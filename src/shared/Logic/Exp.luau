--!strict
-- Experience formulas (DESIGN §4.6). Pure.

local Bosses = require("../Data/Bosses")
local LevelCurves = require("./LevelCurves")
local Progression = require("../Data/Progression")

local Exp = {}

-- S87 (balance plan D7, G13): x the "expToNext" level curve (exactly 1 up to 20, so 1-20 is unchanged bit for bit).
-- Quest rewards are shares of expToNext, so the curve scales them too.
function Exp.expToNext(level: number): number
	return math.floor(
		(Progression.nextFactor * level ^ Progression.nextExponent + Progression.nextBase)
				* LevelCurves.at("expToNext", level)
			+ 0.5
	)
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

-- S134c: a boss winner's EXP from its share of the party pool (`shareExp`, PartyLoot.expShares before the level
-- difference). At or above the old entry level (boss level - Bosses.QUEST_GAP) the usual levelDiffMultiplier; below
-- it (the dungeon opens at boss level - Bosses.ENTRY_GAP) the same share of the own level as a winner on the old entry
-- level gets: exp(old entry level) x expToNext(char) / expToNext(old entry level). Continuous at the old entry level.
function Exp.bossExpFor(charLevel: number, bossLevel: number, shareExp: number): number
	local ref = bossLevel - Bosses.QUEST_GAP
	if charLevel >= ref then
		return shareExp * Exp.levelDiffMultiplier(charLevel, bossLevel)
	end
	return shareExp
		* Exp.levelDiffMultiplier(ref, bossLevel)
		* Exp.expToNext(math.max(1, charLevel))
		/ math.max(1, Exp.expToNext(ref))
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

-- Stat points granted when going from `fromLevel` to `toLevel` (skill ranks come from the level, S56).
function Exp.pointsForLevels(fromLevel: number, toLevel: number): number
	return math.max(0, toLevel - fromLevel) * Progression.statPointsPerLevel
end

-- Fraction 0..1 of the way to the next level (1 at max level).
function Exp.progress(level: number, exp: number, maxLevel: number): number
	if level >= maxLevel then
		return 1
	end
	return math.clamp(exp / Exp.expToNext(level), 0, 1)
end

return Exp
