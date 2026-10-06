--!strict
-- Test gear set of a class at a level (S23, admin /preset): the class weapon type of its starting gear, the
-- four armour pieces of its armour weight, necklace, two rings, talisman and an off-hand the class may use
-- next to a one-handed weapon, all from the highest generated tier <= level. Pure.

local Items = require("../Data/Items")

local DevPreset = {}

local OFFHANDS = { "shield", "quiver", "orb", "tome", "relic" }

local function usable(defId: string, class: string): boolean
	local def = Items.get(defId)
	return def ~= nil and (def.classes == nil or table.find(def.classes, class) ~= nil)
end

-- Ordered list of { slot, defId } for the class at the level (slots: Items.equipmentSlots names).
function DevPreset.pick(class: string, level: number): { { slot: string, id: string } }
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
	if weaponDef then
		local id = `{weaponDef.type}_{tier}`
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
		for _, kind in OFFHANDS do
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
