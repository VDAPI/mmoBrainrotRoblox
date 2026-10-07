--!strict
-- Character window (C and B), DESIGN §23. S29: equipment, backpack and statistics in one window, so items
-- drag straight from the backpack onto the gear.
--   desktop (1240 x 700): left 260 (name, class / level, title, equipment, Unequip), middle 500 (the
--     backpack panel, same component as the companion backpack), right (stat points, derived stats);
--   touch (full screen): equipment on the left (56 px slots), a "Backpack | Statistics" switch on the right.
-- `Focus` ("backpack" | "stats") is the tab B / C asked for (WindowManager.FocusHint).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackpackPanel = require(script.Parent.BackpackPanel)
local Button = require(script.Parent.Parent.Components.Button)
local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local DerivedList = require(script.DerivedList)
local Device = require(script.Parent.Parent.Device)
local Equipment = require(script.Equipment)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local StatAllocator = require(script.StatAllocator)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local TitleData = require(ReplicatedStorage.Shared.Data.Titles)
local Titles = require(ReplicatedStorage.Shared.Logic.Titles)
local Toast = require(script.Parent.Parent.Components.Toast)

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
-- 4 stat rows (44 + 4) + points line + buttons + spacing.
local ALLOCATOR_HEIGHT = 290
local TAB_HEIGHT = Theme.Size.ButtonHeightSmall

-- "◀ title ▶" picker (S16): cycles through none + the unlocked titles, saved with SetTitle.
local function TitlePicker(scope: Scope, order: number): Instance
	local character = State.Value({ "character" })
	local unlocked = scope:Computed(function(use): { string }
		local c = use(character)
		return if c then Titles.unlocked(c) else {}
	end)
	local current = scope:Computed(function(use): string?
		local c = use(character)
		return if c then Titles.shown(c) else nil
	end)
	local function step(delta: number)
		local list = Fusion.peek(unlocked)
		if #list == 0 then
			Toast.push(Text.now("title.none.hint"), "info", 3)
			return
		end
		local index = 0 -- 0 = no title
		for i, id in list do
			if id == Fusion.peek(current) then
				index = i
			end
		end
		index = (index + delta) % (#list + 1)
		task.spawn(function()
			local ok, err = Net.Invoke("SetTitle", if index == 0 then nil else list[index])
			if not ok then
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end
	return scope:New("Frame")({
		Name = "Title",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		[Children] = {
			Button(scope, {
				Size = UDim2.fromOffset(34, 34),
				Text = "◀",
				Variant = "ghost",
				OnClick = function()
					step(-1)
				end,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(38, 0),
				Size = UDim2.new(1, -76, 1, 0),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local id = use(current)
					local def = if id then TitleData.get(id) else nil
					if def then
						return `« {Text.get(use, def.nameKey)} »`
					end
					return Text.get(use, "title.none", { count = #use(unlocked) })
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = scope:Computed(function(use): Color3
					local id = use(current)
					local def = if id then TitleData.get(id) else nil
					return if def then Color3.fromHex(def.color) else Theme.Colors.TextMuted
				end),
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromOffset(34, 34),
				Text = "▶",
				Variant = "ghost",
				OnClick = function()
					step(1)
				end,
			}),
		},
	})
end

-- Name, class / level, title picker and the equipment.
local function heroColumn(scope: Scope, props: Props, touch: boolean): { Instance }
	local name = State.Value({ "character", "name" })
	local classId = State.Value({ "character", "class" })
	local level = State.Value({ "character", "level" })
	return {
		scope:New("UIListLayout")({
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, Theme.Padding.Small),
		}),
		scope:New("TextLabel")({
			Name = "CharName",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, if touch then 28 else 34),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return use(name) or ""
			end),
			FontFace = Theme.Fonts.Heading,
			TextSize = if touch then Theme.TextSize.Large else Theme.TextSize.Title,
			TextColor3 = Theme.Colors.Gold,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		scope:New("TextLabel")({
			Name = "ClassLevel",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local class = Classes.get(use(classId) or "")
				local className = if class then Text.get(use, class.nameKey) else ""
				return Text.get(use, "charSelect.classLevel", { class = className, level = use(level) or 1 })
			end),
			FontFace = Theme.Fonts.Body,
			TextSize = if touch then Theme.TextSize.Small else Theme.TextSize.Body,
			TextColor3 = Theme.Colors.Parchment,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		TitlePicker(scope, 3),
		Equipment(scope, {
			LayoutOrder = 4,
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
		BackgroundColor3 = Theme.Colors.GoldDim,
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
	})
end

local function desktopLayout(scope: Scope, props: Props, pending: Fusion.Value<{ [string]: number }>): { Instance }
	local pad = Theme.Padding.Large
	local rightX = LEFT_WIDTH + MIDDLE_WIDTH + pad * 2
	return {
		scope:New("Frame")({
			Name = "Left",
			Size = UDim2.new(0, LEFT_WIDTH, 1, 0),
			BackgroundTransparency = 1,
			[Children] = heroColumn(scope, props, false),
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

local function touchLayout(scope: Scope, props: Props, pending: Fusion.Value<{ [string]: number }>): { Instance }
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
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = heroColumn(scope, props, true),
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

	-- Any change of free points (confirm, level-up, reset) starts the allocation over.
	scope:Observer(State.Value({ "character", "statPoints" })):onChange(function()
		pending:set({})
	end)

	-- The layout follows the input device (touch = full-screen window).
	return scope:Computed(function(use, s: Scope): { Instance }
		if use(Device.Touch) then
			return touchLayout(s, props, pending)
		end
		return desktopLayout(s, props, pending)
	end) :: any
end

return CharacterWindow
