--!strict
-- Dumps a cave on the engine for tools/cavemap.py (S48): lune run tools/cavedump.luau <mapId> out.json [step]
-- Grid of floor, ceiling, liquid, room and floor material every `step` studs (default 4) plus the rooms (centre,
-- radius, core, role), tunnels, spawners (Logic/AreaSpawns.cave), ore nodes, portals, the dressing's builds (centre,
-- reach, tag), life points and lights (Logic/WorldGen).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Areas = require("../src/shared/Data/Areas")
local CaveTerrain = require("../src/shared/Logic/CaveTerrain")
local Portals = require("../src/shared/Data/Portals")
local WorldGen = require("../src/shared/Logic/WorldGen")

local args = process.args
local mapId = args[1] or "meadows_cave"
local out = args[2] or `{mapId}.json`
local step = tonumber(args[3]) or 4

local T = assert(CaveTerrain.get(mapId), `no cave shape for {mapId}`)
local started = os.clock()
local half = T.HALF
local floors, ceilings, liquids, rooms, mats = {}, {}, {}, {}, {}
local z = -half + step / 2
while z < half do
	local fr, cr, lr, rr, mr = {}, {}, {}, {}, {}
	local x = -half + step / 2
	while x < half do
		local c = T.column(x, z)
		table.insert(fr, if c.open then math.floor(c.floor * 10 + 0.5) / 10 else false)
		table.insert(cr, if c.open then math.floor(math.min(c.ceiling, 999) * 10 + 0.5) / 10 else false)
		table.insert(lr, if c.liquid then c.liquid.level else false)
		table.insert(rr, c.room or 0)
		table.insert(mr, c.floorMat)
		x += step
	end
	table.insert(floors, fr)
	table.insert(ceilings, cr)
	table.insert(liquids, lr)
	table.insert(rooms, rr)
	table.insert(mats, mr)
	z += step
end
print(string.format("%d x %d columns in %.2f s", #floors[1], #floors, os.clock() - started))

local roomList = {}
for i, r in T.rooms do
	table.insert(roomList, { i = i, x = r.x, z = r.z, r = r.r, core = r.core, role = r.role })
end
local spawners = {}
local cave = Areas.caves.get(mapId)
if cave then
	for _, s in AreaSpawns.cave(cave) do
		table.insert(spawners, { x = s.position.x, y = s.position.y, z = s.position.z, r = s.radius, v = s.variant })
	end
end
local portals = {}
for _, p in Portals.onMap(mapId) do
	table.insert(portals, { x = p.x, z = p.z, kind = p.kind, id = p.id })
end
local builds, life, lights, nodes = {}, {}, {}, {}
local gen = WorldGen.get(mapId)
if gen then
	for _, b in gen.all() do
		table.insert(builds, { x = b.at.x, z = b.at.z, r = gen.radius(b), tag = b.tag, name = b.name })
		for _, l in b.bp.lights do
			table.insert(lights, { x = l.p[1], z = l.p[3], c = l.color })
		end
	end
	for _, l in gen.life() do
		table.insert(life, { x = l.x, z = l.z, kind = l.kind })
	end
	for _, n in gen.nodes() do
		table.insert(nodes, { x = n.x, z = n.z, kind = n.kind })
	end
end

fs.writeFile(
	out,
	serde.encode("json", {
		map = mapId,
		half = half,
		step = step,
		floor = floors,
		ceiling = ceilings,
		liquid = liquids,
		room = rooms,
		material = mats,
		rooms = roomList,
		spawners = spawners,
		portals = portals,
		builds = builds,
		life = life,
		lights = lights,
		nodes = nodes,
	})
)
print(`-> {out}`)
