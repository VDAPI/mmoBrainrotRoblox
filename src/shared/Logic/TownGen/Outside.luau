--!strict
-- Scenery outside the city walls (S21, MIASTO.md §9): drawbridges over the moat, a post mill, four farmsteads,
-- crop fields, a ruined watchtower and the forest band on the hills at the map edge. Players never walk out here
-- (the gates are portals), so nothing collides: it is seen from the walls, the towers and the castle hill. Pure.

local Blueprint = require("./Blueprint")
local Fill = require("./Fill")
local Houses = require("./Houses")
local Palette = require("./Palette")
local Parts = require("./Parts")
local Props = require("./Props")
local Structures = require("./Structures")
local TownGeom = require("../TownGeom")

type BP = Blueprint.Blueprint
type Build = Structures.Build
type Ground = (x: number, z: number) -> number

local o = Parts.o

local Outside = {}

-- Scenery options: never collides, never blocks the camera.
local function s(sw: Palette.Swatch, lod: Blueprint.Lod?): Blueprint.Options
	return o(sw, lod or "shell", { col = false, q = false })
end

-- World position of a point given in a rotated local frame (same convention as Build placement).
local function toWorld(x: number, z: number, rot: number, lx: number, lz: number): (number, number)
	local r = math.rad(rot)
	local c, sn = math.cos(r), math.sin(r)
	return x + c * lx + sn * lz, z - sn * lx + c * lz
end

-- Lowered drawbridge over the moat in front of each gate, with chains up to the gatehouse.
local function drawbridge(road: any, ground: Ground): Build
	local b = road.bridge
	local bp = Blueprint.new(math.floor(b.x * 3 + b.z * 7) % 9973 + 5)
	local ax, az = toWorld(b.x, b.z, b.rot, 0, -b.len / 2)
	local bx, bz = toWorld(b.x, b.z, b.rot, 0, b.len / 2)
	local y0 = math.max(ground(ax, az), ground(bx, bz), 0) + 0.4
	local deck = Palette.planks[4]
	bp:box(b.w, 0.8, b.len, 0, 0, 0, s(deck))
	for _, side in { -1, 1 } do
		bp:box(0.8, 1, b.len, side * (b.w / 2 - 0.4), 0.7, 0, s(Palette.timber[1], "detail"))
		-- chains from the outer end up to the gatehouse face (7 studs toward the gate)
		bp:beam(
			side * (b.w / 2 - 0.6),
			1,
			-b.len / 2 + 1,
			side * (b.w / 2 - 1.2),
			13,
			7,
			0.25,
			s(Palette.metal[1], "detail")
		)
	end
	for i = 0, math.floor(b.len / 3) do
		bp:box(b.w, 0.15, 0.35, 0, 0.45, -b.len / 2 + i * 3, s(Palette.timber[2], "fine"))
	end
	return {
		name = "Drawbridge_" .. road.gate,
		bp = bp,
		at = { x = b.x, y = y0, z = b.z, rot = b.rot },
		tag = "outside",
	}
end

-- Post mill (kozlak): a timber body on a trestle, four lattice sails, a tail pole with a ladder.
-- Tag "sail": the client turns every piece with this tag around the cylinder axis of the "sailAxle" piece
-- (its local X, CFrame.RightVector; the axle is rotated 0, 90, 0, so that is the body's Z).
local function windmill(w: any, ground: Ground): Build
	local bp = Blueprint.new(3003)
	local y0 = ground(w.x, w.z)
	local stone = Palette.rubble[1]
	local planks = Palette.greyPlanks[2]
	for _, c in { { -3, -3 }, { 3, -3 }, { 3, 3 }, { -3, 3 } } do
		local gy = ground(toWorld(w.x, w.z, w.rot, c[1], c[2])) - y0
		bp:box(1.8, 1.6 + math.max(0, -gy) + 2, 1.8, c[1], gy + 0.8 - 1, c[2], s(stone))
		bp:beam(c[1], gy + 1.6, c[2], 0, 5.5, 0, 0.6, s(Palette.timber[1]))
	end
	bp:add("cyl", 8, 1.6, 1.6, 0, 4, 0, 0, 0, 90, s(Palette.timber[1]))
	-- body
	bp:box(8, 9, 10, 0, 10.5, 0, s(planks))
	for i = 0, 6 do
		bp:box(0.25, 9, 0.2, -3.6 + i * 1.2, 10.5, -5.05, s(Palette.greyPlanks[1], "detail"))
	end
	for _, c in { { -4, -5 }, { 4, -5 }, { 4, 5 }, { -4, 5 } } do
		bp:box(0.5, 9.2, 0.5, c[1], 10.5, c[2], s(Palette.timber[1], "detail"))
	end
	local look: Parts.Look = {
		timber = Palette.timber[1],
		plaster = planks,
		planks = planks,
		shutter = Palette.shutter[1],
		door = Palette.door[1],
		stone = stone,
		roof = Palette.shingles[2],
	}
	Parts.roof(bp, look, {
		w = 8,
		d = 10,
		zc = 0,
		y = 15,
		pitch = 48,
		ridgeAlongZ = true,
		eave = 0.6,
		verge = 0.6,
		thick = 0.5,
		roof = Palette.shingles[2],
		gable = planks,
		timber = nil,
	})
	bp:box(1.2, 1.4, 0.2, 2.2, 13, -5.1, s(Palette.glass, "detail"))
	-- sails
	local hub = { x = 0, y = 14.5, z = -6.4 }
	bp:add(
		"cyl",
		3,
		1,
		1,
		hub.x,
		hub.y,
		hub.z + 0.9,
		0,
		90,
		0,
		{ c = "#3A2C22", m = "Wood", lod = "shell", col = false, q = false, tag = "sailAxle" }
	)
	for i = 0, 3 do
		bp:push(hub.x, hub.y, hub.z, 0, 0, 45 + i * 90)
		bp:box(
			0.55,
			14,
			0.45,
			0,
			7,
			0,
			{ c = "#4E3B2A", m = "Wood", lod = "shell", col = false, q = false, tag = "sail" }
		)
		bp:box(
			2.8,
			10.5,
			0.12,
			1.7,
			8.2,
			-0.15,
			{ c = "#D8CCB0", m = "Fabric", lod = "shell", col = false, q = false, tag = "sail" }
		)
		for k = 0, 3 do
			bp:box(
				3.2,
				0.18,
				0.18,
				1.6,
				3.4 + k * 3.2,
				-0.3,
				{ c = "#4E3B2A", m = "Wood", lod = "fine", col = false, q = false, tag = "sail" }
			)
		end
		bp:pop()
	end
	-- tail pole and ladder at the back
	local tailGy = ground(toWorld(w.x, w.z, w.rot, 0, 15)) - y0
	bp:beam(0, 7, 5, 0, tailGy + 0.6, 15, 0.7, s(Palette.timber[1]))
	for _, side in { -1, 1 } do
		bp:beam(side * 1.1, 6, 5.2, side * 1.1, tailGy + 0.2, 12, 0.3, s(Palette.timber[2], "detail"))
	end
	for k = 1, 6 do
		local t = k / 7
		bp:box(2.2, 0.2, 0.4, 0, 6 + (tailGy + 0.2 - 6) * t, 5.2 + 6.8 * t, s(Palette.timber[2], "fine"))
	end
	return { name = "Windmill", bp = bp, at = { x = w.x, y = y0, z = w.z, rot = w.rot }, tag = "outside" }
end

-- Thatched plank barn, its big doors facing local -Z.
local function barn(x: number, z: number, rot: number, seed: number, ground: Ground): Build
	local bp = Blueprint.new(seed)
	local W, D = 18, 12
	local lo, hi = Houses.groundRange(x, z, W, D, rot, ground)
	local y0 = hi + 0.2
	local planks = Palette.pick(bp.rng, Palette.planks)
	local timber = Palette.timber[1]
	bp:box(W + 0.4, y0 - lo + 1, D + 0.4, 0, -(y0 - lo + 1) / 2, 0, s(Palette.rubble[1]))
	bp:box(W, 8, D, 0, 4, 0, s(planks))
	for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		bp:box(0.7, 8, 0.7, c[1] * W / 2, 4, c[2] * D / 2, s(timber, "detail"))
	end
	bp:box(W + 0.2, 0.5, 0.5, 0, 8, -D / 2, s(timber, "detail"))
	-- doors, one leaf a little open
	bp:box(6.6, 7, 0.4, 0, 3.5, -D / 2 - 0.1, s({ c = "#1E1A16", m = "WoodPlanks" }))
	bp:box(3.2, 6.6, 0.3, -1.65, 3.3, -D / 2 - 0.3, s(Palette.door[1], "detail"))
	bp:rbox(3.2, 6.6, 0.3, 2.9, 3.3, -D / 2 - 1.1, 0, -35, 0, s(Palette.door[1], "detail"))
	local look: Parts.Look = {
		timber = timber,
		plaster = planks,
		planks = planks,
		shutter = Palette.shutter[1],
		door = Palette.door[1],
		stone = Palette.rubble[1],
		roof = Palette.thatch[1],
	}
	Parts.roof(bp, look, {
		w = W,
		d = D,
		zc = 0,
		y = 8,
		pitch = 50,
		ridgeAlongZ = false,
		eave = 1.6,
		verge = 1,
		thick = 1.4,
		roof = Palette.pick(bp.rng, Palette.thatch),
		gable = planks,
		timber = timber,
	})
	return { name = "Barn", bp = bp, at = { x = x, y = y0, z = z, rot = rot }, tag = "outside" }
end

-- Farmstead: cottage, barn, a fenced yard with haystacks, a cart, a well and a woodpile.
local function farm(f: any, i: number, ground: Ground, out: { Build })
	local hx, hz = toWorld(f.x, f.z, f.rot, -10, 0)
	local hbp, hat = Houses.build({
		id = "farm" .. i,
		kind = "cottage",
		style = "cottage",
		x = hx,
		z = hz,
		w = 14,
		d = 10,
		rot = f.rot,
		floors = if i % 2 == 0 then 2 else 1,
		seed = 5100 + i,
	}, ground)
	table.insert(out, { name = "Farmhouse" .. i, bp = hbp, at = hat, tag = "outside" })
	local bx, bz = toWorld(f.x, f.z, f.rot, 12, 0)
	table.insert(out, barn(bx, bz, f.rot + 90, 5200 + i, ground))
	-- yard
	local bp = Blueprint.new(5300 + i)
	local y0 = ground(f.x, f.z)
	local function gy(lx: number, lz: number): number
		return ground(toWorld(f.x, f.z, f.rot, lx, lz)) - y0
	end
	local corners = { { -18, -12 }, { 19, -12 }, { 19, 11 }, { -18, 11 } }
	for k, a in corners do
		local b = corners[k % 4 + 1]
		if k == 1 then
			Parts.fence(bp, a[1], gy(a[1], a[2]), a[2], -2.5, gy(-2.5, -12), -12, "rail")
			Parts.fence(bp, 2.5, gy(2.5, -12), -12, b[1], gy(b[1], b[2]), b[2], "rail")
		else
			Parts.fence(bp, a[1], gy(a[1], a[2]), a[2], b[1], gy(b[1], b[2]), b[2], "rail")
		end
	end
	Parts.haystack(bp, 15, gy(15, -8), -8, 2.2, "shell")
	Parts.haystack(bp, 15.5, gy(15.5, 7.5), 7.5, 1.8, "shell")
	Parts.cart(bp, 3, gy(3, -7), -7, bp.rng:float(0, 360))
	Props.well(bp, 0, gy(0, 6), 6, 20)
	Parts.woodpile(bp, -10, gy(-10, 6.5), 6.5, 0, 5)
	for _, p in { { -14, -9 }, { 8, 9 } } do
		Parts.tree(bp, p[1], gy(p[1], p[2]), p[2], if i % 2 == 0 then "apple" else "oak", 1.1, "shell")
	end
	table.insert(
		out,
		{ name = "Farmyard" .. i, bp = bp, at = { x = f.x, y = y0, z = f.z, rot = f.rot }, tag = "outside" }
	)
end

-- Ruined round watchtower: a broken ring of wall, tall on one side, fallen blocks and ivy.
local function ruin(r: any, ground: Ground): Build
	local bp = Blueprint.new(4404)
	local rng = bp.rng
	local y0 = ground(r.x, r.z)
	local stone = { c = "#6E6A63", m = "Cobblestone" }
	local n, R = 14, 6
	local side = 2 * (R + 0.8) * math.tan(math.pi / n) + 0.1
	for i = 0, n - 1 do
		local a = i * 360 / n
		local ra = math.rad(a)
		local h = 2 + 11 * (0.5 + 0.5 * math.cos(ra - 0.6)) * rng:float(0.6, 1)
		local x, z = math.sin(ra) * R, math.cos(ra) * R
		local gy = ground(r.x + x, r.z + z) - y0
		bp:rbox(side, h + 1, 1.6, x, gy + h / 2 - 0.5, z, 0, a, 0, s(stone))
		if h > 9 and rng:chance(0.6) then
			bp:rbox(side * 0.8, h * 0.6, 0.2, x * 1.15, gy + h * 0.45, z * 1.15, 0, a, 0, s(Palette.moss[1], "detail"))
		end
	end
	bp:box(10, 3.5, 1.4, R + 5, ground(r.x + R + 5, r.z) - y0 + 1.2, 0, s(stone))
	for _ = 1, 10 do
		local a = rng:float(0, math.pi * 2)
		local d = rng:float(R + 1.5, R + 9)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local sz = rng:float(1, 2.4)
		bp:rbox(
			sz * 1.4,
			sz,
			sz,
			x,
			ground(r.x + x, r.z + z) - y0 + sz * 0.3,
			z,
			rng:float(-25, 25),
			rng:float(0, 90),
			rng:float(-25, 25),
			s(stone, "detail")
		)
	end
	return { name = "Ruin", bp = bp, at = { x = r.x, y = y0, z = r.z, rot = 0 }, tag = "outside" }
end

type Crop = { gap: number, w: number, h: number, c: string, m: string }
local CROPS: { [string]: Crop } = {
	wheat = { gap = 3, w = 2.6, h = 2.2, c = "#C8A85A", m = "Grass" },
	barley = { gap = 3, w = 2.6, h = 1.8, c = "#D2C285", m = "Grass" },
	flax = { gap = 2.8, w = 2.3, h = 1.6, c = "#7088B0", m = "Grass" },
	cabbage = { gap = 3, w = 1.8, h = 0.9, c = "#5E8A4A", m = "LeafyGrass" },
	ploughed = { gap = 2.4, w = 1.3, h = 0.5, c = "#4A3A2A", m = "Ground" },
}

-- Crop rows following the field direction and the ground slope; fallow land gets tufts and flowers.
local function field(f: any, ground: Ground): Build
	local cx, cz = Fill.centroid(f.poly)
	local y0 = ground(cx, cz)
	local bp = Blueprint.new(f.seed)
	local lp = Fill.localPoly(f.poly, cx, cz)
	local function gy(x: number, z: number): number
		return ground(cx + x, cz + z) - y0
	end
	local crop = CROPS[f.crop]
	if crop then
		for _, r in Fill.rows(lp, f.rows, crop.gap, 1.2) do
			local len = math.sqrt((r[3] - r[1]) ^ 2 + (r[4] - r[2]) ^ 2)
			local n = math.max(1, math.ceil(len / 22))
			for k = 0, n - 1 do
				local t0, t1 = k / n, (k + 1) / n
				local ax, az = r[1] + (r[3] - r[1]) * t0, r[2] + (r[4] - r[2]) * t0
				local bx, bz = r[1] + (r[3] - r[1]) * t1, r[2] + (r[4] - r[2]) * t1
				bp:beam(
					ax,
					gy(ax, az) + crop.h / 2 - 0.2,
					az,
					bx,
					gy(bx, bz) + crop.h / 2 - 0.2,
					bz,
					crop.w,
					s({ c = bp:jitter(crop.c, 0.06), m = crop.m }),
					crop.h
				)
			end
		end
	else
		for i, p in Fill.scatter(lp, bp.rng, 7, 2) do
			if i > 12 then
				break
			end
			bp:rbox(
				1.4,
				1.2,
				1.4,
				p[1],
				gy(p[1], p[2]) + 0.4,
				p[2],
				0,
				bp.rng:float(0, 90),
				0,
				s({ c = bp:jitter("#8A9A50", 0.12), m = "Grass" }, "detail")
			)
		end
	end
	return { name = f.id, bp = bp, at = { x = cx, y = y0, z = cz, rot = 0 }, tag = "field" }
end

-- Forest band: trees on a jittered grid where max(|x|, |z|) passes forestStart (with a ragged edge), kept off
-- the roads, the river, the farms, the windmill and the ruin. One Build per 100x100 tile.
local function forest(city: any, ground: Ground, out: { Build })
	local o2 = city.outside
	local start = o2.forestStart
	local half = city.size / 2
	local spacing = 17
	local clear: { { number } } = { { o2.windmill.x, o2.windmill.z, 30 }, { o2.ruin.x, o2.ruin.z, 22 } }
	for _, f in o2.farms do
		table.insert(clear, { f.x, f.z, 32 })
	end
	local river = city.terrain.river
	local tiles: { [string]: any } = {}
	local rng = Blueprint.new(8080).rng
	local x = -half + spacing / 2
	while x < half do
		local z = -half + spacing / 2
		while z < half do
			local px = x + rng:float(-0.35, 0.35) * spacing
			local pz = z + rng:float(-0.35, 0.35) * spacing
			local edge = math.max(math.abs(px), math.abs(pz))
			local ok = edge >= start + rng:float(-14, 14) and edge < half - 2
			if ok then
				for _, c in clear do
					if (px - c[1]) ^ 2 + (pz - c[2]) ^ 2 < c[3] * c[3] then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, road in o2.roads do
					if TownGeom.lineDist(road.pts, px, pz) < road.w / 2 + 8 then
						ok = false
						break
					end
				end
			end
			if ok and TownGeom.lineDist(river.pts, px, pz) < river.width / 2 + river.bank + 3 then
				ok = false
			end
			if ok then
				local tx, tz = math.floor((px + half) / 100), math.floor((pz + half) / 100)
				local key = tx .. "_" .. tz
				local tile = tiles[key]
				if not tile then
					local ox, oz = -half + tx * 100 + 50, -half + tz * 100 + 50
					tile = {
						name = "Forest_" .. key,
						bp = Blueprint.new(tx * 31 + tz * 7 + 1),
						at = { x = ox, y = 0, z = oz, rot = 0 },
						tag = "forest",
					}
					tiles[key] = tile
					table.insert(out, tile)
				end
				local t = tile
				local bp = t.bp
				local lx, lz = px - t.at.x, pz - t.at.z
				local y = ground(px, pz)
				local sc = rng:float(0.85, 1.35)
				local r = rng:next()
				if r < 0.55 then
					local h = 4 * sc
					bp:add(
						"cyl",
						h + 1,
						1.1 * sc,
						1.1 * sc,
						lx,
						y + h / 2 - 0.5,
						lz,
						0,
						0,
						90,
						s({ c = "#4A3A2C", m = "Wood" })
					)
					local leaf = { c = bp:jitter("#2C4628", 0.08), m = "LeafyGrass" }
					bp:add("ball", 7 * sc, 9 * sc, 7 * sc, lx, y + h + 3 * sc, lz, 0, 0, 0, s(leaf))
					bp:add("ball", 4.2 * sc, 6 * sc, 4.2 * sc, lx, y + h + 8 * sc, lz, 0, 0, 0, s(leaf))
				else
					local birch = r > 0.85
					local h = 5 * sc
					bp:add(
						"cyl",
						h + 1,
						1.2 * sc,
						1.2 * sc,
						lx,
						y + h / 2 - 0.5,
						lz,
						0,
						0,
						90,
						s({ c = if birch then "#CFC8B8" else "#4A3A2C", m = "Wood" })
					)
					local leaf = { c = bp:jitter(if birch then "#7E9A45" else "#3F5F2C", 0.08), m = "LeafyGrass" }
					bp:add("ball", 9 * sc, 7.5 * sc, 9 * sc, lx, y + h + 2.5 * sc, lz, 0, 0, 0, s(leaf))
				end
			end
			z += spacing
		end
		x += spacing
	end
end

function Outside.all(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	local o2 = city.outside
	for _, road in o2.roads do
		table.insert(out, drawbridge(road, ground))
	end
	table.insert(out, windmill(o2.windmill, ground))
	for i, f in o2.farms do
		farm(f, i, ground, out)
	end
	table.insert(out, ruin(o2.ruin, ground))
	for _, f in o2.fields do
		table.insert(out, field(f, ground))
	end
	forest(city, ground, out)
	return out
end

return Outside
