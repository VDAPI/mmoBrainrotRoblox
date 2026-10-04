--!strict
-- Every item definition, by id (DESIGN §5.3). Generated equipment + materials + consumables + backpacks +
-- uniques. Data only; rolling and stats live in Logic/ItemRoll.

local Backpacks = require("@self/Backpacks")
local Bases = require("@self/Bases")
local Consumables = require("@self/Consumables")
local Generate = require("@self/Generate")
local Materials = require("@self/Materials")
local Types = require("@self/Types")
local Uniques = require("@self/Uniques")

export type ItemDef = Types.ItemDef
export type SlotGroup = Types.SlotGroup

local byId: { [string]: ItemDef } = Generate.all()

for _, list in { Materials, Consumables, Backpacks, Uniques } do
	for _, def in list do
		assert(byId[def.id] == nil, `Items: duplicate id {def.id}`)
		byId[def.id] = def
	end
end

-- Equipment slot -> slot group (ring1/ring2 share "ring").
local SLOT_GROUP: { [string]: SlotGroup } = {
	weapon = "weapon",
	offhand = "offhand",
	helmet = "helmet",
	armor = "armor",
	gloves = "gloves",
	boots = "boots",
	necklace = "necklace",
	ring1 = "ring",
	ring2 = "ring",
	talisman = "talisman",
	backpack = "backpack",
}

local EQUIPMENT_SLOTS =
	{ "weapon", "offhand", "helmet", "armor", "gloves", "boots", "necklace", "ring1", "ring2", "talisman", "backpack" }

return table.freeze({
	byId = byId,
	get = function(id: string): ItemDef?
		return byId[id]
	end,
	bases = Bases,
	generate = Generate,
	uniques = Uniques,
	slotGroup = SLOT_GROUP,
	equipmentSlots = EQUIPMENT_SLOTS,
	-- Starting gear per class (S04): weapon + chest piece of the class armour weight.
	startingGear = {
		Warrior = { "sword1h_1", "armor_heavy_1" },
		Hunter = { "bow_1", "armor_medium_1" },
		Mage = { "wand_1", "armor_light_1" },
		Cleric = { "mace1h_1", "armor_heavy_1" },
	} :: { [string]: { string } },
	startingPotions = { id = "potion_hp_1", n = 10 },
	startingBackpack = "backpack_20",
})
