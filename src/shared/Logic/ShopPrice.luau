--!strict
-- Unit price of a shop entry (DESIGN §9, §18, §19). Shared by ShopService and the shop window so both
-- show the same number: Logic/ItemValue.buyPrice (fixed / per-level / value x buyMul), minus the potion
-- discount (derived stat potionDiscount from the guild skill "Healer's Grace").

local ItemValue = require("./ItemValue")
local Items = require("../Data/Items")
local Shops = require("../Data/Shops")
local Stats = require("../Data/Stats")

local ShopPrice = {}

function ShopPrice.isPotion(itemId: string): boolean
	local def = Items.get(itemId)
	local use = def and (def :: any).use
	return use ~= nil and use.kind == "potion"
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
