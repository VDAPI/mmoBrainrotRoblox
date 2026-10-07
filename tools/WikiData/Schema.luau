--!strict
-- One declaration of every wiki data entity (S34, docs/WIKI.md §5). The builders' output is validated against it
-- (a key outside the schema is an error: the allowlist of fields), and TypesTs turns it into wiki/src/data/types.ts.
--
-- Types: "string", "int", "number", "bool", "name" ({ pl, en }), "ref:<file>" (an id in another file), "color"
-- (hex text), "data" (free JSON of a game structure, e.g. skill breakpoints: cleaned, not described field by
-- field), S.arr(t), S.map(t) (text keys), S.rec(name, fields) (a field name ending in "?" is optional),
-- S.enum(name) (text from a set the builders register from the game data: rarity keys, elements, classes, ...).

local Schema = {}

export type T = string | { [string]: any }

function Schema.arr(t: T): T
	return { kind = "array", of = t }
end

function Schema.map(t: T): T
	return { kind = "map", of = t }
end

-- Named record; fields `{ ["name?"] = T }` are optional.
function Schema.rec(name: string, fields: { [string]: T }): T
	return { kind = "record", name = name, fields = fields }
end

function Schema.enum(name: string): T
	return { kind = "enum", name = name }
end

-- Values of the enums (filled from the data by the builders before validation).
local enums: { [string]: { string } } = {}

function Schema.setEnum(name: string, values: { string })
	local copy = table.clone(values)
	table.sort(copy)
	enums[name] = copy
end

function Schema.enumValues(name: string): { string }?
	return enums[name]
end

-- File name -> root record.
Schema.files = {} :: { [string]: T }

function Schema.file(name: string, root: T)
	Schema.files[name] = root
end

local function fieldName(key: string): (string, boolean)
	local base = string.match(key, "^(.-)%?$")
	if base then
		return base, true
	end
	return key, false
end

function Schema.fields(record: T): { { name: string, optional: boolean, t: T } }
	local out = {}
	for key, t in (record :: any).fields do
		local name, optional = fieldName(key)
		table.insert(out, { name = name, optional = optional, t = t })
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

local function fail(errors: { string }, path: string, message: string)
	if #errors < 50 then
		table.insert(errors, `{path}: {message}`)
	end
end

local function isDense(v: { [any]: any }): boolean
	return #v > 0 or next(v) == nil
end

local function validate(v: any, t: T, path: string, errors: { string })
	if type(t) == "string" then
		if t == "string" or t == "color" or string.sub(t, 1, 4) == "ref:" then
			if type(v) ~= "string" then
				fail(errors, path, `expected text, got {type(v)}`)
			elseif t == "color" and not string.match(v, "^#%x%x%x%x%x%x$") then
				fail(errors, path, `expected #RRGGBB, got {v}`)
			end
		elseif t == "int" then
			if type(v) ~= "number" or v ~= math.floor(v) then
				fail(errors, path, `expected a whole number, got {tostring(v)}`)
			end
		elseif t == "number" then
			if type(v) ~= "number" then
				fail(errors, path, `expected a number, got {type(v)}`)
			end
		elseif t == "bool" then
			if type(v) ~= "boolean" then
				fail(errors, path, `expected true/false, got {type(v)}`)
			end
		elseif t == "name" then
			if type(v) ~= "table" or type(v.pl) ~= "string" or type(v.en) ~= "string" then
				fail(errors, path, "expected { pl, en }")
			else
				for k in v do
					if k ~= "pl" and k ~= "en" then
						fail(errors, path, `unexpected key {k} in a name`)
					end
				end
			end
		elseif t == "data" then
			-- Free JSON (already cleaned).
			return
		else
			fail(errors, path, `unknown schema type {t}`)
		end
		return
	end
	local kind = t.kind
	if kind == "enum" then
		local values = enums[t.name]
		if type(v) ~= "string" then
			fail(errors, path, `expected {t.name}, got {type(v)}`)
		elseif values and not table.find(values, v) then
			fail(errors, path, `{v} is not a {t.name}`)
		end
	elseif kind == "array" then
		if type(v) ~= "table" or not isDense(v) then
			fail(errors, path, "expected an array")
			return
		end
		for i, item in ipairs(v) do
			validate(item, t.of, `{path}[{i}]`, errors)
		end
	elseif kind == "map" then
		if type(v) ~= "table" then
			fail(errors, path, "expected a map")
			return
		end
		for k, item in v do
			if type(k) ~= "string" then
				fail(errors, path, `map key {tostring(k)} is not text`)
			else
				validate(item, t.of, `{path}.{k}`, errors)
			end
		end
	elseif kind == "record" then
		if type(v) ~= "table" then
			fail(errors, path, `expected {t.name}, got {type(v)}`)
			return
		end
		local known: { [string]: boolean } = {}
		for _, field in Schema.fields(t) do
			known[field.name] = true
			local value = v[field.name]
			if value == nil then
				if not field.optional then
					fail(errors, path, `missing {field.name} ({t.name})`)
				end
			else
				validate(value, field.t, `{path}.{field.name}`, errors)
			end
		end
		for k in v do
			if not known[k] then
				fail(errors, path, `key {tostring(k)} is not in the schema of {t.name}`)
			end
		end
	else
		fail(errors, path, `unknown schema kind {tostring(kind)}`)
	end
end

-- Errors of a value against a type (empty = valid).
function Schema.check(v: any, t: T, path: string?): { string }
	local errors = {}
	validate(v, t, path or "$", errors)
	return errors
end

-- Every named record reachable from the files, by name (for types.ts and the docs table).
function Schema.records(): { [string]: T }
	local out: { [string]: T } = {}
	local function walk(t: T)
		if type(t) ~= "table" then
			return
		end
		if t.kind == "record" then
			if out[t.name] and out[t.name] ~= t then
				error(`Schema: two records named {t.name}`, 0)
			end
			if out[t.name] then
				return
			end
			out[t.name] = t
			for _, field in Schema.fields(t) do
				walk(field.t)
			end
		elseif t.kind == "array" or t.kind == "map" then
			walk(t.of)
		end
	end
	for _, root in Schema.files do
		walk(root)
	end
	return out
end

return Schema
