--!strict
-- Everything a skill handler needs while resolving one cast: the caster, resolved target / point, level
-- values, and helpers for areas, damage, healing, effects and visuals. Built by SkillService per cast.
-- S28: `skill` is the skill as it works at its level (Logic/Skills.effective: breakpoint numbers applied) and `bp`
-- the breakpoint behaviours; `damage` applies the on-hit ones (lifesteal, knockback, execute, stun near the target,
-- splash) and `applyEffect` stacks bleeds; `lingering` and `trap` leave lasting areas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Damage = require(Shared.Logic.Damage)
local Push = require(script.Parent.Push)
local SkillData = require(Shared.Data.Skills)
local Skills = require(Shared.Logic.Skills)
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
}

export type Ctx = {
	player: Player,
	skill: SkillData.SkillDef,
	level: number,
	character: Types.CharacterData,
	caster: any, -- player entity
	root: BasePart,
	target: any?, -- entity
	point: Vector3?,
	services: Services,
	value: (field: string) -> number,
	scaled: (value: SkillData.Scaled?) -> number,
	bp: SkillData.Breakpoint, -- S28: merged breakpoint behaviours at this level
	attack: () -> number, -- physical or magic attack depending on the skill
	magAtk: () -> number,
	fx: (data: { [string]: any }) -> (),
	element: string?, -- the skill's element (adaptive: the weapon's), S18
	isEnemy: (entity: any) -> boolean,
	damage: (entity: any, percent: number, options: { [string]: any }?) -> Damage.Result?,
	heal: (player: Player, amount: number) -> number,
	applyEffects: (entity: any, side: "enemy" | "self" | "allies") -> (),
	applyEffect: (entity: any, effect: SkillData.SkillEffect) -> (), -- one effect (breakpoint extras)
	lingering: (center: Vector3, percent: number) -> (), -- the breakpoint's lasting area (S28)
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

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
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
	level: number,
	character: Types.CharacterData,
	caster: any,
	root: BasePart,
	services: Services,
	bp: SkillData.Breakpoint?
): Ctx
	local ctx: Ctx
	local Entity = services.Entity
	local behaviour: any = bp or {}

	local function value(field: string): number
		return Skills.valueAt(skill, field, level)
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

	-- Extra effect of adaptive skills by weapon element (DESIGN §14.4): fire burns for 30 % of the hit over
	-- 4 s, ice slows by 25 % for 2 s, lightning arcs to one enemy nearby for 40 %.
	local function adaptiveEffect(entity: any, percent: number, amount: number)
		if element == "fire" then
			services.StatusEffect.Apply(entity, "burn", {
				duration = 4,
				value = 30,
				source = player,
				tickAmount = math.max(1, amount * 0.3 / 4),
			})
		elseif element == "ice" then
			services.StatusEffect.Apply(entity, "slow", { duration = 2, value = 25, source = player })
		elseif element == "lightning" then
			local from = Entity.Position(entity)
			if not from then
				return
			end
			local best, bestDistance = nil, 10
			for _, other in Entity.QueryMonsters(from, 10) do
				local p = Entity.Position(other)
				if other ~= entity and p and isEnemy(other) and (p - from).Magnitude <= bestDistance then
					best, bestDistance = other, (p - from).Magnitude
				end
			end
			if best then
				ctx.fx({ v = "arc", path = { entity.id, best.id } })
				ctx.damage(best, percent * 0.4, { noAdaptive = true, consumeShot = false })
			end
		end
	end

	-- Share of HP left (monsters and players), nil when unknown.
	local function hpFraction(entity: any): number?
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

	-- On-hit breakpoint behaviours (S28). `opts.primary`: the cast's main target (stun near it, splash around it).
	onHit = function(entity: any, percent: number, result: Damage.Result, opts: { [string]: any })
		if behaviour.lifesteal then
			ctx.heal(player, result.amount * behaviour.lifesteal / 100)
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
				services.StatusEffect.Apply(other, "stun", { duration = near.duration, source = player })
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
		level = level,
		character = character,
		caster = caster,
		root = root,
		target = nil,
		point = nil,
		services = services,
		bp = behaviour,
		value = value,
		scaled = function(v)
			return Skills.scaled(skill, v, level)
		end,
		attack = function(): number
			local values = stats()
			return if skill.damageKind == "magic" then values.magAtk or 0 else values.physAtk or 0
		end,
		magAtk = function(): number
			return stats().magAtk or 0
		end,
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
			}
			-- S28 execute: a guaranteed crit on a wounded target.
			if behaviour.execute and not opts.plain then
				local fraction = hpFraction(entity)
				if fraction and fraction * 100 < behaviour.execute then
					params.forceCrit = true
				end
			end
			local result = services.Combat.DealDamage(player, entity, params, nil, {
				multiplier = elementalMultiplier(),
				consumeShot = opts.consumeShot ~= false,
				skill = if opts.plain then nil else skill.id,
			})
			if skill.adaptive and result and result.amount > 0 and not opts.noAdaptive then
				adaptiveEffect(entity, percent, result.amount)
			end
			if result and not result.dodged and result.amount > 0 and not opts.plain then
				onHit(entity, percent, result, opts)
			end
			return result
		end,
		heal = function(target: Player, amount: number): number
			local bonus = services.PassiveHook(player, "healBonus")
			local healed = services.Resource.Heal(target, amount * (1 + bonus / 100))
			if healed > 0 then
				local entity = Entity.GetPlayerEntity(target)
				if entity then
					services.Combat.QueueFx(
						Entity.Position(entity),
						{ k = "heal", e = entity.id, a = math.floor(healed) }
					)
				end
			end
			return healed
		end,
		applyEffects = function(entity: any, side: "enemy" | "self" | "allies")
			local skillEffects: { SkillData.SkillEffect } = skill.effects or {}
			for _, effect in skillEffects do
				local effectSide = effect.target
					or (if skill.type == "buff" or skill.type == "groupBuff" then "self" else "enemy")
				if effectSide == side or (side == "allies" and effectSide == "self" and skill.type == "groupBuff") then
					ctx.applyEffect(entity, effect)
				end
			end
		end,
		applyEffect = function(entity: any, effect: SkillData.SkillEffect)
			local duration = Skills.scaled(skill, effect.duration, level)
			local effectValue = if type(effect.value) == "string"
				then value(effect.value)
				elseif type(effect.value) == "number" then effect.value
				else 0
			local tickAmount: number? = nil
			if effect.kind == "bleed" or effect.kind == "poison" then
				-- value % of attack spread over the duration, one tick per second
				tickAmount = math.max(1, ctx.attack() * effectValue / 100 / math.max(1, duration))
			end
			local statValues: { [string]: number }? = nil
			if effect.stats then
				local resolved: { [string]: number } = {}
				for stat, field in effect.stats do
					resolved[stat] = value(field)
				end
				statValues = resolved
			end
			services.StatusEffect.Apply(entity, effect.kind, {
				duration = duration,
				value = effectValue,
				source = player,
				tickAmount = tickAmount,
				stats = statValues,
				pct = effect.pct,
				maxStacks = if effect.kind == "bleed" then behaviour.bleedStacks else nil,
			})
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
							services.StatusEffect.Apply(
								entity,
								"slow",
								{ duration = 1.2, value = spec.slow, source = player }
							)
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
			local best, bestFraction = nil, 1
			for _, ally in ctx.alliesInCircle(center, radius) do
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
			local list = {}
			for _, member in services.Party.Members(player) do
				local entity = Entity.GetPlayerEntity(member)
				local p = entity and Entity.Position(entity)
				if p and flat(p - center).Magnitude <= radius and not services.Resource.IsDead(member) then
					table.insert(list, member)
				end
			end
			return list
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
