--!strict
-- Damage skill types: target, projectile, cone, circleSelf, circleTarget, line, chain.
-- Each handler gets a resolved Context and returns (ok, errorKey?). Areas use the skill's radius / angle /
-- length; multi-hit skills use `hits` and `interval`; DESIGN numbers live in Data/Skills.
-- S28 breakpoints (ctx.bp): pull at the start, pierce (projectiles), lingering areas, echo waves, the last wave /
-- jump stuns, split impacts; on-hit ones (knockback, splash, stun near, lifesteal, execute) live in Context.damage.

local Context = require(script.Parent.Parent.Context)
local Push = require(script.Parent.Parent.Push)

type Ctx = Context.Ctx
type Handler = (ctx: Ctx) -> (boolean, string?)

local Offense: { [string]: Handler } = {}

local PROJECTILE_SPEED = 90 -- studs per second (visual travel time before the hit lands)
local PIERCE_REACH = 16 -- studs behind the target a piercing projectile looks for the next enemy
local PIERCE_WIDTH = 3

local function hitAll(ctx: Ctx, list: { any }, percent: number, withEffects: boolean, from: Vector3?)
	for _, entity in list do
		local result = ctx.damage(entity, percent, { from = from })
		if withEffects and result and not result.dodged then
			ctx.applyEffects(entity, "enemy")
		end
	end
end

-- Breakpoint: enemies around `center` are pulled to it before the blow.
local function pull(ctx: Ctx, center: Vector3)
	local radius = ctx.bp.pull
	if not radius then
		return
	end
	for _, entity in ctx.enemiesInCircle(center, radius) do
		Push.pull(entity, center)
	end
	ctx.fx({ v = "pull", p = center, r = radius })
end

-- Breakpoint: the last wave stuns what it hits.
local function stunLast(ctx: Ctx, list: { any })
	local seconds = ctx.bp.stunLast
	if not seconds then
		return
	end
	for _, entity in list do
		ctx.services.StatusEffect.Apply(entity, "stun", { duration = seconds, source = ctx.player })
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
	local result = ctx.damage(target, ctx.value("dmg"), { primary = true })
	if result and not result.dodged then
		ctx.applyEffects(target, "enemy")
		holyStrikeHeal(ctx, result.amount)
	end
	return true, nil
end

-- Breakpoint: a projectile goes on to the next enemy behind the target.
local function pierce(ctx: Ctx, target: any, percent: number)
	local share = ctx.bp.pierce
	local Entity = ctx.services.Entity
	local at = Entity.Position(target)
	if not share or not at then
		return
	end
	local from = ctx.root.Position
	local flat = Vector3.new(at.X - from.X, 0, at.Z - from.Z)
	if flat.Magnitude < 0.5 then
		return
	end
	local direction = flat.Unit
	local best, bestDistance = nil, math.huge
	for _, entity in ctx.enemiesInCircle(at, PIERCE_REACH) do
		local p = Entity.Position(entity)
		if entity ~= target and p then
			local offset = Vector3.new(p.X - at.X, 0, p.Z - at.Z)
			local along = offset:Dot(direction)
			local side = (offset - direction * along).Magnitude
			if along > 0 and side <= PIERCE_WIDTH and along < bestDistance then
				best, bestDistance = entity, along
			end
		end
	end
	if best then
		ctx.fx({ v = "pierce", path = { target.id, best.id } })
		ctx.damage(best, percent * share / 100, { consumeShot = false })
	end
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
				local percent = ctx.value("dmg")
				local result = ctx.damage(target, percent, { consumeShot = shot == 1, primary = shot == 1 })
				if result and not result.dodged then
					ctx.applyEffects(target, "enemy")
				end
				if shot == 1 then
					pierce(ctx, target, percent)
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
				local result = ctx.damage(entity, ctx.value("dmg"), { consumeShot = i == 1 })
				if result and not result.dodged and i <= #enemies then
					ctx.applyEffects(entity, "enemy")
				end
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
	pull(ctx, ctx.root.Position)
	local function wave(n: number, percent: number, last: boolean)
		local center = ctx.root.Position
		ctx.fx({ p = center, r = radius, n = n })
		local enemies = ctx.enemiesInCircle(center, radius)
		if hasDamage then
			hitAll(ctx, enemies, percent, n == 1)
		elseif n == 1 then
			for _, entity in enemies do
				ctx.applyEffects(entity, "enemy")
			end
		end
		if last then
			stunLast(ctx, enemies)
		end
		if n == 1 then
			-- Radiance: allies are healed for a share of the damage value.
			local healShare = ctx.skill.values.heal
			if healShare and hasDamage then
				local amount = ctx.attack() * ctx.value("dmg") / 100 * ctx.value("heal") / 100
				for _, ally in ctx.alliesInCircle(center, radius) do
					ctx.heal(ally, amount)
				end
			end
			if hasDamage then
				ctx.lingering(center, percent)
			end
		end
	end
	for n = 1, hits do
		task.delay((n - 1) * interval, wave, n, ctx.value("dmg"), n == hits)
	end
	-- Breakpoint: one more wave later (Earthquake's aftershock).
	local echo = ctx.bp.echo
	if echo and hasDamage then
		task.delay((hits - 1) * interval + echo.delay, wave, hits + 1, ctx.value("dmg") * echo.pct / 100, false)
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
		local last = wave == hits
		task.delay(delay + (wave - 1) * interval, function()
			if ctx.skill.randomTarget then
				-- Thunderstorm: one bolt per wave on a random enemy inside the circle.
				local enemies = ctx.enemiesInCircle(impactAt, impactRadius)
				if #enemies > 0 then
					local chosen = enemies[random:NextInteger(1, #enemies)]
					local target = ctx.services.Entity.Position(chosen)
					if target then
						ctx.fx({ v = "lightningBurst", p = target, r = 3 })
					end
					hitAll(ctx, { chosen }, ctx.value("dmg"), true)
				end
				return
			end
			if storm then
				ctx.fx({ v = "meteorImpact", p = impactAt, r = impactRadius })
			end
			local enemies = ctx.enemiesInCircle(impactAt, impactRadius)
			hitAll(ctx, enemies, ctx.value("dmg"), wave == 1, impactAt)
			if last then
				stunLast(ctx, enemies)
			end
			if wave == 1 then
				ctx.lingering(impactAt, ctx.value("dmg"))
				-- Breakpoint: the blast splits into small ones around the point.
				local split = ctx.bp.split
				if split then
					for i = 1, split.count do
						local angle = (i / split.count) * math.pi * 2 + random:NextNumber() * 0.6
						local spot = ctx.ground(
							impactAt + Vector3.new(math.cos(angle) * split.radius, 0, math.sin(angle) * split.radius)
						)
						task.delay(0.15 + i * 0.08, function()
							ctx.fx({ v = "splitImpact", p = spot, r = 3.5 })
							hitAll(ctx, ctx.enemiesInCircle(spot, 3.5), ctx.value("dmg") * split.pct / 100, false, spot)
						end)
					end
				end
			end
		end)
	end
	local echo = ctx.bp.echo
	if echo then
		task.delay(delay + (hits - 1) * interval + echo.delay, function()
			ctx.fx({ v = "echo", p = point, r = radius })
			hitAll(ctx, ctx.enemiesInCircle(point, radius), ctx.value("dmg") * echo.pct / 100, false, point)
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
		local result =
			ctx.damage(current, percent * (1 - 0.1 * (jump - 1)), { consumeShot = jump == 1, primary = jump == 1 })
		if result and not result.dodged then
			ctx.applyEffects(current, "enemy")
		end
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
		if not nextTarget or jump == jumps then
			-- Breakpoint: the last jump stuns.
			stunLast(ctx, { current })
			break
		end
		current = nextTarget
	end
	ctx.fx({ path = path })
	return true, nil
end

return Offense
