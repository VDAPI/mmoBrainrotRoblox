--!strict
-- World events (S101, docs/DESIGN-15.md §4): one event per server about every hour in an open region with players.
-- Logic/WorldEvents picks the region, the hunting ground and the scale; WorldEventService runs it.
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES), the <= 3 % pace check in tests/balance.spec.luau
-- ("World events (S101)"). Rarity keys are numbers (Rarities.UNIQUE / HEROIC / LEGENDARY), like Data/LoginReward.chest.
-- S134c: the Invasion targets (3 players in time, solo almost impossible on equal gear) in tests/balance.spec.luau
-- ("Balance: Invasion (S134c)", tests/Balance.invasion).

export type KindId = "invasion" | "champion"

-- The fields both kinds share (Logic/WorldEvents.kindOf); the kind's own fields are read from `kinds.<id>`.
export type KindDef = {
	id: KindId,
	nameKey: string, -- "event.invasion.name"
	descKey: string, -- one sentence for the HUD and the wiki
	glyph: string, -- map / minimap marker
	color: string, -- hex
	weight: number, -- chance to be picked among the kinds
	duration: number, -- seconds from the start to the hard end
	radius: number, -- studs: participants, heal / shield counting, HUD
	leash: number, -- leash range of the event's monsters
}

return table.freeze({
	schedule = table.freeze({
		interval = 3600, -- seconds between two starts (counted from the planned start of the previous one)
		jitter = 600, -- +- seconds, uniform
		first = table.freeze({ 900, 2100 }), -- first event after the server start: 15-35 min
		warn = 120, -- announcement before the start (DESIGN-15 §4: 2 min)
		retry = 120, -- no player in an open region: try again after this
		gapAfter = 300, -- the next start is never earlier than this after the end of the current event
	}),
	regions = table.freeze({ "meadows", "duskwood", "ashen", "frostpeak" }), -- open region maps (Data/Maps ids)
	levelWindow = 2, -- a hunting ground fits when the median level is in [lv.min - window, lv.max + window]
	order = table.freeze({ "invasion", "champion" }),
	kinds = table.freeze({
		invasion = table.freeze({
			id = "invasion",
			nameKey = "event.invasion.name",
			descKey = "event.invasion.desc",
			glyph = "⚔",
			color = "#E0564A",
			weight = 1,
			duration = 900, -- S134c: 720 -> 900 (bigger waves)
			waves = 6,
			waveEvery = 90, -- S134c: 80 -> 90
			minWaveGap = 40,
			clearShare = 0.8, -- the next wave comes early once 80 % of the current one is dead
			-- monsters per wave = min(max, base + perPlayer x players), in clusters of `cluster` per spawn point
			-- (S134c: 1 player 13, 3 players 19, 5 players 25; S101: 4 + 2 per player, max 16, clusters of 4)
			-- owner 2026-10-20: more monsters at once (10 / 3 / 25 / 5 -> 14 / 4 / 36 / 7), on fewer spawners (`focus`)
			wave = table.freeze({ base = 14, perPlayer = 4, max = 36, cluster = 7 }),
			focus = 3, -- spawners of the ground nearest its centre the waves come down on
			-- S134c: Elites of each wave (index = wave; S101: one Elite in waves 3 and 6 only)
			elitesPerWave = table.freeze({ 1, 1, 1, 1, 2, 2 }),
			-- S134c: the last wave also brings one Elite II of the ground (another kind than the commander when there
			-- is one), an ordinary Elite II with its own ability
			lastWaveElite2 = true,
			commanderAt = 630, -- the commander comes after the last wave or at this second (S134c: 480 -> 630)
			-- S134c: the commander's blows on top of its own ability (Data/MonsterAbilities; list order = priority,
			-- its own ability last) and the gap after each cast (like Data/BossTuning.globalGap)
			commanderAbilities = table.freeze({ "warlordCleave", "warlordLeap", "warlordRally" }),
			commanderGap = 2.2,
			radius = 160,
			leash = 120,
		}),
		champion = table.freeze({
			id = "champion",
			nameKey = "event.champion.name",
			descKey = "event.champion.desc",
			glyph = "♛",
			color = "#E8C25A",
			weight = 1,
			duration = 900,
			routePoints = 8, -- waypoints of the route
			pause = 8, -- seconds of rest on each waypoint
			nearbyAreas = 3, -- the route crosses up to this many fitting hunting grounds of the region
			radius = 120,
			leash = 100,
		}),
	}),
	-- Stat multipliers of the Elite II (commander / champion) by the number of players near it when it spawns
	-- (index = players, the last entry for more). An Elite II of a cave is for 2-3 players (S32): one player gets less.
	-- S134c: the commander is the same for every party (one entry; bosses 2.0: a bigger party only has it easier;
	-- S101: hp 0.45 / 0.7 / 1.0 / 1.2 / 1.4, atk 0.85 / 0.95 / 1 / 1 / 1).
	scale = table.freeze({
		commander = table.freeze({
			hp = table.freeze({ 1.6 }),
			atk = table.freeze({ 1.0 }),
		}),
		champion = table.freeze({
			hp = table.freeze({ 0.7, 1.1, 1.5, 1.9, 2.3 }),
			atk = table.freeze({ 0.9, 1, 1, 1.05, 1.1 }),
		}),
	}),
	share = table.freeze({
		min = 0.03, -- 3 % of all points of the event ...
		hpEquivalent = 3, -- ... or 3 x the HP of a normal monster of the event level, whichever is lower
		healMul = 1, -- points per HP healed
		shieldMul = 1, -- points per HP a shield soaked
		interceptMul = 1, -- points per HP taken for an ally (S61 guard)
		maxLevelAbove = 10, -- characters more than this above the event level help but get no event reward
	}),
	reward = table.freeze({
		-- EXP = expKills x Exp.monsterExp(level, "normal"); S101 F2: the largest one-decimal value keeping one event every
		-- 2 h of play <= 3 % of every level 1-99 (worst L3, Hunter, 2.86 %; L3 grinds at monsterExpMul 0.5)
		expKills = 1.9,
		goldKills = 18, -- gold = goldKills x MonsterStats.gold(level, "normal", 0.5) (S134c: 12 -> 18, a harder event)
		failMul = 0.5, -- time ran out: half EXP and gold, no chest
		-- Same shape as Data/LoginReward.chest (S100) plus the class bias of Loot.pickItem.
		chest = table.freeze({
			-- Rarities.UNIQUE / HEROIC / LEGENDARY, never Mythic (S134c: 60 / 37 / 3, the Legendary half the boss's
			-- base 6 % since an event comes every hour without a daily limit; S101: Unique 80 / Heroic 20)
			rarity = table.freeze({ [2] = 60, [3] = 37, [4] = 3 }),
			classBias = 0.8, -- share of items picked among the ones the character's class can use
			bound = true, -- like the S100 chest: no alt-account farming for the market
		}),
	}),
})
