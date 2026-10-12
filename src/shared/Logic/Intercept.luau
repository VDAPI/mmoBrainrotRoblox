--!strict
-- The Guardian's intercept (S61, ROZWOJ 7.6). Pure: StatusEffectService's damage filter feeds it the intercept
-- effects on the target. Only monster blows (red zones too) move; at most one guard per hit (the strongest share, a tie
-- to the closer one); the share is capped at BuffCategories.caps.intercept and a guard takes at most
-- caps.interceptPerSecond % of max HP per Combat.interceptWindow, fixed from the first take. What the guard cannot take
-- stays on the target: no second guard is tried.

local BuffCategories = require("../Data/BuffCategories")
local Combat = require("../Data/Combat")

local Intercept = {}

export type Candidate = {
	guard: any, -- Player in the game, any key in tests
	share: number, -- % of each hit (the effect's value)
	radius: number, -- studs the guard may stand from the target
	distance: number, -- flat studs between guard and target
	alive: boolean,
}
export type Window = { start: number, taken: number }

-- Only monster blows. Never PvP (duels go that way too), damage over time, admin, world, unknown or an intercepted part
-- itself (two guards never pass damage back and forth).
function Intercept.applies(source: string): boolean
	return source == "monster"
end

-- The guard that takes part of the hit: alive, within its radius; the highest share, a tie to the smaller distance,
-- a full tie to the first in the list.
function Intercept.pick(candidates: { Candidate }): Candidate?
	local best: Candidate? = nil
	for _, c in candidates do
		if not c.alive or c.distance > c.radius then
			continue
		end
		local b = best
		if b == nil or c.share > b.share or (c.share == b.share and c.distance < b.distance) then
			best = c
		end
	end
	return best
end

-- The part of `amount` a guard with `share` % would take.
function Intercept.part(amount: number, share: number): number
	return amount * math.clamp(share, 0, BuffCategories.caps.intercept) / 100
end

-- How much of `part` the guard may take now, and its updated window.
function Intercept.take(window: Window?, now: number, guardMaxHp: number, part: number): (number, Window)
	local w: Window = if window == nil or now - window.start >= Combat.interceptWindow
		then { start = now, taken = 0 }
		else { start = window.start, taken = window.taken }
	local limit = guardMaxHp * BuffCategories.caps.interceptPerSecond / 100
	local taken = math.max(0, math.min(part, limit - w.taken))
	w.taken += taken
	return taken, w
end

-- One call for the filter: (kept on the target, chosen guard, moved to the guard). Stores the window in
-- windows[chosen.guard].
function Intercept.resolve(
	source: string,
	amount: number,
	candidates: { Candidate },
	windows: { [any]: Window },
	now: number,
	maxHpOf: (guard: any) -> number
): (number, Candidate?, number)
	if not Intercept.applies(source) or amount <= 0 then
		return amount, nil, 0
	end
	local chosen = Intercept.pick(candidates)
	if not chosen then
		return amount, nil, 0
	end
	local moved, window =
		Intercept.take(windows[chosen.guard], now, maxHpOf(chosen.guard), Intercept.part(amount, chosen.share))
	windows[chosen.guard] = window
	return amount - moved, chosen, moved
end

-- S72: the part a guard really takes and the damage sent back to the monster that struck (ROZWOJ 10.3). Martyr
-- (`mitigation` %, interceptMitigation) lowers the guard's part; Retribution (`thorns` %, interceptThorns) returns a
-- share of the moved part, at least 1 while it is on. Both read the part before mitigation, and the per-second
-- window (take) counts that part too.
function Intercept.split(moved: number, mitigation: number, thorns: number): (number, number)
	if moved <= 0 then
		return 0, 0
	end
	local toGuard = moved * (1 - math.clamp(mitigation, 0, 100) / 100)
	local reflected = if thorns > 0 then math.max(1, math.floor(moved * thorns / 100)) else 0
	return toGuard, reflected
end

return Intercept
