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
-- Sound: loops by day and by night, at most 3 at a time, crossfaded, volume from the "Ambience" option. Every entry
-- says what it should sound like (`hint`); the id comes from `IDS` (W27), entries with an empty id are skipped.
-- `points` are positional loops (waterfall, fires, drums) heard within `radius` studs.

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
	y: number?, -- S48: height (map-relative); default the floor + 6 (caves on the engine) or 6
}

-- W27 (owner decision 2026-10-20): loops from the ProSoundEffects library in the Creator Store (APMOfficial when
-- PSE has nothing fitting); chosen by description and length, not listened to. List: docs/ASSETS.md (W27).
local IDS = {
	ANVIL = "rbxassetid://9113132431",
	ARMOR = "rbxassetid://9117651569",
	BARSTOW = "rbxassetid://9113286969",
	BARSTOW_B = "rbxassetid://9113287001",
	BEES = "rbxassetid://9112881890",
	BELL = "rbxassetid://9113804573",
	BIRDS = "rbxassetid://9112831284",
	BOIL = "rbxassetid://9120500629",
	BREATHING = "rbxassetid://9120494643",
	BREATH_GROWL = "rbxassetid://9112863325",
	BUGS = "rbxassetid://1839838823",
	CAPE = "rbxassetid://9113716666",
	CAVE_LAP = "rbxassetid://9120570701",
	CHIMES_GLASS = "rbxassetid://9120750073",
	CHIMES_TUNED = "rbxassetid://9120750072",
	CHISEL = "rbxassetid://9118581497",
	CHISEL_B = "rbxassetid://9118581493",
	CHOIR = "rbxassetid://1837435799",
	CINDER = "rbxassetid://9125440972",
	COSMIC = "rbxassetid://9113948307",
	COYOTES = "rbxassetid://9113954299",
	CRAB_MUNCH = "rbxassetid://9113987366",
	CRAB_ROAR = "rbxassetid://9113987614",
	CREEK_NIGHT = "rbxassetid://9113996155",
	CRICKETS = "rbxassetid://9112765304",
	CRICKETS_DESERT = "rbxassetid://9112765142",
	CRICKETS_FOREST = "rbxassetid://9112764891",
	CROWS = "rbxassetid://9112751072",
	DEBRIS = "rbxassetid://9114034817",
	DESERT_WIND = "rbxassetid://9114057128",
	DESERT_WIND_B = "rbxassetid://9114057104",
	DIG = "rbxassetid://9120634046",
	DRIPS = "rbxassetid://9120540076",
	EERIE_PIPE = "rbxassetid://9112775414",
	ELEPHANT = "rbxassetid://9114296808",
	EVIL_DRONE = "rbxassetid://9114353261",
	FARM = "rbxassetid://9112824481",
	FARMLAND = "rbxassetid://9112777807",
	FIELD_BIRDS = "rbxassetid://9112779493",
	FIRE = "rbxassetid://9112780462",
	FIRE_B = "rbxassetid://9112780193",
	FIRE_BIG = "rbxassetid://9112906854",
	FIRE_WHOOSH = "rbxassetid://9112780561",
	FOREST_AMB1 = "rbxassetid://9112781510",
	FOREST_AMB2 = "rbxassetid://9112781689",
	FROGS = "rbxassetid://9125615469",
	GHOST_FOREST = "rbxassetid://9114244841",
	GHOST_FOREST_B = "rbxassetid://9114244667",
	GODS_WIND = "rbxassetid://9114625552",
	HEARTBEAT = "rbxassetid://9043365842",
	HOLLOW = "rbxassetid://9112795463",
	HOLLOW_B = "rbxassetid://9112795583",
	ICE_CUBE = "rbxassetid://9114862037",
	JACUZZI = "rbxassetid://9113602975",
	JUNGLE_INSECTS = "rbxassetid://9114894515",
	KEYS = "rbxassetid://9116165357",
	KODO = "rbxassetid://1836484912",
	LAB_BUBBLE = "rbxassetid://1842379744",
	LAKE_LAP = "rbxassetid://9120572579",
	LAVA_FIRE = "rbxassetid://9112822943",
	LAVA_RUMBLE = "rbxassetid://9112823552",
	MONSTER_GEL = "rbxassetid://9116964934",
	MOUNTAIN_BIRDS = "rbxassetid://9112832297",
	NIGHT_OWLS = "rbxassetid://9112835631",
	ORGANIC = "rbxassetid://9112840906",
	PIGS = "rbxassetid://9113239420",
	SNAKE = "rbxassetid://9118064108",
	SPACE_PRES = "rbxassetid://9119392328",
	STORM_DRAIN = "rbxassetid://9119643864",
	STREAM = "rbxassetid://9119646672",
	THUNDER = "rbxassetid://9120018695",
	TIMBERS = "rbxassetid://9120832471",
	WAGON = "rbxassetid://9112892531",
	WAGON_METAL = "rbxassetid://9112892695",
	WATERFALL_DIST = "rbxassetid://9120552550",
	WATERFALL_MED = "rbxassetid://9116496316",
	WATERFALL_ROAR = "rbxassetid://9120549564",
	WATERFALL_SMALL = "rbxassetid://9120552418",
	WOLF_GROWL = "rbxassetid://9120788412",
	WOLVES_DISTANT = "rbxassetid://9120051839",
	WOLVES_LARGE = "rbxassetid://9120051995",
	WOOD_CRACK = "rbxassetid://9120822603",
}

local function s(hint: string, volume: number?, id: string?): Sound
	return { id = id or "", volume = volume or 0.5, hint = hint }
end

-- Shared loops (one Sound each; the same id in two areas keeps playing across the border).
local BIRDS = s("birds meadow loop (songbirds, daytime, countryside)", 0.45, IDS.BIRDS)
local WIND_GRASS = s("wind in grass loop (soft, steady)", 0.35, IDS.FARMLAND)
local NIGHT_CRICKETS = s("crickets night loop (field, gentle)", 0.4, IDS.CRICKETS)
local OWL = s("owl hooting night forest loop (sparse)", 0.3, IDS.NIGHT_OWLS)
local WIND_HILLS = s("wind on hills loop (gusts, open terrain)", 0.4, IDS.BARSTOW)
local WOLF_HOWL = s("wolf howl distant night loop (several howls, long gaps)", 0.35, IDS.WOLVES_DISTANT)
local FROGS = s("frogs croaking swamp loop (toads, marsh)", 0.5, IDS.FROGS)
local MARSH_NIGHT = s("swamp night loop (frogs, insects, water)", 0.45, IDS.CREEK_NIGHT)
local FOREST_DAY = s("forest ambience day loop (birds, leaves rustling, woodpecker)", 0.45, IDS.FOREST_AMB2)
local FOREST_NIGHT = s("forest night loop (owls, insects, branches)", 0.4, IDS.CRICKETS_FOREST)
local CROWS = s("crows cawing loop (several crows, field)", 0.45, IDS.CROWS)
local FIRE_DISTANT = s("distant campfire crackle loop", 0.2, IDS.FIRE_B)
local ROAD_DAY = s("countryside road ambience loop (birds, distant cart, wind)", 0.35, IDS.FIELD_BIRDS)
local QUARRY = s("quarry ambience loop (dripping, distant pickaxe, gravel)", 0.35, IDS.CHISEL_B)
local CAVE_WIND = s("cave wind low drone loop", 0.25, IDS.STORM_DRAIN)
local GOBLIN_CAMP = s("goblin camp ambience loop (chatter, grunts, fire)", 0.4)
local DRUMS_NIGHT = s("tribal drums distant night loop (slow)", 0.35, IDS.KODO)
local RAVINE = s("mountain ravine ambience loop (wind, distant water, birds of prey)", 0.4, IDS.MOUNTAIN_BIRDS)
local STREAM = s("stream water flowing loop (small brook)", 0.35, IDS.STREAM)

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
local OLD_TREES = s("old forest wind loop (wind in big old trees, creaking branches)", 0.45, IDS.FOREST_AMB1)
local DARK_FOREST_NIGHT = s("dark forest night loop (owls, distant creaks, no birdsong)", 0.4, IDS.NIGHT_OWLS)
local WEREWOLF_HOWL = s("werewolf howl distant night loop (deep, beastly howls, long gaps)", 0.35, IDS.WOLVES_LARGE)
local HOLLOW_DRIP = s("damp forest gorge loop (dripping, cold wind, distant water)", 0.35, IDS.DRIPS)
local WHISPERS = s("ghostly whispers loop (faint, eerie, ruins)", 0.3, IDS.GHOST_FOREST)
local CHAPEL_BELL = s("single distant church bell toll loop (long gaps, eerie)", 0.3, IDS.BELL)
local ROT = s("rotting wood groans and bubbling mud loop (creepy forest)", 0.35, IDS.LAB_BUBBLE)
local SPORES = s("eerie forest drone loop (low hum, magical, unsettling)", 0.25, IDS.GHOST_FOREST_B)
local CULT_CHANT = s("cult chanting night loop (low voices, ritual)", 0.35)
local CULT_DAY = s("forest clearing camp loop (wind, distant voices, fire)", 0.3)
local MIST_WIND = s("misty moor wind loop (soft, hollow, eerie)", 0.4, IDS.GODS_WIND)
local GALLOWS = s("rope creaking loop (gallows, slow sway)", 0.3, IDS.TIMBERS)
local SWAMP_DAY = s("swamp ambience day loop (bubbles, insects, frogs)", 0.45, IDS.JUNGLE_INSECTS)
local SWAMP_NIGHT = s("swamp night loop (frogs croaking, bubbling, insects)", 0.45, IDS.CREEK_NIGHT)
local TROLL_GRUNTS = s("troll grunts distant loop (deep growls, camp)", 0.3, IDS.MONSTER_GEL)
local WITCH_MARSH = s("witch marsh loop (bubbling cauldron, wooden chimes, crows)", 0.35, IDS.LAB_BUBBLE)
local CLIFF_WIND = s("cliff wind loop (strong gusts, high rocks)", 0.45, IDS.BARSTOW)
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
local ASH_WIND = s("desert wind with ash loop (dry gusts, fine grit hissing)", 0.4, IDS.DESERT_WIND)
local EARTH_RUMBLE = s("distant earth rumble loop (deep, slow, volcanic)", 0.25, IDS.HOLLOW)
local EMBERS_CRACKLE = s("embers crackling loop (hot coals, small pops)", 0.35, IDS.FIRE_B)
local HYENAS = s("hyena laughter distant night loop (cackles, long gaps)", 0.3, IDS.COYOTES)
local HOT_WIND_PALMS = s("hot wind in dry palm leaves loop (rustling, dry)", 0.4, IDS.DESERT_WIND_B)
local VULTURES = s("vultures calling loop (distant screeches, wings)", 0.3)
local DESERT_INSECTS = s("desert night insects loop (crickets, dry, sparse)", 0.35, IDS.CRICKETS_DESERT)
local ORC_CAMP = s("orc war camp ambience loop (grunts, chatter, distant fire)", 0.4)
local FORGE_HAMMERS = s("blacksmith hammering loop (anvil, slow, distant)", 0.35, IDS.ANVIL)
local WAR_DRUMS = s("war drums loop (deep, slow, tribal)", 0.4, IDS.KODO)
local CAMPFIRE = s("large bonfire crackle loop", 0.35, IDS.FIRE_BIG)
local LAVA_BUBBLING = s("lava bubbling loop (thick, slow, hissing)", 0.45, IDS.LAVA_FIRE)
local SMOULDER = s("smouldering ruins loop (crackling embers, settling debris)", 0.35, IDS.FIRE_B)
local RUINS_WIND = s("wind through ruins loop (hollow, whistling gaps)", 0.35, IDS.GODS_WIND)
local BEAM_CREAK = s("old wooden beam creaking loop (slow, occasional)", 0.25, IDS.TIMBERS)
local IMP_GIGGLES = s("small creature giggles loop (impish, distant, eerie)", 0.25)
local DESERT_WIND = s("desert wind loop (open dunes, steady)", 0.4, IDS.DESERT_WIND)
local SAND_HISS = s("blowing sand loop (fine hiss over dunes)", 0.3, IDS.DESERT_WIND_B)
local DESERT_NIGHT_WIND = s("cold desert night wind loop (soft, empty)", 0.35, IDS.DESERT_WIND_B)
local CRAG_WIND = s("wind whistling through rocks loop (canyon, high pitch)", 0.4, IDS.DESERT_WIND)
local WYVERN_SCREECH = s("distant dragon screech loop (rare, echoing)", 0.25, IDS.CRAB_ROAR)
local DUSTY_WIND = s("dusty wind and silence loop (empty road, faint gusts)", 0.35, IDS.DESERT_WIND)
local WINGS = s("large wings flapping distant loop (rare)", 0.25, IDS.CAPE)
local FALLING_STONES = s("small rocks trickling loop (scree, occasional)", 0.25, IDS.DEBRIS)
local STILL_HEAT = s("still hot air drone loop (very quiet, low)", 0.25, IDS.SPACE_PRES)
local DRONE_LOW = s("ancient tomb low drone loop (dark, sustained)", 0.3, IDS.HOLLOW)
local WHISPERS_TOMB = s("ghostly whispers loop (faint, ancient, tomb)", 0.25, IDS.GHOST_FOREST)

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
local SPRUCE_WIND =
	s("wind in snowy spruce forest loop (soft gusts, creaking trunks, snow falling off branches)", 0.4, IDS.BARSTOW_B)
local SNOW_CREAK = s("snow crunching and creaking loop (cold, quiet, distant footsteps)", 0.25)
local WOLVES_NIGHT = s("wolves howling winter night loop (pack, distant, long gaps)", 0.35, IDS.WOLVES_LARGE)
local FROST_CRACK = s("trees cracking from frost loop (sharp distant cracks, winter night)", 0.25, IDS.WOOD_CRACK)
local MOUNTAIN_WIND = s("high mountain wind loop (strong, steady, cold)", 0.45, IDS.BARSTOW)
local AVALANCHE_FAR = s("distant avalanche rumble loop (long gaps)", 0.25, IDS.LAVA_RUMBLE)
local HOWLING_WIND = s("howling wind night loop (blizzard, mountains)", 0.45, IDS.BARSTOW_B)
local YETI_ROARS = s("distant beast roars loop (big ape, mountains, long gaps)", 0.3, IDS.CRAB_ROAR)
local SPIRE_WIND = s("wind whistling through rocks loop (high pitched, gusty)", 0.4, IDS.DESERT_WIND)
local HARPY_SHRIEKS = s("distant bird of prey shrieks loop (harpy, eerie, echo)", 0.3)
local GUSTS_NIGHT = s("gusty night wind loop (strong gusts, mountains)", 0.4, IDS.BARSTOW_B)
local PASS_WIND = s("strong wind through a mountain pass loop (roaring, funnelled)", 0.5, IDS.BARSTOW)
local GIANT_HORNS = s("distant war horn loop (deep, long, echoing in mountains)", 0.3)
local BIG_FIRE = s("large bonfire crackling loop (big logs, roaring)", 0.35, IDS.FIRE_BIG)
local ICE_SINGING = s("frozen lake ice cracking and singing loop (pings, booms, eerie)", 0.4)
local LIGHT_WIND = s("light cold wind loop (calm, open space)", 0.3, IDS.BARSTOW_B)
local ICE_BOOMS = s("deep ice booming loop (frozen lake at night, low thuds)", 0.35, IDS.WOOD_CRACK)
local TUNDRA_WIND = s("tundra wind loop (steady, open, cold)", 0.45, IDS.BARSTOW)
local MAMMOTH_CALLS = s("distant elephant trumpeting loop (mammoth, long gaps, echo)", 0.3, IDS.ELEPHANT)
local WOLVES_FAR = s("far wolves howling loop (very distant, faint)", 0.25, IDS.WOLVES_DISTANT)
local COLUMN_WIND = s("wind between stone columns loop (hollow, ruins)", 0.4, IDS.GODS_WIND)
local ICE_CHIMES = s("ice wind chimes loop (crystal, delicate, magical)", 0.3, IDS.CHIMES_TUNED)
local LOW_GROWL = s("low draconic rumble loop (deep, slow, distant)", 0.3, IDS.BREATH_GROWL)
local CRYSTAL_HUM = s("magical crystal hum loop (soft, shimmering)", 0.3, IDS.COSMIC)
local BATTLEMENT_WIND = s("wind on castle battlements loop (cold, stone, flags)", 0.4, IDS.BARSTOW)
local FLAG_CREAK = s("frozen flags creaking loop (stiff fabric, ropes, cold)", 0.25, IDS.TIMBERS)
local DARK_DRONE = s("dark cold ambient drone loop (low, ominous)", 0.3, IDS.HOLLOW_B)
local DISTANT_HORN = s("single distant horn call loop (long gaps, lonely)", 0.25)
local BLIZZARD = s("high altitude blizzard loop (roaring wind, snow hiss)", 0.5, IDS.BARSTOW)
local WYRM_ROAR = s("distant dragon roar loop (deep, echoing, long gaps)", 0.3, IDS.CRAB_ROAR)

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

-- S48 caves on the engine (sounds to find): loops per room of Data/CaveShapes (index = the room's index in
-- Logic/CaveTerrain: the plan's rooms, then the extra rooms); caves have no night, the "day" loops play.
local DRIP_ECHO = s("cave dripping water with echo loop (slow drops, deep cave)", 0.35, IDS.DRIPS)
local WATERFALL_BEHIND = s("waterfall heard from behind a rock wall loop (muffled roar)", 0.4, IDS.WATERFALL_DIST)
local UNDERGROUND_FALL = s("underground waterfall loop (cave, echo, splashing into a lake)", 0.45, IDS.WATERFALL_ROAR)
local LAKE_LAP = s("underground lake lapping loop (soft, cave echo)", 0.3, IDS.CAVE_LAP)
local SPIDER_CLICKS = s("giant spiders hissing and clicking loop (creepy, sparse)", 0.35, IDS.BUGS)
local SHAMAN_CHANT = s("goblin shamans chanting loop (low, tribal, cave echo)", 0.35)
local TRIBAL_DRUMS = s("tribal war drums loop (slow, deep, cave)", 0.35, IDS.KODO)
local BEAR_SNORE = s("bear snoring in a den loop (deep, slow breathing)", 0.3, IDS.BREATH_GROWL)
local BOAT_CREAK = s("wooden boat and ropes creaking loop (moored, gentle)", 0.3, IDS.TIMBERS)
local STREAM_FLOW = s("underground stream flowing loop (dark water, cave)", 0.35, IDS.STREAM)
local CROWS_SHAFT = s("crows cawing in a cave shaft loop (echo, sparse)", 0.3, IDS.CROWS)
local SINKHOLE_WIND = s("wind through a sinkhole loop (soft whistle, night)", 0.3, IDS.BARSTOW_B)
local GOBLIN_CHATTER = s("goblin camp chatter loop (muffled voices, clatter)", 0.35)
local PICKAXES = s("pickaxes striking rock loop (distant mining, echo)", 0.35, IDS.CHISEL)
local MINECART = s("mine cart rolling on rails loop (rumble, squeak)", 0.3, IDS.WAGON)
local WINCH_CREAK = s("wooden winch and chain creaking loop (mine shaft)", 0.3, IDS.TIMBERS)
local ARENA_DRUMS = s("war drums and roaring crowd loop (goblin arena)", 0.4, IDS.KODO)
local FIRE_CRACKLE = s("fire crackling loop (torches and braziers)", 0.3, IDS.FIRE)
local BOAR_GRUNTS = s("boars grunting in a pen loop (snorts, shuffling)", 0.3, IDS.PIGS)

-- S49 Duskwood's caves
local EARTH_CAVE = s("underground earth cave ambience loop (low wind, distant drips)", 0.35, IDS.STORM_DRAIN)
local GNAWING = s("bones crunching and gnawing loop (flies buzzing, wet)", 0.3, IDS.CRAB_MUNCH)
local BEAR_BREATH = s("large animal breathing loop (low growl, sleeping bear)", 0.3, IDS.BREATH_GROWL)
local WOLF_ECHO = s("distant wolf howl echoing in a cave loop (long gaps)", 0.3, IDS.WOLVES_DISTANT)
local LANTERN_CREAK = s("old lantern creaking loop (metal, slow)", 0.25, IDS.WAGON_METAL)
local BEES = s("bees buzzing in a hive loop (muffled, inside wood)", 0.3, IDS.BEES)
local TOMB_DRONE = s("ancient tomb ambience loop (low drone, stone dust)", 0.35, IDS.HOLLOW)
local CULT_VOICES = s("cult chanting loop (deep male voices, ritual)", 0.35)
local DIGGING = s("scratching and digging in earth loop (claws, muffled)", 0.3, IDS.DIG)
local DRIP_TOMB = s("dripping water in a stone crypt loop (echo)", 0.3, IDS.DRIPS)
local MAGIC_FIRE = s("magic fire roar loop (low, eerie)", 0.35, IDS.FIRE_WHOOSH)
local SNAKE_HISS = s("snake hissing loop (rare, close)", 0.2, IDS.SNAKE)
local CRYPT_DRONE = s("crypt ambience loop (deep drone, distant whispers)", 0.35, IDS.HOLLOW_B)
local GHOST_RISE = s("ghostly wind whoosh rising loop (well, eerie)", 0.35, IDS.GODS_WIND)
local BONES_CHAINS = s("bones rattling and chains creaking loop (ossuary)", 0.3, IDS.WAGON_METAL)
local GHOST_WAIL = s("ghost whispers and faint wailing loop", 0.3, IDS.GHOST_FOREST)
local NECRO_HUM = s("necromantic hum loop (low, bubbling, magical)", 0.3, IDS.EVIL_DRONE)
local CHOIR_HUM = s("low choir hum loop (dark, sacred)", 0.3, IDS.CHOIR)
local ROYAL_DRONE = s("royal tomb low choir drone loop", 0.35, IDS.CHOIR)

-- S50 the Ashen Wastes' caves
local SHAFT_WIND = s("wind howling down a mine shaft loop (hollow, low)", 0.3, IDS.EERIE_PIPE)
local TIMBER_CREAK = s("old mine timbers creaking loop (wood, slow)", 0.25, IDS.TIMBERS)
local CAGE_CHAIN = s("hanging cage swinging on a chain loop (metal creak)", 0.25, IDS.WAGON_METAL)
local GRAVEL = s("gravel trickling down loop (small stones, cave)", 0.2, IDS.DEBRIS)
local WAR_DRUM = s("slow tribal war drum loop (distant, echo)", 0.3, IDS.KODO)
local HYENA = s("hyena laughing echo loop (cave, distant)", 0.25, IDS.COYOTES)
local VULTURE = s("vulture screech loop (rare, high in a shaft)", 0.2)
local MAGMA_HISS = s("magma hissing and steam venting loop", 0.3, IDS.ORGANIC)
local VOLCANO_RUMBLE = s("deep volcano rumble loop (low, distant)", 0.35, IDS.HOLLOW)
local LAVA_BUBBLE = s("lava bubbling loop (thick, slow)", 0.3, IDS.LAVA_FIRE)
local WIND_HOLE = s("wind over an opening loop (hot, dry, gusty)", 0.25, IDS.DESERT_WIND_B)
local WYVERN_WINGS = s("distant wyvern screech and wing flaps loop (rare)", 0.25, IDS.CAPE)
local IMP_GIGGLE = s("small imps giggling loop (mischievous, echo)", 0.2)
local SAND_POUR = s("sand pouring down loop (steady hiss)", 0.3, IDS.DEBRIS)
local SCORPION = s("scorpion clicking loop (chitin, close)", 0.2, IDS.BUGS)
local EGG_THROB = s("low pulsing throb loop (deep, organic, slow)", 0.3, IDS.HEARTBEAT)
local ANVILS = s("blacksmith hammers on anvils loop (several, offset, echo)", 0.35, IDS.ANVIL)
local BELLOWS = s("forge bellows breathing loop (slow, leather)", 0.25, IDS.BREATHING)
local FORGE_ROAR = s("furnace roar loop (deep fire)", 0.35, IDS.FIRE_BIG)
local LAVA_RIVER = s("lava river flowing loop (low rumble, crackle)", 0.35, IDS.ORGANIC)
local QUENCH = s("hot metal quenching steam hiss loop", 0.25, IDS.BOIL)
local POUR_METAL = s("molten metal pouring and sizzling loop", 0.3, IDS.LAVA_FIRE)
local CHAINS = s("heavy chains clinking loop (slow)", 0.25, IDS.WAGON_METAL)
local GRINDSTONE = s("grindstone sharpening blade loop", 0.25)
local DWARF_SONG = s("low dwarven work song loop (male voices, distant)", 0.25)
local GOLEM_GRIND = s("stone grinding loop (golem, heavy, slow)", 0.25, IDS.CINDER)
local HEART_THUMP = s("deep heartbeat thump loop (huge, magma)", 0.35, IDS.HEARTBEAT)
local FURNACE_DEEP = s("giant furnace roar loop (huge, deep)", 0.4, IDS.FIRE_BIG)
local LAVAFALL = s("lava fall pouring loop (heavy, crackling)", 0.35, IDS.LAVA_FIRE)

-- S51 the Frost Peaks' caves
local ICE_CAVE = s("ice cave ambience loop (wind, creaking ice, distant drips)", 0.35, IDS.SPACE_PRES)
local ICE_CRACK = s("frozen waterfall ice cracking creak loop", 0.3, IDS.WOOD_CRACK)
local SHAFT_HOWL = s("wind howling through shaft loop", 0.3, IDS.EERIE_PIPE)
local BEAST_BREATH = s("large beast breathing low growl loop", 0.3, IDS.BREATH_GROWL)
local WOLF_PACK = s("wolves growling low pack loop", 0.3, IDS.WOLF_GROWL)
local UNDER_ICE = s("water lapping under ice loop", 0.25, IDS.CAVE_LAP)
local RAPTOR = s("bird of prey screech distant echo (rare)", 0.2)
local LANTERN_SWAY = s("old lantern creaking in the wind loop", 0.2, IDS.WAGON_METAL)
local FROZEN_CASTLE =
	s("frozen castle ambience loop (wind through halls, creaking ice, distant metal)", 0.35, IDS.SPACE_PRES)
local GLACIER_GROAN = s("glacier groaning deep ice creak loop", 0.3, IDS.WOOD_CRACK)
local CHOIR_FAINT = s("faint choir drone cathedral reverb loop", 0.25, IDS.CHOIR)
local ARMOR_CHAINS = s("armor clanking distant, chains loop", 0.25, IDS.ARMOR)
local ICE_WHISPER = s("faint whispers in ice loop", 0.2, IDS.GHOST_FOREST_B)
local GLACIER_DEEP = s("deep glacier ambience loop (low rumble, ice creaking)", 0.35, IDS.HOLLOW_B)
local HEARTBEAT = s("slow deep heartbeat loop (low, ~25 bpm)", 0.35, IDS.HEARTBEAT)
local CRYSTAL_CHIME = s("crystal chime resonance loop", 0.25, IDS.CHIMES_TUNED)
local ICE_ORGAN = s("wind through ice organ drone loop", 0.3, IDS.COSMIC)
local ICE_SLITHER = s("ice scraping slither loop", 0.25, IDS.ICE_CUBE)
local DRAGON_BREATH = s("dragon breathing low distant growl loop", 0.3, IDS.BREATH_GROWL)
local COINS = s("coins tinkle sparse loop", 0.2, IDS.KEYS)
local DRAGON_ROAR = s("distant dragon roar echo, cold wind under door loop", 0.3, IDS.CRAB_ROAR)
local LAIR_WIND = s("dragon lair ambience (cold wind, deep breathing) loop", 0.35, IDS.BREATH_GROWL)
local BRAZIER = s("fire brazier crackle loop", 0.3, IDS.FIRE)
local HIGH_WIND = s("high wind blizzard loop", 0.3, IDS.BARSTOW)

local function room(o: { [string]: any }): Mood
	return o :: any
end

local rooms: { [string]: { [number]: Mood } } = {
	meadows_cave = {
		room({ tint = "#D8FFD0", tintMix = 0.3, sounds = { day = { WATERFALL_BEHIND, DRIP_ECHO }, night = {} } }),
		room({
			fogScale = 1.3,
			tint = "#D0FFE0",
			tintMix = 0.25,
			sounds = { day = { UNDERGROUND_FALL, LAKE_LAP, DRIP_ECHO }, night = {} },
		}),
		room({ tint = "#FFE8C8", tintMix = 0.3, haze = 0.4, sounds = { day = { BEAR_SNORE, DRIP_ECHO }, night = {} } }),
		room({ tint = "#FFD8B8", tintMix = 0.25, sounds = { day = { TRIBAL_DRUMS, FIRE_CRACKLE }, night = {} } }),
		room({
			tint = "#D8F0E8",
			tintMix = 0.35,
			saturation = -0.1,
			sounds = { day = { SPIDER_CLICKS, SHAMAN_CHANT }, night = {} },
		}),
		room({
			fogScale = 0.7,
			fogColor = "#B8C0B8",
			fogMix = 0.4,
			saturation = -0.35,
			sounds = { day = { SPIDER_CLICKS, DRIP_ECHO }, night = {} },
		}),
		room({ tint = "#C8FFB8", tintMix = 0.4, sounds = { day = { SHAMAN_CHANT, FIRE_CRACKLE }, night = {} } }),
		room({ tint = "#FFC8B0", tintMix = 0.35, sounds = { day = { TRIBAL_DRUMS, FIRE_CRACKLE }, night = {} } }),
	},
	meadows_hideout = {
		room({ tint = "#FFE8C8", tintMix = 0.2, sounds = { day = { DRIP_ECHO, FIRE_CRACKLE }, night = {} } }),
		room({ tint = "#C8DCFF", tintMix = 0.35, sounds = { day = { STREAM_FLOW, BOAT_CREAK }, night = {} } }),
		room({
			tint = "#D8E4FF",
			tintMix = 0.3,
			fogScale = 1.2,
			sounds = { day = { CROWS_SHAFT, SINKHOLE_WIND }, night = {} },
		}),
		room({
			tint = "#FFE0A8",
			tintMix = 0.4,
			saturation = 0.1,
			sounds = { day = { FIRE_CRACKLE, DRIP_ECHO }, night = {} },
		}),
		room({
			tint = "#E8D0B0",
			tintMix = 0.3,
			haze = 0.8,
			fogColor = "#6A5A48",
			fogMix = 0.3,
			sounds = { day = { BOAR_GRUNTS, DRIP_ECHO }, night = {} },
		}),
	},
	meadows_burrow = {
		room({ tint = "#FFE4C0", tintMix = 0.25, sounds = { day = { GOBLIN_CHATTER, DRIP_ECHO }, night = {} } }),
		room({ tint = "#E0FFC8", tintMix = 0.3, sounds = { day = { GOBLIN_CHATTER, FIRE_CRACKLE }, night = {} } }),
		room({ haze = 1.2, fogColor = "#7A6A5A", fogMix = 0.35, sounds = { day = { PICKAXES, MINECART }, night = {} } }),
		room({
			brightness = 0.85,
			tint = "#E8D8C0",
			tintMix = 0.3,
			sounds = { day = { WINCH_CREAK, DRIP_ECHO }, night = {} },
		}),
		room({
			saturation = -0.3,
			tint = "#E0ECE0",
			tintMix = 0.3,
			sounds = { day = { SPIDER_CLICKS, DRIP_ECHO }, night = {} },
		}),
	},
	-- S51
	frostpeak_grotto = {
		room({ tint = "#E0F0FF", tintMix = 0.25, sounds = { day = { BLIZZARD, ICE_CAVE }, night = {} } }),
		room({
			brightness = 1.05,
			tint = "#D0ECFF",
			tintMix = 0.35,
			sounds = { day = { ICE_CRACK, ICE_CAVE }, night = {} },
		}),
		room({
			brightness = 1.1,
			fogScale = 1.2,
			tint = "#DCEAFF",
			tintMix = 0.3,
			sounds = { day = { SHAFT_HOWL, RAPTOR }, night = {} },
		}),
		room({ tint = "#D4E4F4", tintMix = 0.3, sounds = { day = { BEAST_BREATH, ICE_CAVE }, night = {} } }),
		room({ brightness = 0.8, tint = "#C8D8E8", tintMix = 0.3, sounds = { day = { WOLF_PACK }, night = {} } }),
	},
	frostpeak_hold = {
		room({ tint = "#D4E2F4", tintMix = 0.25, sounds = { day = { FROZEN_CASTLE, BLIZZARD }, night = {} } }),
		room({ tint = "#F0E0D0", tintMix = 0.25, sounds = { day = { GLACIER_GROAN, BIG_FIRE }, night = {} } }),
		room({ tint = "#CCEFFF", tintMix = 0.35, sounds = { day = { CRYSTAL_HUM, FROZEN_CASTLE }, night = {} } }),
		room({
			brightness = 1.05,
			saturation = -0.3,
			tint = "#E4EEFF",
			tintMix = 0.3,
			sounds = { day = { CHOIR_FAINT }, night = {} },
		}),
		room({
			fogScale = 0.8,
			tint = "#D0DCEC",
			tintMix = 0.25,
			sounds = { day = { ARMOR_CHAINS, FROZEN_CASTLE }, night = {} },
		}),
		room({ tint = "#C8DCF4", tintMix = 0.35, sounds = { day = { ICE_WHISPER, FROZEN_CASTLE }, night = {} } }),
	},
	frostpeak_cave = {
		room({ tint = "#DCF0FF", tintMix = 0.25, sounds = { day = { BLIZZARD, GLACIER_DEEP }, night = {} } }),
		room({ tint = "#C8F4FF", tintMix = 0.35, sounds = { day = { CRYSTAL_CHIME, HEARTBEAT }, night = {} } }),
		room({ tint = "#CCF2FF", tintMix = 0.35, sounds = { day = { HEARTBEAT, GLACIER_DEEP }, night = {} } }),
		room({ tint = "#D0ECFF", tintMix = 0.3, sounds = { day = { ICE_ORGAN, HEARTBEAT }, night = {} } }),
		room({
			brightness = 0.85,
			tint = "#C8E4F0",
			tintMix = 0.3,
			sounds = { day = { ICE_SLITHER, GLACIER_DEEP }, night = {} },
		}),
		room({ tint = "#F4ECD8", tintMix = 0.25, sounds = { day = { COINS, GLACIER_DEEP }, night = {} } }),
		room({
			fogScale = 1.25,
			tint = "#CCF0FF",
			tintMix = 0.35,
			sounds = { day = { DRAGON_BREATH, HEARTBEAT }, night = {} },
		}),
		room({
			fogScale = 0.75,
			tint = "#D8E0F0",
			tintMix = 0.35,
			sounds = { day = { DRAGON_ROAR, HEARTBEAT }, night = {} },
		}),
	},
	dungeon_frostpeak = {
		room({ tint = "#D6EEFF", tintMix = 0.35, sounds = { day = { LAIR_WIND }, night = {} } }),
		room({ tint = "#D6EEFF", tintMix = 0.3, sounds = { day = { LAIR_WIND }, night = {} } }),
	},
	-- S50
	ashen_mine = {
		room({ tint = "#FFE8C8", tintMix = 0.25, sounds = { day = { SHAFT_WIND, TIMBER_CREAK }, night = {} } }),
		room({
			haze = 0.6,
			tint = "#E8E0D0",
			tintMix = 0.2,
			sounds = { day = { CAGE_CHAIN, SHAFT_WIND, GRAVEL }, night = {} },
		}),
		room({
			haze = 0.4,
			tint = "#FFD8B0",
			tintMix = 0.3,
			sounds = { day = { ORC_CAMP, WAR_DRUM, CAMPFIRE }, night = {} },
		}),
		room({ tint = "#C8E4FF", tintMix = 0.35, sounds = { day = { VULTURE, TIMBER_CREAK }, night = {} } }),
		room({
			tint = "#FFC0A0",
			tintMix = 0.35,
			saturation = 0.05,
			sounds = { day = { HYENA, MAGMA_HISS }, night = {} },
		}),
	},
	ashen_lair = {
		room({ tint = "#FFE0C0", tintMix = 0.25, sounds = { day = { WIND_HOLE, GRAVEL }, night = {} } }),
		room({
			haze = 0.5,
			tint = "#FFB898",
			tintMix = 0.4,
			sounds = { day = { IMP_GIGGLE, LAVA_BUBBLE, MAGMA_HISS }, night = {} },
		}),
		room({ haze = 0.6, tint = "#FFE8C8", tintMix = 0.25, sounds = { day = { SAND_POUR, SCORPION }, night = {} } }),
		room({
			fogScale = 1.3,
			tint = "#FFD8B8",
			tintMix = 0.25,
			sounds = { day = { WYVERN_WINGS, WIND_HOLE }, night = {} },
		}),
		room({
			brightness = 0.85,
			tint = "#E0C8B8",
			tintMix = 0.25,
			sounds = { day = { GRAVEL, SCORPION }, night = {} },
		}),
		room({
			tint = "#FFC890",
			tintMix = 0.45,
			saturation = 0.1,
			sounds = { day = { EGG_THROB, LAVA_BUBBLE }, night = {} },
		}),
	},
	ashen_cave = {
		room({ tint = "#D8E8FF", tintMix = 0.3, sounds = { day = { VOLCANO_RUMBLE, LAVA_BUBBLE }, night = {} } }),
		room({
			brightness = 1.1,
			tint = "#FFD8A8",
			tintMix = 0.35,
			sounds = { day = { ANVILS, BELLOWS, FORGE_ROAR }, night = {} },
		}),
		room({
			haze = 0.6,
			tint = "#FFA880",
			tintMix = 0.45,
			sounds = { day = { LAVA_RIVER, GOLEM_GRIND }, night = {} },
		}),
		room({ tint = "#FFE0A0", tintMix = 0.4, sounds = { day = { POUR_METAL, ANVILS }, night = {} } }),
		room({ tint = "#FFB0A0", tintMix = 0.4, sounds = { day = { GOLEM_GRIND, CHAINS, QUENCH }, night = {} } }),
		room({ tint = "#FFD8B8", tintMix = 0.3, sounds = { day = { GRINDSTONE, DWARF_SONG }, night = {} } }),
		room({
			tint = "#FFB878",
			tintMix = 0.45,
			saturation = 0.1,
			sounds = { day = { HEART_THUMP, CHAINS }, night = {} },
		}),
		room({ tint = "#FF9C88", tintMix = 0.45, sounds = { day = { VOLCANO_RUMBLE, LAVA_BUBBLE }, night = {} } }),
	},
	dungeon_ashen = {
		room({
			tint = "#FFB080",
			tintMix = 0.4,
			saturation = 0.08,
			sounds = { day = { FURNACE_DEEP, LAVAFALL }, night = {} },
		}),
		room({ tint = "#FFB080", tintMix = 0.35, sounds = { day = { FURNACE_DEEP }, night = {} } }),
		room({
			tint = "#FFC8A0",
			tintMix = 0.45,
			sounds = { day = { FURNACE_DEEP, LAVAFALL, VOLCANO_RUMBLE }, night = {} },
		}),
	},
	-- S49
	duskwood_den = {
		room({ tint = "#FFE0B8", tintMix = 0.2, sounds = { day = { EARTH_CAVE, LANTERN_CREAK }, night = {} } }),
		room({
			tint = "#D8F0C0",
			tintMix = 0.3,
			saturation = -0.1,
			sounds = { day = { GNAWING, EARTH_CAVE }, night = {} },
		}),
		room({ tint = "#FFE4C0", tintMix = 0.25, haze = 0.3, sounds = { day = { BEAR_BREATH, BEES }, night = {} } }),
		room({
			brightness = 1.1,
			tint = "#D8E4FF",
			tintMix = 0.35,
			sounds = { day = { WOLF_ECHO, EARTH_CAVE }, night = {} },
		}),
		room({ tint = "#C8F0E8", tintMix = 0.3, sounds = { day = { DRIP_ECHO, EARTH_CAVE }, night = {} } }),
	},
	duskwood_barrow = {
		room({ tint = "#E0D0FF", tintMix = 0.25, sounds = { day = { TOMB_DRONE }, night = {} } }),
		room({ tint = "#D8B8FF", tintMix = 0.4, sounds = { day = { CULT_VOICES, MAGIC_FIRE }, night = {} } }),
		room({ brightness = 0.85, saturation = -0.2, sounds = { day = { DIGGING, TOMB_DRONE }, night = {} } }),
		room({
			tint = "#D0A8FF",
			tintMix = 0.45,
			saturation = 0.05,
			sounds = { day = { CULT_VOICES, MAGIC_FIRE }, night = {} },
		}),
		room({
			brightness = 0.8,
			tint = "#D8F0B8",
			tintMix = 0.25,
			sounds = { day = { GNAWING, DIGGING }, night = {} },
		}),
		room({
			fogScale = 0.7,
			tint = "#C8C0E0",
			tintMix = 0.3,
			sounds = { day = { DRIP_TOMB, SNAKE_HISS }, night = {} },
		}),
	},
	duskwood_cave = {
		room({ tint = "#D0E0FF", tintMix = 0.25, sounds = { day = { CRYPT_DRONE }, night = {} } }),
		room({
			tint = "#D0E8F0",
			tintMix = 0.25,
			fogScale = 1.2,
			sounds = { day = { CRYPT_DRONE, DRIP_TOMB }, night = {} },
		}),
		room({
			tint = "#C8F0FF",
			tintMix = 0.35,
			saturation = -0.3,
			sounds = { day = { GHOST_WAIL, CRYPT_DRONE }, night = {} },
		}),
		room({ tint = "#D0D8E8", tintMix = 0.25, sounds = { day = { BONES_CHAINS, CRYPT_DRONE }, night = {} } }),
		room({ tint = "#C0F0F0", tintMix = 0.4, sounds = { day = { GHOST_RISE, CRYPT_DRONE }, night = {} } }),
		room({ tint = "#FFE8C8", tintMix = 0.25, sounds = { day = { BONES_CHAINS, CRYPT_DRONE }, night = {} } }),
		room({ brightness = 0.8, saturation = -0.35, fogScale = 0.8, sounds = { day = { GHOST_WAIL }, night = {} } }),
		room({ tint = "#C8F0C8", tintMix = 0.4, sounds = { day = { NECRO_HUM, CRYPT_DRONE }, night = {} } }),
		room({ tint = "#D8C0FF", tintMix = 0.4, sounds = { day = { CHOIR_HUM }, night = {} } }),
	},
	dungeon_duskwood = {
		room({ tint = "#DCD0FF", tintMix = 0.35, sounds = { day = { ROYAL_DRONE }, night = {} } }),
		room({ tint = "#DCD0FF", tintMix = 0.3, sounds = { day = { ROYAL_DRONE }, night = {} } }),
		room({ tint = "#D0C0FF", tintMix = 0.45, sounds = { day = { ROYAL_DRONE, CHOIR_HUM }, night = {} } }),
	},
	dungeon_meadows = {
		room({
			tint = "#FFC8A0",
			tintMix = 0.4,
			saturation = 0.1,
			sounds = { day = { ARENA_DRUMS, FIRE_CRACKLE }, night = {} },
		}),
		room({ tint = "#FFD8B8", tintMix = 0.3, sounds = { day = { ARENA_DRUMS }, night = {} } }),
		room({ tint = "#FFB890", tintMix = 0.45, sounds = { day = { ARENA_DRUMS, FIRE_CRACKLE }, night = {} } }),
		room({ tint = "#FFC8A0", tintMix = 0.4, sounds = { day = { TRIBAL_DRUMS }, night = {} } }),
		room({ tint = "#FFC8A0", tintMix = 0.4, sounds = { day = { TRIBAL_DRUMS }, night = {} } }),
	},
}

-- Map-wide moods outside every area (paths between the areas keep the map's plain light).
local maps: { [string]: Mood } = {
	meadows = { sounds = { day = { BIRDS, WIND_GRASS }, night = { NIGHT_CRICKETS } } },
	duskwood = { sounds = { day = { OLD_TREES }, night = { DARK_FOREST_NIGHT } } },
	ashen = {
		sounds = {
			day = { DESERT_WIND },
			night = { DESERT_NIGHT_WIND, s("distant thunder rumble loop (dry storm, long gaps)", 0.25, IDS.THUNDER) },
		},
	},
	frostpeak = { sounds = { day = { MOUNTAIN_WIND }, night = { HOWLING_WIND } } },
	-- S48: the tunnels of the caves on the engine
	meadows_cave = { tint = "#D8FFD0", tintMix = 0.2, sounds = { day = { DRIP_ECHO, CAVE_WIND }, night = {} } },
	meadows_hideout = { sounds = { day = { DRIP_ECHO, CAVE_WIND }, night = {} } },
	meadows_burrow = { sounds = { day = { DRIP_ECHO, GOBLIN_CHATTER }, night = {} } },
	dungeon_meadows = { tint = "#FFC8A0", tintMix = 0.3, sounds = { day = { ARENA_DRUMS }, night = {} } },
	-- S51
	frostpeak_grotto = { tint = "#D8ECFF", tintMix = 0.25, sounds = { day = { ICE_CAVE }, night = {} } },
	frostpeak_hold = { tint = "#D4E2F4", tintMix = 0.25, sounds = { day = { FROZEN_CASTLE }, night = {} } },
	frostpeak_cave = { tint = "#CCF2FF", tintMix = 0.3, sounds = { day = { GLACIER_DEEP, HEARTBEAT }, night = {} } },
	dungeon_frostpeak = { tint = "#D6EEFF", tintMix = 0.3, sounds = { day = { LAIR_WIND }, night = {} } },
	-- S50
	ashen_mine = { tint = "#FFE8D0", tintMix = 0.2, sounds = { day = { SHAFT_WIND }, night = {} } },
	ashen_lair = { tint = "#FFD8C0", tintMix = 0.25, sounds = { day = { VOLCANO_RUMBLE }, night = {} } },
	ashen_cave = { tint = "#FFE0C8", tintMix = 0.25, sounds = { day = { VOLCANO_RUMBLE }, night = {} } },
	dungeon_ashen = { tint = "#FFB890", tintMix = 0.35, sounds = { day = { FURNACE_DEEP }, night = {} } },
	-- S49
	duskwood_den = { sounds = { day = { EARTH_CAVE }, night = {} } },
	duskwood_barrow = { tint = "#E0D0FF", tintMix = 0.2, sounds = { day = { TOMB_DRONE }, night = {} } },
	duskwood_cave = { tint = "#D0F0E8", tintMix = 0.2, sounds = { day = { CRYPT_DRONE }, night = {} } },
	dungeon_duskwood = { tint = "#DCD0FF", tintMix = 0.3, sounds = { day = { ROYAL_DRONE }, night = {} } },
}

-- Positional loops (map-relative).
local points: { [string]: { Point } } = {
	meadows = {
		{ x = 742, z = 268, radius = 160, sound = s("waterfall loop (medium, steady roar)", 0.7, IDS.WATERFALL_MED) },
		{ x = 600, z = 266, radius = 70, sound = STREAM },
		{ x = 250, z = 214, radius = 70, sound = STREAM },
		{ x = -100, z = 188, radius = 70, sound = STREAM },
		{ x = -246, z = 120, radius = 60, sound = STREAM },
		{
			x = 40,
			z = -150,
			radius = 70,
			sound = s("fire embers crackling loop (smouldering, quiet)", 0.4, IDS.FIRE_B),
		},
		{ x = 350, z = 470, radius = 80, sound = s("campfire crackle loop", 0.45, IDS.FIRE) },
		{
			x = 665,
			z = -410,
			radius = 150,
			sound = s("tribal drums loop (goblin camp, rhythmic)", 0.45, IDS.KODO),
			night = true,
		},
		{
			x = -652,
			z = -196,
			radius = 90,
			sound = s("farm animals loop (sheep, hens, distant)", 0.4, IDS.FARM),
			night = false,
		},
		{ x = -688, z = -182, radius = 30, sound = s("bees buzzing loop (hive)", 0.35, IDS.BEES), night = false },
		{ x = -480, z = 520, radius = 140, sound = s("lake shore water lapping loop", 0.35, IDS.LAKE_LAP) },
	},
	-- S45 (positions: Data/Areas/duskwood sites)
	duskwood = {
		{
			x = 604,
			z = -142,
			radius = 120,
			sound = s("small waterfall loop (thin cascade over rocks)", 0.55, IDS.WATERFALL_SMALL),
		},
		{ x = 389, z = -128, radius = 70, sound = STREAM },
		{ x = 200, z = -20, radius = 70, sound = STREAM },
		{ x = 596, z = -606, radius = 80, sound = s("magic fire loop (crackling, eerie hum)", 0.4, IDS.FIRE_WHOOSH) },
		{
			x = 560,
			z = -560,
			radius = 120,
			sound = s("cult chanting night loop (low voices, ritual)", 0.35),
			night = true,
		},
		{ x = 300, z = -82, radius = 40, sound = s("rope creaking loop (gallows, slow sway)", 0.3) },
		{ x = 4, z = -586, radius = 120, sound = s("single distant church bell toll loop (long gaps, eerie)", 0.3) },
		{ x = 702, z = 612, radius = 90, sound = s("big cauldron bubbling loop (thick, slow)", 0.4, IDS.LAB_BUBBLE) },
		{ x = -66, z = 122, radius = 60, sound = s("bubbling cauldron loop (small, magical)", 0.4, IDS.LAB_BUBBLE) },
		{ x = 66, z = 72, radius = 50, sound = s("wooden and bone wind chimes loop (hollow)", 0.35, IDS.CHIMES_GLASS) },
		{ x = 616, z = -40, radius = 90, sound = s("bat colony squeaks loop (cave, many bats)", 0.35), night = true },
		{ x = 150, z = 372, radius = 110, sound = s("rotting wood groans and bubbling mud loop (creepy forest)", 0.4) },
		{ x = 768, z = 0, radius = 80, sound = s("crypt wind howl loop (low, cold, stone)", 0.35, IDS.GODS_WIND) },
	},
	-- S46 (positions: Data/Areas/ashen sites, Data/Terrain/ashen lava)
	ashen = {
		{ x = 60, z = 262, radius = 80, sound = LAVA_BUBBLING },
		{ x = -182, z = 300, radius = 80, sound = LAVA_BUBBLING },
		{
			x = -60,
			z = 281,
			radius = 70,
			sound = s("lava flowing loop (slow, thick, crackling crust)", 0.4, IDS.ORGANIC),
		},
		{ x = 130, z = 100, radius = 150, sound = s("volcanic vent roar loop (deep, rumbling)", 0.5, IDS.LAVA_RUMBLE) },
		{ x = 92, z = 138, radius = 90, sound = s("lava fall loop (heavy pouring, hissing)", 0.5, IDS.LAVA_FIRE) },
		{ x = -590, z = -190, radius = 70, sound = LAVA_BUBBLING },
		{ x = -166, z = -540, radius = 80, sound = FORGE_HAMMERS },
		{ x = -250, z = -640, radius = 160, sound = WAR_DRUMS, night = true },
		{ x = -680, z = 304, radius = 60, sound = s("bubbling hot spring loop (water, steam hiss)", 0.4, IDS.JACUZZI) },
		{ x = 214, z = 604, radius = 80, sound = SMOULDER },
		{ x = 560, z = -560, radius = 140, sound = CRAG_WIND },
		{
			x = 752,
			z = 0,
			radius = 100,
			sound = s("dwarven forge deep loop (muffled hammers, bellows)", 0.45, IDS.ANVIL),
		},
		{ x = 610, z = 150, radius = 110, sound = DRONE_LOW, night = true },
	},
	-- S48 (caves on the engine; y over the floor)
	meadows_cave = {
		{ x = -290, z = 0, radius = 70, sound = WATERFALL_BEHIND },
		{ x = 58, z = 74, radius = 90, sound = UNDERGROUND_FALL },
		{ x = 158, z = -200, radius = 60, sound = SPIDER_CLICKS },
		{ x = 90, z = 278, radius = 60, sound = SHAMAN_CHANT },
		{ x = 253, z = 0, radius = 70, sound = TRIBAL_DRUMS },
	},
	meadows_hideout = {
		{ x = -110, z = -70, radius = 60, sound = STREAM_FLOW },
		{ x = -5, z = 72, radius = 50, sound = CROWS_SHAFT },
	},
	meadows_burrow = {
		{ x = 180, z = 0, radius = 50, sound = WINCH_CREAK },
		{ x = 7, z = -45, radius = 60, sound = PICKAXES },
	},
	-- S51
	frostpeak_grotto = {
		{ x = -205, z = 0, radius = 40, sound = BLIZZARD },
		{ x = -90, z = -42, radius = 30, sound = UNDER_ICE },
		{ x = 50, z = 80, radius = 50, sound = RAPTOR },
		{ x = -160, z = 20, radius = 30, sound = LANTERN_SWAY },
	},
	frostpeak_hold = {
		{ x = -80, z = 66, radius = 50, sound = BIG_FIRE },
		{ x = 7, z = -5, radius = 50, sound = CRYSTAL_HUM },
		{ x = 112, z = 100, radius = 40, sound = ICE_WHISPER },
	},
	frostpeak_cave = {
		{ x = 80, z = 170, radius = 50, sound = COINS },
		{ x = 280, z = 0, radius = 50, sound = DRAGON_ROAR },
	},
	dungeon_frostpeak = {
		{ x = -32, z = -32, radius = 24, sound = BRAZIER },
		{ x = 32, z = -32, radius = 24, sound = BRAZIER },
		{ x = -32, z = 28, radius = 24, sound = BRAZIER },
		{ x = 32, z = 28, radius = 24, sound = BRAZIER },
		{ x = 0, z = -110, radius = 60, sound = HIGH_WIND },
	},
	-- S50
	ashen_mine = {
		{ x = -114, z = -62, radius = 50, sound = CAGE_CHAIN },
		{ x = 6, z = 60, radius = 60, sound = CAMPFIRE },
		{ x = 116, z = 26, radius = 50, sound = VULTURE },
		{ x = 32, z = -116, radius = 40, sound = MAGMA_HISS },
	},
	ashen_lair = {
		{ x = -46, z = -89, radius = 40, sound = LAVA_BUBBLE },
		{ x = 13, z = 116, radius = 50, sound = SAND_POUR },
		{ x = 174, z = -14, radius = 70, sound = WIND_HOLE },
		{ x = 202, z = -162, radius = 50, sound = EGG_THROB },
	},
	ashen_cave = {
		{ x = -100, z = 0, radius = 80, sound = ANVILS },
		{ x = -100, z = -92, radius = 60, sound = LAVA_RIVER },
		{ x = -100, z = 92, radius = 60, sound = LAVA_RIVER },
		{ x = -110, z = -246, radius = 50, sound = LAVAFALL },
		{ x = -100, z = 236, radius = 50, sound = POUR_METAL },
		{ x = 110, z = 0, radius = 60, sound = HEART_THUMP },
	},
	dungeon_ashen = {
		{ x = 0, z = -134, radius = 100, sound = FURNACE_DEEP },
	},
	duskwood_den = {
		{ x = -175, z = -24, radius = 40, sound = LANTERN_CREAK },
		{ x = 25, z = -49, radius = 50, sound = BEES },
		{
			x = 134,
			z = -70,
			radius = 50,
			sound = s("wind through a hole in a cave roof loop (soft, night)", 0.25, IDS.BARSTOW_B),
		},
		{ x = -112, z = 120, radius = 40, sound = DRIP_ECHO },
	},
	duskwood_barrow = {
		{ x = -86, z = -18, radius = 60, sound = MAGIC_FIRE },
		{ x = 196, z = 50, radius = 60, sound = MAGIC_FIRE },
		{ x = -69, z = 140, radius = 60, sound = SNAKE_HISS },
	},
	duskwood_cave = {
		{ x = 40, z = -228, radius = 60, sound = GHOST_RISE },
		{ x = 150, z = 0, radius = 50, sound = NECRO_HUM },
		{ x = 262, z = 0, radius = 50, sound = CHOIR_HUM },
		{ x = 40, z = 0, radius = 60, sound = BONES_CHAINS },
	},
	dungeon_duskwood = {
		{ x = 0, z = -10, radius = 100, sound = s("chains creaking loop (chandelier, slow)", 0.25, IDS.WAGON_METAL) },
	},
	dungeon_meadows = {
		{ x = -100, z = -10, radius = 90, sound = ARENA_DRUMS },
		{ x = 100, z = -10, radius = 90, sound = ARENA_DRUMS },
	},
	-- S47 (positions: Data/Areas/frostpeak sites, streams and lakes)
	frostpeak = {
		{
			x = -610,
			z = 11,
			radius = 50,
			sound = s("water flowing under ice loop (muffled brook, gurgling)", 0.35, IDS.STREAM),
		},
		{
			x = -612,
			z = 80,
			radius = 50,
			sound = s("water flowing under ice loop (muffled brook, gurgling)", 0.35, IDS.STREAM),
		},
		{
			x = -555,
			z = -169,
			radius = 50,
			sound = s("old lantern creaking in the wind loop (metal, slow)", 0.3, IDS.WAGON_METAL),
		},
		{ x = 196, z = 104, radius = 130, sound = BIG_FIRE },
		{
			x = 22,
			z = 352,
			radius = 120,
			sound = s("ice cracking and creaking loop (frozen waterfall, icicles)", 0.4, IDS.WOOD_CRACK),
		},
		{
			x = 166,
			z = 584,
			radius = 60,
			sound = s("water splashing in an ice hole loop (small, cold)", 0.3, IDS.CAVE_LAP),
		},
		{ x = 300, z = 640, radius = 90, sound = CRYSTAL_HUM, night = true },
		{ x = 560, z = 0, radius = 70, sound = s("brazier fire loop (crackling, medium)", 0.35, IDS.FIRE) },
		{ x = 562, z = 570, radius = 80, sound = FLAG_CREAK },
		{
			x = 690,
			z = -650,
			radius = 220,
			sound = s("wind roaring over a mountain summit loop (very strong)", 0.5, IDS.BARSTOW),
		},
		{
			x = 745,
			z = 0,
			radius = 100,
			sound = s("deep glacier cracking loop (groaning ice, low booms)", 0.45, IDS.WOOD_CRACK),
		},
		-- S149b: the Forefather's Barrow (Data/WorldBoss.spots[1]): a faint choir over the wind, also while it stands empty
		{ x = 490, z = 360, radius = 90, sound = CHOIR_FAINT },
	},
}

-- S105: the city's seasons for one character (Logic/CitySeason; summer = no mood, as before): snow in the middle of
-- summer once the dragon is beaten, the first spring after the finale.
local seasons: { [string]: Mood } = {
	snow = {
		tint = "#DDE8F4",
		tintMix = 0.3,
		saturation = -0.08,
		sounds = {
			day = { s("soft winter wind in town loop (snow falling, quiet streets)", 0.35, IDS.BARSTOW_B) },
			night = { s("soft winter wind in town loop (snow falling, quiet streets)", 0.3, IDS.BARSTOW_B) },
		},
	},
	spring = {
		tint = "#FFF2DC",
		tintMix = 0.3,
		saturation = 0.1,
		brightness = 1.05,
		sounds = {
			day = { BIRDS, s("town spring celebration loop (distant bells, festive crowd, lute)", 0.35) },
			night = { NIGHT_CRICKETS },
		},
	},
}

local Ambience = {
	areas = areas,
	maps = maps,
	rooms = rooms,
	points = points,
	seasons = seasons, -- S105
	MAX_LOOPS = 3,
	BLEND = 2.5, -- seconds to blend from one mood to the next
}

-- S105: the city's mood in a season (summer = nil: the city as it always was).
function Ambience.cityMood(season: string): Mood?
	return seasons[season]
end

-- Mood of an area, else of the map (nil = plain map light, no loops).
function Ambience.moodOf(mapId: string, areaId: string?): Mood?
	return (areaId and areas[areaId]) or maps[mapId]
end

-- S48: mood of a room of a cave on the engine (nil: no entry; the caller falls back to the map's mood).
function Ambience.roomMood(mapId: string, index: number?): Mood?
	local list = rooms[mapId]
	return if list and index then list[index] else nil
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
	for _, list in { areas, maps, seasons } :: { { [string]: Mood } } do
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
	for _, list in rooms do
		for _, mood in list do
			for _, sound in mood.sounds.day do
				add(sound)
			end
		end
	end
	return out
end

return table.freeze(Ambience)
