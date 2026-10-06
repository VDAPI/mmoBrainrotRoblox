--!strict
-- Shape of the Whispering Meadows terrain (S26), read by the pure height function Logic/MeadowsTerrain. Roads,
-- lakes, streams and building sites come from Data/Areas/meadows (one source with the monster areas and the map);
-- this file holds everything that only shapes the ground. Map-relative studs, y = 0 is the old flat ground.
--
-- Layers (in order): rolling ground (two noise octaves, amplitude per zone) + hills (soft ellipses) + the eastern
-- highland -> Bear Ravine (carved gorge with a bowl and the waterfall) -> Old Quarry (three terraces) -> marsh ->
-- flats (buildings, portals, cave mouths, NPC spots) -> roads (smoothed profile) -> ramps (paths with their own
-- height) -> lakes -> streams (water level falling along the stream).

local Areas = require("../Areas/meadows")

export type Zone = { rect: { number }, blend: number, amp: number }
export type Hill = { x: number, z: number, rx: number, rz: number, rot: number, h: number, flat: number }
export type RavinePoint = { x: number, z: number, half: number, floor: number }
export type Flat = { x: number, z: number, r: number, blend: number, y: number? }
-- Ramp point: { x, z, y? } (y = nil: the ground height there before the ramp).
export type Ramp = { w: number, pts: { { number } } }
export type Theme = { rect: { number }, theme: string }
export type Patch = { x: number, z: number, r: number, material: string }
export type Crossing = { x: number, z: number, kind: "stone" | "wood" | "ford" }
-- Quarry profile breakpoint: normalised radius e and terrace height y (nil = the ground around the pit).
export type Level = { e: number, y: number? }

local sites = assert(Areas.sites, "meadows sites")

local function site(name: string, r: number, blend: number, y: number?): Flat
	local s = sites[name]
	return { x = s.x, z = s.z, r = r, blend = blend, y = y }
end

local flats: { Flat } = {
	{ x = -770, z = 0, r = 18, blend = 24 }, -- city portal
	{ x = 730, z = -720, r = 18, blend = 24 }, -- Duskwood portal
	{ x = 60, z = 735, r = 24, blend = 22 }, -- Smugglers' Hideout
	{ x = 420, z = -745, r = 24, blend = 22 }, -- Goblin Warren
	{ x = -700, z = 30, r = 10, blend = 12 }, -- respawn points
	{ x = -60, z = -250, r = 10, blend = 12 },
	{ x = 120, z = 300, r = 10, blend = 12 },
	{ x = 395, z = -150, r = 10, blend = 12 },
	site("gate", 14, 16),
	site("shrine", 13, 22),
	site("farm", 44, 30),
	site("fisher", 16, 18, 1.2),
	site("woodcutter", 22, 22),
	site("ruins", 18, 18),
	site("stonecircle", 16, 20),
	site("mill", 18, 24),
	site("wagon", 12, 14),
	site("banditCamp", 52, 30),
	site("minerShed", 14, 16),
	site("goblinCamp", 56, 30),
	site("hunterCamp", 15, 14),
}
for _, s in assert(Areas.npcSpots, "meadows npc spots") do
	table.insert(flats, { x = s.x, z = s.z, r = 8, blend = 10 })
end

return table.freeze({
	seed = 26,
	-- Lake and marsh water surface (Toad Pond, the bandits' pond, marsh pools).
	lakeLevel = -1,
	lakeDepth = 7,
	lakeShore = 16,
	-- Rolling ground: broad swell + detail octave whose amplitude depends on the zone (soft rectangles).
	-- (amplitudes are about the typical peak-to-peak height: fbm noise rarely leaves 0.25..0.75)
	swell = { amp = 7, scale = 260 },
	detail = { amp = 8, scale = 70 },
	fine = { amp = 1.4, scale = 18 },
	zones = {
		{ rect = { -470, -330, -200, 330 }, blend = 70, amp = 18 }, -- Wolf Hills
		{ rect = { -320, -780, 220, -380 }, blend = 60, amp = 11 }, -- Old Forest
		{ rect = { -180, -330, 260, 60 }, blend = 60, amp = 5 }, -- Crow Field (old fields)
		{ rect = { -150, 380, 450, 780 }, blend = 60, amp = 11 }, -- south of the merchant road
		{ rect = { 420, -780, 780, -340 }, blend = 60, amp = 10 }, -- goblin hills
		{ rect = { 560, 360, 800, 800 }, blend = 60, amp = 12 }, -- bear highland
		{ rect = { -760, -330, -480, 330 }, blend = 60, amp = 6 }, -- Rabbit Glade (gentle)
	} :: { Zone },
	hills = {
		-- Wolf Hills: the ridge with the stone circle, a southern knoll, smaller hills
		{ x = -340, z = -150, rx = 66, rz = 150, rot = 8, h = 15, flat = 0.22 },
		{ x = -355, z = 205, rx = 70, rz = 86, rot = -10, h = 10, flat = 0.1 },
		{ x = -425, z = -275, rx = 46, rz = 40, rot = 0, h = 7, flat = 0 },
		{ x = -290, z = -290, rx = 34, rz = 30, rot = 0, h = 5, flat = 0 },
		{ x = -420, z = 120, rx = 40, rz = 50, rot = 0, h = 6, flat = 0 },
		-- Rabbit Glade: the shrine knoll and two soft swells
		{ x = -606, z = -72, rx = 46, rz = 40, rot = 20, h = 4.5, flat = 0.45 },
		{ x = -560, z = 210, rx = 70, rz = 60, rot = 0, h = 4, flat = 0 },
		{ x = -700, z = -300, rx = 60, rz = 50, rot = 0, h = 5, flat = 0 },
		-- Toad Pond: a low ridge west of the water
		{ x = -700, z = 690, rx = 60, rz = 80, rot = 0, h = 5, flat = 0 },
		-- Old Forest
		{ x = -240, z = -680, rx = 80, rz = 60, rot = 0, h = 8, flat = 0 },
		{ x = 110, z = -700, rx = 70, rz = 55, rot = 0, h = 7, flat = 0 },
		{ x = -40, z = -640, rx = 50, rz = 45, rot = 0, h = 5, flat = 0 },
		-- Crow Field: the mill's rise
		{ x = 40, z = -150, rx = 44, rz = 40, rot = 0, h = 3.5, flat = 0.5 },
		-- south: hills around the bandit camp and the hideout
		{ x = 50, z = 610, rx = 70, rz = 60, rot = 0, h = 7, flat = 0 },
		{ x = 210, z = 690, rx = 80, rz = 60, rot = 0, h = 9, flat = 0 },
		{ x = 350, z = 470, rx = 80, rz = 75, rot = 0, h = 4, flat = 0.6 },
		{ x = -40, z = 330, rx = 55, rz = 45, rot = 0, h = 4, flat = 0 },
		-- quarry surroundings and the goblin hills
		{ x = 705, z = -10, rx = 60, rz = 55, rot = 0, h = 8, flat = 0 },
		{ x = 330, z = -240, rx = 50, rz = 45, rot = 0, h = 5, flat = 0 },
		{ x = 520, z = -660, rx = 60, rz = 55, rot = 0, h = 8, flat = 0 },
		{ x = 760, z = -560, rx = 50, rz = 70, rot = 0, h = 10, flat = 0 },
	} :: { Hill },
	-- Eastern highland: Bear Ridge stands ~20 studs over the plains; Bear Ravine is cut into it.
	highland = { rect = { 570, 140, 900, 900 }, blend = 120, h = 19 },
	-- Bear Ravine: centre line with the floor half-width and height; the last point is the bowl under the
	-- waterfall (with the mouth of Mosshollow Cave in its east wall). Walls `wall` studs wide (steep rock).
	ravine = {
		wall = 8,
		pts = {
			{ x = 420, z = 292, half = 16, floor = 3 },
			{ x = 500, z = 286, half = 22, floor = 3.4 },
			{ x = 570, z = 282, half = 26, floor = 3.8 },
			{ x = 635, z = 286, half = 30, floor = 4.2 },
			{ x = 690, z = 296, half = 40, floor = 4.6 },
			{ x = 718, z = 300, half = 44, floor = 4.8 },
		} :: { RavinePoint },
	},
	-- Old Quarry: elliptic pit, three terraces (outer ring -> bottom), each `y` deep, walls between them.
	quarry = {
		x = sites.quarry.x,
		z = sites.quarry.z,
		rx = 122,
		rz = 96,
		-- breakpoints of the profile by normalised radius e (1 = rim): ground outside, terraces inside
		levels = {
			{ e = 1.07, y = nil },
			{ e = 1.0, y = -1.5 },
			{ e = 0.83, y = -1.5 },
			{ e = 0.78, y = -7 },
			{ e = 0.56, y = -7 },
			{ e = 0.51, y = -12.5 },
			{ e = 0, y = -12.5 },
		} :: { Level },
	},
	-- Paths with their own height: down into Bear Ravine by the hunter's camp, the quarry ramps.
	ramps = {
		{ w = 9, pts = { { 676, 346 }, { 640, 336, 15 }, { 600, 326, 9.5 }, { 556, 316, 4.6 }, { 522, 300 } } },
		{ w = 9, pts = { { 428, -126 }, { 448, -150, -1.5 }, { 470, -176, -1.5 } } },
		{ w = 9, pts = { { 488, -186, -1.5 }, { 530, -196, -4.2 }, { 575, -192, -7 }, { 600, -180, -7 } } },
		{
			w = 9,
			pts = {
				{ 600, -180, -7 },
				{ 630, -160, -7 },
				{ 640, -125, -9.5 },
				{ 622, -100, -12.5 },
				{ 600, -95, -12.5 },
			},
		},
	} :: { Ramp },
	-- Marsh around Toad Pond: pulled down to the water with noise, so shallow pools open between tussocks.
	-- (a soft ellipse with a ragged edge; `edge` = width of the transition as a fraction of the radii)
	marsh = {
		x = -500,
		z = 575,
		rx = 230,
		rz = 205,
		edge = 0.35,
		ragged = 0.25,
		level = -1.05,
		amp = 2.6,
		scale = 24,
		strength = 0.92,
	},
	flats = flats,
	-- Bridges and the ford where roads cross the streams (checked by tests/meadowsterrain.spec).
	crossings = {
		{ x = 10, z = 161, kind = "stone" },
		{ x = 360, z = 259, kind = "wood" },
		{ x = -250, z = 46, kind = "wood" },
		{ x = 5, z = -428, kind = "ford" },
	} :: { Crossing },
	-- Surface themes (dithered borders, ~50 studs): what the ground is painted with outside roads and water.
	themes = {
		{ rect = { -800, -800, -480, 340 }, theme = "meadow" },
		{ rect = { -480, -340, -190, 340 }, theme = "hills" },
		{ rect = { -800, 340, -190, 800 }, theme = "wet" }, -- the marsh core comes from the marsh weight
		{ rect = { -330, -800, 230, -350 }, theme = "forest" },
		{ rect = { -190, -350, 270, 70 }, theme = "field" },
		{ rect = { -190, 70, 470, 800 }, theme = "road" },
		{ rect = { 270, -350, 800, 90 }, theme = "quarry" },
		{ rect = { 230, -800, 800, -350 }, theme = "goblin" },
		{ rect = { 470, 90, 800, 800 }, theme = "ravine" },
	} :: { Theme },
	themeJitter = 52,
	-- Ground patches painted over the theme (first match wins).
	patches = {
		{ x = sites.wallow.x, z = sites.wallow.z, r = 18, material = "Mud" }, -- boar wallow
		{ x = sites.banditCamp.x, z = sites.banditCamp.z, r = 46, material = "Ground" },
		{ x = sites.goblinCamp.x, z = sites.goblinCamp.z, r = 50, material = "Ground" },
		{ x = sites.hunterCamp.x, z = sites.hunterCamp.z, r = 10, material = "Ground" },
		{ x = -611, z = -195, r = 13, material = "Ground" }, -- vegetable plot of the farm
		{ x = sites.mill.x, z = sites.mill.z, r = 15, material = "Ground" },
		{ x = sites.woodcutter.x, z = sites.woodcutter.z, r = 16, material = "Ground" },
	} :: { Patch },
})
