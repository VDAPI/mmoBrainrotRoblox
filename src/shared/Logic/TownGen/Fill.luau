--!strict
-- Polygon helpers for filling gardens, fields and the forest (S21): centroid, rows clipped to a polygon, jittered
-- points inside it. Pure.

local Rng = require("../Rng")
local TownGeom = require("../TownGeom")

type Vec2 = { number }

local Fill = {}

-- Mean of the vertices (good enough for the convex-ish garden and field polygons).
function Fill.centroid(poly: { Vec2 }): (number, number)
	local x, z = 0, 0
	for _, v in poly do
		x += v[1]
		z += v[2]
	end
	return x / #poly, z / #poly
end

function Fill.area(poly: { Vec2 }): number
	local a = 0
	for i, v in poly do
		local w = poly[i % #poly + 1]
		a += v[1] * w[2] - w[1] * v[2]
	end
	return math.abs(a) / 2
end

-- Direction (degrees, 0 = along +X) of the longest edge, so rows run along the plot.
function Fill.longestEdge(poly: { Vec2 }): number
	local best, deg = -1, 0
	for i, v in poly do
		local w = poly[i % #poly + 1]
		local dx, dz = w[1] - v[1], w[2] - v[2]
		local len = dx * dx + dz * dz
		if len > best then
			best = len
			deg = math.deg(math.atan2(dz, dx))
		end
	end
	return deg
end

-- Parallel rows at `deg` degrees (0 = rows along +X), `gap` apart, clipped to the polygon and pulled in by
-- `margin` at both ends. Returns segments { ax, az, bx, bz }.
function Fill.rows(poly: { Vec2 }, deg: number, gap: number, margin: number): { { number } }
	local a = math.rad(deg)
	local c, s = math.cos(a), math.sin(a)
	local us, vs = {}, {}
	local vmin, vmax = math.huge, -math.huge
	for i, p in poly do
		us[i] = p[1] * c + p[2] * s
		vs[i] = -p[1] * s + p[2] * c
		vmin = math.min(vmin, vs[i])
		vmax = math.max(vmax, vs[i])
	end
	local out = {}
	local v = vmin + margin + gap / 2
	while v <= vmax - margin do
		local xs = {}
		for i = 1, #poly do
			local j = i % #poly + 1
			local v1, v2 = vs[i], vs[j]
			if (v1 <= v and v < v2) or (v2 <= v and v < v1) then
				local t = (v - v1) / (v2 - v1)
				table.insert(xs, us[i] + t * (us[j] - us[i]))
			end
		end
		table.sort(xs)
		for k = 1, #xs - 1, 2 do
			local u0, u1 = xs[k] + margin, xs[k + 1] - margin
			if u1 - u0 > 1 then
				table.insert(out, { u0 * c - v * s, u0 * s + v * c, u1 * c - v * s, u1 * s + v * c })
			end
		end
		v += gap
	end
	return out
end

-- Points on a jittered grid inside the polygon, at least `margin` from its edges.
function Fill.scatter(poly: { Vec2 }, rng: Rng.Rng, spacing: number, margin: number): { Vec2 }
	local x1, z1, x2, z2 = math.huge, math.huge, -math.huge, -math.huge
	for _, p in poly do
		x1, z1 = math.min(x1, p[1]), math.min(z1, p[2])
		x2, z2 = math.max(x2, p[1]), math.max(z2, p[2])
	end
	local out = {}
	local x = x1 + spacing / 2
	while x < x2 do
		local z = z1 + spacing / 2
		while z < z2 do
			local px = x + rng:float(-0.3, 0.3) * spacing
			local pz = z + rng:float(-0.3, 0.3) * spacing
			if TownGeom.inPoly(poly, px, pz) and TownGeom.edgeDist(poly, px, pz) >= margin then
				table.insert(out, { px, pz })
			end
			z += spacing
		end
		x += spacing
	end
	return out
end

-- The polygon moved so that (cx, cz) is the origin (Blueprint local space of a rot-0 build).
function Fill.localPoly(poly: { Vec2 }, cx: number, cz: number): { Vec2 }
	local out = {}
	for i, p in poly do
		out[i] = { p[1] - cx, p[2] - cz }
	end
	return out
end

return Fill
