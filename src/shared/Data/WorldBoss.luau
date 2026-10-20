--!strict
-- The world boss (S149, DESIGN §15.6): at fixed times of the day (S149c: 10:00 and 22:00 Polish time) each world server (Arena/ServerMode.isWorld) wakes
-- the same boss on the same spot of a late map, with no message between servers; 10-20 players fight it in the open,
-- everyone with enough contribution (Logic/Contribution, the S101 rule) and level gets one reward per account and
-- occurrence. Logic/WorldBoss reads it, WorldBossService runs it; the boss itself (attacks, HP, `minLevel`, the time
-- limit after which it leaves) is Data/Bosses[boss] (`world = true`).
-- Balance numbers: tools/balance_reasons.luau (BALANCE_MODULES), the targets in tests/balance.spec.luau ("Balance: world
-- boss (S149)", tests/Balance.targetsS149). Rarity keys are numbers (Rarities.HEROIC / LEGENDARY / MYTHIC).

-- map-relative centre, r = arena and leash radius; S149b: nameKey = the place on the maps and the cards, free = the
-- middle (r - free studs) without any prop (the blows and the brands need room, Logic/WorldGen/WorldBossArena)
export type Spot = { id: string, nameKey: string, x: number, z: number, r: number, free: number }
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
		-- S149c (owner 2026-10-20): twice a day, at 10:00 and 22:00 Polish time (Europe/Warsaw: CET = UTC+1, CEST = UTC+2
		-- from the last Sunday of March 01:00 UTC to the last Sunday of October 01:00 UTC, Logic/WorldBoss.utcOffset), so
		-- 08:00 / 20:00 UTC in summer and 09:00 / 21:00 UTC in winter: never over the Blood Moon (Tue / Thu 19:00-19:30
		-- UTC with its quiet 10 min) nor the tournament start (Sat 19:00 UTC), tests/worldboss.spec
		times = table.freeze({ table.freeze({ 10, 0 }), table.freeze({ 22, 0 }) }), -- local { hour, minute }, ascending
		tz = table.freeze({ std = 1, dst = 2 }), -- hours ahead of UTC in winter and in summer (EU rule)
		warn = table.freeze({ 600, 120 }), -- announcements, seconds before the start (descending)
		linger = 60, -- seconds the marker stays after the kill or the leave
	}),
	-- S149: the arena on the Icewatch plateau (area 88-100): dry, gentle ground in the whole circle, >= 120 studs from
	-- portals, cave mouths, hideouts and road edges (tests/worldboss.spec); S149b dresses it as the Forefather's Barrow
	-- (Logic/WorldGen/WorldBossArena) and keeps the area groups, arrivals, events and Auto Hunt out of r +
	-- AreaSpawns.LAIR_CLEARANCE (AreaSpawns.reservedCircles, like a hideout)
	spots = table.freeze({
		table.freeze({
			id = "icewatchPlateau",
			nameKey = "worldboss.spot.icewatchPlateau",
			x = 490,
			z = 360,
			r = 70,
			free = 10,
		}),
	}),
	-- S149b: the party size the fight is made for (the map card, the HUD, the wiki; the S149 model's 10-20 players)
	players = table.freeze({ 10, 20 }),
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
		-- level, "normal", 0.5) (like S101, from the character's level); S149c (owner 2026-10-20): x2 now that he comes
		-- twice a day (one fight ~25 % of a level at 80-99, tests/Balance S149.exp.*)
		expKills = 32,
		goldKills = 48,
		materials = table.freeze({
			table.freeze({ id = "essence_crystal", chance = 1, min = 2, max = 4 }),
			table.freeze({ id = "legend_core", chance = 0.25, min = 1, max = 1 }),
		}),
		-- the one item: Heroic / Legendary / Mythic (never Unique or Common); S149c: 60 / 34 / 6, the Legendary and
		-- Mythic weights times the contribution factor (Logic/WorldBoss.rarityWeights)
		rarity = table.freeze({ [3] = 60, [4] = 34, [5] = 6 }),
		classBias = 0.8, -- share of items picked among the ones the character's class can use (a Mythic always fits)
		bound = false, -- like the dungeon boss loot (tradeable); the named items are bound (bindOnPickup)
		failMul = 0, -- the boss left: nothing
		-- S149c: the contribution factor f = clamp(lo + slope x s, lo, hi), s = own points / (all points / fighters
		-- with points): x0.5 for a token share, x1 for an even one, x2 at most (Logic/WorldBoss.factor)
		factor = table.freeze({ lo = 0.5, slope = 0.5, hi = 2.0 }),
		-- S149c: a named item of his own (Data/Items/Uniques, two per class) on top of the item: chance x f, +step for
		-- each rewarded fight without one (character.worldBossPity), certain after `pityAt` such fights
		named = table.freeze({
			chance = 0.04,
			step = 0.01,
			pityAt = 30,
			byClass = table.freeze({
				Warrior = table.freeze({ "unique_hrimvald_axe", "unique_hrimvald_helm" }),
				Hunter = table.freeze({ "unique_hrimvald_bow", "unique_hrimvald_mantle" }),
				Mage = table.freeze({ "unique_hrimvald_staff", "unique_hrimvald_robe" }),
				Cleric = table.freeze({ "unique_hrimvald_crozier", "unique_hrimvald_shield" }),
			}),
			element = "ice", -- the element of the named Mage staff (an elemental weapon)
		}),
	}),
	pvpSafe = true, -- no PvP in the fighters' circle while the boss lives
	-- S156 (owner 2026-10-20): the barrow is a cave hollow (cliff walls round the ring, Logic/WorldGen/WorldBossArena) entered
	-- through a vestibule in front of the opening (local -Z): its circle (centre r + d from the spot's centre, radius r)
	-- is always free of PvP, boss or no boss
	antechamber = table.freeze({ d = 20, r = 16 }),
	publishEvery = 0.5, -- seconds between two state sends at most (only on a change)
})
