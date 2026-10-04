--!strict
-- Remote argument validation (pure). Used by Net for every client -> server call.
--
-- Spec entries: "string" | "number" | "integer" | "boolean" | "table" | "any",
-- optional with a "?" suffix. Numbers must be finite (no NaN/inf); strings are capped at MAX_STRING bytes.

local ArgCheck = {}

ArgCheck.MAX_STRING = 200

-- `count` is select("#", ...) of the received arguments, so trailing nils are counted too.
function ArgCheck.check(args: { any }, spec: { string }, count: number?): (boolean, string?)
	local n = count or #args
	if n > #spec then
		return false, `too many arguments ({n} > {#spec})`
	end
	for i, rule in spec do
		local optional = string.sub(rule, -1) == "?"
		local kind = if optional then string.sub(rule, 1, -2) else rule
		local value = args[i]
		if value == nil then
			if not optional then
				return false, `argument {i} missing ({kind})`
			end
		elseif kind == "any" then
			continue
		elseif kind == "number" or kind == "integer" then
			if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
				return false, `argument {i} is not a finite number`
			end
			if kind == "integer" and value ~= math.floor(value) then
				return false, `argument {i} is not an integer`
			end
		elseif kind == "string" then
			if type(value) ~= "string" or #value > ArgCheck.MAX_STRING then
				return false, `argument {i} is not a string (<= {ArgCheck.MAX_STRING} bytes)`
			end
		elseif type(value) ~= kind then
			return false, `argument {i} is not a {kind}`
		end
	end
	return true, nil
end

return ArgCheck
