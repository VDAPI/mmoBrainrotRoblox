-- Rough check for the Warrior paths design (rozwoj/wojownik.md). Not game code.
-- Base 8 with the new unlock ladder, automatic ranks (global A5: step 4, cap 95), path nodes approximated as
-- fake passives / cloned skill defs. Furia = average stacks as an attack-speed bonus.
local E = require("./SkillEngine")
local process = require("@lune/process")
local B = require("../tests/Balance")
local SkillData = require("../src/shared/Data/Skills")
local Damage = require("../src/shared/Logic/Damage")
local fmt = string.format

local byId = SkillData.byId

-- New unlocks (base ladder 1,3,6,10,14,18,30,45; path skills: row level)
local UNLOCK = {
	mightyStrike = 1, charge = 3, bladeWhirl = 6, taunt = 10, steelSkin = 14, bloodlust = 18, earthquake = 30, riposte = 45,
	fortitude = 10, cleave = 10, battleCry = 10, -- row 1 (moved A)
	lastBastion = 48, titansWrath = 48, crushingBlow = 48, -- row 7 (moved B)
	rend = 26, carnage = 60, warBanner = 26, advanceOrder = 60, intercept = 26, shieldWall = 60,
}

local function rankAt(id, L)
	local s = byId[id]
	local u = UNLOCK[id]
	if not s or not u or L < u then
		return 0
	end
	local span = math.min(36, 95 - u)
	local r = 0
	for n = 1, s.maxLevel do
		if u + math.floor((n - 1) * span / (s.maxLevel - 1) + 0.5) <= L then
			r = n
		end
	end
	return r
end

local function clone(id, newId, patch)
	local d = table.clone(byId[id])
	d.id = newId
	d.values = table.clone(d.values)
	for k, v in patch or {} do
		if k == "values" then
			for f, x in v do
				d.values[f] = x
			end
		else
			d[k] = v
		end
	end
	byId[newId] = d
	return d
end

local function passive(id, flat, pct)
	local values, f, p = {}, {}, {}
	for stat, v in flat or {} do
		values["f_" .. stat] = v
		f[stat] = "f_" .. stat
	end
	for stat, v in pct or {} do
		values["p_" .. stat] = v
		p[stat] = "p_" .. stat
	end
	byId[id] = { id = id, class = "Warrior", maxLevel = 1, type = "passive", values = values, passive = { flat = f, pct = p }, cost = 0, cooldown = 0 }
end

-- New skills (approximations)
-- Rend: 140 -> 250 %, bleed 40 % / 6 s; consumes Furia (about 10 stacks x 8 % = +80 %) every 10 s
byId.rend = { id = "rend", class = "Warrior", maxLevel = 10, type = "target", target = "enemy", resource = "energy",
	cost = 25, cooldown = 10, range = 8, damageKind = "phys", values = { dmg = { 140 * 1.8, 250 * 1.8 }, bleed = 40 },
	effects = { { kind = "bleed", duration = 6, value = "bleed" } } }
-- Carnage: +1.5 -> 2.5 % physAtk per stack consumed (10), 8 s, cd 45
byId.carnage = { id = "carnage", class = "Warrior", maxLevel = 10, type = "buff", target = "self", resource = "energy",
	cost = 30, cooldown = 45, duration = 8, damageKind = "phys", values = { atk = { 15, 25 } },
	effects = { { kind = "statBuff", duration = 8, stats = { physAtk = "atk" }, pct = true, target = "self" } } }
-- War Banner (self part): +6 -> 12 % attack speed, 15 s (+6 s node), cd 30
byId.warBanner = { id = "warBanner", class = "Warrior", maxLevel = 10, type = "buff", target = "self", resource = "energy",
	cost = 30, cooldown = 30, duration = 21, damageKind = "phys", values = { haste = { 6, 12 } },
	effects = { { kind = "statBuff", duration = 21, stats = { atkSpeed = "haste" }, pct = true, target = "self" } } }
-- Order (self part): +15 -> 25 pp crit 8 s, cd 60 (hit part as a separate circle)
byId.advanceOrder = { id = "advanceOrder", class = "Warrior", maxLevel = 10, type = "buff", target = "self", resource = "energy",
	cost = 35, cooldown = 60, duration = 8, damageKind = "phys", values = { crit = { 15, 25 } },
	effects = { { kind = "statBuff", duration = 8, stats = { critChance = "crit" }, stats2 = nil, target = "self" } } }
byId.advanceOrderHit = { id = "advanceOrderHit", class = "Warrior", maxLevel = 10, type = "circleSelf", target = "none",
	resource = "energy", cost = 0, cooldown = 60, radius = 10, damageKind = "phys", values = { dmg = { 120, 220 } } }
UNLOCK.advanceOrderHit = 60

E.BUFFS.carnage = true
E.BUFFS.warBanner = true
E.BUFFS.advanceOrder = true

local LEVELS = { 20, 45, 70, 100 }
TUNED = (process and process.args and process.args[1] == "old") ~= true
if TUNED then
	-- Data changes of the design (R4): Battle Cry 10A cooldown x0.75 (today x0.6), Earthquake 5A lingering 5 %
	-- (today 20 %), 10A echo 25 % (today 60 %).
	local bc = table.clone(byId.battleCry)
	bc.breakpoints = { [5] = bc.breakpoints[5], [10] = { mul = { cooldown = 0.75 } } }
	byId.battleCry = bc
	local eq = table.clone(byId.earthquake)
	eq.breakpoints = {
		[5] = { lingering = { pct = 5, duration = 3, kind = "cracks" } },
		[10] = { echo = { delay = 1, pct = 25 } },
	}
	byId.earthquake = eq
end
local BASE = { "mightyStrike", "charge", "bladeWhirl", "taunt", "steelSkin", "bloodlust", "earthquake", "riposte" }

local function ranksFor(list, L)
	local r = {}
	for _, id in list do
		local n = rankAt(id, L)
		if n > 0 then
			r[id] = n
		end
	end
	return r
end

local function withFixed(r, fixed)
	for id, n in fixed do
		r[id] = n
	end
	return r
end

-- Path node approximations by level (rows open at 10/15/20/26/33/40/48/60/70/80/90)
local function berserker(L)
	local list = table.clone(BASE)
	for _, id in { "cleave", "fortitude", "battleCry", "rend", "titansWrath", "carnage" } do
		table.insert(list, id)
	end
	local r = ranksFor(list, L)
	-- cleave with Deep Wounds (+30 % bleed, row 1) and River of Blood (+30 %, row 10); Bloodbath +3 s (row 5)
	local bleedMul = 1 + (if L >= 10 then 0.3 else 0) + (if L >= 80 then 0.3 else 0)
	local cl = clone("cleave", "cleaveB", { values = { bleed = 30 * bleedMul } })
	if L >= 33 then
		cl.effects = { { kind = "bleed", duration = 8, value = "bleed" } }
	end
	if r.cleave then r.cleaveB = r.cleave; r.cleave = nil end
	local rd = clone("rend", "rendB", { values = { bleed = 40 * bleedMul } })
	if r.rend then r.rendB = r.rend; r.rend = nil end
	-- Furia: row 2 (1 %/stack), row 3 Frenzy (+2 %/stack): average 7.5 stacks
	local perStack = (if L >= 15 then 1 else 0) + (if L >= 20 then 2 else 0)
	local pctSpeed = perStack * 7.5
	local physPct = (if L >= 33 then 9 else 0) -- Ferocity row 5
	passive("bersNodes", {}, { atkSpeed = pctSpeed, physAtk = physPct, maxHp = (if L >= 80 then 12 else 0) })
	r.bersNodes = 1
	return r, { weapon = "axe2h", offhand = false }
end

local function guardian(L, n)
	local list = table.clone(BASE)
	for _, id in { "fortitude", "cleave", "battleCry", "lastBastion", "intercept", "shieldWall" } do
		table.insert(list, id)
	end
	local r = ranksFor(list, L)
	-- Groźba (row 5): +1/2/3 % damage per enemy within 10 studs, at most 5 (wojownik.md review)
	local menace = if L >= 33 then 3 * math.min(n or 1, 5) else 0
	passive("guardNodes", {}, { maxHp = (if L >= 80 then 12 else 0), armor = (if L >= 80 then 12 else 0), physAtk = menace })
	r.guardNodes = 1
	return r, { weapon = "sword1h", offhand = "shield" }
end

local function banner(L, weapon)
	local list = table.clone(BASE)
	for _, id in { "battleCry", "cleave", "fortitude", "crushingBlow", "warBanner", "advanceOrder", "advanceOrderHit" } do
		table.insert(list, id)
	end
	local r = ranksFor(list, L)
	-- Battle Cry on himself: Zapał (row 3, +12 pp own) and the caster's copy of Głos Dowódcy (row 2, allyAttack +6 %,
	-- another category than `own`, so it adds); uptime follows the real cooldown (10A x0.6)
	-- TUNED (wojownik.md after review): Głos Dowódcy +1/2/3 %, Battle Cry 10A cooldown x0.75 instead of x0.6,
	-- Rozkaz Hetmański +1/2 s instead of +2.5/5 pp crit. TUNED = false: the values before the review.
	local own = (if L >= 20 then 12 else 0) + (if L >= 15 then (if TUNED then 3 else 6) else 0)
	clone("battleCry", "battleCryC", { values = { atk = { 10 + own, 28 + own } } })
	if r.battleCry then r.battleCryC = r.battleCry; r.battleCry = nil end
	E.BUFFS.battleCryC = true
	if r.crushingBlow then
		local cb = clone("crushingBlow", "crushingBlowC", {})
		cb.effects = { { kind = "armorBreak", duration = 12, value = "armorBreak" } } -- Rozbicie Szyku (row 7)
		r.crushingBlowC = r.crushingBlow; r.crushingBlow = nil
	end
	-- War Banner: +5 -> 10 % attack speed, 12 s, Chorągiew Pułku +3 s (row 4 node), 10A +3 s (rank 10 at 62),
	-- Natchnienie +3 pp crit in the circle (row 6, build "Dowódca"); cd 30
	local wbDur = 12 + (if L >= 33 then 3 else 0) + (if L >= 62 then 3 else 0)
	byId.warBanner.duration = wbDur
	byId.warBanner.values = { haste = { 5, 10 }, crit = (if L >= 40 then 3 else 0) }
	byId.warBanner.effects = {
		{ kind = "statBuff", duration = wbDur, stats = { atkSpeed = "haste" }, pct = true, target = "self" },
		{ kind = "statBuff", duration = wbDur, stats = { critChance = "crit" }, target = "self" },
	}
	-- Order to Advance (self part): +10 -> 20 pp crit, 10 s; Chwała +3 s (row 9), 5A +2 s (rank 5 at 76),
	-- 10A +5 pp (rank 10 at 95), Rozkaz Hetmański +5 pp (row 11)
	local aoDur = 10 + (if L >= 70 then 3 else 0) + (if L >= 76 then 2 else 0) + (if TUNED and L >= 90 then 2 else 0)
	local aoAdd = (if L >= 95 then 5 else 0) + (if not TUNED and L >= 90 then 5 else 0)
	byId.advanceOrder.duration = aoDur
	byId.advanceOrder.values = { crit = { 10 + aoAdd, 20 + aoAdd } }
	byId.advanceOrder.effects = { { kind = "statBuff", duration = aoDur, stats = { critChance = "crit" }, target = "self" } }
	-- Nodes: Hart Chorążego +12 % HP (row 5, 33), Weteran Kampanii +12 % armour (row 10, 80). No other damage nodes.
	passive("bannerNodes", {}, { maxHp = (if L >= 33 then 12 else 0), armor = (if L >= 80 then 12 else 0) })
	r.bannerNodes = 1
	return r, weapon or { weapon = "saber1h", offhand = "shield" }
end

local function baseOnly(L)
	local list = table.clone(BASE)
	for _, id in { "fortitude", "cleave", "battleCry" } do
		table.insert(list, id)
	end
	return ranksFor(list, L), nil
end

local BUILDS = {
	{ "Baza (1H+tarcza)", function(L) return baseOnly(L) end },
	{ "Baza (2H topór)", function(L) local r = baseOnly(L) return r, { weapon = "axe2h", offhand = false } end },
	{ "Berserker", berserker },
	{ "Strażnik", guardian },
	{ "Chorąży miecz+tarcza", function(L) return banner(L, { weapon = "sword1h", offhand = "shield" }) end },
	{ "Chorąży szabla+tarcza", function(L) return banner(L) end },
	{ "(Chorąży włócznia)", function(L) return banner(L, { weapon = "spear2h", offhand = false }) end },
}

-- Skill damage normalised to weapon speed: attack x speed / 0.8 (two-handed axe = 1, so the Berserker is unchanged).
local NORM_REF = 0.8
local Bases = require("../src/shared/Data/Items/Bases")
local function skillMul(gear, norm)
	if not norm then
		return 1
	end
	local wt = (gear and gear.weapon) or "sword1h"
	return Bases.byType[wt].weapon(1).speed / NORM_REF
end

local function eHP(p, L)
	local v = p.values
	local red = Damage.reduction(v.armor, L)
	return v.maxHp / (1 - red), v.maxHp, red
end

for _, norm in { false, true } do
	print(if norm then "== skill damage normalised to weapon speed (x speed / 0.8)" else "== today: skill damage from weapon damage per hit")
	print("build | L | single 60 s x Bers | group 3 x 8 s x Bers | solo pace x Bers (6 + 8/g)/14 | eHP x Bers | AoE/single burst | sustained x basic | energy 60 s")
	for _, L in LEVELS do
		local res = {}
		for _, b in BUILDS do
			local ranks, gear = b[2](L, 1)
			local mul = skillMul(gear, norm)
			local m = B.monster(B.GENERIC, L)
			local sus = E.fight({ classId = "Warrior", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, gearOpts = gear, skillAtkMul = mul })
			local burst = E.fight({ classId = "Warrior", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 8, gearOpts = gear, skillAtkMul = mul })
			local basic = E.fight({ classId = "Warrior", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, gearOpts = gear, skills = false })
			local p = E.player("Warrior", L, ranks, nil, gear)
			local ehp = eHP(p, L)
			local ranks3, gear3 = b[2](L, 3)
			local aoe = E.fight({ classId = "Warrior", L = L, ranks = ranks3, targets = { m, m, m }, dummy = true, seconds = 8, gearOpts = gear3, skillAtkMul = mul })
			table.insert(res, { name = b[1], sus = sus.dps, aoe = aoe.dps, ehp = ehp, burst = burst.dps, basic = basic.dps, spent = sus.spent })
		end
		local ref = res[3]
		for _, x in res do
			local g = x.aoe / ref.aoe
			print(fmt("%s | %d | %.2f | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f", x.name, L, x.sus / ref.sus, g, (6 + 8 / g) / 14, x.ehp / ref.ehp, x.aoe / x.burst, x.sus / x.basic, x.spent))
		end
		print("")
	end
end
