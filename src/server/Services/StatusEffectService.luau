--!strict
-- Buffs and debuffs on entities, players and monsters alike (S05). An effect's key is (kind, sourceKey, skillId,
-- category) (S53); applying the same key again refreshes it, and a statBuff merges its stats. How effects of
-- different keys combine (strongest per category, own entries add up, multiplicative damage reduction) is
-- Logic/EffectStack. Ticking effects (bleed, poison, hot) act every second. Players get stat buffs through
-- StatService (modifier source "effects") and damage filtering through ResourceService (invulnerability,
-- damage reduction, absorb shields, mana shield). Monsters read slows/stuns/taunts through the queries below.
-- The model attribute "Effects" ("kind:expiresAt[:value]", one entry per kind, EffectStack.encode) feeds the
-- client icons.
-- S61: the intercept filter (Logic/Intercept, FilterPriority.intercept) runs before the mitigation filter
-- (FilterPriority.mitigation); heals over time and absorb shields on a player in PvP combat are scaled through
-- SetPvpScales (PvpService); a refreshed statBuff with unchanged numbers does not invalidate stats (party auras).
-- S63 (STATY 5): effects from items carry skillId "item" (EffectStack.ITEM); a running effect with maxStacks > 1
-- gains a stack, all stacks share one end time and multiply value and tickAmount (EffectStack.restack). A new,
-- removed or changed effect publishes "Effects" at once; a mere refresh at most once per PUBLISH_INTERVAL. Category
-- reads with the skill / item split go through CategoryValue; every DoT tick of a player on a player is x0.6 once
-- (Apply); the player's walk speed follows SlowFactor (StatService.SetSpeedFactor).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local BuffCategories = require(Shared.Data.BuffCategories)
local Combat = require(Shared.Data.Combat)
local Config = require(Shared.Config)
local Damage = require(Shared.Logic.Damage)
local EffectStack = require(Shared.Logic.EffectStack)
local Intercept = require(Shared.Logic.Intercept)
local Traits = require(Shared.Logic.Traits)

local Log = require(Shared.Util.Log)
local Signal = require(ReplicatedStorage.Packages.Signal)

local log = Log.new("StatusEffects")

local StatusEffectService = {
	Name = "StatusEffectService",
	Deps = { "EntityService", "ResourceService", "StatService", "CharacterService" },
	-- (entity, kind) after an effect was applied or removed.
	Changed = Signal.new(),
	-- (guard: Player, target: Player, moved: number, taken: number, attacker: any?) after a guard took part of a monster
	-- blow aimed at an ally (S61): moved = the part before the guard's own reductions, taken = what got through them.
	Intercepted = Signal.new(),
}

export type Effect = {
	kind: string,
	source: Player?,
	sourceKey: string, -- "p<userId>" or "env"
	value: number, -- unit x stacks (S63)
	unit: number?, -- S63: value of one stack
	expiresAt: number, -- server time
	tickAmount: number?, -- damage / heal per tick
	nextTick: number?,
	stats: { [string]: number }?, -- statBuff: stat -> value
	pct: boolean?,
	stacks: number?, -- S28: stacking damage over time (Cleave's bleed at level 10)
	skillId: string?, -- S53: skill (or later path node / "item") that applied it; part of the key
	category: string?, -- S53: Data/BuffCategories id; part of the key
	radius: number?, -- S61: intercept: studs the guard may stand from the target (nil = Combat.interceptRadius)
	appliedAt: number, -- server time of the last (re)application; a tie in a category goes to the newer one
	healCut: number?, -- S63: % less healing and shields on this player (Rending Gash, PvP)
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
	misfortune = true, -- S61: the enemy misses regular attacks (category enemyMiss)
	attackSlow = true, -- S63: slower attacks (category enemyAttackSlow)
	weaken = true, -- S63: the bearer deals less (category enemyDamageDown)
	frostbite = true, -- S65: the source's ice: +% damage from that player (SourceValue); lives as long as the slow
}
-- S65 kinds without a table entry: nextBasic (one-shot bonus of the next basic attack, Full Draw; only a basic attack
-- consumes it, so it never collides with nextShot), runeSeal (marker of a glowing Runic Seal; CombatService puts it
-- on and takes it off).

-- S63: damage over time; a player's ticks on a player are x Combat.pvp.dot (Apply).
local DOT_KINDS: { [string]: boolean } = { bleed = true, poison = true, burn = true }

local TICK_INTERVAL = 1
-- S63: a refresh that changes nothing but the end publishes "Effects" at most this often (s).
local PUBLISH_INTERVAL = 1

-- S63: publication state per entity id: refresh waiting, last publish (server time), last text per model.
local pending: { [string]: boolean } = {}
local lastPublish: { [string]: number } = {}
local lastEncoded: { [string]: { model: Instance, text: string? } } = {}

local function forget(id: string)
	effects[id] = nil
	pending[id] = nil
	lastPublish[id] = nil
	lastEncoded[id] = nil
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function publish(entity: any)
	local model = entity.model
	if not model or not model.Parent then
		return
	end
	local id = entity.id
	local t = now()
	lastPublish[id] = t
	pending[id] = nil
	local list = effects[id]
	local listed: { EffectStack.Listed } = {}
	if list then
		for _, effect in list do
			table.insert(listed, { kind = effect.kind, expiresAt = effect.expiresAt, value = effect.value })
		end
	end
	local text = EffectStack.encode(listed, t)
	local last = lastEncoded[id]
	if last and last.model == model and last.text == text then
		return
	end
	lastEncoded[id] = { model = model, text = text }
	model:SetAttribute("Effects", text)
end

-- Kinds that change the player's stats (StatService modifier source) and walk speed.
local STAT_KINDS: { [string]: boolean } = { statBuff = true, attackSlow = true, expired = true, cleanse = true }
local MOVE_KINDS: { [string]: boolean } =
	{ slow = true, root = true, stun = true, freeze = true, expired = true, cleanse = true }

local function changed(entity: any, kind: string)
	publish(entity)
	-- "expired": a stat buff may have run out; Invalidate is cheap (batched per frame).
	if entity.kind == "player" and entity.player then
		if STAT_KINDS[kind] then
			StatService.Invalidate(entity.player)
		end
		if MOVE_KINDS[kind] then
			StatService.RefreshWalkSpeed(entity.player)
		end
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
	-- S61: intercept only: studs the guard (source) may stand from the target; nil = Combat.interceptRadius.
	radius: number?,
	healCut: number?, -- S63: % less healing and shields on this player (Rending Gash, PvP)
	notBoss: boolean?, -- S63: bosses and Elite II ignore it; SkillEffect.notBoss (S70) maps here
	accumulate: boolean?, -- S65: a refresh adds the unpaid rest of the running DoT (EffectStack.accumulate)
}

-- S61 (ROZWOJ 7.6): heal and shield multipliers of a player in PvP combat. PvpService sets them in its Init (it
-- depends on this service, so this one cannot require it); 1 until then.
type Scale = (player: Player) -> number
local function one(_player: Player): number
	return 1
end
local healScale: Scale = one
local shieldScale: Scale = one

function StatusEffectService.SetPvpScales(heal: Scale, shield: Scale)
	healScale = heal
	shieldScale = shield
end

-- Effects shortened in PvP (S63: attack slow too, STATY 8).
-- S65: frostbite lives as long as the ice slow that set it, so PvP halves it the same way.
local CROWD_CONTROL: { [string]: boolean } =
	{ stun = true, root = true, slow = true, freeze = true, attackSlow = true, frostbite = true }

-- Applies (or refreshes) an effect. True when it was applied; callers may ignore the result.
function StatusEffectService.Apply(entity: any, kind: string, options: ApplyOptions): boolean
	if not entity or options.duration <= 0 then
		return false
	end
	if entity.kind == "monster" and entity.monster and not entity.monster:IsAlive() then
		return false
	end
	if options.notBoss and StatusEffectService.IsBossLike(entity) then
		return false
	end
	-- Invulnerable (or freshly respawned, S22) targets ignore debuffs.
	if
		DEBUFFS[kind]
		and (StatusEffectService.Has(entity, "invuln") or StatusEffectService.Has(entity, "respawnShield"))
	then
		return false
	end
	local duration = options.duration
	local tickAmount = options.tickAmount
	if entity.kind == "player" and options.source and options.source ~= entity.player then
		-- Taunt only works on monsters; crowd control from players is shorter on players (S10).
		if kind == "taunt" then
			return false
		end
		if CROWD_CONTROL[kind] then
			duration *= Config.PvpCcMultiplier
		end
		-- S63 (STATY 8, owner answer 18): the only place where a player's damage over time on a player gets x0.6
		-- (items and skills); the bases computed elsewhere never contain Combat.pvpModifier.
		if tickAmount and DOT_KINDS[kind] then
			tickAmount = Traits.pvpTick(tickAmount)
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
		if EffectStack.sameKey(existing, kind, sourceKey, options.skillId, options.category) then
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
	local unit = options.value or 0
	if kind == "shield" and entity.kind == "player" and entity.player then
		unit *= shieldScale(entity.player)
	end
	local running = e.expiresAt > t
	-- S65: the running schedule before restack, for accumulate.
	local schedule: EffectStack.Running? = if running
			and e.tickAmount
			and e.nextTick
		then { tickAmount = e.tickAmount :: number, nextTick = e.nextTick :: number, expiresAt = e.expiresAt }
		else nil
	local old: EffectStack.Stack? = if running
		then {
			stacks = e.stacks or 1,
			value = e.value,
			tickAmount = e.tickAmount,
			expiresAt = e.expiresAt,
			nextTick = e.nextTick,
		}
		else nil
	local state = EffectStack.restack(old, {
		unit = unit,
		tickUnit = tickAmount,
		maxStacks = options.maxStacks,
		duration = duration,
		now = t,
		tickInterval = TICK_INTERVAL,
	})
	-- S63: anything the icons or the stats see changed (S61: party auras refresh every second with the same numbers).
	local structural = not running
		or (e.stacks or 1) ~= state.stacks
		or e.value ~= state.value
		or (e.pct == true) ~= (options.pct == true)
		or not EffectStack.sameStats(e.stats, options.stats)
		or e.healCut ~= options.healCut
	e.stacks = state.stacks
	e.unit = unit
	e.value = state.value
	e.radius = options.radius
	e.tickAmount = state.tickAmount
	e.nextTick = state.nextTick
	if options.accumulate and tickAmount then
		-- S65 (ROZWOJ 7.2): the tick comes only from accumulate (stacks x tick would count earlier hits twice).
		local total = tickAmount * EffectStack.ticksBetween(t + TICK_INTERVAL, t + duration, TICK_INTERVAL)
		local maxStacks = options.maxStacks or 1
		e.tickAmount, e.nextTick = EffectStack.accumulate(schedule, {
			total = total,
			limit = if maxStacks > 1 then maxStacks else nil,
			duration = duration,
			now = t,
			interval = TICK_INTERVAL,
		})
	end
	e.healCut = options.healCut
	if kind == "statBuff" then
		-- Same key: the stats merge (Battle Cry's attack + its breakpoint's armor), the later end wins.
		local timed: EffectStack.Timed? = if running
			then { stats = e.stats, pct = e.pct, expiresAt = e.expiresAt }
			else nil
		e.stats, e.expiresAt =
			EffectStack.merge(timed, { stats = options.stats, pct = options.pct, expiresAt = state.expiresAt }, t)
	else
		e.expiresAt = state.expiresAt
		e.stats = options.stats
	end
	e.pct = options.pct
	e.appliedAt = t
	if structural then
		changed(entity, kind)
	else
		pending[entity.id] = true
	end
	return true
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

-- Strongest value of an effect kind (e.g. the biggest slow). slow and vulnerability each belong to one category
-- (enemySlow, enemyWeak) and manaShield has a single own source, so the biggest value is exactly what
-- Logic/EffectStack would pick; damageReduction needs the full rule (damageFilter), and since S63 armorBreak,
-- weaken and attackSlow are read through CategoryValue (skill + item split, caps).
function StatusEffectService.Max(entity: any, kind: string): number
	local best = 0
	for _, effect in active(entity, kind) do
		best = math.max(best, effect.value)
	end
	return best
end

-- S63 (STATY 5): working value of a "value" category (Data/BuffCategories) on the entity: EffectStack.value over the
-- active effects of the category's kind (split categories: strongest skill + strongest item). Unknown id: 0.
function StatusEffectService.CategoryValue(entity: any, categoryId: string): number
	local category = BuffCategories.get(categoryId)
	local kind = category and category.kind
	if not kind then
		return 0
	end
	local entries: { EffectStack.Entry } = {}
	for _, effect in active(entity, kind) do
		if effect.category == categoryId then
			table.insert(entries, {
				category = categoryId,
				value = effect.value,
				at = effect.appliedAt,
				item = effect.skillId == EffectStack.ITEM,
			})
		end
	end
	return EffectStack.value(entries, categoryId)
end

-- S63 (STATY 8): armour break on a player: only the item part, at most Combat.pvp.armorBreakStacks stacks (skills
-- never break the armour of players).
function StatusEffectService.PvpArmorBreak(entity: any): number
	local best = 0
	for _, effect in active(entity, "armorBreak") do
		if effect.skillId == EffectStack.ITEM then
			best = math.max(best, Damage.pvpArmorBreak(effect.unit or 0, effect.stacks or 1))
		end
	end
	return best
end

-- S65: the biggest value of the active effects of `kind` that `player` applied (Frostbite), 0 without one.
function StatusEffectService.SourceValue(entity: any, kind: string, player: Player): number
	local best = 0
	for _, effect in active(entity, kind) do
		if effect.source == player then
			best = math.max(best, effect.value)
		end
	end
	return best
end

-- S63: % less healing and shields on a player (strongest, no sum).
function StatusEffectService.HealCut(player: Player): number
	local entity = EntityService.GetPlayerEntity(player)
	local list = entity and effects[entity.id]
	local best = 0
	if list then
		local t = now()
		for _, effect in list do
			if effect.healCut and effect.expiresAt > t then
				best = math.max(best, effect.healCut)
			end
		end
	end
	return best
end

-- S63: bosses and Elite II (not boss helpers, not players).
function StatusEffectService.IsBossLike(entity: any): boolean
	if not entity or entity.kind ~= "monster" or not entity.monster then
		return false
	end
	local monster = entity.monster
	if monster.summoned then
		return false
	end
	return monster.isBoss == true or monster.variant == "boss" or monster.variant == "elite2"
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
		forget(entity.id)
		if entity.kind == "player" and entity.player then
			StatService.Invalidate(entity.player)
			StatService.RefreshWalkSpeed(entity.player)
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
	-- S63 (STATY 5): attack slow is negative attack speed (percentage points of the attack speed multiplier).
	local attackSlow = StatusEffectService.CategoryValue(entity, "enemyAttackSlow")
	if attackSlow > 0 then
		flat.atkSpeed = (flat.atkSpeed or 0) - attackSlow
	end
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
local function damageFilter(player: Player, amount: number, source: string, _attacker: any?): number
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

-- S61 (ROZWOJ 7.6): the Guardian's intercept. Part of a monster blow on `player` goes to the guard of the strongest
-- intercept effect on them; that part runs through every filter of the guard (source "intercept", which this filter
-- skips), the rest goes on through the target's own filters. Windows of the per-second cap per guard.
local interceptWindows: { [Player]: Intercept.Window } = {}

local function interceptFilter(player: Player, amount: number, source: string, attacker: any?): number
	if not Intercept.applies(source) then
		return amount
	end
	local entity = playerEntity(player)
	if not entity then
		return amount
	end
	local list = active(entity, "intercept")
	if #list == 0 then
		return amount
	end
	local position = EntityService.Position(entity)
	if not position then
		return amount
	end
	local candidates: { Intercept.Candidate } = {}
	for _, effect in list do
		local guard = effect.source
		if not guard or guard == player then
			continue
		end
		local guardEntity = playerEntity(guard)
		local guardPosition = guardEntity and EntityService.Position(guardEntity)
		if not guardPosition then
			continue
		end
		local offset = guardPosition - position
		table.insert(candidates, {
			guard = guard,
			share = effect.value,
			radius = effect.radius or Combat.interceptRadius,
			distance = Vector3.new(offset.X, 0, offset.Z).Magnitude,
			alive = not ResourceService.IsDead(guard),
		})
	end
	local kept, chosen, moved = Intercept.resolve(
		source,
		amount,
		candidates,
		interceptWindows,
		os.clock(),
		function(g: any): number
			return StatService.GetValue(g, "maxHp")
		end
	)
	if chosen and moved > 0 then
		local guard = chosen.guard :: Player
		local _, taken = ResourceService.Damage(guard, moved, "intercept", attacker)
		StatusEffectService.Intercepted:Fire(guard, player, moved, taken, attacker)
	end
	return kept
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
					local amount = effect.tickAmount * healScale(entity.player)
					local healed = ResourceService.Heal(entity.player, amount, effect.source)
					StatusEffectService.Ticked:Fire(entity, effect, healed)
				end
			elseif entity.kind == "monster" and entity.monster then
				local dealt = entity.monster:TakeDamage(effect.tickAmount, effect.source)
				StatusEffectService.Ticked:Fire(entity, effect, if type(dealt) == "number" then dealt else nil)
			elseif entity.kind == "player" and entity.player then
				-- S29: the number shows what got through (after shields); 0 = absorbed / immune. No attacker on purpose
				-- (S61): intercept and thorns never work on damage over time.
				local amount = effect.tickAmount
				if effect.kind == "poison" then
					-- S63 (STATY 5): poison resistance weakens every poison tick (items and skills).
					amount *= Damage.resMul(StatService.GetValue(entity.player, "resPoison"))
				end
				local _, filtered = ResourceService.Damage(entity.player, amount, effect.kind)
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
	StatService.SetSpeedFactor(function(player: Player): number
		local entity = playerEntity(player)
		return if entity then StatusEffectService.SlowFactor(entity) else 1
	end)
	ResourceService.SetDamageFilter(interceptFilter, ResourceService.FilterPriority.intercept)
	ResourceService.SetDamageFilter(damageFilter, ResourceService.FilterPriority.mitigation)
end

function StatusEffectService.Start()
	EntityService.Unregistered:Connect(function(entity)
		forget(entity.id)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		local entity = playerEntity(player)
		if entity then
			forget(entity.id)
		end
		interceptWindows[player] = nil
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
				forget(id)
			else
				local ok, err = pcall(function()
					tickEntity(entity, list, t)
					-- S63: a refresh waiting for publication (at most once per PUBLISH_INTERVAL).
					if pending[id] and EffectStack.publishDue(false, lastPublish[id], t, PUBLISH_INTERVAL) then
						publish(entity)
					end
				end)
				if not ok then
					log:error("tick failed for %s: %s", id, tostring(err))
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		forget(`p{player.UserId}`)
		interceptWindows[player] = nil
	end)
end

return StatusEffectService
