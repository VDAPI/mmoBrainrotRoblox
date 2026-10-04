--!strict
-- Builds new characters and character summaries (pure). Ids are injected so tests stay deterministic.

local Classes = require("../Data/Classes")
local Config = require("../Config")
local Types = require("../Types")
local AccountSchema = require("./AccountSchema")

type CharacterData = Types.CharacterData

local CharacterFactory = {}

export type Ids = {
	newId: () -> string,
	now: number,
}

local function makeItem(id: string, uid: string): Types.ItemInstance
	return {
		uid = uid,
		id = id,
		rarity = 1,
		ilvl = 1,
		bonuses = {},
		up = 0,
		bound = false,
		n = 1,
	}
end

function CharacterFactory.create(classId: Types.ClassId, name: string, ids: Ids): CharacterData
	local class = Classes.get(classId)
	assert(class, `CharacterFactory: unknown class {classId}`)

	local character = AccountSchema.characterTemplate()
	character.id = ids.newId()
	character.name = name
	character.class = classId
	character.level = 1
	character.stats = table.clone(class.startStats)
	character.gold = Config.StartingGold
	character.location = { map = Config.StartingMap, x = 0, y = 0, z = 0 }
	character.equipment = {
		backpack = makeItem(Config.StartingBackpackId, ids.newId()),
	}
	character.createdAt = ids.now
	return character
end

function CharacterFactory.summary(character: CharacterData): Types.SlotSummary
	return {
		name = character.name,
		class = character.class,
		level = character.level,
		map = character.location.map,
	}
end

function CharacterFactory.summaries(characters: { [string]: CharacterData }): { [string]: Types.SlotSummary }
	local result = {}
	for slot, character in characters do
		result[slot] = CharacterFactory.summary(character)
	end
	return result
end

-- Slot keys are "1".."MaxCharacters". Returns nil for anything else.
function CharacterFactory.slotKey(slot: any): string?
	if type(slot) ~= "number" or slot ~= math.floor(slot) then
		return nil
	end
	if slot < 1 or slot > Config.MaxCharacters then
		return nil
	end
	return tostring(slot)
end

return CharacterFactory
