--!strict
-- Cave mouths of the Ashen Wastes (S46), built where Data/Areas/ashen puts the entrances (the layout adds the
-- portal, the sign with the cave's name and levels, and the map icon):
--   * the Abandoned Mine: a dwarven adit in the ridge's wall, framed with beams, rails running out onto the slope,
--     overturned carts, a headframe with a broken wheel, spoil heaps glinting with silver, dwarven runes smeared
--     with orc paint, orc banners and a kennel of hyenas,
--   * the Wyvern Lair: a huge scorched mouth in the mesa's wall, a fan of soot over it, a heap of bones and a cracked
--     giant egg on the threshold, deep claw furrows, scorpion tracks in the sand,
--   * Deepforge: the dwarven gate in the Forge Mountain (the end of the main road): two carved kings with hammers,
--     glowing runes over it, the doors swung open and orange glow seams around the gateway, smoke from chimneys in
--     the rock, a thin stream of molten metal from under a statue's foot into a small pool of slag. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Mouths = {}

type Build = Kit.Build

local function cave(env: Env.Env, id: string)
	for _, c in env.areas.caves do
		if c.cave == id then
			return c
		end
	end
	error(`no cave {id}`)
end

local function mine(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "ashen_mine")
	Env.clear(env, c.x, c.z, 30)
	local b = Kit.build(ctx, "mineMouth", "cave", c.x, c.z, c.rot)
	b.frames = "ashen_ashen_mine"
	local bp = b.bp
	local wood = Kit.timber
	-- the adit: a dark hole framed by beams, set into the rock behind; W28: as wide and tall as the portal's arch in
	-- front of it (11 x 12 before, the arch 14.5 x 18 stood over it); W31 (Studio review: the painted arch is 16 studs
	-- wide, the adit was 15): the adit is the portals' dark hole (Kit.portalHole), the posts and their braces beside
	-- the painted pillars; W31 fix: round the painted arch's real footprint (21 x 16.5 with its base slab,
	-- Data/Portals.ARCH.model). Studio: the ridge's foot buried the hole (Data/Terrain/ashen flattens it now), the rock
	-- round the adit fills the notch that leaves in the ridge; the lintel with its smeared runes behind the arch's
	-- footprint (its red streak cut across the painted pillar's top)
	bp:box(34, 30, 14, 0, 13, 16.4, o(Props.ash, "shell", { q = true }))
	Kit.portalHole(bp)
	for _, side in { -1, 1 } do
		bp:box(1.6, 19.4, 1.6, side * 11.6, 9, 9.6, o(wood, "shell", { q = false }))
		bp:rbox(1, 9, 1, side * 12.8, 4, 8.8, 0, 0, side * 14, o(wood, "detail", { col = false }))
	end
	bp:box(25, 1.8, 2, 0, 19.6, 9.8, o(wood, "shell", { q = false }))
	-- dwarven runes on the lintel smeared with red orc paint
	for k = -2, 2 do
		bp:box(1, 1, 0.1, k * 2.2, 19.6, 8.75, o({ c = "#C9A45C", m = "SmoothPlastic" }, "fine"))
	end
	bp:rbox(7, 1, 0.12, 0, 19.8, 8.62, 0, 0, 6, o({ c = "#8A2A1E", m = "SmoothPlastic" }, "fine", { t = 0.2 }))
	-- rails out onto the slope, overturned carts
	for _, side in { -1, 1 } do
		bp:box(
			0.3,
			0.3,
			26,
			side * 1.6,
			Kit.gy(ctx, b, 0, -10) + 0.3,
			-10,
			o(Props.ironDark, "detail", { col = false })
		)
	end
	for k = 0, 8 do
		bp:box(4.4, 0.3, 0.8, 0, Kit.gy(ctx, b, 0, -k * 3) + 0.15, -k * 3, o(wood, "fine"))
	end
	for k, p in { { -8, -18, 70 }, { 6, -20, 200 } } do
		bp:push(p[1], Kit.gy(ctx, b, p[1], p[2]) + 1.2, p[2], 0, p[3], if k == 1 then 90 else 0)
		bp:box(3, 2, 4, 0, 0.6, 0, o(Props.ironDark, "detail", { col = false }))
		bp:box(2.6, 1, 3.6, 0, 1.2, 0, o({ c = "#8A8A90", m = "Slate" }, "fine")) -- ore
		bp:pop()
	end
	-- the headframe with its broken wheel
	local hx, hz = 14, -6
	local hy = Kit.gy(ctx, b, hx, hz)
	for _, c2 in { { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } } do
		bp:rbox(
			0.9,
			16,
			0.9,
			hx + c2[1] * 0.7,
			hy + 7.6,
			hz + c2[2] * 0.7,
			c2[2] * 2,
			0,
			-c2[1] * 2,
			o(wood, "shell", { q = false })
		)
	end
	bp:add("cyl", 0.8, 7, 7, hx, hy + 16, hz, 0, 0, 0, o(wood, "detail", { col = false }))
	bp:rbox(3.6, 0.8, 0.8, hx + 2, hy + 14, hz, 0, 0, 40, o(wood, "detail", { col = false }))
	-- spoil heaps glinting with silver
	for k, p in { { -17, -3 }, { -18, -14 } } do
		local y = Kit.gy(ctx, b, p[1], p[2])
		bp:add(
			"ball",
			9,
			4,
			7,
			p[1],
			y + 0.6,
			p[2],
			0,
			k * 40,
			0,
			o({ c = "#5A5652", m = "Slate" }, "detail", { col = false })
		)
		for n = 1, 3 do
			bp:box(0.6, 0.4, 0.6, p[1] + n - 2, y + 2.4, p[2] + (n % 2), o({ c = "#D8DCE4", m = "Metal" }, "fine"))
		end
	end
	-- orc banners and the hyena kennel
	for _, side in { -1, 1 } do
		bp:box(0.3, 9, 0.3, side * 12, Kit.gy(ctx, b, side * 12, -2) + 4.5, -2, o(wood, "detail", { col = false }))
		bp:box(
			0.15,
			3.4,
			2.4,
			side * 12,
			Kit.gy(ctx, b, side * 12, -2) + 7,
			-0.8,
			o({ c = "#B5462B", m = "Fabric" }, "fine", { tag = "flag" })
		)
	end
	for k = 0, 7 do
		local a = k * math.pi / 4
		local lx, lz = -14 + math.cos(a) * 5, -22 + math.sin(a) * 5
		bp:add(
			"cyl",
			4,
			0.8,
			0.8,
			lx,
			Kit.gy(ctx, b, lx, lz) + 1.6,
			lz,
			0,
			0,
			90,
			o(Kit.darkBark, "detail", { col = false })
		)
	end
	Props.gnawed(bp, -14, Kit.gy(ctx, b, -14, -22), -22, 4)
	table.insert(out, b)
end

local function lair(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "ashen_lair")
	Env.clear(env, c.x, c.z, 30)
	local b = Kit.build(ctx, "lairMouth", "cave", c.x, c.z, c.rot)
	b.frames = "ashen_ashen_lair"
	local bp = b.bp
	-- the huge scorched mouth in the wall and the fan of soot over it
	-- (W31 fix: round the painted arch's real footprint, 21 x 16.5 with its base slab, Data/Portals.ARCH.model)
	-- (Studio: the mesa's foot buried the hole; Data/Terrain/ashen flattens it now, the rock fills the notch that leaves)
	bp:box(36, 34, 14, 0, 15, 17.4, o({ c = "#6E2F2A", m = "Sandstone" }, "shell", { q = true }))
	-- W28: over the arch; W31: behind it, the portals' dark hole in its middle (Kit.portalHole)
	bp:add("ball", 22, 24, 4, 0, 9, 11.4, 0, 0, 0, o(Kit.HOLE_BLACK, "shell", { q = false, jitter = 0 }))
	Kit.portalHole(bp)
	for k = -2, 2 do
		bp:rbox(5, 14, 0.2, k * 4.6, 20, 10.25, 0, 0, k * 14, o(Props.soot, "detail", { col = false, t = 0.1 }))
	end
	-- W31 (Studio: no frame round the arch, only the hill): the ribs of a dead wyvern meeting over the arch, beside
	-- its real footprint, a skull at their crown (like the frame round the lair's exit, CaveDress/Lair)
	local bone = { c = "#D8CDB4", m = "SmoothPlastic" }
	for _, side in { -1, 1 } do
		for k = 0, 1 do
			local z = -1.2 + k * 2.4
			local w = 1.8 - k * 0.3
			local rib = if k == 0
				then o(bone, "shell", { col = false, q = false })
				else o(bone, "detail", { col = false, q = false })
			bp:beam(side * (13.4 + k), -0.5, z, side * (12.8 + k), 19.2, z, w, rib)
			bp:beam(
				side * (12.8 + k),
				19.2,
				z,
				side * (3.6 + k),
				23 + k * 0.4,
				z,
				w * 0.9,
				o(bone, "detail", { col = false })
			)
		end
	end
	Kit.skull(bp, 0, 22, -1.8, 2.4, 0)
	-- claw furrows down the wall
	for _, side in { -1, 1 } do
		for k = 0, 3 do
			bp:rbox(
				0.5,
				9,
				0.2,
				side * (12 + k * 1.2),
				10,
				10.25,
				0,
				0,
				side * 8,
				o({ c = "#3A1A16", m = "Slate" }, "fine")
			)
		end
	end
	-- bones and the cracked giant egg on the threshold
	for k, p in { { -8, -6 }, { 14, -12 }, { 0, -16 }, { -13, -12 } } do
		Kit.bones(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], 5)
		if k == 2 then
			Props.carcass(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], 40)
		end
	end
	-- W28: the egg beside the portal's arch (it stood in its pillar)
	local ey = Kit.gy(ctx, b, 17, -5)
	bp:add(
		"ball",
		4,
		5.4,
		4,
		17,
		ey + 2.2,
		-5,
		0,
		0,
		0,
		o({ c = "#C9B79A", m = "SmoothPlastic" }, "detail", { col = false })
	)
	for k = 0, 3 do
		bp:rbox(
			2.2,
			0.3,
			1.6,
			20 + k * 0.8,
			ey + 0.2,
			-7 + k,
			k * 30,
			k * 40,
			0,
			o({ c = "#C9B79A", m = "SmoothPlastic" }, "fine")
		)
	end
	-- scorpion tracks in the sand
	for k = 0, 7 do
		bp:box(
			0.3,
			0.08,
			0.3,
			-16 + k * 1.6,
			Kit.gy(ctx, b, -16 + k * 1.6, -18) + 0.05,
			-18 + (k % 2) * 0.8,
			o(Kit.dark, "fine")
		)
	end
	Kit.lifeAt(ctx, b, "vultures", 0, 46, 10, 22)
	table.insert(out, b)
end

-- Deepforge: the dwarven gate, the culmination of the main road.
local function forgeGate(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local c = cave(env, "ashen_cave")
	Env.clear(env, c.x, c.z, 34)
	local b = Kit.build(ctx, "forgeGate", "cave", c.x, c.z, c.rot)
	b.frames = "ashen_ashen_cave"
	local bp = b.bp
	local stone = { c = "#4E4A48", m = "Slate" }
	local dressed = { c = "#5E5856", m = "Cobblestone" }
	-- the gate's frame of dressed stone set into the mountain
	bp:box(36, 30, 8, 0, 13, 15, o(stone, "shell", { q = true }))
	-- W28: the glowing gateway as wide and tall as the portal's arch in front of it (10 x 13 before); W31 (Studio
	-- review: the flat bright Neon backdrop hid the portal's violet and its label, a door ajar stood between the
	-- painted pillar and the ellipse): the gateway is the portals' dark hole (Kit.portalHole) and the forge's glow
	-- seams around its edges, beside and over the painted arch; the iron doors swung wide open beside it. W31 fix: all
	-- of it round the painted arch's real footprint (21 x 16.5 with its base slab, Data/Portals.ARCH.model)
	bp:box(24, 22, 2, 0, 10, 10.4, o(dressed, "shell", { q = true }))
	Kit.portalHole(bp)
	local seam = o(
		{ c = "#FF8A2A", m = "Neon" },
		"detail",
		{ col = false, q = false, t = 0.15, tag = "forge", jitter = 0 }
	)
	for _, side in { -1, 1 } do
		bp:box(0.8, 16.8, 0.4, side * 8.9, 8.4, 8.75, seam)
	end
	bp:box(18.6, 0.8, 0.4, 0, 16.5, 8.75, seam)
	-- the doors swung wide open, along the gateway's sides
	for _, side in { -1, 1 } do
		bp:rbox(6.5, 18.6, 0.8, side * 12, 9.3, 5.2, 0, 90, 0, o(Props.ironDark, "detail", { col = false }))
	end
	bp:light(0, 8, 2, "#FF8A2A", 36, 2, "fire")
	-- glowing runes over the gate
	for k = -3, 3 do
		bp:box(1.2, 1.6, 0.2, k * 2, 23, 10.9, {
			c = "#FFB040",
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
	end
	bp:box(26, 2, 2.4, 0, 20.6, 9.6, o(dressed, "shell", { q = false }))
	-- two carved kings with hammers (W31: their hammers clear of the open doors)
	for _, side in { -1, 1 } do
		bp:push(side * 17.5, 0, 4, 0, 0, 0)
		bp:box(6, 2, 6, 0, 1, 0, o(dressed, "shell", { q = false }))
		bp:box(4.4, 11, 3.4, 0, 7.5, 0, o(stone, "shell", { q = false }))
		bp:add("ball", 3, 3.2, 3, 0, 14.6, 0, 0, 0, 0, o(stone, "detail", { col = false }))
		bp:box(3.6, 3, 1.6, 0, 12.4, -1.4, o(stone, "detail", { col = false })) -- the beard
		bp:rbox(1, 9, 1, side * -2.6, 9, -1.6, -20, 0, 0, o(Kit.darkBark, "detail", { col = false }))
		bp:box(4, 2.4, 2.4, side * -2.6, 13.4, -3, o(Props.ironDark, "detail", { col = false }))
		bp:pop()
	end
	-- chimneys in the rock
	for k, p in { { -8, 32, 16 }, { 9, 34, 22 } } do
		bp:box(3, 4, 3, p[1], p[2], p[3], o(stone, "shell", { q = false, tag = "smoke" }))
		Kit.lifeAt(ctx, b, "smokeColumn", p[1], p[2] + 3, p[3], 3)
		if k == 1 then
			Kit.lifeAt(ctx, b, "embers", p[1], p[2] + 2, p[3], 2)
		end
	end
	table.insert(out, b)

	-- the stream of molten metal from under the south king's foot into a little pool of slag
	local sx, sz = c.x - 6, c.z + 30
	Env.clear(env, sx, sz, 10)
	local m = Kit.build(ctx, "SlagPool", "vent", sx, sz, 0)
	local mp = m.bp
	mp:add("ball", 7, 0.6, 6, 0, 0.2, 0, 0, 0, 0, o(Props.basalt, "detail", { col = false }))
	mp:add("ball", 4.4, 0.4, 3.6, 0, 0.45, 0, 0, 0, 0, {
		c = "#FFB040",
		m = "Neon",
		lod = "detail",
		col = false,
		q = false,
		t = 0.2,
		tag = "lava",
		jitter = 0,
	})
	for k = 0, 3 do
		local lz = -4 - k * 3
		mp:box(1, 0.3, 3.2, 1.6 - k * 0.4, Kit.gy(ctx, m, 1.6 - k * 0.4, lz) + 0.25, lz, {
			c = "#FFB040",
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "lava",
			jitter = 0,
		})
	end
	mp:light(0, 2, 0, "#FF8A2A", 18, 1, "lava")
	Kit.lifeAt(ctx, m, "embers", 0, 0.6, 0, 3)
	table.insert(out, m)
end

function Mouths.all(env: Env.Env, out: { Build })
	mine(env, out)
	lair(env, out)
	forgeGate(env, out)
end

return Mouths
