--!strict
-- Template animation (docs/ANIM-WZORCE.md F5): the motion of an imported model without bones (one rigid mesh: spider,
-- scorpion, lizards, serpents, the crow and the bat, the toad and the hare, the rot ent, the cats) in layers, from the
-- bottom; everything moves the whole look on its Gait_Body motor about chosen pivots (CF(p) * R * CF(-p)):
-- 1. locomotion synthesised from the gait tables of its style (Data/RigidStyles): one phase advanced by the distance
--    the root really travels (a cadence cap lengthens the stride beyond it), step bob, weight sway, wiggle, surge,
--    hops whose body stays put on the ground and catches up in the air (no sliding), the hover and flight of a body
--    with no wings; the gaits blend by speed over body length; stepping on the spot while turning; the start squat and
--    the stop overshoot;
-- 2. idle: breathing, a weight shift, looking around (the whole body turns), fidgets; the fighting stance, calm going
--    home; the turn lag (a critically damped spring on the root's yaw jumps) and the bank into turns;
-- 3. keyed actions on the timeline of Logic/MotionTimeline (anticipation stretched to the server's windup, the strike
--    ending on its hit): a lunge that closes the gap to the target (aimed until the strike, then locked), flights on
--    the server's Dash* arc (or toward the target), shivers and the gather's tremble;
-- 4. additive reactions: the flinch tilting about the far-side contact, stun, freeze (every clock stops);
-- 5. volume-preserving squash and stretch (only when the rig may write the mesh's Size: one MeshPart, the nearest few)
--    with the feet kept on the ground, transparency, and a no-sink pass that lifts the body so its box never goes
--    under the ground in deaths and flips;
-- 6. a serpent with bones (frostWyrm): a travelling wave along the tail and the coil (amplitude growing to the tail,
--    the head steady), the neck's sway and strikes (Data/RigidRigs chains).
-- Pure: client/Anim/RigidRig writes the motor, the mesh and the bones; AnimLab evaluates it at a fixed time. The
-- functions the game calls have the names of Logic/QuadMotion's (step, pick, death, side, length, mirror).

local MotionTimeline = require("./MotionTimeline")
local NpcPose = require("./NpcPose")
local RigidStyles = require("../Data/RigidStyles")

local RigidMotion = {}

type Vec = { number }
type Mat = { number }
export type Controls = { [string]: number }
type Style = RigidStyles.Style
type Action = RigidStyles.Action
type Gait = RigidStyles.Gait

-- The drawn look measured once on the clone (studs, in the frame of its PrimaryPart: the ground point under the
-- server's root, front -Z, up +Y).
export type Body = {
	h: number, -- top of the mesh over the ground
	lift: number, -- lowest point of the mesh over the ground (0 walkers, the hover of a flyer)
	B: number, -- front-back length of the mesh box
	W: number, -- width of the mesh box
	x0: number, -- centre of the box (horizontal)
	z0: number,
	squash: boolean, -- one visible MeshPart: its Size may be written (§6.1)
}
-- A bone chain of a rigid kind with bones (Data/RigidRigs): its bones' rest rotations in the look's frame.
export type Chain = { names: { string }, rest: { Mat } }
export type Chains = { tail: Chain?, coil: Chain?, neck: Chain?, head: Chain? }

export type ActionRun = { name: string, start: number, hit: number, reach: Vec?, mirror: boolean? }
-- A flight the rig read from the Dash* attributes: the body's offset from the root now (root space, studs) and the
-- arc's tangent pitch (rad, + nose up).
export type Flight = { x: number, y: number, z: number, pitch: number }
export type Input = {
	now: number,
	dt: number,
	speed: number, -- flat speed of the root (studs/s)
	gait: string?, -- the server's gait intent ("walk", "trot", "run": the attribute `Gait`) picks the style's gait
	yawRate: number, -- rad/s, + = turning left (smoothed)
	yawDelta: number?, -- rad the root turned this frame (raw; the turn lag springs on it)
	combat: boolean,
	returning: boolean?,
	action: ActionRun?,
	hitAt: number?,
	hitSide: string?,
	look: Vec?, -- root-space direction to the target
	snap: boolean?,
	stun: boolean?,
	frozen: boolean?,
	flight: Flight?,
	squash: boolean?, -- the rig writes the mesh's Size this frame
	flying: boolean?,
}
-- The pose of one frame (reused): the body's transform (rotation row-major 1..9, translation 10..12) in the motor's
-- frame, the mesh's scale per model axis, its transparency, the bones' Transform rotations.
export type Posed = {
	m: { number },
	sx: number,
	sy: number,
	sz: number,
	alpha: number,
	acting: boolean, -- a keyed action plays (the rig moves the muzzle with the body)
	bones: { [string]: Mat }?,
}
export type Instance = {
	body: Body,
	style: Style,
	seed: number,
	rate: number,
	phase: number,
	wave: number,
	v: number,
	weights: { [string]: number },
	move: number,
	combat: number,
	calm: number,
	stunW: number,
	freezeAt: number?,
	turnOff: number,
	turnVel: number,
	moving: boolean,
	startAt: number,
	stopAt: number,
	fidget: ActionRun?,
	nextFidget: number,
	lastTime: number,
	lastSide: string?,
	deathSide: number,
	lockName: string?,
	lockStart: number,
	lockX: number,
	lockZ: number,
	lockD: number,
	chains: Chains?,
	-- the pose of the last frame and the one a cut-short action blends from
	lastC: Controls,
	lastT: Vec,
	fromC: Controls,
	fromT: Vec,
	blendAt: number,
	wasActing: boolean,
	-- scratch (reused every frame)
	c: Controls,
	loco: Controls,
	keyed: Controls,
	posed: Posed,
}

local TAU = 2 * math.pi
local hash01 = NpcPose.hash01

-- Keys mirrored on a mirrored run (the other side) and turned to the death side.
local MIRRORED: { [string]: boolean } =
	{ x = true, roll = true, yaw = true, wig = true, tip = true, nY = true, spin = true, lean = true, tC = true }
-- How long the flinch rises, holds and falls (s; §1.5), the action's fades.
local FLINCH_IN, FLINCH_HOLD, FLINCH_OUT = 0.05, 0.03, 0.25
local ACTION_IN, CHARGED_IN, ACTION_OUT = 0.08, 0.12, 0.18
-- An action cut short by another (or by the death) hands its pose over this long (s).
local HANDOVER = 0.12
-- Squash and stretch never past these (§6.1).
local SQUASH_MIN, SQUASH_MAX = 0.85, 1.15
-- The turn lag never more than this (rad).
local TURN_MAX = math.rad(70)

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function add(into: Controls, key: string, v: number)
	into[key] = (into[key] or 0) + v
end

local function addAll(into: Controls, from: { [string]: number }, k: number)
	for key, v in from do
		into[key] = (into[key] or 0) + v * k
	end
end

-- Smooth value noise in -1..1 (one channel per `ch`), from the seed: shivers, jitter, twitches.
local function noise(t: number, seed: number, ch: number): number
	local i = math.floor(t)
	local f = t - i
	local a = hash01(i + ch * 7919, seed)
	local b = hash01(i + 1 + ch * 7919, seed)
	return (a + (b - a) * f * f * (3 - 2 * f)) * 2 - 1
end
RigidMotion.noise = noise

function RigidMotion.new(body: Body, styleId: string, seed: number, chains: Chains?): Instance?
	local style = RigidStyles.get(styleId)
	if not style then
		return nil
	end
	local posed: Posed = {
		m = { 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 },
		sx = 1,
		sy = 1,
		sz = 1,
		alpha = 0,
		acting = false,
		bones = if chains then {} else nil,
	}
	return {
		body = body,
		style = style,
		seed = seed,
		rate = 1 + (hash01(2, seed) * 2 - 1) * style.rate,
		phase = hash01(3, seed),
		wave = hash01(6, seed),
		v = 0,
		weights = { [style.order[1]] = 1 },
		move = 0,
		combat = 0,
		calm = 0,
		stunW = 0,
		freezeAt = nil,
		turnOff = 0,
		turnVel = 0,
		moving = false,
		startAt = -math.huge,
		stopAt = -math.huge,
		fidget = nil,
		nextFidget = style.fidgetEvery[1] + hash01(4, seed) * style.fidgetEvery[2],
		lastTime = 0,
		lastSide = nil,
		deathSide = if hash01(5, seed) < 0.5 then -1 else 1,
		lockName = nil,
		lockStart = 0,
		lockX = 0,
		lockZ = -1,
		lockD = 0,
		chains = chains,
		lastC = {},
		lastT = { 0, 0, 0 },
		fromC = {},
		fromT = { 0, 0, 0 },
		blendAt = -math.huge,
		wasActing = false,
		c = {},
		loco = {},
		keyed = {},
		posed = posed,
	}
end

---------------------------------------------------------------- the keyed timeline

-- The segments of an action (Logic/MotionTimeline.segments without the table): the anticipation's end and the
-- strike's length.
local function bounds(action: Action, hit: number): (number, number)
	local s = math.min(action.strike, hit * 0.7)
	return math.max(0, hit - s), s
end

function RigidMotion.length(action: Action, hit: number): number
	return hit + action.follow + action.recover
end

-- When the anticipation ends, the hit, the end (AnimLab keys).
function RigidMotion.times(action: Action, hit: number): (number, number, number)
	local a = bounds(action, hit)
	return a, hit, RigidMotion.length(action, hit)
end

local function startPose(style: Style, action: Action): { [string]: number }
	local first = action.keys[1]
	return if first and first.u == 0 and first.seg == "A" then first.pose else style.stance
end

-- The keyed controls of `action` at `t` (hit at `hit`) written into `out` (cleared), every value times `mul[key]`
-- for the mirrored keys: the same curve as MotionTimeline.at, without new tables.
local function sample(style: Style, action: Action, hit: number, t: number, out: Controls, sideMul: number)
	table.clear(out)
	local a, s = bounds(action, hit)
	local prevT, prevPose = 0, startPose(style, action)
	local nextPose: { [string]: number }? = nil
	local k = 1
	for _, key in action.keys do
		local start, span
		if key.seg == "A" then
			start, span = 0, a
		elseif key.seg == "S" then
			start, span = a, s
		elseif key.seg == "F" then
			start, span = hit, action.follow
		else
			start, span = hit + action.follow, action.recover
		end
		local kt = start + key.u * span
		if t <= kt then
			if kt - prevT < 1e-4 then
				prevPose, nextPose, k = key.pose, nil, 1
			else
				nextPose = key.pose
				k = MotionTimeline.ease(key.ease, (t - prevT) / (kt - prevT))
			end
			break
		end
		prevT, prevPose = kt, key.pose
	end
	local into = nextPose
	if into then
		for key, v in prevPose do
			out[key] = v + ((into[key] or 0) - v) * k
		end
		for key, v in into do
			if prevPose[key] == nil then
				out[key] = v * k
			end
		end
	else
		for key, v in prevPose do
			out[key] = v
		end
	end
	if sideMul ~= 1 then
		for key in MIRRORED do
			local v = out[key]
			if v then
				out[key] = v * sideMul
			end
		end
	end
end

-- The keyed controls of action `name` at `t` (a new table; AnimLab sheets and the tests).
function RigidMotion.controlsAt(style: Style, name: string, hit: number, t: number): Controls?
	local action = style.actions[name]
	if not action then
		return nil
	end
	local out: Controls = {}
	sample(style, action, hit, t, out, 1)
	return out
end

---------------------------------------------------------------- locomotion

-- The weights of the style's gaits at `ratio` (speed over body length): a crossfade band around each threshold.
local function gaitWeights(inst: Instance, ratio: number, into: { [string]: number })
	local style = inst.style
	local order = style.order
	local band = style.band
	local prev = 1
	for i, name in order do
		local th = style.thresholds[i]
		local up = if th then smooth((ratio - (th - band)) / (2 * band)) else 0
		into[name] = prev * (1 - up)
		prev = prev * up
	end
end

-- One gait's controls at `phase` into `out` (weight `w`); `L` = its stride in studs (hops).
local function gaitInto(inst: Instance, g: Gait, phase: number, w: number, L: number, t: number, out: Controls)
	local body = inst.body
	local hMesh = body.h - body.lift
	local hop = g.hop
	if hop then
		-- a hop: on the ground the body sinks and pushes (and stays put: it falls behind the root), in the air it arcs
		-- and catches up
		local g0 = hop.ground
		local H = math.min(hop.height * L, hop.maxHeight * hMesh)
		local zOff: number
		-- the body pitches about its feet: nose down about the fore feet as it lands, nose up about the hind feet as
		-- they push (each stays planted), the same pivots carried through the air
		if phase < g0 then
			local u = phase / g0
			local rise = smooth((u - 0.55) / 0.45)
			add(out, "y", -hop.crouch * math.sin(math.pi * u) * w)
			add(
				out,
				"sq",
				(-hop.squash * math.sin(math.pi * math.min(1, u / 0.8)) * (1 - rise) + hop.stretch * rise) * w
			)
			add(out, "dip", hop.pitchDown * (1 - smooth(u / 0.4)) * w)
			add(out, "rear", hop.pitchUp * rise * w)
			zOff = L * g0 * (u - 0.5)
		else
			local a = (phase - g0) / (1 - g0)
			add(out, "y", H * 4 * a * (1 - a) / hMesh * w)
			add(out, "sq", (hop.stretch * (1 - smooth(a / 0.4)) + 0.4 * hop.stretch * smooth((a - 0.7) / 0.3)) * w)
			add(out, "rear", hop.pitchUp * (1 - smooth(a / 0.5)) * w)
			add(out, "dip", hop.pitchDown * smooth((a - 0.5) / 0.5) * w)
			zOff = L * g0 * (0.5 - a)
		end
		add(out, "z", zOff / body.B * w)
	end
	local bob = g.bob
	if bob ~= 0 then
		local b: number
		if g.sine then
			b = math.sin(TAU * g.bumps * phase)
		else
			b = math.abs(math.sin(math.pi * g.bumps * phase))
			if g.sharp then
				b = b ^ g.sharp
			end
		end
		add(out, "y", bob * b * w)
	end
	if g.roll ~= 0 then
		add(out, "roll", g.roll * math.sin(TAU * (phase + g.rollPhase)) * w)
	end
	if g.rock ~= 0 then
		-- the weight rocks from foot to foot: a tip about the foot it stands on
		add(out, "tip", g.rock * math.sin(TAU * (phase + g.rollPhase)) * w)
	end
	if g.yaw ~= 0 or g.sway ~= 0 then
		local wv = math.sin(TAU * (phase - g.yawLag))
		add(out, "wig", g.yaw * wv * w)
		add(out, "x", -g.sway * wv * w)
	end
	if g.pitch ~= 0 then
		add(out, "pitch", g.pitch * w)
	end
	if g.pitchWave ~= 0 then
		add(out, "pitch", g.pitchWave * math.sin(TAU * (g.pitchBumps * phase + g.pitchPhase)) * w)
	end
	if g.surge ~= 0 then
		add(out, "z", g.surge * math.sin(TAU * g.bumps * phase) * w)
	end
	if g.crouch ~= 0 then
		add(out, "y", g.crouch * w)
	end
	if g.jitter ~= 0 then
		-- an erratic flutter (the bat): lateral and vertical noise
		add(out, "x", g.jitter * noise(t * g.jitterHz, inst.seed, 11) * w)
		add(out, "y", g.jitter * 0.6 * noise(t * g.jitterHz * 1.3, inst.seed, 12) * w)
		add(out, "roll", g.jitter * 2.5 * noise(t * g.jitterHz * 0.8, inst.seed, 13) * w)
	end
end

-- The locomotion controls into inst.loco: the gaits by speed, the phase by distance (or by time for a flutter).
local function locomotion(inst: Instance, input: Input, dt: number, t: number)
	local style = inst.style
	local body = inst.body
	local B = body.B
	local out = inst.loco
	table.clear(out)
	local speed = input.speed
	inst.v = if input.snap then speed else inst.v + (speed - inst.v) * (1 - math.exp(-dt / 0.1))
	local v = inst.v
	local turnSpot = v < 0.6 and math.abs(input.yawRate) > 1 and not style.fly
	local ground = if turnSpot then math.abs(input.yawRate) * B * 0.25 else v
	local moveTarget = if turnSpot then 0.6 else smooth((v - 0.3) / 1.2)
	inst.move = if input.snap then moveTarget else approach(inst.move, moveTarget, 10, dt)
	local weights = inst.weights
	local target = inst.keyed -- scratch until the action samples into it
	table.clear(target)
	local named = style.gaitOf and input.gait and style.gaitOf[input.gait]
	if named and not turnSpot then
		-- the server's intent: wandering walks, going home trots, the chase runs (S162m), whatever the body's size
		target[named] = 1
	else
		gaitWeights(inst, if turnSpot then 0 else v / B, target)
	end
	for _, name in style.order do
		weights[name] = if input.snap then target[name] or 0 else approach(weights[name] or 0, target[name] or 0, 6, dt)
	end
	-- the stride (studs) and how fast the phase runs
	local stride, cap, hz = 0, 0, 0
	for name, w in weights do
		local g = style.gaits[name]
		stride += g.stride * B * w
		cap += (g.maxRate or 99) * w
		hz += (g.hz or 0) * w
	end
	stride = math.max(stride, if cap > 0 then ground / cap else 0, 0.05) * inst.rate
	if hz > 0 then
		-- a flutter beats in time, a little faster when it flies
		inst.phase = (inst.phase + dt * hz * (1 + 0.25 * inst.move) / inst.rate) % 1
	else
		inst.phase = (inst.phase + dt * ground / stride) % 1
	end
	local amp = if style.fly then 1 else inst.move
	if amp > 0.005 then
		for name, w in weights do
			if w > 0.005 then
				gaitInto(inst, style.gaits[name], inst.phase, w * amp, stride, t, out)
			end
		end
	end
	-- a skitter comes in spurts (not going home)
	local burst = style.burst
	if burst and not input.returning and inst.move > 0.05 then
		local b = math.sin(TAU * burst.hz * t + inst.seed)
		out.y = (out.y or 0) * (1 - burst.bob * 0.5 * (1 + b))
		add(out, "z", burst.surge * b * inst.move)
	end
	-- the start squat and the stop's overshoot
	local moving = v > (if inst.moving then 0.6 else 1.0)
	if moving and not inst.moving then
		inst.startAt = t
	elseif not moving and inst.moving then
		inst.stopAt = t
	end
	inst.moving = moving
	local since = t - inst.startAt
	if since >= 0 and since < 0.15 then
		add(out, "y", -style.start * math.sin(math.pi * since / 0.15))
	end
	local stopped = t - inst.stopAt
	if stopped >= 0 and stopped < 0.35 then
		local u = stopped / 0.35
		add(out, "z", -style.stop.over * math.sin(TAU * stopped / 0.3) * (1 - u))
		add(out, "roll", style.stop.wobble * math.sin(TAU * 5 * stopped) * (1 - u) * (1 - u))
	end
end

-- Where the body looks in the idle slot `n` (rad of yaw; some slots straight ahead).
local function lookAt(n: number, seed: number, range: number): number
	if hash01(n, seed) < 0.4 then
		return 0
	end
	return (hash01(n + 11, seed) * 2 - 1) * range
end

-- Idle: breathing, a weight shift, the body turning to look around, a flyer's drift (scaled down while it moves).
local function idleLayer(inst: Instance, t: number, out: Controls)
	local idle = inst.style.idle
	local tt = t + inst.seed * 5.1
	local still = 1 - inst.move
	add(out, "y", idle.breath * math.sin(TAU * idle.rate * tt))
	local shift = math.sin(TAU * 0.13 * tt)
	add(out, "roll", idle.sway * shift * still)
	add(out, "x", idle.shift * shift * still)
	add(out, "y", idle.crouch * still)
	local weave = idle.weave
	if weave then
		-- a serpent's sway in place (the neck takes it when it has bones)
		local k = still * (if inst.chains then weave.bones else 1)
		add(out, "wig", weave.yaw * math.sin(TAU * weave.hz * tt) * k)
		add(out, "pitch", weave.pitch * math.sin(TAU * 2 * weave.hz * tt + 0.7) * k)
	end
	local drift = idle.drift
	if drift then
		-- (steadier while it flies somewhere)
		local w = TAU * drift.hz * tt
		local k = 1 - 0.6 * inst.move
		add(out, "x", drift.x * math.sin(w) * k)
		add(out, "y", drift.y * math.sin(2 * w) * k)
		add(out, "z", drift.z * math.sin(w + 1.3) * k)
		add(out, "yaw", drift.yaw * math.sin(0.5 * w + 0.4) * k)
	end
	-- looks around every few seconds (some slots straight ahead)
	if idle.look > 0 then
		local slot = math.floor(tt / 3.7)
		local y0, y1 = lookAt(slot - 1, inst.seed, idle.look), lookAt(slot, inst.seed, idle.look)
		local k = smooth((tt - slot * 3.7) / 0.3)
		add(out, "yaw", (y0 + (y1 - y0) * k) * still * (1 - inst.combat))
	end
end

---------------------------------------------------------------- the transform

-- Post-multiplies the affine `m` (rotation 1..9, translation 10..12) by a rotation of `a` rad about `axis` (1 x, 2 y,
-- 3 z) through the point p: m = m * CF(p) * R * CF(-p).
local function rotateAbout(m: { number }, axis: number, a: number, px: number, py: number, pz: number)
	if a == 0 then
		return
	end
	local c, s = math.cos(a), math.sin(a)
	-- R's columns
	local r00, r01, r02, r10, r11, r12, r20, r21, r22
	if axis == 1 then
		r00, r01, r02, r10, r11, r12, r20, r21, r22 = 1, 0, 0, 0, c, -s, 0, s, c
	elseif axis == 2 then
		r00, r01, r02, r10, r11, r12, r20, r21, r22 = c, 0, s, 0, 1, 0, -s, 0, c
	else
		r00, r01, r02, r10, r11, r12, r20, r21, r22 = c, -s, 0, s, c, 0, 0, 0, 1
	end
	-- q = p - R p (the pivot's translation)
	local qx = px - (r00 * px + r01 * py + r02 * pz)
	local qy = py - (r10 * px + r11 * py + r12 * pz)
	local qz = pz - (r20 * px + r21 * py + r22 * pz)
	local a00, a01, a02, a10, a11, a12, a20, a21, a22 = m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9]
	m[10] += a00 * qx + a01 * qy + a02 * qz
	m[11] += a10 * qx + a11 * qy + a12 * qz
	m[12] += a20 * qx + a21 * qy + a22 * qz
	m[1] = a00 * r00 + a01 * r10 + a02 * r20
	m[2] = a00 * r01 + a01 * r11 + a02 * r21
	m[3] = a00 * r02 + a01 * r12 + a02 * r22
	m[4] = a10 * r00 + a11 * r10 + a12 * r20
	m[5] = a10 * r01 + a11 * r11 + a12 * r21
	m[6] = a10 * r02 + a11 * r12 + a12 * r22
	m[7] = a20 * r00 + a21 * r10 + a22 * r20
	m[8] = a20 * r01 + a21 * r11 + a22 * r21
	m[9] = a20 * r02 + a21 * r12 + a22 * r22
end
RigidMotion.rotateAbout = rotateAbout

local function lower(k: number, a: number, b: number): number
	return if k * a < k * b then a else b
end

-- The lowest y of the body's box (squashed by sx, sy, sz, footprint `kf`) under the affine `m`.
local function lowest(m: { number }, body: Body, sx: number, sy: number, sz: number, kf: number): number
	local hx = body.W * sx * kf / 2
	local hz = body.B * sz * kf / 2
	local y0 = body.lift
	local y1 = body.lift + (body.h - body.lift) * sy
	-- the lowest corner: each axis takes the end that the row of m pushes down most
	local x = lower(m[4], body.x0 - hx, body.x0 + hx)
	local y = lower(m[5], y0, y1)
	local z = lower(m[6], body.z0 - hz, body.z0 + hz)
	return m[4] * x + m[5] * y + m[6] * z + m[11]
end
RigidMotion.lowest = lowest

-- The pose from the controls (and the action's extra translation in studs, the flight's pitch).
local function solve(inst: Instance, c: Controls, tx: number, ty: number, tz: number, squash: boolean): Posed
	local body = inst.body
	local style = inst.style
	local posed = inst.posed
	local m = posed.m
	local B, W = body.B, body.W
	local hMesh = body.h - body.lift
	local cy = body.lift + hMesh / 2
	local x0, z0 = body.x0, body.z0
	local kf = style.footprint
	-- squash and stretch (volume kept): sq vertical, sl along the body, gr every axis
	local sq, sl, gr = c.sq or 0, c.sl or 0, c.gr or 0
	local sx, sy, sz = 1, 1, 1
	if squash then
		local q, l = math.max(0.5, 1 + sq), math.max(0.5, 1 + sl)
		local g = 1 + gr
		sx = math.clamp(g / math.sqrt(q * l), SQUASH_MIN, SQUASH_MAX)
		sy = math.clamp(g * q / math.sqrt(l), SQUASH_MIN, SQUASH_MAX)
		sz = math.clamp(g * l / math.sqrt(q), SQUASH_MIN, SQUASH_MAX)
	else
		-- no mesh scaling: an impact squash sinks the body a little instead
		ty += math.min(0, sq) * hMesh * 0.35
	end
	posed.sx, posed.sy, posed.sz = sx, sy, sz
	posed.alpha = math.clamp(c.alpha or 0, 0, 1)
	-- the transform: translation, then the turns (outer to inner) about their pivots
	m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9] = 1, 0, 0, 0, 1, 0, 0, 0, 1
	m[10] = (c.x or 0) * W + tx
	m[11] = (c.y or 0) * hMesh + ty - (c.sink or 0) * body.h - (c.fall or 0) * body.lift
	m[12] = (c.z or 0) * B + tz
	rotateAbout(m, 2, (c.yaw or 0) + (c.spin or 0), x0, cy, z0)
	rotateAbout(m, 2, c.wig or 0, x0, cy, z0 + style.wigPivot * B)
	local tip = c.tip or 0
	if tip ~= 0 then
		local side = if tip > 0 then 1 else -1
		rotateAbout(m, 3, -tip, x0 + side * W * kf / 2, body.lift, z0)
	end
	rotateAbout(m, 1, c.bow or 0, x0, body.lift, z0)
	rotateAbout(m, 3, c.lean or 0, x0, body.lift, z0)
	rotateAbout(m, 1, c.rear or 0, x0, body.lift, z0 + B * kf / 2)
	rotateAbout(m, 1, -(c.dip or 0), x0, body.lift, z0 - B * kf / 2)
	rotateAbout(m, 1, c.pitch or 0, x0, cy, z0)
	rotateAbout(m, 3, c.roll or 0, x0, cy, z0)
	-- the squashed mesh keeps its bottom where it was
	if sy ~= 1 then
		m[10] += m[2] * (sy - 1) * hMesh / 2
		m[11] += m[5] * (sy - 1) * hMesh / 2
		m[12] += m[8] * (sy - 1) * hMesh / 2
	end
	-- never under the ground (deaths, flips: `ground`), resting on it (`settle`)
	local groundW, settle = c.ground or 0, c.settle or 0
	if groundW > 0 or settle > 0 then
		local low = lowest(m, body, sx, sy, sz, kf)
		if low < 0 then
			m[11] -= low * math.min(1, math.max(groundW, settle))
		elseif settle > 0 then
			m[11] -= low * math.min(1, settle)
		end
	end
	return posed
end

---------------------------------------------------------------- bones (a serpent with a skeleton)

-- Rotations about the look's x and y axes written into `out` (row-major).
local function rotX(out: Mat, a: number)
	local c, si = math.cos(a), math.sin(a)
	out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9] = 1, 0, 0, 0, c, -si, 0, si, c
end
local function rotY(out: Mat, a: number)
	local c, si = math.cos(a), math.sin(a)
	out[1], out[2], out[3], out[4], out[5], out[6], out[7], out[8], out[9] = c, 0, si, 0, 1, 0, -si, 0, c
end

-- out = a * b (3x3 row-major; `out` is neither)
local function mulInto(out: Mat, a: Mat, b: Mat)
	for r = 0, 2 do
		local a0, a1, a2 = a[r * 3 + 1], a[r * 3 + 2], a[r * 3 + 3]
		out[r * 3 + 1] = a0 * b[1] + a1 * b[4] + a2 * b[7]
		out[r * 3 + 2] = a0 * b[2] + a1 * b[5] + a2 * b[8]
		out[r * 3 + 3] = a0 * b[3] + a1 * b[6] + a2 * b[9]
	end
end

-- Scratch of the bone layer (one frame at a time).
local TURN: Mat = table.create(9, 0)
local TURN2: Mat = table.create(9, 0)
local TURN3: Mat = table.create(9, 0)
local TMP: Mat = table.create(9, 0)

-- Transform = rest^-1 * C * rest (C a turn in the look's axes, carried by the parent; Logic/QuadPose), written into
-- the bone's own matrix (reused).
local function boneTurn(into: { [string]: Mat }, name: string, rest: Mat, turn: Mat)
	local out = into[name]
	if not out then
		out = table.create(9, 0)
		into[name] = out
	end
	mulInto(TMP, turn, rest)
	for r = 0, 2 do
		for c = 0, 2 do
			out[r * 3 + c + 1] = rest[r + 1] * TMP[c + 1] + rest[r + 4] * TMP[c + 4] + rest[r + 7] * TMP[c + 7]
		end
	end
end
RigidMotion.boneTurn = boneTurn

-- The travelling wave down one chain: the amplitude grows to its end, `k` its share, `curl` the keyed curl.
local function waveChain(inst: Instance, chain: Chain, amp: number, k: number, curl: number, bones: { [string]: Mat })
	local lag = (inst.style.bones :: RigidStyles.Bones).lag
	local n = #chain.names
	for i, name in chain.names do
		local share = 0.55 + 0.45 * (i - 1) / math.max(1, n - 1)
		rotY(TURN, amp * k * share * math.sin(TAU * (inst.wave - (i - 1) * lag)) + curl * k / n)
		boneTurn(bones, name, chain.rest[i], TURN)
	end
end

local function bonesLayer(inst: Instance, c: Controls, t: number, dt: number)
	local chains = inst.chains
	local bones = inst.posed.bones
	if not chains or not bones then
		return
	end
	local spec = inst.style.bones
	if not spec then
		return
	end
	-- the wave runs with the distance travelled (a slither) and slowly in place (the coil breathing)
	local B = inst.body.B
	inst.wave = (inst.wave + dt * (inst.v / (spec.stride * B) + spec.idleHz * (1 - inst.move))) % 1
	local calmTail = math.clamp(c.calmTail or 0, 0, 1)
	local amp = (spec.idle + (spec.move - spec.idle) * inst.move) * (1 - calmTail)
	local curl = c.tC or 0
	if chains.tail then
		waveChain(inst, chains.tail, amp, 1, curl, bones)
	end
	if chains.coil then
		waveChain(inst, chains.coil, amp, spec.coil, curl, bones)
	end
	-- the neck: the cobra sway, the keyed strike (nP + = forward and down) and turn; the head keeps level
	local neck = chains.neck
	if neck then
		local n = #neck.names
		local sway = spec.sway * math.sin(TAU * spec.swayHz * (t + inst.seed)) * (1 - inst.move * 0.6) * (1 - calmTail)
		local nY, nP = (c.nY or 0) + sway, c.nP or 0
		for i, name in neck.names do
			local share = (0.6 + 0.8 * (i - 1) / math.max(1, n - 1)) / n
			rotY(TURN2, nY * share)
			rotX(TURN3, -nP * share)
			mulInto(TURN, TURN2, TURN3)
			boneTurn(bones, name, neck.rest[i], TURN)
		end
	end
	local head = chains.head
	if head then
		local nP = c.nP or 0
		for i, name in head.names do
			rotX(TURN, nP * 0.5 / #head.names + (c.hP or 0))
			boneTurn(bones, name, head.rest[i], TURN)
		end
	end
end

---------------------------------------------------------------- one frame

function RigidMotion.step(inst: Instance, input: Input): Posed
	local style = inst.style
	local body = inst.body
	local frozen = input.frozen == true
	if frozen then
		if inst.freezeAt == nil then
			inst.freezeAt = input.now
		end
	else
		inst.freezeAt = nil
	end
	-- frozen, every clock of the model stops (the pose holds)
	local now = inst.freezeAt or input.now
	local dt = if frozen then 0 else math.clamp(input.dt, 0, 0.1)
	local snap = input.snap == true
	-- 1. locomotion
	locomotion(inst, input, dt, now)
	local spec = style.bones
	if inst.chains and spec then
		-- the bones slither: the whole body only follows a little
		local loco = inst.loco
		loco.wig = (loco.wig or 0) * spec.body
		loco.x = (loco.x or 0) * spec.body
	end
	local c = inst.c
	table.clear(c)
	for key, v in inst.loco do
		c[key] = v
	end
	-- 2. idle, stance, calm
	idleLayer(inst, now, c)
	local combatTarget = if input.combat then 1 else 0
	local calmTarget = if input.returning then 1 else 0
	inst.combat = if snap then combatTarget else approach(inst.combat, combatTarget, 4, dt)
	inst.calm = if snap then calmTarget else approach(inst.calm, calmTarget, 3, dt)
	if inst.combat > 0.005 then
		addAll(c, style.stance, inst.combat * (1 - 0.6 * inst.move))
		local stalk = style.stalk
		if stalk then
			-- a cat stalks: low and slow while it fights at a walk
			local walk = inst.weights[style.order[1]] or 0
			addAll(c, stalk, inst.combat * inst.move * walk)
		end
	end
	if inst.calm > 0.005 then
		addAll(c, style.calm, inst.calm)
	end
	-- the turn lag: the root's yaw jumps (face() at 5 Hz) are taken back and spring to nothing
	local turn = style.turn
	if input.yawDelta then
		inst.turnOff = math.clamp(inst.turnOff - input.yawDelta, -TURN_MAX, TURN_MAX)
	end
	if snap then
		inst.turnOff, inst.turnVel = 0, 0
	else
		local left = dt
		while left > 0 do
			local h = math.min(left, 1 / 30)
			local a = turn.omega * turn.omega * -inst.turnOff - 2 * turn.omega * inst.turnVel
			inst.turnVel += a * h
			inst.turnOff += inst.turnVel * h
			left -= h
		end
	end
	add(c, "yaw", inst.turnOff)
	local bankMove = if style.fly then 1 else math.max(inst.move, 0.3)
	add(c, "roll", math.clamp(input.yawRate * turn.bank, -turn.bankMax, turn.bankMax) * bankMove)
	-- fidgets when idle, alone and still
	local run = input.action
	local action = if run then style.actions[run.name] else nil
	local busy = run ~= nil and action ~= nil and now - run.start < RigidMotion.length(action, run.hit)
	local fidget = inst.fidget
	if fidget and (busy or input.combat or inst.move > 0.2 or input.stun) then
		inst.fidget = nil
		fidget = nil
	end
	if not fidget and not busy and not input.combat and inst.move < 0.05 and now >= inst.nextFidget then
		local list = style.fidgets
		if #list > 0 then
			local n = math.floor(now * 7)
			local name = list[1 + math.floor(hash01(n, inst.seed) * #list) % #list]
			inst.fidget = { name = name, start = now, hit = 0.5, mirror = hash01(n + 1, inst.seed) < 0.5 }
			fidget = inst.fidget
		end
		local every = style.fidgetEvery
		inst.nextFidget = now + every[1] + hash01(math.floor(now) + 3, inst.seed) * (every[2] - every[1])
	end
	if now < inst.lastTime then
		inst.fidget = nil
		fidget = nil
		inst.nextFidget = now + style.fidgetEvery[1]
	end
	inst.lastTime = now
	-- 3. the keyed action (or a fidget)
	local tx, ty, tz = 0, 0, 0
	local actionW = 0
	local charged = false
	local playing: ActionRun? = if run and action then run else fidget
	local played = if playing then style.actions[playing.name] else nil
	if playing and played then
		local t = now - playing.start
		local length = RigidMotion.length(played, playing.hit)
		if t >= 0 and (t <= length or played.hold) then
			local tc = math.min(t, length)
			local sideMul = if playing.mirror then -1 else 1
			local fresh = inst.lockName ~= playing.name or inst.lockStart ~= playing.start
			if fresh and inst.wasActing and not snap then
				-- the new action starts from where the last one left the body
				local from = inst.fromC
				table.clear(from)
				for key, v in inst.lastC do
					from[key] = v
				end
				inst.fromT[1], inst.fromT[2], inst.fromT[3] = inst.lastT[1], inst.lastT[2], inst.lastT[3]
				inst.blendAt = now
			end
			if played.sided then
				-- deaths fall to the side away from the last blow from a side, else the seed's
				if fresh then
					local last = inst.lastSide
					inst.deathSide = if last == "left" then 1 elseif last == "right" then -1 else inst.deathSide
				end
				sideMul *= inst.deathSide
			end
			local keyed = inst.keyed
			sample(style, played, playing.hit, tc, keyed, sideMul)
			charged = played.tremble ~= nil
			-- the gather trembles more and more toward the strike; keyed shivers and shakes
			local a = bounds(played, playing.hit)
			if played.tremble then
				local p = if a > 0 then math.clamp(t / a, 0, 1) else 0
				local amp = if t < a then played.tremble * p * p else 0
				add(keyed, "pitch", amp * noise(now * 22, inst.seed, 1))
				add(keyed, "roll", amp * 0.8 * noise(now * 19, inst.seed, 2))
			end
			local shiver = keyed.shiver
			if shiver and shiver ~= 0 then
				add(keyed, "pitch", shiver * noise(now * 21, inst.seed, 3))
				add(keyed, "roll", shiver * noise(now * 23, inst.seed, 4))
				add(keyed, "yaw", shiver * 0.6 * noise(now * 17, inst.seed, 5))
			end
			local shake = keyed.shake
			if shake and shake ~= 0 then
				add(keyed, "roll", shake * math.sin(TAU * 5 * t))
			end
			-- the lunge closes the gap to the target: aimed until the strike starts, then locked
			if fresh then
				inst.lockName, inst.lockStart = playing.name, playing.start
				inst.lockX, inst.lockZ, inst.lockD = 0, -1, style.lunge.min * body.B
			end
			if t < a or snap then
				local look = input.look
				local front = body.B / 2 - body.z0
				if look then
					local fx, fz = look[1], look[3]
					local d = math.sqrt(fx * fx + fz * fz)
					if d > 1e-3 then
						inst.lockX, inst.lockZ = fx / d, fz / d
						inst.lockD = math.clamp(d - front - 1.0, style.lunge.min * body.B, style.lunge.max * body.B)
					end
				end
			end
			local lunge = keyed.lunge or 0
			tx += inst.lockX * inst.lockD * lunge
			tz += inst.lockZ * inst.lockD * lunge
			-- a flight: the server's Dash* arc, else toward the target with an arc of its own
			if played.flight then
				local flight = input.flight
				local hMesh = body.h - body.lift
				if flight then
					tx += flight.x
					ty += flight.y
					tz += flight.z
					local tilt = style.flightPitch
					add(keyed, "pitch", math.clamp(flight.pitch, -tilt[2], tilt[1]))
				else
					local travel = keyed.travel or 0
					local reach = playing.reach
					if travel > 0 and reach then
						local rx_, rz_ = reach[1], reach[3]
						local d = math.sqrt(rx_ * rx_ + rz_ * rz_)
						local k = if d > 1e-3 then math.max(0, d - (body.B / 2 - body.z0) - 0.5) / d else 0
						local H = math.clamp(0.25 * d * k, 0.5 * hMesh, 1.8 * hMesh) * (played.arc or 1)
						local tr = math.clamp(travel, 0, 1)
						tx += rx_ * k * tr
						tz += rz_ * k * tr
						ty += H * 4 * tr * (1 - tr)
						-- the body pitches along the arc while it flies (k of the travel 0 < tr < 1)
						if tr > 0 and tr < 1 and d * k > 1e-3 then
							local slope = math.atan2(H * 4 * (1 - 2 * tr), d * k)
							local tilt = style.flightPitch
							add(keyed, "pitch", math.clamp(slope, -tilt[2], tilt[1]))
						end
					end
				end
			end
			-- an action keyed from its own first pose (the appear: hidden, under the ground) starts in it at once
			local first = played.keys[1]
			local own = first ~= nil and first.seg == "A" and first.u == 0
			local w = if own then 1 else math.min(1, t / (if charged then CHARGED_IN else ACTION_IN))
			if not played.hold then
				w = math.min(w, math.max(0, (length - t) / ACTION_OUT))
			end
			w = MotionTimeline.ease("inout", w)
			actionW = w
			tx, ty, tz = tx * w, ty * w, tz * w
			if played.additive then
				-- a fidget plays over the idle
				for key, v in keyed do
					c[key] = (c[key] or 0) + v * w
				end
			else
				-- the action keys the whole body; the gait goes on underneath at a third (not under a death)
				local under = if played.hold then 0 else 0.3 * w
				for key, v in c do
					local kv = keyed[key] or 0
					c[key] = v + (kv - v) * w + (inst.loco[key] or 0) * under
				end
				for key, v in keyed do
					if c[key] == nil then
						c[key] = v * w
					end
				end
			end
		end
	end
	local handed = now - inst.blendAt
	if handed >= 0 and handed < HANDOVER and not snap then
		local k = MotionTimeline.ease("inout", handed / HANDOVER)
		local from = inst.fromC
		for key, v in c do
			local f = from[key] or 0
			c[key] = f + (v - f) * k
		end
		for key, v in from do
			if c[key] == nil then
				c[key] = v * (1 - k)
			end
		end
		local ft = inst.fromT
		tx, ty, tz = ft[1] + (tx - ft[1]) * k, ft[2] + (ty - ft[2]) * k, ft[3] + (tz - ft[3]) * k
	end
	local last = inst.lastC
	table.clear(last)
	for key, v in c do
		last[key] = v
	end
	inst.lastT[1], inst.lastT[2], inst.lastT[3] = tx, ty, tz
	inst.wasActing = actionW > 0.01
	-- 4. reactions: the flinch, stun, freeze
	local hitAt = input.hitAt
	if hitAt and input.hitSide then
		local t = now - hitAt
		local fl = style.flinch
		if t >= 0 and t < FLINCH_IN + FLINCH_HOLD + FLINCH_OUT then
			local e: number
			if t < FLINCH_IN then
				e = MotionTimeline.ease("out", t / FLINCH_IN)
			elseif t < FLINCH_IN + FLINCH_HOLD then
				e = 1
			else
				local u = (t - FLINCH_IN - FLINCH_HOLD) / FLINCH_OUT
				e = 1 - smooth(u) - 0.1 * math.sin(math.pi * u)
			end
			e *= if charged then 0.3 else 1 - 0.6 * actionW
			local side = input.hitSide
			inst.lastSide = side
			local push, tilt = fl.push, fl.tilt
			local centre = style.fly
			if side == "front" then
				add(c, "z", push * e)
				add(c, if centre then "pitch" else "rear", tilt * e)
			elseif side == "back" then
				add(c, "z", -push * e)
				if centre then
					add(c, "pitch", -tilt * e)
				else
					add(c, "dip", tilt * e)
				end
			elseif side == "left" then
				add(c, "x", push * body.B / body.W * e)
				add(c, if centre then "roll" else "tip", (if centre then -tilt else tilt) * e)
			else
				add(c, "x", -push * body.B / body.W * e)
				add(c, if centre then "roll" else "tip", (if centre then tilt else -tilt) * e)
			end
			add(c, "y", fl.drop * e)
			add(c, "sq", fl.squash * e)
		end
	end
	local stunTarget = if input.stun then 1 else 0
	inst.stunW = if snap then stunTarget else approach(inst.stunW, stunTarget, 1 / 0.15, math.max(dt, 0))
	if inst.stunW > 0.005 then
		local st = style.stun
		local w = inst.stunW * (1 - actionW)
		local tt = now + inst.seed
		add(c, "roll", st.roll * math.sin(TAU * st.hz * tt) * w)
		add(c, "pitch", st.pitch * math.sin(TAU * st.hz * 0.7 * tt + 1) * w)
		add(c, "y", st.drop * w)
		-- a twitch now and then
		local slot = math.floor(tt / 0.75)
		local lt = tt - slot * 0.75
		if hash01(slot, inst.seed) < 0.6 and lt < 0.14 then
			local dir = if hash01(slot + 7, inst.seed) < 0.5 then -1 else 1
			add(c, "yaw", st.twitch * dir * math.sin(math.pi * lt / 0.14) * w)
		end
	end
	if frozen then
		local a = math.rad(0.5)
		add(c, "pitch", a * noise(input.now * 25, inst.seed, 8))
		add(c, "roll", a * noise(input.now * 27, inst.seed, 9))
	end
	-- 5. the bones (a serpent with a skeleton) and the body
	bonesLayer(inst, c, now, dt)
	local posed = solve(inst, c, tx, ty, tz, input.squash == true and body.squash)
	posed.acting = actionW > 0.01
	return posed
end

---------------------------------------------------------------- the game's choices

-- The action of an attack: an ability (or kit blow) by its id, the thrown blow, else the regular blows in turn.
function RigidMotion.pick(style: Style, attackId: string?, shot: string?, count: number): string
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

-- Whether the blow `count` goes to the other side.
function RigidMotion.mirror(count: number): boolean
	return count % 2 == 0
end

-- The death of an instance: one of the style's, by its seed and the weights.
function RigidMotion.death(inst: Instance): string
	local list = inst.style.death
	local total = 0
	for _, entry in list do
		total += entry.weight
	end
	local roll = hash01(7, inst.seed) * total
	for _, entry in list do
		roll -= entry.weight
		if roll <= 0 then
			return entry.name
		end
	end
	return list[#list].name
end

-- The flinch side of a blow coming along `dir` (root-space direction from the attacker into the monster).
function RigidMotion.side(dir: Vec): string
	local x, z = dir[1], dir[3]
	if math.abs(z) >= math.abs(x) then
		return if z > 0 then "front" else "back"
	end
	return if x > 0 then "left" else "right"
end

return RigidMotion
