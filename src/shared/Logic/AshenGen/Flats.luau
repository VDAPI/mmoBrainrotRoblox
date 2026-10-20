--!strict
-- Salamander Flats (45–50, fast EXP) (S46): the way into the Ashen Wastes.
--   * the Ribcage Gate (the landmark): ribs of a giant beast arching over the road from the portals, its spine
--     lying beside it, and a skull driven into the ash; under the skull the hyenas' den (gnawed bones, a trampled
--     ring, torn hides, paw prints),
--   * the Glowing Pit: the brightest lava of the plain with sparks over it, the cracks run out of it; flat basalt
--     slabs worn smooth where the salamanders bask, shed scales,
--   * the Hot Spring: a steaming pool with a yellow sulphur rim and a faint orange glow under the water,
--   * S104 (story chapter III): Brokk's camp behind his place by the scout (a bedroll, a small anvil on a stump, an open
--     iron chest with blue rune stones, a dead fire) and Ghasha's rest on the Hot Spring's rim (herbs drying on a strap
--     between two sticks, a hide mat, a bone totem with a red rag); detail only, no collision. Pure.

local Env = require("./Env")
local Kit = require("../WorldGen/Kit")
local Props = require("./Props")

local o = Kit.o

local Flats = {}

type Build = Kit.Build

local function ribcage(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "ribcage", "landmark", 22)
	local bp = b.bp
	-- the road runs along local Z (the gate faces west): every rib springs from the spine's side (north, local -X),
	-- arches over the road and comes down short of the ground on the south side
	-- owner 2026-10-20: ribs and spine are one asset kit slot (Data/Kit "landmark:ribcage", the owner's bone arch)
	bp:beginKit("landmark:ribcage", 0, Kit.gy(ctx, b, 0, 0) - 0.5, 0, 1, "shell")
	for i = -3, 3 do
		local z = i * 5.5
		local s = 1 - math.abs(i) * 0.08
		local n = 9
		local px, py = -15 * s, Kit.gy(ctx, b, -15 * s, z) - 1
		for k = 1, n do
			local t = k / n
			local a = t * math.pi * 0.94
			local nx = -15 * s * math.cos(a) + math.sin(a) * 2
			local ny = Kit.gy(ctx, b, -15 * s, z) - 1 + math.sin(a) * 21 * s
			local level = if k <= 2 or k == n then "shell" elseif math.abs(i) > 1 then "detail" else "shell"
			bp:beam(
				px,
				py,
				z,
				nx,
				ny,
				z + math.sin(t * math.pi) * 0.6,
				1.7 - t * 0.6,
				o(Kit.oldBone, level :: any, { col = k <= 2, q = false })
			)
			px, py = nx, ny
		end
	end
	-- the spine lying on the ground beside the road, vertebrae in a row
	for k = 0, 9 do
		local z = -26 + k * 5.6
		local x = -19 - math.sin(k * 0.5) * 1.5
		bp:add(
			"ball",
			3,
			2.4,
			3.6,
			x,
			Kit.gy(ctx, b, x, z) + 0.8,
			z,
			0,
			k * 13,
			0,
			o(Kit.oldBone, if k % 3 == 0 then "shell" else "detail", { q = false })
		)
	end
	bp:endKit()
	Kit.lifeAt(ctx, b, "vulturePerch", 0, 23, 0)
	table.insert(out, b)
end

-- The giant skull driven into the ash north of the road, and the hyenas' den under it.
local function hyenaDen(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local b = Env.atSite(env, "hyenaDen", "traces", 18)
	local bp = b.bp
	-- owner 2026-10-20: the skull is an asset kit slot (Data/Kit "landmark:bigSkull", the owner's skull sculpture)
	bp:beginKit("landmark:bigSkull", 0, Kit.gy(ctx, b, 0, 4) - 1, 4, 1, "shell")
	Props.bigSkull(bp, 0, Kit.gy(ctx, b, 0, 4) - 2.4, 4, 1.4, 0)
	bp:endKit()
	-- the den: a dark hollow under the skull's jaw, a trampled ring of ash, torn hides, gnawed bones, paw prints
	bp:add("ball", 7, 3, 4, 0, Kit.gy(ctx, b, 0, -2) + 0.2, -2, 0, 0, 0, o(Kit.dark, "detail", { col = false }))
	for k = 0, 5 do
		local a = k * math.pi / 3
		local lx, lz = math.cos(a) * 8, -6 + math.sin(a) * 6
		Props.gnawed(bp, lx, Kit.gy(ctx, b, lx, lz), lz, 3)
	end
	for k = 1, 3 do
		local lx, lz = -6 + k * 3.5, -12 + (k % 2) * 2
		bp:rbox(2.6, 0.12, 1.8, lx, Kit.gy(ctx, b, lx, lz) + 0.08, lz, 0, k * 50, 0, o(Kit.hide, "fine"))
	end
	Props.carcass(bp, 10, Kit.gy(ctx, b, 10, -10), -10, 40)
	Kit.lifeAt(ctx, b, "vultures", 0, 40, -6, 20)
	table.insert(out, b)
end

-- The Glowing Pit: a vent of sparks and heat over its lava pool, black glassy rims.
local function glowPit(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.glowPit
	Env.clear(env, s.x, s.z, 30)
	local level = env.T.lava(s.x, s.z) or env.T.height(s.x, s.z)
	local b = Kit.buildAt("GlowPit", "vent", s.x, level, s.z, s.rot)
	local bp = b.bp
	bp:add(
		"ball",
		6,
		1,
		6,
		0,
		0.3,
		0,
		0,
		0,
		0,
		{ c = Props.LAVA, m = "Neon", lod = "shell", col = false, q = false, t = 0.35, tag = "vent", jitter = 0 }
	)
	bp:light(0, 6, 0, Props.LAVA, 40, 1.6, "lava")
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.3
		local lx, lz = math.cos(a) * 21, math.sin(a) * 19
		Kit.rock(bp, lx, env.T.height(s.x + lx, s.z + lz) - level - 0.4, lz, 2.2, Props.obsidian, "detail")
	end
	Kit.life(ctx, "embers", s.x, level + 1, s.z, 10)
	Kit.life(ctx, "haze", s.x, level + 1, s.z, 12)
	table.insert(out, b)
end

-- Basalt slabs worn smooth by basking salamanders by the cracks, with shed scales.
local SLABS = { { -540, -128 }, { -520, -186 }, { -640, -152 }, { -620, -252 }, { -560, -232 }, { -660, -214 } }

local function fissures(env: Env.Env, out: { Build })
	local ctx = env.ctx
	for i, p in SLABS do
		local x, z = p[1], p[2]
		if env.T.lavaDistance(x, z) < 4 then
			x += 6
		end
		Env.clear(env, x, z, 7)
		local b = Kit.build(ctx, if i == 1 then "fissures" else `BaskingSlab_{i}`, "traces", x, z, i * 41)
		local bp = b.bp
		bp:rbox(7, 1, 5, 0, 0.2, 0, 0, 0, 3, o(Props.basalt, "shell", { q = false }))
		bp:rbox(4, 0.8, 3, 4.6, 0.1, 2, 0, 30, -4, o(Props.basalt, "detail", { col = false }))
		bp:box(4.4, 0.06, 3, 0, 0.74, 0, o({ c = "#4A4448", m = "Basalt" }, "fine")) -- worn smooth, warm
		for k = 1, 3 do
			bp:rbox(
				0.9,
				0.06,
				0.6,
				-2 + k * 1.2,
				0.76,
				-1 + k * 0.4,
				0,
				k * 60,
				0,
				o({ c = "#B5462B", m = "SmoothPlastic" }, "fine", { t = 0.3 })
			)
		end
		table.insert(out, b)
	end
end

-- The Hot Spring: steam over the water, a sulphur rim, a faint orange glow from below, a few dead reeds.
local function hotSpring(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local s = env.sites.hotSpring
	local lake = env.areas.lakes[2]
	Env.clear(env, s.x, s.z, lake.r + 10)
	local b = Kit.buildAt("HotSpring", "pool", lake.x, env.T.shape.lakeLevel, lake.z, 0)
	local bp = b.bp
	bp:light(0, -1.5, 0, Props.LAVA, 26, 0.7)
	for k = 0, 11 do
		local a = k * math.pi / 6
		local r = lake.r + 2.5
		local lx, lz = math.cos(a) * r, math.sin(a) * r
		local y = env.T.height(lake.x + lx, lake.z + lz) - b.at.y
		bp:rbox(
			3.4,
			0.25,
			1.6,
			lx,
			y + 0.1,
			lz,
			0,
			math.deg(-a) + 90,
			0,
			o({ c = Props.SULPHUR, m = "Sand" }, "detail", { col = false })
		)
		if k % 3 == 0 then
			Kit.rock(bp, lx * 1.15, y - 0.3, lz * 1.15, 2, Props.ash, "detail")
		end
	end
	Kit.life(ctx, "steam", lake.x, b.at.y + 0.5, lake.z, lake.r * 0.8)
	table.insert(out, b)
end

-- S104: the place of a story NPC (Data/Areas/ashen npcSpots).
local function spotOf(env: Env.Env, name: string): { x: number, z: number, facing: number }
	local spots: any = env.areas.npcSpots or {}
	return assert(spots[name], `ashen npc spot {name}`)
end

local RUNE = "#6FB8FF"
local FREE = { col = false }

-- S104: Brokk's camp 5 studs behind his place (he faces west, the camp lies east of him, inside the scout's circle).
local function runesmithCamp(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local spot = spotOf(env, "runesmith")
	local r = math.rad(spot.facing)
	local x, z = spot.x + math.sin(r) * 5, spot.z + math.cos(r) * 5
	Env.clear(env, x, z, 5)
	local b = Kit.build(ctx, "RunesmithCamp", "camp", x, z, spot.facing)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	-- the bedroll and its rolled blanket
	bp:box(2.2, 0.25, 4.2, -2, gy(-2, 0.5) + 0.12, 0.5, o(Kit.cloth, "detail", FREE))
	bp:add("cyl", 2.2, 0.8, 0.8, -2, gy(-2, -1.8) + 0.4, -1.8, 0, 0, 0, o(Kit.hide, "fine", FREE))
	-- the small anvil on a stump
	bp:add("cyl", 1.2, 1.3, 1.3, 1.8, gy(1.8, 1.4) + 0.6, 1.4, 0, 0, 90, o(Kit.charred, "detail", FREE))
	bp:box(1.4, 0.5, 0.6, 1.8, gy(1.8, 1.4) + 1.45, 1.4, o(Props.ironDark, "detail", FREE))
	bp:box(0.5, 0.4, 0.5, 2.6, gy(1.8, 1.4) + 1.4, 1.4, o(Props.ironDark, "fine", FREE))
	-- the open iron chest with the rune stones
	local cy = gy(0.2, 2.6)
	bp:box(1.6, 0.9, 1, 0.2, cy + 0.45, 2.6, o(Props.ironDark, "detail", FREE))
	bp:rbox(1.6, 0.12, 1, 0.2, cy + 1.25, 3.3, -70, 0, 0, o(Props.ironDark, "detail", FREE))
	for k = 0, 1 do
		bp:box(0.35, 0.18, 0.35, -0.1 + k * 0.6, cy + 0.95, 2.5 + k * 0.15, {
			c = RUNE,
			m = "Neon",
			lod = "detail",
			col = false,
			q = false,
			tag = "glow",
			jitter = 0,
		})
	end
	-- the dead fire: a ring of stones and a charred log
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		local lx, lz = 0.4 + math.cos(a) * 1.2, -1.6 + math.sin(a) * 1.2
		bp:box(0.6, 0.4, 0.6, lx, gy(lx, lz) + 0.15, lz, o(Props.ash, "fine", FREE))
	end
	bp:add("cyl", 1.8, 0.45, 0.45, 0.4, gy(0.4, -1.6) + 0.25, -1.6, 0, 30, 0, o(Kit.charred, "fine", FREE))
	table.insert(out, b)
end

-- S104: Ghasha's rest beside her place on the Hot Spring's rim (on the side away from the water).
local function shamanRest(env: Env.Env, out: { Build })
	local ctx = env.ctx
	local spot = spotOf(env, "shaman")
	local x, z = spot.x - 3, spot.z + 3.5
	Env.clear(env, x, z, 4)
	local b = Kit.build(ctx, "ShamanRest", "camp", x, z, spot.facing)
	local bp = b.bp
	local function gy(lx: number, lz: number): number
		return Kit.gy(ctx, b, lx, lz)
	end
	-- herbs drying on a strap between two sticks
	for _, side in { -1, 1 } do
		bp:rbox(0.2, 2.6, 0.2, side * 1.5, gy(side * 1.5, 1) + 1.2, 1, 0, 0, side * 6, o(Kit.deadBark, "detail", FREE))
	end
	bp:box(3, 0.06, 0.06, 0, gy(0, 1) + 2.35, 1, o(Kit.rope, "fine", FREE))
	for _, k in { -0.6, 0.7 } do
		bp:box(0.3, 0.7, 0.3, k, gy(k, 1) + 1.95, 1, o({ c = "#5E6A3A", m = "Grass" }, "fine", FREE))
	end
	-- the hide mat
	bp:box(2, 0.1, 2.6, 0, gy(0, -1.2) + 0.05, -1.2, o(Props.orcHide, "detail", FREE))
	-- the bone totem with a red rag
	local ty = gy(-1.6, -2.6)
	bp:add("cyl", 2.6, 0.3, 0.3, -1.6, ty + 1.3, -2.6, 0, 0, 90, o(Kit.bone, "detail", FREE))
	bp:add("ball", 0.6, 0.55, 0.65, -1.6, ty + 2.85, -2.6, 0, 0, 0, o(Kit.bone, "fine", FREE))
	bp:rbox(0.06, 0.9, 0.5, -1.45, ty + 2, -2.6, 0, 0, 8, o({ c = "#A3282A", m = "Fabric" }, "fine", FREE))
	table.insert(out, b)
end

function Flats.all(env: Env.Env, out: { Build })
	ribcage(env, out)
	hyenaDen(env, out)
	glowPit(env, out)
	fissures(env, out)
	hotSpring(env, out)
	runesmithCamp(env, out) -- S104
	shamanRest(env, out) -- S104
end

return Flats
