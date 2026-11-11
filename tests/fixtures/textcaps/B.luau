--!strict
-- Text caps of package B (messages) of the UI plan (owner 2026-11-10: "bardzo dużo napisów, zbyt
-- szczegółowe opisy"; tests/textcaps.spec, tests/TextScan.luau). `rules`: the surface of keys built at run time.
-- `known`: the package's keys that break a cap of their surface or a universal rule today, with their visible
-- characters after the sample values (pl or en, the longer). The list only shrinks: shorten a text, then remove its
-- line. Edited by package B only; seeded from the scan on 2026-11-10, empty since package B's texts (2026-11-10).
return {
	rules = {
		{ pattern = "^loot%.announce", surface = "banner" },
		-- the zone banner's note in a world boss's circle (Logic/WorldBoss.zoneNote, Hud/ZoneBanner); the boss's own
		-- announcements are literal keys at AnnounceService's sites
		{ pattern = "^worldboss%.safeZone$", surface = "banner" },
		{ pattern = "%.announceGlobal$", surface = "banner" },
		{ pattern = "^combat%.levelLock$", surface = "toast" },
		{ pattern = "^combat%.supportLock$", surface = "toast" },
		-- the invitations, chosen at run time in each controller's popup (B's Prompt will show them)
		{ pattern = "^party%.invited$", surface = "prompt" },
		{ pattern = "^duel%.invited$", surface = "prompt" },
		{ pattern = "^trade%.invited$", surface = "prompt" },
		{ pattern = "^guild%.invited$", surface = "prompt" },
		{ pattern = "^social%.friendInvited$", surface = "prompt" },
		{ pattern = "^friends%.party%.invited$", surface = "prompt" },
		-- the whole text behind a server toast's "i" (NotificationController reads `key .. ".info"`)
		{ pattern = "^contract%.ready%.info$", surface = "infoTip" },
		{ pattern = "^items%.toast%.legendRework%.info$", surface = "infoTip" },
	},
	known = {},
}
