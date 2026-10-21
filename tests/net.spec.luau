--!strict
-- Pure building blocks of the Net layer: argument checks and rate limiting.
local ArgCheck = require("../src/shared/Logic/ArgCheck")
local Definitions = require("../src/shared/Net/Definitions")
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
		-- owner 2026-10-20: trailing nils are no arguments (a caller passing an optional value it does not have); a
		-- real extra value still is
		T.expect((ArgCheck.check({ "a" }, { "string" }, 3))).toBe(true)
		T.expect((ArgCheck.check({ "a", nil, 5 }, { "string" }, 3))).toBe(false)
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

T.describe("Definitions", function()
	T.it("CastSkill accepts every client call shape (regression: aim was required)", function()
		local spec = assert(Definitions.CastSkill.args, "CastSkill has args")
		T.expect((ArgCheck.check({ "id" }, spec, 1))).toBe(true)
		T.expect((ArgCheck.check({ "id", "m1" }, spec, 2))).toBe(true)
		T.expect((ArgCheck.check({ "id", nil, { x = 1 } }, spec, 3))).toBe(true)
		T.expect((ArgCheck.check({ "id", "m1", nil }, spec, 3))).toBe(true)
		T.expect((ArgCheck.check({ "id", nil, nil }, spec, 3))).toBe(true)
		T.expect((ArgCheck.check({}, spec, 0))).toBe(false)
	end)

	T.it("S101b: QuestSay takes a quest id and an answer id, rate 4", function()
		local def = Definitions.QuestSay
		T.expect(def.kind).toBe("function")
		T.expect(def.dir).toBe("c2s")
		T.expect(def.rate).toBe(4)
		T.expect(def.args).toEqual({ "string", "string" })
		T.expect((ArgCheck.check({ "side_bears", "quiet" }, assert(def.args, "expected a value"), 2))).toBe(true)
		T.expect((ArgCheck.check({ "side_bears" }, assert(def.args, "expected a value"), 1))).toBe(false)
	end)

	T.it("S102: CutsceneDone takes a scene id, rate 4", function()
		local def = Definitions.CutsceneDone
		T.expect(def.kind).toBe("function")
		T.expect(def.dir).toBe("c2s")
		T.expect(def.rate).toBe(4)
		T.expect(def.args).toEqual({ "string" })
		T.expect((ArgCheck.check({ "ch1_open" }, assert(def.args, "expected a value"), 1))).toBe(true)
		T.expect((ArgCheck.check({ 5 }, assert(def.args, "expected a value"), 1))).toBe(false)
	end)

	T.it("every c2s remote has well-formed argument rules", function()
		local known = { string = true, number = true, integer = true, boolean = true, table = true, any = true }
		for name, def in Definitions do
			if def.dir == "s2c" then
				continue
			end
			T.expect(def.args ~= nil).toBe(true)
			T.expect(type(def.rate) == "number" and (def.rate :: number) > 0).toBe(true)
			local seenOptional = false
			for i, rule in def.args or {} do
				local optional = string.sub(rule, -1) == "?"
				local kind = if optional then string.sub(rule, 1, -2) else rule
				if not known[kind] then
					error(`{name}: unknown rule '{rule}' at {i}`)
				end
				if seenOptional and not optional then
					error(`{name}: required argument {i} after an optional one`)
				end
				seenOptional = seenOptional or optional
			end
		end
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

	T.it("audit 2026-10-21: guild vault items move 5 at once, then 2 a second", function()
		for _, name in { "GuildPutItem", "GuildTakeItem", "GuildMoveVault" } do
			local def = Definitions[name]
			T.expect(def.burst).toBe(5)
			local limiter = RateLimit.new(def.rate :: number, def.burst)
			for _ = 1, 5 do
				T.expect(limiter:take("p", 0)).toBe(true)
			end
			T.expect(limiter:take("p", 0)).toBe(false)
			T.expect(limiter:take("p", 0.5)).toBe(true)
			T.expect(limiter:take("p", 0.5)).toBe(false)
			-- a minute of steady clicking gets at most 2 a second past the burst
			local passed = 0
			for i = 1, 600 do
				if limiter:take("p", 0.5 + i * 0.1) then
					passed += 1
				end
			end
			T.expect(passed <= 121).toBe(true)
		end
	end)

	T.it("defaults the burst to twice the rate (at least 2)", function()
		T.expect(RateLimit.new(0.5).burst).toBe(2)
		T.expect(RateLimit.new(5).burst).toBe(10)
	end)
end)

return nil
