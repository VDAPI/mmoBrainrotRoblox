--!strict
-- W31 (Studio check, owner 2026-10-21: the dressed NPCs without a model still stood like statues): the joints of a
-- body, whichever kind holds them. A body built from a HumanoidDescription (Util/AvatarBuild, the avatar joint
-- upgrade) has AnimationConstraints, an older rig Motor6Ds; both turn their Part1 by Transform:
--   Motor6D:             Part1 = Part0 * C0 * Transform * C1^-1
--   AnimationConstraint: Part1 = Part0 * Attachment0.CFrame * Transform * Attachment1.CFrame^-1
-- so a joint is its two parts and the two frames. No Roblox globals (tests/npcrig.spec runs it under Lune).

local RigJoints = {}

export type Joint = {
	name: string,
	instance: Instance, -- the Motor6D or the AnimationConstraint (both take Transform)
	part0: BasePart,
	part1: BasePart,
	c0: CFrame,
	c1: CFrame,
}

-- The joint `item` stands for, nil for anything else (or a joint missing a part).
function RigJoints.of(item: Instance): Joint?
	if item:IsA("Motor6D") then
		local motor = item :: Motor6D
		local p0, p1 = motor.Part0, motor.Part1
		if p0 and p1 then
			local joint: Joint =
				{ name = motor.Name, instance = item, part0 = p0, part1 = p1, c0 = motor.C0, c1 = motor.C1 }
			return joint
		end
	elseif item:IsA("AnimationConstraint") then
		local constraint = item :: AnimationConstraint
		local a0, a1 = constraint.Attachment0, constraint.Attachment1
		local p0 = if a0 then a0.Parent else nil
		local p1 = if a1 then a1.Parent else nil
		if a0 and a1 and p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
			local joint: Joint = {
				name = constraint.Name,
				instance = item,
				part0 = p0 :: BasePart,
				part1 = p1 :: BasePart,
				c0 = a0.CFrame,
				c1 = a1.CFrame,
			}
			return joint
		end
	end
	return nil
end

-- Every joint of `model`.
function RigJoints.collect(model: Instance): { Joint }
	local out: { Joint } = {}
	for _, item in model:GetDescendants() do
		local joint = RigJoints.of(item)
		if joint then
			table.insert(out, joint)
		end
	end
	return out
end

-- Writes the joint's Transform.
function RigJoints.set(joint: Joint, transform: CFrame)
	(joint.instance :: any).Transform = transform
end

-- Every part's rest frame in the space of `root` (Transform at identity), from the root outwards; `identity` is
-- CFrame.identity (passed in: no globals here).
function RigJoints.rests(root: BasePart, joints: { Joint }, identity: CFrame): { [BasePart]: CFrame }
	local rest: { [BasePart]: CFrame } = { [root] = identity }
	local moved = true
	while moved do
		moved = false
		for _, joint in joints do
			if rest[joint.part0] and not rest[joint.part1] then
				rest[joint.part1] = rest[joint.part0] * joint.c0 * joint.c1:Inverse()
				moved = true
			end
		end
	end
	return rest
end

-- Every AnimationConstraint joint of `model` becomes the Motor6D it stands for (the same name, parts and frames, in
-- the same parent): a Motor6D is a rigid joint, so the limbs are one body with an anchored root and a client's
-- Transform moves them. `make` is Instance.new. The number of joints changed.
function RigJoints.motorize(model: Instance, make: (className: string) -> Instance): number
	local changed = 0
	for _, item in model:GetDescendants() do
		if item:IsA("AnimationConstraint") then
			local joint = RigJoints.of(item)
			if joint then
				local motor = make("Motor6D") :: Motor6D
				motor.Name = joint.name
				motor.Part0 = joint.part0
				motor.Part1 = joint.part1
				motor.C0 = joint.c0
				motor.C1 = joint.c1
				motor.Parent = item.Parent
				item:Destroy()
				changed += 1
			end
		end
	end
	return changed
end

return RigJoints
