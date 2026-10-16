--!strict
-- S134e: the kit of Elites / Elites II (Logic/MonsterCast, Data/MonsterAbilities.KITS): the server's pick, the landing
-- check of a leap, the lethal blow's level ramp and the throw's.

local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterCast = require("../src/shared/Logic/MonsterCast")
local T = require("./Test")

local KIT = MonsterAbilities.KITS.elite2
local CRUSH = MonsterAbilities.get("crush") :: MonsterAbilities.Ability
local POUNCE = MonsterAbilities.get("pounce") :: MonsterAbilities.Ability
local OWN = MonsterAbilities.get("slam") :: MonsterAbilities.Ability -- circle 11 around itself

local function state(over: { [string]: any }?): MonsterCast.State
	local s: any = {
		now = 100,
		distance = 5,
		reach = 6,
		outOfReachFor = 0,
		ready = { crush = false, pounce = false, slam = false },
		lastCast = -math.huge,
		kit = KIT,
		own = OWN,
		throwReady = true,
	}
	for k, v in over or {} do
		s[k] = v
	end
	return s
end

T.describe("MonsterCast (S134e)", function()
	T.it("the Elite II kit: Crushing Blow and Pounce, a throw, gaps; the Elite kit: Heavy Blow", function()
		T.expect(KIT.abilities).toEqual({ "crush", "pounce" })
		T.expect(KIT.globalGap > 0 and (KIT.kiteSeconds or 0) > 0).toBe(true)
		local throw = KIT.throw :: MonsterAbilities.ThrowSpec
		T.expect(throw.range >= 35 and throw.intervalMul >= 1 and throw.damage > 0).toBe(true)
		T.expect(MonsterAbilities.KITS.elite.abilities).toEqual({ "heavyBlow" })
		T.expect(MonsterAbilities.kit("normal")).toBeNil()
		for variant, kit in MonsterAbilities.KITS do
			for _, id in kit.abilities do
				T.expect({ variant, id, MonsterAbilities.get(id) ~= nil }).toEqual({ variant, id, true })
			end
		end
		-- the reaction times of the rules (zasada 5): lethal >= 2.0 s, Pounce >= 1.2 s, Heavy Blow >= 1.6 s
		T.expect(CRUSH.lethal == true and CRUSH.windup >= 2.0 and CRUSH.canCrit == false).toBe(true)
		T.expect(CRUSH.origin == "target" and (CRUSH.castRange or 0) > 35).toBe(true)
		T.expect(POUNCE.windup >= 1.2 and POUNCE.kiteOnly == true and POUNCE.leap == true).toBe(true)
		local heavy = MonsterAbilities.get("heavyBlow") :: MonsterAbilities.Ability
		T.expect(heavy.windup >= 1.6 and heavy.lethal == nil and heavy.gapRamp == nil).toBe(true)
		for id, ability in MonsterAbilities.byId do
			if ability.lethal then
				T.expect({ id, ability.windup >= 2.0, ability.avoid }).toEqual({ id, true, true })
			end
		end
	end)

	T.it("pick: a ready Crushing Blow first, within its castRange only", function()
		local ready = { crush = true, pounce = true, slam = true }
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 40, outOfReachFor = 9 }))).toBe("crush")
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 5 }))).toBe("crush")
		-- past its castRange: no Crushing Blow (and Pounce has the same range)
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 46, outOfReachFor = 9 }))).toBeNil()
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 46 }))).toBeNil()
	end)

	T.it("pick: Pounce only at a target fleeing for kiteSeconds and 12-45 studs away", function()
		local ready = { crush = false, pounce = true, slam = false }
		local kite = KIT.kiteSeconds :: number
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 20, outOfReachFor = kite }))).toBe("pounce")
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 20, outOfReachFor = kite - 0.1 }))).toBeNil()
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 11, outOfReachFor = kite }))).toBe("throw")
		T.expect(MonsterCast.pick(state({ ready = ready, distance = 45, outOfReachFor = kite }))).toBe("pounce")
	end)

	T.it("pick: the own ability in its old range; the throw at a fleeing target with nothing ready", function()
		T.expect(MonsterCast.pick(state({ ready = { slam = true }, distance = 10 }))).toBe("slam")
		T.expect(MonsterCast.pick(state({ ready = { slam = true }, distance = 12 }))).toBeNil()
		local kite = KIT.kiteSeconds :: number
		T.expect(MonsterCast.pick(state({ distance = 30, outOfReachFor = kite }))).toBe("throw")
		T.expect(MonsterCast.pick(state({ distance = 30, outOfReachFor = kite, throwReady = false }))).toBeNil()
		T.expect(MonsterCast.pick(state({ distance = 30, outOfReachFor = 1 }))).toBeNil()
		T.expect(MonsterCast.pick(state({ distance = 43, outOfReachFor = kite }))).toBeNil() -- past the throw range
		-- an Elite never throws (its kit has no kiteSeconds and no throw)
		local elite = state({ kit = MonsterAbilities.KITS.elite, own = nil, distance = 30, outOfReachFor = 99 })
		T.expect(MonsterCast.pick(elite)).toBeNil()
		local blow = state({ kit = MonsterAbilities.KITS.elite, own = nil, ready = { heavyBlow = true }, distance = 8 })
		T.expect(MonsterCast.pick(blow)).toBe("heavyBlow")
	end)

	T.it("pick: no ability within globalGap after the last one (the throw may come)", function()
		local ready = { crush = true, pounce = true, slam = true }
		local kite = KIT.kiteSeconds :: number
		local just = 100 - KIT.globalGap + 0.1
		T.expect(MonsterCast.pick(state({ ready = ready, lastCast = just, distance = 5 }))).toBeNil()
		T.expect(MonsterCast.pick(state({ ready = ready, lastCast = just, distance = 30, outOfReachFor = kite })))
			.toBe("throw")
		T.expect(MonsterCast.pick(state({ ready = ready, lastCast = 100 - KIT.globalGap, distance = 5 }))).toBe("crush")
	end)

	T.it("canLand: not in a safe zone, not past the hard leash", function()
		T.expect(MonsterCast.canLand(false, 40, 150)).toBe(true)
		T.expect(MonsterCast.canLand(true, 40, 150)).toBe(false)
		T.expect(MonsterCast.canLand(false, 151, 150)).toBe(false)
		T.expect(MonsterCast.canLand(false, 150, 150)).toBe(true)
	end)

	T.it("lethalMul: 1 for no advantage or a higher player, grows up to maxSteps, nothing for other blows", function()
		local ramp = CRUSH.gapRamp :: MonsterAbilities.GapRamp
		T.expect(MonsterCast.lethalMul(CRUSH, 66, 66)).toBe(1)
		T.expect(MonsterCast.lethalMul(CRUSH, 50, 66)).toBe(1)
		T.expect(MonsterCast.lethalMul(CRUSH, 66, 66 - ramp.from)).toBeNear(1 + ramp.perLevel, 1e-9)
		local full = 1 + ramp.maxSteps * ramp.perLevel
		T.expect(MonsterCast.lethalMul(CRUSH, 66, 66 - ramp.from - ramp.maxSteps + 1)).toBeNear(full, 1e-9)
		T.expect(MonsterCast.lethalMul(CRUSH, 66, 30)).toBeNear(full, 1e-9)
		T.expect(MonsterCast.lethalMul(OWN, 66, 30)).toBe(1)
		T.expect(MonsterCast.lethalMul(MonsterAbilities.get("heavyBlow") :: any, 66, 30)).toBe(1)
		local unramped = table.clone(CRUSH)
		unramped.gapRamp = nil
		T.expect(MonsterCast.lethalMul(unramped, 66, 30)).toBe(1)
	end)

	T.it("throwMul: the throw's damage, x its ramp below the monster only", function()
		local throw = KIT.throw :: MonsterAbilities.ThrowSpec
		T.expect(MonsterCast.throwMul(throw, 66, 66)).toBe(throw.damage)
		T.expect(MonsterCast.throwMul(throw, 66, 80)).toBe(throw.damage)
		local ramp = throw.gapRamp :: MonsterAbilities.GapRamp
		T.expect(MonsterCast.throwMul(throw, 66, 66 - 100))
			.toBeNear(throw.damage * (1 + ramp.maxSteps * ramp.perLevel), 1e-9)
		T.expect(MonsterCast.throwMul(throw, 66, 65) > throw.damage).toBe(true)
	end)

	T.it("firstReady: Crushing Blow after 6-9 s, the rest after 3-6 s", function()
		T.expect(MonsterCast.firstReady(CRUSH, 0)).toBe(6)
		T.expect(MonsterCast.firstReady(CRUSH, 1)).toBe(9)
		T.expect(MonsterCast.firstReady(POUNCE, 0.5)).toBe(4.5)
	end)
end)
