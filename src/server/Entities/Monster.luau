--!strict
-- One monster: model, stats, threat table and AI (DESIGN §15.1).
--   idle   : wander within Combat.wanderRadius of the group centre, look for players in aggro range; out of
--            combat it slowly regains HP (S22, Logic/Leash.regen)
--   chase  : follow the highest-threat valid target; goes home by Logic/Leash.shouldReturn (S22: soft leash
--            while nobody hits the group, hard leash, lost target, stuck)
--   cast   : Elite II special: telegraph for `windup` seconds, then resolve
--   return : walk back to the group centre (S22: no healing, no invulnerability; a hit within the hard leash
--            turns it back into the fight), then to its own spot and idle. Bosses keep the old return: their
--            arena centre, full HP and invulnerable on the way.
--   dead   : waiting for MonsterService to remove the model
-- Chasing and going home steer around obstacles (FIX 2026-10-09, Logic/Steer): two short rays (knee and hip
-- height) probe the way ahead; a blocked way takes the first clear angle to one side and keeps that side a while.
-- Damage resolution, telegraphs and rewards are delegated to the Context given by MonsterService, so this
-- module never talks to other services directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local AreaProfiles = require(Shared.Data.AreaProfiles)
local Combat = require(Shared.Data.Combat)
local Leash = require(Shared.Logic.Leash)
local MonsterAbilities = require(Shared.Data.MonsterAbilities)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Monsters = require(Shared.Data.Monsters)
local RigBuilder = require(script.Parent.RigBuilder)
local Steer = require(Shared.Logic.Steer)

export type State = "idle" | "chase" | "cast" | "return" | "dead"

export type Context = {
	findPlayers: (position: Vector3, radius: number) -> { Player },
	playerPosition: (player: Player) -> Vector3?,
	playerLevel: (player: Player) -> number,
	-- Alive, in the world and not standing in a safe (green) zone.
	canTarget: (monster: any, player: Player) -> boolean,
	isSafePosition: (position: Vector3) -> boolean,
	basicAttack: (monster: any, player: Player) -> (),
	telegraph: (monster: any, ability: MonsterAbilities.Ability, area: CFrame) -> (),
	resolveAbility: (monster: any, ability: MonsterAbilities.Ability, area: CFrame) -> (),
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
}

local Monster = {}
Monster.__index = Monster

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
		returnStarted: number,
		random: Random,
		entity: any, -- EntityService entity (set by MonsterService)
		spawnerId: string?,
		damageOverride: number?,
		speedFactor: number,
		-- Bosses: own leash range (arena) and no rewards through CombatService.
		leashRange: number?,
		-- Centre of the monster's group (S19): wander and leash around it instead of the own spawn point.
		home: Vector3?,
		isBoss: boolean?,
		-- S32: highest level of the monster's spawner (drops never get a higher item level).
		levelCap: number?,
		-- S22 leash: last hit by a player, last time the monster moved (or attacked) while chasing and where.
		lastHit: number,
		movedAt: number,
		movedFrom: Vector3,
		lastStep: number,
		-- Obstacle steering: the side of the current detour (-1, 0, 1) and until when it is kept.
		detourSide: number,
		detourUntil: number,
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
	attributes: { [string]: any }?
): Monster
	-- S32: members of bigger groups hit softer (Combat.groupDamageMul). S33: the area profile's HP and attack.
	local groupSize = attributes and (attributes :: any).GroupSize
	local areaId = attributes and (attributes :: any).AreaId
	local profile = AreaProfiles.ofArea(if type(areaId) == "string" then areaId else nil)
	local stats =
		MonsterStats.compute(def, level, variant, if type(groupSize) == "number" then groupSize else nil, profile)
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
		returnStarted = 0,
		random = Random.new(),
		entity = nil,
		spawnerId = nil,
		damageOverride = nil,
		speedFactor = 1,
		leashRange = nil,
		home = nil,
		isBoss = nil,
		levelCap = nil,
		lastHit = 0,
		movedAt = 0,
		movedFrom = spawnCFrame.Position,
		lastStep = os.clock(),
		detourSide = 0,
		detourUntil = 0,
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
		self.model:SetAttribute("AggroUserId", if player then player.UserId else nil)
	end
end

local function stop(self: Monster)
	self.humanoid:MoveTo(self.root.Position)
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

-- Whether something solid (not a walkable slope) is within `reach` studs of `self` in the flat direction.
local function probeBlocked(self: Monster, dx: number, dz: number, reach: number): boolean
	local root = self.root
	local direction = Vector3.new(dx, 0, dz) * reach
	local feet = root.Position.Y - root.Size.Y / 2 - self.humanoid.HipHeight
	for _, y in { feet + 1.5, root.Position.Y } do
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

-- Applies the slow/root factor from status effects (1 = normal speed).
function Monster.RefreshSpeed(self: Monster, factor: number)
	self.speedFactor = factor
	local base = self.def.moveSpeed * (if self.state == "return" then Combat.returnSpeedMultiplier else 1)
	self.humanoid.WalkSpeed = base * factor
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
	if self.isBoss then
		-- Bosses (arena leash 400) keep the old return: full HP and invulnerable on the way.
		self.invulnerable = true
		table.clear(self.damageBy)
		setHp(self, self.stats.maxHp)
	end
	self.model:SetAttribute("Returning", true)
	self.humanoid.WalkSpeed = self.def.moveSpeed * Combat.returnSpeedMultiplier * self.speedFactor
	self.returnStarted = os.clock()
	steerTo(self, returnPoint(self))
end

local function finishReturn(self: Monster)
	self.state = "idle"
	if self.isBoss then
		self.invulnerable = false
	end
	self.model:SetAttribute("Returning", nil)
	self.humanoid.WalkSpeed = self.def.moveSpeed * self.speedFactor
	self.nextWander = os.clock() + 2 + self.random:NextNumber() * 4
	-- Spread back to the own spot of the group.
	if not self.isBoss and not self.ctx.isRooted(self) then
		self.humanoid:MoveTo(self.spawnCFrame.Position)
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

local function lookForAggro(self: Monster): Player?
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
		and Leash.canReengage(distanceFlat(self.root.Position, homeOf(self)), Combat :: any)
	then
		self.state = "idle"
		self.model:SetAttribute("Returning", nil)
		self.humanoid.WalkSpeed = self.def.moveSpeed * self.speedFactor
	end
	if self.state == "idle" then
		self.state = "chase"
		setTarget(self, player)
		local now = os.clock()
		self.movedAt = now
		self.movedFrom = self.root.Position
		self.nextAttack = math.max(self.nextAttack, now + 0.4)
		if self.ability then
			self.nextAbility = now + 3 + self.random:NextNumber() * 3
		end
	end
end

local function abilityArea(self: Monster, ability: MonsterAbilities.Ability, targetPosition: Vector3): CFrame
	local from = self.root.Position
	local ground = from.Y - self.humanoid.HipHeight - self.root.Size.Y / 2
	if ability.origin == "target" then
		return CFrame.new(Vector3.new(targetPosition.X, ground, targetPosition.Z))
	end
	local look = Vector3.new(targetPosition.X, ground, targetPosition.Z)
	local origin = Vector3.new(from.X, ground, from.Z)
	if (look - origin).Magnitude < 0.1 then
		return CFrame.new(origin)
	end
	return CFrame.lookAt(origin, look)
end

local function stepIdle(self: Monster, now: number)
	local found = lookForAggro(self)
	if found then
		engage(self, found)
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
	if self.leashRange then
		cfg = table.clone(Combat) :: any
		cfg.leashRange = self.leashRange
		cfg.leashMax = math.max(self.leashRange, Combat.leashMax)
	end
	local stuckFor = if self.ctx.isRooted(self) then 0 else now - self.movedAt
	local back = Leash.shouldReturn({
		distHome = distHome,
		sinceHit = sinceHit(self, now),
		hasTarget = hasTarget,
		stuckFor = stuckFor,
	}, cfg)
	return back
end

-- Progress for the stuck check: moving at least 1.5 studs (or attacking, or being rooted) counts.
local function noteMovement(self: Monster, now: number, attacking: boolean)
	local position = self.root.Position
	if attacking or self.ctx.isRooted(self) or distanceFlat(position, self.movedFrom) >= 1.5 then
		self.movedAt = now
		self.movedFrom = position
	end
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

	-- Elite II special ability (telegraphed).
	local ability = self.ability
	if
		ability
		and now >= self.nextAbility
		and distance <= math.max(reach, (ability.radius or ability.length or 10))
	then
		stop(self)
		face(self, targetPosition)
		local area = abilityArea(self, ability, targetPosition)
		self.state = "cast"
		self.castArea = area
		self.castEnd = now + ability.windup
		self.ctx.telegraph(self, ability, area)
		return
	end

	noteMovement(self, now, distance <= reach)
	if distance <= reach then
		stop(self)
		face(self, targetPosition)
		if now >= self.nextAttack then
			self.nextAttack = now + self.stats.attackInterval
			self.ctx.basicAttack(self, target)
		end
		return
	end

	-- Do not follow players into safe zones.
	if self.ctx.isSafePosition(targetPosition) then
		self.threat[target] = nil
		return
	end
	if not self.ctx.isRooted(self) then
		steerTo(self, targetPosition)
	end
end

local function stepCast(self: Monster, now: number)
	if now < self.castEnd then
		return
	end
	local ability = self.ability
	local area = self.castArea
	self.state = "chase"
	self.castArea = nil
	if ability and area then
		self.nextAbility = now + ability.cooldown
		self.nextAttack = now + self.stats.attackInterval * 0.5
		self.ctx.resolveAbility(self, ability, area)
	end
end

local function stepReturn(self: Monster, now: number)
	local position = self.root.Position
	local point = returnPoint(self)
	if distanceFlat(position, point) <= 4 then
		finishReturn(self)
		return
	end
	if now - self.returnStarted > Combat.returnTimeout then
		-- Teleport home (no healing, S22).
		self.model:PivotTo(CFrame.new(point) + Vector3.new(0, self.humanoid.HipHeight + self.root.Size.Y / 2, 0))
		finishReturn(self)
		return
	end
	steerTo(self, point)
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

-- Applies damage from a player (or nil for environment). Returns the HP removed.
function Monster.TakeDamage(self: Monster, amount: number, source: Player?): number
	if self.state == "dead" or self.invulnerable or amount <= 0 then
		return 0
	end
	local dealt = math.min(self.hp, amount)
	setHp(self, self.hp - dealt)
	if source then
		self.lastHit = os.clock()
		self.damageBy[source] = (self.damageBy[source] or 0) + dealt
		self.threat[source] = (self.threat[source] or 0) + dealt
		engage(self, source)
	end
	if self.hp <= 0 then
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
	if self.state == "dead" or self.state == "return" then
		return
	end
	self.threat[player] = (self.threat[player] or 0) + amount
	engage(self, player)
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
	self.model:Destroy()
end

return Monster
