--!strict
-- Cave mouths of the Frost Peaks (S47), built where Data/Areas/frostpeak puts the entrances (the layout adds the
-- portal, the sign with the cave's name and levels, and the map icon):
--   * the Ice Grotto: a hole in an ice wall on the Yeti Slopes' top bench, fangs of icicles over it (the biggest
--     8-12 studs), a blue glow from inside (crystals beside the arch and one light), yeti and wolf tracks leading in,
--     a bed of furs and bones on the threshold,
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

local function grotto(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "frostpeak_grotto")
	Env.clear(env, c.x, c.z, 30)
	local b = Kit.build(ctx, "grottoMouth", "cave", c.x, c.z, c.rot)
	b.frames = "frostpeak_frostpeak_grotto"
	local bp = b.bp
	-- the ice wall behind the mouth and the hole; W28: the hole as wide and tall as the portal's arch in front of it
	-- (14 x 13 before, the fangs hung down to its middle). W31 (Studio review: light purple on pale ice): the wall
	-- behind the arch's depth, the dark hole straight behind the arch (Kit.portalHole) in a dark oval mouth in the ice,
	-- the blue glow only from crystals beside the arch (the glowing slab behind the veil washed it out)
	bp:box(34, 28, 10, 0, 11, 9.3, o(Props.glacier, "shell", { q = true }))
	bp:rbox(14, 26, 12, -18, 8, 10, 0, 10, 0, o(Props.darkStone, "shell", { q = true }))
	bp:rbox(14, 24, 12, 18, 7, 10, 0, -10, 0, o(Props.darkStone, "shell", { q = true }))
	Kit.portalHole(bp)
	bp:add("ball", 22, 24, 0.2, 0, 8, 4.25, 0, 0, 0, o(Kit.dark, "shell", { q = false }))
	for _, side in { -1, 1 } do
		Props.crystals(bp, side * 9.8, 0, 5.4, 0.7, "detail", false)
	end
	bp:light(0, 9, 5.5, Props.CRYSTAL, 30, 1.6, "crystal")
	Props.snowCap(bp, 0, 25.4, 8, 32, 9, "shell")
	-- fangs of icicles over the mouth, over the arch (W31: their tips half a stud clear of the painted arch)
	for k = -5, 5 do
		local l = if math.abs(k) <= 1 then 3.4 + (k + 1) % 2 * 0.4 else 1.4 + (5 - math.abs(k)) * 0.5
		local w = 1 + l * 0.08
		bp:add(
			"wedge",
			w,
			l,
			w,
			k * 1.4,
			22.6 - l / 2,
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
	Kit.lifeAt(ctx, b, "icicleDust", 0, 20, 1)
	table.insert(out, b)
end

local function hold(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "frostpeak_hold")
	Env.clear(env, c.x, c.z, 30)
	local b = Kit.build(ctx, "holdGate", "cave", c.x, c.z, c.rot)
	b.frames = "frostpeak_frostpeak_hold"
	local bp = b.bp
	-- the gate front in the glacier: an arch between two towers buried to their battlements; W28: the gateway as wide
	-- and tall as the portal's arch standing in it (13 x 11 before: the towers and the arch cut through the portal).
	-- W31: the gate's lintel just over the painted arch, the gateway walled up with frost stone behind the arch's depth
	-- and the dark passage straight behind the arch (Kit.portalHole), the banners clear of the arch
	for _, side in { -1, 1 } do
		bp:box(9, 26, 9, side * 13.5, 11, 4, o(Props.frostStone, "shell", { q = true }))
		for m = -1, 1 do
			bp:box(2.4, 2.4, 9.4, side * 13.5 + m * 3, 25, 4, o(Props.frostStone, "detail", { col = false }))
		end
		Props.snowCap(bp, side * 13.5, 26.6, 4, 9, 9, "fine")
		Props.torch(bp, side * 10, 6, -0.6)
		Props.banner(bp, if side < 0 then -13 else 11.4, 9, -0.8, 6, Props.orderDark, Props.orderPale, true)
	end
	bp:box(18, 5, 9, 0, 21.2, 4, o(Props.frostStone, "shell", { q = true }))
	bp:box(18, 21, 1, 0, 9.5, 5.4, o(Props.frostStone, "shell", { q = false }))
	Kit.portalHole(bp)
	bp:light(0, 8, 6, Props.EYES, 26, 1.2, "crystal")
	-- ice over everything, icicles from the arch (over the portal's arch)
	bp:box(42, 10, 12, 0, 30, 8, o(Props.glacier, "shell", { q = false }))
	Props.icicles(bp, 0, 18.7, -0.6, 14, 12, 0.4)
	-- the torn iron doors frozen beside the gate
	bp:rbox(5.4, 10, 0.8, -14, Kit.gy(ctx, b, -14, -8) + 1, -8, 76, 20, 0, o(Props.iron, "shell", { q = false }))
	bp:rbox(5.4, 10, 0.8, 13, Kit.gy(ctx, b, 13, -10) + 2.6, -10, 62, -30, 10, o(Props.iron, "detail", { col = false }))
	bp:rbox(7, 1, 3, -14, Kit.gy(ctx, b, -14, -8) + 0.3, -8, 0, 20, 0, o(Props.ice, "fine", { col = false, t = 0.3 }))
	Kit.lifeAt(ctx, b, "icicleDust", 0, 19, -1)
	table.insert(out, b)
end

local function heart(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "frostpeak_cave")
	Env.clear(env, c.x, c.z, 34)
	local b = Kit.build(ctx, "glacierMouth", "cave", c.x, c.z, c.rot)
	b.frames = "frostpeak_frostpeak_cave"
	local bp = b.bp
	-- the cleft deep in the glacier: walls of ice narrowing inwards, crystals glowing from the depth. W31 (Studio review:
	-- a slab hid the painted pillar, the dark hole stood 22 studs deep and looked off the veil, light purple on pale
	-- ice): the walls open towards the path (their front ends stood 6.9 off the axis, before the pillars), the icicles
	-- hang from the walls' tops beside the arch, the dark hole straight behind the arch (Kit.portalHole) and the
	-- crystals glow in the cleft beside it
	for _, side in { -1, 1 } do
		bp:rbox(4, 20, 30, side * 11, 8, 10, 0, -side * 8, 0, o(Props.glacier, "shell", { q = true }))
		for k = 0, 3 do
			bp:rbox(
				5,
				6 + k,
				5,
				side * (13 + k),
				14 + k * 1.5,
				-2 + k * 7,
				10,
				k * 30,
				side * 14,
				o(Props.ice, "detail", { col = false, t = 0.15 })
			)
		end
		Props.crystals(bp, side * 9.6, 0, 6, 1.1, "detail", false)
		Props.icicles(bp, side * 11.5, 18, -2, 3, 4, 5)
	end
	Kit.portalHole(bp)
	bp:box(18, 18, 1, 0, 8, 22, o(Kit.dark, "shell", { q = false }))
	Props.crystals(bp, 0, 0, 18, 2, "shell", false)
	bp:light(0, 8, 6, Props.CRYSTAL, 30, 1.6, "crystal")
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
