--!strict
-- Cave mouths of the Ashen Wastes (S46), built where Data/Areas/ashen puts the entrances (the layout adds the
-- portal, the sign with the cave's name and levels, and the map icon):
--   * the Abandoned Mine: a dwarven adit in the ridge's wall, framed with beams, rails running out onto the slope,
--     overturned carts, a headframe with a broken wheel, spoil heaps glinting with silver, dwarven runes smeared
--     with orc paint, orc banners and a kennel of hyenas,
--   * the Wyvern Lair: a huge scorched mouth in the mesa's wall, a fan of soot over it, a heap of bones and a cracked
--     giant egg on the threshold, deep claw furrows, scorpion tracks in the sand,
--   * Deepforge: the dwarven gate in the Forge Mountain (the end of the main road): two carved kings with hammers,
--     glowing runes over it, doors ajar with an orange glow from inside, smoke from chimneys in the rock, a thin stream
--     of molten metal from under a statue's foot into a small pool of slag. Pure.

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
	local bp = b.bp
	local wood = Kit.timber
	-- the adit: a dark hole framed by beams, set into the rock behind
	bp:box(26, 18, 8, 0, 7, 9, o(Props.ash, "shell", { q = true }))
	bp:box(11, 12, 1, 0, 5.4, 4.6, o(Kit.dark, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:box(1.6, 13, 1.6, side * 6.2, 5.8, 3.6, o(wood, "shell", { q = false }))
		bp:rbox(1, 9, 1, side * 4.6, 4, 2.6, 0, 0, side * 14, o(wood, "detail", { col = false }))
	end
	bp:box(15, 1.8, 2, 0, 12.6, 3.6, o(wood, "shell", { q = false }))
	-- dwarven runes on the lintel smeared with red orc paint
	for k = -2, 2 do
		bp:box(1, 1, 0.1, k * 2.2, 12.6, 2.55, o({ c = "#C9A45C", m = "SmoothPlastic" }, "fine"))
	end
	bp:rbox(9, 1.2, 0.12, 0, 12.4, 2.5, 0, 0, 8, o({ c = "#8A2A1E", m = "SmoothPlastic" }, "fine", { t = 0.2 }))
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
	for k, p in { { -7, -14, 70 }, { 6, -20, 200 } } do
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
	for k, p in { { -14, -4 }, { -18, -14 } } do
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
		bp:box(0.3, 9, 0.3, side * 9, Kit.gy(ctx, b, side * 9, -2) + 4.5, -2, o(wood, "detail", { col = false }))
		bp:box(
			0.15,
			3.4,
			2.4,
			side * 9,
			Kit.gy(ctx, b, side * 9, -2) + 7,
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
	local bp = b.bp
	-- the huge scorched mouth in the wall and the fan of soot over it
	bp:box(34, 26, 8, 0, 11, 10, o({ c = "#6E2F2A", m = "Sandstone" }, "shell", { q = true }))
	bp:add("ball", 20, 18, 4, 0, 7, 5.4, 0, 0, 0, o(Kit.dark, "shell", { q = false }))
	for k = -2, 2 do
		bp:rbox(5, 14, 0.2, k * 4.6, 20, 5.6, 0, 0, k * 14, o(Props.soot, "detail", { col = false, t = 0.1 }))
	end
	-- claw furrows down the wall
	for _, side in { -1, 1 } do
		for k = 0, 3 do
			bp:rbox(
				0.5,
				9,
				0.2,
				side * (12 + k * 1.2),
				10,
				5.7,
				0,
				0,
				side * 8,
				o({ c = "#3A1A16", m = "Slate" }, "fine")
			)
		end
	end
	-- bones and the cracked giant egg on the threshold
	for k, p in { { -8, -6 }, { 6, -9 }, { 0, -14 }, { -12, -12 } } do
		Kit.bones(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], 5)
		if k == 2 then
			Props.carcass(bp, p[1], Kit.gy(ctx, b, p[1], p[2]), p[2], 40)
		end
	end
	local ey = Kit.gy(ctx, b, 9, -2)
	bp:add(
		"ball",
		4,
		5.4,
		4,
		9,
		ey + 2.2,
		-2,
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
			12 + k * 0.8,
			ey + 0.2,
			-4 + k,
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
	local bp = b.bp
	local stone = { c = "#4E4A48", m = "Slate" }
	local dressed = { c = "#5E5856", m = "Cobblestone" }
	-- the gate's frame of dressed stone set into the mountain
	bp:box(30, 30, 8, 0, 13, 11, o(stone, "shell", { q = true }))
	bp:box(14, 16, 2, 0, 7, 7, o(dressed, "shell", { q = true }))
	bp:box(10, 13, 0.6, 0, 5.6, 5.9, {
		c = "#FF8A2A",
		m = "Neon",
		lod = "shell",
		col = false,
		q = false,
		t = 0.2,
		tag = "forge",
		jitter = 0,
	})
	-- doors ajar
	for _, side in { -1, 1 } do
		bp:rbox(5, 13, 0.8, side * 5.6, 5.6, 4.2, 0, side * -35, 0, o(Props.ironDark, "detail", { col = false }))
	end
	bp:light(0, 6, 2, "#FF8A2A", 36, 2, "fire")
	-- glowing runes over the gate
	for k = -3, 3 do
		bp:box(1.2, 1.6, 0.2, k * 2, 17, 5.9, {
			c = "#FFB040",
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
	end
	bp:box(18, 2, 2.4, 0, 15.4, 6.4, o(dressed, "shell", { q = false }))
	-- two carved kings with hammers
	for _, side in { -1, 1 } do
		bp:push(side * 12, 0, 4, 0, 0, 0)
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
