--!strict
-- Procedural animation without animation assets (S17b):
--   * monsters: every "Gait_*" Motor6D built by RigBuilder is posed each frame from Logic/Gait (walk cycle
--     from the replicated root velocity, idle breathing, attack windup and strike, hit flinch, death collapse);
--   * characters: arm swing on basic attacks and a cast pose (point / raise / slam) on skills, by rotating
--     the shoulder joints (C0) on top of the default Roblox animations.
-- Everything runs locally on every client, so other players see the same motion. Real monster models from
-- Assets.Monsters have no Gait joints and are left alone.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local State = require(script.Parent.Parent.UI.State)

local AnimationController = {
	Name = "AnimationController",
}

local RANGE = 150 -- studs from the camera; farther monsters keep their last pose
local RANGE_LOW = 70 -- with low effects quality
local HIT_SECONDS = 0.25
local DEATH_SECONDS = 0.55

type JointState = { motor: Motor6D, joint: Gait.Joint, scale: number }

type MonsterState = {
	model: Model,
	root: BasePart,
	joints: { JointState },
	scale: number,
	seed: number,
	cycle: number,
	move: number,
	attackStart: number,
	attackWindup: number,
	hitAt: number,
	deadAt: number?,
}

local monsters: { [Model]: MonsterState } = {}
local motion: Gait.Motion = { cycle = 0, move = 0, time = 0, raise = 0, strike = 0, hit = 0, dead = 0 }

-- Monsters --------------------------------------------------------------------------------------------------

local function collectJoints(model: Model): { JointState }
	local joints: { JointState } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and string.sub(item.Name, 1, 5) == "Gait_" then
			local role = item:GetAttribute("Role")
			if type(role) ~= "string" then
				continue
			end
			table.insert(joints, {
				motor = item,
				joint = {
					role = role :: any,
					side = tonumber(item:GetAttribute("Side")) or 0,
					phase = tonumber(item:GetAttribute("Phase")) or 0,
					amp = tonumber(item:GetAttribute("Amp")) or 1,
				},
				scale = tonumber(item:GetAttribute("Scale")) or 1,
			})
		end
	end
	return joints
end

local function track(model: Instance)
	if not model:IsA("Model") or monsters[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local joints = collectJoints(model)
	if #joints == 0 then
		return
	end
	local scale = 1
	for _, j in joints do
		if j.joint.role == "body" then
			scale = j.scale
		end
	end
	monsters[model] = {
		model = model,
		root = root,
		joints = joints,
		scale = scale,
		seed = math.random() * 100,
		cycle = 0,
		move = 0,
		attackStart = -math.huge,
		attackWindup = Gait.DEFAULT_WINDUP,
		hitAt = -math.huge,
		deadAt = nil,
	}
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local range = if State.Get({ "account", "settings", "quality" }) == "low" then RANGE_LOW else RANGE
	local now = os.clock()
	for model, s in monsters do
		if not model.Parent or not s.root.Parent then
			monsters[model] = nil
			continue
		end
		if (s.root.Position - eye).Magnitude > range then
			continue
		end
		local velocity = s.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local target = math.clamp(speed / 3, 0, 1)
		s.move += (target - s.move) * math.min(1, dt * 8)
		s.cycle = Gait.advance(s.cycle, dt, speed, s.scale)
		if s.deadAt == nil and model:GetAttribute("Dead") == true then
			s.deadAt = now
		end

		local raise, strike = Gait.attack(now - s.attackStart, s.attackWindup)
		motion.cycle = s.cycle
		motion.move = s.move
		motion.time = now + s.seed
		motion.raise = raise
		motion.strike = strike
		motion.hit = math.max(0, 1 - (now - s.hitAt) / HIT_SECONDS)
		motion.dead = if s.deadAt then math.clamp((now - s.deadAt) / DEATH_SECONDS, 0, 1) else 0

		for _, j in s.joints do
			local p = Gait.pose(j.joint, motion)
			local k = j.scale
			j.motor.Transform = CFrame.new(p.x * k, p.y * k, p.z * k) * CFrame.Angles(p.rx, p.ry, p.rz)
		end
	end
end

-- Starts an attack: the limbs rise for `windup` seconds and strike. With `strikeNow` the windup is mostly
-- skipped (basic attacks arrive when the hit already landed).
function AnimationController.MonsterAttack(model: Model, windup: number?, strikeNow: boolean?)
	local s = monsters[model]
	if not s then
		return
	end
	local w = math.clamp(windup or Gait.DEFAULT_WINDUP, 0.05, 5)
	s.attackWindup = w
	s.attackStart = os.clock() - (if strikeNow then math.max(0, w - 0.06) else 0)
end

function AnimationController.MonsterHit(model: Model)
	local s = monsters[model]
	if s then
		s.hitAt = os.clock()
	end
end

-- Characters ------------------------------------------------------------------------------------------------

local shoulderRest: { [Motor6D]: CFrame } = {}

local function shoulder(model: Model, side: "Right" | "Left"): (Motor6D?, CFrame)
	local motor = model:FindFirstChild(`{side}Shoulder`, true) or model:FindFirstChild(`{side} Shoulder`, true)
	if not motor or not motor:IsA("Motor6D") then
		return nil, CFrame.identity
	end
	local rest = shoulderRest[motor]
	if not rest then
		rest = motor.C0
		shoulderRest[motor] = rest
		motor.Destroying:Connect(function()
			shoulderRest[motor] = nil
		end)
	end
	return motor, rest :: CFrame
end

-- Plays raised -> strike -> rest on one shoulder.
local function shoulderMove(motor: Motor6D, rest: CFrame, raised: CFrame, strike: CFrame, hold: number)
	motor.C0 = raised
	local down = TweenService:Create(
		motor,
		TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, hold),
		{ C0 = strike }
	)
	down:Play()
	down.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			TweenService:Create(motor, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { C0 = rest }):Play()
		end
	end)
end

-- Basic attack: overhead chop for melee, arm held forward for ranged.
function AnimationController.Swing(character: Model, ranged: boolean)
	local motor, rest = shoulder(character, "Right")
	if not motor then
		return
	end
	if ranged then
		shoulderMove(motor, rest, rest * CFrame.Angles(math.rad(80), 0, 0), rest * CFrame.Angles(math.rad(90), 0, 0), 0)
	else
		shoulderMove(
			motor,
			rest,
			rest * CFrame.Angles(math.rad(110), 0, math.rad(-25)),
			rest * CFrame.Angles(math.rad(-20), 0, math.rad(25)),
			0
		)
	end
end

export type CastStyle = "point" | "raise" | "slam"

-- Skill cast pose. point: right arm towards the target; raise: both arms up (buffs, heals);
-- slam: both arms up, then down hard (ground area skills).
function AnimationController.Cast(character: Model, style: CastStyle)
	if monsters[character] then
		AnimationController.MonsterAttack(character, nil, true)
		return
	end
	local right, restR = shoulder(character, "Right")
	local left, restL = shoulder(character, "Left")
	if style == "point" then
		if right then
			local aim = restR * CFrame.Angles(math.rad(90), 0, 0)
			shoulderMove(right, restR, aim, aim, 0.2)
		end
		return
	end
	local function both(motor: Motor6D?, rest: CFrame, side: number)
		if not motor then
			return
		end
		local up = rest * CFrame.Angles(math.rad(160), 0, math.rad(18) * side)
		if style == "slam" then
			shoulderMove(motor, rest, up, rest * CFrame.Angles(math.rad(20), 0, 0), 0.12)
		else
			shoulderMove(motor, rest, up, up, 0.35)
		end
	end
	both(right, restR, -1)
	both(left, restL, 1)
end

function AnimationController.Start()
	RunService.PreSimulation:Connect(step)
	local folder = Workspace:WaitForChild("Monsters", 60)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		track(child)
	end
	folder.ChildAdded:Connect(function(child)
		-- Atomic streaming delivers the whole model at once; one frame lets attributes settle.
		task.defer(track, child)
	end)
	folder.ChildRemoved:Connect(function(child)
		monsters[child :: Model] = nil
	end)
end

return AnimationController
