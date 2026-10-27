--!strict
-- NPC animation (owner 2026-10-26: "after the monsters, the NPCs": alive, believable, varied, never robotic). The motion
-- of a town NPC on the biped template (Logic/BipedPose controls, leg IK, the arms' canonical frame), in layers:
-- 1. the role's stance (Data/NpcStyles: a guard upright with his weapon, a merchant relaxed, an elder stooped), the
--    breath (irregular, deeper after work), the weight moving from one planted foot to the other (contrapposto: the
--    loaded hip up, the shoulders counter, the free knee eases and its heel lifts), a slow sway and idle glances;
-- 2. the work loop of the role (the smith's blows in series with rests, the merchant arranging his stall, the
--    innkeeper's rag, Teodor's channelling...): phrases of keyed moves picked by the NPC's seed;
-- 3. fidgets (scratch, stretch, the belt, hands on the hips...) and the greeting (a nod, a wave, a salute, a bow) when
--    a player first comes close;
-- 4. the talk while the dialogue is open: the NPC turns to the player (the head first, then the chest, the pelvis, and
--    the feet step after it), speaks in phrases of gestures with beats on the accents (open palms, a hand to the
--    chest, a shrug, pointing along the quest's way when there is one) and listens with nods between them;
-- 5. the look: the head (then the chest) turns to a player passing near, holds a few seconds, looks away;
-- 6. the feet (Logic/NpcSteps): planted, stepping when the body turns or walks (a sentry's beat, a server-moved NPC).
-- Moves key the arms either by controls or by a hand target on the body (chest, head, hips) or the ground, reached by
-- two-bone arm IK, so a hand on the chin or a rag on the counter fits every model's proportions.
-- Pure: client/Anim/NpcRig reads the rest frames and writes the Transforms; AnimLab plays it at a fixed time.

local BipedPose = require("./BipedPose")
local NpcPose = require("./NpcPose")
local NpcSteps = require("./NpcSteps")
local NpcStyles = require("../Data/NpcStyles")

local NpcMotion = {}

type Vec = { number }
type Mat = { number }
type Controls = BipedPose.Controls
type Move = NpcStyles.Move
type Target = NpcStyles.HandTarget

export type Person = { id: number, x: number, y: number, z: number, me: boolean? }
export type Input = {
	now: number,
	dt: number,
	snap: boolean?, -- a jump in time (AnimLab): the state starts over
	talk: boolean?, -- the dialogue (or a service window) with this NPC is open on this client
	partner: Vec?, -- the talking player's head (root space, studs, ground y = 0)
	people: { Person }?, -- players near (their heads, root space); the local one has `me`
	point: Vec?, -- root-space direction of the quest's way (the NPC points along it while talking)
	work: boolean?, -- false: no work loop (the model's Work attribute "none"); nil: the style's
	moved: Vec?, -- the root's own move since the last frame: { dx, dz, dyaw } in its previous frame
	force: string?, -- AnimLab: "fidget" (one after another), "greet" (once now), "pace" (the beat now), "point"
}
-- A hand's shape: grip 0 (open) .. 1 (fist), index 1 = pointing.
export type Hand = { grip: number, index: number }
-- One frame: the bones' world turns (root axes), the Hips offset, the hands' shapes and where the body stands from its
-- spot (studs, root axes: a sentry's beat; the hidden figure under an owner's model follows it with its name plate).
export type Posed = { world: BipedPose.World, shift: Vec, hands: { [string]: Hand }, offset: Vec }

-- Seconds the layers fade in and out.
local WORK_IN = 0.6
local WORK_OUT = 0.35
local TALK_IN = 0.35
local TALK_OUT = 0.6
local LOOK_IN = 0.18
local LOOK_OUT = 0.45
-- The look's springs (rad/s): the head is quick, the chest follows slowly; the shares and limits of the turn.
local HEAD_W = 11
local CHEST_W = 3.2
local CHEST_SHARE = 0.32
local CHEST_MAX = 0.42
local HEAD_MAX = 1.25
local PITCH_MAX = 0.45
-- The body's turn: spring (rad/s) and the most it turns per second; walking speed changes (studs/s per second).
local TURN_W = 4.2
local TURN_RATE = 2.6
local ACCEL = 2.8
-- AnimLab's walk for a style without a beat of its own.
local FORCED_PACE = { span = 2.6, every = { 5, 8 }, axis = "side" }
-- A person this close gets looked at even from behind (studs), and how far the NPC looks at people at all.
local CLOSE_BEHIND = 4.5
-- Seconds a greeted player has to be gone (beyond REGREET_FAR studs) before the NPC greets them again.
local REGREET_AFTER = 90
local REGREET_FAR = 22

local IDENTITY: Mat = NpcPose.IDENTITY
local mul, apply = NpcPose.mul, NpcPose.apply
local hash01 = NpcPose.hash01

local SIDES = { "R", "L" }
local NO_POSE: { [string]: number } = {}
-- The per-side names a frame reads and writes (no string building in the loop).
type SideKeys = {
	fx: string,
	fy: string,
	fz: string,
	fyaw: string,
	fp: string,
	toe: string,
	ay: string,
	wp: string,
	wy: string,
	wr: string,
	Shoulder: string,
	Arm: string,
	ForeArm: string,
	Hand: string,
}
local KEYS: { [string]: SideKeys } = {}
for _, s in SIDES do
	local side = if s == "R" then "Right" else "Left"
	KEYS[s] = {
		fx = `f{s}x`,
		fy = `f{s}y`,
		fz = `f{s}z`,
		fyaw = `f{s}yaw`,
		fp = `f{s}p`,
		toe = `t{s}`,
		ay = `a{s}y`,
		wp = `w{s}p`,
		wy = `w{s}y`,
		wr = `w{s}r`,
		Shoulder = `{side}Shoulder`,
		Arm = `{side}Arm`,
		ForeArm = `{side}ForeArm`,
		Hand = `{side}Hand`,
	}
end
local ARM_PARTS = { "Shoulder", "Arm", "ForeArm", "Hand" }
-- Leg lengths a hand's path between its own pose and a target bows forward at its middle.
local L_BOW = 0.24

---------------------------------------------------------------- small helpers

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function ease(kind: string?, x: number): number
	local t = math.clamp(x, 0, 1)
	if kind == "in" then
		return t * t * t
	elseif kind == "fall" then
		-- a swing gathering speed to the blow (a cubic would snap through the last frame)
		return t * t
	elseif kind == "out" then
		local u = 1 - t
		return 1 - u * u * u
	elseif kind == "lin" then
		return t
	end
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Smooth 1-D value noise in -1..1 (seeded; `salt` picks a stream).
local function noise(x: number, seed: number, salt: number): number
	local i = math.floor(x)
	local f = x - i
	local a = hash01(i * 13 + salt, seed) * 2 - 1
	local b = hash01((i + 1) * 13 + salt, seed) * 2 - 1
	return a + (b - a) * f * f * (3 - 2 * f)
end
NpcMotion.noise = noise

-- A critically damped spring toward `target` (x, v) with angular frequency `w`.
local function spring(x: number, v: number, target: number, w: number, dt: number): (number, number)
	local steps = math.max(1, math.ceil(dt * 60))
	local h = dt / steps
	for _ = 1, steps do
		local a = w * w * (target - x) - 2 * w * v
		v += a * h
		x += v * h
	end
	return x, v
end

local function add(c: Controls, key: string, v: number)
	c[key] = (c[key] or 0) + v
end

-- Yaw (+ = left) that turns the front (-Z) toward (dx, dz).
local function yawTo(dx: number, dz: number): number
	if dx * dx + dz * dz < 1e-8 then
		return 0
	end
	return math.atan2(-dx, -dz)
end
NpcMotion.yawTo = yawTo

local angleTo = NpcSteps.angleTo

-- Turns (x, z) by `yaw` about up.
local function turnXZ(x: number, z: number, yaw: number): (number, number)
	local c, s = math.cos(yaw), math.sin(yaw)
	return x * c + z * s, -x * s + z * c
end

---------------------------------------------------------------- the instance

type Running = { move: Move, start: number, rate: number, kind: string, name: string }
type Work = {
	weight: number,
	phrase: number, -- index into the work's phrases
	start: number, -- motion time the phrase started
	reps: number,
	length: number, -- seconds of one repetition
	rate: number,
	count: number, -- phrases so far (the seed's stream)
	resume: number, -- motion time before which the work stays paused
	effort: number, -- 0..1 breath after the blows
}
type Talk = {
	weight: number,
	since: number,
	speaking: boolean,
	phaseEnd: number,
	phases: number,
	gesture: Running?,
	gestures: number,
	pointedAt: number,
	nodAt: number,
	beatAt: number,
	beatSeen: number,
}
type Attention = {
	id: number?,
	since: number,
	untilT: number,
	nextAt: number,
	weight: number,
	yaw: number, -- head yaw total (relative to the pelvis) and its velocity
	yawV: number,
	chest: number,
	chestV: number,
	pitch: number,
	pitchV: number,
	count: number,
}
type Pace = { state: string, at: number, x: number, z: number, count: number }

export type Instance = {
	skel: BipedPose.Skeleton,
	style: NpcStyles.Style,
	seed: number,
	L: number,
	keep: { [string]: boolean }, -- arms that keep the model's own pose (they hold a prop): they ride the chest
	feet: NpcSteps.Feet,
	ankle: { [string]: Vec }, -- rest ankles (root space)
	centre: Vec, -- the turn centre: the rest Hips over the ground (root space)
	homeMid: { number }, -- the feet's mid point at home from the centre (x, z; body frame)
	lean: number, -- the stance's forward pitch that straightens a model sculpted leaning back
	raise: number, -- the pelvis' lift (leg lengths) that stands the legs straight over the feet at home
	hipY: number,
	headY: number,
	-- the body: centre on the ground (root space; at rest the centre above), velocity, facing and the facing it turns to
	bx: number,
	bz: number,
	vx: number,
	vz: number,
	yaw: number,
	yawV: number,
	goalYaw: number,
	still: number,
	last: number?, -- motion time of the last step
	-- clocks and drifts
	breath: number,
	shiftW: number,
	shiftFrom: number,
	shiftTo: number,
	shiftAt: number,
	shiftDur: number,
	shiftNext: number,
	shiftCount: number,
	glanceFrom: { number },
	glanceTo: { number },
	glanceAt: number,
	glanceNext: number,
	glanceCount: number,
	-- layers
	move: Running?,
	fidgetNext: number,
	fidgetCount: number,
	forced: number,
	work: Work,
	talk: Talk,
	attn: Attention,
	greeted: { [number]: number },
	away: { [number]: number },
	greetQueue: { id: number, at: number, me: boolean }?,
	pace: Pace,
	turnAway: number, -- 0..1: a worker facing its work behind it turns round to a player near
	layered: Layered, -- the frame's controls and hand targets (reused)
}

local function newState(inst: Instance, now: number)
	local seed = inst.seed
	inst.bx, inst.bz, inst.vx, inst.vz = inst.centre[1], inst.centre[3], 0, 0
	inst.yaw, inst.yawV, inst.goalYaw, inst.still = 0, 0, 0, 10
	inst.last = nil
	inst.breath = hash01(11, seed)
	inst.shiftW, inst.shiftFrom, inst.shiftTo, inst.shiftAt, inst.shiftDur = 0, 0, 0, now, 1
	inst.shiftNext = now + 1 + hash01(12, seed) * 4
	inst.shiftCount = 0
	inst.glanceFrom, inst.glanceTo, inst.glanceAt = { 0, 0 }, { 0, 0 }, now
	inst.glanceNext = now + 1.5 + hash01(13, seed) * 3
	inst.glanceCount = 0
	inst.move = nil
	local every = inst.style.fidgetEvery
	inst.fidgetNext = now + every[1] * 0.4 + hash01(14, seed) * (every[2] - every[1]) * 0.6
	inst.fidgetCount = 0
	inst.forced = 0
	inst.work = {
		weight = 0,
		phrase = 0,
		start = now,
		reps = 0,
		length = 0,
		rate = 1,
		count = math.floor(hash01(15, seed) * 7),
		resume = now,
		effort = 0,
	}
	inst.talk = {
		weight = 0,
		since = 0,
		speaking = false,
		phaseEnd = 0,
		phases = 0,
		gesture = nil,
		gestures = 0,
		pointedAt = -math.huge,
		nodAt = 0,
		beatAt = 0,
		beatSeen = 0,
	}
	inst.attn = {
		id = nil,
		since = now,
		untilT = now,
		nextAt = now,
		weight = 0,
		yaw = 0,
		yawV = 0,
		chest = 0,
		chestV = 0,
		pitch = 0,
		pitchV = 0,
		count = 0,
	}
	inst.greeted = {}
	inst.away = {}
	inst.greetQueue = nil
	local pace = inst.style.pace
	inst.pace = {
		state = "rest",
		at = now + (if pace then pace.every[1] * hash01(16, seed) else 0),
		x = 0,
		z = 0,
		count = 0,
	}
	inst.turnAway = 0
	NpcSteps.reset(inst.feet, inst.bx, inst.bz, 0)
end

-- The most an arm is twisted to bring its palm round (rad, over the shoulder and the elbow together).
local PALM_TWIST_MAX = 1.6

-- Turns the arms of `skel` about their own length so that each hand's palm (`palms[S]`: its rest normal, root space)
-- faces the thigh when the arm hangs (the canonical neutral every move is keyed for): a model exported with its palms
-- forward or down gestures like any other. Half the twist goes to the upper arm, the rest to the forearm, so neither
-- the shoulder nor the elbow wrings.
function NpcMotion.fitPalms(skel: BipedPose.Skeleton, palms: { [string]: Vec })
	for _, s in SIDES do
		local n = palms[s]
		if not n then
			continue
		end
		local p = apply(skel.foreFit[s], n)
		local want = if s == "R" then -1 else 1
		-- the turn about up (canonical down axis) that brings p's flat part onto (want, 0, 0)
		local flat = math.sqrt(p[1] * p[1] + p[3] * p[3])
		if flat < 0.3 then
			continue
		end
		local tau = math.atan2(p[3], p[1]) - math.atan2(0, want)
		tau = (tau + math.pi) % (2 * math.pi) - math.pi
		tau = math.clamp(tau, -PALM_TWIST_MAX, PALM_TWIST_MAX)
		skel.armFit[s] = mul(BipedPose.ry(tau * 0.5), skel.armFit[s])
		skel.foreFit[s] = mul(BipedPose.ry(tau), skel.foreFit[s])
	end
end

-- An NPC of style `style` (Data/NpcStyles.of) on skeleton `skel`; `seed` 0..1 makes it its own; `keep` names the arms
-- the model holds a prop with (Data/NpcRigs).
function NpcMotion.new(
	skel: BipedPose.Skeleton,
	style: NpcStyles.Style,
	seed: number,
	keep: { [string]: boolean }?
): Instance
	local bones = skel.bones
	local L = skel.legLength
	local hips = bones.Hips.pos
	local centre = { hips[1], 0, hips[3] }
	local ankle: { [string]: Vec } = {}
	local offset: { [string]: NpcSteps.Offset } = {}
	local width = style.stance.width or 0
	local toe = style.stance.toeOut or 0
	-- the stance: the feet side by side under the hip joints, a little wider (a model exported in mid-stride or with
	-- its legs spread stands square), turned out by the style's angle whatever the rest feet's own turn
	local half, back = 0, 0
	local restToe: { [string]: number } = {}
	for _, s in SIDES do
		local side = if s == "R" then "Right" else "Left"
		local a = bones[side .. "Foot"].pos
		ankle[s] = a
		half += math.abs(bones[side .. "UpLeg"].pos[1] - centre[1]) * 0.5
		back += (a[3] - centre[3]) * 0.5
		local toeBone = bones[side .. "ToeBase"]
		local m = if s == "R" then 1 else -1
		restToe[s] = if toeBone then math.atan2(m * (toeBone.pos[1] - a[1]), a[3] - toeBone.pos[3]) else 0
	end
	half = math.clamp(half * 1.15, 0.1 * L, 0.22 * L)
	back = math.clamp(back, -0.08 * L, 0.08 * L)
	for _, s in SIDES do
		local m = if s == "R" then 1 else -1
		local turn = math.clamp(toe - restToe[s], -0.45, 0.45)
		offset[s] = { x = m * (half + width * L), z = back, yaw = m * -turn }
	end
	-- the pelvis at the height where the legs, their feet at home, stand almost straight (a model exported in
	-- mid-stride would otherwise stand with bent knees)
	local raise = math.huge
	for _, s in SIDES do
		local side = if s == "R" then "Right" else "Left"
		local leg = skel.leg[s]
		local hip = bones[side .. "UpLeg"].pos
		local hx = offset[s].x - (hip[1] - centre[1])
		local hz = offset[s].z - (hip[3] - centre[3])
		local chain = leg.l1 + leg.l2
		local vertical = math.sqrt(math.max(0, chain * chain - hx * hx - hz * hz)) * 0.993
		raise = math.min(raise, ankle[s][2] + vertical - hip[2])
	end
	raise = math.clamp(raise, -0.03 * L, 0.08 * L)
	-- a model sculpted leaning back (the chest behind the hips) stands up straighter
	local neck = (bones.Neck or bones.Head).pos
	local lean = math.atan2(neck[3] - hips[3], math.max(0.1, neck[2] - hips[2]))
	local inst: Instance = {
		skel = skel,
		style = style,
		seed = seed,
		L = L,
		keep = keep or {},
		feet = NpcSteps.new(offset, L),
		ankle = ankle,
		centre = centre,
		homeMid = { 0, back },
		lean = math.clamp(lean * 0.6, -0.12, 0.12),
		raise = raise / L,
		hipY = hips[2],
		headY = bones.Head.pos[2],
		layered = { controls = {}, ik = { R = {}, L = {} } },
	} :: any
	newState(inst, 0)
	return inst
end

---------------------------------------------------------------- moves

-- A move's controls and hand targets at `t` seconds (its own clock): the arm and hand controls are absolute, the body's
-- add to the layers under it. Writes into `out` and `hands` (side -> list of { target, weight }); returns the move's
-- envelope weight and which arms it owns.
type HandEntry = { target: Target, k: number }
-- The hand entries of a frame, drawn from a pool (NpcMotion.step starts it over).
local POOL: { HandEntry } = {}
local pooled = 0
local function entry(target: Target, k: number): HandEntry
	pooled += 1
	local e = POOL[pooled]
	if e then
		e.target, e.k = target, k
	else
		e = { target = target, k = k }
		POOL[pooled] = e
	end
	return e
end

local function sampleMove(
	move: Move,
	t: number,
	out: Controls,
	hands: { [string]: { HandEntry } },
	edges: string?
): (number, boolean, boolean)
	local keys = move.keys
	local n = #keys
	local length = keys[n].t
	local fadeIn = move.fadeIn or 0.3
	local fadeOut = move.fadeOut or 0.4
	local wIn = if edges == "out" or edges == "none" then 1 else smooth(t / fadeIn)
	local wOut = if edges == "in" or edges == "none" then 1 else smooth((length - t) / fadeOut)
	local w = if move.hold then smooth(t / fadeIn) else wIn * wOut
	-- the keys around t
	local i = 1
	while i < n and keys[i + 1].t <= t do
		i += 1
	end
	local a = keys[i]
	local b = keys[math.min(n, i + 1)]
	local k = if b == a or b.t <= a.t then 1 else ease(b.ease, (t - a.t) / (b.t - a.t))
	if t <= keys[1].t then
		b, k = a, 1
	end
	local pa: { [string]: number } = a.pose or NO_POSE
	local pb: { [string]: number } = b.pose or NO_POSE
	for key, v in pa do
		out[key] = v + ((pb[key] or v) - v) * k
	end
	for key, v in pb do
		if pa[key] == nil then
			out[key] = v
		end
	end
	local osc = move.osc
	if osc then
		for _, o in osc do
			if t >= o.from and t <= o.to then
				local e = smooth((t - o.from) / 0.15) * smooth((o.to - t) / 0.15)
				out[o.c] = (out[o.c] or 0) + o.amp * e * math.sin(2 * math.pi * o.hz * (t - o.from))
			end
		end
	end
	local ownR, ownL = move.arms.R, move.arms.L
	for _, s in SIDES do
		local ta = (a :: any)[s] :: Target?
		local tb = (b :: any)[s] :: Target?
		local list = hands[s]
		if ta and tb and k < 1 then
			table.insert(list, entry(ta, 1 - k))
			table.insert(list, entry(tb, k))
		elseif tb and k >= 1 then
			table.insert(list, entry(tb, 1))
		elseif ta then
			table.insert(list, entry(ta, 1 - k))
		elseif tb then
			table.insert(list, entry(tb, k))
		end
	end
	return w, ownR, ownL
end

-- Lays a move's sample over `into` with weight `w`: the owned arms' controls blend toward it, the body's add; the hand
-- targets under it fade by its weight on the arms it owns.
local ARM_PREFIX: { [string]: string } = {}
for _, key in BipedPose.CONTROLS do
	local first = string.sub(key, 1, 1)
	if first == "a" or first == "e" or first == "w" or first == "c" then
		ARM_PREFIX[key] = if string.find(key, "R") then "R" else "L"
	end
end
for _, key in { "gR", "iR" } do
	ARM_PREFIX[key] = "R"
end
for _, key in { "gL", "iL" } do
	ARM_PREFIX[key] = "L"
end

type Layered = { controls: Controls, ik: { [string]: { HandEntry } } }

local function layer(
	into: Layered,
	sample: Controls,
	hands: { [string]: { HandEntry } },
	w: number,
	ownR: boolean,
	ownL: boolean
)
	if w <= 0 then
		return
	end
	local c = into.controls
	for key, v in sample do
		local side = ARM_PREFIX[key]
		if side then
			if (side == "R" and ownR) or (side == "L" and ownL) then
				local base = c[key] or 0
				c[key] = base + (v - base) * w
			end
		else
			c[key] = (c[key] or 0) + v * w
		end
	end
	for _, s in SIDES do
		local owns = if s == "R" then ownR else ownL
		local list = into.ik[s]
		if owns then
			for _, e in list do
				e.k *= 1 - w
			end
		end
		for _, e in hands[s] do
			table.insert(list, entry(e.target, e.k * w))
		end
	end
end

-- One move's sample (reused: a move is sampled and laid over at once).
local SAMPLE: Controls = {}
local SAMPLE_HANDS: { [string]: { HandEntry } } = { R = {}, L = {} }

-- `edges`: a repetition in a run of them fades only in ("in": the first), only out ("out": the last) or not at all
-- ("none"), so the repetitions run on one another.
local function sampleInto(into: Layered, move: Move, t: number, scale: number, edges: string?)
	table.clear(SAMPLE)
	table.clear(SAMPLE_HANDS.R)
	table.clear(SAMPLE_HANDS.L)
	local w, ownR, ownL = sampleMove(move, t, SAMPLE, SAMPLE_HANDS, edges)
	layer(into, SAMPLE, SAMPLE_HANDS, w * scale, ownR, ownL)
end

-- A move's length (seconds of its own clock).
function NpcMotion.moveLength(move: Move): number
	return move.keys[#move.keys].t
end

---------------------------------------------------------------- choices

-- The `n`-th pick from weighted `list` ({ name, weight }) by the instance's seed.
local function pick(list: { NpcStyles.Weighted }, n: number, seed: number, salt: number): NpcStyles.Weighted?
	local total = 0
	for _, e in list do
		total += e.weight
	end
	if total <= 0 then
		return nil
	end
	local r = hash01(n * 31 + salt, seed) * total
	for _, e in list do
		r -= e.weight
		if r <= 0 then
			return e
		end
	end
	return list[#list]
end

-- The move named `name`, mirrored to the free arm when the model holds a prop in the one it uses.
local function moveFor(inst: Instance, name: string): Move?
	local move = NpcStyles.MOVES[name]
	if not move then
		return nil
	end
	if (inst.keep.R and move.arms.R and not move.arms.L) or (inst.keep.L and move.arms.L and not move.arms.R) then
		return NpcStyles.MIRRORED[name]
	end
	return move
end

local function start(inst: Instance, name: string, kind: string, now: number): Running?
	local move = moveFor(inst, name)
	if not move then
		return nil
	end
	inst.fidgetCount += 1
	local rate = 1 + (hash01(inst.fidgetCount * 7 + 3, inst.seed) * 2 - 1) * 0.08
	return { move = move, start = now, rate = rate, kind = kind, name = name }
end

---------------------------------------------------------------- layers of state

local function updateShift(inst: Instance, now: number)
	local style = inst.style
	if now >= inst.shiftNext then
		inst.shiftCount += 1
		local n = inst.shiftCount
		local r = hash01(n * 5 + 1, inst.seed)
		-- mostly onto the other leg, now and then back to both
		local to = if r < 0.18
			then 0
			elseif inst.shiftTo > 0.2 then -1
			elseif inst.shiftTo < -0.2 then 1
			else (if r < 0.59 then 1 else -1)
		inst.shiftFrom = inst.shiftW
		inst.shiftTo = to * (0.65 + 0.35 * hash01(n * 5 + 2, inst.seed))
		inst.shiftAt = now
		inst.shiftDur = 0.9 + 0.6 * hash01(n * 5 + 3, inst.seed)
		local every = style.shiftEvery
		inst.shiftNext = now + inst.shiftDur + every[1] + hash01(n * 5 + 4, inst.seed) * (every[2] - every[1])
	end
	local k = ease("inout", (now - inst.shiftAt) / inst.shiftDur)
	inst.shiftW = inst.shiftFrom + (inst.shiftTo - inst.shiftFrom) * k
end

-- Idle glances with nobody to look at: every few seconds a new direction (ahead most often), reached in a quick head
-- turn; the role's scan (a guard) sweeps wider and holds longer.
local function updateGlance(inst: Instance, now: number): (number, number)
	local g = inst.style.glance
	if now >= inst.glanceNext then
		inst.glanceCount += 1
		local n = inst.glanceCount
		inst.glanceFrom = { inst.glanceTo[1], inst.glanceTo[2] }
		local r = hash01(n * 3 + 1, inst.seed)
		if r < g.ahead then
			inst.glanceTo = { (hash01(n * 3 + 2, inst.seed) * 2 - 1) * 0.08, g.pitch }
		else
			local side = if hash01(n * 3 + 2, inst.seed) < 0.5 then -1 else 1
			local yaw = side * (0.25 + 0.75 * hash01(n * 3 + 3, inst.seed)) * g.yaw
			local down = hash01(n * 3 + 4, inst.seed) < g.down
			inst.glanceTo = { yaw, if down then 0.35 else g.pitch + (hash01(n * 3 + 5, inst.seed) * 2 - 1) * 0.12 }
		end
		inst.glanceAt = now
		inst.glanceNext = now + g.every[1] + hash01(n * 3 + 6, inst.seed) * (g.every[2] - g.every[1])
	end
	local k = ease("inout", (now - inst.glanceAt) / g.turn)
	local f, t = inst.glanceFrom, inst.glanceTo
	return f[1] + (t[1] - f[1]) * k, f[2] + (t[2] - f[2]) * k
end

-- Who the NPC looks at: the dialogue's partner, else the most interesting player near (the local one most, a newcomer,
-- one coming closer); it holds a few seconds, looks away a while, then may look again.
local function updateAttention(inst: Instance, input: Input, now: number): (Person?, number?)
	local a = inst.attn
	local look = inst.style.look
	local people = input.people
	local best: Person? = nil
	local bestScore = 0
	local current: Person? = nil
	if people then
		for _, p in people do
			local d = math.sqrt((p.x - inst.bx) ^ 2 + (p.z - inst.bz) ^ 2)
			if p.id == a.id then
				current = p
			end
			if d <= look.range then
				local rel = math.abs(angleTo(inst.yaw, yawTo(p.x - inst.bx, p.z - inst.bz)))
				if rel < 2.1 or d < CLOSE_BEHIND then
					local score = (1 - d / look.range) * (if p.me then 1.6 else 1)
					if score > bestScore then
						best, bestScore = p, score
					end
				end
			end
		end
	end
	local held = a.id ~= nil and current ~= nil and now < a.untilT
	if held and current then
		local d = math.sqrt((current.x - inst.bx) ^ 2 + (current.z - inst.bz) ^ 2)
		if d > look.range * 1.15 then
			held = false
		end
	end
	if not held then
		if a.id ~= nil then
			-- looked long enough: look away a while
			a.id = nil
			a.count += 1
			a.nextAt = now + look.away[1] + hash01(a.count * 9 + 1, inst.seed) * (look.away[2] - look.away[1])
		end
		if best and now >= a.nextAt then
			a.count += 1
			a.id = best.id
			a.since = now
			local hold = look.hold[1] + hash01(a.count * 9 + 2, inst.seed) * (look.hold[2] - look.hold[1])
			a.untilT = now + hold * (if best.me then 1.4 else 1)
			current = best
		end
	end
	local target = if a.id ~= nil then current else nil
	return target, if target then now - a.since else nil
end

---------------------------------------------------------------- the frame

local DOWN_PITCH = 0

-- One frame: the world turns of the bones (root axes), the Hips offset and the hands' shapes.
function NpcMotion.step(inst: Instance, input: Input): Posed
	local now = input.now
	local dt = math.clamp(input.dt, 0, 0.25)
	if input.snap or inst.last == nil or now < (inst.last :: number) then
		newState(inst, now)
		dt = 0
	end
	inst.last = now
	pooled = 0
	local style = inst.style
	local seed = inst.seed
	local L = inst.L
	local feet = inst.feet
	local talking = input.talk == true and input.partner ~= nil

	-- the root's own move: the planted feet stay in the world
	local rootVx, rootVz = 0, 0
	local moved = input.moved
	if moved then
		local d = math.sqrt(moved[1] * moved[1] + moved[2] * moved[2])
		if d > 4 then
			NpcSteps.reset(feet, inst.bx, inst.bz, inst.yaw)
		elseif d > 1e-5 or math.abs(moved[3]) > 1e-5 then
			NpcSteps.shift(feet, moved[1], moved[2], moved[3])
			if dt > 0 then
				rootVx, rootVz = turnXZ(moved[1] / dt, moved[2] / dt, -moved[3])
			end
		end
	end

	-- greetings: a player first coming close (the local one always, another now and then)
	local people = input.people
	local greet = style.greet
	if people and greet then
		for _, p in people do
			local d = math.sqrt((p.x - inst.bx) ^ 2 + (p.z - inst.bz) ^ 2)
			local at: number? = inst.greeted[p.id]
			if d > REGREET_FAR then
				if at and not inst.away[p.id] then
					inst.away[p.id] = now
				end
			else
				inst.away[p.id] = nil
			end
			local gone = inst.away[p.id]
			if at and gone and now - gone > REGREET_AFTER and now - at > REGREET_AFTER then
				inst.greeted[p.id] = nil
				at = nil
			end
			if not at and d <= greet.range then
				inst.greeted[p.id] = now
				local friendly = p.me or hash01(p.id % 100000 + 77, seed) < 0.3
				if friendly and not talking and not inst.greetQueue then
					inst.greetQueue =
						{ id = p.id, at = now + 0.35 + 0.2 * hash01(p.id % 1000, seed), me = p.me == true }
					-- the look goes to them now
					inst.attn.id = p.id
					inst.attn.since = now
					inst.attn.untilT = now + 3.2
				end
			end
		end
	end
	if input.force == "greet" and not inst.greetQueue and not (inst.move and inst.move.kind == "greet") then
		inst.greetQueue = { id = -1, at = now, me = true }
	end

	-- attention
	local target, lookedFor = updateAttention(inst, input, now)
	if talking then
		target =
			{ id = -2, x = (input.partner :: Vec)[1], y = (input.partner :: Vec)[2], z = (input.partner :: Vec)[3] }
	end

	-- the talk's weight and its phases
	local talk = inst.talk
	if talking then
		if talk.weight <= 0 then
			talk.since = 0
			talk.speaking = false
			talk.phaseEnd = 0.55
			talk.phases = 0
			talk.gesture = nil
			talk.nodAt = 0.25
		end
		talk.since += dt
		talk.weight = math.min(1, talk.weight + dt / TALK_IN)
	else
		talk.weight = math.max(0, talk.weight - dt / TALK_OUT)
	end

	-- work: on unless talking, greeting or turned away from it; it resumes a while after
	local work = inst.work
	local workDef = style.work
	local wantWork = workDef ~= nil and input.work ~= false and talk.weight <= 0
	local workBehind = workDef ~= nil and workDef.behind == true
	-- a worker facing away turns round while a player stands near
	local nearMe = false
	if people then
		for _, p in people do
			if p.me and math.sqrt((p.x - inst.bx) ^ 2 + (p.z - inst.bz) ^ 2) < style.look.range * 0.75 then
				nearMe = true
			end
		end
	end
	if workBehind and nearMe then
		wantWork = false
	end
	if inst.greetQueue or (inst.move and inst.move.kind == "greet") then
		work.resume = math.max(work.resume, now + 0.6)
	end
	if not wantWork then
		work.resume = math.max(work.resume, now + (if talk.weight > 0 then 0.9 else 0.3))
	end
	local ready = wantWork and now >= work.resume
	-- work behind it starts once it has turned round to it
	local working = ready and (not workBehind or math.abs(angleTo(inst.yaw, math.pi)) < 0.35)
	if working then
		work.weight = math.min(1, work.weight + dt / WORK_IN)
	else
		work.weight = math.max(0, work.weight - dt / WORK_OUT)
	end
	if workDef and work.weight <= 0 and not working then
		-- a fresh phrase when it starts again
		work.start = now
		work.length = 0
	end

	-- the pace (a sentry's beat): rest at the spot, turn and walk out, look round, walk back, turn to the front
	local paceDef = style.pace or (if input.force == "pace" then FORCED_PACE else nil)
	local pace = inst.pace
	local homeX, homeZ = inst.centre[1], inst.centre[3]
	local goalX, goalZ = inst.bx, inst.bz
	local headingYaw: number? = nil
	if paceDef and not talking then
		if pace.state == "rest" and (now >= pace.at or (input.force == "pace" and pace.count == 0)) then
			pace.count += 1
			local side = if paceDef.axis == "front" then 0 else (if pace.count % 2 == 1 then 1 else -1)
			local dist = paceDef.span * (0.7 + 0.3 * hash01(pace.count * 11, seed))
			if paceDef.axis == "front" then
				pace.x, pace.z = homeX, homeZ - dist
			else
				pace.x, pace.z = homeX + side * dist, homeZ
			end
			pace.state = "out"
		end
		if pace.state == "out" or pace.state == "back" then
			goalX, goalZ = if pace.state == "out" then pace.x else homeX, if pace.state == "out" then pace.z else homeZ
			local dx, dz = goalX - inst.bx, goalZ - inst.bz
			local d = math.sqrt(dx * dx + dz * dz)
			if d < 0.08 and math.sqrt(inst.vx * inst.vx + inst.vz * inst.vz) < 0.3 then
				if pace.state == "out" then
					pace.state = "look"
					pace.at = now + 1.8 + 2 * hash01(pace.count * 11 + 1, seed)
				else
					pace.state = "rest"
					pace.at = now
						+ paceDef.every[1]
						+ hash01(pace.count * 11 + 2, seed) * (paceDef.every[2] - paceDef.every[1])
				end
			elseif d > 0.35 * L then
				-- (the last bit it sidles, without turning round)
				headingYaw = yawTo(dx, dz)
			end
		elseif pace.state == "look" then
			goalX, goalZ = pace.x, pace.z
			if now >= pace.at then
				pace.state = "back"
			end
		else
			goalX, goalZ = homeX, homeZ
		end
	elseif not talking and not paceDef then
		goalX, goalZ = homeX, homeZ
	end
	-- the work's own spot (up to the stall behind it)
	local stand = workDef and workDef.stand
	if ready and stand and not talking and (not paceDef or pace.state == "rest") then
		goalX, goalZ = homeX + stand[1] * L, homeZ + stand[2] * L
	end
	-- a goal farther than a sidle (a beat cut short, a shove): it turns and walks there
	if not headingYaw and not talking then
		local gx, gz = goalX - inst.bx, goalZ - inst.bz
		if gx * gx + gz * gz > (0.35 * L) ^ 2 then
			headingYaw = yawTo(gx, gz)
		end
	end

	-- the facing: the partner, the way it walks, the work behind it, a player who stays near, its own front
	local goalYaw = 0
	if talking then
		local p = input.partner :: Vec
		goalYaw = yawTo(p[1] - inst.bx, p[3] - inst.bz)
	elseif headingYaw then
		goalYaw = headingYaw
	elseif workBehind and ready then
		goalYaw = math.pi
	elseif target and lookedFor and lookedFor > 2.2 then
		-- someone standing near for a while: the body turns part of the way
		local toward = yawTo(target.x - inst.bx, target.z - inst.bz)
		if math.abs(toward) > 0.9 then
			goalYaw = math.clamp(toward * 0.55, -1.2, 1.2)
		end
	end
	-- keep to the short way round from where it faces (a full turn goes the nearer side)
	goalYaw = inst.yaw + angleTo(inst.yaw, goalYaw)
	inst.goalYaw = goalYaw
	local prevYaw = inst.yaw
	inst.yaw, inst.yawV = spring(inst.yaw, inst.yawV, goalYaw, TURN_W * style.tempo, dt)
	inst.yaw = prevYaw + math.clamp(inst.yaw - prevYaw, -TURN_RATE * dt, TURN_RATE * dt)
	inst.yawV = math.clamp(inst.yawV, -TURN_RATE, TURN_RATE)

	-- walking toward the goal once facing its way
	local dx, dz = goalX - inst.bx, goalZ - inst.bz
	local dist = math.sqrt(dx * dx + dz * dz)
	local wantVx, wantVz = 0, 0
	local current = math.sqrt(inst.vx * inst.vx + inst.vz * inst.vz)
	local near = dist < 0.35 * L and current < NpcSteps.WALK_FROM
	if dist > 0.03 and (near or math.abs(angleTo(inst.yaw, yawTo(dx, dz))) < 0.55) then
		-- the speed it can still brake from to stop on the goal
		local speed = math.min(style.walkSpeed, math.sqrt(2 * ACCEL * dist))
		local striding = paceDef ~= nil and (pace.state == "out" or pace.state == "back")
		if near or (dist < 0.6 * L and not striding) then
			-- a short shift (up to the stall, the last bit of a beat): a sidle of small steps, not a stride
			speed = math.min(speed, NpcSteps.WALK_FROM * 0.9)
		end
		wantVx, wantVz = dx / dist * speed, dz / dist * speed
	end
	-- the velocity changes at most by the walk's acceleration (a little more braking)
	local ax, az = wantVx - inst.vx, wantVz - inst.vz
	local change = math.sqrt(ax * ax + az * az)
	local limit = ACCEL * 1.3 * dt
	if change > limit then
		ax, az = ax * limit / change, az * limit / change
	end
	inst.vx += ax
	inst.vz += az
	inst.bx += inst.vx * dt
	inst.bz += inst.vz * dt

	-- the feet
	local turning = math.abs(inst.yaw - prevYaw) > 0.2 * dt or math.abs(angleTo(inst.yaw, goalYaw)) > 0.05
	local moving = inst.vx * inst.vx + inst.vz * inst.vz > 0.01
	inst.still = if turning or moving then 0 else inst.still + dt
	if dt > 0 then
		NpcSteps.step(feet, dt, {
			x = inst.bx,
			z = inst.bz,
			yaw = inst.yaw,
			goalYaw = goalYaw,
			vx = inst.vx + rootVx,
			vz = inst.vz + rootVz,
			room = if moved then nil else dist,
		}, inst.still, style.tempo)
	end
	local walkW = feet.heel

	---------------------------------------------------------------- controls
	local layered = inst.layered
	local c = layered.controls
	table.clear(c)
	for key, v in style.stance.pose do
		c[key] = v
	end
	table.clear(layered.ik.R)
	table.clear(layered.ik.L)
	add(c, "spitch", inst.lean)
	add(c, "py", inst.raise)
	local t = now + seed * 17.3

	-- breath: an irregular rhythm, deeper after effort
	local effort = work.effort
	local period = style.breath * (1 + 0.15 * noise(t * 0.13, seed, 3)) * (1 - 0.3 * effort)
	if dt > 0 then
		inst.breath = (inst.breath + dt / period) % 1
	end
	local ph = inst.breath
	-- a quicker inhale (42 %) than exhale
	local b = if ph < 0.42 then smooth(ph / 0.42) else 1 - smooth((ph - 0.42) / 0.58)
	local depth = style.breathDepth * (1 + 1.2 * effort)
	add(c, "spitch", -0.03 * b * depth)
	add(c, "cRu", 0.035 * b * depth)
	add(c, "cLu", 0.035 * b * depth)
	add(c, "aRo", 0.02 * b * depth)
	add(c, "aLo", 0.02 * b * depth)
	add(c, "hpitch", 0.015 * b * depth)
	add(c, "py", 0.004 * b * depth)

	-- the weight shift (contrapposto) and a slow sway; while one foot swings the weight is over the other
	if dt > 0 then
		updateShift(inst, now)
	end
	local stand = 1 - walkW
	local w = inst.shiftW * style.shift * stand * (1 - 0.6 * talk.weight)
	local support = NpcSteps.support(feet)
	local sway = noise(t * 0.21, seed, 5)
	local swayZ = noise(t * 0.17, seed, 6)
	add(c, "proll", 0.07 * w)
	add(c, "sroll", -0.09 * w)
	add(c, "hroll", 0.045 * w)
	add(c, "py", -0.01 * math.abs(w) - 0.015 * math.abs(support) * stand)
	add(c, "syaw", 0.025 * sway * style.sway)
	add(c, "sroll", 0.012 * sway * style.sway)
	add(c, "spitch", 0.012 * swayZ * style.sway)

	-- walking: the pelvis bobs twice a stride, sways over the stance foot, the arms swing against the legs
	if walkW > 0.01 then
		local a = 2 * math.pi * feet.phase
		add(c, "py", (-0.03 - 0.018 * math.cos(2 * a)) * walkW)
		add(c, "pyaw", 0.07 * math.sin(a) * walkW)
		add(c, "syaw", -0.08 * math.sin(a) * walkW)
		add(c, "proll", 0.03 * math.sin(a) * walkW)
		add(c, "spitch", 0.04 * walkW)
		add(c, "aRp", -0.22 * math.sin(a) * walkW)
		add(c, "aLp", 0.22 * math.sin(a) * walkW)
		add(c, "eR", (0.15 + 0.1 * math.max(0, -math.sin(a))) * walkW)
		add(c, "eL", (0.15 + 0.1 * math.max(0, math.sin(a))) * walkW)
	end

	-- the work loop
	local gazeYaw, gazePitch = updateGlance(inst, now)
	if workDef and work.weight > 0 then
		local rel = now - work.start
		if work.length <= 0 or rel >= work.length * work.reps then
			-- the next phrase
			work.count += 1
			local entry = pick(workDef.phrases, work.count, seed, 41)
			local index = 1
			for i, e in workDef.phrases do
				if e == entry then
					index = i
				end
			end
			local e = workDef.phrases[index]
			local move = moveFor(inst, e.name)
			work.phrase = index
			work.start = now
			work.rate = 1 + (hash01(work.count * 3 + 1, seed) * 2 - 1) * 0.06
			local reps = e.reps or { 1, 1 }
			work.reps = reps[1] + math.floor(hash01(work.count * 3 + 2, seed) * (reps[2] - reps[1] + 0.999))
			work.length = if move then NpcMotion.moveLength(move) / work.rate else 1
			rel = 0
		end
		local base = workDef.base
		if base then
			sampleInto(layered, base, 0.5, work.weight)
		end
		local e = workDef.phrases[work.phrase]
		local move = e and moveFor(inst, e.name)
		if move then
			local local_t = (rel % work.length) * work.rate
			-- the repetitions run on one another: only the first fades in and the last out
			local rep = math.floor(rel / work.length)
			local first, final = rep <= 0, rep >= work.reps - 1
			local edges = if first and final then nil elseif first then "in" elseif final then "out" else "none"
			sampleInto(layered, move, local_t, work.weight, edges)
			if e.effort then
				work.effort = math.min(1, work.effort + dt * e.effort)
			else
				work.effort = math.max(0, work.effort - dt * 0.12)
			end
		end
		local gz = workDef.gaze
		if gz then
			gazeYaw = gazeYaw + (gz[1] - gazeYaw) * work.weight * 0.85
			gazePitch = gazePitch + (gz[2] - gazePitch) * work.weight * 0.85
		end
	else
		work.effort = math.max(0, work.effort - dt * 0.12)
	end

	-- the hands' rest shape
	c.gR = c.gR or style.stance.grip
	c.gL = c.gL or style.stance.grip

	-- fidgets and the greeting (one move at a time; a greeting cuts a fidget short)
	local queue = inst.greetQueue
	if queue and now >= queue.at then
		inst.greetQueue = nil
		if not talking and greet then
			local name = if queue.me then greet.me else greet.other
			local m = start(inst, name, "greet", now)
			if m then
				inst.move = m
			end
		end
	end
	local forcedFidget = input.force == "fidget"
	if not inst.move and not talking and now >= inst.fidgetNext then
		if forcedFidget then
			inst.forced += 1
			local list = style.fidgets
			local e = list[(inst.forced - 1) % #list + 1]
			inst.move = start(inst, e.name, "fidget", now)
			inst.fidgetNext = now + 0.6
		elseif work.weight < 0.05 then
			local e = pick(style.fidgets, inst.fidgetCount + 1, seed, 53)
			if e then
				inst.move = start(inst, e.name, "fidget", now)
			end
			local every = style.fidgetEvery
			inst.fidgetNext = now + every[1] + hash01(inst.fidgetCount * 7 + 5, seed) * (every[2] - every[1])
		else
			inst.fidgetNext = now + 1.5
		end
	end
	local running = inst.move
	if running then
		local mt = (now - running.start) * running.rate
		local length = NpcMotion.moveLength(running.move)
		if mt >= length or (talking and running.kind == "fidget") then
			inst.move = nil
			if forcedFidget then
				inst.fidgetNext = now + 0.5
			end
		else
			sampleInto(layered, running.move, mt, 1)
			local gz = running.move.gaze
			if gz then
				local e = smooth(mt / 0.3) * smooth((length - mt) / 0.4)
				gazeYaw += (gz[1] - gazeYaw) * e
				gazePitch += (gz[2] - gazePitch) * e
			end
		end
	end

	-- talking: listen and speak in turns, gestures with beats on the accents, nods
	local pointYaw: number? = nil
	if talk.weight > 0 then
		local tw = smooth(talk.weight)
		local listen = moveFor(inst, style.talk.listen)
		if listen then
			sampleInto(layered, listen, 1, tw)
		end
		if talking then
			local ts = talk.since
			if ts >= talk.phaseEnd and not talk.gesture then
				talk.phases += 1
				local n = talk.phases
				-- the first phase speaks (after the turn); then listening and speaking in turns
				talk.speaking = n == 1 or not talk.speaking
				local span = if talk.speaking then style.talk.speak else style.talk.listenFor
				talk.phaseEnd = ts + span[1] + hash01(n * 13 + 1, seed) * (span[2] - span[1])
			end
			-- (a greeting under way finishes first)
			local greeting = inst.move ~= nil and (inst.move :: Running).kind == "greet"
			if talk.speaking and not talk.gesture and ts < talk.phaseEnd and not greeting then
				talk.gestures += 1
				local n = talk.gestures
				local list = style.talk.gestures
				local name: string? = nil
				-- the quest's way: pointed once in a while
				local pointNow = input.force == "point" and ts - talk.pointedAt > 4
				if input.point and (pointNow or (ts - talk.pointedAt > 9 and hash01(n * 17 + 2, seed) < 0.6)) then
					name = "talkPoint"
					talk.pointedAt = ts
				else
					local e = pick(list, n, seed, 61)
					name = if e then e.name else nil
				end
				if name then
					local m = moveFor(inst, name)
					if name == "talkPoint" and input.point then
						-- the arm on the side of the way (the other one when that hand holds the model's prop)
						local p = input.point
						local left = angleTo(inst.yaw, yawTo(p[1], p[3])) > 0
						if (left and not inst.keep.L) or (not left and inst.keep.R) then
							m = NpcStyles.MIRRORED.talkPoint
						else
							m = NpcStyles.MOVES.talkPoint
						end
					end
					if m then
						local rate = style.talk.energy * (1 + (hash01(n * 17 + 3, seed) * 2 - 1) * 0.1)
						talk.gesture = { move = m, start = ts, rate = rate, kind = "talk", name = name }
					end
				end
			end
		end
		local g = talk.gesture
		if g then
			local gt = (talk.since - g.start) * g.rate
			if gt >= NpcMotion.moveLength(g.move) then
				talk.gesture = nil
			else
				sampleInto(layered, g.move, gt, tw)
				if g.name == "talkPoint" and input.point then
					local p = input.point
					local py = angleTo(inst.yaw, yawTo(p[1], p[3]))
					pointYaw = py
					-- the hand goes the way, the head glances along it and back
					local e = smooth(gt / 0.45) * smooth((NpcMotion.moveLength(g.move) - gt) / 0.5)
					local side = if g.move.arms.L and not g.move.arms.R then "L" else "R"
					local m = if side == "R" then 1 else -1
					add(c, KEYS[side].ay, math.clamp(m * py, -0.9, 0.9) * e * tw)
					add(c, "syaw", math.clamp(py * 0.25, -0.3, 0.3) * e * tw)
				end
			end
		end
		-- the beats: quick dips of the gesturing forearm and the head on the accents while speaking
		if talking and talk.speaking then
			local ts = talk.since
			if ts >= talk.beatAt then
				talk.beatSeen += 1
				local n = talk.beatSeen
				talk.beatAt = ts + (0.28 + 0.34 * hash01(n * 7 + 1, seed)) / style.talk.energy
			end
			local since = ts - (talk.beatAt - (0.28 + 0.34 * hash01(talk.beatSeen * 7 + 1, seed)) / style.talk.energy)
			local beat = if since < 0.1 then ease("out", since / 0.1) else 1 - ease("inout", (since - 0.1) / 0.22)
			beat = math.max(0, beat) * tw * style.talk.beats
			local accent = 0.6 + 0.4 * hash01(talk.beatSeen * 7 + 2, seed)
			-- only the gesturing hands beat (a resting or pointing one keeps still)
			local g = talk.gesture
			local beatR = if g and g.name ~= "talkPoint" and g.move.arms.R then 1 else 0
			local beatL = if g and g.name ~= "talkPoint" and g.move.arms.L then 1 else 0
			add(c, "eR", -0.12 * beat * accent * beatR)
			add(c, "wRp", 0.18 * beat * accent * beatR)
			add(c, "eL", -0.12 * beat * accent * beatL)
			add(c, "wLp", 0.18 * beat * accent * beatL)
			add(c, "hpitch", 0.06 * beat * accent)
			add(c, "spitch", 0.015 * beat * accent)
		end
		-- nods: a double dip now and then while listening, one at the start
		if talking then
			local ts = talk.since
			if ts >= talk.nodAt + 1.2 and not talk.speaking then
				talk.nodAt = ts + 1.4 + 2.6 * hash01(math.floor(ts * 3) + 91, seed)
			end
			local nt = ts - talk.nodAt
			if nt >= 0 and nt < 0.9 then
				local nod = math.sin(math.clamp(nt / 0.9, 0, 1) * 2 * math.pi * (if talk.speaking then 0.5 else 1))
				add(c, "hpitch", 0.16 * math.max(0, nod) * tw)
			end
			add(c, "hroll", 0.06 * noise(ts * 0.35, seed, 9) * tw)
		end
	end

	-- the look: the target's direction relative to the pelvis, the head first, then the chest
	local a = inst.attn
	local lookTarget = if target then 1 else 0
	a.weight = if lookTarget > a.weight
		then math.min(1, a.weight + dt / LOOK_IN)
		else math.max(0, a.weight - dt / LOOK_OUT)
	local wantYaw, wantPitch = gazeYaw, gazePitch + DOWN_PITCH
	if target then
		local tx, tz = target.x - inst.bx, target.z - inst.bz
		local flat = math.sqrt(tx * tx + tz * tz)
		local yaw = angleTo(inst.yaw, yawTo(tx, tz))
		local pitch = math.atan2(inst.headY + 0.12 * L - target.y, math.max(0.5, flat))
		-- micro-saccades while holding the look
		yaw += 0.03 * noise(now * 0.8, seed, 21)
		pitch += 0.02 * noise(now * 0.7, seed, 22)
		local k = a.weight * style.look.weight * (if workDef and work.weight > 0 then style.look.atWork else 1)
		if talking then
			k = math.max(k, talk.weight)
		end
		wantYaw += (yaw - wantYaw) * k
		wantPitch += (pitch - wantPitch) * k
	end
	if pointYaw then
		local g = talk.gesture
		local gt = if g then (talk.since - g.start) * g.rate else 0
		local e = smooth((gt - 0.15) / 0.35) * smooth((1.35 - gt) / 0.35)
		wantYaw += (pointYaw - wantYaw) * e * 0.85
	end
	wantYaw = math.clamp(wantYaw, -(HEAD_MAX + CHEST_MAX), HEAD_MAX + CHEST_MAX)
	wantPitch = math.clamp(wantPitch, -PITCH_MAX, PITCH_MAX)
	local chestWant = math.clamp(wantYaw * CHEST_SHARE, -CHEST_MAX, CHEST_MAX)
	a.yaw, a.yawV = spring(a.yaw, a.yawV, wantYaw, HEAD_W * style.tempo, dt)
	a.chest, a.chestV = spring(a.chest, a.chestV, chestWant, CHEST_W * style.tempo, dt)
	a.pitch, a.pitchV = spring(a.pitch, a.pitchV, wantPitch, HEAD_W * 0.8 * style.tempo, dt)
	if dt <= 0 then
		a.yaw, a.chest, a.pitch = wantYaw, chestWant, wantPitch
		a.yawV, a.chestV, a.pitchV = 0, 0, 0
	end
	add(c, "syaw", a.chest)
	add(c, "hyaw", math.clamp(a.yaw - a.chest, -HEAD_MAX, HEAD_MAX))
	add(c, "hpitch", a.pitch * 0.85)
	add(c, "spitch", a.pitch * 0.15)

	---------------------------------------------------------------- legs and the body frame
	-- the frame the legs are solved in: turned with the feet (their mean yaw), about the rest Hips over the ground
	local xR, hR, zR, yawR, pitchR, toeR = NpcSteps.pose(feet, "R")
	local xL, hL, zL, yawL, pitchL, toeL = NpcSteps.pose(feet, "L")
	local frame = yawR + angleTo(yawR, yawL) * 0.5
	local cx, cz = inst.centre[1], inst.centre[3]
	-- the pelvis over the feet (standing: between them, loaded toward one) or over the body (walking)
	local midX, midZ = (xR + xL) * 0.5, (zR + zL) * 0.5
	local ox, oz = turnXZ(inst.homeMid[1], inst.homeMid[2], frame)
	-- standing: the pelvis rides between the feet; the load (shift, swing) moves it toward one of them
	local halfX, halfZ = (xR - xL) * 0.5, (zR - zL) * 0.5
	local load = math.clamp(w * 0.55 + support * 0.75, -1, 1) * 0.42
	local standX, standZ = midX - ox + halfX * load, midZ - oz + halfZ * load
	local px = standX + (inst.bx - standX) * walkW
	local pz = standZ + (inst.bz - standZ) * walkW
	-- into the frame (the pelvis' place relative to its rest, in leg lengths)
	local fx, fz = turnXZ(px - cx, pz - cz, -frame)
	add(c, "px", fx / L + 0.012 * sway * style.sway * stand)
	add(c, "pz", fz / L + 0.01 * swayZ * style.sway * stand)
	add(c, "pyaw", math.clamp(angleTo(frame, inst.yaw), -0.75, 0.75))
	local function footControls(s: string, x: number, h: number, z: number, yaw: number, pitch: number, toe: number)
		local an = inst.ankle[s]
		local lx, lz = turnXZ(x - cx, z - cz, -frame)
		local key = KEYS[s]
		c[key.fx] = (c[key.fx] or 0) + (lx + cx - an[1]) / L
		c[key.fz] = (c[key.fz] or 0) + (lz + cz - an[3]) / L
		-- the free foot of a shifted stance rests on its toes a little
		local free = if s == "R" then math.max(0, -w) else math.max(0, w)
		c[key.fy] = (c[key.fy] or 0) + h / L + 0.02 * free
		c[key.fyaw] = angleTo(frame, yaw) - (c.pyaw or 0) * 0.35
		c[key.fp] = (c[key.fp] or 0) + pitch - 0.1 * free
		c[key.toe] = (c[key.toe] or 0) + toe + 0.08 * free
	end
	footControls("R", xR, hR, zR, yawR, pitchR, toeR)
	footControls("L", xL, hL, zL, yawL, pitchL, toeL)
	-- a ghost floats: the whole body bobs, the feet hang with it
	if style.float then
		local bob = style.float * math.sin(t * 2 * math.pi / 3.4)
		add(c, "py", bob)
		add(c, "fRy", bob)
		add(c, "fLy", bob)
	end

	---------------------------------------------------------------- solve
	local world, shift = BipedPose.world(inst.skel, c, nil)
	-- the frame back into root space: everything turns by `frame` about the centre
	if math.abs(frame) > 1e-6 then
		local turn = BipedPose.ry(frame)
		for key, m in world do
			world[key] = mul(turn, m)
		end
		local hips = inst.skel.bones.Hips.pos
		local rx, rz = turnXZ(hips[1] + shift[1] - cx, hips[3] + shift[3] - cz, frame)
		shift = { rx + cx - hips[1], shift[2], rz + cz - hips[3] }
	end
	-- arms that hold the model's prop ride the chest
	local chest = world.Spine2 or world.Spine or IDENTITY
	for _, s in SIDES do
		if inst.keep[s] then
			local key = KEYS[s] :: any
			for _, part in ARM_PARTS do
				world[key[part]] = chest
			end
		end
	end
	-- hand targets: two-bone arm IK onto the body or the ground, blended with the arm's own pose by their weight
	local positions: { [string]: Vec }? = nil
	for _, s in SIDES do
		local list = layered.ik[s]
		local k = 0
		for _, e in list do
			k += e.k
		end
		if k > 0.005 and not inst.keep[s] then
			positions = positions or BipedPose.positions(inst.skel, world, shift)
			NpcMotion.reach(inst, world, positions :: any, s, list, math.min(1, k), c)
		end
	end
	return {
		world = world,
		shift = shift,
		offset = { inst.bx - cx, 0, inst.bz - cz },
		-- a hand that holds the model's prop keeps its fingers as modelled (the prop is skinned to them: a curl tore
		-- the guard's spear apart, studio review 2026-10-27)
		hands = {
			R = if inst.keep.R
				then { grip = 0, index = 0 }
				else { grip = math.clamp(c.gR or 0.3, 0, 1), index = math.clamp(c.iR or 0, 0, 1) },
			L = if inst.keep.L
				then { grip = 0, index = 0 }
				else { grip = math.clamp(c.gL or 0.3, 0, 1), index = math.clamp(c.iL or 0, 0, 1) },
		},
	}
end

-- Where a hand target is (root space): its landmark (a joint of the posed body and its turn, or the ground under the
-- NPC's own spot) plus the offset in that frame (leg lengths).
-- "chest": the base of the neck turned with the chest; "head": the head joint (about the jaw); "hips": the Hips joint.
local LANDMARK: { [string]: { string } } = {
	chest = { "Neck", "Spine2" },
	head = { "Head", "Head" },
	hips = { "Hips", "Hips" },
}

function NpcMotion.resolve(inst: Instance, world: BipedPose.World, positions: { [string]: Vec }, target: Target): Vec
	local L = inst.L
	local mark = LANDMARK[target.at]
	local o: Vec = { target.x * L, target.y * L, target.z * L }
	local p = mark and positions[mark[1]]
	if mark and p then
		local d = apply(world[mark[2]] or IDENTITY, o)
		return { p[1] + d[1], p[2] + d[2], p[3] + d[3] }
	end
	-- "ground": over the NPC's own spot (its rest Hips on the ground), in its rest front (a counter, an anvil)
	local c = inst.centre
	return { c[1] + o[1], o[2], c[3] + o[3] }
end

-- Puts the hand of side `s` on the weighted targets `list` (weight `k` over its own pose): the upper arm and forearm
-- by two-bone IK with the elbow toward the target's pole, the wrist keeping its controls.
function NpcMotion.reach(
	inst: Instance,
	world: BipedPose.World,
	positions: { [string]: Vec },
	s: string,
	list: { HandEntry },
	k: number,
	c: Controls
)
	local key = KEYS[s]
	local m = if s == "R" then 1 else -1
	local skel = inst.skel
	local bones = skel.bones
	local shoulder = positions[key.Arm]
	if not shoulder then
		return
	end
	-- the weighted target and pole
	local tx, ty, tz, total = 0, 0, 0, 0
	local px, py, pz = 0, 0, 0
	local chest = world.Spine2 or IDENTITY
	for _, e in list do
		if e.k > 0 then
			local p = NpcMotion.resolve(inst, world, positions, e.target)
			tx += p[1] * e.k
			ty += p[2] * e.k
			tz += p[3] * e.k
			local pole = e.target.pole or NpcStyles.POLE
			local q = apply(chest, { pole[1] * m, pole[2], pole[3] })
			px += q[1] * e.k
			py += q[2] * e.k
			pz += q[3] * e.k
			total += e.k
		end
	end
	if total <= 0 then
		return
	end
	local target = { tx / total, ty / total, tz / total }
	local pole = NpcPose.unit({ px, py, pz }) or { m, -0.3, 0.6 }
	local fkHand, fkElbow = positions[key.Hand], positions[key.ForeArm]
	-- the arm's own pose bent at the elbow: the solve starts exactly on it (its bend gives the arm's twist)
	local fromOwn = false
	if k < 0.999 and fkHand and fkElbow then
		-- part way (a hand reaching for its target or leaving it): the hand travels from where the arm's own pose
		-- holds it, bowed forward a little past the body, the elbow's bend turning with it; the bones' blend below
		-- then only evens out the twist (a straight blend of an arm raised overhead and one hanging would swing it
		-- through the body)
		local bow = 0.5 * L_BOW * inst.L * 4 * k * (1 - k)
		local ahead = apply(chest, { 0, 0, -1 })
		for i = 1, 3 do
			target[i] = fkHand[i] + (target[i] - fkHand[i]) * k + ahead[i] * bow
		end
		local hx, hy, hz = fkHand[1] - shoulder[1], fkHand[2] - shoulder[2], fkHand[3] - shoulder[3]
		local ex, ey, ez = fkElbow[1] - shoulder[1], fkElbow[2] - shoulder[2], fkElbow[3] - shoulder[3]
		local hh = hx * hx + hy * hy + hz * hz
		local along = if hh > 1e-9 then (ex * hx + ey * hy + ez * hz) / hh else 0
		local ox, oy, oz = ex - hx * along, ey - hy * along, ez - hz * along
		local own = NpcPose.unit({ ox, oy, oz })
		fromOwn = own ~= nil and math.sqrt(ox * ox + oy * oy + oz * oz) > 0.015 * inst.L
		if own then
			-- by way of the elbow out to the side: the bend never swings through the arm (its own pose's elbow
			-- back and a target's elbow forward would cross at nothing)
			local out = apply(chest, { m, 0.15, 0 })
			local from, to, q = own, out, k * 2
			if k > 0.5 then
				from, to, q = out, pole, k * 2 - 1
			end
			pole = NpcPose.unit({
				from[1] + (to[1] - from[1]) * q,
				from[2] + (to[2] - from[2]) * q,
				from[3] + (to[3] - from[3]) * q,
			}) or pole
		end
	end
	local arm, fore, hand = bones[key.Arm].pos, bones[key.ForeArm].pos, bones[key.Hand].pos
	local l1 = math.sqrt((fore[1] - arm[1]) ^ 2 + (fore[2] - arm[2]) ^ 2 + (fore[3] - arm[3]) ^ 2)
	local l2 = math.sqrt((hand[1] - fore[1]) ^ 2 + (hand[2] - fore[2]) ^ 2 + (hand[3] - fore[3]) ^ 2)
	local u, f = BipedPose.solveLeg(shoulder, target, l1, l2, pole)
	-- the canonical arm frame onto the solved arm: down -> u, the elbow's bend (-Z) -> toward the forearm
	local along = u[1] * f[1] + u[2] * f[2] + u[3] * f[3]
	local n = NpcPose.unit({ f[1] - u[1] * along, f[2] - u[2] * along, f[3] - u[3] * along })
		or NpcPose.unit({ pole[1], pole[2], pole[3] })
		or { 0, 0, -1 }
	local x = { u[2] * n[3] - u[3] * n[2], u[3] * n[1] - u[1] * n[3], u[1] * n[2] - u[2] * n[1] }
	local frameA = { x[1], -u[1], -n[1], x[2], -u[2], -n[2], x[3], -u[3], -n[3] }
	local e = math.acos(math.clamp(along, -1, 1))
	local elbow = mul(frameA, BipedPose.rx(e))
	local wrist =
		mul(mul(BipedPose.rx(c[key.wp] or 0), BipedPose.ry(m * (c[key.wy] or 0))), BipedPose.rz(m * (c[key.wr] or 0)))
	local armW = mul(frameA, skel.armFit[s])
	local foreW = mul(elbow, skel.foreFit[s])
	local handW = mul(mul(elbow, wrist), skel.foreFit[s])
	-- the solve already runs from the arm's own pose: no blend of the bones (which could take an arm raised overhead
	-- the long way round to its hanging pose)
	local b = if fromOwn then 1 else k
	if b >= 0.999 then
		world[key.Arm], world[key.ForeArm], world[key.Hand] = armW, foreW, handW
	else
		world[key.Arm] = BipedPose.slerp(world[key.Arm], armW, b)
		world[key.ForeArm] = BipedPose.slerp(world[key.ForeArm], foreW, b)
		world[key.Hand] = BipedPose.slerp(world[key.Hand], handW, b)
	end
end

return NpcMotion
