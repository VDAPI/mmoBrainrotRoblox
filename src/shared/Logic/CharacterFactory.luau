--!strict
-- Builds new characters and character summaries (pure). Ids are injected so tests stay deterministic.

local Classes = require("../Data/Classes")
local Config = require("../Config")
local Types = require("../Types")
local AccountSchema = require("./AccountSchema")
local CharacterLook = require("./CharacterLook")
local SkillPools = require("./SkillPools")
local Skills = require("./Skills")
local StarterGear = require("./StarterGear")
local Tutorial = require("./Tutorial")

type CharacterData = Types.CharacterData

local CharacterFactory = {}

export type Ids = {
	newId: () -> string,
	now: number,
}

-- S132: `look` = the creator's face, skin and hair (unknown ids fall back to the default ones, CharacterLook.normalize).
function CharacterFactory.create(classId: Types.ClassId, name: string, ids: Ids, look: any?): CharacterData
	local class = Classes.get(classId)
	assert(class, `CharacterFactory: unknown class {classId}`)

	local character = AccountSchema.characterTemplate()
	character.id = ids.newId()
	character.name = name
	character.class = classId
	character.level = 1
	character.stats = table.clone(class.startStats)
	-- S137 (DESIGN-18 §10): the point of level 1 is spent on the class's first skill (S1) in the default pool, on slot 1
	local first = Skills.startingSkill(classId)
	local pool = SkillPools.defaultPool(classId) or ""
	character.ranks = if first and pool ~= "" then { [pool] = { [first] = 1 } } else {}
	character.hotbar = if first then { ["1"] = first } else {}
	character.bars = {}
	character.barPool = pool
	character.respecFree = false
	character.poolsVersion = SkillPools.version(classId)
	character.reworkNotice = false
	character.gold = Config.StartingGold
	character.location = { map = Config.StartingMap, x = 0, y = 0, z = 0 }
	character.equipment = {}
	StarterGear.apply(character, ids.newId)
	character.createdAt = ids.now
	character.guideDone = false -- S14; S155: legacy, read by nothing
	character.tutorial = Tutorial.newState() -- S155: the hands-on tutorial from step 1, the level reward waits
	character.look = CharacterLook.normalize(look)
	character.lookFree = true
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
