--!strict
-- W01: the look of every map on top of its Data/Maps lighting preset (docs/WYGLAD.md §1, §4.2): a fixed hour (the owner
-- wants a fixed time and mood per map, the day and night cycle only in the city), the sun's colour, post effects
-- (bloom, sun rays, depth of field, colour contrast) and clouds. Defaults per biome, overrides per map id. The client
-- (WorldController) scales the post effects by the graphics level (Config.Graphics). Looks only, no gameplay.

local Maps = require("./Maps")

export type Bloom = { intensity: number, size: number, threshold: number }

export type Clouds = { cover: number, density: number, color: string }

export type Look = {
	-- Fixed clock time (0..24): no day and night on this map. nil = the map's own clock (its preset, or the cycle).
	clock: number?,
	-- Lighting.ColorShift_Top: the colour of the sunlit side ("#FFFFFF" = neutral).
	sunColor: string,
	bloom: Bloom,
	-- SunRaysEffect intensity (0 = none; underground maps never).
	sunRays: number,
	-- ColorCorrection contrast and brightness added on top of the preset's tint and saturation.
	contrast: number,
	brightness: number,
	-- Terrain Clouds (nil = none; underground maps never).
	clouds: Clouds?,
	-- DepthOfField far blur (0 = none); only on the high graphics level on a computer.
	farBlur: number,
	-- Sky key in ReplicatedStorage.Assets.Sky (nil or missing = the default sky).
	sky: string?,
}

local UNDERGROUND = { cave = true, crypt = true, dungeon = true }

local OUTDOOR: Look = {
	clock = nil,
	sunColor = "#FFFFFF",
	bloom = { intensity = 0.4, size = 24, threshold = 0.95 },
	sunRays = 0.05,
	contrast = 0.08,
	brightness = 0,
	clouds = { cover = 0.45, density = 0.6, color = "#F4F4F4" },
	farBlur = 0.12,
	sky = nil,
}

-- Underground: the light comes from lamps, fires, moss and crystals (Data/Maps presets, RegionLightController); a
-- stronger bloom makes them glow, a little contrast keeps the rooms readable.
local UNDER: Look = {
	clock = nil,
	sunColor = "#FFFFFF",
	bloom = { intensity = 0.55, size = 20, threshold = 0.9 },
	sunRays = 0,
	contrast = 0.06,
	brightness = 0,
	clouds = nil,
	farBlur = 0,
	sky = nil,
}

local function with(base: Look, overrides: { [string]: any }): Look
	local look = table.clone(base) :: any
	for key, value in overrides do
		look[key] = value
	end
	return look :: Look
end

-- Per map (docs/WYGLAD.md §4.2). The city keeps its day and night cycle (clock nil).
local BY_MAP: { [string]: Look } = {
	city = with(OUTDOOR, {
		sunColor = "#FFE6C4",
		contrast = 0.1,
		clouds = { cover = 0.4, density = 0.55, color = "#F6EFE6" },
	}),
	-- Late afternoon, golden sun.
	meadows = with(OUTDOOR, {
		clock = 16.6,
		sunColor = "#FFC98A",
		sunRays = 0.08,
		contrast = 0.1,
		clouds = { cover = 0.42, density = 0.55, color = "#FFF2DE" },
	}),
	-- Overcast, light shafts through the crowns (the eternal dusk of S45 stays in the preset's colours).
	duskwood = with(OUTDOOR, {
		clock = 17.8,
		sunColor = "#D8C8FF",
		sunRays = 0.12,
		contrast = 0.12,
		clouds = { cover = 0.8, density = 0.75, color = "#8A8C9A" },
	}),
	-- Sunset, hot air.
	ashen = with(OUTDOOR, {
		clock = 17.6,
		sunColor = "#FF9A5A",
		sunRays = 0.1,
		contrast = 0.12,
		bloom = { intensity = 0.5, size = 24, threshold = 0.92 },
		clouds = { cover = 0.3, density = 0.5, color = "#E8A27A" },
	}),
	-- Cold morning, low sun.
	frostpeak = with(OUTDOOR, {
		clock = 8.5,
		sunColor = "#CFE4FF",
		sunRays = 0.07,
		contrast = 0.1,
		clouds = { cover = 0.5, density = 0.6, color = "#FFFFFF" },
	}),
}

local MapLooks = {}

MapLooks.OUTDOOR = OUTDOOR
MapLooks.UNDERGROUND_LOOK = UNDER
MapLooks.byMap = BY_MAP

function MapLooks.isUnderground(biome: string): boolean
	return UNDERGROUND[biome] == true
end

-- The look of a map: its own entry, else the default of its biome (underground or outdoor).
function MapLooks.of(mapId: string): Look
	local own = BY_MAP[mapId]
	if own then
		return own
	end
	local map = Maps.get(mapId)
	if map and UNDERGROUND[map.biome] then
		return UNDER
	end
	return OUTDOOR
end

return table.freeze(MapLooks)
