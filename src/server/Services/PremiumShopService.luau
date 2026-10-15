--!strict
-- Premium shop for Dragon Shards (DESIGN §21, DESIGN-17 §1): scrolls with daily/weekly limits from Data/Products,
-- renaming the active character (NameService: filter + unique reservation) and cosmetics/pets (owned by the account).
-- S120: every shop entry goes through Logic/Premium.canBuy (the same rule as the shop window) and the limit counters
-- of account.shopLimits. Every purchase checks, pays and counts in one step without yielding between the check and
-- the change; renaming yields for the name store and checks again afterwards.
-- S122 (DESIGN-17 §3): item entries give `n` items (Elixir of Wholeness packs, bound from creation through
-- ItemRoll.makeStack); `lure` entries add real time to account.lure (Logic/Lure.extend, buying switches it on).
-- S123 (DESIGN-17 §4): a cosmetic costs Logic/WeeklyOffer.priceOf at Util/Clock.now() (the offer of the week, the
-- same clock as the window, /time moves both); a client that saw another price (the week changed in between) is
-- refused with premium.error.priceChanged before anything is paid. Starter packs: the grant handlers of
-- MonetizationService (Developer Products, once per account in account.packs): shards, the pack's cosmetics
-- (CosmeticService.Grant) and passes in the profile (MonetizationService.GrantProfilePass), without yielding. A pack
-- bought twice (two Roblox prompts racing) adds the shards only.
-- S131: analytics. The economy event keeps the entry key / cosmetic id as the SKU; the custom event name is bounded:
-- "PremiumSpend_<shop cat>" or "PremiumSpend_cosmetic_<kind>" (Roblox counts unique names). The shop funnel
-- (src/server/PremiumFunnel) gets "prompt" after the server check and "granted" after the purchase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Clock = require(Shared.Util.Clock)
local Cosmetics = require(Shared.Data.Cosmetics)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Lure = require(Shared.Logic.Lure)
local Net = require(Shared.Net)
local Premium = require(Shared.Logic.Premium)
local PremiumFunnel = require(script.Parent.Parent.PremiumFunnel)
local Products = require(Shared.Data.Products)
local Types = require(Shared.Types)
local WeeklyOffer = require(Shared.Logic.WeeklyOffer)

local log = Log.new("PremiumShopService")

local PremiumShopService = {
	Name = "PremiumShopService",
	-- S123: MonetizationService (starter pack handlers, passes in the profile), CosmeticService (Grant)
	Deps = {
		"DataService",
		"PlayerStateService",
		"InventoryService",
		"NameService",
		"MonetizationService",
		"CosmeticService",
	},
}

local DataService: any
local PlayerStateService: any
local InventoryService: any
local NameService: any
local MonetizationService: any
local CosmeticService: any

local busy: { [Player]: boolean } = {}

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

-- `sku` = the entry key or cosmetic id (economy SKU), `group` = a bounded name part (shop cat, cosmetic_<kind>).
local function spend(player: Player, price: number, sku: string, group: string)
	local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
		return shards - price
	end)
	Analytics.shards(player, -price, total, sku, true)
	Analytics.custom(player, "PremiumSpend_" .. group, price)
	PremiumFunnel.step(player, "shop", "granted")
end

-- S120: the limit counters after a purchase, in the same step as the payment (only entries with a limit write).
local function countLimit(player: Player, entry: Products.ShopEntry, data: Types.AccountData, now: number)
	if entry.dailyLimit or entry.weeklyLimit then
		PlayerStateService.Set(player, { "account", "shopLimits" }, Premium.countPurchase(entry, data, now))
	end
end

local function buyItem(player: Player, key: string): (boolean, string?)
	local data = account(player)
	local entry = Products.getShop(key)
	if not data or not entry or entry.kind ~= "item" or not entry.itemId then
		return false, "error.badRequest"
	end
	if not PlayerStateService.GetCharacter(player) then
		return false, "error.wrongPhase"
	end
	local now = os.time()
	local ok, err = Premium.canBuy(entry, data, now)
	if not ok then
		return false, err
	end
	local item = ItemRoll.makeStack(entry.itemId, entry.n or 1, InventoryService.NewUid())
	if not InventoryService.CanFit(player, { item }) then
		return false, "inventory.full"
	end
	PremiumFunnel.step(player, "shop", "prompt")
	spend(player, entry.price, key, entry.cat)
	countLimit(player, entry, data, now)
	InventoryService.AddItem(player, item)
	DataService.Save(player)
	return true, nil
end

-- S122: Cloak of Luring time (account, no character needed); checked, paid and added in one step.
local function buyLure(player: Player, key: string): (boolean, string?)
	local data = account(player)
	local entry = Products.getShop(key)
	if not data or not entry or entry.kind ~= "lure" or not entry.seconds or entry.seconds <= 0 then
		return false, "error.badRequest"
	end
	local now = os.time()
	local ok, err = Premium.canBuy(entry, data, now)
	if not ok then
		return false, err
	end
	local fresh = Lure.extend(data.lure, entry.seconds, now)
	PremiumFunnel.step(player, "shop", "prompt")
	spend(player, entry.price, key, entry.cat)
	countLimit(player, entry, data, now)
	PlayerStateService.Set(player, { "account", "lure" }, fresh)
	DataService.Save(player)
	local addedKey, addedArgs = Lure.timeKey(entry.seconds)
	local leftKey, leftArgs = Lure.timeKey(Lure.left(fresh, now))
	Net.Fire(player, "Toast", "lure.added", {
		time = { key = addedKey, args = addedArgs },
		left = { key = leftKey, args = leftArgs },
	}, "success")
	return true, nil
end

-- PremiumBuy: one remote for every shop entry, split by the entry's kind.
local function buy(player: Player, key: string): (boolean, string?)
	local entry = Products.getShop(key)
	if entry and entry.kind == "lure" then
		return buyLure(player, key)
	end
	return buyItem(player, key)
end

-- S123: `expected` = the price the client showed; another price on the server (a new week) refuses without paying.
local function buyCosmetic(player: Player, id: string, expected: number?): (boolean, string?)
	local data = account(player)
	local def = Cosmetics.get(id)
	if not data or not def then
		return false, "error.badRequest"
	end
	local now = Clock.now()
	local price = WeeklyOffer.priceOf(id, now) or def.price
	if expected ~= nil and expected ~= price then
		return false, "premium.error.priceChanged"
	end
	local owned = if def.kind == "pet" then data.pets.owned else data.cosmetics.owned
	local ok, err = Premium.canBuyCosmetic(id, owned, data.dragonShards, now)
	if not ok then
		return false, err
	end
	PremiumFunnel.step(player, "shop", "prompt")
	spend(player, price, id, `cosmetic_{def.kind}`)
	PlayerStateService.Set(player, { "account", if def.kind == "pet" then "pets" else "cosmetics", "owned", id }, true)
	DataService.Save(player)
	if WeeklyOffer.inOffer(id, now) then
		Analytics.custom(player, "WeeklyOffer", price)
	end
	CosmeticService.OwnedChanged(player, id)
	return true, nil
end

-- S123: grants a starter pack (the MonetizationService handler; the receipt and the save are its job). False = the
-- profile is not ready (the receipt waits). Never yields.
local function grantPack(player: Player, pack: Products.StarterPack): boolean
	local data = account(player)
	if not data then
		return false
	end
	local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
		return shards + pack.shards
	end)
	Analytics.shards(player, pack.shards, total, pack.key) -- "starter_<name>" (the key)
	if data.packs[pack.key] == true then
		-- bought twice (two prompts racing): paid for, so the shards stay; the rest only once
		Net.Fire(player, "Toast", "premium.pack.duplicate", nil, "info")
		Analytics.custom(player, "StarterPackDuplicate", pack.robux)
		return true
	end
	for _, id in pack.cosmetics do
		CosmeticService.Grant(player, id)
	end
	for _, passKey in pack.passes do
		MonetizationService.GrantProfilePass(player, passKey)
	end
	PlayerStateService.Set(player, { "account", "packs", pack.key }, true)
	Net.Fire(player, "Toast", "premium.pack.granted", { pack = `@premium.pack.{pack.key}` }, "success")
	return true
end

-- S123 (admin /pack grant): the pack without Robux (any server; the admin's own test). Saves.
function PremiumShopService.GrantPack(player: Player, key: string): boolean
	local pack = Products.getStarterPack(key)
	if not pack or not grantPack(player, pack) then
		return false
	end
	DataService.Save(player)
	return true
end

-- S123 (admin /pack reset): forgets the purchase and takes back the passes the pack granted (its cosmetics and shards
-- stay).
function PremiumShopService.ResetPack(player: Player, key: string): boolean
	local pack = Products.getStarterPack(key)
	if not pack or not account(player) then
		return false
	end
	PlayerStateService.Set(player, { "account", "packs", key }, nil)
	for _, passKey in pack.passes do
		MonetizationService.RevokeProfilePass(player, passKey)
	end
	DataService.Save(player)
	return true
end

local function rename(player: Player, newName: string): (boolean, string?)
	local data = account(player)
	local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local entry = Products.getShop("rename")
	if not data or not char or not entry then
		return false, "error.wrongPhase"
	end
	if newName == char.name then
		return false, "premium.error.sameName"
	end
	local canBuy, buyErr = Premium.canBuy(entry, data, os.time())
	if not canBuy then
		return false, buyErr
	end
	local valid, err = NameService.Validate(player, newName)
	if not valid then
		return false, err
	end
	local ownerKey = NameService.OwnerKey(player.UserId, char.id)
	local reserved, reserveErr = NameService.Reserve(newName, ownerKey)
	if not reserved then
		return false, reserveErr
	end
	-- Yielded: make sure the same character is active and can still pay.
	local now = os.time()
	local fresh = account(player)
	if not fresh or PlayerStateService.GetCharacter(player) ~= char then
		NameService.Release(newName, ownerKey)
		return false, "error.wrongPhase"
	end
	local stillOk, stillErr = Premium.canBuy(entry, fresh, now)
	if not stillOk then
		NameService.Release(newName, ownerKey)
		return false, stillErr
	end
	local oldName = char.name
	PremiumFunnel.step(player, "shop", "prompt")
	spend(player, entry.price, "rename", entry.cat)
	countLimit(player, entry, fresh, now)
	PlayerStateService.Set(player, { "character", "name" }, newName)
	local slot = PlayerStateService.Get(player, { "session", "slot" })
	if slot then
		PlayerStateService.Set(player, { "slots", tostring(slot), "name" }, newName)
	end
	if player.Character then
		player.Character:SetAttribute("CharName", newName)
	end
	DataService.Save(player)
	task.spawn(NameService.Release, oldName, ownerKey)
	log:info("%s renamed '%s' to '%s'", player.Name, oldName, newName)
	return true, nil
end

-- S123: a second, optional argument (PremiumBuyCosmetic's expected price).
local function locked(fn: (Player, string, any) -> (boolean, string?)): (Player, string, any) -> (boolean, string?)
	return function(player: Player, arg: string, arg2: any)
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local ok, result, err = pcall(fn, player, arg, arg2)
		busy[player] = nil
		if not ok then
			log:error("premium request failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err
	end
end

function PremiumShopService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NameService = registry.Get("NameService")
	MonetizationService = registry.Get("MonetizationService")
	CosmeticService = registry.Get("CosmeticService")
end

function PremiumShopService.Start()
	Net.Handle("PremiumBuy", locked(buy))
	Net.Handle("PremiumBuyCosmetic", locked(buyCosmetic))
	Net.Handle("PremiumRename", locked(rename))
	-- S123: starter packs (Developer Products) granted through MonetizationService's receipts
	for _, pack in Products.starterPacks do
		MonetizationService.RegisterProduct(pack.key, function(player: Player): boolean
			return grantPack(player, pack)
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return PremiumShopService
