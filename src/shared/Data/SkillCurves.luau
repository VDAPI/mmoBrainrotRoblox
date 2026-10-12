--!strict
-- Per-skill value knots for the balance sessions (balance plan 2.2, ROZWOJ 2.5). Empty until S89.
-- knots[skillId][field] = { [rank] = value }. Only for a `values` field that is a { rank 1, rank max } pair,
-- ranks 2 .. maxLevel - 1. Logic/Skills.valueAt interpolates linearly in rank:
--   (1, pair[1]) -> knots in rank order -> (maxLevel, pair[2]).
-- Band of a knot = band of Skills.rankLevel(skill, rank): <= 20 -> 1-20 (S91), 21-45, 46-70, 71-100.
-- Changing rank max without moving the ranks reached at <= 20: first add a knot at the last rank with
-- rankLevel <= 20 equal to today's value there, then change pair[2] (or add knots at the last ranks
-- reachable at 45 and 70). Never add a third element to the pair. Not read by tools/WikiData.
-- Entries are frozen too: knots = table.freeze({ cleave = table.freeze({ dmg = table.freeze({ [4] = 150 }) }) }).
export type Knots = { [string]: { [string]: { [number]: number } } }
return table.freeze({ knots = table.freeze({}) :: Knots })
