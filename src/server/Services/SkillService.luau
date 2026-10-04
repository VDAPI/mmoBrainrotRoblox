--!strict
-- Skills (DESIGN §14): learning (LearnSkill), the 10-slot hotbar (SetHotbar), tree reset with a Scroll of
-- Rebirth (ResetSkills), passives as a StatService modifier source + combat hooks, and casting:
--   CastSkill(skillId, targetId?, aim?) -> validate (learned, alive, not stunned, GCD 0.5 s, cooldown, cost,
--   target, range) -> spend -> Skills/Types/* handler -> SkillFx to players within FX_RADIUS.
-- Cooldowns replicate as state branch `skills` = { cd = { [skillId] = readyAt }, gcd = readyAt, channel? }
-- (server time), so the client draws the cooldown sweep.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Combat = require(Shared.Data.Combat)
local Context = require(script.Parent.Parent.Skills.Context)
local Log = require(Shared.Util.Log)
local Movement = require(script.Parent.Parent.Skills.Types.Movement)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Offense = require(script.Parent.Parent.Skills.Types.Offense)
local SkillData = require(Shared.Data.Skills)
local Skills = require(Shared.Logic.Skills)
local Support = require(script.Parent.Parent.Skills.Types.Support)
local Types = require(Shared.Types)

local log = Log.new("SkillService")

local SkillService = {
	Name = "SkillService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"StatService",
		"ResourceService",
		"CombatService",
		"StatusEffectService",
		"EntityService",
		"PvpService",
		"PartyService",
		"DeathService",
		"InventoryService",
		"ZoneService",
	},
}

local FX_RADIUS = 120
local RANGE_TOLERANCE = 5
local CHANNEL_MOVE_LIMIT = 2.5

local PlayerStateService: any
local CharacterService: any
local StatService: any
local ResourceService: any
local CombatService: any
local StatusEffectService: any
local EntityService: any
local PvpService: any
local PartyService: any
local DeathService: any
local InventoryService: any
local ZoneService: any

type Handler = (ctx: Context.Ctx) -> (boolean, string?)

local HANDLERS: { [string]: Handler } = {}
for _, group in { Offense, Movement, Support } do
	for kind, handler in group do
		HANDLERS[kind] = handler
	end
end

type Runtime = {
	cooldowns: { [string]: number },
	gcd: number,
	channel: { skillId: string, token: number, startedAt: Vector3 }?,
	channelToken: number,
	noCooldowns: boolean,
	infiniteResources: boolean,
}

local runtimes: { [Player]: Runtime } = {}
local hookCache: { [Player]: { [string]: number } } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function runtime(player: Player): Runtime
	local rt = runtimes[player]
	if not rt then
		rt = {
			cooldowns = {},
			gcd = 0,
			channel = nil,
			channelToken = 0,
			noCooldowns = false,
			infiniteResources = false,
		}
		runtimes[player] = rt
	end
	return rt
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

-- Passives ------------------------------------------------------------------------------------------------

local function passiveHooks(player: Player): { [string]: number }
	local cached = hookCache[player]
	if cached then
		return cached
	end
	local char = character(player)
	local hooks = if char then Skills.passiveTotals(char).hooks else {}
	hookCache[player] = hooks
	return hooks
end

function SkillService.PassiveHook(player: Player, id: string): number
	return passiveHooks(player)[id] or 0
end

local function passivesChanged(player: Player)
	hookCache[player] = nil
	StatService.Invalidate(player)
end

type Source = { key: string, flat: { [string]: number }?, pct: { [string]: number }? }

local function modifierSource(_player: Player, char: Types.CharacterData): Source?
	local totals = Skills.passiveTotals(char)
	if next(totals.flat) == nil and next(totals.pct) == nil then
		return nil
	end
	return { key = "source.passives", flat = totals.flat, pct = totals.pct }
end

-- Learning, hotbar, reset -----------------------------------------------------------------------------

local function learn(player: Player, skillId: string): (boolean, string?, any)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, reason, detail = Skills.canLearn(char, skillId)
	if not ok then
		return false, `skills.error.{reason}`, detail
	end
	local level = Skills.level(char, skillId) + 1
	PlayerStateService.Set(player, { "character", "skills", skillId }, level)
	PlayerStateService.Set(player, { "character", "skillPoints" }, char.skillPoints - 1)
	local skill = SkillData.get(skillId)
	if skill and skill.type == "passive" then
		passivesChanged(player)
	end
	QuestEvents.fire(player, "learn", { skillId = skillId })
	return true, nil
end

local function setHotbar(player: Player, slot: number, skillId: string?): (boolean, string?)
	local char = character(player)
	if not char or not Skills.validHotbar(char, slot, skillId) then
		return false, "error.badRequest"
	end
	-- A skill sits in one slot only: moving it clears the old slot.
	if skillId then
		for key, existing in char.hotbar do
			if existing == skillId and key ~= tostring(slot) then
				PlayerStateService.Set(player, { "character", "hotbar", key }, nil)
			end
		end
	end
	PlayerStateService.Set(player, { "character", "hotbar", tostring(slot) }, skillId)
	return true, nil
end

-- Resets the tree. `free` skips the scroll (admin).
function SkillService.Reset(player: Player, free: boolean?): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not free then
		if InventoryService.Count(player, "scroll_skillreset") < 1 then
			return false, "skills.error.noScroll"
		end
		InventoryService.Remove(player, "scroll_skillreset", 1)
	end
	local refunded = Skills.refundAll(char)
	PlayerStateService.Set(player, { "character", "skills" }, char.skills)
	PlayerStateService.Set(player, { "character", "hotbar" }, char.hotbar)
	PlayerStateService.Set(player, { "character", "skillPoints" }, char.skillPoints)
	passivesChanged(player)
	log:info("%s reset skills (%d points)", player.Name, refunded)
	return true, nil
end

-- Admin helpers --------------------------------------------------------------------------------------------

function SkillService.SetNoCooldowns(player: Player, enabled: boolean)
	local rt = runtime(player)
	rt.noCooldowns = enabled
	if enabled then
		table.clear(rt.cooldowns)
		rt.gcd = 0
		PlayerStateService.Set(player, { "skills" }, { cd = {}, gcd = 0 })
	end
end

function SkillService.SetInfiniteResources(player: Player, enabled: boolean)
	runtime(player).infiniteResources = enabled
end

-- Learns every skill of the class as high as the level allows (spending points first, then free ones).
function SkillService.LearnAll(player: Player): number
	local char = character(player)
	if not char then
		return 0
	end
	local used = 0
	local progress = true
	while progress do
		progress = false
		local classSkills: { SkillData.SkillDef } = SkillData.byClass[char.class] or {}
		for _, skill in classSkills do
			local current = Skills.level(char, skill.id)
			if current < skill.maxLevel and char.level >= Skills.levelRequirement(skill, current + 1) then
				local requirementsMet = true
				local requires: { { skill: string, level: number } } = skill.requires or {}
				for _, requirement in requires do
					if Skills.level(char, requirement.skill) < requirement.level then
						requirementsMet = false
					end
				end
				if requirementsMet then
					char.skills[skill.id] = current + 1
					used += 1
					progress = true
				end
			end
		end
	end
	PlayerStateService.Set(player, { "character", "skills" }, char.skills)
	passivesChanged(player)
	return used
end

-- Casting -----------------------------------------------------------------------------------------------------

local function sendFx(player: Player, data: { [string]: any })
	local entity = EntityService.GetPlayerEntity(player)
	local position = entity and EntityService.Position(entity)
	if not position then
		return
	end
	Net.FireList(EntityService.PlayersNear(position, FX_RADIUS), "SkillFx", data)
end

local services: Context.Services

local function publishCooldowns(player: Player)
	local rt = runtime(player)
	PlayerStateService.Set(player, { "skills", "cd" }, table.clone(rt.cooldowns))
	PlayerStateService.Set(player, { "skills", "gcd" }, rt.gcd)
end

local function interruptChannel(player: Player, reason: string?)
	local rt = runtimes[player]
	if rt and rt.channel then
		rt.channel = nil
		rt.channelToken += 1
		PlayerStateService.Set(player, { "skills", "channel" }, nil)
		if reason then
			Net.Fire(player, "Toast", reason, nil, "warning")
		end
	end
end

local function startChannel(ctx: Context.Ctx)
	local player = ctx.player
	local rt = runtime(player)
	rt.channelToken += 1
	local token = rt.channelToken
	local duration = ctx.scaled(ctx.skill.duration)
	rt.channel = { skillId = ctx.skill.id, token = token, startedAt = ctx.root.Position }
	PlayerStateService.Set(
		player,
		{ "skills", "channel" },
		{ skill = ctx.skill.id, endsAt = now() + duration, duration = duration }
	)
	ctx.fx({ t = ctx.caster.id, d = duration })
	task.spawn(function()
		local endAt = os.clock() + duration
		while os.clock() < endAt do
			task.wait(0.1)
			if rt.channelToken ~= token then
				return
			end
			local model = player.Character
			local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				not root
				or (root.Position - ctx.root.Position).Magnitude > CHANNEL_MOVE_LIMIT
				or ResourceService.IsDead(player)
			then
				interruptChannel(player, "cast.interrupted")
				return
			end
		end
		if rt.channelToken ~= token then
			return
		end
		rt.channel = nil
		PlayerStateService.Set(player, { "skills", "channel" }, nil)
		-- Evocation / Prayer: restore mana (Prayer also to the party).
		local maxMana = StatService.GetValue(player, "maxMana")
		ResourceService.Add(player, "mana", maxMana * ctx.value("mana") / 100)
		if ctx.skill.values.group then
			for _, ally in ctx.alliesInCircle(ctx.root.Position, 40) do
				if ally ~= player then
					ResourceService.Add(ally, "mana", StatService.GetValue(ally, "maxMana") * ctx.value("group") / 100)
				end
			end
		end
	end)
end

local function resolveTarget(player: Player, skill: SkillData.SkillDef, targetId: string?): any
	if targetId then
		local entity = EntityService.Get(targetId)
		if entity then
			return entity
		end
	end
	if skill.target == "enemy" then
		return CombatService.GetTarget(player)
	end
	return nil
end

local function cast(player: Player, skillId: string, targetId: string?, aim: any): (boolean, string?)
	local char = character(player)
	local skill = SkillData.get(skillId)
	if not char or not skill or skill.class ~= char.class then
		return false, "error.badRequest"
	end
	local level = Skills.level(char, skillId)
	if level <= 0 or skill.type == "passive" then
		return false, "cast.error.notLearned"
	end
	local caster = EntityService.GetPlayerEntity(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not caster or not root or ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	if StatusEffectService.IsDisabled(caster) then
		return false, "cast.error.disabled"
	end
	if (skill.type == "blink" or skill.type == "charge") and StatusEffectService.IsRooted(caster) then
		return false, "cast.error.disabled"
	end
	local rt = runtime(player)
	local t = now()
	if not rt.noCooldowns and (t < rt.gcd or t < (rt.cooldowns[skillId] or 0)) then
		return false, "cast.error.cooldown"
	end

	-- Target / point resolution and range.
	local target = resolveTarget(player, skill, targetId)
	local point: Vector3? = nil
	if typeof(aim) == "Vector3" then
		local v = aim :: Vector3
		-- Reject NaN / infinite aims (they would teleport blinks into nowhere).
		if v.X ~= v.X or v.Y ~= v.Y or v.Z ~= v.Z or v.Magnitude > 1e6 then
			return false, "error.badRequest"
		end
		point = v
	end
	local offensive = skill.target == "enemy"
		or skill.type == "cone"
		or skill.type == "circleSelf"
		or skill.type == "circleTarget"
		or skill.type == "line"
	if offensive and ZoneService.GetPvpZone(player) == "green" then
		return false, "cast.error.safeZone"
	end
	if skill.target == "enemy" then
		if not target or target == caster then
			return false, "cast.error.noTarget"
		end
		local isEnemy = (target.kind == "monster" and target.monster and target.monster:IsAlive())
			or (target.kind == "player" and target.player and (PvpService.CanAttack(player, target.player)))
		if not isEnemy then
			return false, "cast.error.invalidTarget"
		end
		local position = EntityService.Position(target)
		if
			not position
			or (position - root.Position).Magnitude > (skill.range or Combat.meleeRange) + RANGE_TOLERANCE
		then
			return false, "cast.error.range"
		end
	elseif skill.target == "point" and skill.type ~= "blink" then
		if not point then
			local targetPosition = target and EntityService.Position(target)
			point = targetPosition or (root.Position + root.CFrame.LookVector * math.min(skill.range or 10, 10))
		end
		local p = point :: Vector3
		local offset = p - root.Position
		local range = skill.range or 30
		if offset.Magnitude > range then
			point = root.Position + offset.Unit * range
		end
	end

	-- Cost
	local cost = Skills.scaled(skill, skill.cost, level)
	local resource = skill.resource
	if cost > 0 and resource and not rt.infiniteResources then
		local ok = if resource == "mana"
			then ResourceService.SpendMana(player, cost)
			else ResourceService.SpendEnergy(player, cost)
		if not ok then
			return false, `cast.error.resource.{resource}`
		end
	end

	-- Execute
	interruptChannel(player, nil)
	local ctx = Context.new(player, skill, level, char, caster, root, services)
	ctx.target = target
	ctx.point = point
	local ok: boolean, err: string?
	if skill.type == "channel" then
		startChannel(ctx)
		ok = true
	else
		local handler = HANDLERS[skill.type]
		if not handler then
			return false, "error.internal"
		end
		local success, a, b = pcall(handler, ctx)
		if not success then
			log:error("%s failed: %s", skillId, tostring(a))
			return false, "error.internal"
		end
		ok, err = a, b
	end
	if not ok then
		-- Refund when the handler refused (e.g. no dead ally to revive).
		if cost > 0 and resource and not rt.infiniteResources then
			ResourceService.Add(player, resource, cost)
		end
		return false, err
	end

	ResourceService.MarkCombat(player)
	if not rt.noCooldowns then
		rt.gcd = t + SkillData.GCD
		rt.cooldowns[skillId] = t + Skills.scaled(skill, skill.cooldown, level)
		publishCooldowns(player)
	end
	return true, nil
end

function SkillService.Cast(player: Player, skillId: string, targetId: string?, aim: Vector3?): (boolean, string?)
	return cast(player, skillId, targetId, aim)
end

function SkillService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	StatService = registry.Get("StatService")
	ResourceService = registry.Get("ResourceService")
	CombatService = registry.Get("CombatService")
	StatusEffectService = registry.Get("StatusEffectService")
	EntityService = registry.Get("EntityService")
	PvpService = registry.Get("PvpService")
	PartyService = registry.Get("PartyService")
	DeathService = registry.Get("DeathService")
	InventoryService = registry.Get("InventoryService")
	ZoneService = registry.Get("ZoneService")

	services = {
		Combat = CombatService,
		StatusEffect = StatusEffectService,
		Resource = ResourceService,
		Stat = StatService,
		Entity = EntityService,
		Pvp = PvpService,
		Party = PartyService,
		Death = DeathService,
		Fx = sendFx,
		PassiveHook = SkillService.PassiveHook,
	}

	StatService.RegisterModifierSource("passives", modifierSource)
	CombatService.RegisterHookProvider(SkillService.PassiveHook)
end

function SkillService.Start()
	Net.Handle("LearnSkill", learn)
	Net.Handle("SetHotbar", setHotbar)
	Net.Handle("ResetSkills", function(player: Player)
		return SkillService.Reset(player, false)
	end)
	Net.Handle("CastSkill", cast)

	-- Taking damage interrupts channels.
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 then
			interruptChannel(player, "cast.interrupted")
		end
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		hookCache[player] = nil
		local rt = runtime(player)
		table.clear(rt.cooldowns)
		rt.gcd = 0
		PlayerStateService.Set(player, { "skills" }, { cd = {}, gcd = 0 })
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		hookCache[player] = nil
		interruptChannel(player, nil)
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "skills" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			runtimes[player] = nil
			hookCache[player] = nil
		end)
	end)
end

return SkillService
