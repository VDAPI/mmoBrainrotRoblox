--!strict
local Auction = require("../src/shared/Logic/Auction")
local ItemName = require("../src/shared/Logic/ItemName")
local Items = require("../src/shared/Data/Items")
local Mail = require("../src/shared/Logic/Mail")
local Market = require("../src/shared/Data/Market")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local function item(id: string, n: number?): any
	return { uid = "u1", id = id, rarity = 3, ilvl = 10, bonuses = {}, up = 0, bound = false, n = n or 1 }
end

local function listing(): Auction.Listing
	return {
		id = "L1",
		sellerUserId = 1,
		sellerCharId = "c1",
		sellerName = "Seller",
		item = item("sword1h_1"),
		price = 1000,
		deposit = 10,
		category = "weapon",
		createdAt = 0,
		expiresAt = 100,
		status = "active",
	}
end

T.describe("Auction rules", function()
	T.it("deposit, fee and payout", function()
		T.expect(Auction.deposit(1000)).toBe(10)
		T.expect(Auction.deposit(5)).toBe(1)
		T.expect(Auction.fee(1000)).toBe(50)
		T.expect(Auction.payout(1000, 10)).toBe(960)
	end)

	T.it("validates listings", function()
		local def = Items.get("sword1h_1") :: any
		T.expect((Auction.validateListing(item("sword1h_1"), def, 100, 24, 0, 1000))).toBe(true)
		local bound = item("sword1h_1")
		bound.bound = true
		T.expect({ Auction.validateListing(bound, def, 100, 24, 0, 1000) }).toEqual({ false, "auction.error.bound" })
		T.expect({ Auction.validateListing(item("sword1h_1"), def, 0, 24, 0, 1000) })
			.toEqual({ false, "auction.error.price" })
		T.expect({ Auction.validateListing(item("sword1h_1"), def, 100, 12, 0, 1000) })
			.toEqual({ false, "error.badRequest" })
		T.expect({ Auction.validateListing(item("sword1h_1"), def, 100, 48, 20, 1000) })
			.toEqual({ false, "auction.error.limit" })
		T.expect({ Auction.validateListing(item("sword1h_1"), def, 100000, 48, 0, 5) })
			.toEqual({ false, "auction.error.deposit" })
	end)

	T.it("S121: VIP fee fixed on the listing and more listings", function()
		T.expect(Auction.fee(1000)).toBe(50)
		T.expect(Auction.payout(1000, 10)).toBe(960)
		T.expect(Auction.feePctFor(false)).toBe(Market.Auction.feePct)
		T.expect(Auction.feePctFor(true)).toBe(2.5)
		T.expect(Auction.fee(1000, 2.5)).toBe(25)
		T.expect(Auction.payout(1000, 10, 2.5)).toBe(985)
		T.expect(Auction.fee(999, 2.5)).toBe(24)
		T.expect(Auction.maxListingsFor(false)).toBe(20)
		T.expect(Auction.maxListingsFor(true)).toBe(25)
		local def = Items.get("sword1h_1") :: any
		T.expect((Auction.validateListing(item("sword1h_1"), def, 100, 24, 20, 1000, 25))).toBe(true)
		T.expect({ Auction.validateListing(item("sword1h_1"), def, 100, 24, 25, 1000, 25) })
			.toEqual({ false, "auction.error.limit" })
	end)

	T.it("every item falls into a known category", function()
		for id, def in Items.byId do
			local category = Auction.categoryOf(def :: any)
			if not Market.getCategory(category) then
				error(`{id} -> {category}`)
			end
		end
		T.expect(Auction.categoryOf(Items.get("sword1h_1") :: any)).toBe("weapon")
		T.expect(Auction.categoryOf(Items.get("potion_hp_1") :: any)).toBe("consumable")
		T.expect(Auction.categoryOf(Items.get("ore_copper") :: any)).toBe("material")
	end)

	T.it("index keys sort by price", function()
		T.expect(Auction.indexKey(99, "b") < Auction.indexKey(100, "a")).toBe(true)
		T.expect(Auction.indexKey(100, "a") < Auction.indexKey(100, "b")).toBe(true)
	end)

	T.it("filters summaries", function()
		local l = listing()
		local s = Auction.summary(l, Items.get("sword1h_1") :: any, ItemName.searchText("sword1h_1"))
		T.expect(Auction.matches(s, {}, 50)).toBe(true)
		T.expect(Auction.matches(s, {}, 100)).toBe(false) -- expired
		T.expect(Auction.matches(s, { rarity = 4 }, 50)).toBe(false)
		T.expect(Auction.matches(s, { minLevel = s.l + 1 }, 50)).toBe(false)
		local name = ItemName.fold(ItemName.get("pl", "sword1h_1", nil))
		T.expect(Auction.matches(s, { text = string.sub(name, 1, 3) }, 50)).toBe(true)
		T.expect(Auction.matches(s, { text = "zzzz" }, 50)).toBe(false)
	end)

	T.it("a listing can be bought once", function()
		local l = listing()
		T.expect({ Auction.buy(l, 1, "Self", 50) }).toEqual({ false, "auction.error.own" })
		T.expect((Auction.buy(l, 2, "Buyer", 50))).toBe(true)
		T.expect(l.status).toBe("sold")
		T.expect({ Auction.buy(l, 3, "Late", 50) }).toEqual({ false, "auction.error.sold" })
		T.expect({ Auction.cancel(l, 1, "c1", 50) }).toEqual({ false, "auction.error.sold" })
		T.expect({ Auction.expire(l, 200) }).toEqual({ false, "auction.error.gone" })
	end)

	T.it("expired listings cannot be bought and expire once", function()
		local l = listing()
		T.expect({ Auction.buy(l, 2, "Buyer", 100) }).toEqual({ false, "auction.error.expired" })
		T.expect({ Auction.expire(l, 50) }).toEqual({ false, "auction.error.notExpired" })
		T.expect((Auction.expire(l, 100))).toBe(true)
		T.expect((Auction.expire(l, 100))).toBe(false)
	end)

	T.it("only the seller's character cancels", function()
		local l = listing()
		T.expect({ Auction.cancel(l, 1, "other", 10) }).toEqual({ false, "auction.error.notYours" })
		T.expect((Auction.cancel(l, 1, "c1", 10))).toBe(true)
	end)

	T.it("price history keeps the last entries", function()
		local history = nil
		for i = 1, 25 do
			history = Auction.pushHistory(history, i)
		end
		T.expect(#(history :: any)).toBe(Market.Auction.historySize)
		T.expect(Auction.average(history)).toBe(16) -- 6..25
		T.expect(Auction.average(nil)).toBe(nil)
	end)

	T.it("category names are localized", function()
		for _, category in Market.categories do
			T.expect(en[category.nameKey] ~= nil and pl[category.nameKey] ~= nil).toBe(true)
		end
	end)
end)

T.describe("Mail rules", function()
	local function parcel(id: string, charId: string?, expiresAt: number?): Mail.Parcel
		return {
			id = id,
			from = "system",
			subjectKey = "mail.subject.admin",
			gold = 5,
			items = {},
			createdAt = 0,
			expiresAt = expiresAt or 1000,
			charId = charId,
		}
	end

	T.it("adds, limits and prunes", function()
		local box = Mail.newBox()
		for i = 1, Market.Mail.maxParcels do
			assert(Mail.add(box, parcel(`p{i}`, nil), 0))
		end
		T.expect({ Mail.add(box, parcel("x", nil), 0) }).toEqual({ false, "mail.error.full" })
		T.expect(#Mail.prune(box, 1000)).toBe(Market.Mail.maxParcels)
		T.expect(Mail.count(box)).toBe(0)
	end)

	T.it("character parcels are private, account parcels shared", function()
		local box = Mail.newBox()
		assert(Mail.add(box, parcel("a", "c1"), 0))
		assert(Mail.add(box, parcel("b", nil), 0))
		T.expect(#Mail.visible(box, "c1", 0)).toBe(2)
		T.expect(#Mail.visible(box, "c2", 0)).toBe(1)
		T.expect(Mail.take(box, "a", "c2", 0)).toBe(nil)
		T.expect((Mail.take(box, "a", "c1", 0) :: any).id).toBe("a")
		T.expect(Mail.take(box, "a", "c1", 0)).toBe(nil) -- once only
	end)

	T.it("rejects oversized parcels", function()
		local box = Mail.newBox()
		local big = parcel("big", nil)
		for i = 1, Market.Mail.maxItemsPerParcel + 1 do
			table.insert(big.items, item("ore_copper", i))
		end
		T.expect({ Mail.add(box, big, 0) }).toEqual({ false, "mail.error.tooManyItems" })
	end)
end)

T.describe("Mail with shards and a timed title (S125)", function()
	local function parcel(from: string, extra: { [string]: any }?): Mail.Parcel
		local p: any = {
			id = "p",
			from = from,
			subjectKey = "mail.subject.weeklyRank",
			gold = 0,
			items = {},
			createdAt = 0,
			expiresAt = 1000,
			charId = "c1",
		}
		for k, v in extra or {} do
			p[k] = v
		end
		return p
	end
	local TITLE = { id = "weekly_diligent", untilTs = 500 }

	T.it("takes shards and a timed title from the system and admins", function()
		local box = Mail.newBox()
		T.expect({ Mail.add(box, parcel("system", { shards = 100, timedTitle = TITLE }), 0) }).toEqual({ true, nil })
		local admin = parcel("admin", { shards = 25 })
		admin.id = "q"
		T.expect({ Mail.add(box, admin, 0) }).toEqual({ true, nil })
		T.expect(#Mail.visible(box, "c1", 0)).toBe(2)
		T.expect(Mail.isEmpty(parcel("system", { shards = 100 }))).toBe(false)
		T.expect(Mail.isEmpty(parcel("system", { timedTitle = TITLE }))).toBe(false)
		T.expect(Mail.isEmpty(parcel("system"))).toBe(true)
	end)

	T.it("refuses shards and titles from players and malformed values", function()
		local bad = {
			parcel("player", { shards = 10 }),
			parcel("auction", { shards = 10 }),
			parcel("system", { shards = 1.5 }),
			parcel("system", { shards = -1 }),
			parcel("player", { timedTitle = TITLE }),
			parcel("system", { timedTitle = { id = "nothing", untilTs = 5 } }),
			parcel("system", { timedTitle = { id = "wanderer", untilTs = 5 } }),
			parcel("system", { timedTitle = { id = "weekly_diligent" } }),
		}
		local noChar = parcel("system", { timedTitle = TITLE })
		noChar.charId = nil
		table.insert(bad, noChar)
		for i, p in bad do
			T.expect({ i, Mail.add(Mail.newBox(), p, 0) }).toEqual({ i, false, "error.badRequest" })
		end
	end)

	T.it("old parcels without the new fields still work", function()
		local stored = {
			parcels = {
				old = {
					id = "old",
					from = "auction",
					subjectKey = "mail.subject.sold",
					gold = 40,
					items = {},
					createdAt = 0,
					expiresAt = 1000,
				},
			},
		}
		local box = Mail.box(stored)
		T.expect(#Mail.visible(box, "c1", 0)).toBe(1)
		T.expect(Mail.isEmpty(box.parcels.old)).toBe(false)
		T.expect((Mail.take(box, "old", "c1", 0) :: any).gold).toBe(40)
	end)
end)

return nil
