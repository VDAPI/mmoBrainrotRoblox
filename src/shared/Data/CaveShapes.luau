--!strict
-- Shapes of the caves and boss chambers on the cave engine (S48; S49-S51 add their maps here). One entry per map id;
-- the room plan and the monsters stay in Data/Areas/Caves (generated caves: Logic/CaveGen from their seed), so this
-- file only shapes, paints and names what is already there. Read by Logic/CaveTerrain (rock, floor, ceiling,
-- liquids), Logic/CaveDress (the dressing per room role), Data/Ambience (moods per room) and the tools.
--
-- Column model: every column has one gap of air between a floor and a ceiling (or none: rock). Rooms are rings whose
-- wall radius wanders outwards by `wall.amp` studs (never inwards: the plan's room is always open); near the wall
-- the floor rises and the ceiling falls until they meet (no vertical voxel walls). Tunnels join the rooms and wind
-- sideways (`wiggle`). The core of every fighting room (0.65 r + 8 round its centre) stays dry, flat and high:
-- floor features (pools, terraces, pits, stalagmites) never touch it.
--
-- Fields of an entry:
--   theme       dressing module (Logic/CaveDress: "Moss", "Smugglers", "Warren", "GoblinThrone")
--   floorY      floor of the plan (default 0; entrances, the boss antechamber and arenas stay on it)
--   wall        { amp, scale }: how far the walls bulge out (studs) and the noise scale along the wall
--   ceiling     { amp, scale }: ceiling noise (studs) outside the cores
--   materials   { wall, floor, accent (bands in the walls), bed (under liquids), moss? (by water, on ledges) }
--   rooms[i]    per room of the plan: role (an id of ROLES), decor (client decoration theme), dy (floor offset),
--               floor (floor material), flat (flat ceiling at h: entrances, antechambers), h (ceiling override)
--   tunnels     corridors when the plan has none (boss caves, chambers): { ax, az, bx, bz, w, h? }
--   tunnelH     ceiling of the tunnels (default 14), wiggle = sideways wander of the tunnels (studs, default 6)
--   extraRooms  rooms outside the plan (chambers: arena, entry niche, throne niche, galleries): { x, z, r, h, role,
--               flat?, dy?, decor?, floor? }
--   features    the feature list below
--   arena       chambers: { x, z, r } of the flat fighting floor (the contract of World/Layouts/DungeonArena)
--
-- Features (S49-S51 add kinds without changing these):
--   pool        { kind, x, z, r, level, depth, ragged?, liquid? ("water" | "lava" | "ice") }
--   stream      { kind, points, width, level, drop, depth, liquid? }: an open channel, the level falls by `drop`
--   waterfall   { kind, x, z, top }: water falling from a crack in the ceiling (dressing and life; no terrain)
--   skyhole     { kind, x, z, r }: the ceiling opens to the sky
--   terrace     { kind, x, z, r, dy, blend, unreachable? }: the floor raised by dy; `blend` = width of the ramp
--               (small = a ledge nobody climbs: unreachable galleries)
--   pit         { kind, x, z, r, depth, blend }: a hollow with a ramp out (at most 8 studs deep)
--   pillar      { kind, x, z, r }: rock from floor to ceiling
--   stalagmites { kind, x, z, r, spacing, height }: cones of the floor (tall ones reach the ceiling)
--   stalactites { kind, x, z, r, spacing, length }: cones of the ceiling
--   niche       { kind, x, z, r, h, dy? }: a hollow behind a room's wall (a small extra room)

export type RoomShape = {
	role: string,
	decor: string?,
	dy: number?,
	floor: string?,
	flat: boolean?,
	h: number?,
}

export type ExtraRoom = {
	x: number,
	z: number,
	r: number,
	h: number,
	role: string,
	flat: boolean?,
	dy: number?,
	decor: string?,
	floor: string?,
}

export type Tunnel = { ax: number, az: number, bx: number, bz: number, w: number, h: number? }

export type Feature = { [string]: any } -- `kind` + the fields of its kind (above)

export type Materials = { wall: string, floor: string, accent: string, bed: string, moss: string? }

export type Shape = {
	theme: string,
	floorY: number?,
	wall: { amp: number, scale: number },
	ceiling: { amp: number, scale: number },
	materials: Materials,
	rooms: { [number]: RoomShape }?,
	tunnels: { Tunnel }?,
	tunnelH: number?,
	wiggle: number?,
	extraRooms: { ExtraRoom }?,
	features: { Feature },
	arena: { x: number, z: number, r: number }?,
}

-- Room roles (English ids; S49-S51 extend the list). Used by /tpcave, the dressing, the moods and the wiki.
local ROLES = {
	"entrance",
	"antechamber",
	"arena",
	"throne",
	"gallery",
	"grotto",
	"bearden",
	"barracks",
	"queennest",
	"spiderhall",
	"shrine",
	"landing",
	"council",
	"chief",
	"pen",
	"village",
	"diggings",
	"shaft",
	"spiderpit",
	"niche",
}

local function room(r: RoomShape): RoomShape
	return r
end

local function extra(r: ExtraRoom): ExtraRoom
	return r
end

local byMap: { [string]: Shape } = {}

-- Mosshollow Cave (16-20): a green grotto under Bear Ravine; water from the Meadows' waterfall seeps in, the moss
-- glows, Grimrok's goblins camp, spiders hunt the goblins.
byMap.meadows_cave = {
	theme = "Moss",
	wall = { amp = 14, scale = 26 },
	ceiling = { amp = 3, scale = 24 },
	materials = { wall = "Rock", floor = "Rock", accent = "Slate", bed = "Salt", moss = "LeafyGrass" },
	wiggle = 9,
	rooms = {
		room({ role = "entrance", decor = "moss", flat = true }),
		room({ role = "grotto", decor = "moss", h = 34 }),
		room({ role = "bearden", decor = "den" }),
		room({ role = "barracks", decor = "junk" }),
		room({ role = "queennest", decor = "web", dy = -3 }),
		room({ role = "spiderhall", decor = "web" }),
		room({ role = "shrine", decor = "moss" }),
		room({ role = "antechamber", decor = "junk", flat = true }),
	},
	tunnels = {
		{ ax = -215, az = 0, bx = -100, bz = 0, w = 16, h = 18 },
		{ ax = -150, az = 0, bx = -150, bz = -110, w = 16, h = 16 },
		{ ax = -150, az = 0, bx = -150, bz = 110, w = 16, h = 16 },
		{ ax = -30, az = -70, bx = -30, bz = -180, w = 16, h = 16 },
		{ ax = -30, az = 70, bx = 60, bz = 170, w = 16, h = 16 },
		{ ax = 40, az = 0, bx = 190, bz = 0, w = 16, h = 18 },
		{ ax = 100, az = 0, bx = 130, bz = -120, w = 16, h = 16 },
	},
	tunnelH = 16,
	features = {
		-- the Great Grotto: the underground lake in a bay behind the south-east wall, the waterfall from a crack
		{ kind = "niche", x = 40, z = 58, r = 28, h = 24 },
		{ kind = "pool", x = 44, z = 62, r = 22, level = -1.2, depth = 4, ragged = 4 },
		{ kind = "waterfall", x = 58, z = 74, top = 22 },
		{ kind = "stalagmites", x = -30, z = -64, r = 26, spacing = 9, height = 7 },
		{ kind = "stalactites", x = -30, z = 0, r = 90, spacing = 12, length = 5 },
		-- the bear den's lairs in the wall's bulges
		{ kind = "niche", x = -182, z = -162, r = 13, h = 14 },
		{ kind = "niche", x = -122, z = -170, r = 11, h = 12 },
		-- the Queen's web behind the nest
		{ kind = "niche", x = 158, z = -200, r = 18, h = 26, dy = -3 },
		-- the spider hall's stalactites and pillars by the walls
		{ kind = "stalactites", x = -30, z = -230, r = 64, spacing = 9, length = 8 },
		{ kind = "pillar", x = -78, z = -262, r = 4 },
		{ kind = "pillar", x = 22, z = -270, r = 4 },
		-- the shrine's altar terrace by the south wall
		{ kind = "niche", x = 90, z = 274, r = 18, h = 20 },
		{ kind = "terrace", x = 90, z = 278, r = 14, dy = 4, blend = 6 },
		-- drops in the tunnels
		{ kind = "stalactites", x = -150, z = 0, r = 30, spacing = 10, length = 4 },
	},
}

-- Smugglers' Hideout (7-12): the gang's den under the Merchants' Road: an underground stream, contraband from
-- robbed wagons, the moon in a sinkhole.
byMap.meadows_hideout = {
	theme = "Smugglers",
	wall = { amp = 12, scale = 24 },
	ceiling = { amp = 2.5, scale = 22 },
	wiggle = 8,
	materials = { wall = "Rock", floor = "Ground", accent = "Slate", bed = "Salt" },
	rooms = {
		room({ role = "entrance", decor = "smugglers", flat = true }),
		room({ role = "landing", decor = "smugglers" }),
		room({ role = "council", decor = "smugglers", h = 32 }),
		room({ role = "chief", decor = "smugglers" }),
		room({ role = "pen", decor = "pen", floor = "Mud" }),
	},
	features = {
		-- the black stream from a crack in the north round the landing's north-west wall
		{
			kind = "stream",
			points = { -70, -96, -96, -84, -120, -64, -129, -42 },
			width = 8,
			level = -1.2,
			drop = 0.6,
			depth = 2.5,
		},
		-- the sinkhole over the council hall, the lookout terrace by the north wall
		{ kind = "skyhole", x = -5, z = 72, r = 12 },
		{ kind = "terrace", x = 24, z = -14, r = 13, dy = 6, blend = 7 },
		{ kind = "stalactites", x = -86, z = -36, r = 50, spacing = 11, length = 4 },
	},
}

-- Goblin Burrow (12-16): a low winding warren: goblins hoard scrap from the Meadows, kobolds dig, spiders nest in
-- the old diggings.
byMap.meadows_burrow = {
	theme = "Warren",
	wall = { amp = 11, scale = 20 },
	ceiling = { amp = 2, scale = 18 },
	materials = { wall = "Ground", floor = "Ground", accent = "Mud", bed = "Salt" },
	rooms = {
		room({ role = "entrance", decor = "junk", flat = true }),
		room({ role = "village", decor = "junk" }),
		room({ role = "diggings", decor = "diggings", floor = "Salt" }),
		room({ role = "shaft", decor = "diggings" }),
		room({ role = "spiderpit", decor = "web", dy = -4 }),
	},
	tunnelH = 13,
	wiggle = 10,
	features = {
		-- the dug step by the diggings' wall, the chief's shaft in a niche behind the east wall
		{ kind = "niche", x = -40, z = -84, r = 15, h = 14 }, -- the caved-in side gallery the spiders took
		{ kind = "terrace", x = -40, z = -84, r = 12, dy = -3, blend = 6 },
		{ kind = "niche", x = 178, z = 0, r = 14, h = 20 },
		{ kind = "pit", x = 180, z = 0, r = 12, depth = 5, blend = 11 },
		-- blind holes off the tunnels (the goblins' beds)
		{ kind = "niche", x = -140, z = 56, r = 9, h = 10 },
		{ kind = "niche", x = -24, z = 30, r = 8, h = 10 },
		{ kind = "niche", x = 68, z = -40, r = 8, h = 10 },
		{ kind = "stalactites", x = 96, z = 114, r = 50, spacing = 10, length = 4 },
	},
}

-- Grimrok's Chamber (boss of the Meadows): a flat arena of trampled earth under a dome, war totems round it, the
-- throne niche in the north, unreachable galleries east and west.
byMap.dungeon_meadows = {
	theme = "GoblinThrone",
	wall = { amp = 6, scale = 30 },
	ceiling = { amp = 2, scale = 30 },
	materials = { wall = "Rock", floor = "Ground", accent = "Slate", bed = "Salt" },
	extraRooms = {
		extra({ x = 0, z = -10, r = 86, h = 40, role = "arena", flat = true, decor = "junk" }),
		extra({ x = 0, z = 72, r = 20, h = 26, role = "entrance", flat = true }),
		extra({ x = 0, z = -102, r = 20, h = 26, role = "throne", decor = "junk" }),
		extra({ x = -96, z = -10, r = 20, h = 34, role = "gallery" }),
		extra({ x = 96, z = -10, r = 20, h = 34, role = "gallery" }),
	},
	features = {
		{ kind = "terrace", x = 0, z = -106, r = 13, dy = 4, blend = 4 },
		{ kind = "terrace", x = -100, z = -10, r = 17, dy = 12, blend = 1.5, unreachable = true },
		{ kind = "terrace", x = 100, z = -10, r = 17, dy = 12, blend = 1.5, unreachable = true },
	},
	arena = { x = 0, z = -10, r = 74 },
}

return table.freeze({
	byMap = byMap,
	ROLES = ROLES,
})
