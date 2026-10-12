--!strict
-- How many levels a set of rarity R and ilvl X stays at least as strong as a set of rarity R2 at the player's level - 2.
local B = require("../tests/Balance")
local names = { "Common", "Unique", "Heroic", "Legendary", "Mythic" }
print("| class | set | ilvl | = Common@L-2 until L | = Unique@L-2 until L | = Heroic@L-2 until L |")
print("| --- | --- | --: | --: | --: | --: |")
for _, c in { "Warrior", "Mage" } do
	for _, r in { 3, 4, 5 } do
		for _, X in { 20, 45, 70 } do
			local cells = { c, names[r], tostring(X) }
			for _, r2 in { 1, 2, 3 } do
				local last = X
				for L = X + 2, 100 do
					local old = B.power(B.player(c, L, { ilvl = X, rarity = r }))
					local new = B.power(B.player(c, L, { ilvl = L - 2, rarity = r2 }))
					if old >= new then
						last = L
					else
						break
					end
				end
				table.insert(cells, tostring(last) .. ` (+{last - X})`)
			end
			print("| " .. table.concat(cells, " | ") .. " |")
		end
	end
end
