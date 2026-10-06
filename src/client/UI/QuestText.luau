--!strict
-- Client helpers for quests (S11): objective labels in the player's language, where an objective points to
-- (for the direction arrow and the minimap) and the marker of an NPC ("!" / "?" / grey "?").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local GatherNodes = require(ReplicatedStorage.Shared.Data.GatherNodes)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Text = require(script.Parent.Text)

local QuestText = {}

type Objective = Quests.Objective

local REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }

-- Localized label of an objective with its progress, e.g. "Defeat: Grey Wolf 3/8".
function QuestText.objective(use: any, objective: Objective, have: number): string
	local t = objective.type
	local count = `{math.min(have, objective.n)}/{objective.n}`
	if t == "talk" then
		local npc = Npcs.get(objective.npc or "")
		return Text.get(use, "quest.obj.talk", { npc = if npc then Text.get(use, npc.nameKey) else "?" })
	elseif t == "kill" then
		if objective.monster then
			local def = Monsters.get(objective.monster)
			local key = if def
				then (if objective.variant == "elite" then def.nameKeys.elite else def.nameKeys.normal)
				else "?"
			return Text.get(use, "quest.obj.kill", { monster = Text.get(use, key), count = count })
		end
		local map = Maps.get(REGION_MAPS[objective.region or 1] or "")
		return Text.get(use, if objective.variant == "elite" then "quest.obj.killElite" else "quest.obj.killRegion", {
			region = if map then Text.get(use, map.nameKey) else "?",
			count = count,
		})
	elseif t == "collect" then
		return Text.get(
			use,
			"quest.obj.collect",
			{ item = Text.get(use, `quest.item.{objective.item}`), count = count }
		)
	elseif t == "gather" then
		if objective.node then
			local kind = GatherNodes.get(objective.node)
			return Text.get(
				use,
				"quest.obj.gather",
				{ node = if kind then Text.get(use, kind.nameKey) else "?", count = count }
			)
		end
		return Text.get(use, if objective.category == "ore" then "quest.obj.gatherOre" else "quest.obj.gatherHerb", {
			count = count,
		})
	elseif t == "reach" then
		local map = Maps.get(objective.map or "")
		return Text.get(use, "quest.obj.reach", { map = if map then Text.get(use, map.nameKey) else "?" })
	elseif t == "boss" then
		local boss = Bosses.get(objective.boss or "")
		if boss then
			return Text.get(use, "quest.obj.boss", { boss = Text.get(use, boss.nameKey) })
		end
		return Text.get(use, "quest.obj.bossAny")
	elseif t == "upgrade" then
		return Text.get(use, "quest.obj.upgrade", { up = objective.up or 1 })
	elseif t == "level" then
		return Text.get(use, "quest.obj.level", { level = objective.level or 1 })
	end
	-- fish, equip, loot, stats, learn, potion, duel
	return Text.get(use, `quest.obj.{t}`, { count = count })
end

export type Target = { map: string, x: number?, z: number?, npc: string? }

-- Where the first unfinished objective of a quest points (NPC, map) or the turn-in NPC when done. S22: kill and
-- collect objectives point at the middle of the area with that monster at the player's level (or the lowest
-- such area); elite kills at the mouth of the cave with that elite.
function QuestText.target(quest: Quests.MainQuest, progress: { number }, level: number?): Target?
	if QuestLogic.isComplete(progress, quest.objectives) then
		local npc = Npcs.get(quest.turnIn)
		return if npc then { map = npc.map, x = npc.position.x, z = npc.position.z, npc = npc.id } else nil
	end
	for i, objective in quest.objectives do
		if (progress[i] or 0) < objective.n then
			if objective.type == "talk" then
				local npc = Npcs.get(objective.npc or "")
				return if npc then { map = npc.map, x = npc.position.x, z = npc.position.z, npc = npc.id } else nil
			elseif objective.type == "reach" and objective.map then
				return { map = objective.map, x = objective.x, z = objective.z }
			elseif (objective.type == "kill" or objective.type == "collect") and objective.monster then
				if objective.variant == "elite" or objective.variant == "elite2" then
					local cave, mouth = AreaAdvice.caveFor(objective.monster)
					if cave and mouth then
						return { map = cave.region, x = mouth.x, z = mouth.z }
					end
				end
				local area, mapId = AreaAdvice.forKind(objective.monster, level or 1)
				if area and mapId then
					local x, z = AreaAdvice.centre(area)
					return { map = mapId, x = x, z = z }
				end
				local cave, mouth = AreaAdvice.caveFor(objective.monster)
				if cave and mouth then
					return { map = cave.region, x = mouth.x, z = mouth.z }
				end
			elseif objective.type == "boss" and objective.boss then
				local boss = Bosses.get(objective.boss)
				for _, map in Maps.byId do
					if boss and map.dungeonRegion == boss.region and map.dungeonEntrance then
						return { map = map.id, x = map.dungeonEntrance.x, z = map.dungeonEntrance.z }
					end
				end
			end
			return nil
		end
	end
	return nil
end

export type Marker = NpcMarks.Mark?

-- Marker above an NPC for the character's quests (S25: Logic/NpcMarks, shared with the maps).
function QuestText.marker(npcId: string, quests: any, level: number): Marker
	return NpcMarks.of(npcId, quests, level)
end

return QuestText
