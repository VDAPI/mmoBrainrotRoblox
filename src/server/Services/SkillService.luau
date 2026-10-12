--!strict
-- Skills (DESIGN §14): the 10-slot hotbar (SetHotbar, PutOnBar, the auto-put of base skills unlocked by a level-up),
-- passives as a StatService modifier source + combat hooks, and casting. S57: which skills a character has, their
-- rank, the path weapon, the passives and the skill changes of path nodes come from Logic/Paths (base + paths); the
-- bar check on load and on level changes is PathService's (Paths.validHotbar).
--   CastSkill(skillId, targetId?, aim?) -> validate (unlocked, alive, not stunned, GCD 0.5 s, cooldown, cost,
--   target, range) -> spend -> SkillFx "cast" (everyone nearby plays the skill's animation, Data/SkillMotions) ->
--   after the motion's hit time (S28, at most 0.6 s) the Skills/Types/* handler -> SkillFx impact events.
--   S28/S55/S57: the skill works as Logic/Paths.effectiveFor makes it (breakpoints at ranks 5 and 10 in the chosen
--   option, modify nodes).
-- S70: whether a channel ends early is Logic/Channel.stops (Prayer 10B steadfast keeps praying through damage);
-- Prayer 5B rolls Roll of the Dice at the end; Guardian Angel's save (StatusEffectService.AngelSaved) plays angelSave.
-- S73: extendOnKill (Bloodlust with Bloodthirst, S75): after the cast every kill (the killing blow, info.finisher)
-- lengthens the skill's running effects on the caster (StatusEffectService.Extend) up to the breakpoint's max.
-- Cooldowns replicate as state branch `skills` = { cd = { [skillId] = readyAt }, gcd = readyAt, channel? }
-- (server time), so the client draws the cooldown sweep.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Banner = require(script.Parent.Parent.Skills.Banner)
local Channel = require(Shared.Logic.Channel)
local Combat = require(Shared.Data.Combat)
local Context = require(script.Parent.Parent.Skills.Context)
local Log = require(Shared.Util.Log)
local Movement = require(script.Parent.Parent.Skills.Types.Movement)
local Net = require(Shared.Net)
local PathData = require(Shared.Data.Paths)
local Paths = require(Shared.Logic.Paths)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Offense = require(script.Parent.Parent.Skills.Types.Offense)
local SkillData = require(Shared.Data.Skills)
local SkillMotions = require(Shared.Data.SkillMotions)
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
		"ZoneService",
		"LevelService",
	},
}

local FX_RADIUS = 120
local RANGE_TOLERANCE = 5
-- S71 (ROZWOJ 9.5, Ardor): skills whose running cooldown the zealCdr hook shortens after an offensive cast.
local ZEAL_SKILLS = { "heal", "purify" }
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
local ZoneService: any
local LevelService: any
local PartyAuraService: any

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
	-- S70: kind for Logic/Channel.stops, def = the channelled skill after Skills.effective (ctx.skill)
	channel: { skillId: string, token: number, startedAt: Vector3, kind: string, def: any }?,
	channelToken: number,
	noCooldowns: boolean,
	infiniteResources: boolean,
	cdr: number, -- S64: % item cooldown reduction (Skills.cooldownReduction), published as { "skills", "cdr" }
	-- S73 extendOnKill per skillId: seconds per kill, the cap and the seconds added since the cast
	extend: { [string]: { seconds: number, max: number, added: number } },
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
			cdr = 0,
			extend = {},
		}
		runtimes[player] = rt
	end
	return rt
end

-- S64 (STATY 2C): item cooldown reduction (leg_cooldown, myth_cooldown) for casts, the skill bar and descriptions.
local function refreshCdr(player: Player)
	local rt = runtime(player)
	local cdr = Skills.cooldownReduction(CombatService.Hook(player, "cooldownReduction"))
	if cdr == rt.cdr then
		return
	end
	rt.cdr = cdr
	if PlayerStateService.HasState(player) and PlayerStateService.Get(player, { "skills" }) ~= nil then
		PlayerStateService.Set(player, { "skills", "cdr" }, cdr)
	end
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
	local hooks = if char then Paths.passiveTotals(char, Paths.weaponTypesOf(char.equipment)).hooks else {}
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
	local totals = Paths.passiveTotals(char, Paths.weaponTypesOf(char.equipment))
	if next(totals.flat) == nil and next(totals.pct) == nil then
		return nil
	end
	return { key = "source.passives", flat = totals.flat, pct = totals.pct }
end

-- Hotbar and unlocks -----------------------------------------------------------------------------------------

-- Every placement goes through here, so the quest "learn" objective fires once per skill put on the bar.
local function setHotbar(player: Player, slot: number, skillId: string?): (boolean, string?)
	local char = character(player)
	if not char or not Skills.validSlot(slot) or (skillId ~= nil and not Paths.canPutOnBar(char, skillId)) then
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
	if skillId ~= nil then
		QuestEvents.fire(player, "learn", { skillId = skillId })
	end
	return true, nil
end

-- Remote PutOnBar (S56, ROZWOJ 3.3) and the auto-put: without `slot` the first free slot (nothing when the skill is
-- already on the bar; "skills.error.barFull" when there is no free slot), with `slot` that slot is replaced.
function SkillService.PutOnBar(player: Player, skillId: string, slot: number?): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local ok, err = Paths.canPutOnBar(char, skillId)
	if not ok then
		return false, err
	end
	if slot ~= nil then
		return setHotbar(player, slot, skillId)
	end
	for _, existing in char.hotbar do
		if existing == skillId then
			return true, nil
		end
	end
	local free = Skills.firstFreeSlot(char.hotbar)
	if not free then
		return false, "skills.error.barFull"
	end
	return setHotbar(player, free, skillId)
end

-- S56 (ROZWOJ 2.5, 5): ranks follow the level. Passive ranks and hooks are refreshed on every change; going up puts
-- the new base actives on free slots (a toast each, or one for more than 2 at once). Going down, PathService cleans
-- the bar (S57: Paths.validHotbar).
local function onLevelChanged(player: Player, newLevel: number, oldLevel: number)
	passivesChanged(player)
	local char = character(player)
	if not char then
		return
	end
	if newLevel < oldLevel then
		return
	end
	local fresh = Skills.newlyUnlocked(char.class, oldLevel, newLevel)
	if #fresh == 0 then
		return
	end
	local actives: { string } = {}
	for _, skill in fresh do
		if skill.type ~= "passive" then
			table.insert(actives, skill.id)
		end
	end
	local placed, left = Skills.placeOnBar(char.hotbar, actives)
	local onBar: { [string]: boolean } = {}
	for _, place in placed do
		if setHotbar(player, place.slot, place.id) then
			onBar[place.id] = true
		end
	end
	-- S58 (ROZWOJ 5): the same actives go to free slots of the inactive set's bar; no toast, no quest event, what
	-- does not fit is dropped. Without buildOther the empty set takes Skills.startHotbar when first switched to.
	local other: any = char.buildOther
	if type(other) == "table" and type(other.hotbar) == "table" then
		local otherPlaced = Skills.placeOnBar(other.hotbar, actives)
		if #otherPlaced > 0 then
			local bar = table.clone(other.hotbar)
			for _, place in otherPlaced do
				bar[tostring(place.slot)] = place.id
			end
			PlayerStateService.Set(player, { "character", "buildOther", "hotbar" }, bar)
		end
	end
	if #fresh > 2 then
		Net.Fire(player, "Toast", "skills.toast.many", { n = #fresh }, "success")
		return
	end
	for _, skill in fresh do
		local args = { skill = "@" .. skill.nameKey }
		if skill.type == "passive" then
			Net.Fire(player, "Toast", "skills.toast.passive", args, "success")
		elseif onBar[skill.id] then
			Net.Fire(player, "Toast", "skills.toast.onBar", args, "success")
		elseif table.find(left, skill.id) then
			Net.Fire(player, "Toast", "skills.toast.barFull", args, "info")
		end
	end
end

-- Admin helpers --------------------------------------------------------------------------------------------

function SkillService.SetNoCooldowns(player: Player, enabled: boolean)
	local rt = runtime(player)
	rt.noCooldowns = enabled
	if enabled then
		table.clear(rt.cooldowns)
		rt.gcd = 0
		PlayerStateService.Set(player, { "skills" }, { cd = {}, gcd = 0, cdr = rt.cdr })
	end
end

function SkillService.SetInfiniteResources(player: Player, enabled: boolean)
	runtime(player).infiniteResources = enabled
end

-- Passives changed outside a level change (admin S28; S57 PathService: nodes, main path, weapon).
function SkillService.RefreshPassives(player: Player)
	passivesChanged(player)
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

-- Ends one skill's cooldown at once (Carnage kills reset Charge and Blade Whirl, ROZWOJ 10.4). The GCD stays.
-- True when the skill was cooling down.
function SkillService.ResetCooldown(player: Player, skillId: string): boolean
	local rt = runtimes[player]
	local ready = rt and rt.cooldowns[skillId]
	if not rt or not ready or ready <= now() then
		return false
	end
	rt.cooldowns[skillId] = nil
	publishCooldowns(player)
	return true
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

-- S70 (Prayer 5B, ROZWOJ 9.4): Roll of the Dice as the player would cast it (rank from the level, at least 1, their
-- breakpoint choices and nodes), one face for half its duration; works without knowing the skill.
local function prayerDice(ctx: Context.Ctx)
	local dice = SkillData.get("fortuneDice")
	if not dice then
		return
	end
	local player = ctx.player
	local char = ctx.character
	local rank = math.max(1, Skills.rankAt(dice, char.level))
	local def, behaviour = Paths.effectiveFor(char, dice.id, Paths.weaponTypesOf(char.equipment), rank)
	local diceCtx = Context.new(player, def, rank, char, ctx.caster, ctx.root, services, behaviour)
	diceCtx.rollDice({ half = true })
end

local function startChannel(ctx: Context.Ctx)
	local player = ctx.player
	local rt = runtime(player)
	rt.channelToken += 1
	local token = rt.channelToken
	local duration = ctx.scaled(ctx.skill.duration)
	local channel =
		{ skillId = ctx.skill.id, token = token, startedAt = ctx.root.Position, kind = "channel", def = ctx.skill }
	rt.channel = channel
	StatService.SetSprint(player, false) -- channelling stops the sprint (S18)
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
			-- S70: Logic/Channel decides (today death and moving always end a channel)
			local event: Channel.Event? = if not root or ResourceService.IsDead(player)
				then "death"
				elseif (root.Position - ctx.root.Position).Magnitude > CHANNEL_MOVE_LIMIT then "move"
				else nil
			if event and Channel.stops(channel.kind, event, channel.def) then
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
		-- S70 (Prayer 5B): the prayer ends with Roll of the Dice for the party
		if ctx.bp.roll then
			prayerDice(ctx)
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

-- Element of the equipped weapon (mage weapons only), from the derived stats.
local function weaponElement(player: Player): string?
	local weapon = PlayerStateService.Get(player, { "derived", "weapon" })
	return if type(weapon) == "table" then weapon.element else nil
end

-- Base speed of the equipped weapon (nil = unarmed), for the skill damage normalisation (S54, Skills.speedFactor).
local function weaponSpeed(player: Player): number?
	local weapon = PlayerStateService.Get(player, { "derived", "weapon" })
	return if type(weapon) == "table" and type(weapon.speed) == "number" then weapon.speed else nil
end

-- Types whose handler may still refuse (no dead ally): they run at once, so the refusal reaches the caster.
local INSTANT: { [string]: boolean } = { resurrect = true, channel = true }

local function cast(player: Player, skillId: string, targetId: string?, aim: any): (boolean, string?)
	local char = character(player)
	local base = SkillData.get(skillId)
	if not char or not base or base.class ~= char.class then
		return false, "error.badRequest"
	end
	-- S57: rank from Logic/Paths (base from the level, path skills from their node), then the path weapon
	local rank = Paths.skillRank(char, skillId)
	if rank <= 0 or base.type == "passive" then
		return false, "cast.error.notLearned"
	end
	local weapons = Paths.weaponTypesOf(char.equipment)
	local usable, usableErr = Paths.skillUsable(char, skillId, weapons)
	if not usable then
		return false, usableErr
	end
	-- S28/S57: numbers and behaviours at this rank (breakpoints in the chosen option, modify nodes).
	local skill, behaviour = Paths.effectiveFor(char, skillId, weapons, rank)
	local caster = EntityService.GetPlayerEntity(player)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not caster or not root or ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	if StatusEffectService.IsDisabled(caster) then
		return false, "cast.error.disabled"
	end
	-- Element skills need a weapon of the same element (S18, DESIGN §5.8).
	if not Skills.elementAllowed(skill, weaponElement(player)) then
		return false, "cast.error.wrongElement"
	end
	-- S74: a rooted guard cannot leap (like Charge); its self variant goes with it
	if
		(skill.type == "blink" or skill.type == "charge" or skill.type == "guard")
		and StatusEffectService.IsRooted(caster)
	then
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
	local offensive = Skills.offensive(skill) -- S74
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
			-- S74 (ROZWOJ 10.5): a banner with no aim and no target stands at the caster's feet
			local ahead = if skill.type == "banner"
				then root.Position
				else root.Position + root.CFrame.LookVector * math.min(skill.range or 10, 10)
			point = targetPosition or ahead
		end
		local p = point :: Vector3
		local offset = p - root.Position
		local range = skill.range or 30
		if offset.Magnitude > range then
			point = root.Position + offset.Unit * range
		end
	end

	-- Cost (S54: one formula with the bar and the description; Mage mana grows with the character level).
	local cost = Skills.cost(skill, rank, char.level, char.class, {
		costReduce = StatService.GetValue(player, "costReduce"), -- S62 item saving
	})
	local resource = skill.resource
	if cost > 0 and resource and not rt.infiniteResources then
		local ok = if resource == "mana"
			then ResourceService.SpendMana(player, cost)
			else ResourceService.SpendEnergy(player, cost)
		if not ok then
			return false, `cast.error.resource.{resource}`
		end
	end
	local function refund()
		if cost > 0 and resource and not rt.infiniteResources then
			ResourceService.Add(player, resource, cost)
		end
		if not rt.noCooldowns then
			rt.cooldowns[skillId] = nil
			rt.gcd = 0
			publishCooldowns(player)
		end
	end

	interruptChannel(player, nil)
	local ctx = Context.new(player, skill, rank, char, caster, root, services, behaviour)
	ctx.target = target
	ctx.point = point
	if not rt.noCooldowns then
		rt.gcd = t + SkillData.GCD
		rt.cooldowns[skillId] = t + Skills.cooldown(skill, rank, rt.cdr, behaviour)
		publishCooldowns(player)
	end
	ResourceService.MarkCombat(player)
	-- Offensive skills end the respawn protection even when they hit nothing (S22).
	if offensive then
		StatusEffectService.BreakRespawnShield(player)
	end

	-- After a successful handler: breakpoint effects on the caster.
	local function finished()
		local selfEffects = skill.selfEffects
		if selfEffects and not ctx.skipSelfEffects then
			for _, effect in selfEffects do
				ctx.applyEffect(caster, effect)
			end
		end
		if behaviour.selfHeal then
			ctx.heal(player, StatService.GetValue(player, "maxHp") * behaviour.selfHeal / 100)
		end
		-- S73 extendOnKill: a new cast starts from zero added seconds
		local extend = behaviour.extendOnKill
		if extend then
			rt.extend[skillId] = { seconds = extend.seconds, max = ctx.resolve(extend.max), added = 0 }
		end
		-- S65 (STATY 5): Full Draw after an offensive skill or a trap (a trap is an attack too).
		if offensive or skill.type == "trap" then
			CombatService.PrimeFullDraw(player)
		end
		-- S71 Ardor (zealCdr): every successful offensive cast, hit or not, shortens the running cooldowns of
		-- ZEAL_SKILLS; now() because this runs after the motion's hit delay.
		local zeal = if offensive and not rt.noCooldowns then SkillService.PassiveHook(player, "zealCdr") else 0
		if zeal > 0 then
			local at = now()
			local shortened = false
			for _, id in ZEAL_SKILLS do
				local ready = rt.cooldowns[id]
				if ready and ready > at then
					rt.cooldowns[id] = math.max(at, ready - zeal)
					shortened = true
				end
			end
			if shortened then
				publishCooldowns(player)
			end
		end
	end

	if skill.type == "channel" then
		startChannel(ctx)
		finished()
		return true, nil
	end
	local handler = HANDLERS[skill.type]
	if not handler then
		refund()
		return false, "error.internal"
	end
	local function run(): (boolean, string?)
		local success, a, b = pcall(handler, ctx)
		if not success then
			log:error("%s failed: %s", skillId, tostring(a))
			refund()
			return false, "error.internal"
		end
		if not a then
			-- The handler refused (e.g. no dead ally to revive): nothing was spent.
			refund()
			return false, b
		end
		finished()
		return true, nil
	end

	-- S28: everyone nearby starts the animation now; the blow lands at the motion's hit time.
	local delay = if INSTANT[skill.type] then 0 else SkillMotions.hitDelay(skillId)
	ctx.fx({
		v = "cast",
		t = if target then target.id else nil,
		p = point,
		mv = behaviour.castMove,
	})
	if delay <= 0 then
		return run()
	end
	task.delay(delay, function()
		-- Killed or stunned during the windup: the skill fizzles and its cost comes back.
		if
			player.Parent == nil
			or ResourceService.IsDead(player)
			or StatusEffectService.IsDisabled(caster)
			or player.Character ~= model
		then
			refund()
			ctx.fx({ v = "fizzle" })
			return
		end
		local ok, err = run()
		if not ok and err then
			Net.Fire(player, "Toast", err, nil, "warning")
		end
	end)
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
	ZoneService = registry.Get("ZoneService")
	LevelService = registry.Get("LevelService")
	-- S73: not in Deps: PartyAuraService -> PathService -> SkillService would be a cycle. Deps only order Init and
	-- BehindAnchor is called on a cast, after every Init.
	PartyAuraService = registry.Get("PartyAuraService")

	services = {
		Combat = CombatService,
		StatusEffect = StatusEffectService,
		Resource = ResourceService,
		Stat = StatService,
		Entity = EntityService,
		Pvp = PvpService,
		Party = PartyService,
		Death = DeathService,
		PartyAura = PartyAuraService,
		Fx = sendFx,
		Toast = function(p: Player, key: string, args: { [string]: any }?, kind: string?)
			Net.Fire(p, "Toast", key, args, kind)
		end,
		PassiveHook = SkillService.PassiveHook,
		WeaponElement = weaponElement,
		WeaponSpeed = weaponSpeed,
	}
	-- S74: the banner folder exists before clients wait for it
	Banner.folder()
	-- S65: shared helpers of Skills/Context (most wounded ally, heal an ally) for CombatService's Saving Blow.
	Context.bind(services)

	StatService.RegisterModifierSource("passives", modifierSource)
	CombatService.RegisterHookProvider(SkillService.PassiveHook)
end

function SkillService.Start()
	ResourceService.Died:Connect(function(player: Player)
		StatService.SetSprint(player, false)
	end)
	-- S72 Carnage (ROZWOJ 10.4): the killing blow of a player under Carnage ends the cooldowns of its reset skills.
	-- One boss has no kills, so there only the Fury bonus works; boss helpers are ordinary kills.
	CombatService.MonsterKilled:Connect(function(info)
		local finisher = info.finisher
		if finisher and StatusEffectService.PlayerHas(finisher, "carnage") then
			for _, id in PathData.HOOK_RULES.carnage.resets do
				SkillService.ResetCooldown(finisher, id)
			end
		end
		-- S73 extendOnKill: monsters only (no PvP), the killing blow like Carnage
		local rt = if finisher then runtimes[finisher] else nil
		local casterEntity = if finisher then EntityService.GetPlayerEntity(finisher) else nil
		if finisher and rt and casterEntity then
			for id, spec in rt.extend do
				local step = math.min(spec.seconds, spec.max - spec.added)
				if step > 0 and StatusEffectService.Extend(casterEntity, finisher, id, step) then
					spec.added += step
				else
					rt.extend[id] = nil -- the buff ended or the cap is reached
				end
			end
		end
	end)
	Net.Handle("SetHotbar", setHotbar)
	Net.Handle("PutOnBar", function(player: Player, skillId: string, slot: number?): (boolean, string?)
		return SkillService.PutOnBar(player, skillId, slot)
	end)
	Net.Handle("CastSkill", cast)
	-- S56: the one-time "character progression has changed" notice was seen.
	Net.On("AckRework", function(player: Player)
		if character(player) then
			PlayerStateService.Set(player, { "character", "reworkNotice" }, false)
		end
	end)
	LevelService.LevelChanged:Connect(onLevelChanged)
	-- S64: equipment changes clear EquipmentService's hook cache before StatService.Invalidate, so the value is fresh.
	StatService.Changed:Connect(function(player: Player)
		refreshCdr(player)
	end)

	-- Taking damage interrupts channels.
	ResourceService.Damaged:Connect(function(player: Player, amount: number)
		if amount > 0 then
			-- S70: Logic/Channel decides (Prayer 10B steadfast keeps praying)
			local channel = runtime(player).channel
			if channel and Channel.stops(channel.kind, "damage", channel.def) then
				interruptChannel(player, "cast.interrupted")
			end
		end
	end)
	-- S70: Guardian Angel left the player at 1 HP
	StatusEffectService.AngelSaved:Connect(function(player: Player, caster: Player?)
		local entity = EntityService.GetPlayerEntity(player)
		if not entity then
			return
		end
		local from = if caster then EntityService.GetPlayerEntity(caster) else nil
		sendFx(player, {
			s = "guardianAngel",
			v = "angelSave",
			t = entity.id,
			p = EntityService.Position(entity),
			c = if from then from.id else nil,
		})
		Net.Fire(player, "Toast", "skills.angelSave", nil, "success")
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		hookCache[player] = nil
		local rt = runtime(player)
		table.clear(rt.cooldowns)
		table.clear(rt.extend)
		rt.gcd = 0
		rt.cdr = Skills.cooldownReduction(CombatService.Hook(player, "cooldownReduction"))
		PlayerStateService.Set(player, { "skills" }, { cd = {}, gcd = 0, cdr = rt.cdr })
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		hookCache[player] = nil
		interruptChannel(player, nil)
		local rt = runtimes[player]
		if rt then
			table.clear(rt.extend)
		end
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
