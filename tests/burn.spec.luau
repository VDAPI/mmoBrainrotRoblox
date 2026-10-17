--!strict
-- S140 (DESIGN-18 §6.1): the fire school's burn and its passives in pure logic (Logic/Burn), the one burn of a player on
-- a target through EffectStack (stacks, refresh, accumulate without the stack cap) and the model's mirror.

local Burn = require("../src/shared/Logic/Burn")
local Combat = require("../src/shared/Data/Combat")
local EffectStack = require("../src/shared/Logic/EffectStack")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")
local Traits = require("../src/shared/Logic/Traits")

local BURN = SkillData.BURN

T.describe("Burn: stacks (S140)", function()
	T.it("the cap: one stack without Kindling, Kindling's extra stacks on top", function()
		T.expect(Burn.cap(nil)).toBe(BURN.maxStacks)
		T.expect(Burn.cap(0)).toBe(1)
		T.expect(Burn.cap(2)).toBe(3)
		T.expect(Burn.cap(-4)).toBe(1)
		local kindling = SkillData.get("kindling") :: any
		local totals = { flat = {}, pct = {}, hooks = {} }
		Skills.addPassive(totals :: any, kindling, 1)
		T.expect(Burn.cap(totals.hooks.burnStacks)).toBe(3)
	end)

	T.it("adding stacks: at least one, never above the cap", function()
		T.expect(Burn.add(0, 1, 1)).toBe(1)
		T.expect(Burn.add(1, 1, 1)).toBe(1) -- without Kindling a refresh stays at one stack
		T.expect(Burn.add(1, 1, 3)).toBe(2)
		T.expect(Burn.add(2, 2, 3)).toBe(3)
		T.expect(Burn.add(0, 2, 3)).toBe(2) -- Pyroblast's two stacks at once
		T.expect(Burn.add(0, 0, 3)).toBe(1)
		T.expect(Burn.add(5, 1, 3)).toBe(3)
	end)

	T.it("a stack's tick: pct % of the hit over the duration's real ticks, x stacks, + dotPower", function()
		T.expect(Burn.tick(1000, 1, 0)).toBeNear(Traits.dotTick(1000, BURN.pct, BURN.duration, 0), 1e-9)
		T.expect(Burn.tick(1000, 2, 0)).toBeNear(2 * Burn.tick(1000, 1, 0), 1e-9)
		T.expect(Burn.tick(1000, 1, 20)).toBeNear(Burn.tick(1000, 1, 0) * 1.2, 1e-9)
		T.expect(Burn.tick(1000, 1, 0, 40, 5)).toBeNear(1000 * 0.4 / Traits.ticks(5), 1e-9)
	end)

	T.it(
		"the stack count on the effect: restack with `stacks` keeps the later end, accumulate pays every hit",
		function()
			local cap = Burn.cap(2)
			local first = EffectStack.restack(nil, {
				unit = BURN.pct,
				tickUnit = 10,
				maxStacks = cap,
				duration = BURN.duration,
				now = 0,
				tickInterval = 1,
				stacks = Burn.add(0, 1, cap),
			})
			T.expect(first.stacks).toBe(1)
			local second = EffectStack.restack(first, {
				unit = BURN.pct,
				tickUnit = 10,
				maxStacks = cap,
				duration = BURN.duration,
				now = 2,
				tickInterval = 1,
				stacks = Burn.add(first.stacks, 2, cap),
			})
			T.expect(second.stacks).toBe(3)
			T.expect(second.expiresAt).toBe(2 + BURN.duration) -- the refresh renews the time
			-- uncapped accumulate (StatusEffectService ApplyOptions.uncapped): a small hit after a big one loses nothing
			local big = { tickAmount = 100, nextTick = 3, expiresAt = 4 }
			local tick, nextTick = EffectStack.accumulate(big, { total = 30, duration = 4, now = 2, interval = 1 })
			local unpaid = 100 * EffectStack.ticksBetween(3, 4, 1)
			T.expect(nextTick).toBe(3)
			T.expect(tick * EffectStack.ticksBetween(3, 6, 1)).toBeNear(unpaid + 30, 1e-9)
			local capped = EffectStack.accumulate(big, { total = 30, limit = cap, duration = 4, now = 2, interval = 1 })
			T.expect(capped < tick).toBe(true)
		end
	)
end)

T.describe("Burn: Kindling, Immolate, Combustion (S140)", function()
	T.it("Kindling's bonus per own stack and Immolate's per stack", function()
		T.expect(Burn.stackBonus(0, 5)).toBe(1)
		T.expect(Burn.stackBonus(3, 5)).toBeNear(1.15, 1e-9)
		T.expect(Burn.stackBonus(2, 0)).toBe(1)
		T.expect(Burn.vsBurning(0, 10)).toBe(1)
		T.expect(Burn.vsBurning(1, 10)).toBeNear(1.1, 1e-9)
		T.expect(Burn.vsBurning(3, 16)).toBeNear(1.48, 1e-9)
	end)

	T.it("Combustion: pct x stacks, a stun from BURN.stunAt stacks, nothing without a burn", function()
		T.expect({ Burn.detonate(0, 60) }).toEqual({ 0, false })
		T.expect({ Burn.detonate(1, 60) }).toEqual({ 60, false })
		local pct, stuns = Burn.detonate(BURN.stunAt, 60)
		T.expect(pct).toBe(60 * BURN.stunAt)
		T.expect(stuns).toBe(true)
		T.expect({ Burn.detonate(BURN.stunAt - 1, 60) }).toEqual({ 60 * (BURN.stunAt - 1), false })
	end)

	T.it("the data: fire skills set stacks, Combustion and Immolate read them", function()
		T.expect((SkillData.get("flameWave") :: any).burnStacks).toBe(1)
		T.expect((SkillData.get("pyroblast") :: any).burnStacks).toBe(2)
		T.expect((SkillData.get("meteorStorm") :: any).burnStacks).toBe(1)
		T.expect((SkillData.get("combustion") :: any).values.detonate ~= nil).toBe(true)
		T.expect((SkillData.get("immolate") :: any).values.vsBurning ~= nil).toBe(true)
		-- add.burnStacks of a breakpoint raises the skill's stacks (Skills.effective)
		local pyro = SkillData.get("pyroblast") :: any
		local def = Skills.effective(pyro, 10, { ["pyroblast:10"] = "a" }, nil, true)
		T.expect((def :: any).burnStacks).toBe(3)
		local args = Skills.descriptionArgs(SkillData.get("combustion") :: any, 1)
		T.expect(args.stunAt).toBe(BURN.stunAt)
		T.expect(Skills.descriptionArgs(SkillData.get("flameWave") :: any, 1).knockback).toBe(6)
	end)
end)

T.describe("Burn: Phoenix Heart (S140)", function()
	local phoenix = SkillData.get("phoenixHeart") :: any

	T.it(
		"saves a lethal blow of a monster, an intercepted blow and a player's blow; never a tick or the world",
		function()
			T.expect({ Burn.phoenixSave(100, 250, "monster", true, nil, 10) }).toEqual({ 99, true })
			T.expect({ Burn.phoenixSave(100, 100, "intercept", true, nil, 10) }).toEqual({ 99, true })
			T.expect({ Burn.phoenixSave(100, 250, "pvp", true, nil, 10) }).toEqual({ 99, Combat.pvp.phoenix > 0 })
			T.expect({ Burn.phoenixSave(100, 250, "burn", true, nil, 10) }).toEqual({ 250, false })
			T.expect({ Burn.phoenixSave(100, 250, "world", true, nil, 10) }).toEqual({ 250, false })
			T.expect({ Burn.phoenixSave(100, 250, "admin", true, nil, 10) }).toEqual({ 250, false })
			T.expect({ Burn.phoenixSave(100, 99, "monster", true, nil, 10) }).toEqual({ 99, false }) -- not lethal
			T.expect({ Burn.phoenixSave(100, 250, "monster", false, nil, 10) }).toEqual({ 250, false })
		end
	)

	T.it("once per rest: ready again only after the passive's rest", function()
		local rest = Skills.valueAt(phoenix, "rest", 1)
		local ready = Burn.phoenixReady(10, rest)
		T.expect(ready).toBe(10 + rest)
		T.expect({ Burn.phoenixSave(100, 250, "monster", true, ready, ready - 1) }).toEqual({ 250, false })
		T.expect({ Burn.phoenixSave(100, 250, "monster", true, ready, ready) }).toEqual({ 99, true })
		T.expect(rest).toBe(180)
	end)

	T.it("invulnerability: the passive's seconds, shorter after a player's blow", function()
		local seconds = Skills.valueAt(phoenix, "invuln", 1)
		T.expect(Burn.phoenixInvuln(seconds, false)).toBe(seconds)
		T.expect(Burn.phoenixInvuln(seconds, true)).toBeNear(seconds * Combat.pvp.phoenix, 1e-9)
		local totals = { flat = {}, pct = {}, hooks = {} }
		Skills.addPassive(totals :: any, phoenix, 5)
		T.expect(totals.hooks.phoenixHeart).toBeNear(Skills.valueAt(phoenix, "blast", 5), 1e-9)
		T.expect(totals.hooks.phoenixRest).toBe(180)
	end)
end)
