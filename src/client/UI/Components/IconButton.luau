--!strict
-- Square button with a glyph icon (placeholder until real icons exist), optional hotkey badge and
-- tooltip text. Minimum size respects the 44 px touch target. S59: optional "!" badge in the top-right corner.
-- S119: optional `ArtKey` (Logic/UiArt): the white silhouette in the glyph colour replaces the glyph once loaded.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.ArtIcon)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Props = {
	Icon: UsedAs<string>,
	OnClick: (() -> ())?,
	Hotkey: UsedAs<string>?,
	Tooltip: UsedAs<string>?,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
	Active: UsedAs<boolean>?, -- highlighted (e.g. window open)
	Badge: UsedAs<boolean>?, -- S59: red "!" in the corner (something waits in the window)
	Visible: UsedAs<boolean>?, -- S97: hidden while false (the mounts entry below the mount level)
	Name: string?,
	ArtKey: UsedAs<string?>?, -- S119
}

local function IconButton(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)
	local size = Theme.Size.IconButton
	local artShown = ArtIcon.Shown(scope, props.ArtKey)

	local button = scope:New("TextButton")({
		Name = props.Name or "IconButton",
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromOffset(size, size),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Visible = if props.Visible ~= nil then props.Visible else true,
		BackgroundColor3 = scope:Tween(
			scope:Computed(function(use): Color3
				if use(pressed) then
					return Theme.Iron.Selected
				elseif use(props.Active) == true then
					return Theme.Iron.Hover
				end
				return if use(hovered) then Theme.Iron.Raised else Theme.Iron.Surface
			end),
			Theme.Anim.Fast
		),
		BackgroundTransparency = 0.05,
		Text = scope:Computed(function(use): string
			return if use(artShown) then "" else use(props.Icon)
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Large,
		TextColor3 = Theme.Iron.Heading,

		[OnEvent("MouseEnter")] = function()
			hovered:set(true)
		end,
		[OnEvent("MouseLeave")] = function()
			hovered:set(false)
			pressed:set(false)
		end,
		[OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
		end,
		[OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
		end,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			if props.OnClick then
				props.OnClick()
			end
		end,

		[Children] = {
			-- W28: pressed, the tile sinks (a short spring back on release)
			scope:New("UIScale")({
				Scale = scope:Spring(
					scope:Computed(function(use): number
						return if use(pressed) then Theme.Anim.PressScaleIcon else 1
					end),
					Theme.Anim.PressSpeed,
					1
				),
			}),
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = Theme.Brass.Line,
				Transparency = scope:Computed(function(use): number
					return if use(hovered) or use(props.Active) == true then 0 else 0.45
				end),
			}),
			scope:New("UISizeConstraint")({
				MinSize = Vector2.new(Theme.Size.MinTouch, Theme.Size.MinTouch),
			}),
			ArtIcon.Image(scope, {
				Key = props.ArtKey,
				Tint = Theme.Iron.Heading,
				Size = UDim2.fromScale(0.62, 0.62),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
			}),
			if props.Hotkey
				then scope:New("TextLabel")({
						Name = "Hotkey",
						-- S136: the key on a small iron plaque in the corner
						BackgroundColor3 = Theme.Iron.Sunken,
						BackgroundTransparency = Theme.BadgeAlpha,
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -2, 1, -2),
						Size = UDim2.fromOffset(18, 16),
						AutomaticSize = Enum.AutomaticSize.X,
						Text = props.Hotkey,
						Visible = scope:Computed(function(use): boolean
							return (use(props.Hotkey) or "") ~= ""
						end),
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Caption,
						TextColor3 = Theme.Iron.Text,
						[Children] = scope:New("UICorner")({ CornerRadius = UDim.new(0, 3) }),
					}) :: any
				else nil,
			if props.Badge
				then scope:New("TextLabel")({
					Name = "Badge",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 4, 0, -4),
					Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = Theme.Iron.Danger,
					Text = "!",
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Caption,
					TextColor3 = Theme.Iron.DangerText,
					ZIndex = 3,
					Visible = props.Badge,
					[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Round }),
				}) :: any
				else nil,
		},
	})

	if props.Tooltip then
		Tooltip.attach(scope, button :: GuiObject, props.Tooltip)
	end
	return button
end

return IconButton
