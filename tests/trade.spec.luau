--!strict
-- S10: atomic 1-on-1 trade.

local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")
local Trade = require("../src/shared/Logic/Trade")

local describe, it, expect = Test.describe, Test.it, Test.expect

local counter = 0
local function newUid(): string
	counter += 1
	return `new-{counter}`
end

local function sword(uid: string, bound: boolean?)
	local item = ItemRoll.rollItem("sword1h_10", 10, 2, Rng.new(1), uid)
	item.bound = bound == true
	return item
end

local function potions(uid: string, n: number)
	return ItemRoll.makeStack("potion_hp_1", n, uid)
end

local function side(inv: { [string]: any }, capacity: number, gold: number, uids: { string }, offerGold: number)
	return { inventory = inv, capacity = capacity, gold = gold, offerUids = uids, offerGold = offerGold }
end

local function countItems(inv: { [string]: any }): number
	local n = 0
	for _, item in inv do
		n += item.n
	end
	return n
end

describe("Trade.exchange", function()
	it("swaps items and gold", function()
		local a = side({ ["1"] = sword("a1"), ["2"] = potions("a2", 5) }, 10, 100, { "a1" }, 30)
		local b = side({ ["1"] = potions("b1", 20) }, 10, 50, { "b1" }, 0)
		local result, err = Trade.exchange(a, b, newUid)
		assert(result, err)
		expect(result.goldA).toBe(70)
		expect(result.goldB).toBe(80)
		-- A gave the sword, got 20 potions (stacked onto its 5)
		local hasSword = false
		for _, item in result.inventoryB do
			if item.uid == "a1" then
				hasSword = true
			end
		end
		expect(hasSword).toBe(true)
		expect(countItems(result.inventoryA)).toBe(25)
		expect(next(result.inventoryB) ~= nil).toBe(true)
	end)

	it("does not touch the original backpacks", function()
		local invA = { ["1"] = sword("a1") }
		local a = side(invA, 10, 0, { "a1" }, 0)
		local b = side({}, 10, 0, {}, 0)
		local result = Trade.exchange(a, b, newUid)
		assert(result, "result")
		expect(invA["1"] ~= nil).toBe(true)
		expect(next(result.inventoryA)).toBeNil()
	end)

	it("keeps the total number of items (no duplication)", function()
		local a = side({ ["1"] = sword("a1"), ["2"] = sword("a2"), ["3"] = potions("a3", 7) }, 10, 0, { "a1", "a3" }, 0)
		local b = side({ ["1"] = sword("b1"), ["4"] = potions("b4", 3) }, 10, 0, { "b4" }, 0)
		local result = Trade.exchange(a, b, newUid)
		assert(result, "result")
		expect(countItems(result.inventoryA) + countItems(result.inventoryB)).toBe(1 + 1 + 7 + 1 + 3)
	end)

	it("rejects an item offered twice", function()
		local a = side({ ["1"] = sword("a1") }, 10, 0, { "a1", "a1" }, 0)
		local result, err = Trade.exchange(a, side({}, 10, 0, {}, 0), newUid)
		expect(result).toBeNil()
		expect(err).toBe("trade.error.changed")
	end)

	it("rejects an item that is no longer there", function()
		local a = side({}, 10, 0, { "gone" }, 0)
		local result, err = Trade.exchange(a, side({}, 10, 0, {}, 0), newUid)
		expect(result).toBeNil()
		expect(err).toBe("trade.error.changed")
	end)

	it("rejects bound items", function()
		local a = side({ ["1"] = sword("a1", true) }, 10, 0, { "a1" }, 0)
		local _, err = Trade.exchange(a, side({}, 10, 0, {}, 0), newUid)
		expect(err).toBe("trade.error.bound")
		expect(Trade.canOffer(sword("x", true))).toBe(false)
		expect(Trade.canOffer(sword("y"))).toBe(true)
	end)

	it("rejects missing gold and negative or fractional gold", function()
		local _, err = Trade.exchange(side({}, 10, 10, {}, 20), side({}, 10, 0, {}, 0), newUid)
		expect(err).toBe("trade.error.gold")
		local _, err2 = Trade.exchange(side({}, 10, 10, {}, -5), side({}, 10, 0, {}, 0), newUid)
		expect(err2).toBe("error.badRequest")
		local _, err3 = Trade.exchange(side({}, 10, 10, {}, 1.5), side({}, 10, 0, {}, 0), newUid)
		expect(err3).toBe("error.badRequest")
	end)

	it("rejects when a backpack cannot fit what it receives", function()
		local full = {}
		for i = 1, 3 do
			full[tostring(i)] = sword(`b{i}`)
		end
		local a = side({ ["1"] = sword("a1"), ["2"] = sword("a2") }, 10, 0, { "a1", "a2" }, 0)
		local b = side(full, 3, 0, { "b1" }, 0)
		local _, err = Trade.exchange(a, b, newUid)
		expect(err).toBe("trade.error.space")
	end)

	it("lets a full backpack trade one item for one", function()
		local full = {}
		for i = 1, 3 do
			full[tostring(i)] = sword(`b{i}`)
		end
		local a = side({ ["1"] = sword("a1") }, 10, 0, { "a1" }, 0)
		local b = side(full, 3, 0, { "b1" }, 0)
		local result = Trade.exchange(a, b, newUid)
		expect(result ~= nil).toBe(true)
	end)

	it("limits the table to 12 items", function()
		local inv, uids = {}, {}
		for i = 1, 13 do
			inv[tostring(i)] = sword(`s{i}`)
			table.insert(uids, `s{i}`)
		end
		local _, err = Trade.exchange(side(inv, 20, 0, uids, 0), side({}, 20, 0, {}, 0), newUid)
		expect(err).toBe("trade.error.tooMany")
	end)
end)
