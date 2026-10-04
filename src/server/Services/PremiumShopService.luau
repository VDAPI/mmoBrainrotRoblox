--!strict
-- Premium shop for Dragon Shards (DESIGN §21): scrolls (Protection limited to 5 a day), renaming the active
-- character (NameService: filter + unique reservation) and cosmetics/pets (owned by the account). Every
-- purchase checks and pays in one step without yielding between the check and the change; renaming yields
-- for the name store and re-checks the shards afterwards.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Cosmetics = require(Shared.Data.Cosmetics)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Premium = require(Shared.Logic.Premium)
local Products = require(Shared.Data.Products)
local Types = require(Shared.Types)

local log = Log.new("PremiumShopService")

local PremiumShopService = {
	Name = "PremiumShopService",
	Deps = { "DataService", "PlayerStateService", "InventoryService", "NameService" },
}

local DataService: any
local PlayerStateService: any
local InventoryService: any
local NameService: any

local busy: { [Player]: boolean } = {}

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

local function spend(player: Player, price: number, reason: string)
	local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
		return shards - price
	end)
	Analytics.shards(player, -price, total, reason)
	Analytics.custom(player, "PremiumSpend_" .. reason, price)
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
	local ok, err = Premium.canBuyShop(key, data.dragonShards, data.dailyLimits, now)
	if not ok then
		return false, err
	end
	local item = ItemRoll.makeStack(entry.itemId, 1, InventoryService.NewUid())
	if not InventoryService.CanFit(player, { item }) then
		return false, "inventory.full"
	end
	spend(player, entry.price, key)
	if entry.dailyLimit then
		PlayerStateService.Set(player, { "account", "dailyLimits" }, Premium.countDaily(data.dailyLimits, now))
	end
	InventoryService.AddItem(player, item)
	DataService.Save(player)
	return true, nil
end

local function buyCosmetic(player: Player, id: string): (boolean, string?)
	local data = account(player)
	local def = Cosmetics.get(id)
	if not data or not def then
		return false, "error.badRequest"
	end
	local owned = if def.kind == "pet" then data.pets.owned else data.cosmetics.owned
	local ok, err = Premium.canBuyCosmetic(id, owned, data.dragonShards)
	if not ok then
		return false, err
	end
	spend(player, def.price, id)
	PlayerStateService.Set(player, { "account", if def.kind == "pet" then "pets" else "cosmetics", "owned", id }, true)
	DataService.Save(player)
	return true, nil
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
	if data.dragonShards < entry.price then
		return false, "premium.error.shards"
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
	data = account(player)
	if not data or PlayerStateService.GetCharacter(player) ~= char or data.dragonShards < entry.price then
		NameService.Release(newName, ownerKey)
		return false, "premium.error.shards"
	end
	local oldName = char.name
	spend(player, entry.price, "rename")
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

local function locked(fn: (Player, string) -> (boolean, string?)): (Player, string) -> (boolean, string?)
	return function(player: Player, arg: string)
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local ok, result, err = pcall(fn, player, arg)
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
end

function PremiumShopService.Start()
	Net.Handle("PremiumBuy", locked(buyItem))
	Net.Handle("PremiumBuyCosmetic", locked(buyCosmetic))
	Net.Handle("PremiumRename", locked(rename))
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return PremiumShopService
