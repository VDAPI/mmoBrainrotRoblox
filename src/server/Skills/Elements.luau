--!strict
-- Weapon-element effects of adaptive skills (Skills/Context) and Elemental Spark (CombatService), STATY 5; recipe in
-- Logic/Traits.elementPlan, strengthened by the elementRider hook. Frostbite (chill) comes with every ice weapon from
-- every slow and freeze of the player's ice (STATY 3).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local SkillData = require(Shared.Data.Skills)
local Traits = require(Shared.Logic.Traits)

local Elements = {}

export type Services = { StatusEffect: any, Entity: any, Combat: any, Pvp: any }
export type Proc = {
	player: Player,
	element: string?, -- weapon element: "fire" | "ice" | "lightning"
	target: any, -- entity that was hit
	hit: number, -- items: dotBase; skills: what adaptiveEffect used before S65
	spec: Traits.ElementSpec,
	skillId: string?, -- effect key: skill.id as Context passes it since S53, EffectStack.ITEM for the Spark
	accumulate: boolean?, -- burn refresh adds the unpaid rest (Spark; skills since S79)
	players: boolean?, -- arcs may jump to attackable players (Spark); skills: monsters only, as before
	jump: (other: any, pct: number) -> (), -- deals the arc through the caller's damage path (noProc)
	fx: ((from: any, to: any) -> ())?,
}

-- elementRider % (items and providers, so path nodes add themselves) and whether a skill arc with no second enemy
-- hits the same target (riderSameTarget, Elemental Might).
function Elements.rider(services: Services, player: Player): (number, boolean)
	return services.Combat.Hook(player, "elementRider"), services.Combat.Hook(player, "riderSameTarget") > 0
end

-- Multiplier of the duration of the player's ice control (1 + elementRider / 100); S79: also the tick of the weapon
-- element zones of the player's skills (Skills/Context startZone, STATY 3).
function Elements.power(services: Services, player: Player): number
	return 1 + math.max(0, services.Combat.Hook(player, "elementRider")) / 100
end

-- Frostbite on `entity` for `duration` s when the player's weapon is of ice: SkillData.FROSTBITE or the higher fixed
-- hook "frostbite" (wand 6, staff 10).
function Elements.chill(services: Services, player: Player, entity: any, duration: number, weaponElement: string?)
	if weaponElement ~= "ice" or duration <= 0 then
		return
	end
	local value = math.max(SkillData.FROSTBITE, services.Combat.Hook(player, "frostbite"))
	services.StatusEffect.Apply(entity, "frostbite", { duration = duration, value = value, source = player })
end

-- Nearest other enemy within `radius` of the target: living monsters (3D), and attackable players when allowed.
local function nearestOther(services: Services, proc: Proc, from: Vector3, radius: number): any?
	local Entity = services.Entity
	local best, bestDistance = nil, radius
	for _, other in Entity.QueryMonsters(from, radius) do
		local p = Entity.Position(other)
		local alive = other.monster ~= nil and other.monster:IsAlive()
		if other ~= proc.target and alive and p and (p - from).Magnitude <= bestDistance then
			best, bestDistance = other, (p - from).Magnitude
		end
	end
	if proc.players then
		for _, other in Entity.QueryPlayers(from, radius) do
			local p = Entity.Position(other)
			local victim = other.player
			if
				other ~= proc.target
				and victim
				and victim ~= proc.player
				and p
				and (p - from).Magnitude <= bestDistance
				and services.Pvp.CanAttack(proc.player, victim)
			then
				best, bestDistance = other, (p - from).Magnitude
			end
		end
	end
	return best
end

function Elements.apply(services: Services, proc: Proc)
	local player = proc.player
	local rider, staffArc = Elements.rider(services, player)
	local plan =
		Traits.elementPlan(proc.element, proc.spec, proc.hit, rider, services.Combat.DotBonus(player, "burn"), staffArc)
	if not plan then
		return
	end
	local target = proc.target
	if plan.kind == "burn" then
		services.StatusEffect.Apply(target, "burn", {
			duration = plan.duration,
			value = plan.pct,
			source = player,
			tickAmount = plan.tick,
			skillId = proc.skillId,
			accumulate = proc.accumulate,
		})
	elseif plan.kind == "slow" then
		local slowed = services.StatusEffect.Apply(target, "slow", {
			duration = plan.duration,
			value = plan.pct,
			source = player,
			skillId = proc.skillId,
			category = "enemySlow",
		})
		if slowed then
			Elements.chill(services, player, target, plan.duration, proc.element)
		end
	else
		local from = services.Entity.Position(target)
		if not from then
			return
		end
		local best = nearestOther(services, proc, from, proc.spec.arcRadius)
		if best then
			if proc.fx then
				proc.fx(target, best)
			end
			proc.jump(best, plan.pct)
		elseif plan.sameTarget > 0 then
			proc.jump(target, plan.sameTarget)
		end
	end
end

return Elements
