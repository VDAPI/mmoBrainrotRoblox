--!strict
-- Text caps of package C (window chrome and shared components) of the UI plan (owner 2026-11-10: "bardzo dużo napisów, zbyt
-- szczegółowe opisy"; tests/textcaps.spec, tests/TextScan.luau). `rules`: the surface of keys built at run time.
-- `known`: the package's keys that break a cap of their surface or a universal rule today, with their visible
-- characters after the sample values (pl or en, the longer). The list only shrinks: shorten a text, then remove its
-- line. Edited by package C only; seeded from the scan on 2026-11-10.
return {
	rules = {
		{ pattern = "^window%.[%w_]+%.title$", surface = "windowTitle" },
	},
	known = {
		["equip.bind.details"] = { surface = "modalDetails", chars = 243, reason = "modalDetails en 243 > 240 chars" },
		["rework2.body"] = { surface = "modalBody", chars = 152, reason = "modalBody pl 152 > 90 chars" },
		["rework2.body.info"] = { surface = "infoTip", chars = 452, reason = "infoTip pl 452 > 240 chars" },
		["rework2.button"] = { surface = "modalButton", chars = 19, reason = "modalButton pl 19 > 14 chars" },
		["rework2.title"] = { surface = "modalTitle", chars = 31, reason = "modalTitle pl 31 > 28 chars" },
		["skills.reset.confirm"] = { surface = "modalBody", chars = 116, reason = "modalBody pl 116 > 90 chars" },
	},
}
