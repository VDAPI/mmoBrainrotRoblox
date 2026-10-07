--!strict
-- Auction house rules (DESIGN §18), pure so they run in Lune and inside DataStore UpdateAsync callbacks:
-- listing checks, deposit/fee/payout, the MemoryStore index key and summary, search filtering and the
-- listing state machine active -> sold | cancelled | expired (each transition only from "active").

local Market = require("../Data/Market")
local Rarities = require("../Data/Rarities")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

local Rules = Market.Auction

export type Status = "active" | "sold" | "cancelled" | "expired"

export type Listing = {
	id: string,
	sellerUserId: number,
	sellerCharId: string,
	sellerName: string,
	item: ItemInstance,
	price: number,
	deposit: number,
	category: string,
	createdAt: number,
	expiresAt: number,
	status: Status,
	buyerName: string?,
	closedAt: number?,
}

-- Short index entry (MemoryStore value).
export type Summary = {
	id: string,
	i: string, -- item id
	r: number, -- rarity
	l: number, -- required level
	c: string, -- classes joined by "," ("" = any)
	p: number, -- price
	il: number, -- item level
	u: number, -- upgrade
	n: number, -- stack size
	e: number, -- expires at (os.time)
	sn: string, -- seller name
	su: number, -- seller user id
	q: string, -- folded search text
	v: number?, -- S30: rarity format (Rarities.RV); summaries without it carry a pre-S30 rarity in `r`
}

export type Filter = {
	category: string?,
	class: string?,
	minLevel: number?,
	maxLevel: number?,
	rarity: number?,
	text: string?, -- folded
}

-- Minimal item definition fields the rules need.
export type DefLike = { category: string, slot: string?, level: number, classes: { string }? }

local Auction = {}

function Auction.categoryOf(def: DefLike): string
	for _, category in Market.categories do
		if def.slot and category.slots and table.find(category.slots, def.slot) then
			return category.id
		end
		if not def.slot and category.itemCategories and table.find(category.itemCategories, def.category) then
			return category.id
		end
	end
	return "other"
end

function Auction.deposit(price: number): number
	return math.max(1, math.floor(price * Rules.depositPct / 100))
end

function Auction.fee(price: number): number
	return math.floor(price * Rules.feePct / 100)
end

-- What the seller receives by mail after a sale: price minus fee plus the returned deposit.
function Auction.payout(price: number, deposit: number): number
	return price - Auction.fee(price) + deposit
end

function Auction.validPrice(price: number): boolean
	return price == math.floor(price) and price >= Rules.minPrice and price <= Rules.maxPrice
end

-- Checks before an item leaves the backpack. Returns (ok, errorKey?).
function Auction.validateListing(
	item: ItemInstance?,
	def: DefLike?,
	price: number,
	hours: number,
	activeCount: number,
	gold: number
): (boolean, string?)
	if not item or not def then
		return false, "auction.error.noItem"
	end
	if item.locked then
		return false, "item.error.locked"
	end
	if item.bound then
		return false, "auction.error.bound"
	end
	if not Auction.validPrice(price) then
		return false, "auction.error.price"
	end
	if not table.find(Rules.durations, hours) then
		return false, "error.badRequest"
	end
	if activeCount >= Rules.maxListings then
		return false, "auction.error.limit"
	end
	if gold < Auction.deposit(price) then
		return false, "auction.error.deposit"
	end
	return true, nil
end

-- Index keys sort by price (zero padded), ties by listing id.
function Auction.indexKey(price: number, id: string): string
	return string.format("%012d_%s", price, id)
end

function Auction.summary(listing: Listing, def: DefLike?, searchText: string): Summary
	local item = listing.item
	return {
		id = listing.id,
		i = item.id,
		r = item.rarity,
		l = if def then def.level else 1,
		c = if def and def.classes then table.concat(def.classes, ",") else "",
		p = listing.price,
		il = item.ilvl,
		u = item.up or 0,
		n = item.n or 1,
		e = listing.expiresAt,
		sn = listing.sellerName,
		su = listing.sellerUserId,
		q = searchText,
		v = Rarities.RV,
	}
end

-- S30: index entries written before the new rarity ladder are mapped when read (listings live <= 48 h).
-- Mutates and returns the summary; idempotent.
function Auction.upgradeSummary(summary: Summary): Summary
	if summary.v ~= Rarities.RV then
		summary.r = Rarities.fromLegacy[tonumber(summary.r) or 1] or Rarities.COMMON
		summary.v = Rarities.RV
	end
	return summary
end

function Auction.matches(summary: Summary, filter: Filter, now: number): boolean
	if summary.e <= now then
		return false
	end
	if filter.class and summary.c ~= "" and not table.find(string.split(summary.c, ","), filter.class) then
		return false
	end
	if filter.minLevel and summary.l < filter.minLevel then
		return false
	end
	if filter.maxLevel and summary.l > filter.maxLevel then
		return false
	end
	if filter.rarity and summary.r ~= filter.rarity then
		return false
	end
	if filter.text and filter.text ~= "" and not string.find(summary.q, filter.text, 1, true) then
		return false
	end
	return true
end

-- Sorts summaries by price (then id) in place.
function Auction.sort(list: { Summary }, descending: boolean)
	table.sort(list, function(a, b)
		if a.p ~= b.p then
			return if descending then a.p > b.p else a.p < b.p
		end
		return a.id < b.id
	end)
end

-- State machine ------------------------------------------------------------------------------------

local function active(listing: Listing?, now: number): (boolean, string?)
	if not listing then
		return false, "auction.error.gone"
	end
	if listing.status ~= "active" then
		return false, if listing.status == "sold" then "auction.error.sold" else "auction.error.gone"
	end
	if listing.expiresAt <= now then
		return false, "auction.error.expired"
	end
	return true, nil
end

function Auction.buy(listing: Listing?, buyerUserId: number, buyerName: string, now: number): (boolean, string?)
	local ok, err = active(listing, now)
	if not ok then
		return false, err
	end
	local l = listing :: Listing
	if l.sellerUserId == buyerUserId then
		return false, "auction.error.own"
	end
	l.status = "sold"
	l.buyerName = buyerName
	l.closedAt = now
	return true, nil
end

function Auction.cancel(listing: Listing?, sellerUserId: number, sellerCharId: string, now: number): (boolean, string?)
	if not listing or listing.status ~= "active" then
		return false, if listing and listing.status == "sold" then "auction.error.sold" else "auction.error.gone"
	end
	if listing.sellerUserId ~= sellerUserId or listing.sellerCharId ~= sellerCharId then
		return false, "auction.error.notYours"
	end
	listing.status = "cancelled"
	listing.closedAt = now
	return true, nil
end

-- Only active listings past their time expire; anything else is left alone (idempotent sweeps).
function Auction.expire(listing: Listing?, now: number): (boolean, string?)
	if not listing or listing.status ~= "active" then
		return false, "auction.error.gone"
	end
	if listing.expiresAt > now then
		return false, "auction.error.notExpired"
	end
	listing.status = "expired"
	listing.closedAt = now
	return true, nil
end

-- Price history -----------------------------------------------------------------------------------

function Auction.pushHistory(history: { number }?, price: number): { number }
	local list = if history then table.clone(history) else {}
	table.insert(list, price)
	while #list > Rules.historySize do
		table.remove(list, 1)
	end
	return list
end

-- Average price per unit, nil without history.
function Auction.average(history: { number }?): number?
	if not history or #history == 0 then
		return nil
	end
	local sum = 0
	for _, price in history do
		sum += price
	end
	return math.floor(sum / #history + 0.5)
end

return Auction
