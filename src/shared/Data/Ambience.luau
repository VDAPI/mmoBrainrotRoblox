--!strict
-- Mood of the monster areas (S26): light and sound per area on top of the map's lighting and the day and night
-- cycle (Data/Maps, Logic/DayCycle). AmbienceController (client) blends from one area's mood to the next over ~2.5 s;
-- outside every area the map's own entry (`maps`) applies, else nothing.
--
-- Light (all optional; identity = no change):
--   fogScale   multiplies Lighting.FogEnd (0.6 = fog closer)       brightness  multiplies Lighting.Brightness
--   fogColor   colour the fog leans to, by fogMix (0..1)          haze        added to Atmosphere.Haze
--   tint       colour grading tint the scene leans to, by tintMix  density     added to Atmosphere.Density
--   saturation added to the colour grading saturation
--
-- Sound: loops by day and by night, at most 3 at a time, crossfaded, volume from the "Ambience" option. Sound ids
-- are NOT filled in (no guessing): every entry says what to look for in the Creator Store (`hint`); entries with an
-- empty id are skipped. `points` are positional loops (waterfall, fires, drums) heard within `radius` studs.

export type Sound = { id: string, volume: number, hint: string }

export type Mood = {
	fogScale: number?,
	fogColor: string?,
	fogMix: number?,
	tint: string?,
	tintMix: number?,
	saturation: number?,
	brightness: number?,
	haze: number?,
	density: number?,
	sounds: { day: { Sound }, night: { Sound } },
}

export type Point = {
	x: number,
	z: number,
	radius: number,
	sound: Sound,
	night: boolean?, -- nil = day and night; true = only at night; false = only by day
}

local function s(hint: string, volume: number?): Sound
	return { id = "", volume = volume or 0.5, hint = hint }
end

-- Shared loops (one Sound each; the same id in two areas keeps playing across the border).
local BIRDS = s("birds meadow loop (songbirds, daytime, countryside)", 0.45)
local WIND_GRASS = s("wind in grass loop (soft, steady)", 0.35)
local NIGHT_CRICKETS = s("crickets night loop (field, gentle)", 0.4)
local OWL = s("owl hooting night forest loop (sparse)", 0.3)
local WIND_HILLS = s("wind on hills loop (gusts, open terrain)", 0.4)
local WOLF_HOWL = s("wolf howl distant night loop (several howls, long gaps)", 0.35)
local FROGS = s("frogs croaking swamp loop (toads, marsh)", 0.5)
local MARSH_NIGHT = s("swamp night loop (frogs, insects, water)", 0.45)
local FOREST_DAY = s("forest ambience day loop (birds, leaves rustling, woodpecker)", 0.45)
local FOREST_NIGHT = s("forest night loop (owls, insects, branches)", 0.4)
local CROWS = s("crows cawing loop (several crows, field)", 0.45)
local FIRE_DISTANT = s("distant campfire crackle loop", 0.2)
local ROAD_DAY = s("countryside road ambience loop (birds, distant cart, wind)", 0.35)
local QUARRY = s("quarry ambience loop (dripping, distant pickaxe, gravel)", 0.35)
local CAVE_WIND = s("cave wind low drone loop", 0.25)
local GOBLIN_CAMP = s("goblin camp ambience loop (chatter, grunts, fire)", 0.4)
local DRUMS_NIGHT = s("tribal drums distant night loop (slow)", 0.35)
local RAVINE = s("mountain ravine ambience loop (wind, distant water, birds of prey)", 0.4)
local STREAM = s("stream water flowing loop (small brook)", 0.35)

local areas: { [string]: Mood } = {
	-- bright sunny glade
	meadows_rabbitfields = {
		tint = "#FFF4DC",
		tintMix = 0.35,
		saturation = 0.08,
		brightness = 1.05,
		sounds = { day = { BIRDS, WIND_GRASS }, night = { NIGHT_CRICKETS, OWL } },
	},
	-- windy, open, a little cooler
	meadows_wolfhills = {
		tint = "#EEF2FF",
		tintMix = 0.25,
		saturation = -0.02,
		haze = 0.3,
		sounds = { day = { WIND_HILLS, BIRDS }, night = { WIND_HILLS, WOLF_HOWL } },
	},
	-- misty, greenish
	meadows_toadmire = {
		fogScale = 0.55,
		fogColor = "#B8C8A8",
		fogMix = 0.6,
		tint = "#E6F2D8",
		tintMix = 0.5,
		saturation = -0.06,
		haze = 1.2,
		density = 0.08,
		sounds = { day = { FROGS, BIRDS }, night = { MARSH_NIGHT, FROGS } },
	},
	-- darker under the trees
	meadows_oldforest = {
		fogScale = 0.75,
		fogColor = "#7A8A6A",
		fogMix = 0.4,
		tint = "#E2ECD8",
		tintMix = 0.45,
		brightness = 0.82,
		saturation = -0.04,
		haze = 0.6,
		sounds = { day = { FOREST_DAY, STREAM }, night = { FOREST_NIGHT, OWL } },
	},
	-- faded, greyish, smoke in the air
	meadows_crowfield = {
		fogScale = 0.85,
		fogColor = "#B4ACA0",
		fogMix = 0.45,
		tint = "#EDE6DA",
		tintMix = 0.5,
		saturation = -0.28,
		brightness = 0.95,
		haze = 0.8,
		sounds = { day = { CROWS, WIND_GRASS, FIRE_DISTANT }, night = { NIGHT_CRICKETS, CROWS } },
	},
	meadows_banditroad = {
		tint = "#FFF0DA",
		tintMix = 0.3,
		saturation = 0.02,
		sounds = { day = { ROAD_DAY, BIRDS }, night = { NIGHT_CRICKETS, FIRE_DISTANT } },
	},
	-- dusty, warm grey
	meadows_diggings = {
		fogScale = 0.85,
		fogColor = "#B8A890",
		fogMix = 0.35,
		tint = "#F2EAD8",
		tintMix = 0.35,
		saturation = -0.12,
		haze = 0.6,
		sounds = { day = { QUARRY, WIND_HILLS }, night = { CAVE_WIND, NIGHT_CRICKETS } },
	},
	-- smoky, earthy green-brown
	meadows_goblincamp = {
		fogScale = 0.8,
		fogColor = "#8A8A62",
		fogMix = 0.4,
		tint = "#EAEAD0",
		tintMix = 0.4,
		saturation = -0.08,
		haze = 0.9,
		sounds = { day = { GOBLIN_CAMP, WIND_HILLS }, night = { DRUMS_NIGHT, GOBLIN_CAMP } },
	},
	-- cool and clear, a little blue
	meadows_bearridge = {
		fogScale = 0.9,
		fogColor = "#B8C8D8",
		fogMix = 0.45,
		tint = "#E6EEFF",
		tintMix = 0.45,
		saturation = -0.06,
		brightness = 0.95,
		sounds = { day = { RAVINE, BIRDS }, night = { RAVINE, WOLF_HOWL } },
	},
}

-- Map-wide moods outside every area (paths between the areas keep the map's plain light).
local maps: { [string]: Mood } = {
	meadows = { sounds = { day = { BIRDS, WIND_GRASS }, night = { NIGHT_CRICKETS } } },
}

-- Positional loops (map-relative).
local points: { [string]: { Point } } = {
	meadows = {
		{ x = 742, z = 268, radius = 160, sound = s("waterfall loop (medium, steady roar)", 0.7) },
		{ x = 600, z = 266, radius = 70, sound = STREAM },
		{ x = 250, z = 214, radius = 70, sound = STREAM },
		{ x = -100, z = 188, radius = 70, sound = STREAM },
		{ x = -246, z = 120, radius = 60, sound = STREAM },
		{ x = 40, z = -150, radius = 70, sound = s("fire embers crackling loop (smouldering, quiet)", 0.4) },
		{ x = 350, z = 470, radius = 80, sound = s("campfire crackle loop", 0.45) },
		{ x = 665, z = -410, radius = 150, sound = s("tribal drums loop (goblin camp, rhythmic)", 0.45), night = true },
		{ x = -652, z = -196, radius = 90, sound = s("farm animals loop (sheep, hens, distant)", 0.4), night = false },
		{ x = -688, z = -182, radius = 30, sound = s("bees buzzing loop (hive)", 0.35), night = false },
		{ x = -480, z = 520, radius = 140, sound = s("lake shore water lapping loop", 0.35) },
	},
}

local Ambience = {
	areas = areas,
	maps = maps,
	points = points,
	MAX_LOOPS = 3,
	BLEND = 2.5, -- seconds to blend from one mood to the next
}

-- Mood of an area, else of the map (nil = plain map light, no loops).
function Ambience.moodOf(mapId: string, areaId: string?): Mood?
	return (areaId and areas[areaId]) or maps[mapId]
end

-- Every sound entry (tests, the owner's list of ids to fill in).
function Ambience.allSounds(): { Sound }
	local out: { Sound } = {}
	local seen: { [Sound]: boolean } = {}
	local function add(sound: Sound)
		if not seen[sound] then
			seen[sound] = true
			table.insert(out, sound)
		end
	end
	for _, list in { areas, maps } :: { { [string]: Mood } } do
		for _, mood in list do
			for _, sound in mood.sounds.day do
				add(sound)
			end
			for _, sound in mood.sounds.night do
				add(sound)
			end
		end
	end
	for _, list in points do
		for _, p in list do
			add(p.sound)
		end
	end
	return out
end

return table.freeze(Ambience)
