--!strict
-- World maps (DESIGN §3.2, ARCHITECTURE §8). Every map from the design is listed so portals, stones and the
-- world map are complete; only maps with a layout (`buildMode = "generated"` and a World/Layouts module) are
-- built. Offsets keep maps >= 3000 studs apart. Lighting/atmosphere are applied on the client when the
-- player enters the map (EnvironmentController).

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
	city = lighting({ clockTime = 15, fogEnd = 1200 }),
	-- Night in the city (S21): cool moonlight, dark blue fog; windows, lamps and fires do the rest.
	cityNight = lighting({
		clockTime = 0,
		brightness = 0.6,
		ambient = "#2A2E40",
		outdoorAmbient = "#3A4058",
		fogColor = "#1A2030",
		fogEnd = 700,
		atmosphere = { density = 0.34, haze = 1.2, glare = 0, color = "#2A3248", decay = "#141826" },
		tint = "#D8E0FF",
		saturation = -0.15,
	}),
	meadows = lighting({ clockTime = 13, saturation = 0.12, fogColor = "#D8E6C9" }),
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
	duskwood = lighting({
		clockTime = 18.2,
		brightness = 1.2,
		ambient = "#3A3448",
		outdoorAmbient = "#4A4458",
		fogColor = "#3A3F4A",
		fogEnd = 420,
		atmosphere = { density = 0.45, haze = 2.4, glare = 0, color = "#5A5F6E", decay = "#2A2A3A" },
		tint = "#D8D0F0",
		saturation = -0.15,
	}),
	ashen = lighting({
		clockTime = 16,
		ambient = "#7A5A4A",
		outdoorAmbient = "#9A6A4A",
		fogColor = "#C98A5A",
		fogEnd = 700,
		atmosphere = { density = 0.4, haze = 2, glare = 0.4, color = "#D9A27A", decay = "#7A3A2A" },
		tint = "#FFE2C9",
		saturation = 0,
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
	frostpeak = lighting({
		clockTime = 11,
		brightness = 2.6,
		ambient = "#7A8AA0",
		outdoorAmbient = "#A8B8D0",
		fogColor = "#E4F0F7",
		fogEnd = 600,
		atmosphere = { density = 0.42, haze = 1.6, glare = 0.5, color = "#E4F0F7", decay = "#9FB6C9" },
		tint = "#E8F4FF",
		saturation = -0.1,
	}),
	cave = lighting({
		clockTime = 0,
		brightness = 0.4,
		ambient = "#3A3F38",
		outdoorAmbient = "#2A2E2A",
		fogColor = "#151816",
		fogEnd = 260,
		atmosphere = { density = 0.55, haze = 0, glare = 0, color = "#202420", decay = "#101210" },
		tint = "#E0F0D8",
		saturation = -0.1,
	}),
	-- S48: presets of the caves on the engine: very dark ambient (never darker than ~#262A26) and short fog in the
	-- cave's colour; the light of the rooms comes from their lamps, fires, moss and crystals (RegionLightController)
	caveMoss = lighting({
		clockTime = 0,
		brightness = 0.35,
		ambient = "#2E3A2E",
		outdoorAmbient = "#283028",
		fogColor = "#101A12",
		fogEnd = 240,
		atmosphere = { density = 0.55, haze = 0.4, glare = 0, color = "#18241A", decay = "#0C140E" },
		tint = "#D8F4D0",
		saturation = -0.05,
	}),
	caveSmugglers = lighting({
		clockTime = 0,
		brightness = 0.35,
		ambient = "#34302A",
		outdoorAmbient = "#2A2826",
		fogColor = "#14120F",
		fogEnd = 230,
		atmosphere = { density = 0.55, haze = 0.2, glare = 0, color = "#201C18", decay = "#100E0C" },
		tint = "#F4E4D0",
		saturation = -0.08,
	}),
	caveWarren = lighting({
		clockTime = 0,
		brightness = 0.35,
		ambient = "#36302A",
		outdoorAmbient = "#2C2824",
		fogColor = "#16120E",
		fogEnd = 210,
		atmosphere = { density = 0.58, haze = 0.6, glare = 0, color = "#221C16", decay = "#120E0A" },
		tint = "#F0E4C8",
		saturation = -0.06,
	}),
	dungeonGoblin = lighting({
		clockTime = 0,
		brightness = 0.4,
		ambient = "#3A2E26",
		outdoorAmbient = "#30261E",
		fogColor = "#1A100C",
		fogEnd = 260,
		atmosphere = { density = 0.5, haze = 0.6, glare = 0, color = "#2A1810", decay = "#140C08" },
		tint = "#FFD8B8",
		saturation = 0.02,
	}),
	-- S49: presets of Duskwood's caves on the engine
	caveDen = lighting({
		clockTime = 0,
		brightness = 0.32,
		ambient = "#262A30",
		outdoorAmbient = "#22262A",
		fogColor = "#0C0F12",
		fogEnd = 200,
		atmosphere = { density = 0.58, haze = 0.3, glare = 0, color = "#141820", decay = "#0A0C10" },
		tint = "#D8E4F0",
		saturation = -0.12,
	}),
	barrowViolet = lighting({
		clockTime = 0,
		brightness = 0.32,
		ambient = "#2A2434",
		outdoorAmbient = "#24202E",
		fogColor = "#0E0A14",
		fogEnd = 180,
		atmosphere = { density = 0.6, haze = 0.4, glare = 0, color = "#1A1424", decay = "#0C0A12" },
		tint = "#E0D0FF",
		saturation = -0.2,
	}),
	cryptGhost = lighting({
		clockTime = 0,
		brightness = 0.32,
		ambient = "#262C30",
		outdoorAmbient = "#22282C",
		fogColor = "#0A0E10",
		fogEnd = 220,
		atmosphere = { density = 0.58, haze = 0.5, glare = 0, color = "#141C20", decay = "#0A0E10" },
		tint = "#D0F0E8",
		saturation = -0.25,
	}),
	dungeonTomb = lighting({
		clockTime = 0,
		brightness = 0.36,
		ambient = "#282236",
		outdoorAmbient = "#221E2E",
		fogColor = "#0C0A12",
		fogEnd = 260,
		atmosphere = { density = 0.55, haze = 0.5, glare = 0, color = "#181424", decay = "#0C0A12" },
		tint = "#DCD0FF",
		saturation = -0.15,
	}),
	-- S50: presets of the Ashen Wastes' caves on the engine
	caveMine = lighting({
		clockTime = 0,
		brightness = 0.34,
		ambient = "#2E2A26",
		outdoorAmbient = "#28241F",
		fogColor = "#16120E",
		fogEnd = 200,
		atmosphere = { density = 0.56, haze = 0.8, glare = 0, color = "#2A2018", decay = "#120E0A" },
		tint = "#FFE8D0",
		saturation = -0.08,
	}),
	caveLair = lighting({
		clockTime = 0,
		brightness = 0.36,
		ambient = "#34241E",
		outdoorAmbient = "#2E201A",
		fogColor = "#22100A",
		fogEnd = 230,
		atmosphere = { density = 0.55, haze = 1.2, glare = 0, color = "#3A1A10", decay = "#180A06" },
		tint = "#FFD8C0",
		saturation = 0.04,
	}),
	caveForge = lighting({
		clockTime = 0,
		brightness = 0.34,
		ambient = "#2C2420",
		outdoorAmbient = "#261E1A",
		fogColor = "#140A06",
		fogEnd = 280,
		atmosphere = { density = 0.5, haze = 0.9, glare = 0, color = "#2A140A", decay = "#100806" },
		tint = "#FFE0C8",
		saturation = 0.06,
	}),
	dungeonFurnace = lighting({
		clockTime = 0,
		brightness = 0.38,
		ambient = "#3A2620",
		outdoorAmbient = "#32201A",
		fogColor = "#2A100A",
		fogEnd = 300,
		atmosphere = { density = 0.5, haze = 1.4, glare = 0, color = "#401A0C", decay = "#1A0A06" },
		tint = "#FFD8C0",
		saturation = 0.08,
	}),
	-- S51: presets of the Frost Peaks' caves on the engine
	caveIce = lighting({
		clockTime = 0,
		brightness = 0.36,
		ambient = "#26303A",
		outdoorAmbient = "#222A34",
		fogColor = "#0E161E",
		fogEnd = 240,
		atmosphere = { density = 0.55, haze = 0.4, glare = 0, color = "#16222C", decay = "#0A1016" },
		tint = "#D8ECFF",
		saturation = -0.1,
	}),
	holdFrozen = lighting({
		clockTime = 0,
		brightness = 0.34,
		ambient = "#262C36",
		outdoorAmbient = "#222830",
		fogColor = "#0C1016",
		fogEnd = 200,
		atmosphere = { density = 0.58, haze = 0.5, glare = 0, color = "#141A24", decay = "#0A0C12" },
		tint = "#D4E2F4",
		saturation = -0.2,
	}),
	glacierHeart = lighting({
		clockTime = 0,
		brightness = 0.36,
		ambient = "#22303C",
		outdoorAmbient = "#1E2A34",
		fogColor = "#08141C",
		fogEnd = 260,
		atmosphere = { density = 0.55, haze = 0.5, glare = 0, color = "#102028", decay = "#060E14" },
		tint = "#CCF2FF",
		saturation = -0.05,
	}),
	lairFrost = lighting({
		clockTime = 0,
		brightness = 0.38,
		ambient = "#24303E",
		outdoorAmbient = "#202A36",
		fogColor = "#0A121A",
		fogEnd = 280,
		atmosphere = { density = 0.52, haze = 0.6, glare = 0, color = "#121C26", decay = "#080C12" },
		tint = "#D6EEFF",
		saturation = -0.08,
	}),
	crypt = lighting({
		clockTime = 0,
		brightness = 0.3,
		ambient = "#2E2A3A",
		outdoorAmbient = "#221E2E",
		fogColor = "#100E16",
		fogEnd = 220,
		atmosphere = { density = 0.6, haze = 0, glare = 0, color = "#1A1626", decay = "#0E0C14" },
		tint = "#D8D0FF",
		saturation = -0.25,
	}),
}

local Maps: { [string]: MapDef } = {}

local function map(def: MapDef)
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
	maxParts = 7000,
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
	-- S26 server part budget: the S20 map had ~2150 parts; the shaped map may use up to +30%.
	maxParts = 2800,
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
	buildLate = true,
	maxParts = 3000,
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
			min = 24,
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
			min = 49,
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
			min = 74,
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
		minLevel = dungeon.level - 5,
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

return table.freeze({
	byId = Maps,
	get = function(id: string): MapDef?
		return Maps[id]
	end,
})
