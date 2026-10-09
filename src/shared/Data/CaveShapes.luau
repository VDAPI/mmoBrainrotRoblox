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
--   niche       { kind, x, z, r, h, dy?, plan?, hx?, hz?, rot?, ceil? }: a hollow behind a room's wall (a small extra room)
-- S49 (architecture: crypts and barrows; natural rooms unchanged):
--   rooms[i] / extraRooms: plan = "rect" (hx, hz half sizes, rot degrees) | "octagon" (inradius r) with straight walls
--               without noise (the inscribed circle stays >= the core), ceil = "vault" (barrel vault along the longer
--               axis) | "corbel" (stepped beehive dome) | "dome" (default)
--   masonry     true: the tunnels run straight with a constant width and a vaulted ceiling
--   chimney     { kind, x, z, r, h }: the ceiling raised to h over the floor (a shaft over a well)
--   dais        { kind, x, z, r, h, dir }: a podium h studs high, stairs (steps <= 2 studs every 4) towards bearing dir
--               (degrees, 0 = +x, 90 = +z), straight drops on the other sides
--   causeway    { kind, points, width }: a dry path across a pool (a ring of water with `inner` keeps its middle dry)
--   ring        { kind, x, z, bands = { { r1, r2, material } }, spokes = { n, width, material, from?, to? } }: a mosaic
--               of floor materials (bands >= 4 studs wide)
--   niches      { kind, room, spacing, tiers, w, h }: rows of niches along a room's walls (positions: T.niches(); the
--               terrain keeps a plain wall, the dressing builds the shelves with skulls and shrouds)
--   pool.inner  a ring of water from `inner` to `r`; terrace.inner / terrace.gaps a ring terrace with gaps

export type RoomShape = {
	role: string,
	decor: string?,
	dy: number?,
	floor: string?,
	flat: boolean?,
	h: number?,
	plan: string?,
	hx: number?,
	hz: number?,
	rot: number?,
	ceil: string?,
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
	plan: string?,
	hx: number?,
	hz: number?,
	rot: number?,
	ceil: string?,
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
	masonry: boolean?,
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
	-- S49 Duskwood
	"feeding",
	"moon",
	"wetden",
	"dromos",
	"ritual",
	"burial",
	"altar",
	"ghoulden",
	"flooded",
	"columns",
	"familycrypt",
	"soulwell",
	"ossuary",
	"sanctum",
	"apse",
}

local function room(r: RoomShape): RoomShape
	return r
end

local function extra(r: ExtraRoom): ExtraRoom
	return r
end

local function tunnel(t: Tunnel): Tunnel
	return t
end

-- A band of a floor mosaic: { from radius, to radius, material }.
local function band(r1: number, r2: number, material: string): { any }
	return { r1, r2, material }
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
		tunnel({ ax = -215, az = 0, bx = -100, bz = 0, w = 16, h = 18 }),
		tunnel({ ax = -150, az = 0, bx = -150, bz = -110, w = 16, h = 16 }),
		tunnel({ ax = -150, az = 0, bx = -150, bz = 110, w = 16, h = 16 }),
		tunnel({ ax = -30, az = -70, bx = -30, bz = -180, w = 16, h = 16 }),
		tunnel({ ax = -30, az = 70, bx = 60, bz = 170, w = 16, h = 16 }),
		tunnel({ ax = 40, az = 0, bx = 190, bz = 0, w = 16, h = 18 }),
		tunnel({ ax = 100, az = 0, bx = 130, bz = -120, w = 16, h = 16 }),
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

-- S49 ---------------------------------------------------------------------------------------------------------------

-- Wolfden Hollow (24-31): an earthen den under the roots of a giant dead oak, dug by werewolves and bears; hanging
-- roots, claw marks, fur; the Moon Chamber's shaft of moonlight on the moonstone.
byMap.duskwood_den = {
	theme = "Den",
	wall = { amp = 12, scale = 22 },
	ceiling = { amp = 2.5, scale = 18 },
	materials = { wall = "Slate", floor = "Ground", accent = "Rock", bed = "Mud", moss = "LeafyGrass" },
	rooms = {
		room({ role = "entrance", decor = "den", flat = true }),
		room({ role = "feeding", decor = "den", dy = -2 }),
		room({ role = "bearden", decor = "den", h = 32 }),
		room({ role = "moon", decor = "den", dy = 6, h = 46 }),
		room({ role = "wetden", decor = "moss", dy = -4, h = 20 }),
	},
	tunnelH = 16,
	wiggle = 8,
	features = {
		-- the ghouls' feeding pits by the walls of the Feeding Pit (out of the core)
		{ kind = "pit", x = -142, z = -66, r = 6, depth = 1.5, blend = 4 },
		{ kind = "pit", x = -78, z = -114, r = 6, depth = 1.5, blend = 4 },
		{ kind = "pit", x = -52, z = -100, r = 5, depth = 1.5, blend = 4 },
		-- the Great Den: the oak's taproot down to the floor by the north wall, the terrace by the north-east wall
		{ kind = "pillar", x = 20, z = -52, r = 4.5 },
		{ kind = "terrace", x = 70, z = -44, r = 13, dy = 4, blend = 6 },
		-- the Moon Chamber: the hole in the vault
		{ kind = "skyhole", x = 134, z = -70, r = 9 },
		-- the Wet Den: the spring pool in a niche behind the south wall
		{ kind = "niche", x = -112, z = 118, r = 12, h = 14, dy = -4 },
		{ kind = "pool", x = -112, z = 120, r = 8, level = -4.6, depth = 1.4, ragged = 1.5 },
		{ kind = "stalactites", x = 26, z = -6, r = 60, spacing = 11, length = 4 },
	},
}

-- Cultist Barrow (31-38): inside a burial mound of dry stone walls with corbelled vaults, taken by the cult; the
-- ghouls dug in from the side, the lower crypt is flooded with black water and snakes.
byMap.duskwood_barrow = {
	theme = "Barrow",
	wall = { amp = 9, scale = 20 },
	ceiling = { amp = 1.5, scale = 18 },
	materials = { wall = "Slate", floor = "Ground", accent = "Basalt", bed = "Mud" },
	masonry = true,
	tunnelH = 15,
	rooms = {
		room({ role = "dromos", decor = "barrow", plan = "rect", hx = 34, hz = 26, flat = true, h = 22 }),
		room({ role = "ritual", decor = "barrow", plan = "octagon", ceil = "corbel", h = 34 }),
		room({ role = "burial", decor = "barrow", plan = "rect", hx = 48, hz = 46, flat = true, h = 20 }),
		room({ role = "altar", decor = "barrow", plan = "octagon", ceil = "corbel", dy = 2, h = 40 }),
		room({ role = "ghoulden", decor = "den" }),
		room({ role = "flooded", decor = "barrow", plan = "octagon", ceil = "corbel", dy = -5, h = 24 }),
	},
	features = {
		-- the rite circle's mosaic
		{
			kind = "ring",
			x = -86,
			z = -18,
			bands = { band(10, 14, "Basalt") },
			spokes = { n = 6, width = 4, material = "Basalt", from = 0, to = 10 },
		},
		{ kind = "niches", room = 3, spacing = 7, tiers = 3, w = 5, h = 5 },
		-- the Heart of the Barrow: the apse behind the east wall with the altar's dais and the black pool
		{ kind = "niche", x = 190, z = 50, r = 18, h = 26, dy = 2, plan = "octagon", ceil = "corbel" },
		{ kind = "dais", x = 188, z = 50, r = 8, h = 4, dir = 180 },
		{ kind = "pool", x = 200, z = 50, r = 5, level = 1.2, depth = 1.4 },
		-- the Flooded Crypt: a ring of black water by the walls, the flooded nave behind the south wall, the causeway
		{ kind = "niche", x = -69, z = 170, r = 18, h = 22, dy = -5, plan = "rect", hx = 16, hz = 14 },
		{ kind = "pool", x = -69, z = 113, r = 70, inner = 40, level = -4.4, depth = 2.2 },
		{ kind = "causeway", points = { -73, 62, -71, 82 }, width = 8 },
	},
}

-- Crypt of the Forgotten (38-45, boss cave): the crypt of a forgotten royal house, built by hand: straight walls,
-- barrel vaults, paved floors, the procession axis z = 0 from the entrance to the seal of Morvane.
byMap.duskwood_cave = {
	theme = "Crypt",
	wall = { amp = 0, scale = 30 },
	ceiling = { amp = 0, scale = 30 },
	materials = { wall = "Slate", floor = "Basalt", accent = "Basalt", bed = "Mud" },
	masonry = true,
	tunnelH = 19,
	rooms = {
		room({
			role = "entrance",
			decor = "crypt",
			plan = "rect",
			hx = 38,
			hz = 34,
			ceil = "vault",
			h = 26,
			floor = "Pavement",
		}),
		room({
			role = "columns",
			decor = "crypt",
			plan = "rect",
			hx = 70,
			hz = 66,
			ceil = "vault",
			h = 34,
			floor = "Pavement",
		}),
		room({ role = "familycrypt", decor = "crypt", plan = "octagon", ceil = "vault", h = 24 }),
		room({ role = "barracks", decor = "crypt", plan = "rect", hx = 46, hz = 42, ceil = "vault", h = 24 }),
		room({ role = "soulwell", decor = "crypt", plan = "octagon", h = 26 }),
		room({ role = "ossuary", decor = "crypt", plan = "octagon", h = 30, floor = "Pavement" }),
		room({ role = "gallery", decor = "crypt", plan = "rect", hx = 54, hz = 42, ceil = "vault", h = 26 }),
		room({ role = "sanctum", decor = "crypt", plan = "octagon", h = 28 }),
		room({
			role = "antechamber",
			decor = "crypt",
			plan = "rect",
			hx = 48,
			hz = 40,
			flat = true,
			h = 32,
			floor = "Pavement",
		}),
	},
	tunnels = {
		tunnel({ ax = -215, az = 0, bx = -170, bz = 0, w = 14, h = 20 }),
		tunnel({ ax = -110, az = -60, bx = -110, bz = -130, w = 14 }),
		tunnel({ ax = -110, az = 60, bx = -110, bz = 130, w = 14 }),
		tunnel({ ax = -50, az = 0, bx = -10, bz = 0, w = 14, h = 20 }),
		tunnel({ ax = 40, az = -50, bx = 40, bz = -130, w = 14 }),
		tunnel({ ax = 40, az = 50, bx = 40, bz = 130, w = 14 }),
		tunnel({ ax = 90, az = 0, bx = 110, bz = 0, w = 14, h = 20 }),
		tunnel({ ax = 190, az = 0, bx = 205, bz = 0, w = 14, h = 20 }),
		tunnel({ ax = -70, az = -170, bx = 0, bz = -170, w = 14 }),
		tunnel({ ax = -70, az = 170, bx = 0, bz = 170, w = 14 }),
	},
	features = {
		-- the Hall of Columns: two rows of pillars at z = +-52 (a gap at x -110 for the north and south corridors)
		{ kind = "pillar", x = -164, z = -52, r = 3.5 },
		{ kind = "pillar", x = -146, z = -52, r = 3.5 },
		{ kind = "pillar", x = -128, z = -52, r = 3.5 },
		{ kind = "pillar", x = -92, z = -52, r = 3.5 },
		{ kind = "pillar", x = -74, z = -52, r = 3.5 },
		{ kind = "pillar", x = -56, z = -52, r = 3.5 },
		{ kind = "pillar", x = -164, z = 52, r = 3.5 },
		{ kind = "pillar", x = -146, z = 52, r = 3.5 },
		{ kind = "pillar", x = -128, z = 52, r = 3.5 },
		{ kind = "pillar", x = -92, z = 52, r = 3.5 },
		{ kind = "pillar", x = -74, z = 52, r = 3.5 },
		{ kind = "pillar", x = -56, z = 52, r = 3.5 },
		{ kind = "niches", room = 3, spacing = 8, tiers = 3, w = 5, h = 5 },
		{ kind = "niches", room = 6, spacing = 6, tiers = 4, w = 4, h = 4 },
		-- the Soul Well: the apse behind the north wall, the shaft over the well
		{ kind = "niche", x = 40, z = -226, r = 13, h = 22, plan = "octagon" },
		{ kind = "pit", x = 40, z = -228, r = 6, depth = 2, blend = 4 },
		{ kind = "chimney", x = 40, z = -228, r = 9, h = 44 },
		-- the necromancer's summoning circle, the seal of Morvane before the gate
		{
			kind = "ring",
			x = 150,
			z = 0,
			bands = { band(11, 15, "Pavement") },
			spokes = { n = 5, width = 4, material = "Pavement", from = 0, to = 11 },
		},
		{ kind = "ring", x = 262, z = 0, bands = { band(6, 10, "Slate"), band(13, 16, "Pavement") } },
	},
}

-- The Tomb of Morvane (boss of Duskwood): a queen's tomb: black floor with a mosaic, sarcophagi under an unreachable
-- gallery, the apse with the broken sarcophagus and the statue of the young queen; the arena contract holds.
byMap.dungeon_duskwood = {
	theme = "Tomb",
	wall = { amp = 4, scale = 30 },
	ceiling = { amp = 1.5, scale = 30 },
	materials = { wall = "Slate", floor = "Basalt", accent = "Basalt", bed = "Mud" },
	extraRooms = {
		extra({ x = 0, z = -10, r = 106, h = 56, role = "arena" }),
		extra({ x = 0, z = 72, r = 20, h = 26, role = "entrance", flat = true }),
		extra({ x = 0, z = -122, r = 26, h = 36, role = "apse", decor = "crypt" }),
	},
	features = {
		{
			kind = "ring",
			x = 0,
			z = -10,
			bands = { band(30, 34, "Pavement"), band(60, 64, "Pavement") },
			spokes = { n = 8, width = 4, material = "Slate", from = 6, to = 74 },
		},
		{ kind = "dais", x = 0, z = -128, r = 14, h = 4, dir = 90 },
		-- the gallery round the arena (+14, no stairs), open to the apse and the entry sector
		{
			kind = "terrace",
			x = 0,
			z = -10,
			r = 112,
			inner = 90,
			dy = 14,
			blend = 1.5,
			gaps = { { 50, 130 }, { 245, 295 } },
			unreachable = true,
		},
	},
	arena = { x = 0, z = -10, r = 74 },
}

return table.freeze({
	byMap = byMap,
	ROLES = ROLES,
})
