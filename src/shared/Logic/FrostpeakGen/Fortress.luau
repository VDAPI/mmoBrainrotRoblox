--!strict
-- Ice Watch (88–95, fast EXP) (S47): the order's fortress on its rocky knoll, everything under a crust of ice.
--   * the gate barred with icicles and the iced-over keep (the landmark): walls with four corner towers, the gate in
--     the west wall, the keep in the courtyard,
--   * banners frozen in mid-flap in the order's colours, weapon racks in the ice, sentries frozen at their posts,
--     the patrol road round the walls with torches of blue fire,
--   * ice elementals: crystals bursting through the walls, rime spread over the stones; at night the loopholes glow
--     cold blue like the knights' eyes. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Fortress = {}

type Build = Kit.Build

local HALF = 64 -- half the side of the walls' square
local WALL_H = 14

local function loophole(bp: Kit.BP, x: number, y: number, z: number, yaw: number)
	bp:rbox(0.8, 2.2, 0.3, x, y, z, 0, yaw, 0, {
		c = Props.EYES,
		m = "Neon",
		lod = "detail",
		col = false,
		tag = "glow",
		jitter = 0,
		fxColor = Props.EYES,
	})
end

local function walls(env: Env.Env, out: { Build })
	local k = env.sites.keep
	local cx, cz = k.x, k.z
	local base = env.T.height(cx, cz)
	-- four walls (the west one split by the gate)
	local sides = {
		{ 0, -HALF, 2 * HALF, 0 }, -- north
		{ 0, HALF, 2 * HALF, 0 }, -- south
		{ HALF, 0, 2 * HALF, 90 }, -- east
		{ -HALF, -HALF / 2 - 6, HALF - 12, 90 }, -- west, north of the gate
		{ -HALF, HALF / 2 + 6, HALF - 12, 90 }, -- west, south of the gate
	}
	for i, s in ipairs(sides) do
		local b = Kit.buildAt(`IceWatchWall_{i}`, "wall", cx + s[1], base, cz + s[2], s[4])
		local bp = b.bp
		local len = s[3]
		bp:box(len, WALL_H, 4, 0, WALL_H / 2 - 2, 0, o(Props.frostStone, "shell", { q = false }))
		for m = -math.floor(len / 8), math.floor(len / 8) do
			bp:box(2.4, 2, 4.4, m * 4, WALL_H, 0, o(Props.frostStone, "detail", { col = false }))
		end
		bp:box(len, 1.2, 4.6, 0, WALL_H - 3, 0, o(Props.ice, "detail", { col = false, t = 0.3 }))
		Props.icicles(bp, 0, WALL_H - 3.6, -2.4, len, math.floor(len / 3), 3)
		Props.snowCap(bp, 0, WALL_H + 1.1, 0, len, 4, "fine")
		for m = -2, 2 do
			loophole(bp, m * len / 6, WALL_H - 5, -2.1, 0)
		end
		-- a crystal bursting through the wall
		if i <= 3 then
			Props.crystals(bp, len * 0.25, 0, -2.6, 1.2, "detail", i == 1)
		end
		table.insert(out, b)
	end
	-- corner towers
	for i, c in { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
		local b = Kit.buildAt(`IceWatchTower_{i}`, "wall", cx + c[1] * HALF, base, cz + c[2] * HALF, 0)
		local bp = b.bp
		bp:add(
			"cyl",
			WALL_H + 8,
			11,
			11,
			0,
			(WALL_H + 8) / 2 - 2,
			0,
			0,
			0,
			90,
			o(Props.frostStone, "shell", { q = false })
		)
		bp:add("cyl", 2, 12.4, 12.4, 0, WALL_H + 7, 0, 0, 0, 90, o(Props.paleStone, "detail", { col = false }))
		bp:add("wedge", 9, 7, 9, 0, WALL_H + 11.4, 0, 0, 45, 0, o(Props.darkStone, "detail", { col = false }))
		Props.snowCap(bp, 0, WALL_H + 8.4, 0, 10, 10, "fine")
		for m = 0, 3 do
			local a = m * math.pi / 2
			loophole(bp, math.cos(a) * 5.6, WALL_H + 2, math.sin(a) * 5.6, math.deg(-a) + 90)
		end
		Props.banner(bp, 0, WALL_H + 12, 0, 6, Props.orderDark, Props.orderPale, true)
		table.insert(out, b)
	end
	Env.clear(env, cx, cz, HALF + 14)
end

local function gate(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.icewatchGate
	local base = env.T.height(env.sites.keep.x, env.sites.keep.z)
	local b = Kit.buildAt("icewatchGate", "landmark", env.sites.keep.x - HALF, base, s.z, 90)
	local bp = b.bp
	-- gatehouse: two towers and an arch over the gate, barred with icicles like a portcullis
	for _, side in { -1, 1 } do
		bp:box(8, WALL_H + 6, 8, side * 10, (WALL_H + 6) / 2 - 2, 0, o(Props.frostStone, "shell", { q = false }))
		Props.snowCap(bp, side * 10, WALL_H + 4.4, 0, 8, 8, "fine")
		Props.torch(bp, side * 7, 6, -4.2)
		Props.banner(bp, side * 10, WALL_H + 4, -1, 5, Props.orderDark, Props.orderPale, true)
		-- a sentry frozen at his post
		local sx = side * 8
		bp:box(1.8, 4.6, 1.2, sx, 2.3, -6, o(Props.orderPale, "detail", { col = false }))
		bp:add("ball", 1.6, 1.8, 1.6, sx, 5.4, -6, 0, 0, 0, o(Props.iron, "detail", { col = false }))
		bp:box(
			1.8,
			0.3,
			0.2,
			sx,
			5.5,
			-6.8,
			{ c = Props.EYES, m = "Neon", lod = "fine", col = false, tag = "glow", jitter = 0, fxColor = Props.EYES }
		)
		bp:rbox(0.3, 7, 0.3, sx + 1.2, 3.4, -6, 0, 0, -6, o(Props.iron, "fine", { col = false }))
		bp:add("ball", 3.4, 6.4, 2.6, sx, 3, -6, 0, 0, 0, o(Props.ice, "fine", { col = false, t = 0.55 }))
	end
	bp:box(12, 4, 8, 0, WALL_H + 0.4, 0, o(Props.frostStone, "shell", { q = false }))
	for m = -5, 5 do
		local l = 9 + (m % 3) * 1.4
		bp:add(
			"wedge",
			0.8,
			l,
			0.8,
			m * 1.05,
			WALL_H - 1.6 - l / 2,
			-3.6,
			180,
			0,
			0,
			o(Props.ice, "detail", { col = false, t = 0.15 })
		)
	end
	Kit.lifeAt(ctx, b, "icicleDust", 0, 10, -4)
	table.insert(out, b)
end

local function keep(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.keep
	local b = Kit.buildAt("keep", "landmark", s.x + 10, env.T.height(s.x, s.z), s.z, s.rot)
	local bp = b.bp
	bp:box(30, 30, 26, 0, 13, 0, o(Props.frostStone, "shell", { q = true }))
	bp:box(32, 3, 28, 0, 29.4, 0, o(Props.paleStone, "detail", { col = false }))
	for m = -3, 3 do
		bp:box(3, 3, 3, m * 4.4, 32, -13, o(Props.frostStone, "detail", { col = false }))
		bp:box(3, 3, 3, m * 4.4, 32, 13, o(Props.frostStone, "detail", { col = false }))
	end
	-- a skin of ice over the walls, icicles from every ledge
	bp:box(31, 20, 27, 0, 10, 0, o(Props.ice, "detail", { col = false, t = 0.55 }))
	Props.icicles(bp, 0, 27.8, -14.2, 30, 18, 5)
	Props.icicles(bp, 0, 18, -14.2, 30, 12, 3)
	bp:box(6, 9, 0.4, 0, 4, -13.2, o(Kit.dark, "detail", { col = false }))
	for m = -2, 2 do
		loophole(bp, m * 5, 20, -13.2, 0)
		loophole(bp, m * 5, 12, -13.2, 0)
	end
	bp:light(0, 20, -16, Props.EYES, 24, 1, "crystal")
	Props.snowCap(bp, 0, 31.4, 0, 30, 26, "shell")
	Props.banner(bp, 12, 33, 0, 8, Props.orderDark, Props.orderPale, true)
	-- weapon racks frozen into the courtyard
	for m = 0, 2 do
		local lx = -26 + m * 6
		bp:box(4, 4, 0.4, lx, Kit.gy(ctx, b, lx, -26) + 2, -26, o(Props.oldWood, "detail", { col = false }))
		bp:box(4.4, 1.4, 1.4, lx, Kit.gy(ctx, b, lx, -26) + 0.5, -26, o(Props.ice, "fine", { col = false, t = 0.4 }))
	end
	table.insert(out, b)
end

-- Torches of blue fire along the outer side of the patrol ring (Data/Areas/frostpeak: 92 studs from the keep).
local function patrol(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local k = env.sites.keep
	local r = 99
	local spots = {}
	for _, t in { -46, 46 } do
		table.insert(spots, { k.x + t, k.z - r })
		table.insert(spots, { k.x + t, k.z + r })
		table.insert(spots, { k.x + r, k.z + t })
	end
	for i, p in spots do
		local b = Kit.build(ctx, `PatrolTorch_{i}`, "lamp", p[1], p[2], 0)
		local bp = b.bp
		local y = Kit.gy(ctx, b, 0, 0)
		bp:box(0.5, 6, 0.5, 0, y + 3, 0, o(Props.iron, "shell", { q = false }))
		Kit.fire(bp, 0, y + 6.4, 0, 0.9, Props.ICEFIRE)
		Env.clear(env, p[1], p[2], 3)
		table.insert(out, b)
	end
end

function Fortress.all(env: Env.Env, out: { Build })
	walls(env, out)
	gate(env, out)
	keep(env, out)
	patrol(env, out)
end

return Fortress
