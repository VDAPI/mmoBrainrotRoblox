--!strict
-- Collapsible sections (owner 2026-11-10: "a lot of text, some things cover others, too detailed descriptions, nothing
-- can be collapsed"): which sections of the interface stand open (UI/Components/Section). One account setting
-- (`account.settings.sections`, SetSetting "sections") keeps section id -> open, only for the sections the player
-- clicked; the others follow DEFAULTS. Every section the client shows has its id here, so the server keeps only known
-- ids. Pure (Lune): tests/sectionfold.spec.

local SectionFold = {}

-- Section id -> open by default. The backpack window (UI/Screens/CharacterWindow): the statistics stand open, the
-- build sets and the title folded to one line (the active set and the worn title).
SectionFold.DEFAULTS = table.freeze({
	charStats = true,
	charSets = false,
} :: { [string]: boolean })

function SectionFold.known(id: string): boolean
	return SectionFold.DEFAULTS[id] ~= nil
end

-- Whether section `id` stands open under the saved setting (anything else than a table reads as no setting).
function SectionFold.isOpen(saved: any, id: string): boolean
	local value = if type(saved) == "table" then saved[id] else nil
	if type(value) == "boolean" then
		return value
	end
	return SectionFold.DEFAULTS[id] == true
end

-- A new setting with section `id` open or folded; unknown ids and choices equal to the default are dropped.
function SectionFold.with(saved: any, id: string, open: boolean): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for known, default in SectionFold.DEFAULTS do
		local value = if known == id then open else SectionFold.isOpen(saved, known)
		if value ~= default then
			out[known] = value
		end
	end
	return out
end

-- Two settings open the same sections.
function SectionFold.same(a: any, b: any): boolean
	for id in SectionFold.DEFAULTS do
		if SectionFold.isOpen(a, id) ~= SectionFold.isOpen(b, id) then
			return false
		end
	end
	return true
end

-- Server validator of the setting: a table of known section ids to booleans.
function SectionFold.valid(value: any): boolean
	if type(value) ~= "table" then
		return false
	end
	for key, open in value do
		if type(key) ~= "string" or not SectionFold.known(key) or type(open) ~= "boolean" then
			return false
		end
	end
	return true
end

return SectionFold
