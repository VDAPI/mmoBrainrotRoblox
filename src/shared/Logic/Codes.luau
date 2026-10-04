--!strict
-- Reward code checks (pure; S17).

local CodeData = require("../Data/Codes")

local Codes = {}

-- "  vael thorn " -> "VAELTHORN": codes ignore case and spaces.
function Codes.normalize(text: string): string
	return string.upper((string.gsub(text, "%s+", "")))
end

-- (def?, errorKey?) for a code typed by an account that already redeemed `redeemed`.
function Codes.check(text: string, redeemed: { [string]: number }?, now: number): (CodeData.CodeDef?, string?)
	local code = Codes.normalize(text)
	if #code < 3 or #code > 24 then
		return nil, "codes.error.invalid"
	end
	local def = CodeData.get(code)
	if not def then
		return nil, "codes.error.invalid"
	end
	if def.expires and now > def.expires then
		return nil, "codes.error.expired"
	end
	if redeemed and redeemed[code] then
		return nil, "codes.error.used"
	end
	return def, nil
end

return Codes
