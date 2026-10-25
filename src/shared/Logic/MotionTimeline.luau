--!strict
-- Template animation: the timeline of a keyed monster action, shared by every family (Logic/BipedMotion,
-- Logic/QuadMotion). A key sits in one of four segments: "A" anticipation (stretched to the server's windup), "S" strike
-- (ends exactly on the server's hit), "F" follow-through, "R" recovery; `u` is its place in the segment, `ease` the curve
-- that reaches it. Poses are control tables (numbers by name) blended by Logic/BipedPose.lerp. Pure.

local BipedPose = require("./BipedPose")

local MotionTimeline = {}

export type Controls = { [string]: number }
export type Key = { seg: string, u: number, ease: string?, pose: Controls }
export type Action = {
	keys: { Key },
	strike: number,
	follow: number,
	recover: number,
	legs: boolean?,
	hold: boolean?,
	travel: boolean?,
	full: boolean?,
	tremble: number?, -- rad of the gather's tremble at the end of the anticipation (grows with its square)
	lag: { [string]: number }?,
}

-- 0..1 eased: "in" accelerates, "out" decelerates, "lin" straight, otherwise smootherstep.
function MotionTimeline.ease(kind: string?, x: number): number
	local t = math.clamp(x, 0, 1)
	if kind == "in" then
		return t * t * t
	elseif kind == "out" then
		local u = 1 - t
		return 1 - u * u * u
	elseif kind == "lin" then
		return t
	end
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- The segments' starts and lengths: the anticipation stretched to the windup, the strike ending on the hit.
function MotionTimeline.segments(action: Action, hit: number): { [string]: { number } }
	local s = math.min(action.strike, hit * 0.7)
	local a = math.max(0, hit - s)
	return {
		A = { 0, a },
		S = { a, s },
		F = { hit, action.follow },
		R = { hit + action.follow, action.recover },
	}
end

function MotionTimeline.length(action: Action, hit: number): number
	return hit + action.follow + action.recover
end

-- The controls at `t` seconds (hit at `hit`) from `startPose`.
function MotionTimeline.at(action: Action, hit: number, t: number, startPose: Controls): Controls
	local seg = MotionTimeline.segments(action, hit)
	local prevT, prevPose = 0, startPose
	for _, key in action.keys do
		local span = seg[key.seg]
		local kt = span[1] + key.u * span[2]
		if t <= kt then
			if kt - prevT < 1e-4 then
				return key.pose
			end
			return BipedPose.lerp(prevPose, key.pose, MotionTimeline.ease(key.ease, (t - prevT) / (kt - prevT)))
		end
		prevT, prevPose = kt, key.pose
	end
	return prevPose
end

-- The gather's progress 0..1 at `t` (the anticipation's share elapsed), for trembles and growing glows.
function MotionTimeline.gather(action: Action, hit: number, t: number): number
	local seg = MotionTimeline.segments(action, hit)
	local a = seg.A[2]
	return if a <= 0 then 0 else math.clamp(t / a, 0, 1)
end

return MotionTimeline
