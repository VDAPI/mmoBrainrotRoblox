--!strict
local B = require("../tests/Balance")
local LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }
local function pct(x: number): string
	return string.format("%+.1f%%", x * 100)
end
local function mark(x: number, lo: number, hi: number): string
	local s = pct(x)
	if x < lo or x > hi then
		return `**{s}**`
	end
	return s
end
for _, pair in { { 2, 3, "Unique (target +8-15%) / Heroic (target +15-25%)" }, { 4, 5, "Legendary (target +25-40%) / Mythic (above Legendary)" } } do
	print(`\n{pair[3]}\n`)
	print("| level | War " .. (if pair[1] == 2 then "U" else "L") .. " | War " .. (if pair[2] == 3 then "H" else "M") .. " | Hun " .. (if pair[1] == 2 then "U" else "L") .. " | Hun " .. (if pair[2] == 3 then "H" else "M") .. " | Mag " .. (if pair[1] == 2 then "U" else "L") .. " | Mag " .. (if pair[2] == 3 then "H" else "M") .. " | Cle " .. (if pair[1] == 2 then "U" else "L") .. " | Cle " .. (if pair[2] == 3 then "H" else "M") .. " |")
	print("| --- | --: | --: | --: | --: | --: | --: | --: | --: |")
	for _, L in LEVELS do
		local cells = { tostring(L) }
		for _, c in B.CLASSES do
			local a = B.rarityGain(c, L, pair[1] :: number)
			local b = B.rarityGain(c, L, pair[2] :: number)
			if pair[1] == 2 then
				table.insert(cells, mark(a, 0.08, 0.15))
				table.insert(cells, mark(b, 0.15, 0.25))
			else
				table.insert(cells, mark(a, 0.25, 0.40))
				table.insert(cells, pct(b))
			end
		end
		print("| " .. table.concat(cells, " | ") .. " |")
	end
end
