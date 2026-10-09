--!strict
-- Deepforge (63-70, boss cave) dressing (S50): the dwarves' forge taken by Azgor's renegades. Old dwarven runes glow
-- cold blue where they were not chiselled off, Azgor's signs glow red.
--   1 the Gate of the Deep: the iron-bound wings of the gate behind the exit, two kneeling stone kings with hammers by
--     the way east, a band of blue runes, abandoned dwarven packs, soot over the gate,
--   2 the Great Forge ("wow"): four forge bays in the diagonal walls (hearth with embers, a huge anvil, double
--     bellows, a quenching tub with steam, a tool rack, the trough of metal), eight statues of kings by the four
--     tunnel mouths with chiselled faces and Azgor's flame cut in their place, his banners on chains, and over the
--     middle the Great Crucible on four chains glowing white-orange and dripping sparks under the smoke hole,
--   bridges over the River of Fire (tunnels 2-3 and 2-4): arched decks with railings over the lava span, the dwarf's
--     face spewing the lava fall at the west end, steam rising from the chasm at the east end,
--   3 the Magma Gullet (golems): basalt columns by the walls, the balustrade of the lake gallery, half-formed golem
--     torsos rising from the lake, ladles, tongs and chains on pulleys on the shore,
--   4 the Smelter: the tilted giant crucible on its scaffold pouring metal, rows of ingot moulds cooling from orange
--     to grey along the gutter, slag heaps, stacks of ingots, a wheelbarrow, a chimney,
--   5 the Golem Foundry: three unfinished golems chained upright in iron frames, moulds of limbs, a crane holding an
--     arm, the torso cooling in the casting pit, red binding circles over the blue runes,
--   6 the Renegades' Armoury: racks of axes and hammers, armour stands, a grindstone throwing sparks, crates of
--     weapons with the dragon's claw ready to ship north, the loading ramp and a cart on rails before a shut iron
--     door, the barracks corner (bunks, mugs, a beer barrel), torn clan banners on the floor, Azgor's on the walls,
--   7 the Heart of the Forge ("wow"): the Heart, a ball of molten rock in a cage of chains under the dome, dripping
--     sparks over the Elite II; the First Smith's anvil on its dais with the hammer and runes, the bowl of metal,
--     four kings raising their hammers to the Heart,
--   8 the Antechamber of the Furnace ("wow"): Azgor's horned flame over the gate with lava in its grooves and a small
--     fall into a bowl, kneeling chained kings by the gate, a row of fire baskets, a pile of dwarven helmets and broken
--     hammers as an offering, shimmering air before the gate. Pure.

local Kit = require("./Kit")

local o = Kit.o

local Forge = {}

type Build = Kit.Build
type Env = Kit.Env
type BP = Kit.BP

local RUNE = "#6FB8FF"
local AZGOR = "#FF3A1A"
local EMBER = "#FF7A1A"
local STONE = { c = "#4A4246", m = "Slate" }
local DWARF = { c = "#6A625C", m = "Slate" }
local IRON = { c = "#3A3A40", m = "CorrodedMetal" }
local STEEL = { c = "#8A8C94", m = "Metal" }
local LEATHER = { c = "#5A3A26", m = "Fabric" }
local BANNER = { c = "#5A1410", m = "Fabric" }
local CLAN = { c = "#2E4A6A", m = "Fabric" }
local GOLEM = { c = "#3A2620", m = "Basalt" }

local function glowBox(
	bp: BP,
	sx: number,
	sy: number,
	sz: number,
	x: number,
	y: number,
	z: number,
	color: string,
	tag: string?
)
	bp:box(sx, sy, sz, x, y, z, {
		c = color,
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		tag = tag or "glow",
		jitter = 0,
		fxColor = color,
	})
end

-- A dwarven king in stone on a plinth (facing -Z of the frame); `kneel` lowers him; `chiselled` cuts his face off and
-- carves Azgor's flame there; `raise` lifts his hammer over his head.
local function king(bp: BP, x: number, y: number, z: number, s: number, yaw: number, opts: { [string]: boolean }?)
	local op: { [string]: boolean } = opts or {}
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(4.4 * s, 1.6 * s, 4.4 * s, 0, 0.8 * s, 0, o(STONE, "shell", { q = false }))
	local body = if op.kneel then 4.4 else 7.5
	bp:box(3.2 * s, body * s, 2.4 * s, 0, (1.6 + body / 2) * s, 0, o(DWARF, "detail", { col = false }))
	local headY = (1.6 + body + 1.1) * s
	bp:box(2.2 * s, 2.2 * s, 2.2 * s, 0, headY, 0, o(DWARF, "detail", { col = false }))
	-- the beard and the crown
	bp:rbox(2 * s, 2.6 * s, 0.8 * s, 0, headY - 2 * s, -1.2 * s, -10, 0, 0, o(DWARF, "detail", { col = false }))
	for k = -1, 1 do
		bp:box(0.4 * s, 0.9 * s, 0.4 * s, k * 0.8 * s, headY + 1.5 * s, 0, o(DWARF, "fine", { col = false }))
	end
	if op.chiselled then
		bp:box(
			1.8 * s,
			1.6 * s,
			0.3 * s,
			0,
			headY,
			-1.2 * s,
			o({ c = "#2A2426", m = "Slate" }, "detail", { col = false })
		)
		glowBox(bp, 0.5 * s, 1.1 * s, 0.1 * s, 0, headY, -1.36 * s, AZGOR)
	end
	if op.raise then
		bp:rbox(
			0.4 * s,
			6 * s,
			0.4 * s,
			1.6 * s,
			headY + 2 * s,
			-0.6 * s,
			-15,
			0,
			-20,
			o(DWARF, "detail", { col = false })
		)
		bp:box(2.4 * s, 1.4 * s, 1.4 * s, 2.6 * s, headY + 5 * s, -1.2 * s, o(DWARF, "detail", { col = false }))
	else
		bp:rbox(
			0.4 * s,
			5 * s,
			0.4 * s,
			0,
			(1.6 + body * 0.4) * s,
			-1.6 * s,
			0,
			0,
			0,
			o(DWARF, "detail", { col = false })
		)
		bp:box(2.4 * s, 1.4 * s, 1.4 * s, 0, 1.6 * s + 0.8, -1.6 * s, o(DWARF, "detail", { col = false }))
	end
	bp:pop()
end

local function anvil(bp: BP, x: number, y: number, z: number, s: number, yaw: number, lod: any?)
	bp:push(x, y, z, 0, yaw, 0)
	bp:box(1.6 * s, 1.6 * s, 1.6 * s, 0, 0.8 * s, 0, o(IRON, lod or "shell", { q = false }))
	bp:box(3.4 * s, 0.9 * s, 1.4 * s, 0, 2 * s, 0, o(IRON, "detail", { col = false }))
	bp:rbox(1.2 * s, 0.6 * s, 0.9 * s, 2.2 * s, 2.1 * s, 0, 0, 0, -15, o(IRON, "detail", { col = false }))
	bp:pop()
end

-- A band of runes along the walls of a room (blue: dwarven, red: Azgor's).
local function runes(env: Env, out: { Build }, i: number, color: string, n: number, h: number)
	local r = env.T.rooms[i]
	local b = Kit.build(env, `Runes_{i}`, "glow", r.x, r.z, 0)
	for k = 0, n - 1 do
		local a = (k + 0.5) * 2 * math.pi / n
		local x, z = Kit.wallSpot(env, r, a, 1)
		if x and z then
			local lx, lz = x - r.x, z - r.z
			local y = Kit.gy(env, b, lx, lz) + h
			b.bp:push(lx, y, lz, 0, math.deg(-a) + 90, 0)
			glowBox(b.bp, 1.6, 0.25, 0.1, 0, 0, 0, color)
			glowBox(b.bp, 0.25, 1.4, 0.1, -0.5, 0.7, 0, color)
			glowBox(b.bp, 0.25, 1, 0.1, 0.6, -0.5, 0, color)
			b.bp:pop()
		end
	end
	table.insert(out, b)
end

local function gate(env: Env, out: { Build })
	-- the wings of the gate behind the exit (-278, 0), ajar, on the west wall
	local w = Kit.build(env, "DeepGate", "landmark", -286, 0, 90)
	for _, s in { -1, 1 } do
		w.bp:rbox(9, 18, 1, s * 7, 9, 3, 0, s * 18, 0, o(IRON, "detail", { col = false }))
		for k = 0, 3 do
			w.bp:rbox(9.2, 0.5, 1.2, s * 7, 2 + k * 4.6, 3, 0, s * 18, 0, o(STEEL, "fine", { col = false }))
		end
	end
	w.bp:box(22, 3, 1, 0, 20, 4, o({ c = "#141012", m = "Slate" }, "detail", { col = false })) -- soot
	table.insert(out, w)
	-- two kneeling kings by the way east
	local k = Kit.build(env, "GateKings", "landmark", -222, 0, 270)
	for _, s in { -1, 1 } do
		king(k.bp, s * 22, Kit.gy(env, k, s * 22, 0), 0, 1.3, 0, { kneel = true })
	end
	table.insert(out, k)
	-- abandoned dwarven packs
	local r = env.T.rooms[1]
	local x, z = Kit.spot(env, r, math.rad(240), 6, 3, false)
	if x and z then
		local p = Kit.build(env, "DwarfPacks", "traces", x, z, 40)
		local y = Kit.gy(env, p, 0, 0)
		for n = 0, 2 do
			p.bp:rbox(
				1.6,
				1.8,
				1.2,
				n * 2,
				y + 0.9,
				(n % 2) * 1.4,
				0,
				n * 30,
				n * 8,
				o(LEATHER, "detail", { col = false })
			)
		end
		p.bp:rbox(0.3, 3, 0.3, -1.5, y + 0.4, 1, 0, 0, 80, o(Kit.wood, "fine", { col = false }))
		table.insert(out, p)
	end
	runes(env, out, 1, RUNE, 10, 6)
end

-- A forge bay of the Great Forge at bearing `a` (radians) from the hall's centre.
local function bay(env: Env, out: { Build }, n: number, a: number)
	local r = env.T.rooms[2]
	local cx, cz = r.x + math.cos(a) * 66, r.z + math.sin(a) * 66
	-- the frame faces the hall: local +Z points out towards the wall
	local b = Kit.build(env, `ForgeBay_{n}`, "forge", cx, cz, math.deg(math.atan2(math.cos(a), math.sin(a))))
	local bp = b.bp
	local y = Kit.gy(env, b, 0, 0)
	-- the hearth with embers
	bp:box(6, 3, 4, -4.5, y + 1.5, 2.5, o(STONE, "shell", { q = false }))
	glowBox(bp, 5, 0.4, 3, -4.5, y + 3.1, 2.5, EMBER, "forge")
	bp:light(-4.5, y + 5, 2.5, EMBER, 24, 1.4, "fire")
	bp:box(2.4, 12, 2.4, -4.5, y + 9, 4, o(STONE, "detail", { col = false })) -- the flue
	-- the double bellows
	for _, s in { -1, 1 } do
		bp:rbox(2.6, 0.8, 4, -8.5, y + 1.2 + s * 0.5, 2.5, s * 8, 0, 0, o(LEATHER, "detail", { col = false }))
	end
	-- the huge anvil and the quenching tub with steam
	anvil(bp, 3, y, -1, 1.4, 20)
	bp:add("cyl", 2.2, 4, 4, 5.5, y + 1.1, 3, 0, 0, 90, o(Kit.wood, "shell", { q = false }))
	bp:add("cyl", 0.1, 3.6, 3.6, 5.5, y + 2.15, 3, 0, 0, 90, o({ c = "#3A4A50", m = "Glass" }, "fine", { col = false }))
	Kit.lifeAt(env.ctx, b, "steam", 5.5, 2.4, 3, 1.5)
	Kit.lifeAt(env.ctx, b, "drips", 5.5, 3, 3, 1)
	-- the tool rack and the gutter of metal from the nozzle to the hearth
	bp:box(4, 4, 0.4, 9, y + 2.5, 4.5, o(Kit.wood, "detail", { col = false }))
	for k = 0, 3 do
		bp:rbox(0.25, 3, 0.25, 7.6 + k * 0.9, y + 2.6, 4.2, 0, 0, 6, o(STEEL, "fine", { col = false }))
	end
	bp:box(1.4, 0.6, 5, -1, y + 0.3, 5, o(STONE, "detail", { col = false }))
	glowBox(bp, 0.8, 0.1, 5, -1, y + 0.62, 5, Kit.METAL, "lava")
	Kit.lifeAt(env.ctx, b, "sparks", 3, 2.4, -1, 1.5)
	Kit.lifeAt(env.ctx, b, "embers", -4.5, 3.4, 2.5, 2)
	Kit.lifeAt(env.ctx, b, "smoke", -4.5, 14, 4, 1.5)
	Kit.clear(env, cx, cz, 9)
	table.insert(out, b)
end

local function greatForge(env: Env, out: { Build })
	local r = env.T.rooms[2]
	for k, deg in { 45, 135, 225, 315 } do
		bay(env, out, k, math.rad(deg))
	end
	-- eight kings by the four tunnel mouths, their faces chiselled off; Azgor's banners on chains between them
	local s = Kit.build(env, "ChiselledKings", "landmark", r.x, r.z, 0)
	local n = 0
	for _, mouth in { 0, 90, 180, 270 } do
		for _, side in { -14, 14 } do
			local a = math.rad(mouth + side)
			local lx, lz = math.cos(a) * 57, math.sin(a) * 57
			n += 1
			king(
				s.bp,
				lx,
				Kit.gy(env, s, lx, lz),
				lz,
				1.5,
				math.deg(math.atan2(math.cos(a), math.sin(a))),
				{ chiselled = true }
			)
		end
		local a = math.rad(mouth + 45)
		local lx, lz = math.cos(a) * 60, math.sin(a) * 60
		local top = (Kit.ceil(env, r.x + lx, r.z + lz) or 30) - s.at.y
		s.bp:box(0.3, 8, 0.3, lx, top - 4, lz, o(IRON, "fine", { col = false }))
		s.bp:rbox(4, 10, 0.2, lx, top - 13, lz, 0, math.deg(-a) + 90, 0, o(BANNER, "detail", { col = false }))
		glowBox(s.bp, 1, 2, 0.1, lx - math.sin(a) * 0.12, top - 12, lz + math.cos(a) * 0.12, AZGOR)
	end
	table.insert(out, s)
	-- the Great Crucible on four chains over the rune ring (no collision), dripping sparks
	local c = Kit.build(env, "GreatCrucible", "forge", r.x, r.z, 0)
	local y = Kit.gy(env, c, 0, 0) + 24
	local top = (Kit.ceil(env, r.x + 8, r.z) or 38) - c.at.y
	c.bp:add("ball", 12, 7, 12, 0, y, 0, 0, 0, 0, o(IRON, "detail", { col = false }))
	c.bp:add("cyl", 1, 13, 13, 0, y + 3, 0, 0, 0, 90, o(IRON, "detail", { col = false }))
	c.bp:add("cyl", 0.3, 11, 11, 0, y + 3.4, 0, 0, 0, 90, Kit.lavaOpts("#FFE0A0", 0.1, "glow"))
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		c.bp:beam(
			math.cos(a) * 6,
			y + 2,
			math.sin(a) * 6,
			math.cos(a) * 10,
			top,
			math.sin(a) * 10,
			0.4,
			o(IRON, "fine", { col = false })
		)
	end
	c.bp:light(0, y + 6, 0, "#FFC070", 60, 2, "lava")
	c.bp:light(0, y - 6, 0, EMBER, 40, 1.2, "lava")
	Kit.lifeAt(env.ctx, c, "sparks", 0, y - 4, 0, 3)
	Kit.lifeAt(env.ctx, c, "smoke", 0, y + 6, 0, 4)
	Kit.lifeAt(env.ctx, c, "dustBeam", 0, y + 8, 0, 8)
	table.insert(out, c)
	runes(env, out, 2, RUNE, 14, 9)
end

local function bridges(env: Env, out: { Build })
	for k, zs in { -1, 1 } do
		local z0 = 92 * zs
		local b = Kit.build(env, `FireBridge_{k}`, "bridge", -100, z0, 0)
		local bp = b.bp
		local y = Kit.gy(env, b, 0, 0)
		-- the arch under the deck and the railings over the lava span
		for t = -2, 2 do
			bp:box(9.6, 1.4, 6, 0, y - 1.2 - (2 - math.abs(t)) * 0.6, t * 6, o(STONE, "detail", { col = false }))
		end
		for _, side in { -1, 1 } do
			bp:box(0.8, 2.6, 26, side * 4.8, y + 1.3, 0, o(STONE, "shell", { q = false }))
			for t = -3, 3 do
				bp:box(1.2, 3.2, 1.2, side * 4.8, y + 1.6, t * 4, o(STONE, "detail", { col = false }))
			end
		end
		Kit.lifeAt(env.ctx, b, "haze", 0, y - 4, 0, 10)
		table.insert(out, b)
		-- the dwarf's face spewing the lava fall at the west end; steam from the chasm at the east end
		local f = Kit.build(env, `LavaFace_{k}`, "landmark", -190, z0, 270)
		local fy = Kit.gy(env, f, 0, 0)
		f.bp:box(10, 10, 2, 0, fy + 14, 3, o(STONE, "detail", { col = false }))
		f.bp:rbox(8, 6, 1.6, 0, fy + 10, 2, -15, 0, 0, o(STONE, "detail", { col = false })) -- the beard
		for _, s in { -1, 1 } do
			glowBox(f.bp, 1.4, 0.8, 0.2, s * 2.2, fy + 16, 1.9, EMBER)
		end
		table.insert(out, f)
		Kit.life(env.ctx, "steam", -24, -8, z0, 6)
		Kit.life(env.ctx, "smokeColumn", -24, -6, z0, 4)
	end
end

local function gullet(env: Env, out: { Build })
	local r = env.T.rooms[3]
	-- basalt columns by the walls
	for k = 0, 5 do
		local x, z = Kit.spot(env, r, k * 1.05 + 0.4, 4, 2.5)
		if x and z then
			local b = Kit.build(env, `BasaltColumns_{k}`, "landmark", x, z, k * 40)
			local y = Kit.gy(env, b, 0, 0)
			for m = 0, 2 do
				local h = 8 + m * 4 + (k % 2) * 3
				b.bp:add(
					"cyl",
					h,
					2.4,
					2.4,
					(m - 1) * 1.6,
					y + h / 2,
					(m % 2) * 1.4,
					0,
					0,
					90,
					o(Kit.basalt, if m == 1 then "shell" else "detail", { q = false, col = m == 1 })
				)
			end
			Kit.clear(env, x, z, 3)
			table.insert(out, b)
		end
	end
	-- the balustrade of the lake gallery and the golems rising from the lava
	local g = Kit.build(env, "GulletLake", "landmark", -105, -216, 0)
	local gy = Kit.gy(env, g, 0, 0)
	for t = -3, 3 do
		g.bp:box(5.4, 2.4, 0.8, t * 6, gy + 1.2, -2, o(STONE, "shell", { q = false }))
		g.bp:box(1.2, 3, 1.2, t * 6 + 3, gy + 1.5, -2, o(STONE, "detail", { col = false }))
	end
	for k, p in { { 0, -24 }, { -12, -18 }, { 10, -14 } } do
		local wx, wz = -105 + p[1], -216 + p[2]
		local l = env.T.liquid(wx, wz)
		if l then
			local ly = l.level - g.at.y
			g.bp:add("ball", 5, 6, 4, p[1], ly + 2, p[2], 10, k * 40, 0, o(GOLEM, "detail", { col = false }))
			g.bp:add(
				"ball",
				2.6,
				2.4,
				2.4,
				p[1],
				ly + 5.6,
				p[2] + 0.4,
				0,
				k * 40,
				0,
				o(GOLEM, "detail", { col = false })
			)
			glowBox(g.bp, 0.4, 3, 0.2, p[1] - 0.8, ly + 2.6, p[2] - 1.9, EMBER)
			glowBox(g.bp, 0.6, 0.4, 0.2, p[1] + 0.5, ly + 5.8, p[2] - 0.8, "#FFD27A")
		end
	end
	-- ladles, tongs and chains on pulleys on the shore
	for t = 0, 2 do
		g.bp:beam(-14 + t * 10, gy + 1, -1, -12 + t * 10, gy + 1, -10, 0.3, o(IRON, "fine", { col = false }))
		g.bp:add("ball", 1.6, 0.8, 1.6, -12 + t * 10, gy + 1, -10.5, 0, 0, 0, o(IRON, "fine", { col = false }))
		g.bp:box(0.25, 10, 0.25, -14 + t * 10, gy + 7, 1.5, o(IRON, "fine", { col = false }))
	end
	table.insert(out, g)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 30)
end

local function smelter(env: Env, out: { Build })
	local r = env.T.rooms[4]
	-- the tilted crucible on its scaffold over the pool (-100, 230), pouring the lava fall
	local c = Kit.build(env, "SmelterCrucible", "forge", -100, 244, 0)
	local y = Kit.gy(env, c, 0, 0)
	for _, s in { -1, 1 } do
		c.bp:box(1.4, 22, 1.4, s * 9, y + 11, 0, o(Kit.wood, "shell", { q = false }))
		c.bp:beam(s * 9, y + 4, 0, s * 9, y + 20, -4, 0.6, o(Kit.wood, "detail", { col = false }))
	end
	c.bp:box(20, 1.4, 1.4, 0, y + 21, 0, o(Kit.wood, "detail", { col = false }))
	c.bp:rbox(9, 8, 9, 0, y + 22, -2, -35, 0, 0, o(IRON, "detail", { col = false }))
	glowBox(c.bp, 6, 0.3, 6, 0, y + 25.5, -3.6, Kit.METAL, "forge")
	c.bp:light(0, y + 24, -4, Kit.METAL, 34, 1.6, "lava")
	table.insert(out, c)
	-- the moulds along the gutter cooling from orange to grey
	local m = Kit.build(env, "IngotMoulds", "traces", -130, 221, 0)
	for k = 0, 9 do
		local lx = 26 - k * 5.5
		local wx = -130 + lx
		local f = env.T.floor(wx, 221)
		if f then
			local my = f - m.at.y
			m.bp:box(4, 0.6, 2.4, lx, my + 0.3, 0, o(IRON, "detail", { col = false }))
			local t = k / 9
			if t < 0.5 then
				glowBox(m.bp, 3.2, 0.3, 1.6, lx, my + 0.62, 0, if t < 0.25 then Kit.METAL else EMBER, "ember")
			else
				m.bp:box(3.2, 0.3, 1.6, lx, my + 0.62, 0, o({ c = "#7A7A80", m = "Metal" }, "detail", { col = false }))
			end
		end
	end
	table.insert(out, m)
	-- slag heaps, ingot stacks, a wheelbarrow, the chimney
	for k, a in { 30, 110, 200, 320 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 3, k % 2 == 0)
		if x and z then
			local b = Kit.build(env, `SmelterProps_{k}`, "traces", x, z, a)
			local by = Kit.gy(env, b, 0, 0)
			if k % 2 == 1 then
				b.bp:add(
					"ball",
					7,
					3,
					6,
					0,
					by + 0.6,
					0,
					0,
					0,
					0,
					o({ c = "#8A8A88", m = "Salt" }, "detail", { col = false })
				)
			else
				for t = 0, 3 do
					b.bp:box(
						3,
						0.7,
						1.2,
						0,
						by + 0.35 + t * 0.7,
						(t % 2) * 0.6,
						o(STEEL, if t == 0 then "shell" else "fine", { q = false, col = t == 0 })
					)
				end
				b.bp:rbox(1.6, 0.8, 2.6, 3, by + 0.8, 0, 0, 30, 0, o(Kit.wood, "detail", { col = false }))
			end
			table.insert(out, b)
		end
	end
	local ch = Kit.build(env, "SmelterChimney", "landmark", -128, 236, 0)
	local cy = Kit.gy(env, ch, 0, 0)
	ch.bp:add("cyl", 18, 4, 4, 0, cy + 9, 0, 0, 0, 90, o(STONE, "detail", { col = false }))
	Kit.lifeAt(env.ctx, ch, "smoke", 0, cy + 18, 0, 2)
	table.insert(out, ch)
	Kit.life(env.ctx, "embers", -100, -5, 230, 6)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 24)
end

local function foundry(env: Env, out: { Build })
	local r = env.T.rooms[5]
	-- three unfinished golems chained upright in iron frames by the north wall
	for k, a in { 250, 270, 290 } do
		local x, z = Kit.spot(env, r, math.rad(a), 6, 3.5)
		if x and z then
			local b = Kit.build(
				env,
				`GolemFrame_{k}`,
				"landmark",
				x,
				z,
				math.deg(math.atan2(math.cos(math.rad(a)), math.sin(math.rad(a))))
			)
			local y = Kit.gy(env, b, 0, 0)
			for _, s in { -1, 1 } do
				b.bp:box(0.8, 14, 0.8, s * 3.6, y + 7, 0, o(IRON, "shell", { q = false }))
			end
			b.bp:box(8, 0.8, 0.8, 0, y + 14, 0, o(IRON, "detail", { col = false }))
			b.bp:add("ball", 5, 7, 3.6, 0, y + 7, 0, 0, 0, 0, o(GOLEM, "detail", { col = false }))
			b.bp:add("ball", 2.4, 2.4, 2.4, 0, y + 11.6, 0, 0, 0, 0, o(GOLEM, "detail", { col = false }))
			glowBox(b.bp, 0.4, 4, 0.2, -0.6, y + 7, -1.8, EMBER)
			if k ~= 2 then
				glowBox(b.bp, 0.8, 0.4, 0.2, 0, y + 11.8, -1.2, "#FFD27A")
			end
			for _, s in { -1, 1 } do
				b.bp:beam(s * 3.6, y + 12, 0, s * 1.8, y + 9, 0, 0.25, o(IRON, "fine", { col = false }))
			end
			Kit.clear(env, x, z, 5)
			table.insert(out, b)
		end
	end
	-- the crane holding an arm, moulds of limbs
	local x, z = Kit.spot(env, r, math.rad(180), 6, 3)
	if x and z then
		local b = Kit.build(env, "FoundryCrane", "landmark", x, z, 90)
		local y = Kit.gy(env, b, 0, 0)
		b.bp:box(1.2, 18, 1.2, 0, y + 9, 0, o(Kit.wood, "shell", { q = false }))
		b.bp:beam(0, y + 17, 0, 0, y + 17, -10, 0.8, o(Kit.wood, "detail", { col = false }))
		b.bp:box(0.2, 6, 0.2, 0, y + 14, -10, o(IRON, "fine", { col = false }))
		b.bp:add("cyl", 6, 2, 2, 0, y + 9, -10, 0, 0, 10, o(GOLEM, "detail", { col = false }))
		glowBox(b.bp, 0.3, 4, 0.2, 0.9, y + 9, -10, EMBER)
		for t = 0, 1 do
			b.bp:box(5, 1.6, 2.6, 4, y + 0.8, 2 + t * 3.4, o(STONE, "detail", { col = false }))
		end
		Kit.clear(env, x, z, 4)
		table.insert(out, b)
	end
	-- the torso cooling in the casting pit (103, -190)
	local p = Kit.build(env, "CastingPit", "forge", 103, -190, 0)
	local l = env.T.liquid(103, -190)
	if l then
		local ly = l.level - p.at.y
		p.bp:add("ball", 6, 3, 4, 0, ly + 0.8, 0, 0, 20, 0, o(GOLEM, "detail", { col = false }))
		glowBox(p.bp, 0.4, 0.3, 3.4, 0.8, ly + 2.2, 0, Kit.METAL)
	end
	Kit.lifeAt(env.ctx, p, "steam", 0, 1, 0, 4)
	table.insert(out, p)
	runes(env, out, 5, RUNE, 8, 7)
	runes(env, out, 5, AZGOR, 6, 9)
	Kit.life(env.ctx, "drips", r.x, 18, r.z, 20)
end

local function armory(env: Env, out: { Build })
	local r = env.T.rooms[6]
	local props = {
		-- bearing, kind
		{ a = 30, kind = "rack" },
		{ a = 70, kind = "armour" },
		{ a = 110, kind = "grind" },
		{ a = 150, kind = "crates" },
		{ a = 200, kind = "cart" },
		{ a = 240, kind = "bunks" },
		{ a = 290, kind = "rack" },
		{ a = 330, kind = "barrel" },
	}
	for k, pr in props do
		local a = math.rad(pr.a)
		local x, z = Kit.spot(env, r, a, 5, 3)
		if x and z then
			local b = Kit.build(env, `Armoury_{k}`, "traces", x, z, math.deg(math.atan2(math.cos(a), math.sin(a))))
			local bp = b.bp
			local y = Kit.gy(env, b, 0, 0)
			local kind = pr.kind
			if kind == "rack" then
				bp:box(6, 0.5, 1, 0, y + 3.5, 0, o(Kit.wood, "shell", { q = false }))
				for t = -2, 2 do
					bp:rbox(0.3, 4, 0.3, t * 1.2, y + 2, 0.2, 0, 0, 5, o(Kit.wood, "fine", { col = false }))
					bp:box(1.2, 1, 0.3, t * 1.2, y + 3.8, 0.2, o(STEEL, "fine", { col = false }))
				end
			elseif kind == "armour" then
				for t = -1, 1 do
					bp:box(0.4, 4, 0.4, t * 2.4, y + 2, 0, o(Kit.wood, "detail", { col = false }))
					bp:box(
						1.8,
						2.2,
						1.1,
						t * 2.4,
						y + 4,
						0,
						o(STEEL, if t == 0 then "shell" else "detail", { q = false, col = t == 0 })
					)
					bp:add("ball", 1.2, 1.2, 1.2, t * 2.4, y + 5.7, 0, 0, 0, 0, o(STEEL, "fine", { col = false }))
				end
			elseif kind == "grind" then
				bp:add("cyl", 0.8, 3, 3, 0, y + 2, 0, 0, 0, 0, o(STONE, "shell", { q = false }))
				bp:box(2.4, 1.4, 1, 0, y + 0.7, 0, o(Kit.wood, "detail", { col = false }))
				Kit.lifeAt(env.ctx, b, "sparks", 0.8, 2.6, -1, 1)
			elseif kind == "crates" then
				for t = 0, 2 do
					Kit.crate(bp, t * 3, y + (if t == 2 then 2.2 else 0), if t == 2 then 0 else 0.4, 1, t * 7)
					glowBox(bp, 1, 1.2, 0.1, t * 3, y + 1.2 + (if t == 2 then 2.2 else 0), -1.35, "#B02A1A", "ember") -- the claw
				end
			elseif kind == "cart" then
				for _, s in { -1, 1 } do
					bp:box(0.4, 0.3, 12, s * 1.4, y + 0.15, 0, o(IRON, "detail", { col = false }))
				end
				bp:box(3, 2, 4, 0, y + 1.4, 1, o(IRON, "shell", { q = false }))
				bp:box(6, 9, 0.8, 0, y + 4.5, 6.6, o(IRON, "detail", { col = false })) -- the shut door
				for t = 0, 2 do
					bp:box(6.2, 0.5, 1, 0, y + 1.5 + t * 3, 6.4, o(STEEL, "fine", { col = false }))
				end
			elseif kind == "bunks" then
				for t = 0, 1 do
					bp:box(3, 0.5, 6.4, t * 3.6, y + 1, 0, o(Kit.wood, "shell", { q = false }))
					bp:box(3, 0.5, 6.4, t * 3.6, y + 3.6, 0, o(Kit.wood, "detail", { col = false }))
					bp:box(2.6, 0.3, 5.8, t * 3.6, y + 1.4, 0, o(Kit.cloth, "fine", { col = false }))
				end
				for t = 0, 2 do
					bp:add("cyl", 0.6, 0.5, 0.5, -2 + t * 0.7, y + 0.3, -3, 0, 0, 90, o(STEEL, "fine", { col = false }))
				end
			else
				Kit.barrel(bp, 0, y, 0, 1.2)
				Kit.barrel(bp, 2.8, y, 0.6, 1)
			end
			Kit.clear(env, x, z, 4)
			table.insert(out, b)
		end
	end
	-- torn clan banners on the floor, Azgor's on the walls, warm lanterns
	local d = Kit.build(env, "TornBanners", "traces", r.x, r.z, 0)
	for k = 0, 2 do
		local a = k * 2.1 + 0.6
		local lx, lz = math.cos(a) * 30, math.sin(a) * 30
		d.bp:rbox(3, 0.1, 5, lx, Kit.gy(env, d, lx, lz) + 0.06, lz, 0, k * 50, 0, o(CLAN, "fine", { col = false }))
	end
	table.insert(out, d)
	runes(env, out, 6, AZGOR, 6, 8)
	for k = 0, 3 do
		local x, z = Kit.spot(env, r, k * math.pi / 2 + 0.8, 3, 1, false)
		if x and z then
			local l = Kit.build(env, `ArmouryLantern_{k}`, "lamp", x, z, 0)
			Kit.lantern(l.bp, 0, Kit.gy(env, l, 0, 0), 0, "#FFB25A", 6, "detail")
			table.insert(out, l)
		end
	end
	Kit.life(env.ctx, "drips", r.x, 16, r.z, 20)
end

local function heart(env: Env, out: { Build })
	local r = env.T.rooms[7]
	-- the Heart: molten rock in a cage of chains under the dome, dripping sparks
	local h = Kit.build(env, "ForgeHeart", "forge", r.x, r.z, 0)
	local y = Kit.gy(env, h, 0, 0) + 26
	local top = (Kit.ceil(env, r.x + 6, r.z) or 40) - h.at.y
	h.bp:add("ball", 6, 6, 6, 0, y, 0, 0, 0, 0, Kit.lavaOpts("#FF8A2A", 0, "glow"))
	h.bp:add("ball", 6.6, 6.6, 6.6, 0, y, 0, 0, 0, 0, o(Kit.slag, "detail", { col = false, t = 0.6 }))
	for k = 0, 5 do
		local a = k * math.pi / 3
		h.bp:beam(
			math.cos(a) * 3.6,
			y - 3,
			math.sin(a) * 3.6,
			math.cos(a) * 3.6,
			y + 3,
			math.sin(a) * 3.6,
			0.3,
			o(IRON, "fine", { col = false })
		)
		h.bp:beam(
			math.cos(a) * 3.6,
			y + 3,
			math.sin(a) * 3.6,
			math.cos(a) * 8,
			top,
			math.sin(a) * 8,
			0.3,
			o(IRON, "fine", { col = false })
		)
	end
	h.bp:light(0, y, 0, "#FF8A2A", 60, 2.4, "lava")
	Kit.lifeAt(env.ctx, h, "sparks", 0, y - 4, 0, 2)
	Kit.lifeAt(env.ctx, h, "embers", 0, y - 3, 0, 3)
	table.insert(out, h)
	-- the First Smith's anvil on its dais (110, -58) with the hammer and runes; the bowl of metal (110, 60)
	local a = Kit.build(env, "FirstSmithAnvil", "landmark", 110, -60, 0)
	local ay = Kit.gy(env, a, 0, 0)
	anvil(a.bp, 0, ay, 0, 1.8, 0)
	a.bp:rbox(0.5, 4, 0.5, 0.6, ay + 4.8, 0, 0, 0, 20, o(Kit.wood, "detail", { col = false }))
	a.bp:box(2.4, 1.4, 1.4, 1.3, ay + 6.6, 0, o(STEEL, "detail", { col = false }))
	for k = -2, 2 do
		glowBox(a.bp, 0.8, 0.12, 0.8, k * 1.6, ay + 0.08, 3.6, RUNE)
	end
	Kit.clear(env, 110, -60, 4)
	table.insert(out, a)
	local w = Kit.build(env, "MetalBowl", "forge", 110, 60, 0)
	local wy = Kit.gy(env, w, 0, 0)
	for k = 0, 7 do
		local t = k * math.pi / 4
		w.bp:rbox(
			2.4,
			1.2,
			1,
			math.cos(t) * 5.4,
			wy + 0.6,
			math.sin(t) * 5.4,
			0,
			math.deg(-t) + 90,
			0,
			o(STONE, "detail", { col = false })
		)
	end
	table.insert(out, w)
	-- four kings raising their hammers to the Heart
	local k = Kit.build(env, "HeartKings", "landmark", r.x, r.z, 0)
	for n, deg in { 45, 135, 225, 315 } do
		local t = math.rad(deg)
		local lx, lz = math.cos(t) * 40, math.sin(t) * 40
		king(
			k.bp,
			lx,
			Kit.gy(env, k, lx, lz),
			lz,
			1.3,
			math.deg(math.atan2(math.cos(t), math.sin(t))),
			{ raise = true, chiselled = n % 2 == 0 }
		)
	end
	table.insert(out, k)
	runes(env, out, 7, AZGOR, 10, 8)
end

local function antechamber(env: Env, out: { Build })
	-- Azgor's horned flame over the gate (282, 0) with lava in its grooves and a small fall into a bowl
	local s = Kit.build(env, "AzgorSign", "landmark", 290, 0, 270)
	local y = Kit.gy(env, s, 0, 0)
	local bp = s.bp
	bp:box(16, 14, 1, 0, y + 22, 1, o(STONE, "detail", { col = false }))
	glowBox(bp, 1.2, 9, 0.2, 0, y + 22, 0.4, Kit.LAVA, "lava")
	for _, side in { -1, 1 } do
		bp:rbox(1, 6, 0.2, side * 3, y + 25, 0.4, 0, 0, side * -30, Kit.lavaOpts(Kit.LAVA, 0, "lava"))
		bp:rbox(1, 5, 0.2, side * 5.6, y + 28, 0.4, 0, 0, side * 20, Kit.lavaOpts(Kit.LAVA, 0, "lava")) -- the horns
	end
	bp:box(0.8, 14, 0.2, 0, y + 10.5, 0.3, Kit.lavaOpts(Kit.LAVA, 0.2, "lavafall"))
	bp:light(0, y + 20, -2, AZGOR, 40, 1.8, "lava")
	table.insert(out, s)
	-- kneeling chained kings by the gate, a row of fire baskets, the offering of helmets and broken hammers
	local k = Kit.build(env, "ChainedKings", "landmark", 272, 0, 270)
	for _, side in { -1, 1 } do
		king(k.bp, side * 15, Kit.gy(env, k, side * 15, 0), 0, 1.3, 0, { kneel = true, chiselled = true })
		k.bp:beam(
			side * 15,
			Kit.gy(env, k, side * 15, 0) + 4,
			-1,
			side * 19,
			Kit.gy(env, k, side * 19, 2) + 0.4,
			2,
			0.25,
			o(IRON, "fine", { col = false })
		)
	end
	table.insert(out, k)
	local f = Kit.build(env, "FireBaskets", "lamp", 240, 0, 0)
	for t = 0, 4 do
		for _, side in { -1, 1 } do
			local lx, lz = -30 + t * 14, side * 18
			local fy = Kit.gy(env, f, lx, lz)
			f.bp:box(0.6, 3.4, 0.6, lx, fy + 1.7, lz, o(IRON, "shell", { q = false }))
			Kit.fire(f.bp, lx, fy + 3.8, lz, 1.4, EMBER, "detail")
		end
	end
	table.insert(out, f)
	local o2 = Kit.build(env, "HelmetOffering", "traces", 262, 12, 0)
	local oy = Kit.gy(env, o2, 0, 0)
	for t = 0, 8 do
		local a = t * 2.1
		o2.bp:add(
			"ball",
			1.4,
			1,
			1.4,
			math.cos(a) * (t % 3) * 0.9,
			oy + 0.5 + (t // 3) * 0.6,
			math.sin(a) * (t % 3) * 0.9,
			0,
			t * 40,
			0,
			o(STEEL, "fine", { col = false })
		)
	end
	o2.bp:rbox(0.4, 3, 0.4, 2, oy + 0.3, 1, 0, 30, 85, o(Kit.wood, "fine", { col = false }))
	o2.bp:box(1.6, 1, 1, 3.4, oy + 0.5, 1.4, o(STEEL, "fine", { col = false }))
	table.insert(out, o2)
	Kit.life(env.ctx, "haze", 270, 0.5, 0, 8)
	runes(env, out, 8, AZGOR, 10, 9)
	Kit.life(env.ctx, "drips", 220, 20, 0, 20)
end

function Forge.all(env: Env, out: { Build })
	gate(env, out)
	greatForge(env, out)
	bridges(env, out)
	gullet(env, out)
	smelter(env, out)
	foundry(env, out)
	armory(env, out)
	heart(env, out)
	antechamber(env, out)
end

return Forge
