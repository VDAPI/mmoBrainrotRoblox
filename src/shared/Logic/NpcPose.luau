--!strict
-- W30 (NPC models from Tripo: Auto Rig Biped, Mixamo bone names, no clips): the procedural pose and motion of an
-- owner's NPC model (ReplicatedStorage.Assets.Npcs.<id>), so it does not stand in the T-pose and nothing has to be
-- uploaded. Pure: Anim/NpcRig reads the bones' rest frames and positions in the NPC's root space (front -Z, up +Y,
-- right +X) and writes Bone.Transform; this module holds the math.
-- * Rotations are 3x3 matrices (row-major, the order of CFrame.new(x, y, z, R00, R01, ...)).
-- * The relaxed stance is computed from bone WORLD directions (shoulder -> elbow, elbow -> wrist), never from a
--   bone's local axes, so any export's bone orientation works (Tripo, Mixamo, Blender roll).
-- * Every driven bone gets a turn C in root axes relative to its parent (the body at rest); the bone's Transform is
--   rest^-1 * C * rest (Anim/BoneOverlay's convention), so children follow their parents.
-- * Motion (idle, talk, hammering) is a function of time and a per-NPC seed: the same on every frame rate and
--   testable here.

local NpcPose = {}

export type Vec = { number } -- { x, y, z }
export type Mat = { number } -- 9 numbers, row-major
-- Turn of a bone in root axes: yaw (ry) outermost, then pitch (rx), then roll (rz).
export type Euler = { rx: number, ry: number, rz: number }
-- Offsets of one frame by bone key (NpcPose.KEYS); a key not listed stays at its base pose.
export type Frame = { [string]: Euler }
-- The base pose of one arm in root axes: `arm` turns the upper arm from rest, `fore` turns the forearm after it.
export type ArmPose = { arm: Mat, fore: Mat }
export type Activity = "idle" | "talk" | "hammer"

-- The bones the layer drives, by the Mixamo name without its prefix.
NpcPose.KEYS = {
	"Hips",
	"Spine",
	"Spine1",
	"Spine2",
	"Neck",
	"Head",
	"LeftShoulder",
	"RightShoulder",
	"LeftArm",
	"RightArm",
	"LeftForeArm",
	"RightForeArm",
	"LeftHand",
	"RightHand",
}
local KNOWN: { [string]: string } = {}
for _, key in NpcPose.KEYS do
	KNOWN[string.lower(key)] = key
end

-- Relaxed stance (looks, not balance): the upper arm hangs this far out from the body (so it clears a wide hip) and
-- this far forward; the elbow bends forward by ELBOW.
NpcPose.SPREAD = math.rad(9)
NpcPose.FORWARD = math.rad(4)
NpcPose.ELBOW = math.rad(16)
-- The model attribute "ArmSpread" (degrees) overrides SPREAD within these bounds (a broad smith, a thin scholar).
NpcPose.SPREAD_MIN = 0
NpcPose.SPREAD_MAX = 40

-- W31 (owner 2026-10-21: the NPCs without a model stood frozen): an R15 figure moves through its Motor6Ds, named here
-- with the bone key whose offsets each one carries (Anim/NpcRig.newR15). It has fewer joints than the skeleton: the
-- chest's and the clavicles' offsets fold onto the waist and the shoulders (NpcPose.fold).
NpcPose.R15_JOINTS = table.freeze({
	Root = "Hips",
	Waist = "Spine",
	Neck = "Neck",
	RightShoulder = "RightArm",
	LeftShoulder = "LeftArm",
	RightElbow = "RightForeArm",
	LeftElbow = "LeftForeArm",
	RightWrist = "RightHand",
	LeftWrist = "LeftHand",
} :: { [string]: string })
NpcPose.FOLD = table.freeze({
	Spine1 = "Spine",
	Spine2 = "Spine",
	Head = "Neck",
	RightShoulder = "RightArm",
	LeftShoulder = "LeftArm",
} :: { [string]: string })
-- The R15 body's arms hang close to its sides already: a smaller spread and elbow bend than a model's T-pose needs.
NpcPose.R15_SPREAD = math.rad(5)
NpcPose.R15_ELBOW = math.rad(12)

local IDENTITY: Mat = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
NpcPose.IDENTITY = IDENTITY

---------------------------------------------------------------- vectors and matrices

local function length(v: Vec): number
	return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
end

-- Unit vector of `v`, or nil for a (near) zero one.
function NpcPose.unit(v: Vec): Vec?
	local l = length(v)
	if l < 1e-6 then
		return nil
	end
	return { v[1] / l, v[2] / l, v[3] / l }
end

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

function NpcPose.mul(a: Mat, b: Mat): Mat
	local out = table.create(9, 0)
	for r = 0, 2 do
		for c = 1, 3 do
			out[r * 3 + c] = a[r * 3 + 1] * b[c] + a[r * 3 + 2] * b[3 + c] + a[r * 3 + 3] * b[6 + c]
		end
	end
	return out
end

-- The inverse of a rotation.
function NpcPose.transpose(m: Mat): Mat
	return { m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9] }
end

function NpcPose.apply(m: Mat, v: Vec): Vec
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- Rotation by `angle` (right hand) about the unit `axis`.
function NpcPose.axisAngle(axis: Vec, angle: number): Mat
	local x, y, z = axis[1], axis[2], axis[3]
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return {
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c,
	}
end

-- The shortest turn that takes direction `from` onto direction `to` (identity for a zero vector). Opposite
-- directions turn half a circle about any axis square to `from`.
function NpcPose.fromTo(from: Vec, to: Vec): Mat
	local a, b = NpcPose.unit(from), NpcPose.unit(to)
	if not a or not b then
		return IDENTITY
	end
	local d = math.clamp(dot(a, b), -1, 1)
	if d > 1 - 1e-9 then
		return IDENTITY
	end
	local axis = NpcPose.unit(cross(a, b))
	if not axis then
		-- opposite: any perpendicular axis (x unless `a` lies along it)
		axis = NpcPose.unit(cross(a, if math.abs(a[1]) < 0.9 then { 1, 0, 0 } else { 0, 1, 0 }))
	end
	return NpcPose.axisAngle(axis :: Vec, math.acos(d))
end

-- Turn of Euler angles in root axes: yaw about up (Y), then pitch about the side (X), then roll about the front (Z).
function NpcPose.euler(e: Euler): Mat
	local m = IDENTITY
	if e.ry ~= 0 then
		m = NpcPose.axisAngle({ 0, 1, 0 }, e.ry)
	end
	if e.rx ~= 0 then
		m = NpcPose.mul(m, NpcPose.axisAngle({ 1, 0, 0 }, e.rx))
	end
	if e.rz ~= 0 then
		m = NpcPose.mul(m, NpcPose.axisAngle({ 0, 0, 1 }, e.rz))
	end
	return m
end

-- rest^-1 * c * rest: a turn `c` in root axes as a bone's Transform (its own frame), `rest` its rest rotation in root
-- space.
function NpcPose.toLocal(rest: Mat, c: Mat): Mat
	return NpcPose.mul(NpcPose.mul(NpcPose.transpose(rest), c), rest)
end

---------------------------------------------------------------- bones and the stance

-- The bone key (NpcPose.KEYS) of a bone name: "mixamorig:LeftArm", "mixamorig1:LeftArm", "mixamorig_LeftArm" and
-- "LeftArm" (any case) are all "LeftArm"; nil for a bone the layer does not drive.
function NpcPose.boneKey(name: string): string?
	local bare = string.match(name, "[^:]*$") or name
	bare = string.gsub(bare, "^[Mm][Ii][Xx][Aa][Mm][Oo][Rr][Ii][Gg]%d*_", "")
	return KNOWN[string.lower(bare)]
end

-- Where the upper arm of `side` (1 right, -1 left) points in the relaxed stance (root space).
function NpcPose.armTarget(side: number, spread: number?): Vec
	local s = spread or NpcPose.SPREAD
	local f = NpcPose.FORWARD
	return NpcPose.unit({ side * math.sin(s), -math.cos(s) * math.cos(f), -math.sin(f) }) :: Vec
end

-- Where the forearm points: the arm's target bent forward by `elbow` about the side axis.
function NpcPose.foreTarget(side: number, spread: number?, elbow: number?): Vec
	local bend = NpcPose.axisAngle({ 1, 0, 0 }, elbow or NpcPose.ELBOW)
	return NpcPose.apply(bend, NpcPose.armTarget(side, spread))
end

-- The relaxed pose of one arm from its rest directions in root space (`armDir` shoulder -> elbow, `foreDir` elbow ->
-- wrist; nil = straight on from the arm): `arm` takes the upper arm onto its target, `fore` the forearm (already
-- carried by `arm`) onto its own.
function NpcPose.armPose(side: number, armDir: Vec, foreDir: Vec?, spread: number?, elbow: number?): ArmPose
	local arm = NpcPose.fromTo(armDir, NpcPose.armTarget(side, spread))
	local carried = NpcPose.apply(arm, foreDir or armDir)
	local fore = NpcPose.fromTo(carried, NpcPose.foreTarget(side, spread, elbow))
	return { arm = arm, fore = fore }
end

-- The upper arm's turn C (root axes, relative to its parent) with a gesture `g` laid over the stance.
function NpcPose.armTurn(pose: ArmPose, g: Euler?): Mat
	return if g then NpcPose.mul(NpcPose.euler(g), pose.arm) else pose.arm
end

-- The forearm's turn C relative to the upper arm: the stance's bend plus `bend` more radians about the elbow's hinge
-- (the side axis of the posed arm): arm^-1 * hinge * fore * arm.
function NpcPose.foreTurn(pose: ArmPose, bend: number?): Mat
	local turn = pose.fore
	if bend and bend ~= 0 then
		turn = NpcPose.mul(NpcPose.axisAngle({ 1, 0, 0 }, bend), turn)
	end
	return NpcPose.mul(NpcPose.mul(NpcPose.transpose(pose.arm), turn), pose.arm)
end

-- "ArmSpread" attribute (degrees) as radians, nil outside the bounds or not a number.
function NpcPose.spread(attribute: any): number?
	if type(attribute) == "number" and attribute >= NpcPose.SPREAD_MIN and attribute <= NpcPose.SPREAD_MAX then
		return math.rad(attribute)
	end
	return nil
end

-- Yaw (about up) that turns the front (-Z) toward a point at (dx, dz) in root space.
function NpcPose.faceYaw(dx: number, dz: number): number
	if dx * dx + dz * dz < 1e-8 then
		return 0
	end
	return math.atan2(-dx, -dz)
end

-- `current` moved toward `target` by at most `rate * dt` radians the short way round (angles wrap).
function NpcPose.turnToward(current: number, target: number, rate: number, dt: number): number
	local diff = (target - current + math.pi) % (2 * math.pi) - math.pi
	local step = rate * dt
	if math.abs(diff) <= step then
		return current + diff
	end
	return current + (if diff > 0 then step else -step)
end

---------------------------------------------------------------- motion

-- Breathing period (s) and depth (rad of the chest), weight shift period and roll of the hips, look-around.
local BREATH_PERIOD = 4.2
local BREATH = 0.022
local SHIFT_PERIOD = 9
local SHIFT = 0.03
NpcPose.LOOK_EVERY = 5.5 -- s between two looks
NpcPose.LOOK_TURN = 0.8 -- s the head takes to turn
NpcPose.LOOK_YAW = math.rad(35)
NpcPose.LOOK_PITCH = math.rad(8)
-- Talk: one gesture beat every TALK_BEAT s; nods in between.
NpcPose.TALK_BEAT = 1.7
-- Hammering: one blow every HAMMER_BEAT s (raise, strike, rest).
NpcPose.HAMMER_BEAT = 1.35

-- Deterministic 0..1 value of (n, seed).
local function hash01(n: number, seed: number): number
	local h = (math.floor(n) * 374761393 + math.floor(seed * 1000) * 668265263) % 2147483647
	h = (h * 48271) % 2147483647
	h = (h * 48271) % 2147483647
	return h / 2147483647
end
NpcPose.hash01 = hash01

local function smooth(x: number): number
	local t = math.clamp(x, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Head look of the idle at time `t`: { yaw, pitch }. Every LOOK_EVERY seconds the head picks a new target (some
-- slots look straight ahead) and turns to it over LOOK_TURN seconds.
function NpcPose.look(t: number, seed: number): (number, number)
	local shifted = t + seed * 13.7
	local slot = math.floor(shifted / NpcPose.LOOK_EVERY)
	local function target(n: number): (number, number)
		local roll = hash01(n, seed)
		if roll < 0.35 then
			return 0, 0 -- ahead
		end
		local yaw = (hash01(n + 7919, seed) * 2 - 1) * NpcPose.LOOK_YAW
		local pitch = (hash01(n + 104729, seed) * 2 - 1) * NpcPose.LOOK_PITCH
		return yaw, pitch
	end
	local y0, p0 = target(slot - 1)
	local y1, p1 = target(slot)
	local k = smooth((shifted - slot * NpcPose.LOOK_EVERY) / NpcPose.LOOK_TURN)
	return y0 + (y1 - y0) * k, p0 + (p1 - p0) * k
end

local function add(frame: Frame, key: string, rx: number, ry: number, rz: number)
	local e = frame[key]
	if e then
		e.rx += rx
		e.ry += ry
		e.rz += rz
	else
		frame[key] = { rx = rx, ry = ry, rz = rz }
	end
end

-- The idle at time `t`: breathing (spine and chest), weight shift (hips roll, the spine leans back), arms swaying
-- with the breath and the head looking around (blink-free: the models have no eyelids).
local function idle(frame: Frame, t: number, seed: number, lookAround: boolean)
	local breath = math.sin((t + seed * 3.1) * 2 * math.pi / BREATH_PERIOD)
	local shift = math.sin((t + seed * 5.3) * 2 * math.pi / SHIFT_PERIOD)
	add(frame, "Hips", 0, 0, SHIFT * shift)
	add(frame, "Spine", 0, 0, -SHIFT * 0.6 * shift)
	add(frame, "Spine1", BREATH * 0.4 * breath, 0, 0)
	add(frame, "Spine2", BREATH * breath, 0, -SHIFT * 0.3 * shift)
	add(frame, "RightShoulder", 0, 0, BREATH * 0.5 * breath)
	add(frame, "LeftShoulder", 0, 0, -BREATH * 0.5 * breath)
	add(frame, "RightArm", BREATH * 0.4 * breath, 0, 0)
	add(frame, "LeftArm", BREATH * 0.4 * breath, 0, 0)
	add(frame, "Neck", -BREATH * 0.5 * breath, 0, 0)
	if lookAround then
		local yaw, pitch = NpcPose.look(t, seed)
		add(frame, "Neck", pitch * 0.4, yaw * 0.4, 0)
		add(frame, "Head", pitch * 0.6, yaw * 0.6, 0)
	end
end

-- Talking, `t` seconds after the dialogue opened: beats of hand gestures (the hands take turns, now and then both),
-- the forearm rising and opening outward, the head nodding between the beats.
local function talk(frame: Frame, t: number, seed: number)
	local beat = math.floor(t / NpcPose.TALK_BEAT)
	local phase = (t - beat * NpcPose.TALK_BEAT) / NpcPose.TALK_BEAT
	-- the gesture swells, holds and falls back inside its beat
	local env = math.sin(math.clamp(phase, 0, 1) * math.pi)
	env = env * env
	local pick = hash01(beat, seed)
	local right = pick < 0.45 or pick > 0.8
	local left = pick >= 0.45
	local size = 0.7 + 0.3 * hash01(beat + 31, seed)
	for _, side in { 1, -1 } do
		local on = if side == 1 then right else left
		if on then
			local arm = if side == 1 then "RightArm" else "LeftArm"
			-- arm a little forward and out, the forearm turns out with the open hand
			add(frame, arm, 0.35 * env * size, -side * 0.25 * env * size, side * 0.12 * env * size)
			add(frame, if side == 1 then "RightHand" else "LeftHand", 0, 0, side * 0.3 * env)
			frame[if side == 1 then "_bendR" else "_bendL"] = { rx = 0.95 * env * size, ry = 0, rz = 0 }
		end
	end
	-- nods: a short dip at the start of every other beat, a slow tilt of the head toward the listener
	local nod = if beat % 2 == 0 then math.max(0, math.sin(phase * 2 * math.pi)) else 0
	add(frame, "Head", -0.16 * nod, 0, 0.05 * math.sin(t * 0.9 + seed))
	add(frame, "Spine2", 0.03 * env, 0, 0)
end

-- Hammering at an anvil in front: the right arm rises over the shoulder, strikes down in a quarter of the beat and
-- rests; the chest leans into the blow.
local function hammer(frame: Frame, t: number, seed: number)
	local phase = ((t + seed) % NpcPose.HAMMER_BEAT) / NpcPose.HAMMER_BEAT
	local lift
	if phase < 0.55 then
		lift = smooth(phase / 0.55) -- raise
	elseif phase < 0.7 then
		lift = 1 - smooth((phase - 0.55) / 0.15) -- strike
	else
		lift = 0 -- rest on the anvil
	end
	add(frame, "RightArm", 0.55 + 1.15 * lift, 0, 0.1)
	frame._bendR = { rx = 0.9 + 0.6 * lift, ry = 0, rz = 0 }
	add(frame, "LeftArm", 0.5, 0.2, 0)
	frame._bendL = { rx = 0.9, ry = 0, rz = 0 }
	add(frame, "Spine2", 0.12 - 0.08 * lift, 0, 0)
	add(frame, "Head", -0.2, 0, 0)
end

-- One frame of motion: offsets by bone key plus the elbow bends `_bendR` / `_bendL` (rx = extra bend, radians).
-- `blend` 0..1 fades talking in (and the idle look out); `facing` is the yaw of the whole body (Hips).
function NpcPose.frame(t: number, seed: number, activity: Activity, blend: number, facing: number): Frame
	local frame: Frame = {}
	idle(frame, t, seed, activity == "idle")
	if activity == "talk" and blend > 0 then
		local talking: Frame = {}
		talk(talking, t, seed)
		for key, e in talking do
			add(frame, key, e.rx * blend, e.ry * blend, e.rz * blend)
		end
	elseif activity == "hammer" then
		hammer(frame, t, seed)
	end
	if facing ~= 0 then
		add(frame, "Hips", 0, facing, 0)
	end
	return frame
end

-- W31: a frame for an R15 figure: every offset on the joint that carries it (NpcPose.FOLD; the angles are small, so
-- they add), the elbow bends as they are. A new frame; `frame` is not changed.
function NpcPose.fold(frame: Frame): Frame
	local out: Frame = {}
	for key, e in frame do
		add(out, NpcPose.FOLD[key] or key, e.rx, e.ry, e.rz)
	end
	return out
end

return NpcPose
