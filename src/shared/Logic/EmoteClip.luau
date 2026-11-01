--!strict
-- 2026-11-01: which emotes play a real animation clip and how (Data/Emotes `clip`). Pure: client/Anim/CharacterClips
-- loads and plays the track, AnimationController.Emote decides between the clip and the procedural motion. An emote
-- plays its clip only when the track has loaded on the character's Animator (R15); until then, and for good when it
-- fails, the motion plays as before. A clip emote ends like the motion: a short one when its track ends, a looping one
-- at Emotes.MAX_SECONDS; any emote ends when its character moves, attacks or casts.

local Emotes = require("../Data/Emotes")

local EmoteClip = {}

EmoteClip.FADE_IN = 0.15 -- seconds the clip blends in over the idle
EmoteClip.FADE_OUT_MIN = 0.1 -- the shortest blend out (the motion's `recover` is the usual one)
EmoteClip.MOVE_SPEED = 2 -- studs/s of the root, horizontally: the character walks (an emote ends, EmoteController)
EmoteClip.FALL_SPEED = 8 -- studs/s of the root, vertically: it jumps or falls

export type Plan = {
	id: string, -- "rbxassetid://<n>"
	looped: boolean, -- the track repeats until the emote ends (the motion has a `loop`)
	fadeIn: number,
	fadeOut: number,
}

-- The clip's asset id of an emote, or nil when it has none (nil, 0, not a positive whole number: procedural).
function EmoteClip.id(emote: Emotes.Emote): string?
	local clip = emote.clip
	if type(clip) ~= "number" or not (clip > 0 and clip < 2 ^ 53) or clip % 1 ~= 0 then
		return nil
	end
	return string.format("rbxassetid://%d", clip)
end

-- How the clip of an emote plays (nil: the emote is procedural only).
function EmoteClip.plan(emote: Emotes.Emote): Plan?
	local id = EmoteClip.id(emote)
	if not id then
		return nil
	end
	return {
		id = id,
		looped = emote.motion.loop ~= nil,
		fadeIn = EmoteClip.FADE_IN,
		fadeOut = math.max(emote.motion.recover, EmoteClip.FADE_OUT_MIN),
	}
end

-- Whether a root moving at (vx, vy, vz) studs/s counts as moving: walking, jumping or falling.
function EmoteClip.moving(vx: number, vy: number, vz: number): boolean
	return math.sqrt(vx * vx + vz * vz) > EmoteClip.MOVE_SPEED or math.abs(vy) > EmoteClip.FALL_SPEED
end

export type Where = {
	r15: boolean, -- the clips are R15 animations; an R6 rig keeps the motion
	near: boolean, -- close enough to the camera to animate at all (Config.EffectRadius)
	moving: boolean, -- EmoteClip.moving
}

-- Whether an emote starts on its clip: it has one (`plan`), the rig is R15, the character is near and stands. A moving
-- one keeps the motion, which moves only the arms and the waist over the walk (a clip would end at once: an emote ends
-- when its character moves). The caller still falls back to the motion while the track loads or when it failed.
function EmoteClip.useClip(plan: Plan?, where: Where): boolean
	return plan ~= nil and where.r15 and where.near and not where.moving
end

-- Every clip id of a list of emotes (default Data/Emotes), once each, sorted: the client preloads them.
function EmoteClip.ids(list: { Emotes.Emote }?): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	for _, emote in list or Emotes.list do
		local id = EmoteClip.id(emote)
		if id and not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

return EmoteClip
