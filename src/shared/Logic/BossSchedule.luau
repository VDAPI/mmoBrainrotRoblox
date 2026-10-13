--!strict
-- Boss attack choice (S87, balance plan D3, target G11). Pure: the same functions pick the attack in
-- Entities/Boss.Step and in the balance model (tests/Balance.bossCadence). No data requires.
--
-- Rule: among the ready attacks the one most overdue relative to its own cooldown wins,
-- (now - nextAttack[id]) / cooldown. "Oldest ready" would give every queued attack about the same number of casts
-- whatever its cooldown (short cooldowns starve); the ratio gives every attack the same share of its own rate.

local BossSchedule = {}

export type Attack = { id: string, phases: { number }, cooldown: number }

-- Cooldown in the overdue ratio's denominator: the same number Boss.Step writes to nextAttack.
local function effectiveCooldown(attack: Attack): number
	return math.max(attack.cooldown, 0.1)
end

-- Attacks of `phase` that are ready at `now`, in list order (a missing nextAttack entry counts as 0).
function BossSchedule.ready<A>(attacks: { A }, phase: number, now: number, nextAttack: { [string]: number }): { A }
	local out = {}
	for _, attack in attacks do
		local a = (attack :: any) :: Attack
		if table.find(a.phases, phase) and now >= (nextAttack[a.id] or 0) then
			table.insert(out, attack)
		end
	end
	return out
end

-- S87 (balance plan D3, target G11): among ready attacks, the one most overdue relative to its own cooldown,
-- (now - nextAttack[id]) / cooldown; ties go to the first in list order. nil when `ready` is empty.
function BossSchedule.pick<A>(ready: { A }, now: number, nextAttack: { [string]: number }): A?
	local best: A? = nil
	local bestRatio = -math.huge
	for _, attack in ready do
		local a = (attack :: any) :: Attack
		local ratio = (now - (nextAttack[a.id] or 0)) / effectiveCooldown(a)
		if ratio > bestRatio then
			best = attack
			bestRatio = ratio
		end
	end
	return best
end

return BossSchedule
