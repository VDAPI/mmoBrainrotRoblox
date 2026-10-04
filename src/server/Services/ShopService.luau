--!strict
-- NPC trade (DESIGN §9, §13, §18): buying from Data/Shops, selling any item to any trader (sell price from
-- ItemRoll.sellPrice), buying back the last 10 sold items (session only, state branch `buyback`), the
-- healer's free restore in the city and the backpack merchant's "buy and equip".
-- Every operation validates the NPC distance and changes data in one step (ARCHITECTURE §10).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local Rarities = require(Shared.Data.Rarities)
local ShopPrice = require(Shared.Logic.ShopPrice)
local Shops = require(Shared.Data.Shops)
local Types = require(Shared.Types)

local log = Log.new("ShopService")

local ShopService = {
	Name = "ShopService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"InventoryService",
		"NpcService",
		"ResourceService",
		"StatService",
	},
}

type ItemInstance = Types.ItemInstance

local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local NpcService: any
local ResourceService: any
local StatService: any

-- Last sold items per player (newest first): { item, price }.
local buyback: { [Player]: { { item: ItemInstance, price: number } } } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function addGold(player: Player, delta: number)
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return math.max(0, gold + delta)
	end)
	Analytics.gold(player, delta, balance, "shop")
end

local function publishBuyback(player: Player)
	local list = {}
	local entries: { { item: ItemInstance, price: number } } = buyback[player] or {}
	for _, entry in entries do
		table.insert(list, { item = entry.item, price = entry.price })
	end
	PlayerStateService.Set(player, { "buyback" }, list)
end

-- Unit price of a shop entry for this character (guild potion discount included).
function ShopService.Price(player: Player, entry: Shops.Entry, char: Types.CharacterData): number
	return ShopPrice.unit(entry, char.level, StatService.GetValue(player, "potionDiscount"))
end

local function shopOf(npcId: string): Shops.ShopDef?
	local npc = Npcs.get(npcId)
	return if npc and npc.shop then Shops.get(npc.shop) else nil
end

local function buy(player: Player, npcId: string, itemId: string, n: number): (boolean, string?)
	local char = character(player)
	local shop = shopOf(npcId)
	if not char or not shop then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local entry: Shops.Entry? = nil
	for _, candidate in shop.entries do
		if candidate.item == itemId then
			entry = candidate
		end
	end
	local def = Items.get(itemId)
	if not entry or not def then
		return false, "shop.error.notSold"
	end
	local count = math.clamp(n, 1, def.maxStack)
	local total = ShopService.Price(player, entry, char) * count
	if char.gold < total then
		return false, "shop.error.gold"
	end
	local item = ItemRoll.makeStack(itemId, count, InventoryService.NewUid())
	if not InventoryService.CanFit(player, { item }) then
		return false, "inventory.full"
	end
	addGold(player, -total)
	InventoryService.AddItem(player, item)
	return true, nil
end

local function sell(player: Player, npcId: string, indices: { any }): (boolean, string?, number?)
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char or not shopOf(npcId) then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local seen: { [number]: boolean } = {}
	local total = 0
	local sold = 0
	local list = buyback[player] or {}
	buyback[player] = list
	for i, raw in indices do
		if i > 200 then
			break
		end
		local index = tonumber(raw)
		if index and index == math.floor(index) and not seen[index] then
			seen[index] = true
			local item = InventoryService.Get(player, index)
			if item then
				local price = ItemRoll.sellPrice(item)
				InventoryService.SetSlot(player, index, nil)
				total += price
				sold += 1
				table.insert(list, 1, { item = item, price = price })
			end
		end
	end
	if sold == 0 then
		return false, "shop.error.nothing"
	end
	while #list > Shops.BUYBACK_SIZE do
		table.remove(list)
	end
	addGold(player, total)
	publishBuyback(player)
	log:info("%s sold %d items for %d gold", player.Name, sold, total)
	return true, nil, total
end

local function buyBack(player: Player, npcId: string, index: number): (boolean, string?)
	local char = character(player)
	local list = buyback[player]
	local entry = list and list[index]
	if not char or not entry or not shopOf(npcId) then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	if char.gold < entry.price then
		return false, "shop.error.gold"
	end
	if not InventoryService.CanFit(player, { entry.item }) then
		return false, "inventory.full"
	end
	table.remove(list, index)
	addGold(player, -entry.price)
	InventoryService.AddItem(player, entry.item)
	publishBuyback(player)
	return true, nil
end

local function healMe(player: Player, npcId: string): (boolean, string?)
	local npc = Npcs.get(npcId)
	if not npc or not table.find(npc.services, "heal") then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	ResourceService.Restore(player)
	return true, nil
end

-- Backpack merchant: pays, equips the new backpack and puts the old one into the (bigger) backpack.
local function buyBackpack(player: Player, npcId: string, itemId: string): (boolean, string?)
	local char = character(player)
	local npc = Npcs.get(npcId)
	local def = Items.get(itemId)
	if not char or not npc or not table.find(npc.services, "backpacks") or not def or def.category ~= "backpack" then
		return false, "error.badRequest"
	end
	if not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	if char.level < def.level then
		return false, "shop.error.level"
	end
	local price = def.buyPrice or 0
	if char.gold < price then
		return false, "shop.error.gold"
	end
	local capacity = def.capacity or 0
	local old = char.equipment.backpack
	local needed = Inventory.used(char.inventory) + (if old then 1 else 0)
	if needed > capacity then
		return false, "equip.error.backpackFit"
	end
	addGold(player, -price)
	local backpack = ItemRoll.makeStack(itemId, 1, InventoryService.NewUid())
	backpack.bound = true
	Inventory.compact(char.inventory, capacity)
	PlayerStateService.Set(player, { "character", "equipment", "backpack" }, backpack)
	InventoryService.SyncAll(player)
	if old then
		InventoryService.AddItem(player, old)
	end
	return true, nil
end

-- Sell price helper for the client preview (also used by rarity confirmations).
function ShopService.IsValuable(item: ItemInstance): boolean
	return item.rarity >= Rarities.EPIC
end

function ShopService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	ResourceService = registry.Get("ResourceService")
	StatService = registry.Get("StatService")
end

function ShopService.Start()
	Net.Handle("Buy", buy)
	Net.Handle("Sell", sell)
	Net.Handle("Buyback", buyBack)
	Net.Handle("HealMe", healMe)
	Net.Handle("BuyBackpack", buyBackpack)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		buyback[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "buyback" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		buyback[player] = nil
	end)
end

return ShopService
