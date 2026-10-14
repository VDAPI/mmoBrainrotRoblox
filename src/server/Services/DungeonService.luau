--!strict
-- Boss dungeons (DESIGN §16). One group at a time per dungeon on a server. The leader (or a solo player)
-- enters at the gate in the cave; party members within 20 studs come along if they meet the level
-- (boss − 5) and have kills left today (S30: Config.Boss.dailyRuns per boss; others are told why they stay).
-- After a 5 s countdown the boss appears (Entities/Boss). The run fails after 15 minutes or when nobody is left
-- fighting: everyone is sent out and the boss resets. On a kill: EXP and gold shared; every winner gets one item
-- in an own bag nobody else sees (FIX 2026-10-09, Loot.rollBossItem: Mythic 1 %, Legendary 6 %, +1 % each per kill
-- of this boss today, else Unique / Heroic) with materials and a chance of a legendary blessing; one daily run used
-- for everyone present, a server announcement; the dungeon is released 60 s later or when everybody has left
-- through the exit portal.
-- S60: Fortune of the winners (Logic/Luck.boss: Legendary multiplier, Unique -> Heroic, a second item), the class
-- variety bonus on the boss EXP and a fight summary (damage share, healing, shields) on every winner's reward card.
-- Fighters see the state branch `boss` = { id, nameKey, hp, maxHp, phase, endsAt, enraged, shielded }.

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
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)

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
		"StatusEffectService",
		"MountService", -- S97: the boss mount roll (MountService never depends on this service)
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
	healing: { [Player]: number }, -- S60: HP restored by each member while the boss was up
	shielding: { [Player]: number }, -- S60: damage soaked by each member's shields while the boss was up
	intercepted: { [Player]: number }, -- S61: blows each member took over from allies (before their own reductions)
}

-- One row of the fight summary (short keys: it travels in CombatFx); i = damage taken over from allies (S61).
type SummaryRow = { n: string, c: string?, d: number, h: number, s: number, i: number }

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
local StatusEffectService: any
local StatService: any
local MountService: any
local Registry: any
local PathService: any

-- Lazy: PathService depends on this service (NearAnyEntrance), so a Deps entry here would be a cycle. Never call
-- during Init.
local function pathService(): any
	PathService = PathService or Registry.Get("PathService")
	return PathService
end

local rng = Rng.new()
local runs: { [string]: Run } = {}

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

-- Fight summary (S60): every member still in the game, damage share of the boss (0..1), healing and shields; sorted
-- by damage, then healing.
local function summaryOf(run: Run, damageBy: { [Player]: number }): { SummaryRow }
	local total = 0
	for _, amount in damageBy do
		total += amount
	end
	local rows: { SummaryRow } = {}
	for _, member in run.members do
		if member.Parent ~= nil then
			local char = character(member)
			local share = if total > 0 then (damageBy[member] or 0) / total else 0
			table.insert(rows, {
				n = nameOf(member),
				c = if char then char.class :: string else nil,
				d = math.floor(share * 1000 + 0.5) / 1000,
				h = math.floor(run.healing[member] or 0),
				s = math.floor(run.shielding[member] or 0),
				i = math.floor(run.intercepted[member] or 0),
			})
		end
	end
	table.sort(rows, function(a, b)
		if a.d ~= b.d then
			return a.d > b.d
		end
		return a.h > b.h
	end)
	return rows
end

local function reward(run: Run, position: Vector3, damageBy: { [Player]: number })
	local winners = present(run)
	local n = #winners
	if n == 0 then
		return
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
	local summary = summaryOf(run, damageBy)
	local baseExp = PartyLoot.splitExp(Exp.monsterExp(def.level, "boss") * PartyBonus.expMul(classes), n)
	local shares = PartyLoot.splitGold(MonsterStats.gold(def.level, "boss", rng:next()), n, rng)
	-- FIX 2026-10-09: every winner gets exactly one item (and the materials) in an own bag only they see and can
	-- pick up; the Legendary / Mythic chances grow with the character's kills of this boss today.
	local blessingChance = Bosses.LEGENDARY_BLESSING_CHANCE / n
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
			local exp = math.floor(baseExp * Exp.levelDiffMultiplier(char.level, def.level) + 0.5)
			LevelService.GiveExp(player, exp, "boss")
			QuestEvents.fire(player, "boss", { bossId = def.id })
			local gold = math.floor(shares[i] * (1 + StatService.GetValue(player, "goldBonus") / 100) + 0.5)
			local balance = PlayerStateService.Update(player, { "character", "gold" }, function(current: number)
				return current + gold
			end)
			Analytics.gold(player, gold, balance, "boss")
			Analytics.progression(player, "Bosses", def.level, def.id)
			local gotLeg, gotMyth, upgraded, gotExtra = false, false, false, false
			if bossTable then
				local items = {}
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
				if gotLeg or gotMyth then
					Analytics.custom(player, if gotMyth then "BossMythic" else "BossLegendary", def.level)
				end
			end
			-- S97: the personal mount / mount skin roll, after every item roll above (their order is unchanged).
			local mountDrop = MountService.RollBossDrop(player, def.id, rng)
			if mountDrop.mount then
				Analytics.custom(player, "BossMount", def.level)
			end
			-- The chances of the next kill today.
			local chances = Loot.bossChances(def.id, killsToday + 1, bossLuck)
			Net.Fire(player, "CombatFx", {
				{
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
					sum = summary,
					mount = mountDrop.mount,
					mountSkin = mountDrop.skin,
				},
			})
		end
	end
	AnnounceService.Server("announce.boss", { name = run.leaderName, boss = `@{def.nameKey}` })
end

local function win(run: Run)
	local boss = run.boss
	local position = if boss then boss.monster:Position() else Vector3.zero
	run.cleared = true
	run.releaseAt = os.clock() + Bosses.RELEASE_AFTER
	if boss then
		for _, summon in boss:Summons() do
			if summon:IsAlive() then
				MonsterService.Despawn(summon)
			end
		end
	end
	-- The damage map before the boss is dropped (fight summary, S60).
	local damageBy: { [Player]: number } = if boss then table.clone(boss.monster.damageBy) else {}
	run.boss = nil
	announce(run, "dungeon.victory", { boss = `@{run.def.nameKey}` })
	for _, member in present(run) do
		clearState(member)
	end
	reward(run, position, damageBy)
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
	}
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
		telegraph = CombatService.MonsterTelegraph,
		resolve = CombatService.MonsterResolve,
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
		healing = {},
		shielding = {},
		intercepted = {},
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
		run.boss = Boss.new(def, #members, arenaCentre(mapId), services(run))
		run.startedAt = os.clock()
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
			busy = run ~= nil,
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
	if runs[region] then
		return false, "dungeon.busy"
	end
	local reason = blocker(player, def)
	if reason then
		return false, reason
	end
	local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	local entering = { player }
	for _, member in PartyService.Members(player) do
		if member ~= player then
			local why = blocker(member, def)
			local memberRoot = member.Character and member.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not why and (not memberRoot or (memberRoot.Position - root.Position).Magnitude > Bosses.ENTRY_RANGE) then
				why = "dungeon.reason.far"
			end
			if why then
				Net.Fire(member, "Toast", "dungeon.leftOut", { reason = `@{why}` }, "warning")
			else
				table.insert(entering, member)
			end
		end
	end
	start(region, player, entering)
	return true, nil
end

local function step()
	local now = os.clock()
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
				table.clear(run.healing)
				table.clear(run.shielding)
				table.clear(run.intercepted)
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
	if not def or not WorldService.IsBuilt(`dungeon_{def.region}`) then
		return false
	end
	local existing = runs[def.region]
	if existing then
		finish(existing)
	end
	start(def.region, player, { player })
	return true
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
	StatusEffectService = registry.Get("StatusEffectService")
	Registry = registry
end

-- The run in which both players fight a boss that is up and not walking home after a leash (S60: healing and
-- shields of the fight summary).
local function fightOf(target: Player, source: Player): Run?
	for _, run in runs do
		local boss = run.boss
		if
			boss ~= nil
			and boss.monster.state ~= "return"
			and not run.cleared
			and table.find(run.members, target)
			and table.find(run.members, source)
		then
			return run
		end
	end
	return nil
end

function DungeonService.Start()
	Net.Handle("DungeonInfo", info)
	Net.Handle("EnterDungeon", enter)
	ResourceService.Healed:Connect(function(target: Player, amount: number, source: Player?, kind: string)
		if not source then
			return
		end
		local run = fightOf(target, source)
		if run then
			local book = if kind == "shield" then run.shielding else run.healing
			book[source] = (book[source] or 0) + amount
		end
	end)
	-- S61: the summary counts the part a guard took before their own reductions (ROZWOJ 10.6).
	StatusEffectService.Intercepted:Connect(function(guard: Player, target: Player, moved: number)
		local run = fightOf(target, guard)
		if run then
			run.intercepted[guard] = (run.intercepted[guard] or 0) + moved
		end
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
		for _, run in runs do
			local index = table.find(run.members, player)
			if index and run.leader == player and #run.members > 1 then
				run.leader = run.members[if index == 1 then 2 else 1]
			end
		end
	end)
end

return DungeonService
