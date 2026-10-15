--!strict
-- The Hunter's falcon (S77, ROZWOJ 11.5): one per player, a damage loop scheduled with task.delay and guarded by a
-- token, so a stopped or replaced falcon never strikes again. Royal Falcon (keystone hook `royalFalcon`) stays until
-- the fight is over.
-- Not a character: it cannot be hit, has no HP and draws no attention by itself; clients draw the bird from the
-- events (falconStrike / falconDive / falconCircle / falconEnd, each with `d` = seconds to keep it).
-- Leaks: the only places that schedule are `start` (the first strike) and `tick` (the next one), always with the
-- token; `stop` and a new `start` drop the state, so a pending tick returns at once. No while loops, no closures over
-- an old ctx: task.delay(tick, player, token). Died, CharacterLeaving and PlayerRemoving (SkillService) call `stop`.
-- A tick schedules the next one before it strikes, so an error in a strike never breaks the chain without a stop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Context = require(script.Parent.Context)
local PathData = require(ReplicatedStorage.Shared.Data.Paths)

type State = {
	token: number, -- bumped on every start; a scheduled tick with an old token returns at once
	ctx: Context.Ctx, -- the Falcon cast (effective def, rank, breakpoint behaviours)
	endsAt: number, -- os.clock() of the normal end (duration + falconBond seconds without the keystone)
	interval: number,
	keep: number, -- seconds clients keep the bird after an event
	calmSince: number?, -- Royal Falcon: when the hunter left combat
}

local Companion = {}

local active: { [Player]: State } = {}
local nextToken = 0

local function hook(ctx: Context.Ctx, id: string): number
	return ctx.services.Combat.Hook(ctx.player, id)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- ROZWOJ 11.5: the hunter's current target within `range`, read on every strike; without one the nearest monster
-- within `radius` that the hunter or the party is already fighting (threat table), so the falcon never starts a
-- fight by itself. A player is a target only when selected (isEnemy checks Pvp.CanAttack).
local function pickTarget(state: State): any
	local ctx = state.ctx
	local origin = ctx.root.Position
	local Entity = ctx.services.Entity
	local selected = ctx.services.Combat.GetTarget(ctx.player)
	local at = selected and Entity.Position(selected)
	if at and ctx.isEnemy(selected) and flatDistance(at, origin) <= (ctx.skill.range or 0) then
		return selected
	end
	local party = ctx.services.Party.Allies(ctx.player) -- S126: the help group
	local best, bestDistance = nil, math.huge
	for _, entity in Entity.QueryMonsters(origin, ctx.skill.radius or 0) do
		local position = Entity.Position(entity)
		local monster = entity.monster
		if not position or not monster or not ctx.isEnemy(entity) then
			continue
		end
		local fighting = false
		for _, member in party do
			if monster.threat[member] ~= nil then
				fighting = true
				break
			end
		end
		local distance = flatDistance(position, origin)
		if
			fighting
			and distance <= (ctx.skill.radius or 0)
			and (distance < bestDistance or (distance == bestDistance and best and entity.id < best.id))
		then
			best, bestDistance = entity, distance
		end
	end
	return best
end

local function strike(state: State, target: any, pct: number, dive: boolean)
	local ctx = state.ctx
	-- consumeShot = false: Camouflage's / Draw a Bead's guaranteed crit and Disengage's next shot stay for the hunter;
	-- primary: 10B splash (onHit); noProc: not a weapon (no item on-hit effects, no Weak Spot)
	local result = ctx.damage(target, pct, { consumeShot = false, primary = true, noProc = true })
	if result and not result.dodged then
		ctx.applyEffects(target, "enemy") -- 5B: the slow
		if hook(ctx, "royalFalcon") > 0 then
			ctx.services.Combat.Spot(ctx.player, target) -- the Royal Falcon spots
		end
		if dive and target.kind == "monster" then
			ctx.services.StatusEffect.Apply(target, "stun", {
				duration = PathData.HOOK_RULES.royalFalcon.stun,
				source = ctx.player,
				skillId = ctx.skill.id,
				notBoss = true,
			})
		end
	end
	-- 11.5: in PvP a strike (even a dodged one: the bird has seen them) ends Camouflage
	if result and target.kind == "player" then
		ctx.services.StatusEffect.Remove(target, "camouflage")
	end
	ctx.fx({ v = if dive then "falconDive" else "falconStrike", t = target.id, d = state.keep })
end

local function tick(player: Player, token: number)
	local state = active[player]
	if not state or state.token ~= token then
		return
	end
	local ctx = state.ctx
	if not player.Parent or not ctx.root.Parent or ctx.services.Resource.IsDead(player) then
		Companion.stop(player)
		return
	end
	local now = os.clock()
	-- read on every tick: the keystone may have been refunded
	if hook(ctx, "royalFalcon") > 0 then
		if ctx.services.Resource.InCombat(player) then
			state.calmSince = nil
		else
			state.calmSince = state.calmSince or now
		end
		local calm = state.calmSince
		if now >= state.endsAt and calm ~= nil and now - calm >= PathData.HOOK_RULES.royalFalcon.linger then
			Companion.stop(player)
			return
		end
	elseif now >= state.endsAt then
		Companion.stop(player)
		return
	end
	-- at most one pending tick per player, scheduled before the strike (see the header)
	task.delay(state.interval, tick, player, token)
	local target = if ctx.services.Zone.GetPvpZone(player) == "green" then nil else pickTarget(state)
	if target then
		strike(state, target, ctx.value("dmg") * (1 + hook(ctx, "falconDamage") / 100), false)
	else
		ctx.fx({ v = "falconCircle", d = state.keep })
	end
end

-- Releases the falcon of this cast (a new cast replaces the running one; the client keeps its bird).
function Companion.start(ctx: Context.Ctx)
	local rules = PathData.HOOK_RULES.royalFalcon
	local royal = hook(ctx, "royalFalcon") > 0
	local duration = ctx.scaled(ctx.skill.duration) + (if royal then 0 else hook(ctx, "falconBond"))
	local interval = math.max(rules.minInterval, (ctx.skill.interval or 2) * (1 - hook(ctx, "falconInterval") / 100))
	local delay = ctx.skill.delay or 1
	nextToken += 1
	local state: State = {
		token = nextToken,
		ctx = ctx,
		endsAt = os.clock() + duration,
		interval = interval,
		keep = delay + interval + 1,
		calmSince = nil,
	}
	active[ctx.player] = state
	ctx.fx({ t = ctx.caster.id, d = state.keep })
	task.delay(delay, tick, ctx.player, state.token)
end

-- Ends the falcon; `silent` skips the fly-away event (the player is gone).
function Companion.stop(player: Player, silent: boolean?)
	local state = active[player]
	if not state then
		return
	end
	active[player] = nil
	if not silent then
		state.ctx.fx({ v = "falconEnd" })
	end
end

-- Royal Falcon (ROZWOJ 11.5): Hunter's Mark sends it diving on the marked target, rules.dive % (+ bondDive points
-- per falconBond second) and a stun on monsters (not bosses). Never moves the strike schedule.
function Companion.dive(player: Player, target: any)
	local state = active[player]
	if not state or not target or hook(state.ctx, "royalFalcon") <= 0 then
		return
	end
	local rules = PathData.HOOK_RULES.royalFalcon
	local ctx = state.ctx
	local pct = (rules.dive + hook(ctx, "falconBond") * rules.bondDive) * (1 + hook(ctx, "falconDamage") / 100)
	strike(state, target, pct, true)
end

function Companion.active(player: Player): boolean
	return active[player] ~= nil
end

return Companion
