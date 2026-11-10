--!strict
-- Text caps of package C (window chrome and shared components) of the UI plan (owner 2026-11-10: "bardzo dużo napisów, zbyt
-- szczegółowe opisy"; tests/textcaps.spec, tests/TextScan.luau). `rules`: the surface of keys built at run time.
-- `known`: the package's keys that break a cap of their surface or a universal rule today, with their visible
-- characters after the sample values (pl or en, the longer). The list only shrinks: shorten a text, then remove its
-- line. Edited by package C only; seeded from the scan on 2026-11-10 (6 keys) and emptied by C's text pass the same
-- day: every key of C now fits its cap, so a new text over a cap fails textcaps.spec.
return {
	rules = {
		{ pattern = "^window%.[%w_]+%.title$", surface = "windowTitle" },
	},
	known = {},
}
