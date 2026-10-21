--!strict
-- W30: the bones of an owner's NPC model (Tripo Auto Rig Biped: Mixamo names with or without "mixamorig:", no clips)
-- posed procedurally (Logic/NpcPose): out of the T-pose into a relaxed stance on load, then breathing, weight shift,
-- looks, talk gestures and the smith's hammering written as Bone.Transform on this client (Anim/BoneOverlay's
-- convention: a turn in the NPC's root axes taken into the bone's own frame). Rest frames are read once with every
-- Transform at identity, in the space of the NPC's HumanoidRootPart (the model is welded to it, front -Z).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NpcPose = require(ReplicatedStorage.Shared.Logic.NpcPose)

local NpcRig = {}

type Driven = { bone: Bone, key: string, rest: NpcPose.Mat }
export type Rig = {
	bones: { Driven },
	arms: { [string]: NpcPose.ArmPose }, -- "RightArm" / "LeftArm"
	seed: number,
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
			table.insert(bones, { bone = bone, key = key, rest = toMat(space:ToObjectSpace(bone.WorldCFrame)) })
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
	return { bones = bones, arms = arms, seed = seed }
end

-- Writes one frame of motion (NpcPose.frame) to the bones.
function NpcRig.apply(rig: Rig, frame: NpcPose.Frame)
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
			d.bone.Transform = CFrame.identity
			continue
		end
		d.bone.Transform = toCFrame(NpcPose.toLocal(d.rest, turn))
	end
end

-- Back to the export's own pose (the rig is dropped).
function NpcRig.clear(rig: Rig)
	for _, d in rig.bones do
		d.bone.Transform = CFrame.identity
	end
end

return NpcRig
