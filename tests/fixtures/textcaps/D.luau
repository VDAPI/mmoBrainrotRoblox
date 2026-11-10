--!strict
-- Text caps of package D (item and character windows) of the UI plan (owner 2026-11-10: "bardzo dużo napisów, zbyt
-- szczegółowe opisy"; tests/textcaps.spec, tests/TextScan.luau). `rules`: the surface of keys built at run time.
-- `known`: the package's keys that break a cap of their surface or a universal rule today, with their visible
-- characters after the sample values (pl or en, the longer). The list only shrinks: shorten a text, then remove its
-- line. Edited by package D only; seeded from the scan on 2026-11-10.
return {
	rules = {
		-- a breakpoint's option A (.bp5) and option B (.bp5b), named by Skills.breakpointKey
		{ pattern = "^skill%.[%w_]+%.bp%d+b?$", surface = "breakpoint" },
		-- the skills window's other texts, read through Data/Skills and Data/Paths (nameKey, descKey) or named by
		-- NodeText.shortKey: D's, not orphans of E. Names head the window's details; a skill's full description
		-- (SkillInfo.full) and a node's long text go under "Więcej ▸", a path's description behind the (i) at its name
		{ pattern = "^skill%.[%w_]+%.name$", surface = "sectionTitle" },
		{ pattern = "^skill%.[%w_]+%.desc$", surface = "details" },
		{ pattern = "^path%.[%w_]+%.name$", surface = "sectionTitle" },
		{ pattern = "^path%.[%w_]+%.desc$", surface = "infoTip" },
		{ pattern = "^path%.[%w_]+%.[%w_]+%.name$", surface = "sectionTitle" },
		{ pattern = "^path%.[%w_]+%.[%w_]+%.desc$", surface = "details" },
		{ pattern = "^path%.[%w_]+%.[%w_]+%.short$", surface = "skillShort" },
	},
	known = {},
}
