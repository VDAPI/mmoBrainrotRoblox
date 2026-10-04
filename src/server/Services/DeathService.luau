--!strict
-- Death and respawn (DESIGN §3.4). Nothing is lost. Respawn delay = RespawnBase + RespawnPerLevel x level
-- (halved by the "Fast Return" gamepass). "Respawn now" costs Dragon Shards. The character respawns at the
-- nearest part tagged "SpawnPoint" whose MapId matches the map it died on, with full resources.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("DeathService")

local DeathService = {
	Name = "DeathService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"ResourceService",
		"ZoneService",
		"WorldService",
		"MonetizationService",
	},
	-- (player) after the character respawned.
	Respawned = Signal.new(),
}

local SPAWN_TAG = "SpawnPoint"

local PlayerStateService: any
local CharacterService: any
local ResourceService: any
local ZoneService: any
local WorldService: any
local MonetizationService: any

type Pending = { token: number, mapId: string, position: Vector3? }

local pending: { [Player]: Pending } = {}
local tokenCounter = 0

function DeathService.RespawnDelay(player: Player, level: number): number
	local delay = Config.RespawnBase + Config.RespawnPerLevel * level
	if MonetizationService.HasPass(player, "fastRespawn") then
		delay *= Config.FastRespawnMultiplier
	end
	return delay
end

function DeathService.IsDead(player: Player): boolean
	return pending[player] ~= nil
end

-- Nearest spawn point of the map to `position` (falls back to the map's default spawn).
function DeathService.SpawnCFrame(mapId: string, position: Vector3?): CFrame
	-- Death in a boss dungeon: back in front of the dungeon entrance (DESIGN §3.4, §16).
	local map = Maps.get(mapId)
	if map and map.biome == "dungeon" then
		return WorldService.ResolveLocation(mapId, 0, 0, 0)
	end
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, instance in CollectionService:GetTagged(SPAWN_TAG) do
		if instance:IsA("BasePart") and instance:GetAttribute("MapId") == mapId then
			local distance = if position then (instance.Position - position).Magnitude else 0
			if distance < bestDistance then
				best = instance
				bestDistance = distance
			end
		end
	end
	if best then
		local spot = best.Position + Vector3.new(0, 3, 0)
		return CFrame.new(spot) * best.CFrame.Rotation
	end
	return WorldService.GetSpawnCFrame(mapId)
end

local function respawn(player: Player, token: number)
	local state = pending[player]
	if not state or state.token ~= token then
		return
	end
	pending[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "death" }, nil)
	end
	if PlayerStateService.GetPhase(player) ~= "playing" then
		return
	end
	ResourceService.Revive(player)
	CharacterService.Respawn(player, DeathService.SpawnCFrame(state.mapId, state.position))
	DeathService.Respawned:Fire(player)
end

local function onDied(player: Player, source: string)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character or pending[player] then
		return
	end
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end

	tokenCounter += 1
	local token = tokenCounter
	local zone = ZoneService.GetZone(player)
	pending[player] = {
		token = token,
		mapId = if zone then zone.map else character.location.map,
		position = if root then root.Position else nil,
	}
	local delay = DeathService.RespawnDelay(player, character.level)
	local now = Workspace:GetServerTimeNow()
	PlayerStateService.Set(player, { "death" }, {
		diedAt = now,
		respawnAt = now + delay,
		cost = Config.RespawnNowCost,
	})
	log:info("%s died (%s), respawn in %.1f s", player.Name, source, delay)
	task.delay(delay, respawn, player, token)
end

-- Revives a dead player where they fell with `hpPct` % health (Cleric Resurrection). Skips the timer.
function DeathService.Revive(player: Player, hpPct: number): boolean
	local state = pending[player]
	if not state then
		return false
	end
	pending[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "death" }, nil)
	end
	ResourceService.Revive(player)
	local at = if state.position then CFrame.new(state.position + Vector3.new(0, 3, 0)) else nil
	task.spawn(function()
		CharacterService.Respawn(player, at or DeathService.SpawnCFrame(state.mapId, nil))
		-- Revive restores everything; bring HP down to the resurrection percentage.
		local hp = ResourceService.Get(player)
		local keep = hp * math.clamp(hpPct, 1, 100) / 100
		if keep < hp then
			ResourceService.Damage(player, hp - keep, "resurrection")
		end
		DeathService.Respawned:Fire(player)
	end)
	return true
end

-- Kills the active character through the normal death flow (/kill me).
function DeathService.Kill(player: Player)
	local hp = ResourceService.Get(player)
	local wasGod = ResourceService.IsGod(player)
	ResourceService.SetGod(player, false)
	ResourceService.Damage(player, hp + 1, "admin")
	ResourceService.SetGod(player, wasGod)
end

local function respawnNow(player: Player): (boolean, string?)
	local state = pending[player]
	if not state then
		return false, "death.error.notDead"
	end
	local account: Types.AccountData? = PlayerStateService.Get(player, { "account" })
	if not account or account.dragonShards < Config.RespawnNowCost then
		return false, "error.notEnoughShards"
	end
	PlayerStateService.Set(player, { "account", "dragonShards" }, account.dragonShards - Config.RespawnNowCost)
	task.spawn(respawn, player, state.token)
	return true, nil
end

function DeathService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
	ZoneService = registry.Get("ZoneService")
	WorldService = registry.Get("WorldService")
	MonetizationService = registry.Get("MonetizationService")
end

function DeathService.Start()
	ResourceService.Died:Connect(onDied)
	Net.Handle("RespawnNow", respawnNow)

	CharacterService.CharacterLeaving:Connect(function(player: Player)
		pending[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "death" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return DeathService
