--!strict
-- Everything a skill handler needs while resolving one cast: the caster, resolved target / point, rank
-- values, and helpers for areas, damage, healing, effects and visuals. Built by SkillService per cast.
-- S28/S55: `skill` is the skill as it works at its rank (Logic/Skills.effective: breakpoint numbers applied, extra
-- effects in skill.effects / skill.selfEffects / skill.allyEffects) and `bp` the merged behaviours without effects; `damage` applies the on-hit ones (lifesteal, knockback, execute, stun near the target,
-- splash) and `applyEffect` stacks bleeds; `lingering` and `trap` leave lasting areas.
-- S54 (ROZWOJ 8): skill hits (`damage`) and attack-based DoTs (`attack`) x Skills.speedFactor of the weapon
-- (`speedMul`); heals and shields carry no weapon factor.
-- S69 (ROZWOJ 7.5): heals and shields of a cast come from the target's max HP plus a magic-attack part on the heal
-- curve (`healAmount` = Logic/Skills.healAmount, per target); `heal` stays the one entry for heal bonuses; `healZone`
-- is the healing field (Circle of Light 10B, Sanctuary S70); on-hit `healWounded` heals the most wounded ally.
-- S65: the weapon-element effect of adaptive skills lives in Skills/Elements (numbers in Data/Skills.ADAPTIVE); the
-- most wounded ally and healing an ally are module functions (Context.bind) CombatService shares (Saving Blow).
-- S70: `rollDice` is Fortune's dice (faces = effects with `face`, Logic/Roll); `applyEffect` takes a scale and a
-- duration multiplier (dice faces, PvP), turns `burn` into damage over time like bleed / poison (a holy skill's burn
-- ticks in light) and a data `hot` into % max HP per second, and passes `notBoss` for every kind; `damage` with
-- `holy` adds the holyDamage hook outside holy skills (Purify 5B burst).
-- S71 (ROZWOJ 9.3-9.5): Context.healFactor is the one heal / shield multiplier (healBonus + allyHealBonus +
-- lowHpHealBonus on heals, healPower, the healCrit roll); healFrom and Types/Support use it. Divine Wrath's heal lives
-- in onHit (holyStrikeHeal; holyHealAll for HOLY_HEAL_SKILLS).
-- S73 (ROZWOJ 14.2): every shield of a skill goes through `shield` (x healFactor, the one bonus path); `consumeFury`
-- spends the caster's Fury for furyConsume skills (the stacks feed the furyConsume stats field); a "hot" effect with
-- hpPct heals that % of the target's max HP per second x healFactor; `resolve` reads a ValueRef at the rank.
-- S76 (ROZWOJ 11.3, 11.4, 16.4, 16.5): `pull` is the one pull of every skill type (Logic/Skills.pullRadius); `damage`
-- adds areaSkillDamage on area skills (not pulses or splashes), the finisher multiplier and critCdr; `applyEffect`
-- stacks poison (poisonStacks), keeps the poison spread / mark jump of the breakpoint on the effect and sends every
-- poison through CombatService.ApplyPoison; `lingering` pulses carry `lingering = true` and a poison field counts as
-- the Hunter's poison (DotBonus).
-- S79: spell tags (Logic/Skills.tag), areaHits / secondary per hit, Mage hooks (area, single, spell, resonance, Cascade, Elemental Trail zone, cdrPerTarget).
-- S80 (ROZWOJ 12.5): `castMul` (Arcane Charges and empowered of this cast, a snapshot SkillService takes at the cast)
-- multiplies every hit but zone ticks; `chargesSpent` (Arcane Discharge) goes to the clients as `ch`; `costMods` is
-- the CostMods the cast paid with (Arcane Torrent drains with the same); services.Beam starts a beam channel.
-- S140 (Logic/Burn, DESIGN-18 §6.1): a skill with `burnStacks` adds that many stacks of the caster's one burn on every
-- main hit (CombatService.ApplyBurn); fire hits get Kindling's burnBonus per own stack on the target and values.vsBurning
-- (Immolate) per stack; the skill field `knockback` pushes like the breakpoint.
-- S141 (Logic/Chill, DESIGN-18 §6.1): every freeze of the player's ice (effects, the chill counter, Blizzard through
-- ctx.freeze) gives bosses and Elite II Deep Chill instead; main ice hits feed Winter's Grip's counter (chillFreeze);
-- Glacial Spike (values.vsFrozen) and Shatter (values.shatter, which ends the freeze or spends the Deep Chill) on their
-- main hits; an effect with maxStacks stacks (a growing slow).
-- S142 (Logic/Shock, DESIGN-18 §6.1): every hit gets the skill's values.crit and, on lightning spells, Overcharge's crit
-- (critAdd / critDmgAdd); a sureCrit skill's main hit always crits without spending a guaranteedCrit; Conductor makes a
-- single-target lightning spell's main hit jump to the nearest other enemy (a secondary hit).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Burn = require(Shared.Logic.Burn)
local Chill = require(Shared.Logic.Chill)
local Chain = require(Shared.Logic.Chain)
local Combat = require(Shared.Data.Combat)
local Damage = require(Shared.Logic.Damage)
local Elements = require(script.Parent.Elements)
local Push = require(script.Parent.Push)
local Rng = require(Shared.Logic.Rng)
local Roll = require(Shared.Logic.Roll)
local Shock = require(Shared.Logic.Shock)
local SkillData = require(Shared.Data.Skills)
local Skills = require(Shared.Logic.Skills)
local Traits = require(Shared.Logic.Traits)
local Types = require(Shared.Types)

export type Services = {
	Combat: any,
	StatusEffect: any,
	Resource: any,
	Stat: any,
	Entity: any,
	Pvp: any,
	Party: any,
	Death: any,
	PartyAura: any, -- S73: BehindAnchor for behindEffect
	Zone: any, -- S77: the Falcon does not strike in green zones
	Fx: (player: Player, data: { [string]: any }) -> (),
	PassiveHook: (player: Player, id: string) -> number,
	ReduceCooldown: (player: Player, skillId: string, seconds: number) -> (), -- S76: critCdr
	WeaponElement: (player: Player) -> string?,
	WeaponSpeed: (player: Player) -> number?, -- base speed of the equipped weapon (S54)
	Toast: (player: Player, key: string, args: { [string]: any }?, kind: string?) -> (), -- S70
	-- S80 (ROZWOJ 12.5): starts the beam channel of `ctx` on `target` (SkillService owns the loop and its ends);
	-- `tick(n)` deals tick n. (false, errorKey) without mana for one tick.
	Beam: (ctx: Ctx, target: any, tick: (n: number) -> ()) -> (boolean, string?),
}

-- S70: options of ctx.applyEffect: value (and resolved stats) x scale, duration x durationMul.
export type EffectOptions = { scale: number?, durationMul: number? }

export type Ctx = {
	player: Player,
	skill: SkillData.SkillDef,
	rank: number,
	character: Types.CharacterData,
	caster: any, -- player entity
	root: BasePart,
	target: any?, -- entity
	point: Vector3?,
	-- S75: set by a handler whose cast must not get the selfEffects (guard's self variant: Sacrifice protects
	-- only while intercepting); SkillService.finished reads it
	skipSelfEffects: boolean?,
	-- S76: the cooldown set at the cast in seconds (0 without; critCdr shortens it by a share)
	cooldown: number,
	-- S79: passive hooks of the caster, read once per cast
	hook: (id: string) -> number,
	tag: string, -- S79: Logic/Skills.tag of the skill ("area" | "single", ROZWOJ 12.3)
	-- S79: mana before this cast's cost as a share of max mana (SkillService sets it; resonance)
	manaFraction: number,
	-- S80: Arcane Charges and empowered of this cast, 1 = none
	castMul: number,
	-- S80: Arcane Charges Arcane Discharge consumed (the clients grow the bolt, `ch`)
	chargesSpent: number?,
	-- S80: the CostMods this cast paid with (Arcane Torrent drains with the same)
	costMods: Skills.CostMods?,
	services: Services,
	value: (field: string) -> number,
	resolve: (ref: SkillData.ValueRef?) -> number, -- S73: Logic/Skills.resolve at this rank
	scaled: (value: SkillData.Scaled?) -> number,
	bp: SkillData.Breakpoint, -- S28: merged breakpoint behaviours at this rank
	attack: () -> number, -- physical or magic attack depending on the skill, x speedMul (S54)
	magAtk: () -> number,
	healMul: () -> number, -- heal level curve at the caster's level (S54)
	-- S69: base heal / shield of this cast on `target` (max HP part + magic part x healMul), before bonuses
	healAmount: (target: Player, prefix: "heal" | "shield") -> number,
	speedMul: number, -- skill damage x weapon speed / Combat.skillSpeedRef (S54)
	fx: (data: { [string]: any }) -> (),
	element: string?, -- the skill's element (adaptive: the weapon's), S18
	isEnemy: (entity: any) -> boolean,
	-- options: plain, canDodge, consumeShot, primary, from, holy, noAdaptive, noProc, lingering (a zone tick, S76);
	-- S79: areaHits = enemies hit in this wave by ROZWOJ 12.3 (default 1), secondary = a splash, pierce, arc or split
	damage: (entity: any, percent: number, options: { [string]: any }?) -> Damage.Result?,
	-- (HP restored, HP it tried to restore after the heal bonus and the PvP scale, S61)
	heal: (player: Player, amount: number) -> (number, number),
	-- S73: an absorb shield of `amount` x healFactor (shield) on `entity`; opts = extra StatusEffectService options
	shield: (entity: any, amount: number, duration: number, opts: { [string]: any }?) -> (),
	-- S73: spends every Fury stack of the caster, returns how many (also kept for the furyConsume stats field)
	consumeFury: () -> number,
	applyEffects: (entity: any, side: "enemy" | "self" | "allies") -> (),
	applyEffect: (entity: any, effect: SkillData.SkillEffect, opts: EffectOptions?) -> (), -- one effect
	-- S141 (Logic/Chill): an ice freeze of `duration` s through applyEffect (bosses and Elite II: Deep Chill)
	freeze: (entity: any, duration: number) -> (),
	-- S70 (ROZWOJ 9.4): Fortune's dice / wheel for the party around the caster; half = one face, half the duration
	rollDice: (opts: { half: boolean? }?) -> (),
	-- the lasting areas of a cast (S28): the breakpoint's zone and (S79) the areaLingering zone, both only on wave 1
	-- (Logic/Skills.castZones); inCircle = enemies in a randomTarget circle (the hook zone's share)
	lingering: (center: Vector3, percent: number, wave: number?, inCircle: number?) -> (),
	-- S69: healing field, every second share % of each ally's own heal of this skill; onTick adds extras (S70)
	healZone: (
		center: Vector3,
		radius: number,
		duration: number,
		share: number,
		onTick: ((ally: Player, entity: any) -> ())?
	) -> (),
	trap: (at: Vector3, radius: number, duration: number, effect: SkillData.SkillEffect) -> (),
	-- S76: pulls enemies to `center` (Skills.pullRadius); true when it pulled (wait Push.DURATION before the blow)
	pull: (center: Vector3) -> boolean,
	wounded: (center: Vector3, radius: number, except: Player?) -> Player?, -- most wounded ally (S28)
	enemiesInCircle: (center: Vector3, radius: number) -> { any },
	enemiesInCone: (origin: CFrame, radius: number, angle: number) -> { any },
	enemiesInLine: (origin: CFrame, length: number, width: number) -> { any },
	alliesInCircle: (center: Vector3, radius: number) -> { Player },
	facing: () -> CFrame, -- caster position looking at the point / target / forward (flat)
	ground: (position: Vector3) -> Vector3,
}

local Context = {}

-- S70: the server's one source of dice rolls (Logic/Roll; tests pass a fixed seed to Roll directly).
local rng = Rng.new()

-- S65: the weapon-element recipe of adaptive skills (numbers in Data/Skills.ADAPTIVE).
local ADAPTIVE_SPEC: Traits.ElementSpec = {
	burnPct = SkillData.ADAPTIVE.burnPct,
	burnDuration = SkillData.ADAPTIVE.burnDuration,
	slowPct = SkillData.ADAPTIVE.slowPct,
	slowDuration = SkillData.ADAPTIVE.slowDuration,
	arcPct = SkillData.ADAPTIVE.arcPct,
	arcRadius = SkillData.ADAPTIVE.arcRadius,
	exactTicks = SkillData.ADAPTIVE.exactTicks, -- S79: the full burnPct over the real ticks
}

-- S71 (ROZWOJ 9.5, Holy Wrath): skills whose direct hits heal through Divine Wrath at holyHealAll % strength.
local HOLY_HEAL_SKILLS: { [string]: boolean } =
	{ radiance = true, judgement = true, brandOfLight = true, hammerOfHeaven = true }

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- S65: services of the shared helpers below (SkillService.Init binds them).
local bound: Services? = nil

function Context.bind(services: Services)
	bound = services
end

local function need(): Services
	local services = bound
	assert(services, "Skills/Context: Context.bind(services) was not called")
	return services
end

-- Share of HP left (monsters and players), nil when unknown.
function Context.hpFraction(entity: any): number?
	local services = need()
	if entity.kind == "monster" and entity.monster then
		local monster = entity.monster
		return monster.hp / math.max(1, monster.stats.maxHp)
	elseif entity.kind == "player" and entity.player then
		local hp = services.Resource.Get(entity.player)
		local maxHp = services.Stat.GetValue(entity.player, "maxHp")
		return if maxHp > 0 then hp / maxHp else nil
	end
	return nil
end

-- Living party members of `player` within `radius` (flat) of `center`; without a party the player alone. S126: the
-- help group (PartyService.Allies: a ranked match side instead of the party).
function Context.alliesInCircle(player: Player, center: Vector3, radius: number): { Player }
	local services = need()
	local Entity = services.Entity
	local list = {}
	for _, member in services.Party.Allies(player) do
		local entity = Entity.GetPlayerEntity(member)
		local p = entity and Entity.Position(entity)
		if p and flat(p - center).Magnitude <= radius and not services.Resource.IsDead(member) then
			table.insert(list, member)
		end
	end
	return list
end

-- The ally (the player included) with the lowest HP share below full within `radius`; nil when nobody is wounded.
function Context.mostWounded(player: Player, center: Vector3, radius: number, except: Player?): Player?
	local services = need()
	local best, bestFraction = nil, 1
	for _, ally in Context.alliesInCircle(player, center, radius) do
		if ally ~= except then
			local hp = services.Resource.Get(ally)
			local maxHp = services.Stat.GetValue(ally, "maxHp")
			local fraction = if maxHp > 0 then hp / maxHp else 1
			if fraction < bestFraction then
				best, bestFraction = ally, fraction
			end
		end
	end
	return best
end

-- S71 (ROZWOJ 9.3, 9.4, 14.1): multiplier of a heal (shield = false) or shield `healer` puts on `target`, and whether
-- it is critical. Heals: 1 + Skills.healBonusPct (healBonus, allyHealBonus on others, lowHpHealBonus on a target below
-- SkillData.LOW_HP_HEAL % before the heal); heals and shields: healPower (S62) and one healCrit roll (Lucky Mending,
-- x SkillData.HEAL_CRIT_MUL). The PvP scale is not here (healFrom, StatusEffectService). One call per heal, per heal
-- over time (its sum at the cast) and per shield.
function Context.healFactor(healer: Player, target: Player, shield: boolean): (number, boolean)
	local services = need()
	local result = services.Stat.Get(healer)
	local values: { [string]: number } = if result then result.values else {}
	local mul = 1 + (values.healPower or 0) / 100
	if not shield then
		local maxHp = services.Stat.GetValue(target, "maxHp")
		local fraction = if maxHp > 0 then services.Resource.Get(target) / maxHp else 1
		local bonus = Skills.healBonusPct({
			healBonus = services.PassiveHook(healer, "healBonus"),
			allyHealBonus = services.PassiveHook(healer, "allyHealBonus"),
			lowHpHealBonus = services.PassiveHook(healer, "lowHpHealBonus"),
		}, target ~= healer, fraction)
		mul *= 1 + bonus / 100
	end
	local chance = Skills.healCritChance(values.critChance or 0, services.PassiveHook(healer, "healCrit"))
	local crit = chance > 0 and rng:chance(chance)
	if crit then
		mul *= SkillData.HEAL_CRIT_MUL
	end
	return mul, crit
end

-- `healer` heals `target` for `amount` x Context.healFactor and the PvP scale (S61); the heal source makes the fight
-- summary and the heal cut (S63) work. Returns (HP restored, HP it tried to restore). S71: Saving Blow's heal of an
-- ally comes here too, so it gets the same bonuses and the crit roll.
function Context.healFrom(healer: Player, target: Player, amount: number): (number, number)
	local services = need()
	local Entity = services.Entity
	local factor, crit = Context.healFactor(healer, target, false)
	-- S61: heals on a player in PvP combat are weaker (Combat.pvp.heal).
	local attempted = amount * factor * services.Pvp.HealScale(target)
	local healed = services.Resource.Heal(target, attempted, healer)
	if healed > 0 then
		local entity = Entity.GetPlayerEntity(target)
		if entity then
			-- S29: `s` (the healer) lets "mine and received" damage numbers show our heals on allies.
			local caster = Entity.GetPlayerEntity(healer)
			services.Combat.QueueFx(
				Entity.Position(entity),
				{ k = "heal", e = entity.id, s = caster and caster.id, a = math.floor(healed), c = crit or nil }
			)
		end
	end
	return healed, attempted
end

local function inCone(origin: CFrame, position: Vector3, radius: number, angle: number): boolean
	local offset = flat(position - origin.Position)
	if offset.Magnitude > radius then
		return false
	end
	if offset.Magnitude < 1.5 then
		return true
	end
	local forward = flat(origin.LookVector).Unit
	local cos = math.clamp(offset.Unit:Dot(forward), -1, 1)
	return math.deg(math.acos(cos)) <= angle / 2
end

local function inLine(origin: CFrame, position: Vector3, length: number, width: number): boolean
	local localPos = origin:PointToObjectSpace(position)
	return localPos.Z <= 1
		and localPos.Z >= -length
		and math.abs(localPos.X) <= width / 2 + 1.5
		and math.abs(localPos.Y) < 12
end

function Context.new(
	player: Player,
	skill: SkillData.SkillDef,
	rank: number,
	character: Types.CharacterData,
	caster: any,
	root: BasePart,
	services: Services,
	bp: SkillData.Breakpoint?
): Ctx
	local ctx: Ctx
	local Entity = services.Entity
	bound = bound or services
	local behaviour: any = bp or {}
	local furyUsed = 0 -- S73: stacks spent by ctx.consumeFury in this cast
	local critCdrUsed = false -- S76: critCdr once per cast
	-- S79: hooks read once per cast; cdrPerTarget counts distinct enemies hit
	local hookCache: { [string]: number } = {}
	local function hook(id: string): number
		local cached = hookCache[id]
		if cached == nil then
			cached = services.PassiveHook(player, id)
			hookCache[id] = cached
		end
		return cached :: number
	end
	local spellHookTable: { [string]: number }? = nil
	local function spellHooks(): { [string]: number }
		local t = spellHookTable
		if not t then
			t = {
				areaDamage = hook("areaDamage"),
				singleDamage = hook("singleDamage"),
				spellDamage = hook("spellDamage"),
			}
			spellHookTable = t
		end
		return t :: { [string]: number }
	end
	local tag = Skills.tag(skill)
	local struck: { [any]: boolean } = {}
	local struckCount = 0

	local function value(field: string): number
		return Skills.valueAt(skill, field, rank)
	end

	local function isEnemy(entity: any): boolean
		if not entity or entity == caster then
			return false
		end
		if entity.kind == "monster" then
			return entity.monster ~= nil and entity.monster:IsAlive()
		end
		local other = entity.player
		return other ~= nil and other ~= player and (services.Pvp.CanAttack(player, other))
	end

	local function stats(): { [string]: number }
		local result = services.Stat.Get(player)
		return if result then result.values else {}
	end

	-- S54 (ROZWOJ 8): skill damage follows the weapon's speed-normalised damage
	local speedMul = Skills.speedFactor(services.WeaponSpeed(player))

	-- Adaptive skills take the weapon's element (S18).
	local element: string? = if skill.adaptive then services.WeaponElement(player) else skill.element

	local function elementalMultiplier(holy: boolean?): number
		local mult = 1
		if element then
			mult += services.PassiveHook(player, "elementDamage") / 100
		end
		if skill.holy or holy then
			mult += services.PassiveHook(player, "holyDamage") / 100
		end
		return mult
	end

	local onHit: (entity: any, percent: number, result: Damage.Result, opts: { [string]: any }) -> ()
	local hpFraction = Context.hpFraction

	local function enemiesWhere(center: Vector3, reach: number, test: (position: Vector3) -> boolean): { any }
		local found = {}
		for _, entity in Entity.QueryMonsters(center, reach + 4) do
			local p = Entity.Position(entity)
			if p and isEnemy(entity) and test(p) then
				table.insert(found, entity)
			end
		end
		for _, entity in Entity.QueryPlayers(center, reach + 4) do
			local p = Entity.Position(entity)
			if p and isEnemy(entity) and test(p) then
				table.insert(found, entity)
			end
		end
		return found
	end

	-- Divine Wrath (holyStrikeHeal): Holy Strike's main hit heals the caster for the hook's share of the damage; with
	-- Holy Wrath (S71) every direct hit of HOLY_HEAL_SKILLS heals that share x holyHealAll / 100. Ticks never do.
	local function holyHeal(dealt: number, opts: { [string]: any })
		local share = 0
		if skill.id == "holyStrike" then
			if opts.primary then
				share = services.PassiveHook(player, "holyStrikeHeal")
			end
		elseif HOLY_HEAL_SKILLS[skill.id] then
			local strength = services.PassiveHook(player, "holyHealAll")
			if strength > 0 then
				share = services.PassiveHook(player, "holyStrikeHeal") * strength / 100
			end
		end
		if share > 0 and dealt > 0 then
			ctx.heal(player, dealt * share / 100)
		end
	end

	-- On-hit breakpoint behaviours (S28). `opts.primary`: the cast's main target (stun near it, splash around it).
	onHit = function(entity: any, percent: number, result: Damage.Result, opts: { [string]: any })
		holyHeal(result.amount, opts)
		if behaviour.lifesteal then
			ctx.heal(player, result.amount * behaviour.lifesteal / 100)
		end
		-- S69 (Holy Strike 10B): the most wounded ally nearby (the caster too) heals a share of the main hit.
		if behaviour.healWounded and opts.primary then
			local ally = ctx.wounded(root.Position, SkillData.WOUNDED_RADIUS)
			if ally then
				ctx.heal(ally, result.amount * behaviour.healWounded / 100)
			end
		end
		local push = behaviour.knockback or skill.knockback -- S140: Flame Wave's own knockback
		if push then
			Push.knockback(entity, opts.from or root.Position, push)
		end
		local at = Entity.Position(entity)
		if not opts.primary or not at then
			return
		end
		local near = behaviour.stunNear
		if near then
			for _, other in ctx.enemiesInCircle(at, near.radius) do
				services.StatusEffect.Apply(
					other,
					"stun",
					{ duration = near.duration, source = player, skillId = skill.id }
				)
			end
			ctx.fx({ v = "stunBurst", p = at, r = near.radius })
		end
		local splash = behaviour.splash
		if splash then
			for _, other in ctx.enemiesInCircle(at, splash.radius) do
				if other ~= entity then
					ctx.damage(
						other,
						percent * splash.pct / 100,
						{ plain = true, consumeShot = false, secondary = true }
					)
				end
			end
			ctx.fx({ v = "splash", p = at, r = splash.radius })
		end
	end

	-- One lasting area (S28; S79 Logic/Skills.Zone): a tick every second for floor(duration) s on the enemies inside.
	-- A weapon element's zone (zone.element) takes the weapon's element (burn / frost / spark), x Elements.power
	-- (elementRider: Elemental Might and Elements in the Veins), slows longer on ice and never applies the weapon
	-- element again (noAdaptive).
	local function startZone(center: Vector3, zone: Skills.Zone)
		local radius = zone.radius
		local pulse = zone.pct
		local el: string? = nil
		local kind = zone.kind
		local power = 1
		if zone.element then
			el = element or services.WeaponElement(player)
			kind = Skills.zoneKind(el)
			power = Elements.power(services, player)
			pulse *= power
			ctx.fx({ v = "lingering", p = center, r = radius, d = zone.duration, k = kind, el = el })
		else
			ctx.fx({ v = "lingering", p = center, r = radius, d = zone.duration, k = kind })
			-- S76 (ROZWOJ 11.4, 11.7): a poison field is the Hunter's poison (dotPower + poisonDamage)
			if kind == "poison" then
				pulse *= 1 + services.Combat.DotBonus(player, "poison") / 100
			end
		end
		local frost = zone.element == true and el == "ice"
		for second = 1, math.floor(zone.duration) do
			task.delay(second, function()
				for _, entity in ctx.enemiesInCircle(center, radius) do
					-- S76: lingering marks a pulse (no areaSkillDamage; S79: no spell bonuses, no resonance)
					ctx.damage(entity, pulse, {
						plain = true,
						canDodge = false,
						consumeShot = false,
						lingering = true,
						noAdaptive = if zone.element then true else nil,
					})
					if zone.slow then
						services.StatusEffect.Apply(entity, "slow", {
							duration = 1.2,
							value = zone.slow,
							source = player,
							skillId = skill.id,
							category = "enemySlow",
						})
					end
					if frost and isEnemy(entity) then
						-- S79: the weapon's ice slow, longer (not stronger) with elementRider, and Frostbite (S65).
						-- Own key (skill.id .. ":zone"): it must not overwrite a stronger breakpoint zone slow of the
						-- same skill; the enemySlow category keeps the strongest (ROZWOJ 14.4).
						local duration = 1.2 * power
						local slowed = services.StatusEffect.Apply(entity, "slow", {
							duration = duration,
							value = SkillData.ADAPTIVE.slowPct,
							source = player,
							skillId = skill.id .. ":zone",
							category = "enemySlow",
						})
						if slowed then
							Elements.chill(services, player, entity, duration, services.WeaponElement(player))
						end
					end
				end
			end)
		end
	end

	-- S141 (Logic/Chill): Winter's Grip. A main ice hit on a slowed, not frozen enemy adds a stack to the caster's
	-- counter on it; at CHILL.threshold the counter is spent on a freeze of chillFreeze s (bosses: Deep Chill).
	local function chillHit(entity: any)
		local seconds = hook("chillFreeze")
		if seconds <= 0 or not isEnemy(entity) then
			return
		end
		local status = services.StatusEffect
		if not Chill.counts(true, status.Has(entity, "slow"), status.Has(entity, "freeze")) then
			return
		end
		local count, freezes = Chill.chillToFreeze(status.StacksFrom(entity, "chill", player, Chill.KEY))
		if freezes then
			status.TakeStacks(entity, "chill", player, Chill.KEY)
			ctx.freeze(entity, seconds)
		else
			status.Apply(entity, "chill", {
				duration = SkillData.CHILL.counter,
				source = player,
				skillId = Chill.KEY,
				maxStacks = Chill.THRESHOLD,
				stacks = count,
			})
		end
	end

	-- S142 Conductor: the nearest other enemy within SHOCK.conductRadius of `entity` (Logic/Shock.conductTarget, flat
	-- distance) takes `percent` as a secondary hit; never `entity` again.
	local function conductFrom(entity: any, percent: number)
		local at = Entity.Position(entity)
		if not at or percent <= 0 then
			return
		end
		local radius = Shock.CONDUCT_RADIUS
		local others: { any } = { entity }
		local points: { Chain.Point } = { { x = at.X, z = at.Z } }
		for _, other in ctx.enemiesInCircle(at, radius) do
			local p = Entity.Position(other)
			if other ~= entity and p then
				table.insert(others, other)
				table.insert(points, { x = p.X, z = p.Z })
			end
		end
		local index = Shock.conductTarget(points, radius + 1.5) -- 1.5: the margin of enemiesInCircle
		local other = if index then others[index] else nil
		if other then
			ctx.fx({ v = "arc", path = { entity.id, other.id } })
			ctx.damage(other, percent, { consumeShot = false, secondary = true, noAdaptive = true })
		end
	end

	ctx = {
		player = player,
		skill = skill,
		rank = rank,
		character = character,
		caster = caster,
		root = root,
		target = nil,
		point = nil,
		cooldown = 0,
		hook = hook,
		tag = tag,
		manaFraction = 0,
		castMul = 1,
		chargesSpent = nil,
		costMods = nil,
		services = services,
		bp = behaviour,
		value = value,
		resolve = function(ref: SkillData.ValueRef?): number
			return Skills.resolve(skill, ref, rank)
		end,
		scaled = function(v)
			return Skills.scaled(skill, v, rank)
		end,
		attack = function(): number
			local values = stats()
			local base = if skill.damageKind == "magic" then values.magAtk or 0 else values.physAtk or 0
			return base * speedMul
		end,
		magAtk = function(): number
			return stats().magAtk or 0
		end,
		healMul = function(): number
			return Skills.healMul(character.level)
		end,
		-- S69 (ROZWOJ 7.5): one formula, Logic/Skills.healAmount; bonuses, item power and PvP come later
		-- (ctx.heal, Support, StatusEffectService).
		healAmount = function(target: Player, prefix: "heal" | "shield"): number
			return Skills.healAmount(
				skill,
				rank,
				prefix,
				services.Stat.GetValue(target, "maxHp"),
				stats().magAtk or 0,
				character.level
			)
		end,
		speedMul = speedMul,
		element = element,
		fx = function(data)
			data.s = skill.id
			data.v = data.v or skill.vfx
			data.c = caster.id
			data.el = data.el or element
			local spent = ctx.chargesSpent
			if spent and spent > 0 then
				data.ch = spent -- S80: the clients grow Arcane Discharge's bolt
			end
			services.Fx(player, data)
		end,
		isEnemy = isEnemy,
		damage = function(entity: any, percent: number, options: { [string]: any }?): Damage.Result?
			if not isEnemy(entity) then
				return nil
			end
			local opts: { [string]: any } = options or {}
			local params: Damage.Params = {
				kind = if skill.damageKind == "magic" then "magic" else "phys",
				multiplier = percent / 100,
				element = element :: any,
				canDodge = opts.canDodge ~= false,
				-- S62 skillDmg: every hit of a skill, splashes, ground pulses and arcs included
				isSkill = true,
			}
			-- S28 execute: a guaranteed crit on a wounded target.
			if behaviour.execute and not opts.plain then
				local fraction = hpFraction(entity)
				if fraction and fraction * 100 < behaviour.execute then
					params.forceCrit = true
				end
			end
			-- S76 (ROZWOJ 11.3) finisher: x mul on a target below hp % of its life (players: Combat.pvp.finisher at
			-- most); a pierce hit is its own target
			local finisher: any = skill.finisher
			if finisher and finisher.hp and finisher.mul and not opts.plain then
				local fraction = hpFraction(entity)
				if fraction and fraction * 100 < finisher.hp then
					local mul = if entity.kind == "player"
						then math.min(finisher.mul, Combat.pvp.finisher)
						else finisher.mul
					params.multiplier *= mul
				end
			end
			-- S76 (ROZWOJ 11.4, 16.4) Hunting Ground: hits of area skills (traps too), never pulses or splashes
			local multiplier = elementalMultiplier(opts.holy) * speedMul
			if Traits.isAreaSkill(skill.type) and not (opts.plain or opts.lingering) then
				multiplier *= 1 + services.Combat.Hook(player, "areaSkillDamage") / 100
			end
			-- S79 (ROZWOJ 12.3, 14.4): tag bonuses + spellDamage as one factor, resonance apart; zone ticks have their
			-- own percent and get neither. S80: nor Arcane Charges and empowered (castMul)
			if not opts.lingering then
				local bonus = Skills.spellBonus(tag, opts.areaHits or 1, opts.secondary == true, spellHooks())
				multiplier *= (1 + bonus / 100) * Skills.resonanceMul(ctx.manaFraction, hook("resonance")) * ctx.castMul
			end
			-- S140 (Logic/Burn): Kindling on every fire hit but zone ticks, Immolate's vsBurning on its main hits
			if element == "fire" and not opts.lingering then
				local perStack = hook("burnBonus")
				local vs = if skill.values.vsBurning ~= nil and not opts.plain then value("vsBurning") else 0
				if perStack > 0 or vs > 0 then
					local stacks = services.StatusEffect.StacksFrom(entity, "burn", player, Burn.KEY)
					multiplier *= Burn.stackBonus(stacks, perStack) * Burn.vsBurning(stacks, vs)
				end
			end
			-- S141 (Logic/Chill): Glacial Spike and Shatter on their main hits; Shatter spends what it used after the hit
			local spend: string? = nil
			local main = not (opts.plain or opts.secondary or opts.lingering)
			if element == "ice" and main and (skill.values.vsFrozen ~= nil or skill.values.shatter ~= nil) then
				local frozen = services.StatusEffect.Has(entity, "freeze")
				local deep = services.StatusEffect.SourceValue(entity, "deepChill", player) > 0
				local mul = 1
				if skill.values.vsFrozen ~= nil then
					mul *= Chill.vsFrozen(frozen, deep, value("vsFrozen"), value("vsDeepChill"))
				end
				if skill.values.shatter ~= nil then
					local shatterMul, used = Chill.shatterMul(frozen, deep, value("shatter"), value("shatterDeep"))
					mul *= shatterMul
					spend = used
				end
				if entity.kind == "player" then
					mul = Chill.pvpMul(mul, Combat.pvp.finisher)
				end
				multiplier *= mul
			end
			-- S142 (Logic/Shock): the skill's crit and Overcharge's (only lightning spells), Lightning Lance's sure crit (it
			-- spends nobody's guaranteedCrit)
			local consume = opts.consumeShot ~= false
			if not opts.lingering then
				local critAdd, critDmgAdd = Shock.critOf(
					element,
					if skill.values.crit ~= nil then value("crit") else 0,
					hook("overchargeCrit"),
					hook("overchargeDmg")
				)
				if critAdd > 0 then
					params.critAdd = critAdd
				end
				if critDmgAdd > 0 then
					params.critDmgAdd = critDmgAdd
				end
			end
			if Shock.sureCrit(skill.sureCrit, main) then
				params.forceCrit = true
				consume = false
			end
			local result = services.Combat.DealDamage(player, entity, params, nil, {
				multiplier = multiplier,
				consumeShot = consume,
				skill = if opts.plain then nil else skill.id,
				-- S63 (STATY 5): area skills roll on-hit effects with a share per target; secondary hits (splash,
				-- ground pulses, the lightning arc, the second pierce target, Storm Arrow's splash, split impacts) roll none.
				area = Traits.isAreaSkill(skill.type),
				noProc = opts.plain == true or opts.noAdaptive == true or opts.noProc == true or opts.secondary == true,
				-- S64 (STATY 6): splashes and pulses keep the skill's kind of blow (protection in PvP).
				delivery = skill.delivery,
			})
			-- S79 Cascade: an area spell's kill gives % max mana (zone ticks too; burn ticks never come here)
			if result and entity.kind == "monster" and entity.monster then
				local killPct = hook("areaKillMana")
				if killPct > 0 then
					local mana = Skills.areaKillMana(
						tag,
						not entity.monster:IsAlive(),
						result.amount,
						killPct,
						services.Stat.GetValue(player, "maxMana")
					)
					if mana > 0 then
						services.Resource.Add(player, "mana", mana)
					end
				end
			end
			-- S79 cdrPerTarget (Storm's Wrath): each distinct enemy hit (players too, no dodges, no zone ticks) takes
			-- sec seconds off this skill's cooldown, at most max enemies; the cooldown was set before the handler
			local cdr = behaviour.cdrPerTarget
			if
				cdr
				and result
				and not result.dodged
				and not opts.lingering
				and not struck[entity]
				and struckCount < cdr.max
			then
				struck[entity] = true
				struckCount += 1
				services.ReduceCooldown(player, skill.id, cdr.sec)
			end
			-- Weapon element of adaptive skills (DESIGN §14.4, S65 Skills/Elements). S63: the hit before the PvP
			-- multiplier (Result.dotBase); StatusEffectService.Apply adds x0.6 once on players. S79: a burn adds the
			-- unpaid rest (accumulate) and pays the full burnPct (ADAPTIVE.exactTicks); the arc is a secondary hit.
			if skill.adaptive and result and result.amount > 0 and not opts.noAdaptive then
				Elements.apply(services, {
					player = player,
					element = element,
					target = entity,
					hit = result.dotBase or result.amount,
					spec = ADAPTIVE_SPEC,
					skillId = skill.id,
					accumulate = true,
					jump = function(other: any, pct: number)
						ctx.damage(
							other,
							percent * pct / 100,
							{ noAdaptive = true, consumeShot = false, secondary = true }
						)
					end,
					fx = function(from: any, to: any)
						ctx.fx({ v = "arc", path = { from.id, to.id } })
					end,
				})
			end
			-- S140: the fire school's burn stacks on main hits (not splashes, pierces, arcs or zone ticks); the hit before
			-- the PvP multiplier like the weapon element
			local stacks = skill.burnStacks or 0
			if
				stacks > 0
				and result
				and not result.dodged
				and result.amount > 0
				and not (opts.plain or opts.secondary or opts.lingering)
			then
				local tick =
					Burn.tick(result.dotBase or result.amount, stacks, services.Combat.DotBonus(player, "burn"))
				services.Combat.ApplyBurn(player, entity, tick, stacks)
			end
			-- S141: Shatter ends the freeze (anyone's) or spends the caster's Deep Chill; Winter's Grip's counter on main ice
			-- hits (Logic/Chill)
			if spend and result and not result.dodged then
				if spend == "freeze" then
					services.StatusEffect.Remove(entity, "freeze")
				else
					services.StatusEffect.TakeStacks(entity, "deepChill", player, Chill.DEEP_KEY)
				end
				ctx.fx({ v = "shatter", p = Entity.Position(entity), t = entity.id })
			end
			if element == "ice" and main and result and not result.dodged and result.amount > 0 then
				chillHit(entity)
			end
			-- S142 Conductor (Logic/Shock): a single-target lightning spell's main hit jumps once (a secondary hit)
			local conduct = hook("conduct")
			if Shock.conducts(element, tag, main, conduct) and result and not result.dodged and result.amount > 0 then
				conductFrom(entity, percent * conduct / 100)
			end
			if result and not result.dodged and result.amount > 0 and not opts.plain then
				onHit(entity, percent, result, opts)
			end
			-- S76 (Archer's Rhythm): the first crit of the cast shortens this skill's cooldown by critCdr % of it
			local critCdr = behaviour.critCdr
			if critCdr and result and result.crit and not opts.plain and not critCdrUsed and ctx.cooldown > 0 then
				critCdrUsed = true
				services.ReduceCooldown(player, skill.id, ctx.cooldown * critCdr / 100)
			end
			return result
		end,
		heal = function(target: Player, amount: number): (number, number)
			return Context.healFrom(player, target, amount)
		end,
		shield = function(entity: any, amount: number, duration: number, opts: { [string]: any }?)
			if amount <= 0 or duration <= 0 then
				return
			end
			-- healPower and the healCrit roll on a player bearer; PvP x0.7 comes in StatusEffectService.Apply (S61)
			local mul = if entity.kind == "player" and entity.player
				then Context.healFactor(player, entity.player, true)
				else 1
			local options: { [string]: any } = {
				duration = duration,
				value = amount * mul,
				source = player,
				skillId = skill.id,
			}
			if opts then
				for key, v in opts do
					options[key] = v
				end
			end
			services.StatusEffect.Apply(entity, "shield", options)
		end,
		consumeFury = function(): number
			local stacks = services.StatusEffect.ConsumeFury(player)
			furyUsed = stacks
			if stacks >= 1 then
				ctx.fx({ v = "furyConsume", t = caster.id, n = stacks })
			end
			return stacks
		end,
		applyEffects = function(entity: any, side: "enemy" | "self" | "allies")
			local skillEffects: { SkillData.SkillEffect } = skill.effects or {}
			for _, effect in skillEffects do
				-- S53: a "self" effect stays on the caster (own); the party copy is a separate "allies" effect.
				-- S70: dice faces are applied by ctx.rollDice only
				if Skills.effectSide(skill, effect) == side and not effect.face then
					ctx.applyEffect(entity, effect)
				end
			end
		end,
		applyEffect = function(entity: any, effect: SkillData.SkillEffect, opts: EffectOptions?)
			local scale = if opts and opts.scale then opts.scale else 1
			local durationMul = if opts and opts.durationMul then opts.durationMul else 1
			local duration = Skills.scaled(skill, effect.duration, rank) * durationMul
			local rawValue = if type(effect.value) == "string"
				then value(effect.value)
				elseif type(effect.value) == "number" then effect.value
				else 0
			local effectValue = rawValue * scale
			-- S141 (Logic/Chill): an ice freeze on a boss or an Elite II is the caster's Deep Chill
			local kind: string = effect.kind
			local skillKey = skill.id
			if
				kind == "freeze"
				and element == "ice"
				and Chill.onFreeze(services.StatusEffect.IsBossLike(entity)) == "deepChill"
			then
				kind = "deepChill"
				effectValue = Chill.deepPct(hook("deepChill"))
				duration = SkillData.CHILL.deepDuration
				skillKey = Chill.DEEP_KEY
			end
			local tickAmount: number? = nil
			if effect.kind == "bleed" or effect.kind == "poison" or effect.kind == "burn" then
				-- value % of attack spread over the duration, one tick per second; S63: + dotPower (STATY 4); S70: burn
				-- too (Brand of Light); PvP x0.6 comes once in StatusEffectService.Apply
				tickAmount = math.max(1, ctx.attack() * effectValue / 100 / math.max(1, duration))
					* (1 + services.Combat.DotBonus(player, effect.kind) / 100)
			elseif effect.kind == "hot" and effect.hpPct ~= nil and entity.kind == "player" and entity.player then
				-- S73 (ROZWOJ 7.5, 14.2): hpPct % of the target's max HP per second with the caster's heal bonuses,
				-- healPower and one crit roll at the application (Context.healFactor); PvP x0.7 on the tick (S61)
				local factor = Context.healFactor(player, entity.player, false)
				tickAmount = services.Stat.GetValue(entity.player, "maxHp")
					* ctx.resolve(effect.hpPct)
					/ 100
					* factor
					* scale
			elseif effect.kind == "hot" and entity.kind == "player" and entity.player then
				-- S70 (dice face Spring): value % of the target's max HP every second; no heal bonus (a Fortune buff,
				-- not a heal spell); PvP x0.7 comes on the tick (S61)
				tickAmount = services.Stat.GetValue(entity.player, "maxHp") * effectValue / 100
			end
			local statValues: { [string]: number }? = nil
			if effect.stats then
				local resolved: { [string]: number } = {}
				for stat, field in effect.stats do
					-- S73: the furyConsume field counts once per Fury stack spent by this cast (Carnage, S74)
					local base = if field == skill.furyConsume then value(field) * furyUsed else value(field)
					resolved[stat] = base * scale
				end
				statValues = resolved
			end
			-- S65 (STATY 3): with an ice weapon the player's ice control lasts longer (elementRider) and chills
			-- (Frostbite) enemies; `element` is the weapon's for adaptive skills.
			local chill = element == "ice"
				and services.WeaponElement(player) == "ice"
				and (kind == "slow" or kind == "freeze" or kind == "deepChill")
			if chill then
				duration *= Elements.power(services, player)
			end
			local options = {
				duration = duration,
				value = effectValue,
				source = player,
				tickAmount = tickAmount,
				stats = statValues,
				pct = effect.pct,
				-- S76: poison stacks like bleed (poisonStacks), on its own key (the bow's poison has "item")
				-- S141: an effect with maxStacks (a growing slow) gains a stack on every application
				maxStacks = if effect.kind == "bleed"
					then behaviour.bleedStacks
					elseif effect.kind == "poison" then behaviour.poisonStacks
					else effect.maxStacks,
				skillId = skillKey,
				category = effect.category,
				notBoss = effect.notBoss, -- S70: for every kind (Hammer of Heaven's stun)
				element = if effect.kind == "burn" and skill.holy then "holy" else nil,
				-- S76: carried to the copies when the bearer dies (CombatService)
				spread = if effect.kind == "poison" then behaviour.poisonSpread else nil,
				jump = if effect.kind == "vulnerability" then behaviour.markJump else nil,
			}
			-- S76: every poison of a player through CombatService.ApplyPoison (poisonSlow)
			local applied = if kind == "poison"
				then services.Combat.ApplyPoison(player, entity, options)
				else services.StatusEffect.Apply(entity, kind, options)
			if chill and applied and isEnemy(entity) then
				Elements.chill(services, player, entity, duration, "ice")
			end
		end,
		freeze = function(entity: any, duration: number)
			if duration > 0 then
				ctx.applyEffect(entity, { kind = "freeze", duration = duration })
			end
		end,
		-- S70 (ROZWOJ 9.4, 14.1): Fortune's dice. Faces are the skill's effects with `face`. Dice: each ally in the
		-- radius gets one rolled face (rollDouble: maybe two); Wheel (roll.all): every face, the pointed one (rolled
		-- once per cast) at 1 + boost/100, and enemies within roll.enemyRadius get the enemy effects (misfortune).
		-- Half (Prayer 5B): one face for half the duration. PvP: faces x Combat.pvp.fortuneBuff (7.6).
		rollDice = function(opts: { half: boolean? }?)
			local faces: { SkillData.SkillEffect } = {}
			local skillEffects: { SkillData.SkillEffect } = skill.effects or {}
			for _, effect in skillEffects do
				if effect.face then
					table.insert(faces, effect)
				end
			end
			local count = #faces
			if count == 0 then
				return
			end
			local half = opts ~= nil and opts.half == true
			local spec = skill.roll
			local all = not half and spec ~= nil and spec.all == true
			local boost = if skill.values.boost ~= nil then value("boost") else 0
			local double = if half then 0 else behaviour.rollDouble or 0
			local durationMul = if half then 0.5 else 1
			local pointed: { number }? = if all then { Roll.face(rng, count) } else nil
			local function faceKey(index: number): string
				return "@skills.face." .. (faces[index].face :: string)
			end
			for _, ally in ctx.alliesInCircle(root.Position, skill.radius or 30) do
				local entity = Entity.GetPlayerEntity(ally)
				if not entity then
					continue
				end
				local picked = pointed or Roll.pick(rng, count, double)
				local multipliers = Roll.multipliers(count, picked, all, boost)
				local pvp = if services.Pvp.InPvpCombat(ally) then Combat.pvp.fortuneBuff else 1
				for i, face in faces do
					local m = multipliers[i]
					if m > 0 then
						ctx.applyEffect(entity, face, { scale = m * pvp, durationMul = durationMul })
					end
				end
				for _, i in picked do
					ctx.fx({
						v = "dieFace",
						t = entity.id,
						k = faces[i].face,
						d = Skills.scaled(skill, faces[i].duration, rank) * durationMul,
					})
				end
				if all then
					services.Toast(ally, "skills.wheelToast", { face = faceKey(picked[1]) }, "info")
				elseif #picked > 1 then
					services.Toast(
						ally,
						"skills.diceToastTwo",
						{ a = faceKey(picked[1]), b = faceKey(picked[2]) },
						"info"
					)
				else
					services.Toast(ally, "skills.diceToast", { face = faceKey(picked[1]) }, "info")
				end
			end
			if all and spec then
				for _, enemy in ctx.enemiesInCircle(root.Position, spec.enemyRadius or 15) do
					ctx.applyEffects(enemy, "enemy")
				end
			end
		end,
		lingering = function(center: Vector3, percent: number, wave: number?, inCircle: number?)
			-- S79 (ROZWOJ 14.4): the breakpoint's zone and the areaLingering zone (Elemental Trail) of the first wave
			for _, zone in Skills.castZones(skill, behaviour, wave or 1, percent, hook("areaLingering"), inCircle or 0) do
				startZone(center, zone)
			end
		end,
		-- S69 (ROZWOJ 9.2, 14.1): every second for floor(duration) s each living ally inside gets share % of their
		-- own heal of this skill, counted at the tick (their max HP, the caster's magic attack).
		healZone = function(center, radius, duration, share, onTick)
			ctx.fx({ v = "lingering", p = center, r = radius, d = duration, k = "heal" })
			for second = 1, math.floor(duration) do
				task.delay(second, function()
					if player.Parent == nil then
						return
					end
					for _, ally in ctx.alliesInCircle(center, radius) do
						ctx.heal(ally, ctx.healAmount(ally, "heal") * share / 100)
						local entity = if onTick then Entity.GetPlayerEntity(ally) else nil
						if onTick and entity then
							onTick(ally, entity)
						end
					end
				end)
			end
		end,
		trap = function(at: Vector3, radius: number, duration: number, effect: SkillData.SkillEffect)
			ctx.fx({ v = "trapSet", p = at, r = radius, d = duration })
			local expires = os.clock() + duration
			task.spawn(function()
				while os.clock() < expires do
					task.wait(0.25)
					local caught = ctx.enemiesInCircle(at, radius)
					if #caught > 0 then
						for _, entity in caught do
							ctx.applyEffect(entity, effect)
						end
						ctx.fx({ v = "trapTrigger", p = at, r = radius })
						return
					end
				end
			end)
		end,
		pull = function(center: Vector3): boolean
			-- S76 (ROZWOJ 16.5): the one pull of every skill type. The breakpoint's `pull` overrides the skill's; a
			-- number is the pull radius, true the skill's (effective) radius. Pulls enemies inside to `center`;
			-- bosses never move (Push).
			local radius = Skills.pullRadius(skill, behaviour)
			if radius <= 0 then
				return false
			end
			for _, entity in ctx.enemiesInCircle(center, radius) do
				Push.pull(entity, center)
			end
			ctx.fx({ v = "pull", p = center, r = radius })
			return true
		end,
		wounded = function(center: Vector3, radius: number, except: Player?): Player?
			return Context.mostWounded(player, center, radius, except)
		end,
		enemiesInCircle = function(center: Vector3, radius: number): { any }
			return enemiesWhere(center, radius, function(p)
				return flat(p - center).Magnitude <= radius + 1.5
			end)
		end,
		enemiesInCone = function(origin: CFrame, radius: number, angle: number): { any }
			return enemiesWhere(origin.Position, radius, function(p)
				return inCone(origin, p, radius + 1.5, angle)
			end)
		end,
		enemiesInLine = function(origin: CFrame, length: number, width: number): { any }
			return enemiesWhere(origin.Position, length, function(p)
				return inLine(origin, p, length, width)
			end)
		end,
		alliesInCircle = function(center: Vector3, radius: number): { Player }
			return Context.alliesInCircle(player, center, radius)
		end,
		facing = function(): CFrame
			local from = root.Position
			local toward = ctx.point
				or (if ctx.target then Entity.Position(ctx.target) else nil)
				or (from + root.CFrame.LookVector)
			local look = Vector3.new(toward.X, from.Y, toward.Z)
			if (look - from).Magnitude < 0.1 then
				look = from + flat(root.CFrame.LookVector)
			end
			return CFrame.lookAt(from, look)
		end,
		ground = function(position: Vector3): Vector3
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			local world = Workspace:FindFirstChild("World")
			params.FilterDescendantsInstances = if world then { world } else {}
			local hit = Workspace:Raycast(position + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), params)
			return if hit then hit.Position else position
		end,
	}
	return ctx
end

return Context
