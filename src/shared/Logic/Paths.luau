--!strict
-- Class paths (ROZWOJ 2.2-2.10, 3.1; S57). Pure. Points, rows, buying and refunding nodes, the main path, path
-- skills, breakpoint choices, the path weapon, node values and skill changes, passives, the hotbar check and the
-- edit rules. Every function reads paths and skills through a Source: the game uses the default module (Data/Paths,
-- Data/Skills), tests build their own with Paths.withSource(Paths.sourceOf(paths, skills)).
-- From a character only `class`, `level`, `path`, `hotbar` and `equipment` are read; a missing `path` is empty.
-- Build sets (S58, ROZWOJ 2.9): swapSets / copySet / cleanSet and friends also read `stats`, `statPoints`,
-- `buildSlot` and `buildOther`.
-- Node numbers (B3): values that depend on the node rank sit in node.values ({ rank 1, rank max }); passive / aura /
-- luck map a stat or field to a values field; in modify.bp any number is { ref = "<values field>" } (inside `mul`
-- it becomes 1 + (x - 1) * scale, elsewhere x * scale). Team nodes of rows 1..DIP_ROWS work outside the main path
-- with scale node.dipScale or DIP_SCALE.
-- S59: nodeScale (that rule for any node), nodeArgs (node description arguments), iconWeapon, isTwoHanded; the
-- window's views live in Logic/PathView.
-- S60: luckOfNodes / luck (raw Data/Luck fields of the active nodes).
-- S61: auras (party auras of the active nodes) and inAura (pure geometry, also Paths.inAura on the module).

local Bases = require("../Data/Items/Bases")
local Classes = require("../Data/Classes")
local EffectStack = require("./EffectStack")
local ItemEffects = require("./ItemEffects")
local Items = require("../Data/Items")
local LuckData = require("../Data/Luck")
local PathData = require("../Data/Paths")
local Progression = require("../Data/Progression")
local SkillData = require("../Data/Skills")
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
	stats: { [string]: number }, -- resolved at the node's rank (x dipScale outside the main path); value categories: { value = n }
	shape: "circle" | "behind",
	radius: number,
}
export type EditAction =
	"buy"
	| "refund"
	| "chooseMain"
	| "changeMain"
	| "chooseBp"
	| "changeBp"
	| "switchSet"
	| "copySet"
-- dead / inRun (S58): only the build set actions read them; nil = false.
export type EditCtx = {
	action: EditAction,
	inCombat: boolean,
	inTown: boolean,
	nearGate: boolean,
	dead: boolean?,
	inRun: boolean?,
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
local MAIN_LEVEL = ROWS[DIP_ROWS + 1].level
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

local EMPTY: PathState = table.freeze({ main = nil, nodes = table.freeze({}), bp = table.freeze({}), freeUsed = false })

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
-- living character out of combat (it does not touch the active set).
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
	if action == "buy" or action == "chooseMain" or action == "chooseBp" then
		return true, nil
	elseif action == "refund" or action == "changeBp" then
		if ctx.inTown or ctx.nearGate then
			return true, nil
		end
		return false, "paths.error.place"
	elseif action == "changeMain" then
		if ctx.inTown then
			return true, nil
		end
		return false, "paths.error.town"
	end
	return false, "error.badRequest"
end

local function pointsAt(level: number): number
	return math.floor(level / Progression.pathPointsEvery)
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
		if row > DIP_ROWS and state.main ~= pathId then
			return false, "paths.error.main"
		end
		if ranksBelow(state.nodes, path, row) < ROWS[row].need then
			return false, "paths.error.need"
		end
		return true, nil
	end

	-- Buying a rank; the weapon is not a condition.
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
		end
		return true, nil
	end

	local function copyState(state: PathState, nodes: { [string]: number }): PathState
		return {
			main = state.main,
			nodes = nodes,
			bp = table.clone(state.bp or {}),
			freeUsed = state.freeUsed == true,
		}
	end

	-- Refunds ranks from the top (highest rows first, in a row from the last node, rank by rank). `path` limits it to
	-- one path, `fromRow` to rows >= fromRow, `points` to that many ranks (nil = every matching rank). main, freeUsed
	-- and bp stay.
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

	-- The third value is the cost: "free" while freeUsed is false, else "scroll".
	local function canChooseMain(character: Char, pathId: string): (boolean, string?, ("free" | "scroll")?)
		local path = source.path(pathId)
		if not path or path.class ~= character.class then
			return false, "paths.error.unknown", nil
		end
		if character.level < MAIN_LEVEL then
			return false, "paths.error.mainLevel", nil
		end
		local state = stateOf(character)
		if state.main == pathId then
			return false, "paths.error.sameMain", nil
		end
		return true, nil, if state.freeUsed then "scroll" else "free"
	end

	-- Rank of a skill: the base from the level (S56); a path skill only with a PathDef, its "skill" node bought, its row
	-- open for the character (rows above DIP_ROWS only in the main path, the row level reached).
	local function skillRank(character: Char, skillId: string): number
		local skill = source.skill(skillId)
		if not skill or skill.class ~= character.class then
			return 0
		end
		if skill.path == nil then
			return Skills.rankFor(character.class, character.level, skill)
		end
		local found = skillNode(skill)
		if not found then
			return 0
		end
		local state = stateOf(character)
		if rankIn(state.nodes, found.node.id) <= 0 then
			return 0
		end
		if found.row > DIP_ROWS and state.main ~= found.path.id then
			return 0
		end
		if character.level < ROWS[found.row].level then
			return 0
		end
		return Skills.rankAt(skill, character.level)
	end

	-- Skills with rank > 0: the base in data order, then the paths (order, rows).
	local function availableSkills(character: Char): { string }
		local out: { string } = {}
		for _, skill in source.classSkills(character.class) do
			if skill.path == nil and skillRank(character, skill.id) > 0 then
				table.insert(out, skill.id)
			end
		end
		for _, path in source.pathsOf(character.class) do
			for _, row in path.rows do
				for _, node in row.nodes do
					if node.kind == "skill" and node.skill and skillRank(character, node.skill) > 0 then
						table.insert(out, node.skill)
					end
				end
			end
		end
		return out
	end

	-- Rank > 0 and, for a path skill, the path weapon (rows above DIP_ROWS) and the node's own weapon (every row).
	-- The Mage element check stays in SkillService.
	local function skillUsable(character: Char, skillId: string, weapons: WeaponTypes): (boolean, string?)
		if skillRank(character, skillId) <= 0 then
			return false, "cast.error.notLearned"
		end
		local skill = source.skill(skillId) :: SkillDef
		if skill.path == nil then
			return true, nil
		end
		local found = skillNode(skill) :: Found
		if found.row > DIP_ROWS and not weaponOk(found.path.weapon, weapons) then
			return false, "cast.error.pathWeapon"
		end
		if found.node.weapon and not weaponOk(found.node.weapon, weapons) then
			return false, "cast.error.pathWeapon"
		end
		return true, nil
	end

	-- B3 for any node, bought or not (S59): a team node of rows 1..DIP_ROWS outside the main path (also without one)
	-- works at node.dipScale or DIP_SCALE, everything else at 1. The one place of the rule (activeNodes, the window).
	local function nodeScale(character: Char, pathId: string, row: number, node: PathNode): number
		if row <= DIP_ROWS and stateOf(character).main ~= pathId and isTeamNode(node) then
			return node.dipScale or DIP_SCALE
		end
		return 1
	end

	-- Nodes that work now: rank > 0, row level reached, rows above DIP_ROWS only of the main path and with its weapon,
	-- node.weapon in every row. Order: row, then path order, then place in the row.
	local function activeNodes(character: Char, weapons: WeaponTypes): { ActiveNode }
		local out: { ActiveNode } = {}
		local state = stateOf(character)
		local paths = source.pathsOf(character.class)
		for r, row in ROWS do
			if character.level < row.level then
				break
			end
			for _, path in paths do
				if r > DIP_ROWS and (state.main ~= path.id or not weaponOk(path.weapon, weapons)) then
					continue
				end
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

	-- Party auras of the active aura nodes (ROZWOJ 7.3, S61): stats at the node rank times entry.scale (already the
	-- dip scale outside the main path), shape and radius with their defaults.
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
				-- a path skill's passive needs the skill usable (path weapon above DIP_ROWS, node.weapon)
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

	local function onBarAllowed(character: Char, skill: SkillDef?): boolean
		return skill ~= nil
			and skill.class == character.class
			and skill.type ~= "passive"
			and skillRank(character, skill.id) > 0
	end

	local function canPutOnBar(character: Char, skillId: string): (boolean, string?)
		if onBarAllowed(character, source.skill(skillId)) then
			return true, nil
		end
		return false, "skills.error.locked"
	end

	-- The hotbar and path.bp the character may keep (B6): bar slots "1".."10" with an active of the class with rank > 0,
	-- no repeats (the lower slot wins); bp entries "<skillId>:<5|10>" = "a" | "b" of a skill with rank > 0 whose
	-- breakpoint at that rank has option B (an entry for a rank not reached yet stays). Third value: anything changed.
	local function validHotbar(character: Char): ({ [string]: string }, { [string]: "a" | "b" }, boolean)
		local bar: { [string]: string } = {}
		local changed = false
		local hotbar: any = character.hotbar
		if type(hotbar) ~= "table" then
			hotbar = {}
			changed = true
		end
		local kept, total = 0, 0
		local seen: { [string]: boolean } = {}
		for slot = 1, SkillData.HOTBAR_SLOTS do
			local id = hotbar[tostring(slot)]
			local skill = if type(id) == "string" then source.skill(id) else nil
			if skill and not seen[skill.id] and onBarAllowed(character, skill) then
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
				and skillRank(character, skill.id) > 0
			then
				bp[key] = option
			else
				changed = true
			end
		end
		return bar, bp, changed
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
		if skillRank(character, skillId) < rank then
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
	-- nodes go, ranks above maxRank are cut, rows above the level and rows above DIP_ROWS of paths other than the main
	-- one go, a main that is not a path of the class becomes nil, a choice row keeps its first bought node, a row
	-- without its requirement goes with every higher row of its path, and points above pointsAt(level) are refunded
	-- from the top. bp and freeUsed stay. Deterministic.
	local function clampToLevel(character: Char, level: number): PathState
		local state = stateOf(character)
		local classId = character.class
		local main = state.main
		local mainPath = if main then source.path(main) else nil
		if not mainPath or mainPath.class ~= classId then
			main = nil
		end
		local nodes: { [string]: number } = {}
		local saved: { [string]: number } = state.nodes or {}
		for id, rank in saved do
			local found = if type(id) == "string" then find(id) else nil
			if found and found.path.class == classId and type(rank) == "number" and rank >= 1 then
				local row = found.row
				if ROWS[row].level <= level and (row <= DIP_ROWS or found.path.id == main) then
					nodes[id] = math.min(math.floor(rank), found.node.maxRank)
				end
			end
		end
		for _, path in source.pathsOf(classId) do
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
			for r = 1, #ROWS do
				if rowRanks(nodes, path, r) > 0 and ranksBelow(nodes, path, r) < ROWS[r].need then
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
		return { main = main, nodes = nodes, bp = table.clone(state.bp or {}), freeUsed = state.freeUsed == true }
	end

	-- Build sets (ROZWOJ 2.9; S58) ------------------------------------------------------------------------------------
	-- The active set lives in the character fields (stats, statPoints, hotbar, path), the other one in buildOther.
	-- Every result is a deep copy: the active set and buildOther never share tables.

	local function emptySet(classId: string, level: number): BuildSet
		return {
			path = { main = nil, nodes = {}, bp = {}, freeUsed = false },
			stats = StatPlan.startOf(classId),
			statPoints = StatPlan.total(level),
			hotbar = Skills.startHotbar(classId, level),
		}
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
			path = {
				main = if type(pathIn.main) == "string" then pathIn.main else nil,
				nodes = if type(pathIn.nodes) == "table" then TableUtil.deepCopy(pathIn.nodes) else {},
				bp = if type(pathIn.bp) == "table" then TableUtil.deepCopy(pathIn.bp) else {},
				freeUsed = pathIn.freeUsed == true,
			},
			stats = stats,
			statPoints = points,
			hotbar = if type(src.hotbar) == "table" then TableUtil.deepCopy(src.hotbar) else {},
		}
	end

	local function activeSet(character: any): BuildSet
		return cloneSet({
			path = character.path,
			stats = character.stats,
			statPoints = character.statPoints,
			hotbar = character.hotbar,
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

	-- The new buildOther: the active set, but the target keeps its own freeUsed (a copy never returns the free choice).
	local function copySet(character: any): BuildSet
		local set = activeSet(character)
		local other = character.buildOther
		set.path.freeUsed = type(other) == "table" and type(other.path) == "table" and other.path.freeUsed == true
		return set
	end

	-- A character-shaped view of a set for the rules above (they read class, level, path, hotbar, equipment).
	local function setView(character: any, set: BuildSet, level: number?): any
		return {
			class = character.class,
			level = level or character.level,
			path = set.path,
			hotbar = set.hotbar,
			stats = set.stats,
			statPoints = set.statPoints,
			equipment = character.equipment,
		}
	end

	-- A set as `level` allows (load, SetLevel down): broken fields repaired, the path clamped, the bar and path.bp
	-- checked; stats stay. Second value: anything changed.
	local function cleanSet(character: any, set: any, level: number): (BuildSet, boolean)
		local out = cloneSet(set, character.class, level)
		out.path = clampToLevel(setView(character, out, level), level)
		local bar, bp = validHotbar(setView(character, out, level))
		out.hotbar = bar
		out.path.bp = bp
		return out, not TableUtil.deepEqual(out, set)
	end

	-- The main path's weapon (ROZWOJ 2.8): false and its PathDef when the weapons do not fit; true without a main path
	-- or for an id without a PathDef.
	local function mainWeaponOk(character: Char, weapons: WeaponTypes): (boolean, PathDef?)
		local main = stateOf(character).main
		local def = if main then source.path(main) else nil
		if def and not weaponOk(def.weapon, weapons) then
			return false, def
		end
		return true, nil
	end

	-- ROZWOJ 2.11: the main path's statPlan (and its PathDef), else the class plan; unknown class {}.
	local function statPlan(character: Char): ({ [string]: number }, PathDef?)
		local main = stateOf(character).main
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
		MAIN_LEVEL = MAIN_LEVEL,
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
		spent = spent,
		free = free,
		rowOpen = rowOpen,
		canBuy = canBuy,
		canRefund = canRefund,
		refund = refund,
		canChooseMain = canChooseMain,
		skillRank = skillRank,
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
		canPutOnBar = canPutOnBar,
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
		mainWeaponOk = mainWeaponOk,
		statPlan = statPlan,
	}
end

build = buildApi

local Paths = buildApi(sourceOf(PathData.list))
export type Api = typeof(Paths)

return Paths
