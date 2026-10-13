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

	T.it("scroll_skillreset is sold again (S81)", function()
		local limits = { day = 0, protectScrolls = 0 }
		T.expect((Premium.canBuyShop("scroll_skillreset", 1000, limits, 0))).toBe(true)
		T.expect((Products.getShop("scroll_skillreset") :: any).unavailable).toBeNil()
		for _, key in { "premium.soon", "premium.error.soon" } do
			T.expect({ key, pl[key], en[key] }).toEqual({ key, nil, nil })
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
		-- S97: the premium mount section (hidden until a product is enabled; its texts exist already)
		for _, key in { "premium.mounts.title", "premium.mounts.desc", "premium.error.notForSale" } do
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
				T.expect(def.kind).toBe("mountskin")
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

return nil
