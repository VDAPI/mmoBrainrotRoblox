--!strict
-- Buffs and debuffs on entities, players and monsters alike (S05). One effect per kind per source; applying
-- again refreshes it. Ticking effects (bleed, poison, hot) act every second. Players get stat buffs through
-- StatService (modifier source "effects") and damage filtering through ResourceService (invulnerability,
-- damage reduction, absorb shields, mana shield). Monsters read slows/stuns/taunts through the queries below.
-- The model attribute "Effects" lists "kind:expiresAt" (server time) for the client icons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)

local Log = require(Shared.Util.Log)
local Signal = require(ReplicatedStorage.Packages.Signal)

local log = Log.new("StatusEffects")

local StatusEffectService = {
	Name = "StatusEffectService",
	Deps = { "EntityService", "ResourceService", "StatService", "CharacterService" },
	-- (entity, kind) after an effect was applied or removed.
	Changed = Signal.new(),
}

export type Effect = {
	kind: string,
	source: Player?,
	sourceKey: string, -- "p<userId>" or "env"
	value: number,
	expiresAt: number, -- server time
	tickAmount: number?, -- damage / heal per tick
	nextTick: number?,
	stats: { [string]: number }?, -- statBuff: stat -> value
	pct: boolean?,
}

local EntityService: any
local ResourceService: any
local StatService: any
local CharacterService: any

-- entity id -> list of effects
local effects: { [string]: { Effect } } = {}

local DEBUFFS = {
	stun = true,
	root = true,
	slow = true,
	freeze = true,
	bleed = true,
	poison = true,
	armorBreak = true,
	vulnerability = true,
	taunt = true,
}

local TICK_INTERVAL = 1

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(entity: any)
	local model = entity.model
	if not model or not model.Parent then
		return
	end
	local list = effects[entity.id]
	local parts = {}
	if list then
		for _, effect in list do
			table.insert(parts, `{effect.kind}:{math.floor(effect.expiresAt * 10) / 10}`)
		end
	end
	model:SetAttribute("Effects", if #parts > 0 then table.concat(parts, ";") else nil)
end

local function changed(entity: any, kind: string)
	publish(entity)
	if entity.kind == "player" and entity.player and kind == "statBuff" then
		StatService.Invalidate(entity.player)
	end
	if entity.kind == "monster" and entity.monster then
		entity.monster:RefreshSpeed(StatusEffectService.SlowFactor(entity))
	end
	StatusEffectService.Changed:Fire(entity, kind)
end

export type ApplyOptions = {
	duration: number,
	value: number?,
	source: Player?,
	tickAmount: number?,
	stats: { [string]: number }?,
	pct: boolean?,
}

-- Effects shortened in PvP.
local CROWD_CONTROL: { [string]: boolean } = { stun = true, root = true, slow = true, freeze = true }

function StatusEffectService.Apply(entity: any, kind: string, options: ApplyOptions)
	if not entity or options.duration <= 0 then
		return
	end
	if entity.kind == "monster" and entity.monster and not entity.monster:IsAlive() then
		return
	end
	-- Invulnerable targets ignore debuffs.
	if DEBUFFS[kind] and StatusEffectService.Has(entity, "invuln") then
		return
	end
	local duration = options.duration
	if entity.kind == "player" and options.source and options.source ~= entity.player then
		-- Taunt only works on monsters; crowd control from players is shorter on players (S10).
		if kind == "taunt" then
			return
		end
		if CROWD_CONTROL[kind] then
			duration *= Config.PvpCcMultiplier
		end
	end
	local list = effects[entity.id]
	if not list then
		list = {}
		effects[entity.id] = list
	end
	local sourceKey = if options.source then `p{options.source.UserId}` else "env"
	local t = now()
	local effect: Effect? = nil
	for _, existing in list do
		if existing.kind == kind and existing.sourceKey == sourceKey then
			effect = existing
			break
		end
	end
	if not effect then
		local created: Effect =
			{ kind = kind, source = options.source, sourceKey = sourceKey, value = 0, expiresAt = 0 }
		effect = created
		table.insert(list, created)
	end
	local e = effect :: Effect
	e.value = options.value or 0
	e.expiresAt = t + duration
	e.tickAmount = options.tickAmount
	e.nextTick = if options.tickAmount then t + TICK_INTERVAL else nil
	e.stats = options.stats
	e.pct = options.pct
	changed(entity, kind)
end

function StatusEffectService.Remove(entity: any, kind: string)
	local list = entity and effects[entity.id]
	if not list then
		return
	end
	local removed = false
	for i = #list, 1, -1 do
		if list[i].kind == kind then
			table.remove(list, i)
			removed = true
		end
	end
	if removed then
		changed(entity, kind)
	end
end

local function active(entity: any, kind: string): { Effect }
	local result = {}
	local list = entity and effects[entity.id]
	if list then
		local t = now()
		for _, effect in list do
			if effect.kind == kind and effect.expiresAt > t then
				table.insert(result, effect)
			end
		end
	end
	return result
end

function StatusEffectService.Has(entity: any, kind: string): boolean
	return #active(entity, kind) > 0
end

-- Strongest value of an effect kind (e.g. the biggest slow).
function StatusEffectService.Max(entity: any, kind: string): number
	local best = 0
	for _, effect in active(entity, kind) do
		best = math.max(best, effect.value)
	end
	return best
end

-- Removes the effect and returns its value (one-shot effects: nextShot, guaranteedCrit).
function StatusEffectService.Consume(entity: any, kind: string): number?
	local list = active(entity, kind)
	if #list == 0 then
		return nil
	end
	local value = list[1].value
	StatusEffectService.Remove(entity, kind)
	return value
end

function StatusEffectService.IsDisabled(entity: any): boolean
	return StatusEffectService.Has(entity, "stun") or StatusEffectService.Has(entity, "freeze")
end

function StatusEffectService.IsRooted(entity: any): boolean
	return StatusEffectService.IsDisabled(entity) or StatusEffectService.Has(entity, "root")
end

function StatusEffectService.SlowFactor(entity: any): number
	if StatusEffectService.IsRooted(entity) then
		return 0
	end
	return math.clamp(1 - StatusEffectService.Max(entity, "slow") / 100, 0.2, 1)
end

-- Player who taunted this monster most recently (still active), or nil.
function StatusEffectService.Taunter(entity: any): Player?
	local best: Effect? = nil
	for _, effect in active(entity, "taunt") do
		if effect.source and (best == nil or effect.expiresAt > best.expiresAt) then
			best = effect
		end
	end
	return if best then best.source else nil
end

-- Removes every harmful effect (Purify).
function StatusEffectService.Cleanse(entity: any)
	local list = entity and effects[entity.id]
	if not list then
		return
	end
	for i = #list, 1, -1 do
		if DEBUFFS[list[i].kind] then
			table.remove(list, i)
		end
	end
	changed(entity, "cleanse")
end

function StatusEffectService.Clear(entity: any)
	if entity and effects[entity.id] then
		effects[entity.id] = nil
		publish(entity)
		if entity.kind == "player" and entity.player then
			StatService.Invalidate(entity.player)
		end
	end
end

-- Player helpers -------------------------------------------------------------------------------------------

local function playerEntity(player: Player): any
	return EntityService.GetPlayerEntity(player)
end

function StatusEffectService.PlayerHas(player: Player, kind: string): boolean
	local entity = playerEntity(player)
	return entity ~= nil and StatusEffectService.Has(entity, kind)
end

-- StatService modifier source: active stat buffs on a player.
type Source = { key: string, flat: { [string]: number }?, pct: { [string]: number }? }

local function modifierSource(player: Player): Source?
	local entity = playerEntity(player)
	if not entity then
		return nil
	end
	local flat: { [string]: number } = {}
	local pct: { [string]: number } = {}
	for _, effect in active(entity, "statBuff") do
		local target = if effect.pct then pct else flat
		local stats: { [string]: number } = effect.stats or {}
		for stat, value in stats do
			target[stat] = (target[stat] or 0) + value
		end
	end
	if next(flat) == nil and next(pct) == nil then
		return nil
	end
	return { key = "source.effects", flat = flat, pct = pct }
end

-- ResourceService damage filter: invulnerability, damage reduction, absorb shields, mana shield.
local function damageFilter(player: Player, amount: number, _source: string): number
	local entity = playerEntity(player)
	if not entity then
		return amount
	end
	if StatusEffectService.Has(entity, "invuln") then
		return 0
	end
	local reduction = StatusEffectService.Max(entity, "damageReduction")
	if reduction > 0 then
		amount *= 1 - math.clamp(reduction, 0, 90) / 100
	end
	-- Absorb shields soak damage first.
	for _, shield in active(entity, "shield") do
		if amount <= 0 then
			break
		end
		local absorbed = math.min(shield.value, amount)
		shield.value -= absorbed
		amount -= absorbed
		if shield.value <= 0 then
			shield.expiresAt = 0
		end
	end
	-- Mana shield: part of the damage drains mana instead.
	local share = StatusEffectService.Max(entity, "manaShield")
	if share > 0 and amount > 0 then
		local _, mana = ResourceService.Get(player)
		local drain = math.min(mana, amount * share / 100)
		if drain > 0 and ResourceService.SpendMana(player, drain) then
			amount -= drain
		end
	end
	return math.max(0, amount)
end

-- Ticking ---------------------------------------------------------------------------------------------------

local function tickEntity(entity: any, list: { Effect }, t: number)
	local expired = false
	for i = #list, 1, -1 do
		local effect = list[i]
		if effect.expiresAt <= t then
			table.remove(list, i)
			expired = true
			continue
		end
		local nextTick = effect.nextTick
		if nextTick and effect.tickAmount and t >= nextTick then
			effect.nextTick = nextTick + TICK_INTERVAL
			if effect.kind == "hot" then
				if entity.kind == "player" and entity.player then
					ResourceService.Heal(entity.player, effect.tickAmount)
				end
			elseif entity.kind == "monster" and entity.monster then
				entity.monster:TakeDamage(effect.tickAmount, effect.source)
				StatusEffectService.Ticked:Fire(entity, effect)
			elseif entity.kind == "player" and entity.player then
				ResourceService.Damage(entity.player, effect.tickAmount, effect.kind)
				StatusEffectService.Ticked:Fire(entity, effect)
			end
		end
	end
	if expired then
		changed(entity, "expired")
	end
end

-- (entity, effect) after a damaging tick (CombatService draws the number).
StatusEffectService.Ticked = Signal.new()

function StatusEffectService.Init(registry)
	EntityService = registry.Get("EntityService")
	ResourceService = registry.Get("ResourceService")
	StatService = registry.Get("StatService")
	CharacterService = registry.Get("CharacterService")
	StatService.RegisterModifierSource("effects", modifierSource)
	ResourceService.SetDamageFilter(damageFilter)
end

function StatusEffectService.Start()
	EntityService.Unregistered:Connect(function(entity)
		effects[entity.id] = nil
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		local entity = playerEntity(player)
		if entity then
			effects[entity.id] = nil
		end
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local t = now()
		for id, list in effects do
			local entity = EntityService.Get(id)
			if not entity then
				effects[id] = nil
			else
				local ok, err = pcall(function()
					tickEntity(entity, list, t)
				end)
				if not ok then
					log:error("tick failed for %s: %s", id, tostring(err))
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		effects[`p{player.UserId}`] = nil
	end)
end

return StatusEffectService
