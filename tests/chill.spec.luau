--!strict
-- S141 (DESIGN-18 §6.1): the ice school's chill in pure logic (Logic/Chill): Winter's Grip's counter, Deep Chill on
-- bosses, Glacial Spike, Shatter, Ice Barrier's gap, Ice Blood, Blizzard's freeze wave and Frozen Orb's flight; the
-- data of the ice pool that the server reads.

local Chill = require("../src/shared/Logic/Chill")
local Combat = require("../src/shared/Data/Combat")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

local CHILL = SkillData.CHILL

T.describe("Chill: Winter's Grip's counter (S141)", function()
	T.it("only hits on a slowed, not frozen target count, and only with the passive", function()
		T.expect(Chill.counts(true, true, false)).toBe(true)
		T.expect(Chill.counts(true, false, false)).toBe(false) -- not slowed
		T.expect(Chill.counts(true, true, true)).toBe(false) -- already frozen
		T.expect(Chill.counts(false, true, false)).toBe(false) -- no Winter's Grip
	end)

	T.it("the threshold freezes and resets the counter", function()
		local count, freezes = 0, false
		local frozenAt = nil
		for hit = 1, CHILL.threshold do
			count, freezes = Chill.chillToFreeze(count)
			if freezes then
				frozenAt = hit
			end
		end
		T.expect(frozenAt).toBe(CHILL.threshold)
		T.expect(count).toBe(0) -- spent on the freeze
		T.expect({ Chill.chillToFreeze(0, 4) }).toEqual({ 1, false })
		T.expect({ Chill.chillToFreeze(2, 4) }).toEqual({ 3, false })
		T.expect({ Chill.chillToFreeze(3, 4) }).toEqual({ 0, true })
		T.expect({ Chill.chillToFreeze(7, 4) }).toEqual({ 0, true }) -- never above the threshold
		T.expect({ Chill.chillToFreeze(0, 1) }).toEqual({ 0, true })
		T.expect(Chill.THRESHOLD).toBe(4)
	end)

	T.it("bosses and Elite II get Deep Chill instead of the freeze", function()
		T.expect(Chill.onFreeze(true)).toBe("deepChill")
		T.expect(Chill.onFreeze(false)).toBe("freeze")
		T.expect(Chill.deepPct(nil)).toBe(CHILL.deepPct)
		T.expect(Chill.deepPct(0)).toBe(CHILL.deepPct)
		T.expect(Chill.deepPct(CHILL.deepPct + 6)).toBe(CHILL.deepPct + 6)
		local grip = SkillData.get("wintersGrip") :: any
		local totals = { flat = {}, pct = {}, hooks = {} }
		Skills.addPassive(totals :: any, grip, 1)
		T.expect(totals.hooks.chillFreeze).toBe(1.5)
		T.expect(Chill.deepPct(totals.hooks.deepChill)).toBe(10)
	end)

	T.it("descriptions show Deep Chill as the server applies it (Winter's Grip raises it)", function()
		local nova = SkillData.get("frostNova") :: any
		T.expect(Skills.descriptionArgs(nova, 1).deepPct).toBe(CHILL.deepPct) -- wiki: no hooks
		T.expect(Skills.descriptionArgs(nova, 1, { hooks = { deepChill = 18 } }).deepPct).toBe(18)
		T.expect(Skills.descriptionArgs(nova, 1, { hooks = { deepChill = 4 } }).deepPct).toBe(CHILL.deepPct)
	end)
end)

T.describe("Chill: the bonuses on frozen targets (S141)", function()
	T.it("vsFrozen: x1.5 on a frozen target, x1.25 with Deep Chill, 1 otherwise", function()
		T.expect(Chill.vsFrozen(true, false, 50, 25)).toBeNear(1.5, 1e-9)
		T.expect(Chill.vsFrozen(true, true, 50, 25)).toBeNear(1.5, 1e-9) -- frozen wins
		T.expect(Chill.vsFrozen(false, true, 50, 25)).toBeNear(1.25, 1e-9)
		T.expect(Chill.vsFrozen(false, false, 50, 25)).toBe(1)
		T.expect(Chill.vsFrozen(true, false, -10, 25)).toBe(1)
		local spike = SkillData.get("glacialSpike") :: any
		T.expect(Chill.vsFrozen(true, false, Skills.valueAt(spike, "vsFrozen", 1), 0)).toBeNear(1.5, 1e-9)
		T.expect(Chill.vsFrozen(false, true, 0, Skills.valueAt(spike, "vsDeepChill", 1))).toBeNear(1.25, 1e-9)
	end)

	T.it("shatterMul: x2 spends the freeze, x1.6 spends Deep Chill, nothing without either", function()
		T.expect({ Chill.shatterMul(true, false, 100, 60) }).toEqual({ 2, "freeze" })
		T.expect({ Chill.shatterMul(true, true, 100, 60) }).toEqual({ 2, "freeze" })
		local mul, used = Chill.shatterMul(false, true, 100, 60)
		T.expect(mul).toBeNear(1.6, 1e-9)
		T.expect(used).toBe("deepChill")
		T.expect({ Chill.shatterMul(false, false, 100, 60) }).toEqual({ 1 })
		local shatter = SkillData.get("shatter") :: any
		T.expect(Skills.valueAt(shatter, "shatter", 1)).toBe(100)
		T.expect(Skills.valueAt(shatter, "shatterDeep", 1)).toBe(60)
	end)

	T.it("against players the bonus stops at the finisher cap", function()
		T.expect(Chill.pvpMul(2, Combat.pvp.finisher)).toBe(Combat.pvp.finisher)
		T.expect(Chill.pvpMul(1.25, Combat.pvp.finisher)).toBe(1.25)
		T.expect(Chill.pvpMul(1, 0.5)).toBe(1)
	end)
end)

T.describe("Chill: barrier, Ice Blood, Blizzard, Frozen Orb (S141)", function()
	T.it("Ice Barrier slows one attacker at most once per barrierGap", function()
		T.expect(Chill.barrierReady(nil, 10)).toBe(true)
		T.expect(Chill.barrierReady(10, 10 + CHILL.barrierGap * 0.5)).toBe(false)
		T.expect(Chill.barrierReady(10, 10 + CHILL.barrierGap)).toBe(true)
		local barrier = SkillData.get("iceBarrier") :: any
		local effect = (barrier.effects :: any)[1]
		T.expect({ effect.kind, effect.target, effect.category }).toEqual({ "iceBarrier", "self", "own" })
		T.expect(Skills.valueAt(barrier, "barrier", 1)).toBe(40)
	end)

	T.it("Ice Blood only against slowed or frozen attackers", function()
		T.expect(Chill.bloodGuard(8, true, false)).toBe(8)
		T.expect(Chill.bloodGuard(8, false, true)).toBe(8)
		T.expect(Chill.bloodGuard(8, false, false)).toBe(0)
		T.expect(Chill.bloodGuard(0, true, true)).toBe(0)
	end)

	T.it("Blizzard freezes each enemy once from its freeze wave", function()
		local blizzard = SkillData.get("blizzard") :: any
		local from = blizzard.freezeWave
		T.expect(from).toBe(5)
		T.expect(Chill.waveFreezes(from - 1, from, false)).toBe(false)
		T.expect(Chill.waveFreezes(from, from, false)).toBe(true)
		T.expect(Chill.waveFreezes(from + 2, from, true)).toBe(false) -- once per cast
		T.expect(Chill.waveFreezes(8, nil, false)).toBe(false)
	end)

	T.it("Frozen Orb's waves move along its travel", function()
		local orb = SkillData.get("frozenOrb") :: any
		T.expect(Chill.orbAt(orb.travel, 1, orb.hits)).toBeNear(orb.travel / orb.hits, 1e-9)
		T.expect(Chill.orbAt(orb.travel, orb.hits, orb.hits)).toBeNear(orb.travel, 1e-9)
		T.expect(Chill.orbAt(20, 15, 10)).toBe(20)
	end)

	T.it("a growing slow: the effect's maxStacks", function()
		local orb = SkillData.get("frozenOrb") :: any
		local blizzard = SkillData.get("blizzard") :: any
		T.expect((orb.effects :: any)[1].maxStacks).toBe(5)
		T.expect((blizzard.effects :: any)[1].maxStacks).toBe(8)
		T.expect(orb.waveEffects and blizzard.waveEffects).toBe(true)
	end)
end)

-- S141: the model's mirror (tests/SkillModel, `-- mirrors`): the orb's waves over the dummies, the chill counter and
-- Deep Chill in a fight of the ice variant.
T.describe("Chill: the balance model's mirror (S141)", function()
	local SkillModel = require("./SkillModel")
	local B = require("./Balance")

	T.it("a flying orb reaches the dummies with the waves near ASSUMPTIONS.orbAim of its travel", function()
		local orb = SkillData.get("frozenOrb") :: any
		local hits = 0
		for w = 1, orb.hits do
			if SkillModel.orbHits(orb, w) then
				hits += 1
			end
		end
		T.expect(hits).toBe(7)
		T.expect(SkillModel.orbHits(SkillData.get("hailstorm") :: any, 1)).toBe(true) -- no travel: every wave
	end)

	T.it("the ice variant slows and freezes a monster and keeps Deep Chill on a boss", function()
		local build = SkillModel.build("arcanist.arcanistIce", "Mage") :: any
		local sp = SkillModel.player(build, 45)
		local plain = SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, 45) } })
		T.expect(plain.chilled > 0.6).toBe(true)
		T.expect(plain.deepChilled).toBe(0) -- a monster freezes instead
		local boss = SkillModel.fight(sp, { targets = { B.monster(B.GENERIC, 45, "boss") } })
		T.expect(boss.deepChilled > 0.5).toBe(true)
		-- the fire variant never chills
		local fire = SkillModel.player(SkillModel.build("arcanist.arcanistFire", "Mage") :: any, 45)
		T.expect(SkillModel.fight(fire, { targets = { B.monster(B.GENERIC, 45, "boss") } }).deepChilled).toBe(0)
	end)
end)
