--!strict
-- skills.json (S34): every skill (Data/Skills without `vfx`) with its ranks 1..maxLevel (S56: the character level of
-- each rank from Skills.rankLevel, also as `rankLevels`; cost from Skills.cost at that level (S54: Mage mana grows with
-- the level), cooldown from Skills.scaled, values from Skills.valueAt, description in both languages from
-- Skills.formatDescription at that level with the breakpoints applied) and the breakpoints in the S55 shape (rank,
-- option A with its text and change), plus the rank rules (RANKS). Level curves only through Logic/Skills, never the
-- curve data. The planner is hidden until S82 (ROZWOJ 3.5).

local Clean = require("./Clean")
local Config = require("../../src/shared/Config")
local Names = require("./Names")
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
			glyph = "string",
			rankLevels = arr("int"), -- S56 (ROZWOJ 2.5): character level of ranks 1..maxLevel
			values = "data",
			["effects?"] = "data",
			["passive?"] = "data",
			-- S55 (ROZWOJ 2.7): one entry per breakpoint rank, option A only; S82 adds the unlock level and option B
			breakpoints = arr(
				rec("SkillBreakpoint", { rank = "int", a = rec("SkillOption", { text = "name", change = "data" }) })
			),
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
			ranks = rec("SkillRankRules", { step = "int", capLevel = "int" }),
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
				local required = SkillLogic.rankLevel(skill, n)
				table.insert(ranks, {
					rank = n,
					requiredLevel = required,
					cost = SkillLogic.cost(skill, n, required, skill.class, nil),
					cooldown = SkillLogic.scaled(skill, skill.cooldown, n),
					values = values,
					desc = Names.combine(function(lang: string): string
						return SkillLogic.formatDescription(skill, n, lang, { level = required })
					end),
				})
			end
			local rankLevels = {}
			for r = 1, skill.maxLevel do
				table.insert(rankLevels, SkillLogic.rankLevel(skill, r))
			end
			local breakpoints = {}
			for _, at in SkillLogic.BREAKPOINT_LEVELS do
				local pair = skill.breakpoints and skill.breakpoints[at]
				if pair then
					table.insert(breakpoints, {
						rank = at,
						a = {
							text = Names.of(SkillLogic.breakpointKey(skill.id, at, "a")),
							change = Clean.clean(pair.a),
						},
					})
				end
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
				glyph = skill.glyph,
				rankLevels = rankLevels,
				values = Clean.clean(skill.values),
				effects = if skill.effects then Clean.clean(skill.effects) else nil,
				passive = if skill.passive then Clean.clean(skill.passive) else nil,
				breakpoints = breakpoints,
				ranks = ranks,
			})
		end
	end
	return {
		skills = list,
		rules = {
			maxLevel = Config.MaxLevel,
			ranks = { step = SkillData.RANKS.step, capLevel = SkillData.RANKS.capLevel },
			breakpointsEnabled = Config.Skills.breakpoints == true,
			breakpointLevels = Clean.clean(SkillLogic.BREAKPOINT_LEVELS),
		},
	}
end

return Skills
