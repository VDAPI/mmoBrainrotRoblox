--!strict
-- FIX 2026-10-14: groups of the shop's Buy view (Logic/ShopGroups): every entry of every shop in exactly one known
-- group, groups in ORDER, the class vendor's tiers ascending inside a group, and a header text for every group.

local Test = require("./Test")
local Items = require("../src/shared/Data/Items")
local Pl = require("../src/shared/Data/Localization/pl")
local En = require("../src/shared/Data/Localization/en")
local ShopGroups = require("../src/shared/Logic/ShopGroups")
local Shops = require("../src/shared/Data/Shops")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function shopList(): { Shops.ShopDef }
	local list: { Shops.ShopDef } = {}
	for _, shop in Shops.byId do
		table.insert(list, shop)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

describe("ShopGroups", function()
	it("puts every entry in exactly one group, groups in ORDER", function()
		for _, shop in shopList() do
			local groups = ShopGroups.group(shop.entries)
			local count = 0
			local lastOrder = 0
			for _, group in groups do
				local order = table.find(ShopGroups.ORDER, group.id)
				expect({ shop = shop.id, group = group.id, known = order ~= nil }).toEqual({
					shop = shop.id,
					group = group.id,
					known = true,
				})
				expect((order :: number) > lastOrder).toBe(true)
				lastOrder = order :: number
				expect(#group.entries > 0).toBe(true)
				count += #group.entries
			end
			expect({ shop = shop.id, n = count }).toEqual({ shop = shop.id, n = #shop.entries })
		end
	end)

	it("sorts kinds of item into their groups", function()
		expect(ShopGroups.of(Items.get("potion_hp_1"))).toBe("potion")
		expect(ShopGroups.of(Items.get("pickaxe"))).toBe("tool")
		expect(ShopGroups.of(Items.get("ore_iron"))).toBe("material")
		expect(ShopGroups.of(Items.get("scroll_oblivion"))).toBe("scroll")
		expect(ShopGroups.of(Items.get("sword1h_5"))).toBe("weapon")
		expect(ShopGroups.of(nil)).toBe("other")
	end)

	it("lists a class vendor's group by tier, weapons first", function()
		local shop = Shops.get("vendor_warrior")
		assert(shop, "vendor_warrior")
		local groups = ShopGroups.group(shop.entries)
		expect(groups[1].id).toBe("weapon")
		for _, group in groups do
			local last = 0
			for _, entry in group.entries do
				local level = entry.level or 0
				expect(level >= last).toBe(true)
				last = level
			end
		end
	end)

	it("has a header in both languages for every group", function()
		for _, id in ShopGroups.ORDER do
			local key = `shop.group.{id}`
			expect({ key = key, pl = (Pl :: any)[key] ~= nil, en = (En :: any)[key] ~= nil }).toEqual({
				key = key,
				pl = true,
				en = true,
			})
		end
	end)
end)
