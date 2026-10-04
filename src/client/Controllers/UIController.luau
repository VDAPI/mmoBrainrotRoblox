--!strict
-- Owns the ScreenGui layers (ARCHITECTURE §9): Screens < Windows < Modals < Toasts < Tooltip.
-- Each layer has a scaled Root frame (UI/Scale); mount UI into UIController.GetLayer(name).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.UI.Scale)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local Tooltip = require(script.Parent.Parent.UI.Components.Tooltip)

export type LayerName = "Screens" | "Windows" | "Modals" | "Toasts" | "Tooltip"

local LAYERS: { { name: LayerName, order: number } } = {
	{ name = "Screens", order = 1 },
	{ name = "Windows", order = 5 },
	{ name = "Modals", order = 10 },
	{ name = "Toasts", order = 20 },
	{ name = "Tooltip", order = 30 },
}

local UIController = {
	Name = "UIController",
	Scope = Fusion.scoped(Fusion),
}

local roots: { [string]: Frame } = {}

function UIController.GetLayer(name: LayerName): Frame
	local root = roots[name]
	assert(root, `UIController: unknown layer {name}`)
	return root
end

function UIController.Init()
	local scope = UIController.Scope
	-- PlayerGui exists before PlayerScripts run in practice; the wait is a safety net.
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, layer in LAYERS do
		local gui = scope:New("ScreenGui")({
			Name = `Vaelthorn_{layer.name}`,
			DisplayOrder = layer.order,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui,
		})
		roots[layer.name] = Scale.root(scope, gui)
	end

	Toast.mount(scope, roots.Toasts)
	Tooltip.mount(scope, roots.Tooltip)

	scope:Observer(State.Value({ "account", "settings", "volume" })):onBind(function()
		local volume = Fusion.peek(State.Value({ "account", "settings", "volume" }))
		if type(volume) == "number" then
			Sounds.setVolume(volume)
		end
	end)
end

return UIController
