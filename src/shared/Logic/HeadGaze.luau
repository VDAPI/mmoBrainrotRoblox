--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"): where the head of a
-- model without bones looks, each frame (client/Anim/MeshHead turns the bone Logic/NeckBend hung it on). Pure (Lune).
-- * A target (the monster's aggro player; AnimLab: the actor): the head turns toward it within `yaw`, `up` and
--   `down` (the body turns after it on its own), followed at `rate`, faster while an action plays.
-- * Calm: now and then a glance aside (within `glance`, less while it walks; a bird cocks its head by `tilt`) or at
--   the local player when near, else ahead; standing still it sniffs (quick nods of `sniff`, the nose a little down).
--   The glances come from the clock and the seed: the same at every replay (AnimLab).
-- * In a fight without a target, going home: ahead. Stunned (even with a target): hung low, swaying. A held action
--   (a death): back to rest.
-- * Over that (not dying): the nod with the steps (`nod`, at the gait's bob bumps), the flinch of a hit away from the
--   blow (`flinch`, Logic/RigidMotion's envelope), and `steady` of the body's own pitch taken back (a hop, a rear: the
--   head stays more level; not while an action plays, its pitch is the blow's). Frozen (no time passing), it holds.
-- Angles in radians in the look's axes: yaw + turns left, pitch + raises the nose, roll + lifts the right side.

local NpcPose = require("./NpcPose")
local RigidRigs = require("../Data/RigidRigs")

local HeadGaze = {}

export type Options = RigidRigs.Gaze

export type Input = {
	now: number, -- the motion's clock (s)
	dt: number, -- its step this frame (0: frozen)
	snap: boolean?, -- a jump of the clock: the head is where it looks at once
	look: { number }?, -- the target from the head (the look's axes: x right, y up, z back), nil: none
	notice: { number }?, -- the local player from the head while near (calm glances), nil: none
	combat: boolean?, -- in a fight (no glances)
	returning: boolean?, -- going home (no glances)
	acting: boolean?, -- a keyed action plays (followed faster, no steadying)
	dying: boolean?, -- a held action (a death): back to rest
	stun: boolean?,
	move: number?, -- the gait's weight (0..1)
	phase: number?, -- the gait's cycle (0..1)
	bumps: number?, -- the gait's bob bumps per cycle
	hitAt: number?, -- the last hit (the motion's clock)
	hitSide: string?, -- where it came from (Logic/RigidMotion.side)
	bodyPitch: number?, -- the body's own pitch this frame (+ nose up)
}

export type State = {
	o: Options,
	seed: number,
	yaw: number, -- the followed angles
	pitch: number,
	roll: number,
	lastNow: number?,
	shown: { number }, -- the angles given last (held while the clock stands)
}

local TAU = 2 * math.pi
local hash01 = NpcPose.hash01
-- The clock jumping back or forward by more than this (s) puts the head where it looks at once.
local JUMP = 0.5
-- A glance lasts about SLOT over the rate (s), within these.
local SLOT = 16
local SLOT_MIN, SLOT_MAX = 1.2, 4.5
-- Shares of the calm glances: ahead, at the local player (when near), aside (the rest).
local AHEAD, AT_PLAYER = 0.35, 0.6
-- The sniff's quick nods (Hz) and the nose's dip while it sniffs (share of `down`).
local SNIFF_HZ = 6.5
local SNIFF_DIP = 0.35
-- Stunned: the head hangs (share of `down`) and sways (share of `glance`, Hz).
local DAZED_DIP, DAZED_SWAY, DAZED_HZ = 0.5, 0.3, 0.7
-- How long the flinch rises, holds and falls (s; Logic/RigidMotion's).
local FLINCH_IN, FLINCH_HOLD, FLINCH_OUT = 0.05, 0.03, 0.25
-- The steadying never takes back more than this share of the turn limits.
local STEADY_MAX = 1

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

function HeadGaze.new(o: Options, seed: number): State
	return { o = o, seed = seed, yaw = 0, pitch = 0, roll = 0, lastNow = nil, shown = { 0, 0, 0 } }
end

-- The yaw and the pitch toward a direction (the look's axes), within the head's limits.
function HeadGaze.aim(o: Options, x: number, y: number, z: number): (number, number)
	local flat = math.sqrt(x * x + z * z)
	if flat < 1e-6 and math.abs(y) < 1e-6 then
		return 0, 0
	end
	local yaw = math.atan2(-x, -z)
	local pitch = math.atan2(y, flat)
	return math.clamp(yaw, -math.rad(o.yaw), math.rad(o.yaw)), math.clamp(pitch, -math.rad(o.down), math.rad(o.up))
end

-- How long one calm glance lasts (s).
function HeadGaze.slot(o: Options): number
	return math.clamp(SLOT / math.max(o.rate, 0.1), SLOT_MIN, SLOT_MAX)
end

-- The calm head at `now`: yaw, pitch, roll and the sniff's share (0..1) of its quick nods; `notice` the local player
-- (or nil), `move` the gait's weight.
function HeadGaze.glance(
	o: Options,
	seed: number,
	now: number,
	notice: { number }?,
	move: number
): (number, number, number, number)
	local length = HeadGaze.slot(o)
	local shift = hash01(7, seed)
	local k = math.floor(now / length + shift)
	local into = now - (k - shift) * length
	local u1, u2, u3, u4 =
		hash01(k * 4 + 1, seed), hash01(k * 4 + 2, seed), hash01(k * 4 + 3, seed), hash01(k * 4, seed)
	local wide = math.rad(o.glance) * (1 - 0.6 * move)
	if u1 < AHEAD then
		-- ahead; standing still, half the time it sniffs (the nose a little down)
		if o.sniff > 0 and u2 < 0.5 then
			local on = smooth(into / 0.2) * (1 - smooth((into - 0.65 * length) / 0.2)) * (1 - move)
			return 0, -SNIFF_DIP * math.rad(o.down) * on, 0, on
		end
		return 0, (u3 - 0.5) * 0.2 * math.rad(o.down), 0, 0
	end
	local side = if u2 < 0.5 then -1 else 1
	local yaw = side * wide * (0.4 + 0.6 * u3)
	local pitch = (u4 * 2 - 1) * 0.35 * math.rad(if u4 > 0.5 then o.up else o.down)
	if u1 < AT_PLAYER and notice then
		local y, p = HeadGaze.aim(o, notice[1], notice[2], notice[3])
		yaw, pitch = math.clamp(y, -wide, wide), p
		side = if yaw >= 0 then 1 else -1
	end
	return yaw, pitch, side * math.rad(o.tilt) * (0.5 + 0.5 * u4), 0
end

-- The flinch's envelope (0..1) `t` seconds after a hit.
function HeadGaze.flinch(t: number): number
	if t < 0 or t >= FLINCH_IN + FLINCH_HOLD + FLINCH_OUT then
		return 0
	elseif t < FLINCH_IN then
		local u = 1 - t / FLINCH_IN
		return 1 - u * u * u
	elseif t < FLINCH_IN + FLINCH_HOLD then
		return 1
	end
	local u = (t - FLINCH_IN - FLINCH_HOLD) / FLINCH_OUT
	return math.max(0, 1 - smooth(u) - 0.1 * math.sin(math.pi * u))
end

-- One frame of the head: its yaw, pitch and roll (rad).
function HeadGaze.step(st: State, input: Input): (number, number, number)
	local o = st.o
	local now = input.now
	local dt = math.clamp(input.dt, 0, 0.1)
	local last = st.lastNow
	local snap = input.snap == true or last == nil or now < last - 1e-6 or now - last > JUMP
	st.lastNow = now
	local shown = st.shown
	if dt <= 0 and not snap then
		-- (frozen: the pose holds, as the body's)
		return shown[1], shown[2], shown[3]
	end
	local move = math.clamp(input.move or 0, 0, 1)
	-- where it looks
	local ty, tp, tr, sniff = 0, 0, 0, 0
	local look = input.look
	if input.dying then
		ty, tp, tr = 0, 0, 0
	elseif input.stun then
		ty = DAZED_SWAY * math.rad(o.glance) * math.sin(TAU * DAZED_HZ * now + st.seed)
		tp = -DAZED_DIP * math.rad(o.down)
	elseif look then
		ty, tp = HeadGaze.aim(o, look[1], look[2], look[3])
	elseif not input.combat and not input.returning then
		ty, tp, tr, sniff = HeadGaze.glance(o, st.seed, now, input.notice, move)
	end
	-- followed at its rate
	if snap then
		st.yaw, st.pitch, st.roll = ty, tp, tr
	else
		local rate = o.rate * (if input.acting or input.dying then 1.5 else 1)
		local k = 1 - math.exp(-rate * dt)
		st.yaw += (ty - st.yaw) * k
		st.pitch += (tp - st.pitch) * k
		st.roll += (tr - st.roll) * k
	end
	local yaw, pitch, roll = st.yaw, st.pitch, st.roll
	if input.dying then
		shown[1], shown[2], shown[3] = yaw, pitch, roll
		return yaw, pitch, roll
	end
	-- the nod with the steps
	local phase = input.phase
	if o.nod ~= 0 and phase and move > 0.01 then
		pitch += math.rad(o.nod) * move * math.sin(TAU * (input.bumps or 2) * phase)
	end
	-- the sniff's quick nods
	if sniff > 0 then
		pitch += math.rad(o.sniff) * sniff * math.sin(TAU * SNIFF_HZ * now)
	end
	-- the flinch, away from the blow
	local hitAt = input.hitAt
	if hitAt and o.flinch ~= 0 then
		local e = HeadGaze.flinch(now - hitAt)
		if e > 0 then
			local side = input.hitSide
			local fy, fp = 0, 1
			if side == "back" then
				fy, fp = 0, -0.5
			elseif side == "left" then
				fy, fp = -0.8, 0.3
			elseif side == "right" then
				fy, fp = 0.8, 0.3
			end
			yaw += math.rad(o.flinch) * fy * e
			pitch += math.rad(o.flinch) * fp * e
		end
	end
	-- the body's own pitch, partly taken back
	local body = input.bodyPitch
	if body and o.steady ~= 0 and not input.acting then
		local most = STEADY_MAX * math.rad(math.max(o.up, o.down))
		pitch -= math.clamp(o.steady * body, -most, most)
	end
	shown[1], shown[2], shown[3] = yaw, pitch, roll
	return yaw, pitch, roll
end

-- The turn of yaw, then pitch, then roll as a row-major 3x3 matrix in the look's axes (Ry * Rx * Rz).
function HeadGaze.matrix(yaw: number, pitch: number, roll: number): { number }
	local cy, sy = math.cos(yaw), math.sin(yaw)
	local cp, sp = math.cos(pitch), math.sin(pitch)
	local cr, sr = math.cos(roll), math.sin(roll)
	-- Ry * Rx
	local a00, a01, a02 = cy, sy * sp, sy * cp
	local a10, a11, a12 = 0, cp, -sp
	local a20, a21, a22 = -sy, cy * sp, cy * cp
	-- * Rz
	return {
		a00 * cr + a01 * sr,
		-a00 * sr + a01 * cr,
		a02,
		a10 * cr + a11 * sr,
		-a10 * sr + a11 * cr,
		a12,
		a20 * cr + a21 * sr,
		-a20 * sr + a21 * cr,
		a22,
	}
end

return HeadGaze
