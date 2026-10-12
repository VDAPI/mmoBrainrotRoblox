--!strict
-- premium.json (S43): the ONLY exporter module that reads Data/Products (docs/WIKI.md §1). It copies the keys and icons
-- of the passes (names and descriptions from premium.pass.<key>) and the services of the premium shop (key, kind,
-- item, daily limit; name from the item or premium.rename). Never prices, Robux, product or pass ids, shard packs,
-- the instant respawn product.

local Names = require("./Names")
local Products = require("../../src/shared/Data/Products")
local Schema = require("./Schema")

local S = Schema
local arr, rec = S.arr, S.rec

local Premium = {}

S.file(
	"premium",
	rec("PremiumFile", {
		passes = arr(rec("PassInfo", { key = "string", icon = "string", name = "name", desc = "name" })),
		shop = arr(rec("PremiumService", {
			key = "string",
			kind = "string",
			["item?"] = "ref:items",
			["dailyLimit?"] = "int",
			name = "name",
			["desc?"] = "name",
		})),
	})
)

function Premium.build(ctx: any): any
	local passes = {}
	for _, p in Products.passes do
		table.insert(passes, {
			key = p.key,
			icon = p.icon,
			name = Names.of(`premium.pass.{p.key}`),
			desc = Names.of(`premium.pass.{p.key}.desc`),
		})
	end
	local shop = {}
	for _, e in Products.shop do
		local item = e.itemId
		if not (item and ctx.hidden[item]) then
			table.insert(shop, {
				key = e.key,
				kind = e.kind,
				item = item,
				dailyLimit = e.dailyLimit,
				name = if item then Names.item(item) else Names.of(`premium.{e.key}`),
				desc = if item then nil else Names.opt(`premium.{e.key}.desc`),
			})
		end
	end
	return { passes = passes, shop = shop }
end

return Premium
