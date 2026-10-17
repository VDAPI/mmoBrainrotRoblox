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
	-- W02: painted terrain materials (MaterialVariant in MaterialService) shown on this map: base material name ->
	-- variant name (nil = the plain materials). The client sets them with SetBaseMaterialOverride on entering the map.
	materials: { [string]: string }?,
}

local UNDERGROUND = { cave = true, crypt = true, dungeon = true }

-- W01 (Studio): bloom from 1.15 up: under Future the sunlit sand, snow and pale paving pass 1.0 and bloomed white;
-- lamps, runes and skill effects stay far above it.
local OUTDOOR: Look = {
	clock = nil,
	sunColor = "#FFFFFF",
	bloom = { intensity = 0.45, size = 24, threshold = 1.15 },
	sunRays = 0.05,
	contrast = 0.08,
	brightness = 0,
	clouds = { cover = 0.45, density = 0.6, color = "#F4F4F4" },
	farBlur = 0.12,
	sky = nil,
}

-- Underground: the light comes from lamps, fires, moss and crystals (Data/Maps presets, RegionLightController); a
-- stronger bloom makes them glow, a little contrast keeps the rooms readable. W01 (Studio): +0.04 brightness and more
-- contrast lift the near-black walls without washing the lamps out.
local UNDER: Look = {
	clock = nil,
	sunColor = "#FFFFFF",
	bloom = { intensity = 0.55, size = 20, threshold = 0.9 },
	sunRays = 0,
	contrast = 0.1,
	brightness = 0.04,
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

-- Per map (docs/WYGLAD.md §4.2). The city keeps its day and night cycle (clock nil). W01 (Studio): hours and colours
-- tuned on screenshots (docs/wyglad/SESJE-W.md "W01 (Studio)"); the presets' light and air are in Data/Maps.
local BY_MAP: { [string]: Look } = {
	city = with(OUTDOOR, {
		sunColor = "#FFE6C4",
		contrast = 0.14,
		brightness = -0.03,
		clouds = { cover = 0.4, density = 0.55, color = "#F6EFE6" },
	}),
	-- Late afternoon, golden sun (16.6 still looked like noon: the sun is low enough from 17).
	meadows = with(OUTDOOR, {
		clock = 17,
		sunColor = "#FFB46A",
		sunRays = 0.08,
		contrast = 0.12,
		clouds = { cover = 0.55, density = 0.5, color = "#FFE8CC" },
		-- W02: the painted rock of the border mountains (the generated grass and dirt looked worse than the plain ones)
		materials = { Rock = "VaelthornRock" },
	}),
	-- Overcast day under a grey sky, shafts through the crowns (the sun high enough to reach between the trees).
	duskwood = with(OUTDOOR, {
		clock = 15.5,
		sunColor = "#E6DCC0",
		sunRays = 0.12,
		contrast = 0.14,
		clouds = { cover = 0.85, density = 0.8, color = "#7A8078" },
		sky = "overcast",
	}),
	-- Sunset through dust, hot air.
	ashen = with(OUTDOOR, {
		clock = 17.2,
		sunColor = "#FF9A50",
		sunRays = 0.12,
		contrast = 0.16,
		bloom = { intensity = 0.5, size = 24, threshold = 1.15 },
		clouds = { cover = 0.25, density = 0.5, color = "#E8A27A" },
		sky = "dustSunset",
	}),
	-- Cold morning, low sun: warm light on the snow, blue shadows.
	frostpeak = with(OUTDOOR, {
		clock = 7.6,
		sunColor = "#FFE2C8",
		sunRays = 0.08,
		contrast = 0.16,
		brightness = -0.02,
		clouds = { cover = 0.45, density = 0.55, color = "#FFFFFF" },
	}),
	-- Underground rooms that stayed too dark with the shared lift (W01, Studio): the Wyvern's roosts, the tomb of
	-- Morvane and Azgor's furnace (their lamps light the edges only).
	ashen_lair = with(UNDER, { brightness = 0.08, contrast = 0.12 }),
	dungeon_duskwood = with(UNDER, { brightness = 0.07 }),
	dungeon_ashen = with(UNDER, { brightness = 0.06 }),
}

local MapLooks = {}

MapLooks.OUTDOOR = OUTDOOR
MapLooks.UNDERGROUND_LOOK = UNDER
MapLooks.byMap = BY_MAP

-- W12 (docs/wyglad/mapy/miasto.md A7): windows at night: about a third glow, a warm amber instead of the yellow neon.
MapLooks.windows = { share = 0.35, color = "#F0A050" }

-- W12: the sun's colour over the city's day (hour, colour), blended between the points; used on maps with the day and
-- night cycle instead of `sunColor` (dawn warm orange, a creamy day, a deep evening gold).
MapLooks.sunByHour = {
	{ 5, "#FFC090" },
	{ 8, "#FFD8B0" },
	{ 10, "#FFE6C4" },
	{ 16, "#FFE6C4" },
	{ 18, "#FFB878" },
	{ 19.5, "#FF9A60" },
} :: { { any } }

-- The sun's colour at an hour of the cycle (MapLooks.sunByHour).
function MapLooks.sunAt(hour: number): string
	local list = MapLooks.sunByHour
	if hour <= list[1][1] then
		return list[1][2]
	end
	for i = 2, #list do
		local a, b = list[i - 1], list[i]
		if hour <= b[1] then
			local t = (hour - a[1]) / (b[1] - a[1])
			local function channel(hex: string, at: number): number
				return tonumber(string.sub(hex, at, at + 1), 16) :: number
			end
			local out = "#"
			for _, at in { 2, 4, 6 } do
				local v = channel(a[2], at) + (channel(b[2], at) - channel(a[2], at)) * t
				out ..= string.format("%02X", math.floor(v + 0.5))
			end
			return out
		end
	end
	return list[#list][2]
end

-- W02: every base material some map overrides (the client clears the ones the current map does not set).
function MapLooks.overriddenMaterials(): { string }
	local seen: { [string]: boolean } = {}
	local list = {}
	for _, look in BY_MAP do
		local materials: { [string]: string } = look.materials or {}
		for base in materials do
			if not seen[base] then
				seen[base] = true
				table.insert(list, base)
			end
		end
	end
	table.sort(list)
	return list
end

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
