--!strict
-- Knockback and pull (S28). Pure (plain numbers, Lune tests): where a hit entity ends up on the ground plane. The
-- server raycasts along the path and passes the fraction of the way that is free (1 = nothing in the way), so the
-- result never ends inside a wall. Horizontal only (the server puts the body back on the ground).

local Knockback = {}

-- Studs kept between the body and the wall it stopped at.
Knockback.WALL_GAP = 1.5
-- Pulled enemies stop this far from the puller.
Knockback.PULL_GAP = 3
-- Players in PvP are moved by this share of the distance.
Knockback.PVP_SHARE = 0.5

-- Unit direction (x, z) pushing a target at (tx, tz) away from a source at (sx, sz); (fx, fz) when they stand on
-- each other (default -Z).
function Knockback.direction(tx: number, tz: number, sx: number, sz: number, fx: number?, fz: number?): (number, number)
	local dx, dz = tx - sx, tz - sz
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.05 then
		local ax, az = fx or 0, fz or -1
		local l = math.sqrt(ax * ax + az * az)
		if l < 0.05 then
			return 0, -1
		end
		return ax / l, az / l
	end
	return dx / length, dz / length
end

-- Final (x, z) of a push from (ox, oz): `distance` studs along (dx, dz), shortened to the free fraction of the path
-- minus the wall gap (never behind the start).
function Knockback.destination(
	ox: number,
	oz: number,
	dx: number,
	dz: number,
	distance: number,
	freeFraction: number?
): (number, number)
	local free = math.clamp(freeFraction or 1, 0, 1)
	local length = distance * free
	if free < 1 then
		length = math.max(0, length - Knockback.WALL_GAP)
	end
	local l = math.sqrt(dx * dx + dz * dz)
	if l < 1e-4 or length <= 0 then
		return ox, oz
	end
	return ox + dx / l * length, oz + dz / l * length
end

-- How far a pull moves a target at (tx, tz) towards (x, z) (stops PULL_GAP short; 0 when already closer).
function Knockback.pullDistance(tx: number, tz: number, x: number, z: number): number
	local dx, dz = x - tx, z - tz
	return math.max(0, math.sqrt(dx * dx + dz * dz) - Knockback.PULL_GAP)
end

-- Distance for the kind of target (bosses do not move, players half).
function Knockback.scaled(distance: number, kind: string): number
	if kind == "boss" then
		return 0
	elseif kind == "player" then
		return distance * Knockback.PVP_SHARE
	end
	return distance
end

-- Share of the way covered at progress u (0..1): fast at the start, easing out.
function Knockback.progress(u: number): number
	local t = math.clamp(u, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

return Knockback
