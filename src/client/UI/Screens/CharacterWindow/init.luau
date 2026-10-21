--!strict
-- Backpack window (B; window id "character"), DESIGN §23. S29: equipment, backpack and statistics in one window,
-- so items drag straight from the backpack onto the gear. FIX 2026-10-14: no separate "Character" button / C key.
--   desktop (1240 x 700): left 260 (name, class / level, title, equipment, Unequip), middle 500 (the
--     backpack panel, same component as the companion backpack), right (stat points, derived stats);
--   touch (full screen): equipment on the left (56 px slots), a "Backpack | Statistics" switch on the right.
-- `Focus` ("backpack" | "stats") is the touch tab the open request asked for (WindowManager.FocusHint).
-- S58 (ROZWOJ 2.9, 4): a build set switch under class / level (no "Copy" here: it lives in the skills window); the
-- stat reservation belongs to a set and clears on a switch.
-- S123: a portrait tile (UI/Components/PortraitFrame, the frame cosmetic) next to the name and class / level; the title
-- picker sees the bought titles (Titles.contextOf with the owned cosmetics and the VIP branch).
-- Owner 2026-10-21: the title is picked from a list (TitleChooser: a visible "Change title" button opens every owned
-- title over the whole window) instead of the S16 "◀ ▶" cycler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local BackpackPanel = require(script.Parent.BackpackPanel)
local BuildSetSwitch = require(script.Parent.Parent.Components.BuildSetSwitch)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DerivedList = require(script.DerivedList)
local Device = require(script.Parent.Parent.Device)
local Equipment = require(script.Equipment)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local StatAllocator = require(script.StatAllocator)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TitleChooser = require(script.TitleChooser)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Focus: Fusion.Value<string>, -- "backpack" | "stats"
	Backpack: BackpackPanel.Actions,
	Unequip: (slot: string) -> (),
}

local LEFT_WIDTH = 260
local MIDDLE_WIDTH = 500
local TOUCH_LEFT_WIDTH = 200
local TOUCH_SLOT = 56
local TOUCH_GAP = 8
-- 4 stat rows (44 + 4) + points line + buttons + plan line + spacing.
local ALLOCATOR_HEIGHT = 338 -- FIX 2026-10-09: rows grew by a description line; S58: the plan line
local TAB_HEIGHT = Theme.Size.ButtonHeightSmall

type Chooser = { open: Fusion.Value<boolean>, state: TitleChooser.ChooserState }

-- Name, class / level, title picker and the equipment.
local function heroColumn(scope: Scope, props: Props, touch: boolean, titles: Chooser): { Instance }
	local name = State.Value({ "character", "name" })
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	local tile = if touch then 48 else 64
	local classColor = scope:Computed(function(use): Color3
		local class = Classes.get(use(classId) or "")
		-- S135: the glyph stands on the dark portrait tile (PortraitFrame), so readable on iron
		return if class then Theme.readable(class.color, "iron") else Theme.Iron.Heading
	end)
	return {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.Padding.Small),
		}),
		-- S123: the portrait tile (frame cosmetic) left of the name and class / level
		scope:New("Frame")({
			Name = "Header",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, tile),
			BackgroundTransparency = 1,
			[Children] = {
				PortraitFrame(scope, {
					Name = "Portrait",
					Position = UDim2.fromOffset(4, 0),
					Size = tile,
					FrameId = State.Value({ "account", "cosmetics", "equipped", "frame" }),
					ClassColor = classColor,
					Content = ArtIcon(scope, {
						Key = scope:Computed(function(use): string?
							local class = Classes.get(use(classId) or "")
							return if class then UiArt.classEmblem(class.id) else nil
						end),
						Glyph = scope:Computed(function(use): string
							local class = Classes.get(use(classId) or "")
							return if class then class.icon else ""
						end),
						GlyphColor = classColor,
						ImageScale = 0.8,
						Size = UDim2.fromScale(1, 1),
						Label = { FontFace = Theme.Fonts.BodyBold, TextSize = math.floor(tile * 0.5) },
					}),
				}),
				scope:New("TextLabel")({
					Name = "CharName",
					Position = UDim2.fromOffset(tile + 14, 0),
					Size = UDim2.new(1, -(tile + 14), 0.55, 0),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return use(name) or ""
					end),
					FontFace = Theme.Fonts.Display,
					TextSize = if touch then Theme.TextSize.Large else Theme.TextSize.Title,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
				scope:New("TextLabel")({
					Name = "ClassLevel",
					Position = UDim2.new(0, tile + 14, 0.55, 0),
					Size = UDim2.new(1, -(tile + 14), 0.45, 0),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						local class = Classes.get(use(classId) or "")
						local className = if class then Text.get(use, class.nameKey) else ""
						return Text.get(use, "charSelect.classLevel", { class = className, level = use(level) or 1 })
					end),
					FontFace = Theme.Fonts.Body,
					TextSize = if touch then Theme.TextSize.Small else Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}),
			},
		}),
		BuildSetSwitch(scope, {
			Height = if touch then Theme.Size.MinTouch else 34,
			ButtonWidth = if touch then 94 else 122,
			LayoutOrder = 3,
		}),
		TitleChooser.Picker(scope, { LayoutOrder = 4, Open = titles.open, State = titles.state, Touch = touch }),
		Equipment(scope, {
			LayoutOrder = 5,
			SlotSize = if touch then TOUCH_SLOT else nil,
			Gap = if touch then TOUCH_GAP else nil,
			Unequip = props.Unequip,
		}),
	}
end

-- Stat points on top, the derived statistics below (scrolling).
local function statsColumn(scope: Scope, pending: Fusion.Value<{ [string]: number }>): { Instance }
	return {
		scope:New("Frame")({
			Name = "Allocator",
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			[Children] = StatAllocator(scope, { Pending = pending }),
		}),
		DerivedList(scope, {
			Pending = pending,
			Position = UDim2.fromOffset(0, ALLOCATOR_HEIGHT),
			Size = UDim2.new(1, 0, 1, -ALLOCATOR_HEIGHT),
		}),
	}
end

local function rule(scope: Scope, name: string, x: number): Instance
	return scope:New("Frame")({
		Name = name,
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Paper.Rule,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	})
end

local function desktopLayout(
	scope: Scope,
	props: Props,
	pending: Fusion.Value<{ [string]: number }>,
	titles: Chooser
): { Instance }
	local pad = Theme.Padding.Large
	local rightX = LEFT_WIDTH + MIDDLE_WIDTH + pad * 2
	return {
		scope:New("Frame")({
			Name = "Left",
			Size = UDim2.new(0, LEFT_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			[Children] = heroColumn(scope, props, false, titles),
		}),
		rule(scope, "RuleLeft", LEFT_WIDTH + pad / 2),
		scope:New("Frame")({
			Name = "Backpack",
			Position = UDim2.fromOffset(LEFT_WIDTH + pad, 0),
			Size = UDim2.new(0, MIDDLE_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			[Children] = BackpackPanel(scope, { Actions = props.Backpack, ButtonWidth = 100 }),
		}),
		rule(scope, "RuleRight", rightX - pad / 2),
		scope:New("Frame")({
			Name = "Right",
			Position = UDim2.fromOffset(rightX, 0),
			Size = UDim2.new(1, -rightX, 1, 0),
			BackgroundTransparency = 1,
			[Children] = statsColumn(scope, pending),
		}),
	}
end

local function touchLayout(
	scope: Scope,
	props: Props,
	pending: Fusion.Value<{ [string]: number }>,
	titles: Chooser
): { Instance }
	local pad = Theme.Padding.Medium
	local focus = props.Focus
	local contentTop = TAB_HEIGHT + Theme.Padding.Small
	return {
		scope:New("ScrollingFrame")({
			Name = "Left",
			Size = UDim2.new(0, TOUCH_LEFT_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.Paper.Label,
			[Children] = heroColumn(scope, props, true, titles),
		}),
		scope:New("Frame")({
			Name = "Right",
			Position = UDim2.fromOffset(TOUCH_LEFT_WIDTH + pad, 0),
			Size = UDim2.new(1, -(TOUCH_LEFT_WIDTH + pad), 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				Tabs(scope, {
					Selected = focus,
					Tabs = {
						{ id = "backpack", label = Text.T(scope, "character.tab.backpack") },
						{ id = "stats", label = Text.T(scope, "character.tab.stats") },
					},
				}),
				scope:New("Frame")({
					Name = "BackpackTab",
					Position = UDim2.fromOffset(0, contentTop),
					Size = UDim2.new(1, 0, 1, -contentTop),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(focus) ~= "stats"
					end),
					[Children] = BackpackPanel(scope, {
						Actions = props.Backpack,
						SlotSize = TOUCH_SLOT,
						ButtonWidth = 100,
					}),
				}),
				scope:New("Frame")({
					Name = "StatsTab",
					Position = UDim2.fromOffset(0, contentTop),
					Size = UDim2.new(1, 0, 1, -contentTop),
					BackgroundTransparency = 1,
					Visible = scope:Computed(function(use): boolean
						return use(focus) == "stats"
					end),
					[Children] = statsColumn(scope, pending),
				}),
			},
		}),
	}
end

local function CharacterWindow(scope: Scope, props: Props): Fusion.Child
	local pending = scope:Value({} :: { [string]: number })

	-- Fewer free points than reserved (reset, spent elsewhere) starts the allocation over. FIX 2026-10-09: a
	-- level-up (more points) keeps what was reserved; a confirm clears it in StatAllocator.
	scope:Observer(State.Value({ "character", "statPoints" })):onChange(function()
		local points = State.Get({ "character", "statPoints" })
		local reserved = 0
		for _, v in Fusion.peek(pending) do
			reserved += v
		end
		if type(points) ~= "number" or points < reserved then
			pending:set({})
		end
	end)

	-- S58: reserved points belong to the build set; a switch starts the allocation over.
	scope:Observer(State.Value({ "character", "buildSlot" })):onChange(function()
		pending:set({})
	end)

	-- The layout follows the input device (touch = full-screen window).
	-- Owner 2026-10-21: the title list (closed on every layout switch), drawn over the whole window
	local titles: Chooser = { open = scope:Value(false), state = TitleChooser.state(scope) }
	scope:Observer(Device.Touch):onChange(function()
		titles.open:set(false)
	end)
	return scope:Computed(function(use, s: Scope): { Instance }
		local touch = use(Device.Touch)
		local out = if touch then touchLayout(s, props, pending, titles) else desktopLayout(s, props, pending, titles)
		table.insert(out, TitleChooser.Panel(s, { Open = titles.open, State = titles.state, Touch = touch }))
		return out
	end) :: any
end

return CharacterWindow
