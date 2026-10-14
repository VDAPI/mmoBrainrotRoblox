--!strict
-- Quests on the client (DESIGN §20): the journal (L), the quest conversation with NPCs (story and, S27, side
-- quests), the contract board, markers above NPCs (gold "!" quest available, S98: grey "!" an offer far below the
-- level, gold "?" ready to hand in, grey "?" in progress; Logic/NpcMarks, style in UI/NpcMarkState), the HUD tracker with the direction arrow and the target on the minimap for the one
-- tracked quest (the story or a side quest, QuestTrack.Focus), and the completion message. S101b: the saved answers
-- lead the target (QuestText `quests` argument) and a quest companion moves it (refreshed every second meanwhile).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestBoard = require(script.Parent.Parent.UI.Screens.QuestBoard)
local QuestDialog = require(script.Parent.Parent.UI.Screens.QuestDialog)
local QuestJournal = require(script.Parent.Parent.UI.Screens.QuestJournal)
local QuestText = require(script.Parent.Parent.UI.QuestText)
local QuestTrack = require(script.Parent.Parent.UI.QuestTrack)
local NpcQuests = require(script.Parent.Parent.UI.NpcQuests)
local NpcMarkState = require(script.Parent.Parent.UI.NpcMarkState)
local Elite2Timer = require(script.Parent.Parent.UI.Screens.Hud.Elite2Timer)
local QuestTracker = require(script.Parent.Parent.UI.Screens.Hud.QuestTracker)
local WorldEventPanel = require(script.Parent.Parent.UI.Screens.Hud.WorldEventPanel)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local QuestController = {
	Name = "QuestController",
	Deps = { "WindowManager", "UIController", "NavController", "NotificationController", "SfxController" },
}

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local NotificationController: any
local SfxController: any
local dialogNpc = scope:Value(nil :: string?)
local dialogRow = scope:Value(nil :: NpcQuests.Row?)

-- Opens the conversation about one quest of an NPC (a row of UI/NpcQuests).
function QuestController.OpenQuest(npcId: string, row: NpcQuests.Row)
	dialogNpc:set(npcId)
	dialogRow:set(row)
	WindowManager.Close("npc")
	WindowManager.Close("questnpc")
	WindowManager.Open("questnpc")
end

function QuestController.OpenBoard()
	WindowManager.Open("questboard")
end

-- S27: track one quest (nil = the story) and show its arrow.
function QuestController.Track(focus: QuestTrack.Focus)
	QuestTrack.Focus:set(focus)
	QuestTrack.Tracked:set(true)
end

local function refreshMarkers()
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Npcs")
	if not folder then
		return
	end
	local quests = State.Get({ "character", "quests" })
	local level = State.Get({ "character", "level" }) or 1
	for _, model in folder:GetChildren() do
		local npcId = model:GetAttribute("NpcId")
		local plate = model:FindFirstChild("VaelthornPlate")
		if type(npcId) == "string" and plate then
			local label = plate:FindFirstChild("QuestMarker") :: TextLabel?
			if not label then
				local created = Instance.new("TextLabel")
				created.Name = "QuestMarker"
				created.AnchorPoint = Vector2.new(0.5, 1)
				created.Position = UDim2.fromScale(0.5, 0)
				created.Size = UDim2.fromOffset(40, 40)
				created.BackgroundTransparency = 1
				created.FontFace = Theme.Fonts.Heading
				created.TextSize = 40
				created.TextStrokeTransparency = 0.2
				created.Parent = plate;
				(plate :: BillboardGui).ClipsDescendants = false
				label = created
			end
			assert(label, "marker")
			local marker = QuestText.marker(npcId, quests, level)
			-- S98: one style for the plates, the world map and the minimap (UI/NpcMarkState)
			local style = NpcMarkState.style(marker :: any)
			label.Visible = style ~= nil
			if style then
				label.Text = style.text
				label.TextColor3 = style.color
			end
		end
	end
end

local function refreshTarget()
	local quests = State.Get({ "character", "quests" })
	local level = State.Get({ "character", "level" }) or 1
	-- S27: a tracked side quest that is no longer active (handed in, abandoned) gives the arrow back to the story.
	local focus = Fusion.peek(QuestTrack.Focus)
	if focus and focus.kind == "contract" then
		-- S99: the active hunting contract; none active (handed in and waiting) gives the arrow back to the story
		local contract, active = Contracts.active(Contracts.stateOf(quests))
		if contract and active then
			local map = State.Get({ "character", "location", "map" })
			QuestTrack.Target:set(QuestText.contractTarget(contract, active, level, map))
			return
		end
		QuestTrack.Focus:set(nil)
	elseif focus then
		local side = Quests.npcQuest(focus.id or "")
		local entry = SideQuests.activeOf(quests)[focus.id or ""]
		if side and type(entry) == "table" then
			QuestTrack.Target:set(QuestText.sideTarget(side, entry, level, quests))
			return
		end
		QuestTrack.Focus:set(nil)
	end
	local main = if type(quests) == "table" then quests.main else nil
	local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
	QuestTrack.Target:set(
		if quest and main then QuestText.target(quest, main.progress or {}, level, quests, main.used) else nil
	)
end

function QuestController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	SfxController = registry.Get("SfxController")
	NotificationController = registry.Get("NotificationController")
	local UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "quests",
		titleKey = "window.quests.title",
		size = Vector2.new(640, 600),
		hotkey = Enum.KeyCode.L,
		build = function(s)
			return QuestJournal(s, {
				Tracked = QuestTrack.Tracked,
				Focus = QuestTrack.Focus,
				Track = QuestController.Track,
				ShowModal = WindowManager.ShowModal,
				-- S102: watch a story cutscene again (CutsceneController from the registry: no Deps cycle)
				Replay = function(sceneId: string)
					local cutscenes = registry.Get("CutsceneController")
					if cutscenes then
						cutscenes.Play(sceneId)
					end
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "questnpc",
		titleKey = "window.questnpc.title",
		size = Vector2.new(640, 560),
		build = function(s)
			return QuestDialog(s, {
				NpcId = dialogNpc,
				Row = dialogRow,
				Close = function()
					WindowManager.Close("questnpc")
				end,
				Back = function()
					WindowManager.Close("questnpc")
					WindowManager.Open("npc")
				end,
				OnAccepted = function(row: NpcQuests.Row)
					-- A freshly taken side quest gets the arrow (one tracked quest at a time).
					if row.kind == "side" then
						QuestController.Track({ kind = "side", id = row.id })
					end
				end,
			})
		end,
	})
	WindowManager.Register({
		id = "questboard",
		titleKey = "window.questboard.title",
		size = Vector2.new(640, 600), -- S99: the hunting contract over the tabs
		build = function(s)
			return QuestBoard(s, {
				Tracked = QuestTrack.Tracked,
				Focus = QuestTrack.Focus,
				Track = QuestController.Track,
			})
		end,
	})
	local Nav = registry.Get("NavController")
	-- S101: the world event panel stands over the tracker (PC), which moves down by its height meanwhile.
	local eventOffset = scope:Value(0)
	QuestTracker(scope, {
		Offset = eventOffset,
		-- S25: the tracker's "➤" guides to the quest target like "Guide" on the map.
		Guide = function(target)
			local npc = if target.npc then Npcs.get(target.npc) else nil
			Nav.Guide({
				map = target.map,
				x = target.x or 0,
				z = target.z or 0,
				npc = target.npc,
				kind = if npc then "npc" else nil,
				id = target.npc,
				labelKey = if npc then npc.nameKey else "quest.tracker",
			})
		end,
	}).Parent =
		UIController.GetLayer("Screens")
	Elite2Timer(scope).Parent = UIController.GetLayer("Screens")
	WorldEventPanel(scope, {
		Offset = eventOffset,
		Guide = function(target)
			Nav.Guide({ map = target.map, x = target.x, z = target.z, labelKey = target.labelKey })
		end,
	}).Parent =
		UIController.GetLayer("Screens")
end

function QuestController.Start()
	scope:Observer(State.Value({ "character", "quests" })):onChange(function()
		refreshMarkers()
		refreshTarget()
	end)
	scope:Observer(State.Value({ "character", "level" })):onChange(function()
		refreshMarkers()
		refreshTarget()
	end)
	scope:Observer(QuestTrack.Focus):onChange(refreshTarget)
	-- S99: a done hunting contract points at its scout on the scout's map, else at the board
	scope:Observer(State.Value({ "character", "location", "map" })):onChange(refreshTarget)
	-- S101b: the companion's phase and figure move an escort target
	scope:Observer(State.Value({ "companion" })):onChange(refreshTarget)
	refreshTarget()
	task.spawn(function()
		while true do
			task.wait(1)
			if State.Get({ "companion" }) ~= nil then
				refreshTarget()
			end
		end
	end)
	-- NPC models stream in and out: refresh the markers regularly.
	task.spawn(function()
		while true do
			task.wait(1.5)
			refreshMarkers()
		end
	end)
	-- S99: (titleKey, args?) the hunting contract title has arguments ("@key" values resolved)
	Net.On("QuestCompleted", function(titleKey: string, args: any)
		-- S111: ui.quest, the old placeholder while it has no sound
		if not SfxController.Ui("ui.quest") then
			Sounds.play("levelUp")
		end
		local title = Text.now(titleKey, NotificationController.ResolveArgs(args))
		Toast.push(Text.now("quest.completed", { title = title }), "success", 5)
	end)
end

return QuestController
