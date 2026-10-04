--!strict
-- Account vault (DESIGN §5.7): 60 slots shared by all characters of the account (+60 with the "Vault"
-- gamepass). Bound items are allowed. Uses the banker NPC; contents replicate under account.deposit.items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Inventory = require(Shared.Logic.Inventory)
local Net = require(Shared.Net)
local Products = require(Shared.Data.Products)
local Types = require(Shared.Types)

local DepositService = {
	Name = "DepositService",
	Deps = { "PlayerStateService", "DataService", "InventoryService", "NpcService", "MonetizationService" },
}

local PlayerStateService: any
local DataService: any
local InventoryService: any
local NpcService: any
local MonetizationService: any

local function account(player: Player): Types.AccountData?
	return DataService.GetData(player)
end

function DepositService.Size(player: Player): number
	local data = account(player)
	local base = if data then data.deposit.size else 60
	return base + (if MonetizationService.HasPass(player, "vault") then Products.VAULT_PASS_SLOTS else 0)
end

local function syncSlots(player: Player, indices: { number })
	local data = account(player)
	if not data then
		return
	end
	for _, index in indices do
		local key = tostring(index)
		PlayerStateService.Set(player, { "account", "deposit", "items", key }, data.deposit.items[key])
	end
end

local function nearBanker(player: Player): boolean
	return NpcService.NearService(player, "deposit") ~= nil
end

local function deposit(player: Player, invIndex: number, depIndex: number?): (boolean, string?)
	if InventoryService.IsTradeLocked(player) then
		return false, "trade.error.locked"
	end
	local data = account(player)
	if not data or not PlayerStateService.GetCharacter(player) then
		return false, "error.wrongPhase"
	end
	if not nearBanker(player) then
		return false, "npc.error.tooFar"
	end
	local item = InventoryService.Get(player, invIndex)
	if not item then
		return false, "error.badRequest"
	end
	local size = DepositService.Size(player)
	local items = data.deposit.items
	if depIndex and depIndex >= 1 and depIndex <= size and items[tostring(depIndex)] == nil then
		items[tostring(depIndex)] = item
		InventoryService.SetSlot(player, invIndex, nil)
		syncSlots(player, { depIndex })
		return true, nil
	end
	local changed, leftover = Inventory.add(items, size, item, InventoryService.NewUid)
	if leftover >= item.n then
		return false, "deposit.full"
	end
	if leftover > 0 then
		item.n = leftover
		InventoryService.SetSlot(player, invIndex, item)
	else
		InventoryService.SetSlot(player, invIndex, nil)
	end
	syncSlots(player, changed)
	return true, nil
end

local function withdraw(player: Player, depIndex: number, invIndex: number?): (boolean, string?)
	local data = account(player)
	local char = PlayerStateService.GetCharacter(player)
	if not data or not char then
		return false, "error.wrongPhase"
	end
	if not nearBanker(player) then
		return false, "npc.error.tooFar"
	end
	local key = tostring(depIndex)
	local item = data.deposit.items[key]
	if not item then
		return false, "error.badRequest"
	end
	local capacity = InventoryService.CapacityOf(char)
	if invIndex and invIndex >= 1 and invIndex <= capacity and InventoryService.Get(player, invIndex) == nil then
		(data.deposit.items :: any)[key] = nil
		InventoryService.SetSlot(player, invIndex, item)
		syncSlots(player, { depIndex })
		return true, nil
	end
	local leftover = InventoryService.AddItem(player, item)
	if leftover >= item.n then
		return false, "inventory.full"
	end
	if leftover > 0 then
		item.n = leftover
	else
		(data.deposit.items :: any)[key] = nil
	end
	syncSlots(player, { depIndex })
	return true, nil
end

local function move(player: Player, from: number, to: number): (boolean, string?)
	local data = account(player)
	if not data or not nearBanker(player) then
		return false, "npc.error.tooFar"
	end
	local changed = Inventory.move(data.deposit.items, DepositService.Size(player), from, to)
	if not changed then
		return false, "error.badRequest"
	end
	syncSlots(player, changed)
	return true, nil
end

local function sort(player: Player): (boolean, string?)
	local data = account(player)
	if not data or not nearBanker(player) then
		return false, "npc.error.tooFar"
	end
	Inventory.sort(data.deposit.items, DepositService.Size(player), InventoryService.NewUid)
	PlayerStateService.Set(player, { "account", "deposit", "items" }, data.deposit.items)
	return true, nil
end

function DepositService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	DataService = registry.Get("DataService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	MonetizationService = registry.Get("MonetizationService")
end

function DepositService.Start()
	Net.Handle("DepositItem", deposit)
	Net.Handle("WithdrawItem", withdraw)
	Net.Handle("MoveDeposit", move)
	Net.Handle("SortDeposit", sort)
end

return DepositService
