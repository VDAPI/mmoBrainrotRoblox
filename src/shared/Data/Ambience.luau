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

-- Duskwood (S45) -------------------------------------------------------------------------------------------------
local OLD_TREES = s("old forest wind loop (wind in big old trees, creaking branches)", 0.45)
local DARK_FOREST_NIGHT = s("dark forest night loop (owls, distant creaks, no birdsong)", 0.4)
local WEREWOLF_HOWL = s("werewolf howl distant night loop (deep, beastly howls, long gaps)", 0.35)
local HOLLOW_DRIP = s("damp forest gorge loop (dripping, cold wind, distant water)", 0.35)
local WHISPERS = s("ghostly whispers loop (faint, eerie, ruins)", 0.3)
local CHAPEL_BELL = s("single distant church bell toll loop (long gaps, eerie)", 0.3)
local ROT = s("rotting wood groans and bubbling mud loop (creepy forest)", 0.35)
local SPORES = s("eerie forest drone loop (low hum, magical, unsettling)", 0.25)
local CULT_CHANT = s("cult chanting night loop (low voices, ritual)", 0.35)
local CULT_DAY = s("forest clearing camp loop (wind, distant voices, fire)", 0.3)
local MIST_WIND = s("misty moor wind loop (soft, hollow, eerie)", 0.4)
local GALLOWS = s("rope creaking loop (gallows, slow sway)", 0.3)
local SWAMP_DAY = s("swamp ambience day loop (bubbles, insects, frogs)", 0.45)
local SWAMP_NIGHT = s("swamp night loop (frogs croaking, bubbling, insects)", 0.45)
local TROLL_GRUNTS = s("troll grunts distant loop (deep growls, camp)", 0.3)
local WITCH_MARSH = s("witch marsh loop (bubbling cauldron, wooden chimes, crows)", 0.35)
local CLIFF_WIND = s("cliff wind loop (strong gusts, high rocks)", 0.45)
local BAT_COLONY = s("bat colony squeaks loop (cave, many bats)", 0.3)

local DUSKWOOD_AREAS: { [string]: Mood } = {
	-- darker, the fog closer, cool
	duskwood_werethicket = {
		fogScale = 0.8,
		fogColor = "#2E3240",
		fogMix = 0.4,
		tint = "#D0D4F0",
		tintMix = 0.25,
		brightness = 0.9,
		sounds = { day = { OLD_TREES }, night = { DARK_FOREST_NIGHT, WEREWOLF_HOWL } },
	},
	-- cold and damp
	duskwood_bearhollow = {
		fogScale = 0.85,
		fogColor = "#3A4450",
		fogMix = 0.4,
		tint = "#D8E8F0",
		tintMix = 0.3,
		saturation = -0.05,
		sounds = { day = { HOLLOW_DRIP, OLD_TREES }, night = { HOLLOW_DRIP, DARK_FOREST_NIGHT } },
	},
	-- chilly, drained of colour, a light haze
	duskwood_ruins = {
		fogScale = 0.85,
		fogColor = "#5A5E6A",
		fogMix = 0.35,
		saturation = -0.22,
		tint = "#E0E4F0",
		tintMix = 0.3,
		haze = 0.6,
		sounds = { day = { OLD_TREES, WHISPERS }, night = { WHISPERS, CHAPEL_BELL } },
	},
	-- sickly green
	duskwood_heart = {
		fogScale = 0.75,
		fogColor = "#3A4A30",
		fogMix = 0.5,
		tint = "#DCF0C8",
		tintMix = 0.4,
		saturation = -0.05,
		haze = 0.5,
		sounds = { day = { ROT, SPORES }, night = { ROT, SPORES, DARK_FOREST_NIGHT } },
	},
	-- a violet cast
	duskwood_cultvillage = {
		fogColor = "#3A2E4A",
		fogMix = 0.45,
		tint = "#E8D8FF",
		tintMix = 0.4,
		saturation = -0.08,
		sounds = { day = { CULT_DAY, OLD_TREES }, night = { CULT_CHANT, DARK_FOREST_NIGHT } },
	},
	-- the thickest white fog of the forest
	duskwood_crossroads = {
		fogScale = 0.55,
		fogColor = "#9AA0A8",
		fogMix = 0.6,
		tint = "#EEF0F4",
		tintMix = 0.3,
		saturation = -0.12,
		haze = 1.2,
		density = 0.06,
		sounds = { day = { MIST_WIND }, night = { MIST_WIND, GALLOWS } },
	},
	-- green-brown
	duskwood_swamp = {
		fogScale = 0.8,
		fogColor = "#3E4430",
		fogMix = 0.5,
		tint = "#E8E8C8",
		tintMix = 0.35,
		saturation = -0.06,
		haze = 0.6,
		sounds = { day = { SWAMP_DAY, TROLL_GRUNTS }, night = { SWAMP_NIGHT, TROLL_GRUNTS } },
	},
	-- green and violet
	duskwood_witchmarsh = {
		fogScale = 0.8,
		fogColor = "#3A3A4A",
		fogMix = 0.45,
		tint = "#E0F0E0",
		tintMix = 0.35,
		saturation = -0.04,
		sounds = { day = { WITCH_MARSH, SWAMP_DAY }, night = { WITCH_MARSH, SWAMP_NIGHT } },
	},
	-- reddish and clearer
	duskwood_bloodcliffs = {
		fogScale = 1.25,
		fogColor = "#5A3A36",
		fogMix = 0.45,
		tint = "#FFE0D8",
		tintMix = 0.35,
		saturation = 0.02,
		sounds = { day = { CLIFF_WIND }, night = { CLIFF_WIND, BAT_COLONY } },
	},
}
for id, mood in DUSKWOOD_AREAS do
	areas[id] = mood
end

-- Ashen Wastes (S46) ---------------------------------------------------------------------------------------------
local ASH_WIND = s("desert wind with ash loop (dry gusts, fine grit hissing)", 0.4)
local EARTH_RUMBLE = s("distant earth rumble loop (deep, slow, volcanic)", 0.25)
local EMBERS_CRACKLE = s("embers crackling loop (hot coals, small pops)", 0.35)
local HYENAS = s("hyena laughter distant night loop (cackles, long gaps)", 0.3)
local HOT_WIND_PALMS = s("hot wind in dry palm leaves loop (rustling, dry)", 0.4)
local VULTURES = s("vultures calling loop (distant screeches, wings)", 0.3)
local DESERT_INSECTS = s("desert night insects loop (crickets, dry, sparse)", 0.35)
local ORC_CAMP = s("orc war camp ambience loop (grunts, chatter, distant fire)", 0.4)
local FORGE_HAMMERS = s("blacksmith hammering loop (anvil, slow, distant)", 0.35)
local WAR_DRUMS = s("war drums loop (deep, slow, tribal)", 0.4)
local CAMPFIRE = s("large bonfire crackle loop", 0.35)
local LAVA_BUBBLING = s("lava bubbling loop (thick, slow, hissing)", 0.45)
local SMOULDER = s("smouldering ruins loop (crackling embers, settling debris)", 0.35)
local RUINS_WIND = s("wind through ruins loop (hollow, whistling gaps)", 0.35)
local BEAM_CREAK = s("old wooden beam creaking loop (slow, occasional)", 0.25)
local IMP_GIGGLES = s("small creature giggles loop (impish, distant, eerie)", 0.25)
local DESERT_WIND = s("desert wind loop (open dunes, steady)", 0.4)
local SAND_HISS = s("blowing sand loop (fine hiss over dunes)", 0.3)
local DESERT_NIGHT_WIND = s("cold desert night wind loop (soft, empty)", 0.35)
local CRAG_WIND = s("wind whistling through rocks loop (canyon, high pitch)", 0.4)
local WYVERN_SCREECH = s("distant dragon screech loop (rare, echoing)", 0.25)
local DUSTY_WIND = s("dusty wind and silence loop (empty road, faint gusts)", 0.35)
local WINGS = s("large wings flapping distant loop (rare)", 0.25)
local FALLING_STONES = s("small rocks trickling loop (scree, occasional)", 0.25)
local STILL_HEAT = s("still hot air drone loop (very quiet, low)", 0.25)
local DRONE_LOW = s("ancient tomb low drone loop (dark, sustained)", 0.3)
local WHISPERS_TOMB = s("ghostly whispers loop (faint, ancient, tomb)", 0.25)

local ASHEN_AREAS: { [string]: Mood } = {
	-- ashen grey, slightly drained
	ashen_flats = {
		fogColor = "#9A8A7E",
		fogMix = 0.4,
		saturation = -0.08,
		haze = 0.8,
		sounds = { day = { ASH_WIND, EARTH_RUMBLE }, night = { EMBERS_CRACKLE, HYENAS } },
	},
	-- glaring heat
	ashen_oasis = {
		brightness = 1.08,
		tint = "#FFF0D0",
		tintMix = 0.35,
		haze = 1.2,
		sounds = { day = { HOT_WIND_PALMS, VULTURES }, night = { DESERT_INSECTS, HYENAS } },
	},
	-- smoky
	ashen_warcamp = {
		fogScale = 0.75,
		fogColor = "#7A4A3A",
		fogMix = 0.45,
		haze = 0.8,
		sounds = { day = { ORC_CAMP, FORGE_HAMMERS }, night = { WAR_DRUMS, CAMPFIRE } },
	},
	-- red, hazy, dense
	ashen_golemfields = {
		fogScale = 0.7,
		fogColor = "#B0482A",
		fogMix = 0.5,
		tint = "#FFC8A8",
		tintMix = 0.4,
		haze = 1.6,
		density = 0.06,
		sounds = { day = { LAVA_BUBBLING, EARTH_RUMBLE }, night = { LAVA_BUBBLING, EARTH_RUMBLE, EMBERS_CRACKLE } },
	},
	-- grey-brown, drained
	ashen_burntruins = {
		fogScale = 0.8,
		fogColor = "#6A5E56",
		fogMix = 0.4,
		saturation = -0.25,
		sounds = { day = { SMOULDER, RUINS_WIND, BEAM_CREAK }, night = { EMBERS_CRACKLE, IMP_GIGGLES } },
	},
	-- bright golden
	ashen_dunes = {
		brightness = 1.1,
		tint = "#FFE8C0",
		tintMix = 0.35,
		saturation = 0.1,
		sounds = { day = { DESERT_WIND, SAND_HISS }, night = { DESERT_NIGHT_WIND } },
	},
	-- clearer, warm
	ashen_crags = {
		fogScale = 1.15,
		tint = "#FFE4CC",
		tintMix = 0.3,
		sounds = { day = { CRAG_WIND, WYVERN_SCREECH }, night = { CRAG_WIND } },
	},
	-- sepia
	ashen_ashroad = {
		fogColor = "#A89078",
		fogMix = 0.45,
		tint = "#F0E0C8",
		tintMix = 0.35,
		saturation = -0.18,
		sounds = { day = { DUSTY_WIND, WINGS }, night = { DUSTY_WIND, FALLING_STONES } },
	},
	-- cooler, a touch of turquoise
	ashen_tombs = {
		fogColor = "#8A9A98",
		fogMix = 0.3,
		tint = "#E0F4F4",
		tintMix = 0.3,
		saturation = -0.12,
		sounds = { day = { STILL_HEAT, SAND_HISS }, night = { DRONE_LOW, WHISPERS_TOMB } },
	},
}
for id, mood in ASHEN_AREAS do
	areas[id] = mood
end

-- S47 Frost Peaks (sounds to find; one Sound per loop shared between areas)
local SPRUCE_WIND = s("wind in snowy spruce forest loop (soft gusts, creaking trunks, snow falling off branches)", 0.4)
local SNOW_CREAK = s("snow crunching and creaking loop (cold, quiet, distant footsteps)", 0.25)
local WOLVES_NIGHT = s("wolves howling winter night loop (pack, distant, long gaps)", 0.35)
local FROST_CRACK = s("trees cracking from frost loop (sharp distant cracks, winter night)", 0.25)
local MOUNTAIN_WIND = s("high mountain wind loop (strong, steady, cold)", 0.45)
local AVALANCHE_FAR = s("distant avalanche rumble loop (long gaps)", 0.25)
local HOWLING_WIND = s("howling wind night loop (blizzard, mountains)", 0.45)
local YETI_ROARS = s("distant beast roars loop (big ape, mountains, long gaps)", 0.3)
local SPIRE_WIND = s("wind whistling through rocks loop (high pitched, gusty)", 0.4)
local HARPY_SHRIEKS = s("distant bird of prey shrieks loop (harpy, eerie, echo)", 0.3)
local GUSTS_NIGHT = s("gusty night wind loop (strong gusts, mountains)", 0.4)
local PASS_WIND = s("strong wind through a mountain pass loop (roaring, funnelled)", 0.5)
local GIANT_HORNS = s("distant war horn loop (deep, long, echoing in mountains)", 0.3)
local BIG_FIRE = s("large bonfire crackling loop (big logs, roaring)", 0.35)
local ICE_SINGING = s("frozen lake ice cracking and singing loop (pings, booms, eerie)", 0.4)
local LIGHT_WIND = s("light cold wind loop (calm, open space)", 0.3)
local ICE_BOOMS = s("deep ice booming loop (frozen lake at night, low thuds)", 0.35)
local TUNDRA_WIND = s("tundra wind loop (steady, open, cold)", 0.45)
local MAMMOTH_CALLS = s("distant elephant trumpeting loop (mammoth, long gaps, echo)", 0.3)
local WOLVES_FAR = s("far wolves howling loop (very distant, faint)", 0.25)
local COLUMN_WIND = s("wind between stone columns loop (hollow, ruins)", 0.4)
local ICE_CHIMES = s("ice wind chimes loop (crystal, delicate, magical)", 0.3)
local LOW_GROWL = s("low draconic rumble loop (deep, slow, distant)", 0.3)
local CRYSTAL_HUM = s("magical crystal hum loop (soft, shimmering)", 0.3)
local BATTLEMENT_WIND = s("wind on castle battlements loop (cold, stone, flags)", 0.4)
local FLAG_CREAK = s("frozen flags creaking loop (stiff fabric, ropes, cold)", 0.25)
local DARK_DRONE = s("dark cold ambient drone loop (low, ominous)", 0.3)
local DISTANT_HORN = s("single distant horn call loop (long gaps, lonely)", 0.25)
local BLIZZARD = s("high altitude blizzard loop (roaring wind, snow hiss)", 0.5)
local WYRM_ROAR = s("distant dragon roar loop (deep, echoing, long gaps)", 0.3)

local FROST_AREAS: { [string]: Mood } = {
	-- slightly warm tint in the sun, a little haze
	frostpeak_valley = {
		tint = "#FFF4E4",
		tintMix = 0.2,
		haze = 0.3,
		sounds = { day = { SPRUCE_WIND, SNOW_CREAK }, night = { WOLVES_NIGHT, FROST_CRACK } },
	},
	-- whiter, blown snow dust
	frostpeak_slopes = {
		fogColor = "#F2F6FA",
		fogMix = 0.4,
		haze = 0.8,
		sounds = { day = { MOUNTAIN_WIND, AVALANCHE_FAR }, night = { HOWLING_WIND, YETI_ROARS } },
	},
	-- clearer
	frostpeak_harpyrocks = {
		fogScale = 1.1,
		sounds = { day = { SPIRE_WIND, HARPY_SHRIEKS }, night = { GUSTS_NIGHT } },
	},
	-- grey-blue
	frostpeak_pass = {
		fogScale = 0.8,
		fogColor = "#A8B8C8",
		fogMix = 0.4,
		tint = "#E0E8F0",
		tintMix = 0.25,
		sounds = { day = { PASS_WIND, GIANT_HORNS }, night = { PASS_WIND, BIG_FIRE } },
	},
	-- very bright, icy blue
	frostpeak_lake = {
		brightness = 1.08,
		tint = "#DDF2FF",
		tintMix = 0.35,
		saturation = 0.05,
		sounds = { day = { ICE_SINGING, LIGHT_WIND }, night = { ICE_BOOMS } },
	},
	-- flat light, drained, blown snow
	frostpeak_tundra = {
		saturation = -0.1,
		haze = 0.6,
		sounds = { day = { TUNDRA_WIND, MAMMOTH_CALLS }, night = { TUNDRA_WIND, WOLVES_FAR } },
	},
	-- cold blue with a golden accent
	frostpeak_temple = {
		tint = "#E4ECFF",
		tintMix = 0.25,
		fogColor = "#C8C0A8",
		fogMix = 0.15,
		haze = 0.4,
		sounds = { day = { COLUMN_WIND, ICE_CHIMES }, night = { LOW_GROWL, CRYSTAL_HUM } },
	},
	-- steel
	frostpeak_icewatch = {
		fogScale = 0.85,
		fogColor = "#8A98A8",
		fogMix = 0.35,
		saturation = -0.12,
		sounds = { day = { BATTLEMENT_WIND, FLAG_CREAK }, night = { DARK_DRONE, DISTANT_HORN } },
	},
	-- white-out
	frostpeak_wyrmspire = {
		fogScale = 0.55,
		fogColor = "#F4F8FC",
		fogMix = 0.6,
		haze = 1.4,
		sounds = { day = { BLIZZARD }, night = { BLIZZARD, WYRM_ROAR } },
	},
}
for id, mood in FROST_AREAS do
	areas[id] = mood
end

-- Map-wide moods outside every area (paths between the areas keep the map's plain light).
local maps: { [string]: Mood } = {
	meadows = { sounds = { day = { BIRDS, WIND_GRASS }, night = { NIGHT_CRICKETS } } },
	duskwood = { sounds = { day = { OLD_TREES }, night = { DARK_FOREST_NIGHT } } },
	ashen = {
		sounds = {
			day = { DESERT_WIND },
			night = { DESERT_NIGHT_WIND, s("distant thunder rumble loop (dry storm, long gaps)", 0.25) },
		},
	},
	frostpeak = { sounds = { day = { MOUNTAIN_WIND }, night = { HOWLING_WIND } } },
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
	-- S45 (positions: Data/Areas/duskwood sites)
	duskwood = {
		{ x = 604, z = -142, radius = 120, sound = s("small waterfall loop (thin cascade over rocks)", 0.55) },
		{ x = 389, z = -128, radius = 70, sound = STREAM },
		{ x = 200, z = -20, radius = 70, sound = STREAM },
		{ x = 596, z = -606, radius = 80, sound = s("magic fire loop (crackling, eerie hum)", 0.4) },
		{
			x = 560,
			z = -560,
			radius = 120,
			sound = s("cult chanting night loop (low voices, ritual)", 0.35),
			night = true,
		},
		{ x = 300, z = -82, radius = 40, sound = s("rope creaking loop (gallows, slow sway)", 0.3) },
		{ x = 4, z = -586, radius = 120, sound = s("single distant church bell toll loop (long gaps, eerie)", 0.3) },
		{ x = 702, z = 612, radius = 90, sound = s("big cauldron bubbling loop (thick, slow)", 0.4) },
		{ x = -66, z = 122, radius = 60, sound = s("bubbling cauldron loop (small, magical)", 0.4) },
		{ x = 66, z = 72, radius = 50, sound = s("wooden and bone wind chimes loop (hollow)", 0.35) },
		{ x = 616, z = -40, radius = 90, sound = s("bat colony squeaks loop (cave, many bats)", 0.35), night = true },
		{ x = 150, z = 372, radius = 110, sound = s("rotting wood groans and bubbling mud loop (creepy forest)", 0.4) },
		{ x = 768, z = 0, radius = 80, sound = s("crypt wind howl loop (low, cold, stone)", 0.35) },
	},
	-- S46 (positions: Data/Areas/ashen sites, Data/Terrain/ashen lava)
	ashen = {
		{ x = 60, z = 262, radius = 80, sound = LAVA_BUBBLING },
		{ x = -182, z = 300, radius = 80, sound = LAVA_BUBBLING },
		{ x = -60, z = 281, radius = 70, sound = s("lava flowing loop (slow, thick, crackling crust)", 0.4) },
		{ x = 130, z = 100, radius = 150, sound = s("volcanic vent roar loop (deep, rumbling)", 0.5) },
		{ x = 92, z = 138, radius = 90, sound = s("lava fall loop (heavy pouring, hissing)", 0.5) },
		{ x = -590, z = -190, radius = 70, sound = LAVA_BUBBLING },
		{ x = -166, z = -540, radius = 80, sound = FORGE_HAMMERS },
		{ x = -250, z = -640, radius = 160, sound = WAR_DRUMS, night = true },
		{ x = -680, z = 304, radius = 60, sound = s("bubbling hot spring loop (water, steam hiss)", 0.4) },
		{ x = 214, z = 604, radius = 80, sound = SMOULDER },
		{ x = 560, z = -560, radius = 140, sound = CRAG_WIND },
		{ x = 752, z = 0, radius = 100, sound = s("dwarven forge deep loop (muffled hammers, bellows)", 0.45) },
		{ x = 610, z = 150, radius = 110, sound = DRONE_LOW, night = true },
	},
	-- S47 (positions: Data/Areas/frostpeak sites, streams and lakes)
	frostpeak = {
		{ x = -610, z = 11, radius = 50, sound = s("water flowing under ice loop (muffled brook, gurgling)", 0.35) },
		{ x = -612, z = 80, radius = 50, sound = s("water flowing under ice loop (muffled brook, gurgling)", 0.35) },
		{ x = -555, z = -169, radius = 50, sound = s("old lantern creaking in the wind loop (metal, slow)", 0.3) },
		{ x = 196, z = 104, radius = 130, sound = BIG_FIRE },
		{ x = 22, z = 352, radius = 120, sound = s("ice cracking and creaking loop (frozen waterfall, icicles)", 0.4) },
		{ x = 166, z = 584, radius = 60, sound = s("water splashing in an ice hole loop (small, cold)", 0.3) },
		{ x = 300, z = 640, radius = 90, sound = CRYSTAL_HUM, night = true },
		{ x = 560, z = 0, radius = 70, sound = s("brazier fire loop (crackling, medium)", 0.35) },
		{ x = 562, z = 570, radius = 80, sound = FLAG_CREAK },
		{ x = 690, z = -650, radius = 220, sound = s("wind roaring over a mountain summit loop (very strong)", 0.5) },
		{ x = 745, z = 0, radius = 100, sound = s("deep glacier cracking loop (groaning ice, low booms)", 0.45) },
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
