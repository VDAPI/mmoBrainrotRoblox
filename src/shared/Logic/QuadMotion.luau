--!strict
-- Template animation (docs/ANIM-WZORCE.md F2): the motion of an imported quadruped in layers, from the bottom:
-- 1. locomotion synthesised from the gait tables of its style (walk, trot, gallop: footfall order, duty, stride, body
--    bob and pitch, spine flex, head counter-pitch, tail): one phase advanced by distance, so the feet keep pace with
--    the ground speed; the gaits blend by speed over leg length; stepping on the spot while turning;
-- 2. idle: breathing, weight shift, looking around, the tail's lazy sway, ear flicks and fidgets (sniffing, a head
--    shake); the fighting stance (head low and forward, tail level) while it fights, calm and low while it goes home;
-- 3. keyed actions (Logic/MotionTimeline: anticipation stretched to the server's windup, the strike ending on its hit)
--    with the gather's tremble; head yaw mirrored on every other blow;
-- 4. additive reactions: the flinch by side, the lean into turns, the head looking at the target.
-- The heavy quadrupeds (bear, boar, mammoth) add: feet planted by Logic/QuadPose's foot solver along a foot planner
-- (stance: the foot slides back at exactly the ground speed; swing: a lifted path to the next touchdown), plantigrade
-- feet kept flat, a roll about the feet that bear the weight, a trunk swinging like a pendulum behind the head, ears
-- fanning, a gait forced by an action (a charge gallops at the dash's speed).
-- Pure: client/Anim/QuadRig writes the bones, AnimLab evaluates it at a fixed time. The functions the game calls have
-- the names and arguments of Logic/BipedMotion's (step, pick, death, side, length, controlsAt, times).

local MotionTimeline = require("./MotionTimeline")
local NpcPose = require("./NpcPose")
local QuadPose = require("./QuadPose")
local QuadStyles = require("../Data/QuadStyles")

local QuadMotion = {}

type Vec = { number }
type Controls = QuadPose.Controls

export type ActionRun = { name: string, start: number, hit: number, reach: Vec?, mirror: boolean? }
export type Input = {
	now: number,
	dt: number,
	speed: number,
	yawRate: number,
	combat: boolean,
	returning: boolean?,
	action: ActionRun?,
	hitAt: number?,
	hitSide: string?,
	look: Vec?,
	snap: boolean?,
}
export type Instance = {
	skel: QuadPose.Skeleton,
	style: QuadStyles.Style,
	seed: number,
	rate: number,
	phase: number,
	weights: { [string]: number }, -- gait weights
	move: number,
	combat: number,
	calm: number,
	look: number,
	lookYaw: number,
	lookPitch: number,
	fidget: ActionRun?,
	nextFidget: number,
	lastAction: number,
	lastTime: number,
	planted: boolean, -- a gait plants its feet (the foot keys blend with the action like the leg keys)
	center: { [string]: number }, -- per leg: the stance's centre under the hip or shoulder (QuadMotion.gaitControls)
	trunkReady: boolean,
	trunkS: number, -- the trunk pendulum: where its tip hangs (side, forward; leg lengths) and how fast it swings
	trunkSV: number,
	trunkF: number,
	trunkFV: number,
}

local function hash01(n: number, seed: number): number
	return NpcPose.hash01(n, seed)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function add(into: Controls, key: string, v: number)
	into[key] = (into[key] or 0) + v
end

local function addAll(into: Controls, from: Controls, k: number)
	for key, v in from do
		into[key] = (into[key] or 0) + v * k
	end
end

function QuadMotion.new(skel: QuadPose.Skeleton, styleId: string, seed: number): Instance?
	local style = QuadStyles.get(styleId)
	if not style then
		return nil
	end
	local planted = false
	for _, g in style.gaits do
		if g.plant or g.level then
			planted = true
		end
	end
	-- a planted stance is centred under the leg's top joint (the leg upright at mid-stance), not on the rest foot
	local center: { [string]: number } = {}
	for side, chain in skel.chains do
		local top = skel.bones[chain.top].pos
		center[side] = (top[3] - chain.foot[3]) / skel.L
	end
	return {
		skel = skel,
		style = style,
		seed = seed,
		rate = 1 + (hash01(2, seed) * 2 - 1) * style.rate,
		phase = hash01(3, seed),
		weights = { walk = 1 },
		move = 0,
		combat = 0,
		calm = 0,
		look = 0,
		lookYaw = 0,
		lookPitch = 0,
		fidget = nil,
		nextFidget = 4 + hash01(4, seed) * 6,
		lastAction = -math.huge,
		lastTime = 0,
		planted = planted,
		center = center,
		trunkReady = false,
		trunkS = 0,
		trunkSV = 0,
		trunkF = 0,
		trunkFV = 0,
	}
end

---------------------------------------------------------------- locomotion

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Control names per leg (no string building per frame).
local LEG_KEYS: { [string]: { k: string, y: string, z: string, l: string } } = {}
for _, leg in { "FL", "FR", "HL", "HR" } do
	LEG_KEYS[leg] = { k = leg .. "k", y = leg .. "y", z = leg .. "z", l = leg .. "l" }
end
-- A gait forced by an action, as weights.
local FORCED: { [string]: { [string]: number } } = {
	walk = { walk = 1, trot = 0, gallop = 0 },
	trot = { walk = 0, trot = 1, gallop = 0 },
	gallop = { walk = 0, trot = 0, gallop = 1 },
}
-- The body's own motion in a gait, kept under an action that runs the gait (a charge).
local GAIT_BODY = { "by", "bpitch", "broll", "sflex", "syaw" }

-- The gait weights at `ratio` (speed over leg length): a crossfade band around each threshold.
local function gaitWeights(style: QuadStyles.Style, ratio: number): { [string]: number }
	local t = style.thresholds
	local band = 0.35
	local trot = smooth((ratio - (t.trot - band)) / (2 * band))
	local gallop = smooth((ratio - (t.gallop - band)) / (2 * band))
	return { walk = 1 - trot, trot = trot * (1 - gallop), gallop = gallop }
end

-- One gait's controls at `phase` (0..1).
-- `center`: per leg, where its stance is centred (leg lengths behind the foot's rest point: under the hip or shoulder).
local function gaitControls(
	style: QuadStyles.Style,
	name: string,
	phase: number,
	center: { [string]: number }
): Controls
	local g = style.gaits[name]
	local out: Controls = {}
	local A = math.asin(math.clamp(g.duty * g.k / 2, 0.15, 0.6))
	for leg, offset in g.foot do
		local front = string.sub(leg, 1, 1) == "F"
		local duty = if front then (g.dutyFront or g.duty) else g.duty
		local p = (phase - offset) % 1
		local u, f, paw
		if p < duty then
			local s = p / duty
			u = A * (1 - 2 * s)
			f = g.foldStance * math.sin(math.pi * s)
			paw = 0
		else
			local q = (p - duty) / (1 - duty)
			u = -A + 2 * A * smooth(q)
			local bump = math.sin(math.pi * math.clamp(q / 0.85, 0, 1))
			f = (if front then g.foldFront else g.foldHind) * bump
			paw = (if front then g.pawFront else g.pawHind) * bump
		end
		out[leg .. "u"] = u
		out[leg .. "f"] = f
		out[leg .. "p"] = paw
	end
	local w = 2 * math.pi * phase
	-- body: bob twice a cycle (walk / trot) or the gallop's rise and pitch; carried lower by `drop`
	if name == "gallop" then
		out.by = g.bob * math.cos(2 * math.pi * (phase - 0.9)) - (g.drop or 0)
		out.bpitch = g.pitch * math.cos(2 * math.pi * (phase - 0.15))
		out.sflex = g.flex * math.cos(2 * math.pi * (phase - 0.9)) - g.flex * 0.25
	else
		out.by = -g.bob * math.cos(2 * w) - (g.drop or 0)
		out.bpitch = 0
		out.broll = g.roll * math.sin(w)
		out.syaw = g.spineYaw * math.sin(w)
	end
	-- the feet: planted in stance (the solver keeps them on the ground while the body moves over them), lifted along a
	-- path to the next touchdown in swing (leaving and landing at the ground speed); plantigrade feet flat until the
	-- heel peels off late in the stance
	if g.plant or g.level then
		for leg, offset in g.foot do
			local front = string.sub(leg, 1, 1) == "F"
			local duty = if front then (g.dutyFront or g.duty) else g.duty
			local p = (phase - offset) % 1
			local keys = LEG_KEYS[leg]
			local stance = p < duty
			local s = p / duty
			local q = (p - duty) / (1 - duty)
			if g.plant then
				local D = duty * g.k
				local c0 = center[leg] or 0
				if stance then
					out[keys.y], out[keys.z] = 0, c0 - D / 2 + D * s
				else
					local lift = if front then (g.liftFront or g.lift or 0.12) else (g.lift or 0.12)
					-- Hermite from the lift-off point to the touchdown point, leaving and landing with part of the
					-- stance's speed
					local m = D * math.min((1 - duty) / duty, 1) * 0.6
					local q2, q3 = q * q, q * q * q
					local z = (2 * q3 - 3 * q2 + 1) * (D / 2)
						+ (q3 - 2 * q2 + q) * m
						+ (-2 * q3 + 3 * q2) * (-D / 2)
						+ (q3 - q2) * m
					out[keys.y], out[keys.z] = lift * math.sin(math.pi * q ^ 0.76), c0 + z
				end
				out[keys.k] = 1
			end
			if g.level then
				out[keys.l] = g.level * (if stance then 1 - smooth((s - 0.6) / 0.4) else smooth((q - 0.6) / 0.4))
			end
		end
	end
	if name ~= "gallop" then
		-- a heavy walk: the roll turns about the feet that bear the weight, the head sways with the steps
		if g.rollPivot then
			out.bpx = -g.rollPivot * math.sin(w)
		end
		if g.headSway then
			out.hyaw = g.headSway * math.sin(w - 0.8)
		end
	end
	-- the head keeps level against the body's pitch; the tail
	out.npitch = (out.bpitch or 0) * 0.8 + g.neck
	out.tpitch = g.tail
	for i = 1, 4 do
		out["tY" .. i] = g.tailSway * math.sin(w - i * 0.95)
	end
	return out
end

-- `forced`: the gait an action runs (blended in fast); `extra`: ground speed of a flight the pose draws itself.
local function locomotion(inst: Instance, input: Input, forced: string?, extra: number): Controls
	local style = inst.style
	local L = inst.skel.L
	local dt = input.dt
	local speed = input.speed + extra
	local turning = speed < 0.3 * L and math.abs(input.yawRate) > 1
	local moving = speed >= 0.3 * L
	local ratio = speed / L
	local force = if forced and style.gaits[forced] then FORCED[forced] else nil
	local targetW = force or gaitWeights(style, if turning then 0.8 else ratio)
	local moveTarget = if moving then math.clamp(ratio / 0.6, 0, 1) elseif turning then 0.7 else 0
	if input.snap then
		inst.weights = table.clone(targetW)
		inst.move = moveTarget
	else
		local rate = if force then 25 else 6
		for name in style.gaits do
			inst.weights[name] = approach(inst.weights[name] or 0, targetW[name] or 0, rate, dt)
		end
		inst.move = approach(inst.move, moveTarget, if force then 25 else 8, dt)
	end
	local k = 0
	for name, w in inst.weights do
		k += style.gaits[name].k * w
	end
	local ground = if moving then speed elseif turning then math.abs(input.yawRate) * L * 0.4 else 0
	-- planted feet: the stride shrinks with `move` (slow steps are short ones), so the cadence makes up for it and the
	-- foot in stance still goes back at the ground speed
	local stride = if inst.planted then math.max(inst.move, 0.5) else 1
	inst.phase = (inst.phase + dt * ground / math.max(0.2, k * L * stride)) % 1
	local out: Controls = {}
	if inst.move > 0.005 then
		for name, w in inst.weights do
			if w > 0.005 then
				addAll(out, gaitControls(style, name, inst.phase, inst.center), w * inst.move)
			end
		end
	end
	return out
end

-- Idle: breathing, weight shift, look-around, tail sway and ear flicks (scaled down while it moves).
local function idleLayer(inst: Instance, now: number, out: Controls)
	local style = inst.style
	local t = now + inst.seed * 5.1
	local still = 1 - inst.move
	local breath = math.sin(t * 2 * math.pi * 0.35)
	add(out, "sflex", 0.017 * breath)
	add(out, "by", 0.004 * breath)
	local shift = math.sin(t * 2 * math.pi * 0.12)
	add(out, "bx", 0.03 * shift * still)
	add(out, "broll", 0.017 * shift * still)
	-- a heavy quadruped stands on planted feet (the weight shift and the breath bend its legs)
	if style.ground then
		addAll(out, style.ground, still)
	end
	-- the tail
	add(out, "tpitch", style.idle.tail * still)
	for i = 1, 4 do
		add(out, "tY" .. i, 0.14 * math.sin(t * 2 * math.pi * 0.25 - i * 0.7) * still)
	end
	-- looks around every few seconds (with no target)
	local slot = math.floor(t / 4.2)
	local function target(n: number): (number, number)
		if hash01(n, inst.seed) < 0.35 then
			return 0, 0
		end
		return (hash01(n + 11, inst.seed) * 2 - 1) * 0.6, (hash01(n + 23, inst.seed) * 2 - 1) * 0.17
	end
	local y0, p0 = target(slot - 1)
	local y1, p1 = target(slot)
	local k = smooth((t - slot * 4.2) / 0.35)
	local free = still * (1 - inst.combat) * (1 - inst.look)
	add(out, "hyaw", (y0 + (y1 - y0) * k) * 0.55 * free)
	add(out, "nyaw", (y0 + (y1 - y0) * k) * 0.45 * free)
	add(out, "hpitch", (p0 + (p1 - p0) * k) * free)
	-- a trunk hangs a little curled and drifts; big ears fan now and then
	if style.trunk then
		add(out, "kcurl", 0.12 + 0.05 * math.sin(t * 2 * math.pi * 0.11))
		add(out, "kside", 0.05 * math.sin(t * 2 * math.pi * 0.17))
	end
	local flap = style.earFlap
	if flap then
		local x = t % flap.every
		local e = if x < 1.6 then math.sin(math.pi * x / 1.6) ^ 2 else 0
		add(out, "earL", flap.amp * e)
		add(out, "earR", flap.amp * e)
	end
	-- ear flicks
	for i, ear in { "earL", "earR" } do
		local e = math.floor(t / 5.3 + i * 0.37)
		local local_t = t - (e - i * 0.37) * 5.3
		if hash01(e + i * 101, inst.seed) < 0.5 and local_t < 0.15 then
			add(out, ear, 0.35 * math.sin(local_t / 0.15 * math.pi))
		end
	end
end

---------------------------------------------------------------- evaluation

local function lerpControls(a: Controls, b: Controls, k: number): Controls
	local out: Controls = {}
	for key, v in a do
		out[key] = v + ((b[key] or 0) - v) * k
	end
	for key, v in b do
		if a[key] == nil then
			out[key] = v * k
		end
	end
	return out
end

-- Head and body yaw are mirrored on a mirrored run (a toss to the other side).
local MIRRORED: { [string]: boolean } = {
	hyaw = true,
	nyaw = true,
	hroll = true,
	byaw = true,
	broll = true,
	syaw = true,
	bx = true,
	bpx = true,
	kside = true,
}

local function actionControls(style: QuadStyles.Style, run: ActionRun, t: number): Controls?
	local action = style.actions[run.name]
	if not action then
		return nil
	end
	local first = action.keys[1]
	local start = if first and first.u == 0 and first.seg == "A" then first.pose else style.stance
	local controls = MotionTimeline.at(action, run.hit, t, start)
	if run.mirror and not action.sided then
		controls = table.clone(controls)
		for key in MIRRORED do
			if controls[key] then
				controls[key] = -controls[key]
			end
		end
	end
	return controls
end

function QuadMotion.step(inst: Instance, input: Input): QuadPose.Posed
	local style = inst.style
	local skel = inst.skel
	local now = input.now
	local dt = input.dt
	local L = skel.L
	-- 1. locomotion (an action may run a gait: a charge gallops; a flight the pose draws itself is ground speed)
	local run = input.action
	local forced: string? = nil
	local extra = 0
	local runAction = if run then style.actions[run.name] else nil
	if run and runAction and runAction.gait then
		-- from the strike (the dash) to the end of the follow-through: the gather keeps the pace it had
		local t = now - run.start
		local strikeAt = run.hit - math.min(runAction.strike, run.hit * 0.7)
		if t >= strikeAt and t <= run.hit + runAction.follow then
			forced = runAction.gait
			local reach = run.reach
			if reach and runAction.travel and dt > 0 then
				local d = math.sqrt(reach[1] * reach[1] + reach[3] * reach[3])
				local a = actionControls(style, run, t)
				local b = actionControls(style, run, math.max(0, t - dt))
				local da = if a then a.travel or 0 else 0
				local db = if b then b.travel or 0 else 0
				extra = math.abs(da - db) * math.max(0, d - 1.1 * L) / dt
			end
		end
	end
	local controls = locomotion(inst, input, forced, extra)
	-- 2. idle, stance, calm
	idleLayer(inst, now, controls)
	local combatTarget = if input.combat then 1 else 0
	local calmTarget = if input.returning then 1 else 0
	inst.combat = if input.snap then combatTarget else approach(inst.combat, combatTarget, 4, dt)
	inst.calm = if input.snap then calmTarget else approach(inst.calm, calmTarget, 3, dt)
	if inst.combat > 0.005 then
		addAll(controls, style.stance, inst.combat * (1 - 0.6 * inst.move))
	end
	if inst.calm > 0.005 then
		addAll(controls, style.calm, inst.calm)
	end
	-- fidgets when idle, alone and still
	local busy = run ~= nil
		and style.actions[run.name] ~= nil
		and now - run.start < MotionTimeline.length(style.actions[run.name], run.hit)
	if busy then
		inst.lastAction = now
	end
	local fidget = inst.fidget
	if fidget and (busy or input.combat or inst.move > 0.2) then
		inst.fidget = nil
		fidget = nil
	end
	if
		not fidget
		and not busy
		and not input.combat
		and inst.move < 0.05
		and now >= inst.nextFidget
		and #style.fidgets > 0
	then
		local n = math.floor(now)
		local name = style.fidgets[1 + math.floor(hash01(n, inst.seed) * #style.fidgets) % #style.fidgets]
		inst.fidget = { name = name, start = now, hit = 0.5 }
		inst.nextFidget = now
			+ style.fidgetEvery[1]
			+ hash01(n + 3, inst.seed) * (style.fidgetEvery[2] - style.fidgetEvery[1])
		fidget = inst.fidget
	end
	if now < inst.lastTime then
		inst.fidget = nil
		fidget = nil
		inst.nextFidget = now + 4
	end
	inst.lastTime = now
	-- 3. the keyed action (or a fidget)
	local actionW = 0
	local playing = if run and style.actions[run.name] then run else fidget
	if playing then
		local action = style.actions[playing.name]
		local t = now - playing.start
		local length = MotionTimeline.length(action, playing.hit)
		if t >= 0 and (t <= length or action.hold) then
			local keyed = actionControls(style, playing, math.min(t, length)) :: Controls
			-- the gather trembles more and more toward the strike
			if action.tremble and action.tremble > 0 then
				local p = MotionTimeline.gather(action, playing.hit, t)
				local amp = action.tremble * p * p
				keyed = table.clone(keyed)
				keyed.bpitch = (keyed.bpitch or 0) + amp * math.sin(now * 2 * math.pi * 18)
				keyed.broll = (keyed.broll or 0) + amp * 0.7 * math.sin(now * 2 * math.pi * 15 + 1.3)
			end
			local travel = keyed.travel
			if travel and playing.reach and action.travel then
				-- the flight ends with the jaws at the target, not the body in it (a body length short)
				local rx, rz = playing.reach[1], playing.reach[3]
				local d = math.sqrt(rx * rx + rz * rz)
				local k = if d > 1e-3 then math.max(0, d - 1.1 * L) / d else 0
				keyed = table.clone(keyed)
				keyed.bx = (keyed.bx or 0) + rx * k * travel / L
				keyed.bz = (keyed.bz or 0) + rz * k * travel / L
				-- planted feet land with the body
				for _, keys in LEG_KEYS do
					if keyed[keys.k] then
						keyed[keys.z] = (keyed[keys.z] or 0) + rz * k * travel / L
					end
				end
			end
			-- a heavy body (planted feet) takes a little longer to leave its gait
			local w = math.min(1, t / (if inst.planted then 0.2 else 0.08))
			if not action.hold then
				w = math.min(w, math.max(0, (length - t) / 0.18))
			end
			w = MotionTimeline.ease("inout", w)
			actionW = w
			-- an action keys the whole body; moving, the legs keep the gait (unless it keys them fully)
			local legW = if action.full then w else w * (1 - inst.move)
			local blended = lerpControls(controls, keyed, w)
			for key, v in keyed do
				local leg = string.match(key, "^[FH][LR][ufpolkyz]$")
				if leg then
					blended[key] = (controls[key] or 0) + (v - (controls[key] or 0)) * legW
				end
			end
			if inst.planted then
				-- the gait's legs and planted feet leave with the legs' weight, not the whole action's (a charge
				-- gallops under its keyed head and body)
				for key, v in controls do
					if keyed[key] == nil and string.match(key, "^[FH][LR][ufpolkyz]$") then
						blended[key] = v * (1 - legW)
					end
				end
			end
			if action.gait then
				-- the gait the action runs keeps its body motion (bob, pitch, flex) under the keyed pose
				for _, key in GAIT_BODY do
					local v = controls[key]
					if v then
						blended[key] = (blended[key] or 0) + v * w * inst.move
					end
				end
			end
			controls = blended
			controls.travel = nil :: any
		end
	end
	-- 4. reactions: the flinch
	local hitAt = input.hitAt
	if hitAt and input.hitSide then
		local t = now - hitAt
		if t >= 0 and t < 0.4 then
			local e = if t < 0.05
				then MotionTimeline.ease("out", t / 0.05)
				else 1 - MotionTimeline.ease("inout", (t - 0.05) / 0.35)
			e *= 1 - 0.6 * actionW
			local f = style.flinch[input.hitSide]
			if f then
				addAll(controls, f, e)
			end
		end
	end
	-- the lean into turns
	local lean = math.clamp(input.yawRate * 0.25, -0.17, 0.17) * inst.move
	add(controls, "broll", -lean)
	add(controls, "syaw", math.clamp(input.yawRate * 0.12, -0.14, 0.14) * inst.move)
	-- the head toward the target
	local look = input.look
	local lookTarget = if look and inst.combat > 0.2 then 1 else 0
	inst.look = if input.snap then lookTarget else approach(inst.look, lookTarget, 5, dt)
	if look then
		local yaw = math.clamp(math.atan2(-look[1], -look[3]), -1.1, 1.1)
		local flat = math.sqrt(look[1] * look[1] + look[3] * look[3])
		local pitch = math.clamp(math.atan2(-look[2], flat), -0.4, 0.4)
		inst.lookYaw = if input.snap then yaw else approach(inst.lookYaw, yaw, 7, dt)
		inst.lookPitch = if input.snap then pitch else approach(inst.lookPitch, pitch, 7, dt)
	end
	local lw = inst.look * (1 - 0.6 * actionW)
	if lw > 0.01 then
		add(controls, "nyaw", inst.lookYaw * 0.5 * lw)
		add(controls, "hyaw", inst.lookYaw * 0.4 * lw)
		add(controls, "hpitch", inst.lookPitch * 0.5 * lw)
	end
	-- 5. the trunk: a pendulum hanging from the face. Its root is carried by the head's turns, the body's roll and
	-- lunges; the tip follows on a soft spring, so it trails, overshoots and swings out
	local trunk = style.trunk
	if trunk then
		local side = ((controls.nyaw or 0) + (controls.hyaw or 0) + (controls.byaw or 0)) * trunk.arm
			+ (controls.broll or 0) * trunk.height
			- (controls.bx or 0)
		local fwd = -(controls.bz or 0) - 0.6 * ((controls.npitch or 0) + (controls.hpitch or 0))
		if input.snap or not inst.trunkReady then
			inst.trunkS, inst.trunkSV, inst.trunkF, inst.trunkFV = side, 0, fwd, 0
			inst.trunkReady = true
		elseif dt > 0 then
			local omega = 2 * math.pi * trunk.hz
			local steps = math.ceil(dt * 60)
			local h = dt / steps
			for _ = 1, steps do
				local aS = omega * omega * (side - inst.trunkS) - 2 * trunk.damp * omega * inst.trunkSV
				inst.trunkSV += aS * h
				inst.trunkS += inst.trunkSV * h
				local aF = omega * omega * (fwd - inst.trunkF) - 2 * trunk.damp * omega * inst.trunkFV
				inst.trunkFV += aF * h
				inst.trunkF += inst.trunkFV * h
			end
		end
		add(controls, "kside", math.clamp((inst.trunkS - side) * trunk.gain, -0.6, 0.6))
		add(controls, "kpitch", math.clamp((inst.trunkF - fwd) * trunk.gain, -0.6, 0.6))
	end
	return QuadPose.solve(skel, controls)
end

---------------------------------------------------------------- the game's choices

function QuadMotion.length(action: MotionTimeline.Action, hit: number): number
	return MotionTimeline.length(action, hit)
end

function QuadMotion.times(action: MotionTimeline.Action, hit: number): (number, number, number)
	local seg = MotionTimeline.segments(action, hit)
	return seg.A[2], hit, MotionTimeline.length(action, hit)
end

function QuadMotion.controlsAt(style: QuadStyles.Style, name: string, hit: number, t: number): Controls?
	return actionControls(style, { name = name, start = 0, hit = hit }, t)
end

function QuadMotion.pick(style: QuadStyles.Style, attackId: string?, shot: string?, count: number): string
	if attackId and style.abilities[attackId] then
		return style.abilities[attackId]
	end
	if attackId then
		return if style.actions.heavy then "heavy" else style.basic[1]
	end
	if shot == "throw" and style.throw then
		return style.throw
	end
	return style.basic[1 + (count - 1) % #style.basic]
end

-- Whether the blow `count` tosses the head to the other side.
function QuadMotion.mirror(count: number): boolean
	return count % 2 == 0
end

function QuadMotion.death(inst: Instance): string
	local list = inst.style.death
	return list[1 + math.floor(hash01(5, inst.seed) * #list) % #list]
end

function QuadMotion.side(dir: Vec): string
	local x, z = dir[1], dir[3]
	if math.abs(z) >= math.abs(x) then
		return if z > 0 then "front" else "back"
	end
	return if x > 0 then "left" else "right"
end

return QuadMotion
