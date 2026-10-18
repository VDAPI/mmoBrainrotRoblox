--!strict
-- What the skills window and the "!" badge show about paths (S59, ROZWOJ 4): tab state, rows with the reason they are
-- closed, node states, the weapon text, pending breakpoints and rank-ups on level-up. Pure; the window computes
-- nothing itself. PathView.with(api) builds the functions over a Logic/Paths API (tests pass Paths.withSource(...));
-- the module itself is PathView.with(Paths).
-- Characters are narrow views ({ class, level, path, hotbar?, equipment? }), as Logic/Paths reads them.
-- S137 (DESIGN-18 §3, §12): ranks are bought (Logic/SkillPoints), so rankUps / newBreakpoints between two levels stay
-- empty for bought ranks (a level only raises limits); the "!" also shows free skill points of the active pool with a
-- rank to buy (Attention.skills; the views then also read `ranks`).
-- S138 (DESIGN-18 §7): paths are directions: the tab state is "main" for the leading direction (Paths.mainOf), "open"
-- or "closed"; the capstone row of a direction is closed with "skills.error.capstoneTaken" while another direction has
-- the set's capstone, the upgrade row with "paths.error.upgrade" without this direction's capstone; no main path
-- choice and no path weapon in the view (`leading` says which direction leads and the threshold).

-- S139 (DESIGN-18 §5, §12): the skills window 2.0: `planned` (the character with a rank reservation bought),
-- `poolView` (the tree of one weapon pool: rows by the shared ladder, role columns, a tile per skill with its rank,
-- limit, lock, breakpoint marks, buy / refund state and bar slot; direction skills in their own row, skills without a
-- role in "Others" by unlock), `skillDetails` (the fixed sections of a clicked skill: role, short text, the rank N / N+1
-- table, breakpoints, changes from directions, item effects, buy state) and the "!" per pool tab and directions tab.

local ItemEffects = require("./ItemEffects")
local Locale = require("../Util/Locale")
local PathData = require("../Data/Paths")
local Paths = require("./Paths")
local PoolData = require("../Data/SkillPools")
local SkillData = require("../Data/Skills")
local SkillPoints = require("./SkillPoints")
local SkillPools = require("./SkillPools")
local Skills = require("./Skills")

type PathDef = PathData.PathDef
type PathNode = PathData.PathNode
type Char = Paths.Char
type WeaponTypes = Paths.WeaponTypes

export type TabState = "main" | "open" | "closed" -- main = the leading direction (S138)
export type NodeView = {
	node: PathNode,
	rank: number,
	scale: number, -- Paths.nodeScale: < 1 for team nodes in rows 1..DIP_ROWS below TEAM_FULL_POINTS in the direction
	active: boolean, -- listed by Paths.activeNodes (works right now)
	weaponOk: boolean, -- node.weapon fits (true when the node has none)
	canBuy: boolean,
	buyReason: string?,
	canRefund: boolean,
	refundReason: string?,
	taken: boolean, -- choice row: the other node has ranks and this one has none
}
export type RowView = {
	index: number,
	level: number,
	need: number,
	have: number, -- ranks bought in this path's lower rows
	kind: PathData.RowKind,
	choice: boolean,
	open: boolean,
	-- paths.closed.level | paths.closed.need | skills.error.capstoneTaken | paths.error.upgrade (S138)
	closedKey: string?,
	closedArgs: { [string]: number }?,
	nodes: { NodeView },
}
export type View = {
	path: PathDef,
	state: TabState,
	spent: number, -- ranks in this direction
	leading: boolean, -- S138: the leading direction (Paths.mainOf)
	rows: { RowView },
}
-- S138: the leading direction of the set (nil below the threshold) and the ranks it needs.
export type Leading = { pathId: string?, need: number }
export type Pending = { skillId: string, at: number }
export type RankUp = { skillId: string, rank: number }
-- S137: skills = a free skill point of the active pool with a rank to buy (the Base tab shows "!" too)
-- S139: pools = the pool tabs with a dot (the active pool: a rank to buy; a pool where a skill with a breakpoint to
-- choose has a rank),
-- directions = the directions tab (a node to buy or a breakpoint of a direction skill)
export type Attention = {
	points: boolean,
	skills: boolean,
	base: boolean,
	paths: { [string]: boolean },
	pools: { [string]: boolean },
	directions: boolean,
	any: boolean,
}

-- S139: the pool tree ---------------------------------------------------------------------------------------------
export type Reserve = { [string]: number } -- skillId -> ranks reserved in one pool (not sent yet)
-- a breakpoint mark on a tile: not reached ("none"), reached with option B and no choice ("pending"), the working option
export type BpMark = { at: number, mark: "none" | "pending" | "a" | "b" }
export type PoolTile = {
	skillId: string,
	role: string?, -- the ladder code (S145: every pool skill has one; nil for a direction skill)
	column: string?, -- PathView.COLUMNS
	passive: boolean,
	path: string?, -- a direction skill: its direction
	rank: number, -- the working rank with the reservation bought
	bought: number, -- bought before the reservation
	reserved: number,
	cap: number, -- the highest rank at the level (Skills.rankAt)
	max: number,
	locked: boolean, -- no rank at the level yet
	unlock: number, -- the level of rank 1
	nextLevel: number?, -- the level of the next rank while the limit holds it back
	buyable: boolean, -- "+" (SkillPoints.canBuy on the planned character)
	buyReason: string?,
	refundable: boolean, -- "-": a reserved rank (free) or a bought one (RefundSkillRank)
	refundCost: number, -- gold of "-" on a bought rank (0 below Progression.freeRespecLevel or for a reserved rank)
	bp: { BpMark },
	onBar: string?, -- the slot on the pool's bar
	active: boolean, -- the pool of the equipped weapon
	-- S143: the skill's own weapon fits the equipment (SkillDef.weapon, Shield Bash's shield; true without one) and the
	-- reason when it does not (Paths.skillWeaponError: "cast.error.needShield")
	weaponOk: boolean,
	weaponError: string?,
}
export type PoolRowKind = "ladder" | "paths" | "other"
export type PoolRow = {
	kind: PoolRowKind,
	level: number?, -- ladder rows: the rung's level
	code: string?, -- ladder rows: the rung's code
	column: string?, -- ladder rows: the rung's column
	tiles: { PoolTile },
}
export type PoolView = {
	poolId: string,
	active: boolean,
	columns: { string },
	rows: { PoolRow },
	points: number, -- SkillPoints.pointsAt(level)
	free: number, -- free points after the reservation (never below 0)
	reserved: number, -- ranks in the reservation
}
-- One skill as the layout places it (PathView.layout; poolView builds it from the pool's members and directions).
export type LayoutRow = {
	kind: PoolRowKind,
	level: number?,
	code: string?,
	column: string?,
	skills: { SkillData.SkillDef },
}

-- S139: the details of a clicked skill (DESIGN-18 §12) ---------------------------------------------------------------
export type DetailRow = { field: string, now: number?, after: number?, diff: number? }
export type DirectionMod = {
	nodeId: string,
	nameKey: string,
	pathId: string,
	pathNameKey: string,
	row: number,
	rank: number,
	maxRank: number,
	active: boolean, -- works now (bought, row level, node weapon, chosen option)
}
export type SkillDetails = {
	skillId: string,
	nameKey: string,
	role: string?,
	column: string?,
	passive: boolean,
	delivery: string?,
	path: string?,
	shortKey: string,
	args: { [string]: number }, -- placeholders of short / desc at the shown rank
	rank: number, -- with the reservation
	bought: number,
	reserved: number,
	cap: number,
	max: number,
	nextRank: number?, -- nil at the highest rank
	nextLevel: number?, -- the level the next rank needs while the limit holds it back
	rows: { DetailRow }, -- the rank N / N+1 table
	breakpoints: { BpMark },
	mods: { DirectionMod }, -- modify nodes of the class for this skill
	items: { string }, -- nameKeys of the equipped item effects on this skill (S134g)
	buyable: boolean,
	buyReason: string?,
	refundable: boolean,
	refundCost: number,
	onBar: string?,
	canBar: boolean, -- an active with a bought rank in the pool
	active: boolean,
	sections: { string }, -- PathView.SECTIONS present, in order
}

local CLOSED_KEY: { [string]: string } = {
	["paths.error.level"] = "paths.closed.level",
	["paths.error.need"] = "paths.closed.need",
}

local function rankIn(character: Char, nodeId: string): number
	local state = character.path
	local rank = if type(state) == "table" and type(state.nodes) == "table" then state.nodes[nodeId] else nil
	return if type(rank) == "number" then rank else 0
end

local function choicesOf(character: Char): { [string]: any }
	local state = character.path
	return if type(state) == "table" and type(state.bp) == "table" then state.bp else {}
end

local function atLevel(character: Char, level: number): Char
	local copy = table.clone(character)
	copy.level = level
	return copy
end

-- S139: the role columns of the pool tree (the first letter of a ladder code: S1 -> "S", C3 -> "C").
local COLUMNS = { "S", "A", "K", "O", "P", "U", "C" }
-- S139: the details sections in their fixed order (DESIGN-18 §12); the header (name, role, type) always comes first.
local SECTIONS = { "what", "rank", "cost", "breakpoints", "directions", "items", "full" }
-- Value fields that open the rank table; the rest follow alphabetically.
local FIRST_FIELDS = { "dmg", "healHp", "healMag", "shieldHp", "shieldMag" }

-- Both ladders (school and common) by level: one tree row per rung.
local RUNGS: { PoolData.Rung } = {}
for _, rung in PoolData.LADDER do
	table.insert(RUNGS, rung)
end
for _, rung in PoolData.COMMON_LADDER do
	table.insert(RUNGS, rung)
end
table.sort(RUNGS, function(a: PoolData.Rung, b: PoolData.Rung): boolean
	return a.level < b.level
end)

local function columnOf(code: string?): string?
	if code == nil then
		return nil
	end
	local letter = string.sub(code, 1, 1)
	return if table.find(COLUMNS, letter) then letter else nil
end

local function slotOf(bar: { [string]: string }, skillId: string): string?
	for slot, id in bar do
		if id == skillId then
			return slot
		end
	end
	return nil
end

local function fieldOrder(a: string, b: string): boolean
	local ia, ib = table.find(FIRST_FIELDS, a) or 99, table.find(FIRST_FIELDS, b) or 99
	if ia ~= ib then
		return ia < ib
	end
	return a < b
end

-- The pool tree's rows (S139, DESIGN-18 §5): one row per rung of both ladders by level, a skill in the row of its role
-- (`role` of the ladder), the direction skills in one "paths" row, the skills without a role (none since S145, every
-- pool is on the ladder) in one "other" row by unlock (data order on a tie). Pure; poolView fills the tiles.
local function layout(base: { SkillData.SkillDef }, directions: { SkillData.SkillDef }): { LayoutRow }
	local rows: { LayoutRow } = {}
	local byCode: { [string]: LayoutRow } = {}
	for _, rung in RUNGS do
		local row: LayoutRow = {
			kind = "ladder",
			level = rung.level,
			code = rung.code,
			column = columnOf(rung.code),
			skills = {},
		}
		byCode[rung.code] = row
		table.insert(rows, row)
	end
	local others: { SkillData.SkillDef } = {}
	local order: { [string]: number } = {}
	for i, def in base do
		local rung = SkillPools.ladderOf(def)
		local row = if rung then byCode[rung.code] else nil
		if row then
			table.insert(row.skills, def)
		else
			order[def.id] = i
			table.insert(others, def)
		end
	end
	table.sort(others, function(a: SkillData.SkillDef, b: SkillData.SkillDef): boolean
		if a.unlock ~= b.unlock then
			return a.unlock < b.unlock
		end
		return order[a.id] < order[b.id]
	end)
	if #directions > 0 then
		local pathsRow: LayoutRow = { kind = "paths", skills = table.clone(directions) }
		table.insert(rows, pathsRow)
	end
	if #others > 0 then
		local otherRow: LayoutRow = { kind = "other", skills = others }
		table.insert(rows, otherRow)
	end
	return rows
end

local function build(api: Paths.Api)
	local source = api.source

	local function tabState(character: Char, pathId: string): TabState
		if api.mainOf(character) == pathId then
			return "main"
		end
		if character.level < PathData.ROWS[1].level then
			return "closed"
		end
		return "open"
	end

	-- S138: the leading direction (nil below MAIN_MIN_POINTS) and the threshold, for the window's header.
	local function leading(character: Char): Leading
		return { pathId = api.mainOf(character), need = api.MAIN_MIN_POINTS }
	end

	local function path(character: Char, pathId: string, weapons: WeaponTypes): View?
		local def = source.path(pathId)
		if not def or def.class ~= character.class then
			return nil
		end
		local capstone = api.capstoneOf(character)
		local active: { [string]: boolean } = {}
		for _, entry in api.activeNodes(character, weapons) do
			active[entry.node.id] = true
		end
		local rows: { RowView } = {}
		local have, spent = 0, 0
		for _, info in api.rowsFor(def.class) do
			local i = info.index
			local rowDef = def.rows[i]
			local open, err = api.rowOpen(character, pathId, i)
			-- S138: one capstone per set; the upgrade only in the direction with the capstone (these reasons come first:
			-- no level or point makes the row buyable)
			if info.kind == "capstone" and capstone ~= nil and capstone ~= pathId then
				open, err = false, "skills.error.capstoneTaken"
			elseif info.kind == "upgrade" and capstone ~= pathId then
				open, err = false, "paths.error.upgrade"
			end
			local closedKey: string?, closedArgs: { [string]: number }? = nil, nil
			if not open and err then
				closedKey = CLOSED_KEY[err] or err
				if err == "paths.error.level" then
					closedArgs = { level = info.level }
				elseif err == "paths.error.need" then
					closedArgs = { need = info.need, have = have }
				end
			end
			local list: { PathNode } = if rowDef then rowDef.nodes else {}
			local nodes: { NodeView } = {}
			local rowRanks = 0
			for _, node in list do
				rowRanks += rankIn(character, node.id)
			end
			for _, node in list do
				local rank = rankIn(character, node.id)
				local canBuy, buyReason = api.canBuy(character, node.id)
				local canRefund, refundReason = api.canRefund(character, node.id)
				table.insert(nodes, {
					node = node,
					rank = rank,
					scale = api.nodeScale(character, pathId, i, node),
					active = active[node.id] == true,
					weaponOk = node.weapon == nil or api.weaponOk(node.weapon, weapons),
					canBuy = canBuy,
					buyReason = buyReason,
					canRefund = canRefund,
					refundReason = refundReason,
					taken = info.choice and rank == 0 and rowRanks > 0,
				})
			end
			table.insert(rows, {
				index = i,
				level = info.level,
				need = info.need,
				have = have,
				kind = info.kind,
				choice = info.choice,
				open = open,
				closedKey = closedKey,
				closedArgs = closedArgs,
				nodes = nodes,
			})
			have += rowRanks
			spent += rowRanks
		end
		return {
			path = def,
			state = tabState(character, pathId),
			spent = spent,
			leading = api.mainOf(character) == pathId,
			rows = rows,
		}
	end

	-- "Staff or Wand + Orb": two-handed main types alone, one-handed main types grouped with the off-hand; no main
	-- type = "any one-handed weapon + off-hand"; no requirement = "any weapon of the class".
	local function weaponText(req: PathData.WeaponReq?, lang: string?): string
		local main: { string } = if req and req.main then req.main else {}
		local offhand: { string } = if req and req.offhand then req.offhand else {}
		if #main == 0 and #offhand == 0 then
			return Locale.T("paths.weapon.any", nil, lang)
		end
		local function names(types: { string }): string
			local out = {}
			for _, itemType in types do
				table.insert(out, Locale.T(`itemBase.{itemType}`, nil, lang))
			end
			return table.concat(out, " / ")
		end
		local offText = if #offhand > 0 then names(offhand) else nil
		local parts: { string } = {}
		local oneHanded: { string } = {}
		for _, itemType in main do
			if api.isTwoHanded(itemType) then
				table.insert(parts, names({ itemType }))
			else
				table.insert(oneHanded, itemType)
			end
		end
		if #oneHanded > 0 then
			local text = names(oneHanded)
			table.insert(parts, if offText then `{text} + {offText}` else text)
		elseif #main == 0 and offText then
			table.insert(parts, `{Locale.T("paths.weapon.anyOneHand", nil, lang)} + {offText}`)
		end
		return table.concat(parts, ` {Locale.T("paths.weapon.or", nil, lang)} `)
	end

	local function hasB(skill: SkillData.SkillDef, at: number): boolean
		local pair = skill.breakpoints and skill.breakpoints[at]
		return pair ~= nil and pair.b ~= nil
	end

	-- Breakpoints with option B reached by an available active and not chosen yet (ROZWOJ 2.7: A works, "!" shows).
	-- S139: actives with a rank in any pool (the active one first), reached by Paths.bpRank like the server's choice.
	local function pendingBreakpoints(character: Char): { Pending }
		local out: { Pending } = {}
		local choices = choicesOf(character)
		local activePool = SkillPools.activePool(character)
		local order: { string } = if activePool then { activePool } else {}
		for _, poolId in SkillPools.ids(character.class) do
			if poolId ~= activePool then
				table.insert(order, poolId)
			end
		end
		local seen: { [string]: boolean } = {}
		for _, poolId in order do
			for _, skillId in api.availableSkills(character, poolId) do
				local skill = source.skill(skillId)
				if not seen[skillId] and skill and skill.type ~= "passive" then
					seen[skillId] = true
					local rank = api.bpRank(character, skillId)
					for _, at in Skills.BREAKPOINT_LEVELS do
						if hasB(skill, at) and rank >= at and choices[Skills.choiceKey(skillId, at)] == nil then
							table.insert(out, { skillId = skillId, at = at })
						end
					end
				end
			end
		end
		return out
	end

	-- S137: a free skill point of the active pool and a member with a rank to buy (SkillPoints.canBuy).
	local function skillsToBuy(character: Char): boolean
		local pool = SkillPools.activePool(character)
		if pool == nil or SkillPoints.free(character, pool) < 1 then
			return false
		end
		for _, id in SkillPools.members(character.class, pool) do
			if SkillPoints.canBuy(character, pool, id, 1) then
				return true
			end
		end
		return false
	end

	-- The "!" (ROZWOJ 4): a free point with a node to buy, or a breakpoint with option B and no choice; S137: a free
	-- skill point with a rank to buy. S139: the dot of the active pool's tab and of the directions tab.
	local function attention(character: Char): Attention
		local out: Attention = {
			points = false,
			skills = false,
			base = false,
			paths = {},
			pools = {},
			directions = false,
			any = false,
		}
		local activePool = SkillPools.activePool(character)
		if skillsToBuy(character) then
			out.skills = true
			out.base = true
			if activePool then
				out.pools[activePool] = true
			end
		end
		if api.free(character) >= 1 then
			for _, def in source.pathsOf(character.class) do
				for _, row in def.rows do
					for _, node in row.nodes do
						if not out.paths[def.id] and (api.canBuy(character, node.id)) then
							out.points = true
							out.paths[def.id] = true
						end
					end
				end
			end
		end
		for _, pending in pendingBreakpoints(character) do
			local skill = source.skill(pending.skillId)
			if skill and skill.path then
				out.paths[skill.path] = true
			else
				out.base = true
			end
			-- S139: the tabs of the pools where the skill has a rank (its tile shows the "!" there)
			for _, poolId in SkillPools.ids(character.class) do
				if api.skillRank(character, pending.skillId, poolId) > 0 then
					out.pools[poolId] = true
				end
			end
		end
		out.directions = out.points or next(out.paths) ~= nil
		out.any = out.points or out.base or next(out.paths) ~= nil
		return out
	end

	-- S139: the character with a reservation of `poolId` bought (the window's "+" before "Confirm"); the same table
	-- when there is nothing reserved.
	local function planned(character: Char, poolId: string, reserve: Reserve?): Char
		if reserve == nil or next(reserve) == nil then
			return character
		end
		local ranks: { [string]: { [string]: number } } = {}
		local all: any = character.ranks
		if type(all) == "table" then
			for id, own in all do
				if type(id) == "string" and type(own) == "table" then
					ranks[id] = table.clone(own)
				end
			end
		end
		local own = ranks[poolId] or {}
		for id, n in reserve do
			if type(id) == "string" and type(n) == "number" and n > 0 then
				own[id] = SkillPoints.bought(character, poolId, id) + n
			end
		end
		ranks[poolId] = own
		local copy = table.clone(character)
		copy.ranks = ranks
		return copy
	end

	local function bpMarks(skill: SkillData.SkillDef, rank: number, choices: { [string]: any }): { BpMark }
		local out: { BpMark } = {}
		if skill.type == "passive" or not skill.breakpoints then
			return out
		end
		for _, at in Skills.BREAKPOINT_LEVELS do
			local pair = skill.breakpoints[at]
			if pair then
				local mark: "none" | "pending" | "a" | "b"
				if rank < at then
					mark = "none"
				elseif pair.b ~= nil and choices[Skills.choiceKey(skill.id, at)] == nil then
					mark = "pending"
				else
					mark = Skills.chosen(skill, at, choices)
				end
				local entry: BpMark = { at = at, mark = mark }
				table.insert(out, entry)
			end
		end
		return out
	end

	-- One tile of the pool tree: ranks from the planned character, the refund from the bought ranks.
	local function tileOf(
		character: Char,
		plannedChar: Char,
		poolId: string,
		skill: SkillData.SkillDef,
		reserve: Reserve?,
		active: boolean
	): PoolTile
		local reservedRaw = if reserve then reserve[skill.id] else nil
		local reserved = if type(reservedRaw) == "number" and reservedRaw > 0 then reservedRaw else 0
		local bought = SkillPoints.bought(character, poolId, skill.id)
		local rank = api.skillRank(plannedChar, skill.id, poolId)
		local cap = Skills.rankAt(skill, character.level)
		local buyable, buyReason = SkillPoints.canBuy(plannedChar, poolId, skill.id, 1)
		local role = if skill.role and SkillPools.ladderOf(skill) then skill.role else nil
		local weaponError = api.skillWeaponError(skill, api.weaponTypesOf(character.equipment))
		return {
			skillId = skill.id,
			role = role,
			column = columnOf(role),
			passive = skill.type == "passive",
			path = skill.path,
			rank = rank,
			bought = bought,
			reserved = reserved,
			cap = cap,
			max = skill.maxLevel,
			locked = cap <= 0,
			unlock = skill.unlock,
			nextLevel = if rank < skill.maxLevel and rank + 1 > cap then Skills.rankLevel(skill, rank + 1) else nil,
			buyable = buyable,
			buyReason = if buyable then nil else buyReason,
			refundable = reserved > 0 or bought > 0,
			refundCost = if reserved == 0 and bought > 0 then SkillPoints.refundCost(character.level, 1) else 0,
			bp = bpMarks(skill, api.bpRank(plannedChar, skill.id), choicesOf(character)),
			onBar = slotOf(SkillPoints.barOf(character, poolId), skill.id),
			active = active,
			weaponOk = weaponError == nil,
			weaponError = weaponError,
		}
	end

	-- Base members of the pool (school and common) and the direction skills that may hold ranks in it (node bought).
	local function poolSkills(character: Char, poolId: string): ({ SkillData.SkillDef }, { SkillData.SkillDef })
		local base: { SkillData.SkillDef } = {}
		for _, id in SkillPools.members(character.class, poolId) do
			local def = source.skill(id)
			if def and def.path == nil then
				table.insert(base, def)
			end
		end
		local directions: { SkillData.SkillDef } = {}
		for _, def in source.pathsOf(character.class) do
			for _, row in def.rows do
				for _, node in row.nodes do
					local skill = if node.kind == "skill" and node.skill then source.skill(node.skill) else nil
					if skill and not table.find(directions, skill) and api.skillOpen(character, skill.id, poolId) then
						table.insert(directions, skill)
					end
				end
			end
		end
		return base, directions
	end

	-- S139 (DESIGN-18 §5, §12): the tree of one weapon pool with a reservation (nil: not a pool of the class).
	local function poolView(character: Char, poolId: string, reserve: Reserve?): PoolView?
		if not SkillPools.valid(character.class, poolId) then
			return nil
		end
		local plannedChar = planned(character, poolId, reserve)
		local active = SkillPools.activePool(character) == poolId
		local base, directions = poolSkills(character, poolId)
		local rows: { PoolRow } = {}
		for _, entry in layout(base, directions) do
			local tiles: { PoolTile } = {}
			for _, skill in entry.skills do
				table.insert(tiles, tileOf(character, plannedChar, poolId, skill, reserve, active))
			end
			local row: PoolRow = {
				kind = entry.kind,
				level = entry.level,
				code = entry.code,
				column = entry.column,
				tiles = tiles,
			}
			table.insert(rows, row)
		end
		local reserved = 0
		for _, n in (reserve or {}) :: Reserve do
			if type(n) == "number" and n > 0 then
				reserved += n
			end
		end
		return {
			poolId = poolId,
			active = active,
			columns = table.clone(COLUMNS),
			rows = rows,
			points = SkillPoints.pointsAt(character.level),
			free = math.max(0, SkillPoints.free(plannedChar, poolId)),
			reserved = reserved,
		}
	end

	-- The modify nodes of the class for `skill` with their state (a node works like Paths.skillMods counts it).
	local function directionMods(character: Char, skill: SkillData.SkillDef, weapons: WeaponTypes): { DirectionMod }
		local out: { DirectionMod } = {}
		local working: { [string]: boolean } = {}
		for _, entry in api.activeNodes(character, weapons) do
			working[entry.node.id] = true
		end
		local choices = choicesOf(character)
		for _, def in source.pathsOf(character.class) do
			for r, row in def.rows do
				for _, node in row.nodes do
					local modify = node.modify
					if modify and modify.skill == skill.id then
						local optionOk = modify.option == nil
							or Skills.chosen(skill, modify.at or 5, choices) == modify.option
						table.insert(out, {
							nodeId = node.id,
							nameKey = node.nameKey,
							pathId = def.id,
							pathNameKey = def.nameKey,
							row = r,
							rank = rankIn(character, node.id),
							maxRank = node.maxRank,
							active = working[node.id] == true and optionOk,
						})
					end
				end
			end
		end
		return out
	end

	-- S139 (DESIGN-18 §12): the sections of a clicked skill in a pool (nil: not a member of a pool of the class).
	-- The rank table holds the skill's value fields, then the time, effect times, cost and cooldown when the next
	-- rank changes them; numbers as Skills.descriptionArgs gives them (breakpoints, modify nodes, item effects, the
	-- passive hooks of cost and radius as the description's).
	local function skillDetails(character: Char, poolId: string, skillId: string, reserve: Reserve?): SkillDetails?
		local skill = source.skill(skillId)
		if not skill or skill.class ~= character.class or not SkillPools.valid(character.class, poolId) then
			return nil
		end
		if not SkillPools.memberDef(character.class, poolId, skill) then
			return nil
		end
		local plannedChar = planned(character, poolId, reserve)
		local active = SkillPools.activePool(character) == poolId
		local tile = tileOf(character, plannedChar, poolId, skill, reserve, active)
		local weapons = api.weaponTypesOf(character.equipment)
		local mods = api.skillMods(character, skillId, weapons)
		for _, mod in ItemEffects.mods(character, skillId) do
			table.insert(mods, mod :: any)
		end
		local opts: Skills.DescOpts = {
			level = character.level,
			choices = choicesOf(character),
			mods = mods,
			hooks = api.passiveTotals(character, weapons).hooks,
		}
		local rank = tile.rank
		local nextRank = if rank < skill.maxLevel then rank + 1 else nil
		local now = if rank > 0 then Skills.descriptionArgs(skill, rank, opts) else nil
		local after = if nextRank then Skills.descriptionArgs(skill, nextRank, opts) else nil
		local fields: { string } = {}
		for field in skill.values do
			table.insert(fields, field)
		end
		table.sort(fields, fieldOrder)
		local extra: { string } = { "duration" }
		local effects: { SkillData.SkillEffect } = skill.effects or {}
		for _, effect in effects do
			local key = `{effect.kind}Duration`
			if not table.find(extra, key) then
				table.insert(extra, key)
			end
		end
		table.insert(extra, "cost")
		table.insert(extra, "cooldown")
		for _, field in extra do
			if now and after and now[field] ~= nil and after[field] ~= nil and now[field] ~= after[field] then
				table.insert(fields, field)
			end
		end
		local rows: { DetailRow } = {}
		for _, field in fields do
			local a = if now then now[field] else nil
			local b = if after then after[field] else nil
			if a ~= nil or b ~= nil then
				table.insert(rows, {
					field = field,
					now = a,
					after = b,
					diff = if a ~= nil and b ~= nil then Skills.roundArg(b - a) else nil,
				})
			end
		end
		local items: { string } = {}
		for _, def in ItemEffects.list(character) do
			if def.skill == skillId then
				table.insert(items, def.nameKey)
			end
		end
		local directionList = directionMods(character, skill, weapons)
		local passive = skill.type == "passive"
		local sections: { string } = {}
		for _, section in SECTIONS do
			local present = if section == "cost"
				then not passive
				elseif section == "breakpoints" then #tile.bp > 0
				elseif section == "directions" then #directionList > 0
				elseif section == "items" then #items > 0
				else true
			if present then
				table.insert(sections, section)
			end
		end
		local args = now or Skills.descriptionArgs(skill, 1, opts)
		return {
			skillId = skillId,
			nameKey = skill.nameKey,
			role = tile.role,
			column = tile.column,
			passive = passive,
			delivery = skill.delivery,
			path = skill.path,
			shortKey = `skill.{skillId}.short`,
			args = args,
			rank = rank,
			bought = tile.bought,
			reserved = tile.reserved,
			cap = tile.cap,
			max = tile.max,
			nextRank = nextRank,
			nextLevel = tile.nextLevel,
			rows = rows,
			breakpoints = tile.bp,
			mods = directionList,
			items = items,
			buyable = tile.buyable,
			buyReason = tile.buyReason,
			refundable = tile.refundable,
			refundCost = tile.refundCost,
			onBar = tile.onBar,
			canBar = not passive and api.skillRank(character, skillId, poolId) > 0,
			active = active,
			sections = sections,
		}
	end

	-- Skills whose rank grew between the two levels (newly unlocked ones have their own toast, S56).
	local function rankUps(character: Char, fromLevel: number, toLevel: number): { RankUp }
		local out: { RankUp } = {}
		if toLevel <= fromLevel then
			return out
		end
		local before, after = atLevel(character, fromLevel), atLevel(character, toLevel)
		for _, skill in source.classSkills(character.class) do
			local r0 = api.skillRank(before, skill.id)
			local r1 = api.skillRank(after, skill.id)
			if r0 > 0 and r1 > r0 then
				table.insert(out, { skillId = skill.id, rank = r1 })
			end
		end
		return out
	end

	-- Breakpoints with option B an active reached between the two levels and has not chosen yet.
	local function newBreakpoints(character: Char, fromLevel: number, toLevel: number): { Pending }
		local out: { Pending } = {}
		if toLevel <= fromLevel then
			return out
		end
		local before, after = atLevel(character, fromLevel), atLevel(character, toLevel)
		local choices = choicesOf(character)
		for _, skill in source.classSkills(character.class) do
			if skill.type ~= "passive" then
				local r0 = api.skillRank(before, skill.id)
				local r1 = api.skillRank(after, skill.id)
				if r1 > 0 then
					for _, at in Skills.BREAKPOINT_LEVELS do
						if
							r0 < at
							and at <= r1
							and hasB(skill, at)
							and choices[Skills.choiceKey(skill.id, at)] == nil
						then
							table.insert(out, { skillId = skill.id, at = at })
						end
					end
				end
			end
		end
		return out
	end

	return {
		tabState = tabState,
		leading = leading,
		path = path,
		weaponText = weaponText,
		pendingBreakpoints = pendingBreakpoints,
		attention = attention,
		rankUps = rankUps,
		newBreakpoints = newBreakpoints,
		-- S139
		COLUMNS = COLUMNS,
		SECTIONS = SECTIONS,
		layout = layout,
		planned = planned,
		poolView = poolView,
		skillDetails = skillDetails,
	}
end

local PathView = build(Paths) :: any
PathView.with = build

return PathView :: typeof(build(Paths)) & { with: typeof(build) }
