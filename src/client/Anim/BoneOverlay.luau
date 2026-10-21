--!strict
-- S159a (owner 2026-10-21, "animations of everything, the bosses' abilities too"): a procedural layer over the bone
-- clips of an imported humanoid model (rig "bones", Data/MonsterClips). The imported clips have one spell and two
-- weapon swings, so a boss pattern's gesture and a roar (Data/MonsterMotions styles, Logic/Gait.overlay) are posed
-- here instead: the Mixamo arm and head bones turn about the model's own axes (the same convention as a generated
-- rig's joints) on top of the clip that plays meanwhile (idle or walk: AnimationController holds the attack clip back
-- for a procedural gesture). The whole body (crouch, lean, turn, hop, lunge) moves on the look's Gait_Body motor
-- (MonsterViewController).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoneClips = require(script.Parent.BoneClips)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)

local BoneOverlay = {}

local PREFIX = "mixamorig:"

-- The Mixamo bones the layer turns: the Gait joint whose style offsets they take, and how much of them.
local MAP: { { name: string, joint: Gait.Joint, k: number } } = {
	{ name = "RightArm", joint = { role = "arm", side = 1, phase = 0, amp = 1, front = 0 }, k = 1 },
	{ name = "LeftArm", joint = { role = "arm", side = -1, phase = 0, amp = 1, front = 0 }, k = 1 },
	{ name = "Head", joint = { role = "head", side = 0, phase = 0, amp = 1, front = 0 }, k = 0.8 },
}

type Entry = { index: number, joint: Gait.Joint, k: number, rest: CFrame }
export type Rig = { bones: { Entry } }

-- A layer for `model` (the cloned look, pivot at the feet, front -Z) playing `mixer`, nil without the bones.
function BoneOverlay.new(model: Model, mixer: BoneClips.Mixer): Rig?
	local pivot = model:GetPivot()
	local bones: { Entry } = {}
	for _, entry in MAP do
		local index = table.find(mixer.clip.bones, entry.name)
		local bone = if index then mixer.bones[index] else nil
		if index and bone and bone.Name == PREFIX .. entry.name then
			-- the rest frame (the clips have not posed it yet); only its rotation matters
			bone.Transform = CFrame.identity
			local rest = pivot:ToObjectSpace(bone.WorldCFrame)
			table.insert(bones, { index = index, joint = entry.joint, k = entry.k, rest = rest.Rotation })
		end
	end
	return if #bones > 0 then { bones = bones } else nil
end

-- Lays the action of motion `m` (Gait.overlay) over the clips of `mixer`: a turn about the model's axes through each
-- bone's pivot, written before the clip's own pose (BoneClips.step).
function BoneOverlay.apply(rig: Rig, mixer: BoneClips.Mixer, m: Gait.Motion)
	local pre: { [number]: CFrame } = mixer.pre or {}
	for _, entry in rig.bones do
		local p = Gait.overlay(entry.joint, m)
		if p.rx == 0 and p.ry == 0 and p.rz == 0 then
			pre[entry.index] = nil
		else
			local k = entry.k
			local turn = CFrame.Angles(p.rx * k, p.ry * k, p.rz * k)
			pre[entry.index] = entry.rest:Inverse() * turn * entry.rest
		end
	end
	mixer.pre = pre
end

-- Drops the layer (the clips alone again).
function BoneOverlay.clear(mixer: BoneClips.Mixer)
	mixer.pre = nil
end

return BoneOverlay
