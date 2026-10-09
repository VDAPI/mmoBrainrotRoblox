--!strict
-- FIX 2026-10-09: monsters steer around obstacles (Logic/Steer).
local Combat = require("../src/shared/Data/Combat")
local Steer = require("../src/shared/Logic/Steer")
local T = require("./Test")

-- Blocks every direction within `degrees` of +x (an obstacle straight ahead when walking +x).
local function wall(degrees: number): (number, number) -> boolean
	return function(x, z)
		return math.abs(math.atan2(z, x)) < math.rad(degrees)
	end
end

T.describe("Steer", function()
	T.it("goes straight on when the way is clear (unit direction)", function()
		local x, z, side = Steer.choose(10, 0, function()
			return false
		end)
		T.expect(x).toBeNear(1)
		T.expect(z).toBeNear(0)
		T.expect(side).toBe(0)
	end)

	T.it("turns by the first clear angle, preferring the side it took before", function()
		local x, z, side = Steer.choose(5, 0, wall(30), nil)
		T.expect(side).toBe(1)
		T.expect(math.deg(math.atan2(z, x))).toBeNear(Combat.steerAngles[1])
		local _, z2, side2 = Steer.choose(5, 0, wall(30), -1)
		T.expect(side2).toBe(-1)
		T.expect(z2 < 0).toBe(true)
		local x3, z3 = Steer.choose(5, 0, wall(50), 1)
		T.expect(math.deg(math.atan2(z3, x3))).toBeNear(Combat.steerAngles[2])
	end)

	T.it("falls back to the goal direction when everything is blocked", function()
		local x, z, side = Steer.choose(0, 3, function()
			return true
		end)
		T.expect(x).toBeNear(0)
		T.expect(z).toBeNear(1)
		T.expect(side).toBe(0)
		local x0, z0 = Steer.choose(0, 0, function()
			return true
		end)
		T.expect(x0).toBe(0)
		T.expect(z0).toBe(0)
	end)
end)
