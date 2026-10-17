--!strict
-- Per-skill value knots for the balance sessions (balance plan 2.2, ROZWOJ 2.5); first used by S89.
-- knots[skillId][field] = { [rank] = value }. Only for a `values` field that is a { rank 1, rank max } pair,
-- ranks 2 .. maxLevel - 1. Logic/Skills.valueAt interpolates linearly in rank:
--   (1, pair[1]) -> knots in rank order -> (maxLevel, pair[2]).
-- Band of a knot = band of Skills.rankLevel(skill, rank): <= 20 -> 1-20 (S91), 21-45, 46-70, 71-100.
-- Changing rank max without moving the ranks reached at <= 20: first add a knot at the last rank with
-- rankLevel <= 20 equal to today's value there, then change pair[2] (or add knots at the last ranks
-- reachable at 45 and 70). Never add a third element to the pair. Not read by tools/WikiData.
-- Entries are frozen too: knots = table.freeze({ cleave = table.freeze({ dmg = table.freeze({ [4] = 150 }) }) }).
export type Knots = { [string]: { [string]: { [number]: number } } }
-- S89: each knot is the value the rank had before S89 (the last rank with rankLevel <= 20), so ranks reached at <= 20
-- keep their numbers while rank max moves (B3, S91 owns the 1-20 band). S90: the same for the Hunter and the Mage.
-- S91 (E3): the ranks reached at <= 20 lowered (R1 at L20 <= 1.15 x D1, docs/DECYZJE.md S91); the first rank above
-- 20 keeps its value from before S91 (a knot written as the interpolation that gave it), so ranks above 20 stay.
local AIMED5 = 170 + 140 * 4 / 9 -- aimedShot rank 5 before S91 (S90 knot)
local DOUBLE5 = 85 + 65 * 4 / 9
local BOLT5 = 170 + 140 * 4 / 9
local BALL5 = 150 + 120 * 4 / 9
local SHARD4 = 140 + 110 * 3 / 9
local CHAIN3 = 130 + 100 * 2 / 9
return table.freeze({
	knots = table.freeze({
		-- S91: ranks 1-5 x0.85 (rank 1 160 -> 136), rank 6 pinned (220 + 2 / 5 before S91)
		mightyStrike = table.freeze({ dmg = table.freeze({ [5] = 187, [6] = 220 + (222 - 220) * 1 / 5 }) }),
		-- S91: ranks 1-5 x0.85 (rank 1 120 -> 102), rank 6 pinned
		charge = table.freeze({ dmg = table.freeze({ [5] = 136, [6] = 160 + (165 - 160) * 1 / 5 }) }),
		-- S91: ranks 1-4 x0.9 (rank 1 37 -> 33), rank 5 pinned
		bladeWhirl = table.freeze({ dmg = table.freeze({ [4] = 42, [5] = 47 + (52 - 47) * 1 / 6 }) }),
		cleave = table.freeze({ dmg = table.freeze({ [3] = 140 + 110 * 2 / 9 }) }),
		battleCry = table.freeze({ atk = table.freeze({ [3] = 14 }) }), -- 10 + 18 * 2 / 9
		-- S91: the Cleric's Holy Strike, ranks 1-5 x0.88 (rank 1 190 -> 167), rank 6 pinned
		holyStrike = table.freeze({ dmg = table.freeze({ [5] = 226, [6] = 190 + (340 - 190) * 5 / 9 }) }),
		-- S90: the Hunter's base (rank 10 nearly flat above 20, C3). S91: ranks 1-5 x0.845 / x0.73, rank 6 pinned
		aimedShot = table.freeze({ dmg = table.freeze({ [5] = 196, [6] = AIMED5 + (233 - AIMED5) * 1 / 5 }) }),
		doubleShot = table.freeze({ dmg = table.freeze({ [5] = 83, [6] = DOUBLE5 + (114 - DOUBLE5) * 1 / 5 }) }),
		disengage = table.freeze({ bonus = table.freeze({ [4] = 20 + 30 * 3 / 9 }) }),
		piercingArrow = table.freeze({ dmg = table.freeze({ [3] = 200 + 160 * 2 / 9 }) }),
		-- S90: the Mage's base (rank 10 lower above 20, F1; Frost Nova reaches only rank 1 by 20). S91: ranks <= 20
		-- x0.75 (Bolt) and x0.85 (the rest), the first rank above 20 pinned
		-- S140 (the fire pool's R1 at 20 in the S91 band): Magic Bolt ranks 1-5 x0.92 (rank 5 174 -> 160), Fireball x0.94
		-- (173 -> 162); rank 6 pinned
		firebolt = table.freeze({ dmg = table.freeze({ [5] = 160, [6] = BOLT5 + (255.7 - BOLT5) * 1 / 5 }) }),
		fireball = table.freeze({ dmg = table.freeze({ [5] = 162, [6] = BALL5 + (221.8 - BALL5) * 1 / 5 }) }),
		-- S141 (DESIGN-18 §6.1): Ice Shard unlocks at 1 (was 6), its rank r + 1 comes near the old rank r's level: rank 5
		-- (level 17) tuned for the ice pool's R1 at 20, rank 6 (level 21) keeps the old rank 5 (level 22)
		iceShard = table.freeze({ dmg = table.freeze({ [5] = 80, [6] = SHARD4 + (213 - SHARD4) * 1 / 6 }) }),
		-- S141: Frost Nova unlocks at 6 (was 18): rank 4 (level 18) keeps the old rank 1 (120), rank 5 (level 22) the old
		-- rank 2
		frostNova = table.freeze({ dmg = table.freeze({ [4] = 120, [5] = 120 + 21.3 / 9 }) }),
		chainLightning = table.freeze({ dmg = table.freeze({ [3] = 129, [4] = CHAIN3 + (163.5 - CHAIN3) * 1 / 7 }) }),
		-- S140 (DESIGN-18 §6.1): Meteor unlocks at 26 (was 30), so its rank r + 1 comes at the old rank r's level: rank 2
		-- (level 30) keeps the old rank 1 (98), rank 1 is one step lower (pair 89.6 - 174)
		meteor = table.freeze({ dmg = table.freeze({ [2] = 98 }) }),
		-- S92 (G2, T-SK5 >= 0.25 at 25-30): Heal's rank 6 (level 23) near rank 10, rank 5 (level 19) pinned
		heal = table.freeze({
			healHp = table.freeze({ [5] = 16 + 2 * 4 / 9, [6] = 17.9 }),
			healMag = table.freeze({ [5] = 8 + 4 * 4 / 9, [6] = 11.6 }),
		}),
	}) :: Knots,
})
