--!strict
-- Monster and boss loot (DESIGN §5.5). Pure: returns what dropped; services turn it into item instances.
--   items     : { defId, ilvl, rarity } (equipment only; S30 rarity ids, see Data/Rarities)
--   materials : { id, n }
--   gold      : gold for the kill (CombatService awards gold immediately, see docs/DECYZJE.md S04)

local Combat = require("../Data/Combat")
local Config = require("../Config")
local Items = require("../Data/Items")
local LevelCurves = require("./LevelCurves")
local LootTables = require("../Data/LootTables")
local Monsters = require("../Data/Monsters")
local MonsterStats = require("./MonsterStats")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local ItemRoll = require("./ItemRoll")

-- `forClass`: the class a class-free item (jewellery) rolls its bonuses for (S32).
-- `family` (S67): the dropping monster's family; family lines of the item roll it.
-- `upgraded` / `extra` (S60): Fortune ennobled a Unique boss item / the second boss item.
export type ItemDrop = {
	defId: string,
	ilvl: number,
	rarity: number,
	forClass: string?,
	family: string?, -- S67: family of the monster that dropped it (ItemRoll.RollContext)
	upgraded: boolean?,
	extra: boolean?,
}
-- Fortune on a boss kill (S60, ROZWOJ 6.2); structurally Logic/Luck.BossLuck. nil = no luck.
export type BossLuck = { legendaryMul: number?, upgrade: number?, extra: number? }
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

-- S87 (balance plan, Mythic for the winner's class): an equipment definition of `ilvl` usable by `classId`. Only
-- slots with at least one usable base at the tier keep their weight; the base is picked among the usable ones.
-- Falls back to Loot.pickItem when no slot has one; without `classId` it is Loot.pickItem(slots, ilvl, 1, nil, rng)
-- (today's choice and Rng use: /bosssim without a class, the wiki's Monte Carlo).
function Loot.pickUsable(slotWeights: { [string]: number }, ilvl: number, classId: string?, rng: Rng.Rng): string?
	if not classId then
		return Loot.pickItem(slotWeights, ilvl, 1, nil, rng)
	end
	local tier = Items.generate.tierFor(ilvl)
	local weights: { [string]: number } = {}
	local any = false
	for slot, weight in slotWeights do
		local list = SLOT_TIER[slot] and SLOT_TIER[slot][tier]
		if weight > 0 and list then
			for _, id in list do
				if usableBy(id, classId) then
					weights[slot] = weight
					any = true
					break
				end
			end
		end
	end
	if not any then
		return Loot.pickItem(slotWeights, ilvl, 1, classId, rng)
	end
	local slot = rng:weighted(weights)
	local usable = {}
	for _, id in SLOT_TIER[slot][tier] do
		if usableBy(id, classId) then
			table.insert(usable, id)
		end
	end
	return rng:pick(usable)
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
		-- S134h: an Elite II drops only its own slot groups (LootTables.ELITE2_SLOTS)
		local slots = LootTables.slotsFor(monsterId, variant)
		for _ = 1, count do
			local ilvl = ItemRoll.dropLevel(mods.dropLevel or level, rng)
			local defId = Loot.pickItem(slots, ilvl, tableDef.classBias, mods.classId, rng)
			if defId then
				table.insert(result.items, {
					defId = defId,
					ilvl = ilvl,
					-- S87 (balance plan D5): the region's Unique / Heroic factor (1 until S91-S94)
					rarity = ItemRoll.rollRarity(variant, rng, mods.topTierMul, LevelCurves.dropFactor(def.region)),
					forClass = mods.classId,
					family = def.family :: string?,
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
-- today (UTC): the base chance + perKill per kill; Fortune multiplies the Legendary chance only (S60).
local function chancesOf(
	boss: LootTables.BossTable,
	killsToday: number?,
	luck: BossLuck?
): { legendary: number, mythic: number }
	local kills = math.max(0, math.floor(killsToday or 0))
	local mul = if luck and luck.legendaryMul then luck.legendaryMul else 1
	return {
		legendary = math.clamp((boss.legendaryChance + boss.perKill * kills) * mul, 0, 1),
		mythic = math.clamp(boss.mythicChance + boss.perKill * kills, 0, 1),
	}
end

-- The one function every shown and rolled boss chance goes through (dungeon card, world map, reward card, roll).
function Loot.bossChances(bossId: string, killsToday: number?, luck: BossLuck?): { legendary: number, mythic: number }
	local boss = LootTables.bosses[bossId]
	if not boss then
		return { legendary = 0, mythic = 0 }
	end
	return chancesOf(boss, killsToday, luck)
end

-- A Unique / Heroic boss item (the common branch of rollBossItem and the second item of rollBossExtra).
local function rollCommon(boss: LootTables.BossTable, classId: string?, rng: Rng.Rng): ItemDrop?
	local ilvl = ItemRoll.dropLevel(boss.level, rng)
	local defId = Loot.pickItem(LootTables.bossSlots, ilvl, Config.BossLoot.legendaryClassShare, classId, rng)
	return if defId
		then { defId = defId, ilvl = ilvl, rarity = ItemRoll.rollRarity("boss", rng), forClass = classId }
		else nil
end

-- The one item a winner of `classId` gets: Mythic (a named item of the boss with Config.BossLoot.mythicNamedShare,
-- otherwise a rolled Mythic of a class-usable base; S87: when no named item fits the class, a rolled Mythic for the
-- class instead, so a Mythic always fits the winner's class), else Legendary (class-usable with
-- Config.BossLoot.legendaryClassShare), else a Unique / Heroic item. Weapons come first (LootTables.bossSlots).
-- Fortune (S60): the Legendary chance times luck.legendaryMul; a Unique becomes Heroic with luck.upgrade (no extra
-- roll without upgrade, so the Rng sequence is unchanged).
function Loot.rollBossItem(
	boss: LootTables.BossTable,
	killsToday: number?,
	classId: string?,
	rng: Rng.Rng,
	luck: BossLuck?
): ItemDrop?
	local chances = chancesOf(boss, killsToday, luck)
	local slots = LootTables.bossSlots
	local roll = rng:next()
	if roll < chances.mythic then
		if #boss.named > 0 and rng:chance(Config.BossLoot.mythicNamedShare) then
			local usable = {}
			for _, id in boss.named do
				if usableBy(id, classId) then
					table.insert(usable, id)
				end
			end
			if #usable > 0 then
				return { defId = rng:pick(usable), ilvl = boss.level, rarity = Rarities.MYTHIC }
			end
			-- S87: no named item for this class -> a rolled Mythic for the class (below)
		end
		local defId = Loot.pickUsable(slots, boss.level, classId, rng)
		return if defId then { defId = defId, ilvl = boss.level, rarity = Rarities.MYTHIC, forClass = classId } else nil
	end
	if roll < chances.mythic + chances.legendary then
		local defId = Loot.pickItem(slots, boss.level, Config.BossLoot.legendaryClassShare, classId, rng)
		return if defId then { defId = defId, ilvl = boss.level, rarity = Rarities.LEGENDARY } else nil
	end
	local drop = rollCommon(boss, classId, rng)
	local upgrade = if luck and luck.upgrade then luck.upgrade else 0
	if drop and drop.rarity == Rarities.UNIQUE and upgrade > 0 and rng:chance(upgrade) then
		drop.rarity = Rarities.HEROIC
		drop.upgraded = true
	end
	return drop
end

-- Fortune's second boss item (S60, ROZWOJ 6.2): with luck.extra a Unique / Heroic item marked `extra`, never
-- ennobled. Without extra > 0 nothing is rolled.
function Loot.rollBossExtra(boss: LootTables.BossTable, classId: string?, rng: Rng.Rng, luck: BossLuck?): ItemDrop?
	local extra = if luck and luck.extra then luck.extra else 0
	if extra <= 0 or not rng:chance(extra) then
		return nil
	end
	local drop = rollCommon(boss, classId, rng)
	if drop then
		drop.extra = true
	end
	return drop
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
