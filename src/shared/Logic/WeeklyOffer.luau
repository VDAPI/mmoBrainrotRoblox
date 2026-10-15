--!strict
-- Offer of the week (S123, DESIGN-17 §4), pure: Data/Cosmetics.WEEKLY.size cosmetics from the `weekly` pool, picked
-- by Logic/Rng seeded with the week number (Monday 00:00 UTC, Logic/Time.weekNumber, the week of the weekly quests),
-- one of them at -discount. Every server and client computes the same offer without any messaging; a new cosmetic
-- added to the pool in a new game version may change the offer of that week on the servers running it (DECYZJE S123).
-- `priceOf` is the only place that prices a cosmetic (shop window, wardrobe, server, admin).

local Cosmetics = require("../Data/Cosmetics")
local Rng = require("./Rng")
local Time = require("./Time")

type Def = Cosmetics.Def

local WEEKLY = Cosmetics.weekly
local SEED_STEP = 7919 -- a prime: consecutive weeks get seeds far apart

local WeeklyOffer = {}

export type Offer = { items: { string }, discounted: string, discount: number, week: number }

-- Ids of the pool (weekly, price > 0, no obtain, not free), sorted by id so the offer never depends on the file order.
function WeeklyOffer.pool(list: { Def }?): { string }
	local out: { string } = {}
	for _, def in list or Cosmetics.list do
		if def.weekly == true and def.price > 0 and def.obtain == nil and def.free ~= true then
			table.insert(out, def.id)
		end
	end
	table.sort(out)
	return out
end

local function shuffled(week: number, pool: { string }): (Rng.Rng, { string })
	local rng = Rng.new(week * SEED_STEP + WEEKLY.salt)
	local copy = table.clone(pool)
	rng:shuffle(copy)
	return rng, copy
end

-- The first WEEKLY.size ids of the week's shuffled pool (no repeat rule; the previous week's offer is checked
-- against this, so forWeek never recurses).
function WeeklyOffer.raw(week: number, pool: { string }?): { string }
	local _, copy = shuffled(week, pool or WeeklyOffer.pool())
	local out: { string } = {}
	for i = 1, math.min(WEEKLY.size, #copy) do
		out[i] = copy[i]
	end
	return out
end

-- The offer of week `week`: like raw, but with a pool of at least two offers nothing of raw(week - 1) comes back
-- (the shuffled list fills the gaps from further on); the discounted one is drawn from the same generator.
function WeeklyOffer.forWeek(week: number, pool: { string }?): Offer
	local ids = pool or WeeklyOffer.pool()
	local rng, copy = shuffled(week, ids)
	local skip: { [string]: boolean } = {}
	if #ids >= 2 * WEEKLY.size then
		for _, id in WeeklyOffer.raw(week - 1, ids) do
			skip[id] = true
		end
	end
	local items: { string } = {}
	for _, id in copy do
		if #items >= WEEKLY.size then
			break
		end
		if not skip[id] then
			table.insert(items, id)
		end
	end
	local discounted = if #items > 0 then items[rng:int(1, #items)] else ""
	return { items = items, discounted = discounted, discount = WEEKLY.discount, week = week }
end

-- The default pool's offers by week (the pool only changes with a new game version).
local cache: { [number]: Offer } = {}
local cacheSize = 0

-- The offer at time `now` (seconds, Util/Clock).
function WeeklyOffer.at(now: number): Offer
	local week = Time.weekNumber(now)
	local hit = cache[week]
	if hit then
		return hit
	end
	if cacheSize > 8 then
		table.clear(cache)
		cacheSize = 0
	end
	local offer = WeeklyOffer.forWeek(week)
	table.freeze(offer.items)
	table.freeze(offer)
	cache[week] = offer
	cacheSize += 1
	return offer
end

-- When the offer of `now` ends (the next Monday 00:00 UTC).
function WeeklyOffer.endsAt(now: number): number
	return Time.weekStart(Time.weekNumber(now) + 1)
end

-- The discounted price of `price`, rounded to WEEKLY.round shards and never below it.
function WeeklyOffer.discountedPrice(price: number): number
	local r = WEEKLY.round
	return math.max(r, math.floor(price * (1 - WEEKLY.discount) / r + 0.5) * r)
end

-- The price of a cosmetic at `now` (the week's discounted one cheaper); nil for an unknown id.
function WeeklyOffer.priceOf(id: string, now: number): number?
	local def = Cosmetics.get(id)
	if not def then
		return nil
	end
	if def.price > 0 and WeeklyOffer.at(now).discounted == id then
		return WeeklyOffer.discountedPrice(def.price)
	end
	return def.price
end

-- Whether the cosmetic is in this week's offer.
function WeeklyOffer.inOffer(id: string, now: number): boolean
	return table.find(WeeklyOffer.at(now).items, id) ~= nil
end

return WeeklyOffer
