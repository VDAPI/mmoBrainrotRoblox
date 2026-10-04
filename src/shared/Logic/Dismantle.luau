--!strict
-- Dismantling equipment into essences (DESIGN §7). Pure.
--   Common 1–2 dust · Uncommon 2–4 dust · Rare 1–2 shards · Epic 2–3 shards + 30 % crystal ·
--   Legendary (and Unique) 1–2 crystals + 1 Legend Core.
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
	return def ~= nil and def.category == "equipment"
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
	local rarity = item.rarity
	if rarity == Rarities.COMMON then
		add(result, "essence_dust", rng:int(1, 2))
	elseif rarity == Rarities.UNCOMMON then
		add(result, "essence_dust", rng:int(2, 4))
	elseif rarity == Rarities.RARE then
		add(result, "essence_shard", rng:int(1, 2))
	elseif rarity == Rarities.EPIC then
		add(result, "essence_shard", rng:int(2, 3))
		if rng:chance(0.3) then
			add(result, "essence_crystal", 1)
		end
	else
		add(result, "essence_crystal", rng:int(1, 2))
		add(result, "legend_core", 1)
	end
	for _, material in Dismantle.upgradeRefund(item) do
		add(result, material.id, material.n)
	end
	return result
end

-- Expected outcome text helper: { id, min, max } ranges for the preview (without the 30 % crystal).
function Dismantle.preview(item: Types.ItemInstance): { { id: string, min: number, max: number } }
	local ranges: { [number]: { { id: string, min: number, max: number } } } = {
		[Rarities.COMMON] = { { id = "essence_dust", min = 1, max = 2 } },
		[Rarities.UNCOMMON] = { { id = "essence_dust", min = 2, max = 4 } },
		[Rarities.RARE] = { { id = "essence_shard", min = 1, max = 2 } },
		[Rarities.EPIC] = { { id = "essence_shard", min = 2, max = 3 }, { id = "essence_crystal", min = 0, max = 1 } },
	}
	local list = table.clone(ranges[item.rarity] or {
		{ id = "essence_crystal", min = 1, max = 2 },
		{ id = "legend_core", min = 1, max = 1 },
	})
	for _, material in Dismantle.upgradeRefund(item) do
		table.insert(list, { id = material.id, min = material.n, max = material.n })
	end
	return list
end

return Dismantle
