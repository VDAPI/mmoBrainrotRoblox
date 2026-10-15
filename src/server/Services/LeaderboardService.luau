--!strict
-- Leaderboards across servers (S124, DESIGN-17 §5): the boards of Data/Leaderboards on shared Roblox stores
-- (Leaderboard/Stores: OrderedDataStore, MemoryStore SortedMap, DataStore lists and metadata), a per-server cache of the
-- tops (Leaderboard/Cache) and the town board of the Hall of Fame (Leaderboard/TownBoard).
--   * Writes: a character's scores (Logic/Leaderboard.SCORERS, the character only) and its metadata (name, class, guild
--     tag, level) are queued on level change, once on entering the world and on leaving (forced), at most one write per
--     board and entry key every Config.Leaderboard.writeGap s; one worker thread writes them in order. A deleted
--     character's entries go away; its Hall of Fame entry stays for good.
--   * Exclusions: Config.AdminUserIds (excludeAdmins), characters with `lbHidden` (/lb hide) and below minLevel are
--     never written; excluded users are also filtered out on read.
--   * Reads: one board at most every Config.Leaderboard.refresh s per server; the town boards and the boards opened in
--     the Rankings window during the last idleBoard s are kept fresh; LeaderboardGet answers from the cache.
--   * Without DataStore access (Studio) everything runs in memory and the window says "this server only".
--   * Hall of Fame: the first Data/Leaderboards.HOF_SIZE characters of each class at Config.MaxLevel, ordered by
--     `character.reached100At` (LevelService; veterans get the time of their first entry after S124), with a toast and
--     an announcement on every server.
--   * S125 weekly EXP (exp_week_<week>_<bracket>): LevelService.ExpGained from Data/Leaderboards.WEEK_SOURCES adds up
--     in character.expWeek; the absolute week total goes to the SortedMap of the character's bracket at most every
--     writeGap s per key and on leaving (Logic/Leaderboard.mergeWeekly: a retry never counts twice). After the week ends
--     one server (the "paid_<week>" lock in Config.Leaderboard.payoutStore) mails the top 3 of every bracket Dragon
--     Shards and the timed title: marked as sent before each mail, so a crash loses at most one reward, never doubles.
--   * S125 guilds: GuildService calls SubmitGuild after every change of a guild record it made (the sum of the highest
--     member levels, Logic/Leaderboard.guildScore), throttled like every board.
-- API for S125–S130: KeyOf, Submit, Add, Remove, ListInsert, List, Snapshot, SubmitPlayer, IsGlobal, Refreshed;
-- S125 SubmitGuild.
-- GuildService and MailService are taken lazily from the registry (GuildService takes this service lazily too).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Cache = require(script.Parent.Parent.Leaderboard.Cache)
local Stores = require(script.Parent.Parent.Leaderboard.Stores)
local TownBoard = require(script.Parent.Parent.Leaderboard.TownBoard)

local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Leaderboards = require(Shared.Data.Leaderboards)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)

local log = Log.new("LeaderboardService")

local LeaderboardService = {
	Name = "LeaderboardService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"LevelService",
		"AnnounceService",
		"WorldService",
	},
	-- (instanceId) after a board was read or changed on this server
	Refreshed = Cache.Refreshed,
}

local Registry: any
local DataService: any
local PlayerStateService: any
local CharacterService: any
local LevelService: any
local AnnounceService: any
local GuildService: any
local MailService: any

local CFG = Config.Leaderboard

local throttle = Leaderboard.newThrottle()
local lastMeta: { [string]: Leaderboard.Meta } = {} -- key -> the metadata last queued from this server
local hofBusy: { [string]: boolean } = {} -- key -> a Hall of Fame write is running
local hofSettled: { [string]: boolean } = {} -- key -> in the list already, or the list was full (this session)
local working = false
local lastForcedRefresh = -math.huge

-- S125 weekly EXP and payouts
type WeekSnap = {
	key: string,
	userId: number,
	slot: string,
	charId: string,
	name: string,
	class: string,
	level: number,
	tag: string?,
	expWeek: Types.ExpWeek,
}
local rng = Rng.new()
local dirtyWeek: { [Player]: boolean } = {} -- the week total changed since the last write
local weekBusy: { [Player]: boolean } = {}
local weekLast: { [string]: number } = {} -- entry key -> os.time() of the last weekly write (writeGap)
local weekInFlight = 0 -- weekly writes still running (BindToClose waits for them)
local paidWeeks: { [number]: boolean } = {}
local paying = false
-- the winners of the last paid week this server knows (from its payout or the record); plan = with keys (server only)
local lastPaid: { week: number, winners: { Leaderboard.Winner }, plan: { Leaderboard.Payout } }? = nil
local wonToasted: { [string]: boolean } = {} -- "<week>|<entry key>|<charId>" -> the winner saw the toast here

-- S60 pattern: GuildService depends on nothing here at Init time; S125 makes it depend on this service.
local function guildService(): any
	if GuildService == nil and Registry then
		local ok, service = pcall(Registry.Get, "GuildService")
		GuildService = if ok then service else false
	end
	return GuildService or nil
end

-- S125: the mail service, lazily (it does not depend on this service, but nothing here needs it at Init time).
local function mailService(): any
	if MailService == nil and Registry then
		local ok, service = pcall(Registry.Get, "MailService")
		MailService = if ok then service else false
	end
	return MailService or nil
end

local function guildTag(player: Player): string?
	local gs = guildService()
	if not gs then
		return nil
	end
	local ok, data = pcall(gs.Data, player)
	return if ok and type(data) == "table" and type(data.tag) == "string" and data.tag ~= "" then data.tag else nil
end

local function excludedUser(userId: number): boolean
	return Leaderboard.excluded(userId, nil, Config.AdminUserIds, CFG)
end

local function excludedPlayer(player: Player, character: any): boolean
	return Leaderboard.excluded(player.UserId, character, Config.AdminUserIds, CFG)
end

-- Character score boards of this character (level and level_<class> in S124) with their instance ids now.
local function scoreBoards(character: any, now: number): { { def: Leaderboard.BoardDef, id: string } }
	local out = {}
	for _, def in Leaderboards.list do
		if
			def.scope == "character"
			and def.score ~= nil
			and def.kind ~= "list"
			and (def.class == nil or def.class == character.class)
		then
			table.insert(out, { def = def, id = Leaderboard.instanceId(def, Leaderboard.partsAt(def, now)) })
		end
	end
	return out
end

local function metaChanged(old: Leaderboard.Meta?, new: Leaderboard.Meta): boolean
	return old == nil or old.n ~= new.n or old.c ~= new.c or old.g ~= new.g or old.l ~= new.l or old.m ~= new.m
end

local function queueMeta(key: string, meta: Leaderboard.Meta, now: number)
	Cache.putMeta(key, meta)
	if metaChanged(lastMeta[key], meta) then
		lastMeta[key] = meta
		Leaderboard.queue(throttle, Leaderboard.META_BOARD, key, { meta = meta }, now, CFG.writeGap)
	end
end

-- Takes the entry of `key` off every score board of `character` (and its metadata).
local function removeCharacter(key: string, character: any)
	local now = os.time()
	for _, board in scoreBoards(character, now) do
		Leaderboard.queue(throttle, board.id, key, { remove = true }, now, CFG.writeGap)
		Cache.mergeLocal(board.id, key, nil)
	end
	if lastMeta[key] then
		lastMeta[key] = nil
	end
	-- KeyStore cannot delete a key: a marker stands for "no metadata" (Logic/Leaderboard.rows)
	Leaderboard.queue(throttle, Leaderboard.META_BOARD, key, { remove = true }, now, CFG.writeGap)
	Cache.putMeta(key, nil)
	Leaderboard.release(throttle, key)
end

-- Queues the scores and metadata of `character` under `key`. Returns false when the character is left out.
local function submitCharacter(player: Player, character: any, key: string, force: boolean?): boolean
	if excludedPlayer(player, character) then
		return false
	end
	if not Leaderboard.eligible(character, CFG) then
		if lastMeta[key] then
			-- fell below minLevel (admin /lvl down): the old entry would lie
			removeCharacter(key, character)
		end
		return false
	end
	local now = os.time()
	for _, board in scoreBoards(character, now) do
		local scorer = Leaderboard.SCORERS[board.def.score :: string]
		local score = scorer and scorer(character, now)
		if score then
			Leaderboard.queue(throttle, board.id, key, { score = score }, now, CFG.writeGap)
			Cache.mergeLocal(board.id, key, score)
		end
	end
	local tag = guildTag(player)
	local before = lastMeta[key]
	if tag == nil and force and character.guildId ~= nil and before then
		-- leaving: GuildService may have dropped the player's guild first (handler order is not fixed); still a member,
		-- so keep the tag written before (leaving a guild clears `guildId`)
		tag = before.g
	end
	queueMeta(key, {
		n = character.name,
		c = character.class,
		g = tag,
		l = character.level,
		u = player.UserId,
		t = now,
	}, now)
	if force then
		Leaderboard.release(throttle, key)
	end
	return true
end

-- Weekly EXP (S125) ---------------------------------------------------------------------------------------------------

local function weekNow(): number
	return Time.weekNumber(Clock.now())
end

local function weekStore(week: number, bracket: number): Stores.Board
	return Stores.sorted(Leaderboard.weekMapName(week, bracket), CFG.weekTtl)
end

-- A copy of what a weekly write needs, taken before any yield (the character may leave meanwhile).
local function weekSnap(player: Player, character: any): WeekSnap?
	local slot = PlayerStateService.Get(player, { "session", "slot" })
	if not character or slot == nil or type(character.expWeek) ~= "table" then
		return nil
	end
	local state = character.expWeek
	return {
		key = Leaderboard.entryKey(player.UserId, slot),
		userId = player.UserId,
		slot = tostring(slot),
		charId = character.id,
		name = character.name,
		class = character.class,
		level = character.level,
		tag = guildTag(player),
		expWeek = { week = state.week or 0, exp = state.exp or 0, b = state.b or 0 },
	}
end

-- Writes the week total of a snapshot to the map of its bracket (yields). The bracket is the level now; an entry left
-- in the bracket of the previous write is removed first. Returns (ok, bracket written).
local function writeWeekSnapNow(snap: WeekSnap): (boolean, number)
	local state = snap.expWeek
	if state.week <= 0 or state.exp <= 0 then
		return true, state.b
	end
	local bracket = Leaderboard.bracketOf(snap.level)
	local entry = Leaderboard.weeklyEntry({
		userId = snap.userId,
		slot = snap.slot,
		charId = snap.charId,
		name = snap.name,
		class = snap.class,
		level = snap.level,
		guildTag = snap.tag,
		exp = state.exp,
		now = os.time(),
	})
	if state.b ~= 0 and state.b ~= bracket then
		weekStore(state.week, state.b).remove(entry.key)
		Cache.mergeLocal(Leaderboard.weekMapName(state.week, state.b), entry.key, nil)
	end
	local id = Leaderboard.weekMapName(state.week, bracket)
	local ok = weekStore(state.week, bracket).update(entry.key, function(current: any?): any?
		return Leaderboard.mergeWeekly(current, entry.value)
	end)
	if ok then
		Cache.putMeta(entry.key, entry.value.m)
		Cache.mergeLocal(id, entry.key, entry.value.s)
	end
	return ok, bracket
end

-- writeWeekSnapNow counted in weekInFlight: BindToClose waits for these writes too (S125 C2).
local function writeWeekSnap(snap: WeekSnap): (boolean, number)
	weekInFlight += 1
	local called, ok, bracket = pcall(writeWeekSnapNow, snap)
	weekInFlight -= 1
	if not called then
		log:warn("weekly write of %s failed: %s", snap.key, tostring(ok))
		return false, snap.expWeek.b
	end
	return ok, bracket
end

-- The weekly write of an online player (the worker, /rankweek flush). Another write of the same player is skipped.
local function writeWeekly(player: Player)
	if weekBusy[player] then
		return
	end
	local character = PlayerStateService.GetCharacter(player)
	if not character or excludedPlayer(player, character) then
		dirtyWeek[player] = nil
		return
	end
	local snap = weekSnap(player, character)
	if not snap then
		dirtyWeek[player] = nil
		return
	end
	weekBusy[player] = true
	dirtyWeek[player] = nil -- EXP gained while this write yields marks it again
	weekLast[snap.key] = os.time()
	local ok, bracket = writeWeekSnap(snap)
	weekBusy[player] = nil
	local now = PlayerStateService.GetCharacter(player)
	local same = now ~= nil and now.id == snap.charId and type(now.expWeek) == "table"
	if ok then
		if same and now.expWeek.week == snap.expWeek.week and now.expWeek.b ~= bracket then
			PlayerStateService.Set(player, { "character", "expWeek", "b" }, bracket)
		end
	elseif same and player.Parent then
		dirtyWeek[player] = true -- the next round tries again
		log:warn("weekly write of %s failed; trying again later", snap.key)
	end
end

local function onExpGained(player: Player, gained: number, source: string?)
	if not Leaderboard.countsForWeek(source) then
		return
	end
	local character = PlayerStateService.GetCharacter(player)
	if not character or excludedPlayer(player, character) then
		return
	end
	local week = weekNow()
	local old = character.expWeek
	if type(old) == "table" and old.week ~= week and old.week > 0 and dirtyWeek[player] then
		-- the week turned while playing: the old total goes to the old week's map first
		local snap = weekSnap(player, character)
		if snap then
			task.spawn(writeWeekSnap, snap)
		end
		dirtyWeek[player] = nil
	end
	PlayerStateService.Set(player, { "character", "expWeek" }, Leaderboard.addWeekly(old, week, gained))
	dirtyWeek[player] = true
	local key = LeaderboardService.KeyOf(player)
	if key and weekLast[key] == nil then
		-- the first write lands within one writeGap, spread so servers do not write in step
		weekLast[key] = os.time() - rng:int(0, CFG.writeGap)
	end
end

-- Due weekly writes (the worker, every second).
local function weeklyTick()
	local now = os.time()
	for player in dirtyWeek do
		if not player.Parent then
			dirtyWeek[player] = nil
			continue
		end
		local key = LeaderboardService.KeyOf(player)
		if key and not weekBusy[player] and now - (weekLast[key] or 0) >= CFG.writeGap then
			task.spawn(writeWeekly, player)
		end
	end
end

-- The payout record of `week` (yields): (ok, record?).
local function payoutRecord(week: number): (boolean, any?)
	return Stores.payouts:get("paid_" .. week)
end

-- "Your character won" once per server for the active character of an online winner of the last paid week.
local function toastWinners()
	local paid = lastPaid
	if not paid then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = PlayerStateService.GetCharacter(player)
		if character then
			for _, p in paid.plan do
				local mark = `{paid.week}|{p.key}|{character.id}`
				if p.userId == player.UserId and p.charId == character.id and not wonToasted[mark] then
					wonToasted[mark] = true
					Net.Fire(player, "Toast", "leaderboard.week.won", {
						place = p.place,
						bracket = Leaderboard.bracketLabel(p.bracket),
					}, "success")
				end
			end
		end
	end
end

local function rememberPaid(week: number, record: any)
	if lastPaid and lastPaid.week > week then
		return
	end
	lastPaid = {
		week = week,
		winners = if type(record.winners) == "table" then record.winners else {},
		plan = if type(record.plan) == "table" then record.plan else {},
	}
	toastWinners()
end

-- Updates the payout record while this server holds the lock ("busy" otherwise).
local function updateOwned(week: number, fn: (record: any) -> (any?, string?)): (boolean, any?, string?)
	return Stores.payouts:update("paid_" .. week, function(record: any?): (any?, string?)
		if type(record) ~= "table" or record.state ~= "claimed" or record.job ~= game.JobId then
			return nil, "busy"
		end
		return fn(record)
	end)
end

-- Pays week `week` (yields): the lock, the plan (kept in the record before anything is sent), then per winner "mark,
-- mail, unmark on failure", then "done". Returns ("paid" | "done" | "busy" | "failed", parcels sent now).
local function payWeek(week: number): (string, number)
	local now = os.time()
	local ok, record, err = Stores.payouts:update("paid_" .. week, function(current: any?): (any?, string?)
		return Leaderboard.claimPayout(current, game.JobId, now, CFG.payoutLockStale)
	end)
	if not ok then
		if err == "done" then
			paidWeeks[week] = true
			local okRead, done = payoutRecord(week)
			if okRead and type(done) == "table" then
				rememberPaid(week, done)
			end
			return "done", 0
		end
		return if err == "busy" then "busy" else "failed", 0
	end
	local plan: { Leaderboard.Payout } = if type(record.plan) == "table" then record.plan else {}
	if type(record.plan) ~= "table" then
		local tops: { [number]: { { key: string, value: any } } } = {}
		local want = #Leaderboards.WEEK_REWARDS.shards + 2 -- room for entries without EXP or a character key
		for bracket = 1, #Leaderboards.WEEK_BRACKETS do
			local okTop, entries = weekStore(week, bracket).top(want)
			if not okTop then
				return "failed", 0
			end
			local list = {}
			for _, e in entries do
				local user = Leaderboard.parseKey(e.key)
				if user and not excludedUser(user) then
					table.insert(list, { key = e.key, value = e.raw })
				end
			end
			tops[bracket] = list
		end
		local planned = Leaderboard.payoutPlan(week, tops)
		local okPlan, _, planErr = updateOwned(week, function(r: any): (any?, string?)
			if type(r.plan) == "table" then
				return nil, "planned" -- planned by this server before a retry
			end
			r.plan = planned
			r.winners = Leaderboard.winnersOf(planned)
			return r, nil
		end)
		if not okPlan and planErr ~= "planned" then
			return if planErr == "busy" then "busy" else "failed", 0
		end
		if okPlan then
			plan = planned
		else
			local okRead, again = payoutRecord(week)
			if not okRead or type(again) ~= "table" or type(again.plan) ~= "table" then
				return "failed", 0
			end
			plan = again.plan
		end
	end
	local sent = 0
	local weekDate = Leaderboard.dateParts(Time.weekStart(week))
	for _, p in plan do
		local okMark, _, markErr = updateOwned(week, function(r: any): (any?, string?)
			r.sent = if type(r.sent) == "table" then r.sent else {}
			if r.sent[p.key] then
				return nil, "sent"
			end
			r.sent[p.key] = true
			return r, nil
		end)
		if not okMark then
			if markErr == "sent" then
				continue
			end
			return if markErr == "busy" then "busy" else "failed", sent
		end
		local mail = mailService()
		local okSend = false
		if mail then
			okSend = mail.Send(p.userId, {
				from = "system",
				subjectKey = "mail.subject.weeklyRank",
				args = {
					place = p.place,
					bracket = Leaderboard.bracketLabel(p.bracket),
					week = { key = "leaderboard.date", args = weekDate },
				},
				shards = p.shards,
				timedTitle = { id = p.title, untilTs = p.untilTs },
				charId = p.charId,
			})
		end
		if not okSend then
			updateOwned(week, function(r: any): (any?, string?)
				if type(r.sent) == "table" then
					r.sent[p.key] = nil
				end
				return r, nil
			end)
			log:warn("weekly reward %s of week %d not sent; the next attempt sends it", p.key, week)
			return "failed", sent
		end
		sent += 1
	end
	local okDone, done = updateOwned(week, function(r: any): (any?, string?)
		r.state = "done"
		r.doneAt = os.time()
		return r, nil
	end)
	if not okDone then
		return "failed", sent
	end
	paidWeeks[week] = true
	rememberPaid(week, done)
	log:info("week %d paid: %d parcels now, %d winners", week, sent, #plan)
	return "paid", sent
end

-- One payout run at a time on this server.
local function runPayout(week: number): (string, number)
	if paying then
		return "busy", 0
	end
	paying = true
	local ok, status, n = pcall(payWeek, week)
	paying = false
	if not ok then
		Stores.warnOnce("weekly payout", status)
		return "failed", 0
	end
	return status, n
end

-- The schedule: the previous week once its end is payoutGrace s old and this server does not know it is paid.
local function checkPayout()
	local now = Clock.now()
	local week = Time.weekNumber(now) - 1
	if paidWeeks[week] then
		if not lastPaid or lastPaid.week < week then
			local ok, record = payoutRecord(week)
			if ok and type(record) == "table" and record.state == "done" then
				rememberPaid(week, record)
			end
		end
		toastWinners()
		return
	end
	if now < Time.weekStart(week + 1) + CFG.payoutGrace then
		return
	end
	local ok, record = payoutRecord(week)
	if ok and type(record) == "table" and record.state == "done" then
		paidWeeks[week] = true
		rememberPaid(week, record)
		return
	end
	runPayout(week)
end

-- Guilds (S125) ----------------------------------------------------------------------------------------------------------

-- The guild board entry of a guild record (GuildService after every change it wrote): the score and the metadata, or
-- the removal of a disbanded / empty guild. Throttled per guild like every board (the last queued score wins).
function LeaderboardService.SubmitGuild(data: any)
	if type(data) ~= "table" or type(data.id) ~= "string" then
		return
	end
	local key = Leaderboard.guildKey(data.id)
	local count, highest = 0, 0
	for _, m in if type(data.members) == "table" then data.members else {} do
		count += 1
		highest = math.max(highest, tonumber(m.level) or 0)
	end
	local now = os.time()
	if data.disbanded or count == 0 then
		LeaderboardService.Remove("guild", key)
		lastMeta[key] = nil
		Leaderboard.queue(throttle, Leaderboard.META_BOARD, key, { remove = true }, now, CFG.writeGap)
		Cache.putMeta(key, nil)
		return
	end
	local score = Leaderboard.encodeGuild(Leaderboard.guildScore(data.members), tonumber(data.createdAt) or 0)
	LeaderboardService.Submit("guild", key, score, { n = data.name, g = data.tag, l = highest, m = count, t = now })
end

-- Public API ----------------------------------------------------------------------------------------------------------

-- The entry key of the active character ("<userId>_<slot>"), nil outside the world.
function LeaderboardService.KeyOf(player: Player): string?
	if PlayerStateService.GetPhase(player) ~= "playing" then
		return nil
	end
	local slot = PlayerStateService.Get(player, { "session", "slot" })
	if slot == nil then
		return nil
	end
	return Leaderboard.entryKey(player.UserId, slot)
end

-- Sets a score on an ordered or sorted board (throttled per board and key). `meta` goes with a sorted entry; on an
-- ordered board it updates the metadata store.
function LeaderboardService.Submit(instanceId: string, key: string, score: number, meta: Leaderboard.Meta?)
	local def = Leaderboard.resolve(instanceId)
	if not def or def.kind == "list" then
		error(`LeaderboardService.Submit: {instanceId} is not a score board`)
	end
	local now = os.time()
	if def.kind == "sorted" then
		Leaderboard.queue(throttle, instanceId, key, { score = score, meta = meta }, now, CFG.writeGap)
	else
		Leaderboard.queue(throttle, instanceId, key, { score = score }, now, CFG.writeGap)
		if meta then
			queueMeta(key, meta, now)
		end
	end
	Cache.mergeLocal(instanceId, key, score)
end

-- Adds to a score of a sorted board (batched: the deltas of one writeGap go in one UpdateAsync). S125 week EXP, S129.
function LeaderboardService.Add(instanceId: string, key: string, delta: number, meta: Leaderboard.Meta?)
	local def = Leaderboard.resolve(instanceId)
	if not def or def.kind ~= "sorted" then
		error(`LeaderboardService.Add: {instanceId} is not a sorted board`)
	end
	Leaderboard.queue(throttle, instanceId, key, { delta = delta, meta = meta }, os.time(), CFG.writeGap)
end

function LeaderboardService.Remove(instanceId: string, key: string)
	Leaderboard.queue(throttle, instanceId, key, { remove = true }, os.time(), CFG.writeGap)
	Leaderboard.release(throttle, key)
	Cache.mergeLocal(instanceId, key, nil)
end

-- Adds an entry to a list board (yields: one UpdateAsync). Returns true for a new entry, or false and "dup" (already
-- in), "full" (mode "first" and no place left), "store" (the store failed: try again later), "unknown".
function LeaderboardService.ListInsert(instanceId: string, entry: Leaderboard.ListEntry): (boolean, string?)
	local def = Leaderboard.resolve(instanceId)
	if not def or def.kind ~= "list" then
		return false, "unknown"
	end
	local max = def.max or Leaderboards.HOF_SIZE
	local mode: Leaderboards.ListMode = def.mode or "first"
	local ok, written, errKey = Stores.lists:update(instanceId, function(current: any?): (any?, string?)
		local list, why = Leaderboard.listInsert(
			if type(current) == "table" and type(current.entries) == "table" then current.entries else nil,
			entry,
			max,
			mode
		)
		if not list then
			return nil, why
		end
		return { entries = list }, nil
	end)
	if ok and type(written) == "table" then
		Cache.setList(instanceId, written.entries)
		return true, nil
	end
	if errKey == "dup" or errKey == "full" then
		Cache.refresh(def, instanceId)
		return false, errKey
	end
	return false, "store"
end

-- The cached list of a list board (nil before the first read; starts a read when due).
function LeaderboardService.List(instanceId: string): { Leaderboard.ListEntry }?
	local def = Leaderboard.resolve(instanceId)
	if not def or def.kind ~= "list" then
		return nil
	end
	Cache.refresh(def, instanceId)
	local _, list = Cache.get(instanceId)
	return list
end

local function snapshotOf(instanceId: string, player: Player?, wait: boolean): Leaderboard.Snapshot?
	local def, parts = Leaderboard.resolve(instanceId)
	if not def then
		return nil
	end
	local now = os.time()
	if player then
		Cache.touch(instanceId, now)
	end
	Cache.refresh(def, instanceId)
	local entries, list, fetchedAt = Cache.get(instanceId)
	if fetchedAt == nil and wait then
		Cache.wait(instanceId, CFG.firstWait)
		entries, list, fetchedAt = Cache.get(instanceId)
	end
	local myKey = if player then LeaderboardService.KeyOf(player) else nil
	local character: any = if player then PlayerStateService.GetCharacter(player) else nil
	local rows: { Leaderboard.Row }
	local me: Leaderboard.Me? = nil
	local last: { week: number, rows: { Leaderboard.Row } }? = nil
	if def.kind == "list" then
		local l = list or {}
		local myCid = if character then character.id else nil
		rows = Leaderboard.listRows(def, l, excludedUser, myKey, myCid)
		if player and character then
			me =
				Leaderboard.listMe(l, myKey, def.max or Leaderboards.HOF_SIZE, excludedPlayer(player, character), myCid)
		end
	else
		local guild: any = nil
		if def.scope == "guild" then
			-- S125: the own row of the guild board is the player's guild
			local gs = guildService()
			if player and gs then
				local ok, data = pcall(gs.Data, player)
				guild = if ok then data else nil
			end
			myKey = if type(guild) == "table" and type(guild.id) == "string"
				then Leaderboard.guildKey(guild.id)
				else nil
		end
		rows = Leaderboard.rows(def, entries or {}, Cache.metaOf, excludedUser, myKey)
		if def.scope == "guild" then
			me = if player then Leaderboard.guildMe(guild, rows) else nil
		elseif def.id == "exp_week" then
			-- S125: the week's EXP and bracket of the character, the winners of the week before
			local week = tonumber(parts and parts[1]) or weekNow()
			if player and character then
				me = Leaderboard.weekMe(character, rows, week, excludedPlayer(player, character))
			end
			local paid = lastPaid
			if paid and paid.week == week - 1 then
				local bracket = tonumber(parts and parts[2]) or 1
				local winners = Leaderboard.winnerRows(paid.winners, bracket)
				if #winners > 0 then
					last = { week = paid.week, rows = winners }
				end
			end
		elseif player and character and (def.class == nil or def.class == character.class) then
			me = Leaderboard.me(character, rows, CFG, excludedPlayer(player, character))
		end
	end
	return {
		id = instanceId,
		kind = def.kind,
		format = def.format,
		rows = rows,
		me = me,
		at = fetchedAt or now,
		mode = Stores.mode(def.kind),
		loading = if fetchedAt == nil then true else nil,
		last = last,
	}
end

-- A snapshot of a board for `player` (own row and line) from the cache; the very first read of a board is waited for
-- at most Config.Leaderboard.firstWait s (yields).
function LeaderboardService.Snapshot(instanceId: string, player: Player?): Leaderboard.Snapshot?
	return snapshotOf(instanceId, player, true)
end

function LeaderboardService.IsGlobal(): boolean
	return Stores.mode() == "global"
end

-- Queues the scores of the player's active character on every character board with a scorer. `force` writes past the
-- throttle (leave, /lb submit). Returns false when the character is left out (excluded or below minLevel).
function LeaderboardService.SubmitPlayer(player: Player, force: boolean?): boolean
	local character = PlayerStateService.GetCharacter(player)
	local key = LeaderboardService.KeyOf(player)
	if not character or not key then
		return false
	end
	return submitCharacter(player, character, key, force)
end

-- Hall of Fame ----------------------------------------------------------------------------------------------------------

local function hofBoardOf(class: string): Leaderboard.BoardDef?
	return Leaderboards.get(`hof_{string.lower(class)}`)
end

local function checkHallOfFame(player: Player)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local key = LeaderboardService.KeyOf(player)
	if not character or not key or character.level < Config.MaxLevel or excludedPlayer(player, character) then
		return
	end
	if character.reached100At == nil then
		-- a veteran from before S124: the real moment is unknown, the first entry after it counts (DECYZJE S124)
		PlayerStateService.Set(player, { "character", "reached100At" }, os.time())
		character = PlayerStateService.GetCharacter(player)
	end
	local def = hofBoardOf(character.class)
	if not def or hofBusy[key] or hofSettled[key] then
		return
	end
	local max = def.max or Leaderboards.HOF_SIZE
	local _, list = Cache.get(def.id)
	if list and (Leaderboard.placeOf(list, key, character.id) or #list >= max) then
		hofSettled[key] = true
		return
	end
	local entry: Leaderboard.ListEntry = {
		k = key,
		n = character.name,
		c = character.class,
		u = player.UserId,
		at = character.reached100At or os.time(),
		cid = character.id,
	}
	local classKey = `@class.{character.class}.name`
	hofBusy[key] = true
	task.spawn(function()
		local ok, why = LeaderboardService.ListInsert(def.id, entry)
		hofBusy[key] = nil
		if ok then
			hofSettled[key] = true
			local _, written = Cache.get(def.id)
			local place = Leaderboard.placeOf(written, key, entry.cid) or 0
			if player.Parent then
				Net.Fire(player, "Toast", "leaderboard.hof.entered", { class = classKey, n = place }, "success")
				Analytics.custom(player, "HallOfFame", place)
			end
			AnnounceService.Global("leaderboard.hof.announce", "leaderboard.hof.announceGlobal", {
				name = entry.n,
				class = classKey,
				n = place,
				level = Config.MaxLevel,
			})
			log:info("%s entered the Hall of Fame (%s, place %d)", entry.n, character.class, place)
		elseif why == "dup" or why == "full" then
			hofSettled[key] = true
		end
		-- "store": tried again on the next entry into the world
	end)
end

-- Worker ------------------------------------------------------------------------------------------------------------------

local function write(p: Leaderboard.Pending)
	local ok = true
	if p.board == Leaderboard.META_BOARD then
		local value: any = if p.remove then { n = "", t = os.time(), d = true } else p.meta
		if value ~= nil then
			ok = Stores.meta:update(p.key, function()
				return value, nil
			end)
		end
	else
		local def = Leaderboard.resolve(p.board)
		if not def or def.kind == "list" then
			return
		end
		local board = Stores.board(def.kind, p.board, def.ttl)
		if p.remove then
			ok = board.remove(p.key)
		else
			if p.score ~= nil then
				ok = board.set(p.key, p.score, p.meta)
			end
			if ok and p.delta ~= nil and p.delta ~= 0 then
				ok = board.add(p.key, p.delta, p.meta)
			end
		end
	end
	if not ok then
		local tries = (p.tries or 0) + 1
		if tries < CFG.deleteTries then
			-- back in the queue (tried again after writeGap), unless something newer is queued: a newer score or removal
			-- wins, a delta adds up
			local k = Leaderboard.throttleKey(p.board, p.key)
			local queued = throttle.pending[k]
			if queued then
				if p.delta ~= nil and not queued.remove then
					queued.delta = (queued.delta or 0) + p.delta
				end
			else
				Leaderboard.queue(
					throttle,
					p.board,
					p.key,
					{ score = p.score, delta = p.delta, meta = p.meta, remove = p.remove },
					os.time(),
					CFG.writeGap
				)
				local again = throttle.pending[k]
				if again then
					again.tries = tries
				end
			end
		end
	end
end

local function flush(force: boolean?)
	if working then
		return
	end
	working = true
	local ok, err = pcall(function()
		for _, p in Leaderboard.due(throttle, os.time(), CFG.writeGap, force) do
			write(p)
		end
	end)
	working = false
	if not ok then
		Stores.warnOnce("leaderboard write", err)
	end
end

-- Town boards and the plinth lists always; other boards while someone opened them in the last idleBoard seconds.
local function refreshBoards(force: boolean?): number
	local now = os.time()
	local ids: { [string]: boolean } = {}
	for _, panel in Leaderboards.TOWN.panels do
		for _, id in panel.boards do
			ids[id] = true
		end
	end
	for _, plinth in Leaderboards.TOWN.plinths do
		ids[plinth.board] = true
	end
	for _, id in Cache.usedSince(now - CFG.idleBoard) do
		ids[id] = true
	end
	local n = 0
	for id in ids do
		local def = Leaderboard.resolve(id)
		if def then
			Cache.refresh(def, id, force)
			n += 1
		end
	end
	return n
end

-- Admin (/lb) -------------------------------------------------------------------------------------------------------------

export type Info = { mode: string, boards: number, pending: number, key: string, score: string }

function LeaderboardService.Info(player: Player): Info
	local key = LeaderboardService.KeyOf(player)
	local character = PlayerStateService.GetCharacter(player)
	local score = "-"
	if character then
		local s = Leaderboard.SCORERS.level(character, os.time())
		score = if s then string.format("%.0f", s) else "-"
	end
	return {
		mode = Stores.mode(),
		boards = #Cache.stats(os.time()),
		pending = Leaderboard.pendingCount(throttle),
		key = key or "-",
		score = score,
	}
end

-- Forced read of the town and recently opened boards, at most once per adminRefreshGap s. (ok, boards)
function LeaderboardService.ForceRefresh(): (boolean, number)
	if os.clock() - lastForcedRefresh < CFG.adminRefreshGap then
		return false, 0
	end
	lastForcedRefresh = os.clock()
	return true, refreshBoards(true)
end

-- Writes the player's entry now (past the throttle). False when the character is left out.
function LeaderboardService.AdminSubmit(player: Player): boolean
	local ok = LeaderboardService.SubmitPlayer(player, true)
	if ok then
		task.spawn(flush, false)
	end
	return ok
end

-- /lb hide | show: the test flag of an online player's character.
function LeaderboardService.SetHidden(player: Player, hidden: boolean): boolean
	local character = PlayerStateService.GetCharacter(player)
	local key = LeaderboardService.KeyOf(player)
	if not character or not key then
		return false
	end
	PlayerStateService.Set(player, { "character", "lbHidden" }, if hidden then true else nil)
	if hidden then
		removeCharacter(key, character)
		-- S125: and the entry of this week
		local state = character.expWeek
		dirtyWeek[player] = nil
		if type(state) == "table" and state.b ~= 0 and state.week == weekNow() then
			task.spawn(function()
				weekStore(state.week, state.b).remove(key)
				Cache.mergeLocal(Leaderboard.weekMapName(state.week, state.b), key, nil)
			end)
		end
	else
		LeaderboardService.SubmitPlayer(player, true)
	end
	return true
end

-- /lb remove <instanceId>:<key>: one entry of a score board, or of a list (yields for a list).
function LeaderboardService.RemoveEntry(instanceId: string, key: string): boolean
	local def = Leaderboard.resolve(instanceId)
	if not def then
		return false
	end
	if def.kind == "list" then
		local ok, written = Stores.lists:update(instanceId, function(current: any?): (any?, string?)
			local out = {}
			local found = false
			for _, e in if type(current) == "table" and type(current.entries) == "table" then current.entries else {} do
				if e.k == key then
					found = true
				else
					table.insert(out, e)
				end
			end
			if not found then
				return nil, "missing"
			end
			return { entries = out }, nil
		end)
		if ok and type(written) == "table" then
			Cache.setList(instanceId, written.entries)
		end
		return ok
	end
	LeaderboardService.Remove(instanceId, key)
	return true
end

-- /lb fake <n>: test characters on the in-memory boards of this server (Studio without API access only).
function LeaderboardService.Fake(n: number): boolean
	if Stores.mode() ~= "local" then
		return false
	end
	local now = os.time()
	local fakes = Leaderboard.fakeEntries(n, now)
	local byClass: { [string]: { Leaderboard.ListEntry } } = {}
	for i, fake in fakes do
		local class = fake.meta.c :: string
		for _, id in { "level", `level_{string.lower(class)}` } do
			Stores.ordered(id).set(fake.key, fake.score, nil)
		end
		Cache.putMeta(fake.key, fake.meta)
		local entries = byClass[class] or {}
		byClass[class] = entries
		if #entries < Leaderboards.HOF_SIZE then
			table.insert(entries, {
				k = fake.key,
				n = fake.meta.n,
				c = class,
				u = 0,
				at = fake.at or (now - (#fakes - i + 1) * 86400),
			})
		end
	end
	-- S125: the weekly boards of this week and the guild board
	local week = weekNow()
	for _, fake in Leaderboard.fakeWeekly(n, now) do
		local value = fake.value
		weekStore(week, fake.bracket).update(fake.key, function(): any?
			return value
		end)
	end
	for _, g in Leaderboard.fakeGuilds(n, now) do
		Stores.ordered("guild").set(g.key, g.score, nil)
		Cache.putMeta(g.key, g.meta)
	end
	for class, entries in byClass do
		local def = hofBoardOf(class)
		if def then
			table.sort(entries, function(a, b)
				return if a.at ~= b.at then a.at < b.at else a.k < b.k
			end)
			Stores.lists:update(def.id, function(): (any?, string?)
				return { entries = entries }, nil
			end)
		end
	end
	refreshBoards(true)
	return true
end

-- /lb hofclear <class>: empties a Hall of Fame list (in-memory mode only).
function LeaderboardService.HofClear(class: string): boolean
	if Stores.mode() ~= "local" then
		return false
	end
	local def = hofBoardOf(class)
	if not def then
		return false
	end
	Stores.lists:update(def.id, function(): (any?, string?)
		return { entries = {} }, nil
	end)
	Cache.setList(def.id, {})
	table.clear(hofSettled)
	return true
end

-- Admin (/rankweek, /rankguild; S125) -------------------------------------------------------------------------------------

export type WeekInfo = { week: number, left: string, exp: number, bracket: string, mock: string, paid: string }

function LeaderboardService.WeekInfo(player: Player): WeekInfo
	local now = Clock.now()
	local week = Time.weekNumber(now)
	local character = PlayerStateService.GetCharacter(player)
	local d, h, m = Time.split(Leaderboard.weekEndsIn(now))
	return {
		week = week,
		left = `{d}d {h}h {m}m`,
		exp = Leaderboard.weekExp(character, week),
		bracket = Leaderboard.bracketLabel(Leaderboard.bracketOf(if character then character.level else 1)),
		mock = "@admin.rank.mode." .. Stores.mode("sorted"),
		paid = "@admin.rank.state." .. (if paidWeeks[week - 1] then "done" elseif paying then "running" else "open"),
	}
end

-- Writes the player's week total now, past the write gap (yields). False when the character is left out.
function LeaderboardService.WeekFlush(player: Player): boolean
	local character = PlayerStateService.GetCharacter(player)
	if not character or excludedPlayer(player, character) then
		return false
	end
	writeWeekly(player)
	local state = character.expWeek
	if type(state) == "table" then
		local def = Leaderboards.get("exp_week")
		local id = Leaderboard.weekMapName(state.week, Leaderboard.bracketOf(character.level))
		if def then
			Cache.refresh(def, id, true)
		end
	end
	return true
end

-- Pays `week` (default the previous one) through the same lock as the schedule (yields). The last value: the week has
-- not ended yet (its scheduled payout will find it done).
function LeaderboardService.WeekPay(week: number?): (string, number, number, boolean)
	local w = week or (weekNow() - 1)
	local status, n = runPayout(w)
	return status, n, w, w >= weekNow()
end

-- Clears this week's and the previous week's in-memory maps and payout records (in-memory mode only).
function LeaderboardService.WeekReset(): (boolean, number)
	local week = weekNow()
	if Stores.mode("sorted") ~= "local" or not Stores.payouts:isMock() then
		return false, week
	end
	for _, w in { week, week - 1 } do
		for bracket = 1, #Leaderboards.WEEK_BRACKETS do
			weekStore(w, bracket).clear()
			local def = Leaderboards.get("exp_week")
			if def then
				Cache.refresh(def, Leaderboard.weekMapName(w, bracket), true)
			end
		end
		Stores.payouts:update("paid_" .. w, function(): (any?, string?)
			return { state = "reset", at = os.time() }, nil
		end)
		paidWeeks[w] = nil
	end
	lastPaid = nil
	table.clear(wonToasted)
	return true, week
end

-- Adds `amount` to the character's week only (no real EXP; tests of the ranking). False when left out.
function LeaderboardService.WeekAdd(player: Player, amount: number): boolean
	local character = PlayerStateService.GetCharacter(player)
	if not character or excludedPlayer(player, character) or LeaderboardService.KeyOf(player) == nil then
		return false
	end
	local week = weekNow()
	PlayerStateService.Set(player, { "character", "expWeek" }, Leaderboard.addWeekly(character.expWeek, week, amount))
	dirtyWeek[player] = true
	return true
end

-- The guild of the player on the guild board: (score, rank?) or nil without a guild.
function LeaderboardService.GuildInfo(player: Player): (number?, number?)
	local gs = guildService()
	local data = if gs then gs.Data(player) else nil
	if type(data) ~= "table" then
		return nil, nil
	end
	local key = Leaderboard.guildKey(data.id)
	local entries: { Leaderboard.Entry } = Cache.get("guild") or {}
	local rank: number? = nil
	for i, e in entries do
		if e.key == key then
			rank = i
			break
		end
	end
	return Leaderboard.guildScore(data.members), rank
end

-- Writes the player's guild entry now, past the throttle.
function LeaderboardService.GuildPush(player: Player): boolean
	local gs = guildService()
	local data = if gs then gs.Data(player) else nil
	if type(data) ~= "table" then
		return false
	end
	LeaderboardService.SubmitGuild(data)
	Leaderboard.release(throttle, Leaderboard.guildKey(data.id))
	task.spawn(flush, false)
	return true
end

-- Lifecycle -----------------------------------------------------------------------------------------------------------------

function LeaderboardService.Init(registry)
	Registry = registry
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	LevelService = registry.Get("LevelService")
	AnnounceService = registry.Get("AnnounceService")
	Stores.init(DataService.HasDataStoreAccess)
end

function LeaderboardService.Start()
	LevelService.ExpGained:Connect(onExpGained)

	LevelService.LevelChanged:Connect(function(player: Player, newLevel: number)
		LeaderboardService.SubmitPlayer(player)
		if newLevel >= Config.MaxLevel then
			checkHallOfFame(player)
		end
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player, character: Types.CharacterData)
		local key = LeaderboardService.KeyOf(player)
		if character.level >= Config.MaxLevel then
			checkHallOfFame(player)
		end
		-- once per entry: characters from before S124 and guild changes reach the boards without a level-up
		task.delay(CFG.enterDelay, function()
			if key ~= nil and player.Parent and LeaderboardService.KeyOf(player) == key then
				LeaderboardService.SubmitPlayer(player)
			end
		end)
		toastWinners()
	end)

	-- The character data goes away after this event: read it now, write past the throttle ("and on leave").
	CharacterService.CharacterLeaving:Connect(function(player: Player, character: Types.CharacterData)
		local key = LeaderboardService.KeyOf(player)
		if key then
			submitCharacter(player, character, key, true)
		end
		-- S125: the week total "and on leave", past the write gap, from a copy taken now
		if dirtyWeek[player] and not excludedPlayer(player, character) then
			local snap = weekSnap(player, character)
			if snap then
				local state = snap.expWeek
				if state.week > 0 and state.exp > 0 then
					-- the bracket of this write is saved with the character (it leaves before the write ends)
					PlayerStateService.Set(player, { "character", "expWeek", "b" }, Leaderboard.bracketOf(snap.level))
				end
				task.spawn(writeWeekSnap, snap)
			end
		end
		dirtyWeek[player] = nil
		weekBusy[player] = nil
	end)

	CharacterService.CharacterDeleted:Connect(function(player: Player, character: Types.CharacterData, slotKey: string?)
		if slotKey then
			local key = Leaderboard.entryKey(player.UserId, slotKey)
			removeCharacter(key, character)
			hofSettled[key] = nil
			-- S125: the entry of this week (the slot key may go to a new character: mergeWeekly compares cid)
			local state = character.expWeek
			if type(state) == "table" and state.b ~= 0 and state.week == weekNow() then
				task.spawn(function()
					weekStore(state.week, state.b).remove(key)
					Cache.mergeLocal(Leaderboard.weekMapName(state.week, state.b), key, nil)
				end)
			end
			weekLast[key] = nil
		end
	end)

	Net.Handle("LeaderboardGet", function(player: Player, instanceId: string)
		local def, parts = Leaderboard.resolve(instanceId)
		-- S125: a board with parts only for the ids the window builds (this week, brackets 1..4)
		if not def or def.hidden or not Leaderboard.readable(def, parts, Clock.now()) then
			return false, "leaderboard.error.unknown"
		end
		local snapshot = LeaderboardService.Snapshot(instanceId, player)
		if not snapshot then
			return false, "leaderboard.error.unknown"
		end
		return true, snapshot
	end)

	TownBoard.start(function(boardId: string): Leaderboard.Snapshot?
		return snapshotOf(boardId, nil, false)
	end, LeaderboardService.List, Cache.Refreshed)

	-- The worker: queued writes every second, board reads when due.
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			flush(false)
			weeklyTick()
			tick += 1
			if tick % 5 == 0 then
				refreshBoards(false)
			end
		end
	end)

	-- S125: the weekly payout schedule (first check after payoutGrace: a server started later finishes a broken payout)
	task.spawn(function()
		task.wait(CFG.payoutGrace)
		while true do
			local ok, err = pcall(function()
				checkPayout()
			end)
			if not ok then
				Stores.warnOnce("weekly payout check", err)
			end
			task.wait(CFG.payoutCheck + rng:int(-CFG.payoutJitter, CFG.payoutJitter))
		end
	end)

	game:BindToClose(function()
		-- CharacterLeaving of every player (DataService releases the profiles) queues the last writes first
		local started = os.clock()
		task.wait(1)
		while os.clock() - started < CFG.flushWait do
			if not working then
				flush(true)
				if Leaderboard.pendingCount(throttle) == 0 and weekInFlight == 0 and os.clock() - started > 2 then
					break
				end
			end
			task.wait(0.25)
		end
	end)
end

return LeaderboardService
