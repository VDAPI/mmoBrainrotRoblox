--!strict
-- W18 (docs/wyglad/mapy/pustkowia.md 1.4, 1.5): the details and secrets the map plan adds to the Ashen Wastes. Built
-- after every other module and without clearings of their own, so trees, rocks and gathering nodes stay where they
-- were (every Build is named Detail_*). All visual: no collision except the compass boulder, nothing on a road or over an anchor.
--   * Salamander Flats: the toppled dwarven signpost "Deepforge" with blue runes by the portal gate,
--   * Warcamp: crates with the cult's grey frost-petal sign by the forge and a rack of frosted axes; the cold axe on
--     the carrion dump, steaming in the heat (secret 3),
--   * Burnt Ruins: a half-burnt washing line between the chimneys and a child's cart left on the square; Ilvar's
--     footprints, unburnt in the ash, from the temple across the square (secret 2),
--   * Scorpion Dunes: gold glinting in the sand by the sarcophagi,
--   * Wyvern Crags: a cult harness hanging from a peg by the arch,
--   * Ash Road: animals turned to stone, all facing the basilisk's den,
--   * Nest Mesa: a flat boulder with a carved dwarven compass rose (secret 1). Pure.

local Areas = require("../../Data/Areas/ashen")
local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Details = {}

type Build = Kit.Build

local RUNE = { c = "#6BB8FF", m = "Neon" }
local FROST = { c = "#DCEEFA", m = "Ice" }
local CULT_GREY = { c = "#9A9AA2", m = "SmoothPlastic" }

-- The frost petal of the cult: a grey disc with a pale six-armed star, its face looking along local -Z.
local function cultSign(bp: Kit.BP, x: number, y: number, z: number)
	bp:add("cyl", 0.08, 1, 1, x, y, z, 0, 90, 0, o(CULT_GREY, "fine", { col = false }))
	for k = 0, 2 do
		bp:rbox(
			0.08,
			0.8,
			0.06,
			x,
			y,
			z - 0.06,
			0,
			0,
			k * 60,
			o({ c = "#E8F2FA", m = "SmoothPlastic" }, "fine", { col = false })
		)
	end
end

local function anchor(id: string): { x: number, z: number, rot: number }?
	for _, a in (Areas :: any).questAnchors or {} do
		if a.id == id then
			return { x = a.x, z = a.z, rot = a.rot or 0 }
		end
	end
	return nil
end

local function signpost(env: Env.Env, out: { Build })
	local b = Kit.build(env.ctx, "Detail_DwarfSignpost", "traces", -650, 24, 20)
	local bp = b.bp
	local gy = Kit.gy(env.ctx, b, 0, 0)
	-- the stump still standing, the post lying in the ash
	bp:box(0.9, 1.4, 0.9, 0, gy + 0.5, 0, o(Props.basalt, "detail", { col = false }))
	bp:rbox(0.8, 0.8, 7, 0, gy + 0.35, 3.6, 0, 8, 0, o(Kit.timber, "detail", { col = false }))
	-- the arm with the runes of Deepforge
	bp:rbox(3.6, 0.9, 0.25, 1.4, gy + 0.5, 6.6, -80, 8, 0, o(Kit.planks, "detail", { col = false }))
	for k = 0, 3 do
		bp:box(0.35, 0.35, 0.1, 0.2 + k * 0.8, gy + 0.62, 6.6, o(RUNE, "fine", { col = false }))
	end
	table.insert(out, b)
end

local function warcamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.orcForge
	local b = Kit.build(ctx, "Detail_ForgeColdIron", "forge", s.x, s.z, s.rot)
	local bp = b.bp
	-- crates of cold iron with the cult's sign
	for k, c in { { 7, 7, 1.8 }, { 9, 6, 1.6 }, { 8, 9.2, 1.5 } } do
		local gy = Kit.gy(ctx, b, c[1], c[2])
		Props.crate(bp, c[1], gy, c[2], c[3], false, "detail")
		if k <= 2 then
			cultSign(bp, c[1], gy + c[3] * 0.55, c[2] - c[3] / 2 - 0.06)
		end
	end
	-- a rack of axes white with frost
	for k = 0, 2 do
		local lx = -8 + k * 3
		local gy = Kit.gy(ctx, b, lx, -13)
		bp:box(0.3, 3.6, 0.3, lx, gy + 1.8, -13, o(Kit.timber, "detail", { col = false }))
		bp:rbox(0.2, 2.4, 1.6, lx, gy + 3.8, -13.8, 0, 0, 10, o(Props.ironDark, "fine", { col = false }))
		bp:rbox(0.26, 2.2, 1.4, lx, gy + 3.9, -13.8, 0, 0, 10, o(FROST, "fine", { col = false, t = 0.35 }))
	end
	Kit.lifeAt(ctx, b, "steam", -5, Kit.gy(ctx, b, -5, -13) + 4, -13, 3)
	table.insert(out, b)

	-- secret 3: the cold axe on the carrion dump, steam rising off its blade in the heat
	local c = env.sites.carrionHeap
	local a = Kit.build(ctx, "Detail_ColdAxe", "traces", c.x + 6, c.z + 12, 30)
	local ap = a.bp
	local gy = Kit.gy(ctx, a, 0, 0)
	ap:rbox(0.25, 4, 0.25, 0, gy + 1.6, 0, 0, 0, 14, o(Kit.timber, "detail", { col = false }))
	ap:rbox(0.25, 1.8, 1.6, 0.4, gy + 0.5, 0, 0, 0, 14, o(FROST, "detail", { col = false }))
	Kit.lifeAt(ctx, a, "steam", 0.4, gy + 1.2, 0, 1.5)
	table.insert(out, a)
end

local function ruins(env: Env.Env, out: { Build })
	local ctx = env.ctx
	-- a washing line between two chimneys of the row, burnt through in the middle
	local r = env.sites.chimneyRow
	local b = Kit.build(ctx, "Detail_WashingLine", "ruins", r.x, r.z, r.rot)
	local bp = b.bp
	local y1, y2 = Kit.gy(ctx, b, -6, 0) + 6, Kit.gy(ctx, b, 6, 0) + 6
	local mid = (y1 + y2) / 2
	bp:beam(-6, y1, 0, -0.6, mid - 0.8, 0, 0.05, o(Kit.rope, "fine", { col = false }))
	bp:beam(6, y2, 0, 0.8, mid - 1.6, 0, 0.05, o(Kit.rope, "fine", { col = false }))
	local cloths: { { number | string } } = { { -4.6, "#C8B89A" }, { -2.6, "#8A6A4A" }, { 4.2, "#A8B0B8" } }
	for k, c in cloths do
		local lx = c[1] :: number
		local t = math.abs(lx) / 6
		local ly = mid - 1 + ((if lx < 0 then y1 else y2) - mid + 1) * t
		bp:box(
			1.4,
			1.6 - k * 0.2,
			0.08,
			lx,
			ly - 1,
			0,
			o({ c = c[2] :: string, m = "Fabric" }, "fine", { col = false, tag = "flag" })
		)
		bp:box(0.5, 0.4, 0.09, lx + 0.3, ly - 1.6, 0, o(Props.soot, "fine", { col = false }))
	end
	table.insert(out, b)

	-- a child's cart left on the square, away from the fountain and the hermit
	local q = env.sites.ruinsSquare
	local cart = Kit.build(ctx, "Detail_ChildCart", "ruins", q.x - 14, q.z + 10, 40)
	local cp = cart.bp
	local gy = Kit.gy(ctx, cart, 0, 0)
	cp:box(1.6, 0.6, 2.4, 0, gy + 0.8, 0, o(Kit.planks, "detail", { col = false }))
	for _, w in { { -0.9, -0.8 }, { 0.9, -0.8 }, { -0.9, 0.8 }, { 0.9, 0.8 } } do
		cp:add("cyl", 0.15, 0.9, 0.9, w[1], gy + 0.45, w[2], 0, 0, 0, o(Kit.timber, "fine", { col = false }))
	end
	cp:rbox(0.12, 0.12, 2.2, 0, gy + 1.2, -2.1, 25, 0, 0, o(Kit.timber, "fine", { col = false }))
	cp:add(
		"ball",
		0.6,
		0.6,
		0.6,
		0.2,
		gy + 1.4,
		0.4,
		0,
		0,
		0,
		o({ c = "#B85A3A", m = "Fabric" }, "fine", { col = false })
	)
	table.insert(out, cart)

	-- secret 2: Ilvar's footprints, pale and unburnt in the ash, from the temple's door north-west across the square
	local t = env.sites.burntTemple
	local f = Kit.build(ctx, "Detail_IlvarSteps", "ruins", t.x - 26, t.z - 6, 0)
	local fp = f.bp
	local avoid = { { x = 175, z = 634 }, { x = 10, z = 600 } } -- the hermit and the dry fountain (>= 8 studs)
	for k = 0, 17 do
		local wx, wz = t.x - 30 - k * 6, t.z - 10 - k * 2.4
		local clear = true
		for _, p in avoid do
			if (wx - p.x) ^ 2 + (wz - p.z) ^ 2 < 64 then
				clear = false
			end
		end
		if clear then
			local lx, lz = wx - f.at.x + (k % 2) * 0.8, wz - f.at.z
			fp:rbox(
				0.5,
				0.05,
				1,
				lx,
				Kit.gy(ctx, f, lx, lz) + 0.03,
				lz,
				0,
				70,
				0,
				o({ c = "#B8AE9C", m = "Sand" }, "fine", { col = false })
			)
		end
	end
	table.insert(out, f)
end

local function dunes(env: Env.Env, out: { Build })
	local s = env.sites.sarcophagi
	local b = Kit.build(env.ctx, "Detail_SandGold", "dunes", s.x, s.z, s.rot)
	local bp = b.bp
	for k = 0, 7 do
		local lx, lz = bp.rng:float(-14, 14), bp.rng:float(-12, 12)
		local gy = Kit.gy(env.ctx, b, lx, lz)
		if k % 3 == 0 then
			-- a gold mask face-up, half under the sand
			bp:add("ball", 1.2, 0.35, 1.5, lx, gy + 0.05, lz, 0, k * 40, 0, o(Props.gold, "fine", { col = false }))
		else
			bp:add("cyl", 0.1, 0.5, 0.5, lx, gy + 0.05, lz, 0, 0, 90 - k * 7, o(Props.gold, "fine", { col = false }))
		end
	end
	table.insert(out, b)
end

local function crags(env: Env.Env, out: { Build })
	local s = env.sites.stoneArch
	local b = Kit.build(env.ctx, "Detail_CultHarness", "traces", s.x + 16, s.z + 8, s.rot)
	local bp = b.bp
	local gy = Kit.gy(env.ctx, b, 0, 0)
	-- straps hanging from a peg in the rock, a buckle and the cult's sign on the breast plate
	bp:box(0.3, 0.3, 1.2, 0, gy + 7, 0, o(Props.ironDark, "detail", { col = false }))
	for k = -1, 1 do
		bp:rbox(
			0.35,
			4.5 - math.abs(k),
			0.1,
			k * 0.6,
			gy + 4.8 + math.abs(k) * 0.5,
			-0.6,
			0,
			0,
			k * 8,
			o(Props.orcHide, "fine", { col = false, tag = "flag" })
		)
	end
	bp:box(1.4, 1.2, 0.2, 0, gy + 4.4, -0.7, o(Props.ironDark, "fine", { col = false }))
	cultSign(bp, 0, gy + 4.4, -0.86)
	table.insert(out, b)
end

local function road(env: Env.Env, out: { Build })
	local den = env.sites.basiliskDen
	for i, p in { { 26, -8 }, { -22, 18 }, { 10, 30 } } do
		local x, z = den.x + p[1], den.z + p[2]
		-- local -Z (the animal's head) toward the pit
		local yaw = math.deg(math.atan2(x - den.x, z - den.z))
		local b = Kit.build(env.ctx, `Detail_StoneBeast_{i}`, "statue", x, z, yaw)
		Props.ox(b.bp, 0, Kit.gy(env.ctx, b, 0, 0), 0, 0, Props.petrified, "detail")
		table.insert(out, b)
	end
end

local function mesa(env: Env.Env, out: { Build })
	local a = anchor("ash_great_nest")
	local x, z = if a then a.x else 712, if a then a.z else -492
	local b = Kit.build(env.ctx, "Detail_CompassRose", "traces", x - 9, z + 6, 0)
	local bp = b.bp
	local gy = Kit.gy(env.ctx, b, 0, 0)
	bp:add("cyl", 1, 6, 5.4, 0, gy + 0.4, 0, 0, 0, 90, o(Props.sandstone, "shell", { q = false }))
	local cut = { c = "#7A6448", m = "Sandstone" }
	for k = 0, 3 do
		bp:rbox(
			0.2,
			0.08,
			if k % 2 == 0 then 4.6 else 3,
			0,
			gy + 0.92,
			0,
			0,
			k * 45,
			0,
			o(cut, "fine", { col = false })
		)
	end
	bp:rbox(0.5, 0.1, 0.5, 0, gy + 0.95, -2.3, 0, 45, 0, o(cut, "fine", { col = false }))
	table.insert(out, b)
end

function Details.all(env: Env.Env, out: { Build })
	signpost(env, out)
	warcamp(env, out)
	ruins(env, out)
	dunes(env, out)
	crags(env, out)
	road(env, out)
	mesa(env, out)
end

return Details
