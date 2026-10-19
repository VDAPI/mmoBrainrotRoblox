--!strict
-- S154: item looks (Logic/Transmog, docs/DESIGN.md §6b). Only held types (weapons and off-hands with a Part look), one
-- look key per model (boss model, tier model, one Part look per type), the checks of putting a look on, the cost on the
-- upgrade gold curve with essence by rarity, and the rule that a look never changes the item (stats, score, pool).

local Config = require("../src/shared/Config")
local ItemIcons = require("../src/shared/Logic/ItemIcons")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemScore = require("../src/shared/Logic/ItemScore")
local Items = require("../src/shared/Data/Items")
local Rarities = require("../src/shared/Data/Rarities")
local SkillPools = require("../src/shared/Logic/SkillPools")
local StatCalc = require("../src/shared/Logic/StatCalc")
local T = require("./Test")
local Transmog = require("../src/shared/Logic/Transmog")
local Upgrade = require("../src/shared/Logic/Upgrade")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")

local function item(defId: string, ilvl: number, rarity: number, extra: { [string]: any }?): any
	local out: any = {
		uid = "u1",
		id = defId,
		rarity = rarity,
		ilvl = ilvl,
		bonuses = { { stat = "str", v = 5 }, { stat = "critChance", v = 2 }, { stat = "vs_undead", v = 6 } },
		up = 4,
		bound = true,
		n = 1,
		rv = Rarities.RV,
		locked = true,
		fx = { "fx_a" },
		rr = { i = 2, n = 3 },
	}
	for k, v in extra or {} do
		out[k] = v
	end
	return out
end

local function def(id: string): Items.ItemDef
	return Items.get(id) :: Items.ItemDef
end

-- A type of the held list whose lowest tier has no model would give the "<type>" key; the data may have none.
local function partLookType(): string?
	for _, itemType in Transmog.SLOTS do
		if Transmog.lookOf(def(`{itemType}_1`)) == itemType then
			return itemType
		end
	end
	return nil
end

T.describe("Transmog: held types (S154 A1)", function()
	T.it("weapons and off-hands yes, armour, jewellery, backpacks and materials no", function()
		for _, id in { "sword1h_1", "bow_45", "staff_70", "shield_20", "quiver_5", "tome_100", "orb_1", "relic_50" } do
			T.expect({ id, Transmog.supports(def(id)) }).toEqual({ id, true })
		end
		for _, id in { "armor_heavy_1", "helmet_light_20", "ring_1", "necklace_1", "backpack_20", "ore_copper" } do
			T.expect({ id, Transmog.supports(Items.get(id)) }).toEqual({ id, false })
		end
		T.expect(Transmog.supports(nil)).toBe(false)
	end)

	T.it("SLOTS are exactly the base types with a Part look", function()
		local expected: { [string]: boolean } = {}
		for _, base in Items.bases.list do
			if WeaponLooks.get(base.type) and (base.slot == "weapon" or base.slot == "offhand") then
				expected[base.type] = true
			end
		end
		local got: { [string]: boolean } = {}
		for _, itemType in Transmog.SLOTS do
			got[itemType] = true
		end
		T.expect(got).toEqual(expected)
		T.expect(#Transmog.SLOTS >= 20).toBe(true)
	end)
end)

T.describe("Transmog: look keys (S154 A2-A4)", function()
	T.it("a boss item with its own model is its own look, marked as a boss look", function()
		T.expect(Transmog.lookOf(def("unique_grimrok_cleaver"))).toBe("unique_grimrok_cleaver")
		T.expect(Transmog.isBoss("unique_grimrok_cleaver")).toBe(true)
		T.expect(Transmog.lookType("unique_grimrok_cleaver")).toBe("axe1h")
		T.expect((Transmog.lookDef("unique_grimrok_cleaver") :: any).id).toBe("unique_grimrok_cleaver")
	end)

	T.it("a boss item without a model takes the tier model of its type (not a boss look)", function()
		local key = Transmog.lookOf(def("unique_morvane_scepter"))
		T.expect(key).toBe("scepter_20")
		T.expect(Transmog.isBoss(key)).toBe(false)
	end)

	T.it("generated items take the nearest lower tier model; one key per model", function()
		T.expect(Transmog.lookOf(def("sword1h_1"))).toBe("sword1h_1")
		T.expect(Transmog.lookOf(def("sword1h_15"))).toBe("sword1h_15")
		T.expect(Transmog.lookOf(def("sword1h_45"))).toBe("sword1h_20")
		T.expect(Transmog.lookOf(def("sword1h_100"))).toBe("sword1h_20")
		T.expect(Transmog.lookType("sword1h_20")).toBe("sword1h")
		T.expect((Transmog.lookDef("sword1h_20") :: any).id).toBe("sword1h_20")
		T.expect(Transmog.isBoss("sword1h_20")).toBe(false)
		-- a tier without its own model is no look key
		T.expect(Transmog.lookType("sword1h_45")).toBeNil()
		T.expect(Transmog.lookType("armor_heavy_1")).toBeNil()
		T.expect(Transmog.lookType("nothing")).toBeNil()
	end)

	T.it("without any model the Part look is one key per type, drawn as the lowest tier", function()
		local itemType = partLookType()
		if itemType then
			T.expect(Transmog.lookType(itemType)).toBe(itemType)
			T.expect((Transmog.lookDef(itemType) :: any).id).toBe(`{itemType}_1`)
		end
		-- the rule itself: a definition whose type has no model at or below its tier
		local fake: any = table.clone(def("sword1h_1"))
		fake.id = "test_partlook"
		fake.type = "test_type"
		T.expect(Transmog.lookOf(fake)).toBe("test_type")
	end)

	T.it("every look of the catalogue is valid, of its type, and the catalogue covers every held item", function()
		local base, boss = 0, 0
		for _, entry in Transmog.catalogue() do
			for _, key in entry.base do
				T.expect({ key, Transmog.lookType(key) }).toEqual({ key, entry.type })
				T.expect({ key, Transmog.isBoss(key) }).toEqual({ key, false })
				base += 1
			end
			for _, key in entry.boss do
				T.expect({ key, Transmog.lookType(key) }).toEqual({ key, entry.type })
				T.expect({ key, Transmog.isBoss(key) }).toEqual({ key, true })
				boss += 1
			end
		end
		for _, d in Items.byId do
			if Transmog.supports(d) then
				local key = Transmog.lookOf(d)
				T.expect({ d.id, table.find(Transmog.looksOf(d.type), key) ~= nil }).toEqual({ d.id, true })
			end
		end
		T.expect(base >= #Transmog.SLOTS).toBe(true)
		T.expect(boss >= 1).toBe(true)
	end)

	T.it("unlocks lists the look of each held item once", function()
		local keys = Transmog.unlocks({
			item("sword1h_45", 45, Rarities.HEROIC),
			item("sword1h_50", 50, Rarities.UNIQUE),
			item("armor_heavy_20", 20, Rarities.COMMON),
			item("unique_grimrok_cleaver", 20, Rarities.MYTHIC),
			item("shield_5", 5, Rarities.COMMON),
		})
		table.sort(keys)
		T.expect(keys).toEqual({ "shield_5", "sword1h_20", "unique_grimrok_cleaver" })
	end)
end)

T.describe("Transmog: putting a look on (S154 A5, A7)", function()
	local looks = { sword1h_1 = true, sword1h_10 = true, unique_grimrok_cleaver = true, bow_5 = true }

	T.it("refuses other types, locked looks, another type's look and the same look", function()
		T.expect({ Transmog.canApply(item("armor_heavy_20", 20, 2), "sword1h_1", looks) }).toEqual({
			false,
			"transmog.error.type",
		})
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "sword1h_5", looks) }).toEqual({
			false,
			"transmog.error.locked",
		})
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "nothing", looks) }).toEqual({
			false,
			"transmog.error.locked",
		})
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "sword1h_1", nil) }).toEqual({
			false,
			"transmog.error.locked",
		})
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "bow_5", looks) }).toEqual({
			false,
			"transmog.error.mismatch",
		})
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "unique_grimrok_cleaver", looks) }).toEqual({
			false,
			"transmog.error.mismatch",
		})
		-- its own look is taken off with "", never put on
		T.expect({ Transmog.canApply(item("sword1h_10", 10, 3), "sword1h_10", looks) }).toEqual({
			false,
			"transmog.error.same",
		})
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3, { tm = "sword1h_1" }), "sword1h_1", looks) }).toEqual({
			false,
			"transmog.error.same",
		})
	end)

	T.it("accepts an unlocked look of the type, a boss look of the type and always taking a look off", function()
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "sword1h_1", looks) }).toEqual({ true, nil })
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3, { tm = "sword1h_1" }), "sword1h_10", looks) }).toEqual({
			true,
			nil,
		})
		T.expect({ Transmog.canApply(item("axe1h_70", 70, 4), "unique_grimrok_cleaver", looks) }).toEqual({ true, nil })
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3, { tm = "sword1h_1" }), "", {}) }).toEqual({ true, nil })
		T.expect({ Transmog.canApply(item("sword1h_45", 45, 3), "", nil) }).toEqual({ true, nil })
	end)

	T.it("apply changes only tm; '' removes it", function()
		local before = item("sword1h_45", 45, Rarities.LEGENDARY, { el = "fire", ns = true })
		local after = Transmog.apply(before, "sword1h_1")
		T.expect(after.tm).toBe("sword1h_1")
		T.expect(before.tm).toBeNil()
		local stripped = table.clone(after)
		stripped.tm = nil
		T.expect(stripped).toEqual(before)
		for _, field in Transmog.KEEP do
			T.expect({ field, (after :: any)[field] }).toEqual({ field, (before :: any)[field] })
		end
		local back = Transmog.apply(after, "")
		T.expect(back.tm).toBeNil()
		T.expect(back).toEqual(before)
	end)

	T.it("displayDef: the worn look, else the item's own (unknown key, other type, no tm)", function()
		T.expect((Transmog.displayDef(item("sword1h_45", 45, 3, { tm = "sword1h_1" })) :: any).id).toBe("sword1h_1")
		T.expect((Transmog.displayDef(item("axe1h_70", 70, 3, { tm = "unique_grimrok_cleaver" })) :: any).id)
			.toBe("unique_grimrok_cleaver")
		T.expect((Transmog.displayDef(item("sword1h_45", 45, 3)) :: any).id).toBe("sword1h_45")
		T.expect((Transmog.displayDef(item("sword1h_45", 45, 3, { tm = "bow_5" })) :: any).id).toBe("sword1h_45")
		T.expect((Transmog.displayDef(item("sword1h_45", 45, 3, { tm = "gone_model" })) :: any).id).toBe("sword1h_45")
		T.expect((Transmog.displayDef(item("sword1h_45", 45, 3, { tm = 5 })) :: any).id).toBe("sword1h_45")
		T.expect(Transmog.current(item("sword1h_45", 45, 3, { tm = "bow_5" }))).toBeNil()
		T.expect(Transmog.current(item("sword1h_45", 45, 3, { tm = "sword1h_10" }))).toBe("sword1h_10")
	end)
end)

T.describe("Transmog: icon of the worn look (S154 D2)", function()
	T.it("the slot icon is the look's icon (tier picture or boss picture), the item's own without a look", function()
		local withLook = item("sword1h_45", 45, 3, { tm = "sword1h_5" })
		T.expect(ItemIcons.candidates(Transmog.displayDef(withLook) :: any))
			.toEqual(ItemIcons.candidates(def("sword1h_5")))
		local boss = item("axe1h_70", 70, 3, { tm = "unique_grimrok_cleaver" })
		T.expect(ItemIcons.candidates(Transmog.displayDef(boss) :: any))
			.toEqual(ItemIcons.candidates(def("unique_grimrok_cleaver")))
		local plain = item("sword1h_45", 45, 3)
		T.expect(ItemIcons.candidates(Transmog.displayDef(plain) :: any))
			.toEqual(ItemIcons.candidates(def("sword1h_45")))
	end)
end)

T.describe("Transmog: cost (S154 A6)", function()
	T.it("gold on the upgrade gold curve x goldMul, growing with the item level", function()
		local last = 0
		for _, ilvl in { 1, 10, 20, 45, 70, 100 } do
			local cost = Transmog.cost(item("sword1h_1", ilvl, Rarities.HEROIC))
			T.expect(cost.gold).toBe(math.floor(ilvl * Upgrade.goldPerIlvl(ilvl) * Config.Transmog.goldMul + 0.5))
			T.expect(cost.gold > last).toBe(true)
			last = cost.gold
		end
	end)

	T.it("essence by the item's rarity, Common none; a boss look costs the same", function()
		T.expect(Transmog.cost(item("sword1h_1", 20, Rarities.COMMON)).materials).toEqual({})
		T.expect(Transmog.cost(item("sword1h_1", 20, Rarities.UNIQUE)).materials).toEqual({
			{ id = "essence_dust", n = 2 },
		})
		T.expect(Transmog.cost(item("sword1h_1", 20, Rarities.HEROIC)).materials).toEqual({
			{ id = "essence_shard", n = 1 },
		})
		T.expect(Transmog.cost(item("sword1h_1", 20, Rarities.LEGENDARY)).materials).toEqual({
			{ id = "essence_crystal", n = 1 },
		})
		T.expect(Transmog.cost(item("sword1h_1", 20, Rarities.MYTHIC)).materials).toEqual({
			{ id = "essence_crystal", n = 1 },
		})
		local axe = item("axe1h_20", 20, Rarities.HEROIC)
		T.expect(Transmog.cost(axe)).toEqual(Transmog.cost(Transmog.apply(axe, "unique_grimrok_cleaver")))
		for _, material in Transmog.cost(item("sword1h_1", 20, Rarities.MYTHIC)).materials do
			T.expect(Items.get(material.id) ~= nil).toBe(true)
		end
	end)
end)

T.describe("Transmog: account state (S154 A8)", function()
	T.it("sanitize keeps only existing looks and a true scanned flag", function()
		T.expect(Transmog.sanitize(nil)).toEqual({ looks = {}, scanned = false })
		T.expect(Transmog.sanitize({ looks = "x", scanned = 1 })).toEqual({ looks = {}, scanned = false })
		T.expect(Transmog.sanitize({
			looks = { sword1h_1 = true, sword1h_45 = true, gone = true, bow_5 = false, unique_grimrok_cleaver = true },
			scanned = true,
		})).toEqual({ looks = { sword1h_1 = true, unique_grimrok_cleaver = true }, scanned = true })
	end)

	T.it("count is n / all of a type", function()
		local n, all = Transmog.count("sword1h", { sword1h_1 = true, sword1h_5 = true, bow_5 = true })
		T.expect(n).toBe(2)
		T.expect(all).toBe(#Transmog.looksOf("sword1h"))
	end)
end)

T.describe("Transmog never changes power (S154 rule 4, A9)", function()
	local cases = {
		{ id = "sword1h_45", class = "Warrior", look = "sword1h_1" },
		{ id = "axe1h_70", class = "Warrior", look = "unique_grimrok_cleaver" },
		{ id = "staff_45", class = "Mage", look = "staff_5", el = "ice" },
		{ id = "bow_70", class = "Hunter", look = "bow_10" },
		{ id = "shield_45", class = "Warrior", look = "shield_1" },
	}

	T.it("itemStats, ItemScore and StatCalc are the same with and without the look", function()
		for _, case in cases do
			for _, rarity in { Rarities.COMMON, Rarities.HEROIC, Rarities.MYTHIC } do
				local plain = item(case.id, 45, rarity, { el = case.el })
				local looked = Transmog.apply(plain, case.look)
				T.expect(looked.tm).toBe(case.look)
				T.expect(ItemRoll.itemStats(looked)).toEqual(ItemRoll.itemStats(plain))
				T.expect(ItemRoll.requiredLevel(looked)).toBe(ItemRoll.requiredLevel(plain))
				T.expect(ItemScore.score(looked, case.class)).toBe(ItemScore.score(plain, case.class))
				T.expect(ItemScore.breakdown(looked, case.class)).toEqual(ItemScore.breakdown(plain, case.class))
				local function computed(source: any): StatCalc.Result
					local stats = ItemRoll.itemStats(source)
					return StatCalc.compute({
						level = 45,
						stats = { str = 40, dex = 30, int = 30, vit = 30 },
						sources = { { key = "source.gear", flat = stats.flat, pct = stats.pct } },
						weapon = stats.weapon :: any,
					})
				end
				T.expect(computed(looked)).toEqual(computed(plain))
			end
		end
	end)

	T.it("the weapon pool reads the item, never the look", function()
		local staff = item("staff_45", 45, Rarities.HEROIC, { el = "fire" })
		local sword = item("sword1h_45", 45, Rarities.HEROIC)
		local function poolOf(class: string, weapon: any): string?
			return SkillPools.activePool({ class = class, equipment = { weapon = weapon } })
		end
		T.expect(poolOf("Mage", Transmog.apply(staff, "staff_1"))).toBe(poolOf("Mage", staff))
		T.expect(poolOf("Warrior", Transmog.apply(sword, "sword1h_10"))).toBe(poolOf("Warrior", sword))
	end)
end)

return nil
