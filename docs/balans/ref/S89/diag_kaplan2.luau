-- Second pass for rozwoj/kaplan.md after review: one baseline (Berserker from rz/wojownik/tools/diag_wojownik.luau,
-- same engine, axe2h), every Cleric path with its own weapon (gearOpts), reference breakthroughs set explicitly.
-- Not game code. Run from rz/kaplan: lune run tools/diag_kaplan2.luau  (env KP=<preset> to pick a parameter set)
local E = require("./SkillEngine")
local B = require("../tests/Balance")
local FightSim = require("../src/shared/Logic/FightSim")
local AreaRates = require("../src/shared/Logic/AreaRates")
local Stats = require("../src/shared/Data/Stats")
local SkillData = require("../src/shared/Data/Skills")
local Classes = require("../src/shared/Data/Classes")
local Damage = require("../src/shared/Logic/Damage")
local process = require("@lune/process")
local fmt = string.format

local byId = SkillData.byId
-- node behaviours that work at every rank (modify nodes), merged after the breakpoints
local Skills = require("../src/shared/Logic/Skills")
local origEffective = Skills.effective
Skills.effective = function(skill, level, enabled)
	local d, bp = origEffective(skill, level, enabled)
	if skill.nodeBp then
		bp = table.clone(bp)
		for k, v in skill.nodeBp do
			bp[k] = v
		end
	end
	return d, bp
end
local LEVELS = { 20, 45, 70, 100 }

local function rankAtU(unlock, maxLevel, L)
	if L < unlock then
		return 0
	end
	local span = math.min(36, 95 - unlock)
	local r = 0
	for n = 1, maxLevel do
		if unlock + math.floor((n - 1) * span / (maxLevel - 1) + 0.5) <= L then
			r = n
		end
	end
	return r
end

---------------------------------------------------------------------------------------------------------------
-- Berserker reference (verbatim port of diag_wojownik.luau berserker())
---------------------------------------------------------------------------------------------------------------
local WUNLOCK = {
	mightyStrike = 1, charge = 3, bladeWhirl = 6, taunt = 10, steelSkin = 14, bloodlust = 18, earthquake = 30, riposte = 45,
	fortitude = 10, cleave = 10, battleCry = 10, titansWrath = 48, rend = 26, carnage = 60,
}
local function wrank(id, L)
	local s = byId[id]
	local u = WUNLOCK[id]
	if not s or not u then
		return 0
	end
	return rankAtU(u, s.maxLevel, L)
end
local function wclone(id, newId, patch)
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
local function wpassive(id, flat, pct)
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
byId.rend = { id = "rend", class = "Warrior", maxLevel = 10, type = "target", target = "enemy", resource = "energy",
	cost = 25, cooldown = 10, range = 8, damageKind = "phys", values = { dmg = { 140 * 1.8, 250 * 1.8 }, bleed = 40 },
	effects = { { kind = "bleed", duration = 6, value = "bleed" } } }
byId.carnage = { id = "carnage", class = "Warrior", maxLevel = 10, type = "buff", target = "self", resource = "energy",
	cost = 30, cooldown = 45, duration = 8, damageKind = "phys", values = { atk = { 15, 25 } },
	effects = { { kind = "statBuff", duration = 8, stats = { physAtk = "atk" }, pct = true, target = "self" } } }
E.BUFFS.carnage = true
local WBASE = { "mightyStrike", "charge", "bladeWhirl", "taunt", "steelSkin", "bloodlust", "earthquake", "riposte" }
local function berserker(L)
	local list = table.clone(WBASE)
	for _, id in { "cleave", "fortitude", "battleCry", "rend", "titansWrath", "carnage" } do
		table.insert(list, id)
	end
	local r = {}
	for _, id in list do
		local n = wrank(id, L)
		if n > 0 then
			r[id] = n
		end
	end
	local bleedMul = 1 + (if L >= 10 then 0.3 else 0) + (if L >= 80 then 0.3 else 0)
	local cl = wclone("cleave", "cleaveB", { values = { bleed = 30 * bleedMul } })
	if L >= 33 then
		cl.effects = { { kind = "bleed", duration = 8, value = "bleed" } }
	end
	if r.cleave then r.cleaveB = r.cleave; r.cleave = nil end
	wclone("rend", "rendB", { values = { bleed = 40 * bleedMul } })
	if r.rend then r.rendB = r.rend; r.rend = nil end
	local perStack = (if L >= 15 then 1 else 0) + (if L >= 20 then 2 else 0)
	wpassive("bersNodes", {}, { atkSpeed = perStack * 7.5, physAtk = (if L >= 33 then 9 else 0), maxHp = (if L >= 80 then 12 else 0) })
	r.bersNodes = 1
	return r, { weapon = "axe2h", offhand = false }
end

---------------------------------------------------------------------------------------------------------------
-- Cleric
---------------------------------------------------------------------------------------------------------------
local PLAN = nil
local origStatsFor = B.statsFor
B.statsFor = function(classId, level)
	if classId ~= "Cleric" or PLAN == nil then
		return origStatsFor(classId, level)
	end
	local stats = table.clone(Classes.get(classId).startStats)
	local seq = {}
	for stat, n in PLAN do
		for _ = 1, n do
			table.insert(seq, stat)
		end
	end
	table.sort(seq)
	for i = 1, (level - 1) * 5 do
		local id = seq[(i - 1) % #seq + 1]
		stats[id] += 1
	end
	return stats
end

local function def(spec)
	local base = byId[spec.from or spec.id]
	local d = if base then table.clone(base) else {
		class = "Cleric", order = 99, target = "enemy", resource = "mana", damageKind = "magic", values = {},
		glyph = "?", vfx = spec.id, nameKey = "", descKey = "",
	}
	d.values = table.clone(d.values or {})
	for k, v in spec do
		if k ~= "from" and k ~= "values" then
			d[k] = v
		end
	end
	for k, v in spec.values or {} do
		d.values[k] = v
	end
	d.id = spec.id
	d.requires = nil
	d.maxLevel = if d.type == "passive" then (spec.maxLevel or 5) else 10
	byId[spec.id] = d
	return d
end
local function node(id, passive, value)
	byId[id] = { id = id, class = "Cleric", type = "passive", maxLevel = 1, unlock = 1, values = { v = value }, passive = passive, cost = 0, cooldown = 0 }
	return id
end
local function healEquiv(p, hp, mag)
	return (hp * p.values.maxHp / 100 + mag * p.values.magAtk / 100) / p.values.magAtk * 100
end
local function scaled(pair, r)
	if type(pair) == "number" then
		return pair
	end
	return pair[1] + (pair[2] - pair[1]) * (math.max(1, r) - 1) / 9
end
local function addPair(pair, d)
	return { pair[1] + d, pair[2] + d }
end

-- Reference breakthroughs per path (kaplan.md 3.1-3.3); only those that change damage matter here.
local BP = {
	ink = {
		hs = { [5] = { execute = 30 }, [10] = { effect = { kind = "stun", duration = 0.8 } } },
		jud = { [5] = { stunNear = { radius = 6, duration = 0.8 } }, [10] = { values = { dmg = 100 } } },
		rad = { [5] = { pull = 16 }, [10] = { echo = { delay = 1, pct = 40 } } },
		brand = { [5] = { values = { dot = 30 } }, [10] = { lifesteal = 20 } },
		hammer = { [5] = { add = { radius = 2 } }, [10] = { echo = { delay = 1.2, pct = 50 } } },
	},
	uzd = {
		hs = { [5] = { splash = { radius = 5, pct = 40 } }, [10] = { healWounded = 30 } },
		jud = { [5] = { lifesteal = 30 }, [10] = { effect = { kind = "vulnerability", duration = 6, value = 10 } } },
		rad = { [5] = { pull = 16 }, [10] = { values = { heal = 50 } } },
	},
	fort = {
		hs = { [5] = { splash = { radius = 5, pct = 40 } }, [10] = { effect = { kind = "stun", duration = 0.8 } } },
		jud = { [5] = { lifesteal = 30 }, [10] = { effect = { kind = "vulnerability", duration = 6, value = 10 } } },
		rad = { [5] = { add = { radius = 3 } }, [10] = { echo = { delay = 1, pct = 40 } } },
	},
}
BP.base = BP.uzd

local GEAR = {
	base = { weapon = "mace1h", offhand = "shield" },
	ink = { weapon = "mace1h", offhand = "relic" },
	inkShield = { weapon = "mace1h", offhand = "shield" },
	uzd = { weapon = "scepter", offhand = "shield" },
	uzdStaff = { weapon = "holystaff", offhand = false },
	fort = { weapon = "mace1h", offhand = "relic" },
}

-- P: parameter set (base values, node values, new skills)
local function cleric(variant, L, P, gear, early)
	local ranks = {}
	local function give(id, unlock, maxLevel)
		local r = rankAtU(unlock, maxLevel or 10, L)
		if r > 0 then
			ranks[id] = r
		end
		return r
	end
	local function n(id, passive, value)
		if value and value ~= 0 then
			ranks[node(id, passive, value)] = 1
		end
	end
	local p = E.player("Cleric", L, {}, nil, gear)
	local bp = BP[variant]
	local pts = math.floor(L / 2)
	def({ id = "k_holyStrike", from = "holyStrike", unlock = 1, values = { dmg = P.hs }, breakpoints = bp.hs })
	def({ id = "k_radiance", from = "radiance", unlock = 6, values = { dmg = P.rad }, breakpoints = bp.rad })
	def({ id = "k_devotion", from = "devotion", unlock = 10, maxLevel = 5 })
	def({ id = "k_divineWrath", from = "divineWrath", unlock = 30, maxLevel = 5, values = { bonus = P.wrath or { 4, 20 } } })
	def({ id = "k_judgement", from = "judgement", unlock = 45, values = { dmg = P.jud }, breakpoints = bp.jud })
	local rh = give("k_heal", 3)
	def({ id = "k_heal", from = "heal", unlock = 3, values = { heal = healEquiv(p, scaled({ 16, 18 }, rh), scaled({ 8, 12 }, rh)) } })
	local rc = give("k_circle", 14)
	def({ id = "k_circle", from = "circleOfLight", unlock = 14, values = { heal = healEquiv(p, scaled({ 8, 12 }, rc), scaled({ 6, 10 }, rc)) } })
	give("k_holyStrike", 1)
	give("k_radiance", 6)
	give("k_devotion", 10, 5)
	give("k_divineWrath", 30, 5)
	give("k_judgement", 45)
	E.HEALS.k_heal = true
	E.HEALS.k_circle = true
	E.HEALS.k_purify = true
	E.HEALS.k_renew = true
	E.HEALS.k_sanct = true
	-- base-wide extra (row 1-2 damage nodes every Cleric can buy) handled per variant below
	local function inkRow1(full)
		local rp = give("k_purify", 10)
		def({ id = "k_purify", from = "purify", unlock = 10, values = { heal = healEquiv(p, scaled({ 8, 12 }, rp), scaled({ 6, 10 }, rp)) } })
		n("i_zeal", { pct = { magAtk = "v" } }, P.zeal)
	end
	local function holyStrikeBonus(pp)
		local hs = byId.k_holyStrike
		hs.values = { dmg = addPair(P.hs, pp) }
	end
	if variant == "ink" then
		local I = P.ink
		def({
			id = "k_brand", unlock = 26, type = "target", holy = true, range = 12, cost = 30, cooldown = I.brandCd,
			values = { dmg = I.brandDmg, dot = I.brandDot },
			effects = { { kind = "poison", duration = 6, value = "dot" } }, breakpoints = bp.brand,
		})
		def({
			id = "k_hammer", unlock = 60, type = "circleTarget", target = "point", holy = true, radius = 8, delay = 0.5,
			cost = 70, cooldown = I.hammerCd, values = { dmg = I.hammerDmg },
			effects = { { kind = "stun", duration = 1.2 } }, breakpoints = bp.hammer,
		})
		local holy = 0
		local list = {
			{ 4, function() inkRow1() end },
			{ 7, function() holy += I.faith end },
			{ 10, function() holyStrikeBonus(I.hand) end },
			{ 13, function()
				if gear and gear.offhand == "shield" then
					n("i_shieldNode", { pct = { maxHp = "v", armor = "v2" } }, 6)
					byId.i_shieldNode.values.v2 = 18
				else
					holy += I.relic
				end
			end },
			{ 14, function() give("k_brand", 26) end },
			{ 17, function() n("i_ember", { flat = { critChance = "v" } }, I.ember) end },
			{ 20, function() byId.k_judgement.nodeBp = { splash = { radius = 6, pct = 50 } } end },
			{ 23, function() n("i_grit", { pct = { maxHp = "v" } }, 6) end },
			{ 31, function() give("k_hammer", 60) end },
			{ 34, function() byId.k_judgement.cooldown = 15 * I.judgeCdMul end },
			{ 40, function() local b = byId.k_brand; b.values = { dmg = b.values.dmg, dot = addPair(I.brandDot, I.truth) } end },
			{ 42, function() byId.k_hammer.cooldown = I.hammerCd * 0.7 end },
		}
		for _, e in list do
			if pts >= e[1] then
				e[2]()
			end
		end
		if holy > 0 then
			n("i_holy", { hooks = { holyDamage = "v" } }, holy)
		end
		if L >= 100 then
			local rr = give("k_renew", 10)
			def({ id = "k_renew", from = "renew", unlock = 10, values = { heal = healEquiv(p, scaled({ 16, 24 }, rr), scaled({ 10, 15 }, rr)) } })
		end
	elseif variant == "uzd" or variant == "base" then
		if variant == "uzd" then
			local rr = give("k_renew", 10)
			def({ id = "k_renew", from = "renew", unlock = 10, values = { heal = healEquiv(p, scaled({ 16, 24 }, rr), scaled({ 10, 15 }, rr)) } })
			local rs = give("k_sanct", 26)
			def({ id = "k_sanct", from = "renew", unlock = 26, type = "hot", cost = 45, cooldown = 18, duration = 6, values = { heal = healEquiv(p, 6 * scaled({ 2, 3.2 }, rs), 6 * scaled({ 2, 3 }, rs)) } })
			if pts >= 7 then n("u_hands", { hooks = { healBonus = "v" } }, 9) end
			-- off-path (reference build): rows 1 of Fortuna and Inkwizytor once the main path allows it
			if pts >= (if early then 31 else 44) then inkRow1() end
		end
	elseif variant == "fort" then
		def({ id = "k_resurrection", from = "resurrection", unlock = 10 })
		E.SKIP.k_resurrection = true
		give("k_resurrection", 10)
		local rd = give("k_dice", 26)
		def({
			id = "k_dice", unlock = 26, type = "buff", target = "self", cost = 40, cooldown = (if pts >= 25 then 18 else 24), duration = 15,
			values = { crit = scaled({ 4, 8 }, rd) / 3, haste = scaled({ 6, 12 }, rd) / 3 },
			effects = {
				{ kind = "statBuff", duration = 15, stats = { critChance = "crit" } },
				{ kind = "statBuff", duration = 15, stats = { atkSpeed = "haste" }, pct = true },
			},
		})
		E.BUFFS.k_dice = true
		local rw = give("k_wheel", 60)
		local boost = 1 + 0.5 / 3
		def({
			id = "k_wheel", unlock = 60, type = "buff", target = "self", cost = 80,
			cooldown = (if pts >= 50 then 70 else 90), duration = (if pts >= 50 then 16 else 12),
			values = { crit = scaled({ 6, 10 }, rw) * boost, haste = scaled({ 8, 15 }, rw) * boost },
			effects = {
				{ kind = "statBuff", duration = (if pts >= 50 then 16 else 12), stats = { critChance = "crit" } },
				{ kind = "statBuff", duration = (if pts >= 50 then 16 else 12), stats = { atkSpeed = "haste" }, pct = true },
			},
		})
		E.BUFFS.k_wheel = true
		if pts >= 10 then n("f_smile", { flat = { critChance = "v" } }, 3) end
		-- off-path (reference build): row 1 of Inkwizytor (+ row 2 Ciężka Ręka) once the main path allows it
		if pts >= (if early then 31 else 46) then inkRow1() end
		if pts >= 49 then holyStrikeBonus(P.ink.hand) end
	end
	return ranks
end

local ORDER = { 1, 2, 3, 2, 1, 4, 3, 1, 2, 3, 1, 2, 4, 2, 1, 3, 1, 2, 3, 4 }
local function grind(classId, L, ranks, healAt, topoff, gear)
	local p0 = E.player(classId, L, ranks, nil, gear)
	local regen = p0.values.manaRegen
	local frac, cds = 1, {}
	local total, members = 0, 0
	for _, n in ORDER do
		local f = E.fight({ classId = classId, L = L, ranks = ranks, targets = FightSim.group(B.GENERIC, L, n), seconds = 300, monstersHit = true, healAt = healAt, startPool = frac, cds = cds, gearOpts = gear })
		local rest = f.endLost / (Stats.Formula.hpRegenPct / 100)
		local poolEnd = f.poolEnd
		if topoff and f.endLost > 0.02 then
			local casts = math.ceil(f.endLost / topoff)
			rest = 1 + (casts - 1) * 3
			poolEnd = math.max(0, poolEnd - casts * 20)
		end
		local gap = rest + AreaRates.BREAK + AreaRates.WALK
		frac = math.min(1, (poolEnd + regen * gap) / f.poolMax)
		cds = {}
		for id, left in f.cds do
			cds[id] = math.max(0, left - gap)
		end
		total += f.seconds + gap
		members += n
	end
	return total / members
end
local function single(classId, L, ranks, gear)
	local m = B.monster(B.GENERIC, L)
	return E.fight({ classId = classId, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, gearOpts = gear })
end
local function aoe3(classId, L, ranks, gear, seconds)
	local m = B.monster(B.GENERIC, L)
	return E.fight({ classId = classId, L = L, ranks = ranks, targets = { m, m, m }, dummy = true, seconds = seconds or 8, gearOpts = gear }).dps
end
local function eHP(classId, L, ranks, gear)
	local p = E.player(classId, L, ranks, nil, gear)
	return p.values.maxHp / (1 - Damage.reduction(p.values.armor, L)), p.values.maxHp, p.values.magAtk
end

---------------------------------------------------------------------------------------------------------------
-- Parameter sets
---------------------------------------------------------------------------------------------------------------
local OLD = {
	hs = { 150, 280 }, rad = { 110, 200 }, jud = { 280, 500 }, zeal = 5,
	ink = { faith = 6, hand = 20, relic = 6, ember = 3, brandDmg = { 50, 90 }, brandDot = { 80, 140 }, brandCd = 12,
		hammerDmg = { 220, 360 }, hammerCd = 30, judgeCdMul = 0.8, truth = 20 },
	inkPlan = { int = 3, vit = 2 },
}
local PRESETS = { old = OLD }
local extra = process.env.KP_FILE
if extra and extra ~= "" then
	local f = require(extra)
	for k, v in f do
		PRESETS[k] = v
	end
end
local P = PRESETS[process.env.KP or "old"]
assert(P, "unknown preset")

local VARIANTS = {
	{ "Baza (buława+tarcza)", "base", { int = 1, vit = 1 }, GEAR.base },
	{ "Inkwizytor (buława+relikwia)", "ink", P.inkPlan, GEAR.ink },
	{ "Inkwizytor (buława+tarcza)", "ink", P.inkPlan, GEAR.inkShield },
	{ "Uzdrowiciel (berło+tarcza)", "uzd", { int = 1, vit = 1 }, GEAR.uzd },
	{ "Uzdrowiciel (kostur)", "uzd", { int = 1, vit = 1 }, GEAR.uzdStaff },
	{ "Fortuna (buława+relikwia)", "fort", { int = 1, vit = 1 }, GEAR.fort },
	{ "Uzdr. berło, rząd 1 Ink. od 62.", "uzd", { int = 1, vit = 1 }, GEAR.uzd, true },
	{ "Fortuna, rząd 1 Ink. od 62.", "fort", { int = 1, vit = 1 }, GEAR.fort, true },
}
if (process.env.KPL or "") ~= "" then
	VARIANTS = {
		{ "Inkwizytor (buława+relikwia)", "ink", P.inkPlan, GEAR.ink },
		{ "Ink. INT 1 : VIT 1", "ink", { int = 1, vit = 1 }, GEAR.ink },
		{ "Ink. INT 2 : VIT 1", "ink", { int = 2, vit = 1 }, GEAR.ink },
		{ "Ink. sama INT", "ink", { int = 1 }, GEAR.ink },
	}
end

local quick = (process.env.KQ or "") ~= ""
print("preset " .. (process.env.KP or "old"))
print("build | L | 1 cel 60 s (xBers) | 3 cele 8 s (xBers) | 3 cele 60 s (xBers) | eHP (xBers) | maxHp magAtk | expienie s/zabicie: dobijanie / odpoczynek")
for _, L in LEVELS do
	local br, bg = berserker(L)
	local bS = single("Warrior", L, br, bg).dps
	local bA = aoe3("Warrior", L, br, bg)
	local bA60 = aoe3("Warrior", L, br, bg, 60)
	local bE = eHP("Warrior", L, br, bg)
	print(fmt("Berserker | %d | %.0f | %.0f | %.0f | %.0f", L, bS, bA, bA60, bE))
	local inkG
	for _, v in VARIANTS do
		PLAN = v[3]
		local ranks = cleric(v[2], L, P, v[4], v[5])
		local s = single("Cleric", L, ranks, v[4]).dps
		local a = aoe3("Cleric", L, ranks, v[4])
		local a60 = aoe3("Cleric", L, ranks, v[4], 60)
		local e, hp, mag = eHP("Cleric", L, ranks, v[4])
		local gT, gR = 0, 0
		if not quick then
			gT = grind("Cleric", L, ranks, 0.4, 0.2, v[4])
			gR = grind("Cleric", L, ranks, 0.4, nil, v[4])
		end
		if v[1] == "Inkwizytor (buława+relikwia)" then
			inkG = { gT, gR }
		end
		local rel = if inkG and not quick then fmt(" (x%.2f / x%.2f)", gT / inkG[1], gR / inkG[2]) else ""
		if (process.env.KC or "") ~= "" then
			local pp = E.player("Cleric", L, ranks, nil, v[4])
			print(fmt("    crit %.1f%% critDmg %.0f", pp.values.critChance, pp.values.critDmg))
		end
		print(fmt("  %-28s | %d | %.0f (%.2f) | %.0f (%.2f) | %.0f (%.2f) | %.0f (%.2f) | %d %d | %.1f / %.1f%s", v[1], L, s, s / bS, a, a / bA, a60, a60 / bA60, e, e / bE, hp, mag, gT, gR, rel))
		PLAN = nil
	end
end
