--!strict
-- HP / Mana / Energy of active characters (ARCHITECTURE §7, DESIGN §4.4). The server owns the values;
-- Humanoid.Health only mirrors the HP percentage (MaxHealth = 100) and Roblox's own regeneration is
-- disabled by the empty StarterCharacterScripts/Health script.
--
-- API: Damage, Heal, SpendMana, SpendEnergy, Restore, MarkCombat, InCombat, IsDead, Revive, SetGod.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local ResourceService = {
	Name = "ResourceService",
	Deps = { "PlayerStateService", "CharacterService", "StatService" },
	-- (player, source: string) when HP reaches 0 (or the Roblox humanoid died, e.g. falling into the void).
	Died = Signal.new(),
	-- (player, amount, source) after damage was applied.
	Damaged = Signal.new(),
}

local PlayerStateService: any
local CharacterService: any
local StatService: any

type Pool = {
	hp: number,
	mana: number,
	energy: number,
	lastCombat: number,
	dead: boolean,
	god: boolean,
	-- Last replicated whole numbers.
	sent: { hp: number, mana: number, energy: number },
}

local pools: { [Player]: Pool } = {}

-- Optional filter applied to incoming damage (StatusEffectService: invulnerability, shields, reductions).
type DamageFilter = (player: Player, amount: number, source: string) -> number
local damageFilters: { DamageFilter } = {}

-- Adds a filter that may reduce incoming damage (shields, duels). Filters run in registration order.
function ResourceService.SetDamageFilter(filter: DamageFilter)
	table.insert(damageFilters, filter)
end

local function maxOf(player: Player, id: string): number
	return math.max(1, StatService.GetValue(player, id))
end

local function mirrorHumanoid(player: Player, pool: Pool)
	local model = player.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid.MaxHealth = 100
	if pool.dead then
		return
	end
	-- Keep a sliver above 0 so the humanoid only dies when the server says so.
	humanoid.Health = math.max(0.1, pool.hp / maxOf(player, "maxHp") * 100)
end

-- Writes changed whole-number values into the character data (and therefore to the client).
local function publish(player: Player, pool: Pool, force: boolean?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	for _, id in { "hp", "mana", "energy" } do
		local rounded = math.floor((pool :: any)[id] + 0.5)
		if force or rounded ~= (pool.sent :: any)[id] then
			(pool.sent :: any)[id] = rounded
			PlayerStateService.Set(player, { "character", id }, rounded)
		end
	end
	mirrorHumanoid(player, pool)
end

local function clampToMax(player: Player, pool: Pool)
	pool.hp = math.clamp(pool.hp, 0, maxOf(player, "maxHp"))
	pool.mana = math.clamp(pool.mana, 0, maxOf(player, "maxMana"))
	pool.energy = math.clamp(pool.energy, 0, maxOf(player, "maxEnergy"))
end

function ResourceService.Get(player: Player): (number, number, number)
	local pool = pools[player]
	if not pool then
		return 0, 0, 0
	end
	return pool.hp, pool.mana, pool.energy
end

function ResourceService.IsDead(player: Player): boolean
	local pool = pools[player]
	return pool ~= nil and pool.dead
end

function ResourceService.MarkCombat(player: Player)
	local pool = pools[player]
	if pool then
		pool.lastCombat = os.clock()
	end
end

function ResourceService.InCombat(player: Player): boolean
	local pool = pools[player]
	return pool ~= nil and os.clock() - pool.lastCombat < Config.CombatTimeout
end

function ResourceService.SetGod(player: Player, enabled: boolean)
	local pool = pools[player]
	if pool then
		pool.god = enabled
	end
end

function ResourceService.IsGod(player: Player): boolean
	local pool = pools[player]
	return pool ~= nil and pool.god
end

-- Applies damage. Returns the HP actually removed.
function ResourceService.Damage(player: Player, amount: number, source: string?): number
	local pool = pools[player]
	if not pool or pool.dead or amount <= 0 or amount ~= amount then
		return 0
	end
	pool.lastCombat = os.clock()
	if pool.god then
		return 0
	end
	for _, filter in damageFilters do
		amount = filter(player, amount, source or "unknown")
		if amount <= 0 then
			return 0
		end
	end
	local dealt = math.min(pool.hp, amount)
	pool.hp -= dealt
	local died = pool.hp <= 0
	if died then
		pool.hp = 0
		pool.dead = true
	end
	publish(player, pool)
	ResourceService.Damaged:Fire(player, dealt, source or "unknown")
	if died then
		ResourceService.Died:Fire(player, source or "unknown")
	end
	return dealt
end

-- Returns the HP actually restored.
function ResourceService.Heal(player: Player, amount: number): number
	local pool = pools[player]
	if not pool or pool.dead or amount <= 0 or amount ~= amount then
		return 0
	end
	local before = pool.hp
	pool.hp = math.min(maxOf(player, "maxHp"), pool.hp + amount)
	publish(player, pool)
	return pool.hp - before
end

local function spend(player: Player, id: "mana" | "energy", amount: number): boolean
	local pool = pools[player]
	if not pool or pool.dead or amount < 0 then
		return false
	end
	if pool.god then
		return true
	end
	if (pool :: any)[id] < amount then
		return false
	end
	(pool :: any)[id] -= amount
	publish(player, pool)
	return true
end

function ResourceService.SpendMana(player: Player, amount: number): boolean
	return spend(player, "mana", amount)
end

function ResourceService.SpendEnergy(player: Player, amount: number): boolean
	return spend(player, "energy", amount)
end

-- Restores one resource (potions). Returns the amount actually restored.
function ResourceService.Add(player: Player, resource: "hp" | "mana" | "energy", amount: number): number
	local pool = pools[player]
	if not pool or pool.dead or amount <= 0 or amount ~= amount then
		return 0
	end
	local maxId = if resource == "hp" then "maxHp" elseif resource == "mana" then "maxMana" else "maxEnergy"
	local before = (pool :: any)[resource]
	local after = math.min(maxOf(player, maxId), before + amount);
	(pool :: any)[resource] = after
	publish(player, pool)
	return after - before
end

-- Missing amount of a resource (0 when full).
function ResourceService.Missing(player: Player, resource: "hp" | "mana" | "energy"): number
	local pool = pools[player]
	if not pool then
		return 0
	end
	local maxId = if resource == "hp" then "maxHp" elseif resource == "mana" then "maxMana" else "maxEnergy"
	return math.max(0, maxOf(player, maxId) - (pool :: any)[resource])
end

-- Fills HP, Mana and Energy (level up, respawn, /heal).
function ResourceService.Restore(player: Player)
	local pool = pools[player]
	if not pool then
		return
	end
	pool.hp = maxOf(player, "maxHp")
	pool.mana = maxOf(player, "maxMana")
	pool.energy = maxOf(player, "maxEnergy")
	publish(player, pool)
end

-- Clears the dead flag and restores everything (DeathService calls this before respawning the model).
function ResourceService.Revive(player: Player)
	local pool = pools[player]
	if not pool then
		return
	end
	pool.dead = false
	pool.lastCombat = 0
	ResourceService.Restore(player)
end

local function onEntered(player: Player, character: Types.CharacterData)
	-- Signal handler order is not guaranteed; make sure the maxima exist before clamping.
	if StatService.Get(player) == nil then
		StatService.Recompute(player)
	end
	local pool: Pool = {
		hp = character.hp,
		mana = character.mana,
		energy = character.energy,
		lastCombat = 0,
		dead = false,
		god = false,
		sent = { hp = -1, mana = -1, energy = -1 },
	}
	pools[player] = pool
	-- New characters (and ones that logged out dead) start full.
	if character.hp <= 0 then
		pool.hp = maxOf(player, "maxHp")
		pool.mana = maxOf(player, "maxMana")
		pool.energy = maxOf(player, "maxEnergy")
	end
	clampToMax(player, pool)
	publish(player, pool, true)
end

local function regenerate(dt: number)
	for player, pool in pools do
		if pool.dead then
			continue
		end
		local result = StatService.Get(player)
		if not result then
			continue
		end
		local v = result.values
		local hpRate = if os.clock() - pool.lastCombat < Config.CombatTimeout then v.hpRegenCombat else v.hpRegen
		pool.hp = math.min(v.maxHp, pool.hp + hpRate * dt)
		pool.mana = math.min(v.maxMana, pool.mana + v.manaRegen * dt)
		pool.energy = math.min(v.maxEnergy, pool.energy + v.energyRegen * dt)
		publish(player, pool)
	end
end

local function onModelSpawned(player: Player, model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local pool = pools[player]
	if not humanoid or not pool then
		return
	end
	mirrorHumanoid(player, pool)
	humanoid.Died:Connect(function()
		-- Deaths the server did not cause (void, Roblox reset) still go through the death system.
		local current = pools[player]
		if current and not current.dead and player.Character == model then
			current.hp = 0
			current.dead = true
			publish(player, current)
			ResourceService.Died:Fire(player, "world")
		end
	end)
end

function ResourceService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	StatService = registry.Get("StatService")
end

-- Switching characters is not a way out of a fight.
local function switchGuard(player: Player): string?
	if ResourceService.IsDead(player) then
		return "death.error.switchDead"
	end
	if ResourceService.InCombat(player) then
		return "error.inCombat"
	end
	return nil
end

function ResourceService.Start()
	CharacterService.SetSwitchGuard(switchGuard)
	CharacterService.CharacterEntered:Connect(onEntered)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		local pool = pools[player]
		if pool then
			publish(player, pool)
		end
		pools[player] = nil
	end)
	CharacterService.ModelSpawned:Connect(onModelSpawned)

	StatService.Changed:Connect(function(player: Player)
		local pool = pools[player]
		if pool then
			clampToMax(player, pool)
			publish(player, pool)
		end
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(Config.ResourceTick)
			local now = os.clock()
			regenerate(now - last)
			last = now
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			pools[player] = nil
		end)
	end)
end

return ResourceService
