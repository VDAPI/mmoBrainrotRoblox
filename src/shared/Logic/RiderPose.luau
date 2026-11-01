--!strict
-- Rider pose on a mount (S96): the legs astride the saddle (Data/Mounts.RIDER, degrees like Data/SkillMotions)
-- and a small lift of the whole body twice per walk cycle of the mount while it moves. Pure; the format is
-- AttackPose.Pose (AnimationController writes it to the character's joints).
-- 2026-11-01 (real mount models): a mount's own fit over RIDER (`rider`: a broad lion spreads the thighs wider than a
-- horse) and, on a mount animated by the quadruped template, the saddle's own motion (Logic/QuadMotion.saddle: the body
-- rides its rise and leans with its pitch and roll).

local AttackMotions = require("../Data/AttackMotions")
local MountData = require("../Data/Mounts")

local RiderPose = {}

-- Joints the rider pose owns (the arms and the waist stay with the default animation and the basic attack).
RiderPose.JOINTS = table.freeze({ "rHip", "lHip", "rKnee", "lKnee", "root" })

-- A mount's own fit (docs/ASSETS.md "Wierzchowce": the field `rider` of its real model entry): any of RIDER's fields
-- but `stride`, the rest stay RIDER's. E.g. a lion: rHip { 70, 0, 30 }, lHip { 70, 0, -30 } (the thighs spread 8
-- degrees wider), seatLift a little higher; bob 0 when the saddle's own motion carries the rider.
export type Over = {
	rHip: { number }?,
	lHip: { number }?,
	rKnee: { number }?,
	lKnee: { number }?,
	bob: number?,
	seatLift: number?,
}

local function copy(a: { number }): { number }
	return { a[1] or 0, a[2] or 0, a[3] or 0 }
end

-- RIDER with a mount's fit laid over it (RIDER itself without one).
function RiderPose.rider(over: Over?): MountData.Rider
	local base = MountData.RIDER
	if not over then
		return base
	end
	return table.freeze({
		rHip = over.rHip or base.rHip,
		lHip = over.lHip or base.lHip,
		rKnee = over.rKnee or base.rKnee,
		lKnee = over.lKnee or base.lKnee,
		bob = over.bob or base.bob,
		seatLift = over.seatLift or base.seatLift,
		stride = base.stride,
	}) :: MountData.Rider
end

-- cycle = the mount's walk cycle (radians, Logic/Gait), move = 0..1 how much it walks; `rider`: the fit
-- (RiderPose.rider, default RIDER); `saddle` (a mount on the quadruped template): { rise in studs, pitch in rad (+ nose
-- up), roll in rad (+ right side up) } of the saddle under the rider (Logic/QuadMotion.saddle).
function RiderPose.sample(cycle: number, move: number, rider: MountData.Rider?, saddle: { number }?): AttackMotions.Pose
	local fit = rider or MountData.RIDER
	local lift = fit.bob * math.clamp(move, 0, 1) * math.sin(2 * cycle)
	local pitch, roll = 0, 0
	if saddle then
		lift += saddle[1] or 0
		-- the root's degrees: + leans back (the saddle's nose up), + roll the right side up (Data/SkillMotions)
		pitch, roll = math.deg(saddle[2] or 0), math.deg(saddle[3] or 0)
	end
	local pose: AttackMotions.Pose = {
		rHip = copy(fit.rHip),
		lHip = copy(fit.lHip),
		rKnee = { fit.rKnee[1] or 0 },
		lKnee = { fit.lKnee[1] or 0 },
		root = { pitch, 0, roll, lift },
	}
	return pose
end

return RiderPose
