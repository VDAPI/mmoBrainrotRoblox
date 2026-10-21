--!strict
-- World maps (DESIGN §3.2, ARCHITECTURE §8). Every map from the design is listed so portals, stones and the
-- world map are complete; only maps with a layout (`buildMode = "generated"` and a World/Layouts module) are
-- built. Offsets keep maps >= 3000 studs apart. Lighting/atmosphere are applied on the client when the
-- player enters the map (EnvironmentController).

local ArenaPit = require("./ArenaPit")
local Bosses = require("./Bosses")
local CavePlan = require("../Logic/CavePlan")
local Town = require("./Town")
local TownTerrain = require("../Logic/TownTerrain")

export type PvpZone = "green" | "yellow" | "red"

export type Biome = "city" | "grass" | "forest" | "desert" | "snow" | "cave" | "crypt" | "dungeon"

export type Lighting = {
	clockTime: number,
	brightness: number,
	ambient: string,
	outdoorAmbient: string,
	fogColor: string,
	fogEnd: number,
	atmosphere: { density: number, haze: number, glare: number, color: string, decay: string },
	-- Colour correction tint and saturation.
	tint: string,
	saturation: number,
}

export type MapDef = {
	id: string,
	nameKey: string,
	zone: PvpZone,
	minLevel: number,
	maxLevel: number,
	-- World-space centre of the map.
	offset: { x: number, y: number, z: number },
	-- Playable footprint (studs) used for bounds checks of saved positions.
	size: { x: number, z: number },
	-- Default spawn point relative to offset.
	spawn: { x: number, y: number, z: number },
	biome: Biome,
	lighting: Lighting,
	music: string, -- rbxassetid or "" (S14 adds real tracks)
	buildMode: "generated" | "asset" | "none",
	-- World map (M) node position (0..1) and connections (portal targets).
	worldMap: { x: number, y: number },
	links: { string },
	-- Caves: the point in front of the boss dungeon entrance (Dungeon Stones, S09 respawn), relative to offset.
	dungeonEntrance: { x: number, y: number, z: number }?,
	-- Boss dungeon region served by this cave ("meadows", ...), matches stone_dungeon_<region>.
	dungeonRegion: string?,
	-- Stricter part budget than Config.MaxPartsPerMap (S21; WorldBuilder only warns).
	maxParts: number?,
	-- Day and night cycle (S21): the client runs the clock (Logic/DayCycle) and blends `lighting` (day) with
	-- `nightLighting`; maps without it keep their fixed lighting.
	dayNight: boolean?,
	nightLighting: Lighting?,
	-- S45: with dayNight, the clock range { from, to } the day's hours are shown as (eternal dusk: the sun stays
	-- low all day; Logic/DayCycle.duskClock). nil = the real clock.
	dayClock: { number }?,
	-- S45: built in the background after the server started (World/WorldBuilder.buildLate): the shaped regions.
	-- Until done, portals show "Soon" and travel there is refused, like an unbuilt map.
	buildLate: boolean?,
	-- S127: built only on servers of these modes (World/WorldBuilder.build); never on a world server, never on the
	-- world map, in travel or on the wiki.
	serverModes: { string }?,
	-- S127: left out of the wiki (tools/WikiData/Visibility), the world map search and admin map lists.
	hidden: boolean?,
}

local DAY: Lighting = {
	clockTime = 14,
	brightness = 2.2,
	ambient = "#6A6F7A",
	outdoorAmbient = "#8A8F9A",
	fogColor = "#C9D6E3",
	fogEnd = 1400,
	atmosphere = { density = 0.28, haze = 1, glare = 0.2, color = "#C7D3DE", decay = "#6A7A8A" },
	tint = "#FFFFFF",
	saturation = 0.05,
}

local function lighting(overrides: { [string]: any }): Lighting
	local result = table.clone(DAY) :: any
	for key, value in overrides do
		result[key] = value
	end
	return result
end

local LIGHT = {
	-- W01 (Studio): warm stone in the sun, softer brightness so the pale paving of the square keeps its texture
	city = lighting({
		clockTime = 15,
		brightness = 2,
		ambient = "#6A6A70",
		outdoorAmbient = "#8A8A90",
		fogEnd = 1200,
		atmosphere = { density = 0.3, haze = 1.2, glare = 0.3, color = "#DCD8D0", decay = "#7A8696" },
		tint = "#FFF4E4",
		saturation = 0.1,
	}),
	-- Night in the city (S21): cool moonlight, dark blue fog; windows, lamps and fires do the rest.
	-- W01 (Studio): roofs and streets were black at 22:00; a brighter moonlit blue, the windows still stand out
	-- W28: a touch more moonlight in the shade between the street lamps (owner: the town was patchy at night)
	cityNight = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#424C6A",
		outdoorAmbient = "#606C8E",
		fogColor = "#1C2438",
		fogEnd = 700,
		atmosphere = { density = 0.3, haze = 1, glare = 0, color = "#2E3A58", decay = "#141A2C" },
		tint = "#DCE4FF",
		saturation = -0.08,
	}),
	-- W01 (Studio): the golden late afternoon of Data/MapLooks: warm ambient and haze towards the sun, cool far away
	meadows = lighting({
		clockTime = 13,
		brightness = 2.6,
		ambient = "#6A6050",
		outdoorAmbient = "#A89880",
		fogColor = "#E6D2AE",
		atmosphere = { density = 0.3, haze = 1, glare = 0.6, color = "#EAD8BA", decay = "#B8C4CE" },
		tint = "#FFF2DE",
		saturation = 0.18,
	}),
	-- Night on the Meadows (S26): moonlight bright enough to fight in, blue-green fog; fireflies and fires glow.
	meadowsNight = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#2E3648",
		outdoorAmbient = "#46506A",
		fogColor = "#1E2632",
		fogEnd = 760,
		atmosphere = { density = 0.33, haze = 1.4, glare = 0, color = "#2E3A50", decay = "#161C2A" },
		tint = "#D4DEFF",
		saturation = -0.12,
	}),
	-- Duskwood (S45): its "day" is an eternal dusk (dayClock), the night deep blue and moonlit, bright enough to fight.
	duskwoodNight = lighting({
		clockTime = 0,
		brightness = 0.85,
		ambient = "#262A44",
		outdoorAmbient = "#363C5E",
		fogColor = "#141A2E",
		fogEnd = 380,
		atmosphere = { density = 0.46, haze = 2.2, glare = 0, color = "#222A44", decay = "#10142A" },
		tint = "#C8D2FF",
		saturation = -0.2,
	}),
	-- W01 (Studio): an overcast day under the crowns instead of the navy dusk: dark green ambient and mist, readable
	duskwood = lighting({
		clockTime = 18.2,
		brightness = 2.1,
		ambient = "#3E4A40",
		outdoorAmbient = "#5C6A5A",
		fogColor = "#4A544A",
		fogEnd = 420,
		-- W15 (bor.md A7): density 0.4 -> 0.33, the Old Tree's silhouette has to carry 700-900 studs
		atmosphere = { density = 0.33, haze = 2.2, glare = 0.2, color = "#6C746C", decay = "#30363A" },
		tint = "#E2EAD8",
		saturation = -0.08,
	}),
	-- W01 (Studio): the sunset through dust: thinner haze (it was brown milk), strong glare towards the sun
	ashen = lighting({
		clockTime = 16,
		brightness = 2.8,
		ambient = "#6A4A3C",
		outdoorAmbient = "#9A6E52",
		fogColor = "#E2A47A",
		fogEnd = 700,
		atmosphere = { density = 0.32, haze = 1.2, glare = 0.9, color = "#E2A47A", decay = "#6A3A2E" },
		tint = "#FFEAD8",
		saturation = 0.02,
	}),
	-- Night on the Ashen Wastes (S46): no stars through the ash, a reddish fog, a dark maroon ambient bright enough
	-- to fight in; the light comes from the lava, the cracks, the forges, the fires and the runes.
	ashenNight = lighting({
		clockTime = 0,
		brightness = 0.8,
		ambient = "#3A2220",
		outdoorAmbient = "#4A2A26",
		fogColor = "#2A1210",
		fogEnd = 520,
		atmosphere = { density = 0.48, haze = 2.6, glare = 0, color = "#3A1A16", decay = "#1A0A08" },
		tint = "#FFD8C8",
		saturation = -0.1,
	}),
	-- S47: blue moonlight on the snow (it reflects: bright enough to fight); the aurora, crystals, runes, fires and the
	-- Ice Watch's loopholes give the light
	frostpeakNight = lighting({
		clockTime = 0,
		brightness = 1,
		ambient = "#2E3A55",
		outdoorAmbient = "#3A4A6A",
		fogColor = "#1C2A44",
		fogEnd = 700,
		atmosphere = { density = 0.4, haze = 1.2, glare = 0, color = "#1C2A44", decay = "#0E1628" },
		tint = "#D0E2FF",
		saturation = -0.08,
	}),
	-- W01 (Studio): a crisp cold morning: blue ambient for blue shadows on the snow, thin haze (it was white milk);
	-- W19-20 (szczyty.md 1.7 b): thinner still (density 0.34 -> 0.30, haze 1 -> 0.8) so the glacier and the horn read
	-- from the far end of the main road
	frostpeak = lighting({
		clockTime = 11,
		brightness = 2.3,
		ambient = "#5A6E8E",
		outdoorAmbient = "#8296B8",
		fogColor = "#D2E4F4",
		fogEnd = 600,
		atmosphere = { density = 0.3, haze = 0.8, glare = 0.6, color = "#D2E4F4", decay = "#6C8AAA" },
		tint = "#E6F0FF",
		saturation = 0.02,
	}),
	cave = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#565E53",
		outdoorAmbient = "#495049",
		fogColor = "#262B28",
		fogEnd = 440,
		atmosphere = { density = 0.4, haze = 0, glare = 0, color = "#333A33", decay = "#1A1D1A" },
		tint = "#E0F0D8",
		saturation = -0.1,
	}),
	-- S48: presets of the caves on the engine in the cave's colour; the light of the rooms comes from their lamps, fires,
	-- moss and crystals (RegionLightController). S134h: every underground preset readable on its own (also on a phone
	-- with low graphics): brightness 0.9, ambient of relative luminance >= 0.10 in the preset's hue, fog from 380+,
	-- atmosphere density <= 0.42 and haze <= 0.4 (tests/cavelight.spec); the player carries a soft light
	-- (Config.CaveLights.player)
	-- W01 (Studio): the walls were near black; a brighter emerald ambient and a turquoise air (docs/WYGLAD.md §4.3)
	caveMoss = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#62806A",
		outdoorAmbient = "#4E6A56",
		fogColor = "#1D2F2A",
		fogEnd = 420,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#22403A", decay = "#10201C" },
		tint = "#D4F4E2",
		saturation = 0.05,
	}),
	-- W01 (Studio): warm lanterns against cool blue rock and air (§4.3)
	caveSmugglers = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#56647A",
		outdoorAmbient = "#4A5466",
		fogColor = "#18202A",
		fogEnd = 410,
		atmosphere = { density = 0.4, haze = 0.2, glare = 0, color = "#1E2A38", decay = "#0E141C" },
		tint = "#F6E8D8",
		saturation = 0.02,
	}),
	-- W01 (Studio): rotten green and lamp yellow (§4.3)
	caveWarren = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#6A7050",
		outdoorAmbient = "#585C42",
		fogColor = "#22261A",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#2C3218", decay = "#161A0C" },
		tint = "#F4F0C8",
		saturation = 0.04,
	}),
	dungeonGoblin = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#6E5748",
		outdoorAmbient = "#5D4A3A",
		fogColor = "#2F1D16",
		fogEnd = 440,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#43261A", decay = "#20130D" },
		tint = "#FFD8B8",
		saturation = 0.02,
	}),
	-- S49: presets of Duskwood's caves on the engine
	-- W01 (Studio): silver blue around the moon shaft (§4.3)
	caveDen = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#5A6A84",
		outdoorAmbient = "#4A5870",
		fogColor = "#141C2A",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0.3, glare = 0, color = "#1C2638", decay = "#0C121C" },
		tint = "#DCE6FA",
		saturation = -0.06,
	}),
	-- W01 (Studio): a readable violet instead of near black (§4.3)
	barrowViolet = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#76609A",
		outdoorAmbient = "#5E5080",
		fogColor = "#1E1630",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#2E2244", decay = "#140E22" },
		tint = "#E8DAFF",
		saturation = -0.04,
	}),
	-- W01 (Studio): pale green-white of the ghost flame (§4.3)
	cryptGhost = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#64786E",
		outdoorAmbient = "#52645A",
		fogColor = "#16241F",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#203A34", decay = "#0E1A16" },
		tint = "#E0F6EA",
		saturation = -0.12,
	}),
	-- W01 (Studio): readable violet tomb
	dungeonTomb = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#72689A",
		outdoorAmbient = "#5C5480",
		fogColor = "#161220",
		fogEnd = 440,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#2A2440", decay = "#120E20" },
		tint = "#E2DEFF",
		saturation = -0.08,
	}),
	-- S50: presets of the Ashen Wastes' caves on the engine
	-- W01 (Studio): cool mithril rock, the fires stay orange (§4.3)
	caveMine = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#5C6A7C",
		outdoorAmbient = "#4E5664",
		fogColor = "#1C1E22",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#24303E", decay = "#14100C" },
		tint = "#F4ECE2",
		saturation = 0.02,
	}),
	-- W01 (Studio): brighter red-gold; the roosts were near black (§4.3)
	caveLair = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#A07058",
		outdoorAmbient = "#7A5240",
		fogColor = "#3A1A0E",
		fogEnd = 410,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#6A3018", decay = "#2A100A" },
		tint = "#FFE2C4",
		saturation = 0.08,
	}),
	-- W01 (Studio): cool walls for the blue runes next to the ember (§4.3)
	caveForge = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#5E5E74",
		outdoorAmbient = "#4C4C60",
		fogColor = "#24120B",
		fogEnd = 460,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#3A1C10", decay = "#140A08" },
		tint = "#FFE8D4",
		saturation = 0.06,
	}),
	-- W01 (Studio): less saturated red, the arena floor readable
	dungeonFurnace = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#8E6252",
		outdoorAmbient = "#76503E",
		fogColor = "#4C1D12",
		fogEnd = 480,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#662A13", decay = "#2A100A" },
		tint = "#FFDCC4",
		saturation = 0.06,
	}),
	-- S51: presets of the Frost Peaks' caves on the engine
	caveIce = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#4A5E71",
		outdoorAmbient = "#404F62",
		fogColor = "#192836",
		fogEnd = 420,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#233646", decay = "#101A23" },
		tint = "#D8ECFF",
		saturation = -0.1,
	}),
	-- W01 (Studio): blue with room for the gold of the ice windows (§4.3)
	holdFrozen = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#5C6C86",
		outdoorAmbient = "#4C5A70",
		fogColor = "#161D28",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#1E2A3E", decay = "#0E1420" },
		tint = "#EEF0F6",
		saturation = -0.06,
	}),
	-- W01 (Studio): cyan, apart from the Ice Grotto's ice blue (§4.3)
	glacierHeart = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#3E6C7A",
		outdoorAmbient = "#345A66",
		fogColor = "#0E2432",
		fogEnd = 440,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#143A44", decay = "#081C22" },
		tint = "#C8FAF6",
		saturation = 0.06,
	}),
	lairFrost = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#465D78",
		outdoorAmbient = "#3C4F66",
		fogColor = "#12202F",
		fogEnd = 460,
		atmosphere = { density = 0.4, haze = 0.4, glare = 0, color = "#1D2D3D", decay = "#0D131D" },
		tint = "#D6EEFF",
		saturation = -0.08,
	}),
	crypt = lighting({
		clockTime = 0,
		brightness = 0.9,
		ambient = "#5F5777",
		outdoorAmbient = "#52486E",
		fogColor = "#1D1928",
		fogEnd = 400,
		atmosphere = { density = 0.4, haze = 0, glare = 0, color = "#2A233D", decay = "#161320" },
		tint = "#D8D0FF",
		saturation = -0.25,
	}),
}

local Maps: { [string]: MapDef } = {}

-- S134h: a scaled cave (Data/CaveShapes `scale`, Logic/CavePlan) is listed in plan units and drawn bigger: its size,
-- spawn and dungeon entrance grow with it here, in one place.
local function map(def: MapDef)
	local s = CavePlan.scale(def.id)
	if s ~= 1 then
		def.size = { x = CavePlan.size(def.id, def.size.x), z = CavePlan.size(def.id, def.size.z) }
		def.spawn = { x = def.spawn.x * s, y = def.spawn.y, z = def.spawn.z * s }
		local e = def.dungeonEntrance
		if e then
			def.dungeonEntrance = { x = e.x * s, y = e.y, z = e.z * s }
		end
	end
	Maps[def.id] = def
end

map({
	id = "city",
	nameKey = "map.city.name",
	zone = "green",
	minLevel = 1,
	maxLevel = 100,
	offset = { x = 0, y = 0, z = 0 },
	-- S21: the starting city plan (Data/Town, docs/miasto/MIASTO.md); spawn on the market by the fountain.
	size = { x = Town.city.size, z = Town.city.size },
	spawn = {
		x = Town.city.spawn.x,
		y = TownTerrain.heightAt(Town.city.spawn.x, Town.city.spawn.z) + 4,
		z = Town.city.spawn.z,
	},
	biome = "city",
	lighting = LIGHT.city,
	nightLighting = LIGHT.cityNight,
	dayNight = true,
	-- Studio review 2026-10-21: 7056 parts at start (houses, lamps, the verge, portals since S21's 7000); a warning
	-- only (World/WorldBuilder), raised with ~8% headroom instead of thinning the city (docs/DECYZJE.md).
	maxParts = 7600,
	music = "",
	buildMode = "generated",
	worldMap = { x = 0.2, y = 0.5 },
	links = { "meadows", "duskwood", "ashen", "frostpeak" },
})

-- Region 1
map({
	id = "meadows",
	nameKey = "map.meadows.name",
	zone = "yellow",
	minLevel = 1,
	maxLevel = 20,
	offset = { x = 4000, y = 0, z = 0 },
	size = { x = 1600, z = 1600 },
	spawn = { x = -700, y = 4, z = 0 },
	biome = "grass",
	lighting = LIGHT.meadows,
	-- S26: day and night (Logic/DayCycle) with the areas' mood on top (Data/Ambience).
	dayNight = true,
	nightLighting = LIGHT.meadowsNight,
	-- Creator Store: a calm pastoral loop ("medieval countryside ambient music", ~2-3 min, loops cleanly).
	music = "",
	buildMode = "generated",
	-- S26 server part budget: the S20 map had ~2150 parts; the shaped map may use up to +30%. Studio review
	-- 2026-10-21: 3342 parts at start (the W02 kit models stand in for the trees and rocks with their own meshes, the
	-- props of W12-W30), a warning only: raised with ~10% headroom (docs/DECYZJE.md).
	maxParts = 3700,
	worldMap = { x = 0.42, y = 0.62 },
	links = { "city", "meadows_hideout", "meadows_burrow", "meadows_cave", "duskwood" },
})
map({
	id = "meadows_cave",
	nameKey = "map.meadows_cave.name",
	zone = "red",
	minLevel = 16,
	maxLevel = 20,
	offset = { x = 4000, y = 0, z = 4000 },
	size = { x = 640, z = 640 },
	spawn = { x = -250, y = 4, z = 0 },
	biome = "cave",
	lighting = LIGHT.caveMoss, -- S48
	-- Creator Store: "dark cave ambient music" with soft drones and distant drips, 2-3 min, loops cleanly.
	music = "",
	buildMode = "generated",
	worldMap = { x = 0.51, y = 0.66 },
	links = { "meadows" },
	dungeonEntrance = { x = 250, y = 0, z = 0 },
	dungeonRegion = "meadows",
	-- S48: on the cave engine (Data/CaveShapes); server budget of the dressing's shell + portals and the gate
	maxParts = 1000,
})

-- Region 2
map({
	id = "duskwood",
	nameKey = "map.duskwood.name",
	zone = "yellow",
	minLevel = 20,
	maxLevel = 45,
	offset = { x = 8000, y = 0, z = 0 },
	size = { x = 1600, z = 1600 },
	spawn = { x = -700, y = 4, z = 0 },
	biome = "forest",
	lighting = LIGHT.duskwood,
	-- S45: night and an eternal dusk by day; the areas' moods on top (Data/Ambience).
	dayNight = true,
	nightLighting = LIGHT.duskwoodNight,
	dayClock = { 17.4, 18.3 },
	-- Creator Store: a dark forest loop ("dark fantasy forest ambient music", slow strings / choir, ~3 min, loops).
	music = "",
	buildMode = "generated",
	-- S45: the shaped forest builds in the background; server budget: ~930 big trees (2 parts each), buildings
	-- ~350, portals / cave entrances / signposts ~300 (tests/duskwood.spec: generator shell + 300 <= maxParts).
	-- Studio review 2026-10-21: 3126 parts with the W02 kit models, a warning only: raised with ~10% headroom.
	buildLate = true,
	maxParts = 3450,
	worldMap = { x = 0.58, y = 0.38 },
	links = { "meadows", "city", "duskwood_den", "duskwood_barrow", "duskwood_cave", "ashen" },
})
map({
	id = "duskwood_cave",
	nameKey = "map.duskwood_cave.name",
	zone = "red",
	minLevel = 38,
	maxLevel = 45,
	offset = { x = 8000, y = 0, z = 4000 },
	size = { x = 640, z = 640 },
	spawn = { x = -250, y = 4, z = 0 },
	biome = "crypt",
	lighting = LIGHT.cryptGhost, -- S49
	music = "",
	buildMode = "generated",
	worldMap = { x = 0.67, y = 0.38 },
	links = { "duskwood" },
	dungeonEntrance = { x = 250, y = 0, z = 0 },
	dungeonRegion = "duskwood",
	-- S49: on the cave engine (Data/CaveShapes); server budget of the dressing's shell + portals and the gate
	maxParts = 1000,
})

-- Region 3 and 4 (S11).
map({
	id = "ashen",
	nameKey = "map.ashen.name",
	zone = "yellow",
	minLevel = 45,
	maxLevel = 70,
	offset = { x = 12000, y = 0, z = 0 },
	size = { x = 1600, z = 1600 },
	spawn = { x = -700, y = 4, z = 0 },
	biome = "desert",
	lighting = LIGHT.ashen,
	-- S46: night (lava, cracks and fires light it) and a low afternoon sun by day; the areas' moods on top
	-- (Data/Ambience).
	dayNight = true,
	nightLighting = LIGHT.ashenNight,
	dayClock = { 15.4, 17.2 },
	-- Creator Store: "desert dark ambient loop" with war drums and a duduk, 2-3 min, loops.
	music = "",
	buildMode = "generated",
	-- S46: the shaped wastes build in the background; server budget: ~180 big dead trees (2 parts each), buildings
	-- and props ~850, portals / cave entrances / signposts ~300 (tests/ashen.spec: generator shell + 300 <= maxParts).
	buildLate = true,
	maxParts = 2400,
	worldMap = { x = 0.76, y = 0.6 },
	links = { "duskwood", "city", "ashen_mine", "ashen_lair", "ashen_cave", "frostpeak" },
})
map({
	id = "ashen_cave",
	nameKey = "map.ashen_cave.name",
	zone = "red",
	minLevel = 63,
	maxLevel = 70,
	offset = { x = 12000, y = 0, z = 4000 },
	size = { x = 640, z = 640 },
	spawn = { x = -250, y = 4, z = 0 },
	biome = "cave",
	lighting = LIGHT.caveForge, -- S50
	music = "", -- S50: hint: deep dwarven forge, slow drums and anvils, low choir (Creator Store)
	buildMode = "generated",
	worldMap = { x = 0.85, y = 0.6 },
	maxParts = 1100, -- S50: Deepforge on the cave engine
	links = { "ashen" },
	dungeonEntrance = { x = 250, y = 0, z = 0 },
	dungeonRegion = "ashen",
})
map({
	id = "frostpeak",
	nameKey = "map.frostpeak.name",
	zone = "yellow",
	minLevel = 70,
	maxLevel = 100,
	offset = { x = 16000, y = 0, z = 0 },
	size = { x = 1600, z = 1600 },
	spawn = { x = -700, y = 4, z = 0 },
	biome = "snow",
	lighting = LIGHT.frostpeak,
	-- S47: day and night (Logic/DayCycle) with the areas' moods on top (Data/Ambience); snowfall and the aurora on
	-- the client (Controllers/WorldLifeController).
	dayNight = true,
	nightLighting = LIGHT.frostpeakNight,
	-- Creator Store: "frozen mountains ambient loop", low strings and choir pads, 2-3 min, loops cleanly.
	music = "",
	buildMode = "generated",
	-- S47: the shaped peaks build in the background; server budget: ~330 big trees (2 parts each), buildings and
	-- props ~400, portals / cave entrances / signposts ~300 (tests/frostpeak.spec: generator shell + 300 <= maxParts).
	buildLate = true,
	maxParts = 2600,
	worldMap = { x = 0.9, y = 0.34 },
	links = { "ashen", "city", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" },
})
map({
	id = "frostpeak_cave",
	nameKey = "map.frostpeak_cave.name",
	zone = "red",
	minLevel = 92,
	maxLevel = 100,
	offset = { x = 16000, y = 0, z = 4000 },
	size = { x = 640, z = 640 },
	spawn = { x = -250, y = 4, z = 0 },
	biome = "cave",
	lighting = LIGHT.glacierHeart, -- S51
	maxParts = 1000, -- S51: the Heart of the Glacier on the cave engine
	music = "", -- S51: hint: frozen cavern ambient, deep strings, 2-3 min (Creator Store)
	buildMode = "generated",
	worldMap = { x = 0.98, y = 0.34 },
	links = { "frostpeak" },
	dungeonEntrance = { x = 250, y = 0, z = 0 },
	dungeonRegion = "frostpeak",
})

-- Generated caves (S19, DESIGN §3.5): two per region before the boss cave. Layout: World/Layouts/CaveTemplate,
-- rooms: Logic/CaveGen; size matches CaveGen.SIZE.
for _, cave in
	{
		{
			id = "meadows_hideout",
			region = "meadows",
			i = 1,
			row = 12000,
			min = 7,
			max = 12,
			biome = "cave",
			wx = 0.42,
			wy = 0.71,
			light = "caveSmugglers", -- S48
		},
		{
			id = "meadows_burrow",
			region = "meadows",
			i = 1,
			row = 16000,
			min = 12,
			max = 16,
			biome = "cave",
			wx = 0.47,
			wy = 0.53,
			light = "caveWarren", -- S48
		},
		{
			id = "duskwood_den",
			region = "duskwood",
			i = 2,
			row = 12000,
			min = 21,
			max = 31,
			biome = "cave",
			wx = 0.53,
			wy = 0.29,
			light = "caveDen", -- S49
		},
		{
			id = "duskwood_barrow",
			region = "duskwood",
			i = 2,
			row = 16000,
			min = 31,
			max = 38,
			biome = "crypt",
			wx = 0.6,
			wy = 0.29,
			light = "barrowViolet", -- S49
		},
		{
			id = "ashen_mine",
			region = "ashen",
			i = 3,
			row = 12000,
			min = 46, -- S93: Elites from 46
			max = 56,
			biome = "cave",
			wx = 0.69,
			wy = 0.51,
			light = "caveMine", -- S50
		},
		{
			id = "ashen_lair",
			region = "ashen",
			i = 3,
			row = 16000,
			min = 56,
			max = 63,
			biome = "cave",
			wx = 0.81,
			wy = 0.51,
			light = "caveLair", -- S50
		},
		{
			id = "frostpeak_grotto",
			region = "frostpeak",
			i = 4,
			row = 12000,
			min = 71, -- S94: Elites from 71
			max = 83,
			biome = "cave",
			wx = 0.86,
			wy = 0.25,
			light = "caveIce", -- S51
		},
		{
			id = "frostpeak_hold",
			region = "frostpeak",
			i = 4,
			row = 16000,
			min = 83,
			max = 92,
			biome = "crypt",
			wx = 0.94,
			wy = 0.25,
			light = "holdFrozen", -- S51
		},
	}
do
	map({
		id = cave.id,
		nameKey = `map.{cave.id}.name`,
		zone = "red",
		minLevel = cave.min,
		maxLevel = cave.max,
		offset = { x = 4000 * cave.i, y = 0, z = cave.row },
		size = { x = 480, z = 480 },
		spawn = { x = -185, y = 4, z = 0 },
		biome = cave.biome :: Biome,
		lighting = LIGHT[cave.light], -- S48: a preset per cave (the Meadows' caves on the engine have their own)
		music = "",
		buildMode = "generated",
		worldMap = { x = cave.wx, y = cave.wy },
		links = { cave.region },
		-- S48: caves on the cave engine keep a server part budget (the Meadows' two: 700)
		maxParts = if cave.region == "meadows" or cave.region == "duskwood"
			then 700
			elseif cave.id == "ashen_mine" then 750 -- S50
			elseif cave.id == "ashen_lair" then 700
			elseif cave.id == "frostpeak_grotto" then 650 -- S51
			elseif cave.id == "frostpeak_hold" then 800
			else nil,
	})
end

-- Boss chambers (DESIGN §16).
for i, dungeon in
	{
		{ region = "meadows", level = 20 },
		{ region = "duskwood", level = 45 },
		{ region = "ashen", level = 70 },
		{ region = "frostpeak", level = 100 },
	}
do
	map({
		id = `dungeon_{dungeon.region}`,
		nameKey = `map.dungeon_{dungeon.region}.name`,
		zone = "red",
		minLevel = dungeon.level - Bosses.ENTRY_GAP, -- S134c: the dungeon opens 10 levels below the boss
		maxLevel = dungeon.level,
		offset = { x = 4000 * i, y = 0, z = 8000 },
		size = { x = 300, z = 300 },
		spawn = { x = 0, y = 4, z = 60 },
		biome = "dungeon",
		lighting = if dungeon.region == "duskwood"
			then LIGHT.dungeonTomb -- S49
			elseif dungeon.region == "ashen" then LIGHT.dungeonFurnace -- S50
			elseif dungeon.region == "frostpeak" then LIGHT.lairFrost -- S51
			elseif dungeon.region == "meadows" then LIGHT.dungeonGoblin -- S48
			else LIGHT.cave,
		music = "",
		buildMode = "generated",
		worldMap = { x = 0, y = 0 },
		links = {},
		-- S48/S49: Grimrok's Chamber and the Tomb of Morvane on the cave engine
		maxParts = if dungeon.region == "meadows" or dungeon.region == "duskwood"
			then 450
			elseif dungeon.region == "ashen" then 500 -- S50: Azgor's Furnace
			else 450, -- S51: Vaelgrath's Lair
	})
end

-- S127: the arena server map (DESIGN-17 §6): sand and stands only (Data/ArenaPit), built on reserved arena and
-- tournament servers instead of the whole world. Far from every other map (z = -8000, tests/data.spec).
map({
	id = "arena_pit",
	nameKey = "map.arena_pit.name",
	zone = "green",
	minLevel = 20,
	maxLevel = 100,
	offset = { x = 0, y = 0, z = -8000 },
	-- S130: as large as the largest layout (the tournament's four fields)
	size = { x = ArenaPit.maxSize(), z = ArenaPit.maxSize() },
	spawn = { x = 0, y = 4, z = 60 }, -- on the stand by the way out
	biome = "grass",
	lighting = LIGHT.city,
	music = "",
	buildMode = "generated",
	worldMap = { x = 0, y = 0 },
	links = {},
	maxParts = 6000, -- S130: four Ristalle stands on a tournament server
	serverModes = { "arena", "tournament" },
	hidden = true,
})

return table.freeze({
	byId = Maps,
	get = function(id: string): MapDef?
		return Maps[id]
	end,
})
