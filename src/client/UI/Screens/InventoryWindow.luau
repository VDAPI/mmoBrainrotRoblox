--!strict
-- Backpack window (B), DESIGN §23: slot grid sized by the backpack, gold, used/total slots, sort button,
-- category filter and an action bar for the selected slot (works for mouse and touch).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
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

local SLOT = 64
local GAP = 6

local FILTERS: { [string]: { [string]: boolean }? } = {
	all = nil,
	equipment = { equipment = true, backpack = true },
	materials = { material = true },
	consumables = { consumable = true, scroll = true, stone = true, tool = true },
}

local function InventoryWindow(scope: Scope, actions: Actions): Fusion.Child
	local inventory = State.Value({ "character", "inventory" })
	local backpack = State.Value({ "character", "equipment", "backpack" })
	local gold = State.Value({ "character", "gold" })
	local filter = scope:Value("all")
	local sorting = false

	local capacity = scope:Computed(function(use): number
		local item = use(backpack)
		local def = item and Items.get(item.id)
		return if def and def.capacity then def.capacity else Config.DefaultCapacity
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

	local function slotItem(s: Scope, index: number)
		return s:Computed(function(use): Types.ItemInstance?
			local inv = use(inventory)
			return if inv then inv[tostring(index)] else nil
		end)
	end

	-- Slots are rebuilt only when the capacity changes; contents update reactively.
	local grid = scope:Computed(function(use, s: Scope): { Instance }
		local count = use(capacity)
		local list = {}
		for index = 1, count do
			local item = slotItem(s, index)
			table.insert(
				list,
				ItemSlot(s, {
					SlotId = `inv:{index}`,
					Item = item,
					Size = SLOT,
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
			)
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
			Size = UDim2.fromOffset(120, Theme.Size.ButtonHeightSmall),
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

	return {
		-- Header: gold, slots, sort
		scope:New("Frame")({
			Name = "Header",
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Name = "Gold",
					Size = UDim2.fromScale(0.5, 1),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return `◉ {Text.get(use, "inventory.gold", { gold = Format.number(use(gold) or 0) })}`
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
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
						return if use(used) >= use(capacity) then Theme.Colors.DangerHover else Theme.Colors.Text
					end),
					TextXAlignment = Enum.TextXAlignment.Right,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(128, 40),
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
		Tabs(scope, {
			Position = UDim2.fromOffset(0, 48),
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
			Position = UDim2.fromOffset(0, 98),
			Size = UDim2.new(1, 0, 1, -98 - 52),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = {
				scope:New("UIGridLayout")({
					CellSize = UDim2.fromOffset(SLOT, SLOT),
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
		-- Actions for the selected slot
		scope:New("Frame")({
			Name = "Actions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightSmall),
			BackgroundTransparency = 1,
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
					Size = UDim2.fromOffset(110, Theme.Size.ButtonHeightSmall),
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
					Size = UDim2.fromOffset(90, Theme.Size.ButtonHeightSmall),
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
		}),
	}
end

return InventoryWindow
