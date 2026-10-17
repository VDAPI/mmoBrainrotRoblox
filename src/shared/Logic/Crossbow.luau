--!strict
-- S144 (DESIGN-18 §6.3): the rules of the Hunter's crossbow school (the Crossbow pool). Pure. Toxic Tips: every main hit
-- of a Crossbow skill adds a stack of the caster's tip poison, at most once per Data/Skills.CROSSBOW.tipGap seconds per
-- target (the server keeps the times per player, CombatService.ToxicTip); the Executioner's Bolt hits harder on a target
-- carrying enough stacks of the caster's poisons; Quick Reload shortens only the cooldowns of the Crossbow's skills.
-- Times are os.clock() seconds; nothing here changes its input.

local SkillData = require("../Data/Skills")

local Crossbow = {}

Crossbow.POOL = SkillData.CROSSBOW.pool
Crossbow.TIP_KEY = SkillData.CROSSBOW.tipKey

-- Is a skill of the Crossbow pool (SkillDef.pool)? Common and direction skills are not.
function Crossbow.ofPool(pool: string?): boolean
	return pool == Crossbow.POOL
end

-- The tip of a main hit: Toxic Tips' `toxicTips` % for a skill of the Crossbow pool; a trap's hit with the Trapper's
-- keystone Master Trapper (`masterTrapper` %) gets the larger of the two and no gap (`gapless`). 0 = no tip.
function Crossbow.tipFor(pool: string?, skillType: string, toxicTips: number, masterTrapper: number): (number, boolean)
	local pct = if Crossbow.ofPool(pool) then math.max(0, toxicTips) else 0
	if skillType == "trap" and masterTrapper > 0 then
		return math.max(pct, masterTrapper), true
	end
	return pct, false
end

-- May a tip stack land now: the last one on this target at `last` (nil = never), at least `gap` seconds ago.
function Crossbow.tipReady(last: number?, now: number, gap: number): boolean
	return last == nil or now - last >= gap
end

-- The stacks of the tip poison after one more tip: one more, at most `max`.
function Crossbow.tipStacks(current: number, max: number): number
	return math.clamp(math.floor(current) + 1, 1, math.max(1, max))
end

-- The tip times kept after a tip on `key` at `now`: entries older than `gap` dropped, `key` set to `now`.
function Crossbow.tipRecord(times: { [any]: number }, key: any, now: number, gap: number): { [any]: number }
	local out: { [any]: number } = {}
	for k, t in times do
		if now - t < gap then
			out[k] = t
		end
	end
	out[key] = now
	return out
end

-- The Executioner's Bolt: x(1 + pct / 100) on a target with at least `need` stacks of the caster's poisons.
function Crossbow.venomMul(stacks: number, need: number, pct: number): number
	if stacks >= math.max(1, need) then
		return 1 + math.max(0, pct) / 100
	end
	return 1
end

-- The cooldown reduction of a skill (Logic/Skills.cooldown caps it): the items' `itemCdr` plus Quick Reload's `reload`
-- for a skill of the Crossbow pool only.
function Crossbow.cdrFor(pool: string?, itemCdr: number?, reload: number?): number
	local total = itemCdr or 0
	if Crossbow.ofPool(pool) then
		total += math.max(0, reload or 0)
	end
	return total
end

return table.freeze(Crossbow)
