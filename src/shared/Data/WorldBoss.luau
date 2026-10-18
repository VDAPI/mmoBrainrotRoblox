--!strict
-- The world boss (S149, DESIGN §15.6): every 3 h of the UTC clock each world server (Arena/ServerMode.isWorld) wakes
-- the same boss on the same spot of a late map, with no message between servers; 10-20 players fight it in the open,
-- everyone with enough contribution (Logic/Contribution, the S101 rule) and level gets one reward per account and
-- occurrence. Logic/WorldBoss reads it, WorldBossService runs it; the boss itself (attacks, HP, `minLevel`, the time
-- limit after which it leaves) is Data/Bosses[boss] (`world = true`).
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES), the targets in tests/balance.spec.luau ("Balance: world
-- boss (S149)", tests/Balance.targetsS149). Rarity keys are numbers (Rarities.HEROIC / LEGENDARY / MYTHIC).

export type Spot = { id: string, x: number, z: number, r: number } -- map-relative centre, r = arena and leash radius
export type Share = {
	min: number, -- share of all points ...
	hpEquivalent: number, -- ... or this many normal monsters' HP of the boss level, whichever is lower
	healMul: number,
	shieldMul: number,
	interceptMul: number,
}
export type MaterialDrop = { id: string, chance: number, min: number, max: number }

return table.freeze({
	boss = "hrimvald", -- Data/Bosses id (world = true)
	map = "frostpeak", -- the Frost Peaks (70-100)
	schedule = table.freeze({
		-- starts every `everyHours` h from `offsetHour`:`minute` UTC (02, 05, 08, 11, 14, 17, 20, 23): never over the Blood
		-- Moon (Tue / Thu 19:00-19:30 with its quiet 10 min) nor the tournament start (Sat 19:00)
		everyHours = 3,
		offsetHour = 2,
		minute = 0,
		warn = table.freeze({ 600, 120 }), -- announcements, seconds before the start (descending)
		linger = 60, -- seconds the marker stays after the kill or the leave
	}),
	-- S149: the arena on the Icewatch plateau (area 88-100): dry, gentle ground in the whole circle, >= 120 studs from
	-- portals, cave mouths, hideouts and road edges (tests/worldboss.spec); S149b dresses it and keeps groups out
	spots = table.freeze({
		table.freeze({ id = "icewatchPlateau", x = 490, z = 360, r = 70 }),
	}),
	fighterReach = 30, -- fighters: alive players within r + this of the centre (also the PvP-free circle)
	share = table.freeze({
		min = 0.02,
		hpEquivalent = 3,
		healMul = 1,
		shieldMul = 1,
		interceptMul = 1,
	}),
	reward = table.freeze({
		-- EXP = expKills x Exp.monsterExp(character level, "normal"), gold = goldKills x MonsterStats.gold(character
		-- level, "normal", 0.5) (like S101, from the character's level); one fight ~ the EXP of 10-12 min of hunting at
		-- 80-99 (12-14 % of a level, tests/Balance S149.exp.*: the boss is about its item)
		expKills = 16,
		goldKills = 24,
		materials = table.freeze({
			table.freeze({ id = "essence_crystal", chance = 1, min = 2, max = 4 }),
			table.freeze({ id = "legend_core", chance = 0.25, min = 1, max = 1 }),
		}),
		-- the one item: Heroic / Legendary / Mythic (never Unique or Common)
		rarity = table.freeze({ [3] = 72, [4] = 24, [5] = 4 }),
		classBias = 0.8, -- share of items picked among the ones the character's class can use (a Mythic always fits)
		bound = false, -- like the dungeon boss loot (tradeable)
		failMul = 0, -- the boss left: nothing
	}),
	pvpSafe = true, -- no PvP in the fighters' circle while the boss lives
	publishEvery = 0.5, -- seconds between two state sends at most (only on a change)
})
