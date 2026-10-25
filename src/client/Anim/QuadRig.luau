--!strict
-- Template animation (docs/ANIM-WZORCE.md F2): the bones of an imported quadruped (Tripo, Data/QuadRigs role map of
-- its model) driven by Logic/QuadMotion. Rest frames are read once with every Transform at identity, in the space of
-- the look's HumanoidRootPart (front -Z, feet at its origin). The rig has the shape of client/Anim/BipedRig's (`motion`,
-- `bones`, `mod`, `kind`), so AnimationController and AnimLab drive either.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuadMotion = require(ReplicatedStorage.Shared.Logic.QuadMotion)
local QuadPose = require(ReplicatedStorage.Shared.Logic.QuadPose)
local QuadRigs = require(ReplicatedStorage.Shared.Data.QuadRigs)

local QuadRig = {}

export type Rig = {
	kind: "quad",
	skel: QuadPose.Skeleton,
	motion: QuadMotion.Instance,
	bones: { [string]: Bone },
	mod: any,
}

local function toMat(cf: CFrame): { number }
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- The rig of `look` (the cloned model of Assets.Monsters `model`) in `styleId` (Data/QuadStyles), nil without a role map
-- or its bones.
function QuadRig.new(look: Model, styleId: string, seed: number, model: string): Rig?
	local map = QuadRigs.get(model)
	if not map then
		return nil
	end
	local root = look:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		root = look.PrimaryPart
	end
	if not root then
		return nil
	end
	local byName: { [string]: Bone } = {}
	for _, item in look:GetDescendants() do
		if item:IsA("Bone") and not byName[item.Name] then
			byName[item.Name] = item
			item.Transform = CFrame.identity
		end
	end
	local space = (root :: BasePart).CFrame
	local data: { [string]: QuadPose.Bone } = {}
	for name, bone in byName do
		local rel = space:ToObjectSpace(bone.WorldCFrame)
		local parent = bone.Parent
		data[name] = {
			rest = toMat(rel),
			pos = { rel.X, rel.Y, rel.Z },
			parent = if parent and parent:IsA("Bone") then parent.Name else nil,
		}
	end
	local skel = QuadPose.skeleton(data, map)
	if not skel then
		return nil
	end
	local motion = QuadMotion.new(skel, styleId, seed)
	if not motion then
		return nil
	end
	return { kind = "quad", skel = skel, motion = motion, bones = byName, mod = QuadMotion }
end

-- Writes the Transforms of one frame.
function QuadRig.apply(rig: Rig, posed: QuadPose.Posed)
	for name, entry in posed do
		local bone = rig.bones[name]
		if bone then
			local r = entry.rot
			local cf = CFrame.new(0, 0, 0, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			local o = entry.offset
			if o then
				cf = CFrame.new(o[1], o[2], o[3]) * cf
			end
			bone.Transform = cf
		end
	end
end

function QuadRig.clear(rig: Rig)
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
end

return QuadRig
