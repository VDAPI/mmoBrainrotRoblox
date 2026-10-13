--!strict
-- Rider pose on a mount (S96): the legs astride the saddle (Data/Mounts.RIDER, degrees like Data/SkillMotions)
-- and a small lift of the whole body twice per walk cycle of the mount while it moves. Pure; the format is
-- AttackPose.Pose (AnimationController writes it to the character's joints).

local AttackMotions = require("../Data/AttackMotions")
local MountData = require("../Data/Mounts")

local RiderPose = {}

-- Joints the rider pose owns (the arms and the waist stay with the default animation and the basic attack).
RiderPose.JOINTS = table.freeze({ "rHip", "lHip", "rKnee", "lKnee", "root" })

local function copy(a: { number }): { number }
	return { a[1] or 0, a[2] or 0, a[3] or 0 }
end

-- cycle = the mount's walk cycle (radians, Logic/Gait), move = 0..1 how much it walks.
function RiderPose.sample(cycle: number, move: number): AttackMotions.Pose
	local rider = MountData.RIDER
	local lift = rider.bob * math.clamp(move, 0, 1) * math.sin(2 * cycle)
	local pose: AttackMotions.Pose = {
		rHip = copy(rider.rHip),
		lHip = copy(rider.lHip),
		rKnee = { rider.rKnee[1] or 0 },
		lKnee = { rider.lKnee[1] or 0 },
		root = { 0, 0, 0, lift },
	}
	return pose
end

return RiderPose
