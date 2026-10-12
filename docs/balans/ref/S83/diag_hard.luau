--!strict
-- Diagnostics of the hard content of regions 2-4 (Elites, Elite II, bosses, boss loot), levels 20-100.
-- Uses the S32 model (tests/Balance.luau, Logic/FightSim) with the game's own data. Extensions over Balance:
--   * real cave spawners (Data/Spawns) instead of the GENERIC kind and the Meadows list;
--   * Elite pairs (AreaSpawns.cave makes 50 % of elite groups 2 members; FightSim.group with groupSize 2);
--   * Elite II party of 4 and the worst ability hit on a Mage;
--   * bosses: per-attack damage kind (Balance.boss uses the boss's kind for every attack), the real attack cadence
--     (Boss.Step: priority list, nextGlobal = windup + 2.2 s), enrage and phase haste;
--   * boss loot: exact pity Markov chain from Loot.bossChances.
-- Prints markdown. `lune run tools/diag_hard.luau [section]`.

local process = require("@lune/process")

local B = require("../tests/Balance")
local Areas = require("../src/shared/Data/Areas")
local Bosses = require("../src/shared/Data/Bosses")
local BossScaling = require("../src/shared/Logic/BossScaling")
local Combat = require("../src/shared/Data/Combat")
local Config = require("../src/shared/Config")
local Exp = require("../src/shared/Logic/Exp")
local FightSim = require("../src/shared/Logic/FightSim")
local Items = require("../src/shared/Data/Items")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Loot = require("../src/shared/Logic/Loot")
local LootTables = require("../src/shared/Data/LootTables")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local Monsters = require("../src/shared/Data/Monsters")
local Rarities = require("../src/shared/Data/Rarities")
local Spawns = require("../src/shared/Data/Spawns")
local Stats = require("../src/shared/Data/Stats")

local only = process.args[1]

local function pct(v: number): string
	if v ~= v then
		return "–"
	end
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end
local function f1(v: number): string
	return string.format("%.1f", v)
end
local function f2(v: number): string
	return string.format("%.2f", v)
end
local function int(v: number): string
	return tostring(math.floor(v + 0.5))
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

local REGION_CAVES = { "meadows_cave", "duskwood_den", "duskwood_barrow", "duskwood_cave", "ashen_mine", "ashen_lair", "ashen_cave", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" }

local function spawnersOf(caveId: string, variant: string): { any }
	local out = {}
	for _, s in Spawns.byMap[caveId] do
		if s.variant == variant then
			table.insert(out, s)
		end
	end
	return out
end

-- Distinct (kind, level range, max members) of a cave's elite spawners.
local function eliteKinds(caveId: string): { { kind: string, min: number, max: number, pairShare: number } }
	local byKind: { [string]: any } = {}
	local order = {}
	for _, s in spawnersOf(caveId, "elite") do
		local e = byKind[s.monster]
		if not e then
			e = { kind = s.monster, min = s.level.min, max = s.level.max, groups = 0, pairs = 0 }
			byKind[s.monster] = e
			table.insert(order, s.monster)
		end
		e.groups += 1
		e.pairs += if s.count >= 2 then 1 else 0
	end
	local out = {}
	for _, id in order do
		local e = byKind[id]
		table.insert(out, { kind = e.kind, min = e.min, max = e.max, pairShare = e.pairs / e.groups })
	end
	return out
end

local function clampLevel(l: number): number
	return math.clamp(l, 1, 100)
end

-------------------------------------------------------------------------------------------------------------
-- 1. Elites solo (real kinds, spawner level = player level), single and pair
-------------------------------------------------------------------------------------------------------------
if not only or only == "elite" then
	print("## Elites solo, real cave kinds (player level = spawner level, capped at 100)")
	print("")
	print("Single Elite: B.elite(p, kind, L). Pair: FightSim.groupFight(p, FightSim.group(kind, L, 2, \"elite\")) (each x0.85 damage).")
	print("")
	header({ "cave · kind · spawner L", "pairs", "W s", "W HP", "H s", "H HP", "M s", "M HP", "C s", "C HP", "W pair HP", "H pair HP", "M pair HP", "C pair HP" })
	for _, caveId in REGION_CAVES do
		for _, e in eliteKinds(caveId) do
			for _, L in { e.min, e.max } do
				local def = Monsters.get(e.kind) :: any
				local cells = { `{caveId} · {e.kind} · {L}`, pct(e.pairShare) }
				local pairCells = {}
				for _, c in B.CLASSES do
					local p = B.player(c, clampLevel(L))
					local f = B.elite(p, def, L)
					table.insert(cells, f1(f.seconds))
					table.insert(cells, pct(f.hpLost))
					local pairFight = FightSim.groupFight(p :: any, FightSim.group(def, L, 2, "elite"), B.SKILL_DPS)
					table.insert(pairCells, pct(pairFight.hpLost))
				end
				for _, v in pairCells do
					table.insert(cells, v)
				end
				row(cells)
			end
		end
	end
	print("")

	print("## Elite solo, GENERIC kind (the S32 global formula) at levels 20-100")
	print("")
	header({ "level", "W s", "W HP", "H s", "H HP", "M s", "M HP", "C s", "C HP" })
	for _, L in { 20, 25, 30, 40, 45, 50, 60, 70, 80, 90, 100 } do
		local cells = { tostring(L) }
		for _, c in B.CLASSES do
			local f = B.elite(B.player(c, L), B.GENERIC, L)
			table.insert(cells, f1(f.seconds))
			table.insert(cells, pct(f.hpLost))
		end
		row(cells)
	end
	print("")
end

-------------------------------------------------------------------------------------------------------------
-- 2. Elite II with a party (W tank + M + H [+ C]), player level = min(100, spawner + 2)
-------------------------------------------------------------------------------------------------------------
local function e2Fight(team: { any }, kind: string, L: number)
	return B.elite2(team, kind, L)
end

if not only or only == "elite2" then
	print("## Elite II, real cave kinds (party Warrior tank + Mage + Hunter + Cleric, level min(100, spawner + 2))")
	print("")
	print("Target (S32): solo > 150 % HP of the tank, 2 players <= 150 %, 3 players <= 100 %. Half of the special attacks hit.")
	print("")
	header({ "cave · kind · spawner L", "players L", "solo s", "solo HP", "2 s", "2 HP", "3 s", "3 HP", "4 s", "4 HP", "ability on Mage", "basic on Mage", "S32 ok" })
	for _, caveId in REGION_CAVES do
		local s = spawnersOf(caveId, "elite2")[1]
		for _, kind in s.choices or { s.monster } do
			for _, L in { s.level.min, s.level.max } do
				local pl = math.min(100, L + 2)
				local w, m, h, c = B.player("Warrior", pl), B.player("Mage", pl), B.player("Hunter", pl), B.player("Cleric", pl)
				local solo = e2Fight({ w }, kind, L)
				local duo = e2Fight({ w, m }, kind, L)
				local trio = e2Fight({ w, m, h }, kind, L)
				local four = e2Fight({ w, m, h, c }, kind, L)
				local def = Monsters.get(kind) :: any
				local mon = B.monster(def, L, "elite2")
				local ability = MonsterAbilities.get(def.ability) :: any
				local abilityHit = B.hit(mon, m, ability.damage, ability.damageKind, false) * Combat.randomMax / m.values.maxHp
				local basic = B.hit(mon, m) * Combat.randomMax / m.values.maxHp
				local ok = solo.hpLost > 1.5 and duo.hpLost <= 1.5 and trio.hpLost <= 1.0
				row({
					`{caveId} · {kind} · {L}`,
					tostring(pl),
					f1(solo.seconds),
					pct(solo.hpLost),
					f1(duo.seconds),
					pct(duo.hpLost),
					f1(trio.seconds),
					pct(trio.hpLost),
					f1(four.seconds),
					pct(four.hpLost),
					pct(abilityHit),
					pct(basic),
					if ok then "yes" else "NO",
				})
			end
		end
	end
	print("")
end

-------------------------------------------------------------------------------------------------------------
-- 3. Bosses
-------------------------------------------------------------------------------------------------------------

-- Boss kind and stats for a party of `n` (same as Entities/Boss kindFor + MonsterStats "boss").
local function bossStats(def: any, n: number): any
	local kind = {
		hpMul = BossScaling.hpMultiplier(n) * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		speed = def.speed,
		attack = def.attack,
		damageKind = def.damageKind,
	}
	return B.monster(kind, def.level, "boss")
end

-- Uses per minute of every attack in phase `phase` (Entities/Boss.Step: list order is priority, after a cast the
-- next attack waits windup + GLOBAL_GAP 2.2 s; first use 3-7 s after the start, mean 5 s).
local GLOBAL_GAP = 2.2
local function cadence(def: any, phase: number): { [string]: number }
	local next: { [string]: number } = {}
	local counts: { [string]: number } = {}
	for _, a in def.attacks do
		next[a.id] = 5
		counts[a.id] = 0
	end
	local global = 4
	local T = 1200
	local t = 0
	while t < T do
		if t >= global then
			for _, a in def.attacks do
				if table.find(a.phases, phase) and t >= next[a.id] then
					next[a.id] = t + a.cooldown
					global = t + a.windup + GLOBAL_GAP
					counts[a.id] += 1
					break
				end
			end
		end
		t += 0.05
	end
	local out = {}
	for id, n in counts do
		out[id] = n / (T / 60)
	end
	return out
end

-- Expected (crit-averaged) hit of an attack with multiplier `mul` and kind on a player, x randomMax as in S32.
local function topHit(m: any, p: any, mul: number, kind: string?): number
	return FightSim.hit(m, p, mul, kind, false) * Combat.randomMax
end

local ORDER = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }

local function team(n: number, level: number): { any }
	local out = {}
	for i = 1, n do
		table.insert(out, B.player(ORDER[i], level))
	end
	return out
end

if not only or only == "boss" then
	print("## Boss multipliers (Data/Bosses)")
	print("")
	header({ "boss", "level", "hpMul", "atkMul", "defMul", "speed", "attack", "damageKind", "attacks (x attack, cooldown, target, kind)", "haste", "enrage" })
	for _, def in Bosses.list do
		local d = def :: any
		local list = {}
		for _, a in d.attacks do
			table.insert(list, `{a.id} x{a.damage} /{a.cooldown}s {a.target}{if a.count then "x" .. a.count else ""} {a.damageKind or d.damageKind} ph{table.concat(a.phases, "")}`)
		end
		local haste = if d.haste then `ph3 x{d.haste[3]}` else "–"
		row({ d.id, tostring(d.level), tostring(d.hpMul or 1), tostring(d.atkMul), tostring(d.defMul), tostring(d.speed), d.attack, d.damageKind, table.concat(list, "; "), haste, `{d.enrageAfter}s x{d.enrageDamage}` })
	end
	print("")

	print("## Boss fight length (75 % uptime, players of level L-1 like Grimrok's 19, and at L)")
	print("")
	header({ "boss · players", "boss HP", "min (L-1)", "min (L)", "min (L-5 entry)", "S32 4-6 min (L-1)" })
	for _, def in Bosses.list do
		local d = def :: any
		for n = 1, 5 do
			local r1 = B.boss(d.id, team(n, d.level - 1))
			local r0 = B.boss(d.id, team(n, math.min(100, d.level)))
			local r5 = B.boss(d.id, team(n, d.level - 5))
			local ok = if n >= 3 then (if r1.seconds / 60 >= 4 and r1.seconds / 60 <= 6 then "yes" else "NO") else ""
			row({ `{d.id} · {n}`, int(r0.hp), f1(r1.seconds / 60), f1(r0.seconds / 60), f1(r5.seconds / 60), ok })
		end
	end
	print("")

	print("## Boss hits on a Mage (biggest telegraphed attack, its own damage kind, x1.08 random max, crit averaged)")
	print("")
	print("`B.boss share` = what tests/Balance.boss reports (biggest multiplier with the boss's damage kind). Target: <= 70 % of a Mage's HP at the boss level; a Mage at L-2 survives (< 100 %).")
	print("")
	header({ "boss", "Mage L", "Mage HP", "biggest attack", "share", "B.boss share", "share at L-2", "basic hit", "crit worst (x1.5)", "S32 ok" })
	for _, def in Bosses.list do
		local d = def :: any
		local L = math.min(100, d.level)
		local mage = B.player("Mage", L)
		local mage2 = B.player("Mage", L - 2)
		local m = bossStats(d, 1)
		local best, bestId, best2 = 0, "", 0
		for _, a in d.attacks do
			local v = topHit(m, mage, a.damage, a.damageKind or d.damageKind) / mage.values.maxHp
			if v > best then
				best, bestId = v, a.id
			end
			best2 = math.max(best2, topHit(m, mage2, a.damage, a.damageKind or d.damageKind) / mage2.values.maxHp)
		end
		local bshare = B.boss(d.id, { mage }).biggest[1].share
		local basic = topHit(m, mage, 1, d.damageKind) / mage.values.maxHp
		-- worst case: random max and a guaranteed crit (no expected crit factor)
		local crit = 1 + Combat.monsterCritChance / 100 * (Combat.monsterCritDmg / 100 - 1)
		local worst = best / crit * (Combat.monsterCritDmg / 100)
		row({ d.id, tostring(L), int(mage.values.maxHp), bestId, pct(best), pct(bshare), pct(best2), pct(basic), pct(worst), if best <= 0.7 and best2 < 1 then "yes" else "NO" })
	end
	print("")

	print("## Every boss attack: hit on Mage / Warrior at the boss level (share of max HP)")
	print("")
	header({ "boss · attack", "x", "kind", "target", "Mage", "Warrior", "Cleric", "Hunter", "uses/min ph1", "uses/min ph2", "uses/min ph3" })
	for _, def in Bosses.list do
		local d = def :: any
		local L = math.min(100, d.level)
		local m = bossStats(d, 1)
		local ps = { B.player("Mage", L), B.player("Warrior", L), B.player("Cleric", L), B.player("Hunter", L) }
		local cad = { cadence(d, 1), cadence(d, 2), cadence(d, 3) }
		for _, a in d.attacks do
			local cells = { `{d.id} · {a.id}`, tostring(a.damage), a.damageKind or d.damageKind, a.target .. (if a.count then "x" .. a.count else "") }
			for _, p in ps do
				table.insert(cells, pct(topHit(m, p, a.damage, a.damageKind or d.damageKind) / p.values.maxHp))
			end
			for ph = 1, 3 do
				table.insert(cells, f1(cad[ph][a.id] or 0))
			end
			row(cells)
		end
		local cells = { `{d.id} · basic`, "1", d.damageKind, "threat" }
		for _, p in ps do
			table.insert(cells, pct(topHit(m, p, 1, d.damageKind) / p.values.maxHp))
		end
		local interval = m.attackInterval
		table.insert(cells, f1(60 / interval))
		table.insert(cells, f1(60 / interval))
		table.insert(cells, f1(60 / interval * ((d.haste or {})[3] or 1)))
		row(cells)
	end
	print("")

	print("## Tank (Warrior at boss level) HP lost per minute")
	print("")
	print("`S32 model` = Balance.boss (basic attacks + threat attacks every cooldown x 0.5). `cadence` = the same with the real attack rate of Boss.Step and per-attack damage kind, phase 1 / phase 3 (with haste) / phase 3 enraged (x1.6 after 600 s).")
	print("Also: Mage at boss level, damage per minute from attacks that can target him (all: every cast; random: count/players with 4 players; nearest/self/threat: 0), x0.5 dodge, phase 3.")
	print("")
	header({ "boss", "tank S32 model", "tank cadence ph1", "tank ph3", "tank ph3 enraged", "Mage ph3 (4 players)", "fight min (4 players, L)", "enrage at min" })
	for _, def in Bosses.list do
		local d = def :: any
		local L = math.min(100, d.level)
		local tank = B.player("Warrior", L)
		local mage = B.player("Mage", L)
		local m = bossStats(d, 4)
		local s32 = B.boss(d.id, { tank }).tankHpPerMinute
		local function tankPerMin(phase: number, enraged: boolean): number
			local cad = cadence(d, phase)
			local haste = if phase == 3 then ((d.haste or {})[3] or 1) else 1
			local mul = if enraged then d.enrageDamage else 1
			local perMin = FightSim.hit(m, tank, 1, d.damageKind) * 60 / m.attackInterval * haste * mul
			for _, a in d.attacks do
				if a.target == "threat" then
					perMin += FightSim.hit(m, tank, a.damage, a.damageKind or d.damageKind, false) * B.SPECIAL_HIT * (cad[a.id] or 0) * mul
				end
			end
			return perMin / tank.values.maxHp
		end
		local cad3 = cadence(d, 3)
		local magePerMin = 0
		for _, a in d.attacks do
			local share = if a.target == "all" then 1 elseif a.target == "random" then math.min(1, (a.count or 1) / 4) else 0
			magePerMin += FightSim.hit(m, mage, a.damage, a.damageKind or d.damageKind, false) * B.SPECIAL_HIT * share * (cad3[a.id] or 0)
		end
		local fight = B.boss(d.id, team(4, L)).seconds / 60
		row({ d.id, pct(s32), pct(tankPerMin(1, false)), pct(tankPerMin(3, false)), pct(tankPerMin(3, true)), pct(magePerMin / mage.values.maxHp), f1(fight), f1(d.enrageAfter / 60) })
	end
	print("")

	print("## Boss summons")
	print("")
	header({ "boss", "summon", "level", "count", "every s", "shield", "summon HP each", "summon hit on Mage (basic)" })
	for _, def in Bosses.list do
		local d = def :: any
		local mage = B.player("Mage", math.min(100, d.level))
		for _, s in d.summons do
			local sm = B.monster(s.monster, s.level, "normal")
			row({ d.id, s.monster, tostring(s.level), tostring(s.count), tostring(s.every or "–"), tostring(s.shield or false), int(sm.maxHp), pct(B.hit(sm, mage) / mage.values.maxHp) })
		end
	end
	print("")
end

-------------------------------------------------------------------------------------------------------------
-- 4. Boss loot: personal roll (exact pity chain), shared loot, per day
-------------------------------------------------------------------------------------------------------------

-- Expected kills between hits and the distribution of the kill number of the first hit (pity chain).
local function pityStats(bossId: string, which: string): (number, number, number)
	-- P(first hit on kill k)
	local survive = 1
	local expected = 0
	local p50, p90 = nil :: number?, nil :: number?
	local cumulative = 0
	for k = 1, 100 do
		local pity = if which == "legendary" then { leg = k - 1, myth = 0 } else { leg = 0, myth = k - 1 }
		local c = (Loot.bossChances(bossId, pity) :: any)[which]
		local hit = survive * c
		expected += k * hit
		cumulative += hit
		survive *= 1 - c
		if not p50 and cumulative >= 0.5 then
			p50 = k
		end
		if not p90 and cumulative >= 0.9 then
			p90 = k
		end
		if survive <= 0 then
			break
		end
	end
	return expected, p50 or 0, p90 or 0
end

if not only or only == "loot" then
	print("## Boss personal roll (LootTables.bosses, Loot.bossChances; Config.Boss.dailyRuns = " .. Config.Boss.dailyRuns .. ")")
	print("")
	header({ "boss", "leg base / step / hard", "myth base / step / hard", "kills per Legendary", "median / 90 %", "kills per Mythic", "median / 90 %", "Legendary / day", "Mythic / day", "days per Mythic", "days per named item for the class" })
	for _, def in Bosses.list do
		local t = (LootTables.bosses :: any)[def.id]
		local eL, mL, nL = pityStats(def.id, "legendary")
		local eM, mM, nM = pityStats(def.id, "mythic")
		local runs = Config.Boss.dailyRuns
		-- A named item usable by the class: mythicNamedShare, then usable named items (1 of 3 for most classes)
		local named = Config.BossLoot.mythicNamedShare
		row({
			def.id,
			`{t.legendaryChance} / {t.legendaryStep} / {t.legendaryHard}`,
			`{t.mythicChance} / {t.mythicStep} / {t.mythicHard}`,
			f2(eL),
			`{mL} / {nL}`,
			f2(eM),
			`{mM} / {nM}`,
			f2(runs / eL),
			f2(runs / eM),
			f1(eM / runs),
			f1(eM / runs / named),
		})
	end
	print("")

	print("## Boss shared loot and materials per kill")
	print("")
	header({ "boss", "items (3 players)", "items (5 players)", "ilvl", "Unique / Heroic weights", "legend_core per kill", "gold per kill" })
	for _, def in Bosses.list do
		local t = (LootTables.bosses :: any)[def.id]
		local core = 0
		for _, mat in t.materials do
			if mat.id == "legend_core" then
				core = mat.chance * (mat.min + mat.max) / 2
			end
		end
		local drops = Rarities.itemDrops.boss
		local low, high = ItemRoll.dropLevelRange(t.level)
		row({
			def.id,
			f1((drops.min + drops.max) / 2),
			f1((drops.min + drops.max) / 2 + BossScaling.extraItems(5)),
			`{low}-{high}`,
			`{Rarities.dropWeights.boss[2]} / {Rarities.dropWeights.boss[3]}`,
			f2(core),
			int(MonsterStats.gold(t.level, "boss", 0.5)),
		})
	end
	print("")

	print("## Elite II items per kill (Rarities.itemDrops.elite2, dropWeights.elite2) and ilvl")
	print("")
	header({ "rarity", "items per kill (all)", "per kill usable by killer's class (B.itemsPerKill)" })
	local drops = Rarities.itemDrops.elite2
	local count = drops.chance * ((drops.min + drops.max) / 2 + (drops.extra or 0))
	local total = 0
	for _, w in Rarities.dropWeights.elite2 do
		total += w
	end
	for _, r in { Rarities.UNIQUE, Rarities.HEROIC, Rarities.LEGENDARY } do
		row({ Rarities.get(r).key, f2(count * (Rarities.dropWeights.elite2[r] or 0) / total), f2(B.itemsPerKill("elite2", r)) })
	end
	print("")
	header({ "cave", "Elite II spawner L", "monster L", "drop base (Loot.dropBaseLevel)", "ilvl range", "party level (spawner + 2)", "cave range", "kills/h (respawn 600-1200 s)", "Legendary/h per cave", "Legendary/h per member (3)" })
	for _, caveId in REGION_CAVES do
		local s = spawnersOf(caveId, "elite2")[1]
		local cave = Areas.caves.byId[caveId] :: any
		local lowB = Loot.dropBaseLevel(s.level.min + 4, "elite2", s.level.max)
		local highB = Loot.dropBaseLevel(s.level.max + 4, "elite2", s.level.max)
		local lowI = ItemRoll.dropLevelRange(lowB)
		local _, highI = ItemRoll.dropLevelRange(highB)
		local respawn = (s.respawn.min + s.respawn.max) / 2
		local killsPerHour = 3600 / respawn
		local legPerKill = count * Rarities.dropWeights.elite2[Rarities.LEGENDARY] / total
		row({
			caveId,
			`{s.level.min}-{s.level.max}`,
			`{s.level.min + 4}-{s.level.max + 4}`,
			`{lowB}-{highB}`,
			`{lowI}-{highI}`,
			`{math.min(100, s.level.min + 2)}-{math.min(100, s.level.max + 2)}`,
			`{cave.levels[1]}-{cave.levels[2]}`,
			f1(killsPerHour),
			f2(killsPerHour * legPerKill),
			f2(killsPerHour * legPerKill / 3),
		})
	end
	print("")

	print("## Elite drop ilvl clamp (Loot.dropBaseLevel with cap = spawner max)")
	print("")
	header({ "cave · kind", "spawner L", "monster L", "drop base", "ilvl range" })
	for _, caveId in REGION_CAVES do
		for _, e in eliteKinds(caveId) do
			local lowB = Loot.dropBaseLevel(e.min + 2, "elite", e.max)
			local highB = Loot.dropBaseLevel(e.max + 2, "elite", e.max)
			local lowI = ItemRoll.dropLevelRange(lowB)
			local _, highI = ItemRoll.dropLevelRange(highB)
			row({ `{caveId} · {e.kind}`, `{e.min}-{e.max}`, `{e.min + 2}-{e.max + 2}`, `{lowB}-{highB}`, `{lowI}-{highI}` })
		end
	end
	print("")
end

-------------------------------------------------------------------------------------------------------------
-- 5. Boss Mythic items vs a Legendary / rolled Mythic of the same base and level
-------------------------------------------------------------------------------------------------------------

local function makeItem(defId: string, ilvl: number, rarity: number, bonuses: { any }): any
	return { uid = "m", id = defId, rarity = rarity, ilvl = ilvl, bonuses = bonuses, up = 0, bound = false, n = 1, rv = Rarities.RV }
end

-- Expected bonuses of a rolled item (same as tests/Balance expectedBonuses).
local function expected(defId: string, ilvl: number, rarity: number, classId: string): { any }
	local rarityDef = Rarities.get(rarity)
	local out = {}
	local pool = ItemRoll.bonusPool(defId, classId)
	local n = (rarityDef.bonusMin + rarityDef.bonusMax) / 2
	if n > 0 and #pool > 0 then
		local share = math.min(1, n / #pool)
		for _, id in pool do
			table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
		end
	end
	local legendary = (require("../src/shared/Data/Bonuses") :: any).pools.legendary
	if rarityDef.legendaryLines > 0 then
		local share = rarityDef.legendaryLines / #legendary
		for _, id in legendary do
			table.insert(out, { stat = id, v = ItemRoll.rollBonusValue(id, ilvl, rarity, 0.5) * share })
		end
	end
	return out
end

local NAMED_CLASS: { [string]: string } = {
	unique_grimrok_cleaver = "Warrior",
	unique_grimrok_fang = "Hunter",
	unique_grimrok_totem = "Warrior",
	unique_morvane_shroud = "Mage",
	unique_morvane_scepter = "Cleric",
	unique_morvane_bow = "Hunter",
	unique_azgor_heart = "Warrior",
	unique_azgor_staff = "Mage",
	unique_azgor_helm = "Warrior",
	unique_vaelgrath_fang = "Warrior",
	unique_vaelgrath_scale = "Warrior",
	unique_vaelgrath_eye = "Mage",
}

if not only or only == "items" then
	print("## Boss Mythic (named) items vs a Legendary and a rolled Mythic of the same base at the boss level")
	print("")
	print("Full set of the class at ilvl = boss level (Common, expected bonuses) with the item's slot replaced. Power = sqrt(DPS x effective HP) vs GENERIC monster of that level (Balance.power). Hooks other than doubleAttack are not in power.")
	print("")
	header({ "item", "class", "slot · base", "L", "power vs Common set", "Legendary same base", "rolled Mythic same base", "named / Legendary", "weapon-only DPS named / Legendary" })
	for _, def in Bosses.list do
		local t = (LootTables.bosses :: any)[def.id]
		for _, id in t.named do
			local named = Items.get(id) :: any
			local classId = NAMED_CLASS[id]
			local L = t.level
			local base = named.type
			local tierDef = `{base}_{Items.generate.tierFor(L)}`
			local set = B.gear(classId, L, { ilvl = L })
			-- find the slot to replace: same slot as the named item (rings: the first ring)
			local function swapped(item: any): number
				local items = table.clone(set)
				local replaced = false
				for i, it in items do
					local d = Items.get(it.id) :: any
					if d.slot == named.slot and not replaced then
						items[i] = item
						replaced = true
					end
				end
				if not replaced then
					table.insert(items, item)
				end
				-- two-handed: drop the off-hand
				if named.weapon and named.weapon.twoHanded then
					for i = #items, 1, -1 do
						local d = Items.get(items[i].id) :: any
						if d.slot == "offhand" then
							table.remove(items, i)
						end
					end
				end
				return B.power(B.playerFromItems(classId, L, items), L)
			end
			local common = B.power(B.playerFromItems(classId, L, set), L)
			local pNamed = swapped(makeItem(id, L, Rarities.MYTHIC, {}))
			local pLeg = swapped(makeItem(tierDef, L, Rarities.LEGENDARY, expected(tierDef, L, Rarities.LEGENDARY, classId)))
			local pMyth = swapped(makeItem(tierDef, L, Rarities.MYTHIC, expected(tierDef, L, Rarities.MYTHIC, classId)))
			local dpsCell = "–"
			if named.weapon then
				local mon = B.monster(B.GENERIC, L)
				local a = B.playerFromItems(classId, L, { makeItem(id, L, Rarities.MYTHIC, {}) })
				local b = B.playerFromItems(classId, L, { makeItem(tierDef, L, Rarities.LEGENDARY, expected(tierDef, L, Rarities.LEGENDARY, classId)) })
				dpsCell = f2(B.dps(a, mon) / B.dps(b, mon))
			end
			row({ id, classId, `{named.slot} · {base}`, tostring(L), "+" .. pct(pNamed / common - 1), "+" .. pct(pLeg / common - 1), "+" .. pct(pMyth / common - 1), f2(pNamed / pLeg), dpsCell })
		end
	end
	print("")
end

-------------------------------------------------------------------------------------------------------------
-- 6. Context: hours a player spends in each boss's item band (generic hunting, AreaRates), Heroics from Elites
-------------------------------------------------------------------------------------------------------------
if not only or only == "context" then
	print("## Elite cadence and Heroics per hour (Warrior, real kinds, single Elite; fight + rest at 0.5 %/s + 7 s)")
	print("")
	header({ "cave · kind · L", "fight s", "HP", "s per kill", "Heroic/h (class)", "respawn cap kills/h (all elite spawners)" })
	for _, caveId in REGION_CAVES do
		local elites = spawnersOf(caveId, "elite")
		local members = 0
		for _, s in elites do
			members += s.count
		end
		local cap = members * 3600 / 120
		for _, e in eliteKinds(caveId) do
			local L = e.max
			local p = B.player("Warrior", clampLevel(L))
			local f = B.elite(p, Monsters.get(e.kind), L)
			local per = f.seconds + f.hpLost / (Stats.Formula.hpRegenPct / 100) + B.BREAK + B.WALK
			row({ `{caveId} · {e.kind} · {L}`, f1(f.seconds), pct(f.hpLost), f1(per), f2(3600 / per * B.itemsPerKill("elite", Rarities.HEROIC)), int(cap) })
		end
	end
	print("")

	print("## Hours of generic hunting per region (Warrior, GENERIC kind, no profile, AreaRates; no quests)")
	print("")
	header({ "levels", "hours", "boss kills possible at 3/day if 2 h/day played" })
	for _, band in { { 20, 45 }, { 45, 70 }, { 70, 100 } } do
		local hours = 0
		for L = band[1], band[2] - 1 do
			local r = B.areaRates("Warrior", L, nil, B.GENERIC)
			hours += Exp.expToNext(L) / r.expPerHour
		end
		row({ `{band[1]}-{band[2]}`, f1(hours), f1(hours / 2 * Config.Boss.dailyRuns) })
	end
	print("")
end
