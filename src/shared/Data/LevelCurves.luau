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
	regions: { string },
	elitePairChance: { [string]: number },
	dropFactor: { [string]: number },
}

local Data: LevelCurvesData = {
	-- DEX gives crit, attack speed and dodge as if the character were at most this level (Logic/StatCalc).
	dexRatingLevel = 20,
	curves = {
		-- Mage mana cost (ROZWOJ 8, owner answer 25). Target T-SK4: on-cooldown casting costs 2-3x regeneration;
		-- the base reaches ~1.1-1.4x with this curve, path skills and costs do the rest (ROZWOJ 12.7).
		-- Key "manaCost.<classId>": classes without a curve pay the flat cost (Cleric, energy classes).
		-- S92 (G2): knots 25 / 30 / 40 keep T-SK4 of destroyerExp and arcanistBoss at 2.0-2.4 on 25-40 (45 unchanged).
		-- S93 (G2): knot 55 (2.18 -> 2.25) lifts arcanistOverload to 2.6 there; knots 50 / 60 hold today's values, so
		-- 45-50 and 60-100 stay as they were.
		-- S147 (DESIGN-18 §13, T-SK4 of the element variants): the pools cast every spell of their bar, so the curve is
		-- lowered from 25 (the means of three elements of S90-S94 are no longer a player's build); 45 / 70 / 100 put the
		-- Arcanist's element variants in 2.0-2.4 and the Destroyer's near 2.0-2.8; the curve still never falls
		["manaCost.Mage"] = {
			{ 20, 1 },
			{ 25, 1.02 },
			{ 30, 1.04 },
			{ 40, 1.08 },
			{ 45, 1.096 },
			{ 50, 1.3 },
			{ 55, 1.4 },
			{ 60, 1.55 },
			{ 70, 1.865 },
			{ 100, 2.1 },
		},
		-- Potion interval = Config.PotionCooldown x this (owner answer 28): 1.5 s to 20, 6 s at 45, ~10 s from 70.
		potionCooldown = { { 20, 1 }, { 45, 4 }, { 70, 6.67 }, { 100, 6.67 } },
		-- Magic-attack part of heals and shields (ROZWOJ 9.2). S87 (T-SK5): mid-band 0.30 for the dungeon Healer on the
		-- Defender at each anchor; the dip on 55-70 is because the HP part grows with path nodes (DECYZJE S87). S92 (G2):
		-- knot 25 (with Heal's rank 6 in Data/SkillCurves) lifts T-SK5 on 25-30 to >= 0.25.
		heal = { { 20, 1 }, { 25, 2.05 }, { 45, 2.33 }, { 70, 0.31 }, { 100, 0.67 } },
		-- S87 (balance plan D1, D4, D5, D7): provisional anchors. S92 owns 45, S93 owns 70, S94 owns 100.
		-- Monster HP and attack at the monster's own (final) level (Logic/MonsterStats.baseHp / baseAttack).
		monsterHp = { { 20, 1 }, { 45, 1.20 }, { 70, 1.32 }, { 100, 1.47 } },
		monsterAtk = { { 20, 1 }, { 45, 1.07 }, { 70, 1.11 }, { 100, 1.14 } },
		-- Elite HP and damage on top of the monster curves (MonsterStats.compute, variant "elite").
		eliteHp = { { 20, 1 }, { 45, 1.08 }, { 70, 1.11 }, { 100, 1.13 } },
		eliteDmg = { { 20, 1 }, { 45, 1.05 }, { 70, 1.06 }, { 100, 1.07 } },
		-- Elite II level terms: neutral until the region sessions tune them.
		elite2Hp = { { 20, 1 }, { 45, 1 }, { 70, 1 }, { 100, 1 } },
		elite2Dmg = { { 20, 1 }, { 45, 1 }, { 70, 1 }, { 100, 1 } },
		-- EXP to the next level (Logic/Exp.expToNext); quest rewards are shares of it, so it scales them too. S92 (F3):
		-- 45 stays 1.0 (the curve never falls, levelcurves.spec); the Dark Forest's quests carry the pace (~14.4 h).
		expToNext = { { 20, 1 }, { 45, 1.0 }, { 70, 1.0 }, { 100, 1.0 } },
	},
	-- S87 (balance plan D5): per-region values by map id (Data/Maps). Data/Monsters.region 1..4 = regions[i].
	-- Neutral until the region sessions (S91 meadows, S92 duskwood, S93 ashen, S94 frostpeak).
	regions = { "meadows", "duskwood", "ashen", "frostpeak" },
	-- Chance that a cave Elite group is a pair (AreaSpawns.cave). S92: the Dark Forest 0.3.
	elitePairChance = { meadows = 0.3, duskwood = 0.3, ashen = 0.25, frostpeak = 0.12 },
	-- Multiplier of Unique and Heroic drop weights of the region's monsters (Common absorbs the rest). At most 1:
	-- Elite II tables have no Common weight, so a factor above 1 fails ItemRoll.rarityWeights (globalbalance.spec).
	-- S92: the Dark Forest 0.85 (2-4 Uniques for the class per hour of grinding, D5). S93: the Scorched Wastes 0.9.
	dropFactor = { meadows = 1, duskwood = 0.85, ashen = 0.9, frostpeak = 0.9 },
}

for _, anchors in Data.curves do
	for _, anchor in anchors do
		table.freeze(anchor)
	end
	table.freeze(anchors)
end
table.freeze(Data.curves)
table.freeze(Data.regions)
table.freeze(Data.elitePairChance)
table.freeze(Data.dropFactor)

return table.freeze(Data)
