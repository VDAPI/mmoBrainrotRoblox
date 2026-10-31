--!strict
-- Backpack window (B; window id "character"), DESIGN §23. S29: equipment, backpack and statistics in one window,
-- so items drag straight from the backpack onto the gear. FIX 2026-10-14: no separate "Character" button / C key.
-- UI plan phase 3 (Studio review 2026-10-31: the window did three jobs at two thirds of the screen): tabs on top, one
-- job per view (Logic/CharacterTabs):
--   "backpack": name, class / level and the equipment on the left, the backpack panel (same component as the companion
--     backpack) on the right;
--   "stats": stat points on the left, the derived statistics on the right; its label counts the free points;
--   "sets": the build set switch (S58, ROZWOJ 2.9, 4) and the title (owner 2026-10-21: TitleChooser), only once one of
--     them means something (CharacterTabs.setsShown / titlesShown).
-- Desktop 826 x 752 (was 1240 x 700); touch full screen with the same tabs (56 px equipment slots).
-- `Focus` ("backpack" | "stats" | "sets") is the tab the open request asked for (WindowManager.FocusHint); the tabs set
-- it too, so B on another tab comes back to the backpack.
-- S123: a portrait tile (UI/Components/PortraitFrame, the frame cosmetic) next to the name and class / level; the title
-- picker sees the bought titles (Titles.contextOf with the owned cosmetics and the VIP branch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtIcon = require(script.Parent.Parent.Components.ArtIcon)
local BackpackPanel = require(script.Parent.BackpackPanel)
local BuildSetSwitch = require(script.Parent.Parent.Components.BuildSetSwitch)
local CharacterTabs = require(ReplicatedStorage.Shared.Logic.CharacterTabs)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DerivedList = require(script.DerivedList)
local Device = require(script.Parent.Parent.Device)
local Equipment = require(script.Equipment)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local PortraitFrame = require(script.Parent.Parent.Components.PortraitFrame)
local SectionLabel = require(script.Parent.Parent.Components.SectionLabel)
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
	Focus: Fusion.Value<string>, -- "backpack" | "stats" | "sets"
	Backpack: BackpackPanel.Actions,
	Unequip: (slot: string) -> (),
}

-- Desktop: the backpack tab is the old left and middle columns side by side.
local LEFT_WIDTH = 260
-- the backpack panel takes the rest: 500 at the desktop size (ScreenController)
local GUTTER = Theme.Padding.Large
local ALLOCATOR_WIDTH = 420 -- the old right column was 416
local SETS_WIDTH = 520
local TOUCH_LEFT_WIDTH = 200
local TOUCH_SLOT = 56
local TOUCH_GAP = 8
local TAB_HEIGHT = Theme.Size.MinTouch -- Components/Tabs
local CONTENT_TOP = TAB_HEIGHT + Theme.Padding.Small

type Chooser = { open: Fusion.Value<boolean>, state: TitleChooser.ChooserState }

-- Name, class / level and the equipment (UI plan phase 3: the set switch and the title moved to their own tab).
local function heroColumn(scope: Scope, props: Props, touch: boolean): { Instance }
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
		Equipment(scope, {
			LayoutOrder = 5,
			SlotSize = if touch then TOUCH_SLOT else nil,
			Gap = if touch then TOUCH_GAP else nil,
			Unequip = props.Unequip,
		}),
	}
end

-- What the tab strip shows and which tab is on screen.
type Shown = {
	tab: Fusion.Computed<string>,
	list: Fusion.Computed<{ string }>,
	sets: Fusion.Computed<boolean>,
	titles: Fusion.Computed<boolean>,
}

local function rule(scope: Scope, name: string, position: UDim2): Instance
	return scope:New("Frame")({
		Name = name,
		Position = position,
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundColor3 = Theme.Paper.Rule,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	})
end

local function column(scope: Scope, name: string, position: UDim2, size: UDim2, children: { Instance }): Instance
	return scope:New("ScrollingFrame")({
		Name = name,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = children,
	})
end

-- One tab's page under the strip.
local function page(scope: Scope, name: string, id: string, shown: Shown, children: { Instance }): Instance
	return scope:New("Frame")({
		Name = name,
		Position = UDim2.fromOffset(0, CONTENT_TOP),
		Size = UDim2.new(1, 0, 1, -CONTENT_TOP),
		BackgroundTransparency = 1,
		Visible = scope:Computed(function(use): boolean
			return use(shown.tab) == id
		end),
		[Children] = children,
	})
end

-- The equipment on the left, the backpack on the right.
local function backpackPage(scope: Scope, props: Props, touch: boolean, shown: Shown): Instance
	local left = if touch then TOUCH_LEFT_WIDTH else LEFT_WIDTH
	local gap = if touch then Theme.Padding.Medium else GUTTER
	local leftSize = UDim2.new(0, left, 1, 0)
	return page(scope, "BackpackTab", "backpack", shown, {
		if touch
			then column(scope, "Left", UDim2.new(), leftSize, heroColumn(scope, props, true))
			else scope:New("Frame")({
				Name = "Left",
				Size = leftSize,
				BackgroundTransparency = 1,
				[Children] = heroColumn(scope, props, false),
			}),
		rule(scope, "Rule", UDim2.fromOffset(left + gap / 2, 0)),
		scope:New("Frame")({
			Name = "Backpack",
			Position = UDim2.fromOffset(left + gap, 0),
			Size = UDim2.new(1, -(left + gap), 1, 0),
			BackgroundTransparency = 1,
			[Children] = BackpackPanel(scope, {
				Actions = props.Backpack,
				SlotSize = if touch then TOUCH_SLOT else nil,
				ButtonWidth = 100,
			}),
		}),
	})
end

-- Stat points on the left, the derived statistics on the right (touch: half the width each).
local function statsPage(
	scope: Scope,
	pending: Fusion.Value<{ [string]: number }>,
	touch: boolean,
	shown: Shown
): Instance
	local gap = if touch then Theme.Padding.Medium else GUTTER
	local leftSize = if touch then UDim2.new(0.5, -gap / 2, 1, 0) else UDim2.new(0, ALLOCATOR_WIDTH, 1, 0)
	local rightAt = if touch then UDim2.new(0.5, gap / 2, 0, 0) else UDim2.fromOffset(ALLOCATOR_WIDTH + gap, 0)
	local rightSize = if touch then UDim2.new(0.5, -gap / 2, 1, 0) else UDim2.new(1, -(ALLOCATOR_WIDTH + gap), 1, 0)
	local ruleAt = if touch then UDim2.fromScale(0.5, 0) else UDim2.fromOffset(ALLOCATOR_WIDTH + gap / 2, 0)
	return page(scope, "StatsTab", "stats", shown, {
		column(scope, "Allocator", UDim2.new(), leftSize, { StatAllocator(scope, { Pending = pending }) }),
		rule(scope, "Rule", ruleAt),
		DerivedList(scope, { Pending = pending, Position = rightAt, Size = rightSize }),
	})
end

-- A titled block of the sets tab, shown while it means something.
local function block(
	scope: Scope,
	name: string,
	order: number,
	labelKey: string,
	visible: Fusion.Computed<boolean>,
	children: { Instance }
): Instance
	return scope:New("Frame")({
		Name = name,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = visible,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			SectionLabel(scope, { Name = "Label", LayoutOrder = 0, Text = Text.T(scope, labelKey) }),
			children :: any,
		},
	})
end

-- The build sets and the title.
local function setsPage(scope: Scope, touch: boolean, shown: Shown, titles: Chooser): Instance
	local size = if touch then UDim2.fromScale(1, 1) else UDim2.new(0, SETS_WIDTH, 1, 0)
	return page(scope, "SetsTab", "sets", shown, {
		column(scope, "Column", UDim2.new(), size, {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Large),
			}),
			block(scope, "Sets", 1, "character.sets.label", shown.sets, {
				scope:New("TextLabel")({
					Name = "Hint",
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					Text = Text.T(scope, "character.sets.hint"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				BuildSetSwitch(scope, {
					Height = if touch then Theme.Size.MinTouch else 34,
					ButtonWidth = if touch then 94 else 122,
					LayoutOrder = 2,
				}),
			}),
			block(scope, "Titles", 2, "character.title.label", shown.titles, {
				TitleChooser.Picker(
					scope,
					{ LayoutOrder = 1, Open = titles.open, State = titles.state, Touch = touch }
				),
			}),
		}),
	})
end

-- The strip: rebuilt when the third tab comes or goes (its label says what it holds); the stats label counts the
-- free points.
local function strip(scope: Scope, props: Props, shown: Shown): Fusion.Child
	local points = State.Value({ "character", "statPoints" })
	local labels: { [string]: Fusion.UsedAs<string> } = {
		backpack = Text.T(scope, "character.tab.backpack"),
		stats = scope:Computed(function(use): string
			local n = use(points)
			if type(n) == "number" and n > 0 then
				return Text.get(use, "character.tab.statsPoints", { points = n })
			end
			return Text.get(use, "character.tab.stats")
		end),
		sets = scope:Computed(function(use): string
			return Text.get(use, CharacterTabs.setsLabel(use(shown.sets), use(shown.titles)))
		end),
	}
	return scope:Computed(function(use, inner: Scope): Instance
		local tabs: { Tabs.Tab } = {}
		for _, id in use(shown.list) do
			table.insert(tabs, { id = id, label = labels[id] })
		end
		return Tabs(inner, { Selected = props.Focus, Tabs = tabs })
	end)
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

	-- UI plan phase 3: which tabs show (Logic/CharacterTabs); a tab that went away hands its place to the backpack.
	local level = State.Value({ "character", "level" })
	local buildSlot = State.Value({ "character", "buildSlot" })
	local sets = scope:Computed(function(use): boolean
		local L, slot = use(level), use(buildSlot)
		return CharacterTabs.setsShown(
			if type(L) == "number" then L else nil,
			if type(slot) == "number" then slot else nil
		)
	end)
	local titlesShown = scope:Computed(function(use): boolean
		return CharacterTabs.titlesShown(#use(titles.state.choices) - 1)
	end)
	local list = scope:Computed(function(use): { string }
		return CharacterTabs.tabs(use(sets), use(titlesShown))
	end)
	local shown: Shown = {
		list = list,
		sets = sets,
		titles = titlesShown,
		tab = scope:Computed(function(use): string
			return CharacterTabs.pick(use(props.Focus), use(list))
		end),
	}
	scope:Observer(shown.tab):onBind(function()
		local tab = Fusion.peek(shown.tab)
		if Fusion.peek(props.Focus) ~= tab then
			props.Focus:set(tab)
		end
	end)

	-- The layout follows the input device (touch = full-screen window).
	return scope:Computed(function(use, s: Scope): { Instance }
		local touch = use(Device.Touch)
		return {
			strip(s, props, shown) :: any,
			backpackPage(s, props, touch, shown),
			statsPage(s, pending, touch, shown),
			setsPage(s, touch, shown, titles),
			-- last: drawn over the whole window
			TitleChooser.Panel(s, { Open = titles.open, State = titles.state, Touch = touch }),
		}
	end) :: any
end

return CharacterWindow
