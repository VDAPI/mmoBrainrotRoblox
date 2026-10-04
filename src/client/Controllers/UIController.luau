--!strict
-- Owns the ScreenGui layers (ARCHITECTURE §9): Screens < Windows < Modals < Toasts < Tooltip.
-- Each layer has a scaled Root frame (UI/Scale); mount UI into UIController.GetLayer(name).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Announcement = require(script.Parent.Parent.UI.Components.Announcement)
local DragDrop = require(script.Parent.Parent.UI.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemTooltip = require(script.Parent.Parent.UI.Components.ItemTooltip)
local Theme = require(script.Parent.Parent.UI.Theme)
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

-- Icon following the mouse while something is dragged (UI/DragDrop). Controllers register providers that
-- return (glyph, colour hex) for slot ids they own.
local dragVisuals: { (slotId: string) -> (string?, string?) } = {}

function UIController.AddDragVisual(provider: (slotId: string) -> (string?, string?))
	table.insert(dragVisuals, provider)
end

local function dragVisual(slotId: string): (string?, string?)
	for _, provider in dragVisuals do
		local glyph, color = provider(slotId)
		if glyph then
			return glyph, color
		end
	end
	return nil, nil
end

function UIController.MountDragGhost(scope: Fusion.Scope<typeof(Fusion)>, parent: Instance)
	local visual = scope:Computed(function(use): { glyph: string, color: string }?
		local dragging = use(DragDrop.Dragging)
		if not dragging then
			return nil
		end
		local glyph, color = dragVisual(dragging)
		return if glyph then { glyph = glyph, color = color or "#252832" } else nil
	end)
	scope:New("TextLabel")({
		Name = "DragGhost",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(56, 56),
		Position = scope:Computed(function(use): UDim2
			local p: Vector2 = use(DragDrop.GhostPosition)
			return UDim2.fromOffset(p.X, p.Y)
		end),
		Visible = scope:Computed(function(use): boolean
			return use(visual) ~= nil
		end),
		BackgroundColor3 = scope:Computed(function(use): Color3
			local v = use(visual)
			return if v then Color3.fromHex(v.color) else Theme.Colors.Panel
		end),
		BackgroundTransparency = 0.3,
		Text = scope:Computed(function(use): string
			local v = use(visual)
			return if v then v.glyph else ""
		end),
		TextScaled = true,
		FontFace = Theme.Fonts.BodyBold,
		TextColor3 = Theme.Colors.Text,
		ZIndex = 300,
		[Fusion.Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Colors.Gold, Thickness = 2 }),
		},
	})
end

function UIController.Init()
	local scope = UIController.Scope
	-- Our own HUD replaces Roblox's backpack (keys 1–0 are the skill bar) and health bar.
	local StarterGui = game:GetService("StarterGui")
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
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
	Announcement.mount(scope, roots.Toasts)
	Tooltip.mount(scope, roots.Tooltip)
	ItemTooltip.mount(scope, roots.Tooltip)
	UIController.MountDragGhost(scope, roots.Tooltip)

	scope:Observer(State.Value({ "account", "settings", "volume" })):onBind(function()
		local volume = Fusion.peek(State.Value({ "account", "settings", "volume" }))
		if type(volume) == "number" then
			Sounds.setVolume(volume)
		end
	end)
end

return UIController
