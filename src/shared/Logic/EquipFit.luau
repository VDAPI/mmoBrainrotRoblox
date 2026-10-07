--!strict
-- Whether an item fits an equipment slot (S29): drag highlighting of the character window's slots and the
-- message on a drop that cannot work. EquipmentService checks the same rules and stays the authority.

local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Types = require("../Types")

local EquipFit = {}

export type Character = {
	level: number,
	class: string,
	equipment: { [string]: Types.ItemInstance }?,
}

-- "slot" (wrong slot), "level", "class", "twoHanded" (off-hand under a two-handed weapon).
export type Reason = "slot" | "level" | "class" | "twoHanded"

-- Equipment slot id ("ring1") -> slot group of the item definitions ("ring").
function EquipFit.group(slotId: string): string
	return Items.slotGroup[slotId] or slotId
end

-- Does `item` belong in `slotId` at all (ignoring level and class)?
function EquipFit.matchesSlot(item: Types.ItemInstance, slotId: string): boolean
	local def = Items.get(item.id)
	return def ~= nil and def.slot ~= nil and def.slot == EquipFit.group(slotId)
end

-- (fits, reason?, requiredLevel?) for equipping `item` into `slotId`.
function EquipFit.check(item: Types.ItemInstance, slotId: string, char: Character): (boolean, Reason?, number?)
	local def = Items.get(item.id)
	if not def or not def.slot or def.slot ~= EquipFit.group(slotId) then
		return false, "slot", nil
	end
	local required = ItemRoll.requiredLevel(item)
	if char.level < required then
		return false, "level", required
	end
	if def.classes and not table.find(def.classes, char.class) then
		return false, "class", nil
	end
	if slotId == "offhand" then
		local weapon = char.equipment and char.equipment.weapon
		local weaponDef = weapon and Items.get(weapon.id)
		if weaponDef and weaponDef.weapon and weaponDef.weapon.twoHanded then
			return false, "twoHanded", nil
		end
	end
	return true, nil, nil
end

-- Locale key (and args) of the message for a failed check.
function EquipFit.messageKey(reason: string, required: number?): (string, { [string]: any }?)
	if reason == "level" then
		return "equip.hint.level", { level = required or 0 }
	elseif reason == "class" then
		return "equip.error.class", nil
	elseif reason == "twoHanded" then
		return "equip.error.twoHanded", nil
	end
	return "equip.error.slot", nil
end

return EquipFit
