local E = require("./SkillEngine")
local B = require("../tests/Balance")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local PLANS = require("./diag_plans")
local fmt = string.format

print("== Damage skills at the rank the LEVEL allows (rank cap): single-target pct per cast (incl. hits, bp extras, DoT), cd, cost, pct/s")
for _, c in B.CLASSES do
	for _, L in { 20, 45, 70, 100 } do
		local p = E.player(c, L, {})
		local basicPctS = p.values.atkSpeed * 100
		local sum, sumAoe = 0, 0
		local parts = {}
		for _, s in SkillData.byClass[c] do
			local r = E.rankCap(s, L)
			if r > 0 and s.values.dmg and not E.SKIP[s.id] then
				if c == "Mage" and not Skills.elementAllowed(s, "fire") then
					continue
				end
				local def = Skills.effective(s, r)
				local cd = Skills.scaled(def, def.cooldown, r)
				local single = E.potency(s.id, r, 1)
				local aoe = E.potency(s.id, r, 3)
				sum += single / cd
				sumAoe += aoe / cd
				table.insert(parts, fmt("%s r%d %.0f%%/%.0fs", s.id, r, single, cd))
			end
		end
		print(fmt("%s %d | basic %.0f%%/s | skills on cd: single %.0f%%/s (x%.2f total) AoE3 %.0f%%/s (x%.2f) | %s", c, L, basicPctS, sum, 1 + sum / basicPctS, sumAoe, (sumAoe + basicPctS) / basicPctS, table.concat(parts, "; ")))
	end
end

print("\n== Hunter with passives (build): atkSpeed / crit at 100")
local ranks = E.build("Hunter", 100, PLANS.Hunter)
local p = E.player("Hunter", 100, ranks)
print("atkSpeed", p.values.atkSpeed, "crit", p.values.critChance, "critDmg", p.values.critDmg, "dodge", p.values.dodge)
local p2 = E.player("Mage", 100, (E.build("Mage", 100, PLANS.Mage)))
print("Mage 100 crit", p2.values.critChance, "critDmg", p2.values.critDmg, "maxMana", p2.values.maxMana, "manaRegen", p2.values.manaRegen)

print("\n== Cleave bleed stacking check (Warrior 100, 60 s single dummy): max stacks seen")
local wr = E.build("Warrior", 100, PLANS.Warrior)
local f = E.fight({ classId = "Warrior", L = 100, ranks = wr, targets = { B.monster(B.GENERIC, 100) }, dummy = true, seconds = 60 })
for k, v in f.maxStacks do print(k, v) end
local cl = SkillData.get("cleave")
print("cleave cooldown", Skills.scaled(cl, cl.cooldown, 10), "bleed duration", cl.effects[1].duration)

print("\n== Renew breakpoint 5: total heal and duration by rank (magAtk x heal%)")
local rn = SkillData.get("renew")
for _, r in { 4, 5, 9, 10 } do
	local def = Skills.effective(rn, r)
	local d = Skills.scaled(def, def.duration, r)
	local h = Skills.valueAt(def, "heal", r)
	print(fmt("rank %d: %.0f%% over %.0f s = %.1f%%/s", r, h, d, h / d))
end

print("\n== Meteor Storm hit chance on a target at the aim point (storm impacts)")
local ms = SkillData.get("meteorStorm")
for _, r in { 9, 10 } do
	local def = Skills.effective(ms, r)
	local R = def.radius
	local ir = math.max(4, R / 3)
	print(fmt("rank %d radius %d impact r %.2f hit chance %.0f%% hits %d expected %.1f impacts", r, R, ir, math.min(1, (ir + 1.5) / (R - ir)) * 100, def.hits, def.hits * math.min(1, (ir + 1.5) / (R - ir))))
end

print("\n== Heal per cast vs tank HP (Cleric heal skill at rank cap, devotion at cap; tank = Warrior)")
for _, L in { 20, 45, 70, 100 } do
	local ranks = { heal = E.rankCap(SkillData.get("heal"), L), devotion = E.rankCap(SkillData.get("devotion"), L) }
	local c = E.player("Cleric", L, ranks)
	local w = B.player("Warrior", L)
	local hs = SkillData.get("heal")
	local amount = c.values.magAtk * Skills.valueAt(hs, "heal", ranks.heal) / 100 * (1 + (c.hooks.healBonus or 0) / 100)
	local m = B.monster(B.GENERIC, L)
	local hitOnTank = B.hit(m, w)
	print(fmt("L%d heal r%d devotion r%d magAtk %.0f -> heal %.0f = %.0f%% of tank HP %d = %.1f monster hits on the tank (hit %.0f)", L, ranks.heal, ranks.devotion, c.values.magAtk, amount, amount / w.values.maxHp * 100, w.values.maxHp, amount / hitOnTank, hitOnTank))
end
