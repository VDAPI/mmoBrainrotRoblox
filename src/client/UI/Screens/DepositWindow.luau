--!strict
-- Vault window (DESIGN §5.7): backpack and account vault side by side. Drag items between them ("inv:N" ↔
-- "dep:N", handled by ItemController), double-click a vault item to take it out; both sides can be sorted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SLOT = 56

local function grid(scope: Scope, prefix: string, count: Fusion.UsedAs<number>, source: Fusion.Value<any>): Instance
	local slots = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		for index = 1, use(count) do
			local key = tostring(index)
			table.insert(
				list,
				ItemSlot(s, {
					SlotId = `{prefix}:{index}`,
					Size = SLOT,
					LayoutOrder = index,
					Item = s:Computed(function(use2): Types.ItemInstance?
						local items = use2(source)
						return if type(items) == "table" then items[key] else nil
					end),
				})
			)
		end
		return list
	end)
	return scope:New("ScrollingFrame")({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.GoldDim,
		[Children] = {
			scope:New("UIGridLayout")({
				CellSize = UDim2.fromOffset(SLOT, SLOT),
				CellPadding = UDim2.fromOffset(5, 5),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 2) }),
			slots :: any,
		},
	})
end

local function DepositWindow(scope: Scope): Fusion.Child
	local inventory = State.Value({ "character", "inventory" })
	local depositItems = State.Value({ "account", "deposit", "items" })
	local depositSize = State.Value({ "account", "deposit", "size" })
	local backpack = State.Value({ "character", "equipment", "backpack" })

	local capacity = scope:Computed(function(use): number
		local item = use(backpack)
		local def = item and Items.get(item.id)
		return if def and def.capacity then def.capacity else Config.DefaultCapacity
	end)
	local size = scope:Computed(function(use): number
		local value = use(depositSize)
		return if type(value) == "number" then value else 60
	end)
	local used = scope:Computed(function(use): number
		local n = 0
		for _ in use(depositItems) or {} do
			n += 1
		end
		return n
	end)

	local function sort(name: string)
		DragDrop.Clear()
		task.spawn(function()
			local ok, err = Net.Invoke(name)
			if not ok then
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	local function column(position: UDim2, title: Fusion.UsedAs<string>, onSort: () -> (), content: Instance): Instance
		return scope:New("Frame")({
			Position = position,
			Size = UDim2.new(0.5, -8, 1, 0),
			BackgroundTransparency = 1,
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.new(1, -110, 0, 36),
					BackgroundTransparency = 1,
					Text = title,
					FontFace = Theme.Fonts.Heading,
					TextSize = Theme.TextSize.Large,
					TextColor3 = Theme.Colors.Gold,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(100, 36),
					TextSize = Theme.TextSize.Small,
					Text = Text.T(scope, "inventory.sort"),
					OnClick = onSort,
				}),
				content,
			},
		})
	end

	return {
		column(UDim2.fromScale(0, 0), Text.T(scope, "deposit.inventory"), function()
			sort("SortInventory")
		end, grid(scope, "inv", capacity, inventory)),
		column(
			UDim2.new(0.5, 8, 0, 0),
			scope:Computed(function(use): string
				return Text.get(use, "deposit.slots", { used = use(used), size = use(size) })
			end),
			function()
				sort("SortDeposit")
			end,
			grid(scope, "dep", size, depositItems)
		),
	}
end

return DepositWindow
