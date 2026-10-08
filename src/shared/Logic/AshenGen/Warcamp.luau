--!strict
-- Ash Orc Warcamp (48–56) (S46): a fortress on the basalt plateau.
--   * a palisade of sharpened stakes with skulls along the plateau's edge, the gate of tusks and logs over the main
--     ramp, a back gate over the west ramp, watchtowers at the corners with rust-red banners,
--   * the forge (an ember hearth, anvils, racks of two-handed axes, heaps of scrap; its smoke is seen from the
--     road), the great war drum on its dais, cages with the bones of captives, the warchief's tent, tents of
--     rust-red cloth, campfires,
--   * the Blood Ring (the landmark): a sunken arena with stakes and posts in the middle of the camp,
--   * under the east cliff the carrion dump: bones and carcasses, dead trees with vultures. Pure.

local Env = require("./Env")
local Flora = require("../WorldGen/Flora")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local Structures = require("../WorldGen/Structures")

local o = Kit.o

local Warcamp = {}

type Build = Kit.Build

local CLOTH = { c = "#7A3A2A", m = "Fabric" }
local STAKE = "#3A2E26"
local BANNER = { c = "#B5462B", m = "Fabric" }

-- The plateau's outline pulled 9 studs in (the palisade's line).
local function wallLine(env: Env.Env): { { number } }
	local poly = assert(env.T.shape.plateaus[1].poly, "poly")
	local n = #poly // 2
	local cx, cz = 0, 0
	for i = 1, n do
		cx += poly[2 * i - 1] / n
		cz += poly[2 * i] / n
	end
	local pts = {}
	for i = 1, n do
		local x, z = poly[2 * i - 1], poly[2 * i]
		local d = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2)
		table.insert(pts, { x + (cx - x) / d * 9, z + (cz - z) / d * 9 })
	end
	return pts
end

local function palisade(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local pts = wallLine(env)
	local gate = env.sites.warcampGate
	local gaps = { { gate.x, gate.z, 9 }, { -406, -600, 8 } }
	local n = 0
	for i, a in pts do
		local b = pts[i % #pts + 1]
		local len = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		local segs = math.max(1, math.floor(len / 12))
		for k = 0, segs - 1 do
			local t1, t2 = k / segs, (k + 1) / segs
			local x1, z1 = a[1] + (b[1] - a[1]) * t1, a[2] + (b[2] - a[2]) * t1
			local x2, z2 = a[1] + (b[1] - a[1]) * t2, a[2] + (b[2] - a[2]) * t2
			local mx, mz = (x1 + x2) / 2, (z1 + z2) / 2
			local open = false
			for _, g in gaps do
				if (mx - g[1]) ^ 2 + (mz - g[2]) ^ 2 < (g[3] + 4) ^ 2 then
					open = true
				end
			end
			if not open then
				n += 1
				local seg = math.sqrt((x2 - x1) ^ 2 + (z2 - z1) ^ 2)
				local yaw = math.deg(math.atan2(-(z2 - z1), x2 - x1))
				local wb = Kit.build(ctx, `Palisade_{n}`, "wall", mx, mz, yaw)
				local bp = wb.bp
				bp:box(seg + 0.6, 7, 1.4, 0, 2.8, 0, o({ c = STAKE, m = "Wood" }, "shell", { q = true }))
				local stakes = math.floor(seg / 1.5)
				for s = 0, stakes do
					local lx = -seg / 2 + s * seg / math.max(1, stakes)
					local h = 8 + bp.rng:float(-0.6, 1)
					bp:add(
						"cyl",
						h,
						1.3,
						1.3,
						lx,
						h / 2 - 0.6,
						0,
						0,
						0,
						90,
						o({ c = bp:jitter(STAKE, 0.1), m = "Wood" }, "detail", { col = false })
					)
					bp:add("wedge", 1.2, 1.4, 1.2, lx, h - 0.1, 0, 0, 0, 0, o({ c = STAKE, m = "Wood" }, "fine"))
					if s % 6 == 3 then
						Kit.skull(bp, lx, h + 0.4, -0.2, 0.9, 0)
					end
				end
				table.insert(out, wb)
				Kit.line(ctx, "wall", { x1, z1, x2, z2 }, 2)
			end
		end
	end
end

-- The gate of tusks and logs over the main ramp, with banners and two braziers.
local function gate(env: Env.Env, out: { Build })
	local b = Env.atSite(env, "warcampGate", "gate", 14)
	local bp = b.bp
	for _, side in { -1, 1 } do
		bp:add("cyl", 14, 2.6, 2.6, side * 7, 6.4, 0, 0, 0, 90, o({ c = STAKE, m = "Wood" }, "shell", { q = true }))
		-- curved tusks leaning in over the passage
		bp:beam(side * 7.5, 2, -1.5, side * 4, 14, -3, 1.4, o(Kit.bone, "detail", { col = false }))
		bp:beam(side * 4, 14, -3, side * 1.2, 16, -1, 1, o(Kit.bone, "detail", { col = false }))
		bp:box(0.2, 6, 2.6, side * 8.6, 9, -0.4, o(BANNER, "detail", { col = false, tag = "flag" }))
		Kit.fire(bp, side * 10, 2.4, -3, 1.4, Kit.FIRE)
		bp:add("cyl", 2.4, 1.8, 1.8, side * 10, 1.2, -3, 0, 0, 90, o(Props.ironDark, "detail", { col = false }))
	end
	bp:box(17, 1.6, 2, 0, 13.4, 0, o({ c = STAKE, m = "Wood" }, "shell", { q = false }))
	Kit.skull(bp, 0, 14.2, -1.2, 2.2, 0)
	table.insert(out, b)
end

local function towers(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local pts = wallLine(env)
	for i, idx in { 1, 4, 6, 8 } do
		local p = pts[idx]
		Env.clear(env, p[1], p[2], 6)
		local b = Kit.build(ctx, `OrcTower_{i}`, "tower", p[1], p[2], i * 30)
		local bp = b.bp
		for _, c in { { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } } do
			bp:box(0.9, 16, 0.9, c[1], 7.6, c[2], o({ c = STAKE, m = "Wood" }, "shell", { q = false }))
		end
		bp:box(6.4, 0.6, 6.4, 0, 15.4, 0, o(Kit.planks, "shell", { q = false }))
		for _, side in { -1, 1 } do
			bp:box(6.4, 1.6, 0.3, 0, 16.6, side * 3.1, o({ c = STAKE, m = "Wood" }, "detail", { col = false }))
		end
		bp:rbox(7.2, 0.4, 7.2, 0, 19.4, 0, 0, 45, 0, o(CLOTH, "detail", { col = false }))
		bp:box(0.3, 6, 0.3, 2.8, 22, 2.8, o(Kit.timber, "detail", { col = false }))
		bp:box(0.15, 2.4, 3.4, 2.8, 23.4, 1.1, o(BANNER, "fine", { tag = "flag" }))
		table.insert(out, b)
	end
end

-- Forge: hearth of glowing coal under a hood, anvils, racks of axes, scrap; smoke column.
local function forge(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "orcForge", "forge", 16)
	local bp = b.bp
	bp:box(7, 2.4, 5, 0, 1.2, 2, o(Props.basalt, "shell", { q = true }))
	bp:box(
		5,
		0.6,
		3.4,
		0,
		2.6,
		2,
		{ c = Props.EMBER, m = "Neon", lod = "detail", col = false, tag = "forge", jitter = 0 }
	)
	bp:light(0, 4.6, 2, Props.EMBER, 26, 1.8, "fire")
	bp:add("wedge", 7.4, 4, 5.4, 0, 6.2, 2, 0, 0, 0, o(Props.ironDark, "detail", { col = false }))
	bp:box(1.8, 9, 1.8, 0, 12, 3.4, o(Props.basalt, "shell", { q = false, tag = "smoke" }))
	for k, lx in { -4, 3.4 } do
		bp:box(1.2, 1.6, 1, lx, 0.8, -4, o(Props.ironDark, "detail", { col = false }))
		bp:box(2.6, 0.8, 1.1, lx, 2, -4, o(Props.ironDark, "shell", { q = false }))
		bp:add(
			"wedge",
			0.9,
			0.7,
			1.1,
			lx + 1.7 * (if k == 1 then 1 else -1),
			2,
			-4,
			0,
			if k == 1 then 90 else -90,
			0,
			o(Props.ironDark, "detail", { col = false })
		)
	end
	-- racks of two-handed axes
	for k = 0, 2 do
		local lx = -8 + k * 3
		bp:box(0.3, 3.6, 0.3, lx, 1.8, -9, o(Kit.timber, "detail", { col = false }))
		bp:box(0.2, 0.2, 2.6, lx, 3.2, -9, o(Kit.timber, "fine"))
		bp:rbox(0.2, 2.4, 1.6, lx, 3.8, -9.8, 0, 0, 10, o(Props.ironDark, "fine"))
	end
	for k = 0, 3 do
		bp:rbox(
			2.2,
			1,
			1.6,
			7 + k * 1.2,
			0.4 + (k % 2) * 0.6,
			-6 + k * 2,
			k * 20,
			k * 50,
			k * 15,
			o(Props.ironDark, "detail", { col = false })
		)
	end
	Kit.lifeAt(ctx, b, "smokeColumn", 0, 18, 3.4, 6)
	Kit.lifeAt(ctx, b, "embers", 0, 3.4, 2, 3)
	table.insert(out, b)
end

local function drum(env: Env.Env, out: { Build })
	local b = Env.atSite(env, "warDrum", "drum", 10)
	local bp = b.bp
	bp:box(10, 1.6, 8, 0, 0.6, 0, o(Props.basalt, "shell", { q = false }))
	bp:add("cyl", 6, 7, 7, 0, 5.2, 0, 90, 0, 0, o(Kit.hide, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:add("cyl", 0.4, 7.4, 7.4, 0, 5.2, side * 3, 90, 0, 0, o(Kit.bone, "detail", { col = false }))
		bp:rbox(0.4, 4.6, 0.4, side * 3.6, 3.6, -3.6, 30, 0, side * 20, o(Kit.bone, "fine"))
	end
	for k = 0, 5 do
		local a = k * math.pi / 3
		bp:box(0.25, 0.25, 6.4, math.cos(a) * 3.5, 5.2 + math.sin(a) * 3.5, 0, o(Kit.rope, "fine"))
	end
	Kit.skull(bp, -4, 1.4, -3.4, 1.1, 0)
	Kit.skull(bp, 4, 1.4, -3.4, 1.1, 0)
	table.insert(out, b)
end

local function cages(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "orcCages", "cages", 12)
	local bp = b.bp
	for k = -1, 1 do
		local lz = k * 6
		bp:push(0, Kit.gy(ctx, b, 0, lz), lz, 0, k * 8, 0)
		bp:box(4.6, 0.4, 4.6, 0, 0.2, 0, o(Kit.timber, "shell", { q = false }))
		bp:box(4.6, 0.4, 4.6, 0, 5, 0, o(Kit.timber, "detail", { col = false }))
		for i = 0, 3 do
			for _, c in
				{ { -2.1 + i * 1.4, -2.1 }, { -2.1 + i * 1.4, 2.1 }, { -2.1, -2.1 + i * 1.4 }, { 2.1, -2.1 + i * 1.4 } }
			do
				bp:box(0.25, 4.6, 0.25, c[1], 2.6, c[2], o(Props.ironDark, "detail", { col = false }))
			end
		end
		Kit.bones(bp, 0, 0.4, 0, 4)
		bp:pop()
	end
	table.insert(out, b)
end

-- The Blood Ring: stakes around the sunken arena, posts with chains in the middle, dark stains.
local function bloodPit(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "bloodPit", "landmark", 22)
	local bp = b.bp
	for k = 0, 15 do
		local a = k * math.pi / 8
		local lx, lz = math.cos(a) * 21, math.sin(a) * 19
		local y = Kit.gy(ctx, b, lx, lz)
		bp:rbox(
			1,
			6,
			1,
			lx,
			y + 2.4,
			lz,
			math.sin(a) * 10,
			0,
			-math.cos(a) * 10,
			o({ c = STAKE, m = "Wood" }, if k % 2 == 0 then "shell" else "detail", { q = false })
		)
		if k % 4 == 1 then
			Kit.skull(bp, lx, y + 5.6, lz, 1, math.deg(-a) - 90)
		end
	end
	for _, lx in { -3, 3 } do
		bp:add("cyl", 8, 1.6, 1.6, lx, 3.8, 0, 0, 0, 90, o(Kit.darkBark, "shell", { q = false }))
		bp:box(0.3, 3, 0.3, lx, 4.8, -0.9, o(Props.ironDark, "fine"))
	end
	for k = 1, 5 do
		local lx, lz = bp.rng:float(-12, 12), bp.rng:float(-10, 10)
		bp:add(
			"ball",
			3.4,
			0.08,
			2.6,
			lx,
			Kit.gy(ctx, b, lx, lz) + 0.05,
			lz,
			0,
			k * 40,
			0,
			o({ c = "#4A1A16", m = "SmoothPlastic" }, "fine")
		)
	end
	table.insert(out, b)
end

local function tents(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local chief = Env.atSite(env, "chiefTent", "tent", 14)
	local cp = chief.bp
	cp:push(0, 0, 0, 0, 0, 0)
	for _, side in { -1, 1 } do
		cp:rbox(12, 0.4, 8, 0, 3.6, side * 3, side * 48, 0, 0, o(CLOTH, "shell", { q = true }))
	end
	cp:pop()
	for _, lx in { -6.4, 6.4 } do
		cp:box(0.5, 9, 0.5, lx, 4.5, 0, o(Kit.timber, "detail"))
		Kit.skull(cp, lx, 9.2, 0, 1.4, 0)
	end
	cp:box(0.2, 5, 2.6, 7.4, 6, -5, o(BANNER, "detail", { col = false, tag = "flag" }))
	cp:box(0.4, 9, 0.4, 7.4, 4.5, -6.4, o(Kit.timber, "detail", { col = false }))
	for k = 1, 3 do
		cp:rbox(3, 0.15, 2, -3 + k * 2, 0.1, -6, 0, k * 25, 0, o(Kit.fur, "fine"))
	end
	table.insert(out, chief)
	local SPOTS = {
		{ -330, -540, 20 },
		{ -200, -600, 80 },
		{ -170, -640, 140 },
		{ -380, -580, 100 },
		{ -300, -662, 10 },
		{ -150, -490, 60 },
	}
	for i, p in SPOTS do
		Env.clear(env, p[1], p[2], 8)
		local b = Kit.build(ctx, `OrcTent_{i}`, "tent", p[1], p[2], p[3])
		Structures.tent(b.bp, 0, 0, 0, 0, CLOTH, i % 3 == 0)
		table.insert(out, b)
	end
	for i, p in { { -290, -606 }, { -200, -560 } } do
		Env.clear(env, p[1], p[2], 6)
		local b = Kit.build(ctx, `OrcFire_{i}`, "fire", p[1], p[2], 0)
		Kit.campfire(b.bp, 0, 0, 0)
		Kit.lifeAt(ctx, b, "smoke", 0, 2, 0, 2)
		table.insert(out, b)
	end
end

-- Carrion dump under the east cliff: bones, carcasses, dead trees with vultures.
local function carrion(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "carrionHeap", "traces", 18)
	local bp = b.bp
	local perch = ctx.perch
	ctx.perch = "vulturePerch"
	for k, p in { { -8, 6 }, { 9, -8 } } do
		Flora.species.blackDead(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], 1 + k * 0.1, true, ctx)
	end
	ctx.perch = perch
	for k = 1, 4 do
		local lx, lz = bp.rng:float(-10, 10), bp.rng:float(-10, 10)
		Props.carcass(bp, lx, Kit.gy(ctx, b, lx, lz), lz, k * 70)
	end
	bp:add(
		"ball",
		9,
		2.2,
		7,
		0,
		Kit.gy(ctx, b, 0, 0),
		0,
		0,
		30,
		0,
		o({ c = "#BFB59C", m = "Slate" }, "detail", { col = false })
	)
	Kit.lifeAt(ctx, b, "vultures", 0, 44, 0, 22)
	table.insert(out, b)
end

function Warcamp.all(env: Env.Env, out: { Build })
	gate(env, out)
	palisade(env, out)
	towers(env, out)
	forge(env, out)
	drum(env, out)
	cages(env, out)
	bloodPit(env, out)
	tents(env, out)
	carrion(env, out)
	local poly = assert(env.T.shape.plateaus[1].poly, "poly")
	local pts = {}
	for i = 1, #poly do
		table.insert(pts, poly[i])
	end
	table.insert(pts, poly[1])
	table.insert(pts, poly[2])
	Kit.line(env.ctx, "cliff", pts, 6)
end

return Warcamp
