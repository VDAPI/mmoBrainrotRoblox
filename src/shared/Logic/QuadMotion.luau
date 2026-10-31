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
-- The dragon (2026-10-31, Data/QuadStyles `dragon`) adds Logic/DragonMotion's wings (folded at rest, keyed open, a
-- wingbeat on the timeline, the gallop's pump), the tail's spring, the gait taken from the server's `Gait`, a flight's
-- height on the server's `Dash*` arc (`arc`), the server's stun (a dazed pose) and freeze (the pose held).
-- Pure: client/Anim/QuadRig writes the bones, AnimLab evaluates it at a fixed time. The functions the game calls have
-- the names and arguments of Logic/BipedMotion's (step, pick, death, side, length, controlsAt, times).

local DragonMotion = require("./DragonMotion")
local MotionTimeline = require("./MotionTimeline")
local NpcPose = require("./NpcPose")
local QuadPose = require("./QuadPose")
local QuadStyles = require("../Data/QuadStyles")

local QuadMotion = {}

type Vec = { number }
type Controls = QuadPose.Controls

-- `hold` keeps the end pose (AnimLab's stage, which has no server teleport, holds a leap where it landed)
export type ActionRun = { name: string, start: number, hit: number, reach: Vec?, mirror: boolean?, hold: boolean? }
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
	-- the server's gait intent (walk / trot / run) and Effects (Logic/EffectStack text at server time `serverNow`);
	-- AnimLab's stun and freeze without the attribute (read by a style with `stun`)
	gait: string?,
	effects: string?,
	serverNow: number?,
	stunned: boolean?,
	frozen: boolean?,
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
	dragon: DragonMotion.State?, -- the wings and the tail's spring (a style with `wings` on a rig with wing bones)
	stun: number, -- the dazed pose's weight
	effects: string?, -- the Effects text last parsed and the stun / freeze ends in it (server time)
	stunEnds: number,
	freezeEnds: number,
	posed: QuadPose.Posed?, -- the last pose (held while frozen)
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
		dragon = DragonMotion.new(skel, style.wings, seed),
		stun = 0,
		effects = nil,
		stunEnds = 0,
		freezeEnds = 0,
		posed = nil,
	}
end

---------------------------------------------------------------- locomotion

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- The share of a swing's ground covered at `q` (0..1): the foot starts and stops at rest, its speed eased up over the
-- first quarter and down over the last (the integral of that speed, so the swing's peak speed is only 4/3 of its mean).
local function swingShare(q: number): number
	local a = 0.25
	local x = math.clamp(q, 0, 1)
	local w
	if x < a then
		local u = x / a
		w = a * (u * u * u - u * u * u * u / 2)
	elseif x <= 1 - a then
		w = a / 2 + (x - a)
	else
		local u = (1 - x) / a
		w = (1 - a) - a * (u * u * u - u * u * u * u / 2)
	end
	return w / (1 - a)
end

-- Control names per leg (no string building per frame).
local LEG_KEYS: { [string]: { k: string, x: string, y: string, z: string, l: string } } = {}
for _, leg in { "FL", "FR", "HL", "HR" } do
	LEG_KEYS[leg] = { k = leg .. "k", x = leg .. "x", y = leg .. "y", z = leg .. "z", l = leg .. "l" }
end
-- A gait forced by an action, as weights.
local FORCED: { [string]: { [string]: number } } = {
	walk = { walk = 1, trot = 0, gallop = 0 },
	trot = { walk = 0, trot = 1, gallop = 0 },
	gallop = { walk = 0, trot = 0, gallop = 1 },
}
-- The body's own motion in a gait, kept under an action that runs the gait (a charge).
local GAIT_BODY = { "by", "bpitch", "broll", "sflex", "syaw" }
-- The tail's per-bone yaw (no string building per frame).
local TAIL_Y = { "tY1", "tY2", "tY3", "tY4", "tY5", "tY6", "tY7", "tY8" }
-- The server's gait intents (Logic/MonsterMove: wander, going home, the chase).
local SERVER_GAIT: { [string]: string } = { walk = "walk", trot = "trot", run = "gallop" }

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
-- `turn`: the body's yaw over one cycle (radians, + to the left), which an `onPrint` gait's planted feet turn against
-- about the root (`skel`: their rest points), so they stay on their prints while the body steers.
local function gaitControls(
	style: QuadStyles.Style,
	name: string,
	phase: number,
	center: { [string]: number },
	turn: number,
	skel: QuadPose.Skeleton
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
		out.bpitch = g.pitch * math.cos(2 * math.pi * (phase - 0.15)) - (g.stoop or 0)
		out.sflex = g.flex * math.cos(2 * math.pi * (phase - 0.9)) - g.flex * 0.25
	else
		out.by = -g.bob * math.cos(2 * w) - (g.drop or 0)
		out.bpitch = -(g.stoop or 0)
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
					if g.onPrint then
						-- on the ground the foot keeps still while the body goes on (R: the body's travel over the
						-- swing), so it lifts and lands without skimming; between, it overtakes the body by the whole
						-- stride (D + R)
						local R = D * (1 - duty) / duty
						local z = D / 2 + R * q - (D + R) * swingShare(q)
						out[keys.y], out[keys.z] = lift * math.sin(math.pi * q), c0 + z
					else
						-- Hermite from the lift-off point to the touchdown point, leaving and landing with part of
						-- the stance's speed
						local m = D * math.min((1 - duty) / duty, 1) * 0.6
						local q2, q3 = q * q, q * q * q
						local z = (2 * q3 - 3 * q2 + 1) * (D / 2)
							+ (q3 - 2 * q2 + q) * m
							+ (-2 * q3 + 3 * q2) * (-D / 2)
							+ (q3 - q2) * m
						out[keys.y], out[keys.z] = lift * math.sin(math.pi * q ^ 0.76), c0 + z
					end
				end
				out[keys.k] = 1
				if g.onPrint and turn ~= 0 then
					-- the yaw since mid-stance (the feet land turned ahead into the turn, leave turned behind it):
					-- a point on the ground turns by -yaw about the root in the body's frame
					local yaw = turn * duty * (if stance then s - 0.5 else 0.5 - swingShare(q))
					local foot = skel.chains[leg].foot
					local L = skel.L
					local fx, fz = foot[1] / L, foot[3] / L + out[keys.z]
					out[keys.x] = -fz * yaw
					out[keys.z] += fx * yaw
				end
			end
			if g.level then
				local into = g.levelIn or 0.4
				out[keys.l] = g.level
					* (if stance then 1 - smooth((s - 0.6) / 0.4) else smooth((q - (1 - into)) / into))
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
	for i = 1, math.min(style.tailBones or 4, #TAIL_Y) do
		out[TAIL_Y[i]] = g.tailSway * math.sin(w - i * 0.95)
	end
	return out
end

-- The gait the server's intent asks for (weights), a step down when the speed is too slow for it (a slowed chase
-- trots); nil without an intent the style has.
local function serverGait(style: QuadStyles.Style, gait: string?, ratio: number): { [string]: number }?
	local name = if gait then SERVER_GAIT[gait] else nil
	if not name or not style.gaits[name] then
		return nil
	end
	local t = style.thresholds
	if name == "gallop" and ratio < 0.7 * t.gallop then
		name = "trot"
	end
	if name == "trot" and ratio < 0.6 * t.trot then
		name = "walk"
	end
	return FORCED[name]
end

-- `forced`: the gait an action runs (blended in fast); `extra`: ground speed of a flight the pose draws itself.
local function locomotion(inst: Instance, input: Input, forced: string?, extra: number): Controls
	local style = inst.style
	local L = inst.skel.L
	local dt = input.dt
	local speed = input.speed + extra
	-- (a style's `stepFrom`: a dragon steps at any crawl rather than glide on its planted feet)
	local stepFrom = (style.stepFrom or 0.3) * L
	local turning = speed < stepFrom and math.abs(input.yawRate) > 1
	local moving = speed >= stepFrom
	local ratio = speed / L
	local force = if forced and style.gaits[forced] then FORCED[forced] else nil
	local intent = if style.serverGait and moving and not force then serverGait(style, input.gait, ratio) else nil
	local targetW = force or intent or gaitWeights(style, if turning then 0.8 else ratio)
	-- (planted feet step at least half a stride: the cadence below makes their stance keep the ground's pace)
	local moveTarget = if moving
		then math.max(math.clamp(ratio / 0.6, 0, 1), if inst.planted then 0.5 else 0)
		elseif turning then 0.7
		else 0
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
	local cadence = ground / math.max(0.2, k * L * stride)
	inst.phase = (inst.phase + dt * cadence) % 1
	-- the yaw over a cycle while it runs on (a chase steers; a turn on the spot keeps its own steps)
	local turn = if moving and cadence > 0.05 then math.clamp(input.yawRate / cadence, -1.2, 1.2) else 0
	local out: Controls = {}
	if inst.move > 0.005 then
		for name, w in inst.weights do
			if w > 0.005 then
				addAll(out, gaitControls(style, name, inst.phase, inst.center, turn, inst.skel), w * inst.move)
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
	for i = 1, math.min(style.tailBones or 4, #TAIL_Y) do
		add(out, TAIL_Y[i], 0.14 * math.sin(t * 2 * math.pi * 0.25 - i * 0.7) * still)
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
-- A dragon's wings swap sides on a mirrored run (Logic/DragonMotion: the left wing's keys become the right one's).
local WING_SWAP: { { string } } = {}
for letter in string.gmatch("estfhbwpqo", ".") do
	table.insert(WING_SWAP, { "wL" .. letter, "wR" .. letter })
end

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
		for _, pair in WING_SWAP do
			local l, r = controls[pair[1]], controls[pair[2]]
			if l or r then
				-- (a side without the key keeps none: 0)
				controls[pair[1]], controls[pair[2]] = r or 0, l or 0
			end
		end
	end
	return controls
end

-- Stun and freeze ends (server time) from the Effects text, parsed only when it changed (Logic/FlyerMotion's rule).
local function readEffects(inst: Instance, raw: string?)
	if raw == inst.effects then
		return
	end
	inst.effects = raw
	inst.stunEnds, inst.freezeEnds = 0, 0
	if type(raw) ~= "string" then
		return
	end
	for kind, ends in string.gmatch(raw, "(%a+):([%d%.]+)") do
		local t = tonumber(ends) or 0
		if kind == "stun" then
			inst.stunEnds = math.max(inst.stunEnds, t)
		elseif kind == "freeze" then
			inst.freezeEnds = math.max(inst.freezeEnds, t)
		end
	end
end

function QuadMotion.step(inst: Instance, input: Input): QuadPose.Posed
	local style = inst.style
	local skel = inst.skel
	local now = input.now
	local dt = input.dt
	local L = skel.L
	-- the server's stun and freeze (a style with a dazed pose): frozen, the pose holds
	local stunned = false
	if style.stun then
		readEffects(inst, input.effects)
		local serverNow = input.serverNow or 0
		if (input.frozen == true or serverNow < inst.freezeEnds) and inst.posed then
			inst.lastTime = now
			return inst.posed :: QuadPose.Posed
		end
		stunned = input.stunned == true or serverNow < inst.stunEnds
	end
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
	-- a dragon's wings at rest, the gallop's wingbeat, the tail tip's flicks
	local dragon = inst.dragon
	if dragon then
		local gallop = (inst.weights.gallop or 0) * inst.move
		DragonMotion.base(dragon, controls, now, gallop, inst.phase, 1 - inst.move, 1 - inst.combat)
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
		and not stunned
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
		local hold = action.hold or (run ~= nil and playing == run and run.hold == true)
		if t >= 0 and (t <= length or hold) then
			local keyed = actionControls(style, playing, math.min(t, length)) :: Controls
			-- the gather trembles more and more toward the strike
			if action.tremble and action.tremble > 0 then
				local p = MotionTimeline.gather(action, playing.hit, t)
				-- (only the gather: it settles over the first 0.08 s of the strike instead of shaking on through the
				-- blow and the recovery, which shook a planted heavy body's legs; studio review 2026-10-31)
				local gatherEnd = playing.hit - math.min(action.strike, playing.hit * 0.7)
				local amp = action.tremble * p * p * math.clamp(1 - (t - gatherEnd) / 0.08, 0, 1)
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
			local arc = keyed.arc
			if arc and action.travel then
				-- the flight's height on the server's Dash arc: a quarter of its length, within 1-3 leg lengths (a hop
				-- in place without a flight)
				local flight = 0
				if playing.reach then
					local rx, rz = playing.reach[1], playing.reach[3]
					flight = math.max(0, math.sqrt(rx * rx + rz * rz) - 1.1 * L) / L
				end
				local height = if flight > 0 then math.clamp(0.25 * flight, 1, 3) else 0.3
				keyed = table.clone(keyed)
				keyed.by = (keyed.by or 0) + arc * height
			end
			-- a heavy body (planted feet) takes a little longer to leave its gait
			local w = math.min(1, t / (if inst.planted then 0.2 else 0.08))
			if not hold then
				w = math.min(w, math.max(0, (length - t) / 0.18))
			end
			w = MotionTimeline.ease("inout", w)
			actionW = w
			-- an action keys the whole body; moving, the legs keep the gait (unless it keys them fully)
			local legW = if action.full then w else w * (1 - inst.move)
			local blended = lerpControls(controls, keyed, w)
			for key, v in keyed do
				local leg = string.match(key, "^[FH][LR][ufpolkxyz]$")
				if leg then
					blended[key] = (controls[key] or 0) + (v - (controls[key] or 0)) * legW
				end
			end
			if inst.planted then
				-- the gait's legs and planted feet leave with the legs' weight, not the whole action's (a charge
				-- gallops under its keyed head and body)
				for key, v in controls do
					if keyed[key] == nil and string.match(key, "^[FH][LR][ufpolkxyz]$") then
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
			controls.arc = nil :: any
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
	-- the server's stun: the dazed pose, the head wobbling
	if style.stun then
		local target = if stunned then 1 else 0
		inst.stun = if input.snap then target else approach(inst.stun, target, 5, dt)
		if inst.stun > 0.005 then
			local k = inst.stun * (1 - 0.6 * actionW)
			addAll(controls, style.stun, k)
			local t = now + inst.seed * 2.3
			add(controls, "nyaw", 0.14 * math.sin(t * 2 * math.pi * 0.42) * k)
			add(controls, "hroll", 0.12 * math.sin(t * 2 * math.pi * 0.55 + 1) * k)
			add(controls, "broll", 0.025 * math.sin(t * 2 * math.pi * 0.42 + 0.5) * k)
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
	-- 6. a dragon: the tail's spring, the wings' controls turned into their joints'
	if dragon then
		DragonMotion.tail(dragon, controls, input.yawRate, dt, input.snap)
		DragonMotion.resolve(dragon, controls, dt, input.snap)
	end
	local posed = QuadPose.solve(skel, controls)
	inst.posed = posed
	return posed
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

-- The death of an instance (one of the style's, by its seed): by the side the killing blow came from (`side`,
-- QuadMotion.side) where the style has deaths for it (the dragon's, 2026-10-31).
function QuadMotion.death(inst: Instance, side: string?): string
	local deaths = inst.style.deaths
	local list = if deaths and side and deaths[side] then deaths[side] else inst.style.death
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
