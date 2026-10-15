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
	-- FIX 2026-10-15 (owner): Elites and Elite II are for their drops, not for levelling: EXP per HP below a normal
	-- monster (Elite HP x3, Elite II x10; was x4 / x12). The pace model 1-100 counts normal monsters only.
	variantMultiplier = table.freeze({
		normal = 1,
		elite = 1.5,
		elite2 = 4,
		boss = 60,
	}) :: { [Variant]: number },

	-- Level difference d = player - monster.
	freeDiff = 5, -- d <= 5: full EXP
	penaltyPerLevel = 0.15, -- per level above freeDiff
	minMultiplier = 0.05,
	bonusPerLevel = 0.04, -- monster above the player
	maxBonus = 0.2,

	statPointsPerLevel = 5,
	-- ROZWOJ 2.4 (S57): 1 path point on every even level (pointsAt(L) = floor(L / pathPointsEvery)); the pace waits
	-- for the owner's approval (ROZWOJ 15.1).
	pathPointsEvery = 2,

	-- % EXP for each other class among the credited players, at most varietyMax (ROZWOJ 7.4, S60).
	varietyPerClass = 5,
	varietyMax = 15,
})
