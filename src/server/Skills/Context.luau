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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Damage = require(Shared.Logic.Damage)
local Elements = require(script.Parent.Elements)
local Push = require(script.Parent.Push)
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
	Fx: (player: Player, data: { [string]: any }) -> (),
	PassiveHook: (player: Player, id: string) -> number,
	WeaponElement: (player: Player) -> string?,
	WeaponSpeed: (player: Player) -> number?, -- base speed of the equipped weapon (S54)
}

export type Ctx = {
	player: Player,
	skill: SkillData.SkillDef,
	rank: number,
	character: Types.CharacterData,
	caster: any, -- player entity
	root: BasePart,
	target: any?, -- entity
	point: Vector3?,
	services: Services,
	value: (field: string) -> number,
	scaled: (value: SkillData.Scaled?) -> number,
	bp: SkillData.Breakpoint, -- S28: merged breakpoint behaviours at this rank
	attack: () -> number, -- physical or magic attack depending on the skill, x speedMul (S54)
	magAtk: () -> number,
	healMul: () -> number, -- heal level curve at the caster's level (S54)
	-- S69: base heal / shield of this cast on `target` (max HP part + magic part x healMul), before bonuses
	healAmount: (target: Player, prefix: "heal" | "shield") -> number,
	healPowerMul: () -> number, -- S62: 1 + healPower / 100 (lines, Anointment) on heals and shields cast
	speedMul: number, -- skill damage x weapon speed / Combat.skillSpeedRef (S54)
	fx: (data: { [string]: any }) -> (),
	element: string?, -- the skill's element (adaptive: the weapon's), S18
	isEnemy: (entity: any) -> boolean,
	damage: (entity: any, percent: number, options: { [string]: any }?) -> Damage.Result?,
	-- (HP restored, HP it tried to restore after the heal bonus and the PvP scale, S61)
	heal: (player: Player, amount: number) -> (number, number),
	applyEffects: (entity: any, side: "enemy" | "self" | "allies") -> (),
	applyEffect: (entity: any, effect: SkillData.SkillEffect) -> (), -- one effect (breakpoint extras)
	lingering: (center: Vector3, percent: number) -> (), -- the breakpoint's lasting area (S28)
	-- S69: healing field, every second share % of each ally's own heal of this skill; onTick adds extras (S70)
	healZone: (
		center: Vector3,
		radius: number,
		duration: number,
		share: number,
		onTick: ((ally: Player, entity: any) -> ())?
	) -> (),
	trap: (at: Vector3, radius: number, duration: number, effect: SkillData.SkillEffect) -> (),
	wounded: (center: Vector3, radius: number, except: Player?) -> Player?, -- most wounded ally (S28)
	enemiesInCircle: (center: Vector3, radius: number) -> { any },
	enemiesInCone: (origin: CFrame, radius: number, angle: number) -> { any },
	enemiesInLine: (origin: CFrame, length: number, width: number) -> { any },
	alliesInCircle: (center: Vector3, radius: number) -> { Player },
	facing: () -> CFrame, -- caster position looking at the point / target / forward (flat)
	ground: (position: Vector3) -> Vector3,
}

local Context = {}

-- S65: the weapon-element recipe of adaptive skills (numbers in Data/Skills.ADAPTIVE).
local ADAPTIVE_SPEC: Traits.ElementSpec = {
	burnPct = SkillData.ADAPTIVE.burnPct,
	burnDuration = SkillData.ADAPTIVE.burnDuration,
	slowPct = SkillData.ADAPTIVE.slowPct,
	slowDuration = SkillData.ADAPTIVE.slowDuration,
	arcPct = SkillData.ADAPTIVE.arcPct,
	arcRadius = SkillData.ADAPTIVE.arcRadius,
}

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

-- Living party members of `player` within `radius` (flat) of `center`; without a party the player alone.
function Context.alliesInCircle(player: Player, center: Vector3, radius: number): { Player }
	local services = need()
	local Entity = services.Entity
	local list = {}
	for _, member in services.Party.Members(player) do
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

-- `healer` heals `target` for `amount` with the heal bonus (passives), healPower (S62) and the PvP scale (S61); the
-- heal source makes the fight summary and the heal cut (S63) work. Returns (HP restored, HP it tried to restore).
function Context.healFrom(healer: Player, target: Player, amount: number): (number, number)
	local services = need()
	local Entity = services.Entity
	local bonus = services.PassiveHook(healer, "healBonus")
	local result = services.Stat.Get(healer)
	local healPower = if result then result.values.healPower or 0 else 0
	-- S61: heals on a player in PvP combat are weaker (Combat.pvp.heal).
	local attempted = amount * (1 + bonus / 100) * (1 + healPower / 100) * services.Pvp.HealScale(target)
	local healed = services.Resource.Heal(target, attempted, healer)
	if healed > 0 then
		local entity = Entity.GetPlayerEntity(target)
		if entity then
			-- S29: `s` (the healer) lets "mine and received" damage numbers show our heals on allies.
			local caster = Entity.GetPlayerEntity(healer)
			services.Combat.QueueFx(
				Entity.Position(entity),
				{ k = "heal", e = entity.id, s = caster and caster.id, a = math.floor(healed) }
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

	local function elementalMultiplier(): number
		local mult = 1
		if element then
			mult += services.PassiveHook(player, "elementDamage") / 100
		end
		if skill.holy then
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

	-- On-hit breakpoint behaviours (S28). `opts.primary`: the cast's main target (stun near it, splash around it).
	onHit = function(entity: any, percent: number, result: Damage.Result, opts: { [string]: any })
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
		if behaviour.knockback then
			Push.knockback(entity, opts.from or root.Position, behaviour.knockback)
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
					ctx.damage(other, percent * splash.pct / 100, { plain = true, consumeShot = false })
				end
			end
			ctx.fx({ v = "splash", p = at, r = splash.radius })
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
		services = services,
		bp = behaviour,
		value = value,
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
		-- S62: healPower (lines, Anointment) raises heals and shields this player casts
		healPowerMul = function(): number
			return 1 + (stats().healPower or 0) / 100
		end,
		speedMul = speedMul,
		element = element,
		fx = function(data)
			data.s = skill.id
			data.v = data.v or skill.vfx
			data.c = caster.id
			data.el = data.el or element
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
			local result = services.Combat.DealDamage(player, entity, params, nil, {
				multiplier = elementalMultiplier() * speedMul,
				consumeShot = opts.consumeShot ~= false,
				skill = if opts.plain then nil else skill.id,
				-- S63 (STATY 5): area skills roll on-hit effects with a share per target; secondary hits (splash,
				-- ground pulses, the lightning arc, the second pierce target) roll none.
				area = Traits.isAreaSkill(skill.type),
				noProc = opts.plain == true or opts.noAdaptive == true or opts.noProc == true,
				-- S64 (STATY 6): splashes and pulses keep the skill's kind of blow (protection in PvP).
				delivery = skill.delivery,
			})
			-- Weapon element of adaptive skills (DESIGN §14.4, S65 Skills/Elements). S63: the hit before the PvP
			-- multiplier (Result.dotBase); StatusEffectService.Apply adds x0.6 once on players.
			if skill.adaptive and result and result.amount > 0 and not opts.noAdaptive then
				Elements.apply(services, {
					player = player,
					element = element,
					target = entity,
					hit = result.dotBase or result.amount,
					spec = ADAPTIVE_SPEC,
					skillId = skill.id,
					jump = function(other: any, pct: number)
						ctx.damage(other, percent * pct / 100, { noAdaptive = true, consumeShot = false })
					end,
					fx = function(from: any, to: any)
						ctx.fx({ v = "arc", path = { from.id, to.id } })
					end,
				})
			end
			if result and not result.dodged and result.amount > 0 and not opts.plain then
				onHit(entity, percent, result, opts)
			end
			return result
		end,
		heal = function(target: Player, amount: number): (number, number)
			return Context.healFrom(player, target, amount)
		end,
		applyEffects = function(entity: any, side: "enemy" | "self" | "allies")
			local skillEffects: { SkillData.SkillEffect } = skill.effects or {}
			for _, effect in skillEffects do
				-- S53: a "self" effect stays on the caster (own); the party copy is a separate "allies" effect.
				if Skills.effectSide(skill, effect) == side then
					ctx.applyEffect(entity, effect)
				end
			end
		end,
		applyEffect = function(entity: any, effect: SkillData.SkillEffect)
			local duration = Skills.scaled(skill, effect.duration, rank)
			local effectValue = if type(effect.value) == "string"
				then value(effect.value)
				elseif type(effect.value) == "number" then effect.value
				else 0
			local tickAmount: number? = nil
			if effect.kind == "bleed" or effect.kind == "poison" then
				-- value % of attack spread over the duration, one tick per second; S63: + dotPower (STATY 4)
				tickAmount = math.max(1, ctx.attack() * effectValue / 100 / math.max(1, duration))
					* (1 + services.Combat.DotBonus(player, effect.kind) / 100)
			end
			local statValues: { [string]: number }? = nil
			if effect.stats then
				local resolved: { [string]: number } = {}
				for stat, field in effect.stats do
					resolved[stat] = value(field)
				end
				statValues = resolved
			end
			-- S65 (STATY 3): with an ice weapon the player's ice control lasts longer (elementRider) and chills
			-- (Frostbite) enemies; `element` is the weapon's for adaptive skills.
			local chill = element == "ice"
				and services.WeaponElement(player) == "ice"
				and (effect.kind == "slow" or effect.kind == "freeze")
			if chill then
				duration *= Elements.power(services, player)
			end
			local applied = services.StatusEffect.Apply(entity, effect.kind, {
				duration = duration,
				value = effectValue,
				source = player,
				tickAmount = tickAmount,
				stats = statValues,
				pct = effect.pct,
				maxStacks = if effect.kind == "bleed" then behaviour.bleedStacks else nil,
				skillId = skill.id,
				category = effect.category,
			})
			if chill and applied and isEnemy(entity) then
				Elements.chill(services, player, entity, duration, "ice")
			end
		end,
		lingering = function(center: Vector3, percent: number)
			local spec = behaviour.lingering
			if not spec then
				return
			end
			local radius = spec.radius or skill.radius or 8
			ctx.fx({ v = "lingering", p = center, r = radius, d = spec.duration, k = spec.kind })
			for second = 1, math.floor(spec.duration) do
				task.delay(second, function()
					for _, entity in ctx.enemiesInCircle(center, radius) do
						ctx.damage(
							entity,
							percent * spec.pct / 100,
							{ plain = true, canDodge = false, consumeShot = false }
						)
						if spec.slow then
							services.StatusEffect.Apply(entity, "slow", {
								duration = 1.2,
								value = spec.slow,
								source = player,
								skillId = skill.id,
								category = "enemySlow",
							})
						end
					end
				end)
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
