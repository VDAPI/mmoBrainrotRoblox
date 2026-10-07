--!strict
-- Dismantling equipment into essences (DESIGN §7). Pure. Outcomes per rarity in Data/Rarities `dismantle`:
--   Common 1–2 dust · Unique 2–4 dust + 25 % shard · Heroic 1–3 shards + 20 % crystal ·
--   Legendary 1–2 crystals + 1 Legend Core · Mythic 2–3 crystals + 2 Legend Cores.
-- Upgraded items also give back half of the essences spent on their upgrades (rounded down).

local Items = require("../Data/Items")
local Rarities = require("../Data/Rarities")
local Rng = require("./Rng")
local Types = require("../Types")
local Upgrade = require("./Upgrade")

local Dismantle = {}

export type Material = { id: string, n: number }

function Dismantle.canDismantle(item: Types.ItemInstance): boolean
	local def = Items.get(item.id)
	return def ~= nil and def.category == "equipment" and item.locked ~= true
end

local function add(list: { Material }, id: string, n: number)
	if n <= 0 then
		return
	end
	for _, entry in list do
		if entry.id == id then
			entry.n += n
			return
		end
	end
	table.insert(list, { id = id, n = n })
end

-- Essences refunded for the upgrade levels of an item.
function Dismantle.upgradeRefund(item: Types.ItemInstance): { Material }
	local spent: { Material } = {}
	for level = 1, item.up or 0 do
		for _, material in Upgrade.cost(item, level).materials do
			add(spent, material.id, material.n)
		end
	end
	local refund: { Material } = {}
	for _, material in spent do
		add(refund, material.id, math.floor(material.n / 2))
	end
	return refund
end

function Dismantle.roll(item: Types.ItemInstance, rng: Rng.Rng): { Material }
	local result: { Material } = {}
	for _, drop in Rarities.get(item.rarity).dismantle do
		if drop.chance == nil or rng:chance(drop.chance) then
			add(result, drop.id, rng:int(drop.min, drop.max))
		end
	end
	for _, material in Dismantle.upgradeRefund(item) do
		add(result, material.id, material.n)
	end
	return result
end

-- Expected outcome for the preview: { id, min, max } ranges; chance-based drops have min 0.
function Dismantle.preview(item: Types.ItemInstance): { { id: string, min: number, max: number } }
	local list = {}
	for _, drop in Rarities.get(item.rarity).dismantle do
		table.insert(list, { id = drop.id, min = if drop.chance then 0 else drop.min, max = drop.max })
	end
	for _, material in Dismantle.upgradeRefund(item) do
		table.insert(list, { id = material.id, min = material.n, max = material.n })
	end
	return list
end

return Dismantle
