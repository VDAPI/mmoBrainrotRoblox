--!strict
-- W31 (Studio check, owner 2026-10-21: the dressed NPCs still stood like statues): Util/RigJoints reads the joints of
-- a body whichever kind holds them. A body from a HumanoidDescription has AnimationConstraints (the avatar joint
-- upgrade), an older rig Motor6Ds; NpcService turns the constraints into Motor6Ds (rigid with the anchored root) and
-- Anim/NpcRig poses either kind through Transform.

local roblox = require("@lune/roblox")

local NpcPose = require("../src/shared/Logic/NpcPose")
local RigJoints = require("../src/shared/Util/RigJoints")
local T = require("./Test")

local Instance = roblox.Instance
local CFrame = roblox.CFrame

-- An R15 body (HumanoidRootPart and the 15 joints): part, its parent part, the joint's name and frames.
local BODY: { { string } } = {
	{ "LowerTorso", "HumanoidRootPart", "Root" },
	{ "UpperTorso", "LowerTorso", "Waist" },
	{ "Head", "UpperTorso", "Neck" },
	{ "RightUpperArm", "UpperTorso", "RightShoulder" },
	{ "RightLowerArm", "RightUpperArm", "RightElbow" },
	{ "RightHand", "RightLowerArm", "RightWrist" },
	{ "LeftUpperArm", "UpperTorso", "LeftShoulder" },
	{ "LeftLowerArm", "LeftUpperArm", "LeftElbow" },
	{ "LeftHand", "LeftLowerArm", "LeftWrist" },
	{ "RightUpperLeg", "LowerTorso", "RightHip" },
	{ "RightLowerLeg", "RightUpperLeg", "RightKnee" },
	{ "RightFoot", "RightLowerLeg", "RightAnkle" },
	{ "LeftUpperLeg", "LowerTorso", "LeftHip" },
	{ "LeftLowerLeg", "LeftUpperLeg", "LeftKnee" },
	{ "LeftFoot", "LeftLowerLeg", "LeftAnkle" },
}

-- Joint frames: the child hangs 1 stud down (arms 1.5 to the side), turned a little so a wrong order shows.
local function frames(i: number): (any, any)
	local side = if i == 4 then 1.5 elseif i == 7 then -1.5 else 0
	local c0 = CFrame.new(side, -1, 0.1 * i) * CFrame.Angles(0.05 * i, 0.02 * i, 0)
	local c1 = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, -0.03 * i, 0.01 * i)
	return c0, c1
end

-- The body with AnimationConstraint joints (`constraints`) or Motor6Ds.
local function body(constraints: boolean): (any, { [string]: any })
	local model = Instance.new("Model")
	local parts: { [string]: any } = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = model
	parts.HumanoidRootPart = root
	for i, row in BODY do
		local part = Instance.new("Part")
		part.Name = row[1]
		part.Parent = model
		parts[row[1]] = part
		local c0, c1 = frames(i)
		local parent = parts[row[2]]
		if constraints then
			local a0 = Instance.new("Attachment")
			a0.Name = row[3] .. "RigAttachment"
			a0.CFrame = c0
			a0.Parent = parent
			local a1 = Instance.new("Attachment")
			a1.Name = row[3] .. "RigAttachment"
			a1.CFrame = c1
			a1.Parent = part
			local joint = Instance.new("AnimationConstraint")
			joint.Name = row[3]
			joint.Attachment0 = a0
			joint.Attachment1 = a1
			joint.Parent = part
		else
			local motor = Instance.new("Motor6D")
			motor.Name = row[3]
			motor.Part0 = parent
			motor.Part1 = part
			motor.C0 = c0
			motor.C1 = c1
			motor.Parent = part
		end
	end
	return model, parts
end

local function near(a: any, b: any): boolean
	local x = { a:GetComponents() }
	local y = { b:GetComponents() }
	for i = 1, 12 do
		if math.abs(x[i] - y[i]) > 1e-4 then
			return false
		end
	end
	return true
end

T.describe("Rig joints (W31)", function()
	T.it("reads the 15 AnimationConstraint joints of an avatar body with their parts and frames", function()
		local model, parts = body(true)
		local joints = RigJoints.collect(model)
		T.expect(#joints).toBe(15)
		local byName: { [string]: RigJoints.Joint } = {}
		for _, j in joints do
			byName[j.name] = j
		end
		for name in NpcPose.R15_JOINTS do
			T.expect(byName[name] ~= nil).toBe(true)
		end
		local shoulder = byName.RightShoulder
		T.expect(shoulder.part0 == parts.UpperTorso).toBe(true)
		T.expect(shoulder.part1 == parts.RightUpperArm).toBe(true)
		local c0, c1 = frames(4)
		T.expect(near(shoulder.c0, c0)).toBe(true)
		T.expect(near(shoulder.c1, c1)).toBe(true)
	end)

	T.it("finds the same rest frames as the Motor6D rig, from the root outwards", function()
		local a, ap = body(true)
		local b, bp = body(false)
		local restA = RigJoints.rests(ap.HumanoidRootPart, RigJoints.collect(a), CFrame.identity)
		local restB = RigJoints.rests(bp.HumanoidRootPart, RigJoints.collect(b), CFrame.identity)
		for _, row in BODY do
			T.expect(restA[ap[row[1]]] ~= nil).toBe(true)
			T.expect(near(restA[ap[row[1]]], restB[bp[row[1]]])).toBe(true)
		end
		-- the hand: the chain root -> lower torso -> upper torso -> arm -> forearm -> hand
		local expect = CFrame.identity
		for _, i in { 1, 2, 4, 5, 6 } do
			local c0, c1 = frames(i)
			expect = expect * c0 * c1:Inverse()
		end
		T.expect(near(restA[ap.RightHand], expect)).toBe(true)
	end)

	T.it("writes Transform to either kind of joint", function()
		for _, constraints in { true, false } do
			local model = body(constraints)
			local turn = CFrame.Angles(0.3, 0, 0)
			for _, j in RigJoints.collect(model) do
				RigJoints.set(j, turn)
				T.expect(near((j.instance :: any).Transform, turn)).toBe(true)
			end
		end
	end)

	T.it("turns an avatar body's constraints into Motor6Ds with the same parts and frames (NpcService)", function()
		local model, parts = body(true)
		local before = RigJoints.rests(parts.HumanoidRootPart, RigJoints.collect(model), CFrame.identity)
		T.expect(RigJoints.motorize(model, Instance.new)).toBe(15)
		local motors, constraints = 0, 0
		for _, item in model:GetDescendants() do
			if item:IsA("Motor6D") then
				motors += 1
			elseif item:IsA("AnimationConstraint") then
				constraints += 1
			end
		end
		T.expect(motors).toBe(15)
		T.expect(constraints).toBe(0)
		local joints = RigJoints.collect(model)
		local after = RigJoints.rests(parts.HumanoidRootPart, joints, CFrame.identity)
		for _, row in BODY do
			T.expect(near(before[parts[row[1]]], after[parts[row[1]]])).toBe(true)
		end
		-- the Motor6D sits in the limb, named as the joint
		local wrist = parts.RightHand:FindFirstChild("RightWrist")
		T.expect(wrist ~= nil and wrist:IsA("Motor6D")).toBe(true)
		T.expect(RigJoints.motorize(model, Instance.new)).toBe(0)
	end)
end)

return nil
