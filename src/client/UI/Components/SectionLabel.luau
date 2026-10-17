--!strict
-- S135 section label (DESIGN §23 "Parchment and iron"): the text in upper case (Logic/TextCase, Polish letters too),
-- Caption size, the `Label` role, and a decorative rule under it. Full width; the height is fixed (Caption + rule).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local TextCase = require(ReplicatedStorage.Shared.Logic.TextCase)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

export type Props = {
	Text: Fusion.UsedAs<string>,
	LayoutOrder: Fusion.UsedAs<number>?,
	Position: Fusion.UsedAs<UDim2>?,
	Size: Fusion.UsedAs<UDim2>?,
	Surface: Theme.SurfaceName?, -- default "paper"
	Name: string?,
}

local HEIGHT = Theme.TextSize.Caption + 10

local function SectionLabel(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local roles = Theme.surface(props.Surface)
	return scope:New("Frame")({
		Name = props.Name or "SectionLabel",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		Size = props.Size or UDim2.new(1, 0, 0, HEIGHT),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("TextLabel")({
				Name = "Text",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -Theme.Stroke.Thin - 2),
				Text = scope:Computed(function(use): string
					return TextCase.upper(use(props.Text))
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Caption,
				TextColor3 = roles.Label,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Bottom,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("Frame")({
				Name = "Rule",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, Theme.Stroke.Thin),
				BackgroundColor3 = roles.Rule,
				BorderSizePixel = 0,
			}),
		},
	})
end

return SectionLabel
