--!strict
-- S22: monster leash and out-of-combat regeneration (Logic/Leash).

local Combat = require("../src/shared/Data/Combat")
local Leash = require("../src/shared/Logic/Leash")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local cfg = Combat :: any

local function situation(distHome: number, sinceHit: number, hasTarget: boolean?, stuckFor: number?): Leash.Situation
	return {
		distHome = distHome,
		sinceHit = sinceHit,
		hasTarget = if hasTarget == nil then true else hasTarget,
		stuckFor = stuckFor or 0,
	}
end

describe("Leash", function()
	it("keeps fighting inside the soft leash", function()
		expect((Leash.shouldReturn(situation(30, 100), cfg))).toBe(false)
		expect((Leash.shouldReturn(situation(cfg.leashRange - 1, 100), cfg))).toBe(false)
	end)

	it("keeps fighting past the soft leash while being hit", function()
		expect((Leash.shouldReturn(situation(cfg.leashRange + 20, 0), cfg))).toBe(false)
		expect((Leash.shouldReturn(situation(cfg.leashRange + 20, cfg.leashGrace - 0.1), cfg))).toBe(false)
	end)

	it("goes home past the soft leash after the grace period", function()
		local back, reason = Leash.shouldReturn(situation(cfg.leashRange + 1, cfg.leashGrace), cfg)
		expect(back).toBe(true)
		expect(reason).toBe("soft")
	end)

	it("always goes home past the hard leash", function()
		local back, reason = Leash.shouldReturn(situation(cfg.leashMax + 1, 0), cfg)
		expect(back).toBe(true)
		expect(reason).toBe("hard")
	end)

	it("goes home without a target or when stuck", function()
		local back, reason = Leash.shouldReturn(situation(5, 0, false), cfg)
		expect(back).toBe(true)
		expect(reason).toBe("target")
		back, reason = Leash.shouldReturn(situation(5, 0, true, cfg.stuckTime), cfg)
		expect(back).toBe(true)
		expect(reason).toBe("stuck")
		expect((Leash.shouldReturn(situation(5, 0, true, cfg.stuckTime - 0.5), cfg))).toBe(false)
	end)

	it("turns back only within the hard leash", function()
		expect(Leash.canReengage(cfg.leashMax, cfg)).toBe(true)
		expect(Leash.canReengage(cfg.leashMax + 1, cfg)).toBe(false)
	end)

	it("regenerates only after the delay, gradually, up to max HP", function()
		expect(Leash.regen(50, 100, cfg.idleRegenDelay - 0.1, 1, cfg)).toBe(50)
		expect(Leash.regen(50, 100, cfg.idleRegenDelay, 1, cfg)).toBeNear(50 + cfg.idleRegenPct, 1e-9)
		expect(Leash.regen(99, 100, 60, 1, cfg)).toBe(100)
		expect(Leash.regen(100, 100, 60, 1, cfg)).toBe(100)
		-- from 10% to full takes (90 / idleRegenPct) seconds
		local hp, t = 10, 0
		while hp < 100 and t < 60 do
			hp = Leash.regen(hp, 100, 60, 0.2, cfg)
			t += 0.2
		end
		expect(t).toBeNear(90 / cfg.idleRegenPct, 0.21)
	end)

	it("returns faster than it walks but slower than before S22", function()
		expect(cfg.returnSpeedMultiplier > 1 and cfg.returnSpeedMultiplier < 1.6).toBe(true)
		expect(cfg.leashMax > cfg.leashRange).toBe(true)
	end)
end)
