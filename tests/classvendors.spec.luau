--!strict
-- S95 (DESIGN-15 §1): class vendors instead of the shared weaponsmith, the dealer in the armoury, the class lock, shop
-- gear always weaker than any Unique of the same item (I1) and shop armour = the blacksmith's recipe (I2).
local Bonuses = require("../src/shared/Data/Bonuses")
local Classes = require("../src/shared/Data/Classes")
local Crafting = require("../src/shared/Data/Crafting")
local Elements = require("../src/shared/Data/Elements")
local Families = require("../src/shared/Data/Families")
local ItemName = require("../src/shared/Logic/ItemName")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemScore = require("../src/shared/Logic/ItemScore")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Items = require("../src/shared/Data/Items")
local Npcs = require("../src/shared/Data/Npcs")
local PathData = require("../src/shared/Data/Paths")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local ShopPrice = require("../src/shared/Logic/ShopPrice")
local Shops = require("../src/shared/Data/Shops")
local StarterGear = require("../src/shared/Logic/StarterGear")
local T = require("./Test")
local Town = require("../src/shared/Data/Town")
local Types = require("../src/shared/Types")

type ItemInstance = Types.ItemInstance

local VENDORS: { { id: string, class: string, at: string } } = {
	{ id = "vendor_warrior", class = "Warrior", at = "donzon" },
	{ id = "vendor_cleric", class = "Cleric", at = "swiatynia" },
	{ id = "vendor_hunter", class = "Hunter", at = "loza" },
	{ id = "vendor_mage", class = "Mage", at = "wieza" },
}

local GEAR_SLOTS: { [string]: boolean } =
	{ weapon = true, offhand = true, helmet = true, armor = true, gloves = true, boots = true }

-- The item ShopService.buy hands out for an entry (S94 signature: no class, no context; the entry's element).
local function shopItem(entry: Shops.Entry, seed: number?): ItemInstance
	local item = ItemRoll.rollItem(entry.item, entry.ilvl :: number, Rarities.COMMON, Rng.new(seed or 1), "t")
	item.el = entry.el
	return item
end

local function contexts(classId: string, level: number): { ItemScore.Context }
	local list: { ItemScore.Context } = { { classId = classId, level = level } }
	for _, path in PathData.byClass[classId] or {} do
		table.insert(list, { classId = classId, level = level, pathId = path.id })
	end
	return list
end

-- Every line a Unique of `defId` can roll (any class it can drop for), markers expanded to every variant.
local function uniqueLines(defId: string): { { pool: string, ids: { string } } }
	local def = Items.get(defId) :: Items.ItemDef
	local seen: { [string]: boolean } = {}
	local out: { { pool: string, ids: { string } } } = {}
	local function addPool(forClass: string?)
		for id in ItemRoll.poolWeights(defId, forClass) do
			if seen[id] then
				continue
			end
			seen[id] = true
			local ids: { string } = {}
			if Bonuses.isParam(id) then
				local param = Bonuses.params[id]
				if param.over == "family" then
					for _, family in Families.ids do
						table.insert(ids, Bonuses.familyLine(param.prefix, family))
					end
				else
					for _, classId in Classes.order do
						table.insert(ids, Bonuses.classLine(param.prefix, classId))
					end
				end
			else
				table.insert(ids, id)
			end
			table.insert(out, { pool = id, ids = ids })
		end
	end
	addPool(nil)
	for _, classId in def.classes or {} do
		addPool(classId)
	end
	return out
end

-- The weakest possible Unique of the same item (base, ilvl, element) for `ctx`: Unique base stats and trait, and the
-- two pool entries with the lowest contribution to the score (each at its lowest value). The pool is the union over
-- every class the base can drop for, so the result is a lower bound of every real Unique.
local function worstUnique(entry: Shops.Entry, ctx: ItemScore.Context): (ItemInstance, number)
	local base = shopItem(entry)
	base.rarity = Rarities.UNIQUE
	base.bonuses = {}
	local s0 = ItemScore.score(base, ctx)
	local best: { { contrib: number, line: Types.Bonus } } = {}
	for _, candidate in uniqueLines(entry.item) do
		local low: { contrib: number, line: Types.Bonus }? = nil
		for _, id in candidate.ids do
			for _, roll in { 0, 1 } do
				local line = { stat = id, v = ItemRoll.rollBonusValue(id, base.ilvl, Rarities.UNIQUE, roll) }
				local probe = table.clone(base)
				probe.bonuses = { line }
				local contrib = ItemScore.score(probe, ctx) - s0
				if not low or contrib < low.contrib then
					low = { contrib = contrib, line = line }
				end
			end
		end
		if low then
			table.insert(best, low)
		end
	end
	table.sort(best, function(a, b)
		return a.contrib < b.contrib
	end)
	local lines = Rarities.get(Rarities.UNIQUE).bonusMin
	local worst = table.clone(base)
	worst.bonuses = {}
	for i = 1, math.min(lines, #best) do
		table.insert(worst.bonuses, best[i].line)
	end
	return worst, ItemScore.score(worst, ctx)
end

-- Ties allowed by I1 (S95, DECYZJE): { item key, context, why }. Heavy gloves of tier 5: armour 7 and HP 9 for Common
-- and Unique after rounding (baseMul 1.05), and the two weakest lines of the shared Warrior / Cleric pool (magic
-- lines for the Warrior, physical ones for the Cleric) weigh 0 for that class.
local TIE_GLOVES_5 = "heavy gloves of tier 5: same rounded armour / HP, weakest Unique lines weigh 0 for the class"
local TIE_OK: { { key: string, ctx: string, why: string } } = {}
for _, ctx in { "Warrior", "guardian", "berserker", "standard", "Cleric", "healer", "fortune", "inquisitor" } do
	table.insert(TIE_OK, { key = "gloves_heavy_5", ctx = ctx, why = TIE_GLOVES_5 })
end

local function tieAllowed(key: string, ctxName: string): boolean
	for _, tie in TIE_OK do
		if tie.key == key and tie.ctx == ctxName then
			return true
		end
	end
	return false
end

T.describe("Class vendors (S95)", function()
	T.it("each vendor stands by its building in the city and sells its class's gear", function()
		for _, v in VENDORS do
			local npc = Npcs.get(v.id) :: Npcs.NpcDef
			T.expect(npc ~= nil).toBe(true)
			T.expect(npc.map).toBe("city")
			T.expect(npc.shop).toBe(v.id)
			T.expect(table.find(npc.services, "shop") ~= nil).toBe(true)
			local spot = Town.npcSpot(v.id)
			T.expect(spot and spot.at).toBe(v.at)
			T.expect((Shops.get(v.id) :: Shops.ShopDef).class).toBe(v.class)
		end
	end)

	T.it("CLASS_VENDORS maps every class to its vendor", function()
		local n = 0
		for _ in Shops.CLASS_VENDORS do
			n += 1
		end
		T.expect(n).toBe(#Classes.order)
		for _, classId in Classes.order do
			local id = Shops.vendorOf(classId) :: string
			T.expect(Shops.CLASS_VENDORS[classId]).toBe(id)
			T.expect((Shops.get(id) :: Shops.ShopDef).class).toBe(classId)
		end
		T.expect(Shops.vendorOf("Bard")).toBeNil()
		T.expect(Shops.vendorOf(nil)).toBeNil()
	end)

	T.it("sells exactly tiers 5..95, Common, ilvl = level, only what the class can wear, unique keys", function()
		T.expect(Shops.WEAPONSMITH_TIERS).toEqual({ 5, 15, 25, 35, 45, 55, 65, 75, 85, 95 })
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			local seen: { [string]: boolean } = {}
			for _, entry in shop.entries do
				local def = Items.get(entry.item) :: Items.ItemDef
				T.expect(def ~= nil).toBe(true)
				T.expect(GEAR_SLOTS[def.slot or ""]).toBe(true)
				T.expect(table.find(Shops.WEAPONSMITH_TIERS, entry.ilvl :: number) ~= nil).toBe(true)
				T.expect(entry.level).toBe(entry.ilvl)
				T.expect(entry.rarity).toBe(Rarities.COMMON)
				T.expect(entry.price).toBeNil()
				T.expect(entry.classes ~= nil and table.find(entry.classes, v.class) ~= nil).toBe(true)
				T.expect(def.classes ~= nil and table.find(def.classes, v.class) ~= nil).toBe(true)
				local key = entry.key or entry.item
				T.expect(seen[key]).toBeNil()
				seen[key] = true
			end
		end
	end)

	T.it("every base of the six slots the class can wear is sold at every tier", function()
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			local sold: { [string]: boolean } = {}
			for _, entry in shop.entries do
				sold[entry.item] = true
			end
			for _, base in Items.bases.list do
				if GEAR_SLOTS[base.slot] and base.classes and table.find(base.classes, v.class) then
					for _, tier in Shops.WEAPONSMITH_TIERS do
						if not sold[`{base.type}_{tier}`] then
							error(`{v.id} misses {base.type}_{tier}`)
						end
					end
				end
			end
		end
	end)

	T.it("armour weights per class: Cleric heavy and light, Hunter medium, Mage light, Warrior heavy", function()
		local expected: { [string]: { [string]: boolean } } = {
			vendor_warrior = { heavy = true },
			vendor_cleric = { heavy = true, light = true },
			vendor_hunter = { medium = true },
			vendor_mage = { light = true },
		}
		for id, weights in expected do
			local found: { [string]: boolean } = {}
			for _, entry in (Shops.get(id) :: Shops.ShopDef).entries do
				local weight = string.match(entry.item, "^armor_(%a+)_%d+$")
				if weight then
					found[weight] = true
				end
			end
			T.expect(found).toEqual(weights)
		end
	end)

	T.it("mage weapons come in every element", function()
		local wand: { [string]: boolean } = {}
		for _, entry in (Shops.get("vendor_mage") :: Shops.ShopDef).entries do
			if entry.item == "wand_15" then
				wand[entry.el or "none"] = true
			end
		end
		for _, element in Elements.WEAPON do
			T.expect(wand[element]).toBe(true)
		end
		T.expect(wand.none).toBeNil()
	end)

	T.it("prices: value x buyMul, the same as ShopPrice.unit", function()
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			for _, entry in shop.entries do
				T.expect(ItemValue.buyPrice(entry, shop))
					.toBe(math.floor(ItemValue.entryValue(entry) * ItemValue.BUY_MUL + 0.5))
				T.expect(ShopPrice.unit(entry, 1, 0, shop)).toBe(ItemValue.buyPrice(entry, shop))
			end
		end
	end)

	T.it("ShopPrice.usableBy: free entries for all, gear only for its classes", function()
		T.expect(ShopPrice.usableBy({ item = "potion_hp_1" }, "Mage")).toBe(true)
		T.expect(ShopPrice.usableBy({ item = "potion_hp_1" }, nil)).toBe(true)
		local plate: Shops.Entry = { item = "armor_heavy_15", classes = { "Warrior", "Cleric" } }
		T.expect(ShopPrice.usableBy(plate, "Warrior")).toBe(true)
		T.expect(ShopPrice.usableBy(plate, "Cleric")).toBe(true)
		T.expect(ShopPrice.usableBy(plate, "Mage")).toBe(false)
		T.expect(ShopPrice.usableBy(plate, nil)).toBe(false)
	end)

	T.it("the dealer buys and sells back, points to the vendors; the weaponsmith is gone", function()
		local fence = Shops.get("fence") :: Shops.ShopDef
		T.expect(fence ~= nil).toBe(true)
		T.expect(#fence.entries).toBe(0)
		T.expect(fence.class).toBeNil()
		local npc = Npcs.get("fence") :: Npcs.NpcDef
		T.expect(npc.shop).toBe("fence")
		T.expect(npc.services).toEqual({ "shop", "vendors" })
		T.expect((Town.npcSpot("fence") :: any).at).toBe("zbrojownia")
		T.expect(Npcs.get("weaponsmith")).toBeNil()
		T.expect(Shops.get("weaponsmith")).toBeNil()
	end)
end)

T.describe("Shop gear is weaker than any Unique (DESIGN-15 §1)", function()
	T.it("Common shop items have fixed stats (two seeds, the same item)", function()
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			for i = 1, #shop.entries, 7 do
				local entry = shop.entries[i]
				local a, b = shopItem(entry, 1), shopItem(entry, 99)
				T.expect(#a.bonuses).toBe(0)
				T.expect(ItemRoll.itemStats(a).flat).toEqual(ItemRoll.itemStats(b).flat)
				T.expect(ItemRoll.itemStats(a).weapon).toEqual(ItemRoll.itemStats(b).weapon)
			end
		end
	end)

	T.it("every entry, class and path context: score(shop) < score(worst Unique of the same item)", function()
		local fails: { string } = {}
		local tiesHit: { [string]: boolean } = {}
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			for _, entry in shop.entries do
				local item = shopItem(entry)
				for _, ctx in contexts(v.class, entry.level :: number) do
					local ctxName = ctx.pathId or v.class
					local shopScore = ItemScore.score(item, ctx)
					local _, worst = worstUnique(entry, ctx)
					local key = entry.key or entry.item
					local diff = worst - shopScore
					if diff < -1e-9 then
						-- A shop advantage is always an error, TIE_OK or not.
						table.insert(fails, `{v.id} {key} {ctxName}: shop {shopScore} beats Unique {worst}`)
					elseif diff <= 1e-9 then
						if tieAllowed(key, ctxName) then
							tiesHit[`{key}|{ctxName}`] = true
						else
							table.insert(fails, `{v.id} {key} {ctxName}: shop {shopScore} ties Unique {worst}`)
						end
					end
				end
			end
		end
		for _, tie in TIE_OK do
			T.expect(tie.why ~= "").toBe(true)
			if not tiesHit[`{tie.key}|{tie.ctx}`] then
				table.insert(fails, `stale TIE_OK: {tie.key} {tie.ctx} is no longer an exact tie`)
			end
		end
		if #fails > 0 then
			error(`{#fails} shop items not weaker than the worst Unique:\n` .. table.concat(fails, "\n"))
		end
	end)

	T.it("the worst Unique is really the lowest (200 rolled Uniques of 3 entries per shop)", function()
		local pick = Rng.new(95)
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			for _ = 1, 3 do
				local entry = shop.entries[pick:int(1, #shop.entries)]
				local ctxs = contexts(v.class, entry.level :: number)
				local floors: { number } = {}
				for i, ctx in ctxs do
					local _, worst = worstUnique(entry, ctx)
					floors[i] = worst
				end
				local def = Items.get(entry.item) :: Items.ItemDef
				local classes = def.classes or {}
				for seed = 1, 200 do
					-- Index 0 rolls the unbiased pool (forClass = nil), the rest each item class.
					local k = seed % (#classes + 1)
					local forClass: string? = if k == 0 then nil else classes[k]
					local rolled = ItemRoll.rollItem(
						entry.item,
						entry.ilvl :: number,
						Rarities.UNIQUE,
						Rng.new(seed),
						"u",
						forClass
					)
					rolled.el = entry.el
					for i, ctx in ctxs do
						if ItemScore.score(rolled, ctx) < floors[i] - 1e-9 then
							error(`{entry.key or entry.item} seed {seed}: rolled Unique below the worst one`)
						end
					end
				end
			end
		end
	end)
end)

T.describe("Shop armour = the blacksmith's recipe (S95 I2)", function()
	T.it("same stats as the crafted Common, price >= the recipe's gold", function()
		for _, v in VENDORS do
			local shop = Shops.get(v.id) :: Shops.ShopDef
			for _, entry in shop.entries do
				local def = Items.get(entry.item) :: Items.ItemDef
				if def.slot == "weapon" or def.slot == "offhand" then
					continue
				end
				local recipe = Crafting.get(entry.item) :: Crafting.Recipe
				T.expect(recipe ~= nil).toBe(true)
				T.expect(recipe.level).toBe(entry.ilvl)
				local crafted = ItemRoll.rollItem(recipe.item, recipe.level, Rarities.COMMON, Rng.new(5), "c")
				T.expect(ItemRoll.itemStats(shopItem(entry)).flat).toEqual(ItemRoll.itemStats(crafted).flat)
				T.expect(ShopPrice.unit(entry, 1, 0, shop) >= recipe.gold).toBe(true)
			end
		end
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
