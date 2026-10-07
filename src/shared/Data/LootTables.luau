--!strict
-- Loot tables (DESIGN §5.5). Item chance and rarity weights come from Data/Rarities per variant; the tables
-- here add slot weights, materials and boss specifics. Every monster kind has a table with its own id.

local Monsters = require("./Monsters")

export type MaterialDrop = { id: string, chance: number, min: number, max: number }

export type LootTable = {
	id: string,
	-- Weights of equipment slot groups for dropped items.
	slotWeights: { [string]: number },
	-- Chance (0..1) to prefer an item usable by the killer's class.
	classBias: number,
	materials: { MaterialDrop },
	-- Extra materials by variant (added to `materials`).
	variantMaterials: { [string]: { MaterialDrop } },
}

export type BossTable = {
	id: string,
	level: number,
	-- Hand-made Mythic items of this boss (Items/Uniques, ids `unique_*` kept for saves).
	named: { string },
	materials: { MaterialDrop },
	-- Personal roll for every winner (S30, Loot.rollBossPersonal): chance + step per kill without a hit,
	-- guaranteed on the `Hard`-th kill without one. Legendary avg ≈ 3.4 kills, Mythic ≈ 9.8 kills.
	legendaryChance: number,
	legendaryStep: number,
	legendaryHard: number,
	mythicChance: number,
	mythicStep: number,
	mythicHard: number,
}

-- Default pity numbers (each boss may tune its own).
local PITY = {
	legendaryChance = 0.20,
	legendaryStep = 0.05,
	legendaryHard = 8,
	mythicChance = 0.04,
	mythicStep = 0.01,
	mythicHard = 30,
}

local DEFAULT_SLOTS: { [string]: number } = {
	weapon = 28,
	offhand = 10,
	helmet = 10,
	armor = 10,
	gloves = 9,
	boots = 9,
	necklace = 8,
	ring = 12,
	talisman = 6,
}

-- Per-region base materials (essence dust is common everywhere).
local REGION_MATERIALS: { [number]: { MaterialDrop } } = {
	[1] = {
		{ id = "essence_dust", chance = 0.12, min = 1, max = 2 },
		{ id = "herb_meadowsweet", chance = 0.04, min = 1, max = 1 },
	},
	[2] = {
		{ id = "essence_dust", chance = 0.14, min = 1, max = 3 },
		{ id = "herb_nightshade", chance = 0.04, min = 1, max = 1 },
	},
	[3] = {
		{ id = "essence_dust", chance = 0.16, min = 2, max = 3 },
		{ id = "herb_firebloom", chance = 0.04, min = 1, max = 1 },
	},
	[4] = {
		{ id = "essence_dust", chance = 0.18, min = 2, max = 4 },
		{ id = "herb_frostleaf", chance = 0.04, min = 1, max = 1 },
	},
}

-- Monster parts by kind (chance 0.3, 1-2; PART_CHANCE overrides).
local PARTS: { [string]: string } = {
	-- S32: the S19 kinds of the Meadows (docs/SWIAT.md §2).
	lynx = "thick_hide",
	brownBear = "thick_hide",
	swampToad = "toad_venom",
	carrionCrow = "crow_feather",
	koboldMiner = "ore_copper",
	wolf = "wolf_pelt",
	rabbit = "wolf_pelt",
	boar = "boar_tusk",
	bandit = "goblin_ear",
	goblinScout = "goblin_ear",
	goblinShaman = "goblin_ear",
	caveSpider = "spider_silk",
	werewolf = "werewolf_claw",
	forestWraith = "ectoplasm",
	rotEnt = "werewolf_claw",
	darkCultist = "ectoplasm",
	swampTroll = "werewolf_claw",
	skeletonGuard = "ectoplasm",
	specter = "ectoplasm",
	necromancer = "ectoplasm",
	salamander = "salamander_scale",
	ashOrc = "magma_shard",
	fireGolem = "magma_shard",
	desertScorpion = "salamander_scale",
	wyvern = "salamander_scale",
	renegadeDwarf = "magma_shard",
	magmaGolem = "magma_shard",
	flameSmith = "magma_shard",
	iceWolf = "yeti_fur",
	yeti = "yeti_fur",
	frostGiant = "yeti_fur",
	iceElemental = "frost_scale",
	dragonspawn = "frost_scale",
	crystalGuardian = "frost_scale",
	youngFrostDragon = "frost_scale",
}

local PART_CHANCE: { [string]: number } = { koboldMiner = 0.25 }

local VARIANT_MATERIALS: { [string]: { MaterialDrop } } = {
	normal = {},
	elite = {
		{ id = "essence_shard", chance = 0.25, min = 1, max = 1 },
		{ id = "essence_dust", chance = 0.5, min = 2, max = 4 },
	},
	elite2 = {
		{ id = "essence_shard", chance = 0.8, min = 1, max = 3 },
		{ id = "essence_crystal", chance = 0.3, min = 1, max = 1 },
		{ id = "scroll_protection", chance = 0.08, min = 1, max = 1 },
	},
}

local TABLES: { [string]: LootTable } = {}
for _, def in Monsters.list do
	local materials = table.clone(REGION_MATERIALS[def.region] or {})
	local part = PARTS[def.id]
	if part then
		table.insert(materials, { id = part, chance = PART_CHANCE[def.id] or 0.3, min = 1, max = 2 })
	end
	TABLES[def.lootTable] = {
		id = def.lootTable,
		slotWeights = DEFAULT_SLOTS,
		classBias = 0.8,
		materials = materials,
		variantMaterials = VARIANT_MATERIALS,
	}
end

-- Bosses (S09/S11 add their encounters): shared items come from Rarities.itemDrops.boss; Legendary and Mythic
-- only from the personal roll (S30).
local BOSSES: { [string]: BossTable } = {
	grimrok = {
		id = "grimrok",
		level = 20,
		named = { "unique_grimrok_cleaver", "unique_grimrok_fang", "unique_grimrok_totem" },
		materials = {
			{ id = "essence_shard", chance = 1, min = 2, max = 4 },
			{ id = "essence_crystal", chance = 0.5, min = 1, max = 1 },
			{ id = "legend_core", chance = 0.1, min = 1, max = 1 },
			{ id = "scroll_protection", chance = 0.25, min = 1, max = 1 },
			{ id = "scroll_unbind", chance = 0.08, min = 1, max = 1 },
		},
		legendaryChance = PITY.legendaryChance,
		legendaryStep = PITY.legendaryStep,
		legendaryHard = PITY.legendaryHard,
		mythicChance = PITY.mythicChance,
		mythicStep = PITY.mythicStep,
		mythicHard = PITY.mythicHard,
	},
	morvane = {
		id = "morvane",
		level = 45,
		named = { "unique_morvane_shroud", "unique_morvane_scepter", "unique_morvane_bow" },
		materials = {
			{ id = "essence_shard", chance = 1, min = 3, max = 5 },
			{ id = "essence_crystal", chance = 0.8, min = 1, max = 2 },
			{ id = "legend_core", chance = 0.15, min = 1, max = 1 },
			{ id = "scroll_protection", chance = 0.3, min = 1, max = 1 },
			{ id = "scroll_unbind", chance = 0.1, min = 1, max = 1 },
		},
		legendaryChance = PITY.legendaryChance,
		legendaryStep = PITY.legendaryStep,
		legendaryHard = PITY.legendaryHard,
		mythicChance = PITY.mythicChance,
		mythicStep = PITY.mythicStep,
		mythicHard = PITY.mythicHard,
	},
	azgor = {
		id = "azgor",
		level = 70,
		named = { "unique_azgor_heart", "unique_azgor_staff", "unique_azgor_helm" },
		materials = {
			{ id = "essence_crystal", chance = 1, min = 2, max = 3 },
			{ id = "legend_core", chance = 0.2, min = 1, max = 1 },
			{ id = "scroll_protection", chance = 0.35, min = 1, max = 2 },
			{ id = "scroll_unbind", chance = 0.12, min = 1, max = 1 },
		},
		legendaryChance = PITY.legendaryChance,
		legendaryStep = PITY.legendaryStep,
		legendaryHard = PITY.legendaryHard,
		mythicChance = PITY.mythicChance,
		mythicStep = PITY.mythicStep,
		mythicHard = PITY.mythicHard,
	},
	vaelgrath = {
		id = "vaelgrath",
		level = 100,
		named = { "unique_vaelgrath_fang", "unique_vaelgrath_scale", "unique_vaelgrath_eye" },
		materials = {
			{ id = "essence_crystal", chance = 1, min = 3, max = 5 },
			{ id = "legend_core", chance = 0.3, min = 1, max = 2 },
			{ id = "scroll_protection", chance = 0.4, min = 1, max = 2 },
			{ id = "scroll_unbind", chance = 0.15, min = 1, max = 1 },
		},
		legendaryChance = PITY.legendaryChance,
		legendaryStep = PITY.legendaryStep,
		legendaryHard = PITY.legendaryHard,
		mythicChance = PITY.mythicChance,
		mythicStep = PITY.mythicStep,
		mythicHard = PITY.mythicHard,
	},
}

return table.freeze({
	byId = TABLES,
	bosses = BOSSES,
	get = function(id: string): LootTable?
		return TABLES[id]
	end,
	regionBoss = { [1] = "grimrok", [2] = "morvane", [3] = "azgor", [4] = "vaelgrath" } :: { [number]: string },
})
