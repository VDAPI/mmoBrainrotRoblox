--!strict
-- Shared income model for the 20-100 item diagnostics: the S32 pace model (tests/Balance.pace) extended to every
-- region (usual kind of the level from any region, its own loot table) and to the main story above level 20.

local B = require("../tests/Balance")
local Exp = require("../src/shared/Logic/Exp")
local Monsters = require("../src/shared/Data/Monsters")
local Quests = require("../src/shared/Data/Quests")
local Stats = require("../src/shared/Data/Stats")

local M = {}

-- Region bands (DESIGN §3): quests of a band are spread over its levels by EXP needed.
M.BANDS = { { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 99 } }

function M.bandOf(level: number): { number }
	for _, band in M.BANDS do
		if level >= band[1] and level <= band[2] then
			return band
		end
	end
	return M.BANDS[#M.BANDS]
end

-- The usual non-passive, non-cave kind of a level in any region (closest middle of its level range).
function M.kindAt(level: number): string
	local best, bestMid = "wolf", math.huge
	for _, def in Monsters.list do
		if not def.passive and not def.cave and level >= def.levels.min and level <= def.levels.max then
			local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
			if mid < bestMid then
				best, bestMid = def.id, mid
			end
		end
	end
	if bestMid == math.huge then
		for _, def in Monsters.list do
			if not def.passive and level >= def.levels.min and level <= def.levels.max then
				local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
				if mid < bestMid then
					best, bestMid = def.id, mid
				end
			end
		end
	end
	return best
end

-- Quest EXP and gold at `level`: quests of its band (main story + SIDE_SHARE of side quests) spread by EXP need.
function M.questRewards(level: number): (number, number)
	local band = M.bandOf(level)
	local exp, gold, need = 0, 0, 0
	for _, entry in { { Quests.Main.list, 1 }, { Quests.Side.list, B.SIDE_SHARE } } do
		for _, q in entry[1] :: any do
			if q.level >= band[1] and q.level <= band[2] then
				exp += (q.reward.exp or 0) * entry[2]
				gold += (q.reward.gold or 0) * entry[2]
			end
		end
	end
	for l = band[1], band[2] do
		need += Exp.expToNext(l)
	end
	local share = Exp.expToNext(level) / need
	return exp * share, gold * share
end

export type Pace = {
	level: number,
	kind: string,
	kills: number,
	secondsPerKill: number,
	hours: number,
	expPerKill: number,
	goldPerKill: number,
	dropPerKill: number,
	questGold: number,
	income: number, -- gold of the whole level (kills + drop sales + quests)
	goldPerHour: number, -- kills + drop sales per hour of grinding
	restShare: number,
}

function M.pace(classId: string, level: number): Pace
	local kind = M.kindAt(level)
	local p = B.player(classId, level)
	local fight = B.expectedGroup(p, kind, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local rest = fight.hpLost / regen
	local perFight = fight.seconds + rest + B.BREAK + B.WALK
	local secondsPerKill = perFight / fight.members
	local expPerKill = B.killExp(level, kind, level)
	local goldPerKill = B.killGold(level, kind, level)
	local dropPerKill = B.dropValue(level, "normal", kind)
	local questExp, questGold = M.questRewards(level)
	local need = math.max(0, Exp.expToNext(level) - questExp)
	local kills = need / expPerKill
	return {
		level = level,
		kind = kind,
		kills = kills,
		secondsPerKill = secondsPerKill,
		hours = kills * secondsPerKill / 3600,
		expPerKill = expPerKill,
		goldPerKill = goldPerKill,
		dropPerKill = dropPerKill,
		questGold = questGold,
		income = kills * (goldPerKill + dropPerKill) + questGold,
		goldPerHour = (goldPerKill + dropPerKill) * 3600 / secondsPerKill,
		restShare = rest / perFight,
	}
end

-- Cumulative income from level `from` to `to` - 1.
function M.incomeBetween(classId: string, from: number, to: number): number
	local total = 0
	for l = from, to - 1 do
		total += M.pace(classId, l).income
	end
	return total
end

return M
