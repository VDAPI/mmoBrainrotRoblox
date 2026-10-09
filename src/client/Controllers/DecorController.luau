--!strict
-- Client-only small decorations (S20, DESIGN §3.7): grass tufts, flowers, pebbles, mushrooms, ferns, reeds
-- by the water, fallen leaves; in caves stalactites, small crystals, webs and bones. Generated per chunk
-- (Config.DecorChunk studs) from the map id + chunk seed, so every client sees the same; only chunks within
-- the "World detail" radius exist. Parts come from a pool: unloading a chunk returns them instead of
-- destroying. The server never creates or replicates any of this.
-- S26: on maps whose areas name a decoration theme (Data/Areas `decor`) every item takes the theme of the area
-- under a randomly shifted point, so neighbouring themes mix over ~40 studs: meadow (flowers, tall grass), hills
-- (pebbles, dry tufts, bones, wool), marsh (reeds, cattails, lily pads on the water, mud), forest (ferns,
-- mushrooms, leaves, twigs), field (dry ears, stones), road, quarry (gravel, chips, planks), goblin (bones, hide
-- scraps) and ravine (moss, stones). On the Meadows shores come from the height function (Logic/MeadowsTerrain).
-- S45: Duskwood's themes (thicket, hollow, ruins, rot, cult, mist, bog, witch, cliffs) and, on every shaped region,
-- the theme and shores from its terrain (Logic/RegionTerrain).
-- S46: the Ashen Wastes' themes (ash, saltflat, warcamp, lavafield, burnt, dunes, crags, royalroad, necropolis): no
-- flowers or green grass there; nothing lies on lava.
-- S47: the Frost Peaks' themes (snowforest, snowfield, harpyrocks, giants, icelake, tundra, dragontemple, icefort,
-- wyrmpeak); frozen reeds and ice shards on the shores of the frozen lakes' ice.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AreaSpawns = require(ReplicatedStorage.Shared.Logic.AreaSpawns)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local MeadowsTerrain = require(ReplicatedStorage.Shared.Logic.MeadowsTerrain)
local RegionTerrain = require(ReplicatedStorage.Shared.Logic.RegionTerrain)
local State = require(script.Parent.Parent.UI.State)
local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)

local DecorController = {
	Name = "DecorController",
}

type Template = {
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	transparency: number?,
	lift: number, -- height above the ground of the part centre (negative: hanging from a ceiling)
	tilt: boolean?, -- random tilt (leaves, ferns)
	water: boolean?, -- only near water
	onWater: boolean?, -- S26: floats on the water surface (lily pads)
	ceiling: boolean?, -- hangs from the ceiling (caves)
}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end

local T: { [string]: Template } = {
	-- S45: Duskwood (roots, skulls, glowing mushrooms, candles, violet rags, serpent sheds, berries, fur, ivy, thorns)
	root = {
		size = Vector3.new(4, 0.6, 0.6),
		color = rgb("#3A2E24"),
		material = Enum.Material.Wood,
		lift = 0.15,
		tilt = true,
	},
	skull = {
		size = Vector3.new(0.9, 0.8, 1),
		color = rgb("#D8D0BA"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.3,
	},
	glowShroom = {
		size = Vector3.new(0.7, 0.4, 0.7),
		color = rgb("#7CFFC0"),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		lift = 0.35,
	},
	candle = {
		size = Vector3.new(0.3, 0.8, 0.3),
		color = rgb("#E8DCC0"),
		material = Enum.Material.Neon,
		lift = 0.4,
	},
	violetRag = {
		size = Vector3.new(1.2, 0.08, 0.9),
		color = rgb("#4A2A5E"),
		material = Enum.Material.Fabric,
		lift = 0.06,
		tilt = true,
	},
	shed = {
		size = Vector3.new(2.4, 0.12, 0.6),
		color = rgb("#CFC8A8"),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.3,
		lift = 0.08,
		tilt = true,
		water = true,
	},
	berries = {
		size = Vector3.one * 0.45,
		color = rgb("#A3222A"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.35,
	},
	fur = {
		size = Vector3.new(0.9, 0.4, 0.7),
		color = rgb("#6E6A64"),
		material = Enum.Material.Fabric,
		shape = Enum.PartType.Ball,
		lift = 0.2,
	},
	ivy = {
		size = Vector3.new(1.6, 0.1, 1.6),
		color = rgb("#2E4426"),
		material = Enum.Material.LeafyGrass,
		lift = 0.06,
		tilt = true,
	},
	thorn = {
		size = Vector3.new(0.15, 1.6, 0.15),
		color = rgb("#3A2A26"),
		material = Enum.Material.Wood,
		lift = 0.6,
		tilt = true,
	},
	redChip = {
		size = Vector3.new(0.9, 0.35, 0.7),
		color = rgb("#6E2F2A"),
		material = Enum.Material.Sandstone,
		lift = 0.1,
		tilt = true,
	},
	tuft = { size = Vector3.new(0.5, 1.1, 0.5), color = rgb("#5C8A3A"), material = Enum.Material.Grass, lift = 0.4 },
	tuftDark = {
		size = Vector3.new(0.5, 1.2, 0.5),
		color = rgb("#34502A"),
		material = Enum.Material.Grass,
		lift = 0.45,
	},
	tuftDry = { size = Vector3.new(0.5, 0.9, 0.5), color = rgb("#B8A060"), material = Enum.Material.Grass, lift = 0.35 },
	flowerY = {
		size = Vector3.one * 0.6,
		color = rgb("#F2E8A0"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.5,
	},
	flowerP = {
		size = Vector3.one * 0.6,
		color = rgb("#E8A0C9"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.5,
	},
	flowerB = {
		size = Vector3.one * 0.55,
		color = rgb("#8FB8F0"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.45,
	},
	pebble = {
		size = Vector3.new(1, 0.5, 0.8),
		color = rgb("#8A8478"),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Ball,
		lift = 0.1,
	},
	pebbleSnow = {
		size = Vector3.new(1, 0.5, 0.8),
		color = rgb("#A8B8C8"),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Ball,
		lift = 0.1,
	},
	pebbleRed = {
		size = Vector3.new(1, 0.5, 0.8),
		color = rgb("#7A4A3A"),
		material = Enum.Material.Basalt,
		shape = Enum.PartType.Ball,
		lift = 0.1,
	},
	mushroom = {
		size = Vector3.new(0.8, 0.5, 0.8),
		color = rgb("#B8423A"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.5,
	},
	fern = {
		size = Vector3.new(1.8, 0.15, 0.7),
		color = rgb("#3F6B2E"),
		material = Enum.Material.Grass,
		lift = 0.4,
		tilt = true,
	},
	leaf = {
		size = Vector3.new(0.9, 0.08, 0.9),
		color = rgb("#A0602A"),
		material = Enum.Material.SmoothPlastic,
		lift = 0.05,
		tilt = true,
	},
	reed = {
		size = Vector3.new(0.2, 3, 0.2),
		color = rgb("#7A8A4A"),
		material = Enum.Material.Grass,
		lift = 1.4,
		water = true,
	},
	bone = {
		size = Vector3.new(1.4, 0.25, 0.25),
		color = rgb("#E8E2D0"),
		material = Enum.Material.SmoothPlastic,
		lift = 0.12,
		tilt = true,
	},
	stalactite = {
		size = Vector3.new(0.8, 3.2, 0.8),
		color = rgb("#5A5650"),
		material = Enum.Material.Slate,
		lift = -1.6,
		ceiling = true,
	},
	crystal = {
		size = Vector3.new(0.5, 1.4, 0.5),
		color = rgb("#9FE0FF"),
		material = Enum.Material.Neon,
		lift = 0.6,
		tilt = true,
	},
	-- S26: area themes
	flowerW = {
		size = Vector3.one * 0.55,
		color = rgb("#EEEADA"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.45,
	},
	tallGrass = {
		size = Vector3.new(0.6, 2.2, 0.6),
		color = rgb("#6E9A44"),
		material = Enum.Material.Grass,
		lift = 0.9,
		tilt = true,
	},
	lily = {
		size = Vector3.new(1.7, 0.08, 1.5),
		color = rgb("#4E7A36"),
		material = Enum.Material.SmoothPlastic,
		lift = 0.05,
		onWater = true,
	},
	lilyFlower = {
		size = Vector3.one * 0.5,
		color = rgb("#F2E6EE"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.2,
		onWater = true,
	},
	cattail = {
		size = Vector3.new(0.25, 3.6, 0.25),
		color = rgb("#6E7A3E"),
		material = Enum.Material.Grass,
		lift = 1.7,
		water = true,
		tilt = true,
	},
	mudClump = {
		size = Vector3.new(1.4, 0.4, 1.1),
		color = rgb("#3F3A2E"),
		material = Enum.Material.Mud,
		shape = Enum.PartType.Ball,
		lift = 0.05,
	},
	dryEar = {
		size = Vector3.new(0.3, 1.8, 0.3),
		color = rgb("#B8A060"),
		material = Enum.Material.Grass,
		lift = 0.8,
		tilt = true,
	},
	stone = {
		size = Vector3.new(1.6, 0.9, 1.3),
		color = rgb("#7A766E"),
		material = Enum.Material.Slate,
		lift = 0.25,
		tilt = true,
	},
	gravel = {
		size = Vector3.new(2.2, 0.25, 1.8),
		color = rgb("#8E887C"),
		material = Enum.Material.Pebble,
		lift = 0.05,
		tilt = true,
	},
	chip = {
		size = Vector3.new(0.8, 0.5, 0.6),
		color = rgb("#6E6A64"),
		material = Enum.Material.Slate,
		lift = 0.2,
		tilt = true,
	},
	plank = {
		size = Vector3.new(3, 0.2, 0.7),
		color = rgb("#6B5038"),
		material = Enum.Material.WoodPlanks,
		lift = 0.1,
		tilt = true,
	},
	hide = {
		size = Vector3.new(1.6, 0.08, 1.2),
		color = rgb("#7A5A3E"),
		material = Enum.Material.Fabric,
		lift = 0.05,
		tilt = true,
	},
	moss = {
		size = Vector3.new(2, 0.2, 1.6),
		color = rgb("#4F6B35"),
		material = Enum.Material.LeafyGrass,
		shape = Enum.PartType.Ball,
		lift = 0.05,
	},
	wool = {
		size = Vector3.new(0.9, 0.5, 0.8),
		color = rgb("#E2DCCC"),
		material = Enum.Material.Fabric,
		shape = Enum.PartType.Ball,
		lift = 0.2,
	},
	twig = {
		size = Vector3.new(2, 0.15, 0.15),
		color = rgb("#4A3A2C"),
		material = Enum.Material.Wood,
		lift = 0.08,
		tilt = true,
	},
	feather = {
		size = Vector3.new(0.9, 0.05, 0.25),
		color = rgb("#1A1A1E"),
		material = Enum.Material.SmoothPlastic,
		lift = 0.05,
		tilt = true,
	},
	web = {
		size = Vector3.new(3, 3, 0.05),
		color = rgb("#E8E8F0"),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.7,
		lift = 2.5,
		tilt = true,
	},
}

-- Weighted templates and items per chunk by biome.
local BIOMES: { [string]: { count: number, mix: { { string | number } } } } = {
	-- S21: the starting city; only on grass (never on paving), sparse inside the walls, denser outside.
	city = {
		count = 30,
		mix = {
			{ "tuft", 10 },
			{ "tuftDark", 4 },
			{ "flowerY", 2 },
			{ "flowerP", 2 },
			{ "flowerB", 1 },
			{ "pebble", 3 },
			{ "fern", 1 },
		},
	},
	grass = {
		count = 34,
		mix = {
			{ "tuft", 10 },
			{ "flowerY", 3 },
			{ "flowerP", 3 },
			{ "flowerB", 2 },
			{ "pebble", 3 },
			{ "mushroom", 1 },
			{ "fern", 2 },
			{ "reed", 3 },
		},
	},
	forest = {
		count = 30,
		mix = { { "tuftDark", 8 }, { "fern", 6 }, { "mushroom", 3 }, { "leaf", 6 }, { "pebble", 2 }, { "reed", 2 } },
	},
	desert = { count = 16, mix = { { "tuftDry", 6 }, { "pebbleRed", 6 }, { "bone", 2 } } },
	snow = { count = 18, mix = { { "pebbleSnow", 6 }, { "tuftDry", 3 }, { "crystal", 1 } } },
	cave = { count = 14, mix = { { "stalactite", 5 }, { "pebble", 4 }, { "crystal", 2 }, { "web", 1 }, { "bone", 2 } } },
	crypt = {
		count = 14,
		mix = { { "stalactite", 3 }, { "pebble", 3 }, { "bone", 4 }, { "web", 3 }, { "crystal", 1 } },
	},
}

-- S46: the Ashen Wastes (ash heaps, charred twigs, basalt and obsidian, salt plates, mud flakes, broken weapons,
-- rusty scrap, rags, slag, glowing coals, charred planks, potsherds, scorched bricks, sand ripples, carapaces, wyvern
-- scales, slab and statue chips, coins, linen strips, turquoise pebbles).
local function item(size: Vector3, color: string, material: Enum.Material, lift: number, tilt: boolean?): Template
	return { size = size, color = rgb(color), material = material, lift = lift, tilt = tilt }
end
T.ashHeap = item(Vector3.new(2.2, 0.5, 1.8), "#8A8480", Enum.Material.Slate, 0.1)
T.charTwig = item(Vector3.new(2.2, 0.18, 0.18), "#1F1B19", Enum.Material.Wood, 0.08, true)
T.basaltPebble = item(Vector3.new(0.9, 0.5, 0.7), "#2E2A2C", Enum.Material.Basalt, 0.15, true)
T.obsidian = item(Vector3.new(0.9, 0.7, 0.4), "#16141C", Enum.Material.Glass, 0.25, true)
T.saltPlate = item(Vector3.new(1.8, 0.12, 1.4), "#E2DACB", Enum.Material.SmoothPlastic, 0.05, true)
T.mudFlake = item(Vector3.new(1.4, 0.15, 1.1), "#7A6A4E", Enum.Material.Ground, 0.06, true)
T.palmLeaf = item(Vector3.new(3.4, 0.08, 0.7), "#7A6A50", Enum.Material.Grass, 0.05, true)
T.brokenArrow = item(Vector3.new(2, 0.1, 0.1), "#4A3A2C", Enum.Material.Wood, 0.06, true)
T.spear = item(Vector3.new(4.2, 0.15, 0.15), "#3A2E24", Enum.Material.Wood, 0.08, true)
T.scrap = item(Vector3.new(1.2, 0.3, 0.9), "#6A3A26", Enum.Material.CorrodedMetal, 0.12, true)
T.rag = item(Vector3.new(1.4, 0.06, 1), "#6B5048", Enum.Material.Fabric, 0.04, true)
T.slag = item(Vector3.new(1, 0.5, 0.8), "#3A2E2A", Enum.Material.Basalt, 0.2, true)
T.coal = {
	size = Vector3.new(0.35, 0.25, 0.35),
	color = rgb("#FF6A1A"),
	material = Enum.Material.Neon,
	lift = 0.1,
}
T.sulphur = item(Vector3.new(1.6, 0.08, 1.2), "#D8C04A", Enum.Material.Sand, 0.04)
T.charPlank = item(Vector3.new(3, 0.2, 0.6), "#24201C", Enum.Material.WoodPlanks, 0.1, true)
T.sherd = item(Vector3.new(0.6, 0.12, 0.5), "#9A5A3A", Enum.Material.SmoothPlastic, 0.06, true)
T.brick = item(Vector3.new(1, 0.5, 0.5), "#4A3A34", Enum.Material.Brick, 0.2, true)
T.soot = item(Vector3.new(2.4, 0.04, 1.8), "#1A1716", Enum.Material.Slate, 0.02)
T.ripple = item(Vector3.new(4, 0.12, 0.6), "#B89A6A", Enum.Material.Sand, 0.02)
T.carapace = item(Vector3.new(1.2, 0.35, 1.6), "#C29A5B", Enum.Material.SmoothPlastic, 0.15, true)
T.scale = item(Vector3.new(0.6, 0.06, 0.5), "#8A3A2A", Enum.Material.SmoothPlastic, 0.04, true)
T.scorch = item(Vector3.new(1.2, 0.6, 1), "#2A2420", Enum.Material.Slate, 0.2, true)
T.slabChip = item(Vector3.new(1.6, 0.4, 1.2), "#7A7468", Enum.Material.Slate, 0.15, true)
T.statueChip = item(Vector3.new(1.2, 1, 1), "#8A8680", Enum.Material.Slate, 0.4, true)
T.coin = item(Vector3.new(0.5, 0.08, 0.5), "#C9A45C", Enum.Material.Metal, 0.04)
T.linen = item(Vector3.new(1.6, 0.04, 0.4), "#D8C9A0", Enum.Material.Fabric, 0.03, true)
T.turquoise = {
	size = Vector3.new(0.35, 0.3, 0.35),
	color = rgb("#6BE0FF"),
	material = Enum.Material.Neon,
	lift = 0.12,
}

-- S47: the Frost Peaks (snow lumps, ice shards, pine cones and twigs, frozen reeds on the shores of the ice, scales
-- of the dragonspawn and the wyrms, tufts of fur, footprints, broken shafts, ice spikes).
T.snowLump = item(Vector3.new(1.6, 0.7, 1.3), "#EEF3F7", Enum.Material.Snow, 0.2, true)
T.iceShard = {
	size = Vector3.new(0.6, 1.4, 0.5),
	color = rgb("#BFE6F7"),
	material = Enum.Material.Ice,
	lift = 0.5,
	tilt = true,
	transparency = 0.2,
}
T.pineCone = item(Vector3.new(0.4, 0.6, 0.4), "#4A3424", Enum.Material.Wood, 0.2, true)
T.pineTwig = item(Vector3.new(1.8, 0.16, 0.16), "#2E3A2A", Enum.Material.Grass, 0.06, true)
T.frozenReed = {
	size = Vector3.new(0.18, 3, 0.18),
	color = rgb("#B8B49A"),
	material = Enum.Material.Grass,
	lift = 1.2,
	tilt = true,
	water = true,
}
T.scaleNavy = item(Vector3.new(0.6, 0.06, 0.5), "#3A4A6B", Enum.Material.SmoothPlastic, 0.04, true)
T.scaleIce = item(Vector3.new(0.7, 0.06, 0.6), "#7FD4FF", Enum.Material.SmoothPlastic, 0.04, true)
T.furBrown = item(Vector3.new(0.8, 0.4, 0.6), "#7A6A5A", Enum.Material.Fabric, 0.15, true)
T.furPale = item(Vector3.new(0.8, 0.4, 0.6), "#C8DDEB", Enum.Material.Fabric, 0.15, true)
T.track = item(Vector3.new(1.2, 0.05, 1.8), "#AFC0CC", Enum.Material.Snow, 0.02)
T.shaft = item(Vector3.new(3.4, 0.16, 0.16), "#4A3E34", Enum.Material.Wood, 0.08, true)
T.iceSpike = {
	size = Vector3.new(0.7, 2.6, 0.7),
	color = rgb("#BFE6F7"),
	material = Enum.Material.Ice,
	lift = 1,
	tilt = true,
	transparency = 0.15,
}
T.frostStone = item(Vector3.new(1.2, 0.7, 1), "#8E9CA8", Enum.Material.Slate, 0.2, true)

-- Area themes (S26, Data/Areas `decor`): items per chunk and the mix.
local THEMES: { [string]: { count: number, mix: { { string | number } } } } = {
	meadow = {
		count = 44,
		mix = {
			{ "tuft", 8 },
			{ "tallGrass", 5 },
			{ "flowerY", 4 },
			{ "flowerP", 4 },
			{ "flowerB", 3 },
			{ "flowerW", 3 },
			{ "pebble", 1 },
		},
	},
	hills = {
		count = 34,
		mix = {
			{ "tuft", 6 },
			{ "tuftDry", 4 },
			{ "pebble", 5 },
			{ "stone", 3 },
			{ "bone", 1 },
			{ "wool", 1 },
			{ "flowerB", 1 },
		},
	},
	marsh = {
		count = 40,
		mix = {
			{ "reed", 8 },
			{ "cattail", 5 },
			{ "tuftDark", 5 },
			{ "mudClump", 4 },
			{ "lily", 7 },
			{ "lilyFlower", 2 },
			{ "twig", 1 },
		},
	},
	forest = {
		count = 40,
		mix = {
			{ "fern", 7 },
			{ "mushroom", 4 },
			{ "leaf", 6 },
			{ "tuftDark", 5 },
			{ "twig", 3 },
			{ "moss", 2 },
			{ "feather", 1 },
		},
	},
	field = {
		count = 36,
		mix = { { "dryEar", 10 }, { "tuftDry", 6 }, { "stone", 2 }, { "pebble", 2 }, { "feather", 2 } },
	},
	road = {
		count = 30,
		mix = {
			{ "tuft", 8 },
			{ "tallGrass", 2 },
			{ "flowerY", 2 },
			{ "flowerP", 1 },
			{ "pebble", 3 },
			{ "tuftDry", 2 },
		},
	},
	quarry = {
		count = 28,
		mix = { { "gravel", 7 }, { "chip", 6 }, { "pebble", 4 }, { "plank", 2 }, { "tuftDry", 2 } },
	},
	goblin = {
		count = 28,
		mix = { { "bone", 5 }, { "hide", 3 }, { "tuftDry", 4 }, { "twig", 3 }, { "pebble", 2 }, { "mudClump", 1 } },
	},
	ravine = {
		count = 32,
		mix = { { "moss", 6 }, { "stone", 4 }, { "fern", 3 }, { "pebble", 4 }, { "tuftDark", 3 }, { "reed", 2 } },
	},
}
-- S45: Duskwood's areas.
THEMES.thicket = {
	count = 40,
	mix = {
		{ "fern", 6 },
		{ "root", 5 },
		{ "tuftDark", 5 },
		{ "leaf", 5 },
		{ "moss", 3 },
		{ "thorn", 3 },
		{ "fur", 1 },
		{ "bone", 1 },
	},
}
THEMES.hollow = {
	count = 40,
	mix = { { "fern", 8 }, { "moss", 5 }, { "root", 5 }, { "berries", 3 }, { "stone", 3 }, { "twig", 3 }, { "fur", 1 } },
}
THEMES.ruins = {
	count = 34,
	mix = {
		{ "ivy", 6 },
		{ "stone", 4 },
		{ "tuftDark", 4 },
		{ "web", 2 },
		{ "skull", 2 },
		{ "bone", 2 },
		{ "leaf", 3 },
	},
}
THEMES.rot = {
	count = 38,
	mix = {
		{ "glowShroom", 5 },
		{ "mushroom", 4 },
		{ "root", 5 },
		{ "mudClump", 4 },
		{ "moss", 4 },
		{ "bone", 2 },
		{ "leaf", 3 },
	},
}
THEMES.cult = {
	count = 28,
	mix = {
		{ "tuftDry", 5 },
		{ "violetRag", 3 },
		{ "candle", 2 },
		{ "bone", 2 },
		{ "twig", 3 },
		{ "pebble", 3 },
		{ "shed", 2 },
	},
}
THEMES.mist = {
	count = 34,
	mix = {
		{ "tuftDark", 6 },
		{ "reed", 4 },
		{ "shed", 3 },
		{ "leaf", 4 },
		{ "stone", 2 },
		{ "violetRag", 1 },
		{ "fern", 3 },
	},
}
THEMES.bog = {
	count = 40,
	mix = {
		{ "reed", 8 },
		{ "cattail", 5 },
		{ "mudClump", 6 },
		{ "lily", 5 },
		{ "root", 3 },
		{ "shed", 2 },
		{ "bone", 1 },
		{ "tuftDark", 4 },
	},
}
THEMES.witch = {
	count = 38,
	mix = {
		{ "reed", 6 },
		{ "glowShroom", 4 },
		{ "candle", 2 },
		{ "skull", 2 },
		{ "mudClump", 4 },
		{ "lily", 4 },
		{ "tuftDark", 4 },
		{ "twig", 3 },
	},
}
THEMES.cliffs = {
	count = 30,
	mix = { { "redChip", 7 }, { "thorn", 4 }, { "pebbleRed", 4 }, { "bone", 3 }, { "tuftDry", 4 } },
}

-- S46: the Ashen Wastes' areas.
THEMES.ash = {
	count = 26,
	mix = { { "ashHeap", 5 }, { "charTwig", 5 }, { "basaltPebble", 5 }, { "bone", 2 }, { "tuftDry", 2 }, { "soot", 2 } },
}
THEMES.saltflat = {
	count = 26,
	mix = { { "saltPlate", 7 }, { "mudFlake", 6 }, { "bone", 3 }, { "palmLeaf", 3 }, { "tuftDry", 1 } },
}
THEMES.warcamp = {
	count = 28,
	mix = { { "bone", 5 }, { "brokenArrow", 4 }, { "spear", 2 }, { "scrap", 4 }, { "rag", 3 }, { "ashHeap", 2 } },
}
THEMES.lavafield = {
	count = 26,
	mix = { { "obsidian", 6 }, { "slag", 5 }, { "coal", 3 }, { "sulphur", 3 }, { "basaltPebble", 5 } },
}
THEMES.burnt = {
	count = 30,
	mix = { { "charPlank", 6 }, { "sherd", 5 }, { "brick", 5 }, { "soot", 3 }, { "ashHeap", 3 }, { "coal", 1 } },
}
THEMES.dunes = {
	count = 22,
	mix = { { "ripple", 8 }, { "carapace", 3 }, { "tuftDry", 3 }, { "sherd", 2 } },
}
THEMES.crags = {
	count = 26,
	mix = { { "redChip", 6 }, { "scale", 4 }, { "bone", 3 }, { "scorch", 4 }, { "pebbleRed", 4 } },
}
THEMES.royalroad = {
	count = 24,
	mix = { { "slabChip", 6 }, { "statueChip", 3 }, { "coin", 1 }, { "ashHeap", 3 }, { "tuftDry", 2 } },
}
THEMES.necropolis = {
	count = 22,
	mix = { { "sherd", 5 }, { "linen", 4 }, { "ripple", 4 }, { "pebble", 3 }, { "turquoise", 1 } },
}

-- S47: the Frost Peaks' areas (no flowers or green grass).
THEMES.snowforest = {
	count = 30,
	mix = {
		{ "snowLump", 6 },
		{ "pineCone", 4 },
		{ "pineTwig", 5 },
		{ "track", 3 },
		{ "furPale", 1 },
		{ "frozenReed", 2 },
	},
}
THEMES.snowfield = {
	count = 24,
	mix = { { "snowLump", 6 }, { "frostStone", 5 }, { "pebbleSnow", 5 }, { "track", 2 } },
}
THEMES.harpyrocks = {
	count = 24,
	mix = { { "feather", 6 }, { "frostStone", 5 }, { "bone", 3 }, { "snowLump", 3 }, { "frozenReed", 2 } },
}
THEMES.giants = {
	count = 24,
	mix = { { "stone", 5 }, { "bone", 4 }, { "pebbleSnow", 5 }, { "snowLump", 3 }, { "furBrown", 1 } },
}
THEMES.icelake = {
	count = 24,
	mix = { { "iceShard", 5 }, { "frozenReed", 6 }, { "snowLump", 5 }, { "furBrown", 1 } },
}
THEMES.tundra = {
	count = 22,
	mix = { { "tuftDry", 6 }, { "gravel", 4 }, { "bone", 3 }, { "furBrown", 3 }, { "snowLump", 2 } },
}
THEMES.dragontemple = {
	count = 24,
	mix = { { "slabChip", 6 }, { "scaleNavy", 4 }, { "coin", 1 }, { "snowLump", 3 }, { "iceShard", 2 } },
}
THEMES.icefort = {
	count = 24,
	mix = { { "stone", 5 }, { "iceShard", 5 }, { "shaft", 3 }, { "snowLump", 3 }, { "track", 2 } },
}
THEMES.wyrmpeak = {
	count = 22,
	mix = { { "iceSpike", 5 }, { "scaleIce", 4 }, { "bone", 3 }, { "snowLump", 4 } },
}

local THEME_MAX = 44
local THEME_JITTER = 40

-- Share of the city biome's items kept inside the walls (the streets are busy; outside it grows freely).
local CITY_INSIDE_SHARE = 0.4

local folder: Folder
local pool: { [string]: { BasePart } } = {}
local chunks: { [string]: { BasePart } } = {}
local currentMap: string? = nil
local frameTime = 0

local function acquire(key: string): BasePart
	local list = pool[key]
	local part = list and table.remove(list)
	if part then
		return part
	end
	local template = T[key]
	local p = Instance.new("Part")
	p.Name = key
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = template.size
	p.Color = template.color
	p.Material = template.material
	p.Transparency = template.transparency or 0
	if template.shape then
		p.Shape = template.shape
	end
	return p
end

local function release(part: BasePart)
	part.Parent = nil
	local list = pool[part.Name]
	if not list then
		list = {}
		pool[part.Name] = list
	end
	table.insert(list, part)
end

local function seedOf(text: string): number
	local seed = 17
	for i = 1, #text do
		seed = (seed * 31 + string.byte(text, i)) % 2147483647
	end
	return seed
end

local function pick(mix: { { string | number } }, rng: Random): string
	local total = 0
	for _, entry in mix do
		total += entry[2] :: number
	end
	local roll = rng:NextNumber() * total
	for _, entry in mix do
		roll -= entry[2] :: number
		if roll <= 0 then
			return entry[1] :: string
		end
	end
	return mix[1][1] :: string
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = false

-- Inside a cave room (caves only have decorations in their rooms).
local function inRoom(rooms: { any }?, x: number, z: number): boolean
	if not rooms then
		return true
	end
	for _, room in rooms do
		if (x - room.x) ^ 2 + (z - room.z) ^ 2 < (room.r * 0.9) ^ 2 then
			return true
		end
	end
	return false
end

local function nearWater(lakes: { any }?, x: number, z: number): boolean
	for _, lake in (lakes or {}) :: { any } do
		local d = math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2)
		if d > lake.r - 4 and d < lake.r + 10 then
			return true
		end
	end
	return false
end

-- Decoration theme at a point (S26): the `decor` of the area under the point shifted by up to THEME_JITTER studs,
-- else (outside every area) the Meadows' surface theme, else nil (the map's biome).
local function themeAt(map: Maps.MapDef, areas: any, x: number, z: number, rng: Random): string?
	if not areas then
		return nil
	end
	local jx = x + (rng:NextNumber() - 0.5) * 2 * THEME_JITTER
	local jz = z + (rng:NextNumber() - 0.5) * 2 * THEME_JITTER
	local area = Areas.areaAt(map.id, jx, jz)
	if area and area.decor then
		-- the toad mire is a marsh only around the water; its drier edges look like a meadow
		if area.decor == "marsh" and map.id == "meadows" and MeadowsTerrain.marshWeight(x, z) < 0.35 then
			return "meadow"
		end
		return area.decor
	end
	if map.id == "meadows" then
		local theme = MeadowsTerrain.themeAt(x, z)
		return if THEMES[theme] then theme elseif theme == "wet" then "meadow" else nil
	end
	-- S45: shaped regions: the surface theme of their terrain
	local region = RegionTerrain.get(map.id)
	if region then
		local theme = region.themeAt(x, z)
		return if THEMES[theme] then theme else nil
	end
	return nil
end

-- Shore of a stream, a lake or a marsh pool on the Meadows (from the height function); other maps: lake circles.
local function shore(map: Maps.MapDef, areas: any, x: number, z: number): boolean
	if map.id == "meadows" then
		local sd = MeadowsTerrain.streamDistance(x, z)
		local ld = MeadowsTerrain.lakeDistance(x, z)
		return (sd > -0.5 and sd < 5) or (ld > -1.5 and ld < 6) or MeadowsTerrain.marshWeight(x, z) > 0.55
	end
	local region = RegionTerrain.get(map.id)
	if region then
		local sd = region.streamDistance(x, z)
		local ld = region.lakeDistance(x, z)
		if (sd > -0.5 and sd < 5) or (ld > -1.5 and ld < 6) or region.marshWeight(x, z) > 0.4 then
			return true
		end
		-- S47: the snowy shore of a sheet of ice (frozen lakes; the `lakes` circles are only ice holes there)
		if region.shape.frozenLakes and region.ice(x, z) == nil then
			for _, o in { { 6, 0 }, { -6, 0 }, { 0, 6 }, { 0, -6 } } do
				if region.ice(x + o[1], z + o[2]) ~= nil then
					return true
				end
			end
		end
		return false
	end
	return areas ~= nil and nearWater(areas.lakes, x, z)
end

local function buildChunk(map: Maps.MapDef, cx: number, cz: number): { BasePart }
	local parts: { BasePart } = {}
	local biome = BIOMES[map.biome]
	if not biome then
		return parts
	end
	local themed = Areas.byMap[map.id] ~= nil and Areas.byMap[map.id].areas[1].decor ~= nil
	local rng = Random.new(seedOf(`{map.id}:{cx}:{cz}`))
	local size = Config.DecorChunk
	local areas = Areas.byMap[map.id]
	local cave = Areas.caves.get(map.id)
	local rooms = if cave then AreaSpawns.caveRooms(cave) else nil
	local inCave = map.biome == "cave" or map.biome == "crypt"
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	for _ = 1, if themed then THEME_MAX else biome.count do
		local x = cx * size + rng:NextNumber() * size
		local z = cz * size + rng:NextNumber() * size
		local mix = biome.mix
		if themed then
			local theme = THEMES[themeAt(map, areas, x, z, rng) or ""]
			if theme then
				if rng:NextNumber() * THEME_MAX > theme.count then
					continue
				end
				mix = theme.mix
			elseif rng:NextNumber() * THEME_MAX > biome.count then
				continue
			end
		end
		local key = pick(mix, rng)
		local template = T[key]
		if math.abs(x) > map.size.x / 2 - 4 or math.abs(z) > map.size.z / 2 - 4 then
			continue
		end
		if inCave and not inRoom(rooms, x, z) then
			continue
		end
		if areas then
			if template.water and not shore(map, areas, x, z) then
				continue
			end
			if AreaSpawns.nearRoad(areas.roads, x, z, 1) then
				continue
			end
		elseif template.water then
			continue
		end
		local inCity = map.biome == "city"
		local insideWalls = inCity and TownTerrain.insideWalls(x, z)
		if insideWalls and (rng:NextNumber() > CITY_INSIDE_SHARE or not TownTerrain.isOpen(x, z, 1)) then
			continue
		end
		local from = origin + Vector3.new(x, if inCave then 4 else 120, z)
		local hit = Workspace:Raycast(from, Vector3.new(0, -200, 0), rayParams)
		if not hit or (hit.Material == Enum.Material.Water) ~= (template.onWater == true) then
			continue
		end
		-- S46: nothing lies on lava
		if hit.Material == Enum.Material.CrackedLava then
			continue
		end
		if inCity and hit.Material ~= Enum.Material.Grass and hit.Material ~= Enum.Material.LeafyGrass then
			continue
		end
		local position = hit.Position
		if template.ceiling then
			local up = Workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, 60, 0), rayParams)
			if not up then
				continue
			end
			position = up.Position
		end
		local yaw = rng:NextNumber() * math.pi * 2
		local cframe = CFrame.new(position + Vector3.new(0, template.lift, 0)) * CFrame.Angles(0, yaw, 0)
		if template.tilt then
			cframe *= CFrame.Angles((rng:NextNumber() - 0.5) * 0.6, 0, (rng:NextNumber() - 0.5) * 0.6)
		end
		local part = acquire(key)
		part.CFrame = cframe
		part.Parent = folder
		table.insert(parts, part)
	end
	return parts
end

local function unloadAll()
	for key, parts in chunks do
		for _, part in parts do
			release(part)
		end
		chunks[key] = nil
	end
end

local function radius(): number
	local setting = State.Get({ "account", "settings", "decor" })
	return (Config.DecorRadius :: any)[setting or "mid"] or Config.DecorRadius.mid
end

-- Loads up to `budget` missing chunks around the player and unloads far ones.
local function update(budget: number)
	local mapId = State.Get({ "character", "location", "map" })
	local map = type(mapId) == "string" and Maps.get(mapId) or nil
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not map or not root then
		return
	end
	if map.id ~= currentMap then
		unloadAll()
		currentMap = map.id
	end
	local size = Config.DecorChunk
	local reach = radius()
	local px, pz = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	local wanted: { [string]: { number } } = {}
	local minX, maxX = math.floor((px - reach) / size), math.floor((px + reach) / size)
	local minZ, maxZ = math.floor((pz - reach) / size), math.floor((pz + reach) / size)
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local mx, mz = (cx + 0.5) * size, (cz + 0.5) * size
			if (mx - px) ^ 2 + (mz - pz) ^ 2 <= (reach + size * 0.7) ^ 2 then
				wanted[`{cx}:{cz}`] = { cx, cz, (mx - px) ^ 2 + (mz - pz) ^ 2 }
			end
		end
	end
	for key, parts in chunks do
		if not wanted[key] then
			for _, part in parts do
				release(part)
			end
			chunks[key] = nil
		end
	end
	-- Nearest missing chunks first.
	local missing = {}
	for key, c in wanted do
		if not chunks[key] then
			table.insert(missing, { key = key, cx = c[1], cz = c[2], d = c[3] })
		end
	end
	table.sort(missing, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(budget, #missing) do
		local c = missing[i]
		chunks[c.key] = buildChunk(map, c.cx, c.cz)
	end
end

-- Active chunks and pooled parts (admin /perf on the client).
function DecorController.Stats(): (number, number, number)
	local active, parts = 0, 0
	for _, list in chunks do
		active += 1
		parts += #list
	end
	return active, parts, frameTime
end

function DecorController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_ClientDecor"
	folder.Parent = Workspace
end

function DecorController.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		frameTime = frameTime * 0.9 + dt * 0.1
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local ok, err = pcall(function()
			update(2)
		end)
		if not ok then
			warn(`[DecorController] {err}`)
		end
	end)
end

return DecorController
