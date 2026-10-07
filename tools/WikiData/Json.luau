--!strict
-- Deterministic JSON for the wiki data (S34, docs/WIKI.md §5): sorted keys, whole numbers without a dot, other
-- numbers rounded to 4 decimals, no -0, NaN / infinity rejected, "\n" line ends. The top-level object puts every
-- key on its own line and every record of a top-level array (or map) on its own line, so diffs stay readable.
-- Input must already be clean (Clean.clean): only tables with string keys or dense arrays.

local Json = {}

Json.DECIMALS = 4

local ESCAPES: { [string]: string } = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function encodeString(s: string): string
	local out = string.gsub(s, '[%c"\\]', function(c: string): string
		return ESCAPES[c] or string.format("\\u%04x", string.byte(c))
	end)
	return '"' .. out .. '"'
end

function Json.number(n: number, path: string?): string
	if n ~= n or n == math.huge or n == -math.huge then
		error(`Json: {n} is not a finite number at {path or "?"}`, 0)
	end
	if n == math.floor(n) and math.abs(n) < 2 ^ 53 then
		if n == 0 then
			return "0"
		end
		return string.format("%d", n)
	end
	local scale = 10 ^ Json.DECIMALS
	local rounded = math.floor(n * scale + 0.5) / scale
	if rounded == 0 then
		return "0"
	end
	if rounded == math.floor(rounded) then
		return string.format("%d", rounded)
	end
	local text = string.format(`%.{Json.DECIMALS}f`, rounded)
	text = string.gsub(text, "0+$", "")
	return text
end

local function isArray(t: { [any]: any }): boolean
	local n = #t
	if n > 0 then
		return true
	end
	return next(t) == nil
end

local function sortedKeys(t: { [any]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, k :: string)
	end
	table.sort(keys)
	return keys
end

local encode: (v: any, path: string) -> string

local function encodeTable(t: { [any]: any }, path: string): string
	if isArray(t) then
		if next(t) == nil then
			-- Empty tables are arrays unless marked as objects (Json.object).
			return if getmetatable(t :: any) == Json.OBJECT then "{}" else "[]"
		end
		local parts = table.create(#t)
		for i, v in ipairs(t) do
			parts[i] = encode(v, `{path}[{i}]`)
		end
		return "[" .. table.concat(parts, ",") .. "]"
	end
	local parts = {}
	for _, k in sortedKeys(t) do
		table.insert(parts, encodeString(k) .. ":" .. encode(t[k], `{path}.{k}`))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

encode = function(v: any, path: string): string
	local kind = type(v)
	if kind == "string" then
		return encodeString(v)
	elseif kind == "number" then
		return Json.number(v, path)
	elseif kind == "boolean" then
		return if v then "true" else "false"
	elseif kind == "table" then
		return encodeTable(v, path)
	elseif v == nil then
		return "null"
	end
	error(`Json: cannot encode {kind} at {path}`, 0)
end

-- Metatable marking an empty table as an object ({}) instead of an array ([]).
Json.OBJECT = table.freeze({})

function Json.object<T>(t: T): T
	return setmetatable(t :: any, Json.OBJECT) :: any
end

-- Compact encoding of any clean value.
function Json.encode(v: any): string
	return encode(v, "$")
end

-- A file: the top-level object one key per line; arrays and maps of records one record per line.
function Json.file(root: { [string]: any }): string
	local lines = { "{" }
	local keys = sortedKeys(root)
	for i, k in keys do
		local v = root[k]
		local comma = if i < #keys then "," else ""
		local head = "  " .. encodeString(k) .. ": "
		if type(v) == "table" and next(v) ~= nil and isArray(v) and type(v[1]) == "table" then
			table.insert(lines, head .. "[")
			for j, item in ipairs(v) do
				table.insert(lines, "    " .. encode(item, `$.{k}[{j}]`) .. (if j < #v then "," else ""))
			end
			table.insert(lines, "  ]" .. comma)
		elseif type(v) == "table" and next(v) ~= nil and not isArray(v) then
			local sub = sortedKeys(v)
			local allTables = true
			for _, sk in sub do
				if type(v[sk]) ~= "table" then
					allTables = false
				end
			end
			if allTables then
				table.insert(lines, head .. "{")
				for j, sk in sub do
					local line = "    " .. encodeString(sk) .. ": " .. encode(v[sk], `$.{k}.{sk}`)
					table.insert(lines, line .. (if j < #sub then "," else ""))
				end
				table.insert(lines, "  }" .. comma)
			else
				table.insert(lines, head .. encode(v, `$.{k}`) .. comma)
			end
		else
			table.insert(lines, head .. encode(v, `$.{k}`) .. comma)
		end
	end
	table.insert(lines, "}")
	return table.concat(lines, "\n") .. "\n"
end

return Json
