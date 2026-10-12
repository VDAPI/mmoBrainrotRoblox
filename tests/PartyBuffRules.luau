--!strict
-- Data rules of party buffs (S61, ROZWOJ 7.3), a helper of tests/paths.spec (not a spec itself). Every class with paths
-- passes it with every skill and path. Limits in Data/BuffCategories.rules.
--   check(skill): the party effects of ranks 1, 5 and 10 in every A/B choice last minDuration..maxDuration s, reach at
--     most maxRadius studs and the cooldown is never shorter than the duration. Rescue effects (invuln, guardianAngel,
--     intercept, shield and allyGuard below rescueBelow s) skip the lower duration bound only. Own effects and enemy
--     debuffs are not checked. The vigilance hook (S77, ROZWOJ 16.3) is a passive reaction, not a skill effect, so it
--     never shows up here.
--   checkAuras(path): every aura node has an ally* category, a known shape, a radius up to maxRadius and stats keys
--     that follow the convention of Data/Paths/Types (the category's stats, or one `value` for a value category).

local BuffCategories = require("../src/shared/Data/BuffCategories")
local PathData = require("../src/shared/Data/Paths")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")

type SkillDef = SkillData.SkillDef
type SkillEffect = SkillData.SkillEffect

local RULES = BuffCategories.rules
local AURA = PathData.AURA
local RESCUE_KINDS: { [string]: boolean } = { invuln = true, guardianAngel = true, intercept = true, shield = true }

local PartyBuffRules = {}

-- Every combination of breakpoint choices up to `rank` (B only where the skill has one).
local function choiceSets(skill: SkillDef, rank: number): { Skills.Choices }
	local sets: { Skills.Choices } = { {} }
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints and skill.breakpoints[at]
		if rank >= at and pair and pair.b then
			local more: { Skills.Choices } = {}
			for _, set in sets do
				local withB = table.clone(set)
				withB[Skills.choiceKey(skill.id, at)] = "b"
				table.insert(more, withB)
			end
			for _, set in more do
				table.insert(sets, set)
			end
		end
	end
	return sets
end

local function describe(choices: Skills.Choices): string
	local parts = {}
	for key, option in choices do
		table.insert(parts, `{key}={option}`)
	end
	table.sort(parts)
	return if #parts > 0 then table.concat(parts, ",") else "A"
end

type Team = { kind: string, category: string?, duration: number }

-- Party effects of the effective skill at `rank`.
local function teamEffects(def: SkillDef, rank: number): { Team }
	local out: { Team } = {}
	local function add(effect: SkillEffect)
		table.insert(out, {
			kind = effect.kind,
			category = effect.category,
			duration = Skills.scaled(def, effect.duration or def.duration, rank),
		})
	end
	for _, effect in def.effects or {} do
		if Skills.effectSide(def, effect) == "allies" then
			add(effect)
		end
	end
	for _, effect in def.allyEffects or {} do
		add(effect)
	end
	if def.type == "shield" then
		table.insert(out, { kind = "shield", duration = Skills.scaled(def, def.duration, rank) })
	end
	return out
end

function PartyBuffRules.check(skill: SkillDef): { string }
	local problems: { string } = {}
	for _, rank in { 1, 5, 10 } do
		if rank > skill.maxLevel then
			continue
		end
		for _, choices in choiceSets(skill, rank) do
			local def = Skills.effective(skill, rank, choices, nil, true)
			local where = `{skill.id} rank {rank} ({describe(choices)})`
			local d: any = def
			local radius = d.allyRadius or def.radius or def.range or 0
			local cooldown = Skills.scaled(def, def.cooldown, rank)
			for _, team in teamEffects(def, rank) do
				local rescue = RESCUE_KINDS[team.kind] == true
					or (team.category == "allyGuard" and team.duration < RULES.rescueBelow)
				if team.duration < RULES.minDuration and not rescue then
					table.insert(problems, `{where}: {team.kind} lasts {team.duration} s < {RULES.minDuration}`)
				end
				if team.duration > RULES.maxDuration then
					table.insert(problems, `{where}: {team.kind} lasts {team.duration} s > {RULES.maxDuration}`)
				end
				if radius > RULES.maxRadius then
					table.insert(problems, `{where}: {team.kind} reaches {radius} studs > {RULES.maxRadius}`)
				end
				if cooldown < team.duration then
					table.insert(problems, `{where}: cooldown {cooldown} s < duration {team.duration} s of {team.kind}`)
				end
			end
		end
	end
	return problems
end

function PartyBuffRules.checkAuras(path: PathData.PathDef): { string }
	local problems: { string } = {}
	for _, row in path.rows do
		for _, node in row.nodes do
			local aura = node.aura
			if node.kind ~= "aura" and aura == nil then
				continue
			end
			if aura == nil then
				table.insert(problems, `{node.id}: aura node without aura`)
				continue
			end
			local category = BuffCategories.get(aura.category)
			if not category or category.side ~= "ally" then
				table.insert(problems, `{node.id}: category {aura.category} is not an ally category`)
				continue
			end
			local shape: string? = aura.shape
			if shape ~= nil and shape ~= "circle" and shape ~= "behind" then
				table.insert(problems, `{node.id}: unknown shape {shape}`)
			end
			local radius = aura.radius or (if shape == "behind" then AURA.behindRadius else AURA.radius)
			if radius > RULES.maxRadius then
				table.insert(problems, `{node.id}: radius {radius} > {RULES.maxRadius}`)
			end
			local declared = category.stats
			for key, field in aura.stats do
				local ok = if declared then table.find(declared, key) ~= nil else key == "value"
				if not ok then
					table.insert(problems, `{node.id}: stats key {key} does not fit {category.id}`)
				end
				if node.values == nil or node.values[field] == nil then
					table.insert(problems, `{node.id}: stats.{key} points at missing values.{field}`)
				end
			end
			if declared == nil and aura.stats.value == nil then
				table.insert(problems, `{node.id}: {category.id} needs stats.value`)
			end
		end
	end
	return problems
end

return PartyBuffRules
