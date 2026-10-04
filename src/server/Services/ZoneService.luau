--!strict
-- Map and PvP zone of every playing character (ARCHITECTURE §8, DESIGN §3.3).
-- Zones are invisible parts tagged "ZoneVolume" (CollectionService) with attributes:
--   MapId (string), PvpZone ("green" | "yellow" | "red"), NameKey (string, optional; defaults to the map name)
-- The smallest volume containing the player wins (a cave inside a meadow). Outside every volume the map's
-- own zone from Data/Maps applies. WorldBuilder creates the volumes; S08 will generate them from data.
--
-- Result: model attributes MapId / PvpZone, state branch `zone` (the client shows the banner), and the
-- ZoneChanged signal.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Maps = require(Shared.Data.Maps)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local ZoneService = {
	Name = "ZoneService",
	Deps = { "PlayerStateService", "CharacterService" },
	-- (player, newZone: ZoneState, oldZone: ZoneState?)
	ZoneChanged = Signal.new(),
}

export type ZoneState = Types.ZoneState

local TAG = "ZoneVolume"
local VALID: { [string]: boolean } = { green = true, yellow = true, red = true }

local PlayerStateService: any
local CharacterService: any

local volumes: { BasePart } = {}
local current: { [Player]: ZoneState } = {}

local function volumeSize(part: BasePart): number
	return part.Size.X * part.Size.Y * part.Size.Z
end

local function addVolume(instance: Instance)
	if instance:IsA("BasePart") and not table.find(volumes, instance) then
		table.insert(volumes, instance)
		table.sort(volumes, function(a, b)
			return volumeSize(a) < volumeSize(b)
		end)
	end
end

local function removeVolume(instance: Instance)
	local index = table.find(volumes, instance :: any)
	if index then
		table.remove(volumes, index)
	end
end

local function contains(part: BasePart, position: Vector3): boolean
	local localPos = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

-- Zone at a world position. `fallbackMap` is used when no volume contains the point.
function ZoneService.ZoneAt(position: Vector3, fallbackMap: string): ZoneState
	for _, part in volumes do
		if contains(part, position) then
			local mapId = part:GetAttribute("MapId")
			local pvp = part:GetAttribute("PvpZone")
			if type(mapId) == "string" and type(pvp) == "string" and VALID[pvp] then
				local map = Maps.get(mapId)
				local nameKey = part:GetAttribute("NameKey")
				return {
					map = mapId,
					pvp = pvp :: Types.PvpZone,
					nameKey = if type(nameKey) == "string" then nameKey elseif map then map.nameKey else "map.unknown",
				}
			end
		end
	end
	local map = Maps.get(fallbackMap)
	return {
		map = fallbackMap,
		pvp = if map then map.zone else "green",
		nameKey = if map then map.nameKey else "map.unknown",
	}
end

function ZoneService.GetZone(player: Player): ZoneState?
	return current[player]
end

-- PvP zone of the player ("green" while not playing).
function ZoneService.GetPvpZone(player: Player): Types.PvpZone
	local zone = current[player]
	return if zone then zone.pvp else "green"
end

local function same(a: ZoneState?, b: ZoneState): boolean
	return a ~= nil and a.map == b.map and a.pvp == b.pvp and a.nameKey == b.nameKey
end

-- Re-evaluates one player now.
function ZoneService.Update(player: Player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not model or not root then
		return
	end
	local zone = ZoneService.ZoneAt(root.Position, character.location.map)
	local old = current[player]
	if same(old, zone) then
		return
	end
	current[player] = zone
	model:SetAttribute("MapId", zone.map)
	model:SetAttribute("PvpZone", zone.pvp)
	if zone.map ~= character.location.map then
		PlayerStateService.Set(player, { "character", "location", "map" }, zone.map)
	end
	PlayerStateService.Set(player, { "zone" }, zone)
	ZoneService.ZoneChanged:Fire(player, zone, old)
end

function ZoneService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
end

function ZoneService.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		addVolume(instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(addVolume)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(removeVolume)

	CharacterService.ModelSpawned:Connect(function(player: Player, model: Model)
		-- Re-apply attributes on the fresh model even when the zone did not change.
		current[player] = nil
		if model.Parent then
			ZoneService.Update(player)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		current[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "zone" }, nil)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.ZoneCheckInterval)
			for _, player in Players:GetPlayers() do
				if PlayerStateService.GetPhase(player) == "playing" then
					ZoneService.Update(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		current[player] = nil
	end)
end

return ZoneService
