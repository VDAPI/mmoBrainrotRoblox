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
-- W31 (Studio review: the corner arches showed their back to the path and their face to the void past the border):
-- every arch faces into its map (local -z, the veil's bright side and the painted model's front): the west arches
-- east (270), the north-east corner arches south-west (135, towards the map's middle and the road coming up to them).
region("meadows_city", "meadows", "city", -770, 0, 270)
region("meadows_duskwood", "meadows", "duskwood", 730, -720, 135)
region("duskwood_meadows", "duskwood", "meadows", -770, 0, 270, { x = 690, z = -690 })
region("duskwood_city", "duskwood", "city", -770, 160, 270)
region("duskwood_ashen", "duskwood", "ashen", 740, -740, 135)
region("ashen_duskwood", "ashen", "duskwood", -770, 0, 270, { x = 690, z = -690 })
region("ashen_city", "ashen", "city", -770, 160, 270)
region("ashen_frostpeak", "ashen", "frostpeak", 740, -740, 135)
region("frostpeak_ashen", "frostpeak", "ashen", -770, 0, 270, { x = 690, z = -690 })
region("frostpeak_city", "frostpeak", "city", -770, 160, 270)

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
-- W31: an exit stands near the west wall of the entrance room and faces east into the room (270; at 90 its face looked
-- at the rock and the players came up to its back), a dungeon gate near the east end faces west.
local EXIT_ROT = 270
local BOSS_CAVES: { [string]: { exit: { number }, gate: { number } } } = {
	-- { x, z, rot } of the exit portal and of the dungeon gate (World/Layouts/<region>_cave)
	meadows_cave = { exit = { -278, 0, EXIT_ROT }, gate = { 272, 0, 90 } },
	duskwood_cave = { exit = { -275, 0, EXIT_ROT }, gate = { 282, 0, 90 } },
	ashen_cave = { exit = { -278, 0, EXIT_ROT }, gate = { 282, 0, 90 } },
	frostpeak_cave = { exit = { -278, 0, EXIT_ROT }, gate = { 284, 0, 90 } },
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
	local planExit = if boss then boss.exit else { entrance.x - entrance.r + 10, entrance.z, EXIT_ROT }
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
	-- W31 (Studio review 2026-10-21: the painted pillars stood inside the cave frames' slabs): the room the frames
	-- round a cave mouth leave the painted arch, its real footprint with the base slab (Assets.Kit common_portal_01 /
	-- 02 at `height`, measured in Studio about 20.9 across and 16 deep once turned; Logic/ArchFit keeps its size, the
	-- frames keep out of it, tests/portals.spec)
	model = table.freeze({ w = 21, h = 18, d = 16.5 }),
})
-- W31: what a frame round a cave mouth keeps free (tests/portals.spec "cave mouths"): the painted arch (`model` and a
-- quarter stud), the view of it `front` studs down the path above `ground` (rubble, tracks and bones may lie lower),
-- and the opening between the arch and its dark hole. The hole stands straight behind the arch, fills its opening
-- (`w` wide, from under the ground to `top`; the painted opening is about 10 x 14) and is centred on the veil within
-- `tolerance`: the dark the purple sits on, whatever the frame (ice, lava, rock) is made of.
local VIEW = table.freeze({ front = 6, ground = 2, margin = 0.25 })
local HOLE = table.freeze({ w = 17, top = 16, z = 8.7, d = 0.6, tolerance = table.freeze({ x = 0.25, y = 1 }) })
local GATE = table.freeze({
	-- W31 (Studio review: the horns leaned out by 12 degrees and stood 2-4 studs off the 9.2 door, a red slab in a V of
	-- black horns): the horns (`horn` thick, 18 tall, centre 8 up) stand upright 0.2 studs off the door's sides, a basalt
	-- lintel over the door with its ends in the horns
	hornX = 6.3,
	horn = 3,
	height = 18,
	-- the red door; W30: 9.2 wide (it was 12 and its lower corners stood 1.2 studs inside the horns); W31 (Studio: the
	-- sill half buried in the cave's floor in the Moss Cave): the door stands on a raised sill, its top under the lintel
	door = table.freeze({ w = 9.2, h = 14, y = 8.1, d = 0.6 }),
	lintel = table.freeze({ w = 15.6, h = 1.6, y = 15.9, d = 2.4 }),
	-- (the sill and the horns reach 2-3 studs down so a lower floor beside it shows no gap)
	sill = table.freeze({ w = 13.6, h = 3.2, y = -0.4, d = 3.6, z = -0.4 }),
	-- W31 (Studio 2026-10-22: the sill 0.8 under the floor in three boss caves, 1.2 over it in the fourth, the rays of
	-- the server missed or hit something else): the gate stands on the cave's floor from data (Logic/CaveTerrain, flat
	-- at every gate), the voxel floor `ground` studs over it (measured 1.9-2.0 at all four gates), the sill's top
	-- `rise` over that floor (gateBase)
	ground = 2,
	rise = 0.15,
	-- W31 (Studio: the basalt horns black on black in the dark caves): glowing rims on the horns' outer front edges,
	-- three runes up each horn and a dim light from each
	rim = table.freeze({ w = 0.22, d = 0.1, t = 0.35, light = 12, brightness = 0.7 }),
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
	-- W31 (Studio review: the light purple was lost on pale ice and snow): on the Frost Peaks and in their caves a
	-- deeper violet, less see-through
	deep = table.freeze({
		veil = table.freeze({ t = 0.25, color = "#5530E0" }),
		core = table.freeze({ t = 0.35, color = "#8A66FF" }),
		swirl = "#A48CFF",
	}),
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

-- W31: the colours of a portal's look on `mapId`: the deep violet on the snow and ice of the Frost Peaks.
local function palette(
	mapId: string
): { veil: { t: number, color: string }, core: { t: number, color: string }, swirl: string }
	if string.find(mapId, "frostpeak", 1, true) then
		return LOOK.deep
	end
	return {
		veil = { t = LOOK.veil.t, color = LOOK.veil.color },
		core = { t = LOOK.core.t, color = LOOK.core.color },
		swirl = LOOK.swirl.color,
	}
end

-- W31: the boxes a frame round a cave mouth keeps free, in the portal's frame (x across, y up from the ground, z
-- behind it; centre and half sizes): the painted arch, the view of it from the path, the opening before the hole.
local function frameKeepOut(): { { name: string, center: { number }, half: { number } } }
	local m, margin = ARCH.model, VIEW.margin
	local hw, hd, top = m.w / 2 + margin, m.d / 2 + margin, m.h + margin
	return {
		{ name = "arch", center = { 0, (1 + top) / 2, 0 }, half = { hw, (top - 1) / 2, hd } },
		{
			name = "view",
			center = { 0, (VIEW.ground + top) / 2, -hd - VIEW.front / 2 },
			half = { hw, (top - VIEW.ground) / 2, VIEW.front / 2 },
		},
		{
			name = "opening",
			center = { 0, (1 + HOLE.top) / 2, (hd + HOLE.z) / 2 },
			half = { HOLE.w / 2 - 2, (HOLE.top - 1) / 2, (HOLE.z - hd) / 2 },
		},
	}
end

return table.freeze({
	ARCH = ARCH,
	GATE = GATE,
	LOOK = LOOK,
	HOLE = HOLE,
	VIEW = VIEW,
	look = look,
	palette = palette,
	frameKeepOut = frameKeepOut,
	-- Height of a dungeon gate's base (World/Prefabs.dungeonGate) over the cave's floor `floor` at the gate: the sill's
	-- top GATE.rise over the voxel floor, which stands GATE.ground over the floor function.
	gateBase = function(floor: number): number
		return floor + GATE.ground + GATE.rise - (GATE.sill.y + GATE.sill.h / 2)
	end,
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
