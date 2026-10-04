--!strict
-- Premium rules (DESIGN §21–22), pure: receipt idempotency, shop purchase checks with the daily limit,
-- cosmetic ownership and equipping.

local Cosmetics = require("../Data/Cosmetics")
local Products = require("../Data/Products")

local Premium = {}

export type DailyLimits = { day: number, protectScrolls: number }

function Premium.day(now: number): number
	return now // 86400
end

-- Purchases bought today of a limited entry (the counter resets on a new UTC day).
function Premium.usedToday(limits: DailyLimits, now: number): number
	return if limits.day == Premium.day(now) then limits.protectScrolls else 0
end

function Premium.canBuyShop(key: string, shards: number, limits: DailyLimits, now: number): (boolean, string?)
	local entry = Products.getShop(key)
	if not entry then
		return false, "error.badRequest"
	end
	if shards < entry.price then
		return false, "premium.error.shards"
	end
	if entry.dailyLimit and Premium.usedToday(limits, now) >= entry.dailyLimit then
		return false, "premium.error.dailyLimit"
	end
	return true, nil
end

-- Counts one limited purchase (returns the new limits table).
function Premium.countDaily(limits: DailyLimits, now: number): DailyLimits
	local day = Premium.day(now)
	return { day = day, protectScrolls = (if limits.day == day then limits.protectScrolls else 0) + 1 }
end

function Premium.canBuyCosmetic(id: string, owned: { [string]: boolean }, shards: number): (boolean, string?)
	local def = Cosmetics.get(id)
	if not def then
		return false, "error.badRequest"
	end
	if owned[id] then
		return false, "premium.error.owned"
	end
	if shards < def.price then
		return false, "premium.error.shards"
	end
	return true, nil
end

-- Equip check: nil id = take off the slot of `kind`.
function Premium.canEquip(kind: string, id: string?, owned: { [string]: boolean }): (boolean, string?)
	if not table.find(Cosmetics.kinds, kind :: any) then
		return false, "error.badRequest"
	end
	if id == nil then
		return true, nil
	end
	local def = Cosmetics.get(id)
	if not def or def.kind ~= kind then
		return false, "error.badRequest"
	end
	if not owned[id] then
		return false, "premium.error.notOwned"
	end
	return true, nil
end

-- Receipts already granted must answer PurchaseGranted again without granting twice.
function Premium.alreadyGranted(purchases: { [string]: number }, receiptId: string): boolean
	return purchases[receiptId] ~= nil
end

-- Drops receipts older than `keepSeconds` so the profile does not grow forever.
function Premium.pruneReceipts(purchases: { [string]: number }, now: number, keepSeconds: number): number
	local removed = 0
	for id, at in purchases do
		if now - at > keepSeconds then
			purchases[id] = nil
			removed += 1
		end
	end
	return removed
end

return Premium
