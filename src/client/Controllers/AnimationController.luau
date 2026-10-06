--!strict
-- Procedural animation without animation assets (S17b):
--   * monsters: every "Gait_*" Motor6D built by RigBuilder is posed each frame from Logic/Gait (walk cycle
--     from the replicated root velocity, idle breathing, attack windup and strike, hit flinch, death collapse);
--   * characters (S22): basic attacks play a weapon-specific pose sequence (Logic/AttackPose: cut, two-handed
--     cut, thrust, smash, bow draw, crossbow, wand / staff push, punch) written to Motor6D.Transform in
--     PreSimulation, after the Animator, on top of the default animation (legs keep walking; the arms follow
--     the attack by its weight); a hit tilts the upper body back for a moment. Skills keep the cast pose
--     (point / raise / slam) by rotating the shoulder joints (C0).
-- Everything runs locally on every client, so other players see the same motion. Real monster models from
-- Assets.Monsters have no Gait joints and are left alone.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local AttackPose = require(ReplicatedStorage.Shared.Logic.AttackPose)
local Config = require(ReplicatedStorage.Shared.Config)
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

-- Characters: attack poses (S22) --------------------------------------------------------------------------

type JointRef = { motor: Motor6D, rot: CFrame }
type Rig = { joints: { [AttackPose.Joint]: JointRef }, r6: boolean }
type Attack = {
	motion: AttackPose.MotionName,
	start: number,
	interval: number?,
	from: AttackPose.Pose?,
	pose: AttackPose.Pose?,
}

local JOINT_NAMES: { [AttackPose.Joint]: { string } } = {
	rShoulder = { "RightShoulder", "Right Shoulder" },
	rElbow = { "RightElbow" },
	rWrist = { "RightWrist" },
	lShoulder = { "LeftShoulder", "Left Shoulder" },
	lElbow = { "LeftElbow" },
	lWrist = { "LeftWrist" },
	waist = { "Waist" },
}
local FLINCH_SECONDS = 0.15
local FLINCH_DEGREES = 3
local R6_ELBOW_SHARE = 0.35 -- R6 has no elbows: part of the elbow bend goes to the shoulder

local rigs: { [Model]: Rig } = {}
local attacks: { [Model]: Attack } = {}
local flinches: { [Model]: number } = {}
-- Guard against stacking: the last Transform we wrote and the animation's own value under it.
local written: { [Motor6D]: CFrame } = {}
local under: { [Motor6D]: CFrame } = {}

local function rigOf(model: Model): Rig?
	local rig = rigs[model]
	if rig then
		return rig
	end
	local joints: { [AttackPose.Joint]: JointRef } = {}
	local r6 = model:FindFirstChild("Torso") ~= nil and model:FindFirstChild("UpperTorso") == nil
	for joint, names in JOINT_NAMES do
		for _, name in names do
			local motor = model:FindFirstChild(name, true)
			if motor and motor:IsA("Motor6D") then
				joints[joint] = { motor = motor, rot = motor.C0.Rotation }
				break
			end
		end
	end
	if not joints.rShoulder then
		return nil
	end
	local created: Rig = { joints = joints, r6 = r6 }
	rigs[model] = created
	model.Destroying:Connect(function()
		rigs[model] = nil
		attacks[model] = nil
		flinches[model] = nil
	end)
	return created
end

-- Hands the joints back to the default animation (once, after an attack or a flinch ends).
local function release(rig: Rig)
	for _, ref in rig.joints do
		local motor = ref.motor
		if written[motor] and motor.Transform == written[motor] then
			motor.Transform = under[motor] or CFrame.identity
		end
		written[motor] = nil
		under[motor] = nil
	end
end

local function poseCharacter(model: Model, rig: Rig, now: number)
	local attack = attacks[model]
	local pose: AttackPose.Pose? = nil
	local weight = 0
	if attack then
		local p, phase, w = AttackPose.sample(attack.motion, now - attack.start, attack.interval, attack.from)
		if phase == "rest" then
			attacks[model] = nil
		else
			pose, weight = p, w
			attack.pose = p
		end
	end
	local flinchAt = flinches[model]
	local flinch = 0
	if flinchAt then
		local t = (now - flinchAt) / FLINCH_SECONDS
		if t >= 1 then
			flinches[model] = nil
		else
			flinch = math.rad(FLINCH_DEGREES) * math.sin(t * math.pi)
		end
	end
	if not pose and flinch == 0 then
		release(rig)
		return
	end
	for joint, ref in rig.joints do
		local a = if pose then pose[joint] else nil
		local x, y, z = 0, 0, 0
		if a then
			x, y, z = a[1], a[2], a[3]
			if rig.r6 and pose and (joint == "rShoulder" or joint == "lShoulder") then
				local elbow = pose[if joint == "rShoulder" then "rElbow" else "lElbow"]
				x += (elbow and elbow[1] or 0) * R6_ELBOW_SHARE
			end
		end
		local q = CFrame.fromEulerAnglesYXZ(math.rad(x), math.rad(y), math.rad(z))
		if joint == "waist" and flinch ~= 0 then
			q = CFrame.Angles(flinch, 0, 0) * q
		end
		local motor = ref.motor
		local anim = motor.Transform
		if written[motor] and anim == written[motor] then
			-- The Animator did not touch this joint since our last write: start from its own value again.
			anim = under[motor] or CFrame.identity
		end
		under[motor] = anim
		local own = if joint == "waist" then weight * 0.6 else weight
		local final = anim:Lerp(CFrame.identity, own) * (ref.rot:Inverse() * q * ref.rot)
		motor.Transform = final
		written[motor] = final
	end
end

local function stepCharacters()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local active: { [Model]: boolean } = {}
	for model in attacks do
		active[model] = true
	end
	for model in flinches do
		active[model] = true
	end
	for model in active do
		local rig = rigs[model]
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rig or not model.Parent or not root then
			attacks[model] = nil
			flinches[model] = nil
		elseif (root.Position - eye).Magnitude > Config.EffectRadius then
			attacks[model] = nil
			flinches[model] = nil
			release(rig)
		else
			poseCharacter(model, rig, now)
		end
	end
end

-- Plays the basic attack of `weaponType` (Items type, nil = fists) on a character. A running attack is
-- interrupted smoothly (the new one starts from the pose the old one had reached). Returns the timing (when
-- the blow lands / the shot leaves) even when the character is too far away to animate.
function AnimationController.Attack(model: Model, weaponType: string?, interval: number?): AttackPose.Timing
	local motion = AttackPose.motionFor(weaponType)
	local timing = AttackPose.timing(motion, interval)
	local rig = rigOf(model)
	if rig then
		local running = attacks[model]
		attacks[model] = {
			motion = motion,
			start = os.clock(),
			interval = interval,
			from = if running then running.pose else nil,
			pose = nil,
		}
	end
	return timing
end

-- A short tilt of the upper body when a character is hit.
function AnimationController.CharacterHit(model: Model)
	if rigOf(model) then
		flinches[model] = os.clock()
	end
end

-- Motion names (for /anim).
AnimationController.MOTIONS = AttackMotions.byWeapon

-- Characters: skill cast poses ---------------------------------------------------------------------------

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
	RunService.PreSimulation:Connect(function(dt: number)
		step(dt)
		stepCharacters()
	end)
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
