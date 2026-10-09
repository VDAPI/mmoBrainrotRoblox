--!strict
-- Boss numbers (DESIGN §16). Pure functions (Lune tests).

local Config = require("../Config")
local Time = require("./Time")
local Types = require("../Types")

local BossScaling = {}

-- HP multiplier on top of a normal monster of the boss's level: 30 x (1 + 0.6 x (players - 1)).
function BossScaling.hpMultiplier(players: number): number
	return 30 * (1 + 0.6 * (math.max(1, players) - 1))
end

-- Item drops: 3–4 (rolled by the caller) + 1 per player above 3.
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

-- Attempts at this boss today (S30: runs store { day = UTC day number, n = attempts that day }). Since 2026-10-10 a
-- failed run (timeout or wipe) uses an attempt too; `k` counts the kills only (older entries: k = n).
function BossScaling.runsToday(runs: { [string]: Types.BossRun }?, bossId: string, now: number): number
	local entry = runs and runs[bossId]
	if type(entry) ~= "table" or entry.day ~= Time.dayNumber(now) then
		return 0
	end
	return math.max(0, tonumber(entry.n) or 0)
end

-- Kills of this boss today (they raise the Legendary / Mythic chances; a failed attempt does not).
function BossScaling.killsToday(runs: { [string]: Types.BossRun }?, bossId: string, now: number): number
	local entry = runs and runs[bossId]
	if type(entry) ~= "table" or entry.day ~= Time.dayNumber(now) then
		return 0
	end
	return math.max(0, tonumber(entry.k) or tonumber(entry.n) or 0)
end

-- Whether the character used all its attempts at this boss today (`limit` defaults to Config.Boss.dailyRuns).
function BossScaling.isLocked(runs: { [string]: Types.BossRun }?, bossId: string, now: number, limit: number?): boolean
	return BossScaling.runsToday(runs, bossId, now) >= (limit or Config.Boss.dailyRuns)
end

-- The runs entry after one more attempt now (`killed` = the boss died, which also counts a kill).
function BossScaling.addRun(
	runs: { [string]: Types.BossRun }?,
	bossId: string,
	now: number,
	killed: boolean?
): Types.BossRun
	return {
		day = Time.dayNumber(now),
		n = BossScaling.runsToday(runs, bossId, now) + 1,
		k = BossScaling.killsToday(runs, bossId, now) + (if killed == false then 0 else 1),
	}
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
