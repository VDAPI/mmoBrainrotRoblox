--!strict
-- Horizontal tab strip. The caller renders the content for Fusion.peek(Selected). S98: `Scroll` puts the strip in a
-- horizontal ScrollingFrame (many tabs on a phone, e.g. the quest journal's six categories).
-- S135: parchment cards: the selected tab is the page colour with an iron frame and an open bottom (it joins the
-- content under it), the others sunken with muted text; >= 44 px high. `Surface = "iron"` on dark backgrounds.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Tab = { id: string, label: UsedAs<string> }

export type Props = {
	Tabs: { Tab },
	Selected: Fusion.Value<string>,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	LayoutOrder: UsedAs<number>?,
	Scroll: boolean?, -- S98
	Surface: Theme.SurfaceName?, -- S135 (default "paper")
}

-- S98: the thin scroll bar under a scrolling strip
local BAR = 4

local function Tabs(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	-- S98: in a scrolling strip the buttons leave room for the scroll bar under them
	local buttonSize = if props.Scroll then UDim2.new(0, 0, 1, -BAR - 2) else UDim2.fromScale(0, 1)
	local roles = Theme.surface(props.Surface)
	local frameColor = if props.Surface == "iron" then Theme.Brass.Line else Theme.Brass.Frame
	local buttons = {}
	for index, tab in props.Tabs do
		local isSelected = scope:Computed(function(use): boolean
			return use(props.Selected) == tab.id
		end)
		table.insert(
			buttons,
			scope:New("TextButton")({
				Name = tab.id,
				LayoutOrder = index,
				AutoButtonColor = false,
				Size = buttonSize,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = scope:Computed(function(use): Color3
					return if use(isSelected) then roles.Surface else roles.Sunken
				end),
				Text = tab.label,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(isSelected) then roles.Heading else roles.TextMuted
				end),
				[OnEvent("Activated")] = function()
					Sounds.play("click")
					props.Selected:set(tab.id)
				end,
				[Children] = {
					scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					scope:New("UIPadding")({
						PaddingLeft = UDim.new(0, Theme.Padding.Large),
						PaddingRight = UDim.new(0, Theme.Padding.Large),
					}),
					scope:New("UIStroke")({
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
						Thickness = Theme.Stroke.Normal,
						Color = frameColor,
						Enabled = isSelected,
					}),
					-- the open bottom of the selected card
					scope:New("Frame")({
						Name = "Join",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 1, -Theme.Stroke.Normal),
						Size = UDim2.new(1, 0, 0, Theme.Stroke.Normal * 2 + 1),
						BackgroundColor3 = roles.Surface,
						BorderSizePixel = 0,
						ZIndex = 2,
						Visible = isSelected,
					}),
				},
			})
		)
	end

	local layout = scope:New("UIListLayout")({
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, Theme.Padding.Small),
	})
	if props.Scroll then
		return scope:New("ScrollingFrame")({
			Name = "Tabs",
			Size = props.Size or UDim2.new(1, 0, 0, Theme.Size.MinTouch + BAR + 2),
			Position = props.Position,
			LayoutOrder = props.LayoutOrder,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			ScrollingDirection = Enum.ScrollingDirection.X,
			ScrollBarThickness = BAR,
			ScrollBarImageColor3 = roles.TextMuted,
			VerticalScrollBarInset = Enum.ScrollBarInset.None,
			HorizontalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
			[Children] = {
				layout,
				buttons :: any,
			},
		})
	end
	return scope:New("Frame")({
		Name = "Tabs",
		Size = props.Size or UDim2.new(1, 0, 0, Theme.Size.MinTouch),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		[Children] = {
			layout,
			buttons :: any,
		},
	})
end

return Tabs
