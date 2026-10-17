--!strict
-- S135: upper case for section labels (UI SectionLabel). Luau's string.upper only knows ASCII, so the Polish letters
-- (and the few other Latin-1 / Latin Extended-A letters our texts use) are mapped here. Pure (Lune).

local TextCase = {}

local UPPER: { [string]: string } = {
	["ą"] = "Ą",
	["ć"] = "Ć",
	["ę"] = "Ę",
	["ł"] = "Ł",
	["ń"] = "Ń",
	["ó"] = "Ó",
	["ś"] = "Ś",
	["ź"] = "Ź",
	["ż"] = "Ż",
	["é"] = "É",
	["ö"] = "Ö",
	["ü"] = "Ü",
	["ä"] = "Ä",
}

function TextCase.upper(s: string): string
	local out = {}
	for _, code in utf8.codes(s) do
		local ch = utf8.char(code)
		table.insert(out, UPPER[ch] or (if code < 128 then string.upper(ch) else ch))
	end
	return table.concat(out)
end

return TextCase
