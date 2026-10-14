--!strict
-- Hunting contract generator (S99, DESIGN-15 §3.3): builds the 99 contracts of Data/Quests/Contracts from its RULES
-- and the hunting grounds of the four region maps (Data/Areas). Pure and deterministic (no Rng): the same data always
-- gives the same list, so tests/contracts.spec compares it with the file; tools/contracts_gen.luau only serialises it.
--
-- Level L picks, among the areas of the region maps with groups >= minGroups and lv[1] <= L <= lv[2] (never caves or
-- dungeons), the one with the smallest score; ties go to the lower area id:
--   |(lv[1] + lv[2]) / 2 - L|  + penalty.previous (the area of L - 1) + penalty.beforePrevious (L - 2)
--   + penalty.perUse x the area's uses so far + penalty.sameProfile (same S33 profile as L - 1)
-- Without a candidate the nearest area by level is a fallback (reported; the test forbids fallbacks).

local AreaAdvice = require("./AreaAdvice")
local AreaProfiles = require("../Data/AreaProfiles")
local Areas = require("../Data/Areas")
local Contracts = require("../Data/Quests/Contracts")
local Exp = require("./Exp")
local QuestTypes = require("../Data/Quests/Types")

export type Rules = typeof(Contracts.RULES)
export type Pick = { area: Areas.Area, map: string, fallback: boolean }

local ContractGen = {}

ContractGen.REGION_MAPS = table.freeze({ "meadows", "duskwood", "ashen", "frostpeak" }) -- the order of the world

-- Kills of the contract of `level`: linear between the anchors of rules.kills, rounded; the end values outside.
function ContractGen.killsAt(rules: Rules, level: number): number
	local anchors = rules.kills
	if level <= anchors[1][1] then
		return anchors[1][2]
	end
	for i = 2, #anchors do
		local a, b = anchors[i - 1], anchors[i]
		if level <= b[1] then
			local t = (level - a[1]) / (b[1] - a[1])
			return math.floor(a[2] + (b[2] - a[2]) * t + 0.5)
		end
	end
	return anchors[#anchors][2]
end

-- Every hunting ground of the region maps with enough groups, in world order (maps, then AreaAdvice.sorted).
local function pool(rules: Rules): { Pick }
	local out: { Pick } = {}
	for _, mapId in ContractGen.REGION_MAPS do
		for _, area in AreaAdvice.sorted(mapId) do
			if area.groups >= rules.minGroups then
				table.insert(out, { area = area, map = mapId, fallback = false })
			end
		end
	end
	return out
end

-- Areas whose level range covers `level` (empty when none does).
function ContractGen.candidates(rules: Rules, level: number): { Pick }
	local out: { Pick } = {}
	for _, pick in pool(rules) do
		if pick.area.lv[1] <= level and level <= pick.area.lv[2] then
			table.insert(out, pick)
		end
	end
	return out
end

-- The nearest area by level when nothing covers `level` (ties: the lower range).
local function fallback(rules: Rules, level: number): Pick
	local best: Pick? = nil
	local bestGap = math.huge
	for _, pick in pool(rules) do
		local lv = pick.area.lv
		local gap = if level < lv[1] then lv[1] - level elseif level > lv[2] then level - lv[2] else 0
		if gap < bestGap or (gap == bestGap and best and lv[1] < best.area.lv[1]) then
			best, bestGap = pick, gap
		end
	end
	assert(best, "ContractGen: no hunting ground at all")
	return { area = best.area, map = best.map, fallback = true }
end

local function profileOf(areaId: string): any
	return AreaProfiles.ofArea(areaId)
end

local function copyItems(list: { { id: string, n: number } }?): { { id: string, n: number } }?
	if not list then
		return nil
	end
	local out = {}
	for _, item in list do
		table.insert(out, { id = item.id, n = item.n })
	end
	return out
end

-- The picks for levels 1..MAX_LEVEL with the rotation rule.
function ContractGen.picks(rules: Rules): { Pick }
	local out: { Pick } = {}
	local uses: { [string]: number } = {}
	for level = 1, Contracts.MAX_LEVEL do
		local list = ContractGen.candidates(rules, level)
		local chosen: Pick
		if #list == 0 then
			chosen = fallback(rules, level)
		else
			local prev = out[level - 1]
			local prev2 = out[level - 2]
			local prevProfile = if prev then profileOf(prev.area.id) else nil
			local best: Pick? = nil
			local bestScore = math.huge
			for _, pick in list do
				local lv = pick.area.lv
				local score = math.abs((lv[1] + lv[2]) / 2 - level)
				if prev and prev.area.id == pick.area.id then
					score += rules.penalty.previous
				end
				if prev2 and prev2.area.id == pick.area.id then
					score += rules.penalty.beforePrevious
				end
				score += rules.penalty.perUse * (uses[pick.area.id] or 0)
				if prev and profileOf(pick.area.id) == prevProfile then
					score += rules.penalty.sameProfile
				end
				if score < bestScore or (score == bestScore and best and pick.area.id < best.area.id) then
					best, bestScore = pick, score
				end
			end
			chosen = best :: Pick
		end
		uses[chosen.area.id] = (uses[chosen.area.id] or 0) + 1
		table.insert(out, chosen)
	end
	return out
end

-- The contracts 1..MAX_LEVEL; `share` = Data/QuestBudget.TARGET.contract (the EXP of a level's requirement), no EXP
-- below rules.expFrom (S109).
function ContractGen.build(rules: Rules, share: number): { QuestTypes.ContractQuest }
	local out: { QuestTypes.ContractQuest } = {}
	for level, pick in ContractGen.picks(rules) do
		local reward: QuestTypes.Reward = {
			exp = if level >= rules.expFrom then math.floor(Exp.expToNext(level) * share) else 0,
			gold = math.floor(rules.gold.base + rules.gold.perLevel * level),
			items = copyItems(rules.milestones[level]),
		}
		table.insert(out, {
			id = `contract_{level}`,
			level = level,
			category = "contract",
			map = pick.map,
			area = pick.area.id,
			objectives = { { type = "kill", n = ContractGen.killsAt(rules, level), area = pick.area.id } },
			reward = reward,
		})
	end
	return out
end

-- Lines for the tool: uses of every area (in world order), the longest run of one area, fallbacks.
function ContractGen.report(list: { QuestTypes.ContractQuest }): { string }
	local lines: { string } = {}
	local uses: { [string]: number } = {}
	local runArea, run, bestRun, bestArea, bestEnd = "", 0, 0, "", 0
	for _, contract in list do
		uses[contract.area] = (uses[contract.area] or 0) + 1
		if contract.area == runArea then
			run += 1
		else
			runArea, run = contract.area, 1
		end
		if run > bestRun then
			bestRun, bestArea, bestEnd = run, runArea, contract.level
		end
	end
	for _, mapId in ContractGen.REGION_MAPS do
		local parts = {}
		for _, area in AreaAdvice.sorted(mapId) do
			table.insert(parts, `{area.id} {uses[area.id] or 0}`)
		end
		table.insert(lines, `{mapId}: {table.concat(parts, ", ")}`)
	end
	table.insert(lines, `longest run: {bestArea} x{bestRun} (ending at level {bestEnd})`)
	local fallbacks = {}
	for _, contract in list do
		local area = Areas.areaById(contract.area)
		if not area or contract.level < area.lv[1] or contract.level > area.lv[2] then
			table.insert(fallbacks, `{contract.level} -> {contract.area}`)
		end
	end
	table.insert(lines, `fallbacks: {if #fallbacks > 0 then table.concat(fallbacks, ", ") else "none"}`)
	return lines
end

return ContractGen
