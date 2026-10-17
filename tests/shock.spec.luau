--!strict
-- S142 (DESIGN-18 §6.1): the lightning school in pure logic (Logic/Shock): the crit of Lightning Bolt and Overcharge,
-- Lightning Lance's sure crit, Conductor's jump, Storm Armor's gap and Ball Lightning's finale; the data of the
-- lightning pool that the server reads.

local Chain = require("../src/shared/Logic/Chain")
local Shock = require("../src/shared/Logic/Shock")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local SHOCK = SkillData.SHOCK

T.describe("Shock: crit (S142)", function()
	T.it("the skill's own crit and Overcharge only on lightning spells", function()
		T.expect({ Shock.critOf("lightning", 10, 3, 10) }).toEqual({ 13, 10 })
		T.expect({ Shock.critOf("fire", 0, 3, 10) }).toEqual({ 0, 0 }) -- Overcharge needs lightning
		T.expect({ Shock.critOf(nil, 0, 8, 30) }).toEqual({ 0, 0 })
		T.expect({ Shock.critOf("ice", 10, nil, nil) }).toEqual({ 0, 0 })
		T.expect({ Shock.critOf("lightning", nil, nil, nil) }).toEqual({ 0, 0 })
		T.expect({ Shock.critOf("lightning", -5, -1, -1) }).toEqual({ 0, 0 })
		-- values.crit as an effect's stat (the Warrior's Advance Order ally buff) never crits the skill's own hits
		local order = SkillData.get("advanceOrder") :: any
		T.expect(order.values.crit ~= nil).toBe(true)
		T.expect({ Shock.critOf(order.element, Skills.valueAt(order, "crit", 10), 0, 0) }).toEqual({ 0, 0 })
		local bolt = SkillData.get("lightningBolt") :: any
		T.expect(Skills.valueAt(bolt, "crit", 1)).toBe(10)
		local over = SkillData.get("overcharge") :: any
		local totals = { flat = {}, pct = {}, hooks = {} }
		Skills.addPassive(totals :: any, over, 5)
		T.expect({ totals.hooks.overchargeCrit, totals.hooks.overchargeDmg }).toEqual({ 8, 30 })
	end)

	T.it("a sure crit only on the main hit of a sureCrit skill", function()
		T.expect(Shock.sureCrit(true, true)).toBe(true)
		T.expect(Shock.sureCrit(true, false)).toBe(false) -- a splash, a pierce, a zone tick
		T.expect(Shock.sureCrit(nil, true)).toBe(false)
		T.expect((SkillData.get("lightningLance") :: any).sureCrit).toBe(true)
		T.expect((SkillData.get("lightningBolt") :: any).sureCrit).toBeNil()
	end)
end)

T.describe("Shock: Conductor (S142)", function()
	T.it("only a single-target lightning spell's main hit jumps", function()
		local bolt = SkillData.get("lightningBolt") :: any
		local chain = SkillData.get("chainLightning") :: any
		T.expect(Shock.conducts("lightning", Skills.tag(bolt), true, 20)).toBe(true)
		T.expect(Shock.conducts("lightning", Skills.tag(chain), true, 20)).toBe(false) -- an area spell
		T.expect(Shock.conducts("lightning", "single", false, 20)).toBe(false) -- a secondary hit never jumps again
		T.expect(Shock.conducts("fire", "single", true, 20)).toBe(false)
		T.expect(Shock.conducts("lightning", "single", true, 0)).toBe(false) -- no passive
	end)

	T.it("the nearest other target within the radius, never the first one", function()
		local points: { Chain.Point } = {
			{ x = 0, z = 0 }, -- the struck target
			{ x = 8, z = 0 },
			{ x = 3, z = 4 }, -- 5 studs: the nearest
			{ x = 30, z = 0 }, -- out of reach
		}
		T.expect(Shock.conductTarget(points, SHOCK.conductRadius)).toBe(3)
		T.expect(Shock.conductTarget({ { x = 0, z = 0 } }, 10)).toBeNil() -- nobody else
		T.expect(Shock.conductTarget({ { x = 0, z = 0 }, { x = 30, z = 0 } }, 10)).toBeNil()
		T.expect(Shock.conductTarget({ { x = 0, z = 0 }, { x = 4, z = 0 }, { x = 4, z = 0 } }, 10)).toBe(2) -- ties: lower
		T.expect(Shock.CONDUCT_RADIUS).toBe(SHOCK.conductRadius)
	end)

	T.it("the jump is a secondary hit: area bonuses count it (ROZWOJ 12.3), single-target ones do not", function()
		T.expect(Skills.areaApplies("single", 1, true)).toBe(true)
		T.expect(Skills.singleApplies("single", true)).toBe(false)
		local conductor = SkillData.get("conductor") :: any
		T.expect(conductor.passive.hooks.conduct).toBe("conduct")
		T.expect({ Skills.valueAt(conductor, "conduct", 1), Skills.valueAt(conductor, "conduct", 5) })
			.toEqual({ 20, 40 })
		T.expect(Skills.descriptionArgs(conductor, 1).conductRadius).toBe(SHOCK.conductRadius)
	end)
end)

T.describe("Shock: Storm Armor, Thunder Strike, Ball Lightning (S142)", function()
	T.it("Storm Armor strikes one attacker back at most once per armorGap", function()
		T.expect(Shock.armorReady(nil, 5)).toBe(true)
		T.expect(Shock.armorReady(5, 5 + SHOCK.armorGap * 0.5)).toBe(false)
		T.expect(Shock.armorReady(5, 5 + SHOCK.armorGap)).toBe(true)
		local armor = SkillData.get("stormArmor") :: any
		local kinds = {}
		for _, effect in armor.effects do
			T.expect({ effect.kind, effect.target, effect.category }).toEqual({ effect.kind, "self", "own" })
			table.insert(kinds, effect.kind)
		end
		T.expect(kinds).toEqual({ "damageReduction", "stormArmor" })
		-- little defence: no shield, a reduction below the ice and fire shields
		T.expect(armor.type).toBe("buff")
		T.expect(Skills.valueAt(armor, "reduce", 10) <= 10).toBe(true)
	end)

	T.it("Thunder Strike lands after its delay; descriptions show it", function()
		local strike = SkillData.get("thunderStrike") :: any
		T.expect({ strike.type, strike.delay }).toEqual({ "target", 0.5 })
		T.expect(Skills.descriptionArgs(strike, 1).delay).toBe(0.5)
	end)

	T.it("Ball Lightning: the finale is the last wave only", function()
		local ball = SkillData.get("ballLightning") :: any
		T.expect(ball.finale).toEqual({ knockback = 6, stun = 1 })
		T.expect(Shock.finale(true, ball.hits, ball.hits)).toBe(true)
		T.expect(Shock.finale(true, ball.hits - 1, ball.hits)).toBe(false)
		T.expect(Shock.finale(false, ball.hits, ball.hits)).toBe(false)
		local args = Skills.descriptionArgs(ball, 1)
		T.expect({ args.finaleKnockback, args.finaleStun, args.travel }).toEqual({ 6, 1, 16 })
	end)

	T.it("lightning hits hardest: Thunder Strike is the heaviest S2, Tempest the biggest capstone total", function()
		local function at10(id: string): number
			local def = SkillData.get(id) :: any
			return Skills.valueAt(def, "dmg", 10) * (def.hits or 1)
		end
		T.expect(at10("thunderStrike") > at10("pyroblast")).toBe(true)
		T.expect(at10("thunderStrike") > at10("glacialSpike")).toBe(true)
		T.expect(at10("lightningBolt") > at10("firebolt")).toBe(true)
		T.expect(at10("tempest") > at10("blizzard")).toBe(true)
	end)
end)

-- S142: the model's mirror (tests/SkillModel, `-- mirrors`): the lightning variant buys Overcharge and Conductor and its
-- hooks reach the fight.
T.describe("Shock: the balance model's mirror (S142)", function()
	local SkillModel = require("./SkillModel")

	T.it("the lightning variant at 100 has Overcharge and Conductor; the fire variant has neither", function()
		local sp = SkillModel.player(SkillModel.build("arcanist.arcanistLightning", "Mage") :: any, 100)
		T.expect((sp.pathHooks.overchargeCrit or 0) > 0).toBe(true)
		T.expect((sp.pathHooks.conduct or 0) > 0).toBe(true)
		local fire = SkillModel.player(SkillModel.build("arcanist.arcanistFire", "Mage") :: any, 100)
		T.expect(fire.pathHooks.conduct or 0).toBe(0)
	end)

	T.it("lightning beats fire on one target at 45-100 in the model (DESIGN-18 §6.1)", function()
		for _, L in { 45, 70, 100 } do
			local bolt = SkillModel.metrics(SkillModel.build("arcanist.arcanistLightning", "Mage") :: any, L)
			local fire = SkillModel.metrics(SkillModel.build("arcanist.arcanistFire", "Mage") :: any, L)
			T.expect({ L, bolt.single60 > fire.single60 }).toEqual({ L, true })
		end
	end)
end)
