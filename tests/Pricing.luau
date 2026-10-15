--!strict
-- Price review of the premium shop (S131, DESIGN-17 §9). Pure: reads Data/Products, Data/Cosmetics, Config and
-- Logic/WeeklyOffer, no randomness. Used by tests/premium.spec.luau ("Prices (S131)") and tools/shop_report.luau
-- (docs/SKLEP-ID.md). A tool, not game data: PROPOSED holds prices for the Creator Hub that live nowhere in the game
-- (the VIP subscription is a Roblox price tier set in the Creator Hub).
--
--   packRates()          -> every shard pack: shards, Robux, shards per Robux, bonus over the smallest pack
--   robuxOf(so)          -> Robux of `so` shards at the best and at the worst pack rate
--   shopTable()          -> every shop entry and cosmetic price range by kind, with its cost in Robux
--   vipMonth(robux)      -> the daily shards of a 30-day month against a proposed subscription price
--   starterPacks()       -> the shards of each starter pack in Robux (smallest pack rate) against its price
--   PROPOSED             -> proposals for the Creator Hub (not game data)

local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Products = require("../src/shared/Data/Products")
local WeeklyOffer = require("../src/shared/Logic/WeeklyOffer")

local Pricing = {}

export type PackRate = { key: string, shards: number, robux: number, perRobux: number, bonusPct: number }
export type ShopRow = {
	key: string,
	cat: string,
	so: number,
	perUnit: number?,
	robuxCheap: number,
	robuxDear: number,
	limit: string?,
}
export type RangeRow = { kind: string, n: number, min: number, median: number, max: number }

-- Proposal for the Creator Hub, not game data (DECYZJE S131): the VIP subscription in Robux a month (KATALOG.md).
Pricing.PROPOSED = table.freeze({
	vipSubscription = 349,
	privateServer = 100, -- Robux a month, set in the game settings (KATALOG.md)
})

local function round2(n: number): number
	return math.floor(n * 100 + 0.5) / 100
end

function Pricing.packRates(): { PackRate }
	local out: { PackRate } = {}
	local base: number? = nil
	for _, pack in Products.shardPacks do
		local rate = pack.shards / pack.robux
		base = base or rate
		table.insert(out, {
			key = pack.key,
			shards = pack.shards,
			robux = pack.robux,
			perRobux = rate,
			bonusPct = round2((rate / (base :: number) - 1) * 100),
		})
	end
	return out
end

-- (cheapest, dearest) rate in shards per Robux over the packs.
local function rates(): (number, number)
	local best, worst = 0, math.huge
	for _, r in Pricing.packRates() do
		best = math.max(best, r.perRobux)
		worst = math.min(worst, r.perRobux)
	end
	return best, worst
end

function Pricing.robuxOf(so: number): { cheapest: number, dearest: number }
	local best, worst = rates()
	return { cheapest = round2(so / best), dearest = round2(so / worst) }
end

function Pricing.shopTable(): { ShopRow }
	local out: { ShopRow } = {}
	for _, e in Products.shop do
		local r = Pricing.robuxOf(e.price)
		local n = e.n or 1
		local limit = if e.dailyLimit
			then `{e.dailyLimit}/dzień`
			elseif e.weeklyLimit then `{e.weeklyLimit}/tydzień`
			else nil
		table.insert(out, {
			key = e.key,
			cat = e.cat,
			so = e.price,
			perUnit = if n > 1 then round2(e.price / n) else nil,
			robuxCheap = r.cheapest,
			robuxDear = r.dearest,
			limit = limit,
		})
	end
	return out
end

-- Price ranges of the cosmetics sold for shards (price > 0, not free), by kind in Data/Cosmetics.kinds order.
function Pricing.cosmeticRanges(): { RangeRow }
	local byKind: { [string]: { number } } = {}
	for _, def in Cosmetics.list do
		if def.price > 0 and (def :: any).free ~= true then
			local list = byKind[def.kind] or {}
			table.insert(list, def.price)
			byKind[def.kind] = list
		end
	end
	local out: { RangeRow } = {}
	for _, kind in Cosmetics.kinds do
		local list = byKind[kind]
		if list then
			table.sort(list)
			table.insert(out, {
				kind = kind,
				n = #list,
				min = list[1],
				median = list[(#list + 1) // 2],
				max = list[#list],
			})
		end
	end
	return out
end

function Pricing.vipMonth(
	proposedRobux: number
): { so: number, robuxValueCheap: number, robuxValueDear: number, ratio: number }
	local so = Config.Vip.dailyShards * 30
	local r = Pricing.robuxOf(so)
	return {
		so = so,
		robuxValueCheap = r.cheapest,
		robuxValueDear = r.dearest,
		ratio = round2(r.dearest / proposedRobux),
	}
end

function Pricing.starterPacks(): { { key: string, robux: number, so: number, soValueRobux: number, extras: string } }
	local out = {}
	local _, worst = rates()
	for _, pack in Products.starterPacks do
		local extras = {}
		for _, id in pack.cosmetics do
			table.insert(extras, id)
		end
		for _, key in pack.passes do
			table.insert(extras, `pass:{key}`)
		end
		table.insert(out, {
			key = pack.key,
			robux = pack.robux,
			so = pack.shards,
			soValueRobux = round2(pack.shards / worst),
			extras = table.concat(extras, ", "),
		})
	end
	return out
end

-- Every price in shards the shop and the wardrobe ask (entries and cosmetics for sale), with its key.
function Pricing.allShardPrices(): { { key: string, so: number } }
	local out = {}
	for _, e in Products.shop do
		table.insert(out, { key = e.key, so = e.price })
	end
	for _, def in Cosmetics.list do
		if def.price > 0 then
			table.insert(out, { key = def.id, so = def.price })
		end
	end
	return out
end

-- The weekly offer price (S123 discount) of every cosmetic in the weekly pool.
function Pricing.weeklyPrices(): { { id: string, price: number, offer: number } }
	local out = {}
	for _, id in WeeklyOffer.pool() do
		local def = Cosmetics.get(id)
		if def then
			table.insert(out, { id = id, price = def.price, offer = WeeklyOffer.discountedPrice(def.price) })
		end
	end
	return out
end

return Pricing
