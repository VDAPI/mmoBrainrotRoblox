--!strict
-- skills.json (S34): every skill (Data/Skills without `vfx`) with its ranks 1..maxLevel (S56: the character level of
-- each rank from Skills.rankLevel, also as `rankLevels`; cost from Skills.cost at that level (S54: Mage mana grows with
-- the level), cooldown from Skills.cooldown, values and description in both languages from Skills.formatDescription at
-- that level) and the breakpoints in the S55 shape, plus the rank rules (RANKS). Level curves only through
-- Logic/Skills, never the curve data.
-- S82 (ROZWOJ 3.5, docs/WIKI.md §5): the skill planner.
-- * Skills: `path` (published paths only; skills of hidden paths are left out through ctx.hidden), breakpoints with
--   their unlock level and options A and B, ranks computed as UI/SkillInfo does (Skills.effective with the choices,
--   Skills.cost on the effective def, Skills.cooldown with its behaviour) for A/A plus `variants` for every other
--   choice pair ("ba", "ab", "bb": first letter = rank 5, second = rank 10). Modify nodes are never folded in.
-- * `paths`: only paths with PathDef.wiki ~= false (ctx.hiddenPaths), built by the pure Skills.pathEntry.
-- * `rules`: the path rules (pathPointsEvery, pathPointsByLevel, rows, dipRows, dipScale) and the planner vectors of
--   Logic/Paths.canBuy / canRefund for published paths (Skills.pathVectors, seed 8282).
-- S138 (DESIGN-18 §7, §14): no main path (no mainPathLevel, no `main` in the vectors); rules add capstonesMax,
--   mainMinPoints, teamFullPoints, skillPointsByLevel, freeRespecLevel and the shared ladder of the weapon pools;
--   every skill has `pool` / `role` (Data/Skills, empty when none) and `classPools` lists the pools of every class
--   (id, name, weapon types, element, members). The planner stays hidden until S148.
-- * wiki/test-fixtures/planner.json (Skills.plannerFixture): the same records for the test paths of
--   tests/fixtures/paths.luau, so the TypeScript rules are checked before any path is published. Never in
--   wiki/src/data.
-- Never exported: PathDef.reference, itemWeights, statPlan.

local AccountSchema = require("../../src/shared/Logic/AccountSchema")
local Classes = require("../../src/shared/Data/Classes")
local Clean = require("./Clean")
local Config = require("../../src/shared/Config")
local Json = require("./Json")
local Names = require("./Names")
local PathData = require("../../src/shared/Data/Paths")
local PathLogic = require("../../src/shared/Logic/Paths")
local Progression = require("../../src/shared/Data/Progression")
local Rng = require("../../src/shared/Logic/Rng")
local PoolData = require("../../src/shared/Data/SkillPools")
local Schema = require("./Schema")
local SkillData = require("../../src/shared/Data/Skills")
local SkillPoolLogic = require("../../src/shared/Logic/SkillPools")
local SkillLogic = require("../../src/shared/Logic/Skills")
local Titles = require("../../src/shared/Data/Titles")

local S = Schema
local arr, map, rec, enum = S.arr, S.map, S.rec, S.enum

local Skills = {}

Skills.VECTOR_SEED = 8282
Skills.RANDOM_STATES = 24
Skills.RANDOM_BUILDS = 16

-- Records (each defined once: Schema.records rejects two different tables with one name) --------------------------

local SkillOption = rec("SkillOption", { text = "name", change = "data" })
local SkillPathWeapon = rec("SkillPathWeapon", { ["main?"] = arr("string"), ["offhand?"] = arr("string") })
local SkillPathNodeRank = rec("SkillPathNodeRank", {
	rank = "int",
	values = map("number"),
	desc = "name",
	["dipDesc?"] = "name",
})
local SkillPathNode = rec("SkillPathNode", {
	id = "string",
	kind = "string",
	maxRank = "int",
	glyph = "string",
	name = "name",
	["skill?"] = "ref:skills",
	["skillB?"] = arr("int"),
	["weapon?"] = SkillPathWeapon,
	["modify?"] = rec("SkillPathModify", { skill = "ref:skills", ["at?"] = "int", ["option?"] = "string" }),
	["dipScale?"] = "number",
	ranks = arr(SkillPathNodeRank),
})
local SkillPathRow = rec("SkillPathRow", {
	row = "int",
	level = "int",
	required = "int",
	kind = "string",
	choice = "bool",
	nodes = arr(SkillPathNode),
})
local SkillPath = rec("SkillPath", {
	id = "string",
	class = enum("ClassId"),
	order = "int",
	role = "string",
	name = "name",
	desc = "name",
	["title?"] = "ref:titles",
	weapon = SkillPathWeapon,
	rows = arr(SkillPathRow),
})
local SkillPathVectorState = rec("SkillPathVectorState", {
	class = enum("ClassId"),
	level = "int",
	nodes = map("int"),
	free = "int",
	results = arr(rec("SkillPathVectorResult", {
		node = "string",
		ok = "bool",
		["reason?"] = "string",
		refund = "bool",
		["refundReason?"] = "string",
	})),
})
local SkillPathVectorBuild = rec("SkillPathVectorBuild", {
	class = enum("ClassId"),
	level = "int",
	nodes = map("int"),
	achievable = "bool",
})
local SkillPathVectors = rec("SkillPathVectors", {
	states = arr(SkillPathVectorState),
	builds = arr(SkillPathVectorBuild),
})

Skills.PlannerFixture = rec("SkillPlannerFixture", { paths = arr(SkillPath), vectors = SkillPathVectors })

S.file(
	"skills",
	rec("SkillsFile", {
		skills = arr(rec("Skill", {
			id = "string",
			class = enum("ClassId"),
			order = "int",
			name = "name",
			["path?"] = "string", -- S82: id of a published path (base skills have none)
			["pool?"] = "string", -- S138: DESIGN-18 §4.2 pool id or "common" (Data/Skills `pool`)
			["role?"] = "string", -- S138: DESIGN-18 §5 role (filled by the class sessions S140-S145)
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
			-- S55 (ROZWOJ 2.7): one entry per breakpoint rank; S82: the level it can be chosen from and option B
			breakpoints = arr(rec("SkillBreakpoint", {
				rank = "int",
				level = "int",
				a = SkillOption,
				["b?"] = SkillOption,
			})),
			ranks = arr(rec("SkillRank", {
				rank = "int",
				requiredLevel = "int",
				cost = "number",
				cooldown = "number",
				values = map("number"),
				desc = "name",
				-- S82: the rank with other breakpoint choices; key = choice at rank 5 + choice at rank 10 ("ba", "ab", "bb")
				["variants?"] = map(rec("SkillRankVariant", {
					cost = "number",
					cooldown = "number",
					values = map("number"),
					desc = "name",
				})),
			})),
		})),
		paths = arr(SkillPath), -- S82: published paths only
		-- S138 (DESIGN-18 §4.2, §14): the weapon pools of every class
		classPools = arr(rec("SkillClassPools", {
			class = enum("ClassId"),
			defaultPool = "string",
			pools = arr(rec("SkillPool", {
				id = "string",
				name = "name",
				weapons = arr("string"),
				["element?"] = enum("ElementId"),
				skills = arr("ref:skills"),
			})),
		})),
		rules = rec("SkillRules", {
			maxLevel = "int",
			ranks = rec("SkillRankRules", { step = "int", capLevel = "int" }),
			breakpointsEnabled = "bool",
			breakpointLevels = arr("int"),
			-- S82: path rules of Logic/Paths (pathPointsByLevel so the wiki repeats no formula); S138: no mainPathLevel
			pathPointsEvery = "int",
			pathPointsByLevel = arr("int"),
			-- S138 (DESIGN-18 §3, §7): directions and skill points
			capstonesMax = "int",
			mainMinPoints = "int",
			teamFullPoints = "int",
			skillPointsByLevel = arr("int"),
			freeRespecLevel = "int",
			ladder = arr(
				rec("SkillLadderRung", { code = "string", level = "int", common = "bool", ["passive?"] = "bool" })
			),
			rows = arr(rec("SkillRowRule", {
				row = "int",
				level = "int",
				required = "int",
				kind = "string",
				choice = "bool",
				["twoPathExtra?"] = "bool",
			})),
			dipRows = "int",
			dipScale = "number",
			vectors = SkillPathVectors,
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

-- Ranks with option B, in rank order (5, 10).
function Skills.ranksWithB(skill: any): { number }
	local out = {}
	for _, at in SkillLogic.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints and skill.breakpoints[at]
		if pair and pair.b then
			table.insert(out, at)
		end
	end
	return out
end

-- Numbers of `skill` at rank `rank` with the breakpoint `choices` (Skills.Choices), as UI/SkillInfo computes them:
-- the effective def (no modify nodes), Skills.cost on it at the rank's level, Skills.cooldown without item reduction.
function Skills.rankNumbers(skill: any, rank: number, choices: any): any
	local def, behaviour = SkillLogic.effective(skill, rank, choices, nil)
	local level = SkillLogic.rankLevel(skill, rank)
	local values = Json.object({})
	for _, field in Clean.keys(def.values) do
		values[field] = SkillLogic.valueAt(def, field, rank)
	end
	return {
		cost = SkillLogic.cost(def, rank, level, skill.class, nil),
		cooldown = SkillLogic.cooldown(def, rank, 0, behaviour),
		values = values,
		desc = Names.combine(function(lang: string): string
			return SkillLogic.formatDescription(skill, rank, lang, { level = level, choices = choices })
		end),
	}
end

-- Choice pairs that differ from A/A at `rank`: { key, choices } ("ba" = B at 5, "ab" = B at 10, "bb" = both).
function Skills.variantKeys(skill: any, rank: number): { { key: string, choices: { [string]: string } } }
	local out = {}
	local with = Skills.ranksWithB(skill)
	local b5 = rank >= 5 and table.find(with, 5) ~= nil
	local b10 = rank >= 10 and table.find(with, 10) ~= nil
	local five = SkillLogic.choiceKey(skill.id, 5)
	local ten = SkillLogic.choiceKey(skill.id, 10)
	if b5 then
		table.insert(out, { key = "ba", choices = { [five] = "b" } })
	end
	if b10 then
		table.insert(out, { key = "ab", choices = { [ten] = "b" } })
	end
	if b5 and b10 then
		table.insert(out, { key = "bb", choices = { [five] = "b", [ten] = "b" } })
	end
	return out
end

local function skillEntry(skill: any): any
	local ranks = {}
	for n = 1, skill.maxLevel do
		local numbers = Skills.rankNumbers(skill, n, nil)
		local variants = nil
		for _, v in Skills.variantKeys(skill, n) do
			variants = variants or {}
			variants[v.key] = Skills.rankNumbers(skill, n, v.choices)
		end
		table.insert(ranks, {
			rank = n,
			requiredLevel = SkillLogic.rankLevel(skill, n),
			cost = numbers.cost,
			cooldown = numbers.cooldown,
			values = numbers.values,
			desc = numbers.desc,
			variants = variants,
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
				level = SkillLogic.rankLevel(skill, at),
				a = {
					text = Names.of(SkillLogic.breakpointKey(skill.id, at, "a")),
					change = Clean.clean(pair.a),
				},
				b = if pair.b
					then {
						text = Names.of(SkillLogic.breakpointKey(skill.id, at, "b")),
						change = Clean.clean(pair.b),
					}
					else nil,
			})
		end
	end
	return {
		id = skill.id,
		class = skill.class,
		order = skill.order,
		name = Names.of(skill.nameKey),
		path = skill.path,
		pool = skill.pool,
		role = skill.role,
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
	}
end

-- Paths -------------------------------------------------------------------------------------------------------------

-- Weapon requirement as base type ids ({} = any weapon of the class).
local function weaponOf(req: any): any
	local out = Json.object({})
	if type(req) == "table" then
		if req.main then
			out.main = table.clone(req.main)
		end
		if req.offhand then
			out.offhand = table.clone(req.offhand)
		end
	end
	return out
end

local function sameName(a: any, b: any): boolean
	return a.pl == b.pl and a.en == b.en
end

-- One path as the wiki shows it (pure; publication is the caller's choice). `api` = Logic/Paths or
-- Paths.withSource(...); `text(key, args)` gives a { pl, en } text; `skillDesc(skillId)` the description of a skill at
-- rank 1. Rows: level, requirement and kind from api.rowsFor, choice and nodes from the PathDef. Node values from
-- api.nodeValues, descriptions from api.nodeArgs (the skill window's way); dipScale for team nodes of rows 1..DIP_ROWS
-- (api.isTeamNode, as nodeScale). Never `reference`, `itemWeights` or `statPlan`; `title` is set by the caller.
function Skills.pathEntry(
	api: any,
	path: any,
	text: (key: string, args: { [string]: any }?) -> any,
	skillDesc: (skillId: string) -> any
): any
	local info = api.rowsFor(path.class)
	local rows = {}
	for i, row in path.rows do
		local nodes = {}
		for _, node in row.nodes do
			local entry: any = {
				id = node.id,
				kind = node.kind,
				maxRank = node.maxRank,
				glyph = node.glyph,
				weapon = if node.weapon then weaponOf(node.weapon) else nil,
			}
			if node.kind == "skill" and node.skill then
				local skill = api.source.skill(node.skill)
				assert(skill, `Skills.pathEntry: {node.id} gives an unknown skill {node.skill}`)
				entry.skill = node.skill
				entry.name = text(skill.nameKey)
				local with = Skills.ranksWithB(skill)
				entry.skillB = if #with > 0 then with else nil
				entry.ranks = { { rank = 1, values = Json.object({}), desc = skillDesc(node.skill) } }
			else
				entry.name = text(node.nameKey)
				if node.modify then
					entry.modify = { skill = node.modify.skill, at = node.modify.at, option = node.modify.option }
				end
				local scale = if i <= api.DIP_ROWS and api.isTeamNode(node) then node.dipScale or api.DIP_SCALE else nil
				entry.dipScale = scale
				local ranks = {}
				for r = 1, node.maxRank do
					local values = Json.object({})
					for field, v in api.nodeValues(node, r) do
						values[field] = v
					end
					local desc = text(node.descKey, api.nodeArgs(node, r))
					local dip = if scale then text(node.descKey, api.nodeArgs(node, r, scale)) else nil
					table.insert(ranks, {
						rank = r,
						values = values,
						desc = desc,
						dipDesc = if dip and not sameName(dip, desc) then dip else nil,
					})
				end
				entry.ranks = ranks
			end
			table.insert(nodes, entry)
		end
		table.insert(rows, {
			row = i,
			level = info[i].level,
			required = info[i].need,
			kind = info[i].kind,
			choice = row.choice == true,
			nodes = nodes,
		})
	end
	return {
		id = path.id,
		class = path.class,
		order = path.order,
		role = path.role,
		name = text(path.nameKey),
		desc = text(path.descKey),
		weapon = weaponOf(path.weapon),
		rows = rows,
	}
end

-- Planner vectors (S82, pattern: the S41 generator) -----------------------------------------------------------------

local function classOrder(paths: { any }): { string }
	local present: { [string]: boolean } = {}
	for _, path in paths do
		present[path.class] = true
	end
	local out = {}
	for _, classId in Classes.order do
		if present[classId] then
			table.insert(out, classId)
		end
	end
	return out
end

local function pathsOfClass(paths: { any }, classId: string): { any }
	local out = {}
	for _, path in paths do
		if path.class == classId then
			table.insert(out, path)
		end
	end
	table.sort(out, function(a, b)
		return a.order < b.order
	end)
	return out
end

local function rankIn(nodes: { [string]: number }, id: string): number
	return nodes[id] or 0
end

local function copyNodes(nodes: { [string]: number }): { [string]: number }
	local out = Json.object({})
	for id, rank in nodes do
		if rank > 0 then
			out[id] = rank
		end
	end
	return out
end

local function character(classId: string, level: number, nodes: { [string]: number }): any
	local c: any = AccountSchema.characterTemplate()
	c.class = classId
	c.level = level
	c.path = { nodes = nodes, bp = {} }
	return c
end

-- Puts up to `count` ranks into a row (node order; a choice row only its first node); returns the ranks left.
local function fillRow(nodes: { [string]: number }, path: any, row: number, count: number): number
	local def = path.rows[row]
	for _, node in def.nodes do
		if count <= 0 then
			break
		end
		local add = math.min(node.maxRank - rankIn(nodes, node.id), count)
		if add > 0 then
			nodes[node.id] = rankIn(nodes, node.id) + add
			count -= add
		end
		if def.choice then
			break
		end
	end
	return count
end

-- Buys through api.canBuy, row by row up to `upto`, every node as far as it goes.
local function greedy(api: any, c: any, path: any, upto: number)
	for r = 1, math.min(upto, #path.rows) do
		for _, node in path.rows[r].nodes do
			while api.canBuy(c, node.id) do
				c.path.nodes[node.id] = rankIn(c.path.nodes, node.id) + 1
			end
		end
	end
end

local function nodeList(classPaths: { any }): { string }
	local out = {}
	for _, path in classPaths do
		for _, row in path.rows do
			for _, node in row.nodes do
				table.insert(out, node.id)
			end
		end
	end
	return out
end

local function rowIndexOfKind(api: any, classId: string, kind: string): number?
	for _, info in api.rowsFor(classId) do
		if info.kind == kind then
			return info.index
		end
	end
	return nil
end

-- Whether a new character of `level` reaches `nodes` (id -> rank): it buys in a loop while anything changes: paths by
-- order, rows ascending, nodes in row order, each `while rank < target and canBuy`. The order is the TypeScript
-- contract (B3). S138: no main path (directions and one capstone per set, Logic/Paths.canBuy).
function Skills.pathAchievable(
	api: any,
	paths: { any },
	classId: string,
	level: number,
	nodes: { [string]: number }
): boolean
	local c = character(classId, level, {})
	local have: { [string]: number } = c.path.nodes
	local classPaths = pathsOfClass(paths, classId)
	local changed = true
	while changed do
		changed = false
		for _, path in classPaths do
			for _, row in path.rows do
				for _, node in row.nodes do
					local target = nodes[node.id] or 0
					while rankIn(have, node.id) < target and api.canBuy(c, node.id) do
						have[node.id] = rankIn(have, node.id) + 1
						changed = true
					end
				end
			end
		end
	end
	for id, target in nodes do
		if target > 0 and rankIn(have, id) ~= target then
			return false
		end
	end
	return true
end

-- { states, builds } for `paths` (PathDefs of one or more classes): canBuy / canRefund of every node of the class
-- (plus "<first path>_missing") in edge states and random walks, and target builds with pathAchievable.
function Skills.pathVectors(api: any, paths: { any }, seed: number): any
	local rng = Rng.new(seed)
	local states = {}
	local builds = {}
	local maxLevel = Config.MaxLevel
	for _, classId in classOrder(paths) do
		local classPaths = pathsOfClass(paths, classId)
		local ids = nodeList(classPaths)
		local missing = `{classPaths[1].id}_missing`
		local probe = table.clone(ids)
		table.insert(probe, missing)
		local info = api.rowsFor(classId)

		local function addState(level: number, nodes: { [string]: number })
			local c = character(classId, level, copyNodes(nodes))
			local results = {}
			for _, id in probe do
				local ok, reason = api.canBuy(c, id)
				local refund, refundReason = api.canRefund(c, id)
				table.insert(results, {
					node = id,
					ok = ok,
					reason = reason,
					refund = refund,
					refundReason = refundReason,
				})
			end
			table.insert(states, {
				class = classId,
				level = level,
				nodes = copyNodes(nodes),
				free = api.free(c),
				results = results,
			})
		end

		local p1 = classPaths[1]
		local p2 = classPaths[2]
		-- edge states
		addState(1, {})
		addState(9, {})
		addState(10, {})
		local row1 = {}
		fillRow(row1, p1, 1, math.huge)
		local short = {}
		fillRow(short, p1, 1, math.max(0, info[2].need - 1))
		for _, level in { 14, 15 } do
			addState(level, row1)
			addState(level, short)
		end
		local r12 = table.clone(row1)
		fillRow(r12, p1, 2, 4)
		addState(19, r12)
		addState(20, r12)
		if p2 then
			local both = table.clone(r12)
			fillRow(both, p2, 1, math.huge)
			addState(20, both)
		end
		-- a choice row with one node bought (rows below at exactly the requirement)
		local choiceRow = rowIndexOfKind(api, classId, "choice")
		if choiceRow then
			local nodes = {}
			local left = info[choiceRow].need
			for r = 1, choiceRow - 1 do
				left = fillRow(nodes, p1, r, left)
			end
			nodes[p1.rows[choiceRow].nodes[1].id] = 1
			addState(info[choiceRow].level, nodes)
			addState(info[choiceRow].level + 10, nodes)
		end
		-- every point spent
		local spent = character(classId, 30, {})
		greedy(api, spent, p1, #p1.rows)
		addState(30, spent.path.nodes)
		if p2 then
			local other = character(classId, 26, {})
			greedy(api, other, p2, #p2.rows)
			addState(26, other.path.nodes)
		end
		-- the capstone, one level before and at its level
		local cap = rowIndexOfKind(api, classId, "capstone")
		if cap then
			local capLevel = info[cap].level
			local before = character(classId, capLevel - 1, {})
			greedy(api, before, p1, cap - 1)
			addState(capLevel - 1, before.path.nodes)
			addState(capLevel, before.path.nodes)
			-- S138: the capstone of a second direction while the first one has it (one per set) and the upgrade rule
			-- (rows below each capstone filled to exactly its requirement, so points are left)
			if p2 then
				local two = {}
				for _, path in { p1, p2 } do
					local left = info[cap].need
					for r = 1, cap - 1 do
						left = fillRow(two, path, r, left)
					end
				end
				two[p1.rows[cap].nodes[1].id] = 1
				addState(maxLevel, two)
			end
		end
		-- a whole direction at the top level
		local full = character(classId, maxLevel, {})
		greedy(api, full, p1, #p1.rows)
		addState(maxLevel, full.path.nodes)

		-- random walks: a level, purchases through canBuy (half of them on a node already bought)
		local function walk(level: number): { [string]: number }
			local c = character(classId, level, {})
			local attempts = rng:int(0, api.pointsAt(level) * 3 + 3)
			for _ = 1, attempts do
				local bought = {}
				for _, id in ids do
					if rankIn(c.path.nodes, id) > 0 then
						table.insert(bought, id)
					end
				end
				local id = if #bought > 0 and rng:chance(0.5) then rng:pick(bought) else rng:pick(ids)
				if api.canBuy(c, id) then
					c.path.nodes[id] = rankIn(c.path.nodes, id) + 1
				end
			end
			return c.path.nodes
		end
		for _ = 1, Skills.RANDOM_STATES do
			local level = rng:int(1, maxLevel)
			addState(level, walk(level))
		end

		-- target builds: random walks, some broken on purpose, and the empty build at level 1
		local function addBuild(level: number, nodes: { [string]: number })
			table.insert(builds, {
				class = classId,
				level = level,
				nodes = copyNodes(nodes),
				achievable = Skills.pathAchievable(api, paths, classId, level, nodes),
			})
		end
		addBuild(1, {})
		local deepLevel = info[api.DIP_ROWS + 1].level -- the first row past the team-node rows
		for i = 1, Skills.RANDOM_BUILDS do
			local level = rng:int(deepLevel, maxLevel)
			local nodes = walk(level)
			local kind = i % 8
			if kind == 2 then
				-- one rank more on a random node
				local id = rng:pick(ids)
				nodes[id] = rankIn(nodes, id) + 1
			elseif kind == 3 then
				level = math.max(1, level - rng:int(1, 20))
			elseif kind == 4 then
				-- a rank taken from a lower row so a higher row loses its requirement
				for _, path in classPaths do
					local top = 0
					for r, row in path.rows do
						for _, node in row.nodes do
							if rankIn(nodes, node.id) > 0 then
								top = r
							end
						end
					end
					local done = false
					for r = 1, top - 1 do
						for _, node in path.rows[r].nodes do
							if not done and rankIn(nodes, node.id) > 0 then
								nodes[node.id] -= 1
								done = true
							end
						end
					end
					if done then
						break
					end
				end
			elseif kind == 5 and p2 and cap then
				-- S138: the capstones of two directions (one per set: never achievable)
				nodes[p1.rows[cap].nodes[1].id] = 1
				nodes[p2.rows[cap].nodes[1].id] = 1
			elseif kind == 6 then
				level = deepLevel - 1
			elseif kind == 7 and choiceRow then
				for _, node in p1.rows[choiceRow].nodes do
					nodes[node.id] = math.max(1, rankIn(nodes, node.id))
				end
			end
			addBuild(level, nodes)
		end
	end
	return { states = states, builds = builds }
end

-- Path ids of `paths` in class order and path order.
local function sortedPaths(paths: { any }): { any }
	local out = {}
	for _, classId in Classes.order do
		for _, path in pathsOfClass(paths, classId) do
			table.insert(out, path)
		end
	end
	return out
end

-- wiki/test-fixtures/planner.json: the test paths of tests/fixtures/paths.luau (never on the wiki) through the same
-- pathEntry and pathVectors, texts as their keys (no Names).
function Skills.plannerFixture(): any
	local Fixture = require("../../tests/fixtures/paths") :: any
	local api = PathLogic.withSource(Fixture.source)
	local defs = sortedPaths(Fixture.paths)
	local list = {}
	for _, def in defs do
		table.insert(
			list,
			Skills.pathEntry(api, def, function(key: string): any
				return { pl = key, en = key }
			end, function(id: string): any
				return { pl = id, en = id }
			end)
		)
	end
	return { paths = list, vectors = Skills.pathVectors(api, defs, Skills.VECTOR_SEED) }
end

-- Rules -------------------------------------------------------------------------------------------------------------

local function rowRules(): { any }
	local out = {}
	for i, row in PathData.ROWS do
		table.insert(out, {
			row = i,
			level = row.level,
			required = row.need,
			kind = row.kind,
			choice = row.kind == "choice",
			twoPathExtra = if row.twoPathExtra then true else nil,
		})
	end
	return out
end

function Skills.build(ctx: any): any
	local list = {}
	for _, skill in sortedSkills() do
		if not ctx.hidden[skill.id] then
			table.insert(list, skillEntry(skill))
		end
	end
	local hiddenPaths: { [string]: boolean } = ctx.hiddenPaths or {}
	local published = {}
	for _, def in sortedPaths(PathData.list) do
		if def.wiki ~= false and not hiddenPaths[def.id] then
			table.insert(published, def)
		end
	end
	local paths = {}
	for _, def in published do
		local entry = Skills.pathEntry(PathLogic, def, Names.of, function(skillId: string): any
			local skill = SkillData.get(skillId) :: any
			return Names.combine(function(lang: string): string
				return SkillLogic.formatDescription(skill, 1, lang, { level = SkillLogic.rankLevel(skill, 1) })
			end)
		end)
		if Titles.get(def.titleId) and not ctx.hidden[def.titleId] then
			entry.title = def.titleId
		end
		table.insert(paths, entry)
	end
	local pointsByLevel = {}
	local skillPointsByLevel = {}
	for level = 1, Config.MaxLevel do
		table.insert(pointsByLevel, PathLogic.pointsAt(level))
		table.insert(skillPointsByLevel, PathLogic.skillPointsAt(level))
	end
	-- S138: the shared ladder (school, then common rungs) and the pools of every class
	local ladder = {}
	for _, rung in PoolData.LADDER do
		table.insert(ladder, { code = rung.code, level = rung.level, common = false, passive = rung.passive })
	end
	for _, rung in PoolData.COMMON_LADDER do
		table.insert(ladder, { code = rung.code, level = rung.level, common = true, passive = rung.passive })
	end
	local classPools = {}
	for _, classId in Classes.order do
		local own = PoolData.get(classId)
		if own then
			local pools = {}
			for _, def in own.pools do
				local skills = {}
				for _, id in SkillPoolLogic.members(classId, def.id) do
					if not ctx.hidden[id] and SkillData.get(id) then
						table.insert(skills, id)
					end
				end
				table.insert(pools, {
					id = def.id,
					name = Names.of(def.nameKey),
					weapons = Clean.clean(def.weapon.main),
					element = def.weapon.element,
					skills = skills,
				})
			end
			table.insert(classPools, {
				class = classId,
				defaultPool = own.defaultPool,
				pools = pools,
			})
		end
	end
	return {
		skills = list,
		paths = paths,
		classPools = classPools,
		rules = {
			maxLevel = Config.MaxLevel,
			ranks = { step = SkillData.RANKS.step, capLevel = SkillData.RANKS.capLevel },
			breakpointsEnabled = Config.Skills.breakpoints == true,
			breakpointLevels = Clean.clean(SkillLogic.BREAKPOINT_LEVELS),
			pathPointsEvery = Progression.pathPointsEvery,
			pathPointsByLevel = pointsByLevel,
			capstonesMax = PathData.CAPSTONES_MAX,
			mainMinPoints = PathData.MAIN_MIN_POINTS,
			teamFullPoints = PathData.TEAM_FULL_POINTS,
			skillPointsByLevel = skillPointsByLevel,
			freeRespecLevel = Progression.freeRespecLevel,
			ladder = ladder,
			rows = rowRules(),
			dipRows = PathData.DIP_ROWS,
			dipScale = PathData.DIP_SCALE,
			vectors = Skills.pathVectors(PathLogic, published, Skills.VECTOR_SEED),
		},
	}
end

return Skills
