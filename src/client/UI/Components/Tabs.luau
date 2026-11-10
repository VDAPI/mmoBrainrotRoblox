--!strict
-- Horizontal tab strip. The caller renders the content for Fusion.peek(Selected). S98: `Scroll` puts the strip in a
-- horizontal ScrollingFrame (many tabs on a phone, e.g. the quest journal's six categories).
-- S135: parchment cards: the selected tab is the page colour with an iron frame and an open bottom (it joins the
-- content under it), the others sunken with muted text; >= 44 px high. `Surface = "iron"` on dark backgrounds.
-- Owner 2026-11-10 ("too much text, things covering each other"), UI package C: no tab is ever out of reach (the
-- quest journal's "Tygodniowe" stood past the strip's end). When the labels do not fit the strip, the whole row first
-- takes less padding, then the smaller text (Logic/WindowFrame.tabFit, one look for the row), and past that it
-- scrolls sideways with ◂ / ▸ at an edge that hides tabs; the selected tab is scrolled into view. The strip is
-- Theme.Size.TabHeight (44) high; a caller's Size sets its width and, until the window adopts the token, its height.
-- `Scroll` keeps the thin scroll bar under the row (and the room for it).
-- Review 2026-11-10: the tabs are as tall as the strip again (less the bar's room; Logic/WindowFrame.tabStrip): the
-- selected card's frame has its room in a band above the strip, where it took 2 px off every tab inside it, and the
-- bar no longer shrinks them while it shows. The ◂ / ▸ are a whole touch target on a touch screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Sounds = require(script.Parent.Parent.Sounds)
local Theme = require(script.Parent.Parent.Theme)
local WindowFrame = require(ReplicatedStorage.Shared.Logic.WindowFrame)

local Children, OnEvent, Out = Fusion.Children, Fusion.OnEvent, Fusion.Out

type UsedAs<T> = Fusion.UsedAs<T>
type Scope = Fusion.Scope<typeof(Fusion)>

export type Tab = { id: string, label: UsedAs<string> }

export type Props = {
	Tabs: { Tab },
	Selected: Fusion.Value<string>,
	Size: UsedAs<UDim2>?, -- default: full width, Theme.Size.TabHeight high (plus the scroll bar with `Scroll`)
	Position: UsedAs<UDim2>?,
	LayoutOrder: UsedAs<number>?,
	Scroll: boolean?, -- S98: the thin scroll bar under the row
	Surface: Theme.SurfaceName?, -- S135 (default "paper")
}

-- S98: the thin scroll bar under a scrolling strip (WindowFrame.TAB_BAR keeps the room for it)
local BAR = 4
-- The selected card's frame stands outside its button: the strip keeps this much room around the row for it.
local EDGE = WindowFrame.TAB_EDGE
-- A ruler of this many virtual pixels measures the strip's scale (the layer's and an opening window's together).
local RULER = 100

-- The width of ◂ / ▸ on this device.
local function chevronWidth(touch: boolean): number
	return if touch then WindowFrame.TAB_CHEVRON_TOUCH else WindowFrame.TAB_CHEVRON
end

local function Tabs(scope: Scope, props: Props): Instance
	local roles = Theme.surface(props.Surface)
	local frameColor = if props.Surface == "iron" then Theme.Brass.Line else Theme.Brass.Frame
	local heights = WindowFrame.tabStrip(props.Scroll)
	local barSpace = heights.bar

	-- Measured on screen (screen pixels): the strip, a ruler, the row's first and last tab.
	local stripPos = scope:Value(Vector2.zero)
	local stripSize = scope:Value(Vector2.zero)
	local ruler = scope:Value(Vector2.zero)
	local firstPos = scope:Value(Vector2.zero)
	local lastPos = scope:Value(Vector2.zero)
	local lastSize = scope:Value(Vector2.zero)

	-- The look of the row for the strip's width (virtual pixels of the strip).
	local fit = scope:Computed(function(use): WindowFrame.TabFit
		local labels = {}
		for _, tab in props.Tabs do
			table.insert(labels, use(tab.label))
		end
		local unit = use(ruler).X / RULER
		local room = if unit > 0 then use(stripSize).X / unit - 2 * EDGE else math.huge
		return WindowFrame.tabFit(labels, room)
	end)
	local padding = scope:Computed(function(use): UDim
		return UDim.new(0, use(fit).pad)
	end)
	local textSize = scope:Computed(function(use): number
		return use(fit).size
	end)

	local buttons: { GuiObject } = {}
	for index, tab in props.Tabs do
		local isSelected = scope:Computed(function(use): boolean
			return use(props.Selected) == tab.id
		end)
		local properties: { [any]: any } = {
			Name = tab.id,
			LayoutOrder = index,
			AutoButtonColor = false,
			Size = UDim2.new(0, 0, 1, -barSpace),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = scope:Computed(function(use): Color3
				return if use(isSelected) then roles.Surface else roles.Sunken
			end),
			Text = tab.label,
			FontFace = Theme.Fonts.BodyBold,
			TextSize = textSize,
			TextColor3 = scope:Computed(function(use): Color3
				return if use(isSelected) then roles.Heading else roles.TextMuted
			end),
			TextWrapped = false,
			[OnEvent("Activated")] = function()
				Sounds.play("click")
				props.Selected:set(tab.id)
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({
					PaddingLeft = padding,
					PaddingRight = padding,
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
		}
		-- the row's ends tell whether tabs stand past an edge of the strip
		if index == 1 then
			properties[Out("AbsolutePosition")] = firstPos
		end
		if index == #props.Tabs then
			properties[Out("AbsolutePosition")] = lastPos
			properties[Out("AbsoluteSize")] = lastSize
		end
		table.insert(buttons, scope:New("TextButton")(properties) :: GuiObject)
	end

	local strip: ScrollingFrame
	strip = scope:New("ScrollingFrame")({
		Name = "Strip",
		-- the band above the strip for the selected card's frame (WindowFrame.tabStrip): the row keeps the strip's height
		Position = UDim2.fromOffset(0, -EDGE),
		Size = UDim2.new(1, 0, 1, EDGE),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = if props.Scroll then BAR else 0,
		ScrollBarImageColor3 = roles.TextMuted,
		VerticalScrollBarInset = Enum.ScrollBarInset.None,
		-- the bar draws in the room kept under the row, never taking it from the tabs
		HorizontalScrollBarInset = Enum.ScrollBarInset.None,
		[Out("AbsolutePosition")] = stripPos,
		[Out("AbsoluteSize")] = stripSize,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, WindowFrame.TAB_GAP),
			}),
			-- room for the selected card's frame, which a scrolling strip would cut off (the band above the strip)
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, EDGE),
				PaddingLeft = UDim.new(0, EDGE),
				PaddingRight = UDim.new(0, EDGE),
			}),
			buttons :: any,
		},
	}) :: ScrollingFrame

	-- Screen pixels per virtual pixel of the strip.
	local function unit(): number
		local measuredRuler = Fusion.peek(ruler).X
		return if measuredRuler > 0 then measuredRuler / RULER else 1
	end

	-- Scrolls by `pages` widths of the strip (negative: back), within the row.
	local function scrollBy(pages: number)
		local width = strip.AbsoluteWindowSize.X / unit()
		local most = math.max(0, (strip.AbsoluteCanvasSize.X - strip.AbsoluteWindowSize.X) / unit())
		local x = math.clamp(strip.CanvasPosition.X + pages * width * 0.7, 0, most)
		strip.CanvasPosition = Vector2.new(x, 0)
	end

	-- The selected tab in view (it may stand past an edge after a choice from the code or a narrower window).
	local function reveal()
		local index = 0
		for i, tab in props.Tabs do
			if tab.id == Fusion.peek(props.Selected) then
				index = i
			end
		end
		local button = buttons[index]
		if not button or strip.AbsoluteWindowSize.X <= 0 then
			return
		end
		local u = unit()
		local left = (button.AbsolutePosition.X - strip.AbsolutePosition.X) / u
		local right = left + button.AbsoluteSize.X / u
		local width = strip.AbsoluteWindowSize.X / u
		-- clear of this device's ◂ / ▸ (a touch one is wider)
		local now = strip.CanvasPosition.X
		local x = WindowFrame.tabReveal(left, right, width, now, chevronWidth(Fusion.peek(Device.Touch)))
		if x ~= now then
			strip.CanvasPosition = Vector2.new(x, 0)
		end
	end
	scope:Observer(props.Selected):onChange(function()
		task.defer(reveal)
	end)
	task.delay(0.1, function()
		if strip.Parent then
			reveal()
		end
	end)

	-- ◂ / ▸ while tabs stand past that edge of the strip.
	local function chevron(right: boolean): Instance
		local shown = scope:Computed(function(use): boolean
			local from = use(stripPos).X
			local to = from + use(stripSize).X
			if right then
				return use(lastPos).X + use(lastSize).X > to + 1
			end
			return use(firstPos).X < from - 1
		end)
		return scope:New("TextButton")({
			Name = if right then "More" else "Back",
			AnchorPoint = Vector2.new(if right then 1 else 0, 0),
			Position = UDim2.fromScale(if right then 1 else 0, 0),
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(0, chevronWidth(use(Device.Touch)), 1, -barSpace)
			end),
			Visible = shown,
			AutoButtonColor = false,
			BackgroundColor3 = roles.Surface,
			BackgroundTransparency = 0.1,
			Text = if right then "▸" else "◂",
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = roles.Heading,
			ZIndex = 4,
			[OnEvent("Activated")] = function()
				Sounds.play("click")
				scrollBy(if right then 1 else -1)
			end,
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			},
		})
	end

	return scope:New("Frame")({
		Name = "Tabs",
		Size = props.Size or UDim2.new(1, 0, 0, heights.height),
		Position = props.Position,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("Frame")({
				Name = "Ruler",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(RULER, 0),
				[Out("AbsoluteSize")] = ruler,
			}),
			strip,
			chevron(false),
			chevron(true),
		},
	})
end

return Tabs
