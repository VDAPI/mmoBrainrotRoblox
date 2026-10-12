--!strict
-- Diagnostic (balance 20-100, items): prints markdown tables. Read-only use of the game's modules + tests/Balance.
-- Run from the repo root: lune run tools/diag_items.luau [section]

local process = require("@lune/process")

local B = require("../tests/Balance")
local Bases = require("../src/shared/Data/Items/Bases")
local Bonuses = require("../src/shared/Data/Bonuses")
local Items = require("../src/shared/Data/Items")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Rarities = require("../src/shared/Data/Rarities")

local LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
local only = process.args[1]

local function pct(x: number): string
	return string.format("%+.1f%%", x * 100)
end
local function f1(x: number): string
	return string.format("%.1f", x)
end
local function f2(x: number): string
	return string.format("%.2f", x)
end
local function int(x: number): string
	local n = math.floor(x + 0.5)
	local s = tostring(math.abs(n))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	out = string.gsub(out, "^ ", "")
	return (if n < 0 then "-" else "") .. out
end

local function header(cols: { string })
	print("| " .. table.concat(cols, " | ") .. " |")
	local sep = {}
	for i = 1, #cols do
		sep[i] = if i == 1 then "---" else "--:"
	end
	print("| " .. table.concat(sep, " | ") .. " |")
end
local function row(cells: { string })
	print("| " .. table.concat(cells, " | ") .. " |")
end

local function want(name: string): boolean
	return only == nil or only == name
end

-- A. Rarity power -------------------------------------------------------------------------------------------
if want("rarity") then
	print("\n## A. Rarity power of a full set vs Common (same ilvl = level - 2)\n")
	header({ "class", "level", "Unique", "Heroic", "Legendary", "Mythic", "Leg base only", "Leg bonuses only", "Myth base only" })
	for _, c in B.CLASSES do
		for _, L in LEVELS do
			local base = B.power(B.player(c, L))
			local function g(r: number, opts: any?): number
				local o = table.clone(opts or {})
				o.rarity = r
				return B.power(B.player(c, L, o)) / base - 1
			end
			local baseNoBonus = B.power(B.player(c, L, { bonuses = false }))
			local legBase = B.power(B.player(c, L, { rarity = 4, bonuses = false })) / baseNoBonus - 1
			local mythBase = B.power(B.player(c, L, { rarity = 5, bonuses = false })) / baseNoBonus - 1
			local leg = g(4)
			row({ c, tostring(L), pct(g(2)), pct(g(3)), pct(leg), pct(g(5)), pct(legBase), pct((1 + leg) / (1 + legBase) - 1), pct(mythBase) })
		end
	end
end

-- B. 2H vs 1H + off-hand --------------------------------------------------------------------------------------
if want("weapons") then
	print("\n## B. Weapon choice: DPS x eHP (power^2) vs the class default loadout (Common, ilvl = level - 2)\n")
	local cases = {
		{ "Warrior", "sword2h", false },
		{ "Warrior", "axe2h", false },
		{ "Warrior", "hammer2h", false },
		{ "Warrior", "spear2h", false },
		{ "Warrior", "axe1h", "shield" },
		{ "Warrior", "saber1h", "shield" },
		{ "Warrior", "mace1h", "shield" },
		{ "Hunter", "crossbow", "quiver" },
		{ "Hunter", "shortbow", "quiver" },
		{ "Hunter", "longbow", "quiver" },
		{ "Hunter", "heavycrossbow", "quiver" },
		{ "Mage", "staff", false },
		{ "Mage", "runestaff", false },
		{ "Mage", "wand", "tome" },
		{ "Cleric", "holystaff", false },
		{ "Cleric", "mace1h", "relic" },
		{ "Cleric", "scepter", "shield" },
		{ "Cleric", "flail1h", "shield" },
	}
	local cols = { "weapon" }
	local SHOW = { 20, 30, 45, 60, 70, 85, 100 }
	for _, L in SHOW do
		table.insert(cols, tostring(L))
	end
	header(cols)
	for _, case in cases do
		local c, w, o = case[1] :: string, case[2] :: string, case[3] :: any
		local cells = { `{c} {w}{if o then " + " .. o else ""}` }
		for _, L in SHOW do
			local base = B.power(B.player(c, L)) ^ 2
			local s = B.power(B.player(c, L, { weapon = w, offhand = o })) ^ 2
			table.insert(cells, f2(s / base))
		end
		row(cells)
	end
	-- Legendary sets (rarity changes the off-hand % share?)
	print("\nSame, all items Legendary:\n")
	header(cols)
	for _, case in cases do
		local c, w, o = case[1] :: string, case[2] :: string, case[3] :: any
		local cells = { `{c} {w}{if o then " + " .. o else ""}` }
		for _, L in SHOW do
			local base = B.power(B.player(c, L, { rarity = 4 })) ^ 2
			local s = B.power(B.player(c, L, { weapon = w, offhand = o, rarity = 4 })) ^ 2
			table.insert(cells, f2(s / base))
		end
		row(cells)
	end
	print("\nSame, all items +9 (Common):\n")
	header(cols)
	for _, case in cases do
		local c, w, o = case[1] :: string, case[2] :: string, case[3] :: any
		local cells = { `{c} {w}{if o then " + " .. o else ""}` }
		for _, L in SHOW do
			local base = B.power(B.player(c, L, { up = 9 })) ^ 2
			local s = B.power(B.player(c, L, { weapon = w, offhand = o, up = 9 })) ^ 2
			table.insert(cells, f2(s / base))
		end
		row(cells)
	end
end

-- C. Jewellery, armour weights, HP -----------------------------------------------------------------------------
if want("jewel") then
	print("\n## C. Jewellery share and class HP (Common, ilvl = level - 2)\n")
	header({ "level", "War jew", "Hun jew", "Mag jew", "Cle jew", "War HP", "Hun HP", "Mag HP", "Cle HP", "Mag/War HP", "Cleric light vs heavy power" })
	for _, L in LEVELS do
		local cells = { tostring(L) }
		for _, c in B.CLASSES do
			local with = B.power(B.player(c, L))
			local without = B.power(B.player(c, L, { jewellery = false }))
			table.insert(cells, pct(with / without - 1))
		end
		local hp = {}
		for _, c in B.CLASSES do
			hp[c] = B.player(c, L).values.maxHp
			table.insert(cells, int(hp[c]))
		end
		table.insert(cells, f2(hp.Mage / hp.Warrior))
		-- Cleric in light armour instead of heavy
		local saved = B.LOADOUT.Cleric
		local heavy = B.power(B.player("Cleric", L))
		B.LOADOUT.Cleric = { weapon = saved.weapon, offhand = saved.offhand, weight = "light" }
		local light = B.power(B.player("Cleric", L))
		B.LOADOUT.Cleric = saved
		table.insert(cells, pct(light / heavy - 1))
		row(cells)
	end
	print("\nItem share of max HP and of attack (Common set, level - 2):\n")
	header({ "level", "War HP from items", "Mag HP from items", "War physAtk from items", "Mag magAtk from items", "War DPS no-gear ratio" })
	for _, L in LEVELS do
		local w = B.player("Warrior", L)
		local wNo = B.player("Warrior", L, { armor = false, jewellery = false, offhand = false })
		local m = B.player("Mage", L)
		local mNo = B.player("Mage", L, { armor = false, jewellery = false, offhand = false })
		row({
			tostring(L),
			pct(1 - wNo.values.maxHp / w.values.maxHp),
			pct(1 - mNo.values.maxHp / m.values.maxHp),
			pct(1 - wNo.values.physAtk / w.values.physAtk),
			pct(1 - mNo.values.magAtk / m.values.magAtk),
			"",
		})
	end
end

-- D. Bonus value per line vs level ------------------------------------------------------------------------------
if want("bonus") then
	print("\n## D. Power of one expected (mid-roll, Unique) bonus line added to a Common set\n")
	local stats = { "str", "dex", "int", "vit", "hp", "hpPct", "physAtk", "magAtk", "armor", "mres", "critChance", "critDmg", "atkSpeed", "armorPen", "dodge" }
	local SHOW = { 20, 40, 60, 80, 100 }
	for _, c in { "Warrior", "Mage" } do
		print(`\n{c}:\n`)
		local cols = { "bonus" }
		for _, L in SHOW do
			table.insert(cols, `value@{L - 2}`)
			table.insert(cols, `power@{L}`)
		end
		header(cols)
		for _, id in stats do
			local cells = { id }
			for _, L in SHOW do
				local items = B.gear(c, L)
				local base = B.power(B.playerFromItems(c, L, items))
				local v = ItemRoll.rollBonusValue(id, L - 2, 2, 0.5)
				local extra = table.clone(items)
				table.insert(extra, {
					uid = "x",
					id = "ring_1",
					rarity = 1,
					ilvl = 1,
					bonuses = { { stat = id, v = v } },
					up = 0,
					bound = false,
					n = 1,
				})
				-- remove the ring_1 base contribution by computing with and without an empty ring_1
				local empty = table.clone(items)
				table.insert(empty, {
					uid = "y",
					id = "ring_1",
					rarity = 1,
					ilvl = 1,
					bonuses = {},
					up = 0,
					bound = false,
					n = 1,
				})
				local p0 = B.power(B.playerFromItems(c, L, empty))
				local p1 = B.power(B.playerFromItems(c, L, extra))
				table.insert(cells, tostring(v))
				table.insert(cells, pct(p1 / p0 - 1))
				local _ = base
			end
			row(cells)
		end
	end
	print("\nScaling factors (ItemRoll.scaleFor) vs item base curve (6 + 2.2 L):\n")
	header({ "ilvl", "flat 1+L/20", "curve (6+2.2L)/8.2", "pct 1+L/60", "weapon dmg sword1h", "War main stat (points)", "Mage main stat" })
	for _, L in { 1, 20, 40, 60, 80, 100 } do
		local sword = (Bases.byType.sword1h.weapon :: any)(L)
		local wStats = B.statsFor("Warrior", math.max(1, L))
		local mStats = B.statsFor("Mage", math.max(1, L))
		row({ tostring(L), f2(1 + L / 20), f2((6 + 2.2 * L) / 8.2), f2(1 + L / 60), tostring(sword.dmg), tostring(wStats.str), tostring(mStats.int) })
	end
end

-- SECTION2
return nil
