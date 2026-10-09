--!strict
-- Cultist Barrow (31-38) dressing (S49): inside a burial mound taken by the cult.
--   1 the dromos: the exit under a dolmen, a fresh offering (a dead crow on a flat stone ringed with candles), rags
--     on strings, chalk spirals,
--   2 the Rite Circle (cultists): nine menhirs underground round the room (none by a group or a corridor mouth), the
--     rite circle's mosaic with violet fire in a shallow bowl, hooks with robes, a drum, bowls of ash,
--   3 the Burial Chamber (ghouls): niches in three tiers with shrouds, stone coffins with broken lids, dragged-out
--     shrouds and gnawed bones, ghoul holes through the walls, stubs of the cult's candles,
--   4 the Heart of the Barrow (Elite II, "wow"): the sacrificial altar on its dais in the apse, the horned idol behind
--     it with violet fire in its eyes and hands, the black pool, chains from the vault, banners, candles on the
--     steps, snake sheds,
--   5 the Ghoul Den: heaps of dug-up bones and skulls, half-eaten bodies in shrouds, clawed walls,
--   6 the Flooded Crypt (snakes): half-sunk sarcophagi in the black water ring and the nave, snake sheds, a nest of
--     eggs in rotten reeds. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Barrow = {}

type Build = Kit.Build
type Env = Kit.Env

local VIOLET = "#B455FF"
local CULT = { c = "#2A1F33", m = "Fabric" }
local CULT2 = { c = "#3A2A4A", m = "Fabric" }
local STONE = { c = "#4E4B4E", m = "Slate" }
local SHROUD = { c = "#C8BEA8", m = "Fabric" }
local CHALK = { c = "#E8E4DA", m = "SmoothPlastic" }

local function ground(env: Env, b: Build): (number, number) -> number
	return function(lx: number, lz: number): number
		return Kit.gy(env, b, lx, lz)
	end
end

local function violetCandles(bp: Kit.BP, x: number, y: number, z: number, n: number)
	Kit.candles(bp, x, y, z, n, VIOLET)
end

local function dromos(env: Env, out: { Build })
	local r = env.T.rooms[1]
	local d = Kit.build(env, "Dolmen", "landmark", -204, 0, 90)
	local bp = d.bp
	for _, s in { -1, 1 } do
		bp:rbox(4, 14, 3, s * 7, 6, 2, 0, 0, s * 3, o(STONE, "shell", { q = false }))
	end
	bp:box(18, 3, 4, 0, 14.4, 2, o(STONE, "shell", { q = false }))
	table.insert(out, d)
	-- the fresh offering, rags, chalk spirals
	local b = Kit.build(env, "FreshOffering", "traces", r.x + 6, r.z - 14, 0)
	local ob = b.bp
	local y = Kit.gy(env, b, 0, 0)
	ob:box(4, 1, 3, 0, y + 0.5, 0, o(STONE, "detail", { col = false }))
	ob:add(
		"ball",
		1.2,
		0.7,
		1.6,
		0,
		y + 1.3,
		0,
		0,
		30,
		0,
		o({ c = "#16161A", m = "SmoothPlastic" }, "fine", { col = false })
	)
	violetCandles(ob, 0, y + 1, 0, 5)
	for k = -2, 2 do
		ob:box(0.06, 0.06, 6, k * 3, y + 6, 6, o(Kit.rope, "fine", { col = false }))
		ob:box(0.8, 1.6, 0.08, k * 3, y + 5, 6, o(CULT2, "fine", { col = false }))
	end
	for k = 0, 2 do
		ob:add(
			"cyl",
			0.04,
			4 + k * 2,
			4 + k * 2,
			8,
			y + 0.04 + k * 0.01,
			4,
			0,
			0,
			90,
			o(CHALK, "fine", { col = false, t = 0.6 })
		)
	end
	table.insert(out, b)
end

local function ritual(env: Env, out: { Build })
	local r = env.T.rooms[2]
	local b = Kit.build(env, "RiteCircle", "landmark", r.x, r.z, 0)
	local bp = b.bp
	local g = ground(env, b)
	-- the fire in the shallow bowl in the middle (no collision)
	bp:add("cyl", 0.8, 5, 5, 0, g(0, 0) + 0.4, 0, 0, 0, 90, o(STONE, "detail", { col = false }))
	Kit.fire(bp, 0, g(0, 0) + 0.9, 0, 2.2, VIOLET, "detail")
	table.insert(out, b)
	-- nine menhirs round the room
	local n = 0
	for k = 0, 8 do
		local a = k * 2 * math.pi / 9 + 0.2
		local x, z = Kit.spot(env, r, a, 4, 2.5)
		if x and z then
			n += 1
			local m = Kit.build(env, `Menhir_{n}`, "landmark", x, z, math.deg(-a))
			local my = Kit.gy(env, m, 0, 0)
			m.bp:rbox(3, 10, 2, 0, my + 4.4, 0, 3, 0, -3, o(STONE, "shell", { q = false }))
			violetCandles(m.bp, 0, my + 9.6, 0, 2)
			m.bp:box(
				1,
				1.4,
				0.1,
				0,
				my + 6,
				-1.06,
				{ c = VIOLET, m = "Neon", lod = "detail", col = false, tag = "glow", jitter = 0, fxColor = VIOLET }
			)
			Kit.clear(env, x, z, 3)
			table.insert(out, m)
		end
	end
	-- hooks with robes, the drum, bowls of ash
	local hx, hz = Kit.spot(env, r, math.rad(250), 3, 2, false)
	if hx and hz then
		local h = Kit.build(env, "CultRobes", "traces", hx, hz, 0)
		local hy = Kit.gy(env, h, 0, 0)
		for k = -1, 1 do
			h.bp:box(1.6, 5, 0.3, k * 2, hy + 4, 0, o(CULT, "detail", { col = false }))
		end
		h.bp:add("cyl", 2, 3, 3, 5, hy + 1, 2, 0, 0, 90, o(Kit.hide, "detail", { col = false }))
		table.insert(out, h)
	end
end

-- Shelves of niches (T.niches): frames with shrouds and skulls inside.
local function niches(env: Env, out: { Build }, roomIndex: number, shrouds: boolean, name: string)
	local list = env.T.niches()
	local b: Build? = nil
	local n = 0
	for _, p in list do
		if p.room == roomIndex then
			local bb = b
			if not bb then
				local r = env.T.rooms[roomIndex]
				bb = Kit.build(env, name, "traces", r.x, r.z, 0)
				b = bb
			end
			local build = bb :: Build
			n += 1
			local lx, lz = p.x - build.at.x, p.z - build.at.z
			local fy = Kit.gy(env, build, lx, lz)
			build.bp:push(lx, fy, lz, 0, p.yaw, 0)
			for t = 0, p.tiers - 1 do
				local y = 1.6 + t * (p.h + 0.6)
				build.bp:box(p.w + 0.6, 0.5, 2.6, 0, y - 0.3, 1.2, o(STONE, "detail", { col = false }))
				build.bp:box(p.w, p.h, 0.3, 0, y + p.h / 2, 2.4, o(Kit.dark, "fine", { col = false }))
				if shrouds then
					build.bp:box(p.w * 0.8, p.h * 0.4, 1.8, 0, y + p.h * 0.2, 1.2, o(SHROUD, "fine", { col = false }))
				end
				if (n + t) % 2 == 0 then
					Kit.skull(build.bp, 0, y, 0.8, 1.1, 180)
				end
			end
			build.bp:pop()
		end
	end
	if b then
		table.insert(out, b :: Build)
	end
end

local function burial(env: Env, out: { Build })
	local r = env.T.rooms[3]
	niches(env, out, 3, true, "BurialNiches")
	-- coffins with broken lids, gnawed bones, ghoul holes, candle stubs
	for k, a in { 30, 120, 210, 300 } do
		local x, z = Kit.spot(env, r, math.rad(a), 5, 3.5)
		if x and z then
			local c = Kit.build(env, `Coffin_{k}`, "traces", x, z, a + 90)
			local cy = Kit.gy(env, c, 0, 0)
			c.bp:box(3, 2, 7, 0, cy + 1, 0, o(STONE, "shell", { q = false }))
			c.bp:rbox(3.2, 0.5, 3.4, 1.6, cy + 1.2, 2, 0, 20, 30, o(STONE, "detail", { col = false }))
			c.bp:rbox(3.2, 0.5, 3.6, -2.4, cy + 0.3, -1, 0, -15, 8, o(STONE, "detail", { col = false }))
			Kit.bones(c.bp, 3, 0, -4, 5, ground(env, c))
			Kit.candles(c.bp, -2, cy, 4, 2)
			Kit.clear(env, x, z, 5)
			table.insert(out, c)
		end
	end
	local h = Kit.build(env, "GhoulHoles", "traces", r.x, r.z, 0)
	for k = 0, 2 do
		local a = k * 2.1 + 1
		local x, z = Kit.wallSpot(env, r, a, 1)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			h.bp:add(
				"ball",
				5,
				4,
				1.4,
				lx,
				Kit.gy(env, h, lx, lz) + 2,
				lz,
				0,
				math.deg(-a) + 90,
				0,
				o(Kit.dark, "detail", { col = false })
			)
			h.bp:add(
				"ball",
				6,
				0.8,
				4,
				lx * 0.92,
				Kit.gy(env, h, lx * 0.92, lz * 0.92) + 0.2,
				lz * 0.92,
				0,
				0,
				0,
				o({ c = "#5A4A38", m = "Ground" }, "fine", { col = false })
			)
		end
	end
	table.insert(out, h)
end

local function heart(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- the altar on the dais (188, 50), the idol behind it, the black pool (200, 50)
	local b = Kit.build(env, "BarrowAltar", "landmark", 188, 50, 270)
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	bp:box(6, 3, 3.4, 0, y + 1.5, 0, o(STONE, "shell", { q = false }))
	bp:box(6.4, 0.3, 3.8, 0, y + 3.1, 0, o({ c = "#5A1A1A", m = "SmoothPlastic" }, "fine", { col = false }))
	-- the horned idol with outstretched arms
	local iy = Kit.gy(env, b, 0, 9)
	bp:box(5, 14, 3, 0, iy + 7, 9, o(STONE, "shell", { q = false }))
	bp:add("ball", 4, 4.4, 3.4, 0, iy + 16, 9, 0, 0, 0, o(STONE, "detail", { col = false }))
	for _, s in { -1, 1 } do
		bp:beam(s * 1.6, iy + 17.4, 9, s * 4, iy + 21, 9.4, 0.7, o(Kit.bone, "detail", { col = false }))
		bp:beam(s * 2.4, iy + 11, 9, s * 7, iy + 13, 8, 1, o(STONE, "detail", { col = false }))
		Kit.fire(bp, s * 7.4, iy + 13.6, 8, 0.8, VIOLET, "detail")
		bp:box(
			0.8,
			0.6,
			0.2,
			s * 0.9,
			iy + 16.4,
			7.2,
			{ c = VIOLET, m = "Neon", lod = "detail", col = false, tag = "glow", jitter = 0, fxColor = VIOLET }
		)
	end
	bp:light(0, iy + 14, 6, VIOLET, 34, 1.8, "crystal")
	-- candles on the steps, chains from the vault, banners, snake sheds
	for k = 0, 2 do
		violetCandles(bp, -3 + k * 3, Kit.gy(env, b, -3 + k * 3, -6), -6, 3)
	end
	for _, s in { -1, 1 } do
		local top = (Kit.ceil(env, 188 + s * 6, 50) or 40) - b.at.y
		bp:box(
			0.25,
			math.max(2, top - y - 12),
			0.25,
			s * 6,
			(top + y + 12) / 2,
			0,
			o(Kit.iron, "fine", { col = false })
		)
		Kit.banner(bp, s * 9, Kit.gy(env, b, s * 9, 3), 3, 10, CULT2)
	end
	for k = 0, 2 do
		bp:rbox(
			2.4,
			0.08,
			0.5,
			-2 + k * 2,
			Kit.gy(env, b, -2 + k * 2, -9) + 0.05,
			-9,
			0,
			k * 50,
			0,
			o({ c = "#A8B85A", m = "SmoothPlastic" }, "fine", { col = false, t = 0.3 })
		)
	end
	Kit.clear(env, 188, 50, 12)
	table.insert(out, b)
	local _ = r
end

local function ghoulden(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "GhoulDen", "traces", r.x, r.z, 0)
	local g = ground(env, b)
	for k = 0, 4 do
		local a = k * 1.25 + 0.3
		local x, z = Kit.wallSpot(env, r, a, 5)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			b.bp:add(
				"ball",
				6,
				2,
				5,
				lx,
				g(lx, lz) + 0.4,
				lz,
				0,
				0,
				0,
				o({ c = "#5A4A38", m = "Ground" }, "detail", { col = false })
			)
			Kit.bones(b.bp, lx, 0, lz, 8, g)
			if k % 2 == 0 then
				b.bp:box(
					1.8,
					0.8,
					5,
					lx * 0.85,
					g(lx * 0.85, lz * 0.85) + 0.4,
					lz * 0.85,
					o(SHROUD, "fine", { col = false })
				)
			end
			Kit.glowCap(b.bp, lx * 0.9 + 1, g(lx * 0.9, lz * 0.9), lz * 0.9, 0.4, "#C9E86B", k == 2, "fine")
		end
	end
	table.insert(out, b)
end

local function flooded(env: Env, out: { Build })
	local r = env.T.rooms[6]
	local b = Kit.build(env, "FloodedCrypt", "traces", r.x, r.z, 0)
	local bp = b.bp
	-- half-sunk sarcophagi in the ring of black water and the nave, snake sheds on them
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.4
		local d = 46 + (k % 2) * 6
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		local wx, wz = r.x + lx, r.z + lz
		local liquid = env.T.liquid(wx, wz)
		if liquid then
			local level = liquid.level - b.at.y
			bp:rbox(3, 2.4, 7, lx, level - 0.4, lz, 6, math.deg(-a), 0, o(STONE, "detail", { col = false }))
			bp:rbox(
				2.2,
				0.08,
				0.5,
				lx,
				level + 0.85,
				lz,
				0,
				k * 30,
				0,
				o({ c = "#A8B85A", m = "SmoothPlastic" }, "fine", { col = false, t = 0.3 })
			)
			violetCandles(bp, lx, level + 0.8, lz + 2, 2)
		end
	end
	-- the nave (-69, 170)
	local nx, nz = -69 - r.x, 172 - r.z
	for k = -1, 1 do
		local liquid = env.T.liquid(-69 + k * 6, 172)
		local level = (if liquid then liquid.level else -4) - b.at.y
		bp:box(3.4, 2.4, 8, nx + k * 6, level - 0.2, nz, o(STONE, "detail", { col = false }))
	end
	-- the nest of eggs in rotten reeds (a dry corner by the causeway)
	local ex, ez = Kit.spot(env, r, math.rad(250), 6, 2, false)
	if ex and ez then
		local lx, lz = ex - r.x, ez - r.z
		local y = Kit.gy(env, b, lx, lz)
		bp:add("ball", 4, 1, 4, lx, y + 0.3, lz, 0, 0, 0, o({ c = "#5A5030", m = "Grass" }, "detail", { col = false }))
		for k = 0, 4 do
			bp:add(
				"ball",
				0.8,
				1,
				0.8,
				lx + math.cos(k * 1.3) * 0.9,
				y + 0.8,
				lz + math.sin(k * 1.3) * 0.9,
				0,
				0,
				0,
				o(CHALK, "fine", { col = false })
			)
		end
	end
	table.insert(out, b)
	Kit.life(env.ctx, "drips", r.x, 14, r.z, 30)
end

function Barrow.all(env: Env, out: { Build })
	dromos(env, out)
	ritual(env, out)
	burial(env, out)
	heart(env, out)
	ghoulden(env, out)
	flooded(env, out)
end

-- Exposed for the crypt (the same shelves of niches).
Barrow.niches = niches

return Barrow
