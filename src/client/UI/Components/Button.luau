--!strict
-- Text button with variants (primary / secondary / danger / ghost), hover/press/disabled states and a
-- click sound. Works with mouse and touch (Activated).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type Variant = "primary" | "secondary" | "danger" | "ghost"

export type Props = {
	Text: UsedAs<string>,
	OnClick: (() -> ())?,
	Variant: UsedAs<Variant>?,
	Disabled: UsedAs<boolean>?,
	Size: UsedAs<UDim2>?,
	Position: UsedAs<UDim2>?,
	AnchorPoint: UsedAs<Vector2>?,
	LayoutOrder: UsedAs<number>?,
	TextSize: UsedAs<number>?,
	Visible: UsedAs<boolean>?,
	Name: string?,
}

type Palette = { base: Color3, hover: Color3, pressed: Color3, text: Color3, stroke: Color3, strokeT: number }

local PALETTES: { [string]: Palette } = {
	primary = {
		base = Theme.Colors.Accent,
		hover = Theme.Colors.AccentHover,
		pressed = Theme.Colors.AccentPressed,
		text = Color3.new(1, 1, 1),
		stroke = Theme.Colors.Gold,
		strokeT = 0.35,
	},
	secondary = {
		base = Theme.Colors.PanelRaised,
		hover = Theme.Colors.PanelHover,
		pressed = Theme.Colors.Panel,
		text = Theme.Colors.Text,
		stroke = Theme.Colors.Gold,
		strokeT = 0.2,
	},
	danger = {
		base = Theme.Colors.Danger,
		hover = Theme.Colors.DangerHover,
		pressed = Theme.Colors.Danger:Lerp(Color3.new(0, 0, 0), 0.25),
		text = Color3.new(1, 1, 1),
		stroke = Theme.Colors.Gold,
		strokeT = 0.5,
	},
	ghost = {
		base = Theme.Colors.Panel,
		hover = Theme.Colors.PanelRaised,
		pressed = Theme.Colors.Panel,
		text = Theme.Colors.TextMuted,
		stroke = Theme.Colors.Border,
		strokeT = 0,
	},
}

local function Button(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)

	local palette = scope:Computed(function(use): Palette
		local variant: string = use(props.Variant) or "secondary"
		return PALETTES[variant] or PALETTES.secondary
	end)
	local disabled = scope:Computed(function(use): boolean
		return use(props.Disabled) == true
	end)

	local background = scope:Computed(function(use): Color3
		local p = use(palette)
		if use(disabled) then
			return p.base:Lerp(Theme.Colors.Panel, 0.6)
		elseif use(pressed) then
			return p.pressed
		elseif use(hovered) then
			return p.hover
		end
		return p.base
	end)

	return scope:New("TextButton")({
		Name = props.Name or "Button",
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromOffset(220, Theme.Size.ButtonHeight),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		BackgroundColor3 = scope:Tween(background, Theme.Anim.Fast),
		Text = props.Text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = props.TextSize or Theme.TextSize.Body,
		TextColor3 = scope:Computed(function(use): Color3
			local color = use(palette).text
			return if use(disabled) then color:Lerp(Theme.Colors.TextMuted, 0.6) else color
		end),
		TextWrapped = true,

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
			if Fusion.peek(disabled) then
				return
			end
			Sounds.play("click")
			if props.OnClick then
				props.OnClick()
			end
		end,

		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Normal,
				Color = scope:Computed(function(use): Color3
					return use(palette).stroke
				end),
				Transparency = scope:Computed(function(use): number
					return if use(hovered) and not use(disabled) then 0 else use(palette).strokeT
				end),
			}),
			scope:New("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Padding.Medium),
				PaddingRight = UDim.new(0, Theme.Padding.Medium),
			}),
		},
	})
end

return Button
