--!strict
-- Auto Potions (S134d): the account state (Logic/AutoPotion), thresholds, what to drink and the purchase rule.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local AutoPotion = require("../src/shared/Logic/AutoPotion")
local Config = require("../src/shared/Config")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local T = require("./Test")
local UseBlocks = require("../src/shared/Logic/UseBlocks")

local NOW = 1_800_000_000

local function state(fields: { [string]: any }): AutoPotion.State
	local s = AutoPotion.default() :: any
	for k, v in fields do
		s[k] = v
	end
	return s
end

T.describe("S134d AutoPotion state", function()
	T.it("owned and active: timed, forever, switched off, nothing", function()
		T.expect(AutoPotion.owned(nil, NOW)).toBe(false)
		T.expect(AutoPotion.active(nil, NOW)).toBe(false)
		local timed = state({ untilTs = NOW + 60, on = true })
		T.expect(AutoPotion.owned(timed, NOW)).toBe(true)
		T.expect(AutoPotion.active(timed, NOW)).toBe(true)
		T.expect(AutoPotion.left(timed, NOW)).toBe(60)
		T.expect(AutoPotion.active(timed, NOW + 61)).toBe(false)
		local forever = state({ permanent = true, on = true })
		T.expect(AutoPotion.owned(forever, NOW + 10 ^ 9)).toBe(true)
		T.expect(AutoPotion.active(forever, NOW)).toBe(true)
		local off = state({ permanent = true, on = false })
		T.expect(AutoPotion.owned(off, NOW)).toBe(true)
		T.expect(AutoPotion.active(off, NOW)).toBe(false)
	end)

	T.it("extend adds from now or from the end, switches on and keeps the thresholds", function()
		local fresh = AutoPotion.extend(state({ hp = 40, res = 0 }), 3600, NOW)
		T.expect(fresh.untilTs).toBe(NOW + 3600)
		T.expect(fresh.on).toBe(true)
		T.expect({ fresh.hp, fresh.res }).toEqual({ 40, 0 })
		local more = AutoPotion.extend(fresh, 3600, NOW + 100)
		T.expect(more.untilTs).toBe(NOW + 7200)
		local late = AutoPotion.extend(state({ untilTs = NOW - 50 }), 60, NOW)
		T.expect(late.untilTs).toBe(NOW + 60)
		local forever = AutoPotion.extend(fresh, 0, NOW, true)
		T.expect(forever.permanent).toBe(true)
		T.expect(forever.untilTs).toBe(NOW + 3600)
	end)

	T.it("canBuy refuses everything once owned forever", function()
		local perm = Products.getShop("autopotion_perm") :: Products.ShopEntry
		local day = Products.getShop("autopotion_1d") :: Products.ShopEntry
		T.expect({ AutoPotion.canBuy(day, nil, NOW) }).toEqual({ true })
		T.expect({ AutoPotion.canBuy(perm, state({ untilTs = NOW + 99 }), NOW) }).toEqual({ true })
		local owned = state({ permanent = true })
		T.expect({ AutoPotion.canBuy(day, owned, NOW) }).toEqual({ false, "premium.error.owned" })
		T.expect({ AutoPotion.canBuy(perm, owned, NOW) }).toEqual({ false, "premium.error.owned" })
		-- the shop's one rule asks it (the owned check before the price)
		T.expect({ Premium.canBuy(day, { dragonShards = 0, autoPotion = owned }, NOW) }).toEqual({
			false,
			"premium.error.owned",
		})
		T.expect({ Premium.canBuy(day, { dragonShards = 0 }, NOW) }).toEqual({ false, "premium.error.shards" })
		T.expect({ Premium.canBuy(day, { dragonShards = day.price }, NOW) }).toEqual({ true })
	end)

	T.it("clampThreshold: 0 is off, minPct..maxPct in steps", function()
		T.expect(Config.AutoPotion.minPct).toBe(10)
		T.expect(Config.AutoPotion.maxPct).toBe(90)
		T.expect(AutoPotion.clampThreshold(5)).toBe(10)
		T.expect(AutoPotion.clampThreshold(95)).toBe(90)
		T.expect(AutoPotion.clampThreshold(0)).toBe(0)
		T.expect(AutoPotion.clampThreshold(-20)).toBe(0)
		T.expect(AutoPotion.clampThreshold(0 / 0)).toBe(0)
		T.expect(AutoPotion.clampThreshold("50")).toBe(0)
		T.expect(AutoPotion.clampThreshold(47)).toBe(45)
		T.expect(AutoPotion.clampThreshold(48)).toBe(50)
		T.expect(AutoPotion.clampThreshold(math.huge)).toBe(90)
	end)

	T.it("wants: HP before the resource, a threshold of 0 never drinks", function()
		local s = state({ hp = 50, res = 30 })
		T.expect(AutoPotion.wants(s, 40, 20)).toEqual({ "hp", "res" })
		T.expect(AutoPotion.wants(s, 50, 31)).toEqual({ "hp" })
		T.expect(AutoPotion.wants(s, 51, 30)).toEqual({ "res" })
		T.expect(AutoPotion.wants(s, 100, 100)).toEqual({})
		local noHp = state({ hp = 0, res = 30 })
		T.expect(AutoPotion.wants(noHp, 1, 50)).toEqual({})
		T.expect(AutoPotion.wants(noHp, 1, 10)).toEqual({ "res" })
	end)

	T.it("the account template has the state, off and with the default thresholds", function()
		local template = AccountSchema.accountTemplate() :: any
		T.expect(template.autoPotion).toEqual({
			untilTs = 0,
			permanent = false,
			on = false,
			hp = Config.AutoPotion.hp,
			res = Config.AutoPotion.res,
		})
		T.expect(template.autoGrind).toEqual({ bank = 0, day = 0, used = 0 })
	end)

	T.it("the block list holds every place of fights with players", function()
		for _, reason in { "dead", "duel", "arena", "pvpLock", "tourney", "bloodMoon" } do
			T.expect({ reason, table.find(UseBlocks.LISTS.autoPotion, reason) ~= nil }).toEqual({ reason, true })
		end
		-- the boss dungeon is allowed (the same potions and cooldown as the key; DECYZJE S134d)
		T.expect(table.find(UseBlocks.LISTS.autoPotion, "dungeon")).toBeNil()
		T.expect(UseBlocks.key("autoPotion", "duel")).toBe("autoPotion.block.duel")
	end)
end)

return nil
