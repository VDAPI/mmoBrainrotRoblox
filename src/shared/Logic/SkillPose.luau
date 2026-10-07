--!strict
-- Skill animation poses (S28). Pure: the pose of a Data/SkillMotions motion at time t — keys interpolated with
-- their easing, entered smoothly from `from` (the pose a previous motion or attack had reached) or from rest, a
-- channel stretch looped while the channel lasts, and a return to rest after the last key. The client
-- (AnimationController) turns the degrees into Motor6D transforms; tests check every motion.

local SkillMotions = require("../Data/SkillMotions")

local SkillPose = {}

export type Pose = SkillMotions.Pose
export type Motion = SkillMotions.Motion

export type Options = {
	speed: number?, -- > 1 plays faster
	from: Pose?, -- the pose to blend in from (default rest)
	loopUntil: number?, -- channel: the loop stretch repeats until this many seconds after the start
}

local function size(joint: string): number
	return SkillMotions.SIZE[joint] or 3
end

local function zero(joint: string): { number }
	return table.create(size(joint), 0)
end

local function ease(kind: SkillMotions.Ease?, t: number): number
	t = math.clamp(t, 0, 1)
	if kind == "linear" then
		return t
	elseif kind == "in" then
		return t * t
	elseif kind == "out" then
		return 1 - (1 - t) * (1 - t)
	end
	return t * t * (3 - 2 * t) -- inOut (default)
end

local function value(pose: Pose?, joint: string): { number }
	local v = pose and pose[joint]
	if v then
		return v
	end
	return zero(joint)
end

local function mix(a: { number }, b: { number }, t: number, n: number): { number }
	local out = table.create(n, 0)
	for i = 1, n do
		local x, y = a[i] or 0, b[i] or 0
		out[i] = x + (y - x) * t
	end
	return out
end

-- Joints a motion moves (present in any key).
local jointCache: { [Motion]: { string } } = {}
function SkillPose.joints(motion: Motion): { string }
	local cached = jointCache[motion]
	if cached then
		return cached
	end
	local seen: { [string]: boolean } = {}
	local list = {}
	for _, key in motion.keys do
		for joint in key.pose do
			if not seen[joint] then
				seen[joint] = true
				table.insert(list, joint)
			end
		end
	end
	table.sort(list)
	jointCache[motion] = list
	return list
end

-- Length of a motion in seconds at speed 1 (with a channel: `loopUntil` stretches it).
function SkillPose.duration(motion: Motion, loopUntil: number?): number
	local last = motion.keys[#motion.keys].t
	local loop = motion.loop
	if loop and loopUntil and loopUntil > loop.to then
		last += loopUntil - loop.to
	end
	return last + motion.recover
end

-- Motion time for real time t (channel loop).
local function motionTime(motion: Motion, t: number, loopUntil: number?): number
	local loop = motion.loop
	if not loop or not loopUntil or t <= loop.to then
		return t
	end
	if t < loopUntil then
		local span = loop.to - loop.from
		return loop.from + ((t - loop.from) % span)
	end
	return loop.to + (t - loopUntil)
end

-- Pose (every joint the motion moves), weight 0..1 (how much the skill owns those joints over the default
-- animation) and whether the motion is over, `t` seconds after the start.
function SkillPose.sample(motion: Motion, t: number, options: Options?): (Pose, number, boolean)
	local speed = if options and options.speed and options.speed > 0 then options.speed else 1
	local from = options and options.from
	local loopUntil = options and options.loopUntil
	local joints = SkillPose.joints(motion)
	local out: Pose = {}
	local time = motionTime(motion, t * speed, loopUntil and loopUntil * speed)
	local keys = motion.keys
	local last = keys[#keys]
	local done = t * speed >= SkillPose.duration(motion, loopUntil and loopUntil * speed)
	if t < 0 or done then
		for _, joint in joints do
			out[joint] = zero(joint)
		end
		return out, 0, done
	end
	local weight = 1
	if time <= keys[1].t then
		local u = ease(keys[1].ease, time / keys[1].t)
		for _, joint in joints do
			out[joint] = mix(value(from, joint), value(keys[1].pose, joint), u, size(joint))
		end
		if not from then
			weight = math.clamp(time / (keys[1].t * 0.4), 0, 1)
		end
	elseif time <= last.t then
		local i = 1
		while keys[i + 1] and keys[i + 1].t < time do
			i += 1
		end
		local a, b = keys[i], keys[i + 1]
		if not b then
			for _, joint in joints do
				out[joint] = value(a.pose, joint)
			end
		else
			local u = ease(b.ease, (time - a.t) / math.max(1e-4, b.t - a.t))
			for _, joint in joints do
				out[joint] = mix(value(a.pose, joint), value(b.pose, joint), u, size(joint))
			end
		end
	else
		local u = ease("inOut", (time - last.t) / motion.recover)
		for _, joint in joints do
			local from = value(last.pose, joint)
			if joint == "root" then
				-- A spin or a flip ends where it started: come back the short way (720° -> 0° is no turn at all).
				from = table.clone(from)
				for i = 1, 3 do
					local a = from[i] or 0
					from[i] = a - 360 * math.floor(a / 360 + 0.5)
				end
			end
			out[joint] = mix(from, zero(joint), u, size(joint))
		end
		weight = 1 - u
	end
	return out, weight, false
end

-- Seconds after the start of an event ("hit" / "release" / "land"), scaled by the speed; nil when absent.
function SkillPose.event(motion: Motion, name: string, speed: number?): number?
	local t = (motion :: any)[name]
	if type(t) ~= "number" then
		return nil
	end
	return t / (if speed and speed > 0 then speed else 1)
end

return SkillPose
