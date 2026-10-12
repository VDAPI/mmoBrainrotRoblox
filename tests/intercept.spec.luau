--!strict
-- The Guardian's intercept (S61, ROZWOJ 7.6): Logic/Intercept.

local BuffCategories = require("../src/shared/Data/BuffCategories")
local Combat = require("../src/shared/Data/Combat")
local Intercept = require("../src/shared/Logic/Intercept")
local T = require("./Test")

local function candidate(guard: string, share: number, distance: number, alive: boolean?): Intercept.Candidate
	return { guard = guard, share = share, radius = 20, distance = distance, alive = alive ~= false }
end

local function maxHp(_guard: any): number
	return 1000
end

T.describe("Intercept", function()
	T.it("only monster blows move", function()
		T.expect(Intercept.applies("monster")).toBe(true)
		for _, source in { "pvp", "bleed", "poison", "burn", "admin", "intercept", "world", "unknown" } do
			T.expect(Intercept.applies(source)).toBe(false)
		end
	end)

	T.it("pick: alive, in range, highest share, then the closer one", function()
		T.expect(Intercept.pick({ candidate("dead", 30, 5, false) })).toBeNil()
		T.expect(Intercept.pick({ candidate("far", 30, 21) })).toBeNil()
		local best = Intercept.pick({ candidate("a", 20, 5), candidate("b", 30, 15), candidate("c", 25, 1) })
		T.expect(best and best.guard).toBe("b")
		local tie = Intercept.pick({ candidate("a", 30, 10), candidate("b", 30, 4), candidate("c", 30, 4) })
		T.expect(tie and tie.guard).toBe("b")
		local skipDead = Intercept.pick({ candidate("a", 40, 1, false), candidate("b", 10, 19) })
		T.expect(skipDead and skipDead.guard).toBe("b")
	end)

	T.it("the share is capped", function()
		T.expect(Intercept.part(1000, 40)).toBeNear(1000 * BuffCategories.caps.intercept / 100, 1e-9)
		T.expect(Intercept.part(1000, 10)).toBeNear(100, 1e-9)
	end)

	T.it("a guard takes at most 25% of max HP per window, fixed from the first take", function()
		local windows: { [any]: Intercept.Window } = {}
		local guards = { candidate("g", 30, 5) }
		local moved: { number } = {}
		for i = 1, 3 do
			local kept, chosen, m = Intercept.resolve("monster", 600, guards, windows, 10 + i * 0.1, maxHp)
			T.expect(chosen and chosen.guard).toBe("g")
			T.expect(kept + m).toBeNear(600, 1e-9)
			table.insert(moved, m)
		end
		T.expect(moved[1]).toBeNear(180, 1e-9)
		T.expect(moved[2]).toBeNear(70, 1e-9)
		T.expect(moved[3]).toBeNear(0, 1e-9)
		local _, _, again = Intercept.resolve("monster", 600, guards, windows, 10.1 + Combat.interceptWindow, maxHp)
		T.expect(again).toBeNear(180, 1e-9)
	end)

	T.it("two guards intercepting each other never pass damage back", function()
		local windows: { [any]: Intercept.Window } = {}
		-- A is guarded by B and B by A: a monster blow on A moves part to B ...
		local keptA, chosen, moved = Intercept.resolve("monster", 500, { candidate("B", 30, 5) }, windows, 1, maxHp)
		T.expect(chosen and chosen.guard).toBe("B")
		T.expect(moved).toBeNear(150, 1e-9)
		T.expect(keptA).toBeNear(350, 1e-9)
		-- ... and that part, resolved as a hit on B from "intercept", stays on B in full.
		local keptB, back, movedBack =
			Intercept.resolve("intercept", moved, { candidate("A", 30, 5) }, windows, 1, maxHp)
		T.expect(back).toBeNil()
		T.expect(movedBack).toBe(0)
		T.expect(keptB).toBe(moved)
	end)

	T.it("damage over time and PvP move nothing", function()
		local windows: { [any]: Intercept.Window } = {}
		for _, source in { "pvp", "poison", "bleed", "admin" } do
			local kept, chosen, moved = Intercept.resolve(source, 400, { candidate("g", 30, 1) }, windows, 1, maxHp)
			T.expect(kept).toBe(400)
			T.expect(chosen).toBeNil()
			T.expect(moved).toBe(0)
		end
		T.expect(next(windows)).toBeNil()
	end)
end)

T.describe("Martyr and Retribution (S72)", function()
	T.it("split reads the part before mitigation", function()
		local function check(moved: number, mitigation: number, thorns: number, guard: number, back: number)
			local toGuard, reflected = Intercept.split(moved, mitigation, thorns)
			T.expect(toGuard).toBeNear(guard, 1e-9)
			T.expect(reflected).toBe(back)
		end
		check(100, 30, 0, 70, 0)
		check(100, 0, 20, 100, 20)
		check(100, 30, 30, 70, 30)
		check(3, 0, 10, 3, 1)
		check(0, 30, 30, 0, 0)
		check(100, -5, -5, 100, 0)
		check(100, 150, 0, 0, 0)
	end)

	T.it("the per-second window counts the part before Martyr", function()
		local windows: { [any]: Intercept.Window } = {}
		local expected = { { 180, 126 }, { 70, 49 }, { 0, 0 } }
		for _, pair in expected do
			local _, _, moved = Intercept.resolve("monster", 600, { candidate("g", 30, 1) }, windows, 1, maxHp)
			T.expect(moved).toBeNear(pair[1], 1e-9)
			local toGuard = Intercept.split(moved, 30, 0)
			T.expect(toGuard).toBeNear(pair[2], 1e-9)
		end
	end)
end)

return nil
