--!strict
local B = require("../tests/Balance")
local Bonuses = require("../src/shared/Data/Bonuses")
local cases = { { "Warrior", "sword2h" }, { "Warrior", "spear2h" }, { "Mage", "staff" }, { "Mage", "runestaff" }, { "Cleric", "holystaff" } }
print("| weapon | rarity | x1.5 @20 | @60 | @100 | x1.75 @20 | @60 | @100 | x2 @20 | @60 | @100 |")
print("| --- | --- | --: | --: | --: | --: | --: | --: | --: | --: | --: |")
for _, case in cases do
	local c, w = case[1], case[2]
	for _, r in { 2, 3, 4, 5 } do
		local cells = { `{c} {w}`, tostring(r) }
		for _, mul in { 1.5, 1.75, 2 } do
			for _, L in { 20, 60, 100 } do
				local base = B.power(B.player(c, L, { rarity = r })) ^ 2
				local items = B.gear(c, L, { weapon = w, offhand = false, rarity = r })
				local weapon = table.clone(items[1])
				local scaled = {}
				for _, b in weapon.bonuses do
					local def = Bonuses.get(b.stat) :: any
					local regular = def.scaling ~= "none" -- legendary pool lines use scaling "none"
					table.insert(scaled, { stat = b.stat, v = if regular then b.v * mul else b.v })
				end
				weapon.bonuses = scaled
				items[1] = weapon
				table.insert(cells, string.format("%.2f", B.power(B.playerFromItems(c, L, items)) ^ 2 / base))
			end
		end
		print("| " .. table.concat(cells, " | ") .. " |")
	end
end
