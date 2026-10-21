--!strict
-- Shop window (DESIGN §9, §18): Buy, Sell (click backpack items to select, total, confirmation for Epic and better)
-- and Buy back (last 10 sold). FIX 2026-10-15 (owner): on the Sell tab the items are marked right in the backpack
-- next to the shop (DragDrop.MarkHandler / Marked: a click or tap toggles the check mark); the tab lists what is
-- marked (a click removes it), the total and "Sell marked". No second copy of the backpack in the shop any more. Gold always visible. Prices come from ItemValue.buyPrice (S31; the tooltip shows the
-- same price).
-- FIX 2026-10-14 (owner): Buy is a grid of icons grouped by kind (Logic/ShopGroups: weapons, off-hand, armour
-- pieces, jewellery, potions, ...) with a small header per group; hovering an icon (PC) or tapping it (touch) shows
-- the item tooltip with its name and stats; a click / tap picks it for the buy bar under the grid (name, price,
-- quantity with −/+/Max, "Buy"). S95: a class vendor (shop.class) lists every tier (5, 15 ... 95, ascending in each
-- group); items above the character's level show a red "Requires level N" in the bar and a disabled "Buy", gear
-- another class wears "Only for: ..." (the server refuses both too); the icons of both are red. Another class's
-- vendor and the dealer (no entries: no Buy tab) show who sells the player's gear, with "Guide me".
-- 2026-10-21 (owner: too many detailed descriptions): short hints; the vendor bar names the vendor, where to find them
-- is behind its "i" (shop.vendor.otherClass).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local InfoTip = require(script.Parent.Parent.Components.InfoTip)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemTooltip = require(script.Parent.Parent.Components.ItemTooltip)
local ItemText = require(script.Parent.Parent.ItemText)
local ItemValue = require(ReplicatedStorage.Shared.Logic.ItemValue)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Potions = require(ReplicatedStorage.Shared.Logic.Potions)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local SelectableSlot = require(script.Parent.Parent.Components.SelectableSlot)
local ShopGroups = require(ReplicatedStorage.Shared.Logic.ShopGroups)
local ShopPrice = require(ReplicatedStorage.Shared.Logic.ShopPrice)
local Shops = require(ReplicatedStorage.Shared.Data.Shops)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)
local TooltipModel = require(ReplicatedStorage.Shared.Logic.TooltipModel)
local Types = require(ReplicatedStorage.Shared.Types)

local Children, Out = Fusion.Children, Fusion.Out

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	NpcId: Fusion.UsedAs<string?>,
	ShowModal: (spec: any) -> (),
	-- S95: leads the player to an NPC (NavController.GuideToNpc) and closes the window
	Guide: (npcId: string) -> (),
}

local ROW = 76 -- buyback rows
local SELL_RETRY = 0.3 -- S134f: pause before a rate-limited single sale is retried as one batch (seconds)
-- FIX 2026-10-14: the Buy grid's cell and icon, and the buy bar under it.
local CELL = 68
local ICON = 60
local BUY_BAR = 64
local RED_HEX = "#" .. Theme.Paper.Danger:ToHex()

-- Highest rarity the "sell all" buttons may include (S30: the `quickSell` rarities, Common and Unique).
local QUICK_SELL_MAX = Rarities.COMMON
for _, rarity in Rarities.list do
	if rarity.quickSell then
		QUICK_SELL_MAX = math.max(QUICK_SELL_MAX, rarity.id)
	end
end

-- The (Common, +0) item an entry sells: the same instance the price and the tooltip are computed from.
local function preview(entry: Shops.Entry): Types.ItemInstance
	return ItemValue.entryItem(entry)
end

local function invoke(name: string, ...: any): (boolean, any)
	local ok, err, extra = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok, extra
end

-- Unit price shown in the row, the tooltip and charged by ShopService (ShopPrice.unit -> ItemValue.buyPrice).
local function priceOf(entry: Shops.Entry, shop: Shops.ShopDef?): number
	return ShopPrice.unit(
		entry,
		State.Get({ "character", "level" }) or 1,
		State.Get({ "derived", "values", "potionDiscount" }) or 0,
		shop
	)
end

-- S87: the entry's level or the potion's (Great 45, Mighty 70), the same expression as ShopService.buy.
local function requiredLevelOf(entry: Shops.Entry): number
	return math.max(entry.level or 1, Potions.requiredLevel(Items.get(entry.item)))
end

-- One icon of the Buy grid (FIX 2026-10-14): the item's slot (tooltip with name, stats and price on hover, PC, or
-- on a tap, touch; red when the character cannot use it) in a frame that lights up when it is picked for the buy bar.
local function buyCell(
	scope: Scope,
	shop: Shops.ShopDef,
	entry: Shops.Entry,
	order: number,
	chosen: Fusion.Value<string?>
): Instance
	local key = entry.key or entry.item
	local picked = scope:Computed(function(use): boolean
		return use(chosen) == key
	end)
	local slot = ItemSlot(scope, {
		SlotId = `view:shop:{key}`,
		Item = preview(entry),
		Size = ICON,
		Position = UDim2.fromOffset((CELL - ICON) / 2, (CELL - ICON) / 2),
		TooltipCtx = function(): TooltipModel.Ctx?
			return {
				shop = shop,
				shopEntry = entry,
				potionDiscount = State.Get({ "derived", "values", "potionDiscount" }) or 0,
				merchantOpen = false,
				hints = false,
			}
		end,
	})
	-- A click (PC) or a tap (touch; DragDrop shows the tooltip of the tapped slot) picks the item for the buy bar.
	-- A touch picks only when it ends near where it began, so a swipe that scrolls the grid keeps the pick.
	local touchFrom: Vector2? = nil
	table.insert(
		scope,
		(slot :: GuiObject).InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 then
				if Fusion.peek(chosen) ~= key then
					Sounds.play("click")
				end
				chosen:set(key)
			elseif kind == Enum.UserInputType.Touch then
				local at = Vector2.new(input.Position.X, input.Position.Y)
				touchFrom = if DragDrop.IsBlocked(at) then nil else at
			end
		end)
	)
	table.insert(
		scope,
		(slot :: GuiObject).InputEnded:Connect(function(input: InputObject)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			local from = touchFrom
			touchFrom = nil
			local at = Vector2.new(input.Position.X, input.Position.Y)
			if from and (at - from).Magnitude <= DragDrop.TAP_SLOP and not DragDrop.IsBlocked(at) then
				chosen:set(key)
			end
		end)
	)
	return scope:New("Frame")({
		Name = key,
		LayoutOrder = order,
		Size = UDim2.fromOffset(CELL, CELL),
		BackgroundColor3 = Theme.Paper.Rule,
		BackgroundTransparency = scope:Computed(function(use): number
			return if use(picked) then 0.45 else 1
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				Color = Theme.Brass.Frame,
				Thickness = 2,
				Enabled = picked,
			}),
			slot,
		},
	})
end

-- Buy bar under the grid (FIX 2026-10-14): the picked item's name, price (with "Only for" / "Requires level" in red),
-- the quantity for stackable items and "Buy"; a hint while nothing is picked.
local function buyBar(
	scope: Scope,
	use: Fusion.Use,
	npcId: string,
	shop: Shops.ShopDef,
	entry: Shops.Entry?
): { Instance }
	if not entry then
		return {
			scope:New("TextLabel")({
				Name = "Hint",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = Text.get(use, "shop.pick"),
				FontFace = Theme.Fonts.Body,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.TextMuted,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		}
	end
	local def = Items.get(entry.item)
	local key = entry.key or entry.item
	local quantity = scope:Value("1")
	local maxStack = if def then def.maxStack else 1
	local item = preview(entry)
	-- Text column width: stackable items keep room for the quantity controls.
	local textWidth = if maxStack > 1 then -380 else -144
	local level = State.Value({ "character", "level" })
	local requiredLevel = requiredLevelOf(entry)
	-- S95: gear of another class can be browsed, not bought (ShopService refuses it with shop.error.class)
	local classLocked = not ShopPrice.usableBy(entry, State.Get({ "character", "class" }))
	local locked = scope:Computed(function(use2): boolean
		return classLocked or requiredLevel > (use2(level) or 1)
	end)
	local function amount(): number
		return math.clamp(tonumber(Fusion.peek(quantity)) or 1, 1, maxStack)
	end
	return {
		scope:New("TextLabel")({
			Name = "ItemName",
			Position = UDim2.fromOffset(4, 6),
			Size = UDim2.new(1, textWidth, 0, 24),
			BackgroundTransparency = 1,
			Text = ItemText.get(use, entry.item, nil, entry.el),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Body,
			TextColor3 = ItemText.rarityName(item.rarity, "paper"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		scope:New("TextLabel")({
			Name = "Price",
			Position = UDim2.fromOffset(4, 32),
			Size = UDim2.new(1, textWidth, 0, 22),
			BackgroundTransparency = 1,
			RichText = true,
			Text = scope:Computed(function(use2): string
				use2(level)
				use2(State.Value({ "derived", "values", "potionDiscount" }))
				local price = Text.get(use2, "shop.price", { price = Format.number(priceOf(entry, shop)) })
				if classLocked then
					local names = {}
					local classes: { string } = entry.classes or {}
					for _, classId in classes do
						table.insert(names, Text.get(use2, `class.{classId}.name`))
					end
					local only = Text.get(use2, "shop.onlyFor", { classes = table.concat(names, ", ") })
					return `{price}   <font color="{RED_HEX}">{only}</font>`
				end
				if use2(locked) then
					local need = Text.get(use2, "shop.requiresLevel", { level = requiredLevel })
					return `{price}   <font color="{RED_HEX}">{need}</font>`
				end
				return price
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Paper.Heading,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		-- Quantity
		scope:New("Frame")({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -132, 0.5, 0),
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
					BackgroundColor3 = Theme.Paper.Sunken,
					Text = quantity,
					[Out("Text")] = quantity,
					ClearTextOnFocus = false,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Body,
					TextColor3 = Theme.Paper.Text,
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
						local price = math.max(1, priceOf(entry, shop))
						quantity:set(tostring(math.clamp(math.floor(gold / price), 1, maxStack)))
					end,
				}),
			},
		}),
		Button(scope, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(120, 48),
			Variant = "primary",
			Text = Text.T(scope, "shop.buy"),
			Disabled = locked,
			OnClick = function()
				if Fusion.peek(locked) then
					return
				end
				local n = amount()
				task.spawn(function()
					local ok, err = Net.Invoke("Buy", npcId, key, n)
					if ok then
						Sounds.play("click")
						Toast.push(
							Text.now("shop.bought", { name = ItemText.name(entry.item, nil, entry.el), n = n }),
							"success",
							2
						)
					else
						Sounds.play("error")
						Toast.push(Text.now(err or "error.internal", { level = requiredLevel }), "error")
					end
				end)
			end,
		}),
	}
end

-- One group of the Buy grid: a small header (`shop.group.<id>`) over its icons, wrapping in rows.
local function buyGroup(
	s: Scope,
	use: Fusion.Use,
	shop: Shops.ShopDef,
	group: ShopGroups.Group,
	order: number,
	chosen: Fusion.Value<string?>
): Instance
	local cells = {}
	for i, entry in group.entries do
		table.insert(cells, buyCell(s, shop, entry, i, chosen))
	end
	return s:New("Frame")({
		Name = `Group_{group.id}`,
		LayoutOrder = order,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		[Children] = {
			s:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),
			s:New("TextLabel")({
				Name = "Header",
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 24),
				BackgroundTransparency = 1,
				Text = Text.get(use, `shop.group.{group.id}`),
				FontFace = Theme.Fonts.Display,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Paper.Heading,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			s:New("Frame")({
				Name = "Icons",
				LayoutOrder = 2,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIGridLayout")({
						CellSize = UDim2.fromOffset(CELL, CELL),
						CellPadding = UDim2.fromOffset(4, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					cells :: any,
				},
			}),
		},
	})
end

-- S95: "Gear for your class is sold by X, where." with "Guide me", at another class's vendor and at the dealer;
-- nil at the player's own vendor or without a class.
local function vendorBar(
	s: Scope,
	use: Fusion.Use,
	shopId: string,
	guide: (npcId: string) -> (),
	order: number
): Instance?
	local vendorId = Shops.vendorOf(State.Get({ "character", "class" }))
	local vendor = vendorId and Npcs.get(vendorId)
	if not vendorId or not vendor or vendorId == shopId then
		return nil
	end
	return s:New("Frame")({
		Name = "VendorBar",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = Theme.Paper.Raised,
		BackgroundTransparency = 0.3,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			-- who sells the player's gear, where they stand behind the "i"
			s:New("Frame")({
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -170, 1, 0),
				BackgroundTransparency = 1,
				[Children] = {
					s:New("UIListLayout")({
						FillDirection = Enum.FillDirection.Horizontal,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 6),
					}),
					s:New("TextLabel")({
						LayoutOrder = 1,
						Size = UDim2.new(),
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Text = Text.get(use, "shop.vendor.otherClass.short", { name = Text.get(use, vendor.nameKey) }),
						FontFace = Theme.Fonts.BodyMedium,
						TextSize = Theme.TextSize.Small,
						TextColor3 = Theme.Paper.Text,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						[Children] = s:New("UIFlexItem")({ FlexMode = Enum.UIFlexMode.Shrink }),
					}),
					InfoTip.new(s, {
						Text = Text.get(use, "shop.vendor.otherClass", {
							name = Text.get(use, vendor.nameKey),
							where = Text.get(use, `npc.{vendorId}.where`),
						}),
						LayoutOrder = 2,
					}),
				},
			}),
			Button(s, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				Size = UDim2.fromOffset(150, 40),
				Variant = "primary",
				Text = Text.get(use, "shop.vendor.guide"),
				TextSize = Theme.TextSize.Small,
				OnClick = function()
					guide(vendorId)
				end,
			}),
		},
	})
end

local function ShopWindow(scope: Scope, props: Props): Fusion.Child
	local openNpc = Fusion.peek(props.NpcId)
	local openNpcDef = openNpc and Npcs.get(openNpc)
	local openShop = openNpcDef and openNpcDef.shop and Shops.get(openNpcDef.shop)
	-- S95: the dealer sells nothing: no Buy tab, the window opens on Sell.
	local canBuy = not openShop or #openShop.entries > 0
	local tab = scope:Value(if canBuy then "buy" else "sell")
	local inventory = State.Value({ "character", "inventory" })
	local gold = State.Value({ "character", "gold" })
	local buyback = State.Value({ "buyback" })
	-- FIX 2026-10-15: the marks live on the backpack slots ("inv:N" -> uid), shared through DragDrop.
	local selected = DragDrop.Marked
	selected:set({})

	local npcId = scope:Computed(function(use): string?
		return use(props.NpcId)
	end)
	-- FIX 2026-10-14: the entry key picked in the Buy grid (the buy bar shows it).
	local chosen = scope:Value(nil :: string?)

	local sellTotal = scope:Computed(function(use): number
		local inv = use(inventory) or {}
		local total = 0
		for slotId, uid in use(selected) do
			local item = inv[string.sub(slotId, 5)]
			if item and item.uid == uid then
				total += ItemRoll.sellPrice(item)
			end
		end
		return total
	end)
	local markedCount = scope:Computed(function(use): number
		local n = 0
		for _ in use(selected) do
			n += 1
		end
		return n
	end)

	-- S134f: items dropped faster than the Sell rate limit are queued (key -> uid), marked and sold as one batch
	-- after a short pause instead of bouncing back with "rate limited".
	local queued: { [string]: string } = {}
	local flushPending = false
	local sellKeys: (keys: { string }) -> ()
	local function queueSale(keys: { string })
		local inv = Fusion.peek(inventory) or {}
		local marks = table.clone(Fusion.peek(selected))
		for _, key in keys do
			local item = inv[key]
			if item then
				queued[key] = item.uid
				marks[`inv:{key}`] = item.uid
			end
		end
		selected:set(marks)
		if flushPending then
			return
		end
		flushPending = true
		task.delay(SELL_RETRY, function()
			flushPending = false
			local current = Fusion.peek(inventory) or {}
			local again = {}
			for key, uid in queued do
				local item = current[key]
				if item and item.uid == uid then
					table.insert(again, key)
				end
			end
			table.clear(queued)
			if #again > 0 then
				sellKeys(again)
			end
		end)
	end

	-- Sells backpack slots (keys "1".."N"): the selection, or one item dropped on the window (S17).
	function sellKeys(keys: { string })
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
				if Rarities.get(item.rarity).valuable then
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
			if not ok and err == "error.rateLimited" then
				queueSale(keys)
				return true, nil
			end
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

	-- Quick sell (S20, S30): every Common (or Common and Unique) item, after a confirmation.
	local function quickSell(maxRarity: number)
		local id = Fusion.peek(npcId)
		if not id then
			return
		end
		props.ShowModal({
			Title = Text.now("shop.sellAll.title"),
			Message = Text.now("shop.sellAll.message"),
			ConfirmText = Text.now("shop.sell"),
			CancelText = Text.now("common.cancel"),
			Variant = "danger",
			OnConfirm = function(): (boolean, string?)
				local ok, err, total = Net.Invoke("SellAll", id, maxRarity)
				if ok then
					selected:set({})
					Sounds.play("click")
					Toast.push(Text.now("shop.sold", { gold = Format.number(total or 0) }), "success")
					return true, nil
				end
				return false, Text.now(err or "error.internal")
			end,
		})
	end

	local function sellSelected()
		local keys = {}
		for slotId in Fusion.peek(selected) do
			table.insert(keys, string.sub(slotId, 5))
		end
		sellKeys(keys)
	end

	local function unmark(slotId: string)
		local copy = table.clone(Fusion.peek(selected))
		copy[slotId] = nil
		selected:set(copy)
	end

	-- A click on a backpack slot while the Sell tab is open toggles its mark (locked items say why not).
	DragDrop.MarkHandler = function(slotId: string): boolean
		if Fusion.peek(tab) ~= "sell" then
			return false
		end
		local inv = Fusion.peek(inventory) or {}
		local item = inv[string.sub(slotId, 5)]
		if not item then
			return false
		end
		local copy = table.clone(Fusion.peek(selected))
		if copy[slotId] then
			copy[slotId] = nil
		elseif item.locked then
			Toast.push(Text.now("shop.error.locked"), "warning")
			return true
		else
			copy[slotId] = item.uid
		end
		selected:set(copy)
		return true
	end
	-- Marks follow the items: a slot whose item changed (sold, moved, sorted) loses its mark; leaving Sell clears them.
	scope:Observer(inventory):onChange(function()
		local inv = Fusion.peek(inventory) or {}
		local copy = {}
		local changed = false
		for slotId, uid in Fusion.peek(selected) do
			local item = inv[string.sub(slotId, 5)]
			if item and item.uid == uid then
				copy[slotId] = uid
			else
				changed = true
			end
		end
		if changed then
			selected:set(copy)
		end
	end)
	scope:Observer(tab):onChange(function()
		if Fusion.peek(tab) ~= "sell" then
			selected:set({})
		end
	end)

	-- Dragging (or tapping, after selecting it) a backpack item onto the drop zone sells it.
	DragDrop.SellHandler = function(index: number)
		sellKeys({ tostring(index) })
	end
	-- While the window is open, backpack tooltips add "Sells for: X gold" (S31).
	ItemTooltip.setMerchantOpen(true)
	table.insert(scope, function()
		DragDrop.SellHandler = nil
		DragDrop.MarkHandler = nil
		DragDrop.Marked:set({})
		ItemTooltip.setMerchantOpen(false)
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
			return if use(DragDrop.Dragging) ~= nil then Theme.Paper.Rule else Theme.Paper.Surface
		end),
		BackgroundTransparency = 0.3,
		Text = Text.T(scope, "shop.dropToSell"),
		FontFace = Theme.Fonts.BodyMedium,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Paper.Text,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({ Color = Theme.Paper.Rule, Thickness = 1, Transparency = 0.3 }),
		},
	})
	DragDrop.register(scope, dropZone :: any, "shopsell:zone")

	local content = scope:Computed(function(use, s: Scope): { Instance }
		local current = use(tab)
		local id = use(npcId)
		local npc = id and Npcs.get(id)
		local shop = npc and npc.shop and Shops.get(npc.shop)
		if current == "buy" then
			-- FIX 2026-10-14: icons in groups by kind (Logic/ShopGroups), no list rows; the name and the stats are in
			-- the tooltip, the picked item in the buy bar. S95: a class vendor lists every tier of its gear (the
			-- tiers ascend inside each group); its header and "who sells your gear" bar stay on top.
			local rows = {}
			if shop and id then
				local entries: { Shops.Entry } = {}
				if shop.class then
					entries = shop.entries
					table.insert(
						rows,
						s:New("TextLabel")({
							Name = "VendorHeader",
							LayoutOrder = -3,
							Size = UDim2.new(1, 0, 0, 30),
							BackgroundTransparency = 1,
							Text = Text.get(
								use,
								"shop.vendor.header",
								{ class = Text.get(use, `class.{shop.class}.name`) }
							),
							FontFace = Theme.Fonts.Display,
							TextSize = Theme.TextSize.Large,
							TextColor3 = Theme.Paper.Heading,
							TextXAlignment = Enum.TextXAlignment.Left,
						})
					)
					local bar = vendorBar(s, use, shop.id, props.Guide, -2)
					if bar then
						table.insert(rows, bar)
					end
				else
					local classId = State.Get({ "character", "class" }) or ""
					for _, entry in shop.entries do
						if ShopPrice.offered(entry, classId) then
							table.insert(entries, entry)
						end
					end
				end
				for order, group in ShopGroups.group(entries) do
					table.insert(rows, buyGroup(s, use, shop, group, order, chosen))
				end
			end
			return rows
		elseif current == "sell" then
			-- S95: the dealer (no gear of its own) points to the player's class vendor.
			local bar = if shop and #shop.entries == 0 then vendorBar(s, use, shop.id, props.Guide, -1) else nil
			local list = {
				s:New("TextLabel")({
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 24),
					AutomaticSize = Enum.AutomaticSize.Y,
					TextWrapped = true,
					BackgroundTransparency = 1,
					Text = Text.get(use, "shop.sellHint"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.TextMuted,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				s:New("Frame")({
					Name = "QuickSell",
					LayoutOrder = 0,
					Size = UDim2.new(1, 0, 0, 44),
					BackgroundTransparency = 1,
					[Children] = {
						s:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							Padding = UDim.new(0, 8),
						}),
						Button(s, {
							Text = Text.get(use, "shop.sellAllCommon"),
							TextSize = Theme.TextSize.Small,
							Size = UDim2.fromOffset(230, 40),
							OnClick = function()
								quickSell(Rarities.COMMON)
							end,
						}),
						Button(s, {
							Text = Text.get(use, "shop.sellAllUncommon"),
							TextSize = Theme.TextSize.Small,
							Size = UDim2.fromOffset(250, 40),
							OnClick = function()
								quickSell(QUICK_SELL_MAX)
							end,
						}),
					},
				}),
			}
			if bar then
				table.insert(list, bar)
			end
			-- What is marked in the backpack (a click here removes the mark). S134f: the tab is built once; only
			-- this list follows the marks, and through per-slot state values only the marked slots (not the whole
			-- backpack), so a sale no longer rebuilds the tab.
			local marked = s:Computed(function(use2): { number }
				local out = {}
				for slotId, uid in use2(selected) do
					local key = string.sub(slotId, 5)
					local index = tonumber(key)
					local item = use2(State.Value({ "character", "inventory", key }))
					if index and item and item.uid == uid then
						table.insert(out, index)
					end
				end
				table.sort(out)
				return out
			end)
			local grid = s:Computed(function(use2, s2: Scope): { Instance }
				local cells = {}
				for _, index in use2(marked) do
					local key = tostring(index)
					table.insert(
						cells,
						SelectableSlot(s2, {
							Id = `sell:{key}`,
							LayoutOrder = index,
							TooltipCtx = { merchantOpen = true },
							Item = State.Value({ "character", "inventory", key }),
							Selected = true,
							OnToggle = function()
								unmark(`inv:{key}`)
							end,
						})
					)
				end
				return cells
			end)
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					Text = s:Computed(function(use2): string
						local n = #use2(marked)
						return Text.get(use2, if n == 0 then "shop.markedNone" else "shop.marked", { n = n })
					end),
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Paper.Text,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
			)
			table.insert(
				list,
				s:New("Frame")({
					LayoutOrder = 2,
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
						BackgroundColor3 = Theme.Paper.Raised,
						BackgroundTransparency = 0.4,
						[Children] = {
							s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
							ItemSlot(s, {
								SlotId = `view:buyback:{i}`,
								Item = entry.item,
								Size = 56,
								Position = UDim2.fromOffset(7, (ROW - 56) / 2),
								TooltipCtx = { hints = false, merchantOpen = false },
							}),
							s:New("TextLabel")({
								Position = UDim2.fromOffset(74, 8),
								Size = UDim2.new(1, -220, 0, 26),
								BackgroundTransparency = 1,
								Text = ItemText.get(use, entry.item.id, entry.item.up),
								FontFace = Theme.Fonts.BodyBold,
								TextSize = Theme.TextSize.Body,
								TextColor3 = ItemText.rarityName(entry.item.rarity, "paper"),
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
								TextColor3 = Theme.Paper.Heading,
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
						TextColor3 = Theme.Paper.TextMuted,
					})
				)
			end
			return rows
		end
	end)

	local listFrame = scope:New("ScrollingFrame")({
		Name = "List",
		Position = UDim2.fromOffset(0, 50),
		Size = scope:Computed(function(use): UDim2
			local current = use(tab)
			return UDim2.new(
				1,
				0,
				1,
				if current == "sell" then -110 elseif current == "buy" then -(100 + BUY_BAR + 6) else -100
			)
		end),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Paper.Label,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}),
			scope:New("UIPadding")({ PaddingRight = UDim.new(0, 10) }),
			content :: any,
		},
	}) :: ScrollingFrame

	return {
		Tabs(scope, {
			Selected = tab,
			Tabs = if canBuy
				then {
					{ id = "buy", label = Text.T(scope, "shop.tab.buy") },
					{ id = "sell", label = Text.T(scope, "shop.tab.sell") },
					{ id = "buyback", label = Text.T(scope, "shop.tab.buyback") },
				}
				else {
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
			TextColor3 = Theme.Paper.Heading,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		listFrame,
		-- FIX 2026-10-14: the picked item of the Buy grid (name, price, quantity, Buy).
		scope:New("Frame")({
			Name = "BuyBar",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -50),
			Size = UDim2.new(1, 0, 0, BUY_BAR),
			BackgroundColor3 = Theme.Paper.Raised,
			BackgroundTransparency = 0.4,
			Visible = scope:Computed(function(use): boolean
				return use(tab) == "buy"
			end),
			[Children] = {
				scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
				scope:New("UIPadding")({
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
				scope:Computed(function(use, s: Scope): { Instance }
					local id = use(npcId)
					local npc = id and Npcs.get(id)
					local shop = npc and npc.shop and Shops.get(npc.shop)
					local key = use(chosen)
					local picked: Shops.Entry? = nil
					if shop and key then
						for _, entry in shop.entries do
							if (entry.key or entry.item) == key then
								picked = entry
								break
							end
						end
					end
					if not shop or not id then
						return {}
					end
					return buyBar(s, use, id, shop, picked)
				end) :: any,
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
					TextColor3 = Theme.Paper.Heading,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Button(scope, {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.fromOffset(240, 50),
					Variant = "primary",
					Text = scope:Computed(function(use): string
						return Text.get(use, "shop.sellMarked", { n = use(markedCount) })
					end),
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
