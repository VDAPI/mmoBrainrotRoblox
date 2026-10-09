--!strict
-- Wyrm Spire (94–100) (S47): the highest horn of the land, the wind tearing a plume of snow off its summit (seen from
-- the whole map); a plateau at its foot with ice spikes and wind-scoured snow.
--   * the Wyrm's Skeleton (the landmark): the spine of a giant wyrm coiled round a rock, ribs arching over the Bone
--     Trail, the skull on a ledge,
--   * wyrm burrows: round smooth holes in icy scarps with furrows of scales round them (shallow, blind; rims in the
--     shell), shed scales, serpentine ruts in the snow,
--   * the dragonspawn's obelisk to the wyrms with a navy and gold banner. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Wyrm = {}

type Build = Kit.Build

local function bones(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.wyrmBones
	Env.clear(env, s.x, s.z, 30)
	local b = Kit.build(ctx, "wyrmBones", "landmark", s.x, s.z, s.rot)
	local bp = b.bp
	local ground = function(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	-- the rock the spine coils round (north of the trail; local +X = north at rot 90)
	local rx, rz = 20, 4
	bp:rbox(12, 14, 12, rx, ground(rx, rz) + 5, rz, 6, 30, -4, o(Props.darkStone, "shell", { q = false }))
	Props.snowCap(bp, rx, ground(rx, rz) + 12.4, rz, 10, 10)
	-- the spine: a coil round the rock, then over the trail
	local prev: { number }? = nil
	for k = 0, 22 do
		local a = k * 0.42
		local r = 10 + k * 0.4
		local lx, lz = rx + math.cos(a) * r, rz + math.sin(a) * r
		local ly = ground(lx, lz) + 1.6 + math.sin(k * 0.5) * 0.8
		bp:add(
			"ball",
			2.6,
			2.2,
			2.6,
			lx,
			ly,
			lz,
			0,
			math.deg(a),
			0,
			o(Kit.oldBone, if k % 3 == 0 then "shell" else "detail", { col = false, q = false })
		)
		local p = prev
		if p then
			bp:beam(p[1], p[2], p[3], lx, ly, lz, 1, o(Kit.bone, "fine", { col = false }))
		end
		prev = { lx, ly, lz }
	end
	-- ribs arching over the trail (local Z along the trail, the trail at local X = 0)
	for k = -4, 4 do
		local lz = k * 4.4
		local h = 22 - math.abs(k) * 1.6
		for _, side in { -1, 1 } do
			local x0 = side * 9
			local g = ground(x0, lz)
			bp:beam(
				x0,
				g - 0.5,
				lz,
				side * 7,
				g + h * 0.7,
				lz,
				1,
				o(Kit.oldBone, "shell", { col = math.abs(k) == 4, q = false })
			)
			bp:beam(side * 7, g + h * 0.7, lz, side * 1.4, g + h, lz, 0.8, o(Kit.bone, "detail", { col = false }))
		end
	end
	-- the skull on a ledge south of the trail
	local sx, sz = -18, -10
	local sy = ground(sx, sz)
	bp:rbox(9, 5, 9, sx, sy + 1.6, sz, 0, 20, 0, o(Props.darkStone, "shell", { q = false }))
	bp:add("ball", 7, 5, 11, sx, sy + 6, sz, 0, 20, 0, o(Kit.oldBone, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:rbox(1.6, 1.6, 0.4, sx + side * 2, sy + 7, sz - 5.2, 0, 20, 0, o(Kit.dark, "fine", { col = false }))
		bp:beam(
			sx + side * 2.4,
			sy + 8,
			sz + 3,
			sx + side * 4.6,
			sy + 11,
			sz + 8,
			0.7,
			o(Props.tusk, "detail", { col = false })
		)
	end
	-- shed scales
	for k = 1, 12 do
		local lx, lz = bp.rng:float(-24, 24), bp.rng:float(-18, 18)
		bp:rbox(
			1.2,
			0.12,
			1.6,
			lx,
			ground(lx, lz) + 0.08,
			lz,
			0,
			k * 33,
			0,
			o(Props.wyrmScale, "fine", { col = false })
		)
	end
	Kit.lifeAt(ctx, b, "eagles", 0, 60, 0, 80)
	table.insert(out, b)
end

local function burrows(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.wyrmBurrows
	Env.clear(env, s.x, s.z, 22)
	for i = 0, 2 do
		local x, z = s.x + i * 26 - 26, s.z + (i % 2) * 14
		local b = Kit.build(ctx, if i == 0 then "wyrmBurrows" else `WyrmBurrow_{i}`, "traces", x, z, s.rot + i * 20)
		local bp = b.bp
		local y = Kit.gy(ctx, b, 0, 0)
		-- an icy scarp with a round, smooth hole
		bp:rbox(18, 12, 8, 0, y + 4, 4, 6, 0, 0, o(Props.glacier, "shell", { q = false }))
		bp:add("cyl", 1, 8, 8, 0, y + 4.6, -0.2, 0, 90, 0, o(Kit.dark, "detail", { col = false }))
		bp:add("cyl", 1.2, 9.6, 9.6, 0, y + 4.6, 0.2, 0, 90, 0, o(Props.ice, "shell", { q = false, t = 0.2 }))
		-- furrows of scales round it, ruts in the snow
		for m = 0, 5 do
			local a = m * math.pi / 3
			bp:rbox(
				5,
				0.3,
				0.4,
				math.cos(a) * 5.6,
				y + 4.6 + math.sin(a) * 5.6,
				-0.3,
				0,
				0,
				math.deg(a) + 90,
				o(Props.glacier, "fine", { col = false })
			)
		end
		for m = 0, 6 do
			local lz = -4 - m * 3
			bp:rbox(
				2.4,
				0.1,
				3.4,
				math.sin(m * 0.8) * 3,
				Kit.gy(ctx, b, math.sin(m * 0.8) * 3, lz) + 0.06,
				lz,
				0,
				math.cos(m * 0.8) * 30,
				0,
				o(Props.trackColor, "fine", { col = false })
			)
		end
		Props.snowCap(bp, 0, y + 10.4, 4, 16, 7)
		table.insert(out, b)
	end
end

local function obelisk(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "wyrmObelisk", "landmark", 8)
	local bp = b.bp
	local y = Kit.gy(ctx, b, 0, 0)
	bp:box(5, 2, 5, 0, y + 0.6, 0, o(Props.darkStone, "shell", { q = false }))
	bp:box(3, 16, 3, 0, y + 9, 0, o(Props.darkStone, "shell", { q = false }))
	bp:add("wedge", 3, 3, 3, 0, y + 18.4, 0, 0, 0, 0, o(Props.gold, "detail", { col = false }))
	bp:box(1.2, 4, 0.1, 0, y + 11, -1.56, {
		c = Props.ICEFIRE,
		m = "Neon",
		lod = "detail",
		col = false,
		tag = "glow",
		jitter = 0,
		fxColor = Props.ICEFIRE,
	})
	Props.banner(bp, 4, y, 0, 12, Props.cultBlue, Props.gold, false)
	table.insert(out, b)
end

-- The summit: the snow plume and the wind's roar (life points on the horn and on the ridges' crests).
local function plumes(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.summit
	Kit.life(ctx, "snowPlume", s.x, env.T.height(s.x, s.z) + 4, s.z, 3)
	for _, p in { { 60, -280 }, { -20, -292 }, { 150, 318 }, { -60, 300 }, { -420, 650 } } do
		local best, bx, bz = -math.huge, p[1], p[2]
		for dx = -12, 12, 4 do
			for dz = -12, 12, 4 do
				local h = env.T.height(p[1] + dx, p[2] + dz)
				if h > best then
					best, bx, bz = h, p[1] + dx, p[2] + dz
				end
			end
		end
		Kit.life(ctx, "snowPlume", bx, best + 2, bz, 1)
	end
	local _ = out
end

function Wyrm.all(env: Env.Env, out: { Build })
	bones(env, out)
	burrows(env, out)
	obelisk(env, out)
	plumes(env, out)
end

return Wyrm
