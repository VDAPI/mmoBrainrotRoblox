--!strict
-- Text caps of package A (HUD) of the UI plan (owner 2026-11-10: "bardzo dużo napisów, zbyt
-- szczegółowe opisy"; tests/textcaps.spec, tests/TextScan.luau). `rules`: the surface of keys built at run time.
-- `known`: the package's keys that break a cap of their surface or a universal rule today, with their visible
-- characters after the sample values (pl or en, the longer). The list only shrinks: shorten a text, then remove its
-- line. Edited by package A only; seeded from the scan on 2026-11-10, emptied by package A's texts the same day.
return {
	rules = {
		{ pattern = "^tutorial%.[%w_]+%.pc$", surface = "tutorialTile" },
		{ pattern = "^tutorial%.[%w_]+%.touch$", surface = "tutorialTile" },
		{ pattern = "^tutorial%.[%w_]+%.phone$", surface = "tutorialTile" },
		{ pattern = "^tutorial%.[%w_]+%.travel$", surface = "tutorialTile" },
		{ pattern = "^tracker%.", surface = "hudLine" },
		{ pattern = "^e2timer%.", surface = "hudLine" },
		{ pattern = "^hud%.menu%.", surface = "tileLabel" },
	},
	known = {},
}
