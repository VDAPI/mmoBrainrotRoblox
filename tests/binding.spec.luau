--!strict
-- Item binding (owner 2026-10-31, Data/Binding, Logic/Binding, docs/DESIGN.md §5.6): the rule of every category and
-- source, binding on equip, the migration of old saves and parcels, stacks that never merge across binding, the
-- refusals of trade, the auction house, mail and the guild vault, the tooltip line.
local fs = require("@lune/fs")

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Auction = require("../src/shared/Logic/Auction")
local Binding = require("../src/shared/Logic/Binding")
local BindingData = require("../src/shared/Data/Binding")
local Guild = require("../src/shared/Logic/Guild")
local GuildBank = require("../src/shared/Logic/GuildBank")
local Inventory = require("../src/shared/Logic/Inventory")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Items = require("../src/shared/Data/Items")
local Locale = require("../src/shared/Util/Locale")
local Products = require("../src/shared/Data/Products")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Social = require("../src/shared/Logic/Social")
local TooltipModel = require("../src/shared/Logic/TooltipModel")
local Trade = require("../src/shared/Logic/Trade")
local Tutorial = require("../src/shared/Logic/Tutorial")
local T = require("./Test")

local counter = 0
local function uid(): string
	counter += 1
	return `b{counter}`
end

local function stack(id: string, n: number?): any
	return ItemRoll.makeStack(id, n or 1, uid())
end

local function gear(id: string, rarity: number): any
	return ItemRoll.rollItem(id, Items.get(id).level, rarity, Rng.new(7), uid())
end

local SOURCES: { Binding.Source } =
	{ "drop", "craft", "gold", "boss", "quest", "reward", "currency", "shop", "premium" }

-- what (item, rarity) gets from every source, in SOURCES order
local function rules(item: any): { string }
	local out = {}
	for _, source in SOURCES do
		table.insert(out, Binding.ruleFrom(item, source))
	end
	return out
end

T.describe("Binding: the rule of every category and source (owner 2026-10-31)", function()
	T.it(
		"potions, scrolls, stones, blessings, elixirs: free unless from the Portal Master or the season pass",
		function()
			for _, id in
				{
					"potion_hp_1",
					"potion_mana_3",
					"potion_energy_5",
					"elixir_resFire",
					"blessing_fortune_2",
					"stone_return",
					"stone_map",
					"stone_dungeon_meadows",
					"scroll_unbind",
					"scroll_protection",
					"scroll_oblivion",
				}
			do
				T.expect({ id, rules(stack(id)) })
					.toEqual({ id, { "none", "none", "none", "none", "none", "none", "none", "none", "pickup" } })
				T.expect({ id, stack(id).bound }).toEqual({ id, false })
			end
		end
	)

	T.it("materials, herbs, fish, ore, tools: free; a currency shop binds what it sells", function()
		for _, id in { "essence_dust", "essence_crystal", "legend_core", "herb_moonpetal", "fish_goldfin", "ore_iron" } do
			T.expect({ id, rules(stack(id)) })
				.toEqual({ id, { "none", "none", "none", "none", "none", "none", "pickup", "none", "pickup" } })
		end
		T.expect(rules(stack("pickaxe")))
			.toEqual({ "none", "none", "none", "none", "none", "none", "pickup", "none", "pickup" })
	end)

	T.it("premium things carry their own rule: bound from creation, whatever the source", function()
		for _, id in
			{
				"potion_full",
				"reroll_stone",
				"effect_stone",
				"transmute_scroll",
				"scroll_hunt",
				"stone_return_perm",
			}
		do
			local made = stack(id)
			T.expect({ id, made.bound, rules(made)[1] }).toEqual({ id, true, "pickup" })
		end
	end)

	T.it(
		"equipment: on equip from drops, crafts, vendors, bosses, side quests; on pickup from rewards, currencies",
		function()
			-- owner 2026-10-31 (less binding): a boss's Legendary and a side quest's chosen reward bind on equip (S149)
			for _, rarity in { Rarities.COMMON, Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY } do
				T.expect({ rarity, rules(gear("sword1h_30", rarity)) }).toEqual({
					rarity,
					{ "equip", "equip", "equip", "equip", "equip", "pickup", "pickup", "equip", "pickup" },
				})
			end
			-- Mythic binds on pickup everywhere (S30), the named boss items too
			local all = table.create(#SOURCES, "pickup")
			T.expect(rules(gear("sword1h_30", Rarities.MYTHIC))).toEqual(all)
			T.expect(rules(gear("unique_grimrok_cleaver", Rarities.MYTHIC))).toEqual(all)
		end
	)

	T.it("ordinary backpacks never bind; premium ones bind on equip", function()
		local bag = stack("backpack_30")
		T.expect(rules(bag)).toEqual({ "none", "none", "none", "none", "none", "pickup", "pickup", "none", "pickup" })
		T.expect(Binding.bindsOnEquip(bag)).toBe(false)
		Binding.onEquip(bag)
		T.expect(bag.bound).toBe(false)
		local premium = stack("backpack_premium_150")
		T.expect(premium.bound).toBe(false)
		T.expect(Binding.ruleFrom(premium, "shop")).toBe("equip")
		T.expect(Binding.bindsOnEquip(premium)).toBe(true)
		T.expect(Binding.tooltipKey(premium)).toBe("tooltip.bindOnEquip")
		Binding.onEquip(premium)
		T.expect(premium.bound).toBe(true)
	end)

	-- Protection, Unbinding, Oblivion and Renewal were free before 2026-10-31 and stay so (owner: less binding)
	local FREE_IN_SHOP =
		{ scroll_protection = true, scroll_unbind = true, scroll_oblivion = true, scroll_skillreset = true }

	T.it("the premium shop: scrolls free, backpacks on equip, the elixir, stones, Transmutation on pickup", function()
		local seen = 0
		for _, entry in Products.shop do
			local def = entry.kind == "item" and entry.itemId and Items.get(entry.itemId)
			if def then
				seen += 1
				local item = Binding.apply(ItemRoll.makeStack(def.id, entry.n or 1, uid()), "shop")
				local want = if FREE_IN_SHOP[def.id]
					then { false, "none" }
					elseif def.category == "backpack" then { false, "equip" }
					else { true, "pickup" }
				T.expect({ def.id, item.bound, Binding.ruleOf(item) }).toEqual({ def.id, want[1], want[2] })
			end
		end
		T.expect(seen >= 10).toBe(true)
	end)

	T.it("every category has a rule, every definition resolves to one, the sources are the documented ones", function()
		local seen: { [string]: boolean } = {}
		for _, def in Items.byId do
			T.expect({ def.id, BindingData.CATEGORY[def.category] ~= nil }).toEqual({ def.id, true })
			T.expect({ def.id, Binding.ofDef(def) ~= nil }).toEqual({ def.id, true })
			seen[def.category] = true
		end
		for category in BindingData.CATEGORY do
			T.expect({ category, seen[category] == true }).toEqual({ category, true })
		end
		local names = {}
		for source in BindingData.SOURCES do
			table.insert(names, source)
		end
		table.sort(names)
		local expected = table.clone(SOURCES)
		table.sort(expected)
		T.expect(names).toEqual(expected)
	end)

	T.it("Binding.apply binds only what binds on pickup and never unbinds", function()
		local potion = Binding.apply(stack("potion_hp_2", 5), "currency")
		T.expect(potion.bound).toBe(false)
		local essence = Binding.apply(stack("essence_shard", 5), "currency")
		T.expect(essence.bound).toBe(true)
		local sword = Binding.apply(gear("sword1h_30", Rarities.HEROIC), "boss")
		T.expect(sword.bound).toBe(false)
		local legend = Binding.apply(gear("sword1h_30", Rarities.LEGENDARY), "boss")
		T.expect(legend.bound).toBe(false)
		local mythic = Binding.apply(gear("sword1h_30", Rarities.MYTHIC), "boss")
		T.expect(mythic.bound).toBe(true)
		local worn = gear("sword1h_30", Rarities.UNIQUE)
		worn.bound = true
		T.expect(Binding.apply(worn, "drop").bound).toBe(true)
		T.expect(Binding.apply(stack("scroll_unbind"), "shop").bound).toBe(false)
		T.expect(Binding.apply(stack("stone_return"), "premium").bound).toBe(true)
	end)

	T.it("the first drop of a new character binds on pickup", function()
		local item = Tutorial.firstDrop("Warrior", 3, nil, Rng.new(1), "first")
		T.expect(item ~= nil and item.bound).toBe(true)
	end)
end)

T.describe("Binding: equipping", function()
	T.it("free gear binds when equipped and asks first; bound gear and stacks never ask", function()
		local sword = gear("sword1h_30", Rarities.HEROIC)
		T.expect(Binding.bindsOnEquip(sword)).toBe(true)
		Binding.onEquip(sword)
		T.expect(sword.bound).toBe(true)
		T.expect(Binding.bindsOnEquip(sword)).toBe(false)
		T.expect(Binding.bindsOnEquip(stack("potion_hp_1"))).toBe(false)
	end)
end)

T.describe("Binding: stacks", function()
	T.it("a bound and a free stack never merge, a missing field counts as free", function()
		local inv: any = {}
		Inventory.add(inv, 5, stack("potion_hp_1", 10), uid)
		local bound = stack("potion_hp_1", 3)
		bound.bound = true
		T.expect(Inventory.add(inv, 5, bound, uid)).toEqual({ 2 })
		T.expect(inv["1"].n).toBe(10)
		local legacy = stack("potion_hp_1", 2)
		legacy.bound = nil
		T.expect(Inventory.canMerge(inv["1"], legacy)).toBe(true)
		T.expect(Inventory.canMerge(inv["2"], legacy)).toBe(false)
		-- after the migration the old bound stack joins the free one
		T.expect(Binding.migrateItem(inv["2"])).toBe(true)
		T.expect(Inventory.move(inv, 5, 2, 1)).toEqual({ 2, 1 })
		T.expect(inv["1"].n).toBe(13)
	end)
end)

T.describe("Binding: refusals", function()
	T.it("trade, auction, mail and the guild vault refuse bound items; a merchant still buys them", function()
		local sword = gear("sword1h_30", Rarities.UNIQUE)
		local def = Items.get(sword.id)
		T.expect({ Trade.canOffer(sword) }).toEqual({ true, nil })
		T.expect({ Social.mailableItem(sword) }).toEqual({ true, nil })
		sword.bound = true
		T.expect({ Trade.canOffer(sword) }).toEqual({ false, "trade.error.bound" })
		T.expect({ Auction.validateListing(sword, def :: any, 100, 24, 0, 1000) })
			.toEqual({ false, "auction.error.bound" })
		T.expect({ Social.mailableItem(sword) }).toEqual({ false, "mail.error.bound" })
		local member = {
			userId = 1,
			charId = "c1",
			name = "Lead",
			class = "Warrior",
			level = 30,
			rank = "member",
			joinedAt = 0,
			contributed = 0,
		}
		local g = Guild.create({ id = "g1", name = "Order", tag = "ORD", founder = member, now = 100 })
		T.expect({ GuildBank.putItem(g, Guild.memberKey(1, "c1"), sword, nil, 0) })
			.toEqual({ false, "trade.error.bound" })
		T.expect(ItemValue.canSell(sword, def)).toBe(true)
		-- potions are free now: every way takes them
		local potion = stack("potion_hp_3", 20)
		T.expect({ Trade.canOffer(potion) }).toEqual({ true, nil })
		T.expect({ Social.mailableItem(potion) }).toEqual({ true, nil })
	end)
end)

T.describe("Binding: migration of old saves (schema 13)", function()
	local function oldItem(id: string, bound: boolean, extra: { [string]: any }?): any
		local item = if Items.get(id).category == "equipment" then gear(id, Rarities.UNIQUE) else stack(id, 5)
		item.bound = bound
		for k, v in extra or {} do
			item[k] = v
		end
		return item
	end

	T.it("stacks bound by the old rules come free; equipment, premium and currency goods stay", function()
		local data: any = AccountSchema.accountTemplate()
		data.schema = 12
		data.characters["1"] = {
			id = "c1",
			name = "Old",
			class = "Warrior",
			level = 20,
			inventory = {
				["1"] = oldItem("potion_hp_1", true), -- the level 5 reward
				["2"] = oldItem("stone_return", true, { ns = true }), -- the Huntmaster's
				["3"] = oldItem("blessing_fortune_1", true),
				["4"] = oldItem("herb_moonpetal", true, { ns = true }), -- the wandering merchant's for gold
				["5"] = oldItem("essence_dust", true, { ns = true }), -- maybe bought for marks: stays
				["6"] = oldItem("sword1h_30", true), -- maybe worn: stays
				["7"] = oldItem("potion_full", true), -- premium: stays
				["8"] = oldItem("backpack_45", true), -- a backpack worn before: free
				["9"] = oldItem("backpack_premium_100", true), -- binds on equip, worn before: stays
				["10"] = oldItem("potion_mana_1", false),
			},
			equipment = {
				weapon = oldItem("sword1h_30", true),
				backpack = oldItem("backpack_60", true),
			},
		}
		data.deposit.items = { ["1"] = oldItem("potion_energy_2", true), ["2"] = oldItem("scroll_hunt", true) }
		local applied = AccountSchema.migrate(data)
		T.expect(applied[#applied]).toBe(13)
		local inv = data.characters["1"].inventory
		local bound = {}
		for i = 1, 10 do
			bound[i] = inv[tostring(i)].bound
		end
		T.expect(bound).toEqual({ false, false, false, false, true, true, true, false, true, false })
		T.expect(inv["2"].ns).toBe(true) -- still never sold to a merchant
		T.expect(data.characters["1"].equipment.weapon.bound).toBe(true)
		T.expect(data.characters["1"].equipment.backpack.bound).toBe(false)
		T.expect({ data.deposit.items["1"].bound, data.deposit.items["2"].bound }).toEqual({ false, true })
		-- runs once: a later load changes nothing
		inv["1"].bound = true
		T.expect(#AccountSchema.migrate(data)).toBe(0)
		T.expect(inv["1"].bound).toBe(true)
	end)

	T.it("a parcel sent before the rules goes through the same migration (Mail bv)", function()
		local items = { oldItem("potion_hp_2", true), oldItem("sword1h_30", true), oldItem("reroll_stone", true) }
		T.expect(Binding.migrateAll(items)).toBe(1)
		T.expect({ items[1].bound, items[2].bound, items[3].bound }).toEqual({ false, true, true })
		T.expect(BindingData.VERSION >= 1).toBe(true)
	end)
end)

T.describe("Binding: the tooltip line", function()
	local function bindLine(item: any, view: string?): string?
		local lines = TooltipModel.build(item, nil, { lang = "pl", view = view :: any }).lines
		for _, line in lines do
			if line.role == "bind" then
				return line.text
			end
		end
		return nil
	end

	-- the compact view: the rarity line, which carries the binding there
	local function rarityLine(item: any): string
		for _, line in TooltipModel.build(item, nil, { lang = "pl", view = "compact", input = "mouse" }).lines do
			if line.role == "rarity" then
				return line.text
			end
		end
		return ""
	end

	T.it("one short line: bound, binds when equipped, or nothing; the compact view keeps it", function()
		for _, lang in { "pl", "en" } do
			local sword = gear("sword1h_30", Rarities.HEROIC)
			local full = TooltipModel.build(sword, nil, { lang = lang }).lines
			local text: string? = nil
			for _, line in full do
				if line.role == "bind" then
					text = line.text
				end
			end
			T.expect(text).toBe(Locale.T("tooltip.bindOnEquip", nil, lang))
		end
		-- the short view keeps its line count: the binding joins the rarity line
		local sword = gear("sword1h_30", Rarities.UNIQUE)
		T.expect(bindLine(sword, "compact")).toBeNil()
		local suffix = ` · {Locale.T("tooltip.bindOnEquip", nil, "pl")}`
		T.expect(string.sub(rarityLine(sword), -#suffix)).toBe(suffix)
		sword.bound = true
		suffix = ` · {Locale.T("tooltip.bound", nil, "pl")}`
		T.expect(string.sub(rarityLine(sword), -#suffix)).toBe(suffix)
		T.expect(string.find(rarityLine(stack("potion_hp_1")), " · ", 1, true)).toBeNil()
		T.expect(bindLine(stack("potion_hp_1"))).toBeNil()
		T.expect(bindLine(stack("backpack_80"))).toBeNil()
		T.expect(bindLine(stack("potion_full"))).toBe(Locale.T("tooltip.bound", nil, "pl"))
		T.expect(Binding.tooltipKey(stack("essence_dust"))).toBeNil()
	end)

	T.it("the texts are short in both languages and the bind question has its switch", function()
		local pl = require("../src/shared/Data/Localization/pl")
		local en = require("../src/shared/Data/Localization/en")
		for _, key in { "tooltip.bound", "tooltip.bindOnEquip", "equip.bind.message", "equip.bind.session" } do
			for _, dict in { pl, en } :: { any } do
				T.expect({ key, type(dict[key]) == "string" and #dict[key] <= 60 }).toEqual({ key, true })
			end
		end
		T.expect(pl["equip.bind.message"]).toBe("Założenie zwiąże <b>{name}</b> z postacią.")
		T.expect(pl["tooltip.bindOnEquip"]).toBe("Wiąże się po założeniu")
		T.expect(pl["tooltip.bound"]).toBe("Związany z postacią")
	end)
end)

T.describe("Binding: one place", function()
	-- every server or shared file that binds an item does it through Logic/Binding (apply / onEquip), never by hand
	local function walk(dir: string, out: { string })
		for _, name in fs.readDir(dir) do
			local path = `{dir}/{name}`
			if fs.isDir(path) then
				walk(path, out)
			elseif string.match(name, "%.luau$") then
				table.insert(out, path)
			end
		end
	end

	T.it("nobody sets bound = true by hand, every source named is a known one", function()
		local files: { string } = {}
		walk("src", files)
		local known: { [string]: boolean } = {}
		for _, source in SOURCES do
			known[source] = true
		end
		local named = 0
		for _, path in files do
			local text = fs.readFile(path)
			if path ~= "src/shared/Logic/Binding.luau" then
				for line in string.gmatch(text, "[^\n]+") do
					if string.match(line, "%.bound%s*=%s*true") and not string.match(line, "^%s*%-%-") then
						error(`{path}: binds by hand ({line}); use Logic/Binding`, 0)
					end
				end
			end
			for source in string.gmatch(text, 'Binding%.apply%([^,]+,%s*"([%w_]+)"%)') do
				T.expect({ path, source, known[source] == true }).toEqual({ path, source, true })
				named += 1
			end
		end
		T.expect(named >= 15).toBe(true)
	end)
end)
