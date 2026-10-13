--!strict
-- Procedural animation without animation assets (S17b):
--   * monsters: every "Gait_*" Motor6D of the look (S24: built on this client by MonsterViewController, joints
--     collected again whenever the full look appears) is posed each frame from Logic/Gait (walk cycle from the
--     replicated root velocity, idle breathing, attack windup and strike, hit flinch, death collapse). Real
--     models with `asset.rig = "animator"` play their clips instead (Logic/LookAnim). Only the nearest
--     Config.MonsterLook.maxAnimated monsters with a full look move; the rest hold still;
--   * characters (S22): basic attacks play a weapon-specific pose sequence (Logic/AttackPose: cut, two-handed
--     cut, thrust, smash, bow draw, crossbow, wand / staff push, punch) written to Motor6D.Transform in
--     PreSimulation, after the Animator, on top of the default animation (legs keep walking; the arms follow
--     the attack by its weight); a hit tilts the upper body back for a moment;
--   * skills (S28): every active skill plays its own motion (Data/SkillMotions through Logic/SkillPose) on the same
--     joints plus the whole body (RootJoint: turns, flips, visual jumps) and the legs; it wins over the basic attack,
--     stops on stun / death, freezes for a moment on a melee hit (hitstop) and may hold the character still while it
--     plays (`lock`, unless a breakpoint lets it move: castMove);
--   * mounts (S96): every model tagged "VaelthornMount" (Util/MountLook, welded under a rider) walks its Gait_* legs
--     in step with the rider's speed (stride x Data/Mounts.RIDER.stride), a real model with MountRig "animator"
--     plays its clips (Data/Mounts.assets anims) and "static" stands; the rider (character attribute Mount) sits
--     astride with the legs of Logic/RiderPose (the arms stay free for the basic attack).
-- Everything runs locally on every client, so other players see the same motion.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local AttackPose = require(ReplicatedStorage.Shared.Logic.AttackPose)
local Config = require(ReplicatedStorage.Shared.Config)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local SkillMotions = require(ReplicatedStorage.Shared.Data.SkillMotions)
local SkillPose = require(ReplicatedStorage.Shared.Logic.SkillPose)
local LookAnim = require(ReplicatedStorage.Shared.Logic.LookAnim)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local MountData = require(ReplicatedStorage.Shared.Data.Mounts)
local RiderPose = require(ReplicatedStorage.Shared.Logic.RiderPose)
local UserInputService = game:GetService("UserInputService")

local AnimationController = {
	Name = "AnimationController",
	Deps = { "MonsterViewController" },
}

local MonsterView: any = nil
local HIT_SECONDS = 0.25
local SPAWN_SECONDS = 1.2
local PICK_EVERY = 0.25 -- seconds between choosing which monsters animate
local DEATH_SECONDS = 0.55

type JointState = { motor: Motor6D, joint: Gait.Joint, scale: number }

type Clips = {
	animator: Animator,
	tracks: { [string]: AnimationTrack },
	playing: AnimationTrack?,
	slot: string?,
	walkSpeed: number?,
	paused: boolean,
}

type MonsterState = {
	model: Model,
	root: BasePart,
	joints: { JointState },
	clips: Clips?,
	spawnedAt: number,
	attackSlot: string,
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
local animated: { [Model]: boolean } = {}
local animations: { [string]: Animation } = {} -- one Animation object per id
local pickClock = 0
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

-- Tracks of `anims` (slot -> animation id) on `animator` (S96: monsters and mounts).
local function clipsFrom(animator: Animator, anims: { [string]: string }, walkSpeed: number?): Clips
	local tracks: { [string]: AnimationTrack } = {}
	for slot, id in anims do
		local animation = animations[id]
		if not animation then
			local created = Instance.new("Animation")
			created.AnimationId = id
			animations[id] = created
			animation = created
		end
		local ok, loaded = pcall(function()
			return animator:LoadAnimation(animation :: Animation)
		end)
		if ok and loaded then
			tracks[slot] = loaded
		end
	end
	return {
		animator = animator,
		tracks = tracks,
		playing = nil,
		slot = nil,
		walkSpeed = walkSpeed,
		paused = false,
	}
end

-- Clips of a real model (asset.rig = "animator"), loaded once per look.
local function loadClips(model: Model): Clips?
	local lookId = model:GetAttribute("Look")
	local look = if type(lookId) == "string" then MonsterLooks.get(lookId) else nil
	local asset = look and look.asset
	if not asset or asset.rig ~= "animator" or not asset.anims then
		return nil
	end
	local holder = model:FindFirstChild("Look")
	local animator = holder and holder:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return nil
	end
	return clipsFrom(animator :: Animator, asset.anims :: { [string]: string }, asset.walkSpeed)
end

-- (Re)collects the joints of a monster's look; called when the model arrives and when its look changes.
local function refresh(model: Model)
	local s = monsters[model]
	if not s then
		return
	end
	s.joints = collectJoints(model)
	s.clips = loadClips(model)
	for _, j in s.joints do
		if j.joint.role == "body" then
			s.scale = j.scale
		end
	end
end

local function track(model: Instance)
	if not model:IsA("Model") or monsters[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local scale = model:GetAttribute("LookScale")
	monsters[model] = {
		model = model,
		root = root,
		joints = {},
		clips = nil,
		spawnedAt = os.clock(),
		attackSlot = "attack1",
		scale = if type(scale) == "number" then scale else 1,
		seed = math.random() * 100,
		cycle = 0,
		move = 0,
		attackStart = -math.huge,
		attackWindup = Gait.DEFAULT_WINDUP,
		hitAt = -math.huge,
		deadAt = nil,
	}
	refresh(model)
end

-- The nearest monsters with a full look shown animate (Config.MonsterLook.maxAnimated).
local function pickAnimated()
	local list: { MonsterState } = {}
	for model, s in monsters do
		if MonsterView.IsFull(model) and (#s.joints > 0 or s.clips ~= nil) then
			table.insert(list, s)
		end
	end
	table.sort(list, function(a, b)
		return MonsterView.Distance(a.model) < MonsterView.Distance(b.model)
	end)
	local limits = Config.MonsterLook.maxAnimated
	local limit = if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		then limits.touch
		else limits.desktop
	table.clear(animated)
	for i = 1, math.min(limit, #list) do
		animated[list[i].model] = true
	end
	for _, s in list do
		local clips = s.clips
		if clips then
			local on = animated[s.model] == true
			if clips.paused == on and clips.playing then
				clips.playing:AdjustSpeed(if on then 1 else 0)
			end
			clips.paused = not on
		end
	end
end

local function stepClips(s: MonsterState, clips: Clips, now: number, speed: number)
	local raise, strike = Gait.attack(now - s.attackStart, s.attackWindup)
	local available: { [string]: boolean } = {}
	for slot in clips.tracks do
		available[slot] = true
	end
	local pick = LookAnim.pick({
		dead = s.deadAt ~= nil,
		hit = now - s.hitAt < HIT_SECONDS,
		attack = if raise > 0 or strike > 0 then s.attackSlot :: any else nil,
		speed = speed,
		spawning = now - s.spawnedAt < SPAWN_SECONDS,
		walkSpeed = clips.walkSpeed,
	}, available)
	if not pick then
		return
	end
	local clip = clips.tracks[pick.slot]
	if clips.slot ~= pick.slot or not clips.playing then
		if clips.playing then
			clips.playing:Stop(pick.fade)
		end
		clip.Looped = pick.looped
		clip:Play(pick.fade)
		clips.playing = clip
		clips.slot = pick.slot
	end
	clip:AdjustSpeed(pick.speed)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	if now - pickClock >= PICK_EVERY then
		pickClock = now
		pickAnimated()
	end
	for model, s in monsters do
		if not model.Parent or not s.root.Parent then
			monsters[model] = nil
			animated[model] = nil
			continue
		end
		if s.deadAt == nil and model:GetAttribute("Dead") == true then
			s.deadAt = now
		end
		if not animated[model] then
			continue
		end
		local velocity = s.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local target = math.clamp(speed / 3, 0, 1)
		s.move += (target - s.move) * math.min(1, dt * 8)
		s.cycle = Gait.advance(s.cycle, dt, speed, s.scale)
		local clips = s.clips
		if clips then
			stepClips(s, clips, now, speed)
			continue
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
	-- Real models: long windups are spells and specials.
	s.attackSlot = if strikeNow then "attack1" elseif w > 1 then "cast" else "attack2"
	s.attackStart = os.clock() - (if strikeNow then math.max(0, w - 0.06) else 0)
end

function AnimationController.MonsterHit(model: Model)
	local s = monsters[model]
	if s then
		s.hitAt = os.clock()
	end
end

-- Mounts (S96) ------------------------------------------------------------------------------------------------

local MOUNT_TAG = "VaelthornMount"
local MOUNT_RUN_ABOVE = 20 -- speed from which a real mount model plays "run"

type MountState = {
	model: Model,
	joints: { JointState },
	clips: Clips?,
	scale: number,
	cycle: number,
	move: number,
	seed: number,
}

local mounts: { [Model]: MountState } = {}

-- Clips of a real mount model (MountRig "animator", Data/Mounts.assets anims); a model without an Animator gets a
-- local one (the clips only play on this client, like every animation here).
local function mountClips(model: Model): Clips?
	local id = model:GetAttribute("MountId")
	local asset = if type(id) == "string" then MountData.assets[id] else nil
	if not asset or not asset.anims then
		return nil
	end
	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		local controller = model:FindFirstChildWhichIsA("AnimationController", true)
		if not controller then
			local created = Instance.new("AnimationController")
			created.Parent = model
			controller = created
		end
		local created = Instance.new("Animator")
		created.Parent = controller
		animator = created
	end
	return clipsFrom(animator :: Animator, asset.anims, asset.walkSpeed)
end

local function trackMount(instance: Instance)
	if not instance:IsA("Model") or mounts[instance] then
		return
	end
	local rig = instance:GetAttribute("MountRig")
	local scale = instance:GetAttribute("LookScale")
	mounts[instance] = {
		model = instance,
		joints = if rig == "gait" then collectJoints(instance) else {},
		clips = if rig == "animator" then mountClips(instance) else nil,
		scale = if type(scale) == "number" then scale else 1,
		cycle = 0,
		move = 0,
		seed = math.random() * 100,
	}
end

local function riderRoot(model: Model): BasePart?
	local rider = model.Parent
	local root = rider and rider:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function stepMountClips(clips: Clips, speed: number)
	local available: { [string]: boolean } = {}
	for slot in clips.tracks do
		available[slot] = true
	end
	local pick = LookAnim.pick({ speed = speed, runAbove = MOUNT_RUN_ABOVE, walkSpeed = clips.walkSpeed }, available)
	if not pick then
		return
	end
	local clip = clips.tracks[pick.slot]
	if clips.slot ~= pick.slot or not clips.playing then
		if clips.playing then
			clips.playing:Stop(pick.fade)
		end
		clip.Looped = pick.looped
		clip:Play(pick.fade)
		clips.playing = clip
		clips.slot = pick.slot
	end
	clip:AdjustSpeed(pick.speed)
end

-- Walk cycle of every mount near the camera from its rider's speed; legs from Logic/Gait or the model's clips.
local function stepMounts(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	for model, m in mounts do
		if not model.Parent then
			mounts[model] = nil
			continue
		end
		local root = riderRoot(model)
		if not root or (root.Position - eye).Magnitude > Config.EffectRadius then
			continue
		end
		local velocity = root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local target = math.clamp(speed / 3, 0, 1)
		m.move += (target - m.move) * math.min(1, dt * 8)
		m.cycle = Gait.advance(m.cycle, dt, speed, m.scale * MountData.RIDER.stride)
		local clips = m.clips
		if clips then
			stepMountClips(clips, speed)
			continue
		end
		motion.cycle = m.cycle
		motion.move = m.move
		motion.time = now + m.seed
		motion.raise = 0
		motion.strike = 0
		motion.hit = 0
		motion.dead = 0
		for _, j in m.joints do
			local p = Gait.pose(j.joint, motion)
			local k = j.scale
			j.motor.Transform = CFrame.new(p.x * k, p.y * k, p.z * k) * CFrame.Angles(p.rx, p.ry, p.rz)
		end
	end
end

-- Rider pose of a character on a mount (nil on foot): the legs astride, lifted in step with the mount.
local function riderPose(model: Model): AttackPose.Pose?
	local id = model:GetAttribute("Mount")
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local mount = model:FindFirstChild(MOUNT_TAG)
	local m = if mount and mount:IsA("Model") then mounts[mount] else nil
	return RiderPose.sample(if m then m.cycle else 0, if m then m.move else 0)
end

-- Characters: attack poses (S22) --------------------------------------------------------------------------

-- A joint is a Motor6D or (avatar joint upgrade, S28) an AnimationConstraint: both take Transform.
type JointRef = { motor: any, rot: CFrame }
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
	-- S28: skill motions also move the whole body and the legs (R15 Root / R6 RootJoint).
	root = { "Root", "RootJoint" },
	rHip = { "RightHip", "Right Hip" },
	lHip = { "LeftHip", "Left Hip" },
	rKnee = { "RightKnee" },
	lKnee = { "LeftKnee" },
}
-- Joints the basic attack poses own (the skill motions add the rest).
local ATTACK_JOINTS = { "rShoulder", "rElbow", "rWrist", "lShoulder", "lElbow", "lWrist", "waist" }
local FLINCH_SECONDS = 0.15
local FLINCH_DEGREES = 3
local R6_ELBOW_SHARE = 0.35 -- R6 has no elbows: part of the elbow bend goes to the shoulder

type SkillPlay = {
	motion: SkillMotions.Motion,
	start: number,
	loopUntil: number?,
	from: AttackPose.Pose?,
	pose: AttackPose.Pose?,
	frozenUntil: number, -- hitstop: the motion clock stands still until then
	frozenAt: number?,
}

local rigs: { [Model]: Rig } = {}
local attacks: { [Model]: Attack } = {}
local skills: { [Model]: SkillPlay } = {}
local flinches: { [Model]: number } = {}
-- Guard against stacking: the last Transform we wrote and the animation's own value under it.
local written: { [any]: CFrame } = {}
local under: { [any]: CFrame } = {}

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
			elseif motor and motor:IsA("AnimationConstraint") then
				-- Player characters with the avatar joint upgrade (found in Studio, S28): the same Transform, the
				-- frame of Attachment0 instead of C0.
				local a0 = motor.Attachment0
				joints[joint] = { motor = motor, rot = if a0 then a0.CFrame.Rotation else CFrame.identity }
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
		skills[model] = nil
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

-- Joint transform from pose degrees: torso-frame rotation q in the joint's own frame (rot = C0 rotation); knees bend
-- with + (the shin folds back), the root also lifts the body (studs).
local function jointTransform(joint: string, a: { number }, ref: JointRef, r6: boolean, pose: AttackPose.Pose?): CFrame
	local x, y, z = a[1] or 0, a[2] or 0, a[3] or 0
	if r6 and pose and (joint == "rShoulder" or joint == "lShoulder") then
		local elbow = pose[if joint == "rShoulder" then "rElbow" else "lElbow"]
		x += (elbow and elbow[1] or 0) * R6_ELBOW_SHARE
	end
	local q
	if joint == "rKnee" or joint == "lKnee" then
		q = CFrame.fromEulerAnglesYXZ(math.rad(-x), 0, 0)
	else
		q = CFrame.fromEulerAnglesYXZ(math.rad(x), math.rad(y), math.rad(z))
	end
	if joint == "root" then
		q = CFrame.new(0, a[4] or 0, 0) * q
	end
	return ref.rot:Inverse() * q * ref.rot
end

local function poseCharacter(model: Model, rig: Rig, now: number, ride: AttackPose.Pose?)
	-- A skill motion owns its joints; the basic attack the rest of the arms (S28).
	local skillPose: AttackPose.Pose? = nil
	local skillWeight = 0
	local play = skills[model]
	if play then
		local t = (play.frozenAt or now) - play.start
		local p, w, done = SkillPose.sample(play.motion, t, { from = play.from, loopUntil = play.loopUntil })
		if done then
			skills[model] = nil
		else
			skillPose, skillWeight = p, w
			play.pose = p
		end
	end
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
	if not pose and not skillPose and flinch == 0 and not ride then
		release(rig)
		return
	end
	for joint, ref in rig.joints do
		local fromSkill = skillPose and skillPose[joint]
		-- S96: the rider's legs and body lift (a skill dismounts, so the two meet only for a frame)
		local fromRide = if ride and not fromSkill and table.find(RiderPose.JOINTS, joint) then ride[joint] else nil
		local a = fromSkill or fromRide or (if pose then pose[joint] else nil)
		local isAttackJoint = table.find(ATTACK_JOINTS, joint) ~= nil
		local own: number
		if fromSkill then
			own = if joint == "waist" then skillWeight * 0.85 else skillWeight
		elseif fromRide then
			own = 1
		elseif isAttackJoint and pose then
			own = if joint == "waist" then weight * 0.6 else weight
		elseif joint == "waist" and flinch ~= 0 then
			own = 0
		else
			continue -- not moved by anything now (legs and root outside skill motions)
		end
		local q = if a then jointTransform(joint, a, ref, rig.r6, skillPose or pose) else CFrame.identity
		if joint == "waist" and flinch ~= 0 then
			q = ref.rot:Inverse() * CFrame.Angles(flinch, 0, 0) * ref.rot * q
		end
		local motor = ref.motor
		local anim = motor.Transform
		if written[motor] and anim == written[motor] then
			-- The Animator did not touch this joint since our last write: start from its own value again.
			anim = under[motor] or CFrame.identity
		end
		under[motor] = anim
		local final = anim:Lerp(CFrame.identity, own) * q
		motor.Transform = final
		written[motor] = final
	end
end

-- S96: characters posed as riders last frame (released once when they dismount).
local riders: { [Model]: boolean } = {}

local function stepCharacters()
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local active: { [Model]: boolean } = {}
	for model in attacks do
		active[model] = true
	end
	-- S96: riders (the mount's parent) and riders who just dismounted
	for mount in mounts do
		local rider = mount.Parent
		if rider and rider:IsA("Model") and rigOf(rider) then
			active[rider] = true
		end
	end
	for model in riders do
		active[model] = true
	end
	for model in flinches do
		active[model] = true
	end
	for model in skills do
		active[model] = true
	end
	for model in active do
		local rig = rigs[model]
		local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rig or not model.Parent or not root then
			attacks[model] = nil
			flinches[model] = nil
			skills[model] = nil
			riders[model] = nil
		elseif
			model:GetAttribute("VaelthornPreview") ~= true and (root.Position - eye).Magnitude > Config.EffectRadius
		then
			attacks[model] = nil
			flinches[model] = nil
			skills[model] = nil
			riders[model] = nil
			release(rig)
		else
			local ride = riderPose(model)
			if ride then
				riders[model] = true
			else
				riders[model] = nil
			end
			poseCharacter(model, rig, now, ride)
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

-- Plays a skill's motion on a character (S28). `loopUntil`: seconds a channel lasts (its loop repeats till then).
-- Returns the motion (nil when the skill has none) so callers can time effects on its events.
function AnimationController.Skill(model: Model, skillId: string, loopUntil: number?): SkillMotions.Motion?
	local motion = SkillMotions.get(skillId)
	if not motion then
		return nil
	end
	if monsters[model] then
		AnimationController.MonsterAttack(model, nil, true)
		return motion
	end
	if not rigOf(model) then
		return motion
	end
	local running = skills[model]
	local attack = attacks[model]
	-- A skill takes over from the basic attack, starting from the pose it reached.
	attacks[model] = nil
	skills[model] = {
		motion = motion,
		start = os.clock(),
		loopUntil = loopUntil,
		from = if running then running.pose elseif attack then attack.pose else nil,
		pose = nil,
		frozenUntil = 0,
		frozenAt = nil,
	}
	return motion
end

-- Stops a skill motion at once (stun, death, interrupted channel); the joints go back to the default animation.
function AnimationController.StopSkill(model: Model)
	if skills[model] then
		skills[model] = nil
		local rig = rigs[model]
		if rig then
			release(rig)
		end
	end
end

-- Hitstop (S28): the skill motion of `model` (and a monster's attack) stands still for `seconds`.
function AnimationController.Hitstop(model: Model, seconds: number)
	local play = skills[model]
	local now = os.clock()
	if play and not play.frozenAt then
		play.frozenAt = now
		task.delay(seconds, function()
			if skills[model] == play and play.frozenAt then
				play.start += os.clock() - (play.frozenAt :: number)
				play.frozenAt = nil
			end
		end)
	end
	local s = monsters[model]
	if s then
		s.attackStart += seconds
		s.hitAt = now
	end
end

-- Whether a character is playing a skill motion that holds it still (S28 `lock`).
function AnimationController.SkillLock(model: Model): boolean
	local play = skills[model]
	return play ~= nil and play.motion.lock == true
end

-- A short tilt of the upper body when a character is hit.
function AnimationController.CharacterHit(model: Model)
	if rigOf(model) then
		flinches[model] = os.clock()
	end
end

-- Motion names (for /anim).
AnimationController.MOTIONS = AttackMotions.byWeapon

-- Monsters animated right now (/lookstats).
function AnimationController.AnimatedCount(): number
	local n = 0
	for _ in animated do
		n += 1
	end
	return n
end

function AnimationController.Init(registry: any)
	MonsterView = registry.Get("MonsterViewController")
end

function AnimationController.Start()
	MonsterView.Changed:Connect(function(model: Model)
		if monsters[model] then
			refresh(model)
		else
			track(model)
		end
	end)
	RunService.PreSimulation:Connect(function(dt: number)
		step(dt)
		stepMounts(dt)
		stepCharacters()
	end)
	-- S96: mounts arrive with their rider (one frame lets the attributes settle)
	for _, instance in CollectionService:GetTagged(MOUNT_TAG) do
		trackMount(instance)
	end
	CollectionService:GetInstanceAddedSignal(MOUNT_TAG):Connect(function(instance)
		task.defer(trackMount, instance)
	end)
	CollectionService:GetInstanceRemovedSignal(MOUNT_TAG):Connect(function(instance)
		mounts[instance :: Model] = nil
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
