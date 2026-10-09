--!strict
-- Item rolling and item statistics (DESIGN §5.2–§5.4). Pure; randomness from Logic/Rng, uids injected.

local Bonuses = require("../Data/Bonuses")
local Elements = require("../Data/Elements")
local ItemValue = require("./ItemValue")
local Items = require("../Data/Items")
local LootRules = require("../Data/LootRules")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

local ItemRoll = {}

export type BonusLine = { id: string, v: number, quality: number }

export type ItemStats = {
	-- Non-weapon base stats after rarity and upgrades.
	base: { [string]: number },
	weapon: { dmg: number, mdmg: number, speed: number, ranged: boolean, twoHanded: boolean, element: string? }?,
	-- Totals ready for StatCalc: flat additions and % multipliers by stat id, plus special effects.
	flat: { [string]: number },
	pct: { [string]: number },
	hooks: { [string]: number },
	bonuses: { BonusLine },
}

local function roundTo(value: number, decimals: number): number
	local factor = 10 ^ decimals
	return math.floor(value * factor + 0.5) / factor
end

local function scaleFor(def: Bonuses.BonusDef, ilvl: number): number
	if def.scaling == "flat" then
		return 1 + ilvl / 20
	elseif def.scaling == "curve" then
		return (6 + 2.2 * ilvl) / 8.2
	elseif def.scaling == "pct" then
		return 1 + ilvl / 60
	end
	return 1
end

-- Value range of a bonus on an item of `ilvl` and `rarity` (before rounding).
function ItemRoll.bonusRange(bonusId: string, ilvl: number, rarity: number): (number, number)
	local def = Bonuses.get(bonusId)
	assert(def, `ItemRoll: unknown bonus {bonusId}`)
	local rangeMul = if def.scaling ~= "none" then Rarities.get(rarity).rangeMul else 1
	local scale = scaleFor(def, ilvl) * rangeMul
	return def.min * scale, def.max * scale
end

function ItemRoll.rollBonusValue(bonusId: string, ilvl: number, rarity: number, roll: number): number
	local def = Bonuses.get(bonusId) :: Bonuses.BonusDef
	local low, high = ItemRoll.bonusRange(bonusId, ilvl, rarity)
	local value = roundTo(low + (high - low) * math.clamp(roll, 0, 1), def.decimals)
	-- Never round a bonus down to nothing.
	return math.max(value, 10 ^ -def.decimals)
end

-- 0..1: where the value sits inside its possible range (1 for fixed bonuses of named items: pass `fixed`).
function ItemRoll.bonusQuality(bonusId: string, value: number, ilvl: number, rarity: number, fixed: boolean?): number
	if fixed or Bonuses.get(bonusId) == nil then
		return 1
	end
	local low, high = ItemRoll.bonusRange(bonusId, ilvl, rarity)
	if high - low < 1e-9 then
		return 1
	end
	return math.clamp((value - low) / (high - low), 0, 1)
end

-- Weights of a drop source with its highest rarity (never above Rarities.cap) multiplied by `topTierMul` (S33:
-- "better drops" hunting grounds).
function ItemRoll.rarityWeights(variant: string, topTierMul: number?): { [number]: number }
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	if not topTierMul or topTierMul == 1 then
		return weights
	end
	local cap = Rarities.cap[variant] or Rarities.cap.normal
	local top = 0
	for rarity, weight in weights do
		if weight > 0 and rarity <= cap and rarity > top then
			top = rarity
		end
	end
	local out = table.clone(weights)
	if top > 0 then
		out[top] = weights[top] * math.max(0, topTierMul)
	end
	return out
end

function ItemRoll.rollRarity(variant: string, rng: Rng.Rng, topTierMul: number?): number
	return rng:weighted(ItemRoll.rarityWeights(variant, topTierMul))
end

-- Builds a stack of a non-equipment item (materials, potions, scrolls, tools, backpacks).
function ItemRoll.makeStack(defId: string, n: number, uid: string): ItemInstance
	local def = Items.get(defId)
	assert(def, `ItemRoll: unknown item {defId}`)
	return {
		uid = uid,
		id = defId,
		rarity = def.rarity or Rarities.COMMON,
		ilvl = def.level,
		bonuses = {},
		up = 0,
		bound = false,
		n = math.clamp(math.floor(n), 1, def.maxStack),
		rv = Rarities.RV,
	}
end

-- Whether a bonus is useful to one of `classes` (S32, Bonuses.classStats; nil classes = every class).
local function fitsClasses(bonusId: string, classes: { string }?): boolean
	local only = Bonuses.classStats[bonusId]
	if not only or not classes then
		return true
	end
	for _, classId in classes do
		if table.find(only, classId) then
			return true
		end
	end
	return false
end

local function filtered(pool: { string }, classes: { string }?): { string }
	local out = {}
	for _, id in pool do
		if fitsClasses(id, classes) then
			table.insert(out, id)
		end
	end
	return out
end

-- Bonus pool of an equipment definition (S32): its bonus group without stats none of its classes use; class-free
-- items (jewellery) filter by `forClass` (the class they dropped for) when given.
function ItemRoll.bonusPool(defId: string, forClass: string?): { string }
	local def = Items.get(defId)
	if not def then
		return {}
	end
	local classes = def.classes or (if forClass then { forClass } else nil)
	return filtered(Bonuses.pools[def.bonusGroup or ""] or {}, classes)
end

function ItemRoll.legendaryPool(defId: string, forClass: string?): { string }
	local def = Items.get(defId)
	local classes = if def and def.classes then def.classes elseif forClass then { forClass } else nil
	return filtered(Bonuses.pools.legendary, classes)
end

function ItemRoll.mythicPool(defId: string, forClass: string?): { string }
	local def = Items.get(defId)
	local classes = if def and def.classes then def.classes elseif forClass then { forClass } else nil
	return filtered(Bonuses.pools.mythic, classes)
end

-- Rolls an item instance. Equipment gets bonusMin..bonusMax random bonuses of its rarity (no repeats) plus
-- `legendaryLines` distinct lines from the legendary pool and `mythicLines` from the mythic pool; named boss items get their fixed bonuses and fixed
-- rarity (Mythic); everything else is a single unit of its definition's rarity. `forClass` (S32) is the class a
-- class-free item (jewellery) dropped for: its bonuses are useful to that class.
function ItemRoll.rollItem(
	defId: string,
	ilvl: number,
	rarity: number,
	rng: Rng.Rng,
	uid: string,
	forClass: string?
): ItemInstance
	local def = Items.get(defId)
	assert(def, `ItemRoll: unknown item {defId}`)
	if def.category ~= "equipment" then
		return ItemRoll.makeStack(defId, 1, uid)
	end
	if def.fixedBonuses then
		return {
			uid = uid,
			id = defId,
			rarity = def.rarity or Rarities.MYTHIC,
			ilvl = def.level,
			bonuses = table.clone(def.fixedBonuses),
			up = 0,
			bound = false,
			n = 1,
			rv = Rarities.RV,
		}
	end

	local rarityId = math.clamp(math.floor(rarity), Rarities.COMMON, Rarities.MAX)
	local rarityDef = Rarities.get(rarityId)
	local level = math.max(1, math.floor(ilvl))
	local bonuses: { Types.Bonus } = {}

	local pool = ItemRoll.bonusPool(defId, forClass)
	rng:shuffle(pool)
	local count = if rarityDef.bonusMax > 0 then rng:int(rarityDef.bonusMin, rarityDef.bonusMax) else 0
	for i = 1, math.min(count, #pool) do
		local id = pool[i]
		table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, rng:next()) })
	end
	if rarityDef.legendaryLines > 0 then
		local legendary = ItemRoll.legendaryPool(defId, forClass)
		rng:shuffle(legendary)
		for i = 1, math.min(rarityDef.legendaryLines, #legendary) do
			local id = legendary[i]
			table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, rng:next()) })
		end
	end
	if rarityDef.mythicLines > 0 then
		local mythic = ItemRoll.mythicPool(defId, forClass)
		rng:shuffle(mythic)
		for i = 1, math.min(rarityDef.mythicLines, #mythic) do
			local id = mythic[i]
			table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, rng:next()) })
		end
	end

	return {
		uid = uid,
		id = defId,
		rarity = rarityId,
		ilvl = level,
		bonuses = bonuses,
		up = 0,
		bound = false,
		n = 1,
		-- Mage weapons roll their element (S18).
		el = if def.elemental then rng:pick(Elements.WEAPON) else nil,
		rv = Rarities.RV,
	}
end

-- Element of a mage weapon instance; weapons from before S18 count as fire. nil for everything else.
function ItemRoll.elementOf(item: ItemInstance): string?
	local def = Items.get(item.id)
	if not def or not def.elemental then
		return nil
	end
	return if Elements.isWeaponElement(item.el) then item.el else Elements.DEFAULT
end

-- A base stat key "<stat>Pct" (S32: off-hands and rings) is a % multiplier of <stat>; anything else is flat.
function ItemRoll.baseKey(key: string): (string, boolean)
	local stat = string.match(key, "^(.+)Pct$")
	if stat then
		return stat, true
	end
	return key, false
end

-- Stats of an item instance: base (rarity + upgrade), weapon, and bonus totals mapped to StatCalc ids.
function ItemRoll.itemStats(item: ItemInstance): ItemStats
	local def = Items.get(item.id)
	local result: ItemStats = { base = {}, weapon = nil, flat = {}, pct = {}, hooks = {}, bonuses = {} }
	if not def then
		return result
	end
	local named = def.fixedBonuses ~= nil
	-- Named items already carry their ×1.3 in the definition: no rarity multiplier on top (S30 B.2).
	local baseMul = if named then 1 else Rarities.get(item.rarity).baseMul
	local multiplier = baseMul * (1 + Rarities.upgradeStatPerLevel * (item.up or 0))

	-- S18: generated equipment scales with the instance's ilvl (every level beats the one before); the
	-- tier definition only names it. Named items keep their fixed base (S30 fix: it was recomputed and lost ×1.3).
	local scaling = if def.tier and not named then Items.bases.byType[def.type] else nil
	local baseStats: { [string]: number } = if scaling and scaling.stats
		then scaling.stats(math.max(1, item.ilvl))
		else def.base or {}
	for stat, value in baseStats do
		local decimals = if value % 1 == 0 then 0 else 1
		local scaled = roundTo(value * multiplier, decimals)
		result.base[stat] = scaled
		local id, isPct = ItemRoll.baseKey(stat)
		local target = if isPct then result.pct else result.flat
		target[id] = (target[id] or 0) + scaled
	end
	local weapon = if scaling and scaling.weapon then scaling.weapon(math.max(1, item.ilvl)) else def.weapon
	if weapon then
		result.weapon = {
			dmg = math.floor(weapon.dmg * multiplier + 0.5),
			mdmg = math.floor(weapon.mdmg * multiplier + 0.5),
			speed = weapon.speed,
			ranged = weapon.ranged,
			twoHanded = weapon.twoHanded,
			element = ItemRoll.elementOf(item),
		}
	end

	-- Named items always use their definition's bonuses (S32: values changed, saved copies follow).
	local bonuses: { Types.Bonus } = if named then def.fixedBonuses :: any else item.bonuses
	for _, bonus in ipairs(bonuses) do
		local bonusDef = Bonuses.get(bonus.stat)
		if bonusDef then
			table.insert(result.bonuses, {
				id = bonus.stat,
				v = bonus.v,
				quality = ItemRoll.bonusQuality(bonus.stat, bonus.v, item.ilvl, item.rarity, named),
			})
			if bonusDef.hook then
				result.hooks[bonusDef.hook] = (result.hooks[bonusDef.hook] or 0) + bonus.v
			elseif bonusDef.stat then
				local target = if bonusDef.mode == "pct" then result.pct else result.flat
				target[bonusDef.stat] = (target[bonusDef.stat] or 0) + bonus.v
			end
		end
	end
	return result
end

-- Level needed to equip: the ilvl for generated equipment (S18), the definition's level otherwise.
function ItemRoll.requiredLevel(item: ItemInstance): number
	local def = Items.get(item.id)
	if not def then
		return 1
	end
	return if def.tier then math.max(1, item.ilvl) else def.level
end

-- Price a merchant pays (S31, DESIGN §18): the item's value from Logic/ItemValue (0 when it cannot be sold).
function ItemRoll.sellPrice(item: ItemInstance): number
	return ItemValue.sellPrice(item)
end

-- Item levels a drop of a monster of `level` can have (S32, DESIGN §5.3): level - 0..dropLevelBelow, at least 1.
-- Before S32 it was level +-2, so 40 % of drops at the player's level could not be worn.
function ItemRoll.dropLevelRange(level: number, _variant: string?): (number, number)
	local high = math.max(1, math.floor(level))
	return math.max(1, high - LootRules.dropLevelBelow), high
end

function ItemRoll.dropLevel(level: number, rng: Rng.Rng): number
	local low, high = ItemRoll.dropLevelRange(level)
	return rng:int(low, high)
end

return ItemRoll
