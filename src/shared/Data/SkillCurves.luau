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
return table.freeze({
	knots = table.freeze({
		mightyStrike = table.freeze({ dmg = table.freeze({ [5] = 220 }) }), -- 160 + 135 * 4 / 9
		charge = table.freeze({ dmg = table.freeze({ [5] = 160 }) }), -- 120 + 90 * 4 / 9
		bladeWhirl = table.freeze({ dmg = table.freeze({ [4] = 47 }) }), -- 37 + 30 * 3 / 9
		cleave = table.freeze({ dmg = table.freeze({ [3] = 140 + 110 * 2 / 9 }) }),
		battleCry = table.freeze({ atk = table.freeze({ [3] = 14 }) }), -- 10 + 18 * 2 / 9
		-- S90: the Hunter's base (rank 10 nearly flat above 20, C3)
		aimedShot = table.freeze({ dmg = table.freeze({ [5] = 170 + 140 * 4 / 9 }) }),
		doubleShot = table.freeze({ dmg = table.freeze({ [5] = 85 + 65 * 4 / 9 }) }),
		disengage = table.freeze({ bonus = table.freeze({ [4] = 20 + 30 * 3 / 9 }) }),
		piercingArrow = table.freeze({ dmg = table.freeze({ [3] = 200 + 160 * 2 / 9 }) }),
		-- S90: the Mage's base (rank 10 lower above 20, F1; Frost Nova reaches only rank 1 by 20)
		firebolt = table.freeze({ dmg = table.freeze({ [5] = 170 + 140 * 4 / 9 }) }),
		fireball = table.freeze({ dmg = table.freeze({ [5] = 150 + 120 * 4 / 9 }) }),
		iceShard = table.freeze({ dmg = table.freeze({ [4] = 140 + 110 * 3 / 9 }) }),
		chainLightning = table.freeze({ dmg = table.freeze({ [3] = 130 + 100 * 2 / 9 }) }),
	}) :: Knots,
})
