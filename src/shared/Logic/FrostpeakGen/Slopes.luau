--!strict
-- Yeti Slopes (74–80, fast EXP) (S47): snowy benches with steep steps and dark outcrops.
--   * the Yeti's Den (the landmark): a niche under a rock overhang (a slab in the shell) with a bed of furs and
--     branches, a heap of gnawed bones, an uprooted pine as a club, huge hand prints on the rock,
--   * smaller burrows in the steps with steam from inside, heaps of throwing boulders, giant footprints,
--   * the avalanche cone at the mouth of the gully: a heap of snow blocks and broken trunks (now and then a powder
--     avalanche slides down it on the client). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Slopes = {}

type Build = Kit.Build

local function yetiDen(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "yetiDen", "landmark", 24)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	-- the rock behind and the overhang over the niche (the opening faces the front, -Z)
	bp:rbox(30, 18, 12, 0, y + 7, 9, 4, 0, -2, o(Props.darkStone, "shell", { q = true }))
	bp:rbox(26, 3.4, 14, 0, y + 12.4, -1, -8, 0, 3, o(Props.slate, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:rbox(5, 12, 7, side * 12, y + 5, 0, 0, side * 10, side * -4, o(Props.darkStone, "shell", { q = true }))
	end
	Props.snowCap(bp, 0, y + 14.6, 0, 26, 12, "shell")
	Props.icicles(bp, 0, y + 10.6, -7.6, 24, 16, 4)
	bp:box(18, 9, 0.5, 0, y + 4.4, 3, o(Kit.dark, "detail", { col = false, t = 0.15 }))
	-- the bed of furs and branches, bones, the club
	bp:add("ball", 9, 1.6, 6, 0, y + 0.5, 0, 0, 0, 0, o(Props.yetiFur, "detail", { col = false }))
	for k = 1, 6 do
		bp:rbox(4, 0.4, 0.4, -3 + k, y + 0.9, -1 + (k % 3), 0, k * 31, 6, o(Props.frozenWood, "fine", { col = false }))
	end
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	Kit.bones(bp, 6, 0, -6, 8, ground)
	Kit.bones(bp, -7, 0, -8, 6, ground)
	bp:add("cyl", 14, 1.4, 1.4, -10, ground(-10, -6) + 0.8, -6, 0, 70, 6, o(Props.frozenWood, "shell", { q = false }))
	for k = 0, 4 do
		local a = k * 1.25
		bp:beam(
			-17,
			ground(-17, -8) + 1,
			-8,
			-17 + math.cos(a) * 3,
			ground(-17, -8) + 2 + math.sin(a),
			-8 + math.sin(a) * 3,
			0.4,
			o(Props.oldWood, "fine", { col = false })
		)
	end
	-- giant hand prints on the rock face
	for k = 0, 2 do
		bp:box(2.4, 2.8, 0.12, -8 + k * 7, y + 8 + (k % 2), 2.7, o(Props.slate, "fine", { col = false }))
	end
	Props.tracks(bp, ground, 0, -10, 180, 8, 2.4, 4.2)
	Kit.lifeAt(ctx, b, "steam", 0, 2, 2)
	table.insert(out, b)
end

-- Small burrows in the benches' steps with a breath of steam, footprints and throwing stones.
local function burrows(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in { { -420, -470, 0 }, { -160, -470, 0 }, { -380, -606, 0 }, { -60, -606, 0 } } do
		local x, z = p[1], p[2]
		if Env.isClear(env, x, z, 4) then
			Env.clear(env, x, z, 8)
			local b = Kit.build(ctx, `YetiBurrow_{i}`, "traces", x, z, 180)
			local bp = b.bp
			local y = Kit.gy(ctx, b, 0, 0)
			bp:rbox(9, 6, 6, 0, y + 2, 2, 6, 0, 0, o(Props.darkStone, "shell", { q = false }))
			bp:box(4, 3.4, 0.4, 0, y + 1.6, -1.2, o(Kit.dark, "detail", { col = false }))
			Props.snowCap(bp, 0, y + 5, 2, 8, 5)
			Props.icicles(bp, 0, y + 3.6, -1.4, 5, 6, 1.4)
			Kit.lifeAt(ctx, b, "steam", 0, 2, -1)
			table.insert(out, b)
		end
	end
end

local function boulders(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "yetiBoulders", "traces", 14)
	local bp = b.bp
	local rng = bp.rng
	for k = 1, 9 do
		local a = rng:float(0, math.pi * 2)
		local d = rng:float(0, 5)
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		Props.boulder(
			bp,
			lx,
			Kit.gy(ctx, b, lx, lz) + (if k > 6 then 2.4 else 0),
			lz,
			rng:float(2, 3.4),
			if k <= 4 then "shell" else "detail"
		)
	end
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	Props.tracks(bp, ground, 6, 4, 120, 7, 2.4, 4)
	table.insert(out, b)
end

local function avalanche(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "avalanche", "traces", 26)
	local bp = b.bp
	local rng = bp.rng
	for k = 1, 18 do
		local lx, lz = rng:float(-14, 14), rng:float(-10, 10)
		local s = rng:float(2, 4.6)
		bp:rbox(
			s,
			s * 0.7,
			s,
			lx,
			Kit.gy(ctx, b, lx, lz) + s * 0.25,
			lz,
			rng:float(-20, 20),
			rng:float(0, 180),
			rng:float(-20, 20),
			o(Props.snow, if k <= 6 then "shell" else "detail", { col = k <= 6, q = false })
		)
	end
	for _ = 1, 5 do
		local lx, lz = rng:float(-12, 12), rng:float(-8, 8)
		bp:add(
			"cyl",
			rng:float(8, 13),
			1.1,
			1.1,
			lx,
			Kit.gy(ctx, b, lx, lz) + 0.8,
			lz,
			rng:float(-10, 10),
			rng:float(0, 180),
			rng:float(-8, 8),
			o(Props.oldWood, "detail", { col = false })
		)
	end
	Kit.lifeAt(ctx, b, "avalanche", 0, 30, 40, 30)
	table.insert(out, b)
end

function Slopes.all(env: Env.Env, out: { Build })
	yetiDen(env, out)
	burrows(env, out)
	boulders(env, out)
	avalanche(env, out)
end

return Slopes
