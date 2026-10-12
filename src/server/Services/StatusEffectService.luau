--!strict
-- Buffs and debuffs on entities, players and monsters alike (S05). An effect's key is (kind, sourceKey, skillId,
-- category) (S53); applying the same key again refreshes it, and a statBuff merges its stats. How effects of
-- different keys combine (strongest per category, own entries add up, multiplicative damage reduction) is
-- Logic/EffectStack. Ticking effects (bleed, poison, hot) act every second. Players get stat buffs through
-- StatService (modifier source "effects") and damage filtering through ResourceService (invulnerability,
-- damage reduction, absorb shields, mana shield). Monsters read slows/stuns/taunts through the queries below.
-- The model attribute "Effects" ("kind:expiresAt[:value]", one entry per kind, EffectStack.encode) feeds the
-- client icons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local EffectStack = require(Shared.Logic.EffectStack)

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
	stacks: number?, -- S28: stacking damage over time (Cleave's bleed at level 10)
	skillId: string?, -- S53: skill (or later path node / "item") that applied it; part of the key
	category: string?, -- S53: Data/BuffCategories id; part of the key
	appliedAt: number, -- server time of the last (re)application; a tie in a category goes to the newer one
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
	burn = true, -- adaptive fire skills (S18)
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
	local listed: { EffectStack.Listed } = {}
	if list then
		for _, effect in list do
			table.insert(listed, { kind = effect.kind, expiresAt = effect.expiresAt, value = effect.value })
		end
	end
	model:SetAttribute("Effects", EffectStack.encode(listed, now()))
end

local function changed(entity: any, kind: string)
	publish(entity)
	-- "expired": a stat buff may have run out; Invalidate is cheap (batched per frame).
	if entity.kind == "player" and entity.player and (kind == "statBuff" or kind == "expired") then
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
	-- S28: re-applying from the same source adds a stack (tick amount x stacks) up to this many.
	maxStacks: number?,
	-- S53 (ROZWOJ 7.2): both are part of the key, so effects of different skills (and the caster's own copy vs the
	-- party copy of one skill) never overwrite each other. skillId = skill, path node or "item"; category =
	-- Data/BuffCategories id (nil = own).
	skillId: string?,
	category: string?,
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
	-- Invulnerable (or freshly respawned, S22) targets ignore debuffs.
	if
		DEBUFFS[kind]
		and (StatusEffectService.Has(entity, "invuln") or StatusEffectService.Has(entity, "respawnShield"))
	then
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
		if
			existing.kind == kind
			and existing.sourceKey == sourceKey
			and existing.skillId == options.skillId
			and existing.category == options.category
		then
			effect = existing
			break
		end
	end
	if not effect then
		local created: Effect = {
			kind = kind,
			source = options.source,
			sourceKey = sourceKey,
			value = 0,
			expiresAt = 0,
			skillId = options.skillId,
			category = options.category,
			appliedAt = t,
		}
		effect = created
		table.insert(list, created)
	end
	local e = effect :: Effect
	local stacks = 1
	if options.maxStacks and options.maxStacks > 1 and e.expiresAt > t then
		stacks = math.min(options.maxStacks, (e.stacks or 1) + 1)
	end
	e.stacks = stacks
	e.value = options.value or 0
	e.tickAmount = if options.tickAmount then options.tickAmount * stacks else nil
	e.nextTick = if options.tickAmount then t + TICK_INTERVAL else nil
	if kind == "statBuff" then
		-- Same key: the stats merge (Battle Cry's attack + its breakpoint's armor), the later end wins.
		local old: EffectStack.Timed? = if e.expiresAt > t
			then { stats = e.stats, pct = e.pct, expiresAt = e.expiresAt }
			else nil
		e.stats, e.expiresAt =
			EffectStack.merge(old, { stats = options.stats, pct = options.pct, expiresAt = t + duration }, t)
	else
		e.expiresAt = t + duration
		e.stats = options.stats
	end
	e.pct = options.pct
	e.appliedAt = t
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

-- Strongest value of an effect kind (e.g. the biggest slow). slow, vulnerability and armorBreak each belong to one
-- category (enemySlow, enemyWeak, enemyArmor) and manaShield has a single own source, so the biggest value is
-- exactly what Logic/EffectStack would pick; only damageReduction needs the full rule (damageFilter).
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

-- Respawn protection (S22, DESIGN §3.4): no damage, no debuffs, monsters ignore the player, no PvP against
-- them. Any attack of the player ends it (BreakRespawnShield).
function StatusEffectService.ApplyRespawnShield(player: Player, seconds: number?)
	local entity = playerEntity(player)
	if entity then
		StatusEffectService.Apply(entity, "respawnShield", { duration = seconds or Config.RespawnShieldSeconds })
	end
end

-- Ends the respawn protection: the player attacked (basic attack, offensive skill, PvP). True when it had one.
function StatusEffectService.BreakRespawnShield(player: Player): boolean
	local entity = playerEntity(player)
	if entity and StatusEffectService.Has(entity, "respawnShield") then
		StatusEffectService.Remove(entity, "respawnShield")
		return true
	end
	return false
end

-- Death clears harmful effects (DoTs, slows, ...); buffs from blessings and skills stay (S22).
function StatusEffectService.CleanseOnDeath(player: Player)
	local entity = playerEntity(player)
	if entity then
		StatusEffectService.Cleanse(entity)
	end
end

-- StatService modifier source: active stat buffs on a player.
type Source = { key: string, flat: { [string]: number }?, pct: { [string]: number }? }

local function modifierSource(player: Player): Source?
	local entity = playerEntity(player)
	if not entity then
		return nil
	end
	local entries: { EffectStack.Entry } = {}
	for _, effect in active(entity, "statBuff") do
		table.insert(
			entries,
			{ category = effect.category, stats = effect.stats, pct = effect.pct, at = effect.appliedAt }
		)
	end
	local flat, pct = EffectStack.stats(entries)
	if next(flat) == nil and next(pct) == nil then
		return nil
	end
	return { key = "source.effects", flat = flat, pct = pct }
end

-- Extra own damage-reduction entries (ROZWOJ 7.1). CombatService registers the "lastStand" hook here in its
-- Init, so this service never requires CombatService (which depends on it).
export type ReductionProvider = (player: Player, source: string) -> number

local reductionProviders: { ReductionProvider } = {}

function StatusEffectService.RegisterReductionProvider(provider: ReductionProvider)
	table.insert(reductionProviders, provider)
end

-- ResourceService damage filter: invulnerability, damage reduction (Logic/EffectStack: multiplicative, capped),
-- absorb shields, mana shield.
local function damageFilter(player: Player, amount: number, source: string): number
	local entity = playerEntity(player)
	if not entity then
		return amount
	end
	if StatusEffectService.Has(entity, "invuln") or StatusEffectService.Has(entity, "respawnShield") then
		return 0
	end
	local entries: { EffectStack.Entry } = {}
	for _, effect in active(entity, "damageReduction") do
		table.insert(entries, { category = effect.category, value = effect.value, at = effect.appliedAt })
	end
	for _, provider in reductionProviders do
		local r = provider(player, source)
		if r > 0 then
			table.insert(entries, { category = "own", value = r, at = 0 })
		end
	end
	local reduction = EffectStack.reduction(entries)
	if reduction > 0 then
		amount *= 1 - reduction / 100
	end
	-- Absorb shields soak damage first.
	for _, shield in active(entity, "shield") do
		if amount <= 0 then
			break
		end
		local absorbed = math.min(shield.value, amount)
		shield.value -= absorbed
		amount -= absorbed
		if absorbed > 0 then
			ResourceService.ShieldAbsorbed(player, absorbed, shield.source)
		end
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
					local healed = ResourceService.Heal(entity.player, effect.tickAmount, effect.source)
					StatusEffectService.Ticked:Fire(entity, effect, healed)
				end
			elseif entity.kind == "monster" and entity.monster then
				local dealt = entity.monster:TakeDamage(effect.tickAmount, effect.source)
				StatusEffectService.Ticked:Fire(entity, effect, if type(dealt) == "number" then dealt else nil)
			elseif entity.kind == "player" and entity.player then
				-- S29: the number shows what got through (after shields); 0 = absorbed / immune.
				local _, filtered = ResourceService.Damage(entity.player, effect.tickAmount, effect.kind)
				StatusEffectService.Ticked:Fire(entity, effect, filtered)
			end
		end
	end
	if expired then
		changed(entity, "expired")
	end
end

-- (entity, effect, amount?) after a tick: damage dealt after shields, or HP healed by "hot" (CombatService draws
-- the number, S29).
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
