--!strict
local Bonuses = require("../src/shared/Data/Bonuses")
local Inventory = require("../src/shared/Logic/Inventory")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Loot = require("../src/shared/Logic/Loot")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")

local counter = 0
local function uid(): string
	counter += 1
	return `uid{counter}`
end

local function stack(id: string, n: number): any
	return ItemRoll.makeStack(id, n, uid())
end

T.describe("ItemRoll", function()
	T.it("rolls the right number of distinct bonuses per rarity", function()
		local rng = Rng.new(1)
		for rarity = 1, 5 do
			for _ = 1, 50 do
				local item = ItemRoll.rollItem("sword1h_30", 31, rarity, rng, uid())
				local def = Rarities.get(rarity)
				T.expect(#item.bonuses)
					.toBeBetween(def.bonusMin + def.legendaryLines, def.bonusMax + def.legendaryLines)
				T.expect(item.rv).toBe(Rarities.RV)
				local seen = {}
				for _, bonus in item.bonuses do
					T.expect(seen[bonus.stat]).toBeNil()
					seen[bonus.stat] = true
					T.expect(Bonuses.get(bonus.stat) ~= nil).toBe(true)
				end
			end
		end
	end)

	T.it("legendary items get one legendary-pool bonus, mythic two different ones", function()
		local rng = Rng.new(2)
		for _, case in { { Rarities.LEGENDARY, 1 }, { Rarities.MYTHIC, 2 }, { Rarities.HEROIC, 0 } } do
			for _ = 1, 100 do
				local item = ItemRoll.rollItem("ring_50", 52, case[1], rng, uid())
				local legendary = 0
				local seen = {}
				for _, bonus in item.bonuses do
					if table.find(Bonuses.pools.legendary, bonus.stat) then
						legendary += 1
						T.expect(seen[bonus.stat]).toBeNil()
						seen[bonus.stat] = true
					end
				end
				T.expect(legendary).toBe(case[2])
				if case[1] ~= Rarities.HEROIC then
					local r = Rarities.get(case[1])
					T.expect(#item.bonuses).toBeBetween(r.bonusMin + case[2], r.bonusMax + case[2])
				end
			end
		end
	end)

	T.it("unique rolls 1–2 bonuses and heroic 2–3, both counts happen", function()
		local rng = Rng.new(21)
		for _, case in { { Rarities.UNIQUE, 1, 2 }, { Rarities.HEROIC, 2, 3 } } do
			local counts = {}
			for _ = 1, 200 do
				local item = ItemRoll.rollItem("sword1h_30", 31, case[1], rng, uid())
				counts[#item.bonuses] = true
			end
			T.expect(counts[case[2]]).toBe(true)
			T.expect(counts[case[3]]).toBe(true)
		end
	end)

	T.it("bonus values stay inside their scaled range", function()
		local rng = Rng.new(3)
		for _ = 1, 200 do
			local item = ItemRoll.rollItem("armor_heavy_60", 62, 4, rng, uid())
			for _, bonus in item.bonuses do
				local low, high = ItemRoll.bonusRange(bonus.stat, item.ilvl, item.rarity)
				-- Rounding to the bonus precision may move a value by half a unit.
				T.expect(bonus.v >= low - 0.5 and bonus.v <= high + 0.5).toBe(true)
				T.expect(ItemRoll.bonusQuality(bonus.stat, bonus.v, item.ilvl, item.rarity)).toBeBetween(0, 1)
			end
		end
	end)

	T.it("higher ilvl and rarity widen bonus ranges", function()
		local _, lowMax = ItemRoll.bonusRange("physAtk", 1, 2)
		local _, highMax = ItemRoll.bonusRange("physAtk", 100, 2)
		local _, legMax = ItemRoll.bonusRange("physAtk", 100, Rarities.LEGENDARY)
		local _, mythMax = ItemRoll.bonusRange("physAtk", 100, Rarities.MYTHIC)
		T.expect(highMax > lowMax).toBe(true)
		local unique = Rarities.get(2).rangeMul
		T.expect(legMax).toBeNear(highMax / unique * Rarities.get(Rarities.LEGENDARY).rangeMul)
		T.expect(mythMax).toBeNear(highMax / unique * Rarities.get(Rarities.MYTHIC).rangeMul)
	end)

	T.it("named boss items keep fixed bonuses and are Mythic", function()
		local item = ItemRoll.rollItem("unique_grimrok_cleaver", 1, 2, Rng.new(4), uid())
		T.expect(item.rarity).toBe(Rarities.MYTHIC)
		T.expect(item.rv).toBe(Rarities.RV)
		T.expect(item.ilvl).toBe(20)
		T.expect(item.bonuses).toEqual((Items.get("unique_grimrok_cleaver") :: any).fixedBonuses)
	end)

	T.it("non-equipment rolls to a single common unit", function()
		local item = ItemRoll.rollItem("essence_dust", 50, 5, Rng.new(5), uid())
		T.expect({ item.rarity, #item.bonuses, item.n }).toEqual({ 1, 0, 1 })
	end)

	T.it("itemStats: rarity multiplies base, upgrades add 6 % per level", function()
		local common: any = ItemRoll.rollItem("sword1h_50", 50, 1, Rng.new(6), uid())
		local stats = ItemRoll.itemStats(common)
		local def = Items.get("sword1h_50") :: any
		T.expect((stats.weapon :: any).dmg).toBe(def.weapon.dmg)
		common.up = 9
		T.expect((ItemRoll.itemStats(common).weapon :: any).dmg).toBe(math.floor(def.weapon.dmg * 1.54 + 0.5))
		local legendary: any = ItemRoll.rollItem("sword1h_50", 50, Rarities.LEGENDARY, Rng.new(6), uid())
		local legMul = Rarities.get(Rarities.LEGENDARY).baseMul
		T.expect((ItemRoll.itemStats(legendary).weapon :: any).dmg).toBe(math.floor(def.weapon.dmg * legMul + 0.5))
		local mythic: any = ItemRoll.rollItem("sword1h_50", 50, Rarities.MYTHIC, Rng.new(6), uid())
		local mythMul = Rarities.get(Rarities.MYTHIC).baseMul
		T.expect((ItemRoll.itemStats(mythic).weapon :: any).dmg).toBe(math.floor(def.weapon.dmg * mythMul + 0.5))
	end)

	T.it("named boss items keep their ×1.3 base (S30 B.2; S32: axe 1.14, Grimrok's cleaver has 74 damage)", function()
		local item: any = ItemRoll.rollItem("unique_grimrok_cleaver", 20, 1, Rng.new(6), uid())
		local base = (Items.bases.byType.axe1h.weapon :: any)(20)
		local dmg = (ItemRoll.itemStats(item).weapon :: any).dmg
		T.expect(dmg).toBe(math.floor(base.dmg * 1.3 + 0.5))
		T.expect(dmg).toBe(74)
		local totem: any = ItemRoll.rollItem("unique_grimrok_totem", 20, 1, Rng.new(6), uid())
		local raw = (Items.bases.byType.talisman.stats :: any)(20)
		for stat, value in raw do
			T.expect(ItemRoll.itemStats(totem).base[stat]).toBeNear(value * 1.3, 0.11)
		end
		item.up = 9
		T.expect((ItemRoll.itemStats(item).weapon :: any).dmg).toBe(math.floor(74 * 1.54 + 0.5))
	end)

	T.it("itemStats scales with ilvl: every level beats the one before", function()
		local previous = 0
		for ilvl = 1, 12 do
			local item: any = ItemRoll.rollItem("sword1h_1", ilvl, 1, Rng.new(7), uid())
			item.id = (Items.generate.tierFor(ilvl) == 1 and "sword1h_1") or `sword1h_{Items.generate.tierFor(ilvl)}`
			local dmg = (ItemRoll.itemStats(item).weapon :: any).dmg
			T.expect(dmg > previous).toBe(true)
			previous = dmg
			T.expect(ItemRoll.requiredLevel(item)).toBe(ilvl)
		end
		local armor: any = ItemRoll.rollItem("armor_heavy_1", 3, 1, Rng.new(8), uid())
		local armor1: any = ItemRoll.rollItem("armor_heavy_1", 1, 1, Rng.new(8), uid())
		T.expect(ItemRoll.itemStats(armor).base.armor > ItemRoll.itemStats(armor1).base.armor).toBe(true)
	end)

	T.it("itemStats maps bonuses to flat, pct and hooks", function()
		local item: any = {
			uid = "x",
			id = "necklace_10",
			rarity = 5,
			ilvl = 10,
			up = 0,
			bound = false,
			n = 1,
			bonuses = { { stat = "hp", v = 20 }, { stat = "hpPct", v = 3 }, { stat = "leg_bossDamage", v = 8 } },
		}
		local stats = ItemRoll.itemStats(item)
		local mythMul = Rarities.get(Rarities.MYTHIC).baseMul
		local baseHp = math.floor((Items.get("necklace_10") :: any).base.hp * mythMul * 10 + 0.5) / 10
		T.expect(stats.flat.maxHp).toBe(20)
		T.expect(stats.flat.hp).toBeNear(baseHp, 0.6)
		T.expect(stats.pct.maxHp).toBe(3)
		T.expect(stats.hooks.bossDamage).toBe(8)
	end)

	T.it("sell price grows with rarity, upgrade and stack size", function()
		local common: any = ItemRoll.rollItem("ring_30", 30, 1, Rng.new(7), uid())
		local epic: any = ItemRoll.rollItem("ring_30", 30, 4, Rng.new(7), uid())
		T.expect(ItemRoll.sellPrice(epic) > ItemRoll.sellPrice(common)).toBe(true)
		local dust = stack("essence_dust", 10)
		T.expect(ItemRoll.sellPrice(dust)).toBe((Items.get("essence_dust") :: any).price * 10)
	end)

	T.it("rarity distribution matches weights within 10 % (100 000 rolls)", function()
		local rng = Rng.new(2024)
		for variant, weights in Rarities.dropWeights do
			local total = 0
			for _, w in weights do
				total += w
			end
			local counts: { [number]: number } = {}
			local rolls = 100000
			for _ = 1, rolls do
				local r = ItemRoll.rollRarity(variant, rng)
				counts[r] = (counts[r] or 0) + 1
			end
			for rarity, w in weights do
				local expected = rolls * w / total
				local actual = counts[rarity] or 0
				-- +-10 % relative, with a floor for very rare outcomes (statistical noise).
				local tolerance = math.max(expected * 0.1, 4 * math.sqrt(expected))
				if math.abs(actual - expected) > tolerance then
					error(`{variant} rarity {rarity}: expected ~{expected}, got {actual}`)
				end
			end
		end
	end)
end)

T.describe("Loot", function()
	T.it("normal monsters drop items about 20 % of the time", function()
		local rng = Rng.new(11)
		local withItems = 0
		for _ = 1, 20000 do
			if #Loot.rollMonsterLoot("wolf", "normal", 5, rng).items > 0 then
				withItems += 1
			end
		end
		T.expect(withItems / 20000).toBeNear(0.20, 0.015)
	end)

	T.it("drop bonus multiplies the chance", function()
		local rng = Rng.new(12)
		local withItems = 0
		for _ = 1, 20000 do
			if #Loot.rollMonsterLoot("wolf", "normal", 5, rng, { dropBonus = 100 }).items > 0 then
				withItems += 1
			end
		end
		T.expect(withItems / 20000).toBeNear(0.40, 0.02)
	end)

	T.it("Elite II always drops 2–3 items of the right tier", function()
		local rng = Rng.new(13)
		for _ = 1, 300 do
			local loot = Loot.rollMonsterLoot("caveSpider", "elite2", 20, rng)
			for _, drop in loot.items do
				T.expect(Items.get(drop.defId) ~= nil).toBe(true)
				T.expect(drop.ilvl).toBeBetween(18, 22)
				T.expect(drop.rarity).toBeBetween(Rarities.UNIQUE, Rarities.cap.elite2)
			end
			T.expect(#loot.items).toBeBetween(2, 3)
			T.expect(loot.gold > 0).toBe(true)
		end
	end)

	T.it("class bias prefers usable items", function()
		local rng = Rng.new(14)
		local usable, total = 0, 0
		for _ = 1, 3000 do
			local id = Loot.pickItem({ weapon = 1 }, 30, 1, "Mage", rng)
			if id then
				total += 1
				local def = Items.get(id) :: any
				if table.find(def.classes, "Mage") then
					usable += 1
				end
			end
		end
		T.expect(usable).toBe(total)
	end)

	T.it("boss loot: 3–4 items (+1 per player above 3) and materials", function()
		local rng = Rng.new(15)
		for _ = 1, 100 do
			local loot = Loot.rollBossLoot("grimrok", 5, rng)
			for _, drop in loot.items do
				-- Shared boss items: Unique or Heroic; Legendary/Mythic only from the personal roll.
				T.expect(drop.rarity).toBeBetween(Rarities.UNIQUE, Rarities.HEROIC)
				T.expect(Items.get(drop.defId).fixedBonuses).toBeNil()
			end
			T.expect(#loot.items).toBeBetween(5, 6)
			T.expect(#loot.materials > 0).toBe(true)
		end
	end)

	T.it("unknown monsters drop nothing", function()
		local loot = Loot.rollMonsterLoot("dragonKing", "normal", 5, Rng.new(1))
		T.expect(#loot.items + #loot.materials).toBe(0)
	end)
end)

T.describe("Inventory", function()
	T.it("adds to the first free slot and reports a full backpack", function()
		local inv: any = {}
		for i = 1, 3 do
			local changed, left = Inventory.add(inv, 3, ItemRoll.rollItem("ring_1", 1, 1, Rng.new(i), uid()), uid)
			T.expect({ changed[1], left }).toEqual({ i, 0 })
		end
		local _, left = Inventory.add(inv, 3, ItemRoll.rollItem("ring_1", 1, 1, Rng.new(9), uid()), uid)
		T.expect(left).toBe(1)
		T.expect(Inventory.firstFree(inv, 3)).toBeNil()
		T.expect(Inventory.freeSlots(inv, 3)).toBe(0)
	end)

	T.it("stacks up to 999 and overflows into new slots", function()
		local inv: any = {}
		Inventory.add(inv, 5, stack("essence_dust", 990), uid)
		local changed, left = Inventory.add(inv, 5, stack("essence_dust", 20), uid)
		T.expect(left).toBe(0)
		T.expect(changed).toEqual({ 1, 2 })
		T.expect(inv["1"].n).toBe(999)
		T.expect(inv["2"].n).toBe(11)
		T.expect(inv["1"].uid ~= inv["2"].uid).toBe(true)
		T.expect(Inventory.count(inv, "essence_dust")).toBe(1010)
	end)

	T.it("bound and unbound stacks do not merge", function()
		local inv: any = {}
		Inventory.add(inv, 5, stack("scroll_unbind", 1), uid)
		local bound = stack("scroll_unbind", 1)
		bound.bound = true
		local changed = Inventory.add(inv, 5, bound, uid)
		T.expect(changed).toEqual({ 2 })
	end)

	T.it("canFit simulates without mutating", function()
		local inv: any = {}
		Inventory.add(inv, 2, stack("essence_dust", 500), uid)
		T.expect(Inventory.canFit(inv, 2, { stack("essence_dust", 499), stack("ring_1", 1) })).toBe(true)
		T.expect(Inventory.canFit(inv, 2, { stack("ore_iron", 1), stack("ring_1", 1) })).toBe(false)
		T.expect(Inventory.count(inv, "essence_dust")).toBe(500)
	end)

	T.it("move swaps, merges and rejects bad indices", function()
		local inv: any = {}
		Inventory.add(inv, 4, stack("essence_dust", 10), uid)
		inv["3"] = stack("essence_dust", 5)
		inv["4"] = ItemRoll.rollItem("ring_1", 1, 1, Rng.new(1), uid())
		T.expect(Inventory.move(inv, 4, 3, 1)).toEqual({ 3, 1 })
		T.expect(inv["1"].n).toBe(15)
		T.expect(inv["3"]).toBeNil()
		T.expect(Inventory.move(inv, 4, 4, 2)).toEqual({ 4, 2 })
		T.expect(inv["2"].id).toBe("ring_1")
		T.expect(Inventory.move(inv, 4, 3, 1)).toBeNil() -- empty source
		T.expect(Inventory.move(inv, 4, 1, 9)).toBeNil() -- outside capacity
	end)

	T.it("split creates a new stack with a new uid", function()
		local inv: any = {}
		Inventory.add(inv, 3, stack("potion_hp_1", 10), uid)
		T.expect(Inventory.split(inv, 3, 1, 4, uid)).toEqual({ 1, 2 })
		T.expect({ inv["1"].n, inv["2"].n }).toEqual({ 6, 4 })
		T.expect(Inventory.split(inv, 3, 1, 6, uid)).toBeNil() -- whole stack
		T.expect(Inventory.split(inv, 3, 1, 0, uid)).toBeNil()
	end)

	T.it("sort merges stacks and orders by category, slot, rarity", function()
		local inv: any = {}
		inv["5"] = stack("essence_dust", 3)
		inv["2"] = ItemRoll.rollItem("ring_10", 10, 1, Rng.new(1), uid())
		inv["7"] = ItemRoll.rollItem("sword1h_10", 10, 4, Rng.new(1), uid())
		inv["9"] = stack("essence_dust", 4)
		inv["1"] = stack("potion_hp_1", 2)
		Inventory.sort(inv, 10, uid)
		T.expect(inv["1"].id).toBe("sword1h_10")
		T.expect(inv["2"].id).toBe("ring_10")
		T.expect(inv["3"].id).toBe("potion_hp_1")
		T.expect(inv["4"].id).toBe("essence_dust")
		T.expect(inv["4"].n).toBe(7)
		T.expect(inv["5"]).toBeNil()
	end)

	T.it("compact packs into a smaller backpack or refuses", function()
		local inv: any = { ["3"] = stack("ore_iron", 1), ["9"] = stack("ore_copper", 1) }
		T.expect(Inventory.compact(inv, 2)).toBe(true)
		T.expect({ inv["1"].id, inv["2"].id }).toEqual({ "ore_iron", "ore_copper" })
		inv["3"] = stack("fish_carp", 1)
		T.expect(Inventory.compact(inv, 2)).toBe(false)
		T.expect(inv["3"].id).toBe("fish_carp")
	end)

	T.it("remove takes from the smallest stacks first", function()
		local inv: any = { ["1"] = stack("essence_dust", 10), ["2"] = stack("essence_dust", 3) }
		local removed, changed = Inventory.remove(inv, "essence_dust", 5)
		T.expect(removed).toBe(5)
		T.expect(changed).toEqual({ 2, 1 })
		T.expect(inv["2"]).toBeNil()
		T.expect(inv["1"].n).toBe(8)
		T.expect((Inventory.remove(inv, "essence_dust", 50))).toBe(8)
	end)
end)

return nil
