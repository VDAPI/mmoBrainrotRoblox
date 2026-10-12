-- Diagnosis of EXP tempo and gold economy for levels 20-100 (balance review, not part of the game).
-- Runs the game's own modules through tests/Balance.luau and Logic/AreaRates. Extends the S32 model:
--   * kindAt for every region (outdoor kinds of the level's region; S32 only knew the Meadows),
--   * quest EXP / gold spread per region band (S32 only spread the quests below level 20),
--   * pace / potions / economy with an explicit monster kind,
--   * best hunting ground per level (all areas of all maps, kinds averaged, S33 profile applied),
--   * upgrade costs with materials and without protection (Markov chain), sinks of level 100.
-- Usage: lune run tools/diag_economy.luau  -> writes tools/diag_economy_out.md (+ json)

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local AreaProfiles = require("../src/shared/Data/AreaProfiles")
local AreaRates = require("../src/shared/Logic/AreaRates")
local Areas = require("../src/shared/Data/Areas")
local B = require("../tests/Balance")
local Blessings = require("../src/shared/Data/Blessings")
local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local Exp = require("../src/shared/Logic/Exp")
local GuildSkills = require("../src/shared/Data/GuildSkills")
local Items = require("../src/shared/Data/Items")
local ItemValue = require("../src/shared/Logic/ItemValue")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local Quests = require("../src/shared/Data/Quests")
local Rarities = require("../src/shared/Data/Rarities")
local Recipes = require("../src/shared/Data/Recipes")
local Stats = require("../src/shared/Data/Stats")
local Upgrade = require("../src/shared/Logic/Upgrade")

local OUT = "tools/diag_economy_out.md"
local CLASSES = B.CLASSES
local LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
local BANDS = { { 1, 20, "1-20 Meadows" }, { 20, 45, "20-45 Duskwood" }, { 45, 70, "45-70 Ashen" }, { 70, 100, "70-100 Frostpeak" } }
local MAP_OF_REGION = { "meadows", "duskwood", "ashen", "frostpeak" }

local lines: { string } = {}
local json: { [string]: any } = {}
local function out(s: string?)
	table.insert(lines, s or "")
end
local function fmt(v: number, d: number?): string
	if v ~= v then
		return "-"
	end
	if v == math.huge then
		return "inf"
	end
	local dd = d or 0
	if dd == 0 then
		local n = math.floor(v + 0.5)
		local s = tostring(n)
		if math.abs(n) >= 10000 then
			s = string.gsub(string.reverse(string.gsub(string.reverse(tostring(math.abs(n))), "(%d%d%d)", "%1 ")), "^ ", "")
			if n < 0 then
				s = "-" .. s
			end
		end
		return s
	end
	return string.format(`%.{dd}f`, v)
end
local function pct(v: number): string
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end
local function header(cols: { string })
	out("| " .. table.concat(cols, " | ") .. " |")
	local sep = {}
	for i = 1, #cols do
		sep[i] = if i == 1 then "---" else "--:"
	end
	out("| " .. table.concat(sep, " | ") .. " |")
end
local function rowOut(cells: { string })
	out("| " .. table.concat(cells, " | ") .. " |")
end

-- Kinds ---------------------------------------------------------------------------------------------------------

local outdoor: { [string]: boolean } = {}
for _, data in Areas.byMap do
	for _, area in data.areas do
		for _, k in area.kinds do
			outdoor[k] = true
		end
	end
end

local function regionOf(level: number): number
	return if level < 20 then 1 elseif level < 45 then 2 elseif level < 70 then 3 else 4
end

-- The usual kind of a level: S32 Balance.kindAt below 20; above, the outdoor kind of the level's region whose
-- level range holds the level, closest to its middle.
local function kindAt(level: number): string
	if level < 20 then
		return B.kindAt(level)
	end
	local region = regionOf(level)
	local best, bestMid = nil :: string?, math.huge
	for _, def in Monsters.list do
		if def.region == region and outdoor[def.id] and not def.passive then
			if level >= def.levels.min and level <= def.levels.max then
				local mid = math.abs((def.levels.min + def.levels.max) / 2 - level)
				if mid < bestMid then
					best, bestMid = def.id, mid
				end
			end
		end
	end
	assert(best, `no kind at {level}`)
	return best :: string
end

-- Quests -------------------------------------------------------------------------------------------------------

local function bandOf(level: number): (number, number)
	for _, b in BANDS do
		if level >= b[1] and level < b[2] then
			return b[1], b[2]
		end
	end
	return 100, 101
end

-- Main story (+ SIDE_SHARE of side quests) of the band, spread over the band's levels by EXP need.
local bandCache: { [number]: { exp: number, gold: number, need: number } } = {}
local function bandQuests(lo: number, hi: number): { exp: number, gold: number, need: number }
	if bandCache[lo] then
		return bandCache[lo]
	end
	local exp, gold, need = 0, 0, 0
	for _, entry in { { Quests.Main.list, 1 }, { Quests.Side.list, B.SIDE_SHARE } } do
		for _, q in entry[1] :: any do
			if q.level >= lo and q.level < hi then
				exp += (q.reward.exp or 0) * entry[2]
				gold += (q.reward.gold or 0) * entry[2]
			end
		end
	end
	for l = lo, hi - 1 do
		need += Exp.expToNext(l)
	end
	bandCache[lo] = { exp = exp, gold = gold, need = need }
	return bandCache[lo]
end

local function questRewards(level: number): (number, number)
	if level < 20 then
		return B.questRewards(level)
	end
	local lo, hi = bandOf(level)
	if lo >= 100 then
		return 0, 0
	end
	local q = bandQuests(lo, hi)
	local share = Exp.expToNext(level) / q.need
	return q.exp * share, q.gold * share
end

-- Pace (S32 Balance.pace with an explicit kind) --------------------------------------------------------------

local playerCache: { [string]: any } = {}
local function player(classId: string, level: number): any
	local key = `{classId}:{level}`
	if not playerCache[key] then
		playerCache[key] = B.player(classId, level)
	end
	return playerCache[key]
end

local function paceWith(classId: string, level: number, kindId: any, withQuests: boolean?): any
	local def = if type(kindId) == "string" then Monsters.get(kindId) else kindId
	local p = player(classId, level)
	local fight = B.expectedGroup(p, def, level)
	local regen = Stats.Formula.hpRegenPct / 100
	local rest = fight.hpLost / regen
	local perFight = fight.seconds + rest + B.BREAK + B.WALK
	local spk = perFight / fight.members
	local expPerKill = B.killExp(level, def, level)
	local goldPerKill = B.killGold(level, def, level)
	local dropPerKill = B.dropValue(level, "normal", if type(kindId) == "string" then kindId else nil)
	local qExp, qGold = 0, 0
	if withQuests ~= false then
		qExp, qGold = questRewards(level)
	end
	local need = math.max(0, Exp.expToNext(level) - qExp)
	local kills = need / expPerKill
	return {
		kind = if type(kindId) == "string" then kindId else "generic",
		expPerKill = expPerKill,
		goldPerKill = goldPerKill,
		dropPerKill = dropPerKill,
		secondsPerKill = spk,
		kills = kills,
		hours = kills * spk / 3600,
		expPerHour = expPerKill * 3600 / spk,
		goldPerHour = goldPerKill * 3600 / spk,
		dropPerHour = dropPerKill * 3600 / spk,
		questExp = qExp,
		questGold = qGold,
		hpLost = fight.hpLost,
		group4 = fight.bySize[4].hpLost,
		restShare = rest / perFight,
		fightSeconds = fight.seconds,
		members = fight.members,
		p = p,
		fight = fight,
	}
end

local function paceAt(classId: string, level: number): any
	return paceWith(classId, level, kindAt(level))
end

-- Potion gold per kill (Balance.potionGold with an explicit kind).
local function potionGold(classId: string, level: number, kindId: string): number
	local def = Monsters.get(kindId)
	local p = player(classId, level)
	local fight = B.expectedGroup(p, def, level)
	local weights = B.groupWeights()
	local total, gold = 0, 0
	local potions = {}
	for q = 1, 5 do
		local item = Items.get(`potion_hp_{q}`) :: any
		table.insert(potions, { heal = item.use.amount, price = item.buyPrice })
	end
	for n, w in weights do
		local over = math.max(0, fight.bySize[n].hpLost - B.POTION_ABOVE) * p.values.maxHp
		local cost = 0
		if over > 0 then
			local best = math.huge
			for _, potion in potions do
				best = math.min(best, math.ceil(over / potion.heal) * potion.price)
			end
			cost = best
		end
		total += w
		gold += w * cost
	end
	return gold / total / fight.members
end

-- Areas (S33) --------------------------------------------------------------------------------------------------

type AreaRow = { id: string, map: string, lv: { number }, kinds: { string }, profile: string? }
local allAreas: { AreaRow } = {}
for _, mapId in MAP_OF_REGION do
	for _, area in Areas.byMap[mapId].areas do
		table.insert(allAreas, { id = area.id, map = mapId, lv = area.lv, kinds = area.kinds, profile = area.profile })
	end
end

-- An hour in `area` for a player of `level` (kinds averaged with equal weight; each kind's monster level = the
-- player's level clamped to the kind's range inside the area).
local function areaHour(classId: string, level: number, area: AreaRow, dropBonus: number?): any
	local p = player(classId, level)
	local n = 0
	local spk, exp, coin, drop, items, top, hpLost = 0, 0, 0, 0, 0, 0, 0
	for _, id in area.kinds do
		local def = Monsters.get(id) :: any
		local low = math.max(area.lv[1], def.levels.min)
		local high = math.min(area.lv[2], def.levels.max)
		if low > high then
			low, high = area.lv[1], area.lv[2]
		end
		local ml = math.clamp(level, low, high)
		local r = AreaRates.rates(p, def, ml, area.profile, B.SKILL_DPS, dropBonus)
		local k = r.killsPerHour
		n += 1
		spk += r.secondsPerKill
		exp += r.expPerKill
		coin += r.coinGoldPerHour / k
		drop += r.dropGoldPerHour / k
		items += r.itemsPerHour / k
		top += r.topPerHour / k
		hpLost += r.hpLostPerFight
	end
	spk /= n
	local kph = 3600 / spk
	return {
		secondsPerKill = spk,
		expPerHour = exp / n * kph,
		coinPerHour = coin / n * kph,
		dropPerHour = drop / n * kph,
		goldPerHour = (coin + drop) / n * kph,
		itemsPerHour = items / n * kph,
		topPerHour = top / n * kph,
		hpLost = hpLost / n,
	}
end

local function areasAt(level: number): { AreaRow }
	local list = {}
	for _, a in allAreas do
		if level >= a.lv[1] and level <= a.lv[2] then
			table.insert(list, a)
		end
	end
	return list
end

local function bestArea(classId: string, level: number, key: string): (AreaRow?, any)
	local best, bestR, bestV = nil, nil, -1
	for _, a in areasAt(level) do
		local r = areaHour(classId, level, a)
		if r[key] > bestV then
			best, bestR, bestV = a, r, r[key]
		end
	end
	return best, bestR
end

-- Upgrade costs ------------------------------------------------------------------------------------------------

-- Gold-equivalent prices of the materials (buy route): dust from the merchant, shard / crystal by transmutation.
local DUST = 40
local SHARD = 10 * DUST + (Recipes.byId.transmute_shard :: any).gold
local CRYSTAL = 8 * SHARD + (Recipes.byId.transmute_crystal :: any).gold
local CORE = (Items.get("legend_core") :: any).price -- not buyable: its merchant value
local SCROLL = (Recipes.byId.scroll_protection :: any).gold + 2 * SHARD + 2 * (Items.get("herb_moonpetal") :: any).price
local MAT_PRICE = { essence_dust = DUST, essence_shard = SHARD, essence_crystal = CRYSTAL, legend_core = CORE }

local function attemptCost(ilvl: number, n: number, rarity: number): (number, number)
	local item = { uid = "x", id = "sword1h_1", rarity = rarity, ilvl = ilvl, bonuses = {}, up = n - 1, bound = false, n = 1 }
	local cost = Upgrade.cost(item :: any, n)
	local mats = 0
	for _, m in cost.materials do
		mats += (MAT_PRICE[m.id] or 0) * m.n
	end
	return cost.gold, mats
end

-- S32 model: gold / chance per step (protection assumed, its scrolls not counted).
local function upgradeS32(ilvl: number, to: number): number
	return B.upgradeGold(ilvl, to)
end

-- Full expected cost to +`to` (gold + materials at buy-equivalent prices), no protection: a failure drops a level.
local function upgradeNoProt(ilvl: number, to: number, rarity: number?): (number, number)
	local r = rarity or Rarities.COMMON
	local prevT = 0
	local total, goldOnly = 0, 0
	local prevG = 0
	for n = 1, to do
		local g, m = attemptCost(ilvl, n, r)
		local p = Upgrade.chance(n) / 100
		local T = (g + m + (1 - p) * prevT) / p
		local G = (g + (1 - p) * prevG) / p
		total += T
		goldOnly += G
		prevT, prevG = T, G
	end
	return total, goldOnly
end

-- With a protection scroll on every attempt from +4 (a failure keeps the level).
local function upgradeProt(ilvl: number, to: number, rarity: number?): number
	local r = rarity or Rarities.COMMON
	local total = 0
	local prevT = 0
	for n = 1, to do
		local g, m = attemptCost(ilvl, n, r)
		local p = Upgrade.chance(n) / 100
		local T
		if n >= 4 then
			T = (g + m + SCROLL) / p
		else
			T = (g + m + (1 - p) * prevT) / p
		end
		total += T
		prevT = T
	end
	return total
end

-- Report ---------------------------------------------------------------------------------------------------------

out("# diag_economy output (generated)")
out()
out(`Materials at buy-equivalent prices: dust {DUST}, shard {SHARD}, crystal {CRYSTAL}, legend core {CORE} (value), protection scroll {SCROLL}.`)
out()

-- 1. EXP curve -------------------------------------------------------------------------------------------------
out("## 1. EXP curve and the usual kind")
out()
header({ "level", "expToNext", "monsterExp(L)", "kills/level (generic, no quests)", "usual kind", "kindReward", "EXP/kill kind", "quest EXP (spread)", "quest share" })
json.curve = {}
for _, L in LEVELS do
	if L == 100 then
		rowOut({ "100", "-", fmt(Exp.monsterExp(100)), "-", kindAt(100), fmt(B.kindReward(Monsters.get(kindAt(100))), 2), fmt(B.killExp(100, Monsters.get(kindAt(100)), 100)), "-", "-" })
		continue
	end
	local k = kindAt(L)
	local def = Monsters.get(k)
	local qe = questRewards(L)
	rowOut({
		tostring(L),
		fmt(Exp.expToNext(L)),
		fmt(Exp.monsterExp(L)),
		fmt(Exp.expToNext(L) / Exp.monsterExp(L)),
		k,
		fmt(B.kindReward(def), 2),
		fmt(B.killExp(L, def, L)),
		fmt(qe),
		pct(qe / Exp.expToNext(L)),
	})
	json.curve[tostring(L)] = { expToNext = Exp.expToNext(L), monsterExp = Exp.monsterExp(L), kind = k }
end
out()

-- 2. Pace per class (usual kind, no profile) --------------------------------------------------------------------
out("## 2. Pace per class (usual kind of the region, no profile; S32 Balance.pace extended)")
out()
header({ "level · kind", "W s/kill", "W h/lvl", "W rest", "H s/kill", "H h/lvl", "M s/kill", "M h/lvl", "C s/kill", "C h/lvl", "C rest", "W EXP/h", "W group4 HP", "M group4 HP" })
json.pace = {}
for _, L in LEVELS do
	if L == 100 then
		continue
	end
	local cells = {}
	local w = paceAt("Warrior", L)
	table.insert(cells, `{L} {w.kind}`)
	local byClass = {}
	for _, c in CLASSES do
		local pc = paceAt(c, L)
		byClass[c] = pc
	end
	table.insert(cells, fmt(byClass.Warrior.secondsPerKill, 1))
	table.insert(cells, fmt(byClass.Warrior.hours, 2))
	table.insert(cells, pct(byClass.Warrior.restShare))
	table.insert(cells, fmt(byClass.Hunter.secondsPerKill, 1))
	table.insert(cells, fmt(byClass.Hunter.hours, 2))
	table.insert(cells, fmt(byClass.Mage.secondsPerKill, 1))
	table.insert(cells, fmt(byClass.Mage.hours, 2))
	table.insert(cells, fmt(byClass.Cleric.secondsPerKill, 1))
	table.insert(cells, fmt(byClass.Cleric.hours, 2))
	table.insert(cells, pct(byClass.Cleric.restShare))
	table.insert(cells, fmt(byClass.Warrior.expPerHour))
	table.insert(cells, pct(byClass.Warrior.group4))
	table.insert(cells, pct(byClass.Mage.group4))
	rowOut(cells)
	json.pace[tostring(L)] = {
		W = byClass.Warrior.hours,
		H = byClass.Hunter.hours,
		M = byClass.Mage.hours,
		C = byClass.Cleric.hours,
	}
end
out()

-- 2b. Generic kind (multipliers 1) for comparison
out("### 2b. Same with the generic kind (all multipliers 1), Warrior and Hunter")
out()
header({ "level", "W s/kill generic", "W h/lvl generic", "W h/lvl usual kind", "kind / generic", "H h/lvl generic", "W fight s", "W HP lost/fight", "W rest share" })
for _, L in LEVELS do
	if L == 100 then
		continue
	end
	local g = paceWith("Warrior", L, B.GENERIC)
	local k = paceAt("Warrior", L)
	local h = paceWith("Hunter", L, B.GENERIC)
	rowOut({ tostring(L), fmt(g.secondsPerKill, 1), fmt(g.hours, 2), fmt(k.hours, 2), fmt(k.hours / g.hours, 2), fmt(h.hours, 2), fmt(g.fightSeconds, 1), pct(g.hpLost), pct(g.restShare) })
end
out()

-- 3. Best hunting ground per level ----------------------------------------------------------------------------------
out("## 3. Best hunting ground for EXP per level and class (all areas holding the level, S33 profile applied)")
out()
header({ "level", "W area", "W EXP/h", "W h/lvl", "H h/lvl", "M h/lvl", "C h/lvl", "choices (profiles)" })
json.best = {}
for _, L in LEVELS do
	if L == 100 then
		continue
	end
	local cells = { tostring(L) }
	local qe = questRewards(L)
	local need = math.max(0, Exp.expToNext(L) - qe)
	local wa, wr = bestArea("Warrior", L, "expPerHour")
	table.insert(cells, `{(wa :: any).id} {(wa :: any).profile or "-"}`)
	table.insert(cells, fmt(wr.expPerHour))
	table.insert(cells, fmt(need / wr.expPerHour, 2))
	json.best[tostring(L)] = { W = need / wr.expPerHour }
	for _, c in { "Hunter", "Mage", "Cleric" } do
		local _, r = bestArea(c, L, "expPerHour")
		table.insert(cells, fmt(need / r.expPerHour, 2))
		json.best[tostring(L)][c] = need / r.expPerHour
	end
	local kinds = {}
	for _, a in areasAt(L) do
		table.insert(kinds, a.profile or "none")
	end
	table.insert(cells, `{#kinds} ({table.concat(kinds, ",")})`)
	rowOut(cells)
end
out()

-- 4. Totals per band -----------------------------------------------------------------------------------------------
out("## 4. Total hours per band (every level summed)")
out()
local function sumHours(classId: string, lo: number, hi: number, model: string): (number, number)
	local h, kills = 0, 0
	for L = lo, hi - 1 do
		if model == "usual" then
			local pc = paceAt(classId, L)
			h += pc.hours
			kills += pc.kills
		elseif model == "generic" then
			local pc = paceWith(classId, L, B.GENERIC)
			h += pc.hours
			kills += pc.kills
		elseif model == "noquest" then
			local pc = paceWith(classId, L, kindAt(L), false)
			h += pc.hours
			kills += pc.kills
		else
			local qe = questRewards(L)
			local need = math.max(0, Exp.expToNext(L) - qe)
			local _, r = bestArea(classId, L, "expPerHour")
			if r then
				h += need / r.expPerHour
				kills += need / r.expPerHour * 3600 / r.secondsPerKill
			else
				local pc = paceAt(classId, L)
				h += pc.hours
				kills += pc.kills
			end
		end
	end
	return h, kills
end
header({ "band · model", "Warrior h", "Hunter h", "Mage h", "Cleric h", "Warrior kills" })
json.totals = {}
for _, model in { "usual", "best", "generic", "noquest" } do
	for _, b in { { 1, 20 }, { 20, 45 }, { 45, 70 }, { 70, 100 }, { 90, 100 }, { 1, 100 } } do
		local cells = { `{b[1]}->{b[2]} · {model}` }
		local wk = 0
		for _, c in CLASSES do
			local h, k = sumHours(c, b[1], b[2], model)
			table.insert(cells, fmt(h, 1))
			json.totals[`{model}:{b[1]}-{b[2]}:{c}`] = h
			if c == "Warrior" then
				wk = k
			end
		end
		table.insert(cells, fmt(wk))
		rowOut(cells)
	end
end
out()

-- 4b. Region borders: every level around 20, 45, 70 and 90-99
out("### 4b. Every level around the region borders and 88-99 (Warrior, usual kind / best area)")
out()
header({ "level · kind", "EXP/kill", "s/kill", "kills", "h/lvl usual", "h/lvl best", "best area", "gold/kill", "gold/h (coins)", "rest" })
for _, range in { { 17, 23 }, { 42, 48 }, { 67, 73 }, { 88, 99 } } do
	for L = range[1], range[2] do
		local pc = paceAt("Warrior", L)
		local qe = questRewards(L)
		local need = math.max(0, Exp.expToNext(L) - qe)
		local a, r = bestArea("Warrior", L, "expPerHour")
		rowOut({
			`{L} {pc.kind}`,
			fmt(pc.expPerKill),
			fmt(pc.secondsPerKill, 1),
			fmt(pc.kills),
			fmt(pc.hours, 2),
			if r then fmt(need / r.expPerHour, 2) else "-",
			if a then `{a.id} {a.profile or "-"}` else "-",
			fmt(pc.goldPerKill, 1),
			fmt(pc.goldPerHour),
			pct(pc.restShare),
		})
	end
end
out()

-- 5. Area profiles of regions 2-4 -------------------------------------------------------------------------------------
out("## 5. Hunting grounds of regions 2-4 (Warrior at the area's middle level, kinds averaged)")
out()
header({ "area · profile", "lv", "mid", "s/kill", "EXP/h", "gold/h (with drop)", "coins/h", "drop/h", "items/h", "Unique/h", "HP lost/fight" })
json.areas = {}
for _, a in allAreas do
	if a.map == "meadows" then
		continue
	end
	local mid = math.floor((a.lv[1] + a.lv[2]) / 2)
	local r = areaHour("Warrior", mid, a)
	rowOut({
		`{a.id} {a.profile or "-"}`,
		`{a.lv[1]}-{a.lv[2]}`,
		tostring(mid),
		fmt(r.secondsPerKill, 1),
		fmt(r.expPerHour),
		fmt(r.goldPerHour),
		fmt(r.coinPerHour),
		fmt(r.dropPerHour),
		fmt(r.itemsPerHour, 1),
		fmt(r.topPerHour, 2),
		pct(r.hpLost),
	})
	json.areas[a.id] = r
end
out()

-- 5b. S33 targets with the real kinds: at every level from 20 to 100, compare the best area of each profile.
out("### 5b. S33 targets with the real kinds, every level 20-100 (Warrior; best area of each profile at that level)")
out()
out("exp/loot = best ⚡ EXP/h ÷ best ✦ EXP/h (target ≥ 1.25); loot top = best ✦ Unique/h ÷ best other Unique/h (≥ 1.6); gold = best ⛁ gold/h ÷ best other gold/h (≥ 1.5).")
out()
header({ "level", "profiles present", "exp/loot EXP", "loot top ratio", "gold ratio", "exp area vs best other EXP/h" })
local fails = { exp = 0, loot = 0, gold = 0, levels = 0 }
for L = 20, 100 do
	local best: { [string]: any } = {}
	for _, a in areasAt(L) do
		local key = a.profile or "none"
		local r = areaHour("Warrior", L, a)
		best[key] = best[key] or { expPerHour = 0, topPerHour = 0, goldPerHour = 0 }
		for _, f in { "expPerHour", "topPerHour", "goldPerHour" } do
			best[key][f] = math.max(best[key][f], r[f])
		end
	end
	local function otherMax(skip: string, f: string): number
		local m = 0
		for k, v in best do
			if k ~= skip then
				m = math.max(m, v[f])
			end
		end
		return m
	end
	local present = {}
	for k in best do
		table.insert(present, k)
	end
	table.sort(present)
	local e = if best.exp and best.loot then best.exp.expPerHour / best.loot.expPerHour else 0 / 0
	local l = if best.loot and #present > 1 then best.loot.topPerHour / otherMax("loot", "topPerHour") else 0 / 0
	local g = if best.gold and #present > 1 then best.gold.goldPerHour / otherMax("gold", "goldPerHour") else 0 / 0
	local ev = if best.exp and #present > 1 then best.exp.expPerHour / otherMax("exp", "expPerHour") else 0 / 0
	fails.levels += 1
	if e == e and e < 1.25 then
		fails.exp += 1
	end
	if l == l and l < 1.6 then
		fails.loot += 1
	end
	if g == g and g < 1.5 then
		fails.gold += 1
	end
	if L % 5 == 0 or (e == e and e < 1.25) or (l == l and l < 1.6) or (g == g and g < 1.5) or (ev == ev and ev < 1) then
		rowOut({ tostring(L), table.concat(present, ","), fmt(e, 2), fmt(l, 2), fmt(g, 2), fmt(ev, 2) })
	end
end
out()
out(`Levels 20-100 below target: exp/loot {fails.exp}, loot top {fails.loot}, gold {fails.gold} (of {fails.levels}).`)
out()

-- 6. Quests of regions 2-4 -------------------------------------------------------------------------------------------
out("## 6. Main quests 20-100: EXP and gold")
out()
header({ "quest", "level", "EXP", "EXP / expToNext(level)", "gold", "gold / W coin gold per hour at level", "items" })
for _, q in Quests.Main.list do
	if q.level >= 18 then
		local L = math.min(99, q.level)
		local w = paceAt("Warrior", L)
		local items = {}
		for _, it in q.reward.items or {} do
			table.insert(items, `{it.id}×{it.n}`)
		end
		rowOut({
			q.id,
			tostring(q.level),
			fmt(q.reward.exp),
			fmt(q.reward.exp / Exp.expToNext(L), 2),
			fmt(q.reward.gold),
			fmt(q.reward.gold / (w.goldPerHour + w.dropPerHour), 2) .. " h",
			table.concat(items, ", "),
		})
	end
end
out()
header({ "band", "quest EXP", "band EXP need", "share", "quest gold", "quest count" })
for _, b in BANDS do
	local q = bandQuests(b[1], b[2])
	local count = 0
	for _, quest in Quests.Main.list do
		if quest.level >= b[1] and quest.level < b[2] then
			count += 1
		end
	end
	rowOut({ b[3], fmt(q.exp), fmt(q.need), pct(q.exp / q.need), fmt(q.gold), tostring(count) })
end
out()

-- 6b. Daily contracts
out("### 6b. Daily contracts (3 per day) and bosses (3 kills per day) as a share of the level")
out()
header({ "level", "3 dailies EXP / level", "3 dailies gold", "dailies gold / W gold per hour", "W grind h per level (best)", "boss", "boss EXP / level (party 5)", "boss EXP / level (solo)", "boss gold (party 5 each)" })
for _, L in LEVELS do
	local Lx = math.min(L, 99)
	local d = Quests.Daily.reward(Lx)
	local w = paceAt("Warrior", Lx)
	local qe = questRewards(Lx)
	local need = math.max(0, Exp.expToNext(Lx) - qe)
	local _, r = bestArea("Warrior", Lx, "expPerHour")
	local boss = nil
	for _, b in { "grimrok", "morvane", "azgor", "vaelgrath" } do
		local def = Bosses.byId[b] :: any
		if def.level >= Lx and (boss == nil or def.level < (Bosses.byId[boss] :: any).level) then
			boss = b
		end
	end
	local bdef = Bosses.byId[boss :: string] :: any
	local bossLevel = bdef.level
	local bexp = Exp.monsterExp(bossLevel, "boss") * Exp.levelDiffMultiplier(Lx, bossLevel)
	local bgold = MonsterStats.gold(bossLevel, "boss", 0.5)
	rowOut({
		tostring(L),
		pct(3 * d.exp / Exp.expToNext(Lx)),
		fmt(3 * d.gold),
		fmt(3 * d.gold / (w.goldPerHour + w.dropPerHour), 2) .. " h",
		fmt(need / r.expPerHour, 2),
		`{boss} {bossLevel}`,
		pct(bexp / 5 / Exp.expToNext(Lx)),
		pct(bexp / Exp.expToNext(Lx)),
		fmt(bgold / 5),
	})
end
out()

-- 7. Gold per level and budget -----------------------------------------------------------------------------------------
out("## 7. Gold per level (Warrior, usual kind, no profile) and what a level costs")
out()
out("Upgrades: S32 model = gold / chance per step on the weapon of ilvl L-2 (protection assumed free). 'full' = gold + materials at buy-equivalent prices, no protection (failure drops a level).")
out()
header({ "level", "coins/h", "drop sales/h", "drop / coins", "income of the level", "of it quests", "potions", "weapon +1..+3 (S32)", "+3 / income", "weapon +1..+5 (S32)", "set of 10 +3 (full)", "set +3 / income", "weapon +9 (full, no prot.)" })
json.gold = {}
for _, L in LEVELS do
	local Lx = math.min(L, 99)
	local w = paceAt("Warrior", Lx)
	local income = w.kills * (w.goldPerKill + w.dropPerKill) + w.questGold
	local potions = w.kills * potionGold("Warrior", Lx, w.kind)
	local ilvl = math.max(1, Lx - B.GEAR_GAP)
	local up3 = upgradeS32(ilvl, 3)
	local up5 = upgradeS32(ilvl, 5)
	local set3 = upgradeNoProt(ilvl, 3) * 10
	local w9 = upgradeNoProt(ilvl, 9)
	rowOut({
		tostring(L),
		fmt(w.goldPerHour),
		fmt(w.dropPerHour),
		pct(w.dropPerKill / w.goldPerKill),
		fmt(income),
		pct(w.questGold / income),
		fmt(potions),
		fmt(up3),
		pct(up3 / income),
		fmt(up5),
		fmt(set3),
		pct(set3 / income),
		fmt(w9),
	})
	json.gold[tostring(L)] = { income = income, up3 = up3, potions = potions, goldPerHour = w.goldPerHour, dropPerHour = w.dropPerHour }
end
out()

-- 7b. Gold budget per region (S32 "Złoto 1→20" for every band), every class
out("### 7b. Gold budget per region (every level summed; S32 conventions: weapon +1..+3 every level, potions above 60% HP)")
out()
header({ "band · class", "kill coins", "drop sales", "quests", "income", "potions", "pot / income", "weapon +3 every level", "up / income", "drop / coins", "hours (usual)", "gold/h overall" })
json.budget = {}
for _, b in BANDS do
	for _, c in CLASSES do
		local coins, drops, quests, potions, ups, hours = 0, 0, 0, 0, 0, 0
		for L = b[1], b[2] - 1 do
			local pc = paceAt(c, L)
			coins += pc.kills * pc.goldPerKill
			drops += pc.kills * pc.dropPerKill
			quests += pc.questGold
			potions += pc.kills * potionGold(c, L, pc.kind)
			ups += upgradeS32(math.max(1, L - B.GEAR_GAP), 3)
			hours += pc.hours
		end
		local income = coins + drops + quests
		rowOut({
			`{b[3]} · {c}`,
			fmt(coins),
			fmt(drops),
			fmt(quests),
			fmt(income),
			fmt(potions),
			pct(potions / income),
			fmt(ups),
			pct(ups / income),
			pct(drops / coins),
			fmt(hours, 1),
			fmt(income / hours),
		})
		json.budget[`{b[3]}:{c}`] = { coins = coins, drops = drops, quests = quests, income = income, potions = potions, ups = ups, hours = hours }
	end
end
out()

-- 7c. Cumulative gold and the big purchases
out("### 7c. Cumulative income (Warrior, usual kind, no spending) vs the big purchases")
out()
local cum = 0
local cumAt: { [number]: number } = {}
for L = 1, 99 do
	local pc = paceAt("Warrior", L)
	cum += pc.kills * (pc.goldPerKill + pc.dropPerKill) + pc.questGold
	cumAt[L + 1] = cum
end
header({ "purchase", "level", "price", "cumulative income at that level", "price / income of that level", "hours of grinding (coins+drop) at that level" })
local function levelIncome(L: number): number
	local pc = paceAt("Warrior", L)
	return pc.kills * (pc.goldPerKill + pc.dropPerKill) + pc.questGold, pc.goldPerHour + pc.dropPerHour
end
for _, cap in { 30, 45, 60, 80, 100, 130, 160, 200 } do
	local def = Items.get(`backpack_{cap}`) :: any
	local L = math.max(def.level, 1)
	local inc, perH = levelIncome(math.min(99, L))
	rowOut({ `backpack_{cap}`, tostring(def.level), fmt(def.buyPrice), fmt(cumAt[L] or 0), fmt(def.buyPrice / inc, 2), fmt(def.buyPrice / perH, 1) })
end
for _, tier in { 25, 35, 45, 55, 65, 75, 85, 95 } do
	local weapon = Items.get(`sword1h_{tier}`) :: any
	local shield = Items.get(`shield_{tier}`) :: any
	local price = ItemValue.equipment(weapon, tier, 1, 0) * 4 + ItemValue.equipment(shield, tier, 1, 0) * 4
	local inc, perH = levelIncome(tier)
	rowOut({ `weaponsmith sword+shield {tier}`, tostring(tier), fmt(price), fmt(cumAt[tier] or 0), fmt(price / inc, 2), fmt(price / perH, 1) })
end
do
	local inc, perH = levelIncome(20)
	rowOut({ "guild founding", "20", fmt(GuildSkills.Rules.createCost), fmt(cumAt[20]), fmt(GuildSkills.Rules.createCost / inc, 2), fmt(GuildSkills.Rules.createCost / perH, 1) })
	local all = 0
	for _, s in GuildSkills.list do
		for _, cost in s.costs do
			all += cost
		end
	end
	local inc99, perH99 = levelIncome(99)
	rowOut({ "all guild skills to 5", "-", fmt(all), "-", fmt(all / inc99, 2) .. " (L99)", fmt(all / perH99, 1) .. " (L99)" })
	for _, L in { 50, 100 } do
		local Lx = math.min(L, 99)
		local incL, perHL = levelIncome(Lx)
		rowOut({ `scroll_oblivion at {L}`, tostring(L), fmt(500 * L), fmt(cumAt[Lx] or 0), fmt(500 * L / incL, 2), fmt(500 * L / perHL, 1) })
	end
end
out()
out(`Cumulative income 1->100 (Warrior, no spending): {fmt(cumAt[100])}; at 20: {fmt(cumAt[20])}, 45: {fmt(cumAt[45])}, 70: {fmt(cumAt[70])}.`)
out()

-- 7d. Blessings per hour vs gold per hour
out("### 7d. Blessings (30 min) kept up while grinding: gold per hour vs income per hour (Warrior, usual kind, coins + drop)")
out()
header({ "level", "income/h", "Common ×2/h", "Unique ×2/h", "Heroic ×2/h", "Legendary ×2/h", "Legendary / income", "fortune EXP bonus of the best brew" })
local bgold = {}
for r = 1, 4 do
	bgold[r] = (Recipes.byId[`blessing_fortune_{r}`] :: any).gold
end
for _, L in LEVELS do
	local Lx = math.min(L, 99)
	local pc = paceAt("Warrior", Lx)
	local inc = pc.goldPerHour + pc.dropPerHour
	local avail = 1
	for r = 1, 4 do
		if (Recipes.byId[`blessing_fortune_{r}`] :: any).level <= L then
			avail = r
		end
	end
	rowOut({
		tostring(L),
		fmt(inc),
		fmt(2 * bgold[1]),
		fmt(2 * bgold[2]),
		fmt(2 * bgold[3]),
		fmt(2 * bgold[4]),
		pct(2 * bgold[4] / inc),
		`+{(Blessings.of("fortune", avail) :: any).stats.expBonus}% (tier {avail})`,
	})
end
out()

-- 8. Gold penalty for lower monsters
out("## 8. Gold and EXP for monsters below the player (generic kind)")
out()
header({ "player", "monster", "d", "gold", "gold share", "EXP", "EXP share" })
for _, P in { 45, 70, 100 } do
	for _, d in { 0, 5, 7, 10, 15, 25 } do
		local M = P - d
		local g = B.killGold(P, B.GENERIC, M)
		local e = B.killExp(P, B.GENERIC, M)
		rowOut({ tostring(P), tostring(M), tostring(d), fmt(g, 1), pct(g / B.killGold(M, B.GENERIC, M)), fmt(e, 1), pct(e / B.killExp(M, B.GENERIC, M)) })
	end
end
out()

-- 9. Upgrade cost ladder
out("## 9. Upgrade cost of one item (+0 -> +N)")
out()
header({ "ilvl", "+1 gold", "+3 S32", "+3 full", "+5 full", "+7 full", "+9 full no prot.", "+9 with prot. from +4", "+9 Legendary (core) with prot.", "gold/h W at that level" })
for _, il in { 18, 43, 68, 98, 100 } do
	local g1 = attemptCost(il, 1, 1)
	local pcL = paceAt("Warrior", math.min(99, il + 2))
	rowOut({
		tostring(il),
		fmt(g1),
		fmt(upgradeS32(il, 3)),
		fmt((upgradeNoProt(il, 3))),
		fmt((upgradeNoProt(il, 5))),
		fmt((upgradeNoProt(il, 7))),
		fmt((upgradeNoProt(il, 9))),
		fmt(upgradeProt(il, 9)),
		fmt(upgradeProt(il, 9, Rarities.LEGENDARY)),
		fmt(pcL.goldPerHour + pcL.dropPerHour),
	})
end
out()

-- 10. Level 100: income and sinks
out("## 10. Level 100: income per hour and the sinks")
out()
header({ "class", "best gold area at 100", "gold/h (coins+drop)", "coins/h", "best EXP area at 99 h/lvl", "frostWyrm 100 coins/h (usual)", "drop/h" })
for _, c in CLASSES do
	local a, r = bestArea(c, 100, "goldPerHour")
	local pc = paceWith(c, 100, "frostWyrm", false)
	local _, e = bestArea(c, 99, "expPerHour")
	rowOut({ c, `{(a :: any).id} {(a :: any).profile or "-"}`, fmt(r.goldPerHour), fmt(r.coinPerHour), fmt((Exp.expToNext(99) - questRewards(99)) / e.expPerHour, 2), fmt(pc.goldPerHour), fmt(pc.dropPerHour) })
end
out()
do
	local _, r = bestArea("Warrior", 100, "goldPerHour")
	local perH = r.goldPerHour
	local all = 0
	for _, s in GuildSkills.list do
		for _, cost in s.costs do
			all += cost
		end
	end
	local set9 = 0
	for _ = 1, 10 do
		set9 += upgradeProt(100, 9, Rarities.LEGENDARY)
	end
	local set9np = 0
	for _ = 1, 10 do
		set9np += (upgradeNoProt(100, 9, Rarities.LEGENDARY))
	end
	header({ "sink at level 100", "gold", "hours at best gold area (W)" })
	rowOut({ "set of 10 Legendary +0->+9 with protection from +4 (gold+mats+scrolls)", fmt(set9), fmt(set9 / perH, 1) })
	rowOut({ "set of 10 Legendary +0->+9 no protection", fmt(set9np), fmt(set9np / perH, 1) })
	rowOut({ "all guild skills to 5 (shared by a guild)", fmt(all), fmt(all / perH, 1) })
	rowOut({ "backpack_200", fmt((Items.get("backpack_200") :: any).buyPrice), fmt((Items.get("backpack_200") :: any).buyPrice / perH, 1) })
	rowOut({ "Legendary blessing kept up (per hour)", fmt(2 * bgold[4]), fmt(2 * bgold[4] / perH, 2) })
	rowOut({ "scroll_oblivion + scroll_skillreset at 100", fmt(900 * 100), fmt(900 * 100 / perH, 2) })
	rowOut({ "potion_hp_5 ×100", fmt(300000), fmt(300000 / perH, 1) })
	out()
	local p100 = player("Warrior", 100)
	out(`Warrior L100 max HP {fmt(p100.values.maxHp)}; potion_hp_5 heals 10000 for 3000.`)
	out()
end

-- 11. Elites in caves vs grinding
out("## 11. Cave Elites solo vs normal grind (Warrior; generic kind; fight + rest + walk)")
out()
header({ "level", "elite s", "elite HP", "cadence s", "EXP/h elites", "EXP/h grind (usual)", "ratio", "coins/h elites", "drop/h elites", "Heroic/h" })
for _, L in LEVELS do
	local Lx = math.min(L, 99)
	local p = player("Warrior", Lx)
	local f = B.elite(p, B.GENERIC, Lx)
	local cad = B.eliteCadence("Warrior", Lx)
	local exp = B.killExp(Lx, B.GENERIC, Lx + 2, "elite")
	local coins = B.killGold(Lx, B.GENERIC, Lx + 2, "elite")
	local drop = B.dropValue(Lx, "elite")
	local pc = paceAt("Warrior", Lx)
	rowOut({
		tostring(L),
		fmt(f.seconds, 1),
		pct(f.hpLost),
		fmt(cad, 1),
		fmt(exp * 3600 / cad),
		fmt(pc.expPerHour),
		fmt(exp * 3600 / cad / pc.expPerHour, 2),
		fmt(coins * 3600 / cad),
		fmt(drop * 3600 / cad),
		fmt(3600 / cad * B.itemsPerKill("elite", Rarities.HEROIC), 2),
	})
end
out()


-- 12. Potions instead of resting
out("## 12. Potions instead of resting (heal the fight's loss with HP potions while walking; 1.5 s cooldown)")
out()
out("Per fight: HP lost (expected group) minus the regen of the 7 s break+walk; cheapest potion quality whose drinks fit in the 7 s, else the fastest one (extra wait). EXP/h and gold/h vs the S32 rest model.")
out()
local POTS = {}
for q = 1, 5 do
	local item = Items.get(`potion_hp_{q}`) :: any
	table.insert(POTS, { q = q, heal = item.use.amount, price = item.buyPrice })
end
local function potionFight(classId: string, level: number, kindId: string): any
	local def = Monsters.get(kindId)
	local p = player(classId, level)
	local fight = B.expectedGroup(p, def, level)
	local free = B.BREAK + B.WALK
	local regen = Stats.Formula.hpRegenPct / 100
	local weights = B.groupWeights()
	local total, gold, extra, secs, members = 0, 0, 0, 0, 0
	for n, w in weights do
		local f = fight.bySize[n]
		local lostHp = math.max(0, f.hpLost - regen * free) * p.values.maxHp
		local best, bestCost, bestTime = nil, math.huge, math.huge
		for _, pot in POTS do
			local count = math.ceil(lostHp / pot.heal)
			local t = count * Config.PotionCooldown
			local cost = count * pot.price
			local wait = math.max(0, t - free)
			-- value the extra wait at nothing; prefer no wait, then cost
			local key = cost + wait * 1e6
			if key < bestCost then
				best, bestCost, bestTime = pot, key, wait
			end
		end
		local cost = math.ceil(lostHp / (best :: any).heal) * (best :: any).price
		total += w
		gold += w * cost
		extra += w * bestTime
		secs += w * f.seconds
		members += w * n
	end
	gold /= total
	extra /= total
	secs /= total
	members /= total
	local perFight = secs + free + extra
	local spk = perFight / members
	local expPerKill = B.killExp(level, def, level)
	local goldPerKill = B.killGold(level, def, level)
	local dropPerKill = B.dropValue(level, "normal", kindId)
	return {
		spk = spk,
		expPerHour = expPerKill * 3600 / spk,
		potionPerHour = gold / members * 3600 / spk,
		incomePerHour = (goldPerKill + dropPerKill) * 3600 / spk,
		maxHp = p.values.maxHp,
	}
end
header({ "level · class", "max HP", "rest model s/kill", "potion s/kill", "EXP/h ×", "income/h (potions)", "potions/h", "potions / income", "net gold/h potions", "net gold/h rest model", "h/lvl potions" })
local potionTotals: { [string]: number } = {}
for _, L in LEVELS do
	local Lx = math.min(L, 99)
	for _, c in { "Warrior", "Mage", "Cleric", "Hunter" } do
		local pc = paceAt(c, Lx)
		local pf = potionFight(c, Lx, pc.kind)
		local need = math.max(0, Exp.expToNext(Lx) - pc.questExp)
		if c == "Warrior" or c == "Mage" or L % 20 == 0 then
			rowOut({
				`{L} {c}`,
				fmt(pf.maxHp),
				fmt(pc.secondsPerKill, 1),
				fmt(pf.spk, 1),
				fmt(pf.expPerHour / pc.expPerHour, 2),
				fmt(pf.incomePerHour),
				fmt(pf.potionPerHour),
				pct(pf.potionPerHour / pf.incomePerHour),
				fmt(pf.incomePerHour - pf.potionPerHour),
				fmt(pc.goldPerHour + pc.dropPerHour),
				fmt(need / pf.expPerHour, 2),
			})
		end
	end
end
out()
header({ "band", "Warrior h (rest)", "Warrior h (potions)", "Mage h (potions)", "Cleric h (potions)", "Hunter h (potions)", "Warrior potion gold", "Warrior income in the band", "share" })
for _, b in { { 1, 20 }, { 20, 45 }, { 45, 70 }, { 70, 100 }, { 1, 100 } } do
	local cells = { `{b[1]}->{b[2]}` }
	local restH = 0
	for L = b[1], b[2] - 1 do
		restH += paceAt("Warrior", L).hours
	end
	table.insert(cells, fmt(restH, 1))
	local wGold, wIncome = 0, 0
	for _, c in { "Warrior", "Mage", "Cleric", "Hunter" } do
		local h = 0
		for L = b[1], b[2] - 1 do
			local pc = paceAt(c, L)
			local pf = potionFight(c, L, pc.kind)
			local need = math.max(0, Exp.expToNext(L) - pc.questExp)
			local hh = need / pf.expPerHour
			h += hh
			if c == "Warrior" then
				wGold += pf.potionPerHour * hh
				wIncome += pf.incomePerHour * hh + pc.questGold
			end
		end
		table.insert(cells, fmt(h, 1))
	end
	table.insert(cells, fmt(wGold))
	table.insert(cells, fmt(wIncome))
	table.insert(cells, pct(wGold / wIncome))
	rowOut(cells)
end
out()

-- 13. Number of hunting grounds per level
out("## 13. Hunting grounds per level (outdoor areas holding the level)")
out()
local runs = {}
for L = 20, 100 do
	local list = areasAt(L)
	local ids = {}
	for _, a in list do
		table.insert(ids, `{string.gsub(a.id, "^%a+_", "")}{if a.profile then ":" .. a.profile else ""}`)
	end
	table.insert(runs, `{L}: {#list} ({table.concat(ids, ", ")})`)
end
out(table.concat(runs, "  \n"))
out()


-- 12b. Break-even potion price: gold per HP that makes chain-potions earn the same net gold/h as resting.
out("### 12b. Potion price that would make chain-potions gold-neutral (net gold/h = resting), per class")
out()
out("Current cheapest gold per HP: hp_1 0.067, hp_2 0.12, hp_3 0.167, hp_4 0.225, hp_5 0.30 (price / heal).")
out()
header({ "level", "W HP healed/h", "W current gold/HP paid", "W break-even gold/HP", "W price ×", "M price ×", "C price ×", "H price ×" })
for _, L in LEVELS do
	local Lx = math.min(L, 99)
	local cells = { tostring(L) }
	local first = true
	for _, c in { "Warrior", "Mage", "Cleric", "Hunter" } do
		local pc = paceAt(c, Lx)
		local pf = potionFight(c, Lx, pc.kind)
		local need = pf.incomePerHour - (pc.goldPerHour + pc.dropPerHour)
		local mult = need / math.max(1, pf.potionPerHour)
		if first then
			-- HP healed per hour = lost HP net of the walk regen, per fight x fights per hour
			local p = player(c, Lx)
			local fight = B.expectedGroup(p, Monsters.get(pc.kind), Lx)
			local healed = 0
			local total = 0
			for n, w in B.groupWeights() do
				healed += w * math.max(0, fight.bySize[n].hpLost - Stats.Formula.hpRegenPct / 100 * (B.BREAK + B.WALK)) * p.values.maxHp
				total += w
			end
			healed /= total
			local fightsPerHour = 3600 / (pf.spk * fight.members)
			local hph = healed * fightsPerHour
			table.insert(cells, fmt(hph))
			table.insert(cells, fmt(pf.potionPerHour / hph, 3))
			table.insert(cells, fmt(need / hph, 3))
			first = false
		end
		table.insert(cells, fmt(mult, 1))
	end
	rowOut(cells)
end
out()

-- 9b. What +7..+9 costs in gold vs materials, and legend cores.
out("### 9b. +0 -> +9 with protection from +4 at ilvl 100: gold, materials, scrolls, cores")
out()
do
	local gold, mats, scrolls, crystals, cores, dust, shards = 0, 0, 0, 0, 0, 0, 0
	for n = 1, 9 do
		local item = { uid = "x", id = "sword1h_1", rarity = Rarities.LEGENDARY, ilvl = 100, bonuses = {}, up = n - 1, bound = false, n = 1 }
		local cost = Upgrade.cost(item :: any, n)
		local p = Upgrade.chance(n) / 100
		local attempts = 1 / p -- with protection (n >= 4) or retry from n-1 after a fall (approx. for n <= 3)
		gold += cost.gold * attempts
		for _, m in cost.materials do
			mats += (MAT_PRICE[m.id] or 0) * m.n * attempts
			if m.id == "essence_crystal" then
				crystals += m.n * attempts
			elseif m.id == "legend_core" then
				cores += m.n * attempts
			elseif m.id == "essence_dust" then
				dust += m.n * attempts
			elseif m.id == "essence_shard" then
				shards += m.n * attempts
			end
		end
		if n >= 4 then
			scrolls += attempts
		end
	end
	header({ "part", "amount", "gold equivalent" })
	rowOut({ "upgrade gold", "-", fmt(gold) })
	rowOut({ "essence dust", fmt(dust, 1), fmt(dust * DUST) })
	rowOut({ "essence shards", fmt(shards, 1), fmt(shards * SHARD) })
	rowOut({ "essence crystals", fmt(crystals, 1), fmt(crystals * CRYSTAL) })
	rowOut({ "legend cores (Legendary/Mythic only; 1 per dismantled Legendary)", fmt(cores, 1), fmt(cores * CORE) .. " (value)" })
	rowOut({ "protection scrolls", fmt(scrolls, 1), fmt(scrolls * SCROLL) })
	out()
	-- Dust supply from kills at 100
	local pc = paceWith("Warrior", 100, "frostWyrm", false)
	local killsPerHour = 3600 / pc.secondsPerKill
	out(`Dust from kills at 100 (region 4: 18% × 2-4): {fmt(killsPerHour * 0.18 * 3, 1)} dust/h (rest model, {fmt(killsPerHour)} kills/h) = {fmt(killsPerHour * 0.18 * 3 / 80, 2)} crystals/h.`)
	out()
end

-- 11b. Elite ratio in the Meadows for context
out("### 11b. Elites vs grind in 1-20 for context (Warrior)")
out()
header({ "level", "EXP/h elites", "EXP/h grind", "ratio" })
for _, L in { 10, 15, 19 } do
	local cad = B.eliteCadence("Warrior", L)
	local exp = B.killExp(L, B.GENERIC, L + 2, "elite")
	local pc = paceAt("Warrior", L)
	rowOut({ tostring(L), fmt(exp * 3600 / cad), fmt(pc.expPerHour), fmt(exp * 3600 / cad / pc.expPerHour, 2) })
end
out()

fs.writeFile(OUT, table.concat(lines, "\n"))
fs.writeFile("tools/diag_economy_out.json", serde.encode("json", json, true))
print(`wrote {OUT}`)
