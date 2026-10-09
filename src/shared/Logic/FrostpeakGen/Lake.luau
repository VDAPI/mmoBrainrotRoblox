--!strict
-- Frozen Lake (82–90, loot) (S47): a great sheet of ice with cracks, frozen reeds sticking out of the snow ashore.
--   * the ice hole with the frozen boat (the landmark): a boat locked into the ice, a broken mast, nets stiff with
--     ice, a fisherman's sledge and rods,
--   * the Frozen Falls: a cascade of ice columns and icicles down the South Ridge's cliff, cracked ice and dark water
--     at its foot,
--   * the elementals' garden of crystals growing out of the ice (they pulse at night), rings of perfectly smooth ice,
--     boulders split by frost; mammoth trails across the ice; things locked in blocks of ice (chests, a shield,
--     a sword). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local Shapes = require("../../Data/Terrain")

local o = Kit.o

local Lake = {}

type Build = Kit.Build

local SHAPE = Shapes.byMap.frostpeak

local function boat(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "frozenBoat", "landmark", 14)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	-- the hull sunk to its gunwales in the ice, tilted
	bp:push(0, y - 0.6, 0, 0, 0, 8)
	bp:box(4.4, 1.6, 12, 0, 0.4, 0, o(Props.oldWood, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:rbox(0.5, 1.8, 12, side * 2.3, 0.8, 0, 0, 0, side * -12, o(Props.oldWood, "detail", { col = false }))
	end
	bp:rbox(3, 1.8, 3, 0, 0.6, -6.6, 0, 45, 0, o(Props.oldWood, "detail", { col = false }))
	bp:add("cyl", 6, 0.6, 0.6, 0, 3, 1, 0, 0, 90, o(Props.oldWood, "detail", { col = false }))
	bp:rbox(0.5, 5, 0.5, 0.6, 3.2, 4.6, 64, 0, 10, o(Props.oldWood, "detail", { col = false })) -- the broken top
	bp:rbox(5, 2.4, 0.15, 1.8, 1.6, 2, 0, 0, -20, o({ c = "#8C9AA4", m = "Fabric" }, "fine", { col = false, t = 0.3 }))
	Props.snowCap(bp, 0, 1.4, -2, 3.4, 6, "fine")
	bp:pop()
	-- the sledge, rods and a bucket by the hole
	bp:box(2.4, 0.4, 5, -7, y + 0.6, -6, o(Props.oldWood, "detail", { col = false }))
	for k = 0, 2 do
		bp:rbox(0.12, 4, 0.12, -4 + k * 1.2, y + 1.6, -9, 30, k * 10, 0, o(Props.oldWood, "fine", { col = false }))
	end
	bp:add("cyl", 1.2, 1.2, 1.2, -5.6, y + 0.6, -3, 0, 0, 90, o(Props.iron, "fine", { col = false }))
	Kit.lifeAt(ctx, b, "steam", -6, 0.5, 10)
	table.insert(out, b)
end

local function falls(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.frozenFalls
	Env.clear(env, s.x, s.z, 26)
	-- the falls hang on the cliff north of the site: ice columns from the crest down to the pool
	local b = Kit.build(ctx, "frozenFalls", "landmark", s.x, s.z, 0)
	local bp = b.bp
	local rng = bp.rng
	local foot = Kit.gy(ctx, b, 0, 8)
	for k = -6, 6 do
		local lx = k * 1.9 + rng:float(-0.4, 0.4)
		local lz = -10
		local top = Kit.gy(ctx, b, lx, lz - 22)
		local h = math.max(8, top - foot)
		local w = rng:float(1.4, 2.6)
		bp:add(
			"cyl",
			h,
			w,
			w,
			lx,
			foot + h / 2,
			lz + math.abs(k) * 0.4,
			0,
			rng:float(0, 90),
			90,
			o(
				Props.ice,
				if math.abs(k) <= 2 then "shell" else "detail",
				{ col = math.abs(k) <= 2, q = false, t = 0.15 }
			)
		)
		Props.icicles(bp, lx, foot + h * rng:float(0.5, 0.9), lz + 1.6, 2, 3, 4)
	end
	-- cracked ice and dark water at the foot, a pile of ice blocks
	for _ = 1, 8 do
		local lx, lz = rng:float(-10, 10), rng:float(-6, 8)
		bp:rbox(
			rng:float(2, 4),
			1,
			rng:float(2, 4),
			lx,
			Kit.gy(ctx, b, lx, lz) + 0.3,
			lz,
			rng:float(-14, 14),
			rng:float(0, 180),
			rng:float(-14, 14),
			o(Props.glacier, "detail", { col = false })
		)
	end
	bp:add(
		"cyl",
		0.1,
		8,
		8,
		0,
		Kit.gy(ctx, b, 0, 0) + 0.06,
		0,
		0,
		0,
		90,
		o({ c = "#1E3A52", m = "Glass" }, "detail", { col = false, t = 0.1 })
	)
	Kit.lifeAt(ctx, b, "icicleDust", 0, 16, -8)
	Kit.lifeAt(ctx, b, "steam", 0, 1, 0)
	table.insert(out, b)
end

local function crystals(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.crystals
	Env.clear(env, s.x, s.z, 30)
	local rng = Kit.build(ctx, "crystals", "glow", s.x, s.z, 0)
	local bp = rng.bp
	local r = bp.rng
	for k = 0, 8 do
		local a = k * 0.7 + r:float(-0.2, 0.2)
		local d = if k == 0 then 0 else 6 + k * 2
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		Props.crystals(
			bp,
			lx,
			Kit.gy(ctx, rng, lx, lz),
			lz,
			if k == 0 then 1.8 else r:float(0.7, 1.3),
			"shell",
			k % 3 == 0
		)
	end
	-- rings of perfectly smooth ice
	for k = 1, 3 do
		bp:add(
			"cyl",
			0.06,
			10 + k * 6,
			10 + k * 6,
			0,
			Kit.gy(ctx, rng, 0, 0) + 0.04 * k,
			0,
			0,
			0,
			90,
			o({ c = "#E4F6FF", m = "Glass" }, "fine", { col = false, t = 0.5 })
		)
	end
	table.insert(out, rng)
	-- more crystals along the shore of the lake (east lobe) and a frost-split boulder
	local lake = (SHAPE.frozenLakes :: { any })[1]
	for i, f in { { 0.55, -0.3 }, { -0.4, 0.5 }, { 0.2, 0.62 } } do
		local lobe = lake.lobes[2]
		local x, z = lobe.x + f[1] * lobe.rx, lobe.z + f[2] * lobe.rz
		if Env.isClear(env, x, z, 6) then
			local cb = Kit.build(ctx, `LakeCrystals_{i}`, "glow", x, z, i * 70)
			Props.crystals(cb.bp, 0, Kit.gy(ctx, cb, 0, 0), 0, 1, "shell", true)
			Env.clear(env, x, z, 8)
			table.insert(out, cb)
		end
	end
end

local function hoard(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "iceHoard", "landmark", 18)
	local bp = b.bp
	for k, inner in { "chest", "shield", "sword", "coins", "chest" } do
		local a = k * 1.25
		local lx, lz = math.cos(a) * 9, math.sin(a) * 9
		Props.iceBlock(bp, lx, Kit.gy(ctx, b, lx, lz) - 1, lz, 1 + (k % 2) * 0.3, inner, k * 40)
	end
	table.insert(out, b)
end

-- A wide trail of mammoth tracks across the ice; frozen reeds along the shores.
local function trails(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Kit.build(ctx, "MammothTrail", "traces", 230, 690, 0)
	local bp = b.bp
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	for k = 0, 2 do
		Props.tracks(bp, ground, -70 + k * 4, -20 + k * 5, 70, 22, 3, 6)
	end
	table.insert(out, b)
end

function Lake.all(env: Env.Env, out: { Build })
	boat(env, out)
	falls(env, out)
	crystals(env, out)
	hoard(env, out)
	trails(env, out)
end

return Lake
