--!strict
-- Damage skill types: target, projectile, cone, circleSelf, circleTarget, line, chain.
-- Each handler gets a resolved Context and returns (ok, errorKey?). Areas use the skill's radius / angle /
-- length; multi-hit skills use `hits` and `interval`; DESIGN numbers live in Data/Skills.

local Context = require(script.Parent.Parent.Context)

type Ctx = Context.Ctx
type Handler = (ctx: Ctx) -> (boolean, string?)

local Offense: { [string]: Handler } = {}

local PROJECTILE_SPEED = 90 -- studs per second (visual travel time before the hit lands)

local function hitAll(ctx: Ctx, list: { any }, percent: number, withEffects: boolean)
	for _, entity in list do
		local result = ctx.damage(entity, percent)
		if withEffects and result and not result.dodged then
			ctx.applyEffects(entity, "enemy")
		end
	end
end

-- Cleric passive: Holy Strike heals for a share of the damage.
local function holyStrikeHeal(ctx: Ctx, dealt: number)
	if ctx.skill.id ~= "holyStrike" or dealt <= 0 then
		return
	end
	local share = ctx.services.PassiveHook(ctx.player, "holyStrikeHeal")
	if share > 0 then
		ctx.heal(ctx.player, dealt * share / 100)
	end
end

Offense.target = function(ctx)
	local target = ctx.target
	if not target then
		return false, "cast.error.noTarget"
	end
	ctx.fx({ t = target.id })
	local result = ctx.damage(target, ctx.value("dmg"))
	if result and not result.dodged then
		ctx.applyEffects(target, "enemy")
		holyStrikeHeal(ctx, result.amount)
	end
	return true, nil
end

Offense.projectile = function(ctx)
	local target = ctx.target
	if not target then
		return false, "cast.error.noTarget"
	end
	local Entity = ctx.services.Entity
	local hits = ctx.skill.hits or 1
	local interval = ctx.skill.interval or 0.15
	for shot = 1, hits do
		task.delay((shot - 1) * interval, function()
			local position = Entity.Position(target)
			if not position then
				return
			end
			ctx.fx({ t = target.id, n = shot })
			local travel = math.clamp((position - ctx.root.Position).Magnitude / PROJECTILE_SPEED, 0.05, 0.6)
			task.delay(travel, function()
				if not ctx.isEnemy(target) then
					return
				end
				-- Only the first arrow consumes "next shot" buffs.
				local result = ctx.damage(target, ctx.value("dmg"), { consumeShot = shot == 1 })
				if result and not result.dodged then
					ctx.applyEffects(target, "enemy")
				end
				-- Storm Arrow: lightning splash around the target.
				local splash = ctx.skill.values.splash
				local radius = ctx.skill.radius
				local at = Entity.Position(target)
				if splash and radius and at then
					local others = {}
					for _, entity in ctx.enemiesInCircle(at, radius) do
						if entity ~= target then
							table.insert(others, entity)
						end
					end
					hitAll(ctx, others, ctx.value("splash"), false)
					ctx.fx({ v = "lightningBurst", p = at, r = radius })
				end
			end)
		end)
	end
	return true, nil
end

Offense.cone = function(ctx)
	local origin = ctx.facing()
	local radius = ctx.skill.radius or 10
	local angle = ctx.skill.angle or 90
	ctx.fx({ cf = origin, r = radius, a = angle })
	local enemies = ctx.enemiesInCone(origin, radius, angle)
	local hits = ctx.skill.hits
	if hits and #enemies > 0 then
		-- Volley: N arrows spread over the enemies in the cone.
		for i = 1, hits do
			local entity = enemies[(i - 1) % #enemies + 1]
			task.delay(i * 0.06, function()
				ctx.damage(entity, ctx.value("dmg"), { consumeShot = i == 1 })
			end)
		end
	else
		hitAll(ctx, enemies, ctx.value("dmg"), true)
	end
	return true, nil
end

Offense.circleSelf = function(ctx)
	local radius = ctx.skill.radius or 8
	local hasDamage = ctx.skill.values.dmg ~= nil
	local hits = ctx.skill.hits or 1
	local interval = ctx.skill.interval or 0.4
	for wave = 1, hits do
		task.delay((wave - 1) * interval, function()
			local center = ctx.root.Position
			ctx.fx({ p = center, r = radius, n = wave })
			local enemies = ctx.enemiesInCircle(center, radius)
			if hasDamage then
				hitAll(ctx, enemies, ctx.value("dmg"), wave == 1)
			elseif wave == 1 then
				for _, entity in enemies do
					ctx.applyEffects(entity, "enemy")
				end
			end
			if wave == 1 then
				-- Radiance: allies are healed for a share of the damage value.
				local healShare = ctx.skill.values.heal
				if healShare and hasDamage then
					local amount = ctx.attack() * ctx.value("dmg") / 100 * ctx.value("heal") / 100
					for _, ally in ctx.alliesInCircle(center, radius) do
						ctx.heal(ally, amount)
					end
				end
			end
		end)
	end
	-- Self effects (Taunt's armor buff).
	ctx.applyEffects(ctx.caster, "self")
	return true, nil
end

Offense.circleTarget = function(ctx)
	local point = ctx.point
	if not point then
		return false, "cast.error.noTarget"
	end
	local radius = ctx.skill.radius or 8
	local hits = ctx.skill.hits or 1
	local interval = ctx.skill.interval or 0.5
	local delay = ctx.skill.delay or 0
	local storm = hits > 1 and (ctx.skill.delay or 0) > 0 -- meteor storm: separate small impacts
	local impactRadius = if storm then math.max(4, radius / 3) else radius
	local random = Random.new()
	ctx.fx({ p = point, r = radius, d = delay + (hits - 1) * interval, n = hits })
	for wave = 1, hits do
		local at = point
		if storm then
			local angle = random:NextNumber() * math.pi * 2
			local distance = random:NextNumber() * (radius - impactRadius)
			at = ctx.ground(point + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
		end
		local impactAt = at
		task.delay(delay + (wave - 1) * interval, function()
			if ctx.skill.randomTarget then
				-- Thunderstorm: one bolt per wave on a random enemy inside the circle.
				local enemies = ctx.enemiesInCircle(impactAt, impactRadius)
				if #enemies > 0 then
					local chosen = enemies[random:NextInteger(1, #enemies)]
					local at = ctx.services.Entity.Position(chosen)
					if at then
						ctx.fx({ v = "lightningBurst", p = at, r = 3 })
					end
					hitAll(ctx, { chosen }, ctx.value("dmg"), false)
				end
				return
			end
			if storm then
				ctx.fx({ v = "meteorImpact", p = impactAt, r = impactRadius })
			end
			hitAll(ctx, ctx.enemiesInCircle(impactAt, impactRadius), ctx.value("dmg"), wave == 1)
		end)
	end
	return true, nil
end

Offense.line = function(ctx)
	local origin = ctx.facing()
	local length = ctx.skill.length or 20
	local width = ctx.skill.width or 4
	local duration = ctx.scaled(ctx.skill.duration)
	ctx.fx({ cf = origin, l = length, w = width, d = duration })
	if duration > 0 then
		-- Firewall: a lasting area ticking every `interval`.
		local interval = ctx.skill.interval or 0.5
		local ticks = math.floor(duration / interval)
		for i = 1, ticks do
			task.delay(i * interval, function()
				hitAll(ctx, ctx.enemiesInLine(origin, length, width), ctx.value("dmg"), false)
			end)
		end
	else
		hitAll(ctx, ctx.enemiesInLine(origin, length, width), ctx.value("dmg"), true)
	end
	return true, nil
end

Offense.chain = function(ctx)
	local first = ctx.target
	if not first then
		return false, "cast.error.noTarget"
	end
	local Entity = ctx.services.Entity
	local jumps = math.floor(ctx.value("jumps") + 0.5)
	local radius = ctx.skill.radius or 12
	local hit: { [any]: boolean } = {}
	local current = first
	local percent = ctx.value("dmg")
	local path = { ctx.caster.id }
	for jump = 1, jumps do
		hit[current] = true
		table.insert(path, current.id)
		ctx.damage(current, percent * (1 - 0.1 * (jump - 1)), { consumeShot = jump == 1 })
		local from = Entity.Position(current)
		if not from then
			break
		end
		local nextTarget: any = nil
		local best = math.huge
		for _, entity in ctx.enemiesInCircle(from, radius) do
			local p = Entity.Position(entity)
			if not hit[entity] and p and (p - from).Magnitude < best then
				nextTarget = entity
				best = (p - from).Magnitude
			end
		end
		if not nextTarget then
			break
		end
		current = nextTarget
	end
	ctx.fx({ path = path })
	return true, nil
end

return Offense
