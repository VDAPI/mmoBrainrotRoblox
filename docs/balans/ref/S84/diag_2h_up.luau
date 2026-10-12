--!strict
-- 2H vs 1H + off-hand when everything is +9: what per-level upgrade share would the 2H weapon need?
local B = require("../tests/Balance")
local Bonuses = require("../src/shared/Data/Bonuses")
local cases = { { "Warrior", "sword2h" }, { "Warrior", "spear2h" }, { "Mage", "staff" }, { "Mage", "runestaff" }, { "Cleric", "holystaff" } }
print("| weapon | rarity | +9, bonus x1.75 | +9, 2H 7%/lvl + bonus x1.75 |")
print("| --- | --- | --: | --: |")
for _, case in cases do
	local c, w = case[1], case[2]
	for _, r in { 1, 3, 4, 5 } do
		local cells = { `{c} {w}`, tostring(r) }
		for _, spec in { { 9, 1.75 }, { 10.5, 1.75 } } do
			local parts = {}
			for _, L in { 20, 60, 100 } do
				local base = B.power(B.player(c, L, { rarity = r, up = 9 })) ^ 2
				local items = B.gear(c, L, { weapon = w, offhand = false, rarity = r, up = 9 })
				local weapon = table.clone(items[1])
				weapon.up = spec[1]
				local scaled = {}
				for _, b in weapon.bonuses do
					local def = Bonuses.get(b.stat) :: any
					table.insert(scaled, { stat = b.stat, v = if def.scaling ~= "none" then b.v * spec[2] else b.v })
				end
				weapon.bonuses = scaled
				items[1] = weapon
				table.insert(parts, string.format("%.2f", B.power(B.playerFromItems(c, L, items)) ^ 2 / base))
			end
			table.insert(cells, table.concat(parts, " / "))
		end
		print("| " .. table.concat(cells, " | ") .. " |")
	end
end
