-- Rough check for the Mage paths design (rozwoj/mag.md 4). Not game code. Builds in diag_mag_lib.luau.
-- Averages over the three weapon elements (fire / ice / lightning). Skill damage normalised to weapon speed (global G).
-- Boss numbers (1 target, 180 s from a full pool): every build with its single-target breakpoints (base B);
-- A/N(boss) compares with the Niszczyciel boss build (Oszczędny Splot).
-- Area / exp numbers: exp breakpoints (base A; Arkanista without the Torrent).
-- Mana: demand = mana per second when every spell is cast on cooldown without a mana limit (1 target, 180 s);
-- "regen" = regeneration with nodes + passive returns (Reclaim); "+evo" adds Evocation used on every cooldown;
-- loss = DPS with the mana limit / without it over 180 s from a full pool.
-- Usage: lune run tools/diag_mag.luau            (all levels)
local E = require("./SkillEngineMag")
local B = require("../tests/Balance")
local FightSim = require("../src/shared/Logic/FightSim")
local AreaRates = require("../src/shared/Logic/AreaRates")
local Stats = require("../src/shared/Data/Stats")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local M = require("./diag_mag_lib")
local fmt = string.format
local costMul = M.costMul

local LEVELS = (_G :: any).LEVELS or { 20, 26, 45, 70, 100 }
local HPX = { [20] = 2, [26] = 2.4, [45] = 3, [70] = 4, [100] = 5 }
local ORDER = { 1, 2, 3, 2, 1, 4, 3, 1, 2, 3, 1, 2, 4, 2, 1, 3, 1, 2, 3, 4 }
local EL = { "fire", "ice", "lightning" }

local BASE_B = { firebolt = "bb", fireball = "ab", iceShard = "bb", chainLightning = "bb", frostNova = "ab", firewall = "bb", meteor = "ba" }
local N_BOSS = table.clone(BASE_B)
N_BOSS.meteorStorm, N_BOSS.elementalVortex, N_BOSS.cataclysm = "bb", "ba", "bb"
local A_GRIND = { firebolt = "aa", fireball = "aa", iceShard = "ab", chainLightning = "aa", frostNova = "aa", firewall = "ab", meteor = "aa", arcaneDischarge = "ab", arcaneTorrent = "ab" }

-- name, node order, main path, boss choices, exp choices, gear
local SPECS = {
	{ "Baza (kostur)", M.ORDER_BASE, "none", BASE_B, M.CHOICE_D, M.STAFF },
	{ "Niszczyciel (kostur)", M.ORDER_D, "d", N_BOSS, M.CHOICE_D, M.STAFF },
	{ "Niszczyciel, Płaszcz", M.ORDER_D_MANTLE, "d", N_BOSS, M.CHOICE_D, M.STAFF },
	{ "Niszczyciel, Oszczędny Splot", M.ORDER_D_THRIFT, "d", N_BOSS, M.CHOICE_D, M.STAFF },
	{ "Niszczyciel (różdżka+kula)", M.ORDER_D, "d", N_BOSS, M.CHOICE_D, M.WANDORB },
	{ "Arkanista (k. runiczny)", M.ORDER_A, "a", M.CHOICE_A, A_GRIND, M.RUNE },
	{ "Arkanista, Przeciążenie", M.ORDER_A_OVER, "a", M.CHOICE_A, A_GRIND, M.RUNE },
	{ "Arkanista, Chłodna Głowa", M.ORDER_A_COOL, "a", M.CHOICE_A, A_GRIND, M.RUNE },
	{ "Arkanista, Studnia Many", M.ORDER_A_WELL, "a", M.CHOICE_A, A_GRIND, M.RUNE },
	{ "Arkanista (różdżka+księga)", M.ORDER_A, "a", M.CHOICE_A, A_GRIND, M.WANDTOME },
}

local function scaled(list, x)
	local out = {}
	for _, m in list do
		local c = table.clone(m)
		c.maxHp *= x
		table.insert(out, c)
	end
	return out
end

local function grind(ranks, mage, gear, L, element)
	local p0 = E.player("Mage", L, ranks, nil, gear)
	local regen = p0.values.manaRegen
	local frac, cds = 1, {}
	local total, members = 0, 0
	for _, n in ORDER do
		local f = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = scaled(FightSim.group(B.GENERIC, L, n), HPX[L]), seconds = 300, monstersHit = true, weaponElement = element, startPool = frac, cds = cds, gearOpts = gear, costMul = costMul(L), mage = mage })
		local rest = f.endLost / (Stats.Formula.hpRegenPct / 100)
		local gap = rest + AreaRates.BREAK + AreaRates.WALK
		local gain = (mage.killMana or 0) / 100 * f.poolMax * n
		frac = math.min(1, (f.poolEnd + gain + regen * gap) / f.poolMax)
		cds = {}
		for id, left in f.cds do
			cds[id] = math.max(0, left - gap)
		end
		total += f.seconds + gap
		members += n
	end
	-- fresh fights (full pool, no cooldowns) against 2 / 3 / 4 monsters
	local groups = {}
	for _, n in { 2, 3, 4 } do
		local f = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = scaled(FightSim.group(B.GENERIC, L, n), HPX[L]), seconds = 300, monstersHit = true, weaponElement = element, gearOpts = gear, costMul = costMul(L), mage = mage })
		groups[n] = f.seconds
	end
	return total / members, groups
end

local function evocationIncome(ranks, poolMax)
	for id, rank in ranks do
		if string.sub(id, 1, 9) == "evocation" then
			local def = Skills.effective(SkillData.get(id), rank)
			return poolMax * Skills.valueAt(def, "mana", rank) / 100 / Skills.scaled(def, def.cooldown, rank)
		end
	end
	return 0
end

local function stripTorrent(ranks)
	for id in ranks do
		if string.find(id, "arcaneTorrent") then
			ranks[id] = nil
		end
	end
	return ranks
end

local function avg(t)
	return (t.fire + t.ice + t.lightning) / 3
end

for _, L in LEVELS do
	print(fmt("== L%d", L))
	local res = {}
	for _, sp in SPECS do
		local acc = { boss = {}, aoe = {}, burst1 = {}, burst3 = {}, spk = {}, g2 = {}, g3 = {}, g4 = {}, dr = {}, de = {}, loss = {}, sus = {} }
		for _, el in EL do
			local m = B.monster(B.GENERIC, L)
			local cm = costMul(L)
			local ranks, mage = M.buildWith(sp[2], sp[3], L, sp[4])
			local f = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 180, weaponElement = el, gearOpts = sp[6], costMul = cm, mage = mage })
			local fr = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 180, weaponElement = el, gearOpts = sp[6], costMul = cm, mage = mage, freeMana = true })
			local gr, gm = M.buildWith(sp[2], sp[3], L, sp[5])
			if sp[3] == "a" then
				gr = stripTorrent(gr)
			end
			local aoe = E.fight({ classId = "Mage", L = L, ranks = gr, targets = { m, m, m }, dummy = true, seconds = 60, weaponElement = el, gearOpts = sp[6], costMul = cm, mage = gm })
			local b1 = E.fight({ classId = "Mage", L = L, ranks = gr, targets = { m }, dummy = true, seconds = 8, weaponElement = el, gearOpts = sp[6], costMul = cm, mage = gm })
			local b3 = E.fight({ classId = "Mage", L = L, ranks = gr, targets = { m, m, m }, dummy = true, seconds = 8, weaponElement = el, gearOpts = sp[6], costMul = cm, mage = gm })
			local spk, groups = grind(gr, gm, sp[6], L, el)
			local d = fr.spent / 180
			acc.boss[el] = f.dps
			acc.aoe[el] = aoe.dps
			acc.burst1[el] = b1.dps
			acc.burst3[el] = b3.dps
			acc.spk[el] = spk
			acc.g2[el], acc.g3[el], acc.g4[el] = groups[2], groups[3], groups[4]
			acc.dr[el] = d / (fr.regen + fr.gain)
			acc.de[el] = d / (fr.regen + fr.gain + evocationIncome(ranks, fr.poolMax))
			acc.loss[el] = f.dps / fr.dps
		end
		res[sp[1]] = acc
	end
	local base = res["Baza (kostur)"]
	for _, sp in SPECS do
		local a = res[sp[1]]
		print(fmt(
			"%-30s | boss %6.0f x%.2f | 3 cele 60 s x%.2f, 8 s x%.2f | obszar/1 cel 8 s %.2f | exp %.1f s/potwór, walka 2/3/4: %.1f/%.1f/%.1f s | mana %.2f (+evo %.2f), strata %.2f",
			sp[1], avg(a.boss), avg(a.boss) / avg(base.boss), avg(a.aoe) / avg(base.aoe), avg(a.burst3) / avg(base.burst3), avg(a.burst3) / avg(a.burst1),
			avg(a.spk), avg(a.g2), avg(a.g3), avg(a.g4), avg(a.dr), avg(a.de), avg(a.loss)
		))
	end
	local function r(x, y)
		return avg(res[x].boss) / avg(res[y].boss)
	end
	print(fmt("A/N(boss) %.2f, Przeciążenie/N(boss) %.2f | A/N boss: %.2f, Przeciążenie/N %.2f, różdżki %.2f; N/A 3 cele 60 s (exp) %.2f; N/A exp czas %.2f",
		r("Arkanista (k. runiczny)", "Niszczyciel, Oszczędny Splot"), r("Arkanista, Przeciążenie", "Niszczyciel, Oszczędny Splot"),
		r("Arkanista (k. runiczny)", "Niszczyciel (kostur)"), r("Arkanista, Przeciążenie", "Niszczyciel (kostur)"),
		r("Arkanista (różdżka+księga)", "Niszczyciel (różdżka+kula)"),
		avg(res["Niszczyciel (kostur)"].aoe) / avg(res["Arkanista (k. runiczny)"].aoe),
		avg(res["Niszczyciel (kostur)"].spk) / avg(res["Arkanista (k. runiczny)"].spk)))
	local n, a = res["Niszczyciel (kostur)"], res["Arkanista (k. runiczny)"]
	print(fmt("żywioły (ogień / lód / błyskawica): Baza boss %.0f/%.0f/%.0f, 3 cele %.0f/%.0f/%.0f | N boss %.0f/%.0f/%.0f, 3 cele %.0f/%.0f/%.0f | A boss %.0f/%.0f/%.0f, 3 cele %.0f/%.0f/%.0f",
		base.boss.fire, base.boss.ice, base.boss.lightning, base.aoe.fire, base.aoe.ice, base.aoe.lightning,
		n.boss.fire, n.boss.ice, n.boss.lightning, n.aoe.fire, n.aoe.ice, n.aoe.lightning,
		a.boss.fire, a.boss.ice, a.boss.lightning, a.aoe.fire, a.aoe.ice, a.aoe.lightning))
	print("")
end
