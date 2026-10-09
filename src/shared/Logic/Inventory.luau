--!strict
-- Backpack operations on the sparse slot table (DESIGN §5.7). Pure: every function works on the table it
-- gets (keys "1".."capacity") and returns what changed, so the server can mirror changes to the client.
-- Stackable items (materials, potions, scrolls) merge up to their maxStack (999).

local Items = require("../Data/Items")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
export type Inventory = { [string]: ItemInstance }

local Inventory = {}

local function key(index: number): string
	return tostring(index)
end

local function maxStack(item: ItemInstance): number
	local def = Items.get(item.id)
	return if def and def.stackable then def.maxStack else 1
end

-- Two stacks can merge when they are the same stackable item with the same binding.
function Inventory.canMerge(a: ItemInstance, b: ItemInstance): boolean
	return a.id == b.id and a.bound == b.bound and maxStack(a) > 1 and a.up == 0 and b.up == 0
end

function Inventory.firstFree(inv: Inventory, capacity: number): number?
	for i = 1, capacity do
		if inv[key(i)] == nil then
			return i
		end
	end
	return nil
end

function Inventory.used(inv: Inventory): number
	local n = 0
	for _ in inv do
		n += 1
	end
	return n
end

function Inventory.freeSlots(inv: Inventory, capacity: number): number
	local n = 0
	for i = 1, capacity do
		if inv[key(i)] == nil then
			n += 1
		end
	end
	return n
end

-- Adds `item` (stacks first). Mutates inv. Returns (changed slot indices, leftover count that did not fit).
-- `newUid` is called when a stack must be split into a new slot.
function Inventory.add(inv: Inventory, capacity: number, item: ItemInstance, newUid: () -> string): ({ number }, number)
	local changed = {}
	local remaining = math.max(1, item.n)
	local limit = maxStack(item)
	if limit > 1 then
		for i = 1, capacity do
			local existing = inv[key(i)]
			if existing and Inventory.canMerge(existing, item) and existing.n < limit then
				local moved = math.min(limit - existing.n, remaining)
				existing.n += moved
				remaining -= moved
				table.insert(changed, i)
				if remaining <= 0 then
					return changed, 0
				end
			end
		end
	end
	local first = true
	while remaining > 0 do
		local slot = Inventory.firstFree(inv, capacity)
		if not slot then
			break
		end
		local placed = table.clone(item)
		placed.n = math.min(limit, remaining)
		if not first or #changed > 0 then
			placed.uid = newUid()
		end
		first = false
		inv[key(slot)] = placed
		remaining -= placed.n
		table.insert(changed, slot)
	end
	return changed, remaining
end

-- True when every item fits (simulated on a copy).
function Inventory.canFit(inv: Inventory, capacity: number, items: { ItemInstance }): boolean
	local copy: Inventory = {}
	for k, v in inv do
		copy[k] = table.clone(v)
	end
	for _, item in items do
		local _, leftover = Inventory.add(copy, capacity, table.clone(item), function()
			return "sim"
		end)
		if leftover > 0 then
			return false
		end
	end
	return true
end

-- Moves (or merges / swaps) the item at `from` to `to`. Returns changed indices, or nil when invalid.
function Inventory.move(inv: Inventory, capacity: number, from: number, to: number): { number }?
	if from == to or from < 1 or to < 1 or from > capacity or to > capacity then
		return nil
	end
	local source = inv[key(from)]
	if not source then
		return nil
	end
	local target = inv[key(to)]
	if target and Inventory.canMerge(source, target) then
		local limit = maxStack(target)
		local moved = math.min(limit - target.n, source.n)
		if moved <= 0 then
			-- Full target stack: swap instead.
			local slots = inv :: any
			slots[key(from)], slots[key(to)] = target, source
			return { from, to }
		end
		target.n += moved
		source.n -= moved
		if source.n <= 0 then
			inv[key(from)] = nil
		end
		return { from, to }
	end
	local slots = inv :: any
	slots[key(from)], slots[key(to)] = target, source
	return { from, to }
end

-- Splits `amount` off the stack at `from` into the first free slot. Returns changed indices or nil.
function Inventory.split(
	inv: Inventory,
	capacity: number,
	from: number,
	amount: number,
	newUid: () -> string
): { number }?
	local source = inv[key(from)]
	if not source or amount < 1 or amount >= source.n or amount ~= math.floor(amount) then
		return nil
	end
	local slot = Inventory.firstFree(inv, capacity)
	if not slot then
		return nil
	end
	local part = table.clone(source)
	part.uid = newUid()
	part.n = amount
	source.n -= amount
	inv[key(slot)] = part
	return { from, slot }
end

local CATEGORY_ORDER: { [string]: number } = {
	equipment = 1,
	backpack = 2,
	consumable = 3,
	stone = 4,
	scroll = 5,
	tool = 6,
	material = 7,
}

local SLOT_ORDER: { [string]: number } = {
	weapon = 1,
	offhand = 2,
	helmet = 3,
	armor = 4,
	gloves = 5,
	boots = 6,
	necklace = 7,
	ring = 8,
	talisman = 9,
	backpack = 10,
}

-- Sort key: category, slot, rarity (best first), level (highest first), id.
local function less(a: ItemInstance, b: ItemInstance): boolean
	local da, db = Items.get(a.id), Items.get(b.id)
	local ca = if da then CATEGORY_ORDER[da.category] or 99 else 99
	local cb = if db then CATEGORY_ORDER[db.category] or 99 else 99
	if ca ~= cb then
		return ca < cb
	end
	local sa = if da and da.slot then SLOT_ORDER[da.slot] or 99 else 99
	local sb = if db and db.slot then SLOT_ORDER[db.slot] or 99 else 99
	if sa ~= sb then
		return sa < sb
	end
	if a.rarity ~= b.rarity then
		return a.rarity > b.rarity
	end
	local la = if da then da.level else 0
	local lb = if db then db.level else 0
	if la ~= lb then
		return la > lb
	end
	if a.id ~= b.id then
		return a.id < b.id
	end
	return a.uid < b.uid
end

-- Merges stacks and packs items to the front in sorted order. Mutates inv. Returns the new table.
function Inventory.sort(inv: Inventory, capacity: number, newUid: () -> string): Inventory
	local list: { ItemInstance } = {}
	for _, item in inv do
		table.insert(list, item)
	end
	table.sort(list, less)
	local result: Inventory = {}
	for _, item in list do
		Inventory.add(result, math.max(capacity, #list), item, newUid)
	end
	table.clear(inv)
	for k, v in result do
		inv[k] = v
	end
	return inv
end

-- Moves every item into slots 1..capacity keeping order (for a smaller backpack). Returns false when they
-- do not fit (inv untouched).
function Inventory.compact(inv: Inventory, capacity: number): boolean
	if Inventory.used(inv) > capacity then
		return false
	end
	local indices = {}
	for k in inv do
		table.insert(indices, tonumber(k) :: number)
	end
	table.sort(indices)
	local result: Inventory = {}
	for i, index in indices do
		result[key(i)] = inv[key(index)]
	end
	table.clear(inv)
	for k, v in result do
		inv[k] = v
	end
	return true
end

function Inventory.count(inv: Inventory, itemId: string): number
	local n = 0
	for _, item in inv do
		if item.id == itemId then
			n += item.n
		end
	end
	return n
end

-- Removes up to `n` units of `itemId` (smallest stacks first). Returns (removed, changed indices).
function Inventory.remove(inv: Inventory, itemId: string, n: number): (number, { number })
	local slots = {}
	for k, item in inv do
		if item.id == itemId then
			table.insert(slots, { index = tonumber(k) :: number, n = item.n })
		end
	end
	table.sort(slots, function(a, b)
		if a.n ~= b.n then
			return a.n < b.n
		end
		return a.index < b.index
	end)
	local removed = 0
	local changed = {}
	for _, slot in slots do
		if removed >= n then
			break
		end
		local item = inv[key(slot.index)]
		local take = math.min(item.n, n - removed)
		item.n -= take
		removed += take
		if item.n <= 0 then
			inv[key(slot.index)] = nil
		end
		table.insert(changed, slot.index)
	end
	return removed, changed
end

return Inventory
