--!strict
local Bonuses = require("../src/shared/Data/Bonuses")
local Inventory = require("../src/shared/Logic/Inventory")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemTraits = require("../src/shared/Data/ItemTraits")
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
				local extra = def.legendaryLines + def.mythicLines
				T.expect(#item.bonuses).toBeBetween(def.bonusMin + extra, def.bonusMax + extra)
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
					local extra = case[2] + r.mythicLines
					T.expect(#item.bonuses).toBeBetween(r.bonusMin + extra, r.bonusMax + extra)
				end
			end
		end
	end)

	T.it("bonus lines per rarity: unique 2, heroic 3, legendary 3 + 1, mythic 3 + 2 + 1 mythic", function()
		local rng = Rng.new(21)
		local cases = {
			{ Rarities.UNIQUE, 2, 0, 0 },
			{ Rarities.HEROIC, 3, 0, 0 },
			{ Rarities.LEGENDARY, 3, 1, 0 },
			{ Rarities.MYTHIC, 3, 2, 1 },
		}
		for _, case in cases do
			for _ = 1, 50 do
				local item = ItemRoll.rollItem("sword1h_30", 31, case[1], rng, uid())
				local counts = { 0, 0, 0 }
				for _, bonus in item.bonuses do
					local slot = if table.find(Bonuses.pools.mythic, bonus.stat)
						then 3
						elseif table.find(Bonuses.pools.legendary, bonus.stat) then 2
						else 1
					counts[slot] += 1
				end
				T.expect(counts).toEqual({ case[2], case[3], case[4] })
			end
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

	T.it("S88 (D4): named Mythics keep 4 lines within their limits and the base type's trait", function()
		local B = require("./Balance")
		local named = 0
		for _, def in Items.byId do
			local d: any = def
			if d.fixedBonuses and d.rarity == Rarities.MYTHIC then
				named += 1
				T.expect({ d.id, #d.fixedBonuses }).toEqual({ d.id, 4 })
				for _, line in d.fixedBonuses do
					T.expect({ d.id, line.stat, Bonuses.get(line.stat) ~= nil }).toEqual({ d.id, line.stat, true })
				end
				for _, line in B.namedLines(d.id) do
					T.expect({ d.id, line.stat, line.ok }).toEqual({ d.id, line.stat, true })
				end
				local item = ItemRoll.rollItem(d.id, d.level, Rarities.MYTHIC, Rng.new(3), uid())
				local trait = ItemRoll.trait(item)
				local base = (Items.bases.byType :: any)[d.type]
				if base.trait then
					T.expect({ d.id, trait and trait.id, trait and trait.power })
						.toEqual({ d.id, base.trait, Rarities.get(Rarities.MYTHIC).baseMul })
				end
			end
		end
		T.expect(named).toBe(12)
		T.expect(B.NAMED_LINE_MAX).toBe(2.5)
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

	T.it("boss loot: materials and gold only (FIX 2026-10-09: items come one per winner)", function()
		local rng = Rng.new(15)
		for _ = 1, 100 do
			local loot = Loot.rollBossLoot("grimrok", 5, rng)
			T.expect(#loot.items).toBe(0)
			T.expect(#loot.materials > 0).toBe(true)
			T.expect(loot.gold > 0).toBe(true)
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

T.describe("S62 traits and weighted pools", function()
	local function plain(defId: string, rarity: number, up: number?, bonuses: { any }?): any
		return {
			uid = uid(),
			id = defId,
			rarity = rarity,
			ilvl = (Items.get(defId) :: any).level,
			bonuses = bonuses or {},
			up = up or 0,
			bound = false,
			n = 1,
			rv = Rarities.RV,
		}
	end

	local function has(list: { string }, id: string): boolean
		return table.find(list, id) ~= nil
	end

	T.it("pools follow the class the item dropped for", function()
		local cleric = ItemRoll.bonusPool("mace1h_20", "Cleric")
		T.expect(has(cleric, "str") or has(cleric, "physAtk") or has(cleric, "pierce")).toBe(false)
		T.expect(has(cleric, "healPower") and has(cleric, "magicPierce")).toBe(true)
		local warrior = ItemRoll.bonusPool("mace1h_20", "Warrior")
		T.expect(has(warrior, "magAtk") or has(warrior, "int") or has(warrior, "healPower")).toBe(false)
		local both = ItemRoll.bonusPool("mace1h_20")
		T.expect(has(both, "str") and has(both, "int")).toBe(true)
		T.expect(has(ItemRoll.bonusPool("ring_20", "Mage"), "pierce")).toBe(false)
		T.expect(has(ItemRoll.bonusPool("shield_20", "Warrior"), "critResist")).toBe(true)
		for _, pool in Bonuses.pools do
			T.expect(has(pool, "armorPen")).toBe(false)
		end
		for id in Items.byId do
			T.expect(has(ItemRoll.bonusPool(id), "armorPen")).toBe(false)
		end
	end)

	T.it("pool weights follow the type's trait", function()
		local w = ItemRoll.poolWeights("longbow_50", "Hunter")
		T.expect(w.critChance).toBe(3)
		T.expect(w.critDmg).toBe(3)
		T.expect(w.skillDmg).toBe(3)
		T.expect(w.accuracy).toBe(1)
		T.expect(w.magAtk).toBeNil()
		T.expect(ItemRoll.poolWeights("mace1h_50", "Cleric").healPower).toBe(3)
		T.expect(ItemRoll.poolWeights("mace1h_50", "Warrior").lifesteal).toBe(3)
		T.expect(ItemRoll.poolWeights("mace1h_50", "Cleric").lifesteal).toBe(1)
		for _, pair in { { "longbow_50", "Hunter" }, { "mace1h_50", "Cleric" }, { "ring_20", "Mage" }, { "orb_50" } } do
			local weights = ItemRoll.poolWeights(pair[1], pair[2])
			local pool = ItemRoll.bonusPool(pair[1], pair[2])
			local n = 0
			for id in weights do
				n += 1
				T.expect(has(pool, id)).toBe(true)
			end
			T.expect(n).toBe(#pool)
		end
	end)

	T.it("inclusion gives exact chances of weighted draws without replacement", function()
		local flat: { [string]: number } = {}
		for i = 1, 10 do
			flat[`l{i}`] = 1
		end
		for _, p in ItemRoll.inclusion(flat, 3) do
			T.expect(p).toBeNear(0.3, 1e-9)
		end
		local weights = ItemRoll.poolWeights("longbow_50", "Hunter")
		for count = 0, 3 do
			local sum = 0
			for _, p in ItemRoll.inclusion(weights, count) do
				sum += p
			end
			T.expect(sum).toBeNear(count, 1e-9)
		end
		local zero = ItemRoll.inclusion({ a = 1, b = 0, c = 1 }, 1)
		T.expect(zero.b).toBe(0)
		T.expect(zero.a).toBeNear(0.5, 1e-9)
		T.expect(zero.c).toBeNear(0.5, 1e-9)
		local three = ItemRoll.inclusion(weights, 3)
		T.expect(three.critChance > three.accuracy).toBe(true)
	end)

	T.it("weighted rolls match inclusion", function()
		local rng = Rng.new(62)
		local weights = ItemRoll.poolWeights("longbow_50", "Hunter")
		local expected = ItemRoll.inclusion(weights, 3)
		local seen: { [string]: number } = {}
		local N = 4000
		for _ = 1, N do
			local item = ItemRoll.rollItem("longbow_50", 50, Rarities.HEROIC, rng, uid(), "Hunter")
			local once: { [string]: boolean } = {}
			for _, bonus in item.bonuses do
				T.expect(once[bonus.stat]).toBeNil()
				once[bonus.stat] = true
				-- S67: a family / class variant counts for the pool marker it came from
				local key = (Bonuses.get(bonus.stat) :: any).param or bonus.stat
				seen[key] = (seen[key] or 0) + 1
			end
		end
		for id, p in expected do
			T.expect(math.abs((seen[id] or 0) / N - p) <= 0.03).toBe(true)
		end
	end)

	T.it("trait strength grows with rarity and upgrades", function()
		T.expect(ItemRoll.traitPower(Rarities.COMMON, 0)).toBe(1)
		T.expect(ItemRoll.traitPower(Rarities.MYTHIC, 9)).toBeNear(1.8788, 1e-4)
		local longbow = plain("longbow_50", Rarities.COMMON)
		T.expect((ItemRoll.trait(longbow) :: any).id).toBe("criticalForce")
		T.expect(ItemRoll.itemStats(longbow).flat.critDmg).toBe(20) -- S88: 25 -> 20
		T.expect(ItemRoll.itemStats(plain("heavycrossbow_50", Rarities.COMMON)).flat.pierce).toBe(20)
		T.expect(ItemRoll.itemStats(plain("tome_50", Rarities.COMMON)).flat.costReduce).toBe(8)
		T.expect(ItemRoll.itemStats(plain("orb_50", Rarities.COMMON)).flat.skillDmg).toBe(6)
		T.expect(ItemRoll.itemStats(plain("scepter_50", Rarities.COMMON)).flat.healPower).toBe(5) -- S88: 8 -> 5
		T.expect(ItemRoll.itemStats(plain("relic_50", Rarities.COMMON)).flat.dropBonus).toBe(8)
		T.expect((ItemRoll.trait(plain("orb_50", Rarities.MYTHIC, 9)) :: any).value).toBeNear(11.27, 0.01)
		local eye = ItemRoll.rollItem("unique_vaelgrath_eye", 1, Rarities.COMMON, Rng.new(1), uid())
		local trait = ItemRoll.trait(eye) :: any
		T.expect(trait.power).toBe(1.22)
		T.expect(trait.value).toBeNear(7.32, 0.01)
	end)

	T.it("S63: on-hit traits and lines", function()
		local effectIds = { "rendingGash", "toxicBarbs", "sundering", "bonebreaker", "harrying", "concussion" }
		for _, def in ItemTraits.list do
			local isOnHit = table.find(effectIds, def.id) ~= nil
			T.expect({ def.id, def.onHit ~= nil }).toEqual({ def.id, isOnHit })
			if isOnHit then
				T.expect({ def.id, def.kind, def.live }).toEqual({ def.id, "effect", true })
			end
		end
		local order = { "bleed", "poison", "armorBreak", "weaken", "harass", "shock" }
		T.expect(#ItemTraits.onHitList).toBe(6)
		local hooks: { [string]: boolean } = {}
		for i, entry in ItemTraits.onHitList do
			T.expect(entry.onHit.effect).toBe(order[i])
			local hook = entry.trait.hook :: string
			T.expect(hooks[hook]).toBeNil()
			hooks[hook] = true
			local line = entry.onHit.line
			if line then
				T.expect({ line, (Bonuses.get(line) :: any).hook }).toEqual({ line, line })
			end
		end
		T.expect(ItemRoll.itemStats(plain("hammer2h_50", Rarities.COMMON)).hooks.traitArmorBreak).toBe(5)
		T.expect(ItemRoll.itemStats(plain("axe2h_50", Rarities.COMMON)).hooks.traitWound).toBe(36) -- S88: 30 -> 36
		T.expect(ItemRoll.itemStats(plain("mace1h_50", Rarities.COMMON)).hooks.traitWeaken).toBe(6)
		T.expect(ItemRoll.itemStats(plain("hammer2h_50", Rarities.MYTHIC, 9)).hooks.traitArmorBreak)
			.toBeNear(9.39, 0.05)
		local pools = {
			woundChance = { "weapon", "gloves", "quiver" },
			poisonChance = { "weapon", "gloves", "quiver" },
			dotPower = { "weapon", "necklace" },
			resourceOnHit = { "gloves", "ring" },
		}
		for id, groups in pools do
			local def = Bonuses.get(id) :: any
			T.expect({ id, def.tier, def.hook }).toEqual({ id, "regular", id })
			for group, pool in Bonuses.pools do
				T.expect({ id, group, table.find(pool, id) ~= nil })
					.toEqual({ id, group, table.find(groups, group) ~= nil })
			end
		end
		T.expect(Bonuses.classStats.woundChance).toEqual({ "Warrior", "Hunter" })
		T.expect(Bonuses.classStats.poisonChance).toEqual({ "Hunter" })
		T.expect(Bonuses.classStats.dotPower).toEqual({ "Warrior", "Hunter", "Mage", "Cleric" })
		T.expect(Bonuses.classStats.resourceOnHit).toBeNil()
	end)

	-- S65: every trait is live, so no base hides its trait any more.
	T.it("weapons carry their trait, armour none", function()
		T.expect((Items.get("axe1h_20") :: any).trait).toBe("reaping")
		T.expect(ItemRoll.trait(plain("armor_heavy_10", Rarities.COMMON))).toBeNil()
	end)

	T.it("legacy armorPen reads as pierce with the same quality", function()
		local old = ItemRoll.rollBonusValue("armorPen", 50, Rarities.HEROIC, 0.7)
		local item = plain("sword1h_50", Rarities.HEROIC, 0, { { stat = "armorPen", v = old } })
		local stats = ItemRoll.itemStats(item)
		T.expect(#stats.bonuses).toBe(1)
		T.expect(stats.bonuses[1].id).toBe("pierce")
		T.expect(stats.bonuses[1].quality).toBeNear(0.7, 0.05)
		local q = stats.bonuses[1].quality
		T.expect(stats.flat.pierce).toBe(ItemRoll.rollBonusValue("pierce", 50, Rarities.HEROIC, q))
		T.expect(stats.flat.armorPen).toBeNil()
		T.expect(item.bonuses[1].stat).toBe("armorPen")
	end)

	T.it("saved items keep their rarity and get their trait", function()
		for _, rarity in { Rarities.LEGENDARY, Rarities.MYTHIC } do
			local item = plain("sword1h_30", rarity)
			item.rv = 2
			Rarities.upgradeItem(item, Items.get(item.id))
			T.expect(item.rarity).toBe(rarity)
		end
		local bow = plain("longbow_30", Rarities.LEGENDARY)
		bow.rv = 2
		Rarities.upgradeItem(bow, Items.get(bow.id))
		local trait = ItemRoll.trait(bow) :: any
		T.expect(trait.id).toBe("criticalForce")
		T.expect(trait.power).toBe(1.16)
	end)
end)

T.describe("S64 defensive and conditional traits, new lines", function()
	local Combat = require("../src/shared/Data/Combat")

	local function plain(defId: string, rarity: number, up: number?): any
		return {
			uid = uid(),
			id = defId,
			rarity = rarity,
			ilvl = (Items.get(defId) :: any).level,
			bonuses = {},
			up = up or 0,
			bound = false,
			n = 1,
			rv = Rarities.RV,
		}
	end

	T.it("an old axe gets Reaping without a migration", function()
		local axe = plain("axe1h_50", Rarities.COMMON)
		axe.rv = 2
		Rarities.upgradeItem(axe, Items.get(axe.id))
		local stats = ItemRoll.itemStats(axe)
		T.expect((stats.trait :: any).id).toBe("reaping")
		T.expect(stats.hooks.killHeal).toBe(0.7) -- S88: 1 -> 0.7
		local mythic = plain("axe1h_50", Rarities.MYTHIC, 9)
		T.expect(ItemRoll.itemStats(mythic).hooks.killHeal).toBeNear(1.32, 0.02)
	end)

	T.it("fixed hooks never grow, the grown value does", function()
		local sword = ItemRoll.itemStats(plain("sword1h_50", Rarities.COMMON)).hooks
		T.expect(sword.riposte).toBe(10)
		T.expect(sword.counterDamage).toBe(33) -- S88: 25 -> 33
		local swordMyth = ItemRoll.itemStats(plain("sword1h_50", Rarities.MYTHIC, 9)).hooks
		T.expect(swordMyth.riposte).toBe(10)
		T.expect(swordMyth.counterDamage).toBeNear(62, 0.5)
		local shield = ItemRoll.itemStats(plain("shield_50", Rarities.COMMON)).hooks
		T.expect(shield.block).toBe(5)
		T.expect(shield.blockHeal).toBe(0.1) -- S88: 0.5 -> 0.1 (one decimal in the tooltip)
		local shieldMyth = ItemRoll.itemStats(plain("shield_50", Rarities.MYTHIC, 9)).hooks
		T.expect(shieldMyth.block).toBe(5)
		T.expect(shieldMyth.blockHeal).toBeNear(0.19, 0.01)
		T.expect(ItemRoll.itemStats(plain("sword2h_50", Rarities.COMMON)).hooks.traitExecute).toBe(18)
		T.expect(ItemRoll.itemStats(plain("crossbow_50", Rarities.COMMON)).hooks.controlledDamage).toBe(9) -- S88: 10 -> 9
	end)

	T.it("trait params match the code's constants", function()
		local swordplay = ItemTraits.get("swordplay") :: any
		T.expect(swordplay.fixedHooks.riposte).toBe(swordplay.params.chance)
		local parry = ItemTraits.get("parry") :: any
		T.expect(parry.fixedHooks.block).toBe(parry.params.chance)
		T.expect((ItemTraits.get("beheading") :: any).params.threshold).toBeNear(Combat.lowHpFraction * 100)
		local byHook = ItemTraits.pvpByHook
		for _, id in { "counterDamage", "blockHeal", "traitExecute", "controlledDamage" } do
			T.expect({ id, byHook[id] }).toEqual({ id, 0.5 })
		end
		T.expect(byHook.killHeal).toBe(0)
	end)
end)

T.describe("S65 rhythm and player-state traits", function()
	local function plain(defId: string, rarity: number, up: number?): any
		return {
			uid = uid(),
			id = defId,
			rarity = rarity,
			ilvl = (Items.get(defId) :: any).level,
			bonuses = {},
			up = up or 0,
			bound = false,
			n = 1,
			rv = Rarities.RV,
		}
	end

	-- S88: Twin Cut 40 -> 58, Run Through 25 -> 55, Full Draw 30 -> 45, Elemental Might 30 -> 39, Runic Seal 8 -> 5.5,
	-- Saving Blow 4 -> 2.5, the Spark's Frostbite 6 -> 11
	local GROWN = {
		{ "saber1h_50", "traitTwinCut", 58 },
		{ "spear2h_50", "traitRunThrough", 55 },
		{ "quiver_50", "traitFullDraw", 45 },
		{ "wand_50", "traitSpark", 35 },
		{ "staff_50", "elementRider", 39 },
		{ "runestaff_50", "traitRuneSeal", 5.5 },
		{ "holystaff_50", "traitSavingBlow", 2.5 },
	}
	local FIXED = {
		{ "wand_50", "frostbite", 11 },
		{ "staff_50", "frostbite", 10 },
		{ "staff_50", "riderSameTarget", 1 },
	}

	T.it("Common +0 hooks and fixed hooks", function()
		for _, row in GROWN do
			local hooks = ItemRoll.itemStats(plain(row[1], Rarities.COMMON)).hooks
			T.expect({ row[1], row[2], hooks[row[2]] }).toEqual({ row[1], row[2], row[3] })
		end
		for _, row in FIXED do
			local hooks = ItemRoll.itemStats(plain(row[1], Rarities.COMMON)).hooks
			T.expect({ row[1], row[2], hooks[row[2]] }).toEqual({ row[1], row[2], row[3] })
		end
	end)

	T.it("Mythic +9 grows the trait value, never the fixed hooks", function()
		for _, row in GROWN do
			local hooks = ItemRoll.itemStats(plain(row[1], Rarities.MYTHIC, 9)).hooks
			T.expect(hooks[row[2]] / row[3]).toBeNear(1.88, 0.02)
		end
		for _, row in FIXED do
			local hooks = ItemRoll.itemStats(plain(row[1], Rarities.MYTHIC, 9)).hooks
			T.expect({ row[1], row[2], hooks[row[2]] }).toEqual({ row[1], row[2], row[3] })
		end
	end)

	T.it("an old wand gets Elemental Spark without a migration", function()
		local wand = plain("wand_50", Rarities.COMMON)
		wand.rv = 2
		Rarities.upgradeItem(wand, Items.get(wand.id))
		local stats = ItemRoll.itemStats(wand)
		T.expect((stats.trait :: any).id).toBe("elementalSpark")
		T.expect(stats.hooks.traitSpark).toBe(35)
		T.expect(stats.hooks.frostbite).toBe(11) -- S88: 6 -> 11
	end)

	T.it("new lines sit in their pools", function()
		local function pools(id: string): { string }
			local out = {}
			for group, list in Bonuses.pools do
				if table.find(list, id) then
					table.insert(out, group)
				end
			end
			table.sort(out)
			return out
		end
		T.expect(pools("blockChance")).toEqual({ "shield" })
		T.expect(Bonuses.classStats.blockChance).toEqual({ "Warrior", "Cleric" })
		T.expect((Bonuses.get("blockChance") :: any).hook).toBe("block")
		T.expect(pools("meleeGuard")).toEqual({ "armor", "boots", "shield" })
		T.expect(pools("rangedGuard")).toEqual({ "armor", "helmet", "shield" })
		T.expect(pools("leg_cooldown")).toEqual({ "legendary" })
		T.expect(pools("myth_cooldown")).toEqual({ "mythic" })
		local leg = Bonuses.get("leg_cooldown") :: any
		local myth = Bonuses.get("myth_cooldown") :: any
		T.expect({ leg.tier, leg.hook }).toEqual({ "legendary", "cooldownReduction" })
		T.expect({ myth.tier, myth.hook }).toEqual({ "mythic", "cooldownReduction" })
		for _, classId in { "Warrior", "Cleric" } do
			local pool = ItemRoll.bonusPool("shield_50", classId)
			T.expect({ classId, #pool <= 14 }).toEqual({ classId, true }) -- S67: 14 with @resFamily
			T.expect({ classId, table.find(pool, "blockChance") ~= nil }).toEqual({ classId, true })
		end
	end)
end)

T.describe("S67 lines with a parameter", function()
	local Families = require("../src/shared/Data/Families")
	local Monsters = require("../src/shared/Data/Monsters")

	local function familyOf(stat: string): string?
		local def = Bonuses.get(stat) :: any
		return if def and def.param and Bonuses.params[def.param].over == "family" then def.of else nil
	end

	local function classLine(stat: string): boolean
		local def = Bonuses.get(stat) :: any
		return def ~= nil and def.param ~= nil and Bonuses.params[def.param].over == "class"
	end

	T.it("a drop's family picks the variant", function()
		local rng = Rng.new(1)
		local found = 0
		for _ = 1, 300 do
			local item =
				ItemRoll.rollItem("sword1h_30", 30, Rarities.HEROIC, rng, uid(), "Warrior", { family = "undead" })
			for _, bonus in item.bonuses do
				if familyOf(bonus.stat) then
					T.expect(bonus.stat).toBe("vs_undead")
					found += 1
				end
			end
		end
		T.expect(found > 0).toBe(true)
	end)

	T.it("no context rolls a random family, never a marker", function()
		local rng = Rng.new(2)
		local families: { [string]: boolean } = {}
		local count = 0
		for _ = 1, 600 do
			local item = ItemRoll.rollItem("necklace_30", 30, Rarities.HEROIC, rng, uid(), "Mage")
			for _, bonus in item.bonuses do
				T.expect(Bonuses.get(bonus.stat) ~= nil).toBe(true)
				T.expect(string.sub(bonus.stat, 1, 1) ~= "@").toBe(true)
				local family = familyOf(bonus.stat)
				if family then
					if not families[family] then
						count += 1
					end
					families[family] = true
				end
			end
		end
		T.expect(count >= 2).toBe(true)
		for _ = 1, 300 do
			local item = ItemRoll.rollItem("necklace_30", 30, Rarities.HEROIC, rng, uid(), "Mage", { family = "nope" })
			for _, bonus in item.bonuses do
				T.expect(Bonuses.get(bonus.stat) ~= nil).toBe(true)
				local family = familyOf(bonus.stat)
				if family then
					T.expect(Families.get(family) ~= nil).toBe(true)
				end
			end
		end
	end)

	T.it("markers sit only in their pools; class lines only on rings and talismans", function()
		local expected = {
			["@vsFamily"] = { "necklace", "weapon" },
			["@resFamily"] = { "armor", "helmet", "shield", "talisman" },
			["@vsClass"] = { "ring", "talisman" },
			["@resClass"] = { "ring", "talisman" },
		}
		for marker, groups in expected do
			local found: { string } = {}
			for group, pool in Bonuses.pools do
				if table.find(pool, marker) then
					table.insert(found, group)
				end
			end
			table.sort(found)
			T.expect({ marker, found }).toEqual({ marker, groups })
		end
		local rng = Rng.new(3)
		for _ = 1, 300 do
			local item = ItemRoll.rollItem("armor_heavy_30", 30, Rarities.HEROIC, rng, uid(), "Warrior")
			for _, bonus in item.bonuses do
				T.expect(classLine(bonus.stat)).toBe(false)
			end
		end
		local classLines = 0
		for _ = 1, 300 do
			local item = ItemRoll.rollItem("ring_30", 30, Rarities.HEROIC, rng, uid(), "Warrior")
			for _, bonus in item.bonuses do
				if classLine(bonus.stat) then
					classLines += 1
				end
			end
		end
		T.expect(classLines > 0).toBe(true)
	end)

	T.it("monster loot carries the monster's family", function()
		local family = (Monsters.get("skeletonGuard") :: any).family
		T.expect(family ~= nil).toBe(true)
		local loot = Loot.rollMonsterLoot("skeletonGuard", "normal", 40, Rng.new(9), { dropBonus = 100000 })
		T.expect(#loot.items > 0).toBe(true)
		for _, drop in loot.items do
			T.expect(drop.family).toBe(family)
		end
	end)
end)

-- S81: STATY 3, column "Klasa, ścieżka", against Logic/Paths.weaponOk for every class with paths.
T.describe("S81 weapon types per path (STATY 3)", function()
	local Classes = require("../src/shared/Data/Classes")
	local PathData = require("../src/shared/Data/Paths")
	local GamePaths = require("../src/shared/Logic/Paths")

	-- mirror of docs/STATY.md section 3, column "Klasa, ścieżka"
	local STATY3_PATHS: { [string]: { string } } = {
		sword1h = { "guardian", "standard" },
		saber1h = { "guardian", "standard" },
		axe1h = { "guardian" },
		mace1h = { "guardian", "inquisitor", "fortune" },
		sword2h = { "berserker" },
		axe2h = { "berserker" },
		hammer2h = { "berserker" },
		spear2h = { "berserker" },
		shield = { "guardian", "standard", "healer", "inquisitor" },
		shortbow = { "scout" },
		bow = { "trapper", "scout" },
		longbow = { "marksman" },
		crossbow = { "trapper" },
		heavycrossbow = { "marksman" },
		quiver = { "marksman", "trapper", "scout" },
		wand = { "destroyer", "arcanist" },
		staff = { "destroyer" },
		runestaff = { "arcanist" },
		tome = { "arcanist" },
		orb = { "destroyer" },
		scepter = { "healer", "fortune" },
		holystaff = { "healer" },
		flail1h = { "inquisitor", "fortune" },
		relic = { "fortune", "inquisitor", "healer" },
	}

	T.it("every weapon and off-hand type fits exactly the paths of STATY 3", function()
		local computed: { [string]: { [string]: boolean } } = {}
		local function add(t: string, pathId: string)
			computed[t] = computed[t] or {}
			computed[t][pathId] = true
		end
		for _, path in PathData.list do
			local class = Classes.get(path.class) :: any
			for _, t in class.weaponTypes do
				local fits = GamePaths.weaponOk(path.weapon, { main = t })
				if not GamePaths.isTwoHanded(t) then
					for _, o in class.offhandTypes do
						fits = fits or GamePaths.weaponOk(path.weapon, { main = t, offhand = o })
					end
				end
				if fits then
					add(t, path.id)
				end
			end
			for _, o in class.offhandTypes do
				for _, t in class.weaponTypes do
					if not GamePaths.isTwoHanded(t) and GamePaths.weaponOk(path.weapon, { main = t, offhand = o }) then
						add(o, path.id)
					end
				end
			end
		end
		local count = 0
		for t, want in STATY3_PATHS do
			count += 1
			local set: { [string]: boolean } = {}
			for _, id in want do
				set[id] = true
			end
			T.expect({ t, computed[t] or {} }).toEqual({ t, set })
		end
		for t in computed do
			T.expect({ t, STATY3_PATHS[t] ~= nil }).toEqual({ t, true })
		end
		T.expect(count).toBe(24)
	end)
end)

return nil
