--!strict
-- Class paths (ROZWOJ 2.2-2.10, 3.3; S57): buying and refunding nodes, breakpoint choices, and the checks after every
-- change (hotbar and path.bp through Logic/Paths.validHotbar, passives, PathService.Changed). S138 (DESIGN-18 §3.2, §7):
-- no main path (ChooseMainPath and /path are gone); paths are mixable directions with one capstone per set
-- (Logic/Paths.canBuy); a node refund from Progression.freeRespecLevel costs the price of a skill rank
-- (SkillPoints.refundCost, in town or at a gate), ResetPaths the price of all node ranks (free with respecFree or below
-- that level); ResetSkills / the Scroll of Skill Renewal is the full reset (FullReset: every pool's ranks and the
-- active set's nodes, breakpoint choices kept). The rules live in Logic/Paths; this service only builds
-- the place context (combat, town, dungeon entrance) and writes the state.
-- Build sets (ROZWOJ 2.9; S58): two sets, the active one in the character fields, the other in buildOther; switching
-- (town or a boss gate, out of combat, alive, outside a dungeon run, Config.BuildSetCooldown) swaps them in one write
-- block, copying puts the active set into buildOther. On load both sets are cleaned.
-- No service PathService depends on may list it in its Deps (DepSort rejects cycles); a service that needs it later
-- keeps the registry and calls registry.Get("PathService") during play.
-- S137 (DESIGN-18 §3, §4, §10, §11): the one service that changes skill ranks, the pool bars and the pool of the bar
-- (ranks, hotbar through SkillService.PutOnBar / setHotbar, bars, barPool, respecFree): AllocateSkills (a whole
-- reservation through Logic/SkillPoints.apply), RefundSkillRank (place, combat, gold), ResetSkills (free below
-- Progression.freeRespecLevel or with respecFree, else the scroll; S138), SetPoolBar (the bar of another pool from
-- the window). The equipped weapon selects the pool (Logic/SkillPools.activePool): on load and on a weapon change the
-- bars swap (SkillPoints.switchPool), in combat the new pool's skills wait Config.SkillPools.swapLock
-- (SkillService.LockPool). On load a changed pool version cleans the ranks and gives a free reset (needsRespec).
-- S139: a weapon change that switches the pool sends the toast "Pool: <name>".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local PathData = require(Shared.Data.Paths)
local Paths = require(Shared.Logic.Paths)
local SkillData = require(Shared.Data.Skills)
local SkillPoints = require(Shared.Logic.SkillPoints)
local SkillPools = require(Shared.Logic.SkillPools)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Skills = require(Shared.Logic.Skills)
local TableUtil = require(Shared.Util.TableUtil)
local Types = require(Shared.Types)

local PathService = {
	Name = "PathService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"SkillService",
		"InventoryService",
		"EquipmentService",
		"DungeonService",
		"ResourceService",
		"ZoneService",
		"LevelService",
		"StatService",
	},
	Changed = Signal.new(), -- (player) nodes, breakpoints, weapon, level or (S137) skill ranks changed
}

-- The Scroll of Skill Renewal (S138): the full reset (FullReset).

local SCROLL = "scroll_skillreset"

local PlayerStateService: any
local CharacterService: any
local SkillService: any
local InventoryService: any
local EquipmentService: any
local DungeonService: any
local ResourceService: any
local ZoneService: any
local LevelService: any
local StatService: any

local lastSwitch: { [Player]: number } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function ctxFor(player: Player, action: Paths.EditAction): Paths.EditCtx
	local char = character(player)
	return {
		action = action,
		inCombat = ResourceService.InCombat(player),
		inTown = ZoneService.GetPvpZone(player) == "green",
		nearGate = DungeonService.NearAnyEntrance(player),
		dead = ResourceService.IsDead(player),
		inRun = DungeonService.InRun(player),
		level = if char then char.level else nil, -- S138: a refund below freeRespecLevel anywhere
	}
end

local function setPath(player: Player, state: Types.PathState)
	PlayerStateService.Set(player, { "character", "path" }, {
		nodes = table.clone(state.nodes),
		bp = table.clone(state.bp),
	})
end

-- S138: takes `cost` gold for a refund (Analytics source `reason`); false when the character has less.
local function payRefund(player: Player, char: Types.CharacterData, cost: number, reason: string): boolean
	if cost <= 0 then
		return true
	end
	if char.gold < cost then
		return false
	end
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold - cost
	end)
	Analytics.gold(player, -cost, balance, reason)
	return true
end

-- Drops from the bar and path.bp what the character no longer has; S137: also from the bars of the other pools.
-- Returns whether anything changed.
local function checkBar(player: Player, char: Types.CharacterData): boolean
	local bar, bp, changed = Paths.validHotbar(char)
	if changed then
		PlayerStateService.Set(player, { "character", "hotbar" }, bar)
		PlayerStateService.Set(player, { "character", "path", "bp" }, bp)
	end
	local bars: any = char.bars
	if type(bars) ~= "table" then
		PlayerStateService.Set(player, { "character", "bars" }, {})
		return true
	end
	for poolId, other in bars do
		if type(poolId) ~= "string" or poolId == char.barPool or not SkillPools.valid(char.class, poolId) then
			PlayerStateService.Set(player, { "character", "bars", poolId }, nil)
			changed = true
		else
			local clean, barChanged = Paths.validBar(char, poolId, other)
			if barChanged then
				PlayerStateService.Set(player, { "character", "bars", poolId }, clean)
				changed = true
			end
		end
	end
	return changed
end

-- S137: the place of a rank refund or a reset (Logic/SkillPoints.PlaceCtx).
local function placeCtx(player: Player): SkillPoints.PlaceCtx
	return {
		inCombat = ResourceService.InCombat(player),
		inTown = ZoneService.GetPvpZone(player) == "green",
		nearGate = DungeonService.NearAnyEntrance(player),
	}
end

-- S137: the bar follows the pool of the equipped weapon (DESIGN-18 §4.1). `fromWeapon` = a weapon change during play:
-- in combat the new pool waits Config.SkillPools.swapLock. Returns whether the bars swapped.
local function syncPool(player: Player, fromWeapon: boolean): boolean
	local char = character(player)
	if not char then
		return false
	end
	local pool = SkillPools.activePool(char)
	if pool == nil then
		return false
	end
	local swap = SkillPoints.switchPool(char, pool)
	if not swap then
		return false
	end
	PlayerStateService.Set(player, { "character", "hotbar" }, swap.hotbar)
	PlayerStateService.Set(player, { "character", "bars" }, swap.bars)
	PlayerStateService.Set(player, { "character", "barPool" }, swap.barPool)
	if fromWeapon and ResourceService.InCombat(player) then
		SkillService.LockPool(player, Config.SkillPools.swapLock)
	end
	-- S139 (DESIGN-18 §12 F2): "Pool: <name>" on a weapon change (the HUD also shows it over the bar)
	local def = if fromWeapon then SkillPools.def(char.class, pool) else nil
	if def then
		Net.Fire(player, "Toast", "skills.toast.pool", { pool = "@" .. def.nameKey }, "info")
	end
	return true
end

-- After every change of nodes, level or (S137) skill ranks: the rank cleaning (a refunded node takes its
-- skill's ranks back), the bar check, passives and hooks, Changed.
local function afterChange(player: Player)
	local char = character(player)
	if not char then
		return
	end
	local ranks, changed = SkillPoints.clean(char)
	if changed then
		PlayerStateService.Set(player, { "character", "ranks" }, ranks)
	end
	checkBar(player, char)
	SkillService.RefreshPassives(player)
	PathService.Changed:Fire(player)
end

-- Handlers -------------------------------------------------------------------------------------------------------

local function buyNode(player: Player, nodeId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err = Paths.canEdit(ctxFor(player, "buy"))
	if not ok then
		return false, err
	end
	ok, err = Paths.canBuy(char, nodeId)
	if not ok then
		return false, err
	end
	local rank = (char.path.nodes[nodeId] or 0) + 1
	PlayerStateService.Set(player, { "character", "path", "nodes", nodeId }, rank)
	local node = Paths.findNode(nodeId)
	local skill = node and node.kind == "skill" and node.skill and SkillData.get(node.skill)
	if skill then
		-- S137: the node only unlocks the skill; rank 1 is bought with skill points (placeNew puts it on the bar)
		Net.Fire(player, "Toast", "skills.toast.unlocked", { skill = "@" .. skill.nameKey }, "info")
	end
	afterChange(player)
	return true, nil
end

local function refundNode(player: Player, nodeId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err = Paths.canEdit(ctxFor(player, "refund"))
	if not ok then
		return false, err
	end
	ok, err = Paths.canRefund(char, nodeId)
	if not ok then
		return false, err
	end
	-- S138 (DESIGN-18 §3.2): from freeRespecLevel a node rank costs as much as a skill rank, plus the ranks of its skill
	-- that the refund drops in every pool
	local cost = SkillPoints.nodeRefundCost(char, nodeId)
	if not payRefund(player, char, cost, "nodeRefund") then
		return false, "skills.error.refundGold"
	end
	local rank = (char.path.nodes[nodeId] or 0) - 1
	PlayerStateService.Set(player, { "character", "path", "nodes", nodeId }, if rank > 0 then rank else nil)
	afterChange(player)
	if cost > 0 then
		Net.Fire(player, "Toast", "paths.toast.refundPaid", { gold = cost }, "info")
	end
	return true, nil
end

-- ResetPaths(): every node of the active set back (breakpoint choices stay). S138: from freeRespecLevel it costs the
-- price of all node ranks, free with respecFree (the flag stays for the full reset) or below that level.
local function resetPaths(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err = Paths.canEdit(ctxFor(player, "refund"))
	if not ok then
		return false, err
	end
	local cost = if char.respecFree == true then 0 else SkillPoints.nodesRefundCost(char)
	if not payRefund(player, char, cost, "nodeRefund") then
		return false, "skills.error.refundGold"
	end
	PlayerStateService.Set(player, { "character", "path", "nodes" }, Paths.refund(char, nil).nodes)
	afterChange(player)
	if cost > 0 then
		Net.Fire(player, "Toast", "paths.toast.refundPaid", { gold = cost }, "info")
	end
	return true, nil
end

local function chooseBreakpoint(player: Player, skillId: string, rank: number, option: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err, isChange = Paths.canChooseBreakpoint(char, skillId, rank, option)
	if not ok then
		return false, err
	end
	local action: Paths.EditAction = if isChange then "changeBp" else "chooseBp"
	ok, err = Paths.canEdit(ctxFor(player, action))
	if not ok then
		return false, err
	end
	local key = Skills.choiceKey(skillId, rank)
	if char.path.bp[key] ~= option then
		PlayerStateService.Set(player, { "character", "path", "bp", key }, option)
		PathService.Changed:Fire(player)
	end
	return true, nil
end

-- Skill points (S137, DESIGN-18 §3, §11) ---------------------------------------------------------------------------

-- A newly bought skill goes to the first free slot of its pool's bar (the active pool's bar through SkillService, so
-- the quest "learn" objective fires); passives only get a toast.
local function placeNew(player: Player, poolId: string, skill: SkillData.SkillDef)
	local args = { skill = "@" .. skill.nameKey }
	if skill.type == "passive" then
		Net.Fire(player, "Toast", "skills.toast.passive", args, "success")
		return
	end
	local char = character(player)
	if not char then
		return
	end
	if poolId == char.barPool then
		local placed, err = SkillService.PutOnBar(player, skill.id)
		if placed then
			Net.Fire(player, "Toast", "skills.toast.onBar", args, "success")
		elseif err == "skills.error.barFull" then
			Net.Fire(player, "Toast", "skills.toast.barFull", args, "info")
		end
		return
	end
	local bar = SkillPoints.barOf(char, poolId)
	for _, id in bar do
		if id == skill.id then
			return
		end
	end
	local slot = Skills.firstFreeSlot(bar)
	if slot then
		PlayerStateService.Set(player, { "character", "bars", poolId, tostring(slot) }, skill.id)
	end
end

-- AllocateSkills(poolId, { [skillId] = +n }): the whole reservation or nothing, out of combat (DESIGN-18 §3.2).
local function allocateSkills(player: Player, poolId: string, plan: any): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if ResourceService.InCombat(player) then
		return false, "paths.error.combat"
	end
	local ok, err, ranks = SkillPoints.apply(char, poolId, plan)
	if not ok or not ranks then
		return false, err
	end
	local before: { [string]: number } = {}
	for id in ranks do
		before[id] = SkillPoints.bought(char, poolId, id)
	end
	PlayerStateService.Set(player, { "character", "ranks", poolId }, ranks)
	local order = SkillPoints.order(char.class, poolId)
	for _, id in order do
		local skill = SkillData.get(id)
		local was = before[id]
		if skill and was ~= nil and was <= 0 and (ranks[id] or 0) > 0 then
			placeNew(player, poolId, skill)
		end
		-- S137 (DESIGN-18 §8): a bought rank 5 / 10 with option B and no choice yet
		if skill and was ~= nil and skill.type ~= "passive" and skill.breakpoints then
			for _, at in Skills.BREAKPOINT_LEVELS do
				local pair = skill.breakpoints[at]
				local key = Skills.choiceKey(id, at)
				if pair and pair.b and was < at and (ranks[id] or 0) >= at and char.path.bp[key] == nil then
					Net.Fire(player, "Toast", "bp.toast.new", { skill = "@" .. skill.nameKey, rank = at }, "warning")
				end
			end
		end
	end
	afterChange(player)
	return true, nil
end

-- RefundSkillRank(poolId, skillId): one rank back; from Progression.freeRespecLevel for gold in town / at a gate.
local function refundSkillRank(player: Player, poolId: string, skillId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err, cost = SkillPoints.canRefund(char, poolId, skillId, placeCtx(player))
	if not ok then
		return false, err
	end
	if not payRefund(player, char, cost, "skillRefund") then
		return false, "skills.error.gold"
	end
	local rank = SkillPoints.bought(char, poolId, skillId) - 1
	PlayerStateService.Set(player, { "character", "ranks", poolId, skillId }, if rank > 0 then rank else nil)
	afterChange(player)
	if cost > 0 then
		Net.Fire(player, "Toast", "skills.toast.refundPaid", { gold = cost }, "info")
	end
	return true, nil
end

-- The full reset (S138, DESIGN-18 §3.2): every pool's ranks and the active set's nodes back (bars follow), breakpoint
-- choices stay. Out of combat, anywhere; free below freeRespecLevel, then with respecFree (used up; the scroll stays),
-- else one Scroll of Skill Renewal from the backpack (used up only on success). ResetSkills and the scroll's use
-- (ScrollService) both land here.
function PathService.FullReset(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err, pay = SkillPoints.canReset(char, placeCtx(player), InventoryService.Count(player, SCROLL))
	if not ok then
		return false, err
	end
	-- The scroll goes right before the write, with no yield in between.
	if pay == "scroll" and InventoryService.Remove(player, SCROLL, 1) ~= 1 then
		return false, "skills.error.resetNeedsScroll"
	end
	local reset = SkillPoints.resetState(char)
	PlayerStateService.Set(player, { "character", "ranks" }, reset.ranks)
	PlayerStateService.Set(player, { "character", "path", "nodes" }, reset.path.nodes)
	if pay == "respec" then
		PlayerStateService.Set(player, { "character", "respecFree" }, false)
	end
	afterChange(player)
	Net.Fire(player, "Toast", "skills.toast.reset", nil, "success")
	return true, nil
end

local function resetSkills(player: Player): (boolean, string?)
	return PathService.FullReset(player)
end

-- SetPoolBar(poolId, slot, skillId?): the bar of any pool of the class from the window; the active pool's bar goes
-- through SkillService (the same rules as SetHotbar).
local function setPoolBar(player: Player, poolId: string, slot: number, skillId: string?): (boolean, string?)
	local char = character(player)
	if not char or not SkillPools.valid(char.class, poolId) or not Skills.validSlot(slot) then
		return false, "error.badRequest"
	end
	if poolId == char.barPool then
		return SkillService.SetSlot(player, slot, skillId)
	end
	if skillId ~= nil then
		local ok, err = Paths.canPutOnBar(char, skillId, poolId)
		if not ok then
			return false, err
		end
	end
	local bar: { [string]: string } = table.clone(SkillPoints.barOf(char, poolId))
	if skillId then
		for key, existing in bar do
			if existing == skillId then
				bar[key] = nil :: any
			end
		end
	end
	bar[tostring(slot)] = skillId :: any
	PlayerStateService.Set(player, { "character", "bars", poolId }, bar)
	PathService.Changed:Fire(player)
	return true, nil
end

-- Build sets (ROZWOJ 2.9; S58) -------------------------------------------------------------------------------------

-- Both sets change in one block without yields; the client gets one diff batch. S137: with the skill ranks, the pool
-- bars and the free reset of each set.
local function writeSwap(player: Player, swap: Paths.SetSwap)
	PlayerStateService.Set(player, { "character", "stats" }, swap.active.stats)
	PlayerStateService.Set(player, { "character", "statPoints" }, swap.active.statPoints)
	PlayerStateService.Set(player, { "character", "hotbar" }, swap.active.hotbar)
	PlayerStateService.Set(player, { "character", "path" }, swap.active.path)
	PlayerStateService.Set(player, { "character", "ranks" }, swap.active.ranks)
	PlayerStateService.Set(player, { "character", "bars" }, swap.active.bars)
	PlayerStateService.Set(player, { "character", "barPool" }, swap.active.barPool or "")
	PlayerStateService.Set(player, { "character", "respecFree" }, swap.active.respecFree)
	PlayerStateService.Set(player, { "character", "poolsVersion" }, swap.active.poolsVersion)
	PlayerStateService.Set(player, { "character", "buildOther" }, swap.other)
	PlayerStateService.Set(player, { "character", "buildSlot" }, swap.slot)
end

local function switchSet(player: Player, admin: boolean): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not admin then
		local ok, err = Paths.canEdit(ctxFor(player, "switchSet"))
		if not ok then
			return false, err
		end
		local last = lastSwitch[player]
		if last and os.clock() - last < Config.BuildSetCooldown then
			return false, "buildset.error.wait"
		end
	end
	local swap = Paths.swapSets(char)
	writeSwap(player, swap)
	lastSwitch[player] = os.clock()
	syncPool(player, false) -- S137: the new set's bar of the equipped weapon's pool
	afterChange(player) -- validHotbar of the new active set, RefreshPassives (hooks + StatService), Changed
	-- Cooldowns stay; HP and resources are only clamped to the new maxima (ResourceService on StatService.Changed).
	StatService.Recompute(player)
	Net.Fire(player, "Toast", "buildset.toast.switched", { n = swap.slot }, "success")
	return true, nil
end

local function copySet(player: Player, admin: boolean): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not admin then
		local ok, err = Paths.canEdit(ctxFor(player, "copySet"))
		if not ok then
			return false, err
		end
	end
	PlayerStateService.Set(player, { "character", "buildOther" }, Paths.copySet(char))
	local from = if char.buildSlot == 2 then 2 else 1
	Net.Fire(player, "Toast", "buildset.toast.copied", { from = from, to = 3 - from }, "success")
	return true, nil
end

-- Admin (Admin/Character): no place or combat rules -----------------------------------------------------------------

-- Raw luck fields of the active build set (S60, ROZWOJ 6.3); {} without a character. The one server entry to a
-- character's luck: CombatService, DungeonService, PartyService and admin /luck read it (lazily, see their Init).
function PathService.GetLuck(player: Player): { [string]: number }
	local char = character(player)
	if not char then
		return {}
	end
	return Paths.luck(char, EquipmentService.WeaponTypes(player))
end

-- Sets a node rank without points or requirements (nil = maxRank, 0 removes); only nodes of the class.
function PathService.AdminSetNode(player: Player, nodeId: string, rank: number?): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local node, path = Paths.findNode(nodeId)
	if not node or not path or path.class ~= char.class then
		return false, "admin.node.unknown"
	end
	local value = math.clamp(math.floor(rank or node.maxRank), 0, node.maxRank)
	PlayerStateService.Set(player, { "character", "path", "nodes", nodeId }, if value > 0 then value else nil)
	afterChange(player)
	return true, nil
end

-- Buys like a player (S138: Paths.canBuy, so the capstone too while no other direction has one): with `pathId` that
-- direction first (rows up), then every direction rows up; nodes in order, the first node of a choice row, while there
-- are points. Returns the ranks bought.
function PathService.AdminMax(player: Player, pathId: string?): (number, string?)
	local char = character(player)
	if not char then
		return 0, "error.wrongPhase"
	end
	local first: PathData.PathDef? = nil
	if pathId ~= nil then
		first = PathData.get(pathId)
		if not first or first.class ~= char.class then
			return 0, "admin.path.unknown"
		end
	end
	local bought = 0
	local function buyRow(path: PathData.PathDef, r: number)
		for _, node in path.rows[r].nodes do
			while Paths.canBuy(char, node.id) do
				PlayerStateService.Set(
					player,
					{ "character", "path", "nodes", node.id },
					(char.path.nodes[node.id] or 0) + 1
				)
				bought += 1
			end
		end
	end
	if first then
		for r = 1, #PathData.ROWS do
			buyRow(first, r)
		end
	end
	for r = 1, #PathData.ROWS do
		for _, path in Paths.pathsOf(char.class) do
			buyRow(path, r)
		end
	end
	afterChange(player)
	return bought, nil
end

-- A breakpoint choice without the rank check; option B still needs B data.
function PathService.AdminChooseBp(player: Player, skillId: string, rank: number, option: string): (boolean, string?)
	local char = character(player)
	local skill = SkillData.get(skillId)
	if not char or not skill or skill.class ~= char.class or (rank ~= 5 and rank ~= 10) then
		return false, "error.badRequest"
	end
	if option ~= "a" and option ~= "b" then
		return false, "error.badRequest"
	end
	local pair = skill.breakpoints and skill.breakpoints[rank]
	if option == "b" and not (pair and pair.b) then
		return false, "bp.error.noOption"
	end
	PlayerStateService.Set(player, { "character", "path", "bp", Skills.choiceKey(skillId, rank) }, option)
	afterChange(player)
	return true, nil
end

-- /buildset (ROZWOJ 3.3): anywhere, no place, combat, death or cooldown checks.
function PathService.AdminSwitch(player: Player): boolean
	return (switchSet(player, true))
end

function PathService.AdminCopy(player: Player): boolean
	return (copySet(player, true))
end

-- S137 /skillrank: sets a bought rank without points or the limit (0 removes); a skill of the pool (default: active).
function PathService.AdminSkillRank(player: Player, skillId: string, rank: number, poolId: string?): (boolean, string?)
	local char = character(player)
	local skill = SkillData.get(skillId)
	if not char or not skill or skill.class ~= char.class then
		return false, "error.badRequest"
	end
	local pool = poolId or SkillPools.activePool(char)
	if pool == nil or not SkillPools.valid(char.class, pool) or not SkillPools.memberDef(char.class, pool, skill) then
		return false, "skills.error.pool"
	end
	local value = math.clamp(math.floor(rank), 0, skill.maxLevel)
	if type(char.ranks[pool]) ~= "table" then
		PlayerStateService.Set(player, { "character", "ranks", pool }, {})
	end
	PlayerStateService.Set(player, { "character", "ranks", pool, skillId }, if value > 0 then value else nil)
	if value > 0 then
		placeNew(player, pool, skill)
	end
	-- no cleaning here: the rank stays above the limit and the points until the next load or level change
	checkBar(player, char)
	SkillService.RefreshPassives(player)
	PathService.Changed:Fire(player)
	return true, nil
end

-- S137 /skillmax: buys like a player (SkillPoints.suggest + apply) in the pool (default: active). Ranks bought.
function PathService.AdminSkillMax(player: Player, poolId: string?): (number, string?)
	local char = character(player)
	if not char then
		return 0, "error.wrongPhase"
	end
	local pool = poolId or SkillPools.activePool(char)
	if pool == nil or not SkillPools.valid(char.class, pool) then
		return 0, "skills.error.pool"
	end
	local plan = SkillPoints.suggest(char, pool)
	local total = 0
	for _, n in plan do
		total += n
	end
	if total == 0 then
		return 0, nil
	end
	local ok, err, ranks = SkillPoints.apply(char, pool, plan)
	if not ok or not ranks then
		return 0, err
	end
	PlayerStateService.Set(player, { "character", "ranks", pool }, ranks)
	for _, id in SkillPoints.order(char.class, pool) do
		local skill = SkillData.get(id)
		-- a skill without a rank before: the whole reservation is its rank now
		if skill and plan[id] and plan[id] == ranks[id] then
			placeNew(player, pool, skill)
		end
	end
	afterChange(player)
	return total, nil
end

-- S137 /skillreset: every pool's ranks back, free, anywhere.
function PathService.AdminSkillReset(player: Player): boolean
	if not character(player) then
		return false
	end
	PlayerStateService.Set(player, { "character", "ranks" }, {})
	afterChange(player)
	return true
end

-- S137 /pool: the active pool, the bar's pool and the free points of every pool.
export type PoolInfo = { active: string, barPool: string, free: { [string]: number }, respecFree: boolean }
function PathService.AdminPoolInfo(player: Player): PoolInfo?
	local char = character(player)
	if not char then
		return nil
	end
	local free: { [string]: number } = {}
	for _, id in SkillPools.ids(char.class) do
		free[id] = SkillPoints.free(char, id)
	end
	return {
		active = SkillPools.activePool(char) or "?",
		barPool = char.barPool,
		free = free,
		respecFree = char.respecFree == true,
	}
end

-- S137 /respecfree: sets the free full reset flag of the active set.
function PathService.AdminRespecFree(player: Player, on: boolean): boolean
	if not character(player) then
		return false
	end
	PlayerStateService.Set(player, { "character", "respecFree" }, on)
	PathService.Changed:Fire(player)
	return true
end

-- /resetskills (S138): the full reset for free, anywhere (every pool's ranks and the active set's nodes; breakpoint
-- choices stay, as with the scroll; respecFree stays). /skillreset keeps refunding the ranks only.
function PathService.AdminReset(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local reset = SkillPoints.resetState(char)
	PlayerStateService.Set(player, { "character", "ranks" }, reset.ranks)
	PlayerStateService.Set(player, { "character", "path", "nodes" }, reset.path.nodes)
	afterChange(player)
	return true, nil
end

-- Lifecycle --------------------------------------------------------------------------------------------------------

local function sameMap(a: { [string]: any }, b: { [string]: any }): boolean
	for key, value in a do
		if b[key] ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

-- S138: a saved path with the old `main` / `freeUsed` fields is never the same (the write drops them).
local function samePath(a: Types.PathState, b: Types.PathState): boolean
	local old: any = a
	if old.main ~= nil or old.freeUsed ~= nil then
		return false
	end
	return sameMap(a.nodes, b.nodes) and sameMap(a.bp, b.bp)
end

-- Load: the path state as the level allows, then the bar and path.bp (the only bar check on load); the same for the
-- inactive build set (ROZWOJ 2.6, 5: class sessions move skills into paths and count on both sets being cleaned).
local function onEntered(player: Player)
	local char = character(player)
	if not char then
		return
	end
	local changed = false
	local clamped = Paths.clampToLevel(char, char.level)
	if not samePath(char.path, clamped) then
		setPath(player, clamped)
		changed = true
	end
	char = character(player) :: Types.CharacterData
	-- S137 (DESIGN-18 §10): the skill ranks as the level, the pools and the nodes allow; a new pool version of the
	-- class also gives a free reset (one toast for both sets)
	local respec = false
	if type(char.ranks) ~= "table" then
		PlayerStateService.Set(player, { "character", "ranks" }, {})
	end
	local ranks, ranksChanged = SkillPoints.clean(char)
	if ranksChanged then
		PlayerStateService.Set(player, { "character", "ranks" }, ranks)
		changed = true
	end
	if SkillPoints.needsRespec(char) then
		PlayerStateService.Set(player, { "character", "respecFree" }, true)
		PlayerStateService.Set(player, { "character", "poolsVersion" }, SkillPools.version(char.class))
		respec = true
	end
	if syncPool(player, false) then
		changed = true
	end
	char = character(player) :: Types.CharacterData
	if checkBar(player, char) then
		changed = true
	end
	if char.buildSlot ~= 1 and char.buildSlot ~= 2 then
		PlayerStateService.Set(player, { "character", "buildSlot" }, 1)
	end
	local other: any = char.buildOther
	if other ~= nil and type(other) ~= "table" then
		PlayerStateService.Set(player, { "character", "buildOther" }, nil)
	elseif type(other) == "table" then
		local cleaned, otherChanged = Paths.cleanSet(char, other, char.level)
		if SkillPoints.needsRespec(Paths.setView(char, cleaned)) then
			cleaned.respecFree = true
			cleaned.poolsVersion = SkillPools.version(char.class)
			otherChanged = true
			respec = true
		end
		if otherChanged then
			PlayerStateService.Set(player, { "character", "buildOther" }, TableUtil.deepCopy(cleaned))
		end
	end
	SkillService.RefreshPassives(player)
	if respec then
		Net.Fire(player, "Toast", "skills.toast.respecFree", nil, "warning")
	end
	if changed or respec then
		PathService.Changed:Fire(player)
	end
end

function PathService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	SkillService = registry.Get("SkillService")
	InventoryService = registry.Get("InventoryService")
	EquipmentService = registry.Get("EquipmentService")
	DungeonService = registry.Get("DungeonService")
	ResourceService = registry.Get("ResourceService")
	ZoneService = registry.Get("ZoneService")
	LevelService = registry.Get("LevelService")
	StatService = registry.Get("StatService")
end

function PathService.Start()
	Net.Handle("BuyNode", buyNode)
	Net.Handle("RefundNode", refundNode)
	Net.Handle("ResetPaths", resetPaths)
	Net.Handle("ChooseBreakpoint", chooseBreakpoint)
	Net.Handle("AllocateSkills", allocateSkills)
	Net.Handle("RefundSkillRank", refundSkillRank)
	Net.Handle("ResetSkills", resetSkills)
	Net.Handle("SetPoolBar", setPoolBar)
	Net.Handle("SwitchBuildSet", function(player: Player)
		return switchSet(player, false)
	end)
	Net.Handle("CopyBuildSet", function(player: Player)
		return copySet(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSwitch[player] = nil
	end)
	CharacterService.CharacterEntered:Connect(onEntered)
	-- A node's own weapon (node.weapon) switches it on and off: passives and hooks again, the bar only greys out. S137:
	-- the weapon selects the pool, so the bars swap (DESIGN-18 §4.1).
	EquipmentService.Changed:Connect(function(player: Player, slot: string)
		if (slot == "weapon" or slot == "offhand") and character(player) then
			if slot == "weapon" then
				syncPool(player, true)
			end
			SkillService.RefreshPassives(player)
			PathService.Changed:Fire(player)
		end
	end)
	-- LevelService.SetLevel cuts the path before this fires; here the bar and path.bp follow the level.
	LevelService.LevelChanged:Connect(function(player: Player)
		afterChange(player)
	end)
end

return PathService
