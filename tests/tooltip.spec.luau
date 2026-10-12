--!strict
-- S68: item tooltip order (STATY 11), the details panel model (TooltipModel.details, traitNodes, capValue), the
-- details hint and the % comparison lines.
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

T.describe("TooltipModel order (S68)", function()
	T.it("name, damage, trait, regular, legendary, mythic lines, requirements", function()
		for _, id in { "sword1h_60", "shield_60" } do
			local lines = TooltipModel.build(sample(id, Rarities.MYTHIC), nil, { lang = "pl", class = "Warrior" }).lines
			local first: { [string]: number } = {}
			local lastTier = 0
			for index, line in lines do
				first[line.role] = first[line.role] or index
				if line.role == "bonus" then
					local rank = TooltipModel.TIER_ORDER[line.tier or "regular"]
					T.expect(rank >= lastTier).toBe(true)
					lastTier = rank
				end
			end
			local stat = first.dps or first.stat
			T.expect(first.name < stat).toBe(true)
			T.expect(stat < first.traitName).toBe(true)
			T.expect(first.traitName < first.trait).toBe(true)
			T.expect(first.trait < first.bonus).toBe(true)
			T.expect(first.bonus < first.requires).toBe(true)
			T.expect(lastTier).toBe(3)
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

	T.it("an upgraded sword shows the damage change in %", function()
		local better = made("sword1h_30", Rarities.COMMON, {}, 5)
		local worn = made("sword1h_30", Rarities.COMMON, {}, 0)
		worn.uid = "worn"
		local withClass = TooltipModel.build(better, nil, { lang = "pl", class = "Warrior", equipped = worn }).lines
		T.expect(count(withClass, "comparePct")).toBe(1)
		T.expect(count(withClass, "compare")).toBe(1)
		local without = TooltipModel.build(better, nil, { lang = "pl", equipped = worn }).lines
		T.expect(count(without, "comparePct")).toBe(0)
	end)
end)
