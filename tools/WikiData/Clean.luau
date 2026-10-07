--!strict
-- Turns game data into plain JSON-ready values (S34): functions are dropped, dense 1..n tables become arrays,
-- sparse number keys become text keys ("3"), tables mixing number and text keys are an error with the path (no
-- data is lost silently), cycles are an error. Strings, numbers and booleans pass through.

local Json = require("./Json")

local Clean = {}

local function fail(path: string, message: string): never
	error(`Clean: {message} at {path}`, 0)
end

local function clean(v: any, path: string, seen: { [any]: boolean }): any
	local kind = type(v)
	if kind == "string" or kind == "number" or kind == "boolean" then
		return v
	elseif kind == "function" or kind == "nil" then
		return nil
	elseif kind ~= "table" then
		fail(path, `unsupported {kind}`)
	end
	if seen[v] then
		fail(path, "cycle")
	end
	seen[v] = true
	local numbers, texts, count, maxIndex = 0, 0, 0, 0
	for k, item in v do
		if type(item) ~= "function" then
			count += 1
			if type(k) == "number" then
				numbers += 1
				if k == math.floor(k) and k > maxIndex then
					maxIndex = k
				end
			elseif type(k) == "string" then
				texts += 1
			else
				fail(path, `unsupported key type {type(k)}`)
			end
		end
	end
	local out: { [any]: any } = {}
	if numbers > 0 and texts > 0 then
		fail(path, "mixed number and text keys")
	elseif numbers > 0 and maxIndex == numbers and #v == numbers then
		for i = 1, numbers do
			out[i] = clean(v[i], `{path}[{i}]`, seen)
		end
	elseif numbers > 0 then
		for k, item in v do
			if type(item) ~= "function" then
				out[Json.number(k :: number, path)] = clean(item, `{path}.{k}`, seen)
			end
		end
	else
		for k, item in v do
			if type(item) ~= "function" then
				out[k] = clean(item, `{path}.{k}`, seen)
			end
		end
		if count == 0 and getmetatable(v) == Json.OBJECT then
			Json.object(out)
		end
	end
	seen[v] = nil
	return out
end

function Clean.clean(v: any, path: string?): any
	return clean(v, path or "$", {})
end

-- Copy of `t` with only the listed fields (allowlist), cleaned. Missing fields stay missing.
function Clean.pick(t: { [string]: any }, fields: { string }, path: string?): { [string]: any }
	local out = {}
	for _, field in fields do
		if t[field] ~= nil then
			out[field] = clean(t[field], `{path or "$"}.{field}`, {})
		end
	end
	return out
end

-- Sorted keys of a table (deterministic iteration instead of pairs order).
function Clean.keys(t: { [any]: any }): { any }
	local keys = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys, function(a: any, b: any): boolean
		if type(a) == type(b) then
			return a < b
		end
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- Entities released on the wiki (S34, docs/WIKI.md §1): `hidden == true` or `wiki == false` hides one.
function Clean.visible(entity: any): boolean
	return type(entity) ~= "table" or (entity.hidden ~= true and entity.wiki ~= false)
end

-- Drops hidden entities from a list and every reference to them: `refs(entity)` lists the ids an entity points
-- to; an entity whose required reference is hidden is kept but the reference is removed by `strip`.
function Clean.withoutHidden<T>(list: { T }, hidden: { [string]: boolean }, idOf: (T) -> string): { T }
	local out = {}
	for _, entity in list do
		if Clean.visible(entity) and not hidden[idOf(entity)] then
			table.insert(out, entity)
		end
	end
	return out
end

-- Removes entries pointing at hidden ids from an array of references (`field` = the id field, or the entry itself).
function Clean.dropRefs(list: { any }, hidden: { [string]: boolean }, field: string?): { any }
	local out = {}
	for _, entry in list do
		local id = if field then (entry :: any)[field] else entry
		if not (type(id) == "string" and hidden[id]) then
			table.insert(out, entry)
		end
	end
	return out
end

return Clean
