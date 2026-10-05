--!strict
local Crafting = require("../src/shared/Data/Crafting")
local Dismantle = require("../src/shared/Logic/Dismantle")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Npcs = require("../src/shared/Data/Npcs")
local Rng = require("../src/shared/Logic/Rng")
local Shops = require("../src/shared/Data/Shops")
local T = require("./Test")
local Upgrade = require("../src/shared/Logic/Upgrade")
local en = require("../src/shared/Data/Localization/en")

local function item(rarity: number, up: number, ilvl: number?): any
	return {
		uid = "x",
		id = "sword1h_30",
		rarity = rarity,
		ilvl = ilvl or 30,
		bonuses = {},
		up = up,
		bound = false,
		n = 1,
	}
end

T.describe("Upgrade", function()
	T.it("chances follow 110 − 10·N", function()
		T.expect(Upgrade.chance(1)).toBe(100)
		T.expect(Upgrade.chance(2)).toBe(90)
		T.expect(Upgrade.chance(5)).toBe(60)
		T.expect(Upgrade.chance(9)).toBe(20)
	end)

	T.it("costs follow DESIGN §6", function()
		local c1 = Upgrade.cost(item(4, 0), 1)
		T.expect(c1.gold).toBe(math.floor(30 * 40 * 2 ^ 1.6 + 0.5))
		T.expect(c1.materials).toEqual({ { id = "essence_dust", n = 2 } })
		T.expect(Upgrade.cost(item(4, 2), 3).materials).toEqual({ { id = "essence_dust", n = 6 } })
		T.expect(Upgrade.cost(item(4, 4), 5).materials).toEqual({ { id = "essence_shard", n = 5 } })
		T.expect(Upgrade.cost(item(4, 6), 7).materials).toEqual({ { id = "essence_crystal", n = 2 } })
		T.expect(Upgrade.cost(item(5, 8), 9).materials).toEqual({
			{ id = "essence_crystal", n = 4 },
			{ id = "legend_core", n = 1 },
		})
	end)

	T.it("+0 → +1 always succeeds", function()
		local rng = Rng.new(1)
		for _ = 1, 200 do
			T.expect(Upgrade.attempt(item(1, 0), false, rng).success).toBe(true)
		end
	end)

	T.it("failure drops one level, protection keeps it, +0 never goes lower", function()
		local rng = Rng.new(2)
		local sawFail, sawProtected = false, false
		for _ = 1, 400 do
			local r = Upgrade.attempt(item(1, 8), false, rng)
			if not r.success then
				sawFail = true
				T.expect(r.to).toBe(7)
			else
				T.expect(r.to).toBe(9)
			end
			local p = Upgrade.attempt(item(1, 8), true, rng)
			if not p.success then
				sawProtected = true
				T.expect({ p.to, p.protected }).toEqual({ 8, true })
			end
		end
		T.expect(sawFail and sawProtected).toBe(true)
	end)

	T.it("success rate matches the chance", function()
		local rng = Rng.new(3)
		local ok = 0
		for _ = 1, 20000 do
			if Upgrade.attempt(item(1, 4), false, rng).success then
				ok += 1
			end
		end
		T.expect(ok / 20000).toBeNear(0.6, 0.02)
	end)

	T.it("max level is +9", function()
		T.expect(Upgrade.canUpgrade(item(1, 8))).toBe(true)
		T.expect(Upgrade.canUpgrade(item(1, 9))).toBe(false)
		T.expect(Upgrade.statMultiplier(9)).toBeNear(1.54)
	end)
end)

T.describe("Dismantle", function()
	T.it("materials by rarity", function()
		local rng = Rng.new(4)
		for _ = 1, 100 do
			local common = Dismantle.roll(item(1, 0), rng)
			T.expect(common[1].id).toBe("essence_dust")
			T.expect(common[1].n).toBeBetween(1, 2)
			local rare = Dismantle.roll(item(3, 0), rng)
			T.expect(rare[1].id).toBe("essence_shard")
			local legendary = Dismantle.roll(item(5, 0), rng)
			T.expect(legendary[1].id).toBe("essence_crystal")
			T.expect(legendary[2]).toEqual({ id = "legend_core", n = 1 })
		end
	end)

	T.it("epic gives a crystal about 30 % of the time", function()
		local rng = Rng.new(5)
		local crystals = 0
		for _ = 1, 5000 do
			for _, m in Dismantle.roll(item(4, 0), rng) do
				if m.id == "essence_crystal" then
					crystals += 1
				end
			end
		end
		T.expect(crystals / 5000).toBeNear(0.3, 0.03)
	end)

	T.it("upgrades refund half of the spent essences", function()
		-- +1..+3 dust 2+4+6 = 12 -> 6; +4 shard 4 -> 2
		local refund = Dismantle.upgradeRefund(item(1, 4))
		T.expect(refund).toEqual({ { id = "essence_dust", n = 6 }, { id = "essence_shard", n = 2 } })
	end)

	T.it("only equipment can be dismantled", function()
		T.expect(Dismantle.canDismantle(item(1, 0))).toBe(true)
		T.expect(Dismantle.canDismantle(ItemRoll.makeStack("essence_dust", 5, "y"))).toBe(false)
	end)
end)

T.describe("Economy data", function()
	T.it("sell price follows DESIGN §18", function()
		T.expect(ItemRoll.sellPrice(item(1, 0, 50))).toBe(100)
		T.expect(ItemRoll.sellPrice(item(5, 0, 50))).toBe(math.floor(50 * 2 * 1.4 * 1.4 + 0.5))
		T.expect(ItemRoll.sellPrice(item(5, 0, 50)) > ItemRoll.sellPrice(item(4, 0, 50))).toBe(true)
	end)

	T.it("shops sell existing items with a price", function()
		for id, shop in Shops.byId do
			for _, entry in shop.entries do
				local def = Items.get(entry.item)
				if not def then
					error(`{id}: unknown item {entry.item}`)
				end
				local price = entry.price or entry.pricePerLevel or def.buyPrice
				if not price or price <= 0 then
					error(`{id}: {entry.item} has no price`)
				end
			end
		end
		T.expect(#Shops.byId.healer.entries).toBe(15)
	end)

	T.it("every NPC is localized and its shop exists", function()
		for _, npc in Npcs.list do
			T.expect(en[npc.nameKey] ~= nil).toBe(true)
			T.expect(en[npc.greetingKey] ~= nil).toBe(true)
			if table.find(npc.services, "shop") then
				T.expect(Shops.get(npc.shop or "") ~= nil).toBe(true)
			end
		end
	end)

	T.it("one recipe per equipment base and tier, using existing materials", function()
		-- 39 bases x 21 tiers, mage weapons (3 bases) once per element (+2 each)
		T.expect(#Crafting.list).toBe(39 * 21 + 3 * 21 * 2)
		for _, recipe in Crafting.list do
			T.expect(Items.get(recipe.item) ~= nil).toBe(true)
			for _, material in recipe.materials do
				T.expect(Items.get(material.id) ~= nil).toBe(true)
			end
		end
		T.expect(Crafting.oreFor(1)).toBe("ore_copper")
		T.expect(Crafting.oreFor(100)).toBe("ore_adamantite")
	end)
end)

return nil
