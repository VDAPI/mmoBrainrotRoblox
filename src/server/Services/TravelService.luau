--!strict
-- Teleport stones (DESIGN §13). Stone of Return: 5 s channel, interrupted by damage or moving, then a
-- teleport to the capital (the stone is consumed only on success). Map Stone: any visited map (picker on
-- the client, remote UseMapStone). Dungeon Stones: in front of a boss dungeon entrance (once S08/S09 define
-- them). The channel replicates as state branch `travel` = { endsAt, duration, label }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Items = require(Shared.Data.Items)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local TravelService = {
	Name = "TravelService",
	Deps = {
		"PlayerStateService",
		"InventoryService",
		"ResourceService",
		"CharacterService",
		"DeathService",
		"WorldService",
	},
}

local CHANNEL_SECONDS = 5
local MOVE_LIMIT = 2.5

local PlayerStateService: any
local InventoryService: any
local ResourceService: any
local CharacterService: any
local DeathService: any
local WorldService: any

local tokens: { [Player]: number } = {}

local function interrupt(player: Player, notify: boolean)
	if tokens[player] then
		tokens[player] = (tokens[player] or 0) + 1
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "travel" }, nil)
		end
		if notify then
			Net.Fire(player, "Toast", "teleport.interrupted", nil, "warning")
		end
	end
end

-- Moves the character to a map (respawn point unless `at` is given) behind the client's loading screen:
-- MapTransition(mapId) shows it, the target area is streamed in, then MapTransition(nil) hides it. Yields.
function TravelService.TeleportToMap(player: Player, mapId: string, at: CFrame?)
	local model = player.Character
	if not model then
		return
	end
	local target = at or DeathService.SpawnCFrame(mapId, nil)
	Net.Fire(player, "MapTransition", mapId)
	task.wait(0.4)
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 8)
	end)
	model = player.Character
	if not model or player.Parent == nil then
		return
	end
	model:PivotTo(target)
	PlayerStateService.Set(player, { "character", "location", "map" }, mapId)
	TravelService.MarkVisited(player, mapId)
	task.delay(0.6, function()
		if player.Parent then
			Net.Fire(player, "MapTransition", nil)
		end
	end)
end

-- Portals (S08): walk up and press E; the client warns before red zones and maps above your level.
local PORTAL_RANGE = 20
local portalBusy: { [Player]: boolean } = {}

local function usePortal(player: Player, portalId: string): (boolean, string?)
	local portal = WorldService.GetPortal(portalId)
	if not portal or not PlayerStateService.GetCharacter(player) then
		return false, "error.badRequest"
	end
	if ResourceService.IsDead(player) or portalBusy[player] then
		return false, "error.wrongPhase"
	end
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - portal.position).Magnitude > PORTAL_RANGE then
		return false, "npc.error.tooFar"
	end
	if not WorldService.IsBuilt(portal.target) then
		return false, "portal.closed"
	end
	interrupt(player, false)
	local arrive = portal.arrive
	local at = if arrive then WorldService.GroundCFrame(portal.target, arrive.x, arrive.z) else nil
	portalBusy[player] = true
	task.spawn(function()
		TravelService.TeleportToMap(player, portal.target, at)
		portalBusy[player] = nil
	end)
	return true, nil
end

function TravelService.MarkVisited(player: Player, mapId: string)
	local char = PlayerStateService.GetCharacter(player)
	if char and not (char.visitedMaps or {})[mapId] then
		PlayerStateService.Set(player, { "character", "visitedMaps", mapId }, true)
	end
end

-- The cave map that holds a dungeon region's entrance, if it exists yet (S08/S09).
local function dungeonMap(region: string): Maps.MapDef?
	for _, map in Maps.byId do
		if map.dungeonRegion == region and map.dungeonEntrance then
			return map
		end
	end
	return nil
end

-- 5 s channel; on success consumes one `itemId` and runs `arrive`.
local function channel(player: Player, itemId: string, label: string, arrive: () -> ()): (boolean, string?)
	if ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "error.wrongPhase"
	end
	local token = (tokens[player] or 0) + 1
	tokens[player] = token
	local start = root.Position
	PlayerStateService.Set(player, { "travel" }, {
		endsAt = Workspace:GetServerTimeNow() + CHANNEL_SECONDS,
		duration = CHANNEL_SECONDS,
		label = label,
	})
	Net.Fire(player, "Toast", label, nil, "info")
	task.spawn(function()
		local finish = os.clock() + CHANNEL_SECONDS
		while os.clock() < finish do
			task.wait(0.1)
			if tokens[player] ~= token then
				return
			end
			local current = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not current or (current.Position - start).Magnitude > MOVE_LIMIT or ResourceService.IsDead(player) then
				interrupt(player, true)
				return
			end
		end
		if tokens[player] ~= token then
			return
		end
		tokens[player] = token + 1
		PlayerStateService.Set(player, { "travel" }, nil)
		-- The stone may have moved; consume one by id.
		if InventoryService.Remove(player, itemId, 1) < 1 then
			return
		end
		arrive()
	end)
	return true, nil
end

local function toMap(player: Player, itemId: string, mapId: string): (boolean, string?)
	local map = Maps.get(mapId)
	local char = PlayerStateService.GetCharacter(player)
	if not map or not char then
		return false, "error.badRequest"
	end
	if not (char.visitedMaps or {})[mapId] then
		return false, "teleport.notVisited"
	end
	if char.location.map == mapId and mapId ~= Config.StartingMap then
		return false, "teleport.sameMap"
	end
	return channel(player, itemId, "teleport.channelMap", function()
		TravelService.TeleportToMap(player, mapId)
		Net.Fire(player, "Toast", "teleport.arrived", { map = `@{map.nameKey}` }, "success")
	end)
end

local function toDungeon(player: Player, itemId: string, region: string): (boolean, string?)
	local map = dungeonMap(region)
	local entrance = map and map.dungeonEntrance
	if not map or not entrance then
		return false, "teleport.soon"
	end
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	local at = CFrame.new(origin + Vector3.new(entrance.x, entrance.y + 4, entrance.z))
	return channel(player, itemId, "teleport.channelDungeon", function()
		TravelService.TeleportToMap(player, map.id, at)
		Net.Fire(player, "Toast", "teleport.arrived", { map = `@{map.nameKey}` }, "success")
	end)
end

local function useStone(player: Player, _index: number, item: Types.ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	local target = def and def.use and def.use.target
	if target == "city" then
		return channel(player, item.id, "teleport.channel", function()
			TravelService.TeleportToMap(player, Config.StartingMap)
			Net.Fire(player, "Toast", "teleport.done", nil, "success")
		end)
	elseif target == "map" or target == "dungeon" then
		-- Needs a destination: the client opens the picker and calls UseMapStone.
		return false, "teleport.pick"
	elseif target and string.sub(target, 1, 8) == "dungeon:" then
		return toDungeon(player, item.id, string.sub(target, 9))
	end
	return false, "teleport.soon"
end

-- (inventory index, map id or dungeon region) for the Map Stone and the generic Dungeon Stone.
local function useMapStone(player: Player, index: number, target: string): (boolean, string?)
	local item = InventoryService.Get(player, index)
	local def = item and Items.get(item.id)
	local kind = def and def.use and def.use.target
	if not item or not def or def.use == nil or def.use.kind ~= "teleport" then
		return false, "error.badRequest"
	end
	if kind == "map" then
		return toMap(player, item.id, target)
	elseif kind == "dungeon" then
		return toDungeon(player, item.id, target)
	end
	return false, "error.badRequest"
end

function TravelService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	ResourceService = registry.Get("ResourceService")
	CharacterService = registry.Get("CharacterService")
	DeathService = registry.Get("DeathService")
	WorldService = registry.Get("WorldService")
	InventoryService.UseHandlers.teleport = useStone
end

function TravelService.Start()
	Net.Handle("UseMapStone", useMapStone)
	Net.Handle("UsePortal", usePortal)
	CharacterService.CharacterEntered:Connect(function(player: Player, char: Types.CharacterData)
		TravelService.MarkVisited(player, char.location.map)
	end)
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 then
			interrupt(player, true)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		interrupt(player, false)
	end)
	Players.PlayerRemoving:Connect(function(player)
		portalBusy[player] = nil
		tokens[player] = nil
	end)
end

return TravelService
