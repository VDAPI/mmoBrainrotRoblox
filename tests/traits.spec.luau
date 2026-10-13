--!strict
local Combat = require("../src/shared/Data/Combat")
local Damage = require("../src/shared/Logic/Damage")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local SkillData = require("../src/shared/Data/Skills")
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
		for _, kind in { "cone", "circleSelf", "circleTarget", "line", "chain", "trap", "shout" } do
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

T.describe("Traits: block, counter, execute and controlled targets (S64)", function()
	T.it("caps the block and halves it in PvP", function()
		T.expect(Traits.blockChance(5, false)).toBe(5)
		T.expect(Traits.blockChance(40, false)).toBe(25)
		T.expect(Traits.blockChance(40, true)).toBe(12.5)
		T.expect(Traits.blockChance(5, true)).toBe(2.5)
		T.expect(Traits.blockChance(-3, false)).toBe(0)
	end)

	T.it("caps the counter and halves it in PvP", function()
		T.expect(Traits.counterChance(10, false)).toBe(10)
		T.expect(Traits.counterChance(45, false)).toBe(34) -- S88: riposteCap 30 -> 34
		T.expect(Traits.counterChance(45, true)).toBe(17)
		T.expect(Traits.counterChance(10, true)).toBe(5)
	end)

	T.it("halves only the trait part of the execute bonus and caps the sum", function()
		T.expect(Traits.executeBonus(0, 18, nil)).toBe(18)
		T.expect(Traits.executeBonus(0, 18, 0.5)).toBe(9)
		T.expect(Traits.executeBonus(15, 33.8, nil)).toBeNear(48.8)
		T.expect(Traits.executeBonus(35, 33.8, nil)).toBe(60)
		T.expect(Traits.executeBonus(90, 0, 0.5)).toBe(60)
	end)

	T.it("gives Easy Prey only on controlled targets", function()
		T.expect(Traits.controlledBonus(10, 0.8, nil)).toBe(10)
		T.expect(Traits.controlledBonus(10, 1, nil)).toBe(0)
		T.expect(Traits.controlledBonus(10, 0, 0.5)).toBe(5)
	end)
end)

T.describe("Traits: rhythm and player state (S65)", function()
	T.it("Twin Cut strikes again on the fifth attack", function()
		local count, twin = 0, false
		for i = 1, 4 do
			count, twin = Traits.twinCut(count, if i == 1 then nil else i - 1, i, 5, 5)
			T.expect({ count, twin }).toEqual({ i, false })
		end
		count, twin = Traits.twinCut(count, 4, 5, 5, 5)
		T.expect({ count, twin }).toEqual({ 0, true })
		T.expect({ Traits.twinCut(4, 0, 5.1, 5, 5) }).toEqual({ 1, false })
		T.expect({ Traits.twinCut(4, 0, 5, 5, 5) }).toEqual({ 0, true })
		T.expect({ Traits.twinCut(3, nil, 10, 5, 5) }).toEqual({ 1, false })
	end)

	T.it("Run Through finds the nearest enemy behind the target", function()
		local me, at = { x = 0, z = 0 }, { x = 0, z = 10 }
		local function one(x: number, z: number): number?
			return Traits.behind(me, at, 1, { { x = x, z = z } }, 4, 4)
		end
		T.expect(one(0, 13)).toBe(1)
		T.expect(one(0, 15)).toBe(1)
		T.expect(one(1.9, 12)).toBe(1)
		T.expect(one(0, 15.5)).toBeNil()
		T.expect(one(2.1, 12)).toBeNil()
		T.expect(one(0, 9)).toBeNil()
		T.expect(Traits.behind(me, at, 1, { { x = 0, z = 14 }, { x = 0, z = 12 } }, 4, 4)).toBe(2)
		T.expect(Traits.behind(me, at, 1, { { x = 0, z = 12 }, { x = 0, z = 12 } }, 4, 4)).toBe(1)
		local diag = { x = 10, z = 10 }
		T.expect(Traits.behind(me, diag, 1, { { x = 12, z = 12 } }, 4, 4)).toBe(1)
		T.expect(Traits.behind(me, diag, 1, { { x = 13, z = 11 } }, 4, 4)).toBe(1)
		T.expect(Traits.behind(me, diag, 1, { { x = 14, z = 10 } }, 4, 4)).toBeNil()
		T.expect(Traits.behind(at, at, 1, { { x = 0, z = 12 } }, 4, 4)).toBeNil()
		T.expect(Traits.behind(me, at, 1, {}, 4, 4)).toBeNil()
	end)

	T.it("Runic Seal glows after standing still", function()
		local seal = Traits.sealStep(nil, 0, 0, 0, 1.5, 1)
		T.expect(seal.lit).toBe(false)
		seal = Traits.sealStep(seal, 0, 0, 1.4, 1.5, 1)
		T.expect(seal.lit).toBe(false)
		seal = Traits.sealStep(seal, 0, 0, 1.5, 1.5, 1)
		T.expect(seal.lit).toBe(true)
		seal = Traits.sealStep(seal, 0.9, 0, 2, 1.5, 1)
		T.expect(seal.lit).toBe(true)
		seal = Traits.sealStep(seal, 1.2, 0, 2.1, 1.5, 1)
		T.expect({ seal.lit, seal.x, seal.since }).toEqual({ false, 1.2, 2.1 })
		seal = Traits.sealStep(seal, 1.2, 0, 3.6, 1.5, 1)
		T.expect(seal.lit).toBe(true)
	end)

	T.it("Full Draw scales with weapon speed, Saving Blow fits under lifesteal", function()
		T.expect(Traits.drawBonus(30, 1.3)).toBeNear(39)
		T.expect(Traits.drawBonus(30, 1.0)).toBe(30)
		T.expect(Traits.drawBonus(30, 0.62)).toBeNear(18.6)
		T.expect(Traits.drawBonus(30, 1.3, 0.5)).toBeNear(19.5)
		T.expect(Traits.drawBonus(30, nil)).toBe(30)
		T.expect(Traits.savingSelfShare(4, 0)).toBe(4)
		T.expect(Traits.savingSelfShare(4, 13)).toBe(2)
		T.expect(Traits.savingSelfShare(4, 15)).toBe(0)
		T.expect(Traits.savingSelfShare(4, 20)).toBe(0)
		T.expect(Traits.savingSelfShare(2, 14)).toBe(1)
	end)

	T.it("kill heal sums stay under the lifesteal cap (S88 E5)", function()
		T.expect(Traits.killHeal(19.9)).toBe(15)
		T.expect(Traits.killHeal(4)).toBe(4)
		T.expect(Traits.killHeal(0)).toBe(0)
		T.expect(Traits.killHeal(-1)).toBe(0)
	end)

	local ADAPTIVE: Traits.ElementSpec = {
		burnPct = SkillData.ADAPTIVE.burnPct,
		burnDuration = SkillData.ADAPTIVE.burnDuration,
		slowPct = SkillData.ADAPTIVE.slowPct,
		slowDuration = SkillData.ADAPTIVE.slowDuration,
		arcPct = SkillData.ADAPTIVE.arcPct,
		arcRadius = SkillData.ADAPTIVE.arcRadius,
		exactTicks = SkillData.ADAPTIVE.exactTicks,
	}

	T.it("adaptive skills without a rider (S79: the burn pays the full 30 % over the real ticks)", function()
		local fire = Traits.elementPlan("fire", ADAPTIVE, 1000, 0, 0, false) :: Traits.ElementPlan
		T.expect({ fire.kind, fire.pct, fire.duration, fire.sameTarget }).toEqual({ "burn", 30, 4, 0 })
		T.expect(fire.tick :: number).toBeNear(100)
		-- S79: Traits.dotTick, 30 % of the hit over 3 ticks x (1 + dotPower / 100) (75 / 90 before S79)
		T.expect((Traits.elementPlan("fire", ADAPTIVE, 1000, 0, 20, false) :: any).tick).toBeNear(120)
		T.expect((Traits.elementPlan("fire", ADAPTIVE, 10, 0, 0, false) :: any).tick).toBe(1)
		local ice = Traits.elementPlan("ice", ADAPTIVE, 1000, 0, 0, false) :: Traits.ElementPlan
		T.expect({ ice.kind, ice.pct, ice.duration, ice.sameTarget }).toEqual({ "slow", 25, 2, 0 })
		local arc = Traits.elementPlan("lightning", ADAPTIVE, 1000, 0, 0, false) :: Traits.ElementPlan
		T.expect({ arc.kind, arc.pct, arc.sameTarget }).toEqual({ "arc", 40, 0 })
		T.expect(Traits.elementPlan("holy", ADAPTIVE, 1000, 0, 0, false)).toBeNil()
		T.expect(Traits.elementPlan(nil, ADAPTIVE, 1000, 0, 0, false)).toBeNil()
	end)

	T.it("Elemental Might strengthens the weapon element", function()
		local fire = Traits.elementPlan("fire", ADAPTIVE, 1000, 30, 0, true) :: Traits.ElementPlan
		T.expect(fire.pct).toBeNear(39)
		T.expect(fire.tick :: number).toBeNear(130)
		T.expect((Traits.elementPlan("ice", ADAPTIVE, 1000, 30, 0, true) :: any).duration).toBeNear(2.6)
		local arc = Traits.elementPlan("lightning", ADAPTIVE, 1000, 30, 0, true) :: Traits.ElementPlan
		T.expect(arc.pct).toBeNear(52)
		T.expect(arc.sameTarget).toBeNear(12)
		T.expect((Traits.elementPlan("lightning", ADAPTIVE, 1000, 30, 0, false) :: any).sameTarget).toBe(0)
	end)

	T.it("Elemental Spark uses its params and exact ticks", function()
		local p = (ItemTraits.get("elementalSpark") :: any).params
		local spec: Traits.ElementSpec = {
			burnPct = p.burnPct,
			burnDuration = p.burnDuration,
			exactTicks = true,
			slowPct = p.slowPct,
			slowDuration = p.slowDuration,
			arcPct = p.arcPct,
			arcRadius = p.arcRadius,
			sameTargetPct = p.sameTargetPct,
		}
		-- S88: burn 30 -> 80 %, arc 40 -> 110 %, same target 20 -> 55 %
		T.expect((Traits.elementPlan("fire", spec, 1000, 0, 0, false) :: any).tick).toBeNear(800)
		T.expect((Traits.elementPlan("fire", spec, 1000, 0, 10, false) :: any).tick).toBeNear(880)
		local ice = Traits.elementPlan("ice", spec, 1000, 0, 0, false) :: Traits.ElementPlan
		T.expect({ ice.pct, ice.duration }).toEqual({ 20, 2 })
		local arc = Traits.elementPlan("lightning", spec, 1000, 0, 0, false) :: Traits.ElementPlan
		T.expect({ arc.pct, arc.sameTarget }).toEqual({ 110, 55 })
		local strong = Traits.elementPlan("lightning", spec, 1000, 30, 0, false) :: Traits.ElementPlan
		T.expect(strong.pct).toBeNear(143)
		T.expect(strong.sameTarget).toBeNear(71.5)
	end)

	T.it("PvP multipliers come from the data", function()
		local byHook = ItemTraits.pvpByHook
		for _, id in { "traitFullDraw", "traitRuneSeal", "traitSavingBlow" } do
			T.expect({ id, byHook[id] }).toEqual({ id, 0.5 })
		end
		for _, id in { "traitTwinCut", "traitRunThrough", "traitSpark", "elementRider" } do
			T.expect({ id, byHook[id] or 1 }).toEqual({ id, 1 })
		end
		T.expect(Combat.pvp.frostbite * 6).toBe(3)
	end)
end)

return nil
