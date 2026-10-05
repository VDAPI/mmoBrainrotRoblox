--!strict
-- Skill rules (DESIGN §14.1). Pure.

local Locale = require("../Util/Locale")
local SkillData = require("../Data/Skills")
local Types = require("../Types")

type SkillDef = SkillData.SkillDef

local Skills = {}

-- Linear interpolation of a { level 1, max level } pair; constants pass through.
function Skills.scaled(skill: SkillDef, value: SkillData.Scaled?, level: number): number
	if value == nil then
		return 0
	end
	if type(value) == "number" then
		return value
	end
	local first, last = value[1], value[2] or value[1]
	if skill.maxLevel <= 1 then
		return first
	end
	local t = math.clamp((level - 1) / (skill.maxLevel - 1), 0, 1)
	return first + (last - first) * t
end

function Skills.valueAt(skill: SkillDef, field: string, level: number): number
	return Skills.scaled(skill, skill.values[field], level)
end

-- Character level needed for skill level n (DESIGN: unlock + 3·(n−1)).
function Skills.levelRequirement(skill: SkillDef, n: number): number
	return skill.unlock + 3 * (n - 1)
end

function Skills.level(character: Types.CharacterData, skillId: string): number
	return character.skills[skillId] or 0
end

export type LearnError = "unknown" | "wrongClass" | "maxLevel" | "noPoints" | "level" | "requires"

-- Whether the next level of `skillId` can be learned now. Returns (ok, reason?, detail?).
function Skills.canLearn(character: Types.CharacterData, skillId: string): (boolean, LearnError?, any)
	local skill = SkillData.get(skillId)
	if not skill then
		return false, "unknown", nil
	end
	if skill.class ~= character.class then
		return false, "wrongClass", nil
	end
	local current = Skills.level(character, skillId)
	if current >= skill.maxLevel then
		return false, "maxLevel", nil
	end
	if character.skillPoints < 1 then
		return false, "noPoints", nil
	end
	local needed = Skills.levelRequirement(skill, current + 1)
	if character.level < needed then
		return false, "level", needed
	end
	local requires: { { skill: string, level: number } } = skill.requires or {}
	for _, requirement in requires do
		if Skills.level(character, requirement.skill) < requirement.level then
			return false, "requires", requirement
		end
	end
	return true, nil, nil
end

function Skills.spentPoints(character: Types.CharacterData): number
	local spent = 0
	for _, level in character.skills do
		spent += level
	end
	return spent
end

-- Resets the tree: refunds every point and clears the hotbar. Mutates; returns refunded points.
function Skills.refundAll(character: Types.CharacterData): number
	local spent = Skills.spentPoints(character)
	character.skills = {}
	character.hotbar = {}
	character.skillPoints += spent
	return spent
end

-- Slot "1".."10" may hold a learned active skill of the character's class (or nil to clear).
function Skills.validHotbar(character: Types.CharacterData, slot: number, skillId: string?): boolean
	if slot ~= math.floor(slot) or slot < 1 or slot > SkillData.HOTBAR_SLOTS then
		return false
	end
	if skillId == nil then
		return true
	end
	local skill = SkillData.get(skillId)
	return skill ~= nil
		and skill.class == character.class
		and skill.type ~= "passive"
		and Skills.level(character, skillId) > 0
end

export type PassiveTotals = {
	flat: { [string]: number },
	pct: { [string]: number },
	hooks: { [string]: number },
}

-- Stat modifiers and proc values from learned passives.
function Skills.passiveTotals(character: Types.CharacterData): PassiveTotals
	local totals: PassiveTotals = { flat = {}, pct = {}, hooks = {} }
	for skillId, level in character.skills do
		local skill = SkillData.get(skillId)
		local passive = skill and skill.passive
		if skill and passive and level > 0 then
			local flat: { [string]: string } = passive.flat or {}
			local pct: { [string]: string } = passive.pct or {}
			local hooks: { [string]: string } = passive.hooks or {}
			for stat, field in flat do
				totals.flat[stat] = (totals.flat[stat] or 0) + Skills.valueAt(skill, field, level)
			end
			for stat, field in pct do
				totals.pct[stat] = (totals.pct[stat] or 0) + Skills.valueAt(skill, field, level)
			end
			for hook, field in hooks do
				totals.hooks[hook] = (totals.hooks[hook] or 0) + Skills.valueAt(skill, field, level)
			end
		end
	end
	return totals
end

local function round(value: number): number
	if math.abs(value - math.floor(value + 0.5)) < 1e-6 then
		return math.floor(value + 0.5)
	end
	return math.floor(value * 10 + 0.5) / 10
end

-- Placeholder values for the description of `skill` at `level` ({dmg}, {slow}, {duration}, {cost}, ...).
function Skills.descriptionArgs(skill: SkillDef, level: number): { [string]: number }
	local args: { [string]: number } = {}
	for field in skill.values do
		args[field] = round(Skills.valueAt(skill, field, level))
	end
	args.cost = round(Skills.scaled(skill, skill.cost, level))
	args.cooldown = round(Skills.scaled(skill, skill.cooldown, level))
	if skill.duration then
		args.duration = round(Skills.scaled(skill, skill.duration, level))
	end
	local effects: { SkillData.SkillEffect } = skill.effects or {}
	for _, effect in effects do
		args[`{effect.kind}Duration`] = round(Skills.scaled(skill, effect.duration, level))
	end
	args.radius = skill.radius or 0
	args.range = skill.range or 0
	args.length = skill.length or 0
	args.hits = skill.hits or 1
	return args
end

function Skills.formatDescription(skill: SkillDef, level: number, lang: string?): string
	return Locale.T(skill.descKey, Skills.descriptionArgs(skill, math.max(1, level)), lang)
end

-- Weapon element a skill needs (DESIGN §5.8, S18): Mage element skills need a weapon of their element;
-- adaptive skills and everything else work with any weapon.
function Skills.requiredElement(skill: SkillDef): string?
	if skill.class ~= "Mage" or skill.adaptive or not skill.element then
		return nil
	end
	return skill.element
end

function Skills.elementAllowed(skill: SkillDef, weaponElement: string?): boolean
	local required = Skills.requiredElement(skill)
	return required == nil or required == weaponElement
end

return Skills
