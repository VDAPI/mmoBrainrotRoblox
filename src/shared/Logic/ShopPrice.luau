--!strict
-- Unit price of a shop entry (DESIGN §9, §18, §19). Shared by ShopService and the shop window so both
-- show the same number: Logic/ItemValue.buyPrice (fixed / per-level / value x buyMul), minus the potion
-- discount (derived stat potionDiscount from the guild skill "Healer's Grace").

local ItemValue = require("./ItemValue")
local Items = require("../Data/Items")
local Paths = require("./Paths")
local Shops = require("../Data/Shops")
local Stats = require("../Data/Stats")

local ShopPrice = {}

function ShopPrice.isPotion(itemId: string): boolean
	local def = Items.get(itemId)
	local use = def and (def :: any).use
	return use ~= nil and use.kind == "potion"
end

-- S57: whether the entry is sold to a character of `classId` (needsPaths: only classes with paths, the Scroll of a
-- New Path).
function ShopPrice.offered(entry: Shops.Entry, classId: string): boolean
	return not entry.needsPaths or Paths.classHasPaths(classId)
end

-- S95: whether a character of `classId` can buy the entry: entries without `classes` (potions, ores, scrolls) for
-- everyone, gear only for the classes that can wear it (the class vendors show the rest locked).
function ShopPrice.usableBy(entry: Shops.Entry, classId: string?): boolean
	if entry.classes == nil then
		return true
	end
	return classId ~= nil and table.find(entry.classes, classId) ~= nil
end

function ShopPrice.unit(entry: Shops.Entry, level: number, potionDiscount: number?, shop: Shops.ShopDef?): number
	local price = ItemValue.buyPrice(entry, shop, level)
	local discount = potionDiscount or 0
	if discount > 0 and price > 0 and ShopPrice.isPotion(entry.item) then
		local cap = (Stats.get("potionDiscount") :: any).cap or 50
		price = math.max(1, math.floor(price * (1 - math.min(discount, cap) / 100) + 0.5))
	end
	return price
end

return ShopPrice
