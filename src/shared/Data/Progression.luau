--!strict
-- Experience and level-up constants (DESIGN §4.6, §4.3, §14.1). Data only; formulas in Logic/Exp.

export type Variant = "normal" | "elite" | "elite2" | "boss"

return table.freeze({
	-- expToNext(L) = round(nextFactor * L ^ nextExponent + nextBase)
	nextFactor = 40,
	nextExponent = 1.9,
	nextBase = 60,

	-- monsterExp(Lm) = round(monsterBase + monsterFactor * Lm ^ monsterExponent) * variant multiplier
	monsterBase = 8,
	monsterFactor = 6,
	monsterExponent = 1.25,
	variantMultiplier = table.freeze({
		normal = 1,
		elite = 4,
		elite2 = 12,
		boss = 60,
	}) :: { [Variant]: number },

	-- Level difference d = player - monster.
	freeDiff = 5, -- d <= 5: full EXP
	penaltyPerLevel = 0.15, -- per level above freeDiff
	minMultiplier = 0.05,
	bonusPerLevel = 0.04, -- monster above the player
	maxBonus = 0.2,

	statPointsPerLevel = 5,
	skillPointsPerLevel = 1,
	skillPointsFromLevel = 2, -- first skill point when reaching this level
})
