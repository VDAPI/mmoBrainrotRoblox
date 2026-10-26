--!strict
-- NPC animation (owner 2026-10-26: "after the monster animations, the NPCs"): the joints of a town NPC driven by
-- Logic/NpcMotion on the biped template (Logic/BipedPose), in a space with the ground at its origin under the NPC's
-- HumanoidRootPart (front -Z), so every distance of the motion is in the NPC's own leg lengths.
-- * The owner's model (Tripo Auto Rig Biped, Mixamo bones, no clips; NpcService welds it as "Asset"): Bone.Transform
--   from the world turns (BipedPose.transforms), the fingers curled about their own hinge (the palm's normal crossed
--   with the finger) for the hands' grip, the pointing index straight; Data/NpcRigs says which arms keep a prop. The
--   hidden R15 figure under it follows the body's steps (its Root joint), so the name plate on its head walks along.
-- * An R15 figure in its outfit (W31: Motor6D or AnimationConstraint joints, Util/RigJoints): its fifteen joints'
--   Transforms from the same world turns (Logic/NpcPose.R15_JOINTS / R15_PARENT), its skeleton read off the joints
--   (the chest bends at the waist only); no fingers.
-- * Props the work needs: the smith's anvil before him (Data/NpcStyles.ANVIL) with a glowing piece on it, a hammer in
--   the hand of a figure that holds none of its own (R15 smiths, Data/NpcRigs `hammer`). Client only, no collisions.
-- Rest frames are read once with every Transform at identity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BipedPose = require(ReplicatedStorage.Shared.Logic.BipedPose)
local BipedRigs = require(ReplicatedStorage.Shared.Data.BipedRigs)
local NpcMotion = require(ReplicatedStorage.Shared.Logic.NpcMotion)
local NpcPose = require(ReplicatedStorage.Shared.Logic.NpcPose)
local NpcRigs = require(ReplicatedStorage.Shared.Data.NpcRigs)
local NpcStyles = require(ReplicatedStorage.Shared.Data.NpcStyles)
local RigJoints = require(ReplicatedStorage.Shared.Util.RigJoints)

local NpcRig = {}

type Mat = { number }

-- A finger bone: its hinge in its own frame, which hand, which finger and segment.
type Finger = { bone: Bone, axis: Vector3, side: string, finger: string, seg: number }
-- An R15 joint: the key whose turn it carries, the key its Part0 follows, its rest frame's rotation (root axes).
type Joint = { joint: RigJoints.Joint, key: string, parent: string?, rest: Mat }

export type Rig = {
	kind: "npc",
	mod: any, -- Logic/NpcMotion (AnimLab steps it through the rig)
	motion: NpcMotion.Instance,
	skel: BipedPose.Skeleton,
	space: CFrame, -- the motion's space in the root part's: the ground under the root
	root: BasePart,
	r15: boolean,
	bones: { [string]: Bone }, -- the owner's model: the pose keys' bones
	joints: { Joint }, -- an R15 figure
	fingers: { Finger },
	grip: { [string]: number }, -- the hands' shapes last written ("gR", "iR", "gL", "iL")
	follow: { joint: RigJoints.Joint, rest: CFrame, at: Vector3 }?, -- the hidden figure's Root under a model
	props: { Instance },
	hammer: { part: BasePart, bone: Bone, offset: CFrame }?, -- a hammer carried by a hand bone (the owner's model)
}

-- Curl (rad) of each finger segment at a full grip, and the thumb's; how much more each finger closes than the index.
local CURL = { 1.2, 1.45, 1.05 }
local THUMB_CURL = { 0.3, 0.5, 0.45 }
local FINGER_SHARE: { [string]: number } = { Index = 0.92, Middle = 1, Ring = 1.05, Pinky = 1.1, Thumb = 1 }
-- The hands' shapes are rewritten once they change by more than this.
local GRIP_EPS = 0.015
-- Studs the body must move before the hidden figure under a model follows it again.
local FOLLOW_EPS = 0.02

local IRON = Color3.fromRGB(58, 58, 64)
local WOOD = Color3.fromRGB(110, 78, 50)
local HOT = Color3.fromRGB(255, 120, 40)

local function toMat(cf: CFrame): Mat
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local function vec(v: Vector3): { number }
	return { v.X, v.Y, v.Z }
end

local function v3(v: { number }): Vector3
	return Vector3.new(v[1], v[2], v[3])
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 1e-6 then v.Unit else fallback
end

-- A part of a prop: anchored, without collisions or queries.
local function propPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

-- The fingers of the owner's model: each bone's hinge from the palm of its hand at rest (root space).
local function fingersOf(byName: { [string]: Bone }, restOf: { [string]: CFrame }): { Finger }
	type Seg = { name: string, pos: Vector3 }
	local hands: { [string]: { [string]: { [number]: Seg } } } = { Right = {}, Left = {} }
	local handPos: { [string]: Vector3 } = {}
	for name, cf in restOf do
		local bare = BipedRigs.keyOf(name)
		local side, finger, seg = string.match(bare, "^(%a-)Hand(%a+)(%d)$")
		if side and finger and seg and hands[side] then
			local list = hands[side][finger] or {}
			hands[side][finger] = list
			list[tonumber(seg) :: number] = { name = name, pos = cf.Position }
		elseif bare == "RightHand" or bare == "LeftHand" then
			handPos[if bare == "RightHand" then "Right" else "Left"] = cf.Position
		end
	end
	local out: { Finger } = {}
	for side, fingers in hands do
		local hand = handPos[side]
		local index, pinky, middle = fingers.Index, fingers.Pinky or fingers.Ring, fingers.Middle
		if not hand or not index or not index[1] or not pinky or not pinky[1] or not middle or not middle[1] then
			continue
		end
		local across = index[1].pos - pinky[1].pos
		local along = unitOr(middle[1].pos - hand, Vector3.yAxis)
		local palm = unitOr(if side == "Right" then across:Cross(along) else along:Cross(across), Vector3.xAxis)
		for finger, segs in fingers do
			if
				finger ~= "Thumb"
				and finger ~= "Index"
				and finger ~= "Middle"
				and finger ~= "Ring"
				and finger ~= "Pinky"
			then
				continue
			end
			for n = 1, 3 do
				local seg = segs[n]
				if not seg then
					continue
				end
				local nextSeg, prevSeg = segs[n + 1], segs[n - 1]
				local dir = if nextSeg
					then nextSeg.pos - seg.pos
					elseif prevSeg then seg.pos - prevSeg.pos
					else seg.pos - hand
				local axis = unitOr(dir, along):Cross(palm)
				if axis.Magnitude < 1e-4 then
					continue
				end
				table.insert(out, {
					bone = byName[seg.name],
					axis = restOf[seg.name].Rotation:VectorToObjectSpace(axis.Unit),
					side = if side == "Right" then "R" else "L",
					finger = finger :: string,
					seg = n,
				})
			end
		end
	end
	return out
end

-- The palm normals (root space) of the owner's model's hands, from their fingers' first bones.
local function palmsOf(restOf: { [string]: CFrame }): { [string]: { number } }
	local at: { [string]: Vector3 } = {}
	for name, cf in restOf do
		at[BipedRigs.keyOf(name)] = at[BipedRigs.keyOf(name)] or cf.Position
	end
	local out: { [string]: { number } } = {}
	for _, side in { "Right", "Left" } do
		local hand, index, pinky, middle =
			at[side .. "Hand"], at[side .. "HandIndex1"], at[side .. "HandPinky1"], at[side .. "HandMiddle1"]
		if hand and index and pinky and middle then
			local across = index - pinky
			local along = middle - hand
			local n = if side == "Right" then across:Cross(along) else along:Cross(across)
			if n.Magnitude > 1e-6 then
				out[if side == "Right" then "R" else "L"] = vec(n.Unit)
			end
		end
	end
	return out
end

-- The hidden R15 figure's Root joint under an owner's model (it carries the name plate along the body's steps).
local function followOf(npc: Model): { joint: RigJoints.Joint, rest: CFrame, at: Vector3 }?
	for _, joint in RigJoints.collect(npc) do
		if joint.name == "Root" then
			return { joint = joint, rest = joint.c0.Rotation, at = Vector3.zero }
		end
	end
	return nil
end

-- A rig for the NPC `npc` whose owner's model is `asset` (NpcService: child "Asset") in style `style`, nil without
-- the bones a biped needs.
function NpcRig.new(npc: Model, asset: Model, npcId: string, style: NpcStyles.Style, seed: number): Rig?
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local order: { Bone } = {}
	local byName: { [string]: Bone } = {}
	for _, item in asset:GetDescendants() do
		if item:IsA("Bone") then
			item.Transform = CFrame.identity
			if not byName[item.Name] then
				byName[item.Name] = item
				table.insert(order, item)
			end
		end
	end
	-- the ground: the bottom of the model's bounds (NpcService stands it on the figure's feet)
	local frame, size = asset:GetBoundingBox()
	local bottom = root.CFrame:PointToObjectSpace(frame.Position - Vector3.new(0, size.Y / 2, 0))
	local space = CFrame.new(0, bottom.Y, 0)
	local world = root.CFrame * space
	local rest: { [string]: BipedPose.Bone } = {}
	local restOf: { [string]: CFrame } = {}
	local names: { [string]: string } = {}
	for _, bone in order do
		local cf = world:ToObjectSpace(bone.WorldCFrame)
		restOf[bone.Name] = cf
		rest[bone.Name] = { rest = toMat(cf), pos = vec(cf.Position) }
		local key = BipedRigs.keyOf(bone.Name)
		if not names[key] then
			names[key] = bone.Name
		end
	end
	local data, keyed = BipedPose.collect(names, rest, nil)
	local skel = BipedPose.skeleton(data, nil)
	if not skel then
		return nil
	end
	local entry = NpcRigs.of(npcId)
	if entry.palms ~= false then
		NpcMotion.fitPalms(skel, palmsOf(restOf))
	end
	local bones: { [string]: Bone } = {}
	for key, name in keyed do
		bones[key] = byName[name]
	end
	local rig: Rig = {
		kind = "npc",
		mod = NpcMotion,
		motion = NpcMotion.new(skel, style, seed, NpcRigs.keep(entry)),
		skel = skel,
		space = space,
		root = root,
		r15 = false,
		bones = bones,
		joints = {},
		fingers = fingersOf(byName, restOf),
		grip = {},
		follow = followOf(npc),
		props = {},
		hammer = nil,
	}
	return rig
end

-- W31: a rig for an R15 figure without the owner's model (Motor6D or AnimationConstraint joints), nil without its
-- fifteen joints. Its skeleton is read off the joints' rest frames from the root outwards (Transform at identity).
function NpcRig.newR15(npc: Model, npcId: string, style: NpcStyles.Style, seed: number): Rig?
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local all = RigJoints.collect(npc)
	local byName: { [string]: RigJoints.Joint } = {}
	for _, j in all do
		if NpcPose.R15_JOINTS[j.name] and not byName[j.name] then
			byName[j.name] = j
		end
	end
	for name in NpcPose.R15_JOINTS do
		if not byName[name] then
			return nil
		end
	end
	for _, j in byName do
		RigJoints.set(j, CFrame.identity)
	end
	local rests = RigJoints.rests(root, all, CFrame.identity)
	for name in NpcPose.R15_JOINTS do
		if not rests[byName[name].part0] then
			return nil
		end
	end
	-- the ground under the feet
	local function bottomOf(name: string): number
		local part = byName[name].part1
		local cf = rests[part]
		return if cf then cf.Y - part.Size.Y / 2 else 0
	end
	local space = CFrame.new(0, math.min(bottomOf("RightAnkle"), bottomOf("LeftAnkle")), 0)
	local inverse = space:Inverse()
	local function at(name: string): CFrame
		local j = byName[name]
		return inverse * rests[j.part0] * j.c0
	end
	local function bone(cf: CFrame): BipedPose.Bone
		return { rest = toMat(cf), pos = vec(cf.Position) }
	end
	local function point(p: Vector3): BipedPose.Bone
		return { rest = NpcPose.IDENTITY, pos = vec(p) }
	end
	local waist, neck = at("Waist").Position, at("Neck").Position
	local data: { [string]: BipedPose.Bone } = {
		Hips = bone(at("Root")),
		-- the R15 chest turns at the waist alone: the spine's three keys sit on it
		Spine = point(waist),
		Spine1 = point(waist),
		Spine2 = point(waist),
		Neck = point(neck),
		Head = point(neck + (neck - waist) * 0.3),
	}
	for _, side in { "Right", "Left" } do
		local shoulder = at(side .. "Shoulder").Position
		data[side .. "Shoulder"] = point(Vector3.new(shoulder.X * 0.35, shoulder.Y, shoulder.Z))
		data[side .. "Arm"] = bone(at(side .. "Shoulder"))
		data[side .. "ForeArm"] = bone(at(side .. "Elbow"))
		data[side .. "Hand"] = bone(at(side .. "Wrist"))
		data[side .. "UpLeg"] = bone(at(side .. "Hip"))
		data[side .. "Leg"] = bone(at(side .. "Knee"))
		data[side .. "Foot"] = bone(at(side .. "Ankle"))
	end
	local skel = BipedPose.skeleton(data, nil)
	if not skel then
		return nil
	end
	local joints: { Joint } = {}
	for name, key in NpcPose.R15_JOINTS do
		table.insert(joints, {
			joint = byName[name],
			key = key,
			parent = NpcPose.R15_PARENT[name],
			rest = toMat(at(name)),
		})
	end
	local rig: Rig = {
		kind = "npc",
		mod = NpcMotion,
		motion = NpcMotion.new(skel, style, seed, NpcRigs.keep(NpcRigs.of(npcId))),
		skel = skel,
		space = space,
		root = root,
		r15 = true,
		bones = {},
		joints = joints,
		fingers = {},
		grip = {},
		follow = nil,
		props = {},
		hammer = nil,
	}
	return rig
end

-- The props the NPC's work needs (the smith's anvil, a hammer for a hand without one); `npc` holds them.
function NpcRig.addProps(rig: Rig, npc: Model, npcId: string)
	local work = rig.motion.style.work
	if not work or work.prop ~= "anvil" then
		return
	end
	local L = rig.skel.legLength
	local centre = rig.motion.centre
	local a = NpcStyles.ANVIL
	local base = rig.root.CFrame * rig.space * CFrame.new(centre[1] + a.x * L, 0, centre[3] + a.z * L)
	local folder = Instance.new("Model")
	folder.Name = "NpcAnvil"
	local top = a.top * L
	propPart(
		folder,
		"Foot",
		Vector3.new(0.42, 0.18, 0.32) * L,
		base * CFrame.new(0, 0.09 * L, 0),
		IRON,
		Enum.Material.Metal
	)
	propPart(
		folder,
		"Waist",
		Vector3.new(0.2 * L, top - 0.3 * L, 0.18 * L),
		base * CFrame.new(0, 0.18 * L + (top - 0.3 * L) / 2, 0),
		IRON,
		Enum.Material.Metal
	)
	propPart(
		folder,
		"Face",
		Vector3.new(0.5, 0.12, 0.2) * L,
		base * CFrame.new(-0.02 * L, top - 0.06 * L, 0),
		IRON,
		Enum.Material.Metal
	)
	local horn = propPart(
		folder,
		"Horn",
		Vector3.new(0.2 * L, 0.09 * L, 0.09 * L),
		base * CFrame.new(-0.36 * L, top - 0.07 * L, 0),
		IRON,
		Enum.Material.Metal
	)
	horn.Shape = Enum.PartType.Cylinder
	local piece = propPart(
		folder,
		"Piece",
		Vector3.new(0.26, 0.03, 0.05) * L,
		base * CFrame.new(0.04 * L, top + 0.015 * L, 0.02 * L),
		HOT,
		Enum.Material.Neon
	)
	local glow = Instance.new("PointLight")
	glow.Color = HOT
	glow.Range = 4
	glow.Brightness = 1.2
	glow.Parent = piece
	folder.Parent = npc
	table.insert(rig.props, folder)
	-- a hammer for a hand without one: welded to an R15 hand, carried by the model's hand bone
	local entry = NpcRigs.of(npcId)
	if not rig.r15 and not entry.hammer then
		return
	end
	local handle =
		propPart(npc, "NpcHammer", Vector3.new(0.05, 0.05, 0.5) * L, CFrame.identity, WOOD, Enum.Material.Wood)
	local head = propPart(handle, "Head", Vector3.new(0.09, 0.09, 0.2) * L, CFrame.identity, IRON, Enum.Material.Metal)
	table.insert(rig.props, handle)
	-- the handle across the fist (pinky to index), the head on the thumb's side
	local handFrame: CFrame
	if rig.r15 then
		local wrist = nil :: RigJoints.Joint?
		for _, j in rig.joints do
			if j.key == "RightHand" then
				wrist = j.joint
			end
		end
		if not wrist then
			return
		end
		local hand = wrist.part1
		handFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y * 0.3, 0)
		handle.CFrame = handFrame * CFrame.new(0, 0, -0.12 * L)
		head.CFrame = handle.CFrame * CFrame.new(0, 0, -0.25 * L) * CFrame.Angles(0, math.rad(90), 0)
		for _, part in { handle, head } do
			part.Anchored = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = part
			weld.Parent = part
		end
	else
		local bone = rig.bones.RightHand
		if not bone then
			return
		end
		head.Anchored = false
		head.Massless = true
		head.CFrame = handle.CFrame * CFrame.new(0, 0, -0.25 * L) * CFrame.Angles(0, math.rad(90), 0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = head
		weld.Parent = head
		-- the grip in the bone's frame: from the fingers' first bones at rest
		local world = rig.root.CFrame * rig.space
		local function restAt(key: string): Vector3?
			for _, f in rig.fingers do
				if f.side == "R" and f.seg == 1 and f.finger == key then
					return world:PointToObjectSpace(f.bone.WorldPosition)
				end
			end
			return nil
		end
		local index, pinky = restAt("Index"), restAt("Pinky") or restAt("Ring")
		local handAt = world:PointToObjectSpace(bone.WorldPosition)
		local across = if index and pinky then (index - pinky).Unit else Vector3.zAxis * -1
		local grip = if index and pinky then (index + pinky) * 0.5 else handAt
		local boneRest = world:ToObjectSpace(bone.WorldCFrame)
		local localGrip = boneRest:PointToObjectSpace(grip:Lerp(handAt, 0.3))
		local localAcross = boneRest.Rotation:VectorToObjectSpace(across)
		rig.hammer = {
			part = handle :: BasePart,
			bone = bone,
			offset = CFrame.lookAt(localGrip, localGrip + localAcross) * CFrame.new(0, 0, -0.12 * L),
		}
	end
end

-- Writes one frame of the motion (Logic/NpcMotion.step) to the joints.
function NpcRig.apply(rig: Rig, posed: NpcMotion.Posed)
	local world, shift = posed.world, posed.shift
	if rig.r15 then
		for _, d in rig.joints do
			local w = world[d.key]
			if not w then
				continue
			end
			local pw = if d.parent then world[d.parent] or NpcPose.IDENTITY else NpcPose.IDENTITY
			local r = NpcPose.toLocal(d.rest, NpcPose.mul(NpcPose.transpose(pw), w))
			local o = if d.key == "Hips" then NpcPose.apply(NpcPose.transpose(d.rest), shift) else nil
			RigJoints.set(
				d.joint,
				CFrame.new(
					o and o[1] or 0,
					o and o[2] or 0,
					o and o[3] or 0,
					r[1],
					r[2],
					r[3],
					r[4],
					r[5],
					r[6],
					r[7],
					r[8],
					r[9]
				)
			)
		end
	else
		local posedT = BipedPose.transforms(rig.skel, world, shift)
		for key, entry in posedT do
			local bone = rig.bones[key]
			if bone then
				local r = entry.rot
				local o = entry.offset
				bone.Transform = if o
					then CFrame.new(o[1], o[2], o[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
					else CFrame.new(0, 0, 0, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			end
		end
		NpcRig.hands(rig, posed.hands)
		local follow = rig.follow
		if follow then
			local at = v3(posed.offset)
			if (at - follow.at).Magnitude > FOLLOW_EPS then
				follow.at = at
				RigJoints.set(follow.joint, CFrame.new(follow.rest:VectorToObjectSpace(at)))
			end
		end
		local hammer = rig.hammer
		if hammer then
			hammer.part.CFrame = hammer.bone.TransformedWorldCFrame * hammer.offset
		end
	end
end

-- The fingers' curl for the hands' shapes (only when one changed).
function NpcRig.hands(rig: Rig, hands: { [string]: NpcMotion.Hand })
	if #rig.fingers == 0 then
		return
	end
	local last = rig.grip
	local changed = false
	for side, hand in hands do
		local g, i = "g" .. side, "i" .. side
		if math.abs((last[g] or -1) - hand.grip) > GRIP_EPS or math.abs((last[i] or -1) - hand.index) > GRIP_EPS then
			last[g], last[i] = hand.grip, hand.index
			changed = true
		end
	end
	if not changed then
		return
	end
	for _, f in rig.fingers do
		local grip = last["g" .. f.side] or 0
		local angle: number
		if f.finger == "Thumb" then
			angle = THUMB_CURL[f.seg] * grip
		else
			angle = CURL[f.seg] * grip * FINGER_SHARE[f.finger]
			if f.finger == "Index" then
				angle *= 1 - (last["i" .. f.side] or 0)
			end
		end
		f.bone.Transform = CFrame.fromAxisAngle(f.axis, angle)
	end
end

-- Back to the export's own pose; the props go.
function NpcRig.clear(rig: Rig)
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
	for _, f in rig.fingers do
		f.bone.Transform = CFrame.identity
	end
	for _, d in rig.joints do
		RigJoints.set(d.joint, CFrame.identity)
	end
	local follow = rig.follow
	if follow then
		RigJoints.set(follow.joint, CFrame.identity)
	end
	for _, prop in rig.props do
		prop:Destroy()
	end
	table.clear(rig.props)
	rig.hammer = nil
	table.clear(rig.grip)
end

-- The root-space (ground origin) point of a world position for the motion's inputs.
function NpcRig.toSpace(rig: Rig, position: Vector3): Vector3
	return (rig.root.CFrame * rig.space):PointToObjectSpace(position)
end

return NpcRig
