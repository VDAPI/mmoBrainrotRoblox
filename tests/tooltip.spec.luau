--!strict
-- S68: item tooltip order (STATY 11), the details panel model (TooltipModel.details, traitNodes, capValue), the
-- details hint; S134g: the head line, the stat groups, the skill effects and no comparison numbers.
local Bonuses = require("../src/shared/Data/Bonuses")
local Combat = require("../src/shared/Data/Combat")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemTraits = require("../src/shared/Data/ItemTraits")
local Items = require("../src/shared/Data/Items")
local Locale = require("../src/shared/Util/Locale")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Stats = require("../src/shared/Data/Stats")
local T = require("./Test")
local TooltipModel = require("../src/shared/Logic/TooltipModel")

local ALIASES: { [string]: string } = { hp = "maxHp", mana = "maxMana", energy = "maxEnergy" }

local function sample(id: string, rarity: number, up: number?): any
	local def = Items.get(id) :: Items.ItemDef
	local item: any = ItemRoll.rollItem(id, def.level, rarity, Rng.new(7), `{id}:{rarity}`)
	item.up = up or 0
	return item
end

local function made(id: string, rarity: number, bonuses: { any }, up: number?): any
	local def = Items.get(id) :: Items.ItemDef
	return {
		uid = `m{id}{rarity}{up or 0}`,
		id = id,
		rarity = rarity,
		ilvl = def.level,
		bonuses = bonuses,
		up = up or 0,
		bound = false,
		n = 1,
		rv = Rarities.RV,
	}
end

local function rowOf(details: TooltipModel.Details, role: string): TooltipModel.DetailRow?
	for _, row in details.rows do
		if row.role == role then
			return row
		end
	end
	return nil
end

local function clean(text: string): boolean
	return string.find(text, "{", 1, true) == nil
		and string.find(text, "bonusInfo.", 1, true) == nil
		and string.find(text, "tooltip.", 1, true) == nil
		and string.find(text, "trait.", 1, true) == nil
end

-- One generated definition per base type that has a trait.
local function traitTypes(): { [string]: string }
	local out: { [string]: string } = {}
	for id, def in Items.byId do
		if def.trait and def.tier and not def.fixedBonuses then
			local known = out[def.type]
			if not known or id < known then
				out[def.type] = id
			end
		end
	end
	return out
end

-- S134g (F1): every category starts with name, head, rarity; equipment goes main value, statistics in fixed groups,
-- trait, effects, description, replace notes, binding, item level, value. Replaces the S68 order test and the FIX
-- 2026-10-15 readability test (the type line became the head line, the requirements and classes moved into it).
local function firstOf(lines: { TooltipModel.Line }): { [string]: number }
	local first: { [string]: number } = {}
	for index, line in lines do
		first[line.role] = first[line.role] or index
	end
	return first
end

T.describe("TooltipModel order (S134g)", function()
	T.it("every category: name, head, rarity first", function()
		for _, id in { "sword1h_60", "armor_heavy_60", "ring_60", "potion_hp_2", "spider_silk", "stone_return" } do
			local item = sample(id, Rarities.HEROIC)
			local lines = TooltipModel.build(item, nil, { lang = "pl", class = "Warrior", level = 60 }).lines
			T.expect({ id, lines[1].role, lines[2].role, lines[3].role }).toEqual({ id, "name", "head", "rarity" })
			T.expect({ id, lines[2].size, lines[2].font, lines[3].size }).toEqual({ id, "body", "bold", "small" })
			for _, line in lines do
				T.expect({ id, line.role ~= "type" and line.role ~= "requires" and line.role ~= "classes" })
					.toEqual({ id, true })
			end
		end
	end)

	T.it("weapon, armour, jewellery: main value, stats, trait, effects, description, binding, level, value", function()
		for _, id in { "sword1h_60", "shield_60", "armor_heavy_60", "ring_60" } do
			local item = sample(id, Rarities.MYTHIC)
			local first = firstOf(TooltipModel.build(item, nil, { lang = "pl", class = "Warrior" }).lines)
			-- the main value (damage or armour) before the statistics; a ring has none (its base stats are statistics)
			local main = if id == "ring_60" then first.bonus else first.speedDps or first.stat
			T.expect({ id, first.rarity < main, main <= first.bonus }).toEqual({ id, true, true })
			if first.traitName then
				T.expect({ id, first.bonus < first.traitName, first.traitName < first.fxTitle })
					.toEqual({ id, true, true })
			end
			T.expect({ id, first.bonus < first.fxTitle, first.fxTitle < first.fx }).toEqual({ id, true, true })
			T.expect({ id, first.fx < first.bind, first.bind < first.ilvl, first.ilvl < first.value })
				.toEqual({ id, true, true, true })
		end
	end)

	T.it("head: kind, grip, level and classes; the unmet part red", function()
		local sword = sample("sword1h_60", Rarities.HEROIC)
		local def = Items.get("sword1h_60") :: Items.ItemDef
		local lines = TooltipModel.build(sword, nil, { lang = "pl", class = "Warrior", level = 99 }).lines
		local head = lines[2].text
		T.expect(string.find(head, Locale.T("itemBase.sword1h", nil, "pl"), 1, true) ~= nil).toBe(true)
		T.expect(string.find(head, Locale.T("itemCat.weapon1h", nil, "pl"), 1, true) ~= nil).toBe(true)
		T.expect(string.find(head, Locale.T("tooltip.head.level", { level = def.level }, "pl"), 1, true) ~= nil)
			.toBe(true)
		T.expect(string.find(head, TooltipModel.BAD_HEX, 1, true)).toBeNil()
		local low = TooltipModel.build(sword, nil, { lang = "pl", class = "Warrior", level = 1 }).lines[2].text
		local red = `<font color="{TooltipModel.BAD_HEX}">{Locale.T("tooltip.head.level", { level = def.level }, "pl")}`
		T.expect(string.find(low, red, 1, true) ~= nil).toBe(true)
		local mage = TooltipModel.build(sword, nil, { lang = "pl", class = "Mage", level = 99 }).lines[2].text
		local className = Locale.T("class.Warrior.name", nil, "pl")
		T.expect(string.find(mage, `<font color="{TooltipModel.BAD_HEX}">{className}`, 1, true) ~= nil).toBe(true)
		-- every weapon names its grip (owner 2026-10-15), ranged ones too
		local bow = TooltipModel.build(sample("bow_60", Rarities.COMMON), nil, { lang = "pl" }).lines[2].text
		T.expect(string.find(bow, Locale.T("itemCat.weaponRanged1h", nil, "pl"), 1, true) ~= nil).toBe(true)
		local staff = TooltipModel.build(sample("staff_60", Rarities.COMMON), nil, { lang = "en" }).lines[2].text
		T.expect(string.find(staff, Locale.T("itemCat.weaponRanged2h", nil, "en"), 1, true) ~= nil).toBe(true)
		-- level 1 items leave the level out; the rarity line carries the upgrade
		local upgraded = sample("sword1h_60", Rarities.LEGENDARY, 3)
		local rarity = TooltipModel.build(upgraded, nil, { lang = "pl" }).lines[3].text
		T.expect(string.find(TooltipModel.plain(rarity), "+3", 1, true) ~= nil).toBe(true)
		local potion = TooltipModel.build(sample("potion_hp_2", Rarities.COMMON), nil, { lang = "pl" }).lines
		T.expect(potion[3].text)
			.toBe(TooltipModel.rarityLine(sample("potion_hp_2", Rarities.COMMON), Items.get("potion_hp_2") :: any, "pl"))
	end)

	T.it(
		"the statistics are small, in the fixed group order whatever the roll order, with gaps between groups",
		function()
			local lines = { { stat = "goldBonus", v = 5 }, { stat = "vit", v = 4 }, { stat = "critChance", v = 2 } }
			local reversed = { lines[3], lines[2], lines[1] }
			local function order(bonuses: { any }): { string }
				local out: { string } = {}
				for _, line in TooltipModel.build(made("ring_60", Rarities.HEROIC, bonuses), nil, { lang = "pl" }).lines do
					if line.role == "bonus" or line.role == "stat" or line.role == "gap" then
						table.insert(out, if line.role == "bonus" then (line.detail :: any).id else line.role)
						if line.role ~= "gap" then
							T.expect(line.size).toBe("small")
						end
					end
				end
				return out
			end
			local a = order(lines)
			T.expect(a).toEqual(order(reversed))
			local at: { [string]: number } = {}
			for index, id in a do
				at[id] = at[id] or index
			end
			T.expect(at.vit < at.critChance and at.critChance < at.goldBonus).toBe(true)
			T.expect(table.find(a, "gap") ~= nil).toBe(true)
			local groups: { string } = {}
			for _, group in TooltipModel.STAT_GROUPS do
				table.insert(groups, group.id)
			end
			T.expect(groups).toEqual({ "attributes", "attack", "defence", "resources" })
		end
	)

	T.it("every published line of Data/Bonuses has a group", function()
		for id, def in Bonuses.byId do
			if def.wiki == true then
				T.expect({ id, (TooltipModel.groupOf(id)) ~= nil }).toEqual({ id, true })
			end
		end
	end)

	T.it("rarity bonus after the stats, no rarity bonus on a Common item, item level in the footer", function()
		local first = firstOf(TooltipModel.build(sample("sword1h_60", Rarities.HEROIC), nil, { lang = "pl" }).lines)
		T.expect(first.rarityBonus > first.bonus and first.rarityBonus < first.traitName).toBe(true)
		T.expect(first.ilvl > first.bind).toBe(true)
		for _, line in TooltipModel.build(sample("sword1h_60", Rarities.COMMON), nil, { lang = "pl" }).lines do
			T.expect(line.role ~= "rarityBonus").toBe(true)
		end
	end)
end)

T.describe("TooltipModel skill effects (S134g)", function()
	T.it("effects after the trait in the tier colour; another class's effect says whom it works for", function()
		local item = made("sword1h_60", Rarities.MYTHIC, {})
		item.fx = { "charge_stagger", "earthquake_rupture" }
		local lines = TooltipModel.build(item, nil, { lang = "pl", class = "Warrior" }).lines
		local titles, fx, notes = 0, 0, 0
		for _, line in lines do
			if line.role == "fxTitle" then
				titles += 1
				local hex = Rarities.get(if line.tier == "mythic" then Rarities.MYTHIC else Rarities.LEGENDARY).textHex
				T.expect(line.hex).toBe(hex)
				T.expect(clean(line.text)).toBe(true)
			elseif line.role == "fx" then
				fx += 1
				T.expect(clean(line.text)).toBe(true)
				T.expect((line.detail :: any).kind).toBe("effect")
			elseif line.role == "fxClass" then
				notes += 1
			end
		end
		T.expect({ titles, fx, notes }).toEqual({ 2, 2, 0 })
		local other = TooltipModel.build(item, nil, { lang = "en", class = "Mage" }).lines
		local note = 0
		for _, line in other do
			if line.role == "fxClass" then
				note += 1
				T.expect(line.text).toBe(Locale.T("tooltip.fx.otherClass", { class = "Warrior" }, "en"))
			end
		end
		T.expect(note).toBe(2)
	end)

	T.it("effect details: what it does, the skill, breakpoints, once, the class", function()
		local item = made("wand_60", Rarities.LEGENDARY, {})
		item.fx = { "meteor_shards" }
		for _, lang in { "pl", "en" } do
			local details = TooltipModel.details(item, { kind = "effect", id = "meteor_shards" }, { lang = lang })
			T.expect(details.tier).toBe("mythic")
			for _, role in { "does", "skill", "works", "once", "class" } do
				local row = rowOf(details, role)
				T.expect({ lang, role, row ~= nil and clean(row.text) }).toEqual({ lang, role, true })
			end
			T.expect(
				string.find((rowOf(details, "skill") :: any).text, Locale.T("skill.meteor.name", nil, lang), 1, true)
					~= nil
			).toBe(true)
		end
	end)
end)

T.describe("TooltipModel Elixir of Wholeness (S122)", function()
	T.it("effect, rules, where it does not work, bound and not for sale", function()
		local stack = ItemRoll.makeStack("potion_full", 3, "s122")
		for _, lang in { "pl", "en" } do
			local lines = TooltipModel.build(stack, nil, { lang = lang }).lines
			local byRole: { [string]: TooltipModel.Line } = {}
			for _, line in lines do
				byRole[line.role] = byRole[line.role] or line
			end
			for _, role in { "effect", "rules", "blocked", "bind", "noSell" } do
				T.expect({ lang, role, byRole[role] ~= nil }).toEqual({ lang, role, true })
			end
			T.expect(byRole.effect.text).toBe(Locale.T("tooltip.fullElixir.effect", nil, lang))
			T.expect(byRole.blocked.tone).toBe("bad")
			T.expect(byRole.bind.text).toBe(Locale.T("tooltip.bound", nil, lang))
			T.expect(clean(byRole.rules.text) and clean(byRole.blocked.text)).toBe(true)
			T.expect(byRole.head.text ~= nil).toBe(true) -- S134g: the head line replaced the type line
		end
	end)
end)

T.describe("TooltipModel.details (S68)", function()
	T.it("every published line has its details in both languages", function()
		local ids: { string } = {}
		for id, def in Bonuses.byId do
			if def.wiki == true then
				table.insert(ids, id)
			end
		end
		table.sort(ids)
		for _, id in ids do
			local def = Bonuses.get(id) :: Bonuses.BonusDef
			local v = ItemRoll.rollBonusValue(id, 50, Rarities.HEROIC, 0.5)
			local item = made("sword1h_50", Rarities.HEROIC, { { stat = id, v = v } })
			for _, lang in { "pl", "en" } do
				local details = TooltipModel.details(item, { kind = "bonus", id = id, v = v }, { lang = lang })
				T.expect({ id, lang, details.title ~= "" }).toEqual({ id, lang, true })
				T.expect({ id, rowOf(details, "does") ~= nil, rowOf(details, "pvp") ~= nil })
					.toEqual({ id, true, true })
				for _, row in details.rows do
					T.expect({ id, lang, row.role, clean(row.text) }).toEqual({ id, lang, row.role, true })
				end
				-- Hooks and parameter lines have their own text, never the generic stat template.
				if def.hook or def.param then
					local param = def.param and Bonuses.params[def.param]
					local key = if param
						then `bonusInfo.{string.gsub(param.prefix, "_", "")}{if param.over == "family"
							then "Family"
							else "Class"}`
						else `bonusInfo.{def.hook}`
					T.expect({ id, key, Locale.has(key, lang) }).toEqual({ id, key, true })
				end
				local stat = def.stat and (ALIASES[def.stat] or def.stat)
				local statDef = stat and Stats.get(stat)
				if def.capRef or (statDef and statDef.cap) then
					T.expect({ id, rowOf(details, "cap") ~= nil }).toEqual({ id, true })
				end
			end
		end
	end)

	T.it("a two-handed line's range is shown with twoHandedBonusMul like its value (S87)", function()
		T.expect(ItemRoll.lineMultiplier(made("sword2h_50", Rarities.HEROIC, {}), "str"))
			.toBe(Rarities.twoHandedBonusMul)
		T.expect(ItemRoll.lineMultiplier(made("sword1h_50", Rarities.HEROIC, {}), "str")).toBe(1)
		T.expect(ItemRoll.lineMultiplier({ id = "unique_azgor_staff", ilvl = 45 } :: any, "str")).toBe(1)
		local ilvl = (Items.get("sword2h_50") :: Items.ItemDef).level
		local low, high = ItemRoll.bonusRange("str", ilvl, Rarities.HEROIC)
		local saved = ItemRoll.rollBonusValue("str", ilvl, Rarities.HEROIC, 1)
		local item = made("sword2h_50", Rarities.HEROIC, { { stat = "str", v = saved } })
		local line = ItemRoll.itemStats(item).bonuses[1]
		T.expect(line.v).toBe(math.floor(saved * Rarities.twoHandedBonusMul + 0.5))
		local details = TooltipModel.details(item, { kind = "bonus", id = "str", v = line.v, quality = line.quality }, {
			lang = "en",
		})
		local mul = Rarities.twoHandedBonusMul
		T.expect((rowOf(details, "range") :: any).text).toBe(Locale.T("tooltip.detail.range", {
			min = tostring(math.floor(low * mul + 0.5)),
			max = tostring(math.floor(high * mul + 0.5)),
			q = math.floor(line.quality * 100 + 0.5),
		}, "en"))
	end)

	T.it("family and class variants say where they work", function()
		local function details(id: string): TooltipModel.Details
			local item = made("sword1h_50", Rarities.HEROIC, { { stat = id, v = 3 } })
			return TooltipModel.details(item, { kind = "bonus", id = id, v = 3 }, { lang = "pl" })
		end
		local none = Locale.T("tooltip.detail.pvp.none", nil, "pl")
		T.expect((rowOf(details("vs_undead"), "pvp") :: any).text).toBe(none)
		local only = Locale.T("tooltip.detail.pvp.only", { pvp = "0,6" }, "pl")
		T.expect(Combat.pvpModifier).toBe(0.6)
		T.expect((rowOf(details("vs_mage"), "pvp") :: any).text).toBe(only)
		local cap = rowOf(details("res_undead"), "cap") :: any
		T.expect(cap ~= nil).toBe(true)
		T.expect(string.find(cap.text, `{Combat.familyResCap}%`, 1, true) ~= nil).toBe(true)
	end)

	T.it("every cap reference resolves to a number", function()
		for id, def in Bonuses.byId do
			if def.capRef then
				T.expect({ id, type(TooltipModel.capValue(def.capRef)) }).toEqual({ id, "number" })
			end
		end
		for _, def in ItemTraits.list do
			if def.capRef then
				T.expect({ def.id, type(TooltipModel.capValue(def.capRef)) }).toEqual({ def.id, "number" })
			end
		end
	end)

	T.it("every trait has its details, growing with rarity and upgrades", function()
		for baseType, id in traitTypes() do
			local low = made(id, Rarities.COMMON, {}, 0)
			local high = made(id, Rarities.MYTHIC, {}, 9)
			local traitId = (Items.get(id) :: Items.ItemDef).trait :: string
			for _, item in { low, high } do
				for _, lang in { "pl", "en" } do
					local details = TooltipModel.details(item, { kind = "trait", id = traitId }, { lang = lang })
					T.expect({ baseType, details.tier }).toEqual({ baseType, "trait" })
					for _, role in { "does", "growth", "pvp" } do
						local row = rowOf(details, role)
						T.expect({ baseType, role, row ~= nil and clean(row.text) }).toEqual({ baseType, role, true })
					end
					local pvpKey = `trait.{traitId}.pvp`
					if Locale.has(pvpKey, lang) then
						local args: any = TooltipModel.traitArgs(traitId, (ItemRoll.trait(item) :: any).power, lang)
						args.dot = if lang == "pl" then "0,6" else "0.6"
						args.frost = if lang == "pl" then "0,5" else "0.5"
						T.expect((rowOf(details, "pvp") :: any).text).toBe(Locale.T(pvpKey, args, lang))
					end
				end
			end
			local lowLine = TooltipModel.traitLine(traitId, ItemRoll.traitPower(Rarities.COMMON, 0), "pl")
			local highLine = TooltipModel.traitLine(traitId, ItemRoll.traitPower(Rarities.MYTHIC, 9), "pl")
			T.expect({ baseType, lowLine ~= highLine }).toEqual({ baseType, true })
		end
		T.expect(Combat.pvp.dot).toBe(0.6)
		T.expect(Combat.pvp.frostbite).toBe(0.5)
	end)

	T.it("traitNodes lists nodes with a matching passive hook", function()
		local nameKey = "trait.swordplay.name"
		local paths = {
			{
				id = "fx",
				nameKey = nameKey,
				rows = {
					{
						choice = false,
						nodes = {
							{
								id = "fx_a",
								kind = "passive",
								passive = { hooks = { riposte = "x" } },
								nameKey = nameKey,
							},
						},
					},
				},
			},
		}
		local owned = TooltipModel.traitNodes("swordplay", paths, { fx_a = 1 }, "pl")
		T.expect(#owned).toBe(1)
		T.expect(owned[1].owned).toBe(true)
		T.expect(owned[1].nodeId).toBe("fx_a")
		local free = TooltipModel.traitNodes("swordplay", paths, nil, "pl")
		T.expect(#free).toBe(1)
		T.expect(free[1].owned).toBe(false)
		T.expect(#TooltipModel.traitNodes("powerLens", paths, { fx_a = 1 }, "pl")).toBe(0)
	end)
end)

T.describe("TooltipModel hint and comparison (S68)", function()
	local function count(lines: { TooltipModel.Line }, role: string): number
		local n = 0
		for _, line in lines do
			if line.role == role then
				n += 1
			end
		end
		return n
	end

	T.it("the details hint needs an input", function()
		local item = sample("sword1h_30", Rarities.HEROIC)
		T.expect(count(TooltipModel.build(item, nil, { lang = "pl" }).lines, "detailsHint")).toBe(0)
		T.expect(count(TooltipModel.build(item, nil, { lang = "pl", input = "touch" }).lines, "detailsHint")).toBe(1)
		local mouse = TooltipModel.build(item, nil, { lang = "en", input = "mouse", detailsKey = "Alt" }).lines
		T.expect(count(mouse, "detailsHint")).toBe(1)
	end)

	-- S134g (F2, owner 2026-10-15): no comparison numbers in the tooltip (the second panel shows the equipped item's own
	-- stats); only "Zastąpi: <name>" without numbers and the two-hander note. Was: % and ↑↓ lines (S68).
	T.it("an upgraded sword shows no comparison numbers, only what it replaces", function()
		local better = made("sword1h_30", Rarities.COMMON, {}, 5)
		local worn = made("sword1h_30", Rarities.COMMON, {}, 0)
		worn.uid = "worn"
		local lines = TooltipModel.build(better, nil, { lang = "pl", class = "Warrior", equipped = worn }).lines
		for _, role in { "compare", "comparePct", "compareTitle", "bonusTitle", "type", "requires", "classes" } do
			T.expect({ role, count(lines, role) }).toEqual({ role, 0 })
		end
		T.expect(count(lines, "replaces")).toBe(1)
		for _, line in lines do
			if line.role == "replaces" then
				local name = require("../src/shared/Logic/ItemName").get("pl", worn.id, worn.up)
				T.expect(line.text).toBe(Locale.T("tooltip.replaces", { item = name }, "pl"))
				T.expect(string.find(line.text, "%%")).toBeNil()
			end
		end
		local self = TooltipModel.build(worn, nil, { lang = "pl", class = "Warrior", equipped = worn }).lines
		T.expect(count(self, "replaces")).toBe(0)
	end)

	T.it("a two-hander next to a shield replaces the shield too; an off-hand under a two-hander is red", function()
		local axe = made("axe2h_50", Rarities.COMMON, {}, 0)
		local shield = made("shield_50", Rarities.COMMON, {}, 0)
		local lines = TooltipModel.build(axe, nil, { lang = "pl", class = "Warrior", offhand = shield }).lines
		T.expect(count(lines, "comparePct")).toBe(0)
		T.expect(count(lines, "replaces")).toBe(1)
		local under = TooltipModel.build(shield, nil, { lang = "pl", class = "Warrior", mainHand = axe }).lines
		T.expect(count(under, "compareNote")).toBe(1)
		for _, line in under do
			if line.role == "compareNote" then
				T.expect({ line.text, line.tone }).toEqual({ Locale.T("equip.error.twoHanded", nil, "pl"), "bad" })
			end
		end
	end)
end)
