--!strict
-- On-hit effects of item traits and lines (S63, docs/STATY.md 5, 8, 13). Pure helpers CombatService and
-- StatusEffectService use; the numbers live in Data/Combat, Data/BuffCategories and Data/ItemTraits. S64 adds the
-- defensive and conditional traits (block, counter, execute, controlled targets). S65 adds the
-- rhythm traits and the player's trait state here.

local BuffCategories = require("../Data/BuffCategories")
local Combat = require("../Data/Combat")
local Stats = require("../Data/Stats")

local Traits = {}

-- How a hit was dealt (CombatService.DealOptions passes as is).
export type Hit = { basic: boolean?, area: boolean?, noProc: boolean? }

-- Skill types that hit every target in an area (Data/Skills/Types); one-target types: target, projectile, charge.
Traits.AREA_TYPES = table.freeze({
	cone = true,
	circleSelf = true,
	circleTarget = true,
	line = true,
	chain = true,
	trap = true,
} :: { [string]: boolean })

function Traits.isAreaSkill(skillType: string?): boolean
	return skillType ~= nil and Traits.AREA_TYPES[skillType] == true
end

-- Share of an effect's chance this hit gets: 0 for secondary hits (noProc), 1 for basic attacks and one-target
-- skills, Combat.areaProcShare per target of an area skill.
function Traits.procShare(hit: Hit?): number
	if hit == nil then
		return 1
	end
	if hit.noProc then
		return 0
	end
	if hit.area and not hit.basic then
		return Combat.areaProcShare
	end
	return 1
end

-- % chance of one effect: trait chance + line chance, capped at Combat.onHitChanceCap, times the hit's share.
function Traits.chance(traitChance: number, lineChance: number, share: number): number
	return math.min(math.max(0, traitChance) + math.max(0, lineChance), Combat.onHitChanceCap) * share
end

-- Ticks an effect of `duration` s really deals: StatusEffectService removes the effect before its last tick, so
-- dividing by these makes the ticks add up to exactly pct % of the hit (STATY 5). 4 s -> 3, 5 s -> 4.
function Traits.ticks(duration: number): number
	return math.max(1, math.ceil(duration) - 1)
end

-- One tick of a damage over time worth `pct` % of `hit` over `duration` s, raised by `bonus` % (dotPower).
function Traits.dotTick(hit: number, pct: number, duration: number, bonus: number): number
	return math.max(1, hit * pct / 100 / Traits.ticks(duration) * (1 + bonus / 100))
end

-- A tick of a player on a player (STATY 8); StatusEffectService.Apply is the only caller, so it applies once.
function Traits.pvpTick(tick: number): number
	return tick * Combat.pvp.dot
end

-- A trait value against a player (TraitDef.pvp; nil = 1).
function Traits.pvpValue(value: number, multiplier: number?): number
	return value * (if multiplier == nil then 1 else multiplier)
end

-- S64 (STATY 5, 8): block chance in % for one regular hit; pvp halves it after the cap.
function Traits.blockChance(total: number, pvp: boolean): number
	return math.clamp(total, 0, Combat.blockCap) * (if pvp then Combat.pvp.block else 1)
end

-- S64: counter chance in % after a regular attack; the same with riposteCap and pvp.counter.
function Traits.counterChance(total: number, pvp: boolean): number
	return math.clamp(total, 0, Combat.riposteCap) * (if pvp then Combat.pvp.counter else 1)
end

-- S64: bonus % below Combat.lowHpFraction: executioner (nodes, legends) + Beheading; traitPvp = the trait's
-- multiplier against players, nil against monsters. Only the trait part is halved in PvP.
function Traits.executeBonus(executioner: number, trait: number, traitPvp: number?): number
	local bonus = math.max(0, executioner) + Traits.pvpValue(math.max(0, trait), traitPvp)
	return math.min(bonus, Combat.executionerCap)
end

-- S64: Easy Prey: `value` when the target is slowed, rooted, frozen or stunned (StatusEffectService.SlowFactor < 1).
function Traits.controlledBonus(value: number, slowFactor: number, traitPvp: number?): number
	if slowFactor >= 1 then
		return 0
	end
	return Traits.pvpValue(math.max(0, value), traitPvp)
end

-- Armour break from items at `stacks` stacks of `unit` %.
function Traits.armorBreakCap(unit: number, stacks: number): number
	return math.min(unit * stacks, BuffCategories.caps.enemyArmorItem)
end

-- Attack interval under `slowPct` % attack slow (capped by BuffCategories.caps.enemyAttackSlow).
function Traits.slowedInterval(interval: number, slowPct: number): number
	local slow = math.clamp(slowPct, 0, BuffCategories.caps.enemyAttackSlow)
	return interval / (1 - slow / 100)
end

-- True when `gap` s passed since `last` (nil = never).
function Traits.gapReady(last: number?, now: number, gap: number): boolean
	return last == nil or now - last >= gap
end

-- Mana / energy refunded by the resourceOnHit line: min(linePct, cap) % of the maximum, 0 within the gap.
function Traits.resourceOnHit(linePct: number, maxResource: number, last: number?, now: number): number
	if linePct <= 0 or not Traits.gapReady(last, now, Combat.resourceOnHitGap) then
		return 0
	end
	return math.max(0, maxResource) * math.min(linePct, Combat.resourceOnHitCap) / 100
end

-- Rhythm and player state traits (S65, STATY 5) ----------------------------------------------------------------

export type Spot = { x: number, z: number }
export type Seal = { x: number, z: number, since: number, lit: boolean }
export type ElementSpec = {
	burnPct: number,
	burnDuration: number,
	exactTicks: boolean?, -- true: Traits.dotTick (items, skills since S79); nil: hit x pct / duration (legacy)
	slowPct: number,
	slowDuration: number,
	arcPct: number,
	arcRadius: number,
	sameTargetPct: number?, -- sameTargetPct: arc on the same target when nobody is near (Spark)
}
export type ElementPlan = {
	kind: "burn" | "slow" | "arc",
	pct: number, -- burn: % of the hit in total; slow: slow %; arc: % of the hit for the jump
	duration: number, -- burn / slow seconds (0 for arcs)
	tick: number?, -- burn: damage per tick
	sameTarget: number, -- arc with no second enemy: % of the hit on the same target, 0 = nothing
}

-- Twin Cut: counts basic attacks; the `every`-th one strikes again. A pause longer than `reset` s (or no previous
-- attack) restarts the count. Returns the new count and whether this attack is the extra cut.
function Traits.twinCut(count: number, last: number?, now: number, every: number, reset: number): (number, boolean)
	local current = if last == nil or now - last > reset then 0 else count
	current += 1
	if current >= every then
		return 0, true
	end
	return current, false
end

-- Run Through: index of the candidate closest behind the target in a band `width` wide reaching `depth` studs past
-- the target's back edge (flat, along attacker -> target); lower index on a tie. nil: none, or no direction.
function Traits.behind(
	attacker: Spot,
	target: Spot,
	targetRadius: number,
	candidates: { Spot },
	width: number,
	depth: number
): number?
	local dx, dz = target.x - attacker.x, target.z - attacker.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 0.5 then
		return nil
	end
	dx, dz = dx / length, dz / length
	local best: number? = nil
	local bestAlong = math.huge
	for i, c in candidates do
		local ox, oz = c.x - target.x, c.z - target.z
		local along = ox * dx + oz * dz
		local side = math.abs(ox * dz - oz * dx)
		if along > 0 and along <= targetRadius + depth and side <= width / 2 and along < bestAlong then
			best, bestAlong = i, along
		end
	end
	return best
end

-- Runic Seal: the anchor stays while the player moves at most `step` studs (flat) from it and glows after `still` s;
-- a longer move (or no state) sets a new, unlit anchor.
function Traits.sealStep(state: Seal?, x: number, z: number, now: number, still: number, step: number): Seal
	if state == nil or math.sqrt((x - state.x) ^ 2 + (z - state.z) ^ 2) > step then
		return { x = x, z = z, since = now, lit = false }
	end
	return { x = state.x, z = state.z, since = state.since, lit = now - state.since >= still }
end

-- Full Draw: % bonus of the drawn shot, x the main weapon's base speed (unarmed speed without one). The only formula
-- of the bonus (the tooltip detail of S68 uses it too).
function Traits.drawBonus(value: number, weaponSpeed: number?, pvpMultiplier: number?): number
	return Traits.pvpValue(value, pvpMultiplier) * (weaponSpeed or Stats.Formula.unarmed.speed)
end

-- Saving Blow on the bearer: the part of `pct` that fits under the lifesteal cap left by the bearer's lifesteal.
function Traits.savingSelfShare(pct: number, lifesteal: number): number
	local def = Stats.get("lifesteal")
	local cap = if def and def.cap then def.cap else 0
	return math.clamp(cap - math.clamp(lifesteal, 0, cap), 0, math.max(0, pct))
end

-- Weapon-element effect of a hit (adaptive skills, Elemental Spark), strengthened by `rider` % (elementRider):
-- fire burns longer-lasting damage, ice slows longer, lightning arcs harder. `staffArc`: with no second enemy a
-- skill arc hits the same target for arcPct x rider % (Elemental Might). nil for other elements.
function Traits.elementPlan(
	element: string?,
	spec: ElementSpec,
	hit: number,
	rider: number,
	dotBonus: number,
	staffArc: boolean
): ElementPlan?
	local r = math.max(0, rider)
	if element == "fire" then
		local pct = spec.burnPct * (1 + r / 100)
		local tick = if spec.exactTicks
			then Traits.dotTick(hit, pct, spec.burnDuration, dotBonus)
			else math.max(1, hit * pct / 100 / spec.burnDuration) * (1 + dotBonus / 100)
		return { kind = "burn", pct = pct, duration = spec.burnDuration, tick = tick, sameTarget = 0 }
	elseif element == "ice" then
		return {
			kind = "slow",
			pct = spec.slowPct,
			duration = spec.slowDuration * (1 + r / 100),
			sameTarget = 0,
		}
	elseif element == "lightning" then
		local sameTargetPct = spec.sameTargetPct
		local sameTarget = if sameTargetPct
			then sameTargetPct * (1 + r / 100)
			elseif staffArc and r > 0 then spec.arcPct * r / 100
			else 0
		return { kind = "arc", pct = spec.arcPct * (1 + r / 100), duration = 0, sameTarget = sameTarget }
	end
	return nil
end

return Traits
