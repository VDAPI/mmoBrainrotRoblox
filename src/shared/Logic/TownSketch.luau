--!strict
-- Map sketch of the starting city (S21) for the minimap and the world map, in the shape format of
-- World/Build.luau (rect/circle/line; `c` is the style kind looked up in UI/MapSketch COLORS). Pure, so the
-- server publishes it and tests can count it. Polygons (squares, gardens, fields) become horizontal strips,
-- because the UI draws rectangles only.
--
-- Kinds used: plaza, path, water, wall, building, arena, forest (existing) and field, garden, cemetery (new:
-- MapSketch needs COLORS entries for them).

local Town = require("../Data/Town")

local TownSketch = {}

export type Shape = { [string]: any }

-- Horizontal strips (rects) covering a polygon: one rect per x-interval of every scan row `step` studs tall.
function TownSketch.strips(poly: { { number } }, step: number, kind: string, out: { Shape })
	local z1, z2 = math.huge, -math.huge
	for _, p in poly do
		z1, z2 = math.min(z1, p[2]), math.max(z2, p[2])
	end
	local z = z1
	while z < z2 - 0.01 do
		local h = math.min(step, z2 - z)
		local mid = z + h / 2
		local xs = {}
		for i, a in poly do
			local b = poly[i % #poly + 1]
			if (a[2] <= mid and b[2] > mid) or (b[2] <= mid and a[2] > mid) then
				table.insert(xs, a[1] + (mid - a[2]) / (b[2] - a[2]) * (b[1] - a[1]))
			end
		end
		table.sort(xs)
		for i = 1, #xs - 1, 2 do
			local w = xs[i + 1] - xs[i]
			if w > 0.5 then
				table.insert(out, { t = "rect", x = (xs[i] + xs[i + 1]) / 2, z = mid, w = w, h = h, c = kind })
			end
		end
		z += step
	end
end

local function flat(pts: { { number } }, closed: boolean?): { number }
	local out = {}
	for _, p in pts do
		table.insert(out, p[1])
		table.insert(out, p[2])
	end
	if closed and #pts > 0 then
		table.insert(out, pts[1][1])
		table.insert(out, pts[1][2])
	end
	return out
end

-- Outline of a closed polygon pushed outward by `d` studs (mitred corners), for the moat.
local function offset(poly: { { number } }, d: number): { { number } }
	local n = #poly
	local area = 0
	for i, a in poly do
		local b = poly[i % n + 1]
		area += a[1] * b[2] - b[1] * a[2]
	end
	local sign = if area > 0 then 1 else -1
	local out = {}
	for i = 1, n do
		local prev, cur, nxt = poly[(i - 2) % n + 1], poly[i], poly[i % n + 1]
		local function normal(a: { number }, b: { number }): (number, number)
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len = math.sqrt(dx * dx + dz * dz)
			return sign * dz / len, -sign * dx / len
		end
		local n1x, n1z = normal(prev, cur)
		local n2x, n2z = normal(cur, nxt)
		local mx, mz = n1x + n2x, n1z + n2z
		local ml = math.sqrt(mx * mx + mz * mz)
		local cosHalf = math.max(0.3, ml / 2)
		table.insert(out, { cur[1] + mx / ml * d / cosHalf, cur[2] + mz / ml * d / cosHalf })
	end
	return out
end

TownSketch.offset = offset

-- Every shape of the city, bottom layer first.
function TownSketch.shapes(): { Shape }
	local city = Town.city
	local out: { Shape } = {}
	-- outside: fields, forest band
	for _, f in city.outside.fields do
		TownSketch.strips(f.poly, 14, "field", out)
	end
	local fs = city.outside.forestStart
	local half = city.size / 2
	for x = -half + 20, half - 20, 40 do
		for z = -half + 20, half - 20, 40 do
			if math.max(math.abs(x), math.abs(z)) >= fs + 20 then
				table.insert(out, { t = "circle", x = x, z = z, r = 28, c = "forest" })
			end
		end
	end
	for _, road in city.outside.roads do
		table.insert(out, { t = "line", p = flat(road.pts), w = road.w, c = "path" })
	end
	-- water: moat ring and river
	local moat = city.terrain.moat
	table.insert(out, { t = "line", p = flat(offset(city.wall, moat.center), true), w = moat.half * 1.4, c = "water" })
	local river = city.terrain.river
	table.insert(out, { t = "line", p = flat(river.pts), w = river.width, c = "water" })
	-- inside: gardens, cemetery, squares, arena, streets, ramps, bridges
	for _, g in city.gardens do
		TownSketch.strips(g.poly, 14, "garden", out)
	end
	TownSketch.strips(city.cemetery, 8, "cemetery", out)
	for _, q in city.squares do
		TownSketch.strips(q.poly, 8, "plaza", out)
	end
	local arena = city.arena
	table.insert(out, { t = "rect", x = arena.x, z = arena.z, w = arena.half * 2, h = arena.half * 2, c = "arena" })
	for _, street in city.streets do
		table.insert(out, { t = "line", p = flat(street.pts), w = street.w, c = "path" })
	end
	for _, ramp in city.terrain.ramps do
		table.insert(out, { t = "line", p = flat(ramp.pts), w = ramp.w, c = "path" })
	end
	for _, b in city.bridges do
		table.insert(out, { t = "rect", x = b.x, z = b.z, w = b.w, h = b.len, r = b.rot, c = "path" })
	end
	-- buildings and walls on top
	for _, lot in city.lots do
		table.insert(out, { t = "rect", x = lot.x, z = lot.z, w = lot.w, h = lot.d, r = lot.rot, c = "building" })
	end
	for _, sp in city.specials do
		if sp.kind ~= "arena" then
			table.insert(out, { t = "rect", x = sp.x, z = sp.z, w = sp.w, h = sp.d, r = sp.rot, c = "building" })
		end
	end
	for _, stall in city.stalls do
		table.insert(out, { t = "rect", x = stall.x, z = stall.z, w = 10, h = 5, r = stall.rot, c = "building" })
	end
	for _, r in city.retaining do
		if r.kind ~= "rampSide" then
			table.insert(out, { t = "line", p = { r.a[1], r.a[2], r.b[1], r.b[2] }, w = 2, c = "wall" })
		end
	end
	table.insert(out, { t = "line", p = flat(city.wall, true), w = 6, c = "wall" })
	return out
end

return TownSketch
