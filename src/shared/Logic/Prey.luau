--!strict
-- Prey hunts (owner 2026-10-23): the daily and weekly "kill N of monster X" contracts. A hunting ground of the region
-- maps that fits the level (the hunting contracts' pool: Data/Quests/Contracts.RULES.minGroups, never caves), one of
-- its normal kinds (RULES.minKindShare, like Logic/ContractGen.kindsOf) and the kills scaled by the kind's share of the
-- area's normal monsters, so a rarer kind asks for fewer. Pure; the draw comes from the caller's Rng.

local AreaAdvice = require("./AreaAdvice")
local AreaSpawns = require("./AreaSpawns")
local Areas = require("../Data/Areas")
local Contracts = require("../Data/Quests/Contracts")
local Monsters = require("../Data/Monsters")
local QuestTypes = require("../Data/Quests/Types")
local Rng = require("./Rng")
local Spawns = require("../Data/Spawns")

local Prey = {}

local REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }

export type Ground = { map: string, area: Areas.Area }

-- Hunting grounds that cover `level`; the nearest one by level when none does (never empty).
function Prey.grounds(level: number): { Ground }
	local all: { Ground } = {}
	for _, mapId in REGION_MAPS do
		for _, area in AreaAdvice.sorted(mapId) do
			if area.groups >= Contracts.RULES.minGroups and #area.kinds > 0 then
				table.insert(all, { map = mapId, area = area })
			end
		end
	end
	local fit: { Ground } = {}
	for _, ground in all do
		if ground.area.lv[1] <= level and level <= ground.area.lv[2] then
			table.insert(fit, ground)
		end
	end
	if #fit > 0 then
		return fit
	end
	local best, bestGap = all[1], math.huge
	for _, ground in all do
		local lv = ground.area.lv
		local gap = if level < lv[1] then lv[1] - level elseif level > lv[2] then level - lv[2] else 0
		if gap < bestGap then
			best, bestGap = ground, gap
		end
	end
	return { best }
end

-- The kinds of a ground with their share of its normal monsters (kinds under RULES.minKindShare left out while
-- another reaches it; 1 / #kinds when the map has no generated groups).
function Prey.kinds(ground: Ground): { { kind: string, share: number } }
	local shares = AreaSpawns.kindShares(Spawns.byMap[ground.map] or {}, ground.area.id)
	local floor = Contracts.RULES.minKindShare
	local known, out = {}, {}
	for _, kind in ground.area.kinds do
		if Monsters.get(kind) then
			table.insert(known, kind)
			local share = shares[kind] or 0
			if share >= floor then
				table.insert(out, { kind = kind, share = share })
			end
		end
	end
	if #out == 0 then
		for _, kind in known do
			table.insert(out, { kind = kind, share = shares[kind] or (1 / #known) })
		end
	end
	return out
end

-- A "kill `n` of a kind on a ground" objective: `base` = kills of the whole area for the hunt, `minKills` the floor.
function Prey.objective(level: number, base: number, minKills: number, rng: Rng.Rng): QuestTypes.Objective
	local ground = rng:pick(Prey.grounds(level))
	local pick = rng:pick(Prey.kinds(ground))
	local n = math.max(minKills, math.floor(base * pick.share + 0.5))
	return { type = "kill", n = n, monster = pick.kind, area = ground.area.id }
end

return Prey
