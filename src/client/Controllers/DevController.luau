--!strict
-- Dev panel (S23): the window (F2, an overlay that leaves other windows open) and a small gold "DEV" button
-- on the HUD, both only for players with the "Admin" attribute (set by AdminService; visibility only, the
-- server checks every call) while playing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DevWindow = require(script.Parent.Parent.UI.Screens.DevWindow)
local Dev = require(script.Parent.Parent.UI.Screens.DevWindow.Dev)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.UI.State)
local Theme = require(script.Parent.Parent.UI.Theme)

local DevController = {
	Name = "DevController",
	Deps = { "WindowManager", "UIController", "DecorController", "TownDetailController" },
}

local WindowManager: any
local scope = Fusion.scoped(Fusion)
local isAdmin = scope:Value(Players.LocalPlayer:GetAttribute("Admin") == true)

function DevController.IsAdmin(): boolean
	return Fusion.peek(isAdmin)
end

function DevController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	local controllers = {
		DecorController = registry.Get("DecorController"),
		TownDetailController = registry.Get("TownDetailController"),
	}
	Dev.setModal(WindowManager.ShowModal)
	WindowManager.Register({
		id = "dev",
		titleKey = "window.dev.title",
		size = Vector2.new(1000, 700),
		hotkey = Enum.KeyCode.F2,
		overlay = true,
		enabled = DevController.IsAdmin,
		build = function(s)
			return DevWindow(s, { Controllers = controllers })
		end,
	})
	local UIController = registry.Get("UIController")
	local phase = State.Value({ "session", "phase" })
	scope:New("TextButton")({
		Name = "DevButton",
		Parent = UIController.GetLayer("Screens"),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -230),
		Size = UDim2.fromOffset(Theme.Size.MinTouch + 16, Theme.Size.MinTouch),
		Visible = scope:Computed(function(use): boolean
			return use(isAdmin) and use(phase) == "playing"
		end),
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Colors.GoldDim,
		Text = "DEV",
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.GoldBright,
		ZIndex = 5,
		[Fusion.OnEvent("Activated")] = function()
			WindowManager.Toggle("dev")
		end,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		},
	})
end

function DevController.Start()
	Players.LocalPlayer:GetAttributeChangedSignal("Admin"):Connect(function()
		isAdmin:set(Players.LocalPlayer:GetAttribute("Admin") == true)
	end)
end

return DevController
