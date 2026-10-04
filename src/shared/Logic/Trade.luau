--!strict
-- 1-on-1 trade exchange (DESIGN §18). Pure functions (Lune tests): the server calls `exchange` with both
-- backpacks and offers; nothing is changed unless every check passes, so an item can never be duplicated
-- or lost:
--   * every offered uid must still be in its owner's backpack, unbound, offered only once,
--   * both players must still have the offered gold,
--   * after removing what they give, each backpack must fit what they receive.
-- On success the new backpacks are returned (the caller swaps them in without yielding).

local Inventory = require("./Inventory")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
type Inventory = { [string]: ItemInstance }

local Trade = {}

export type Side = {
	inventory: Inventory,
	capacity: number,
	gold: number, -- gold the player owns
	offerUids: { string },
	offerGold: number,
}

export type Result = {
	inventoryA: Inventory,
	inventoryB: Inventory,
	goldA: number,
	goldB: number,
	movedA: { ItemInstance }, -- items A gave
	movedB: { ItemInstance }, -- items B gave
}

local MAX_ITEMS = 12

local function clone(inv: Inventory): Inventory
	local copy: Inventory = {}
	for key, item in inv do
		copy[key] = table.clone(item)
	end
	return copy
end

-- Takes the offered items out of `inv` (a clone). Returns the items or (nil, error).
local function take(inv: Inventory, uids: { string }): ({ ItemInstance }?, string?)
	if #uids > MAX_ITEMS then
		return nil, "trade.error.tooMany"
	end
	local seen: { [string]: boolean } = {}
	local taken = {}
	for _, uid in uids do
		if seen[uid] then
			return nil, "trade.error.changed"
		end
		seen[uid] = true
		local foundKey: string? = nil
		for key, item in inv do
			if item.uid == uid then
				foundKey = key
				break
			end
		end
		if not foundKey then
			return nil, "trade.error.changed"
		end
		local item = inv[foundKey]
		if item.bound then
			return nil, "trade.error.bound"
		end
		inv[foundKey] = nil
		table.insert(taken, item)
	end
	return taken, nil
end

-- Whether an item may be put on the table.
function Trade.canOffer(item: ItemInstance?): (boolean, string?)
	if not item then
		return false, "error.badRequest"
	end
	if item.bound then
		return false, "trade.error.bound"
	end
	return true, nil
end

function Trade.exchange(a: Side, b: Side, newUid: () -> string): (Result?, string?)
	if
		a.offerGold < 0
		or b.offerGold < 0
		or a.offerGold ~= math.floor(a.offerGold)
		or b.offerGold ~= math.floor(b.offerGold)
	then
		return nil, "error.badRequest"
	end
	if a.gold < a.offerGold or b.gold < b.offerGold then
		return nil, "trade.error.gold"
	end
	local invA, invB = clone(a.inventory), clone(b.inventory)
	local fromA, errA = take(invA, a.offerUids)
	if not fromA then
		return nil, errA
	end
	local fromB, errB = take(invB, b.offerUids)
	if not fromB then
		return nil, errB
	end
	if not Inventory.canFit(invA, a.capacity, fromB) or not Inventory.canFit(invB, b.capacity, fromA) then
		return nil, "trade.error.space"
	end
	for _, item in fromB do
		local _, leftover = Inventory.add(invA, a.capacity, table.clone(item), newUid)
		if leftover > 0 then
			return nil, "trade.error.space"
		end
	end
	for _, item in fromA do
		local _, leftover = Inventory.add(invB, b.capacity, table.clone(item), newUid)
		if leftover > 0 then
			return nil, "trade.error.space"
		end
	end
	return {
		inventoryA = invA,
		inventoryB = invB,
		goldA = a.gold - a.offerGold + b.offerGold,
		goldB = b.gold - b.offerGold + a.offerGold,
		movedA = fromA,
		movedB = fromB,
	},
		nil
end

Trade.MAX_ITEMS = MAX_ITEMS

return Trade
