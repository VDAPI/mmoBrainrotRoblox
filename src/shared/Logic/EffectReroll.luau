--!strict
-- S160k (owner 2026-10-21, docs/DESIGN.md §6a): "Change effect" at the smith. Pure (Lune and Roblox); the server
-- (BlacksmithService.RerollEffect) rolls with its rng, the forge's Effect tab previews with the same functions.
--   * One skill effect (`fx`, S134g) of a Legendary or Mythic item is replaced by another effect of the SAME tier:
--     a legendary effect only ever becomes a legendary one, a mythic one a mythic one (no Mythic effect leaks onto a
--     Legendary item, no second mythic effect on a Mythic one).
--   * The pool is Logic/ItemEffects.pool, the drop's own rule: the class (the character's when the item fits it, else
--     the class of the effect being replaced), a Mage weapon's element, a weapon's own skill pool and the class's
--     common skills; without the effects the item already has (the other ones and the current one). Every candidate
--     is equally likely (a drop draws them uniformly too).
--   * Named boss items (definition `fx` / `fixedBonuses`) and items below Legendary are never changed.
--   * Cost: gold ilvl x Upgrade.goldPerIlvl x Config.Reroll.effectGoldMul, the essence of the rarity
--     (Config.Reroll.effectEssence) and one Stone of Effect Transmutation (EffectReroll.STONE), all together.

local Config = require("../Config")
local ItemEffects = require("./ItemEffects")
local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Reroll = require("./Reroll")
local Rng = require("./Rng")
local Types = require("../Types")
local Upgrade = require("./Upgrade")

type ItemInstance = Types.ItemInstance
type ItemEffectDef = ItemEffects.ItemEffectDef

local EffectReroll = {}

-- The premium item every change of an effect takes (Data/Items/Consumables, Data/Products: 100 Dragon Shards, 10 a day).
EffectReroll.STONE = "effect_stone"

export type Cost = Upgrade.Cost
export type Outcome = { id: string, chance: number }

local function fxList(item: ItemInstance): { any }
	local raw: any = (item :: any).fx
	return if type(raw) == "table" then raw else {}
end

-- Whether the item's effects can be changed at all: equipment, not a named item, Legendary or Mythic, with an effect.
function EffectReroll.eligible(item: ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	if not def or def.category ~= "equipment" then
		return false, "smith.effect.error.none"
	end
	if def.fixedBonuses or def.fx then
		return false, "smith.effect.error.fixed"
	end
	local rarity = tonumber(item.rarity) or 0
	if rarity < Rarities.LEGENDARY then
		return false, "smith.effect.error.rarity"
	end
	for _, id in ipairs(fxList(item)) do
		if ItemEffects.resolve(id) then
			return true, nil
		end
	end
	return false, "smith.effect.error.none"
end

-- The live definition of effect `index` (nil for a bad index or an unknown id).
function EffectReroll.effectAt(item: ItemInstance, index: number): ItemEffectDef?
	if type(index) ~= "number" or index ~= math.floor(index) then
		return nil
	end
	local id = fxList(item)[index]
	return if type(id) == "string" then ItemEffects.resolve(id) else nil
end

-- Whether effect `index` can be changed now.
function EffectReroll.canIndex(item: ItemInstance, index: number): (boolean, string?)
	local ok, err = EffectReroll.eligible(item)
	if not ok then
		return false, err
	end
	if not EffectReroll.effectAt(item, index) then
		return false, "smith.effect.error.none"
	end
	return true, nil
end

-- The class the new effect is drawn for: the character's when the item fits it (Reroll.classFor), else the class of
-- the effect being replaced.
function EffectReroll.classFor(item: ItemInstance, current: ItemEffectDef, classId: string?): string
	return Reroll.classFor(item, classId) or current.class
end

-- The effects effect `index` can become (data order): the drop pool of its tier without the item's own effects.
function EffectReroll.pool(item: ItemInstance, index: number, classId: string?): { ItemEffectDef }
	local out: { ItemEffectDef } = {}
	local current = EffectReroll.effectAt(item, index)
	local def = Items.get(item.id)
	if not current or not def then
		return out
	end
	local taken: { [string]: boolean } = {}
	for _, id in ipairs(fxList(item)) do
		local live = ItemEffects.resolve(id)
		if live then
			taken[live.id] = true
		end
	end
	local weaponType = if def.slot == "weapon" then def.type else nil
	local class = EffectReroll.classFor(item, current, classId)
	for _, candidate in ItemEffects.pool(class, current.tier, ItemRoll.elementOf(item), weaponType) do
		if not taken[candidate.id] and candidate.tier == current.tier then
			table.insert(out, candidate)
		end
	end
	return out
end

-- What effect `index` can become, each with its chance (uniform; the chances add up to 1).
function EffectReroll.preview(item: ItemInstance, index: number, classId: string?): { Outcome }
	local pool = EffectReroll.pool(item, index, classId)
	local out: { Outcome } = {}
	for _, def in pool do
		table.insert(out, { id = def.id, chance = 1 / #pool })
	end
	return out
end

-- Draws the new effect id for `index`. Does not change the item.
function EffectReroll.roll(item: ItemInstance, index: number, classId: string?, rng: Rng.Rng): string
	local pool = EffectReroll.pool(item, index, classId)
	assert(#pool > 0, "EffectReroll: empty pool")
	return (rng:pick(pool :: { any }) :: ItemEffectDef).id
end

-- Writes `id` into effect `index` (a new fx list, the order unchanged). Nothing else of the item changes.
function EffectReroll.apply(item: ItemInstance, index: number, id: string)
	local fx = table.clone(fxList(item))
	fx[index] = id
	item.fx = fx
end

-- The gold and essence of one change (without the stone).
function EffectReroll.cost(item: ItemInstance): Cost
	local c = Config.Reroll
	local ilvl = math.max(1, math.floor(tonumber(item.ilvl) or 1))
	local gold = math.floor(ilvl * Upgrade.goldPerIlvl(ilvl) * c.effectGoldMul + 0.5)
	local rarity = math.clamp(math.floor(tonumber(item.rarity) or 1), Rarities.COMMON, Rarities.MAX)
	local essence = (c.effectEssence :: { [string]: { id: string, n: number } })[Rarities.get(rarity).key]
	local materials = {}
	if essence then
		table.insert(materials, { id = essence.id, n = essence.n })
	end
	return { gold = gold, materials = materials }
end

-- What the smith takes: the gold, the essence and one Stone of Effect Transmutation (the last material).
function EffectReroll.payment(item: ItemInstance): Cost
	local cost = EffectReroll.cost(item)
	table.insert(cost.materials, { id = EffectReroll.STONE, n = 1 })
	return cost
end

return EffectReroll
