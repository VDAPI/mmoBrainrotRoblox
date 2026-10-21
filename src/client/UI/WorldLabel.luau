--!strict
-- W31 (Studio review 2026-10-21: the white and gold names over the portals were lost on snow and ice, and one sat in
-- the painted arch's crown, hidden by the stone): the label over a portal or a boss gate (WorldController,
-- DungeonController). A BillboardGui always on top within its distance, `height` studs over its part, with the title
-- and the line under it on one iron plate with a brass edge and the HUD transparency (UI/PlateStyle), the text with a
-- dark stroke, so it reads on any ground or sky.

local Theme = require(script.Parent.Theme)

local WorldLabel = {}

export type Label = { gui: BillboardGui, title: TextLabel, sub: TextLabel }

local function line(parent: Instance, order: number, font: Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = Theme.Shade
	label.TextStrokeTransparency = 0.2
	label.Parent = parent
	return label
end

-- A label on `anchor` (its title in `titleColor`, the line under it in `subColor`), `height` studs over the part,
-- seen up to `distance` studs.
function WorldLabel.new(
	anchor: BasePart,
	name: string,
	height: number,
	distance: number,
	titleColor: Color3,
	subColor: Color3
): Label
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(320, 72)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = distance
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.AutomaticSize = Enum.AutomaticSize.XY
	plate.Size = UDim2.fromOffset(0, 0)
	plate.BackgroundColor3 = Theme.Iron.Surface
	plate.BackgroundTransparency = Theme.HudAlpha
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Small
	corner.Parent = plate
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Brass.Line
	stroke.Thickness = Theme.Stroke.Thin
	stroke.Parent = plate
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Padding.Small)
	padding.PaddingRight = UDim.new(0, Theme.Padding.Small)
	padding.PaddingTop = UDim.new(0, Theme.Padding.Tiny)
	padding.PaddingBottom = UDim.new(0, Theme.Padding.Tiny)
	padding.Parent = plate
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = plate
	local title = line(plate, 1, Theme.Fonts.Display, Theme.TextSize.Large + 2, titleColor)
	local sub = line(plate, 2, Theme.Fonts.BodyBold, Theme.TextSize.Small, subColor)
	return { gui = gui, title = title, sub = sub }
end

return WorldLabel
