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
		["manaCost.Mage"] = { { 20, 1 }, { 45, 1.89 }, { 70, 2.59 }, { 100, 3.49 } },
		-- Potion interval = Config.PotionCooldown x this (owner answer 28): 1.5 s to 20, 6 s at 45, ~10 s from 70.
		potionCooldown = { { 20, 1 }, { 45, 4 }, { 70, 6.67 }, { 100, 6.67 } },
		-- Magic-attack part of heals and shields (ROZWOJ 9.2). S87 (T-SK5): mid-band 0.30 for the dungeon Healer on the
		-- Defender at each anchor; the dip on 55-70 is because the HP part grows with path nodes (DECYZJE S87).
		heal = { { 20, 1 }, { 45, 2.33 }, { 70, 0.31 }, { 100, 0.67 } },
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
		-- EXP to the next level (Logic/Exp.expToNext); quest rewards are shares of it, so it scales them too.
		expToNext = { { 20, 1 }, { 45, 1.0 }, { 70, 1.0 }, { 100, 1.0 } },
	},
	-- S87 (balance plan D5): per-region values by map id (Data/Maps). Data/Monsters.region 1..4 = regions[i].
	-- Neutral until the region sessions (S91 meadows, S92 duskwood, S93 ashen, S94 frostpeak).
	regions = { "meadows", "duskwood", "ashen", "frostpeak" },
	-- Chance that a cave Elite group is a pair (AreaSpawns.cave).
	elitePairChance = { meadows = 0.3, duskwood = 0.5, ashen = 0.5, frostpeak = 0.5 },
	-- Multiplier of Unique and Heroic drop weights of the region's monsters (Common absorbs the rest). At most 1:
	-- Elite II tables have no Common weight, so a factor above 1 fails ItemRoll.rarityWeights (globalbalance.spec).
	dropFactor = { meadows = 1, duskwood = 1, ashen = 1, frostpeak = 1 },
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
