--!strict
-- Adaptive UI scale (ARCHITECTURE §9). Every layer has a Root frame sized 1/scale of the screen with a
-- UIScale inside, so layouts are authored in "virtual pixels" at the base resolution and full-screen
-- elements (fromScale(1, 1)) still cover the whole screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Device = require(script.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Theme)

local Scale = {}

-- Smallest scale per input type. Touch keeps buttons >= Theme.Size.MinTouch (44 / 52 ~ 0.85).
local MIN_SCALE_TOUCH = Theme.Size.MinTouch / Theme.Size.ButtonHeight
local MIN_SCALE_DESKTOP = 0.6
local MAX_SCALE = 1.5

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
	local touch = use(Device.Touch)
	local base = if touch then Theme.BaseResolutionTouch else Theme.BaseResolution
	local raw = math.min(size.X / base.X, size.Y / base.Y)
	return math.clamp(raw, if touch then MIN_SCALE_TOUCH else MIN_SCALE_DESKTOP, MAX_SCALE)
end)

-- Size of the screen in virtual pixels (what layouts inside a Root frame see).
Scale.VirtualSize = scope:Computed(function(use): Vector2
	return use(viewport) / use(Scale.Value)
end)

function Scale.get(): number
	return Fusion.peek(Scale.Value)
end

-- Screen pixels -> virtual pixels.
function Scale.toVirtual(point: Vector2): Vector2
	return point / Scale.get()
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
