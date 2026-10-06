--!strict
-- Validates admin command arguments against their schema (S23, Data/AdminCommands). Pure: catalogue ids are
-- checked by a resolver the caller passes (the server resolves items, monsters, maps, players...). Returns the
-- arguments as strings with defaults filled in, or an error text key with its arguments.

local AdminArgs = {}

export type Arg = {
	name: string,
	kind: string,
	min: number?,
	max: number?,
	options: { string }?,
	optional: boolean?,
	default: string?,
}

-- (kind, value) -> whether the id exists. Kinds without a catalogue never reach it.
export type Resolver = (kind: string, value: string) -> boolean

local CATALOGUES = {
	item = true,
	monster = true,
	map = true,
	area = true,
	npc = true,
	boss = true,
	quest = true,
	blessing = true,
	pass = true,
	player = true,
}

AdminArgs.MAX_ARGS = 8
AdminArgs.MAX_LENGTH = 64

local function fail(key: string, args: { [string]: any }): (boolean, { string }?, string?, { [string]: any }?)
	return false, nil, key, args
end

-- (ok, values, errorKey, errorArgs)
function AdminArgs.validate(
	spec: { Arg },
	args: { string },
	resolve: Resolver?
): (boolean, { string }?, string?, { [string]: any }?)
	if #args > #spec then
		return fail("admin.args.tooMany", { max = #spec })
	end
	local out: { string } = {}
	for i, arg in spec do
		local value = args[i]
		if value == nil or value == "" then
			if arg.default ~= nil then
				out[i] = arg.default
				continue
			elseif arg.optional then
				-- keep the position empty: later optional arguments may still follow
				for j = i + 1, #spec do
					if args[j] ~= nil and args[j] ~= "" then
						return fail("admin.args.missing", { name = arg.name })
					end
				end
				break
			end
			return fail("admin.args.missing", { name = arg.name })
		end
		if #value > AdminArgs.MAX_LENGTH then
			return fail("admin.args.tooLong", { name = arg.name })
		end
		local kind = arg.kind
		if kind == "integer" or kind == "number" then
			local n = tonumber(value)
			if n == nil or n ~= n or n == math.huge or n == -math.huge then
				return fail("admin.args.number", { name = arg.name })
			end
			if kind == "integer" and n ~= math.floor(n) then
				return fail("admin.args.integer", { name = arg.name })
			end
			if (arg.min and n < arg.min) or (arg.max and n > arg.max) then
				return fail("admin.args.range", { name = arg.name, min = arg.min or "-", max = arg.max or "-" })
			end
		elseif kind == "enum" then
			if not table.find(arg.options or {}, value) then
				return fail("admin.args.option", { name = arg.name, options = table.concat(arg.options or {}, ", ") })
			end
		elseif CATALOGUES[kind] then
			if resolve and not resolve(kind, value) then
				return fail("admin.args.unknown", { name = arg.name, value = value })
			end
		end
		out[i] = value
	end
	return true, out, nil, nil
end

-- Sanitises raw remote arguments (dev panel): at most MAX_ARGS strings or numbers of at most MAX_LENGTH
-- characters each, numbers turned into strings. Nil when anything else arrives.
function AdminArgs.sanitize(raw: any): { string }?
	if type(raw) ~= "table" then
		return nil
	end
	local count = 0
	for key in raw do
		if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
			return nil
		end
		count += 1
	end
	if count > AdminArgs.MAX_ARGS then
		return nil
	end
	local out: { string } = {}
	for i = 1, count do
		local value = raw[i]
		if type(value) == "number" then
			if value ~= value or value == math.huge or value == -math.huge then
				return nil
			end
			value = tostring(value)
		end
		if type(value) ~= "string" or #value > AdminArgs.MAX_LENGTH then
			return nil
		end
		out[i] = value
	end
	return out
end

-- Splits a console line "/name a b c" (or "name a b c") into the command name and its arguments.
function AdminArgs.parseLine(line: string): (string?, { string })
	local parts = {}
	for word in string.gmatch(line, "%S+") do
		table.insert(parts, word)
	end
	local name = parts[1]
	if not name then
		return nil, {}
	end
	name = string.lower((string.gsub(name, "^/", "")))
	table.remove(parts, 1)
	return name, parts
end

return AdminArgs
