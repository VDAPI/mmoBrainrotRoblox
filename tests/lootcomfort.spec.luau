--!strict
local Dismantle = require("../src/shared/Logic/Dismantle")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemScore = require("../src/shared/Logic/ItemScore")
local LootFilter = require("../src/shared/Logic/LootFilter")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Trade = require("../src/shared/Logic/Trade")
local T = require("./Test")

local function item(id: string, ilvl: number, rarity: number?): any
	return ItemRoll.rollItem(id, ilvl, rarity or 1, Rng.new(ilvl * 7 + (rarity or 1)), `u{id}{ilvl}`)
end

T.describe("ItemScore", function()
	T.it("a higher level weapon of the class is better for every class", function()
		for classId, weapon in { Warrior = "sword1h_1", Hunter = "bow_1", Mage = "wand_1", Cleric = "mace1h_1" } do
			local low, high = item(weapon, 2), item(weapon, 6)
			T.expect(ItemScore.score(high, classId) > ItemScore.score(low, classId)).toBe(true)
			T.expect(ItemScore.isUpgrade(high, low, classId, 10)).toBe(true)
			T.expect(ItemScore.isUpgrade(low, high, classId, 10)).toBe(false)
		end
	end)

	T.it("better armour beats worse armour, any class that can wear it", function()
		local low, high = item("armor_heavy_1", 1), item("armor_heavy_1", 5)
		T.expect(ItemScore.isUpgrade(high, low, "Warrior", 10)).toBe(true)
		T.expect(ItemScore.isUpgrade(high, low, "Cleric", 10)).toBe(true)
	end)

	T.it("never suggests items of another class or above the level", function()
		T.expect(ItemScore.isUpgrade(item("bow_1", 3), nil, "Warrior", 10)).toBe(false)
		T.expect(ItemScore.isUpgrade(item("sword1h_10", 12), nil, "Warrior", 10)).toBe(false)
		T.expect(ItemScore.isUpgrade(item("sword1h_10", 10), nil, "Warrior", 10)).toBe(true)
	end)

	T.it("a mage values magic damage, a warrior physical", function()
		local wand, sword = item("wand_10", 10), item("sword1h_10", 10)
		T.expect(ItemScore.score(wand, "Mage") > ItemScore.score(sword, "Mage")).toBe(true)
		T.expect(ItemScore.score(sword, "Warrior") > ItemScore.score(wand, "Warrior")).toBe(true)
	end)
end)

T.describe("LootFilter", function()
	T.it("hides weak equipment only, never materials or legendaries", function()
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, Rarities.RARE, nil, false)).toBe("hide")
		T.expect(LootFilter.decide("equipment", Rarities.RARE, Rarities.RARE, nil, false)).toBe("show")
		T.expect(LootFilter.decide("material", Rarities.COMMON, Rarities.EPIC, nil, false)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.LEGENDARY, 99, nil, false)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, 0, nil, false)).toBe("show")
	end)

	T.it("auto-loot picks up from the chosen rarity and everything else", function()
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, nil, Rarities.RARE, true)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.EPIC, nil, Rarities.RARE, true)).toBe("pickup")
		T.expect(LootFilter.decide("material", Rarities.COMMON, nil, Rarities.RARE, true)).toBe("pickup")
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, nil, 0, true)).toBe("pickup")
	end)
end)

T.describe("Item lock", function()
	T.it("a locked item cannot be dismantled or traded", function()
		local sword = item("sword1h_1", 3, 2)
		T.expect(Dismantle.canDismantle(sword)).toBe(true)
		T.expect((Trade.canOffer(sword))).toBe(true)
		sword.locked = true
		T.expect(Dismantle.canDismantle(sword)).toBe(false)
		local ok, why = Trade.canOffer(sword)
		T.expect(ok).toBe(false)
		T.expect(why).toBe("item.error.locked")
	end)
end)

return nil
