--!strict
-- Side quests (S27, DESIGN §20, Data/Quests/Side): several active at once (character.quests.side), taken from
-- their giver NPC, progressed by the same gameplay events as the story (QuestService.handle passes every event
-- here), handed in at their turn-in NPC with a reward choice on an arc's last quest, abandoned from the journal.
-- World interactions (`use` objectives): QuestUse(anchorId) holds for the objective's time at a quest anchor (parts
-- tagged QuestAnchor, built by the map layouts from Data/Areas) like gathering; moving or taking damage breaks it.
-- Rules live in Logic/SideQuests (shared with the client's dialog, journal and quest marks).
--   SideAccept(questId) · SideTurnIn(questId, choiceIndex?) · SideAbandon(questId) · QuestUse(anchorId) ·
--   CancelQuestUse()

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Quests = require(Shared.Data.Quests)
local Rng = require(Shared.Logic.Rng)
local SideQuests = require(Shared.Logic.SideQuests)
local Types = require(Shared.Types)

local log = Log.new("SideQuestService")

local SideQuestService = {
	Name = "SideQuestService",
	Deps = {
		"PlayerStateService",
		"InventoryService",
		"LevelService",
		"NpcService",
		"ResourceService",
		"CharacterService",
		"ZoneService",
		"WorldService",
	},
}

local PlayerStateService: any
local InventoryService: any
local LevelService: any
local NpcService: any
local ResourceService: any
local CharacterService: any
local ZoneService: any

local rng = Rng.new()

local ANCHOR_TAG = "QuestAnchor"
local RANGE_TOLERANCE = 3
local REACH_POLL = 1

-- Quest anchors in the world: id -> part (registered from the tag; the world is built in WorldService.Init).
local anchors: { [string]: BasePart } = {}

-- Running `use` holds: player -> token, anchor.
type Hold = { token: number, anchor: string }
local holds: { [Player]: Hold } = {}
local holdCounter = 0

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function itemArg(item: string): string
	return `@quest.item.{item}`
end

local function npcArg(npcId: string): string
	local def = Npcs.get(npcId)
	return if def then `@{def.nameKey}` else npcId
end

local function sideOf(char: Types.CharacterData): { active: { [string]: Types.SideEntry }, done: { [string]: boolean } }
	return char.quests.side
end

local function setEntry(player: Player, id: string, entry: Types.SideEntry?)
	PlayerStateService.Set(player, { "character", "quests", "side", "active", id }, entry)
end

-- A copy of an entry that can be changed and published (the state layer diffs by assignment).
local function copyEntry(entry: Types.SideEntry): Types.SideEntry
	return {
		progress = table.clone(entry.progress or {}),
		used = table.clone(entry.used or {}),
		choice = entry.choice,
	}
end

-- Rolls the reward choice once (when the quest is complete) and stores it in the entry.
local function ensureChoice(player: Player, quest: Quests.SideQuest, entry: Types.SideEntry): Types.SideEntry
	if not quest.reward.choice or (entry.choice and #entry.choice > 0) then
		return entry
	end
	local char = character(player)
	if not char then
		return entry
	end
	local updated = copyEntry(entry)
	updated.choice = SideQuests.rollChoice(quest, char.class, rng, InventoryService.NewUid)
	return updated
end

-- Applies a gameplay event to every active side quest (QuestService.handle calls this for every event).
function SideQuestService.Handle(player: Player, kind: string, data: { [string]: any })
	local char = character(player)
	if not char then
		return
	end
	for id, entry in sideOf(char).active do
		local quest = Quests.Side.get(id)
		if not quest or SideQuests.isComplete(entry, quest) then
			continue
		end
		local updated = copyEntry(entry)
		local changed = SideQuests.advance(updated, quest, kind, data, rng)
		if #changed == 0 then
			continue
		end
		for _, index in changed do
			local objective = quest.objectives[index]
			if objective.type == "collect" and objective.item then
				Net.Fire(player, "Toast", "quest.collected", {
					item = itemArg(objective.item),
					have = updated.progress[index],
					n = objective.n,
				}, "success")
			end
		end
		if SideQuests.isComplete(updated, quest) then
			updated = ensureChoice(player, quest, updated)
			Net.Fire(player, "Toast", "quest.ready", {
				title = `@quest.{quest.id}.title`,
				npc = npcArg(quest.turnIn),
			}, "success")
		end
		setEntry(player, id, updated)
	end
end

-- Map-relative position of a player's character and the map it stands on.
local function whereIs(player: Player): (string?, number, number)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local zone = ZoneService.GetZone(player)
	local map = zone and Maps.get(zone.map)
	if not root or not map then
		return nil, 0, 0
	end
	return map.id, root.Position.X - map.offset.x, root.Position.Z - map.offset.z
end

-- Counts what already holds when a quest starts: the current map / place and the level.
local function catchUp(player: Player)
	local char = character(player)
	if not char then
		return
	end
	local map, x, z = whereIs(player)
	SideQuestService.Handle(player, "reach", { map = map or char.location.map, x = x, z = z })
	SideQuestService.Handle(player, "level", { level = char.level })
end

-- Remotes ----------------------------------------------------------------------------------------------------------

local function accept(player: Player, questId: string): (boolean, string?)
	local char = character(player)
	local quest = Quests.Side.get(questId)
	if not char or not quest then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, quest.giver) then
		return false, "npc.error.tooFar"
	end
	local ok, reason = SideQuests.canAccept(char.quests, char.level, quest)
	if not ok then
		return false, `quest.side.error.{reason}`
	end
	setEntry(player, quest.id, SideQuests.newEntry(quest))
	for _, objective in quest.objectives do
		if objective.type == "deliver" and objective.item then
			Net.Fire(player, "Toast", "quest.deliverGot", { item = itemArg(objective.item) }, "info")
		end
	end
	catchUp(player)
	log:info("%s accepted %s", player.Name, quest.id)
	return true, nil
end

local function turnIn(player: Player, questId: string, choiceIndex: number?): (boolean, string?)
	local char = character(player)
	local quest = Quests.Side.get(questId)
	if not char or not quest then
		return false, "error.badRequest"
	end
	local entry = sideOf(char).active[questId]
	if not entry then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, quest.turnIn) then
		return false, "npc.error.tooFar"
	end
	-- Talking to the turn-in NPC counts first (talk / deliver objectives that end here).
	SideQuestService.Handle(player, "talk", { npc = quest.turnIn })
	entry = sideOf(char).active[questId]
	if not entry or not SideQuests.isComplete(entry, quest) then
		return false, "quest.error.notDone"
	end
	local chosen: Types.ItemInstance? = nil
	if quest.reward.choice then
		entry = ensureChoice(player, quest, entry)
		local options = entry.choice or {}
		if #options > 0 then
			if not choiceIndex or choiceIndex < 1 or choiceIndex > #options then
				setEntry(player, questId, entry)
				return false, "quest.side.error.choose"
			end
			chosen = options[choiceIndex]
		end
	end
	if chosen and not InventoryService.CanFit(player, { chosen }) then
		return false, "inventory.full"
	end
	setEntry(player, questId, nil)
	PlayerStateService.Set(player, { "character", "quests", "side", "done", questId }, true)
	LevelService.GiveExp(player, quest.reward.exp, "quest")
	PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold + quest.reward.gold
	end)
	local items: { { id: string, n: number } } = quest.reward.items or {}
	for _, item in items do
		InventoryService.GiveNew(player, item.id, item.n)
	end
	if chosen then
		InventoryService.AddItem(player, chosen)
	end
	Net.Fire(player, "CombatFx", { { k = "reward", exp = quest.reward.exp, gold = quest.reward.gold } })
	Net.Fire(player, "QuestCompleted", `quest.{quest.id}.title`)
	log:info("%s completed %s", player.Name, quest.id)
	return true, nil
end

local function abandon(player: Player, questId: string): (boolean, string?)
	local char = character(player)
	if not char or not sideOf(char).active[questId] then
		return false, "error.badRequest"
	end
	setEntry(player, questId, nil)
	return true, nil
end

-- World interactions -----------------------------------------------------------------------------------------------

local function stopHold(player: Player, notify: boolean)
	if not holds[player] then
		return
	end
	holds[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "questUse" }, nil)
	end
	if notify then
		Net.Fire(player, "Toast", "quest.use.interrupted", nil, "warning")
	end
end

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function useAnchor(player: Player, anchorId: string): (boolean, string?)
	local char = character(player)
	local part = anchors[anchorId]
	if not char or not part then
		return false, "error.badRequest"
	end
	if ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	if holds[player] then
		return false, "gather.already"
	end
	local target = SideQuests.usableAnchors(char.quests)[anchorId]
	if not target then
		return false, "quest.use.notNeeded"
	end
	local root = rootOf(player)
	if not root then
		return false, "error.wrongPhase"
	end
	local offset = root.Position - part.Position
	if Vector3.new(offset.X, 0, offset.Z).Magnitude > Config.SideQuest.useRange + RANGE_TOLERANCE then
		return false, "npc.error.tooFar"
	end
	local quest = Quests.Side.get(target.quest)
	local objective = quest and quest.objectives[target.index]
	if not quest or not objective then
		return false, "error.badRequest"
	end
	holdCounter += 1
	local token = holdCounter
	holds[player] = { token = token, anchor = anchorId }
	local duration = objective.hold or 2
	PlayerStateService.Set(player, { "questUse" }, {
		endsAt = Workspace:GetServerTimeNow() + duration,
		duration = duration,
		label = objective.action or "quest.use.default",
		anchor = anchorId,
	})
	local start = root.Position
	task.spawn(function()
		local finishAt = os.clock() + duration
		while os.clock() < finishAt do
			task.wait(0.1)
			local current = holds[player]
			if not current or current.token ~= token then
				return
			end
			local now = rootOf(player)
			if
				not now
				or ((now.Position - start) * Vector3.new(1, 0, 1)).Magnitude > Config.SideQuest.useMoveLimit
				or ResourceService.IsDead(player)
			then
				stopHold(player, true)
				return
			end
		end
		local current = holds[player]
		if not current or current.token ~= token then
			return
		end
		stopHold(player, false)
		-- Through QuestEvents so the story and the contracts see it too (QuestService.handle -> Handle here).
		QuestEvents.fire(player, "use", { anchor = anchorId })
		Net.Fire(
			player,
			"Toast",
			"quest.use.done",
			{ action = `@{objective.action or "quest.use.default"}` },
			"success"
		)
	end)
	return true, nil
end

-- Admin ----------------------------------------------------------------------------------------------------------

-- /side give <id>: makes the quest active (requirements and limit ignored).
function SideQuestService.Give(player: Player, questId: string): boolean
	local quest = Quests.Side.get(questId)
	local char = character(player)
	if not quest or not char then
		return false
	end
	PlayerStateService.Set(player, { "character", "quests", "side", "done", questId }, nil)
	setEntry(player, quest.id, SideQuests.newEntry(quest))
	catchUp(player)
	return true
end

-- /side complete <id>: fills every objective of an active quest (and marks its anchors used).
function SideQuestService.Complete(player: Player, questId: string): boolean
	local quest = Quests.Side.get(questId)
	local char = character(player)
	local entry = char and sideOf(char).active[questId]
	if not quest or not entry then
		return false
	end
	local updated = copyEntry(entry)
	for i, objective in quest.objectives do
		updated.progress[i] = objective.n
		if objective.type == "use" then
			local list: { string } = objective.anchors or { objective.anchor :: string }
			for _, anchor in list do
				if not table.find(updated.used, anchor) then
					table.insert(updated.used, anchor)
				end
			end
		end
	end
	setEntry(player, questId, ensureChoice(player, quest, updated))
	return true
end

-- /side reset [id]: forgets one quest (active and done) or every side quest.
function SideQuestService.Reset(player: Player, questId: string?): boolean
	if not character(player) then
		return false
	end
	if questId then
		setEntry(player, questId, nil)
		PlayerStateService.Set(player, { "character", "quests", "side", "done", questId }, nil)
	else
		PlayerStateService.Set(player, { "character", "quests", "side" }, { active = {}, done = {} })
	end
	return true
end

-- /side arc <questId>: everything in the quest's arc before it handed in, the quest itself active.
function SideQuestService.SkipTo(player: Player, questId: string): boolean
	local quest = Quests.Side.get(questId)
	if not quest or not character(player) then
		return false
	end
	local arc: { Quests.SideQuest } = Quests.Side.byArc[quest.arc] or {}
	for _, other in arc do
		if other.id == questId then
			break
		end
		setEntry(player, other.id, nil)
		PlayerStateService.Set(player, { "character", "quests", "side", "done", other.id }, true)
	end
	-- Requirements from other arcs (side_mill needs side_shiny) are marked done too.
	local requires: { string } = quest.requires or {}
	for _, id in requires do
		if Quests.Side.get(id) then
			PlayerStateService.Set(player, { "character", "quests", "side", "done", id }, true)
		end
	end
	return SideQuestService.Give(player, questId)
end

-- World position of a quest anchor (admin /anchor), or nil.
function SideQuestService.AnchorPosition(anchorId: string): Vector3?
	local part = anchors[anchorId]
	return if part then part.Position else nil
end

function SideQuestService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	LevelService = registry.Get("LevelService")
	NpcService = registry.Get("NpcService")
	ResourceService = registry.Get("ResourceService")
	CharacterService = registry.Get("CharacterService")
	ZoneService = registry.Get("ZoneService")
end

function SideQuestService.Start()
	local function register(instance: Instance)
		local id = instance:GetAttribute("AnchorId")
		if instance:IsA("BasePart") and type(id) == "string" then
			anchors[id] = instance
		end
	end
	for _, instance in CollectionService:GetTagged(ANCHOR_TAG) do
		register(instance)
	end
	CollectionService:GetInstanceAddedSignal(ANCHOR_TAG):Connect(register)

	Net.Handle("SideAccept", accept)
	Net.Handle("SideTurnIn", turnIn)
	Net.Handle("SideAbandon", abandon)
	Net.Handle("QuestUse", useAnchor)
	Net.On("CancelQuestUse", function(player: Player)
		stopHold(player, false)
	end)
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 and holds[player] then
			stopHold(player, true)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		stopHold(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		holds[player] = nil
	end)

	-- "Reach a place" objectives (S27: the stone circle) need the position, not only the map: poll the players who
	-- have one open. Through QuestEvents, so a story quest with a place would count as well.
	task.spawn(function()
		while true do
			task.wait(REACH_POLL)
			for _, player in Players:GetPlayers() do
				local char = PlayerStateService.HasState(player) and character(player)
				if not char then
					continue
				end
				local wanted = false
				for id, entry in sideOf(char).active do
					local quest = Quests.Side.get(id)
					if quest then
						for i, objective in quest.objectives do
							if objective.type == "reach" and objective.x and (entry.progress[i] or 0) < objective.n then
								wanted = true
							end
						end
					end
				end
				if wanted then
					local map, x, z = whereIs(player)
					if map then
						QuestEvents.fire(player, "reach", { map = map, x = x, z = z })
					end
				end
			end
		end
	end)
end

return SideQuestService
