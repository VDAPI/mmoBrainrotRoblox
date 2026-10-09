--!strict
-- Procedural attack poses of characters (S22, DESIGN §24). Pure: the motion for a weapon type, its timing
-- (squeezed into the attack interval when that is shorter) and the pose at time t. The client
-- (AnimationController) turns the angles into Motor6D transforms on top of the default animations.
-- A pose always starts at rest (or at `from`, the pose an interrupted attack had reached) and ends at rest,
-- so attacks blend into walking and into each other without jumps.

local AttackMotions = require("../Data/AttackMotions")

local AttackPose = {}

export type Joint = AttackMotions.Joint
export type Pose = AttackMotions.Pose
export type MotionName = AttackMotions.MotionName
export type Phase = "windup" | "strike" | "recover" | "rest"

export type Timing = {
	windup: number,
	strike: number,
	recover: number,
	total: number,
	hitAt: number, -- seconds after the start when the blow lands / the shot leaves
	ranged: boolean,
}

local ZERO = { 0, 0, 0 }

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
-- the blow, or the release plus the flight (FIX 2026-10-09: the server waits this long before the damage).
function AttackPose.hitDelay(weaponType: string?, distance: number, ranged: boolean): number
	local motion = AttackPose.motionFor(weaponType)
	local timing = AttackPose.timing(motion)
	local kind = AttackPose.projectile(motion)
	if ranged and kind then
		return timing.hitAt + AttackPose.flightTime(kind, distance)
	end
	return timing.hitAt
end

-- Timing of a motion; with `interval` (seconds between attacks) shorter than the motion, every phase shrinks
-- by the same factor (never below 40%).
function AttackPose.timing(name: MotionName, interval: number?): Timing
	local m = AttackMotions.motions[name]
	local total = m.windup + m.strike + m.recover
	local k = if interval and interval > 0 and interval < total then math.max(0.4, interval / total) else 1
	local windup, strike, recover = m.windup * k, m.strike * k, m.recover * k
	return {
		windup = windup,
		strike = strike,
		recover = recover,
		total = windup + strike + recover,
		hitAt = windup + strike * m.hit,
		ranged = m.ranged,
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

local function angles(pose: Pose?, joint: Joint): { number }
	return (pose and pose[joint]) or ZERO
end

local function mix(a: { number }, b: { number }, t: number): { number }
	return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t }
end

-- Pose (degrees per joint, every joint present), phase and weight at `t` seconds after the start. The weight
-- (0..1) says how much the attack owns the arms and the waist: it rises over the first part of the windup
-- (at once when blending from an interrupted attack) and falls during the recovery.
function AttackPose.sample(name: MotionName, t: number, interval: number?, from: Pose?): (Pose, Phase, number)
	local m = AttackMotions.motions[name]
	local timing = AttackPose.timing(name, interval)
	local out: Pose = {}
	local phase: Phase
	local weight: number
	if t < 0 or t >= timing.total then
		for _, joint in AttackMotions.JOINTS do
			out[joint] = { 0, 0, 0 }
		end
		return out, "rest", 0
	end
	if t < timing.windup then
		local k = smooth(t / timing.windup)
		for _, joint in AttackMotions.JOINTS do
			out[joint] = mix(angles(from, joint), angles(m.poses.windup, joint), k)
		end
		phase = "windup"
		weight = if from then 1 else math.clamp(t / (timing.windup * 0.3), 0, 1)
	elseif t < timing.windup + timing.strike then
		local k = easeOut((t - timing.windup) / timing.strike)
		for _, joint in AttackMotions.JOINTS do
			out[joint] = mix(angles(m.poses.windup, joint), angles(m.poses.strike, joint), k)
		end
		phase = "strike"
		weight = 1
	else
		local k = smooth((t - timing.windup - timing.strike) / timing.recover)
		for _, joint in AttackMotions.JOINTS do
			out[joint] = mix(angles(m.poses.strike, joint), ZERO, k)
		end
		phase = "recover"
		weight = 1 - k
	end
	return out, phase, weight
end

return AttackPose
