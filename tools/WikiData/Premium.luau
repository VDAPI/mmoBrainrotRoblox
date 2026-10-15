--!strict
-- premium.json (S43): the ONLY exporter module that reads Data/Products (docs/WIKI.md §1). It copies the keys and icons
-- of the passes (names and descriptions from premium.pass.<key>) and the services of the premium shop (key, kind,
-- item, daily limit; name from the item or premium.rename). Never prices, Robux, product or pass ids, shard packs,
-- the instant respawn product. S122: an item sold in several packs (Elixir of Wholeness) is one row.
-- S131 (DESIGN-17 §9): only enabled passes ("VIP forever" stays off); shop rows carry `cat` and `weeklyLimit`, entries
-- marked `unavailable` and hidden items are left out; new blocks `vip` (the
-- benefits from Config.Vip and the cosmetics of the month, `dailyCurrency` instead of an amount), `items` (the rules
-- of the Elixir of Wholeness and the Cloak of Luring with the names of their blocks) and `starterPacks` (the contents
-- without a price: cosmetic ids, pass keys, `currency` instead of an amount). Never a subscription id, a price, an
-- amount of Dragon Shards or the premium mounts (S97).

local Config = require("../../src/shared/Config")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Market = require("../../src/shared/Data/Market")
local Names = require("./Names")
local Products = require("../../src/shared/Data/Products")
local Recipes = require("../../src/shared/Data/Recipes")
local Schema = require("./Schema")
local UseBlocks = require("../../src/shared/Logic/UseBlocks")

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
			cat = "string",
			["item?"] = "ref:items",
			["dailyLimit?"] = "int",
			["weeklyLimit?"] = "int",
			name = "name",
			["desc?"] = "name",
		})),
		vip = rec("VipInfo", {
			recallMin = "number",
			freeRespawnsPerDay = "int",
			auctionExtraListings = "int",
			auctionFeePct = "number",
			auctionFeeBasePct = "number",
			alchemyQueue = "int",
			dailyCurrency = "bool",
			monthCosmetics = arr(rec("VipMonthCosmetic", { month = "string", id = "string", name = "name" })),
		}),
		items = rec("PremiumItems", {
			fullElixir = rec("FullElixirInfo", { cooldown = "int", dailyLimit = "int", blocked = arr("name") }),
			lure = rec("LureInfo", {
				radius = "int",
				interval = "int",
				maxPulled = "int",
				levelGap = "int",
				blocked = arr("name"),
			}),
		}),
		starterPacks = arr(rec("StarterPackInfo", {
			key = "string",
			name = "name",
			["desc?"] = "name",
			cosmetics = arr("string"),
			passes = arr("string"),
			currency = "bool",
		})),
	})
)

-- The names of the blocks of a premium consumable (the texts the game shows), "dead" left out.
local function blocks(feature: UseBlocks.Feature): { any }
	local out = {}
	for _, reason in UseBlocks.LISTS[feature] do
		if reason ~= "dead" then
			table.insert(out, Names.of(UseBlocks.key(feature, reason)))
		end
	end
	return out
end

function Premium.build(ctx: any): any
	local passes = {}
	for _, p in Products.passes do
		-- S121: disabled passes (VIP forever) stay off the wiki
		if p.enabled ~= false then
			table.insert(passes, {
				key = p.key,
				icon = p.icon,
				name = Names.of(`premium.pass.{p.key}`),
				desc = Names.of(`premium.pass.{p.key}.desc`),
			})
		end
	end
	local shop = {}
	-- S122: one row per item (packs differ only in price and size, which the wiki never shows)
	local listed: { [string]: boolean } = {}
	for _, e in Products.shop do
		local item = e.itemId
		if not (e.unavailable or (item and (ctx.hidden[item] or listed[item]))) then
			if item then
				listed[item] = true
			end
			table.insert(shop, {
				key = e.key,
				kind = e.kind,
				cat = e.cat,
				item = item,
				dailyLimit = e.dailyLimit,
				weeklyLimit = e.weeklyLimit,
				name = if item then Names.item(item) else Names.of(`premium.{e.key}`),
				desc = if item then nil else Names.opt(`premium.{e.key}.desc`),
			})
		end
	end

	local months = {}
	for _, def in Cosmetics.list do
		local month = def.obtain and def.obtain.vipMonth
		if month and not ctx.hidden[def.id] then
			table.insert(months, {
				month = `{string.sub(month, 1, 4)}-{string.sub(month, 5, 6)}`,
				id = def.id,
				name = Names.of(def.nameKey),
			})
		end
	end
	table.sort(months, function(a, b): boolean
		return a.month < b.month
	end)

	local packs = {}
	for _, pack in Products.starterPacks do
		table.insert(packs, {
			key = pack.key,
			name = Names.of(`premium.pack.{pack.key}`),
			desc = Names.opt(`premium.pack.{pack.key}.desc`),
			cosmetics = table.clone(pack.cosmetics),
			passes = table.clone(pack.passes),
			currency = pack.shards > 0,
		})
	end

	local vip = Config.Vip
	return {
		passes = passes,
		shop = shop,
		vip = {
			recallMin = vip.freeRecallCooldown / 60,
			freeRespawnsPerDay = vip.freeRespawnsPerDay,
			auctionExtraListings = vip.auctionExtraListings,
			auctionFeePct = Market.Auction.feePct * vip.auctionFeeMul,
			auctionFeeBasePct = Market.Auction.feePct,
			alchemyQueue = Recipes.QUEUE_SLOTS_VIP - Recipes.QUEUE_SLOTS,
			dailyCurrency = vip.dailyShards > 0,
			monthCosmetics = months,
		},
		items = {
			fullElixir = {
				cooldown = Config.FullElixir.cooldown,
				dailyLimit = Config.FullElixir.dailyLimit,
				blocked = blocks("fullElixir"),
			},
			lure = {
				radius = Config.Lure.radius,
				interval = Config.Lure.interval,
				maxPulled = Config.Lure.maxPulled,
				levelGap = Config.Lure.levelGap,
				blocked = blocks("lure"),
			},
		},
		starterPacks = packs,
	}
end

return Premium
