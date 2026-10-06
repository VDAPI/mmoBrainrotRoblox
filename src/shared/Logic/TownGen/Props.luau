--!strict
-- Street furniture of the city (S21, MIASTO.md §7): market stalls, the fountain, wells, the pillory, the quest board
-- and the cemetery. One Build per object. Pure.

local Blueprint = require("./Blueprint")
local Fill = require("./Fill")
local Palette = require("./Palette")
local Parts = require("./Parts")
local Structures = require("./Structures")
local TownGeom = require("../TownGeom")

type BP = Blueprint.Blueprint
type Build = Structures.Build
type Ground = (x: number, z: number) -> number

local o = Parts.o

local Props = {}

-- The pillory stands on the free east side of the market square (checked in tests/town.spec.luau).
Props.PILLORY = { x = 72, z = -42 }

local STONE = Palette.ashlar[1]
local BRONZE = { c = "#5E7A66", m = "Metal" }

-- Ring of `n` stone blocks around the origin of the current frame (wells, the fountain basin).
local function ring(
	bp: BP,
	n: number,
	r: number,
	h: number,
	thick: number,
	y: number,
	sw: Palette.Swatch,
	lod: Blueprint.Lod
)
	local side = 2 * (r + thick / 2) * math.tan(math.pi / n) + 0.1
	for i = 0, n - 1 do
		local a = i * 360 / n
		local ra = math.rad(a)
		bp:rbox(side, h, thick, math.sin(ra) * r, y + h / 2, math.cos(ra) * r, 0, a, 0, o(sw, lod, { q = true }))
	end
end

-- Gable roof of two plates over local X (ridge along X at height y, half depth hd, plate width w).
local function smallRoof(
	bp: BP,
	w: number,
	hd: number,
	y: number,
	pitch: number,
	sw: Palette.Swatch,
	lod: Blueprint.Lod?
)
	local p = math.rad(pitch)
	local len = hd / math.cos(p) + 0.4
	for _, s in { -1, 1 } do
		bp:rbox(w, 0.3, len, 0, y - math.sin(p) * len / 2, s * math.cos(p) * len / 2, s * pitch, 0, 0, o(sw, lod))
	end
end

local GOODS: { [string]: { string } } = {
	stall_bread = { "#B07A3A", "#C8924A", "#8E5A2A" },
	stall_cloth = { "#6B3E6B", "#3E5A7A", "#A8843A", "#7A2A22", "#E0D6C0" },
	stall_pottery = { "#9A5A3E", "#B8784A", "#7A4A30", "#C8B8A0" },
	stall_fish = { "#8A9AA8", "#6E7E8C", "#A8B4BC" },
	stall_merchant = { "#5AA060", "#A04A8A", "#4A7AC0", "#C8A040" },
	stall_backpacker = { "#6B5038", "#5A4632", "#7A6A4A" },
}

-- Market stall: counter toward the customers (local -Z) inside the 10x5 footprint of Data/Town, the awning runs
-- back over the vendor, who stands behind the counter at local z = +6 (Data/Town npcs), between crates.
local function stall(st: any, ground: Ground): Build
	local bp = Blueprint.new(math.floor(st.x * 7 + st.z * 13) % 99991 + 11)
	local y0 = ground(st.x, st.z)
	local wood = Palette.pick(bp.rng, Palette.planks)
	local timber = Palette.timber[1]
	local zc = -1.3 -- counter centre
	-- posts: front lower, back higher
	for _, x in { -4.6, 4.6 } do
		bp:box(0.45, 7.2, 0.45, x, 3.6, -2.6, o(timber, "shell", { q = true }))
		bp:box(0.45, 8.6, 0.45, x, 4.3, 7.4, o(timber, "shell", { q = true }))
		bp:beam(x, 7.2, -2.6, x, 8.6, 7.4, 0.35, o(timber))
	end
	bp:box(9, 3, 2.2, 0, 1.5, zc, o(wood, "shell", { q = true }))
	bp:box(9.4, 0.3, 2.6, 0, 3.1, zc - 0.2, o(Palette.planks[4]))
	-- striped awning in the stall colour and cream
	local depth = 10
	local ang = math.deg(math.atan2(1.4, depth))
	for i = 0, 4 do
		local x = -4.8 + (i + 0.5) * 9.6 / 5
		local c = if i % 2 == 0 then st.color else "#E2D6BC"
		bp:rbox(9.6 / 5 + 0.02, 0.18, depth + 0.8, x, 8.05, 2.4, -ang, 0, 0, { c = c, m = "Fabric", lod = "shell" })
		bp:add("wedge", 0.1, 0.8, 9.6 / 5, x, 7, -2.85, 0, 90, 180, { c = c, m = "Fabric", lod = "detail" })
	end
	-- goods on the counter (y 3.25 = counter top)
	local cols = GOODS[st.id] or GOODS.stall_merchant
	local rng = bp.rng
	if st.id == "stall_cloth" then
		for i = 0, 5 do
			local c = cols[i % #cols + 1]
			bp:add("cyl", 2.6, 0.9, 0.9, -3.4 + i * 1.35, 3.7, zc, 0, 90, 0, { c = c, m = "Fabric", lod = "detail" })
		end
		for i = 0, 2 do
			bp:box(1.6, 3.2, 0.1, -3 + i * 3, 6.2, 7.3, { c = cols[(i + 2) % #cols + 1], m = "Fabric", lod = "detail" })
		end
	elseif st.id == "stall_pottery" then
		for i = 0, 6 do
			local h = rng:float(0.9, 1.8)
			local d = rng:float(0.8, 1.3)
			local c = cols[rng:int(1, #cols)]
			bp:add("cyl", h, d, d, -3.6 + i * 1.2, 3.25 + h / 2, zc, 0, 0, 90, { c = c, m = "Slate", lod = "detail" })
			bp:add(
				"ball",
				d * 1.25,
				h * 0.7,
				d * 1.25,
				-3.6 + i * 1.2,
				3.25 + h * 0.45,
				zc,
				0,
				0,
				0,
				{ c = c, m = "Slate", lod = "fine" }
			)
		end
	elseif st.id == "stall_fish" then
		bp:box(7, 0.5, 1.8, 0, 3.5, zc, { c = "#C8D8E0", m = "Ice", lod = "detail" })
		for i = 0, 5 do
			bp:rbox(
				1.6,
				0.35,
				0.6,
				-2.8 + i * 1.1,
				3.9,
				zc + rng:float(-0.4, 0.4),
				0,
				rng:float(-30, 30),
				0,
				{ c = cols[rng:int(1, #cols)], m = "SmoothPlastic", lod = "fine" }
			)
		end
		Parts.barrel(bp, 3.6, 0, 6.6)
	elseif st.id == "stall_bread" then
		for i = 0, 7 do
			local c = cols[rng:int(1, #cols)]
			bp:add(
				"ball",
				1,
				0.6,
				1.5,
				-3.6 + i * 1.05,
				3.55,
				zc + rng:float(-0.4, 0.4),
				0,
				rng:float(-30, 30),
				0,
				{ c = c, m = "SmoothPlastic", lod = "detail" }
			)
		end
		for _, x in { -3.4, 3.4 } do
			bp:add("cyl", 1.2, 2, 2, x, 0.6, 6.4, 0, 0, 90, { c = "#8A6A40", m = "Fabric", lod = "detail" })
		end
	elseif st.id == "stall_backpacker" then
		for i = 0, 3 do
			bp:add(
				"ball",
				1.7,
				2.1,
				1.3,
				-3 + i * 2,
				4.3,
				zc,
				0,
				0,
				0,
				{ c = cols[rng:int(1, #cols)], m = "Leather", lod = "detail" }
			)
		end
		for _, x in { -3.4, 3.4 } do
			bp:add("cyl", 0.5, 1.6, 1.6, x, 0.25, 6.4, 0, 0, 90, { c = "#A08A5A", m = "Fabric", lod = "fine" })
		end
	else
		for i = 0, 5 do
			local c = cols[i % #cols + 1]
			bp:add(
				"cyl",
				1.1,
				0.6,
				0.6,
				-3 + i * 1.2,
				3.8,
				zc,
				0,
				0,
				90,
				{ c = c, m = "Glass", lod = "detail", t = 0.15 }
			)
		end
	end
	-- crates beside the vendor
	Parts.crate(bp, -3.5, 0, 6.8, 1.6)
	Parts.crate(bp, 3.5, 0, 7, 1.5)
	Parts.crate(bp, 3.5, 1.5, 7, 1.1)
	-- hanging lantern
	bp:box(0.8, 1, 0.8, 0, 6.3, -2.4, { c = "#FFD08A", m = "Neon", lod = "detail", t = 0.2, tag = "lamp" })
	bp:light(0, 6.3, -2.4, "#FFB860", 12, 0.6, "lamp")
	return { name = st.id, bp = bp, at = { x = st.x, y = y0, z = st.z, rot = st.rot }, tag = "stall" }
end

-- Fountain: octagonal basin, two bowls on a column and a bronze knight with a raised sword; benches around.
local function fountain(city: any, ground: Ground): Build
	local fx, fz = city.fountain[1], city.fountain[2]
	local bp = Blueprint.new(4242)
	local y0 = ground(fx, fz)
	local light = Palette.ashlar[3]
	bp:add("cyl", 0.6, 17, 17, 0, 0, 0, 0, 0, 90, o(STONE, "shell", { q = true }))
	ring(bp, 8, 6.6, 2.2, 1, 0.2, STONE, "shell")
	ring(bp, 8, 6.6, 0.35, 1.5, 2.4, light, "detail")
	bp:add(
		"cyl",
		0.2,
		13,
		13,
		0,
		1.7,
		0,
		0,
		0,
		90,
		{ c = "#3E6A8A", m = "Glass", lod = "detail", t = 0.25, col = false, tag = "water" }
	)
	bp:add("cyl", 4, 2, 2, 0, 2.2, 0, 0, 0, 90, o(STONE, "shell", { q = true }))
	bp:add("cyl", 0.8, 6, 6, 0, 4.5, 0, 0, 0, 90, o(light))
	bp:add(
		"cyl",
		0.15,
		5.3,
		5.3,
		0,
		4.95,
		0,
		0,
		0,
		90,
		{ c = "#4E7A9A", m = "Glass", lod = "detail", t = 0.25, tag = "water" }
	)
	bp:add("cyl", 2.5, 1, 1, 0, 6.2, 0, 0, 0, 90, o(STONE))
	bp:add("cyl", 0.5, 2.6, 2.6, 0, 7.5, 0, 0, 0, 90, o(light))
	-- the knight
	bp:box(1.3, 2.4, 0.8, 0, 9, 0, o(BRONZE))
	bp:box(0.5, 1.6, 0.6, -0.35, 7.5 + 0.3, 0, o(BRONZE, "fine"))
	bp:box(0.5, 1.6, 0.6, 0.35, 7.5 + 0.3, 0, o(BRONZE, "fine"))
	bp:add("ball", 0.95, 1.05, 0.95, 0, 10.75, 0, 0, 0, 0, o(BRONZE))
	bp:beam(0.6, 9.8, 0, 1.1, 13.6, -0.2, 0.25, o(BRONZE))
	bp:add("cyl", 0.2, 1.6, 1.6, -0.75, 9, -0.2, 0, 90, 0, o(BRONZE, "fine"))
	-- streams from the upper bowl
	for i = 0, 3 do
		local ra = math.rad(i * 90 + 45)
		bp:box(
			0.7,
			2.9,
			0.15,
			math.sin(ra) * 3.1,
			3.3,
			math.cos(ra) * 3.1,
			{ c = "#9AC0D8", m = "Glass", lod = "detail", t = 0.5, tag = "water" }
		)
	end
	for i = 0, 3 do
		local a = i * 90 + 45
		local ra = math.rad(a)
		Parts.bench(
			bp,
			math.sin(ra) * 11.5,
			ground(fx + math.sin(ra) * 11.5, fz + math.cos(ra) * 11.5) - y0,
			math.cos(ra) * 11.5,
			a,
			4.5
		)
	end
	return { name = "Fountain", bp = bp, at = { x = fx, y = y0, z = fz, rot = 0 }, tag = "fountain" }
end

-- Draw well with a winch under a little shingle roof.
function Props.well(bp: BP, x: number, y: number, z: number, ry: number)
	bp:push(x, y, z, 0, ry, 0)
	ring(bp, 8, 2.3, 2.4, 0.8, 0, Palette.rubble[1], "shell")
	bp:add("cyl", 0.2, 3.8, 3.8, 0, 1.6, 0, 0, 0, 90, { c = "#1E2A30", m = "Glass", lod = "detail", col = false })
	for _, s in { -1, 1 } do
		bp:box(0.5, 6.2, 0.5, s * 2.7, 3.1, 0, o(Palette.timber[1], "shell", { q = true }))
	end
	bp:add("cyl", 4.8, 0.6, 0.6, 0, 4.6, 0, 0, 0, 0, o(Palette.timber[2]))
	bp:beam(2.95, 4.6, 0, 3.4, 4.1, 0.6, 0.18, o(Palette.metal[1], "fine"))
	bp:box(0.08, 1.7, 0.08, 0, 3.7, 0, { c = "#8A7A5A", m = "Fabric", lod = "fine" })
	bp:add("cyl", 0.9, 0.9, 0.9, 0, 2.6, 0, 0, 0, 90, o(Palette.planks[1], "fine"))
	smallRoof(bp, 6.4, 2.2, 7.3, 32, Palette.shingles[1], "detail")
	bp:pop()
end

local function well(p: { number }, i: number, ground: Ground): Build
	local bp = Blueprint.new(700 + i)
	local y0 = ground(p[1], p[2])
	Props.well(bp, 0, 0, 0, bp.rng:float(0, 90))
	return { name = "Well" .. i, bp = bp, at = { x = p[1], y = y0, z = p[2], rot = 0 }, tag = "well" }
end

-- Pillory (pregierz): a stone column on steps with iron rings and a little executioner on top.
local function pillory(ground: Ground): Build
	local P = Props.PILLORY
	local bp = Blueprint.new(1717)
	local y0 = ground(P.x, P.z)
	for i = 0, 2 do
		bp:box(5 - i * 1.1, 0.6, 5 - i * 1.1, 0, 0.3 + i * 0.6, 0, o(STONE, "shell", { q = true }))
	end
	bp:add("cyl", 9, 1.5, 1.5, 0, 1.8 + 4.5, 0, 0, 0, 90, o(STONE, "shell", { q = true }))
	bp:box(2.2, 0.6, 2.2, 0, 11.1, 0, o(Palette.ashlar[3]))
	for _, s in { -1, 1 } do
		bp:add("cyl", 0.2, 1.1, 1.1, s * 0.8, 5, 0, 0, 0, 0, o(Palette.metal[1], "fine"))
	end
	bp:box(0.9, 1.6, 0.6, 0, 12.2, 0, o(BRONZE))
	bp:add("ball", 0.7, 0.75, 0.7, 0, 13.4, 0, 0, 0, 0, o(BRONZE))
	bp:beam(0.4, 12.6, 0, 0.6, 15, 0, 0.2, o(BRONZE))
	return { name = "Pillory", bp = bp, at = { x = P.x, y = y0, z = P.z, rot = 0 }, tag = "pillory" }
end

-- Quest board: a roofed notice board full of pinned notes, with a lantern.
local function questBoard(city: any, ground: Ground): Build
	local s = city.npcs.questboard
	local bp = Blueprint.new(9090)
	local y0 = ground(s.x, s.z)
	local timber = Palette.timber[2]
	for _, x in { -3.4, 3.4 } do
		bp:box(0.6, 7.4, 0.6, x, 3.7, 0, o(timber, "shell", { q = true }))
	end
	bp:box(6.6, 4.2, 0.4, 0, 4.1, 0, o(Palette.planks[2], "shell", { q = true }))
	bp:box(7.2, 0.4, 0.6, 0, 6.35, 0, o(timber))
	bp:box(7.2, 0.4, 0.6, 0, 1.9, 0, o(timber))
	smallRoof(bp, 8, 1.4, 8.1, 30, Palette.shingles[2], "detail")
	local rng = bp.rng
	for i = 0, 8 do
		local x = -2.6 + (i % 5) * 1.3 + rng:float(-0.2, 0.2)
		local y = if i < 5 then 5 else 3.4
		local c = if rng:chance(0.6) then "#E6DAC0" else "#D2C098"
		bp:rbox(
			1,
			1.3,
			0.05,
			x,
			y + rng:float(-0.2, 0.2),
			-0.24,
			0,
			0,
			rng:float(-8, 8),
			{ c = c, m = "SmoothPlastic", lod = "fine" }
		)
		bp:box(0.15, 0.15, 0.08, x, y + 0.5, -0.28, { c = "#8A2A22", m = "SmoothPlastic", lod = "fine" })
	end
	bp:box(0.2, 0.2, 1.6, 3.4, 6.8, -0.9, o(Palette.metal[1]))
	bp:box(0.7, 0.9, 0.7, 3.4, 6, -1.6, { c = "#FFD08A", m = "Neon", lod = "detail", t = 0.2, tag = "lamp" })
	bp:light(3.4, 6, -1.6, "#FFB860", 14, 0.7, "lamp")
	return { name = "QuestBoard", bp = bp, at = { x = s.x, y = y0, z = s.z, rot = s.facing }, tag = "questboard" }
end

-- Cemetery: a low stone wall with a roofed gate toward the temple, rows of headstones and crosses, old yews and a
-- small crypt.
local function cemetery(city: any, ground: Ground): Build
	local poly = city.cemetery
	local cx, cz = Fill.centroid(poly)
	local y0 = ground(cx, cz)
	local bp = Blueprint.new(6660)
	local rng = bp.rng
	local lp = Fill.localPoly(poly, cx, cz)
	-- the gate goes into the edge closest to the temple
	local tx, tz = 0, 0
	for _, sp in city.specials do
		if sp.kind == "temple" then
			tx, tz = sp.x - cx, sp.z - cz
		end
	end
	local gateEdge, best = 1, math.huge
	for i, a in lp do
		local b = lp[i % #lp + 1]
		local d = (((a[1] + b[1]) / 2 - tx) ^ 2 + ((a[2] + b[2]) / 2 - tz) ^ 2)
		if d < best then
			best, gateEdge = d, i
		end
	end
	local wall = Palette.rubble[2]
	for i, a in lp do
		local b = lp[i % #lp + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local ry = math.deg(math.atan2(-dz, dx))
		local spans = { { 0, len } }
		if i == gateEdge then
			spans = { { 0, len / 2 - 3 }, { len / 2 + 3, len } }
		end
		for _, sp in spans do
			local l = sp[2] - sp[1]
			local t = (sp[1] + sp[2]) / 2 / len
			local mx, mz = a[1] + dx * t, a[2] + dz * t
			local gy = ground(cx + mx, cz + mz) - y0
			bp:rbox(l + 1, 2.6, 1, mx, gy + 0.9, mz, 0, ry, 0, o(wall, "shell", { q = true }))
			bp:rbox(l + 1.2, 0.3, 1.3, mx, gy + 2.35, mz, 0, ry, 0, o(Palette.slate[1]))
		end
		if i == gateEdge then
			local mx, mz = a[1] + dx / 2, a[2] + dz / 2
			local gy = ground(cx + mx, cz + mz) - y0
			bp:push(mx, gy, mz, 0, ry, 0)
			for _, s in { -1, 1 } do
				bp:box(0.6, 6, 0.6, s * 3, 3, 0, o(Palette.timber[1], "shell", { q = true }))
			end
			smallRoof(bp, 7.6, 1.6, 7.2, 35, Palette.shingles[1], "detail")
			bp:pop()
		end
	end
	-- graves on a loose grid, all facing the same way like old rows
	local pts = Fill.scatter(lp, rng, 6.5, 4)
	local graves = 0
	local yews = 0
	for k, p in pts do
		local x, z = p[1], p[2]
		local gy = ground(cx + x, cz + z) - y0
		if k % 17 == 5 and yews < 4 then
			yews += 1
			Parts.tree(bp, x, gy, z, "yew", 1.2, "shell")
		elseif graves < 80 then
			graves += 1
			local tilt, lean = rng:float(-6, 6), rng:float(-4, 4)
			local stone = { c = bp:jitter("#8A857C", 0.1), m = if rng:chance(0.5) then "Limestone" else "Slate" }
			local r = rng:next()
			if r < 0.45 then
				bp:rbox(1.6, 2.2, 0.45, x, gy + 1.1, z, lean, 0, tilt, o(stone))
				bp:add("cyl", 0.45, 1.6, 1.6, x, gy + 2.2, z, lean, 90, tilt, o(stone, "fine"))
			elseif r < 0.75 then
				bp:rbox(0.45, 3, 0.45, x, gy + 1.5, z, lean, 0, tilt, o(stone))
				bp:rbox(1.8, 0.45, 0.45, x, gy + 2.2, z, lean, 0, tilt, o(stone))
			else
				local wood = Palette.pick(rng, Palette.greyPlanks)
				bp:rbox(0.3, 2.6, 0.3, x, gy + 1.3, z, lean, 0, tilt, o(wood))
				bp:rbox(1.5, 0.3, 0.3, x, gy + 1.9, z, lean, 0, tilt, o(wood))
			end
			bp:box(1.6, 0.35, 2.8, x, gy + 0.1, z + 1.8, { c = "#4E4234", m = "Ground", lod = "fine" })
		end
	end
	-- crypt at the vertex farthest from the gate
	local fxp, fzp, far = 0, 0, -1
	local ga, gb = lp[gateEdge], lp[gateEdge % #lp + 1]
	local gmx, gmz = (ga[1] + gb[1]) / 2, (ga[2] + gb[2]) / 2
	for _, v in lp do
		local d = (v[1] - gmx) ^ 2 + (v[2] - gmz) ^ 2
		if d > far then
			far, fxp, fzp = d, v[1], v[2]
		end
	end
	local kx, kz = fxp * 0.75, fzp * 0.75
	if TownGeom.inPoly(lp, kx, kz) then
		local gy = ground(cx + kx, cz + kz) - y0
		local ry = math.deg(math.atan2(kx, kz)) -- front (-Z) toward the centre
		bp:push(kx, gy, kz, 0, ry, 0)
		bp:box(7, 6, 8, 0, 3, 0, o(STONE, "shell", { q = true }))
		smallRoof(bp, 7.6, 4.4, 9.2, 32, Palette.slateRoof[1], "shell")
		for _, e in { -1, 1 } do
			for _, s in { -1, 1 } do
				bp:add("wedge", 0.6, 3, 4, e * 3.2, 7.5, s * 2, 0, if s > 0 then 180 else 0, 0, o(STONE))
			end
		end
		bp:box(2.4, 4, 0.3, 0, 2, -4.05, { c = "#2A2622", m = "Metal", lod = "detail" })
		bp:box(1, 1, 0.2, 0, 4.9, -4.1, o(Palette.ashlar[3], "fine"))
		bp:pop()
	end
	return { name = "Cemetery", bp = bp, at = { x = cx, y = y0, z = cz, rot = 0 }, tag = "cemetery" }
end

function Props.all(city: any, ground: Ground): { Build }
	local out: { Build } = {}
	for _, st in city.stalls do
		table.insert(out, stall(st, ground))
	end
	table.insert(out, fountain(city, ground))
	for i, p in city.wells do
		table.insert(out, well(p, i, ground))
	end
	table.insert(out, pillory(ground))
	table.insert(out, questBoard(city, ground))
	table.insert(out, cemetery(city, ground))
	return out
end

return Props
