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
-- API for S125–S130: KeyOf, Submit, Add, Remove, ListInsert, List, Snapshot, SubmitPlayer, IsGlobal, Refreshed.
-- GuildService is taken lazily from the registry (S125 adds LeaderboardService to its Deps: no cycle).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Cache = require(script.Parent.Parent.Leaderboard.Cache)
local Stores = require(script.Parent.Parent.Leaderboard.Stores)
local TownBoard = require(script.Parent.Parent.Leaderboard.TownBoard)

local Config = require(Shared.Config)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Leaderboards = require(Shared.Data.Leaderboards)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
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

local CFG = Config.Leaderboard

local throttle = Leaderboard.newThrottle()
local lastMeta: { [string]: Leaderboard.Meta } = {} -- key -> the metadata last queued from this server
local hofBusy: { [string]: boolean } = {} -- key -> a Hall of Fame write is running
local hofSettled: { [string]: boolean } = {} -- key -> in the list already, or the list was full (this session)
local working = false
local lastForcedRefresh = -math.huge

-- S60 pattern: GuildService depends on nothing here at Init time; S125 makes it depend on this service.
local function guildService(): any
	if GuildService == nil and Registry then
		local ok, service = pcall(Registry.Get, "GuildService")
		GuildService = if ok then service else false
	end
	return GuildService or nil
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
	return old == nil or old.n ~= new.n or old.c ~= new.c or old.g ~= new.g or old.l ~= new.l
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
	local def = Leaderboard.resolve(instanceId)
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
	if def.kind == "list" then
		local l = list or {}
		local myCid = if character then character.id else nil
		rows = Leaderboard.listRows(def, l, excludedUser, myKey, myCid)
		if player and character then
			me =
				Leaderboard.listMe(l, myKey, def.max or Leaderboards.HOF_SIZE, excludedPlayer(player, character), myCid)
		end
	else
		rows = Leaderboard.rows(def, entries or {}, Cache.metaOf, excludedUser, myKey)
		if player and character and (def.class == nil or def.class == character.class) then
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
	end)

	-- The character data goes away after this event: read it now, write past the throttle ("and on leave").
	CharacterService.CharacterLeaving:Connect(function(player: Player, character: Types.CharacterData)
		local key = LeaderboardService.KeyOf(player)
		if key then
			submitCharacter(player, character, key, true)
		end
	end)

	CharacterService.CharacterDeleted:Connect(function(player: Player, character: Types.CharacterData, slotKey: string?)
		if slotKey then
			local key = Leaderboard.entryKey(player.UserId, slotKey)
			removeCharacter(key, character)
			hofSettled[key] = nil
		end
	end)

	Net.Handle("LeaderboardGet", function(player: Player, instanceId: string)
		local def = Leaderboard.resolve(instanceId)
		if not def or def.hidden then
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
			tick += 1
			if tick % 5 == 0 then
				refreshBoards(false)
			end
		end
	end)

	game:BindToClose(function()
		-- CharacterLeaving of every player (DataService releases the profiles) queues the last writes first
		local started = os.clock()
		task.wait(1)
		while os.clock() - started < CFG.flushWait do
			if not working then
				flush(true)
				if Leaderboard.pendingCount(throttle) == 0 and os.clock() - started > 2 then
					break
				end
			end
			task.wait(0.25)
		end
	end)
end

return LeaderboardService
