--!strict
-- Skill points (S137, DESIGN-18 §3, §9, §10). Pure. Every weapon pool (Logic/SkillPools) has its own points,
-- pointsAt(L) = L x Progression.skillPoints.perLevel, and its own bought ranks (character.ranks[poolId][skillId]); one
-- point buys one rank up to the limit Skills.rankAt (the old level curve). S138: the full reset (canReset with the
-- scroll, resetState) and the node refund price (refundCost, nodeRefundCost, nodesRefundCost). Nothing is bought by
-- itself: the window reserves ranks and the server applies the whole reservation (apply) or nothing. Refunds: free below
-- Progression.freeRespecLevel anywhere out of combat, from it in town or at a dungeon gate for rankRefundGold x level
-- gold a rank. The rank rule itself (pool, node of a path skill, limit) is Logic/Paths.skillRank; the rank part of a
-- set's cleaning is Logic/Paths.cleanRanks.
-- A character here is a narrow view: class, level, path, equipment, ranks, hotbar, bars, barPool, respecFree,
-- poolsVersion (Logic/Paths.setView gives one for the inactive set).

local Paths = require("./Paths")
local Progression = require("../Data/Progression")
local SkillData = require("../Data/Skills")
local SkillPools = require("./SkillPools")
local Skills = require("./Skills")
local TableUtil = require("../Util/TableUtil")

type SkillDef = SkillData.SkillDef

export type Plan = { [string]: number } -- skillId -> ranks to add (a reservation)
export type Ranks = { [string]: number } -- one pool's bought ranks
export type PlaceCtx = { inCombat: boolean, inTown: boolean, nearGate: boolean }
export type PoolBars = { hotbar: { [string]: string }, bars: { [string]: { [string]: string } }, barPool: string }
export type Migrated = {
	ranks: { [string]: Ranks },
	hotbar: { [string]: string },
	bars: { [string]: { [string]: string } },
	barPool: string,
	respecFree: boolean,
	poolsVersion: number,
}

local SkillPoints = {}

-- Entries of one AllocateSkills reservation at most (a pool has at most ~17 skills).
SkillPoints.MAX_PLAN = 32
-- Old bars had 10 slots (S05-S136): the migration reads them all, keeps 1..HOTBAR_SLOTS.
local OLD_SLOTS = 10

function SkillPoints.pointsAt(level: number): number
	return Paths.skillPointsAt(level)
end

-- The highest rank that may be bought at `level` (DESIGN-18 §3.1: the old curve is the limit).
function SkillPoints.cap(skill: SkillDef, level: number): number
	return Skills.rankAt(skill, level)
end

-- The working rank (Paths.skillRank): bought, in the pool (default: the active one), at most the limit.
function SkillPoints.rank(character: any, skillId: string, poolId: string?): number
	return Paths.skillRank(character, skillId, poolId)
end

-- The raw bought rank (0 when missing).
function SkillPoints.bought(character: any, poolId: string, skillId: string): number
	return Paths.boughtIn(character, poolId, skillId)
end

function SkillPoints.spent(character: any, poolId: string): number
	local total = 0
	local all = character.ranks
	local own = if type(all) == "table" then all[poolId] else nil
	if type(own) == "table" then
		for id in own do
			if type(id) == "string" then
				total += Paths.boughtIn(character, poolId, id)
			end
		end
	end
	return total
end

-- Free points of the pool; negative only after admin /skillrank (the window shows max(0, ...)).
function SkillPoints.free(character: any, poolId: string): number
	return SkillPoints.pointsAt(character.level) - SkillPoints.spent(character, poolId)
end

-- The pool asked for, else the active one.
function SkillPoints.poolFor(character: any, poolId: string?): string?
	if poolId ~= nil then
		return poolId
	end
	return SkillPools.activePool(character)
end

local function wholeAtLeastOne(n: any): boolean
	return type(n) == "number" and n == n and n >= 1 and n <= 1000 and n == math.floor(n)
end

-- May `n` (default 1) more ranks of the skill be bought in the pool? A pool of the class ("skills.error.pool"), a
-- member of it ("skills.error.pool"), a path skill with its node ("skills.error.locked"), at most the limit at the
-- level ("skills.error.limit"), enough free points ("skills.error.points").
function SkillPoints.canBuy(character: any, poolId: string, skillId: string, n: number?): (boolean, string?)
	local count = if n == nil then 1 else n
	if not wholeAtLeastOne(count) or type(skillId) ~= "string" then
		return false, "error.badRequest"
	end
	if not SkillPools.valid(character.class, poolId) then
		return false, "skills.error.pool"
	end
	local skill = SkillData.get(skillId)
	if not skill or skill.class ~= character.class then
		return false, "error.badRequest"
	end
	if not SkillPools.memberDef(character.class, poolId, skill) then
		return false, "skills.error.pool"
	end
	if skill.path ~= nil and not Paths.pathSkillOpen(character, skill) then
		return false, "skills.error.locked"
	end
	if SkillPoints.bought(character, poolId, skillId) + count > SkillPoints.cap(skill, character.level) then
		return false, "skills.error.limit"
	end
	if SkillPoints.free(character, poolId) < count then
		return false, "skills.error.points"
	end
	return true, nil
end

-- A whole reservation { [skillId] = +n } in one pool (AllocateSkills): every entry a known string id with a whole
-- n >= 1, at most MAX_PLAN entries, each checked by canBuy on top of the entries before it (sorted ids, so the answer
-- never depends on table order). All or nothing: the third value is the pool's new ranks (a copy).
function SkillPoints.apply(character: any, poolId: string, plan: any): (boolean, string?, Ranks?)
	if type(plan) ~= "table" or not SkillPools.valid(character.class, poolId) then
		return false, if type(plan) ~= "table" then "error.badRequest" else "skills.error.pool", nil
	end
	local ids: { string } = {}
	for id, n in plan do
		if type(id) ~= "string" or not wholeAtLeastOne(n) then
			return false, "error.badRequest", nil
		end
		table.insert(ids, id)
		if #ids > SkillPoints.MAX_PLAN then
			return false, "error.badRequest", nil
		end
	end
	if #ids == 0 then
		return false, "error.badRequest", nil
	end
	table.sort(ids)
	local all = character.ranks
	local own = if type(all) == "table" and type(all[poolId]) == "table" then all[poolId] else {}
	local ranks: Ranks = {}
	for id, value in own do
		if type(id) == "string" and type(value) == "number" then
			ranks[id] = value
		end
	end
	local work = table.clone(character)
	work.ranks = { [poolId] = ranks }
	for _, id in ids do
		local n = plan[id]
		local ok, err = SkillPoints.canBuy(work, poolId, id, n)
		if not ok then
			return false, err, nil
		end
		ranks[id] = SkillPoints.bought(work, poolId, id) + n
	end
	return true, nil, ranks
end

-- Gold for refunding `n` ranks at `level` (0 below freeRespecLevel). S138: the same price for a skill rank and a node
-- rank (RefundNode, ResetPaths).
function SkillPoints.refundCost(level: number, n: number): number
	if level < Progression.freeRespecLevel then
		return 0
	end
	return Progression.rankRefundGold * level * n
end

-- One rank back (RefundSkillRank): a bought rank ("skills.error.noRank"), out of combat; below freeRespecLevel
-- anywhere and free, from it in town or at a dungeon gate ("paths.error.place") for refundCost gold (the server checks
-- the gold). Third value: the cost.
function SkillPoints.canRefund(
	character: any,
	poolId: string,
	skillId: string,
	ctx: PlaceCtx
): (boolean, string?, number)
	if not SkillPools.valid(character.class, poolId) then
		return false, "skills.error.pool", 0
	end
	if type(skillId) ~= "string" or SkillPoints.bought(character, poolId, skillId) <= 0 then
		return false, "skills.error.noRank", 0
	end
	if ctx.inCombat then
		return false, "paths.error.combat", 0
	end
	local level = character.level
	if level >= Progression.freeRespecLevel and not (ctx.inTown or ctx.nearGate) then
		return false, "paths.error.place", 0
	end
	return true, nil, SkillPoints.refundCost(level, 1)
end

-- How a full reset is paid (S138): "level" (below freeRespecLevel), "respec" (the respecFree flag, used up) or
-- "scroll" (one Scroll of Skill Renewal, used up).
export type ResetPay = "level" | "respec" | "scroll"

-- The full reset (ResetSkills, the Scroll of Skill Renewal; S138, DESIGN-18 §3.2): every pool's ranks and the active
-- set's nodes back, breakpoint choices kept. Out of combat, anywhere; free below freeRespecLevel, then with respecFree
-- (the scroll is not used up), else with a scroll in the backpack (`scrolls` = how many the character has), otherwise
-- "skills.error.resetNeedsScroll". Third value: how it is paid (nil when refused).
function SkillPoints.canReset(character: any, ctx: PlaceCtx, scrolls: number?): (boolean, string?, ResetPay?)
	if ctx.inCombat then
		return false, "paths.error.combat", nil
	end
	if character.level < Progression.freeRespecLevel then
		return true, nil, "level"
	end
	if character.respecFree == true then
		return true, nil, "respec"
	end
	if (scrolls or 0) >= 1 then
		return true, nil, "scroll"
	end
	return false, "skills.error.resetNeedsScroll", nil
end

-- The state after a full reset: no ranks in any pool, no nodes, the breakpoint choices of the set kept (a copy).
function SkillPoints.resetState(
	character: any
): { ranks: { [string]: Ranks }, path: { nodes: { [string]: number }, bp: any } }
	local path = character.path
	local bp = if type(path) == "table" and type(path.bp) == "table" then TableUtil.deepCopy(path.bp) else {}
	return { ranks = {}, path = { nodes = {}, bp = bp } }
end

local function keptRanks(character: any): number
	local total = 0
	for _, ranks in (Paths.cleanRanks(character)) do
		for _, n in ranks do
			total += n
		end
	end
	return total
end

-- S138: skill ranks (all pools) that `nodes` in place of the active set's nodes would drop (Paths.cleanRanks: a path
-- skill without its node holds no ranks). A node refund pays for them too, so it never refunds ranks for less than
-- RefundSkillRank.
function SkillPoints.droppedRanks(character: any, nodes: { [string]: number }): number
	local path = if type(character.path) == "table" then character.path else {}
	local after = table.clone(character)
	after.path = { nodes = nodes, bp = path.bp or {} }
	return math.max(0, keptRanks(character) - keptRanks(after))
end

-- S138: gold for refunding one rank of `nodeId` (RefundNode) = refundCost of that rank and of the skill ranks it drops.
function SkillPoints.nodeRefundCost(character: any, nodeId: string): number
	local path = if type(character.path) == "table" then character.path else {}
	local nodes = table.clone(path.nodes or {})
	local rank = (if type(nodes[nodeId]) == "number" then nodes[nodeId] else 0) - 1
	nodes[nodeId] = if rank > 0 then rank else nil
	return SkillPoints.refundCost(character.level, 1 + SkillPoints.droppedRanks(character, nodes))
end

-- S138: gold for refunding every node of the active set (ResetPaths) = refundCost of all their ranks and of the skill
-- ranks they drop (0 below freeRespecLevel).
function SkillPoints.nodesRefundCost(character: any): number
	local n = Paths.spent(character)
	if n <= 0 then
		return 0
	end
	return SkillPoints.refundCost(character.level, n + SkillPoints.droppedRanks(character, {}))
end

-- The buying order of a pool (SkillPools.members: the plan, other base members, the class's path skills).
function SkillPoints.order(classId: string, poolId: string): { string }
	return SkillPools.members(classId, poolId)
end

-- "Spend as the pool suggests" (DESIGN-18 §3.1): a reservation of the free points in the pool's order, each skill
-- that may hold ranks (Paths.skillOpen) up to its limit in turn. Never more than the free points.
function SkillPoints.suggest(character: any, poolId: string): Plan
	local plan: Plan = {}
	if not SkillPools.valid(character.class, poolId) then
		return plan
	end
	local left = SkillPoints.free(character, poolId)
	for _, id in SkillPoints.order(character.class, poolId) do
		if left <= 0 then
			break
		end
		local skill = SkillData.get(id)
		if skill and Paths.skillOpen(character, id, poolId) then
			local room = SkillPoints.cap(skill, character.level) - SkillPoints.bought(character, poolId, id)
			local add = math.min(room, left)
			if add > 0 then
				plan[id] = add
				left -= add
			end
		end
	end
	return plan
end

-- Migration 12 (DESIGN-18 §10 pt 1): the old automatic rank (Skills.rankAt) of every member of the pool, cut to the
-- pool's points in this order: the skills of the old bar (by slot), the passives, the rest (pool order). A path skill
-- counts only with its node (`path` = the set's path state). Partial ranks are kept.
function SkillPoints.legacy(classId: string, level: number, poolId: string, oldBar: any, path: any?): Ranks
	local out: Ranks = {}
	if not SkillPools.valid(classId, poolId) then
		return out
	end
	local view: any = { class = classId, level = level, path = path }
	local members = SkillPoints.order(classId, poolId)
	local isMember: { [string]: boolean } = {}
	for _, id in members do
		isMember[id] = true
	end
	local ordered: { string } = {}
	local seen: { [string]: boolean } = {}
	local function push(id: string)
		if isMember[id] and not seen[id] then
			seen[id] = true
			table.insert(ordered, id)
		end
	end
	if type(oldBar) == "table" then
		for slot = 1, OLD_SLOTS do
			local id = oldBar[tostring(slot)]
			if type(id) == "string" then
				push(id)
			end
		end
	end
	for _, id in members do
		local skill = SkillData.get(id)
		if skill and skill.type == "passive" then
			push(id)
		end
	end
	for _, id in members do
		push(id)
	end
	local budget = SkillPoints.pointsAt(level)
	for _, id in ordered do
		if budget <= 0 then
			break
		end
		local skill = SkillData.get(id)
		if skill and (skill.path == nil or Paths.pathSkillOpen(view, skill)) then
			local take = math.min(Skills.rankAt(skill, level), budget)
			if take > 0 then
				out[id] = take
				budget -= take
			end
		end
	end
	return out
end

-- The ranks a character may keep (Paths.cleanRanks: out of pool, above the limit, above the points). Second value:
-- anything changed.
function SkillPoints.clean(character: any): ({ [string]: Ranks }, boolean)
	return Paths.cleanRanks(character)
end

-- A bar of the pool from its ranks: the actives with rank > 0 in the pool's order, on "1", "2", ... (HOTBAR_SLOTS).
function SkillPoints.startBar(character: any, poolId: string): { [string]: string }
	local bar: { [string]: string } = {}
	local slot = 0
	for _, id in SkillPoints.order(character.class, poolId) do
		if slot >= SkillData.HOTBAR_SLOTS then
			break
		end
		local skill = SkillData.get(id)
		if skill and skill.type ~= "passive" and Paths.skillRank(character, id, poolId) > 0 then
			slot += 1
			bar[tostring(slot)] = id
		end
	end
	return bar
end

-- The pools of the class changed since the ranks were counted (DESIGN-18 §10): clean, a free reset, the new version.
function SkillPoints.needsRespec(character: any): boolean
	return character.poolsVersion ~= SkillPools.version(character.class)
end

-- The bar of a pool: `hotbar` for the bar's own pool (Paths.barPoolOf), else bars[poolId] ({} when missing).
function SkillPoints.barOf(character: any, poolId: string): { [string]: string }
	if poolId == Paths.barPoolOf(character) then
		local hotbar = character.hotbar
		return if type(hotbar) == "table" then hotbar else {}
	end
	local bars = character.bars
	local bar = if type(bars) == "table" then bars[poolId] else nil
	return if type(bar) == "table" then bar else {}
end

-- The bars after the active pool became `poolId` (DESIGN-18 §4.1): the old hotbar goes to bars[old barPool], the new
-- pool's saved bar (startBar when it never had one) becomes the hotbar (Paths.validBar). nil when nothing changes.
function SkillPoints.switchPool(character: any, poolId: string): PoolBars?
	if not SkillPools.valid(character.class, poolId) then
		return nil
	end
	local old = character.barPool
	if old == poolId then
		return nil
	end
	local bars: { [string]: { [string]: string } } = {}
	if type(character.bars) == "table" then
		for id, bar in character.bars do
			if type(id) == "string" and type(bar) == "table" then
				bars[id] = TableUtil.deepCopy(bar)
			end
		end
	end
	local saved: { [string]: string }?
	if SkillPools.valid(character.class, old) then
		bars[old] = if type(character.hotbar) == "table" then TableUtil.deepCopy(character.hotbar) else {}
		saved = bars[poolId]
	else
		-- no pool yet (a broken or template barPool): the hotbar is this pool's bar
		saved = if type(character.hotbar) == "table" then TableUtil.deepCopy(character.hotbar) else nil
	end
	bars[poolId] = nil
	local hotbar = if saved then saved else SkillPoints.startBar(character, poolId)
	local clean = Paths.validBar(character, poolId, hotbar)
	return { hotbar = clean, bars = bars, barPool = poolId }
end

-- Migration 12 of one build set (DESIGN-18 §10): legacy ranks in every pool, barPool = the pool of the equipped weapon,
-- its bar = the old bar kept to that pool and to HOTBAR_SLOTS, filled up by startBar; the other pools get startBar;
-- respecFree, the class's pool version. An unknown class gets empty ranks and bars.
function SkillPoints.migrate(classId: string, level: number, equipment: any, path: any, oldBar: any): Migrated
	local ranks: { [string]: Ranks } = {}
	for _, poolId in SkillPools.ids(classId) do
		local own = SkillPoints.legacy(classId, level, poolId, oldBar, path)
		if next(own) ~= nil then
			ranks[poolId] = own
		end
	end
	local view: any = { class = classId, level = level, path = path, equipment = equipment, ranks = ranks }
	local active = SkillPools.activePool(view)
	if active == nil then
		return {
			ranks = {},
			hotbar = {},
			bars = {},
			barPool = "",
			respecFree = true,
			poolsVersion = 0,
		}
	end
	view.barPool = active
	local hotbar = Paths.validBar(view, active, oldBar)
	local start = SkillPoints.startBar(view, active)
	local fill: { string } = {}
	for slot = 1, SkillData.HOTBAR_SLOTS do
		local id = start[tostring(slot)]
		if id then
			table.insert(fill, id)
		end
	end
	for _, place in (Skills.placeOnBar(hotbar, fill)) do
		hotbar[tostring(place.slot)] = place.id
	end
	local bars: { [string]: { [string]: string } } = {}
	for _, poolId in SkillPools.ids(classId) do
		if poolId ~= active then
			bars[poolId] = SkillPoints.startBar(view, poolId)
		end
	end
	return {
		ranks = ranks,
		hotbar = hotbar,
		bars = bars,
		barPool = active,
		respecFree = true,
		poolsVersion = SkillPools.version(classId),
	}
end

return SkillPoints
