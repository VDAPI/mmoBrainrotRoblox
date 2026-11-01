--!strict
-- Template animation (docs/ANIM-WZORCE.md F2): the bones of an imported quadruped (Tripo, Data/QuadRigs role map of
-- its model) driven by Logic/QuadMotion. Rest frames are read once with every Transform at identity, in the space of
-- the look's HumanoidRootPart (front -Z, feet at its origin). The rig has the shape of client/Anim/BipedRig's (`motion`,
-- `bones`, `mod`, `kind`), so AnimationController and AnimLab drive either. A map with a `muzzle` (the dragon's mouth,
-- 2026-10-31) moves the monster root's `Muzzle` onto it every frame, so the shots and the breath leave the drawn jaws.

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
	root: BasePart, -- the look's root: the skeleton's space, whose place in the world pins the feet (`rootAt`)
	look: Model,
	muzzle: Attachment?, -- the monster root's Muzzle, moved onto `muzzleBone` each frame
	muzzleBone: Bone?,
	muzzleAt: Vector3?, -- the shots' point in the bone's own frame
	maxTurn: number?, -- the map's `maxTurn` (QuadRig.apply)
	applied: number?,
}

-- the standing pose a new rig shows before its first frame
local STILL: QuadMotion.Input = { now = 0, dt = 0, speed = 0, yawRate = 0, combat = false, snap = true }

local function toMat(cf: CFrame): { number }
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- The rig of `look` (the cloned model of Assets.Monsters `model`) in `styleId` (Data/QuadStyles), nil without a role map
-- or its bones.
function QuadRig.new(look: Model, styleId: string, seed: number, model: string): Rig?
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
		end
	end
	local map = QuadRigs.find(model, function(name: string): boolean
		local found: Bone? = byName[name]
		return found ~= nil
	end)
	if not map then
		return nil
	end
	for _, bone in byName do
		bone.Transform = CFrame.identity
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
	local rig: Rig =
		{ kind = "quad", skel = skel, motion = motion, bones = byName, mod = QuadMotion, root = root, look = look }
	rig.maxTurn = map.maxTurn
	-- the mouth: the point is kept without the monster's root too (AnimLab's look, Vfx/MotionFx's breath read it)
	local spec = map.muzzle
	local muzzleBone = spec and byName[spec.bone]
	if spec and muzzleBone then
		local owner = look.Parent
		local ownerRoot = owner and owner:FindFirstChild("HumanoidRootPart")
		local muzzle = ownerRoot and ownerRoot:FindFirstChild("Muzzle")
		local at, L = spec.at, skel.L
		rig.muzzle = if muzzle and muzzle:IsA("Attachment") then muzzle else nil
		rig.muzzleBone = muzzleBone
		rig.muzzleAt = muzzleBone.WorldCFrame:VectorToObjectSpace(
			space:VectorToWorldSpace(Vector3.new(at[1] * L, at[2] * L, at[3] * L))
		)
	end
	-- studio review 2026-10-31: the bones were just read at their bind pose (a dragon's wings spread); stand the rig
	-- at once so a new rig (AnimLab's loop, a refreshed look) never shows that frame. A throwaway instance keeps the
	-- live one's clocks.
	local still = QuadMotion.new(skel, styleId, seed)
	if still then
		QuadRig.apply(rig, QuadMotion.step(still, STILL))
	end
	return rig
end

-- The root's place on the ground for QuadMotion's `rootAt` ({x, z, yaw}): a style with pinned feet holds them where
-- they came down in the world by it, however the replicated root moves (in network steps, with no velocity).
function QuadRig.rootAt(rig: Rig): { number }?
	local root = rig.root
	if not root.Parent then
		return nil
	end
	local cf = root.CFrame
	local look = cf.LookVector
	return { cf.X, cf.Z, math.atan2(-look.X, -look.Z) }
end

-- Writes the Transforms of one frame.
function QuadRig.apply(rig: Rig, posed: QuadPose.Posed)
	-- (a map's `maxTurn`: near-straight legs of a model answer a foot's last bit with a jump; each bone eases toward its
	-- pose at most this many radians a 60th of a second)
	local now = os.clock()
	local limit = rig.maxTurn
	if limit then
		limit *= math.clamp((now - (rig.applied or now)) * 60, 1, 4)
		rig.applied = now
	end
	for name, entry in posed do
		local bone = rig.bones[name]
		if bone then
			local r = entry.rot
			local cf = CFrame.new(0, 0, 0, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			local o = entry.offset
			if o then
				cf = CFrame.new(o[1], o[2], o[3]) * cf
			end
			if limit then
				local _, turn = (bone.Transform:Inverse() * cf):ToAxisAngle()
				turn = math.abs(turn)
				if turn > limit then
					cf = bone.Transform:Lerp(cf, limit / turn)
				end
			end
			bone.Transform = cf
		end
	end
	local muzzle, bone, at = rig.muzzle, rig.muzzleBone, rig.muzzleAt
	if muzzle and bone and at and muzzle.Parent then
		muzzle.WorldPosition = bone.TransformedWorldCFrame:PointToWorldSpace(at)
	end
end

function QuadRig.clear(rig: Rig)
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
end

return QuadRig
