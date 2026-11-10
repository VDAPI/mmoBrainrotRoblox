--!strict
-- Backpack window (B; window id "character"), DESIGN §23. S29: equipment, backpack and statistics in one window,
-- so items drag straight from the backpack onto the gear. FIX 2026-10-14: no separate "Character" button / C key.
-- Owner 2026-11-10 (the tabs of UI plan phase 3 hid the statistics, and "nothing can be collapsed"): one window as before
-- 2026-10-31, no tabs; what is secondary folds under one header (UI/Components/Section, Logic/CharacterSections):
--   wide (PC 1240 x 720, or a wide touch screen): left 260 (name, class / level, the equipment, the sets and title
--     section), middle 500 (the backpack panel, same component as the companion backpack), right (the statistics
--     section: stat points and the derived statistics); the side columns scroll on their own;
--   narrow touch (a phone in landscape, full screen): the left column (220 to 400, scrolling) holds the name, the
--     equipment and both sections, the backpack takes the rest.
-- The columns are Logic/GearLayout.character's (pure, tested): owner 2026-11-10 via the UI plan, from the window's
-- content as measured (its AbsoluteSize in virtual px), not the screen, whose safe-area insets left a 428-px backpack
-- on an 844x390 phone; a narrow statistics column puts a stat's controls under its name (StatAllocator `Compact`).
-- "charStats" stands open by default (folded: the free points as a badge); "charSets" shows once a set or a title means
-- something (CharacterSections.setsShown / titlesShown), folded by default to one line: the active set and the worn
-- title; what the sets are is behind its "i".
-- S58 (ROZWOJ 2.9, 4): the build set switch (no "Copy" here: it lives in the skills window); the stat reservation
-- belongs to a set and clears on a switch.
-- S123: a portrait tile (UI/Components/PortraitFrame, the frame cosmetic) next to the name and class / level; the title
-- picker sees the bought titles (Titles.contextOf with the owned cosmetics and the VIP branch).
-- Owner 2026-10-21: the title is picked from a list (TitleChooser: a visible "Change title" button opens every owned
-- title over the whole window).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local BackpackPanel = require(script.Parent.BackpackPanel)
local BuildSetSwitch = require(script.Parent.Parent.Components.BuildSetSwitch)
local CharacterSections = require(ReplicatedStorage.Shared.Logic.CharacterSections)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DerivedList = require(script.DerivedList)
local Device = require(script.Parent.Parent.Device)
local Equipment = require(script.Equipment)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local Scale = require(script.Parent.Parent.Scale)
local Section = require(script.Parent.Parent.Components.Section)
local StatAllocator = require(script.StatAllocator)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TitleChooser = require(script.TitleChooser)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)

local Children, Out = Fusion.Children, Fusion.Out

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Backpack: BackpackPanel.Actions,
	Unequip: (slot: string) -> (),
}

local LAYOUT = CharacterSections.LAYOUT
local LEFT_WIDTH = LAYOUT.left
local MIDDLE_WIDTH = LAYOUT.middle
local GUTTER = LAYOUT.gutter
local NARROW_GUTTER = LAYOUT.narrowGutter
local TOUCH_SLOT = GearLayout.BACKPACK.touchSlot
local TOUCH_GAP = 8

type Chooser = { open: Fusion.Value<boolean>, state: TitleChooser.ChooserState }

-- What the sets and title section holds.
type Shown = { sets: Fusion.Computed<boolean>, titles: Fusion.Computed<boolean> }

-- The portrait tile (frame cosmetic) left of the name and class / level.
local function heroHeader(scope: Scope, touch: boolean, order: number): Instance
	local name = State.Value({ "character", "name" })
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	local tile = if touch then 48 else 64
	local classColor = scope:Computed(function(use): Color3
		local class = Classes.get(use(classId) or "")
		-- S135: the glyph stands on the dark portrait tile (PortraitFrame), so readable on iron
		return if class then Theme.readable(class.color, "iron") else Theme.Iron.Heading
	end)
	return scope:New("Frame")({
		Name = "Header",
		LayoutOrder = order,
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
	})
end

local function equipment(scope: Scope, props: Props, touch: boolean, order: number): Instance
	return Equipment(scope, {
		LayoutOrder = order,
		SlotSize = if touch then TOUCH_SLOT else nil,
		Gap = if touch then TOUCH_GAP else nil,
		Unequip = props.Unequip,
	})
end

-- A part of a section shown while `visible` (its height from the content).
local function part(
	scope: Scope,
	name: string,
	order: number,
	visible: Fusion.Computed<boolean>,
	child: Instance
): Instance
	return scope:New("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = visible,
		[Children] = child,
	})
end

-- Stat points on top, the derived statistics below; folded, the free points as a badge. `compact`: a narrow column.
local function statsSection(
	scope: Scope,
	pending: Fusion.Value<{ [string]: number }>,
	compact: boolean,
	order: number
): Instance
	local points = State.Value({ "character", "statPoints" })
	local badge = scope:Computed(function(use): number?
		local n = use(points)
		return CharacterSections.pointsBadge(if type(n) == "number" then n else nil)
	end)
	return Section.new(scope, {
		Id = "charStats",
		Name = "Stats",
		LayoutOrder = order,
		Title = Text.T(scope, "character.section.stats"),
		Summary = scope:Computed(function(use): string?
			local n = use(badge)
			return if n then Text.get(use, "character.pointsLeft", { points = n }) else nil
		end),
		Accent = scope:Computed(function(use): boolean
			return use(badge) ~= nil
		end),
		Children = {
			scope:New("Frame")({
				Name = "Allocator",
				LayoutOrder = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = StatAllocator(scope, { Pending = pending, Compact = compact }),
			}),
		},
	})
end

-- Owner 2026-11-10 (UI plan): the derived statistics as four sections after the statistics' one (one fold level):
-- "Ofensywa" open; "Defensywa", "Zasoby" and "Inne" folded (DerivedList, Data/Folds/Gear).
local function derivedSections(scope: Scope, pending: Fusion.Value<{ [string]: number }>, order: number): { Instance }
	return DerivedList(scope, { Pending = pending, LayoutOrder = order })
end

-- The build sets (S58) and the title; folded, one line: the active set and the worn title.
local function setsSection(scope: Scope, touch: boolean, shown: Shown, titles: Chooser, order: number): Instance
	local buildSlot = State.Value({ "character", "buildSlot" })
	return Section.new(scope, {
		Id = "charSets",
		Name = "Sets",
		LayoutOrder = order,
		Visible = scope:Computed(function(use): boolean
			return use(shown.sets) or use(shown.titles)
		end),
		Title = scope:Computed(function(use): string
			local key = CharacterSections.setsLabel(use(shown.sets), use(shown.titles))
			return Text.get(use, key or "character.section.sets")
		end),
		-- what the sets are and where titles come from, behind the "i"
		Info = scope:Computed(function(use): string
			local lines: { string } = {}
			if use(shown.sets) then
				table.insert(lines, Text.get(use, "character.sets.hint"))
			end
			if use(shown.titles) then
				table.insert(lines, Text.get(use, "title.none.hint"))
			end
			return table.concat(lines, "\n")
		end),
		Summary = scope:Computed(function(use): string?
			local slot = use(buildSlot)
			local parts = CharacterSections.setsSummary(
				use(shown.sets),
				use(shown.titles),
				if type(slot) == "number" then slot else nil,
				use(titles.state.current)
			)
			local out: { string } = {}
			for _, p in parts do
				local key = p.key
				if p.title then
					table.insert(out, TitleChooser.currentName(use, titles.state) or "")
				elseif key then
					table.insert(out, Text.get(use, key, p.args))
				end
			end
			return if #out > 0 then table.concat(out, " · ") else nil
		end),
		Children = {
			part(
				scope,
				"SetSwitch",
				1,
				shown.sets,
				BuildSetSwitch(scope, {
					Height = if touch then Theme.Size.MinTouch else 34,
					ButtonWidth = if touch then 94 else 118, -- two and the gap within the left column
				})
			),
			part(
				scope,
				"TitlePicker",
				2,
				shown.titles,
				TitleChooser.Picker(scope, { LayoutOrder = 1, Open = titles.open, State = titles.state, Touch = touch })
			),
		},
	})
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

-- A scrolling column, its rows in the middle (the equipment), `width` nil: to the right edge.
local function column(scope: Scope, name: string, x: number, width: number?, children: { Instance }): Instance
	return scope:New("ScrollingFrame")({
		Name = name,
		Position = UDim2.fromOffset(x, 0),
		Size = if width then UDim2.new(0, width, 1, 0) else UDim2.new(1, -x, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			-- room for the scroll bar
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, LAYOUT.scrollPad) }),
			children :: any,
		},
	})
end

local function backpack(scope: Scope, props: Props, touch: boolean, x: number, width: number?): Instance
	return scope:New("Frame")({
		Name = "Backpack",
		Position = UDim2.fromOffset(x, 0),
		Size = if width then UDim2.new(0, width, 1, 0) else UDim2.new(1, -x, 1, 0),
		BackgroundTransparency = 1,
		[Children] = BackpackPanel(scope, {
			Actions = props.Backpack,
			SlotSize = if touch then TOUCH_SLOT else nil,
			ButtonWidth = 100,
		}),
	})
end

local function wideLayout(
	scope: Scope,
	props: Props,
	pending: Fusion.Value<{ [string]: number }>,
	touch: boolean,
	compact: boolean,
	shown: Shown,
	titles: Chooser
): { Instance }
	local middleX = LEFT_WIDTH + GUTTER
	local rightX = middleX + MIDDLE_WIDTH + GUTTER
	return {
		column(scope, "Left", 0, LEFT_WIDTH, {
			heroHeader(scope, touch, 1),
			equipment(scope, props, touch, 2),
			setsSection(scope, touch, shown, titles, 3),
		}),
		rule(scope, "RuleLeft", LEFT_WIDTH + GUTTER / 2),
		backpack(scope, props, touch, middleX, MIDDLE_WIDTH),
		rule(scope, "RuleRight", rightX - GUTTER / 2),
		column(scope, "Right", rightX, nil, {
			statsSection(scope, pending, compact, 1),
			derivedSections(scope, pending, 1) :: any,
		}),
	}
end

local function narrowLayout(
	scope: Scope,
	props: Props,
	pending: Fusion.Value<{ [string]: number }>,
	layout: GearLayout.Character,
	shown: Shown,
	titles: Chooser
): { Instance }
	local left = layout.left.right
	return {
		column(scope, "Left", 0, left, {
			heroHeader(scope, true, 1),
			equipment(scope, props, true, 2),
			statsSection(scope, pending, layout.compact, 3),
			derivedSections(scope, pending, 3) :: any,
			setsSection(scope, true, shown, titles, 8),
		}),
		rule(scope, "Rule", left + NARROW_GUTTER / 2),
		-- owner 2026-11-10: the backpack as wide as GearLayout gives it (500 on every phone), not "the rest"
		backpack(scope, props, true, layout.backpack.left, layout.backpack.right - layout.backpack.left),
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

	-- Owner 2026-10-21: the title list (closed on every layout switch), drawn over the whole window
	local titles: Chooser = { open = scope:Value(false), state = TitleChooser.state(scope) }
	scope:Observer(Device.Touch):onChange(function()
		titles.open:set(false)
	end)

	-- What the sets and title section holds (Logic/CharacterSections).
	local level = State.Value({ "character", "level" })
	local buildSlot = State.Value({ "character", "buildSlot" })
	local shown: Shown = {
		sets = scope:Computed(function(use): boolean
			local L, slot = use(level), use(buildSlot)
			return CharacterSections.setsShown(
				if type(L) == "number" then L else nil,
				if type(slot) == "number" then slot else nil
			)
		end),
		titles = scope:Computed(function(use): boolean
			return CharacterSections.titlesShown(#use(titles.state.choices) - 1)
		end),
	}

	-- The columns (Logic/GearLayout.character): PC always three; touch by the content's width as measured (owner
	-- 2026-11-10 via the UI plan: the content rect, not the screen). Until the first measure the PC layout stands.
	-- Rebuilt only when the kind, the left width, the backpack's width or `compact` changes, not on every resize.
	local absolute = scope:Value(Vector2.zero)
	local columns = scope:Computed(function(use): GearLayout.Character
		local touch = use(Device.Touch) == true
		local size: Vector2 = use(absolute)
		local k: number = use(Scale.Value)
		if size.X <= 0 or k <= 0 then
			return GearLayout.character({ w = 1196, h = 624 }, false)
		end
		return GearLayout.character({ w = size.X / k, h = size.Y / k }, touch)
	end)
	local key = scope:Computed(function(use): string
		local c = use(columns)
		return `{c.wide}|{c.compact}|{c.left.right}|{c.backpack.left}|{c.backpack.right}`
	end)

	local layout = scope:Computed(function(use, s: Scope): { Instance }
		use(key)
		local touch = use(Device.Touch)
		local c = Fusion.peek(columns)
		local out = if c.wide
			then wideLayout(s, props, pending, touch, c.compact, shown, titles)
			else narrowLayout(s, props, pending, c, shown, titles)
		-- last: drawn over the whole window
		table.insert(out, TitleChooser.Panel(s, { Open = titles.open, State = titles.state, Touch = touch }))
		return out
	end)
	return scope:New("Frame")({
		Name = "Character",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		[Out("AbsoluteSize")] = absolute,
		[Children] = layout :: any,
	})
end

return CharacterWindow
