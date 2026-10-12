local E = require("./SkillEngine")
local B = require("../tests/Balance")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local Bosses = require("../src/shared/Data/Bosses")
local fmt = string.format

local HEALER = {
	{ "heal", 10 }, { "renew", 10 }, { "devotion", 5 }, { "circleOfLight", 10 }, { "holyStrike", 5 },
	{ "shieldOfFaith", 10 }, { "radiance", 10 }, { "prayer", 5 }, { "auraOfEndurance", 5 }, { "purify", 5 },
	{ "divineIntervention", 10 }, { "resurrection", 5 }, { "divineWrath", 5 }, { "judgement", 5 },
}

-- Sustained heal rotation: heal skills on cooldown (shield, renew, circle, heal, purify, radiance), mana-limited.
-- Returns single-target HPS (on the tank), group HPS (5 allies in range), mana numbers.
local function healRotation(L, ranks, seconds, allies)
	local p = E.player("Cleric", L, ranks)
	local v = p.values
	local bonus = 1 + (p.hooks.healBonus or 0) / 100
	local pool, poolMax = v.maxMana, v.maxMana
	local t, gcd = 0, 0
	local cds = {}
	local tank, group, spent = 0, 0, 0
	local order = { "shieldOfFaith", "renew", "circleOfLight", "heal", "purify", "radiance", "prayer" }
	local casts = {}
	local dt = 0.05
	local channelUntil = -1
	while t < seconds do
		if t >= gcd and t >= channelUntil then
			for _, id in order do
				local r = ranks[id] or 0
				if r > 0 then
					local def, bp = Skills.effective(SkillData.get(id), r)
					local cost = Skills.scaled(def, def.cost, r)
					local function val(f)
						return Skills.valueAt(def, f, r)
					end
					local ready = (cds[id] or 0) <= t and cost <= pool
					if id == "prayer" then
						ready = ready and pool < poolMax * 0.4
					end
					if ready then
						local amt, grp = 0, 0
						if id == "heal" or id == "purify" then
							amt = v.magAtk * val("heal") / 100 * bonus
							if bp.secondTarget then
								grp = amt * bp.secondTarget / 100
							end
						elseif id == "renew" then
							amt = v.magAtk * val("heal") / 100 * bonus
						elseif id == "circleOfLight" then
							amt = v.magAtk * val("heal") / 100 * bonus
							grp = amt * (allies - 1)
						elseif id == "shieldOfFaith" then
							amt = v.magAtk * val("shield") / 100
							if bp.secondTarget then
								grp = amt * bp.secondTarget / 100
							end
						elseif id == "radiance" then
							amt = v.magAtk * val("dmg") / 100 * val("heal") / 100 * bonus
							grp = amt * (allies - 1)
						elseif id == "prayer" then
							pool = math.min(poolMax, pool + poolMax * val("mana") / 100)
							channelUntil = t + 3
						end
						tank += amt
						group += amt + grp
						pool -= cost
						spent += cost
						cds[id] = t + Skills.scaled(def, def.cooldown, r)
						gcd = t + E.GCD
						casts[id] = (casts[id] or 0) + 1
						break
					end
				end
			end
		end
		pool = math.min(poolMax, pool + v.manaRegen * dt)
		t += dt
	end
	return { tank = tank / seconds, group = group / seconds, pool = poolMax, regen = v.manaRegen, spent = spent / seconds, poolEnd = pool, magAtk = v.magAtk, casts = casts, maxHp = v.maxHp }
end

print("== Cleric healer build, sustained 300 s heal rotation (party of 5 in range)")
print("L | ranks | magAtk | tank HPS | group HPS | mana pool regen/s spent/s end")
for _, L in { 20, 45, 70, 100 } do
	local ranks, left = E.build("Cleric", L, HEALER)
	local r = healRotation(L, ranks, 300, 5)
	local s = {}
	for _, sk in SkillData.byClass.Cleric do
		if ranks[sk.id] then
			table.insert(s, sk.id .. " " .. ranks[sk.id])
		end
	end
	print(fmt("%d | %s (left %d) | %.0f | %.0f | %.0f | %.0f %.1f %.1f %.0f", L, table.concat(s, ", "), left, r.magAtk, r.tank, r.group, r.pool, r.regen, r.spent, r.poolEnd))
end

print("\n== Boss tank damage vs Cleric healing (team Warrior, Mage, Hunter, Cleric, Warrior at boss level - 1)")
print("boss L | fight min | tank maxHp | tank HP%/min | tank dmg/s | Cleric tank HPS | HPS / tank dmg | biggest hit Mage % | biggest Warrior % | Cleric HPS as % tank HP/min")
for _, id in { "grimrok", "morvane", "azgor", "vaelgrath" } do
	local def = Bosses.byId[id]
	local L = def.level - 1
	local team = {}
	for _, c in { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" } do
		table.insert(team, B.player(c, L))
	end
	local r = B.boss(id, team)
	local tank = team[1]
	local dmgPerSec = r.tankHpPerMinute * tank.values.maxHp / 60
	local ranks = E.build("Cleric", L, HEALER)
	local h = healRotation(L, ranks, r.seconds, 5)
	local mage, war = 0, 0
	for _, b in r.biggest do
		if b.classId == "Mage" then mage = math.max(mage, b.share) end
		if b.classId == "Warrior" then war = math.max(war, b.share) end
	end
	print(fmt("%s %d | %.1f | %d | %.0f%% | %.0f | %.0f | %.2f | %.0f%% | %.0f%% | %.0f%%", id, def.level, r.seconds / 60, tank.values.maxHp, r.tankHpPerMinute * 100, dmgPerSec, h.tank, h.tank / dmgPerSec, mage * 100, war * 100, h.tank * 60 / tank.values.maxHp * 100))
end

print("\n== Boss fight length with real sustained skill rotations (team W, M, H, C, W at boss level - 1; 75 % uptime)")
local PLANS = require("./diag_plans")
local BossScaling = require("../src/shared/Logic/BossScaling")
for _, id in { "grimrok", "morvane", "azgor", "vaelgrath" } do
	local def = Bosses.byId[id]
	local L = def.level - 1
	local team = {}
	for _, c in { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" } do
		table.insert(team, B.player(c, L))
	end
	local r = B.boss(id, team)
	local kind = { hpMul = BossScaling.hpMultiplier(5) * (def.hpMul or 1), atkMul = def.atkMul, defMul = def.defMul, speed = def.speed, attack = def.attack, damageKind = def.damageKind }
	local m = B.monster(kind, def.level, "boss")
	local sum = 0
	local parts = {}
	for _, c in { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" } do
		local ranks = E.build(c, L, PLANS[c])
		local f = E.fight({ classId = c, L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 120, weaponElement = if c == "Mage" then "fire" else nil })
		sum += f.dps * B.BOSS_UPTIME
		table.insert(parts, fmt("%s %.0f", c, f.dps))
	end
	print(fmt("%s | HP %d | model %.1f min | real skills %.1f min | %s", id, m.maxHp, r.seconds / 60, m.maxHp / sum / 60, table.concat(parts, ", ")))
end
