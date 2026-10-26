--!strict
-- Template animation (docs/ANIM-WZORCE.md F3): the bones of an imported flyer (Tripo, Data/FlyerRigs role map of its
-- model) driven by Logic/FlyerMotion. Rest frames are read once with every Transform at identity, in the space of the
-- look's HumanoidRootPart (front -Z, the ground at its origin). The rig has the shape of client/Anim/QuadRig's (`motion`,
-- `bones`, `mod`, `kind`), so AnimationController and AnimLab drive either.
-- * A Transform is written only when it moved by more than about 0.1 degree (docs/ANIM-WZORCE §1.10);
-- * the monster root's `Muzzle` attachment follows the beak / the wing tips (FlyerRigs `muzzle`), so the shots drawn
--   on this client leave from there (docs/ANIM-WZORCE §10).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FlyerMotion = require(ReplicatedStorage.Shared.Logic.FlyerMotion)
local FlyerPose = require(ReplicatedStorage.Shared.Logic.FlyerPose)
local FlyerRigs = require(ReplicatedStorage.Shared.Data.FlyerRigs)

local FlyerRig = {}

export type Rig = {
	kind: "flyer",
	skel: FlyerPose.Skeleton,
	motion: FlyerMotion.Instance,
	bones: { [string]: Bone },
	mod: any,
	root: BasePart,
	muzzle: Attachment?,
	last: { [string]: { number } }, -- the last written rotation (9) and offset (3) of each bone
}

local EPS = 0.0017 -- about 0.1 degree
local EPS_MOVE = 0.002 -- studs

local function toMat(cf: CFrame): { number }
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- The rig of `look` (the cloned model of Assets.Monsters `model`) in `styleId` (Data/FlyerStyles), nil without a role
-- map or its bones.
function FlyerRig.new(look: Model, styleId: string, seed: number, model: string): Rig?
	local map = FlyerRigs.get(model)
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
	local data: { [string]: FlyerPose.Bone } = {}
	for name, bone in byName do
		local rel = space:ToObjectSpace(bone.WorldCFrame)
		local parent = bone.Parent
		data[name] = {
			rest = toMat(rel),
			pos = { rel.X, rel.Y, rel.Z },
			parent = if parent and parent:IsA("Bone") then parent.Name else nil,
		}
	end
	local skel = FlyerPose.skeleton(data, map)
	if not skel then
		return nil
	end
	local motion = FlyerMotion.new(skel, styleId, seed)
	if not motion then
		return nil
	end
	-- the monster's own root (the look hangs under the monster model)
	local owner = look.Parent
	local ownerRoot = owner and owner:FindFirstChild("HumanoidRootPart")
	local muzzle = ownerRoot and ownerRoot:FindFirstChild("Muzzle")
	local last: { [string]: { number } } = {}
	for name in skel.posed do
		last[name] = { 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0 }
	end
	return {
		kind = "flyer",
		skel = skel,
		motion = motion,
		bones = byName,
		mod = FlyerMotion,
		root = root :: BasePart,
		muzzle = if muzzle and muzzle:IsA("Attachment") then muzzle else nil,
		last = last,
	}
end

-- Writes the Transforms of one frame that moved, and puts the muzzle where the shots leave.
function FlyerRig.apply(rig: Rig, posed: FlyerPose.Posed)
	for name, entry in posed do
		local bone = rig.bones[name]
		local last = rig.last[name]
		if bone and last then
			local r = entry.rot
			local o = entry.offset
			local ox, oy, oz = 0, 0, 0
			if o then
				ox, oy, oz = o[1], o[2], o[3]
			end
			local moved = math.abs(ox - last[10]) > EPS_MOVE
				or math.abs(oy - last[11]) > EPS_MOVE
				or math.abs(oz - last[12]) > EPS_MOVE
			if not moved then
				for i = 1, 9 do
					if math.abs(r[i] - last[i]) > EPS then
						moved = true
						break
					end
				end
			end
			if moved then
				for i = 1, 9 do
					last[i] = r[i]
				end
				last[10], last[11], last[12] = ox, oy, oz
				bone.Transform = CFrame.new(ox, oy, oz, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			end
		end
	end
	local muzzle = rig.muzzle
	local at = FlyerMotion.muzzle(rig.motion)
	if muzzle and at and muzzle.Parent then
		muzzle.WorldPosition = rig.root.CFrame:PointToWorldSpace(Vector3.new(at[1], at[2], at[3]))
	end
end

-- Back to the export's own pose.
function FlyerRig.clear(rig: Rig)
	for name, bone in rig.bones do
		bone.Transform = CFrame.identity
		local last = rig.last[name]
		if last then
			last[1], last[2], last[3], last[4], last[5], last[6], last[7], last[8], last[9] = 1, 0, 0, 0, 1, 0, 0, 0, 1
			last[10], last[11], last[12] = 0, 0, 0
		end
	end
end

return FlyerRig
