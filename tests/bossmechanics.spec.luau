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
