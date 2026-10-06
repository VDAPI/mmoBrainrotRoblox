--!strict
-- Day and night clock (S21). Pure: the client computes the time of day from the shared server time
-- (workspace:GetServerTimeNow() + the server's offset attribute), so every player sees the same sky.
-- A cycle starts at dawn (6:00). The day (6:00-19:00, 13 h) takes 1 - nightShare of the cycle and the night
-- (19:00-6:00, 11 h) the rest, so the night is short in real time although it covers 11 hours of the clock.

local DayCycle = {}

DayCycle.DAWN = 6
DayCycle.DUSK = 19
local DAY_HOURS = DayCycle.DUSK - DayCycle.DAWN
local NIGHT_HOURS = 24 - DAY_HOURS

-- Fraction of the cycle (0..1) at `seconds`.
function DayCycle.phase(seconds: number, length: number): number
	return (seconds / length) % 1
end

-- Clock time (0..24) at a cycle fraction.
function DayCycle.clockAt(fraction: number, nightShare: number): number
	local f = fraction % 1
	local dayShare = 1 - nightShare
	if f < dayShare then
		return DayCycle.DAWN + DAY_HOURS * f / dayShare
	end
	return (DayCycle.DUSK + NIGHT_HOURS * (f - dayShare) / nightShare) % 24
end

-- Clock time (0..24) at `seconds` of shared time.
function DayCycle.clock(seconds: number, length: number, nightShare: number): number
	return DayCycle.clockAt(DayCycle.phase(seconds, length), nightShare)
end

-- Cycle fraction at which the clock shows `clock` (inverse of clockAt).
function DayCycle.fractionOf(clock: number, nightShare: number): number
	local c = clock % 24
	local dayShare = 1 - nightShare
	if c >= DayCycle.DAWN and c < DayCycle.DUSK then
		return (c - DayCycle.DAWN) / DAY_HOURS * dayShare
	end
	return dayShare + ((c - DayCycle.DUSK) % 24) / NIGHT_HOURS * nightShare
end

-- Offset (seconds, 0..length) to add to `now` so that the clock shows `clock` (admin /daytime).
function DayCycle.offsetFor(now: number, clock: number, length: number, nightShare: number): number
	local want = DayCycle.fractionOf(clock, nightShare)
	return ((want - DayCycle.phase(now, length)) % 1) * length
end

function DayCycle.isNight(clock: number): boolean
	return clock < DayCycle.DAWN or clock >= DayCycle.DUSK
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- How dark it is: 0 in full day, 1 in full night, blending over 1.5 h around dusk (18:15-19:45) and dawn
-- (5:15-6:45). Drives the lighting blend between a map's day and night presets.
function DayCycle.nightness(clock: number): number
	local c = clock % 24
	if c >= 12 then
		return smooth((c - (DayCycle.DUSK - 0.75)) / 1.5)
	end
	return smooth(((DayCycle.DAWN + 0.75) - c) / 1.5)
end

-- Stable pseudo-random number 0..1 from a position (same window, same answer every night).
function DayCycle.hash(x: number, y: number, z: number): number
	local n = math.sin(math.floor(x * 2) * 12.9898 + math.floor(y * 2) * 78.233 + math.floor(z * 2) * 37.719)
		* 43758.5453
	return n - math.floor(n)
end

-- Whether a window at this position is lit at night (about `share` of all windows, 0.6 by default).
function DayCycle.windowLit(x: number, y: number, z: number, share: number?): boolean
	return DayCycle.hash(x, y, z) < (share or 0.6)
end

return DayCycle
