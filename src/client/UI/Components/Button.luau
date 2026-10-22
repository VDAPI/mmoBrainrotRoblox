--!strict
-- Text button with variants (primary / secondary / danger / ghost), hover/press/disabled states and a
-- click sound. Works with mouse and touch (Activated). S135: colours from the roles of its `Surface`.

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
	Surface: Theme.SurfaceName?, -- S135: the background it stands on (default "paper"; HUD and overlays "iron")
}

-- Owner 2026-10-22 (Studio: the quest journal's 36 px "▶" left 8 px for its glyph): a button narrower than NARROW
-- (a glyph: "▶", "+", "−") keeps a tiny side padding, so the glyph has the button's width (tests/uifit.spec).
local NARROW = 64

type Palette = {
	base: Color3,
	hover: Color3,
	pressed: Color3,
	text: Color3,
	stroke: Color3,
	strokeT: number,
	clear: boolean?, -- ghost: no background until hovered
}

-- S135: palettes per surface from the roles (Data/UiPalette); hover / pressed are the base mixed towards black.
local function palettes(r: Theme.Roles, stroke: Color3): { [string]: Palette }
	return {
		primary = {
			base = r.Accent,
			hover = Theme.mix(r.Accent, Theme.Shade, 0.12),
			pressed = Theme.mix(r.Accent, Theme.Shade, 0.25),
			text = r.AccentText,
			stroke = Theme.Brass.Line,
			strokeT = 0,
		},
		secondary = {
			base = r.Raised,
			hover = r.Hover,
			pressed = r.Selected,
			text = r.Text,
			stroke = stroke,
			strokeT = 0,
		},
		danger = {
			base = r.Danger,
			hover = Theme.mix(r.Danger, Theme.Shade, 0.12),
			pressed = Theme.mix(r.Danger, Theme.Shade, 0.25),
			text = r.DangerText,
			stroke = stroke,
			strokeT = 0.3,
		},
		ghost = {
			base = r.Surface,
			hover = r.Hover,
			pressed = r.Selected,
			text = r.Link,
			stroke = stroke,
			strokeT = 1,
			clear = true,
		},
	}
end

local PALETTES: { [string]: { [string]: Palette } } = {
	paper = palettes(Theme.Paper, Theme.Paper.Border),
	iron = palettes(Theme.Iron, Theme.Iron.Border),
}

local function Button(scope: Fusion.Scope<typeof(Fusion)>, props: Props): Instance
	local hovered = scope:Value(false)
	local pressed = scope:Value(false)

	local surface = props.Surface or "paper"
	local set = PALETTES[surface] or PALETTES.paper
	local roles = Theme.surface(surface)
	local palette = scope:Computed(function(use): Palette
		local variant: string = use(props.Variant) or "secondary"
		return set[variant] or set.secondary
	end)
	local disabled = scope:Computed(function(use): boolean
		return use(props.Disabled) == true
	end)

	local background = scope:Computed(function(use): Color3
		local p = use(palette)
		if use(disabled) then
			return Theme.mix(p.base, roles.Surface, 0.6)
		elseif use(pressed) then
			return p.pressed
		elseif use(hovered) then
			return p.hover
		end
		return p.base
	end)

	local side = scope:Computed(function(use): UDim
		local size: UDim2? = use(props.Size)
		local narrow = size ~= nil and size.X.Scale == 0 and size.X.Offset < NARROW
		return UDim.new(0, if narrow then Theme.Padding.Tiny else Theme.Padding.Medium)
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
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(palette).clear and not (use(hovered) and not use(disabled)) then 1 else 0
		end),
		Text = props.Text,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = props.TextSize or Theme.TextSize.Body,
		TextColor3 = scope:Computed(function(use): Color3
			local color = use(palette).text
			return if use(disabled) then Theme.mix(color, roles.TextMuted, 0.6) else color
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
			-- W28: the button sinks a little while held
			scope:New("UIScale")({
				Scale = scope:Spring(
					scope:Computed(function(use): number
						return if use(pressed) and not use(disabled) then Theme.Anim.PressScale else 1
					end),
					Theme.Anim.PressSpeed,
					1
				),
			}),
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
				Color = ColorSequence.new(Theme.Plain, Theme.mix(Theme.Plain, Theme.Shade, 0.08)),
			}),
			scope:New("UIPadding")({
				PaddingLeft = side,
				PaddingRight = side,
			}),
		},
	})
end

return Button
