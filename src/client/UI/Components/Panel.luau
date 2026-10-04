--!strict
-- Dark rounded panel with a thin gold border. Base container for windows, cards and HUD blocks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Name: string?,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
	ZIndex: UsedAs<number>?,
	AutomaticSize: UsedAs<Enum.AutomaticSize>?,
	Raised: boolean?, -- lighter background
	BorderColor: UsedAs<Color3>?,
	BorderTransparency: UsedAs<number>?,
	Transparency: UsedAs<number>?,
	Padding: number?,
	Corner: UDim?,
	[typeof(Children)]: Fusion.Child?,
}

local function Panel(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local padding = props.Padding or Theme.Padding.Medium
	return scope:New("Frame")({
		Name = props.Name or "Panel",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		AutomaticSize = props.AutomaticSize,
		BackgroundColor3 = if props.Raised then Theme.Colors.PanelRaised else Theme.Colors.Panel,
		BackgroundTransparency = props.Transparency or 0.04,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = props.Corner or Theme.Corner.Medium }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = props.BorderColor or Theme.Colors.GoldDim,
				Transparency = props.BorderTransparency or 0.15,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, padding),
				PaddingBottom = UDim.new(0, padding),
				PaddingLeft = UDim.new(0, padding),
				PaddingRight = UDim.new(0, padding),
			}),
			props[Children] :: any,
		},
	})
end

return Panel
