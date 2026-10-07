--!strict
-- S29: NPC feet on the ground (Logic/Footing).

local Footing = require("../src/shared/Logic/Footing")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- Rotation about Z by `deg` degrees, row-major.
local function rotZ(deg: number): { number }
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

-- Torso and two legs of a figure whose torso centre is at y; legs 2 studs long under it.
local function figure(y: number): { Footing.Box }
	return {
		{ p = { 0, y, 0 }, size = { 2, 2, 1 } },
		{ p = { -0.5, y - 2, 0 }, size = { 1, 2, 1 } },
		{ p = { 0.5, y - 2, 0 }, size = { 1, 2, 1 } },
	}
end

describe("Footing.liftFor", function()
	it("lifts a model whose legs are under the ground", function()
		-- Feet at y = 1 - 3 = -2, ground at 0.
		local dy = Footing.liftFor(figure(1), 0)
		expect(dy > 0).toBe(true)
		expect(dy).toBeNear(2 + Footing.CLEARANCE)
	end)

	it("lowers a hanging model", function()
		-- Feet at 10 - 3 = 7, ground at 2.
		local dy = Footing.liftFor(figure(10), 2)
		expect(dy < 0).toBe(true)
		expect(dy).toBeNear(2 + Footing.CLEARANCE - 7)
	end)

	it("leaves a standing model (almost) in place", function()
		expect(Footing.liftFor(figure(3 + Footing.CLEARANCE), 0)).toBeNear(0)
	end)

	it("measures rotated parts by their corners", function()
		-- A 1x4 bar tilted 90 degrees lies flat: half height 0.5, not 2.
		local flat = { { p = { 0, 5, 0 }, r = rotZ(90), size = { 1, 4, 1 } } }
		expect(Footing.lowest(flat)).toBeNear(4.5, 1e-6)
		-- At 45 degrees the lowest corner is (0.5 + 2) * sin 45 under the centre.
		local tilted = { { p = { 0, 5, 0 }, r = rotZ(45), size = { 1, 4, 1 } } }
		expect(Footing.lowest(tilted)).toBeNear(5 - 2.5 * math.sqrt(0.5), 1e-6)
		expect(Footing.liftFor(tilted, 5)).toBeNear(2.5 * math.sqrt(0.5) + Footing.CLEARANCE, 1e-6)
	end)

	it("returns 0 for no parts", function()
		expect(Footing.liftFor({}, 3)).toBe(0)
		expect(Footing.lowest({})).toBeNil()
	end)
end)

describe("Footing.hipHeight", function()
	it("is the gap from the root part's bottom to the ground", function()
		expect(Footing.hipHeight(5, 2, 2)).toBeNear(2 - Footing.CLEARANCE)
		expect(Footing.hipHeight(1, 2, 3)).toBe(0)
	end)
end)
