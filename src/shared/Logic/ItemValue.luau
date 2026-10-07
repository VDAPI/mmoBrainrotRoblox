--!strict
-- One value per item instance (S31, DESIGN §5, §18). Pure; used by the server (shop buy/sell/buyback, trade)
-- and the UI (tooltips, shop rows) so both always show the same number.
--   value(item, def?)            -> what the item is worth ("Wartość"); merchants pay exactly this
--   sellPrice(item, def?)        -> value, or 0 when the item cannot be sold (locked / noSell)
--   buyPrice(entry, shop?, level?) -> NPC price of one unit of a shop entry (before the guild potion discount)

local Data = require("../Data/ItemValue")
local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Shops = require("../Data/Shops")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance
type ItemDef = Items.ItemDef

local ItemValue = {}

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- Value of one equipment piece of this rarity, item level and upgrade (named Mythic items use the same rule).
function ItemValue.equipment(def: ItemDef, ilvl: number, rarity: number, up: number?): number
	local mul = Rarities.get(rarity).sellMul
	local slotMul = Data.slotMul[def.slot or ""] or Data.defaultSlotMul
	local level = math.max(1, ilvl)
	local value = Data.perLevel * level * mul * mul * slotMul * (1 + Data.upgradePerLevel * (up or 0))
	return math.max(Data.minValue, round(value))
end

function ItemValue.value(item: ItemInstance, def: ItemDef?): number
	local itemDef = def or Items.get(item.id)
	if not itemDef then
		return 0
	end
	if itemDef.category == "equipment" then
		return ItemValue.equipment(itemDef, item.ilvl, item.rarity, item.up)
	end
	return math.max(Data.minValue, itemDef.price) * math.max(1, item.n or 1)
end

-- Whether a merchant takes the item (the server refuses locked items and `noSell` definitions).
function ItemValue.canSell(item: ItemInstance, def: ItemDef?): boolean
	local itemDef = def or Items.get(item.id)
	if not itemDef or itemDef.noSell then
		return false
	end
	return not item.locked
end

function ItemValue.sellPrice(item: ItemInstance, def: ItemDef?): number
	if not ItemValue.canSell(item, def) then
		return 0
	end
	return ItemValue.value(item, def)
end

-- The (common, +0, single) item a shop entry hands out; used for its value and the tooltip preview.
function ItemValue.entryItem(entry: Shops.Entry): ItemInstance
	local def = Items.get(entry.item)
	return {
		uid = `shop:{entry.key or entry.item}`,
		id = entry.item,
		rarity = entry.rarity or (if def and def.rarity then def.rarity else Rarities.COMMON),
		ilvl = entry.ilvl or (if def then def.level else 1),
		bonuses = {},
		up = 0,
		bound = false,
		n = 1,
		el = entry.el,
		rv = Rarities.RV,
	}
end

-- Value of one unit sold by the entry.
function ItemValue.entryValue(entry: Shops.Entry): number
	return ItemValue.value(ItemValue.entryItem(entry))
end

-- Unit buy price at an NPC: a per-level price (teacher's scrolls), the entry's fixed price, the item's fixed
-- shop price (potions, stones, tools, backpacks), otherwise value x buyMul (shop's own or the default).
function ItemValue.buyPrice(entry: Shops.Entry, shop: Shops.ShopDef?, level: number?): number
	if entry.pricePerLevel then
		return entry.pricePerLevel * math.max(1, level or 1)
	end
	if entry.price then
		return entry.price
	end
	local def = Items.get(entry.item)
	if not def then
		return 0
	end
	if def.category ~= "equipment" and def.buyPrice and def.buyPrice > 0 then
		return def.buyPrice
	end
	local buyMul = if shop and shop.buyMul then shop.buyMul else Data.buyMul
	return math.max(1, round(ItemValue.entryValue(entry) * buyMul))
end

ItemValue.BUY_MUL = Data.buyMul

return ItemValue
