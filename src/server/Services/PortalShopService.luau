--!strict
-- S160k (owner 2026-10-21, docs/DESIGN.md §13a): the Portal Master in the capital sells every teleport stone of the
-- game for Dragon Shards (Data/PortalShop): by the piece, or forever once per account (account.portalStones; the
-- buying character gets its everlasting copy at once, every other character of the account takes one from him for
-- free). Logic/PortalShop.canBuy is the only rule (the window uses it too); the server checks the NPC's distance and
-- the backpack, then pays, counts and gives in one step without yielding in between.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Data = require(Shared.Data.PortalShop)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local PortalShop = require(Shared.Logic.PortalShop)
local Types = require(Shared.Types)

local log = Log.new("PortalShopService")

local PortalShopService = {
	Name = "PortalShopService",
	Deps = { "DataService", "PlayerStateService", "InventoryService", "NpcService" },
}

local DataService: any
local PlayerStateService: any
local InventoryService: any
local NpcService: any

local busy: { [Player]: boolean } = {}

-- (stone item id, "piece" | "perm" | "claim", amount of a piece purchase) -> (ok, err)
local function buy(player: Player, itemId: string, mode: string, n: number): (boolean, string?)
	local data: Types.AccountData? = DataService.GetData(player)
	if not data or not PlayerStateService.GetCharacter(player) then
		return false, "error.wrongPhase"
	end
	if not NpcService.Near(player, Data.NPC) then
		return false, "npc.error.tooFar"
	end
	local entry = Data.get(itemId)
	local held = if entry then InventoryService.Count(player, entry.permId) else 0
	local ok, err = PortalShop.canBuy(entry, mode, n, data, held)
	if not ok or not entry then
		return false, err
	end
	local price = PortalShop.price(entry, mode, n) :: number
	local give = if mode == "piece" then entry.itemId else entry.permId
	local item = ItemRoll.makeStack(give, if mode == "piece" then n else 1, InventoryService.NewUid())
	item.bound = true
	-- Buying forever with a full backpack still counts: the copy waits at the Portal Master (a free claim later).
	local fits = InventoryService.CanFit(player, { item })
	if mode ~= "perm" and not fits then
		return false, "inventory.full"
	end
	-- Pay, count and give — no yields in between.
	if price > 0 then
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
			return shards - price
		end)
		Analytics.shards(player, -price, total, `portal_{mode}_{itemId}`, true)
		Analytics.custom(player, "PremiumSpend_portal", price)
	end
	if mode == "perm" then
		PlayerStateService.Set(player, { "account", "portalStones", itemId }, true)
	end
	if fits then
		InventoryService.AddItem(player, item)
	else
		Net.Fire(player, "Toast", "portalshop.claimLater", nil, "info")
	end
	if price > 0 then
		DataService.Save(player)
	end
	log:info("%s portal shop %s %s x%d for %d", player.Name, mode, itemId, if mode == "piece" then n else 1, price)
	return true, nil
end

function PortalShopService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
end

function PortalShopService.Start()
	Net.Handle("PortalShopBuy", function(player: Player, itemId: string, mode: string, n: number): (boolean, string?)
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local ok, result, err = pcall(buy, player, itemId, mode, n)
		busy[player] = nil
		if not ok then
			log:error("portal shop failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return PortalShopService
