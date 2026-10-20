--!strict
-- Boss dungeons (DESIGN §16). One group at a time per dungeon on a server. The leader (or a solo player)
-- enters at the gate in the cave; party members within 20 studs come along if they meet the level
-- (boss − 5) and have kills left today (S30: Config.Boss.dailyRuns per boss; others are told why they stay).
-- After a 5 s countdown the boss appears (Entities/Boss). The run fails after 15 minutes or when nobody is left
-- fighting: everyone is sent out and the boss resets. On a kill: EXP and gold from the party pool (S134b,
-- Logic/PartyLoot); every winner gets one item
-- in an own bag nobody else sees (FIX 2026-10-09, Loot.rollBossItem: Mythic 1 %, Legendary 6 %, +1 % each per kill
-- of this boss today, else Unique / Heroic) with materials and a chance of a legendary blessing; one daily run used
-- for everyone present, a server announcement; the dungeon is released 60 s later or when everybody has left
-- through the exit portal.
-- S60: Fortune of the winners (Logic/Luck.boss: Legendary multiplier, Unique -> Heroic, a second item), the class
-- variety bonus on the boss EXP and a fight summary (damage share, healing, shields) on every winner's reward card.
-- Fighters see the state branch `boss` = { id, nameKey, hp, maxHp, phase, endsAt, enraged, shielded, staggered,
-- channel? } (S134: `channel` = { id, endsAt, need, done } while the boss channels a spell to break).
-- S134f: a leader with a member able to come along asks "Ready?" first (Logic/ReadyCheck, state branch `readyCheck`,
-- remote DungeonReady, 3-2-1, then the gate checks again); the fight summary comes from FightLogService (the S60 healing /
-- shield / intercept books moved there) with the time, deaths, dodged blows and the party's loot on the reward card.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Blessings = require(Shared.Data.Blessings)
local Boss = require(script.Parent.Parent.Entities.Boss)
local BossScaling = require(Shared.Logic.BossScaling)
local Bosses = require(Shared.Data.Bosses)
local Clock = require(Shared.Util.Clock)
local Exp = require(Shared.Logic.Exp)
local FightStats = require(Shared.Logic.FightStats)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Config = require(Shared.Config)
local Loot = require(Shared.Logic.Loot)
local Luck = require(Shared.Logic.Luck)
local PartyBonus = require(Shared.Logic.PartyBonus)
local LootTables = require(Shared.Data.LootTables)
local Maps = require(Shared.Data.Maps)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Rarities = require(Shared.Data.Rarities)
local ReadyCheck = require(Shared.Logic.ReadyCheck)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("DungeonService")

local DungeonService = {
	Name = "DungeonService",
	Deps = {
		"PlayerStateService",
		"PartyService",
		"TravelService",
		"WorldService",
		"MonsterService",
		"CombatService",
		"ResourceService",
		"LevelService",
		"LootService",
		"AnnounceService",
		"StatService",
		"MountService", -- S97: the boss mount roll (MountService never depends on this service)
		"CosmeticService", -- S132: class outfits of a boss win (CosmeticService never depends on this service)
		"FightLogService", -- S134f: the after-fight meter (the S60 summary moved there)
	},
}

local ENTRANCE_RANGE = 30
local STATE_INTERVAL = 0.25

type Run = {
	region: string,
	def: Bosses.BossDef,
	mapId: string,
	leader: Player,
	leaderName: string,
	members: { Player },
	startedAt: number, -- os.clock()
	endsAt: number, -- server time (Workspace:GetServerTimeNow) shown to clients
	deadline: number, -- os.clock()
	boss: Boss.Boss?,
	cleared: boolean,
	releaseAt: number?,
	lastState: number,
	warned: { [number]: boolean }, -- time-left warnings already sent (minutes)
	fightId: number?, -- S134f: the FightLogService fight while the boss is up (healing, shields, intercepts: S60 / S61)
}

local PlayerStateService: any
local PartyService: any
local TravelService: any
local WorldService: any
local MonsterService: any
local CombatService: any
local ResourceService: any
local LevelService: any
local LootService: any
local AnnounceService: any
local StatService: any
local MountService: any
local CosmeticService: any
local FightLogService: any
local Registry: any
local PathService: any
local SeasonService: any -- S152: season pass points (registry.Get only, no Deps)

-- Lazy: PathService depends on this service (NearAnyEntrance), so a Deps entry here would be a cycle. Never call
-- during Init.
local function pathService(): any
	PathService = PathService or Registry.Get("PathService")
	return PathService
end

local rng = Rng.new()
local runs: { [string]: Run } = {}

-- S134f: a ready check at a dungeon gate (one per dungeon; the dungeon counts as busy meanwhile).
type Pending = {
	check: ReadyCheck.Check,
	leader: Player,
	entering: { Player },
	def: Bosses.BossDef,
	counted: number, -- the last 3-2-1 number announced
}
local checks: { [string]: Pending } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function nameOf(player: Player): string
	local char = character(player)
	return if char then char.name else player.DisplayName
end

local function caveOf(region: string): Maps.MapDef?
	for _, map in Maps.byId do
		if map.dungeonRegion == region and map.dungeonEntrance then
			return map
		end
	end
	return nil
end

local function entranceCFrame(region: string): CFrame?
	local cave = caveOf(region)
	local e = cave and cave.dungeonEntrance
	if not cave or not e then
		return nil
	end
	return WorldService.GroundCFrame(cave.id, e.x - 22, e.z)
end

local function onMap(player: Player, mapId: string): boolean
	local char = character(player)
	return player.Parent ~= nil and char ~= nil and char.location.map == mapId
end

-- Members on the dungeon map and alive.
local function fighters(run: Run): { Player }
	local list = {}
	for _, member in run.members do
		if onMap(member, run.mapId) and not ResourceService.IsDead(member) then
			table.insert(list, member)
		end
	end
	return list
end

local function present(run: Run): { Player }
	local list = {}
	for _, member in run.members do
		if onMap(member, run.mapId) then
			table.insert(list, member)
		end
	end
	return list
end

local function announce(run: Run, key: string, args: { [string]: any }?)
	for _, member in present(run) do
		Net.Fire(member, "BossAnnounce", key, args)
	end
end

-- S134: a big message to some of the players present (a boss mark).
local function announceTo(run: Run, players: { Player }, key: string, args: { [string]: any }?)
	local here = present(run)
	for _, player in players do
		if table.find(here, player) then
			Net.Fire(player, "BossAnnounce", key, args)
		end
	end
end

local function clearState(player: Player)
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "boss" }, nil)
	end
end

local function sendOut(run: Run, player: Player)
	clearState(player)
	local cave = caveOf(run.region)
	local at = entranceCFrame(run.region)
	if cave and onMap(player, run.mapId) then
		task.spawn(TravelService.TeleportToMap, player, cave.id, at)
	end
end

local function finish(run: Run)
	if run.fightId then
		FightLogService.Drop(run.fightId) -- S134f: ended without a win or a fail (admin reset)
		run.fightId = nil
	end
	if run.boss then
		run.boss:Destroy()
		run.boss = nil
	end
	for _, member in run.members do
		sendOut(run, member)
	end
	runs[run.region] = nil
end

-- A failed run (timeout or wipe) uses one of today's attempts of everyone who entered, without a kill (no bonus to
-- the Legendary / Mythic chances).
local function useAttempt(run: Run)
	local now = Clock.now()
	for _, member in run.members do
		local char = member.Parent and character(member)
		if char then
			PlayerStateService.Set(
				member,
				{ "character", "bossRuns", run.def.id },
				BossScaling.addRun(char.bossRuns, run.def.id, now, false)
			)
		end
	end
end

local function fail(run: Run, key: string)
	log:info("%s dungeon failed (%s)", run.region, key)
	if run.fightId then
		FightLogService.End(run.fightId, "fail") -- S134f
		run.fightId = nil
	end
	useAttempt(run)
	announce(run, key, { boss = `@{run.def.nameKey}` })
	task.delay(2.5, function()
		if runs[run.region] == run then
			finish(run)
		end
	end)
	run.deadline = math.huge
	if run.boss then
		run.boss:Destroy()
		run.boss = nil
	end
end

-- Fortune of `players` (Logic/Luck.boss): the best priest counts for everyone, also solo.
local function bossLuckOf(players: { Player }): Luck.BossLuck
	local members: { Luck.Member } = {}
	for _, player in players do
		table.insert(members, { name = nameOf(player), luck = pathService().GetLuck(player) })
	end
	return Luck.boss(members)
end

-- S134f: the active flag of the party pool (S134b) and the card summary come from the fight meter (FightLogService:
-- damage on the boss and its summons, healing, shields, intercepted blows of this attempt; S60 moved there).
local function activeIn(run: Run, player: Player): boolean
	local stat = if run.fightId then FightLogService.Stat(run.fightId, player) else nil
	return stat ~= nil and (stat.dmg > 0 or stat.heal > 0 or stat.shield > 0 or stat.intercept > 0)
end

local function reward(run: Run, position: Vector3): { [Player]: { any } }
	local drops: { [Player]: { any } } = {}
	local winners = present(run)
	local n = #winners
	if n == 0 then
		return drops
	end
	local def = run.def
	local now = Clock.now()
	local bossTable = LootTables.bosses[def.id]
	-- S60: Fortune once per kill, the same for every winner; the class variety bonus before the split.
	local bossLuck = bossLuckOf(winners)
	local luckFrom = if bossLuck.legendaryMul > 1 then bossLuck.from else nil
	local classes: { string } = {}
	for _, player in winners do
		local char = character(player)
		table.insert(classes, if char then char.class :: string else "")
	end
	-- S134b: the party pool (Logic/PartyLoot) as for monsters; active = damage on the boss, healing, shields or
	-- intercepted blows in this attempt (the fight meter), carried = more than partyCarryGap levels below the boss.
	local pool: { PartyLoot.Member } = {}
	for _, player in winners do
		local char = character(player)
		table.insert(pool, { level = if char then char.level else 0, active = activeIn(run, player) })
	end
	local expShares =
		PartyLoot.expShares(Exp.monsterExp(def.level, "boss") * PartyBonus.expMul(classes), pool, def.level)
	local shares = PartyLoot.goldShares(MonsterStats.gold(def.level, "boss", rng:next()), pool, def.level, rng)
	-- FIX 2026-10-09: every winner gets exactly one item (and the materials) in an own bag only they see and can
	-- pick up; the Legendary / Mythic chances grow with the character's kills of this boss today.
	local blessingChance = Bosses.LEGENDARY_BLESSING_CHANCE / n
	-- S134f: the cards go out after every bag is rolled (each card lists the party's loot)
	local cards: { { player: Player, card: { [string]: any } } } = {}
	for i, player in winners do
		local char = character(player)
		if char then
			local killsToday = BossScaling.killsToday(char.bossRuns, def.id, now)
			local runsToday = BossScaling.runsToday(char.bossRuns, def.id, now)
			PlayerStateService.Set(
				player,
				{ "character", "bossRuns", def.id },
				BossScaling.addRun(char.bossRuns, def.id, now, true)
			)
			-- S134c: below the old entry level (boss level - 5) the winner gets the share of its level a winner there
			-- would (Exp.bossExpFor); the helpers of the shield waves are ordinary kills (CombatService)
			local exp = math.floor(Exp.bossExpFor(char.level, def.level, expShares[i]) + 0.5)
			LevelService.GiveExp(player, exp, "boss")
			-- S151: `party` = the winners present (achievements: a won fight in a full party)
			QuestEvents.fire(player, "boss", { bossId = def.id, party = n })
			SeasonService.Add(player, "boss") -- S152: a won boss fight (Config.Boss.dailyRuns applies)
			local gold = math.floor(shares[i] * (1 + StatService.GetValue(player, "goldBonus") / 100) + 0.5)
			local balance = PlayerStateService.Update(player, { "character", "gold" }, function(current: number)
				return current + gold
			end)
			Analytics.gold(player, gold, balance, "boss")
			Analytics.progression(player, "Bosses", def.level, def.id)
			local gotLeg, gotMyth, upgraded, gotExtra = false, false, false, false
			if bossTable then
				local items = {}
				-- S134c: the boss item is always at the boss level, also for a lower winner (no clamp to the
				-- character's level; an item above it waits in the backpack like any loot)
				local drop = Loot.rollBossItem(bossTable, killsToday, char.class :: string, rng, bossLuck)
				local extraDrop = Loot.rollBossExtra(bossTable, char.class :: string, rng, bossLuck)
				if drop then
					gotLeg, gotMyth = drop.rarity == Rarities.LEGENDARY, drop.rarity == Rarities.MYTHIC
					upgraded = drop.upgraded == true
				end
				gotExtra = extraDrop ~= nil
				for _, rolled in { drop, extraDrop } :: { Loot.ItemDrop? } do
					if rolled then
						table.insert(
							items,
							ItemRoll.rollItem(
								rolled.defId,
								rolled.ilvl,
								rolled.rarity,
								rng,
								HttpService:GenerateGUID(false),
								char.class :: string,
								{ family = def.family :: string? } -- S67: family lines take the boss's family
							)
						)
					end
				end
				local extra = Loot.rollBossLoot(def.id, n, rng)
				for _, stack in LootService.InstancesFrom(extra) do
					table.insert(items, stack)
				end
				if rng:chance(blessingChance) then
					local line = Blessings.lines[rng:int(1, #Blessings.lines)]
					table.insert(items, ItemRoll.makeStack(`blessing_{line}_5`, 1, HttpService:GenerateGUID(false)))
				end
				if #items > 0 then
					LootService.SpawnBag(player, position + Vector3.new(0, 0, 3), items, def.id, true, luckFrom)
				end
				-- S134f: what the bag holds, for the "Party loot" lines of the cards and the fight summary
				local listed = {}
				for _, item in items do
					table.insert(listed, { id = item.id, r = item.rarity, up = item.up, n = item.n })
				end
				drops[player] = listed
				if gotLeg or gotMyth then
					Analytics.custom(player, if gotMyth then "BossMythic" else "BossLegendary", def.level)
				end
			end
			-- S97: the personal mount / mount skin roll, after every item roll above (their order is unchanged).
			local mountDrop = MountService.RollBossDrop(player, def.id, rng)
			if mountDrop.mount then
				Analytics.custom(player, "BossMount", def.level)
			end
			-- S132: the class outfit of this boss for every winner of that class (obtain.bossWin; no roll, rng unused)
			CosmeticService.GrantBossWin(player, def.id, char.class :: string)
			-- The chances of the next kill today.
			local chances = Loot.bossChances(def.id, killsToday + 1, bossLuck)
			table.insert(cards, {
				player = player,
				card = {
					k = "reward",
					exp = exp,
					gold = gold,
					boss = def.id,
					gotLeg = gotLeg,
					gotMyth = gotMyth,
					leg = chances.legendary,
					myth = chances.mythic,
					runs = runsToday + 1,
					dailyRuns = Config.Boss.dailyRuns,
					luckMul = bossLuck.legendaryMul,
					luckFrom = bossLuck.from,
					upgraded = upgraded,
					extra = gotExtra,
					mount = mountDrop.mount,
					mountSkin = mountDrop.skin,
				},
			})
		end
	end
	-- S134f: the fight summary of each winner's party (rows with the new columns, time, deaths, dodged blows) and the
	-- party's loot (own items, the others' from Legendary up)
	for _, entry in cards do
		local player = entry.player
		local card = entry.card
		local snap = if run.fightId then FightLogService.Snapshot(run.fightId, player) else nil
		if snap then
			card.sum = snap.rows
			card.fs = { time = snap.time, deaths = snap.deaths, dodged = snap.dodged, aimed = snap.aimed }
		end
		local others = {}
		for _, other in winners do
			if other ~= player and drops[other] then
				table.insert(others, { n = nameOf(other), items = drops[other] })
			end
		end
		card.drop = FightStats.dropView(drops[player], others, Rarities.LEGENDARY)
		Net.Fire(player, "CombatFx", { card })
	end
	AnnounceService.Server("announce.boss", { name = run.leaderName, boss = `@{def.nameKey}` })
	return drops
end

local function win(run: Run)
	local boss = run.boss
	local position = if boss then boss.monster:Position() else Vector3.zero
	run.cleared = true
	run.releaseAt = os.clock() + Bosses.RELEASE_AFTER
	if boss then
		boss:ClearMechanics() -- S134: no mark left on a character (Boss.Step does not run after the kill)
		for _, summon in boss:Summons() do
			if summon:IsAlive() then
				MonsterService.Despawn(summon)
			end
		end
	end
	run.boss = nil
	announce(run, "dungeon.victory", { boss = `@{run.def.nameKey}` })
	for _, member in present(run) do
		clearState(member)
	end
	local drops = reward(run, position)
	-- S134f: the after-fight summary of every party member (the reward card already has it; the fight log keeps it)
	if run.fightId then
		FightLogService.End(run.fightId, "win", { drops = drops })
		run.fightId = nil
	end
	log:info("%s cleared by %s's group (%d)", run.def.id, run.leaderName, #run.members)
end

local function publish(run: Run)
	local boss = run.boss
	if not boss then
		return
	end
	local monster = boss.monster
	local value = {
		id = run.def.id,
		nameKey = run.def.nameKey,
		hp = math.max(0, math.floor(monster.hp)),
		maxHp = monster.stats.maxHp,
		phase = boss.phase,
		endsAt = run.endsAt,
		enraged = boss.enraged,
		shielded = monster.invulnerable == true,
		staggered = boss:IsStaggered(), -- S134
		channel = nil :: any,
	}
	-- S134: the channel to break (end in server time, need / done as shares of the max HP)
	local channel = boss:ChannelState()
	if channel then
		value.channel = {
			id = channel.id,
			endsAt = Workspace:GetServerTimeNow() + math.max(0, channel.endsAt - os.clock()),
			need = channel.need,
			done = math.min(channel.done, channel.need),
		}
	end
	for _, member in present(run) do
		PlayerStateService.Set(member, { "boss" }, value)
	end
end

local function services(run: Run): Boss.Services
	return {
		spawnCustom = MonsterService.SpawnCustom,
		spawnMonster = function(monsterId: string, level: number, at: CFrame, attributes: { [string]: any }?)
			return MonsterService.SpawnAt(monsterId, "normal", level, at, nil, attributes)
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
		fighters = function()
			return fighters(run)
		end,
		position = function(player: Player): Vector3?
			local model = player.Character
			local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
			return if root then root.Position else nil
		end,
		announce = function(key: string, args: { [string]: any }?)
			announce(run, key, args)
		end,
		announceTo = function(players: { Player }, key: string, args: { [string]: any }?)
			announceTo(run, players, key, args)
		end,
		nameOf = nameOf,
	}
end

-- Arena centre on the dungeon map.
local function arenaCentre(mapId: string): CFrame
	local cf = WorldService.GroundCFrame(mapId, 0, -10)
	return CFrame.new(cf.Position - Vector3.new(0, 4, 0)) * CFrame.Angles(0, math.pi, 0)
end

-- Starts a run for `members` (already checked). Teleports them in and summons the boss after the countdown.
local function start(region: string, leader: Player, members: { Player }): Run
	local def = Bosses.forRegion(region) :: Bosses.BossDef
	local mapId = `dungeon_{region}`
	local run: Run = {
		region = region,
		def = def,
		mapId = mapId,
		leader = leader,
		leaderName = nameOf(leader),
		members = members,
		startedAt = os.clock(),
		endsAt = Workspace:GetServerTimeNow() + def.timeLimit + Bosses.COUNTDOWN,
		deadline = os.clock() + def.timeLimit + Bosses.COUNTDOWN,
		boss = nil,
		cleared = false,
		releaseAt = nil,
		lastState = 0,
		warned = {},
		fightId = nil,
	}
	runs[region] = run
	for i, member in members do
		local x = (i - (#members + 1) / 2) * 5
		task.spawn(TravelService.TeleportToMap, member, mapId, WorldService.GroundCFrame(mapId, x, 55))
	end
	task.delay(1.5, function()
		if runs[region] == run then
			announce(run, "dungeon.countdown", { boss = `@{def.nameKey}`, seconds = Bosses.COUNTDOWN })
		end
	end)
	task.delay(Bosses.COUNTDOWN + 1, function()
		if runs[region] ~= run or run.cleared then
			return
		end
		-- S134: the boss is the same for every party (the log above keeps the party size)
		local boss = Boss.new(def, arenaCentre(mapId), services(run))
		run.boss = boss
		run.startedAt = os.clock()
		-- S134f: the fight meter starts with the boss (members join at once; damage on the boss and its summons)
		local fightId = FightLogService.Begin("boss", region, present(run), def.nameKey)
		run.fightId = fightId
		FightLogService.Bind(fightId, boss.monster)
		announce(run, `boss.{def.id}.phase1`, nil)
	end)
	log:info("%s entered %s with %d player(s)", run.leaderName, region, #members)
	return run
end

-- Why a member cannot enter (nil = ok).
local function blocker(player: Player, def: Bosses.BossDef): (string?, number?)
	local char = character(player)
	if not char then
		return "dungeon.reason.offline", nil
	end
	if char.level < BossScaling.requiredLevel(def.level) then
		return "dungeon.reason.level", nil
	end
	local now = Clock.now()
	if BossScaling.isLocked(char.bossRuns, def.id, now, Config.Boss.dailyRuns) then
		return "dungeon.reason.locked", BossScaling.untilReset(now)
	end
	if ResourceService.IsDead(player) then
		return "dungeon.reason.dead", nil
	end
	return nil, nil
end

local function nearEntrance(player: Player, region: string): boolean
	local at = entranceCFrame(region)
	local model = player.Character
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return at ~= nil and root ~= nil and (root.Position - at.Position).Magnitude <= ENTRANCE_RANGE + 22
end

local function info(player: Player, region: string): (boolean, string?, any)
	local def = Bosses.forRegion(region)
	if not def then
		return false, "error.badRequest"
	end
	local run = runs[region]
	local members = {}
	local self = character(player)
	local now = Clock.now()
	-- ROZWOJ 6.4: the chance with the party's Fortune (the whole party; solo the player).
	local chances = Loot.bossChances(
		def.id,
		if self then BossScaling.killsToday(self.bossRuns, def.id, now) else 0,
		bossLuckOf(PartyService.Members(player))
	)
	local leaderRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, member in PartyService.Members(player) do
		local reason, lockLeft = blocker(member, def)
		local root = member.Character and member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not reason and member ~= player then
			if not root or not leaderRoot or (root.Position - leaderRoot.Position).Magnitude > Bosses.ENTRY_RANGE then
				reason = "dungeon.reason.far"
			end
		end
		local char = character(member)
		table.insert(members, {
			name = nameOf(member),
			level = if char then char.level else 0,
			ok = reason == nil,
			reason = reason,
			lockLeft = lockLeft,
		})
	end
	return true,
		nil,
		{
			region = region,
			bossId = def.id,
			nameKey = def.nameKey,
			level = def.level,
			required = BossScaling.requiredLevel(def.level),
			built = WorldService.IsBuilt(`dungeon_{region}`),
			busy = run ~= nil or checks[region] ~= nil, -- S134f: a ready check holds the gate too
			leaderName = if run then run.leaderName else nil,
			endsAt = if run then run.endsAt else nil,
			isLeader = PartyService.IsLeader(player),
			members = members,
			-- S30: today's kills of this boss, the limit, seconds to the reset and the personal roll chances.
			runs = if self then BossScaling.runsToday(self.bossRuns, def.id, now) else 0,
			dailyRuns = Config.Boss.dailyRuns,
			resetIn = BossScaling.untilReset(now),
			legChance = chances.legendary,
			mythChance = chances.mythic,
		}
end

-- The leader and the party members who may come along now (blocker, ENTRY_RANGE from the leader); the others are told
-- why they stay (`dungeon.leftOut`).
local function gather(leader: Player, def: Bosses.BossDef, among: { Player }): { Player }
	local root = (leader.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	local entering = { leader }
	for _, member in among do
		if member ~= leader then
			local why = blocker(member, def)
			local memberRoot = member.Character and member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not why and (not memberRoot or (memberRoot.Position - root.Position).Magnitude > Bosses.ENTRY_RANGE) then
				why = "dungeon.reason.far"
			end
			if not why and not PartyService.SameParty(leader, member) then
				why = "dungeon.reason.far"
			end
			if why then
				Net.Fire(member, "Toast", "dungeon.leftOut", { reason = `@{why}` }, "warning")
			else
				table.insert(entering, member)
			end
		end
	end
	return entering
end

-- Ready check (S134f, Logic/ReadyCheck) ------------------------------------------------------------------------
-- A leader with at least one member able to come along asks first; every asked member sees the `readyCheck` state
-- branch { region, bossKey, endsAt, members = { { id, name, answer? } }, goAt? } (server time). All "yes": a 3-2-1
-- (`dungeon.ready.count`), then the gate checks run again and the run starts as before. "No", the time, the leader
-- leaving or a party change cancels the whole check. The daily attempt is used only by the run (start / useAttempt).

local function clearCheckState(player: Player)
	if player.Parent ~= nil and PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "readyCheck" }, nil)
	end
end

local function publishCheck(region: string)
	local pending = checks[region]
	if not pending then
		return
	end
	local check = pending.check
	local offset = Workspace:GetServerTimeNow() - os.clock()
	local members = {}
	for _, member in pending.entering do
		local answer = check.answers[member.UserId]
		table.insert(members, {
			id = member.UserId,
			name = nameOf(member),
			answer = if answer == nil then nil else answer,
		})
	end
	local goAt = ReadyCheck.goAt(check)
	local value = {
		region = region,
		bossKey = pending.def.nameKey,
		endsAt = check.endsAt + offset,
		members = members,
		goAt = if goAt then goAt + offset else nil,
	}
	for _, member in pending.entering do
		if member.Parent ~= nil and PlayerStateService.HasState(member) then
			PlayerStateService.Set(member, { "readyCheck" }, value)
		end
	end
end

local function cancelCheck(region: string, key: string, args: { [string]: any }?)
	local pending = checks[region]
	if not pending then
		return
	end
	checks[region] = nil
	for _, member in pending.entering do
		clearCheckState(member)
		if member.Parent ~= nil then
			Net.Fire(member, "Toast", key, args, "warning")
		end
	end
	log:info("%s ready check cancelled (%s)", region, key)
end

-- The countdown is over: the gate checks again (the leader at the gate and alive, members in range) and the run starts.
local function launchCheck(region: string)
	local pending = checks[region]
	if not pending then
		return
	end
	local leader = pending.leader
	if
		runs[region]
		or leader.Parent == nil
		or not PartyService.IsLeader(leader)
		or not nearEntrance(leader, region)
		or blocker(leader, pending.def) ~= nil
	then
		cancelCheck(region, "dungeon.ready.cancelled")
		return
	end
	checks[region] = nil
	for _, member in pending.entering do
		clearCheckState(member)
	end
	local among = {}
	for _, member in pending.entering do
		if member.Parent ~= nil then
			table.insert(among, member)
		end
	end
	local entering = gather(leader, pending.def, among)
	if #entering < 2 then
		-- nobody is left with the leader (the others were told why): the check is called off, the leader may enter alone
		Net.Fire(leader, "Toast", "dungeon.ready.cancelled", nil, "warning")
		return
	end
	start(region, leader, entering)
end

local function stepChecks(now: number)
	for region, pending in checks do
		local check = pending.check
		local status = ReadyCheck.status(check, now)
		if status == "expired" then
			cancelCheck(region, "dungeon.ready.expired")
		elseif status == "go" then
			local goAt = ReadyCheck.goAt(check) :: number
			if now >= goAt then
				launchCheck(region)
			else
				local left = math.ceil(goAt - now - 1e-3)
				if left >= 1 and left ~= pending.counted then
					pending.counted = left
					for _, member in pending.entering do
						if member.Parent ~= nil then
							Net.Fire(member, "BossAnnounce", "dungeon.ready.count", { n = left })
						end
					end
				end
			end
		end
	end
end

-- The pending check `player` was asked in (region, check), or nil.
local function checkOf(player: Player): (string?, Pending?)
	for region, pending in checks do
		if table.find(pending.entering, player) then
			return region, pending
		end
	end
	return nil, nil
end

local function readyAnswer(player: Player, yes: boolean): (boolean, string?)
	local region, pending = checkOf(player)
	if not region or not pending then
		return false, "dungeon.ready.notAsked"
	end
	local now = os.clock()
	local ok, err = ReadyCheck.answer(pending.check, player.UserId, yes, now)
	if not ok then
		return false, err
	end
	if ReadyCheck.status(pending.check, now) == "declined" then
		cancelCheck(region, "dungeon.ready.declined", { name = nameOf(player) })
		return true, nil
	end
	publishCheck(region)
	return true, nil
end

-- A member of a pending check left the game / the party, died or the leader changed: the check is called off.
local function cancelChecksWith(player: Player)
	local region = checkOf(player)
	if region then
		cancelCheck(region, "dungeon.ready.cancelled")
	end
end

local function enter(player: Player, region: string): (boolean, string?)
	local def = Bosses.forRegion(region)
	if not def then
		return false, "error.badRequest"
	end
	if not WorldService.IsBuilt(`dungeon_{region}`) then
		return false, "dungeon.closed"
	end
	if not nearEntrance(player, region) then
		return false, "npc.error.tooFar"
	end
	if not PartyService.IsLeader(player) then
		return false, "dungeon.notLeader"
	end
	local pending = checks[region]
	if pending and pending.leader == player then
		return false, "dungeon.ready.waiting"
	end
	if runs[region] or pending then
		return false, "dungeon.busy"
	end
	if checkOf(player) then
		return false, "dungeon.ready.waiting"
	end
	local reason = blocker(player, def)
	if reason then
		return false, reason
	end
	local entering = gather(player, def, PartyService.Members(player))
	if #entering < 2 then
		-- solo, or only the leader at the gate: in at once (as before S134f)
		start(region, player, entering)
		return true, nil
	end
	local ids = {}
	for _, member in entering do
		table.insert(ids, member.UserId)
	end
	checks[region] = {
		check = ReadyCheck.new(ids, player.UserId, os.clock(), Config.Boss),
		leader = player,
		entering = entering,
		def = def,
		counted = 0,
	}
	publishCheck(region)
	log:info("%s asks %d member(s) at %s", nameOf(player), #entering - 1, region)
	return true, nil
end

local function step()
	local now = os.clock()
	stepChecks(now) -- S134f
	for _, run in runs do
		if run.cleared then
			if (run.releaseAt and now >= run.releaseAt) or #present(run) == 0 then
				finish(run)
			end
			continue
		end
		local boss = run.boss
		if boss then
			if not boss:IsAlive() then
				win(run)
				continue
			end
			boss:Step(now)
			if boss.monster.state == "return" then
				-- A leashed boss walks home at full HP with a cleared damage record (Monster.StartReturn): the fight
				-- summary starts over with it, so healing, shields and intercepts match the damage of the last attempt.
				if run.fightId then
					FightLogService.Reset(run.fightId)
				end
			end
			if now - run.lastState >= STATE_INTERVAL then
				run.lastState = now
				publish(run)
			end
			if #fighters(run) == 0 then
				fail(run, "dungeon.wiped")
				continue
			end
		elseif now - run.startedAt > Bosses.COUNTDOWN + 20 and #present(run) == 0 then
			-- Nobody arrived (left during the countdown).
			finish(run)
			continue
		end
		if now >= run.deadline then
			fail(run, "dungeon.timeout")
			continue
		end
		if run.boss then
			for _, minutes in Bosses.TIME_WARNINGS do
				if not run.warned[minutes] and run.deadline - now <= minutes * 60 then
					run.warned[minutes] = true
					announce(run, "dungeon.timeWarning", { minutes = minutes, boss = `@{run.def.nameKey}` })
				end
			end
		end
	end
end

-- Admin ------------------------------------------------------------------------------------------

-- S58 (ROZWOJ 2.9): a member of a dungeon run from start until finish (also after dying and leaving the cave).
function DungeonService.InRun(player: Player): boolean
	for _, run in runs do
		if table.find(run.members, player) then
			return true
		end
	end
	return false
end

-- S57 (ROZWOJ 2.7, 2.9, 2.10): at the entrance of some boss dungeon (on its cave map, within the entering range of
-- 52 studs) and not a member of a running dungeon. Path refunds, breakpoint changes and (S58) build sets use it.
function DungeonService.NearAnyEntrance(player: Player): boolean
	if DungeonService.InRun(player) then
		return false
	end
	for _, map in Maps.byId do
		local region = map.dungeonRegion
		if region and map.dungeonEntrance and onMap(player, map.id) and nearEntrance(player, region) then
			return true
		end
	end
	return false
end

-- /boss reset: clears the player's daily runs and ends every run.
function DungeonService.ResetAll(player: Player)
	PlayerStateService.Set(player, { "character", "bossRuns" }, {})
	for _, run in runs do
		finish(run)
	end
end

-- /boss spawn <id>: starts the boss's dungeon for the player alone, ignoring level and lockout.
function DungeonService.ForceStart(player: Player, bossId: string): boolean
	local def = Bosses.get(bossId)
	-- S149: a world boss has no dungeon (its region is another boss's map)
	if not def or def.world or not WorldService.IsBuilt(`dungeon_{def.region}`) then
		return false
	end
	local existing = runs[def.region]
	if existing then
		finish(existing)
	end
	start(def.region, player, { player })
	return true
end

-- S134f /readycheck skip: every asked member of the leader's pending check answers "yes" at once.
function DungeonService.ReadySkip(player: Player): boolean
	for region, pending in checks do
		if pending.leader == player then
			local now = os.clock()
			for _, id in ReadyCheck.pending(pending.check) do
				ReadyCheck.answer(pending.check, id, true, now)
			end
			publishCheck(region)
			return true
		end
	end
	return false
end

-- /phase <n>: forces the phase of the boss the player is fighting.
function DungeonService.ForcePhase(player: Player, phase: number): boolean
	for _, run in runs do
		local boss = run.boss
		if boss and table.find(run.members, player) then
			local thresholds = run.def.phases
			local fraction = if phase <= 1 then 1 elseif thresholds[phase - 1] then thresholds[phase - 1] - 0.01 else 0.3
			local monster = boss.monster
			monster.hp = math.max(1, math.floor(monster.stats.maxHp * fraction))
			monster.model:SetAttribute("Hp", monster.hp)
			boss:SetPhase(phase)
			return true
		end
	end
	return false
end

function DungeonService.Init(registry)
	SeasonService = registry.Get("SeasonService")
	PlayerStateService = registry.Get("PlayerStateService")
	PartyService = registry.Get("PartyService")
	TravelService = registry.Get("TravelService")
	WorldService = registry.Get("WorldService")
	MonsterService = registry.Get("MonsterService")
	CombatService = registry.Get("CombatService")
	ResourceService = registry.Get("ResourceService")
	LevelService = registry.Get("LevelService")
	LootService = registry.Get("LootService")
	AnnounceService = registry.Get("AnnounceService")
	StatService = registry.Get("StatService")
	MountService = registry.Get("MountService")
	CosmeticService = registry.Get("CosmeticService")
	FightLogService = registry.Get("FightLogService")
	Registry = registry
end

function DungeonService.Start()
	UseGuards.register("dungeon", DungeonService.InRun, "DungeonService") -- S122 Logic/UseBlocks
	Net.Handle("DungeonInfo", info)
	Net.Handle("EnterDungeon", enter)
	-- S134f: the ready check (answers; a member who leaves the party, dies or quits calls it off)
	Net.Handle("DungeonReady", readyAnswer)
	PartyService.Changed:Connect(function(party: any)
		for _, member in party.members do
			cancelChecksWith(member)
		end
		for region, pending in checks do
			for _, member in pending.entering do
				if not PartyService.SameParty(pending.leader, member) then
					cancelCheck(region, "dungeon.ready.cancelled")
					break
				end
			end
		end
	end)
	ResourceService.Died:Connect(function(player: Player)
		cancelChecksWith(player)
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local ok, err = pcall(function()
			step()
		end)
		if not ok then
			log:error("dungeon step failed: %s", tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		cancelChecksWith(player) -- S134f
		for _, run in runs do
			local index = table.find(run.members, player)
			if index and run.leader == player and #run.members > 1 then
				run.leader = run.members[if index == 1 then 2 else 1]
			end
		end
	end)
end

return DungeonService
