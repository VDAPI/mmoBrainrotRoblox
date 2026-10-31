--!strict
-- Item binding rules (owner 2026-10-31, docs/DESIGN.md §5.6, data in Data/Binding): one rule per item, "none",
-- "equip" or "pickup", the strongest of its definition (`bind`, else the category), its rarity (Mythic) and its
-- source. Every item grant of the server goes through Binding.apply with its source, equipping through
-- Binding.onEquip; trade, the auction house, mail and the guild vault refuse what Binding.isBound says. Pure.

local Data = require("../Data/Binding")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef
export type Rule = Data.Rule
export type Source = Data.Source

local Binding = {}

-- Typed views of the frozen data (the freeze widens the rule literals to string).
local CATEGORY: { [string]: Rule } = Data.CATEGORY :: any
local SOURCES: { [string]: Data.SourceRule } = Data.SOURCES :: any

local RANK: { [Rule]: number } = { none = 0, equip = 1, pickup = 2 }

local function stronger(a: Rule, b: Rule?): Rule
	return if b and RANK[b] > RANK[a] then b else a
end

-- The rule of a definition: its own `bind`, else its category's (unknown items never bind).
function Binding.ofDef(def: ItemDef?): Rule
	if not def then
		return "none"
	end
	return def.bind or CATEGORY[def.category] or "none"
end

-- The rule of an item wherever it came from: the definition, then the rarity (Mythic equipment binds on pickup).
function Binding.ruleOf(item: ItemInstance, def: ItemDef?): Rule
	local d = def or Items.get(item.id)
	local rule: Rule = Binding.ofDef(d)
	if d and d.category == "equipment" and Rarities.get(item.rarity).bindOnPickup then
		rule = "pickup"
	end
	return rule
end

-- The rule of an item given by `source` (Data/Binding.SOURCES): the item's own rule or what the source adds.
function Binding.ruleFrom(item: ItemInstance, source: Source, def: ItemDef?): Rule
	local d = def or Items.get(item.id)
	local rule: Rule = Binding.ruleOf(item, d)
	local spec = SOURCES[source]
	if not d or not spec then
		return rule
	end
	if d.slot then
		if spec.gear and (item.rarity or 0) >= (spec.gearFrom or 0) then
			return stronger(rule, spec.gear)
		end
		return rule
	end
	return stronger(rule, if Data.CONSUMABLE[d.category] then spec.consumable else spec.goods)
end

-- Binds `item` when its rule from `source` is "pickup" (never unbinds). Mutates and returns the item.
function Binding.apply(item: ItemInstance, source: Source): ItemInstance
	if Binding.ruleFrom(item, source) == "pickup" then
		item.bound = true
	end
	return item
end

-- Whether a stack of `defId` (or a piece of gear of `rarity`) from `source` comes bound (shop windows say so first).
function Binding.bindsFrom(defId: string, source: Source, rarity: number?): boolean
	local def = Items.get(defId)
	if not def then
		return false
	end
	local probe: ItemInstance = {
		uid = "",
		id = defId,
		rarity = rarity or def.rarity or Rarities.COMMON,
		ilvl = def.level,
		bonuses = {},
		up = 0,
		bound = false,
		n = 1,
	}
	return Binding.ruleFrom(probe, source, def) == "pickup"
end

function Binding.isBound(item: ItemInstance): boolean
	return item.bound == true
end

-- Whether equipping the item binds it now (the client asks first, ItemController.Equip).
function Binding.bindsOnEquip(item: ItemInstance, def: ItemDef?): boolean
	return not Binding.isBound(item) and Binding.ruleOf(item, def) ~= "none"
end

-- The item was equipped: it binds unless its rule is "none" (backpacks). Mutates the item.
function Binding.onEquip(item: ItemInstance, def: ItemDef?)
	if Binding.ruleOf(item, def) ~= "none" then
		item.bound = true
	end
end

-- Whether the item may leave its owner (trade, auction, mail, guild vault): never when bound. Returns (ok, errorKey?)
-- with `key` the refusal of the caller ("trade.error.bound", "auction.error.bound", "mail.error.bound").
function Binding.canTransfer(item: ItemInstance, key: string): (boolean, string?)
	if Binding.isBound(item) then
		return false, key
	end
	return true, nil
end

-- The tooltip's one binding line: bound, binds when equipped (free gear and the like), or nothing (free stacks).
function Binding.tooltipKey(item: ItemInstance, def: ItemDef?): string?
	if Binding.isBound(item) then
		return "tooltip.bound"
	end
	local d = def or Items.get(item.id)
	if d and d.slot and Binding.ruleOf(item, d) ~= "none" then
		return "tooltip.bindOnEquip"
	end
	return nil
end

-- Migration of an item saved under the old rules (schema 13, mail parcels without `bv`): a stack bound only by them
-- (potions, scrolls, stones, blessings, elixirs and materials whose own rule is "none", except the types a currency
-- shop still binds, Data/Binding.KEEP_BOUND_TYPES) and a backpack (never binds now, worn or not) come free.
-- Equipment keeps its state: nobody knows whether a bound piece in the backpack was worn. Returns true when changed.
function Binding.migrateItem(item: any): boolean
	if type(item) ~= "table" or item.bound ~= true or type(item.id) ~= "string" then
		return false
	end
	local def = Items.get(item.id)
	if not def or def.category == "equipment" or Binding.ofDef(def) ~= "none" then
		return false
	end
	if def.category == "material" and Data.KEEP_BOUND_TYPES[def.type] then
		return false
	end
	item.bound = false
	return true
end

-- Migrates every item of a slot map or a list (backpack, deposit, a parcel). Returns how many came free.
function Binding.migrateAll(items: any): number
	if type(items) ~= "table" then
		return 0
	end
	local n = 0
	for _, item in items do
		if Binding.migrateItem(item) then
			n += 1
		end
	end
	return n
end

return Binding
