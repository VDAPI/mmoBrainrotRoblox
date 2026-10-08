--!strict
-- Ashen Wastes (45–70): monster areas, roads, water and cave entrances (S19), rebuilt in S46 around a shaped terrain
-- (Logic/RegionTerrain, shape in Data/Terrain/ashen): a grey ash plain cut by glowing cracks in the west (the portals
-- open under the Ribcage Gate), the ash orc fortress on its basalt plateau in the north-west, the Golem Fields round
-- a lava crater in the middle (the Fire Vein runs from it under a stone bridge into cooling lakes), the burnt town on
-- its knoll in the south, the sea of dunes on a sand plateau in the south-east, the forest of spires in the
-- north-east, the old royal road between them and the necropolis with its pyramid in the east, where the main road
-- ends at the gate of Deepforge. `sites` are the places of the buildings and landmarks (Logic/AshenGen builds them);
-- the layout draws the roads from here; Logic/AreaSpawns places the groups. Lava is not water: it lives in
-- Data/Terrain/ashen (`lava`), `lakes` holds only the two hot pools.

local Types = require("./Types")

-- Building and landmark sites: x, z (map-relative), rot (yaw in degrees; the front of a building is local -Z,
-- facing (-sin rot, -cos rot): 0 north, 90 west, 180 south, 270 east). Names are unique across all maps (/tparea).
type Site = Types.Site

local SITES: { [string]: Site } = {
	-- Salamander Flats
	ribcage = { x = -612, z = 0, rot = 90 }, -- ribs of a giant beast arching over the road from the portals
	hyenaDen = { x = -598, z = -58, rot = 180 }, -- a skull driven into the ash, the hyenas' den under it
	glowPit = { x = -590, z = -190, rot = 0 }, -- the Glowing Pit: a shallow bowl with a lava pool
	fissures = { x = -540, z = -128, rot = 30 }, -- basalt slabs where the salamanders bask by the cracks
	hotSpring = { x = -680, z = 300, rot = 0 }, -- steaming pool with a sulphur rim (fishing)
	-- Dead Oasis
	strandedBoat = { x = -652, z = 650, rot = 30 }, -- a boat stranded on the dry bed far from the water
	oasisJetty = { x = -560, z = 536, rot = 0 }, -- the old jetty running over the dry bed to the last pond
	caravanGrave = { x = -430, z = 640, rot = 200 }, -- torn tents, overturned wagons, pack animal skeletons
	caravanChest = { x = -500, z = 600, rot = 160 }, -- the chest in the middle of the bed the vultures circle
	-- Ash Orc Warcamp
	warcampGate = { x = -300, z = -480, rot = 205 }, -- gate of tusks and logs over the ramp
	bloodPit = { x = -250, z = -570, rot = 0 }, -- the Blood Ring: a sunken arena with stakes
	orcForge = { x = -166, z = -540, rot = 270 }, -- forge with an ember hearth, anvils, racks of axes
	warDrum = { x = -250, z = -640, rot = 180 }, -- the great war drum on its dais
	orcCages = { x = -350, z = -520, rot = 90 }, -- cages with the bones of captives
	chiefTent = { x = -340, z = -628, rot = 135 }, -- the warchief's tent
	carrionHeap = { x = -74, z = -560, rot = 270 }, -- carrion dump under the east cliff (vultures)
	-- Golem Fields
	crater = { x = 130, z = 100, rot = 0 }, -- the crater with its lava lake
	lavafall = { x = 92, z = 138, rot = 135 }, -- the Fire Vein falling from the crater's lip
	lavaBridge = { x = -60, z = 281, rot = 0 }, -- stone bridge over the Fire Vein on the road to the ruins
	colossus = { x = -150, z = 150, rot = 80 }, -- the Sleeping Colossus: a hill shaped like a lying golem
	basaltColumns = { x = 214, z = 330, rot = 0 }, -- field of basalt columns
	impChimneys = { x = -10, z = 60, rot = 0 }, -- fumaroles and charcoal nests of the imps
	-- Burnt Ruins
	ruinsGate = { x = -26, z = 470, rot = 0 }, -- the town gate by the road from the bridge
	ruinsSquare = { x = 0, z = 600, rot = 0 }, -- square with the dry fountain full of embers
	chimneyRow = { x = 96, z = 600, rot = 90 }, -- alley of lone chimneys
	burntTemple = { x = 196, z = 640, rot = 90 }, -- temple with a fallen dome
	belltower = { x = 214, z = 604, rot = 90 }, -- the bell tower that still smoulders
	scorpionNests = { x = 250, z = 716, rot = 0 }, -- burrows in the sand drifts on the east side
	-- Scorpion Dunes
	buriedKing = { x = 560, z = 560, rot = 40 }, -- head and arm of a king's statue rising from a dune
	sarcophagi = { x = 620, z = 520, rot = 20 }, -- sarcophagi laid bare by the wind
	-- Wyvern Crags
	wyvernStone = { x = 574, z = -360, rot = 250 }, -- a stone wyvern roaring on a low spire by the road
	nestMesa = { x = 724, z = -500, rot = 270 }, -- the low mesa with the great nest
	stoneArch = { x = 678, z = -590, rot = 339 }, -- natural rock arch over the road
	-- Ash Road
	kingsAvenue = { x = 220, z = -153, rot = 293 }, -- colossal kings along the old road
	stoneCaravan = { x = 352, z = -168, rot = 290 }, -- a wagon, oxen and people turned to stone
	robbedWagons = { x = 450, z = -196, rot = 250 }, -- robbed and burnt wagons, scattered coins
	basiliskDen = { x = 120, z = -252, rot = 0 }, -- the basilisk's rocky pit
	-- Desert Tombs
	pyramid = { x = 610, z = 178, rot = 0 }, -- stepped pyramid with a turquoise entrance
	courtyardWest = { x = 470, z = 196, rot = 0 }, -- sunken courtyard with sarcophagi
	courtyardEast = { x = 724, z = 214, rot = 0 }, -- sunken courtyard with altars
	rockTombs = { x = 520, z = 286, rot = 0 }, -- tombs carved in the scarp under the dunes
	forgeGate = { x = 752, z = 0, rot = 90 }, -- the dwarven gate of Deepforge in the Forge Mountain
	-- Cave mouths
	mineMouth = { x = -560, z = -745, rot = 180 }, -- the Abandoned Mine's adit in the ridge
	lairMouth = { x = 420, z = -745, rot = 180 }, -- the Wyvern Lair's scorched mouth in the mesa
}

local function at(name: string, r: number): Types.Circle
	local s = SITES[name]
	return { x = s.x, z = s.z, r = r }
end

local data: Types.MapAreas = {
	map = "ashen",
	roads = {
		-- the main road: portals -> Ribcage Gate -> warcamp junction -> golem fields -> tombs -> Deepforge
		{
			points = { -790, 0, -480, 0, -240, -60, 0, -60, 260, -20, 520, 0, 720, 0 },
			width = 14,
			material = "Pavement",
		},
		{ points = { -790, 160, -480, 0 }, width = 10, material = "Pavement" }, -- from the city portal
		{ points = { -240, -60, -200, -420 }, width = 10, material = "Pavement" }, -- to the warcamp
		{ points = { 260, -20, 420, 360 }, width = 10, material = "Sand" }, -- up to the dunes (a cut in the scarp)
		{ points = { 520, 0, 590, -310, 620, -440, 690, -620, 740, -740 }, width = 10, material = "Pavement" },
		-- to the mine at the foot of the plateau
		{ points = { -200, -420, -320, -396, -430, -420, -476, -560, -560, -720 }, width = 8, material = "Pavement" },
		{ points = { 620, -440, 420, -600, 420, -720 }, width = 8, material = "Pavement" }, -- to the lair
		-- S46: the old royal road (straight, broad), the road over the Fire Vein to the ruins, the caravan trail to the
		-- oasis, the procession road to the pyramid
		{ points = { 0, -60, 590, -310 }, width = 14, material = "Pavement" },
		{ points = { -40, -60, -56, 120, -60, 281, -40, 400, -26, 470, 0, 600 }, width = 10, material = "Cobblestone" },
		{ points = { -520, 0, -526, 200, -520, 380, -548, 480 }, width = 8, material = "Ground" },
		{ points = { 600, 0, 606, 132 }, width = 12, material = "Pavement" },
	},
	lakes = {
		{ x = -560, z = 612, r = 24 }, -- the last pond of the oasis
		{ x = -680, z = 304, r = 22 }, -- the Hot Spring
	},
	avoid = {
		{ x = -770, z = 0, r = 60 }, -- Duskwood portal
		{ x = -770, z = 160, r = 60 }, -- city portal
		{ x = 740, z = -740, r = 60 }, -- Frost Peaks portal
		{ x = 690, z = -690, r = 24 }, -- landing from the Frost Peaks
		{ x = -690, z = -36, r = 24 }, -- the scout
		-- respawn points (Data/Terrain/ashen respawns)
		{ x = -700, z = 52, r = 40 },
		{ x = -226, z = -300, r = 35 },
		{ x = -110, z = 30, r = 35 },
		{ x = 296, z = 250, r = 35 },
		{ x = 470, z = -212, r = 35 },
		{ x = 690, z = 44, r = 35 },
		-- buildings and landmarks (the warcamp's single buildings, not the whole camp: the orcs stand in the yard)
		at("ribcage", 30),
		at("hyenaDen", 22),
		at("glowPit", 34),
		at("fissures", 16),
		at("hotSpring", 40),
		at("strandedBoat", 22),
		at("oasisJetty", 30),
		at("caravanGrave", 34),
		at("caravanChest", 14),
		at("warcampGate", 30),
		at("bloodPit", 26),
		at("orcForge", 22),
		at("warDrum", 16),
		at("orcCages", 16),
		at("chiefTent", 18),
		at("carrionHeap", 22),
		at("crater", 80),
		at("lavafall", 26),
		at("colossus", 56),
		at("basaltColumns", 26),
		at("impChimneys", 20),
		at("ruinsGate", 22),
		at("ruinsSquare", 32),
		at("chimneyRow", 30),
		at("burntTemple", 34),
		at("belltower", 16),
		at("scorpionNests", 14),
		at("buriedKing", 36),
		at("sarcophagi", 18),
		at("wyvernStone", 24),
		at("nestMesa", 60),
		at("stoneArch", 20),
		at("kingsAvenue", 30),
		at("stoneCaravan", 20),
		at("robbedWagons", 20),
		at("basiliskDen", 30),
		at("pyramid", 56),
		at("courtyardWest", 40),
		at("courtyardEast", 40),
		at("rockTombs", 30),
		at("forgeGate", 40),
	},
	caves = {
		{ cave = "ashen_mine", x = -560, z = -745, rot = 180 },
		{ cave = "ashen_lair", x = 420, z = -745, rot = 180 },
		{ cave = "ashen_cave", x = 745, z = 0, rot = 90 },
	},
	sites = SITES,
	areas = {
		{
			id = "ashen_flats",
			nameKey = "area.ashen_flats",
			lv = { 45, 50 },
			kinds = { "salamander", "wasteHyena" },
			rect = { -760, -330, -420, 420 },
			groups = 8,
			profile = "exp", -- S33: salamanders and hyena packs
			arrive = { x = -680, z = 0 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.ribcage.x, z = SITES.ribcage.z },
			decor = "ash",
		},
		{
			id = "ashen_oasis",
			nameKey = "area.ashen_oasis",
			lv = { 46, 52 },
			kinds = { "wasteHyena", "ashVulture" },
			rect = { -760, 440, -300, 780 },
			groups = 6,
			profile = "loot", -- S33: lost caravans' gear in the sand
			arrive = { x = -541, z = 456 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.strandedBoat.x, z = SITES.strandedBoat.z },
			decor = "saltflat",
		},
		{
			id = "ashen_warcamp",
			nameKey = "area.ashen_warcamp",
			lv = { 48, 56 },
			kinds = { "ashOrc", "ashVulture" },
			rect = { -460, -780, -20, -340 },
			groups = 7,
			arrive = { x = -207, z = -356 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.bloodPit.x, z = SITES.bloodPit.z },
			decor = "warcamp",
		},
		{
			id = "ashen_golemfields",
			nameKey = "area.ashen_golemfields",
			lv = { 52, 60 },
			kinds = { "fireGolem", "fireImp" },
			rect = { -260, -40, 330, 390 },
			groups = 7,
			arrive = { x = -43, z = -24 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.colossus.x, z = SITES.colossus.z },
			decor = "lavafield",
		},
		{
			id = "ashen_burntruins",
			nameKey = "area.ashen_burntruins",
			lv = { 55, 61 },
			kinds = { "fireImp", "desertScorpion" },
			rect = { -280, 440, 280, 780 },
			groups = 6,
			profile = "exp", -- S33: swarms of imps
			arrive = { x = -22, z = 492 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.belltower.x, z = SITES.belltower.z },
			decor = "burnt",
		},
		{
			id = "ashen_dunes",
			nameKey = "area.ashen_dunes",
			lv = { 55, 63 },
			kinds = { "desertScorpion", "desertMummy" },
			rect = { 330, 300, 780, 780 },
			groups = 7,
			profile = "gold", -- S33: mummies buried with their gold
			arrive = { x = 401, z = 316 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.buriedKing.x, z = SITES.buriedKing.z },
			decor = "dunes",
		},
		{
			id = "ashen_crags",
			nameKey = "area.ashen_crags",
			lv = { 58, 66 },
			kinds = { "wyvern", "basilisk" },
			rect = { 300, -780, 780, -300 },
			groups = 6,
			profile = "exp", -- S33: wyvern flocks
			arrive = { x = 583, z = -307 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.wyvernStone.x, z = SITES.wyvernStone.z },
			decor = "crags",
		},
		{
			id = "ashen_ashroad",
			nameKey = "area.ashen_ashroad",
			lv = { 61, 67 },
			kinds = { "basilisk", "wyvern" },
			rect = { 0, -300, 500, -80 },
			groups = 4,
			profile = "gold", -- S33: robbed caravans along the road
			arrive = { x = 63, z = -87 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.kingsAvenue.x, z = SITES.kingsAvenue.z },
			decor = "royalroad",
		},
		{
			id = "ashen_tombs",
			nameKey = "area.ashen_tombs",
			lv = { 66, 70 },
			kinds = { "desertMummy", "basilisk" },
			rect = { 340, 40, 780, 280 },
			groups = 5,
			arrive = { x = 346, z = 185 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.pyramid.x, z = SITES.pyramid.z },
			decor = "necropolis",
		},
	},
}

return data
