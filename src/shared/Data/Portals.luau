--!strict
-- Every way between two maps (S25): portals, city gates, cave mouths, cave exits, dungeon gates and the exits of
-- the boss chambers, with their map-relative position. One source of truth for the layouts (they place the
-- hand-made portals from here), the route between maps (Logic/MapRoute), the world map cards and the guide.
-- City gates come from the city plan (Data/Town), cave mouths from Data/Areas and the exit of a generated cave
-- from Logic/CaveGen (its entrance room is fixed), so nothing is written twice.

local Areas = require("./Areas")
local CaveGen = require("../Logic/CaveGen")
local CavePlan = require("../Logic/CavePlan")
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
	local planExit = if boss then boss.exit else { entrance.x - entrance.r + 10, entrance.z, 90 }
	-- S134h: drawn in the scaled cave (Logic/CavePlan; the exit stays in the entrance room, the gate in the antechamber)
	local ex, ez = CavePlan.point(cave.id, planExit[1], planExit[2])
	local exit = { ex, ez, planExit[3] }
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
			x = CavePlan.coord(cave.id, boss.gate[1]),
			z = CavePlan.coord(cave.id, boss.gate[2]),
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

-- W28 (owner: the purple field outside its frame, "E" at the boss gate refused): the one geometry of a portal arch
-- (World/Prefabs.portal) and of a dungeon gate (Prefabs.dungeonGate) in the portal's frame (x across, y up from the
-- ground, -z its face), the box round it the dressing keeps out of (tests/portals.spec), and the interaction ranges
-- shared by the "E" prompt on the field / door and the server's check (TravelService, DungeonService).
local ARCH = table.freeze({
	pillarX = 6, -- pillars' centres (2.5 thick, 15 tall)
	height = 18, -- the arch (and the painted model scaled to it)
	field = table.freeze({ w = 9.5, h = 13.5, y = 7.5, d = 0.4 }), -- the purple field, between the pillars
})
local GATE = table.freeze({
	hornX = 8, -- the horns (3 thick, 18 tall, centre 8 up, leaning out by `hornLean` degrees)
	hornLean = 12,
	height = 18,
	-- the red door; W30: 9.2 wide (it was 12 and its lower corners stood 1.2 studs inside the horns, which lean in
	-- towards their feet)
	door = table.freeze({ w = 9.2, h = 15, y = 7.5, d = 0.6 }),
})
-- W30 (owner: "the portals still look broken"): what is seen of a portal (World/Prefabs.makePortal, arches and city
-- gates alike). The field stays the invisible trigger (prompt, server range); in it stand two glowing ellipses (an
-- outer veil and a brighter core, a little apart so they never flicker into each other), a slowly turning swirl on
-- the core and sparkles that stay inside the field. Shares of the field's width and height; tests/portals.spec.
local LOOK = table.freeze({
	veil = table.freeze({ w = 0.9, h = 0.94, t = 0.45, color = "#7A5CFF" }),
	core = table.freeze({ w = 0.62, h = 0.66, t = 0.55, color = "#B9A8FF" }),
	gap = 0.16, -- the core stands this far in front of the veil, the swirl on the other side (studs)
	thick = 0.08,
	swirl = table.freeze({ share = 0.95, life = 3, rate = 1, spin = { 20, 45 }, color = "#C9B8FF" }), -- of core width
	sparkle = table.freeze({ speed = { 0.2, 0.6 }, life = { 0.8, 1.4 }, size = 0.3, rate = 14 }),
})
local CLEARANCE: { [Kind]: { center: { number }, half: { number } } } = {
	-- from 1 stud over the ground (rubble, tracks and furs on the threshold stay) to the arch's top
	portal = { center = { 0, 9.5, 0 }, half = { 7.25, 8.5, 1.25 } },
	cave = { center = { 0, 9.5, 0 }, half = { 7.25, 8.5, 1.25 } },
	exit = { center = { 0, 9.5, 0 }, half = { 7.25, 8.5, 1.25 } },
	dungeon = { center = { 0, 9.5, 0 }, half = { 9.5, 8.5, 1.5 } },
}
-- The prompt shows this close to the field / door centre; the server accepts up to SERVER_RANGE from the same point
-- (the root part stands a few studs lower and moves on while the request travels).
local PROMPT_RANGE = 12
local SERVER_RANGE = PROMPT_RANGE + 8

-- W30: the pieces of a portal's look in the field of size w x h (field-local x across, y up, z through it): the
-- ellipses' sizes, how far a sparkle can get from the core's box and the swirl's diameter.
local function look(w: number, h: number)
	local veil = { w = w * LOOK.veil.w, h = h * LOOK.veil.h }
	local core = { w = w * LOOK.core.w, h = h * LOOK.core.h }
	local reach = LOOK.sparkle.speed[2] * LOOK.sparkle.life[2] + LOOK.sparkle.size
	return {
		veil = veil,
		core = core,
		swirl = core.w * LOOK.swirl.share,
		sparkleReach = reach,
	}
end

return table.freeze({
	ARCH = ARCH,
	GATE = GATE,
	LOOK = LOOK,
	look = look,
	PROMPT_RANGE = PROMPT_RANGE,
	SERVER_RANGE = SERVER_RANGE,
	-- The box (portal frame) a portal of `kind` keeps free of dressing (nil: city gates, drawn by the town plan).
	clearance = function(kind: Kind): { center: { number }, half: { number } }?
		return CLEARANCE[kind]
	end,
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
