--!strict
-- World events (S101, docs/DESIGN-15.md §4): one event per server about every hour in an open region with players.
-- Logic/WorldEvents picks the region, the hunting ground and the scale; WorldEventService runs it.
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES), the <= 3 % pace check in tests/balance.spec.luau
-- ("World events (S101)"). Rarity keys are numbers (Rarities.UNIQUE / HEROIC), like Data/LoginReward.chest.

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
			duration = 720,
			waves = 6,
			waveEvery = 80,
			minWaveGap = 40,
			clearShare = 0.8, -- the next wave comes early once 80 % of the current one is dead
			wave = table.freeze({ base = 4, perPlayer = 2, max = 16, cluster = 4 }), -- monsters per wave, per point
			eliteWaves = table.freeze({ 3, 6 }), -- these waves add one Elite
			commanderAt = 480, -- the commander comes after the last wave or at this second
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
	scale = table.freeze({
		commander = table.freeze({
			hp = table.freeze({ 0.45, 0.7, 1.0, 1.2, 1.4 }),
			atk = table.freeze({ 0.85, 0.95, 1, 1, 1 }),
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
		goldKills = 12, -- gold = goldKills x MonsterStats.gold(level, "normal", 0.5)
		failMul = 0.5, -- time ran out: half EXP and gold, no chest
		-- Same shape as Data/LoginReward.chest (S100) plus the class bias of Loot.pickItem.
		chest = table.freeze({
			rarity = table.freeze({ [2] = 80, [3] = 20 }), -- Rarities.UNIQUE / HEROIC; never above Heroic
			classBias = 0.8, -- share of items picked among the ones the character's class can use
			bound = true, -- like the S100 chest: no alt-account farming for the market
		}),
	}),
})
