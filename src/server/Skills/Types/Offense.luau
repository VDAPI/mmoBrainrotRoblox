--!strict
-- Damage skill types: target, projectile, cone, circleSelf, circleTarget, line, chain.
-- Each handler gets a resolved Context and returns (ok, errorKey?). Areas use the skill's radius / angle /
-- length; multi-hit skills use `hits` and `interval`; DESIGN numbers live in Data/Skills.
-- S28 breakpoints (ctx.bp): pull at the start, pierce (projectiles), lingering areas, echo waves, the last wave /
-- jump stuns, split impacts; on-hit ones (knockback, splash, stun near, lifesteal, execute) live in Context.damage.
-- S71: Final Verdict (stunSplash) in `target`; Divine Wrath's heal moved to Context (onHit).
-- S73 (ROZWOJ 10.4, 14.2): `target` with furyConsume spends the caster's Fury for x Skills.furyMultiplier (the splash
-- too, it counts from the same percent); circleSelf with shieldPerHit shields the caster per taunted monster.
-- S76 (ROZWOJ 11.4, 16.5): pulls go through ctx.pull (circleSelf to the caster, circleTarget to the point before the
-- first wave, which waits Push.DURATION); firstWave makes circleTarget's first wave stronger.
-- S79 (ROZWOJ 12.3, 14.4): every hit carries areaHits (enemies hit in its wave; Thunderstorm counts its circle) and
-- secondary hits (pierce, splashes, splits) say so; zones come from ctx.lingering on every wave (Skills.castZones
-- keeps the first); a chain decides its path first (Logic/Chain.path, flat distance).
-- S80 (ROZWOJ 12.4, 12.5): `beam` (Arcane Torrent) starts a beam channel through services.Beam; circleTarget with
-- SkillVfx `waves` (Cataclysm) sends one impact event per wave instead of one at the start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chain = require(ReplicatedStorage.Shared.Logic.Chain)
local Context = require(script.Parent.Parent.Context)
local Push = require(script.Parent.Parent.Push)
local SkillVfx = require(ReplicatedStorage.Shared.Data.SkillVfx)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)

type Ctx = Context.Ctx
type Handler = (ctx: Ctx) -> (boolean, string?)

local Offense: { [string]: Handler } = {}

local PROJECTILE_SPEED = 90 -- studs per second (visual travel time before the hit lands)
-- FIX 2026-10-09: circle skills with a projectile (fireball) land when the orb arrives; same speed and cap as
-- client/Controllers/VfxController ("Projectile skills").
local CIRCLE_PROJECTILE_SPEED = 140
local CIRCLE_PROJECTILE_MAX = 0.8
local PIERCE_REACH = 16 -- studs behind the target a piercing projectile looks for the next enemy
local PIERCE_WIDTH = 3

-- S79: `extra.areaHits` defaults to #list (the enemies hit together), `extra.secondary` marks a secondary hit.
type HitExtra = { from: Vector3?, areaHits: number?, secondary: boolean? }

local function hitAll(ctx: Ctx, list: { any }, percent: number, withEffects: boolean, extra: HitExtra?)
	local from = if extra then extra.from else nil
	local areaHits = if extra and extra.areaHits then extra.areaHits else #list
	local secondary = if extra then extra.secondary else nil
	for _, entity in list do
		local result = ctx.damage(entity, percent, { from = from, areaHits = areaHits, secondary = secondary })
		if withEffects and result and not result.dodged then
			ctx.applyEffects(entity, "enemy")
		end
	end
end

-- Breakpoint: the last wave stuns what it hits.
local function stunLast(ctx: Ctx, list: { any })
	local seconds = ctx.bp.stunLast
	if not seconds then
		return
	end
	for _, entity in list do
		ctx.services.StatusEffect.Apply(
			entity,
			"stun",
			{ duration = seconds, source = ctx.player, skillId = ctx.skill.id }
		)
	end
end

-- S71 Final Verdict (stunSplash): a hit on a stunned target (also stunned by this cast) bursts around it for
-- values.stunSplash % of the skill's damage; bosses too (ROZWOJ 15.2.7).
local function stunSplash(ctx: Ctx, target: any)
	local spec = ctx.bp.stunSplash
	if not spec or not ctx.services.StatusEffect.Has(target, "stun") then
		return
	end
	local at = ctx.services.Entity.Position(target)
	if not at then
		return
	end
	local percent = ctx.value("dmg") * ctx.value("stunSplash") / 100
	for _, other in ctx.enemiesInCircle(at, spec.radius) do
		if other ~= target then
			ctx.damage(other, percent, { plain = true, consumeShot = false })
		end
	end
	ctx.fx({ v = "splash", p = at, r = spec.radius })
end

Offense.target = function(ctx)
	local target = ctx.target
	if not target then
		return false, "cast.error.noTarget"
	end
	ctx.fx({ t = target.id })
	local percent = ctx.value("dmg")
	if ctx.skill.furyConsume then
		-- spent even when the blow is dodged (the cast happened)
		percent *= Skills.furyMultiplier(ctx.value(ctx.skill.furyConsume), ctx.consumeFury())
	end
	local result = ctx.damage(target, percent, { primary = true })
	if result and not result.dodged then
		ctx.applyEffects(target, "enemy")
		stunSplash(ctx, target)
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
		ctx.damage(best, percent * share / 100, { consumeShot = false, noProc = true, secondary = true })
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
					hitAll(ctx, others, ctx.value("splash"), false, { secondary = true })
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
				local result = ctx.damage(entity, ctx.value("dmg"), { consumeShot = i == 1, areaHits = #enemies })
				if result and not result.dodged and i <= #enemies then
					ctx.applyEffects(entity, "enemy")
				end
			end)
		end
	else
		hitAll(ctx, enemies, ctx.value("dmg"), true)
	end
	-- S134g (Volley's item effect, Data/ItemEffects): the cone strikes again after echo.delay for echo.pct % (the
	-- enemies in the same cone then; a volley shoots its arrows again), like the echo of circleSelf / circleTarget
	local echo = ctx.bp.echo
	if echo then
		task.delay(echo.delay, function()
			local again = ctx.enemiesInCone(origin, radius, angle)
			if #again == 0 then
				return
			end
			ctx.fx({ cf = origin, r = radius, a = angle })
			local percent = ctx.value("dmg") * echo.pct / 100
			if hits then
				for i = 1, hits do
					ctx.damage(again[(i - 1) % #again + 1], percent, { consumeShot = false, areaHits = #again })
				end
			else
				hitAll(ctx, again, percent, false)
			end
		end)
	end
	return true, nil
end

-- S73 shieldPerHit (Defender's Oath, S75): a shield on the caster, hpPct % of its max HP per monster in the first wave
-- (taunt works on monsters only), at most `max` of them.
local function shieldPerHit(ctx: Ctx, enemies: { any })
	local spec = ctx.bp.shieldPerHit
	if not spec then
		return
	end
	local count = 0
	for _, entity in enemies do
		if entity.kind == "monster" then
			count += 1
		end
	end
	if count > 0 then
		local maxHp = ctx.services.Stat.GetValue(ctx.player, "maxHp")
		ctx.shield(ctx.caster, maxHp * ctx.resolve(spec.hpPct) / 100 * math.min(count, spec.max), spec.duration)
	end
end

Offense.circleSelf = function(ctx)
	local radius = ctx.skill.radius or 8
	local hasDamage = ctx.skill.values.dmg ~= nil
	local hits = ctx.skill.hits or 1
	local interval = ctx.skill.interval or 0.4
	ctx.pull(ctx.root.Position)
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
			shieldPerHit(ctx, enemies)
			-- Radiance: allies are healed for a share of the damage value.
			local healShare = ctx.skill.values.heal
			if healShare and hasDamage then
				local amount = ctx.attack() * ctx.value("dmg") / 100 * ctx.value("heal") / 100 * ctx.healMul()
				for _, ally in ctx.alliesInCircle(center, radius) do
					ctx.heal(ally, amount)
				end
			end
		end
		-- S79: every wave asks; Skills.castZones makes the zones on the first one only (the echo has none)
		if hasDamage then
			ctx.lingering(center, percent, n)
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
	local vfx = SkillVfx[ctx.skill.id]
	if vfx and vfx.projectile then
		delay += math.clamp(
			(point - ctx.root.Position).Magnitude / CIRCLE_PROJECTILE_SPEED,
			0.05,
			CIRCLE_PROJECTILE_MAX
		)
	end
	-- S76: pulled enemies reach the point before the first wave
	if ctx.pull(point) then
		delay = math.max(delay, Push.DURATION)
	end
	-- S76 (Biting Arrows): firstWave % more on the first wave only (lingering, echo and later waves from dmg)
	local firstPercent = ctx.value("dmg") * (1 + (ctx.bp.firstWave or 0) / 100)
	local impactRadius = if storm then math.max(4, radius / 3) else radius
	local random = Random.new()
	-- S80: `waves` (Cataclysm) sends one event per wave below; others one event at the start
	local perWave = vfx ~= nil and vfx.waves == true
	if not perWave then
		ctx.fx({ p = point, r = radius, d = delay + (hits - 1) * interval, n = hits })
	end
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
					-- S79 (ROZWOJ 12.3): the bolt counts the enemies in the circle
					hitAll(
						ctx,
						{ chosen },
						if wave == 1 then firstPercent else ctx.value("dmg"),
						true,
						{ areaHits = Skills.areaCount(ctx.skill, #enemies, 1) }
					)
				end
				-- S79: the areaLingering zone splits among the enemies in the circle (none without enemies)
				ctx.lingering(impactAt, ctx.value("dmg"), wave, #enemies)
				return
			end
			if storm then
				ctx.fx({ v = "meteorImpact", p = impactAt, r = impactRadius })
			end
			if perWave then
				-- d: the falling pieces (meteor) land with this wave's damage, not a second later
				ctx.fx({ p = impactAt, r = radius, n = wave, d = 0.2 })
			end
			local enemies = ctx.enemiesInCircle(impactAt, impactRadius)
			hitAll(ctx, enemies, if wave == 1 then firstPercent else ctx.value("dmg"), wave == 1, { from = impactAt })

			if last then
				stunLast(ctx, enemies)
			end
			-- S79: Skills.castZones keeps the zones of the first wave
			ctx.lingering(impactAt, ctx.value("dmg"), wave, 0)
			if wave == 1 then
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
							hitAll(
								ctx,
								ctx.enemiesInCircle(spot, 3.5),
								ctx.value("dmg") * split.pct / 100,
								false,
								{ from = spot, secondary = true }
							)
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
			hitAll(ctx, ctx.enemiesInCircle(point, radius), ctx.value("dmg") * echo.pct / 100, false, { from = point })
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

-- S79 (ROZWOJ 12.3, 14.4): the path first (Logic/Chain.path: nearest not yet hit enemy within the radius of the
-- last one, flat distance), so every hit knows how many enemies the chain hits (areaHits).
Offense.chain = function(ctx)
	local first = ctx.target
	if not first then
		return false, "cast.error.noTarget"
	end
	local Entity = ctx.services.Entity
	local jumps = math.floor(ctx.value("jumps") + 0.5)
	local radius = ctx.skill.radius or 12
	local percent = ctx.value("dmg")
	local targets: { any } = { first }
	local order: { number } = { 1 }
	local start = Entity.Position(first)
	if start then
		-- 1.5: the margin of enemiesInCircle
		local reach = (radius + 1.5) * math.max(1, jumps - 1)
		local points: { Chain.Point } = { { x = start.X, z = start.Z } }
		for _, entity in ctx.enemiesInCircle(start, reach) do
			local p = Entity.Position(entity)
			if entity ~= first and p then
				table.insert(targets, entity)
				table.insert(points, { x = p.X, z = p.Z })
			end
		end
		order = Chain.path(points, 1, radius + 1.5, jumps)
	end
	local path = { ctx.caster.id }
	for i, index in order do
		local current = targets[index]
		table.insert(path, current.id)
		local result = ctx.damage(
			current,
			percent * (1 - 0.1 * (i - 1)),
			{ consumeShot = i == 1, primary = i == 1, areaHits = #order }
		)
		if result and not result.dodged then
			ctx.applyEffects(current, "enemy")
		end
		if i == #order then
			-- Breakpoint: the last jump stuns.
			stunLast(ctx, { current })
		end
	end
	ctx.fx({ path = path })
	return true, nil
end

-- S80 (ROZWOJ 12.5): Arcane Torrent. Starts a beam channel on the target (SkillService owns the loop and every way
-- it ends, Logic/Channel kind "beam"); each tick deals dmg x (1 + growth% x (n - 1)) and may splash (10B).
Offense.beam = function(ctx)
	local target = ctx.target
	if not target or not ctx.isEnemy(target) then
		return false, "cast.error.noTarget"
	end
	local dmg, growth = ctx.value("dmg"), ctx.value("growth")
	return ctx.services.Beam(ctx, target, function(n: number)
		ctx.fx({ t = target.id, n = n })
		ctx.damage(target, Skills.beamTickPct(dmg, growth, n), { primary = true, consumeShot = n == 1 })
	end)
end

return Offense
