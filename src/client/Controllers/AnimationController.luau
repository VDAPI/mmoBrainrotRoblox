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
--     astride with the legs of Logic/RiderPose (the arms stay free for the basic attack);
--   AnimLab (S110): LabHold samples the attack and the skill of a preview model at a fixed time t and keeps them past
--     their end (a flinch at the same t), LabClear drops them; only models with the attribute VaelthornPreview;
--   S113 (DESIGN-16 §5): attacks within AttackMotions.COMBO_WINDOW play the next combo step (each client counts the
--     steps it sees; looks only), a step may hold its pose a moment at the hit (hitstop), a hit tilts the upper body away
--     from the attacker (AttackPose.flinch) and turns a generated monster's body away (MonsterState.hitDir, the base for
--     S117); real clips (AttackMotions clips / clipsByWeapon, SkillMotions clip) play through client/Anim/CharacterClips
--     instead of the poses when they loaded, fitted to the server's hit, and the poses stay the fallback.
--   S117 (DESIGN-16 §8): generated monsters attack in the style of their body plan (Data/MonsterMotions: by weapon for
--     humanoids, the Elite II special by its ability) and bosses with the pose of each attack (Data/BossMotions); a
--     telegraphed attack gathers over exactly the windup the telegraph fills over (Gait.charge, the blow peaks at its
--     end), a basic one peaks Gait.STRIKE_NOW_LEAD after its event; a hit or a hitstop never cuts the gather; Grimrok's
--     leap flies the last Config.MonsterLook.leapArc s to the area before the server's teleport; a new boss phase roars,
--     a summoned helper (attribute Summoned) climbs out of the ground, Vaelgrath's wings beat wide while Flying; deaths
--     by plan over Config.MonsterLook.deathSeconds; a hit pushes the body away from the attacker (Gait.hitLean, bosses
--     less). Real models keep their clips (S116 adds attack / roar clips); the new poses are the generator's.
-- Everything runs locally on every client, so other players see the same motion.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Anatomy = require(ReplicatedStorage.Shared.Logic.Anatomy)
local AnatomyPlans = require(ReplicatedStorage.Shared.Logic.Anatomy.Plans)
local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local AttackPose = require(ReplicatedStorage.Shared.Logic.AttackPose)
local BossMotions = require(ReplicatedStorage.Shared.Data.BossMotions)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local CharacterClips = require(script.Parent.Parent.Anim.CharacterClips)
local ClipFit = require(ReplicatedStorage.Shared.Logic.ClipFit)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local SkillMotions = require(ReplicatedStorage.Shared.Data.SkillMotions)
local SkillPose = require(ReplicatedStorage.Shared.Logic.SkillPose)
local LookAnim = require(ReplicatedStorage.Shared.Logic.LookAnim)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local MonsterMotions = require(ReplicatedStorage.Shared.Data.MonsterMotions)
local MountData = require(ReplicatedStorage.Shared.Data.Mounts)
local Telegraph = require(ReplicatedStorage.Shared.Logic.Telegraph)
local Library = require(script.Parent.Parent.Vfx.Library)
local State = require(script.Parent.Parent.UI.State)
local RiderPose = require(ReplicatedStorage.Shared.Logic.RiderPose)
local UserInputService = game:GetService("UserInputService")

local AnimationController = {
	Name = "AnimationController",
	Deps = { "MonsterViewController" },
}

local MonsterView: any = nil
local HIT_SECONDS = Gait.HIT_SECONDS -- S110: shared with MobViz and AnimLab
local SPAWN_SECONDS = 1.2 -- window in which a real model plays its "spawn" clip (not Gait.SPAWN_SECONDS)
local PICK_EVERY = 0.25 -- seconds between choosing which monsters animate
local DEATH_SECONDS = Gait.DEATH_SECONDS
local LOOK = Config.MonsterLook
-- S117: looks only.
local SAME_ATTACK = 0.1 -- seconds: more telegraphs of one attack (count, target "all") pose it once
local CHARGE_HIT = 0.3 -- a hit during a gather leans the body this much (it never restarts the gather)
local ROAR_YIELD = 0.15 -- seconds a roar takes to give way to an attack
local TELEPORT_JUMP = 4 -- studs the root jumps in one frame when the server teleports a leaping boss
local LEAP_WAIT = 0.3 -- seconds after the windup a leap waits for the teleport, then its arc returns
local LEAP_BACK = 0.2 -- seconds the arc takes to return
local LAND_WIDE = 0.5 -- seconds the wings stay wide after a flight
local LAND_FADE = 0.2 -- then they settle over this
local DUST_TINT = Color3.fromHex("#6A5A48") -- the cracks a summon leaves

type JointState = { motor: Motor6D, joint: Gait.Joint, scale: number, body: boolean }

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
	flinchAt: number, -- S117: the last flinch from a blow (MonsterHit's hitEvery gate; Hitstop leaves it)
	hitDir: Vector3?, -- S113: flat unit direction of the last blow (from the attacker to the monster; S117 reads it)
	deadAt: number?,
	-- S117
	plan: string?,
	weapon: string?,
	bossId: string?,
	hover: number, -- studs at scale 1 the plan floats
	deathStyle: string?,
	deathSide: number,
	style: string?, -- the running attack's style
	charged: boolean, -- the running attack is telegraphed (Gait.charge)
	attackId: string?,
	leap: { offset: Vector3, height: number }?, -- Grimrok: the arc to the area (root frame)
	lastRoot: Vector3?,
	riseStart: number?,
	roarStart: number?,
	roarSeconds: number,
	flying: boolean,
	landedAt: number?,
	phase: number,
	connection: RBXScriptConnection?,
}

local monsters: { [Model]: MonsterState } = {}
local animated: { [Model]: boolean } = {}
local animations: { [string]: Animation } = {} -- one Animation object per id
local pickClock = 0
local motion: Gait.Motion = { cycle = 0, move = 0, time = 0, raise = 0, strike = 0, hit = 0, dead = 0 }
-- The S117 fields of the shared motion, cleared for every monster and mount (Gait reads nil / 0 as "off").
local function clearExtra(m: Gait.Motion)
	m.style = nil
	m.tremble = 0
	m.hop = 0
	m.spin = 0
	m.roar = 0
	m.roarStyle = nil
	m.rise = nil
	m.deathStyle = nil
	m.deathSide = nil
	m.hover = nil
	m.hitX = 0
	m.hitZ = 0
	m.plan = nil
	m.flying = 0
end

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
					front = tonumber(item:GetAttribute("Front")) or 0,
				},
				scale = tonumber(item:GetAttribute("Scale")) or 1,
				body = role == "body",
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

-- S117: the boss id of a monster model (a world boss: MonsterId; an AnimLab look: PreviewMonsterId), else nil.
local function bossIdOf(model: Model): string?
	local id = model:GetAttribute("MonsterId") or model:GetAttribute("PreviewMonsterId")
	return if type(id) == "string" and Bosses.get(id) then id else nil
end

-- S117: listeners of a phase roar (CombatFxController: the camera shake and the aura's flash).
local roarListeners: { (model: Model, bossId: string?) -> () } = {}

function AnimationController.OnRoar(fn: (model: Model, bossId: string?) -> ())
	table.insert(roarListeners, fn)
end

-- S117: a phase roar starts (a new phase of a boss; AnimLab `boss <id> roar` calls it directly).
local function startRoar(s: MonsterState)
	local def = if s.bossId then BossMotions.get(s.bossId) else nil
	s.roarStart = Clock.now()
	s.roarSeconds = if def then def.roar.seconds else LOOK.roarSeconds
	for _, fn in roarListeners do
		task.spawn(fn, s.model, s.bossId)
	end
end

-- S117: the first Config.MonsterLook.summonFxMax helpers of a wave rise with dust and cracks, the rest only move.
local SUMMON_WAVE = 1 -- seconds: summons arriving within this belong to one wave
local wave = { at = -math.huge, count = 0 }

local function riseFx(s: MonsterState)
	local now = Clock.now()
	if now - wave.at > SUMMON_WAVE then
		wave.at, wave.count = now, 0
	end
	wave.count += 1
	if wave.count > LOOK.summonFxMax then
		return
	end
	local low = State.Get({ "account", "settings", "quality" }) == "low"
	local at = s.root.Position
	Library.dust(at, 1.3 * s.scale, low)
	if not low then
		Library.groundDecal(at, 2.4 * s.scale, "cracks", Library.crackTint(DUST_TINT), LOOK.summonRise + 1.2)
	end
end

local function onAttribute(s: MonsterState, name: string)
	local model = s.model
	if name == "Phase" then
		local phase = tonumber(model:GetAttribute("Phase")) or 1
		if phase > s.phase and model:GetAttribute("Dead") ~= true then
			startRoar(s)
		end
		s.phase = phase
	elseif name == "Flying" then
		local flying = model:GetAttribute("Flying") == true
		if s.flying and not flying then
			s.landedAt = Clock.now()
		end
		s.flying = flying
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
	local lookId = model:GetAttribute("Look")
	local region = model:GetAttribute("LookRegion")
	local look = if type(lookId) == "string"
		then MonsterLooks.get(lookId, if type(region) == "number" then region else nil)
		else nil
	local plan = if look then look.plan else nil
	local seed = math.random() * 100
	local s: MonsterState = {
		model = model,
		root = root,
		joints = {},
		clips = nil,
		spawnedAt = Clock.now(),
		attackSlot = "attack1",
		scale = if type(scale) == "number" then scale else 1,
		seed = seed,
		cycle = 0,
		move = 0,
		attackStart = -math.huge,
		attackWindup = Gait.DEFAULT_WINDUP,
		hitAt = -math.huge,
		flinchAt = -math.huge,
		hitDir = nil,
		deadAt = nil,
		plan = plan,
		weapon = if look then look.weapon else nil,
		bossId = bossIdOf(model),
		hover = if plan and AnatomyPlans.hovers(plan) then Anatomy.HOVER else 0,
		deathStyle = nil,
		deathSide = if seed % 2 < 1 then -1 else 1,
		style = nil,
		charged = false,
		attackId = nil,
		leap = nil,
		lastRoot = nil,
		-- a summoned helper of a boss climbs out of the ground once, when it arrives (DECYZJE S117)
		riseStart = if model:GetAttribute("Summoned") == true and model:GetAttribute("Dead") ~= true
			then Clock.now()
			else nil,
		roarStart = nil,
		roarSeconds = LOOK.roarSeconds,
		flying = model:GetAttribute("Flying") == true,
		landedAt = nil,
		phase = tonumber(model:GetAttribute("Phase")) or 1,
		connection = nil,
	}
	local bossDef = if s.bossId then BossMotions.get(s.bossId) else nil
	s.deathStyle = if bossDef then bossDef.death.style elseif plan then MonsterMotions.deathFor(plan) else nil
	s.connection = model.AttributeChanged:Connect(function(name: string)
		onAttribute(s, name)
	end)
	monsters[model] = s
	refresh(model)
	if s.riseStart then
		riseFx(s)
	end
end

local function untrack(model: Model)
	local s = monsters[model]
	if s and s.connection then
		s.connection:Disconnect()
	end
	monsters[model] = nil
	animated[model] = nil
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

-- S117: the push of the last blow in the root's frame (Gait.hitLean): unit, bosses Config.MonsterLook.bossHitScale;
-- 0, 0 without a direction. A gather's CHARGE_HIT scales motion.hit only (Gait.hitLean multiplies the two).
local function hitPush(s: MonsterState): (number, number)
	local dir = s.hitDir
	if not dir then
		return 0, 0
	end
	local into = s.root.CFrame:VectorToObjectSpace(dir)
	local k = if s.bossId then LOOK.bossHitScale else 1
	return into.X * k, into.Z * k
end

-- S117: Grimrok's leap: the body flies the last leapArc s of the windup along an arc to the area (root frame), stays
-- there until the server's teleport moves the root (then the arc ends at once), else returns after LEAP_WAIT.
local function leapOffset(s: MonsterState, now: number): Vector3?
	local leap = s.leap
	if not leap then
		return nil
	end
	local t = now - s.attackStart
	local w = s.attackWindup
	local fly = math.min(LOOK.leapArc, w)
	if t < w - fly then
		return nil
	end
	local target = leap.offset
	if t <= w then
		local x, y, z = Gait.leapArc((t - (w - fly)) / fly, { 0, 0, 0 }, { target.X, target.Y, target.Z }, leap.height)
		return Vector3.new(x, y, z)
	end
	local back = (t - w - LEAP_WAIT) / LEAP_BACK
	if back >= 1 then
		s.leap = nil
		return nil
	end
	return target * (1 - math.clamp(back, 0, 1))
end

-- S117: the roar envelope now (an attack started after the roar makes it give way within ROAR_YIELD s).
local function roarOf(s: MonsterState, now: number): number
	local start = s.roarStart
	if not start then
		return 0
	end
	local value = Gait.roarEnvelope(now - start, s.roarSeconds)
	if value <= 0 and now - start >= s.roarSeconds then
		s.roarStart = nil
		return 0
	end
	if s.attackStart > start then
		value *= math.max(0, 1 - (now - s.attackStart) / ROAR_YIELD)
	end
	return value
end

-- S117: how much a dragon is in the air: 1 while Flying and LAND_WIDE s after it, then down over LAND_FADE s.
local function flyingOf(s: MonsterState, now: number): number
	if s.flying then
		return 1
	end
	local landed = s.landedAt
	if not landed then
		return 0
	end
	local t = now - landed - LAND_WIDE
	if t >= LAND_FADE then
		s.landedAt = nil
		return 0
	end
	return if t <= 0 then 1 else 1 - t / LAND_FADE
end

-- The generated monster's Motion this frame (the shared `motion` table).
local function monsterMotion(s: MonsterState, now: number): Gait.Motion
	clearExtra(motion)
	local elapsed = now - s.attackStart
	Gait.attackMotion(motion, elapsed, s.attackWindup, s.charged)
	local attacking = motion.raise > 0 or motion.strike > 0
	if attacking then
		motion.style = s.style
	end
	motion.cycle = s.cycle
	motion.move = s.move
	motion.time = now + s.seed
	motion.hit = math.max(0, 1 - (now - s.hitAt) / HIT_SECONDS)
	motion.dead = if s.deadAt then math.clamp((now - s.deadAt) / DEATH_SECONDS, 0, 1) else 0
	motion.plan = s.plan
	local gathering = s.charged and elapsed >= 0 and elapsed < s.attackWindup
	if gathering then
		-- D3: a hit during the gather only leans the body a little; the gather goes on
		motion.hit *= CHARGE_HIT
	end
	motion.hitX, motion.hitZ = hitPush(s)
	if s.deadAt then
		motion.deathStyle = s.deathStyle
		motion.deathSide = s.deathSide
		motion.hover = s.hover
	end
	motion.roar = roarOf(s, now)
	if s.bossId then
		local def = BossMotions.get(s.bossId)
		motion.roarStyle = if def then def.roar.style else nil
	end
	local riseStart = s.riseStart
	if riseStart then
		local t = now - riseStart
		if t >= LOOK.summonRise then
			s.riseStart = nil
		else
			motion.rise = Gait.riseOf(t, LOOK.summonRise)
		end
	end
	motion.flying = flyingOf(s, now)
	return motion
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local now = Clock.now()
	if os.clock() - pickClock >= PICK_EVERY then
		pickClock = os.clock()
		pickAnimated()
	end
	for model, s in monsters do
		if not model.Parent or not s.root.Parent then
			untrack(model)
			continue
		end
		if s.deadAt == nil and model:GetAttribute("Dead") == true then
			s.deadAt = now
		end
		-- the server's teleport of a leaping boss: the visual arc ends where the root lands
		local rootAt = s.root.Position
		if s.leap and s.lastRoot and (rootAt - s.lastRoot).Magnitude > TELEPORT_JUMP then
			s.leap = nil
		end
		s.lastRoot = rootAt
		if not animated[model] then
			continue
		end
		local velocity = s.root.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local target = math.clamp(speed / 3, 0, 1)
		local frame = Clock.dt(dt)
		s.move += (target - s.move) * math.min(1, frame * 8)
		s.cycle = Gait.advance(s.cycle, frame, speed, s.scale)
		local clips = s.clips
		if clips then
			stepClips(s, clips, now, speed)
			continue
		end

		local m = monsterMotion(s, now)
		local leap = leapOffset(s, now)
		for _, j in s.joints do
			local p = Gait.pose(j.joint, m)
			local k = j.scale
			local transform = CFrame.new(p.x * k, p.y * k, p.z * k) * CFrame.Angles(p.rx, p.ry, p.rz)
			if leap and j.body then
				transform = CFrame.new(leap) * transform
			end
			j.motor.Transform = transform
		end
	end
end

-- Starts an attack: the limbs rise for `windup` seconds and strike (S117: the blow peaks at the end of the windup).
-- With `strikeNow` (a basic attack: its event arrives with the damage) the blow peaks Gait.STRIKE_NOW_LEAD s from now.
-- S117: `attackId` (an Elite II ability or a boss attack, the "tele" event's `a`) picks the style and makes it a
-- telegraphed gather (Gait.charge) over the same clamped windup the telegraph fills over; `area` (the event's CFrame)
-- aims a boss leap. More telegraphs of one attack within SAME_ATTACK s pose it once.
function AnimationController.MonsterAttack(
	model: Model,
	windup: number?,
	strikeNow: boolean?,
	attackId: string?,
	area: CFrame?
)
	local s = monsters[model]
	if not s then
		return
	end
	local now = Clock.now()
	if attackId and s.attackId == attackId and now - s.attackStart < SAME_ATTACK then
		return
	end
	local w = if strikeNow
		then math.clamp(windup or Gait.DEFAULT_WINDUP, 0.05, 5)
		else Telegraph.windup(windup or Gait.DEFAULT_WINDUP)
	s.attackWindup = w
	-- Real models: long windups are spells and specials.
	s.attackSlot = if strikeNow then "attack1" elseif w > 1 then "cast" else "attack2"
	s.attackStart = now - (if strikeNow then math.max(0, w - Gait.STRIKE_NOW_LEAD) else 0)
	s.attackId = attackId
	s.charged = not strikeNow and attackId ~= nil
	s.leap = nil
	local bossMotion = if s.bossId and attackId then BossMotions.attack(s.bossId, attackId) else nil
	if bossMotion then
		s.style = bossMotion.style
		local arc = bossMotion.arc
		local boss = Bosses.get(s.bossId :: string)
		local leaps = false
		if boss then
			for _, attack in boss.attacks do
				if attack.id == attackId and attack.leap then
					leaps = true
				end
			end
		end
		if leaps and arc and area then
			local offset = s.root.CFrame:PointToObjectSpace(area.Position)
			s.leap = { offset = Vector3.new(offset.X, 0, offset.Z), height = arc }
		end
	elseif s.plan then
		s.style = MonsterMotions.styleFor(s.plan, s.weapon, if s.charged then attackId else nil)
	else
		s.style = nil
	end
end

-- A monster was hit; `from` (the attacker's position) gives the direction of the blow (S113: MonsterState.hitDir).
-- S117: at most one flinch per Config.MonsterLook.hitEvery s (an area hitting many times does not shake it on and on).
function AnimationController.MonsterHit(model: Model, from: Vector3?)
	local s = monsters[model]
	if s then
		local now = Clock.now()
		if now - s.flinchAt < LOOK.hitEvery then
			return
		end
		s.flinchAt = now
		s.hitAt = now
		local push = if from then s.root.Position - from else nil
		local flat = if push then Vector3.new(push.X, 0, push.Z) else nil
		s.hitDir = if flat and flat.Magnitude > 0.05 then flat.Unit else nil
	end
end

-- S117 AnimLab `boss <id> roar`: a monster roars now (the Phase attribute does the same in the game); a stage look
-- (not a world monster: AnimLab poses it itself) only gets the listeners' shake and flash.
function AnimationController.Roar(model: Model)
	local s = monsters[model]
	if s then
		startRoar(s)
		return
	end
	for _, fn in roarListeners do
		task.spawn(fn, model, bossIdOf(model))
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
		clearExtra(motion)
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
	step: number, -- S113: combo step
	start: number,
	interval: number?,
	from: AttackPose.Pose?,
	pose: AttackPose.Pose?,
	frozenAt: number?, -- S113 hitstop: the motion clock stands still since then
	clip: CharacterClips.Play?, -- S113: a real clip plays instead of the pose
}
-- S113: a hit reaction: when, the direction of the push in the character's frame, the strength (critical hits more).
type Flinch = { at: number, push: { x: number, z: number }, strength: number }

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
local R6_ELBOW_SHARE = 0.35 -- R6 has no elbows: part of the elbow bend goes to the shoulder

type SkillPlay = {
	motion: SkillMotions.Motion,
	start: number,
	loopUntil: number?,
	from: AttackPose.Pose?,
	pose: AttackPose.Pose?,
	frozenUntil: number, -- hitstop: the motion clock stands still until then
	frozenAt: number?,
	clip: CharacterClips.Play?, -- S113: a real clip plays instead of the keys
}

local rigs: { [Model]: Rig } = {}
local attacks: { [Model]: Attack } = {}
local skills: { [Model]: SkillPlay } = {}
local flinches: { [Model]: Flinch } = {}
-- S113: the last basic attack of every character as its combo remembers it (each client counts what it sees).
local combos: { [Model]: AttackPose.ComboState } = {}
-- S110 AnimLab: preview models held at a motion time (seconds from the start of their attack / skill).
local labHeld: { [Model]: number } = {}
local labWarned = false
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
		labHeld[model] = nil
		combos[model] = nil
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

-- S113: a clip track held at `t` seconds of the motion (AnimLab freeze) or playing on.
local function holdClip(play: CharacterClips.Play, t: number?)
	local track = play.track
	if t then
		track.TimePosition = math.clamp(t * play.speed, 0, math.max(0, track.Length - 1e-3))
		track:AdjustSpeed(0)
	elseif track.Speed == 0 then
		track:AdjustSpeed(play.speed)
	end
end

local function poseCharacter(model: Model, rig: Rig, now: number, ride: AttackPose.Pose?)
	-- A skill motion owns its joints; the basic attack the rest of the arms (S28).
	local skillPose: AttackPose.Pose? = nil
	local skillWeight = 0
	local skillClip = false
	local play = skills[model]
	local hold = labHeld[model] -- S110: AnimLab holds this model at a fixed motion time
	if play then
		local clip = play.clip
		if clip then
			-- S113: a real clip owns the arms while its track plays
			if hold then
				holdClip(clip, hold)
			end
			if clip.track.IsPlaying then
				skillClip = true
			elseif not hold then
				skills[model] = nil
			end
		else
			local t = hold or (play.frozenAt or now) - play.start
			local p, w, done = SkillPose.sample(play.motion, t, { from = play.from, loopUntil = play.loopUntil })
			if done then
				if not hold then
					skills[model] = nil
				end
			else
				skillPose, skillWeight = p, w
				play.pose = p
			end
		end
	end
	local attack = attacks[model]
	local pose: AttackPose.Pose? = nil
	local weight = 0
	local attackClip = false
	if attack then
		local clip = attack.clip
		if clip then
			if hold then
				holdClip(clip, hold)
			end
			if clip.track.IsPlaying then
				attackClip = true
			elseif not hold then
				attacks[model] = nil
			end
		else
			local t = hold or (attack.frozenAt or now) - attack.start
			local p, phase, w = AttackPose.sample(attack.motion, t, attack.interval, attack.from, attack.step)
			if phase == "rest" then
				if not hold then
					attacks[model] = nil
				end
			else
				pose, weight = p, w
				attack.pose = p
			end
		end
	end
	-- S113: the hit reaction leans away from the blow (AnimLab: sampled at the held time)
	local flinch = flinches[model]
	local flinchPose: AttackPose.Pose? = nil
	if flinch then
		local t = hold or (now - flinch.at)
		if t >= AttackMotions.FLINCH.seconds then
			if not hold then
				flinches[model] = nil
			end
		else
			flinchPose = AttackPose.flinch(flinch.push, flinch.strength, t)
		end
	end
	local busy = pose ~= nil or skillPose ~= nil or attackClip or skillClip
	if not busy and not flinchPose and not ride then
		release(rig)
		return
	end
	for joint, ref in rig.joints do
		local fromSkill = skillPose and skillPose[joint]
		-- S96: the rider's legs and body lift (a skill dismounts, so the two meet only for a frame)
		local fromRide = if ride and not fromSkill and table.find(RiderPose.JOINTS, joint) then ride[joint] else nil
		local a = fromSkill or fromRide or (if pose then pose[joint] else nil)
		local isAttackJoint = table.find(ATTACK_JOINTS, joint) ~= nil
		-- the flinch of this joint: the waist always, the shoulders only while nothing else poses the arms
		local f = flinchPose and flinchPose[joint]
		if f and joint ~= "waist" and busy then
			f = nil
		end
		local own: number
		if fromSkill then
			own = if joint == "waist" then skillWeight * 0.85 else skillWeight
		elseif fromRide then
			own = 1
		elseif isAttackJoint and pose then
			own = if joint == "waist" then weight * 0.6 else weight
		elseif f then
			own = 0 -- on top of the default animation (or of a clip)
		else
			continue -- not moved by anything now (legs and root outside skill motions; arms under a clip)
		end
		if (attackClip or skillClip) and isAttackJoint and not fromSkill and not f then
			continue -- S113: the clip's track poses these joints
		end
		local q = if a then jointTransform(joint, a, ref, rig.r6, skillPose or pose) else CFrame.identity
		if f then
			q = jointTransform(joint, f, ref, rig.r6, nil) * q
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

local function dropClips(model: Model)
	local attack = attacks[model]
	if attack and attack.clip then
		attack.clip.stop(0.1)
	end
	local play = skills[model]
	if play and play.clip then
		play.clip.stop(0.1)
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
			dropClips(model)
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

-- Whether a character is near enough to animate (Config.EffectRadius; AnimLab and preview copies always).
local function nearCamera(model: Model): boolean
	if model:GetAttribute("VaelthornPreview") == true then
		return true
	end
	local camera = Workspace.CurrentCamera
	local root = model:FindFirstChild("HumanoidRootPart")
	if not camera or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - camera.CFrame.Position).Magnitude <= Config.EffectRadius
end

-- Plays the basic attack of `weaponType` (Items type, nil = fists) on a character. A running attack is
-- interrupted smoothly (the new one starts from the pose the old one had reached). Returns the timing (when
-- the blow lands / the shot leaves) even when the character is too far away to animate, and whether a real clip
-- plays. S113: the combo step follows the previous attack within AttackMotions.COMBO_WINDOW (`step` forces one,
-- AnimLab); `onHit` runs exactly once at the server's hit time: the clip's "Hit" marker, else Vfx/Clock after
-- timing.hitAt (AnimLab freezes it). A step's hitstop holds the pose there for a moment.
function AnimationController.Attack(
	model: Model,
	weaponType: string?,
	interval: number?,
	onHit: (() -> ())?,
	step: number?
): (AttackPose.Timing, boolean)
	local motion = AttackPose.motionFor(weaponType)
	local now = os.clock()
	local count = AttackPose.stepCount(motion, weaponType)
	local chosen = step or AttackPose.nextStep(combos[model], motion, now, count)
	combos[model] = { motion = motion, step = chosen, at = now }
	local timing = AttackPose.timing(motion, interval, chosen)
	local stepDef = AttackPose.step(motion, chosen)
	local rig = rigOf(model)
	local running = attacks[model]
	if running and running.clip then
		running.clip.stop(0.08)
	end
	local play: CharacterClips.Play? = nil
	if rig and not rig.r6 and nearCamera(model) then
		local clip = ClipFit.attackClip(weaponType, chosen)
		if clip then
			play = CharacterClips.play(model, clip, timing.hitAt, Enum.AnimationPriority.Action, onHit)
		end
	end
	if rig then
		attacks[model] = {
			motion = motion,
			step = chosen,
			start = now,
			interval = interval,
			from = if running and not running.clip then running.pose else nil,
			pose = nil,
			frozenAt = nil,
			clip = play,
		}
	end
	if not play then
		local hitstop = stepDef.hitstop
		Clock.after(timing.hitAt, function()
			if hitstop and rig and attacks[model] and attacks[model].start == now then
				AnimationController.Hitstop(model, hitstop)
			end
			if onHit then
				onHit()
			end
		end)
	end
	return timing, play ~= nil
end

-- Plays a skill's motion on a character (S28). `loopUntil`: seconds a channel lasts (its loop repeats till then).
-- Returns the motion (nil when the skill has none) so callers can time effects on its events. S113: a skill with a
-- real clip (SkillMotions `clip`, never with `loop`) plays it when it loaded, fitted to SkillMotions.hitDelay.
-- S114: `ctx` (waves `hits` and walking `move` of the cast event) and the family of the model's weapon (attribute
-- "WeaponType" of VaelthornWeapon, AttackMotions.byWeapon) pick a variant (SkillPose.pick); the returned motion is the
-- one that plays. A clip plays only when no variant was picked (a variant is always procedural).
function AnimationController.Skill(
	model: Model,
	skillId: string,
	loopUntil: number?,
	ctx: { hits: number?, move: boolean? }?
): SkillMotions.Motion?
	local base = SkillMotions.get(skillId)
	if not base then
		return nil
	end
	local motion = base
	if base.variants then
		local weapon = model:FindFirstChild("VaelthornWeapon")
		local weaponType = if weapon then weapon:GetAttribute("WeaponType") else nil
		motion = SkillPose.pick(base, {
			weapon = if type(weaponType) == "string" then AttackMotions.byWeapon[weaponType] else nil,
			hits = ctx and ctx.hits,
			move = ctx and ctx.move,
		})
	end
	if monsters[model] then
		AnimationController.MonsterAttack(model, nil, true)
		return motion
	end
	local rig = rigOf(model)
	if not rig then
		return motion
	end
	local running = skills[model]
	local attack = attacks[model]
	if running and running.clip then
		running.clip.stop(0.08)
	end
	if attack and attack.clip then
		attack.clip.stop(0.08)
	end
	local play: CharacterClips.Play? = nil
	local clip = if motion == base then motion.clip else nil
	if clip and not motion.loop and not rig.r6 and nearCamera(model) then
		play = CharacterClips.play(
			model,
			ClipFit.normalize(clip),
			SkillMotions.hitDelay(skillId),
			Enum.AnimationPriority.Action2,
			nil
		)
	end
	-- A skill takes over from the basic attack, starting from the pose it reached.
	attacks[model] = nil
	skills[model] = {
		motion = motion,
		start = os.clock(),
		loopUntil = loopUntil,
		from = if running and not running.clip
			then running.pose
			elseif attack and not attack.clip then attack.pose
			else nil,
		pose = nil,
		frozenUntil = 0,
		frozenAt = nil,
		clip = play,
	}
	return motion
end

-- Stops a skill motion at once (stun, death, interrupted channel); the joints go back to the default animation.
function AnimationController.StopSkill(model: Model)
	local play = skills[model]
	if play then
		if play.clip then
			play.clip.stop(0.1)
		end
		skills[model] = nil
		local rig = rigs[model]
		if rig then
			release(rig)
		end
	end
end

-- Hitstop (S28): the skill motion of `model` (and a monster's attack) stands still for `seconds`. S113: also the basic
-- attack (its pose, or its clip's track) and a skill's clip.
function AnimationController.Hitstop(model: Model, seconds: number)
	local play = skills[model]
	local now = os.clock()
	if play and not play.frozenAt then
		play.frozenAt = now
		local clip = play.clip
		if clip then
			clip.track:AdjustSpeed(0)
		end
		task.delay(seconds, function()
			if skills[model] == play and play.frozenAt then
				play.start += os.clock() - (play.frozenAt :: number)
				play.frozenAt = nil
				if clip and labHeld[model] == nil then
					clip.track:AdjustSpeed(clip.speed)
				end
			end
		end)
	end
	local attack = attacks[model]
	if attack and not attack.frozenAt and not play then
		attack.frozenAt = now
		local clip = attack.clip
		if clip then
			clip.track:AdjustSpeed(0)
		end
		task.delay(seconds, function()
			if attacks[model] == attack and attack.frozenAt then
				attack.start += os.clock() - (attack.frozenAt :: number)
				attack.frozenAt = nil
				if clip and labHeld[model] == nil then
					clip.track:AdjustSpeed(clip.speed)
				end
			end
		end)
	end
	local s = monsters[model]
	if s then
		-- S117 (D3): a telegraphed gather never moves (the server deals its damage on time); a basic attack does
		local clock = Clock.now()
		local gathering = s.charged and clock - s.attackStart < s.attackWindup
		if not gathering then
			s.attackStart += seconds
		end
		s.hitAt = clock
	end
end

-- Whether a character is playing a skill motion that holds it still (S28 `lock`).
function AnimationController.SkillLock(model: Model): boolean
	local play = skills[model]
	return play ~= nil and play.motion.lock == true
end

-- A short lean of the upper body away from the blow when a character is hit (S113): `from` is the attacker's
-- position (nil: pushed straight back), `crit` a stronger lean (AttackPose.flinch).
function AnimationController.CharacterHit(model: Model, from: Vector3?, crit: boolean?)
	if not rigOf(model) then
		return
	end
	local push = { x = 0, z = 1 }
	local root = model:FindFirstChild("HumanoidRootPart")
	if from and root and root:IsA("BasePart") then
		local world = root.Position - from
		local flat = Vector3.new(world.X, 0, world.Z)
		if flat.Magnitude > 0.05 then
			local localDir = root.CFrame:VectorToObjectSpace(flat.Unit)
			local planar = Vector3.new(localDir.X, 0, localDir.Z)
			if planar.Magnitude > 0.05 then
				planar = planar.Unit
				push = { x = planar.X, z = planar.Z }
			end
		end
	end
	flinches[model] = { at = os.clock(), push = push, strength = AttackPose.flinchStrength(crit) }
end

-- S110 AnimLab: holds the attack and the skill motion of a preview model (attribute VaelthornPreview) at `t` seconds
-- from their start, also past their end; nil lets them play on from there (their start moves by the time held).
-- S113: a clip track is held through its TimePosition, a flinch at the same t.
function AnimationController.LabHold(model: Model, t: number?)
	if model:GetAttribute("VaelthornPreview") ~= true then
		if not labWarned then
			labWarned = true
			warn("[AnimationController] LabHold works only on preview models (VaelthornPreview)")
		end
		return
	end
	if t then
		labHeld[model] = math.max(0, t)
		rigOf(model)
		return
	end
	local held = labHeld[model]
	labHeld[model] = nil
	if held then
		local now = os.clock()
		local attack = attacks[model]
		if attack then
			attack.start = now - held
			attack.frozenAt = nil
			if attack.clip then
				holdClip(attack.clip, nil)
			end
		end
		local play = skills[model]
		if play then
			play.start = now - held
			play.frozenAt = nil
			if play.clip then
				holdClip(play.clip, nil)
			end
		end
		local flinch = flinches[model]
		if flinch then
			flinch.at = now - held
		end
	end
end

-- S110 AnimLab: drops every motion of a preview model and gives its joints back to the default animation.
function AnimationController.LabClear(model: Model)
	dropClips(model)
	labHeld[model] = nil
	attacks[model] = nil
	skills[model] = nil
	flinches[model] = nil
	local rig = rigs[model]
	if rig then
		release(rig)
	end
end

-- S113 AnimLab: forgets a model's combo, so its next attack is step 1.
function AnimationController.ResetCombo(model: Model)
	combos[model] = nil
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
	-- S113: an Animation object for every clip id in the data (none until the owner adds clips)
	local skillClips: { [string]: ClipFit.Clip } = {}
	for id, m in SkillMotions.motions do
		if m.clip then
			skillClips[id] = m.clip
		end
	end
	CharacterClips.preload(ClipFit.allIds(skillClips))
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
		if child:IsA("Model") then
			untrack(child)
		end
	end)
end

return AnimationController
