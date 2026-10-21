--!strict
-- A short line with the shared "i" (Components/InfoTip) right after it (2026-10-21, owner: too many detailed
-- descriptions make the game hard to read). The text keeps its natural width up to the row minus the "i" and wraps past
-- it, so a short line reads "Short text (i)" and a long one still fits a narrow card or a phone. The long text sits in
-- the popover of the "i". `InfoVisible` hides the "i" when a state has nothing more to say.
--
--   InfoLine.new(scope, { Text = Text.T(scope, "x.short"), Info = Text.T(scope, "x"), LayoutOrder = 3 })
--
-- Recipe "short line + (i)": docs/JAK-DODAC.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local InfoTip = require(script.Parent.InfoTip)
local Scale = require(script.Parent.Parent.Scale)
local Theme = require(script.Parent.Parent.Theme)

local Children, Out = Fusion.Children, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Text: UsedAs<string>,
	Info: UsedAs<string>, -- the long text of the popover (rich text allowed)
	InfoTitle: UsedAs<string>?,
	InfoVisible: UsedAs<boolean>?,
	Font: Font?, -- default Theme.Fonts.Body
	TextSize: number?, -- default Theme.TextSize.Small
	Color: UsedAs<Color3>?, -- default the surface's text colour
	RichText: boolean?,
	Center: boolean?, -- centre the text and the "i" in the row (empty states)
	Surface: Theme.SurfaceName?, -- "paper" (default) or "iron"
	LayoutOrder: UsedAs<number>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	Size: UsedAs<UDim2>?, -- default full width; the height grows with the text (a given height is the least)
	Visible: UsedAs<boolean>?,
	ZIndex: number?,
	Name: string?,
}

local GAP = 6
local TIP_ROOM = 32 -- the "i" with its gap (a touch draws it a little larger)
local MIN_TEXT = 60 -- the text never collapses below this while the row is measured

local InfoLine = {}

function InfoLine.new(scope: Scope, props: Props): Instance
	local roles = Theme.surface(props.Surface)
	local rowSize = scope:Value(Vector2.zero)
	local maxWidth = scope:Computed(function(use): number
		local width = use(rowSize).X / use(Scale.Value)
		return math.max(MIN_TEXT, width - TIP_ROOM)
	end)
	return scope:New("Frame")({
		Name = props.Name or "InfoLine",
		LayoutOrder = props.LayoutOrder,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Size = props.Size or UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y, -- a given height is the least one
		Visible = props.Visible,
		ZIndex = props.ZIndex,
		BackgroundTransparency = 1,
		[Out("AbsoluteSize")] = rowSize,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = if props.Center
					then Enum.HorizontalAlignment.Center
					else Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, GAP),
			}),
			scope:New("TextLabel")({
				Name = "Text",
				LayoutOrder = 1,
				Size = UDim2.new(),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Text = props.Text,
				RichText = props.RichText,
				TextWrapped = true,
				FontFace = props.Font or Theme.Fonts.Body,
				TextSize = props.TextSize or Theme.TextSize.Small,
				TextColor3 = props.Color or roles.Text,
				TextXAlignment = if props.Center then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
				ZIndex = props.ZIndex,
				[Children] = scope:New("UISizeConstraint")({
					MaxSize = scope:Computed(function(use): Vector2
						return Vector2.new(use(maxWidth), math.huge)
					end),
				}),
			}),
			InfoTip.new(scope, {
				Text = props.Info,
				Title = props.InfoTitle,
				Surface = props.Surface,
				LayoutOrder = 2,
				Visible = props.InfoVisible,
				ZIndex = props.ZIndex,
			}),
		},
	})
end

return InfoLine
