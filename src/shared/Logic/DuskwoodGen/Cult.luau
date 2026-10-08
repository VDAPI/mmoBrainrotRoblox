--!strict
-- Cultist Village (29–37, more gold) and the Cultists' Barrow (S45).
--   * a clearing in a palisade of black stakes with violet rags, the gate with a bell towards the road,
--   * the ritual circle (the landmark): runestones whose runes glow at night, the altar with violet fire, a dagger
--     and dried blood, bowls of coins,
--   * the cult hall (a long house with a steep black roof, banners with an eye, candles by the door), huts with
--     pointed roofs, and the lure: the tithe, crates and sacks of coins piled before the hall,
--   * serpents: the fenced serpent pond, skins on drying racks, eggs in reed nests, a carved serpent totem,
--   * the Cultists' Barrow: an overgrown mound with a stone entrance (a dolmen) and a ring of menhirs with violet
--     candles and rags (the cave's portal stands in the entrance). Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")
local Structures = require("../WorldGen/Structures")

local o = Kit.o

local Cult = {}

type Build = Kit.Build
type BP = Kit.BP

local BLACK_WOOD = { c = "#221D1E", m = "Wood" }
local ROOF = { c = "#16141A", m = "Slate" }
local WALL = { c = "#3A3438", m = "WoodPlanks" }
local RUNE = { c = "#545058", m = "Slate" }
local R = 72 -- palisade radius

local function violetCap(bp: BP, x: number, y: number, z: number, k: number)
	if k % 2 == 0 then
		bp:box(0.1, 1.6, 1.2, x, y - 0.9, z + 0.6, o(Kit.violet, "fine", { tag = "flag" }))
	else
		Kit.skull(bp, x, y, z, 0.9)
	end
end

-- Hut with a pointed roof (two steep planes), door towards local -Z of a sub-frame.
local function hut(ctx: Kit.Ctx, b: Build, x: number, z: number, yaw: number)
	local bp = b.bp
	local gy = Kit.gy(ctx, b, x, z)
	bp:push(x, gy, z, 0, yaw, 0)
	bp:box(8, 5, 8, 0, 2, 0, o(WALL, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:rbox(9.4, 0.5, 7, side * 2.4, 6.9, 0, 0, 0, side * -62, o(ROOF, "shell", { q = false }))
	end
	bp:box(2.2, 3.6, 0.3, 0, 1.8, -4.1, o(Kit.dark, "detail", { col = false }))
	bp:box(1.2, 1.2, 0.3, 2.5, 3, -4.1, {
		c = "#3A2A20",
		m = "Glass",
		lod = "detail",
		col = false,
		tag = "lamp",
		jitter = 0,
		fxColor = "#C08AFF",
	})
	Props.ragPole(bp, 4.6, 0, -4.2, 5, Kit.violet)
	bp:pop()
end

local function village(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.cultVillage
	Env.clear(env, s.x, s.z, 78)
	local b = Kit.build(ctx, "CultVillage", "camp", s.x, s.z, 0)
	local bp = b.bp
	-- the palisade, its gate towards the village road (500, -462)
	local door = math.atan2(-462 - s.z, 500 - s.x)
	Structures.palisade(ctx, b, R, 24, door, 0.44, 7.5, BLACK_WOOD, "#241E20", violetCap)
	-- the gate's bell on a beam between the posts
	local gx1, gz1 = math.cos(door - 0.22) * R, math.sin(door - 0.22) * R
	local gx2, gz2 = math.cos(door + 0.22) * R, math.sin(door + 0.22) * R
	local gy = Kit.gy(ctx, b, (gx1 + gx2) / 2, (gz1 + gz2) / 2)
	bp:beam(gx1, gy + 10, gz1, gx2, gy + 10, gz2, 1, o(BLACK_WOOD, "detail", { col = false }))
	bp:add(
		"ball",
		2,
		2.4,
		2,
		(gx1 + gx2) / 2,
		gy + 8.2,
		(gz1 + gz2) / 2,
		0,
		0,
		0,
		o({ c = "#6A5A3A", m = "CorrodedMetal" }, "detail", { col = false, tag = "flag" })
	)
	-- huts around the clearing
	for i, a in { -2.75, -2.05, -1.4, 1.35, 2.75 } do
		local hx, hz = math.cos(a) * 50, math.sin(a) * 50
		hut(ctx, b, hx, hz, math.deg(math.atan2(hx, hz)) + (i % 2) * 12)
		Kit.rect(ctx, "building", s.x + hx, s.z + hz, 8, 8, 0)
	end
	-- the bonfire in the middle, fires, cages, firewood, racks and barrels in the yard
	local cy = Kit.gy(ctx, b, 0, 0)
	Kit.campfire(bp, 0, cy, 0, "detail")
	for k = 0, 5 do
		local a = k * math.pi / 3
		bp:beam(
			math.cos(a) * 2.6,
			cy,
			math.sin(a) * 2.6,
			math.cos(a) * 0.4,
			cy + 6,
			math.sin(a) * 0.4,
			0.7,
			o(Kit.charred, "shell", { q = false })
		)
	end
	Kit.campfire(bp, -26, Kit.gy(ctx, b, -26, 20), 20, "detail")
	Kit.campfire(bp, 16, Kit.gy(ctx, b, 16, 34), 34, "detail")
	for k, p in { { -30, -14 }, { -20, -30 } } do
		local gy = Kit.gy(ctx, b, p[1], p[2])
		bp:box(5, 0.5, 5, p[1], gy + 0.25, p[2], o(BLACK_WOOD, "shell", { q = true }))
		bp:box(5, 0.5, 5, p[1], gy + 6.2, p[2], o(BLACK_WOOD, "detail", { col = false }))
		for i = 0, 7 do
			local bx = p[1] - 2.3 + (i % 4) * 1.53
			local bz = p[2] + (if i < 4 then -2.3 else 2.3)
			bp:box(0.3, 6, 0.3, bx, gy + 3.2, bz, o(Kit.iron, "detail", { col = false }))
		end
		Kit.bones(bp, p[1], gy + 0.5, p[2], 2 + k)
	end
	for _, p in { { 30, -8 }, { -8, 30 } } do
		local gy = Kit.gy(ctx, b, p[1], p[2])
		for i = 0, 5 do
			bp:add(
				"cyl",
				4,
				0.9,
				0.9,
				p[1],
				gy + 0.45 + math.floor(i / 3) * 0.85,
				p[2] + (i % 3) * 0.9 - 0.9,
				0,
				90,
				0,
				o(Kit.timber, "detail", { col = false })
			)
		end
	end
	Props.rack(bp, -36, Kit.gy(ctx, b, -36, 6), 6, 80, Kit.hide, 3)
	for k = 0, 2 do
		Props.barrel(bp, 24 + k * 2.2, Kit.gy(ctx, b, 24 + k * 2.2, 14), 14)
	end
	for i = 0, 5 do
		local a = i * 1.05 + 0.3
		Props.ragPole(
			bp,
			math.cos(a) * 30,
			Kit.gy(ctx, b, math.cos(a) * 30, math.sin(a) * 30),
			math.sin(a) * 30,
			7,
			Kit.violet
		)
	end
	Kit.ring(ctx, "wall", s.x, s.z, R, 24, 2)
	table.insert(out, b)
end

local function hall(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "cultHall", "home", 22)
	local bp = b.bp
	local lo = math.huge
	for _, c in { { -8, -16 }, { 8, -16 }, { 8, 16 }, { -8, 16 } } do
		lo = math.min(lo, Kit.gy(ctx, b, c[1], c[2]))
	end
	local base = lo - 0.6
	local h = 6
	-- walls (door gap in the front) and the steep black roof
	bp:box(5.5, h, 1.2, -4.25, base + h / 2, -15, o(WALL, "shell", { q = true }))
	bp:box(5.5, h, 1.2, 4.25, base + h / 2, -15, o(WALL, "shell", { q = true }))
	bp:box(14, h, 1.2, 0, base + h / 2, 15, o(WALL, "shell", { q = true }))
	for _, side in { -1, 1 } do
		bp:box(1.2, h, 30, side * 7, base + h / 2, 0, o(WALL, "shell", { q = true }))
		bp:rbox(11.4, 0.6, 32, side * 4, base + h + 4.4, 0, 0, 0, side * -58, o(ROOF, "shell", { q = false }))
	end
	for _, z in { -15, 15 } do
		bp:add(
			"wedge",
			14,
			9,
			1.2,
			0,
			base + h + 4.5,
			z,
			0,
			if z > 0 then 180 else 0,
			0,
			o(WALL, "detail", { col = false })
		)
	end
	bp:box(3, 4.6, 0.4, 0, base + 2.3, -15.4, o(Kit.dark, "detail", { col = false }))
	-- banners with the eye, candles by the door
	for _, side in { -1, 1 } do
		bp:box(2.6, 5, 0.15, side * 4.4, base + h - 1, -15.8, o(Kit.violet, "detail", { col = false, tag = "flag" }))
		bp:add("cyl", 0.1, 1.4, 1.4, side * 4.4, base + h - 0.6, -15.9, 0, 90, 0, o(Kit.bone, "fine"))
		bp:add("cyl", 0.12, 0.6, 0.6, side * 4.4, base + h - 0.6, -15.96, 0, 90, 0, o(Kit.dark, "fine"))
		for k = 0, 2 do
			Kit.candle(bp, side * (2 + k * 0.5), base, -16.4 - k * 0.4, 0.6 + k * 0.3, Kit.VIOLET)
		end
	end
	-- the tithe before the hall: crates, sacks and coins
	for k = 0, 5 do
		local lx, lz = -5 + (k % 3) * 2.8, -21 - math.floor(k / 3) * 2.8
		Props.crate(bp, lx, Kit.gy(ctx, b, lx, lz) + (if k == 4 then 2.4 else 0), lz, 2.4, k * 15)
	end
	Props.crate(bp, 1.4, Kit.gy(ctx, b, 1.4, -24), -24, 2.6, 30, "shell")
	for k = 0, 3 do
		local lx, lz = 4 + k * 1.6, -20 - (k % 2) * 2
		Props.sack(bp, lx, Kit.gy(ctx, b, lx, lz), lz, true)
	end
	Props.coins(bp, 0, Kit.gy(ctx, b, 0, -19), -19, 12)
	Kit.rect(ctx, "building", b.at.x, b.at.z, 14, 30, b.at.rot)
	table.insert(out, b)
end

local function ritualCircle(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "ritualCircle", "landmark", 18)
	local bp = b.bp
	for i = 0, 8 do
		local a = i * 2 * math.pi / 9
		local lx, lz = math.cos(a) * 12, math.sin(a) * 12
		local gy = Kit.gy(ctx, b, lx, lz)
		local yaw = -math.deg(a) + 90
		local h = 6 + (i % 3) * 1.2
		bp:add("box", 2.4, h, 1.4, lx, gy + h / 2 - 0.6, lz, 0, yaw, 0, o(RUNE, "shell", { q = true }))
		-- the runes glow violet at night
		bp:push(lx, gy, lz, 0, yaw, 0)
		for k = 0, 2 do
			bp:box(0.5, 0.7, 0.1, 0, h * 0.35 + k * 1.1, -0.75, {
				c = "#B060FF",
				m = "Neon",
				lod = "detail",
				col = false,
				tag = "lamp",
				jitter = 0,
				fxColor = Kit.VIOLET,
			})
		end
		bp:pop()
	end
	-- the altar with violet fire, a dagger, dried blood and coin bowls
	local ay = Kit.gy(ctx, b, 0, 0)
	bp:box(5, 2.6, 3, 0, ay + 1, 0, o({ c = "#3A3640", m = "Slate" }, "shell", { q = true }))
	Kit.fire(bp, 0, ay + 2.6, 0.3, 1.6, Kit.VIOLET, "detail")
	bp:rbox(0.25, 0.1, 1.8, 1.6, ay + 2.35, -0.9, 0, 30, 0, o({ c = "#B8B8C0", m = "Metal" }, "fine"))
	bp:box(2, 0.05, 1.4, -1.2, ay + 2.32, -0.6, o({ c = "#3A0E10", m = "SmoothPlastic" }, "fine"))
	bp:add("ball", 3.4, 0.08, 2.6, 2.6, ay + 0.06, -3.4, 0, 0, 0, o({ c = "#3A0E10", m = "SmoothPlastic" }, "fine"))
	for _, side in { -1, 1 } do
		bp:add(
			"cyl",
			0.6,
			1.6,
			1.6,
			side * 3.6,
			ay + 0.3,
			-2.4,
			0,
			0,
			90,
			o({ c = "#6A5A3A", m = "Metal" }, "detail", { col = false })
		)
		Props.coins(bp, side * 3.6, ay + 0.6, -2.4, 4)
		for k = 0, 1 do
			Kit.candle(bp, side * (1.6 + k), ay + 2.6, 1.2, 0.5 + k * 0.4, Kit.VIOLET)
		end
	end
	Kit.circle(ctx, "ritual", b.at.x, b.at.z, 13)
	Kit.lifeAt(ctx, b, "spores", 0, 5, 0, 8)
	table.insert(out, b)
end

local function serpentPond(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "serpentPond", "landmark", 22)
	local bp = b.bp
	-- the fence of stakes around the pond
	for i = 0, 31 do
		local a = i * 2 * math.pi / 32
		if i ~= 24 and i ~= 25 then
			local lx, lz = math.cos(a) * 18, math.sin(a) * 18
			bp:rbox(
				0.5,
				3.6,
				0.5,
				lx,
				Kit.gy(ctx, b, lx, lz) + 1.4,
				lz,
				bp.rng:float(-5, 5),
				0,
				bp.rng:float(-5, 5),
				o(BLACK_WOOD, "detail", { col = false })
			)
		end
	end
	-- skins on racks, eggs in reed nests, the serpent totem
	Props.rack(bp, -12, Kit.gy(ctx, b, -12, -20), -22, 15, { c = "#7A8A5A", m = "Fabric" }, 4)
	Props.rack(bp, 8, Kit.gy(ctx, b, 8, -23), -24, -20, { c = "#5A6A4A", m = "Fabric" }, 3)
	for _, p in { { 15, 6 }, { -16, 8 } } do
		local ny = Kit.gy(ctx, b, p[1], p[2])
		bp:add("ball", 3.4, 1, 3.4, p[1], ny + 0.3, p[2], 0, 0, 0, o(Kit.straw, "detail", { col = false }))
		for k = 0, 3 do
			bp:add(
				"ball",
				0.8,
				1,
				0.8,
				p[1] + math.cos(k * 1.6) * 0.8,
				ny + 0.9,
				p[2] + math.sin(k * 1.6) * 0.8,
				0,
				0,
				0,
				o({ c = "#DCD6C0", m = "SmoothPlastic" }, "fine")
			)
		end
	end
	local ty = Kit.gy(ctx, b, 0, -22)
	bp:add("cyl", 10, 1.8, 1.8, 0, ty + 4.6, -22, 0, 0, 90, o(BLACK_WOOD, "shell", { q = true }))
	for k = 0, 5 do
		local a = k * 1.2
		bp:add(
			"ball",
			1.5,
			1.2,
			1.5,
			math.cos(a) * 1.2,
			ty + 1.5 + k * 1.4,
			-22 + math.sin(a) * 1.2,
			0,
			0,
			0,
			o({ c = "#3E5A3A", m = "Wood" }, "detail", { col = false })
		)
	end
	bp:add("ball", 2.4, 1.8, 3, 0, ty + 10, -22.6, 0, 0, 0, o({ c = "#3E5A3A", m = "Wood" }, "detail", { col = false }))
	for _, side in { -1, 1 } do
		bp:box(0.3, 0.3, 0.1, side * 0.5, ty + 10.2, -24.1, o({ c = "#FFD84A", m = "Neon" }, "fine"))
	end
	Kit.ring(ctx, "wall", b.at.x, b.at.z, 18, 16, 1)
	table.insert(out, b)
end

-- The Cultists' Barrow: mound, dolmen entrance and a ring of menhirs (the portal stands in the entrance).
local function barrow(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local cave = env.areas.caves[2]
	Env.clear(env, cave.x, cave.z, 30)
	local b = Kit.build(ctx, "CultBarrow", "cave", cave.x, cave.z, cave.rot)
	local bp = b.bp
	bp:add("ball", 44, 20, 32, 0, 1, 16, 0, 0, 0, o({ c = "#2E3A26", m = "LeafyGrass" }, "shell", { q = true }))
	bp:box(16, 17, 1, 0, 8, 3.6, o(Kit.dark, "shell", { q = false }))
	for _, side in { -1, 1 } do
		bp:rbox(3.2, 18, 3.2, side * 9.4, 8.4, 1, 0, 0, side * 3, o(Kit.darkStone, "shell", { q = true }))
	end
	bp:rbox(24, 3.4, 5, 0, 18.6, 1.4, 0, 0, 2, o(Kit.darkStone, "shell", { q = false }))
	for k = 0, 2 do
		bp:box(
			1.2,
			1.4,
			0.2,
			-2 + k * 2,
			18.6,
			-1.2,
			o({ c = "#B060FF", m = "Neon" }, "fine", { tag = "lamp", fxColor = Kit.VIOLET })
		)
	end
	-- the ring of menhirs with violet candles and rags in front of the mound
	for i = 0, 6 do
		local a = math.pi + i * math.pi / 6
		local lx, lz = math.cos(a) * 26, math.sin(a) * 22 - 2
		local gy = Kit.gy(ctx, b, lx, lz)
		local h = 7 + (i % 3) * 1.5
		bp:rbox(2.4, h, 1.8, lx, gy + h / 2 - 0.6, lz, 0, i * 20, 2, o(Kit.mossyStone, "shell", { q = true }))
		Kit.candle(bp, lx + 1.6, gy, lz - 1, 0.7, Kit.VIOLET)
		Kit.candle(bp, lx - 1.4, gy, lz - 1.2, 0.5, Kit.VIOLET)
		bp:box(0.1, 1.8, 1.2, lx, gy + h - 1, lz - 1, o(Kit.violet, "detail", { col = false, tag = "flag" }))
	end
	Kit.circle(ctx, "hill", b.at.x, b.at.z - 16, 20)
	table.insert(out, b)
end

function Cult.all(env: Env.Env, out: { Build })
	village(env, out)
	hall(env, out)
	ritualCircle(env, out)
	serpentPond(env, out)
	barrow(env, out)
end

return Cult
