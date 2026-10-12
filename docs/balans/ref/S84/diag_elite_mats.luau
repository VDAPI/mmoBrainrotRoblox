--!strict
local B = require("../tests/Balance")
local LootTables = require("../src/shared/Data/LootTables")
local E = require("./diag_econ")
print("| level | elite s/kill | elite kills/h | shards/h (drop) | dust/h | shards/h incl. transmute | h of elites for 26 shards (+4..+6 prot.) | h for 35 crystals via transmute (L45+) |")
print("| --- | --: | --: | --: | --: | --: | --: | --: |")
for _, L in { 20, 30, 45, 60, 80, 99 } do
	local cad = B.eliteCadence("Warrior", L)
	local kph = 3600 / cad
	local kind = E.kindAt(L)
	local t = LootTables.byId[kind]
	local dust, shard = 0, 0
	for _, list in { t.materials, t.variantMaterials.elite } do
		for _, m in list do
			local n = m.chance * (m.min + m.max) / 2
			if m.id == "essence_dust" then dust += n elseif m.id == "essence_shard" then shard += n end
		end
	end
	local sh = shard * kph + dust * kph / 10
	print(string.format("| %d | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %s |", L, cad, kph, shard * kph, dust * kph, sh, 26 / sh, if L >= 45 then string.format("%.1f", 35 * 8 / sh) else "-"))
end
