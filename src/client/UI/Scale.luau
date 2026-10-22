--!strict
-- Adaptive UI scale (ARCHITECTURE §9). Every layer has a Root frame sized 1/scale of the screen with a
-- UIScale inside, so layouts are authored in "virtual pixels" at the base resolution and full-screen
-- elements (fromScale(1, 1)) still cover the whole screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UiScale = require(ReplicatedStorage.Shared.Logic.UiScale)

local Scale = {}

-- The scale per input type (bases, the smallest: touch keeps buttons >= Theme.Size.MinTouch, 44 / 52 ~ 0.85, and the
-- largest) is Logic/UiScale's, which the HUD tests lay out with.

local scope = Fusion.scoped(Fusion)
local viewport = scope:Value(Vector2.new(1920, 1080))

local function bindCamera(camera: Camera?)
	if not camera then
		return
	end
	viewport:set(camera.ViewportSize)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		viewport:set(camera.ViewportSize)
	end)
end

bindCamera(Workspace.CurrentCamera)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	bindCamera(Workspace.CurrentCamera)
end)

Scale.Viewport = viewport

Scale.Value = scope:Computed(function(use): number
	local size: Vector2 = use(viewport)
	return UiScale.factor(size.X, size.Y, use(Device.Touch) == true)
end)

-- Size of the screen in virtual pixels (what layouts inside a Root frame see).
Scale.VirtualSize = scope:Computed(function(use): Vector2
	return use(viewport) / use(Scale.Value)
end)

-- Owner 2026-10-22 (Studio: the quest tracker ran into the PvP toggle): the HUD's layer (Screens) keeps clear of
-- Roblox's top bar, so it is shorter than the screen (Logic/UiScale.hud). UIController reports the layer's size in
-- real pixels; HudSize is that in virtual pixels (the screen's until the layer is up): the size the HUD's elements
-- anchored to its edges see, which UI/HudSlots, UI/HudDrag and the panels lay out in.
local hudArea = scope:Value(nil :: Vector2?)

function Scale.SetHudArea(size: Vector2)
	hudArea:set(size)
end

Scale.HudSize = scope:Computed(function(use): Vector2
	local area = use(hudArea)
	if area and area.X > 0 and area.Y > 0 then
		return area / use(Scale.Value)
	end
	return use(Scale.VirtualSize)
end)

function Scale.get(): number
	return Fusion.peek(Scale.Value)
end

-- Screen pixels -> virtual pixels.
function Scale.toVirtual(point: Vector2): Vector2
	return point / Scale.get()
end

-- FIX 2026-10-14: a point in GUI space (InputObject.Position, AbsolutePosition: below the Roblox top bar) ->
-- virtual pixels inside a layer's Root frame. The layers ignore the top bar inset (IgnoreGuiInset) and sit inside
-- the device safe area, so their origin is not GUI space's origin: measuring from the Root itself covers both.
function Scale.toLayer(point: Vector2, root: GuiObject): Vector2
	return (point - root.AbsolutePosition) / Scale.get()
end

-- Builds the scaled Root frame for a layer.
function Scale.root(s: Fusion.Scope<typeof(Fusion)>, parent: Instance, name: string?): Frame
	return s:New("Frame")({
		Name = name or "Root",
		Parent = parent,
		BackgroundTransparency = 1,
		Size = s:Computed(function(use): UDim2
			local factor = use(Scale.Value)
			return UDim2.fromScale(1 / factor, 1 / factor)
		end),
		[Fusion.Children] = {
			s:New("UIScale")({ Scale = Scale.Value }),
		},
	}) :: Frame
end

return Scale
