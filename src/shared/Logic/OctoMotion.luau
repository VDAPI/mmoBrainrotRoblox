--!strict
-- Template animation (owner 2026-10-31, docs/ANIM-WZORCE.md §6.6): the legs of a many-legged crawler with a skeleton
-- (Data/OctoRigs, Logic/OctoPose) under the body its rigid recipe moves (Data/RigidStyles through Logic/RigidMotion:
-- bob, sway, rear-ups, lunges, flights, deaths). Every frame, after RigidMotion has placed the body:
-- 1. the feet that stand are planted on the ground: each keeps its point in the world (the root's own move and turn are
--    taken back every frame), the leg bends to it by inverse kinematics, so nothing slides however the body bobs,
--    rears, flinches or lags in a turn;
-- 2. the gait: the recipe's phase (advanced by the distance the root covers) runs the legs in two alternating tetrads
--    (L1 R2 L3 R4 / R1 L2 R3 L4, a ripple back through each), the stride the recipe's; a foot leaves when its tetrad's
--    stance ends and lands ahead of its rest point by half the stance's travel (and turned on by half the stance's
--    turn), lifted along an arc whose height grows with the server's `Gait`; a tetrad's middle of stance is the top of
--    the recipe's step bob. Standing, the legs settle back under the body one after another; any foot left too far
--    behind (a lunge, a spin in place, a lag spike) or out of the leg's reach steps on its own (joining its tetrad's
--    swing when that comes; as many at once as leave three on the ground), lifted higher the farther it goes and
--    landing ahead of a body that keeps moving (a lunge); a teleport puts them all down at once;
-- 3. the idle: a leg shifts its footing now and then, the palps tap, the fangs chew, the abdomen breathes; on the move
--    the palps are carried up in front, feeling the way (too short to keep up with the stride);
-- 4. what the recipe keys: `raise` (the front pair and the palps lift into their raised pose: the foot out in front a
--    little over the hip, the knee up; blended from the standing pose joint by joint, so the foot rises on an arc),
--    `wave`, `stab` (they strike forward and down onto the ground ahead, `grip` closer in, and plant there), `tuck`
--    (every leg drawn in under the body: a flight, the spawn), `splay` (the feet set down wider: landings, slams),
--    `palp`, `fang`, the abdomen's pump (`gr`), the legs' tremble (`shiver`, stun) and the flinch of the legs on the
--    struck side (a standing foot trembles and flinches by lifting a touch on its point: it never slides);
-- 5. deaths: from the pose they had, the legs straighten in the jolt and curl in over the belly as the recipe's `fold`
--    grows (each leg at its own pace); RigidMotion lowers and topples the body over the folded box (OctoMotion.folds);
-- 6. on a ground that is not flat (the rig's ground probe, once per footfall) the body tilts with the plane of its feet;
-- 7. every drawn joint (and the yaw) turns at most JOINT_RATE (SAFE_RATE walking or striking, STAND_RATE standing on
--    its point under the body's own smooth move): whatever the solver or a key does, a joint never jumps between two
--    frames nor flips back and forth (tests/octomotion: under 12 degrees a frame in every AnimLab state and gait); a
--    long frame (a hitch) turns them no further than HITCH usual frames;
-- 8. a leg standing on its point holds the head of its last bone where it stands (Studio's planted slide is the head's,
--    not the tip's): only that bone turns and rolls (OctoPose.pinned) to put the tip on the point; a step, a stab and a
--    tuck rise straight up off it first and come straight down onto the next.
-- Pure: client/Anim/RigidRig feeds the root's move and the ground probe and writes the bones.

local NpcPose = require("./NpcPose")
local OctoPose = require("./OctoPose")
local RigidMotion = require("./RigidMotion")

local OctoMotion = {}

-- Which leg code runs (client/Anim/RigidRig stamps it on the look as the attribute `OctoVersion`; the Studio session
-- compares it with the commit it synced). Bumped with every change of the legs' behaviour.
OctoMotion.VERSION = "2026-11-01a last bone held on its point, straight up and down, legs written whole"

type Vec = { number }

-- Foot modes.
local PLANT, GAIT, STEP = 0, 1, 2

export type Foot = {
	mode: number,
	-- the planted point (ground frame: the look's rest frame under the root; it is carried back as the root moves)
	px: number,
	py: number,
	pz: number,
	-- a step: where it left from (carried like the planted point), the ground height at its goal, its offset from the
	-- rest point (an idle shift), its clock and lift
	sx: number,
	sy: number,
	sz: number,
	gy: number,
	ox: number,
	oz: number,
	-- the step's goal once it comes down (set at SET_AT of its swing; carried like the planted point): it lands where
	-- it set, straight down, whatever the body does meanwhile
	gx: number,
	gz: number,
	set: boolean,
	t0: number,
	dur: number,
	lift: number,
	-- the gait swing of this cycle has started (or was skipped)
	swung: boolean,
	-- the foot's target this frame (ground frame)
	x: number,
	y: number,
	z: number,
	-- the pose drawn (yaw, joint turns, then the last bone's roll: n + 1), the solver's pair standing on its point and
	-- striking (the next frame's guesses)
	psi: number,
	c: { number },
	a: number,
	b: number,
	sa: number,
	sb: number,
	want: { number }, -- scratch: the turns wanted this frame
	-- a death starts from this pose
	hold: { number },
	holdPsi: number,
	pace: number, -- the curl's exponent (its own pace)
	wave: number, -- its phase in a wave
	stabbed: boolean, -- the stab planted it (the key's rest is ignored until it falls)
	striking: boolean, -- a stab is on its way down (its own solver pair: sa, sb)
	airborne: boolean, -- drawn in for a flight: its rest point follows the body until it lands
	down: boolean, -- standing on the ground this frame (planted, nothing lifting it)
	miss: number, -- how far the solver's foot missed its target last frame (out of reach: it steps)
	rw: number, -- the raise and the stab on this leg (the keys followed at RAISE_RATE / STAB_RATE)
	sw: number,
	lag: number, -- how far the drawn pose trails the wanted one (rad, the most of its joints)
	ride: number, -- a palp riding with the body (1), let down onto its point over PALP_LET seconds
	-- standing on its point, the head of its last bone is pinned too (Studio review 2026-10-31: the mesh's last bone
	-- stands over the claw; a bone pivoting on its point slid its head along the ground): its place from the point
	-- (ground frame, carried with the root's turn), the last joint's turn on top of the solver's pair (let go on a step)
	pin: boolean,
	kx: number,
	ky: number,
	kz: number,
	ankle: number,
	roll: number,
	-- a stab over its point: the point (ground frame) it comes straight down on
	aimed: boolean,
	aimX: number,
	aimZ: number,
	swWas: number, -- the stab's key last frame (its pace)
}
export type Input = {
	dx: number?, -- the root's move this frame in its own frame before the turn (studs); nil: forward at the speed
	dz: number?,
	dyaw: number?, -- the root's turn this frame (rad, + left); nil: the yaw rate
	ground: ((x: number, z: number) -> number?)?, -- the ground's height under a point (ground frame); nil: flat
	coarse: boolean?, -- a far monster: fewer solver steps
}
export type Instance = {
	skel: OctoPose.Skeleton,
	seed: number,
	feet: { Foot },
	arms: { Foot },
	ready: boolean,
	duty: number,
	runW: number,
	lastPhase: number,
	rateHz: number,
	vx: number, -- the root's velocity in its frame (studs/s, smoothed)
	vz: number,
	moving: boolean,
	stopAt: number,
	lastStep: number,
	nextShift: number,
	nextTap: number,
	nextChew: number,
	deathAt: number?,
	tiltP: number, -- the ground plane under the feet (smoothed): pitch, roll, height
	tiltR: number,
	rise: number,
	fang: number, -- the fangs' turn this frame (rad)
	pump: number, -- the abdomen's
	tail: number, -- a tail's curl
	carry: number, -- the palps carried up on the move (0..1, smoothed)
	tuck: number, -- the legs drawn in (the recipe's `tuck`, smoothed)
	up: { { number }? }, -- each leg's raised pose (yaw, a, b), nil for a leg that takes no raise
	bx: number, -- the body's centre in the root's frame last frame, its velocity there (a lunge, smoothed)
	bz: number,
	ubx: number,
	ubz: number,
	walkers: number, -- the legs that carry it (not the palps)
	frame: number, -- the frame time it usually runs at (s, smoothed): a hitch never turns a joint further in a frame
	-- scratch
	m: { number },
}

local TAU = 2 * math.pi
local hash01 = NpcPose.hash01
local noise = RigidMotion.noise

-- Duty factor (share of the cycle on the ground) by the server's gait.
local DUTY = { walk = 0.68, trot = 0.62, run = 0.55 }
-- Each rank lifts this share of a cycle after the one in front of it (the ripple through a tetrad).
local LAG = 0.035
-- Step height (hip heights) at a walk and a run; a catch-up step's, an idle shift's, a palp's tap.
local LIFT_WALK, LIFT_RUN, LIFT_STEP, LIFT_SHIFT, LIFT_TAP = 0.16, 0.3, 0.16, 0.1, 0.12
-- Seconds of a settling step, an idle shift, a tap; the gap between two settling steps (a catch-up step: STEP_BASE on).
local STEP_SETTLE, STEP_SHIFT, STEP_TAP, SETTLE_GAP = 0.13, 0.17, 0.15, 0.05
-- A step's share of its swing by which it is over its goal (it comes straight down after); a step lasts at least this
-- many frames (a phone at 15 fps: no step of three frames, up, down and slid), never longer than STEP_SLOW for that.
local SET_AT, STEP_FRAMES, STEP_SLOW = 0.8, 4, 0.3
-- .. and by which it is up off its point before it travels (straight up from it: no slide along the ground as it
-- leaves; Studio review 2026-10-31).
local LIFT_FIRST = 0.15
-- .. and from which it comes down, most of the way while it slows over its goal (never dropped in a frame or two), but
-- never under STEP_FLOOR (hip heights, or its lift) till it is over it: the rest straight down.
local STEP_DOWN, STEP_FLOOR = 0.4, 0.05
-- A step of its own this far through when its tetrad swings goes on to land (the swing would yank it off its way).
local JOIN_BY = 0.3
-- A raised leg (the front pair, the palps; Studio review 2026-10-31: the tips at about the body's height, never a pole):
-- its foot this share of its length out in front, this many hip heights over the hip (times the leg's `front`), its
-- heading turned this share toward the front; a wave's lift (rad of `a`), yaw and rate.
local RAISE_OUT, RAISE_UP, RAISE_TURN = 0.6, 0.05, 0.45
-- How high over the ground a palp's stab stops (hip heights).
local PALP_HOVER = 0.2
-- The body darts on its own (a lunge, its recoil) faster than this (spans it goes in STEP_BASE): a palp rides with it,
-- a foot a stab planted lets go of its point (it steps before the leg is dragged off it).
local DART = 0.02
local PALP_LET = 0.3
-- A riding palp keeps this far over the ground (hip heights).
local PALP_CLEAR = 0.08
-- How high over the ground a stab keeps the foot on its way (hip heights at half way; nothing as it starts or lands).
local STAB_CLEAR = 0.3
-- A stab over its point aims where the body's own move will have taken it by the time it lands, at most STAB_AHEAD
-- seconds of the move ahead.
local STAB_AHEAD = 0.15
-- The share of the body's pitch a raised leg takes back (a rear-up lifts the body, not the raised legs on top of it).
local PITCH_HOLD = 0.7
local WAVE_LIFT, WAVE_YAW, WAVE_HZ = 0.12, math.rad(8), 3.2
-- A catch-up step: its lift per stud it travels (hip heights), the most; its seconds, plus per span it travels; how much
-- of the body's own move (a lunge) over the step it lands ahead by.
local STEP_ARC, LIFT_MAX, STEP_BASE, STEP_PER_SPAN, STEP_LONG, LEAD_BODY = 0.3, 0.45, 0.09, 0.06, 0.2, 0.6
-- The body's own move (spans a second) past which it hops (a lunge, a recoil): its legs all step together.
local DASH = 1.5
-- The fangs' full opening, the abdomen's pump per unit of the recipe's `gr`.
local FANG, PUMP = math.rad(24), 2.4
-- How deep a flight's tuck curls the legs; how much wider a splay sets them.
local TUCK, SPLAY = 0.55, 0.25
-- A leg drawn in from the ground lifts its foot this many hip heights, under its hip, by the time the tuck is TUCK_OFF.
local TUCK_LIFT, TUCK_OFF = 0.5, 0.5
-- The first TUCK_UP of it only lifts the foot straight off its point, the head of its last bone over where it stood.
local TUCK_UP = 0.2
-- The ground's tilt taken up by the body, its limit.
local TILT, TILT_MAX = 0.6, math.rad(20)
-- How high the palps are carried on the move (a share of the raise), their feeling wave.
local CARRY, CARRY_WAVE = 0.45, 0.35
-- A planted foot the leg misses by more than this (hip heights) steps to a point it reaches.
local MISS = 0.05
-- How fast the legs follow the recipe's `tuck` (share per second): drawn in over a few frames, never in one.
local TUCK_IN, TUCK_OUT = 6, 9
-- No drawn joint (nor a leg's yaw) turns faster than this (rad/s, about 9.5 degrees a frame at 60 fps): a target passing
-- right under a hip, a solver jumping to the other bend, a key or a death's jolt are followed, never snapped.
local JOINT_RATE = 10
-- How fast a leg takes up and lets go of the raise and the stab (share per second): a raise rises over a sixth of a
-- second at the least and lets go over a fifth; a stab strikes as keyed (on the hit), the raise giving way to it.
local RAISE_RATE, LET_GO = 6, 5
-- A leg that only walks or strikes (nothing else keyed on it, nothing trailing) follows its solver at up to this
-- (rad/s); one standing on its point follows the body at up to STAND_RATE (a planted foot never trails the body; the
-- body's own moves are smooth, so it never jumps), a solver jumping to the other bend still never snaps.
local SAFE_RATE, STAND_RATE = 12, 30
-- A frame this many times longer than the usual one (a hitch: Studio's 0.1 s stall at a strike) turns a joint no
-- further than the usual frame would at the rates above (a leg standing on its point keeps up with the body: it never
-- slides off its point after a stall). The usual frame follows the frame time at FRAME_RATE a frame.
local HITCH, FRAME_RATE = 1.5, 0.3
-- The last joint of a leg standing on its point turns at most ANKLE_MAX from the solver's and rolls its bone at most
-- ROLL_MAX out of the leg's plane (rad): beyond it the head lets go. On a step both let go at ANKLE_LET a second (off the
-- ground, where nothing shows it).
local ANKLE_MAX, ROLL_MAX, ANKLE_LET = 0.7, 1.2, 12
-- A head is pinned once the drawn foot is within PIN_AT of its point (studs); a pinned head the leg cannot hold with
-- its foot within PIN_LET of its point is let go of (the foot keeps its point, the head goes, pinned anew on it).
local PIN_AT, PIN_LET = 0.03, 0.06
-- A foot standing on its point it misses by more than HANG_AT (studs: out of reach) hangs straight over it.
local HANG_AT, HANG_TRIES = 0.02, 3

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

local function newFoot(n: number, seed: number, i: number): Foot
	return {
		mode = PLANT,
		px = 0,
		py = 0,
		pz = 0,
		sx = 0,
		sy = 0,
		sz = 0,
		gy = 0,
		ox = 0,
		oz = 0,
		t0 = 0,
		dur = 0.1,
		lift = 0,
		swung = false,
		x = 0,
		y = 0,
		z = 0,
		psi = 0,
		c = table.create(n + 1, 0),
		a = 0,
		b = 0,
		sa = 0,
		sb = 0,
		want = table.create(n + 1, 0),
		hold = table.create(n + 1, 0),
		holdPsi = 0,
		pace = 0.75 + 0.55 * hash01(40 + i, seed),
		wave = hash01(60 + i, seed) * TAU,
		stabbed = false,
		striking = false,
		airborne = false,
		down = true,
		miss = 0,
		rw = 0,
		sw = 0,
		lag = 0,
		ride = 0,
		pin = false,
		kx = 0,
		ky = 0,
		kz = 0,
		ankle = 0,
		roll = 0,
		aimed = false,
		aimX = 0,
		aimZ = 0,
		swWas = 0,
		gx = 0,
		gz = 0,
		set = false,
	}
end

-- The raised pose of a leg that takes a raise (its `front` > 0): the foot out in front of the hip and a little over it,
-- turned toward the front; the pair the solver finds from a bent knee (yaw, a, b).
local function raised(leg: OctoPose.Leg, hipH: number): { number }?
	if leg.front <= 0 then
		return nil
	end
	local heading = leg.yaw0 * (1 - RAISE_TURN)
	local out = RAISE_OUT * leg.reach
	local hip = leg.hip
	local tx, tz = hip[1] - math.sin(heading) * out, hip[3] - math.cos(heading) * out
	local psi, a, b = OctoPose.solve(leg, tx, hip[2] + RAISE_UP * hipH * leg.front, tz, 0.4, 0.4, 40)
	-- (and how much of the body's pitch its lift feels: a leg reaching forward rises with a rearing body)
	return { psi, a, b, math.cos(heading) }
end

function OctoMotion.new(skel: OctoPose.Skeleton, seed: number): Instance
	local feet: { Foot } = {}
	local up: { { number }? } = {}
	local walkers = 0
	for i, leg in skel.legs do
		feet[i] = newFoot(leg.n, seed, i)
		up[i] = raised(leg, skel.hipH)
		if not leg.palp then
			walkers += 1
		end
	end
	local arms: { Foot } = {}
	for i, arm in skel.arms do
		arms[i] = newFoot(arm.n, seed, 20 + i)
	end
	return {
		skel = skel,
		seed = seed,
		feet = feet,
		arms = arms,
		ready = false,
		duty = DUTY.walk,
		runW = 0,
		lastPhase = 0,
		rateHz = 0,
		vx = 0,
		vz = 0,
		moving = false,
		stopAt = -math.huge,
		lastStep = -math.huge,
		nextShift = 1 + hash01(70, seed) * 2,
		nextTap = 0.5 + hash01(71, seed) * 2,
		nextChew = 2 + hash01(72, seed) * 4,
		deathAt = nil,
		tiltP = 0,
		tiltR = 0,
		rise = 0,
		fang = 0,
		pump = 0,
		tail = 0,
		carry = 0,
		tuck = 0,
		up = up,
		bx = 0,
		bz = 0,
		ubx = 0,
		ubz = 0,
		walkers = walkers,
		frame = 1 / 60,
		m = table.create(12, 0),
	}
end

---------------------------------------------------------------- frames

-- The body's transform (rotation row-major 1..9, translation 10..12): a look-frame point into the ground frame.
local function toGround(m: { number }, x: number, y: number, z: number): (number, number, number)
	return m[1] * x + m[2] * y + m[3] * z + m[10],
		m[4] * x + m[5] * y + m[6] * z + m[11],
		m[7] * x + m[8] * y + m[9] * z + m[12]
end

-- .. and back.
local function toLook(m: { number }, x: number, y: number, z: number): (number, number, number)
	local qx, qy, qz = x - m[10], y - m[11], z - m[12]
	return m[1] * qx + m[4] * qy + m[7] * qz, m[2] * qx + m[5] * qy + m[8] * qz, m[3] * qx + m[6] * qy + m[9] * qz
end

-- A world-fixed point in the ground frame after the root moved (dx, dz) in its old frame and turned dyaw.
local function carry(x: number, z: number, dx: number, dz: number, cs: number, sn: number): (number, number)
	local qx, qz = x - dx, z - dz
	-- turned by -dyaw: x' = x cos - z sin, z' = x sin + z cos
	return qx * cs - qz * sn, qx * sn + qz * cs
end

-- The body's heading (its forward axis laid flat: cos, sin) and its centre on the ground this frame (ground frame), set
-- once per frame.
local HCS, HSN, BCX, BCZ = 1, 0, 0, 0

local function bodyFrame(skel: OctoPose.Skeleton, m: { number })
	local hx, hz = m[3], m[9]
	local len = math.sqrt(hx * hx + hz * hz)
	HCS, HSN = 1, 0
	if len > 1e-4 then
		HCS, HSN = hz / len, hx / len
	end
	local bx, _, bz = toGround(m, skel.cx, skel.ground + skel.hipH, skel.cz)
	BCX, BCZ = bx, bz
end

-- The rest point of leg `leg` under the body now (ground frame, flat: the body's heading and place, not its pitch),
-- set `splay` wider, plus an offset (look frame).
local function neutral(
	skel: OctoPose.Skeleton,
	leg: OctoPose.Leg,
	splay: number,
	ox: number,
	oz: number
): (number, number)
	local k = 1 + SPLAY * splay
	local hip = leg.hip
	local fx = hip[1] + (leg.foot[1] - hip[1]) * k + ox - skel.cx
	local fz = hip[3] + (leg.foot[3] - hip[3]) * k + oz - skel.cz
	return BCX + fx * HCS + fz * HSN, BCZ - fx * HSN + fz * HCS
end

-- The ground's height under (x, z) (ground frame): the probe within reason, else the flat ground.
local function groundAt(skel: OctoPose.Skeleton, input: Input, x: number, z: number): number
	local probe = input.ground
	if probe then
		local y = probe(x, z)
		if y and math.abs(y - skel.ground) < 1.2 * skel.hipH then
			return y
		end
	end
	return skel.ground
end

-- Starts a timed step of `f` from where it is to its rest point (plus an offset), `seconds` long (`least` at least),
-- `lift` hip heights. It began a frame ago (what made it step came within the last frame; no further back than its
-- straight lift): the frame shows it already off the ground, never dragged along it toward a point the body has left
-- out of reach.
local function startStep(
	f: Foot,
	now: number,
	dt: number,
	least: number,
	seconds: number,
	lift: number,
	ox: number,
	oz: number,
	gy: number
)
	seconds = math.max(seconds, least)
	f.mode = STEP
	f.sx, f.sy, f.sz = f.x, f.y, f.z
	f.t0, f.dur, f.lift = now - math.min(dt, seconds / STEP_FRAMES, LIFT_FIRST * seconds), seconds, lift
	f.ox, f.oz, f.gy = ox, oz, gy
	f.set = false
end

-- The turns of the pair (a, b) with the foot's last joint turned and its bone rolled on top, into `want`.
local function turnsOf(leg: OctoPose.Leg, f: Foot, a: number, b: number, want: { number })
	OctoPose.turns(leg, a, b, want)
	want[leg.n] += f.ankle
	want[leg.n + 1] = f.roll
end

-- The yaw and pair that put the foot on (tx, ty, tz) (look frame) with its last joint's turn and its bone's roll on top:
-- the point taken back by where the roll moves the foot first (once is enough: the roll only lets go).
local function solveFoot(
	leg: OctoPose.Leg,
	f: Foot,
	tx: number,
	ty: number,
	tz: number,
	a: number,
	b: number,
	iters: number,
	want: { number }
): (number, number, number)
	local psi
	psi, a, b = OctoPose.solve(leg, tx, ty, tz, a, b, iters, f.ankle)
	if f.roll ~= 0 then
		turnsOf(leg, f, a, b, want)
		local rx, ry, rz = OctoPose.foot(leg, psi, want)
		want[leg.n + 1] = 0
		local px, py, pz = OctoPose.foot(leg, psi, want)
		psi, a, b = OctoPose.solve(leg, tx - (rx - px), ty - (ry - py), tz - (rz - pz), a, b, iters, f.ankle)
	end
	return psi, a, b
end

local function land(f: Foot, x: number, y: number, z: number)
	f.mode = PLANT
	f.px, f.py, f.pz = x, y, z
	f.x, f.y, f.z = x, y, z
	f.ox, f.oz = 0, 0
end

-- The foot along a step's arc at `q` (0..1) from its start to (gx, gy, gz): it lifts and sets down gently (no jolt in
-- the joints as a step starts), rising before it travels. A step of its own (`set`) is over its goal by SET_AT and comes
-- straight down from there onto where the goal was then (a gait's swing lands on its moving goal: its lead is reckoned
-- for that); standing (`straight`), it also rises straight up off its point till LIFT_FIRST and keeps over STEP_FLOOR
-- on its way (Studio review 2026-10-31: no slide along the ground as it leaves or lands).
local function arc(
	f: Foot,
	q: number,
	gx: number,
	gz: number,
	hipH: number,
	outX: number,
	outZ: number,
	set: boolean,
	straight: boolean
)
	local h = q
	local high = f.lift * hipH
	local y
	if set and not straight then
		if q >= SET_AT then
			if not f.set then
				f.set = true
				f.gx, f.gz = gx, gz
			end
			gx, gz = f.gx, f.gz
		end
		h = math.clamp(q / SET_AT, 0, 1)
		y = high * math.sin(math.pi * math.clamp(q, 0, 1) ^ 0.8) ^ 2
	elseif set then
		if q >= SET_AT then
			if not f.set then
				f.set = true
				f.gx, f.gz = gx, gz
			end
			gx, gz = f.gx, f.gz
		end
		h = math.clamp((q - LIFT_FIRST) / (SET_AT - LIFT_FIRST), 0, 1)
		local rise = smooth(q / (2 * LIFT_FIRST))
		local wide = math.min(rise, 1 - smooth((q - STEP_DOWN) / (1 - STEP_DOWN)))
		local over = math.min(rise, 1 - smooth((q - SET_AT) / (1 - SET_AT)))
		y = math.max(high * wide, math.min(high, STEP_FLOOR * hipH) * over)
	else
		y = high * math.sin(math.pi * math.clamp(q, 0, 1) ^ 0.8) ^ 2
	end
	local e = h * h * (3 - 2 * h)
	local bulge = 0.06 * (if set and straight then math.sin(math.pi * h) else y / math.max(high, 1e-6))
	f.x = f.sx + (gx - f.sx) * e + outX * bulge
	f.z = f.sz + (gz - f.sz) * e + outZ * bulge
	f.y = f.sy + (f.gy - f.sy) * e + y
end

---------------------------------------------------------------- the ground plane

-- Pre-multiplies the body's transform by small turns about the ground point (px, pz) under it: pitch about x, roll
-- about z, and lifts it by `rise`.
local function tilt(
	m: { number },
	a: { number },
	pitch: number,
	roll: number,
	rise: number,
	px: number,
	py: number,
	pz: number
)
	if pitch == 0 and roll == 0 and rise == 0 then
		return
	end
	local cp, sp, cr, sr = math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
	-- R = Rz(roll) * Rx(pitch)
	local r00, r01, r02 = cr, -sr * cp, sr * sp
	local r10, r11, r12 = sr, cr * cp, -cr * sp
	local r20, r21, r22 = 0, sp, cp
	for i = 1, 12 do
		a[i] = m[i]
	end
	for col = 0, 2 do
		local x, y, z = a[1 + col], a[4 + col], a[7 + col]
		m[1 + col] = r00 * x + r01 * y + r02 * z
		m[4 + col] = r10 * x + r11 * y + r12 * z
		m[7 + col] = r20 * x + r21 * y + r22 * z
	end
	local qx, qy, qz = a[10] - px, a[11] - py, a[12] - pz
	m[10] = px + r00 * qx + r01 * qy + r02 * qz
	m[11] = py + r10 * qx + r11 * qy + r12 * qz + rise
	m[12] = pz + r20 * qx + r21 * qy + r22 * qz
end

-- The plane through the planted feet (least squares): height at the body's centre and slopes along x and z.
local function plane(inst: Instance, cx: number, cz: number): (number, number, number, boolean)
	local n, sx, sz, sy, sxx, szz, sxz, sxy, szy = 0, 0, 0, 0, 0, 0, 0, 0, 0
	for _, f in inst.feet do
		if f.down then
			local x, z, y = f.px - cx, f.pz - cz, f.py - inst.skel.ground
			n += 1
			sx += x
			sz += z
			sy += y
			sxx += x * x
			szz += z * z
			sxz += x * z
			sxy += x * y
			szy += z * y
		end
	end
	if n < 3 then
		return 0, 0, 0, false
	end
	-- the normal equations of y = h + gx x + gz z (Cramer's rule)
	local a11, a12, a13, a22, a23, a33 = n, sx, sz, sxx, sxz, szz
	local det = a11 * (a22 * a33 - a23 * a23) - a12 * (a12 * a33 - a23 * a13) + a13 * (a12 * a23 - a22 * a13)
	if math.abs(det) < 1e-9 then
		return 0, 0, 0, false
	end
	local b1, b2, b3 = sy, sxy, szy
	local d1 = b1 * (a22 * a33 - a23 * a23) - a12 * (b2 * a33 - a23 * b3) + a13 * (b2 * a23 - a22 * b3)
	local d2 = a11 * (b2 * a33 - a23 * b3) - b1 * (a12 * a33 - a23 * a13) + a13 * (a12 * b3 - b2 * a13)
	local d3 = a11 * (a22 * b3 - b2 * a23) - a12 * (a12 * b3 - b2 * a13) + b1 * (a12 * a23 - a22 * a13)
	return d1 / det, d2 / det, d3 / det, true
end

---------------------------------------------------------------- one frame

-- The legs' pose for the frame RigidMotion just posed (`rigid` after its step, `input` its input, `posed` its pose:
-- the body's transform may be tilted here). Reads the root's move and the ground from `octo`.
function OctoMotion.step(
	inst: Instance,
	rigid: RigidMotion.Instance,
	input: RigidMotion.Input,
	posed: RigidMotion.Posed,
	octo: Input
)
	local skel = inst.skel
	local legs = skel.legs
	local feet = inst.feet
	local frozen = input.frozen == true
	local now = rigid.freezeAt or input.now
	local dt = if frozen then 0 else math.clamp(input.dt, 0, 0.1)
	local snap = input.snap == true or not inst.ready
	local c = rigid.c
	local hipH = skel.hipH
	local seed = inst.seed
	local iters = if octo.coarse then 2 else 4
	-- the action (a death holds its last pose)
	local run = input.action
	local action = if run then rigid.style.actions[run.name] else nil
	local dying = run ~= nil and action ~= nil and action.hold == true and now >= run.start
	-- 0. the ground under the feet tilts the body (fading while it flies or dies)
	local m = posed.m
	local planted = 0
	for _, f in feet do
		if f.down then
			planted += 1
		end
	end
	local onFeet = not dying and planted >= 3 and octo.ground ~= nil
	local bx0, _, bz0 = toGround(m, skel.cx, skel.ground, skel.cz)
	local h, gx, gz, fitted = 0, 0, 0, false
	if onFeet then
		h, gx, gz, fitted = plane(inst, bx0, bz0)
	end
	local pitchT = if fitted then math.clamp(-math.atan(gz) * TILT, -TILT_MAX, TILT_MAX) else 0
	local rollT = if fitted then math.clamp(math.atan(gx) * TILT, -TILT_MAX, TILT_MAX) else 0
	local riseT = if fitted then math.clamp(h, -0.4 * hipH, 0.4 * hipH) else 0
	if snap then
		inst.tiltP, inst.tiltR, inst.rise = pitchT, rollT, riseT
	else
		inst.tiltP = approach(inst.tiltP, pitchT, 5, dt)
		inst.tiltR = approach(inst.tiltR, rollT, 5, dt)
		inst.rise = approach(inst.rise, riseT, 5, dt)
	end
	tilt(m, inst.m, inst.tiltP, inst.tiltR, inst.rise, bx0, skel.ground, bz0)
	bodyFrame(skel, m)
	-- (the body's own move under the root: a lunge, a recoil)
	if snap or dt <= 0 then
		if snap then
			inst.ubx, inst.ubz = 0, 0
		end
	else
		inst.ubx = approach(inst.ubx, (BCX - inst.bx) / dt, 25, dt)
		inst.ubz = approach(inst.ubz, (BCZ - inst.bz) / dt, 25, dt)
	end
	inst.bx, inst.bz = BCX, BCZ
	-- 1. the root's move: the planted points stay where they are in the world
	-- (AnimLab: the look stands still while the ground runs under it at the speed)
	local dx, dz = 0, -input.speed * dt
	local mx, mz = octo.dx, octo.dz
	if mx and mz then
		dx, dz = mx, mz
	end
	local dyaw = octo.dyaw or input.yawRate * dt
	if dt > 0 then
		inst.vx = approach(inst.vx, dx / dt, 12, dt)
		inst.vz = approach(inst.vz, dz / dt, 12, dt)
	end
	if not snap and (dx ~= 0 or dz ~= 0 or dyaw ~= 0) then
		local cs, sn = math.cos(dyaw), math.sin(dyaw)
		for _, f in feet do
			f.px, f.pz = carry(f.px, f.pz, dx, dz, cs, sn)
			f.sx, f.sz = carry(f.sx, f.sz, dx, dz, cs, sn)
			f.x, f.z = carry(f.x, f.z, dx, dz, cs, sn)
			f.gx, f.gz = carry(f.gx, f.gz, dx, dz, cs, sn)
			f.kx, f.kz = carry(f.kx, f.kz, 0, 0, cs, sn)
			f.aimX, f.aimZ = carry(f.aimX, f.aimZ, dx, dz, cs, sn)
		end
	end
	-- 2. the gait: the recipe's phase and stride
	local phase = rigid.phase
	local dPhase = (phase - inst.lastPhase) % 1
	if snap or dPhase > 0.5 then
		dPhase = 0
	end
	inst.lastPhase = phase
	if dt > 0 then
		inst.rateHz = approach(inst.rateHz, dPhase / dt, 10, dt)
	end
	local moving = dPhase > 1e-5 and rigid.move > 0.02
	if inst.moving and not moving then
		inst.stopAt = now
	end
	inst.moving = moving
	local carryT = if moving and not frozen then 1 else 0
	inst.carry = if snap then carryT else approach(inst.carry, carryT, if moving then 8 else 4, dt)
	local carry = smooth(inst.carry)
	local gait = input.gait
	local runTarget = if gait == "run"
		then 1
		elseif gait == "trot" then 0.5
		elseif gait == "walk" then 0
		else math.clamp((rigid.v / math.max(skel.span, 0.1) - 1) / 2, 0, 1)
	inst.runW = if snap then runTarget else approach(inst.runW, runTarget, 4, dt)
	local duty = DUTY.walk + (DUTY.run - DUTY.walk) * inst.runW
	inst.duty = duty
	local stride = rigid.stride
	local liftGait = LIFT_WALK + (LIFT_RUN - LIFT_WALK) * inst.runW
	-- where a foot lands: ahead by half the stance's travel along the root's velocity, turned on by half its turn
	local stanceTime = if inst.rateHz > 0.05 then duty / inst.rateHz else 0
	local leadX, leadZ = inst.vx * stanceTime / 2, inst.vz * stanceTime / 2
	local leadMax = 0.6 * skel.span
	local leadLen = math.sqrt(leadX * leadX + leadZ * leadZ)
	if leadLen > leadMax then
		leadX, leadZ = leadX * leadMax / leadLen, leadZ * leadMax / leadLen
	end
	local leadYaw = math.clamp(input.yawRate * stanceTime / 2, -0.6, 0.6)
	leadLen = math.min(leadLen, leadMax)
	local lcs, lsn = math.cos(leadYaw), math.sin(leadYaw)
	local bodyX, bodyZ = BCX, BCZ
	-- the keyed controls
	local splay = c.splay or 0
	local raiseK = c.raise or 0
	local stabK = c.stab or 0
	local tuckT = math.clamp(c.tuck or 0, 0, 1)
	inst.tuck = if snap then tuckT else inst.tuck + math.clamp(tuckT - inst.tuck, -TUCK_OUT * dt, TUCK_IN * dt)
	local tuckW = inst.tuck
	local palpK = c.palp or 0
	local waveK = c.wave or 0
	-- 3. each leg
	if snap then
		inst.ready = true
		inst.deathAt = nil
		inst.lastStep = -math.huge
		for i, leg in legs do
			local f = feet[i]
			local nx, nz = neutral(skel, leg, splay, 0, 0)
			local gy = groundAt(skel, octo, nx, nz)
			land(f, nx, gy, nz)
			f.swung, f.stabbed, f.airborne = false, false, false
			f.pin, f.ankle, f.roll = false, 0, 0
			-- standing on it (the pose a death that starts now begins from)
			local lx, ly, lz = toLook(m, nx, gy, nz)
			local psi, a, b = OctoPose.solve(leg, lx, ly, lz, 0, 0, 12)
			f.a, f.b, f.sa, f.sb, f.psi = a, b, a, b, psi
			f.striking, f.aimed = false, false
			turnsOf(leg, f, a, b, f.c)
		end
	end
	if dying and inst.deathAt == nil then
		inst.deathAt = now
		for _, f in feet do
			for j = 1, #f.c do
				f.hold[j] = f.c[j]
			end
			f.holdPsi = f.psi
		end
	elseif not dying then
		inst.deathAt = nil
	end
	local standing = not moving and rigid.move < 0.05
	local fold = c.fold or 0
	local deathW = if inst.deathAt then smooth((now - (inst.deathAt :: number)) / 0.1) else 0
	local maxDrift = math.max(0.45 * skel.span, 0.8 * duty * stride)
	-- the flinch of the legs on the struck side
	local hitE = 0
	local hitSide = input.hitSide
	if input.hitAt and hitSide and not dying then
		local t = now - input.hitAt
		if t >= 0 and t < 0.33 then
			hitE = if t < 0.05 then t / 0.05 else 1 - smooth((t - 0.05) / 0.28)
		end
	end
	local shiver = math.abs(c.shiver or 0) * 1.5 + 0.07 * rigid.stunW
	local grip = math.clamp(c.grip or 0, 0, 1)
	-- (a hitch turns a joint no further than the usual frame)
	local rateDt = math.min(dt, HITCH * inst.frame)
	local maxTurn = JOINT_RATE * rateDt
	if dt > 0 then
		inst.frame += (dt - inst.frame) * FRAME_RATE
	end
	-- the legs off the ground (not the palps): a step of its own waits while it would leave fewer than three standing
	local lifted = 0
	for i, f in feet do
		if not legs[i].palp and not f.down then
			lifted += 1
		end
	end
	local liftMost = math.max(1, inst.walkers - 3)
	-- (where the body's own move takes it over a step: a step lands ahead of a lunge; a body darting faster than
	-- DASH spans a second hops: every leg may step at once)
	local ubx, ubz = inst.ubx * LEAD_BODY, inst.ubz * LEAD_BODY
	local ub = math.sqrt(inst.ubx * inst.ubx + inst.ubz * inst.ubz)
	local ahead = ub * STEP_BASE
	local dash = ub > DASH * skel.span
	local leadCap = 0.5 * skel.span
	-- (a step of its own lasts STEP_FRAMES frames at least, standing: on the move it keeps to the gait's swing)
	local least = if moving then 0 else math.min(STEP_FRAMES * dt, STEP_SLOW)
	-- (the body's pitch, + nose up)
	local pitch = math.asin(math.clamp(-m[6], -1, 1))
	for i, leg in legs do
		local f = feet[i]
		local want = f.want
		local psiW = f.psi
		local rate = maxTurn
		-- (the head of its last bone held this frame: off its target by the pin; the target)
		local holds, baseX, baseY, baseZ = false, 0, 0, 0
		if dying then
			-- the death: from the pose it had, straightened by the jolt, then curled in at its own pace
			local depth = if fold >= 0 then fold ^ f.pace else fold
			for j = 1, leg.n do
				local curl = leg.curl[j] * depth
				want[j] = f.hold[j] + (curl - f.hold[j]) * deathW
			end
			want[leg.n + 1] = f.hold[leg.n + 1] * (1 - deathW)
			psiW = f.holdPsi * (1 - deathW * math.clamp(fold, 0, 1))
			local tw = math.abs(c.shiver or 0)
			if tw > 0 then
				want[leg.knee] += tw * 2 * noise(now * 14, seed, 80 + i)
			end
			f.mode = PLANT
			f.airborne = true
			f.down = false
			f.pin = false
		else
			-- the overlays the recipe keys, on the legs that take a raise (the front pair, the palps)
			local up = inst.up[i]
			local raiseT, stabT = 0, 0
			if up then
				local palpUp = if leg.palp then math.max(palpK * 0.6, CARRY * carry) else 0
				raiseT = math.clamp(raiseK + palpUp, 0, 1)
				if f.stabbed and stabK < 0.05 then
					f.stabbed = false
				end
				stabT = if f.stabbed then 0 else math.clamp(stabK, 0, 1)
			end
			if snap then
				f.rw, f.sw = raiseT, stabT
			else
				local striking = stabT > f.sw
				f.swWas = f.sw
				f.rw = if striking and raiseT < f.rw
					then raiseT
					else f.rw + math.clamp(raiseT - f.rw, -LET_GO * dt, RAISE_RATE * dt)
				-- (a stab that landed lets go at once: the foot stands where it struck)
				f.sw = if f.stabbed then 0 elseif striking then stabT else math.max(stabT, f.sw - LET_GO * dt)
			end
			local raiseW, stabW = smooth(f.rw), smooth(f.sw)
			local overlay = math.max(raiseW, stabW)
			local busy = overlay > 0.02 or tuckW > 0.02
			-- a flight: drawn in, its rest point follows the body; down again on the ground under it
			if tuckW >= 0.85 and not f.airborne then
				f.airborne = true
			elseif f.airborne and tuckW < 0.5 then
				f.airborne = false
				local nx, nz = neutral(skel, leg, splay, 0, 0)
				land(f, nx, groundAt(skel, octo, nx, nz), nz)
			end
			local nx, nz = neutral(skel, leg, splay, f.ox, f.oz)
			-- (a palp keyed up, striking or carried by the body's own dart never stands: it rides with the body, its pose
			-- fixed in the body's frame, so a lunge or its recoil never leaves it behind to swing back to and step after)
			-- (riding, it rides on till the dart is half as fast: no frame on its point between two of riding)
			local dart = not moving and ahead > DART * skel.span * (if f.ride >= 1 then 0.5 else 1)
			local follow = f.airborne or (leg.palp and (carry > 0.02 or busy or dart))
			if follow then
				-- (up in the air, its foot point goes with the body)
				f.mode = PLANT
				f.px, f.pz = nx, nz
				f.py = groundAt(skel, octo, nx, nz)
			end
			-- the gait
			local offset = 0.25 + 0.5 * leg.group + LAG * leg.rank - duty / 2
			local p = (phase - offset) % 1
			local inSwing = p >= duty
			local q = if inSwing then (p - duty) / (1 - duty) else 0
			if moving and not busy and not f.airborne then
				-- (a foot still on a step of its own joins its tetrad's swing from where it is, unless it is well on its
				-- way: it lands, ahead by the lead, and joins the next)
				if f.mode ~= GAIT and inSwing and not f.swung then
					f.swung = true
					local onWay = f.mode == STEP and now - f.t0 > JOIN_BY * f.dur
					if q < 0.5 and not onWay then
						f.mode = GAIT
						f.sx, f.sy, f.sz = f.x, f.y, f.z
						f.lift = liftGait * (if leg.palp then 0.7 else 1)
						f.ox, f.oz = 0, 0
						-- the ground where it will land (once per footfall)
						local gx_, gz_ = neutral(skel, leg, splay, 0, 0)
						f.gy = groundAt(skel, octo, gx_ + leadX, gz_ + leadZ)
					end
				end
			end
			if not inSwing then
				f.swung = false
			end
			local outX, outZ = (nx - bodyX), (nz - bodyZ)
			local outL = math.sqrt(outX * outX + outZ * outZ)
			if outL > 1e-4 then
				outX, outZ = outX / outL * skel.span, outZ / outL * skel.span
			end
			if f.mode == GAIT then
				if not moving or busy then
					-- the gait stopped under it: finish the step in a moment
					startStep(f, now, dt, least, 0.08, f.lift * 0.6, 0, 0, f.gy)
				else
					-- the goal: ahead by the lead, turned on about the body's centre
					local rx, rz = nx - bodyX, nz - bodyZ
					local gx2 = bodyX + rx * lcs + rz * lsn + leadX
					local gz2 = bodyZ - rx * lsn + rz * lcs + leadZ
					if not inSwing then
						land(f, gx2, f.gy, gz2)
					else
						arc(f, q, gx2, gz2, hipH, outX, outZ, false, false)
					end
				end
			end
			if f.mode == PLANT then
				f.x, f.y, f.z = f.px, f.py, f.pz
				-- (a foot the stab planted stays while the stab holds, unless the leg cannot reach it or the body darts
				-- back off it)
				local off = ahead > DART * skel.span and (f.px - bodyX) * ubx + (f.pz - bodyZ) * ubz < 0
				local held = f.stabbed and f.miss <= MISS * hipH and not off
				if not busy and not follow and not held then
					local ex, ez = f.px - nx, f.pz - nz
					local drift = math.sqrt(ex * ex + ez * ez)
					-- (a stance of the gait carries it back from the lead it landed with to as far behind)
					local limit = math.max(maxDrift, 1.5 * (leadLen + math.abs(leadYaw) * outL))
					-- (never as far as under its own hip)
					limit = math.min(limit, math.max(maxDrift, 0.9 * leg.span))
					local free = leg.palp or dash or lifted < liftMost
					if drift > 3 * skel.span then
						-- a teleport: down at once
						land(f, nx, groundAt(skel, octo, nx, nz), nz)
					elseif
						(
							drift + ahead > (if dash then 0.5 * limit else limit)
							or (f.miss > MISS * hipH and drift > 0.1 * skel.span)
						) and (free or f.miss > 4 * MISS * hipH)
					then
						-- left behind (a lunge, a spin, a lag spike) or out of reach: a step of its own, longer and
						-- higher the farther it goes (no longer than the gait's swing on the move)
						local gx2 = nx + math.clamp(ubx * STEP_BASE, -leadCap, leadCap)
						local gz2 = nz + math.clamp(ubz * STEP_BASE, -leadCap, leadCap)
						-- (the way it goes: to its point and on with the body)
						local dist = math.sqrt((gx2 - f.x) ^ 2 + (gz2 - f.z) ^ 2) + 2 * ahead
						local seconds = math.clamp(STEP_BASE + STEP_PER_SPAN * dist / skel.span, STEP_BASE, STEP_LONG)
						if moving then
							seconds = math.min(seconds, math.max((1 - duty) / math.max(inst.rateHz, 0.1), 0.06))
						end
						local lift = math.clamp(STEP_ARC * dist / hipH, LIFT_STEP, LIFT_MAX)
						startStep(f, now, dt, least, seconds, lift, 0, 0, groundAt(skel, octo, nx, nz))
						inst.lastStep = now
						if not leg.palp then
							lifted += 1
						end
					elseif
						standing
						and free
						and splay < 0.1
						and now - inst.stopAt > 0.12
						and now - inst.lastStep > SETTLE_GAP
						and drift > 0.16 * skel.span
					then
						-- standing: the legs settle back under the body one after another (a splayed landing holds
						-- its feet until the splay is gone, then gathers them)
						startStep(f, now, dt, least, STEP_SETTLE, LIFT_STEP * 0.8, 0, 0, groundAt(skel, octo, nx, nz))
						inst.lastStep = now
						if not leg.palp then
							lifted += 1
						end
					end
				end
			end
			-- (a step started this frame is already on its way: see startStep)
			if f.mode == STEP then
				-- (on the move it lands ahead by the lead, like the gait's steps; ahead of a lunge by where the body
				-- goes over the rest of the step)
				local remain = math.max(0, f.t0 + f.dur - now)
				local bx_ = math.clamp(ubx * remain, -leadCap, leadCap)
				local bz_ = math.clamp(ubz * remain, -leadCap, leadCap)
				local gx2, gz2 = nx + bx_, nz + bz_
				if moving then
					gx2, gz2 = gx2 + leadX, gz2 + leadZ
				end
				local u = if f.dur > 0 then (now - f.t0) / f.dur else 1
				if snap then
					land(f, gx2, f.gy, gz2)
				elseif u >= 1 then
					land(f, if f.set then f.gx else gx2, f.gy, if f.set then f.gz else gz2)
				else
					arc(f, math.max(u, 0), gx2, gz2, hipH, outX, outZ, true, not moving)
				end
			end
			-- standing on its point: the solver's pair (how far it falls short: a foot it cannot reach steps); a foot that
			-- stands trembles (stun, a shiver) and flinches by lifting a touch, its leg keeping the point (no slide)
			local kn = leg.knee
			local near = hitE > 0
				and (
					if hitSide == "left"
						then leg.side < 0
						elseif hitSide == "right" then leg.side > 0
						elseif hitSide == "front" then leg.rank <= 1.5
						else leg.rank >= 3
				)
			local onPoint = f.mode == PLANT and not follow and f.ride <= 0 and overlay <= 0.02 and tuckW <= 0.02
			local rise = 0
			if onPoint then
				rise = shiver * math.max(0, noise(now * 17, seed, 30 + i)) + hitE * (if near then 0.15 else 0.04)
			end
			local tx_, ty_, tz_ = f.x, f.y + rise * hipH, f.z
			-- (a stab starts straight up off its point, the head of its last bone held over where it stood, as a step
			-- does: then on its way)
			local stabLift = stabW > 0.001
				and stabW < LIFT_FIRST
				and f.mode == PLANT
				and not follow
				and not leg.palp
				and f.ride <= 0
				and raiseW <= 0.02
				and tuckW <= 0.02
			if stabLift then
				ty_ += 4 * stabW * (1 - stabW) * STAB_CLEAR * hipH
			end
			local tuckLift = tuckW > 0.001
				and tuckW < TUCK_UP
				and not f.airborne
				and f.mode == PLANT
				and not follow
				and f.ride <= 0
				and overlay <= 0.02
			if tuckW > 0.001 and not f.airborne then
				-- (drawn in from the ground: up off its point and in under the hip first, never curled through the
				-- ground the body leaves)
				local tw = smooth(math.min(1, tuckW / TUCK_OFF))
				local hw = smooth(math.clamp((tuckW - TUCK_UP) / (TUCK_OFF - TUCK_UP), 0, 1))
				tx_ += (nx - tx_) * hw
				ty_ += tw * TUCK_LIFT * hipH
				tz_ += (nz - tz_) * hw
			end
			local lx, ly, lz = toLook(m, tx_, ty_, tz_)
			-- (the head of the last bone held where it stands, rising straight up off its point with it and coming
			-- straight down onto the next: on the ground it never moves, only the last bone turns to the point)
			local stepQ = if f.mode == STEP and f.dur > 0 then (now - f.t0) / f.dur else 0
			-- (not on the move: the gait's feet stand a moment on their points, the leg swinging on over them to its full
			-- reach)
			holds = leg.n > 1
				and not moving
				and (
					onPoint
					or stabLift
					or tuckLift
					or (
						f.mode == STEP
						and (stepQ <= LIFT_FIRST + 1e-6 or f.set)
						and not follow
						and f.ride <= 0
						and overlay <= 0.02
						and tuckW <= 0.02
					)
				)
			baseX, baseY, baseZ = tx_, ty_, tz_
			f.ride = if follow and leg.palp then 1 elseif snap then 0 else math.max(0, f.ride - dt / PALP_LET)
			if f.ride > 0 then
				-- (riding: its rest point in the body's frame, whatever the body's pitch and dart, but never through the
				-- ground a squash or a nose-down brings near: kept PALP_CLEAR over it; let down onto its point after)
				local k = 1 + SPLAY * splay
				local w = smooth(f.ride)
				lx += (leg.hip[1] + (leg.foot[1] - leg.hip[1]) * k - lx) * w
				ly += (skel.ground - ly) * w
				lz += (leg.hip[3] + (leg.foot[3] - leg.hip[3]) * k - lz) * w
				local gx_, gy_, gz_ = toGround(m, lx, ly, lz)
				local clear = groundAt(skel, octo, gx_, gz_) + PALP_CLEAR * hipH * w
				if gy_ < clear then
					lx, ly, lz = toLook(m, gx_, clear, gz_)
				end
			end
			local psi, a, b = 0, f.a, f.b
			local pinned = false
			if holds and f.pin and not snap then
				-- (the head where it stood, the last bone turned and rolled onto the point)
				local wx, wy, wz = tx_ + f.kx, ty_ + f.ky, tz_ + f.kz
				local hx, hy, hz = toLook(m, wx, wy, wz)
				local ankle, roll
				psi, a, b, ankle, roll = OctoPose.pinned(leg, hx, hy, hz, lx, ly, lz, f.a, f.b, iters, f.ankle, f.roll)
				-- (a head out of reach, the body reared up off it: it hangs straight over its place, never swinging
				-- along the ground, and comes straight down onto it)
				local hang = 0
				for _ = 1, HANG_TRIES do
					OctoPose.turns(leg, a, b, want)
					local jx, jy, jz = OctoPose.joint(leg, psi, want, leg.n)
					if (jx - hx) ^ 2 + (jy - hy) ^ 2 + (jz - hz) ^ 2 <= HANG_AT * HANG_AT then
						break
					end
					-- (as high over it as the leg reaches, a touch higher: the leg puts it there exactly)
					local hip = leg.hip
					local gx_, gy_, gz_ = toGround(m, hip[1], hip[2], hip[3])
					local reach = math.sqrt((jx - hip[1]) ^ 2 + (jy - hip[2]) ^ 2 + (jz - hip[3]) ^ 2) - HANG_AT
					local flat2 = (wx - gx_) ^ 2 + (wz - gz_) ^ 2
					local over = if reach * reach > flat2 then gy_ - math.sqrt(reach * reach - flat2) - wy else 0
					if over <= hang then
						break
					end
					hang = over
					hx, hy, hz = toLook(m, wx, wy + hang, wz)
					psi, a, b, ankle, roll = OctoPose.pinned(leg, hx, hy, hz, lx, ly, lz, a, b, iters, f.ankle, f.roll)
				end
				-- (a head out of reach over a point the foot still reaches, a leg trailing at the end of its stance: the
				-- point wins)
				local reaches = false
				if hang > 0 then
					local p2, a2, b2 = OctoPose.solve(leg, lx, ly, lz, f.a, f.b, iters)
					OctoPose.turns(leg, a2, b2, want)
					want[leg.n + 1] = 0
					local qx, qy, qz = OctoPose.foot(leg, p2, want)
					reaches = (qx - lx) ^ 2 + (qy - ly) ^ 2 + (qz - lz) ^ 2 <= HANG_AT * HANG_AT
				end
				f.ankle = math.clamp(ankle, -ANKLE_MAX, ANKLE_MAX)
				f.roll = math.clamp(roll, -ROLL_MAX, ROLL_MAX)
				turnsOf(leg, f, a, b, want)
				local fx, fy, fz = OctoPose.foot(leg, psi, want)
				-- (where the leg cannot hold the head with the bone on the point, the point wins: the head goes, pinned
				-- again once the foot is back on its point)
				pinned = not reaches
					and ankle == f.ankle
					and roll == f.roll
					and (fx - lx) ^ 2 + (fy - ly) ^ 2 + (fz - lz) ^ 2 <= (PIN_LET + hang) ^ 2
				if not pinned then
					f.pin = false
				end
			end
			if not pinned then
				local let = if snap then 0 else math.exp(-ANKLE_LET * dt)
				if f.mode == STEP and not moving and not snap and f.dur > 0 then
					-- (a step standing: let go as it travels, all of it once over its goal; a phone's frame or two of
					-- travel never swings the last joint there and back)
					local e0 = smooth((stepQ - dt / f.dur - LIFT_FIRST) / (SET_AT - LIFT_FIRST))
					if e0 < 1 then
						let = (1 - smooth((stepQ - LIFT_FIRST) / (SET_AT - LIFT_FIRST))) / (1 - e0)
					end
				end
				f.ankle *= let
				f.roll *= let
				psi, a, b = solveFoot(leg, f, lx, ly, lz, a, b, if snap then 12 else iters, want)
			end
			f.a, f.b = a, b
			turnsOf(leg, f, a, b, want)
			local fx, fy, fz = OctoPose.foot(leg, psi, want)
			f.miss = math.sqrt((fx - lx) ^ 2 + (fy - ly) ^ 2 + (fz - lz) ^ 2)
			local hung = false
			if onPoint and not moving and not pinned and not snap and f.miss > HANG_AT then
				-- (out of reach of its point, a body still high off a landing, a lunge: the foot hangs straight over it
				-- at the reach it has, coming straight down onto it, never reaching short along the ground)
				local hip = leg.hip
				local gx_, gy_, gz_ = toGround(m, hip[1], hip[2], hip[3])
				local reach2 = (fx - hip[1]) ^ 2 + (fy - hip[2]) ^ 2 + (fz - hip[3]) ^ 2
				local flat2 = (tx_ - gx_) ^ 2 + (tz_ - gz_) ^ 2
				if reach2 > flat2 then
					local hy_ = gy_ - math.sqrt(reach2 - flat2)
					if hy_ > ty_ then
						-- (off its point by more than PIN_AT: not standing)
						hung = hy_ - ty_ > PIN_AT
						local ux, uy, uz = toLook(m, tx_, hy_, tz_)
						psi, a, b = solveFoot(leg, f, ux, uy, uz, a, b, iters, want)
						f.a, f.b = a, b
						turnsOf(leg, f, a, b, want)
					end
				end
			end
			-- raised: blended joint by joint toward its raised pose (the foot rises on an arc), waving
			if up and raiseW > 0.001 then
				local wk = if leg.palp then math.max(waveK, CARRY_WAVE * carry) else waveK
				local psiU, aU, bU = up[1], up[2] - pitch * PITCH_HOLD * up[4], up[3]
				if wk > 0 then
					aU += WAVE_LIFT * wk * math.sin(TAU * WAVE_HZ * now + f.wave)
					psiU += WAVE_YAW * wk * math.sin(TAU * WAVE_HZ * 0.7 * now + f.wave * 1.7)
				end
				psi += ((psiU - psi + math.pi) % TAU - math.pi) * raiseW
				a += (aU - a) * raiseW
				b += (bU - b) * raiseW
			end
			-- the stab: from where the foot is, straight down onto the ground ahead of the hip (closer in with a grip),
			-- planted there as it lands (a straight way: it never dips under the ground); a palp only reaches down
			-- over the ground (it feels, it does not stand)
			if stabW > 0.001 and not stabLift then
				local heading = leg.yaw0 * (0.5 - 0.3 * grip)
				local d = leg.span * (1.05 - 0.2 * grip)
				local hip = leg.hip
				local gxs, _, gzs = toGround(m, hip[1] - math.sin(heading) * d, 0, hip[3] - math.cos(heading) * d)
				-- (once over its point, the point comes to stay where it is on the ground, whatever the body's lunge:
				-- down onto it, never along the ground with the body)
				local hw = if leg.palp
					then math.min(1, stabW / SET_AT)
					else smooth(math.clamp((stabW - LIFT_FIRST) / (SET_AT - LIFT_FIRST), 0, 1))
				if hw >= 1 and not leg.palp then
					if not f.aimed then
						-- (where the body's own move takes the point by the time the stab lands, at its pace now)
						local pace = (f.sw - f.swWas) / math.max(dt, 1e-3)
						local remain = if pace > 1e-3 then math.min((1 - f.sw) / pace, STAB_AHEAD) else 0
						f.aimed = true
						f.aimX = gxs + math.clamp(inst.ubx * remain, -leadCap, leadCap)
						f.aimZ = gzs + math.clamp(inst.ubz * remain, -leadCap, leadCap)
					end
					local stay = smooth(math.clamp((stabW - SET_AT) / (1 - SET_AT), 0, 1))
					gxs, gzs = gxs + (f.aimX - gxs) * stay, gzs + (f.aimZ - gzs) * stay
				end
				local tx, ty, tz = toLook(m, gxs, skel.ground, gzs)
				if leg.palp then
					-- (a palp's strike is fixed in the body's frame: it goes with the lunge, never against it)
					tx, ty, tz =
						hip[1] - math.sin(heading) * d, skel.ground + PALP_HOVER * hipH, hip[3] - math.cos(heading) * d
				end
				turnsOf(leg, f, a, b, want)
				local ux, uy, uz = OctoPose.foot(leg, psi, want)
				-- (up off its point first, over the next by SET_AT of the way and straight down from there, never along
				-- the ground: the pose it strikes from may stand far behind)
				tx, ty, tz = ux + (tx - ux) * hw, uy + (ty - uy) * stabW, uz + (tz - uz) * hw
				if not leg.palp then
					local wx, wy, wz = toGround(m, tx, ty, tz)
					local clear = skel.ground + 4 * stabW * (1 - stabW) * STAB_CLEAR * hipH
					if wy < clear then
						tx, ty, tz = toLook(m, wx, clear, wz)
					end
				end
				if not f.striking then
					-- (the strike's solver starts from the pose it strikes from)
					f.striking = true
					f.sa, f.sb = a, b
				end
				local psiS, aS, bS = solveFoot(leg, f, tx, ty, tz, f.sa, f.sb, if snap then 12 else iters, want)
				f.sa, f.sb = aS, bS
				psi, a, b = psiS, aS, bS
				if f.sw >= 0.92 and stabK >= 0.92 and not f.stabbed and not leg.palp then
					-- the stab lands: the foot is planted where it struck, the pair it struck with standing on it
					f.stabbed = true
					land(f, gxs, skel.ground, gzs)
					f.a, f.b = aS, bS
					f.swung = true
				end
			else
				f.striking, f.aimed = false, false
			end
			turnsOf(leg, f, a, b, want)
			-- drawn in for a flight or the spawn (the turns of a part curl)
			if tuckW > 0.001 then
				local tw = smooth(math.clamp((tuckW - TUCK_UP) / (1 - TUCK_UP), 0, 1))
				for j = 1, leg.n do
					want[j] += (leg.curl[j] * TUCK - want[j]) * tw
				end
				want[leg.n + 1] *= 1 - tw
				psi *= 1 - 0.5 * tw
			end
			-- the tremble and the flinch of a leg off the ground
			if not onPoint and shiver > 0.001 then
				want[kn] += shiver * noise(now * 17, seed, 30 + i)
				want[math.max(1, kn - 1)] += shiver * 0.7 * noise(now * 19, seed, 50 + i)
			end
			if not onPoint and hitE > 0 then
				local k = hitE * (if near then 0.28 else 0.08)
				want[math.max(1, kn - 1)] += k
				want[kn] -= k * 0.6
			end
			psiW = psi
			-- (a foot its leg cannot bring down to its point hangs: not standing)
			f.down = f.mode == PLANT
				and not follow
				and f.ride <= 0
				and overlay <= 0.02
				and tuckW <= 0.02
				and f.miss <= MISS * hipH
				and not hung
				and f.lag < 0.05
			-- only standing, walking or striking down the straight way: the solver's pose as it is
			if tuckW <= 0.001 and ((overlay <= 0.001 and f.lag < 0.03) or stabW > 0.001 or f.stabbed) then
				local still = f.mode == PLANT and not follow and (overlay <= 0.001 or f.stabbed)
				rate = if still then STAND_RATE * dt else SAFE_RATE * rateDt
			end
		end
		-- drawn: no joint turns faster than JOINT_RATE, a leg that only walks or strikes than SAFE_RATE, one standing than
		-- STAND_RATE (a snap draws the pose at once)
		local fc = f.c
		if snap then
			for j = 1, leg.n + 1 do
				fc[j] = want[j]
			end
			f.psi = psiW
			f.lag = 0
		else
			-- (the whole pose moves toward the wanted one at the pace of its fastest joint: slowed, never bent off its
			-- way)
			local dPsi = (psiW - f.psi + math.pi) % TAU - math.pi
			local most = math.abs(dPsi)
			for j = 1, leg.n do
				most = math.max(most, math.abs(want[j] - fc[j]))
			end
			local k = if most > rate then rate / most else 1
			for j = 1, leg.n do
				fc[j] += (want[j] - fc[j]) * k
			end
			-- (the last bone's roll on its own: it keeps a standing bone still in the world as the body swings, it
			-- never holds the leg back)
			local ro = want[leg.n + 1] - fc[leg.n + 1]
			fc[leg.n + 1] += math.clamp(ro, -rate, rate)
			f.psi += dPsi * k
			f.lag = most * (1 - k)
		end
		-- pinned from the pose drawn on the frame it comes to hold (it stands on its point, a step sets down), kept
		-- while it holds
		if holds and not f.pin then
			-- (once the drawn foot is on its point: never pinned where a lagging leg hangs)
			local fx, fy, fz = OctoPose.foot(leg, f.psi, fc)
			local wx, wy, wz = toGround(m, fx, fy, fz)
			if (wx - baseX) ^ 2 + (wy - baseY) ^ 2 + (wz - baseZ) ^ 2 <= PIN_AT * PIN_AT then
				f.pin = true
				local hx, hy, hz = OctoPose.joint(leg, f.psi, fc, leg.n)
				local gx_, gy_, gz_ = toGround(m, hx, hy, hz)
				f.kx, f.ky, f.kz = gx_ - baseX, gy_ - baseY, gz_ - baseZ
			end
		elseif not holds then
			f.pin = false
		end
	end
	-- the pincers of a scorpion: held forward, raised and struck like the front legs (never planted)
	for i, arm in skel.arms do
		local f = inst.arms[i]
		local hip = arm.hip
		local lift = smooth(math.clamp(raiseK, 0, 1))
		local strike = smooth(math.clamp(stabK, 0, 1))
		local tx = arm.foot[1] + (hip[1] - arm.foot[1]) * 0.1 * lift
		local ty = arm.foot[2] + arm.reach * (0.3 * lift - 0.05 * strike)
		local tz = arm.foot[3] - arm.reach * 0.25 * strike
		local psi, a, b = OctoPose.solve(arm, tx, ty, tz, f.a, f.b, iters)
		f.a, f.b, f.psi = a, b, psi
		OctoPose.turns(arm, a, b, f.c)
	end
	-- 4. the idle: a leg shifts its footing, a palp taps (standing, nothing keyed)
	local calm = standing and not dying and tuckW < 0.02 and raiseK < 0.02 and stabK < 0.02
	if calm and now >= inst.nextShift then
		local n = math.floor(now * 3)
		local i = 1 + math.floor(hash01(n, seed) * #legs) % #legs
		local f, leg = feet[i], legs[i]
		if f.mode == PLANT and not leg.palp then
			local ox = (hash01(n + 1, seed) * 2 - 1) * 0.07 * skel.span
			local oz = (hash01(n + 2, seed) * 2 - 1) * 0.07 * skel.span
			local nx, nz = neutral(skel, leg, splay, ox, oz)
			startStep(f, now, dt, least, STEP_SHIFT, LIFT_SHIFT, ox, oz, groundAt(skel, octo, nx, nz))
		end
		local every = if input.combat then 1.6 else 1.2
		inst.nextShift = now + every + hash01(n + 3, seed) * 2.8
	end
	if calm and now >= inst.nextTap then
		local n = math.floor(now * 5)
		local pick = hash01(n, seed) < 0.5
		for i, leg in legs do
			local f = feet[i]
			if leg.palp and f.mode == PLANT and ((leg.side < 0) == pick) then
				-- a tap: up and down again where it stood
				local gx_, gz_ = f.px, f.pz
				startStep(f, now, dt, least, STEP_TAP, LIFT_TAP, 0, 0, f.py)
				-- (the goal is its rest point plus the offset that keeps it where it stood)
				local nx, nz = neutral(skel, leg, splay, 0, 0)
				local ex, ez = gx_ - nx, gz_ - nz
				f.ox, f.oz = ex * HCS - ez * HSN, ex * HSN + ez * HCS
			end
		end
		inst.nextTap = now + 1.1 + hash01(n + 1, seed) * 2.4
	end
	if snap then
		inst.nextShift = math.max(inst.nextShift, now + 0.8)
		inst.nextTap = math.max(inst.nextTap, now + 0.5)
	end
	-- 5. the fangs chew now and then, open and snap as keyed; the abdomen pumps and breathes; a tail curls
	local chew = 0
	if not rigid.wasActing and not dying then
		if now >= inst.nextChew + 0.7 then
			inst.nextChew = now + 2.5 + hash01(math.floor(now), seed) * 4
		elseif now >= inst.nextChew then
			chew = 0.3 * math.max(0, math.sin(TAU * 4.5 * (now - inst.nextChew)))
		end
	end
	inst.fang = ((c.fang or 0) + chew) * FANG
	inst.pump = (c.gr or 0) * PUMP + 0.025 * math.sin(TAU * 0.45 * (now + seed)) * (if dying then 0 else 1)
	inst.tail = 1.5 * (c.dip or 0) + 0.4 * (c.lunge or 0)
end

---------------------------------------------------------------- the folded boxes

-- The look's box with the legs curled at 0, 1/8 .. 1 (RigidMotion lowers and topples the dying body over them), from
-- the measured box `body` (the rest one) plus how the legs' joints move it: the box of the hips' core and every joint.
function OctoMotion.folds(inst: Instance, body: RigidMotion.Body): { RigidMotion.Fold }
	local skel = inst.skel
	local pts: { Vec } = {}
	local c: { number } = {}
	local boxes: { { number } } = {}
	-- the body itself: around the hips, from half the hip height up
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	local top = -math.huge
	for _, leg in skel.legs do
		x0, x1 = math.min(x0, leg.hip[1]), math.max(x1, leg.hip[1])
		z0, z1 = math.min(z0, leg.hip[3]), math.max(z1, leg.hip[3])
		top = math.max(top, leg.hip[2])
	end
	local mx, mz = (x1 - x0) * 0.3, (z1 - z0) * 0.3
	local core = { x0 - mx, skel.ground + 0.5 * skel.hipH, z0 - mz, x1 + mx, top + 0.6 * skel.hipH, z1 + mz }
	for step = 0, 8 do
		local k = step / 8
		local b = table.clone(core)
		for i, leg in skel.legs do
			local f = inst.feet[i]
			OctoPose.curl(leg, k ^ f.pace, c)
			OctoPose.joints(leg, 0, c, pts)
			for j = 2, leg.n + 1 do
				local p = pts[j]
				b[1], b[2], b[3] = math.min(b[1], p[1]), math.min(b[2], p[2]), math.min(b[3], p[3])
				b[4], b[5], b[6] = math.max(b[4], p[1]), math.max(b[5], p[2]), math.max(b[6], p[3])
			end
		end
		boxes[step + 1] = b
	end
	local r = boxes[1]
	local out: { RigidMotion.Fold } = {}
	for i, b in boxes do
		out[i] = {
			h = body.h + (b[5] - r[5]),
			lift = body.lift + (b[2] - r[2]),
			B = math.max(0.2, body.B + (b[6] - b[3]) - (r[6] - r[3])),
			W = math.max(0.2, body.W + (b[4] - b[1]) - (r[4] - r[1])),
			x0 = body.x0 + ((b[1] + b[4]) - (r[1] + r[4])) / 2,
			z0 = body.z0 + ((b[3] + b[6]) - (r[3] + r[6])) / 2,
		}
	end
	return out
end

return OctoMotion
