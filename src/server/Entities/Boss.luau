--!strict
-- A dungeon boss (DESIGN §16) on top of a Monster (model, threat, chase and basic attacks come from
-- Entities/Monster). This module adds:
--   * phases by HP thresholds (Data/Bosses), with a per-boss script hook (Entities/BossScripts/<id>),
--   * the attack schedule: telegraphed areas on chosen targets, resolved after the windup,
--   * summons when a phase starts (optionally repeated, optionally shielding the boss while alive); helpers attack
--     the fighters at once and drop nothing; a shielded boss holds still at the arena centre without attacking,
--   * phase haste and the enrage after `enrageAfter` seconds,
--   * the Phase attribute (clients tint the look per Data/MonsterLooks phases, S24).
-- Services are injected (DungeonService), so the module never requires them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)

local Boss = {}
Boss.__index = Boss

export type Services = {
	spawnCustom: (def: Monsters.MonsterDef, variant: any, level: number, at: CFrame) -> any,
	spawnMonster: (monsterId: string, level: number, at: CFrame) -> any,
	despawn: (monster: any) -> (),
	telegraph: (monster: any, ability: any, area: CFrame) -> (),
	resolve: (monster: any, ability: any, area: CFrame) -> (),
	-- Players currently fighting (alive, inside the arena).
	fighters: () -> { Player },
	position: (player: Player) -> Vector3?,
	announce: (key: string, args: { [string]: any }?) -> (),
}

export type Script = {
	onPhase: ((boss: any, phase: number) -> ())?,
	onEnrage: ((boss: any) -> ())?,
	-- Every boss tick (arena hazards); `now` is os.clock().
	onTick: ((boss: any, now: number) -> ())?,
	-- Cleanup of script-made objects when the boss is removed.
	onDestroy: ((boss: any) -> ())?,
}

export type Boss = typeof(setmetatable(
	{} :: {
		def: Bosses.BossDef,
		monster: any,
		services: Services,
		script: Script,
		centre: CFrame,
		phase: number,
		startedAt: number,
		enraged: boolean,
		nextAttack: { [string]: number },
		nextGlobal: number,
		summons: { any },
		shielded: { any },
		players: number,
		nextSummon: { [number]: number },
		baseAttack: number,
		baseInterval: number,
		random: Random,
	},
	Boss
))

local GLOBAL_GAP = 2.2 -- seconds between two attacks of any kind

local function kindFor(def: Bosses.BossDef, players: number): Monsters.MonsterDef
	return {
		id = def.id,
		region = 0,
		cave = true,
		levels = { min = def.level, max = def.level },
		hpMul = BossScaling.hpMultiplier(players) * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		speed = def.speed,
		moveSpeed = def.moveSpeed,
		attack = def.attack,
		damageKind = def.damageKind,
		range = def.range,
		element = nil,
		passive = false,
		elites = false,
		ability = nil,
		lootTable = def.id,
		size = def.look.size,
		aura = def.look.aura,
		nameKeys = { normal = def.nameKey, elite = def.nameKey, elite2 = def.nameKey, boss = def.nameKey } :: any,
	}
end

function Boss.new(def: Bosses.BossDef, players: number, centre: CFrame, services: Services): Boss
	local scriptModule = script.Parent:FindFirstChild("BossScripts")
		and (script.Parent :: any).BossScripts:FindFirstChild(def.id)
	local bossScript: Script = if scriptModule then (require :: any)(scriptModule) else {}
	local monster = services.spawnCustom(kindFor(def, players), "boss", def.level, centre)
	monster.isBoss = true
	monster.leashRange = 400
	local self = setmetatable({
		def = def,
		monster = monster,
		services = services,
		script = bossScript,
		centre = centre,
		phase = 1,
		startedAt = os.clock(),
		enraged = false,
		nextAttack = {},
		nextGlobal = os.clock() + 4,
		summons = {},
		shielded = {},
		players = math.max(1, players),
		nextSummon = {},
		baseAttack = monster.stats.attack,
		baseInterval = monster.stats.attackInterval,
		random = Random.new(),
	}, Boss)
	for _, attack in def.attacks do
		self.nextAttack[attack.id] = os.clock() + 3 + self.random:NextNumber() * 4
	end
	return self
end

function Boss.IsAlive(self: Boss): boolean
	return self.monster:IsAlive()
end

function Boss.HpFraction(self: Boss): number
	return math.max(0, self.monster.hp) / math.max(1, self.monster.stats.maxHp)
end

local function applySpeed(self: Boss)
	local haste = (self.def.haste or {})[self.phase] or 1
	self.monster.stats.attackInterval = self.baseInterval / haste
	self.monster:RefreshSpeed(haste)
	self.monster.stats.attack = self.baseAttack * (if self.enraged then self.def.enrageDamage else 1)
end

-- Helpers go straight for the fighters (spread over them) instead of waiting to be hit.
local function engageFighters(self: Boss, monster: any)
	for _, player in self.services.fighters() do
		monster:AddThreat(player, 1 + self.random:NextNumber())
	end
end

-- While shielded the boss stands at the arena centre and neither moves nor attacks (a Monster "cast" state that
-- never ends); `hold = false` gives it back to the chase.
local function holdStill(self: Boss, hold: boolean)
	local monster = self.monster
	local root = monster.root :: BasePart
	local humanoid = monster.humanoid :: Humanoid
	if hold then
		if monster.state ~= "cast" or monster.castEnd ~= math.huge then
			monster.state = "cast"
			monster.castArea = nil
			monster.castEnd = math.huge
			monster.model:PivotTo(
				CFrame.new(self.centre.Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
					* root.CFrame.Rotation
			)
		end
		humanoid:MoveTo(root.Position)
	elseif monster.state == "cast" and monster.castEnd == math.huge then
		monster.castEnd = 0
		monster.state = "chase"
	end
end

local function spawnSummons(self: Boss, summon: Bosses.Summon)
	local count = summon.count + Bosses.SUMMON_PER_PLAYER * (self.players - 1)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + self.random:NextNumber()
		local radius = 14 + self.random:NextNumber() * 6
		local at = self.centre * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local monster = self.services.spawnMonster(summon.monster, summon.level, at)
		if monster then
			monster.summoned = true
			monster.leashRange = self.monster.leashRange
			table.insert(self.summons, monster)
			if summon.shield then
				table.insert(self.shielded, monster)
			end
			engageFighters(self, monster)
		end
	end
	if summon.shield and #self.shielded > 0 then
		self.monster.invulnerable = true
		self.monster.model:SetAttribute("Shielded", true)
		holdStill(self, true)
	end
end

-- Forces a phase (admin /phase); also used internally when HP crosses a threshold.
function Boss.SetPhase(self: Boss, phase: number)
	if phase == self.phase or phase < 1 or phase > #self.def.phases + 1 then
		return
	end
	self.phase = phase
	self.monster.model:SetAttribute("Phase", phase)
	for _, summon in self.def.summons do
		if summon.phase == phase then
			spawnSummons(self, summon)
			if summon.every then
				self.nextSummon[phase] = os.clock() + summon.every
			end
		end
	end
	applySpeed(self)
	self.services.announce(`boss.{self.def.id}.phase{phase}`, nil)
	if self.script.onPhase then
		self.script.onPhase(self, phase)
	end
end

-- Area of an attack aimed at `targetPosition` (ground level).
local function areaFor(self: Boss, attack: Bosses.Attack, targetPosition: Vector3?): CFrame
	local root = self.monster.root :: BasePart
	local humanoid = self.monster.humanoid :: Humanoid
	local groundY = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local from = Vector3.new(root.Position.X, groundY, root.Position.Z)
	if attack.target == "self" or not targetPosition then
		return CFrame.new(from)
	end
	local to = Vector3.new(targetPosition.X, groundY, targetPosition.Z)
	if attack.shape == "cone" or attack.shape == "line" then
		if (to - from).Magnitude < 0.1 then
			return CFrame.new(from)
		end
		return CFrame.lookAt(from, to)
	end
	return CFrame.new(to)
end

local function targetsFor(self: Boss, attack: Bosses.Attack): { Vector3? }
	local fighters = self.services.fighters()
	if #fighters == 0 then
		return {}
	end
	if attack.target == "self" then
		return { nil }
	elseif attack.target == "threat" then
		local target = self.monster.target
		return { if target then self.services.position(target) else nil }
	elseif attack.target == "all" then
		local list = {}
		for _, player in fighters do
			table.insert(list, self.services.position(player))
		end
		return list
	elseif attack.target == "nearest" then
		local root = self.monster.root :: BasePart
		local best, bestDistance = nil, math.huge
		for _, player in fighters do
			local p = self.services.position(player)
			if p and (p - root.Position).Magnitude < bestDistance then
				best, bestDistance = p, (p - root.Position).Magnitude
			end
		end
		return { best }
	end
	-- random (without repeats)
	local pool = table.clone(fighters)
	local list = {}
	for _ = 1, math.min(attack.count or 1, #pool) do
		local player = table.remove(pool, self.random:NextInteger(1, #pool)) :: Player
		table.insert(list, self.services.position(player))
	end
	return list
end

local function cast(self: Boss, attack: Bosses.Attack)
	local monster = self.monster
	local ability = {
		id = attack.id,
		shape = attack.shape,
		origin = "self",
		radius = attack.radius,
		inner = attack.inner,
		angle = attack.angle,
		length = attack.length,
		width = attack.width,
		windup = attack.windup,
		damage = attack.damage,
		cooldown = attack.cooldown,
		element = attack.element,
		damageKind = attack.damageKind,
	}
	-- The boss stands still while it winds up (Monster "cast" state without its own ability).
	monster.state = "cast"
	monster.castEnd = os.clock() + attack.windup
	monster.castArea = nil
	monster.humanoid:MoveTo(monster.root.Position)
	local areas = {}
	for _, position in targetsFor(self, attack) do
		local area = areaFor(self, attack, position)
		table.insert(areas, area)
		self.services.telegraph(monster, ability, area)
	end
	task.delay(attack.windup, function()
		if not monster:IsAlive() then
			return
		end
		for _, area in areas do
			self.services.resolve(monster, ability, area)
		end
		if attack.leap and areas[1] then
			local root = monster.root :: BasePart
			local humanoid = monster.humanoid :: Humanoid
			monster.model:PivotTo(
				CFrame.new(areas[1].Position + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
					* root.CFrame.Rotation
			)
		end
	end)
end

-- One tick (DungeonService calls it ~10x per second).
function Boss.Step(self: Boss, now: number)
	local monster = self.monster
	if not monster:IsAlive() then
		return
	end
	-- Phase by HP
	local phase = BossScaling.phaseFor(self:HpFraction(), self.def.phases)
	if phase > self.phase then
		for p = self.phase + 1, phase do
			self:SetPhase(p)
		end
	end
	-- Shield summons
	if #self.shielded > 0 then
		local alive = {}
		for _, summon in self.shielded do
			if summon:IsAlive() then
				table.insert(alive, summon)
			end
		end
		self.shielded = alive
		if #alive == 0 then
			monster.invulnerable = false
			monster.model:SetAttribute("Shielded", nil)
			holdStill(self, false)
			self.services.announce(`boss.{self.def.id}.shieldDown`, nil)
		else
			-- A stun could have released it; keep it in place.
			holdStill(self, true)
		end
	end
	-- Repeating summons
	for _, summon in self.def.summons do
		local due = self.nextSummon[summon.phase]
		if summon.every and self.phase == summon.phase and due and now >= due then
			self.nextSummon[summon.phase] = now + summon.every
			spawnSummons(self, summon)
		end
	end
	-- Enrage
	if not self.enraged and now - self.startedAt >= self.def.enrageAfter then
		self.enraged = true
		monster.model:SetAttribute("Enraged", true)
		applySpeed(self)
		self.services.announce(`boss.{self.def.id}.enrage`, nil)
		if self.script.onEnrage then
			self.script.onEnrage(self)
		end
	end
	if self.script.onTick then
		self.script.onTick(self, now)
	end
	-- Attacks (only while chasing and not already casting; never behind the helpers' shield)
	if #self.shielded > 0 or monster.state ~= "chase" or now < self.nextGlobal then
		return
	end
	for _, attack in self.def.attacks do
		if table.find(attack.phases, self.phase) and now >= (self.nextAttack[attack.id] or 0) then
			self.nextAttack[attack.id] = now + attack.cooldown
			self.nextGlobal = now + attack.windup + GLOBAL_GAP
			cast(self, attack)
			return
		end
	end
end

-- Hits every fighter standing in `area` with a telegraph-less attack (scripted hazards).
function Boss.Hazard(self: Boss, ability: any, area: CFrame)
	self.services.resolve(self.monster, ability, area)
end

-- Removes the boss and every summon (reset or cleanup after the kill).
function Boss.Destroy(self: Boss)
	if self.script.onDestroy then
		self.script.onDestroy(self)
	end
	for _, summon in self.summons do
		if summon:IsAlive() then
			self.services.despawn(summon)
		end
	end
	self.summons = {}
	if self.monster:IsAlive() then
		self.services.despawn(self.monster)
	end
end

-- Living summons (cleared after a win).
function Boss.Summons(self: Boss): { any }
	return self.summons
end

return Boss
