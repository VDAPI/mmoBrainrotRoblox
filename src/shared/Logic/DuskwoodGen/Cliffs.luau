--!strict
-- Blood Cliffs (40–45) (S45): red rock, ledges, overhangs, scree, thorns and a reddish haze.
--   * the Crypt Gate (the landmark and lure): a monumental gate carved in the rock over the mouth of the Crypt of the
--     Forgotten: a facade of red slabs (it also hides the grey border behind the mouth), niches with skulls, two
--     hooded figures, the iron doors ajar, cold blue flames,
--   * the black waterfall: a thin cascade of the Black Stream down the red rock,
--   * bats: overhangs with dark crevice nests and streaks of guano (bats hang under them, Controllers/
--     WorldLifeController), white bones of drained animals at the foot; witches' charms in the crevices. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local Structures = require("../WorldGen/Structures")

local o = Kit.o

local Cliffs = {}

type Build = Kit.Build

local RED = Kit.redRock
local RED_DARK = Kit.redRockDark
local GUANO = { c = "#7E7A70", m = "Slate" }

-- x of the scarp's edge at z (the plateau polygon's west side in Data/Terrain/duskwood).
local EDGE = { { -220, 626 }, { -142, 612 }, { -60, 606 }, { 40, 610 }, { 112, 604 }, { 172, 622 } }
local function edgeX(z: number): number
	for i = 1, #EDGE - 1 do
		local a, b = EDGE[i], EDGE[i + 1]
		if z >= a[1] and z <= b[1] then
			return a[2] + (b[2] - a[2]) * (z - a[1]) / (b[1] - a[1])
		end
	end
	return if z < EDGE[1][1] then EDGE[1][2] else EDGE[#EDGE][2]
end
Cliffs.edgeX = edgeX

local function cryptGate(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "cryptGate", "cryptGate", 30)
	local bp = b.bp
	local y0 = -1.5
	-- the facade of red rock with the dark gateway (the portal stands 6 studs in front of it)
	bp:box(56, 38, 28, 0, y0 + 19, -3, o(RED, "shell", { q = true }))
	bp:box(17, 21, 1, 0, y0 + 10.5, -17.4, o(Kit.dark, "shell", { q = false }))
	bp:box(22, 4, 4, 0, y0 + 23, -18.6, o(RED_DARK, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:box(3, 24, 3, side * 10, y0 + 12, -18.4, o(RED_DARK, "detail", { col = false }))
		-- the iron doors, one ajar
		bp:push(side * 8.4, y0, -17.6, 0, if side > 0 then -38 else 4, 0)
		bp:box(8, 19, 0.6, -side * 4, 9.5, 0, o(Kit.iron, "detail", { col = false }))
		for k = 0, 3 do
			bp:box(8.1, 0.4, 0.7, -side * 4, 3 + k * 4.4, 0, o({ c = "#2A2826", m = "CorrodedMetal" }, "fine"))
		end
		bp:pop()
		-- niches with skulls
		for k = 0, 2 do
			local nx, ny = side * 15, y0 + 9 + k * 7
			bp:box(2.6, 2.6, 1, nx, ny, -17.2, o(Kit.dark, "detail", { col = false }))
			Kit.skull(bp, nx, ny - 1, -17.4, 1.4)
		end
		-- the hooded figures on their plinths
		local fx, fz = side * 21, -21
		bp:box(5, 2.4, 5, fx, y0 + 1.2, fz, o(RED_DARK, "shell", { q = true }))
		bp:add(
			"cyl",
			12,
			4.2,
			4.2,
			fx,
			y0 + 8.4,
			fz,
			0,
			0,
			90,
			o({ c = "#3A3438", m = "Slate" }, "shell", { q = true })
		)
		bp:add(
			"ball",
			4.4,
			4.8,
			4.4,
			fx,
			y0 + 15.6,
			fz + 0.3,
			0,
			0,
			0,
			o({ c = "#3A3438", m = "Slate" }, "shell", { q = false })
		)
		bp:box(2.2, 2.4, 1, fx, y0 + 15.2, fz - 1.8, o(Kit.dark, "detail", { col = false }))
		bp:rbox(
			0.8,
			9,
			0.5,
			fx - side * 0.6,
			y0 + 7.6,
			fz - 2.4,
			0,
			0,
			side * 6,
			o(Kit.iron, "detail", { col = false })
		)
		bp:box(2.6, 1, 1.2, fx, y0 + 10.6, fz - 2.2, o({ c = "#3A3438", m = "Slate" }, "detail", { col = false }))
		-- cold blue flames in braziers
		local bx, bz = side * 7.5, -27
		bp:add("cyl", 4, 1.6, 1.6, bx, y0 + 2, bz, 0, 0, 90, o(RED_DARK, "detail", { col = false }))
		bp:add("cyl", 0.8, 3, 3, bx, y0 + 4.2, bz, 0, 0, 90, o(Kit.iron, "detail", { col = false }))
		Kit.fire(bp, bx, y0 + 4.8, bz, 1.6, Kit.COLD, "detail")
		-- wing walls framing the courtyard
		bp:rbox(4, 20, 18, side * 30, y0 + 9, -14, 0, side * 24, side * 3, o(RED_DARK, "shell", { q = true }))
	end
	-- the overhang above the gate, bats under it
	bp:rbox(30, 3, 14, 0, y0 + 39, -16, 6, 0, 0, o(RED_DARK, "shell", { q = false }))
	for k = -2, 2 do
		Kit.lifeAt(ctx, b, "batRoost", k * 5, y0 + 36.6, -18, 4)
		bp:box(0.6, 3, 0.3, k * 6 + 1, y0 + 35, -17.25, o(GUANO, "fine", { col = false }))
	end
	Kit.rect(ctx, "cliff", b.at.x + 2, b.at.z, 28, 56, b.at.rot)
	table.insert(out, b)
end

-- Overhangs along the scarp: a jutting slab with crevice nests, guano and bats under it.
local OVERHANGS = { { -40, 18 }, { 72, 16 }, { -192, 14 } }

local function overhangs(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in OVERHANGS do
		local z = p[1]
		local x = edgeX(z)
		local top = env.T.height(x + 8, z)
		local b = Kit.buildAt(`Overhang_{i}`, "cliff", x, top, z, 0)
		local bp = b.bp
		bp:rbox(9, 2.6, p[2], -1.5, -0.6, 0, 0, 0, -6, o(RED_DARK, "shell", { q = false }))
		for k = 0, 4 do
			local cz = -p[2] / 2 + 2 + k * (p[2] - 4) / 4
			bp:box(0.6, bp.rng:float(2, 4), 1.4, -3.2, -4 - (k % 2) * 2.4, cz, o(Kit.dark, "detail", { col = false }))
			bp:box(0.4, bp.rng:float(4, 8), 0.9, -3.4, -7 - (k % 2), cz + 1.2, o(GUANO, "detail", { col = false }))
			Kit.lifeAt(ctx, b, "batRoost", -4, -2.4, cz, 3)
		end
		Props.charm(bp, -5.4, -2, p[2] / 2 - 2, i % 2 == 0)
		-- bleached bones at the foot
		local footX = x - 12
		local foot = Kit.buildAt(`BatBones_{i}`, "traces", footX, env.T.height(footX, z), z, i * 50)
		Kit.bones(foot.bp, 0, 0, 0, 6)
		Kit.bones(foot.bp, 3, 0, 2, 4)
		table.insert(out, b)
		table.insert(out, foot)
	end
end

-- Scree at the foot of the scarp (red boulders, shell).
local SCREE = { -260, -100, 92, 150, -176, 18 }

local function scree(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, z in SCREE do
		local x = edgeX(z) - 9
		if env.T.roadDistance(x, z) > 8 and env.T.streamDistance(x, z) > 6 then
			Env.clear(env, x, z, 9)
			local b = Kit.build(ctx, `Scree_{i}`, "rocks", x, z, i * 41)
			Kit.rock(b.bp, 0, -0.8, 0, 6, RED, "shell")
			Kit.rock(b.bp, 4, Kit.gy(ctx, b, 4, 3) - 0.5, 3, 4, RED_DARK, "shell")
			for k = 1, 5 do
				local a = k * 1.3
				local lx, lz = math.cos(a) * 6, math.sin(a) * 6
				Kit.rock(b.bp, lx, Kit.gy(ctx, b, lx, lz) - 0.3, lz, 1.6, RED, "detail")
			end
			table.insert(out, b)
		end
	end
end

function Cliffs.all(env: Env.Env, out: { Build })
	cryptGate(env, out)
	overhangs(env, out)
	scree(env, out)
	Structures.waterfall(env.ctx, env.T, out, 2, 1, RED, "#4E5A66")
	Env.clear(env, env.sites.blackFall.x, env.sites.blackFall.z, 14)
	local ctx = env.ctx
	for _, p in { { 690, -110 }, { 700, 90 }, { 660, -250 } } do
		Kit.life(ctx, "bats", p[1], env.T.height(p[1], p[2]) + 8, p[2], 60)
	end
	Kit.life(ctx, "mist", 600, env.T.height(590, -140), -140, 20)
end

return Cliffs
