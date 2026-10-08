--!strict
-- Duskwood generator (S45): plan data in (Data/Areas/duskwood sites, Data/Terrain/duskwood), Builds out, like
-- Logic/MeadowsGen for the Meadows. Pure and deterministic: the server builds the "shell" level of every Build and
-- each client builds "detail" and "fine" near its camera from the same list (TownDetailController via
-- Logic/WorldGen). Every hunting ground looks like what lives there:
--
--   * Thicket (way in, dusk gate, ravaged camp, Moon Glade, bone tree, Wolf Den), Hollow (fallen giant, lost camp,
--     bear dens), Ruins (manor, cemetery, chapel, family crypt), Heart (Elder Tree, mushrooms, craters, burrows,
--     rot pools), Cult (village, hall, ritual circle, serpent pond, the Barrow), Crossroads (shrine, gallows,
--     signpost), Swamp (sunken tower, troll village, jetty, stilt village, causeways), Witch (hut, hanging tree),
--     Cliffs (Crypt Gate, overhangs, scree, the black waterfall),
--   * bridges and the ford (Logic/WorldGen/Structures), cold blue road lanterns, rock outcrops, trees last
--     (Logic/WorldGen/Flora: they keep clear of everything above).
-- Also: gathering node placements by theme (`nodes`), life points (`life`), map sketch shapes (`sketch`).

local AreaSpawns = require("./AreaSpawns")
local Cliffs = require("@self/Cliffs")
local Crossroads = require("@self/Crossroads")
local Cult = require("@self/Cult")
local Env = require("@self/Env")
local Flora = require("./WorldGen/Flora")
local Heart = require("@self/Heart")
local Hollow = require("@self/Hollow")
local Kit = require("./WorldGen/Kit")
local Maps = require("../Data/Maps")
local Rng = require("./Rng")
local Ruins = require("@self/Ruins")
local Shapes = require("../Data/Terrain")
local Structures = require("./WorldGen/Structures")
local Swamp = require("@self/Swamp")
local TerrainLayers = require("./TerrainLayers")
local Thicket = require("@self/Thicket")
local Witch = require("@self/Witch")

local o = Kit.o

local DuskwoodGen = {}

export type Build = Kit.Build
export type Life = Kit.Life
export type NodePlacement = { kind: string, x: number, z: number }

local SHAPE = Shapes.byMap.duskwood

local cache: { Build }? = nil
local treeCache: { Flora.TreeInfo } = {}
local env: Env.Env? = nil

local function envOf(): Env.Env
	if not env then
		env = Env.new()
	end
	return env :: Env.Env
end

-- Clearings that come from data: portals, cave mouths, respawn points, the scout, crossings, monster groups.
local function dataClearings(e: Env.Env)
	for _, p in { { -770, 0 }, { -770, 160 }, { 740, -740 } } do
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
	local map = Maps.get("duskwood")
	for _, s in AreaSpawns.region(e.areas, if map then map.size else { x = 1600, z = 1600 }) do
		Env.clear(e, s.position.x, s.position.z, 9)
	end
end

-- Cold blue lanterns along the roads (rarer deep in the forest), off bridges, water and buildings.
local function lanterns(e: Env.Env, out: { Build })
	local n = 0
	for ri, road in e.areas.roads do
		local line = e.T.roadLine(ri)
		local s = 40
		local side = 1
		while s < line.length - 20 do
			local x, z, dx, dz = TerrainLayers.pointAt(line, s)
			local off = road.width / 2 + 3
			local px, pz = x - dz * off * side, z + dx * off * side
			local deep = e.T.themeAt(px, pz)
			local ok = math.abs(px) < 770
				and math.abs(pz) < 770
				and not e.T.isWater(px, pz)
				and e.T.streamDistance(px, pz) > 6
				and e.T.slope(px, pz, 2) < 0.6
				and Env.isClear(e, px, pz, -6)
			if ok then
				n += 1
				local b =
					Kit.build(e.ctx, `RoadLantern_{n}`, "lamp", px, pz, math.deg(math.atan2(-dx, -dz)) + 90 * side)
				Kit.lantern(b.bp, 0, 0, 0, Kit.COLD, 7, "detail")
				b.bp:box(0.5, 0.5, 0.5, 0, 0.2, 0, o(Kit.darkStone, "detail", { col = false }))
				Kit.lifeAt(e.ctx, b, "moths", 1.1, 6, 0, 3)
				Env.clear(e, px, pz, 3)
				table.insert(out, b)
			end
			side = -side
			s += if deep == "thicket" or deep == "hollow" or deep == "ruins" or deep == "forest" then 150 else 110
		end
	end
end

-- Rock outcrops by theme (shell lumps collide): mossy in the forest, red on the cliffs, dark in the gorge.
local function rocks(e: Env.Env, out: { Build })
	local rng = Rng.new(4505)
	local wanted: { [string]: number } =
		{ thicket = 14, hollow = 12, ruins = 8, cliffs = 14, cult = 4, forest = 6, rot = 6 }
	local placed: { [string]: number } = {}
	local tries = 0
	while tries < 5000 do
		tries += 1
		local x, z = rng:float(-770, 770), rng:float(-770, 770)
		local theme = e.T.themeAt(x, z)
		local want = wanted[theme]
		if
			want
			and (placed[theme] or 0) < want
			and Env.isClear(e, x, z, 4)
			and e.T.slope(x, z, 3) < 0.9
			and not e.T.isWater(x, z)
			and e.T.roadDistance(x, z) > 6
			and e.T.streamDistance(x, z) > 4
		then
			placed[theme] = (placed[theme] or 0) + 1
			local b = Kit.build(e.ctx, `Rocks_{theme}_{placed[theme]}`, "rocks", x, z, rng:float(0, 360))
			local sw = if theme == "cliffs"
				then Kit.redRock
				elseif theme == "hollow" then Kit.darkStone
				else Kit.mossyStone
			local size = rng:float(3.5, 7)
			Kit.rock(b.bp, 0, -0.6, 0, size, sw, "shell")
			for _ = 1, rng:int(1, 3) do
				local a = rng:float(0, math.pi * 2)
				local d = size * rng:float(0.8, 1.4)
				local lx, lz = math.cos(a) * d, math.sin(a) * d
				Kit.rock(b.bp, lx, Kit.gy(e.ctx, b, lx, lz) - 0.2, lz, size * rng:float(0.25, 0.45), sw, "detail")
			end
			if theme ~= "cliffs" then
				b.bp:box(size * 0.9, 0.3, size * 0.7, 0, size * 0.62, 0, o(Kit.moss, "fine", { col = false }))
			end
			Env.clear(e, x, z, size)
			table.insert(out, b)
		end
	end
end

-- Terrain shapes of the sketch (drawn under the buildings): marshes, basins, the gorge, the cliffs' plateau and
-- scarp, streams, lakes, roads, ramps.
local function terrainSketch(e: Env.Env)
	local ctx = e.ctx
	for _, m in SHAPE.marshes do
		for _, c in { { 0, 0, 0.72 }, { -0.35, 0.3, 0.42 }, { 0.3, -0.25, 0.42 }, { 0.35, 0.35, 0.38 } } do
			Kit.circle(ctx, "marsh", m.x + c[1] * m.rx, m.z + c[2] * m.rz, (m.rx + m.rz) / 2 * c[3])
		end
	end
	for _, bsn in SHAPE.basins do
		if bsn.depth >= 4 then
			Kit.circle(ctx, "basin", bsn.x, bsn.z, (bsn.rx + bsn.rz) / 2 * 0.8)
		end
	end
	for _, g in SHAPE.gorges do
		for i = 1, #g.pts - 1 do
			local a, c = g.pts[i], g.pts[i + 1]
			Kit.line(ctx, "ravineWall", { a.x, a.z, c.x, c.z }, a.half + c.half + 2 * g.wall)
			Kit.line(ctx, "ravine", { a.x, a.z, c.x, c.z }, a.half + c.half)
		end
	end
	local plateau = SHAPE.plateaus[1]
	local poly = assert(plateau.poly, "cliffs polygon")
	local cliff: { number } = {}
	for i = 3, 12 do
		table.insert(cliff, poly[i])
	end
	Kit.rect(ctx, "plateau", 712, -66, 190, 470, 0)
	Kit.line(ctx, "cliff", cliff, 7)
	local manor = SHAPE.plateaus[2]
	Kit.circle(ctx, "plateau", manor.x or 0, manor.z or 0, ((manor.rx or 0) + (manor.rz or 0)) / 2)
	for _, lake in e.areas.lakes do
		Kit.circle(ctx, "water", lake.x, lake.z, lake.r)
	end
	for _, stream in (e.areas.streams or {}) :: { any } do
		local p = stream.points
		for i = 1, #p - 3, 2 do
			local k = (i + 1) // 2
			local w = ((stream.widths[k] or 8) + (stream.widths[k + 1] or 8)) / 2
			Kit.line(ctx, "water", { p[i], p[i + 1], p[i + 2], p[i + 3] }, w)
		end
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

-- Every Build of Duskwood in a fixed order (cached; identical on the server and every client).
function DuskwoodGen.all(): { Build }
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
	Thicket.all(e, out)
	Hollow.all(e, out)
	Ruins.all(e, out)
	Heart.all(e, out)
	Cult.all(e, out)
	Crossroads.all(e, out)
	Swamp.all(e, out)
	Witch.all(e, out)
	Cliffs.all(e, out)
	Structures.bridges(e.ctx, e.T, out, Kit.COLD)
	Structures.banks(e.ctx, e.T, out, 1, 80, Kit.mossyStone)
	lanterns(e, out)
	rocks(e, out)
	local tiles, trees = Flora.forest({
		ctx = e.ctx,
		ground = e.T,
		rules = SHAPE.flora,
		default = SHAPE.defaultTheme,
		seed = 4504,
		half = 800,
		clear = function(x: number, z: number, extra: number): boolean
			return Env.isClear(e, x, z, extra)
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
function DuskwoodGen.trees(): { Flora.TreeInfo }
	DuskwoodGen.all()
	return treeCache
end

-- Points the client brings to life (Controllers/WorldLifeController): "batRoost", "bats", "perch", "wisp", "mist",
-- "moths", "fireflies", "spores".
function DuskwoodGen.life(): { Life }
	DuskwoodGen.all()
	return envOf().ctx.life
end

-- Map sketch shapes: terrain (marshes, basins, gorge, cliffs, water, roads) then buildings, walls, bridges.
function DuskwoodGen.sketch(): { { [string]: any } }
	DuskwoodGen.all()
	return envOf().ctx.sketch
end

-- Horizontal reach of a Build from its `at` point.
function DuskwoodGen.radius(build: Build): number
	local r = 0
	for _, piece in build.bp.pieces do
		local p, size = piece.p, piece.size
		r = math.max(r, math.sqrt(p[1] * p[1] + p[3] * p[3]) + math.max(size[1], size[2], size[3]) / 2)
	end
	return r
end

-- Parts per level of detail over all Builds.
function DuskwoodGen.counts(): { shell: number, detail: number, fine: number, builds: number, lights: number }
	local c = { shell = 0, detail = 0, fine = 0, builds = 0, lights = 0 }
	for _, b in DuskwoodGen.all() do
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

local function nearWater(e: Env.Env, x: number, z: number): boolean
	local sd = e.T.streamDistance(x, z)
	if sd > 4 and sd < 26 then
		return true
	end
	if e.T.marshWeight(x, z) > 0.05 and e.T.marshWeight(x, z) < 0.5 then
		return true
	end
	local ld = e.T.lakeDistance(x, z)
	return ld > 4 and ld < 26
end

-- Herbs and ores by the area's character: iron in the thicket's rocks and the gorge's walls, silver on the Blood
-- Cliffs and the manor's rise, nightshade in the dark forest (thicket, the Heart's edge, the cemetery), moonpetal by
-- the water (the stream, the swamp's shores, the Moon Glade).
local function nodeRules(e: Env.Env): { NodeRule }
	local moon = e.sites.moonstone
	local manor = e.sites.manor
	local cemetery = e.sites.cemetery
	return {
		{
			kind = "vein_iron",
			count = 6,
			where = function(_x, _z, theme)
				return theme == "thicket"
			end,
		},
		{
			kind = "vein_iron",
			count = 6,
			where = function(x, z, theme)
				local floor = e.T.gorgeFloor(x, z)
				return floor or theme == "hollow"
			end,
			box = { -770, 420, -300, 780 },
		},
		{
			kind = "vein_silver",
			count = 6,
			where = function(_x, _z, theme)
				return theme == "cliffs"
			end,
		},
		{
			kind = "vein_silver",
			count = 4,
			where = function(x, z, _theme)
				local top = e.T.plateauAt(x, z)
				return top
			end,
			box = { manor.x - 100, manor.z - 90, manor.x + 100, manor.z + 90 },
		},
		{
			kind = "bush_nightshade",
			count = 6,
			where = function(_x, _z, theme)
				return theme == "thicket"
			end,
		},
		{
			kind = "bush_nightshade",
			count = 4,
			where = function(x, z, theme)
				return theme == "rot" and e.T.basinWeight(x, z) < 0.4
			end,
		},
		{
			kind = "bush_nightshade",
			count = 4,
			where = function(_x, _z, _theme)
				return true
			end,
			box = { cemetery.x - 80, cemetery.z - 70, cemetery.x + 80, cemetery.z + 70 },
		},
		{
			kind = "bush_moonpetal",
			count = 5,
			where = function(x, z, _theme)
				local sd = e.T.streamDistance(x, z)
				return sd > 4 and sd < 26
			end,
		},
		{
			kind = "bush_moonpetal",
			count = 4,
			where = function(x, z, theme)
				return (theme == "bog" or theme == "witch") and nearWater(e, x, z)
			end,
		},
		{
			kind = "bush_moonpetal",
			count = 3,
			where = function(_x, _z, _theme)
				return true
			end,
			box = { moon.x - 50, moon.z - 50, moon.x + 50, moon.z + 50 },
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
-- buildings and monster groups.
function DuskwoodGen.nodes(): { NodePlacement }
	if nodeCache then
		return nodeCache
	end
	DuskwoodGen.all()
	local e = envOf()
	local out: { NodePlacement } = {}
	for _, spot in DuskwoodGen.fishingSpots() do
		table.insert(out, { kind = "fishing_duskwood", x = spot.x, z = spot.z })
	end
	local map = Maps.get("duskwood")
	local groups = AreaSpawns.region(e.areas, if map then map.size else { x = 1600, z = 1600 })
	local rng = Rng.new(4506)
	for _, rule in nodeRules(e) do
		local placed, tries = 0, 0
		local box = rule.box or { -770, -770, 770, 770 }
		while placed < rule.count and tries < rule.count * 600 do
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
			if ok and Env.isClear(e, x, z, -2) and e.T.walkable(x, z) and e.T.streamDistance(x, z) > 3 then
				table.insert(out, { kind = rule.kind, x = math.floor(x + 0.5), z = math.floor(z + 0.5) })
				placed += 1
			end
		end
	end
	nodeCache = out
	return out
end

-- Fishing spots: a dry point on the shore with open water 9-12 studs to the south (+Z), where the spot's buoys
-- float: by the swamp's jetty and on the west shore of the swamp by the stilt village.
function DuskwoodGen.fishingSpots(): { { x: number, z: number } }
	local e = envOf()
	local out = {}
	local jetty = e.sites.swampJetty
	local stilts = e.sites.stiltVillage
	for _, c in { { jetty.x - 12, jetty.z - 2 }, { stilts.x + 10, stilts.z - 46 } } do
		local best: { x: number, z: number }? = nil
		local bestD = math.huge
		for dx = -40, 40, 2 do
			for dz = -40, 40, 2 do
				local x, z = c[1] + dx, c[2] + dz
				if
					not e.T.isWater(x, z)
					and e.T.slope(x, z, 2) < 0.5
					and e.T.isWater(x, z + 9)
					and e.T.isWater(x, z + 12)
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

return DuskwoodGen
