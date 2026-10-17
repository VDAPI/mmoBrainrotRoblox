--!strict
-- Class paths (ROZWOJ 2.2-2.10, 3.1; S57). Pure. Points, rows, buying and refunding nodes, path skills, breakpoint
-- choices, node values and skill changes, passives, the hotbar check and the edit rules. Every function reads paths and skills through a Source: the game uses the default module (Data/Paths,
-- Data/Skills), tests build their own with Paths.withSource(Paths.sourceOf(paths, skills)).
-- From a character only `class`, `level`, `path`, `hotbar` and `equipment` are read; a missing `path` is empty.
-- Build sets (S58, ROZWOJ 2.9): swapSets / copySet / cleanSet and friends also read `stats`, `statPoints`,
-- `buildSlot` and `buildOther`.
-- Node numbers (B3): values that depend on the node rank sit in node.values ({ rank 1, rank max }); passive / aura /
-- luck map a stat or field to a values field; in modify.bp any number is { ref = "<values field>" } (inside `mul`
-- it becomes 1 + (x - 1) * scale, elsewhere x * scale). Team nodes of rows 1..DIP_ROWS work with scale node.dipScale or
-- DIP_SCALE while their direction has fewer than TEAM_FULL_POINTS ranks (S138).
-- S59: nodeScale (that rule for any node), nodeArgs (node description arguments), iconWeapon, isTwoHanded; the
-- window's views live in Logic/PathView.
-- S60: luckOfNodes / luck (raw Data/Luck fields of the active nodes).
-- S61: auras (party auras of the active nodes) and inAura (pure geometry, also Paths.inAura on the module).
-- S137 (DESIGN-18 §3, §4, §9): a rank is BOUGHT with skill points per weapon pool (character.ranks[poolId][skillId]),
-- capped by the old level curve (Skills.rankAt). skillRank is the one rule: a skill of the pool (Logic/SkillPools; path
-- skills are in every pool but still need their node), the bought rank, the limit; the pool defaults to the active one
-- (the equipped weapon). Build sets carry ranks, bars, barPool, respecFree and poolsVersion; cleanRanks is the rank
-- part of cleanSet (Logic/SkillPoints.clean). Points and the other rank rules: Logic/SkillPoints.
-- S138 (DESIGN-18 §7): paths are mixable directions. No main path (canChooseMain, MAIN_LEVEL, mainWeaponOk, `main` and
-- `freeUsed` are gone; clampToLevel / cleanSet drop the old fields): every row of every direction opens with its level
-- and the ranks in its lower rows; a capstone (row kind "capstone") in at most CAPSTONES_MAX directions, the upgrade only
-- in the direction with the capstone; PathDef.weapon blocks nothing (node.weapon still does, in every row). The leading
-- direction (mainOf: the most ranks, at least MAIN_MIN_POINTS, a tie goes to the lower order) replaces the main path for
-- the title, statPlan, item weights and the party sign. Node refunds below Progression.freeRespecLevel work anywhere out
-- of combat (canEdit with ctx.level); from it they cost gold (PathService, Logic/SkillPoints.refundCost).

local Bases = require("../Data/Items/Bases")
local Classes = require("../Data/Classes")
local EffectStack = require("./EffectStack")
local ItemEffects = require("./ItemEffects")
local Items = require("../Data/Items")
local LuckData = require("../Data/Luck")
local PathData = require("../Data/Paths")
local Progression = require("../Data/Progression")
local SkillData = require("../Data/Skills")
local SkillPools = require("./SkillPools")
local Skills = require("./Skills")
local StatPlan = require("./StatPlan")
local TableUtil = require("../Util/TableUtil")
local Types = require("../Types")

type PathDef = PathData.PathDef
type PathNode = PathData.PathNode
type SkillDef = SkillData.SkillDef

export type WeaponReq = PathData.WeaponReq
export type RowKind = PathData.RowKind
export type WeaponTypes = { main: string?, offhand: string? }
export type RowInfo = { index: number, level: number, need: number, kind: RowKind, choice: boolean, extra: boolean }
export type ActiveNode = { node: PathNode, path: PathDef, row: number, rank: number, scale: number }
-- S61: flat positions (Logic has no Vector3) and a resolved party aura.
export type Flat = { x: number, z: number }
export type Aura = {
	nodeId: string, -- buff skillId; "admin_aura" for /aura
	category: string, -- Data/BuffCategories ally category
	stats: { [string]: number }, -- resolved at the node's rank (x nodeScale); value categories: { value = n }
	shape: "circle" | "behind",
	radius: number,
}
export type EditAction = "buy" | "refund" | "chooseBp" | "changeBp" | "switchSet" | "copySet"
-- dead / inRun (S58): only the build set actions read them; nil = false. level (S138): a refund below
-- Progression.freeRespecLevel may happen anywhere out of combat (nil = the town / gate rule).
export type EditCtx = {
	action: EditAction,
	inCombat: boolean,
	inTown: boolean,
	nearGate: boolean,
	dead: boolean?,
	inRun: boolean?,
	level: number?,
}
export type RefundOpts = { path: string?, fromRow: number?, points: number? }
export type PathState = Types.PathState
export type BuildSet = Types.BuildSet
export type SetSwap = { active: BuildSet, other: BuildSet, slot: number } -- slot = the new buildSlot
-- The part of a character the rules read (S58 / S59 pass narrow views, e.g. the inactive build set).
export type Char = {
	class: string,
	level: number,
	path: PathState?,
	hotbar: { [string]: string }?,
	equipment: { [string]: any }?,
	-- S137: bought ranks per pool, the other pools' bars and whose bar `hotbar` is (nil = none)
	ranks: { [string]: { [string]: number } }?,
	bars: { [string]: { [string]: string } }?,
	barPool: string?,
}

export type Source = {
	pathsOf: (classId: string) -> { PathDef },
	path: (pathId: string) -> PathDef?,
	skill: (skillId: string) -> SkillDef?,
	classSkills: (classId: string) -> { SkillDef },
}

local ROWS = PathData.ROWS
local DIP_ROWS = PathData.DIP_ROWS
local DIP_SCALE = PathData.DIP_SCALE
local CAPSTONES_MAX = PathData.CAPSTONES_MAX
local MAIN_MIN_POINTS = PathData.MAIN_MIN_POINTS
local TEAM_FULL_POINTS = PathData.TEAM_FULL_POINTS
local BP_RANKS = Skills.BREAKPOINT_LEVELS

-- Two-handed weapon types, from the item bases.
local TWO_HANDED: { [string]: boolean } = {}
for _, base in Bases.list do
	local weapon = base.weapon
	if weapon and weapon(1).twoHanded then
		TWO_HANDED[base.type] = true
	end
end

local AURA = PathData.AURA

local function flatDistance(a: Flat, b: Flat): number
	local dx, dz = a.x - b.x, a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

-- ROZWOJ 7.3 (S61): is `receiver` inside the aura of `owner`? circle: flat distance <= radius (default AURA.radius).
-- behind: the anchor is `threat`, else the nearest of `monsters` within AURA.fallbackRange of the owner (none: false);
-- the receiver is within radius (default AURA.behindRadius) of the owner, farther from the anchor than the owner, and
-- at most AURA.behindAngle / 2 off the anchor -> owner line. The facing of the character never counts.
local function inAura(
	aura: { shape: string?, radius: number? },
	owner: Flat,
	receiver: Flat,
	threat: Flat?,
	monsters: { Flat }?
): boolean
	if aura.shape ~= "behind" then
		return flatDistance(owner, receiver) <= (aura.radius or AURA.radius)
	end
	local anchor = threat
	if anchor == nil and monsters then
		local best = AURA.fallbackRange
		for _, m in monsters do
			local d = flatDistance(owner, m)
			if d <= best then
				best = d
				anchor = m
			end
		end
	end
	if anchor == nil then
		return false
	end
	local distance = flatDistance(owner, receiver)
	if distance > (aura.radius or AURA.behindRadius) or distance <= 0 then
		return false
	end
	local ax, az = owner.x - anchor.x, owner.z - anchor.z
	local along = math.sqrt(ax * ax + az * az)
	if along <= 0 then
		return false
	end
	if flatDistance(anchor, receiver) <= along then
		return false
	end
	local rx, rz = receiver.x - owner.x, receiver.z - owner.z
	local cos = (rx * ax + rz * az) / (distance * along)
	local angle = math.deg(math.acos(math.clamp(cos, -1, 1)))
	return angle <= AURA.behindAngle / 2 + 1e-9
end

local EMPTY: PathState = table.freeze({ nodes = table.freeze({}), bp = table.freeze({}) })

local function stateOf(character: Char): PathState
	local state = character.path
	if type(state) ~= "table" then
		return EMPTY
	end
	return state
end

local function rankIn(nodes: { [string]: number }, id: string): number
	local rank = nodes[id]
	return if type(rank) == "number" then rank else 0
end

-- Source-independent rules ------------------------------------------------------------------------------------------

-- ROZWOJ 2.8: nil = any weapon of the class. A two-hander listed in `main` needs no off-hand; with any other main
-- type (and with main = nil) the off-hand requirement holds.
local function weaponOk(req: WeaponReq?, weapons: WeaponTypes): boolean
	if req == nil then
		return true
	end
	if req.main and (weapons.main == nil or table.find(req.main, weapons.main) == nil) then
		return false
	end
	if req.offhand == nil then
		return true
	end
	if req.main and weapons.main and TWO_HANDED[weapons.main] then
		return true -- a listed two-hander needs no off-hand
	end
	return weapons.offhand ~= nil and table.find(req.offhand, weapons.offhand) ~= nil
end

local function typeOfItem(item: any): string?
	if type(item) ~= "table" or type(item.id) ~= "string" then
		return nil
	end
	local def = Items.get(item.id)
	return if def then def.type else nil
end

-- Base types in the weapon and off-hand slots (an empty slot = nil).
local function weaponTypesOf(equipment: { [string]: any }?): WeaponTypes
	if type(equipment) ~= "table" then
		return {}
	end
	return { main = typeOfItem(equipment.weapon), offhand = typeOfItem(equipment.offhand) }
end

local function hasTeamEffect(effect: any): boolean
	return type(effect) == "table" and not EffectStack.isOwn(effect.category)
end

-- A team node (ROZWOJ 2.2, B3): an aura, a modify node with an effect of a category other than "own", or a node with
-- an explicit dipScale. Effects without a category (heal, shield, invulnerability, heal over time) are not team
-- effects and work in full. Luck nodes never (6.3).
local function isTeamNode(node: PathNode): boolean
	if node.kind == "luck" then
		return false
	end
	if node.kind == "aura" or node.dipScale ~= nil then
		return true
	end
	local bp = node.modify and node.modify.bp
	if type(bp) ~= "table" then
		return false
	end
	for _, key in { "effect", "selfEffect", "allyEffect" } do
		if hasTeamEffect(bp[key]) then
			return true
		end
	end
	for _, key in { "effects", "selfEffects", "allyEffects" } do
		local list = bp[key]
		if type(list) == "table" then
			for _, effect in list do
				if hasTeamEffect(effect) then
					return true
				end
			end
		end
	end
	return false
end

-- Each node.values field at `rank`: linear { rank 1, rank max } over maxRank (maxRank 1: the first value; a constant
-- stays), times `scale` (default 1).
local function nodeValues(node: PathNode, rank: number, scale: number?): { [string]: number }
	local out: { [string]: number } = {}
	local s = scale or 1
	local fields: { [string]: PathData.Scaled } = node.values or {}
	for field, value in fields do
		local v: number
		if type(value) == "number" then
			v = value
		else
			local first, last = value[1], value[2] or value[1]
			if node.maxRank <= 1 then
				v = first
			else
				local t = math.clamp((rank - 1) / (node.maxRank - 1), 0, 1)
				v = first + (last - first) * t
			end
		end
		out[field] = v * s
	end
	return out
end

-- ROZWOJ 2.10 (B5): where an edit may happen. The server builds the context itself. Build sets (S58, ROZWOJ 2.9):
-- switching needs a living character outside a dungeon run, out of combat, in town or at a gate; copying only a
-- living character out of combat (it does not touch the active set). S138 (DESIGN-18 §3.2): a node refund below
-- Progression.freeRespecLevel (ctx.level) works anywhere out of combat, from it in town or at a gate (and costs gold).
local function canEdit(ctx: EditCtx): (boolean, string?)
	local action = ctx.action
	if action == "switchSet" or action == "copySet" then
		if ctx.dead then
			return false, "buildset.error.dead"
		end
		if action == "switchSet" and ctx.inRun then
			return false, "buildset.error.run"
		end
		if ctx.inCombat then
			return false, "paths.error.combat"
		end
		if action == "copySet" or ctx.inTown or ctx.nearGate then
			return true, nil
		end
		return false, "paths.error.place"
	end
	if ctx.inCombat then
		return false, "paths.error.combat"
	end
	if action == "buy" or action == "chooseBp" then
		return true, nil
	elseif action == "refund" or action == "changeBp" then
		if ctx.inTown or ctx.nearGate then
			return true, nil
		end
		if action == "refund" and ctx.level ~= nil and ctx.level < Progression.freeRespecLevel then
			return true, nil
		end
		return false, "paths.error.place"
	end
	return false, "error.badRequest"
end

local function pointsAt(level: number): number
	return math.floor(level / Progression.pathPointsEvery)
end

-- S137 (DESIGN-18 §3.1): skill points of one weapon pool at `level` (Logic/SkillPoints.pointsAt).
local function skillPointsAt(level: number): number
	local rule: any = Progression.skillPoints
	return math.max(0, math.floor(level * rule.perLevel + (rule.bonus or 0)))
end

local NO_RANKS: { [string]: number } = table.freeze({})

-- The raw bought ranks of one pool (a frozen empty table when missing or broken).
local function ranksOf(character: Char, poolId: string): { [string]: number }
	local all: any = character.ranks
	if type(all) ~= "table" then
		return NO_RANKS
	end
	local own = all[poolId]
	return if type(own) == "table" then own else NO_RANKS
end

-- A bought rank as a whole number >= 0 (anything else counts 0).
local function boughtIn(character: Char, poolId: string, skillId: string): number
	local value = ranksOf(character, poolId)[skillId]
	if type(value) ~= "number" or value ~= value or value < 1 then
		return 0
	end
	return math.floor(math.min(value, 1e6))
end

-- The pool `hotbar` belongs to: barPool when it is a pool of the class, else the active pool.
local function barPoolOf(character: Char): string?
	local pool = character.barPool
	if SkillPools.valid(character.class, pool) then
		return pool
	end
	return SkillPools.activePool(character)
end

-- Resolves { ref = field } in a modify.bp copy: inside `mul` 1 + (x - 1) * scale, elsewhere x * scale.
local function resolveRefs(value: any, values: { [string]: number }, scale: number, inMul: boolean): any
	if type(value) ~= "table" then
		return value
	end
	local ref = value.ref
	if type(ref) == "string" then
		local x = values[ref] or 0
		return if inMul then 1 + (x - 1) * scale else x * scale
	end
	local out = {}
	for key, inner in value do
		out[key] = resolveRefs(inner, values, scale, inMul or key == "mul")
	end
	return out
end

-- values fields referenced as { ref = field } inside any `mul` table of a modify.bp (they scale as 1 + (x - 1) * s).
local function mulRefs(value: any, inMul: boolean, out: { [string]: boolean })
	if type(value) ~= "table" then
		return
	end
	if type(value.ref) == "string" then
		if inMul then
			out[value.ref] = true
		end
		return
	end
	for key, inner in value do
		mulRefs(inner, inMul or key == "mul", out)
	end
end

-- Arguments of node.descKey at `rank` (S59): one per node.values field (the placeholder = the field name), scaled as
-- skillMods resolves references (a field used inside modify.bp `mul` as 1 + (v - 1) * scale, others v * scale) and
-- rounded as skill descriptions (Skills.roundArg). A node without values gives {}.
-- S71 (ROZWOJ 3.1): a field used inside `mul` also gives <field>Pct = |1 - v| x 100 of the same scaled value (texts
-- show multipliers as a % change: 0.92 -> 8, which roundArg would show as 0.9).
local function nodeArgs(node: PathNode, rank: number, scale: number?): { [string]: number }
	local s = scale or 1
	local inMul: { [string]: boolean } = {}
	if node.modify then
		mulRefs(node.modify.bp, false, inMul)
	end
	local out: { [string]: number } = {}
	for field, v in nodeValues(node, rank, 1) do
		local x = if inMul[field] then 1 + (v - 1) * s else v * s
		out[field] = Skills.roundArg(x)
		if inMul[field] then
			out[field .. "Pct"] = Skills.roundArg(math.abs(1 - x) * 100)
		end
	end
	return out
end

-- The weapon type of a path's icon (S59, S60 path sign): the first main type, else the first off-hand type, else nil
-- (the UI shows the class glyph).
local function iconWeapon(def: PathDef): string?
	local req = def.weapon
	if req == nil then
		return nil
	end
	if req.main and req.main[1] then
		return req.main[1]
	end
	if req.offhand and req.offhand[1] then
		return req.offhand[1]
	end
	return nil
end

local function isTwoHanded(itemType: string): boolean
	return TWO_HANDED[itemType] == true
end

-- Sources -----------------------------------------------------------------------------------------------------------

local function sourceOf(paths: { PathDef }, extraSkills: { SkillDef }?): Source
	local byId: { [string]: PathDef } = {}
	local byClass: { [string]: { PathDef } } = {}
	for _, path in paths do
		byId[path.id] = path
		local own = byClass[path.class]
		if not own then
			own = {}
			byClass[path.class] = own
		end
		table.insert(own, path)
	end
	for _, own in byClass do
		table.sort(own, function(a: PathDef, b: PathDef): boolean
			return a.order < b.order
		end)
	end
	local skillById: { [string]: SkillDef } = {}
	local skillsOf: { [string]: { SkillDef } } = {}
	local function addSkill(skill: SkillDef)
		skillById[skill.id] = skill
		local own = skillsOf[skill.class]
		if not own then
			own = {}
			skillsOf[skill.class] = own
		end
		table.insert(own, skill)
	end
	for _, classId in Classes.order do
		local list: { SkillDef } = SkillData.byClass[classId] or {}
		for _, skill in list do
			addSkill(skill)
		end
	end
	local extra: { SkillDef } = extraSkills or {}
	for _, skill in extra do
		addSkill(skill)
	end
	local none: { any } = {}
	return {
		pathsOf = function(classId: string): { PathDef }
			return byClass[classId] or none
		end,
		path = function(pathId: string): PathDef?
			return byId[pathId]
		end,
		skill = function(skillId: string): SkillDef?
			return skillById[skillId]
		end,
		classSkills = function(classId: string): { SkillDef }
			return skillsOf[classId] or none
		end,
	}
end

-- The API over one source -------------------------------------------------------------------------------------------

type Found = { node: PathNode, path: PathDef, row: number }

local build: (source: Source) -> any

local function buildApi(source: Source)
	local nodeCache: { [string]: Found } = {}
	local skillNodeCache: { [string]: Found } = {}

	-- The node, its path and its row. Node ids are "<pathId>_<name>"; a path id may hold "_" too, so every split is
	-- tried. Only hits are cached (ids come from clients).
	local function find(nodeId: string): Found?
		local hit = nodeCache[nodeId]
		if hit then
			return hit
		end
		if type(nodeId) ~= "string" then
			return nil
		end
		local from = 1
		while true do
			local at = string.find(nodeId, "_", from, true)
			if not at then
				return nil
			end
			local path = source.path(string.sub(nodeId, 1, at - 1))
			if path then
				for r, row in path.rows do
					for _, node in row.nodes do
						if node.id == nodeId then
							local found = { node = node, path = path, row = r }
							nodeCache[nodeId] = found
							return found
						end
					end
				end
			end
			from = at + 1
		end
	end

	local function findNode(nodeId: string): (PathNode?, PathDef?, number?)
		local found = find(nodeId)
		if not found then
			return nil, nil, nil
		end
		return found.node, found.path, found.row
	end

	-- The "skill" node that gives a path skill.
	local function skillNode(skill: SkillDef): Found?
		local hit = skillNodeCache[skill.id]
		if hit then
			return hit
		end
		local path = skill.path and source.path(skill.path)
		if not path or path.class ~= skill.class then
			return nil
		end
		for r, row in path.rows do
			for _, node in row.nodes do
				if node.kind == "skill" and node.skill == skill.id then
					local found = { node = node, path = path, row = r }
					skillNodeCache[skill.id] = found
					return found
				end
			end
		end
		return nil
	end

	local function pathsOf(classId: string): { PathDef }
		return source.pathsOf(classId)
	end

	local function classHasPaths(classId: string): boolean
		return #source.pathsOf(classId) > 0
	end

	-- In the game a path exists when it has a PathDef (the wiki looks at `wiki ~= false` on its own).
	local function isPublished(pathId: string): boolean
		return source.path(pathId) ~= nil
	end

	local function rowsFor(classId: string): { RowInfo }
		local twoPaths = #source.pathsOf(classId) == 2
		local out: { RowInfo } = {}
		for i, row in ROWS do
			table.insert(out, {
				index = i,
				level = row.level,
				need = row.need,
				kind = row.kind,
				choice = row.kind == "choice",
				extra = row.twoPathExtra == true and twoPaths,
			})
		end
		return out
	end

	local function rowRanks(nodes: { [string]: number }, path: PathDef, row: number): number
		local total = 0
		local def = path.rows[row]
		if def then
			for _, node in def.nodes do
				total += rankIn(nodes, node.id)
			end
		end
		return total
	end

	-- Ranks bought in the rows below `row` of the path (ROZWOJ 2.2: a row's point requirement).
	local function ranksBelow(nodes: { [string]: number }, path: PathDef, row: number): number
		local total = 0
		for r = 1, row - 1 do
			total += rowRanks(nodes, path, r)
		end
		return total
	end

	-- Ranks the character has in the rows below `row` of a path (the window's "have / need").
	local function ranksIn(character: Char, pathId: string, row: number): number
		local path = source.path(pathId)
		return if path then ranksBelow(stateOf(character).nodes, path, row) else 0
	end

	-- Sum of node ranks of the character's class (unknown ids are skipped).
	local function spentOf(classId: string, nodes: { [string]: number }): number
		local total = 0
		for id, rank in nodes do
			local found = find(id)
			if found and found.path.class == classId and type(rank) == "number" and rank > 0 then
				total += rank
			end
		end
		return total
	end

	local function spent(character: Char): number
		return spentOf(character.class, stateOf(character).nodes)
	end

	-- Free path points; negative after /node (the window shows max(0, ...)).
	local function free(character: Char): number
		return pointsAt(character.level) - spent(character)
	end

	local function rowOpen(character: Char, pathId: string, row: number): (boolean, string?)
		local path = source.path(pathId)
		if not path or path.class ~= character.class or ROWS[row] == nil then
			return false, "paths.error.unknown"
		end
		local state = stateOf(character)
		if character.level < ROWS[row].level then
			return false, "paths.error.level"
		end
		if ranksBelow(state.nodes, path, row) < ROWS[row].need then
			return false, "paths.error.need"
		end
		return true, nil
	end

	-- Ranks bought in one path (every row).
	local function spentIn(nodes: { [string]: number }, path: PathDef): number
		return ranksBelow(nodes, path, #ROWS + 1)
	end

	-- S138: does the path have its capstone (row kind "capstone") bought?
	local function hasCapstone(nodes: { [string]: number }, path: PathDef): boolean
		for r, row in ROWS do
			if row.kind == "capstone" and rowRanks(nodes, path, r) > 0 then
				return true
			end
		end
		return false
	end

	-- S138 (DESIGN-18 §7): the leading direction of a node map: the path of the class with the most ranks, at least
	-- MAIN_MIN_POINTS; a tie goes to the lower order (pathsOf is sorted by order); nil below the threshold.
	local function mainOfNodes(classId: string, nodes: { [string]: number }): string?
		local best: string?, bestRanks = nil, MAIN_MIN_POINTS - 1
		for _, path in source.pathsOf(classId) do
			local ranks = spentIn(nodes, path)
			if ranks > bestRanks then
				best, bestRanks = path.id, ranks
			end
		end
		return best
	end

	local function mainOf(character: Char): string?
		return mainOfNodes(character.class, stateOf(character).nodes)
	end

	-- Ranks the character has in one direction (S138: the leading direction, the team node rule).
	local function pathSpent(character: Char, pathId: string): number
		local path = source.path(pathId)
		if not path or path.class ~= character.class then
			return 0
		end
		return spentIn(stateOf(character).nodes, path)
	end

	-- S138: the direction whose capstone is bought, nil without one. With two (only an old save or an admin leaves that;
	-- clampToLevel keeps one) the leading direction's, else the lower order's.
	local function capstoneOf(character: Char): string?
		local nodes = stateOf(character).nodes
		local main = mainOf(character)
		local first: string? = nil
		for _, path in source.pathsOf(character.class) do
			if hasCapstone(nodes, path) then
				if path.id == main then
					return path.id
				end
				first = first or path.id
			end
		end
		return first
	end

	-- Directions other than `pathId` with a bought capstone.
	local function otherCapstones(classId: string, nodes: { [string]: number }, pathId: string): number
		local count = 0
		for _, path in source.pathsOf(classId) do
			if path.id ~= pathId and hasCapstone(nodes, path) then
				count += 1
			end
		end
		return count
	end

	-- Buying a rank; the weapon is not a condition. S138: a capstone only while fewer than CAPSTONES_MAX other
	-- directions have theirs ("skills.error.capstoneTaken"), the upgrade only in the direction with its capstone
	-- ("paths.error.upgrade").
	local function canBuy(character: Char, nodeId: string): (boolean, string?)
		local found = find(nodeId)
		if not found or found.path.class ~= character.class then
			return false, "paths.error.unknown"
		end
		local state = stateOf(character)
		if rankIn(state.nodes, nodeId) >= found.node.maxRank then
			return false, "paths.error.maxRank"
		end
		if free(character) < 1 then
			return false, "paths.error.points"
		end
		local open, err = rowOpen(character, found.path.id, found.row)
		if not open then
			return false, err
		end
		if found.path.rows[found.row].choice then
			for _, other in found.path.rows[found.row].nodes do
				if other.id ~= nodeId and rankIn(state.nodes, other.id) > 0 then
					return false, "paths.error.choice"
				end
			end
		end
		local kind = ROWS[found.row].kind
		if kind == "capstone" and otherCapstones(character.class, state.nodes, found.path.id) >= CAPSTONES_MAX then
			return false, "skills.error.capstoneTaken"
		end
		if kind == "upgrade" and not hasCapstone(state.nodes, found.path) then
			return false, "paths.error.upgrade"
		end
		return true, nil
	end

	-- Refunding one rank: every higher row of the path with ranks still meets its requirement.
	local function canRefund(character: Char, nodeId: string): (boolean, string?)
		local found = find(nodeId)
		if not found or found.path.class ~= character.class then
			return false, "paths.error.unknown"
		end
		local state = stateOf(character)
		local rank = rankIn(state.nodes, nodeId)
		if rank <= 0 then
			return false, "paths.error.noRank"
		end
		local nodes = table.clone(state.nodes)
		nodes[nodeId] = rank - 1
		for r = found.row + 1, #ROWS do
			if rowRanks(nodes, found.path, r) > 0 and ranksBelow(nodes, found.path, r) < ROWS[r].need then
				return false, "paths.error.needAbove"
			end
			-- S138: an upgrade stays only with its capstone
			if
				ROWS[r].kind == "upgrade"
				and rowRanks(nodes, found.path, r) > 0
				and not hasCapstone(nodes, found.path)
			then
				return false, "paths.error.needAbove"
			end
		end
		return true, nil
	end

	local function copyState(state: PathState, nodes: { [string]: number }): PathState
		return { nodes = nodes, bp = table.clone(state.bp or {}) }
	end

	-- Refunds ranks from the top (highest rows first, in a row from the last node, rank by rank). `path` limits it to
	-- one path, `fromRow` to rows >= fromRow, `points` to that many ranks (nil = every matching rank). bp stays.
	local function refundNodes(classId: string, nodesIn: { [string]: number }, opts: RefundOpts?): { [string]: number }
		local nodes = table.clone(nodesIn)
		local budget = if opts and opts.points then opts.points else math.huge
		local fromRow = if opts and opts.fromRow then math.max(1, opts.fromRow) else 1
		local only = opts and opts.path
		local paths = source.pathsOf(classId)
		for r = #ROWS, fromRow, -1 do
			for p = #paths, 1, -1 do
				local path = paths[p]
				if only == nil or path.id == only then
					local row = path.rows[r]
					local list = if row then row.nodes else {}
					for i = #list, 1, -1 do
						local id = list[i].id
						local rank = rankIn(nodes, id)
						while rank > 0 and budget > 0 do
							rank -= 1
							budget -= 1
						end
						if nodes[id] ~= nil then
							nodes[id] = if rank > 0 then rank else nil :: any
						end
						if budget <= 0 then
							return nodes
						end
					end
				end
			end
		end
		return nodes
	end

	local function refund(character: Char, opts: RefundOpts?): PathState
		local state = stateOf(character)
		return copyState(state, refundNodes(character.class, state.nodes, opts))
	end

	-- A path skill's node rule (S57; S138: in every direction): a PathDef, its "skill" node bought, the row level
	-- reached. Its ranks are bought in every pool (Logic/SkillPoints).
	local function pathSkillOpen(character: Char, skill: SkillDef): boolean
		local found = skillNode(skill)
		if not found then
			return false
		end
		if rankIn(stateOf(character).nodes, found.node.id) <= 0 then
			return false
		end
		return character.level >= ROWS[found.row].level
	end

	-- S137: may `skill` hold ranks in the pool (default: the active one)? A skill of the class and of the pool
	-- (Logic/SkillPools; path skills of every pool) and, for a path skill, its node rule.
	local function skillOpen(character: Char, skillId: string, poolId: string?): boolean
		local skill = source.skill(skillId)
		if not skill or skill.class ~= character.class then
			return false
		end
		local pool = poolId or SkillPools.activePool(character)
		if pool == nil or not SkillPools.memberDef(character.class, pool, skill) then
			return false
		end
		return skill.path == nil or pathSkillOpen(character, skill)
	end

	-- Rank of a skill (S137, DESIGN-18 §3.1): the rank bought in the pool (default: the active pool, the equipped
	-- weapon), at most the old level curve (Skills.rankAt is the limit); 0 outside the pool, for a path skill without
	-- its node (pathSkillOpen) and for another class. The one rank every consumer asks for.
	local function skillRank(character: Char, skillId: string, poolId: string?): number
		local skill = source.skill(skillId)
		if not skill or skill.class ~= character.class then
			return 0
		end
		local pool = poolId or SkillPools.activePool(character)
		if pool == nil or not SkillPools.memberDef(character.class, pool, skill) then
			return 0
		end
		if skill.path ~= nil and not pathSkillOpen(character, skill) then
			return 0
		end
		return math.min(boughtIn(character, pool, skillId), Skills.rankAt(skill, character.level))
	end

	-- Skills with rank > 0 in the pool (default: the active one): the base in data order, then the paths (order, rows).
	local function availableSkills(character: Char, poolId: string?): { string }
		local out: { string } = {}
		for _, skill in source.classSkills(character.class) do
			if skill.path == nil and skillRank(character, skill.id, poolId) > 0 then
				table.insert(out, skill.id)
			end
		end
		for _, path in source.pathsOf(character.class) do
			for _, row in path.rows do
				for _, node in row.nodes do
					if node.kind == "skill" and node.skill and skillRank(character, node.skill, poolId) > 0 then
						table.insert(out, node.skill)
					end
				end
			end
		end
		return out
	end

	-- A base skill of the active pool (S137: "cast.error.wrongPool" for a skill of another pool), rank > 0 and, for a path
	-- skill, the node's own weapon (every row; S138: a direction has no weapon). The Mage element check stays in
	-- SkillService.
	local function skillUsable(character: Char, skillId: string, weapons: WeaponTypes): (boolean, string?)
		local def = source.skill(skillId)
		if def and def.class == character.class and def.path == nil then
			local pool = SkillPools.activePool(character)
			if pool and not SkillPools.memberDef(character.class, pool, def) then
				return false, "cast.error.wrongPool"
			end
		end
		if skillRank(character, skillId) <= 0 then
			return false, "cast.error.notLearned"
		end
		local skill = source.skill(skillId) :: SkillDef
		if skill.path == nil then
			return true, nil
		end
		local found = skillNode(skill) :: Found
		if found.node.weapon and not weaponOk(found.node.weapon, weapons) then
			return false, "cast.error.pathWeapon"
		end
		return true, nil
	end

	-- B3 for any node, bought or not (S59; S138, DESIGN-18 §7): a team node of rows 1..DIP_ROWS works at node.dipScale or
	-- DIP_SCALE while its direction has fewer than TEAM_FULL_POINTS ranks, everything else at 1. The one place of the
	-- rule (activeNodes, the window).
	local function nodeScale(character: Char, pathId: string, row: number, node: PathNode): number
		if row <= DIP_ROWS and isTeamNode(node) and pathSpent(character, pathId) < TEAM_FULL_POINTS then
			return node.dipScale or DIP_SCALE
		end
		return 1
	end

	-- Nodes that work now: rank > 0, row level reached, node.weapon fits (every row; S138: no main path and no
	-- direction weapon). Order: row, then path order, then place in the row.
	local function activeNodes(character: Char, weapons: WeaponTypes): { ActiveNode }
		local out: { ActiveNode } = {}
		local state = stateOf(character)
		local paths = source.pathsOf(character.class)
		for r, row in ROWS do
			if character.level < row.level then
				break
			end
			for _, path in paths do
				local def = path.rows[r]
				local list: { PathNode } = if def then def.nodes else {}
				for _, node in list do
					local rank = math.min(rankIn(state.nodes, node.id), node.maxRank)
					if rank > 0 and (node.weapon == nil or weaponOk(node.weapon, weapons)) then
						table.insert(out, {
							node = node,
							path = path,
							row = r,
							rank = rank,
							scale = nodeScale(character, path.id, r, node),
						})
					end
				end
			end
		end
		return out
	end

	-- Raw luck fields of active nodes (ROZWOJ 6.3, S60): node.luck maps a Data/Luck field to a node.values field, at
	-- the node rank and without scale (luck nodes carry their own values for the dip). Unknown fields are skipped;
	-- Logic/Luck applies the caps.
	local function luckOfNodes(active: { ActiveNode }): { [string]: number }
		local out: { [string]: number } = {}
		for _, entry in active do
			local luck = entry.node.luck
			if luck then
				local values = nodeValues(entry.node, entry.rank)
				for field, valueKey in luck do
					if LuckData.fields[field] then
						out[field] = (out[field] or 0) + (values[valueKey] or 0)
					end
				end
			end
		end
		return out
	end

	local function luck(character: Char, weapons: WeaponTypes): { [string]: number }
		return luckOfNodes(activeNodes(character, weapons))
	end

	-- Party auras of the active aura nodes (ROZWOJ 7.3, S61): stats at the node rank times entry.scale (nodeScale),
	-- shape and radius with their defaults.
	local function auras(character: Char, weapons: WeaponTypes): { Aura }
		local out: { Aura } = {}
		for _, entry in activeNodes(character, weapons) do
			local node = entry.node
			local def = node.aura
			if node.kind ~= "aura" or def == nil then
				continue
			end
			local values = nodeValues(node, entry.rank, entry.scale)
			local stats: { [string]: number } = {}
			for stat, field in def.stats do
				stats[stat] = values[field] or 0
			end
			local shape: "circle" | "behind" = if def.shape == "behind" then "behind" else "circle"
			table.insert(out, {
				nodeId = node.id,
				category = def.category,
				stats = stats,
				shape = shape,
				radius = def.radius or (if shape == "behind" then AURA.behindRadius else AURA.radius),
			})
		end
		return out
	end

	-- Modify nodes of the skill as resolved breakpoint tables, in row order (ROZWOJ 2.7). A node with modify.option
	-- works only while that option is chosen at rank modify.at (default 5).
	local function skillMods(character: Char, skillId: string, weapons: WeaponTypes): { Skills.SkillMod }
		local out: { Skills.SkillMod } = {}
		local skill = source.skill(skillId)
		if not skill then
			return out
		end
		local state = stateOf(character)
		for _, active in activeNodes(character, weapons) do
			local modify = active.node.modify
			if modify and modify.skill == skillId then
				if modify.option == nil or Skills.chosen(skill, modify.at or 5, state.bp) == modify.option then
					local values = nodeValues(active.node, active.rank, 1)
					table.insert(out, resolveRefs(modify.bp, values, active.scale, false))
				end
			end
		end
		return out
	end

	-- The skill as it works for the character: rank (at least 1, as the locked preview of S56), path.bp choices,
	-- the modify nodes and (S134g) the skill effects of the equipped Legendary / Mythic items of the character's class
	-- (Logic/ItemEffects.mods, after the nodes). The one call for every consumer (server, skill bar, aim, description).
	local function effectiveFor(
		character: Char,
		skillId: string,
		weapons: WeaponTypes,
		rank: number?
	): (SkillDef, Skills.Behaviour)
		local skill = source.skill(skillId)
		assert(skill, `Paths.effectiveFor: unknown skill {skillId}`)
		local r = rank or math.max(1, skillRank(character, skillId))
		local mods = skillMods(character, skillId, weapons)
		for _, mod in ItemEffects.mods(character, skillId) do
			table.insert(mods, mod :: any)
		end
		return Skills.effective(skill, r, stateOf(character).bp, mods)
	end

	-- Base passives (rank > 0), path skill passives only while usable, and node.passive of the active nodes.
	local function passiveTotals(character: Char, weapons: WeaponTypes): Skills.PassiveTotals
		local totals: Skills.PassiveTotals = { flat = {}, pct = {}, hooks = {} }
		for _, skill in source.classSkills(character.class) do
			if skill.passive then
				-- a path skill's passive needs the skill usable (node.weapon)
				if skill.path == nil or skillUsable(character, skill.id, weapons) then
					Skills.addPassive(totals, skill, skillRank(character, skill.id))
				end
			end
		end
		for _, active in activeNodes(character, weapons) do
			local passive = active.node.passive
			if passive then
				local values = nodeValues(active.node, active.rank, active.scale)
				local flat: { [string]: string } = passive.flat or {}
				local pct: { [string]: string } = passive.pct or {}
				local hooks: { [string]: string } = passive.hooks or {}
				for stat, field in flat do
					totals.flat[stat] = (totals.flat[stat] or 0) + (values[field] or 0)
				end
				for stat, field in pct do
					totals.pct[stat] = (totals.pct[stat] or 0) + (values[field] or 0)
				end
				for hook, field in hooks do
					totals.hooks[hook] = (totals.hooks[hook] or 0) + (values[field] or 0)
				end
			end
		end
		return totals
	end

	-- S137: in the pool (default: the active one).
	local function onBarAllowed(character: Char, skill: SkillDef?, poolId: string?): boolean
		return skill ~= nil
			and skill.class == character.class
			and skill.type ~= "passive"
			and skillRank(character, skill.id, poolId) > 0
	end

	local function canPutOnBar(character: Char, skillId: string, poolId: string?): (boolean, string?)
		if onBarAllowed(character, source.skill(skillId), poolId) then
			return true, nil
		end
		return false, "skills.error.locked"
	end

	-- A bar of the pool as the character may keep it (S137): slots "1".."HOTBAR_SLOTS" with an active of the pool with
	-- rank > 0 there, no repeats (the lower slot wins). Second value: anything changed.
	local function validBar(character: Char, poolId: string?, barIn: any): ({ [string]: string }, boolean)
		local bar: { [string]: string } = {}
		local changed = false
		local hotbar: any = barIn
		if type(hotbar) ~= "table" then
			hotbar = {}
			changed = true
		end
		local kept, total = 0, 0
		local seen: { [string]: boolean } = {}
		for slot = 1, SkillData.HOTBAR_SLOTS do
			local id = hotbar[tostring(slot)]
			local skill = if type(id) == "string" then source.skill(id) else nil
			if skill and not seen[skill.id] and poolId ~= nil and onBarAllowed(character, skill, poolId) then
				seen[skill.id] = true
				bar[tostring(slot)] = skill.id
				kept += 1
			end
		end
		for _ in hotbar do
			total += 1
		end
		if total ~= kept then
			changed = true
		end
		return bar, changed
	end

	-- The hotbar and path.bp the character may keep (B6): the hotbar as validBar in its pool (barPool, else the active
	-- pool); bp entries "<skillId>:<5|10>" = "a" | "b" of a skill of the class whose breakpoint at that rank has option
	-- B: a base skill always (S137, DESIGN-18 §8: a refunded rank keeps the choice), a path skill while its node exists
	-- (S138: also with the node refunded, so a node refund and the full reset keep the choice; without the node the
	-- skill has rank 0 and the choice does nothing). Third value: anything changed.
	local function validHotbar(character: Char): ({ [string]: string }, { [string]: "a" | "b" }, boolean)
		local bar, changed = validBar(character, barPoolOf(character), character.hotbar)
		local bp: { [string]: "a" | "b" } = {}
		local state = stateOf(character)
		local saved: { [string]: "a" | "b" } = state.bp or {}
		for key, option in saved do
			local skillId, at = string.match(key, "^(.+):(%d+)$")
			local rank = tonumber(at)
			local skill = if skillId then source.skill(skillId) else nil
			local pair = skill and rank and skill.breakpoints and skill.breakpoints[rank]
			if
				skill
				and rank
				and table.find(BP_RANKS, rank)
				and (option == "a" or option == "b")
				and pair
				and pair.b
				and skill.class == character.class
				and (skill.path == nil or skillNode(skill) ~= nil)
			then
				bp[key] = option
			else
				changed = true
			end
		end
		return bar, bp, changed
	end

	-- S137: a breakpoint choice belongs to the set, not to a pool (DESIGN-18 §8): the best rank of the skill in any pool
	-- of the class. S139: the one rank for "reached" (server, tiles, details, phone sheet, the "!").
	local function bpRank(character: Char, skillId: string): number
		local best = 0
		for _, poolId in SkillPools.ids(character.class) do
			best = math.max(best, skillRank(character, skillId, poolId))
		end
		return best
	end

	-- Third value: whether this changes an existing choice. The same choice again is a success without a write.
	local function canChooseBreakpoint(
		character: Char,
		skillId: string,
		rank: number,
		option: string
	): (boolean, string?, boolean)
		local skill = source.skill(skillId)
		if not skill or skill.class ~= character.class or skill.type == "passive" then
			return false, "error.badRequest", false
		end
		if not table.find(BP_RANKS, rank) or (option ~= "a" and option ~= "b") then
			return false, "error.badRequest", false
		end
		if bpRank(character, skillId) < rank then
			return false, "bp.error.rank", false
		end
		local pair = skill.breakpoints and skill.breakpoints[rank]
		if not pair or not pair.b then
			return false, "bp.error.noOption", false
		end
		local current = (stateOf(character).bp or {})[Skills.choiceKey(skillId, rank)]
		return true, nil, current ~= nil and current ~= option
	end

	-- The state a character of `level` may keep (load, SetLevel down, admin leftovers): unknown / other class / rank <= 0
	-- nodes go, ranks above maxRank are cut, rows above the level go, a choice row keeps its first bought node; S138:
	-- capstones of more than CAPSTONES_MAX directions keep the leading direction's (else the lower order's) and the
	-- others go with their upgrades; a row without its requirement (or an upgrade without its capstone) goes with every
	-- higher row of its path, and points above pointsAt(level) are refunded from the top. bp stays; the old `main` and
	-- `freeUsed` are not copied. Deterministic.
	local function clampToLevel(character: Char, level: number): PathState
		local state = stateOf(character)
		local classId = character.class
		local nodes: { [string]: number } = {}
		local saved: { [string]: number } = state.nodes or {}
		for id, rank in saved do
			local found = if type(id) == "string" then find(id) else nil
			if found and found.path.class == classId and type(rank) == "number" and rank >= 1 then
				if ROWS[found.row].level <= level then
					nodes[id] = math.min(math.floor(rank), found.node.maxRank)
				end
			end
		end
		local paths = source.pathsOf(classId)
		for _, path in paths do
			for _, row in path.rows do
				if row.choice then
					local keep = false
					for _, node in row.nodes do
						if nodes[node.id] then
							if keep then
								nodes[node.id] = nil
							end
							keep = true
						end
					end
				end
			end
		end
		-- S138: at most CAPSTONES_MAX capstones, the leading direction's first, then by order
		local keptCapstones: { [string]: boolean } = {}
		local capstones = 0
		local leading = mainOfNodes(classId, nodes)
		local leadingPath = if leading then source.path(leading) else nil
		if leadingPath and hasCapstone(nodes, leadingPath) then
			keptCapstones[leadingPath.id] = true
			capstones = 1
		end
		for _, path in paths do
			if not keptCapstones[path.id] and hasCapstone(nodes, path) then
				if capstones < CAPSTONES_MAX then
					keptCapstones[path.id] = true
					capstones += 1
				else
					for r, row in ROWS do
						if row.kind == "capstone" or row.kind == "upgrade" then
							for _, node in path.rows[r].nodes do
								nodes[node.id] = nil
							end
						end
					end
				end
			end
		end
		for _, path in paths do
			for r = 1, #ROWS do
				local broken = ranksBelow(nodes, path, r) < ROWS[r].need
					or (ROWS[r].kind == "upgrade" and not hasCapstone(nodes, path))
				if rowRanks(nodes, path, r) > 0 and broken then
					for above = r, #ROWS do
						for _, node in path.rows[above].nodes do
							nodes[node.id] = nil
						end
					end
					break
				end
			end
		end
		local excess = spentOf(classId, nodes) - pointsAt(level)
		if excess > 0 then
			nodes = refundNodes(classId, nodes, { points = excess })
		end
		return { nodes = nodes, bp = table.clone(state.bp or {}) }
	end

	-- S137 (DESIGN-18 §10, Logic/SkillPoints.clean): the bought ranks a character may keep. Every pool of the class
	-- keeps whole ranks >= 1 of skills that may hold ranks there (skillOpen: of the pool, a path skill with its node),
	-- each at most its limit (Skills.rankAt); points above skillPointsAt(level) go back from the end of the pool's order
	-- (SkillPools.members: the plan, other base members, path skills; unknown ids last), rank by rank. Pools of another
	-- class and broken entries go. Second value: anything changed.
	local function cleanRanks(character: Char): ({ [string]: { [string]: number } }, boolean)
		local out: { [string]: { [string]: number } } = {}
		local level = character.level
		for _, poolId in SkillPools.ids(character.class) do
			local own: { [string]: number } = {}
			local total = 0
			for id, value in ranksOf(character, poolId) do
				if type(id) == "string" and type(value) == "number" and value == value and value >= 1 then
					local skill = source.skill(id)
					if skill and skillOpen(character, id, poolId) then
						local rank = math.min(math.floor(value), Skills.rankAt(skill, level))
						if rank > 0 then
							own[id] = rank
							total += rank
						end
					end
				end
			end
			local excess = total - skillPointsAt(level)
			if excess > 0 then
				local order = SkillPools.members(character.class, poolId)
				local listed: { [string]: boolean } = {}
				for _, id in order do
					listed[id] = true
				end
				local extra: { string } = {}
				for id in own do
					if not listed[id] then
						table.insert(extra, id)
					end
				end
				table.sort(extra)
				table.move(extra, 1, #extra, #order + 1, order)
				for i = #order, 1, -1 do
					local id = order[i]
					local rank = own[id]
					if rank then
						local cut = math.min(rank, excess)
						excess -= cut
						own[id] = if rank - cut > 0 then rank - cut else nil :: any
						if excess <= 0 then
							break
						end
					end
				end
			end
			if next(own) ~= nil then
				out[poolId] = own
			end
		end
		return out, not TableUtil.deepEqual(out, character.ranks)
	end

	-- Build sets (ROZWOJ 2.9; S58) ------------------------------------------------------------------------------------
	-- The active set lives in the character fields (stats, statPoints, hotbar, path; S137: ranks, bars, barPool,
	-- respecFree, poolsVersion), the other one in buildOther. Every result is a deep copy: the active set and buildOther
	-- never share tables.

	-- S137: an empty set has no bought ranks and empty bars (nothing is bought by itself, DESIGN-18 §3).
	local function emptySet(classId: string, level: number): BuildSet
		return {
			path = { nodes = {}, bp = {} },
			stats = StatPlan.startOf(classId),
			statPoints = StatPlan.total(level),
			hotbar = {},
			ranks = {},
			bars = {},
			barPool = nil,
			respecFree = false,
			poolsVersion = SkillPools.version(classId),
		}
	end

	-- { [string]: table } with string keys only (ranks per pool, bars per pool), deep-copied.
	local function copyByPool(value: any): { [string]: any }
		local out: { [string]: any } = {}
		if type(value) == "table" then
			for key, inner in value do
				if type(key) == "string" and type(inner) == "table" then
					out[key] = TableUtil.deepCopy(inner)
				end
			end
		end
		return out
	end

	-- A deep copy; missing or broken fields are filled as in emptySet (a broken save never stops the server).
	local function cloneSet(set: any, classId: string, level: number): BuildSet
		local src: any = if type(set) == "table" then set else {}
		local pathIn: any = if type(src.path) == "table" then src.path else {}
		local stats: Types.Stats = if type(src.stats) == "table"
			then TableUtil.deepCopy(src.stats)
			else StatPlan.startOf(classId)
		local points = src.statPoints
		if type(points) ~= "number" then
			points = math.max(0, StatPlan.total(level) - StatPlan.spent(classId, stats :: any))
		end
		return {
			-- S138: the old `main` / `freeUsed` are not copied
			path = {
				nodes = if type(pathIn.nodes) == "table" then TableUtil.deepCopy(pathIn.nodes) else {},
				bp = if type(pathIn.bp) == "table" then TableUtil.deepCopy(pathIn.bp) else {},
			},
			stats = stats,
			statPoints = points,
			hotbar = if type(src.hotbar) == "table" then TableUtil.deepCopy(src.hotbar) else {},
			ranks = copyByPool(src.ranks),
			bars = copyByPool(src.bars),
			barPool = if type(src.barPool) == "string" and src.barPool ~= "" then src.barPool else nil,
			respecFree = src.respecFree == true,
			-- a set without the field counts as current (migration 12 writes it on every saved set)
			poolsVersion = if type(src.poolsVersion) == "number" then src.poolsVersion else SkillPools.version(classId),
		}
	end

	local function activeSet(character: any): BuildSet
		return cloneSet({
			path = character.path,
			stats = character.stats,
			statPoints = character.statPoints,
			hotbar = character.hotbar,
			ranks = character.ranks,
			bars = character.bars,
			barPool = character.barPool,
			respecFree = character.respecFree,
			poolsVersion = character.poolsVersion,
		}, character.class, character.level)
	end

	local function otherSet(character: any): BuildSet
		if type(character.buildOther) == "table" then
			return cloneSet(character.buildOther, character.class, character.level)
		end
		return emptySet(character.class, character.level)
	end

	local function swapSets(character: any): SetSwap
		return {
			active = otherSet(character),
			other = activeSet(character),
			slot = if character.buildSlot == 2 then 1 else 2,
		}
	end

	-- The new buildOther: the active set, but the target keeps its own respecFree (a copy never returns a free reset).
	local function copySet(character: any): BuildSet
		local set = activeSet(character)
		local other = character.buildOther
		set.respecFree = type(other) == "table" and other.respecFree == true
		return set
	end

	-- A character-shaped view of a set for the rules above (they read class, level, path, hotbar, equipment; S137:
	-- ranks, bars, barPool).
	local function setView(character: any, set: BuildSet, level: number?): any
		return {
			class = character.class,
			level = level or character.level,
			path = set.path,
			hotbar = set.hotbar,
			stats = set.stats,
			statPoints = set.statPoints,
			equipment = character.equipment,
			ranks = set.ranks,
			bars = set.bars,
			barPool = set.barPool,
			respecFree = set.respecFree,
			poolsVersion = set.poolsVersion,
		}
	end

	-- A set as `level` allows (load, SetLevel down): broken fields repaired, the path clamped, the ranks cleaned
	-- (cleanRanks), the bar of barPool, the other pools' bars and path.bp checked; stats stay. Second value: anything
	-- changed.
	local function cleanSet(character: any, set: any, level: number): (BuildSet, boolean)
		local out = cloneSet(set, character.class, level)
		out.path = clampToLevel(setView(character, out, level), level)
		out.ranks = (cleanRanks(setView(character, out, level)))
		if out.barPool ~= nil and not SkillPools.valid(character.class, out.barPool) then
			out.barPool = nil
		end
		local view = setView(character, out, level)
		local bar, bp = validHotbar(view)
		out.hotbar = bar
		out.path.bp = bp
		local bars: { [string]: { [string]: string } } = {}
		for poolId, other in out.bars do
			if poolId ~= out.barPool and SkillPools.valid(character.class, poolId) then
				bars[poolId] = (validBar(view, poolId, other))
			end
		end
		out.bars = bars
		return out, not TableUtil.deepEqual(out, set)
	end

	-- ROZWOJ 2.11: the leading direction's statPlan (S138: mainOf) and its PathDef, else the class plan; unknown
	-- class {}.
	local function statPlan(character: Char): ({ [string]: number }, PathDef?)
		local main = mainOf(character)
		local def = if main then source.path(main) else nil
		local own = def and def.statPlan
		if def and own and next(own) ~= nil then
			return own, def
		end
		local class = Classes.get(character.class)
		return if class then class.statPlan else {}, nil
	end

	return {
		ROWS = ROWS,
		DIP_ROWS = DIP_ROWS,
		DIP_SCALE = DIP_SCALE,
		CAPSTONES_MAX = CAPSTONES_MAX,
		MAIN_MIN_POINTS = MAIN_MIN_POINTS,
		TEAM_FULL_POINTS = TEAM_FULL_POINTS,
		SKILL_ROWS = PathData.SKILL_ROWS,
		source = source,
		withSource = function(other: Source): any
			return build(other)
		end,
		sourceOf = sourceOf,
		pathsOf = pathsOf,
		classHasPaths = classHasPaths,
		isPublished = isPublished,
		findNode = findNode,
		rowsFor = rowsFor,
		ranksIn = ranksIn,
		pointsAt = pointsAt,
		skillPointsAt = skillPointsAt,
		spent = spent,
		free = free,
		rowOpen = rowOpen,
		canBuy = canBuy,
		canRefund = canRefund,
		refund = refund,
		mainOf = mainOf,
		pathSpent = pathSpent,
		capstoneOf = capstoneOf,
		skillRank = skillRank,
		skillOpen = skillOpen,
		pathSkillOpen = pathSkillOpen,
		boughtIn = boughtIn,
		barPoolOf = barPoolOf,
		availableSkills = availableSkills,
		skillUsable = skillUsable,
		activeNodes = activeNodes,
		luckOfNodes = luckOfNodes,
		luck = luck,
		auras = auras,
		inAura = inAura,
		AURA = AURA,
		nodeValues = nodeValues,
		nodeScale = nodeScale,
		nodeArgs = nodeArgs,
		iconWeapon = iconWeapon,
		isTwoHanded = isTwoHanded,
		isTeamNode = isTeamNode,
		skillMods = skillMods,
		effectiveFor = effectiveFor,
		passiveTotals = passiveTotals,
		validHotbar = validHotbar,
		validBar = validBar,
		cleanRanks = cleanRanks,
		canPutOnBar = canPutOnBar,
		bpRank = bpRank,
		canChooseBreakpoint = canChooseBreakpoint,
		clampToLevel = clampToLevel,
		weaponOk = weaponOk,
		weaponTypesOf = weaponTypesOf,
		canEdit = canEdit,
		emptySet = emptySet,
		cloneSet = cloneSet,
		activeSet = activeSet,
		otherSet = otherSet,
		swapSets = swapSets,
		copySet = copySet,
		setView = setView,
		cleanSet = cleanSet,
		statPlan = statPlan,
	}
end

build = buildApi

local Paths = buildApi(sourceOf(PathData.list))
export type Api = typeof(Paths)

return Paths
