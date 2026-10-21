--!strict
-- World events (S101, docs/DESIGN-15.md §4): one event per server about every hour in an open region with players.
-- Logic/WorldEvents picks the region, the hunting ground and the scale; WorldEventService runs it.
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES), the <= 3 % pace check in tests/balance.spec.luau
-- ("World events (S101)"). Rarity keys are numbers (Rarities.UNIQUE / HEROIC / LEGENDARY), like Data/LoginReward.chest.
-- S134c: the Invasion targets (3 players in time, solo almost impossible on equal gear) in tests/balance.spec.luau
-- ("Balance: Invasion (S134c)", tests/Balance.invasion). S134d: the Invasion is a zone with a live population refilled
-- in place and intensity phases (Logic/WorldEvents.refill, phaseDone; WorldEventService), the same targets.

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
			duration = 900, -- S134c: 720 -> 900
			-- S134d (owner 2026-10-20: "few monsters, easy, they just run in; let them spawn in one area, more, like a
			-- hunting ground"): the Invasion is a zone around the ground's centre (a rift / war camp, the map circle).
			-- Its monsters spawn at spread points inside (`points` in a ring from `core` to radius - `edge`, never
			-- within `clear` of a player), keep their own spot as home (soft leash `leash`, the hard leash keeps them
			-- within radius + `margin` of the centre) and aggro from `aggro` studs; no long runs at players.
			-- S160 (owner 2026-10-21: "everyone who enters the area gets attacked"): a zone monster goes for any
			-- player standing inside the circle within `aggro` studs of it and its hard leash, whatever the level
			-- (world event monsters are never level-locked), each player counting `spread` studs farther per zone
			-- monster already on them (the zone's monsters share out the players); the soft leash is the hard one.
			zone = table.freeze({
				radius = 70,
				core = 16, -- the rift and the commander's ground stay free of spawn points
				edge = 6,
				points = 28,
				clear = 18,
				aggro = 40, -- S160: 25 -> 40 (any player in the circle has zone monsters within reach)
				spread = 10, -- S160: studs a player counts farther per zone monster already fighting it
				leash = 30,
				margin = 15,
				maxSlope = 18, -- a spawn point this much above / below the centre is dropped (a cliff, a roof)
			}),
			-- S134d: the live population = min(max, base + perPlayer x players in the radius), refilled every
			-- `refillEvery` s with at most `refillBatch` monsters (1 player 24, 3 players 36, 5 players 48, 7+ 60)
			population = table.freeze({ base = 18, perPlayer = 6, max = 60 }),
			-- S156 (owner 2026-10-20, the waves on the 3 spawners nearest the centre): in the zone these spawners are
			-- spawn points too (known good ground, within the radius) next to the spiral's
			focus = 3,
			refillEvery = 3,
			refillBatch = 8,
			-- S134d: intensity phases (S134c waves): a phase ends after phaseEvery s, or after minPhase s once the
			-- party has killed phaseKills x the population in it (and the phase's Elite II is dead). Live Elites of the
			-- population per phase; elite2Phase brings one Elite II of the ground, the last phase the commander (at the
			-- latest after (phases - 1) x phaseEvery = 600 s)
			phases = 6,
			phaseEvery = 120,
			minPhase = 60,
			phaseKills = 1,
			elitesPerPhase = table.freeze({ 0, 1, 1, 2, 2, 3 }),
			elite2Phase = 5,
			-- S134d: the zone's monsters (not the commander) are a little tougher and pay more EXP per kill
			-- (CombatService: monster.expMul): 3 players earn 1.03-1.13 x grinding the same ground with potions for
			-- the same time (owner's x1.25 = 0.92-1.01: the commander's part kills slower), 3.8-4.8 x the pace
			-- convention (resting between fights); tests/balance.spec "Balance: Invasion (S134c)" S134d rows
			mods = table.freeze({ hpMul = 1.3, atkMul = 1.2 }),
			expMul = 1.4,
			-- S134c: the commander's blows on top of its own ability (Data/MonsterAbilities; list order = priority,
			-- its own ability last) and the gap after each cast (like Data/BossTuning.globalGap)
			commanderAbilities = table.freeze({ "warlordCleave", "warlordLeap", "warlordRally" }),
			commanderGap = 2.2,
			radius = 100, -- participants, heal / shield counting, HUD (S134d: the zone + 30; S134c: 160)
			leash = 100, -- the commander's leash from the centre (S134c: 120)
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
