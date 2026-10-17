--!strict
-- S135 list row (DESIGN §23 "Parchment and iron"): RowHeight high (>= 44, touch), alternating Surface / Sunken by
-- `Index`, a decorative rule at the bottom, Hover under the mouse, Selected with a brass bar on the left. Main text in
-- Body / Text, an optional second line in Small / TextMuted, an optional value aligned right. Extra children (icons,
-- buttons) go in [Children]; `Inset` leaves room on the left (an icon) and `RightInset` on the right (a button).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Text: UsedAs<string>,
	Sub: UsedAs<string?>?,
	Value: UsedAs<string?>?, -- right-aligned value (statistics)
	Index: number?, -- odd / even: the alternating background
	Selected: UsedAs<boolean>?,
	Muted: UsedAs<boolean>?, -- locked / unavailable: muted main text
	OnClick: (() -> ())?,
	Height: number?,
	Inset: number?,
	RightInset: number?,
	LayoutOrder: UsedAs<number>?,
	Name: string?,
	RichText: boolean?,
	Dense: boolean?, -- statistics and other compact lists: Small text instead of Body (the height is the caller's)
	Surface: Theme.SurfaceName?, -- default "paper"
	[typeof(Children)]: Fusion.Child?,
}

local BAR = 4

local function ListRow(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local roles = Theme.surface(props.Surface)
	local hovered = scope:Value(false)
	local height = props.Height or Theme.Size.RowHeight
	local inset = (props.Inset or 0) + Theme.Padding.Small + BAR
	local rightInset = (props.RightInset or 0) + Theme.Padding.Small
	local base = if (props.Index or 1) % 2 == 0 then roles.Sunken else roles.Surface
	local selected = scope:Computed(function(use): boolean
		return use(props.Selected) == true
	end)
	local hasSub = scope:Computed(function(use): boolean
		local sub = use(props.Sub)
		return sub ~= nil and sub ~= ""
	end)
	local hasValue = scope:Computed(function(use): boolean
		local value = use(props.Value)
		return value ~= nil and value ~= ""
	end)

	local className: string = if props.OnClick then "TextButton" else "Frame"
	local spec: { [any]: any } = {
		Name = props.Name or "ListRow",
		LayoutOrder = props.LayoutOrder,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = scope:Computed(function(use): Color3
			if use(selected) then
				return roles.Selected
			end
			return if use(hovered) and props.OnClick then roles.Hover else base
		end),
		BorderSizePixel = 0,
		Active = props.OnClick ~= nil,
		AutoButtonColor = if props.OnClick then false else nil,
		Text = if props.OnClick then "" else nil,
		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
		end,
		[Children] = {
			scope:New("Frame")({
				Name = "Bar",
				Size = UDim2.new(0, BAR, 1, 0),
				BackgroundColor3 = if props.Surface == "iron" then Theme.Brass.Line else Theme.Brass.Frame,
				BorderSizePixel = 0,
				Visible = selected,
			}),
			scope:New("Frame")({
				Name = "Rule",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, Theme.Stroke.Thin),
				BackgroundColor3 = roles.Rule,
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
			}),
			scope:New("TextLabel")({
				Name = "Main",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(inset, 0),
				Size = scope:Computed(function(use): UDim2
					local valueWidth = if use(hasValue) then 0.35 else 0
					return UDim2.new(1 - valueWidth, -inset - rightInset, if use(hasSub) then 0.55 else 1, 0)
				end),
				Text = props.Text,
				RichText = props.RichText == true,
				FontFace = if props.Dense then Theme.Fonts.BodyMedium else Theme.Fonts.BodyBold,
				TextSize = if props.Dense then Theme.TextSize.Small else Theme.TextSize.Body,
				TextColor3 = scope:Computed(function(use): Color3
					return if use(props.Muted) == true then roles.TextMuted else roles.Text
				end),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = scope:Computed(function(use): Enum.TextYAlignment
					return if use(hasSub) then Enum.TextYAlignment.Bottom else Enum.TextYAlignment.Center
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Name = "Sub",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, inset, 0.55, 0),
				Size = UDim2.new(1, -inset - rightInset, 0.45, 0),
				Visible = hasSub,
				Text = scope:Computed(function(use): string
					return use(props.Sub) or ""
				end),
				RichText = props.RichText == true,
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = roles.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Name = "Value",
				AnchorPoint = Vector2.new(1, 0),
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -rightInset, 0, 0),
				Size = UDim2.fromScale(0.35, 1),
				Visible = hasValue,
				Text = scope:Computed(function(use): string
					return use(props.Value) or ""
				end),
				RichText = props.RichText == true,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = if props.Dense then Theme.TextSize.Small else Theme.TextSize.Body,
				TextColor3 = roles.Text,
				TextXAlignment = Enum.TextXAlignment.Right,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			props[Children] :: any,
		},
	}
	local onClick = props.OnClick
	if onClick then
		spec[OnEvent("Activated")] = function()
			Sounds.play("click")
			onClick()
		end
	end
	return (scope :: any):New(className)(spec)
end

return ListRow
