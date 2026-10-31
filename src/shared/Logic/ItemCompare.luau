--!strict
-- The comparison inside the item tooltip (owner 2026-10-31: "under the item you point at show the stats to compare, not
-- the one you wear"). The hovered item's own tooltip writes the change of every number it shows next to the value
-- (TooltipModel, ctx.compare); the second panel with the worn item is gone. This module says what equipping the item
-- would take off (`replaced`, the same choice as the equip action and the "Better item" card) and sums those items
-- into the numbers the tooltip compares with (`worn`). Pure, tested in tests/itemcompare.spec.
--
-- Rules: only an item of the character's class (not an off-hand under a two-hander) is compared, and never a worn one;
-- nothing worn in the slot = nothing to compare. 2026-10-31 (Studio check): a too high level is still compared (the
-- level in the head line is red), so a find for later shows what it will give. Rings: the weaker ring by ItemScore (nil while a ring
-- slot is free, the new ring goes there); a two-hander also takes the off-hand. Backpacks compare their capacity.

local ItemRoll = require("./ItemRoll")
local ItemScore = require("./ItemScore")
local Items = require("../Data/Items")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

-- The numbers of what the equip takes off: the weapon's damage, speed and DPS (the first replaced weapon), base stats
-- and line values summed over every replaced item (lines by id, in the order the items list them).
export type Worn = {
	items: { ItemInstance },
	weapon: { dmg: number, mdmg: number, speed: number, dps: number }?,
	base: { [string]: number },
	lines: { [string]: { number } },
	lineOrder: { string }, -- the ids of `lines` in the order they first appear
	ilvl: number,
	capacity: number?,
}

local ItemCompare = {}

local function isTwoHanded(item: ItemInstance?): boolean
	if not item then
		return false
	end
	local weapon = ItemRoll.itemStats(item).weapon
	return weapon ~= nil and weapon.twoHanded
end

-- True when `item` is compared for this character: equipment of its class (EquipmentService rules without the level
-- and the backpack fit), never an off-hand while a two-hander is worn.
function ItemCompare.comparable(item: ItemInstance, equipment: { [string]: any }, context: ItemScore.Context): boolean
	local def = Items.get(item.id)
	if not def or not def.slot then
		return false
	end
	if def.classes and not table.find(def.classes, context.classId) then
		return false
	end
	if def.slot == "offhand" and isTwoHanded(equipment.weapon) then
		return false
	end
	return true
end

-- The equipment slot the equip action fills when the player names none: a ring goes to the free ring slot, with both
-- worn it replaces the weaker one (ItemScore.replaced); nil for every other item (its slot group).
function ItemCompare.targetSlot(def: Items.ItemDef, equipment: { [string]: any }, context: ItemScore.Context): string?
	if def.slot ~= "ring" then
		return nil
	end
	local weaker = ItemScore.replaced(def, equipment, context)
	if not weaker then
		return nil
	end
	return if equipment.ring2 and equipment.ring2.uid == weaker.uid then "ring2" else "ring1"
end

-- What equipping `item` takes off (main slot first, a two-hander then the off-hand); nil when the item is not compared:
-- another class, an off-hand under a two-hander, a worn item, or nothing it would replace is worn.
function ItemCompare.replaced(
	item: ItemInstance,
	equipment: { [string]: any },
	context: ItemScore.Context
): { ItemInstance }?
	local def = Items.get(item.id)
	if not def or not def.slot or not ItemCompare.comparable(item, equipment, context) then
		return nil
	end
	for _, worn in equipment do
		if type(worn) == "table" and worn.uid == item.uid then
			return nil
		end
	end
	local out: { ItemInstance } = {}
	local main = if def.slot == "backpack" then equipment.backpack else ItemScore.replaced(def, equipment, context)
	if main then
		table.insert(out, main)
	end
	if def.slot == "weapon" and equipment.offhand and isTwoHanded(item) then
		table.insert(out, equipment.offhand)
	end
	return if #out > 0 then out else nil
end

-- The summed numbers of `items` (see Worn).
function ItemCompare.worn(items: { ItemInstance }): Worn
	local out: Worn = { items = items, weapon = nil, base = {}, lines = {}, lineOrder = {}, ilvl = 0, capacity = nil }
	for index, item in items do
		local def = Items.get(item.id)
		if index == 1 then
			out.ilvl = item.ilvl
			if def and def.category == "backpack" then
				out.capacity = def.capacity or 0
			end
		end
		local stats = ItemRoll.itemStats(item)
		local w = stats.weapon
		if w and not out.weapon then
			out.weapon = { dmg = w.dmg, mdmg = w.mdmg, speed = w.speed, dps = math.max(w.dmg, w.mdmg) * w.speed }
		end
		for stat, value in stats.base do
			out.base[stat] = (out.base[stat] or 0) + value
		end
		for _, line in stats.bonuses do
			local list = out.lines[line.id]
			if not list then
				list = {}
				out.lines[line.id] = list
				table.insert(out.lineOrder, line.id)
			end
			table.insert(list, line.v)
		end
	end
	return out
end

-- The change shown next to a value: `value` minus the worn one, rounded to the places the tooltip writes (so 1.2 - 1.1
-- is 0.1, never 0.09999...); 0 = the same.
function ItemCompare.change(value: number, worn: number, places: number): number
	local scale = 10 ^ places
	local d = math.floor((value - worn) * scale + 0.5) / scale
	return if d == 0 then 0 else d
end

return ItemCompare
