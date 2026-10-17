--!strict
-- Fury of the Berserker (S72, ROZWOJ 10.4): Logic/Fury with Data/Paths HOOK_RULES. S143: Rage (the two-handed P1).

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

-- S143 (DESIGN-18 §6.2): Rage, the two-handed school's passive, is the only source of Fury; the Berserker's nodes raise
-- its cap; Brutal Strike gives two stacks; Unstoppable works at full Fury.
local GamePaths = require("../src/shared/Logic/Paths")
local Items = require("../src/shared/Data/Items")

local function itemOf(itemType: string): string
	local best: string? = nil
	for id, def in Items.byId do
		if def.type == itemType and (best == nil or id < best) then
			best = id
		end
	end
	assert(best, `no item of type {itemType}`)
	return best
end

local function warrior(level: number, weapon: string, ranks: { [string]: any }, nodes: { [string]: number }): any
	return {
		class = "Warrior",
		level = level,
		path = { nodes = nodes, bp = {} },
		hotbar = {},
		equipment = { weapon = { id = itemOf(weapon) } },
		ranks = ranks,
		bars = {},
		barPool = if weapon == "axe2h" then "twohand" else "onehand",
	}
end

local function capOf(c: any, weapon: string): number
	local hooks = GamePaths.passiveTotals(c, { main = weapon }).hooks
	return Fury.cap(hooks.furyMax or 0, hooks.rage or 0, RULES.maxStacks)
end

T.describe("Fury: Rage (S143)", function()
	T.it("the cap: only with Rage, the furyMax hook up to maxStacks", function()
		T.expect(Fury.cap(16, 0, RULES.maxStacks)).toBe(0)
		T.expect(Fury.cap(16, 6, RULES.maxStacks)).toBe(RULES.maxStacks)
		T.expect(Fury.cap(6, 6, RULES.maxStacks)).toBe(6)
		T.expect(Fury.cap(6.9, 6, RULES.maxStacks)).toBe(6)
		T.expect(Fury.cap(-3, 6, RULES.maxStacks)).toBe(0)
		-- without Fury nothing is gained and furyConsume spends nothing
		local s = Fury.gain(Fury.new(), 0, Fury.cap(10, 0, RULES.maxStacks), 2, RULES)
		T.expect(s.stacks).toBe(0)
		local _, spent = Fury.consume(s)
		T.expect(spent).toBe(0)
	end)

	T.it("Fury only from Rage: Battle Rhythm alone gives none, with Rage it raises the cap", function()
		local rhythm = { berserker_scars = 1, berserker_wounds = 1, berserker_rhythm = 3 }
		T.expect(capOf(warrior(30, "axe2h", { twohand = {} }, rhythm), "axe2h")).toBe(0)
		local rage = (SkillData.get("rage") :: any).values.fury
		T.expect(capOf(warrior(30, "axe2h", { twohand = { rage = 1 } }, {}), "axe2h")).toBe(rage)
		T.expect(capOf(warrior(30, "axe2h", { twohand = { rage = 1 } }, rhythm), "axe2h")).toBe(RULES.maxStacks)
		-- every rank of Battle Rhythm counts above Rage's stacks (no rank lost to the clamp)
		local caps = {}
		for rank = 1, 3 do
			local nodes = { berserker_scars = 1, berserker_wounds = 1, berserker_rhythm = rank }
			caps[rank] = capOf(warrior(30, "axe2h", { twohand = { rage = 1 } }, nodes), "axe2h")
		end
		T.expect(caps).toEqual({ rage + 2, rage + 3, RULES.maxStacks })
		-- Rage is of the two-handed pool: a one-handed weapon has no Fury even with the bought ranks there
		T.expect(capOf(warrior(30, "sword1h", { twohand = { rage = 1 } }, rhythm), "sword1h")).toBe(0)
		-- below its unlock (20) Rage has no rank
		T.expect(capOf(warrior(19, "axe2h", { twohand = { rage = 1 } }, rhythm), "axe2h")).toBe(0)
	end)

	T.it("hitGain: the skill's furyGain or Carnage's, the larger", function()
		local carnage = Paths.HOOK_RULES.carnage.furyGain
		T.expect(Fury.hitGain(nil, false, carnage)).toBe(1)
		T.expect(Fury.hitGain(2, false, carnage)).toBe(2)
		T.expect(Fury.hitGain(nil, true, carnage)).toBe(carnage)
		T.expect(Fury.hitGain(carnage + 1, true, carnage)).toBe(carnage + 1)
		T.expect((SkillData.get("brutalStrike") :: any).furyGain).toBe(2)
		local two = Fury.gain(Fury.new(), 0, 10, Fury.hitGain(2, false, carnage), RULES)
		T.expect(two.stacks).toBe(2)
	end)

	T.it("unstoppable: the hook at full Fury only", function()
		T.expect(Fury.unstoppable(1, 10, 10)).toBe(true)
		T.expect(Fury.unstoppable(1, 6, 6)).toBe(true)
		T.expect(Fury.unstoppable(1, 9, 10)).toBe(false)
		T.expect(Fury.unstoppable(0, 10, 10)).toBe(false)
		T.expect(Fury.unstoppable(1, 0, 0)).toBe(false)
	end)

	T.it("data: Rage P1 and Unstoppable P2 of the two-handed pool; Fury consumers; the Fury nodes need Rage", function()
		local rage = SkillData.get("rage") :: any
		T.expect({ rage.pool, rage.role, rage.type, rage.unlock }).toEqual({ "twohand", "P1", "passive", 20 })
		T.expect(rage.passive.hooks.rage ~= nil and rage.passive.hooks.furyMax ~= nil).toBe(true)
		local unstoppable = SkillData.get("unstoppable") :: any
		T.expect({ unstoppable.pool, unstoppable.role }).toEqual({ "twohand", "P2" })
		T.expect(unstoppable.passive.hooks.unstoppable ~= nil).toBe(true)
		for _, id in { "rend", "execute", "carnage" } do
			local def = SkillData.get(id) :: any
			T.expect({ id, def.furyConsume ~= nil }).toEqual({ id, true })
		end
		-- no Warrior skill but Rage gives the rage hook, so Fury comes from the two-handed pool only
		for _, def in SkillData.byClass.Warrior do
			local hooks = def.passive and def.passive.hooks
			if hooks and hooks.rage then
				T.expect({ def.id, def.pool }).toEqual({ def.id, "twohand" })
			end
		end
		for _, path in Paths.list do
			for _, row in path.rows do
				for _, n in row.nodes do
					local hooks = n.passive and n.passive.hooks
					T.expect({ n.id, hooks ~= nil and hooks.rage ~= nil }).toEqual({ n.id, false })
				end
			end
		end
	end)
end)
