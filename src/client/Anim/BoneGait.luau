--!strict
-- W26: walks the bones of an imported rig without clips (rig "static" with bones: Tripo animals, dragons, birds) from
-- Logic/Gait's motion: Logic/BoneRoles finds legs, knees, wings, tails, the head and the spine in the rest skeleton
-- and gives each an angle; this writes Bone.Transform as a turn about the model's side, forward or up axis taken into
-- the bone's own frame. The whole body (bob, lean, death) stays on the Gait_Body motor.
-- S159g: an attack style, its follow-through and a roar (Data/MonsterMotions: a boss gesture of Vaelgrath) also bend
-- the head, the wings, the front and hind legs and the tail by the style's offsets of the matching Gait role (head,
-- flap, leg, tail; Logic/Gait.overlay); a role the style lists drops the generic attack swing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoneRoles = require(ReplicatedStorage.Shared.Logic.BoneRoles)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local MonsterMotions = require(ReplicatedStorage.Shared.Data.MonsterMotions)

local BoneGait = {}

type Joint = { bone: Bone, role: BoneRoles.Role, axis: Vector3, gait: Gait.Joint? }
export type Rig = { joints: { Joint } }

-- S159g: the Gait role whose style offset a bone role takes, and which component of it (its turn axis above).
local GAIT_ROLE: { [string]: string } = { head = "head", wing = "flap", leg = "leg", tail = "tail" }
local COMPONENT: { [string]: string } = { head = "rx", wing = "rz", leg = "rx", tail = "ry" }

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
		local gaitRole = GAIT_ROLE[r.role]
		local gait: Gait.Joint? = if gaitRole
			then { role = gaitRole :: any, side = r.side, phase = r.phase, amp = 1, front = r.front }
			else nil
		table.insert(joints, { bone = bone, role = r, axis = rest:VectorToObjectSpace(AXIS[r.role]), gait = gait })
	end
	return { joints = joints }
end

-- Whether `style` poses the Gait role of `j` (its windup, strike or follow-through lists it; hind legs by hindWindup).
local function owned(style: MonsterMotions.Style?, j: Joint): boolean
	local gait = j.gait
	if not style or not gait then
		return false
	end
	if gait.role == "leg" and (gait.front or 0) < 0 then
		return style.hindWindup ~= nil or style.hindStrike ~= nil
	end
	local role = gait.role
	return style.windup[role] ~= nil or style.strike[role] ~= nil or (style.follow ~= nil and style.follow[role] ~= nil)
end

function BoneGait.step(rig: Rig, m: Gait.Motion)
	local alive = 1 - m.dead
	local style = if m.style then MonsterMotions.STYLES[m.style] else nil
	local acting = style ~= nil or (m.roar or 0) > 0
	for _, j in rig.joints do
		local mine = owned(style, j)
		local raise = if mine then 0 else m.raise
		local strike = if mine then 0 else m.strike
		local angle = BoneRoles.angle(j.role, m.cycle, m.move, m.time, raise, strike, m.hit, m.flying or 0)
		local gait = j.gait
		if acting and gait then
			local p = Gait.overlay(gait, m) :: any
			angle += p[COMPONENT[j.role.role]] or 0
		end
		j.bone.Transform = CFrame.fromAxisAngle(j.axis, angle * alive)
	end
end

return BoneGait
