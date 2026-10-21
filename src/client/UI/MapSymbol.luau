--!strict
-- One look for map symbols (owner 2026-10-20 "Mapa"): the dark plate in a category's shape ringed in its colour
-- (Logic/MapMarkers, Data/UiPalette.map), shared by the world map (WorldMap/Canvas, Overlay) and the minimap
-- (Hud/Minimap). Plain instances (no Fusion): the map layers are built imperatively and cached.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapMarkers = require(ReplicatedStorage.Shared.Logic.MapMarkers)
local Theme = require(script.Parent.Theme)
local UiPalette = require(ReplicatedStorage.Shared.Data.UiPalette)

local MapSymbol = {}

local MAP = UiPalette.map
MapSymbol.PLATE_COLOR = Theme.tint(MAP.plate)

-- Colour of a category.
function MapSymbol.color(id: string): Color3
	local category = MapMarkers.byId[id]
	local hex = if category then (MAP :: any)[category.color] else nil
	return Theme.tint(if type(hex) == "string" then hex else MAP.npc)
end

-- The dark plate of a symbol in its shape (round, diamond, square), ringed with `color`, centred in `parent`.
function MapSymbol.plate(
	parent: Instance,
	shape: MapMarkers.Shape,
	side: number,
	color: Color3,
	z: number
): (Frame, UIStroke)
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	local s = if shape == "diamond" then math.floor(side * 0.78) else side
	plate.Size = UDim2.fromOffset(s, s)
	plate.Rotation = if shape == "diamond" then 45 else 0
	plate.BackgroundColor3 = MapSymbol.PLATE_COLOR
	plate.BackgroundTransparency = 0.08
	plate.BorderSizePixel = 0
	plate.ZIndex = z
	plate.Active = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if shape == "round" then UDim.new(0.5, 0) else UDim.new(0, math.max(2, math.floor(side / 6)))
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = if side >= 28 then 2.5 else 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = plate
	plate.Parent = parent
	return plate, stroke
end

return MapSymbol
