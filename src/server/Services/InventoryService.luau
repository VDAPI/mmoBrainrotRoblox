--!strict
-- The active character's backpack (DESIGN §5.7). Every change goes through Logic/Inventory and is mirrored to
-- the client slot by slot. Other services use the API (AddItem, GiveNew, Remove, Count, CanFit, ...);
-- players use the remotes MoveItem / SplitStack / SortInventory / DestroyItem / UseItem.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("InventoryService")

type ItemInstance = Types.ItemInstance

local InventoryService = {
	Name = "InventoryService",
	Deps = { "PlayerStateService", "CharacterService" },
	-- (player) after any change of the backpack contents.
	Changed = Signal.new(),
	-- Item use handlers by UseEffect.kind (PotionService registers "potion"; S06–S07 add the rest).
	UseHandlers = {} :: { [string]: (player: Player, index: number, item: ItemInstance) -> (boolean, string?) },
}

local PlayerStateService: any
local rng = Rng.new()

-- Players with an open trade (S10): items cannot leave their backpack until the trade ends.
local tradeLocked: { [Player]: boolean } = {}

function InventoryService.SetTradeLock(player: Player, locked: boolean)
	(tradeLocked :: any)[player] = if locked then true else nil
end

function InventoryService.IsTradeLocked(player: Player): boolean
	return tradeLocked[player] == true
end

function InventoryService.NewUid(): string
	return HttpService:GenerateGUID(false)
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

function InventoryService.CapacityOf(char: Types.CharacterData): number
	local backpack = char.equipment.backpack
	local def = backpack and Items.get(backpack.id)
	return if def and def.capacity then def.capacity else Config.DefaultCapacity
end

function InventoryService.Capacity(player: Player): number
	local char = character(player)
	return if char then InventoryService.CapacityOf(char) else 0
end

-- Mirrors the given slots to the client.
local function sync(player: Player, indices: { number })
	local char = character(player)
	if not char then
		return
	end
	local done = {}
	for _, index in indices do
		if not done[index] then
			done[index] = true
			local key = tostring(index)
			PlayerStateService.Set(player, { "character", "inventory", key }, char.inventory[key])
		end
	end
	InventoryService.Changed:Fire(player)
end

-- Replaces the whole inventory table on the client (sort, compaction).
function InventoryService.SyncAll(player: Player)
	local char = character(player)
	if char then
		PlayerStateService.Set(player, { "character", "inventory" }, char.inventory)
		InventoryService.Changed:Fire(player)
	end
end

function InventoryService.Get(player: Player, index: number): ItemInstance?
	local char = character(player)
	return if char then char.inventory[tostring(index)] else nil
end

-- Puts `item` into a specific empty slot (or clears it with nil).
function InventoryService.SetSlot(player: Player, index: number, item: ItemInstance?)
	local char = character(player)
	if not char then
		return
	end
	(char.inventory :: any)[tostring(index)] = item
	sync(player, { index })
end

-- Adds an item (stacking). Returns the number of units that did not fit.
function InventoryService.AddItem(player: Player, item: ItemInstance): number
	local char = character(player)
	if not char then
		return item.n
	end
	local changed, leftover =
		Inventory.add(char.inventory, InventoryService.CapacityOf(char), item, InventoryService.NewUid)
	sync(player, changed)
	return leftover
end

function InventoryService.CanFit(player: Player, items: { ItemInstance }): boolean
	local char = character(player)
	return char ~= nil and Inventory.canFit(char.inventory, InventoryService.CapacityOf(char), items)
end

-- Creates and adds a new item. Equipment is rolled at `rarity`/`ilvl`. Returns (leftover, instance).
function InventoryService.GiveNew(
	player: Player,
	defId: string,
	n: number?,
	rarity: number?,
	ilvl: number?
): (number, ItemInstance?)
	local def = Items.get(defId)
	if not def then
		return n or 1, nil
	end
	local item: ItemInstance
	if def.category == "equipment" then
		item = ItemRoll.rollItem(defId, ilvl or def.level, rarity or 1, rng, InventoryService.NewUid())
	else
		item = ItemRoll.makeStack(defId, n or 1, InventoryService.NewUid())
	end
	return InventoryService.AddItem(player, item), item
end

function InventoryService.Count(player: Player, itemId: string): number
	local char = character(player)
	return if char then Inventory.count(char.inventory, itemId) else 0
end

-- Removes up to n units by id. Returns the number removed.
function InventoryService.Remove(player: Player, itemId: string, n: number): number
	local char = character(player)
	if not char then
		return 0
	end
	local removed, changed = Inventory.remove(char.inventory, itemId, n)
	sync(player, changed)
	return removed
end

-- Removes one unit from the stack at `index`. Returns the removed unit's definition id.
function InventoryService.ConsumeAt(player: Player, index: number): string?
	local char = character(player)
	local key = tostring(index)
	local item = char and char.inventory[key]
	if not char or not item then
		return nil
	end
	item.n -= 1
	if item.n <= 0 then
		char.inventory[key] = nil
	end
	sync(player, { index })
	return item.id
end

-- Index of the first stack of `itemId`, or nil.
function InventoryService.Find(player: Player, itemId: string): number?
	local char = character(player)
	if not char then
		return nil
	end
	local best: number? = nil
	for key, item in char.inventory do
		if item.id == itemId then
			local index = tonumber(key) :: number
			if best == nil or index < best then
				best = index
			end
		end
	end
	return best
end

function InventoryService.Clear(player: Player)
	local char = character(player)
	if char then
		table.clear(char.inventory)
		InventoryService.SyncAll(player)
	end
end

-- Remotes ---------------------------------------------------------------------------------------------------

local function validIndex(char: Types.CharacterData, index: number): boolean
	return index >= 1 and index <= InventoryService.CapacityOf(char)
end

local function moveItem(player: Player, from: number, to: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local changed = Inventory.move(char.inventory, InventoryService.CapacityOf(char), from, to)
	if not changed then
		return false, "error.badRequest"
	end
	sync(player, changed)
	return true, nil
end

local function splitStack(player: Player, from: number, amount: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local changed =
		Inventory.split(char.inventory, InventoryService.CapacityOf(char), from, amount, InventoryService.NewUid)
	if not changed then
		return false,
			if Inventory.firstFree(char.inventory, InventoryService.CapacityOf(char)) == nil
				then "inventory.full"
				else "error.badRequest"
	end
	sync(player, changed)
	return true, nil
end

local function sortInventory(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	Inventory.sort(char.inventory, InventoryService.CapacityOf(char), InventoryService.NewUid)
	InventoryService.SyncAll(player)
	return true, nil
end

local function destroyItem(player: Player, index: number): (boolean, string?)
	if tradeLocked[player] then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char or not validIndex(char, index) then
		return false, "error.badRequest"
	end
	local key = tostring(index)
	local item = char.inventory[key]
	if not item then
		return false, "error.badRequest"
	end
	char.inventory[key] = nil
	sync(player, { index })
	log:info("%s destroyed %s x%d", player.Name, item.id, item.n)
	return true, nil
end

local function useItem(player: Player, index: number): (boolean, string?)
	if tradeLocked[player] then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char or not validIndex(char, index) then
		return false, "error.badRequest"
	end
	local item = char.inventory[tostring(index)]
	local def = item and Items.get(item.id)
	if not item or not def then
		return false, "error.badRequest"
	end
	local kind = def.use and def.use.kind
	local handler = kind and InventoryService.UseHandlers[kind]
	if not handler then
		return false, "inventory.cannotUse"
	end
	return handler(player, index, item)
end

function InventoryService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
end

function InventoryService.Start()
	Net.Handle("MoveItem", moveItem)
	Net.Handle("SplitStack", splitStack)
	Net.Handle("SortInventory", sortInventory)
	Net.Handle("DestroyItem", destroyItem)
	Net.Handle("UseItem", useItem)
end

return InventoryService
