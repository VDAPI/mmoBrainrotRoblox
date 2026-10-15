--!strict
-- Offer of the week (S123, DESIGN-17 §4): the pool, the same offer everywhere, no repeats of the previous week, the
-- rotation over the whole pool, the week bounds (Monday 00:00 UTC) and the one price rule.

local Cosmetics = require("../src/shared/Data/Cosmetics")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")
local WeeklyOffer = require("../src/shared/Logic/WeeklyOffer")

local MONDAY = 1791763200 -- 2026-10-12 00:00 UTC, week 2963 (S98)
local WEEK = 7 * 86400

T.describe("Offer of the week (S123)", function()
	T.it("the pool: at least 30 sold cosmetics, sorted by id", function()
		local pool = WeeklyOffer.pool()
		T.expect(#pool >= 30).toBe(true)
		for i, id in pool do
			local def = Cosmetics.get(id) :: Cosmetics.Def
			T.expect({ id, def.price > 0, def.obtain, def.free }).toEqual({ id, true, nil, nil })
			if i > 1 then
				T.expect({ id, pool[i - 1] < id }).toEqual({ id, true })
			end
		end
	end)

	T.it("four different cosmetics of the pool, one discounted, the same every time and in any file order", function()
		local offer = WeeklyOffer.forWeek(2963)
		T.expect(#offer.items).toBe(Cosmetics.weekly.size)
		T.expect(offer.week).toBe(2963)
		T.expect(offer.discount).toBe(0.3)
		local pool = WeeklyOffer.pool()
		local seen: { [string]: boolean } = {}
		for _, id in offer.items do
			T.expect({ id, seen[id] }).toEqual({ id, nil })
			seen[id] = true
			T.expect({ id, table.find(pool, id) ~= nil }).toEqual({ id, true })
		end
		T.expect(seen[offer.discounted]).toBe(true)
		T.expect(WeeklyOffer.forWeek(2963)).toEqual(offer)
		local shuffled = table.clone(Cosmetics.list)
		Rng.new(42):shuffle(shuffled)
		T.expect(WeeklyOffer.forWeek(2963, WeeklyOffer.pool(shuffled))).toEqual(offer)
	end)

	-- S132: 200 weeks (the pool grew by the class outfits)
	T.it("200 weeks: no repeat of the previous week, the whole pool rotates, discounts spread over kinds", function()
		local pool = WeeklyOffer.pool()
		local seen: { [string]: boolean } = {}
		local kinds: { [string]: boolean } = {}
		for week = 2963, 3162 do
			local offer = WeeklyOffer.forWeek(week)
			local before = WeeklyOffer.raw(week - 1)
			for _, id in offer.items do
				T.expect({ week, id, table.find(before, id) }).toEqual({ week, id, nil })
				seen[id] = true
			end
			kinds[(Cosmetics.get(offer.discounted) :: Cosmetics.Def).kind] = true
		end
		for _, id in pool do
			T.expect({ id, seen[id] }).toEqual({ id, true })
		end
		local n = 0
		for _ in kinds do
			n += 1
		end
		T.expect(n >= 4).toBe(true)
	end)

	T.it("the week runs from Monday 00:00 to Sunday 23:59:59 UTC", function()
		T.expect(WeeklyOffer.at(MONDAY)).toEqual(WeeklyOffer.forWeek(2963))
		T.expect(WeeklyOffer.at(MONDAY + WEEK - 1)).toEqual(WeeklyOffer.at(MONDAY))
		T.expect(WeeklyOffer.at(MONDAY + WEEK).week).toBe(2964)
		T.expect(WeeklyOffer.endsAt(MONDAY)).toBe(MONDAY + WEEK)
		T.expect(WeeklyOffer.endsAt(MONDAY + WEEK - 1)).toBe(MONDAY + WEEK)
	end)

	T.it("prices: the discounted one -30 % rounded to 5, the rest and unknown ids", function()
		T.expect(WeeklyOffer.discountedPrice(250)).toBe(175)
		T.expect(WeeklyOffer.discountedPrice(150)).toBe(105)
		T.expect(WeeklyOffer.discountedPrice(30)).toBe(20)
		T.expect(WeeklyOffer.discountedPrice(5)).toBe(5)
		local offer = WeeklyOffer.at(MONDAY)
		local discounted = Cosmetics.get(offer.discounted) :: Cosmetics.Def
		T.expect(WeeklyOffer.priceOf(offer.discounted, MONDAY)).toBe(math.floor(discounted.price * 0.7 / 5 + 0.5) * 5)
		for _, id in offer.items do
			if id ~= offer.discounted then
				T.expect(WeeklyOffer.priceOf(id, MONDAY)).toBe((Cosmetics.get(id) :: Cosmetics.Def).price)
			end
		end
		T.expect(WeeklyOffer.priceOf("dye_gold", MONDAY)).toBe(60)
		T.expect(WeeklyOffer.priceOf("nope", MONDAY)).toBeNil()
		T.expect(WeeklyOffer.inOffer(offer.items[1], MONDAY)).toBe(true)
	end)
end)

return nil
