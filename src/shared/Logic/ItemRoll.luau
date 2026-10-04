--!strict
-- Item rolling and item statistics (DESIGN §5.2–§5.4). Pure; randomness from Logic/Rng, uids injected.

local Bonuses = require("../Data/Bonuses")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

local ItemRoll = {}

export type BonusLine = { id: string, v: number, quality: number }

export type ItemStats = {
	-- Non-weapon base stats after rarity and upgrades.
	base: { [string]: number },
	weapon: { dmg: number, mdmg: number, speed: number, ranged: boolean, twoHanded: boolean }?,
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
	elseif def.scaling == "pct" then
		return 1 + ilvl / 60
	end
	return 1
end

-- Value range of a bonus on an item of `ilvl` and `rarity` (before rounding).
function ItemRoll.bonusRange(bonusId: string, ilvl: number, rarity: number): (number, number)
	local def = Bonuses.get(bonusId)
	assert(def, `ItemRoll: unknown bonus {bonusId}`)
	local rarityDef = Rarities.get(rarity)
	local rangeMul = if rarityDef and def.scaling ~= "none" then rarityDef.rangeMul else 1
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

-- 0..1: where the value sits inside its possible range (1 for fixed/unique bonuses outside the range).
function ItemRoll.bonusQuality(bonusId: string, value: number, ilvl: number, rarity: number): number
	if rarity == Rarities.UNIQUE or Bonuses.get(bonusId) == nil then
		return 1
	end
	local low, high = ItemRoll.bonusRange(bonusId, ilvl, rarity)
	if high - low < 1e-9 then
		return 1
	end
	return math.clamp((value - low) / (high - low), 0, 1)
end

function ItemRoll.rollRarity(variant: string, rng: Rng.Rng): number
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	return rng:weighted(weights)
end

-- Builds a stack of a non-equipment item (materials, potions, scrolls, tools, backpacks).
function ItemRoll.makeStack(defId: string, n: number, uid: string): ItemInstance
	local def = Items.get(defId)
	assert(def, `ItemRoll: unknown item {defId}`)
	return {
		uid = uid,
		id = defId,
		rarity = Rarities.COMMON,
		ilvl = def.level,
		bonuses = {},
		up = 0,
		bound = false,
		n = math.clamp(math.floor(n), 1, def.maxStack),
	}
end

-- Rolls an item instance. Equipment gets rarity-based random bonuses (no repeats; legendary +1 from the
-- legendary pool); uniques get their fixed bonuses; everything else is a single common unit.
function ItemRoll.rollItem(defId: string, ilvl: number, rarity: number, rng: Rng.Rng, uid: string): ItemInstance
	local def = Items.get(defId)
	assert(def, `ItemRoll: unknown item {defId}`)
	if def.category ~= "equipment" then
		return ItemRoll.makeStack(defId, 1, uid)
	end
	if def.fixedBonuses then
		return {
			uid = uid,
			id = defId,
			rarity = Rarities.UNIQUE,
			ilvl = def.level,
			bonuses = table.clone(def.fixedBonuses),
			up = 0,
			bound = false,
			n = 1,
		}
	end

	local rarityId = math.clamp(math.floor(rarity), Rarities.COMMON, Rarities.LEGENDARY)
	local rarityDef = Rarities.get(rarityId) :: Rarities.RarityDef
	local level = math.max(1, math.floor(ilvl))
	local bonuses: { Types.Bonus } = {}

	local pool = table.clone(Bonuses.pools[def.bonusGroup or ""] or {})
	rng:shuffle(pool)
	for i = 1, math.min(rarityDef.bonusCount, #pool) do
		local id = pool[i]
		table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, rng:next()) })
	end
	if rarityDef.legendaryBonus then
		local id = rng:pick(Bonuses.pools.legendary)
		table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, rng:next()) })
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
	}
end

-- Stats of an item instance: base (rarity + upgrade), weapon, and bonus totals mapped to StatCalc ids.
function ItemRoll.itemStats(item: ItemInstance): ItemStats
	local def = Items.get(item.id)
	local result: ItemStats = { base = {}, weapon = nil, flat = {}, pct = {}, hooks = {}, bonuses = {} }
	if not def then
		return result
	end
	local rarityDef = Rarities.get(item.rarity)
	local baseMul = if rarityDef then rarityDef.baseMul else 1
	local multiplier = baseMul * (1 + Rarities.upgradeStatPerLevel * (item.up or 0))

	local baseStats: { [string]: number } = def.base or {}
	for stat, value in baseStats do
		local decimals = if value % 1 == 0 then 0 else 1
		local scaled = roundTo(value * multiplier, decimals)
		result.base[stat] = scaled
		result.flat[stat] = (result.flat[stat] or 0) + scaled
	end
	local weapon = def.weapon
	if weapon then
		result.weapon = {
			dmg = math.floor(weapon.dmg * multiplier + 0.5),
			mdmg = math.floor(weapon.mdmg * multiplier + 0.5),
			speed = weapon.speed,
			ranged = weapon.ranged,
			twoHanded = weapon.twoHanded,
		}
	end

	for _, bonus in item.bonuses do
		local bonusDef = Bonuses.get(bonus.stat)
		if bonusDef then
			table.insert(result.bonuses, {
				id = bonus.stat,
				v = bonus.v,
				quality = ItemRoll.bonusQuality(bonus.stat, bonus.v, item.ilvl, item.rarity),
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

-- Price the merchant pays (DESIGN §18 economy is tuned in S06).
function ItemRoll.sellPrice(item: ItemInstance): number
	local def = Items.get(item.id)
	if not def then
		return 0
	end
	local rarityDef = Rarities.get(item.rarity)
	local mul = if rarityDef then rarityDef.sellMul else 1
	return math.floor(def.price * mul * (1 + 0.1 * (item.up or 0)) + 0.5) * math.max(1, item.n)
end

-- Item level of a monster drop: monster level +-2, at least 1 (DESIGN §5.3).
function ItemRoll.dropLevel(monsterLevel: number, rng: Rng.Rng): number
	return math.max(1, monsterLevel + rng:int(-2, 2))
end

return ItemRoll
