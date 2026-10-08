--!strict
-- skills.json (S34): every skill (Data/Skills without `vfx`) with its ranks 1..maxLevel (required character level
-- from Skills.levelRequirement, cost and cooldown from Skills.scaled, values from Skills.valueAt, description in both
-- languages from Skills.formatDescription with the breakpoints applied) and the S28 breakpoints with their texts,
-- plus the point rules for the planner (S41). Field names are a contract for the planner.

local AccountSchema = require("../../src/shared/Logic/AccountSchema")
local Clean = require("./Clean")
local Classes = require("../../src/shared/Data/Classes")
local Config = require("../../src/shared/Config")
local Exp = require("../../src/shared/Logic/Exp")
local Names = require("./Names")
local Progression = require("../../src/shared/Data/Progression")
local Rng = require("../../src/shared/Logic/Rng")
local Schema = require("./Schema")
local SkillData = require("../../src/shared/Data/Skills")
local SkillLogic = require("../../src/shared/Logic/Skills")

local S = Schema
local arr, map, rec, enum = S.arr, S.map, S.rec, S.enum

local Skills = {}

S.file(
	"skills",
	rec("SkillsFile", {
		skills = arr(rec("Skill", {
			id = "string",
			class = enum("ClassId"),
			order = "int",
			name = "name",
			unlock = "int",
			maxLevel = "int",
			type = "string",
			target = "string",
			shape = "string",
			["resource?"] = "string",
			["range?"] = "number",
			["radius?"] = "number",
			["angle?"] = "number",
			["length?"] = "number",
			["width?"] = "number",
			["delay?"] = "number",
			["hits?"] = "int",
			["interval?"] = "number",
			["element?"] = enum("ElementId"),
			["requiredElement?"] = enum("ElementId"),
			-- S41: the weapon element line of the game's skill window (skill.requiresElement / skill.adaptive).
			["elementNote?"] = "name",
			["adaptive?"] = "bool",
			["damageKind?"] = "string",
			["holy?"] = "bool",
			passiveSkill = "bool",
			requires = arr(rec("SkillRequirement", { skill = "ref:skills", level = "int" })),
			col = "int",
			row = "int",
			glyph = "string",
			values = "data",
			["effects?"] = "data",
			["passive?"] = "data",
			breakpoints = arr(rec("SkillBreakpoint", { level = "int", text = "name", change = "data" })),
			ranks = arr(rec("SkillRank", {
				rank = "int",
				requiredLevel = "int",
				cost = "number",
				cooldown = "number",
				values = map("number"),
				desc = "name",
			})),
		})),
		rules = rec("SkillRules", {
			maxLevel = "int",
			pointsByLevel = arr("int"),
			skillPointsPerLevel = "int",
			skillPointsFromLevel = "int",
			breakpointsEnabled = "bool",
			breakpointLevels = arr("int"),
			-- S41: parity vectors for the planner (wiki/src/lib/skills.ts must answer exactly like Skills.canLearn).
			vectors = rec("SkillVectors", {
				states = arr(rec("SkillVectorState", {
					class = enum("ClassId"),
					level = "int",
					skillPoints = "int",
					skills = map("int"),
					results = arr(rec("SkillVectorResult", {
						skill = "ref:skills",
						ok = "bool",
						["reason?"] = "string",
						["detail?"] = "data",
					})),
				})),
				builds = arr(rec("SkillVectorBuild", {
					class = enum("ClassId"),
					level = "int",
					skills = map("int"),
					achievable = "bool",
				})),
			}),
		}),
	})
)

local function sortedSkills(): { any }
	local list = {}
	for _, skill in SkillData.byId do
		table.insert(list, skill)
	end
	table.sort(list, function(a, b)
		if a.class ~= b.class then
			return a.class < b.class
		end
		return a.order < b.order
	end)
	return list
end

-- Parity vectors (S41) ------------------------------------------------------------------------------------------

local VECTOR_SEED = 4141
local RANDOM_STATES = 34
local RANDOM_BUILDS = 16

local function pointsAt(level: number): number
	local _, skillPoints = Exp.pointsForLevels(1, level)
	return skillPoints
end

local function character(classId: string, level: number, skills: { [string]: number }): any
	local c: any = AccountSchema.characterTemplate()
	c.class = classId
	c.level = level
	c.skills = table.clone(skills)
	c.skillPoints = pointsAt(level) - SkillLogic.spentPoints(c)
	return c
end

local function learnable(c: any, list: { any }): { string }
	local out = {}
	for _, skill in list do
		if SkillLogic.canLearn(c, skill.id) then
			table.insert(out, skill.id)
		end
	end
	return out
end

-- A random learning path through the real rules: up to `steps` points, half the time on a skill already learned
-- (so maximum ranks and requirements show up).
local function randomPath(rng: any, classId: string, level: number, steps: number, list: { any }): { [string]: number }
	local c = character(classId, level, {})
	for _ = 1, steps do
		local ids = learnable(c, list)
		if #ids == 0 then
			break
		end
		local known = {}
		for _, id in ids do
			if (c.skills[id] or 0) > 0 then
				table.insert(known, id)
			end
		end
		local id = if #known > 0 and rng:chance(0.5) then rng:pick(known) else rng:pick(ids)
		c.skills[id] = (c.skills[id] or 0) + 1
		c.skillPoints -= 1
	end
	return c.skills
end

local function stateVector(classId: string, level: number, skills: { [string]: number }, list: { any }): any
	local c = character(classId, level, skills)
	local results = {}
	for _, skill in list do
		local ok, reason, detail = SkillLogic.canLearn(c, skill.id)
		table.insert(results, {
			skill = skill.id,
			ok = ok,
			reason = reason,
			detail = if detail ~= nil then Clean.clean(detail) else nil,
		})
	end
	return {
		class = classId,
		level = level,
		skillPoints = c.skillPoints,
		skills = Clean.clean(skills),
		results = results,
	}
end

-- Replays a target build point by point through Skills.canLearn until nothing more can be added.
function Skills.achievable(classId: string, level: number, target: { [string]: number }): boolean
	local list = SkillData.byClass[classId]
	local c = character(classId, level, {})
	local progress = true
	while progress do
		progress = false
		for _, skill in list do
			while (c.skills[skill.id] or 0) < (target[skill.id] or 0) and SkillLogic.canLearn(c, skill.id) do
				c.skills[skill.id] = (c.skills[skill.id] or 0) + 1
				c.skillPoints -= 1
				progress = true
			end
		end
	end
	for id, rank in target do
		if (c.skills[id] or 0) ~= rank then
			return false
		end
	end
	return true
end

type Entry = { level: number, skills: { [string]: number } }

-- Handmade edge states of one class: level 1, the first point, a requirement one rank short (and met), a level
-- exactly equal to a rank's requirement (and one below), a maximum rank, every point spent.
local function edgeStates(list: { any }): { Entry }
	local out: { Entry } = { { level = 1, skills = {} }, { level = 2, skills = {} } }
	local maxLevel = Config.MaxLevel
	for _, skill in list do
		local req = skill.requires and skill.requires[1]
		if req then
			local prereq = SkillData.get(req.skill) :: any
			local level = math.max(skill.unlock, SkillLogic.levelRequirement(prereq, req.level))
			table.insert(out, { level = level, skills = { [req.skill] = req.level - 1 } })
			table.insert(out, { level = level, skills = { [req.skill] = req.level } })
			break
		end
	end
	local first = list[1]
	local at = SkillLogic.levelRequirement(first, 3)
	table.insert(out, { level = at, skills = { [first.id] = 2 } })
	table.insert(out, { level = at - 1, skills = { [first.id] = 2 } })
	table.insert(out, { level = maxLevel, skills = { [first.id] = first.maxLevel } })
	table.insert(out, { level = 4, skills = { [first.id] = pointsAt(4) } })
	return out
end

function Skills.vectors(): any
	local rng = Rng.new(VECTOR_SEED)
	local states, builds = {}, {}
	for _, classId in Classes.order do
		local list = SkillData.byClass[classId]
		local entries = edgeStates(list)
		for _ = 1, RANDOM_STATES do
			local level = rng:int(1, Config.MaxLevel)
			local steps = rng:int(0, pointsAt(level))
			table.insert(entries, { level = level, skills = randomPath(rng, classId, level, steps, list) })
		end
		for _, e in entries do
			table.insert(states, stateVector(classId, e.level, e.skills, list))
		end
		-- Target builds: random reachable paths, then broken on purpose (one rank more, a lower level, a missing
		-- requirement), plus the capstone at its maximum rank (unreachable when unlock + 27 > max level).
		local targets: { Entry } = {}
		for i = 1, RANDOM_BUILDS do
			local level = rng:int(1, Config.MaxLevel)
			local skills = randomPath(rng, classId, level, pointsAt(level), list)
			local kind = i % 4
			if kind == 1 then
				local skill = rng:pick(list)
				skills[skill.id] = math.min(skill.maxLevel, (skills[skill.id] or 0) + 1)
			elseif kind == 2 then
				level = math.max(1, level - rng:int(1, 20))
			elseif kind == 3 then
				for _, skill in list do
					local req = skill.requires and skill.requires[1]
					if req and (skills[skill.id] or 0) > 0 then
						skills[req.skill] = req.level - 1
						break
					end
				end
			end
			table.insert(targets, { level = level, skills = skills })
		end
		local last = list[#list]
		local capstone: { [string]: number } = { [last.id] = last.maxLevel }
		for _, req in last.requires or {} do
			capstone[req.skill] = req.level
		end
		local almost = table.clone(capstone)
		almost[last.id] = last.maxLevel - 1
		table.insert(targets, { level = Config.MaxLevel, skills = capstone })
		table.insert(targets, { level = Config.MaxLevel, skills = almost })
		table.insert(targets, { level = 1, skills = {} })
		table.insert(targets, { level = 1, skills = { [list[1].id] = 1 } })
		for _, target in targets do
			local skills: { [string]: number } = {}
			for id, rank in target.skills do
				if rank > 0 then
					skills[id] = rank
				end
			end
			table.insert(builds, {
				class = classId,
				level = target.level,
				skills = Clean.clean(skills),
				achievable = Skills.achievable(classId, target.level, skills),
			})
		end
	end
	return { states = states, builds = builds }
end

local function elementNote(skill: any): any
	local required = SkillLogic.requiredElement(skill)
	if required then
		return Names.combine(function(lang: string): string
			return Names.T("skill.requiresElement", { element = Names.T(`element.{required}`, nil, lang) }, lang)
		end)
	elseif skill.adaptive then
		return Names.of("skill.adaptive")
	end
	return nil
end

function Skills.build(ctx: any): any
	local list = {}
	for _, skill in sortedSkills() do
		if not ctx.hidden[skill.id] then
			local ranks = {}
			for n = 1, skill.maxLevel do
				local values = {}
				for _, field in Clean.keys(skill.values) do
					values[field] = SkillLogic.valueAt(skill, field, n)
				end
				table.insert(ranks, {
					rank = n,
					requiredLevel = SkillLogic.levelRequirement(skill, n),
					cost = SkillLogic.scaled(skill, skill.cost, n),
					cooldown = SkillLogic.scaled(skill, skill.cooldown, n),
					values = values,
					desc = Names.combine(function(lang: string): string
						return SkillLogic.formatDescription(skill, n, lang)
					end),
				})
			end
			local breakpoints = {}
			for _, bp in SkillLogic.breakpointKeys(skill) do
				table.insert(breakpoints, {
					level = bp.level,
					text = Names.of(bp.key),
					change = Clean.clean((skill.breakpoints :: any)[bp.level]),
				})
			end
			table.insert(list, {
				id = skill.id,
				class = skill.class,
				order = skill.order,
				name = Names.of(skill.nameKey),
				unlock = skill.unlock,
				maxLevel = skill.maxLevel,
				type = skill.type,
				target = skill.target,
				shape = SkillLogic.shape(skill),
				resource = skill.resource,
				range = skill.range,
				radius = skill.radius,
				angle = skill.angle,
				length = skill.length,
				width = skill.width,
				delay = skill.delay,
				hits = skill.hits,
				interval = skill.interval,
				element = skill.element,
				requiredElement = SkillLogic.requiredElement(skill),
				elementNote = elementNote(skill),
				adaptive = skill.adaptive,
				damageKind = skill.damageKind,
				holy = skill.holy,
				passiveSkill = skill.type == "passive",
				requires = Clean.dropRefs(Clean.clean(skill.requires or {}), ctx.hidden, "skill"),
				col = skill.col,
				row = skill.row,
				glyph = skill.glyph,
				values = Clean.clean(skill.values),
				effects = if skill.effects then Clean.clean(skill.effects) else nil,
				passive = if skill.passive then Clean.clean(skill.passive) else nil,
				breakpoints = breakpoints,
				ranks = ranks,
			})
		end
	end
	local points = {}
	for level = 1, Config.MaxLevel do
		local _, skillPoints = Exp.pointsForLevels(1, level)
		table.insert(points, skillPoints)
	end
	return {
		skills = list,
		rules = {
			maxLevel = Config.MaxLevel,
			pointsByLevel = points,
			skillPointsPerLevel = Progression.skillPointsPerLevel,
			skillPointsFromLevel = Progression.skillPointsFromLevel,
			breakpointsEnabled = Config.Skills.breakpoints == true,
			breakpointLevels = Clean.clean(SkillLogic.BREAKPOINT_LEVELS),
			vectors = Skills.vectors(),
		},
	}
end

return Skills
