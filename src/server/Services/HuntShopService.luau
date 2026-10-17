--!strict
-- The Huntmaster's shop (S134k, docs/DESIGN-15.md §3.3, Data/HuntShop): Hunter's Marks (character.quests.contract
-- .marks, paid by the hunting contracts) buy potions, stones, Fortune blessings, essence with a weekly limit, chests with
-- one Unique / Heroic item for the class and cosmetics. One purchase: near the Huntmaster, Logic/HuntShop.canBuy (the
-- window's rule), room in the backpack (a full backpack refuses before anything is paid); then, without a yield, the
-- marks and the weekly counter go and the bound items (or the cosmetic) come. A chest rolls its item at once, like the
-- day 7 chest of the login reward (Logic/LoginReward.rollItem).
--   HuntShopBuy(npcId, key, amount)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Clock = require(Shared.Util.Clock)
local Contracts = require(Shared.Logic.Contracts)
local Cosmetics = require(Shared.Data.Cosmetics)
local Data = require(Shared.Data.HuntShop)
local HuntShop = require(Shared.Logic.HuntShop)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local LoginReward = require(Shared.Logic.LoginReward)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)

local log = Log.new("HuntShopService")

local HuntShopService = {
	Name = "HuntShopService",
	Deps = { "PlayerStateService", "InventoryService", "NpcService", "CosmeticService", "DataService" },
}

local PlayerStateService: any
local InventoryService: any
local NpcService: any
local CosmeticService: any
local DataService: any

local rng = Rng.new()
local busy: { [Player]: boolean } = {}

local function maxStack(id: string): number
	local def = Items.get(id)
	return if def and def.stackable then def.maxStack or 1 else 1
end

local function buy(player: Player, npcId: string, key: string, amount: number): (boolean, string?)
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if npcId ~= Contracts.HUNTMASTER or not NpcService.Near(player, npcId) then
		return false, "huntshop.error.tooFar"
	end
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local entry = Data.byKey[key]
	local state = Contracts.stateOf(char.quests)
	local week = Time.weekNumber(Clock.now())
	local account = PlayerStateService.Get(player, { "account" })
	local owned = if type(account) == "table" and type(account.cosmetics) == "table"
		then account.cosmetics.owned
		else {}
	local ok, err = HuntShop.canBuy(entry, state, char.level, week, amount, owned)
	if not ok or not entry then
		return false, err
	end
	local items: { Types.ItemInstance } = {}
	local grant = HuntShop.grant(entry, char.level, char.class)
	if grant then
		local total = grant.n * amount
		if not Items.get(grant.id) or total > maxStack(grant.id) then
			return false, "error.badRequest"
		end
		local stack = ItemRoll.makeStack(grant.id, total, InventoryService.NewUid())
		stack.bound = true -- marks never turn into gold through trade or the auction house
		stack.ns = true -- nor through the merchant (ItemValue.canSell)
		table.insert(items, stack)
	elseif entry.kind == "chest" then
		local rarity = HuntShop.chestRarity(entry)
		local drop = if rarity then LoginReward.rollItem(char.level, char.class, rarity, rng) else nil
		if not drop then
			log:warn("no hunt chest item at level %d for %s", char.level, char.class)
			return false, "huntshop.error.chest"
		end
		local item =
			ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, rng, InventoryService.NewUid(), drop.forClass)
		item.bound = Data.CHEST_BOUND
		item.ns = true
		table.insert(items, item)
	elseif not Cosmetics.get(entry.id) then
		return false, "error.badRequest"
	end
	if #items > 0 and not InventoryService.CanFit(player, items) then
		return false, "inventory.full"
	end
	-- no yield from here: the marks and the counter, then the goods
	local wallet = Contracts.copy(state)
	local cost = HuntShop.priceAt(entry, char.level) * amount
	PlayerStateService.Set(player, { "character", "quests", "contract", "marks" }, state.marks - cost)
	PlayerStateService.Set(
		player,
		{ "character", "quests", "contract", "shopWeek" },
		HuntShop.counted(entry, wallet, week, amount)
	)
	for _, item in items do
		local left = InventoryService.AddItem(player, item)
		if left > 0 then
			log:warn("%s: %d x %s did not fit after CanFit", player.Name, left, item.id)
		end
	end
	if entry.kind == "cosmetic" then
		CosmeticService.Grant(player, entry.id)
	end
	Analytics.custom(player, `HuntShop_{entry.group}`, cost) -- a bounded name (S131)
	if entry.kind == "chest" then
		Net.Fire(player, "Toast", "huntshop.chestGot", { item = `#item:{items[1].id}:{items[1].up}` }, "success")
	end
	if #items > 0 then
		DataService.Save(player)
	end
	return true, nil
end

function HuntShopService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	CosmeticService = registry.Get("CosmeticService")
	DataService = registry.Get("DataService")
end

function HuntShopService.Start()
	Net.Handle("HuntShopBuy", function(player: Player, npcId: string, key: string, amount: number): (boolean, string?)
		if busy[player] then
			return false, "huntshop.error.busy"
		end
		busy[player] = true
		local ok, result, err = pcall(buy, player, npcId, key, amount)
		busy[player] = nil
		if not ok then
			log:error("hunt shop failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return HuntShopService
