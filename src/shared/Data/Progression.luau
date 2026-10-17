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

	-- S137 (DESIGN-18 §3.1): skill points, pointsAt(L) = L x perLevel per weapon pool (Logic/SkillPoints); one point
	-- buys one rank up to Logic/Skills.rankAt (the old rank curve is the limit). Below freeRespecLevel a rank refund and
	-- the full reset are free anywhere out of combat; from it a rank refund costs rankRefundGold x level gold (in town
	-- or at a dungeon gate).
	skillPoints = table.freeze({ perLevel = 1, bonus = 7 }),
	freeRespecLevel = 20,
	rankRefundGold = 10,

	-- % EXP for each other class among the credited players, at most varietyMax (ROZWOJ 7.4, S60).
	varietyPerClass = 5,
	varietyMax = 15,

	-- S134b: % of the monster's EXP/gold pool added per extra credited player; split equally (Logic/PartyLoot):
	-- 2 players 150 % (75 % each), 3 200 %, 4 250 %, 5 300 % (60 % each). Solo unchanged.
	partyPoolPerMember = 50,
	-- S134b: a credited member more than this many levels below the monster is carried: does not grow the pool and
	-- gets a share without the pool bonus (total / n).
	partyCarryGap = 10,

	-- S134d: % of a kill's EXP and gold a player gets while Auto Hunt walks for them (Logic/AutoGrind.reward; the EXP
	-- goes with the source "autoGrind", outside the weekly EXP ranking). Item drops unchanged.
	autoGrindExpPct = 70,
	autoGrindGoldPct = 70,
})
