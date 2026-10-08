--!strict
-- Wyvern Crags (58–66, fast EXP) (S46): a forest of rust-red spires with basalt caps, mesas, the canyon road.
--   * wyvern nests on the spires' tops (brushwood, bones, hanging scales seen from below) and the thinnest
--     pinnacles finished with rock,
--   * the nest mesa (ramp from the road): a great nest with eggs, bones of prey and scorched stone,
--   * the Stone Wyvern (the landmark): a wyvern turned to stone mid-roar on a low spire by the road (a basilisk
--     hunts here too), smaller petrified beasts round it,
--   * a natural rock arch over the road, black fire stains and claw furrows on the rocks, broken shells. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Crags = {}

type Build = Kit.Build

local TWIGS = { c = "#3A2E24", m = "Wood" }

-- A nest of brushwood with bones and a few eggs at (x, y, z) of the current frame (`s` scale).
local function nest(bp: Kit.BP, x: number, y: number, z: number, s: number, eggs: number, lod: string?)
	bp:add("cyl", 1.4 * s, 9 * s, 9 * s, x, y + 0.4 * s, z, 0, 0, 90, o(TWIGS, (lod or "shell") :: any, { q = false }))
	for k = 0, 9 do
		local a = k * math.pi / 5
		bp:beam(
			x + math.cos(a) * 3.6 * s,
			y + 0.6 * s,
			z + math.sin(a) * 3.6 * s,
			x + math.cos(a + 0.9) * 4.6 * s,
			y + 1.6 * s,
			z + math.sin(a + 0.9) * 4.6 * s,
			0.3 * s,
			o(TWIGS, "detail", { col = false })
		)
	end
	for k = 1, eggs do
		bp:add(
			"ball",
			1.4 * s,
			1.9 * s,
			1.4 * s,
			x + (k - 2) * 1.6 * s,
			y + 1.6 * s,
			z + (k % 2) * s,
			0,
			0,
			0,
			o({ c = "#C9B79A", m = "SmoothPlastic" }, "detail", { col = false })
		)
	end
	Kit.bones(bp, x + 2 * s, y + 1, z - 1.4 * s, 3)
	-- scales hanging over the edge
	for k = 1, 3 do
		bp:rbox(0.9, 1.2, 0.08, x + (k - 2) * 3 * s, y - 0.4, z - 4.4 * s, 20, 0, k * 10, o(Props.scale, "fine"))
	end
end

local function spireTops(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, s in assert(env.T.shape.spires, "spires") do
		if s.h < 20 then
			continue
		end
		Env.clear(env, s.x, s.z, s.r * 1.5)
		local top = env.T.height(s.x, s.z)
		local b = Kit.buildAt(`SpireTop_{i}`, "crag", s.x, top, s.z, i * 47)
		local bp = b.bp
		if i % 2 == 0 then
			nest(bp, 0, 0, 0, 0.9, (i % 3) + 1)
			Kit.lifeAt(ctx, b, "vulturePerch", 1, 2.2, 0)
		else
			-- a pinnacle of rock finishing the spire's narrow top
			bp:rbox(4.4, 9, 4, 0.6, 3.6, 0, 6, 0, -8, o(Props.basalt, "shell", { q = false }))
			bp:rbox(2.4, 5, 2.4, 1.2, 9.4, 0.4, -6, 20, -12, o(Props.basalt, "detail", { col = false }))
		end
		Props.scorch(bp, 0, -6, -s.r * 0.35, 4, 5)
		table.insert(out, b)
		Kit.circle(ctx, "crag", s.x, s.z, s.r * 0.8)
	end
end

local function nestMesa(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.nestMesa
	Env.clear(env, s.x, s.z, 44)
	local b = Kit.build(ctx, "nestMesa", "crag", s.x, s.z, s.rot)
	local bp = b.bp
	nest(bp, 0, 0, 0, 1.8, 4)
	-- scorched stone and the bones of prey round the nest
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.4
		local lx, lz = math.cos(a) * 14, math.sin(a) * 14
		bp:add("ball", 6, 0.1, 4, lx, Kit.gy(ctx, b, lx, lz) + 0.05, lz, 0, k * 30, 0, o(Props.soot, "fine"))
		if k % 2 == 0 then
			Props.carcass(bp, lx * 0.8, Kit.gy(ctx, b, lx * 0.8, lz * 0.8), lz * 0.8, k * 50)
		end
	end
	-- a broken egg
	for k = 0, 3 do
		bp:rbox(
			1.6,
			0.2,
			1.2,
			9 + k * 0.8,
			Kit.gy(ctx, b, 9, 6) + 0.2,
			6 + k * 0.5,
			k * 30,
			k * 50,
			0,
			o({ c = "#C9B79A", m = "SmoothPlastic" }, "fine")
		)
	end
	Kit.lifeAt(ctx, b, "vultures", 0, 40, 0, 26)
	table.insert(out, b)
end

-- The stone wyvern roaring on its low spire, petrified beasts round it.
local function wyvernStone(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.wyvernStone
	Env.clear(env, s.x, s.z, 18)
	local top = env.T.height(s.x, s.z)
	local b = Kit.buildAt("wyvernStone", "landmark", s.x, top, s.z, s.rot)
	local bp = b.bp
	local st = Props.petrified
	bp:rbox(4.4, 4, 9, 0, 3.6, 0, -18, 0, 0, o(st, "shell", { q = false }))
	bp:rbox(2, 2, 8, 0, 7.4, -5.6, -48, 0, 0, o(st, "shell", { q = false }))
	-- the head with open jaws, roaring at the sky
	bp:rbox(2.4, 2.2, 4, 0, 11.6, -8.6, -60, 0, 0, o(st, "detail", { col = false }))
	bp:rbox(1.8, 0.8, 3.6, 0, 10.6, -9.6, -20, 0, 0, o(st, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:rbox(0.5, 0.5, 2.4, side * 0.8, 13.2, -8, -70, side * 20, 0, o(st, "fine")) -- horns
		-- spread wings: a bone and a membrane
		bp:rbox(12, 0.6, 1, side * 7, 7.6, -1, 0, side * -15, side * 28, o(st, "shell", { q = false }))
		bp:rbox(11, 0.3, 6, side * 6.6, 6.4, 1.6, 0, side * -15, side * 24, o(st, "detail", { col = false }))
		bp:rbox(1.2, 4, 1.2, side * 1.8, 1.4, 1.6, 10, 0, 0, o(st, "detail", { col = false }))
	end
	bp:rbox(1.4, 1.4, 9, 0, 2.2, 8, 12, 0, 0, o(st, "detail", { col = false }))
	table.insert(out, b)
	-- petrified hyenas and a vulture at its foot
	local foot = Kit.build(ctx, "PetrifiedBeasts", "statue", s.x - 18, s.z + 10, 30)
	Env.clear(env, s.x - 18, s.z + 10, 10)
	Props.ox(foot.bp, 0, 0, 0, 40, st, "shell")
	Props.ox(foot.bp, 6, Kit.gy(ctx, foot, 6, 4), 4, 160, st)
	foot.bp:add("ball", 1.4, 1.6, 2, -5, Kit.gy(ctx, foot, -5, 3) + 0.9, 3, 0, 0, 0, o(st, "detail", { col = false }))
	foot.bp:rbox(3.4, 0.3, 1.2, -5, Kit.gy(ctx, foot, -5, 3) + 1.4, 3, 0, 0, 30, o(st, "detail", { col = false }))
	table.insert(out, foot)
end

-- The natural rock arch over the crags' road (clearance 18 studs).
local function arch(env: Env.Env, out: { Build })
	local s = env.sites.stoneArch
	Env.clear(env, s.x, s.z, 20)
	local b = Kit.build(env.ctx, "stoneArch", "crag", s.x, s.z, s.rot)
	local bp = b.bp
	local rock = { c = "#6E2F2A", m = "Sandstone" }
	for _, side in { -1, 1 } do
		bp:rbox(6, 22, 7, side * 12.5, 10, 0, 0, 0, side * 6, o(rock, "shell", { q = false }))
		bp:rbox(4, 10, 5, side * 13.5, 3, 3, 0, 20, side * -4, o(Props.rust, "detail", { col = false }))
	end
	for k = -2, 2 do
		local x = k * 5.2
		local y = 21 + (1 - (k / 2.6) ^ 2) * 3.6
		bp:rbox(
			6,
			4.6,
			7,
			x,
			y,
			0,
			0,
			0,
			-k * 10,
			o(rock, if math.abs(k) <= 1 then "shell" else "detail", { q = false })
		)
	end
	bp:box(16, 1.2, 0.08, 0, 19.8, -3.55, o(Props.soot, "fine"))
	table.insert(out, b)
end

function Crags.all(env: Env.Env, out: { Build })
	spireTops(env, out)
	nestMesa(env, out)
	wyvernStone(env, out)
	arch(env, out)
	for _, m in assert(env.T.shape.mesas, "mesas") do
		if m.x and m.rx and m.rz then
			Kit.circle(env.ctx, "mesa", m.x, m.z or 0, (m.rx + m.rz) / 2)
		elseif m.poly then
			local pts = table.clone(m.poly)
			table.insert(pts, m.poly[1])
			table.insert(pts, m.poly[2])
			Kit.line(env.ctx, "cliff", pts, 6)
		end
	end
end

return Crags
