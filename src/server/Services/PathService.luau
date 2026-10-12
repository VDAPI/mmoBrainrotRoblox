--!strict
-- Class paths (ROZWOJ 2.2-2.10, 3.3; S57): buying and refunding nodes, the main path (free first choice, later the
-- Scroll of a New Path in town), breakpoint choices, and the checks after every change (hotbar and path.bp through
-- Logic/Paths.validHotbar, passives, PathService.Changed). The rules live in Logic/Paths; this service only builds
-- the place context (combat, town, dungeon entrance) and writes the state.
-- No service PathService depends on may list it in its Deps (DepSort rejects cycles); a service that needs it later
-- keeps the registry and calls registry.Get("PathService") during play.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Net = require(Shared.Net)
local PathData = require(Shared.Data.Paths)
local Paths = require(Shared.Logic.Paths)
local SkillData = require(Shared.Data.Skills)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Skills = require(Shared.Logic.Skills)
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
	},
	Changed = Signal.new(), -- (player) nodes, main path, breakpoints, weapon or level changed what the paths give
}

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

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function ctxFor(player: Player, action: Paths.EditAction): Paths.EditCtx
	return {
		action = action,
		inCombat = ResourceService.InCombat(player),
		inTown = ZoneService.GetPvpZone(player) == "green",
		nearGate = DungeonService.NearAnyEntrance(player),
	}
end

local function setPath(player: Player, state: Types.PathState)
	PlayerStateService.Set(player, { "character", "path" }, {
		main = state.main,
		nodes = table.clone(state.nodes),
		bp = table.clone(state.bp),
		freeUsed = state.freeUsed,
	})
end

-- Drops from the bar and path.bp what the character no longer has. Returns whether anything changed.
local function checkBar(player: Player, char: Types.CharacterData): boolean
	local bar, bp, changed = Paths.validHotbar(char)
	if changed then
		PlayerStateService.Set(player, { "character", "hotbar" }, bar)
		PlayerStateService.Set(player, { "character", "path", "bp" }, bp)
	end
	return changed
end

-- After every change of nodes, main path or level: the bar check, passives and hooks, Changed.
local function afterChange(player: Player)
	local char = character(player)
	if not char then
		return
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
		local args = { skill = "@" .. skill.nameKey }
		if skill.type == "passive" then
			Net.Fire(player, "Toast", "skills.toast.passive", args, "success")
		else
			local placed, placeErr = SkillService.PutOnBar(player, skill.id)
			if placed then
				Net.Fire(player, "Toast", "skills.toast.onBar", args, "success")
			elseif placeErr == "skills.error.barFull" then
				Net.Fire(player, "Toast", "skills.toast.barFull", args, "info")
			end
		end
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
	local rank = (char.path.nodes[nodeId] or 0) - 1
	PlayerStateService.Set(player, { "character", "path", "nodes", nodeId }, if rank > 0 then rank else nil)
	afterChange(player)
	return true, nil
end

local function resetPaths(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err = Paths.canEdit(ctxFor(player, "refund"))
	if not ok then
		return false, err
	end
	PlayerStateService.Set(player, { "character", "path", "nodes" }, Paths.refund(char, nil).nodes)
	afterChange(player)
	return true, nil
end

local function chooseMainPath(player: Player, pathId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err, cost = Paths.canChooseMain(char, pathId)
	if not ok then
		return false, err
	end
	local action: Paths.EditAction = if cost == "free" then "chooseMain" else "changeMain"
	ok, err = Paths.canEdit(ctxFor(player, action))
	if not ok then
		return false, err
	end
	if cost == "scroll" and InventoryService.Count(player, SCROLL) < 1 then
		return false, "paths.error.scroll"
	end
	local old = char.path.main
	local state = if old then Paths.refund(char, { path = old, fromRow = PathData.DIP_ROWS + 1 }) else char.path
	-- The scroll goes right before the write, with no yield in between.
	if cost == "scroll" and InventoryService.Remove(player, SCROLL, 1) ~= 1 then
		return false, "paths.error.scroll"
	end
	setPath(player, {
		main = pathId,
		nodes = state.nodes,
		bp = state.bp,
		freeUsed = true,
	})
	afterChange(player)
	Net.Fire(player, "Toast", "paths.main.done", nil, "success")
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

-- Admin (Admin/Character): no place or combat rules -----------------------------------------------------------------

-- Sets (or clears) the main path; rows above DIP_ROWS of the old one are refunded, freeUsed stays.
function PathService.AdminSetMain(player: Player, pathId: string?): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if pathId ~= nil then
		local path = PathData.get(pathId)
		if not path or path.class ~= char.class then
			return false, "admin.path.unknown"
		end
	end
	local old = char.path.main
	local state = if old and old ~= pathId
		then Paths.refund(char, { path = old, fromRow = PathData.DIP_ROWS + 1 })
		else char.path
	setPath(player, { main = pathId, nodes = state.nodes, bp = state.bp, freeUsed = char.path.freeUsed })
	afterChange(player)
	return true, nil
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

-- Optionally sets the main path (from MAIN_LEVEL), then buys like a player: rows up, nodes in order, the first node of
-- a choice row, every rank through Paths.canBuy, while there are points. Returns the ranks bought.
function PathService.AdminMax(player: Player, pathId: string?): (number, string?)
	local char = character(player)
	if not char then
		return 0, "error.wrongPhase"
	end
	if pathId ~= nil and char.path.main ~= pathId then
		local path = PathData.get(pathId)
		if not path or path.class ~= char.class then
			return 0, "admin.path.unknown"
		end
		if char.level >= Paths.MAIN_LEVEL then
			PathService.AdminSetMain(player, pathId)
		end
	end
	local bought = 0
	local paths = Paths.pathsOf(char.class)
	for r = 1, #PathData.ROWS do
		for _, path in paths do
			local row = path.rows[r]
			for _, node in row.nodes do
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

-- Refunds every node and breakpoint choice of the active set; the main path and freeUsed stay.
function PathService.AdminReset(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	PlayerStateService.Set(player, { "character", "path", "nodes" }, {})
	PlayerStateService.Set(player, { "character", "path", "bp" }, {})
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

local function samePath(a: Types.PathState, b: Types.PathState): boolean
	return a.main == b.main and a.freeUsed == b.freeUsed and sameMap(a.nodes, b.nodes) and sameMap(a.bp, b.bp)
end

-- Load: the path state as the level allows, then the bar and path.bp (the only bar check on load).
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
	if checkBar(player, char) then
		changed = true
	end
	SkillService.RefreshPassives(player)
	if changed then
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
end

function PathService.Start()
	Net.Handle("BuyNode", buyNode)
	Net.Handle("RefundNode", refundNode)
	Net.Handle("ResetPaths", resetPaths)
	Net.Handle("ChooseMainPath", chooseMainPath)
	Net.Handle("ChooseBreakpoint", chooseBreakpoint)
	CharacterService.CharacterEntered:Connect(onEntered)
	-- The path weapon switches rows 3-11 on and off: passives and hooks again, the bar only greys out.
	EquipmentService.Changed:Connect(function(player: Player, slot: string)
		if (slot == "weapon" or slot == "offhand") and character(player) then
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
