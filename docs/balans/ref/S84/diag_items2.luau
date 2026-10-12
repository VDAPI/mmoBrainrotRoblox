--!strict
-- Diagnostic (balance 20-100, items) part 2: economy of items. lune run tools/diag_items2.luau [section]

local process = require("@lune/process")

local B = require("../tests/Balance")
local Areas = require("../src/shared/Data/Areas")
local Crafting = require("../src/shared/Data/Crafting")
local E = require("./diag_econ")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Loot = require("../src/shared/Logic/Loot")
local LootTables = require("../src/shared/Data/LootTables")
local Monsters = require("../src/shared/Data/Monsters")
local Rarities = require("../src/shared/Data/Rarities")
local Recipes = require("../src/shared/Data/Recipes")
local Shops = require("../src/shared/Data/Shops")
local Upgrade = require("../src/shared/Logic/Upgrade")
local ItemRoll = require("../src/shared/Logic/ItemRoll")

local LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
local only = process.args[1]

local function pct(x: number): string
	return string.format("%+.1f%%", x * 100)
end
local function pc0(x: number): string
	return string.format("%.0f%%", x * 100)
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

local function item(defId: string, ilvl: number, rarity: number, up: number?, bonuses: { any }?): any
	return { uid = "m", id = defId, rarity = rarity, ilvl = ilvl, bonuses = bonuses or {}, up = up or 0, bound = false, n = 1, rv = 2 }
end

-- Income -------------------------------------------------------------------------------------------------------
if want("income") then
	print("\n## Income model (Warrior, extended S32 pace: usual kind of the level, its loot table, main story)\n")
	header({ "level", "kind", "kills", "h/level", "gold/kill", "drop/kill", "drop/kill gold", "quest gold", "income of level", "gold/h", "rest share" })
	for _, L in LEVELS do
		local l = math.min(L, 99)
		local p = E.pace("Warrior", l)
		row({ tostring(l), p.kind, int(p.kills), f2(p.hours), f1(p.goldPerKill), f1(p.dropPerKill), pc0(p.dropPerKill / p.goldPerKill), int(p.questGold), int(p.income), int(p.goldPerHour), pc0(p.restShare) })
	end
	local total = { 0, 0, 0, 0 }
	for i, band in E.BANDS do
		for l = band[1], band[2] do
			total[i] += E.pace("Warrior", l).income
		end
	end
	print(`\nIncome per region band (Warrior): 1-19 {int(total[1])}, 20-44 {int(total[2])}, 45-69 {int(total[3])}, 70-99 {int(total[4])}`)
end

-- Upgrades -----------------------------------------------------------------------------------------------------
-- Expected cost of +from -> +to: protected (scroll every attempt, failure keeps the level) and unprotected
-- (failure drops one level: Markov chain).
local SCROLL = Recipes.get("scroll_protection") :: any
local function upgradeChain(it: any, to: number, protect: boolean): (number, { [string]: number }, number)
	-- E[k] = expected attempts-weighted cost to go from +k-1 to +k for the first time.
	local gold, mats, scrolls = 0, {} :: { [string]: number }, 0
	local prevGold, prevMats, prevScrolls = 0, {} :: { [string]: number }, 0
	for k = 1, to do
		local cost = Upgrade.cost(it, k)
		local p = Upgrade.chance(k) / 100
		local stepGold, stepMats, stepScrolls
		if protect or k == 1 then
			stepGold = cost.gold / p
			stepScrolls = if protect and p < 1 then 1 / p else 0
			stepMats = {}
			for _, m in cost.materials do
				stepMats[m.id] = m.n / p
			end
		else
			-- E_k = (c_k + (1 - p) E_{k-1}) / p
			stepGold = (cost.gold + (1 - p) * prevGold) / p
			stepScrolls = 0
			stepMats = {}
			for _, m in cost.materials do
				stepMats[m.id] = (stepMats[m.id] or 0) + m.n / p
			end
			for id, n in prevMats do
				stepMats[id] = (stepMats[id] or 0) + (1 - p) * n / p
			end
		end
		gold += stepGold
		scrolls += stepScrolls
		for id, n in stepMats do
			mats[id] = (mats[id] or 0) + n
		end
		prevGold, prevMats, prevScrolls = stepGold, stepMats, stepScrolls
	end
	local _ = prevScrolls
	return gold, mats, scrolls
end

local MAT_GOLD = {
	-- gold to obtain one unit when not farmed: merchant price for dust (40), alchemy for shard / crystal
	essence_dust = 40,
	essence_shard = 10 * 40 + 50, -- 10 dust + 50 gold (transmute_shard)
	essence_crystal = 8 * (10 * 40 + 50) + 300, -- 8 shards + 300 gold
	legend_core = 0, -- no gold source (dismantle Legendary/Mythic, bosses)
}

if want("upgrade") then
	print("\n## Upgrade cost per step (Logic/Upgrade, Config.Upgrade), weapon ilvl = level - 2\n")
	header({ "ilvl", "gold/ilvl k", "+1", "+3", "+4", "+6", "+7", "+9", "mats +1..+3", "mats +4..+6", "mats +7..+9" })
	for _, L in { 18, 19, 20, 21, 22, 23, 25, 28, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 98, 100 } do
		local it = item("sword1h_1", L, 1)
		local c = function(n: number): number
			return Upgrade.cost(it, n).gold
		end
		row({ tostring(L), f2(Upgrade.goldPerIlvl(L)), int(c(1)), int(c(3)), int(c(4)), int(c(6)), int(c(7)), int(c(9)), "2/4/6 dust", "4/5/6 shard", "2/3/4 crystal (+1 core Leg/Myth)" })
	end

	print("\n### Expected total cost vs the gold of a level (Warrior income model)\n")
	header({ "level", "weapon ilvl", "income of level", "+1..+3 (prot.)", "/income", "+1..+6 (prot.)", "/income", "+1..+9 (prot.)", "/income", "+1..+9 unprot.", "+1..+9 full set unprot.", "full set +1..+9 / income" })
	for _, L in LEVELS do
		local l = math.min(L, 99)
		local p = E.pace("Warrior", l)
		local ilvl = L - 2
		local it = item("sword1h_1", ilvl, 1)
		local g3 = B.upgradeGold(ilvl, 3)
		local g6 = B.upgradeGold(ilvl, 6)
		local g9 = B.upgradeGold(ilvl, 9)
		local u9 = upgradeChain(it, 9, false)
		local set = u9 * 10 -- 10 pieces at the same ilvl (cost does not depend on slot)
		row({ tostring(L), tostring(ilvl), int(p.income), int(g3), f2(g3 / p.income), int(g6), f2(g6 / p.income), int(g9), f2(g9 / p.income), int(u9), int(set), f1(set / p.income) })
	end

	print("\n### Expected materials and scrolls of +1..+9 (one item) and their gold equivalent\n")
	header({ "ilvl", "prot: dust", "shard", "crystal", "core (Leg+)", "scrolls", "unprot: dust", "shard", "crystal", "core (Leg+)", "mats gold-eq (unprot.)", "gold (unprot.)", "mats share" })
	for _, ilvl in { 18, 38, 58, 78, 98 } do
		local it = item("sword1h_1", ilvl, 4)
		local gp, mp, sp = upgradeChain(it, 9, true)
		local gu, mu = upgradeChain(it, 9, false)
		local eq = 0
		for id, n in mu do
			eq += n * (MAT_GOLD[id] or 0)
		end
		local _ = gp
		row({
			tostring(ilvl),
			f1(mp.essence_dust or 0), f1(mp.essence_shard or 0), f1(mp.essence_crystal or 0), f1(mp.legend_core or 0), f1(sp),
			f1(mu.essence_dust or 0), f1(mu.essence_shard or 0), f1(mu.essence_crystal or 0), f1(mu.legend_core or 0),
			int(eq), int(gu), pc0(eq / (eq + gu)),
		})
	end
	print(`\nProtection scroll (alchemy): {SCROLL.gold} gold + 2 shards + 2 moonpetal; MAT_GOLD dust {MAT_GOLD.essence_dust}, shard {MAT_GOLD.essence_shard}, crystal {MAT_GOLD.essence_crystal}`)

	print("\n### Power of upgrades (Warrior / Mage, Common set at level - 2)\n")
	header({ "level", "War weapon +1", "War weapon +9", "War full set +3", "War full set +9", "Mage weapon +9", "Mage full set +9", "War +9 set vs Legendary +0 set" })
	for _, L in { 20, 40, 60, 80, 100 } do
		local function weaponUp(c: string, n: number): number
			local items = B.gear(c, L)
			local base = B.power(B.playerFromItems(c, L, items))
			local up = table.clone(items)
			up[1] = table.clone(up[1])
			up[1].up = n
			return B.power(B.playerFromItems(c, L, up)) / base - 1
		end
		local function setUp(c: string, n: number): number
			return B.power(B.player(c, L, { up = n })) / B.power(B.player(c, L)) - 1
		end
		local leg = B.power(B.player("Warrior", L, { rarity = 4 })) / B.power(B.player("Warrior", L)) - 1
		row({ tostring(L), pct(weaponUp("Warrior", 1)), pct(weaponUp("Warrior", 9)), pct(setUp("Warrior", 3)), pct(setUp("Warrior", 9)), pct(weaponUp("Mage", 9)), pct(setUp("Mage", 9)), `{pct(setUp("Warrior", 9))} vs {pct(leg)}` })
	end
end

-- Essence supply ------------------------------------------------------------------------------------------------
if want("essence") then
	print("\n## Essence supply per level (Warrior grind, normal kills only) vs upgrade demand\n")
	header({ "level", "kind", "kills", "dust/kill", "dust/level", "shards/level via transmute", "shards for +4..+6 weapon (prot.)", "crystals for +7..+9 (prot.)" })
	for _, L in LEVELS do
		local l = math.min(L, 99)
		local p = E.pace("Warrior", l)
		local t = LootTables.byId[p.kind]
		local dust = 0
		for _, m in t.materials do
			if m.id == "essence_dust" then
				dust += m.chance * (m.min + m.max) / 2
			end
		end
		local it = item("sword1h_1", L - 2, 1)
		local _, mats = upgradeChain(it, 9, true)
		row({ tostring(l), p.kind, int(p.kills), f2(dust), f1(dust * p.kills), f1(dust * p.kills / 10), f1(mats.essence_shard or 0), f1(mats.essence_crystal or 0) })
	end
end

-- Weapon merchant and shops -----------------------------------------------------------------------------------
local function shopTier(level: number): number
	local best = 1
	for _, tier in Shops.WEAPONSMITH_TIERS do
		if tier <= level then
			best = tier
		end
	end
	return best
end

if want("shop") then
	print("\n## Weapon merchant (Shops.WEAPONSMITH_TIERS, Common, ilvl = tier, value x 4)\n")
	header({ "tier", "sword1h price", "shield price", "staff price", "income of level (tier)", "weapon+offhand / income" })
	for _, tier in Shops.WEAPONSMITH_TIERS do
		local entry = { item = `sword1h_{Items.generate.tierFor(tier)}`, ilvl = tier, rarity = 1 }
		local sh = { item = `shield_{Items.generate.tierFor(tier)}`, ilvl = tier, rarity = 1 }
		local st = { item = `staff_{Items.generate.tierFor(tier)}`, ilvl = tier, rarity = 1 }
		local ps = ItemValue.buyPrice(entry :: any)
		local psh = ItemValue.buyPrice(sh :: any)
		local pst = ItemValue.buyPrice(st :: any)
		local inc = E.pace("Warrior", math.min(tier, 99)).income
		row({ tostring(tier), int(ps), int(psh), int(pst), int(inc), f2((ps + psh) / inc) })
	end
	print("\n### Shop/crafted gear only (weapon + off-hand from the merchant tier <= level, armour + jewellery at tierFor(level)) vs a monster of the level\n")
	header({ "level", "shop tier", "War s", "War HP", "Hun s", "Hun HP", "Mag s", "Mag HP", "Cle s", "Cle HP" })
	for _, L in LEVELS do
		local cells = { tostring(L), tostring(shopTier(L)) }
		for _, c in B.CLASSES do
			local p = B.player(c, L, { ilvl = Items.generate.tierFor(L), weaponIlvl = shopTier(L) })
			local f = B.duel(p, B.monster(B.GENERIC, L))
			table.insert(cells, f1(f.seconds))
			table.insert(cells, pc0(f.hpLost))
		end
		row(cells)
	end
	print("\n### Worst case inside a band: level just below the next shop tier (weapon 9 levels low)\n")
	header({ "level", "shop tier", "War s", "War HP", "Mag s", "Mag HP", "Cle s", "Cle HP" })
	for _, L in { 24, 34, 44, 54, 64, 74, 84, 94, 100 } do
		local cells = { tostring(L), tostring(shopTier(L)) }
		for _, c in { "Warrior", "Mage", "Cleric" } do
			local p = B.player(c, L, { ilvl = Items.generate.tierFor(L), weaponIlvl = shopTier(L) })
			local f = B.duel(p, B.monster(B.GENERIC, L))
			table.insert(cells, f1(f.seconds))
			table.insert(cells, pc0(f.hpLost))
		end
		row(cells)
	end

	print("\n## Backpacks (Data/Items/Backpacks) vs income\n")
	header({ "backpack", "level", "price", "income of that level", "price / income", "main quest gives it at" })
	local questGives: { [string]: number } = {}
	local Quests = require("../src/shared/Data/Quests")
	for _, q in Quests.Main.list :: any do
		for _, it in q.reward.items or {} do
			if string.sub(it.id, 1, 9) == "backpack_" then
				questGives[it.id] = q.level
			end
		end
	end
	for _, id in { "backpack_80", "backpack_100", "backpack_130", "backpack_160", "backpack_200" } do
		local def = Items.get(id) :: any
		local inc = E.pace("Warrior", def.level).income
		row({ id, tostring(def.level), int(def.buyPrice), int(inc), f2(def.buyPrice / inc), tostring(questGives[id] or "-") })
	end

	print("\n## Potions (healer) vs Warrior HP and gold per hour\n")
	header({ "level", "War HP", "potion_hp_3 (1500) % HP", "potion_hp_4 (4000) % HP", "potion_hp_5 (10000) % HP", "cheapest full heal gold", "gold/h" })
	for _, L in { 20, 40, 60, 80, 100 } do
		local hp = B.player("Warrior", L).values.maxHp
		local best = math.huge
		for q = 1, 5 do
			local def = Items.get(`potion_hp_{q}`) :: any
			best = math.min(best, math.ceil(hp / def.use.amount) * def.buyPrice)
		end
		local p = E.pace("Warrior", math.min(L, 99))
		row({ tostring(L), int(hp), pc0(1500 / hp), pc0(4000 / hp), pc0(10000 / hp), int(best), int(p.goldPerHour) })
	end
end

-- Crafting ----------------------------------------------------------------------------------------------------
if want("craft") then
	print("\n## Blacksmith crafting (Data/Crafting): gold + ore (+ dust from tier 30)\n")
	local orePrice: { [string]: number } = {}
	for _, e in (Shops.get("blacksmith") :: any).entries do
		orePrice[e.item] = e.price
	end
	header({ "tier", "weapon gold", "chest gold", "ore", "ore n", "ore buyable at", "dust n", "weapon total gold-eq", "merchant weapon price", "full set (10) gold-eq", "income of level", "set / income" })
	for _, tier in { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 } do
		local w = Crafting.get(`sword1h_{tier}`) :: any
		local ch = Crafting.get(`armor_heavy_{tier}`) :: any
		local ore, oreN, dustN = "", 0, 0
		for _, m in w.materials do
			if m.id == "essence_dust" then
				dustN = m.n
			else
				ore, oreN = m.id, m.n
			end
		end
		local oreGold = orePrice[ore]
		local function eq(r: any): number
			local g = r.gold
			for _, m in r.materials do
				local unit = orePrice[m.id] or (if m.id == "essence_dust" then 40 else 0)
				if not orePrice[m.id] and m.id ~= "essence_dust" then
					unit = (Items.get(m.id) :: any).price * 4 -- not sold: 4 x value as a guess of trade price
				end
				g += unit * m.n
			end
			return g
		end
		local set = 0
		for _, t in { "sword1h", "shield", "helmet_heavy", "armor_heavy", "gloves_heavy", "boots_heavy", "necklace", "ring", "ring", "talisman" } do
			set += eq(Crafting.get(`{t}_{tier}`) :: any)
		end
		local merchant = if tier % 10 == 5 then int(ItemValue.buyPrice({ item = `sword1h_{tier}`, ilvl = tier, rarity = 1 } :: any)) else "-"
		local inc = E.pace("Warrior", math.min(tier, 99)).income
		row({ tostring(tier), int(w.gold), int(ch.gold), ore, tostring(oreN), if oreGold then tostring(oreGold) else "not sold", tostring(dustN), int(eq(w)), merchant, int(set), int(inc), f2(set / inc) })
	end
end

-- Item values ---------------------------------------------------------------------------------------------------
if want("value") then
	print("\n## Item value / sell price (Logic/ItemValue) vs gold of kills\n")
	header({ "ilvl", "Common weapon", "Unique", "Heroic", "Legendary", "Mythic", "Common +9", "Mythic +9", "kill gold (kind)", "Common weapon / kill gold", "upgrade gold +1..+9 (prot.) / value gain" })
	for _, L in LEVELS do
		local def = Items.get("sword1h_1") :: any
		local v = function(r: number, up: number?): number
			return ItemValue.equipment(def, L, r, up)
		end
		local l = math.min(L, 99)
		local p = E.pace("Warrior", l)
		local up9 = B.upgradeGold(L, 9)
		row({ tostring(L), int(v(1)), int(v(2)), int(v(3)), int(v(4)), int(v(5)), int(v(1, 9)), int(v(5, 9)), f1(p.goldPerKill), f2(v(1) / p.goldPerKill), f1(up9 / (v(1, 9) - v(1))) })
	end
	print("\n### Drop sales per kill: item vs material share\n")
	header({ "level", "kind", "item value/kill", "materials value/kill", "materials share" })
	for _, L in LEVELS do
		local l = math.min(L, 99)
		local kind = E.kindAt(l)
		local total = B.dropValue(l, "normal", kind)
		-- items only: dropValue with a loot table without materials -> recompute materials
		local t = LootTables.byId[kind]
		local mats = 0
		for _, m in t.materials do
			local d = Items.get(m.id) :: any
			mats += m.chance * (m.min + m.max) / 2 * d.price
		end
		row({ tostring(l), kind, f1(total - mats), f1(mats), pc0(mats / total) })
	end
end

-- Drops: item level vs monster level -----------------------------------------------------------------------------
if want("drops") then
	print("\n## Drop item level: caves (elite / Elite II), bosses (Loot.dropBaseLevel, LootRules.dropLevelBelow)\n")
	header({ "cave", "range", "elite kinds (spawner lv)", "elite drop ilvl", "Elite II spawner lv", "Elite II drop ilvl", "Heroic/Leg available for levels" })
	for _, cave in Areas.caves.list do
		local function range(kinds: { string }): (number, number)
			local low, high = math.huge, -math.huge
			for _, id in kinds do
				local def = Monsters.get(id) :: any
				low = math.min(low, def.levels.min)
				high = math.max(high, def.levels.max)
			end
			local mn, mx = math.max(cave.levels[1], low), math.min(cave.levels[2], high)
			if mn > mx then
				return cave.levels[1], cave.levels[2]
			end
			return mn, mx
		end
		local eLo, eHi = math.huge, -math.huge
		for _, k in cave.elites do
			local a, b = range({ k })
			eLo, eHi = math.min(eLo, a), math.max(eHi, b)
		end
		local e2Lo, e2Hi = range({ cave.elite2[1] })
		local dLo = Loot.dropBaseLevel(eLo + 2, "elite", eHi) - 2
		local dHi = Loot.dropBaseLevel(eHi + 2, "elite", eHi)
		local d2Lo = Loot.dropBaseLevel(e2Lo + 4, "elite2", e2Hi) - 2
		local d2Hi = Loot.dropBaseLevel(e2Hi + 4, "elite2", e2Hi)
		row({ cave.id, `{cave.levels[1]}-{cave.levels[2]}`, `{table.concat(cave.elites, ",")} {eLo}-{eHi}`, `{math.max(1, dLo)}-{dHi}`, `{e2Lo}-{e2Hi}`, `{math.max(1, d2Lo)}-{d2Hi}`, "" })
	end
	print("\nBosses: shared loot ilvl = boss level - 0..2, personal Legendary/Mythic = boss level (Loot.personalItems).")
	for id, b in LootTables.bosses do
		print(`- {id}: level {b.level}, named {table.concat(b.named, ", ")}; legendary {b.legendaryChance}+{b.legendaryStep}/kill hard {b.legendaryHard}; mythic {b.mythicChance}+{b.mythicStep} hard {b.mythicHard}`)
	end
	print("\nNormal monsters: ilvl = monster level - 0..2 (ItemRoll.dropLevelRange); mean level - 1 at every level.")
	local lo, hi = ItemRoll.dropLevelRange(60)
	print(`dropLevelRange(60) = {lo}..{hi}`)
end

-- Named boss items -----------------------------------------------------------------------------------------------
if want("uniques") then
	print("\n## Named boss Mythics (Items/Uniques) vs a same-level Legendary / rolled Mythic of the same base\n")
	print("Full Common set of the class at the boss level (ilvl = level), only the item's slot replaced. Power = sqrt(DPS x eHP).\n")
	local cases = {
		{ "unique_grimrok_cleaver", "Warrior", "axe1h", 1 },
		{ "unique_grimrok_fang", "Hunter", "ring", 9 },
		{ "unique_grimrok_totem", "Warrior", "talisman", 10 },
		{ "unique_morvane_shroud", "Mage", "armor_light", 4 },
		{ "unique_morvane_scepter", "Cleric", "scepter", 1 },
		{ "unique_morvane_bow", "Hunter", "bow", 1 },
		{ "unique_azgor_heart", "Warrior", "necklace", 7 },
		{ "unique_azgor_staff", "Mage", "staff", 1 },
		{ "unique_azgor_helm", "Warrior", "helmet_heavy", 3 },
		{ "unique_vaelgrath_fang", "Warrior", "sword2h", 1 },
		{ "unique_vaelgrath_scale", "Warrior", "shield", 2 },
		{ "unique_vaelgrath_eye", "Mage", "orb", 2 },
	}
	-- expected bonuses (copied from tests/Balance: every pool entry gets count / #pool of its mid value)
	local Bonuses = require("../src/shared/Data/Bonuses")
	local function expected(defId: string, ilvl: number, rarity: number, classId: string): { any }
		local rd = Rarities.get(rarity)
		local out = {}
		local pool = ItemRoll.bonusPool(defId, classId)
		local count = (rd.bonusMin + rd.bonusMax) / 2
		if count > 0 and #pool > 0 then
			local share = math.min(1, count / #pool)
			for _, id in pool do
				table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
			end
		end
		if rd.legendaryLines > 0 then
			local leg = Bonuses.pools.legendary
			for _, id in leg do
				table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * rd.legendaryLines / #leg })
			end
		end
		return out
	end
	header({ "item", "class", "boss lv", "vs Common", "Legendary same base", "rolled Mythic same base", "named / Mythic", "named weapon DPS / Mythic DPS", "named @+10 lv vs Heroic of lv-2", "named @+25 lv vs Heroic of lv-2" })
	for _, case in cases do
		local id, c, baseType, slotIndex = case[1] :: string, case[2] :: string, case[3] :: string, case[4] :: number
		local named = Items.get(id) :: any
		local L = named.level
		local function setWith(level: number, replacement: any?, rarity: number?): any
			local opts: any = { ilvl = level, rarity = rarity or 1 }
			if baseType == "sword2h" or baseType == "staff" then
				opts.weapon = baseType
				opts.offhand = false
			elseif slotIndex == 1 then
				opts.weapon = baseType
			end
			local items = B.gear(c, level, opts)
			-- find the slot by def slot
			if replacement then
				local slot = (Items.get(replacement.id) :: any).slot
				local done = false
				for i, it in items do
					local d = Items.get(it.id) :: any
					if d.slot == slot and not done then
						items[i] = replacement
						done = true
					end
				end
				assert(done, `no slot {slot} for {id}`)
			end
			return B.playerFromItems(c, level, items)
		end
		local tid = `{baseType}_{Items.generate.tierFor(L)}`
		local base = B.power(setWith(L))
		local pNamed = B.power(setWith(L, item(id, L, 5)))
		local pLeg = B.power(setWith(L, item(tid, L, 4, 0, expected(tid, L, 4, c))))
		local pMyth = B.power(setWith(L, item(tid, L, 5, 0, expected(tid, L, 5, c))))
		local dpsNote = "-"
		if named.weapon then
			local m = B.monster(B.GENERIC, L)
			local dn = B.dps(setWith(L, item(id, L, 5)), m)
			local dm = B.dps(setWith(L, item(tid, L, 5, 0, expected(tid, L, 5, c))), m)
			dpsNote = f2(dn / dm)
		end
		-- later: player at L + d with Heroic set of level L+d-2, compared with the same set where the slot holds the named item
		local function later(d: number): string
			local lv = math.min(100, L + d)
			if lv == L then
				return "-"
			end
			local heroic = B.power(setWith(lv - 2, nil, 3))
			local items = B.gear(c, lv, { ilvl = lv - 2, rarity = 3, weapon = if slotIndex == 1 or baseType == "sword2h" or baseType == "staff" then baseType else nil, offhand = if baseType == "sword2h" or baseType == "staff" then false else nil })
			local slot = named.slot
			for i, it in items do
				if (Items.get(it.id) :: any).slot == slot then
					items[i] = item(id, L, 5)
					break
				end
			end
			-- heroic set powered at level lv (same player level)
			local ph = B.power(B.playerFromItems(c, lv, B.gear(c, lv, { ilvl = lv - 2, rarity = 3, weapon = if slotIndex == 1 or baseType == "sword2h" or baseType == "staff" then baseType else nil, offhand = if baseType == "sword2h" or baseType == "staff" then false else nil })))
			local pn = B.power(B.playerFromItems(c, lv, items))
			local _ = heroic
			return pct(pn / ph - 1)
		end
		row({ id, c, tostring(L), pct(pNamed / base - 1), pct(pLeg / base - 1), pct(pMyth / base - 1), f2(pNamed / pMyth), dpsNote, later(10), later(25) })
	end
end

-- Materials and parts ---------------------------------------------------------------------------------------------
if want("parts") then
	print("\n## Monster parts per region kind (LootTables PARTS) and their uses\n")
	-- uses: alchemy ingredients and smith materials
	local uses: { [string]: { string } } = {}
	for _, r in Recipes.list do
		for _, ing in r.ingredients do
			uses[ing.id] = uses[ing.id] or {}
			table.insert(uses[ing.id], `{r.id}(L{r.level})`)
		end
	end
	local smith: { [string]: { [number]: boolean } } = {}
	for _, r in Crafting.list do
		for _, m in r.materials do
			smith[m.id] = smith[m.id] or {}
			smith[m.id][r.level] = true
		end
	end
	header({ "region", "kind", "levels", "part", "part value", "alchemy uses", "smith tiers" })
	for _, def in Monsters.list do
		if def.region >= 2 then
			local t = LootTables.byId[def.lootTable]
			local part = "-"
			for _, m in t.materials do
				local d = Items.get(m.id) :: any
				if d.type == "part" or (d.type == "ore" and m.chance ~= 0.04) then
					if not (m.id == "essence_dust") then
						part = m.id
					end
				end
			end
			local u = if part ~= "-" and uses[part] then table.concat(uses[part], ", ") else "-"
			local tiers = {}
			if part ~= "-" and smith[part] then
				for tier in smith[part] do
					table.insert(tiers, tier)
				end
				table.sort(tiers)
			end
			row({ tostring(def.region), def.id, `{def.levels.min}-{def.levels.max}`, part, if part ~= "-" then tostring((Items.get(part) :: any).price) else "-", u, if #tiers > 0 then table.concat(tiers, ",") else "-" })
		end
	end
	print("\n### Alchemy recipes by level and their ingredients\n")
	header({ "recipe", "level", "gold", "ingredients" })
	for _, r in Recipes.list do
		local ing = {}
		for _, i in r.ingredients do
			table.insert(ing, `{i.n} {i.id}`)
		end
		row({ r.id, tostring(r.level), int(r.gold), table.concat(ing, ", ") })
	end
	print("\n### Ores and herbs by region (LootTables region materials) and where ore is sold\n")
	for id, d in Items.byId do
		local dd = d :: any
		if dd.category == "material" then
			print(`- {id}: type {dd.type}, tier {dd.tier}, value {dd.price}`)
		end
	end
end

-- Rates of better items -------------------------------------------------------------------------------------------
if want("rates") then
	print("\n## Better-item rates by level (Warrior; S32 targets: Unique for the class every 1-2 levels, Heroic every 1-2 h of cave Elites)\n")
	header({ "level", "kills/level", "Uniques for class / level", "Elite s/kill (fight+rest+walk)", "Heroic for class / h (Elites)", "Elite II Legendary for class / kill", "boss personal Legendary / kill" })
	for _, L in LEVELS do
		local l = math.min(L, 99)
		local p = E.pace("Warrior", l)
		local uniques = p.kills * B.itemsPerKill("normal", Rarities.UNIQUE)
		local cad = B.eliteCadence("Warrior", l)
		local heroic = 3600 / cad * B.itemsPerKill("elite", Rarities.HEROIC)
		row({ tostring(l), int(p.kills), f2(uniques), f1(cad), f2(heroic), f2(B.itemsPerKill("elite2", Rarities.LEGENDARY)), "1/3.4 (80% class)" })
	end
end

return nil
