--!strict
-- S31: one value per item (Logic/ItemValue) and the tooltip content of every category (Logic/TooltipModel).
local Format = require("../src/shared/Util/Format")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Items = require("../src/shared/Data/Items")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local ShopPrice = require("../src/shared/Logic/ShopPrice")
local Shops = require("../src/shared/Data/Shops")
local T = require("./Test")
local TooltipModel = require("../src/shared/Logic/TooltipModel")
local ValueData = require("../src/shared/Data/ItemValue")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function sample(id: string, ilvl: number?, rarity: number?, up: number?): any
	local def = Items.get(id) :: Items.ItemDef
	local item: any = ItemRoll.rollItem(
		id,
		ilvl or def.level,
		rarity or def.rarity or Rarities.COMMON,
		Rng.new(7),
		`{id}:{ilvl or 0}`
	)
	if up then
		item.up = up
	end
	return item
end

local function roles(item: any, ctx: any?): { [string]: number }
	local found: { [string]: number } = {}
	for _, line in TooltipModel.build(item, nil, ctx or { lang = "pl" }).lines do
		found[line.role] = (found[line.role] or 0) + 1
	end
	return found
end

local function texts(item: any, ctx: any?): string
	local out = {}
	for _, line in TooltipModel.build(item, nil, ctx or { lang = "pl" }).lines do
		table.insert(out, TooltipModel.plain(line.text))
	end
	return table.concat(out, "\n")
end

T.describe("ItemValue (S31)", function()
	T.it("every item has a value > 0 and a localized category", function()
		for id, def in Items.byId do
			local item = sample(id)
			if ItemValue.value(item, def) <= 0 or def.price <= 0 then
				error(`{id}: no value`)
			end
			local key = TooltipModel.categoryKey(def)
			if pl[key] == nil or en[key] == nil then
				error(`{id}: category key {key} missing`)
			end
		end
	end)

	T.it("equipment follows the formula and grows with level, rarity and upgrade", function()
		local item = sample("sword1h_30", 30)
		T.expect(ItemValue.value(item)).toBe(math.floor(ValueData.perLevel * 30 + 0.5))
		local ring = sample("ring_30", 30)
		T.expect(ItemValue.value(ring)).toBe(math.floor(ValueData.perLevel * 30 * ValueData.slotMul.ring + 0.5))
		T.expect(ItemValue.value(sample("sword1h_30", 31)) > ItemValue.value(item)).toBe(true)
		local last = 0
		for rarity = Rarities.COMMON, Rarities.MAX do
			local v = ItemValue.value(sample("sword1h_30", 30, rarity))
			T.expect(v > last).toBe(true)
			last = v
		end
		T.expect(ItemValue.value(sample("sword1h_30", 30, 1, 3)) > ItemValue.value(item)).toBe(true)
		-- Named Mythic items: the same rule as a rolled Mythic of their level.
		for _, def in Items.uniques do
			local named = sample(def.id)
			T.expect(ItemValue.value(named)).toBe(ItemValue.equipment(def, named.ilvl, Rarities.MYTHIC, 0))
		end
	end)

	T.it("stacks are worth price x n, sell price = value, locked items cannot be sold", function()
		local dust = ItemRoll.makeStack("essence_dust", 10, "d")
		T.expect(ItemValue.value(dust)).toBe((Items.get("essence_dust") :: any).price * 10)
		T.expect(ItemRoll.sellPrice(dust)).toBe(ItemValue.value(dust))
		local item = sample("sword1h_30", 30)
		item.locked = true
		T.expect(ItemValue.canSell(item)).toBe(false)
		T.expect(ItemValue.sellPrice(item)).toBe(0)
		T.expect(roles(item).noSell).toBe(1)
	end)

	T.it("buy price = value x buyMul unless the entry or item has a fixed price", function()
		local entry: Shops.Entry = { item = "sword1h_25", ilvl = 25 }
		T.expect(ItemValue.buyPrice(entry)).toBe(math.floor(ItemValue.entryValue(entry) * ValueData.buyMul + 0.5))
		T.expect(ItemValue.buyPrice(entry, { id = "x", entries = {}, buyMul = 2 }))
			.toBe(ItemValue.entryValue(entry) * 2)
		T.expect(ItemValue.buyPrice({ item = "ore_iron", price = 60 })).toBe(60)
		T.expect(ItemValue.buyPrice({ item = "potion_hp_1" })).toBe((Items.get("potion_hp_1") :: any).buyPrice)
		T.expect(ItemValue.buyPrice({ item = "scroll_oblivion", pricePerLevel = 500 }, nil, 7)).toBe(3500)
		-- Buying from an NPC never pays off when sold back.
		for id, shop in Shops.byId do
			for _, e in shop.entries do
				if ItemValue.buyPrice(e, shop, 1) < ItemValue.entryValue(e) then
					error(`{id}: {e.key or e.item} sells below its value`)
				end
			end
		end
	end)

	T.it("the tooltip shop price is the row price (ShopPrice.unit)", function()
		local shop = Shops.get("weaponsmith") :: Shops.ShopDef
		for i = 1, #shop.entries, 37 do
			local entry = shop.entries[i]
			local item = ItemValue.entryItem(entry)
			local price = ShopPrice.unit(entry, 1, 0, shop)
			local found = false
			for _, line in TooltipModel.build(item, nil, { lang = "en", shop = shop, shopEntry = entry }).lines do
				if line.role == "price" then
					found = string.find(line.text, Format.number(price), 1, true) ~= nil
				end
			end
			T.expect(found).toBe(true)
		end
	end)
end)

T.describe("TooltipModel (S31)", function()
	T.it("every category has its stats or effect and the value line", function()
		local cases: { { id: string, role: string } } = {
			{ id = "sword1h_15", role = "dps" },
			{ id = "shield_15", role = "stat" },
			{ id = "helmet_heavy_15", role = "stat" },
			{ id = "ring_15", role = "stat" },
			{ id = "potion_hp_2", role = "effect" },
			{ id = "blessing_warrior_3", role = "duration" },
			{ id = "elixir_resFire", role = "duration" },
			{ id = "essence_dust", role = "usedFor" },
			{ id = "stone_return", role = "effect" },
			{ id = "stone_dungeon_meadows", role = "effect" },
			{ id = "scroll_protection", role = "effect" },
			{ id = "pickaxe", role = "effect" },
			{ id = "backpack_45", role = "effect" },
		}
		for _, case in cases do
			local found = roles(sample(case.id))
			if not found[case.role] or found.value ~= 1 or found.name ~= 1 or found.type ~= 1 then
				error(`{case.id}: missing {case.role} / value / header`)
			end
		end
	end)

	T.it("every item gets a value line and no raw keys in both languages", function()
		for id in Items.byId do
			for _, lang in { "pl", "en" } do
				local text = texts(sample(id), { lang = lang, merchantOpen = true })
				if not string.find(text, if lang == "pl" then "Wartość:" else "Value:", 1, true) then
					error(`{id}: no value line`)
				end
				if string.find(text, "tooltip%.") or string.find(text, "itemCat%.") then
					error(`{id}: raw key in {text}`)
				end
			end
		end
	end)

	T.it("elixirs show resistance and duration; materials show their uses", function()
		local elixir = texts(sample("elixir_resFire"))
		T.expect(string.find(elixir, "Odporność na ogień +15%", 1, true) ~= nil).toBe(true)
		T.expect(string.find(elixir, "60 min", 1, true) ~= nil).toBe(true)
		local dust = texts(sample("essence_dust"))
		T.expect(string.find(dust, "Używany do:", 1, true) ~= nil).toBe(true)
		T.expect(string.find(dust, "+1…+3", 1, true) ~= nil).toBe(true)
		local core = texts(sample("legend_core"))
		T.expect(string.find(core, "+7…+9", 1, true) ~= nil).toBe(true)
		for id, def in Items.byId do
			if def.category == "material" and not roles(sample(id)).use then
				error(`{id}: no usage line`)
			end
		end
	end)

	T.it("context lines: shop price, sells for, red requirement, comparison", function()
		local item = sample("sword1h_45", 45)
		T.expect(roles(item, { lang = "pl", merchantOpen = true }).sellFor).toBe(1)
		T.expect(roles(item, { lang = "pl" }).sellFor).toBeNil()
		local low = false
		for _, line in TooltipModel.build(item, nil, { lang = "pl", level = 10 }).lines do
			if line.role == "requires" then
				low = line.tone == "bad"
			end
		end
		T.expect(low).toBe(true)
		local found = roles(item, { lang = "pl", equipped = sample("sword1h_5", 5) })
		T.expect(found.compare).toBe(1)
	end)

	T.it("statLine: compact weapon and off-hand rows", function()
		local line = TooltipModel.statLine(sample("sword1h_15", 15), nil, "pl") :: string
		T.expect(string.find(line, "Poz. 15", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "1,20/s", 1, true) ~= nil).toBe(true)
		T.expect(string.find(line, "DPS", 1, true) ~= nil).toBe(true)
		local shield = TooltipModel.statLine(sample("shield_15", 15), nil, "en") :: string
		T.expect(string.find(shield, "Lv 15", 1, true) ~= nil).toBe(true)
		T.expect(TooltipModel.decimal(46.8, 1, "pl")).toBe("46,8")
	end)
end)

return nil
