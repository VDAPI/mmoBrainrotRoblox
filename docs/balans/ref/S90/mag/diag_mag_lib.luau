-- Rough check for the Mage paths design (rozwoj/mag.md). Not game code.
-- Base 8 on the new ladder, automatic ranks (global A5: step 4, cap 95), mana cost curve (global G), path nodes as
-- fake passives, tag multipliers and cloned skill defs; Arcane Charges, Evocation, Torrent beam in SkillEngineMag.
local E = require("./SkillEngineMag")
local B = require("../tests/Balance")
local FightSim = require("../src/shared/Logic/FightSim")
local AreaRates = require("../src/shared/Logic/AreaRates")
local Stats = require("../src/shared/Data/Stats")
local SkillData = require("../src/shared/Data/Skills")
local Damage = require("../src/shared/Logic/Damage")
local fmt = string.format

local byId = SkillData.byId

-- Magiczny Pocisk gets an explicit `hits = 1` (rozwoj/mag.md 2), so its 10B `add.hits = 1` gives 2 bolts
-- (Skills.effective adds to `def.hits or 0`).
do
	local d = table.clone(byId.firebolt)
	d.hits = 1
	byId.firebolt = d
end

local UNLOCK = {
	firebolt = 1, fireball = 3, iceShard = 6, chainLightning = 10, blink = 14, frostNova = 18, meteor = 30, firewall = 45,
	elementalist = 10, manaShield = 10,
	elementalVortex = 26, arcaneDischarge = 26,
	meteorStorm = 48, evocation = 48,
	cataclysm = 60, arcaneTorrent = 60,
	focus = 80, arcaneMind = 80,
}

local function rankAt(id, L)
	local base = string.split(id, "#")[1]
	local s = byId[id]
	local u = UNLOCK[base]
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

-- Mana cost multiplier (global G): 1.0 / 1.4 / 1.9 / 2.5 at 20 / 45 / 70 / 100.
local function costMul(L)
	local pts = { { 20, 1.0 }, { 45, 1.4 }, { 70, 1.9 }, { 100, 2.5 } }
	if L <= 20 then
		return 1
	end
	for i = 2, #pts do
		local a, b = pts[i - 1], pts[i]
		if L <= b[1] then
			return a[2] + (b[2] - a[2]) * (L - a[1]) / (b[1] - a[1])
		end
	end
	return 2.5
end

local function def(spec)
	spec.class = "Mage"
	spec.resource = if spec.type == "passive" then nil else "mana"
	spec.damageKind = "magic"
	spec.maxLevel = spec.maxLevel or 10
	spec.target = spec.target or "enemy"
	spec.cost = spec.cost or 0
	spec.cooldown = spec.cooldown or 0
	byId[spec.id] = spec
	return spec
end

-- Tunable numbers (rozwoj/mag.md). Node values are per rank (rank r gives r x value).
local P = {
	vortex = { dmg = { 12, 13 }, hits = 10, cost = 40, cd = 12 },
	cataclysm = { dmg = { 60, 70 }, hits = 5, cost = 90, cd = 30 },
	storm = { dmg = { 60, 80 } },
	discharge = { dmg = { 140, 230 }, perCharge = 12, cost = 20, cd = 6 },
	-- Torrent: flat, strong ticks so the 4 s channel beats the spells it displaces (GCD 0.5 s); bp5 = 5A growth, bp10 = 10A dmg
	torrent = { dmg = { 160, 170 }, growth = 2, drain = 1.5, cd = 25, dur = 4, bp5 = 1, bp10 = 30 },
	evocation = { cd = 120 },
	charges = { max = 4, dmg = 2, cost = 15 },
	-- Niszczyciel nodes (per rank)
	sweep = 2, scorched = 2, cascade = 0.5, volatile = { dmg = 2, cost = 10 }, thrift = 4, eye = 1, might = 2,
	glass = { dmg = 2, hp = 4 }, wrath = 1, raging = 0.5, swift = 2, overflow = 3, grit = 4, final = 1, tough = 4,
	-- Arkanista nodes (per rank)
	precision = 1, reserve = 4, acuity = 1, resonance = 2, overload = { dmg = 2, cost = 10 }, fullDischarge = 10 / 3,
	arcMight = 1, reclaim = 0.1, will = 4, mounting = 0.5, coolHead = 4, invocation = 5, rending = 0.5,
	-- masterMind: damage taken -4% per rank while channelling (no damage, no mana: 0 here); archmage: Evocation channel -0.5 s per rank
	well = 0.25, masterMind = 0, archmage = 0.5, endless = 0.5,
	focusMana = { 4, 20 },
	-- Tajemny Umysł in the Arkanista path (rozwoj/mag.md 3.2)
	mind = { crit = { 1, 3 }, critDmg = { 3, 8 } },
}
-- Tuning experiments (tools/diag_mag_tune.luau): _G.TUNE overrides fields of P before the skills are defined.
for k, v in (_G :: any).TUNE or {} do
	P[k] = v
end
local CDR = { sec = 0, max = 5 }
def({ id = "elementalVortex", type = "circleSelf", target = "none", cost = P.vortex.cost, cooldown = P.vortex.cd, radius = 7, hits = P.vortex.hits, interval = 0.4, adaptive = true, values = { dmg = P.vortex.dmg },
	breakpoints = { [5] = { add = { radius = 2 } }, [10] = { add = { hits = 3 } } } })
def({ id = "cataclysm", type = "circleTarget", target = "point", cost = P.cataclysm.cost, cooldown = P.cataclysm.cd, radius = 12, hits = P.cataclysm.hits, interval = 0.6, delay = 0, adaptive = true, values = { dmg = P.cataclysm.dmg },
	breakpoints = { [5] = { add = { radius = 3 } }, [10] = { lingering = { pct = 25, duration = 4, kind = "element" } } } })
def({ id = "arcaneDischarge", type = "projectile", cost = P.discharge.cost, cooldown = P.discharge.cd, range = 38, values = { dmg = P.discharge.dmg, perCharge = P.discharge.perCharge },
	breakpoints = { [5] = { values = { perCharge = 5 } }, [10] = { execute = 35 } } })
def({ id = "arcaneTorrent", type = "beam", cost = 0, cooldown = P.torrent.cd, duration = P.torrent.dur, interval = 0.5, values = { dmg = P.torrent.dmg, growth = P.torrent.growth, drain = P.torrent.drain },
	breakpoints = { [5] = { values = { growth = P.torrent.bp5 or 3 } }, [10] = { values = { dmg = P.torrent.bp10 } } } })
-- Elemental Fury moved to row 7 (48) with lower values
do
	local d = byId.meteorStorm
	d.values = table.clone(d.values)
	d.values.dmg = P.storm.dmg
end

-- B options (rozwoj/mag.md); "a" keeps the data. Values of 5 and 10 add up (fixed Skills.effective).
local BP_B = {
	firebolt = { [5] = P.fireboltB5 or { mul = { cooldown = 0.88 } }, [10] = { add = { hits = 1 }, values = { dmg = -124 } } },
	fireball = { [5] = { execute = 35 }, [10] = { values = { dmg = 55 } } },
	iceShard = { [5] = { values = { dmg = 20 } }, [10] = { mul = { cooldown = 0.85 } } },
	chainLightning = { [5] = { values = { dmg = 25 } }, [10] = { mul = { cooldown = 0.8 } } },
	frostNova = { [5] = { selfEffect = { kind = "damageReduction", duration = 4, value = 20, target = "self" } }, [10] = { echo = { delay = 1.5, pct = 40 } } },
	firewall = { [5] = { mul = { cooldown = 0.75 } }, [10] = { values = { dmg = 18 } } },
	meteor = { [5] = { values = { dmg = 45 } }, [10] = { values = { dmg = 100 } } },
	meteorStorm = { [5] = { mul = { cooldown = 0.75 } }, [10] = { values = { dmg = 22 } } },
	elementalVortex = { [5] = { values = { dmg = 2 } }, [10] = { selfEffect = { kind = "damageReduction", duration = 6, value = 20, target = "self" } } },
	cataclysm = { [5] = { values = { dmg = 7 } }, [10] = { echo = { delay = 0.8, pct = 100 } } },
	arcaneDischarge = { [5] = { mul = { cooldown = 0.8 } }, [10] = { splash = { radius = 5, pct = 40 } } },
	arcaneTorrent = { [5] = { channelMove = 50 }, [10] = { splash = { radius = 4, pct = 35 } } },
}

-- Variant of a skill: new id "<id>#<tag>", patched fields, values and breakpoints.
local function variant(id, tag, patch)
	local d = table.clone(byId[id])
	d.id = id .. "#" .. tag
	d.values = table.clone(d.values)
	for k, v in patch do
		if k == "values" then
			for f, x in v do
				d.values[f] = x
			end
		else
			d[k] = v
		end
	end
	byId[d.id] = d
	return d.id
end

local function passive(id, flat, pct, hooks)
	local values, f, p, h = {}, {}, {}, {}
	for stat, v in flat or {} do
		values["f_" .. stat] = v
		f[stat] = "f_" .. stat
	end
	for stat, v in pct or {} do
		values["p_" .. stat] = v
		p[stat] = "p_" .. stat
	end
	for hk, v in hooks or {} do
		values["h_" .. hk] = v
		h[hk] = "h_" .. hk
	end
	byId[id] = { id = id, class = "Mage", maxLevel = 1, type = "passive", values = values, passive = { flat = f, pct = p, hooks = h }, cost = 0, cooldown = 0, unlock = 1 }
	UNLOCK[id] = 1
end

-- Focus retuned (rozwoj/mag.md): pool +4 -> 20 %, no regen line (regen follows the pool)
-- Focus as a reserve (rozwoj/mag.md): pool +4 -> 20 %, regeneration stays as without it
local focusT = variant("focus", "t", { values = { mana = P.focusMana, regen = { -3.85, -16.67 } } })
-- Arcane Mind in the Arkanista path (rozwoj/mag.md): crit 2 -> 6, crit damage 5 -> 15
local mindT = variant("arcaneMind", "t", { values = { crit = P.mind.crit, critDmg = P.mind.critDmg } })

local BASE = { "firebolt", "fireball", "iceShard", "chainLightning", "blink", "frostNova", "firewall", "meteor" }

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

-- Applies breakpoint choices: choices[id] = "ab" (rank 5 option, rank 10 option). Variants keep the id prefix.
local function choose(ranks, choices)
	local out = {}
	for id, rank in ranks do
		local base = string.split(id, "#")[1]
		local c = choices[base]
		local d = byId[id]
		if c and d and d.breakpoints and BP_B[base] then
			local a5, a10 = d.breakpoints[5], d.breakpoints[10]
			local b5, b10 = BP_B[base][5], BP_B[base][10]
			local five = if string.sub(c, 1, 1) == "b" then b5 else a5
			local ten = table.clone(if string.sub(c, 2, 2) == "b" then b10 else a10)
			-- values of rank 5 and 10 add up
			if five and five.values and ten then
				local v = table.clone(ten.values or {})
				for f, x in five.values do
					v[f] = (v[f] or 0) + x
				end
				ten.values = v
			end
			local vid = variant(id, "c" .. c, { breakpoints = { [5] = five, [10] = ten } })
			out[vid] = rank
		else
			out[id] = rank
		end
	end
	return out
end

local CHOICE_D = { firebolt = "aa", fireball = "aa", iceShard = "aa", chainLightning = "aa", frostNova = "aa", firewall = "ab", meteor = "aa", meteorStorm = "ab", elementalVortex = "aa", cataclysm = "aa" }
local CHOICE_A = { firebolt = "bb", fireball = "ab", iceShard = "bb", chainLightning = "bb", frostNova = "ab", firewall = "bb", meteor = "ba", arcaneDischarge = "aa", arcaneTorrent = "aa", evocation = "aa" }
local CHOICE_A_GRIND = { firebolt = "aa", fireball = "aa", iceShard = "ab", chainLightning = "aa", frostNova = "aa", firewall = "ab", meteor = "aa", arcaneDischarge = "ab", arcaneTorrent = "ab" }

-- Rows (global A2) and point requirements in the main path.
local ROWLV = { 10, 15, 20, 26, 33, 40, 48, 60, 70, 80, 90 }
local REQ = { 0, 2, 4, 6, 9, 12, 15, 18, 21, 24, 28 }

-- Nodes: path ("d" Niszczyciel, "a" Arkanista), row, max rank, effect(state, rank).
local NODES = {
	d_elementalist = { "d", 1, 1, function(b) b.skills.elementalist = true end },
	d_sweep = { "d", 1, 3, function(b, r) b.area += P.sweep * r end },
	d_scorched = { "d", 2, 3, function(b, r) b.area += P.scorched * r end },
	d_cascade = { "d", 2, 3, function(b, r) b.killMana += P.cascade * r end },
	d_wide = { "d", 2, 3, function() end },
	d_volatile = { "d", 3, 3, function(b, r) b.area += P.volatile.dmg * r; b.areaCost += P.volatile.cost * r end },
	d_thrift = { "d", 3, 3, function(b, r) b.areaCost -= P.thrift * r end },
	d_vortex = { "d", 4, 1, function(b) b.skills.elementalVortex = true end },
	d_eye = { "d", 4, 3, function(b, r) b.vortexHits += P.eye * r end },
	d_might = { "d", 5, 3, function(b, r) b.pct.magAtk = (b.pct.magAtk or 0) + P.might * r end },
	d_veins = { "d", 5, 3, function() end },
	d_tough = { "d", 5, 3, function(b, r) b.pct.maxHp = (b.pct.maxHp or 0) + P.tough * r end },
	d_glass = { "d", 6, 3, function(b, r) b.area += P.glass.dmg * r; b.pct.maxHp = (b.pct.maxHp or 0) - P.glass.hp * r end },
	-- Elemental Mantle: 4/8/12 % less damage while the Vortex is up (about 2/3 of the time); as effective HP
	d_mantle = { "d", 6, 3, function(b, r) b.pct.maxHp = (b.pct.maxHp or 0) + 3 * r end },
	d_fury = { "d", 7, 1, function(b) b.skills.meteorStorm = true end },
	d_wrath = { "d", 7, 3, function(b, r) b.wrath = P.wrath * r end },
	d_cataclysm = { "d", 8, 1, function(b) b.skills.cataclysm = true end },
	d_raging = { "d", 9, 3, function(b, r) b.vortexDmg += P.raging * r end },
	d_swift = { "d", 9, 3, function(b, r) b.cataCd -= P.swift * r end },
	d_focus = { "d", 10, 1, function(b) b.skills.focus = true end },
	d_overflow = { "d", 10, 3, function(b, r) b.areaCost -= P.overflow * r end },
	d_grit = { "d", 10, 3, function(b, r) b.pct.maxHp = (b.pct.maxHp or 0) + P.grit * r end },
	d_final = { "d", 11, 2, function(b, r) b.cataHits += P.final * r end },

	a_manaShield = { "a", 1, 1, function() end },
	a_precision = { "a", 1, 3, function(b, r) b.single += P.precision * r end },
	-- Rezerwa as a mana reserve (manaReserve): bigger pool, regeneration as without it
	a_reserve = { "a", 2, 3, function(b, r)
		b.pct.maxMana = (b.pct.maxMana or 0) + P.reserve * r
		b.pct.manaRegen = (b.pct.manaRegen or 0) - (1 - 1 / (1 + P.reserve * r / 100)) * 100
	end },
	a_acuity = { "a", 2, 3, function(b, r) b.flat.critChance = (b.flat.critChance or 0) + P.acuity * r end },
	a_composure = { "a", 2, 3, function() end },
	a_resonance = { "a", 3, 3, function(b, r) b.resonance = P.resonance * r end },
	a_overload = { "a", 3, 3, function(b, r) b.all += P.overload.dmg * r; b.allCost += P.overload.cost * r end },
	a_discharge = { "a", 4, 1, function(b) b.skills.arcaneDischarge = true end },
	a_fullDischarge = { "a", 4, 3, function(b, r) b.perCharge += P.fullDischarge * r end },
	a_arcMight = { "a", 5, 3, function(b, r) b.pct.magAtk = (b.pct.magAtk or 0) + P.arcMight * r end },
	a_reclaim = { "a", 5, 3, function(b, r) b.reclaim = P.reclaim * r end },
	a_will = { "a", 5, 3, function(b, r) b.pct.maxHp = (b.pct.maxHp or 0) + P.will * r end },
	a_mounting = { "a", 6, 3, function(b, r) b.chargeDmg += P.mounting * r end },
	a_coolHead = { "a", 6, 3, function(b, r) b.chargeCost -= P.coolHead * r end },
	a_evocation = { "a", 7, 1, function(b) b.skills.evocation = true end },
	a_invocation = { "a", 7, 3, function(b, r) b.invocation = P.invocation * r end },
	a_torrent = { "a", 8, 1, function(b) b.skills.arcaneTorrent = true end },
	a_rending = { "a", 9, 3, function(b, r) b.growth += P.rending * r end },
	a_well = { "a", 9, 3, function(b, r) b.drain -= P.well * r end },
	a_arcaneMind = { "a", 10, 1, function(b) b.skills.arcaneMind = true end },
	a_masterMind = { "a", 10, 3, function(b, r) b.flat.critDmg = (b.flat.critDmg or 0) + P.masterMind * r end },
	a_archmage = { "a", 10, 3, function(b, r) b.evoDur = P.archmage * r end },
	a_endless = { "a", 11, 2, function(b, r) b.torrentDur += P.endless * r end },
}

-- Buys nodes in priority order with floor(L/2) points; rows open by level, rows 3+ only in the main path and
-- with the point requirement. Returns { [node] = rank }.
local function buy(order, main, L)
	local pts = math.floor(L / 2)
	local have, spentMain = {}, 0
	local changed = true
	while changed and pts > 0 do
		changed = false
		for _, id in order do
			local n = NODES[id]
			local path, row, maxR = n[1], n[2], n[3]
			local r = have[id] or 0
			local inMain = path == main
			local open = L >= ROWLV[row] and (row <= 2 or (inMain and spentMain >= REQ[row]))
			if open and r < maxR and pts > 0 then
				have[id] = r + 1
				pts -= 1
				if inMain then
					spentMain += 1
				end
				changed = true
				break
			end
		end
	end
	return have
end

local function build(order, main, L, choices, weaponOk)
	local have = buy(order, main, L)
	local b = {
		skills = {}, area = 0, single = 0, all = 0, areaCost = 0, allCost = 0, killMana = 0, vortexHits = 0,
		vortexDmg = 0, cataCd = 0, cataHits = 0, wrath = 0, pct = {}, flat = {}, hooks = {}, resonance = nil,
		perCharge = 0, reclaim = nil, chargeDmg = 0, chargeCost = 0, invocation = nil, growth = 0, drain = 0,
		torrentDur = 0, evoDur = 0, have = have,
	}
	for id, r in have do
		NODES[id][4](b, r)
	end
	local ranks = ranksFor(BASE, L)
	local function add(id)
		local n = rankAt(id, L)
		if n > 0 then
			ranks[id] = n
		end
	end
	if b.skills.elementalist then
		add("elementalist")
	end
	if b.skills.focus then
		ranks[focusT] = rankAt(focusT, L)
	end
	if b.skills.arcaneMind then
		ranks[mindT] = rankAt(mindT, L)
	end
	if b.skills.evocation then
		local v = variant("evocation", "a" .. L .. "_" .. b.evoDur, { cooldown = P.evocation.cd, duration = 3 - b.evoDur })
		UNLOCK[v] = UNLOCK.evocation
		ranks[v] = rankAt(v, L)
	end
	if b.skills.elementalVortex then
		local v = variant("elementalVortex", "d" .. L, { hits = P.vortex.hits + b.vortexHits, values = { dmg = { P.vortex.dmg[1] + b.vortexDmg, P.vortex.dmg[2] + b.vortexDmg } } })
		ranks[v] = rankAt(v, L)
	end
	if b.skills.meteorStorm then
		local v = variant("meteorStorm", "d" .. L, { cdrPerTarget = if b.wrath > 0 then { sec = b.wrath, max = 5 } else nil })
		ranks[v] = rankAt(v, L)
	end
	if b.skills.cataclysm then
		local v = variant("cataclysm", "d" .. L, { hits = P.cataclysm.hits + b.cataHits, cooldown = P.cataclysm.cd + b.cataCd })
		ranks[v] = rankAt(v, L)
	end
	if b.skills.arcaneDischarge then
		local v = variant("arcaneDischarge", "a" .. L, { values = { perCharge = P.discharge.perCharge + b.perCharge } })
		ranks[v] = rankAt(v, L)
	end
	if b.skills.arcaneTorrent then
		local v = variant("arcaneTorrent", "a" .. L, { duration = P.torrent.dur + b.torrentDur, values = { growth = P.torrent.growth + b.growth, drain = P.torrent.drain + b.drain } })
		ranks[v] = rankAt(v, L)
	end
	local mage = { tagDamage = { area = b.area, single = b.single, all = b.all }, tagCost = { area = b.areaCost, all = b.allCost }, use = { evocation = true } }
	if b.skills.arcaneDischarge then
		mage.charges = { max = P.charges.max, dmg = P.charges.dmg + b.chargeDmg, cost = P.charges.cost + b.chargeCost }
		mage.reclaim = b.reclaim
	end
	mage.resonance = b.resonance
	mage.invocation = b.invocation
	mage.killMana = b.killMana
	passive("nodes" .. main .. L, b.flat, b.pct, b.hooks)
	ranks["nodes" .. main .. L] = 1
	return choose(ranks, choices), mage, have
end

local ORDER_BASE = { "d_elementalist", "d_sweep", "a_precision", "d_scorched", "a_reserve", "a_acuity", "d_cascade", "a_manaShield", "d_wide", "a_composure" }
local ORDER_D = { "d_elementalist", "d_sweep", "d_scorched", "d_volatile", "d_vortex", "d_eye", "d_might", "d_glass", "d_fury", "d_wrath", "d_cataclysm", "d_cascade", "d_raging", "d_focus", "d_overflow", "d_final", "d_grit", "d_wide", "d_tough", "d_veins", "a_manaShield" }
local ORDER_D_THRIFT = table.clone(ORDER_D)
ORDER_D_THRIFT[4] = "d_thrift"
local ORDER_D_MANTLE = table.clone(ORDER_D)
ORDER_D_MANTLE[table.find(ORDER_D, "d_glass")] = "d_mantle"
local ORDER_A = { "a_manaShield", "a_precision", "d_elementalist", "a_reserve", "a_resonance", "a_discharge", "a_fullDischarge", "a_arcMight", "a_mounting", "a_evocation", "a_invocation", "a_torrent", "a_rending", "a_arcaneMind", "a_archmage", "a_masterMind", "a_endless", "a_reclaim", "a_acuity", "a_will", "a_composure" }
local ORDER_A_OVER = table.clone(ORDER_A)
ORDER_A_OVER[5] = "a_overload"
local ORDER_A_COOL = table.clone(ORDER_A)
ORDER_A_COOL[table.find(ORDER_A, "a_mounting")] = "a_coolHead"
local ORDER_A_WELL = table.clone(ORDER_A)
ORDER_A_WELL[table.find(ORDER_A, "a_rending")] = "a_well"

local function baseBuild(L)
	return build(ORDER_BASE, "none", L, CHOICE_D)
end

local STAFF = { weapon = "staff", offhand = false }
local RUNE = { weapon = "runestaff", offhand = false }
local WANDORB = { weapon = "wand", offhand = "orb" }
local WANDTOME = { weapon = "wand", offhand = "tome" }

local function D(order)
	return function(L) return build(order, "d", L, CHOICE_D) end
end
local function A(order, choices, grind)
	return function(L)
		local ranks, mage, have = build(order, "a", L, choices or CHOICE_A)
		if grind then
			for id in ranks do
				if string.find(id, "arcaneTorrent") then
					ranks[id] = nil
				end
			end
		end
		return ranks, mage, have
	end
end

-- { name, build, gear, grind build (optional) }
-- Path weapons (rozwoj/mag.md 1): Niszczyciel staff or wand + orb, Arkanista runestaff or wand + tome.
local BUILDS = {
	{ "Baza, kostur", baseBuild, STAFF },
	{ "Baza, k. runiczny", baseBuild, RUNE },
	{ "Baza, różdżka+kula", baseBuild, WANDORB },
	{ "Baza, różdżka+księga", baseBuild, WANDTOME },
	{ "Niszczyciel, kostur", D(ORDER_D), STAFF },
	{ "Niszczyciel, oszczędny", D(ORDER_D_THRIFT), STAFF },
	{ "Niszczyciel, płaszcz", D(ORDER_D_MANTLE), STAFF },
	{ "Niszczyciel, różdżka+kula", D(ORDER_D), WANDORB },
	{ "Arkanista, k. runiczny", A(ORDER_A), RUNE, A(ORDER_A, CHOICE_A_GRIND, true) },
	{ "Arkanista, przeciążenie", A(ORDER_A_OVER), RUNE, A(ORDER_A_OVER, CHOICE_A_GRIND, true) },
	{ "Arkanista, różdżka+księga", A(ORDER_A), WANDTOME, A(ORDER_A, CHOICE_A_GRIND, true) },
}

return { ORDER_A_COOL = ORDER_A_COOL, ORDER_A_WELL = ORDER_A_WELL, BP_B = BP_B, CHOICE_A = CHOICE_A, CHOICE_D = CHOICE_D, ORDER_A_OVER = ORDER_A_OVER, ORDER_D_THRIFT = ORDER_D_THRIFT, ORDER_D_MANTLE = ORDER_D_MANTLE, STAFF = STAFF, RUNE = RUNE, WANDORB = WANDORB, WANDTOME = WANDTOME, buildWith = build, P = P, BUILDS = BUILDS, costMul = costMul, rankAt = rankAt, UNLOCK = UNLOCK, variant = variant, passive = passive, buy = buy, NODES = NODES, ORDER_D = ORDER_D, ORDER_A = ORDER_A, ORDER_BASE = ORDER_BASE }
