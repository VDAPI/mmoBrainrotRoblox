--!strict
-- S121 (DESIGN-17 §2): VIP rules (Logic/Vip), months (Logic/Time), passes, character slots and saved looks
-- (Logic/Premium), the one capacity formula and the overflow (Logic/Inventory).
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Inventory = require("../src/shared/Logic/Inventory")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local Time = require("../src/shared/Logic/Time")
local Vip = require("../src/shared/Logic/Vip")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local T = require("./Test")

local DAY = 86400
local NOW = 1793491200 + 3600 -- 2026-11-01 01:00 UTC

local function item(uid: string): any
	return { uid = uid, id = "sword1h_1", rarity = 1, ilvl = 1, bonuses = {}, up = 0, bound = false, n = 1 }
end

local function count(inv: { [string]: any }): number
	local n = 0
	for _ in inv do
		n += 1
	end
	return n
end

T.describe("Time months (S121)", function()
	T.it("monthKey from the UTC day", function()
		T.expect(Time.monthKey(0)).toBe("197001")
		T.expect(Time.monthKey(1793491199)).toBe("202610") -- 2026-10-31 23:59:59
		T.expect(Time.monthKey(1793491200)).toBe("202611") -- 2026-11-01 00:00:00
		T.expect(Time.monthKey(1798761600)).toBe("202701") -- 2027-01-01
		T.expect(Time.monthKey(1835438400)).toBe("202802") -- 2028-02-29 12:00
		T.expect(Time.monthKey(1809129599)).toBe("202704") -- 2027-04-30 23:59:59
		T.expect({ Time.civil(1835438400) }).toEqual({ 2028, 2, 29 })
	end)

	T.it("monthLabel", function()
		T.expect({ Time.monthLabel("202611") }).toEqual({ 2026, 11 })
		T.expect((Time.monthLabel("2026-11"))).toBeNil()
		T.expect((Time.monthLabel("202613"))).toBeNil()
		T.expect((Time.monthLabel("202600"))).toBeNil()
	end)
end)

T.describe("VIP state (S121)", function()
	T.it("sanitize fills defaults and keeps only good months", function()
		local empty = { shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = {} }
		T.expect(Vip.sanitize(nil)).toEqual(empty)
		T.expect(Vip.sanitize("oops")).toEqual(empty)
		local s = Vip.sanitize({ shardDay = "x", months = { ["202611"] = true, bad = true, ["202612"] = 5 } })
		T.expect(s)
			.toEqual({ shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = { ["202611"] = true } })
	end)

	T.it("daily shards once per UTC day", function()
		local fresh = Vip.sanitize(nil)
		T.expect(Vip.dailyDue(fresh, NOW)).toBe(true)
		local claimed = Vip.claimDaily(fresh, NOW)
		T.expect(fresh.shardDay).toBe(0)
		T.expect(Vip.dailyDue(claimed, NOW)).toBe(false)
		local midnight = Time.nextDayAt(NOW)
		T.expect(Vip.dailyDue(claimed, midnight - 1)).toBe(false)
		T.expect(Vip.dailyDue(claimed, midnight)).toBe(true)
		T.expect(Vip.dailyDue(claimed, NOW + DAY)).toBe(true)
	end)

	T.it("one cosmetic for each month 202611-202704", function()
		for _, key in { "202611", "202612", "202701", "202702", "202703", "202704" } do
			local found = {}
			for _, def in Cosmetics.list do
				if def.obtain and def.obtain.vipMonth == key then
					table.insert(found, def.id)
				end
			end
			T.expect({ key, #found }).toEqual({ key, 1 })
			T.expect(Vip.monthCosmetic(key)).toBe(found[1])
		end
		T.expect(Vip.monthCosmetic("202610")).toBeNil()
		T.expect(Vip.monthCosmetic("202705")).toBeNil()
		T.expect(Vip.monthDue(nil, "202611", {})).toBe("aura_vip_hearth")
		T.expect(Vip.monthDue({ months = { ["202611"] = true } }, "202611", {})).toBeNil()
		T.expect(Vip.monthDue(nil, "202611", { aura_vip_hearth = true })).toBeNil()
		T.expect(Vip.monthDue(nil, "202610", {})).toBeNil()
		T.expect(Vip.markMonth(nil, "202611").months).toEqual({ ["202611"] = true })
		local list: { Cosmetics.Def } = {
			{
				id = "a",
				kind = "aura",
				nameKey = "x",
				price = 0,
				icon = "a",
				color = "#000000",
				obtain = { vipMonth = "203001" },
			},
			{
				id = "b",
				kind = "aura",
				nameKey = "x",
				price = 0,
				icon = "b",
				color = "#000000",
				obtain = { vipMonth = "203001" },
			},
		}
		T.expect(Vip.monthCosmetic("203001", list)).toBe("a")
		T.expect(Vip.monthDue(nil, "203001", {}, list)).toBe("a")
	end)

	T.it("free respawn per day and free recall cooldown", function()
		local fresh = Vip.sanitize(nil)
		T.expect(Vip.respawnLeft(fresh, NOW)).toBe(Config.Vip.freeRespawnsPerDay)
		local used = Vip.useRespawn(fresh, NOW)
		T.expect(Vip.respawnLeft(used, NOW + 60)).toBe(0)
		T.expect(Vip.respawnLeft(used, NOW + DAY)).toBe(Config.Vip.freeRespawnsPerDay)
		T.expect(Vip.recallLeft(fresh, NOW)).toBe(0)
		local recalled = Vip.useRecall(fresh, NOW)
		T.expect(Vip.recallLeft(recalled, NOW)).toBe(Config.Vip.freeRecallCooldown)
		T.expect(Vip.recallLeft(recalled, NOW + Config.Vip.freeRecallCooldown)).toBe(0)
		local reset =
			Vip.reset({ shardDay = 5, respawnDay = 5, respawnN = 1, recallAt = 9, months = { ["202611"] = true } })
		T.expect(reset)
			.toEqual({ shardDay = 0, respawnDay = 0, respawnN = 0, recallAt = 0, months = { ["202611"] = true } })
	end)
end)

T.describe("Passes, slots and looks (S121)", function()
	T.it("canBuyPass and canBuySubscription", function()
		T.expect({ Premium.canBuyPass("vip", {}) }).toEqual({ false, "premium.error.soon" })
		T.expect((Premium.canBuyPass("pockets", {}))).toBe(true)
		T.expect({ Premium.canBuyPass("pockets", { pockets = true }) }).toEqual({ false, "premium.error.owned" })
		T.expect({ Premium.canBuyPass("slot5", {}) }).toEqual({ false, "premium.error.requires" })
		T.expect((Premium.canBuyPass("slot5", { slot4 = true }))).toBe(true)
		T.expect({ Premium.canBuyPass("nope", {}) }).toEqual({ false, "error.badRequest" })
		T.expect((Premium.canBuySubscription("vip", false))).toBe(true)
		T.expect({ Premium.canBuySubscription("vip", true) }).toEqual({ false, "premium.error.owned" })
		T.expect({ Premium.canBuySubscription("x", false) }).toEqual({ false, "error.badRequest" })
	end)

	T.it("character slots", function()
		T.expect(Config.MaxCharacters).toBe(5)
		T.expect(Config.FreeCharacters).toBe(3)
		for slot = 1, 3 do
			T.expect(Premium.slotOpen(slot, {})).toBe(true)
		end
		T.expect(Premium.slotOpen(4, {})).toBe(false)
		T.expect(Premium.slotOpen(4, { slot4 = true })).toBe(true)
		T.expect(Premium.slotOpen(5, { slot5 = true })).toBe(false)
		T.expect(Premium.slotOpen(5, { slot4 = true })).toBe(false)
		T.expect(Premium.slotOpen(5, { slot4 = true, slot5 = true })).toBe(true)
		T.expect(Premium.slotOpen(0, { slot4 = true, slot5 = true })).toBe(false)
		T.expect(Premium.slotOpen(6, { slot4 = true, slot5 = true })).toBe(false)
		for slot = Config.FreeCharacters + 1, Config.MaxCharacters do
			T.expect({ slot, Products.SLOT_PASSES[slot] ~= nil }).toEqual({ slot, true })
			for _, key in Products.SLOT_PASSES[slot] do
				T.expect({ key, Products.getPass(key) ~= nil }).toEqual({ key, true })
			end
		end
		T.expect(Premium.slotPass(5, {})).toBe("slot4")
		T.expect(Premium.slotPass(5, { slot4 = true })).toBe("slot5")
		T.expect(Premium.slotPass(4, { slot4 = true })).toBeNil()
	end)

	T.it("capacity: one formula", function()
		T.expect(Inventory.capacityOf(nil, false)).toBe(Config.DefaultCapacity)
		T.expect(Inventory.capacityOf(nil, true)).toBe(Config.DefaultCapacity + Products.POCKETS_SLOTS)
		T.expect(Inventory.capacityOf(nil, true)).toBe(30)
		T.expect(Inventory.capacityOf("backpack_60", true)).toBe(70)
		T.expect(Inventory.capacityOf("backpack_premium_200", true)).toBe(210)
		T.expect(Inventory.capacityOf("nope", false)).toBe(Config.DefaultCapacity)
		T.expect(Inventory.capacityOf("nope", true)).toBe(Config.DefaultCapacity + 10)
	end)

	T.it("overflow: take out, never put in", function()
		local inv: any = {}
		for i = 1, 25 do
			inv[tostring(i)] = item(`u{i}`)
		end
		T.expect(Inventory.lastIndex(inv)).toBe(25)
		T.expect(Inventory.lastIndex({})).toBe(0)
		T.expect(Inventory.firstFree(inv, 20)).toBeNil()
		local changed, leftover = Inventory.add(inv, 20, item("new"), function()
			return "x"
		end)
		T.expect({ #changed, leftover }).toEqual({ 0, 1 })
		T.expect(inv["21"].uid).toBe("u21")
		inv["5"] = nil
		T.expect(Inventory.move(inv, 20, 23, 5)).toEqual({ 23, 5 })
		T.expect(inv["5"].uid).toBe("u23")
		T.expect(inv["23"]).toBeNil()
		T.expect(Inventory.move(inv, 20, 5, 23)).toBeNil()
		T.expect(Inventory.move(inv, 20, 24, 6)).toBeNil() -- no swap into the overflow
		T.expect(Inventory.move(inv, 20, 30, 6)).toBeNil()
		local copy = table.clone(inv)
		T.expect(Inventory.compact(inv, 20)).toBe(false)
		T.expect(inv).toEqual(copy)
		Inventory.sort(inv, 20, function()
			return "s"
		end)
		T.expect(count(inv)).toBe(24)
	end)

	T.it("saved looks", function()
		T.expect(Premium.outfitSlots({})).toBe(Products.OUTFITS_FREE)
		T.expect(Premium.outfitSlots({ wardrobePlus = true })).toBe(Products.OUTFITS_PLUS)
		local cosmetics = { equipped = { aura = "aura_gold", trail = "trail_spark" } }
		local pets = { equipped = "pet_fox" }
		local look = Premium.snapshotOutfit(cosmetics, pets)
		T.expect(look).toEqual({ equipped = { aura = "aura_gold", trail = "trail_spark" }, pet = "pet_fox" })
		look.equipped.aura = "aura_frost"
		T.expect(cosmetics.equipped.aura).toBe("aura_gold")
		local saved = {
			equipped = {
				aura = "aura_gold", -- owned
				trail = "trail_mist", -- not owned
				weapon = "nope", -- unknown
				outfit = "aura_frost", -- wrong kind
				pet = "pet_fox", -- pets are not in equipped
			},
			pet = "pet_fox",
		}
		local owned = { aura_gold = true, aura_frost = true, pet_fox = true }
		local looks, pet = Premium.outfitLooks(saved, owned, { pet_fox = true })
		T.expect(looks).toEqual({ aura = "aura_gold" })
		T.expect(pet).toBe("pet_fox")
		local _, noPet = Premium.outfitLooks(saved, owned, {})
		T.expect(noPet).toBeNil()
		T.expect({ Premium.outfitLooks("bad", {}, {}) }).toEqual({ {} })
	end)

	T.it("every benefit row is localized with its placeholders", function()
		local function placeholders(text: string): { [string]: boolean }
			local out = {}
			for name in string.gmatch(text, "{([%w_]+)}") do
				out[name] = true
			end
			return out
		end
		for _, row in Vip.BENEFITS do
			local key = `vip.benefit.{row.key}`
			local text = (pl :: any)[key]
			T.expect({ key, text ~= nil and (en :: any)[key] ~= nil }).toEqual({ key, true })
			local given = {}
			for name in row.args or {} do
				given[name] = true
			end
			T.expect({ key, given }).toEqual({ key, placeholders(text) })
		end
	end)
end)

return nil
