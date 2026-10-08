--!strict
-- Shape of the Ashen Wastes terrain (S46), read by Logic/RegionTerrain (types: Data/Terrain/Types). Roads, the two
-- hot pools and the building sites come from Data/Areas/ashen. Character: a grey ash plain with rust and basalt,
-- gently rolling; lava, cracks, dunes, mesas and spires give each hunting ground its own ground:
--
--   * Salamander Flats: the Glowing Pit (a bowl with a lava pool) with glowing cracks running out of it, basalt
--     humps, the Hot Spring in a shallow bowl,
--   * Dead Oasis: a dry lake (salt crust in polygons, a bleached old waterline) round the last pond,
--   * Ash Orc Warcamp: a basalt plateau 16 studs over the plain, the main ramp from the junction along its south
--     face, a back ramp from the west, the sunken Blood Ring; the Abandoned Mine opens in a ridge to the west,
--   * Golem Fields: the crater (a low mesa with a lava lake), the Fire Vein falling from its lip into two cooling
--     lakes (the road to the ruins crosses it on a stone bridge), a third cooling lake, lava tongues, the Sleeping
--     Colossus (a hill shaped like a lying golem),
--   * Burnt Ruins: the town's knoll, the square flattened,
--   * Scorpion Dunes: a sand plateau (scarp over the necropolis, the sand road climbs it in a cut) with dunes driven
--     by a west wind,
--   * Wyvern Crags: a forest of spires, the nest mesa with a ramp, the tall mesa with the Wyvern Lair,
--   * Ash Road: a broad flat valley with the basilisk's pit,
--   * Desert Tombs: the pyramid's terrace, two sunken courtyards, the Forge Mountain with the gate of Deepforge.

local Areas = require("../Areas/ashen")
local Types = require("./Types")

local sites = assert(Areas.sites, "ashen sites")

local function site(name: string, r: number, blend: number, y: number?): Types.Flat
	local s = sites[name]
	return { x = s.x, z = s.z, r = r, blend = blend, y = y }
end

local CAMP_Y = 16 -- top of the warcamp plateau
local DUNES_Y = 10 -- the sand plateau under the dunes

local respawns: { Types.Respawn } = {
	{ x = -700, z = 52, lookX = 0, lookZ = 0 },
	{ x = -226, z = -300, lookX = -255, lookZ = -560 },
	{ x = -110, z = 30, lookX = 130, lookZ = 100 },
	{ x = 296, z = 250, lookX = 560, lookZ = 560 },
	{ x = 470, z = -212, lookX = 620, lookZ = -440 },
	{ x = 690, z = 44, lookX = 745, lookZ = 0 },
}

local flats: { Types.Flat } = {
	{ x = -770, z = 0, r = 18, blend = 24 }, -- Duskwood portal
	{ x = -770, z = 160, r = 18, blend = 24 }, -- city portal
	{ x = 740, z = -740, r = 18, blend = 24 }, -- Frost Peaks portal
	{ x = 690, z = -690, r = 14, blend = 16 }, -- landing from the Frost Peaks
	{ x = -560, z = -728, r = 18, blend = 14 }, -- Abandoned Mine (in front of the ridge)
	{ x = 420, z = -728, r = 18, blend = 14 }, -- Wyvern Lair (in front of the mesa)
	{ x = 738, z = 0, r = 18, blend = 12 }, -- Deepforge (an alcove in the Forge Mountain)
	{ x = -690, z = -36, r = 9, blend = 12 }, -- the scout
	site("ribcage", 16, 18),
	site("hyenaDen", 12, 14),
	site("fissures", 10, 12),
	site("strandedBoat", 12, 10),
	site("caravanGrave", 22, 14),
	site("carrionHeap", 14, 14),
	site("basaltColumns", 16, 14),
	site("ruinsGate", 10, 12),
	site("ruinsSquare", 30, 20),
	site("chimneyRow", 18, 14),
	site("burntTemple", 24, 16),
	site("belltower", 10, 10),
	site("sarcophagi", 12, 12),
	site("stoneCaravan", 14, 12),
	site("robbedWagons", 12, 12),
	site("pyramid", 44, 22),
}
for _, r in respawns do
	table.insert(flats, { x = r.x, z = r.z, r = 10, blend = 12 })
end

local mesas: { Types.Mesa } = {
	-- the crater: a low basalt mesa holding a lava lake
	{
		x = 130,
		z = 100,
		rx = 56,
		rz = 50,
		rot = 0,
		top = 14,
		cliff = 9,
		ragged = 3,
		skirt = 14,
		skirtH = 3,
		cap = "Basalt",
	},
	-- the nest mesa (ramp from the road)
	{
		x = 724,
		z = -500,
		rx = 30,
		rz = 34,
		rot = 10,
		top = 16,
		cliff = 8,
		ragged = 4,
		skirt = 10,
		skirtH = 3,
		cap = "Ground",
	},
	-- the tall mesa with the Wyvern Lair's mouth in its south wall
	{
		poly = { 330, -756, 400, -760, 470, -758, 520, -770, 540, -900, 320, -900 },
		top = 32,
		cliff = 8,
		ragged = 3,
		skirt = 10,
		skirtH = 3,
	},
	-- a tall mesa by the east edge of the crags
	{ x = 772, z = -390, rx = 38, rz = 58, rot = 0, top = 30, cliff = 8, ragged = 4, skirt = 10, skirtH = 3 },
	-- the ridge with the Abandoned Mine's adit
	{
		poly = { -640, -756, -560, -762, -480, -756, -470, -900, -650, -900 },
		top = 26,
		cliff = 7,
		ragged = 3,
		skirt = 10,
		skirtH = 3,
	},
	-- the Forge Mountain: its west wall holds the gate of Deepforge
	{
		poly = { 762, -150, 760, -40, 764, 40, 760, 150, 900, 160, 900, -160 },
		top = 36,
		cliff = 8,
		ragged = 3,
		skirt = 8,
		skirtH = 2,
		cap = "Basalt",
	},
}

local spires: { Types.Spire } = {
	{ x = 660, z = -350, r = 13, h = 40, lean = 200, asym = 0.3 },
	{ x = 700, z = -440, r = 12, h = 46, lean = 90, asym = 0.25 },
	{ x = 520, z = -420, r = 14, h = 38, lean = 300, asym = 0.3 },
	{ x = 470, z = -350, r = 12, h = 32, lean = 20, asym = 0.2 },
	{ x = 390, z = -430, r = 15, h = 44, lean = 160, asym = 0.3 },
	{ x = 340, z = -520, r = 13, h = 36, lean = 250, asym = 0.25 },
	{ x = 466, z = -500, r = 11, h = 30, lean = 60, asym = 0.2 },
	{ x = 560, z = -640, r = 14, h = 48, lean = 120, asym = 0.3 },
	{ x = 630, z = -704, r = 12, h = 40, lean = 330, asym = 0.25 },
	{ x = 350, z = -640, r = 12, h = 34, lean = 210, asym = 0.2 },
	{ x = 762, z = -626, r = 10, h = 36, lean = 270, asym = 0.25 },
	{ x = 486, z = -686, r = 11, h = 30, lean = 40, asym = 0.2 },
	{ x = 740, z = -322, r = 12, h = 34, lean = 180, asym = 0.25 },
	-- the low spire of the stone wyvern by the road
	{ x = 574, z = -362, r = 8, h = 9, top = 0.4 },
}

local shape: Types.Shape = {
	map = "ashen",
	seed = 46,
	writer = { bottom = -24, top = 72, margin = 64 },
	lakeLevel = -2.5,
	lakeDepth = 3,
	lakeShore = 10,
	swell = { amp = 3, scale = 300 },
	detail = { amp = 2.5, scale = 70 },
	fine = { amp = 0.8, scale = 16 },
	zones = {
		{ rect = { -800, -340, -420, 440 }, blend = 60, amp = 3 }, -- the ash plain
		{ rect = { -260, -40, 330, 420 }, blend = 50, amp = 3.2 }, -- lava tongues
		{ rect = { 0, -300, 500, -80 }, blend = 50, amp = 1 }, -- the flat valley of the Ash Road
		{ rect = { 340, 30, 760, 280 }, blend = 40, amp = 1 }, -- the necropolis terrace
		{ rect = { 300, -800, 800, -300 }, blend = 60, amp = 3.5 }, -- the crags' rough floor
	},
	hills = {
		-- the Sleeping Colossus: body, head (north end), fist
		{ x = -150, z = 150, rx = 62, rz = 24, rot = 80, h = 10, flat = 0.25 },
		{ x = -143, z = 92, rx = 15, rz = 15, rot = 0, h = 8, flat = 0.2 },
		{ x = -112, z = 190, rx = 12, rz = 11, rot = 0, h = 5, flat = 0 },
		-- lava tongues
		{ x = 40, z = 150, rx = 40, rz = 14, rot = 30, h = 2.5, flat = 0 },
		{ x = 200, z = 250, rx = 50, rz = 16, rot = -20, h = 2, flat = 0 },
		{ x = -20, z = 220, rx = 36, rz = 12, rot = 60, h = 2, flat = 0 },
		-- the burnt town's knoll
		{ x = 80, z = 640, rx = 170, rz = 110, rot = 0, h = 7, flat = 0.3 },
		-- basalt humps on the ash plain
		{ x = -480, z = -240, rx = 30, rz = 22, rot = 20, h = 3, flat = 0 },
		{ x = -700, z = -200, rx = 26, rz = 20, rot = 0, h = 3, flat = 0 },
		{ x = -460, z = 200, rx = 34, rz = 24, rot = 40, h = 3, flat = 0 },
		-- the oasis's rim
		{ x = -540, z = 615, rx = 260, rz = 190, rot = 0, h = 3, flat = 0.75 },
	},
	ridges = {},
	plateaus = {
		-- the warcamp's basalt plateau; the main ramp climbs its south face, the back ramp the west face
		{
			poly = {
				-400,
				-470,
				-300,
				-470,
				-180,
				-450,
				-112,
				-470,
				-106,
				-580,
				-120,
				-682,
				-260,
				-692,
				-400,
				-682,
				-414,
				-580,
			},
			cliff = 7,
			y = CAMP_Y,
			noise = 0.6,
		},
		-- the sand plateau of the dunes: a scarp over the necropolis (north), gentle towards the ruins (west)
		{
			poly = { 300, 300, 420, 292, 560, 286, 700, 290, 900, 296, 900, 900, 300, 900 },
			cliff = { 50, 7, 7, 7, 7, 60, 60 },
			y = DUNES_Y,
			noise = 0.8,
		},
	},
	gorges = {},
	basins = {
		{ x = -590, z = -190, rx = 48, rz = 44, rot = 0, depth = 5, flat = 0.35 }, -- the Glowing Pit
		{ x = -680, z = 304, rx = 52, rz = 46, rot = 0, depth = 3, flat = 0.4 }, -- the Hot Spring's bowl
		{ x = 60, z = 262, rx = 50, rz = 36, rot = 10, depth = 2.5, flat = 0.4 }, -- cooling lakes
		{ x = -182, z = 300, rx = 44, rz = 34, rot = -10, depth = 2.5, flat = 0.4 },
		{ x = 262, z = 184, rx = 40, rz = 30, rot = 20, depth = 2.5, flat = 0.4 },
		{ x = -250, z = -570, rx = 22, rz = 20, rot = 0, depth = 2.5, flat = 0.5 }, -- the Blood Ring
		{ x = -10, z = 60, rx = 18, rz = 15, rot = 0, depth = 1.5, flat = 0.3 }, -- the imps' fumaroles
		{ x = 120, z = -252, rx = 24, rz = 20, rot = 0, depth = 3, flat = 0.5 }, -- the basilisk's pit
		{ x = 470, z = 196, rx = 32, rz = 30, rot = 0, depth = 6, flat = 0.6 }, -- sunken courtyards
		{ x = 724, z = 214, rx = 30, rz = 28, rot = 0, depth = 6, flat = 0.6 },
	},
	marshes = {},
	flats = flats,
	ramps = {
		-- warcamp: main ramp from the junction along the south face to the gate, back ramp from the mine road
		{ w = 12, pts = { { -200, -424 }, { -240, -437, 6 }, { -282, -452, 13 }, { -300, -478, CAMP_Y } } },
		{ w = 10, pts = { { -470, -548 }, { -440, -576, 8 }, { -416, -604, CAMP_Y } } },
		-- up the nest mesa from the crags' road
		{ w = 10, pts = { { 662, -532 }, { 686, -522, 7 }, { 708, -512, 15.5 } } },
		-- down into the sunken courtyards
		{ w = 8, pts = { { 470, 150 }, { 470, 184 } } },
		{ w = 8, pts = { { 724, 170 }, { 724, 202 } } },
	},
	crossings = {},
	themes = {
		{ rect = { -470, -800, -20, -340 }, theme = "warcamp" },
		{ rect = { -800, 440, -290, 800 }, theme = "saltflat" },
		{ rect = { -290, -40, 330, 430 }, theme = "lavafield" },
		{ rect = { -290, 430, 300, 800 }, theme = "burnt" },
		{ rect = { 300, 290, 800, 800 }, theme = "dunes" },
		{ rect = { 300, -800, 800, -300 }, theme = "crags" },
		{ rect = { -20, -300, 500, -70 }, theme = "royalroad" },
		{ rect = { 330, -70, 800, 290 }, theme = "necropolis" },
		{ rect = { -800, -800, -470, 440 }, theme = "ash" },
	},
	defaultTheme = "ash",
	themeJitter = 36,
	patches = {
		{ x = sites.ruinsSquare.x, z = sites.ruinsSquare.z, r = 24, material = "Cobblestone" },
		{ x = sites.pyramid.x, z = sites.pyramid.z, r = 40, material = "Pavement" },
		{ x = sites.courtyardWest.x, z = sites.courtyardWest.z, r = 18, material = "Pavement" },
		{ x = sites.courtyardEast.x, z = sites.courtyardEast.z, r = 17, material = "Pavement" },
		-- sand blown into the burnt town from the dunes
		{ x = 236, z = 700, r = 46, material = "Sand" },
		{ x = 250, z = 560, r = 30, material = "Sand" },
		{ x = 180, z = 760, r = 34, material = "Sand" },
		-- the hot spring's sulphur rim
		{ x = -680, z = 304, r = 30, material = "Sand" },
		-- the hyenas' trampled ring
		{ x = sites.hyenaDen.x, z = sites.hyenaDen.z, r = 10, material = "Ground" },
		{ x = sites.caravanGrave.x, z = sites.caravanGrave.z, r = 18, material = "Ground" },
	},
	materialRules = {
		{ minSlope = 40, rock = true, mat = "@strata" }, -- mesa and spire walls
		{ minSlope = 40, plateau = true, theme = "warcamp", mat = "Basalt" },
		{ minSlope = 40, plateau = true, mat = "Sandstone" },
		{ minSlope = 38, mat = "Rock" },
		{ minSlope = 22, rock = true, mat = "Rock" }, -- scree under the walls
		-- charred band round lava and glowing cracks: basalt fading into ash
		{ maxLava = 7, mat = "Basalt" },
		{ maxLava = 16, maxNoise = 0.62, mat = "Basalt" },
		{ maxLava = 26, mat = "Asphalt" },
		{ drylake = true, minNoise = 0.55, mat = "Sand" },
		{ drylake = true, mat = "Ground" },
		{ dune = true, mat = "@dune" },
		{ theme = "ash", minNoise = 0.68, mat = "Ground" },
		{ theme = "ash", maxNoise = 0.18, mat = "Basalt" },
		{ theme = "ash", mat = "Asphalt" },
		{ theme = "saltflat", minNoise = 0.6, mat = "Sand" },
		{ theme = "saltflat", maxNoise = 0.25, mat = "Asphalt" },
		{ theme = "saltflat", mat = "Ground" },
		{ theme = "warcamp", plateau = true, minNoise = 0.6, mat = "Basalt" },
		{ theme = "warcamp", plateau = true, mat = "Ground" },
		{ theme = "warcamp", minNoise = 0.55, mat = "Ground" },
		{ theme = "warcamp", mat = "Asphalt" },
		{ theme = "lavafield", minNoise = 0.6, mat = "Ground" },
		{ theme = "lavafield", maxNoise = 0.42, mat = "Basalt" },
		{ theme = "lavafield", mat = "Asphalt" },
		{ theme = "burnt", minNoise = 0.66, mat = "Sand" },
		{ theme = "burnt", maxNoise = 0.3, mat = "Ground" },
		{ theme = "burnt", mat = "Asphalt" },
		{ theme = "dunes", mat = "Sand" },
		{ theme = "crags", minNoise = 0.62, mat = "Rock" },
		{ theme = "crags", maxNoise = 0.24, mat = "Sandstone" },
		{ theme = "crags", mat = "Ground" },
		{ theme = "royalroad", minNoise = 0.66, mat = "Asphalt" },
		{ theme = "royalroad", maxNoise = 0.24, mat = "Rock" },
		{ theme = "royalroad", mat = "Ground" },
		{ theme = "necropolis", minNoise = 0.6, mat = "Ground" },
		{ theme = "necropolis", mat = "Sand" },
		{ mat = "Asphalt" },
	},
	flora = {
		ash = {
			spacing = 30,
			dense = 0.34,
			sparse = 0.055,
			clump = 0.58,
			kinds = { charredStump = 50, burntTree = 35, blackDead = 15 },
			filler = 3,
			fillerKinds = { charredStump = 60, burntTree = 40 },
			under = { n = 6, kinds = { thorns = 3, deadBush = 2 } },
		},
		saltflat = {
			spacing = 40,
			dense = 0.2,
			sparse = 0.02,
			clump = 0.6,
			kinds = { deadPalm = 70, blackDead = 30 },
			filler = 1,
			fillerKinds = { deadPalm = 100 },
			under = { n = 4, kinds = { deadBush = 3 } },
		},
		warcamp = {
			spacing = 44,
			dense = 0.12,
			sparse = 0.02,
			clump = 0.62,
			kinds = { blackDead = 60, charredStump = 40 },
			filler = 1,
			under = { n = 4, kinds = { thorns = 2, deadBush = 2 } },
		},
		lavafield = {
			spacing = 44,
			dense = 0.1,
			sparse = 0.015,
			clump = 0.65,
			kinds = { charredStump = 60, burntTree = 40 },
			filler = 1,
			under = { n = 2, kinds = { deadBush = 1 } },
		},
		burnt = {
			spacing = 32,
			dense = 0.22,
			sparse = 0.03,
			clump = 0.58,
			kinds = { burntTree = 55, charredStump = 45 },
			filler = 2,
			under = { n = 4, kinds = { thorns = 2, deadBush = 2 } },
		},
		dunes = {
			spacing = 60,
			dense = 0.05,
			sparse = 0.005,
			clump = 0.7,
			kinds = { deadPalm = 60, blackDead = 40 },
			under = { n = 2, kinds = { deadBush = 1 } },
		},
		crags = {
			spacing = 42,
			dense = 0.12,
			sparse = 0.02,
			clump = 0.62,
			kinds = { blackDead = 60, charredStump = 40 },
			filler = 1,
			under = { n = 4, kinds = { thorns = 3, deadBush = 1 } },
		},
		royalroad = {
			spacing = 44,
			dense = 0.1,
			sparse = 0.015,
			clump = 0.62,
			kinds = { burntTree = 50, charredStump = 50 },
			under = { n = 3, kinds = { deadBush = 2, thorns = 1 } },
		},
		necropolis = {
			spacing = 50,
			dense = 0.12,
			sparse = 0.015,
			clump = 0.62,
			kinds = { deadPalm = 70, blackDead = 30 },
			under = { n = 2, kinds = { deadBush = 1 } },
		},
	},
	respawns = respawns,
	fallback = "Asphalt",
	capMaterial = "Basalt",
	strata = { period = 7, base = "Sandstone", bands = { { "Ground", 0, 0.14 }, { "Basalt", 0.5, 0.58 } } },
	dunes = {
		-- the wind blows from the west: crests run north-south, flat valleys between them for the groups and paths
		{
			rect = { 340, 330, 800, 800 },
			blend = 50,
			wind = 90,
			wave = 120,
			height = 12,
			lee = 0.2,
			valley = 0.36,
			wander = 26,
		},
	},
	mesas = mesas,
	spires = spires,
	lava = {
		pools = {
			{ id = "craterLake", x = 130, z = 100, rx = 30, rz = 26, rot = 0, level = 12.4, wall = 1.2, bank = 4 },
			{
				id = "coolNorth",
				x = 60,
				z = 262,
				rx = 38,
				rz = 26,
				rot = 10,
				level = -1.6,
				wall = 1.6,
				bank = 6,
				crust = true,
				islands = { { x = 70, z = 258, r = 6, h = 0.8 } },
			},
			{
				id = "coolWest",
				x = -182,
				z = 300,
				rx = 34,
				rz = 26,
				rot = -10,
				level = -1.8,
				wall = 1.6,
				bank = 6,
				crust = true,
			},
			{
				id = "coolEast",
				x = 262,
				z = 184,
				rx = 30,
				rz = 22,
				rot = 20,
				level = -1.4,
				wall = 1.6,
				bank = 6,
				crust = true,
			},
			{ id = "glowPool", x = -590, z = -190, rx = 16, rz = 14, rot = 0, level = -3.6, wall = 1, bank = 4 },
		},
		rivers = {
			{
				-- the Fire Vein: from the crater over its lip and down into the north cooling lake
				id = "fireVein",
				points = { 124, 108, 104, 128, 88, 144, 74, 160, 60, 186, 52, 214, 54, 240, 58, 252 },
				widths = { 8, 8, 8, 9, 9, 10, 10, 10 },
				level = 12.4,
				sink = 1.6,
				wall = 1.4,
				bank = 6,
				from = "pool:1",
				into = "pool:2",
			},
			{
				-- ... and on west under the bridge into the west cooling lake
				id = "fireVeinLow",
				points = { 24, 266, -10, 272, -60, 281, -110, 292, -150, 298 },
				widths = { 9, 10, 10, 10, 9 },
				level = -1.6,
				sink = 1.6,
				wall = 1.4,
				bank = 6,
				from = "pool:2",
				into = "pool:3",
			},
		},
		falls = {
			{ x = 94, z = 136, rot = 135, drop = 10, river = "fireVein" },
		},
	},
	cracks = {
		-- glowing cracks running out of the Glowing Pit
		{ points = { -572, -176, -540, -152, -505, -140, -470, -114 }, width = 6, depth = 2.5, glow = true },
		{ points = { -568, -198, -520, -214, -474, -236, -436, -236 }, width = 6, depth = 2.5, glow = true },
		{ points = { -594, -212, -604, -258, -592, -300 }, width = 6, depth = 2.5, glow = true },
		{ points = { -612, -184, -660, -172, -704, -150 }, width = 6, depth = 2.5, glow = true },
		{ points = { -608, -206, -652, -242, -700, -276 }, width = 6, depth = 2.5, glow = true },
		{ points = { -580, -172, -576, -130, -590, -96 }, width = 5, depth = 2, glow = true },
		-- ... and two running along the road from the portals, leading the eye east
		{ points = { -590, -96, -556, -82, -520, -70, -494, -52 }, width = 5, depth = 2, glow = true },
		{ points = { -590, -96, -640, -84, -690, -92, -730, -84 }, width = 5, depth = 2, glow = true },
		-- cold cracks in the plain, the golem fields and the old road's valley
		{ points = { -640, 120, -600, 160, -560, 150 }, width = 4, depth = 1, glow = false },
		{ points = { -700, 220, -660, 250, -640, 236 }, width = 4, depth = 1, glow = false },
		{ points = { 180, 20, 230, 40, 270, 30 }, width = 4, depth = 1, glow = false },
		{ points = { 60, -230, 120, -200, 170, -215 }, width = 4, depth = 1, glow = false },
		{ points = { 300, -250, 340, -232, 380, -246 }, width = 4, depth = 1, glow = false },
	},
	drylakes = {
		{ x = -540, z = 615, rx = 190, rz = 125, rot = 0, depth = 4, shore = 34, y = -1.2 },
	},
}

return table.freeze(shape)
