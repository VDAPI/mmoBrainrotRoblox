--!strict
-- What the skills window and the "!" badge show about paths (S59, ROZWOJ 4): tab state, rows with the reason they are
-- closed, node states, the weapon text, pending breakpoints and rank-ups on level-up. Pure; the window computes
-- nothing itself. PathView.with(api) builds the functions over a Logic/Paths API (tests pass Paths.withSource(...));
-- the module itself is PathView.with(Paths).
-- Characters are narrow views ({ class, level, path, hotbar?, equipment? }), as Logic/Paths reads them.

local Locale = require("../Util/Locale")
local PathData = require("../Data/Paths")
local Paths = require("./Paths")
local SkillData = require("../Data/Skills")
local Skills = require("./Skills")

type PathDef = PathData.PathDef
type PathNode = PathData.PathNode
type Char = Paths.Char
type WeaponTypes = Paths.WeaponTypes

export type TabState = "main" | "dip" | "closed"
export type NodeView = {
	node: PathNode,
	rank: number,
	scale: number, -- Paths.nodeScale: < 1 for team nodes in rows 1..DIP_ROWS outside the main path
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
	closedKey: string?, -- paths.closed.level | paths.closed.main | paths.closed.need
	closedArgs: { [string]: number }?,
	weaponBlocked: boolean, -- main path, index > DIP_ROWS and the path weapon does not fit
	nodes: { NodeView },
}
export type MainView = { ok: boolean, reason: string?, cost: ("free" | "scroll")? } -- Paths.canChooseMain
export type View = {
	path: PathDef,
	state: TabState,
	weaponOk: boolean,
	spent: number,
	main: MainView,
	rows: { RowView },
}
export type Pending = { skillId: string, at: number }
export type RankUp = { skillId: string, rank: number }
export type Attention = { points: boolean, base: boolean, paths: { [string]: boolean }, any: boolean }

local CLOSED_KEY: { [string]: string } = {
	["paths.error.level"] = "paths.closed.level",
	["paths.error.main"] = "paths.closed.main",
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

local function mainOf(character: Char): string?
	local state = character.path
	return if type(state) == "table" then state.main else nil
end

local function atLevel(character: Char, level: number): Char
	local copy = table.clone(character)
	copy.level = level
	return copy
end

local function build(api: Paths.Api)
	local source = api.source

	local function tabState(character: Char, pathId: string): TabState
		if mainOf(character) == pathId then
			return "main"
		end
		if character.level < PathData.ROWS[1].level then
			return "closed"
		end
		return "dip"
	end

	local function path(character: Char, pathId: string, weapons: WeaponTypes): View?
		local def = source.path(pathId)
		if not def or def.class ~= character.class then
			return nil
		end
		local isMain = mainOf(character) == pathId
		local weaponOk = api.weaponOk(def.weapon, weapons)
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
				weaponBlocked = isMain and i > api.DIP_ROWS and not weaponOk,
				nodes = nodes,
			})
			have += rowRanks
			spent += rowRanks
		end
		local ok, reason, cost = api.canChooseMain(character, pathId)
		return {
			path = def,
			state = tabState(character, pathId),
			weaponOk = weaponOk,
			spent = spent,
			main = { ok = ok, reason = reason, cost = cost },
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
	local function pendingBreakpoints(character: Char): { Pending }
		local out: { Pending } = {}
		local choices = choicesOf(character)
		for _, skillId in api.availableSkills(character) do
			local skill = source.skill(skillId)
			if skill and skill.type ~= "passive" then
				local rank = api.skillRank(character, skillId)
				for _, at in Skills.BREAKPOINT_LEVELS do
					if hasB(skill, at) and rank >= at and choices[Skills.choiceKey(skillId, at)] == nil then
						table.insert(out, { skillId = skillId, at = at })
					end
				end
			end
		end
		return out
	end

	-- The "!" (ROZWOJ 4): a free point with a node to buy, or a breakpoint with option B and no choice.
	local function attention(character: Char): Attention
		local out: Attention = { points = false, base = false, paths = {}, any = false }
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
		end
		out.any = out.points or out.base or next(out.paths) ~= nil
		return out
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
		path = path,
		weaponText = weaponText,
		pendingBreakpoints = pendingBreakpoints,
		attention = attention,
		rankUps = rankUps,
		newBreakpoints = newBreakpoints,
	}
end

local PathView = build(Paths) :: any
PathView.with = build

return PathView :: typeof(build(Paths)) & { with: typeof(build) }
