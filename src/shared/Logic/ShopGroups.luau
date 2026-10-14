--!strict
-- Groups of the shop's Buy view (FIX 2026-10-14, owner: icons in rows sorted by kind, the name and stats only in
-- the tooltip). Every entry falls into one kind (weapons, off-hand, each armour piece, jewellery, potions, other
-- consumables, scrolls, stones, materials, tools, backpacks); groups come in a fixed order and keep the shop's
-- entry order inside, sorted (stably) by the level the entry asks for, so a class vendor's tiers read 5 → 95. Pure.

local Items = require("../Data/Items")
local Shops = require("../Data/Shops")

local ShopGroups = {}

-- Group ids in display order; the Buy view's header is `shop.group.<id>` (PL and EN).
ShopGroups.ORDER = table.freeze({
	"weapon",
	"offhand",
	"helmet",
	"armor",
	"gloves",
	"boots",
	"jewelry",
	"potion",
	"consumable",
	"scroll",
	"stone",
	"material",
	"tool",
	"backpack",
	"other",
})

local JEWELRY: { [string]: boolean } = { necklace = true, ring = true, talisman = true }
local SLOT_GROUPS: { [string]: boolean } =
	{ weapon = true, offhand = true, helmet = true, armor = true, gloves = true, boots = true }

-- Group id of an item definition (nil definition: "other").
function ShopGroups.of(def: Items.ItemDef?): string
	if not def then
		return "other"
	end
	local slot = def.slot
	if slot and SLOT_GROUPS[slot] then
		return slot
	elseif slot and JEWELRY[slot] then
		return "jewelry"
	elseif def.category == "backpack" or slot == "backpack" then
		return "backpack"
	elseif def.category == "consumable" then
		local use = def.use
		return if use and use.kind == "potion" then "potion" else "consumable"
	elseif def.category == "scroll" or def.category == "stone" or def.category == "material" then
		return def.category
	elseif def.category == "tool" then
		return "tool"
	end
	return "other"
end

-- Level an entry asks for (the entry's own, else the item's).
local function levelOf(entry: Shops.Entry, def: Items.ItemDef?): number
	return entry.level or (if def then def.level else 0)
end

export type Group = { id: string, entries: { Shops.Entry } }

-- The entries in groups (only non-empty ones, in ORDER).
function ShopGroups.group(entries: { Shops.Entry }): { Group }
	local byGroup: { [string]: { { entry: Shops.Entry, index: number, level: number } } } = {}
	for index, entry in entries do
		local def = Items.get(entry.item)
		local id = ShopGroups.of(def)
		local list = byGroup[id]
		if not list then
			list = {}
			byGroup[id] = list
		end
		table.insert(list, { entry = entry, index = index, level = levelOf(entry, def) })
	end
	local out: { Group } = {}
	for _, id in ShopGroups.ORDER do
		local list = byGroup[id]
		if not list then
			continue
		end
		table.sort(list, function(a, b)
			if a.level ~= b.level then
				return a.level < b.level
			end
			return a.index < b.index
		end)
		local group: Group = { id = id, entries = {} }
		for _, row in list do
			table.insert(group.entries, row.entry)
		end
		table.insert(out, group)
	end
	return out
end

return ShopGroups
