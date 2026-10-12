--!strict
-- Every skill (Data/Skills/<Class>), by id and by class.

local Cleric = require("@self/Cleric")
local Hunter = require("@self/Hunter")
local Mage = require("@self/Mage")
local Types = require("@self/Types")
local Warrior = require("@self/Warrior")

export type SkillDef = Types.SkillDef
export type Scaled = Types.Scaled
export type SkillEffect = Types.SkillEffect
export type Breakpoint = Types.Breakpoint
export type Breakpoints = Types.Breakpoints
export type BreakpointPair = Types.BreakpointPair
export type BreakpointOption = Types.BreakpointOption

local byClass: { [string]: { SkillDef } } = {
	Warrior = Warrior,
	Hunter = Hunter,
	Mage = Mage,
	Cleric = Cleric,
}

local byId: { [string]: SkillDef } = {}
for _, list in byClass do
	for _, def in list do
		assert(byId[def.id] == nil, `Skills: duplicate id {def.id}`)
		byId[def.id] = def
	end
end

return table.freeze({
	byId = byId,
	byClass = byClass,
	get = function(id: string): SkillDef?
		return byId[id]
	end,
	HOTBAR_SLOTS = 10,
	-- S55 (ROZWOJ 2.5): ranks grow with the character level. Rank r of a skill unlocked at U comes at
	-- U + round((r - 1) * span / (maxLevel - 1)), span = min(9 * step, capLevel - U): every skill is maxed by capLevel.
	RANKS = table.freeze({ step = 4, capLevel = 95 }),
	GCD = 0.5, -- global cooldown (DESIGN §14.1)
})
