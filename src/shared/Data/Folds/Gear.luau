--!strict
-- Fold defaults of the item and character windows (Data/Folds, Logic/SectionFold): section id -> open by default,
-- true / false or { pc = ..., phone = ... }. Package D of the UI plan (owner 2026-11-10: backpack, skills, services,
-- shops) adds its sections here.
return table.freeze({
	-- The backpack window (owner 2026-11-10, UI/Screens/CharacterWindow): the statistics stand open, the build sets and
	-- the title fold to one line (the active set and the worn title).
	charStats = true,
	charSets = false,
} :: { [string]: boolean | { pc: boolean, phone: boolean } })
