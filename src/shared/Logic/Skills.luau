--!strict
-- Skill rules (DESIGN §14.1). Pure.
-- S54 (ROZWOJ 8): the one cost (Skills.cost), heal curve (Skills.healMul) and weapon speed normalisation
-- (Skills.speedFactor) used by the server, the skill bar, the descriptions and the wiki.

local Combat = require("../Data/Combat")
local Config = require("../Config")
local LevelCurves = require("./LevelCurves")
local Locale = require("../Util/Locale")
local SkillData = require("../Data/Skills")
local Stats = require("../Data/Stats")
local Types = require("../Types")

type SkillDef = SkillData.SkillDef

local Skills = {}

-- Linear interpolation of a { rank 1, max rank } pair; constants pass through.
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

-- Breakpoints (S28, S55: ROZWOJ 2.7) -------------------------------------------------------------------------------

Skills.BREAKPOINT_LEVELS = { 5, 10 }

-- S55 (ROZWOJ 2.7, 3.2): breakpoint choices in the shape of the saved path.bp: ["<skillId>:<rank>"] = "a" | "b".
-- A missing entry, or "b" on a rank without option B, means A.
export type Choices = { [string]: SkillData.BreakpointOption }
-- One modify node as a resolved breakpoint table (Paths.skillMods, S57, settles the node rank, the weapon and
-- modify.option). Applied after the breakpoints, in row order.
export type SkillMod = SkillData.Breakpoint

function Skills.choiceKey(skillId: string, at: number): string
	return `{skillId}:{at}`
end

-- The option that works at breakpoint rank `at`.
function Skills.chosen(skill: SkillDef, at: number, choices: Choices?): SkillData.BreakpointOption
	local pair = skill.breakpoints and skill.breakpoints[at]
	if choices and pair and pair.b and choices[Skills.choiceKey(skill.id, at)] == "b" then
		return "b"
	end
	return "a"
end

-- Breakpoints that work at `rank`, rank 5 first, each in the chosen option (none when Config.Skills.breakpoints is
-- off; `enabled` overrides the switch, for tests and measurements).
function Skills.breakpointsAt(
	skill: SkillDef,
	rank: number,
	choices: Choices?,
	enabled: boolean?
): { SkillData.Breakpoint }
	local out = {}
	local list = skill.breakpoints
	local on = if enabled == nil then Config.Skills.breakpoints else enabled
	if not list or not on then
		return out
	end
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = list[at]
		if pair and rank >= at then
			local bp = if Skills.chosen(skill, at, choices) == "b" then pair.b else pair.a
			if bp then
				table.insert(out, bp)
			end
		end
	end
	return out
end

-- Behaviours of every source merged into one table (later sources win on the same key). Extra effects are not here:
-- they are on def.effects / def.selfEffects / def.allyEffects.
export type Behaviour = SkillData.Breakpoint

local NUMERIC_FIELDS = { "range", "radius", "angle", "length", "width", "hits", "delay" }

-- The skill as it works at `rank` (ROZWOJ 2.7). Sources in order: breakpoint 5, breakpoint 10 (chosen option, A
-- without a choice), then `mods` (modify nodes, row order). Rules: `values` add to the current value (the base scales
-- once), `add` sums, `mul` multiplies, `effect` / `selfEffect` / `allyEffect` go to the effects / selfEffects /
-- allyEffects lists, every other key: the later source wins. `add.effectDuration` lengthens `effects` only.
-- `enabled = false` (or Config.Skills.breakpoints off) drops the breakpoints, not the mods. Until S56 `rank` is the
-- learned level; until S57 every caller passes `choices = nil`, `mods = nil`. Never mutates the data; with no source
-- returns the def itself.
function Skills.effective(
	skill: SkillDef,
	rank: number,
	choices: Choices?,
	mods: { SkillMod }?,
	enabled: boolean?
): (SkillDef, Behaviour)
	local sources = Skills.breakpointsAt(skill, rank, choices, enabled)
	if mods then
		for _, mod in mods do
			table.insert(sources, mod)
		end
	end
	local behaviour: any = {}
	if #sources == 0 then
		return skill, behaviour
	end
	local def: any = table.clone(skill)
	def.values = table.clone(skill.values)
	local effects: { SkillData.SkillEffect } = table.clone(skill.effects or {})
	local selfEffects: { SkillData.SkillEffect } = {}
	local allyEffects: { SkillData.SkillEffect } = {}
	local addDuration = 0
	local jumps = 0
	local none: { [string]: number } = {}
	for _, bp in sources do
		for key, amount in bp.add or none do
			if key == "effectDuration" then
				addDuration += amount
			elseif key == "jumps" then
				jumps += amount
			elseif key == "duration" then
				def.duration = Skills.scaled(skill, def.duration, rank) + amount
			elseif table.find(NUMERIC_FIELDS, key) then
				def[key] = (def[key] or 0) + amount
			end
		end
		for key, factor in bp.mul or none do
			if key == "cooldown" then
				def.cooldown = Skills.scaled(skill, def.cooldown, rank) * factor
			elseif key == "cost" then
				def.cost = Skills.scaled(skill, def.cost, rank) * factor
			elseif key == "delay" then
				def.delay = (def.delay or 0) * factor
			end
		end
		for field, amount in bp.values or none do
			-- ROZWOJ 2.7: every change adds to the current value (the base scales once)
			def.values[field] = Skills.scaled(skill, def.values[field], rank) + amount
		end
		for key, v in bp :: any do
			if key == "effect" then
				table.insert(effects, v)
			elseif key == "selfEffect" then
				table.insert(selfEffects, v)
			elseif key == "allyEffect" then
				table.insert(allyEffects, v)
			elseif key ~= "add" and key ~= "mul" and key ~= "values" then
				behaviour[key] = v -- later wins: breakpoint 5, breakpoint 10, nodes by row
			end
		end
	end
	if jumps ~= 0 then
		def.values.jumps = Skills.scaled(skill, def.values.jumps, rank) + jumps
	end
	-- add.effectDuration lengthens `effects` only, as before S55 (not selfEffects / allyEffects)
	if addDuration ~= 0 then
		for i, effect in effects do
			local copy = table.clone(effect)
			copy.duration = math.max(0.5, Skills.scaled(skill, effect.duration, rank) + addDuration)
			effects[i] = copy
		end
	end
	def.effects = effects
	def.selfEffects = if #selfEffects > 0 then selfEffects else nil
	def.allyEffects = if #allyEffects > 0 then allyEffects else nil
	return def :: SkillDef, behaviour
end

-- Who an effect of the skill lands on (S53): its own target, or self for buffs and enemies for the rest.
function Skills.effectSide(skill: SkillDef, effect: SkillData.SkillEffect): "enemy" | "self" | "allies"
	return effect.target or (if skill.type == "buff" or skill.type == "groupBuff" then "self" else "enemy")
end

-- Locale key of a breakpoint option's text: skill.<id>.bp5 / .bp10 (A), .bp5b / .bp10b (B).
function Skills.breakpointKey(skillId: string, at: number, option: SkillData.BreakpointOption): string
	return if option == "b" then `skill.{skillId}.bp{at}b` else `skill.{skillId}.bp{at}`
end

-- Locale keys of a skill's breakpoints, rank by rank, A before B (B only where it exists).
export type BreakpointKey = { rank: number, option: SkillData.BreakpointOption, key: string }

function Skills.breakpointKeys(skill: SkillDef): { BreakpointKey }
	local out: { BreakpointKey } = {}
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints and skill.breakpoints[at]
		if pair then
			table.insert(out, { rank = at, option = "a", key = Skills.breakpointKey(skill.id, at, "a") })
			if pair.b then
				table.insert(out, { rank = at, option = "b", key = Skills.breakpointKey(skill.id, at, "b") })
			end
		end
	end
	return out
end

-- S55 (ROZWOJ 2.5): character level at which `skill` reaches rank r (actives 1..10, passives 1..5; a passive's last
-- rank comes where an active's rank 10 does). Every skill is maxed by Data/Skills RANKS.capLevel.
function Skills.rankLevel(skill: SkillDef, r: number): number
	if skill.maxLevel <= 1 or r <= 1 then
		return skill.unlock
	end
	local ranks = SkillData.RANKS
	-- nine steps: an active skill's ranks 1..10
	local span = math.max(0, math.min(9 * ranks.step, ranks.capLevel - skill.unlock))
	local n = math.min(r, skill.maxLevel)
	return skill.unlock + math.floor((n - 1) * span / (skill.maxLevel - 1) + 0.5)
end

-- Rank of `skill` at character level `level` (0 before the unlock).
function Skills.rankAt(skill: SkillDef, level: number): number
	for r = skill.maxLevel, 1, -1 do
		if level >= Skills.rankLevel(skill, r) then
			return r
		end
	end
	return 0
end

-- Character level needed for skill level n (DESIGN: unlock + 3·(n−1)). Late skills whose last level would need
-- more than Config.MaxLevel (FIX 2026-10-09: unlock 75 asked for level 102) use the largest step that fits.
function Skills.levelRequirement(skill: SkillDef, n: number): number
	local step = 3
	if skill.maxLevel > 1 then
		step = math.min(3, math.floor((Config.MaxLevel - skill.unlock) / (skill.maxLevel - 1)))
	end
	return skill.unlock + math.max(1, step) * (n - 1)
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

-- Level formulas (S54, ROZWOJ 8) ---------------------------------------------------------------------------------

-- Changes to a skill's cost: costPct = sum of percentage changes (-20 = 20 % cheaper). Later sessions extend it
-- (S62 costReduce, S76 / S79-S80 hooks).
export type CostMods = { costPct: number? }

-- Resource cost of `skill` (the def after Skills.effective, so breakpoint cost changes apply) at rank `rank` for a
-- character of level `level` and class `classId`. Mana skills of a class with a "manaCost.<classId>" level curve cost
-- more with the level (Mage, owner answer 25). Not rounded: the server and the skill bar compare the same number.
-- One function for the server, the skill bar, the description and the wiki; until S56 `rank` is the learned level,
-- then the rank from the character level.
function Skills.cost(skill: SkillDef, rank: number, level: number, classId: string, mods: CostMods?): number
	local base = Skills.scaled(skill, skill.cost, rank)
	if base <= 0 then
		return 0
	end
	local curve = "manaCost." .. classId
	if skill.resource == "mana" and LevelCurves.has(curve) then
		base *= LevelCurves.at(curve, level)
	end
	local pct = if mods and mods.costPct then mods.costPct else 0
	return base * math.max(0, 1 + pct / 100)
end

-- Multiplier of the magic-attack part of heals and shields at character level `level` (ROZWOJ 9.2).
function Skills.healMul(level: number): number
	return LevelCurves.at("heal", level)
end

local HEAL_TYPES: { [string]: boolean } = { heal = true, hot = true, groupHeal = true }

-- Value fields of `skill` computed from magic attack (or, for a damage skill that heals allies, from its own hit)
-- that the heal curve multiplies. Percent-of-HP heals (Divine Intervention), heal bonuses (Devotion) and shares of
-- dealt damage from passive hooks (Holy Strike) are not on the curve.
function Skills.healFields(skill: SkillDef): { string }
	if HEAL_TYPES[skill.type] then
		return { "heal" }
	elseif skill.type == "shield" then
		return { "shield" }
	elseif skill.type ~= "passive" and skill.values.heal ~= nil and skill.values.dmg ~= nil then
		return { "heal" }
	end
	return {}
end

-- Skill damage multiplier from the base speed of the equipped weapon (nil = unarmed): weapons with the same damage
-- per second give skills the same damage. Combat.skillSpeedRef (two-handed axe) = x1.
function Skills.speedFactor(weaponSpeed: number?): number
	return (weaponSpeed or Stats.Formula.unarmed.speed) / Combat.skillSpeedRef
end

local function round(value: number): number
	if math.abs(value - math.floor(value + 0.5)) < 1e-6 then
		return math.floor(value + 0.5)
	end
	return math.floor(value * 10 + 0.5) / 10
end

-- Options of a description: `level` = character level (default: the level the rank unlocks at, as on the wiki);
-- `choices` / `mods` as in Skills.effective (S55; nil = option A, no nodes).
export type DescOpts = { level: number?, choices: Choices?, mods: { SkillMod }? }

-- Placeholder values for the description of `base` at rank `rank` ({dmg}, {slow}, {duration}, {cost}, ...).
-- S28: the numbers as the skill works at that rank (breakpoints applied). S54: cost and heal values at the
-- character level from `opts` (Skills.cost, Skills.healMul).
function Skills.descriptionArgs(base: SkillDef, rank: number, opts: DescOpts?): { [string]: number }
	local skill = Skills.effective(base, rank, opts and opts.choices, opts and opts.mods)
	local L = if opts and opts.level then opts.level else Skills.levelRequirement(base, rank)
	local args: { [string]: number } = {}
	for field in skill.values do
		args[field] = round(Skills.valueAt(skill, field, rank))
	end
	local healMul = Skills.healMul(L)
	for _, field in Skills.healFields(base) do
		if skill.values[field] ~= nil then
			args[field] = round(Skills.valueAt(skill, field, rank) * healMul)
		end
	end
	args.cost = round(Skills.cost(skill, rank, L, base.class, nil))
	args.cooldown = round(Skills.scaled(skill, skill.cooldown, rank))
	if skill.duration then
		args.duration = round(Skills.scaled(skill, skill.duration, rank))
	end
	local effects: { SkillData.SkillEffect } = skill.effects or {}
	for _, effect in effects do
		args[`{effect.kind}Duration`] = round(Skills.scaled(skill, effect.duration, rank))
	end
	args.radius = skill.radius or 0
	args.range = skill.range or 0
	args.length = skill.length or 0
	args.hits = skill.hits or 1
	return args
end

function Skills.formatDescription(skill: SkillDef, rank: number, lang: string?, opts: DescOpts?): string
	return Locale.T(skill.descKey, Skills.descriptionArgs(skill, math.max(1, rank), opts), lang)
end

-- Weapon element a skill needs (DESIGN §5.8, S18): Mage element skills need a weapon of their element;
-- adaptive skills and everything else work with any weapon.
-- Shape of a skill's area for the tooltip icon (S28): "circle" | "self" | "cone" | "line" | "target" | "none".
function Skills.shape(skill: SkillDef): string
	local kind: string = skill.type
	if kind == "cone" then
		return "cone"
	elseif kind == "line" then
		return "line"
	elseif kind == "circleSelf" or kind == "groupHeal" or kind == "groupBuff" then
		return "self"
	elseif kind == "circleTarget" or kind == "trap" then
		return "circle"
	elseif skill.target == "enemy" or skill.target == "ally" or skill.target == "deadAlly" then
		return "target"
	end
	return "none"
end

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
