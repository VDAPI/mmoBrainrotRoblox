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
-- S76 (ROZWOJ 11.3, 14.3): castTime aims before the shot (startChannel kind "castTime"): cost and cooldown at the
-- start, no basic attacks (CombatService), another skill is refused (cast.error.channeling); moving or a stun ends it
-- with the cost and the skill's cooldown back (the GCD stays), damage never; the handler fires at the end.
-- S77: the Falcon's loop lives in Skills/Companion; death, leaving the character and leaving the game stop it.
-- ReduceCooldown shortens one running cooldown (critCdr, Mage cdrPerTarget in S79).
-- S79: circle spells grow with the areaRadius hook (a copy of the definition, the VFX too); the mana share before the
-- cost goes to ctx.manaFraction (resonance); a channel with channelMove survives moving (Logic/Channel); Master Mind
-- (channelGuard) guards the whole channel and comes off at its one exit (closeChannel); vortexGuard after Elemental Vortex.
-- S80 (ROZWOJ 12.5, 14.4): the beam (Arcane Torrent) is a channel kind with ticks, mana drain and its own ends
-- (Logic/Channel "beam": a stun, a knockback through Push.Moved, moving, the target lost or out of range, no mana,
-- another cast; never damage). Every channel ends in closeChannel. Arcane Charges: a snapshot at the cast (cost
-- through Skills.cost, damage through ctx.castMul), +1 after a damaging spell, all consumed by Arcane Discharge, off
-- on death and out of combat; empowered loses a use per damaging spell; grantCharges / empower after a full channel.
-- Cooldowns replicate as state branch `skills` = { cd = { [skillId] = readyAt }, gcd = readyAt, channel? }
-- (server time), so the client draws the cooldown sweep.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Banner = require(script.Parent.Parent.Skills.Banner)
local Channel = require(Shared.Logic.Channel)
local Combat = require(Shared.Data.Combat)
local Companion = require(script.Parent.Parent.Skills.Companion)
local Context = require(script.Parent.Parent.Skills.Context)
local Log = require(Shared.Util.Log)
local Movement = require(script.Parent.Parent.Skills.Types.Movement)
local Net = require(Shared.Net)
local PathData = require(Shared.Data.Paths)
local Paths = require(Shared.Logic.Paths)
local Push = require(script.Parent.Parent.Skills.Push)
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
		"MountService", -- S96: a skill interrupts mounting and dismounts
	},
}

local FX_RADIUS = 120
local RANGE_TOLERANCE = 5
-- S71 (ROZWOJ 9.5, Ardor): skills whose running cooldown the zealCdr hook shortens after an offensive cast.
local ZEAL_SKILLS = { "heal", "purify" }
local CHARGES = SkillData.ARCANE_CHARGES

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
local MountService: any
-- S96: a cast that dismounted: until then (os.clock) a channel's start follows the rider settling to the ground (the
-- HipHeight drop is not a move).
local DISMOUNT_SETTLE = 0.6
local settling: { [Player]: number } = {}

type Handler = (ctx: Context.Ctx) -> (boolean, string?)

local HANDLERS: { [string]: Handler } = {}
for _, group in { Offense, Movement, Support } do
	for kind, handler in group do
		HANDLERS[kind] = handler
	end
end

-- S80: a beam channel (Arcane Torrent): its target, ticks every `interval`, reach, mana per tick and the tick itself.
type Beam = { target: any, interval: number, ticks: number, range: number, drain: number, tick: (n: number) -> () }

-- S70: kind for Logic/Channel.stops, def = the channelled skill after Skills.effective (ctx.skill)
-- S76: kind "castTime" (aiming) with fx (the cast's ctx.fx) and onRefund (gives the cost and the cooldown back)
-- S80: ctx and onDone (closeChannel needs no closure of the loop), the beam and its target
type ChannelState = {
	skillId: string,
	token: number,
	startedAt: Vector3,
	kind: string,
	def: any,
	fx: ((data: { [string]: any }) -> ())?,
	onRefund: (() -> ())?,
	guard: string?, -- S79: skillId of the channelGuard damage reduction on the caster (removed at the end)
	ctx: Context.Ctx,
	onDone: (() -> ())?,
	onCancel: (() -> ())?, -- S80 review: an aim cut short without a refund (frees the cast's empowered use)
	target: any?,
	beam: Beam?,
}

type Runtime = {
	cooldowns: { [string]: number },
	gcd: number,
	channel: ChannelState?,
	channelToken: number,
	noCooldowns: boolean,
	infiniteResources: boolean,
	cdr: number, -- S64: % item cooldown reduction (Skills.cooldownReduction), published as { "skills", "cdr" }
	-- S73 extendOnKill per skillId: seconds per kill, the cap and the seconds added since the cast
	extend: { [string]: { seconds: number, max: number, added: number } },
	-- S80 review: empowered uses taken by casts whose hit has not landed yet (a hit delay longer than the GCD)
	empowerPending: number,
}

local runtimes: { [Player]: Runtime } = {}
local hookCache: { [Player]: { [string]: number } } = {}
-- S80: players who got an Arcane Charge (the out-of-combat sweep in Start looks only at them)
local chargeHolders: { [Player]: boolean } = {}

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
			empowerPending = 0,
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
	if not char then
		return {} -- not cached (see EquipmentService.GetHooks)
	end
	local hooks = Paths.passiveTotals(char, Paths.weaponTypesOf(char.equipment)).hooks
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

-- S76: shortens one running cooldown by `seconds` (critCdr; S79 cdrPerTarget). The GCD stays.
function SkillService.ReduceCooldown(player: Player, skillId: string, seconds: number)
	local rt = runtimes[player]
	if not rt or rt.noCooldowns or seconds <= 0 then
		return
	end
	local ready = rt.cooldowns[skillId]
	if not ready then
		return
	end
	rt.cooldowns[skillId] = math.max(now(), ready - seconds)
	publishCooldowns(player)
end

-- Arcane Charges (S80) ---------------------------------------------------------------------------------------

-- ROZWOJ 12.5: charges work with Arcane Discharge and the path's weapon only; others never pay their cost
local function chargesEnabled(char: Types.CharacterData): boolean
	return (Paths.skillUsable(char, CHARGES.consumer, Paths.weaponTypesOf(char.equipment)))
end

-- Charges that count now (none out of combat or after their 15 s).
local function chargesOf(player: Player, caster: any): number
	local stacks, expiresAt = StatusEffectService.Stacks(caster, "arcaneCharge")
	return Skills.chargesNow(stacks, expiresAt, now(), ResourceService.InCombat(player))
end

-- Sets the charges to `stacks` (at least the running ones, StatusEffectService ApplyOptions.stacks) or, without
-- `stacks`, adds one; the time starts again. One entry: source = the player, no skillId, category own.
local function giveCharges(player: Player, caster: any, stacks: number?)
	StatusEffectService.Apply(caster, "arcaneCharge", {
		duration = CHARGES.duration,
		maxStacks = CHARGES.max,
		stacks = stacks,
		source = player,
		category = "own",
		value = 0,
	})
	chargeHolders[player] = true
end

local function dropCharges(player: Player, caster: any?)
	if caster then
		StatusEffectService.Remove(caster, "arcaneCharge")
	end
	chargeHolders[player] = nil
end

-- Channels -----------------------------------------------------------------------------------------------------

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

-- Evocation / Prayer after the full channel: mana back (Prayer also to the party), Prayer 5B's dice and (S80,
-- ROZWOJ 12.5) Evocation 10B's charges and Empowering Invocation. An interrupted channel gives none of these.
local function completeChannel(player: Player, ctx: Context.Ctx)
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
	local char = character(player)
	local grant = ctx.bp.grantCharges
	if grant and grant > 0 and char and chargesEnabled(char) then
		giveCharges(player, ctx.caster, Skills.chargesAfterGain(chargesOf(player, ctx.caster), grant))
	end
	local empower = ctx.bp.empower
	if empower and empower.uses > 0 then
		StatusEffectService.Apply(ctx.caster, "empowered", {
			duration = SkillData.EMPOWERED.duration,
			value = ctx.resolve(empower.pct),
			stacks = empower.uses,
			maxStacks = empower.uses,
			source = player,
			category = "own",
		})
	end
end

-- S80: the only way a channel ends (time up, Logic/Channel stop, another cast, death, leaving). Clears the state,
-- removes what the channel put on the caster (channelGuard, S79) and tells the clients (beamEnd / aimEnd + fizzle /
-- channelEnd).
-- `completed`: the channel ran its full time (aiming shoots, Evocation / Prayer restore); `refund` gives an aim's cost
-- and cooldown back (S76).
local function closeChannel(player: Player, completed: boolean, reason: string?, refund: boolean?)
	local rt = runtimes[player]
	local channel = rt and rt.channel
	if not rt or not channel then
		return
	end
	rt.channel = nil
	rt.channelToken += 1
	PlayerStateService.Set(player, { "skills", "channel" }, nil)
	-- S79 Master Mind: only this channel's guard entry (StatusEffectService.Remove by skillId)
	local guard = channel.guard
	if guard then
		StatusEffectService.Remove(channel.ctx.caster, "damageReduction", guard)
	end
	local fx = channel.fx
	if channel.kind == "castTime" then
		if completed then
			if channel.onDone then
				channel.onDone()
			end
		else
			if refund and channel.onRefund then
				channel.onRefund()
			elseif channel.onCancel then
				channel.onCancel()
			end
			if fx then
				fx({ v = "aimEnd" })
				fx({ v = "fizzle" })
			end
		end
	elseif channel.kind == "beam" then
		if fx then
			fx({ v = "beamEnd" }) -- the clients put the ray out and stop the motion's loop
		end
	elseif completed then
		completeChannel(player, channel.ctx)
	elseif fx then
		fx({ v = "channelEnd" }) -- cut short: the clients stop the motion's loop and give the caster's walk back
	end
	if reason then
		Net.Fire(player, "Toast", reason, nil, "warning")
	end
end

-- S76: `refund` gives an aim's cost and cooldown back (Channel.stops). S80: a thin wrapper of closeChannel.
local function interruptChannel(player: Player, reason: string?, refund: boolean?)
	local rt = runtimes[player]
	if rt and rt.channel then
		closeChannel(player, false, reason, refund)
	end
end

-- Toast of a channel stopped by `event` (S76: a cancelled aim says so; S80: a lost target says nothing).
local function stopReason(event: Channel.Event, refund: boolean): string?
	if refund then
		return "cast.aimCancelled"
	elseif event == "target" then
		return nil
	elseif event == "range" then
		return "cast.error.beamRange"
	elseif event == "noMana" then
		return "cast.error.resource.mana"
	end
	return "cast.interrupted"
end

-- Channels (Evocation, Prayer), with `onDone` (S76, ROZWOJ 14.3) aiming: the castTime wait before the shot, and with
-- `beam` (S80, ROZWOJ 12.5) the beam of Arcane Torrent: a tick every beam.interval, each draining beam.drain mana.
-- Logic/Channel.stops decides what ends it; every end goes through closeChannel.
local function startChannel(ctx: Context.Ctx, onDone: (() -> ())?, onRefund: (() -> ())?, beam: Beam?)
	local player = ctx.player
	local rt = runtime(player)
	rt.channelToken += 1
	local token = rt.channelToken
	local kind = if beam then "beam" elseif onDone then "castTime" else "channel"
	local duration = if beam
		then beam.ticks * beam.interval
		elseif onDone then ctx.skill.castTime or 0
		else ctx.scaled(ctx.skill.duration)
	local channel: ChannelState = {
		skillId = ctx.skill.id,
		token = token,
		startedAt = ctx.root.Position,
		kind = kind,
		def = ctx.skill,
		fx = ctx.fx,
		onRefund = onRefund,
		guard = nil,
		ctx = ctx,
		onDone = onDone,
		target = if beam then beam.target else nil,
		beam = beam,
	}
	rt.channel = channel
	StatService.SetSprint(player, false) -- channelling stops the sprint (S18)
	PlayerStateService.Set(
		player,
		{ "skills", "channel" },
		{ skill = ctx.skill.id, endsAt = now() + duration, duration = duration, kind = kind }
	)
	if kind == "castTime" then
		ctx.fx({ v = "aim", t = if ctx.target then ctx.target.id else nil, p = ctx.point, d = duration })
	elseif kind == "channel" then
		ctx.fx({ t = ctx.caster.id, d = duration }) -- the channel's aura and rune (the cast event went before, S80)
	end
	-- S79 Master Mind (ROZWOJ 12.5): damage reduction for the whole channel or beam (not for aiming), off at closeChannel
	local guard = Skills.channelGuard(kind, SkillService.PassiveHook(player, "channelGuard"), duration)
	if guard then
		StatusEffectService.Apply(ctx.caster, guard.kind, {
			duration = guard.duration,
			value = guard.value,
			source = player,
			skillId = guard.skillId,
			category = guard.category,
		})
		channel.guard = guard.skillId
	end
	local Entity = EntityService
	task.spawn(function()
		local started = os.clock()
		local nextTick = 1
		while true do
			task.wait(0.1)
			if rt.channelToken ~= token then
				return
			end
			local model = player.Character
			local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
			-- S70 / S76 / S80: Logic/Channel decides; the checks go before the tick, so no tick lands after a reason.
			-- Every event that applies counts (a stunned Prayer pushed away still ends on "move").
			local events: { string } = {} -- Channel.Event names
			if not root or ResourceService.IsDead(player) then
				table.insert(events, "death")
			else
				if StatusEffectService.IsDisabled(ctx.caster) then
					table.insert(events, "disabled")
				end
				local settleUntil = settling[player]
				if settleUntil and os.clock() < settleUntil then
					-- S96: the rider drops to the ground after a dismount; only the height of the start follows
					local start = channel.startedAt
					channel.startedAt = Vector3.new(start.X, root.Position.Y, start.Z)
				end
				if Channel.afterMove(kind, (root.Position - channel.startedAt).Magnitude, channel.def) then
					table.insert(events, "move")
				end
				if beam then
					if not ctx.isEnemy(beam.target) then
						table.insert(events, "target")
					else
						local at = Entity.Position(beam.target)
						if not at or (at - root.Position).Magnitude > beam.range + RANGE_TOLERANCE then
							table.insert(events, "range")
						end
					end
				end
			end
			local event, refund = Channel.firstStop(kind, events, channel.def)
			if event then
				closeChannel(player, false, stopReason(event :: any, refund), refund)
				return
			end
			if beam then
				local elapsed = os.clock() - started
				while nextTick <= beam.ticks and elapsed >= nextTick * beam.interval - 1e-3 do
					if
						beam.drain > 0
						and not rt.infiniteResources
						and not ResourceService.SpendMana(player, beam.drain)
					then
						if Channel.stops(kind, "noMana", channel.def) then
							closeChannel(player, false, stopReason("noMana", false), false)
							return
						end
					end
					local ok, err = pcall(beam.tick :: any, nextTick)
					if not ok then
						log:error("%s tick failed: %s", channel.skillId, tostring(err))
						closeChannel(player, false)
						return
					end
					nextTick += 1
					if rt.channelToken ~= token then
						return
					end
				end
				if nextTick > beam.ticks then
					closeChannel(player, true)
					return
				end
			elseif os.clock() - started >= duration then
				closeChannel(player, true)
				return
			end
		end
	end)
end

-- S80 (services.Beam, Types/Offense.beam): mana per tick from Skills.drain with the cast's CostMods (charges, hooks,
-- saving); refused when the mana does not pay one tick (the cost is 0, so nothing was spent).
local function startBeam(ctx: Context.Ctx, target: any, tick: (n: number) -> ()): (boolean, string?)
	local player = ctx.player
	local rt = runtime(player)
	local drain = Skills.drain(ctx.skill, ctx.rank, StatService.GetValue(player, "maxMana"), ctx.costMods)
	if drain > 0 and not rt.infiniteResources then
		local _, mana = ResourceService.Get(player)
		if mana < drain then
			return false, "cast.error.resource.mana"
		end
	end
	startChannel(ctx, nil, nil, {
		target = target,
		interval = ctx.skill.interval or 0.5,
		ticks = Skills.beamTicks(ctx.skill),
		range = ctx.skill.range or 30,
		drain = drain,
		tick = tick,
	})
	return true, nil
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
-- S80: a beam too (no mana for a tick, a lost target).
local INSTANT: { [string]: boolean } = { resurrect = true, channel = true, beam = true }

local function cast(player: Player, skillId: string, targetId: string?, aim: any): (boolean, string?)
	-- S96 (DESIGN-15 §2): pressing a skill stops mounting, even when the cast is refused below
	MountService.Interrupt(player)
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
	-- S79 Broad Rings: circle spells grow; the VFX event carries the grown radius. Always on a copy: without sources
	-- effectiveFor returns the data definition itself.
	local radiusPct = SkillService.PassiveHook(player, "areaRadius")
	if radiusPct ~= 0 then
		local grown = Skills.areaRadius(skill, radiusPct)
		if grown ~= skill.radius then
			skill = table.clone(skill)
			skill.radius = grown
		end
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
	-- S76 (ROZWOJ 14.3): another skill never ends an aim (it says so, before the quiet cooldown message: the GCD is
	-- still running in the first half second); Focus and Prayer are still ended by interruptChannel below.
	if rt.channel and rt.channel.kind == "castTime" then
		return false, "cast.error.channeling"
	end
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

	-- S80 (ROZWOJ 12.5): Arcane Charges now; a weapon change (or the end of combat) takes them off
	local charges = chargesOf(player, caster)
	if StatusEffectService.Stacks(caster, "arcaneCharge") > 0 and (charges == 0 or not chargesEnabled(char)) then
		dropCharges(player, caster)
		charges = 0
	end
	-- Cost (S54: one formula with the bar and the description; Mage mana grows with the character level).
	local costMods: Skills.CostMods = {
		costReduce = StatService.GetValue(player, "costReduce"), -- S62 item saving
		hooks = passiveHooks(player), -- S76: trapCost; S79: areaCost / spellCost; S80: chargeCost
		charges = charges, -- S80: Skills.cost counts them for damaging spells only
	}
	local cost = Skills.cost(skill, rank, char.level, char.class, costMods)
	local resource = skill.resource
	-- S79 (resonance): the mana share before this cast pays (also with infinite resources)
	local _, manaBefore = ResourceService.Get(player)
	local manaFraction = manaBefore / math.max(1, StatService.GetValue(player, "maxMana"))
	if cost > 0 and resource and not rt.infiniteResources then
		local ok = if resource == "mana"
			then ResourceService.SpendMana(player, cost)
			else ResourceService.SpendEnergy(player, cost)
		if not ok then
			return false, `cast.error.resource.{resource}`
		end
	end
	-- S80 review: the empowered use this cast reserved (see the snapshot below); `consume` takes the stack off, else
	-- the reservation is just freed (refund, fizzle). Runs at most once per cast.
	local empowerReserved = false
	local function releaseEmpower(consume: boolean)
		if not empowerReserved then
			return
		end
		empowerReserved = false
		rt.empowerPending = math.max(0, rt.empowerPending - 1)
		if consume then
			StatusEffectService.UseStack(caster, "empowered")
		end
	end
	local function refund()
		releaseEmpower(false)
		if cost > 0 and resource and not rt.infiniteResources then
			ResourceService.Add(player, resource, cost)
		end
		if not rt.noCooldowns then
			rt.cooldowns[skillId] = nil
			rt.gcd = 0
			publishCooldowns(player)
		end
	end
	-- S76: a cancelled aim gives the cost and this skill's cooldown back; the GCD stays.
	local function refundAim()
		releaseEmpower(false)
		if cost > 0 and resource and not rt.infiniteResources then
			ResourceService.Add(player, resource, cost)
		end
		if not rt.noCooldowns then
			rt.cooldowns[skillId] = nil
			publishCooldowns(player)
		end
	end

	-- S96 (DESIGN-15 §2): a skill dismounts first, then it is cast
	if MountService.IsRiding(player) then
		MountService.Dismount(player, "skill")
		settling[player] = os.clock() + DISMOUNT_SETTLE
	end
	-- S80: a new cast ends a channel or a beam (Logic/Channel "cast"); a refused cast above never does
	local running = rt.channel
	if running and (Channel.stops(running.kind, "cast", running.def)) then
		closeChannel(player, false)
	end
	local ctx = Context.new(player, skill, rank, char, caster, root, services, behaviour)
	ctx.target = target
	ctx.point = point
	ctx.manaFraction = manaFraction
	ctx.costMods = costMods
	-- S80 (ROZWOJ 12.5): a snapshot of the charges and empowered for every hit of this cast (waves, echo, splash,
	-- the Torrent's ticks)
	local spell = Skills.isSpell(skill)
	local consumes = Skills.consumesCharges(skill)
	local castMul = 1
	if consumes then
		castMul *= Skills.dischargeFactor(ctx.value("perCharge"), charges)
		ctx.chargesSpent = charges
	elseif spell and charges > 0 then
		castMul *= Skills.chargeDamageFactor(charges, ctx.hook("chargeDamage"))
	end
	if spell then
		-- one use per damaging spell: uses already reserved by casts still before their hit do not count again
		local uses, _, pct = StatusEffectService.Stacks(caster, "empowered")
		if uses > rt.empowerPending then
			castMul *= 1 + pct / 100
			empowerReserved = true
			rt.empowerPending += 1
		end
	end
	ctx.castMul = castMul
	if not rt.noCooldowns then
		rt.gcd = t + SkillData.GCD
		local cooldown = Skills.cooldown(skill, rank, rt.cdr, behaviour)
		rt.cooldowns[skillId] = t + cooldown
		ctx.cooldown = cooldown -- S76: critCdr shortens this
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
		-- S79 Mantle of Elements (vortexGuard, ROZWOJ 12.4): damage reduction until the last wave of Elemental Vortex;
		-- its own key (destroyer_mantle), so it multiplies with other reductions under the cap (7.1)
		local mantle = Skills.castGuard(skill, SkillService.PassiveHook(player, "vortexGuard"))
		if mantle then
			StatusEffectService.Apply(caster, mantle.kind, {
				duration = mantle.duration,
				value = mantle.value,
				source = player,
				skillId = mantle.skillId,
				category = mantle.category,
			})
		end
		-- S80 (ROZWOJ 12.5): Arcane Discharge spends every charge (reclaiming mana per charge with chargeReclaim);
		-- other damaging spells add one (the Torrent at the start of its beam); empowered loses a use
		if consumes then
			dropCharges(player, caster)
			local spent = ctx.chargesSpent or 0
			local reclaim = ctx.hook("chargeReclaim")
			if reclaim > 0 and spent > 0 then
				ResourceService.Add(player, "mana", StatService.GetValue(player, "maxMana") * reclaim / 100 * spent)
			end
		elseif spell and chargesEnabled(char) then
			giveCharges(player, caster, nil)
		end
		releaseEmpower(true)
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
		-- S80: the cast event of a channel carries its time (the motion loops for it) and channelMove (walk speed)
		ctx.fx({ v = "cast", d = ctx.scaled(skill.duration), mv = skill.channelMove })
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
			if skill.type == "beam" then
				ctx.fx({ v = "fizzle" })
			end
			return false, "error.internal"
		end
		if not a then
			-- The handler refused (e.g. no dead ally to revive): nothing was spent.
			refund()
			if skill.type == "beam" then
				ctx.fx({ v = "fizzle" }) -- S80: the cast event already started the motion's loop
			end
			return false, b
		end
		finished()
		return true, nil
	end

	-- S76 (ROZWOJ 11.3, 14.3): aim first; the shot fires at the end without the motion's hit delay and without a new
	-- range check (the arrow flies). A target that died or stopped being an enemy meanwhile gives everything back.
	local castTime = skill.castTime or 0
	if castTime > 0 then
		ctx.fx({
			v = "cast",
			t = if target then target.id else nil,
			p = point,
			mv = behaviour.castMove,
			ct = castTime,
		})
		startChannel(ctx, function()
			if skill.target == "enemy" and not ctx.isEnemy(ctx.target) then
				refundAim()
				ctx.fx({ v = "aimEnd" })
				Net.Fire(player, "Toast", "cast.error.noTarget", nil, "warning")
				return
			end
			ctx.fx({ v = "aimEnd" })
			local ok, err = run()
			if not ok and err then
				Net.Fire(player, "Toast", err, nil, "warning")
			end
		end, refundAim)
		local aiming = rt.channel
		if aiming then
			aiming.onCancel = function()
				releaseEmpower(false)
			end
		end
		return true, nil
	end

	-- S28: everyone nearby starts the animation now; the blow lands at the motion's hit time.
	local delay = if INSTANT[skill.type] then 0 else SkillMotions.hitDelay(skillId)
	local isBeam = skill.type == "beam"
	ctx.fx({
		v = "cast",
		t = if target then target.id else nil,
		p = point,
		-- S80: a beam walks at channelMove % (5B) and loops its motion for the whole beam
		mv = if isBeam then skill.channelMove else behaviour.castMove,
		d = if isBeam then Skills.beamTicks(skill) * (skill.interval or 0.5) else nil,
		-- S114 (DESIGN-16 §0.2.3): the waves after breakpoints and nodes, looks only (the motion's variant)
		w = skill.hits,
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
	MountService = registry.Get("MountService")
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
		Zone = ZoneService,
		Fx = sendFx,
		Beam = startBeam, -- S80
		Toast = function(p: Player, key: string, args: { [string]: any }?, kind: string?)
			Net.Fire(p, "Toast", key, args, kind)
		end,
		PassiveHook = SkillService.PassiveHook,
		ReduceCooldown = SkillService.ReduceCooldown, -- S76: critCdr
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
		Companion.stop(player) -- S77
		-- S80 (ROZWOJ 12.5): charges and empowered end with death (CleanseOnDeath keeps buffs)
		local entity = EntityService.GetPlayerEntity(player)
		dropCharges(player, entity)
		if entity then
			StatusEffectService.Remove(entity, "empowered")
		end
	end)
	-- S80: a knockback or a pull ends a beam (Logic/Channel "knockback"); other channels keep the distance rule
	Push.Moved:Connect(function(entity: any)
		local moved: Player? = entity.player
		local rt = if moved then runtimes[moved] else nil
		local channel = rt and rt.channel
		if moved and channel then
			local stop, refund = Channel.stops(channel.kind, "knockback", channel.def)
			if stop then
				closeChannel(moved, false, "cast.interrupted", refund)
			end
		end
	end)
	-- S80: Arcane Charges end with combat (Config.CombatTimeout), not only after their 15 s
	task.spawn(function()
		while true do
			task.wait(1)
			for holder in chargeHolders do
				local entity = if holder.Parent then EntityService.GetPlayerEntity(holder) else nil
				if not entity then
					chargeHolders[holder] = nil
				elseif chargesOf(holder, entity) == 0 then
					dropCharges(holder, entity)
				end
			end
		end
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
			-- S76: never an aim (Channel.stops "castTime")
			local channel = runtime(player).channel
			if channel and (Channel.stops(channel.kind, "damage", channel.def)) then
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
		Companion.stop(player) -- S77
		local rt = runtimes[player]
		if rt then
			table.clear(rt.extend)
		end
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "skills" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Companion.stop(player, true) -- S77: the entity is gone
		chargeHolders[player] = nil -- S80
		settling[player] = nil -- S96
		task.defer(function()
			runtimes[player] = nil
			hookCache[player] = nil
		end)
	end)
end

return SkillService
