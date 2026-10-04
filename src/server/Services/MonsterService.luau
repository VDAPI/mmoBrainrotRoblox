--!strict
-- Monster spawners and the AI loop (DESIGN §15.1, ARCHITECTURE §7).
--   * spawners come from Data/Spawns (per map), positions relative to the map offset
--   * a spawner sleeps (no spawning, no AI) while no player is within Combat.sleepRadius
--   * AI ticks at Combat.aiTickRate per monster, staggered across frames
--   * Config.MaxActiveMonsters caps the number of live monsters on the server
-- Combat resolution (attacks, abilities, rewards) is plugged in by CombatService via SetCombatHandlers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Combat = require(Shared.Data.Combat)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Monster = require(script.Parent.Parent.Entities.Monster)
local MonsterAbilities = require(Shared.Data.MonsterAbilities)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Spawns = require(Shared.Data.Spawns)
local Types = require(Shared.Types)

local log = Log.new("MonsterService")

local MonsterService = {
	Name = "MonsterService",
	Deps = { "EntityService", "ZoneService", "ResourceService", "PlayerStateService", "StatusEffectService" },
	-- (monster) after a monster appeared in the world.
	Spawned = Signal.new(),
}

export type Handlers = {
	basicAttack: (monster: Monster.Monster, player: Player) -> (),
	telegraph: (monster: Monster.Monster, ability: MonsterAbilities.Ability, area: CFrame) -> (),
	resolveAbility: (monster: Monster.Monster, ability: MonsterAbilities.Ability, area: CFrame) -> (),
	died: (monster: Monster.Monster) -> (),
}

type SpawnerRuntime = {
	data: Spawns.Spawner,
	mapId: string,
	origin: Vector3,
	alive: { Monster.Monster },
	respawnAt: { number },
	awake: boolean,
}

local EntityService: any
local ZoneService: any
local ResourceService: any
local PlayerStateService: any
local StatusEffectService: any

local handlers: Handlers? = nil
local folder: Folder
local spawners: { SpawnerRuntime } = {}
local monsters: { Monster.Monster } = {}
local nextTick: { [Monster.Monster]: number } = {}
local spawnerOf: { [Monster.Monster]: SpawnerRuntime } = {}
local random = Random.new()

local TICK = 1 / Combat.aiTickRate
local CORPSE_SECONDS = 1.6

function MonsterService.SetCombatHandlers(h: Handlers)
	handlers = h
end

function MonsterService.All(): { Monster.Monster }
	return monsters
end

-- Ground position below `position` (ignores monsters and characters).
local function groundAt(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else position
end

local context: Monster.Context = {
	findPlayers = function(position: Vector3, radius: number): { Player }
		return EntityService.PlayersNear(position, radius)
	end,
	playerPosition = function(player: Player): Vector3?
		local model = player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		return if root then root.Position else nil
	end,
	playerLevel = function(player: Player): number
		local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		return if character then character.level else 1
	end,
	canTarget = function(_monster, player: Player): boolean
		if PlayerStateService.GetPhase(player) ~= "playing" or ResourceService.IsDead(player) then
			return false
		end
		if not player.Character then
			return false
		end
		-- Camouflaged players are invisible to monsters (Hunter skill).
		if StatusEffectService.PlayerHas(player, "camouflage") then
			return false
		end
		return ZoneService.GetPvpZone(player) ~= "green"
	end,
	isDisabled = function(monster): boolean
		return monster.entity ~= nil and StatusEffectService.IsDisabled(monster.entity)
	end,
	isRooted = function(monster): boolean
		return monster.entity ~= nil and StatusEffectService.IsRooted(monster.entity)
	end,
	taunter = function(monster): Player?
		return if monster.entity then StatusEffectService.Taunter(monster.entity) else nil
	end,
	isSafePosition = function(position: Vector3): boolean
		return ZoneService.ZoneAt(position, Config.StartingMap).pvp == "green"
	end,
	basicAttack = function(monster, player)
		if handlers then
			handlers.basicAttack(monster, player)
		end
	end,
	telegraph = function(monster, ability, area)
		if handlers then
			handlers.telegraph(monster, ability, area)
		end
	end,
	resolveAbility = function(monster, ability, area)
		if handlers then
			handlers.resolveAbility(monster, ability, area)
		end
	end,
	died = function(monster)
		MonsterService.OnDied(monster)
	end,
	moved = function(monster)
		if monster.entity then
			EntityService.UpdatePosition(monster.entity)
		end
	end,
}

-- Spawns one monster. Returns nil when the server budget is full or the id is unknown.
function MonsterService.SpawnAt(
	monsterId: string,
	variant: "normal" | "elite" | "elite2",
	level: number,
	at: CFrame,
	spawner: SpawnerRuntime?
): Monster.Monster?
	local def = Monsters.get(monsterId)
	if not def then
		return nil
	end
	if #monsters >= Config.MaxActiveMonsters then
		log:warn("monster budget reached (%d)", Config.MaxActiveMonsters)
		return nil
	end
	local actualVariant: "normal" | "elite" | "elite2" = if def.elites then variant else "normal"
	local ground = groundAt(at.Position)
	local monster = Monster.new(def, actualVariant, level, CFrame.new(ground) * at.Rotation, context, folder)
	monster.entity = EntityService.RegisterMonster(monster, monster.model)
	monster.spawnerId = if spawner then spawner.data.id else nil
	table.insert(monsters, monster)
	nextTick[monster] = os.clock() + random:NextNumber() * TICK
	if spawner then
		spawnerOf[monster] = spawner
		table.insert(spawner.alive, monster)
	end
	MonsterService.Spawned:Fire(monster)
	return monster
end

local function removeFrom(list: { any }, value: any)
	local index = table.find(list, value)
	if index then
		table.remove(list, index)
	end
end

local function fadeAndDestroy(monster: Monster.Monster)
	local info = TweenInfo.new(CORPSE_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in monster.model:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 then
			TweenService:Create(part, info, { Transparency = 1 }):Play()
		elseif part:IsA("ParticleEmitter") then
			part.Enabled = false
		end
	end
	task.delay(CORPSE_SECONDS + 0.1, function()
		monster:Destroy()
	end)
end

-- Called by the monster when its HP reaches 0.
function MonsterService.OnDied(monster: Monster.Monster)
	if handlers then
		local died = handlers.died
		local ok, err = pcall(function()
			died(monster)
		end)
		if not ok then
			log:error("death handler failed: %s", tostring(err))
		end
	end
	removeFrom(monsters, monster)
	nextTick[monster] = nil
	if monster.entity then
		EntityService.Unregister(monster.entity)
	end
	local spawner = spawnerOf[monster]
	spawnerOf[monster] = nil
	if spawner then
		removeFrom(spawner.alive, monster)
		local respawn = spawner.data.respawn
		table.insert(spawner.respawnAt, os.clock() + respawn.min + random:NextNumber() * (respawn.max - respawn.min))
	end
	fadeAndDestroy(monster)
end

-- Removes a monster without rewards (admin, map unload).
function MonsterService.Despawn(monster: Monster.Monster)
	removeFrom(monsters, monster)
	nextTick[monster] = nil
	if monster.entity then
		EntityService.Unregister(monster.entity)
	end
	local spawner = spawnerOf[monster]
	spawnerOf[monster] = nil
	if spawner then
		removeFrom(spawner.alive, monster)
	end
	monster:Destroy()
end

local function spawnFromSpawner(spawner: SpawnerRuntime, announce: boolean)
	local data = spawner.data
	local angle = random:NextNumber() * math.pi * 2
	local radius = random:NextNumber() * data.radius
	local position = spawner.origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local level = random:NextInteger(data.level.min, data.level.max)
	local facing = CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0)
	local monster = MonsterService.SpawnAt(data.monster, data.variant, level, CFrame.new(position) * facing, spawner)
	if monster and announce and monster.variant == "elite2" then
		for _, player in Players:GetPlayers() do
			local zone = ZoneService.GetZone(player)
			if zone and zone.map == spawner.mapId then
				Net.Fire(player, "SystemMessage", "combat.elite2Spawned", { name = "@" .. monster:Name() })
			end
		end
	end
end

local function updateSpawners()
	local now = os.clock()
	for _, spawner in spawners do
		spawner.awake = #EntityService.QueryPlayers(spawner.origin, Combat.sleepRadius) > 0
		if not spawner.awake then
			continue
		end
		-- Due respawns first, then fill up (initial population) without announcements.
		for i = #spawner.respawnAt, 1, -1 do
			if spawner.respawnAt[i] <= now then
				table.remove(spawner.respawnAt, i)
				spawnFromSpawner(spawner, true)
			end
		end
		local missing = spawner.data.count - #spawner.alive - #spawner.respawnAt
		for _ = 1, missing do
			spawnFromSpawner(spawner, false)
		end
	end
end

function MonsterService.Stats(): (number, number, number, number)
	local active, sleeping, awake = 0, 0, 0
	for _, spawner in spawners do
		if spawner.awake then
			awake += 1
		end
	end
	for _, monster in monsters do
		local spawner = spawnerOf[monster]
		if spawner and not spawner.awake then
			sleeping += 1
		else
			active += 1
		end
	end
	return active, sleeping, #spawners, awake
end

local function tick()
	local now = os.clock()
	for _, monster in table.clone(monsters) do
		local due = nextTick[monster]
		if due and now >= due then
			nextTick[monster] = due + TICK
			if now - due > TICK * 4 then
				nextTick[monster] = now + TICK -- fell behind (sleep or hitch): do not burst
			end
			local spawner = spawnerOf[monster]
			if spawner == nil or spawner.awake or monster.state ~= "idle" then
				local ok, err = pcall(function()
					monster:Step(now)
				end)
				if not ok then
					log:error("%s AI error: %s", monster.def.id, tostring(err))
				end
			end
		end
	end
end

function MonsterService.Init(registry)
	EntityService = registry.Get("EntityService")
	ZoneService = registry.Get("ZoneService")
	ResourceService = registry.Get("ResourceService")
	PlayerStateService = registry.Get("PlayerStateService")
	StatusEffectService = registry.Get("StatusEffectService")

	folder = Instance.new("Folder")
	folder.Name = "Monsters"
	folder.Parent = Workspace

	for mapId, list in Spawns.byMap do
		local map = Maps.get(mapId)
		if not map then
			log:warn("spawns for unknown map %s", mapId)
			continue
		end
		for _, data in list do
			if not Monsters.get(data.monster) then
				log:warn("spawner %s uses unknown monster %s", data.id, data.monster)
				continue
			end
			table.insert(spawners, {
				data = data,
				mapId = mapId,
				origin = Vector3.new(
					map.offset.x + data.position.x,
					map.offset.y + data.position.y,
					map.offset.z + data.position.z
				),
				alive = {},
				respawnAt = {},
				awake = false,
			})
		end
	end
end

function MonsterService.Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				updateSpawners()
			end)
			if not ok then
				log:error("spawner update failed: %s", tostring(err))
			end
			task.wait(1)
		end
	end)
	RunService.Heartbeat:Connect(tick)
	log:info("%d spawners loaded", #spawners)
end

return MonsterService
