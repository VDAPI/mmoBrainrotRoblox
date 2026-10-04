--!strict
-- Story playthrough sanity (S15): stands in for a full run in Studio. Every kill/collect objective of the
-- main line must be doable — some spawner places that monster (and variant / region) at levels close to
-- the quest's recommended level — and the line must go from level 1 to 100 in order.

local Monsters = require("../src/shared/Data/Monsters")
local Quests = require("../src/shared/Data/Quests")
local Spawns = require("../src/shared/Data/Spawns")
local T = require("./Test")

local LEVEL_SLACK = 12

type Found = { min: number, max: number }

-- Level range of spawners matching an objective, nil when nothing spawns it.
local function spawnRange(objective: any): Found?
	local found: Found? = nil
	for _, spawners in Spawns.byMap do
		for _, spawner in spawners do
			local def = Monsters.get(spawner.monster)
			local matches = def ~= nil
				and (objective.monster == nil or spawner.monster == objective.monster)
				and (objective.region == nil or (def :: any).region == objective.region)
				and (
					objective.variant == nil
					or (objective.variant == "elite" and spawner.variant ~= "normal")
					or spawner.variant == objective.variant
				)
			if matches then
				if not found then
					found = { min = spawner.level.min, max = spawner.level.max }
				else
					local f = found :: Found
					f.min = math.min(f.min, spawner.level.min)
					f.max = math.max(f.max, spawner.level.max)
				end
			end
		end
	end
	return found
end

T.describe("Main story playthrough", function()
	T.it("every kill and collect objective has spawners near the quest level", function()
		local problems = {}
		for _, quest in Quests.Main.list do
			for _, objective in quest.objectives do
				if objective.type == "kill" or objective.type == "collect" then
					local range = spawnRange(objective)
					if not range then
						table.insert(
							problems,
							`{quest.id}: nothing spawns {objective.monster or "region " .. tostring(objective.region)}`
						)
					elseif quest.level + LEVEL_SLACK < range.min or quest.level - LEVEL_SLACK > range.max then
						table.insert(problems, `{quest.id} (lv {quest.level}): spawns at {range.min}-{range.max}`)
					end
				end
			end
		end
		T.expect(problems).toEqual({})
	end)

	T.it("collect chances make the objective reachable in a sensible number of kills", function()
		for _, quest in Quests.Main.list do
			for _, objective in quest.objectives do
				if objective.type == "collect" then
					local expectedKills = objective.n / (objective.chance or 0)
					if expectedKills > 60 then
						error(`{quest.id}: ~{math.floor(expectedKills)} kills for {objective.item}`)
					end
				end
			end
		end
	end)

	T.it("goes from the start to level 100 without gaps over 15 levels", function()
		local list = Quests.Main.list
		T.expect(list[1].level).toBe(1)
		T.expect(list[#list].level >= 95).toBe(true)
		for i = 2, #list do
			if list[i].level - list[i - 1].level > 15 then
				error(`gap before {list[i].id}: {list[i - 1].level} -> {list[i].level}`)
			end
		end
	end)
end)

return nil
