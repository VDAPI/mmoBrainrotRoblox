--!strict
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local Time = require("../src/shared/Logic/Time")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local DAY = 86400
local MONDAY = 1791763200 -- 2026-10-12 00:00 UTC (S98)

T.describe("Premium shop", function()
	local protection = Products.getShop("scroll_protection") :: Products.ShopEntry

	T.it("scroll of protection is limited to 1 a day", function()
		local now = 10 * DAY + 5
		local account = { dragonShards = 1000, shopLimits = Premium.emptyLimits() }
		T.expect((Premium.canBuy(protection, account, now))).toBe(true)
		account.shopLimits = Premium.countPurchase(protection, account, now)
		T.expect({ Premium.canBuy(protection, account, now) }).toEqual({ false, "premium.error.dailyLimit" })
		-- New UTC day resets the counter.
		T.expect((Premium.canBuy(protection, account, now + DAY))).toBe(true)
		T.expect(Premium.countPurchase(protection, account, now + DAY).daily.scroll_protection).toBe(1)
	end)

	T.it("weekly limit counts Monday to Sunday", function()
		local entry: Products.ShopEntry =
			{ key = "x", kind = "item", cat = "scroll", itemId = "scroll_unbind", price = 1, weeklyLimit = 2 }
		T.expect(Time.weekNumber(MONDAY)).toBe(2963)
		local account = { dragonShards = 100, shopLimits = Premium.emptyLimits() }
		for _ = 1, 2 do
			T.expect((Premium.canBuy(entry, account, MONDAY + 3600))).toBe(true)
			account.shopLimits = Premium.countPurchase(entry, account, MONDAY + 3600)
		end
		T.expect({ Premium.canBuy(entry, account, MONDAY + 3600) }).toEqual({ false, "premium.error.weeklyLimit" })
		local sundayLast = MONDAY + 7 * DAY - 1 -- 2026-10-18 23:59:59
		T.expect({ Premium.canBuy(entry, account, sundayLast) }).toEqual({ false, "premium.error.weeklyLimit" })
		T.expect((Premium.canBuy(entry, account, MONDAY + 7 * DAY))).toBe(true)
		T.expect(select(2, Premium.usedOf(entry, account, sundayLast))).toBe(2)
		T.expect(select(2, Premium.usedOf(entry, account, MONDAY + 7 * DAY))).toBe(0)
	end)

	T.it("checks availability, then limits, then shards", function()
		local now = 10 * DAY
		local used = Premium.countPurchase(protection, { shopLimits = Premium.emptyLimits() }, now)
		T.expect({ Premium.canBuy(protection, { dragonShards = 0, shopLimits = used }, now) }).toEqual({
			false,
			"premium.error.dailyLimit",
		})
		T.expect({ Premium.canBuy(protection, { dragonShards = 0 }, now) }).toEqual({ false, "premium.error.shards" })
		local soon = table.clone(protection) :: Products.ShopEntry
		soon.unavailable = true
		T.expect({ Premium.canBuy(soon, { dragonShards = 0, shopLimits = used }, now) }).toEqual({
			false,
			"premium.error.soon",
		})
		T.expect({ Premium.canBuy(nil, { dragonShards = 1e9 }, now) }).toEqual({ false, "error.badRequest" })
		local oblivion = Products.getShop("scroll_oblivion") :: Products.ShopEntry
		T.expect({ Premium.canBuy(oblivion, { dragonShards = 1 }, 0) }).toEqual({ false, "premium.error.shards" })
	end)

	T.it("limitsOf never mutates and resets on a new day / week", function()
		local entry: Products.ShopEntry = {
			key = "y",
			kind = "item",
			cat = "scroll",
			itemId = "scroll_unbind",
			price = 1,
			dailyLimit = 3,
			weeklyLimit = 5,
		}
		local saved = Premium.countPurchase(entry, { shopLimits = Premium.emptyLimits() }, MONDAY)
		table.freeze(saved.daily)
		table.freeze(saved.weekly)
		table.freeze(saved)
		local account = table.freeze({ shopLimits = saved })
		local same = Premium.limitsOf(account, MONDAY + 60)
		T.expect(same ~= saved).toBe(true)
		T.expect({ same.daily.y, same.weekly.y }).toEqual({ 1, 1 })
		local after = Premium.countPurchase(entry, account, MONDAY + 60)
		T.expect({ after.daily.y, after.weekly.y, saved.daily.y }).toEqual({ 2, 2, 1 })
		local tuesday = Premium.limitsOf(account, MONDAY + DAY)
		T.expect(tuesday.daily.y).toBeNil()
		T.expect({ tuesday.weekly.y, tuesday.day }).toEqual({ 1, Time.dayNumber(MONDAY + DAY) })
		local nextWeek = Premium.limitsOf(account, MONDAY + 7 * DAY)
		T.expect(nextWeek.daily.y).toBeNil()
		T.expect(nextWeek.weekly.y).toBeNil()
		T.expect(nextWeek.week).toBe(Time.weekNumber(MONDAY + 7 * DAY))
	end)

	T.it("pre-S120 counter is read on the day of the update", function()
		local now = 20 * DAY + 100
		local account = {
			dragonShards = 1000,
			shopLimits = Premium.emptyLimits(),
			dailyLimits = { day = Time.dayNumber(now), protectScrolls = 3 },
		}
		T.expect((Premium.usedOf(protection, account, now))).toBe(3)
		T.expect({ Premium.canBuy(protection, account, now) }).toEqual({ false, "premium.error.dailyLimit" })
		T.expect((Premium.usedOf(protection, account, now + DAY))).toBe(0)
		T.expect((Premium.canBuy(protection, account, now + DAY))).toBe(true)
	end)

	T.it("tabs and sections", function()
		T.expect(#Premium.TABS).toBe(5)
		T.expect(Premium.visibleTabs(0)).toEqual({ "currency", "passes", "items", "cosmetics" })
		T.expect(Premium.visibleTabs(1)).toEqual({ "currency", "passes", "items", "cosmetics", "mounts" })
		local seen: { [string]: number } = {}
		local cats = {}
		for _, section in Premium.shopSections() do
			T.expect(#section.entries > 0).toBe(true)
			table.insert(cats, section.cat)
			for _, entry in section.entries do
				T.expect(entry.cat).toBe(section.cat)
				seen[entry.key] = (seen[entry.key] or 0) + 1
			end
		end
		local expected = {}
		for _, cat in Products.shopCats do
			if #Products.shopIn(cat) > 0 then
				table.insert(expected, cat)
			end
		end
		T.expect(cats).toEqual(expected)
		for _, entry in Products.shop do
			T.expect({ entry.key, seen[entry.key] }).toEqual({ entry.key, 1 })
		end
	end)

	T.it("robux state", function()
		T.expect(Premium.robuxState(0, false)).toBe("soon")
		T.expect(Premium.robuxState(0, true)).toBe("buy")
		T.expect(Premium.robuxState(123, false)).toBe("buy")
	end)

	T.it("shown passes", function()
		local off: any = { key = "b", passId = 0, robux = 1, icon = "b", enabled = false }
		local list: { Products.Pass } = { { key = "a", passId = 0, robux = 1, icon = "a" }, off }
		T.expect(#Premium.shownPasses({}, list)).toBe(1)
		T.expect(#Premium.shownPasses({ b = true }, list)).toBe(2)
		-- S121: "VIP forever" is switched off (enabled = false): hidden unless owned
		local enabled = 0
		for _, pass in Products.passes do
			if (pass :: any).enabled ~= false then
				enabled += 1
			end
		end
		T.expect(#Premium.shownPasses({})).toBe(enabled)
		T.expect(#Premium.shownPasses({ vip = true })).toBe(#Products.passes)
	end)

	T.it("pack bonus", function()
		local base = Products.shardPacks[1]
		local last = -1
		for i, pack in Products.shardPacks do
			local bonus = Premium.packBonus(pack)
			local expected = math.floor((pack.shards / pack.robux) / (base.shards / base.robux) * 100 + 1e-9) - 100
			T.expect({ pack.key, bonus }).toEqual({ pack.key, expected })
			if i == 1 then
				T.expect(bonus).toBe(0)
			end
			T.expect(bonus > last).toBe(true)
			last = bonus
		end
		T.expect(Premium.balanceAfter(100, 60)).toBe(40)
	end)

	T.it("account template has shopLimits (S120, no migration)", function()
		T.expect(AccountSchema.accountTemplate().shopLimits).toEqual(Premium.emptyLimits())
		local old: any = AccountSchema.accountTemplate()
		old.shopLimits = nil
		old.dailyLimits = { day = 5, protectScrolls = 2 }
		AccountSchema.migrate(old, function(): string
			return "id"
		end)
		T.expect(old.shopLimits).toEqual(Premium.emptyLimits())
		T.expect(old.dailyLimits).toEqual({ day = 5, protectScrolls = 2 })
	end)

	T.it("scroll_skillreset is sold again (S81)", function()
		local entry = Products.getShop("scroll_skillreset") :: Products.ShopEntry
		T.expect((Premium.canBuy(entry, { dragonShards = 1000 }, 0))).toBe(true)
		T.expect(entry.unavailable).toBeNil()
		-- S120: "Soon" is back for entries and Robux products without an id (DESIGN-17 §0.8).
		for _, key in { "premium.soon", "premium.error.soon" } do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("cosmetics are bought once and equipped only when owned", function()
		T.expect((Premium.canBuyCosmetic("pet_fox", {}, 1e6))).toBe(true)
		T.expect({ Premium.canBuyCosmetic("pet_fox", { pet_fox = true }, 1e6) })
			.toEqual({ false, "premium.error.owned" })
		T.expect({ Premium.canBuyCosmetic("pet_fox", {}, 1) }).toEqual({ false, "premium.error.shards" })
		T.expect({ Premium.canEquip("pet", "pet_fox", {}) }).toEqual({ false, "premium.error.notOwned" })
		T.expect((Premium.canEquip("pet", "pet_fox", { pet_fox = true }))).toBe(true)
		T.expect({ Premium.canEquip("aura", "pet_fox", { pet_fox = true }) }).toEqual({ false, "error.badRequest" })
		T.expect((Premium.canEquip("aura", nil, {}))).toBe(true)
	end)

	T.it("receipts are idempotent and pruned", function()
		local purchases = { a = 100, b = 100 + 200 * DAY }
		T.expect(Premium.alreadyGranted(purchases, "a")).toBe(true)
		T.expect(Premium.alreadyGranted(purchases, "c")).toBe(false)
		T.expect(Premium.pruneReceipts(purchases, 100 + 200 * DAY, 90 * DAY)).toBe(1)
		T.expect(purchases.a).toBe(nil)
	end)
end)

T.describe("Premium data", function()
	T.it("matches DESIGN §21-22", function()
		local amounts = {}
		for _, pack in Products.shardPacks do
			table.insert(amounts, pack.shards)
		end
		T.expect(amounts).toEqual({ 100, 550, 1200, 2600, 7000 })
		local counts: { [string]: number } = {}
		for _, def in Cosmetics.list do
			counts[def.kind] = (counts[def.kind] or 0) + 1
		end
		T.expect(counts.outfit >= 8 and counts.aura >= 4 and counts.weapon >= 3 and counts.pet >= 6).toBe(true)
		T.expect((counts.mountskin or 0) >= 8).toBe(true) -- S97
		-- S123 (DESIGN-17 §4)
		T.expect((counts.frame or 0) >= 5 and (counts.chatframe or 0) >= 4 and (counts.title or 0) >= 5).toBe(true)
		T.expect((counts.emote or 0) >= 8 and (counts.levelup or 0) >= 4 and (counts.dye or 0) >= 6).toBe(true)
	end)

	T.it("everything is localized", function()
		local missing = {}
		local function need(key: string)
			if en[key] == nil or pl[key] == nil then
				table.insert(missing, key)
			end
		end
		for _, def in Cosmetics.list do
			need(def.nameKey)
		end
		for _, kind in Cosmetics.kinds do
			need(`wardrobe.kind.{kind}`)
		end
		for _, pass in Products.passes do
			need(`premium.pass.{pass.key}`)
			need(`premium.pass.{pass.key}.desc`)
		end
		-- S123: starter packs, bought titles, groups, the weekly offer
		for _, pack in Products.starterPacks do
			need(`premium.pack.{pack.key}`)
			need(`premium.pack.{pack.key}.desc`)
		end
		for _, def in Cosmetics.list do
			if def.kind == "title" and def.title then
				need(`title.{def.title}`)
			end
		end
		for _, group in Cosmetics.groups do
			need(`wardrobe.group.{group.id}`)
		end
		for _, key in
			{
				"premium.weekly.title",
				"premium.weekly.ends",
				"premium.weekly.discount",
				"premium.error.priceChanged",
				"premium.pack.title",
				"premium.pack.once",
				"premium.pack.granted",
				"premium.pack.duplicate",
				"premium.pack.passOwned",
				"wardrobe.obtain.pack",
				"wardrobe.free",
				"wardrobe.weekly",
				"keys.emoteWheel",
				"emote.help",
			}
		do
			need(key)
		end
		-- S97: the premium mount section (hidden until a product is enabled; its texts exist already)
		for _, key in { "premium.mounts.title", "premium.mounts.desc", "premium.error.notForSale" } do
			need(key)
		end
		-- S120: tabs, sections, entry descriptions, "Soon", limits, confirmation
		for _, tab in Premium.TABS do
			need(`premium.tab.{tab}`)
		end
		for _, cat in Products.shopCats do
			need(`premium.cat.{cat}`)
		end
		for _, entry in Products.shop do
			need(`premium.shop.{entry.key}.desc`)
		end
		for _, key in
			{
				"premium.soon",
				"premium.soon.hint",
				"premium.error.soon",
				"premium.error.weeklyLimit",
				"premium.limitReached",
				"premium.service.limitWeek",
				"premium.topUp",
				"premium.bought",
				"premium.rename.confirm2",
				"premium.confirm.title",
				"premium.confirm.buy",
				"premium.confirm.price",
				"premium.confirm.balance",
				"premium.confirm.after",
				"premium.tooltip.price",
				"premium.tooltip.after",
			}
		do
			need(key)
		end
		T.expect(missing).toEqual({})
	end)
end)

T.describe("S97 mount skins and premium mounts", function()
	T.it("sells shop skins, never the earned ones", function()
		T.expect({ Premium.canBuyCosmetic("mountskin_shade", {}, 99999) }).toEqual({
			false,
			"premium.error.notForSale",
		})
		T.expect((Premium.canBuyCosmetic("mountskin_dapple", {}, 350))).toBe(true)
		T.expect({ Premium.canBuyCosmetic("mountskin_dapple", {}, 349) }).toEqual({ false, "premium.error.shards" })
		for _, def in Cosmetics.list do
			if def.obtain then
				-- S121: the VIP cosmetics of the month are earned too (any look kind); S123: starter pack cosmetics;
				-- S128: the arena cosmetics (Arena Tokens shop, season rewards)
				T.expect(
					def.kind == "mountskin"
						or def.obtain.vipMonth ~= nil
						or def.obtain.pack ~= nil
						or def.obtain.arena ~= nil
				).toBe(true)
				T.expect(def.price).toBe(0)
				local n = 0
				for _ in def.obtain do
					n += 1
				end
				T.expect(n).toBe(1)
			end
		end
	end)

	T.it("equips a mount skin like any cosmetic", function()
		T.expect((Premium.canEquip("mountskin", "mountskin_dapple", { mountskin_dapple = true }))).toBe(true)
		T.expect({ Premium.canEquip("mountskin", "outfit_ranger", { outfit_ranger = true }) }).toEqual({
			false,
			"error.badRequest",
		})
		T.expect((Premium.canEquip("mountskin", nil, {}))).toBe(true)
	end)

	T.it("offers premium mounts only while enabled", function()
		T.expect(Premium.mountOffers()).toEqual({})
		local on: { Products.MountProduct } =
			{ { key = "x", productId = 0, robux = 1, mount = "mount_royal", enabled = true } }
		T.expect(#Premium.mountOffers(on)).toBe(1)
		local char = { mounts = { owned = {} } }
		T.expect({ Premium.canBuyMount("mount_royal", char) }).toEqual({ false, "premium.error.notOnSale" })
		T.expect({ Premium.canBuyMount("nope", char) }).toEqual({ false, "error.badRequest" })
		T.expect((Premium.canBuyMount("x", char, on))).toBe(true)
		T.expect({ Premium.canBuyMount("x", nil, on) }).toEqual({ false, "error.wrongPhase" })
		local owner = { mounts = { owned = { mount_royal = { lvl = 4 } } } }
		T.expect({ Premium.canBuyMount("x", owner, on) }).toEqual({ false, "premium.error.owned" })
	end)
end)

T.describe("S122 Elixir of Wholeness and Cloak of Luring", function()
	local now = MONDAY + 3600
	local function account(shards: number): Premium.ShopAccount
		return { dragonShards = shards, shopLimits = Premium.emptyLimits() }
	end

	T.it("packs and cloak time go through the one purchase rule, without a daily limit", function()
		local pack = Products.getShop("potion_full_5")
		local week = Products.getShop("lure_7d")
		assert(pack and week, "S122 entries")
		T.expect({ Premium.canBuy(pack, account(pack.price - 1), now) }).toEqual({ false, "premium.error.shards" })
		T.expect({ Premium.canBuy(pack, account(pack.price), now) }).toEqual({ true, nil })
		T.expect({ Premium.canBuy(week, account(989), now) }).toEqual({ false, "premium.error.shards" })
		T.expect({ Premium.canBuy(week, account(990), now) }).toEqual({ true, nil })
		for _, entry in { pack, week } do
			local acc = account(1e9)
			for _ = 1, 10 do
				T.expect((Premium.canBuy(entry, acc, now))).toBe(true)
				acc.shopLimits = Premium.countPurchase(entry, acc, now)
			end
		end
	end)

	T.it("the cards and the cloak are localized", function()
		for _, key in
			{
				"premium.potion_full.pack",
				"premium.lure_1h",
				"premium.lure_7d",
				"premium.lure_1h.desc",
				"premium.lure_7d.desc",
				"premium.lure.left",
				"premium.lure.none",
				"premium.lure.toggleOn",
				"premium.lure.toggleOff",
				"lure.name",
				"lure.desc",
				"menu.lure",
				"hud.lure",
			}
		do
			T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
		end
	end)
end)

T.describe("S121 VIP and passes", function()
	T.it("subscriptions, new passes and the VIP texts are localized", function()
		local missing = {}
		local function need(key: string)
			if en[key] == nil or pl[key] == nil then
				table.insert(missing, key)
			end
		end
		for _, sub in Products.subscriptions do
			need(`premium.sub.{sub.key}`)
			need(`premium.sub.{sub.key}.desc`)
		end
		for _, key in { "wardrobe.obtain.vip", "premium.error.requires", "premium.requires", "title.vip" } do
			need(key)
		end
		T.expect(missing).toEqual({})
	end)

	T.it("the cosmetics of the month are earned, never sold, and equip like any", function()
		T.expect({ Premium.canBuyCosmetic("aura_vip_hearth", {}, 1e9) }).toEqual({
			false,
			"premium.error.notForSale",
		})
		T.expect((Premium.canEquip("aura", "aura_vip_hearth", { aura_vip_hearth = true }))).toBe(true)
	end)

	T.it("the subscription button says Soon without an id on a live server", function()
		local sub = { key = "vip", subscriptionId = "", enabled = true }
		T.expect(Premium.subscriptionState(sub, false)).toBe("soon")
		T.expect(Premium.subscriptionState(sub, true)).toBe("buy")
		T.expect(Premium.subscriptionState({ key = "vip", subscriptionId = "EXP-1", enabled = true }, false))
			.toBe("buy")
	end)

	T.it("the account template has vip and outfits (no migration)", function()
		local acc = AccountSchema.accountTemplate()
		T.expect(acc.vip).toEqual({ shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = {} })
		T.expect(acc.outfits).toEqual({})
	end)
end)

T.describe("S128 arena cosmetics", function()
	T.it("adds no cosmetic kind and sells no arena cosmetic for shards", function()
		T.expect(#Cosmetics.kinds).toBe(12)
		T.expect({ Premium.canBuyCosmetic("aura_gladiator", {}, 99999) }).toEqual({ false, "premium.error.notForSale" })
		for _, def in Cosmetics.list do
			if def.obtain and def.obtain.arena then
				T.expect({ def.id, pl[def.nameKey] ~= nil, en[def.nameKey] ~= nil }).toEqual({ def.id, true, true })
				T.expect({ def.id, def.wiki }).toEqual({ def.id, false })
			end
		end
	end)
end)

return nil
