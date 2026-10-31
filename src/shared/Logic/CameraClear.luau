--!strict
-- Studio review 2026-10-31 (the first view after entering the world in a roof and a lamp): the camera's clear line.
-- The city's houses, walls, lamps and trees are asset kit models (W02, W12) whose visible parts neither collide nor
-- take rays, over invisible collision left by the generator; the Roblox camera's Popper only pulls in for opaque
-- colliding parts, so it saw none of it. CameraController pulls both camera modes in front of the map's colliding
-- geometry with one ray a frame (`reach`, `ease`); WorldService.OpenFacing turns a character entering the world on a
-- saved spot towards a direction whose start view is clear (`pick`). Pure: numbers only, runs in Lune.
--
-- Yaw: degrees about Y, the Roblox convention (CFrame.Angles(0, rad(yaw), 0)): 0 looks along -Z and the look is
-- (-sin, -cos), the same as TownGeom.front.

local CameraClear = {}

-- The Roblox camera's first view of a fresh character: START_ZOOM studs from the focus, START_PITCH degrees down,
-- behind the character (its starting zoom and INITIAL_CAMERA_ANGLE); the focus is HEAD studs over the root (R15).
CameraClear.START_ZOOM = 12.5
CameraClear.START_PITCH = 15
CameraClear.HEAD = 1.5
-- Facing search: COUNT directions round the spot; a direction is clear when its camera line is free for REACH studs
-- (the start zoom and the wall margin) and the view ahead for FRONT studs.
CameraClear.COUNT = 12
CameraClear.REACH = 14
CameraClear.FRONT = 8
-- Occlusion: the camera never comes nearer the focus than MIN_REACH; once a wall stops covering it, it goes back out
-- at most EASE_OUT studs a second (in at once).
CameraClear.MIN_REACH = 1
CameraClear.EASE_OUT = 40

-- Unit direction from the focus to the camera of a character facing `yaw`, the camera `pitch` degrees over the
-- horizon behind it.
function CameraClear.behind(yaw: number, pitch: number): (number, number, number)
	local r, p = math.rad(yaw), math.rad(pitch)
	local flat = math.cos(p)
	return math.sin(r) * flat, math.sin(p), math.cos(r) * flat
end

-- Yaw (0..360) of a flat look direction (x, z).
function CameraClear.yawOf(x: number, z: number): number
	return math.deg(math.atan2(-x, -z)) % 360
end

-- Search order: `preferred` first, then alternately right and left in steps of 360 / count, so the first clear
-- direction found is the one nearest the preferred.
function CameraClear.yaws(preferred: number, count: number): { number }
	local step = 360 / count
	local out = { preferred % 360 }
	for k = 1, count // 2 do
		table.insert(out, (preferred + k * step) % 360)
		if k * step < 180 then
			table.insert(out, (preferred - k * step) % 360)
		end
	end
	return out
end

-- Clear studs of a direction: along the camera line behind the character and ahead of it.
export type Measure = (yaw: number) -> (number, number)

-- The facing for a character placed on a spot: the first of `yaws(preferred)` that is clear (REACH behind, FRONT
-- ahead); with none, the one with the longest camera line, then the most open front, then the nearest the preferred.
function CameraClear.pick(preferred: number, measure: Measure, count: number?): number
	local reach, front = CameraClear.REACH, CameraClear.FRONT
	local best, bestBehind, bestFront = preferred % 360, -1, -1
	for _, yaw in CameraClear.yaws(preferred, count or CameraClear.COUNT) do
		local behind, ahead = measure(yaw)
		if behind >= reach and ahead >= front then
			return yaw
		end
		local b = math.min(behind, reach)
		if b > bestBehind or (b == bestBehind and ahead > bestFront) then
			best, bestBehind, bestFront = yaw, b, ahead
		end
	end
	return best
end

-- How far from the focus the camera may stand on a line `wanted` studs long whose first wall is `hit` studs out
-- (nil: nothing in the way): `margin` in front of the wall, never nearer than MIN_REACH (nor farther than wanted).
function CameraClear.reach(wanted: number, hit: number?, margin: number): number
	if hit == nil then
		return wanted
	end
	return math.clamp(hit - margin, math.min(CameraClear.MIN_REACH, wanted), wanted)
end

-- The distance the camera is held to this frame: `allowed` (from `reach`) and the hold of the last frame `previous`
-- (nil: none) moved out by at most EASE_OUT * dt. nil once the hold reaches `wanted` (the camera is free again).
function CameraClear.ease(previous: number?, allowed: number, wanted: number, dt: number): number?
	local hold = allowed
	if previous ~= nil then
		hold = math.min(allowed, previous + CameraClear.EASE_OUT * dt)
	end
	if hold >= wanted then
		return nil
	end
	return hold
end

return CameraClear
