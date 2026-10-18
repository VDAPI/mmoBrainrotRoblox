--!strict
-- S149: the one contribution rule of the world events (S101, Logic/WorldEvents) and the world boss (Logic/WorldBoss).
-- Damage, healing, shields and damage taken for an ally count alike (weighted by `share`); the reward threshold is a
-- share of all points or an HP equivalent, whichever is lower. Pure, no data requires.

export type Contribution = { dmg: number, heal: number, shield: number, intercept: number }
-- The fields of Data/WorldEvents.share and Data/WorldBoss.share this module reads.
export type Share = { min: number, healMul: number, shieldMul: number, interceptMul: number }

local Contribution = {}

function Contribution.empty(): Contribution
	return { dmg = 0, heal = 0, shield = 0, intercept = 0 }
end

-- Points of a contribution: damage + healing, shields and intercepted damage times their multipliers.
function Contribution.points(c: Contribution, share: Share): number
	return c.dmg + c.heal * share.healMul + c.shield * share.shieldMul + c.intercept * share.interceptMul
end

-- Points needed for the reward: share.min of all points, or `hpEq` points (an HP equivalent), whichever is lower;
-- nobody fought (total 0) = never.
function Contribution.threshold(total: number, hpEq: number, share: Share): number
	if total <= 0 then
		return math.huge
	end
	return math.min(share.min * total, hpEq)
end

-- Whether `points` of `total` reach the threshold (and are more than nothing).
function Contribution.eligible(points: number, total: number, hpEq: number, share: Share): boolean
	return points > 0 and points >= Contribution.threshold(total, hpEq, share)
end

return Contribution
