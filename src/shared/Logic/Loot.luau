--!strict
-- Monster and boss loot (DESIGN §5.5). Pure: returns what dropped; services turn it into item instances.
--   items     : { defId, ilvl, rarity } (equipment only; S30 rarity ids, see Data/Rarities)
--   materials : { id, n }
--   gold      : gold for the kill (CombatService awards gold immediately, see docs/DECYZJE.md S04)

local Combat = require("../Data/Combat")
local Config = require("../Config")
local Items = require("../Data/Items")
local LootTables = require("../Data/LootTables")
local Monsters = require("../Data/Monsters")
local MonsterStats = require("./MonsterStats")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local ItemRoll = require("./ItemRoll")

-- `forClass`: the class a class-free item (jewellery) rolls its bonuses for (S32).
export type ItemDrop = { defId: string, ilvl: number, rarity: number, forClass: string? }
export type MaterialDrop = { id: string, n: number }
export type LootResult = { items: { ItemDrop }, materials: { MaterialDrop }, gold: number }

export type Modifiers = {
	dropBonus: number?, -- % (multiplies the item chance, never the rarity weights)
	classId: string?, -- killer's class (class-biased item choice)
	dropLevel: number?, -- S32: base level of item drops (Loot.dropBaseLevel); the monster level otherwise
	-- S33: hunting ground profile (Data/AreaProfiles); 1 when nil.
	itemChanceMul: number?, -- multiplies the item chance (with dropBonus)
	topTierMul: number?, -- weight of the source's highest rarity (never above Rarities.cap)
	materialMul: number?, -- amount of every dropped material (expected value kept: fractions round by chance)
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

-- Amount `n` x `mul`, the fraction rounded up with its probability (expected value = n x mul, at least 1).
local function scaleAmount(n: number, mul: number, rng: Rng.Rng): number
	if mul == 1 then
		return n
	end
	local scaled = n * mul
	local whole = math.floor(scaled)
	if rng:chance(scaled - whole) then
		whole += 1
	end
	return math.max(1, whole)
end

local function rollMaterials(list: { LootTables.MaterialDrop }, rng: Rng.Rng, into: { MaterialDrop }, mul: number?)
	for _, drop in list do
		if rng:chance(drop.chance) then
			table.insert(into, { id = drop.id, n = scaleAmount(rng:int(drop.min, drop.max), mul or 1, rng) })
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
	local chance = math.min(1, drops.chance * (1 + (mods.dropBonus or 0) / 100) * (mods.itemChanceMul or 1))

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
					rarity = ItemRoll.rollRarity(variant, rng, mods.topTierMul),
					forClass = mods.classId,
				})
			end
		end
	end

	rollMaterials(tableDef.materials, rng, result.materials, mods.materialMul)
	rollMaterials(tableDef.variantMaterials[variant] or {}, rng, result.materials, mods.materialMul)
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

-- Boss materials and gold (DESIGN §16). FIX 2026-10-09: no shared items any more; every winner gets one item of
-- their own (Loot.rollBossItem). `items` stays empty.
function Loot.rollBossLoot(bossId: string, _players: number, rng: Rng.Rng, _modifiers: Modifiers?): LootResult
	local result: LootResult = { items = {}, materials = {}, gold = 0 }
	local boss = LootTables.bosses[bossId]
	if not boss then
		return result
	end
	rollMaterials(boss.materials, rng, result.materials)
	result.gold = MonsterStats.gold(boss.level, "boss", rng:next())
	return result
end

-- Boss item of each winner (FIX 2026-10-09, DESIGN §16) ------------------------------------------------------

-- Chances (0..1) of a Legendary and a Mythic item for a winner who already killed this boss `killsToday` times
-- today (UTC): the base chance + perKill per kill.
local function chancesOf(boss: LootTables.BossTable, killsToday: number?): { legendary: number, mythic: number }
	local kills = math.max(0, math.floor(killsToday or 0))
	return {
		legendary = math.clamp(boss.legendaryChance + boss.perKill * kills, 0, 1),
		mythic = math.clamp(boss.mythicChance + boss.perKill * kills, 0, 1),
	}
end

function Loot.bossChances(bossId: string, killsToday: number?): { legendary: number, mythic: number }
	local boss = LootTables.bosses[bossId]
	if not boss then
		return { legendary = 0, mythic = 0 }
	end
	return chancesOf(boss, killsToday)
end

-- The one item a winner of `classId` gets: Mythic (a named item of the boss with Config.BossLoot.mythicNamedShare,
-- otherwise a rolled Mythic of a class-usable base), else Legendary (class-usable with
-- Config.BossLoot.legendaryClassShare), else a Unique / Heroic item. Weapons come first (LootTables.bossSlots).
function Loot.rollBossItem(boss: LootTables.BossTable, killsToday: number?, classId: string?, rng: Rng.Rng): ItemDrop?
	local chances = chancesOf(boss, killsToday)
	local slots = LootTables.bossSlots
	local roll = rng:next()
	if roll < chances.mythic then
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
		defId = defId or Loot.pickItem(slots, boss.level, 1, classId, rng)
		return if defId then { defId = defId, ilvl = boss.level, rarity = Rarities.MYTHIC } else nil
	end
	if roll < chances.mythic + chances.legendary then
		local defId = Loot.pickItem(slots, boss.level, Config.BossLoot.legendaryClassShare, classId, rng)
		return if defId then { defId = defId, ilvl = boss.level, rarity = Rarities.LEGENDARY } else nil
	end
	local ilvl = ItemRoll.dropLevel(boss.level, rng)
	local defId = Loot.pickItem(slots, ilvl, Config.BossLoot.legendaryClassShare, classId, rng)
	return if defId
		then { defId = defId, ilvl = ilvl, rarity = ItemRoll.rollRarity("boss", rng), forClass = classId }
		else nil
end

-- Simulates `n` kills of a boss by one character, `perDay` kills a day (admin /bosssim, tests).
function Loot.simulateBoss(
	boss: LootTables.BossTable,
	n: number,
	rng: Rng.Rng,
	perDay: number?
): { legendary: number, mythic: number }
	local day = math.max(1, perDay or Config.Boss.dailyRuns)
	local legendary, mythic = 0, 0
	for i = 1, n do
		local drop = Loot.rollBossItem(boss, (i - 1) % day, nil, rng)
		legendary += if drop and drop.rarity == Rarities.LEGENDARY then 1 else 0
		mythic += if drop and drop.rarity == Rarities.MYTHIC then 1 else 0
	end
	return { legendary = legendary, mythic = mythic }
end

return Loot
