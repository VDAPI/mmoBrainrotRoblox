--!strict
-- Ashen Wastes generator (S46): plan data in (Data/Areas/ashen sites, Data/Terrain/ashen), Builds out, like
-- Logic/DuskwoodGen. Pure and deterministic: the server builds the "shell" level of every Build and each client
-- builds "detail" and "fine" near its camera from the same list (TownDetailController via Logic/WorldGen). Every
-- hunting ground looks like what lives there:
--
--   * Flats (Ribcage Gate, hyena den, Glowing Pit, basking slabs, Hot Spring), Oasis (stranded boat, jetty, caravan
--     graveyard, dead palms), Warcamp (palisade, gate, towers, forge, war drum, cages, Blood Ring, tents, carrion
--     dump), Lava (glowing lava, the crater and its fall, the Sleeping Colossus, stone golems, basalt columns, the
--     imps' chimneys), Ruins (burnt houses, chimney alley, square, temple and bell tower, scorpion nests), Dunes
--     (Buried King, sarcophagi, columns, burrows), Crags (nests and pinnacles on the spires, the nest mesa, the Stone
--     Wyvern, the rock arch), Road (Avenue of Kings, stone caravan, robbed wagons, milestones, basilisk pit),
--     Necropolis (pyramid, procession avenue, courtyards, rock tombs), Mouths (mine, lair, Deepforge),
--   * stone bridges over the lava (Logic/WorldGen/Structures), braziers by the roads, rocks, dead trees last
--     (Logic/WorldGen/Flora: charred stumps, burnt trees, dead palms; they keep clear of everything above).
-- Also: gathering node placements by theme (`nodes`), life points (`life`), map sketch shapes (`sketch`).

local AreaSpawns = require("./AreaSpawns")
local Crags = require("@self/Crags")
local Dunes = require("@self/Dunes")
local Env = require("@self/Env")
local Flats = require("@self/Flats")
local Flora = require("./WorldGen/Flora")
local Kit = require("./WorldGen/Kit")
local Lava = require("@self/Lava")
local Maps = require("../Data/Maps")
local Mouths = require("@self/Mouths")
local Necropolis = require("@self/Necropolis")
local Oasis = require("@self/Oasis")
local Props = require("@self/Props")
local Rng = require("./Rng")
local Road = require("@self/Road")
local Ruins = require("@self/Ruins")
local Shapes = require("../Data/Terrain")
local Structures = require("./WorldGen/Structures")
local TerrainLayers = require("./TerrainLayers")
local Warcamp = require("@self/Warcamp")

local o = Kit.o

local AshenGen = {}

export type Build = Kit.Build
export type Life = Kit.Life
export type NodePlacement = { kind: string, x: number, z: number }

local SHAPE = Shapes.byMap.ashen

local cache: { Build }? = nil
local treeCache: { Flora.TreeInfo } = {}
local env: Env.Env? = nil

local function envOf(): Env.Env
	if not env then
		local e = Env.new()
		e.ctx.perch = "vulturePerch"
		env = e
	end
	return env :: Env.Env
end

-- Clearings that come from data: portals, the landing from the Frost Peaks, cave mouths, respawn points, the scout,
-- crossings, monster groups.
local function dataClearings(e: Env.Env)
	for _, p in { { -770, 0 }, { -770, 160 }, { 740, -740 }, { 690, -690 } } do
		Env.clear(e, p[1], p[2], 22)
	end
	for _, c in e.areas.caves do
		Env.clear(e, c.x, c.z, 26)
	end
	for _, r in SHAPE.respawns do
		Env.clear(e, r.x, r.z, 10)
	end
	Env.clear(e, -690, -36, 9)
	for _, c in e.T.crossings() do
		Env.clear(e, c.x, c.z, c.span / 2 + 8)
	end
	local map = Maps.get("ashen")
	for _, s in AreaSpawns.region(e.areas, if map then map.size else { x = 1600, z = 1600 }) do
		Env.clear(e, s.position.x, s.position.z, 9)
	end
end

-- Braziers of black iron by the roads (rarer than Duskwood's lanterns), off bridges, lava and buildings.
local function braziers(e: Env.Env, out: { Build })
	local n = 0
	for ri, road in e.areas.roads do
		local line = e.T.roadLine(ri)
		local s = 50
		local side = 1
		while s < line.length - 30 do
			local x, z, dx, dz = TerrainLayers.pointAt(line, s)
			local off = road.width / 2 + 3
			local px, pz = x - dz * off * side, z + dx * off * side
			local ok = math.abs(px) < 770
				and math.abs(pz) < 770
				and Env.safe(e, px, pz, 8)
				and e.T.slope(px, pz, 2) < 0.6
				and not e.T.rockAt(px, pz)
				and Env.isClear(e, px, pz, -6)
			if ok then
				n += 1
				local b = Kit.build(e.ctx, `Brazier_{n}`, "lamp", px, pz, math.deg(math.atan2(-dx, -dz)))
				local bp = b.bp
				bp:box(0.5, 4.6, 0.5, 0, 2.2, 0, o(Props.ironDark, "shell", { q = false }))
				bp:add("cyl", 1.2, 2.2, 2.2, 0, 4.8, 0, 0, 0, 90, o(Props.ironDark, "detail", { col = false }))
				Kit.fire(bp, 0, 5.5, 0, 1.3, Kit.FIRE)
				for k = 0, 2 do
					bp:rbox(
						0.3,
						2.6,
						0.3,
						math.cos(k * 2.1) * 0.9,
						1.2,
						math.sin(k * 2.1) * 0.9,
						0,
						k * 120,
						18,
						o(Props.ironDark, "detail", { col = false })
					)
				end
				Env.clear(e, px, pz, 3)
				table.insert(out, b)
			end
			side = -side
			s += 170
		end
	end
end

-- Rock outcrops by theme (shell lumps collide).
local ROCKS: { [string]: { n: number, sw: Kit.Swatch, size: { number } } } = {
	ash = { n = 16, sw = Props.ashDark, size = { 3, 6 } },
	crags = { n = 18, sw = Props.rust, size = { 4, 8 } },
	lavafield = { n = 10, sw = Props.basalt, size = { 3, 6 } },
	royalroad = { n = 8, sw = Props.rust, size = { 3, 6 } },
	saltflat = { n = 4, sw = Props.ash, size = { 2.5, 4.5 } },
	burnt = { n = 6, sw = Props.ashDark, size = { 2.5, 5 } },
	necropolis = { n = 4, sw = Props.sandstone, size = { 3, 5 } },
	warcamp = { n = 6, sw = Props.basalt, size = { 3, 6 } },
	dunes = { n = 4, sw = Props.sandstone, size = { 3, 5 } },
}

local function rocks(e: Env.Env, out: { Build })
	local rng = Rng.new(4605)
	local placed: { [string]: number } = {}
	local tries = 0
	while tries < 6000 do
		tries += 1
		local x, z = rng:float(-770, 770), rng:float(-770, 770)
		local theme = e.T.themeAt(x, z)
		local spec = ROCKS[theme]
		if
			spec
			and (placed[theme] or 0) < spec.n
			and Env.isClear(e, x, z, 4)
			and e.T.slope(x, z, 3) < 0.9
			and Env.safe(e, x, z, 6)
			and e.T.roadDistance(x, z) > 6
			and not e.T.rockAt(x, z)
		then
			placed[theme] = (placed[theme] or 0) + 1
			local b = Kit.build(e.ctx, `Rocks_{theme}_{placed[theme]}`, "rocks", x, z, rng:float(0, 360))
			local size = rng:float(spec.size[1], spec.size[2])
			Kit.rock(b.bp, 0, -0.6, 0, size, spec.sw, "shell")
			for _ = 1, rng:int(1, 3) do
				local a = rng:float(0, math.pi * 2)
				local d = size * rng:float(0.8, 1.4)
				local lx, lz = math.cos(a) * d, math.sin(a) * d
				Kit.rock(b.bp, lx, Kit.gy(e.ctx, b, lx, lz) - 0.2, lz, size * rng:float(0.25, 0.45), spec.sw, "detail")
			end
			Env.clear(e, x, z, size)
			table.insert(out, b)
		end
	end
end

-- Terrain shapes of the sketch (drawn under the buildings): the dry lake, the dune sea, basins, water, roads, ramps.
local function terrainSketch(e: Env.Env)
	local ctx = e.ctx
	for _, dl in assert(SHAPE.drylakes, "drylakes") do
		Kit.circle(ctx, "drylake", dl.x - dl.rx * 0.45, dl.z, dl.rz * 0.95)
		Kit.circle(ctx, "drylake", dl.x + dl.rx * 0.45, dl.z, dl.rz * 0.95)
		Kit.rect(ctx, "drylake", dl.x, dl.z, dl.rx * 0.9, dl.rz * 1.9, 0)
	end
	local d = assert(SHAPE.dunes, "dunes")[1]
	Kit.rect(
		ctx,
		"ground:Sand",
		(d.rect[1] + d.rect[3]) / 2,
		(d.rect[2] + d.rect[4]) / 2,
		d.rect[3] - d.rect[1],
		d.rect[4] - d.rect[2],
		0
	)
	for _, b in SHAPE.basins do
		if b.depth >= 4 then
			Kit.circle(ctx, "basin", b.x, b.z, (b.rx + b.rz) / 2 * 0.8)
		end
	end
	local camp = SHAPE.plateaus[1]
	Kit.circle(ctx, "plateau", -255, -575, 120)
	local _ = camp
	for _, lake in e.areas.lakes do
		Kit.circle(ctx, "water", lake.x, lake.z, lake.r)
	end
	for _, road in e.areas.roads do
		Kit.line(ctx, "path", road.points, road.width)
	end
	for _, ramp in SHAPE.ramps do
		local pts = {}
		for _, q in ramp.pts do
			table.insert(pts, q[1])
			table.insert(pts, q[2])
		end
		Kit.line(ctx, "path", pts, ramp.w)
	end
end

-- Every Build of the Ashen Wastes in a fixed order (cached; identical on the server and every client).
function AshenGen.all(): { Build }
	if cache then
		return cache
	end
	local e = envOf()
	table.clear(e.ctx.life)
	table.clear(e.ctx.sketch)
	table.clear(e.clearings)
	terrainSketch(e)
	dataClearings(e)
	local out: { Build } = {}
	Flats.all(e, out)
	Oasis.all(e, out)
	Warcamp.all(e, out)
	Lava.all(e, out)
	Ruins.all(e, out)
	Dunes.all(e, out)
	Crags.all(e, out)
	Road.all(e, out)
	Necropolis.all(e, out)
	Mouths.all(e, out)
	Structures.bridges(e.ctx, e.T, out, Props.EMBER)
	braziers(e, out)
	rocks(e, out)
	local tiles, trees = Flora.forest({
		ctx = e.ctx,
		ground = e.T,
		rules = SHAPE.flora,
		default = SHAPE.defaultTheme,
		seed = 4604,
		half = 800,
		clear = function(x: number, z: number, extra: number): boolean
			return Env.isClear(e, x, z, extra) and not e.T.rockAt(x, z)
		end,
	})
	for _, b in tiles do
		table.insert(out, b :: any)
	end
	treeCache = trees
	cache = out
	return out
end

-- Big trees (x, z, kind).
function AshenGen.trees(): { Flora.TreeInfo }
	AshenGen.all()
	return treeCache
end

-- Points the client brings to life (Controllers/WorldLifeController): "vulturePerch", "vultures", "embers", "haze",
-- "steam", "smoke", "smokeColumn", "lavaBubbles", "wisp".
function AshenGen.life(): { Life }
	AshenGen.all()
	return envOf().ctx.life
end

-- Map sketch shapes: terrain (dry lake, dunes, basins, water, roads), lava, then buildings, walls, bridges.
function AshenGen.sketch(): { { [string]: any } }
	AshenGen.all()
	return envOf().ctx.sketch
end

-- Horizontal reach of a Build from its `at` point.
function AshenGen.radius(build: Build): number
	local r = 0
	for _, piece in build.bp.pieces do
		local p, size = piece.p, piece.size
		r = math.max(r, math.sqrt(p[1] * p[1] + p[3] * p[3]) + math.max(size[1], size[2], size[3]) / 2)
	end
	return r
end

-- Parts per level of detail over all Builds.
function AshenGen.counts(): { shell: number, detail: number, fine: number, builds: number, lights: number }
	local c = { shell = 0, detail = 0, fine = 0, builds = 0, lights = 0 }
	for _, b in AshenGen.all() do
		c.builds += 1
		c.lights += #b.bp.lights
		for _, piece in b.bp.pieces do
			c[piece.lod] += 1
		end
	end
	return c
end

-- Gathering nodes ----------------------------------------------------------------------------------------------

type NodeRule = {
	kind: string,
	count: number,
	where: (x: number, z: number, theme: string) -> boolean,
	box: { number }?,
}

-- Ores and herbs by the areas' character: silver in the plain's rocks, under the warcamp's cliffs and by the mine;
-- mithril at the foot of the spires, among the obsidian of the golem fields and under the tombs' scarp; fire bloom
-- by the glowing cracks and lava (14-25 studs from it), in the ruins' yards, by the pond and the spring.
local function nodeRules(e: Env.Env): { NodeRule }
	local T = e.T
	local pond, spring = e.areas.lakes[1], e.areas.lakes[2]
	local function near(c: { x: number, z: number, r: number }, x: number, z: number, from: number, to: number): boolean
		local d = math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) - c.r
		return d > from and d < to
	end
	return {
		{
			kind = "vein_silver",
			count = 5,
			where = function(_x, _z, theme)
				return theme == "ash"
			end,
		},
		{
			kind = "vein_silver",
			count = 4,
			where = function(x, z, _theme)
				return not (T.plateauAt(x, z))
			end,
			box = { -450, -720, -60, -420 },
		},
		{
			kind = "vein_silver",
			count = 3,
			where = function(_x, _z, _theme)
				return true
			end,
			box = { -660, -720, -460, -600 },
		},
		{
			kind = "vein_mithril",
			count = 4,
			where = function(_x, _z, theme)
				return theme == "crags"
			end,
		},
		{
			kind = "vein_mithril",
			count = 3,
			where = function(x, z, theme)
				local d = T.lavaDistance(x, z)
				return theme == "lavafield" and d > 14 and d < 40
			end,
		},
		{
			kind = "vein_mithril",
			count = 3,
			where = function(_x, _z, _theme)
				return true
			end,
			box = { 360, 220, 780, 276 },
		},
		{
			kind = "bush_firebloom",
			count = 12,
			where = function(x, z, _theme)
				local d = T.lavaDistance(x, z)
				return d >= 14 and d <= 25
			end,
		},
		{
			kind = "bush_firebloom",
			count = 6,
			where = function(_x, _z, theme)
				return theme == "burnt"
			end,
			box = { -200, 500, 260, 760 },
		},
		{
			kind = "bush_firebloom",
			count = 4,
			where = function(x, z, _theme)
				return near(pond, x, z, 14, 60)
			end,
			box = { pond.x - 90, pond.z - 90, pond.x + 90, pond.z + 90 },
		},
		{
			kind = "bush_firebloom",
			count = 4,
			where = function(x, z, _theme)
				return near(spring, x, z, 14, 60)
			end,
			box = { spring.x - 90, spring.z - 90, spring.x + 90, spring.z + 90 },
		},
	}
end

local nodeCache: { NodePlacement }? = nil

local function blocked(e: Env.Env, x: number, z: number): boolean
	if AreaSpawns.nearRoad(e.areas.roads, x, z, 6) then
		return true
	end
	for _, list in { e.areas.avoid, e.areas.lakes } do
		for _, c in list do
			if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + 6) ^ 2 then
				return true
			end
		end
	end
	for _, c in e.areas.caves do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < 40 * 40 then
			return true
		end
	end
	return false
end

-- Gathering node placements (fishing spots, herbs, ores), 24+ studs apart, on dry gentle ground away from roads,
-- lava, water, buildings and monster groups.
function AshenGen.nodes(): { NodePlacement }
	if nodeCache then
		return nodeCache
	end
	AshenGen.all()
	local e = envOf()
	local out: { NodePlacement } = {}
	for _, spot in AshenGen.fishingSpots() do
		table.insert(out, { kind = "fishing_ashen", x = spot.x, z = spot.z })
	end
	local map = Maps.get("ashen")
	local groups = AreaSpawns.region(e.areas, if map then map.size else { x = 1600, z = 1600 })
	local rng = Rng.new(4606)
	for _, rule in nodeRules(e) do
		local placed, tries = 0, 0
		local box = rule.box or { -770, -770, 770, 770 }
		while placed < rule.count and tries < rule.count * 800 do
			tries += 1
			local x, z = rng:float(box[1], box[3]), rng:float(box[2], box[4])
			local theme = e.T.themeAt(x, z)
			local ok = rule.where(x, z, theme) and not blocked(e, x, z)
			if ok then
				for _, other in out do
					if (x - other.x) ^ 2 + (z - other.z) ^ 2 < 24 * 24 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, g in groups do
					if (x - g.position.x) ^ 2 + (z - g.position.z) ^ 2 < 20 * 20 then
						ok = false
						break
					end
				end
			end
			if ok and Env.isClear(e, x, z, -2) and e.T.walkable(x, z) and not e.T.rockAt(x, z) then
				table.insert(out, { kind = rule.kind, x = math.floor(x + 0.5), z = math.floor(z + 0.5) })
				placed += 1
			end
		end
	end
	nodeCache = out
	return out
end

-- Fishing spots: a dry point on the north shore with open water 9-12 studs to the south (+Z), where the spot's
-- buoys float: by the foot of the oasis jetty (beside it) and on the Hot Spring's north shore.
function AshenGen.fishingSpots(): { { x: number, z: number } }
	local e = envOf()
	local out = {}
	for i, lake in e.areas.lakes do
		local cx, cz = lake.x + (if i == 1 then 9 else 0), lake.z - lake.r - 4
		local best: { x: number, z: number }? = nil
		local bestD = math.huge
		for dx = -24, 24, 2 do
			for dz = -16, 16, 2 do
				local x, z = cx + dx, cz + dz
				if
					not e.T.isWater(x, z)
					and e.T.slope(x, z, 2) < 0.5
					and e.T.isWater(x, z + 9)
					and e.T.isWater(x, z + 12)
					and (i ~= 1 or math.abs(x - lake.x) > 5)
				then
					local d = dx * dx + dz * dz
					if d < bestD then
						bestD = d
						best = { x = x, z = z }
					end
				end
			end
		end
		if best then
			table.insert(out, best)
		end
	end
	return out
end

return AshenGen
