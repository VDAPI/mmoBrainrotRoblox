--!strict
-- Text caps of package E (world and social windows, dialogue, orphan texts) of the UI plan (owner 2026-11-10: "bardzo dużo napisów, zbyt
-- szczegółowe opisy"; tests/textcaps.spec, tests/TextScan.luau). `rules`: the surface of keys built at run time.
-- `known`: the package's keys that break a cap of their surface or a universal rule today, with their visible
-- characters after the sample values (pl or en, the longer). The list only shrinks: shorten a text, then remove its
-- line. Edited by package E only; seeded from the scan on 2026-11-10.
return {
	rules = {
		{ pattern = "^quest%.[%w_]+%.p[1-4]$", surface = "dialogPage" },
		{ pattern = "^quest%.[%w_]+%.done%d*$", surface = "dialogPage" },
		-- a page goes on under its continuation keys (Logic/Dialogue.parts, "Dalej ▸"): p1 -> p1b, p1c
		{ pattern = "^quest%.[%w_]+%.p[1-4][b-d]$", surface = "dialogPage" },
		-- a page's variant by an earlier answer (quest.<id>.p2.<answer>, quest.<id>.done.<answer>) and its continuation
		{ pattern = "^quest%.[%w_]+%.p[1-4]%.%a+%d?$", surface = "dialogPage" },
		{ pattern = "^quest%.[%w_]+%.done%.%a+%d?$", surface = "dialogPage" },
		{ pattern = "^npc%.[%w_]+%.greeting$", surface = "npcGreeting" },
		{ pattern = "^npc%.[%w_]+%.greetingSpring$", surface = "npcGreeting" },
		{ pattern = "^npc%.[%w_]+%.line", surface = "dialogPage" },
		-- the NPC's line after the player's answer in a quest dialogue
		{ pattern = "^quest%.[%w_]+%.say%.[%w_]+%.reply$", surface = "dialogPage" },
		{ pattern = "^tip%.", surface = "loadingTip" },
		{ pattern = "^cutscene%.", surface = "cutscene" },
		-- the arena's 3v3 queue button: ArenaWindow's team3 picks the key at run time (review 2026-11-10)
		{ pattern = "^arena%.queue3%.solo$", surface = "button" },
		{ pattern = "^arena%.queue3%.team$", surface = "button" },
		{ pattern = "%.short$", surface = "line" },
		{ pattern = "%.info$", surface = "infoTip" },
	},
	-- empty since 2026-11-10 (package E): every key of E fits its surface, with no em dash
	known = {},
}
