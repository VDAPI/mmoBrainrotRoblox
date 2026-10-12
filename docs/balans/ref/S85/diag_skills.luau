local E = require("./SkillEngine")
local B = require("../tests/Balance")
local FightSim = require("../src/shared/Logic/FightSim")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local SkillData = require("../src/shared/Data/Skills")
local fmt = string.format

local PLANS = {
	Warrior = {
		{ "mightyStrike", 10 }, { "bladeWhirl", 3 }, { "cleave", 3 }, { "bladeWhirl", 10 }, { "cleave", 10 },
		{ "earthquake", 10 }, { "crushingBlow", 10 }, { "titansWrath", 10 }, { "battleCry", 10 }, { "bloodlust", 10 },
		{ "fortitude", 5 }, { "steelSkin", 5 }, { "charge", 10 }, { "riposte", 5 }, { "taunt", 1 }, { "lastBastion", 1 },
	},
	Hunter = {
		{ "aimedShot", 10 }, { "doubleShot", 10 }, { "arrowRain", 10 }, { "venomArrow", 10 }, { "hawkEye", 5 },
		{ "piercingArrow", 10 }, { "huntersMark", 10 }, { "volley", 10 }, { "stormArrow", 10 }, { "predatorInstinct", 5 },
		{ "agility", 5 }, { "disengage", 10 }, { "frostTrap", 1 }, { "camouflage", 1 },
	},
	Mage = {
		{ "firebolt", 10 }, { "fireball", 10 }, { "meteor", 10 }, { "elementalist", 5 }, { "meteorStorm", 10 },
		{ "arcaneMind", 5 }, { "focus", 5 }, { "manaShield", 5 }, { "blink", 3 }, { "iceShard", 3 }, { "evocation", 1 },
	},
	Cleric = {
		{ "holyStrike", 10 }, { "heal", 3 }, { "radiance", 10 }, { "judgement", 10 }, { "divineWrath", 5 },
		{ "devotion", 5 }, { "renew", 3 }, { "circleOfLight", 5 }, { "heal", 10 }, { "shieldOfFaith", 5 },
		{ "auraOfEndurance", 5 }, { "purify", 1 }, { "resurrection", 1 }, { "prayer", 1 }, { "divineIntervention", 1 },
	},
}
local ELEMENT = { Mage = "fire" }
local LEVELS = { 20, 45, 70, 100 }
local HEALAT = { Cleric = 0.4 }

local function rankStr(classId, ranks)
	local out = {}
	for _, s in SkillData.byClass[classId] do
		local r = ranks[s.id]
		if r and r > 0 then
			table.insert(out, s.id .. " " .. r)
		end
	end
	return table.concat(out, ", ")
end

print("== Builds")
for _, c in B.CLASSES do
	for _, L in LEVELS do
		local ranks, left = E.build(c, L, PLANS[c])
		print(fmt("%s %d (left %d): %s", c, L, left, rankStr(c, ranks)))
	end
end

print("\n== Single target dummy (generic monster of level L): DPS basic | burst 8 s total | x basic | sustained 60 s | x basic | FightSim x1.2")
for _, c in B.CLASSES do
	for _, L in LEVELS do
		local ranks = E.build(c, L, PLANS[c])
		local m = B.monster(B.GENERIC, L)
		local base = E.fight({ classId = c, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, skills = false, weaponElement = ELEMENT[c] })
		local burst = E.fight({ classId = c, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 8, weaponElement = ELEMENT[c] })
		local sus = E.fight({ classId = c, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, weaponElement = ELEMENT[c] })
		local parts = {}
		for id, v in sus.by do
			table.insert(parts, { id = id, v = v })
		end
		table.sort(parts, function(a, b) return a.v > b.v end)
		local ps = {}
		for i = 1, math.min(5, #parts) do
			table.insert(ps, fmt("%s %.0f%%", parts[i].id, parts[i].v / sus.dealt * 100))
		end
		print(fmt("%s %d | %.0f | %.0f | %.2f | %.0f | %.2f | pool %.0f spent60 %.0f end %.0f | %s", c, L, base.dps, burst.dps, burst.dps / base.dps, sus.dps, sus.dps / base.dps, sus.poolMax, sus.spent, sus.poolEnd, table.concat(ps, "; ")))
	end
end

print("\n== AoE: 3 clustered dummies, burst 8 s: total dmg/s on all | x single basic | sustained 60 s x basic")
for _, c in B.CLASSES do
	for _, L in LEVELS do
		local ranks = E.build(c, L, PLANS[c])
		local m = B.monster(B.GENERIC, L)
		local base = E.fight({ classId = c, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 60, skills = false })
		local tg = { m, m, m }
		local burst = E.fight({ classId = c, L = L, ranks = ranks, targets = tg, dummy = true, seconds = 8, weaponElement = ELEMENT[c] })
		local sus = E.fight({ classId = c, L = L, ranks = ranks, targets = tg, dummy = true, seconds = 60, weaponElement = ELEMENT[c] })
		print(fmt("%s %d | %.0f | %.2f | %.2f", c, L, burst.dps, burst.dps / base.dps, sus.dps / base.dps))
	end
end

print("\n== Group kill sim (generic kind, group size n, monsters hit; real skills) vs FightSim x1.2: s / HP% end (peak)")
for _, c in B.CLASSES do
	for _, L in LEVELS do
		local ranks = E.build(c, L, PLANS[c])
		local p = B.player(c, L)
		local row = {}
		local wsum, ws, wl, wfs, wfl = 0, 0, 0, 0, 0
		for n = 1, 4 do
			local members = FightSim.group(B.GENERIC, L, n)
			local f = E.fight({ classId = c, L = L, ranks = ranks, targets = members, seconds = 300, monstersHit = true, weaponElement = ELEMENT[c], healAt = HEALAT[c] })
			local fs = FightSim.groupFight(p, members, FightSim.SKILL_DPS)
			table.insert(row, fmt("n%d %.1fs %.0f%%(%.0f%%) | FS %.1fs %.0f%%", n, f.seconds, f.endLost * 100, f.hpLost * 100, fs.seconds, fs.hpLost * 100))
			local w = AreaSpawns.GROUP_SIZE_WEIGHTS[n] or 0
			wsum += w; ws += w * f.seconds; wl += w * f.endLost; wfs += w * fs.seconds; wfl += w * fs.hpLost
		end
		print(fmt("%s %d || %s || avg real %.1fs %.0f%% vs FS %.1fs %.0f%%", c, L, table.concat(row, " || "), ws / wsum, wl / wsum * 100, wfs / wsum, wfl / wsum * 100))
	end
end

print("\n== Elite solo (variant elite, spawner = L): real vs FightSim x1.2")
for _, c in B.CLASSES do
	for _, L in LEVELS do
		local ranks = E.build(c, L, PLANS[c])
		local p = B.player(c, L)
		local m = B.monster(B.GENERIC, L, "elite")
		local f = E.fight({ classId = c, L = L, ranks = ranks, targets = { m }, seconds = 300, monstersHit = true, weaponElement = ELEMENT[c], healAt = HEALAT[c] })
		local fs = B.elite(p, B.GENERIC, L)
		print(fmt("%s %d | real %.1fs %.0f%% (peak %.0f%%) healed %.0f | FS %.1fs %.0f%%", c, L, f.seconds, f.endLost * 100, f.hpLost * 100, f.healed, fs.seconds, fs.hpLost * 100))
	end
end
