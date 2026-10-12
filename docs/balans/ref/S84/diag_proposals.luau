--!strict
-- Proposal checks for the 20-100 item report. Nothing on disk is changed: module functions are swapped in memory
-- (ItemRoll.bonusRange, Upgrade.goldPerIlvl), the files keep their values. lune run tools/diag_proposals.luau [x]

local process = require("@lune/process")

local B = require("../tests/Balance")
local Bonuses = require("../src/shared/Data/Bonuses")
local E = require("./diag_econ")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Rarities = require("../src/shared/Data/Rarities")
local Upgrade = require("../src/shared/Logic/Upgrade")

local only = process.args[1]
local function want(n: string): boolean
	return only == nil or only == n
end
local function pct(x: number): string
	return string.format("%+.1f%%", x * 100)
end
local function f2(x: number): string
	return string.format("%.2f", x)
end
local function header(cols: { string })
	print("| " .. table.concat(cols, " | ") .. " |")
	local sep = {}
	for i = 1, #cols do
		sep[i] = if i == 1 then "---" else "--:"
	end
	print("| " .. table.concat(sep, " | ") .. " |")
end
local function row(cells: { string })
	print("| " .. table.concat(cells, " | ") .. " |")
end

local originalRange = ItemRoll.bonusRange

-- pct scaling replacement: `scale(ilvl)` instead of 1 + ilvl / 60 for bonuses with scaling "pct".
local function withPct(scale: ((number) -> number)?, fn: () -> ())
	if scale then
		(ItemRoll :: any).bonusRange = function(bonusId: string, ilvl: number, rarity: number): (number, number)
			local def = Bonuses.get(bonusId) :: Bonuses.BonusDef
			if def.scaling ~= "pct" then
				return originalRange(bonusId, ilvl, rarity)
			end
			local rangeMul = Rarities.get(rarity).rangeMul
			local s = scale(ilvl) * rangeMul
			return def.min * s, def.max * s
		end
	end
	fn()
	;(ItemRoll :: any).bonusRange = originalRange
end

if want("pct") then
	print("\n## P1. Rarity gain with a different 'pct' bonus scaling (ItemRoll.scaleFor)\n")
	local variants: { any } = {
		{ "now: 1 + ilvl/60", nil },
		{ "cap: 1 + min(ilvl,20)/60", function(l: number): number
			return 1 + math.min(l, 20) / 60
		end },
		{ "slope/4 above 20: 1.333 + (ilvl-20)/240", function(l: number): number
			return if l <= 20 then 1 + l / 60 else 1 + 20 / 60 + (l - 20) / 240
		end },
	}
	for _, v in variants do
		print(`\n### {v[1]}\n`)
		header({ "class", "Unique 20/60/100", "Heroic 20/60/100", "Legendary 20/60/100", "Mythic 20/60/100", "Legendary 5/10" })
		withPct(v[2], function()
			for _, c in B.CLASSES do
				local cells = { c }
				for _, r in { 2, 3, 4, 5 } do
					local parts = {}
					for _, L in { 20, 60, 100 } do
						table.insert(parts, pct(B.rarityGain(c, L, r)))
					end
					table.insert(cells, table.concat(parts, " / "))
				end
				table.insert(cells, `{pct(B.rarityGain(c, 5, 4))} / {pct(B.rarityGain(c, 10, 4))}`)
				row(cells)
			end
		end)
	end
end

if want("twohand") then
	print("\n## P2. Two-handed weapons at higher rarities: DPS x eHP vs 1H + off-hand of the same rarity\n")
	local cases = { { "Warrior", "sword2h" }, { "Warrior", "hammer2h" }, { "Mage", "staff" }, { "Mage", "runestaff" }, { "Cleric", "holystaff" } }
	header({ "weapon", "rarity", "now 20", "now 60", "now 100", "2H bonus x2: 20", "60", "100", "2H bonus x1.5: 100", "base only 100" })
	for _, case in cases do
		local c, w = case[1], case[2]
		for _, r in { 1, 2, 3, 4, 5 } do
			local cells = { `{c} {w}`, Rarities.get(r).key }
			local function ratio(L: number, mul: number, bonuses: boolean?): number
				local base = B.power(B.player(c, L, { rarity = r, bonuses = bonuses })) ^ 2
				local items = B.gear(c, L, { weapon = w, offhand = false, rarity = r, bonuses = bonuses })
				local weapon = table.clone(items[1])
				local scaled = {}
				for _, b in weapon.bonuses do
					table.insert(scaled, { stat = b.stat, v = b.v * mul })
				end
				weapon.bonuses = scaled
				items[1] = weapon
				return B.power(B.playerFromItems(c, L, items)) ^ 2 / base
			end
			for _, L in { 20, 60, 100 } do
				table.insert(cells, f2(ratio(L, 1)))
			end
			for _, L in { 20, 60, 100 } do
				table.insert(cells, f2(ratio(L, 2)))
			end
			table.insert(cells, f2(ratio(100, 1.5)))
			table.insert(cells, f2(ratio(100, 1, false)))
			row(cells)
		end
	end
end

if want("upgrade") then
	print("\n## P3. Upgrade gold with another Config.Upgrade.goldHigh (k at ilvl 100), weapon ilvl = level - 2\n")
	local original = Upgrade.goldPerIlvl
	header({ "goldHigh", "+1..+3/income @25", "@30", "@45", "@60", "@80", "@100", "+1..+9 prot./income @45", "@70", "@100" })
	for _, high in { 40, 30, 25, 20, 16 } do
		(Upgrade :: any).goldPerIlvl = function(ilvl: number): number
			if ilvl <= 20 then
				return 4
			end
			local t = math.clamp((ilvl - 20) / 80, 0, 1)
			return 4 + (high - 4) * t
		end
		local cells = { tostring(high) }
		for _, L in { 25, 30, 45, 60, 80, 100 } do
			local inc = E.pace("Warrior", math.min(L, 99)).income
			table.insert(cells, f2(B.upgradeGold(L - 2, 3) / inc))
		end
		for _, L in { 45, 70, 100 } do
			local inc = E.pace("Warrior", math.min(L, 99)).income
			table.insert(cells, f2(B.upgradeGold(L - 2, 9) / inc))
		end
		row(cells)
	end
	;(Upgrade :: any).goldPerIlvl = original
end

return nil
