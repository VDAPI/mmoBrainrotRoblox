--!strict
-- S140 (DESIGN-18 §6.1): the fire school's burn and its passives. Pure; numbers in Data/Skills (BURN, EMBER, PHOENIX)
-- and Data/Combat.pvp.phoenix; Phoenix Heart's rest, invulnerability and blast are its passive values (hooks). The server (CombatService.ApplyBurn, Skills/Context, Types/Offense, SkillService) and the
-- balance model (tests/SkillModel, `-- mirrors`) only call these.
--   * One burn per player on a target (effect key skillId = Burn.KEY): fire skills add `burnStacks` stacks, the
--     adaptive weapon burn one. Each stack is worth pct % of its hit over `duration` s (Traits.dotTick); a refresh
--     adds the unpaid rest (accumulate without a cap), so every hit is paid in full and the stacks only count.
--   * The stack count: at most cap = BURN.maxStacks + Kindling's burnStacks hook; a refresh renews the end time.
--   * Kindling (burnBonus hook): +perStack % fire damage of the player's hits per own stack on the target.
--   * Immolate (values.vsBurning): +pct % per own stack on the target. Combustion (values.detonate): consumes the
--     stacks for detonate % x stacks around the target, a stun from BURN.stunAt stacks (never bosses).
--   * Phoenix Heart: a lethal blow from a monster or a player leaves 1 HP once per `rest` s (hook phoenixRest); damage
--     over time, "admin" and "world" are never saved (the rule of Guardian Angel, Logic/Skills.angelSave).

local Combat = require("../Data/Combat")
local SkillData = require("../Data/Skills")
local Traits = require("./Traits")

local BURN = SkillData.BURN

local Burn = {}

Burn.KEY = BURN.key

-- Most stacks of a player's burn on one target: the data's maxStacks plus `extra` (Kindling's burnStacks hook).
function Burn.cap(extra: number?): number
	return math.max(1, math.floor(BURN.maxStacks + math.max(0, extra or 0) + 1e-9))
end

-- Stacks after `n` more (at least one) on `current` running stacks (0 without a burn), at most `cap`.
function Burn.add(current: number, n: number?, cap: number): number
	local more = math.max(1, math.floor((n or 1) + 1e-9))
	return math.clamp(math.max(0, math.floor(current + 1e-9)) + more, 1, math.max(1, cap))
end

-- Damage per tick of `stacks` stacks of one hit: pct % (default BURN.pct) of `hit` each over `duration` s (default
-- BURN.duration), raised by `bonus` % (dotPower).
function Burn.tick(hit: number, stacks: number, bonus: number, pct: number?, duration: number?): number
	return Traits.dotTick(hit, (pct or BURN.pct) * math.max(1, stacks), duration or BURN.duration, bonus)
end

-- Kindling: multiplier of the player's fire hits on a target with `stacks` own burn stacks (+perStack % each).
function Burn.stackBonus(stacks: number, perStack: number): number
	if stacks <= 0 or perStack <= 0 then
		return 1
	end
	return 1 + stacks * perStack / 100
end

-- Immolate: multiplier on a target with `stacks` own burn stacks (+pct % each; 1 when it does not burn).
function Burn.vsBurning(stacks: number, pct: number): number
	if stacks <= 0 or pct <= 0 then
		return 1
	end
	return 1 + stacks * pct / 100
end

-- Combustion: the % of attack the detonation of `stacks` stacks deals (pct each) and whether it stuns.
function Burn.detonate(stacks: number, pct: number): (number, boolean)
	if stacks <= 0 then
		return 0, false
	end
	return stacks * math.max(0, pct), stacks >= BURN.stunAt
end

-- Phoenix Heart: the damage to let through and whether the passive saved the player. `readyAt` = the server time the
-- passive is ready again (nil = ready), `source` the ResourceService damage source. Saves "monster", "intercept" and
-- "pvp" (Data/Combat.pvp.phoenix > 0); never damage over time (no attacker), "admin" or "world".
function Burn.phoenixSave(
	hp: number,
	amount: number,
	source: string,
	has: boolean,
	readyAt: number?,
	now: number
): (number, boolean)
	if not has or amount < hp or (readyAt ~= nil and now < readyAt) then
		return amount, false
	end
	local saves = source == "monster" or source == "intercept" or (source == "pvp" and Combat.pvp.phoenix > 0)
	if not saves then
		return amount, false
	end
	return math.max(0, hp - 1), true
end

-- Seconds of invulnerability after a save: the passive's `seconds`, x Combat.pvp.phoenix after a player's blow.
function Burn.phoenixInvuln(seconds: number, pvp: boolean): number
	return math.max(0, seconds) * (if pvp then Combat.pvp.phoenix else 1)
end

-- The server time Phoenix Heart is ready again after a save at `now` (`rest` = the passive's rest in seconds).
function Burn.phoenixReady(now: number, rest: number): number
	return now + math.max(0, rest)
end

return Burn
