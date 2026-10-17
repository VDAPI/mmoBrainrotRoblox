--!strict
-- S136: the iron plate style of the name labels over NPCs and companions (built with Instance.new in their
-- controllers): the same look as the players' and monsters' nameplates (DESIGN §23): an iron tile with the HUD
-- transparency and a 1 px brass edge, centred, as wide as the name; the name in iron text with a dark stroke.

local Theme = require(script.Parent.Theme)

local PlateStyle = {}

-- Turns a full-width TextLabel into a centred plate at the same top offset.
function PlateStyle.name(label: TextLabel)
	local top = label.Position.Y.Offset
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, top)
	label.Size = UDim2.fromOffset(0, label.Size.Y.Offset)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.BackgroundColor3 = Theme.Iron.Surface
	label.BackgroundTransparency = Theme.HudAlpha
	label.TextColor3 = Theme.Iron.Text
	label.TextStrokeColor3 = Theme.Shade
	label.TextStrokeTransparency = 0.2
	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.Corner.Small
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Theme.Brass.Line
	stroke.Thickness = Theme.Stroke.Thin
	stroke.Parent = label
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Padding.Small)
	padding.PaddingRight = UDim.new(0, Theme.Padding.Small)
	padding.Parent = label
end

return PlateStyle
