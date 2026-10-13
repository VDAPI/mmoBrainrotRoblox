--!strict
-- Shop window (DESIGN §9, §18): Buy (icon, name, price, quantity with −/+/Max), Sell (click backpack items to
-- select, total, confirmation for Epic and better) and Buy back (last 10 sold). Gold always visible.
-- S31: rows show a third line with the item's stats (TooltipModel.statLine, required level red when too high) and
-- the price of ItemValue.buyPrice (the tooltip shows the same price). S95: a class vendor (shop.class) lists every
-- tier (5, 15 ... 95) under "Level 15 · Reinforced" headers with a slot filter, scrolled to the player's tier; rows
-- above the character's level show a red "Requires level N" and a disabled "Buy", gear another class wears shows
-- "Only for: ..." and a disabled "Buy" (the server refuses it too). Another class's vendor and the dealer (no
-- entries: no Buy tab) show who sells the player's gear, with "Guide me". Vendor rows are built lazily.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local DragDrop = require(script.Parent.Parent.DragDrop)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ItemRoll = require(ReplicatedStorage.Shared.Logic.ItemRoll)
local ItemSlot = require(script.Parent.Parent.Components.ItemSlot)
local ItemTooltip = require(script.Parent.Parent.Components.ItemTooltip)
local ItemText = require(script.Parent.Parent.ItemText)
local ItemValue = require(ReplicatedStorage.Shared.Logic.ItemValue)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Items = require(ReplicatedStorage.Shared.Data.Items)
local Net = require(ReplicatedStorage.Shared.Net)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local Potions = require(ReplicatedStorage.Shared.Logic.Potions)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local Scale = require(script.Parent.Parent.Scale)
local SelectableSlot = require(script.Parent.Parent.Components.SelectableSlot)
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

local ROW = 76
-- Lazy rows (class vendors): rows within this many pixels of the visible part of the list are built.
local LAZY_MARGIN = 400
local RED_HEX = "#" .. Theme.Colors.DangerHover:ToHex()

-- Highest rarity the "sell all" buttons may include (S30: the `quickSell` rarities, Common and Unique).
-- S95: slot filter of the class vendors (armour = helmet, chest, gloves, boots).
local FILTERS: { string } = { "all", "weapon", "offhand", "armor" }
local FILTER_OF: { [string]: string } =
	{ weapon = "weapon", offhand = "offhand", helmet = "armor", armor = "armor", gloves = "armor", boots = "armor" }

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

-- Third line of a row: the stats summary, the required level in red when the character is below it.
local function statsText(use: Fusion.Use, item: Types.ItemInstance): string
	local lang = use(Text.Lang)
	local line = TooltipModel.statLine(item, nil, lang)
	if not line then
		return ""
	end
	local required = ItemRoll.requiredLevel(item)
	if required > (use(State.Value({ "character", "level" })) or 1) then
		local levelPart = Locale.T("itemLine.level", { level = required }, lang)
		local at = string.find(line, levelPart, 1, true)
		if at then
			line = string.sub(line, 1, at - 1)
				.. `<font color="{RED_HEX}">{levelPart}</font>`
				.. string.sub(line, at + #levelPart)
		end
	end
	return line
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

local function buyRow(scope: Scope, npcId: string, shop: Shops.ShopDef, entry: Shops.Entry, order: number): Instance
	local def = Items.get(entry.item)
	local key = entry.key or entry.item
	local quantity = scope:Value("1")
	local maxStack = if def then def.maxStack else 1
	local item = preview(entry)
	-- Text column width: stackable rows keep room for the quantity controls.
	local textWidth = if maxStack > 1 then -380 else -214
	local level = State.Value({ "character", "level" })
	-- S87: the entry's level or the potion's (Great 45, Mighty 70), the same expression as ShopService.buy
	local requiredLevel = math.max(entry.level or 1, Potions.requiredLevel(def))
	-- S95: gear of another class can be browsed, not bought (ShopService refuses it with shop.error.class)
	local classLocked = not ShopPrice.usableBy(entry, State.Get({ "character", "class" }))
	local locked = scope:Computed(function(use): boolean
		return classLocked or requiredLevel > (use(level) or 1)
	end)
	local function amount(): number
		return math.clamp(tonumber(Fusion.peek(quantity)) or 1, 1, maxStack)
	end
	return scope:New("Frame")({
		Name = key,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.4,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			ItemSlot(scope, {
				SlotId = `view:shop:{key}`,
				Item = item,
				Size = 56,
				Position = UDim2.fromOffset(7, (ROW - 56) / 2),
				TooltipCtx = function(): TooltipModel.Ctx?
					return {
						shop = shop,
						shopEntry = entry,
						potionDiscount = State.Get({ "derived", "values", "potionDiscount" }) or 0,
						merchantOpen = false,
						hints = false,
					}
				end,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(74, 5),
				Size = UDim2.new(1, textWidth, 0, 24),
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					return ItemText.get(use, entry.item, nil, entry.el)
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = ItemText.rarityTextColor(item.rarity),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(74, 30),
				Size = UDim2.new(1, textWidth, 0, 20),
				BackgroundTransparency = 1,
				RichText = true,
				Text = scope:Computed(function(use): string
					use(level)
					use(State.Value({ "derived", "values", "potionDiscount" }))
					local price = Text.get(use, "shop.price", { price = Format.number(priceOf(entry, shop)) })
					if classLocked then
						local names = {}
						local classes: { string } = entry.classes or {}
						for _, classId in classes do
							table.insert(names, Text.get(use, `class.{classId}.name`))
						end
						local only = Text.get(use, "shop.onlyFor", { classes = table.concat(names, ", ") })
						return `{price}   <font color="{RED_HEX}">{only}</font>`
					end
					if use(locked) then
						local need = Text.get(use, "shop.requiresLevel", { level = requiredLevel })
						return `{price}   <font color="{RED_HEX}">{need}</font>`
					end
					return price
				end),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.GoldBright,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			scope:New("TextLabel")({
				Name = "Stats",
				Position = UDim2.fromOffset(74, 52),
				Size = UDim2.new(1, textWidth, 0, 18),
				BackgroundTransparency = 1,
				RichText = true,
				Text = scope:Computed(function(use): string
					return statsText(use, item)
				end),
				FontFace = Theme.Fonts.Body,
				TextSize = 14,
				TextColor3 = Theme.Colors.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
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
							local price = math.max(1, priceOf(entry, shop))
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
		BackgroundColor3 = Theme.Colors.PanelRaised,
		BackgroundTransparency = 0.3,
		[Children] = {
			s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			s:New("TextLabel")({
				Position = UDim2.fromOffset(10, 0),
				Size = UDim2.new(1, -170, 1, 0),
				BackgroundTransparency = 1,
				Text = Text.get(use, "shop.vendor.otherClass", {
					name = Text.get(use, vendor.nameKey),
					where = Text.get(use, `npc.{vendorId}.where`),
				}),
				FontFace = Theme.Fonts.BodyMedium,
				TextSize = Theme.TextSize.Small,
				TextColor3 = Theme.Colors.Parchment,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
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
	local selected = scope:Value({} :: { [string]: boolean })

	local npcId = scope:Computed(function(use): string?
		return use(props.NpcId)
	end)
	-- S95: slot filter of the class vendors and the NPC it was chosen at ("all" at another NPC).
	local filter = scope:Value({ npc = openNpc, slot = "all" } :: { npc: string?, slot: string })
	local playerLevel = State.Value({ "character", "level" })

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
		for key in Fusion.peek(selected) do
			table.insert(keys, key)
		end
		sellKeys(keys)
	end

	-- Dragging (or tapping, after selecting it) a backpack item onto the drop zone sells it.
	DragDrop.SellHandler = function(index: number)
		sellKeys({ tostring(index) })
	end
	-- While the window is open, backpack tooltips add "Sells for: X gold" (S31).
	ItemTooltip.setMerchantOpen(true)
	table.insert(scope, function()
		DragDrop.SellHandler = nil
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

	-- Lazy rows of the class vendor list: placeholders of the row's height, filled when they come near the view.
	local list: ScrollingFrame? = nil
	-- `y` = the row's canvas offset in virtual pixels (the layout is fixed: known heights and padding), so the
	-- check does not depend on when the layout pass runs.
	local pending: { { y: number, build: () -> () } } = {}
	-- Canvas offset (virtual pixels) of the player's tier header, applied once the canvas is tall enough.
	local scrollTarget: number? = nil
	local scrollTries = 0
	local function fillVisible()
		local frame = list
		if not frame or #pending == 0 or frame.AbsoluteSize.Y <= 0 then
			return
		end
		-- CanvasPosition is in unscaled (virtual) pixels; the visible height is AbsoluteSize / UI scale.
		local height = frame.AbsoluteSize.Y / math.max(0.1, Scale.get())
		local top = frame.CanvasPosition.Y - LAZY_MARGIN
		local bottom = frame.CanvasPosition.Y + height + LAZY_MARGIN
		local i = 1
		while i <= #pending do
			local p = pending[i]
			if p.y + ROW >= top and p.y <= bottom then
				table.remove(pending, i)
				p.build()
			else
				i += 1
			end
		end
	end
	local function applyScroll()
		local frame = list
		local target = scrollTarget
		if not frame or not target then
			return
		end
		frame.CanvasPosition = Vector2.new(0, target)
		scrollTries += 1
		-- The automatic canvas grows after the layout pass; retry until the position sticks.
		if frame.CanvasPosition.Y >= target - 1 or scrollTries > 8 then
			scrollTarget = nil
		end
	end
	-- After a rebuild: scroll to the player's tier header, then fill what is visible.
	local function afterBuild()
		task.defer(function()
			applyScroll()
			fillVisible()
		end)
	end

	local content = scope:Computed(function(use, s: Scope): { Instance }
		local current = use(tab)
		local id = use(npcId)
		local npc = id and Npcs.get(id)
		local shop = npc and npc.shop and Shops.get(npc.shop)
		pending = {}
		scrollTarget = nil
		scrollTries = 0
		if current == "buy" then
			local rows = {}
			if shop and id and shop.class then
				local chosenFor = use(filter)
				local chosen = if chosenFor.npc == id then chosenFor.slot else "all"
				-- Canvas offset of the next element (list padding 6).
				local offset = 0
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
						FontFace = Theme.Fonts.Heading,
						TextSize = 22,
						TextColor3 = Theme.Colors.Gold,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
				)
				offset += 30 + 6
				local bar = vendorBar(s, use, shop.id, props.Guide, -2)
				if bar then
					table.insert(rows, bar)
					offset += 48 + 6
				end
				local slots: { [string]: boolean } = {}
				for _, entry in shop.entries do
					local def = Items.get(entry.item)
					slots[FILTER_OF[def and def.slot or ""] or ""] = true
				end
				local filters = {}
				for order, filterId in FILTERS do
					if filterId ~= "all" and not slots[filterId] then
						continue -- no empty filter (a class without off-hands)
					end
					table.insert(
						filters,
						Button(s, {
							LayoutOrder = order,
							Text = Text.get(use, `shop.filter.{filterId}`),
							TextSize = Theme.TextSize.Small,
							Size = UDim2.fromOffset(130, 40),
							Variant = if chosen == filterId then "primary" else "secondary",
							OnClick = function()
								filter:set({ npc = id, slot = filterId })
							end,
						})
					)
				end
				table.insert(
					rows,
					s:New("Frame")({
						Name = "SlotFilter",
						LayoutOrder = -1,
						Size = UDim2.new(1, 0, 0, 44),
						BackgroundTransparency = 1,
						[Children] = {
							s:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								Padding = UDim.new(0, 6),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							filters :: any,
						},
					})
				)
				offset += 44 + 6
				-- S31: every tier (Shops.WEAPONSMITH_TIERS) under its header; the list opens at the highest tier
				-- the character can use (the first one below level 5).
				local alive = true
				table.insert(s, function()
					alive = false
				end)
				local lvl = Fusion.peek(playerLevel) or 1
				local targetTier = Shops.WEAPONSMITH_TIERS[1]
				for _, tier in Shops.WEAPONSMITH_TIERS do
					if tier <= lvl then
						targetTier = tier
					end
				end
				local byTier: { [number]: { { entry: Shops.Entry, index: number } } } = {}
				for i, entry in shop.entries do
					local def = Items.get(entry.item)
					if chosen == "all" or FILTER_OF[def and def.slot or ""] == chosen then
						local tier = entry.level or 0
						byTier[tier] = byTier[tier] or {}
						table.insert(byTier[tier], { entry = entry, index = i })
					end
				end
				local order = 0
				for _, tier in Shops.WEAPONSMITH_TIERS do
					local group = byTier[tier]
					if not group then
						continue
					end
					order += 1
					local header = s:New("Frame")({
						Name = `Tier{tier}`,
						LayoutOrder = order,
						Size = UDim2.new(1, 0, 0, 34),
						BackgroundTransparency = 1,
						[Children] = {
							s:New("TextLabel")({
								Position = UDim2.fromOffset(4, 6),
								Size = UDim2.new(1, -8, 0, 26),
								BackgroundTransparency = 1,
								Text = Text.get(use, "shop.tierHeader", {
									level = tier,
									name = Text.get(use, `itemTier.{tier}.m`),
								}),
								FontFace = Theme.Fonts.Heading,
								TextSize = 20,
								TextColor3 = s:Computed(function(use2): Color3
									return if tier > (use2(playerLevel) or 1)
										then Theme.Colors.TextMuted
										else Theme.Colors.GoldBright
								end),
								TextXAlignment = Enum.TextXAlignment.Left,
							}),
							s:New("Frame")({
								AnchorPoint = Vector2.new(0, 1),
								Position = UDim2.fromScale(0, 1),
								Size = UDim2.new(1, 0, 0, 1),
								BackgroundColor3 = Theme.Colors.GoldDim,
								BackgroundTransparency = 0.5,
								BorderSizePixel = 0,
							}),
						},
					}) :: Frame
					table.insert(rows, header)
					if tier == targetTier and tier ~= Shops.WEAPONSMITH_TIERS[1] then
						scrollTarget = offset
					end
					offset += 34 + 6
					for _, row in group do
						order += 1
						local holder = s:New("Frame")({
							Name = row.entry.key or row.entry.item,
							LayoutOrder = order,
							Size = UDim2.new(1, 0, 0, ROW),
							BackgroundTransparency = 1,
						}) :: Frame
						table.insert(rows, holder)
						table.insert(pending, {
							y = offset,
							build = function()
								if alive then
									local built = buyRow(s, id, shop, row.entry, 0) :: any
									built.Parent = holder
								end
							end,
						})
						offset += ROW + 6
					end
				end
				afterBuild()
			elseif shop and id then
				local classId = State.Get({ "character", "class" }) or ""
				for i, entry in shop.entries do
					if ShopPrice.offered(entry, classId) then
						table.insert(rows, buyRow(s, id, shop, entry, i))
					end
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
					BackgroundTransparency = 1,
					Text = Text.get(use, "shop.sellHint"),
					FontFace = Theme.Fonts.Body,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Colors.TextMuted,
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
						TooltipCtx = { merchantOpen = true },
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

	local listFrame = scope:New("ScrollingFrame")({
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
	}) :: ScrollingFrame
	list = listFrame
	table.insert(scope, listFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(fillVisible))
	table.insert(scope, listFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fillVisible))
	table.insert(
		scope,
		listFrame:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			applyScroll()
			fillVisible()
		end)
	)

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
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
		listFrame,
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
