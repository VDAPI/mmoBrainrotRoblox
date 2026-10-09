--!strict
-- Frost Peaks (70–100): monster areas, roads, water and cave entrances (S19), rebuilt in S47 around a shaped terrain
-- (Logic/RegionTerrain, shape in Data/Terrain/frostpeak): the portals open in the U-shaped Ice Wolf Valley in the
-- west (snowy spruces, the frozen Ice Brook under two wooden bridges, the abandoned trappers' camp); the road climbs
-- the Step into the Giants' Pass between the North and South Ridge, through the Giants' Gate (two seated colossi on
-- the spurs) past the Hall of Thrones; north of the pass the Yeti Slopes (three benches, the Ice Grotto on the top
-- one) and the windswept Mammoth Tundra (a glacier tongue swallowed the gate of the Frozen Hold); south, over the
-- saddle, the Frozen Lake (a walkable sheet of ice with an ice hole, the frozen boat and the frozen falls) and the
-- Harpy Rocks round the Harpy Tarn in the south-west; east the terraces of the Dragon Temple climb to the great
-- glacier whose cleft holds the Glacier Heart, the Ice Watch fortress sits on its knoll in the south-east and the
-- Wyrm Spire, the highest horn, rises in the north-east. `sites` are the places of the buildings and landmarks
-- (Logic/FrostpeakGen builds them); `lakes` are only the two ice holes (open water in the frozen lakes).

local Types = require("./Types")

-- Building and landmark sites: x, z (map-relative), rot (yaw in degrees; the front of a building is local -Z,
-- facing (-sin rot, -cos rot): 0 north, 90 west, 180 south, 270 east). Names are unique across all maps (/tparea).
type Site = Types.Site

local SITES: { [string]: Site } = {
	-- Ice Wolf Valley
	entryCairn = { x = -646, z = -26, rot = 90 }, -- the stone cairn with horns and ribbons by the road
	trapperCamp = { x = -548, z = -168, rot = 200 }, -- the abandoned trappers' camp
	howlRock = { x = -690, z = 286, rot = 30 }, -- the Howling Rock in a ring of trampled snow
	leopardLedge = { x = -586, z = -296, rot = 270 }, -- a boulder ledge over the brook with the leopards' leftovers
	-- Yeti Slopes
	yetiDen = { x = -150, z = -690, rot = 180 }, -- the yeti's den under a rock overhang on the top bench
	avalanche = { x = -86, z = -560, rot = 160 }, -- the avalanche cone at the mouth of the gully
	yetiBoulders = { x = -370, z = -520, rot = 30 }, -- heaps of throwing boulders on the middle bench
	grottoMouth = { x = -300, z = -745, rot = 180 }, -- the Ice Grotto's mouth under icicle fangs
	-- Harpy Rocks
	tarn = { x = -560, z = 612, rot = 0 }, -- the frozen Harpy Tarn with its ice hole (fishing)
	harpyQueen = { x = -420, z = 650, rot = 270 }, -- the Queen's Spire with the great nest
	climbersCamp = { x = -470, z = 604, rot = 250 }, -- the fallen climbers' camp at its foot
	-- Giants' Pass
	giantsGate = { x = 94, z = -14, rot = 90 }, -- two seated colossi on the spurs by the road
	thrones = { x = 196, z = 104, rot = 0 }, -- the Hall of Thrones round the giants' fire
	boulderField = { x = 10, z = 130, rot = 0 }, -- a field of boulders and craters of the giants' throws
	-- Frozen Lake
	frozenBoat = { x = 196, z = 566, rot = 30 }, -- a boat frozen into the ice by the ice hole
	frozenFalls = { x = 22, z = 352, rot = 180 }, -- the Frozen Falls on the South Ridge's wall
	crystals = { x = 300, z = 640, rot = 0 }, -- the garden of crystals growing out of the ice
	iceHoard = { x = 96, z = 660, rot = 0 }, -- things locked in the ice (chests, a shield, a sword)
	-- Mammoth Tundra
	mammothGraveyard = { x = 236, z = -500, rot = 90 }, -- a field of giant skeletons, crossed tusks over the road
	huntingCamp = { x = 100, z = -640, rot = 160 }, -- the giants' hunting camp
	holdGate = { x = 300, z = -745, rot = 180 }, -- the gate of the Frozen Hold swallowed by the glacier tongue
	-- Ruins of the Dragon Temple
	dragonStairs = { x = 560, z = 0, rot = 90 }, -- the Dragon Stairs climbing the terraces east
	sanctuary = { x = 610, z = -104, rot = 180 }, -- the roofless sanctuary with the dragon colossus
	offeringAltars = { x = 618, z = 104, rot = 0 }, -- altars with gold frozen into blocks of ice
	glacierMouth = { x = 745, z = 0, rot = 90 }, -- the cleft in the glacier's front: the Glacier Heart
	-- Ice Watch
	icewatchGate = { x = 562, z = 570, rot = 90 }, -- the gate barred with icicles
	keep = { x = 640, z = 570, rot = 90 }, -- the iced-over keep
	-- Wyrm Spire
	wyrmBones = { x = 560, z = -522, rot = 90 }, -- the wyrm's skeleton, ribs arching over the Bone Trail
	wyrmBurrows = { x = 596, z = -700, rot = 30 }, -- burrows in the ice scarps
	wyrmObelisk = { x = 650, z = -430, rot = 200 }, -- the dragonspawn's obelisk to the wyrms
	summit = { x = 690, z = -650, rot = 0 }, -- the horn's summit (snow plume)
}

local function at(name: string, r: number): Types.Circle
	local s = SITES[name]
	return { x = s.x, z = s.z, r = r }
end

local data: Types.MapAreas = {
	map = "frostpeak",
	roads = {
		-- the main road: portals -> valley -> the Step -> the pass through the Giants' Gate -> temple -> Glacier Heart
		{
			points = { -790, 0, -480, 20, -200, 0, 0, 0, 260, -40, 500, 0, 720, 0 },
			width = 14,
			material = "Ground",
		},
		{ points = { -790, 160, -480, 20 }, width = 10, material = "Ground" }, -- from the city portal
		{ points = { -200, 0, -260, -460, -300, -720 }, width = 10, material = "Salt" }, -- up the Yeti Slopes to the Grotto
		{ points = { 0, 0, 120, 440 }, width = 10, material = "Salt" }, -- over the South Ridge's saddle to the lake
		{ points = { 260, -40, 300, -720 }, width = 8, material = "Salt" }, -- across the tundra to the Frozen Hold
		-- S47: the trail to the Harpy Tarn (east bank of the Ice Brook), the patrol road along the lake's north shore
		-- to the Ice Watch's gate and round its walls, the Bone Trail from the tundra onto the Wyrm Spire's plateau
		{ points = { -480, 20, -540, 180, -560, 330, -550, 470, -530, 548 }, width = 8, material = "Salt" },
		{ points = { 120, 440, 260, 436, 400, 462, 500, 520, 562, 570 }, width = 10, material = "Cobblestone" },
		{
			points = { 548, 476, 732, 476, 732, 664, 548, 664, 548, 476 },
			width = 8,
			material = "Cobblestone",
		},
		{ points = { 290, -560, 420, -540, 540, -522, 624, -500 }, width = 8, material = "Salt" },
	},
	-- Only the ice holes: open water in the frozen lakes (Data/Terrain/frostpeak frozenLakes).
	lakes = {
		{ x = 166, z = 584, r = 20 }, -- the Frozen Lake's ice hole by the frozen boat
		{ x = -560, z = 622, r = 18 }, -- the Harpy Tarn's ice hole
	},
	streams = {
		{
			-- the Ice Brook: from the small glacier in the north-west corner south under both portal roads into the
			-- Harpy Tarn; frozen over (a flat top of ice)
			id = "iceBrook",
			points = {
				-636,
				-664,
				-626,
				-560,
				-614,
				-420,
				-616,
				-280,
				-610,
				-140,
				-610,
				10,
				-614,
				80,
				-620,
				200,
				-612,
				330,
				-600,
				450,
				-586,
				560,
			},
			widths = { 6, 7, 8, 8, 9, 9, 9, 10, 10, 10, 10 },
			bank = 6,
			depth = 1.6,
			into = "lake",
			frozen = true,
		},
	},
	avoid = {
		{ x = -770, z = 0, r = 60 }, -- Ashen portal
		{ x = -770, z = 160, r = 60 }, -- city portal
		{ x = -690, z = -36, r = 24 }, -- the scout
		-- respawn points (Data/Terrain/frostpeak respawns)
		{ x = -700, z = 56, r = 40 },
		{ x = -236, z = -340, r = 35 },
		{ x = -130, z = 40, r = 35 },
		{ x = 108, z = 420, r = 35 },
		{ x = 430, z = 44, r = 35 },
		{ x = 690, z = 44, r = 35 },
		{ x = 330, z = -430, r = 35 },
		-- buildings and landmarks (the Hall of Thrones and the hunting camp by their single buildings)
		at("entryCairn", 10),
		at("trapperCamp", 30),
		at("howlRock", 16),
		at("leopardLedge", 14),
		at("yetiDen", 30),
		at("avalanche", 30),
		at("yetiBoulders", 16),
		at("harpyQueen", 34),
		at("climbersCamp", 22),
		at("giantsGate", 36),
		at("thrones", 30),
		at("boulderField", 16),
		at("frozenBoat", 16),
		at("frozenFalls", 30),
		at("crystals", 30),
		at("iceHoard", 20),
		at("mammothGraveyard", 36),
		at("huntingCamp", 30),
		at("dragonStairs", 24),
		at("sanctuary", 40),
		at("offeringAltars", 24),
		at("glacierMouth", 40),
		at("icewatchGate", 24),
		at("keep", 80),
		at("wyrmBones", 34),
		at("wyrmBurrows", 26),
		at("wyrmObelisk", 14),
		at("summit", 110),
	},
	caves = {
		{ cave = "frostpeak_grotto", x = -300, z = -745, rot = 180 },
		{ cave = "frostpeak_hold", x = 300, z = -745, rot = 180 },
		{ cave = "frostpeak_cave", x = 745, z = 0, rot = 90 },
	},
	sites = SITES,
	areas = {
		{
			id = "frostpeak_valley",
			nameKey = "area.frostpeak_valley",
			lv = { 70, 75 },
			kinds = { "iceWolf", "snowLeopard" },
			rect = { -760, -330, -420, 420 },
			groups = 8,
			arrive = { x = -682, z = 7 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.trapperCamp.x, z = SITES.trapperCamp.z },
			decor = "snowforest",
		},
		{
			id = "frostpeak_slopes",
			nameKey = "area.frostpeak_slopes",
			lv = { 74, 80 },
			kinds = { "yeti", "snowLeopard" },
			rect = { -480, -780, -20, -340 },
			groups = 7,
			profile = "exp", -- S33: yeti families on the slopes
			arrive = { x = -249, z = -374 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.yetiDen.x, z = SITES.yetiDen.z },
			decor = "snowfield",
		},
		{
			id = "frostpeak_harpyrocks",
			nameKey = "area.frostpeak_harpyrocks",
			lv = { 76, 83 },
			kinds = { "peakHarpy", "yeti" },
			rect = { -760, 440, -200, 780 },
			groups = 6,
			profile = "loot", -- S33: nests full of fallen climbers' gear
			arrive = { x = -551, z = 456 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.harpyQueen.x, z = SITES.harpyQueen.z },
			decor = "harpyrocks",
		},
		{
			id = "frostpeak_pass",
			nameKey = "area.frostpeak_pass",
			lv = { 78, 86 },
			kinds = { "frostGiant", "peakHarpy" },
			rect = { -200, -240, 320, 240 },
			groups = 7,
			arrive = { x = -184, z = 0 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.giantsGate.x, z = SITES.giantsGate.z },
			decor = "giants",
		},
		{
			id = "frostpeak_lake",
			nameKey = "area.frostpeak_lake",
			lv = { 82, 90 },
			kinds = { "iceElemental", "iceMammoth" },
			rect = { -60, 400, 420, 780 },
			groups = 6,
			profile = "loot", -- S33: things frozen in the ice
			arrive = { x = 405, z = 465 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.frozenBoat.x, z = SITES.frozenBoat.z },
			decor = "icelake",
		},
		{
			id = "frostpeak_tundra",
			nameKey = "area.frostpeak_tundra",
			lv = { 82, 89 },
			kinds = { "iceMammoth", "frostGiant" },
			rect = { 0, -780, 480, -320 },
			groups = 6,
			profile = "exp", -- S33: mammoth herds
			arrive = { x = 277, z = -336 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.mammothGraveyard.x, z = SITES.mammothGraveyard.z },
			decor = "tundra",
		},
		{
			id = "frostpeak_temple",
			nameKey = "area.frostpeak_temple",
			lv = { 85, 95 },
			kinds = { "dragonspawn", "frozenKnight" },
			rect = { 400, -300, 780, 320 },
			groups = 7,
			profile = "gold", -- S33: the temple's offerings
			arrive = { x = 417, z = -14 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.dragonStairs.x, z = SITES.dragonStairs.z },
			decor = "dragontemple",
		},
		{
			id = "frostpeak_icewatch",
			nameKey = "area.frostpeak_icewatch",
			lv = { 88, 95 },
			kinds = { "frozenKnight", "iceElemental" },
			rect = { 440, 340, 780, 780 },
			groups = 5,
			profile = "exp", -- S33: the watch's patrols
			arrive = { x = 454, z = 494 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.icewatchGate.x, z = SITES.icewatchGate.z },
			decor = "icefort",
		},
		{
			id = "frostpeak_wyrmspire",
			nameKey = "area.frostpeak_wyrmspire",
			lv = { 94, 100 },
			kinds = { "frostWyrm", "dragonspawn" },
			rect = { 500, -780, 780, -320 },
			groups = 5,
			arrive = { x = 516, z = -526 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.wyrmBones.x, z = SITES.wyrmBones.z },
			decor = "wyrmpeak",
		},
	},
}

return data
