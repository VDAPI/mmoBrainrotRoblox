--!strict
-- One monster: model, stats, threat table and AI (DESIGN §15.1).
--   idle   : wander within Combat.wanderRadius of the group centre, look for players in aggro range; out of
--            combat it slowly regains HP (S22, Logic/Leash.regen)
--   chase  : follow the highest-threat valid target; goes home by Logic/Leash.shouldReturn (S22: soft leash
--            while nobody hits the group, hard leash, lost target); S162e: evades when it cannot reach its target
--   cast   : Elite II special: telegraph for `windup` seconds, then resolve. S134c: a world event commander also has
--            extra abilities (SetExtraAbilities: big blows to dodge and a shared blow, the bosses 2.0 telegraph and
--            resolve options of Logic/BossMechanics). S134e: an Elite / Elite II has a kit (Data/MonsterAbilities.KITS:
--            Crushing Blow, Pounce, the throw at a fleeing target; Heavy Blow), picked by Logic/MonsterCast
--            together with its own ability; a target-centred area is frozen on the ground under the target
--   return : walk back to the group centre (S22: no healing, no invulnerability; a hit within the hard leash
--            turns it back into the fight), then to its own spot and idle. Bosses keep the old return: their
--            arena centre, full HP and invulnerable on the way. S162e evade (`evading`): the same walk home, but
--            immune, at full HP, with its damage record cleared, and no aggro by sight for a while once home.
--   dead   : waiting for MonsterService to remove the model
-- Chasing and going home steer around obstacles (FIX 2026-10-09, Logic/Steer): two short rays (step and hip
-- height) probe the way ahead; a blocked way takes the first clear angle to one side and keeps that side a while.
-- S162e (owner's tester 2026-10-31: monsters stuck on rocks, trees, houses and ledges were cheesed with ranged
-- attacks; Logic/Pursuit): while two long rays say the straight way to the goal is blocked, the monster asks
-- PathfindingService for a path (its agent size from its body, within the server's budget, at most every
-- Combat.pathGap seconds) and walks its points; no progress towards where it walks for Combat.pursuitRepath s = a new
-- path; no path, or still no progress after Combat.pursuitEvade s, while its blow, shot or throw cannot reach the
-- target = it evades (bosses and their helpers never do). The low probe ray sits at Pursuit.stepHeight: what lies
-- lower is walked over (only the root collides), so a monster no longer turns at small ledges.
-- S162m (owner 2026-10-25, docs/ANIM-WZORCE §9; Logic/MonsterMove): a walk while idle, a trot home, a run in the fight
-- (the "Gait" attribute); a melee monster walks on to meleeApproach x its reach; an ability with `dash` really travels
-- (Dash* attributes); "SpawnedAt" = server time of the spawn (the clients' appear animation).
-- Damage resolution, telegraphs and rewards are delegated to the Context given by MonsterService, so this
-- module never talks to other services directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AreaProfiles = require(Shared.Data.AreaProfiles)
local BasicBlow = require(Shared.Logic.BasicBlow)
local BossMechanics = require(Shared.Logic.BossMechanics)
local ChaseTest = require(Shared.Logic.ChaseTest)
local Combat = require(Shared.Data.Combat)
local Leash = require(Shared.Logic.Leash)
local LevelLock = require(Shared.Logic.LevelLock)
local MonsterAbilities = require(Shared.Data.MonsterAbilities)
local MonsterCast = require(Shared.Logic.MonsterCast)
local MonsterMove = require(Shared.Logic.MonsterMove)
local MonsterStats = require(Shared.Logic.MonsterStats)
local PathWorker = require(script.Parent.PathWorker)
local Monsters = require(Shared.Data.Monsters)
local Pursuit = require(Shared.Logic.Pursuit)
local RigBuilder = require(script.Parent.RigBuilder)
local Steer = require(Shared.Logic.Steer)
local Traits = require(Shared.Logic.Traits)

export type State = "idle" | "chase" | "cast" | "return" | "dead"

export type Context = {
	findPlayers: (position: Vector3, radius: number) -> { Player },
	playerPosition: (player: Player) -> Vector3?,
	playerLevel: (player: Player) -> number,
	-- Alive, in the world and not standing in a safe (green) zone.
	canTarget: (monster: any, player: Player) -> boolean,
	isSafePosition: (position: Vector3) -> boolean,
	basicAttack: (monster: any, player: Player) -> (),
	-- S134c: `opts` = CombatService.TelegraphOpts / ResolveOpts (the bosses 2.0 mechanics of extra abilities)
	telegraph: (monster: any, ability: MonsterAbilities.Ability, area: CFrame, opts: any?) -> (),
	resolveAbility: (monster: any, ability: MonsterAbilities.Ability, area: CFrame, opts: any?) -> (),
	died: (monster: any) -> (),
	moved: (monster: any) -> (),
	-- Status effects (StatusEffectService): stunned/frozen monsters do nothing, rooted ones cannot move,
	-- a taunting player overrides the threat table.
	isDisabled: (monster: any) -> boolean,
	isRooted: (monster: any) -> boolean,
	taunter: (monster: any) -> Player?,
	-- A player newly joined the monster's threat list (S19: the rest of the group joins the fight).
	engaged: ((monster: any, player: Player) -> ())?,
	-- Most recent time (os.clock) a player hit any monster of this one's group (S22: the group shares the leash
	-- and the regeneration delay); nil = only the monster's own hits count.
	groupLastHit: ((monster: any) -> number)?,
	attackSlow: ((monster: any) -> number)?, -- % attack slow from status effects (enemyAttackSlow, S63)
	-- S72 (ROZWOJ 10.3, Menace): threat multiplier of a player's damage (the threat hook); nil = 1. Kill credit
	-- (damageBy) never uses it.
	threatMultiplier: ((monster: any, player: Player) -> number)?,
	-- S134c: ground below a point (a "random" ability lands on the chosen fighter's ground, not the caster's).
	-- S134e: also a "target" one (the target's ground: on a slope the caster's height missed it).
	groundAt: ((position: Vector3) -> Vector3)?,
	-- S134e: the kit's throw at a fleeing target (a regular ranged blow, CombatService.monsterHitsPlayer)
	rangedThrow: ((monster: any, player: Player, params: any) -> ())?,
	-- S134f: a player's damage was booked in damageBy (CombatService.MonsterDamaged, the fight meter).
	damaged: ((monster: any, player: Player, dealt: number) -> ())?,
	-- S159: a regular blow winds up (the clients pose the draw; CombatService.MonsterWindup); S159a `shot` says what
	-- (melee / arrow / bolt / throw) for the draw's pose
	attackWind: ((monster: any, player: Player, seconds: number, shot: string?) -> ())?,
	-- S162e: the monster evades (its target cannot be reached): debuffs off, the clients show "Evade" over it to
	-- `player` (the target it gave up on)
	evaded: ((monster: any, player: Player?) -> ())?,
}

local Monster = {}
Monster.__index = Monster

local windUp: (self: any, target: Player) -> ()

export type Monster = typeof(setmetatable(
	{} :: {
		def: Monsters.MonsterDef,
		variant: MonsterStats.Variant,
		stats: MonsterStats.MonsterStats,
		hp: number,
		model: Model,
		root: BasePart,
		humanoid: Humanoid,
		spawnCFrame: CFrame,
		ctx: Context,
		state: State,
		target: Player?,
		threat: { [Player]: number },
		damageBy: { [Player]: number },
		invulnerable: boolean,
		nextAttack: number,
		nextAbility: number,
		nextWander: number,
		castEnd: number,
		castArea: CFrame?,
		ability: MonsterAbilities.Ability?,
		-- S134c: the ability being cast (own or extra) and the extra abilities of a world event commander: list order
		-- = priority (its own ability last), each with its own ready time, a gap after every cast (`extraGap`), the
		-- fighters the random ones aim at and the shared blow hits when nobody stands in it, and a hook on each cast
		castAbility: MonsterAbilities.Ability?,
		extra: { MonsterAbilities.Ability }?,
		extraNext: { [string]: number },
		extraGap: number,
		nextGlobal: number,
		fighters: (() -> { Player })?,
		onCast: ((ability: MonsterAbilities.Ability, area: CFrame) -> ())?,
		-- S134e: the kit (nil = none), its abilities' ready times, when the last ability landed, since when the target
		-- is out of reach (0 = in reach) and the next throw
		kit: MonsterAbilities.Kit?,
		kitNext: { [string]: number },
		lastCast: number,
		outOfReachSince: number,
		nextThrow: number,
		-- S159: the regular blow being wound up: a token that a stun or a cast cancels
		windToken: number,
		returnStarted: number,
		random: Random,
		entity: any, -- EntityService entity (set by MonsterService)
		spawnerId: string?,
		damageOverride: number?,
		speedFactor: number,
		-- Bosses: own leash range (arena) and no rewards through CombatService.
		leashRange: number?,
		-- S134d: an Invasion zone monster's hard leash from its home (keeps it inside the zone; nil = Combat.leashMax)
		leashHard: number?,
		-- S160: an Invasion zone monster's own target pick (any player inside the zone, shared out among the zone's
		-- monsters; WorldEventService); nil = the usual aggro by range and level
		aggroPicker: ((any) -> Player?)?,
		-- S134d: EXP of its kill x this (CombatService; the Invasion zone's monsters), nil = 1
		expMul: number?,
		-- Centre of the monster's group (S19): wander and leash around it instead of the own spawn point.
		home: Vector3?,
		isBoss: boolean?,
		-- S149: a world boss walks home at its current HP and stays hittable (the party may regroup in the open)
		keepHp: boolean?,
		-- Boss helpers (2026-10-10): no items and no gold when they die.
		summoned: boolean?,
		-- S149: the world boss's helpers: no EXP either (CombatService gives nothing)
		noReward: boolean?,
		-- S32: highest level of the monster's spawner (drops never get a higher item level).
		levelCap: number?,
		-- S157 (Logic/LevelLock): the highest player level that may fight this monster (nil = everyone).
		capLevel: number?,
		-- S22 leash: last hit by a player.
		lastHit: number,
		-- S72: the player whose damage brought HP to 0; nil for the environment.
		killedBy: Player?,
		lastStep: number,
		-- S162e (Logic/Pursuit): the last progress towards where it walks (os.clock), the studs gained since, the root's
		-- position at the last tick and the point it walked to (the goal or the path's next point)
		progressAt: number,
		progressAcc: number,
		lastPos: Vector3,
		walkGoal: Vector3?,
		-- S162e: the path (PathfindingService points, the next one, the goal it leads to), whether one is being computed,
		-- when the last one was asked, when an answer last found no way (0 = never) and a token that drops late answers
		path: { Vector3 }?,
		pathIndex: number,
		pathGoal: Vector3?,
		pathPending: boolean,
		pathAskedAt: number,
		pathFailedAt: number,
		pathToken: number,
		pathSticky: boolean, -- keep to the path even where the way looks clear (a stalled monster's new path)
		-- path answers in a row with no way (Combat.pathFailEvade of them = evade), since a path found or a blow in reach
		pathFailStreak: number,
		-- S162e: evading (immune, going home) and until when it ignores players by sight after an evade (os.clock)
		evading: boolean,
		calmUntil: number,
		-- S162e: the admin chase test's record (Logic/ChaseTest; /chasetest), nil on every other monster
		probe: ChaseTest.Probe?,
		-- Obstacle steering: the side of the current detour (-1, 0, 1) and until when it is kept.
		detourSide: number,
		detourUntil: number,
		-- S101: patrol route (world event champion): waypoints, the current one, rest until (0 = walking), the rest
		-- on each waypoint and the next MoveTo while walking. `home` = the champion's own position while walking (the
		-- leash and the return point at the spot where a fight starts), the waypoint while resting.
		patrol: { Vector3 }?,
		patrolIndex: number,
		patrolWaitUntil: number,
		patrolPause: number,
		nextPatrolMove: number,
		-- S162m: the pace mirrored as "Gait"; a cast's token (a stun or a new cast drops its dash); the running dash's
		-- speed and until when it runs (os.clock, 0 = none); whether Dash* attributes announce a flight now
		gait: MonsterMove.Gait,
		castToken: number,
		dashSpeed: number,
		dashUntil: number,
		dashOn: boolean,
	},
	Monster
))

function Monster.new(
	def: Monsters.MonsterDef,
	variant: MonsterStats.Variant,
	level: number,
	spawnCFrame: CFrame,
	ctx: Context,
	parent: Instance,
	attributes: { [string]: any }?,
	extraMods: MonsterStats.Mods?
): Monster
	-- S32: members of bigger groups hit softer (Combat.groupDamageMul). S33: the area profile's HP and attack.
	-- S101: `extraMods` (world event commander / champion) multiply the profile's.
	local groupSize = attributes and (attributes :: any).GroupSize
	local areaId = attributes and (attributes :: any).AreaId
	local profile = AreaProfiles.ofArea(if type(areaId) == "string" then areaId else nil)
	local mods: MonsterStats.Mods? = profile
	if extraMods then
		mods = {
			hpMul = (if profile then profile.hpMul else 1) * (extraMods.hpMul or 1),
			atkMul = (if profile then profile.atkMul else 1) * (extraMods.atkMul or 1),
		}
	end
	local stats =
		MonsterStats.compute(def, level, variant, if type(groupSize) == "number" then groupSize else nil, mods)
	local model = RigBuilder.build(def, variant, stats.scale)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	model:SetAttribute("MonsterId", def.id)
	model:SetAttribute("Variant", variant)
	model:SetAttribute("NameKey", (def.nameKeys :: any)[variant] or def.nameKeys.normal)
	model:SetAttribute("Level", stats.level)
	if profile then
		model:SetAttribute("AreaProfile", profile.id) -- S33: the target plate shows the profile's icon
	end
	model:SetAttribute("MaxHp", stats.maxHp)
	model:SetAttribute("Hp", stats.maxHp)
	-- S162m: the spawn's server time (Workspace:GetServerTimeNow, the clients' clock too) for the appear animation, and
	-- the idle pace (Logic/MonsterMove)
	model:SetAttribute("SpawnedAt", Workspace:GetServerTimeNow())
	model:SetAttribute("Gait", MonsterMove.gaitOf("idle"))
	humanoid.WalkSpeed = def.moveSpeed * MonsterMove.speedMul(MonsterMove.gaitOf("idle"), Combat :: any)
	model:PivotTo(spawnCFrame + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	-- Group attributes (GroupId, GroupSize) must be there before the model replicates.
	for name, value in (attributes or {}) :: { [string]: any } do
		model:SetAttribute(name, value)
	end
	model.Parent = parent
	root:SetNetworkOwner(nil)

	local ability = if variant == "elite2" and def.ability then MonsterAbilities.get(def.ability) else nil

	local self = setmetatable({
		def = def,
		variant = variant,
		stats = stats,
		hp = stats.maxHp,
		model = model,
		root = root,
		humanoid = humanoid,
		spawnCFrame = spawnCFrame,
		ctx = ctx,
		state = "idle" :: State,
		target = nil,
		threat = {},
		damageBy = {},
		invulnerable = false,
		nextAttack = 0,
		nextAbility = 0,
		nextWander = os.clock() + math.random() * 4,
		castEnd = 0,
		castArea = nil,
		ability = ability,
		castAbility = nil,
		extra = nil,
		extraNext = {},
		extraGap = 0,
		nextGlobal = 0,
		fighters = nil,
		onCast = nil,
		kit = MonsterAbilities.kit(variant),
		kitNext = {},
		lastCast = -math.huge,
		outOfReachSince = 0,
		nextThrow = 0,
		windToken = 0,
		returnStarted = 0,
		random = Random.new(),
		entity = nil,
		spawnerId = nil,
		damageOverride = nil,
		speedFactor = 1,
		leashRange = nil,
		leashHard = nil,
		aggroPicker = nil,
		expMul = nil,
		home = nil,
		isBoss = nil,
		keepHp = nil,
		summoned = nil,
		noReward = nil,
		levelCap = nil,
		capLevel = nil,
		lastHit = 0,
		lastStep = os.clock(),
		progressAt = 0,
		progressAcc = 0,
		lastPos = spawnCFrame.Position,
		walkGoal = nil,
		path = nil,
		pathIndex = 1,
		pathGoal = nil,
		pathPending = false,
		pathAskedAt = -math.huge,
		pathFailedAt = 0,
		pathToken = 0,
		pathSticky = false,
		pathFailStreak = 0,
		evading = false,
		calmUntil = 0,
		probe = nil,
		detourSide = 0,
		detourUntil = 0,
		patrol = nil,
		patrolIndex = 1,
		patrolWaitUntil = 0,
		patrolPause = 0,
		nextPatrolMove = 0,
		gait = MonsterMove.gaitOf("idle"),
		castToken = 0,
		dashSpeed = 0,
		dashUntil = 0,
		dashOn = false,
	}, Monster)
	return self
end

function Monster.IsAlive(self: Monster): boolean
	return self.state ~= "dead"
end

function Monster.Position(self: Monster): Vector3
	return self.root.Position
end

function Monster.Name(self: Monster): string
	return (self.def.nameKeys :: any)[self.variant] or self.def.nameKeys.normal
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distanceFlat(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
end

-- Wander / leash centre: the group centre, or the own spawn point.
local function homeOf(self: Monster): Vector3
	return self.home or self.spawnCFrame.Position
end

local function setHp(self: Monster, hp: number)
	self.hp = math.clamp(hp, 0, self.stats.maxHp)
	self.model:SetAttribute("Hp", math.ceil(self.hp))
end

local function face(self: Monster, position: Vector3)
	local from = self.root.Position
	local look = Vector3.new(position.X, from.Y, position.Z)
	if (look - from).Magnitude > 0.1 then
		self.root.CFrame = CFrame.lookAt(from, look)
	end
end

-- Who the monster is fighting, mirrored as "AggroUserId" so clients can pick their next target (S16).
local function setTarget(self: Monster, player: Player?)
	if self.target ~= player then
		self.target = player
		self.outOfReachSince = 0 -- S134e: a new target is not fleeing yet
		self.model:SetAttribute("AggroUserId", if player then player.UserId else nil)
	end
end

local function stop(self: Monster)
	self.humanoid:MoveTo(self.root.Position)
end

-- S162m: WalkSpeed = moveSpeed x the pace of the state (Logic/MonsterMove: walk, trot, run) x the status factor, or a
-- running dash's own speed; the pace is mirrored as the attribute "Gait" (the clients' walk / trot / run).
local function applyPace(self: Monster)
	local gait: MonsterMove.Gait = MonsterMove.gaitOf(self.state)
	if gait ~= self.gait then
		self.gait = gait
		self.model:SetAttribute("Gait", gait)
	end
	local speed = if self.dashUntil > os.clock()
		then self.dashSpeed
		else self.def.moveSpeed * MonsterMove.speedMul(gait, Combat :: any)
	self.humanoid.WalkSpeed = speed * self.speedFactor
end

-- Rays of the steering probe ignore monsters and characters: only the world blocks the way.
local probeParams = RaycastParams.new()
probeParams.FilterType = Enum.RaycastFilterType.Exclude
probeParams.RespectCanCollide = true
probeParams.IgnoreWater = true
local probeRefresh = 0

local function refreshProbeFilter()
	local now = os.clock()
	if now - probeRefresh < 2 then
		return
	end
	probeRefresh = now
	local ignore: { Instance } = {}
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	probeParams.FilterDescendantsInstances = ignore
end

-- The ground under the root (the feet), from the hip height.
local function feetY(self: Monster): number
	return self.root.Position.Y - self.root.Size.Y / 2 - self.humanoid.HipHeight
end

-- Whether something solid (not a walkable slope) is within `reach` studs of `self` in the flat direction. S162e: the low
-- ray at Pursuit.stepHeight (was 1.5 studs for every body): a lower obstacle passes under the root.
local function probeBlocked(self: Monster, dx: number, dz: number, reach: number): boolean
	local root = self.root
	local direction = Vector3.new(dx, 0, dz) * reach
	local feet = feetY(self)
	for _, y in { feet + Pursuit.stepHeight(self.humanoid.HipHeight), root.Position.Y } do
		local hit = Workspace:Raycast(Vector3.new(root.Position.X, y, root.Position.Z), direction, probeParams)
		if hit and hit.Normal.Y < 0.6 then
			return true
		end
	end
	return false
end

-- Walks towards `goal`, around obstacles (FIX 2026-10-09: straight MoveTo got monsters stuck on rocks and trees).
local function steerTo(self: Monster, goal: Vector3)
	local from = self.root.Position
	local offset = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	local distance = offset.Magnitude
	local reach = math.min(distance, Combat.steerLookAhead + self.root.Size.Z / 2)
	if distance < 2 or reach < 1 then
		self.humanoid:MoveTo(goal)
		return
	end
	refreshProbeFilter()
	local now = os.clock()
	local prefer = if now < self.detourUntil then self.detourSide else nil
	local dx, dz, side = Steer.choose(offset.X, offset.Z, function(x, z)
		return probeBlocked(self, x, z, reach)
	end, prefer)
	if side == 0 then
		self.humanoid:MoveTo(goal)
		return
	end
	self.detourSide = side
	self.detourUntil = now + Combat.steerHold
	self.humanoid:MoveTo(from + Vector3.new(dx, 0, dz) * (reach + 2))
end

-- S162e: a player's root stands this high over the ground (R15: hip height 2 + half the root); chase goals are ground
-- points under the target.
local PLAYER_ROOT_UP = 3

-- S162e: whether the straight way to the ground point `goal` is blocked: a ray at step height and one at the root's
-- height, both rising or falling with the ground between the two ends; a hit on a walkable slope (a hill) is no block.
local function wayBlocked(self: Monster, goal: Vector3): boolean
	local from = self.root.Position
	local offset = Vector3.new(goal.X - from.X, 0, goal.Z - from.Z)
	if offset.Magnitude < 1 then
		return false
	end
	refreshProbeFilter()
	local feet = feetY(self)
	for _, up in { Pursuit.stepHeight(self.humanoid.HipHeight), from.Y - feet } do
		local start = Vector3.new(from.X, feet + up, from.Z)
		local hit = Workspace:Raycast(start, Vector3.new(goal.X, goal.Y + up, goal.Z) - start, probeParams)
		if hit and hit.Normal.Y < 0.6 then
			return true
		end
	end
	return false
end

-- S162e: whether a shot or a throw from the monster's mouth height meets nothing solid on its way to the target's root
-- (a ranged monster no longer shoots through walls and rocks).
local function sightTo(self: Monster, targetPosition: Vector3): boolean
	refreshProbeFilter()
	local root = self.root
	local muzzle = root:FindFirstChild("Muzzle")
	local y = if muzzle and muzzle:IsA("Attachment") then muzzle.WorldPosition.Y else root.Position.Y
	local from = Vector3.new(root.Position.X, y, root.Position.Z)
	return Workspace:Raycast(from, targetPosition - from, probeParams) == nil
end

-- S162e (Studio test 2026-10-31: a wolf under a target on a roof counted as in reach by the flat distance, never gave
-- up and its blows landed through 34 studs of air): whether a melee blow reaches up (or down) to a target standing on
-- the ground height `groundY` (Logic/Pursuit.meleeReaches: Combat.meleeUp, a tall body half its height; meleeDown).
local function meleeHeightOk(self: Monster, groundY: number): boolean
	local hip = self.humanoid.HipHeight
	return Pursuit.meleeReaches(groundY - feetY(self), hip + self.root.Size.Y, Combat :: any)
end

-- S162e: the ground a player stands on: the surface under the root (a jumping player still stands on the ground it left,
-- so a hop does not dodge a blow), or the root's height less PLAYER_ROOT_UP with nothing within TARGET_GROUND_PROBE.
local TARGET_GROUND_PROBE = 12
local function targetGround(targetPosition: Vector3): number
	refreshProbeFilter()
	local standing = targetPosition.Y - PLAYER_ROOT_UP
	local hit = Workspace:Raycast(targetPosition, Vector3.new(0, -TARGET_GROUND_PROBE, 0), probeParams)
	return if hit then math.min(standing, hit.Position.Y) else standing
end

-- S162e: whether the monster's blow or shot reaches a target whose root is at `targetPosition`, `flat` studs away on
-- the flat: a blow by the flat reach and the height, a shot by the reach in 3D and a clear line (`seen`, asked last).
local function reaches(self: Monster, targetPosition: Vector3, flat: number, seen: () -> boolean): boolean
	local reach = self.stats.range + self.root.Size.Z / 2
	if self.def.attack == "melee" then
		return flat <= reach and meleeHeightOk(self, targetGround(targetPosition))
	end
	return (targetPosition - self.root.Position).Magnitude <= reach and seen()
end

-- S162e: PathfindingService agents by size (Logic/Pursuit.agent rounds a body up to a few, one navmesh per size).
-- Monsters cannot jump, climb or swim (RigBuilder), so their paths neither: water costs extra and is walked only when
-- there is no other way.
local agents: { [string]: { [string]: any } } = {}
local pathBucket = Pursuit.newBucket(Combat :: any, os.clock())
local WATER_COST = 10
local WAYPOINT_SPACING = 6

local function agentOf(self: Monster): { [string]: any }
	local size = self.root.Size
	local radius, height = Pursuit.agent(size.X, size.Y, size.Z, self.humanoid.HipHeight)
	local key = `{radius}|{height}`
	local agent = agents[key]
	if not agent then
		agent = {
			AgentRadius = radius,
			AgentHeight = height,
			AgentCanJump = false,
			AgentCanClimb = false,
			WaypointSpacing = WAYPOINT_SPACING,
			Costs = { Water = WATER_COST },
		}
		agents[key] = agent
	end
	return agent
end

-- S162e: drops the path and any answer still on its way.
local function dropPath(self: Monster)
	self.path = nil
	self.pathGoal = nil
	self.pathPending = false
	self.pathSticky = false
	self.pathToken += 1
	self.pathFailStreak = 0
	PathWorker.cancel(self)
end

-- S162e: asks for a path to the ground point `goal` (queued: Entities/PathWorker calls PathfindingService outside the AI
-- tick), at most every Combat.pathGap seconds per monster and within the server's budget (Logic/Pursuit.take); a refused
-- ask is simply tried again on a later tick. A success replaces the path, "no way" is remembered as pathFailedAt and
-- counted in pathFailStreak, unless an end of the path lay within the agent's radius of a part (PathWorker.tight,
-- Studio 2026-11-01: a target with its back to a wall or a monster pressed into a fence is off the navmesh; that "no
-- way" says nothing about the way, so it does not count towards the evade, only the stall rules do).
local function requestPath(self: Monster, goal: Vector3, now: number)
	if self.pathPending or now - self.pathAskedAt < Combat.pathGap then
		return
	end
	local probe = self.probe
	if not Pursuit.take(pathBucket, now, Combat :: any) then
		if probe then
			probe.pathDenied += 1
		end
		return
	end
	if probe then
		probe.pathAsks += 1
		probe.firstAskAt = probe.firstAskAt or os.clock()
	end
	self.pathPending = true
	self.pathAskedAt = now
	self.pathToken += 1
	local token = self.pathToken
	local askedAt = os.clock()
	local agent = agentOf(self)
	local from = self.root.Position
	local feet = Vector3.new(from.X, feetY(self), from.Z)
	-- S162e (Studio 2026-10-31: a 1.7 s frame at a first path): the AI tick only queues; Entities/PathWorker calls the
	-- engine in a thread of its own, at most Combat.pathPerFrame calls per server frame
	PathWorker.request(self, {
		agent = agent,
		from = from,
		goal = goal,
		done = function(answer: PathWorker.Answer)
			local points = answer.points
			-- (in the worker's thread, not the AI tick) a "no way" with an end against a part counts for nothing
			local tight = false
			if not points then
				refreshProbeFilter()
				local ignore = probeParams.FilterDescendantsInstances
				tight = PathWorker.tight(feet, agent.AgentRadius, ignore)
					or PathWorker.tight(goal, agent.AgentRadius, ignore)
			end
			if probe then
				ChaseTest.noteAnswer(probe, askedAt, answer.waited, answer.seconds, points ~= nil, tight)
			end
			if self.pathToken ~= token or self.state == "dead" then
				return
			end
			self.pathPending = false
			if points then
				self.path = points
				self.pathIndex = 2 -- the first point is where it stood
				self.pathGoal = goal
				self.pathFailedAt = 0
				self.pathFailStreak = 0
			else
				self.path = nil
				self.pathGoal = nil
				self.pathFailedAt = os.clock()
				if not tight then
					self.pathFailStreak += 1
				end
			end
		end,
	})
end

-- S162e: walks to the path's next point: points it stands at (within a tick's walk) or has passed (the one after is
-- nearer) are skipped. Returns the point, or nil when the path is used up.
local function followPath(self: Monster): Vector3?
	local points = self.path
	if not points then
		return nil
	end
	local position = self.root.Position
	local near = math.max(2.5, self.humanoid.WalkSpeed / Combat.aiTickRate * 1.2)
	local i = self.pathIndex
	while i <= #points do
		local here = distanceFlat(position, points[i])
		local nextPoint = points[i + 1]
		if here <= near or (nextPoint and distanceFlat(position, nextPoint) <= here) then
			i += 1
		else
			break
		end
	end
	self.pathIndex = i
	local point = points[i]
	if not point then
		self.path = nil
		return nil
	end
	self.humanoid:MoveTo(point)
	return point
end

-- S162e: walks towards the ground point `goal`: straight on (steering around what the short probes find) while the
-- straight way is clear, along a path while it is blocked (asked for when there is none or its end lies
-- Combat.pathMove studs from `pathTo`; the old path leads on meanwhile). `pathTo` = where a path should end (a melee
-- chase: the target's feet, which move less than its approach point; nil = `goal`). `walkGoal` = where it walks
-- (progress counts towards it): the path's next point or the goal, never a steering detour.
local function travel(self: Monster, goal: Vector3, now: number, pathTo: Vector3?)
	if not self.pathSticky and not wayBlocked(self, goal) then
		self.walkGoal = goal
		steerTo(self, goal)
		return
	end
	local pathGoal = self.pathGoal
	local destination = pathTo or goal
	if not self.path or not pathGoal or distanceFlat(pathGoal, destination) > Combat.pathMove then
		requestPath(self, destination, now)
	end
	local point = followPath(self)
	self.walkGoal = point or goal
	if not point then
		if not self.pathPending then
			self.pathSticky = false -- no path to keep to (none found, or walked to its end)
		end
		steerTo(self, goal)
	end
end

-- S162e: a stalled monster's new path (Pursuit.decide "repath"): it keeps to that path even where the long rays see the
-- way clear (whatever stopped it, a post, a fence gap or a water edge, they missed).
local function repath(self: Monster, goal: Vector3, now: number)
	self.pathSticky = true
	local asked = self.pathAskedAt
	requestPath(self, goal, now)
	local probe = self.probe
	if probe and self.pathAskedAt ~= asked then
		probe.repaths += 1
	end
end

-- S162e: starts a fresh progress record (a new chase, the way home, after a stun or a cast).
local function resetProgress(self: Monster, now: number)
	self.progressAt = now
	self.progressAcc = 0
	self.lastPos = self.root.Position
end

-- S162e (Logic/Pursuit): books the last tick's walk towards `walkGoal` and decides: chase on, a new path, or give up.
-- Standing where it can hit (or held by a root) is progress.
local function notePursuit(self: Monster, now: number, canHit: boolean, mayEvade: boolean): Pursuit.Action
	local position = self.root.Position
	local last = self.lastPos
	local goal = self.walkGoal
	self.lastPos = position
	if canHit or goal == nil or self.ctx.isRooted(self) then
		self.progressAt = now
		self.progressAcc = 0
		if canHit then
			self.pathFailStreak = 0
		end
		return "chase"
	end
	local advance = Pursuit.advance(last.X, last.Z, position.X, position.Z, goal.X, goal.Z)
	local acc, progressed = Pursuit.track(self.progressAcc, advance, Combat :: any)
	self.progressAcc = acc
	if progressed then
		self.progressAt = now
	end
	return Pursuit.decide({
		stalled = now - self.progressAt,
		canHit = false,
		asked = self.pathAskedAt > self.progressAt,
		pending = self.pathPending,
		noPath = self.pathFailedAt > self.progressAt,
		failStreak = self.pathFailStreak,
		mayEvade = mayEvade,
	}, Combat :: any)
end

-- Applies the slow/root factor from status effects (1 = normal speed).
function Monster.RefreshSpeed(self: Monster, factor: number)
	self.speedFactor = factor
	applyPace(self)
	if factor <= 0 then
		stop(self)
	end
end

-- Where a returning monster walks to: the group centre (S22), or the own spawn point (bosses, lone monsters).
local function returnPoint(self: Monster): Vector3
	return if self.isBoss then self.spawnCFrame.Position else homeOf(self)
end

local function sinceHit(self: Monster, now: number): number
	local last = self.lastHit
	local group = self.ctx.groupLastHit
	if group then
		last = math.max(last, group(self))
	end
	return now - last
end

function Monster.StartReturn(self: Monster)
	self.state = "return"
	setTarget(self, nil)
	table.clear(self.threat)
	if self.isBoss and not self.keepHp then
		-- Bosses (arena leash 400) keep the old return: full HP and invulnerable on the way (S149: not a world boss).
		self.invulnerable = true
		table.clear(self.damageBy)
		setHp(self, self.stats.maxHp)
	end
	self.model:SetAttribute("Returning", true)
	applyPace(self)
	self.returnStarted = os.clock()
	-- S162e: a fresh way home (the chase's path led to its target)
	dropPath(self)
	resetProgress(self, self.returnStarted)
	travel(self, returnPoint(self), self.returnStarted)
end

-- S162e (Logic/Pursuit): gives up on a target it can neither reach nor hit (WoW's evade): immune to damage and debuffs,
-- full HP with a clean damage record (the cheese earns no kill), aggro reset, home at a trot; the clients show "Evade"
-- over it to the target (Context.evaded). Never bosses or their helpers (Pursuit.decide gets mayEvade = false).
local function evade(self: Monster)
	local target = self.target
	local probe = self.probe
	if probe then
		probe.evadeAt = os.clock()
		probe.hpAtEvade = self.hp
	end
	self.evading = true
	self.invulnerable = true
	table.clear(self.damageBy)
	setHp(self, self.stats.maxHp)
	if probe then
		probe.hpAfterEvade = self.hp
	end
	self:StartReturn()
	if self.ctx.evaded then
		self.ctx.evaded(self, target)
	end
end

local function finishReturn(self: Monster)
	self.state = "idle"
	if self.isBoss then
		self.invulnerable = false
	end
	-- S162e: the evade ends at home: hittable again and blind to players by sight for Combat.evadeCalm seconds (a hit
	-- still starts a fight), so a player on an unreachable spot next to its home does not pull it again at once
	if self.evading then
		self.evading = false
		self.invulnerable = false
		self.calmUntil = os.clock() + Combat.evadeCalm
		if self.probe then
			self.probe.homeAt = os.clock()
		end
	end
	dropPath(self)
	self.model:SetAttribute("Returning", nil)
	applyPace(self)
	self.nextWander = os.clock() + 2 + self.random:NextNumber() * 4
	-- Spread back to the own spot of the group. S101: a patrolling champion walks back to where the fight started,
	-- then goes on to its next waypoint instead of the start of its route.
	if not self.isBoss and not self.ctx.isRooted(self) then
		self.humanoid:MoveTo(if self.patrol then homeOf(self) else self.spawnCFrame.Position)
	end
end

-- S101: walks `points` in a loop (world event champion), resting `pause` seconds on each. The leash centre (`home`)
-- moves with the champion while it walks: route legs run up to ~1 500 studs, far past the 150 stud leash.
function Monster.SetPatrol(self: Monster, points: { Vector3 }, pause: number)
	if #points == 0 then
		self.patrol = nil
		return
	end
	self.patrol = points
	self.patrolIndex = 1
	self.patrolWaitUntil = 0
	self.patrolPause = pause
	self.nextPatrolMove = 0
	self.home = points[1]
end

-- One idle step along the patrol route.
local function stepPatrol(self: Monster, now: number)
	local route = self.patrol :: { Vector3 }
	local point = route[self.patrolIndex] or route[1]
	if distanceFlat(self.root.Position, point) <= 6 then
		if self.patrolWaitUntil == 0 then
			self.patrolWaitUntil = now + self.patrolPause
			self.home = point
			stop(self)
		elseif now >= self.patrolWaitUntil then
			self.patrolIndex = self.patrolIndex % #route + 1
			self.patrolWaitUntil = 0
			self.nextPatrolMove = 0
		end
		return
	end
	if now >= self.nextPatrolMove then
		self.nextPatrolMove = now + 1
		self.home = self.root.Position
		steerTo(self, point)
	end
end

-- Highest-threat valid target, or nil. A taunting player always wins.
local function pickTarget(self: Monster): Player?
	local taunter = self.ctx.taunter(self)
	if taunter and taunter.Parent ~= nil and self.ctx.canTarget(self, taunter) then
		if self.threat[taunter] == nil then
			self.threat[taunter] = 0
		end
		return taunter
	end
	local best: Player? = nil
	local bestThreat = -1
	for player, value in self.threat do
		if player.Parent == nil or not self.ctx.canTarget(self, player) then
			self.threat[player] = nil
		elseif value > bestThreat then
			best = player
			bestThreat = value
		end
	end
	return best
end

-- S157: whether `player` is over the monster's level cap (Logic/LevelLock; no cap = never).
local function lockedFor(self: Monster, player: Player?): boolean
	local cap = self.capLevel
	if cap == nil or player == nil then
		return false
	end
	return LevelLock.over(self.ctx.playerLevel(player), cap)
end

local function lookForAggro(self: Monster): Player?
	-- S162e: just back from an evade it ignores players by sight a while
	if os.clock() < self.calmUntil then
		return nil
	end
	-- S160: an Invasion zone monster attacks every player inside the zone (its own pick, no level rule)
	local picker = self.aggroPicker
	if picker then
		local picked = picker(self)
		if picked and self.ctx.canTarget(self, picked) then
			return picked
		end
	end
	if self.def.passive then
		return nil
	end
	local position = self.root.Position
	local closest: Player? = nil
	local closestDistance = math.huge
	for _, player in self.ctx.findPlayers(position, self.stats.aggroRange) do
		if
			self.ctx.canTarget(self, player)
			and MonsterStats.isAggressiveTowards(self.stats.level, self.ctx.playerLevel(player))
			and not lockedFor(self, player) -- S157: no pulling a capped monster away from its band
		then
			local p = self.ctx.playerPosition(player)
			local d = if p then (p - position).Magnitude else math.huge
			if d < closestDistance then
				closest = player
				closestDistance = d
			end
		end
	end
	return closest
end

local function engage(self: Monster, player: Player)
	if self.threat[player] == nil then
		self.threat[player] = 0
		if self.ctx.engaged then
			self.ctx.engaged(self, player)
		end
	end
	-- S22: a monster going home turns back when hit within the hard leash.
	if
		self.state == "return"
		and not self.isBoss
		and not self.evading -- S162e: an evading monster goes home whatever happens
		and Leash.canReengage(distanceFlat(self.root.Position, homeOf(self)), Combat :: any)
	then
		self.state = "idle"
		self.model:SetAttribute("Returning", nil)
		applyPace(self)
	end
	if self.state == "idle" then
		self.state = "chase"
		applyPace(self)
		setTarget(self, player)
		local now = os.clock()
		if self.probe then
			self.probe.engagedAt = now
		end
		resetProgress(self, now) -- S162e
		self.walkGoal = nil
		dropPath(self)
		self.nextAttack = math.max(self.nextAttack, now + 0.4)
		if self.ability then
			self.nextAbility = now + 3 + self.random:NextNumber() * 3
		end
		local extras: { MonsterAbilities.Ability } = self.extra or {}
		for _, extra in extras do
			self.extraNext[extra.id] = now + 3 + self.random:NextNumber() * 3
		end
		-- S134e: the kit's abilities (Crushing Blow first after 6-9 s)
		local kit = self.kit
		if kit then
			for _, id in kit.abilities do
				local ability = MonsterAbilities.get(id)
				if ability then
					self.kitNext[id] = now + MonsterCast.firstReady(ability, self.random:NextNumber())
				end
			end
			self.nextThrow = now
		end
	end
end

-- S134e: removes the kit (the world event commander and champion: MonsterService.SpawnAt `noKit`).
function Monster.ClearKit(self: Monster)
	self.kit = nil
	table.clear(self.kitNext)
end

local function abilityArea(self: Monster, ability: MonsterAbilities.Ability, targetPosition: Vector3): CFrame
	local from = self.root.Position
	local ground = from.Y - self.humanoid.HipHeight - self.root.Size.Y / 2
	if (ability.origin == "random" or ability.origin == "target") and self.ctx.groundAt then
		-- S134c: the chosen fighter may stand far away on higher or lower ground (insideArea checks height). S134e: so
		-- may the target (a slope 12+ studs above or below the caster left it untouchable); frozen when announced.
		return CFrame.new(self.ctx.groundAt(targetPosition))
	end
	if ability.origin == "target" or ability.origin == "random" then
		return CFrame.new(Vector3.new(targetPosition.X, ground, targetPosition.Z))
	end
	local look = Vector3.new(targetPosition.X, ground, targetPosition.Z)
	local origin = Vector3.new(from.X, ground, from.Z)
	if (look - origin).Magnitude < 0.1 then
		return CFrame.new(origin)
	end
	return CFrame.lookAt(origin, look)
end

-- Hard leash distance from home (S22; bosses keep their single arena leash).
local function leashMax(self: Monster): number
	if self.isBoss then
		return self.leashRange or Combat.leashRange
	end
	if self.leashHard then
		return self.leashHard
	end
	return math.max(self.leashRange or Combat.leashRange, Combat.leashMax)
end

-- S134c: a random living fighter's position for a "random" ability (the spawning service lists the fighters); only
-- fighters within the hard leash, so a leap never carries the caster past it.
local function randomFighterPosition(self: Monster): Vector3?
	local list: { Player } = if self.fighters then self.fighters() else {}
	local options: { Vector3 } = {}
	local limit = leashMax(self)
	for _, player in list do
		if self.ctx.canTarget(self, player) then
			local position = self.ctx.playerPosition(player)
			if position and distanceFlat(position, homeOf(self)) <= limit then
				table.insert(options, position)
			end
		end
	end
	if #options == 0 then
		return nil
	end
	return options[self.random:NextInteger(1, #options)]
end

-- The ability to cast now and its area, or nil: S134c the first ready extra ability (its HP gate met; a "random" one
-- needs a fighter, the others the target in reach), then the own ability; with extra abilities the gap after the
-- last cast holds them all.
local function pickAbility(
	self: Monster,
	now: number,
	distance: number,
	reach: number,
	targetPosition: Vector3
): (MonsterAbilities.Ability?, CFrame?)
	if self.extra and now < self.nextGlobal then
		return nil, nil
	end
	local hpShare = self.hp / math.max(1, self.stats.maxHp)
	local extras: { MonsterAbilities.Ability } = self.extra or {}
	for _, extra in extras do
		if now >= (self.extraNext[extra.id] or math.huge) and (extra.fromHp == nil or hpShare <= extra.fromHp) then
			if extra.origin == "random" then
				local at = randomFighterPosition(self)
				if at then
					return extra, abilityArea(self, extra, at)
				end
			elseif distance <= math.max(reach, (extra.radius or extra.length or 10)) then
				return extra, abilityArea(self, extra, targetPosition)
			end
		end
	end
	local ability = self.ability
	if
		ability
		and now >= self.nextAbility
		and distance <= math.max(reach, (ability.radius or ability.length or 10))
	then
		return ability, abilityArea(self, ability, targetPosition)
	end
	return nil, nil
end

-- S134e: the kit's choice (Logic/MonsterCast.pick): an ability id, "throw" or nil.
local function kitPick(self: Monster, now: number, distance: number, reach: number): string?
	local kit = self.kit :: MonsterAbilities.Kit
	local ready: { [string]: boolean } = {}
	for _, id in kit.abilities do
		ready[id] = now >= (self.kitNext[id] or math.huge)
	end
	local own = self.ability
	if own then
		ready[own.id] = now >= self.nextAbility
	end
	return MonsterCast.pick({
		now = now,
		distance = distance,
		reach = reach,
		outOfReachFor = if self.outOfReachSince > 0 then now - self.outOfReachSince else 0,
		ready = ready,
		lastCast = self.lastCast,
		kit = kit,
		own = own,
		throwReady = now >= self.nextThrow,
	})
end

-- S63: interval between regular attacks under attack slow (bosses' special abilities keep their own cooldowns).
local function attackInterval(self: Monster): number
	local slow = if self.ctx.attackSlow then self.ctx.attackSlow(self) else 0
	return Traits.slowedInterval(self.stats.attackInterval, slow)
end

-- S162e: tells the chase test (Logic/ChaseTest) that a blow or a throw leaves now.
local function probeAttack(self: Monster, target: Player, kind: string)
	local probe = self.probe
	local attack = probe and probe.attack
	if attack then
		attack(self, target, kind)
	end
end

-- S134e: the kit's throw at a fleeing target: a regular ranged blow (dodge, block and ranged protection count), every
-- attack interval x intervalMul, harder the farther below the monster the target is (MonsterCast.throwMul). Returns
-- whether it threw. S159a: the throw is drawn back first (Data/Combat.basicWind.throw, the clients pose the throw or
-- the spell): it flies after the draw if the monster is still chasing, not stunned and may still target the player.
local function throwAt(self: Monster, now: number, target: Player, targetPosition: Vector3): boolean
	local kit = self.kit
	local throw = kit and kit.throw
	local send = self.ctx.rangedThrow
	if not throw or not send then
		return false
	end
	self.nextThrow = now + attackInterval(self) * throw.intervalMul
	face(self, targetPosition)
	local multiplier = MonsterCast.throwMul(throw, self.stats.level, self.ctx.playerLevel(target))
	local params = { kind = self.stats.damageKind, multiplier = multiplier, element = self.def.element }
	local wind = self.ctx.attackWind
	local seconds = BasicBlow.throwWind(self.variant)
	if not wind or seconds <= 0 then
		probeAttack(self, target, "throw")
		send(self, target, params)
		return true
	end
	self.windToken += 1
	local token = self.windToken
	wind(self, target, seconds, if self.stats.damageKind == "magic" then "bolt" else "throw")
	task.delay(seconds, function()
		if self.windToken ~= token or self.state ~= "chase" or self.ctx.isDisabled(self) then
			return
		end
		self.windToken += 1
		if self.ctx.canTarget(self, target) then
			probeAttack(self, target, "throw")
			send(self, target, params)
		end
	end)
	return true
end

-- S134c: the bosses 2.0 telegraph options of an ability (the golden shared circle, the thicker rim of a big blow).
-- S134e: a lethal blow is marked (`lethal`: its own colour and pulse) and warns its target (`warn`).
local function teleOpts(ability: MonsterAbilities.Ability, target: Player?): any?
	if ability.mechanic == "split" then
		return { mechanic = "split" }
	elseif BossMechanics.isAvoidable(ability :: any) then
		if ability.lethal then
			return { mechanic = "avoid", lethal = true, warn = target }
		end
		return { mechanic = "avoid" }
	end
	return nil
end

local function stepIdle(self: Monster, now: number)
	local found = lookForAggro(self)
	if found then
		engage(self, found)
		return
	end
	if self.patrol then
		if not self.ctx.isRooted(self) then
			stepPatrol(self, now)
		end
		return
	end
	if now >= self.nextWander and not self.ctx.isRooted(self) then
		self.nextWander = now + 4 + self.random:NextNumber() * 5
		local angle = self.random:NextNumber() * math.pi * 2
		local radius = self.random:NextNumber() * Combat.wanderRadius
		local point = homeOf(self) + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not self.ctx.isSafePosition(point) then
			self.humanoid:MoveTo(point)
		end
	end
end

-- Leash check (S22). Bosses keep their single arena leash.
local function leashed(self: Monster, now: number, hasTarget: boolean): boolean
	local distHome = distanceFlat(self.root.Position, homeOf(self))
	if self.isBoss then
		return not hasTarget or distHome > (self.leashRange or Combat.leashRange)
	end
	local cfg = Combat :: any
	if self.leashRange or self.leashHard then
		cfg = table.clone(Combat) :: any
		cfg.leashRange = self.leashRange or Combat.leashRange
		cfg.leashMax = leashMax(self)
	end
	local back = Leash.shouldReturn({
		distHome = distHome,
		sinceHit = sinceHit(self, now),
		hasTarget = hasTarget,
	}, cfg)
	return back
end

-- S134c: extra abilities of a world event commander (Data/MonsterAbilities with the bosses 2.0 fields): tried in list
-- order before its own ability, `gap` seconds after every cast, `fighters` = the players a "random" ability aims at
-- and a shared blow hits when nobody stands in it (from the spawning service), `onCast` = a hook on each cast (the
-- service's announcement of a shared blow). Ready 3 s after it is set while fighting, else 3-6 s after it engages.
function Monster.SetExtraAbilities(
	self: Monster,
	abilities: { MonsterAbilities.Ability },
	gap: number,
	fighters: () -> { Player },
	onCast: ((ability: MonsterAbilities.Ability, area: CFrame) -> ())?
)
	self.extra = abilities
	self.extraGap = gap
	self.fighters = fighters
	self.onCast = onCast
	local now = os.clock()
	for _, ability in abilities do
		self.extraNext[ability.id] = if self.state == "idle" then math.huge else now + 3
	end
end

-- S63: after a Concussion stun the monster strikes at the earliest `share` of its interval later (like stepCast);
-- a stun alone never moves nextAttack (Step returns early), so it would strike right after the stun.
function Monster.DelayAttack(self: Monster, stunSeconds: number, share: number)
	self.nextAttack = math.max(self.nextAttack, os.clock() + stunSeconds + attackInterval(self) * share)
end

-- S159: a regular blow: the draw (Data/Combat.basicWind) on the clients, then the blow lands if the target is still
-- near (reach x windReach + windSlack; a step back dodges it), the monster still chasing and not stunned. A monster
-- without the hook strikes at once. Studio review 2026-10-21: the draw of Logic/BasicBlow (longer, an Elite's longer
-- still); the clients pose the same seconds, so the blow lands where the swing does.
windUp = function(self: Monster, target: Player)
	local wind = self.ctx.attackWind
	local seconds = BasicBlow.wind(self.def.attack, self.variant)
	if not wind or seconds <= 0 then
		probeAttack(self, target, "blow")
		self.ctx.basicAttack(self, target)
		return
	end
	self.windToken += 1
	local token = self.windToken
	wind(self, target, seconds, BasicBlow.shot(self.def.attack, self.stats.damageKind))
	task.delay(seconds, function()
		if self.windToken ~= token or self.state ~= "chase" or self.ctx.isDisabled(self) then
			return
		end
		self.windToken += 1
		local at = self.ctx.playerPosition(target)
		if not at or not self.ctx.canTarget(self, target) then
			return
		end
		local reach = self.stats.range + self.root.Size.Z / 2
		-- S162e: a blow lands only within the height a melee blow reaches (no hits through the air to a roof)
		local high = self.def.attack == "melee" and not meleeHeightOk(self, targetGround(at))
		if distanceFlat(self.root.Position, at) <= reach * Combat.windReach + Combat.windSlack and not high then
			probeAttack(self, target, "blow")
			self.ctx.basicAttack(self, target)
		end
	end)
end

-- S162m: the root's place over a ground point, and the ground point under the root.
local function rootOver(self: Monster, ground: Vector3): Vector3
	return ground + Vector3.new(0, self.humanoid.HipHeight + self.root.Size.Y / 2, 0)
end

local function groundUnder(self: Monster): Vector3
	return self.root.Position - Vector3.new(0, self.humanoid.HipHeight + self.root.Size.Y / 2, 0)
end

-- S162m: drops the flight of the cast being wound up (a stun or a new cast): the run stops at the next pace and the
-- clients see DashAt cleared.
local function cancelDash(self: Monster)
	self.castToken += 1
	if self.dashUntil > 0 then
		self.dashUntil = 0
		applyPace(self)
	end
	if self.dashOn then
		self.dashOn = false
		self.model:SetAttribute("DashAt", nil)
	end
end

-- S162m (docs/ANIM-WZORCE §9 Q6): the flight of an ability with `dash` (Data/MonsterAbilities), announced with its
-- telegraph. A running dash (no `leap`: the wolf's leap, the boar's charge) runs `seconds` before the blow lands to
-- MonsterMove.stopDistance in front of where the target stood (a line: no farther than its length); skipped when the
-- landing is a ledge or a drop, in a safe zone or past the hard leash. A `leap` one (Pounce, the commander's leap) is
-- still moved at the blow (stepCast); its flight is announced only when it may land. The clients draw both from the
-- model attributes DashId, DashMode ("move" | "jump"), DashFrom, DashTo (root positions), DashAt (server time the
-- flight starts), DashTime (its seconds) and DashArc (studs of the apex over the straight line), DashAt set last.
local function planDash(self: Monster, ability: MonsterAbilities.Ability, area: CFrame, targetPosition: Vector3)
	local dash = ability.dash
	if not dash then
		return
	end
	local startsIn, seconds = MonsterMove.dashStart(dash, ability.windup)
	local from = self.root.Position
	local landing: Vector3
	local travel: number
	if ability.leap then
		landing = area.Position
		travel = distanceFlat(from, landing)
	else
		local halfDepth = self.root.Size.Z / 2
		local stopAt = MonsterMove.stopDistance("melee", self.stats.range + halfDepth, halfDepth, Combat :: any)
		local aim = if ability.origin == "self" then targetPosition else area.Position
		local maxTravel = if ability.shape == "line" then ability.length or 0 else math.huge
		local x, z, run = MonsterMove.dashLanding(from.X, from.Z, aim.X, aim.Z, stopAt, maxTravel)
		if run <= 0 then
			return
		end
		local ground = groundUnder(self)
		landing = Vector3.new(x, ground.Y, z)
		if self.ctx.groundAt then
			local found = self.ctx.groundAt(landing)
			if math.abs(found.Y - ground.Y) > MonsterMove.DASH_CLIMB then
				return
			end
			landing = found
		end
		travel = run
	end
	if
		not MonsterCast.canLand(self.ctx.isSafePosition(landing), distanceFlat(landing, homeOf(self)), leashMax(self))
	then
		return
	end
	local to = rootOver(self, landing)
	if not ability.leap then
		local token = self.castToken
		task.delay(startsIn, function()
			if self.castToken ~= token or self.state ~= "cast" then
				return
			end
			if self.ctx.isDisabled(self) or self.ctx.isRooted(self) then
				cancelDash(self) -- held in place: the clients do not draw a flight it never makes
				return
			end
			self.dashSpeed = travel / math.max(0.05, seconds)
			self.dashUntil = os.clock() + seconds + 0.25
			applyPace(self)
			self.humanoid:MoveTo(landing)
		end)
	end
	local model = self.model
	model:SetAttribute("DashId", ability.id)
	model:SetAttribute("DashMode", if ability.leap then "jump" else "move")
	model:SetAttribute("DashFrom", from)
	model:SetAttribute("DashTo", to)
	model:SetAttribute("DashTime", seconds)
	model:SetAttribute("DashArc", MonsterMove.arcHeight(dash, travel, self.def.size * self.stats.scale))
	model:SetAttribute("DashAt", Workspace:GetServerTimeNow() + startsIn)
	self.dashOn = true
end

local function stepChase(self: Monster, now: number)
	local position = self.root.Position
	local target = pickTarget(self)
	if leashed(self, now, target ~= nil) or not target then
		self:StartReturn()
		return
	end
	setTarget(self, target)
	local targetPosition = self.ctx.playerPosition(target)
	if not targetPosition then
		self.threat[target] = nil
		return
	end
	local distance = distanceFlat(position, targetPosition)
	local reach = self.stats.range + self.root.Size.Z / 2
	local melee = self.def.attack == "melee"
	-- S162e: a shot or a throw needs a clear line to the target (no arrows through rocks and walls); one sight ray per
	-- tick at most. Studio 2026-10-31: a blow needs the height too (a target on a roof is out of a wolf's reach), a shot
	-- or a throw measures its reach in 3D.
	local sight: boolean? = nil
	local aim: Vector3 = targetPosition
	local function seen(): boolean
		if sight == nil then
			sight = sightTo(self, aim)
		end
		return sight == true
	end
	local ground = targetPosition.Y - PLAYER_ROOT_UP
	local inReach = reaches(self, targetPosition, distance, seen)
	-- a melee monster within its flat reach of a target it cannot reach up to (a roof, a rock, a ledge)
	local below = melee and distance <= reach and not inReach
	-- S134e: since when the target keeps out of reach (the kit's fleeing rule)
	if inReach then
		self.outOfReachSince = 0
	elseif self.outOfReachSince == 0 then
		self.outOfReachSince = now
	end

	-- Elite II special ability (telegraphed); S134c: a commander's extra abilities first. S134e: a monster with a
	-- kit picks through Logic/MonsterCast (the kit, its own ability, the throw at a fleeing target).
	local ability: MonsterAbilities.Ability?, area: CFrame? = nil, nil
	local threw = false
	if self.kit then
		local choice = kitPick(self, now, distance, reach)
		if choice == "throw" then
			threw = seen() and throwAt(self, now, target, targetPosition) -- S162e: along a clear line only
		elseif choice then
			local own = self.ability
			ability = if own and own.id == choice then own else MonsterAbilities.get(choice)
			if ability then
				area = abilityArea(self, ability, targetPosition)
			end
		end
	else
		ability, area = pickAbility(self, now, distance, reach, targetPosition)
	end
	if ability and area then
		stop(self)
		face(self, if ability.origin == "random" then area.Position else targetPosition)
		self.state = "cast"
		self.windToken += 1 -- S159: a cast cancels a blow being wound up
		cancelDash(self) -- S162m: a new cast drops the flight of the last one
		self.castArea = area
		self.castAbility = ability
		self.castEnd = now + ability.windup
		if self.extra then
			self.nextGlobal = now + ability.windup + self.extraGap
		end
		self.ctx.telegraph(self, ability, area, teleOpts(ability, target))
		planDash(self, ability, area, targetPosition)
		if self.onCast then
			self.onCast(ability, area)
		end
		return
	end

	-- S162e (Logic/Pursuit): progress towards where it walked since the last tick; standing where its blow, its shot or
	-- its Elite II throw reaches the target is never stalling. It evades when it can neither reach nor hit the target
	-- (bosses and their helpers never: their arenas have walls by design and the bosses their own answer to kiting).
	local throw = self.kit and self.kit.throw
	local canHit = inReach
		or threw
		or (
			throw ~= nil
			and self.ctx.rangedThrow ~= nil
			and (targetPosition - position).Magnitude <= throw.range
			and seen()
		)
	local action = notePursuit(self, now, canHit, not self.isBoss and not self.summoned)
	if action == "evade" then
		evade(self)
		return
	end

	-- S162m (docs/ANIM-WZORCE §9 R2): a melee monster walks on to MonsterMove.stopDistance (meleeApproach x its reach)
	-- before it stands, so its blow meets the target; it starts a blow anywhere within its reach as before (the hit
	-- rule at the blow stays). A ranged one stands at its reach. S162e: the goals are ground points (the paths' ends).
	local halfDepth = self.root.Size.Z / 2
	local stopAt = MonsterMove.stopDistance(self.def.attack, reach, halfDepth, Combat :: any)
	if inReach then
		local closing = melee and distance > stopAt and not self.ctx.isRooted(self)
		if not closing then
			stop(self)
			face(self, targetPosition)
		end
		if now >= self.nextAttack then
			self.nextAttack = now + attackInterval(self)
			windUp(self, target)
		end
		if closing then
			local x, z = MonsterMove.approach(position.X, position.Z, targetPosition.X, targetPosition.Z, stopAt)
			travel(self, Vector3.new(x, ground, z), now, Vector3.new(targetPosition.X, ground, targetPosition.Z))
		end
		return
	end

	-- Do not follow players into safe zones.
	if self.ctx.isSafePosition(targetPosition) then
		self.threat[target] = nil
		return
	end
	if not self.ctx.isRooted(self) then
		-- S162m: a melee monster to the point stopAt short of the target (MoveTo ends there instead of in the target's
		-- body); a ranged one to the target until it is within its reach with a clear line. S162e: a path to the
		-- target's feet.
		local feet = Vector3.new(targetPosition.X, ground, targetPosition.Z)
		local goal = feet
		-- S162e: under a target it cannot reach up to, it walks to the target's spot itself (up a slope it gets there;
		-- under a roof or a rock it stalls and gives up)
		if melee and not below then
			local x, z = MonsterMove.approach(position.X, position.Z, targetPosition.X, targetPosition.Z, stopAt)
			goal = Vector3.new(x, ground, z)
		end
		if action == "repath" then
			repath(self, feet, now)
		end
		travel(self, goal, now, feet)
	end
end

local function stepCast(self: Monster, now: number)
	if now < self.castEnd then
		return
	end
	local ability = self.castAbility
	local area = self.castArea
	self.state = "chase"
	self.castArea = nil
	self.castAbility = nil
	resetProgress(self, now) -- S162e: the windup was no stalling
	-- S162m: the dash is over (its run ends at the landing; the pace is the fight's again)
	self.dashOn = false
	if self.dashUntil > 0 then
		self.dashUntil = 0
		applyPace(self)
	end
	if ability and area then
		local kit = self.kit
		if ability == self.ability then
			self.nextAbility = now + ability.cooldown
		elseif kit and table.find(kit.abilities, ability.id) then
			self.kitNext[ability.id] = now + ability.cooldown
		else
			self.extraNext[ability.id] = now + ability.cooldown
		end
		self.lastCast = now -- S134e: the kit's globalGap counts from here
		self.nextAttack = now + attackInterval(self) * 0.5
		-- S134c: a shared blow is split by everyone inside; nobody inside = missAll on every fighter (CombatService)
		local split = if ability.mechanic == "split" then ability.split else nil
		local opts = if split
			then {
				split = true,
				missAll = split.missAll,
				fighters = if self.fighters then self.fighters() else {},
			}
			else nil
		self.ctx.resolveAbility(self, ability, area, opts)
		-- S134e: a leap lands only outside safe zones and within the hard leash (Logic/MonsterCast.canLand)
		local point = area.Position
		if
			ability.leap
			and self.state ~= "dead"
			and MonsterCast.canLand(self.ctx.isSafePosition(point), distanceFlat(point, homeOf(self)), leashMax(self))
		then
			self.model:PivotTo(
				CFrame.new(point + Vector3.new(0, self.humanoid.HipHeight + self.root.Size.Y / 2, 0))
					* self.root.CFrame.Rotation
			)
			resetProgress(self, now)
			dropPath(self) -- S162e: it landed elsewhere
			self.outOfReachSince = 0
		end
	end
end

local function stepReturn(self: Monster, now: number)
	local position = self.root.Position
	local point = returnPoint(self)
	if distanceFlat(position, point) <= 4 then
		finishReturn(self)
		return
	end
	-- S162e (Logic/Pursuit): stalled on the way home, with no path or for pursuitEvade seconds = the timeout's teleport
	local action = notePursuit(self, now, false, true)
	if now - self.returnStarted > Combat.returnTimeout or action == "evade" then
		-- Teleport home (no healing, S22).
		if self.probe and self.evading then
			self.probe.homeTeleport = true
		end
		self.model:PivotTo(CFrame.new(point) + Vector3.new(0, self.humanoid.HipHeight + self.root.Size.Y / 2, 0))
		finishReturn(self)
		return
	end
	if action == "repath" then
		repath(self, point, now)
	end
	travel(self, point, now)
end

-- Out-of-combat regeneration at home (S22). Back at full HP the damage record is cleared, so a later kill
-- credits only the new fight.
local function regenerate(self: Monster, now: number, dt: number)
	if self.isBoss or self.hp >= self.stats.maxHp then
		return
	end
	local hp = Leash.regen(self.hp, self.stats.maxHp, sinceHit(self, now), dt, Combat :: any)
	if hp ~= self.hp then
		setHp(self, hp)
		if self.hp >= self.stats.maxHp then
			table.clear(self.damageBy)
		end
	end
end

-- One AI tick (MonsterService calls this at Combat.aiTickRate).
function Monster.Step(self: Monster, now: number)
	local state = self.state
	if state == "dead" then
		return
	end
	-- Stunned or frozen: no movement, no attacks, casts are interrupted.
	if state ~= "return" and self.ctx.isDisabled(self) then
		if state == "cast" then
			self.state = "chase"
			self.castArea = nil
		end
		self.windToken += 1 -- S159: a stun breaks the draw
		cancelDash(self) -- S162m: and the flight of a cast
		resetProgress(self, now) -- S162e: held in place is no stalling
		stop(self)
		return
	end
	local dt = math.min(now - self.lastStep, 1)
	self.lastStep = now
	if state == "idle" then
		regenerate(self, now, dt)
		stepIdle(self, now)
	elseif state == "chase" then
		stepChase(self, now)
	elseif state == "cast" then
		stepCast(self, now)
	elseif state == "return" then
		stepReturn(self, now)
	end
	self.ctx.moved(self)
end

-- S162e: whether its blow or shot reaches a target whose root is at `targetPosition` now (the chase test's "caught").
function Monster.CanReach(self: Monster, targetPosition: Vector3): boolean
	return reaches(self, targetPosition, distanceFlat(self.root.Position, targetPosition), function()
		return sightTo(self, targetPosition)
	end)
end

-- S157: sets the over-level cap (Logic/LevelLock; nil = none), also as the model attribute CapLevel for the clients.
function Monster.SetCap(self: Monster, cap: number?)
	self.capLevel = cap
	self.model:SetAttribute("CapLevel", cap)
end

-- S157: whether `player` is too high to fight this monster (Logic/LevelLock).
function Monster.LockedFor(self: Monster, player: Player?): boolean
	return lockedFor(self, player)
end

-- Applies damage from a player (or nil for environment). Returns the HP removed. S157: a player over the level cap
-- removes nothing (damage over time, reflections and every other source end here).
function Monster.TakeDamage(self: Monster, amount: number, source: Player?): number
	if self.state == "dead" or self.invulnerable or amount <= 0 then
		return 0
	end
	-- S162e: a chase test's monster cannot be hurt (nor pulled by hits): the test drives the fight
	if self.probe and self.probe.immortal then
		return 0
	end
	if source and lockedFor(self, source) then
		return 0
	end
	local dealt = math.min(self.hp, amount)
	setHp(self, self.hp - dealt)
	if source then
		self.lastHit = os.clock()
		self.damageBy[source] = (self.damageBy[source] or 0) + dealt
		local threatMul = if self.ctx.threatMultiplier then self.ctx.threatMultiplier(self, source) else 1
		-- Engage first: it pulls the group only while this player has no threat entry yet.
		engage(self, source)
		self.threat[source] = (self.threat[source] or 0) + dealt * threatMul
		if self.ctx.damaged and dealt > 0 then
			self.ctx.damaged(self, source, dealt)
		end
	end
	if self.hp <= 0 then
		self.killedBy = source
		self.state = "dead"
		setTarget(self, nil)
		self.model:SetAttribute("Dead", true)
		stop(self)
		self.ctx.died(self)
	end
	return dealt
end

-- Adds threat without damage (taunts, heals on allies in later sessions).
function Monster.AddThreat(self: Monster, player: Player, amount: number)
	if self.state == "dead" or self.state == "return" or lockedFor(self, player) then
		return
	end
	-- Engage first: it pulls the group only while this player has no threat entry yet.
	engage(self, player)
	self.threat[player] = (self.threat[player] or 0) + amount
end

-- Player who dealt the most damage (DESIGN §15.1); parties extend this in S09.
function Monster.TopDamager(self: Monster): Player?
	local best: Player? = nil
	local bestDamage = 0
	for player, damage in self.damageBy do
		if damage > bestDamage and player.Parent ~= nil then
			best = player
			bestDamage = damage
		end
	end
	return best
end

function Monster.Destroy(self: Monster)
	self.state = "dead"
	PathWorker.cancel(self) -- S162e: a path still waiting is not computed for nobody
	self.model:Destroy()
end

return Monster
