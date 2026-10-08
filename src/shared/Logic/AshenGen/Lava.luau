--!strict
-- Lava and the Golem Fields (52–60) (S46).
--   * glowing lava (client detail, tag "lava": the colour pulses): thin Neon plates over every river and bright pool,
--     dark crust floes drifting with the flow ("lavaCrust"), glowing veins over the cooling lakes, narrow glowing
--     strips in the glowing cracks ("ember"), lights every ~40 studs (tag "lava": only the nearest few are on,
--     Controllers/RegionLightController),
--   * the crater (its glow and smoke are seen from the whole map: shell parts), the lava fall from its lip (sheets
--     tagged "lavafall", sparks and smoke at the foot),
--   * the Sleeping Colossus (the landmark): a hill shaped like a lying golem with a head, a fist and shoulder plates,
--     its eyes and cracks glowing and slowly "breathing" ("glow"); smaller stone golems frozen mid-step,
--   * the field of basalt columns, obsidian shards by the lava, the imps' chimneys (fumaroles with sparks, nests of
--     charcoal, soot). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local TerrainLayers = require("../TerrainLayers")

local o = Kit.o

local Lava = {}

type Build = Kit.Build

local CHUNK = 64
local LIGHT_EVERY = 40

local function glow(t: number?, tag: string?, lod: string?): any
	return {
		c = Props.LAVA,
		m = "Neon",
		lod = lod or "detail",
		col = false,
		q = false,
		t = t or 0.3,
		tag = tag or "lava",
		jitter = 0,
	}
end

-- Chunked Builds of lava detail (one per 64-stud cell, frame at y = 0).
local function chunker(out: { Build }, prefix: string): (x: number, z: number) -> Build
	local chunks: { [string]: Build } = {}
	return function(x: number, z: number): Build
		local cx, cz = math.floor(x / CHUNK), math.floor(z / CHUNK)
		local key = `{cx}_{cz}`
		local found = chunks[key]
		if found then
			return found
		end
		local created = Kit.buildAt(`{prefix}_{key}`, "lava", (cx + 0.5) * CHUNK, 0, (cz + 0.5) * CHUNK, 0)
		chunks[key] = created
		table.insert(out, created)
		return created
	end
end

local function rivers(env: Env.Env, out: { Build })
	local T = env.T
	local chunk = chunker(out, "LavaRiver")
	local rivers = assert(T.shape.lava, "lava").rivers
	local lightIn = 0
	for i, river in rivers do
		local line = T.lavaLine(i)
		local s = 4
		while s < line.length - 2 do
			local x, z, dx, dz = TerrainLayers.pointAt(line, s)
			local level = T.lavaLevel(i, s)
			local b = chunk(x, z)
			local lx, lz = x - b.at.x, z - b.at.z
			local yaw = math.deg(math.atan2(dx, dz))
			local _, _, segI, t = TerrainLayers.nearest(line, x, z)
			local w = TerrainLayers.atSegment(river.widths, segI, t)
			local slope = T.lavaLevel(i, math.max(0, s - 4)) - T.lavaLevel(i, math.min(line.length, s + 4))
			local pitch = math.deg(math.atan(slope / 8))
			b.bp:rbox(w * 0.85, 0.2, 8.6, lx, level + 0.4, lz, pitch, yaw, 0, glow(0.3))
			if math.floor(s / 8) % 3 == 1 and pitch < 8 then
				b.bp:rbox(w * 0.3, 0.25, 2.4, lx + dz * w * 0.15, level + 0.55, lz - dx * w * 0.15, 0, yaw + 20, 0, {
					c = "#2A1A14",
					m = "Basalt",
					lod = "detail",
					col = false,
					q = false,
					tag = "lavaCrust",
					jitter = 0.1,
				})
			end
			lightIn -= 8
			if lightIn <= 0 then
				b.bp:light(lx, level + 4, lz, Props.LAVA, 34, 1.4, "lava")
				lightIn = LIGHT_EVERY
			end
			s += 8
		end
		-- obsidian shards on the banks
		local k = 0
		s = 10
		while s < line.length - 10 do
			local x, z, dx, dz = TerrainLayers.pointAt(line, s)
			k += 1
			local side = if k % 2 == 0 then 1 else -1
			local px, pz = x - dz * side * 11, z + dx * side * 11
			if T.roadDistance(px, pz) > 6 and not T.rockAt(px, pz) then
				local b = chunk(px, pz)
				Kit.rock(
					b.bp,
					px - b.at.x,
					T.height(px, pz) - 0.5,
					pz - b.at.z,
					1.2 + (k % 3) * 0.4,
					Props.obsidian,
					"detail"
				)
			end
			s += 22
		end
	end
end

local function pools(env: Env.Env, out: { Build })
	local T = env.T
	local chunk = chunker(out, "LavaPool")
	for i, p in assert(T.shape.lava, "lava").pools do
		local r = math.rad(p.rot)
		local c, sn = math.cos(r), math.sin(r)
		local function world(u: number, v: number): (number, number)
			return p.x + u * c - v * sn, p.z + u * sn + v * c
		end
		if p.crust then
			-- cooling lake: a few glowing veins and lights; the crust itself is terrain
			for k = 1, 6 do
				local a = k * 1.05 + i
				local x, z = world(math.cos(a) * p.rx * 0.45, math.sin(a) * p.rz * 0.45)
				if T.lava(x, z) then
					local b = chunk(x, z)
					b.bp:rbox(1.2, 0.2, 10, x - b.at.x, p.level + 0.3, z - b.at.z, 0, k * 47, 0, glow(0.2, "lava"))
				end
			end
			local b = chunk(p.x, p.z)
			b.bp:light(p.x - b.at.x, p.level + 5, p.z - b.at.z, Props.LAVA, 30, 1, "lava")
		else
			for u = -p.rx, p.rx, 10 do
				for v = -p.rz, p.rz, 10 do
					local x, z = world(u, v)
					if T.lava(x, z) and T.lavaDistance(x, z) < -3 then
						local b = chunk(x, z)
						b.bp:box(10.2, 0.2, 10.2, x - b.at.x, p.level + 0.4, z - b.at.z, glow(0.3))
						if (u + v) % 30 == 0 then
							b.bp:rbox(3.2, 0.3, 2.2, x - b.at.x + 2, p.level + 0.6, z - b.at.z, 0, u * 7, 0, {
								c = "#2A1A14",
								m = "Basalt",
								lod = "detail",
								col = false,
								q = false,
								tag = "lavaCrust",
								jitter = 0.1,
							})
						end
					end
				end
			end
			local b = chunk(p.x, p.z)
			b.bp:light(p.x - b.at.x, p.level + 6, p.z - b.at.z, Props.LAVA, 40, 1.6, "lava")
		end
		Kit.life(env.ctx, "lavaBubbles", p.x, p.level + 0.5, p.z, math.min(p.rx, p.rz) * 0.7)
		Kit.life(env.ctx, "haze", p.x, p.level + 1, p.z, math.min(p.rx, p.rz))
	end
end

-- Glowing strips at the bottom of the glowing cracks.
local function cracks(env: Env.Env, out: { Build })
	local T = env.T
	local chunk = chunker(out, "Cracks")
	local lightIn = 10
	for _, c in assert(T.shape.cracks, "cracks") do
		if c.glow then
			local line = TerrainLayers.line(TerrainLayers.pairs(c.points))
			local s = 3
			while s < line.length - 2 do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				local b = chunk(x, z)
				local y = T.height(x, z)
				b.bp:rbox(1.4, 0.3, 6.4, x - b.at.x, y + 0.2, z - b.at.z, 0, math.deg(math.atan2(dx, dz)), 0, {
					c = Props.EMBER,
					m = "Neon",
					lod = "detail",
					col = false,
					q = false,
					t = 0.15,
					tag = "ember",
					jitter = 0,
				})
				lightIn -= 6
				if lightIn <= 0 then
					b.bp:light(x - b.at.x, y + 3, z - b.at.z, Props.EMBER, 24, 1, "lava")
					lightIn = 46
				end
				s += 6
			end
			local mid = math.floor(#c.points / 4) * 2 + 1
			Kit.life(
				env.ctx,
				"embers",
				c.points[mid],
				T.height(c.points[mid], c.points[mid + 1]) + 0.5,
				c.points[mid + 1],
				6
			)
		end
	end
end

-- The crater's glow and smoke (shell: seen from afar) and the lava fall from its lip.
local function crater(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local T = env.T
	local s = env.sites.crater
	local pool = assert(T.shape.lava, "lava").pools[1]
	local b = Kit.buildAt("Crater", "vent", s.x, pool.level, s.z, 0)
	local bp = b.bp
	bp:add("ball", pool.rx * 1.6, 1.2, pool.rz * 1.6, 0, 0.6, 0, 0, 0, 0, glow(0.55, "vent", "shell"))
	bp:light(0, 10, 0, Props.LAVA, 60, 2.2, "lava")
	for k = 0, 9 do
		local a = k * math.pi / 5
		local lx, lz = math.cos(a) * (pool.rx + 14), math.sin(a) * (pool.rz + 14)
		Kit.rock(bp, lx, T.height(s.x + lx, s.z + lz) - pool.level - 0.4, lz, 2.6, Props.basalt, "detail")
	end
	Kit.life(ctx, "smokeColumn", s.x, pool.level + 4, s.z, 14)
	Kit.life(ctx, "embers", s.x, pool.level + 1, s.z, 16)
	Kit.lifeAt(ctx, b, "lavaBubbles", 0, 0.4, 0, 18)
	table.insert(out, b)

	-- the fall: from the lip down the crater's wall to the river below
	local fall = assert(T.shape.lava, "lava").falls[1]
	local line = T.lavaLine(1)
	local _, at = TerrainLayers.nearest(line, fall.x, fall.z)
	local top = T.lavaLevel(1, math.max(0, at - 10))
	local bottom = T.lavaLevel(1, math.min(line.length, at + 14))
	local tx, tz = TerrainLayers.pointAt(line, math.max(0, at - 10))
	local bx, bz = TerrainLayers.pointAt(line, math.min(line.length, at + 14))
	Env.clear(env, fall.x, fall.z, 16)
	local f = Kit.buildAt("Lavafall", "lavafall", bx, bottom, bz, fall.rot)
	local fp = f.bp
	local horiz = math.sqrt((tx - bx) ^ 2 + (tz - bz) ^ 2)
	local drop = top - bottom
	local tilt = math.deg(math.atan2(horiz, drop))
	local len = math.sqrt(horiz * horiz + drop * drop)
	for k = -1, 1 do
		fp:rbox(4.2 - math.abs(k) * 1.2, len, 0.6, k * 2.6, drop / 2 + 0.5, horiz / 2, tilt, 0, k * 4, {
			c = Props.LAVA,
			m = "Neon",
			lod = "shell",
			col = false,
			q = false,
			t = 0.15 + math.abs(k) * 0.15,
			tag = if k == 0 then "lavafall" else "lava",
			jitter = 0,
		})
	end
	fp:add("ball", 8, 1.4, 7, 0, 0.4, -2, 0, 0, 0, glow(0.35, "vent"))
	fp:light(0, 3, -2, Props.LAVA, 30, 1.6, "lava")
	Kit.life(ctx, "smoke", bx, bottom + 2, bz, 4)
	Kit.life(ctx, "haze", bx, bottom + 1, bz, 8)
	table.insert(out, f)
end

-- The Sleeping Colossus: head with glowing eyes, a fist, shoulder plates and glowing cracks on the hill's body.
local function colossus(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.colossus
	local b = Env.atSite(env, "colossus", "landmark", 50)
	local bp = b.bp
	local r = math.rad(s.rot)
	local c, sn = math.cos(r), math.sin(r)
	local function localOf(wx: number, wz: number): (number, number)
		local dx, dz = wx - s.x, wz - s.z
		return c * dx - sn * dz, sn * dx + c * dz
	end
	local function gy(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	local stone = { c = "#3A2A22", m = "Basalt" }
	-- the head: a block skull, a brow, eyes of fire
	local hx, hz = localOf(-143, 92)
	local hy = gy(hx, hz)
	-- the face looks east, at the road to the ruins
	bp:push(hx, hy - 1, hz, 0, 190, 8)
	bp:box(14, 11, 13, 0, 4, 0, o(stone, "shell", { q = false }))
	bp:box(15, 2.6, 3, 0, 8, -6.6, o(stone, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:box(3, 1.8, 0.6, side * 3.4, 5.8, -6.7, {
			c = Props.EMBER,
			m = "Neon",
			lod = "shell",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
	end
	bp:box(8, 1.4, 0.6, 0, 1.8, -6.7, o(Kit.dark, "detail", { col = false }))
	bp:light(0, 6, -10, Props.EMBER, 24, 1.2, "glow")
	bp:pop()
	-- the arm from the shoulder to the fist resting on the ground
	local fx, fz = localOf(-112, 190)
	local fy = gy(fx, fz)
	local sx, sz = localOf(-132, 118)
	local ex, ez = localOf(-116, 156)
	bp:beam(sx, gy(sx, sz) + 5, sz, ex, gy(ex, ez) + 4, ez, 6, o(stone, "shell", { q = false }))
	bp:beam(ex, gy(ex, ez) + 4, ez, fx, fy + 3, fz, 5, o(stone, "shell", { q = false }))
	bp:rbox(0.6, 0.3, 10, (sx + ex) / 2, gy((sx + ex) / 2, (sz + ez) / 2) + 8.2, (sz + ez) / 2, 0, 0, 0, {
		c = Props.EMBER,
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		tag = "glow",
		jitter = 0,
	})
	bp:rbox(9, 7, 8, fx, fy + 1.5, fz, 0, 20, 6, o(stone, "shell", { q = false }))
	for k = 0, 3 do
		bp:box(2, 2.2, 1.8, fx - 3 + k * 2, fy + 4, fz - 4, o(stone, "detail", { col = false }))
	end
	-- shoulder plates and glowing cracks along the back
	for k = -2, 2 do
		local lx = k * 14
		local y = gy(lx, -8)
		bp:rbox(
			10,
			2,
			7,
			lx,
			y + 0.4,
			-8,
			0,
			k * 6,
			-14,
			o(stone, if k % 2 == 0 then "shell" else "detail", { q = false })
		)
		bp:rbox(0.8, 0.3, 9, lx + 3, gy(lx + 3, 2) + 0.2, 2, 0, 30 + k * 20, 0, {
			c = Props.EMBER,
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
	end
	Kit.lifeAt(ctx, b, "haze", hx, hy + 4, hz, 6)
	table.insert(out, b)

	-- smaller stone golems frozen mid-step
	for i, p in { { -30, 130, 40 }, { 190, 290, 200 }, { 250, 60, 300 } } do
		Env.clear(env, p[1], p[2], 8)
		local g = Kit.build(ctx, `StoneGolem_{i}`, "statue", p[1], p[2], p[3])
		local gp = g.bp
		gp:rbox(1.8, 4, 1.8, -1.4, 2, 0.6, 14, 0, 0, o(stone, "detail", { col = false }))
		gp:rbox(1.8, 4, 1.8, 1.4, 2, -0.8, -20, 0, 0, o(stone, "detail", { col = false }))
		gp:rbox(5, 5, 3.4, 0, 6.2, 0, -8, 0, 0, o(stone, "shell", { q = false }))
		gp:box(2.4, 2.2, 2.2, 0, 9.6, -0.4, o(stone, "detail", { col = false }))
		gp:rbox(1.6, 5, 1.6, -3.4, 6, -1, -40, 0, 10, o(stone, "detail", { col = false }))
		gp:rbox(1.6, 5, 1.6, 3.4, 5.6, 0.6, 20, 0, -10, o(stone, "detail", { col = false }))
		gp:box(1.6, 0.4, 0.2, 0, 9.8, -1.55, {
			c = Props.EMBER,
			m = "Neon",
			lod = "fine",
			col = false,
			tag = "glow",
			jitter = 0,
		})
		table.insert(out, g)
	end
end

local function columns(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "basaltColumns", "rocks", 24)
	local bp = b.bp
	for k = 1, 18 do
		local a = k * 2.4
		local d = 3 + (k % 6) * 3
		local lx, lz = math.cos(a) * d, math.sin(a) * d
		local h = 2 + bp.rng:float(0, 9)
		bp:add(
			"cyl",
			h,
			3.2,
			3.2,
			lx,
			Kit.gy(ctx, b, lx, lz) + h / 2 - 0.4,
			lz,
			0,
			k * 30,
			90,
			o(Props.basalt, if h > 6 then "shell" else "detail", { q = false })
		)
	end
	table.insert(out, b)
end

-- The imps' chimneys: fumaroles of black rock with sparks and smoke, charcoal nests, soot on the stones.
local function chimneys(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in { { -10, 60 }, { -40, 200 }, { 232, 110 }, { 30, 330 } } do
		local x, z = p[1], p[2]
		Env.clear(env, x, z, 10)
		local b = Kit.build(ctx, if i == 1 then "impChimneys" else `ImpChimney_{i}`, "vent", x, z, i * 50)
		local bp = b.bp
		bp:add("cyl", 6, 4.6, 4.6, 0, 2.4, 0, 0, 0, 90, o(Props.basalt, "shell", { q = false }))
		bp:add("cyl", 3, 3, 3, 0, 6.4, 0, 0, 0, 90, o(Props.soot, "detail", { col = false }))
		bp:box(1.6, 0.3, 1.6, 0, 8, 0, {
			c = Props.EMBER,
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "vent",
			jitter = 0,
		})
		Props.embers(bp, 5, Kit.gy(ctx, b, 5, 2), 2, 1.4, i == 1)
		Props.embers(bp, -4, Kit.gy(ctx, b, -4, -4), -4, 1)
		for k = 1, 3 do
			bp:rbox(
				2.4,
				0.1,
				1.6,
				-2 + k * 2,
				Kit.gy(ctx, b, -2 + k * 2, 4) + 0.05,
				4,
				0,
				k * 60,
				0,
				o(Props.soot, "fine")
			)
		end
		Kit.lifeAt(ctx, b, "smoke", 0, 8.6, 0, 1)
		Kit.lifeAt(ctx, b, "embers", 0, 8.4, 0, 2)
		table.insert(out, b)
	end
end

-- Map sketch of the lava (rivers, pools, glowing cracks).
local function sketch(env: Env.Env)
	local ctx = env.ctx
	local lava = assert(env.T.shape.lava, "lava")
	for _, p in lava.pools do
		Kit.circle(ctx, "lava", p.x, p.z, (p.rx + p.rz) / 2)
	end
	for _, r in lava.rivers do
		local w = 0
		for _, v in r.widths do
			w = math.max(w, v)
		end
		Kit.line(ctx, "lava", r.points, w)
	end
	for _, c in assert(env.T.shape.cracks, "cracks") do
		Kit.line(ctx, if c.glow then "lava" else "crack", c.points, if c.glow then 4 else 3)
	end
end

function Lava.all(env: Env.Env, out: { Build })
	sketch(env)
	crater(env, out)
	rivers(env, out)
	pools(env, out)
	cracks(env, out)
	colossus(env, out)
	columns(env, out)
	chimneys(env, out)
end

return Lava
