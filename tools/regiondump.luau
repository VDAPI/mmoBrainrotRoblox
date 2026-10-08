--!strict
-- Dumps a shaped map's terrain for tools/regionmap.py, a top-down preview without Studio (S45, generalised from the
-- S26 meadowsdump): lune run tools/regiondump.luau <map> out.json [step] [builds]
-- Grid of heights, materials and water every `step` studs (default 8) plus roads, streams, lakes, sites, areas,
-- monster groups, crossings, NPC spots, quest anchors and nodes; with "builds" also the generated buildings and
-- trees (Logic/WorldGen). Maps: meadows (Logic/MeadowsTerrain) and every Data/Terrain/<map> (Logic/RegionTerrain).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Areas = require("../src/shared/Data/Areas")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Maps = require("../src/shared/Data/Maps")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")

local args = process.args
local mapId = args[1] or "duskwood"
local out = args[2] or `{mapId}.json`
local step = tonumber(args[3]) or 8
local withBuilds = args[4] == "builds"

local data = assert(Areas.byMap[mapId], `no areas for {mapId}`)
local map = assert(Maps.get(mapId), `no map {mapId}`)

type Api = {
	sample: (number, number) -> (number, any),
	slope: (number, number, number?) -> number,
	materialAt: (number, number, number, number, any) -> string,
	water: (number, number) -> number?,
	crossings: () -> { any },
	HALF: number,
}

local terrain: Api
if mapId == "meadows" then
	terrain = MeadowsTerrain :: any
else
	terrain = assert(RegionTerrain.get(mapId), `no terrain for {mapId}`) :: any
end

local started = os.clock()
local half = terrain.HALF + 32
local heights, materials, water = {}, {}, {}
local n = 0
local z = -half
while z <= half do
	local hrow, mrow, wrow = {}, {}, {}
	local x = -half
	while x <= half do
		local h, info = terrain.sample(x, z)
		local s = terrain.slope(x, z, step / 2)
		table.insert(hrow, math.floor(h * 10 + 0.5) / 10)
		table.insert(mrow, terrain.materialAt(x, z, h, s, info))
		local w = terrain.water(x, z)
		table.insert(wrow, if w then math.floor(w * 10 + 0.5) / 10 else false)
		n += 1
		x += step
	end
	table.insert(heights, hrow)
	table.insert(materials, mrow)
	table.insert(water, wrow)
	z += step
end
local elapsed = os.clock() - started

local groups = {}
local spawnStarted = os.clock()
local perArea: { [string]: number } = {}
for _, s in AreaSpawns.region(data, map.size) do
	table.insert(groups, { s.position.x, s.position.z, s.count, s.areaId })
	perArea[s.areaId] = (perArea[s.areaId] or 0) + 1
end
local spawnElapsed = os.clock() - spawnStarted

local builds = {}
local pieces = {}
local trees = {}
local nodes = {}
local life = {}
if withBuilds then
	local WorldGen = require("../src/shared/Logic/WorldGen")
	local gen = assert(WorldGen.get(mapId), `no generator for {mapId}`)
	for _, b in gen.all() do
		local shell, detail, fine = 0, 0, 0
		for _, p in b.bp.pieces do
			if p.lod == "shell" then
				shell += 1
			elseif p.lod == "detail" then
				detail += 1
			else
				fine += 1
			end
		end
		local r = math.rad(b.at.rot)
		local c, sn = math.cos(r), math.sin(r)
		for _, p in b.bp.pieces do
			if p.lod ~= "fine" and b.tag ~= "trees" then
				local lx, lz = p.p[1], p.p[3]
				local wx, wz = b.at.x + c * lx + sn * lz, b.at.z - sn * lx + c * lz
				local ext = math.max(p.size[1], p.size[3]) * 0.5
				if p.s == "cyl" then
					ext = math.max(p.size[2], p.size[3]) * 0.5
				end
				table.insert(pieces, {
					math.floor(wx * 10) / 10,
					math.floor(wz * 10) / 10,
					math.floor(ext * 10) / 10,
					p.c,
					p.lod == "shell",
				})
			end
		end
		table.insert(builds, {
			name = b.name,
			tag = b.tag,
			x = b.at.x,
			z = b.at.z,
			rot = b.at.rot,
			shell = shell,
			detail = detail,
			fine = fine,
		})
	end
	for _, t in gen.trees() do
		table.insert(trees, { t.x, t.z, t.kind })
	end
	for _, nd in gen.nodes() do
		table.insert(nodes, { nd.x, nd.z, nd.kind })
	end
	for _, l in gen.life() do
		table.insert(life, { l.x, l.z, l.kind })
	end
end

local dump = {
	map = mapId,
	half = half,
	step = step,
	heights = heights,
	materials = materials,
	water = water,
	roads = data.roads,
	streams = data.streams or {},
	lakes = data.lakes,
	areas = data.areas,
	sites = data.sites or {},
	npcSpots = data.npcSpots or {},
	anchors = data.questAnchors or {},
	caves = data.caves,
	avoid = data.avoid,
	groups = groups,
	crossings = terrain.crossings(),
	builds = builds,
	pieces = pieces,
	trees = trees,
	nodes = nodes,
	life = life,
}
fs.writeFile(out, serde.encode("json", dump))
print(string.format("%d columns in %.2f s (%.1f us each) -> %s", n, elapsed, elapsed / n * 1e6, out))
print(string.format("groups: %d in %.2f s", #groups, spawnElapsed))
for _, area in data.areas do
	local got = perArea[area.id] or 0
	print(string.format("  %-24s %d/%d%s", area.id, got, area.groups, if got ~= area.groups then "  <- MISSING" else ""))
end
if withBuilds then
	print(string.format("builds %d, trees %d, nodes %d, life %d", #builds, #trees, #nodes, #life))
end
