--!strict
-- Heart of the Forest (26–33, fast EXP) (S45): a hollow around the Elder Tree.
--   * the Elder Tree: a colossal rotting tree split in two (trunk ~20 studs across, 45 tall, dead branches to 60),
--     bark peeling, its crown nearly dead, the crack between the halves glowing with fungi (a shallow niche, the
--     lure), root arms along the root ridges of the terrain,
--   * giant mushrooms ringing the hollow's rim, glowing bracket fungi, rot pools bubbling on the floor, spores,
--   * ent traces: craters of torn-out roots, furrows, trees pushed aside; ghoul burrows with heaps of earth and
--     bones on the hollow's edge. Pure.

local Env = require("./Env")
local Flora = require("../WorldGen/Flora")
local Kit = require("../WorldGen/Kit")

local o = Kit.o

local Heart = {}

type Build = Kit.Build

local BARK = { c = "#3E3428", m = "Wood" }
local ROT = { c = "#4A3E30", m = "Wood" }
local GLOW = "#8CFFB0"

local function glowFungus(bp: Kit.BP, x: number, y: number, z: number, s: number, yaw: number)
	bp:rbox(1.8 * s, 0.4 * s, 1.2 * s, x, y, z, 0, yaw, 0, {
		c = GLOW,
		m = "SmoothPlastic",
		lod = "detail",
		col = false,
		tag = "lamp",
		jitter = 0.04,
		fxColor = GLOW,
	})
end

local function elderTree(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "elderTree", "elderTree", 30)
	local bp = b.bp
	local H = 46
	-- two halves of the split trunk, leaning apart
	for _, side in { -1, 1 } do
		bp:add("cyl", H, 11.5, 11.5, side * 4.8, H / 2 - 2, 0, 0, 0, 90 + side * 3.5, o(BARK, "shell", { q = true }))
		-- peeling bark plates (detail) and bracket fungi
		for k = 1, 8 do
			local a = k * 0.8 + (if side > 0 then 0 else math.pi)
			local y = 4 + k * 4.6
			bp:rbox(
				3.2,
				4.4,
				0.6,
				side * 4.8 + math.cos(a) * 5.9,
				y,
				math.sin(a) * 5.9,
				bp.rng:float(-12, 12),
				-math.deg(a) + 90,
				bp.rng:float(-20, 20),
				o(ROT, "detail", { col = false })
			)
			if k % 2 == 0 then
				glowFungus(
					bp,
					side * 4.8 + math.cos(a + 0.4) * 6.2,
					y + 1.2,
					math.sin(a + 0.4) * 6.2,
					1.3,
					-math.deg(a)
				)
			end
		end
	end
	-- the glowing crack between the halves (a shallow niche)
	bp:box(3, 22, 6, 0, 11, -1.2, o(Kit.dark, "detail", { col = false }))
	for k = 0, 6 do
		glowFungus(bp, bp.rng:float(-1, 1), 2 + k * 2.8, -3.8 + bp.rng:float(-0.4, 0.4), 0.9, k * 50)
	end
	bp:light(0, 6, -5, GLOW, 22, 1.2, "lamp")
	-- dead branches and the last of the crown
	for i, d in { { -1, 1, 0.4 }, { 1, 1, -0.3 }, { -1, -1, -0.6 }, { 1, -1, 0.7 } } do
		local sx, sz = d[1], d[2]
		local ex, ey, ez = sx * 20, H + 12 + i * 2, sz * 14 + d[3] * 6
		bp:beam(sx * 4.8, H - 6, 0, ex, ey, ez, 3.2, o(BARK, if i <= 2 then "shell" else "detail", { col = false }))
		bp:beam(ex, ey, ez, ex + sx * 8, ey + 5, ez - sz * 4, 1.4, o(BARK, "detail", { col = false }))
		bp:beam(ex * 0.6, ey - 6, ez * 0.6, ex * 0.6 + sz * 7, ey + 1, ez * 0.6 + sx * 6, 1.2, o(BARK, "fine"))
	end
	bp:add(
		"ball",
		22,
		9,
		18,
		-6,
		H + 8,
		4,
		0,
		0,
		0,
		o({ c = "#3E4426", m = "LeafyGrass" }, "shell", { col = false, q = false })
	)
	bp:add(
		"ball",
		14,
		6,
		14,
		12,
		H + 14,
		-6,
		0,
		0,
		0,
		o({ c = "#4A4A2A", m = "LeafyGrass" }, "detail", { col = false })
	)
	-- root arms along the terrain's root ridges
	for i, a in { 20, 95, 160, 230, 300 } do
		local r = math.rad(a)
		local c, s = math.cos(r), math.sin(r)
		bp:beam(
			c * 5,
			5,
			s * 5,
			c * 26,
			Kit.gy(ctx, b, c * 26, s * 26) + 1,
			s * 26,
			4.2,
			o(BARK, "shell", { q = false })
		)
		bp:beam(
			c * 26,
			Kit.gy(ctx, b, c * 26, s * 26) + 1,
			s * 26,
			c * 44,
			Kit.gy(ctx, b, c * 44, s * 44) - 0.4,
			s * 44,
			2.6,
			o(BARK, "detail", { col = false })
		)
		if i % 2 == 1 then
			glowFungus(bp, c * 18, Kit.gy(ctx, b, c * 18, s * 18) + 3.4, s * 18, 1, a)
		end
	end
	Kit.circle(ctx, "elderTree", b.at.x, b.at.z, 12)
	Kit.lifeAt(ctx, b, "spores", 0, 10, 0, 40)
	Kit.lifeAt(ctx, b, "spores", 30, 4, 40, 30)
	Kit.lifeAt(ctx, b, "perch", 20, H + 14, 6)
	table.insert(out, b)
end

-- Giant mushrooms on the hollow's rim (where the ground is dry and off the paths).
local function mushrooms(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local tree = env.sites.elderTree
	local n = 0
	for i = 0, 15 do
		local a = i * 2 * math.pi / 16 + 0.13
		local r = 118 + (i % 3) * 9
		local x, z = tree.x + math.cos(a) * r, tree.z + math.sin(a) * r
		if
			env.T.roadDistance(x, z) > 10
			and not env.T.isWater(x, z)
			and env.T.slope(x, z, 3) < 0.6
			and Env.isClear(env, x, z, 4)
		then
			n += 1
			Env.clear(env, x, z, 8)
			local b = Kit.build(ctx, `GiantMushroom_{n}`, "mushroom", x, z, i * 40)
			Flora.species.giantMushroom(b.bp, 0, 0, 0, 1.3 + (i % 4) * 0.15, true, ctx)
			if i % 2 == 0 then
				Flora.species.giantMushroom(b.bp, 4.5, Kit.gy(ctx, b, 4.5, 3), 3, 0.7, false, ctx)
			end
			table.insert(out, b)
		end
	end
end

-- Ent craters (torn-out roots, furrows, trees pushed aside) and ghoul burrows on the edge.
local CRATERS = { { 52, 282 }, { 252, 452 }, { 92, 500 } }
local BURROWS = { { -6, 360 }, { 300, 330 }, { 196, 520 }, { 40, 230 } }

local function traces(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in CRATERS do
		Env.clear(env, p[1], p[2], 12)
		local b = Kit.build(ctx, `EntCrater_{i}`, "traces", p[1], p[2], i * 70)
		local bp = b.bp
		for k = 0, 9 do
			local a = k * math.pi / 5
			local lx, lz = math.cos(a) * 5.5, math.sin(a) * 5.5
			bp:add(
				"ball",
				3.4,
				1.6,
				3.4,
				lx,
				Kit.gy(ctx, b, lx, lz) + 0.2,
				lz,
				0,
				0,
				0,
				o({ c = "#30281E", m = "Ground" }, "detail", { col = false })
			)
		end
		bp:add("ball", 8, 1, 8, 0, Kit.gy(ctx, b, 0, 0) - 0.3, 0, 0, 0, 0, o(Kit.dark, "detail", { col = false }))
		for k = 1, 4 do
			local a = k * 1.6
			bp:beam(
				math.cos(a) * 2,
				Kit.gy(ctx, b, 0, 0),
				math.sin(a) * 2,
				math.cos(a) * 6,
				Kit.gy(ctx, b, 0, 0) + 4,
				math.sin(a) * 6,
				0.9,
				o(Kit.darkBark, if k == 1 then "shell" else "detail", { col = false })
			)
		end
		-- a furrow and a tree pushed over
		bp:rbox(
			2.4,
			0.6,
			26,
			0,
			Kit.gy(ctx, b, 0, -18) + 0.1,
			-18,
			0,
			10,
			0,
			o({ c = "#2A2219", m = "Ground" }, "detail", { col = false })
		)
		local ty = Kit.gy(ctx, b, 9, 6)
		bp:add("cyl", 18, 2.4, 2.4, 9, ty + 6.4, 6, 0, 30, 52, o(Kit.blackBark, "shell", { q = false }))
		table.insert(out, b)
	end
	for i, p in BURROWS do
		Env.clear(env, p[1], p[2], 9)
		local b = Kit.build(ctx, `GhoulBurrow_{i}`, "traces", p[1], p[2], i * 90)
		local bp = b.bp
		bp:add("ball", 9, 4, 7, 2, -0.6, 3, 0, 0, 0, o({ c = "#3A3026", m = "Ground" }, "shell", { q = false }))
		bp:add("ball", 4, 2.4, 3, 0, 0.2, -1.4, 0, 0, 0, o(Kit.dark, "detail", { col = false }))
		Kit.bones(bp, -3, Kit.gy(ctx, b, -3, -4), -4, 5)
		Kit.bones(bp, 3, Kit.gy(ctx, b, 3, -5), -5, 3)
		table.insert(out, b)
	end
end

-- Bubbles in the rot pools (client fx) and wisps over them.
local function pools(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local tree = env.sites.elderTree
	local n = 0
	for i = 0, 23 do
		local a = i * 2.39996
		local r = 24 + i * 3.2
		local x, z = tree.x + math.cos(a) * r, tree.z + 32 + math.sin(a) * r * 0.7
		local w = env.T.water(x, z)
		if w and n < 6 then
			n += 1
			local b = Kit.buildAt(`RotPool_{n}`, "pool", x, w, z, i * 30)
			b.bp:add("cyl", 0.2, 3.6, 3.6, 0, 0.05, 0, 0, 0, 90, {
				c = "#5A6A2A",
				m = "SmoothPlastic",
				lod = "detail",
				col = false,
				t = 0.3,
				tag = "bubbles",
				jitter = 0,
				fxColor = "#9AB04A",
			})
			table.insert(out, b)
			Kit.life(ctx, "wisp", x, w + 3, z, 10)
		end
	end
end

function Heart.all(env: Env.Env, out: { Build })
	elderTree(env, out)
	traces(env, out)
	mushrooms(env, out)
	pools(env, out)
	Kit.life(env.ctx, "mist", 150, -6, 400, 50)
	Kit.life(env.ctx, "mist", 90, -4, 330, 34)
end

return Heart
