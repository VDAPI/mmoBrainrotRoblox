--!strict
-- Quests on the client (DESIGN §20): the journal (L), the quest conversation with NPCs (story and, S27, side
-- quests), the contract board, markers above NPCs ("!" quest available, golden "?" ready to hand in, grey "?" in
-- progress; Logic/NpcMarks), the HUD tracker with the direction arrow and the target on the minimap for the one
-- tracked quest (the story or a side quest, QuestTrack.Focus), and the completion message.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local QuestBoard = require(script.Parent.Parent.UI.Screens.QuestBoard)
local QuestDialog = require(script.Parent.Parent.UI.Screens.QuestDialog)
local QuestJournal = require(script.Parent.Parent.UI.Screens.QuestJournal)
local QuestText = require(script.Parent.Parent.UI.QuestText)
local QuestTrack = require(script.Parent.Parent.UI.QuestTrack)
local NpcQuests = require(script.Parent.Parent.UI.NpcQuests)
local QuestTracker = require(script.Parent.Parent.UI.Screens.Hud.QuestTracker)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local QuestController = {
	Name = "QuestController",
	Deps = { "WindowManager", "UIController", "NavController" },
}

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local dialogNpc = scope:Value(nil :: string?)
local dialogRow = scope:Value(nil :: NpcQuests.Row?)

local MARKERS = {
	available = { text = "!", color = Theme.Colors.GoldBright },
	turnIn = { text = "?", color = Theme.Colors.GoldBright },
	active = { text = "?", color = Theme.Colors.TextMuted },
}

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
			local style = if marker then MARKERS[marker] else nil
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
	if focus then
		local side = Quests.Side.get(focus.id)
		local entry = SideQuests.activeOf(quests)[focus.id]
		if side and type(entry) == "table" then
			QuestTrack.Target:set(QuestText.sideTarget(side, entry, level))
			return
		end
		QuestTrack.Focus:set(nil)
	end
	local main = if type(quests) == "table" then quests.main else nil
	local quest = if type(main) == "table" then Quests.Main.get(main.id) else nil
	QuestTrack.Target:set(if quest and main then QuestText.target(quest, main.progress or {}, level) else nil)
end

function QuestController.Init(registry)
	WindowManager = registry.Get("WindowManager")
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
		size = Vector2.new(640, 480),
		build = QuestBoard,
	})
	local Nav = registry.Get("NavController")
	QuestTracker(scope, {
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
	refreshTarget()
	-- NPC models stream in and out: refresh the markers regularly.
	task.spawn(function()
		while true do
			task.wait(1.5)
			refreshMarkers()
		end
	end)
	Net.On("QuestCompleted", function(titleKey: string)
		Sounds.play("levelUp")
		Toast.push(Text.now("quest.completed", { title = Text.now(titleKey) }), "success", 5)
	end)
end

return QuestController
