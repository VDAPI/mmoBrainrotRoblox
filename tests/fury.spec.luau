--!strict
-- Fury of the Berserker (S72, ROZWOJ 10.4): Logic/Fury with Data/Paths HOOK_RULES.

local Fury = require("../src/shared/Logic/Fury")
local Paths = require("../src/shared/Data/Paths")
local SkillData = require("../src/shared/Data/Skills")
local T = require("./Test")

local RULES = Paths.HOOK_RULES.fury

local function full(at: number): Fury.State
	return { stacks = 10, base = 10, quietSince = at, lastGain = at }
end

T.describe("Fury: gain", function()
	T.it("one stack per hit, at most one per gainInterval", function()
		local s = Fury.gain(Fury.new(), 0, 10, 1, RULES)
		T.expect(s.stacks).toBe(1)
		s = Fury.gain(s, 0.1, 10, 1, RULES)
		T.expect(s.stacks).toBe(1)
		T.expect(s.quietSince).toBe(0.1)
		s = Fury.gain(s, 0.25, 10, 1, RULES)
		T.expect(s.stacks).toBe(2)
	end)

	T.it("stops at max", function()
		local s = Fury.new()
		for i = 0, 9 do
			s = Fury.gain(s, i * 0.25, 10, 1, RULES)
		end
		T.expect(s.stacks).toBe(10)
		s = Fury.gain(s, 2.5, 10, 1, RULES)
		T.expect(s.stacks).toBe(10)
		local nine: Fury.State = { stacks = 9, base = 9, quietSince = 0, lastGain = 0 }
		T.expect(Fury.gain(nine, 1, 10, 2, RULES).stacks).toBe(10)
	end)

	T.it("no Fury without furyMax", function()
		T.expect(Fury.gain(Fury.new(), 0, 0, 1, RULES).stacks).toBe(0)
	end)
end)

T.describe("Fury: decay", function()
	T.it("falls two stacks per second after four quiet seconds", function()
		local s = full(0)
		T.expect(Fury.step(s, 3.9, 10, true, false, RULES).stacks).toBe(10)
		T.expect(Fury.step(s, 4.5, 10, true, false, RULES).stacks).toBe(9)
		T.expect(Fury.step(s, 5.0, 10, true, false, RULES).stacks).toBe(8)
		T.expect(Fury.step(s, 8.0, 10, true, false, RULES).stacks).toBe(2)
		T.expect(Fury.step(s, 9.0, 10, true, false, RULES).stacks).toBe(0)
	end)

	T.it("gone out of combat, clamped to a lower max", function()
		T.expect(Fury.step(full(0), 1, 10, false, false, RULES).stacks).toBe(0)
		T.expect(Fury.step(full(0), 1, 4, true, false, RULES).stacks).toBe(4)
	end)

	T.it("Carnage holds the stacks and restarts the clock", function()
		local s = Fury.step(full(0), 10, 10, true, true, RULES)
		T.expect(s.stacks).toBe(10)
		T.expect(s.quietSince).toBe(10)
		T.expect(Fury.step(s, 13.9, 10, true, false, RULES).stacks).toBe(10)
		T.expect(Fury.step(s, 14.5, 10, true, false, RULES).stacks).toBe(9)
	end)
end)

T.describe("Fury: consume and set", function()
	T.it("consume spends every stack", function()
		local s, spent = Fury.consume(full(0))
		T.expect(s.stacks).toBe(0)
		T.expect(spent).toBe(10)
		local empty, none = Fury.consume(Fury.new())
		T.expect(empty.stacks).toBe(0)
		T.expect(none).toBe(0)
	end)

	T.it("set clamps and restarts the clock", function()
		local s = Fury.set(Fury.new(), 20, 5, 10)
		T.expect(s.stacks).toBe(5)
		T.expect(s.quietSince).toBe(20)
		T.expect(Fury.set(Fury.new(), 20, 15, 10).stacks).toBe(10)
		T.expect(Fury.set(Fury.new(), 20, -1, 10).stacks).toBe(0)
	end)

	T.it("never changes its input", function()
		local frozen = table.freeze(full(0))
		Fury.gain(frozen, 1, 10, 1, RULES)
		Fury.step(frozen, 5, 10, true, false, RULES)
		Fury.step(frozen, 5, 10, true, true, RULES)
		Fury.consume(frozen)
		Fury.set(frozen, 1, 3, 10)
		T.expect(frozen.stacks).toBe(10)
	end)
end)

T.describe("Fury: data", function()
	T.it("rules and Carnage resets", function()
		T.expect(RULES.maxStacks).toBe(10)
		local warrior: { [string]: boolean } = {}
		for _, def in SkillData.byClass.Warrior do
			warrior[def.id] = true
		end
		for _, id in Paths.HOOK_RULES.carnage.resets do
			local def = SkillData.get(id)
			T.expect(def ~= nil and warrior[id] == true).toBe(true)
			T.expect(def ~= nil and def.type ~= "passive").toBe(true)
		end
	end)
end)
