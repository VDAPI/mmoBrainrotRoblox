--!strict
-- Wolfden Hollow (24-31) dressing (S49): an earthen den under the roots of a giant dead oak.
--   1 the Threshold under the Roots: the exit in an arch of thick roots, the hunters' last bivouac (a cold fire, a
--     bedroll torn to shreds, a broken crossbow, a pack with spilled bolts, a lantern still smouldering), claw marks,
--   2 the Feeding Pit (ghouls): feeding pits with bones by the walls, carcasses of a deer and a horse with a torn
--     harness, ghoul burrows low in the walls, root trunks like pillars, a claw sign over the way east,
--   3 the Great Den (bears): bark round the oak's taproot, beds of branches and moss, a fallen giant trunk along the
--     south wall, the wild hive in the roots under the vault dripping amber honey (glow), clawed walls,
--   4 the Moon Chamber (Elite II, "wow"): a shaft of moonlight from the hole on the flat moonstone, a ring of skulls
--     round it like a clock face, roots hanging round the hole like a curtain, hides and antlers on the walls,
--   5 the Wet Den: a bed of moss and branches, the spring pool in the niche, glowing fungi, drops. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Den = {}

type Build = Kit.Build
type Env = Kit.Env

local ROOT = { c = "#3A2E24", m = "Wood" }
local BARK = { c = "#2E2620", m = "Wood" }
local WOLF = { c = "#4A3B30", m = "Fabric" }
local MOON = "#CFE0FF"
local AMBER = "#E8A23A"
local FUNGUS = "#7FD4C0"
local GHOUL = "#C9E86B"

local function ground(env: Env, b: Build): (number, number) -> number
	return function(lx: number, lz: number): number
		return Kit.gy(env, b, lx, lz)
	end
end

-- Thick roots hanging from the vault near a wall (shell where they collide, at the walls only).
local function roots(env: Env, out: { Build }, i: number, n: number)
	local r = env.T.rooms[i]
	local b = Kit.build(env, `Roots_{i}`, "traces", r.x, r.z, 0)
	for k = 1, n do
		local a = k * (2 * math.pi / n) + i * 0.7
		local x, z = Kit.wallSpot(env, r, a, 3)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local fy = Kit.gy(env, b, lx, lz)
			local cy = (Kit.ceil(env, x, z) or (fy + b.at.y + 12)) - b.at.y
			local hang = math.min(cy - fy - 3, 6 + (k % 3) * 2)
			b.bp:beam(
				lx,
				cy,
				lz,
				lx * 0.96,
				cy - hang,
				lz * 0.96,
				0.5 + (k % 2) * 0.3,
				o(ROOT, "detail", { col = false })
			)
			b.bp:beam(
				lx * 0.96,
				cy - hang,
				lz * 0.96,
				lx * 0.93,
				cy - hang - 2,
				lz * 0.93,
				0.25,
				o(ROOT, "fine", { col = false })
			)
		end
	end
	table.insert(out, b)
end

local function threshold(env: Env, out: { Build })
	local r = env.T.rooms[1]
	-- the arch of thick roots over the exit (-211, 0)
	local arch = Kit.build(env, "RootArch", "landmark", -205, 0, 90)
	for k = -2, 2 do
		local x = k * 4
		arch.bp:beam(
			x,
			0,
			6 + math.abs(k),
			x * 0.6,
			17,
			4,
			1.4,
			o(ROOT, if math.abs(k) == 2 then "shell" else "detail", { col = false })
		)
	end
	arch.bp:beam(-8, 16, 4, 8, 17, 4, 1.6, o(BARK, "detail", { col = false }))
	table.insert(out, arch)
	-- the hunters' last bivouac
	local x, z = Kit.spot(env, r, math.rad(-50), 8, 4)
	if x and z then
		local b = Kit.build(env, "HuntersBivouac", "camp", x, z, 300)
		local bp = b.bp
		local y = Kit.gy(env, b, 0, 0)
		for k = 0, 5 do
			local a = k * math.pi / 3
			bp:rbox(
				0.8,
				0.5,
				0.8,
				math.cos(a) * 1.8,
				y + 0.25,
				math.sin(a) * 1.8,
				0,
				math.deg(a),
				0,
				o(Kit.rock, "detail", { col = false })
			)
		end
		bp:add(
			"cyl",
			3,
			0.5,
			0.5,
			0,
			y + 0.3,
			0,
			0,
			30,
			10,
			o({ c = "#1F1B19", m = "Wood" }, "detail", { col = false })
		)
		for k = 0, 3 do
			bp:rbox(
				1.6,
				0.1,
				0.8,
				3 + k * 0.8,
				Kit.gy(env, b, 3, 2) + 0.06,
				2 + (k % 2),
				0,
				k * 50,
				0,
				o(Kit.cloth, "fine", { col = false })
			)
		end
		bp:rbox(2.4, 0.3, 0.3, -3, Kit.gy(env, b, -3, 2) + 0.2, 2, 0, 40, 0, o(Kit.wood, "fine", { col = false }))
		bp:rbox(0.3, 0.3, 2, -3.4, Kit.gy(env, b, -3, 2) + 0.2, 2.6, 0, 70, 0, o(Kit.wood, "fine", { col = false }))
		bp:box(1.4, 1.8, 1, -4, Kit.gy(env, b, -4, -2) + 0.8, -2, o(Kit.hide, "detail", { col = false }))
		for k = 1, 5 do
			bp:rbox(
				1.2,
				0.1,
				0.1,
				-3 + k * 0.4,
				Kit.gy(env, b, -3, -3) + 0.06,
				-3 + k * 0.2,
				0,
				k * 35,
				0,
				o(Kit.wood, "fine", { col = false })
			)
		end
		Kit.lantern(bp, 2, y, -3, "#FFB25A", 4, "shell")
		Kit.clear(env, x, z, 6)
		table.insert(out, b)
	end
	roots(env, out, 1, 6)
end

local function feeding(env: Env, out: { Build })
	local r = env.T.rooms[2]
	-- bones in the feeding pits, carcasses, burrows, the claw sign
	local b = Kit.build(env, "FeedingPit", "traces", r.x, r.z, 0)
	local bp = b.bp
	local g = ground(env, b)
	for _, p in { { -142, -66 }, { -78, -114 }, { -52, -100 } } do
		local lx, lz = p[1] - r.x, p[2] - r.z
		Kit.bones(bp, lx, 0, lz, 7, g)
		Kit.glowCap(bp, lx + 2, g(lx + 2, lz + 2), lz + 2, 0.4, GHOUL, false, "fine")
	end
	-- the horse carcass with its torn harness
	local cx, cz = Kit.spot(env, r, math.rad(200), 8, 3, false)
	if cx and cz then
		local lx, lz = cx - r.x, cz - r.z
		local y = g(lx, lz)
		bp:add(
			"ball",
			6,
			2.4,
			3,
			lx,
			y + 0.8,
			lz,
			0,
			30,
			0,
			o({ c = "#5A3A2A", m = "SmoothPlastic" }, "detail", { col = false })
		)
		for k = 0, 4 do
			bp:beam(lx - 2 + k, y + 1.2, lz, lx - 2 + k, y + 0.2, lz + 2.4, 0.2, o(Kit.bone, "fine", { col = false }))
		end
		bp:rbox(4, 0.15, 0.6, lx + 3, y + 0.1, lz - 1, 0, 60, 0, o(Kit.hide, "fine", { col = false }))
		Kit.glowCap(bp, lx + 1, y + 1.4, lz, 0.5, GHOUL, true, "detail")
	end
	-- ghoul burrows low in the walls, root trunks like pillars
	for k = 0, 4 do
		local a = k * 1.25 + 0.4
		local x, z = Kit.wallSpot(env, r, a, 1)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			bp:add(
				"ball",
				4,
				3,
				1.2,
				lx,
				g(lx, lz) + 1.2,
				lz,
				0,
				math.deg(-a) + 90,
				0,
				o(Kit.dark, "detail", { col = false })
			)
			if k % 2 == 0 and Kit.free(env, x, z, 2) then
				bp:add(
					"cyl",
					18,
					2.4,
					2.4,
					lx * 0.94,
					g(lx, lz) + 8,
					lz * 0.94,
					0,
					0,
					90,
					o(ROOT, "shell", { q = false })
				)
			end
		end
	end
	-- the claw sign over the way east
	bp:push(r.x + 48 - b.at.x, 0, -10, 0, 90, 0)
	Kit.claws(bp, 0, g(48, -10) + 8, 0, 2.4)
	bp:pop()
	table.insert(out, b)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 30)
	roots(env, out, 2, 8)
end

local function bearden(env: Env, out: { Build })
	local r = env.T.rooms[3]
	local b = Kit.build(env, "GreatDen", "landmark", r.x, r.z, 0)
	local bp = b.bp
	local g = ground(env, b)
	-- bark round the taproot (pillar at (20, -52))
	local tx, tz = 20 - r.x, -52 - r.z
	for k = 0, 7 do
		local a = k * math.pi / 4
		bp:rbox(
			1.4,
			24,
			2.6,
			tx + math.cos(a) * 4.6,
			g(tx, tz) + 10,
			tz + math.sin(a) * 4.6,
			0,
			math.deg(-a),
			4,
			o(BARK, "detail", { col = false })
		)
	end
	-- the wild hive high in the roots dripping amber honey (glow)
	local hy = (Kit.ceil(env, 20, -52) or 30) - b.at.y - 6
	bp:add(
		"ball",
		4,
		6,
		4,
		tx + 5,
		hy,
		tz + 3,
		0,
		0,
		0,
		o({ c = "#B8862A", m = "SmoothPlastic" }, "detail", { col = false })
	)
	bp:add(
		"ball",
		2,
		2,
		2,
		tx + 5,
		hy - 3,
		tz + 3,
		0,
		0,
		0,
		{ c = AMBER, m = "Neon", lod = "detail", col = false, tag = "glow", jitter = 0, fxColor = AMBER, t = 0.2 }
	)
	bp:light(tx + 5, hy - 2, tz + 3, AMBER, 22, 1.1, "crystal")
	table.insert(out, b)
	-- beds of branches and moss under the walls, the fallen trunk along the south wall
	for k, a in { 60, 140, 220, 300 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 4, false)
		if x and z then
			local bed = Kit.build(env, `DenBed_{k}`, "traces", x, z, a)
			local y = Kit.gy(env, bed, 0, 0)
			bed.bp:add("ball", 7, 1.4, 5, 0, y + 0.2, 0, 0, 0, 0, o(Kit.moss, "detail", { col = false }))
			for m = 1, 5 do
				bed.bp:rbox(
					4,
					0.4,
					0.4,
					-2 + m,
					y + 0.7,
					(m % 2) - 0.5,
					0,
					m * 37,
					4,
					o(Kit.wood, "fine", { col = false })
				)
			end
			table.insert(out, bed)
		end
	end
	local fx, fz = Kit.spot(env, r, math.rad(90), 8, 6)
	if fx and fz then
		local t = Kit.build(env, "FallenTrunk", "landmark", fx, fz, 0)
		t.bp:add("cyl", 26, 4, 4, 0, Kit.gy(env, t, 0, 0) + 2, 0, 0, 0, 0, o(BARK, "shell", { q = false }))
		Kit.clear(env, fx, fz, 13)
		table.insert(out, t)
	end
	Kit.life(env.ctx, "bats", r.x, 24, r.z, 22)
	roots(env, out, 3, 9)
end

local function moon(env: Env, out: { Build })
	local r = env.T.rooms[4]
	local b = Kit.build(env, "MoonChamber", "landmark", r.x, r.z, 0)
	local bp = b.bp
	local g = ground(env, b)
	local y = g(0, 0)
	-- the moonstone (flat, no collision) and the shaft of moonlight
	bp:add("cyl", 0.6, 10, 10, 0, y + 0.3, 0, 0, 0, 90, o({ c = "#B8C4D0", m = "Slate" }, "detail", { col = false }))
	bp:add(
		"cyl",
		0.08,
		9,
		9,
		0,
		y + 0.62,
		0,
		0,
		0,
		90,
		{ c = MOON, m = "Neon", lod = "detail", col = false, t = 0.6, tag = "glow", jitter = 0, fxColor = MOON }
	)
	local top = (Kit.ceil(env, r.x, r.z) or 60) - b.at.y
	bp:add(
		"cyl",
		math.min(top, 60),
		16,
		16,
		0,
		y + math.min(top, 60) / 2,
		0,
		0,
		0,
		90,
		{ c = MOON, m = "Neon", lod = "detail", col = false, q = false, t = 0.9 }
	)
	bp:light(0, y + 20, 0, MOON, 40, 1.6, "lamp")
	Kit.lifeAt(env.ctx, b, "dustBeam", 0, y + 10, 0, 12)
	-- the ring of skulls round the stone like a clock face
	for k = 0, 11 do
		local a = k * math.pi / 6
		Kit.skull(bp, math.cos(a) * 8, g(math.cos(a) * 8, math.sin(a) * 8), math.sin(a) * 8, 1.2, math.deg(-a) - 90)
	end
	-- the curtain of roots round the hole
	for k = 0, 9 do
		local a = k * math.pi / 5
		bp:beam(
			math.cos(a) * 11,
			top,
			math.sin(a) * 11,
			math.cos(a) * 10,
			top - 10 - (k % 3) * 3,
			math.sin(a) * 10,
			0.35,
			o(ROOT, "fine", { col = false })
		)
	end
	table.insert(out, b)
	-- hides and antlers on the walls (trophies of the werewolves)
	local w = Kit.build(env, "MoonTrophies", "traces", r.x, r.z, 0)
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.3
		local x, z = Kit.wallSpot(env, r, a, 1)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local fy = Kit.gy(env, w, lx, lz)
			w.bp:rbox(3, 4, 0.15, lx, fy + 6, lz, 0, math.deg(-a) + 90, 0, o(WOLF, "detail", { col = false }))
			w.bp:beam(lx, fy + 9, lz, lx + 1, fy + 11, lz, 0.25, o(Kit.bone, "fine", { col = false }))
			w.bp:beam(lx, fy + 9, lz, lx - 1, fy + 11, lz, 0.25, o(Kit.bone, "fine", { col = false }))
		end
	end
	table.insert(out, w)
	roots(env, out, 4, 6)
end

local function wetden(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "WetDen", "glow", r.x, r.z, 0)
	local bp = b.bp
	local g = ground(env, b)
	bp:add("ball", 12, 1.2, 9, 0, g(0, 0) + 0.15, 0, 0, 0, 0, o(Kit.moss, "detail", { col = false }))
	for k = 0, 6 do
		local a = k * 0.9 + 0.2
		local x, z = Kit.wallSpot(env, r, a, 4)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			Kit.glowCap(bp, lx, g(lx, lz), lz, 0.6 + (k % 2) * 0.3, FUNGUS, k % 3 == 0)
		end
	end
	-- fungi round the spring pool in the niche (-112, 120)
	for k = 0, 3 do
		local a = k * 1.4
		local lx, lz = -112 + math.cos(a) * 11 - r.x, 120 + math.sin(a) * 11 - r.z
		Kit.glowCap(bp, lx, g(lx, lz), lz, 0.5, FUNGUS, k == 0, "fine")
	end
	table.insert(out, b)
	Kit.life(env.ctx, "drips", r.x, 14, r.z, 24)
	Kit.life(env.ctx, "drips", -112, 10, 120, 8)
end

function Den.all(env: Env, out: { Build })
	threshold(env, out)
	feeding(env, out)
	bearden(env, out)
	moon(env, out)
	wetden(env, out)
end

return Den
