--!strict
-- Unit price of a shop entry (DESIGN §9, §18, §19). Shared by ShopService and the shop window so both
-- show the same number: entry price / item buyPrice / per-level price, minus the potion discount
-- (derived stat potionDiscount from the guild skill "Healer's Grace").

local Items = require("../Data/Items")
local Shops = require("../Data/Shops")
local Stats = require("../Data/Stats")

local ShopPrice = {}

function ShopPrice.isPotion(itemId: string): boolean
	local def = Items.get(itemId)
	local use = def and (def :: any).use
	return use ~= nil and use.kind == "potion"
end

function ShopPrice.unit(entry: Shops.Entry, level: number, potionDiscount: number?): number
	local price: number
	if entry.pricePerLevel then
		price = entry.pricePerLevel * level
	else
		local def = Items.get(entry.item)
		price = entry.price or (if def then def.buyPrice else nil) or 0
	end
	local discount = potionDiscount or 0
	if discount > 0 and price > 0 and ShopPrice.isPotion(entry.item) then
		local cap = (Stats.get("potionDiscount") :: any).cap or 50
		price = math.max(1, math.floor(price * (1 - math.min(discount, cap) / 100) + 0.5))
	end
	return price
end

return ShopPrice
