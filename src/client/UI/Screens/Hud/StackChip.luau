--!strict
-- Owner 2026-11-10 ("things covering each other, nothing folds"; UI plan package A): the '+N' chip of the HUD column.
-- Logic/HudStack.place never puts an element past the column's floor: it gives the least height, then folds panels to
-- their header line, and what still has no room waits behind this chip (UI/HudSlots.Hidden, at HudSlots.Chip: the
-- floor's end of the column on PC and a tablet, the last line's right end of a phone's stack). A click or a tap opens
-- the list of what waits, one line each; picking one brings it back (HudSlots.bring: it stays in the column and the
-- others fold or wait before it) and closes the list. PC and a tablet open the list left of the chip, a phone over the
-- stack from its left edge (half the layer wide at most), so it never reaches the thumb's controls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Device = require(script.Parent.Parent.Parent.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local HudSlots = require(script.Parent.Parent.Parent.HudSlots)
local PanelHeader = require(script.Parent.PanelHeader)
local PhoneLayout = require(script.Parent.Parent.Parent.PhoneLayout)
local Scale = require(script.Parent.Parent.Parent.Scale)
local Sounds = require(script.Parent.Parent.Parent.Sounds)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Tooltip = require(script.Parent.Parent.Parent.Components.Tooltip)

local Children, OnEvent = Fusion.Children, Fusion.OnEvent

type Scope = Fusion.Scope<typeof(Fusion)>

local LIST_PC = 220 -- the list's width on PC and a tablet
local LIST_PHONE = 440 -- a phone's list at most this wide (and half the layer)
local MARGIN = 8
local PAD = 4

local function StackChip(scope: Scope): Instance
	local open = scope:Value(false)
	local hidden = HudSlots.Hidden
	local chip = HudSlots.Chip
	local compact = PhoneLayout.Compact
	local row = PanelHeader.Height(scope)
	local shown = scope:Computed(function(use): boolean
		return use(chip) ~= nil and #use(hidden) > 0
	end)
	-- nothing left to bring: the list closes with the chip
	scope:Observer(shown):onChange(function()
		if not Fusion.peek(shown) then
			open:set(false)
		end
	end)
	local listWidth = scope:Computed(function(use): number
		if use(compact) then
			local size: Vector2 = use(Scale.HudSize)
			return math.min(size.X / 2, LIST_PHONE) - MARGIN
		end
		return LIST_PC
	end)

	local button = scope:New("TextButton")({
		Name = "StackChip",
		Position = scope:Computed(function(use): UDim2
			local at = use(chip)
			return if at then UDim2.fromOffset(at.left, at.top) else UDim2.new()
		end),
		Size = scope:Computed(function(use): UDim2
			local at = use(chip)
			return if at then UDim2.fromOffset(at.right - at.left, at.bottom - at.top) else UDim2.new()
		end),
		Visible = shown,
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Iron.Raised,
		BackgroundTransparency = Theme.HudAlpha,
		Text = scope:Computed(function(use): string
			return `+{#use(hidden)}`
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Brass.Bright,
		ZIndex = 3,
		[OnEvent("Activated")] = function()
			Sounds.play("click")
			open:set(not Fusion.peek(open))
		end,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
		},
	}) :: GuiObject
	Tooltip.attach(
		scope,
		button,
		scope:Computed(function(use): string
			return Text.get(use, "hud.stack.chip", { n = #use(hidden) })
		end)
	)

	local list = scope:New("Frame")({
		Name = "StackList",
		-- PC and a tablet: left of the chip, bottom-aligned with it; a phone: from the stack's left edge, its bottom on
		-- the chip's top
		AnchorPoint = scope:Computed(function(use): Vector2
			return if use(compact) then Vector2.new(0, 1) else Vector2.new(1, 1)
		end),
		Position = scope:Computed(function(use): UDim2
			local at = use(chip)
			if not at then
				return UDim2.new()
			end
			if use(compact) then
				return UDim2.fromOffset(MARGIN, at.top - PAD)
			end
			return UDim2.fromOffset(at.left - PAD, at.bottom)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(use(listWidth), 0)
		end),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Visible = scope:Computed(function(use): boolean
			return use(open) and use(shown)
		end),
		ZIndex = 4,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = Theme.Stroke.Thin }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, PAD),
				PaddingBottom = UDim.new(0, PAD),
				PaddingLeft = UDim.new(0, PAD),
				PaddingRight = UDim.new(0, PAD),
			}),
			scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, PAD) }),
			scope:ForValues(hidden, function(_use, s: Scope, id: string): Instance
				return s:New("TextButton")({
					Name = id,
					Size = s:Computed(function(use): UDim2
						return UDim2.new(1, 0, 0, use(row))
					end),
					AutoButtonColor = true,
					BackgroundColor3 = Theme.Iron.Raised,
					Text = Text.T(s, `hud.stack.{id}`),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = if Fusion.peek(Device.Touch) then Theme.TextSize.Body else Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 5,
					[OnEvent("Activated")] = function()
						Sounds.play("click")
						HudSlots.bring(id)
						open:set(false)
					end,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
					},
				})
			end) :: any,
		},
	})

	return scope:New("Frame")({
		Name = "StackChipLayer",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Children] = { button :: Instance, list } :: any,
	})
end

return StackChip
