--!strict
-- Item rolling and item statistics (DESIGN §5.2–§5.4). Pure; randomness from Logic/Rng, uids injected.

local Bonuses = require("../Data/Bonuses")
local Classes = require("../Data/Classes")
local Elements = require("../Data/Elements")
local Families = require("../Data/Families")
local ItemValue = require("./ItemValue")
local ItemTraits = require("../Data/ItemTraits")
local Items = require("../Data/Items")
local LootRules = require("../Data/LootRules")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

local ItemRoll = {}

export type BonusLine = { id: string, v: number, quality: number }

-- S67: what itemStats added from the trait (flat / hooks), so ItemScore can value the trait once.
export type TraitContrib = { flat: { [string]: number }, hooks: { [string]: number } }

export type TraitRoll = {
	id: string,
	def: ItemTraits.TraitDef,
	power: number,
	value: number,
	contrib: TraitContrib?, -- filled by itemStats
}

-- S67: the context of a drop; `family` is the family of the monster or boss that dropped the item.
export type RollContext = { family: string? }

export type ItemStats = {
	-- Non-weapon base stats after rarity and upgrades.
	base: { [string]: number },
	weapon: { dmg: number, mdmg: number, speed: number, ranged: boolean, twoHanded: boolean, element: string? }?,
	-- Totals ready for StatCalc: flat additions and % multipliers by stat id, plus special effects.
	flat: { [string]: number },
	pct: { [string]: number },
	hooks: { [string]: number },
	bonuses: { BonusLine },
	trait: TraitRoll?, -- S62: the live trait of the base type (already added to flat / hooks)
}

local function roundTo(value: number, decimals: number): number
	local factor = 10 ^ decimals
	return math.floor(value * factor + 0.5) / factor
end

-- Scale of a bonus by item level (constants in Data/Bonuses.scaling). S87 (balance plan C1, G7): "pct" lines stop
-- growing at ilvl pctCapIlvl (20), so Legendary and Mythic gains no longer grow with the level; 1-20 unchanged.
local function scaleFor(def: Bonuses.BonusDef, ilvl: number): number
	local s = Bonuses.scaling
	if def.scaling == "flat" then
		return 1 + ilvl / s.flatPer
	elseif def.scaling == "curve" then
		return (s.curveBase + s.curveSlope * ilvl) / s.curveDiv
	elseif def.scaling == "pct" then
		return 1 + math.min(ilvl, s.pctCapIlvl) / s.pctPer
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
-- "better drops" hunting grounds). S87 (balance plan D5): `dropFactor` (LevelCurves.dropFactor of the monster's
-- region) first multiplies the Unique and Heroic weights of the source table and Common takes the difference, so
-- the total and the Legendary / Mythic share stay; nil or 1 returns today's table (same Rng use).
function ItemRoll.rarityWeights(variant: string, topTierMul: number?, dropFactor: number?): { [number]: number }
	local weights = Rarities.dropWeights[variant] or Rarities.dropWeights.normal
	if dropFactor and dropFactor ~= 1 then
		local f = math.max(0, dropFactor)
		local u = weights[Rarities.UNIQUE] or 0
		local h = weights[Rarities.HEROIC] or 0
		local scaled = table.clone(weights)
		local common = (weights[Rarities.COMMON] or 0) + (1 - f) * (u + h)
		assert(common >= -1e-9, `ItemRoll: dropFactor {f} leaves no Common weight for {variant}`)
		scaled[Rarities.COMMON] = math.max(0, common)
		if weights[Rarities.UNIQUE] then
			scaled[Rarities.UNIQUE] = u * f
		end
		if weights[Rarities.HEROIC] then
			scaled[Rarities.HEROIC] = h * f
		end
		weights = scaled
	end
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

function ItemRoll.rollRarity(variant: string, rng: Rng.Rng, topTierMul: number?, dropFactor: number?): number
	return rng:weighted(ItemRoll.rarityWeights(variant, topTierMul, dropFactor))
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
		-- S122: stackables with bindOnPickup are bound from creation (potion_full); boss uniques are not stackable
		bound = def.stackable == true and def.bindOnPickup == true,
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

-- S62 (STATY 2B): a base shared by classes (mace1h, shield) rolls for the class it dropped for; class-free items
-- (jewellery) for `forClass` when known.
local function classesFor(def: Items.ItemDef, forClass: string?): { string }?
	if def.classes then
		if forClass and table.find(def.classes, forClass) then
			return { forClass }
		end
		return def.classes
	end
	return if forClass then { forClass } else nil
end

-- Pool weights of an equipment definition (S62, Data/ItemTraits affinity): the class-filtered pool of its bonus
-- group, each line weighted by its base type (and by class when exactly one applies). Only weights > 0.
function ItemRoll.poolWeights(defId: string, forClass: string?): { [string]: number }
	local def = Items.get(defId)
	if not def then
		return {}
	end
	local classes = classesFor(def, forClass)
	local classId = if classes and #classes == 1 then classes[1] else nil
	local out: { [string]: number } = {}
	for _, id in filtered(Bonuses.pools[def.bonusGroup or ""] or {}, classes) do
		local w = ItemTraits.weight(def.type, id, classId)
		if w > 0 then
			out[id] = w
		end
	end
	return out
end

-- Bonus pool of an equipment definition (S32): its bonus group without stats none of its classes use; class-free
-- items (jewellery) filter by `forClass` (the class they dropped for) when given. S62: shared bases filter by
-- `forClass` too, and lines weighted 0 for the type are left out. Pool order.
function ItemRoll.bonusPool(defId: string, forClass: string?): { string }
	local def = Items.get(defId)
	if not def then
		return {}
	end
	local weights = ItemRoll.poolWeights(defId, forClass)
	local out = {}
	local pool: { string } = Bonuses.pools[def.bonusGroup or ""] or {}
	for _, id in pool do
		if weights[id] then
			table.insert(out, id)
		end
	end
	return out
end

function ItemRoll.legendaryPool(defId: string, forClass: string?): { string }
	local def = Items.get(defId)
	local classes = if def then classesFor(def, forClass) elseif forClass then { forClass } else nil
	return filtered(Bonuses.pools.legendary, classes)
end

function ItemRoll.mythicPool(defId: string, forClass: string?): { string }
	local def = Items.get(defId)
	local classes = if def then classesFor(def, forClass) elseif forClass then { forClass } else nil
	return filtered(Bonuses.pools.mythic, classes)
end

-- Exact chance (0..1) that each line is among `count` weighted draws without replacement (Rng.weighted per draw).
function ItemRoll.inclusion(weights: { [string]: number }, count: number): { [string]: number }
	local ids: { string } = {}
	local out: { [string]: number } = {}
	local total = 0
	for id, w in weights do
		out[id] = 0
		if w > 0 then
			table.insert(ids, id)
			total += w
		end
	end
	table.sort(ids)
	local used: { [string]: boolean } = {}
	local function walk(p: number, left: number, remaining: number)
		if left <= 0 or remaining <= 0 then
			return
		end
		for _, id in ids do
			if not used[id] then
				local w = weights[id]
				local q = p * w / remaining
				out[id] += q
				used[id] = true
				walk(q, left - 1, remaining - w)
				used[id] = false
			end
		end
	end
	walk(1, math.min(count, #ids), total)
	return out
end

-- S67 (STATY 4, 7): the variant line of a pool marker. Family: the drop's family when known, else a random one;
-- class: always a random class (the wearer's too). Never nil, never a marker.
local function expandParam(id: string, rng: Rng.Rng, ctx: RollContext?): string
	local param = Bonuses.params[id]
	if param.over == "family" then
		local family = ctx and ctx.family
		if not family or not Families.get(family) then
			family = rng:pick(Families.ids :: any) :: string
		end
		return Bonuses.familyLine(param.prefix, family :: string)
	end
	return Bonuses.classLine(param.prefix, rng:pick(Classes.order :: any) :: string)
end

-- Rolls an item instance. Equipment gets bonusMin..bonusMax random bonuses of its rarity (no repeats) plus
-- `legendaryLines` distinct lines from the legendary pool and `mythicLines` from the mythic pool; named boss items get their fixed bonuses and fixed
-- rarity (Mythic); everything else is a single unit of its definition's rarity. `forClass` (S32) is the class a
-- class-free item (jewellery) dropped for: its bonuses are useful to that class. `ctx` (S67): the family of the
-- monster that dropped it; without it a family marker rolls a random family.
function ItemRoll.rollItem(
	defId: string,
	ilvl: number,
	rarity: number,
	rng: Rng.Rng,
	uid: string,
	forClass: string?,
	ctx: RollContext?
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

	-- S62: weighted draw without replacement (Data/ItemTraits affinity); the rng sequence changed, seeded tests that check exact lines were re-based
	local count = if rarityDef.bonusMax > 0 then rng:int(rarityDef.bonusMin, rarityDef.bonusMax) else 0
	if count > 0 then
		local remaining = ItemRoll.poolWeights(defId, forClass)
		for _ = 1, count do
			if next(remaining) == nil then
				break
			end
			local id = rng:weighted(remaining)
			remaining[id] = nil
			if Bonuses.isParam(id) then
				id = expandParam(id, rng, ctx)
			end
			table.insert(bonuses, { stat = id, v = ItemRoll.rollBonusValue(id, level, rarityId, rng:next()) })
		end
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

-- S62 (STATY 2A, 10): trait strength = rarity baseMul (named boss items too) x (1 + 0.06 x upgrade level).
function ItemRoll.traitPower(rarity: number, up: number?): number
	return Rarities.get(rarity).baseMul * (1 + Rarities.upgradeStatPerLevel * (up or 0))
end

-- The live trait of an item's base type, or nil (no trait, or no code yet: live = false).
function ItemRoll.trait(item: ItemInstance): TraitRoll?
	local def = Items.get(item.id)
	local traitDef = if def then ItemTraits.get(def.trait) else nil
	if not traitDef or not traitDef.live then
		return nil
	end
	local rarity = math.clamp(math.floor(item.rarity or Rarities.COMMON), Rarities.COMMON, Rarities.MAX)
	local power = ItemRoll.traitPower(rarity, item.up)
	return { id = traitDef.id, def = traitDef, power = power, value = traitDef.value * power }
end

-- A base stat key "<stat>Pct" (S32: off-hands and rings) is a % multiplier of <stat>; anything else is flat.
function ItemRoll.baseKey(key: string): (string, boolean)
	local stat = string.match(key, "^(.+)Pct$")
	if stat then
		return stat, true
	end
	return key, false
end

-- S87 (balance plan C2): a regular line (not from the legendary or mythic pools, scaling with the item level) gets
-- Rarities.twoHandedBonusMul on a rolled two-handed weapon.
function ItemRoll.isRegularLine(bonusId: string): boolean
	local def = Bonuses.get(bonusId)
	return def ~= nil and def.tier == "regular" and def.scaling ~= "none"
end

-- Upgrade share per level of an item's base stats and weapon damage (S87: two-handed weapons 6.6 %, the rest 6 %).
function ItemRoll.upgradeStatPerLevel(twoHanded: boolean?): number
	return if twoHanded then Rarities.upgradeStatPerLevelTwoHanded else Rarities.upgradeStatPerLevel
end

-- S87: Rarities.twoHandedBonusMul for a rolled (not named) item whose weapon is two-handed, else 1.
local function twoHandedLineMul(def: Items.ItemDef, weapon: any): number
	return if def.fixedBonuses == nil
			and weapon ~= nil
			and weapon.twoHanded == true
		then Rarities.twoHandedBonusMul
		else 1
end

-- Multiplier of line `bonusId` on `item` as itemStats applies it (S87: a regular line of a rolled two-handed
-- weapon x twoHandedBonusMul, else 1); the tooltip scales the line's range with it.
function ItemRoll.lineMultiplier(item: ItemInstance, bonusId: string): number
	local def = Items.get(item.id)
	if not def or not ItemRoll.isRegularLine(bonusId) then
		return 1
	end
	local scaling = if def.tier and def.fixedBonuses == nil then Items.bases.byType[def.type] else nil
	local weapon = if scaling and scaling.weapon then scaling.weapon(math.max(1, item.ilvl)) else def.weapon
	return twoHandedLineMul(def, weapon)
end

-- Stats of an item instance: base (rarity + upgrade), weapon, and bonus totals mapped to StatCalc ids.
function ItemRoll.itemStats(item: ItemInstance): ItemStats
	local def = Items.get(item.id)
	local result: ItemStats = { base = {}, weapon = nil, flat = {}, pct = {}, hooks = {}, bonuses = {} }
	if not def then
		return result
	end
	local named = def.fixedBonuses ~= nil
	-- S18: generated equipment scales with the instance's ilvl (every level beats the one before); the
	-- tier definition only names it. Named items keep their fixed base (S30 fix: it was recomputed and lost ×1.3).
	local scaling = if def.tier and not named then Items.bases.byType[def.type] else nil
	local weapon = if scaling and scaling.weapon then scaling.weapon(math.max(1, item.ilvl)) else def.weapon
	-- S87 (balance plan C2, G8): two-handed weapons read on load (owned items too, no migration)
	local twoHanded = weapon ~= nil and weapon.twoHanded == true
	-- Named items already carry their ×1.3 in the definition: no rarity multiplier on top (S30 B.2).
	local baseMul = if named then 1 else Rarities.get(item.rarity).baseMul
	local multiplier = baseMul * (1 + ItemRoll.upgradeStatPerLevel(twoHanded) * (item.up or 0))
	local lineMul = twoHandedLineMul(def, weapon)

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
			local id, v = bonus.stat, bonus.v
			local quality = ItemRoll.bonusQuality(id, v, item.ilvl, item.rarity, named)
			local replacement = if bonusDef.replacedBy then Bonuses.get(bonusDef.replacedBy) else nil
			if replacement then
				-- STATY 12: a legacy line (flat armorPen) reads as its replacement with the same roll quality; the
				-- save keeps the old id and the conversion runs on every read.
				id = replacement.id
				v = ItemRoll.rollBonusValue(id, item.ilvl, item.rarity, quality)
				bonusDef = replacement
			end
			-- S87: regular lines of a rolled two-handed weapon x twoHandedBonusMul (quality from the saved value)
			if lineMul ~= 1 and ItemRoll.isRegularLine(id) then
				v = roundTo(v * lineMul, bonusDef.decimals)
			end
			table.insert(result.bonuses, { id = id, v = v, quality = quality })
			if bonusDef.hook then
				result.hooks[bonusDef.hook] = (result.hooks[bonusDef.hook] or 0) + v
			elseif bonusDef.stat then
				local target = if bonusDef.mode == "pct" then result.pct else result.flat
				target[bonusDef.stat] = (target[bonusDef.stat] or 0) + v
			end
		end
	end

	-- S62: the base type's trait (a stat trait adds like a line; hook / effect traits go to hooks once live).
	local trait = ItemRoll.trait(item)
	if trait then
		local traitDef = trait.def
		local contrib: TraitContrib = { flat = {}, hooks = {} }
		if traitDef.kind == "stat" and traitDef.stat then
			result.flat[traitDef.stat] = (result.flat[traitDef.stat] or 0) + trait.value
			contrib.flat[traitDef.stat] = trait.value
		elseif traitDef.hook then
			result.hooks[traitDef.hook] = (result.hooks[traitDef.hook] or 0) + trait.value
			contrib.hooks[traitDef.hook] = trait.value
		end
		-- S64: fixed hooks (Swordplay's counter, Parry's block chance) never grow with the trait strength.
		local fixedHooks: { [string]: number } = traitDef.fixedHooks or {}
		for hookId, v in fixedHooks do
			result.hooks[hookId] = (result.hooks[hookId] or 0) + v
			contrib.hooks[hookId] = (contrib.hooks[hookId] or 0) + v
		end
		trait.contrib = contrib
		result.trait = trait
	end
	return result
end

-- Level needed to equip or use: the ilvl for generated equipment (S18), the definition's level otherwise. S87: the
-- ilvl branch only for equipment (potions, materials and blessings also carry `tier`; a potion stack from before S87
-- has ilvl 1, its definition says 45 / 70).
function ItemRoll.requiredLevel(item: ItemInstance): number
	local def = Items.get(item.id)
	if not def then
		return 1
	end
	return if def.category == "equipment" and def.tier then math.max(1, item.ilvl) else def.level or 1
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
