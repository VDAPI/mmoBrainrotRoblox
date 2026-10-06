--!strict
-- S25: guide path helpers (Logic/NavPath).

local NavPath = require("../src/shared/Logic/NavPath")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function p(x: number, z: number, y: number?, jump: boolean?): NavPath.Point
	return { x = x, y = y or 0, z = z, jump = jump }
end

describe("NavPath", function()
	it("simplify keeps the ends and drops collinear points", function()
		local points = { p(0, 0), p(5, 0), p(10, 0.2), p(15, 0), p(20, 0), p(20, 10), p(20, 20) }
		local simple = NavPath.simplify(points)
		expect(#simple).toBe(3)
		expect(simple[1]).toEqual(points[1])
		expect(simple[2]).toEqual(p(20, 0))
		expect(simple[3]).toEqual(points[#points])
	end)

	it("simplify keeps jumps and height changes", function()
		local points = { p(0, 0), p(5, 0, 0, true), p(10, 0), p(15, 0, 6), p(20, 0) }
		local simple = NavPath.simplify(points)
		local jump, high = false, false
		for _, point in simple do
			jump = jump or point.jump == true
			high = high or point.y == 6
		end
		expect({ jump, high, #simple < #points or #simple == #points }).toEqual({ true, true, true })
		-- A flat stretch around a jump keeps only the jump.
		local flat = NavPath.simplify({ p(0, 0), p(5, 0), p(10, 0, 0, true), p(15, 0), p(20, 0) })
		expect(#flat).toBe(3)
		expect(flat[2].jump).toBe(true)
	end)

	it("short paths stay as they are", function()
		expect(NavPath.simplify({ p(0, 0), p(1, 1) })).toEqual({ p(0, 0), p(1, 1) })
		expect(NavPath.simplify({})).toEqual({})
	end)

	it("length sums the segments", function()
		expect(NavPath.length({ p(0, 0), p(3, 4), p(3, 10) })).toBeNear(11, 1e-6)
		expect(NavPath.length({ p(0, 0) })).toBe(0)
	end)

	it("deviated is false on the path and true far from it", function()
		local path = { p(0, 0), p(100, 0), p(100, 100) }
		expect(NavPath.deviated(path, p(50, 3), 10)).toBe(false)
		expect(NavPath.deviated(path, p(103, 60), 10)).toBe(false)
		expect(NavPath.deviated(path, p(50, 30), 10)).toBe(true)
		expect(NavPath.deviated(path, p(-20, 0), 10)).toBe(true)
	end)

	it("progress measures the distance along and left", function()
		local path = { p(0, 0), p(100, 0), p(100, 100) }
		local at = NavPath.progress(path, p(100, 40))
		expect(at.segment).toBe(2)
		expect(at.along).toBeNear(140, 1e-6)
		expect(at.remaining).toBeNear(60, 1e-6)
		expect(at.distance).toBeNear(0, 1e-6)
	end)

	it("progress does not jump back to an earlier segment", function()
		-- A U-turn: the end passes near the start.
		local path = { p(0, 0), p(100, 0), p(100, 8), p(0, 8) }
		local late = NavPath.progress(path, p(5, 7), 3)
		expect(late.segment).toBe(3)
	end)

	it("markers sit at fixed path distances ahead", function()
		local path = { p(0, 0), p(100, 0) }
		local markers = NavPath.markers(path, 13, 6, 30, 40)
		expect(#markers).toBe(5)
		expect(markers[1].x).toBeNear(18, 1e-6)
		expect(markers[5].x).toBeNear(42, 1e-6)
		expect(markers[1].dx).toBeNear(1, 1e-6)
		-- Capped by the end of the path and by the count.
		expect(#NavPath.markers(path, 97, 6, 30, 40)).toBe(0)
		expect(#NavPath.markers(path, 95, 6, 30, 40)).toBe(1)
		expect(#NavPath.markers(path, 0, 1, 100, 10)).toBe(10)
	end)
end)

return nil
