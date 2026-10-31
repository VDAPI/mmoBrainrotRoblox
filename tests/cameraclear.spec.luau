--!strict
local T = require("./Test")
local CameraClear = require("../src/shared/Logic/CameraClear")
local TownGeom = require("../src/shared/Logic/TownGeom")

-- Smallest angle between two yaws (degrees).
local function gap(a: number, b: number): number
	local d = math.abs(a - b) % 360
	return math.min(d, 360 - d)
end

T.describe("CameraClear", function()
	T.it("puts the camera behind the facing and over the head", function()
		for _, yaw in { 0, 20, 90, 135, 270 } do
			local fx, fz = TownGeom.front(yaw)
			local x, y, z = CameraClear.behind(yaw, CameraClear.START_PITCH)
			T.expect(x * fx + z * fz).toBeNear(-math.cos(math.rad(CameraClear.START_PITCH)), 1e-9)
			T.expect(y).toBeNear(math.sin(math.rad(CameraClear.START_PITCH)), 1e-9)
			T.expect(x * x + y * y + z * z).toBeNear(1, 1e-9)
		end
	end)

	T.it("reads the yaw back from a look direction", function()
		for _, yaw in { 0, 20, 90, 180, 200, 359 } do
			local fx, fz = TownGeom.front(yaw)
			T.expect(gap(CameraClear.yawOf(fx, fz), yaw)).toBeNear(0, 1e-6)
		end
		-- a CFrame with no turn looks along -Z: yaw 0
		T.expect(CameraClear.yawOf(0, -1)).toBeNear(0, 1e-9)
	end)

	T.it("searches every direction once, nearest the preferred first", function()
		local list = CameraClear.yaws(20, 12)
		T.expect(#list).toBe(12)
		T.expect(list[1]).toBe(20)
		local seen = {}
		for i, yaw in list do
			local key = math.floor(yaw + 0.5) % 360
			T.expect(seen[key]).toBeNil()
			seen[key] = true
			if i > 1 then
				T.expect(gap(yaw, 20) >= gap(list[i - 1], 20)).toBe(true)
			end
		end
		T.expect(#CameraClear.yaws(0, 5)).toBe(5)
	end)

	T.it("keeps the preferred facing when its view is clear", function()
		local calls = 0
		local yaw = CameraClear.pick(20, function(_candidate: number)
			calls += 1
			return 100, 100
		end)
		T.expect(yaw).toBe(20)
		T.expect(calls).toBe(1)
	end)

	T.it("turns away from a house behind to the nearest clear way", function()
		-- a house wall 4 studs south of the spot: facing north (yaw 0) puts the camera in it, as a saved spot did
		local function measure(candidate: number): (number, number)
			local _, _, z = CameraClear.behind(candidate, CameraClear.START_PITCH)
			local blocked = z > 0.3 -- the camera line goes south
			return if blocked then 4 / z else 100, 100
		end
		local yaw = CameraClear.pick(0, measure)
		local x, _, z = CameraClear.behind(yaw, CameraClear.START_PITCH)
		T.expect(z <= 0.3).toBe(true)
		T.expect(math.abs(x) > 0).toBe(true)
		-- the nearest clear one (90 or 270 first after the blocked 30 / 60 steps)
		T.expect(gap(yaw, 0)).toBeNear(90, 1e-9)
	end)

	T.it("does not face a wall right ahead either", function()
		local yaw = CameraClear.pick(0, function(candidate: number): (number, number)
			if gap(candidate, 0) < 1 then
				return 100, 2 -- clear camera line, a wall 2 studs in front
			end
			return 100, 100
		end)
		T.expect(gap(yaw, 0)).toBeNear(30, 1e-9)
	end)

	T.it("takes the longest camera line when no way is clear", function()
		local yaw = CameraClear.pick(0, function(candidate: number): (number, number)
			return if gap(candidate, 150) < 1 then 9 else 3, 1
		end)
		T.expect(gap(yaw, 150)).toBeNear(0, 1e-9)
	end)

	T.it("pulls the camera in front of a wall, never through the head", function()
		T.expect(CameraClear.reach(12.5, nil, 1.5)).toBe(12.5)
		T.expect(CameraClear.reach(12.5, 8, 1.5)).toBe(6.5)
		T.expect(CameraClear.reach(12.5, 0.5, 1.5)).toBe(CameraClear.MIN_REACH)
		T.expect(CameraClear.reach(12.5, 20, 1.5)).toBe(12.5)
		T.expect(CameraClear.reach(0.6, 0.3, 1.5)).toBe(0.6)
	end)

	T.it("snaps in at once and eases back out", function()
		local wanted = 12.5
		-- a wall comes in: held at once
		local hold = CameraClear.ease(nil, 4, wanted, 1 / 60)
		T.expect(hold).toBe(4)
		-- closer still: in at once
		hold = CameraClear.ease(hold, 2, wanted, 1 / 60)
		T.expect(hold).toBe(2)
		-- the wall is gone: out at EASE_OUT studs a second, then free
		local frames = 0
		while hold ~= nil and frames < 1000 do
			local before = hold :: number
			hold = CameraClear.ease(hold, wanted, wanted, 1 / 60)
			if hold then
				T.expect(hold - before).toBeNear(CameraClear.EASE_OUT / 60, 1e-9)
			end
			frames += 1
		end
		T.expect(hold).toBeNil()
		T.expect(frames).toBeBetween(15, 20)
		-- nothing in the way and nothing held: free at once
		T.expect(CameraClear.ease(nil, wanted, wanted, 1 / 60)).toBeNil()
		-- zooming in past the hold frees it
		T.expect(CameraClear.ease(5, 3, 3, 1 / 60)).toBeNil()
	end)
end)
