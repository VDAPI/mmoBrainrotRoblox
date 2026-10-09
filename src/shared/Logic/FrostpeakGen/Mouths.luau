--!strict
-- Cave mouths of the Frost Peaks (S47), built where Data/Areas/frostpeak puts the entrances (the layout adds the
-- portal, the sign with the cave's name and levels, and the map icon):
--   * the Ice Grotto: a hole in an ice wall on the Yeti Slopes' top bench, fangs of icicles over it (the biggest
--     8-12 studs), a blue glow from inside (glow + one light), yeti and wolf tracks leading in, a bed of furs and
--     bones on the threshold,
--   * the Frozen Hold: the fortress gate swallowed by the glacier tongue, two gate towers sticking out of the ice up
--     to their battlements, a dark passage under the ice, the order's banners frozen by the arch, torn iron doors
--     frozen beside it (the giants' work), torches of blue fire,
--   * the Glacier Heart: the climax of the main road: the great glacier's front with its seracs split by a cleft,
--     crystals glowing from deep inside (cyan), rime on the walls, scales and frozen bones on the threshold. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Mouths = {}

type Build = Kit.Build

local function cave(env: Env.Env, id: string)
	for _, c in env.areas.caves do
		if c.cave == id then
			return c
		end
	end
	error(`no cave {id}`)
end

local function glowInside(bp: Kit.BP, x: number, y: number, z: number, w: number, h: number, color: string)
	bp:box(
		w,
		h,
		0.6,
		x,
		y,
		z,
		{ c = color, m = "Neon", lod = "detail", col = false, tag = "glow", jitter = 0, fxColor = color, t = 0.35 }
	)
	bp:light(x, y, z - 3, color, 30, 1.6, "crystal")
end

local function grotto(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "frostpeak_grotto")
	Env.clear(env, c.x, c.z, 30)
	local b = Kit.build(ctx, "grottoMouth", "cave", c.x, c.z, c.rot)
	local bp = b.bp
	-- the ice wall behind the mouth and the hole
	bp:box(34, 22, 10, 0, 8, 8, o(Props.glacier, "shell", { q = true }))
	bp:rbox(14, 26, 12, -18, 8, 10, 0, 10, 0, o(Props.darkStone, "shell", { q = true }))
	bp:rbox(14, 24, 12, 18, 7, 10, 0, -10, 0, o(Props.darkStone, "shell", { q = true }))
	bp:add("ball", 14, 13, 2, 0, 5.6, 3.4, 0, 0, 0, o(Kit.dark, "shell", { q = false }))
	glowInside(bp, 0, 5, 4.2, 9, 8, Props.CRYSTAL)
	Props.snowCap(bp, 0, 19.4, 8, 32, 9, "shell")
	-- fangs of icicles over the mouth
	for k = -5, 5 do
		local l = if math.abs(k) <= 1 then 10 + (k + 1) % 2 * 2 else 4 + (5 - math.abs(k)) * 1.2
		local w = 1 + l * 0.08
		bp:add(
			"wedge",
			w,
			l,
			w,
			k * 1.4,
			13 - l / 2,
			2.6,
			180,
			0,
			0,
			o(Props.ice, if math.abs(k) <= 1 then "shell" else "detail", { col = false, q = false, t = 0.15 })
		)
	end
	-- the bed of furs and bones on the threshold, tracks leading in
	bp:add("ball", 6, 1, 4, 5, Kit.gy(ctx, b, 5, -4) + 0.3, -4, 0, 20, 0, o(Props.yetiFur, "detail", { col = false }))
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	Kit.bones(bp, -5, 0, -5, 6, ground)
	Props.tracks(bp, ground, -2, -24, 0, 8, 2.4, 3)
	Props.tracks(bp, ground, 3, -24, 0, 10, 0.9, 2)
	Kit.lifeAt(ctx, b, "icicleDust", 0, 12, 1)
	table.insert(out, b)
end

local function hold(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "frostpeak_hold")
	Env.clear(env, c.x, c.z, 30)
	local b = Kit.build(ctx, "holdGate", "cave", c.x, c.z, c.rot)
	local bp = b.bp
	-- the gate front in the glacier: an arch between two towers buried to their battlements
	for _, side in { -1, 1 } do
		bp:box(9, 20, 9, side * 11, 8, 4, o(Props.frostStone, "shell", { q = true }))
		for m = -1, 1 do
			bp:box(2.4, 2.4, 9.4, side * 11 + m * 3, 19, 4, o(Props.frostStone, "detail", { col = false }))
		end
		Props.snowCap(bp, side * 11, 20.6, 4, 9, 9, "fine")
		Props.torch(bp, side * 7, 6, -0.6)
		Props.banner(bp, side * 7.4, 9, -0.8, 6, Props.orderDark, Props.orderPale, true)
	end
	bp:box(13, 5, 9, 0, 13.4, 4, o(Props.frostStone, "shell", { q = true }))
	bp:box(10, 11, 1, 0, 5.4, 5, o(Kit.dark, "shell", { q = false }))
	glowInside(bp, 0, 4, 6, 6, 6, Props.EYES)
	-- ice over everything, icicles from the arch
	bp:box(36, 10, 12, 0, 21, 8, o(Props.glacier, "shell", { q = false }))
	Props.icicles(bp, 0, 10.8, -0.6, 12, 12, 4)
	-- the torn iron doors frozen beside the gate
	bp:rbox(5.4, 10, 0.8, -14, Kit.gy(ctx, b, -14, -8) + 1, -8, 76, 20, 0, o(Props.iron, "shell", { q = false }))
	bp:rbox(5.4, 10, 0.8, 13, Kit.gy(ctx, b, 13, -10) + 2.6, -10, 62, -30, 10, o(Props.iron, "detail", { col = false }))
	bp:rbox(7, 1, 3, -14, Kit.gy(ctx, b, -14, -8) + 0.3, -8, 0, 20, 0, o(Props.ice, "fine", { col = false, t = 0.3 }))
	Kit.lifeAt(ctx, b, "icicleDust", 0, 10, -1)
	table.insert(out, b)
end

local function heart(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "frostpeak_cave")
	Env.clear(env, c.x, c.z, 34)
	local b = Kit.build(ctx, "glacierMouth", "cave", c.x, c.z, c.rot)
	local bp = b.bp
	-- the cleft deep in the glacier: walls of ice narrowing inwards, crystals glowing from the depth
	for _, side in { -1, 1 } do
		bp:rbox(4, 20, 30, side * 11, 8, 10, 0, side * 8, 0, o(Props.glacier, "shell", { q = true }))
		for k = 0, 3 do
			bp:rbox(
				5,
				6 + k,
				5,
				side * (12 + k),
				14 + k * 1.5,
				-2 + k * 7,
				10,
				k * 30,
				side * 14,
				o(Props.ice, "detail", { col = false, t = 0.15 })
			)
		end
		Props.crystals(bp, side * 6, 0, 14, 1.3, "detail", false)
		Props.icicles(bp, side * 8, 17, -4, 6, 5, 5)
	end
	bp:box(16, 14, 1, 0, 6, 22, o(Kit.dark, "shell", { q = false }))
	Props.crystals(bp, 0, 0, 18, 2, "shell", false)
	glowInside(bp, 0, 7, 21, 10, 10, Props.CRYSTAL)
	-- the threshold: scales and frozen bones, rime
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	Kit.bones(bp, -4, 0, -6, 7, ground)
	for k = 1, 10 do
		local lx, lz = bp.rng:float(-8, 8), bp.rng:float(-14, 4)
		bp:rbox(
			1.2,
			0.12,
			1.6,
			lx,
			ground(lx, lz) + 0.08,
			lz,
			0,
			k * 37,
			0,
			o(Props.wyrmScale, "fine", { col = false })
		)
	end
	Kit.lifeAt(ctx, b, "icicleDust", 0, 14, 4)
	table.insert(out, b)
end

function Mouths.all(env: Env.Env, out: { Build })
	grotto(env, out)
	hold(env, out)
	heart(env, out)
end

return Mouths
