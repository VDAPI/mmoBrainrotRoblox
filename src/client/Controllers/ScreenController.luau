--!strict
-- Switches the main screen with the session phase: CharacterSelect ("loading"/"select") or Hud
-- ("playing"). Handles the selection camera (blurred city view) and registers the HUD menu windows.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterSelect = require(script.Parent.Parent.UI.Screens.CharacterSelect)
local CharacterWindow = require(script.Parent.Parent.UI.Screens.CharacterWindow)
local ComingSoon = require(script.Parent.Parent.UI.Screens.ComingSoon)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GameMenu = require(script.Parent.Parent.UI.Screens.GameMenu)
local Hud = require(script.Parent.Parent.UI.Screens.Hud)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

type Scope = Fusion.Scope<typeof(Fusion)>

local ScreenController = {
	Name = "ScreenController",
	Deps = { "UIController", "WindowManager", "StateController" },
}

local UIController: any
local WindowManager: any

-- HUD menu (DESIGN §23). Windows without their system yet show a "coming soon" body.
local MENU: { Hud.MenuEntry } = {
	{ id = "character", icon = "♜", hotkey = "C", tooltipKey = "hud.menu.character" },
	{ id = "inventory", icon = "▣", hotkey = "B", tooltipKey = "hud.menu.inventory" },
	{ id = "skills", icon = "✦", hotkey = "K", tooltipKey = "hud.menu.skills" },
	{ id = "map", icon = "⌖", hotkey = "M", tooltipKey = "hud.menu.map" },
	{ id = "quests", icon = "✎", hotkey = "L", tooltipKey = "hud.menu.quests" },
	{ id = "guild", icon = "⚑", hotkey = "G", tooltipKey = "hud.menu.guild" },
	{ id = "party", icon = "☍", hotkey = "P", tooltipKey = "hud.menu.party" },
	{ id = "menu", icon = "☰", hotkey = nil, tooltipKey = "hud.menu.menu" },
}

local HOTKEYS: { [string]: Enum.KeyCode } = {
	character = Enum.KeyCode.C,
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

local function registerWindows()
	for _, entry in MENU do
		if entry.id == "character" then
			WindowManager.Register({
				id = "character",
				titleKey = "window.character.title",
				size = Vector2.new(900, 640),
				hotkey = HOTKEYS.character,
				build = CharacterWindow,
			})
		elseif entry.id == "menu" then
			WindowManager.Register({
				id = "menu",
				titleKey = "window.menu.title",
				size = Vector2.new(420, 380),
				build = GameMenu,
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
	local centre = Vector3.new(city.offset.x, city.offset.y + 6, city.offset.z)
	local eye = centre + Vector3.new(70, 48, 110)
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
			IsOpen = WindowManager.IsOpen,
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
