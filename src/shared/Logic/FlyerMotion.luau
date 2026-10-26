--!strict
-- Template animation (docs/ANIM-WZORCE.md F3): the motion of an imported flyer in layers, from the bottom:
-- 1. the wingbeat: one phase (downstroke 0 -> 0.45, upstroke -> 1) at the blended mode's rate (hover, forward flight,
--    hard flapping; Data/FlyerStyles `modes`), the humerus elevation fastest mid-stroke, the sweep's loop, the forearm
--    folding on the upstroke, the hand whipping behind the humerus and twisting on the upstroke; the body rises,
--    pitches and the tail counters with it. Glides in long straight flights (entered at the end of a downstroke, left
--    with a downstroke from the top); the outer wing beats wider while it turns in place;
-- 2. flight: the forward lean by speed, the bank into turns (a spring), the tail as a rudder, the brake's flare, the
--    legs hanging in a hover and tucked in flight; the hover's slow figure 8 and yaw drift; the head held still against
--    the body's bob, pitch and bank, with bird saccades (it jumps to a new look and holds) or locked on its target;
-- 3. keyed actions (Logic/MotionTimeline: anticipation stretched to the server's windup, the strike ending on its hit)
--    with their own controls (Data/FlyerStyles header: flap, hard, travel, drop, fall, shake) and the gather's tremble;
-- 4. reactions: the flinch by side with two hard beats after it, the stun's irregular flutter and sinking wobble, the
--    freeze holding the pose.
-- Pure: client/Anim/FlyerRig writes the bones, AnimLab evaluates it at a fixed time. The functions the game calls have
-- the names and arguments of Logic/QuadMotion's (step, pick, death, side, length, controlsAt, times, mirror).
-- Allocation-light: the controls live in tables of the instance, rewritten every frame.

local FlyerPose = require("./FlyerPose")
local FlyerStyles = require("../Data/FlyerStyles")
local MotionTimeline = require("./MotionTimeline")
local NpcPose = require("./NpcPose")

local FlyerMotion = {}

type Vec = { number }
type Controls = FlyerPose.Controls

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
	gait: string?, -- the server's `Gait` attribute (walk / trot / run)
	effects: string?, -- the model's `Effects` attribute (Logic/EffectStack text) at server time `serverNow`
	serverNow: number?,
	stunned: boolean?, -- AnimLab: stunned / frozen without the attribute, a glide now
	frozen: boolean?,
	glide: boolean?,
}
export type Instance = {
	skel: FlyerPose.Skeleton,
	style: FlyerStyles.Style,
	seed: number,
	rate: number, -- this bird's wingbeat rate x its scale's
	phase: number,
	flight: number, -- 0 hover .. 1 forward flight
	hard: number, -- hard flapping
	hardKey: number, -- ... asked by the running action (last frame)
	hardUntil: number,
	lastHit: number?,
	stun: number,
	glide: number,
	gliding: boolean,
	glidePending: boolean,
	glideUntil: number,
	glideSlot: number,
	straight: number,
	lastSpeed: number,
	decel: number,
	flareAt: number,
	bank: number,
	combat: number,
	calm: number,
	look: number,
	lookYaw: number,
	lookPitch: number,
	sacFrom: Vec,
	sacTo: Vec,
	sacAt: number,
	sacNext: number,
	sacCount: number,
	fidget: ActionRun?,
	nextFidget: number,
	lastTime: number,
	effects: string?,
	stunEnds: number,
	freezeEnds: number,
	solved: boolean,
	controls: Controls,
	beat: Controls,
	from: Controls, -- the pose the running action started from
	fromName: string?,
	fromStart: number?,
	mode: FlyerStyles.Mode,
	muzzle: Vec,
}

local TAU = 2 * math.pi

-- The wing controls by side (built once: no strings are made per frame).
local WING: { { [string]: string } } = {}
local WING_KEYS: { string } = {}
for _, side in { "L", "R" } do
	local names: { [string]: string } = {}
	for letter in string.gmatch("estfhbwpq", ".") do
		names[letter] = "w" .. side .. letter
		table.insert(WING_KEYS, "w" .. side .. letter)
	end
	table.insert(WING, names)
end

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

-- Smooth value noise in [-1, 1] at time `t` (one knot per second).
local function noise(t: number, seed: number): number
	local i = math.floor(t)
	local f = t - i
	local a = hash01(i, seed) * 2 - 1
	local b = hash01(i + 1, seed) * 2 - 1
	return a + (b - a) * f * f * (3 - 2 * f)
end

local function newMode(): FlyerStyles.Mode
	return { hz = 0, top = 0, bottom = 0, fore = 0, back = 0, fold = 0, twist = 0, bob = 0, pitch = 0, tail = 0 }
end

function FlyerMotion.new(skel: FlyerPose.Skeleton, styleId: string, seed: number): Instance?
	local style = FlyerStyles.get(styleId)
	if not style then
		return nil
	end
	-- bigger birds beat slower (docs/ANIM-WZORCE §4.2: the rate over the square root of the scale)
	local scale = math.clamp(skel.unit, 0.3, 4)
	return {
		skel = skel,
		style = style,
		seed = seed,
		rate = (1 + (hash01(2, seed) * 2 - 1) * style.rate) / math.sqrt(scale),
		phase = hash01(3, seed),
		flight = 0,
		hard = 0,
		hardKey = 0,
		hardUntil = -math.huge,
		lastHit = nil,
		stun = 0,
		glide = 0,
		gliding = false,
		glidePending = false,
		glideUntil = 0,
		glideSlot = -1,
		straight = 0,
		lastSpeed = 0,
		decel = 0,
		flareAt = -math.huge,
		bank = 0,
		combat = 0,
		calm = 0,
		look = 0,
		lookYaw = 0,
		lookPitch = 0,
		sacFrom = { 0, 0 },
		sacTo = { 0, 0 },
		sacAt = 0,
		sacNext = 0,
		sacCount = 0,
		fidget = nil,
		nextFidget = 4 + hash01(4, seed) * 6,
		lastTime = 0,
		effects = nil,
		stunEnds = 0,
		freezeEnds = 0,
		solved = false,
		controls = {},
		beat = {},
		from = {},
		fromName = nil,
		fromStart = nil,
		mode = newMode(),
		muzzle = { 0, 0, 0 },
	}
end

---------------------------------------------------------------- the wingbeat

-- `out` = the modes blended: hover / flight by `f`, then hard flapping by `h`.
local function blendModes(out: FlyerStyles.Mode, style: FlyerStyles.Style, f: number, h: number)
	local a: any, b: any, c: any, o: any = style.modes.hover, style.modes.flight, style.modes.hard, out
	for key, va in a do
		local v = va + (b[key] - va) * f
		o[key] = v + (c[key] - v) * h
	end
end

-- Humerus elevation at phase `p` (0..1): down from the top over 0.45 of the cycle, up again over the rest, fastest
-- mid-stroke.
local function elevation(mode: FlyerStyles.Mode, p: number): number
	p %= 1
	if p < 0.45 then
		return mode.top + (mode.bottom - mode.top) * (1 - math.cos(math.pi * p / 0.45)) / 2
	end
	return mode.bottom + (mode.top - mode.bottom) * (1 - math.cos(math.pi * (p - 0.45) / 0.55)) / 2
end

-- The wingbeat at phase `p` into `out`: per wing `e` as the swing about the stroke's middle (the middle itself is
-- `mid`), with `amp` per side (L, R) on the swing; the body's rise, pitch and the tail's counter.
local function beatInto(out: Controls, mode: FlyerStyles.Mode, p: number, ampL: number, ampR: number)
	local mid = (mode.top + mode.bottom) / 2
	local e = elevation(mode, p) - mid
	local lagHand = elevation(mode, p - 0.06) - mid
	local lagTip = elevation(mode, p - 0.1) - mid
	local down = p < 0.45
	local s = if down then p / 0.45 else (p - 0.45) / 0.55
	local arch = math.sin(math.pi * s)
	local sweep = if down then mode.fore * arch else mode.back * arch
	local fold = if down then 0 else mode.fold * arch
	local twist = if down then 0 else mode.twist * arch
	for i, k in WING do
		local amp = if i == 1 then ampL else ampR
		out[k.e] = e * amp
		out[k.s] = sweep * amp
		out[k.f] = fold
		out[k.h] = fold * 0.7
		out[k.w] = (lagHand - e) * amp
		out[k.p] = (lagTip - e) * 0.6 * amp
		out[k.q] = twist
		out[k.t] = if down then -0.08 * arch else 0
	end
	local wave = math.cos(TAU * (p - 0.4))
	out.by = mode.bob * wave
	out.bpitch = mode.pitch * wave
	out.tpitch = mode.tail * wave -- the tail's tip counters the body's pitch
end

---------------------------------------------------------------- the server's effects

-- Stun and freeze ends (server time) from the Effects text, parsed only when it changed.
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

---------------------------------------------------------------- evaluation

-- Head and body yaw are mirrored on a mirrored run.
local MIRRORED: { [string]: boolean } = {
	hyaw = true,
	nyaw = true,
	hroll = true,
	byaw = true,
	broll = true,
	syaw = true,
	sroll = true,
	bx = true,
	tyaw = true,
}

-- Controls a key may set that drive the motion instead of a bone (Data/FlyerStyles header).
local META: { [string]: boolean } =
	{ flap = true, hard = true, travel = true, reachMax = true, arc = true, drop = true, fall = true, shake = true }

-- The keyed controls of `run` at `t` s, blending from `from` (the pose it started from, mirrored like the run; the
-- stance when nil) unless its first key is at its very start.
local function actionControls(style: FlyerStyles.Style, run: ActionRun, t: number, from: Controls?): Controls?
	local action = style.actions[run.name]
	if not action then
		return nil
	end
	local first = action.keys[1]
	local start = if first and first.u == 0 and first.seg == "A" then first.pose else from or style.stance
	local controls = MotionTimeline.at(action, run.hit, t, start)
	if run.mirror then
		controls = table.clone(controls)
		for key in MIRRORED do
			if controls[key] then
				controls[key] = -controls[key]
			end
		end
	end
	return controls
end

-- Saccades: the head jumps to a new look in 0.08 s and holds (style.saccade); `amp` scales the jumps.
local function saccade(inst: Instance, now: number, amp: number, out: Controls)
	local sac = inst.style.saccade
	if now < inst.sacAt then
		inst.sacFrom[1], inst.sacFrom[2], inst.sacTo[1], inst.sacTo[2] = 0, 0, 0, 0
		inst.sacAt, inst.sacNext = now, now
	end
	if now >= inst.sacNext then
		local n = inst.sacCount + 1
		inst.sacCount = n
		local k = math.clamp((now - inst.sacAt) / 0.08, 0, 1)
		inst.sacFrom[1] = inst.sacFrom[1] + (inst.sacTo[1] - inst.sacFrom[1]) * k
		inst.sacFrom[2] = inst.sacFrom[2] + (inst.sacTo[2] - inst.sacFrom[2]) * k
		-- now and then back to straight ahead, else a new look
		if hash01(n * 7 + 1, inst.seed) < 0.25 then
			inst.sacTo[1], inst.sacTo[2] = 0, 0
		else
			inst.sacTo[1] = (hash01(n * 7 + 2, inst.seed) * 2 - 1) * sac.yaw
			inst.sacTo[2] = (hash01(n * 7 + 3, inst.seed) * 2 - 1) * sac.pitch
		end
		inst.sacAt = now
		inst.sacNext = now + sac.hold[1] + hash01(n * 7 + 4, inst.seed) * (sac.hold[2] - sac.hold[1])
	end
	local k = MotionTimeline.ease("out", (now - inst.sacAt) / 0.08)
	local yaw = inst.sacFrom[1] + (inst.sacTo[1] - inst.sacFrom[1]) * k
	local pitch = inst.sacFrom[2] + (inst.sacTo[2] - inst.sacFrom[2]) * k
	add(out, "hyaw", yaw * 0.6 * amp)
	add(out, "nyaw", yaw * 0.4 * amp)
	add(out, "hpitch", pitch * amp)
end

function FlyerMotion.step(inst: Instance, input: Input): FlyerPose.Posed
	local style = inst.style
	local skel = inst.skel
	local now = input.now
	local dt = input.dt
	local snap = input.snap == true
	-- the server's stun and freeze
	readEffects(inst, input.effects)
	local serverNow = input.serverNow or 0
	local stunned = input.stunned == true or serverNow < inst.stunEnds
	local frozen = input.frozen == true or serverNow < inst.freezeEnds
	if frozen and inst.solved then
		-- frozen in the air: the pose holds (and its clocks with it)
		inst.lastTime = now
		return skel.posed
	end
	if now < inst.lastTime then
		inst.fidget = nil
		inst.nextFidget = now + 4
		inst.flareAt = -math.huge
		inst.hardUntil = -math.huge
		inst.lastHit = nil
		inst.gliding, inst.glidePending, inst.glide, inst.glideSlot = false, false, 0, -1
	end
	inst.lastTime = now
	local speed = input.speed
	local cruise = style.cruise
	---------------------------------------------------------------- the modes
	local flightTarget = math.clamp((speed - 1) / 5, 0, 1)
	local hit = input.hitAt
	if hit and hit ~= inst.lastHit then
		inst.lastHit = hit
		inst.hardUntil = hit + 0.6 -- two hard beats after a hit
	end
	local hardTarget = math.max(inst.hardKey, if now < inst.hardUntil and now >= (hit or now) then 1 else 0)
	local stunTarget = if stunned then 1 else 0
	if snap then
		inst.flight, inst.hard, inst.stun = flightTarget, hardTarget, stunTarget
	else
		inst.flight = approach(inst.flight, flightTarget, 4, dt)
		inst.hard = approach(inst.hard, hardTarget, 10, dt)
		inst.stun = approach(inst.stun, stunTarget, 6, dt)
	end
	local mode = inst.mode
	blendModes(mode, style, inst.flight, inst.hard)
	local gaitRate = if input.gait == "run" then 1.08 elseif input.gait == "walk" then 0.92 else 1
	local hz = mode.hz * inst.rate * gaitRate
	if inst.stun > 0.01 then
		-- an irregular flutter between 2 and 4 beats a second
		hz += (2 + noise(now * 1.7, inst.seed + 9) - hz) * inst.stun
	end
	---------------------------------------------------------------- glides
	local run = input.action
	local runAction = if run then style.actions[run.name] else nil
	local busy = run ~= nil and runAction ~= nil and now - run.start < MotionTimeline.length(runAction, run.hit)
	local straightFlight = inst.flight > 0.8 and math.abs(input.yawRate) < 0.35
	local mayGlide = straightFlight
		and not input.combat
		and not input.returning
		and input.gait ~= "run"
		and not stunned
		and not busy
	inst.straight = if straightFlight then inst.straight + dt else 0
	local slot = math.floor(now / style.glide.every)
	if slot ~= inst.glideSlot then
		inst.glideSlot = slot
		if
			not inst.gliding
			and mayGlide
			and inst.straight >= style.glide.after
			and hash01(slot, inst.seed + 31) < style.glide.chance
		then
			inst.glidePending = true
		end
	end
	if input.glide and not inst.gliding then
		inst.glidePending = true
	end
	local before = inst.phase
	if inst.glidePending and (mayGlide or input.glide) then
		-- enters at the end of a downstroke
		local after = (before + hz * dt) % 1
		if (before < 0.45 and after >= 0.45) or snap then
			inst.glidePending = false
			inst.gliding = true
			local g = style.glide.length
			inst.glideUntil = now + g[1] + hash01(slot + 5, inst.seed + 31) * (g[2] - g[1])
		end
	elseif not mayGlide then
		inst.glidePending = false
	end
	if input.glide and inst.gliding then
		inst.glideUntil = now + 1
	end
	if inst.gliding and (now >= inst.glideUntil or not (mayGlide or input.glide)) then
		inst.gliding = false
		inst.phase = 0 -- out of the glide with a downstroke from the top
	end
	local glideTarget = if inst.gliding then 1 else 0
	if snap then
		inst.glide = glideTarget
	elseif inst.glide < glideTarget then
		inst.glide = math.min(glideTarget, inst.glide + dt / 0.2)
	else
		inst.glide = math.max(glideTarget, inst.glide - dt / 0.15)
	end
	local glide = inst.glide
	-- the phase (held in a glide)
	if not inst.gliding then
		inst.phase = (inst.phase + hz * dt * (1 - glide)) % 1
	end
	---------------------------------------------------------------- the flare (braking)
	if dt > 1e-4 and not snap then
		inst.decel = approach(inst.decel, (inst.lastSpeed - speed) / dt, 12, dt)
	end
	inst.lastSpeed = speed
	if inst.decel > 6 and now - inst.flareAt > 0.6 and inst.flight > 0.4 then
		inst.flareAt = now
	end
	local ft = now - inst.flareAt
	local flare = if ft >= 0 and ft < 0.3 then math.sin(math.pi * ft / 0.3) else 0
	---------------------------------------------------------------- the beat and the flight
	local controls = inst.controls
	table.clear(controls)
	local turnInPlace = (1 - inst.flight) * math.clamp(math.abs(input.yawRate) / 1.5, 0, 1)
	local wide = 1 - 0.4 * inst.stun
	local ampL = wide * (1 + (if input.yawRate < 0 then 0.22 * turnInPlace else 0))
	local ampR = wide * (1 + (if input.yawRate > 0 then 0.22 * turnInPlace else 0))
	local beat = inst.beat
	beatInto(beat, mode, inst.phase, ampL, ampR)
	local mid = (mode.top + mode.bottom) / 2
	local flapping = (1 - glide) * (1 - flare * 0.7)
	addAll(controls, beat, flapping)
	for _, k in WING do
		add(controls, k.e, mid * (1 - glide))
	end
	if glide > 0.001 then
		local g = style.glide
		for _, k in WING do
			add(controls, k.e, g.elevation * glide)
			add(controls, k.s, g.sweep * glide)
			add(controls, k.f, g.fold * glide)
		end
		add(controls, "bpitch", g.pitch * glide)
		add(controls, "broll", g.wobble * math.sin(TAU * 0.7 * now) * glide)
	end
	-- the forward lean, the legs, the hover's drift
	local f = inst.flight
	add(controls, "bpitch", style.lean * math.clamp(speed / cruise, 0, 1.2) * f)
	addAll(controls, style.hang, 1 - f)
	addAll(controls, style.tuck, f)
	local t = now + inst.seed * 3.7
	local still = 1 - f
	local d = style.drift
	add(controls, "bx", d.x * math.sin(TAU * d.hz * t) * still)
	add(controls, "bz", d.z * math.sin(TAU * 2 * d.hz * t) * still)
	add(controls, "byaw", d.yaw * math.sin(TAU * 0.13 * t + 1.1) * still)
	-- the bank into turns (a spring of 0.2 s), the tail as a rudder
	local bankTarget = math.clamp(0.35 * input.yawRate, -style.bank, style.bank) * (0.35 + 0.65 * f)
	inst.bank = if snap then bankTarget else approach(inst.bank, bankTarget, 5, dt)
	add(controls, "broll", inst.bank)
	add(controls, "tyaw", -math.clamp(input.yawRate * 0.3, -math.rad(15), math.rad(15)) * f)
	-- the flare
	if flare > 0.001 then
		addAll(controls, style.flare, flare)
	end
	---------------------------------------------------------------- stances, the head
	local combatTarget = if input.combat then 1 else 0
	local calmTarget = if input.returning then 1 else 0
	inst.combat = if snap then combatTarget else approach(inst.combat, combatTarget, 4, dt)
	inst.calm = if snap then calmTarget else approach(inst.calm, calmTarget, 3, dt)
	if inst.combat > 0.005 then
		addAll(controls, style.stance, inst.combat)
	end
	if inst.calm > 0.005 then
		addAll(controls, style.calm, inst.calm)
	end
	-- the head stays still in the world: the neck takes up the body's rise, the head its pitch and bank
	local unit = skel.unit
	local neckDump = skel.neck / unit
	local rise = (controls.by or 0)
	local counter = -math.clamp(rise / math.max(0.2, neckDump), -0.5, 0.5) * 0.8
	add(controls, "npitch", counter)
	add(controls, "hpitch", -counter - (controls.bpitch or 0) * 0.85)
	add(controls, "hroll", -inst.bank * 0.8)
	-- look at the target (fighting) or bird saccades (straight ahead on the way home)
	local look = input.look
	local lookTarget = if look and inst.combat > 0.2 then 1 else 0
	inst.look = if snap then lookTarget else approach(inst.look, lookTarget, 8, dt)
	if look then
		local yaw = math.clamp(math.atan2(-look[1], -look[3]), -1.2, 1.2)
		local flat = math.sqrt(look[1] * look[1] + look[3] * look[3])
		local pitch = math.clamp(math.atan2(look[2], flat), -0.7, 0.4)
		inst.lookYaw = if snap then yaw else approach(inst.lookYaw, yaw, 14, dt)
		inst.lookPitch = if snap then pitch else approach(inst.lookPitch, pitch, 14, dt)
	end
	saccade(inst, now, (1 - inst.calm) * (1 - 0.85 * inst.look), controls)
	---------------------------------------------------------------- fidgets
	if busy then
		inst.fidget = nil
	end
	local fidget = inst.fidget
	if fidget and (input.combat or inst.flight > 0.2 or stunned) then
		inst.fidget = nil
		fidget = nil
	end
	if
		not fidget
		and not busy
		and not input.combat
		and not stunned
		and inst.flight < 0.05
		and now >= inst.nextFidget
		and #style.fidgets > 0
	then
		local n = math.floor(now)
		local name = style.fidgets[1 + math.floor(hash01(n, inst.seed) * #style.fidgets) % #style.fidgets]
		if style.actions[name] then
			inst.fidget = { name = name, start = now, hit = 0.5 }
			fidget = inst.fidget
		end
		inst.nextFidget = now
			+ style.fidgetEvery[1]
			+ hash01(n + 3, inst.seed) * (style.fidgetEvery[2] - style.fidgetEvery[1])
	end
	---------------------------------------------------------------- the keyed action
	local actionW = 0
	inst.hardKey = 0
	local playing = if busy or (run and runAction and runAction.hold) then run else fidget
	if playing then
		local action = style.actions[playing.name]
		local at = now - playing.start
		local length = MotionTimeline.length(action, playing.hit)
		if at >= 0 and (at <= length or action.hold) then
			-- the motion stops where it is and blends into the first key from there
			if playing.name ~= inst.fromName or playing.start ~= inst.fromStart or snap then
				inst.fromName, inst.fromStart = playing.name, playing.start
				local from = inst.from
				table.clear(from)
				for key, v in controls do
					from[key] = if playing.mirror and MIRRORED[key] then -v else v
				end
			end
			local keyed = actionControls(style, playing, math.min(at, length), inst.from) :: Controls
			local w = math.min(1, at / 0.08)
			if not action.hold then
				w = math.min(w, math.max(0, (length - at) / 0.18))
			end
			w = MotionTimeline.ease("inout", w)
			actionW = w
			for key, v in controls do
				if keyed[key] == nil then
					controls[key] = v * (1 - w)
				end
			end
			for key, v in keyed do
				if not META[key] then
					controls[key] = (controls[key] or 0) * (1 - w) + v * w
				end
			end
			-- the wingbeat running on over the keyed wings
			local flap = (keyed.flap or 0) * w
			if flap > 0.001 then
				for _, key in WING_KEYS do
					add(controls, key, (beat[key] or 0) * flap)
				end
				add(controls, "by", (beat.by or 0) * flap)
				add(controls, "bpitch", (beat.bpitch or 0) * flap)
			end
			inst.hardKey = (keyed.hard or 0) * w
			-- the gather trembles more and more toward the strike (the body, the wing tips)
			if action.tremble and action.tremble > 0 then
				local g = MotionTimeline.gather(action, playing.hit, at)
				local amp = action.tremble * g * g * w
				add(controls, "bpitch", amp * math.sin(now * TAU * 18))
				add(controls, "broll", amp * 0.7 * math.sin(now * TAU * 15 + 1.3))
				add(controls, "wLw", amp * 2.5 * math.sin(now * TAU * 12))
				add(controls, "wRw", amp * 2.5 * math.sin(now * TAU * 12 + 2))
			end
			local shake = keyed.shake
			if shake and shake > 0 then
				add(controls, "hyaw", shake * w * math.sin(now * TAU * 8))
				add(controls, "hroll", shake * 0.5 * w * math.sin(now * TAU * 8 + 0.8))
			end
			-- toward the target: a dive capped at `reachMax` studs, a pounce all the way (on its arc)
			local travel = keyed.travel
			if travel and travel > 0 and playing.reach then
				local rx, rz = playing.reach[1], playing.reach[3]
				local dist = math.sqrt(rx * rx + rz * rz)
				if dist > 1e-3 then
					local cap = if keyed.reachMax then keyed.reachMax * unit else math.huge
					local go = math.min(math.max(0, dist - 0.6 * unit), cap)
					local k = go / dist * travel * w
					add(controls, "bx", rx * k / unit)
					add(controls, "bz", rz * k / unit)
					local arc = keyed.arc
					if arc and arc > 0 then
						local apex = math.clamp(arc * dist, 2 * unit, 6 * unit)
						add(controls, "by", 4 * travel * (1 - travel) * apex * w / unit)
					end
				end
			end
			-- down toward the ground (straight, or falling under gravity)
			local height = math.max(0, skel.pivot[2] / unit - skel.rig.half)
			local drop = (keyed.drop or 0) + (keyed.fall or 0) ^ 2
			if drop > 0 then
				add(controls, "by", -drop * height * w)
			end
			-- the beat stays out of sight while keyed fully: resume from the upstroke when it comes back
			if flap <= 0.001 and w > 0.99 and not action.hold then
				inst.phase = (0.45 - hz * math.max(0, length - at)) % 1
			end
		end
	end
	---------------------------------------------------------------- reactions
	if hit and input.hitSide then
		local ht = now - hit
		if ht >= 0 and ht < 0.4 then
			local e = if ht < 0.05
				then MotionTimeline.ease("out", ht / 0.05)
				else 1 - MotionTimeline.ease("inout", (ht - 0.05) / 0.35)
			e *= 1 - 0.6 * actionW
			local fl = style.flinch[input.hitSide]
			if fl then
				addAll(controls, fl, e)
			end
		end
	end
	-- stunned: sinks and wobbles, the head hangs
	local st = inst.stun * (1 - actionW)
	if st > 0.005 then
		add(controls, "by", -0.6 * st)
		add(controls, "broll", math.rad(8) * math.sin(TAU * 0.9 * now) * st)
		add(controls, "bpitch", math.rad(3) * math.sin(TAU * 0.6 * now + 1) * st)
		addAll(controls, style.stun, st)
	end
	-- the head toward the target
	local lw = inst.look * (1 - 0.6 * actionW)
	if lw > 0.01 then
		add(controls, "nyaw", inst.lookYaw * 0.45 * lw)
		add(controls, "hyaw", inst.lookYaw * 0.45 * lw)
		add(controls, "hpitch", inst.lookPitch * 0.6 * lw)
	end
	inst.solved = true
	local posed = FlyerPose.solve(skel, controls)
	FlyerPose.muzzle(skel, inst.muzzle)
	return posed
end

---------------------------------------------------------------- the game's choices

function FlyerMotion.length(action: MotionTimeline.Action, hit: number): number
	return MotionTimeline.length(action, hit)
end

function FlyerMotion.times(action: MotionTimeline.Action, hit: number): (number, number, number)
	local seg = MotionTimeline.segments(action, hit)
	return seg.A[2], hit, MotionTimeline.length(action, hit)
end

function FlyerMotion.controlsAt(style: FlyerStyles.Style, name: string, hit: number, t: number): Controls?
	return actionControls(style, { name = name, start = 0, hit = hit }, t)
end

function FlyerMotion.pick(style: FlyerStyles.Style, attackId: string?, shot: string?, count: number): string
	if attackId and style.abilities[attackId] then
		return style.abilities[attackId]
	end
	if attackId then
		return style.abilities.heavyBlow or style.basic[1]
	end
	if shot == "throw" and style.throw then
		return style.throw
	end
	return style.basic[1 + (count - 1) % #style.basic]
end

-- Whether the blow `count` turns the head the other way.
function FlyerMotion.mirror(count: number): boolean
	return count % 2 == 0
end

function FlyerMotion.death(inst: Instance): string
	local list = inst.style.death
	return list[1 + math.floor(hash01(5, inst.seed) * #list) % #list]
end

function FlyerMotion.side(dir: Vec): string
	local x, z = dir[1], dir[3]
	if math.abs(z) >= math.abs(x) then
		return if z > 0 then "front" else "back"
	end
	return if x > 0 then "left" else "right"
end

-- Where shots leave the body in the last pose (root space of the look), nil before the first frame.
function FlyerMotion.muzzle(inst: Instance): Vec?
	return if inst.solved then inst.muzzle else nil
end

return FlyerMotion
