--!strict
-- S141 (DESIGN-18 §6.1): the ice school's chill. Pure; numbers in Data/Skills.CHILL and in the skills' values. The
-- server (Skills/Context, Types/Offense, CombatService) and the balance model (tests/SkillModel, `-- mirrors`) only call
-- these.
--   * Winter's Grip (hook chillFreeze): every main ice hit of the player on a slowed, not frozen enemy adds a stack to
--     the player's chill counter on it; at CHILL.threshold the counter is spent on a freeze (chillToFreeze).
--   * Bosses and Elite II never freeze (StatusEffectService.IsBossLike): every freeze of a player's ice gives them Deep
--     Chill instead (onFreeze), +deepPct % damage from that player for CHILL.deepDuration s.
--   * Glacial Spike (values.vsFrozen / vsDeepChill): more damage on a frozen target, less on a Deep Chilled one.
--   * Shatter (values.shatter / shatterDeep): ends the target's freeze for x (1 + shatter / 100); on a boss it spends
--     the player's Deep Chill for x (1 + shatterDeep / 100).
--   * Ice Barrier: a monster's melee blow on the bearer slows it, at most once per CHILL.barrierGap s per attacker.
--   * Ice Blood (hook iceBlood): an own damage reduction against slowed or frozen attackers.

local SkillData = require("../Data/Skills")
local Traits = require("./Traits")

local CHILL = SkillData.CHILL

local Chill = {}

Chill.KEY = CHILL.key
Chill.DEEP_KEY = CHILL.deepKey
Chill.THRESHOLD = CHILL.threshold

-- Whether a main ice hit counts toward the counter: the passive is there, the target is slowed and not frozen.
function Chill.counts(active: boolean, slowed: boolean, frozen: boolean): boolean
	return active and slowed and not frozen
end

-- The counter after one more counted hit on `count` stacks and whether it freezes now (then the counter is spent:
-- 0 stacks). `threshold` defaults to CHILL.threshold (at least 1).
function Chill.chillToFreeze(count: number, threshold: number?): (number, boolean)
	local limit = math.max(1, math.floor((threshold or CHILL.threshold) + 1e-9))
	local after = math.max(0, math.floor(count + 1e-9)) + 1
	if after >= limit then
		return 0, true
	end
	return after, false
end

-- What a freeze of the player's ice does to a target: "deepChill" on bosses and Elite II, "freeze" on the rest.
function Chill.onFreeze(bossLike: boolean): "freeze" | "deepChill"
	return if bossLike then "deepChill" else "freeze"
end

-- Deep Chill's % more damage from the player: CHILL.deepPct or Winter's Grip's deepChill hook when higher.
function Chill.deepPct(hook: number?): number
	return math.max(CHILL.deepPct, hook or 0)
end

-- Glacial Spike: the multiplier on a frozen target (+pct %) or, else, on a target with the player's Deep Chill
-- (+deepPct %); 1 on the rest.
function Chill.vsFrozen(frozen: boolean, deepChill: boolean, pct: number, deepPct: number): number
	if frozen then
		return 1 + math.max(0, pct) / 100
	elseif deepChill then
		return 1 + math.max(0, deepPct) / 100
	end
	return 1
end

-- Shatter: the multiplier and what the hit spends: a frozen target's freeze (x (1 + pct / 100)), else the player's Deep
-- Chill on a boss (x (1 + deepPct / 100)); nothing (1) on the rest.
function Chill.shatterMul(
	frozen: boolean,
	deepChill: boolean,
	pct: number,
	deepPct: number
): (number, ("freeze" | "deepChill")?)
	if frozen then
		return 1 + math.max(0, pct) / 100, "freeze"
	elseif deepChill then
		return 1 + math.max(0, deepPct) / 100, "deepChill"
	end
	return 1, nil
end

-- A player's freeze bonus (Glacial Spike, Shatter) never goes above `cap` against players (Data/Combat.pvp.finisher).
function Chill.pvpMul(mul: number, cap: number): number
	return math.min(mul, math.max(1, cap))
end

-- Ice Barrier: whether a blow at `now` slows the attacker whose last slow by the barrier was at `last` (nil = never).
function Chill.barrierReady(last: number?, now: number): boolean
	return Traits.gapReady(last, now, CHILL.barrierGap)
end

-- Ice Blood: the own damage reduction % against an attacker (0 unless it is slowed or frozen).
function Chill.bloodGuard(pct: number, slowed: boolean, frozen: boolean): number
	if pct <= 0 or not (slowed or frozen) then
		return 0
	end
	return pct
end

-- Blizzard: whether wave `wave` freezes an enemy the cast has not frozen yet (`from` = the skill's freezeWave).
function Chill.waveFreezes(wave: number, from: number?, done: boolean): boolean
	return from ~= nil and wave >= from and not done
end

-- Frozen Orb: the distance from the caster of wave `wave`'s centre (travel x wave / hits).
function Chill.orbAt(travel: number, wave: number, hits: number): number
	return travel * math.clamp(wave, 0, math.max(1, hits)) / math.max(1, hits)
end

return Chill
