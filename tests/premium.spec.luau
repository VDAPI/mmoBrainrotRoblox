--!strict
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local DAY = 86400

T.describe("Premium shop", function()
	T.it("scroll of protection is limited to 5 a day", function()
		local limits = { day = 0, protectScrolls = 0 }
		local now = 10 * DAY + 5
		for _ = 1, 5 do
			T.expect((Premium.canBuyShop("scroll_protection", 1000, limits, now))).toBe(true)
			limits = Premium.countDaily(limits, now)
		end
		T.expect({ Premium.canBuyShop("scroll_protection", 1000, limits, now) }).toEqual({
			false,
			"premium.error.dailyLimit",
		})
		-- New UTC day resets the counter.
		T.expect((Premium.canBuyShop("scroll_protection", 1000, limits, now + DAY))).toBe(true)
		T.expect(Premium.countDaily(limits, now + DAY).protectScrolls).toBe(1)
	end)

	T.it("needs enough shards and a known entry", function()
		local limits = { day = 0, protectScrolls = 0 }
		T.expect({ Premium.canBuyShop("scroll_oblivion", 1, limits, 0) }).toEqual({ false, "premium.error.shards" })
		T.expect({ Premium.canBuyShop("nope", 1e9, limits, 0) }).toEqual({ false, "error.badRequest" })
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
		T.expect(missing).toEqual({})
	end)
end)

return nil
