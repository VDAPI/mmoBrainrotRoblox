--!strict
-- Character name validation and normalization (pure). Text filtering and uniqueness are server-side
-- (NameService); this module only checks the shape so the client can validate live.

local Config = require("../Config")

local NameRules = {}

-- Polish letters: uppercase codepoint -> lowercase codepoint.
local POLISH_LOWER: { [number]: number } = {
	[0x0104] = 0x0105, -- Ą ą
	[0x0106] = 0x0107, -- Ć ć
	[0x0118] = 0x0119, -- Ę ę
	[0x0141] = 0x0142, -- Ł ł
	[0x0143] = 0x0144, -- Ń ń
	[0x00D3] = 0x00F3, -- Ó ó
	[0x015A] = 0x015B, -- Ś ś
	[0x0179] = 0x017A, -- Ź ź
	[0x017B] = 0x017C, -- Ż ż
}

local POLISH_LETTERS: { [number]: boolean } = {}
for upper, lower in POLISH_LOWER do
	POLISH_LETTERS[upper] = true
	POLISH_LETTERS[lower] = true
end

local function isAllowedCodepoint(cp: number): boolean
	if cp >= 48 and cp <= 57 then -- 0-9
		return true
	end
	if cp >= 65 and cp <= 90 then -- A-Z
		return true
	end
	if cp >= 97 and cp <= 122 then -- a-z
		return true
	end
	return POLISH_LETTERS[cp] == true
end

-- A-Z, a-z or a Polish letter (guild names reuse this).
function NameRules.isLetter(cp: number): boolean
	return (cp >= 65 and cp <= 90) or (cp >= 97 and cp <= 122) or POLISH_LETTERS[cp] == true
end

-- Error keys map to Localization entries "error.name.<reason>".
export type NameError = "invalidUtf8" | "tooShort" | "tooLong" | "invalidChars" | "noLetter"

function NameRules.validate(name: string): (boolean, NameError?)
	local length = utf8.len(name)
	if length == nil then
		return false, "invalidUtf8"
	end
	if length < Config.CharacterName.MinLength then
		return false, "tooShort"
	end
	if length > Config.CharacterName.MaxLength then
		return false, "tooLong"
	end
	local hasLetter = false
	for _, cp in utf8.codes(name) do
		if not isAllowedCodepoint(cp) then
			return false, "invalidChars"
		end
		if not (cp >= 48 and cp <= 57) then
			hasLetter = true
		end
	end
	if not hasLetter then
		return false, "noLetter"
	end
	return true, nil
end

-- Case-insensitive key used for uniqueness ("Łukasz" and "łUKASZ" collide).
function NameRules.normalize(name: string): string
	local out = {}
	for _, cp in utf8.codes(name) do
		if cp >= 65 and cp <= 90 then
			cp += 32
		else
			cp = POLISH_LOWER[cp] or cp
		end
		table.insert(out, utf8.char(cp))
	end
	return table.concat(out)
end

function NameRules.errorKey(reason: string): string
	return `error.name.{reason}`
end

return NameRules
