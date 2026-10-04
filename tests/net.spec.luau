--!strict
-- Pure building blocks of the Net layer: argument checks and rate limiting.
local ArgCheck = require("../src/shared/Logic/ArgCheck")
local RateLimit = require("../src/shared/Logic/RateLimit")
local T = require("./Test")

T.describe("ArgCheck", function()
	T.it("accepts matching arguments", function()
		T.expect((ArgCheck.check({ 1, "Aria", "Warrior" }, { "integer", "string", "string" }))).toBe(true)
		T.expect((ArgCheck.check({ true, {} }, { "boolean", "table" }))).toBe(true)
		T.expect((ArgCheck.check({}, {}))).toBe(true)
	end)

	T.it("handles optional arguments", function()
		T.expect((ArgCheck.check({ "x" }, { "string", "number?" }))).toBe(true)
		T.expect((ArgCheck.check({ "x", 2 }, { "string", "number?" }))).toBe(true)
		T.expect((ArgCheck.check({ "x", "2" }, { "string", "number?" }))).toBe(false)
	end)

	T.it("rejects missing, extra and wrong arguments", function()
		T.expect((ArgCheck.check({}, { "string" }))).toBe(false)
		T.expect((ArgCheck.check({ "a", "b" }, { "string" }))).toBe(false)
		T.expect((ArgCheck.check({ 5 }, { "string" }))).toBe(false)
		-- Trailing nils still count as extra arguments when the caller passes select("#").
		T.expect((ArgCheck.check({ "a" }, { "string" }, 3))).toBe(false)
	end)

	T.it("rejects NaN, infinity and fractional integers", function()
		T.expect((ArgCheck.check({ 0 / 0 }, { "number" }))).toBe(false)
		T.expect((ArgCheck.check({ math.huge }, { "number" }))).toBe(false)
		T.expect((ArgCheck.check({ -math.huge }, { "integer" }))).toBe(false)
		T.expect((ArgCheck.check({ 1.5 }, { "integer" }))).toBe(false)
		T.expect((ArgCheck.check({ 1.5 }, { "number" }))).toBe(true)
	end)

	T.it("caps string length", function()
		T.expect((ArgCheck.check({ string.rep("a", ArgCheck.MAX_STRING) }, { "string" }))).toBe(true)
		T.expect((ArgCheck.check({ string.rep("a", ArgCheck.MAX_STRING + 1) }, { "string" }))).toBe(false)
	end)
end)

T.describe("RateLimit", function()
	T.it("allows a burst then blocks", function()
		local limiter = RateLimit.new(1, 3)
		T.expect(limiter:take("p", 0)).toBe(true)
		T.expect(limiter:take("p", 0)).toBe(true)
		T.expect(limiter:take("p", 0)).toBe(true)
		T.expect(limiter:take("p", 0)).toBe(false)
	end)

	T.it("refills over time up to the burst", function()
		local limiter = RateLimit.new(2, 2)
		limiter:take("p", 0)
		limiter:take("p", 0)
		T.expect(limiter:take("p", 0.1)).toBe(false)
		T.expect(limiter:take("p", 0.6)).toBe(true)
		-- A long pause never stores more than the burst.
		T.expect(limiter:take("p", 100)).toBe(true)
		T.expect(limiter:take("p", 100)).toBe(true)
		T.expect(limiter:take("p", 100)).toBe(false)
	end)

	T.it("keeps keys independent and clears by prefix", function()
		local limiter = RateLimit.new(1, 1)
		T.expect(limiter:take("1:A", 0)).toBe(true)
		T.expect(limiter:take("2:A", 0)).toBe(true)
		T.expect(limiter:take("1:A", 0)).toBe(false)
		limiter:clearPrefix("1:")
		T.expect(limiter:take("1:A", 0)).toBe(true)
		T.expect(limiter:take("2:A", 0)).toBe(false)
	end)

	T.it("defaults the burst to twice the rate (at least 2)", function()
		T.expect(RateLimit.new(0.5).burst).toBe(2)
		T.expect(RateLimit.new(5).burst).toBe(10)
	end)
end)

return nil
