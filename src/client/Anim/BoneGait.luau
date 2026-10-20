--!strict
-- W26: walks the bones of an imported rig without clips (rig "static" with bones: Tripo animals, dragons, birds) from
-- Logic/Gait's motion: Logic/BoneRoles finds legs, knees, wings, tails, the head and the spine in the rest skeleton
-- and gives each an angle; this writes Bone.Transform as a turn about the model's side, forward or up axis taken into
-- the bone's own frame. The whole body (bob, lean, death) stays on the Gait_Body motor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoneRoles = require(ReplicatedStorage.Shared.Logic.BoneRoles)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)

local BoneGait = {}

type Joint = { bone: Bone, role: BoneRoles.Role, axis: Vector3 }
export type Rig = { joints: { Joint } }

local AXIS = {
	leg = Vector3.xAxis,
	knee = Vector3.xAxis,
	head = Vector3.xAxis,
	spine = Vector3.xAxis,
	wing = Vector3.zAxis,
	tail = Vector3.yAxis,
}

-- A rig for `model` (the cloned look, pivot at the feet, front -Z), or nil when no bone gets a role.
function BoneGait.new(model: Model): Rig?
	local list: { Bone } = {}
	local index: { [Bone]: number } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			table.insert(list, item)
			index[item] = #list
		end
	end
	if #list == 0 then
		return nil
	end
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local input: { BoneRoles.BoneIn } = {}
	local minZ, maxZ = math.huge, -math.huge
	for i, bone in list do
		local at = pivot:PointToObjectSpace(bone.WorldPosition)
		local parent = bone.Parent
		input[i] = {
			name = bone.Name,
			parent = if parent and parent:IsA("Bone") then index[parent] else nil,
			pos = { at.X, at.Y, at.Z },
		}
		minZ, maxZ = math.min(minZ, at.Z), math.max(maxZ, at.Z)
	end
	local roles = BoneRoles.classify(input, size.Y, size.X, (minZ + maxZ) / 2)
	if #roles == 0 then
		return nil
	end
	local joints: { Joint } = {}
	for _, r in roles do
		local bone = list[r.bone]
		local rest = pivot:ToObjectSpace(bone.WorldCFrame)
		table.insert(joints, { bone = bone, role = r, axis = rest:VectorToObjectSpace(AXIS[r.role]) })
	end
	return { joints = joints }
end

function BoneGait.step(rig: Rig, m: Gait.Motion)
	local alive = 1 - m.dead
	for _, j in rig.joints do
		local angle = BoneRoles.angle(j.role, m.cycle, m.move, m.time, m.raise, m.strike, m.hit, m.flying or 0)
		j.bone.Transform = CFrame.fromAxisAngle(j.axis, angle * alive)
	end
end

return BoneGait
