--!strict
-- Template animation (owner 2026-10-25): the bones of an imported biped monster (Mixamo names, Data/MonsterAssets
-- `motion`) driven by Logic/BipedMotion instead of the baked clips. Rest frames are read once with every Transform at
-- identity, in the space of the look's HumanoidRootPart (front -Z, feet at its origin), so the motion fits the model's
-- own proportions and scale.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BipedMotion = require(ReplicatedStorage.Shared.Logic.BipedMotion)
local BipedPose = require(ReplicatedStorage.Shared.Logic.BipedPose)

local BipedRig = {}

export type Rig = {
	kind: "biped",
	skel: BipedPose.Skeleton,
	motion: BipedMotion.Instance,
	bones: { [string]: Bone },
	mod: any, -- Logic/BipedMotion (the game calls its pick, death, side, length, step through the rig)
}

local function toMat(cf: CFrame): { number }
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- The rig of `look` (the cloned model) in `styleId` (Data/BipedStyles), nil without the bones a biped needs.
function BipedRig.new(look: Model, styleId: string, seed: number, grip: { number }?): Rig?
	local root = look:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		root = look.PrimaryPart
	end
	if not root then
		return nil
	end
	local byKey: { [string]: Bone } = {}
	for _, item in look:GetDescendants() do
		if item:IsA("Bone") then
			local key = string.match(item.Name, "[^:]*$") or item.Name
			if not byKey[key] then
				byKey[key] = item
				item.Transform = CFrame.identity
			end
		end
	end
	local space = (root :: BasePart).CFrame
	local data: { [string]: BipedPose.Bone } = {}
	for key, bone in byKey do
		local rel = space:ToObjectSpace(bone.WorldCFrame)
		data[key] = { rest = toMat(rel), pos = { rel.X, rel.Y, rel.Z } }
	end
	local skel = BipedPose.skeleton(data)
	if not skel then
		return nil
	end
	local motion = BipedMotion.new(skel, styleId, seed, grip)
	if not motion then
		return nil
	end
	return { kind = "biped", skel = skel, motion = motion, bones = byKey, mod = BipedMotion }
end

-- Writes the Transforms of one frame (Logic/BipedMotion.step).
function BipedRig.apply(rig: Rig, posed: BipedPose.Posed)
	for key, entry in posed do
		local bone = rig.bones[key]
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

-- Back to the export's own pose.
function BipedRig.clear(rig: Rig)
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
end

return BipedRig
