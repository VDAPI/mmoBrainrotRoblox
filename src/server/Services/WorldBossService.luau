--!strict
-- The world boss (S149, DESIGN §15.6, Data/WorldBoss, Logic/WorldBoss). Every world server (Arena/ServerMode.isWorld;
-- arena and tournament servers never) computes the same occurrences from the UTC clock (Util/Clock, no message between
-- servers): announcements 10 and 2 min before, then Hrimvald (Data/Bosses, `world = true`) stands on the Frost Peaks
-- spot until killed or until `timeLimit` after the start, when he leaves. A server starting inside an occurrence puts
-- him up at once with full HP and the time left. The fight is Entities/Boss with an open-world Services provider: the
-- fighters are the living players in the circle (spot r + fighterReach) on the map, the S134 blows and mechanics go
-- through CombatService, the helpers of phases 2-3 have no shield, loot or EXP; a boss with nobody near walks back to
-- the centre without healing. Contribution (Logic/Contribution with Data/WorldBoss.share): damage on the boss and its
-- helpers (CombatService.MonsterDamaged), healing and shields on players in the circle (ResourceService.Healed) and
-- blows taken for them (StatusEffectService.Intercepted). On a kill every participant with the same character, level
-- >= minLevel and enough points gets once per account and occurrence (account.worldBoss.last, written with the reward)
-- EXP, gold, materials and one Heroic+ item (backpack, else mail). Inside the occurrence's window no Invasion or
-- Champion starts (WorldEventService.AddBlocker) and nobody fights PvP in the circle while the boss lives
-- (PvpService.AddFightRule). Every player sees the state branch `worldBoss` (Logic/WorldBoss.Public + `mine`, or
-- `{ next }`), sent at most every publishEvery seconds and only on a change. The after-fight meter is
-- FightLogService ("worldboss", S149b: with each player's place in the contribution); S149b: every winner gets the
-- reward card (`WorldBossReward`: EXP, gold and the items, or the reason without a reward).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Boss = require(script.Parent.Parent.Entities.Boss)
local Clock = require(Shared.Util.Clock)
local Contribution = require(Shared.Logic.Contribution)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)
local WorldBoss = require(Shared.Logic.WorldBoss)

local Data = WorldBoss.Data
local log = Log.new("WorldBossService")

local WorldBossService = {
	Name = "WorldBossService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"ZoneService",
		"WorldService",
		"MonsterService",
		"CombatService",
		"ResourceService",
		"StatusEffectService",
		"StatService",
		"LevelService",
		"InventoryService",
		"MailService",
		"LootService",
		"AnnounceService",
		"WorldEventService", -- the blocker of Invasions and Champions (WorldEventService never depends on this service)
		"FightLogService",
		"PvpService", -- the PvP-free circle (a fight rule)
	},
}

type Occurrence = WorldBoss.Occurrence
type State = "warn" | "active" | "slain" | "left"

type Fight = {
	occ: Occurrence,
	forced: boolean,
	state: State,
	boss: Boss.Boss?, -- while it stands (nil after the kill or the leave)
	bossPhase: number,
	centre: Vector3?, -- world position of the spot on the ground (once spawned)
	helpers: { [any]: boolean },
	bank: { [Player]: Contribution.Contribution },
	chars: { [Player]: string }, -- the character that earned the first point (the reward goes only to it)
	fightId: number?,
	spawnedAt: number?, -- Clock time
	endedAt: number?, -- Clock time of the kill or the leave
	closed: boolean, -- the marker is gone (linger over); the occurrence stays so the boss never comes back
}

local PlayerStateService: any
local CharacterService: any
local ZoneService: any
local WorldService: any
local MonsterService: any
local CombatService: any
local ResourceService: any
local StatusEffectService: any
local StatService: any
local LevelService: any
local InventoryService: any
local MailService: any
local LootService: any
local AnnounceService: any
local WorldEventService: any
local FightLogService: any
local PvpService: any
local SeasonService: any -- S152: season pass points (registry.Get only, no Deps)

local rng = Rng.new()
local current: Fight? = nil
local forcedCount = 0
local lastSchedule: number? = nil -- Clock time of the previous schedule step (warnings cross once)
local lastPublish = 0
local lastSent: { [Player]: string } = {}
local finished: { [string]: boolean } = {} -- occurrences already fought on this server (never twice)

local BOSS_STEP = 0.1
local SCHEDULE_STEP = 1

local function now(): number
	return Clock.now()
end

local function mapDef(): Maps.MapDef?
	return Maps.get(Data.map)
end

local function mapArg(): string
	local map = mapDef()
	return if map then "@" .. map.nameKey else Data.map
end

local function bossArg(): string
	return "@" .. WorldBoss.def().nameKey
end

local function rootOf(player: Player): BasePart?
	local model = player.Character
	return if model then model:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function playing(player: Player): boolean
	return PlayerStateService.GetPhase(player) == "playing" and PlayerStateService.GetCharacter(player) ~= nil
end

local function onMap(player: Player): boolean
	local zone = ZoneService.GetZone(player)
	return zone ~= nil and zone.map == Data.map
end

-- Map-relative x, z of a player on the boss's map, or nil.
local function relative(player: Player): (number?, number?)
	local map = mapDef()
	local root = rootOf(player)
	if not map or not root or not onMap(player) then
		return nil, nil
	end
	return root.Position.X - map.offset.x, root.Position.Z - map.offset.z
end

local function inArena(player: Player): boolean
	local x, z = relative(player)
	return x ~= nil and z ~= nil and WorldBoss.inArena(WorldBoss.spot(), x, z)
end

local function bossAlive(f: Fight?): boolean
	local boss = if f then f.boss else nil
	return boss ~= nil and boss:IsAlive()
end

-- The fighters: living, playing players in the circle on the map.
local function fighters(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if playing(player) and not ResourceService.IsDead(player) and inArena(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function announceTo(players: { Player }, key: string, args: { [string]: any }?)
	for _, player in players do
		Net.Fire(player, "BossAnnounce", key, args)
	end
end

-- Contribution ------------------------------------------------------------------------------------------------

local function bankAdd(f: Fight, player: Player, field: "dmg" | "heal" | "shield" | "intercept", amount: number)
	if amount <= 0 or amount ~= amount then
		return
	end
	local c = f.bank[player]
	if not c then
		c = Contribution.empty()
		f.bank[player] = c
	end
	c[field] += amount
	if f.chars[player] == nil then
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		if char then
			f.chars[player] = char.id
		end
	end
end

local function contributions(f: Fight): ({ [Player]: number }, number)
	local per: { [Player]: number } = {}
	local total = 0
	for player, c in f.bank do
		local points = WorldBoss.points(c)
		per[player] = points
		total += points
	end
	return per, total
end

-- Whether the fight is on (the boss up and alive): contributions count only then.
local function fighting(f: Fight?): boolean
	return f ~= nil and f.state == "active" and bossAlive(f)
end

-- Client state ------------------------------------------------------------------------------------------------

local function liveOf(f: Fight): WorldBoss.Live
	local boss = f.boss
	local hp = 1
	local channel = nil
	if boss then
		hp = if boss:IsAlive() then boss:HpFraction() else 0
		f.bossPhase = boss.phase
		local c = boss:ChannelState()
		if c then
			channel = {
				id = c.id,
				endsAt = now() + math.max(0, c.endsAt - os.clock()),
				need = c.need,
				done = math.min(c.done, c.need),
			}
		end
	end
	if f.state == "slain" then
		hp = 0
	end
	return { phase = f.state, hp = hp, bossPhase = f.bossPhase, channel = channel }
end

local function publishTo(
	player: Player,
	f: Fight?,
	base: WorldBoss.Public?,
	per: { [Player]: number },
	total: number,
	idle: WorldBoss.Idle
)
	if not PlayerStateService.HasState(player) then
		return
	end
	local value: any = idle
	if f and base then
		value = table.clone(base) :: any
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		local points = per[player] or 0
		local account = PlayerStateService.Get(player, { "account" })
		local ok, reason = false, nil :: WorldBoss.Reason?
		if char then
			ok, reason = WorldBoss.canReward(account, char.level, points, total, f.occ.id)
		end
		value.mine = WorldBoss.mineOf(points, total, ok, reason)
	end
	local key = HttpService:JSONEncode(value)
	if lastSent[player] == key then
		return
	end
	lastSent[player] = key
	PlayerStateService.Set(player, { "worldBoss" }, value)
end

local function publishAll()
	lastPublish = os.clock()
	local f = current
	local t = now()
	local idle = WorldBoss.idleOf(t)
	local base: WorldBoss.Public? = nil
	local per, total = {}, 0
	if f and not f.closed then
		base = WorldBoss.publicOf(f.occ, liveOf(f))
		per, total = contributions(f)
	end
	for _, player in Players:GetPlayers() do
		publishTo(player, if base then f else nil, base, per, total, idle)
	end
end

-- Reward ------------------------------------------------------------------------------------------------------

local function mailItems(player: Player, charId: string, items: { Types.ItemInstance })
	local sent, err = MailService.Send(player.UserId, {
		from = "system",
		subjectKey = "mail.subject.worldBoss",
		items = items,
		charId = charId,
	})
	if sent then
		if player.Parent ~= nil then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "worldboss.mailed", nil, "info")
		end
		return
	end
	log:warn("world boss reward for %s not mailed: %s", player.Name, tostring(err))
	local root = if player.Parent ~= nil then rootOf(player) else nil
	if root then
		LootService.SpawnBag(player, root.Position, items, "worldBoss", true)
	else
		log:warn("world boss reward of %s lost: the player left", player.Name)
	end
end

-- EXP, gold, materials and the item of one winner; returns the items for the fight summary.
local function giveReward(player: Player, char: Types.CharacterData): { any }
	local r = WorldBoss.reward(char.level, true)
	LevelService.GiveExp(player, r.exp, "worldBoss")
	if r.gold > 0 then
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return gold + r.gold
		end)
		Analytics.gold(player, r.gold, balance, "worldBoss")
	end
	local expBonus = StatService.GetValue(player, "expBonus")
	local shownExp = if char.level >= 100 then 0 else math.floor(r.exp * (1 + expBonus / 100))
	Net.Fire(player, "CombatFx", { { k = "reward", exp = shownExp, gold = r.gold } })
	local items: { Types.ItemInstance } = {}
	local drop = WorldBoss.rollItem(char.level, char.class, rng)
	if drop then
		local rolled = ItemRoll.rollItem(
			drop.defId,
			drop.ilvl,
			drop.rarity,
			rng,
			InventoryService.NewUid(),
			drop.forClass,
			{ family = WorldBoss.def().family :: string? }
		)
		if Data.reward.bound then
			rolled.bound = true
		end
		table.insert(items, rolled)
		if drop.rarity >= Rarities.LEGENDARY then
			Analytics.custom(player, if drop.rarity >= Rarities.MYTHIC then "WorldBossMythic" else "WorldBossLegendary")
		end
	else
		log:warn("no world boss item at level %d for %s", char.level, char.class)
	end
	for _, m in WorldBoss.rollMaterials(rng) do
		table.insert(items, ItemRoll.makeStack(m.id, m.n, InventoryService.NewUid()))
	end
	if #items > 0 then
		if not InventoryService.IsTradeLocked(player) and InventoryService.CanFit(player, items) then
			for _, item in items do
				local leftover = InventoryService.AddItem(player, item)
				if leftover > 0 then
					log:warn("%s: world boss item %s did not fit after CanFit", player.Name, item.id)
				end
			end
		else
			task.spawn(mailItems, player, char.id, items)
		end
	end
	Analytics.custom(player, "WorldBossReward", char.level)
	local listed = {}
	for _, item in items do
		table.insert(listed, { id = item.id, r = item.rarity, up = item.up, n = item.n })
	end
	-- S149b: the reward card (BossReward in its world boss form) instead of the S149 toast
	Net.Fire(player, "WorldBossReward", { boss = WorldBoss.def().id, exp = shownExp, gold = r.gold, items = listed })
	return listed
end

-- Rewards every participant still here with the same character (the check and the account write without a yield
-- between them). Returns the participants and the rewarded, and the items for the fight summary.
local function rewardAll(f: Fight): (number, number, { [Player]: { any } })
	local per, total = contributions(f)
	local participants, rewarded = 0, 0
	local drops: { [Player]: { any } } = {}
	for player, points in per do
		if points <= 0 then
			continue
		end
		participants += 1
		if player.Parent == nil or not playing(player) then
			continue
		end
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		if not char or f.chars[player] ~= char.id then
			continue
		end
		local account = PlayerStateService.Get(player, { "account" })
		local ok, reason = WorldBoss.canReward(account, char.level, points, total, f.occ.id)
		if not ok then
			-- S149b: the card with the reason instead of the loot (level / share / claimed)
			Net.Fire(
				player,
				"WorldBossReward",
				{ boss = WorldBoss.def().id, reason = reason, level = WorldBoss.minLevel() }
			)
			continue
		end
		-- one reward per account and real occurrence: the id is written at once, before anything can yield
		if not f.forced then
			PlayerStateService.Set(player, { "account", "worldBoss" }, { last = f.occ.id })
		end
		local done, result = pcall(giveReward, player, char)
		if done then
			rewarded += 1
			drops[player] = result
			-- S151: a rewarded world boss fight (achievements)
			QuestEvents.fire(player, "worldboss", { occId = f.occ.id, bossId = WorldBoss.def().id })
			SeasonService.Add(player, "worldBoss") -- S152: a rewarded fight
		else
			log:error("world boss reward for %s failed: %s", player.Name, tostring(result))
		end
	end
	return participants, rewarded, drops
end

-- Start and end -----------------------------------------------------------------------------------------------

local function newFight(occ: Occurrence, forced: boolean): Fight
	-- fought here already, or already over when this server met it (a server started in the linger): no boss, no
	-- announcement, no marker
	local done = finished[occ.id] == true or now() >= occ.endsAt
	return {
		occ = occ,
		forced = forced,
		state = if done then "left" elseif now() < occ.startsAt then "warn" else "active",
		boss = nil,
		bossPhase = 1,
		centre = nil,
		helpers = {},
		bank = {},
		chars = {},
		fightId = nil,
		spawnedAt = nil,
		endedAt = nil,
		closed = done, -- fought here already (an admin occurrence took its place) or over: never again
	}
end

local function despawnHelpers(f: Fight)
	for monster in f.helpers do
		if monster.state ~= "dead" and monster.model.Parent ~= nil then
			MonsterService.Despawn(monster)
		end
	end
	f.helpers = {}
end

local function services(f: Fight): Boss.Services
	return {
		spawnCustom = MonsterService.SpawnCustom,
		spawnMonster = function(monsterId: string, level: number, at: CFrame, attributes: { [string]: any }?)
			local monster = MonsterService.SpawnAt(monsterId, "normal", level, at, nil, attributes)
			if monster then
				monster.noReward = true -- no loot and no EXP (CombatService)
				monster.home = f.centre
				f.helpers[monster] = true
				if f.fightId then
					FightLogService.BindEvent(f.fightId, monster)
				end
			end
			return monster
		end,
		despawn = MonsterService.Despawn,
		telegraph = function(monster: any, ability: any, area: CFrame, opts: any?)
			CombatService.MonsterTelegraph(monster, ability, area, opts)
		end,
		resolve = function(monster: any, ability: any, area: CFrame, opts: any?)
			CombatService.MonsterResolve(monster, ability, area, opts)
		end,
		blow = function(monster: any, ability: any, area: CFrame)
			CombatService.MonsterBlow(monster, ability, area)
		end,
		cancelMark = function(monster: any, ability: any, player: Player)
			CombatService.MonsterTelegraphCancel(monster, ability, player)
		end,
		fighters = fighters,
		position = function(player: Player): Vector3?
			local root = rootOf(player)
			return if root then root.Position else nil
		end,
		announce = function(key: string, args: { [string]: any }?)
			announceTo(fighters(), key, args)
		end,
		announceTo = function(players: { Player }, key: string, args: { [string]: any }?)
			announceTo(players, key, args)
		end,
		nameOf = function(player: Player): string
			local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
			return if char then char.name else player.DisplayName
		end,
	}
end

-- Puts the boss up (the map must be built). Returns whether it stands.
local function spawnBoss(f: Fight): boolean
	if f.boss or not WorldService.IsBuilt(Data.map) then
		return f.boss ~= nil
	end
	local def = WorldBoss.def()
	local spot = WorldBoss.spot()
	local ground = WorldService.FloorAt(Data.map, spot.x, spot.z)
	f.centre = ground
	f.fightId = FightLogService.Begin("worldboss", f.occ.id, nil, def.nameKey)
	local boss = Boss.new(def, CFrame.new(ground), services(f))
	local monster = boss.monster
	monster.leashRange = spot.r -- back to the centre when the target runs past the arena
	monster.keepHp = true -- the open world: no healing on the way back (Entities/Monster.StartReturn)
	monster.home = ground
	f.boss = boss
	f.spawnedAt = now()
	FightLogService.Bind(f.fightId, monster)
	AnnounceService.Server("worldboss.spawn", { boss = bossArg(), map = mapArg() })
	log:info(
		"%s up for %s (%s), %d s to its leave",
		def.id,
		f.occ.id,
		if f.forced then "forced" else "scheduled",
		math.floor(f.occ.endsAt - now())
	)
	return true
end

-- The kill: rewards, the announcement, the summary.
local function win(f: Fight)
	local boss = f.boss
	f.state = "slain"
	f.endedAt = now()
	finished[f.occ.id] = true
	if boss then
		f.bossPhase = boss.phase
		boss:ClearMechanics() -- no mark left on a character (Boss.Step does not run after the kill)
	end
	f.boss = nil -- the corpse is MonsterService's
	despawnHelpers(f)
	local participants, rewarded, drops = rewardAll(f)
	local seconds = if f.spawnedAt then now() - f.spawnedAt else 0
	AnnounceService.Server("worldboss.slain", { boss = bossArg(), time = Time.format(seconds), players = participants })
	if f.fightId then
		-- S149b: the contribution points give every summary its place (FightStats.place)
		local per = contributions(f)
		FightLogService.End(f.fightId, "win", { drops = drops, points = per })
		f.fightId = nil
	end
	log:info("%s slain in %d s, %d participant(s), %d rewarded", f.occ.id, math.floor(seconds), participants, rewarded)
	publishAll()
end

-- The time ran out (or an admin stop with `silent`): the boss leaves in a burst of ice, the helpers vanish.
local function leave(f: Fight, silent: boolean?)
	local boss = f.boss
	f.state = "left"
	f.endedAt = now()
	finished[f.occ.id] = true
	if boss then
		f.bossPhase = boss.phase
		if boss:IsAlive() then
			local monster = boss.monster
			local def = WorldBoss.def()
			local stomp: any = nil
			for _, attack in def.attacks do
				if attack.id == "glacierStomp" then
					stomp = attack
				end
			end
			if stomp then
				-- an existing effect (the stomp's ring and shake), no new asset
				CombatService.MonsterBlow(
					monster,
					{ id = stomp.id, shape = stomp.shape, radius = stomp.radius, element = stomp.element } :: any,
					CFrame.new(monster:Position())
				)
			end
		end
		boss:Destroy()
		f.boss = nil
	end
	despawnHelpers(f)
	if f.fightId then
		if silent then
			FightLogService.Drop(f.fightId)
		else
			local per = contributions(f)
			FightLogService.End(f.fightId, "fail", { points = per })
		end
		f.fightId = nil
	end
	if not silent then
		AnnounceService.Server("worldboss.left", { boss = bossArg() })
	end
	local _, total = contributions(f)
	log:info("%s %s, %d points", f.occ.id, if silent then "stopped" else "left", math.floor(total))
	publishAll()
end

-- Schedule ----------------------------------------------------------------------------------------------------

local function stepSchedule()
	if not ServerMode.isWorld() then
		return
	end
	local t = now()
	local from = lastSchedule or t
	lastSchedule = t
	local f = current
	if not (f and f.forced and not f.closed) then
		local occ = WorldBoss.occurrenceAt(t)
		if occ and not (f and f.occ.id == occ.id) then
			if f and bossAlive(f) then
				leave(f)
			end
			f = newFight(occ, false)
			current = f
			log:info("occurrence %s, starts in %d s", occ.id, math.floor(occ.startsAt - t))
		elseif not occ and f and not f.forced then
			if bossAlive(f) then
				leave(f)
			end
			current = nil
			f = nil
			publishAll()
		end
	end
	if not f then
		return
	end
	-- the warnings crossed since the last step (a server starting late never announces the missed ones)
	for _, before in Data.schedule.warn do
		local at = f.occ.startsAt - before
		if from < at and at <= t and t < f.occ.startsAt then
			AnnounceService.Server("worldboss.warn", {
				boss = bossArg(),
				minutes = math.floor(before / 60 + 0.5),
				map = mapArg(),
				level = WorldBoss.minLevel(),
			})
		end
	end
	if f.state == "warn" and t >= f.occ.startsAt then
		f.state = "active"
	end
	if f.state == "active" then
		if t >= f.occ.endsAt then
			leave(f)
		elseif not f.boss then
			spawnBoss(f)
		end
	end
	if
		(f.state == "slain" or f.state == "left")
		and not f.closed
		and f.endedAt
		and t >= f.endedAt + Data.schedule.linger
	then
		f.closed = true
		if f.forced then
			current = nil
		end
		publishAll()
	end
end

local function stepBoss()
	local f = current
	local boss = if f then f.boss else nil
	if not f or not boss or f.state ~= "active" then
		return
	end
	if not boss:IsAlive() then
		win(f)
		return
	end
	boss:Step(os.clock())
	for monster in f.helpers do
		if monster.state == "dead" or monster.model.Parent == nil then
			f.helpers[monster] = nil
		end
	end
end

-- Blocks world events (S101) in [startsAt - warn[2], endsAt] of every occurrence (and a forced one).
local function blocks(from: number, to: number): boolean
	local s = Data.schedule
	local near = s.warn[#s.warn] or 0
	local timeLimit = WorldBoss.def().timeLimit
	for _, occ in WorldBoss.list(from - timeLimit - 1, to + near + 1) do
		if occ.startsAt - near < to and occ.endsAt > from then
			return true
		end
	end
	local f = current
	if f and f.forced and not f.closed and (f.state == "warn" or f.state == "active") then
		return f.occ.startsAt - near < to and f.occ.endsAt > from
	end
	return false
end

-- Admin (/worldboss) -------------------------------------------------------------------------------------------

export type Info = {
	id: string?,
	state: string,
	hp: number?,
	phase: number?,
	timeLeft: number?,
	participants: number,
	top: { { name: string, points: number, ok: boolean } },
	nextId: string,
	nextIn: number,
}

function WorldBossService.Info(): Info
	local t = now()
	local nextOcc = WorldBoss.next(t)
	local f = current
	local info: Info = {
		id = nil,
		state = "none",
		participants = 0,
		top = {},
		nextId = nextOcc.id,
		nextIn = math.max(0, nextOcc.startsAt - t),
	}
	if not f then
		return info
	end
	info.id = f.occ.id
	info.state = f.state
	local boss = f.boss
	if boss and boss:IsAlive() then
		info.hp = math.floor(boss:HpFraction() * 1000 + 0.5) / 10
		info.phase = boss.phase
	end
	info.timeLeft = math.max(0, (if f.state == "warn" then f.occ.startsAt else f.occ.endsAt) - t)
	local per, total = contributions(f)
	local rows = {}
	for player, points in per do
		local char: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		local ok = false
		if char then
			ok = WorldBoss.canReward(PlayerStateService.Get(player, { "account" }), char.level, points, total, f.occ.id)
		end
		table.insert(rows, { name = if char then char.name else player.Name, points = math.floor(points), ok = ok })
	end
	table.sort(rows, function(a, b): boolean
		return a.points > b.points
	end)
	info.participants = #rows
	for i = 1, math.min(5, #rows) do
		table.insert(info.top, rows[i])
	end
	return info
end

-- /worldboss start [now]: an admin occurrence on this server ("wbforce<n>", never a real occurrence's reward); with
-- `immediate` the boss stands at once, else after the last warning (2 min).
function WorldBossService.Force(immediate: boolean): (boolean, string?)
	if not ServerMode.isWorld() then
		return false, "admin.worldboss.notWorld"
	end
	local f = current
	if f and bossAlive(f) then
		return false, "admin.worldboss.busy"
	end
	forcedCount += 1
	local s = Data.schedule
	local startsAt = now() + (if immediate then 0 else (s.warn[#s.warn] or 0))
	local occ = WorldBoss.forced(forcedCount, startsAt)
	local fight = newFight(occ, true)
	current = fight
	if not immediate then
		AnnounceService.Server("worldboss.warn", {
			boss = bossArg(),
			minutes = math.floor((s.warn[#s.warn] or 0) / 60 + 0.5),
			map = mapArg(),
			level = WorldBoss.minLevel(),
		})
	end
	lastSchedule = now() -- the warning above counts as crossed: stepSchedule must not announce it again
	stepSchedule()
	publishAll()
	return true, occ.id
end

-- /worldboss stop: the boss goes without rewards (no announcement); a real occurrence stays used on this server.
function WorldBossService.Stop(): boolean
	local f = current
	if not f or f.closed or (f.state ~= "warn" and f.state ~= "active") then
		return false
	end
	leave(f, true)
	f.closed = true
	if f.forced then
		current = nil
	end
	publishAll()
	return true
end

-- /worldboss hp <pct>: sets the boss's HP (1-100 % of the max).
function WorldBossService.SetHp(pct: number): boolean
	local f = current
	local boss = if f then f.boss else nil
	if not boss or not boss:IsAlive() then
		return false
	end
	local monster = boss.monster
	monster.hp = math.max(1, math.floor(monster.stats.maxHp * math.clamp(pct, 1, 100) / 100))
	monster.model:SetAttribute("Hp", monster.hp)
	return true
end

-- /worldboss phase <n>: forces a phase (HP just under its threshold, like DungeonService.ForcePhase).
function WorldBossService.SetPhase(phase: number): boolean
	local f = current
	local boss = if f then f.boss else nil
	if not boss or not boss:IsAlive() then
		return false
	end
	local thresholds = WorldBoss.def().phases
	local fraction = if phase <= 1 then 1 elseif thresholds[phase - 1] then thresholds[phase - 1] - 0.01 else 0.3
	local monster = boss.monster
	monster.hp = math.max(1, math.floor(monster.stats.maxHp * fraction))
	monster.model:SetAttribute("Hp", monster.hp)
	boss:SetPhase(phase)
	return true
end

-- The fight right now (tests of other services, S149b's HUD helpers).
function WorldBossService.Current(): Fight?
	return current
end

function WorldBossService.Init(registry)
	SeasonService = registry.Get("SeasonService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ZoneService = registry.Get("ZoneService")
	WorldService = registry.Get("WorldService")
	MonsterService = registry.Get("MonsterService")
	CombatService = registry.Get("CombatService")
	ResourceService = registry.Get("ResourceService")
	StatusEffectService = registry.Get("StatusEffectService")
	StatService = registry.Get("StatService")
	LevelService = registry.Get("LevelService")
	InventoryService = registry.Get("InventoryService")
	MailService = registry.Get("MailService")
	LootService = registry.Get("LootService")
	AnnounceService = registry.Get("AnnounceService")
	WorldEventService = registry.Get("WorldEventService")
	FightLogService = registry.Get("FightLogService")
	PvpService = registry.Get("PvpService")
end

function WorldBossService.Start()
	if not ServerMode.isWorld() then
		log:info("not a world server: no world boss here")
		return
	end
	-- one big event at a time: no Invasion or Champion in the boss's window
	WorldEventService.AddBlocker(blocks, "worldboss.name")
	-- no PvP in the circle while the boss lives (either side inside)
	PvpService.AddFightRule(function(attacker: Player, target: Player): string?
		-- S156: the vestibule is free of PvP at every hour, the circle while the boss lives
		local alive = bossAlive(current)
		local spot = WorldBoss.spot()
		for _, player in { attacker, target } do
			local x, z = relative(player)
			if x and z and WorldBoss.pvpSafe(spot, x, z, alive) then
				return "pvp.deny.worldBoss"
			end
		end
		return nil
	end)
	-- S134d (Logic/UseBlocks): Auto Hunt stops in the circle of a living world boss (like a world event's radius)
	UseGuards.register("worldEvent", function(player: Player): boolean
		return bossAlive(current) and inArena(player)
	end, "WorldBossService")
	-- S150 (Logic/UseBlocks friendJoin): no teleport to a friend's server from the circle of a living world boss
	UseGuards.register("worldBoss", function(player: Player): boolean
		return bossAlive(current) and inArena(player)
	end, "WorldBossService")
	CombatService.MonsterDamaged:Connect(function(monster: any, player: Player, dealt: number)
		local f = current
		local boss = if f then f.boss else nil
		-- the killing blow counts too (the boss may already be dead when its damage is booked)
		if f and boss and f.state == "active" and (monster == boss.monster or f.helpers[monster]) then
			bankAdd(f, player, "dmg", dealt)
		end
	end)
	ResourceService.Healed:Connect(function(target: Player, amount: number, source: Player?, kind: string)
		local f = current
		if f and source and fighting(f) and inArena(target) then
			bankAdd(f, source, if kind == "shield" then "shield" else "heal", amount)
		end
	end)
	StatusEffectService.Intercepted:Connect(function(guard: Player, target: Player, moved: number)
		local f = current
		if f and fighting(f) and inArena(target) then
			bankAdd(f, guard, "intercept", moved)
		end
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	PlayerStateService.Ready:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
	local bossClock, scheduleClock = 0, SCHEDULE_STEP
	RunService.Heartbeat:Connect(function(dt)
		bossClock += dt
		scheduleClock += dt
		if bossClock >= BOSS_STEP then
			bossClock = 0
			local ok, err = pcall(function()
				stepBoss()
			end)
			if not ok then
				log:error("world boss step failed: %s", tostring(err))
			end
		end
		if scheduleClock >= SCHEDULE_STEP then
			scheduleClock = 0
			local ok, err = pcall(function()
				stepSchedule()
			end)
			if not ok then
				log:error("world boss schedule failed: %s", tostring(err))
			end
		end
		if os.clock() - lastPublish >= Data.publishEvery then
			local ok, err = pcall(function()
				publishAll()
			end)
			if not ok then
				log:error("world boss publish failed: %s", tostring(err))
			end
		end
	end)
	log:info("world boss %s on %s, next %s", Data.boss, Data.map, WorldBoss.next(now()).id)
end

return WorldBossService
