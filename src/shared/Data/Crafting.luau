--!strict
-- Blacksmith recipes (DESIGN §8): every equipment base type at every tier, for gold + ore. The result is a
-- Common item with fixed average stats (no random bonuses) — a safety net, drops are better.
-- Recipe id = item id ("sword1h_30").

local Bases = require("./Items/Bases")

export type Recipe = {
	id: string,
	item: string,
	level: number,
	gold: number,
	materials: { { id: string, n: number } },
	classes: { string }?,
	slot: string,
}

-- Ore by tier band (DESIGN §12: copper .. adamantite by zone).
local function oreFor(tier: number): string
	if tier < 20 then
		return "ore_copper"
	elseif tier < 45 then
		return "ore_iron"
	elseif tier < 70 then
		return "ore_silver"
	elseif tier < 90 then
		return "ore_mithril"
	end
	return "ore_adamantite"
end

local RECIPES: { [string]: Recipe } = {}
local LIST: { Recipe } = {}

for _, base in Bases.list do
	for _, tier in Bases.tiers do
		local id = `{base.type}_{tier}`
		local materials = { { id = oreFor(tier), n = 3 + math.floor(tier / 15) } }
		if tier >= 30 then
			table.insert(materials, { id = "essence_dust", n = 2 + math.floor(tier / 20) })
		end
		local recipe: Recipe = {
			id = id,
			item = id,
			level = tier,
			gold = Bases.priceAt(tier) * 3,
			materials = materials,
			classes = base.classes,
			slot = base.slot,
		}
		RECIPES[id] = recipe
		table.insert(LIST, recipe)
	end
end

return table.freeze({
	byId = RECIPES,
	list = LIST,
	get = function(id: string): Recipe?
		return RECIPES[id]
	end,
	oreFor = oreFor,
})
