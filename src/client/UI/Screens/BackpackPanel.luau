--!strict
-- Backpack panel (DESIGN §23): slot grid sized by the backpack, gold, used/total slots, sort button,
-- category filter and an action bar for the selected slot (works for mouse and touch). S29: one component
-- embedded in the character window (middle column / "Backpack" tab) and in the companion backpack window
-- next to services ("inventory").
-- S121: the capacity is Logic/Inventory.capacityOf (backpack + Merchant's Pockets from the `passes` branch); items
-- above it (overflow) get extra slots with a red frame and can only be taken out.
-- Owner 2026-11-10 (UI plan: "niektóre rzeczy zasłaniają inne"): the rows come from Logic/GearLayout.backpack: the
-- header, the overflow / pockets line under it in Small 17 (it was scaled text over the gold), the filters, the slot
-- grid and the action bar in the footer.
-- Review 2026-11-10: on touch the slots are 56 px wherever the panel stands (the companion window next to a service
-- kept 64 and showed one full row on a phone), and the sort and action buttons are 44 high (UI-ZASADY: touch targets
-- of 44, ButtonHeightSmall only on PC); GearLayout.backpack gives the header and the action bar their touch heights.
-- Adoption stage (UI package D after C, 2026-11-10): the panel registers its action bar with ItemTooltip.avoid, so a
-- touch tooltip of the selected item no longer covers "Załóż" / "Użyj" in either home. The bar stays the panel's own
-- (not Components/Window's Footer): the character window shows the same panel in a column, and on an 844x390 phone
-- under the 58-px top bar a window footer would take the second slot row.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Device = require(script.Parent.Parent.Device)
local DragDrop = require(script.Parent.Parent.DragDrop)
local CurrencyIcon = require(script.Parent.Parent.Components.CurrencyIcon)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Inventory = require(ReplicatedStorage.Shared.Logic.Inventory)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemTooltip = require(script.Parent.Parent.Components.ItemTooltip)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Actions = {
	Equip: (index: number) -> (),
	Use: (index: number) -> (),
	Split: (index: number) -> (),
	Destroy: (index: number) -> (),
	Lock: (index: number) -> (), -- S20: toggle the padlock
	LootLog: () -> (), -- S20: open the loot log
}

export type Props = {
	Actions: Actions,
	SlotSize: number?, -- default 64, 56 on touch (GearLayout.BACKPACK)
	ButtonWidth: number?, -- action bar button width, default 120
}

local SLOT = GearLayout.BACKPACK.slot
local TOUCH_SLOT = GearLayout.BACKPACK.touchSlot
local GAP = GearLayout.BACKPACK.gap
-- The panel's rows are anchored to its top and bottom, so GearLayout's rects at any height give their offsets.
local NOMINAL = { w = 500, h = 640 }
local BUTTON_WIDTH = 120

local FILTERS: { [string]: { [string]: boolean }? } = {
	all = nil,
	equipment = { equipment = true, backpack = true },
	materials = { material = true },
	consumables = { consumable = true, scroll = true, stone = true, tool = true },
}

local function BackpackPanel(scope: Scope, props: Props): Fusion.Child
	local actions = props.Actions
	local touch = scope:Computed(function(use): boolean
		return use(Device.Touch) == true
	end)
	local slotSize = scope:Computed(function(use): number
		return props.SlotSize or (if use(touch) then TOUCH_SLOT else SLOT)
	end)
	local buttonWidth = props.ButtonWidth or BUTTON_WIDTH
	-- the sort and action buttons: a touch target on touch
	local buttonHeight = scope:Computed(function(use): number
		return if use(touch) then Theme.Size.MinTouch else Theme.Size.ButtonHeightSmall
	end)
	local inventory = State.Value({ "character", "inventory" })
	local backpack = State.Value({ "character", "equipment", "backpack" })
	local gold = State.Value({ "character", "gold" })
	local filter = scope:Value("all")
	local sorting = false

	local pockets = State.Value({ "passes", "pockets" })
	local capacity = scope:Computed(function(use): number
		local item = use(backpack)
		return Inventory.capacityOf(if item then item.id else nil, use(pockets) == true)
	end)
	-- S121: slots drawn = the capacity, or more while items sit above it (overflow)
	local shown = scope:Computed(function(use): number
		return math.max(use(capacity), Inventory.lastIndex(use(inventory) or {}))
	end)
	local overflow = scope:Computed(function(use): boolean
		return use(shown) > use(capacity)
	end)
	-- the overflow / pockets line takes its own row under the header (GearLayout.backpack)
	local hinted = scope:Computed(function(use): boolean
		return use(overflow) or use(pockets) == true
	end)
	local rects = scope:Computed(function(use): GearLayout.Backpack
		return GearLayout.backpack(NOMINAL, use(slotSize), use(hinted), use(touch))
	end)
	local used = scope:Computed(function(use): number
		local n = 0
		for _ in use(inventory) or {} do
			n += 1
		end
		return n
	end)
	local selectedIndex = scope:Computed(function(use): number?
		local selected = use(DragDrop.Selected)
		local index = selected and string.match(selected, "^inv:(%d+)$")
		return if index then tonumber(index) else nil
	end)
	local selectedItem = scope:Computed(function(use): Types.ItemInstance?
		local index = use(selectedIndex)
		local inv = use(inventory)
		return if index and inv then inv[tostring(index)] else nil
	end)

	-- S134f: a slot listens to its own key only (a diff of slot "17" does not touch slot "5"); a sort or a
	-- snapshot replaces the whole inventory and refreshes every slot once.
	local function slotItem(_s: Scope, index: number): Fusion.Value<any>
		return State.Value({ "character", "inventory", tostring(index) })
	end

	-- Slots are rebuilt only when the capacity (or the overflow) changes, or the slot size with the input device;
	-- contents update reactively.
	local grid = scope:Computed(function(use, s: Scope): { Instance }
		local count = use(shown)
		local cap = use(capacity)
		local size = use(slotSize)
		local list = {}
		for index = 1, count do
			local item = slotItem(s, index)
			local slot = ItemSlot(s, {
				SlotId = `inv:{index}`,
				Item = item,
				Size = size,
				LayoutOrder = index,
				Visible = s:Computed(function(use2): boolean
					local categories = FILTERS[use2(filter)]
					if not categories then
						return true
					end
					local i = use2(item)
					local def = i and Items.get(i.id)
					return def ~= nil and categories[def.category] == true
				end),
			})
			if index > cap then
				-- S121: an overflow slot: a red frame over the slot (input goes through to the slot)
				s:New("Frame")({
					Name = "Overflow",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					Active = false,
					ZIndex = 5,
					Parent = slot,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIStroke")({
							ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							Color = Theme.Paper.Danger,
							Thickness = Theme.Stroke.Normal,
						}),
					},
				})
			end
			table.insert(list, slot)
		end
		return list
	end)

	local function actionButton(
		order: number,
		key: string,
		visible: Fusion.UsedAs<boolean>,
		onClick: (index: number) -> (),
		variant: string?
	)
		return Button(scope, {
			LayoutOrder = order,
			Text = Text.T(scope, key),
			Variant = (variant or "secondary") :: any,
			Size = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(buttonWidth, use(buttonHeight))
			end),
			TextSize = Theme.TextSize.Small,
			Visible = visible,
			OnClick = function()
				local index = Fusion.peek(selectedIndex)
				if index then
					onClick(index)
				end
			end,
		})
	end

	local selectedDef = scope:Computed(function(use): Items.ItemDef?
		local item = use(selectedItem)
		return if item then Items.get(item.id) else nil
	end)

	-- Actions for the selected slot
	-- Scrolls sideways when the panel is narrower than the visible buttons (touch, character window); on touch the
	-- bar is one button high and its thin scroll bar lies over the buttons' lower edge (GearLayout.backpack).
	-- UI package C's ItemTooltip.avoid (adoption stage, 2026-11-10): the touch tooltip keeps off the bar
	local actionBar = scope:New("ScrollingFrame")({
		Name = "Actions",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = scope:Computed(function(use): UDim2
			return UDim2.new(1, 0, 0, NOMINAL.h - use(rects).actions.top)
		end),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, Theme.Padding.Small),
			}),
			actionButton(
				1,
				"inventory.action.equip",
				scope:Computed(function(use): boolean
					local def = use(selectedDef)
					return def ~= nil and def.slot ~= nil
				end),
				actions.Equip,
				"primary"
			),
			actionButton(
				2,
				"inventory.action.use",
				scope:Computed(function(use): boolean
					local def = use(selectedDef)
					return def ~= nil and def.slot == nil and def.use ~= nil and def.use.kind ~= "none"
				end),
				actions.Use,
				"primary"
			),
			actionButton(
				3,
				"inventory.action.split",
				scope:Computed(function(use): boolean
					local item = use(selectedItem)
					return item ~= nil and item.n > 1
				end),
				actions.Split
			),
			-- Padlock (S20): protects from selling, dismantling, destroying and trading.
			Button(scope, {
				LayoutOrder = 5,
				Text = scope:Computed(function(use): string
					local item = use(selectedItem)
					return Text.get(use, if item and item.locked then "item.unlock" else "item.lock")
				end),
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(math.min(110, buttonWidth), use(buttonHeight))
				end),
				TextSize = Theme.TextSize.Small,
				Visible = scope:Computed(function(use): boolean
					local def = use(selectedDef)
					return def ~= nil and def.category == "equipment"
				end),
				OnClick = function()
					local index = Fusion.peek(selectedIndex)
					if index then
						actions.Lock(index)
					end
				end,
			}),
			Button(scope, {
				LayoutOrder = 6,
				Text = Text.T(scope, "lootlog.button"),
				Size = scope:Computed(function(use): UDim2
					return UDim2.fromOffset(math.min(90, buttonWidth), use(buttonHeight))
				end),
				TextSize = Theme.TextSize.Small,
				OnClick = function()
					actions.LootLog()
				end,
			}),
			actionButton(
				4,
				"inventory.action.destroy",
				scope:Computed(function(use): boolean
					return use(selectedItem) ~= nil
				end),
				actions.Destroy,
				"danger"
			),
		},
	})
	ItemTooltip.avoid(scope, actionBar :: GuiObject)

	return {
		-- Header: gold, slots, sort
		scope:New("Frame")({
			Name = "Header",
			Size = scope:Computed(function(use): UDim2
				local header = use(rects).header
				return UDim2.new(1, 0, 0, header.bottom - header.top)
			end),
			BackgroundTransparency = 1,
			[Children] = {
				-- S35: gold coin from the item atlases (the ◉ glyph before the upload).
				CurrencyIcon(scope, {
					Currency = "gold",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(20, 20),
				}),
				scope:New("TextLabel")({
					Name = "Gold",
					Position = UDim2.fromOffset(24, 0),
					Size = UDim2.new(1, -374, 1, 0),
					TextTruncate = Enum.TextTruncate.AtEnd,
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "inventory.gold", { gold = Format.number(use(gold) or 0) })
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				-- S121: under the count, the Merchant's Pockets line or the overflow warning
				scope:New("TextLabel")({
					Name = "Slots",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -140, 0, 0),
					Size = UDim2.new(0, 120, 1, 0),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "inventory.slots", { used = use(used), capacity = use(capacity) })
					end),
					FontFace = Theme.Fonts.BodyMedium,
					TextSize = Theme.TextSize.Body,
					TextColor3 = scope:Computed(function(use): Color3
						return if use(used) >= use(capacity) then Theme.Paper.Danger else Theme.Paper.Text
					end),
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 128, 1, 0), -- the header's height: 40, or 44 on touch
					Text = Text.T(scope, "inventory.sort"),
					TextSize = Theme.TextSize.Small,
					OnClick = function()
						if sorting then
							return
						end
						sorting = true
						DragDrop.Clear()
						task.spawn(function()
							local ok, err = Net.Invoke("SortInventory")
							sorting = false
							if not ok then
								Toast.push(Text.now(err or "error.internal"), "error")
							end
						end)
					end,
				}),
			},
		}),
		-- owner 2026-11-10 (UI plan): the overflow / pockets line under the header in Small 17, never scaled text over the
		-- gold (GearLayout.backpack's hint)
		scope:New("TextLabel")({
			Name = "SlotsHint",
			Position = scope:Computed(function(use): UDim2
				local hint = use(rects).hint
				return UDim2.fromOffset(0, if hint then hint.top else 0)
			end),
			Size = UDim2.new(1, 0, 0, GearLayout.BACKPACK.hint),
			BackgroundTransparency = 1,
			Visible = hinted,
			Text = scope:Computed(function(use): string
				if use(overflow) then
					return Text.get(use, "backpack.overflow")
				end
				return Text.get(use, "backpack.pockets", { n = Products.POCKETS_SLOTS })
			end),
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Small,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = scope:Computed(function(use): Color3
				return if use(overflow) then Theme.Paper.Danger else Theme.Paper.TextMuted
			end),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		Tabs(scope, {
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(0, use(rects).tabs.top)
			end),
			Selected = filter,
			Tabs = {
				{ id = "all", label = Text.T(scope, "inventory.filter.all") },
				{ id = "equipment", label = Text.T(scope, "inventory.filter.equipment") },
				{ id = "materials", label = Text.T(scope, "inventory.filter.materials") },
				{ id = "consumables", label = Text.T(scope, "inventory.filter.consumables") },
			},
		}),
		scope:New("ScrollingFrame")({
			Name = "Grid",
			Position = scope:Computed(function(use): UDim2
				return UDim2.fromOffset(0, use(rects).grid.top)
			end),
			Size = scope:Computed(function(use): UDim2
				local r = use(rects)
				return UDim2.new(1, 0, 1, -(r.grid.top + NOMINAL.h - r.grid.bottom))
			end),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Paper.Label,
			[Children] = {
				scope:New("UIGridLayout")({
					CellSize = scope:Computed(function(use): UDim2
						local size = use(slotSize)
						return UDim2.fromOffset(size, size)
					end),
					CellPadding = UDim2.fromOffset(GAP, GAP),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 4),
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 10),
				}),
				grid :: any,
			},
		}),
		actionBar,
	}
end

return BackpackPanel
