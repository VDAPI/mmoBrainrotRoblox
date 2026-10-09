--!strict
-- Obstacle steering of monsters (FIX 2026-10-09: they walked straight into rocks and trees and stood there).
-- Pure: the caller probes the world (`blocked(dx, dz)` = something solid within the look-ahead in that flat
-- direction) and walks the returned direction. Straight on when it is clear; otherwise the first clear one of
-- Combat.steerAngles to either side, trying the side it took last time first (no zig-zag between ticks).

local Combat = require("../Data/Combat")

local Steer = {}

local function rotate(x: number, z: number, degrees: number): (number, number)
	local a = math.rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return x * c - z * s, x * s + z * c
end

-- Direction (unit x, z) to walk towards the goal direction (x, z), and the side used (-1, 1, or 0 straight on).
-- With every direction blocked it returns the goal direction and side 0.
function Steer.choose(
	x: number,
	z: number,
	blocked: (dx: number, dz: number) -> boolean,
	preferSide: number?
): (number, number, number)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then
		return 0, 0, 0
	end
	x, z = x / length, z / length
	if not blocked(x, z) then
		return x, z, 0
	end
	local first = if preferSide == -1 then -1 else 1
	for _, angle in Combat.steerAngles do
		for _, side in { first, -first } do
			local dx, dz = rotate(x, z, angle * side)
			if not blocked(dx, dz) then
				return dx, dz, side
			end
		end
	end
	return x, z, 0
end

return Steer
