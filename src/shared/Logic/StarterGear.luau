--!strict
-- Starting equipment (S04): class weapon + chest piece (equipped, bound), the cloth backpack and
-- 10 small health potions on the potion bar. Used by CharacterFactory and by the schema-2 migration for
-- characters created before items existed. Pure; uids injected.

local ItemRoll = require("./ItemRoll")
local Items = require("../Data/Items")
local Rng = require("./Rng")
local Types = require("../Types")

local StarterGear = {}

-- Fills empty equipment slots, adds the potions to the first free slot and sets the potion bar.
-- Never replaces anything the character already has. Mutates `character`.
function StarterGear.apply(character: Types.CharacterData, newId: () -> string)
	local rng = Rng.new(1) -- common items roll no bonuses; the seed does not matter
	local equipment = character.equipment
	if equipment.backpack == nil then
		equipment.backpack = ItemRoll.makeStack(Items.startingBackpack, 1, newId())
	end
	local gear: { string } = Items.startingGear[character.class] or {}
	for _, defId in gear do
		local def = Items.get(defId)
		local slot = def and def.slot
		if def and slot and equipment[slot] == nil then
			local item = ItemRoll.rollItem(defId, def.level, 1, rng, newId())
			item.bound = true -- equipped items are bound (DESIGN §5.6)
			equipment[slot] = item
		end
	end
	local potions = Items.startingPotions
	local capacity = 20
	local backpack = equipment.backpack
	local backpackDef = backpack and Items.get(backpack.id)
	if backpackDef and backpackDef.capacity then
		capacity = backpackDef.capacity
	end
	for i = 1, capacity do
		local key = tostring(i)
		if character.inventory[key] == nil then
			character.inventory[key] = ItemRoll.makeStack(potions.id, potions.n, newId())
			break
		end
	end
	if character.potionBar.hp == nil then
		character.potionBar.hp = potions.id
	end
end

return StarterGear
