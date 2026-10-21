--!strict
-- W30: the bones of an owner's NPC model (Tripo Auto Rig Biped: Mixamo names with or without "mixamorig:", no clips)
-- posed procedurally (Logic/NpcPose): out of the T-pose into a relaxed stance on load, then breathing, weight shift,
-- looks, talk gestures and the smith's hammering written as Bone.Transform on this client (Anim/BoneOverlay's
-- convention: a turn in the NPC's root axes taken into the bone's own frame). Rest frames are read once with every
-- Transform at identity, in the space of the NPC's HumanoidRootPart (the model is welded to it, front -Z).
-- W31 (owner 2026-10-21: the NPCs without a model stood frozen): an R15 figure (NpcService: its root anchored, the limbs
-- on their Motor6Ds) moves the same way through Motor6D.Transform (Logic/NpcPose.R15_JOINTS, the bones' offsets folded
-- onto its fewer joints by NpcPose.fold); its rest frames come from the joints' C0 / C1 from the root outwards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcPose = require(ReplicatedStorage.Shared.Logic.NpcPose)

local NpcRig = {}

-- One driven joint: a bone or a Motor6D (`set` writes its Transform), its key (NpcPose.KEYS) and rest rotation.
type Driven = { set: (CFrame) -> (), key: string, rest: NpcPose.Mat }
export type Rig = {
	bones: { Driven },
	arms: { [string]: NpcPose.ArmPose }, -- "RightArm" / "LeftArm"
	seed: number,
	r15: boolean, -- W31: Motor6Ds of an R15 figure (the frame is folded onto its joints)
}

local function toMat(cf: CFrame): NpcPose.Mat
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

local function toCFrame(m: NpcPose.Mat): CFrame
	return CFrame.new(0, 0, 0, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
end

local function vec(v: Vector3): NpcPose.Vec
	return { v.X, v.Y, v.Z }
end

-- A rig for the NPC `npc` whose owner's model is `asset` (NpcService: child "Asset"), nil without Mixamo arm bones.
function NpcRig.new(npc: Model, asset: Model, seed: number): Rig?
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local byKey: { [string]: Bone } = {}
	for _, item in asset:GetDescendants() do
		if item:IsA("Bone") then
			local key = NpcPose.boneKey(item.Name)
			if key and not byKey[key] then
				byKey[key] = item
				item.Transform = CFrame.identity
			end
		end
	end
	if not byKey.RightArm or not byKey.LeftArm then
		return nil
	end
	local space = root.CFrame
	local bones: { Driven } = {}
	for _, key in NpcPose.KEYS do
		local bone = byKey[key]
		if bone then
			table.insert(bones, {
				set = function(cf: CFrame)
					bone.Transform = cf
				end,
				key = key,
				rest = toMat(space:ToObjectSpace(bone.WorldCFrame)),
			})
		end
	end
	local function at(key: string): Vector3?
		local bone = byKey[key]
		return if bone then space:PointToObjectSpace(bone.WorldPosition) else nil
	end
	local spread = NpcPose.spread(asset:GetAttribute("ArmSpread"))
	local arms: { [string]: NpcPose.ArmPose } = {}
	for _, side in { 1, -1 } do
		local prefix = if side == 1 then "Right" else "Left"
		local shoulder, elbow, wrist = at(prefix .. "Arm"), at(prefix .. "ForeArm"), at(prefix .. "Hand")
		if shoulder and elbow then
			local foreDir = if wrist then vec(wrist - elbow) else nil
			arms[prefix .. "Arm"] = NpcPose.armPose(side, vec(elbow - shoulder), foreDir, spread)
		end
	end
	return { bones = bones, arms = arms, seed = seed, r15 = false }
end

-- W31: a rig for an R15 figure without the owner's model, nil without its arm joints. Every part's rest frame in the
-- root's space from the joints (Part1 = Part0 * C0 * C1^-1 with Transform at identity), from the root outwards.
function NpcRig.newR15(npc: Model, seed: number): Rig?
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local motors: { Motor6D } = {}
	local byName: { [string]: Motor6D } = {}
	for _, item in npc:GetDescendants() do
		if item:IsA("Motor6D") and item.Part0 and item.Part1 then
			table.insert(motors, item)
			if NpcPose.R15_JOINTS[item.Name] and not byName[item.Name] then
				byName[item.Name] = item
			end
		end
	end
	if not byName.RightShoulder or not byName.LeftShoulder or not byName.Root then
		return nil
	end
	local rest: { [BasePart]: CFrame } = { [root] = CFrame.identity }
	local moved = true
	while moved do
		moved = false
		for _, motor in motors do
			local p0, p1 = motor.Part0 :: BasePart, motor.Part1 :: BasePart
			if rest[p0] and not rest[p1] then
				rest[p1] = rest[p0] * motor.C0 * motor.C1:Inverse()
				moved = true
			end
		end
	end
	-- the joint's frame in root space: where Transform turns Part1
	local function joint(name: string): CFrame?
		local motor = byName[name]
		local base = motor and rest[motor.Part0 :: BasePart]
		return if motor and base then base * motor.C0 else nil
	end
	local bones: { Driven } = {}
	for name, key in NpcPose.R15_JOINTS do
		local motor, frame = byName[name], joint(name)
		if motor and frame then
			motor.Transform = CFrame.identity
			table.insert(bones, {
				set = function(cf: CFrame)
					motor.Transform = cf
				end,
				key = key,
				rest = toMat(frame),
			})
		end
	end
	local arms: { [string]: NpcPose.ArmPose } = {}
	for _, side in { 1, -1 } do
		local prefix = if side == 1 then "Right" else "Left"
		local shoulder, elbow, wrist = joint(prefix .. "Shoulder"), joint(prefix .. "Elbow"), joint(prefix .. "Wrist")
		if shoulder and elbow then
			local foreDir = if wrist then vec(wrist.Position - elbow.Position) else nil
			arms[prefix .. "Arm"] = NpcPose.armPose(
				side,
				vec(elbow.Position - shoulder.Position),
				foreDir,
				NpcPose.R15_SPREAD,
				NpcPose.R15_ELBOW
			)
		end
	end
	return { bones = bones, arms = arms, seed = seed, r15 = true }
end

-- Writes one frame of motion (NpcPose.frame) to the bones (W31: or the R15 joints).
function NpcRig.apply(rig: Rig, motion: NpcPose.Frame)
	local frame = if rig.r15 then NpcPose.fold(motion) else motion
	for _, d in rig.bones do
		local key = d.key
		local offset = frame[key]
		local turn: NpcPose.Mat
		if key == "RightArm" or key == "LeftArm" then
			local pose = rig.arms[key]
			turn = if pose then NpcPose.armTurn(pose, offset) else NpcPose.euler(offset or { rx = 0, ry = 0, rz = 0 })
		elseif key == "RightForeArm" or key == "LeftForeArm" then
			local side = if key == "RightForeArm" then "Right" else "Left"
			local pose = rig.arms[side .. "Arm"]
			if not pose then
				continue
			end
			local bend = frame[if side == "Right" then "_bendR" else "_bendL"]
			turn = NpcPose.foreTurn(pose, if bend then bend.rx else nil)
		elseif offset then
			turn = NpcPose.euler(offset)
		else
			d.set(CFrame.identity)
			continue
		end
		d.set(toCFrame(NpcPose.toLocal(d.rest, turn)))
	end
end

-- Back to the export's own pose (the rig is dropped).
function NpcRig.clear(rig: Rig)
	for _, d in rig.bones do
		d.set(CFrame.identity)
	end
end

return NpcRig
