--!strict
-- Blacksmith upgrades +0 → +9 (DESIGN §6). Pure.
--   chance(N)   = 110 − 10·N %   (N = target level: +1 100 %, +2 90 %, … +9 20 %)
--   failure     = the item drops one level (never below +0); a Scroll of Protection prevents the drop
--   cost        = gold round(ilvl × perIlvl × (N+1)^1.6) (S32: perIlvl 4 up to ilvl 20, then up to 40 at 100;
--                 Config.Upgrade) + essences: +1..+3 dust ×2N, +4..+6 shard ×N, +7..+9 crystal ×(N−5);
--                 Legendary and Mythic items (Rarities `legendCore`) also need 1 Legend Core from +7
--   each level  = +6 % base stats (Rarities.upgradeStatPerLevel)

local Config = require("../Config")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local Types = require("../Types")

local Upgrade = {}

Upgrade.MAX = 9

export type Cost = { gold: number, materials: { { id: string, n: number } } }

export type Result = {
	success: boolean,
	from: number,
	to: number,
	protected: boolean, -- the protection scroll saved the item
}

function Upgrade.chance(targetLevel: number): number
	return math.clamp(110 - 10 * targetLevel, 0, 100)
end

function Upgrade.statMultiplier(up: number): number
	return 1 + Rarities.upgradeStatPerLevel * up
end

-- Gold per item level of an upgrade (S32): Config.Upgrade.goldLow up to goldLowUntil, then linear to goldHigh.
function Upgrade.goldPerIlvl(ilvl: number): number
	local c = Config.Upgrade
	if ilvl <= c.goldLowUntil then
		return c.goldLow
	end
	local t = math.clamp((ilvl - c.goldLowUntil) / (100 - c.goldLowUntil), 0, 1)
	return c.goldLow + (c.goldHigh - c.goldLow) * t
end

function Upgrade.cost(item: Types.ItemInstance, targetLevel: number): Cost
	local n = targetLevel
	local ilvl = math.max(1, item.ilvl)
	local gold = math.floor(ilvl * Upgrade.goldPerIlvl(ilvl) * (n + 1) ^ Config.Upgrade.goldExponent + 0.5)
	local materials = {}
	if n <= 3 then
		table.insert(materials, { id = "essence_dust", n = 2 * n })
	elseif n <= 6 then
		table.insert(materials, { id = "essence_shard", n = n })
	else
		table.insert(materials, { id = "essence_crystal", n = n - 5 })
		if Rarities.get(item.rarity).legendCore then
			table.insert(materials, { id = "legend_core", n = 1 })
		end
	end
	return { gold = gold, materials = materials }
end

function Upgrade.canUpgrade(item: Types.ItemInstance): boolean
	return (item.up or 0) < Upgrade.MAX
end

-- Rolls one attempt. Does not mutate the item.
function Upgrade.attempt(item: Types.ItemInstance, useProtection: boolean, rng: Rng.Rng): Result
	local from = item.up or 0
	local target = from + 1
	if rng:next() * 100 < Upgrade.chance(target) then
		return { success = true, from = from, to = target, protected = false }
	end
	if useProtection then
		return { success = false, from = from, to = from, protected = true }
	end
	return { success = false, from = from, to = math.max(0, from - 1), protected = false }
end

return Upgrade
