--!strict
-- Duskwood (20–45): monster areas, roads, water and cave entrances (S19), rebuilt in S45 around a shaped terrain
-- (Logic/RegionTerrain, shape in Data/Terrain/duskwood): old rooty forest on rolling ground; the Black Stream
-- falls from the Blood Cliffs (east), runs west through Misty Crossroads under a stone bridge, south under the main
-- road past the Witch Marsh into the Troll Swamp; Bear Hollow is a deep gorge, the haunted manor stands on a rise,
-- the Heart of the Forest is a hollow around the Elder Tree. `sites` are the places of the buildings and landmarks
-- (Logic/DuskwoodGen builds them); the layout draws the roads from here; Logic/AreaSpawns places the groups.

local Types = require("./Types")

-- Building and landmark sites: x, z (map-relative), rot (yaw in degrees; the front of a building is local -Z,
-- facing (-sin rot, -cos rot): 0 north, 90 west, 180 south, 270 east). Names are unique across all maps (/tparea).
type Site = Types.Site

local SITES: { [string]: Site } = {
	-- Werewolf Thicket
	duskGate = { x = -646, z = 9, rot = 90 }, -- warning gate over the road between two giant gnarled oaks
	ravagedCamp = { x = -598, z = -76, rot = 160 }, -- hunters' camp torn apart at the forest's edge
	moonstone = { x = -606, z = -262, rot = 0 }, -- Moon Glade: clawed menhir in a trampled ring
	boneTree = { x = -540, z = 214, rot = 0 }, -- bones and antlers under a black dead tree
	-- Bear Hollow
	fallenGiant = { x = -514, z = 566, rot = 0 }, -- giant trunk lying across the gorge (a bridge)
	lostCamp = { x = -626, z = 664, rot = 30 }, -- lost hunters' camp on the gorge floor
	-- Haunted Ruins
	manor = { x = -130, z = -436, rot = 180 }, -- overgrown manor on its rise (courtyard in front)
	cemetery = { x = -6, z = -520, rot = 200 }, -- family cemetery behind a bent iron fence
	chapel = { x = 4, z = -586, rot = 180 }, -- chapel with a broken window
	familyCrypt = { x = 54, z = -560, rot = 270 }, -- open family crypt with a grate (coins inside)
	-- Heart of the Forest
	elderTree = { x = 150, z = 372, rot = 180 }, -- the Elder Tree in its hollow
	-- Cultist Village
	cultVillage = { x = 560, z = -560, rot = 220 }, -- centre of the palisade
	ritualCircle = { x = 596, z = -606, rot = 220 }, -- runestones and the altar with violet fire
	cultHall = { x = 600, z = -528, rot = 51 }, -- long hall of the cult
	serpentPond = { x = 436, z = -640, rot = 0 }, -- fenced pond of the serpents
	-- Misty Crossroads
	wayShrine = { x = 392, z = -78, rot = 230 }, -- wayside shrine with a mossy figure and a lantern
	gallows = { x = 300, z = -82, rot = 180 },
	-- Troll Swamp
	trollVillage = { x = 702, z = 612, rot = 300 }, -- domed huts of logs, moss and bones on an island
	sunkenTower = { x = 628, z = 580, rot = 20 }, -- half-sunk leaning watchtower
	swampJetty = { x = 594, z = 506, rot = 180 }, -- jetty with a boat and a lantern (fishing)
	stiltVillage = { x = 452, z = 586, rot = 90 }, -- abandoned village on stilts with walkways
	-- Witch Marsh
	witchHut = { x = -66, z = 122, rot = 160 }, -- crooked hut on stilts
	hangingTree = { x = 66, z = 72, rot = 0 }, -- hanging tree with charms and bone chimes
	-- Blood Cliffs
	cryptGate = { x = 768, z = 0, rot = 90 }, -- monumental gate carved in the rock over the Crypt
	blackFall = { x = 612, z = -142, rot = 270 }, -- black waterfall of the Black Stream
	batRoost = { x = 616, z = -40, rot = 270 }, -- overhang with bat nests in the wall
}

-- The Black Stream and its head on the cliffs (typed apart: only the first has shallows).
local STREAMS: { Types.Stream } = {
	{
		id = "blackStream",
		points = {
			598,
			-140,
			520,
			-150,
			452,
			-142,
			392,
			-128,
			330,
			-104,
			262,
			-74,
			206,
			-40,
			192,
			40,
			226,
			116,
			296,
			196,
			352,
			284,
			430,
			338,
			480,
			380,
		},
		widths = { 6, 7, 8, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12 },
		bank = 5,
		depth = 2.6,
		into = "marsh:1",
		shallows = { { x = 226, z = 117, r = 14, depth = 0.7 } }, -- the ford of the swamp path
	},
	{
		-- on the Blood Cliffs plateau to the lip of the black waterfall
		id = "blackStreamHead",
		points = { 700, -176, 664, -158, 618, -142 },
		widths = { 3, 4, 5 },
		bank = 3,
		depth = 1.2,
		into = "fall",
		centreOnly = true,
	},
}

local data: Types.MapAreas = {
	map = "duskwood",
	roads = {
		-- the main road: Meadows portal -> dusk gate -> forest -> crossroads -> cut up the Blood Cliffs -> Crypt
		{
			points = {
				-790,
				0,
				-640,
				10,
				-480,
				20,
				-330,
				-28,
				-200,
				-60,
				-60,
				-34,
				80,
				0,
				230,
				-24,
				360,
				-40,
				470,
				-12,
				560,
				0,
				640,
				0,
				724,
				0,
			},
			width = 12,
			material = "Ground",
		},
		{ points = { -790, 160, -620, 92, -480, 20 }, width = 10, material = "Ground" }, -- from the city portal
		{ points = { -200, -60, -170, -200, -134, -346 }, width = 10, material = "Ground" }, -- up to the manor
		{ points = { 360, -40, 392, -150, 446, -330, 500, -462 }, width = 10, material = "Ground" }, -- the village
		{ points = { 80, 0, 150, 96, 240, 120, 330, 180, 400, 262, 430, 310 }, width = 8, material = "Mud" }, -- swamp path
		{ points = { 560, 0, 554, -150, 574, -300, 640, -430, 700, -566, 736, -720 }, width = 10, material = "Ground" },
		{ points = { -480, 20, -452, -150, -420, -400, -420, -718 }, width = 8, material = "Ground" }, -- Wolf Den
		{ points = { -170, -200, 30, -300, 116, -470, 176, -720 }, width = 8, material = "Ground" }, -- the barrow
		{ points = { -620, 92, -612, 260, -566, 420 }, width = 8, material = "Ground" }, -- into Bear Hollow
	},
	lakes = {
		{ x = 604, z = 566, r = 42 }, -- open water of the Troll Swamp (jetty, sunken tower)
		{ x = 436, z = -640, r = 13 }, -- the serpents' pond
	},
	streams = STREAMS,
	avoid = {
		{ x = -770, z = 0, r = 70 }, -- Meadows portal
		{ x = -770, z = 160, r = 60 }, -- city portal
		{ x = 740, z = -740, r = 60 }, -- Ashen portal
		{ x = -690, z = -36, r = 24 }, -- the scout
		-- respawn points (Data/Terrain/duskwood respawns)
		{ x = -700, z = 52, r = 40 },
		{ x = -166, z = -196, r = 35 },
		{ x = 112, z = 84, r = 35 },
		{ x = 400, z = -262, r = 35 },
		{ x = 336, z = 140, r = 35 },
		{ x = 684, z = 44, r = 35 },
		-- buildings and landmarks
		{ x = SITES.duskGate.x, z = SITES.duskGate.z, r = 30 },
		{ x = SITES.ravagedCamp.x, z = SITES.ravagedCamp.z, r = 30 },
		{ x = SITES.moonstone.x, z = SITES.moonstone.z, r = 30 },
		{ x = SITES.boneTree.x, z = SITES.boneTree.z, r = 22 },
		{ x = SITES.fallenGiant.x, z = SITES.fallenGiant.z, r = 30 },
		{ x = SITES.lostCamp.x, z = SITES.lostCamp.z, r = 30 },
		{ x = SITES.manor.x, z = SITES.manor.z, r = 60 },
		{ x = SITES.cemetery.x, z = SITES.cemetery.z, r = 38 },
		{ x = SITES.chapel.x, z = SITES.chapel.z, r = 24 },
		{ x = SITES.familyCrypt.x, z = SITES.familyCrypt.z, r = 20 },
		{ x = SITES.elderTree.x, z = SITES.elderTree.z, r = 40 },
		{ x = SITES.cultVillage.x, z = SITES.cultVillage.z, r = 88 },
		{ x = SITES.serpentPond.x, z = SITES.serpentPond.z, r = 30 },
		{ x = SITES.wayShrine.x, z = SITES.wayShrine.z, r = 22 },
		{ x = SITES.gallows.x, z = SITES.gallows.z, r = 20 },
		{ x = SITES.trollVillage.x, z = SITES.trollVillage.z, r = 40 },
		{ x = SITES.swampJetty.x, z = SITES.swampJetty.z, r = 26 },
		{ x = SITES.stiltVillage.x, z = SITES.stiltVillage.z, r = 40 },
		{ x = SITES.witchHut.x, z = SITES.witchHut.z, r = 34 },
		{ x = SITES.hangingTree.x, z = SITES.hangingTree.z, r = 22 },
		{ x = SITES.cryptGate.x, z = SITES.cryptGate.z, r = 30 },
		{ x = SITES.blackFall.x, z = SITES.blackFall.z, r = 26 },
	},
	caves = {
		{ cave = "duskwood_den", x = -420, z = -745, rot = 180 },
		{ cave = "duskwood_barrow", x = 180, z = -745, rot = 180 },
		{ cave = "duskwood_cave", x = 745, z = 0, rot = 90 },
	},
	sites = SITES,
	areas = {
		{
			id = "duskwood_werethicket",
			nameKey = "area.duskwood_werethicket",
			lv = { 20, 25 },
			kinds = { "werewolf", "blackBear" },
			rect = { -760, -400, -420, 400 },
			groups = 8,
			profile = "exp", -- S33: werewolf packs
			arrive = { x = -682, z = 7 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.moonstone.x, z = SITES.moonstone.z },
			decor = "thicket",
		},
		{
			id = "duskwood_bearhollow",
			nameKey = "area.duskwood_bearhollow",
			lv = { 21, 27 },
			kinds = { "blackBear", "werewolf" },
			rect = { -760, 420, -300, 780 },
			groups = 6,
			profile = "loot", -- S33: the hollow keeps the gear of lost hunters
			arrive = { x = -528, z = 596 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.fallenGiant.x, z = SITES.fallenGiant.z },
			decor = "hollow",
		},
		{
			id = "duskwood_ruins",
			nameKey = "area.duskwood_ruins",
			lv = { 24, 31 },
			kinds = { "forestWraith", "ghoul" },
			rect = { -400, -780, 60, -150 },
			groups = 7,
			profile = "gold", -- S33: wraiths of the old nobles keep their coin
			arrive = { x = 53, z = -345 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.manor.x, z = SITES.manor.z },
			decor = "ruins",
		},
		{
			id = "duskwood_heart",
			nameKey = "area.duskwood_heart",
			lv = { 26, 33 },
			kinds = { "rotEnt", "ghoul" },
			rect = { -250, 200, 300, 780 },
			groups = 7,
			profile = "exp", -- S33: ghouls swarm around the rotten heart
			arrive = { x = 22, z = 488 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.elderTree.x, z = SITES.elderTree.z },
			decor = "rot",
		},
		{
			id = "duskwood_cultvillage",
			nameKey = "area.duskwood_cultvillage",
			lv = { 29, 37 },
			kinds = { "darkCultist", "bogSerpent" },
			rect = { 300, -780, 780, -300 },
			groups = 7,
			profile = "gold", -- S33: the cult's tithes
			arrive = { x = 442, z = -316 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.ritualCircle.x, z = SITES.ritualCircle.z },
			decor = "cult",
		},
		{
			id = "duskwood_crossroads",
			nameKey = "area.duskwood_crossroads",
			lv = { 30, 36 },
			kinds = { "bogSerpent", "darkCultist", "forestWraith" },
			rect = { 80, -280, 515, -20 },
			groups = 5,
			profile = "exp", -- S33: everything passes the crossroads
			arrive = { x = 415, z = -26 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.wayShrine.x, z = SITES.wayShrine.z },
			decor = "mist",
		},
		{
			id = "duskwood_swamp",
			nameKey = "area.duskwood_swamp",
			lv = { 32, 40 },
			kinds = { "swampTroll", "bogSerpent", "marshWitch" },
			rect = { 305, 180, 780, 780 },
			groups = 7,
			profile = "exp", -- S33: trolls and serpents in numbers
			arrive = { x = 341, z = 192 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.sunkenTower.x, z = SITES.sunkenTower.z },
			decor = "bog",
		},
		{
			id = "duskwood_witchmarsh",
			nameKey = "area.duskwood_witchmarsh",
			lv = { 36, 42 },
			kinds = { "marshWitch", "swampTroll" },
			rect = { -220, 20, 300, 195 },
			groups = 4,
			profile = "loot", -- S33: witches' charms and trinkets
			arrive = { x = 105, z = 34 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.witchHut.x, z = SITES.witchHut.z },
			decor = "witch",
		},
		{
			id = "duskwood_bloodcliffs",
			nameKey = "area.duskwood_bloodcliffs",
			lv = { 40, 45 },
			kinds = { "bloodBat", "marshWitch" },
			rect = { 520, -300, 780, 160 },
			groups = 6,
			arrive = { x = 536, z = -3 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.cryptGate.x, z = SITES.cryptGate.z },
			decor = "cliffs",
		},
	},
}

return data
