--!strict
-- Every way between two maps (S25): portals, city gates, cave mouths, cave exits, dungeon gates and the exits of
-- the boss chambers, with their map-relative position. One source of truth for the layouts (they place the
-- hand-made portals from here), the route between maps (Logic/MapRoute), the world map cards and the guide.
-- City gates come from the city plan (Data/Town), cave mouths from Data/Areas and the exit of a generated cave
-- from Logic/CaveGen (its entrance room is fixed), so nothing is written twice.

local Areas = require("./Areas")
local CaveGen = require("../Logic/CaveGen")
local Maps = require("./Maps")
local Town = require("./Town")

export type Kind =
	"portal" -- portal arch between region maps (and back to the city)
	| "gate" -- city gate
	| "cave" -- cave mouth on a region map
	| "exit" -- way out of a cave or a boss chamber
	| "dungeon" -- boss dungeon gate in the last cave of a region

export type Portal = {
	id: string,
	map: string, -- map the portal stands on
	target: string, -- map it leads to
	kind: Kind,
	x: number,
	z: number,
	rot: number, -- yaw in degrees
	-- Landing point on the target map (map-relative); nil = the target's own rule (areas, spawn).
	arrive: { x: number, z: number }?,
}

local list: { Portal } = {}
local byId: { [string]: Portal } = {}
local byMap: { [string]: { Portal } } = {}

local function add(portal: Portal)
	assert(byId[portal.id] == nil, `Portals: duplicate id {portal.id}`)
	byId[portal.id] = portal
	table.insert(list, portal)
	local onMap = byMap[portal.map]
	if not onMap then
		onMap = {}
		byMap[portal.map] = onMap
	end
	table.insert(onMap, portal)
end

local function cityArrival(region: string): { x: number, z: number }?
	local gate = Town.gate(region)
	return if gate then { x = gate.arrive[1], z = gate.arrive[2] } else nil
end

-- Region portals (S08, placed by World/Layouts/<map>). Portals to the city land inside its gate.
local function region(id: string, map: string, target: string, x: number, z: number, rot: number, arrive: any?)
	add({
		id = id,
		map = map,
		target = target,
		kind = "portal",
		x = x,
		z = z,
		rot = rot,
		arrive = if target == "city" then cityArrival(map) else arrive,
	})
end
region("meadows_city", "meadows", "city", -770, 0, 90)
region("meadows_duskwood", "meadows", "duskwood", 730, -720, 45)
region("duskwood_meadows", "duskwood", "meadows", -770, 0, 90, { x = 690, z = -690 })
region("duskwood_city", "duskwood", "city", -770, 160, 90)
region("duskwood_ashen", "duskwood", "ashen", 740, -740, 45)
region("ashen_duskwood", "ashen", "duskwood", -770, 0, 90, { x = 690, z = -690 })
region("ashen_city", "ashen", "city", -770, 160, 90)
region("ashen_frostpeak", "ashen", "frostpeak", 740, -740, 45)
region("frostpeak_ashen", "frostpeak", "ashen", -770, 0, 90, { x = 690, z = -690 })
region("frostpeak_city", "frostpeak", "city", -770, 160, 90)

-- City gates (S21, the city plan).
for _, gate in Town.city.gates do
	add({
		id = gate.portal,
		map = "city",
		target = gate.target,
		kind = "gate",
		x = gate.x,
		z = gate.z,
		rot = gate.rot,
		arrive = nil,
	})
end

-- Cave mouths on the region maps and the way back out of every cave (S19).
local BOSS_CAVES: { [string]: { exit: { number }, gate: { number } } } = {
	-- { x, z, rot } of the exit portal and of the dungeon gate (World/Layouts/<region>_cave)
	meadows_cave = { exit = { -278, 0, 90 }, gate = { 272, 0, 90 } },
	duskwood_cave = { exit = { -275, 0, 90 }, gate = { 282, 0, 90 } },
	ashen_cave = { exit = { -278, 0, 90 }, gate = { 282, 0, 90 } },
	frostpeak_cave = { exit = { -278, 0, 90 }, gate = { 284, 0, 90 } },
}
for mapId, data in Areas.byMap do
	for _, entrance in data.caves do
		add({
			id = `{mapId}_{entrance.cave}`,
			map = mapId,
			target = entrance.cave,
			kind = "cave",
			x = entrance.x,
			z = entrance.z,
			rot = entrance.rot,
			arrive = nil,
		})
	end
end
for _, cave in Areas.caves.list do
	local boss = BOSS_CAVES[cave.id]
	local entrance = CaveGen.ENTRANCE
	local exit = if boss then boss.exit else { entrance.x - entrance.r + 10, entrance.z, 90 }
	add({
		id = `{cave.id}_exit`,
		map = cave.id,
		target = cave.region,
		kind = "exit",
		x = exit[1],
		z = exit[2],
		rot = exit[3],
		arrive = Areas.arrivalOf(cave.id),
	})
	if boss then
		-- The dungeon gate (S09): entering needs a party check on the server (DungeonService), so it is a way
		-- for the route but not a portal model.
		add({
			id = `dungeon_{cave.region}`,
			map = cave.id,
			target = `dungeon_{cave.region}`,
			kind = "dungeon",
			x = boss.gate[1],
			z = boss.gate[2],
			rot = boss.gate[3],
			arrive = nil,
		})
	end
end

-- Exits of the boss chambers (S09, World/Layouts/DungeonArena): back in front of the dungeon gate.
for _, map in Maps.byId do
	if map.biome == "dungeon" then
		local region = string.match(map.id, "^dungeon_(.+)$") or ""
		local cave = Maps.get(`{region}_cave`)
		local entrance = cave and cave.dungeonEntrance
		add({
			id = `{map.id}_exit`,
			map = map.id,
			target = `{region}_cave`,
			kind = "exit",
			x = 0,
			z = 78,
			rot = 0,
			arrive = if entrance then { x = entrance.x - 24, z = entrance.z } else nil,
		})
	end
end

-- Stable order (the route search walks the portals of a map in this order).
for _, onMap in byMap do
	table.sort(onMap, function(a, b)
		return a.id < b.id
	end)
end

return table.freeze({
	list = list,
	byId = byId,
	get = function(id: string): Portal?
		return byId[id]
	end,
	-- Portals standing on `mapId` (sorted by id).
	onMap = function(mapId: string): { Portal }
		return byMap[mapId] or {}
	end,
})
