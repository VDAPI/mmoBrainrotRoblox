--!strict
-- NPC comments during quests (S101b, DESIGN-15 §3.5; rules in Logic/Barks, pace in Config.Barks). Everything comes
-- from the replicated state, so comments never touch play: quest changes (accept, half, done), the player's death
-- during a quest with a place on that map, coming near where an objective points, long play without progress outside
-- town, and the companion's phases (lines quest.<id>.comp.*, at most every Config.Companion.lineGap seconds). The
-- speaker (Barks.speaker: `by`, the companion when its figure is near, the turn-in NPC for done, else the giver) says
-- it in a bubble over its head when it stands within `bubbleRange` on the player's map, else in the box with a
-- portrait at the screen's edge (Hud/BarkToast). One at a time, at most two waiting (older ones drop). Silent with the
-- setting off (account.settings.barks), outside play and while muted: other controllers call SetQuiet (S102 cutscenes);
-- comments while muted are dropped. A comment of an NPC whose dialog is open waits until it closes (at most
-- `holdSeconds`).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BarkToast = require(script.Parent.Parent.UI.Screens.Hud.BarkToast)
local Barks = require(ReplicatedStorage.Shared.Logic.Barks)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local QuestText = require(script.Parent.Parent.UI.QuestText)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local BarkController = {
	Name = "BarkController",
	Deps = { "UIController", "WindowManager", "NpcController" },
}

type Bark = { speaker: string, key: string, companion: boolean }
type Held = { questId: string, event: string, at: number }

local B = Config.Barks
local MAX_QUEUE = 2
local TOWN = "city"

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local NpcController: any
local toast: BarkToast.Api? = nil

local limiter = Barks.newLimiter()
local quiet: { [string]: boolean? } = {}
local queue: { Bark } = {}
local busyUntil = 0
local counter = 0
local held: Held? = nil
local lastComp = -math.huge

-- S101b: other controllers mute comments, e.g. S102 cutscenes. Comments while muted are dropped, not queued.
function BarkController.SetQuiet(reason: string, isQuiet: boolean)
	quiet[reason] = if isQuiet then true else nil
	if isQuiet then
		table.clear(queue)
		held = nil
		if toast then
			toast.hide()
		end
	end
end

local function enabled(): boolean
	if next(quiet) ~= nil then
		return false
	end
	if State.Get({ "session", "phase" }) ~= "playing" then
		return false
	end
	return State.Get({ "account", "settings", "barks" }) ~= false
end

local function myRoot(): BasePart?
	local character = Players.LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function currentMap(): string?
	local zone = State.Get({ "zone" })
	if type(zone) == "table" and type(zone.map) == "string" then
		return zone.map
	end
	return State.Get({ "character", "location", "map" })
end

-- The local player's companion figure (of `npcId` when given).
local function companionModel(npcId: string?): Model?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Companions")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if
			model:IsA("Model")
			and model:GetAttribute("CompanionOf") == Players.LocalPlayer.UserId
			and (npcId == nil or model:GetAttribute("CompanionNpc") == npcId)
		then
			return model
		end
	end
	return nil
end

local function npcModel(npcId: string): Model?
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Npcs")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("NpcId") == npcId then
			return model
		end
	end
	return nil
end

-- The head the bubble hangs on: the speaker's model within bubbleRange of the player, else nil.
local function headNear(speaker: string, companion: boolean): BasePart?
	local model = if companion then companionModel(speaker) else nil
	model = model or npcModel(speaker)
	local head = model and model:FindFirstChild("Head") :: BasePart?
	local root = myRoot()
	if not head or not root then
		return nil
	end
	local gap = Vector3.new(head.Position.X - root.Position.X, 0, head.Position.Z - root.Position.Z)
	return if gap.Magnitude <= B.bubbleRange then head else nil
end

local function bubble(head: BasePart, line: string)
	local old = head.Parent and head.Parent:FindFirstChild("VaelthornBark")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "VaelthornBark"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(300, 110)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	gui.MaxDistance = B.bubbleRange
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.fromScale(0.5, 1)
	box.Size = UDim2.fromOffset(300, 0)
	box.AutomaticSize = Enum.AutomaticSize.Y
	box.BackgroundColor3 = Theme.Paper.Raised
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Medium
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Paper.Border
	stroke.Thickness = 2
	stroke.Parent = box
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = box
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.BackgroundTransparency = 1
	label.TextWrapped = true
	label.Text = line
	label.FontFace = Theme.Fonts.Body
	label.TextSize = Theme.TextSize.Small
	label.TextColor3 = Theme.Paper.Text
	label.Parent = box
	gui.Parent = head.Parent
	task.delay(B.bubbleSeconds, function()
		gui:Destroy()
	end)
end

local function display(bark: Bark)
	local line = Text.now(bark.key)
	local head = headNear(bark.speaker, bark.companion)
	if head then
		bubble(head, line)
		busyUntil = os.clock() + B.bubbleSeconds
	elseif toast then
		toast.show(bark.speaker, line)
		busyUntil = os.clock() + B.toastSeconds
	end
end

local function enqueue(bark: Bark)
	table.insert(queue, bark)
	while #queue > MAX_QUEUE do
		table.remove(queue, 1)
	end
end

-- Whether the dialog of an NPC is open (its comment waits).
local function talkingTo(npcId: string): boolean
	if Fusion.peek(NpcController.Current) ~= npcId then
		return false
	end
	return Fusion.peek(WindowManager.IsOpen("npc")) or Fusion.peek(WindowManager.IsOpen("questnpc"))
end

-- The companion speaks for its own quest when its figure is near.
local function companionFor(questId: string): string?
	local state = State.Get({ "companion" })
	if type(state) ~= "table" or state.quest ~= questId then
		return nil
	end
	return if headNear(state.npc, true) then state.npc else nil
end

local function trigger(questId: string, event: string)
	if not enabled() then
		return
	end
	local quest = Barks.questOf(questId)
	if not quest or Barks.count(quest, event) == 0 then
		return
	end
	local companion = companionFor(questId)
	local speaker = Barks.speaker(quest, event, companion)
	if talkingTo(speaker) then
		held = { questId = questId, event = event, at = os.clock() }
		return
	end
	if not Barks.allow(limiter, questId, event, os.clock()) then
		return
	end
	local key = Barks.pick(quest, event, counter)
	counter += 1
	if key then
		enqueue({ speaker = speaker, key = key, companion = companion ~= nil })
	end
end

-- Companion lines (join, wait, arrive, back), at most every Config.Companion.lineGap seconds.
local function companionLine(questId: string, npcId: string, event: string)
	if not enabled() or os.clock() - lastComp < Config.Companion.lineGap then
		return
	end
	local quest = Barks.questOf(questId)
	local key = quest and Barks.pickComp(quest, event, counter)
	if not key then
		return
	end
	counter += 1
	lastComp = os.clock()
	enqueue({ speaker = npcId, key = key, companion = true })
end

-- Active quests with comments: id -> { quest, progress, kind }.
local function activeQuests(quests: any): { [string]: { quest: any, progress: { number }, kind: string } }
	local out = {}
	if type(quests) ~= "table" then
		return out
	end
	local main = quests.main
	if type(main) == "table" then
		local quest = Quests.Main.get(main.id)
		if quest and quest.barks then
			out[quest.id] = { quest = quest, progress = main.progress or {}, kind = "main" }
		end
	end
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.npcQuest(id)
		if quest and quest.barks and type(entry) == "table" then
			out[id] = { quest = quest, progress = entry.progress or {}, kind = "side" }
		end
	end
	return out
end

local function targetOf(item: { quest: any, progress: { number }, kind: string }, quests: any, level: number): any
	if item.kind == "main" then
		return QuestText.target(item.quest, item.progress, level, quests, (quests.main or {}).used)
	end
	local entry = SideQuests.activeOf(quests)[item.quest.id]
	return QuestText.sideTarget(item.quest, entry, level, quests)
end

-- Watching -------------------------------------------------------------------------------------------------------------

local previous: any = nil
local previousCharacter: string? = nil
local shares: { [string]: number } = {}
local idle: { [string]: number } = {}
local nearSaid: { [string]: boolean } = {}

local function snapshot(quests: any): any
	-- a deep enough copy of the parts Barks.events reads (the state tables are changed in place)
	if type(quests) ~= "table" then
		return nil
	end
	local copy: any = { main = nil, side = { active = {}, done = {} } }
	if type(quests.main) == "table" then
		copy.main = { id = quests.main.id, progress = table.clone(quests.main.progress or {}) }
	end
	for id, entry in SideQuests.activeOf(quests) do
		if type(entry) == "table" then
			copy.side.active[id] = { progress = table.clone(entry.progress or {}) }
		end
	end
	return copy
end

local function onQuests()
	local quests = State.Get({ "character", "quests" })
	local characterId = State.Get({ "character", "id" })
	local now = snapshot(quests)
	if previous == nil or characterId ~= previousCharacter then
		-- first state of a character: nothing to comment yet
		previous, previousCharacter = now, characterId
		return
	end
	local level = State.Get({ "character", "level" }) or 1
	for _, event in Barks.events(previous, now, level) do
		trigger(event.quest, event.event)
	end
	previous = now
	-- progress resets the idle time of the quest
	for id, item in activeQuests(quests) do
		local share = Barks.share(item.progress, item.quest.objectives)
		if shares[id] ~= share then
			shares[id] = share
			idle[id] = 0
		end
	end
end

local function onDeath()
	local death = State.Get({ "death" })
	if type(death) ~= "table" then
		return
	end
	local quests = State.Get({ "character", "quests" })
	local level = State.Get({ "character", "level" }) or 1
	local map = currentMap()
	for id, item in activeQuests(quests) do
		if Barks.count(item.quest, "death") > 0 then
			local target = targetOf(item, quests, level)
			if target and target.map == map then
				trigger(id, "death")
				return
			end
		end
	end
end

local lastPhase: string? = nil
local lastCompanionQuest: string? = nil

local function onCompanion()
	local state = State.Get({ "companion" })
	if type(state) ~= "table" then
		lastPhase, lastCompanionQuest = nil, nil
		return
	end
	local phase = state.phase
	if state.quest ~= lastCompanionQuest then
		lastCompanionQuest = state.quest
		lastPhase = phase
		if phase == "join" or phase == "follow" or phase == "lead" then
			companionLine(state.quest, state.npc, "join")
		end
		return
	end
	if phase == lastPhase then
		return
	end
	local before = lastPhase
	lastPhase = phase
	if phase == "join" and before == "back" then
		companionLine(state.quest, state.npc, "join")
	elseif phase == "wait" then
		companionLine(state.quest, state.npc, "wait")
	elseif phase == "arrived" and state.mode == "lead" then
		companionLine(state.quest, state.npc, "arrive")
	elseif phase == "back" then
		companionLine(state.quest, state.npc, "back")
	end
end

-- Every second: near and stuck, held comments, the queue.
local function poll(dt: number)
	local quests = State.Get({ "character", "quests" })
	local level = State.Get({ "character", "level" }) or 1
	local map = currentMap()
	local root = myRoot()
	local mapDef = Maps.get(map or "")
	local inTown = map == TOWN
	if enabled() and root and mapDef then
		local position = { x = root.Position.X - mapDef.offset.x, z = root.Position.Z - mapDef.offset.z }
		for id, item in activeQuests(quests) do
			if
				Barks.count(item.quest, "near") > 0 and not QuestLogic.isComplete(item.progress, item.quest.objectives)
			then
				local index = 0
				for i, objective in item.quest.objectives do
					if (item.progress[i] or 0) < objective.n then
						index = i
						break
					end
				end
				local key = `{id}#{index}`
				if not nearSaid[key] then
					local target = targetOf(item, quests, level)
					if Barks.nearHit(target, position, map, B.nearRadius) then
						nearSaid[key] = true
						trigger(id, "near")
					end
				end
			end
			if QuestLogic.isComplete(item.progress, item.quest.objectives) then
				idle[id] = nil -- done: nothing left to hint at
			elseif Barks.count(item.quest, "stuck") > 0 then
				if not inTown then
					idle[id] = (idle[id] or 0) + dt
				end
				if Barks.isStuck(0, idle[id] or 0, inTown) then
					trigger(id, "stuck")
				end
			end
		end
	end
	local waiting = held
	if waiting then
		if os.clock() - waiting.at > B.holdSeconds then
			held = nil
		else
			local quest = Barks.questOf(waiting.questId)
			local speaker = quest and Barks.speaker(quest, waiting.event, companionFor(waiting.questId))
			if speaker and not talkingTo(speaker) then
				held = nil
				trigger(waiting.questId, waiting.event)
			end
		end
	end
end

function BarkController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	NpcController = registry.Get("NpcController")
	local api = BarkToast.new(scope)
	api.frame.Parent = registry.Get("UIController").GetLayer("Toasts")
	toast = api
end

function BarkController.Start()
	scope:Observer(State.Value({ "character", "quests" })):onChange(onQuests)
	scope:Observer(State.Value({ "character", "id" })):onChange(onQuests)
	scope:Observer(State.Value({ "death" })):onChange(onDeath)
	scope:Observer(State.Value({ "companion" })):onChange(onCompanion)
	scope:Observer(State.Value({ "account", "settings", "barks" })):onChange(function()
		if State.Get({ "account", "settings", "barks" }) == false then
			table.clear(queue)
			held = nil
			if toast then
				toast.hide()
			end
		end
	end)
	onQuests()
	task.spawn(function()
		local last = os.clock()
		local pollAt = 0
		while true do
			task.wait(0.25)
			local now = os.clock()
			if now - pollAt >= 1 then
				local ok, err = pcall(poll :: any, now - last)
				if not ok then
					warn("[Bark] " .. tostring(err))
				end
				last = now
				pollAt = now
			end
			if now >= busyUntil and #queue > 0 then
				local bark = table.remove(queue, 1) :: Bark
				if enabled() then
					display(bark)
				end
			end
		end
	end)
end

return BarkController
