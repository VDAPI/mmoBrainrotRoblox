--!strict
-- Shop window (DESIGN §9, §18): Buy (icon, name, price, quantity with −/+/Max), Sell (click backpack items to
-- select, total, confirmation for Epic and better) and Buy back (last 10 sold). Gold always visible.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemText = require(script.Parent.Parent.ItemText)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SelectableSlot = require(script.Parent.Parent.Components.SelectableSlot)
local ShopPrice = require(ReplicatedStorage.Shared.Logic.ShopPrice)
local Shops = require(ReplicatedStorage.Shared.Data.Shops)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, Out = Fusion.Children, Fusion.Out

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	ShowModal: (spec: any) -> (),
}

local ROW = 70

local function preview(itemId: string): Types.ItemInstance
	return ItemRoll.makeStack(itemId, 1, `preview:{itemId}`)
end

local function invoke(name: string, ...: any): (boolean, any)
	local ok, err, extra = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok, extra
end

local function priceOf(entry: Shops.Entry): number
	return ShopPrice.unit(
		entry,
		State.Get({ "character", "level" }) or 1,
		State.Get({ "derived", "values", "potionDiscount" }) or 0
	)
end

local function buyRow(scope: Scope, npcId: string, entry: Shops.Entry, order: number): Instance
	local def = Items.get(entry.item)
	local quantity = scope:Value("1")
	local maxStack = if def then def.maxStack else 1
	local function amount(): number
		return math.clamp(tonumber(Fusion.peek(quantity)) or 1, 1, maxStack)
	end
	return scope:New("Frame")({
		Name = entry.item,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.4,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			ItemSlot(scope, {
				SlotId = `view:shop:{entry.item}`,
				Item = preview(entry.item),
				Size = 56,
				Position = UDim2.fromOffset(7, 7),
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(74, 8),
				Size = UDim2.new(1, -380, 0, 26),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return ItemText.get(use, entry.item)
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Colors.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(74, 36),
				Size = UDim2.new(1, -380, 0, 22),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					use(State.Value({ "character", "level" }))
					return Text.get(use, "shop.price", { price = Format.number(priceOf(entry)) })
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			-- Quantity
			scope:New("Frame")({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -140, 0.5, 0),
				Size = UDim2.fromOffset(190, 44),
				BackgroundTransparency = 1,
				Visible = maxStack > 1,
				[Children] = {
					scope:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						Padding = UDim.new(0, 4),
					}),
					Button(scope, {
						LayoutOrder = 1,
						Text = "−",
						Size = UDim2.fromOffset(44, 44),
						OnClick = function()
							quantity:set(tostring(math.max(1, amount() - 1)))
						end,
					}),
					scope:New("TextBox")({
						LayoutOrder = 2,
						Size = UDim2.fromOffset(52, 40),
						BackgroundColor3 = Theme.Colors.Background,
						Text = quantity,
						[Out("Text")] = quantity,
						ClearTextOnFocus = false,
						FontFace = Theme.Fonts.BodyBold,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.Text,
						[Children] = scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
					}),
					Button(scope, {
						LayoutOrder = 3,
						Text = "+",
						Size = UDim2.fromOffset(44, 44),
						OnClick = function()
							quantity:set(tostring(math.min(maxStack, amount() + 1)))
						end,
					}),
					Button(scope, {
						LayoutOrder = 4,
						Text = Text.T(scope, "shop.max"),
						TextSize = Theme.TextSize.Small,
						Size = UDim2.fromOffset(40, 44),
						OnClick = function()
							local gold = State.Get({ "character", "gold" }) or 0
							local price = math.max(1, priceOf(entry))
							quantity:set(tostring(math.clamp(math.floor(gold / price), 1, maxStack)))
						end,
					}),
				},
			}),
			Button(scope, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.fromOffset(120, 48),
				Variant = "primary",
				Text = Text.T(scope, "shop.buy"),
				OnClick = function()
					local n = amount()
					task.spawn(function()
						if invoke("Buy", npcId, entry.item, n) then
							Sounds.play("click")
							Toast.push(
								Text.now("shop.bought", { name = ItemText.name(entry.item), n = n }),
								"success",
								2
							)
						end
					end)
				end,
			}),
		},
	})
end

local function ShopWindow(scope: Scope, props: Props): Fusion.Child
	local tab = scope:Value("buy")
	local inventory = State.Value({ "character", "inventory" })
	local gold = State.Value({ "character", "gold" })
	local buyback = State.Value({ "buyback" })
	local selected = scope:Value({} :: { [string]: boolean })

	local npcId = scope:Computed(function(use): string?
		return use(props.NpcId)
	end)

	local sellTotal = scope:Computed(function(use): number
		local inv = use(inventory) or {}
		local total = 0
		for key in use(selected) do
			local item = inv[key]
			if item then
				total += ItemRoll.sellPrice(item)
			end
		end
		return total
	end)

	-- Sells backpack slots (keys "1".."N"): the selection, or one item dropped on the window (S17).
	local function sellKeys(keys: { string })
		local id = Fusion.peek(npcId)
		local inv = Fusion.peek(inventory) or {}
		local indices = {}
		local valuable = false
		local total = 0
		for _, key in keys do
			local item = inv[key]
			if item then
				table.insert(indices, tonumber(key))
				total += ItemRoll.sellPrice(item)
				if item.rarity >= Rarities.EPIC then
					valuable = true
				end
			end
		end
		if not id or #indices == 0 then
			Toast.push(Text.now("shop.error.nothing"), "warning")
			return
		end
		local function doSell(): (boolean, string?)
			local ok, err, total = Net.Invoke("Sell", id, indices)
			if ok then
				selected:set({}) -- slots shift after a sale, so the old selection would be wrong
				Sounds.play("click")
				Toast.push(Text.now("shop.sold", { gold = Format.number(total or 0) }), "success")
				return true, nil
			end
			return false, Text.now(err or "error.internal")
		end
		if valuable and State.Get({ "account", "settings", "sellConfirm" }) ~= false then
			props.ShowModal({
				Title = Text.now("shop.confirm.title"),
				Message = Text.now("shop.confirm.message", { gold = Format.number(total) }),
				ConfirmText = Text.now("shop.sell"),
				CancelText = Text.now("common.cancel"),
				Variant = "danger",
				OnConfirm = doSell,
			})
		else
			task.spawn(function()
				local ok, err = doSell()
				if not ok then
					Toast.push(err or "", "error")
				end
			end)
		end
	end

	local function sellSelected()
		local keys = {}
		for key in Fusion.peek(selected) do
			table.insert(keys, key)
		end
		sellKeys(keys)
	end

	-- Dragging (or tapping, after selecting it) a backpack item onto the drop zone sells it.
	DragDrop.SellHandler = function(index: number)
		sellKeys({ tostring(index) })
	end
	table.insert(scope, function()
		DragDrop.SellHandler = nil
	end)

	local dropZone = scope:New("TextLabel")({
		Name = "SellDrop",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 44),
		Visible = scope:Computed(function(use): boolean
			return use(tab) ~= "sell"
		end),
		BackgroundColor3 = scope:Computed(function(use): Color3
			return if use(DragDrop.Dragging) ~= nil then Theme.Colors.GoldDim else Theme.Colors.Panel
		end),
		BackgroundTransparency = 0.3,
		Text = Text.T(scope, "shop.dropToSell"),
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Colors.Parchment,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({ Color = Theme.Colors.GoldDim, Thickness = 1, Transparency = 0.3 }),
		},
	})
	DragDrop.register(scope, dropZone :: any, "shopsell:zone")

	local content = scope:Computed(function(use, s: Scope): { Instance }
		local current = use(tab)
		local id = use(npcId)
		local npc = id and Npcs.get(id)
		local shop = npc and npc.shop and Shops.get(npc.shop)
		if current == "buy" then
			local rows = {}
			if shop and id then
				for i, entry in shop.entries do
					table.insert(rows, buyRow(s, id, entry, i))
				end
			end
			return rows
		elseif current == "sell" then
			local list = {
				s:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = Text.get(use, "shop.sellHint"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
			}
			local grid = {}
			local keys = {}
			for key in use(inventory) or {} do
				table.insert(keys, tonumber(key) :: number)
			end
			table.sort(keys)
			for _, index in keys do
				local key = tostring(index)
				table.insert(
					grid,
					SelectableSlot(s, {
						Id = `sell:{key}`,
						LayoutOrder = index,
						Item = s:Computed(function(use2): Types.ItemInstance?
							local inv = use2(inventory)
							return if inv then inv[key] else nil
						end),
						Selected = s:Computed(function(use2): boolean
							return use2(selected)[key] == true
						end),
						OnToggle = function()
							local copy = table.clone(Fusion.peek(selected))
							copy[key] = if copy[key] then nil :: any else true
							selected:set(copy)
						end,
					})
				)
			end
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = 1,
					Size = UDim2.fromScale(1, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIGridLayout")({
							CellSize = UDim2.fromOffset(64, 64),
							CellPadding = UDim2.fromOffset(6, 6),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						grid :: any,
					},
				})
			)
			return list
		else
			local rows = {}
			local entries = use(buyback) or {}
			for i, entry in entries do
				table.insert(
					rows,
					s:New("Frame")({
						LayoutOrder = i,
						Size = UDim2.new(1, 0, 0, ROW),
						BackgroundColor3 = Theme.Colors.PanelRaised,
						BackgroundTransparency = 0.4,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							ItemSlot(s, {
								SlotId = `view:buyback:{i}`,
								Item = entry.item,
								Size = 56,
								Position = UDim2.fromOffset(7, 7),
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(74, 8),
								Size = UDim2.new(1, -220, 0, 26),
								BackgroundTransparency = 1,
								Text = ItemText.get(use, entry.item.id, entry.item.up),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = ItemText.rarityColor(entry.item.rarity),
								TextXAlignment = Enum.TextXAlignment.Left,
								TextTruncate = Enum.TextTruncate.AtEnd,
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(74, 36),
								Size = UDim2.new(1, -220, 0, 22),
								BackgroundTransparency = 1,
								Text = Text.get(use, "shop.price", { price = Format.number(entry.price) }),
								FontFace = Theme.Fonts.BodyMedium,
								TextSize = Theme.TextSize.Small,
								TextColor3 = Theme.Colors.GoldBright,
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							Button(s, {
								AnchorPoint = Vector2.new(1, 0.5),
								Position = UDim2.new(1, -8, 0.5, 0),
								Size = UDim2.fromOffset(130, 48),
								Text = Text.T(s, "shop.buyback"),
								OnClick = function()
									task.spawn(function()
										invoke("Buyback", id, i)
									end)
								end,
							}),
						},
					})
				)
			end
			if #rows == 0 then
				table.insert(
					rows,
					s:New("TextLabel")({
						Size = UDim2.new(1, 0, 0, 40),
						BackgroundTransparency = 1,
						Text = Text.get(use, "shop.buybackEmpty"),
						FontFace = Theme.Fonts.Body,
						TextSize = Theme.TextSize.Body,
						TextColor3 = Theme.Colors.TextMuted,
					})
				)
			end
			return rows
		end
	end)

	return {
		Tabs(scope, {
			Selected = tab,
			Tabs = {
				{ id = "buy", label = Text.T(scope, "shop.tab.buy") },
				{ id = "sell", label = Text.T(scope, "shop.tab.sell") },
				{ id = "buyback", label = Text.T(scope, "shop.tab.buyback") },
			},
		}),
		scope:New("TextLabel")({
			Name = "Gold",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.fromOffset(220, 40),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return `◉ {Text.get(use, "inventory.gold", { gold = Format.number(use(gold) or 0) })}`
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		scope:New("ScrollingFrame")({
			Name = "List",
			Position = UDim2.fromOffset(0, 50),
			Size = scope:Computed(function(use): UDim2
				return UDim2.new(1, 0, 1, if use(tab) == "sell" then -110 else -100)
			end),
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.GoldDim,
			[Children] = {
				scope:New("UIListLayout")({
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 6),
				}),
				scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
				content :: any,
			},
		}),
		dropZone,
		scope:New("Frame")({
			Name = "SellBar",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			Visible = scope:Computed(function(use): boolean
				return use(tab) == "sell"
			end),
			[Children] = {
				scope:New("TextLabel")({
					Size = UDim2.fromScale(0.5, 1),
					BackgroundTransparency = 1,
					Text = scope:Computed(function(use): string
						return Text.get(use, "shop.total", { gold = Format.number(use(sellTotal)) })
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Colors.GoldBright,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(240, 50),
					Variant = "primary",
					Text = Text.T(scope, "shop.sell"),
					Disabled = scope:Computed(function(use): boolean
						return next(use(selected)) == nil
					end),
					OnClick = sellSelected,
				}),
			},
		}),
	}
end

return ShopWindow
