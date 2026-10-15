--!strict
-- Blood Moon (S129, DESIGN-17 §7): a PvP event on the UTC clock. Every server computes the same occurrences from
-- Data/ScheduledEvents (Logic/Schedule over Util/Clock.now, so /time moves it too) with no cross-server messages:
-- Tuesday and Thursday 19:00 UTC for 30 min, announced 10 min and 1 min before and at the start.
-- During it (world servers only):
--   * the yellow zones of the four open regions are red (ZoneService.SetBloodMoon), the client reddens the sky;
--   * a normal group respawning in an open region may come back as one Elite (MonsterService.SetGroupHook);
--   * no S101 world event runs (WorldEventService blocks by the schedule; a forced one through AddBlocker);
--   * points (Logic/BloodMoon): a defeated player 10 (0 for a victim 8+ levels lower or after 2 kills of the same one),
--     an Elite 1, an Elite II 5, in a region and its caves; dying costs nothing. Saved in character.bloodMoon;
--   * the Elixir of Wholeness and the Cloak of Luring do not work (UseGuards "bloodMoon"), and a death on an event map
--     has no paid / VIP skip and no pass shortcut (DeathService reads IsActive lazily).
-- Ranking per region: BloodMoon/Board (MemoryStore SortedMap through Leaderboard/Stores, in memory = this server only),
-- written every Config.BloodMoon.writeEvery s per character and on leave / the end, the top 10 read every readEvery s
-- and published to every player as the runtime branch `bloodMoonBoard`. Rewards after settleDelay s by mail, once per
-- character and occurrence (Mail `once` key + character.bloodMoon.paid); a character away at the end is settled on its
-- next entry on any server. The region winner is announced on every server (AnnounceService.Global).
-- Arena / tournament servers (ServerMode) only show the state: attributes and announcements.
-- ReplicatedStorage attributes: BloodMoon (occurrence id or ""), BloodMoonEndsAt, BloodMoonNext (next start or 0).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Blessings = require(Shared.Data.Blessings)
local BloodMoon = require(Shared.Logic.BloodMoon)
local Board = require(script.Parent.Parent.BloodMoon.Board)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local Schedule = require(Shared.Logic.Schedule)
local ScheduledEvents = require(Shared.Data.ScheduledEvents)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("BloodMoonService")

local BloodMoonService = {
	Name = "BloodMoonService",
	-- nothing here depends on this service (AdminService lists it; DeathService takes it lazily)
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"DataService",
		"ZoneService",
		"MonsterService",
		"CombatService",
		"PvpService",
		"MailService",
		"AnnounceService",
		"WorldEventService",
		"LeaderboardService",
	},
}

type State = BloodMoon.State
type Occurrence = Schedule.Occurrence
type BoardCache = { id: string, at: number, global: boolean?, regions: { [string]: { Board.Row } } }
type Ending = { occ: Occurrence, at: number }

local CFG = Config.BloodMoon
local RULES = ScheduledEvents.bloodMoon
local DEF = ScheduledEvents.get("bloodmoon") :: ScheduledEvents.EventDef
local WINNER_GAP = 11 -- s between two cross-server winner announcements (AnnounceService.Global: 10 s per server)

local Registry: any
local PlayerStateService: any
local CharacterService: any
local DataService: any
local ZoneService: any
local MonsterService: any
local CombatService: any
local PvpService: any
local MailService: any
local AnnounceService: any
local WorldEventService: any
local LeaderboardService: any
local GuildService: any

local rng = Rng.new()
local occ: Occurrence? = nil -- the running occurrence (scheduled or forced)
local forced: Occurrence? = nil -- /bloodmoon start on this server
local stoppedId: string? = nil -- a scheduled occurrence ended early by /bloodmoon stop (this server only)
local lastStep = 0
local ending: Ending? = nil -- settle this occurrence at `at`
local lastEnded: Occurrence? = nil
local cache: BoardCache? = nil -- the last read of the region boards (live, then final)
local resultsUntil = 0 -- the final results stay published until then
local lastRead = 0
local reading = false
local settled: { [string]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local lastWrite: { [Player]: number } = {}
local writing: { [Player]: boolean } = {}
local keys: { [Player]: string } = {} -- the entry key of the active character
local lastSent: { [Player]: string } = {}
local settling: { [string]: boolean } = {} -- "<charId>|<id>" being settled
local winnerQueue = 0 -- winner announcements waiting on this server

local function world(): boolean
	return ServerMode.isWorld()
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function stateOf(char: Types.CharacterData): State
	local state = (char :: any).bloodMoon
	if type(state) ~= "table" or type(state.id) ~= "string" then
		return BloodMoon.newState("")
	end
	return state :: State
end

local function keyOf(player: Player): string?
	local key = keys[player]
	if key == nil then
		key = LeaderboardService.KeyOf(player)
		keys[player] = key
	end
	return key
end

local function toast(player: Player, key: string, args: { [string]: any }?, kind: string?)
	Net.Fire(player, "Toast", key, args, kind or "info")
end

local function setAttribute(name: string, value: any)
	if ReplicatedStorage:GetAttribute(name) ~= value then
		ReplicatedStorage:SetAttribute(name, value)
	end
end

-- Staff characters (Config.AdminUserIds, /lb hide; Logic/Leaderboard.excluded) collect points they can see but are not
-- written to the boards and get no rewards, except in a forced occurrence (an admin testing the whole flow).
local function excluded(player: Player, char: Types.CharacterData, id: string): boolean
	if BloodMoon.isForcedId(id) then
		return false
	end
	return Leaderboard.excluded(player.UserId, char, Config.AdminUserIds, Config.Leaderboard)
end

-- S60 pattern: GuildService depends on LeaderboardService (S125), never needed at Init.
local function guildTag(player: Player): string?
	if GuildService == nil and Registry then
		local ok, service = pcall(Registry.Get, "GuildService")
		GuildService = if ok and service then service else false
	end
	if not GuildService then
		return nil
	end
	local ok, data = pcall(GuildService.Data, player)
	return if ok and type(data) == "table" and type(data.tag) == "string" and data.tag ~= "" then data.tag else nil
end

-- Public state ----------------------------------------------------------------------------------------------------

function BloodMoonService.IsActive(): boolean
	local o = occ
	return o ~= nil and Clock.now() < o.endsAt
end

function BloodMoonService.Current(): Occurrence?
	return occ
end

-- The event runs and `mapId` counts for points (a region or its cave).
function BloodMoonService.ActiveOn(mapId: string): boolean
	return BloodMoonService.IsActive() and BloodMoon.regionOf(mapId) ~= nil
end

-- Board publication -------------------------------------------------------------------------------------------------

local function payloadFor(player: Player, now: number): { [string]: any }?
	local c = cache
	local o = occ
	local phase: string
	if o and c and c.id == o.id then
		phase = "active"
	elseif o then
		return { id = o.id, phase = "active", updatedAt = 0, regions = {} }
	elseif c and now < resultsUntil then
		phase = "ended"
	else
		return nil
	end
	local data = c :: BoardCache
	local key = keys[player]
	local regions: { [string]: any } = {}
	for region, rows in data.regions do
		local top = {}
		local me: number? = nil
		for _, row in rows do
			table.insert(top, {
				rank = row.rank,
				name = row.name,
				class = row.class,
				level = row.level,
				guild = row.guild,
				points = row.points,
			})
			if key ~= nil and row.key == key then
				me = row.rank
			end
		end
		regions[region] = { top = top, me = me }
	end
	return { id = data.id, phase = phase, global = data.global, updatedAt = data.at, regions = regions }
end

local function publish(player: Player, now: number)
	if not PlayerStateService.HasState(player) or PlayerStateService.GetPhase(player) ~= "playing" then
		return
	end
	local payload = payloadFor(player, now)
	local text = if payload then HttpService:JSONEncode(payload) else ""
	if lastSent[player] == text then
		return
	end
	lastSent[player] = text
	PlayerStateService.Set(player, { "bloodMoonBoard" }, payload)
end

local function publishAll()
	local now = Clock.now()
	for _, player in Players:GetPlayers() do
		publish(player, now)
	end
end

-- Reads the top of every region board (yields; one read at a time). A region whose read failed keeps its rows from
-- `prev` (the same occurrence) and is listed in the second result.
local function readBoards(id: string, n: number, prev: BoardCache?): (BoardCache, { [string]: boolean })
	local result: BoardCache = { id = id, at = Clock.now(), global = true, regions = {} }
	local failed: { [string]: boolean } = {}
	for _, region in RULES.regions do
		local rows, global, ok = Board.top(id, region, n)
		if ok then
			result.regions[region] = rows
		else
			failed[region] = true
			result.regions[region] = if prev and prev.id == id then prev.regions[region] or {} else {}
		end
		if not global then
			result.global = false
		end
	end
	return result, failed
end

local function refreshBoards()
	local o = occ
	if reading or not o or not world() then
		return
	end
	reading = true
	lastRead = Clock.now()
	task.spawn(function()
		local ok, result = pcall(function(): BoardCache
			local board = readBoards(o.id, CFG.boardTop, cache)
			return board
		end)
		reading = false
		if not ok then
			log:warn("board read failed: %s", tostring(result))
			return
		end
		if occ and occ.id == o.id then
			cache = result
			publishAll()
		end
	end)
end

-- Scores ------------------------------------------------------------------------------------------------------------

-- Writes the character's points of occurrence `o` to its region boards now (yields). Returns whether every region
-- write went through. `key` and `tag` are taken before the yield (on leave the player's key and guild are gone by then).
local function writeState(
	player: Player,
	key: string,
	tag: string?,
	char: Types.CharacterData,
	state: State,
	startsAt: number
): boolean
	if excluded(player, char, state.id) then
		return true
	end
	local meta: Leaderboard.Meta = { n = char.name, c = char.class, l = char.level, g = tag, t = os.time() }
	local all = true
	for region, points in state.regions do
		if
			points > 0 and not Board.write(state.id, region, key, BloodMoon.sortKey(points, state.at, startsAt), meta)
		then
			all = false
		end
	end
	return all
end

-- Sends the character's score to the boards: a periodic write (dirty, every writeEvery s, one at a time) or, with
-- `force` (leave, the end), the last one at once, tried writeTries times writeRetry s apart (Board.write only raises an
-- entry, so it may overlap a periodic write in flight). A failed periodic write is tried again after writeRetry s.
-- `charData` = the leaving character (CharacterLeaving), else the active one.
local function flushPlayer(player: Player, force: boolean?, charData: Types.CharacterData?)
	local o = occ or (if ending then ending.occ else nil)
	local char = charData or character(player)
	if not o or not char or not world() then
		return
	end
	if writing[player] and not force then
		return
	end
	local state = stateOf(char)
	if state.id ~= o.id or state.points <= 0 then
		return
	end
	local now = Clock.now()
	if not force and (not dirty[player] or now - (lastWrite[player] or 0) < CFG.writeEvery) then
		return
	end
	dirty[player] = nil
	lastWrite[player] = now
	local key = keyOf(player)
	if key == nil then
		return
	end
	local tag = guildTag(player)
	local snapshot = table.clone(state)
	local tries = if force then math.max(1, CFG.writeTries) else 1
	if not force then
		writing[player] = true
	end
	task.spawn(function()
		local done = false
		for attempt = 1, tries do
			local ok, result = pcall(writeState, player, key :: string, tag, char, snapshot, o.startsAt)
			if ok and result then
				done = true
				break
			end
			log:warn("score write %d/%d failed for %s: %s", attempt, tries, player.Name, tostring(result))
			if attempt < tries then
				task.wait(CFG.writeRetry)
			end
		end
		if not force then
			writing[player] = nil
		end
		if not done and player.Parent == Players and character(player) == char then
			-- the periodic flush tries again writeRetry s from now
			dirty[player] = true
			lastWrite[player] = Clock.now() - CFG.writeEvery + CFG.writeRetry
		end
	end)
end

-- Rewards -----------------------------------------------------------------------------------------------------------

local function announceWinner(name: string, region: string, points: number)
	local map = Maps.get(region)
	local args = { player = name, region = if map then "@" .. map.nameKey else region, points = points }
	local delay = winnerQueue * WINNER_GAP
	winnerQueue += 1
	task.delay(delay, function()
		winnerQueue = math.max(0, winnerQueue - 1)
		AnnounceService.Global("bloodmoon.winner", "bloodmoon.winnerGlobal", args)
	end)
end

-- Reads the final ranks (key -> rank) of the regions `state` has points in (yields); nil when nothing was read.
local function readRanks(id: string, regions: { [string]: number }): { [string]: { [string]: number } }?
	local out: { [string]: { [string]: number } } = {}
	local any = false
	for region, points in regions do
		if points > 0 then
			local ok, rows, read = pcall(function(): ({ Board.Row }, boolean)
				local list, _, success = Board.top(id, region, CFG.rankTop)
				return list, success
			end)
			if ok and read then
				local map: { [string]: number } = {}
				for _, row in rows do
					map[row.key] = row.rank
				end
				out[region] = map
				any = true
			end
		end
	end
	return if any then out else nil
end

-- Marks `id` paid on the active character, only while it still holds that occurrence.
local function markPaid(player: Player, charId: string, id: string)
	local char = character(player)
	if char and char.id == charId and stateOf(char).id == id then
		PlayerStateService.Set(player, { "character", "bloodMoon", "paid" }, true)
		DataService.Save(player)
	end
end

-- Settles one character's occurrence (`state` = its snapshot). Yields (board reads, mail). Returns true when it is
-- settled (rewarded, nothing to give, or the parcel was already sent).
local function settleCharacter(player: Player, state: State, ranks: { [string]: { [string]: number } }?): boolean
	local char = character(player)
	if not char or state.id == "" or state.paid or not world() then
		return false
	end
	local busyKey = `{char.id}|{state.id}`
	if settling[busyKey] then
		return false
	end
	settling[busyKey] = true
	local ok, result = pcall(function(): boolean
		local key = keyOf(player)
		local left = excluded(player, char, state.id)
		local rankMap = ranks
		if rankMap == nil and key ~= nil and not left then
			rankMap = readRanks(state.id, state.regions)
		end
		local best = if left or key == nil then nil else BloodMoon.bestRank(state, key :: string, rankMap)
		local tier = BloodMoon.tierOf(if left then 0 else state.points, best)
		local rewards = BloodMoon.rewardsOf(tier)
		Analytics.custom(player, "BloodMoonTier", BloodMoon.tierIndex(tier))
		if not tier.participation then
			markPaid(player, char.id, state.id)
			if not left and state.points > 0 then
				toast(player, "bloodmoon.noReward", { min = RULES.reward.minPoints }, "info")
			end
			return true
		end
		local startsAt, endsAt = BloodMoon.spanOf(state.id)
		local endTs = endsAt or Clock.now()
		local line = rng:pick(Blessings.lines)
		local outgoing = {
			from = "system",
			subjectKey = "mail.subject.bloodMoon",
			args = { id = { key = "leaderboard.date", args = Leaderboard.dateParts(startsAt or endTs) } },
			items = {
				ItemRoll.makeStack(BloodMoon.blessingItem(line), 1, HttpService:GenerateGUID(false)),
			},
			charId = char.id,
			shards = if rewards.shards > 0 then rewards.shards else nil,
			timedTitle = if rewards.titleId
				then { id = rewards.titleId, untilTs = endTs + (rewards.titleDays or 0) * 86400 }
				else nil,
			tokens = rewards.tokens,
			cosmetics = if rewards.frameId then { rewards.frameId } else nil,
			once = `bloodmoon_{state.id}_{char.id}`,
		}
		local sent, err = MailService.Send(player.UserId, outgoing)
		if not sent then
			log:warn("reward mail for %s (%s) failed: %s", player.Name, state.id, tostring(err))
			if player.Parent == Players then
				toast(player, "bloodmoon.mailFull", nil, "warning")
			end
			return false
		end
		markPaid(player, char.id, state.id)
		if tier.winner and key ~= nil and rankMap then
			for region, points in state.regions do
				local regionRanks = rankMap[region]
				if points > 0 and regionRanks and regionRanks[key :: string] == 1 then
					announceWinner(char.name, region, points)
				end
			end
		end
		log:info("%s settled %s: %d points, rank %s", player.Name, state.id, state.points, tostring(best))
		return true
	end)
	settling[busyKey] = nil
	if not ok then
		log:warn("settling %s for %s failed: %s", state.id, player.Name, tostring(result))
		return false
	end
	return result == true
end

-- Settles occurrence `id` for every character on this server that took part (yields). The final boards are read up to
-- `tries` times settleRetry s apart; a character with points in a region whose board still could not be read is left
-- for its next entry (settled then with whatever the boards give). Returns how many settled.
local function settle(id: string, tries: number?): number
	settled[id] = true
	local final, failed = readBoards(id, CFG.rankTop, nil)
	local attempts = math.max(1, tries or 1)
	for _ = 2, attempts do
		if next(failed) == nil then
			break
		end
		log:warn("final boards of %s not read, again in %d s", id, CFG.settleRetry)
		task.wait(CFG.settleRetry)
		final, failed = readBoards(id, CFG.rankTop, final)
	end
	local ranks: { [string]: { [string]: number } } = {}
	for region, rows in final.regions do
		local map: { [string]: number } = {}
		for _, row in rows do
			map[row.key] = row.rank
		end
		ranks[region] = map
		-- the window shows the final top 10
		local top = {}
		for i = 1, math.min(#rows, CFG.boardTop) do
			table.insert(top, rows[i])
		end
		final.regions[region] = top
	end
	if occ == nil then
		cache = final
		local _, endsAt = BloodMoon.spanOf(id)
		resultsUntil = (if lastEnded and lastEnded.id == id then lastEnded.endsAt else endsAt or Clock.now())
			+ CFG.resultsFor
		publishAll()
	end
	local n = 0
	for _, player in Players:GetPlayers() do
		local char = character(player)
		local state = if char then stateOf(char) else nil
		if state and state.id == id and not state.paid then
			local blind = false
			for region, points in state.regions do
				if points > 0 and failed[region] then
					blind = true
				end
			end
			if not blind and settleCharacter(player, table.clone(state), ranks) then
				n += 1
			end
		end
	end
	return n
end

-- Points --------------------------------------------------------------------------------------------------------------

-- The character's state for the running occurrence (a new one replaces an older occurrence, which is settled first
-- when it was never paid; the `once` key keeps that safe). nil outside the event.
local function ensure(player: Player): State?
	local o = occ
	local char = character(player)
	if not o or not char then
		return nil
	end
	local state = stateOf(char)
	if state.id == o.id then
		return state
	end
	if state.id ~= "" and not state.paid then
		local old = table.clone(state)
		task.spawn(settleCharacter, player, old, nil)
	end
	local fresh = BloodMoon.newState(o.id)
	PlayerStateService.Set(player, { "character", "bloodMoon" }, fresh)
	dirty[player] = nil
	return fresh
end

local function give(player: Player, region: string, points: number): number?
	local state = ensure(player)
	if not state or points <= 0 then
		return nil
	end
	local new = BloodMoon.addPoints(state, region, points, Clock.now())
	PlayerStateService.Set(player, { "character", "bloodMoon" }, new)
	dirty[player] = true
	toast(player, "bloodmoon.points", { n = points, total = new.points }, "success")
	return new.points
end

local function onPlayerKilled(killer: Player, victim: Player, mapId: string?)
	if not BloodMoonService.IsActive() or not world() or type(mapId) ~= "string" then
		return
	end
	local region = BloodMoon.regionOf(mapId)
	local killerChar, victimChar = character(killer), character(victim)
	local victimKey = LeaderboardService.KeyOf(victim)
	if not region or not killerChar or not victimChar or victimKey == nil then
		return
	end
	local state = ensure(killer)
	if not state then
		return
	end
	local ctx: BloodMoon.KillCtx = {
		killerLevel = killerChar.level,
		victimLevel = victimChar.level,
		prior = state.kills[victimKey] or 0,
	}
	local points = BloodMoon.playerPoints(ctx)
	-- the victim counts also when it gave nothing (the same-victim limit stays honest)
	local counted = BloodMoon.countKill(state, victimKey)
	PlayerStateService.Set(killer, { "character", "bloodMoon" }, counted)
	if points > 0 then
		give(killer, region, points)
	else
		toast(killer, BloodMoon.noPointsKey(ctx) or "bloodmoon.noPoints.repeat", nil, "info")
	end
end

local function onMonsterKilled(info: any, credit: { Player }?)
	if not BloodMoonService.IsActive() or not world() or type(info) ~= "table" or info.boss == true then
		return
	end
	local points = BloodMoon.monsterPoints(info.variant)
	local region = if type(info.mapId) == "string" then BloodMoon.regionOf(info.mapId) else nil
	if points <= 0 or not region then
		return
	end
	-- the same credit as EXP and quests: the best damage dealer and their party in range
	for _, player in (credit or {}) :: { Player } do
		give(player, region, points)
	end
end

-- Start and end -----------------------------------------------------------------------------------------------------

local function groupHook(mapId: string, _data: any): string?
	return if BloodMoon.isEventMap(mapId) and BloodMoon.rollElite(rng) then "elite" else nil
end

local function welcome(player: Player)
	local o = occ
	if not o then
		return
	end
	Net.Fire(player, "SystemMessage", "bloodmoon.inProgress", { time = Time.format(o.endsAt - Clock.now()) })
end

local function begin(o: Occurrence, announce: boolean)
	occ = o
	cache = nil
	resultsUntil = 0
	lastRead = 0
	if world() then
		ZoneService.SetBloodMoon(true)
		MonsterService.SetGroupHook(groupHook)
		if WorldEventService.Current() then
			WorldEventService.Stop()
		end
	end
	setAttribute("BloodMoonEndsAt", o.endsAt)
	setAttribute("BloodMoon", o.id)
	if announce then
		AnnounceService.Server("bloodmoon.start", { min = math.floor((o.endsAt - o.startsAt) / 60 + 0.5) })
	end
	for _, player in Players:GetPlayers() do
		if world() and character(player) then
			ensure(player)
			if not announce then
				welcome(player)
			end
		end
	end
	log:info("Blood Moon %s started (until %d)", o.id, o.endsAt)
	publishAll()
end

local function finish(now: number)
	local o = occ
	if not o then
		return
	end
	occ = nil
	lastEnded = o
	if forced and forced.id == o.id then
		forced = nil
	end
	if world() then
		ZoneService.SetBloodMoon(false)
		MonsterService.SetGroupHook(nil)
	end
	setAttribute("BloodMoon", "")
	AnnounceService.Server("bloodmoon.end", {})
	if world() then
		-- the last live boards stay published as "ended" until settle swaps in the final ranks
		resultsUntil = o.endsAt + CFG.resultsFor
		ending = { occ = o, at = now + CFG.settleDelay }
		for _, player in Players:GetPlayers() do
			flushPlayer(player, true)
			if character(player) then
				DataService.Save(player)
			end
		end
	end
	log:info("Blood Moon %s ended", o.id)
	publishAll()
end

local function step()
	local now = Clock.now()
	local sched = Schedule.current(DEF, now)
	if sched and stoppedId == sched.id then
		sched = nil
	end
	local f = forced
	if f and now >= f.endsAt then
		f = nil
	end
	local want = f or sched
	local due = Schedule.crossed(DEF, Schedule.next(DEF, lastStep), lastStep, now)
	lastStep = now
	local startAnnounced = false
	for _, before in due do
		if before == 60 then
			AnnounceService.Server("bloodmoon.warn1", {})
		elseif before > 0 then
			AnnounceService.Server("bloodmoon.warn", { min = before // 60 })
		else
			startAnnounced = true
		end
	end
	local o = occ
	if o and (want == nil or want.id ~= o.id) then
		finish(now)
	end
	if want and occ == nil then
		begin(want, startAnnounced or want == forced)
	end
	local running = occ
	if running and world() then
		for _, player in Players:GetPlayers() do
			if dirty[player] then
				flushPlayer(player, false)
			end
		end
		if now - lastRead >= CFG.readEvery then
			refreshBoards()
		end
	end
	local e = ending
	if e and now >= e.at then
		ending = nil
		task.spawn(function()
			local ok, err = pcall(settle, e.occ.id, CFG.settleTries)
			if not ok then
				log:warn("settle %s failed: %s", e.occ.id, tostring(err))
			end
		end)
	end
	if cache and not running and resultsUntil > 0 and now >= resultsUntil then
		cache = nil
		resultsUntil = 0
		publishAll()
	end
	local nextOcc = Schedule.next(DEF, now)
	setAttribute("BloodMoonNext", if nextOcc then nextOcc.startsAt else 0)
end

-- Admin (/bloodmoon) ----------------------------------------------------------------------------------------------

-- Forces an occurrence on this server from now for `minutes` (own boards: id "t<date><minute>"). (ok, error or id)
function BloodMoonService.Force(minutes: number): (boolean, string?)
	if occ then
		return false, "admin.bloodmoon.busy"
	end
	local now = Clock.now()
	local id = BloodMoon.forcedId(now)
	-- stoppedId stays: a stopped scheduled occurrence must not resume (and reset points) after the forced one
	forced = { key = DEF.key, id = id, startsAt = now, endsAt = now + math.max(1, math.floor(minutes)) * 60 }
	step()
	return true, id
end

-- Ends the running occurrence on this server (a scheduled one stays off here until its end); settled as usual.
function BloodMoonService.Stop(): boolean
	local o = occ
	if not o then
		return false
	end
	if not (forced and forced.id == o.id) then
		stoppedId = o.id
	end
	finish(Clock.now())
	return true
end

-- Settles `id` (default: the last ended occurrence) now, without waiting settleDelay. Yields. (id?, characters)
function BloodMoonService.Settle(id: string?): (string?, number)
	local target = id or (if ending then ending.occ.id else nil) or (if lastEnded then lastEnded.id else nil)
	if target == nil then
		return nil, 0
	end
	if ending and ending.occ.id == target then
		ending = nil
	end
	return target, settle(target)
end

-- Admin: `points` more for the admin in the region of their map (only while the event runs). The region or nil.
function BloodMoonService.AdminPoints(player: Player, points: number): string?
	if not BloodMoonService.IsActive() or not world() then
		return nil
	end
	local zone = ZoneService.GetZone(player)
	local region = if zone then BloodMoon.regionOf(zone.map) else nil
	if not region or give(player, region, points) == nil then
		return nil
	end
	return region
end

export type Info = {
	phase: string, -- "none" | "warn" | "active" | "settling"
	id: string?,
	timeLeft: number,
	global: boolean?,
	characters: number,
	top: { { name: string, points: number, region: string } },
	nextId: string?,
	nextIn: number?,
}

function BloodMoonService.Info(): Info
	local now = Clock.now()
	local nextOcc = Schedule.next(DEF, now)
	local rows = {}
	for _, player in Players:GetPlayers() do
		local char = character(player)
		local state = if char then stateOf(char) else nil
		local current = occ or (if ending then ending.occ else nil)
		if char and state and current and state.id == current.id and state.points > 0 then
			local bestRegion, bestPoints = "-", -1
			for region, points in state.regions do
				if points > bestPoints then
					bestRegion, bestPoints = region, points
				end
			end
			table.insert(rows, { name = char.name, points = state.points, region = bestRegion })
		end
	end
	table.sort(rows, function(a, b): boolean
		return a.points > b.points
	end)
	local top = {}
	for i = 1, math.min(5, #rows) do
		table.insert(top, rows[i])
	end
	local o = occ
	local phase, id, left = "none", nil, 0
	if o then
		phase, id, left = "active", o.id, o.endsAt - now
	elseif ending then
		phase, id, left = "settling", ending.occ.id, ending.at - now
	elseif nextOcc and nextOcc.startsAt - now <= BloodMoon.SOON then
		phase, id, left = "warn", nextOcc.id, nextOcc.startsAt - now
	end
	return {
		phase = phase,
		id = id,
		timeLeft = math.max(0, left),
		global = if cache then cache.global else nil,
		characters = #rows,
		top = top,
		nextId = if nextOcc then nextOcc.id else nil,
		nextIn = if nextOcc then nextOcc.startsAt - now else nil,
	}
end

-- Lifecycle ---------------------------------------------------------------------------------------------------------

function BloodMoonService.Init(registry)
	Registry = registry
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	DataService = registry.Get("DataService")
	ZoneService = registry.Get("ZoneService")
	MonsterService = registry.Get("MonsterService")
	CombatService = registry.Get("CombatService")
	PvpService = registry.Get("PvpService")
	MailService = registry.Get("MailService")
	AnnounceService = registry.Get("AnnounceService")
	WorldEventService = registry.Get("WorldEventService")
	LeaderboardService = registry.Get("LeaderboardService")
end

function BloodMoonService.Start()
	-- S122 Logic/UseBlocks: the Elixir of Wholeness and the Cloak of Luring are off during the event
	UseGuards.register("bloodMoon", function(): boolean
		return BloodMoon.consumableBlocked(BloodMoonService.IsActive())
	end, "BloodMoonService")
	-- S101 world events: a forced occurrence blocks them like a scheduled one (Logic/Schedule.blocking)
	WorldEventService.AddBlocker(function(from: number, to: number): boolean
		local f = forced
		return f ~= nil and from < f.endsAt and to > f.startsAt
	end, DEF.nameKey)

	PvpService.PlayerKilled:Connect(onPlayerKilled)
	CombatService.MonsterKilled:Connect(onMonsterKilled)

	CharacterService.CharacterEntered:Connect(function(player: Player, char: Types.CharacterData)
		keys[player] = LeaderboardService.KeyOf(player)
		lastSent[player] = nil
		publish(player, Clock.now())
		if not world() then
			return
		end
		local state = stateOf(char)
		local o = occ
		local pendingEnd = ending
		if o then
			-- a new occurrence replaces an older one; an unpaid older one is settled first (ensure)
			ensure(player)
			welcome(player)
		elseif state.id ~= "" and not state.paid and not (pendingEnd and pendingEnd.occ.id == state.id) then
			-- an occurrence that ended without settling this character: now, or once the last writes landed
			local _, endsAt = BloodMoon.spanOf(state.id)
			local wait = if endsAt then math.max(0, endsAt + CFG.settleDelay - Clock.now()) else 0
			local snapshot = table.clone(state)
			task.delay(wait, function()
				if character(player) == char then
					settleCharacter(player, snapshot, nil)
				end
			end)
		end
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player, char: Types.CharacterData?)
		flushPlayer(player, true, char)
		keys[player] = nil
		dirty[player] = nil
		lastWrite[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "bloodMoonBoard" }, nil)
		end
		lastSent[player] = nil
	end)
	PlayerStateService.Ready:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player)
		keys[player] = nil
		dirty[player] = nil
		lastWrite[player] = nil
		writing[player] = nil
		lastSent[player] = nil
	end)

	lastStep = Clock.now()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				step()
			end)
			if not ok then
				log:error("step failed: %s", tostring(err))
			end
			task.wait(1)
		end
	end)
end

return BloodMoonService
