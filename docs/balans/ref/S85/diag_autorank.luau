-- Rough check (redesign global): today's greedy point builds vs automatic ranks (all 14 skills as base),
-- rank r at unlock + round((r-1) * min(STEP, (CAP - unlock) / 9)); passives spread over the same span.
local E = require("./SkillEngine")
local B = require("../tests/Balance")
local SkillData = require("../src/shared/Data/Skills")
local fmt = string.format

local PLANS = {
	Warrior = { { "mightyStrike", 10 }, { "bladeWhirl", 3 }, { "cleave", 3 }, { "bladeWhirl", 10 }, { "cleave", 10 }, { "earthquake", 10 }, { "crushingBlow", 10 }, { "titansWrath", 10 }, { "battleCry", 10 }, { "bloodlust", 10 }, { "fortitude", 5 }, { "steelSkin", 5 }, { "charge", 10 }, { "riposte", 5 }, { "taunt", 1 }, { "lastBastion", 1 } },
	Hunter = { { "aimedShot", 10 }, { "doubleShot", 10 }, { "arrowRain", 10 }, { "venomArrow", 10 }, { "hawkEye", 5 }, { "piercingArrow", 10 }, { "huntersMark", 10 }, { "volley", 10 }, { "stormArrow", 10 }, { "predatorInstinct", 5 }, { "agility", 5 }, { "disengage", 10 }, { "frostTrap", 1 }, { "camouflage", 1 } },
	Mage = { { "firebolt", 10 }, { "fireball", 10 }, { "meteor", 10 }, { "elementalist", 5 }, { "meteorStorm", 10 }, { "arcaneMind", 5 }, { "focus", 5 }, { "manaShield", 5 }, { "blink", 3 }, { "iceShard", 3 }, { "evocation", 1 } },
	Cleric = { { "holyStrike", 10 }, { "heal", 3 }, { "radiance", 10 }, { "judgement", 10 }, { "divineWrath", 5 }, { "devotion", 5 }, { "renew", 3 }, { "circleOfLight", 5 }, { "heal", 10 }, { "shieldOfFaith", 5 }, { "auraOfEndurance", 5 }, { "purify", 1 }, { "resurrection", 1 }, { "prayer", 1 }, { "divineIntervention", 1 } },
}
local ELEMENT = { Mage = "fire" }
local LEVELS = { 10, 15, 20, 30, 45, 70, 100 }

local function autoRank(skill, L, STEP, CAP)
	if L < skill.unlock then return 0 end
	local step = math.min(STEP, (CAP - skill.unlock) / 9)
	local span = 9 * step
	local r = 0
	for n = 1, skill.maxLevel do
		local need = skill.unlock + math.floor((n - 1) * span / (skill.maxLevel - 1) + 0.5)
		if need <= L then r = n end
	end
	return r
end

local function autoBuild(c, L, STEP, CAP)
	local ranks, sum = {}, 0
	for _, s in SkillData.byClass[c] do
		local r = autoRank(s, L, STEP, CAP)
		if r > 0 then ranks[s.id] = r; sum += r end
	end
	return ranks, sum
end

local function sum(r) local n = 0 for _, v in r do n += v end return n end

for _, STEP in { 3, 4 } do
	print(fmt("\n== STEP %d, CAP 95: class L | ranks today / auto | sustained 60 s x basic today / auto | burst 8 s today / auto | AoE3 burst today / auto", STEP))
	for _, c in B.CLASSES do
		for _, L in LEVELS do
			local today = E.build(c, L, PLANS[c])
			local auto = autoBuild(c, L, STEP, 95)
			local m = B.monster(B.GENERIC, L)
			local function run(ranks, sec, tg, skills)
				return E.fight({ classId = c, L = L, ranks = ranks, targets = tg, dummy = true, seconds = sec, skills = skills, weaponElement = ELEMENT[c] }).dps
			end
			local base = run(today, 60, { m }, false)
			print(fmt("%s %d | %d / %d | %.2f / %.2f | %.2f / %.2f | %.2f / %.2f", c, L, sum(today), sum(auto),
				run(today, 60, { m }) / base, run(auto, 60, { m }) / base,
				run(today, 8, { m }) / base, run(auto, 8, { m }) / base,
				run(today, 8, { m, m, m }) / base, run(auto, 8, { m, m, m }) / base))
		end
	end
end
