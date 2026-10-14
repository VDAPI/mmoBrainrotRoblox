--!strict
-- Procedural attack poses of characters (S22, DESIGN §24; S113 combos and contact poses, DESIGN-16 §5). Pure: the
-- motion for a weapon type, the server's hit time (Data/AttackMotions.SERVER_HIT, AttackPose.hitDelay), the timing of
-- a combo step (squeezed into the attack interval when that is shorter) and the pose at time t. The client
-- (AnimationController) turns the angles into Motor6D transforms on top of the default animations.
-- A pose always starts at rest (or at `from`, the pose an interrupted attack had reached) and ends at rest,
-- so attacks blend into walking and into each other without jumps.
-- S113 curves of a step: rest -> windup `smooth`; windup -> pass accelerating (t², the fastest at the contact =
-- SERVER_HIT); pass -> strike decelerating (a cubic that starts at the speed of an ease-out and ends at the speed the
-- follow-through starts with, so the overshoot flows on); strike -> follow ease-out; follow -> rest `smooth`.
-- Steps without `pass` cut windup -> strike with an ease-out (S22); without `follow` they return straight to rest.

local AttackMotions = require("../Data/AttackMotions")
local ClipFit = require("./ClipFit")

local AttackPose = {}

export type Joint = AttackMotions.Joint
export type Pose = AttackMotions.Pose
export type MotionName = AttackMotions.MotionName
export type Step = AttackMotions.Step
export type Phase = "windup" | "strike" | "recover" | "rest"

export type Timing = {
	windup: number,
	strike: number,
	recover: number,
	total: number,
	hitAt: number, -- seconds after the start when the blow lands / the shot leaves (SERVER_HIT, squeezed with the rest)
	hit: number, -- 0..1 of the strike phase at hitAt (derived)
	followAt: number, -- end of the follow-through (MotionKeys `follow`)
	ranged: boolean,
	step: number,
}

-- The last basic attack of a character as the combo remembers it (client).
export type ComboState = { motion: MotionName, step: number, at: number }

local ZERO = { 0, 0, 0 }
local FOLLOW_KEY_SHARE = 0.3 -- MotionKeys `follow` of a step without a follow pose (S110)

-- Motion of a weapon item type ("unarmed" without a weapon or for unknown types).
function AttackPose.motionFor(weaponType: string?): MotionName
	return if weaponType then AttackMotions.byWeapon[weaponType] or "unarmed" else "unarmed"
end

-- Projectile a ranged motion shoots ("arrow", "bolt" or "magic"); nil for melee motions.
function AttackPose.projectile(name: MotionName): string?
	if not AttackMotions.motions[name].ranged then
		return nil
	end
	return if name == "bow" then "arrow" elseif name == "crossbow" then "bolt" else "magic"
end

-- Seconds a basic attack projectile of `kind` flies over `distance` studs (client flight and server hit agree).
function AttackPose.flightTime(kind: string, distance: number): number
	local speed = if kind == "bolt" then 150 elseif kind == "arrow" then 110 else 85
	return math.clamp(distance / speed, 0.06, 0.4)
end

-- Seconds from the start of a basic attack with `weaponType` until it lands on a target `distance` studs away:
-- the blow, or the release plus the flight (FIX 2026-10-09: the server waits this long before the damage; S113: the
-- time comes from AttackMotions.SERVER_HIT, the same numbers as before, never from a pose).
function AttackPose.hitDelay(weaponType: string?, distance: number, ranged: boolean): number
	local motion = AttackPose.motionFor(weaponType)
	local hitAt = AttackMotions.SERVER_HIT[motion]
	local kind = AttackPose.projectile(motion)
	if ranged and kind then
		return hitAt + AttackPose.flightTime(kind, distance)
	end
	return hitAt
end

-- Steps of a motion's combo: the clips of the weapon type when it has any (Logic/ClipFit), else the pose steps.
function AttackPose.stepCount(name: MotionName, weaponType: string?): number
	if weaponType ~= nil and AttackPose.motionFor(weaponType) == name then
		local clips = ClipFit.attackClips(weaponType)
		if clips then
			return math.min(#clips, ClipFit.MAX_CLIPS)
		end
	else
		local clips = AttackMotions.motions[name].clips
		if clips and #clips > 0 then
			return math.min(#clips, ClipFit.MAX_CLIPS)
		end
	end
	return #AttackMotions.motions[name].steps
end

-- Step `i` of a motion (wraps around: a combo of clips may be longer than the pose steps behind it).
function AttackPose.step(name: MotionName, i: number?): Step
	local steps = AttackMotions.motions[name].steps
	local index = ((math.max(1, math.floor(i or 1)) - 1) % #steps) + 1
	return steps[index]
end

-- The combo step of a new attack: 1 when there was none, it was another motion, it started more than COMBO_WINDOW
-- seconds ago or the motion has one step; else the next step after the previous one (round).
function AttackPose.nextStep(prev: ComboState?, name: MotionName, now: number, count: number): number
	if prev == nil or prev.motion ~= name or now - prev.at > AttackMotions.COMBO_WINDOW or count <= 1 then
		return 1
	end
	return prev.step % count + 1
end

-- Timing of a combo step (default 1); with `interval` (seconds between attacks) shorter than the step, every phase
-- and the hit time shrink by the same factor (never below 40%).
function AttackPose.timing(name: MotionName, interval: number?, step: number?): Timing
	local m = AttackMotions.motions[name]
	local s = AttackPose.step(name, step)
	local total = s.windup + s.strike + s.recover
	local k = if interval and interval > 0 and interval < total then math.max(0.4, interval / total) else 1
	local windup, strike, recover = s.windup * k, s.strike * k, s.recover * k
	local hitAt = AttackMotions.SERVER_HIT[name] * k
	local share = if s.poses.follow then s.follow or AttackMotions.FOLLOW_SHARE else FOLLOW_KEY_SHARE
	return {
		windup = windup,
		strike = strike,
		recover = recover,
		total = windup + strike + recover,
		hitAt = hitAt,
		hit = if strike > 0 then math.clamp((hitAt - windup) / strike, 0, 1) else 0,
		followAt = windup + strike + share * recover,
		ranged = m.ranged,
		step = (((math.max(1, math.floor(step or 1)) - 1) % #m.steps) + 1),
	}
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function easeOut(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

local function easeIn(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t
end

local function angles(pose: Pose?, joint: Joint): { number }
	return (pose and pose[joint]) or ZERO
end

local function mix(a: { number }, b: { number }, t: number): { number }
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Cubic Hermite from a to b over `seconds` with start velocity v0 and end velocity v1 (degrees per second) at u in
-- [0, 1], per value.
local function hermite(
	a: { number },
	b: { number },
	v0: { number },
	v1: { number },
	seconds: number,
	u: number
): { number }
	u = math.clamp(u, 0, 1)
	local u2, u3 = u * u, u * u * u
	local h00 = 2 * u3 - 3 * u2 + 1
	local h10 = u3 - 2 * u2 + u
	local h01 = -2 * u3 + 3 * u2
	local h11 = u3 - u2
	local out = {}
	for i = 1, 3 do
		out[i] = h00 * a[i] + h10 * seconds * v0[i] + h01 * b[i] + h11 * seconds * v1[i]
	end
	return out
end

local function velocity(a: { number }, b: { number }, factor: number): { number }
	return { (b[1] - a[1]) * factor, (b[2] - a[2]) * factor, (b[3] - a[3]) * factor }
end

-- Pose (degrees per joint, every joint present), phase and weight at `t` seconds after the start of combo step
-- `step` (default 1). The weight (0..1) says how much the attack owns the arms and the waist: it rises over the first
-- part of the windup (at once when blending from an interrupted attack), stays 1 through the follow-through and falls
-- during the return to rest.
function AttackPose.sample(
	name: MotionName,
	t: number,
	interval: number?,
	from: Pose?,
	step: number?
): (Pose, Phase, number)
	local s = AttackPose.step(name, step)
	local poses = s.poses
	local timing = AttackPose.timing(name, interval, step)
	local out: Pose = {}
	local phase: Phase
	local weight: number
	if t < 0 or t >= timing.total then
		for _, joint in AttackMotions.JOINTS do
			out[joint] = { 0, 0, 0 }
		end
		return out, "rest", 0
	end
	local strikeEnd = timing.windup + timing.strike
	local followPose = poses.follow
	local followSeconds = if followPose then (s.follow or AttackMotions.FOLLOW_SHARE) * timing.recover else 0
	if t < timing.windup then
		local k = smooth(t / timing.windup)
		for _, joint in AttackMotions.JOINTS do
			out[joint] = mix(angles(from, joint), angles(poses.windup, joint), k)
		end
		phase = "windup"
		weight = if from then 1 else math.clamp(t / (timing.windup * 0.3), 0, 1)
	elseif t < strikeEnd then
		local pass = poses.pass
		local toPass = timing.hitAt - timing.windup
		local fromPass = strikeEnd - timing.hitAt
		if pass and toPass > 1e-6 and fromPass > 1e-6 then
			if t < timing.hitAt then
				local k = easeIn((t - timing.windup) / toPass)
				for _, joint in AttackMotions.JOINTS do
					out[joint] = mix(angles(poses.windup, joint), angles(pass, joint), k)
				end
			else
				-- leaves the contact at an ease-out's speed and arrives with the follow-through's starting speed
				local u = (t - timing.hitAt) / fromPass
				for _, joint in AttackMotions.JOINTS do
					local a, b = angles(pass, joint), angles(poses.strike, joint)
					local v0 = velocity(a, b, 2 / fromPass)
					local v1 = if followPose and followSeconds > 1e-6
						then velocity(b, angles(followPose, joint), 2 / followSeconds)
						else ZERO
					out[joint] = hermite(a, b, v0, v1, fromPass, u)
				end
			end
		else
			local k = easeOut((t - timing.windup) / timing.strike)
			for _, joint in AttackMotions.JOINTS do
				out[joint] = mix(angles(poses.windup, joint), angles(poses.strike, joint), k)
			end
		end
		phase = "strike"
		weight = 1
	else
		local back = t - strikeEnd
		if followPose and back < followSeconds then
			local k = easeOut(back / followSeconds)
			for _, joint in AttackMotions.JOINTS do
				out[joint] = mix(angles(poses.strike, joint), angles(followPose, joint), k)
			end
			weight = 1
		else
			local last = followPose or poses.strike
			local k = smooth((back - followSeconds) / (timing.recover - followSeconds))
			for _, joint in AttackMotions.JOINTS do
				out[joint] = mix(angles(last, joint), ZERO, k)
			end
			weight = 1 - k
		end
		phase = "recover"
	end
	return out, phase, weight
end

-- The strength of a hit reaction: 1 for a normal hit, FLINCH.critDegrees / degrees for a critical one.
function AttackPose.flinchStrength(crit: boolean?): number
	local f = AttackMotions.FLINCH
	return if crit then f.critDegrees / f.degrees else 1
end

-- A hit character's reaction at `t` seconds (S113, looks only): `push` is the direction of the blow in the
-- character's own frame (x to the right, z to the back; the front is -Z), unit length; the waist leans away from the
-- blow (back when struck from the front, sideways from the struck side), the arms swing a little back. Envelope
-- sin(pi * t / FLINCH.seconds), zero outside; `strength` scales FLINCH.degrees (flinchStrength).
function AttackPose.flinch(push: { x: number, z: number }, strength: number, t: number): Pose
	local f = AttackMotions.FLINCH
	local envelope = if t <= 0 or t >= f.seconds then 0 else math.sin(math.pi * t / f.seconds)
	local deg = f.degrees * strength * envelope
	local arms = -push.z * deg * f.shoulder
	return {
		waist = { push.z * deg, 0, -push.x * deg },
		rShoulder = { arms, 0, 0 },
		lShoulder = { arms, 0, 0 },
	}
end

return AttackPose
