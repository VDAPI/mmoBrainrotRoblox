--!strict
-- Premium rules (DESIGN §21–22, DESIGN-17 §1), pure: the one purchase rule of the shop (`canBuy`, used by the shop
-- window and PremiumShopService), daily/weekly limits, tabs and sections of the shop window, cosmetic ownership and
-- equipping, receipt idempotency. S97: cosmetics earned in the game are not for sale, premium mounts (sold only while
-- their product is enabled; Data/Products.mounts).

local Cosmetics = require("../Data/Cosmetics")
local Products = require("../Data/Products")
local Time = require("./Time")

local Premium = {}

-- Per-account shop counters (S120, account.shopLimits): purchases of each limited entry today and this week.
-- `day` is Time.dayNumber, `week` is Time.weekNumber (Monday 00:00 UTC, the same week as weekly quests, S98).
export type ShopLimits = { day: number, week: number, daily: { [string]: number }, weekly: { [string]: number } }

-- The pre-S120 counter (account.dailyLimits): Scrolls of Protection bought on `day`.
export type OldDailyLimits = { day: number, protectScrolls: number }

-- What the purchase rule reads from the account (the server passes AccountData, the window its replicated branches).
export type ShopAccount = {
	dragonShards: number,
	shopLimits: ShopLimits?,
	dailyLimits: OldDailyLimits?,
}

-- Tabs of the shop window in order (texts premium.tab.<id>).
Premium.TABS = table.freeze({ "currency", "passes", "items", "cosmetics", "mounts" })

local OLD_LIMIT_KEY = "scroll_protection"

function Premium.emptyLimits(): ShopLimits
	return { day = 0, week = 0, daily = {}, weekly = {} }
end

-- The counters for today and this week as a new table (the input is never changed).
function Premium.limitsOf(account: { shopLimits: ShopLimits?, dailyLimits: OldDailyLimits? }, now: number): ShopLimits
	local day = Time.dayNumber(now)
	local week = Time.weekNumber(now)
	local saved = account.shopLimits
	local daily: { [string]: number } = {}
	local weekly: { [string]: number } = {}
	if saved and saved.day == day and type(saved.daily) == "table" then
		daily = table.clone(saved.daily)
	end
	if saved and saved.week == week and type(saved.weekly) == "table" then
		weekly = table.clone(saved.weekly)
	end
	-- S120: reads the pre-S120 counter for the day of the update only; dailyLimits is never written again.
	local old = account.dailyLimits
	if daily[OLD_LIMIT_KEY] == nil and old and old.day == day and (old.protectScrolls or 0) > 0 then
		daily[OLD_LIMIT_KEY] = old.protectScrolls
	end
	return { day = day, week = week, daily = daily, weekly = weekly }
end

-- Bought today and this week of `entry`.
function Premium.usedOf(
	entry: Products.ShopEntry,
	account: { shopLimits: ShopLimits?, dailyLimits: OldDailyLimits? },
	now: number
): (number, number)
	local limits = Premium.limitsOf(account, now)
	return limits.daily[entry.key] or 0, limits.weekly[entry.key] or 0
end

-- The one purchase rule for Dragon Currency entries (shop window and server). The limit goes before the price: a
-- player who used up the limit learns that first.
function Premium.canBuy(entry: Products.ShopEntry?, account: ShopAccount, now: number): (boolean, string?)
	if entry == nil then
		return false, "error.badRequest"
	end
	if entry.unavailable == true then
		return false, "premium.error.soon"
	end
	if entry.dailyLimit or entry.weeklyLimit then
		local today, thisWeek = Premium.usedOf(entry, account, now)
		if entry.dailyLimit and today >= entry.dailyLimit then
			return false, "premium.error.dailyLimit"
		end
		if entry.weeklyLimit and thisWeek >= entry.weeklyLimit then
			return false, "premium.error.weeklyLimit"
		end
	end
	if (account.dragonShards or 0) < entry.price then
		return false, "premium.error.shards"
	end
	return true, nil
end

-- The counters after one purchase of `entry` (an entry without limits returns limitsOf unchanged).
function Premium.countPurchase(
	entry: Products.ShopEntry,
	account: { shopLimits: ShopLimits?, dailyLimits: OldDailyLimits? },
	now: number
): ShopLimits
	local limits = Premium.limitsOf(account, now)
	if entry.dailyLimit then
		limits.daily[entry.key] = (limits.daily[entry.key] or 0) + 1
	end
	if entry.weeklyLimit then
		limits.weekly[entry.key] = (limits.weekly[entry.key] or 0) + 1
	end
	return limits
end

-- DESIGN-17 §1: the mounts tab exists only while a mount product is enabled (S97).
function Premium.visibleTabs(mountOffers: number): { string }
	local out: { string } = {}
	for _, id in Premium.TABS do
		if id ~= "mounts" or mountOffers > 0 then
			table.insert(out, id)
		end
	end
	return out
end

export type ShopSection = { cat: Products.ShopCat, entries: { Products.ShopEntry } }

-- Sections of the "Items" tab: Data/Products.shopCats in order, without empty ones.
function Premium.shopSections(): { ShopSection }
	local out: { ShopSection } = {}
	for _, cat: Products.ShopCat in Products.shopCats :: { Products.ShopCat } do
		local entries = Products.shopIn(cat)
		if #entries > 0 then
			table.insert(out, { cat = cat, entries = entries })
		end
	end
	return out
end

-- Passes shown in the shop, in list order (default Data/Products.passes).
-- S121 turns the lifetime VIP pass off with enabled = false; owners still see it as owned.
function Premium.shownPasses(owned: { [string]: boolean }, list: { Products.Pass }?): { Products.Pass }
	local out: { Products.Pass } = {}
	for _, pass in list or Products.passes do
		if (pass :: any).enabled ~= false or owned[pass.key] == true then
			table.insert(out, pass)
		end
	end
	return out
end

-- The buy button of a Robux product (DESIGN-17 §0.8): a configured id, or Studio (simulated purchase), can be bought;
-- id 0 on a live server shows "Soon" (MonetizationService refuses it with premium.error.notConfigured).
function Premium.robuxState(id: number, studio: boolean): "buy" | "soon"
	return if id ~= 0 or studio then "buy" else "soon"
end

-- Percent more currency per Robux than `base` (default the smallest pack), rounded down.
function Premium.packBonus(pack: Products.ShardPack, base: Products.ShardPack?): number
	local b = base or Products.shardPacks[1]
	return math.floor((pack.shards / pack.robux) / (b.shards / b.robux) * 100 + 1e-9) - 100
end

-- The balance left after paying `price` (purchase confirmation and tooltips).
function Premium.balanceAfter(shards: number, price: number): number
	return shards - price
end

function Premium.canBuyCosmetic(id: string, owned: { [string]: boolean }, shards: number): (boolean, string?)
	local def = Cosmetics.get(id)
	if not def then
		return false, "error.badRequest"
	end
	if owned[id] then
		return false, "premium.error.owned"
	end
	if def.obtain ~= nil then
		return false, "premium.error.notForSale"
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

-- Premium mounts on sale (enabled) from `list` (default Data/Products.mounts). Empty while the owner has not decided.
function Premium.mountOffers(list: { Products.MountProduct }?): { Products.MountProduct }
	local out: { Products.MountProduct } = {}
	for _, entry in list or Products.mounts do
		if entry.enabled == true then
			table.insert(out, entry)
		end
	end
	return out
end

-- Whether `character` may buy the premium mount `key` (from `list`, default Data/Products.mounts).
function Premium.canBuyMount(
	key: string,
	character: { mounts: { owned: { [string]: any } }? }?,
	list: { Products.MountProduct }?
): (boolean, string?)
	local entry: Products.MountProduct? = nil
	for _, e in list or Products.mounts do
		if e.key == key then
			entry = e
		end
	end
	if not entry then
		return false, "error.badRequest"
	end
	if entry.enabled ~= true then
		return false, "premium.error.notOnSale"
	end
	if not character then
		return false, "error.wrongPhase"
	end
	local owned = character.mounts and character.mounts.owned
	if owned and owned[entry.mount] ~= nil then
		return false, "premium.error.owned"
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
