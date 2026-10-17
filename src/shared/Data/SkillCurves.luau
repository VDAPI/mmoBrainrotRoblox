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
		-- S91: ranks 1-5 x0.85 (rank 1 120 -> 102), rank 6 pinned (S143: unlock 3 -> 4, rank 5 at 20)
		charge = table.freeze({ dmg = table.freeze({ [5] = 136, [6] = 160 + (165 - 160) * 1 / 5 }) }),
		-- S143 (DESIGN-18 §6.2): Blade Whirl unlocks at 26 (rank 1 = the old rank 6), its S91 knots are gone; Cleave
		-- unlocks at 3: rank 5 (level 19) keeps the old rank 3 (level 18); Battle Cry unlocks at 30 (rank 1 = the old
		-- rank 6), its knot is gone
		cleave = table.freeze({ dmg = table.freeze({ [5] = 140 + 110 * 2 / 9 }) }),
		-- S143: Brutal Strike, the two-handed S1, on Mighty Strike's S91 knots
		brutalStrike = table.freeze({ dmg = table.freeze({ [5] = 187, [6] = 220 + (222 - 220) * 1 / 5 }) }),
		-- S143: Bloodlust unlocks at 10 (was 18): rank 3 (level 18) keeps the old rank 1, rank 4 (22) the old rank 2
		bloodlust = table.freeze({ speed = table.freeze({ [3] = 15, [4] = 15 + 5 / 9 }) }),
		-- S143: Earthquake unlocks at 26 (was 30): rank 2 (level 30) keeps the old rank 1
		earthquake = table.freeze({ dmg = table.freeze({ [2] = 150 }) }),
		-- S143: Intercept unlocks at 10 (was the Guardian's row 4, 26): rank 5 (level 26) keeps the old rank 1, rank 6
		-- (30) the old rank 2
		intercept = table.freeze({
			share = table.freeze({ [5] = 20, [6] = 20 + 10 / 9 }),
			guard = table.freeze({ [5] = 10, [6] = 10 + 5 / 9 }),
		}),
		-- S143: Crushing Blow unlocks at 15 (was the Standard-Bearer's row 7, 48): rank 9 (47) keeps the old rank 1
		crushingBlow = table.freeze({ dmg = table.freeze({ [9] = 300 }) }),
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
		-- S142: Fire Bolt x0.72 at every rank (its burn stack, Logic/Burn): rank 5 160 -> 115, rank 6 x0.72
		firebolt = table.freeze({ dmg = table.freeze({ [5] = 115, [6] = (BOLT5 + (255.7 - BOLT5) * 1 / 5) * 0.72 }) }),
		fireball = table.freeze({ dmg = table.freeze({ [5] = 162, [6] = BALL5 + (221.8 - BALL5) * 1 / 5 }) }),
		-- S141 (DESIGN-18 §6.1): Ice Shard unlocks at 1 (was 6), its rank r + 1 comes near the old rank r's level: rank 5
		-- (level 17) tuned for the ice pool's R1 at 20, rank 6 (level 21) keeps the old rank 5 (level 22)
		-- S142: rank 5 80 -> 130 (Fire Bolt left the ice pool: Ice Shard is its only bolt again, ice 0.85-0.95 x fire)
		iceShard = table.freeze({ dmg = table.freeze({ [5] = 130, [6] = SHARD4 + (213 - SHARD4) * 1 / 6 }) }),
		-- S142 (DESIGN-18 §6.1): Lightning Bolt like Fire Bolt's S91 knots (ranks <= 20 cut, rank 6 near rank 10)
		lightningBolt = table.freeze({ dmg = table.freeze({ [5] = 170, [6] = 265 }) }),
		-- S141: Frost Nova unlocks at 6 (was 18): rank 4 (level 18) keeps the old rank 1 (120), rank 5 (level 22) the old
		-- rank 2
		frostNova = table.freeze({ dmg = table.freeze({ [4] = 120, [5] = 120 + 21.3 / 9 }) }),
		-- S142 (DESIGN-18 §6.1): Chain Lightning unlocks at 3 (was 10): rank 5 (level 19) 140 (the old rank 3 at 18 was 129;
		-- lightning's area at 20), rank 6 (level 23) the old rank 4 (level 22); ranks 1-4 lower (pair 100 - 200)
		chainLightning = table.freeze({ dmg = table.freeze({ [5] = 140, [6] = CHAIN3 + (163.5 - CHAIN3) * 1 / 7 }) }),
		-- S142: Thunderstorm unlocks at 26 (was 45): rank 6 (level 46) 32 (the old rank 1 24.9 x 1.3, the lightning pool's
		-- A2), ranks 1-5 lower
		firewall = table.freeze({ dmg = table.freeze({ [6] = 32 }) }),
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
