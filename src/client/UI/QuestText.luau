--!strict
-- Client helpers for quests (S11): objective labels in the player's language, where an objective points to
-- (for the direction arrow and the minimap) and the marker of an NPC ("!" / "?" / grey "?").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local GatherNodes = require(ReplicatedStorage.Shared.Data.GatherNodes)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestRows = require(ReplicatedStorage.Shared.Logic.QuestRows)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Text = require(script.Parent.Text)
local Theme = require(script.Parent.Theme)

local QuestText = {}

type Objective = Quests.Objective

local REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }

-- Localized label of an objective with its progress, e.g. "Defeat: Grey Wolf 3/8".
-- `turnIn` names the NPC of a deliver objective without its own `npc` (S27).
function QuestText.objective(use: any, objective: Objective, have: number, turnIn: string?): string
	local t = objective.type
	local count = `{math.min(have, objective.n)}/{objective.n}`
	-- S27: "in <area>" after kill / collect objectives limited to a monster area.
	local area = objective.area and Areas.areaById(objective.area)
	local where = if area then Text.get(use, "quest.obj.inArea", { area = Text.get(use, area.nameKey) }) else ""
	if t == "talk" then
		local npc = Npcs.get(objective.npc or "")
		return Text.get(use, "quest.obj.talk", { npc = if npc then Text.get(use, npc.nameKey) else "?" })
	elseif t == "deliver" then
		local npc = Npcs.get(objective.npc or turnIn or "")
		return Text.get(use, "quest.obj.deliver", {
			item = Text.get(use, `quest.item.{objective.item}`),
			npc = if npc then Text.get(use, npc.nameKey) else "?",
		})
	elseif t == "use" then
		local label = Text.get(use, objective.action or "quest.use.default")
		return if objective.n > 1 then `{label} {count}` else label
	elseif t == "kill" then
		if objective.monster then
			local def = Monsters.get(objective.monster)
			local key = if def
				then (if objective.variant == "elite" then def.nameKeys.elite else def.nameKeys.normal)
				else "?"
			return Text.get(use, "quest.obj.kill", { monster = Text.get(use, key), count = count }) .. where
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
		) .. where
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
		if objective.place then
			return Text.get(use, "quest.obj.reach", { map = Text.get(use, objective.place) })
		end
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

-- S29: the objective rows of a quest with localized labels (Logic/QuestRows): every objective stays, finished
-- ones are done, and a complete quest names its turn-in NPC.
function QuestText.rows(use: any, objectives: { Objective }, progress: { number }?, turnIn: string?): QuestRows.List
	return QuestRows.build(objectives, progress, turnIn, function(objective: Objective, have: number): string
		return QuestText.objective(use, objective, have, turnIn)
	end)
end

-- S29: "Return to: <NPC>" of a complete quest ("" without a turn-in NPC).
function QuestText.returnTo(use: any, list: QuestRows.List): string
	local npc = list.turnIn and Npcs.get(list.turnIn)
	return if npc then Text.get(use, "quest.tracker.returnTo", { npc = Text.get(use, npc.nameKey) }) else ""
end

local SUCCESS_HEX = "#" .. Theme.Colors.Success:ToHex()
local GOLD_HEX = "#" .. Theme.Colors.GoldBright:ToHex()

-- S29: the rows as rich text lines for the journal and the NPC dialog: finished objectives green with a "✔" and a
-- soft glow, open ones with a bullet, then the gold "Return to: <NPC>" line when complete (`withReturn`).
function QuestText.richRows(use: any, list: QuestRows.List, withReturn: boolean?): { string }
	local lines: { string } = {}
	for _, row in list.rows do
		local line = QuestRows.line(row)
		table.insert(
			lines,
			if row.done
				then `<stroke color="{SUCCESS_HEX}" thickness="1" transparency="0.65"><font color="{SUCCESS_HEX}">{line}</font></stroke>`
				else line
		)
	end
	if withReturn ~= false and list.complete then
		local back = QuestText.returnTo(use, list)
		if back ~= "" then
			table.insert(lines, `<font color="{GOLD_HEX}"><b>{back}</b></font>`)
		end
	end
	return lines
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

local function npcTarget(npcId: string?): Target?
	local npc = Npcs.get(npcId or "")
	return if npc then { map = npc.map, x = npc.position.x, z = npc.position.z, npc = npc.id } else nil
end

local function areaTarget(areaId: string?): Target?
	local area, mapId = Areas.areaById(areaId or "")
	if area and mapId then
		local x, z = AreaAdvice.centre(area)
		return { map = mapId, x = x, z = z }
	end
	return nil
end

-- S27: where a side quest points: its turn-in NPC when complete, else the first open objective (an anchor not used
-- yet, the NPC to talk / deliver to, the objective's area, the place to reach), else the quest's `where` hint.
function QuestText.sideTarget(quest: Quests.SideQuest, entry: any, level: number?): Target?
	if SideQuests.isComplete(entry, quest) then
		return npcTarget(quest.turnIn)
	end
	local index = SideQuests.currentObjective(entry, quest)
	local objective = if index then quest.objectives[index] else nil
	if objective then
		local t = objective.type
		if t == "use" then
			local used: { string } = if type(entry) == "table" then entry.used or {} else {}
			local anchors: { string } = objective.anchors or { objective.anchor :: string }
			for _, id in anchors do
				if not table.find(used, id) then
					local anchor, mapId = Areas.anchorById(id)
					if anchor and mapId then
						return { map = mapId, x = anchor.x, z = anchor.z }
					end
				end
			end
		elseif t == "talk" then
			return npcTarget(objective.npc)
		elseif t == "deliver" then
			return npcTarget(objective.npc or quest.turnIn)
		elseif t == "reach" and objective.map then
			return { map = objective.map, x = objective.x, z = objective.z }
		elseif (t == "kill" or t == "collect") and objective.area then
			local target = areaTarget(objective.area)
			if target then
				return target
			end
		end
		if (t == "kill" or t == "collect") and objective.monster then
			-- the same rules as the story (S22): the area with that monster at the level, elites in their cave
			local fake: Quests.MainQuest = {
				id = quest.id,
				level = quest.level,
				giver = quest.giver,
				turnIn = quest.turnIn,
				objectives = { objective },
				reward = quest.reward,
			}
			local target = QuestText.target(fake, { 0 }, level)
			if target and not quest.where then
				return target
			end
		end
	end
	local hint = quest.where
	if hint then
		if hint.area then
			return areaTarget(hint.area)
		end
		return { map = hint.map, x = hint.x, z = hint.z }
	end
	return nil
end

export type Marker = NpcMarks.Mark?

-- Marker above an NPC for the character's quests (S25: Logic/NpcMarks, shared with the maps).
function QuestText.marker(npcId: string, quests: any, level: number): Marker
	return NpcMarks.of(npcId, quests, level)
end

return QuestText
