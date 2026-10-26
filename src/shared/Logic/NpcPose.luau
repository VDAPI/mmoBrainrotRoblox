--!strict
-- The rotation math every procedural rig shares (W30 began it for the NPCs; 2026-10-26 the NPCs moved onto the biped
-- template: Logic/NpcMotion on Logic/BipedPose), the R15 joints an NPC figure without a model is posed through, and
-- the deterministic hash the motions draw their choices from. Pure.
-- * Rotations are 3x3 matrices (row-major, the order of CFrame.new(x, y, z, R00, R01, ...)).

local NpcPose = {}

export type Vec = { number } -- { x, y, z }
export type Mat = { number } -- 9 numbers, row-major

-- W31 (owner 2026-10-21: the NPCs without a model stood frozen): an R15 figure moves through its Motor6Ds; each joint
-- turns its Part1 like the skeleton key named here (client/Anim/NpcRig.newR15: the joint's Transform from that key's
-- world turn relative to `R15_PARENT`'s). The R15 body bends only at the waist, so the chest's whole turn is on it.
NpcPose.R15_JOINTS = table.freeze({
	Root = "Hips",
	Waist = "Spine2",
	Neck = "Head",
	RightShoulder = "RightArm",
	LeftShoulder = "LeftArm",
	RightElbow = "RightForeArm",
	LeftElbow = "LeftForeArm",
	RightWrist = "RightHand",
	LeftWrist = "LeftHand",
	RightHip = "RightUpLeg",
	LeftHip = "LeftUpLeg",
	RightKnee = "RightLeg",
	LeftKnee = "LeftLeg",
	RightAnkle = "RightFoot",
	LeftAnkle = "LeftFoot",
} :: { [string]: string })
-- The key whose turn each R15 joint's Transform is relative to (its Part0's); the root's is nil.
NpcPose.R15_PARENT = table.freeze({
	Waist = "Hips",
	Neck = "Spine2",
	RightShoulder = "Spine2",
	LeftShoulder = "Spine2",
	RightElbow = "RightArm",
	LeftElbow = "LeftArm",
	RightWrist = "RightForeArm",
	LeftWrist = "LeftForeArm",
	RightHip = "Hips",
	LeftHip = "Hips",
	RightKnee = "RightUpLeg",
	LeftKnee = "LeftUpLeg",
	RightAnkle = "RightLeg",
	LeftAnkle = "LeftLeg",
} :: { [string]: string })

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

-- rest^-1 * c * rest: a turn `c` in root axes as a joint's Transform (its own frame), `rest` its rest rotation in root
-- space.
function NpcPose.toLocal(rest: Mat, c: Mat): Mat
	return NpcPose.mul(NpcPose.mul(NpcPose.transpose(rest), c), rest)
end

-- Deterministic 0..1 value of (n, seed).
local function hash01(n: number, seed: number): number
	local h = (math.floor(n) * 374761393 + math.floor(seed * 1000) * 668265263) % 2147483647
	h = (h * 48271) % 2147483647
	h = (h * 48271) % 2147483647
	return h / 2147483647
end
NpcPose.hash01 = hash01

return NpcPose
