--!strict
-- S134 (bosses 2.0): the pure rules of the boss mechanics (Logic/BossMechanics), read by the server and the model.

local BossMechanics = require("../src/shared/Logic/BossMechanics")
local T = require("./Test")

T.describe("BossMechanics (S134)", function()
	T.it("splitShare shares the blow among 1-5 players, nobody inside = missAll on everyone", function()
		for inside = 1, 5 do
			T.expect(BossMechanics.splitShare(20, inside, 0.25)).toBeNear(20 / inside, 1e-9)
		end
		T.expect(BossMechanics.splitShare(20, 0, 0.25)).toBeNear(5, 1e-9)
		T.expect(BossMechanics.splitShare(20, 0, 0)).toBe(0)
		-- three players together take less each than one alone, and the sum stays the blow
		T.expect(BossMechanics.splitShare(20, 3, 0.25) * 3).toBeNear(20, 1e-9)
	end)

	T.it("markDamage: the marked one takes damage x self, the others the whole damage", function()
		local spec = { seconds = 5, self = 0.4 }
		T.expect(BossMechanics.markDamage(true, 10, spec)).toBeNear(4, 1e-9)
		T.expect(BossMechanics.markDamage(false, 10, spec)).toBe(10)
	end)

	T.it(
		"channelBroken: the share of the max HP taken off since the start; healing the boss never breaks it",
		function()
			T.expect(BossMechanics.channelBroken(10000, 9600, 10000, 0.04)).toBe(true)
			T.expect(BossMechanics.channelBroken(10000, 9601, 10000, 0.04)).toBe(false)
			-- the boss healed above its start: nothing done, not broken
			T.expect(BossMechanics.channelBroken(5000, 5600, 10000, 0.04)).toBe(false)
			T.expect(BossMechanics.channelDone(5000, 5600, 10000)).toBe(0)
			T.expect(BossMechanics.channelDone(5000, 4500, 10000)).toBeNear(0.05, 1e-9)
			-- an already broken share stays broken however low the boss is
			T.expect(BossMechanics.channelBroken(800, 0, 10000, 0.04)).toBe(true)
		end
	)

	T.it("breakSeconds: breakPct x max HP / dps", function()
		T.expect(BossMechanics.breakSeconds(0.012, 100000, 400)).toBeNear(3, 1e-9)
		T.expect(BossMechanics.breakSeconds(0.012, 100000, 0) > 1e6).toBe(true)
	end)

	T.it("isAvoidable: only `avoid` attacks without a mechanic", function()
		T.expect(BossMechanics.isAvoidable({ avoid = true })).toBe(true)
		T.expect(BossMechanics.isAvoidable({})).toBe(false)
		T.expect(BossMechanics.isAvoidable({ avoid = true, mechanic = "split" })).toBe(false)
		T.expect(BossMechanics.isAvoidable({ mechanic = "channel" })).toBe(false)
	end)
end)

-- S149: a mark brands `count` fighters at once (the world boss: three).
T.describe("BossMechanics: marks with count (S149)", function()
	local Rng = require("../src/shared/Logic/Rng")

	local function roller(seed: number): (number, number) -> number
		local rng = Rng.new(seed)
		return function(lo: number, hi: number): number
			return rng:int(lo, hi)
		end
	end

	T.it("count defaults to 1; pickMarked picks min(count, fighters) without repeats", function()
		T.expect(BossMechanics.markCount({ seconds = 5, self = 0.4 })).toBe(1)
		T.expect(BossMechanics.markCount({ seconds = 5, self = 0.4, count = 3 })).toBe(3)
		for seed = 1, 50 do
			for fighters = 1, 12 do
				local picks = BossMechanics.pickMarked(fighters, 3, roller(seed))
				T.expect(#picks).toBe(math.min(3, fighters))
				local seen: { [number]: boolean } = {}
				for _, i in picks do
					T.expect(i >= 1 and i <= fighters and not seen[i]).toBe(true)
					seen[i] = true
				end
			end
		end
		-- count 1 rolls exactly once (the S134 boss's choice and Random use are unchanged)
		local calls = 0
		local picks = BossMechanics.pickMarked(5, 1, function(lo: number, hi: number): number
			calls += 1
			T.expect({ lo, hi }).toEqual({ 1, 5 })
			return 4
		end)
		T.expect(picks).toEqual({ 4 })
		T.expect(calls).toBe(1)
	end)

	T.it("markTaken: the own circle x self, every other branded circle the whole blow (overlaps add up)", function()
		local spec = { seconds = 5, self = 0.43, count = 3 }
		T.expect(BossMechanics.markTaken(true, 0, 10, spec)).toBeNear(4.3, 1e-9)
		T.expect(BossMechanics.markTaken(false, 1, 10, spec)).toBe(10)
		T.expect(BossMechanics.markTaken(false, 0, 10, spec)).toBe(0)
		-- a branded one inside another branded one's circle: its own share and the other's full blow
		T.expect(BossMechanics.markTaken(true, 1, 10, spec)).toBeNear(14.3, 1e-9)
		T.expect(BossMechanics.markTaken(true, 2, 10, spec)).toBeNear(24.3, 1e-9)
	end)
end)
