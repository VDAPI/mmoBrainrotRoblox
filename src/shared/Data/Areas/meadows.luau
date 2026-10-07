--!strict
-- Whispering Meadows (1–20): monster areas, roads, water and cave entrances (S19), rebuilt in S26 around a shaped
-- terrain (Logic/MeadowsTerrain, shape in Data/Terrain/meadows): the Whispering Brook falls from the waterfall in
-- Bear Ravine (east), crosses the middle of the map under three bridges and ends in Toad Pond (south-west); its
-- tributary from the Old Forest crosses the forest path at a ford. `sites` are the places of the buildings and
-- landmarks (World/Meadows builds them); the NPC spots and quest anchors of S27 are derived from them below.
-- The layout draws the roads from here; Logic/AreaSpawns places the monster groups.

local Types = require("./Types")

-- Building and landmark sites: x, z (map-relative), rot (yaw in degrees; the front of a building is local -Z,
-- facing (-sin rot, -cos rot): 0 north, 90 west, 180 south, 270 east).
type Site = Types.Site

local SITES: { [string]: Site } = {
	gate = { x = -736, z = 0, rot = 90 }, -- timber gate over the road behind the city portal
	shrine = { x = -604, z = -70, rot = 200 }, -- old oak with a wayside shrine on a knoll
	farm = { x = -652, z = -196, rot = 180 }, -- farmstead yard (house, barn, well, cabbage field, hives)
	fisher = { x = -546, z = 396, rot = 160 }, -- fisherman's hut on the north shore of Toad Pond
	jetty = { x = -468, z = 426, rot = 180 }, -- jetty from the shore into the pond (with a boat)
	woodcutter = { x = 104, z = -452, rot = 90 }, -- woodcutter's hut on a clearing by the forest path
	ruins = { x = -150, z = -380, rot = 20 },
	wallow = { x = -205, z = -560, rot = 0 }, -- boar wallow in the forest
	stonecircle = { x = -340, z = -150, rot = 0 }, -- on the Wolf Hills ridge
	mill = { x = 40, z = -150, rot = 200 }, -- burnt post mill on Crow Field
	wagon = { x = 172, z = 262, rot = 30 }, -- wrecked merchant wagon by the merchant road
	banditCamp = { x = 350, z = 470, rot = 0 },
	quarry = { x = 560, z = -120, rot = 0 }, -- centre of the Old Quarry pit
	minerShed = { x = 462, z = -206, rot = 50 }, -- miner's shed on the quarry rim
	goblinCamp = { x = 665, z = -410, rot = 0 },
	hunterCamp = { x = 618, z = 376, rot = 330 }, -- hunter's camp on the plateau south of Bear Ravine
	waterfall = { x = 742, z = 270, rot = 0 }, -- pool under the waterfall (the lip is north-east of it)
}

-- Point `d` studs in front of a site (its front direction turned by `turn` degrees).
local function ahead(site: Site, d: number, turn: number?): { x: number, z: number }
	local r = math.rad(site.rot + (turn or 0))
	return { x = math.floor(site.x - math.sin(r) * d + 0.5), z = math.floor(site.z - math.cos(r) * d + 0.5) }
end

local function spot(site: Site, d: number, turn: number?, facing: number?): Types.NpcSpot
	local p = ahead(site, d, turn)
	return { x = p.x, z = p.z, facing = facing or site.rot }
end

-- NPC places for S27 (in front of their building or landmark, facing the visitor).
local NPC_SPOTS: { [string]: Types.NpcSpot } = {
	farmer = spot(SITES.farm, 14, 25, 160),
	fisher = spot(SITES.fisher, 11, 0, 150),
	woodcutter = spot(SITES.woodcutter, 11, 0, 90),
	merchant = spot(SITES.wagon, 9, 90, 120),
	miner = spot(SITES.minerShed, 9, 0, 70),
	hunter = spot(SITES.hunterCamp, 9, 0, 330),
	shrine = spot(SITES.shrine, 9, 0, 200),
}

-- Quest objects for S27 (invisible parts tagged QuestAnchor).
local function anchor(id: string, site: Site, d: number, turn: number, y: number?): Types.QuestAnchor
	local p = ahead(site, d, turn)
	return { id = id, x = p.x, z = p.z, y = y }
end

local QUEST_ANCHORS: { Types.QuestAnchor } = {
	anchor("shrine_candles", SITES.shrine, 2.5, 0, 1.5),
	-- the farm fence: corners of the vegetable plot east of the yard
	{ id = "fence_1", x = -621, z = -214 },
	{ id = "fence_2", x = -621, z = -176 },
	{ id = "fence_3", x = -601, z = -176 },
	{ id = "fence_4", x = -601, z = -214 },
	{ id = "net_shore", x = -500, z = 424 },
	{ id = "logpile_1", x = 120, z = -440 },
	{ id = "logpile_2", x = 116, z = -470 },
	{ id = "logpile_3", x = -70, z = -560 },
	{ id = "logpile_4", x = -250, z = -470 },
	{ id = "logpile_5", x = 150, z = -640 },
	anchor("mill_ruin", SITES.mill, 9, 0, 1),
	anchor("wagon_goods", SITES.wagon, 6, 180, 1),
	-- boarded tunnels in the wall between the first and the second terrace of the quarry (World/Meadows)
	{ id = "tunnel_1", x = 620, z = -176 },
	{ id = "tunnel_2", x = 647, z = -95 },
	{ id = "tunnel_3", x = 480, z = -84 },
	anchor("totem_goblin", SITES.goblinCamp, 5, 0, 2),
	{ id = "bear_den", x = 700, z = 470 },
}

local function avoidSpots(): { Types.Circle }
	local list: { Types.Circle } = {
		{ x = -770, z = 0, r = 70 }, -- city portal
		{ x = 730, z = -720, r = 60 }, -- Duskwood portal
		-- respawn points
		{ x = -700, z = 30, r = 40 },
		{ x = -60, z = -250, r = 35 },
		{ x = 120, z = 300, r = 35 },
		{ x = 395, z = -150, r = 35 },
		{ x = 680, z = 322, r = 35 },
		-- buildings and landmarks
		{ x = SITES.shrine.x, z = SITES.shrine.z, r = 30 },
		{ x = SITES.farm.x, z = SITES.farm.z, r = 58 },
		{ x = SITES.fisher.x, z = SITES.fisher.z, r = 30 },
		{ x = SITES.jetty.x, z = SITES.jetty.z, r = 22 },
		{ x = SITES.woodcutter.x, z = SITES.woodcutter.z, r = 36 },
		{ x = SITES.ruins.x, z = SITES.ruins.z, r = 32 },
		{ x = SITES.stonecircle.x, z = SITES.stonecircle.z, r = 22 },
		{ x = SITES.mill.x, z = SITES.mill.z, r = 32 },
		{ x = SITES.wagon.x, z = SITES.wagon.z, r = 26 },
		{ x = SITES.banditCamp.x, z = SITES.banditCamp.z, r = 66 },
		{ x = SITES.minerShed.x, z = SITES.minerShed.z, r = 26 },
		{ x = SITES.goblinCamp.x, z = SITES.goblinCamp.z, r = 62 },
		{ x = SITES.hunterCamp.x, z = SITES.hunterCamp.z, r = 28 },
		{ x = SITES.waterfall.x, z = SITES.waterfall.z, r = 30 },
	}
	for _, s in NPC_SPOTS do
		table.insert(list, { x = s.x, z = s.z, r = 22 })
	end
	return list
end

local data: Types.MapAreas = {
	map = "meadows",
	roads = {
		-- the merchant road: city portal -> Wolf Hills saddle -> stone bridge -> bandit crossroads -> Bear Ravine
		{
			points = {
				-790,
				0,
				-640,
				0,
				-520,
				6,
				-420,
				16,
				-300,
				34,
				-200,
				58,
				-120,
				86,
				-40,
				128,
				2,
				140,
				12,
				182,
				60,
				205,
				130,
				250,
				220,
				320,
				300,
				370,
				370,
				345,
				430,
				306,
				500,
				302,
				570,
				300,
				640,
				302,
				700,
				316,
				712,
				326,
			},
			width = 14,
			material = "Ground",
		},
		-- forest path north to the woodcutter (ford over the forest brook)
		{
			points = { -120, 86, -100, -40, -75, -190, -50, -310, -15, -395, 25, -460, 60, -520 },
			width = 10,
			material = "Ground",
		},
		-- from the bandit crossroads north past the quarry to the goblin camp and the Duskwood portal
		{
			points = {
				300,
				370,
				345,
				300,
				370,
				230,
				400,
				150,
				420,
				70,
				405,
				-60,
				415,
				-200,
				470,
				-300,
				545,
				-380,
				600,
				-470,
				660,
				-560,
				705,
				-640,
				722,
				-695,
			},
			width = 12,
			material = "Ground",
		},
		-- south to the Smugglers' Hideout
		{ points = { 300, 370, 250, 450, 180, 560, 100, 660, 64, 704 }, width = 10, material = "Ground" },
		-- to the Goblin Warren
		{ points = { 600, -470, 520, -560, 450, -640, 425, -712 }, width = 10, material = "Ground" },
		-- S26: from the merchant road south to the jetty on Toad Pond
		{ points = { -520, 6, -506, 140, -492, 270, -482, 350, -470, 410 }, width = 8, material = "Ground" },
	},
	-- Toad Pond (irregular: several circles) and the bandits' pond
	lakes = {
		{ x = -480, z = 530, r = 95 },
		{ x = -560, z = 600, r = 62 },
		{ x = -400, z = 482, r = 52 },
		{ x = -515, z = 655, r = 52 },
		{ x = -615, z = 520, r = 34 },
		{ x = -60, z = 560, r = 34 },
	},
	streams = {
		{
			id = "brook",
			points = {
				740,
				280,
				705,
				268,
				655,
				264,
				600,
				264,
				540,
				268,
				485,
				272,
				440,
				276,
				400,
				268,
				360,
				259,
				310,
				240,
				255,
				215,
				190,
				190,
				125,
				172,
				60,
				163,
				10,
				161,
				-40,
				168,
				-100,
				188,
				-170,
				222,
				-235,
				262,
				-290,
				300,
				-340,
				345,
				-378,
				392,
				-398,
				432,
			},
			widths = { 26, 12, 10, 10, 10, 11, 12, 12, 9, 12, 13, 14, 14, 13, 9, 13, 14, 15, 16, 15, 15, 16, 16 },
			bank = 5,
			depth = 2.6,
			into = "lake",
			shallows = { { x = 600, z = 264, r = 30, depth = 1.2 }, { x = 125, z = 172, r = 24, depth = 1.4 } },
		},
		{
			id = "forestBrook",
			points = {
				92,
				-362,
				45,
				-398,
				5,
				-427.5,
				-42,
				-424,
				-95,
				-372,
				-135,
				-318,
				-200,
				-232,
				-240,
				-150,
				-258,
				-60,
				-252,
				30,
				-250,
				46,
				-246,
				120,
				-240,
				200,
				-235,
				262,
			},
			widths = { 12, 7, 8, 7, 8, 8, 8, 8, 9, 7, 7, 9, 9, 9 },
			bank = 4,
			depth = 1.8,
			into = "stream:1",
			shallows = { { x = 5, z = -427.5, r = 16, depth = 0.7 } },
		},
		{
			-- above the waterfall: from the eastern hills to the lip of Bear Ravine
			id = "upperBrook",
			points = { 800, 226, 780, 238, 764, 252, 754, 260 },
			widths = { 8, 8, 9, 9 },
			bank = 3,
			depth = 1.6,
			into = "fall",
			centreOnly = true,
		},
	} :: { Types.Stream },
	avoid = avoidSpots(),
	caves = {
		{ cave = "meadows_hideout", x = 60, z = 735, rot = 0 },
		{ cave = "meadows_burrow", x = 420, z = -745, rot = 180 },
		{ cave = "meadows_cave", x = 745, z = 330, rot = 90 },
	},
	areas = {
		{
			id = "meadows_rabbitfields",
			nameKey = "area.meadows_rabbitfields",
			lv = { 1, 4 },
			kinds = { "rabbit", "wolf" },
			rect = { -760, -330, -480, 330 },
			groups = 7,
			arrive = { x = -672, z = 0 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.shrine.x, z = SITES.shrine.z },
			decor = "meadow",
		},
		{
			id = "meadows_wolfhills",
			nameKey = "area.meadows_wolfhills",
			lv = { 3, 7 },
			kinds = { "wolf", "lynx" },
			rect = { -470, -330, -200, 330 },
			groups = 7,
			profile = "exp", -- S33: wolf packs on open hills
			arrive = { x = -454, z = 13 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.stonecircle.x, z = SITES.stonecircle.z },
			decor = "hills",
		},
		{
			id = "meadows_toadmire",
			nameKey = "area.meadows_toadmire",
			lv = { 4, 8 },
			kinds = { "swampToad", "lynx" },
			rect = { -760, 360, -200, 780 },
			groups = 6,
			profile = "loot", -- S33: the bog swallowed many travellers' gear
			arrive = { x = -477, z = 376 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.jetty.x, z = SITES.jetty.z },
			decor = "marsh",
		},
		{
			id = "meadows_oldforest",
			nameKey = "area.meadows_oldforest",
			lv = { 6, 11 },
			kinds = { "boar", "carrionCrow" },
			rect = { -320, -780, 220, -360 },
			groups = 7,
			profile = "exp", -- S33: boars and crows everywhere
			arrive = { x = -23, z = -376 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.woodcutter.x, z = SITES.woodcutter.z },
			decor = "forest",
		},
		{
			id = "meadows_crowfield",
			nameKey = "area.meadows_crowfield",
			lv = { 8, 12 },
			kinds = { "carrionCrow", "boar", "bandit" },
			rect = { -180, -330, 260, 40 },
			groups = 5,
			profile = "gold", -- S33: old battlefield, crows carry off trinkets
			arrive = { x = -110, z = 24 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.mill.x, z = SITES.mill.z },
			decor = "field",
		},
		{
			id = "meadows_banditroad",
			nameKey = "area.meadows_banditroad",
			lv = { 9, 14 },
			kinds = { "bandit", "koboldMiner" },
			rect = { -150, 120, 450, 780 },
			groups = 8,
			profile = "gold", -- S33: bandits with purses
			arrive = { x = -40, z = 128 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.banditCamp.x, z = SITES.banditCamp.z },
			decor = "road",
		},
		{
			id = "meadows_diggings",
			nameKey = "area.meadows_diggings",
			lv = { 11, 15 },
			kinds = { "koboldMiner", "goblinScout" },
			rect = { 260, -330, 780, 60 },
			groups = 6,
			profile = "loot", -- S33: ores and the miners' chests
			arrive = { x = 417, z = 44 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.quarry.x, z = SITES.quarry.z },
			decor = "quarry",
		},
		{
			id = "meadows_goblincamp",
			nameKey = "area.meadows_goblincamp",
			lv = { 13, 18 },
			kinds = { "goblinScout", "koboldMiner" },
			rect = { 420, -780, 780, -340 },
			groups = 6,
			profile = "exp", -- S33: a crowded camp
			arrive = { x = 519, z = -352 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.goblinCamp.x, z = SITES.goblinCamp.z },
			decor = "goblin",
		},
		{
			id = "meadows_bearridge",
			nameKey = "area.meadows_bearridge",
			lv = { 16, 20 },
			kinds = { "brownBear", "goblinScout" },
			rect = { 480, 100, 780, 780 },
			groups = 6,
			profile = "loot", -- S33: bears guard the remains of hunters
			arrive = { x = 496, z = 302 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = SITES.waterfall.x, z = SITES.waterfall.z },
			decor = "ravine",
		},
	},
	npcSpots = NPC_SPOTS,
	questAnchors = QUEST_ANCHORS,
	sites = SITES,
}

return data
