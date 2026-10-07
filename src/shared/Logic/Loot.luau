--!strict
-- Monster and boss loot (DESIGN §5.5). Pure: returns what dropped; services turn it into item instances.
--   items     : { defId, ilvl, rarity } (equipment only; S30 rarity ids, see Data/Rarities)
--   materials : { id, n }
--   gold      : gold for the kill (CombatService awards gold immediately, see PROGRESS S04)

local Combat = require("../Data/Combat")
local Config = require("../Config")
local Items = require("../Data/Items")
local LootTables = require("../Data/LootTables")
local Monsters = require("../Data/Monsters")
local MonsterStats = require("./MonsterStats")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local ItemRoll = require("./ItemRoll")
local Types = require("../Types")

-- `forClass`: the class a class-free item (jewellery) rolls its bonuses for (S32).
export type ItemDrop = { defId: string, ilvl: number, rarity: number, forClass: string? }
export type MaterialDrop = { id: string, n: number }
export type LootResult = { items: { ItemDrop }, materials: { MaterialDrop }, gold: number }

export type Modifiers = {
	dropBonus: number?, -- % (multiplies the item chance, never the rarity weights)
	classId: string?, -- killer's class (class-biased item choice)
	dropLevel: number?, -- S32: base level of item drops (Loot.dropBaseLevel); the monster level otherwise
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
		local count = rng:int(drops.min, drops.max)
		if drops.extra and rng:chance(drops.extra) then
			count += 1
		end
		for _ = 1, count do
			local ilvl = ItemRoll.dropLevel(mods.dropLevel or level, rng)
			local defId = Loot.pickItem(tableDef.slotWeights, ilvl, tableDef.classBias, mods.classId, rng)
			if defId then
				table.insert(result.items, {
					defId = defId,
					ilvl = ilvl,
					rarity = ItemRoll.rollRarity(variant, rng),
					forClass = mods.classId,
				})
			end
		end
	end

	rollMaterials(tableDef.materials, rng, result.materials)
	rollMaterials(tableDef.variantMaterials[variant] or {}, rng, result.materials)
	result.gold = MonsterStats.gold(level, variant, rng:next())
	return result
end

-- Base level of a monster's item drops (S32, DESIGN §5.5): its level without the variant's extra levels (Elites
-- +2, Elite II +4), never above its spawner's highest level (`cap`), at least 1.
function Loot.dropBaseLevel(level: number, variant: string, cap: number?): number
	local mods = Combat.variants[variant]
	local base = level - (if mods and variant ~= "boss" then mods.levelAdd else 0)
	if cap then
		base = math.min(base, cap)
	end
	return math.max(1, math.floor(base))
end

-- Shared boss loot (DESIGN §16): 3–4 Unique/Heroic items (+1 per player above 3) and materials. Legendary and
-- Mythic items only come from every winner's personal roll (Loot.rollBossPersonal).
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
		local defId = Loot.pickItem(LootTables.byId.wolf.slotWeights, ilvl, 0.8, mods.classId, rng)
		if defId then
			table.insert(
				result.items,
				{ defId = defId, ilvl = ilvl, rarity = ItemRoll.rollRarity("boss", rng), forClass = mods.classId }
			)
		end
	end
	rollMaterials(boss.materials, rng, result.materials)
	result.gold = MonsterStats.gold(boss.level, "boss", rng:next())
	return result
end

-- Personal boss roll (S30, DESIGN §16) ------------------------------------------------------------------------

export type Pity = Types.BossPity
export type PersonalRoll = { legendary: boolean, mythic: boolean, pity: Pity }

local function pityOf(entry: Pity?): Pity
	if type(entry) ~= "table" then
		return { leg = 0, myth = 0 }
	end
	return {
		leg = math.max(0, math.floor(tonumber(entry.leg) or 0)),
		myth = math.max(0, math.floor(tonumber(entry.myth) or 0)),
	}
end

-- Chance on the next kill after `misses` kills without a hit: base + step × misses, 1 on the `hard`-th kill.
local function pityChance(base: number, step: number, hard: number, misses: number): number
	if misses + 1 >= hard then
		return 1
	end
	return math.clamp(base + step * misses, 0, 1)
end

-- Current chances (0..1) of a Legendary and a Mythic on the next kill of this boss, given the pity counters.
function Loot.bossChances(bossId: string, pityEntry: Pity?): { legendary: number, mythic: number }
	local boss = LootTables.bosses[bossId]
	if not boss then
		return { legendary = 0, mythic = 0 }
	end
	local pity = pityOf(pityEntry)
	return {
		legendary = pityChance(boss.legendaryChance, boss.legendaryStep, boss.legendaryHard, pity.leg),
		mythic = pityChance(boss.mythicChance, boss.mythicStep, boss.mythicHard, pity.myth),
	}
end

-- One winner's personal roll. A hit resets its counter, a miss adds one. Does not mutate `pity`.
function Loot.rollBossPersonal(boss: LootTables.BossTable, pity: Pity?, rng: Rng.Rng): PersonalRoll
	local current = pityOf(pity)
	local chances = Loot.bossChances(boss.id, current)
	local legendary = rng:next() < chances.legendary
	local mythic = rng:next() < chances.mythic
	return {
		legendary = legendary,
		mythic = mythic,
		pity = {
			leg = if legendary then 0 else current.leg + 1,
			myth = if mythic then 0 else current.myth + 1,
		},
	}
end

-- Simulates `n` kills of a boss by one character starting from `pity` (admin /bosssim, tests).
function Loot.simulateBoss(
	boss: LootTables.BossTable,
	n: number,
	rng: Rng.Rng,
	pity: Pity?
): { legendary: number, mythic: number, pity: Pity }
	local current = pityOf(pity)
	local legendary, mythic = 0, 0
	for _ = 1, n do
		local roll = Loot.rollBossPersonal(boss, current, rng)
		current = roll.pity
		legendary += if roll.legendary then 1 else 0
		mythic += if roll.mythic then 1 else 0
	end
	return { legendary = legendary, mythic = mythic, pity = current }
end

-- Items of a personal roll for a winner of `classId`: a rolled Legendary (class-usable with
-- Config.BossLoot.legendaryClassShare) and a Mythic (a named item of the boss with Config.BossLoot.mythicNamedShare,
-- otherwise a rolled Mythic of a class-usable base). All at the boss's level.
function Loot.personalItems(
	boss: LootTables.BossTable,
	roll: PersonalRoll,
	classId: string?,
	rng: Rng.Rng
): { ItemDrop }
	local items: { ItemDrop } = {}
	local slots = LootTables.byId.wolf.slotWeights
	if roll.legendary then
		local defId = Loot.pickItem(slots, boss.level, Config.BossLoot.legendaryClassShare, classId, rng)
		if defId then
			table.insert(items, { defId = defId, ilvl = boss.level, rarity = Rarities.LEGENDARY })
		end
	end
	if roll.mythic then
		local defId: string? = nil
		if #boss.named > 0 and rng:chance(Config.BossLoot.mythicNamedShare) then
			local usable = {}
			for _, id in boss.named do
				if usableBy(id, classId) then
					table.insert(usable, id)
				end
			end
			defId = rng:pick(if #usable > 0 then usable else boss.named)
		end
		if not defId then
			defId = Loot.pickItem(slots, boss.level, 1, classId, rng)
		end
		if defId then
			table.insert(items, { defId = defId, ilvl = boss.level, rarity = Rarities.MYTHIC })
		end
	end
	return items
end

return Loot
