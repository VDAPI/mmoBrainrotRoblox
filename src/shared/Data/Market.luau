--!strict
-- Auction house and mail balance (DESIGN §18). The auction takes a 1 % deposit when listing (kept on
-- cancel, returned with the payment on a sale) and a 5 % fee from the sale price.

export type Category = {
	id: string,
	nameKey: string,
	slots: { string }?, -- equipment slot groups (Items.Types.SlotGroup)
	itemCategories: { string }?, -- Items.Types.Category for non-equipment
}

local function category(id: string, slots: { string }?, itemCategories: { string }?): Category
	return { id = id, nameKey = `auction.category.{id}`, slots = slots, itemCategories = itemCategories }
end

local CATEGORIES: { Category } = {
	category("weapon", { "weapon" }),
	category("offhand", { "offhand" }),
	category("armor", { "helmet", "armor", "gloves", "boots" }),
	category("jewelry", { "necklace", "ring", "talisman" }),
	category("material", nil, { "material" }),
	category("consumable", nil, { "consumable", "scroll", "stone" }),
	category("other", nil, { "backpack", "tool" }),
}

local byId: { [string]: Category } = {}
for _, entry in CATEGORIES do
	byId[entry.id] = entry
end

local Auction = table.freeze({
	depositPct = 1,
	feePct = 5,
	durations = { 24, 48 }, -- hours
	maxListings = 20, -- active listings per character
	minPrice = 1,
	maxPrice = 1000000000,
	pageSize = 20,
	scanLimit = 200, -- index entries read per category and sort direction
	searchCacheSeconds = 10,
	expireSweepSeconds = 300,
	historySize = 20, -- sales remembered per item id for the average price
})

local Mail = table.freeze({
	lifetimeDays = 30,
	maxParcels = 100, -- per account
	maxItemsPerParcel = 10,
})

return table.freeze({
	categories = CATEGORIES,
	categoryById = byId,
	getCategory = function(id: string): Category?
		return byId[id]
	end,
	Auction = Auction,
	Mail = Mail,
})
