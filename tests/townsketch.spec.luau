--!strict
-- City map sketch (S21): every shape is well formed, inside the map and the total stays cheap for the UI.
local T = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local TownSketch = require("../src/shared/Logic/TownSketch")

T.describe("TownSketch", function()
	local shapes = TownSketch.shapes()
	local half = Town.city.size / 2

	T.it("keeps the shape count low enough for the map UI", function()
		T.expect(#shapes > 300).toBe(true)
		T.expect(#shapes < 1000).toBe(true)
	end)

	T.it("produces well-formed shapes inside the map", function()
		for _, s in shapes do
			T.expect(type(s.c)).toBe("string")
			if s.t == "rect" then
				T.expect(s.w > 0 and s.h > 0).toBe(true)
				T.expect(math.abs(s.x) <= half and math.abs(s.z) <= half).toBe(true)
			elseif s.t == "circle" then
				T.expect(s.r > 0).toBe(true)
			else
				T.expect(s.t).toBe("line")
				T.expect(#s.p >= 4 and #s.p % 2 == 0).toBe(true)
			end
		end
	end)

	T.it("pushes the moat outside the wall", function()
		local ring = TownSketch.offset(Town.city.wall, 13)
		for _, p in ring do
			T.expect(TownGeom.inPoly(Town.city.wall, p[1], p[2])).toBe(false)
		end
	end)

	T.it("covers a polygon with strips", function()
		local out = {}
		TownSketch.strips({ { 0, 0 }, { 20, 0 }, { 20, 20 }, { 0, 20 } }, 8, "plaza", out)
		local area = 0
		for _, s in out do
			area += s.w * s.h
		end
		T.expect(math.abs(area - 400) < 1e-6).toBe(true)
	end)
end)
