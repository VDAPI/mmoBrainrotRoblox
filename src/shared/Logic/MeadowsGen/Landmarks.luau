--!strict
-- Landmarks and monster traces of the Whispering Meadows (S26): the burnt post mill on Crow Field with withered
-- fields and scarecrows, the forest ruins, the stone circle on the Wolf Hills, wolf dens with bones and wool, the
-- boar wallow, the wrecked merchant wagon, milestones along the merchant road and bear dens on the plateau. Pure.

local Areas = require("../../Data/Areas/meadows")
local AreaTypes = require("../../Data/Areas/Types")
local Kit = require("./Kit")
local MeadowsTerrain = require("../MeadowsTerrain")
local Nature = require("./Nature")
local Outside = require("../TownGen/Outside")
local Palette = require("../TownGen/Palette")
local Parts = require("../TownGen/Parts")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o
local sites = assert(Areas.sites, "meadows sites")

local Landmarks = {}

type Build = Kit.Build

local function ground(x: number, z: number): number
	return MeadowsTerrain.height(x, z)
end

-- Burnt post mill: stone piers, a charred trestle, the body with burnt-through walls and a caved-in roof, one sail
-- still on the hub, one fallen; smouldering beams (smoke).
local function mill(out: { Build })
	local s = sites.mill
	local b = Kit.build("BurntMill", "mill", s.x, s.z, s.rot)
	local bp = b.bp
	-- W13: the piers, the trestle, the body, the roof and both sails are one asset kit slot (Data/Kit "landmark:mill":
	-- the painted burnt mill); the charred beams, the ash and the smoke around stay
	bp:beginKit("landmark:mill", 0, Kit.gy(b, 0, 0), 0, 1, "shell")
	for _, c in { { -3, -3 }, { 3, -3 }, { 3, 3 }, { -3, 3 } } do
		local gy = Kit.gy(b, c[1], c[2])
		bp:box(1.8, 2.4 - gy, 1.8, c[1], gy + (2.4 - gy) / 2 - 0.6, c[2], o(Palette.rubble[1], "shell", { q = true }))
		bp:beam(c[1], 1.6, c[2], 0, 5.5, 0, 0.6, o(Kit.charred, "detail"))
	end
	bp:add("cyl", 8, 1.6, 1.6, 0, 4, 0, 0, 0, 90, o(Kit.charred, "shell", { q = true }))
	-- body: floor and three walls, each with holes; the fourth wall gone
	bp:box(8, 0.6, 10, 0, 6.3, 0, o(Kit.charred, "shell", { q = true }))
	bp:box(0.5, 7, 10, -3.8, 9.8, 0, o(Kit.charred, "shell", { q = true }))
	bp:box(8, 5, 0.5, 0, 8.8, 4.8, o(Kit.charred, "shell", { q = true }))
	bp:box(4, 7, 0.5, -2, 9.8, -4.8, o(Kit.charred, "detail"))
	for i = 0, 5 do
		local y = 7.2 + i * 1.1
		if i ~= 2 then
			bp:box(0.4, 0.9, 10 - i * 0.6, 3.9, y, 0.3 * i, o(Palette.greyPlanks[3], "detail", { jitter = 0.15 }))
		end
	end
	-- corner posts, one leaning
	for _, c in { { -4, -5 }, { 4, -5 }, { -4, 5 } } do
		bp:box(0.5, 9.2, 0.5, c[1], 10.8, c[2], o(Kit.charred, "detail"))
	end
	bp:rbox(0.5, 9, 0.5, 4.6, 10.2, 5.2, 0, 0, -14, o(Kit.charred, "detail"))
	-- caved-in roof: one plate on, one slipped down
	bp:rbox(9, 0.5, 6.5, 0, 14.6, -2.2, 42, 0, 6, o(Palette.shingles[2], "shell"))
	bp:rbox(8, 0.5, 6, 2.2, 10, 2.8, -28, 8, 30, o(Kit.charred, "detail"))
	-- hub with one broken sail, the other on the ground
	local hz = -6.4
	bp:add("cyl", 3, 1, 1, 0, 14.5, hz + 1, 0, 90, 0, o(Kit.charred, "detail"))
	bp:rbox(0.6, 13, 0.5, 0, 14.5 + 5.6, hz - 0.2, 0, 0, 24, o(Kit.charred, "shell"))
	bp:rbox(2.4, 7, 0.2, -1.7, 14.5 + 8, hz - 0.3, 0, 0, 24, o({ c = "#3A3430", m = "Fabric" }, "detail", { t = 0.2 }))
	local fx, fz = 9, -9
	bp:rbox(0.6, 13, 0.5, fx, Kit.gy(b, fx, fz) + 0.4, fz, 88, 30, 0, o(Kit.charred, "detail"))
	bp:rbox(
		2.4,
		6,
		0.2,
		fx + 1.4,
		Kit.gy(b, fx, fz) + 0.7,
		fz + 1,
		88,
		30,
		0,
		o({ c = "#3A3430", m = "Fabric" }, "detail")
	)
	bp:endKit()
	-- charred beams and ash around, smoke from three places
	for i = 1, 8 do
		local a = i * 0.78 + 0.3
		local d = 7 + (i % 3) * 2.5
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		bp:rbox(
			0.6,
			0.6,
			4 + (i % 2) * 2,
			lx,
			Kit.gy(b, lx, lz) + 0.3,
			lz,
			0,
			i * 37,
			(i % 2) * 8,
			o(Kit.charred, "detail", { col = false })
		)
	end
	for i, p in { { -6, 4 }, { 6, -2 }, { 0, 8 } } do
		local gy = Kit.gy(b, p[1], p[2])
		bp:add("ball", 3.2, 0.9, 3.2, p[1], gy + 0.1, p[2], 0, 0, 0, o(Kit.ash, "detail", { col = false }))
		bp:box(
			0.6,
			0.3,
			0.6,
			p[1],
			gy + 0.5,
			p[2],
			o({ c = "#3A2A20", m = "Slate" }, "detail", { col = false, tag = if i <= 3 then "smoke" else nil })
		)
	end
	bp:box(0.8, 0.4, 0.8, 0, 6.8, 2, o(Kit.charred, "detail", { tag = "smoke" }))
	table.insert(out, b)
	Kit.rect("building", s.x, s.z, 9, 11, s.rot)
	local wx, wy, wz = Kit.worldOf(b, 0, 21, hz)
	Kit.life("perch", wx, wy, wz)
	-- W13: the plume from the smouldering body, seen over the saddle (laki.md 1.2)
	local px, py, pz = Kit.worldOf(b, 0, 12, 1)
	Kit.life("smokePlume", px, py, pz, 2)
end

-- Withered wheat fields around the mill (rows of dry stalks, client detail) and scarecrows with crows.
local function fields(out: { Build })
	local s = sites.mill
	local plots = {
		{ x = s.x - 70, z = s.z + 40, w = 70, d = 50, rot = 12 },
		{ x = s.x + 80, z = s.z - 30, w = 60, d = 70, rot = -8 },
		{ x = s.x + 10, z = s.z + 95, w = 80, d = 40, rot = 4 },
		{ x = s.x - 40, z = s.z - 90, w = 60, d = 45, rot = 20 },
	}
	for i, f in plots do
		Kit.rect("field", f.x, f.z, f.w, f.d, f.rot)
		local b = Kit.build(`WitheredField_{i}`, "field", f.x, f.z, f.rot)
		local bp = b.bp
		for row = 0, math.floor(f.w / 3.2) do
			local lx = -f.w / 2 + row * 3.2
			local n = math.ceil(f.d / 14)
			for k = 0, n - 1 do
				local z1 = -f.d / 2 + k * f.d / n
				local z2 = z1 + f.d / n - 1.5
				local wx, wz = Kit.toWorld(f.x, f.z, f.rot, lx, (z1 + z2) / 2)
				if
					MeadowsTerrain.roadDistance(wx, wz) > 2
					and MeadowsTerrain.streamDistance(wx, wz) > 2
					and bp.rng:chance(0.82)
				then
					local h = bp.rng:float(1.2, 2.2)
					bp:beam(
						lx,
						Kit.gy(b, lx, z1) + h / 2 - 0.1,
						z1,
						lx,
						Kit.gy(b, lx, z2) + h / 2 - 0.1,
						z2,
						2.2,
						o({ c = bp:jitter("#A08A52", 0.1), m = "Grass" }, "detail", { col = false }),
						h
					)
				end
			end
		end
		-- a scarecrow in every field
		local sx, sz = bp.rng:float(-f.w / 4, f.w / 4), bp.rng:float(-f.d / 4, f.d / 4)
		local gy = Kit.gy(b, sx, sz)
		bp:box(0.45, 7, 0.45, sx, gy + 3.2, sz, o(Kit.timber, "shell", { q = false }))
		bp:box(5, 0.4, 0.4, sx, gy + 5, sz, o(Kit.timber, "shell", { q = false }))
		bp:box(2.2, 3, 1, sx, gy + 4.4, sz, o({ c = "#5A4A3A", m = "Fabric" }, "detail"))
		bp:box(4.4, 0.8, 0.9, sx, gy + 5, sz, o({ c = "#4A3E30", m = "Fabric" }, "detail"))
		bp:add("ball", 1.6, 1.8, 1.6, sx, gy + 6.9, sz, 0, 0, 0, o({ c = "#B8A070", m = "Fabric" }, "detail"))
		bp:add("cyl", 0.3, 2.8, 2.8, sx, gy + 7.7, sz, 0, 0, 90, o({ c = "#3A3026", m = "Fabric" }, "fine"))
		bp:add("cyl", 1, 1.6, 1.6, sx, gy + 8.2, sz, 0, 0, 90, o({ c = "#3A3026", m = "Fabric" }, "fine"))
		for _, side in { -1, 1 } do
			bp:box(0.4, 1.2, 0.4, sx + side * 2.4, gy + 4.6, sz, o(Kit.straw, "fine"))
		end
		local wx, wy, wz = Kit.worldOf(b, sx, gy + 8.8, sz)
		Kit.life("perch", wx, wy, wz)
		local ax, ay, az = Kit.worldOf(b, sx + 2.4, gy + 5.4, sz)
		Kit.life("perch", ax, ay, az)
		table.insert(out, b)
	end
	-- an abandoned hand cart by the field road (bandits were here)
	local c = Kit.build("AbandonedCart", "field", s.x + 46, s.z + 52, 70)
	Parts.cart(c.bp, 0, 0, 0, 25)
	c.bp:add("ball", 1.4, 1, 1.4, 1.5, 0.5, 2.2, 0, 0, 0, o(Kit.cloth, "detail", { col = false }))
	c.bp:box(1.6, 0.9, 1.1, -1.8, 0.45, 2.6, o(Kit.cloth, "detail", { col = false }))
	table.insert(out, c)
end

-- Overgrown ruin of a watchtower in the forest (the city's ruin) with moss and a fallen tree.
local function ruins(out: { Build })
	local s = sites.ruins
	local b = Outside.ruin({ x = s.x, z = s.z }, ground)
	b.name = "ForestRuin"
	Kit.circle("ruins", s.x, s.z, 12)
	table.insert(out, b :: any)
	local f = Kit.build("RuinLog", "ruins", s.x + 16, s.z + 10, 35)
	f.bp:add("cyl", 18, 2.4, 2.4, 0, 1, 0, 0, 0, 4, o(Kit.bark, "shell", { q = false }))
	f.bp:box(10, 0.4, 2, 2, 2.3, 0, o(Kit.moss, "fine", { col = false }))
	for i = 1, 3 do
		f.bp:beam(-6 + i * 4, 1.6, 0, -6 + i * 4 + 1.5, 4, (i % 2) * 2 - 1, 0.4, o(Kit.bark, "detail", { col = false }))
	end
	table.insert(out, f)
end

-- Stone circle on the Wolf Hills ridge: nine standing stones, a fallen lintel, a flat altar stone.
local function stoneCircle(out: { Build })
	local s = sites.stonecircle
	local b = Kit.build("StoneCircle", "stonecircle", s.x, s.z, 0)
	Kit.ring("ruins", s.x, s.z, 11, 12, 2)
	local bp = b.bp
	local rng = bp.rng
	for i = 0, 8 do
		local a = i * math.pi * 2 / 9
		local lx, lz = math.cos(a) * 11, math.sin(a) * 11
		local h = rng:float(6, 9)
		local gy = Kit.gy(b, lx, lz)
		if i == 4 then
			bp:rbox(2.2, 2, h, lx, gy + 0.8, lz, 0, math.deg(a), 6, o(Kit.mossyStone, "shell", { q = false }))
		else
			bp:rbox(
				2.4,
				h,
				1.6,
				lx,
				gy + h / 2 - 0.5,
				lz,
				rng:float(-4, 4),
				-math.deg(a) + 90,
				rng:float(-5, 5),
				o(Kit.stone, "shell", { q = true })
			)
			bp:box(2.5, 0.25, 1.7, lx, gy + h * 0.4, lz, o(Kit.moss, "fine", { col = false }))
		end
	end
	bp:rbox(7, 1.4, 3.6, 0, Kit.gy(b, 0, 0) + 0.4, 0, 0, 20, 0, o(Kit.mossyStone, "shell", { q = true }))
	for i = 1, 4 do
		local a = i * 1.6
		bp:add(
			"ball",
			0.4,
			0.2,
			0.4,
			math.cos(a) * 1.5,
			Kit.gy(b, 0, 0) + 1.2,
			math.sin(a) * 0.8,
			0,
			0,
			0,
			o(Kit.bone, "fine")
		)
	end
	table.insert(out, b)
end

-- Wolf dens under rock outcrops: a dark hollow, gnawed bones and tufts of sheep wool.
local function wolfDens(out: { Build })
	local spots = { { -400, -40 }, { -300, 110 }, { -430, 250 }, { -280, -250 } }
	for i, p in spots do
		local b = Kit.build(`WolfDen_{i}`, "den", p[1], p[2], i * 75)
		local bp = b.bp
		Kit.rock(bp, 0, -1, 2.5, 8, Kit.stone, "shell")
		Kit.rock(bp, 4, Kit.gy(b, 4, 0) - 0.5, 0, 5, Kit.stone, "shell")
		bp:rbox(
			4.5,
			2.6,
			0.4,
			0.2,
			1,
			-1.2,
			-10,
			0,
			0,
			o({ c = "#141210", m = "SmoothPlastic" }, "detail", { col = false })
		)
		for k = 1, 6 do
			local a = k * 1.1
			local lx, lz = math.cos(a) * 4 - 1, math.sin(a) * 2 - 4
			bp:rbox(1.4, 0.25, 0.25, lx, Kit.gy(b, lx, lz) + 0.12, lz, 0, k * 50, 0, o(Kit.bone, "fine"))
		end
		for k = 1, 4 do
			local lx, lz = -5 + k * 2.2, -7 - (k % 2) * 2
			bp:add(
				"ball",
				0.9,
				0.6,
				0.9,
				lx,
				Kit.gy(b, lx, lz) + 0.25,
				lz,
				0,
				0,
				0,
				o({ c = "#E2DCCC", m = "Fabric" }, "fine")
			)
		end
		table.insert(out, b)
	end
end

-- Boar wallow: churned clods around the mud, a rubbing stump.
local function wallow(out: { Build })
	local s = sites.wallow
	local b = Kit.build("BoarWallow", "wallow", s.x, s.z, 0)
	local bp = b.bp
	for i = 0, 13 do
		local a = i * 0.45
		local d = 14 + (i % 3) * 3
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		bp:add(
			"ball",
			1.8,
			0.8,
			1.4,
			lx,
			Kit.gy(b, lx, lz) + 0.1,
			lz,
			0,
			i * 20,
			0,
			o({ c = "#4A3A2A", m = "Ground" }, "detail", { col = false })
		)
	end
	bp:add("cyl", 2.4, 2.6, 2.6, 9, Kit.gy(b, 9, -12) + 1, -12, 0, 0, 90, o(Kit.bark, "shell", { q = false }))
	bp:add("cyl", 1.2, 2.4, 2.4, 9, Kit.gy(b, 9, -12) + 1.5, -12, 0, 0, 90, o({ c = "#3A2E22", m = "Mud" }, "fine"))
	table.insert(out, b)
end

-- Wrecked merchant wagon by the road: on its side, a broken wheel, crates, barrels, sacks and spilled goods.
local function wagon(out: { Build })
	local s = sites.wagon
	local b = Kit.build("WreckedWagon", "wagon", s.x, s.z, s.rot)
	Kit.rect("building", s.x, s.z, 6, 10, s.rot)
	local bp = b.bp
	local planks = Palette.planks[2]
	bp:rbox(5, 1.4, 10, 0, 1.6, 0, 0, 0, 74, o(planks, "shell", { q = true }))
	bp:rbox(5, 3.4, 0.3, -1.2, 2.4, 4.9, 0, 0, 74, o(planks, "detail"))
	bp:rbox(5, 3.4, 0.3, -1.2, 2.4, -4.9, 0, 0, 74, o(planks, "detail"))
	for _, z in { -3, 3 } do
		bp:add("cyl", 0.5, 3.2, 3.2, 1.8, 3.6, z, 0, 0, 74, o(Kit.timber, "detail"))
	end
	-- a broken wheel and the shaft on the ground
	bp:rbox(0.4, 3.2, 3.2, -4, 0.25, -6, 0, 30, 90, o(Kit.timber, "detail"))
	bp:beam(-1, 0.3, -6, -1.5, 0.3, -12, 0.35, o(Kit.timber, "detail"))
	-- cargo
	for i = 1, 4 do
		Parts.crate(bp, -5 + i * 1.8, Kit.gy(b, -5 + i * 1.8, -2 - i), -2 - i, 1.6 + (i % 2) * 0.6)
	end
	Parts.barrel(bp, -6, Kit.gy(b, -6, 3), 3)
	bp:rbox(2.2, 1.8, 1.8, -7.5, Kit.gy(b, -7.5, 5.5) + 0.9, 5.5, 0, 30, 90, o(Palette.planks[1], "detail"))
	for i = 1, 3 do
		bp:add(
			"ball",
			1.6,
			1.1,
			1.3,
			-3 - i * 1.4,
			Kit.gy(b, -3 - i * 1.4, 6) + 0.5,
			6 + (i % 2),
			0,
			i * 30,
			0,
			o(Kit.cloth, "detail", { col = false })
		)
	end
	-- spilled goods: bolts of cloth and apples
	for i, c in { "#7A3B2E", "#3E5A7A", "#A8843A" } do
		bp:rbox(
			0.9,
			0.9,
			3,
			-9 + i * 1.5,
			Kit.gy(b, -9 + i * 1.5, -6) + 0.4,
			-6,
			0,
			i * 25,
			0,
			o({ c = c, m = "Fabric" }, "fine")
		)
	end
	for i = 1, 6 do
		bp:add(
			"ball",
			0.5,
			0.5,
			0.5,
			-2 + i * 0.7,
			Kit.gy(b, -2, -5) + 0.25,
			-5 - (i % 3) * 0.6,
			0,
			0,
			0,
			{ c = "#A8322A", m = "SmoothPlastic", lod = "fine" }
		)
	end
	table.insert(out, b)
end

-- Milestones along the merchant road every ~180 studs, on the right-hand side.
local function milestones(out: { Build })
	local line = MeadowsTerrain.roadLine(1)
	local n = 0
	local sAt = 120
	while sAt < line.length - 60 do
		local x, z, dx, dz = TerrainLayers.pointAt(line, sAt)
		local px, pz = x - dz * 10, z + dx * 10
		if MeadowsTerrain.streamDistance(px, pz) > 8 and not MeadowsTerrain.isWater(px, pz) then
			n += 1
			local rot = math.deg(math.atan2(dx, dz))
			local b = Kit.build(`Milestone_{n}`, "milestone", px, pz, rot)
			b.bp:box(1.6, 2.6, 0.9, 0, 1, 0, o(Palette.ashlar[2], "shell", { q = true }))
			b.bp:add("cyl", 0.9, 1.6, 1.6, 0, 2.3, 0, 0, 90, 0, o(Palette.ashlar[2], "detail"))
			for k = 1, math.min(n, 5) do
				b.bp:box(0.12, 0.7, 0.08, -0.6 + k * 0.22, 1.4, -0.5, o({ c = "#3A3630", m = "Slate" }, "fine"))
			end
			table.insert(out, b)
		end
		sAt += 180
	end
end

-- Bear dens: a big rock overhang, broken branches, a clawed pine stump, bones (bear_den anchor by the first).
local function bearDens(out: { Build })
	local first = (Areas.questAnchors or {})[1]
	local spots = { { 704, 474 }, { 610, 610 }, { 720, 690 } }
	for _, a in (Areas.questAnchors or {}) :: { AreaTypes.QuestAnchor } do
		if a.id == "bear_den" then
			first = a
			spots[1] = { a.x + 4, a.z + 6 }
		end
	end
	local _ = first
	for i, p in spots do
		local b = Kit.build(`BearDen_{i}`, "den", p[1], p[2], i * 110)
		local bp = b.bp
		Kit.rock(bp, 0, -1.5, 4, 12, Kit.mossyStone, "shell")
		Kit.rock(bp, -7, Kit.gy(b, -7, 2) - 1, 2, 8, Kit.mossyStone, "shell")
		bp:rbox(
			7,
			4,
			0.4,
			-1,
			1.5,
			-1.5,
			-8,
			0,
			0,
			o({ c = "#100E0C", m = "SmoothPlastic" }, "detail", { col = false })
		)
		for k = 1, 7 do
			local a = k * 0.9
			local lx, lz = math.cos(a) * 7, math.sin(a) * 4 - 7
			bp:rbox(
				0.5,
				0.5,
				3 + (k % 3),
				lx,
				Kit.gy(b, lx, lz) + 0.25,
				lz,
				0,
				k * 40,
				0,
				o(Kit.bark, "detail", { col = false })
			)
		end
		local tx, tz = 8, -6
		bp:add("cyl", 4, 2, 2, tx, Kit.gy(b, tx, tz) + 2, tz, 0, 0, 90, o(Kit.bark, "shell", { q = false }))
		for k = 0, 2 do
			bp:box(
				0.15,
				1.6,
				0.1,
				tx - 0.4 + k * 0.35,
				Kit.gy(b, tx, tz) + 2.4,
				tz - 1.02,
				o({ c = "#C8B48A", m = "Wood" }, "fine")
			)
		end
		for k = 1, 4 do
			bp:rbox(
				1.6,
				0.3,
				0.3,
				-3 + k,
				Kit.gy(b, -3 + k, -9) + 0.15,
				-9 - (k % 2),
				0,
				k * 60,
				0,
				o(Kit.bone, "fine")
			)
		end
		table.insert(out, b)
	end
end

-- Thickets on the Toad Mire's edge towards the Wolf Hills (the lynxes come out of them): hazel and young birches.
local function thickets(out: { Build })
	local b = Kit.build("LynxThickets", "trees", -270, 420, 0)
	local bp = b.bp
	local rng = bp.rng
	for i = 0, 26 do
		local t = i / 26
		local x = -335 + 120 * t + rng:float(-14, 14)
		local z = 372 + 100 * t + rng:float(-16, 16)
		if
			not MeadowsTerrain.isWater(x, z)
			and MeadowsTerrain.streamDistance(x, z) > 6
			and MeadowsTerrain.roadDistance(x, z) > 5
		then
			local lx, lz = x - b.at.x, z - b.at.z
			local y = Kit.gy(b, lx, lz)
			if i % 4 == 0 then
				Nature.tree(bp, "birch", lx, y, lz, rng:float(0.6, 0.8), false)
			else
				Nature.undergrowth(bp, if i % 3 == 0 then "sapling" else "bush", lx, y, lz)
				Nature.undergrowth(bp, "bush", lx + rng:float(-3, 3), y, lz + rng:float(-3, 3))
			end
		end
	end
	table.insert(out, b)
end

-- Fallen trees in the Old Forest: a mossy trunk (collides), broken branches, a root plate.
local function fallenTrees(out: { Build })
	local spots = { { -260, -520 }, { -60, -700 }, { 160, -560 }, { -180, -640 }, { 40, -610 }, { -280, -410 } }
	for i, p in spots do
		if
			MeadowsTerrain.roadDistance(p[1], p[2]) > 8
			and MeadowsTerrain.streamDistance(p[1], p[2]) > 8
			and Nature.isClear(p[1], p[2], 6)
		then
			local b = Kit.build(`FallenTree_{i}`, "trees", p[1], p[2], i * 53)
			local bp = b.bp
			local len = 16 + (i % 3) * 3
			bp:add("cyl", len, 2.2, 2.2, 0, 1, 0, 0, 0, 3, o(Kit.bark, "shell", { q = false }))
			bp:add("cyl", 1.2, 5.5, 5.5, -len / 2 - 0.3, 2, 0, 0, 0, 0, o({ c = "#4A3A28", m = "Ground" }, "detail"))
			bp:box(len * 0.6, 0.35, 1.8, 1, 2.15, 0, o(Kit.moss, "fine", { col = false }))
			for k = 1, 4 do
				bp:beam(
					-len / 2 + k * len / 5,
					1.6,
					0,
					-len / 2 + k * len / 5 + 1.2,
					3.6,
					(k % 2) * 2.4 - 1.2,
					0.35,
					o(Kit.bark, "detail", { col = false })
				)
			end
			bp:add("ball", 1.2, 0.6, 1.2, 2, 2.1, 0.8, 0, 0, 0, { c = "#B8423A", m = "SmoothPlastic", lod = "fine" })
			table.insert(out, b)
		end
	end
end

-- W14 (laki.md 1.5): three secrets for players who look around, all visual. (1) Behind the tallest wall of the forest
-- ruin the thorned petal of the Lady carved fresh and free of frost, a snuffed candle under it and boot prints in
-- the frost leading north. (2) A merchant wagon half sunk in Toad Pond: a wheel, crates and the tarp with the same
-- merchant's sign as Lucjan's wagon out of the water. (3) A ledge of flat stones behind the waterfall curtain to the
-- fishing spot, Borys's rod leaning on a rock.
local MERCHANT = { c = "#3E5A7A", m = "Fabric" }
local MERCHANT_SIGN = { c = "#C9A45C", m = "SmoothPlastic" }

local function ruinCrest(out: { Build })
	local s = sites.ruins
	-- the ruin's tallest wall faces 0.6 rad from +Z (TownGen/Outside ruin): the crest on its outer face
	local a = 0.6
	local r = 7
	local cx, cz = s.x + math.sin(a) * r, s.z + math.cos(a) * r
	local b = Kit.build("RuinCrest", "ruins", cx, cz, math.deg(a) + 180)
	local bp = b.bp
	local fresh = { c = "#B8B2A6", m = "Slate" }
	local cut = { c = "#3E3A36", m = "Slate" }
	-- a pale freshly cut disc on the weathered stone, the petal and the thorn cut into it
	bp:add("cyl", 0.2, 2.6, 2.6, 0, 6.5, -0.2, 0, 90, 0, o(fresh, "detail", { col = false }))
	bp:rbox(0.9, 1.6, 0.12, 0, 6.6, -0.35, 0, 0, 0, o(cut, "fine", { col = false }))
	bp:rbox(0.12, 1.3, 0.12, 0.45, 6.1, -0.35, 0, 0, -35, o(cut, "fine", { col = false }))
	bp:rbox(0.12, 0.5, 0.12, 0.7, 6.9, -0.35, 0, 0, 40, o(cut, "fine", { col = false }))
	-- snuffed candle at the foot (local -Z is outward, away from the ruin's centre)
	local fy = Kit.gy(b, 0, -1)
	bp:add("cyl", 0.6, 0.3, 0.3, 0, fy + 0.3, -1, 0, 0, 90, o({ c = "#E8E0C8", m = "SmoothPlastic" }, "fine"))
	bp:box(0.05, 0.15, 0.05, 0, fy + 0.66, -1, o({ c = "#1F1B19", m = "SmoothPlastic" }, "fine", { col = false }))
	-- boot prints in the frost leading away from the wall
	for i = 1, 7 do
		local lx, lz = (i % 2) * 0.7 - 0.35, -2.2 - i * 1.6
		bp:rbox(
			0.45,
			0.06,
			0.9,
			lx,
			Kit.gy(b, lx, lz) + 0.03,
			lz,
			0,
			0,
			0,
			o({ c = "#E6ECEF", m = "Snow" }, "fine", { col = false })
		)
	end
	table.insert(out, b)
end

local function sunkenWagon(out: { Build })
	local x, z = -560, 600
	local b = Kit.build("SunkenWagon", "wagon", x, z, 35)
	local bp = b.bp
	local water = MeadowsTerrain.LAKE_LEVEL - b.at.y -- the pond's surface in the build's frame
	local planks = Palette.planks[2]
	-- the bed tipped forward, its back corner out of the water
	bp:rbox(5, 1.4, 10, 0, water - 1.2, 0, 16, 0, 7, o(planks, "shell", { q = true }))
	bp:rbox(5, 2.6, 0.3, 0, water - 0.2, 4.7, 16, 0, 7, o(planks, "detail"))
	-- a wheel standing half out
	bp:add("cyl", 0.45, 3.4, 3.4, 2.8, water + 0.3, 3, 0, 0, 0, o(Kit.timber, "detail"))
	bp:add("cyl", 0.6, 0.7, 0.7, 2.9, water + 0.3, 3, 0, 0, 0, o(Kit.iron, "fine"))
	-- the tarp over the back with the merchant's sign
	bp:add("ball", 5.4, 2.2, 4.5, 0, water + 0.2, 2.6, 10, 0, 7, o(MERCHANT, "detail", { col = false }))
	bp:add("cyl", 0.1, 1.3, 1.3, 0, water + 1.2, 2.4, 0, 0, 90, o(MERCHANT_SIGN, "fine", { col = false }))
	-- crates afloat and stranded
	for i, c in { { -1.2, -1.5, 15 }, { -3.4, 2, -20 } } do
		bp:rbox(1.8, 1.8, 1.8, c[1], water - 0.4 + i * 0.1, c[2], 8, c[3], -6, o(Palette.planks[1], "detail"))
	end
	table.insert(out, b)
end

local function fallsLedge(out: { Build })
	local x, z = 738, 266
	local b = Kit.build("FallsLedge", "waterfall", x, z, 0)
	local bp = b.bp
	local pool = MeadowsTerrain.streamLevel(1, 0)
	-- from the dry side of the bowl to the foot of the wall behind the curtain
	local path = { { -7, -3 }, { -3.5, -2.6 }, { 0, -2 }, { 3.4, -1.2 }, { 6.4, -0.6 }, { 8.8, 0 } }
	local top = 0
	for i, p in path do
		local wx, wz = x + p[1], z + p[2]
		top = math.max(MeadowsTerrain.height(wx, wz), pool) + 0.45 - b.at.y
		bp:add(
			"cyl",
			0.9,
			2.6 + (i % 2) * 0.5,
			2.2,
			p[1],
			top - 0.45,
			p[2],
			0,
			i * 40,
			90,
			o(Kit.mossyStone, "shell", { q = false })
		)
	end
	-- the rock at the end and Borys's rod leaning on it, the line hanging into the pool
	local ex, ez = path[#path][1], path[#path][2]
	Kit.rock(bp, ex + 1.4, top - 0.6, ez - 1.6, 2.2, Kit.mossyStone, "detail")
	bp:beam(ex + 0.6, top, ez + 0.4, ex + 0.9, top + 5.4, ez - 1.2, 0.12, o(Kit.timber, "fine", { col = false }))
	bp:beam(
		ex + 0.9,
		top + 5.4,
		ez - 1.2,
		ex - 1.6,
		pool - b.at.y,
		ez + 1.6,
		0.03,
		o(Kit.rope, "fine", { col = false })
	)
	table.insert(out, b)
end

-- W14 (laki.md 1.4): the hoist crane on the north-east rim of the Old Quarry, its jib over the pit with a block of
-- stone on the rope (the mast collides, the rest is detail).
local function quarryCrane(out: { Build })
	local q = sites.quarry
	local a = math.rad(45)
	local x, z = q.x + math.sin(a) * 122 * 1.1, q.z - math.cos(a) * 96 * 1.1
	local b = Kit.build("QuarryCrane", "quarry", x, z, 135) -- local -Z toward the pit
	local bp = b.bp
	local wood = Kit.timber
	local H = 11
	-- the mast on a stone foot, two raking struts behind it
	bp:box(3, 1, 3, 0, Kit.gy(b, 0, 0) + 0.3, 0, o(Kit.stone, "shell", { q = true }))
	bp:add("cyl", H, 0.7, 0.7, 0, H / 2 + 0.5, 0, 0, 0, 90, o(wood, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:beam(side * 2.6, Kit.gy(b, side * 2.6, 3), 3, 0, H * 0.7, 0.2, 0.35, o(wood, "detail", { col = false }))
	end
	-- the jib out over the pit and its stay back to the mast top
	local jx, jy, jz = 0, H * 0.82, -12
	bp:beam(0, H * 0.55, 0, jx, jy, jz, 0.4, o(wood, "detail", { col = false }))
	bp:beam(0, H + 0.4, 0, jx, jy, jz, 0.12, o(Kit.rope, "fine", { col = false }))
	-- the winch drum at the foot of the mast
	bp:add("cyl", 1.8, 0.9, 0.9, 0, 1.6, 1.1, 0, 0, 0, o(wood, "detail", { col = false }))
	-- rope, hook and a hanging stone block
	local by = jy - 6
	bp:beam(jx, jy, jz, jx, by + 0.9, jz, 0.08, o(Kit.rope, "fine", { col = false }))
	bp:box(0.3, 0.6, 0.3, jx, by + 0.6, jz, o(Kit.iron, "fine", { col = false }))
	bp:rbox(2, 1.4, 1.6, jx, by - 0.3, jz, 0, 20, 0, o(Kit.stone, "detail", { col = false }))
	table.insert(out, b)
end

-- W14 (laki.md 1.4): lily pads on the shallow edges of Toad Pond's waters, some with a white or pink flower (client
-- detail only).
local function lilies(out: { Build })
	for li = 1, 5 do
		local lake = Areas.lakes[li]
		local b = Kit.build(`Lilies_{li}`, "lilies", lake.x, lake.z, 0)
		b.at.y = MeadowsTerrain.LAKE_LEVEL
		local bp = b.bp
		local n = 0
		local steps = math.floor(lake.r * 1.6)
		for k = 0, steps - 1 do
			local ang = k / steps * math.pi * 2 + li
			local rr = lake.r * (0.45 + bp.rng:float(0, 0.6))
			local wx, wz = lake.x + math.sin(ang) * rr, lake.z + math.cos(ang) * rr
			local w = MeadowsTerrain.water(wx, wz)
			if w and w - MeadowsTerrain.height(wx, wz) < 5.5 and bp.rng:chance(0.5) then
				n += 1
				local lx, lz = wx - lake.x, wz - lake.z
				for c = 1, 3 do
					local px, pz = lx + bp.rng:float(-1.6, 1.6), lz + bp.rng:float(-1.6, 1.6)
					local d = bp.rng:float(1.4, 2.4)
					bp:add(
						"cyl",
						0.08,
						d,
						d,
						px,
						w - b.at.y + 0.05,
						pz,
						0,
						bp.rng:float(0, 180),
						90,
						o({ c = if c == 2 then "#5E8A3A" else "#4E7A34", m = "LeafyGrass" }, "fine", { col = false })
					)
				end
				if n % 3 == 0 then
					bp:add(
						"ball",
						0.6,
						0.45,
						0.6,
						lx,
						w - b.at.y + 0.3,
						lz,
						0,
						0,
						0,
						o(
							{ c = if n % 2 == 0 then "#F2EEE6" else "#E8A6C0", m = "SmoothPlastic" },
							"fine",
							{ col = false }
						)
					)
				end
			end
		end
		table.insert(out, b)
	end
end

function Landmarks.all(out: { Build })
	thickets(out)
	fallenTrees(out)
	mill(out)
	fields(out)
	ruins(out)
	stoneCircle(out)
	wolfDens(out)
	wallow(out)
	wagon(out)
	milestones(out)
	bearDens(out)
	ruinCrest(out)
	sunkenWagon(out)
	fallsLedge(out)
	quarryCrane(out)
	lilies(out)
end

return Landmarks
