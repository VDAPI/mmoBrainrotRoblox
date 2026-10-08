--!strict
-- Shape of the Duskwood terrain (S45), read by Logic/RegionTerrain (types: Data/Terrain/Types). Roads, lakes, the
-- Black Stream and the building sites come from Data/Areas/duskwood. Character: old rooty forest on rolling
-- ground; water and mist gather in hollows; a wall of red cliffs in the east.
--
--   * Werewolf Thicket: humps and roots (amplitude 10), the Moon Glade on a low knoll,
--   * Bear Hollow: a winding gorge 11-14 studs deep from the north-east to the south-west, two paths down,
--   * Haunted Ruins: the manor's rise (a plateau 8 studs over the forest), the cemetery below it,
--   * Heart of the Forest: a hollow 12 studs deep around the Elder Tree, root ridges splitting its floor, rot pools,
--   * Misty Crossroads: a broad shallow bowl around the junction where the fog stands,
--   * Troll Swamp and Witch Marsh: big marshes with ragged shores and dry islands for the groups,
--   * Blood Cliffs: a red scarp facing west (14-16 studs), fading out at both ends; the main road climbs it in a
--     cut, the Crypt of the Forgotten opens on the plateau's courtyard by the map edge.

local Areas = require("../Areas/duskwood")
local Types = require("./Types")

local sites = assert(Areas.sites, "duskwood sites")

local function site(name: string, r: number, blend: number, y: number?): Types.Flat
	local s = sites[name]
	return { x = s.x, z = s.z, r = r, blend = blend, y = y }
end

local CLIFF_Y = 21 -- top of the Blood Cliffs plateau

local respawns: { Types.Respawn } = {
	{ x = -700, z = 52, lookX = 0, lookZ = 0 },
	{ x = -166, z = -196, lookX = -130, lookZ = -436 },
	{ x = 112, z = 84, lookX = 150, lookZ = 372 },
	{ x = 400, z = -262, lookX = 560, lookZ = -560 },
	{ x = 336, z = 140, lookX = 580, lookZ = 520 },
	{ x = 684, z = 44, lookX = 745, lookZ = 0 },
}

local flats: { Types.Flat } = {
	{ x = -770, z = 0, r = 18, blend = 24 }, -- Meadows portal
	{ x = -770, z = 160, r = 18, blend = 24 }, -- city portal
	{ x = 740, z = -740, r = 18, blend = 24 }, -- Ashen portal
	{ x = -420, z = -745, r = 24, blend = 22 }, -- Wolf Den
	{ x = 180, z = -745, r = 24, blend = 22 }, -- Cultists' Barrow
	{ x = 742, z = 0, r = 28, blend = 14, y = CLIFF_Y }, -- Crypt of the Forgotten (courtyard on the plateau)
	{ x = -690, z = -36, r = 9, blend = 12 }, -- the scout
	site("duskGate", 13, 16),
	site("ravagedCamp", 18, 16),
	site("moonstone", 20, 22),
	site("lostCamp", 16, 10),
	site("wayShrine", 9, 12),
	site("gallows", 8, 10),
	site("cultVillage", 62, 26),
	site("cultHall", 16, 14),
	site("ritualCircle", 16, 14),
	site("cemetery", 26, 18),
	site("chapel", 12, 14),
	site("familyCrypt", 9, 12),
	site("hangingTree", 9, 12),
	site("boneTree", 8, 10),
	site("elderTree", 16, 16),
}
for _, r in respawns do
	table.insert(flats, { x = r.x, z = r.z, r = 10, blend = 12 })
end

-- Root ridges of the Elder Tree: five arms falling from the trunk to the floor of the hollow.
local ridges: { Types.Ridge } = {}
local tree = sites.elderTree
for i, a in { 20, 95, 160, 230, 300 } do
	local r = math.rad(a)
	local c, s = math.cos(r), math.sin(r)
	local len = 92 + (i % 2) * 18
	table.insert(ridges, {
		pts = {
			{ tree.x + c * 14, tree.z + s * 14, 5, 13 },
			{ tree.x + c * len * 0.55, tree.z + s * len * 0.55, 3.2, 11 },
			{ tree.x + c * len, tree.z + s * len, 0, 8 },
		},
		sharp = 1.15,
	})
end

local shape: Types.Shape = {
	map = "duskwood",
	seed = 45,
	writer = { bottom = -24, top = 48, margin = 64 },
	lakeLevel = -1,
	lakeDepth = 6,
	lakeShore = 14,
	swell = { amp = 6, scale = 280 },
	detail = { amp = 7, scale = 64 },
	fine = { amp = 1.6, scale = 16 },
	zones = {
		{ rect = { -800, -420, -420, 420 }, blend = 70, amp = 11 }, -- Werewolf Thicket: humps and roots
		{ rect = { -760, 420, -300, 800 }, blend = 60, amp = 8 }, -- Bear Hollow rims
		{ rect = { -420, -800, 70, -150 }, blend = 60, amp = 6 }, -- the manor's forest
		{ rect = { 300, -800, 800, -320 }, blend = 60, amp = 3 }, -- the village clearing
		{ rect = { 80, -290, 515, -10 }, blend = 60, amp = 2.5 }, -- crossroads bowl
		{ rect = { 300, 180, 800, 800 }, blend = 60, amp = 2 }, -- swamp
		{ rect = { -230, 10, 300, 200 }, blend = 50, amp = 3 }, -- witch marsh
		{ rect = { -260, 200, 300, 800 }, blend = 60, amp = 6 }, -- heart
	},
	hills = {
		-- Thicket humps and the Moon Glade knoll
		{ x = -606, z = -262, rx = 60, rz = 54, rot = 0, h = 4, flat = 0.55 },
		{ x = -520, z = -330, rx = 70, rz = 55, rot = 30, h = 7, flat = 0 },
		{ x = -700, z = -180, rx = 50, rz = 70, rot = 0, h = 6, flat = 0 },
		{ x = -520, z = 110, rx = 60, rz = 80, rot = 20, h = 6, flat = 0 },
		{ x = -660, z = 300, rx = 70, rz = 60, rot = 0, h = 7, flat = 0 },
		-- the forest between the thicket and the crossroads
		{ x = -300, z = -120, rx = 80, rz = 50, rot = 10, h = 5, flat = 0 },
		{ x = -40, z = -190, rx = 60, rz = 50, rot = 0, h = 4, flat = 0 },
		-- the cemetery knoll and the chapel's hill
		{ x = 10, z = -560, rx = 70, rz = 60, rot = 0, h = 3, flat = 0.5 },
		-- hills north of the village and around the barrow
		{ x = 220, z = -640, rx = 90, rz = 70, rot = 0, h = 7, flat = 0 },
		{ x = 760, z = -420, rx = 60, rz = 70, rot = 0, h = 5, flat = 0 },
	},
	ridges = ridges,
	plateaus = {
		-- Blood Cliffs: the scarp faces west (cliff 6), gentle at the north and south ends.
		{
			poly = { 650, -300, 626, -220, 612, -142, 606, -60, 610, 40, 604, 112, 622, 172, 900, 178, 900, -306 },
			cliff = { 70, 7, 6, 6, 6, 6, 60, 60, 70 },
			y = CLIFF_Y,
			noise = 1.4,
		},
		-- the manor's rise
		{ x = -130, z = -440, rx = 92, rz = 74, rot = 0, y = 13, cliff = 26, noise = 0.5 },
	},
	gorges = {
		{
			wall = 11,
			pts = {
				{ x = -318, z = 446, half = 12, floor = -3.5 },
				{ x = -410, z = 508, half = 18, floor = -4.5 },
				{ x = -514, z = 566, half = 22, floor = -5.5 },
				{ x = -604, z = 650, half = 26, floor = -6.5 },
				{ x = -700, z = 724, half = 24, floor = -7.5 },
				{ x = -760, z = 760, half = 20, floor = -8 },
			},
		},
	},
	basins = {
		{ x = 150, z = 372, rx = 142, rz = 132, rot = 0, depth = 12, flat = 0.42 }, -- the Heart's hollow
		{ x = 320, z = -110, rx = 176, rz = 112, rot = 8, depth = 3, flat = 0.3 }, -- Misty Crossroads
		{ x = -606, z = 650, rx = 40, rz = 30, rot = 40, depth = 2, flat = 0.4 }, -- the gorge floor by the lost camp
	},
	marshes = {
		{
			-- Troll Swamp
			x = 584,
			z = 528,
			rx = 214,
			rz = 236,
			edge = 0.35,
			ragged = 0.3,
			level = -1.4,
			amp = 3.6,
			scale = 22,
			strength = 0.92,
			theme = "bog",
			islands = {
				{ x = sites.trollVillage.x, z = sites.trollVillage.z, r = 30, h = 1.4 },
				{ x = sites.swampJetty.x, z = sites.swampJetty.z - 14, r = 22, h = 1.2 },
				{ x = 500, z = 456, r = 30, h = 1.5 },
				{ x = 676, z = 420, r = 28, h = 1.4 },
				{ x = 530, z = 668, r = 30, h = 1.5 },
				{ x = 640, z = 716, r = 26, h = 1.3 },
			},
		},
		{
			-- Witch Marsh
			x = -56,
			z = 120,
			rx = 138,
			rz = 66,
			edge = 0.4,
			ragged = 0.3,
			level = -2.1,
			amp = 3.4,
			scale = 20,
			strength = 0.9,
			theme = "witch",
			islands = {
				{ x = sites.witchHut.x, z = sites.witchHut.z, r = 18, h = 1.2 },
			},
		},
		{
			-- rot pools on the floor of the Heart's hollow
			x = 150,
			z = 452,
			rx = 104,
			rz = 56,
			edge = 0.5,
			ragged = 0.35,
			level = -7.6,
			amp = 1.8,
			scale = 18,
			strength = 0.85,
			water = -7.1,
			theme = "rot",
		},
	},
	flats = flats,
	ramps = {
		-- Bear Hollow: down from the north rim by the fallen giant, and from the south rim to the lost camp
		{ w = 8, pts = { { -566, 420 }, { -566, 470, 0 }, { -552, 520, -4 }, { -534, 548, -5.5 } } },
		{ w = 8, pts = { { -700, 610 }, { -676, 640, -2 }, { -652, 664, -6.2 } } },
	},
	crossings = {
		{ x = 389, z = -128, kind = "stone" }, -- the village road over the Black Stream at the crossroads
		{ x = 200, z = -20, kind = "wood" }, -- the main road
		{ x = 226, z = 117, kind = "ford" }, -- the swamp path
	},
	themes = {
		{ rect = { -800, -420, -420, 420 }, theme = "thicket" },
		{ rect = { -800, 420, -290, 800 }, theme = "hollow" },
		{ rect = { -420, -800, 70, -150 }, theme = "ruins" },
		{ rect = { -260, 200, 300, 800 }, theme = "rot" },
		{ rect = { 300, -800, 800, -305 }, theme = "cult" },
		{ rect = { 70, -305, 520, -10 }, theme = "mist" },
		{ rect = { -260, -10, 300, 200 }, theme = "witch" },
		{ rect = { 300, 170, 800, 800 }, theme = "bog" },
		{ rect = { 520, -305, 800, 170 }, theme = "cliffs" },
	},
	defaultTheme = "forest",
	themeJitter = 44,
	patches = {
		{ x = sites.manor.x, z = sites.manor.z + 40, r = 22, material = "Cobblestone" }, -- the manor's courtyard
		{ x = sites.manor.x, z = sites.manor.z, r = 30, material = "Cobblestone" },
		{ x = sites.cultVillage.x, z = sites.cultVillage.z, r = 66, material = "Ground" },
		{ x = sites.ravagedCamp.x, z = sites.ravagedCamp.z, r = 14, material = "Ground" },
		{ x = sites.lostCamp.x, z = sites.lostCamp.z, r = 12, material = "Ground" },
		{ x = sites.trollVillage.x, z = sites.trollVillage.z, r = 20, material = "Ground" },
		{ x = sites.moonstone.x, z = sites.moonstone.z, r = 11, material = "Ground" },
		{ x = 742, z = 0, r = 24, material = "Sandstone" }, -- the Crypt's courtyard
	},
	materialRules = {
		{ minSlope = 40, plateau = true, mat = "Sandstone" },
		{ minSlope = 40, theme = "cliffs", mat = "Sandstone" },
		{ minSlope = 40, gorge = true, mat = "Slate" },
		{ minSlope = 40, mat = "Rock" },
		{ minSlope = 26, plateau = true, mat = "Sandstone" },
		{ minSlope = 12, maxSlope = 26, theme = "cliffs", minNoise = 0.48, mat = "Rock" },
		{ minSlope = 26, gorge = true, mat = "Rock" },
		{ minSlope = 30, minNoise = 0.5, mat = "Rock" },
		{ theme = "cliffs", minNoise = 0.64, mat = "Rock" },
		{ theme = "cliffs", maxNoise = 0.26, mat = "LeafyGrass" },
		{ theme = "cliffs", mat = "Ground" },
		{ theme = "thicket", minNoise = 0.74, mat = "Mud" },
		{ theme = "thicket", maxNoise = 0.26, mat = "Ground" },
		{ theme = "hollow", gorge = true, minNoise = 0.55, mat = "Ground" },
		{ theme = "hollow", minNoise = 0.72, mat = "Ground" },
		{ theme = "ruins", minNoise = 0.7, mat = "Ground" },
		{ theme = "ruins", maxNoise = 0.24, mat = "Mud" },
		{ theme = "rot", minNoise = 0.55, mat = "Mud" },
		{ theme = "rot", maxNoise = 0.2, mat = "Ground" },
		{ theme = "cult", minNoise = 0.5, mat = "Ground" },
		{ theme = "cult", maxNoise = 0.25, mat = "Mud" },
		{ theme = "mist", minNoise = 0.7, mat = "Mud" },
		{ theme = "mist", maxNoise = 0.3, mat = "Ground" },
		{ theme = "bog", marsh = true, mat = "Mud" },
		{ theme = "bog", minNoise = 0.56, mat = "Mud" },
		{ theme = "bog", maxNoise = 0.22, mat = "Ground" },
		{ theme = "witch", marsh = true, mat = "Mud" },
		{ theme = "witch", minNoise = 0.45, mat = "Mud" },
		{ theme = "witch", maxNoise = 0.2, mat = "Ground" },
		{ minNoise = 0.76, mat = "Mud" },
		{ maxNoise = 0.24, mat = "Ground" },
		{ mat = "LeafyGrass" },
	},
	flora = {
		thicket = {
			spacing = 17,
			dense = 0.35,
			sparse = 0.06,
			clump = 0.44,
			kinds = { gnarledOak = 46, darkPine = 34, blackDead = 12, giantOak = 8 },
			filler = 22,
			fillerKinds = { darkPine = 50, gnarledOak = 30, blackDead = 20 },
			under = { n = 30, kinds = { bramble = 5, fern = 4, sapling = 2 } },
		},
		hollow = {
			spacing = 18,
			dense = 0.3,
			sparse = 0.05,
			clump = 0.48,
			kinds = { gnarledOak = 40, darkPine = 40, blackDead = 20 },
			filler = 16,
			fillerKinds = { darkPine = 60, gnarledOak = 40 },
			under = { n = 28, kinds = { fern = 6, berryBush = 3, sapling = 1 } },
		},
		ruins = {
			spacing = 19,
			dense = 0.25,
			sparse = 0.04,
			clump = 0.5,
			kinds = { darkPine = 50, blackDead = 30, gnarledOak = 20 },
			filler = 13,
			fillerKinds = { darkPine = 60, blackDead = 40 },
			under = { n = 16, kinds = { bramble = 3, fern = 2 } },
		},
		rot = {
			spacing = 19,
			dense = 0.23,
			sparse = 0.04,
			clump = 0.5,
			kinds = { gnarledOak = 40, blackDead = 25, giantMushroom = 20, mossWillow = 15 },
			filler = 13,
			fillerKinds = { blackDead = 40, gnarledOak = 40, giantMushroom = 20 },
			under = { n = 20, kinds = { fern = 3, toadstools = 4, bramble = 1 } },
		},
		cult = {
			spacing = 21,
			dense = 0.18,
			sparse = 0.025,
			clump = 0.56,
			kinds = { darkPine = 60, blackDead = 25, gnarledOak = 15 },
			filler = 10,
			fillerKinds = { darkPine = 80, blackDead = 20 },
			under = { n = 10, kinds = { bramble = 2, fern = 1 } },
		},
		mist = {
			spacing = 21,
			dense = 0.15,
			sparse = 0.025,
			clump = 0.58,
			kinds = { blackDead = 40, mossWillow = 30, gnarledOak = 30 },
			filler = 10,
			fillerKinds = { blackDead = 50, mossWillow = 50 },
			under = { n = 12, kinds = { reedbed = 2, fern = 2, bramble = 1 } },
		},
		bog = {
			spacing = 21,
			dense = 0.15,
			sparse = 0.03,
			clump = 0.55,
			kinds = { mossWillow = 50, blackDead = 40, darkPine = 10 },
			filler = 13,
			fillerKinds = { mossWillow = 50, blackDead = 50 },
			under = { n = 16, kinds = { reedbed = 6, fern = 1 } },
		},
		witch = {
			spacing = 20,
			dense = 0.17,
			sparse = 0.03,
			clump = 0.55,
			kinds = { mossWillow = 40, blackDead = 40, gnarledOak = 20 },
			filler = 10,
			fillerKinds = { mossWillow = 50, blackDead = 50 },
			under = { n = 14, kinds = { reedbed = 4, toadstools = 2, fern = 1 } },
		},
		cliffs = {
			spacing = 22,
			dense = 0.12,
			sparse = 0.02,
			clump = 0.6,
			kinds = { blackDead = 55, darkPine = 45 },
			filler = 6,
			fillerKinds = { blackDead = 60, darkPine = 40 },
			under = { n = 10, kinds = { thorns = 4, bramble = 1 } },
		},
		forest = {
			spacing = 18,
			dense = 0.3,
			sparse = 0.05,
			clump = 0.48,
			kinds = { gnarledOak = 45, darkPine = 40, blackDead = 15 },
			filler = 16,
			fillerKinds = { darkPine = 50, gnarledOak = 50 },
			under = { n = 24, kinds = { fern = 4, bramble = 3, sapling = 1 } },
		},
	},
	respawns = respawns,
}

return table.freeze(shape)
