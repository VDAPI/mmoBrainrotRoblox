--!strict
-- Switches the main screen with the session phase: CharacterSelect ("loading"/"select") or Hud
-- ("playing"). Handles the selection camera (blurred city view) and registers the HUD menu windows.
-- UI plan phase 1 (owner 2026-10-31, "too much information and too many options on one screen"; Logic/HudMenu): the
-- HUD bar keeps six buttons (MENU), every other window is a tile of the game menu (TILES), its "!" lights the bar's ☰.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterSelect = require(script.Parent.Parent.UI.Screens.CharacterSelect)
local ServerModeView = require(script.Parent.Parent.UI.ServerModeView)
local CharacterWindow = require(script.Parent.Parent.UI.Screens.CharacterWindow)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GameMenu = require(script.Parent.Parent.UI.Screens.GameMenu)
local BackpackPanel = require(script.Parent.Parent.UI.Screens.BackpackPanel)
local HudMenu = require(ReplicatedStorage.Shared.Logic.HudMenu)
local Mail = require(ReplicatedStorage.Shared.Logic.Mail)
local MenuAttention = require(script.Parent.Parent.UI.MenuAttention) -- S155b
local SkillsAttention = require(script.Parent.Parent.UI.SkillsAttention)
local SkillsWindow = require(script.Parent.Parent.UI.Screens.SkillsWindow)
local Hud = require(script.Parent.Parent.UI.Screens.Hud)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local SeasonState = require(script.Parent.Parent.UI.SeasonState)
local SeasonView = require(ReplicatedStorage.Shared.Logic.SeasonView)
local Town = require(ReplicatedStorage.Shared.Data.Town)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

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
		"LoginRewardController", -- S100: the HUD button's status and badge, the tile's "!"
		"EmoteController", -- S123: the emote wheel (UI plan phase 1: a tile of the game menu)
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

-- UI plan phase 1: the game menu's tiles (UI/Screens/GameMenu) by id, laid out in the order of HudMenu.TILES. Their
-- windows are registered by GuildController, PartyController, SocialController (friends, S133), MarketController
-- (mail), ArenaController (S126), RankingsController (S124), BloodMoonController (S129), AchievementController
-- (S151b), MountController (S97), PremiumController (wardrobe, VIP), SeasonController (S152b), LoginRewardController
-- (S100) and ReturningController ("What's new", S153); the emote wheel is EmoteController's (S123).
local TILE_DEFS: { [string]: GameMenu.Tile } = {
	guild = { id = "guild", icon = "⚑", art = UiArt.menu("guild"), labelKey = "menu.tile.guild" },
	party = { id = "party", icon = "☍", art = UiArt.menu("party"), labelKey = "menu.tile.party" },
	friends = { id = "friends", icon = "☺", art = UiArt.menu("friends"), labelKey = "menu.tile.friends" },
	-- "!" while parcels wait (the envelope in the corner shows their number)
	mail = {
		id = "mail",
		icon = "✉",
		art = UiArt.hud("mail"),
		labelKey = "menu.tile.mail",
		badge = function(s: Scope): Fusion.UsedAs<boolean>
			local mail = State.Value({ "mail" })
			return s:Computed(function(use): boolean
				return (Mail.badge(use(mail))) > 0
			end)
		end,
	},
	-- S155b: "!" after the level up that unlocks it
	arena = {
		id = "arena",
		icon = "⚔",
		art = UiArt.menu("arena"),
		labelKey = "menu.tile.arena",
		badge = MenuAttention.unlocked("arena"),
	},
	rankings = { id = "rankings", icon = "♔", art = UiArt.menu("rankings"), labelKey = "menu.tile.rankings" },
	-- always (the window tells when the next one rises; the event has its own panel on the HUD)
	bloodmoon = { id = "bloodmoon", icon = "☾", art = UiArt.menu("bloodmoon"), labelKey = "menu.tile.bloodmoon" },
	-- S151c: "!" after an achievement or a bestiary tier earned since the window was last open
	achievements = {
		id = "achievements",
		icon = "✪",
		art = UiArt.menu("achievements"),
		labelKey = "menu.tile.achievements",
		badge = MenuAttention.achievements,
	},
	-- S97: from the mount level, or earlier with a mount (MountController.Access); S155b: "!" after the unlock
	mounts = {
		id = "mounts",
		icon = "♞",
		art = UiArt.menu("mounts"),
		labelKey = "menu.tile.mounts",
		badge = MenuAttention.unlocked("mounts"),
		visible = function(use: Fusion.Use): boolean
			return use(MountController.Access) == true and ServerModeView.isWorld()
		end,
	},
	wardrobe = { id = "wardrobe", icon = "♛", art = UiArt.menu("wardrobe"), labelKey = "menu.tile.wardrobe" },
	-- S123: the emote wheel (T; a touch screen has only this tile)
	emotes = {
		id = "emotes",
		icon = "✋",
		labelKey = "menu.tile.emotes",
		open = function()
			EmoteController.Toggle()
		end,
	},
	-- S152b: "!" while a reward waits (the ❖ by the portrait shows then too)
	season = {
		id = "season",
		icon = "❖",
		art = UiArt.hud("season"),
		labelKey = "menu.tile.season",
		badge = function(s: Scope): Fusion.UsedAs<boolean>
			return s:Computed(function(use): boolean
				return SeasonView.claimCount(use(SeasonState.View)) > 0
			end)
		end,
	},
	-- S100: "!" while today's reward waits (the ✧ by the portrait shows then too)
	login = {
		id = "login",
		icon = "✧",
		labelKey = "menu.tile.login",
		badge = function(_s: Scope): Fusion.UsedAs<boolean>
			return LoginRewardController.Badge
		end,
	},
	vip = { id = "vip", icon = "★", art = UiArt.hud("vip"), labelKey = "menu.tile.vip" },
	whatsnew = { id = "whatsnew", icon = "✷", labelKey = "menu.tile.whatsnew" },
}

local TILES: { GameMenu.Tile } = {}
for _, id in HudMenu.TILES do
	local def = TILE_DEFS[id]
	assert(def, `no menu tile {id}`)
	table.insert(TILES, def)
end

type Lit = { id: string, badge: Fusion.UsedAs<boolean>, visible: ((use: Fusion.Use) -> boolean)? }

-- The ☰'s "!": a shown tile's own is lit (Logic/HudMenu.attention).
local function tilesBadge(s: Scope): Fusion.Computed<boolean>
	local lit: { Lit } = {}
	for _, entry in TILES do
		local badge = entry.badge
		if badge then
			table.insert(lit, { id = entry.id, badge = badge(s), visible = entry.visible })
		end
	end
	return s:Computed(function(use): boolean
		local now: { [string]: boolean } = {}
		for _, t in lit do
			local visible = t.visible
			now[t.id] = use(t.badge) == true and (visible == nil or visible(use))
		end
		return HudMenu.attention(now)
	end)
end

-- The HUD bar (DESIGN §23): Logic/HudMenu.BAR in that order.
local MENU: { Hud.MenuEntry } = {
	-- S155b: "!" while stat points wait (MenuAttention)
	{
		id = "inventory",
		icon = "▣",
		hotkey = "B",
		tooltipKey = "hud.menu.inventory",
		badge = MenuAttention.statPoints,
	},
	{ id = "skills", icon = "✦", hotkey = "K", tooltipKey = "hud.menu.skills", badge = SkillsAttention.badge },
	-- S127: the world map and the journal need the world (hidden on an arena server)
	{ id = "map", icon = "⌖", hotkey = "M", tooltipKey = "hud.menu.map", visible = worldOnly },
	{ id = "quests", icon = "✎", hotkey = "L", tooltipKey = "hud.menu.quests", visible = worldOnly },
	{ id = "premium", icon = "◆", hotkey = nil, tooltipKey = "hud.menu.shop" },
	-- UI plan phase 1: "!" while a tile of the game menu has one
	{ id = "menu", icon = "☰", hotkey = nil, tooltipKey = "hud.menu.menu", badge = tilesBadge },
}

-- The default keys of the windows registered here (Data/Keybinds `win_<id>` decides; WindowManager).
local HOTKEYS: { [string]: Enum.KeyCode } = {
	inventory = Enum.KeyCode.B,
	skills = Enum.KeyCode.K,
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
	-- The bar's windows but the world map, the journal and the Dragon Shop (WorldController, QuestController,
	-- PremiumController); the tiles' windows are their controllers' (TILE_DEFS).
	WindowManager.Register({
		id = "skills",
		titleKey = "window.skills.title",
		size = Vector2.new(920, 640),
		hotkey = HOTKEYS.skills,
		build = function(scope: Scope)
			return SkillsWindow(scope, { ShowModal = WindowManager.ShowModal, Preview = VfxController.Preview })
		end,
	})
	-- S29: the backpack window: equipment + backpack + statistics in one (WindowRules.MAIN, opened by B without a
	-- service). FIX 2026-10-14: the separate "Character" button and its C key are gone; the window has the backpack's
	-- title.
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
	WindowManager.Register({
		id = "menu",
		titleKey = "window.menu.title",
		size = Vector2.new(640, 700),
		-- S121: the menu opens the VIP window; UI plan phase 1: and every tile's
		build = function(s, close)
			return GameMenu(s, close, { OpenWindow = WindowManager.Open, Tiles = TILES })
		end,
	})
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
			UsePotion = ItemController.UsePotion,
			AssignPotion = ItemController.SetPotion,
			CastSlot = SkillController.CastSlot,
			AimStart = SkillController.AimStart,
			AimMove = SkillController.AimMove,
			AimEnd = SkillController.AimEnd,
			ClearSlot = SkillController.ClearSlot,
			SkillUsable = SkillController.Usable,
			SkillColor = SkillController.Color,
			SkillCost = SkillController.Cost,
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
