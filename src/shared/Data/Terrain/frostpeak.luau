--!strict
-- Shape of the Frost Peaks terrain (S47), read by Logic/RegionTerrain (types: Data/Terrain/Types). Roads, the ice
-- holes, the Ice Brook and the building sites come from Data/Areas/frostpeak. Character: fresh snow over grey
-- slate, raised in steps from the low west to the high east by `lifts` (the ridges and the horn keep their shape on
-- top of them); every hunting ground has its own ground:
--
--   * Ice Wolf Valley (y 0-8): a U-shaped valley floor, the frozen Ice Brook from a small glacier in the north-west
--     corner south to the Harpy Tarn; the Step climbs east to the pass (~9%),
--   * Giants' Pass (y ~30): between the North Ridge (steep south wall, crest ~100) and the South Ridge (steep north
--     wall, crest ~90, a saddle at y ~38 for the lake road), two spurs narrow it to ~130 studs at the Giants' Gate,
--   * Yeti Slopes: three benches (y 30, 42, 55) with steep steps, the Ice Grotto's mouth on the top one,
--   * Harpy Rocks (y 0-10): a forest of spires round the frozen Harpy Tarn, the Queen's Spire the tallest,
--   * Frozen Lake: a sheet of ice (y 22) in a basin under the South Ridge, the Frozen Falls in a cliff of its wall,
--   * Mammoth Tundra (y ~48): a windswept plateau; a glacier tongue from the north edge holds the Frozen Hold,
--   * Wyrm Spire: a plateau (y ~64) under the horn (summit ~150),
--   * Dragon Temple: three terraces (36, 42, 48) climbing east to the great glacier; a cleft in its front holds the
--     Glacier Heart,
--   * Ice Watch: a rocky knoll (y ~40) for the fortress.

local Areas = require("../Areas/frostpeak")
local Types = require("./Types")

local sites = assert(Areas.sites, "frostpeak sites")

local function site(name: string, r: number, blend: number, y: number?): Types.Flat
	local s = sites[name]
	return { x = s.x, z = s.z, r = r, blend = blend, y = y }
end

local PASS_Y = 30 -- floor of the Giants' Pass (and the temple's foot)
local LAKE_Y = 26 -- ground round the Frozen Lake
local ICE_Y = 22 -- the Frozen Lake's ice
local TUNDRA_Y = 48
local WYRM_Y = 64
local TOP_Y = 48 -- the temple's top terrace (the glacier's foot)

local respawns: { Types.Respawn } = {
	{ x = -700, z = 56, lookX = 0, lookZ = 0 },
	{ x = -236, z = -340, lookX = -260, lookZ = -560 },
	{ x = -130, z = 40, lookX = 94, lookZ = -14 },
	{ x = 108, z = 420, lookX = 166, lookZ = 584 },
	{ x = 430, z = 44, lookX = 560, lookZ = 0 },
	{ x = 690, z = 44, lookX = 745, lookZ = 0 },
	{ x = 330, z = -430, lookX = 236, lookZ = -500 },
}

local flats: { Types.Flat } = {
	{ x = -770, z = 0, r = 20, blend = 24 }, -- Ashen portal
	{ x = -770, z = 160, r = 20, blend = 24 }, -- city portal
	{ x = -690, z = -36, r = 9, blend = 12 }, -- the scout
	{ x = -300, z = -736, r = 24, blend = 12 }, -- Ice Grotto (top bench)
	-- the Frozen Hold: a niche cut into the glacier's front, open to the south
	{ x = 300, z = -740, r = 24, blend = 6, y = TUNDRA_Y },
	{ x = 300, z = -712, r = 20, blend = 8, y = TUNDRA_Y },
	-- the Glacier Heart: a cleft in the great glacier's front, wide at the mouth, narrow inside
	{ x = 724, z = 0, r = 24, blend = 8, y = TOP_Y },
	{ x = 746, z = 0, r = 18, blend = 6, y = TOP_Y },
	{ x = 772, z = 0, r = 11, blend = 5, y = TOP_Y },
	site("entryCairn", 6, 10),
	site("trapperCamp", 22, 16),
	site("howlRock", 12, 12),
	site("yetiDen", 18, 10),
	site("yetiBoulders", 12, 10),
	site("climbersCamp", 14, 10),
	site("thrones", 28, 18),
	site("boulderField", 16, 16),
	site("mammothGraveyard", 30, 20),
	site("huntingCamp", 26, 16),
	site("sanctuary", 30, 8),
	site("offeringAltars", 18, 8),
	site("keep", 138, 26),
	site("wyrmBones", 20, 14),
	site("wyrmObelisk", 8, 10),
}
for _, r in respawns do
	table.insert(flats, { x = r.x, z = r.z, r = 10, blend = 12 })
end

-- Harpy Rocks: a forest of spires round the tarn (the Queen's Spire first).
local spires: { Types.Spire } = {
	{ x = -420, z = 650, r = 20, h = 62, lean = 250, asym = 0.25, cap = "Snow" },
	{ x = -656, z = 500, r = 12, h = 30, lean = 30, asym = 0.2, cap = "Snow" },
	{ x = -704, z = 640, r = 14, h = 40, lean = 120, asym = 0.25, cap = "Snow" },
	{ x = -640, z = 734, r = 12, h = 34, lean = 300, asym = 0.2, cap = "Snow" },
	{ x = -520, z = 724, r = 13, h = 42, lean = 200, asym = 0.25, cap = "Snow" },
	{ x = -460, z = 540, r = 10, h = 28, lean = 80, asym = 0.2, cap = "Snow" },
	{ x = -356, z = 726, r = 14, h = 46, lean = 160, asym = 0.3, cap = "Snow" },
	{ x = -300, z = 600, r = 12, h = 34, lean = 330, asym = 0.2, cap = "Snow" },
	{ x = -372, z = 500, r = 10, h = 26, lean = 60, asym = 0.2, cap = "Snow" },
	{ x = -250, z = 690, r = 12, h = 38, lean = 220, asym = 0.25, cap = "Snow" },
	{ x = -740, z = 712, r = 12, h = 44, lean = 90, asym = 0.25, cap = "Snow" },
	{ x = -440, z = 760, r = 11, h = 32, lean = 10, asym = 0.2, cap = "Snow" },
}

-- Lifts raise the ground in steps (the ridges, hills and the horn keep their shape on top of them).
local lifts: { Types.Lift } = {
	{ rect = { -190, -240, 420, 290 }, blend = 300, y = PASS_Y, ragged = 20, linear = true }, -- the pass (the Step west of it)
	{ rect = { 420, -300, 900, 900 }, blend = 60, y = PASS_Y, ragged = 24 }, -- the temple's foot and the Ice Watch
	{ rect = { -100, 330, 420, 900 }, blend = 120, y = LAKE_Y, ragged = 30 }, -- round the Frozen Lake
	-- the Yeti Slopes' benches
	{ rect = { -470, -900, -10, -330 }, blend = 60, y = 30, ragged = 30 },
	{ rect = { -450, -900, -40, -476 }, blend = 22, y = 42, ragged = 26 },
	{ rect = { -430, -900, -70, -610 }, blend = 22, y = 55, ragged = 26 },
	{ rect = { -10, -900, 480, -340 }, blend = 420, y = TUNDRA_Y, ragged = 30, linear = true }, -- the tundra plateau
	-- the Wyrm Spire's plateau: a long even climb from the tundra (west), a short slope down to the temple (south)
	{
		rect = { 500, -900, 900, -380 },
		blend = 100,
		sides = { 580, 100, 100, 200 },
		y = WYRM_Y,
		ragged = 20,
		linear = true,
	},
	-- the temple's terraces (retaining walls ~6 studs)
	{ rect = { 500, -250, 900, 250 }, blend = 8, y = 36 },
	{ rect = { 580, -210, 900, 210 }, blend = 8, y = 42 },
	{ rect = { 650, -164, 900, 164 }, blend = 8, y = TOP_Y },
}

local shape: Types.Shape = {
	map = "frostpeak",
	seed = 47,
	writer = { bottom = -24, top = 168, margin = 64 },
	lakeLevel = -2,
	lakeDepth = 3,
	lakeShore = 10,
	swell = { amp = 3, scale = 300 },
	detail = { amp = 2.5, scale = 70 },
	fine = { amp = 0.6, scale = 16 },
	zones = {
		{ rect = { -800, -330, -420, 440 }, blend = 60, amp = 3 }, -- the valley's hummocks
		{ rect = { -200, -240, 330, 240 }, blend = 50, amp = 2 }, -- the pass floor
		{ rect = { -10, -800, 490, -340 }, blend = 50, amp = 2.5 }, -- the tundra's swell
		{ rect = { 420, -260, 800, 260 }, blend = 30, amp = 0.8 }, -- the temple's terraces
		{ rect = { -100, 400, 430, 800 }, blend = 40, amp = 1.5 }, -- round the lake
	},
	lifts = lifts,
	hills = {
		-- the valley's west wall behind the portals
		{ x = -840, z = 40, rx = 60, rz = 520, rot = 0, h = 18, flat = 0.2 },
		-- the avalanche cone at the gully's mouth
		{ x = -86, z = -560, rx = 40, rz = 24, rot = 20, h = 4, flat = 0.1 },
		-- the Ice Watch's knoll
		{ x = 640, z = 570, rx = 176, rz = 166, rot = 0, h = 10, flat = 0.7 },
		-- erratic swells on the tundra
		{ x = 120, z = -420, rx = 30, rz = 22, rot = 30, h = 3, flat = 0 },
		{ x = 380, z = -600, rx = 34, rz = 24, rot = 60, h = 3, flat = 0 },
	},
	ridges = {
		-- the North Ridge: steep wall south over the pass, gentle back north to the slopes and the tundra
		{
			pts = {
				{ -150, -252, 12, 50 },
				{ -90, -282, 66, 90 },
				{ -20, -292, 80, 100 },
				{ 60, -278, 82, 100 },
				{ 130, -300, 76, 90 },
				{ 190, -324, 50, 70 },
				{ 224, -340, 10, 40 },
			},
			sharp = 1.35,
			steep = -1,
			cliff = 34,
			jag = { amp = 14, wave = 38 },
			noGroups = true,
		},
		-- the South Ridge: steep wall north over the pass, a saddle for the lake road, a cliff over the falls
		{
			pts = {
				{ -200, 262, 10, 50 },
				{ -130, 280, 50, 80 },
				{ -60, 300, 60, 80 },
				{ 20, 302, 62, 44 },
				{ 82, 300, 58, 70 },
				{ 150, 318, 60, 80 },
				{ 230, 300, 52, 80 },
				{ 290, 284, 10, 50 },
			},
			sharp = 1.35,
			steep = 1,
			cliff = 30,
			jag = { amp = 12, wave = 34 },
			cols = { { x = 82, z = 300, depth = 50, width = 46 } },
			noGroups = true,
		},
		-- the spurs of the Giants' Gate
		{
			pts = { { 96, -262, 44, 56 }, { 94, -170, 38, 54 }, { 92, -110, 24, 46 } },
			sharp = 1.1,
			jag = { amp = 6, wave = 30 },
			noGroups = true,
		},
		{
			pts = { { 130, 296, 40, 56 }, { 108, 190, 34, 54 }, { 98, 106, 22, 46 } },
			sharp = 1.1,
			jag = { amp = 6, wave = 30 },
			noGroups = true,
		},
	},
	plateaus = {},
	gorges = {},
	basins = {},
	marshes = {},
	flats = flats,
	ramps = {
		-- the Grotto road climbs the benches' steps on ramps (the steps stay steep beside it)
		{
			w = 12,
			pts = {
				{ -253.5, -410 },
				{ -270.8, -530, 42 },
				{ -275.4, -560, 42 },
				{ -295.4, -690, 55 },
				{ -299, -712 },
			},
		},
	},
	crossings = {},
	themes = {
		{ rect = { -800, 440, -200, 800 }, theme = "harpyrocks" },
		{ rect = { -800, -800, -420, 440 }, theme = "snowforest" },
		{ rect = { -420, -800, -10, -330 }, theme = "snowfield" },
		{ rect = { -420, -330, -200, 440 }, theme = "snowfield" },
		{ rect = { -10, -800, 490, -330 }, theme = "tundra" },
		{ rect = { 490, -800, 800, -320 }, theme = "wyrmpeak" },
		{ rect = { -200, 330, 430, 800 }, theme = "icelake" },
		{ rect = { 430, 330, 800, 800 }, theme = "icefort" },
		{ rect = { 360, -320, 800, 330 }, theme = "dragontemple" },
		{ rect = { -200, -330, 360, 330 }, theme = "giants" },
	},
	defaultTheme = "giants",
	themeJitter = 30,
	patches = {
		-- the procession road's terraces, the sanctuary and the altars
		{ x = 560, z = 0, r = 24, material = "Pavement" },
		{ x = 630, z = 0, r = 28, material = "Cobblestone" },
		{ x = 694, z = 0, r = 26, material = "Pavement" },
		{ x = sites.sanctuary.x, z = sites.sanctuary.z, r = 26, material = "Cobblestone" },
		{ x = sites.offeringAltars.x, z = sites.offeringAltars.z, r = 15, material = "Pavement" },
		-- the Ice Watch's courtyard
		{ x = sites.keep.x, z = sites.keep.z, r = 56, material = "Cobblestone" },
		-- trampled ground of the camps and the giants' fire
		{ x = sites.trapperCamp.x, z = sites.trapperCamp.z, r = 12, material = "Ground" },
		{ x = sites.huntingCamp.x, z = sites.huntingCamp.z, r = 20, material = "Ground" },
		{ x = sites.thrones.x, z = sites.thrones.z, r = 16, material = "Ground" },
		{ x = sites.climbersCamp.x, z = sites.climbersCamp.z, r = 8, material = "Rock" },
	},
	materialRules = {
		-- glacier tongues: walls and the front glacier blue, broken ice on the seracs, gravel moraines
		{ glacier = true, minSlope = 30, mat = "Glacier" },
		{ glacier = true, minNoise = 0.68, mat = "Ice" },
		{ glacier = true, mat = "Glacier" },
		{ moraine = true, mat = "Salt" },
		-- the white horn of the Wyrm Spire (and the highest crests): snow but on the sheerest faces, glacier streaks
		{ mountain = true, minY = 104, maxSlope = 66, maxNoise = 0.16, mat = "Glacier" },
		{ mountain = true, minY = 104, maxSlope = 66, mat = "Snow" },
		-- cliffs of slate with dark basalt bands, snow in the gullies and rock on the ribs below
		{ minSlope = 48, mat = "@strata" },
		{ minSlope = 34, minNoise = 0.46, mat = "Slate" },
		{ minSlope = 34, mat = "Snow" },
		{ rock = true, minSlope = 22, mat = "Rock" },
		-- crests over y 80 scoured by the wind
		{ mountain = true, minY = 80, facing = "windward", mat = "Rock" },
		{ mountain = true, minY = 80, maxNoise = 0.28, mat = "Ice" },
		-- the tundra: thin snow with frozen ground and grey gravel, wind-scoured where it faces the wind
		{ theme = "tundra", minNoise = 0.8, mat = "Ground" },
		{ theme = "tundra", maxNoise = 0.2, mat = "Salt" },
		{ theme = "tundra", facing = "windward", minNoise = 0.64, mat = "Salt" },
		{ theme = "wyrmpeak", facing = "windward", minNoise = 0.55, mat = "Ice" },
		{ theme = "snowfield", maxNoise = 0.12, mat = "Rock" },
		{ theme = "giants", maxNoise = 0.14, mat = "Rock" },
		{ mat = "Snow" },
	},
	flora = {
		snowforest = {
			spacing = 22,
			dense = 0.55,
			sparse = 0.08,
			clump = 0.52,
			kinds = { snowPine = 90, frozenDead = 10 },
			filler = 3,
			fillerKinds = { snowPine = 100 },
			under = { n = 5, kinds = { snowShrub = 3 } },
		},
		snowfield = {
			spacing = 34,
			dense = 0.22,
			sparse = 0.03,
			clump = 0.58,
			kinds = { snowPine = 70, frozenDead = 30 },
			filler = 1,
			fillerKinds = { snowPine = 100 },
			under = { n = 3, kinds = { snowShrub = 2 } },
		},
		harpyrocks = {
			spacing = 34,
			dense = 0.26,
			sparse = 0.04,
			clump = 0.6,
			kinds = { snowPine = 80, frozenDead = 20 },
			filler = 1,
			fillerKinds = { snowPine = 100 },
			under = { n = 3, kinds = { snowShrub = 2 } },
		},
		giants = {
			spacing = 46,
			dense = 0.1,
			sparse = 0.02,
			clump = 0.62,
			kinds = { frozenDead = 80, snowPine = 20 },
			under = { n = 2, kinds = { snowShrub = 1 } },
		},
		icelake = {
			spacing = 40,
			dense = 0.2,
			sparse = 0.02,
			clump = 0.6,
			kinds = { snowPine = 75, iceSpike = 25 },
			filler = 1,
			fillerKinds = { snowPine = 100 },
			under = { n = 2, kinds = { snowShrub = 1 } },
		},
		tundra = {
			spacing = 64,
			dense = 0.06,
			sparse = 0.01,
			clump = 0.7,
			kinds = { frozenDead = 100 },
		},
		dragontemple = {
			spacing = 54,
			dense = 0.06,
			sparse = 0.01,
			clump = 0.66,
			kinds = { frozenDead = 70, iceSpike = 30 },
		},
		icefort = {
			spacing = 50,
			dense = 0.08,
			sparse = 0.01,
			clump = 0.64,
			kinds = { frozenDead = 60, snowPine = 40 },
		},
		wyrmpeak = {
			spacing = 36,
			dense = 0.2,
			sparse = 0.04,
			clump = 0.6,
			kinds = { iceSpike = 100 },
		},
	},
	respawns = respawns,
	fallback = "Snow",
	capMaterial = "Snow",
	strata = { period = 9, base = "Slate", bands = { { "Basalt", 0.55, 0.68 } } },
	spires = spires,
	peaks = {
		{ x = 690, z = -650, r = 112, h = 90, faces = 4, sharp = 1.4, lean = 14, leanDir = 210 },
	},
	winds = {
		{ rect = { -900, -900, 900, 900 }, blend = 10, dir = 100, strength = 0.35, gust = 0.3 },
		{ rect = { -800, -330, -420, 440 }, blend = 80, dir = 100, strength = 0.2, gust = 0.2 }, -- calm valley
		{ rect = { -480, -800, -20, -340 }, blend = 80, dir = 110, strength = 0.5, gust = 0.5 },
		{ rect = { -800, 440, -200, 800 }, blend = 80, dir = 80, strength = 0.5, gust = 0.9 }, -- gusts in the spires
		{ rect = { -200, -240, 330, 240 }, blend = 80, dir = 90, strength = 0.75, gust = 0.4 }, -- funnel of the pass
		{ rect = { -60, 400, 420, 800 }, blend = 80, dir = 100, strength = 0.45, gust = 0.3 },
		{ rect = { 0, -800, 480, -330 }, blend = 80, dir = 95, strength = 0.8, gust = 0.5 }, -- the open tundra
		{ rect = { 400, -300, 800, 330 }, blend = 80, dir = 100, strength = 0.45, gust = 0.3 },
		{ rect = { 440, 340, 800, 800 }, blend = 80, dir = 100, strength = 0.5, gust = 0.4 },
		{ rect = { 500, -800, 800, -330 }, blend = 80, dir = 110, strength = 1, gust = 0.7 }, -- the horn's blizzard
	},
	frozenLakes = {
		-- the Frozen Lake (two lobes)
		{
			lobes = {
				{ x = 150, z = 610, rx = 160, rz = 115, rot = 0 },
				{ x = 300, z = 640, rx = 110, rz = 95, rot = 20 },
			},
			ice = ICE_Y,
			depth = 10,
			ragged = 8,
			shore = 14,
		},
		-- the Harpy Tarn
		{ lobes = { { x = -560, z = 612, rx = 74, rz = 52, rot = 8 } }, ice = -1, depth = 10, ragged = 5, shore = 10 },
		-- the pool under the Frozen Falls
		{ lobes = { { x = 24, z = 384, rx = 32, rz = 24, rot = 0 } }, ice = 25, depth = 10, ragged = 4, shore = 8 },
	},
	glaciers = {
		-- the little glacier the Ice Brook flows from (north-west corner)
		{
			pts = { { -700, -880, 70, 42 }, { -672, -780, 56, 28 }, { -646, -712, 42, 20 } },
			bulge = 4,
			side = 10,
			front = 8,
			seracs = 3,
			seracReach = 30,
			moraine = 3,
			moraineW = 12,
		},
		-- the tongue over the tundra holding the Frozen Hold
		{
			pts = { { 300, -880, 84, 78 }, { 300, -780, 78, 68 }, { 300, -700, 72, 62 } },
			bulge = 5,
			side = 12,
			front = 8,
			seracs = 4,
			seracReach = 40,
			moraine = 4,
			moraineW = 14,
		},
		-- the great glacier behind the temple: the Glacier Heart's cleft in its front
		{
			pts = { { 880, 0, 150, 74 }, { 800, 0, 140, 66 }, { 716, 0, 128, 62 } },
			bulge = 6,
			side = 14,
			front = 8,
			seracs = 5,
			seracReach = 60,
			moraine = 4,
			moraineW = 14,
		},
	},
	crevasses = {
		{ points = { 770, -112, 800, -82, 836, -92 }, width = 10, depth = 10 },
		{ points = { 770, 104, 804, 82, 842, 92 }, width = 10, depth = 10 },
		{ points = { 400, -650, 440, -640, 480, -656 }, width = 10, depth = 9, bridges = { 42 } },
	},
}

return table.freeze(shape)
