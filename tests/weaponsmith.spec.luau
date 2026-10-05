--!strict
local Classes = require("../src/shared/Data/Classes")
local Elements = require("../src/shared/Data/Elements")
local ItemName = require("../src/shared/Logic/ItemName")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Npcs = require("../src/shared/Data/Npcs")
local Rng = require("../src/shared/Logic/Rng")
local ShopPrice = require("../src/shared/Logic/ShopPrice")
local Shops = require("../src/shared/Data/Shops")
local StarterGear = require("../src/shared/Logic/StarterGear")
local T = require("./Test")

T.describe("Weaponsmith (S18)", function()
	local shop = Shops.get("weaponsmith") :: Shops.ShopDef

	T.it("stands in the city and sells with class tabs", function()
		local npc = Npcs.get("weaponsmith")
		T.expect(npc and npc.shop).toBe("weaponsmith")
		T.expect(shop.classTabs).toBe(true)
	end)

	T.it("every class gets a weapon at every tier, priced and level gated", function()
		local seen: { [string]: boolean } = {}
		for _, classId in Classes.order do
			for _, tier in { 1, 5, 50, 100 } do
				local found = false
				for _, entry in shop.entries do
					local def = Items.get(entry.item)
					if
						def
						and def.slot == "weapon"
						and entry.ilvl == tier
						and entry.classes
						and table.find(entry.classes, classId)
					then
						found = true
					end
				end
				T.expect(found).toBe(true)
			end
		end
		for _, entry in shop.entries do
			local key = entry.key or entry.item
			T.expect(seen[key]).toBeNil()
			seen[key] = true
			T.expect(entry.level).toBe(entry.ilvl)
			T.expect(ShopPrice.unit(entry, 1, 0) > 0).toBe(true)
		end
	end)

	T.it("mage weapons come in every element", function()
		local wand: { [string]: boolean } = {}
		for _, entry in shop.entries do
			if entry.item == "wand_10" then
				wand[entry.el or "none"] = true
			end
		end
		for _, element in Elements.WEAPON do
			T.expect(wand[element]).toBe(true)
		end
		T.expect(wand.none).toBeNil()
	end)
end)

T.describe("Mage weapon elements (items)", function()
	T.it("dropped mage weapons roll an element, others do not", function()
		local rng = Rng.new(3)
		local counts: { [string]: number } = {}
		for i = 1, 300 do
			local item = ItemRoll.rollItem("staff_20", 20, 2, rng, `u{i}`)
			counts[item.el or "none"] = (counts[item.el or "none"] or 0) + 1
		end
		for _, element in Elements.WEAPON do
			T.expect((counts[element] or 0) > 50).toBe(true)
		end
		T.expect(ItemRoll.rollItem("sword1h_20", 20, 2, rng, "s").el).toBeNil()
	end)

	T.it("old mage weapons count as fire and the weapon stats carry the element", function()
		local item: any = ItemRoll.rollItem("wand_1", 1, 1, Rng.new(1), "w")
		item.el = nil
		T.expect(ItemRoll.elementOf(item)).toBe("fire")
		item.el = "ice"
		T.expect((ItemRoll.itemStats(item).weapon :: any).element).toBe("ice")
		T.expect(ItemName.get("pl", "wand_1", nil, "ice")).toBe("Prosta Różdżka Lodu")
		T.expect(ItemName.get("en", "wand_1", nil, "lightning")).toBe("Crude Wand of Lightning")
	end)

	T.it("the Mage starts with a Wand of Fire", function()
		local character: any = {
			class = "Mage",
			equipment = {},
			inventory = {},
			potionBar = {},
		}
		local n = 0
		StarterGear.apply(character, function()
			n += 1
			return `id{n}`
		end)
		T.expect(character.equipment.weapon.el).toBe("fire")
	end)
end)

return nil
