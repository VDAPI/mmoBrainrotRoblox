--!strict
-- Monster and boss loot (DESIGN §5.5). Pure: returns what dropped; services turn it into item instances.
--   items     : { defId, ilvl, rarity } (equipment only; rarity 6 = unique)
--   materials : { id, n }
--   gold      : gold for the kill (CombatService awards gold immediately, see PROGRESS S04)

local Items = require("../Data/Items")
local LootTables = require("../Data/LootTables")
local Monsters = require("../Data/Monsters")
local MonsterStats = require("./MonsterStats")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local ItemRoll = require("./ItemRoll")

export type ItemDrop = { defId: string, ilvl: number, rarity: number }
export type MaterialDrop = { id: string, n: number }
export type LootResult = { items: { ItemDrop }, materials: { MaterialDrop }, gold: number }

export type Modifiers = {
	dropBonus: number?, -- % (multiplies the item chance, never the rarity weights)
	classId: string?, -- killer's class (class-biased item choice)
}

local Loot = {}

-- Equipment definition ids grouped by slot group and tier: SLOT_TIER[group][tier] = { defId }
local SLOT_TIER: { [string]: { [number]: { string } } } = {}
for id, def in Items.byId do
	if def.category == "equipment" and def.slot and def.tier and not def.fixedBonuses then
		local group = SLOT_TIER[def.slot]
		if not group then
			group = {}
			SLOT_TIER[def.slot] = group
		end
		local list = group[def.tier]
		if not list then
			list = {}
			group[def.tier] = list
		end
		table.insert(list, id)
	end
end
for _, group in SLOT_TIER do
	for _, list in group do
		table.sort(list) -- deterministic order for seeded tests
	end
end

local function usableBy(defId: string, classId: string?): boolean
	if not classId then
		return true
	end
	local def = Items.get(defId)
	return def ~= nil and (def.classes == nil or table.find(def.classes, classId) ~= nil)
end

-- Picks an equipment definition for a drop of `ilvl`.
function Loot.pickItem(
	slotWeights: { [string]: number },
	ilvl: number,
	classBias: number,
	classId: string?,
	rng: Rng.Rng
): string?
	local tier = Items.generate.tierFor(ilvl)
	local slot = rng:weighted(slotWeights)
	local candidates = SLOT_TIER[slot] and SLOT_TIER[slot][tier]
	if not candidates or #candidates == 0 then
		return nil
	end
	if classId and rng:chance(classBias) then
		local preferred = {}
		for _, id in candidates do
			if usableBy(id, classId) then
				table.insert(preferred, id)
			end
		end
		if #preferred > 0 then
			return rng:pick(preferred)
		end
	end
	return rng:pick(candidates)
end

local function rollMaterials(list: { LootTables.MaterialDrop }, rng: Rng.Rng, into: { MaterialDrop })
	for _, drop in list do
		if rng:chance(drop.chance) then
			table.insert(into, { id = drop.id, n = rng:int(drop.min, drop.max) })
		end
	end
end

function Loot.rollMonsterLoot(
	monsterId: string,
	variant: string,
	level: number,
	rng: Rng.Rng,
	modifiers: Modifiers?
): LootResult
	local result: LootResult = { items = {}, materials = {}, gold = 0 }
	local def = Monsters.get(monsterId)
	local tableDef = def and LootTables.get(def.lootTable)
	if not def or not tableDef then
		return result
	end
	local mods: Modifiers = modifiers or {}
	local drops = Rarities.itemDrops[variant] or Rarities.itemDrops.normal
	local chance = math.min(1, drops.chance * (1 + (mods.dropBonus or 0) / 100))

	if rng:chance(chance) then
		for _ = 1, rng:int(drops.min, drops.max) do
			local ilvl = ItemRoll.dropLevel(level, rng)
			local defId = Loot.pickItem(tableDef.slotWeights, ilvl, tableDef.classBias, mods.classId, rng)
			if defId then
				table.insert(result.items, { defId = defId, ilvl = ilvl, rarity = ItemRoll.rollRarity(variant, rng) })
			end
		end
	end

	-- Elite II: small chance at a unique of the region's boss.
	if variant == "elite2" and rng:chance(LootTables.elite2UniqueChance) then
		local boss = LootTables.bosses[LootTables.regionBoss[def.region] or ""]
		if boss and #boss.uniques > 0 then
			table.insert(result.items, { defId = rng:pick(boss.uniques), ilvl = boss.level, rarity = Rarities.UNIQUE })
		end
	end

	rollMaterials(tableDef.materials, rng, result.materials)
	rollMaterials(tableDef.variantMaterials[variant] or {}, rng, result.materials)
	result.gold = MonsterStats.gold(level, variant, rng:next())
	return result
end

-- Boss loot (DESIGN §16): 3–4 items (+1 per player above 3), 25 % unique, materials.
function Loot.rollBossLoot(bossId: string, players: number, rng: Rng.Rng, modifiers: Modifiers?): LootResult
	local result: LootResult = { items = {}, materials = {}, gold = 0 }
	local boss = LootTables.bosses[bossId]
	if not boss then
		return result
	end
	local mods: Modifiers = modifiers or {}
	local drops = Rarities.itemDrops.boss
	local count = rng:int(drops.min, drops.max) + math.max(0, players - 3)
	for _ = 1, count do
		local ilvl = ItemRoll.dropLevel(boss.level, rng)
		local defId = Loot.pickItem(LootTables.byId.wolf.slotWeights, ilvl, 0.65, mods.classId, rng)
		if defId then
			table.insert(result.items, { defId = defId, ilvl = ilvl, rarity = ItemRoll.rollRarity("boss", rng) })
		end
	end
	if #boss.uniques > 0 and rng:chance(Rarities.bossUniqueChance) then
		table.insert(result.items, { defId = rng:pick(boss.uniques), ilvl = boss.level, rarity = Rarities.UNIQUE })
	end
	rollMaterials(boss.materials, rng, result.materials)
	result.gold = MonsterStats.gold(boss.level, "boss", rng:next())
	return result
end

return Loot
