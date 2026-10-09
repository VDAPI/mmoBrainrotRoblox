--!strict
-- Giants' Pass (78–86) (S47): a real pass between the North and the South Ridge, scree at the walls' feet.
--   * the Giants' Gate (the landmark): two colossal seated giants carved on the spurs either side of the road,
--     frosted; one lost its head, which lies in the snow by the road,
--   * the Hall of Thrones behind it: three stone thrones in a ring round the giants' fire (whole trunks, a spit with a
--     mammoth leg, a great cauldron), rune stones glowing like giants' eyes; a column of smoke seen from the Step,
--   * giant traces: mammoth bones, a field of boulders with craters from their throws, giant-sized steps cut into
--     a spur; harpy nests on the walls, feathers. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Pass = {}

type Build = Kit.Build

local function gate(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.giantsGate
	Env.clear(env, s.x, s.z, 20)
	-- the road runs west-east through the gate; the statues sit on the spurs' ends facing west (towards arrivals)
	for i, lz in { -80, 70 } do
		local x, z = s.x, s.z + lz
		Env.clear(env, x, z, 22)
		local b = Kit.build(ctx, if i == 1 then "giantsGate" else "GiantsGateSouth", "landmark", x, z, 90)
		Props.giantStatue(b.bp, 0, Kit.gy(ctx, b, -6, 0) - 1.5, 0, 1.8, 0, i == 2)
		table.insert(out, b)
	end
	-- the fallen head by the road
	local hb = Kit.build(ctx, "GiantsHead", "landmark", s.x - 18, s.z + 22, 70)
	local bp = hb.bp
	local y = Kit.gy(ctx, hb, 0, 0)
	bp:rbox(6.4, 7.4, 6.4, 0, y + 2.4, 0, 30, 0, 24, o(Props.frostStone, "shell", { q = false }))
	bp:rbox(5, 6, 2.6, 2.4, y + 1.2, -1, 30, 0, 24, o(Props.frostStone, "detail", { col = false }))
	Props.snowCap(bp, -1, y + 5.4, 0, 5, 5)
	Env.clear(env, s.x - 18, s.z + 22, 8)
	table.insert(out, hb)
end

local function thrones(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.thrones
	Env.clear(env, s.x, s.z, 30)
	local fire = Kit.build(ctx, "giantsFire", "camp", s.x, s.z, 0)
	local bp = fire.bp
	local y = Kit.gy(ctx, fire, 0, 0)
	-- whole trunks crossed, embers, a spit with a mammoth leg, a great cauldron
	for k = 0, 3 do
		bp:add("cyl", 12, 1.6, 1.6, 0, y + 0.9, 0, 0, k * 45, 10, o(Kit.charred, "shell", { q = false }))
	end
	bp:box(5, 1, 5, 0, y + 1.6, 0, { c = Kit.FIRE, m = "Neon", lod = "detail", col = false, tag = "fire", jitter = 0 })
	bp:light(0, y + 5, 0, Kit.FIRE, 40, 2.2, "fire")
	for _, side in { -1, 1 } do
		bp:rbox(1, 9, 1, side * 7, y + 3.6, 0, 0, 0, side * 12, o(Props.oldWood, "detail", { col = false }))
	end
	bp:add("cyl", 15, 0.6, 0.6, 0, y + 7.4, 0, 0, 0, 0, o(Props.iron, "detail", { col = false }))
	bp:add(
		"ball",
		3.4,
		2.4,
		6,
		0,
		y + 6.2,
		0,
		0,
		90,
		0,
		o({ c = "#7A3A2A", m = "SmoothPlastic" }, "detail", { col = false })
	)
	bp:add("cyl", 4, 7, 7, 8, Kit.gy(ctx, fire, 8, 6) + 2, 6, 0, 0, 90, o(Props.iron, "shell", { q = false }))
	bp:add(
		"cyl",
		0.3,
		6.2,
		6.2,
		8,
		Kit.gy(ctx, fire, 8, 6) + 4.1,
		6,
		0,
		0,
		90,
		o({ c = "#6A5A3A", m = "SmoothPlastic" }, "fine", { col = false })
	)
	Kit.lifeAt(ctx, fire, "smokeColumn", 0, 4, 0)
	Kit.lifeAt(ctx, fire, "steam", 8, 4.4, 6)
	table.insert(out, fire)
	-- three thrones in a ring facing the fire
	for k = 0, 2 do
		local a = k * 2 * math.pi / 3 + math.pi / 2
		local tx, tz = s.x + math.cos(a) * 20, s.z + math.sin(a) * 20
		local yaw = math.deg(math.atan2(math.cos(a), math.sin(a)))
		local t = Kit.build(ctx, if k == 0 then "thrones" else `Throne_{k}`, "landmark", tx, tz, yaw)
		local tb = t.bp
		local ty = Kit.gy(ctx, t, 0, 0)
		tb:box(10, 3, 8, 0, ty + 1.4, 0, o(Props.frostStone, "shell", { q = false }))
		tb:box(10, 14, 2.4, 0, ty + 8, 3.6, o(Props.frostStone, "shell", { q = false }))
		for _, side in { -1, 1 } do
			tb:box(1.8, 5, 7, side * 4.6, ty + 4.6, 0, o(Props.frostStone, "detail", { col = false }))
		end
		tb:add("ball", 6, 1, 5, 0, ty + 3.2, 0, 0, 0, 0, o(Props.mammothFur, "detail", { col = false }))
		Props.snowCap(tb, 0, ty + 15.2, 3.6, 10, 2.4)
		Env.clear(env, tx, tz, 8)
		table.insert(out, t)
	end
	-- rune stones round the hall like giants' eyes
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.3
		local rx, rz = s.x + math.cos(a) * 33, s.z + math.sin(a) * 33
		if env.T.roadDistance(rx, rz) > 8 then
			local rs = Kit.build(ctx, `RuneStone_{k}`, "glow", rx, rz, math.deg(math.atan2(math.cos(a), math.sin(a))))
			Props.runeStone(rs.bp, 0, Kit.gy(ctx, rs, 0, 0), 0, 9 + (k % 2) * 3, 0)
			Env.clear(env, rx, rz, 4)
			table.insert(out, rs)
		end
	end
	-- mammoth bones by the fire
	local mb = Kit.build(ctx, "GiantsMeal", "traces", s.x - 14, s.z - 22, 30)
	Props.mammothSkeleton(mb.bp, function(lx: number, lz: number): number
		return Kit.gy(ctx, mb, lx, lz)
	end, 0, 0, 0.7, 0)
	table.insert(out, mb)
end

local function boulderField(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "boulderField", "traces", 22)
	local bp = b.bp
	local rng = bp.rng
	for k = 1, 10 do
		local lx, lz = rng:float(-20, 20), rng:float(-16, 16)
		local s = rng:float(2.4, 5)
		Props.boulder(bp, lx, Kit.gy(ctx, b, lx, lz), lz, s, if k <= 5 then "shell" else "detail")
		-- a crater of thrown-up snow
		bp:add(
			"cyl",
			0.6,
			s * 3,
			s * 3,
			lx + s,
			Kit.gy(ctx, b, lx + s, lz) + 0.1,
			lz,
			0,
			0,
			90,
			o(Props.rime, "fine", { col = false })
		)
	end
	table.insert(out, b)
end

-- Giant-sized steps cut into the north spur and harpy nests on the ridges' walls.
local function walls(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local stairs = Kit.build(ctx, "GiantStairs", "landmark", 70, -150, 270)
	local bp = stairs.bp
	for k = 0, 5 do
		local lz = -k * 6
		bp:box(
			14,
			4,
			6,
			0,
			Kit.gy(ctx, stairs, 0, lz) - 1,
			lz,
			o(Props.frostStone, if k < 3 then "shell" else "detail", { q = false })
		)
	end
	Env.clear(env, 70, -150, 14)
	table.insert(out, stairs)
	for i, p in { { -40, -262, 34 }, { 150, -296, 40 }, { -100, 288, 30 }, { 200, 300, 36 } } do
		local x, z = p[1], p[2] + (if p[2] < 0 then 22 else -22)
		local nb = Kit.buildAt(`PassNest_{i}`, "ice", x, env.T.height(x, z) + 2, z, 0)
		local nbp = nb.bp
		for k = 1, 8 do
			local a = k * 0.8
			nbp:rbox(
				4,
				0.4,
				0.4,
				math.cos(a) * 1.8,
				0.4 + (k % 2) * 0.3,
				math.sin(a) * 1.8,
				0,
				math.deg(-a) + 90,
				8,
				o(Props.oldWood, "detail", { col = false })
			)
		end
		nbp:add("cyl", 0.6, 3.4, 3.4, 0, 0.2, 0, 0, 0, 90, o(Props.harpyFeather, "fine", { col = false }))
		Kit.lifeAt(ctx, nb, "harpyGlint", 0, 1, 0)
		table.insert(out, nb)
	end
end

function Pass.all(env: Env.Env, out: { Build })
	gate(env, out)
	thrones(env, out)
	boulderField(env, out)
	walls(env, out)
end

return Pass
