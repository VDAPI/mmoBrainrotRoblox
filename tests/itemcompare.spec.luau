--!strict
-- Owner 2026-10-31: the hovered item's tooltip shows the change of every number against what equipping it takes off
-- (Logic/ItemCompare, TooltipModel ctx.compare) instead of a second panel with the worn item.
local ItemCompare = require("../src/shared/Logic/ItemCompare")
local ItemName = require("../src/shared/Logic/ItemName")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Locale = require("../src/shared/Util/Locale")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")
local TooltipModel = require("../src/shared/Logic/TooltipModel")

local GOOD = TooltipModel.DELTA_HEX.good
local BAD = TooltipModel.DELTA_HEX.bad
local SAME = TooltipModel.DELTA_HEX.same

local function made(id: string, uid: string, bonuses: { any }?, up: number?, rarity: number?): any
	local def = Items.get(id) :: Items.ItemDef
	return {
		uid = uid,
		id = id,
		rarity = rarity or Rarities.COMMON,
		ilvl = def.level or 1,
		bonuses = bonuses or {},
		up = up or 0,
		bound = false,
		n = 1,
		rv = Rarities.RV,
	}
end

local function uids(list: { any }?): { string }?
	if not list then
		return nil
	end
	local out: { string } = {}
	for _, item in list do
		table.insert(out, item.uid)
	end
	return out
end

local function good(text: string): string
	return ` <font color="{GOOD}">({text})</font>`
end
local function bad(text: string): string
	return ` <font color="{BAD}">({text})</font>`
end
local SAME_TEXT = ` <font color="{SAME}">(=)</font>`

local function withRole(lines: { TooltipModel.Line }, role: string): { TooltipModel.Line }
	local out: { TooltipModel.Line } = {}
	for _, line in lines do
		if line.role == role then
			table.insert(out, line)
		end
	end
	return out
end

local function texts(lines: { TooltipModel.Line }): { string }
	local out: { string } = {}
	for _, line in lines do
		table.insert(out, line.text)
	end
	return out
end

local WARRIOR = { classId = "Warrior", level = 60 }

T.describe("ItemCompare.replaced (owner 2026-10-31)", function()
	T.it(
		"the worn item of the slot; nothing for an empty slot, a worn item or another class; a too high level is compared",
		function()
			local sword = made("sword1h_30", "new")
			local worn = made("sword1h_30", "worn")
			local gear = { weapon = worn }
			T.expect(uids(ItemCompare.replaced(sword, gear, WARRIOR))).toEqual({ "worn" })
			T.expect(ItemCompare.replaced(sword, {}, WARRIOR)).toBeNil()
			T.expect(ItemCompare.replaced(worn, gear, WARRIOR)).toBeNil()
			T.expect(ItemCompare.replaced(sword, gear, { classId = "Mage", level = 60 })).toBeNil()
			-- 2026-10-31 (Studio check): a find for later is compared too (its level is red in the head line)
			T.expect(uids(ItemCompare.replaced(sword, gear, { classId = "Warrior", level = 29 }))).toEqual({ "worn" })
			-- a potion or a material is never compared
			T.expect(ItemCompare.replaced(ItemRoll.makeStack("potion_hp_2", 1, "p"), gear, WARRIOR)).toBeNil()
		end
	)

	T.it(
		"rings: the weaker of two worn rings, the same one the equip action replaces; none while a slot is free",
		function()
			local weak = made("ring_30", "weak")
			local strong = made("ring_60", "strong", { { stat = "str", v = 5 } }, 0, Rarities.HEROIC)
			local ring = made("ring_60", "new")
			local def = Items.get("ring_60") :: Items.ItemDef
			T.expect(uids(ItemCompare.replaced(ring, { ring1 = strong, ring2 = weak }, WARRIOR))).toEqual({ "weak" })
			T.expect(ItemCompare.targetSlot(def, { ring1 = strong, ring2 = weak }, WARRIOR)).toBe("ring2")
			T.expect(ItemCompare.targetSlot(def, { ring1 = weak, ring2 = strong }, WARRIOR)).toBe("ring1")
			T.expect(ItemCompare.replaced(ring, { ring1 = strong }, WARRIOR)).toBeNil()
			T.expect(ItemCompare.targetSlot(def, { ring1 = strong }, WARRIOR)).toBeNil()
			T.expect(ItemCompare.targetSlot(Items.get("sword1h_30") :: Items.ItemDef, { ring1 = strong }, WARRIOR))
				.toBeNil()
			-- a worn ring is not compared with the other one
			T.expect(ItemCompare.replaced(strong, { ring1 = strong, ring2 = weak }, WARRIOR)).toBeNil()
		end
	)

	T.it("a two-hander also takes the off-hand; an off-hand under a two-hander is not compared", function()
		local sword = made("sword1h_30", "sword")
		local shield = made("shield_50", "shield")
		local axe = made("axe2h_50", "axe")
		T.expect(uids(ItemCompare.replaced(axe, { weapon = sword, offhand = shield }, WARRIOR)))
			.toEqual({ "sword", "shield" })
		T.expect(uids(ItemCompare.replaced(axe, { offhand = shield }, WARRIOR))).toEqual({ "shield" })
		local other = made("shield_50", "other")
		T.expect(ItemCompare.comparable(other, { weapon = axe }, WARRIOR)).toBe(false)
		T.expect(ItemCompare.replaced(other, { weapon = axe, offhand = shield }, WARRIOR)).toBeNil()
		T.expect(uids(ItemCompare.replaced(made("sword1h_30", "new"), { weapon = axe }, WARRIOR))).toEqual({ "axe" })
	end)

	T.it("a backpack compares with the worn backpack", function()
		local worn = made("backpack_30", "worn")
		local bag = made("backpack_45", "new")
		T.expect(uids(ItemCompare.replaced(bag, { backpack = worn }, WARRIOR))).toEqual({ "worn" })
		T.expect(ItemCompare.worn({ worn }).capacity).toBe((Items.get("backpack_30") :: Items.ItemDef).capacity)
	end)

	T.it("worn sums base stats and lines of every item (lines by id, in their order) and keeps the weapon", function()
		local sword = made("sword1h_30", "sword", { { stat = "str", v = 3 }, { stat = "dex", v = 2 } })
		local shield = made("shield_50", "shield", { { stat = "str", v = 4 } })
		local worn = ItemCompare.worn({ sword, shield })
		local shieldStats = ItemRoll.itemStats(shield)
		local weapon = ItemRoll.itemStats(sword).weapon :: any
		T.expect(worn.base.armor).toBe(shieldStats.base.armor)
		T.expect(worn.lines.str).toEqual({ 3, 4 })
		T.expect(worn.lineOrder).toEqual({ "str", "dex" })
		T.expect(worn.weapon).toEqual({
			dmg = weapon.dmg,
			mdmg = weapon.mdmg,
			speed = weapon.speed,
			dps = TooltipModel.dps(weapon),
		})
		T.expect(worn.ilvl).toBe(sword.ilvl)
	end)

	T.it("change is rounded to the written places", function()
		T.expect(ItemCompare.change(1.2, 1.1, 2)).toBe(0.1)
		T.expect(ItemCompare.change(5, 5, 0)).toBe(0)
		T.expect(ItemCompare.change(72, 80, 0)).toBe(-8)
		T.expect(ItemCompare.change(2.04, 2, 1)).toBe(0)
	end)
end)

T.describe("TooltipModel with the comparison (owner 2026-10-31)", function()
	local function ctx(compare: { any }?, extra: { [string]: any }?): TooltipModel.Ctx
		local c: any = { lang = "pl", class = "Warrior", level = 60, compare = compare }
		for k, v in extra or {} do
			c[k] = v
		end
		return c
	end

	T.it("an upgraded sword: more damage and DPS in green, the same speed in grey, full and compact", function()
		local better = made("sword1h_30", "new", {}, 5)
		local worn = made("sword1h_30", "worn")
		local b = ItemRoll.itemStats(better).weapon :: any
		local w = ItemRoll.itemStats(worn).weapon :: any
		local lines = TooltipModel.build(better, nil, ctx({ worn }, { equipped = worn })).lines
		local main = withRole(lines, "stat")[1]
		T.expect(main.main).toBe(true)
		T.expect(main.text).toBe(Locale.T("tooltip.damage", { dmg = b.dmg }, "pl") .. good(`+{b.dmg - w.dmg}`))
		local dps = TooltipModel.dps(b)
		local diff = math.floor(dps * 10 + 0.5) / 10 - math.floor(TooltipModel.dps(w) * 10 + 0.5) / 10
		local speed = Locale.T("tooltip.speed", { speed = TooltipModel.decimal(b.speed, 2, "pl") }, "pl")
		local dpsText = Locale.T("tooltip.dps", { dps = TooltipModel.decimal(dps, 1, "pl") }, "pl")
		T.expect(withRole(lines, "speedDps")[1].text)
			.toBe(`{speed}{SAME_TEXT} · {dpsText}{good("+" .. TooltipModel.decimal(diff, 1, "pl"))}`)
		T.expect(withRole(lines, "ilvl")[1].text)
			.toBe(Locale.T("tooltip.ilvl", { ilvl = better.ilvl }, "pl") .. SAME_TEXT)
		-- what it is compared with is said once, below the numbers
		T.expect(texts(withRole(lines, "replaces")))
			.toEqual({ Locale.T("tooltip.replaces", { item = ItemName.get("pl", worn.id, worn.up) }, "pl") })
		local short = TooltipModel.build(better, nil, ctx({ worn }, { view = "compact" })).lines
		local compactDps = Locale.T("tooltip.compact.dps", { dps = TooltipModel.decimal(dps, 1, "pl") }, "pl")
		T.expect(withRole(short, "mainShort")[1].text).toBe(
			`{Locale.T("tooltip.damage", { dmg = b.dmg }, "pl")}{good(`+{b.dmg - w.dmg}`)} · {compactDps}{good(
				"+" .. TooltipModel.decimal(diff, 1, "pl")
			)}`
		)
		-- a worse one: red
		local worse = TooltipModel.build(worn, nil, ctx({ better })).lines
		T.expect(withRole(worse, "stat")[1].text)
			.toBe(Locale.T("tooltip.damage", { dmg = w.dmg }, "pl") .. bad(`-{b.dmg - w.dmg}`))
	end)

	T.it(
		"lines against the same lines (the n-th against the n-th); the worn item's other lines are red losses",
		function()
			local ring =
				made("ring_60", "new", { { stat = "str", v = 5 }, { stat = "dex", v = 3 }, { stat = "str", v = 2 } })
			local worn = made("ring_60", "worn", {
				{ stat = "str", v = 7 },
				{ stat = "critChance", v = 2.5 },
				{ stat = "costReduce", v = 2.5 },
				{ stat = "pierce", v = 3.5 },
			})
			local lines = TooltipModel.build(ring, nil, ctx({ worn })).lines
			local bonus = texts(withRole(lines, "bonus"))
			T.expect(bonus).toEqual({
				TooltipModel.bonusText("pl", "str", 5) .. bad("-2"),
				TooltipModel.bonusText("pl", "str", 2) .. good("+2"),
				TooltipModel.bonusText("pl", "dex", 3) .. good("+3"),
			})
			-- the same base stats of two rings of one level: grey
			for _, line in withRole(lines, "stat") do
				if not line.main then
					T.expect({ line.text, string.sub(line.text, -#SAME_TEXT) }).toEqual({ line.text, SAME_TEXT })
				end
			end
			local lost = withRole(lines, "lost")
			local lostTexts = texts(lost)
			table.sort(lostTexts)
			local expected = {
				"-2,5% Szansy na krytyk",
				"+2,5% kosztu umiejętności",
				"Przebicie pancerza -3,5%",
			}
			table.sort(expected)
			T.expect(lostTexts).toEqual(expected)
			for _, line in lost do
				T.expect({ line.tone, line.kind, line.detail == nil, line.size })
					.toEqual({ "bad", "text", true, "small" })
			end
			-- the losses stand among the statistics (before the rarity bonus and the footer)
			local first: { [string]: number } = {}
			for index, line in lines do
				first[line.role] = first[line.role] or index
			end
			for index, line in lines do
				if line.role == "lost" then
					T.expect(index > first.head and index < first.bind).toBe(true)
				end
			end
		end
	)

	T.it("a two-hander against a sword and a shield: the shield's armour and life are lost rows", function()
		local axe = made("axe2h_50", "axe")
		local sword = made("sword1h_30", "sword")
		local shield = made("shield_50", "shield")
		local lines = TooltipModel.build(axe, nil, ctx({ sword, shield }, { offhand = shield, equipped = sword })).lines
		local shieldStats = ItemRoll.itemStats(shield)
		local lost = texts(withRole(lines, "lost"))
		T.expect(#lost).toBe(2)
		local joined = TooltipModel.plain(table.concat(lost, "\n"))
		T.expect(string.find(joined, `-{shieldStats.base.armor}`, 1, true) ~= nil).toBe(true)
		T.expect(string.find(joined, Locale.T("stat.armor", nil, "pl"), 1, true) ~= nil).toBe(true)
		-- the damage against the sword's
		local a = ItemRoll.itemStats(axe).weapon :: any
		local s = ItemRoll.itemStats(sword).weapon :: any
		T.expect(withRole(lines, "stat")[1].text)
			.toBe(Locale.T("tooltip.damage", { dmg = a.dmg }, "pl") .. good(`+{a.dmg - s.dmg}`))
	end)

	T.it("a kind of damage only the worn weapon deals is a red part (full and compact)", function()
		local sword = made("sword1h_30", "sword")
		local mace = made("mace1h_30", "mace")
		local m = ItemRoll.itemStats(mace).weapon :: any
		local s = ItemRoll.itemStats(sword).weapon :: any
		local lines = TooltipModel.build(sword, nil, ctx({ mace })).lines
		local main = withRole(lines, "stat")
		local lostText = Locale.T("tooltip.magicDamage", { mdmg = -m.mdmg }, "pl")
		T.expect({ main[2].text, main[2].tone, main[2].main }).toEqual({ lostText, "bad", true })
		local short = TooltipModel.build(sword, nil, ctx({ mace }, { view = "compact" })).lines
		local text = withRole(short, "mainShort")[1].text
		T.expect(string.find(text, `<font color="{BAD}">{lostText}</font>`, 1, true) ~= nil).toBe(true)
		T.expect(string.find(text, Locale.T("tooltip.damage", { dmg = s.dmg }, "pl") .. SAME_TEXT, 1, true) ~= nil)
			.toBe(true)
	end)

	T.it("a backpack shows the change of its capacity", function()
		local bag = made("backpack_45", "new")
		local worn = made("backpack_30", "worn")
		local capacity = (Items.get("backpack_45") :: Items.ItemDef).capacity :: number
		local old = (Items.get("backpack_30") :: Items.ItemDef).capacity :: number
		local effect = withRole(TooltipModel.build(bag, nil, ctx({ worn })).lines, "effect")[1]
		T.expect(effect.text)
			.toBe(Locale.T("tooltip.capacity", { capacity = capacity }, "pl") .. good(`+{capacity - old}`))
	end)

	T.it("nothing to compare: the lines are the same as without a comparison", function()
		local sword = made("sword1h_30", "new", { { stat = "str", v = 3 } }, 2)
		local plain = texts(TooltipModel.build(sword, nil, ctx(nil)).lines)
		T.expect(texts(TooltipModel.build(sword, nil, ctx({})).lines)).toEqual(plain)
		-- compared with itself (a worn item): no changes
		T.expect(texts(TooltipModel.build(sword, nil, ctx({ sword })).lines)).toEqual(plain)
		local potion = ItemRoll.makeStack("potion_hp_2", 1, "p")
		T.expect(texts(TooltipModel.build(potion, nil, ctx({ made("sword1h_30", "worn") })).lines))
			.toEqual(texts(TooltipModel.build(potion, nil, ctx(nil)).lines))
		for _, line in TooltipModel.build(sword, nil, ctx(nil)).lines do
			T.expect(string.find(line.text, GOOD, 1, true)).toBeNil()
		end
	end)

	-- 2026-10-31 (Studio check: a Warrior's sword shown to a Mage said "Zastąpi: <the Mage's staff>")
	T.it("another class: no changes and no 'Replaces'; a too high level: compared, its level red", function()
		local sword = made("sword1h_30", "new", { { stat = "str", v = 3 } }, 2)
		local staff = made("staff_30", "staff")
		local shield = made("shield_50", "shield")
		local mage = TooltipModel.build(sword, nil, ctx({ staff }, { class = "Mage", equipped = staff })).lines
		T.expect(texts(mage)).toEqual(texts(TooltipModel.build(sword, nil, ctx(nil, { class = "Mage" })).lines))
		T.expect(#withRole(mage, "replaces")).toBe(0)
		local offhand = TooltipModel.build(shield, nil, ctx(nil, { class = "Mage", mainHand = staff })).lines
		T.expect(#withRole(offhand, "compareNote")).toBe(0)
		-- level 20 against a level 30 sword: the changes are there and the level part of the head line is red
		local worn = made("sword1h_30", "worn")
		local low = TooltipModel.build(sword, nil, ctx({ worn }, { level = 20, equipped = worn })).lines
		T.expect(#withRole(low, "replaces")).toBe(1)
		T.expect(string.find(withRole(low, "stat")[1].text, GOOD, 1, true) ~= nil).toBe(true)
		T.expect(string.find(withRole(low, "head")[1].text, TooltipModel.BAD_HEX, 1, true) ~= nil).toBe(true)
	end)

	T.it("an identical copy: every number grey '(=)', nothing green or red, no loss rows", function()
		for _, id in { "sword1h_30", "ring_60", "shield_50", "armor_heavy_60", "staff_30" } do
			local bonuses = { { stat = "str", v = 4 }, { stat = "critChance", v = 1.5 } }
			local item = made(id, "new", bonuses, 3, Rarities.HEROIC)
			local copy = made(id, "copy", bonuses, 3, Rarities.HEROIC)
			local def = Items.get(id) :: Items.ItemDef
			local class = if def.classes then def.classes[1] else "Warrior"
			for _, view in { "full", "compact" } do
				local lines = TooltipModel.build(item, nil, ctx({ copy }, { class = class, view = view })).lines
				local same = 0
				for _, line in lines do
					T.expect({ id, view, line.role, string.find(line.text, GOOD, 1, true) })
						.toEqual({ id, view, line.role, nil })
					T.expect({ id, view, line.role, string.find(line.text, BAD, 1, true) })
						.toEqual({ id, view, line.role, nil })
					local at = string.find(line.text, SAME_TEXT, 1, true)
					while at do
						same += 1
						at = string.find(line.text, SAME_TEXT, at + 1, true)
					end
					if line.role == "bonus" or (line.role == "stat" and not line.main) then
						T.expect({ id, view, string.sub(line.text, -#SAME_TEXT) }).toEqual({ id, view, SAME_TEXT })
					end
				end
				T.expect({ id, view, #withRole(lines, "lost") }).toEqual({ id, view, 0 })
				T.expect({ id, view, same >= 2 }).toEqual({ id, view, true })
			end
		end
	end)

	T.it("English: the same changes with a decimal point", function()
		local better = made("sword1h_30", "new", {}, 5)
		local worn = made("sword1h_30", "worn")
		local line = withRole(TooltipModel.build(better, nil, ctx({ worn }, { lang = "en" })).lines, "speedDps")[1]
		T.expect(string.find(TooltipModel.plain(line.text), "%(%+%d+%.%d%)$") ~= nil).toBe(true)
	end)

	T.it("the compact view keeps its line cap with a comparison against another rolled item of the type", function()
		local byType: { [string]: string } = {}
		for id, def in Items.byId do
			if def.category == "equipment" and def.level == 60 and def.tier and not def.fixedBonuses then
				local known = byType[def.type or id]
				if not known or id < known then
					byType[def.type or id] = id
				end
			end
		end
		for _, id in byType do
			local def = Items.get(id) :: Items.ItemDef
			for _, rarity in { Rarities.LEGENDARY, Rarities.MYTHIC } do
				local item: any = ItemRoll.rollItem(id, 60, rarity, Rng.new(7), `{id}:{rarity}`)
				local other: any = ItemRoll.rollItem(id, 60, rarity, Rng.new(11), `{id}:{rarity}:worn`)
				item.up, other.up = 3, 0
				local c = ctx({ other }, {
					class = if def.classes and def.classes[1] then def.classes[1] else "Warrior",
					input = "mouse",
					detailsKey = "Alt",
					view = "compact",
				})
				local lines = TooltipModel.build(item, nil, c).lines
				local cap = TooltipModel.COMPACT_MAX_LINES + (if rarity == Rarities.MYTHIC then 1 else 0)
				T.expect({ id, rarity, #lines <= cap }).toEqual({ id, rarity, true })
			end
		end
	end)
end)
