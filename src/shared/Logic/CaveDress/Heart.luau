--!strict
-- Heart of the Glacier (92-100, boss cave) dressing (S51): the inside of the glacier where the dragons sleep. Nothing
-- collidable on the Dragon's Way (z = 0 from the respawn to the gate). The crystals' veins beat with one heart (tag
-- "heart": Controllers/TownFxController, every 2.4 s), stronger towards the antechamber.
--   1 the Crevasse: snow falling through the slit of sky, packed snow, scales and frozen bones on the threshold,
--   2 the Crystal Hall: four colossal crystals on the diagonals (prisms round the rock shafts), the "births" of the
--     guardians by the walls (clusters with half-formed torsos and arms, flat rune circles), shards,
--   3 the Hatchery: dragons' eggs in crystal nests in the ice niches glowing with the heart, cracked shells, a nest of
--     crushed ice,
--   4 the Ice Organ: curtains of giant icicles like organ pipes by the south wall, the frozen waterfall behind,
--   5 the Wyrm Burrows: shed skins of wyrms, ice shavings at the burrows' mouths, spiral scratches,
--   6 the Ice Hoard: heaps of gold and silver, goblets, chests, armour and swords of fallen seekers in blocks of ice,
--     claw prints and scales in the heaps (the one warm glint of the Heart),
--   7 the Dragon's Cave ("wow", Elite II): the frozen skeleton of an ancient dragon: the spine along the north wall,
--     ribs arching over the hall (feet by the walls, arches 16+ studs over the floor, only the feet collide), the tail
--     along the south wall, the skull by the east wall with its jaws open over the tunnel to the antechamber, crystals
--     growing through the bones, nests of young dragons between the ribs,
--   8 the Antechamber of Claws: Vaelgrath's claw marks (four parallel grooves) on the north and south walls, the fan
--     of his breath's frost from the gate, paw prints leading to it, shed scales, the gate between two ice claws, two
--     tall baskets of cold fire, mist creeping from under the gate. Pure.

local Grotto = require("./Grotto")
local Kit = require("./Kit")

local o = Kit.o

local Heart = {}

type Build = Kit.Build
type Env = Kit.Env
type BP = Kit.BP

local CRYSTAL = "#9FF0FF"
local EGG = "#BFF4FF"
local GOLD = { c = "#C9A45C", m = "Metal" }
local SILVER = { c = "#B8C0C8", m = "Metal" }
local BONE = { c = "#D8E4EC", m = "SmoothPlastic" }
local ICE = { c = "#A8D8F0", m = "Ice" }
local ICEGLASS = { c = "#BFE8FF", m = "Glass" }
local SCALE = { c = "#A8D8F0", m = "SmoothPlastic" }
local FROST = { c = "#E4F6FF", m = "SmoothPlastic" }

local function heartBox(
	bp: BP,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	rx: number,
	ry: number,
	rz: number,
	color: string?,
	t: number?
)
	bp:rbox(sx, sy, sz, x, y, z, rx, ry, rz, {
		c = color or CRYSTAL,
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		t = t or 0.15,
		tag = "heart",
		jitter = 0,
		fxColor = color or CRYSTAL,
	})
end

-- Veins of crystal deep in the walls of a room, beating with the heart (n veins, brightness grows with `k`).
local function veins(env: Env, out: { Build }, i: number, n: number, light: boolean)
	local r = env.T.rooms[i]
	local b = Kit.build(env, `HeartVeins_{i}`, "glow", r.x, r.z, 0)
	for k = 0, n - 1 do
		local a = (k + 0.3) * 2 * math.pi / n
		local x, z = Kit.wallSpot(env, r, a, 0)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local y = Kit.gy(env, b, lx, lz)
			heartBox(b.bp, 0.5, 12, 0.4, lx, y + 8, lz, 0, math.deg(-a) + 90, (k % 3 - 1) * 20)
			if light and k == 0 then
				b.bp:light(lx * 0.95, y + 8, lz * 0.95, CRYSTAL, 22, 1.1, "heart")
			end
		end
	end
	table.insert(out, b)
end

local function crevasse(env: Env, out: { Build })
	local r = env.T.rooms[1]
	local b = Kit.build(env, "CrevasseThreshold", "traces", -268, 0, 0)
	local y = Kit.gy(env, b, 0, 0)
	for k = 0, 5 do
		b.bp:rbox(
			1.4,
			0.15,
			1,
			-4 + k * 1.6,
			y + 0.08,
			6 + (k % 2) * 2,
			0,
			k * 40,
			0,
			o(SCALE, "fine", { col = false })
		)
		b.bp:rbox(
			1.4,
			0.15,
			1,
			-4 + k * 1.6,
			y + 0.08,
			-7 - (k % 2) * 2,
			0,
			k * 40,
			0,
			o(SCALE, "fine", { col = false })
		)
	end
	Kit.bones(b.bp, 4, y, 9, 6)
	table.insert(out, b)
	Kit.life(env.ctx, "snowBeam", -250, 28, 0, 6)
	Kit.life(env.ctx, "snowGust", -270, 0.5, 0, 8)
	veins(env, out, 1, 4, false)
	Kit.life(env.ctx, "drips", r.x, 20, r.z, 20)
end

local function crystalHall(env: Env, out: { Build })
	local r = env.T.rooms[2]
	-- the four colossal crystals round the rock shafts
	for k, p in { { -60, -40 }, { -60, 40 }, { -140, -40 }, { -140, 40 } } do
		-- the Build stands on the floor beside the rock shaft (towards the axis); the crystal wraps the shaft
		local sgn = if p[2] > 0 then 1 else -1
		local c = Kit.build(env, `ColossalCrystal_{k}`, "glow", p[1], p[2] - 6 * sgn, 0)
		local ox, oz = 0, 6 * sgn
		local y = Kit.gy(env, c, 0, 0)
		local top = (Kit.ceil(env, p[1], p[2] - 6 * sgn) or 40) - c.at.y
		for m = 0, 5 do
			local a = m * math.pi / 3
			c.bp:rbox(
				2.4,
				top - y,
				2.4,
				ox + math.cos(a) * 4.2,
				(top + y) / 2,
				oz + math.sin(a) * 4.2,
				0,
				math.deg(-a),
				3,
				o(ICEGLASS, "detail", { col = false, t = 0.3 })
			)
		end
		heartBox(c.bp, 1, top - y - 4, 1, ox + 4.8, (top + y) / 2, oz, 0, 0, 0)
		c.bp:light(0, y + 12, 0, CRYSTAL, 34, 1.4, "heart")
		Kit.lifeAt(env.ctx, c, "sparkle", 0, y + 6, 0, 6)
		table.insert(out, c)
	end
	-- the births of the guardians by the walls, with flat rune circles
	for k, a in { 30, 150, 210, 330 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 4)
		if x and z then
			local g = Kit.build(env, `GuardianBirth_{k}`, "glow", x, z, a)
			local y = Kit.gy(env, g, 0, 0)
			for m = 0, 4 do
				g.bp:rbox(
					1.6,
					5 + m,
					1.6,
					(m - 2) * 1.4,
					y + 2.5 + m / 2,
					(m % 2) * 1.2,
					0,
					m * 30,
					(m - 2) * 12,
					o(ICEGLASS, if m == 2 then "shell" else "detail", { q = false, col = m == 2, t = 0.25 })
				)
			end
			g.bp:add("ball", 4, 4, 3, 0, y + 5, -2, 0, 0, 0, o({ c = "#7FD4E8", m = "Ice" }, "detail", { col = false }))
			heartBox(g.bp, 0.4, 2, 0.2, 0, y + 5, -3.4, 0, 0, 0)
			g.bp:add("cyl", 0.05, 9, 9, 0, y + 0.03, -4, 0, 0, 90, o(FROST, "fine", { col = false, t = 0.4 }))
			Kit.clear(env, x, z, 5)
			table.insert(out, g)
		end
	end
	veins(env, out, 2, 4, false)
	Kit.life(env.ctx, "drips", r.x, 30, r.z, 40)
end

local function hatchery(env: Env, out: { Build })
	local r = env.T.rooms[3]
	for k, p in { { -110, -226 }, { -154, -202 }, { -68, -212 } } do
		local f = env.T.floor(p[1], p[2])
		if f then
			local e = Kit.build(env, `DragonEggs_{k}`, "glow", p[1], p[2], k * 50)
			local y = Kit.gy(env, e, 0, 0)
			e.bp:add("ball", 7, 1.4, 7, 0, y + 0.3, 0, 0, 0, 0, o(FROST, "detail", { col = false }))
			for m = 1, 3 do
				local a = m * 2.1
				e.bp:add("ball", 2.2, 3, 2.2, math.cos(a) * 1.8, y + 1.6, math.sin(a) * 1.8, 0, 0, 0, {
					c = EGG,
					m = "Neon",
					lod = "detail",
					col = false,
					q = false,
					t = 0.25,
					tag = "heart",
					jitter = 0,
					fxColor = EGG,
				})
			end
			e.bp:light(0, y + 3, 0, EGG, 20, 1.1, "heart")
			table.insert(out, e)
		end
	end
	local s = Kit.build(env, "EggShells", "traces", r.x, r.z, 0)
	for k = 0, 5 do
		local a = k * 1.05
		local lx, lz = math.cos(a) * 26, math.sin(a) * 26
		s.bp:rbox(
			1.6,
			1.2,
			0.2,
			lx,
			Kit.gy(env, s, lx, lz) + 0.5,
			lz,
			20,
			k * 60,
			30,
			o(FROST, "fine", { col = false })
		)
	end
	table.insert(out, s)
	veins(env, out, 3, 4, false)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 24)
end

local function organ(env: Env, out: { Build })
	local r = env.T.rooms[4]
	for i, f in env.T.icefalls() do
		if (f.x - r.x) ^ 2 + (f.z - r.z) ^ 2 < (r.r + 30) ^ 2 then
			Grotto.icefall(env, out, f, i)
		end
	end
	-- the curtains of giant icicles like organ pipes
	local p = Kit.build(env, "IceOrgan", "glow", -110, 214, 0)
	local y = Kit.gy(env, p, 0, 0)
	for k = -6, 6 do
		local lx = k * 2.6
		local top = (Kit.ceil(env, -110 + lx, 216) or 28) - p.at.y
		local len = top - y - 4 - math.abs(k) * 0.6
		p.bp:add(
			"cyl",
			len,
			1.8,
			1.8,
			lx,
			top - len / 2,
			2 + math.abs(k) * 0.3,
			0,
			0,
			90,
			o(ICE, "detail", { col = false })
		)
	end
	p.bp:light(0, y + 10, 4, "#9FE0FF", 30, 1.2, "crystal")
	table.insert(out, p)
	veins(env, out, 4, 4, false)
	Kit.life(env.ctx, "drips", r.x, 22, r.z, 24)
end

local function burrows(env: Env, out: { Build })
	local r = env.T.rooms[5]
	local b = Kit.build(env, "WyrmTraces", "traces", r.x, r.z, 0)
	for k, p in { { 60, -196 }, { 97, -181 }, { 106, -140 }, { 24, -187 } } do
		local lx, lz = p[1] - r.x, p[2] - r.z
		local f = env.T.floor(p[1], p[2])
		if f then
			local y = f - b.at.y
			for m = 0, 3 do
				b.bp:rbox(
					0.6,
					0.3,
					1,
					lx * 0.85 + m - 1.5,
					y + 0.15,
					lz * 0.85,
					0,
					m * 40,
					0,
					o(FROST, "fine", { col = false })
				)
			end
			if k % 2 == 1 then
				b.bp:rbox(
					6,
					0.2,
					2.4,
					lx * 0.75,
					y + 0.15,
					lz * 0.75,
					0,
					k * 40,
					0,
					o({ c = "#C8E0EC", m = "SmoothPlastic" }, "detail", { col = false, t = 0.3 })
				)
			end
		end
	end
	table.insert(out, b)
	veins(env, out, 5, 4, false)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 20)
end

local function hoard(env: Env, out: { Build })
	local r = env.T.rooms[6]
	for k, a in { 20, 60, 100 } do
		local x, z = Kit.spot(env, r, math.rad(a - 40), 6, 4)
		if x and z then
			local h = Kit.build(env, `IceHoard_{k}`, "glow", x, z, a)
			local y = Kit.gy(env, h, 0, 0)
			h.bp:add("ball", 8, 2.4, 6, 0, y + 0.6, 0, 0, 0, 0, o(GOLD, "shell", { q = false }))
			for m = 0, 5 do
				h.bp:add(
					"cyl",
					0.8,
					0.6,
					0.6,
					math.cos(m) * 2.4,
					y + 1.8,
					math.sin(m) * 2,
					0,
					0,
					90,
					o(if m % 2 == 0 then GOLD else SILVER, "fine", { col = false })
				)
			end
			h.bp:box(2.4, 1.6, 1.6, 4, y + 0.8, 2, o({ c = "#5A4632", m = "Wood" }, "detail", { col = false }))
			h.bp:box(3, 4, 2.4, -4, y + 2, 1, o(ICEGLASS, "detail", { col = false, t = 0.35 })) -- armour in a block of ice
			h.bp:box(1.4, 2.4, 0.8, -4, y + 2, 1, o(SILVER, "fine", { col = false }))
			h.bp:light(0, y + 3, 0, "#FFD27A", 18, 0.9, "lamp")
			Kit.clear(env, x, z, 6)
			table.insert(out, h)
		end
	end
	veins(env, out, 6, 4, false)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 20)
end

local function ribcage(env: Env, out: { Build })
	local r = env.T.rooms[7]
	local s = Kit.build(env, "DragonSkeleton", "landmark", r.x, r.z, 0)
	local bp = s.bp
	local fy = Kit.gy(env, s, 0, 0)
	-- the spine along the north wall (bearings 200-340 but the mouth of tunnel 5-7)
	local last: { number }? = nil
	for deg = 200, 340, 10 do
		if deg < 236 or deg > 256 then
			local a = math.rad(deg)
			local lx, lz = math.cos(a) * 45, math.sin(a) * 45
			local y = Kit.gy(env, s, lx, lz) + 6
			bp:add("ball", 3, 2.4, 2.4, lx, y, lz, 0, 0, 0, o(BONE, "detail", { col = false }))
			if last then
				bp:beam(last[1], last[2], last[3], lx, y, lz, 0.9, o(BONE, "detail", { col = false }))
			end
			last = { lx, y, lz }
		else
			last = nil
		end
	end
	-- the ribs arching over the hall (feet by the walls, 16+ studs over the floor inside the core)
	for _, lx in { -6, 6, 18 } do
		local prev: { number }? = nil
		for t = 0, 10 do
			local u = t / 10
			local lz = -44 + 88 * u
			local y = fy + 4 + 32 * math.sin(math.pi * u) ^ 0.4
			if prev then
				bp:beam(prev[1], prev[2], prev[3], lx, y, lz, 0.8, o(BONE, "detail", { col = false }))
			end
			prev = { lx, y, lz }
		end
		for _, side in { -1, 1 } do
			bp:box(2.4, 6, 2.4, lx, Kit.gy(env, s, lx, side * 46) + 3, side * 46, o(BONE, "shell", { q = false }))
		end
		heartBox(bp, 0.6, 4, 0.6, lx, fy + 30, 0, 30, 0, 0)
	end
	-- the tail along the south wall
	for k = 0, 6 do
		local a = math.rad(60 + k * 10)
		bp:add(
			"ball",
			2 - k * 0.2,
			1.6 - k * 0.15,
			2 - k * 0.2,
			math.cos(a) * 46,
			Kit.gy(env, s, math.cos(a) * 46, math.sin(a) * 46) + 1,
			math.sin(a) * 46,
			0,
			0,
			0,
			o(BONE, "detail", { col = false })
		)
	end
	bp:light(0, fy + 24, 0, CRYSTAL, 50, 1.4, "heart")
	table.insert(out, s)
	-- the skull by the east wall, its jaws open over the tunnel to the antechamber (no collision; passage 12+ wide, 18+)
	local k = Kit.build(env, "DragonSkull", "landmark", 156, 0, 90)
	local ky = Kit.gy(env, k, 0, 0)
	k.bp:box(16, 8, 12, 0, ky + 24, 4, o(BONE, "detail", { col = false })) -- the cranium over the mouth
	k.bp:rbox(14, 2, 10, 0, ky + 19, -4, -18, 0, 0, o(BONE, "detail", { col = false })) -- the upper jaw
	for _, side in { -1, 1 } do
		k.bp:box(2, 2, 2, side * 4, ky + 25, -2.2, {
			c = CRYSTAL,
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "heart",
			jitter = 0,
			fxColor = CRYSTAL,
		}) -- the eye sockets
		for t = 0, 3 do
			k.bp:rbox(0.8, 3, 0.8, side * (2 + t * 1.5), ky + 17, -7, 0, 0, 0, o(BONE, "fine", { col = false })) -- teeth
		end
		k.bp:beam(side * 7, ky + 18, -2, side * 8, ky + 6, -6, 0.9, o(BONE, "detail", { col = false })) -- the lower jaw
	end
	table.insert(out, k)
	-- nests of young dragons between the ribs (by the walls, outside the core)
	for n, a in { 120, 300 } do
		local x, z = Kit.spot(env, r, math.rad(a), 4, 3, false)
		if x and z then
			local b = Kit.build(env, `YoungNest_{n}`, "traces", x, z, a)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:add("ball", 6, 1.2, 6, 0, y + 0.3, 0, 0, 0, 0, o(FROST, "detail", { col = false }))
			for m = 0, 4 do
				b.bp:rbox(
					1.2,
					0.15,
					0.8,
					math.cos(m) * 2,
					y + 0.8,
					math.sin(m) * 2,
					0,
					m * 40,
					0,
					o(SCALE, "fine", { col = false })
				)
			end
			table.insert(out, b)
		end
	end
	veins(env, out, 7, 4, true)
	Kit.life(env.ctx, "drips", r.x, 30, r.z, 30)
end

local function antechamber(env: Env, out: { Build })
	-- the claw marks on the north and south walls, the fan of frost, the paw prints, the scales
	local b = Kit.build(env, "VaelgrathTraces", "traces", 245, 0, 0)
	local bp = b.bp
	for _, side in { -1, 1 } do
		for g = 0, 3 do
			bp:rbox(
				24,
				1,
				0.4,
				-6 + g * 1.5,
				Kit.gy(env, b, 0, side * 39) + 10 + g * 1.4,
				side * 39.5,
				0,
				0,
				-12,
				o(FROST, "detail", { col = false })
			)
		end
	end
	for k = 0, 7 do
		local a = math.rad(150 + k * 8)
		local lx, lz = 39 + math.cos(a) * 30, math.sin(a) * 30
		bp:rbox(
			30,
			0.05,
			3,
			(39 + lx) / 2,
			Kit.gy(env, b, lx, lz) + 0.04,
			lz / 2,
			0,
			math.deg(-a),
			0,
			o(FROST, "fine", { col = false, t = 0.3 })
		)
	end
	for k = 0, 5 do
		local lx = -20 + k * 9
		bp:rbox(
			4,
			0.06,
			3,
			lx,
			Kit.gy(env, b, lx, (k % 2) * 6 - 3) + 0.05,
			(k % 2) * 6 - 3,
			0,
			90,
			0,
			o({ c = "#B8D0DC", m = "SmoothPlastic" }, "fine", { col = false })
		)
	end
	for k = 0, 3 do
		bp:rbox(
			3,
			0.3,
			2.2,
			-10 + k * 7,
			Kit.gy(env, b, -10 + k * 7, 20) + 0.2,
			20 - k * 3,
			0,
			k * 50,
			10,
			o(SCALE, "fine", { col = false })
		)
	end
	table.insert(out, b)
	-- the two ice claws round the gate (284, 0), the baskets of cold fire, the mist
	local g = Kit.build(env, "ClawGate", "landmark", 290, 0, 270)
	local gy = Kit.gy(env, g, 0, 0)
	for _, side in { -1, 1 } do
		for t = 0, 4 do
			g.bp:rbox(
				2.6 - t * 0.3,
				7,
				2.6 - t * 0.3,
				side * (10 - t * 1.2),
				gy + 3 + t * 6,
				1,
				0,
				0,
				side * (-8 - t * 9),
				o(ICE, "detail", { col = false })
			)
		end
	end
	table.insert(out, g)
	local f = Kit.build(env, "ColdBaskets", "lamp", 272, 0, 0)
	for _, side in { -1, 1 } do
		local fy = Kit.gy(env, f, 0, side * 14)
		f.bp:box(0.8, 7, 0.8, 0, fy + 3.5, side * 14, o(Kit.iron, "shell", { q = false }))
		Kit.fire(f.bp, 0, fy + 7.6, side * 14, 1.6, "#9FE0FF", "detail")
	end
	table.insert(out, f)
	Kit.life(env.ctx, "mist", 276, 0.5, 0, 12)
	veins(env, out, 8, 4, true)
	Kit.life(env.ctx, "drips", 230, 24, 0, 20)
end

function Heart.all(env: Env, out: { Build })
	crevasse(env, out)
	crystalHall(env, out)
	hatchery(env, out)
	organ(env, out)
	burrows(env, out)
	hoard(env, out)
	ribcage(env, out)
	antechamber(env, out)
end

return Heart
