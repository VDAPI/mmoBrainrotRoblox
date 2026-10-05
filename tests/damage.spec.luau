--!strict
local Combat = require("../src/shared/Data/Combat")
local Damage = require("../src/shared/Logic/Damage")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")

local function attacker(overrides: { [string]: any }?): Damage.Attacker
	local a: any = {
		level = 10,
		physAtk = 100,
		magAtk = 80,
		critChance = 0,
		critDmg = 150,
		accuracy = 0,
		armorPen = 0,
		lifesteal = 0,
	}
	for k, v in overrides or {} do
		a[k] = v
	end
	return a
end

local function defender(overrides: { [string]: any }?): Damage.Defender
	local d: any = { armor = 0, mres = 0, dodge = 0, res = {} }
	for k, v in overrides or {} do
		d[k] = v
	end
	return d
end

local PHYS: Damage.Params = { kind = "phys" }

T.describe("Damage", function()
	T.it("no defense: damage stays within the random band", function()
		local rng = Rng.new(1)
		for _ = 1, 200 do
			local r = Damage.computeDamage(attacker(), defender(), PHYS, rng)
			T.expect(r.amount).toBeBetween(92, 108)
			T.expect(r.dodged).toBe(false)
		end
	end)

	T.it("never negative, at least 1 on a hit", function()
		local rng = Rng.new(2)
		for _ = 1, 100 do
			local r = Damage.computeDamage(attacker({ physAtk = 0 }), defender({ armor = 1e6 }), PHYS, rng)
			T.expect(r.amount).toBe(1)
		end
		local r = Damage.computeDamage(attacker(), defender(), { kind = "phys", multiplier = -5 }, rng)
		T.expect(r.amount >= 1).toBe(true)
	end)

	T.it("reduction formula", function()
		T.expect(Damage.reduction(0, 10)).toBe(0)
		T.expect(Damage.reduction(600, 10)).toBeNear(600 / (600 + 400 + 200))
		T.expect(Damage.reduction(-50, 10)).toBe(0)
	end)

	T.it("higher attacker level pierces more defense", function()
		T.expect(Damage.reduction(500, 50) < Damage.reduction(500, 5)).toBe(true)
	end)

	T.it("armor penetration only lowers physical defense", function()
		local rngA, rngB = Rng.new(9), Rng.new(9)
		local plain = Damage.computeDamage(attacker(), defender({ armor = 300 }), PHYS, rngA)
		local pierced = Damage.computeDamage(attacker({ armorPen = 300 }), defender({ armor = 300 }), PHYS, rngB)
		T.expect(pierced.amount > plain.amount).toBe(true)
		local magicA = Damage.computeDamage(attacker(), defender({ mres = 300 }), { kind = "magic" }, Rng.new(4))
		local magicB =
			Damage.computeDamage(attacker({ armorPen = 300 }), defender({ mres = 300 }), { kind = "magic" }, Rng.new(4))
		T.expect(magicA.amount).toBe(magicB.amount)
	end)

	T.it("crits multiply by critDmg", function()
		local rng = Rng.new(3)
		local r = Damage.computeDamage(attacker({ critChance = 100, critDmg = 200 }), defender(), PHYS, rng)
		T.expect(r.crit).toBe(true)
		T.expect(r.amount).toBeBetween(184, 216)
		local noCrit = Damage.computeDamage(
			attacker({ critChance = 100 }),
			defender(),
			{ kind = "phys", canCrit = false },
			Rng.new(3)
		)
		T.expect(noCrit.crit).toBe(false)
	end)

	T.it("dodge chance is capped at 30% and reduced by accuracy", function()
		T.expect(Damage.dodgeChance(80, 0)).toBeNear(0.3)
		T.expect(Damage.dodgeChance(20, 5)).toBeNear(0.15)
		T.expect(Damage.dodgeChance(5, 20)).toBe(0)
		local rng = Rng.new(5)
		local dodged = 0
		for _ = 1, 4000 do
			if Damage.computeDamage(attacker(), defender({ dodge = 100 }), PHYS, rng).dodged then
				dodged += 1
			end
		end
		T.expect(dodged / 4000).toBeNear(0.3, 0.03)
	end)

	T.it("dodged attacks deal 0 and canDodge=false always hits", function()
		local rng = Rng.new(6)
		local seenDodge = false
		for _ = 1, 100 do
			local r = Damage.computeDamage(attacker(), defender({ dodge = 30 }), PHYS, rng)
			if r.dodged then
				seenDodge = true
				T.expect(r.amount).toBe(0)
			end
			local sure =
				Damage.computeDamage(attacker(), defender({ dodge = 30 }), { kind = "phys", canDodge = false }, rng)
			T.expect(sure.dodged).toBe(false)
		end
		T.expect(seenDodge).toBe(true)
	end)

	T.it("element resistance is capped at 75%", function()
		local r = Damage.computeDamage(
			attacker(),
			defender({ res = { resFire = 200 } }),
			{ kind = "magic", element = "fire", canDodge = false },
			Rng.new(8)
		)
		-- magAtk 80 x 0.25 x random
		T.expect(r.amount).toBeBetween(18, 22)
		T.expect(r.element).toBe("fire")
	end)

	T.it("PvP modifier is 0.6", function()
		local a = Damage.computeDamage(attacker(), defender(), PHYS, Rng.new(10))
		local b = Damage.computeDamage(attacker(), defender(), { kind = "phys", pvp = true }, Rng.new(10))
		T.expect(b.amount).toBeNear(a.amount * 0.6, 1)
	end)

	T.it("lifesteal is a share of the final damage, capped at 15%", function()
		local r = Damage.computeDamage(
			attacker({ lifesteal = 50 }),
			defender(),
			{ kind = "phys", canDodge = false },
			Rng.new(11)
		)
		T.expect(r.lifesteal).toBe(math.floor(r.amount * 0.15))
	end)

	T.it("fromStats maps StatCalc values", function()
		local a, d = Damage.fromStats(7, { physAtk = 12, armor = 30, resIce = 10 })
		T.expect(a.level).toBe(7)
		T.expect(a.physAtk).toBe(12)
		T.expect(d.armor).toBe(30)
		T.expect((d.res :: any).resIce).toBe(10)
	end)
end)

T.describe("MonsterStats", function()
	local kind: MonsterStats.Kind = { hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }

	T.it("base formulas", function()
		local s = MonsterStats.compute(kind, 10, "normal")
		T.expect(s.level).toBe(10)
		T.expect(s.maxHp)
			.toBe(math.floor(Combat.monsterHpBase + Combat.monsterHpFactor * 10 ^ Combat.monsterHpExponent + 0.5))
		T.expect(s.attack).toBeNear(Combat.monsterAtkBase + Combat.monsterAtkFactor * 10 ^ Combat.monsterAtkExponent)
		T.expect(s.armor).toBe(40)
		T.expect(s.attackInterval).toBeNear(Combat.monsterAttackInterval)
		T.expect(s.range).toBe(7)
		T.expect(s.aggroRange).toBe(Combat.variants.normal.aggroRange)
	end)

	T.it("variants add levels and multiply", function()
		local normal = MonsterStats.compute(kind, 10, "normal")
		local elite = MonsterStats.compute(kind, 10, "elite")
		local elite2 = MonsterStats.compute(kind, 10, "elite2")
		T.expect(elite.level).toBe(12)
		T.expect(elite2.level).toBe(14)
		T.expect(elite.maxHp).toBe(math.floor(MonsterStats.baseHp(12) * 4 + 0.5))
		T.expect(elite2.maxHp).toBe(math.floor(MonsterStats.baseHp(14) * 12 + 0.5))
		T.expect(elite.attack).toBeNear(MonsterStats.baseAttack(12) * 1.5)
		T.expect(elite2.attack).toBeNear(MonsterStats.baseAttack(14) * 2)
		T.expect({ normal.scale, elite.scale, elite2.scale }).toEqual({ 1, 1.25, 1.5 })
		T.expect(elite.aggroRange).toBe(Combat.variants.elite.aggroRange)
	end)

	T.it("kind multipliers apply", function()
		local tough = MonsterStats.compute(
			{ hpMul = 2, atkMul = 0.5, defMul = 3, speed = 2, attack = "ranged", range = 28 },
			20,
			"normal"
		)
		T.expect(tough.maxHp).toBe(math.floor(MonsterStats.baseHp(20) * 2 + 0.5))
		T.expect(tough.attack).toBeNear(MonsterStats.baseAttack(20) * 0.5)
		T.expect(tough.armor).toBe(240)
		T.expect(tough.attackInterval).toBeNear(Combat.monsterAttackInterval / 2)
		T.expect(tough.range).toBe(28)
	end)

	T.it("rejects unknown variants", function()
		T.expect(function()
			MonsterStats.compute(kind, 1, "mythic" :: any)
		end).toThrow("unknown variant")
	end)

	T.it("gold follows DESIGN §5.5", function()
		T.expect(MonsterStats.gold(10, "normal", 0)).toBe(21) -- 10 x 3 x 0.7
		T.expect(MonsterStats.gold(10, "normal", 1)).toBe(39) -- 10 x 3 x 1.3
		T.expect(MonsterStats.gold(10, "elite", 0.5)).toBe(120)
		T.expect(MonsterStats.gold(10, "elite2", 0.5)).toBe(360)
	end)

	T.it("gold scales with variant and roll", function()
		local low = MonsterStats.gold(10, "normal", 0)
		local high = MonsterStats.gold(10, "normal", 1)
		T.expect(high > low).toBe(true)
		T.expect(MonsterStats.gold(10, "elite2", 0.5) > MonsterStats.gold(10, "elite", 0.5)).toBe(true)
		T.expect(MonsterStats.gold(1, "normal", 0) >= 1).toBe(true)
	end)

	T.it("weak monsters leave strong players alone", function()
		T.expect(MonsterStats.isAggressiveTowards(5, 19)).toBe(true)
		T.expect(MonsterStats.isAggressiveTowards(5, 20)).toBe(false)
	end)
end)

return nil
