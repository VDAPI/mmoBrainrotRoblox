--!strict
-- Gardens, yards and green plots between the houses (S21, MIASTO.md §8): orchards, vegetable beds, vineyards,
-- formal hedge gardens by the castle, paddocks, herb beds, training yards, meadows. One Build per plot, almost
-- everything "detail" (the client builds it near the camera); the terrain material under each plot comes from
-- MIASTO.md §3. Pure.

local Blueprint = require("./Blueprint")
local Fill = require("./Fill")
local Palette = require("./Palette")
local Parts = require("./Parts")
local Structures = require("./Structures")

type BP = Blueprint.Blueprint
type Build = Structures.Build
type Ground = (x: number, z: number) -> number
type Vec2 = { number }

local o = Parts.o

local Gardens = {}

local HEDGE = { c = "#2F4A2A", m = "LeafyGrass" }
local SOIL = { c = "#4A3A2A", m = "Ground" }

type Ctx = { bp: BP, poly: { Vec2 }, gy: (x: number, z: number) -> number }

local function fenceAround(c: Ctx, kind: string, gap: boolean)
	local poly = c.poly
	local longest, best = 1, -1
	for i, a in poly do
		local b = poly[i % #poly + 1]
		local l = (b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2
		if l > best then
			best, longest = l, i
		end
	end
	for i, a in poly do
		local b = poly[i % #poly + 1]
		local ax, az, bx, bz = a[1], a[2], b[1], b[2]
		if gap and i == longest then
			-- leave a 4 stud opening in the middle of the longest side
			local mx, mz = (ax + bx) / 2, (az + bz) / 2
			local len = math.sqrt(best)
			local ux, uz = (bx - ax) / len, (bz - az) / len
			Parts.fence(c.bp, ax, c.gy(ax, az), az, mx - ux * 2, c.gy(mx - ux * 2, mz - uz * 2), mz - uz * 2, kind)
			Parts.fence(c.bp, mx + ux * 2, c.gy(mx + ux * 2, mz + uz * 2), mz + uz * 2, bx, c.gy(bx, bz), bz, kind)
		else
			Parts.fence(c.bp, ax, c.gy(ax, az), az, bx, c.gy(bx, bz), bz, kind)
		end
	end
end

-- A low bush with a few flowers of one colour.
local function bush(c: Ctx, x: number, z: number, s: number, flower: string?)
	local bp = c.bp
	local y = c.gy(x, z)
	bp:add(
		"ball",
		2.2 * s,
		1.6 * s,
		2.2 * s,
		x,
		y + 0.6 * s,
		z,
		0,
		0,
		0,
		o({ c = bp:jitter("#46662F", 0.1), m = "LeafyGrass" })
	)
	if flower then
		for _ = 1, 3 do
			bp:add(
				"ball",
				0.5,
				0.5,
				0.5,
				x + bp.rng:float(-0.8, 0.8) * s,
				y + 1.2 * s,
				z + bp.rng:float(-0.8, 0.8) * s,
				0,
				0,
				0,
				{ c = flower, m = "SmoothPlastic", lod = "fine" }
			)
		end
	end
end

local function orchard(c: Ctx)
	local pts = Fill.scatter(c.poly, c.bp.rng, 8, 3)
	for i, p in pts do
		if i > 10 then
			break
		end
		Parts.tree(c.bp, p[1], c.gy(p[1], p[2]), p[2], if i % 5 == 0 then "oak" else "apple", c.bp.rng:float(0.85, 1.1))
	end
	if c.bp.rng:chance(0.5) then
		fenceAround(c, "wattle", true)
	end
end

local function vegetables(c: Ctx)
	local bp = c.bp
	local deg = Fill.longestEdge(c.poly)
	local rows = Fill.rows(c.poly, deg, 3, 1.5)
	local greens = { "#5E8A4A", "#6F9A50", "#4E7A3E", "#7A8A3E" }
	for i, r in rows do
		if i > 12 then
			break
		end
		local ya, yb = c.gy(r[1], r[2]), c.gy(r[3], r[4])
		bp:beam(r[1], ya + 0.2, r[2], r[3], yb + 0.2, r[4], 1.6, o(SOIL), 0.5)
		bp:beam(
			r[1],
			ya + 0.7,
			r[2],
			r[3],
			yb + 0.7,
			r[4],
			1,
			{ c = greens[i % #greens + 1], m = "LeafyGrass", lod = "detail" },
			0.7
		)
	end
	-- scarecrow
	local pts = Fill.scatter(c.poly, bp.rng, 9, 3)
	if #pts > 0 and bp.rng:chance(0.6) then
		local p = pts[bp.rng:int(1, #pts)]
		local y = c.gy(p[1], p[2])
		bp:box(0.3, 5, 0.3, p[1], y + 2.5, p[2], o(Palette.timber[1]))
		bp:box(3.4, 0.3, 0.3, p[1], y + 3.6, p[2], o(Palette.timber[1]))
		bp:box(1.4, 2, 0.6, p[1], y + 3.2, p[2], { c = "#6A5A3A", m = "Fabric", lod = "detail" })
		bp:add("ball", 1, 1, 1, p[1], y + 4.8, p[2], 0, 0, 0, { c = "#C8A85A", m = "Fabric", lod = "detail" })
		bp:add("cyl", 0.2, 1.8, 1.8, p[1], y + 5.3, p[2], 0, 0, 90, { c = "#4A3A2A", m = "Fabric", lod = "detail" })
	end
	fenceAround(c, "wattle", true)
end

local function vineyard(c: Ctx)
	local bp = c.bp
	local deg = Fill.longestEdge(c.poly)
	for i, r in Fill.rows(c.poly, deg, 4, 2) do
		if i > 10 then
			break
		end
		local ya, yb = c.gy(r[1], r[2]), c.gy(r[3], r[4])
		bp:beam(
			r[1],
			ya + 1.3,
			r[2],
			r[3],
			yb + 1.3,
			r[4],
			0.9,
			{ c = bp:jitter("#4F6B35", 0.1), m = "LeafyGrass", lod = "detail" },
			2.2
		)
		local len = math.sqrt((r[3] - r[1]) ^ 2 + (r[4] - r[2]) ^ 2)
		local n = math.max(1, math.floor(len / 5))
		for k = 0, n do
			local t = k / n
			local x, z = r[1] + (r[3] - r[1]) * t, r[2] + (r[4] - r[2]) * t
			bp:box(0.25, 3, 0.25, x, c.gy(x, z) + 1.5, z, o(Palette.greyPlanks[1], "fine"))
		end
		-- dark grapes
		for _ = 1, 2 do
			local t = bp.rng:float(0.1, 0.9)
			local x, z = r[1] + (r[3] - r[1]) * t, r[2] + (r[4] - r[2]) * t
			bp:add(
				"ball",
				0.6,
				0.8,
				0.6,
				x,
				c.gy(x, z) + 1,
				z,
				0,
				0,
				0,
				{ c = "#4A2A4A", m = "SmoothPlastic", lod = "fine" }
			)
		end
	end
end

local function formal(c: Ctx)
	local bp = c.bp
	-- clipped hedges just inside the plot border
	local cx, cz = 0, 0
	for i, a in c.poly do
		local b = c.poly[i % #c.poly + 1]
		local ax, az = a[1] * 0.9, a[2] * 0.9
		local bx, bz = b[1] * 0.9, b[2] * 0.9
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		if len > 6 then
			-- gap in the middle of each side for the paths
			local mx, mz = (ax + bx) / 2, (az + bz) / 2
			local ux, uz = (bx - ax) / len, (bz - az) / len
			bp:beam(ax, c.gy(ax, az) + 1.2, az, mx - ux * 1.8, c.gy(mx, mz) + 1.2, mz - uz * 1.8, 1.4, o(HEDGE), 2.4)
			bp:beam(mx + ux * 1.8, c.gy(mx, mz) + 1.2, mz + uz * 1.8, bx, c.gy(bx, bz) + 1.2, bz, 1.4, o(HEDGE), 2.4)
		end
	end
	-- topiary on the quarters, a sundial or a statue in the middle
	for _, p in Fill.scatter(c.poly, bp.rng, 9, 4) do
		if (p[1] - cx) ^ 2 + (p[2] - cz) ^ 2 > 16 then
			local y = c.gy(p[1], p[2])
			bp:add("cyl", 1.4, 1.4, 1.4, p[1], y + 0.7, p[2], 0, 0, 90, o(Palette.ashlar[1]))
			bp:add("ball", 2, 2.4, 2, p[1], y + 2.6, p[2], 0, 0, 0, o(HEDGE))
		end
	end
	local y = c.gy(0, 0)
	if bp.rng:chance(0.5) then
		bp:add("cyl", 2.6, 1.2, 1.2, 0, y + 1.3, 0, 0, 0, 90, o(Palette.ashlar[2]))
		bp:add("cyl", 0.3, 2.2, 2.2, 0, y + 2.75, 0, 0, 0, 90, { c = "#7A6A40", m = "Metal", lod = "detail" })
		bp:add("wedge", 0.15, 0.9, 0.9, 0, y + 3.3, 0, 0, 0, 0, { c = "#5A4A30", m = "Metal", lod = "fine" })
	else
		bp:box(1.6, 1.8, 1.6, 0, y + 0.9, 0, o(Palette.ashlar[2]))
		bp:box(0.9, 1.9, 0.6, 0, y + 2.75, 0, o(Palette.ashlar[3]))
		bp:add("ball", 0.75, 0.8, 0.75, 0, y + 4.05, 0, 0, 0, 0, o(Palette.ashlar[3]))
	end
	for _, a in { 0, 180 } do
		local ra = math.rad(a)
		Parts.bench(bp, math.sin(ra) * 4.5, c.gy(math.sin(ra) * 4.5, math.cos(ra) * 4.5), math.cos(ra) * 4.5, a, 4)
	end
end

local function yard(c: Ctx)
	local bp = c.bp
	local rng = bp.rng
	local pts = Fill.scatter(c.poly, rng, 7, 2.5)
	for i, p in pts do
		if i > 5 then
			break
		end
		local x, z = p[1], p[2]
		local y = c.gy(x, z)
		local pick = rng:int(1, 6)
		if pick == 1 then
			Parts.woodpile(bp, x, y, z, rng:float(0, 180), 4)
			bp:add("cyl", 1.2, 1.4, 1.4, x + 3, y + 0.6, z, 0, 0, 90, o(Palette.timber[2]))
		elseif pick == 2 then
			Parts.cart(bp, x, y, z, rng:float(0, 360))
		elseif pick == 3 then
			Parts.barrel(bp, x, y, z)
			Parts.barrel(bp, x + 2, y, z + 0.4)
			Parts.crate(bp, x + 0.8, y, z - 2, 1.6)
		elseif pick == 4 then
			Parts.haystack(bp, x, y, z, 1.8)
		elseif pick == 5 then
			-- chicken coop on legs
			bp:push(x, y, z, 0, rng:float(0, 360), 0)
			for _, s in { -1, 1 } do
				bp:box(0.3, 1.2, 0.3, s * 1.3, 0.6, -1, o(Palette.timber[1]))
				bp:box(0.3, 1.2, 0.3, s * 1.3, 0.6, 1, o(Palette.timber[1]))
			end
			bp:box(3, 1.8, 2.4, 0, 2.1, 0, o(Palette.pick(rng, Palette.planks)))
			bp:add("wedge", 3.2, 1, 1.4, 0, 3.5, -0.7, 0, 0, 0, o(Palette.pick(rng, Palette.shingles)))
			bp:add("wedge", 3.2, 1, 1.4, 0, 3.5, 0.7, 0, 180, 0, o(Palette.pick(rng, Palette.shingles)))
			bp:beam(0, 1.2, -1.2, 0, 0, -2.6, 0.8, o(Palette.planks[2]), 0.15)
			bp:pop()
		else
			-- washing line
			bp:push(x, y, z, 0, rng:float(0, 180), 0)
			bp:box(0.3, 4.4, 0.3, -3, 2.2, 0, o(Palette.timber[1]))
			bp:box(0.3, 4.4, 0.3, 3, 2.2, 0, o(Palette.timber[1]))
			bp:box(6, 0.08, 0.08, 0, 4.2, 0, { c = "#8A7A5A", m = "Fabric", lod = "fine" })
			for k = 0, 2 do
				local cloth = ({ "#E0D6C0", "#7A3B2E", "#3E5A7A", "#C8B890" })[rng:int(1, 4)]
				bp:box(1.2, 1.6, 0.08, -1.6 + k * 1.6, 3.4, 0, { c = cloth, m = "Fabric", lod = "detail" })
			end
			bp:pop()
		end
	end
end

local function backGarden(c: Ctx)
	local bp = c.bp
	local rng = bp.rng
	local pts = Fill.scatter(c.poly, rng, 8, 2.5)
	for i, p in pts do
		if i > 6 then
			break
		end
		local x, z = p[1], p[2]
		local y = c.gy(x, z)
		if i <= 2 then
			Parts.tree(bp, x, y, z, if rng:chance(0.5) then "apple" else "birch", rng:float(0.8, 1))
		elseif i == 3 then
			local ry = rng:float(0, 180)
			bp:push(x, y, z, 0, ry, 0)
			bp:box(5, 0.8, 2.4, 0, 0.4, 0, o(Palette.planks[1]))
			bp:box(4.6, 0.3, 2, 0, 0.85, 0, o(SOIL))
			for k = 0, 3 do
				bp:add(
					"ball",
					0.9,
					0.7,
					0.9,
					-1.6 + k * 1.05,
					1.15,
					0,
					0,
					0,
					0,
					{ c = "#5E8A4A", m = "LeafyGrass", lod = "fine" }
				)
			end
			bp:pop()
		elseif i == 4 then
			Parts.bench(bp, x, y, z, rng:float(0, 360), 3.6)
		else
			bush(c, x, z, rng:float(0.8, 1.2), ({ "#C8505A", "#E0C050", "#E8E0D0", "#9A60B0" })[rng:int(1, 4)])
		end
	end
end

local function paddock(c: Ctx)
	local bp = c.bp
	fenceAround(c, "rail", true)
	local pts = Fill.scatter(c.poly, bp.rng, 9, 3)
	if #pts > 0 then
		local p = pts[1]
		local y = c.gy(p[1], p[2])
		local ry = bp.rng:float(0, 180)
		bp:push(p[1], y, p[2], 0, ry, 0)
		bp:box(5, 1.2, 1.4, 0, 0.6, 0, o(Palette.planks[1]))
		bp:box(4.4, 0.2, 0.9, 0, 1.15, 0, { c = "#3A5A6A", m = "Glass", lod = "detail" })
		bp:pop()
	end
	if #pts > 2 then
		local p = pts[#pts]
		Parts.haystack(bp, p[1], c.gy(p[1], p[2]), p[2], 2)
	end
end

local function herbs(c: Ctx)
	local bp = c.bp
	local cols = { "#8A6AB0", "#E0C050", "#E8E0D0", "#6A9A50", "#C8505A" }
	for i, p in Fill.scatter(c.poly, bp.rng, 4, 2) do
		if i > 16 then
			break
		end
		local y = c.gy(p[1], p[2])
		bp:box(2.6, 0.5, 2.6, p[1], y + 0.25, p[2], o(Palette.planks[4]))
		bp:box(2.2, 0.8, 2.2, p[1], y + 0.8, p[2], { c = bp:jitter("#4F6B35", 0.1), m = "LeafyGrass", lod = "detail" })
		bp:box(1.8, 0.3, 1.8, p[1], y + 1.3, p[2], { c = cols[i % #cols + 1], m = "SmoothPlastic", lod = "fine" })
	end
	fenceAround(c, "picket", true)
end

local function trainingYard(c: Ctx)
	local bp = c.bp
	local rng = bp.rng
	for i, p in Fill.scatter(c.poly, rng, 7, 3) do
		if i > 6 then
			break
		end
		local x, z = p[1], p[2]
		local y = c.gy(x, z)
		if i % 3 == 0 then
			-- archery target
			bp:push(x, y, z, 0, rng:float(-20, 20), 0)
			bp:beam(0, 0, 0.8, 0, 3.6, 0, 0.3, o(Palette.timber[1]))
			bp:beam(0, 0, -0.8, 0, 3.6, 0, 0.3, o(Palette.timber[1]))
			bp:add("cyl", 0.5, 3.4, 3.4, 0, 3.2, -0.3, 0, 90, 0, { c = "#C8B890", m = "Fabric", lod = "detail" })
			bp:add("cyl", 0.55, 2.2, 2.2, 0, 3.2, -0.32, 0, 90, 0, { c = "#8A2A22", m = "Fabric", lod = "detail" })
			bp:add("cyl", 0.6, 0.9, 0.9, 0, 3.2, -0.34, 0, 90, 0, { c = "#E0C050", m = "Fabric", lod = "fine" })
			bp:pop()
		else
			-- straw dummy on a post
			bp:box(0.4, 5.2, 0.4, x, y + 2.6, z, o(Palette.timber[1]))
			bp:box(3.4, 0.35, 0.35, x, y + 4, z, o(Palette.timber[1]))
			bp:add("cyl", 2.4, 1.6, 1.6, x, y + 3.6, z, 0, 0, 90, { c = "#B89A55", m = "Grass", lod = "detail" })
			bp:add("ball", 1.1, 1.1, 1.1, x, y + 5.4, z, 0, 0, 0, { c = "#9A8050", m = "Fabric", lod = "detail" })
		end
	end
	local pts = Fill.scatter(c.poly, rng, 11, 2)
	if #pts > 0 then
		local p = pts[#pts]
		local y = c.gy(p[1], p[2])
		bp:push(p[1], y, p[2], 0, rng:float(0, 360), 0)
		bp:box(4.4, 0.3, 0.3, 0, 3.2, 0, o(Palette.timber[1]))
		bp:box(4.4, 0.3, 0.3, 0, 0.8, 0.5, o(Palette.timber[1]))
		for k = 0, 3 do
			bp:rbox(0.2, 4.2, 0.2, -1.5 + k, 2.1, 0.2, 10, 0, 0, o(Palette.metal[1], "fine"))
		end
		bp:pop()
	end
	fenceAround(c, "rail", true)
end

local function meadow(c: Ctx, pasture: boolean)
	local bp = c.bp
	local rng = bp.rng
	for i, p in Fill.scatter(c.poly, rng, 5, 1.5) do
		if i > 18 then
			break
		end
		local y = c.gy(p[1], p[2])
		bp:rbox(
			1.2,
			1.4,
			1.2,
			p[1],
			y + 0.5,
			p[2],
			0,
			rng:float(0, 90),
			0,
			{ c = bp:jitter("#7A8A45", 0.12), m = "Grass", lod = "detail" }
		)
		if rng:chance(0.3) then
			bp:add("ball", 0.4, 0.4, 0.4, p[1] + 0.4, y + 1.3, p[2], 0, 0, 0, {
				c = ({ "#E8E0D0", "#E0C050", "#C8505A", "#7A8AD0" })[rng:int(1, 4)],
				m = "SmoothPlastic",
				lod = "fine",
			})
		end
	end
	local pts = Fill.scatter(c.poly, rng, 14, 4)
	if #pts > 0 then
		local p = pts[1]
		Parts.tree(bp, p[1], c.gy(p[1], p[2]), p[2], if rng:chance(0.5) then "oak" else "willow", rng:float(1, 1.25))
	end
	if pasture then
		fenceAround(c, "rail", true)
		if #pts > 1 then
			local p = pts[#pts]
			Parts.haystack(bp, p[1], c.gy(p[1], p[2]), p[2], 2.2)
		end
	end
end

function Gardens.build(g: any, ground: Ground): Build
	local cx, cz = Fill.centroid(g.poly)
	local y0 = ground(cx, cz)
	local bp = Blueprint.new(g.seed)
	local c: Ctx = {
		bp = bp,
		poly = Fill.localPoly(g.poly, cx, cz),
		gy = function(x: number, z: number): number
			return ground(cx + x, cz + z) - y0
		end,
	}
	local kind = g.kind
	if kind == "orchard" then
		orchard(c)
	elseif kind == "vegetables" then
		vegetables(c)
	elseif kind == "vineyard" then
		vineyard(c)
	elseif kind == "formal" then
		formal(c)
	elseif kind == "yard" then
		yard(c)
	elseif kind == "backGarden" then
		backGarden(c)
	elseif kind == "paddock" then
		paddock(c)
	elseif kind == "herbs" then
		herbs(c)
	elseif kind == "trainingYard" then
		trainingYard(c)
	else
		meadow(c, kind == "pasture")
	end
	if #bp.pieces == 0 then
		-- narrow leftover strips: a few shrubs so no garden is bare
		for i, p in Fill.scatter(c.poly, bp.rng, 4.5, 1.4) do
			if i > 6 then
				break
			end
			bush(c, p[1], p[2], bp.rng:float(0.7, 1), if i % 2 == 0 then "#C9A0D8" else nil)
		end
	end
	return { name = g.id, bp = bp, at = { x = cx, y = y0, z = cz, rot = 0 }, tag = "garden" }
end

function Gardens.all(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	for _, g in city.gardens do
		table.insert(out, Gardens.build(g, ground))
	end
	return out
end

return Gardens
