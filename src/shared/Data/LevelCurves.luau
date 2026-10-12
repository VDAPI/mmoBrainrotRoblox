--!strict
-- Level curves (S54, ROZWOJ 8): multipliers that change a formula with the character level. A curve is a list of
-- anchors { level, value } with strictly increasing levels; the first anchor is always { 20, 1 } and the last one sits
-- on Config.MaxLevel. The curve is the identity up to level 20; between two anchors log(value) is linear in log(level)
-- (a power law); above the last anchor the value stays flat. Balance sessions may add anchors inside their own band
-- (e.g. 30 or 58). Read only through Logic/LevelCurves; the wiki exporter never reads this module, it shows the values
-- through Logic (Skills.cost, Potions.interval, StatCalc). Data only.

export type Anchor = { number } -- { level, value }

export type LevelCurvesData = {
	dexRatingLevel: number,
	curves: { [string]: { Anchor } },
}

local Data: LevelCurvesData = {
	-- DEX gives crit, attack speed and dodge as if the character were at most this level (Logic/StatCalc).
	dexRatingLevel = 20,
	curves = {
		-- Mage mana cost (ROZWOJ 8, owner answer 25). Target T-SK4: on-cooldown casting costs 2-3x regeneration;
		-- the base reaches ~1.1-1.4x with this curve, path skills and costs do the rest (ROZWOJ 12.7).
		-- Key "manaCost.<classId>": classes without a curve pay the flat cost (Cleric, energy classes).
		["manaCost.Mage"] = { { 20, 1 }, { 45, 1.4 }, { 70, 1.9 }, { 100, 2.5 } },
		-- Potion interval = Config.PotionCooldown x this (owner answer 28): 1.5 s to 20, 6 s at 45, ~10 s from 70.
		potionCooldown = { { 20, 1 }, { 45, 4 }, { 70, 6.67 }, { 100, 6.67 } },
		-- Magic-attack part of heals and shields (ROZWOJ 9.2). Identity until the balance sessions set it (S87).
		heal = { { 20, 1 }, { 45, 1 }, { 70, 1 }, { 100, 1 } },
	},
}

for _, anchors in Data.curves do
	for _, anchor in anchors do
		table.freeze(anchor)
	end
	table.freeze(anchors)
end
table.freeze(Data.curves)

return table.freeze(Data)
