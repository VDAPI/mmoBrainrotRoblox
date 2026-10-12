-- Rough check for the Hunter paths design (rozwoj/lowca.md). Not game code.
-- DEX rating (global G) patched into this copy's StatCalc; automatic ranks (global A5: step 4, cap 95); path nodes
-- approximated as fake passives / cloned skill defs; traps as instant circles (monsters walk into them).
local E = require("./SkillEngine")
local B = require("../tests/Balance")
local SkillData = require("../src/shared/Data/Skills")
local Damage = require("../src/shared/Logic/Damage")
local fmt = string.format

local byId = SkillData.byId
local ARGS = require("@lune/process").args
local function arg(name)
	return table.find(ARGS, name) ~= nil
end
-- Weapon-speed normalisation of skill damage (lowca.md 5, global G): on unless "raw"
E.SPEED_NORM = not arg("raw")
-- Combat.skillSpeedRef: 0.8 as in wojownik.md (two-handed axe unchanged); "ref1" = 1.0
E.SPEED_REF = if arg("ref1") then 1 else 0.8
-- Design after the review of lowca.md (default); "old" = the design before it (each change can be added back by name)
local REVIEW = { snap = true, bitefield = true, area20 = true, trim = true, loot = true, dips = true, mark = true }
local function v(name)
	return arg(name) or (not arg("old") and REVIEW[name] == true)
end

local UNLOCK = {
	-- base ladder 1,3,6,10,14,18,30,45
	aimedShot = 1, doubleShot = 3, disengage = 6, arrowRain = 10, hawkEye = 14, venomArrow = 18, volley = 30,
	predatorInstinct = 45,
	-- row 1 (moved A), row 7 (moved B)
	piercingArrow = 10, frostTrap = 10, agility = 10,
	stormArrow = 48, camouflage = 48, huntersMark = 48,
	-- new
	drawBead = 26, heartseeker = 60, venomSnare = 26, snarefield = 60, falcon = 26, drive = 80,
}

local function rankFrom(u, maxLevel, L)
	if not u or L < u then
		return 0
	end
	local span = math.min(36, 95 - u)
	local r = 0
	for n = 1, maxLevel do
		if u + math.floor((n - 1) * span / (maxLevel - 1) + 0.5) <= L then
			r = n
		end
	end
	return r
end

local function rankAt(id, L, unlockOverride)
	local s = byId[id]
	if not s then
		return 0
	end
	return rankFrom(unlockOverride or UNLOCK[id], s.maxLevel, L)
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
	UNLOCK[newId] = UNLOCK[id]
	return d
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
	for stat, v in hooks or {} do
		values["h_" .. stat] = v
		h[stat] = "h_" .. stat
	end
	byId[id] = {
		id = id, class = "Hunter", maxLevel = 1, type = "passive", values = values,
		passive = { flat = f, pct = p, hooks = h }, cost = 0, cooldown = 0,
	}
end

-- New skills (rank 1 -> 10) ---------------------------------------------------------------------------------
-- Namierzenie: on one enemy, for the Hunter only (modelled as a buff; in AoE fights 1/3 of it)
byId.drawBead = { id = "drawBead", class = "Hunter", maxLevel = 10, type = "buff", target = "self",
	resource = "energy", cost = 15, cooldown = 25, duration = 10, damageKind = "phys",
	values = { crit = { 15, 25 }, critDmg = { 20, 40 } },
	effects = { { kind = "statBuff", duration = 10, stats = { critChance = "crit", critDmg = "critDmg" }, target = "self" } } }
-- Heartseeker: 500 -> 800 %, x2 below 20 % HP (dummy: 20 % of the time below) = x1.2; 1.5 s draw (no basic attacks)
byId.heartseeker = { id = "heartseeker", class = "Hunter", maxLevel = 10, type = "projectile", target = "enemy",
	resource = "energy", cost = 50, cooldown = 30, range = 40, damageKind = "phys", castTime = 1.5,
	values = { dmg = { 400 * 1.2, 650 * 1.2 } } }
byId.venomSnare = { id = "venomSnare", class = "Hunter", maxLevel = 10, type = "circleTarget", target = "point",
	resource = "energy", cost = 25, cooldown = 10, radius = 6, range = 30, damageKind = "phys",
	values = { dmg = { 90, 160 }, poison = { 60, 110 } },
	effects = { { kind = "poison", duration = 6, value = "poison" } } }
byId.snarefield = { id = "snarefield", class = "Hunter", maxLevel = 10, type = "circleTarget", target = "point",
	resource = "energy", cost = 45, cooldown = 40, radius = 8, range = 30, damageKind = "phys",
	values = { dmg = { 60, 110 }, vuln = { 6, 10 } },
	effects = { { kind = "vulnerability", duration = 6, value = "vuln" } } }
byId.falcon = { id = "falcon", class = "Hunter", maxLevel = 10, type = "companion", target = "enemy",
	resource = "energy", cost = 30, cooldown = 30, duration = 20, interval = 2, damageKind = "phys",
	values = { dmg = { 15, 30 } } }
byId.drive = { id = "drive", class = "Hunter", maxLevel = 10, type = "circleTarget", target = "point",
	resource = "energy", cost = 40, cooldown = 30, radius = 12, range = 30, damageKind = "phys",
	values = { dmg = { 80, 120 }, vuln = 6 },
	effects = { { kind = "vulnerability", duration = 8, value = "vuln" } } }
-- Hunter's Mark retuned for the party path: 8 -> 12 % (was 10 -> 25 %)
clone("huntersMark", "huntersMarkZ", { values = { vuln = { 8, 12 } } })
E.BUFFS.drawBead = true
E.BUFFS.huntersMarkZ = true

local LEVELS = { 20, 45, 70, 100 }
local BASE = { "aimedShot", "doubleShot", "disengage", "arrowRain", "hawkEye", "venomArrow", "volley", "predatorInstinct" }
local ROW1 = { "piercingArrow", "frostTrap", "agility" }

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

local function swap(r, from, to)
	if r[from] then
		r[to] = r[from]
		r[from] = nil
	end
end

local function on(L, lvl, v)
	return if L >= lvl then v else 0
end

-- Today: 14 skills, today's unlocks, automatic ranks (as global diag_autorank)
local function today(classId)
	return function(L)
		local r = {}
		for _, s in SkillData.byClass[classId] do
			local n = rankFrom(s.unlock, s.maxLevel, L)
			if n > 0 then
				r[s.id] = n
			end
		end
		return r, nil
	end
end

local function base(L)
	local list = table.clone(BASE)
	for _, id in ROW1 do
		table.insert(list, id)
	end
	return ranksFor(list, L), nil
end

local AOE = false -- set per fight: single-target-only effects count for 1 of 3 targets

local function marksman(weapon)
	return function(L)
		local list = table.clone(BASE)
		for _, id in { "piercingArrow", "frostTrap", "agility", "drawBead", "stormArrow", "heartseeker" } do
			table.insert(list, id)
		end
		local r = ranksFor(list, L)
		-- Celny Strzał (row 2): a crit cuts Aimed Shot's cooldown by 50 % -> about x(1 - 0.5 x crit 0.3);
		-- Długi Strzał (row 5): Aimed Shot +30 pp
		if L >= 15 then
			local a = byId.aimedShot
			local add = on(L, 33, 30)
			clone("aimedShot", "aimedShotM", { cooldown = 4 * (1 - 0.5 * 0.3), values = { dmg = { a.values.dmg[1] + add, a.values.dmg[2] + add } } })
			swap(r, "aimedShot", "aimedShotM")
		end
		-- Namierzenie (row 4) on one target only; Spokojna Dłoń (row 4) +3 s
		if L >= 26 then
			local k = if AOE then 1 / 3 else 1
			local dur = 13
			local d = clone("drawBead", "drawBeadM", { duration = dur, values = { crit = { 12 * k, 20 * k }, critDmg = { 15 * k, 30 * k } } })
			d.effects = { { kind = "statBuff", duration = dur, stats = { critChance = "crit", critDmg = "critDmg" }, target = "self" } }
			E.BUFFS.drawBeadM = true
			swap(r, "drawBead", "drawBeadM")
		end
		-- Oko Burzy (row 7): storm cooldown x0.8
		if L >= 48 then
			clone("stormArrow", "stormArrowM", { cooldown = 32 })
			swap(r, "stormArrow", "stormArrowM")
		end
		-- Śmiertelny Grot (row 9): finisher below 30 % (x1.3 on a dummy); Strzał Królobójcy (row 11) +20 %
		if L >= 70 then
			local mul = 1.3 * (if L >= 90 then 1.2 else 1)
			clone("heartseeker", "heartseekerM", { values = { dmg = { 400 * mul, 650 * mul } } })
			swap(r, "heartseeker", "heartseekerM")
		end
		-- reference build dips ("dips"): Oznaczenie 3 (1/3 strength: 2 % vulnerability on own hits, here as attack),
		-- Jad Myśliwski 3 (+30 % poison)
		local dip = if v("dips") then (if AOE then 2 / 3 else 2) else 0
		passive("mmNodes", {
			critChance = on(L, 10, 3) + on(L, 33, 3), -- Pewna Ręka, Bystry Wzrok
			critDmg = on(L, 15, 15), -- Zabójcza Precyzja
		}, {
			physAtk = (if AOE then on(L, 20, 3) else on(L, 20, 9)) + on(L, 15, dip), -- Słaby Punkt: one target, up to +9 %
			maxHp = on(L, 80, 12),
			armor = on(L, 80, 15),
		}, {
			poisonDamage = if v("dips") then on(L, 10, 30) else 0,
		})
		r.mmNodes = 1
		return r, { weapon = weapon }
	end
end

local function trapper(weapon)
	return function(L)
		-- review variant ("loot"): Łup Kłusownika (row 5, instead of Cierpliwość): each enemy a trap catches returns
		-- LOOT energy (at most 3 per trap) -> modelled as a lower trap cost
		local LOOT = 4
		local refund = if v("loot") and L >= 33 then (if AOE then 3 else 1) * LOOT else 0
		-- review variant ("snap"): more instant damage on the traps (Trujące Sidła 130 -> 220 %, Pole Sideł 90 -> 150 %)
		if v("bigfield") then
			byId.venomSnare.values.dmg = { 130, 220 }
			byId.snarefield.values.dmg = { 150, 250 }
		elseif v("snap") then
			byId.venomSnare.values.dmg = { 130, 220 }
			byId.snarefield.values.dmg = { 90, 150 }
		else
			byId.venomSnare.values.dmg = { 90, 160 }
			byId.snarefield.values.dmg = { 60, 110 }
		end
		local list = table.clone(BASE)
		for _, id in { "piercingArrow", "frostTrap", "agility", "venomSnare", "camouflage", "snarefield" } do
			table.insert(list, id)
		end
		local r = ranksFor(list, L)
		-- Zjadliwy Jad (row 2): poison 12 s, 3 stacks
		if L >= 15 then
			local v = clone("venomArrow", "venomArrowT", { poisonStacks = 3 })
			v.effects = { { kind = "poison", duration = 12, value = "poison" } }
			swap(r, "venomArrow", "venomArrowT")
		end
		-- Oszczędność Kłusownika (row 2): traps -30 % energy; Szersze Sidła (row 4) not modelled
		if L >= 26 and r.venomSnare then
			clone("venomSnare", "venomSnareT", { cost = 25 * 0.7 - refund })
			swap(r, "venomSnare", "venomSnareT")
		end
		-- Kąsające Strzały (row 5). Old: a poison field, 30 % of a wave per second for 4 s. Review variant
		-- ("bite"): +45 % on the first wave instead (modelled as +45/4 % on every wave, all land within 1.5 s);
		-- "bitefield": both.
		if L >= 33 then
			local patch = {}
			if not v("bite") then
				patch.lingering = { pct = 30, duration = 4, kind = "poison" }
			end
			local d = clone("arrowRain", "arrowRainT", patch)
			if v("bite") or v("bitefield") then
				local a = byId.arrowRain.values.dmg
				d.values.dmg = { a[1] * (1 + 0.45 / 4), a[2] * (1 + 0.45 / 4) }
			end
			swap(r, "arrowRain", "arrowRainT")
		end
		-- Wybuchowa Pułapka (row 6): Frost Trap bursts for 150 % and poisons 100 % (as an instant circle)
		if L >= 40 and r.frostTrap then
			byId.frostTrapT = { id = "frostTrapT", class = "Hunter", maxLevel = 10, type = "circleTarget", target = "point",
				resource = "energy", cost = 25 * 0.7 - refund, cooldown = 18, radius = 6, damageKind = "phys", values = { dmg = 150, poison = 100 },
				effects = { { kind = "poison", duration = 6, value = "poison" } } }
			r.frostTrapT = r.frostTrap
		end
		if L >= 60 and r.snarefield then
			local d = clone("snarefield", "snarefieldT", { cost = 45 * 0.7 - refund })
			if L >= 90 then
				d.values.poison = if v("trim") then 120 else 200
				d.effects = { { kind = "vulnerability", duration = 6, value = "vuln" }, { kind = "poison", duration = 6, value = "poison" } }
			end
			swap(r, "snarefield", "snarefieldT")
		end
		-- build priority (lowca.md 3.2): Pole Sideł at the group's entry, then Trujące Sidła ("open")
		if arg("open") then
			E.BUFFS.snarefieldT = true
			E.BUFFS.venomSnareT = true
		end
		-- review variant ("area"): area hook +15 % on area skills from row 5 (33), as a multiplier on their values
		local AREA_MUL = if v("area20") then 1.2 else 1.15
		if (v("area") or v("area20")) and L >= 26 then
			local AREA = { "arrowRainT", "volley", "piercingArrow", "venomSnareT", "snarefieldT", "frostTrapT" }
			for _, id in AREA do
				if r[id] and byId[id] then
					local d = clone(id, id .. "A", {})
					local v = byId[id].values.dmg
					d.values.dmg = if type(v) == "table" then { v[1] * AREA_MUL, v[2] * AREA_MUL } else v * AREA_MUL
					if d.lingering then
						d.lingering = d.lingering
					end
					if E.BUFFS[id] then
						E.BUFFS[id .. "A"] = true
					end
					swap(r, id, id .. "A")
				end
			end
		end
		passive("trNodes", {
			energyRegen = if v("loot") then 0 else on(L, 33, 1.5), -- Cierpliwość
		}, {
			maxHp = on(L, 80, 12),
		}, {
			poisonDamage = on(L, 10, 30) + on(L, 80, 30),
		})
		r.trNodes = 1
		return r, { weapon = weapon }
	end
end

local function scout(weapon)
	return function(L)
		local list = table.clone(BASE)
		for _, id in { "piercingArrow", "frostTrap", "agility", "falcon", "drive" } do
			table.insert(list, id)
		end
		local r = ranksFor(list, L)
		if L >= 48 then
			r.huntersMarkZ = rankAt("huntersMark", L)
			-- review ("mark"): Znak 6 -> 8 %, 10B +2 (from rank 10, poz. 84) in the reference build
			if v("mark") then
				local top = 8 + on(L, 84, 2)
				byId.huntersMarkZ.values = table.clone(byId.huntersMarkZ.values)
				byId.huntersMarkZ.values.vuln = { 6, top }
			else
				byId.huntersMarkZ.values = table.clone(byId.huntersMarkZ.values)
				byId.huntersMarkZ.values.vuln = { 8, 12 }
			end
		end
		-- Falcon: Ostre Szpony +15 pp (row 4), Sokola Więź +6 s (row 5); Royal Falcon (row 8): the whole fight;
		-- Sokół Władcy (row 11): strikes every 1.6 s
		if L >= 26 then
			local f = byId.falcon
			local dur = 20 + on(L, 33, 6)
			if L >= 60 then
				dur = 600
			end
			local d = clone("falcon", "falconZ", { duration = dur, values = { dmg = { f.values.dmg[1] + 15, f.values.dmg[2] + 15 } } })
			if L >= 90 then
				d.interval = 1.6
			end
			swap(r, "falcon", "falconZ")
		end
		-- Szybki Znak (row 9): mark cooldown x0.8
		if L >= 70 and r.huntersMarkZ then
			clone("huntersMarkZ", "huntersMarkS", { cooldown = 20 })
			E.BUFFS.huntersMarkS = true
			swap(r, "huntersMarkZ", "huntersMarkS")
		end
		-- Oznaczenie (row 2): 6 % vulnerability from basic attacks (Royal Falcon: also its strikes); before the mark
		-- always, after it in the mark's gaps
		local spot = if L >= 70 then 6 * 0.25 elseif L >= 48 then 6 * 0.4 elseif L >= 15 then 6 else 0
		if AOE then
			spot = spot / 3
		end
		-- reference build dips ("dips"): rows 1-2 of the Marksman (Pewna Ręka +3 crit, Zabójcza Precyzja +15 crit
		-- damage, Rytm Strzelca on Aimed Shot)
		if v("dips") and L >= 15 then
			clone("aimedShot", "aimedShotS", { cooldown = 4 * (1 - 0.5 * 0.25) })
			swap(r, "aimedShot", "aimedShotS")
		end
		passive("scNodes", {
			atkSpeed = 0, -- party reference: Lekka Stopa instead of Szybkie Palce
			dodge = on(L, 20, 6),
			critChance = if v("dips") then on(L, 10, 3) else 0,
			critDmg = if v("dips") then on(L, 15, 15) else 0,
		}, {
			physAtk = spot,
			maxHp = on(L, 33, 9) + on(L, 80, 8),
		})
		r.scNodes = 1
		return r, { weapon = weapon }
	end
end

-- Warrior references (same engine, same rating): today's 14 and the Berserker of rozwoj/wojownik.md
local function berserker(L)
	local WU = { mightyStrike = 1, charge = 3, bladeWhirl = 6, taunt = 10, steelSkin = 14, bloodlust = 18, earthquake = 30,
		riposte = 45, fortitude = 10, cleave = 10, battleCry = 10, titansWrath = 48 }
	local r = {}
	for id, u in WU do
		local n = rankFrom(u, byId[id].maxLevel, L)
		if n > 0 then
			r[id] = n
		end
	end
	if L >= 26 then
		byId.rend = byId.rend or { id = "rend", class = "Warrior", maxLevel = 10, type = "target", target = "enemy",
			resource = "energy", cost = 25, cooldown = 10, range = 8, damageKind = "phys",
			values = { dmg = { 140 * 1.8, 250 * 1.8 }, bleed = 40 }, effects = { { kind = "bleed", duration = 6, value = "bleed" } } }
		r.rend = rankFrom(26, 10, L)
	end
	if L >= 60 then
		byId.carnage = byId.carnage or { id = "carnage", class = "Warrior", maxLevel = 10, type = "buff", target = "self",
			resource = "energy", cost = 30, cooldown = 45, duration = 8, damageKind = "phys", values = { atk = { 15, 25 } },
			effects = { { kind = "statBuff", duration = 8, stats = { physAtk = "atk" }, pct = true, target = "self" } } }
		E.BUFFS.carnage = true
		r.carnage = rankFrom(60, 10, L)
	end
	local perStack = on(L, 15, 1) + on(L, 20, 2)
	byId.bersNodes = { id = "bersNodes", class = "Warrior", maxLevel = 1, type = "passive",
		values = { a = perStack * 7.5, b = on(L, 33, 9), c = on(L, 80, 12) },
		passive = { pct = { atkSpeed = "a", physAtk = "b", maxHp = "c" } }, cost = 0, cooldown = 0 }
	r.bersNodes = 1
	return r, { weapon = "axe2h", offhand = false }
end

local BUILDS = {
	{ "Wojownik dziś (14)", today("Warrior"), "Warrior" },
	{ "Berserker", berserker, "Warrior" },
	{ "Łowca dziś (14)", today("Hunter"), "Hunter" },
	{ "Baza, łuk", base, "Hunter" },
	{ "Baza, długi łuk", function(L) local r = base(L) return r, { weapon = "longbow" } end, "Hunter" },
	{ "Baza, krótki łuk", function(L) local r = base(L) return r, { weapon = "shortbow" } end, "Hunter" },
	{ "Baza, kusza", function(L) local r = base(L) return r, { weapon = "crossbow" } end, "Hunter" },
	{ "Baza, ciężka kusza", function(L) local r = base(L) return r, { weapon = "heavycrossbow" } end, "Hunter" },
	{ "Strzelec, długi łuk", marksman("longbow"), "Hunter" },
	{ "Strzelec, ciężka kusza", marksman("heavycrossbow"), "Hunter" },
	{ "Traper, kusza", trapper("crossbow"), "Hunter" },
	{ "Traper, łuk", trapper("bow"), "Hunter" },
	{ "Zwiadowca, łuk", scout("bow"), "Hunter" },
	{ "Zwiadowca, krótki łuk", scout("shortbow"), "Hunter" },
}

local function eHP(p, L)
	local v = p.values
	local red = Damage.reduction(v.armor, L)
	local dodge = math.min(v.dodge or 0, 30) / 100
	return v.maxHp / (1 - red) / (1 - dodge), v.maxHp, red
end

local REF = 4 -- "Baza, łuk"
print("build | L | 60 s single DPS | x base | x Berserker | AoE3 8 s | x base | AoE3 60 s x base | AoE3/single 8 s | sustained x basic | eHP x base | crit / speed / dodge | group 3: s, HP lost")
for _, L in LEVELS do
	local res = {}
	for _, b in BUILDS do
		local ranks, gear = b[2](L)
		local cls = b[3]
		local m = B.monster(B.GENERIC, L)
		local sus = E.fight({ classId = cls, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, gearOpts = gear })
		AOE = true
		local ranksA = b[2](L)
		AOE = false
		local aoe = E.fight({ classId = cls, L = L, ranks = ranksA, targets = { m, m, m }, dummy = true, seconds = 8, gearOpts = gear })
		local aoeS = E.fight({ classId = cls, L = L, ranks = ranksA, targets = { m, m, m }, dummy = true, seconds = 60, gearOpts = gear, reserve = true })
		local burst = E.fight({ classId = cls, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 8, gearOpts = gear })
		local basic = E.fight({ classId = cls, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, gearOpts = gear, skills = false })
		local grp = E.fight({ classId = cls, L = L, ranks = ranks, targets = B.group(B.GENERIC, L, 3), seconds = 300, monstersHit = true, gearOpts = gear })
		local p = E.player(cls, L, ranks, nil, gear)
		local ehp = eHP(p, L)
		table.insert(res, { name = b[1], weapon = gear and gear.weapon or "bow", sus = sus.dps, aoe = aoe.dps, aoeS = aoeS.dps, sby = aoeS.by, scasts = aoeS.casts, burst = burst.dps, basic = basic.dps, ehp = ehp, p = p,
			gs = grp.seconds, gl = grp.hpLost, by = sus.by, aby = aoe.by, spent = sus.spent, killed = grp.killed })
	end
	local ref = res[REF]
	local bers = res[2]
	for _, x in res do
		local v = x.p.values
		print(fmt("%s | %d | %.0f | %.2f | %.2f | %.0f | %.2f | %.2f | %.2f | %.2f | %.2f | %.0f / %.2f / %.0f | %.1f s, %.0f%%",
			x.name, L, x.sus, x.sus / ref.sus, x.sus / bers.sus, x.aoe, x.aoe / ref.aoe, x.aoeS / ref.aoeS, x.aoe / x.burst, x.sus / x.basic,
			x.ehp / ref.ehp, v.critChance, v.atkSpeed, v.dodge or 0, x.gs, x.gl * 100))
		if arg("by") then
			local parts = {}
			for id, a in x.by do
				table.insert(parts, { id, a })
			end
			table.sort(parts, function(a, b) return a[2] > b[2] end)
			local s = {}
			for i = 1, math.min(7, #parts) do
				table.insert(s, fmt("%s %.0f%%", parts[i][1], parts[i][2] / math.max(1, x.sus * 60) * 100))
			end
			print("    " .. table.concat(s, ", "))
			parts = {}
			for id, a in x.aby do
				table.insert(parts, { id, a })
			end
			table.sort(parts, function(a, b) return a[2] > b[2] end)
			s = {}
			for i = 1, math.min(14, #parts) do
				table.insert(s, fmt("%s %.0f%%", parts[i][1], parts[i][2] / math.max(1, x.aoe * 8) * 100))
			end
			print("    AoE: " .. table.concat(s, ", "))
			parts = {}
			for id, a in x.sby do
				table.insert(parts, { id, a })
			end
			table.sort(parts, function(a, b) return a[2] > b[2] end)
			s = {}
			for i = 1, math.min(9, #parts) do
				table.insert(s, fmt("%s %.0f%% (%d)", parts[i][1], parts[i][2] / math.max(1, x.aoeS * 60) * 100, x.scasts[(string.split(parts[i][1], ":"))[1]] or 0))
			end
			print("    AoE60: " .. table.concat(s, ", "))
		end
	end
	-- compact summary: x same-weapon base (single 60 s, AoE 8 s, AoE 60 s), x Berserker, AoE 8 s x best Marksman,
	-- solo time (6 s walk + 8 s fight of the fastest AoE 8 s build) and group-3 time ratio vs the fastest
	local baseOf = {}
	for _, x in res do
		if string.find(x.name, "^Baza") then
			baseOf[x.weapon] = x
		end
	end
	local bestMm, fastest, fastGrp = 0, 0, math.huge
	local mmLong = res[1]
	for _, x in res do
		if x.name == "Strzelec, długi łuk" then
			mmLong = x
		end
		if string.find(x.name, "^Strzelec") then
			bestMm = math.max(bestMm, x.aoe)
		end
		if x.name ~= "Berserker" and not string.find(x.name, "dziś") then
			fastest = math.max(fastest, x.aoe)
			fastGrp = math.min(fastGrp, x.gs)
		end
	end
	for _, x in res do
		local bw = baseOf[x.weapon]
		if bw and not string.find(x.name, "^Baza") and x.name ~= "Berserker" and not string.find(x.name, "dziś") then
			local r = x.aoe / fastest
			print(fmt("  SUM %s | L%d | single x base(w) %.2f | x Bers %.2f | AoE8 x base(w) %.2f | AoE60 x base(w) %.2f | AoE8 x best Strzelec %.2f | AoE8 x fastest %.2f -> solo %.2f | grp %.2f | S x Strzelec dl %.2f",
				x.name, L, x.sus / bw.sus, x.sus / bers.sus, x.aoe / bw.aoe, x.aoeS / bw.aoeS, x.aoe / bestMm, r, (6 + 8 / r) / 14, (6 + x.gs) / (6 + fastGrp), x.sus / mmLong.sus))
		end
	end
	print("")
end
