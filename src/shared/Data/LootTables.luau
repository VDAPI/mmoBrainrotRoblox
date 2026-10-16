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
	-- One item for every winner (FIX 2026-10-09, Loot.rollBossItem): Mythic `mythicChance`, Legendary
	-- `legendaryChance`, each + `perKill` for every kill of this boss by the character earlier the same UTC day
	-- (reset at midnight with the daily runs); otherwise a Unique / Heroic item (Rarities dropWeights.boss).
	legendaryChance: number,
	mythicChance: number,
	perKill: number,
}

-- Default boss item chances (FIX 2026-10-09; each boss may tune its own).
local BOSS_ROLL = {
	legendaryChance = 0.06,
	mythicChance = 0.01,
	perKill = 0.01,
}

-- Slots of boss items (FIX 2026-10-09: more weapons than a monster's drop).
local BOSS_SLOTS: { [string]: number } = {
	weapon = 40,
	offhand = 10,
	helmet = 8,
	armor = 8,
	gloves = 7,
	boots = 7,
	necklace = 7,
	ring = 7,
	talisman = 6,
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

-- S134h: the nine slot groups of DEFAULT_SLOTS in the order of the cards and the wiki.
local SLOT_GROUPS: { string } =
	{ "weapon", "offhand", "helmet", "armor", "gloves", "boots", "necklace", "ring", "talisman" }

-- S134h (DESIGN §5.5): the slot groups an Elite II drops, by kind (the player knows an Elite II by its name,
-- monster.<kind>.elite2; a kind is an Elite II in at most one place of the world, tests/elite2loot.spec). Its items
-- keep the DEFAULT_SLOTS weights cut to these groups (LootTables.slotsFor). A kind outside the list (the Elite II of
-- events: the Invasion, the Blood Moon) drops from every group. In every band of ELITE2_BANDS the Elite IIs together
-- drop all nine groups; the two of one cave never share a group.
local ELITE2_SLOTS: { [string]: { string } } = {
	-- Region 1
	bandit = { "weapon", "armor", "ring" }, -- meadows_hideout
	carrionCrow = { "boots", "gloves", "talisman" },
	goblinScout = { "helmet", "gloves", "offhand" }, -- meadows_burrow
	koboldMiner = { "weapon", "necklace", "talisman" },
	caveSpider = { "armor", "boots", "ring" }, -- meadows_cave
	goblinShaman = { "weapon", "helmet", "necklace" },
	-- Region 2
	werewolf = { "weapon", "gloves", "boots" }, -- duskwood_den
	blackBear = { "armor", "helmet", "ring" },
	darkCultist = { "weapon", "offhand", "talisman" }, -- duskwood_barrow
	ghoul = { "necklace", "ring", "boots" },
	necromancer = { "weapon", "helmet", "gloves" }, -- duskwood_cave
	specter = { "armor", "necklace", "ring" },
	-- Region 3
	ashOrc = { "weapon", "armor", "gloves" }, -- ashen_mine
	wasteHyena = { "boots", "helmet", "ring" },
	wyvern = { "weapon", "necklace", "talisman" }, -- ashen_lair
	desertScorpion = { "offhand", "ring", "gloves" },
	flameSmith = { "weapon", "armor", "helmet" }, -- ashen_cave
	magmaGolem = { "boots", "offhand", "necklace" },
	-- Region 4
	yeti = { "weapon", "helmet", "gloves" }, -- frostpeak_grotto
	iceWolf = { "boots", "ring", "talisman" },
	frozenKnight = { "armor", "offhand", "ring" }, -- frostpeak_hold
	frostGiant = { "weapon", "necklace", "talisman" },
	youngFrostDragon = { "weapon", "helmet", "boots" }, -- frostpeak_cave
	crystalGuardian = { "gloves", "armor", "necklace" },
}

-- S134h: two level bands per region; an Elite II belongs to a band when its spawner's level range overlaps it.
local ELITE2_BANDS: { { number } } = {
	{ 7, 14 },
	{ 14, 20 },
	{ 21, 33 },
	{ 33, 45 },
	{ 46, 58 },
	{ 58, 70 },
	{ 71, 86 },
	{ 86, 100 },
}

-- DEFAULT_SLOTS cut to the groups of each kind of ELITE2_SLOTS (built once).
local ELITE2_WEIGHTS: { [string]: { [string]: number } } = {}
for kind, groups in ELITE2_SLOTS do
	local weights: { [string]: number } = {}
	for _, group in groups do
		weights[group] = DEFAULT_SLOTS[group]
	end
	ELITE2_WEIGHTS[kind] = table.freeze(weights)
end

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
	-- S92: the S19 kinds of the Dark Forest (docs/SWIAT.md §2)
	blackBear = "thick_hide",
	ghoul = "cursed_bone",
	bogSerpent = "toad_venom",
	marshWitch = "cursed_bone",
	bloodBat = "crow_feather",
	salamander = "salamander_scale",
	ashOrc = "magma_shard",
	fireGolem = "magma_shard",
	desertScorpion = "salamander_scale",
	wyvern = "salamander_scale",
	renegadeDwarf = "magma_shard",
	magmaGolem = "magma_shard",
	flameSmith = "magma_shard",
	-- S93: the S19 kinds of the Scorched Wastes (docs/SWIAT.md §2)
	wasteHyena = "thick_hide",
	ashVulture = "crow_feather",
	fireImp = "magma_shard",
	basilisk = "toad_venom",
	desertMummy = "cursed_bone",
	iceWolf = "yeti_fur",
	yeti = "yeti_fur",
	frostGiant = "yeti_fur",
	iceElemental = "frost_scale",
	dragonspawn = "frost_scale",
	crystalGuardian = "frost_scale",
	youngFrostDragon = "frost_scale",
	-- S94: the S19 kinds of the Frost Peaks (docs/SWIAT.md §2)
	snowLeopard = "thick_hide",
	peakHarpy = "crow_feather",
	iceMammoth = "yeti_fur",
	frozenKnight = "cursed_bone",
	frostWyrm = "frost_scale",
}

local PART_CHANCE: { [string]: number } = { koboldMiner = 0.25 }

local VARIANT_MATERIALS: { [string]: { MaterialDrop } } = {
	normal = {},
	elite = {
		{ id = "essence_shard", chance = 0.25, min = 1, max = 1 },
		{ id = "essence_dust", chance = 0.5, min = 2, max = 4 },
	},
	-- S134h: halved (two Elite IIs in every cave: about the same essence and scrolls per hour as one before)
	elite2 = {
		{ id = "essence_shard", chance = 0.4, min = 1, max = 3 },
		{ id = "essence_crystal", chance = 0.15, min = 1, max = 1 },
		{ id = "scroll_protection", chance = 0.04, min = 1, max = 1 },
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

-- Bosses (S09/S11 add their encounters): one item per winner (FIX 2026-10-09, Loot.rollBossItem) from
-- BOSS_SLOTS, plus the materials.
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
			-- S134d: Scroll of the Hunt (Auto Hunt time; the free way, slower than buying)
			{ id = "scroll_hunt", chance = 0.15, min = 1, max = 1 },
		},
		legendaryChance = BOSS_ROLL.legendaryChance,
		mythicChance = BOSS_ROLL.mythicChance,
		perKill = BOSS_ROLL.perKill,
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
			{ id = "scroll_hunt", chance = 0.2, min = 1, max = 1 }, -- S134d
		},
		legendaryChance = BOSS_ROLL.legendaryChance,
		mythicChance = BOSS_ROLL.mythicChance,
		perKill = BOSS_ROLL.perKill,
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
			{ id = "scroll_hunt", chance = 0.25, min = 1, max = 1 }, -- S134d
		},
		legendaryChance = BOSS_ROLL.legendaryChance,
		mythicChance = BOSS_ROLL.mythicChance,
		perKill = BOSS_ROLL.perKill,
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
			{ id = "scroll_hunt", chance = 0.3, min = 1, max = 1 }, -- S134d
		},
		legendaryChance = BOSS_ROLL.legendaryChance,
		-- S94 (balance plan 8.4, D2): the Mythic rarer than at the bosses of regions 1-3: 0.3 / 1.3 / 2.3 % on the
		-- day's kills, ~77 kills to the first (Grimrok 50: x1.54); back to the shared chance = BOSS_ROLL.mythicChance
		mythicChance = 0.003,
		perKill = BOSS_ROLL.perKill,
	},
}

-- S134h: the slot weights of a monster's item drops: an Elite II of ELITE2_SLOTS only its groups (DEFAULT_SLOTS
-- weights), everything else its table's. The one source of the server (Loot.rollMonsterLoot), the model, the map card
-- and the wiki.
local function slotsFor(monsterId: string, variant: string): { [string]: number }
	if variant == "elite2" then
		local weights = ELITE2_WEIGHTS[monsterId]
		if weights then
			return weights
		end
	end
	local def = Monsters.get(monsterId)
	local tableDef = def and TABLES[def.lootTable]
	return if tableDef then tableDef.slotWeights else DEFAULT_SLOTS
end

-- S134h: the locale key of a slot group's name (the ring group reads as one ring: slot.ring1).
local function slotKey(group: string): string
	return if group == "ring" then "slot.ring1" else `slot.{group}`
end

-- S134h: the slot groups an Elite II of `kind` drops, in SLOT_GROUPS order (every group for a kind outside
-- ELITE2_SLOTS).
local function elite2Groups(kind: string): { string }
	local own = ELITE2_SLOTS[kind]
	local list = {}
	for _, group in SLOT_GROUPS do
		if own == nil or table.find(own, group) then
			table.insert(list, group)
		end
	end
	return list
end

return table.freeze({
	byId = TABLES,
	defaultSlots = DEFAULT_SLOTS,
	slotGroups = SLOT_GROUPS,
	ELITE2_SLOTS = ELITE2_SLOTS,
	ELITE2_BANDS = ELITE2_BANDS,
	slotsFor = slotsFor,
	elite2Groups = elite2Groups,
	slotKey = slotKey,
	bosses = BOSSES,
	bossSlots = BOSS_SLOTS,
	get = function(id: string): LootTable?
		return TABLES[id]
	end,
	regionBoss = { [1] = "grimrok", [2] = "morvane", [3] = "azgor", [4] = "vaelgrath" } :: { [number]: string },
})
