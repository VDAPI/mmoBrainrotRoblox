--!strict
-- Movement and placement skill types: charge (dash to the target), blink (teleport; Disengage jumps back),
-- trap (S76, ROZWOJ 11.4 / 14.3): `hits` traps (default 1), in a ring of `ringRadius` around the point or side by side
-- (TRAP_SIDE_OFFSET studs, perpendicular to the hunter -> point line). Each waits `duration` and fires once on the
-- first enemy inside: pull (ctx.pull), then values.dmg and the skill's enemy effects on everyone caught (on those
-- hit when it deals damage), trapEnergy, and the breakpoint's echo (damage only).
-- The server moves the character itself (PivotTo) after raycasting for walls, so clients cannot teleport.
-- S74 (ROZWOJ 10.3, 10.5, 14.2): guard leaps to an ally (Logic/GuardTarget picks one without a selection) and puts
-- the intercept on them; banner plants a server object (Skills/Banner) whose circle pulses on PartyAuraService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Banner = require(script.Parent.Parent.Banner)
local Context = require(script.Parent.Parent.Context)
local GuardTarget = require(ReplicatedStorage.Shared.Logic.GuardTarget)
local PathsData = require(ReplicatedStorage.Shared.Data.Paths)
local Push = require(script.Parent.Parent.Push)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local SkillGeom = require(ReplicatedStorage.Shared.Logic.SkillGeom)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)

type Ctx = Context.Ctx
type Handler = (ctx: Ctx) -> (boolean, string?)

local Movement: { [string]: Handler } = {}

local TRAP_CHECK = 0.25
local RANGE_TOLERANCE = 5 -- as SkillService
local NO_EFFECTS: { SkillData.SkillEffect } = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Furthest safe point from `from` toward `to` (stops before walls).
local function clearPath(ctx: Ctx, from: Vector3, to: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, name in { "Monsters", "Vaelthorn_Effects", "Vaelthorn_Loot", "Vaelthorn_CombatFx" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	local model = ctx.player.Character
	if model then
		table.insert(exclude, model)
	end
	params.FilterDescendantsInstances = exclude
	local direction = to - from
	local hit = Workspace:Raycast(from, direction, params)
	if hit then
		local back = if direction.Magnitude > 0 then direction.Unit * 2 else Vector3.zero
		return hit.Position - back
	end
	return to
end

local function moveTo(ctx: Ctx, destination: Vector3, lookAt: Vector3?)
	local model = ctx.player.Character
	if not model then
		return
	end
	local face = lookAt or (destination + ctx.root.CFrame.LookVector)
	local flatFace = Vector3.new(face.X, destination.Y, face.Z)
	if (flatFace - destination).Magnitude < 0.1 then
		flatFace = destination + ctx.root.CFrame.LookVector
	end
	model:PivotTo(CFrame.lookAt(destination, flatFace))
end

Movement.charge = function(ctx)
	local target = ctx.target
	if not target then
		return false, "cast.error.noTarget"
	end
	local position = ctx.services.Entity.Position(target)
	if not position then
		return false, "cast.error.noTarget"
	end
	local from = ctx.root.Position
	local offset = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
	local stopAt = if offset.Magnitude > 3 then position - offset.Unit * 3 else from
	local destination = clearPath(ctx, from, Vector3.new(stopAt.X, from.Y, stopAt.Z))
	ctx.fx({ t = target.id, p = destination, from = from })
	moveTo(ctx, destination, position)
	task.delay(0.15, function()
		local result = ctx.damage(target, ctx.value("dmg"), { primary = true, from = from })
		if result and not result.dodged then
			ctx.applyEffects(target, "enemy")
		end
	end)
	return true, nil
end

Movement.blink = function(ctx)
	local from = ctx.root.Position
	local length = ctx.skill.length or 15
	local direction: Vector3
	if ctx.skill.id == "disengage" then
		-- Jump back, away from where the hunter is facing.
		direction = -ctx.root.CFrame.LookVector
	elseif ctx.point then
		direction = ctx.point - from
	else
		direction = ctx.root.CFrame.LookVector
	end
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.05 then
		direction = ctx.root.CFrame.LookVector
	end
	local destination = clearPath(ctx, from, from + direction.Unit * length)
	ctx.fx({ p = destination, from = from })
	local lookAt = if ctx.skill.id == "disengage" then from else destination + direction.Unit
	moveTo(ctx, destination, lookAt)
	-- S65: a blink breaks the Runic Seal (any longer walk breaks it through CombatService's polling).
	ctx.services.Combat.BreakSeal(ctx.player)
	ctx.applyEffects(ctx.caster, "self")
	-- S28 breakpoint: a slowing trap where the caster stood.
	local trap = ctx.bp.trap
	if trap then
		ctx.trap(ctx.ground(from), trap.radius, trap.duration, {
			kind = "slow",
			duration = 3,
			value = trap.slow,
			category = "enemySlow",
		})
	end
	return true, nil
end

-- One trap fires: damage and the enemy effects on everyone inside (only on those hit when it deals damage; the
-- trapRootDuration hook lengthens roots), trapEnergy once per trap, then the echo.
local function fire(ctx: Ctx, at: Vector3, radius: number)
	local player = ctx.player
	local Combat = ctx.services.Combat
	local caught = ctx.enemiesInCircle(at, radius)
	ctx.fx({ v = "trapTrigger", p = at, r = radius })
	local hasDamage = ctx.skill.values.dmg ~= nil
	local rootBonus = Combat.Hook(player, "trapRootDuration")
	local effects: { SkillData.SkillEffect } = ctx.skill.effects or NO_EFFECTS
	for _, entity in caught do
		local hit = true
		if hasDamage then
			local result = ctx.damage(entity, ctx.value("dmg"), { from = at })
			hit = result ~= nil and not result.dodged
		end
		if hit then
			for _, effect in effects do
				-- the side rule of ctx.applyEffects; dice faces never come from a trap
				if Skills.effectSide(ctx.skill, effect) == "enemy" and not effect.face then
					if effect.kind == "root" and rootBonus > 0 then
						local longer = table.clone(effect)
						longer.duration = ctx.scaled(effect.duration) + rootBonus
						ctx.applyEffect(entity, longer)
					else
						ctx.applyEffect(entity, effect)
					end
				end
			end
		end
	end
	-- Poacher's Spoils (ROZWOJ 11.4): energy per enemy caught, at most TRAP_ENERGY_MAX per trap
	local energy = Combat.Hook(player, "trapEnergy")
	if energy > 0 and #caught > 0 then
		ctx.services.Resource.Add(player, "energy", energy * math.min(#caught, SkillData.TRAP_ENERGY_MAX))
	end
	-- Breakpoint echo: damage only, a part of the area skill (1/3 on-hit chance, S63), no effects, no energy
	local echo = ctx.bp.echo
	if echo and hasDamage then
		task.delay(echo.delay, function()
			ctx.fx({ v = "echo", p = at, r = radius })
			for _, entity in ctx.enemiesInCircle(at, radius) do
				ctx.damage(entity, ctx.value("dmg") * echo.pct / 100, { from = at })
			end
		end)
	end
end

-- One trap waits `lifetime` for the first enemy; a pulling trap fires after the pull has landed.
local function arm(ctx: Ctx, at: Vector3, radius: number, lifetime: number, index: number?)
	ctx.fx({ p = at, r = radius, d = lifetime, n = index })
	local expires = os.clock() + lifetime
	task.spawn(function()
		while os.clock() < expires do
			task.wait(TRAP_CHECK)
			if #ctx.enemiesInCircle(at, radius) > 0 then
				if ctx.pull(at) then
					task.wait(Push.DURATION)
				end
				fire(ctx, at, radius)
				return
			end
		end
	end)
end

Movement.trap = function(ctx)
	local origin = ctx.root.Position
	local at = ctx.ground(ctx.point or origin)
	local radius = ctx.skill.radius or 6
	local lifetime = ctx.scaled(ctx.skill.duration)
	local count = math.max(1, math.floor((ctx.skill.hits or 1) + 0.5))
	if count == 1 then
		arm(ctx, at, radius, lifetime, nil)
		return true, nil
	end
	local ring = ctx.skill.ringRadius or 0
	local points: { SkillGeom.Point } = if ring > 0
		then SkillGeom.ringPoints(at.X, at.Z, ring, count, SkillGeom.angle(origin.X, origin.Z, at.X, at.Z))
		else SkillGeom.sidePoints(origin.X, origin.Z, at.X, at.Z, count, SkillData.TRAP_SIDE_OFFSET)
	for i, p in points do
		arm(ctx, ctx.ground(Vector3.new(p.x, at.Y, p.z)), radius, lifetime, i)
	end
	return true, nil
end

-- Longest effect of the skill on `side` (of `kind` when given) after Skills.effective; 0 without one.
local function longest(ctx: Ctx, side: "self" | "allies", kind: string?): number
	local out = 0
	local effects: { SkillData.SkillEffect } = ctx.skill.effects or NO_EFFECTS
	for _, effect in effects do
		if Skills.effectSide(ctx.skill, effect) == side and (kind == nil or effect.kind == kind) then
			out = math.max(out, ctx.scaled(effect.duration))
		end
	end
	return out
end

-- A guard candidate: a living ally other than the caster, its HP share and flat distance from `from`.
local function candidate(ctx: Ctx, ally: Player, from: Vector3): GuardTarget.Candidate?
	local Entity = ctx.services.Entity
	local entity = Entity.GetPlayerEntity(ally)
	local position = entity and Entity.Position(entity)
	if not entity or not position or ally == ctx.player or ctx.services.Resource.IsDead(ally) then
		return nil
	end
	return {
		key = ally,
		hpFraction = Context.hpFraction(entity) or 1,
		distance = flat(position - from).Magnitude,
	}
end

-- The intercept and party effects of a guard on one protected ally at pct % strength (10A: the second ally at the
-- breakpoint's share): ally-side effects, allyEffects (S75 nodes) and allyShield (Team Shield).
local function cover(ctx: Ctx, ally: Player, entity: any, pct: number)
	local opts = { scale = pct / 100 }
	local effects: { SkillData.SkillEffect } = ctx.skill.effects or NO_EFFECTS
	for _, effect in effects do
		if Skills.effectSide(ctx.skill, effect) == "allies" then
			ctx.applyEffect(entity, effect, opts)
		end
	end
	local allyEffects: { SkillData.SkillEffect } = ctx.skill.allyEffects or NO_EFFECTS
	for _, effect in allyEffects do
		ctx.applyEffect(entity, effect, opts)
	end
	local shield = ctx.bp.allyShield
	if shield then
		local maxHp = ctx.services.Stat.GetValue(ally, "maxHp")
		ctx.shield(entity, maxHp * ctx.resolve(shield.hpPct) / 100 * pct / 100, shield.duration)
	end
end

-- The most wounded living ally below full health within GUARD_SECOND_RADIUS of `at`, other than the caster and
-- `first` (ctx.wounded skips one player only).
local function secondAlly(ctx: Ctx, at: Vector3, first: Player): Player?
	local best, bestFraction = nil, 1
	for _, other in ctx.alliesInCircle(at, SkillData.GUARD_SECOND_RADIUS) do
		if other ~= first then
			local c = candidate(ctx, other, at)
			if c and c.hpFraction < bestFraction then
				best, bestFraction = other, c.hpFraction
			end
		end
	end
	return best
end

-- Enemies within `radius` of `at` get `kind` from the caster (stun: 5B; taunt: 10B, players ignore it).
local function nearAlly(ctx: Ctx, at: Vector3, radius: number, kind: string, duration: number)
	for _, enemy in ctx.enemiesInCircle(at, radius) do
		ctx.services.StatusEffect.Apply(
			enemy,
			kind,
			{ duration = duration, source = ctx.player, skillId = ctx.skill.id }
		)
	end
end

Movement.guard = function(ctx)
	local Entity = ctx.services.Entity
	local from = ctx.root.Position
	local range = ctx.skill.range or 25
	local reach = range + RANGE_TOLERANCE
	-- the selection counts only when it is a living ally (a monster under the cursor = no selection)
	local selected: GuardTarget.Candidate? = nil
	local target = ctx.target
	if
		target
		and target.kind == "player"
		and target.player
		and ctx.services.Party.AreAllies(ctx.player, target.player)
	then
		selected = candidate(ctx, target.player, from)
	end
	local inZone: { GuardTarget.Candidate } = {}
	-- the search reaches `range` (ROZWOJ 10.3); the +5 tolerance only for the selected ally and GuardTarget.pick
	for _, ally in ctx.alliesInCircle(from, range) do
		local entity = Entity.GetPlayerEntity(ally)
		local position = entity and Entity.Position(entity)
		local c = if position and ctx.services.Combat.InRedZone(position) ~= nil
			then candidate(ctx, ally, from)
			else nil
		if c then
			table.insert(inZone, c)
		end
	end
	local woundedAlly = ctx.wounded(from, range, ctx.player)
	local wounded = if woundedAlly then candidate(ctx, woundedAlly, from) else nil
	local ally: Player? = GuardTarget.pick(selected, inZone, wounded, reach)
	local allyEntity = if ally then Entity.GetPlayerEntity(ally) else nil
	local allyPosition = allyEntity and Entity.Position(allyEntity)
	if not ally or not allyEntity or not allyPosition then
		-- the self variant: the guard's own reduction only; S75: no selfEffects (Sacrifice's reduction is for the
		-- time of an intercept and shares the key of this one, so it would overwrite it)
		ctx.skipSelfEffects = true
		ctx.fx({ t = ctx.caster.id, d = longest(ctx, "self") })
		ctx.applyEffects(ctx.caster, "self")
		return true, nil
	end

	-- the leap: 2 studs before the ally on the line, stopped by walls; already close = stay
	local offset = flat(allyPosition - from)
	local destination = from
	if offset.Magnitude > 3 then
		local stopAt = allyPosition - offset.Unit * 2
		destination = clearPath(ctx, from, Vector3.new(stopAt.X, from.Y, stopAt.Z))
		moveTo(ctx, destination, allyPosition)
	end

	cover(ctx, ally, allyEntity, 100)
	-- 10A: the same intercept on the second most wounded ally near the landing point
	local secondIds: { string }? = nil
	local share = ctx.bp.secondTarget
	local second = if share then secondAlly(ctx, destination, ally) else nil
	local secondEntity = if second then Entity.GetPlayerEntity(second) else nil
	if share and second and secondEntity then
		cover(ctx, second, secondEntity, share)
		secondIds = { secondEntity.id }
	end
	ctx.fx({ t = allyEntity.id, p = destination, from = from, d = longest(ctx, "allies", "intercept"), al = secondIds })

	local stun = ctx.bp.stunNear
	if stun then
		nearAlly(ctx, allyPosition, stun.radius, "stun", stun.duration)
		ctx.fx({ v = "stunBurst", p = allyPosition, r = stun.radius })
	end
	local taunt = ctx.bp.tauntNear
	if taunt then
		nearAlly(ctx, allyPosition, taunt.radius, "taunt", taunt.duration)
	end
	return true, nil
end

-- S74 War Banner: a server object at the point (no aim: at the feet) and a zone on PartyAuraService's loop. Every
-- pulse gives allies in the circle (the owner too) the ally effects and enemies the enemy effects, each for one pulse
-- (AURA.duration) whatever the data says; a new banner of the same player replaces the old one.
Movement.banner = function(ctx)
	local at = ctx.ground(ctx.point or ctx.root.Position)
	local radius = ctx.skill.radius or 15
	local duration = ctx.scaled(ctx.skill.duration)
	local Entity = ctx.services.Entity
	local allyEffects: { SkillData.SkillEffect } = {}
	local enemyEffects: { SkillData.SkillEffect } = {}
	local function pulsed(effect: SkillData.SkillEffect): SkillData.SkillEffect
		local copy = table.clone(effect)
		copy.duration = PathsData.AURA.duration
		return copy
	end
	local effects: { SkillData.SkillEffect } = ctx.skill.effects or NO_EFFECTS
	for _, effect in effects do
		local side = Skills.effectSide(ctx.skill, effect)
		if side == "allies" then
			table.insert(allyEffects, pulsed(effect))
		elseif side == "enemy" then
			table.insert(enemyEffects, pulsed(effect))
		end
	end
	local extra: { SkillData.SkillEffect } = ctx.skill.allyEffects or NO_EFFECTS
	for _, effect in extra do
		table.insert(allyEffects, pulsed(effect))
	end
	local function pulse()
		for _, ally in ctx.alliesInCircle(at, radius) do
			local entity = Entity.GetPlayerEntity(ally)
			if entity then
				for _, effect in allyEffects do
					ctx.applyEffect(entity, effect)
				end
			end
		end
		if #enemyEffects > 0 then
			for _, enemy in ctx.enemiesInCircle(at, radius) do
				for _, effect in enemyEffects do
					ctx.applyEffect(enemy, effect)
				end
			end
		end
	end
	local model = Banner.spawn(ctx.player, ctx.skill.id, at, radius, duration)
	ctx.fx({ p = at, r = radius, d = duration })
	ctx.services.PartyAura.AddZone({
		key = ctx.skill.id .. ":" .. ctx.player.UserId,
		owner = ctx.player,
		center = at,
		radius = radius,
		endsAt = os.clock() + duration,
		pulse = pulse,
		onEnd = function()
			Banner.remove(model)
		end,
	})
	return true, nil
end

return Movement
