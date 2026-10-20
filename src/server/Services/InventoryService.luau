--!strict
-- The active character's backpack (DESIGN §5.7). Every change goes through Logic/Inventory and is mirrored to
-- the client slot by slot. Other services use the API (AddItem, GiveNew, Remove, Count, CanFit, ...);
-- players use the remotes MoveItem / SplitStack / SortInventory / DestroyItem / UseItem.
-- S121: the capacity is Logic/Inventory.capacityOf (backpack + Merchant's Pockets); items above it are overflow (taken
-- out through ValidTakeIndex, never added to).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

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
	-- S121: MonetizationService depends on neither of the others (Merchant's Pockets)
	Deps = { "PlayerStateService", "CharacterService", "MonetizationService" },
	-- (player) after any change of the backpack contents.
	Changed = Signal.new(),
	-- Item use handlers by UseEffect.kind (PotionService registers "potion"; S06–S07 add the rest).
	UseHandlers = {} :: { [string]: (player: Player, index: number, item: ItemInstance) -> (boolean, string?) },
}

local PlayerStateService: any
local MonetizationService: any
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

-- S121: `player` is required (the Merchant's Pockets pass is the player's).
function InventoryService.CapacityOf(char: Types.CharacterData, player: Player): number
	local backpack = char.equipment.backpack
	return Inventory.capacityOf(if backpack then backpack.id else nil, MonetizationService.HasPass(player, "pockets"))
end

function InventoryService.Capacity(player: Player): number
	local char = character(player)
	return if char then InventoryService.CapacityOf(char, player) else 0
end

-- S121: the capacity `player` would have with the backpack `backpackId` (equipping or buying a backpack).
function InventoryService.CapacityFor(player: Player, backpackId: string?): number
	return Inventory.capacityOf(backpackId, MonetizationService.HasPass(player, "pockets"))
end

-- S121: a backpack index an item may be TAKEN from: 1..capacity, or an overflow slot holding an item.
function InventoryService.ValidTakeIndex(player: Player, index: number): boolean
	local char = character(player)
	if not char or index ~= math.floor(index) or index < 1 then
		return false
	end
	local capacity = InventoryService.CapacityOf(char, player)
	return index <= capacity
		or (char.inventory[tostring(index)] ~= nil and index <= Inventory.lastIndex(char.inventory))
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

-- Backpack index of the item with this uid (S23: admin tools edit a freshly given item), or nil.
function InventoryService.IndexOf(player: Player, uid: string): number?
	local char = character(player)
	if not char then
		return nil
	end
	for key, item in char.inventory do
		if item.uid == uid then
			return tonumber(key)
		end
	end
	return nil
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

-- S134f: sets several slots at once (nil clears) with one sync and one Changed signal (selling a batch).
function InventoryService.SetSlots(player: Player, slots: { [number]: ItemInstance | false })
	local char = character(player)
	if not char then
		return
	end
	local indices = {}
	for index, item in slots do
		(char.inventory :: any)[tostring(index)] = if item then item else nil
		table.insert(indices, index)
	end
	if #indices > 0 then
		table.sort(indices)
		sync(player, indices)
	end
end

-- Adds an item (stacking). Returns the number of units that did not fit.
function InventoryService.AddItem(player: Player, item: ItemInstance): number
	local char = character(player)
	if not char then
		return item.n
	end
	local changed, leftover =
		Inventory.add(char.inventory, InventoryService.CapacityOf(char, player), item, InventoryService.NewUid)
	sync(player, changed)
	return leftover
end

function InventoryService.CanFit(player: Player, items: { ItemInstance }): boolean
	local char = character(player)
	return char ~= nil and Inventory.canFit(char.inventory, InventoryService.CapacityOf(char, player), items)
end

-- Creates and adds a new item. Equipment is rolled at `rarity`/`ilvl`. Returns (leftover, instance).
function InventoryService.GiveNew(
	player: Player,
	defId: string,
	n: number?,
	rarity: number?,
	ilvl: number?,
	forClass: string? -- S32: class-free items (jewellery) roll bonuses for this class
): (number, ItemInstance?)
	local def = Items.get(defId)
	if not def then
		return n or 1, nil
	end
	local item: ItemInstance
	if def.category == "equipment" then
		item = ItemRoll.rollItem(defId, ilvl or def.level, rarity or 1, rng, InventoryService.NewUid(), forClass)
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

-- Operations that take the item out (lock, destroy, use) accept overflow slots too (S121).
local function validIndex(player: Player, index: number): boolean
	return InventoryService.ValidTakeIndex(player, index)
end

local function moveItem(player: Player, from: number, to: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local changed = Inventory.move(char.inventory, InventoryService.CapacityOf(char, player), from, to)
	if not changed then
		-- W28: a drag from a slot the click before already emptied is stale, not a bad request
		return false,
			if from ~= to
					and from >= 1
					and char.inventory[tostring(from)] == nil
				then "error.stale"
				else "error.badRequest"
	end
	sync(player, changed)
	return true, nil
end

local function splitStack(player: Player, from: number, amount: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local capacity = InventoryService.CapacityOf(char, player)
	local changed = Inventory.split(char.inventory, capacity, from, amount, InventoryService.NewUid)
	if not changed then
		return false,
			if Inventory.firstFree(char.inventory, capacity) == nil then "inventory.full" else "error.badRequest"
	end
	sync(player, changed)
	return true, nil
end

local function sortInventory(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	Inventory.sort(char.inventory, InventoryService.CapacityOf(char, player), InventoryService.NewUid)
	InventoryService.SyncAll(player)
	return true, nil
end

-- Item lock (S20, DESIGN §5.9): protects from selling, dismantling, destroying and trading.
local function toggleLock(player: Player, index: number): (boolean, string?)
	local char = character(player)
	if not char or not validIndex(player, index) then
		return false, "error.badRequest"
	end
	local item = char.inventory[tostring(index)]
	if not item then
		return false, "error.stale" -- W28: the click before already took it (silent on the client)
	end
	local updated = table.clone(item)
	updated.locked = if item.locked then nil else true
	InventoryService.SetSlot(player, index, updated)
	return true, nil
end

local function destroyItem(player: Player, index: number): (boolean, string?)
	if tradeLocked[player] then
		return false, "trade.error.locked"
	end
	local char = character(player)
	if not char or not validIndex(player, index) then
		return false, "error.badRequest"
	end
	local key = tostring(index)
	local item = char.inventory[key]
	if not item then
		return false, "error.stale" -- W28: the click before already took it (silent on the client)
	end
	if item.locked then
		return false, "item.error.locked"
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
	if not char or not validIndex(player, index) then
		return false, "error.badRequest"
	end
	local item = char.inventory[tostring(index)]
	local def = item and Items.get(item.id)
	if not item then
		return false, "error.stale" -- W28: the click before already took it (silent on the client)
	end
	if not def then
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
	MonetizationService = registry.Get("MonetizationService")
end

-- S121: Merchant's Pockets bought or taken away (admin): new slots show at once; a loss packs the items into the
-- smaller capacity when they fit, otherwise they stay as overflow (nothing lost, nothing mailed).
local function pocketsChanged(player: Player, passKey: string, owned: boolean)
	if passKey ~= "pockets" then
		return
	end
	local char = character(player)
	if not char then
		return
	end
	if not owned then
		Inventory.compact(char.inventory, InventoryService.CapacityOf(char, player))
	end
	InventoryService.SyncAll(player)
end

function InventoryService.Start()
	Net.Handle("MoveItem", moveItem)
	Net.Handle("SplitStack", splitStack)
	Net.Handle("SortInventory", sortInventory)
	Net.Handle("DestroyItem", destroyItem)
	Net.Handle("ToggleLock", toggleLock)
	Net.Handle("UseItem", useItem)
	MonetizationService.PassChanged:Connect(pocketsChanged)
end

return InventoryService
