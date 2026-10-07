--!strict
-- skills.json (S34): every skill (Data/Skills without `vfx`) with its ranks 1..maxLevel (required character level
-- from Skills.levelRequirement, cost and cooldown from Skills.scaled, values from Skills.valueAt, description in both
-- languages from Skills.formatDescription with the breakpoints applied) and the S28 breakpoints with their texts,
-- plus the point rules for the planner (S41). Field names are a contract for the planner.

local Clean = require("./Clean")
local Config = require("../../src/shared/Config")
local Exp = require("../../src/shared/Logic/Exp")
local Names = require("./Names")
local Progression = require("../../src/shared/Data/Progression")
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
		},
	}
end

return Skills
