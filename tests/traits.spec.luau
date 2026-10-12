--!strict
local Combat = require("../src/shared/Data/Combat")
local Damage = require("../src/shared/Logic/Damage")
local Rng = require("../src/shared/Logic/Rng")
local Traits = require("../src/shared/Logic/Traits")
local T = require("./Test")

T.describe("Traits: on-hit chances (S63)", function()
	T.it("gives every hit its share", function()
		T.expect(Traits.procShare(nil)).toBe(1)
		T.expect(Traits.procShare({ basic = true })).toBe(1)
		T.expect(Traits.procShare({})).toBe(1)
		T.expect(Traits.procShare({ area = true })).toBeNear(1 / 3)
		T.expect(Traits.procShare({ basic = true, noProc = true })).toBe(0)
	end)

	T.it("knows area skills", function()
		for _, kind in { "target", "projectile", "charge" } do
			T.expect({ kind, Traits.isAreaSkill(kind) }).toEqual({ kind, false })
		end
		for _, kind in { "cone", "circleSelf", "circleTarget", "line", "chain" } do
			T.expect({ kind, Traits.isAreaSkill(kind) }).toEqual({ kind, true })
		end
		T.expect(Traits.isAreaSkill(nil)).toBe(false)
	end)

	T.it("caps the chance of one effect", function()
		T.expect(Traits.chance(15, 0, 1)).toBe(15)
		T.expect(Traits.chance(15, 30, 1)).toBe(40)
		T.expect(Traits.chance(15, 30, 1 / 3)).toBeNear(13.333, 0.001)
	end)
end)

T.describe("Traits: damage over time (S63)", function()
	T.it("divides by the ticks really dealt", function()
		T.expect(Traits.ticks(4)).toBe(3)
		T.expect(Traits.ticks(5)).toBe(4)
		T.expect(Traits.ticks(2)).toBe(1)
		local tick = Traits.dotTick(1000, 30, 4, 0)
		T.expect(tick).toBe(100)
		T.expect(tick * Traits.ticks(4)).toBe(300)
		T.expect(Traits.dotTick(1000, 30, 4, 50)).toBe(150)
		T.expect(Traits.dotTick(1, 30, 4, 0)).toBe(1)
	end)

	T.it("applies the PvP multiplier exactly once", function()
		local attacker: Damage.Attacker = { level = 10, physAtk = 500, magAtk = 0, critChance = 0, critDmg = 150 }
		local defender: Damage.Defender = { armor = 100, mres = 0 }
		local plain = Damage.computeDamage(attacker, defender, { kind = "phys" }, Rng.new(7))
		local pvp = Damage.computeDamage(attacker, defender, { kind = "phys", pvp = true }, Rng.new(7))
		T.expect(pvp.dotBase).toBe(plain.dotBase)
		local base = Traits.dotTick(plain.dotBase :: number, 30, 4, 0)
		local inPvp = Traits.pvpTick(Traits.dotTick(pvp.dotBase :: number, 30, 4, 0))
		T.expect(inPvp).toBeNear(base * Combat.pvp.dot)
	end)

	T.it("scales trait values against players", function()
		T.expect(Traits.pvpValue(6, 0.5)).toBe(3)
		T.expect(Traits.pvpValue(6, nil)).toBe(6)
	end)
end)

T.describe("Traits: armour, attack slow, gaps, resource (S63)", function()
	T.it("caps armour break from items", function()
		T.expect(Traits.armorBreakCap(5, 5)).toBe(25)
		T.expect(Traits.armorBreakCap(9.4, 5)).toBe(40)
	end)

	T.it("slows attacks up to the cap", function()
		T.expect(Traits.slowedInterval(2, 20)).toBeNear(2.5)
		T.expect(Traits.slowedInterval(2, 50)).toBeNear(2.5)
		T.expect(Traits.slowedInterval(2, 0)).toBe(2)
	end)

	T.it("waits for the gap", function()
		T.expect(Traits.gapReady(nil, 100, 8)).toBe(true)
		T.expect(Traits.gapReady(100, 107.9, 8)).toBe(false)
		T.expect(Traits.gapReady(100, 108, 8)).toBe(true)
	end)

	T.it("refunds at most 1 % of the resource per gap", function()
		T.expect(Traits.resourceOnHit(0.5, 200, nil, 10)).toBe(1)
		T.expect(Traits.resourceOnHit(1.8, 200, nil, 10)).toBe(2)
		T.expect(Traits.resourceOnHit(0.5, 200, 9.8, 10)).toBe(0)
		T.expect(Traits.resourceOnHit(0, 200, nil, 10)).toBe(0)
	end)
end)

return nil
