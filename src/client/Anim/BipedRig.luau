--!strict
-- Template animation (owner 2026-10-25): the bones of an imported biped monster (Mixamo names, Data/MonsterAssets
-- `motion`) driven by Logic/BipedMotion instead of the baked clips. Rest frames are read once with every Transform at
-- identity, in the space of the look's HumanoidRootPart (front -Z, feet at its origin), so the motion fits the model's
-- own proportions and scale.
-- * A model with a Data/BipedRigs map (2026-10-26: the regular wyvern, the specter, the ice elemental) takes its bones
--   from the map over the name rules: virtual points for missing or misplaced bones, the body turned about a pivot;
--   the root's `Muzzle` attachment then follows the map's jaw / casting hand (docs/ANIM-WZORCE §10);
-- * a style the spirits' motion drives (Logic/SpiritMotion: the specter, the ice elemental) also fades the look's
--   visible parts (the specter's flicker, the deaths).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BipedMotion = require(ReplicatedStorage.Shared.Logic.BipedMotion)
local BipedPose = require(ReplicatedStorage.Shared.Logic.BipedPose)
local BipedRigs = require(ReplicatedStorage.Shared.Data.BipedRigs)
local SpiritMotion = require(ReplicatedStorage.Shared.Logic.SpiritMotion)

local BipedRig = {}

export type Rig = {
	kind: "biped",
	skel: BipedPose.Skeleton,
	motion: any, -- Logic/BipedMotion.Instance, or Logic/SpiritMotion's (its `style` the same)
	bones: { [string]: Bone },
	mod: any, -- Logic/BipedMotion or SpiritMotion (the game calls its pick, death, side, length, step through the rig)
	muzzle: Attachment?, -- the monster root's Muzzle, moved onto `muzzleBone` each frame
	muzzleBone: Bone?,
	muzzleAt: Vector3?, -- the shots' point in the bone's own frame
	parts: { { part: BasePart, base: number } }?, -- the visible parts a spirit fades
	fade: number,
}

local FADE_EPS = 0.01

local function toMat(cf: CFrame): { number }
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return { r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

-- The rig of `look` (the cloned model of Assets.Monsters `model`) in `styleId` (Data/BipedStyles), nil without the
-- bones a biped needs.
function BipedRig.new(look: Model, styleId: string, seed: number, grip: { number }?, model: string?): Rig?
	local root = look:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		root = look.PrimaryPart
	end
	if not root then
		return nil
	end
	local space = (root :: BasePart).CFrame
	local byName: { [string]: Bone } = {}
	local names: { [string]: string } = {}
	local rest: { [string]: BipedPose.Bone } = {}
	for _, item in look:GetDescendants() do
		if item:IsA("Bone") then
			item.Transform = CFrame.identity
			if not byName[item.Name] then
				byName[item.Name] = item
				local cf = space:ToObjectSpace(item.WorldCFrame)
				rest[item.Name] = { rest = toMat(cf), pos = { cf.X, cf.Y, cf.Z } }
				local key = BipedRigs.keyOf(item.Name)
				if not names[key] then
					names[key] = item.Name
				end
			end
		end
	end
	local map = if model then BipedRigs.get(model) else nil
	local data, keyed, options, unit = BipedPose.collect(names, rest, map)
	local skel = BipedPose.skeleton(data, options)
	if not skel then
		return nil
	end
	local mod: any = if SpiritMotion.handles(styleId) then SpiritMotion else BipedMotion
	local motion = mod.new(skel, styleId, seed, grip)
	if not motion then
		return nil
	end
	local byKey: { [string]: Bone } = {}
	for key, name in keyed do
		byKey[key] = byName[name]
	end
	local rig: Rig = {
		kind = "biped",
		skel = skel,
		motion = motion,
		bones = byKey,
		mod = mod,
		fade = 0,
	}
	-- the shots leave the jaw / the casting hand: the monster's own root (the look hangs under the monster model)
	-- bones the map folds once (outside the pose: nothing else writes them)
	local tucks: { { bone: string, axis: { number }, angle: number } } = (map and map.tuck) or {}
	for _, t in tucks do
		local bone = byName[t.bone]
		if bone then
			local turn = CFrame.fromAxisAngle(Vector3.new(t.axis[1], t.axis[2], t.axis[3]).Unit, t.angle)
			local at = space:ToObjectSpace(bone.WorldCFrame).Rotation
			bone.Transform = at:Inverse() * turn * at
		end
	end
	local muzzleSpec = map and map.muzzle
	local muzzleBone = muzzleSpec and byKey[muzzleSpec.key]
	local owner = look.Parent
	local ownerRoot = owner and owner:FindFirstChild("HumanoidRootPart")
	local muzzle = ownerRoot and ownerRoot:FindFirstChild("Muzzle")
	if muzzleSpec and muzzleBone and muzzle and muzzle:IsA("Attachment") then
		local o = muzzleSpec.offset
		rig.muzzle = muzzle
		rig.muzzleBone = muzzleBone
		rig.muzzleAt = muzzleBone.WorldCFrame:VectorToObjectSpace(
			space:VectorToWorldSpace(Vector3.new(o[1] * unit, o[2] * unit, o[3] * unit))
		)
	end
	if mod == SpiritMotion then
		local parts = {}
		for _, item in look:GetDescendants() do
			if item:IsA("BasePart") and item.Transparency < 1 and item ~= root then
				table.insert(parts, { part = item, base = item.Transparency })
			end
		end
		rig.parts = parts
	end
	return rig
end

-- Writes the Transforms of one frame (Logic/BipedMotion.step), puts the muzzle where the shots leave and fades a
-- spirit.
function BipedRig.apply(rig: Rig, posed: BipedPose.Posed)
	for key, entry in posed do
		local bone = rig.bones[key]
		if bone then
			local r = entry.rot
			local o = entry.offset
			if o then
				bone.Transform = CFrame.new(o[1], o[2], o[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			else
				bone.Transform = CFrame.new(0, 0, 0, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9])
			end
		end
	end
	local muzzle, bone, at = rig.muzzle, rig.muzzleBone, rig.muzzleAt
	if muzzle and bone and at and muzzle.Parent then
		muzzle.WorldPosition = bone.TransformedWorldCFrame:PointToWorldSpace(at)
	end
	local parts = rig.parts
	if parts then
		local fade = SpiritMotion.fade(rig.motion)
		if math.abs(fade - rig.fade) > FADE_EPS then
			rig.fade = fade
			for _, p in parts do
				p.part.Transparency = p.base + (1 - p.base) * fade
			end
		end
	end
end

-- Back to the export's own pose (and look).
function BipedRig.clear(rig: Rig)
	for _, bone in rig.bones do
		bone.Transform = CFrame.identity
	end
	local parts = rig.parts
	if parts then
		rig.fade = 0
		for _, p in parts do
			p.part.Transparency = p.base
		end
	end
end

return BipedRig
