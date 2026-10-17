--!strict
-- W08: which base clip a player character plays (Data/Locomotion), the walk / run weights and the playback speeds.
-- Pure and deterministic; src/character/Animate feeds it the Humanoid's state each frame.

local Locomotion = require("../Data/Locomotion")

local LocomotionPick = {}

-- The Humanoid state, reduced: what the motion depends on.
export type State = "ground" | "jump" | "fall" | "climb" | "swim" | "seated" | "dead" | "none"

export type Input = {
	state: State,
	speed: number, -- horizontal studs per second (vertical for "climb")
	heightScale: number?, -- the character's height scale (1 = standard)
	airTime: number?, -- seconds since leaving the ground ("jump" / "fall")
	mounted: boolean?,
}

-- "move" = the walk / run blend (see `blend`); "none" = stop every base clip.
export type Clip = "idle" | "move" | "jump" | "fall" | "climb" | "swim" | "swimIdle" | "none"

export type Blend = {
	walk: number, -- weights, sum 1
	run: number,
	walkSpeed: number, -- playback speeds
	runSpeed: number,
}

local function clampRate(rate: number): number
	return math.clamp(rate, Locomotion.blend.rate[1], Locomotion.blend.rate[2])
end

-- The clip for an input.
function LocomotionPick.clip(input: Input): Clip
	local s = input.state
	if s == "dead" or s == "none" then
		return "none"
	elseif input.mounted or s == "seated" then
		return "idle" -- the rider's legs come from Logic/RiderPose on top
	elseif s == "jump" then
		return if (input.airTime or 0) >= Locomotion.air.fallAfter then "fall" else "jump"
	elseif s == "fall" then
		return "fall"
	elseif s == "climb" then
		return "climb"
	elseif s == "swim" then
		return if input.speed > Locomotion.blend.moving then "swim" else "swimIdle"
	end
	return if input.speed / (input.heightScale or 1) > Locomotion.blend.moving then "move" else "idle"
end

-- Walk / run weights and playback speeds at a horizontal speed (studs/s).
function LocomotionPick.blend(speed: number, heightScale: number?): Blend
	local b = Locomotion.blend
	local v = speed / (heightScale or 1)
	local t = math.clamp((v - b.walkUntil) / (b.runFrom - b.walkUntil), 0, 1)
	-- inside the crossfade both clips keep the speed of their ends, so the pose does not jump
	local walkSpeed = clampRate(math.min(v, b.walkUntil) / Locomotion.stride.walk)
	local runSpeed = clampRate(math.max(v, b.runFrom) / Locomotion.stride.run)
	return { walk = 1 - t, run = t, walkSpeed = walkSpeed, runSpeed = runSpeed }
end

-- Playback speed of the climb and swim clips.
function LocomotionPick.rate(clip: Clip, speed: number, heightScale: number?): number
	local v = speed / (heightScale or 1)
	if clip == "climb" then
		return clampRate(math.abs(v) / Locomotion.stride.climb)
	elseif clip == "swim" then
		return clampRate(v / Locomotion.stride.swim)
	end
	return 1
end

-- Whether a landing after falling `height` studs plays the landing clip.
function LocomotionPick.lands(height: number): boolean
	return Locomotion.clips.land ~= "" and height >= Locomotion.air.landHeight
end

-- Seconds until the next idle variant, from a number in [0, 1).
function LocomotionPick.variantDelay(roll: number): number
	local r = Locomotion.idle.variantEvery
	return r[1] + (r[2] - r[1]) * math.clamp(roll, 0, 1)
end

-- Whether an idle variant may start now.
function LocomotionPick.variantAllowed(clip: Clip, idleFor: number, due: number, sinceCombat: number): boolean
	return clip == "idle"
		and idleFor >= due
		and sinceCombat >= Locomotion.idle.combatQuiet
		and #Locomotion.clips.idleVariants > 0
end

-- Crossfade seconds from one clip to another.
function LocomotionPick.fade(from: Clip, to: Clip): number
	local f = Locomotion.fade
	if to == "jump" or to == "fall" then
		return f.air
	elseif from == "idle" and to == "move" then
		return f.start
	elseif from == "move" and to == "idle" then
		return f.stop
	end
	return f.other
end

return LocomotionPick
