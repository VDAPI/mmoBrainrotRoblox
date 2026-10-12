-- Torrent check (rozwoj/mag.md 3.2): Arkanista boss DPS with and without the Torrent, x base and x Niszczyciel. Not game code.
local E = require("./SkillEngineMag")
local B = require("../tests/Balance")
local M = require("./diag_mag_lib")
local fmt = string.format
local BASE_B = { firebolt = "bb", fireball = "ab", iceShard = "bb", chainLightning = "bb", frostNova = "ab", firewall = "bb", meteor = "ba" }
local N_BOSS = table.clone(BASE_B)
N_BOSS.meteorStorm, N_BOSS.elementalVortex, N_BOSS.cataclysm = "bb", "ba", "bb"
local ORDER_A = M.ORDER_A
if (_G :: any).DROP then
	ORDER_A = {}
	for _, id in M.ORDER_A do
		if not table.find((_G :: any).DROP, id) then table.insert(ORDER_A, id) end
	end
end
local function run(L, order, main, choices, gear, strip, free)
	local s, tor, tot, dem = 0, 0, 0, 0
	for _, el in { "fire", "ice", "lightning" } do
		local ranks, mage = M.buildWith(order, main, L, choices)
		if strip then
			for id in ranks do if string.find(id, "arcaneTorrent") then ranks[id] = nil end end
		end
		local m = B.monster(B.GENERIC, L)
		local f = E.fight({ classId = "Mage", L = L, ranks = ranks, targets = { m }, dummy = true, seconds = 180, weaponElement = el, gearOpts = gear, costMul = M.costMul(L), mage = mage, freeMana = free })
		s += f.dps / 3
		for id, v in f.by do
			tot += v
			if string.find(id, "arcaneTorrent") then tor += v end
		end
		if free then dem += f.spent / 180 / (f.regen + f.gain) / 3 end
	end
	return s, tor / tot, dem
end
for _, L in (_G :: any).LEVELS or { 45, 70, 100 } do
	local base = run(L, M.ORDER_BASE, "none", BASE_B, M.STAFF)
	local n = run(L, M.ORDER_D_THRIFT, "d", N_BOSS, M.STAFF)
	local a, share = run(L, ORDER_A, "a", M.CHOICE_A, M.RUNE)
	local a0 = run(L, ORDER_A, "a", M.CHOICE_A, M.RUNE, true)
	local af, _, dem = run(L, ORDER_A, "a", M.CHOICE_A, M.RUNE, false, true)
	local af0 = run(L, ORDER_A, "a", M.CHOICE_A, M.RUNE, true, true)
	print(fmt("L%d A x%.2f (bez Strumienia x%.2f) A/N(boss) %.2f | Strumień %.0f%% obrażeń, zysk z nim x%.2f (bez limitu many x%.2f) | mana %.2f",
		L, a / base, a0 / base, a / n, share * 100, a / a0, af / af0, dem))
end
