--!strict
-- Death and respawn (DESIGN §3.4). Nothing is lost. Respawn delay = RespawnBase + RespawnPerLevel x level
-- (halved by the "Fast Return" gamepass). "Respawn now" (Dragon Shards or Robux) skips the countdown.
-- S22: after the countdown the player chooses (RespawnChoice): "city" (the capital's spawn) or "here" (where
-- they fell; Logic/Respawn handles dungeons, falls under the map and blocked spots). No choice within
-- Config.DeathChoiceTimeout seconds = the city. The character comes back with 1 HP, full mana and energy and
-- the respawn protection (StatusEffectService "respawnShield"). Death clears harmful effects.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Respawn = require(Shared.Logic.Respawn)
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
		"StatusEffectService",
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
local StatusEffectService: any

type Pending = {
	token: number,
	mapId: string,
	position: Vector3?,
	respawnAt: number, -- server time the choice opens
	deadline: number, -- server time the choice defaults to the city
	busy: boolean, -- a respawn is running
}

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

-- "Here" -------------------------------------------------------------------------------------------------

local function overlapParams(): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local world = Workspace:FindFirstChild("World")
	params.FilterDescendantsInstances = if world then { world } else {}
	params.RespectCanCollide = true
	return params
end

-- Whether a character can stand at this ground CFrame (from WorldService.GroundCFrame, 4 studs over the
-- ground): no water under the feet, no colliding map geometry in the body.
local function standable(at: CFrame): boolean
	local feet = at.Position - Vector3.new(0, 4, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Workspace.Terrain }
	params.IgnoreWater = false
	local hit = Workspace:Raycast(feet + Vector3.new(0, 6, 0), Vector3.new(0, -12, 0), params)
	if hit and hit.Material == Enum.Material.Water then
		return false
	end
	local body = CFrame.new(feet + Vector3.new(0, 3, 0))
	return #Workspace:GetPartBoundsInBox(body, Vector3.new(2, 4.5, 2), overlapParams()) == 0
end

-- Ground CFrame where the character fell, or a free spot within Config.RespawnSearchRadius, or nil when the
-- death spot is unusable (Logic/Respawn decides what that means).
local function placeHere(state: Pending): (Respawn.Place, CFrame?)
	local map = Maps.get(state.mapId)
	local position = state.position
	if not map or not position then
		return "spawnPoint", nil
	end
	local lx, lz = position.X - map.offset.x, position.Z - map.offset.z
	local inside = WorldService.IsInsideMap(state.mapId, position)
	local ground = WorldService.GroundCFrame(state.mapId, lx, lz)
	local belowFloor = position.Y < ground.Position.Y - 4 - 12
	local blocked = not standable(ground)
	local free: CFrame? = nil
	if inside and not belowFloor and blocked then
		for _, offset in Respawn.searchOffsets(Config.RespawnSearchRadius) do
			local candidate = WorldService.GroundCFrame(state.mapId, lx + offset[1], lz + offset[2])
			if
				WorldService.IsInsideMap(state.mapId, candidate.Position)
				and math.abs(candidate.Position.Y - ground.Position.Y) < 12
				and standable(candidate)
			then
				free = candidate
				break
			end
		end
	end
	local place: Respawn.Place = Respawn.place(map.biome, "here", {
		inside = inside,
		belowFloor = belowFloor,
		blocked = blocked,
		freeNearby = free ~= nil,
	})
	if place == "here" then
		return "here", free or ground
	end
	return place, nil
end

local function respawnCFrame(state: Pending, choice: Respawn.Choice): (string, CFrame)
	if choice == "city" then
		return Config.StartingMap, WorldService.GetSpawnCFrame(Config.StartingMap)
	end
	local place, at = placeHere(state)
	if place == "here" and at then
		return state.mapId, at
	end
	-- Dungeons (entrance) and unusable spots (nearest spawn point) both come from SpawnCFrame.
	return state.mapId, DeathService.SpawnCFrame(state.mapId, state.position)
end

-- Respawn ------------------------------------------------------------------------------------------------

local function respawn(player: Player, token: number, choice: Respawn.Choice)
	local state = pending[player]
	if not state or state.token ~= token or state.busy then
		return
	end
	state.busy = true
	local mapId, at = respawnCFrame(state, choice)
	pending[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "death" }, nil)
	end
	if PlayerStateService.GetPhase(player) ~= "playing" then
		return
	end
	-- 1 HP, full mana and energy; the protection comes once the new model stands in the world.
	ResourceService.Revive(player)
	ResourceService.SetHp(player, 1)
	CharacterService.Respawn(player, at, mapId)
	StatusEffectService.ApplyRespawnShield(player)
	log:info("%s respawned (%s) on %s", player.Name, choice, mapId)
	DeathService.Respawned:Fire(player)
end

-- No choice in time: the city.
local function onDeadline(player: Player, token: number)
	local state = pending[player]
	if not state or state.token ~= token then
		return
	end
	local left = state.deadline - Workspace:GetServerTimeNow()
	if left > 0.05 then
		task.delay(left, onDeadline, player, token)
		return
	end
	respawn(player, token, "city")
end

-- Opens the choice now (paid respawn) and moves the deadline.
local function openChoice(player: Player, state: Pending)
	local now = Workspace:GetServerTimeNow()
	state.respawnAt = math.min(state.respawnAt, now)
	state.deadline = now + Config.DeathChoiceTimeout
	PlayerStateService.Set(player, { "death", "respawnAt" }, state.respawnAt)
	PlayerStateService.Set(player, { "death", "deadline" }, state.deadline)
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
	StatusEffectService.CleanseOnDeath(player)

	tokenCounter += 1
	local token = tokenCounter
	local zone = ZoneService.GetZone(player)
	local delay = DeathService.RespawnDelay(player, character.level)
	local now = Workspace:GetServerTimeNow()
	local state: Pending = {
		token = token,
		mapId = if zone then zone.map else character.location.map,
		position = if root then root.Position else nil,
		respawnAt = now + delay,
		deadline = now + delay + Config.DeathChoiceTimeout,
		busy = false,
	}
	pending[player] = state
	PlayerStateService.Set(player, { "death" }, {
		diedAt = now,
		respawnAt = state.respawnAt,
		deadline = state.deadline,
		cost = Config.RespawnNowCost,
		dungeon = (Maps.get(state.mapId) or {} :: any).biome == "dungeon",
	})
	log:info("%s died (%s), choice in %.1f s", player.Name, source, delay)
	task.delay(delay + Config.DeathChoiceTimeout, onDeadline, player, token)
end

-- RespawnChoice(choice): after the countdown (or a paid skip) the player picks "city" or "here".
local function onChoice(player: Player, choice: string): (boolean, string?)
	local state = pending[player]
	if not state then
		return false, "death.error.notDead"
	end
	if choice ~= "city" and choice ~= "here" then
		return false, "error.badRequest"
	end
	if Workspace:GetServerTimeNow() < state.respawnAt - 0.25 then
		return false, "death.error.wait"
	end
	if state.busy then
		return false, "error.wrongPhase"
	end
	task.spawn(respawn, player, state.token, choice :: Respawn.Choice)
	return true, nil
end

-- Revives a dead player where they fell with `hpPct` % health (Cleric Resurrection). Skips the timer and the
-- choice; the resurrected player gets the same respawn protection.
function DeathService.Revive(player: Player, hpPct: number): boolean
	local state = pending[player]
	if not state or state.busy then
		return false
	end
	state.busy = true
	pending[player] = nil
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "death" }, nil)
	end
	ResourceService.Revive(player)
	local at = if state.position then CFrame.new(state.position + Vector3.new(0, 3, 0)) else nil
	task.spawn(function()
		local maxHp = ResourceService.Get(player)
		ResourceService.SetHp(player, maxHp * math.clamp(hpPct, 1, 100) / 100)
		CharacterService.Respawn(player, at or DeathService.SpawnCFrame(state.mapId, nil), state.mapId)
		StatusEffectService.ApplyRespawnShield(player)
		DeathService.Respawned:Fire(player)
	end)
	return true
end

-- Kills the active character through the normal death flow (/kill me, /die). Removes the respawn protection
-- first, otherwise the damage filter would stop it.
function DeathService.Kill(player: Player)
	StatusEffectService.BreakRespawnShield(player)
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
	if Workspace:GetServerTimeNow() >= state.respawnAt then
		return false, "death.error.alreadyOpen"
	end
	local account: Types.AccountData? = PlayerStateService.Get(player, { "account" })
	if not account or account.dragonShards < Config.RespawnNowCost then
		return false, "error.notEnoughShards"
	end
	PlayerStateService.Set(player, { "account", "dragonShards" }, account.dragonShards - Config.RespawnNowCost)
	Analytics.shards(player, -Config.RespawnNowCost, account.dragonShards - Config.RespawnNowCost, "respawn")
	openChoice(player, state)
	return true, nil
end

-- Developer Product "instant respawn" (Robux): only granted while the player is dead (opens the choice now;
-- bought after the countdown it still counts, so the purchase is never retried forever).
local function respawnProduct(player: Player): boolean
	local state = pending[player]
	if not state then
		return false
	end
	openChoice(player, state)
	return true
end

function DeathService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
	ZoneService = registry.Get("ZoneService")
	WorldService = registry.Get("WorldService")
	MonetizationService = registry.Get("MonetizationService")
	StatusEffectService = registry.Get("StatusEffectService")
	MonetizationService.RegisterProduct("respawn", respawnProduct)
end

function DeathService.Start()
	ResourceService.Died:Connect(onDied)
	Net.Handle("RespawnNow", respawnNow)
	Net.Handle("RespawnChoice", onChoice)

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
