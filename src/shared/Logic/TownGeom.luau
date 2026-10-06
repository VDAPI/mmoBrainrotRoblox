--!strict
-- 2D geometry for the city plan (S21): points are { x, z } arrays. Pure, no Roblox API.

local TownGeom = {}

type Vec2 = { number }

-- Even-odd point in polygon test. Points exactly on an edge may go either way.
function TownGeom.inPoly(poly: { Vec2 }, x: number, z: number): boolean
	local inside = false
	local n = #poly
	local j = n
	for i = 1, n do
		local xi, zi = poly[i][1], poly[i][2]
		local xj, zj = poly[j][1], poly[j][2]
		if (zi > z) ~= (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- Distance from (x, z) to segment a-b and the segment parameter t (0..1) of the nearest point.
function TownGeom.segDist(ax: number, az: number, bx: number, bz: number, x: number, z: number): (number, number)
	local vx, vz = bx - ax, bz - az
	local len2 = vx * vx + vz * vz
	local t = 0
	if len2 > 0 then
		t = math.clamp(((x - ax) * vx + (z - az) * vz) / len2, 0, 1)
	end
	local nx, nz = ax + vx * t, az + vz * t
	return math.sqrt((x - nx) ^ 2 + (z - nz) ^ 2), t
end

-- Distance from (x, z) to the outline of a closed polygon.
function TownGeom.edgeDist(poly: { Vec2 }, x: number, z: number): number
	local best = math.huge
	local n = #poly
	for i = 1, n do
		local a, b = poly[i], poly[i % n + 1]
		local d = TownGeom.segDist(a[1], a[2], b[1], b[2], x, z)
		if d < best then
			best = d
		end
	end
	return best
end

-- Distance from (x, z) to an open polyline.
function TownGeom.lineDist(pts: { Vec2 }, x: number, z: number): number
	local best = math.huge
	for i = 1, #pts - 1 do
		local d = TownGeom.segDist(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], x, z)
		if d < best then
			best = d
		end
	end
	return best
end

-- Corners of a w x d rectangle centred at (x, z) and rotated by rot degrees (game convention: local -Z is the
-- front, x' = x cos + z sin, z' = -x sin + z cos).
function TownGeom.rect(x: number, z: number, w: number, d: number, rot: number): { Vec2 }
	local r = math.rad(rot)
	local c, s = math.cos(r), math.sin(r)
	local out = {}
	for _, corner in { { -w / 2, -d / 2 }, { w / 2, -d / 2 }, { w / 2, d / 2 }, { -w / 2, d / 2 } } do
		local lx, lz = corner[1], corner[2]
		table.insert(out, { x + lx * c + lz * s, z - lx * s + lz * c })
	end
	return out
end

-- Front direction of something rotated by rot degrees.
function TownGeom.front(rot: number): (number, number)
	local r = math.rad(rot)
	return -math.sin(r), -math.cos(r)
end

-- Door point: 1.5 studs in front of the middle of the front wall.
function TownGeom.door(x: number, z: number, d: number, rot: number): (number, number)
	local fx, fz = TownGeom.front(rot)
	return x + fx * (d / 2 + 1.5), z + fz * (d / 2 + 1.5)
end

return TownGeom
