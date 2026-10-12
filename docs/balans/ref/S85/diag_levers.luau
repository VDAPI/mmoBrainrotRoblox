local E = require("./SkillEngine")
local B = require("../tests/Balance")
local FightSim = require("../src/shared/Logic/FightSim")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local PLANS = require("./diag_plans")
local fmt = string.format
local ELEMENT = { Mage = "fire" }
local HEALAT = { Cleric = 0.4 }

print("== Mage sustained single-target (60 s) and 120 s with mana costs x k")
for _, L in { 45, 70, 100 } do
	local ranks = E.build("Mage", L, PLANS.Mage)
	local m = B.monster(B.GENERIC, L)
	local base = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 120, skills = false })
	local row = {}
	for _, k in { 1, 2, 3, 4, 6 } do
		local f = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 120, weaponElement = "fire", costMul = k })
		table.insert(row, fmt("k%d x%.2f", k, f.dps / base.dps))
	end
	print(L, table.concat(row, " | "))
end

print("\n== Monster HP multiplier needed so the REAL group fight (expected sizes) lasts as long as FightSim x1.2 says")
for _, c in B.CLASSES do
	local row = {}
	for _, L in { 20, 45, 70, 100 } do
		local ranks = E.build(c, L, PLANS[c])
		local p = B.player(c, L)
		local function avg(k)
			local wsum, ws, wl = 0, 0, 0
			for n = 1, 4 do
				local members = FightSim.group(B.GENERIC, L, n)
				for _, mm in members do
					mm.maxHp *= k
				end
				local f = E.fight({ classId = c, L = L, ranks = ranks, targets = members, seconds = 600, monstersHit = true, weaponElement = ELEMENT[c], healAt = HEALAT[c] })
				local w = AreaSpawns.GROUP_SIZE_WEIGHTS[n]
				wsum += w; ws += w * f.seconds; wl += w * f.endLost
			end
			return ws / wsum, wl / wsum
		end
		local target = FightSim.expectedGroup(p, B.GENERIC, L, FightSim.SKILL_DPS).seconds
		local lo, hi = 1, 20
		for _ = 1, 25 do
			local mid = (lo + hi) / 2
			if avg(mid) < target then lo = mid else hi = mid end
		end
		local s, l = avg(lo)
		table.insert(row, fmt("L%d x%.1f (%.1fs, HP %.0f%%)", L, lo, s, l * 100))
	end
	print(c, table.concat(row, " | "))
end
