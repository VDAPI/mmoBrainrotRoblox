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
	music = "",
	buildMode = "generated",
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
	lighting = LIGHT.cave,
	music = "",
	buildMode = "generated",
	worldMap = { x = 0.51, y = 0.66 },
	links = { "meadows" },
	dungeonEntrance = { x = 250, y = 0, z = 0 },
	dungeonRegion = "meadows",
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
	music = "",
	buildMode = "generated",
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
	lighting = LIGHT.crypt,
	music = "",
	buildMode = "generated",
	worldMap = { x = 0.67, y = 0.38 },
	links = { "duskwood" },
	dungeonEntrance = { x = 250, y = 0, z = 0 },
	dungeonRegion = "duskwood",
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
	music = "",
	buildMode = "generated",
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
	lighting = LIGHT.cave,
	music = "",
	buildMode = "generated",
	worldMap = { x = 0.85, y = 0.6 },
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
	music = "",
	buildMode = "generated",
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
	lighting = LIGHT.cave,
	music = "",
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
		lighting = if cave.biome == "crypt" then LIGHT.crypt else LIGHT.cave,
		music = "",
		buildMode = "generated",
		worldMap = { x = cave.wx, y = cave.wy },
		links = { cave.region },
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
		lighting = if dungeon.region == "duskwood" then LIGHT.crypt else LIGHT.cave,
		music = "",
		buildMode = "generated",
		worldMap = { x = 0, y = 0 },
		links = {},
	})
end

return table.freeze({
	byId = Maps,
	get = function(id: string): MapDef?
		return Maps[id]
	end,
})
