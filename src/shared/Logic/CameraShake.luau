--!strict
-- The camera kick in numbers (owner 2026-11-10, skill juice): how far and how long a shake of a strength moves the
-- camera, scaled by the "Hit feel" option (settings.shake 0..1, 0 = none) and the graphics level, and the offset of all
-- running kicks at a moment. Every kick fades as (1 - u)² over its time and wobbles on two sines per axis of its own
-- seed, so two kicks never move in step and the sum stays smooth; the sum is capped. Pure (Vfx/CameraShake writes it
-- into Humanoid.CameraOffset). Tuning in Config.Vfx.shake.

local Config = require("../Config")

local CameraShake = {}

export type Kick = { amp: number, start: number, seconds: number, seed: number }

local TAU = 2 * math.pi
-- Wobble frequencies (Hz) of the two sines of each axis: fast enough to read as a jolt, not a sway.
local FX = { 21, 13 }
local FY = { 17, 29 }

-- The strength of a kick as given (bosses 0.3-1, our big blows 0.3-0.8), clamped.
local function clampStrength(strength: number): number
	return math.clamp(strength, 0, Config.Vfx.shake.maxStrength)
end

-- Studs a kick of `strength` moves the camera at most, with the "Hit feel" option `setting` (0..1; nil or not a number
-- = 1) at the graphics level `quality` (low / medium / high; unknown = high). 0 = no kick.
function CameraShake.amp(strength: number, setting: any, quality: any): number
	local cfg = Config.Vfx.shake
	local feel = if type(setting) == "number" then math.clamp(setting, 0, 1) else 1
	local level = (if type(quality) == "string" then cfg.level[quality] else nil) or cfg.level.high
	return clampStrength(strength) * cfg.studs * feel * level
end

-- Seconds a kick of `strength` lasts (a bigger blow rings longer).
function CameraShake.seconds(strength: number): number
	local cfg = Config.Vfx.shake
	return cfg.base + cfg.per * clampStrength(strength)
end

-- How much of a kick is left `t` seconds after its start (1 at the start, 0 at its end and after).
function CameraShake.envelope(kick: Kick, t: number): number
	if t < 0 or kick.seconds <= 0 or t >= kick.seconds then
		return 0
	end
	local u = 1 - t / kick.seconds
	return u * u
end

-- The camera offset (x, y in studs) of every kick at `now`; each axis capped at Config.Vfx.shake.maxStuds.
function CameraShake.offset(kicks: { Kick }, now: number): (number, number)
	local x, y = 0, 0
	for _, kick in kicks do
		local t = now - kick.start
		local e = CameraShake.envelope(kick, t)
		if e > 0 then
			local a = kick.amp * e
			local s = kick.seed
			x += a * (0.65 * math.sin(TAU * FX[1] * t + s) + 0.35 * math.sin(TAU * FX[2] * t + s * 1.7))
			y += a * (0.65 * math.sin(TAU * FY[1] * t + s * 2.3) + 0.35 * math.sin(TAU * FY[2] * t + s * 0.6))
		end
	end
	local cap = Config.Vfx.shake.maxStuds
	return math.clamp(x, -cap, cap), math.clamp(y, -cap, cap)
end

-- Drops the kicks that ended by `now` (in place); returns how many are left.
function CameraShake.prune(kicks: { Kick }, now: number): number
	for i = #kicks, 1, -1 do
		local kick = kicks[i]
		if now - kick.start >= kick.seconds then
			table.remove(kicks, i)
		end
	end
	return #kicks
end

return CameraShake
