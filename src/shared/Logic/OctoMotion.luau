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
--    swing when that comes); a teleport puts them all down at once; the solver's answer is followed at a capped rate,
--    so a target swept across a leg's reach never snaps it to its other bend;
-- 3. the idle: a leg shifts its footing now and then, the palps tap, the fangs chew, the abdomen breathes; on the move
--    the palps are carried up in front, feeling the way (too short to keep up with the stride);
-- 4. what the recipe keys: `raise` (the front legs and the palps lift and reach forward and up), `wave`, `stab` (they
--    strike forward and down onto the ground ahead and plant there), `tuck` (every leg drawn in under the body: a
--    flight, the spawn), `splay` (the feet set down wider: landings, slams), `palp`, `fang`, the abdomen's pump (`gr`),
--    the legs' tremble (`shiver`, stun) and the flinch of the legs on the struck side;
-- 5. deaths: from the pose they had, the legs straighten in the jolt and curl in over the belly as the recipe's `fold`
--    grows (each leg at its own pace); RigidMotion lowers and topples the body over the folded box (OctoMotion.folds);
-- 6. on a ground that is not flat (the rig's ground probe, once per footfall) the body tilts with the plane of its feet.
-- Pure: client/Anim/RigidRig feeds the root's move and the ground probe and writes the bones.

local NpcPose = require("./NpcPose")
local OctoPose = require("./OctoPose")
local RigidMotion = require("./RigidMotion")

local OctoMotion = {}

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
	t0: number,
	dur: number,
	lift: number,
	-- the gait swing of this cycle has started (or was skipped)
	swung: boolean,
	-- the foot's target this frame (ground frame)
	x: number,
	y: number,
	z: number,
	-- the pose written (yaw, joint turns) and the solver's pair for the next frame
	psi: number,
	c: { number },
	a: number,
	b: number,
	-- a death starts from this pose
	hold: { number },
	holdPsi: number,
	pace: number, -- the curl's exponent (its own pace)
	wave: number, -- its phase in a wave
	stabbed: boolean, -- the stab planted it (the key's rest is ignored until it falls)
	airborne: boolean, -- drawn in for a flight: its rest point follows the body until it lands
	down: boolean, -- standing on the ground this frame (planted, nothing lifting it)
	miss: number, -- how far the drawn foot missed its target last frame (out of reach: it steps)
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
-- Seconds of a catch-up step, a settling step, an idle shift, a tap; the gap between two settling steps.
local STEP_FAST, STEP_SETTLE, STEP_SHIFT, STEP_TAP, SETTLE_GAP = 0.1, 0.13, 0.17, 0.15, 0.05
-- A raised leg: its foot's elevation and reach, how far it swings toward the front; a wave's amplitude and rate.
local RAISE_ELEV, RAISE_REACH, RAISE_TURN = math.rad(38), 0.72, 0.45
local WAVE_ELEV, WAVE_YAW, WAVE_HZ = math.rad(18), math.rad(10), 3.2
-- The fangs' full opening, the abdomen's pump per unit of the recipe's `gr`.
local FANG, PUMP = math.rad(24), 2.4
-- How deep a flight's tuck curls the legs; how much wider a splay sets them.
local TUCK, SPLAY = 0.55, 0.25
-- The ground's tilt taken up by the body, its limit.
local TILT, TILT_MAX = 0.6, math.rad(20)
-- How high the palps are carried on the move (a share of the raise), their feeling wave.
local CARRY, CARRY_WAVE = 0.45, 0.35
-- A planted foot the leg misses by more than this (hip heights) steps to a point it reaches.
local MISS = 0.05
-- How fast the legs follow the recipe's `tuck` (1/s): drawn in over a few frames, never in one (out twice as fast).
local TUCK_RATE = 22
-- A leg's yaw never turns faster than this (rad/s): a target passing right under its hip would spin it; its lift and
-- fold neither (a target swept across the chain's reach could make the solver jump to the other bend).
local PSI_RATE, BEND_RATE = 24, 22

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
		c = table.create(n, 0),
		a = 0,
		b = 0,
		hold = table.create(n, 0),
		holdPsi = 0,
		pace = 0.75 + 0.55 * hash01(40 + i, seed),
		wave = hash01(60 + i, seed) * TAU,
		stabbed = false,
		airborne = false,
		down = true,
		miss = 0,
	}
end

function OctoMotion.new(skel: OctoPose.Skeleton, seed: number): Instance
	local feet: { Foot } = {}
	for i, leg in skel.legs do
		feet[i] = newFoot(leg.n, seed, i)
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

-- Starts a timed step of `f` from where it is to its rest point (plus an offset), `seconds` long, `lift` hip heights.
local function startStep(f: Foot, now: number, seconds: number, lift: number, ox: number, oz: number, gy: number)
	f.mode = STEP
	f.sx, f.sy, f.sz = f.x, f.y, f.z
	f.t0, f.dur, f.lift = now, seconds, lift
	f.ox, f.oz, f.gy = ox, oz, gy
end

local function land(f: Foot, x: number, y: number, z: number)
	f.mode = PLANT
	f.px, f.py, f.pz = x, y, z
	f.x, f.y, f.z = x, y, z
	f.ox, f.oz = 0, 0
end

-- The foot along a step's arc at `q` (0..1) from its start to (gx, gy, gz).
local function arc(f: Foot, q: number, gx: number, gz: number, hipH: number, outX: number, outZ: number)
	local e = q * q * (3 - 2 * q)
	local up = math.sin(math.pi * math.clamp(q, 0, 1) ^ 0.85)
	local bulge = 0.06 * up
	f.x = f.sx + (gx - f.sx) * e + outX * bulge
	f.z = f.sz + (gz - f.sz) * e + outZ * bulge
	f.y = f.sy + (f.gy - f.sy) * e + f.lift * hipH * up
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
	inst.tuck = if snap
		then tuckT
		else approach(inst.tuck, tuckT, if tuckT < inst.tuck then 2 * TUCK_RATE else TUCK_RATE, dt)
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
			-- standing on it (the pose a death that starts now begins from)
			local lx, ly, lz = toLook(m, nx, gy, nz)
			local psi, a, b = OctoPose.solve(leg, lx, ly, lz, 0, 0, 12)
			f.a, f.b, f.psi = a, b, psi
			OctoPose.turns(leg, a, b, f.c)
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
	for i, leg in legs do
		local f = feet[i]
		local fc = f.c
		if dying then
			-- the death: from the pose it had, straightened by the jolt, then curled in at its own pace
			local depth = if fold >= 0 then fold ^ f.pace else fold
			for j = 1, leg.n do
				local want = leg.curl[j] * depth
				fc[j] = f.hold[j] + (want - f.hold[j]) * deathW
			end
			f.psi = f.holdPsi * (1 - deathW * math.clamp(fold, 0, 1))
			local tw = math.abs(c.shiver or 0)
			if tw > 0 then
				fc[leg.knee] += tw * 2 * noise(now * 14, seed, 80 + i)
			end
			f.mode = PLANT
			f.airborne = true
			f.down = false
			continue
		end
		-- the overlays the recipe keys (the front legs and the palps)
		local front = leg.front
		local raiseW =
			smooth(math.clamp(raiseK * front + (if leg.palp then math.max(palpK * 0.6, CARRY * carry) else 0), 0, 1))
		if f.stabbed and stabK < 0.05 then
			f.stabbed = false
		end
		local stabW = if f.stabbed then 0 else smooth(math.clamp(stabK * front, 0, 1))
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
		local follow = f.airborne or (leg.palp and carry > 0.02)
		if follow then
			-- (up in the air, its foot point goes with the body)
			f.mode = PLANT
			f.px, f.pz = nx, nz
			f.py = skel.ground
		end
		-- the gait
		local offset = 0.25 + 0.5 * leg.group + LAG * leg.rank - duty / 2
		local p = (phase - offset) % 1
		local inSwing = p >= duty
		local q = if inSwing then (p - duty) / (1 - duty) else 0
		if moving and not busy and not f.airborne then
			-- (a foot still on a step of its own joins its tetrad's swing from where it is)
			if f.mode ~= GAIT and inSwing and not f.swung then
				f.swung = true
				if q < 0.5 then
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
				startStep(f, now, 0.08, f.lift * 0.6, 0, 0, f.gy)
			else
				-- the goal: ahead by the lead, turned on about the body's centre
				local rx, rz = nx - bodyX, nz - bodyZ
				local gx2 = bodyX + rx * lcs + rz * lsn + leadX
				local gz2 = bodyZ - rx * lsn + rz * lcs + leadZ
				if not inSwing then
					land(f, gx2, f.gy, gz2)
				else
					arc(f, q, gx2, gz2, hipH, outX, outZ)
				end
			end
		end
		if f.mode == STEP then
			-- (on the move it lands ahead by the lead, like the gait's steps)
			local gx2, gz2 = nx, nz
			if moving then
				gx2, gz2 = nx + leadX, nz + leadZ
			end
			local u = if f.dur > 0 then (now - f.t0) / f.dur else 1
			if u >= 1 or snap then
				land(f, gx2, f.gy, gz2)
			else
				arc(f, math.max(u, 0), gx2, gz2, hipH, outX, outZ)
			end
		end
		if f.mode == PLANT then
			f.x, f.y, f.z = f.px, f.py, f.pz
			if not busy and not f.airborne then
				local ex, ez = f.px - nx, f.pz - nz
				local drift = math.sqrt(ex * ex + ez * ez)
				-- (a stance of the gait carries it back from the lead it landed with to as far behind)
				local limit = math.max(maxDrift, 1.5 * (leadLen + math.abs(leadYaw) * outL))
				-- (never as far as under its own hip)
				limit = math.min(limit, math.max(maxDrift, 0.9 * leg.span))
				if drift > 3 * skel.span then
					-- a teleport: down at once
					land(f, nx, groundAt(skel, octo, nx, nz), nz)
				elseif
					(drift > limit or f.miss > MISS * hipH) and (now - inst.lastStep > 0.03 or drift > 1.5 * limit)
				then
					-- left behind (a lunge, a spin, a lag spike): a quick step of its own (no longer than the gait's)
					local seconds = if moving
						then math.clamp((1 - duty) / math.max(inst.rateHz, 0.1), 0.06, STEP_FAST)
						else STEP_FAST
					startStep(f, now, seconds, LIFT_STEP, 0, 0, groundAt(skel, octo, nx, nz))
					inst.lastStep = now
				elseif
					standing
					and splay < 0.1
					and now - inst.stopAt > 0.12
					and now - inst.lastStep > SETTLE_GAP
					and drift > 0.16 * skel.span
				then
					-- standing: the legs settle back under the body one after another (a splayed landing holds its
					-- feet until the splay is gone, then gathers them)
					startStep(f, now, STEP_SETTLE, LIFT_STEP * 0.8, 0, 0, groundAt(skel, octo, nx, nz))
					inst.lastStep = now
				end
			end
		end
		-- the target in the look frame: the foot, lifted toward the raised point and down onto the stab point
		local lx, ly, lz = toLook(m, f.x, f.y, f.z)
		if overlay > 0.001 then
			local yawR = leg.yaw0 * (1 - RAISE_TURN * math.min(front, 1))
			local wk = if leg.palp then math.max(waveK, CARRY_WAVE * carry) else waveK
			local wv = wk * math.sin(TAU * WAVE_HZ * now + f.wave)
			local elev = RAISE_ELEV + WAVE_ELEV * wv
			yawR += WAVE_YAW * wk * math.sin(TAU * WAVE_HZ * 0.7 * now + f.wave * 1.7)
			local reach = RAISE_REACH * leg.reach
			local hip = leg.hip
			local rx_ = hip[1] - math.sin(yawR) * math.cos(elev) * reach
			local ry_ = hip[2] + math.sin(elev) * reach
			local rz_ = hip[3] - math.cos(yawR) * math.cos(elev) * reach
			local qx, qy, qz = rx_, ry_, rz_
			if stabW > 0.001 then
				-- the stab: forward and down to the ground ahead (ground frame)
				local yawS = leg.yaw0 * 0.5
				local d = leg.span * 1.05
				local sx_ = hip[1] - math.sin(yawS) * d
				local sz_ = hip[3] - math.cos(yawS) * d
				local gxs, _, gzs = toGround(m, sx_, 0, sz_)
				local tx, ty, tz = toLook(m, gxs, skel.ground, gzs)
				local k = stabW / (raiseW + stabW)
				qx, qy, qz = qx + (tx - qx) * k, qy + (ty - qy) * k, qz + (tz - qz) * k
			end
			lx, ly, lz = lx + (qx - lx) * overlay, ly + (qy - ly) * overlay, lz + (qz - lz) * overlay
			if stabW >= 0.92 and not f.stabbed then
				-- the stab lands: the foot is planted where it struck
				f.stabbed = true
				local gx3, _, gz3 = toGround(m, lx, ly, lz)
				land(f, gx3, skel.ground, gz3)
				f.swung = true
			end
		end
		local psi, a, b = OctoPose.solve(leg, lx, ly, lz, f.a, f.b, if snap then 12 else iters)
		-- (how far it falls short: a foot that cannot be reached steps)
		OctoPose.turns(leg, a, b, fc)
		local fx, fy, fz = OctoPose.foot(leg, psi, fc)
		f.miss = math.sqrt((fx - lx) ^ 2 + (fy - ly) ^ 2 + (fz - lz) ^ 2)
		if not snap then
			local turn = (psi - f.psi + math.pi) % TAU - math.pi
			psi = f.psi + math.clamp(turn, -PSI_RATE * dt, PSI_RATE * dt)
			a = f.a + math.clamp(a - f.a, -BEND_RATE * dt, BEND_RATE * dt)
			b = f.b + math.clamp(b - f.b, -BEND_RATE * dt, BEND_RATE * dt)
		end
		f.a, f.b = a, b
		OctoPose.turns(leg, a, b, fc)
		-- drawn in for a flight or the spawn (the turns of a part curl)
		if tuckW > 0.001 then
			local tw = smooth(tuckW)
			for j = 1, leg.n do
				fc[j] += (leg.curl[j] * TUCK - fc[j]) * tw
			end
			psi *= 1 - 0.5 * tw
		end
		-- the tremble (stun, a shiver) and the flinch
		local kn = leg.knee
		if shiver > 0.001 then
			fc[kn] += shiver * noise(now * 17, seed, 30 + i)
			fc[math.max(1, kn - 1)] += shiver * 0.7 * noise(now * 19, seed, 50 + i)
		end
		if hitE > 0 then
			local near = if hitSide == "left"
				then leg.side < 0
				elseif hitSide == "right" then leg.side > 0
				elseif hitSide == "front" then leg.rank <= 1.5
				else leg.rank >= 3
			local k = hitE * (if near then 0.28 else 0.08)
			fc[math.max(1, kn - 1)] += k
			fc[kn] -= k * 0.6
		end
		f.psi = psi
		f.down = f.mode == PLANT and not follow and overlay <= 0.02 and tuckW <= 0.02
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
			startStep(f, now, STEP_SHIFT, LIFT_SHIFT, ox, oz, groundAt(skel, octo, nx, nz))
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
				startStep(f, now, STEP_TAP, LIFT_TAP, 0, 0, f.py)
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
