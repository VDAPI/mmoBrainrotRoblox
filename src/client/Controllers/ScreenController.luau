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
local UiHubs = require(ReplicatedStorage.Shared.Data.UiHubs)

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
		"CameraController", -- Studio review 2026-10-31: the select shot is a camera claim ("select")
	},
}

local UIController: any
local CameraController: any
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

-- UI plan phase 3 (Data/UiHubs): what lights a hub's "!": its windows' own (the old bar buttons' and the tiles').
local TAB_BADGES: { [string]: (s: Scope) -> Fusion.UsedAs<boolean> } = {
	inventory = MenuAttention.statPoints, -- S155b: stat points wait
	skills = SkillsAttention.badge,
}
for id, def in TILE_DEFS do
	local badge = def.badge
	if badge then
		TAB_BADGES[id] = badge
	end
end

local function hubOf(hubId: string): UiHubs.Hub
	return assert(UiHubs.get(hubId), `no hub {hubId}`)
end

-- A hub's "!": one of its shown tabs has its own.
local function hubBadge(hubId: string): (s: Scope) -> Fusion.UsedAs<boolean>
	return function(s: Scope): Fusion.UsedAs<boolean>
		local lit: { { tab: string, badge: Fusion.UsedAs<boolean> } } = {}
		for _, tab in hubOf(hubId).tabs do
			local badge = TAB_BADGES[tab]
			if badge then
				table.insert(lit, { tab = tab, badge = badge(s) })
			end
		end
		return s:Computed(function(use): boolean
			for _, entry in lit do
				if use(entry.badge) == true and WindowManager.TabShown(use, entry.tab) then
					return true
				end
			end
			return false
		end)
	end
end

-- A hub's button shows while one of its tabs does (the world map and the journal need the world, S127).
local function hubVisible(hubId: string): (use: Fusion.Use) -> boolean
	return function(use: Fusion.Use): boolean
		for _, tab in hubOf(hubId).tabs do
			if WindowManager.TabShown(use, tab) then
				return true
			end
		end
		return false
	end
end

local function hubEntry(hubId: string, hotkey: string?, key: string?, art: string?): Hud.MenuEntry
	local hub = hubOf(hubId)
	local windows = table.clone(hub.tabs)
	for window, tab in UiHubs.ALIAS do
		if table.find(hub.tabs, tab) then
			table.insert(windows, window) -- the backpack window ("character") lights the backpack's hub
		end
	end
	return {
		id = hub.button,
		icon = hub.icon,
		hotkey = hotkey,
		key = key,
		art = art,
		tooltipKey = hub.labelKey,
		badge = hubBadge(hubId),
		visible = hubVisible(hubId),
		windows = windows,
		open = function()
			WindowManager.ToggleHub(hubId)
		end,
	}
end

-- The HUD bar (DESIGN §23): Logic/HudMenu.BAR in that order. UI plan phase 3: the five hubs and the ☰; the backpack's
-- hub keeps the id "inventory" (the tutorial points at it) and every window key still opens its own window.
local MENU: { Hud.MenuEntry } = {
	hubEntry("character", "B", "win_inventory"),
	hubEntry("world", "M", "win_map", UiArt.menu("map")),
	hubEntry("social", "P", "win_party", UiArt.menu("party")),
	hubEntry("rivalry", "U", "win_arena", UiArt.menu("arena")),
	hubEntry("shop", nil, nil, UiArt.menu("premium")),
	-- UI plan phase 1: "!" while a tile of the game menu outside the hubs has one
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
	-- title. UI plan phase 3: one job per tab (Logic/CharacterTabs), so the window is the backpack tab's width
	-- (260 + 22 + 500 and the padding) instead of 1240 x 700.
	WindowManager.Register({
		id = "character",
		titleKey = "window.inventory.title",
		size = Vector2.new(826, 752),
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
	-- UI plan phase 3: the settings in their own window (the menu's "Settings" button)
	WindowManager.Register({
		id = "settings",
		titleKey = "window.settings.title",
		size = Vector2.new(640, 700),
		build = function(s, close)
			return GameMenu(s, close, { OpenWindow = WindowManager.Open, Settings = true })
		end,
	})
	-- UI plan phase 3: a hub's tab shows like its tile or its old bar button (Data/UiHubs)
	WindowManager.SetTabRule("map", worldOnly)
	WindowManager.SetTabRule("quests", worldOnly)
	for id, def in TILE_DEFS do
		local visible = def.visible
		if visible then
			WindowManager.SetTabRule(id, visible)
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
	CameraController.Claim("select")
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

-- The select shot lets go; with no other owner the player's camera comes back (CameraController).
local function gameCamera()
	blur.Enabled = false
	CameraController.Release("select")
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
	CameraController = registry.Get("CameraController")
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
