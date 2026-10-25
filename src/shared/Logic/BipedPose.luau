--!strict
-- Template animation (owner 2026-10-25: "the monsters are animated terribly"): the pose of an imported biped monster
-- (Tripo model, Mixamo bones, Data/MonsterAssets rig "bones") built from a small set of named controls instead of
-- clips. Pure: client/Anim/BipedRig reads the bones' rest frames in the model's root space (front -Z, up +Y, right +X)
-- and writes the Bone.Transform this module returns; Logic/BipedMotion fills the controls (locomotion, actions,
-- reactions), so every motion blends as plain numbers and the same controls fit any biped's proportions.
-- * A bone's world turn W (root axes, applied to its rest frame) becomes its Transform as R^-1 * (Wparent^-1 * W) * R,
--   R its rest rotation (the convention of Logic/NpcPose and client/Anim/BoneOverlay).
-- * Arms live in a canonical frame: hanging straight down, the elbow bending forward about the side axis (X), so a
--   pose reads the same on every export whatever its bones' own axes.
-- * Legs are solved by two-bone IK to a foot target on the ground (feet planted, no sliding); the knee points along the
--   pelvis' front; the foot keeps its own flat orientation turned by its yaw and pitch.
-- Signs (controls): pitch > 0 bends forward (the torso, the head down), yaw > 0 turns left, roll > 0 leans left; an arm's
-- `p` > 0 raises it forward, `o` > 0 lifts it out sideways, `y` > 0 swings it in across the body, `t` > 0 twists it
-- inward, elbow > 0 bends the forearm forward; a foot's `p` > 0 lifts its toes, the toe bend > 0 lifts the toes alone.

local NpcPose = require("./NpcPose")

local BipedPose = {}

export type Vec = { number }
export type Mat = { number }

-- The driven bones (Mixamo names without the prefix) and their parents (nil = the root).
BipedPose.KEYS = {
	"Hips",
	"Spine",
	"Spine1",
	"Spine2",
	"Neck",
	"Head",
	"LeftShoulder",
	"LeftArm",
	"LeftForeArm",
	"LeftHand",
	"RightShoulder",
	"RightArm",
	"RightForeArm",
	"RightHand",
	"LeftUpLeg",
	"LeftLeg",
	"LeftFoot",
	"LeftToeBase",
	"RightUpLeg",
	"RightLeg",
	"RightFoot",
	"RightToeBase",
}
BipedPose.PARENT = table.freeze({
	Spine = "Hips",
	Spine1 = "Spine",
	Spine2 = "Spine1",
	Neck = "Spine2",
	Head = "Neck",
	LeftShoulder = "Spine2",
	LeftArm = "LeftShoulder",
	LeftForeArm = "LeftArm",
	LeftHand = "LeftForeArm",
	RightShoulder = "Spine2",
	RightArm = "RightShoulder",
	RightForeArm = "RightArm",
	RightHand = "RightForeArm",
	LeftUpLeg = "Hips",
	LeftLeg = "LeftUpLeg",
	LeftFoot = "LeftLeg",
	LeftToeBase = "LeftFoot",
	RightUpLeg = "Hips",
	RightLeg = "RightUpLeg",
	RightFoot = "RightLeg",
	RightToeBase = "RightFoot",
} :: { [string]: string })

-- The bones a rig needs (without them the model keeps its clips).
BipedPose.REQUIRED = {
	"Hips",
	"Spine",
	"Spine2",
	"Head",
	"LeftArm",
	"LeftForeArm",
	"LeftHand",
	"RightArm",
	"RightForeArm",
	"RightHand",
	"LeftUpLeg",
	"LeftLeg",
	"LeftFoot",
	"RightUpLeg",
	"RightLeg",
	"RightFoot",
}

-- How the spine's and the head's turns spread over their bones.
local SPINE_SHARE = { Spine = 0.3, Spine1 = 0.33, Spine2 = 0.37 }
local NECK_SHARE = 0.4

-- The controls (every value a number, 0 = neutral: arms straight down, legs at rest).
-- Pelvis: px py pz (leg lengths, root axes), pyaw ppitch proll. Spine: syaw spitch sroll. Head: hyaw hpitch hroll.
-- Clavicles: cRu cRf cLu cLf (shrug up, forward). Arms: a<S>p a<S>o a<S>y a<S>t e<S> w<S>p w<S>y w<S>r (S = R / L).
-- Feet (target offsets from the rest ankle, leg lengths, root axes): f<S>x f<S>y f<S>z f<S>yaw f<S>p f<S>r t<S> (toe
-- bend).
BipedPose.CONTROLS = {
	"px",
	"py",
	"pz",
	"pyaw",
	"ppitch",
	"proll",
	"syaw",
	"spitch",
	"sroll",
	"hyaw",
	"hpitch",
	"hroll",
	"cRu",
	"cRf",
	"cLu",
	"cLf",
	"aRp",
	"aRo",
	"aRy",
	"aRt",
	"eR",
	"wRp",
	"wRy",
	"wRr",
	"aLp",
	"aLo",
	"aLy",
	"aLt",
	"eL",
	"wLp",
	"wLy",
	"wLr",
	"fRx",
	"fRy",
	"fRz",
	"fRyaw",
	"fRp",
	"fRr",
	"tR",
	"fLx",
	"fLy",
	"fLz",
	"fLyaw",
	"fLp",
	"fLr",
	"tL",
}
export type Controls = { [string]: number }

---------------------------------------------------------------- math

local IDENTITY: Mat = NpcPose.IDENTITY
local mul, transpose, apply, axisAngle = NpcPose.mul, NpcPose.transpose, NpcPose.apply, NpcPose.axisAngle
local unit = NpcPose.unit

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function add(a: Vec, b: Vec): Vec
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function scale(a: Vec, k: number): Vec
	return { a[1] * k, a[2] * k, a[3] * k }
end

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function length(a: Vec): number
	return math.sqrt(dot(a, a))
end

local function rx(a: number): Mat
	return if a == 0 then IDENTITY else axisAngle({ 1, 0, 0 }, a)
end

local function ry(a: number): Mat
	return if a == 0 then IDENTITY else axisAngle({ 0, 1, 0 }, a)
end

local function rz(a: number): Mat
	return if a == 0 then IDENTITY else axisAngle({ 0, 0, 1 }, a)
end
BipedPose.rx, BipedPose.ry, BipedPose.rz = rx, ry, rz

-- Body turn of yaw / pitch / roll controls (yaw outermost; pitch > 0 forward = a negative turn about X).
local function body(yaw: number, pitch: number, roll: number): Mat
	return mul(mul(ry(yaw), rx(-pitch)), rz(roll))
end
BipedPose.body = body

-- The rotation whose columns are the axes x, y, z.
local function columns(x: Vec, y: Vec, z: Vec): Mat
	return { x[1], y[1], z[1], x[2], y[2], z[2], x[3], y[3], z[3] }
end

---------------------------------------------------------------- the skeleton

export type Bone = { rest: Mat, pos: Vec }
export type Skeleton = {
	bones: { [string]: Bone },
	armFit: { [string]: Mat }, -- "R" / "L": rest upper arm -> canonical (hanging down)
	foreFit: { [string]: Mat }, -- rest forearm (and hand) -> canonical
	leg: { [string]: { l1: number, l2: number, thighRest: Mat, shinRest: Mat, hip: Vec, ankle: Vec } },
	legLength: number, -- hip joint over the ground (studs): the scale of every distance the motion uses
	dirs: { [string]: Vec }, -- rest direction of each bone toward its child joint (root space)
}

-- The child joint whose direction retargets a bone (the extra end bones are read only for their positions).
BipedPose.TIP = table.freeze({
	Hips = "Spine",
	Spine = "Spine1",
	Spine1 = "Spine2",
	Spine2 = "Neck",
	Neck = "Head",
	Head = "HeadTop_End",
	LeftShoulder = "LeftArm",
	LeftArm = "LeftForeArm",
	LeftForeArm = "LeftHand",
	LeftHand = "LeftHandMiddle1",
	RightShoulder = "RightArm",
	RightArm = "RightForeArm",
	RightForeArm = "RightHand",
	RightHand = "RightHandMiddle1",
	LeftUpLeg = "LeftLeg",
	LeftLeg = "LeftFoot",
	LeftFoot = "LeftToeBase",
	LeftToeBase = "LeftToe_End",
	RightUpLeg = "RightLeg",
	RightLeg = "RightFoot",
	RightFoot = "RightToeBase",
	RightToeBase = "RightToe_End",
} :: { [string]: string })

local DOWN: Vec = { 0, -1, 0 }
local FRONT: Vec = { 0, 0, -1 }

-- The skeleton from the bones' rest rotations and positions in root space (`bones[key] = { rest, pos }`); nil when a
-- REQUIRED bone is missing.
function BipedPose.skeleton(bones: { [string]: Bone }): Skeleton?
	for _, key in BipedPose.REQUIRED do
		if not bones[key] then
			return nil
		end
	end
	local armFit, foreFit = {}, {}
	local leg = {}
	local legLength = 0
	for _, s in { "R", "L" } do
		local side = if s == "R" then "Right" else "Left"
		local arm, fore, hand = bones[side .. "Arm"], bones[side .. "ForeArm"], bones[side .. "Hand"]
		armFit[s] = NpcPose.fromTo(sub(fore.pos, arm.pos), DOWN)
		foreFit[s] = NpcPose.fromTo(sub(hand.pos, fore.pos), DOWN)
		local hip, knee, ankle = bones[side .. "UpLeg"].pos, bones[side .. "Leg"].pos, bones[side .. "Foot"].pos
		local thigh, shin = sub(knee, hip), sub(ankle, knee)
		-- the knee's rest front: the bend of the rest leg, or straight ahead for a straight one
		local hinge = unit(cross(thigh, FRONT)) or { 1, 0, 0 }
		leg[s] = {
			l1 = length(thigh),
			l2 = length(shin),
			thighRest = columns(hinge, unit(thigh) :: Vec, cross(hinge, unit(thigh) :: Vec)),
			shinRest = columns(hinge, unit(shin) :: Vec, cross(hinge, unit(shin) :: Vec)),
			hip = hip,
			ankle = ankle,
		}
		legLength = math.max(legLength, hip[2])
	end
	-- rest directions to each bone's child joint (Logic/BipedClip.fit: mocap retargeting)
	local dirs: { [string]: Vec } = {}
	for key, child in BipedPose.TIP do
		local a, b = bones[key], bones[child]
		if a and b then
			local d = unit(sub(b.pos, a.pos))
			if d then
				dirs[key] = d
			end
		end
	end
	return { bones = bones, armFit = armFit, foreFit = foreFit, leg = leg, legLength = legLength, dirs = dirs }
end

---------------------------------------------------------------- the pose

local function c(controls: Controls, key: string): number
	return controls[key] or 0
end

-- An arm's canonical turn (hanging down -> posed), mirrored for the left side.
local function armTurn(controls: Controls, s: string): Mat
	local m = if s == "R" then 1 else -1
	return mul(
		mul(
			mul(ry(m * c(controls, "a" .. s .. "y")), rz(m * c(controls, "a" .. s .. "o"))),
			rx(c(controls, "a" .. s .. "p"))
		),
		ry(m * c(controls, "a" .. s .. "t"))
	)
end

-- Two-bone IK: the thigh and shin directions that put the ankle of a leg (hip at `hip`, lengths l1, l2) on `target`
-- with the knee toward `front`.
function BipedPose.solveLeg(hip: Vec, target: Vec, l1: number, l2: number, front: Vec): (Vec, Vec, Vec)
	local v = sub(target, hip)
	local d = length(v)
	local reach = (l1 + l2) * 0.999
	local short = math.abs(l1 - l2) * 1.02 + 1e-3
	local dir = unit(v) or DOWN
	d = math.clamp(d, short, reach)
	local cosA = math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1)
	local sinA = math.sqrt(1 - cosA * cosA)
	-- the front square to the reach
	local f = unit(sub(front, scale(dir, dot(front, dir)))) or unit(cross({ 1, 0, 0 }, dir)) or FRONT
	local thigh = add(scale(dir, cosA), scale(f, sinA))
	local knee = add(hip, scale(thigh, l1))
	local ankle = add(hip, scale(dir, d))
	local shin = unit(sub(ankle, knee)) or dir
	return thigh, shin, f
end

export type Posed = { [string]: { rot: Mat, offset: Vec? } } -- Transform per bone key (rotation, Hips translation)
export type World = { [string]: Mat } -- world turn (root axes) of every bone, applied to its rest frame

-- The world turns and the Hips offset (studs, root axes) for `controls`; `grip` is the direction of the weapon's blade
-- in the right hand at rest (root space, Data/BipedStyles `grip`), which the controls bRx bRy bRz aim.
function BipedPose.world(skel: Skeleton, controls: Controls, grip: Vec?): (World, Vec)
	local bones = skel.bones
	local world: World = {}
	-- pelvis
	local hips = body(c(controls, "pyaw"), c(controls, "ppitch"), c(controls, "proll"))
	world.Hips = hips
	-- distances are in leg lengths (hip joint over the ground), so a style fits any biped's size
	local L = skel.legLength
	local shift: Vec = { c(controls, "px") * L, c(controls, "py") * L, c(controls, "pz") * L }
	-- spine (the share of each bone, carried by its parent)
	local sy, sp, sr = c(controls, "syaw"), c(controls, "spitch"), c(controls, "sroll")
	local parent = hips
	for _, key in { "Spine", "Spine1", "Spine2" } do
		local k = SPINE_SHARE[key]
		if bones[key] then
			parent = mul(parent, body(sy * k, sp * k, sr * k))
			world[key] = parent
		end
	end
	local chest = world.Spine2 or parent
	local hy, hp, hr = c(controls, "hyaw"), c(controls, "hpitch"), c(controls, "hroll")
	world.Neck = mul(chest, body(hy * NECK_SHARE, hp * NECK_SHARE, hr * NECK_SHARE))
	world.Head = mul(world.Neck, body(hy * (1 - NECK_SHARE), hp * (1 - NECK_SHARE), hr * (1 - NECK_SHARE)))
	-- arms
	for _, s in { "R", "L" } do
		local side = if s == "R" then "Right" else "Left"
		local m = if s == "R" then 1 else -1
		-- the clavicle: shrug up (roll toward the head) and forward (yaw toward the front)
		local clav = mul(chest, mul(rz(m * c(controls, "c" .. s .. "u")), ry(m * c(controls, "c" .. s .. "f"))))
		world[side .. "Shoulder"] = clav
		local a = mul(clav, armTurn(controls, s))
		world[side .. "Arm"] = mul(a, skel.armFit[s])
		local elbow = mul(a, rx(c(controls, "e" .. s)))
		world[side .. "ForeArm"] = mul(elbow, skel.foreFit[s])
		local wrist = mul(
			mul(rx(c(controls, "w" .. s .. "p")), ry(m * c(controls, "w" .. s .. "y"))),
			rz(m * c(controls, "w" .. s .. "r"))
		)
		world[side .. "Hand"] = mul(mul(elbow, wrist), skel.foreFit[s])
	end
	-- the blade aimed: the wrist turns the weapon onto bRx bRy bRz (root axes); the vector's length (up to 1) weighs the
	-- aim against the wrist controls, so a key without an aim fades it out
	if grip then
		local b = { c(controls, "bRx"), c(controls, "bRy"), c(controls, "bRz") }
		local k = math.min(1, length(b))
		local d = unit(b)
		local hand = world.RightHand
		if d and k > 0.01 and hand then
			local aimed = mul(NpcPose.fromTo(apply(hand, grip), d), hand)
			world.RightHand = if k >= 0.999 then aimed else BipedPose.slerp(hand, aimed, k)
		end
	end
	-- legs: IK to the foot targets
	local hipsPos = add(bones.Hips.pos, shift)
	local pelvisFront = apply(hips, FRONT)
	for _, s in { "R", "L" } do
		local side = if s == "R" then "Right" else "Left"
		local leg = skel.leg[s]
		local hip = add(hipsPos, apply(hips, sub(leg.hip, bones.Hips.pos)))
		local target = add(
			leg.ankle,
			{ c(controls, "f" .. s .. "x") * L, c(controls, "f" .. s .. "y") * L, c(controls, "f" .. s .. "z") * L }
		)
		local footYaw = c(controls, "f" .. s .. "yaw")
		-- the knee follows the pelvis and a little the foot's turn
		local kneeFront = apply(ry(footYaw * 0.5), pelvisFront)
		local thigh, shin, f = BipedPose.solveLeg(hip, target, leg.l1, leg.l2, kneeFront)
		local hinge = unit(cross(thigh, f)) or { 1, 0, 0 }
		world[side .. "UpLeg"] = mul(columns(hinge, thigh, cross(hinge, thigh)), transpose(leg.thighRest))
		world[side .. "Leg"] = mul(columns(hinge, shin, cross(hinge, shin)), transpose(leg.shinRest))
		local foot = mul(
			mul(ry(c(controls, "pyaw") * 0.35 + footYaw), rx(c(controls, "f" .. s .. "p"))),
			rz(c(controls, "f" .. s .. "r"))
		)
		world[side .. "Foot"] = foot
		world[side .. "ToeBase"] = mul(foot, rx(c(controls, "t" .. s)))
	end
	return world, shift
end

-- The bones' Transforms (each in its bone's own frame) for world turns and a Hips offset.
function BipedPose.transforms(skel: Skeleton, world: World, shift: Vec): Posed
	local out: Posed = {}
	for key, w in world do
		local bone = skel.bones[key]
		if not bone then
			continue
		end
		local parentKey = BipedPose.PARENT[key]
		local pw = if parentKey then world[parentKey] or IDENTITY else IDENTITY
		local turn = mul(transpose(pw), w)
		local rest = bone.rest
		local entry = { rot = mul(mul(transpose(rest), turn), rest), offset = nil :: Vec? }
		if key == "Hips" then
			entry.offset = apply(transpose(rest), shift)
		end
		out[key] = entry
	end
	return out
end

-- The bones' Transforms for `controls`.
function BipedPose.solve(skel: Skeleton, controls: Controls, grip: Vec?): Posed
	local world, shift = BipedPose.world(skel, controls, grip)
	return BipedPose.transforms(skel, world, shift)
end

---------------------------------------------------------------- world-turn layers

-- Quaternion (x, y, z, w) of a rotation matrix.
local function toQuat(m: Mat): (number, number, number, number)
	local t = m[1] + m[5] + m[9]
	local x, y, z, w
	if t > 0 then
		local s = math.sqrt(t + 1) * 2
		w, x, y, z = 0.25 * s, (m[8] - m[6]) / s, (m[3] - m[7]) / s, (m[4] - m[2]) / s
	elseif m[1] > m[5] and m[1] > m[9] then
		local s = math.sqrt(1 + m[1] - m[5] - m[9]) * 2
		w, x, y, z = (m[8] - m[6]) / s, 0.25 * s, (m[2] + m[4]) / s, (m[3] + m[7]) / s
	elseif m[5] > m[9] then
		local s = math.sqrt(1 + m[5] - m[1] - m[9]) * 2
		w, x, y, z = (m[3] - m[7]) / s, (m[2] + m[4]) / s, 0.25 * s, (m[6] + m[8]) / s
	else
		local s = math.sqrt(1 + m[9] - m[1] - m[5]) * 2
		w, x, y, z = (m[4] - m[2]) / s, (m[3] + m[7]) / s, (m[6] + m[8]) / s, 0.25 * s
	end
	return x, y, z, w
end
BipedPose.toQuat = toQuat

local function fromQuat(x: number, y: number, z: number, w: number): Mat
	return {
		1 - 2 * (y * y + z * z),
		2 * (x * y - z * w),
		2 * (x * z + y * w),
		2 * (x * y + z * w),
		1 - 2 * (x * x + z * z),
		2 * (y * z - x * w),
		2 * (x * z - y * w),
		2 * (y * z + x * w),
		1 - 2 * (x * x + y * y),
	}
end

-- Rotation between `a` and `b` (k = 0 .. 1), the short way.
function BipedPose.slerp(a: Mat, b: Mat, k: number): Mat
	if k <= 0 then
		return a
	elseif k >= 1 then
		return b
	end
	local ax, ay, az, aw = toQuat(a)
	local bx, by, bz, bw = toQuat(b)
	local d = ax * bx + ay * by + az * bz + aw * bw
	if d < 0 then
		bx, by, bz, bw, d = -bx, -by, -bz, -bw, -d
	end
	local ka, kb
	if d > 0.9995 then
		ka, kb = 1 - k, k
	else
		local th = math.acos(math.clamp(d, -1, 1))
		local s = math.sin(th)
		ka, kb = math.sin((1 - k) * th) / s, math.sin(k * th) / s
	end
	local x, y, z, w = ax * ka + bx * kb, ay * ka + by * kb, az * ka + bz * kb, aw * ka + bw * kb
	local n = math.sqrt(x * x + y * y + z * z + w * w)
	return fromQuat(x / n, y / n, z / n, w / n)
end

-- Per bone, `a` toward `b` by `k` (times `mask[key]` when a mask is given: 0..1 per bone, missing = 0).
function BipedPose.blend(a: World, b: World, k: number, mask: { [string]: number }?): World
	local out: World = {}
	for key, m in a do
		local w = if mask then k * (mask[key] or 0) else k
		local other = b[key]
		out[key] = if other and w > 0 then BipedPose.slerp(m, other, w) else m
	end
	for key, m in b do
		if out[key] == nil then
			out[key] = m
		end
	end
	return out
end

-- Every descendant of `key` (and `key`) in the driven skeleton.
local CHILDREN: { [string]: { string } } = {}
local NONE: { string } = {}
for child, parentKey in BipedPose.PARENT do
	local list = CHILDREN[parentKey]
	if not list then
		list = {}
		CHILDREN[parentKey] = list
	end
	table.insert(list, child)
end

-- Turns the subtree rooted at `key` by `turn` (root axes) about the bone's joint: a rigid bend of the chain above it.
function BipedPose.turnSubtree(world: World, key: string, turn: Mat)
	local m = world[key]
	if m then
		world[key] = mul(turn, m)
	end
	for _, child in CHILDREN[key] or NONE do
		BipedPose.turnSubtree(world, child, turn)
	end
end

-- The joints' positions (root space) of a pose.
function BipedPose.positions(skel: Skeleton, world: World, shift: Vec): { [string]: Vec }
	local bones = skel.bones
	local out: { [string]: Vec } = {}
	local function walk(key: string)
		local bone = bones[key]
		local parentKey = BipedPose.PARENT[key]
		if not bone then
			return
		end
		if not parentKey then
			out[key] = add(bone.pos, shift)
		else
			local pp, pw = out[parentKey], world[parentKey] or IDENTITY
			local parentBone = bones[parentKey]
			if pp and parentBone then
				out[key] = add(pp, apply(pw, sub(bone.pos, parentBone.pos)))
			end
		end
		for _, child in CHILDREN[key] or NONE do
			walk(child)
		end
	end
	walk("Hips")
	return out
end

-- Re-solves the legs of a pose by IK so each ankle reaches `targets[S]` (root space; S = "R" / "L", nil keeps the
-- leg), the knee along its current bend and the foot keeping its world turn (planted feet, ground contact).
function BipedPose.fixLegs(skel: Skeleton, world: World, shift: Vec, targets: { [string]: Vec? })
	local at = BipedPose.positions(skel, world, shift)
	for _, s in { "R", "L" } do
		local target = targets[s]
		if not target then
			continue
		end
		local side = if s == "R" then "Right" else "Left"
		local leg = skel.leg[s]
		local hip, knee = at[side .. "UpLeg"], at[side .. "Leg"]
		local footTurn = world[side .. "Foot"]
		local toeTurn = world[side .. "ToeBase"]
		if not hip or not knee then
			continue
		end
		-- the current knee's front: from the line hip -> ankle toward the knee, else the pelvis front
		local ankle = at[side .. "Foot"] or target
		local line = unit(sub(ankle, hip)) or DOWN
		local toKnee = sub(knee, hip)
		local bend = sub(toKnee, scale(line, dot(toKnee, line)))
		local front = unit(bend) or apply(world.Hips or IDENTITY, FRONT)
		local thigh, shin, f = BipedPose.solveLeg(hip, target, leg.l1, leg.l2, front)
		local hinge = unit(cross(thigh, f)) or { 1, 0, 0 }
		world[side .. "UpLeg"] = mul(columns(hinge, thigh, cross(hinge, thigh)), transpose(leg.thighRest))
		world[side .. "Leg"] = mul(columns(hinge, shin, cross(hinge, shin)), transpose(leg.shinRest))
		if footTurn then
			world[side .. "Foot"] = footTurn
		end
		if toeTurn then
			world[side .. "ToeBase"] = toeTurn
		end
	end
end

---------------------------------------------------------------- controls

-- A + (B - A) * k for every control in either; the blade's aim (bRx bRy bRz) turns along the arc between the two
-- directions (over the top when they are opposite) while its weight changes in step.
function BipedPose.lerp(a: Controls, b: Controls, k: number): Controls
	local out: Controls = {}
	for key, v in a do
		out[key] = v + ((b[key] or 0) - v) * k
	end
	for key, v in b do
		if a[key] == nil then
			out[key] = v * k
		end
	end
	local va: Vec = { a.bRx or 0, a.bRy or 0, a.bRz or 0 }
	local vb: Vec = { b.bRx or 0, b.bRy or 0, b.bRz or 0 }
	local la, lb = length(va), length(vb)
	if la > 1e-4 or lb > 1e-4 then
		local da = unit(va) or unit(vb) :: Vec
		local db = unit(vb) or da
		local cosT = math.clamp(dot(da, db), -1, 1)
		local dir: Vec
		if cosT > 0.9999 then
			dir = da
		else
			local axis = unit(cross(da, db)) or { 1, 0, 0 }
			dir = apply(axisAngle(axis, math.acos(cosT) * k), da)
		end
		local w = la + (lb - la) * k
		out.bRx, out.bRy, out.bRz = dir[1] * w, dir[2] * w, dir[3] * w
	end
	return out
end

-- `into` += `b` * k (in place).
function BipedPose.addInto(into: Controls, b: Controls, k: number)
	for key, v in b do
		into[key] = (into[key] or 0) + v * k
	end
end

-- The upper body's controls (pelvis turn, spine, head, clavicles, arms): what an action takes over while the legs walk.
local UPPER: { [string]: boolean } = {}
for _, key in BipedPose.CONTROLS do
	local first = string.sub(key, 1, 1)
	if first == "s" or first == "h" or first == "c" or first == "a" or first == "e" or first == "w" then
		UPPER[key] = true
	end
end
BipedPose.UPPER = UPPER

return BipedPose
