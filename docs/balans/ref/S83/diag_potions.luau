--!strict
-- Solo Elite II / Elite pair with potions (Config.PotionCooldown 1.5 s, flat heals): potions and gold to win
-- (heal everything above 80 % of max HP lost), vs the gold of the kill.
local B = require("../tests/Balance")
local Items = require("../src/shared/Data/Items")
local Monsters = require("../src/shared/Data/Monsters")
local FightSim = require("../src/shared/Logic/FightSim")
local Spawns = require("../src/shared/Data/Spawns")

local potions = {}
for q = 1, 5 do
	local d = Items.get(`potion_hp_{q}`) :: any
	table.insert(potions, { q = q, heal = d.use.amount, price = d.buyPrice })
end
local function cost(hp: number): (number, number, number)
	local best, bestN, bestQ = math.huge, 0, 0
	for _, p in potions do
		local n = math.ceil(hp / p.heal)
		if n * p.price < best then
			best, bestN, bestQ = n * p.price, n, p.q
		end
	end
	return best, bestN, bestQ
end

print("| cave · kind · spawner L | solo Warrior HP lost | fight s | HP to heal | potions (quality) | potion gold | potions per s needed | kill gold (solo) |")
print("| --- | --: | --: | --: | --: | --: | --: | --: |")
for _, caveId in { "meadows_cave", "duskwood_den", "duskwood_barrow", "duskwood_cave", "ashen_mine", "ashen_lair", "ashen_cave", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" } do
	for _, s in Spawns.byMap[caveId] do
		if s.variant == "elite2" then
			for _, kind in (s :: any).choices do
				local L = s.level.max
				local pl = math.min(100, L + 2)
				local w = B.player("Warrior", pl)
				local f = B.elite2({ w }, kind, L)
				local heal = math.max(0, f.hpLost - 0.8) * w.values.maxHp
				local gold, n, q = cost(heal)
				local killGold = B.killGold(pl, kind, L + 4, "elite2")
				print(string.format("| %s · %s · %d | %d%% | %.0f | %d | %d (q%d) | %d | %.2f | %d |", caveId, kind, L, f.hpLost * 100 + 0.5, f.seconds, heal, n, q, gold, n / f.seconds, killGold))
			end
		end
	end
end
print("")
print("Elite pairs, solo (spawner = player level, max level of the spawner):")
print("| cave · kind · L | Warrior pair HP | Mage pair HP | Mage potions to heal (quality) | potion gold | kill gold (2 elites) |")
print("| --- | --: | --: | --: | --: | --: |")
for _, caveId in { "duskwood_den", "duskwood_barrow", "duskwood_cave", "ashen_mine", "ashen_lair", "ashen_cave", "frostpeak_grotto", "frostpeak_hold", "frostpeak_cave" } do
	local seen = {}
	for _, s in Spawns.byMap[caveId] do
		if s.variant == "elite" and s.count == 2 and not seen[s.monster] then
			seen[s.monster] = true
			local L = s.level.max
			local def = Monsters.get(s.monster)
			local w, m = B.player("Warrior", math.min(100, L)), B.player("Mage", math.min(100, L))
			local fw = FightSim.groupFight(w :: any, FightSim.group(def, L, 2, "elite"), B.SKILL_DPS)
			local fm = FightSim.groupFight(m :: any, FightSim.group(def, L, 2, "elite"), B.SKILL_DPS)
			local heal = math.max(0, fm.hpLost - 0.8) * m.values.maxHp
			local gold, n, q = cost(heal)
			print(string.format("| %s · %s · %d | %d%% | %d%% | %d (q%d) | %d | %d |", caveId, s.monster, L, fw.hpLost * 100 + 0.5, fm.hpLost * 100 + 0.5, n, q, gold, 2 * B.killGold(L, def, L + 2, "elite")))
		end
	end
end
