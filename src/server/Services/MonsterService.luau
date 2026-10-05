--!strict
-- Monster spawners and the AI loop (DESIGN §15.1, ARCHITECTURE §7).
--   * spawners come from Data/Spawns (per map), positions relative to the map offset; since S19 every
--     spawner is a group of 1–4 (Logic/AreaSpawns) that spawns, fights and respawns together: hitting or
--     aggroing one member pulls the whole group, the group comes back 30–45 s after its last member died,
--     models carry GroupId / GroupSize (living members) for the client's group rings
--   * a spawner sleeps (no spawning, no AI) while no player is within Combat.sleepRadius; groups asleep for
--     SLEEP_DESPAWN seconds with nobody fighting are removed and spawn fresh on the next wake
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
	respawnAt: number?, -- the whole group comes back at this time
	spawned: boolean, -- the group has been populated since the last despawn
	awake: boolean,
	asleepSince: number,
}

local SLEEP_DESPAWN = 90

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

-- Ground position below `position` (ignores monsters and characters). The ray starts only a little above
-- the point so spawners inside caves (terrain roof overhead) land on the cave floor.
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
	local hit = Workspace:Raycast(position + Vector3.new(0, 14, 0), Vector3.new(0, -200, 0), params)
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
	engaged = function(monster, player: Player)
		-- The group fights together: everyone alive in the group joins the fight against the same player.
		local spawner = spawnerOf[monster]
		if not spawner then
			return
		end
		for _, member in spawner.alive do
			if member ~= monster and member:IsAlive() and member.threat[player] == nil then
				member:AddThreat(player, 0)
			end
		end
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
	spawner: SpawnerRuntime?,
	attributes: { [string]: any }?
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
	local monster =
		Monster.new(def, actualVariant, level, CFrame.new(ground) * at.Rotation, context, folder, attributes)
	monster.entity = EntityService.RegisterMonster(monster, monster.model)
	monster.spawnerId = if spawner then spawner.data.id else nil
	if spawner then
		monster.home = spawner.origin
	end
	table.insert(monsters, monster)
	nextTick[monster] = os.clock() + random:NextNumber() * TICK
	if spawner then
		spawnerOf[monster] = spawner
		table.insert(spawner.alive, monster)
	end
	MonsterService.Spawned:Fire(monster)
	return monster
end

-- Spawns a monster from a custom kind definition (dungeon bosses). Not tied to a spawner; ignores the budget.
function MonsterService.SpawnCustom(def: Monsters.MonsterDef, variant: any, level: number, at: CFrame): Monster.Monster
	local ground = groundAt(at.Position)
	local monster = Monster.new(def, variant, level, CFrame.new(ground) * at.Rotation, context, folder)
	monster.entity = EntityService.RegisterMonster(monster, monster.model)
	table.insert(monsters, monster)
	nextTick[monster] = os.clock()
	MonsterService.Spawned:Fire(monster)
	return monster
end

local function removeFrom(list: { any }, value: any)
	local index = table.find(list, value)
	if index then
		table.remove(list, index)
	end
end

-- Living members of a group, mirrored on every member (client group rings, "xN" plate).
local function refreshGroupSize(spawner: SpawnerRuntime)
	local n = #spawner.alive
	for _, member in spawner.alive do
		member.model:SetAttribute("GroupSize", n)
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
		refreshGroupSize(spawner)
		if #spawner.alive == 0 then
			local respawn = spawner.data.respawn
			spawner.respawnAt = os.clock() + respawn.min + random:NextNumber() * (respawn.max - respawn.min)
		end
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
		refreshGroupSize(spawner)
	end
	monster:Destroy()
end

-- Spawns the whole group (all members at once). Elite II picks its kind from `choices`.
local function spawnGroup(spawner: SpawnerRuntime, announce: boolean)
	local data = spawner.data
	spawner.spawned = true
	spawner.respawnAt = nil
	local kinds = data.members or table.create(data.count, data.monster)
	if data.choices and #data.choices > 0 then
		kinds = { data.choices[random:NextInteger(1, #data.choices)] }
	end
	local attributes = { GroupId = data.id, GroupSize = #kinds }
	for _, kind in kinds do
		local angle = random:NextNumber() * math.pi * 2
		-- sqrt keeps the members evenly spread over the circle instead of bunched in the middle.
		local radius = math.sqrt(random:NextNumber()) * data.radius
		local position = spawner.origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local level = random:NextInteger(data.level.min, data.level.max)
		local facing = CFrame.Angles(0, random:NextNumber() * math.pi * 2, 0)
		local monster =
			MonsterService.SpawnAt(kind, data.variant, level, CFrame.new(position) * facing, spawner, attributes)
		if monster and announce and monster.variant == "elite2" then
			for _, player in Players:GetPlayers() do
				local zone = ZoneService.GetZone(player)
				if zone and zone.map == spawner.mapId then
					Net.Fire(player, "SystemMessage", "combat.elite2Spawned", { name = "@" .. monster:Name() })
				end
			end
		end
	end
	refreshGroupSize(spawner)
end

-- Removes a sleeping group without rewards; it spawns fresh when a player comes back.
local function despawnGroup(spawner: SpawnerRuntime)
	for _, member in table.clone(spawner.alive) do
		MonsterService.Despawn(member)
	end
	spawner.spawned = false
end

local function groupIdle(spawner: SpawnerRuntime): boolean
	for _, member in spawner.alive do
		if member.state ~= "idle" then
			return false
		end
	end
	return true
end

-- Player positions, gathered once per update (spawners x players distance checks are cheap).
local function playerPositions(): { Vector3 }
	local list = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(list, root.Position)
		end
	end
	return list
end

local function updateSpawners()
	local now = os.clock()
	local positions = playerPositions()
	local radiusSq = Combat.sleepRadius * Combat.sleepRadius
	for _, spawner in spawners do
		local awake = false
		for _, position in positions do
			local d = position - spawner.origin
			if d.X * d.X + d.Z * d.Z <= radiusSq and math.abs(d.Y) < 300 then
				awake = true
				break
			end
		end
		if awake ~= spawner.awake then
			spawner.awake = awake
			spawner.asleepSince = now
		end
		if not awake then
			if spawner.spawned and #spawner.alive > 0 and now - spawner.asleepSince > SLEEP_DESPAWN then
				if groupIdle(spawner) then
					despawnGroup(spawner)
				end
			end
			continue
		end
		if spawner.respawnAt and spawner.respawnAt <= now then
			spawnGroup(spawner, true)
		elseif not spawner.spawned or (#spawner.alive == 0 and spawner.respawnAt == nil) then
			spawnGroup(spawner, false)
		end
	end
end

-- Group statistics for /groups: groups, size distribution, active (awake) groups.
function MonsterService.GroupStats(mapId: string?): (number, { number }, number)
	local total, active = 0, 0
	local sizes = { 0, 0, 0, 0 }
	for _, spawner in spawners do
		if mapId == nil or spawner.mapId == mapId then
			total += 1
			local n = math.clamp(spawner.data.count, 1, 4)
			sizes[n] += 1
			if spawner.awake then
				active += 1
			end
		end
	end
	return total, sizes, active
end

-- Respawns the Elite II of a cave right away (admin /e2 spawn). Returns false when the map has none.
function MonsterService.RespawnElite2(mapId: string): boolean
	for _, spawner in spawners do
		if spawner.mapId == mapId and spawner.data.variant == "elite2" then
			despawnGroup(spawner)
			spawnGroup(spawner, true)
			return true
		end
	end
	return false
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
				respawnAt = nil,
				spawned = false,
				awake = false,
				asleepSince = 0,
			})
		end
	end
end

-- Spawners within `radius` of a position, nearest first (admin /nearby).
function MonsterService.SpawnersNear(
	position: Vector3,
	radius: number
): {
	{
		id: string,
		monster: string,
		variant: string,
		alive: number,
		count: number,
		distance: number,
	}
}
	local result = {}
	for _, spawner in spawners do
		local distance = (spawner.origin - position).Magnitude
		if distance <= radius then
			table.insert(result, {
				id = spawner.data.id,
				monster = spawner.data.monster,
				variant = spawner.data.variant,
				alive = #spawner.alive,
				count = spawner.data.count,
				distance = math.floor(distance),
			})
		end
	end
	table.sort(result, function(a, b)
		return a.distance < b.distance
	end)
	return result :: any
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
