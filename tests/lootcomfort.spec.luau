--!strict
local Dismantle = require("../src/shared/Logic/Dismantle")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Bonuses = require("../src/shared/Data/Bonuses")
local ItemScore = require("../src/shared/Logic/ItemScore")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local ItemWeights = require("../src/shared/Data/ItemWeights")
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

	local function made(defId: string, bonuses: { any }): any
		return {
			uid = "m" .. defId,
			id = defId,
			rarity = Rarities.HEROIC,
			ilvl = 30,
			bonuses = bonuses,
			up = 0,
			bound = false,
			n = 1,
			rv = Rarities.RV,
		}
	end

	T.it("S67: a family line is worth half an attack line for every class", function()
		local cases = {
			{ "Warrior", "sword1h_30", "physAtk" },
			{ "Hunter", "bow_30", "physAtk" },
			{ "Mage", "wand_30", "magAtk" },
			{ "Cleric", "mace1h_30", "magAtk" },
		}
		for _, case in cases do
			local classId, defId, attack = case[1], case[2], case[3]
			local bare = ItemScore.score(made(defId, {}), classId)
			local family = ItemScore.score(made(defId, { { stat = "vs_undead", v = 4 } }), classId)
			local atk = ItemScore.score(made(defId, { { stat = attack, v = 4 } }), classId)
			T.expect({ classId, bare < family, family < atk }).toEqual({ classId, true, true })
			T.expect(family - bare).toBeNear((atk - bare) / 2, 1e-9)
		end
	end)

	T.it("S67: path weights change the axes; an unknown path changes nothing", function()
		local hp = made("helmet_heavy_30", { { stat = "hpPct", v = 4 } })
		local crit = made("helmet_heavy_30", { { stat = "critChance", v = 4 } })
		T.expect(ItemScore.score(hp, "Warrior") < ItemScore.score(crit, "Warrior")).toBe(true)
		local tank = { classId = "Warrior", weights = { axes = { surv = 2 } } }
		T.expect(ItemScore.score(hp, tank) > ItemScore.score(crit, tank)).toBe(true)
		T.expect(ItemScore.score(hp, { classId = "Warrior", pathId = "nope" })).toBe(ItemScore.score(hp, "Warrior"))
		local b = ItemScore.breakdown(crit, "Warrior")
		T.expect(b.dmg + b.surv + b.support + b.util).toBeNear(b.total, 1e-9)
	end)

	T.it("S67: every line and trait has a weight", function()
		local function classHas(key: string): boolean
			for _, byClass in ItemWeights.class do
				if byClass[key] then
					return true
				end
			end
			return false
		end
		for id, def in Bonuses.byId do
			if not def.replacedBy then
				local ok
				if def.hook then
					local prefixed = false
					for prefix in ItemWeights.prefixHooks do
						if string.sub(def.hook, 1, #prefix) == prefix then
							prefixed = true
						end
					end
					ok = ItemWeights.hooks[def.hook] ~= nil or classHas(def.hook) or prefixed
				else
					local stat = def.stat :: string
					ok = ItemWeights.common[stat] ~= nil or classHas(stat)
				end
				T.expect({ id, ok }).toEqual({ id, true })
			end
		end
		for _, def in ItemTraits.list do
			T.expect({ def.id, ItemWeights.traits[def.id] ~= nil }).toEqual({ def.id, true })
		end
		T.expect(#ItemScore.validateWeights({ axes = { foo = 1 } })).toBe(1)
	end)

	T.it("a mage values magic damage, a warrior physical", function()
		local wand, sword = item("wand_10", 10), item("sword1h_10", 10)
		T.expect(ItemScore.score(wand, "Mage") > ItemScore.score(sword, "Mage")).toBe(true)
		T.expect(ItemScore.score(sword, "Warrior") > ItemScore.score(wand, "Warrior")).toBe(true)
	end)
end)

T.describe("LootFilter", function()
	T.it("hides weak equipment only, never materials or legendaries", function()
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, Rarities.HEROIC, nil, false)).toBe("hide")
		T.expect(LootFilter.decide("equipment", Rarities.UNIQUE, Rarities.HEROIC, nil, false)).toBe("hide")
		T.expect(LootFilter.decide("equipment", Rarities.HEROIC, Rarities.HEROIC, nil, false)).toBe("show")
		T.expect(LootFilter.decide("material", Rarities.COMMON, Rarities.HEROIC, nil, false)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.LEGENDARY, 99, nil, false)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.MYTHIC, 99, nil, false)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, 0, nil, false)).toBe("show")
	end)

	T.it("auto-loot picks up from the chosen rarity and everything else", function()
		T.expect(LootFilter.decide("equipment", Rarities.COMMON, nil, Rarities.HEROIC, true)).toBe("show")
		T.expect(LootFilter.decide("equipment", Rarities.LEGENDARY, nil, Rarities.HEROIC, true)).toBe("pickup")
		T.expect(LootFilter.decide("material", Rarities.COMMON, nil, Rarities.HEROIC, true)).toBe("pickup")
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
