--!strict
-- One monster: model, stats, threat table and AI (DESIGN §15.1).
--   idle   : wander within Combat.wanderRadius of the spawn point, look for players in aggro range
--   chase  : follow the highest-threat valid target; leash at Combat.leashRange from spawn
--   cast   : Elite II special: telegraph for `windup` seconds, then resolve
--   return : walk back to spawn invulnerable with full HP, then idle
--   dead   : waiting for MonsterService to remove the model
-- Damage resolution, telegraphs and rewards are delegated to the Context given by MonsterService, so this
-- module never talks to other services directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Combat = require(Shared.Data.Combat)
local MonsterAbilities = require(Shared.Data.MonsterAbilities)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Monsters = require(Shared.Data.Monsters)
local RigBuilder = require(script.Parent.RigBuilder)

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
	},
	Monster
))

local RETURN_TIMEOUT = 12

function Monster.new(
	def: Monsters.MonsterDef,
	variant: MonsterStats.Variant,
	level: number,
	spawnCFrame: CFrame,
	ctx: Context,
	parent: Instance
): Monster
	local stats = MonsterStats.compute(def, level, variant)
	local model = RigBuilder.build(def, variant, stats.scale)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	model:SetAttribute("MonsterId", def.id)
	model:SetAttribute("Variant", variant)
	model:SetAttribute("Level", stats.level)
	model:SetAttribute("MaxHp", stats.maxHp)
	model:SetAttribute("Hp", stats.maxHp)
	model:PivotTo(spawnCFrame + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
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
	return self.def.nameKeys[self.variant]
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distanceFlat(a: Vector3, b: Vector3): number
	return (flat(a) - flat(b)).Magnitude
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

local function stop(self: Monster)
	self.humanoid:MoveTo(self.root.Position)
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

function Monster.StartReturn(self: Monster)
	self.state = "return"
	self.target = nil
	self.invulnerable = true
	table.clear(self.threat)
	table.clear(self.damageBy)
	setHp(self, self.stats.maxHp)
	self.model:SetAttribute("Returning", true)
	self.humanoid.WalkSpeed = self.def.moveSpeed * Combat.returnSpeedMultiplier * self.speedFactor
	self.returnStarted = os.clock()
	self.humanoid:MoveTo(self.spawnCFrame.Position)
end

local function finishReturn(self: Monster)
	self.state = "idle"
	self.invulnerable = false
	self.model:SetAttribute("Returning", nil)
	self.humanoid.WalkSpeed = self.def.moveSpeed * self.speedFactor
	self.nextWander = os.clock() + 2 + self.random:NextNumber() * 4
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
	end
	if self.state == "idle" then
		self.state = "chase"
		self.target = player
		local now = os.clock()
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
		local point = self.spawnCFrame.Position + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		if not self.ctx.isSafePosition(point) then
			self.humanoid:MoveTo(point)
		end
	end
end

local function stepChase(self: Monster, now: number)
	local position = self.root.Position
	if distanceFlat(position, self.spawnCFrame.Position) > Combat.leashRange then
		self:StartReturn()
		return
	end
	local target = pickTarget(self)
	if not target then
		self:StartReturn()
		return
	end
	self.target = target
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
		self.humanoid:MoveTo(targetPosition)
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
	if distanceFlat(position, self.spawnCFrame.Position) <= 4 then
		finishReturn(self)
		return
	end
	if now - self.returnStarted > RETURN_TIMEOUT then
		self.model:PivotTo(self.spawnCFrame + Vector3.new(0, self.humanoid.HipHeight + self.root.Size.Y / 2, 0))
		finishReturn(self)
		return
	end
	self.humanoid:MoveTo(self.spawnCFrame.Position)
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
	if state == "idle" then
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
		self.damageBy[source] = (self.damageBy[source] or 0) + dealt
		self.threat[source] = (self.threat[source] or 0) + dealt
		engage(self, source)
	end
	if self.hp <= 0 then
		self.state = "dead"
		self.target = nil
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
