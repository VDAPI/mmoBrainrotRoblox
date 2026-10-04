--!strict
-- Experience formulas (DESIGN §4.6). Pure.

local Progression = require("../Data/Progression")

local Exp = {}

function Exp.expToNext(level: number): number
	return math.floor(Progression.nextFactor * level ^ Progression.nextExponent + Progression.nextBase + 0.5)
end

function Exp.monsterExp(monsterLevel: number, variant: Progression.Variant?): number
	local base = math.floor(
		Progression.monsterBase + Progression.monsterFactor * monsterLevel ^ Progression.monsterExponent + 0.5
	)
	local key: Progression.Variant = variant or "normal"
	local multiplier = Progression.variantMultiplier[key] or 1
	return base * multiplier
end

function Exp.levelDiffMultiplier(playerLevel: number, monsterLevel: number): number
	local d = playerLevel - monsterLevel
	if d < 0 then
		return 1 + math.min(-d * Progression.bonusPerLevel, Progression.maxBonus)
	end
	if d <= Progression.freeDiff then
		return 1
	end
	return math.max(Progression.minMultiplier, 1 - Progression.penaltyPerLevel * (d - Progression.freeDiff))
end

-- Adds `gained` EXP. Returns (newLevel, newExp, levelsGained). EXP is not collected at maxLevel.
function Exp.applyExp(level: number, exp: number, gained: number, maxLevel: number): (number, number, number)
	if level >= maxLevel then
		return maxLevel, 0, 0
	end
	local newLevel = level
	local newExp = exp + math.max(0, math.floor(gained))
	while newLevel < maxLevel do
		local need = Exp.expToNext(newLevel)
		if newExp < need then
			break
		end
		newExp -= need
		newLevel += 1
	end
	if newLevel >= maxLevel then
		newExp = 0
	end
	return newLevel, newExp, newLevel - level
end

-- Points granted when going from `fromLevel` to `toLevel`.
function Exp.pointsForLevels(fromLevel: number, toLevel: number): (number, number)
	local stat, skill = 0, 0
	for l = fromLevel + 1, toLevel do
		stat += Progression.statPointsPerLevel
		if l >= Progression.skillPointsFromLevel then
			skill += Progression.skillPointsPerLevel
		end
	end
	return stat, skill
end

-- Fraction 0..1 of the way to the next level (1 at max level).
function Exp.progress(level: number, exp: number, maxLevel: number): number
	if level >= maxLevel then
		return 1
	end
	return math.clamp(exp / Exp.expToNext(level), 0, 1)
end

return Exp
