--!strict
-- Dumps the Whispering Meadows terrain (S26, Logic/MeadowsTerrain) for tools/meadowsmap.py, a top-down preview
-- without Studio: lune run tools/meadowsdump.luau out.json [step] [builds]
-- Grid of heights, materials and water every `step` studs (default 8) plus roads, streams, lakes, sites, areas,
-- monster groups, crossings, NPC spots and quest anchors; with "builds" also the footprints of the generated
-- buildings and trees (World/Meadows plan).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Areas = require("../src/shared/Data/Areas/meadows")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")

local args = process.args
local out = args[1] or "meadows.json"
local step = tonumber(args[2]) or 8
local withBuilds = args[3] == "builds"

local started = os.clock()
local half = MeadowsTerrain.HALF + 32
local heights, materials, water = {}, {}, {}
local n = 0
local z = -half
while z <= half do
	local hrow, mrow, wrow = {}, {}, {}
	local x = -half
	while x <= half do
		local h, info = MeadowsTerrain.sample(x, z)
		local s = MeadowsTerrain.slope(x, z, step / 2)
		table.insert(hrow, math.floor(h * 10 + 0.5) / 10)
		table.insert(mrow, MeadowsTerrain.materialAt(x, z, h, s, info))
		local w = MeadowsTerrain.water(x, z)
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
for _, s in AreaSpawns.region(Areas, { x = 1600, z = 1600 }) do
	table.insert(groups, { s.position.x, s.position.z, s.count, s.areaId })
end

local builds = {}
local pieces = {}
if withBuilds then
	local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
	for _, b in MeadowsGen.all() do
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
			if p.lod ~= "fine" then
				local lx, lz = p.p[1], p.p[3]
				local wx, wz = b.at.x + c * lx + sn * lz, b.at.z - sn * lx + c * lz
				-- footprint: the largest horizontal extent of the rotated piece, roughly
				local ext = math.max(p.size[1], p.size[3]) * 0.5
				if p.s == "cyl" then
					ext = math.max(p.size[2], p.size[3]) * 0.5
				end
				table.insert(pieces, { math.floor(wx * 10) / 10, math.floor(wz * 10) / 10, math.floor(ext * 10) / 10, p.c, p.lod == "shell" })
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
end

local data = {
	half = half,
	step = step,
	heights = heights,
	materials = materials,
	water = water,
	roads = Areas.roads,
	streams = Areas.streams,
	lakes = Areas.lakes,
	areas = Areas.areas,
	sites = Areas.sites,
	npcSpots = Areas.npcSpots,
	anchors = Areas.questAnchors,
	caves = Areas.caves,
	avoid = Areas.avoid,
	groups = groups,
	crossings = MeadowsTerrain.crossings(),
	builds = builds,
	pieces = pieces,
}
fs.writeFile(out, serde.encode("json", data))
print(string.format("%d columns in %.2f s (%.1f us each) -> %s", n, elapsed, elapsed / n * 1e6, out))
