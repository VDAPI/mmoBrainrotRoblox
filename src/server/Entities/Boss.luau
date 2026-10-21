--!strict
-- A dungeon boss (DESIGN §16) on top of a Monster (model, threat, chase and basic attacks come from
-- Entities/Monster). This module adds:
--   * phases by HP thresholds (Data/Bosses), with a per-boss script hook (Entities/BossScripts/<id>),
--   * the attack schedule: telegraphed areas on chosen targets, resolved after the windup,
--   * summons when a phase starts (optionally repeated, optionally shielding the boss while alive); helpers attack
--     the fighters at once and drop nothing; a shielded boss holds still at the arena centre without attacking,
--   * phase haste and the enrage after `enrageAfter` seconds,
--   * the Phase attribute (clients tint the look per Data/MonsterLooks phases, S24),
--   * FIX 2026-10-15 (owner): BossTuning.extra: a shielded boss keeps casting at the fighters from the centre (it
--     cannot be hurt, but it does not stand idle), and a boss nobody stands next to (kiting) throws a ranged attack.
--   * S134 (bosses 2.0, Logic/BossMechanics): no scaling with the party (HP and helpers fixed); big blows to dodge
--     (`avoid`: a thicker rim, the same telegraph and hit) and three party mechanics: `split` (the blow is shared by
--     everyone standing in the golden circle at the hit, nobody inside = `missAll` on every fighter), `mark` (a random
--     fighter is branded, the circle follows them and blasts at their position after `seconds`) and `channel` (the boss
--     stands; `breakPct` of its max HP dealt in time staggers it, otherwise the spell hits every fighter). The server
--     counts every hit at the blow; the clients only draw.
--   * S159 (owner 2026-10-21): dodgeable hazards (Data/BossTuning.patterns, HazardService): an attack may deliver its
--     damage by a pattern of projectiles / waves instead of its area (`replace`), be followed by one (`add`), and the
--     later phases add patterns on their own timers (`ambient`); the shield and kiting casts may be patterns too.
-- Services are injected (DungeonService), so the module never requires them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossMechanics = require(ReplicatedStorage.Shared.Logic.BossMechanics)
local BossScaling = require(ReplicatedStorage.Shared.Logic.BossScaling)
local BossSchedule = require(ReplicatedStorage.Shared.Logic.BossSchedule)
local BossTuning = require(ReplicatedStorage.Shared.Data.BossTuning)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local HazardPatterns = require(ReplicatedStorage.Shared.Data.HazardPatterns)
local Hazards = require(ReplicatedStorage.Shared.Logic.Hazards)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)

local Boss = {}
Boss.__index = Boss

export type Services = {
	spawnCustom: (def: Monsters.MonsterDef, variant: any, level: number, at: CFrame) -> any,
	spawnMonster: (monsterId: string, level: number, at: CFrame, attributes: { [string]: any }?) -> any,
	despawn: (monster: any) -> (),
	-- S134: opts = CombatService.TelegraphOpts / ResolveOpts (mechanics)
	telegraph: (monster: any, ability: any, area: CFrame, opts: any?) -> (),
	resolve: (monster: any, ability: any, area: CFrame, opts: any?) -> (),
	-- S134: an unbroken channel's blast on the clients (CombatService.MonsterBlow)
	blow: (monster: any, ability: any, area: CFrame) -> (),
	-- S134: a mark gone before its blast: its circle and glow stop on the clients (CombatService.MonsterTelegraphCancel)
	cancelMark: (monster: any, ability: any, player: Player) -> (),
	-- S159: a dodgeable hazard pattern (CombatService.MonsterHazard -> HazardService.Cast); nil = no hazards (the
	-- attack falls back to its area)
	hazard: ((monster: any, patternId: string, opts: any) -> number?)?,
	-- Players currently fighting (alive, inside the arena).
	fighters: () -> { Player },
	position: (player: Player) -> Vector3?,
	announce: (key: string, args: { [string]: any }?) -> (),
	-- S134: a big message to some players only (the marked one and the rest)
	announceTo: (players: { Player }, key: string, args: { [string]: any }?) -> (),
	nameOf: (player: Player) -> string,
}

-- S134: a mark in flight (the blast comes at `at`).
type Mark = { player: Player, attack: Bosses.Attack, ability: any, at: number }
-- S134: the channel the boss is casting.
type Channel = { attack: Bosses.Attack, ability: any, startHp: number, endsAt: number }

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
		nextSummon: { [number]: number },
		baseAttack: number,
		baseInterval: number,
		random: Random,
		nextShieldCast: number,
		nextFar: number,
		farSince: number?,
		marks: { Mark },
		channel: Channel?,
		staggerUntil: number,
		-- S159: the next cast of each ambient pattern (index of BossTuning.patterns[id].ambient)
		nextAmbient: { [number]: number },
	},
	Boss
))

-- S87: the gap between two attacks of any kind lives in Data/BossTuning.globalGap (balance plan D3).

-- S159: helpers defined further down (ambient patterns, the kiting punisher's target, the pattern pose).
local hold: (self: any, seconds: number) -> ()
local farthest: (self: any) -> { Player }
local stepAmbient: (self: any, now: number) -> boolean

-- S134: the same kind for every party (BossScaling.hpMultiplier() = Bosses.HP_BASE).
local function kindFor(def: Bosses.BossDef): Monsters.MonsterDef
	return {
		id = def.id,
		region = 0,
		cave = true,
		levels = { min = def.level, max = def.level },
		hpMul = BossScaling.hpMultiplier() * (def.hpMul or 1),
		atkMul = def.atkMul,
		defMul = def.defMul,
		mresMul = def.mresMul or 1, -- S66
		dodge = 0, -- S66: bosses never dodge
		family = def.family, -- S66 (S67 reads monster.def.family)
		defence = nil,
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

-- S134: the boss does not know the party size (DungeonService logs it).
function Boss.new(def: Bosses.BossDef, centre: CFrame, services: Services): Boss
	local scriptModule = script.Parent:FindFirstChild("BossScripts")
		and (script.Parent :: any).BossScripts:FindFirstChild(def.id)
	local bossScript: Script = if scriptModule then (require :: any)(scriptModule) else {}
	local monster = services.spawnCustom(kindFor(def), "boss", def.level, centre)
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
		nextSummon = {},
		baseAttack = monster.stats.attack,
		baseInterval = monster.stats.attackInterval,
		random = Random.new(),
		nextShieldCast = 0,
		nextFar = 0,
		farSince = nil,
		marks = {},
		channel = nil,
		staggerUntil = 0,
		nextAmbient = {},
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
	local count = summon.count -- S134: the same helpers for every party
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + self.random:NextNumber()
		local radius = 14 + self.random:NextNumber() * 6
		local at = self.centre * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		-- S117: the attribute Summoned lets the clients raise it out of the ground (looks only; set before it replicates)
		local monster = self.services.spawnMonster(summon.monster, summon.level, at, { Summoned = true })
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

-- S159: the players an attack aims at (the same choice as targetsFor; `self` attacks aim at nobody).
local function targetPlayersFor(self: Boss, target: string, count: number?): { Player }
	local fighters = self.services.fighters()
	if #fighters == 0 or target == "self" then
		return {}
	elseif target == "threat" then
		local t = self.monster.target
		return if t and table.find(fighters, t) then { t } else { fighters[1] }
	elseif target == "all" then
		return table.clone(fighters)
	elseif target == "nearest" then
		local root = self.monster.root :: BasePart
		local best, bestDistance = nil, math.huge
		for _, player in fighters do
			local p = self.services.position(player)
			if p and (p - root.Position).Magnitude < bestDistance then
				best, bestDistance = player, (p - root.Position).Magnitude
			end
		end
		return if best then { best } else {}
	end
	local pool = table.clone(fighters)
	local list = {}
	for _ = 1, math.min(count or 1, #pool) do
		table.insert(list, table.remove(pool, self.random:NextInteger(1, #pool)) :: Player)
	end
	return list
end

-- S159: the boss's ground point (the origin of its patterns).
local function groundOf(self: Boss): Vector3
	local root = self.monster.root :: BasePart
	local humanoid = self.monster.humanoid :: Humanoid
	return Vector3.new(root.Position.X, root.Position.Y - humanoid.HipHeight - root.Size.Y / 2, root.Position.Z)
end

-- S159: the bounce circle of the boss's arena.
local function arenaOf(self: Boss): { x: number, z: number, r: number }
	local r = if self.def.world then BossTuning.arenaRadius.world else BossTuning.arenaRadius.dungeon
	return { x = self.centre.Position.X, z = self.centre.Position.Z, r = r }
end

-- S159: casts a hazard pattern of the boss (HazardService). `targets` aim it, `origin` defaults to the boss's ground,
-- `delay` = the least warning (the boss's pose lasts as long), `attackId` = the client's pose and sound. True when it
-- went out.
local function castPattern(
	self: Boss,
	patternId: string,
	damage: number,
	targets: { Player },
	delay: number?,
	attackId: string,
	element: string?,
	damageKind: string?,
	origin: Vector3?
): boolean
	local hazard = self.services.hazard
	if not hazard or not HazardPatterns.get(patternId) then
		return false
	end
	local id = hazard(self.monster, patternId, {
		origin = origin or groundOf(self),
		targets = targets,
		damage = damage,
		element = element,
		damageKind = damageKind,
		delay = delay,
		arena = arenaOf(self),
		attackId = attackId,
		windup = delay,
	})
	return id ~= nil
end

-- S159: the warning of a pattern's first emitter (an ambient cast's pose).
local function patternWarn(patternId: string): number
	local pattern = HazardPatterns.get(patternId)
	local first = pattern and pattern.emitters[1]
	return math.max(Hazards.MIN_WARN, if first and first.delay then first.delay else Hazards.MIN_WARN)
end

-- S159: this boss's BossTuning.patterns entry (nil = none).
local function tuningOf(self: Boss): any
	return (BossTuning.patterns :: any)[self.def.id]
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

-- S134 mark: a random fighter carries a circle for `mark.seconds` (the telegraph follows the character, `f` in the
-- "tele" event; no red zone); Step blasts it at the marked one's position then. A big message to the marked one and
-- to the rest; the attribute BossMark marks the character for the clients. S149: `mark.count` fighters at once
-- (Logic/BossMechanics.pickMarked, without repeats), each with its own circle and blast.
local function startMark(self: Boss, attack: Bosses.Attack, ability: any)
	local fighters = self.services.fighters()
	if #fighters == 0 or not attack.mark then
		return
	end
	local markAbility = table.clone(ability)
	markAbility.windup = attack.mark.seconds
	local marked: { Player } = {}
	local names: { string } = {}
	local picks = BossMechanics.pickMarked(
		#fighters,
		BossMechanics.markCount(attack.mark),
		function(lo: number, hi: number): number
			return self.random:NextInteger(lo, hi)
		end
	)
	for _, index in picks do
		local player = fighters[index]
		local position = self.services.position(player)
		if position then
			local character = player.Character
			if character then
				character:SetAttribute("BossMark", attack.id)
			end
			table.insert(
				self.marks,
				{ player = player, attack = attack, ability = markAbility, at = os.clock() + attack.mark.seconds }
			)
			self.services.telegraph(
				self.monster,
				markAbility,
				areaFor(self, attack, position),
				{ mechanic = "mark", follow = player, castWindup = attack.windup }
			)
			table.insert(marked, player)
			table.insert(names, self.services.nameOf(player))
		end
	end
	if #marked == 0 then
		return
	end
	self.services.announceTo(marked, "boss.mechanic.mark.you", nil)
	local others = {}
	for _, other in fighters do
		if not table.find(marked, other) then
			table.insert(others, other)
		end
	end
	if #others > 0 then
		if #names == 1 then
			self.services.announceTo(others, "boss.mechanic.mark.other", { name = names[1] })
		else
			self.services.announceTo(others, "boss.mechanic.mark.others", { names = table.concat(names, ", ") })
		end
	end
end

local function clearMark(mark: Mark)
	local character = mark.player.Character
	if character and character:GetAttribute("BossMark") == mark.attack.id then
		character:SetAttribute("BossMark", nil)
	end
end

-- S134: a mark that will not blast (the marked one is gone, the boss died or is removed): the attribute goes and the
-- clients drop its circle.
local function cancelMark(self: Boss, mark: Mark)
	clearMark(mark)
	self.services.cancelMark(self.monster, mark.ability, mark.player)
end

-- S134: drops every mark in flight and the channel (the boss died, won or removed: no blast, no spell).
function Boss.ClearMechanics(self: Boss)
	for _, mark in self.marks do
		cancelMark(self, mark)
	end
	self.marks = {}
	self.channel = nil
end

-- S134 channel: the boss stands for `channel.seconds` (no telegraph to dodge; the "tele" event with m = "channel"
-- only poses it on the clients) and remembers its HP; Step checks the break every tick. Never behind the shield.
local function startChannel(self: Boss, attack: Bosses.Attack, ability: any)
	local spec = attack.channel
	if not spec or #self.shielded > 0 then
		return
	end
	local monster = self.monster
	local now = os.clock()
	monster.state = "cast"
	monster.castEnd = now + spec.seconds
	monster.castArea = nil
	self.channel = { attack = attack, ability = ability, startHp = monster.hp, endsAt = now + spec.seconds }
	self.services.telegraph(monster, ability, areaFor(self, attack, nil), { mechanic = "channel" })
	self.services.announce("boss.mechanic.channel.start", { boss = `@{self.def.nameKey}` })
end

-- S134: the marks and the channel, once per tick.
local function stepMechanics(self: Boss, now: number)
	local monster = self.monster
	if #self.marks > 0 then
		local fighters = self.services.fighters()
		for i = #self.marks, 1, -1 do
			local mark = self.marks[i]
			-- death or leaving the arena before the blast: the mark is gone
			if not table.find(fighters, mark.player) then
				cancelMark(self, mark)
				table.remove(self.marks, i)
			elseif now >= mark.at then
				table.remove(self.marks, i)
				clearMark(mark)
				local position = self.services.position(mark.player)
				if position and mark.attack.mark then
					self.services.resolve(
						monster,
						mark.ability,
						areaFor(self, mark.attack, position),
						{ marked = mark.player, markSelf = mark.attack.mark.self }
					)
				end
			end
		end
	end
	local channel = self.channel
	if channel then
		local spec = channel.attack.channel :: Bosses.ChannelSpec
		if #self.shielded > 0 then
			-- a shield wave began in the spell: it fizzles
			self.channel = nil
		elseif BossMechanics.channelBroken(channel.startHp, monster.hp, monster.stats.maxHp, spec.breakPct) then
			self.channel = nil
			self.staggerUntil = now + spec.stagger
			monster.state = "cast"
			monster.castEnd = now + spec.stagger
			monster.castArea = nil
			monster.model:SetAttribute("Staggered", true)
			self.nextGlobal = math.max(self.nextGlobal, now + spec.stagger)
			self.services.announce("boss.mechanic.channel.broken", { boss = `@{self.def.nameKey}` })
		elseif now >= channel.endsAt then
			self.channel = nil
			local area = CFrame.new(monster.root.Position)
			self.services.resolve(monster, channel.ability, area, { all = true, fighters = self.services.fighters() })
			self.services.blow(monster, channel.ability, area)
			self.services.announce("boss.mechanic.channel.failed", { boss = `@{self.def.nameKey}` })
		end
	end
	if self.staggerUntil > 0 and now >= self.staggerUntil then
		self.staggerUntil = 0
		monster.model:SetAttribute("Staggered", nil)
	end
end

-- S134: the channel the boss is casting for the fight state (`{"boss"}.channel`): need and done as shares of the
-- max HP, the end in seconds of os.clock (DungeonService turns it into server time). nil without one.
function Boss.ChannelState(self: Boss): { id: string, endsAt: number, need: number, done: number }?
	local channel = self.channel
	local spec = channel and channel.attack.channel
	if not channel or not spec then
		return nil
	end
	local monster = self.monster
	return {
		id = channel.attack.id,
		endsAt = channel.endsAt,
		need = spec.breakPct,
		done = BossMechanics.channelDone(channel.startHp, monster.hp, monster.stats.maxHp),
	}
end

-- S134: the boss is staggered after a broken channel.
function Boss.IsStaggered(self: Boss): boolean
	return self.staggerUntil > 0
end

-- S134: the telegraph options of an attack (the client's colour, rim and follow; mechanics never enter redZones but
-- the split, which is an area to stand in).
local function teleOpts(attack: Bosses.Attack): any?
	if attack.mechanic == "split" then
		return { mechanic = "split" }
	elseif BossMechanics.isAvoidable(attack) then
		return { mechanic = "avoid" }
	end
	return nil
end

local function cast(self: Boss, attack: Bosses.Attack, keepState: boolean?)
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
		delivery = attack.delivery,
	}
	-- The boss stands still while it winds up (Monster "cast" state without its own ability); a held (shielded) boss
	-- keeps its endless hold.
	if not keepState then
		monster.state = "cast"
		monster.castEnd = os.clock() + attack.windup
		monster.castArea = nil
		monster.humanoid:MoveTo(monster.root.Position)
	end
	-- S134: the mark and the channel have their own flow (Step resolves them)
	if attack.mechanic == "mark" and attack.mark then
		startMark(self, attack, ability)
		return
	elseif attack.mechanic == "channel" and attack.channel then
		startChannel(self, attack, ability)
		return
	end
	-- S159: an attack delivered by a dodgeable pattern instead of its area (same numbers, one hit per player)
	local tuning = tuningOf(self)
	local replaced = tuning and tuning.replace and tuning.replace[attack.id]
	if replaced and attack.mechanic == nil then
		local targets = targetPlayersFor(self, attack.target, attack.count)
		if
			castPattern(
				self,
				replaced,
				attack.damage,
				targets,
				attack.windup,
				attack.id,
				attack.element,
				attack.damageKind
			)
		then
			return
		end
	end
	local opts = teleOpts(attack)
	if attack.mechanic == "split" then
		self.services.announce("boss.mechanic.split.hint", nil)
	end
	local areas = {}
	for _, position in targetsFor(self, attack) do
		local area = areaFor(self, attack, position)
		table.insert(areas, area)
		self.services.telegraph(monster, ability, area, opts)
	end
	-- S159: a pattern that follows the blow (the leap's shock ring, the whirlwind's axes), live from the blow
	local follow = tuning and tuning.add and tuning.add[attack.id]
	if follow and areas[1] then
		local origin = if follow.at == "area" then areas[1].Position else groundOf(self)
		castPattern(
			self,
			follow.pattern,
			follow.damage,
			targetPlayersFor(self, "random", 1),
			attack.windup,
			follow.pattern,
			attack.element,
			attack.damageKind,
			origin
		)
	end
	task.delay(attack.windup, function()
		if not monster:IsAlive() then
			return
		end
		-- S134: a split blow is shared by everyone inside; nobody inside = missAll on every fighter (CombatService)
		local resolveOpts = if attack.mechanic == "split" and attack.split
			then { split = true, missAll = attack.split.missAll, fighters = self.services.fighters() }
			else nil
		for _, area in areas do
			self.services.resolve(monster, ability, area, resolveOpts)
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

-- A BossTuning.extra entry as a Data/Bosses attack aimed at a random fighter (the id is the look's attack id).
local function extraAttack(spec: any): Bosses.Attack
	return {
		id = spec.look,
		shape = spec.shape,
		target = "random",
		radius = spec.radius,
		length = spec.length,
		width = spec.width,
		windup = spec.windup,
		damage = spec.damage,
		cooldown = spec.cooldown or spec.every or 5,
		phases = { 1, 2, 3 },
	} :: any
end

-- S159: the boss stands for `seconds` (a pattern's warning: the clients pose its cast).
hold = function(self: Boss, seconds: number)
	local monster = self.monster
	monster.state = "cast"
	monster.castEnd = os.clock() + seconds
	monster.castArea = nil
	monster.humanoid:MoveTo(monster.root.Position)
end

-- S159: the farthest fighter (the kiting punisher's target), as a list.
farthest = function(self: Boss): { Player }
	local root = self.monster.root :: BasePart
	local best, bestDistance = nil, -1
	for _, player in self.services.fighters() do
		local p = self.services.position(player)
		if p and (p - root.Position).Magnitude > bestDistance then
			best, bestDistance = player, (p - root.Position).Magnitude
		end
	end
	return if best then { best } else {}
end

-- S159: casts the first due ambient pattern of the phase (BossTuning.patterns[id].ambient); true when one went out.
-- The first one of a phase waits half its timer after the phase starts.
stepAmbient = function(self: Boss, now: number): boolean
	local tuning = tuningOf(self)
	local list = tuning and tuning.ambient
	if not list then
		return false
	end
	for i, entry in list do
		if not table.find(entry.phases, self.phase) then
			continue
		end
		local due = self.nextAmbient[i]
		if not due then
			self.nextAmbient[i] = now + entry.every * 0.5
			continue
		end
		if now < due then
			continue
		end
		self.nextAmbient[i] = now + entry.every
		local warn = patternWarn(entry.pattern)
		local targets = if entry.centre
			then targetPlayersFor(self, "random", 1)
			else targetPlayersFor(self, "random", entry.count or 1)
		local origin = if entry.centre
			then Vector3.new(self.centre.Position.X, groundOf(self).Y, self.centre.Position.Z)
			else nil
		local element = nil
		for _, attack in self.def.attacks do
			element = element or attack.element
		end
		hold(self, warn)
		if
			castPattern(
				self,
				entry.pattern,
				entry.damage,
				targets,
				warn,
				entry.pattern,
				element,
				self.def.damageKind,
				origin
			)
		then
			self.nextGlobal = now + warn + BossTuning.globalGap
			return true
		end
	end
	return false
end

-- Whether no fighter stands within BossTuning.farRange of the boss (kiting).
local function nobodyNear(self: Boss): boolean
	local root = self.monster.root :: BasePart
	local any = false
	for _, player in self.services.fighters() do
		local p = self.services.position(player)
		if p then
			any = true
			if (p - root.Position).Magnitude <= BossTuning.farRange then
				return false
			end
		end
	end
	return any
end

-- One tick (DungeonService calls it ~10x per second).
function Boss.Step(self: Boss, now: number)
	local monster = self.monster
	if not monster:IsAlive() then
		-- S134: a dead boss blasts no mark and finishes no spell
		self:ClearMechanics()
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
	stepMechanics(self, now)
	local extra = (BossTuning.extra :: any)[self.def.id]
	-- Behind the helpers' shield: no schedule, but the shield attack keeps coming (FIX 2026-10-15).
	if #self.shielded > 0 then
		if extra and extra.shield and now >= self.nextShieldCast then
			if self.nextShieldCast == 0 then
				self.nextShieldCast = now + 2 -- a breath after the shield goes up
			else
				self.nextShieldCast = now + extra.shield.every
				-- S159: the shield cast as a dodgeable pattern when it has one
				local spec = extra.shield
				if
					not spec.pattern
					or not castPattern(
						self,
						spec.pattern,
						spec.damage,
						targetPlayersFor(self, "random", 1),
						spec.windup,
						spec.pattern,
						nil,
						nil
					)
				then
					cast(self, extraAttack(spec), true)
				end
			end
		end
		return
	end
	self.nextShieldCast = 0
	-- Kiting: nobody next to the boss for a while = the ranged attack first (FIX 2026-10-15).
	if extra and extra.far then
		if nobodyNear(self) then
			self.farSince = self.farSince or now
		else
			self.farSince = nil
		end
	end
	-- Attacks (only while chasing and not already casting)
	if monster.state ~= "chase" or now < self.nextGlobal then
		return
	end
	local since = self.farSince
	if extra and extra.far and since and now - since >= BossTuning.farAfter and now >= self.nextFar then
		local attack = extraAttack(extra.far)
		self.nextFar = now + attack.cooldown
		self.nextGlobal = now + attack.windup + BossTuning.globalGap
		-- S159: the kiting punisher as a dodgeable pattern at the farthest fighter
		local spec = extra.far
		if spec.pattern then
			hold(self, attack.windup)
			if castPattern(self, spec.pattern, spec.damage, farthest(self), attack.windup, spec.pattern, nil, nil) then
				return
			end
		end
		cast(self, attack)
		return
	end
	-- S159: an ambient pattern of the phase that is due goes first (it shares the global gap)
	if stepAmbient(self, now) then
		return
	end
	-- S87 (balance plan D3, G11): the most overdue attack relative to its cooldown (Logic/BossSchedule, also the model).
	local attack =
		BossSchedule.pick(BossSchedule.ready(self.def.attacks, self.phase, now, self.nextAttack), now, self.nextAttack)
	if attack then
		self.nextAttack[attack.id] = now + attack.cooldown -- same effective cooldown as BossSchedule
		self.nextGlobal = now + attack.windup + BossTuning.globalGap
		cast(self, attack)
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
	self:ClearMechanics()
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
