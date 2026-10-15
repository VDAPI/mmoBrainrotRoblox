--!strict
-- Switches the main screen with the session phase: CharacterSelect ("loading"/"select") or Hud
-- ("playing"). Handles the selection camera (blurred city view) and registers the HUD menu windows.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterSelect = require(script.Parent.Parent.UI.Screens.CharacterSelect)
local ServerModeView = require(script.Parent.Parent.UI.ServerModeView)
local CharacterWindow = require(script.Parent.Parent.UI.Screens.CharacterWindow)
local ComingSoon = require(script.Parent.Parent.UI.Screens.ComingSoon)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GameMenu = require(script.Parent.Parent.UI.Screens.GameMenu)
local BackpackPanel = require(script.Parent.Parent.UI.Screens.BackpackPanel)
local BloodMoonView = require(script.Parent.Parent.UI.BloodMoonView)
local SkillsAttention = require(script.Parent.Parent.UI.SkillsAttention)
local SkillsWindow = require(script.Parent.Parent.UI.Screens.SkillsWindow)
local Hud = require(script.Parent.Parent.UI.Screens.Hud)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Town = require(ReplicatedStorage.Shared.Data.Town)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

type Scope = Fusion.Scope<typeof(Fusion)>

local ScreenController = {
	Name = "ScreenController",
	Deps = {
		"UIController",
		"WindowManager",
		"StateController",
		"TargetController",
		"ItemController",
		"SkillController",
		"PartyController",
		"MovementController",
		"NavController",
		"VfxController",
		"MountController",
		"LoginRewardController", -- S100: the HUD button's status and badge
		"EmoteController", -- S123: the emote wheel button
	},
}

local UIController: any
local WindowManager: any
local TargetController: any
local ItemController: any
local SkillController: any
local PartyController: any
local MovementController: any
local NavController: any
local VfxController: any
local MountController: any
local LoginRewardController: any
local EmoteController: any

-- S127: menu entries that need the world (an arena server has none of it).
local function worldOnly(_use: Fusion.Use): boolean
	return ServerModeView.isWorld()
end

-- HUD menu (DESIGN §23). Windows without their system yet show a "coming soon" body.
local MENU: { Hud.MenuEntry } = {
	{ id = "inventory", icon = "▣", hotkey = "B", tooltipKey = "hud.menu.inventory" },
	{ id = "skills", icon = "✦", hotkey = "K", tooltipKey = "hud.menu.skills", badge = SkillsAttention.badge },
	-- S127: the world map and the journal need the world (hidden on an arena server)
	{ id = "map", icon = "⌖", hotkey = "M", tooltipKey = "hud.menu.map", visible = worldOnly },
	{ id = "quests", icon = "✎", hotkey = "L", tooltipKey = "hud.menu.quests", visible = worldOnly },
	{ id = "guild", icon = "⚑", hotkey = "G", tooltipKey = "hud.menu.guild" },
	{ id = "party", icon = "☍", hotkey = "P", tooltipKey = "hud.menu.party" },
	-- S133: friends and ignored players (SocialController registers the window; key win_friends)
	{ id = "friends", icon = "☺", hotkey = "Y", tooltipKey = "hud.menu.friends" },
	-- S97: shown from the mount level, or earlier with a mount (MountController.Access)
	{
		id = "mounts",
		icon = "♞",
		hotkey = "J",
		tooltipKey = "hud.menu.mounts",
		visible = function(use: Fusion.Use): boolean
			return use(MountController.Access) == true and ServerModeView.isWorld()
		end,
	},
	-- S124: rankings (RankingsController registers the window; key win_rankings)
	{ id = "rankings", icon = "♔", hotkey = "R", tooltipKey = "hud.menu.rankings" },
	-- S126: the ranked arena next to the rankings (ArenaController registers the window; key win_arena)
	{ id = "arena", icon = "⚔", hotkey = "U", tooltipKey = "hud.menu.arena" },
	-- S129: the Blood Moon results, from 10 min before the start until the results go (BloodMoonController registers
	-- the window; no key)
	{
		id = "bloodmoon",
		icon = "☾",
		hotkey = nil,
		tooltipKey = "hud.menu.bloodmoon",
		visible = BloodMoonView.menuVisible,
	},
	{ id = "wardrobe", icon = "♛", hotkey = nil, tooltipKey = "hud.menu.wardrobe" },
	{ id = "premium", icon = "◆", hotkey = nil, tooltipKey = "hud.menu.shop" },
	{ id = "menu", icon = "☰", hotkey = nil, tooltipKey = "hud.menu.menu" },
}

local HOTKEYS: { [string]: Enum.KeyCode } = {
	inventory = Enum.KeyCode.B,
	skills = Enum.KeyCode.K,
	map = Enum.KeyCode.M,
	quests = Enum.KeyCode.L,
	guild = Enum.KeyCode.G,
	party = Enum.KeyCode.P,
}

local SELECT_BLUR = 14

local current: "select" | "hud" | nil = nil
local screenScope: Scope? = nil
local blur: BlurEffect

local backpackActions: BackpackPanel.Actions

local function registerWindows()
	backpackActions = {
		Equip = function(index: number)
			ItemController.Equip(index, nil)
		end,
		Use = ItemController.Use,
		Split = ItemController.Split,
		Destroy = ItemController.Destroy,
		Lock = ItemController.ToggleLock,
		LootLog = function()
			WindowManager.Open("lootlog")
		end,
	}
	for _, entry in MENU do
		if entry.id == "skills" then
			WindowManager.Register({
				id = "skills",
				titleKey = "window.skills.title",
				size = Vector2.new(920, 640),
				hotkey = HOTKEYS.skills,
				build = function(scope: Scope)
					return SkillsWindow(scope, { ShowModal = WindowManager.ShowModal, Preview = VfxController.Preview })
				end,
			})
		elseif entry.id == "inventory" then
			-- S29: the backpack window: equipment + backpack + statistics in one (WindowRules.MAIN, opened by B
			-- without a service). FIX 2026-10-14: the separate "Character" button and its C key are gone; the
			-- window has the backpack's title.
			WindowManager.Register({
				id = "character",
				titleKey = "window.inventory.title",
				size = Vector2.new(1240, 700),
				build = function(scope: Scope)
					return CharacterWindow(scope, {
						Focus = WindowManager.FocusHint,
						Backpack = backpackActions,
						Unequip = function(slot: string)
							ItemController.Unequip(slot, nil)
						end,
					})
				end,
			})
			-- The companion backpack next to service windows.
			WindowManager.Register({
				id = "inventory",
				titleKey = "window.inventory.title",
				size = Vector2.new(560, 640),
				hotkey = HOTKEYS.inventory,
				build = function(scope: Scope)
					return BackpackPanel(scope, { Actions = backpackActions })
				end,
			})
		elseif
			entry.id == "map"
			or entry.id == "party"
			or entry.id == "friends"
			or entry.id == "quests"
			or entry.id == "guild"
			or entry.id == "premium"
			or entry.id == "wardrobe"
			or entry.id == "mounts"
			or entry.id == "rankings"
			or entry.id == "arena"
			or entry.id == "bloodmoon"
		then
			-- Registered by WorldController / PartyController / QuestController / GuildController / PremiumController /
			-- MountController (S97) / RankingsController (S124) / ArenaController (S126) / BloodMoonController (S129).
			continue
		elseif entry.id == "menu" then
			WindowManager.Register({
				id = "menu",
				titleKey = "window.menu.title",
				size = Vector2.new(640, 700),
				-- S121: the menu opens the VIP window
				build = function(s, close)
					return GameMenu(s, close, { OpenWindow = WindowManager.Open })
				end,
			})
		else
			WindowManager.Register({
				id = entry.id,
				titleKey = `window.{entry.id}.title`,
				size = Vector2.new(560, 420),
				hotkey = HOTKEYS[entry.id],
				build = function(scope: Scope)
					return ComingSoon(scope, entry.icon)
				end,
			})
		end
	end
end

local function selectCamera()
	local camera = Workspace.CurrentCamera
	local city = Maps.get(Config.StartingMap)
	if not camera or not city then
		return
	end
	-- S21: the shot of the city plan (eye and look point, x y z map-relative) over the market, the town hall
	-- and the castle.
	local origin = Vector3.new(city.offset.x, city.offset.y, city.offset.z)
	local shot = Town.city.selectCamera
	local centre = origin + Vector3.new(shot.look[1], shot.look[2], shot.look[3])
	local eye = origin + Vector3.new(shot.eye[1], shot.eye[2], shot.eye[3])
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(eye, centre)
	blur.Size = SELECT_BLUR
	blur.Enabled = true
	-- Streaming: without a character nothing streams in around the camera unless we ask.
	task.spawn(function()
		pcall(function()
			Players.LocalPlayer:RequestStreamAroundAsync(centre)
		end)
	end)
end

local function gameCamera()
	blur.Enabled = false
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- S102: for CutsceneController: the game camera back on the character after a cutscene.
function ScreenController.RestoreCamera()
	gameCamera()
end

local function show(screen: "select" | "hud")
	if current == screen then
		return
	end
	current = screen
	if screenScope then
		Fusion.doCleanup(screenScope)
	end
	WindowManager.CloseAll()
	WindowManager.DismissModals()

	local scope = UIController.Scope:innerScope()
	screenScope = scope
	local layer = UIController.GetLayer("Screens")

	if screen == "select" then
		WindowManager.SetHotkeysEnabled(false)
		selectCamera()
		CharacterSelect(scope, {
			ShowModal = WindowManager.ShowModal,
		}).Parent = layer
	else
		WindowManager.SetHotkeysEnabled(true)
		gameCamera()
		Hud(scope, {
			Menu = MENU,
			OpenWindow = WindowManager.Toggle,
			ShowWindow = WindowManager.Open,
			StopGuide = function()
				NavController.Clear()
			end,
			IsOpen = WindowManager.IsOpen,
			Target = TargetController.Target,
			OnPlayerMenu = function(player: Player, at: Vector2)
				PartyController.OpenMenu(player, at)
			end,
			OnAttack = TargetController.AttackNearest,
			Sprinting = MovementController.Sprinting,
			OnSprint = MovementController.ToggleSprint,
			Riding = MountController.Riding,
			HasMount = MountController.Has,
			OnMount = MountController.Toggle,
			LoginStatus = LoginRewardController.Status,
			LoginBadge = LoginRewardController.Badge,
			OpenLogin = LoginRewardController.Open,
			OpenEmotes = EmoteController.Toggle,
			UsePotion = ItemController.UsePotion,
			AssignPotion = ItemController.SetPotion,
			CastSlot = SkillController.CastSlot,
			AimStart = SkillController.AimStart,
			AimMove = SkillController.AimMove,
			AimEnd = SkillController.AimEnd,
			ClearSlot = SkillController.ClearSlot,
			SkillUsable = SkillController.Usable,
			SkillColor = SkillController.Color,
			SelectTarget = function()
				local found = TargetController.FindNearest(60, true, false)
				if found then
					TargetController.SetTarget(found)
				end
			end,
		}).Parent =
			layer
		local name = State.Get({ "character", "name" })
		if name then
			Toast.push(Text.now("toast.enterWorld", { name = name }), "success")
		end
	end
end

function ScreenController.Init(registry)
	UIController = registry.Get("UIController")
	WindowManager = registry.Get("WindowManager")
	TargetController = registry.Get("TargetController")
	ItemController = registry.Get("ItemController")
	SkillController = registry.Get("SkillController")
	PartyController = registry.Get("PartyController")
	MovementController = registry.Get("MovementController")
	NavController = registry.Get("NavController")
	VfxController = registry.Get("VfxController")
	MountController = registry.Get("MountController")
	LoginRewardController = registry.Get("LoginRewardController")
	EmoteController = registry.Get("EmoteController")
	blur = Instance.new("BlurEffect")
	blur.Name = "Vaelthorn_SelectBlur"
	blur.Enabled = false
	blur.Parent = Lighting
	registerWindows()
end

function ScreenController.Start()
	local phase = State.Value({ "session", "phase" })
	local function apply()
		show(if Fusion.peek(phase) == "playing" then "hud" else "select")
	end
	UIController.Scope:Observer(phase):onBind(apply)

	-- Respawns (and the first spawn) hand the camera back to the new humanoid while playing.
	Players.LocalPlayer.CharacterAdded:Connect(function()
		if current == "hud" then
			task.defer(gameCamera)
		end
	end)
end

return ScreenController
