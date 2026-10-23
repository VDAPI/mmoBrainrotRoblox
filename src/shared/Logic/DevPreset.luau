--!strict
-- Test gear set of a class at a level (S23, admin /preset): the class weapon type of its starting gear, the
-- four armour pieces of its armour weight, necklace, two rings, talisman and an off-hand the class may use
-- next to a one-handed weapon, all from the highest generated tier <= level. Pure. `prefer` (dev panel best grants):
-- the weapon / off-hand types the character uses now, kept when the class may use them.

local Items = require("../Data/Items")

local DevPreset = {}

local OFFHANDS = { "shield", "quiver", "orb", "tome", "relic" }

local function usable(defId: string, class: string): boolean
	local def = Items.get(defId)
	return def ~= nil and (def.classes == nil or table.find(def.classes, class) ~= nil)
end

export type Prefer = { weapon: string?, offhand: string? }

-- Ordered list of { slot, defId } for the class at the level (slots: Items.equipmentSlots names).
function DevPreset.pick(class: string, level: number, prefer: Prefer?): { { slot: string, id: string } }
	local tier = Items.generate.tierFor(level)
	local starting = Items.startingGear[class]
	if not starting then
		return {}
	end
	local weaponDef = Items.get(starting[1])
	local chestDef = Items.get(starting[2])
	local out: { { slot: string, id: string } } = {}
	local function add(slot: string, id: string)
		if usable(id, class) then
			table.insert(out, { slot = slot, id = id })
		end
	end
	local twoHanded = false
	local weaponType = if weaponDef then weaponDef.type else nil
	if prefer and prefer.weapon and usable(`{prefer.weapon}_{tier}`, class) then
		weaponType = prefer.weapon
	end
	if weaponType then
		local id = `{weaponType}_{tier}`
		add("weapon", id)
		local def = Items.get(id)
		twoHanded = def ~= nil and def.weapon ~= nil and def.weapon.twoHanded == true
	end
	local weight = if chestDef then string.match(chestDef.type, "^armor_(%a+)$") else nil
	if weight then
		for _, slot in { "helmet", "armor", "gloves", "boots" } do
			add(slot, `{slot}_{weight}_{tier}`)
		end
	end
	add("necklace", `necklace_{tier}`)
	add("ring1", `ring_{tier}`)
	add("ring2", `ring_{tier}`)
	add("talisman", `talisman_{tier}`)
	if not twoHanded then
		local kinds = OFFHANDS
		if prefer and prefer.offhand and usable(`{prefer.offhand}_{tier}`, class) then
			kinds = { prefer.offhand }
		end
		for _, kind in kinds do
			local id = `{kind}_{tier}`
			if usable(id, class) then
				table.insert(out, { slot = "offhand", id = id })
				break
			end
		end
	end
	return out
end

return DevPreset
