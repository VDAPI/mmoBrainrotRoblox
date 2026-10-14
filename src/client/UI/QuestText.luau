--!strict
-- Client helpers for quests (S11): objective labels in the player's language, where an objective points to
-- (for the direction arrow and the minimap) and the marker of an NPC ("!" / "?" / grey "?"). S99: the hunting
-- contract title (one key with arguments) and target. S101b: the saved answer leads the tracker (`focus`: another
-- objective first, `hint`: an extra point; one helper `withDialogue` for the story and side quests) and the `escort`
-- objective points at the companion while it is far, else at the goal. S102: one helper for where an objective points
-- (objectiveTarget: anchors, NPCs, places, areas) for the story and the side quests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AreaAdvice = require(ReplicatedStorage.Shared.Logic.AreaAdvice)
local AreaProfileText = require(script.Parent.AreaProfileText)
local AreaProfiles = require(ReplicatedStorage.Shared.Data.AreaProfiles)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Companion = require(ReplicatedStorage.Shared.Logic.Companion)
local Config = require(ReplicatedStorage.Shared.Config)
local Dialogue = require(ReplicatedStorage.Shared.Logic.Dialogue)
local GatherNodes = require(ReplicatedStorage.Shared.Data.GatherNodes)
local LevelBand = require(ReplicatedStorage.Shared.Logic.LevelBand)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NpcMarks = require(ReplicatedStorage.Shared.Logic.NpcMarks)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestRows = require(ReplicatedStorage.Shared.Logic.QuestRows)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local State = require(script.Parent.State)
local Text = require(script.Parent.Text)
local Theme = require(script.Parent.Theme)

local QuestText = {}

type Objective = Quests.Objective

local REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }

-- S95: an objective's NPC for this character ("classVendor" = the vendor of the player's class).
local function objectiveNpc(npc: string?): string?
	return QuestLogic.npcFor(npc, State.Get({ "character", "class" }))
end

-- Localized label of an objective with its progress, e.g. "Defeat: Grey Wolf 3/8".
-- `turnIn` names the NPC of a deliver objective without its own `npc` (S27).
function QuestText.objective(use: any, objective: Objective, have: number, turnIn: string?): string
	local t = objective.type
	local count = `{math.min(have, objective.n)}/{objective.n}`
	-- S27: "in <area>" after kill / collect objectives limited to a monster area.
	local area = objective.area and Areas.areaById(objective.area)
	local where = if area then Text.get(use, "quest.obj.inArea", { area = Text.get(use, area.nameKey) }) else ""
	if t == "talk" then
		local npc = Npcs.get(objectiveNpc(objective.npc) or "")
		return Text.get(use, "quest.obj.talk", { npc = if npc then Text.get(use, npc.nameKey) else "?" })
	elseif t == "deliver" then
		local npc = Npcs.get(objectiveNpc(objective.npc) or turnIn or "")
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
		-- S99: only an area (the hunting contracts): "Defeat monsters: <area> 3/30", no "in <area>" suffix
		if area and not objective.region and not objective.variant then
			return Text.get(use, "quest.obj.killArea", { area = Text.get(use, area.nameKey), count = count })
		end
		local map = Maps.get(REGION_MAPS[objective.region or 1] or "")
		-- S98: "elite2" = Elite II only (weekly contracts)
		local key = if objective.variant == "elite2"
			then "quest.obj.killElite2"
			elseif objective.variant == "elite" then "quest.obj.killElite"
			else "quest.obj.killRegion"
		return Text.get(use, key, {
			region = if map then Text.get(use, map.nameKey) else "?",
			count = count,
		})
	elseif t == "collect" then
		-- S104: loot of Elites only ("Get: Supply Ledger (Ash Orc Overseer) 0/1"), named like the elite kills
		local def = if objective.variant == "elite" and objective.monster then Monsters.get(objective.monster) else nil
		if def then
			return Text.get(use, "quest.obj.collectFrom", {
				item = Text.get(use, `quest.item.{objective.item}`),
				monster = Text.get(use, def.nameKeys.elite),
				count = count,
			}) .. where
		end
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
		-- S98: no node and no category = herbs or ore (the weekly "gather" contract)
		local key = if objective.category == "ore"
			then "quest.obj.gatherOre"
			elseif objective.category == "herb" then "quest.obj.gatherHerb"
			else "quest.obj.gatherAny"
		return Text.get(use, key, { count = count })
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
	elseif t == "escort" then
		-- S101b: walk with the leading companion
		local npc = Npcs.get(objective.npc or "")
		return Text.get(use, "quest.obj.escort", {
			npc = if npc then Text.get(use, npc.nameKey) else "?",
			place = Text.get(use, objective.place or "quest.tracker"),
		})
	end
	-- fish, equip, loot, stats, learn, potion, duel, event (S98: world events, counted from S101)
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

-- S101b: `place` = locale key of a point's name (a dialogue hint), shown under the star on the world map.
export type Target = { map: string, x: number?, z: number?, npc: string?, place: string? }

-- S101b: the companion figure of the local player (Workspace.World.Companions), if streamed in.
local function companionFigure(): BasePart?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Companions")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("CompanionOf") == Players.LocalPlayer.UserId then
			return model:FindFirstChild("HumanoidRootPart") :: BasePart?
		end
	end
	return nil
end

-- S101b: an escort objective points at the companion while it is farther than Config.Companion.waitDist from the
-- player, else at the goal; when the companion went back, at its start.
local function escortTarget(quest: any, objective: Objective): Target?
	local map = Maps.get(objective.map or "")
	if not map then
		return nil
	end
	local figure = companionFigure()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if figure and root then
		local gap = Vector3.new(figure.Position.X - root.Position.X, 0, figure.Position.Z - root.Position.Z)
		if gap.Magnitude > Config.Companion.waitDist then
			return {
				map = map.id,
				x = figure.Position.X - map.offset.x,
				z = figure.Position.Z - map.offset.z,
				npc = objective.npc,
			}
		end
		return { map = map.id, x = objective.x, z = objective.z, place = objective.place }
	end
	local def = quest.companion
	local from = if def then Companion.fromOf(def) else nil
	if from and State.Get({ "companion", "phase" }) == "back" then
		return { map = map.id, x = from.x, z = from.z }
	end
	return { map = map.id, x = objective.x, z = objective.z, place = objective.place }
end

-- S101b: the saved answer of a quest leads the tracker. `pick(index)` is where objective `index` points by the
-- caller's own rules (and whether that point is precise). `focus` starts at that objective while it is open; `hint`
-- is the point when the first open objective points nowhere better (kill / collect without an area or `where`, talk
-- to an NPC on another map). S102 moves this into the shared objectiveTarget.
local function withDialogue(
	quest: any,
	quests: any,
	progress: { number },
	pick: (index: number) -> (Target?, boolean)
): Target?
	if quests == nil then
		return nil
	end
	local focus = Dialogue.focusOf(quest, quests)
	local focused = if focus then quest.objectives[focus] else nil
	if focus and focused and (progress[focus] or 0) < focused.n then
		local target = pick(focus)
		if target then
			return target
		end
	end
	local hint: any = Dialogue.hintOf(quest, quests)
	if hint then
		local first: number? = nil
		for i, objective in quest.objectives do
			if (progress[i] or 0) < objective.n then
				first = i
				break
			end
		end
		if first then
			local target, precise = pick(first)
			local here = State.Get({ "character", "location", "map" })
			local vague = target == nil
				or not precise
				or (quest.objectives[first].type == "talk" and target.map ~= here)
			if vague then
				return { map = hint.map, x = hint.x, z = hint.z, place = hint.place }
			end
		end
	end
	return nil
end

local function npcTarget(npcId: string?): Target?
	local npc = Npcs.get(npcId or "")
	return if npc then { map = npc.map, x = npc.position.x, z = npc.position.z, npc = npc.id } else nil
end

-- An objective's area: a named area (its middle) or a cave id (review S102): inside that cave the cave itself (no
-- point, the arrow rests), elsewhere the mouth on its region map like AreaAdvice.caveFor.
local function areaTarget(areaId: string?): Target?
	local area, mapId = Areas.areaById(areaId or "")
	if area and mapId then
		local x, z = AreaAdvice.centre(area)
		return { map = mapId, x = x, z = z }
	end
	local cave = Areas.caves.get(areaId or "")
	if cave then
		if State.Get({ "character", "location", "map" }) == cave.id then
			return { map = cave.id }
		end
		local mouth = Areas.arrivalOf(cave.id)
		if mouth then
			return { map = cave.region, x = mouth.x, z = mouth.z }
		end
	end
	return nil
end

-- S102: where one open objective points by the rules shared by the story and the side quests: an anchor not used
-- yet, the NPC to talk / deliver to (`turnIn` for a deliver without its own NPC), the place or map to reach, the area
-- of a kill / collect objective; nil = the caller's own rules (monster kinds, bosses, hints).
local function objectiveTarget(objective: Objective, used: { string }, turnIn: string): Target?
	local t = objective.type
	if t == "use" then
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
		return npcTarget(objectiveNpc(objective.npc))
	elseif t == "deliver" then
		return npcTarget(objectiveNpc(objective.npc) or turnIn)
	elseif t == "reach" and objective.map then
		return { map = objective.map, x = objective.x, z = objective.z }
	elseif (t == "kill" or t == "collect") and objective.area then
		return areaTarget(objective.area)
	end
	return nil
end

-- Where the first unfinished objective of a quest points (NPC, map) or the turn-in NPC when done. S22: kill and
-- collect objectives point at the middle of the area with that monster at the player's level (or the lowest
-- such area); elite kills at the mouth of the cave with that elite. S101b: `quests` (optional) lets the saved answer
-- lead (withDialogue). S102: `used` = the anchors the active story quest already used (quests.main.used); anchors,
-- deliveries, places and areas point like in the side quests (objectiveTarget).
function QuestText.target(
	quest: Quests.MainQuest,
	progress: { number },
	level: number?,
	quests: any?,
	used: { string }?
): Target?
	if QuestLogic.isComplete(progress, quest.objectives) then
		local npc = Npcs.get(quest.turnIn)
		return if npc then { map = npc.map, x = npc.position.x, z = npc.position.z, npc = npc.id } else nil
	end
	local led = withDialogue(quest, quests, progress, function(index: number): (Target?, boolean)
		-- the plain rules for this one objective: every other one counts as done
		local one: { number } = {}
		for i, objective in quest.objectives do
			one[i] = if i == index then (progress[i] or 0) else objective.n
		end
		local objective = quest.objectives[index]
		local precise = not ((objective.type == "kill" or objective.type == "collect") and not objective.area)
		return QuestText.target(quest, one, level, nil, used), precise
	end)
	if led then
		return led
	end
	for i, objective in quest.objectives do
		if (progress[i] or 0) < objective.n then
			if objective.type == "escort" then
				return escortTarget(quest, objective)
			end
			local shared = objectiveTarget(objective, used or {}, quest.turnIn)
			if shared then
				return shared
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

-- S27: where a side quest points: its turn-in NPC when complete, else the first open objective (an anchor not used
-- yet, the NPC to talk / deliver to, the objective's area, the place to reach), else the quest's `where` hint.
function QuestText.sideTarget(quest: Quests.SideQuest, entry: any, level: number?, quests: any?): Target?
	if SideQuests.isComplete(entry, quest) then
		return npcTarget(quest.turnIn)
	end
	local progress: { number } = if type(entry) == "table" then entry.progress or {} else {}
	local led = withDialogue(quest, quests, progress, function(index: number): (Target?, boolean)
		-- the plain rules for this one objective: every other one counts as done
		local one = { progress = {} :: { number }, used = if type(entry) == "table" then entry.used or {} else {} }
		for i, objective in quest.objectives do
			one.progress[i] = if i == index then (progress[i] or 0) else objective.n
		end
		local objective = quest.objectives[index]
		local t = objective.type
		local precise = not ((t == "kill" or t == "collect") and not objective.area and not quest.where)
		return QuestText.sideTarget(quest, one, level), precise
	end)
	if led then
		return led
	end
	local index = SideQuests.currentObjective(entry, quest)
	local objective = if index then quest.objectives[index] else nil
	if objective then
		local t = objective.type
		if t == "escort" then
			return escortTarget(quest, objective)
		end
		local used: { string } = if type(entry) == "table" then entry.used or {} else {}
		local shared = objectiveTarget(objective, used, quest.turnIn)
		if shared then
			return shared
		elseif t == "talk" or t == "deliver" then
			-- an unknown NPC (never in the data): nowhere, like before
			return nil
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
		elseif t == "boss" and objective.boss then
			-- Slayer quests (S98): the dungeon entrance, like the story's boss objective
			local fake: Quests.MainQuest = {
				id = quest.id,
				level = quest.level,
				giver = quest.giver,
				turnIn = quest.turnIn,
				objectives = { objective },
				reward = quest.reward,
			}
			local target = QuestText.target(fake, { 0 }, level)
			if target then
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

-- S99: the title of a hunting contract ("Hunting contract 12: Crow Field"); `lookup` = Text.get bound to a scope's
-- `use` or the T of a card.
function QuestText.contractTitle(
	lookup: (key: string, args: { [string]: any }?) -> string,
	contract: Quests.ContractQuest
): string
	local area = Areas.areaById(contract.area)
	return lookup("contract.title", { n = contract.level, area = if area then lookup(area.nameKey) else "?" })
end

-- S99: the hunting ground of a contract as rich text: its name and levels in the colour of the level band for the
-- character, then the S33 profile tag in its colour.
function QuestText.contractAreaLine(use: any, contract: Quests.ContractQuest, level: number): string
	local area = Areas.areaById(contract.area)
	if not area then
		return ""
	end
	local color: string = LevelBand.COLORS[AreaAdvice.bandOf(area, level)]
	local name = `{Text.get(use, area.nameKey)} ({area.lv[1]}–{area.lv[2]})`
	local line = `<font color="{color}">{name}</font>`
	local profile = AreaProfiles.ofArea(area.id)
	if profile then
		local hex = "#" .. AreaProfileText.color(profile):ToHex()
		line ..= `  <font color="{hex}">{AreaProfileText.tag(use, profile)}</font>`
	end
	return line
end

-- S99: the scout of a contract's region (the other place to take and hand it in).
function QuestText.contractScout(contract: Quests.ContractQuest): string
	return `scout_{contract.map}`
end

-- S99: where a hunting contract points: done -> its scout when the player is on that map, else the board; open or
-- not taken yet -> the middle of its hunting ground.
function QuestText.contractTarget(
	contract: Quests.ContractQuest,
	active: { level: number, progress: { number } }?,
	_level: number?,
	currentMap: string?
): Target?
	if active and QuestLogic.isComplete(active.progress, contract.objectives) then
		local scout = Npcs.get(QuestText.contractScout(contract))
		if scout and currentMap == scout.map then
			return npcTarget(scout.id)
		end
		return npcTarget(NpcMarks.BOARD)
	end
	return areaTarget(contract.area)
end

export type Marker = NpcMarks.Mark?

-- Marker above an NPC for the character's quests (S25: Logic/NpcMarks, shared with the maps).
function QuestText.marker(npcId: string, quests: any, level: number): Marker
	return NpcMarks.of(npcId, quests, level)
end

return QuestText
