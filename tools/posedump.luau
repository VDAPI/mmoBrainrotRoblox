--!strict
-- Skill animation preview without Studio (S28): an R15 dummy posed by Logic/SkillPose with the same joint transforms as
-- AnimationController, dumped as world-space pieces for docs/miasto/tools/render3d.py.
--   lune run tools/posedump.luau out.json <skillId|class:Warrior> [frames]
-- Every skill is two rows (along X: the frames over the motion's length; the front row faces -Z towards a camera in
-- front, the row behind shows the same frames from the right side); skills go back along +Z (16 studs each). R15 sizes and rig attachments are the default avatar's (read from Studio).

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local SkillData = require("../src/shared/Data/Skills")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local SkillPose = require("../src/shared/Logic/SkillPose")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

type Part = { size: { number }, color: string, att: { [string]: { number } } }

local PARTS: { [string]: Part } = {
	HumanoidRootPart = { size = { 2, 2, 1 }, color = "", att = { Root = { 0, -1, 0 } } },
	LowerTorso = {
		size = { 1.991, 0.401, 1.004 },
		color = "#968C64",
		att = { Root = { 0, -0.2, 0 }, Waist = { 0, 0.2, 0 }, LeftHip = { -0.5, -0.2, 0 }, RightHip = { 0.5, -0.2, 0 } },
	},
	UpperTorso = {
		size = { 1.943, 1.698, 1.004 },
		color = "#E6DCAA",
		att = {
			Waist = { 0, -0.849, 0 },
			Neck = { 0, 0.849, 0 },
			LeftShoulder = { -0.972, 0.598, 0 },
			RightShoulder = { 0.972, 0.598, 0 },
		},
	},
	Head = { size = { 1.159, 1.182, 1.161 }, color = "#F0D2AA", att = { Neck = { 0, -0.576, 0 } } },
	RightUpperArm = {
		size = { 1.001, 1.242, 1.002 },
		color = "#DC3C3C",
		att = { RightShoulder = { -0.501, 0.419, 0 }, RightElbow = { 0, -0.355, 0 } },
	},
	RightLowerArm = {
		size = { 1.001, 1.118, 1.002 },
		color = "#FF8C8C",
		att = { RightElbow = { 0, 0.275, 0 }, RightWrist = { 0, -0.532, 0 } },
	},
	RightHand = { size = { 0.984, 0.316, 1.028 }, color = "#FFDCDC", att = { RightWrist = { 0, 0.132, 0 } } },
	LeftUpperArm = {
		size = { 1.001, 1.242, 1.002 },
		color = "#3C5ADC",
		att = { LeftShoulder = { 0.501, 0.419, 0 }, LeftElbow = { 0, -0.355, 0 } },
	},
	LeftLowerArm = {
		size = { 1.001, 1.118, 1.002 },
		color = "#8CAAFF",
		att = { LeftElbow = { 0, 0.275, 0 }, LeftWrist = { 0, -0.532, 0 } },
	},
	LeftHand = { size = { 0.984, 0.316, 1.028 }, color = "#DCE6FF", att = { LeftWrist = { 0, 0.132, 0 } } },
	RightUpperLeg = {
		size = { 0.993, 1.363, 0.973 },
		color = "#C83C3C",
		att = { RightHip = { 0, 0.471, 0 }, RightKnee = { 0, -0.449, 0 } },
	},
	RightLowerLeg = {
		size = { 0.993, 1.301, 0.973 },
		color = "#FF9664",
		att = { RightKnee = { 0, 0.413, 0 }, RightAnkle = { 0, -0.596, 0 } },
	},
	RightFoot = { size = { 1.009, 0.312, 1.001 }, color = "#FFC878", att = { RightAnkle = { 0, 0.106, 0 } } },
	LeftUpperLeg = {
		size = { 0.993, 1.363, 0.973 },
		color = "#3C50C8",
		att = { LeftHip = { 0, 0.471, 0 }, LeftKnee = { 0, -0.449, 0 } },
	},
	LeftLowerLeg = {
		size = { 0.993, 1.301, 0.973 },
		color = "#64AAFF",
		att = { LeftKnee = { 0, 0.413, 0 }, LeftAnkle = { 0, -0.596, 0 } },
	},
	LeftFoot = { size = { 1.009, 0.312, 1.001 }, color = "#96DCFF", att = { LeftAnkle = { 0, 0.106, 0 } } },
}

-- joint (attachment name), parent part, child part, pose joint
local CHAIN = {
	{ "Root", "HumanoidRootPart", "LowerTorso", "root" },
	{ "Waist", "LowerTorso", "UpperTorso", "waist" },
	{ "Neck", "UpperTorso", "Head", nil },
	{ "RightShoulder", "UpperTorso", "RightUpperArm", "rShoulder" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm", "rElbow" },
	{ "RightWrist", "RightLowerArm", "RightHand", "rWrist" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm", "lShoulder" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm", "lElbow" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand", "lWrist" },
	{ "RightHip", "LowerTorso", "RightUpperLeg", "rHip" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg", "rKnee" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot", nil },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg", "lHip" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg", "lKnee" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot", nil },
}

-- Same as AnimationController (R15 rig attachments have no rotation).
local function transform(joint: string?, v: { number }?): any
	if not joint or not v then
		return CFrame.identity
	end
	if joint == "rKnee" or joint == "lKnee" then
		return CFrame.fromEulerAnglesYXZ(math.rad(-(v[1] or 0)), 0, 0)
	end
	local q = CFrame.fromEulerAnglesYXZ(math.rad(v[1] or 0), math.rad(v[2] or 0), math.rad(v[3] or 0))
	if joint == "root" then
		return CFrame.new(0, v[4] or 0, 0) * q
	end
	return q
end

local function at(v: { number }): any
	return CFrame.new(v[1], v[2], v[3])
end

local pieces = {}

local function dummy(pose: { [string]: { number } }, origin: any)
	local cf: { [string]: any } = { HumanoidRootPart = origin }
	for _, link in CHAIN do
		local parent, child = PARTS[link[2]], PARTS[link[3]]
		local T = transform(link[4], pose[link[4] or ""])
		cf[link[3]] = cf[link[2]] * at(parent.att[link[1]]) * T * at(child.att[link[1]]):Inverse()
	end
	for name, part in PARTS do
		if name ~= "HumanoidRootPart" then
			local c = cf[name]
			local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
			table.insert(pieces, {
				s = "box",
				size = part.size,
				p = { x, y, z },
				r = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
				c = part.color,
				m = "SmoothPlastic",
				lod = "shell",
			})
		end
	end
end

local args = process.args
local out = args[1] or "poses.json"
local frames = tonumber(args[3]) or 7
local ids = {}
local which = args[2] or "class:Warrior"
if string.sub(which, 1, 6) == "class:" then
	for _, skill in SkillData.byClass[string.sub(which, 7)] or {} do
		if SkillMotions.get(skill.id) then
			table.insert(ids, skill.id)
		end
	end
else
	for id in string.gmatch(which, "[^,]+") do
		table.insert(ids, id)
	end
end

local rows = {}
for row, id in ids do
	local motion = assert(SkillMotions.get(id), id)
	local loopUntil = if motion.loop then motion.loop.to + 0.3 else nil
	local total = SkillPose.duration(motion, loopUntil)
	for i = 0, frames - 1 do
		local t = total * i / (frames - 1) * 0.94
		local pose = SkillPose.sample(motion, t, { loopUntil = loopUntil })
		-- front row (facing the camera at -Z) and, behind it, the same frame seen from the right side
		dummy(pose, CFrame.new(-i * 6, 3, (row - 1) * 16))
		dummy(pose, CFrame.new(-i * 6, 3, (row - 1) * 16 + 7) * CFrame.Angles(0, math.rad(90), 0))
	end
	table.insert(rows, `{row}:{id} ({string.format("%.2f", total)} s)`)
end
table.insert(pieces, {
	s = "box",
	size = { frames * 6 + 6, 0.2, #ids * 16 + 6 },
	p = { -(frames - 1) * 3, -0.1, (#ids - 1) * 8 + 4 },
	r = { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	c = "#6F7A62",
	m = "Grass",
	lod = "shell",
})
fs.writeFile(out, `\{"pieces": {serde.encode("json", pieces)}\}`)
print(table.concat(rows, "  "))
