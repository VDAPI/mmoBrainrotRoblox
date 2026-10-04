--!strict
-- Boss numbers (DESIGN §16). Pure functions (Lune tests).

local Time = require("./Time")

local BossScaling = {}

-- HP multiplier on top of a normal monster of the boss's level: 30 x (1 + 0.6 x (players - 1)).
function BossScaling.hpMultiplier(players: number): number
	return 30 * (1 + 0.6 * (math.max(1, players) - 1))
end

-- Item drops: 3–4 (rolled by the caller) + 1 per player above 3.
function BossScaling.extraItems(players: number): number
	return math.max(0, players - 3)
end

-- Phase (1-based) for an HP fraction and descending thresholds like { 0.7, 0.35 }.
function BossScaling.phaseFor(hpFraction: number, thresholds: { number }): number
	local phase = 1
	for i, threshold in thresholds do
		if hpFraction <= threshold then
			phase = i + 1
		end
	end
	return phase
end

-- Whether the character already killed this boss today (lockouts store the UTC day number).
function BossScaling.isLocked(lockouts: { [string]: number }?, bossId: string, now: number): boolean
	local day = lockouts and lockouts[bossId]
	return day ~= nil and day >= Time.dayNumber(now)
end

-- Seconds until the daily reset (00:00 UTC).
function BossScaling.untilReset(now: number): number
	return (Time.dayNumber(now) + 1) * 86400 - now
end

-- Minimum character level to enter a boss dungeon.
function BossScaling.requiredLevel(bossLevel: number): number
	return bossLevel - 5
end

return BossScaling
