--!strict
-- Fold defaults of the item and character windows (Data/Folds, Logic/SectionFold): section id -> open by default,
-- true / false or { pc = ..., phone = ... }. Package D of the UI plan (owner 2026-11-10: backpack, skills, services,
-- shops) adds its sections here.
return table.freeze({
	-- The backpack window (owner 2026-11-10, UI/Screens/CharacterWindow): the statistics stand open, the build sets and
	-- the title fold to one line (the active set and the worn title).
	charStats = true,
	charSets = false,
	-- Owner 2026-11-10 (UI plan, "nothing folds"): the 37 derived statistics in four groups (Data/Stats.groups,
	-- CharacterWindow/DerivedList): the attack ones open, the rest folded to their header.
	charOffense = true,
	charDefense = false,
	charResources = false,
	charOther = false,
	-- The skills window's details (SkillsWindow/Details): "Koszt i odnowienie" folds to its one line (the cost and the
	-- cooldown; the shape, the element and the rank table under it), the breakpoints fold to their header, and
	-- "Zmiany z kierunków" to how many of its direction nodes work (review 2026-11-11).
	skillCost = false,
	skillBreakpoints = false,
	skillDirections = false,
} :: { [string]: boolean | { pc: boolean, phone: boolean } })
