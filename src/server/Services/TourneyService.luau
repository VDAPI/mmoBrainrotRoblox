--!strict
-- Champion's Tournament (S130, DESIGN-17 §8): every Saturday 19:00 UTC a single elimination 1v1 bracket in each of the
-- four arena brackets. Every server computes the same schedule from the UTC clock (Logic/Tourney over Util/Clock.now,
-- so /time moves it too). The pieces (src/server/Tourney): Store (signup lists, the organizer's lock, the server
-- records; MemoryStore through the S127 Backend or an in-memory fake), Bus (MessagingService "open" / "cancel"),
-- Hall (the champions in a DataStore) and Runner (one bracket fought through ArenaService.RunMatch).
-- World servers:
--   * signups 18:00-18:50 UTC (TourneySignup, the arena window or the Arena Master): first the store, then
--     character.tourney.signed; the bracket is the level at the signup; announcements at the opening, 10 min before
--     the close, at the close and at the start (AnnounceService.Server on every server by the clock);
--   * 18:55 (global mode): one server takes the lock lock_<id> and, bracket by bracket, reads the list, picks the 32
--     best 1v1 ratings (ties: the earlier signup), reserves one server (ReserveServer), writes the record
--     srv_<id>_<bracket>, registers the reserved server in the S127 ReservedServers ("tournament", "<id>_<bracket>")
--     and publishes "open" (or "cancel" under 4); every world server invites its signed players of the record (2 min
--     to accept, TourneyRespond), the others hear "the list was full"; two own reads of the records (recheck) cover a
--     lost message; an accepted invitation teleports (Arena/Transfer.toReserved);
--   * the local mode ("this server only": Studio, no MemoryStore, an admin test tournament): the signups stay here,
--     18:55 invites the signed players of this server, 19:00 runs every bracket here on the Ristalle (one field, the
--     sand held for the whole tournament through Arena/Sand: duels and ranked matches wait).
-- A tournament server (Arena/ServerMode "tournament", ref "<id>_<bracket>"): claims the mode, lets in only the keys of
-- the record (TeleportData is never proof), puts everybody in the lobby of arena_pit, starts the bracket at 19:00 (or
-- once everybody arrived), four matches at once on pit_1 .. pit_4, losers watch or go home (TourneyLeave), the
-- champion is announced on every server, everybody goes home Config.Tourney.returnDelay s after the final.
-- Rewards: one mail parcel per character (S129 fields: shards, tokens outside the week cap, timed title, cosmetics,
-- `once` = tourney_<id>_<bracket>_<key>), the Hall of Fame (Tourney/Hall, the city board and statues). Nothing here
-- reads purchases (tests/paywall.spec). The Elixir of Wholeness is off for the players of a bracket and on a tournament
-- server (UseGuards "tourney").
-- Runtime branch `tourney` (Types.TourneyClient), published per player only when it changed.
-- S131 (admin /tourney force): a real tournament forced on every server through the bus ("force", Tourney.forcedId,
-- the start Tourney.forceStart); it takes the place of the scheduled one until its end and runs exactly like it (global
-- with the stores, else this server only). A server that boots after the message keeps the schedule.
-- Only AdminService lists this service in its Deps.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Arena = require(Shared.Data.Arena)
local ArenaPit = require(Shared.Data.ArenaPit)
local ArenaRules = require(Shared.Logic.ArenaRules)
local Bus = require(script.Parent.Parent.Tourney.Bus)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local Hall = require(script.Parent.Parent.Tourney.Hall)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local Runner = require(script.Parent.Parent.Tourney.Runner)
local Sand = require(script.Parent.Parent.Arena.Sand)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Store = require(script.Parent.Parent.Tourney.Store)
local Tourney = require(Shared.Logic.Tourney)
local Transfer = require(script.Parent.Parent.Arena.Transfer)
local Types = require(Shared.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("TourneyService")

local TourneyService = {
	Name = "TourneyService",
	-- none of these depends on TourneyService (AdminService lists it; GuildService is taken lazily)
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"DataService",
		"ResourceService",
		"ZoneService",
		"AnnounceService",
		"ArenaService",
		"MailService",
		"TravelService",
		"WorldService",
		"PvpService",
	},
}

local CFG = Config.Tourney
local RULES = Arena.TOURNEY
local CHAMPION_GAP = 11 -- s between two champion announcements of a local tournament (one line a bracket)
local rng = Rng.new() -- where a player appears in the lobby

type Phase = Tourney.Phase
type Mode = Store.Mode
type Invite = { id: string, bracket: string, code: string?, expiresAt: number }
-- The tournament this server deals with now: by the clock, or an admin test tournament (always local).
type Current = { id: string, startAt: number, phase: Phase, test: boolean }
type Test = { id: string, phase: Phase, closesAt: number, startAt: number }

local Registry: any
local PlayerStateService: any
local CharacterService: any
local DataService: any
local AnnounceService: any
local ArenaService: any
local MailService: any
local TravelService: any
local WorldService: any
local PvpService: any
local GuildService: any

local current: Current? = nil
local test: Test? = nil
local forced: { id: string, startAt: number }? = nil -- S131: /tourney force
local modes: { [string]: Mode } = {} -- tournament id -> its mode on this server (decided once)
local deciding: { [string]: boolean } = {}
local invites: { [Player]: Invite } = {}
local accepted: { [string]: { [string]: boolean } } = {} -- local mode: tournament id -> keys that accepted
local records: { [string]: Store.Record } = {} -- "<id>_<bracket>" -> the record seen by this server
local handled: { [string]: { [string]: boolean } } = {} -- "<id>_<bracket>" -> keys already invited / told
local runners: { [string]: Runner.Handle } = {} -- bracket -> the runner of this server
local runnerId: string? = nil -- the tournament the runners belong to
local organized: { [string]: boolean } = {}
local rechecks: { [string]: number } = {} -- tournament id -> own record reads done
local busy: { [Player]: boolean } = {}
local lastCall: { [Player]: number } = {}
local lastSent: { [Player]: string } = {}
local charIds: { [string]: string } = {} -- character key -> character id (mail after the player left)
local paid: { [string]: boolean } = {}
local lastStep = 0
local localSand: { id: string, granted: boolean }? = nil
local championLine = 0 -- the next free moment for a local champion announcement
local hallJson: string? = nil

-- tournament server
local hostRecord: Store.Record? = nil
local hostRef: { id: string, bracket: string }? = nil
local joinData: { [Player]: any } = {}
local hostEndsAt: number? = nil
local hostRunner: Runner.Handle? = nil -- kept after the final: the bracket, the champion and the return stay shown

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function keyOf(player: Player): string?
	if not PlayerStateService.HasState(player) or character(player) == nil then
		return nil
	end
	local slot = PlayerStateService.Get(player, { "session", "slot" })
	if slot == nil then
		return nil
	end
	return Leaderboard.entryKey(player.UserId, slot)
end

-- The online player of a character key (the same character active), nil otherwise.
local function playerOfKey(key: string): Player?
	local userId = Leaderboard.parseKey(key)
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	if player and keyOf(player) == key then
		return player
	end
	return nil
end

local function toast(player: Player, key: string, args: { [string]: any }?, kind: string?)
	if player.Parent then
		Net.Fire(player, "Toast", key, args, kind or "info")
	end
end

local function stateOf(char: Types.CharacterData): Types.TourneyState
	local t = (char :: any).tourney
	if type(t) ~= "table" then
		return { played = 0, won = 0, best = 0 }
	end
	return t :: Types.TourneyState
end

local function setSigned(player: Player, value: { id: string, bracket: string }?)
	if character(player) then
		PlayerStateService.Set(player, { "character", "tourney", "signed" }, value)
	end
end

local function rating1v1(player: Player): number
	local state = ArenaService.State(player)
	if state then
		return ArenaRules.ratingOf(state, Arena.MODES["1v1"])
	end
	return Arena.ELO.start
end

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

-- The tournament now (a test tournament first).
local function currentNow(now: number): Current
	local t = test
	if t then
		return { id = t.id, startAt = t.startAt, phase = t.phase, test = true }
	end
	local f = forced
	if f and now < Tourney.times(f.startAt).ends then
		return { id = f.id, startAt = f.startAt, phase = Tourney.phaseFor(f.startAt, now), test = false }
	end
	local phase, startAt = Tourney.phaseAt(now)
	return { id = Tourney.idOf(startAt), startAt = startAt, phase = phase :: Phase, test = false }
end

local function cur(): Current
	return current or currentNow(Clock.now())
end

local onMessage: (message: Bus.Message) -> ()

-- The mode of a tournament on this server (decided once per tournament by a fresh probe, retried once, so a store error
-- at boot does not make every later Saturday local; yields). A test tournament is always local, and so is everything
-- on a non-world server. A global tournament subscribes the bus if the boot probe failed.
local function modeOf(id: string, isTest: boolean): Mode
	local known: Mode? = modes[id]
	if known then
		return known
	end
	if isTest or not ServerMode.isWorld() then
		modes[id] = "local"
		return "local"
	end
	while deciding[id] do
		task.wait(0.1)
	end
	local decided: Mode? = modes[id]
	if decided then
		return decided
	end
	deciding[id] = true
	local online = false
	for attempt = 1, 2 do
		local ok, result = pcall(Store.probe, true)
		online = ok and result == true
		if online or RunService:IsStudio() then
			break
		end
		if attempt == 1 then
			task.wait(CFG.probeRetry)
		end
	end
	deciding[id] = nil
	local m: Mode = if online then "global" else "local"
	modes[id] = m
	log:info("tournament %s runs %s", id, m)
	if m == "global" then
		task.spawn(Bus.start, onMessage, true)
	end
	return m
end

-- Publishing --------------------------------------------------------------------------------------------------------

local function runnerOf(key: string): Runner.Handle?
	for _, r in runners do
		if r.Has(key) then
			return r
		end
	end
	return nil
end

local function payloadFor(player: Player): Types.TourneyClient?
	local char = character(player)
	if not char then
		return nil
	end
	local c = cur()
	local key = keyOf(player)
	local state = stateOf(char)
	local signed = state.signed
	local inv = invites[player]
	local out: Types.TourneyClient = {
		mode = modes[c.id],
		phase = c.phase,
		startAt = c.startAt,
		id = c.id,
		server = ServerMode.get(),
		test = if c.test then true else nil,
		signed = if signed and signed.id == c.id then { bracket = signed.bracket } else nil,
		invite = if inv then { expiresAt = inv.expiresAt, range = Tourney.rangeOf(inv.bracket) } else nil,
		live = nil,
	}
	local r = if key then runnerOf(key) else nil
	if r == nil and ServerMode.get() == "tournament" then
		-- a tournament server: everybody sees its bracket (after the final too, until everybody went home)
		for _, any in runners do
			r = any
		end
		r = r or hostRunner
	end
	if r and key then
		local me = r.Me(key)
		out.live = {
			bracket = r.bracket,
			range = r.range,
			view = r.View(),
			me = if me
				then { place = me.place, field = me.field, at = nil, state = me.state }
				else { place = nil, field = nil, at = nil, state = "spectator" },
			endsAt = hostEndsAt,
		}
	end
	return out
end

local function publish(player: Player)
	if not player.Parent or not PlayerStateService.HasState(player) then
		return
	end
	local payload = payloadFor(player)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, payload)
	local encoded = if ok then json else tostring(os.clock())
	if lastSent[player] == encoded then
		return
	end
	lastSent[player] = encoded
	PlayerStateService.Set(player, { "tourney" }, payload)
end

local function publishAll()
	for _, player in Players:GetPlayers() do
		publish(player)
	end
end

-- Rewards (F1-F4) ---------------------------------------------------------------------------------------------------

local function sendReward(id: string, bracket: string, key: string, place: number, showed: boolean)
	local r = Tourney.rewardsFor(place, showed)
	if r.shards <= 0 and r.tokens <= 0 and r.title == nil and #r.cosmetics == 0 then
		return
	end
	local userId = Leaderboard.parseKey(key)
	local charId = charIds[key]
	if not userId or not charId then
		log:warn("tournament %s: no character for the reward of %s", id, key)
		return
	end
	local outgoing = {
		from = "system",
		subjectKey = "mail.subject.tourney",
		args = { place = Tourney.placeArg(place) },
		charId = charId,
		shards = if r.shards > 0 then r.shards else nil,
		tokens = if r.tokens > 0 then r.tokens else nil,
		cosmetics = if #r.cosmetics > 0 then r.cosmetics else nil,
		timedTitle = if r.title then { id = r.title, untilTs = Clock.now() + (r.titleDays or 0) * 86400 } else nil,
		once = `tourney_{id}_{bracket}_{key}`,
	}
	task.spawn(function()
		local ok, err = MailService.Send(userId, outgoing)
		if not ok then
			log:warn("tournament %s: reward mail for %s failed: %s", id, key, tostring(err))
		end
	end)
end

local function onPlace(id: string, bracket: string, key: string, place: number, showed: boolean, player: Player?)
	local paidKey = `{id}|{bracket}|{key}`
	if paid[paidKey] then
		return
	end
	paid[paidKey] = true
	sendReward(id, bracket, key, place, showed)
	if player and keyOf(player) == key then
		local char = character(player)
		if char then
			local state = stateOf(char)
			local nextState: Types.TourneyState = {
				signed = nil,
				played = state.played + (if showed then 1 else 0),
				won = state.won + (if place == 1 then 1 else 0),
				best = if showed then (if state.best == 0 then place else math.min(state.best, place)) else state.best,
			}
			PlayerStateService.Set(player, { "character", "tourney" }, nextState)
			Analytics.custom(player, "TourneyPlace", place)
			if place > 1 then
				toast(player, "tourney.out", { place = Tourney.placeArg(place) }, "info")
			end
		end
	end
end

local function refreshBoards(champions: Hall.Champions?)
	if not ServerMode.isWorld() then
		return
	end
	local value = champions or Hall.peek()
	local json: string? = nil
	if value then
		local ok, encoded = pcall(HttpService.JSONEncode, HttpService, value)
		json = if ok then encoded else nil
	end
	hallJson = json
	for _, board in CollectionService:GetTagged("TourneyFameBoard") do
		board:SetAttribute("Hall", json)
		board:SetAttribute("Mode", if DataService.HasDataStoreAccess() then "global" else "local")
	end
	for _, plaque in CollectionService:GetTagged("TourneyFamePlinth") do
		local i = plaque:GetAttribute("Plinth")
		local b = if type(i) == "number" then Arena.BRACKETS[i] else nil
		local list = if value and b then value[b.id] else nil
		local top = if list then list[1] else nil
		plaque:SetAttribute("HeroName", if top then top.name else nil)
		plaque:SetAttribute("ClassKey", if top then top.class else nil)
		plaque:SetAttribute("TourneyId", if top then top.id else nil)
	end
end

local function announceChampion(range: string, name: string, isLocal: boolean)
	local args = { player = name, range = range }
	if isLocal then
		local at = math.max(os.clock(), championLine)
		championLine = at + CHAMPION_GAP
		task.delay(at - os.clock(), function()
			AnnounceService.Server("tourney.champion", args)
		end)
	else
		AnnounceService.Global("tourney.champion", "tourney.championGlobal", args)
		-- a tournament server: the big message for everybody here
		Net.FireAll("BossAnnounce", "tourney.championBig", args)
	end
end

-- After a bracket: the champion announced, the Hall of Fame.
local function onBracketDone(
	id: string,
	bracket: string,
	championKey: string?,
	cancelled: boolean,
	isLocal: boolean,
	isTest: boolean
)
	runners[bracket] = nil
	publishAll()
	if cancelled or championKey == nil then
		log:info("tournament %s bracket %s: no champion", id, bracket)
		return
	end
	local player = playerOfKey(championKey)
	local char = if player then character(player) else nil
	local range = Tourney.rangeOf(bracket)
	local name = if char then char.name else championKey
	announceChampion(range, name, isLocal)
	if player and char and not isTest then
		local entry: Hall.Entry = {
			id = id,
			name = char.name,
			class = char.class :: string,
			userId = player.UserId,
			guild = guildTag(player),
		}
		task.spawn(function()
			if Hall.add(bracket, entry) then
				refreshBoards(Hall.peek())
			end
		end)
	end
end

-- Runners ---------------------------------------------------------------------------------------------------------

local function arenaApi(): Runner.ArenaApi
	return {
		RunMatch = ArenaService.RunMatch,
		MatchFinished = ArenaService.MatchFinished,
		ForceWin = ArenaService.ForceWin,
		AdminStop = ArenaService.AdminStop,
		CanFight = ArenaService.CanFight,
		InMatch = ArenaService.InMatch,
	}
end

local function entrantOf(player: Player, key: string): ArenaRules.Entrant?
	local char = character(player)
	if not char or keyOf(player) ~= key then
		return nil
	end
	local state = ArenaService.State(player)
	return {
		key = key,
		userId = player.UserId,
		slot = tonumber(PlayerStateService.Get(player, { "session", "slot" })) or 0,
		name = char.name,
		class = char.class :: string,
		level = char.level,
		rating = if state then ArenaRules.ratingOf(state, Arena.MODES["1v1"]) else Arena.ELO.start,
		played = if state then tonumber(state.played) or 0 else 0,
	}
end

-- A pool of venue ids (the fields of a tournament server, or the one Ristalle shared by the local runners).
local function pool(venues: { string }, ready: () -> boolean): Runner.FieldPool
	local free: { [string]: boolean } = {}
	for _, v in venues do
		free[v] = true
	end
	local p = {} :: any
	function p.take(_self: Runner.FieldPool): string?
		if not ready() then
			return nil
		end
		for _, v in venues do
			if free[v] then
				free[v] = false
				return v
			end
		end
		return nil
	end
	function p.give(_self: Runner.FieldPool, venue: string)
		if free[venue] ~= nil then
			free[venue] = true
		end
	end
	function p.number(_self: Runner.FieldPool, venue: string): number
		return table.find(venues, venue) or 1
	end
	return p :: Runner.FieldPool
end

local function startRunner(
	id: string,
	bracket: string,
	players: { Runner.PlayerEntry },
	fields: Runner.FieldPool,
	isLocal: boolean,
	isTest: boolean
): Runner.Handle
	for _, p in players do
		local char = character(p.player)
		if char then
			charIds[p.key] = char.id
		end
	end
	local handle = Runner.start({
		id = id,
		bracket = bracket,
		range = Tourney.rangeOf(bracket),
		players = players,
		fields = fields,
		arena = arenaApi(),
		direct = isLocal,
		waitBusy = isLocal,
		online = playerOfKey,
		entrant = entrantOf,
		toast = toast,
		onPlace = function(key: string, place: number, showed: boolean, player: Player?)
			if isTest then
				-- a test tournament gives no rewards (statistics neither): only the place
				if player then
					toast(player, "tourney.out", { place = Tourney.placeArg(place) }, "info")
				end
				return
			end
			onPlace(id, bracket, key, place, showed, player)
		end,
		onDone = function(championKey: string?, cancelled: boolean)
			onBracketDone(id, bracket, championKey, cancelled, isLocal, isTest)
		end,
		onChange = publishAll,
	})
	runners[bracket] = handle
	runnerId = id
	return handle
end

-- Local mode (D8) ---------------------------------------------------------------------------------------------------

-- The signed players of tournament `id` on this server, by bracket.
local function signedHere(id: string): { [string]: { Player } }
	local out: { [string]: { Player } } = {}
	for _, player in Players:GetPlayers() do
		local char = character(player)
		local signed = if char then stateOf(char).signed else nil
		if signed and signed.id == id then
			local list = out[signed.bracket] or {}
			table.insert(list, player)
			out[signed.bracket] = list
		end
	end
	return out
end

-- 18:55 locally: brackets with enough signed players here are invited, the others cancelled.
local function inviteLocal(c: Current): number
	local n = 0
	local expiresAt = Clock.now() + RULES.window.invite
	accepted[c.id] = accepted[c.id] or {}
	for bracket, list in signedHere(c.id) do
		if #list >= RULES.minPlayers then
			for _, player in list do
				invites[player] = { id = c.id, bracket = bracket, code = nil, expiresAt = expiresAt }
				n += 1
			end
		else
			for _, player in list do
				toast(player, "tourney.cancelled", { range = Tourney.rangeOf(bracket) }, "warning")
				setSigned(player, nil)
			end
		end
	end
	publishAll()
	return n
end

-- The local brackets start: the players that accepted and are here, one Runner a bracket, the Ristalle held for all.
local function startLocal(c: Current): number
	local list: { [string]: boolean } = accepted[c.id] or {}
	local byBracket: { [string]: { Runner.PlayerEntry } } = {}
	local count = 0
	for key in list do
		local player = playerOfKey(key)
		local char = if player then character(player) else nil
		local signed = if char then stateOf(char).signed else nil
		if player and char and signed and signed.id == c.id then
			local entries = byBracket[signed.bracket] or {}
			table.insert(entries, {
				player = player,
				key = key,
				rating = rating1v1(player),
				t = 0,
				name = char.name,
				class = char.class :: string,
			})
			byBracket[signed.bracket] = entries
			count += 1
		end
	end
	if count == 0 then
		return 0
	end
	-- one field for every bracket: the sand of the Ristalle, before every duel and ranked match waiting for it
	local sand = { id = `tourney_{c.id}`, granted = false }
	localSand = sand
	Sand.request("tourney", sand.id, function()
		sand.granted = true
	end, true)
	local fields = pool({ "ristalle" }, function(): boolean
		return sand.granted
	end)
	for _, b in Arena.BRACKETS do
		local entries = byBracket[b.id]
		if entries then
			-- signup order from the store (the local fake keeps it); the rating decides first anyway
			local signups = Store.readSignups("local", c.id, b.id)
			if signups then
				for _, e in entries do
					for _, s in signups do
						if s.key == e.key then
							e.t = s.t
						end
					end
				end
			end
			startRunner(c.id, b.id, entries, fields, true, c.test)
			for _, e in entries do
				if ArenaService.InQueue(e.player) then
					ArenaService.Leave(e.player)
					toast(e.player, "tourney.error.inBracket", nil, "warning")
				end
			end
		end
	end
	return count
end

local function releaseSand()
	local sand = localSand
	if sand and next(runners) == nil then
		localSand = nil
		Sand.cancel(sand.id)
		Sand.release("tourney", sand.id)
	end
end

-- Global mode (D4-D6) -----------------------------------------------------------------------------------------------

local function clearFor(player: Player, reasonKey: string, args: { [string]: any }?)
	toast(player, reasonKey, args, "warning")
	setSigned(player, nil)
	invites[player] = nil
end

-- A record of bracket `b` seen here (a message or an own read): invitations, "not picked" or "cancelled".
local function applyRecord(id: string, b: string, record: Store.Record)
	local recordKey = `{id}_{b}`
	records[recordKey] = record
	local done = handled[recordKey] or {}
	handled[recordKey] = done
	local range = Tourney.rangeOf(b)
	local inList: { [string]: boolean } = {}
	for _, k in record.keys do
		inList[k] = true
	end
	for _, player in Players:GetPlayers() do
		local char = character(player)
		local key = keyOf(player)
		local signed = if char then stateOf(char).signed else nil
		if key and signed and signed.id == id and signed.bracket == b and not done[key] then
			done[key] = true
			if record.state == "cancelled" then
				clearFor(
					player,
					if record.reason == "service" then "tourney.cancelled.service" else "tourney.cancelled",
					{ range = range }
				)
			elseif inList[key] and record.code then
				invites[player] = {
					id = id,
					bracket = b,
					code = record.code,
					expiresAt = Clock.now() + RULES.window.invite,
				}
			else
				clearFor(player, "tourney.notPicked", { range = range, rating = record.minRating or 0 })
				Net.Fire(
					player,
					"SystemMessage",
					"tourney.notPicked",
					{ range = range, rating = record.minRating or 0 }
				)
			end
		end
	end
	publishAll()
end

onMessage = function(message: Bus.Message)
	if message.op == "force" then
		-- S131: a forced tournament (also this server's own publish); a test tournament here keeps it out
		local startAt = message.t
		local now = Clock.now()
		if startAt and test == nil and startAt > now and startAt <= now + 3 * 3600 then
			forced = { id = message.id, startAt = startAt } -- the next step (every second) announces the signups
		end
		return
	end
	local c = cur()
	if message.id ~= c.id or c.test then
		return
	end
	task.spawn(function()
		local mode: Mode = modeOf(c.id, false)
		for _ = 1, 2 do
			local ok, record = Store.readServer(mode, message.id, message.b)
			if ok and record then
				applyRecord(message.id, message.b, record)
				return
			end
			task.wait(2)
		end
	end)
end

-- The organizer: one server (the lock), bracket after bracket.
local function organize(c: Current)
	if organized[c.id] then
		return
	end
	organized[c.id] = true
	local mode: Mode = modeOf(c.id, false)
	if mode ~= "global" then
		return
	end
	if not Store.tryLock(mode, c.id, if game.JobId ~= "" then game.JobId else Bus.ServerId) then
		return
	end
	log:info("tournament %s: this server organizes", c.id)
	local times = Tourney.times(c.startAt)
	local function bracketOf(b: Arena.Bracket)
		do
			local entries = Store.readSignups(mode, c.id, b.id)
			if entries == nil then
				task.wait(5)
				entries = Store.readSignups(mode, c.id, b.id)
			end
			if entries == nil then
				log:error("tournament %s bracket %s: the signups could not be read", c.id, b.id)
				Store.writeServer(mode, c.id, b.id, {
					state = "cancelled",
					reason = "service",
					keys = {},
					players = {},
					n = 0,
					startAt = c.startAt,
				})
				Bus.publish({ op = "cancel", id = c.id, b = b.id }, true)
				return
			end
			if #entries == 0 then
				return -- nobody signed: nothing to tell anyone
			end
			local picked, _, threshold = Tourney.pick(entries, RULES.cap, times.open)
			log:info("tournament %s bracket %s: %d signed, %d picked", c.id, b.id, #entries, #picked)
			if #picked < RULES.minPlayers then
				Store.writeServer(mode, c.id, b.id, {
					state = "cancelled",
					reason = "few",
					keys = {},
					players = {},
					n = #picked,
					startAt = c.startAt,
				})
				Bus.publish({ op = "cancel", id = c.id, b = b.id }, true)
				return
			end
			local code, ps = Store.reserve(mode)
			if not code or not ps then
				task.wait(2)
				code, ps = Store.reserve(mode)
			end
			local keys: { string } = {}
			local players = {}
			for _, e in picked do
				table.insert(keys, e.key)
				table.insert(players, { k = e.key, n = e.name, c = e.class, r = e.rating, t = e.t })
			end
			if not code or not ps then
				log:error("tournament %s bracket %s: no server could be reserved", c.id, b.id)
				Store.writeServer(mode, c.id, b.id, {
					state = "cancelled",
					reason = "service",
					keys = {},
					players = {},
					n = #picked,
					startAt = c.startAt,
				})
				Bus.publish({ op = "cancel", id = c.id, b = b.id }, true)
				return
			end
			Store.writeServer(mode, c.id, b.id, {
				state = "open",
				code = code,
				ps = ps,
				keys = keys,
				players = players,
				n = #picked,
				startAt = c.startAt,
				minRating = threshold,
			})
			-- the registry before the message: the tournament server starts with its first player
			ServerMode.register(Store.backend(mode), ps, "tournament", `{c.id}_{b.id}`)
			Bus.publish({ op = "open", id = c.id, b = b.id }, true)
		end
	end
	for _, b in Arena.BRACKETS do
		local ok, err = pcall(function()
			bracketOf(b)
		end)
		if not ok then
			log:error("tournament %s bracket %s: organizing failed: %s", c.id, b.id, tostring(err))
		end
	end
end

-- D6: a world server reads the records of its signed players itself (a lost message), at most twice.
local function recheck(c: Current)
	rechecks[c.id] = (rechecks[c.id] or 0) + 1
	local mode: Mode = modeOf(c.id, false)
	if mode ~= "global" then
		return
	end
	local need: { [string]: boolean } = {}
	for bracket, list in signedHere(c.id) do
		for _, player in list do
			local key = keyOf(player)
			local done = handled[`{c.id}_{bracket}`]
			if key and not (done and done[key]) then
				need[bracket] = true
			end
		end
	end
	for bracket in need do
		local ok, record = Store.readServer(mode, c.id, bracket)
		if ok and record then
			applyRecord(c.id, bracket, record)
		end
	end
end

-- Signups (D2) ------------------------------------------------------------------------------------------------------

local function signup(player: Player, sign: boolean): (boolean, string?)
	local char = character(player)
	local key = keyOf(player)
	if not char or not key then
		return false, "error.wrongPhase"
	end
	if not ServerMode.isWorld() then
		return false, "tourney.error.notWorld"
	end
	local now = Clock.now()
	local c = currentNow(now)
	local state = stateOf(char)
	local signed = state.signed
	if sign then
		local ok, err = Tourney.canSignup({ level = char.level, phase = c.phase, signed = signed, id = c.id })
		if not ok then
			return false, err
		end
		local bracket = Tourney.bracketOf(char.level) :: string
		local mode: Mode = modeOf(c.id, c.test)
		local openAt = if c.test then c.startAt - 1 else Tourney.times(c.startAt).open
		local stored = Store.signup(mode, c.id, bracket, key, {
			n = char.name,
			c = char.class :: string,
			r = rating1v1(player),
			l = char.level,
			t = math.floor(now),
		}, openAt)
		if not stored then
			return false, "tourney.error.service"
		end
		if character(player) ~= char then
			return false, "error.wrongPhase"
		end
		setSigned(player, { id = c.id, bracket = bracket })
		charIds[key] = char.id
		toast(player, "tourney.signedUp", { range = Tourney.rangeOf(bracket) }, "success")
		Analytics.custom(player, "TourneySignup", char.level)
		publish(player)
		return true, nil
	end
	local ok, err = Tourney.canUnsign({ phase = c.phase, signed = signed, id = c.id })
	if not ok then
		return false, err
	end
	local s = signed :: { id: string, bracket: string }
	local mode: Mode = modeOf(c.id, c.test)
	if not Store.unsign(mode, s.id, s.bracket, key) then
		return false, "tourney.error.service"
	end
	if character(player) == char then
		setSigned(player, nil)
	end
	toast(player, "tourney.withdrawn", nil, "info")
	publish(player)
	return true, nil
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local inv = invites[player]
	local key = keyOf(player)
	if not inv or not key or Clock.now() > inv.expiresAt then
		return false, "party.error.expired"
	end
	if not accept then
		invites[player] = nil
		setSigned(player, nil)
		toast(player, "tourney.declined", nil, "info")
		publish(player)
		return true, nil
	end
	local blocked = ArenaService.CanFight(player)
	if blocked then
		return false, blocked
	end
	if inv.code == nil then
		-- local mode: the bracket starts here at 19:00
		invites[player] = nil
		local list = accepted[inv.id] or {}
		list[key] = true
		accepted[inv.id] = list
		charIds[key] = (character(player) :: Types.CharacterData).id
		toast(player, "tourney.signed", { range = Tourney.rangeOf(inv.bracket) }, "success")
		publish(player)
		return true, nil
	end
	if Transfer.busy(player) then
		return false, "error.busy"
	end
	local slot = tonumber(PlayerStateService.Get(player, { "session", "slot" })) or 0
	local code = inv.code :: string
	local data = {
		serverMode = "tournament",
		tourney = `{inv.id}_{inv.bracket}`,
		slot = slot,
		returnJob = game.JobId,
	}
	local tries = 0
	local function onFail(_reason: string)
		tries += 1
		if tries < 2 and player.Parent == Players and invites[player] == inv then
			Transfer.toReserved(player, code, data, onFail)
			return
		end
		toast(player, "tourney.error.teleport", nil, "warning")
	end
	Transfer.toReserved(player, code, data, onFail)
	return true, nil
end

-- The loop (world servers) ------------------------------------------------------------------------------------------

local function announceAt(key: string, args: { [string]: any })
	AnnounceService.Server(key, args)
end

local function onPhase(c: Current, from: Phase?)
	if c.phase == "signup" then
		if not c.test then
			announceAt("tourney.announce.open", { time = `{Tourney.clockUtc(Tourney.times(c.startAt).close)} UTC` })
		end
		task.spawn(modeOf, c.id, c.test)
	elseif c.phase == "closed" then
		if not c.test then
			announceAt("tourney.announce.closed", {})
		end
	elseif c.phase == "inviting" then
		task.spawn(function()
			local mode: Mode = modeOf(c.id, c.test)
			if mode == "local" then
				inviteLocal(c)
			else
				organize(c)
			end
		end)
	elseif c.phase == "running" then
		if not c.test then
			announceAt("tourney.announce.started", {})
		end
		if modes[c.id] == "local" or c.test then
			startLocal(c)
		end
	end
	if from == "running" and c.phase == "idle" then
		accepted = {}
	end
end

local function step()
	local now = Clock.now()
	local t = test
	if t then
		if t.phase == "signup" and now >= t.closesAt then
			t.phase = "inviting"
			t.startAt = now + RULES.window.invite
		elseif t.phase == "inviting" and now >= t.startAt then
			t.phase = "running"
		end
	end
	local c = currentNow(now)
	local prev = current
	current = c
	if prev == nil or prev.id ~= c.id then
		-- a new tournament (or the first step): no announcements for phases this server did not see begin
		invites = {}
		if prev ~= nil and prev.phase ~= c.phase then
			onPhase(c, prev.phase)
		elseif prev == nil and (c.phase == "signup" or c.phase == "inviting") then
			task.spawn(modeOf, c.id, c.test)
			if c.phase == "inviting" then
				task.spawn(function()
					if modeOf(c.id, c.test) == "global" then
						organize(c)
					end
				end)
			end
		end
		publishAll()
	elseif prev.phase ~= c.phase then
		onPhase(c, prev.phase)
		publishAll()
	end
	-- 10 min before the close
	if not c.test and c.phase == "signup" then
		local warnAt = Tourney.times(c.startAt).close - 600
		if lastStep < warnAt and warnAt <= now and lastStep > 0 then
			announceAt("tourney.announce.closing", {})
		end
	end
	-- D6: own reads of the records after the organizer's time
	if not c.test and c.phase == "inviting" and modes[c.id] == "global" then
		local since = now - Tourney.times(c.startAt).organize
		local done = rechecks[c.id] or 0
		local due = CFG.recheck[done + 1]
		if due and since >= due then
			task.spawn(recheck, c)
		end
	end
	-- expired invitations
	for player, inv in table.clone(invites) do
		if now > inv.expiresAt then
			invites[player] = nil
			if inv.code ~= nil or not (accepted[inv.id] and accepted[inv.id][keyOf(player) or ""]) then
				setSigned(player, nil)
				toast(player, "tourney.inviteExpired", nil, "warning")
			end
			publish(player)
		end
	end
	-- a local tournament: the sand goes back when every bracket is over; a safety stop
	if next(runners) == nil then
		releaseSand()
		local t2 = test
		if t2 and t2.phase == "running" then
			-- the test tournament is over: its signups go
			for _, player in Players:GetPlayers() do
				local char = character(player)
				local signed = if char then stateOf(char).signed else nil
				if signed and signed.id == t2.id then
					setSigned(player, nil)
				end
			end
			accepted[t2.id] = nil
			test = nil
		end
	elseif runnerId and not test and now > Tourney.times(c.startAt).start + CFG.maxMinutes * 60 then
		log:error("tournament %s: the safety stop ended the local brackets", tostring(runnerId))
		for _, r in table.clone(runners) do
			r.Stop()
		end
	end
	lastStep = now
end

-- Tournament server (E1-E7) -----------------------------------------------------------------------------------------

local function lobbyCFrame(): CFrame
	local l = ArenaPit.layout("tournament").lobby
	local x, z = if l then l.x else 0, if l then l.z else 0
	local spread = if l then l.half - 4 else 4
	local rx = rng:float(-spread, spread)
	local rz = rng:float(-spread, spread)
	return WorldService.GroundCFrame("arena_pit", x + rx, z + rz)
end

local function joinDataOf(player: Player): any?
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return if ok then data else nil
end

local function homeOf(player: Player, reasonKey: string)
	task.spawn(Transfer.home, player, joinData[player] or joinDataOf(player), reasonKey, nil)
end

local function homeAll(reasonKey: string)
	for _, player in Players:GetPlayers() do
		homeOf(player, reasonKey)
	end
end

local function admit(player: Player)
	if player.Parent ~= Players then
		return
	end
	local data = joinDataOf(player)
	joinData[player] = data
	local r = hostRecord
	local ref = hostRef
	if not r or not ref then
		return -- the record is read at boot; admitted then
	end
	local tp = if type(data) == "table" and type(data.TeleportData) == "table" then data.TeleportData else {}
	local slot = tonumber(tp.slot)
	local key = if slot then Leaderboard.entryKey(player.UserId, slot) else nil
	if not key or not table.find(r.keys, key) or hostEndsAt ~= nil then
		homeOf(player, "tourney.error.notInvited") -- Transfer.home shows the reason
		return
	end
	local ok, err = CharacterService.Play(player, slot :: number, { map = "arena_pit", at = lobbyCFrame() })
	if not ok then
		log:warn("%s could not enter the tournament: %s", player.Name, tostring(err))
		homeOf(player, "tourney.error.notInvited")
		return
	end
	local char = character(player)
	if char then
		charIds[key] = char.id
	end
	publish(player)
end

local function hostPresent(): { Runner.PlayerEntry }
	local out: { Runner.PlayerEntry } = {}
	local r = hostRecord
	if not r then
		return out
	end
	for _, p in r.players do
		local player = playerOfKey(p.k)
		if player and player.Character then
			table.insert(out, { player = player, key = p.k, rating = p.r, t = p.t, name = p.n, class = p.c })
		end
	end
	return out
end

local function hostEnd(reasonKey: string)
	if hostEndsAt ~= nil then
		return
	end
	hostEndsAt = Workspace:GetServerTimeNow() + CFG.returnDelay
	for _, player in Players:GetPlayers() do
		toast(player, "tourney.ending", { s = CFG.returnDelay }, "info")
	end
	publishAll()
	task.delay(CFG.returnDelay, function()
		homeAll(reasonKey)
		-- C1: the ReservedServers entry goes with the tournament
		if game.PrivateServerId ~= "" then
			ServerMode.unregister(Store.backend("global"), game.PrivateServerId)
		end
	end)
end

local function startHost()
	ServerMode.claim("tournament", "TourneyService")
	local ref = ServerMode.tourney()
	hostRef = ref
	TravelService.AddGuard(function(_player: Player): string?
		return "arena.net.error.notHere"
	end)
	CharacterService.SetSpawnOverride(function(_player: Player): (CFrame?, string?)
		return lobbyCFrame(), "arena_pit"
	end)
	-- E5: only the two players of one match hit each other (ArenaService's match rule decides them); a spectator on a
	-- free field (a yellow zone) hits nobody
	PvpService.AddFightRule(function(attacker: Player, target: Player): string?
		if ArenaService.InMatch(attacker) or ArenaService.InMatch(target) then
			return nil
		end
		return "deny"
	end)
	PlayerStateService.Ready:Connect(function(player: Player)
		task.spawn(admit, player)
	end)
	game:BindToClose(function()
		for _, r in table.clone(runners) do
			r.Stop()
		end
		homeAll("arena.net.cancelled.server")
		local deadline = os.clock() + 25
		while #Players:GetPlayers() > 0 and os.clock() < deadline do
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		if not ref then
			log:warn("a tournament server without a tournament: everybody goes home")
			task.wait(5)
			homeAll("arena.net.cancelled.server")
			return
		end
		local deadline = os.clock() + Config.ArenaNet.modeWait
		local record: Store.Record? = nil
		while os.clock() < deadline do
			local ok, value = Store.readServer("global", ref.id, ref.bracket)
			if ok and value then
				record = value
				break
			end
			task.wait(1)
		end
		if not record or record.state ~= "open" then
			log:warn("no open record of %s %s: everybody goes home", ref.id, ref.bracket)
			homeAll("arena.net.cancelled.server")
			return
		end
		hostRecord = record
		modes[ref.id] = "global"
		current = { id = ref.id, startAt = record.startAt, phase = "inviting", test = false }
		for _, player in Players:GetPlayers() do
			if PlayerStateService.GetPhase(player) == "select" then
				task.spawn(admit, player)
			end
		end
		-- keep the ReservedServers entry alive while the tournament runs (its TTL is shorter than a tournament)
		task.spawn(function()
			local every = math.max(30, Config.ArenaNet.registryTtl / 3)
			while hostEndsAt == nil do
				task.wait(every)
				if hostEndsAt == nil and game.PrivateServerId ~= "" then
					ServerMode.register(
						Store.backend("global"),
						game.PrivateServerId,
						"tournament",
						ServerMode.ref() or ""
					)
				end
			end
		end)
		-- the start: at 19:00 once everybody of the record is here, else Config.Tourney.startWait s after it
		local bootAt = Clock.now()
		while true do
			task.wait(1)
			local now = Clock.now()
			local present = hostPresent()
			local all = #present >= #record.players
			if now >= record.startAt and (all or now >= record.startAt + CFG.startWait) then
				break
			end
			if now - bootAt > CFG.emptyClose and #present == 0 then
				log:warn("tournament %s %s: nobody arrived", ref.id, ref.bracket)
				hostEnd("tourney.cancelledFew")
				return
			end
		end
		current = { id = ref.id, startAt = record.startAt, phase = "running", test = false }
		local venues: { string } = {}
		for i = 1, RULES.fields do
			table.insert(venues, `pit_{i}`)
		end
		local present = hostPresent()
		local startedAt = os.clock()
		local handle = startRunner(
			ref.id,
			ref.bracket,
			present,
			pool(venues, function(): boolean
				return true
			end),
			false,
			false
		)
		hostRunner = handle
		publishAll()
		while not handle.Done() do
			task.wait(1)
			if os.clock() - startedAt > CFG.maxMinutes * 60 then
				log:error("tournament %s %s: the safety stop ended the bracket", ref.id, ref.bracket)
				handle.Stop()
				break
			end
			local anyone = false
			for _, p in record.players do
				if playerOfKey(p.k) then
					anyone = true
				end
			end
			if not anyone then
				handle.Stop()
				break
			end
		end
		hostEnd("tourney.ended")
	end)
end

-- Public API --------------------------------------------------------------------------------------------------------

-- Whether the Elixir of Wholeness is off for `player`: a tournament server as a whole, or a player of a bracket
-- fought on this server and still in it.
function TourneyService.InTourney(player: Player): boolean
	if ServerMode.get() == "tournament" then
		return true
	end
	for _, r in runners do
		if r.InTourney(player) then
			return true
		end
	end
	return false
end

-- The champions of the Hall of Fame (cached, Config.Tourney.hallRefresh).
function TourneyService.Hall(): Hall.Champions
	return Hall.read(Clock.now())
end

local function info(player: Player): (boolean, any)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local c = cur()
	local mode: Mode? = modes[c.id]
	local bracket = Tourney.bracketOf(char.level)
	local count: number? = nil
	local threshold: number? = nil
	if bracket and ServerMode.isWorld() and c.phase ~= "idle" then
		local m: Mode? = mode
		if m == nil and c.test then
			m = "local"
		end
		if m then
			count, threshold = Store.count(m, c.id, bracket, Clock.now())
		end
	end
	local champions = TourneyService.Hall()
	return true,
		{
			mode = mode,
			phase = c.phase,
			startAt = c.startAt,
			id = c.id,
			bracket = bracket,
			count = count,
			cap = RULES.cap,
			overflowRating = threshold,
			rating = rating1v1(player),
			hall = champions,
		}
end

-- Admin (H) --------------------------------------------------------------------------------------------------------

export type AdminInfo = {
	id: string,
	mode: string,
	phase: string,
	left: number,
	counts: string,
	lock: string,
	servers: string,
	server: string,
	test: boolean,
}

function TourneyService.AdminInfo(): AdminInfo
	local now = Clock.now()
	local c = currentNow(now)
	local mode: Mode? = modes[c.id]
	local counts: { string } = {}
	local servers: { string } = {}
	for _, b in Arena.BRACKETS do
		local n: number? = nil
		if mode then
			n = Store.count(mode, c.id, b.id, now)
		end
		table.insert(counts, `{b.id}: {if n then tostring(n) else "?"}`)
		local r = records[`{c.id}_{b.id}`]
		if r then
			table.insert(servers, `{b.id}: {r.state} ({r.n})`)
		end
	end
	local left = 0
	if test then
		left = math.max(0, if c.phase == "signup" then (test :: Test).closesAt - now else c.startAt - now)
	else
		left = math.max(0, Tourney.phaseEnds(c.phase, c.startAt) - now)
	end
	return {
		id = c.id,
		mode = mode or "-",
		phase = c.phase,
		left = left,
		counts = table.concat(counts, ", "),
		lock = if mode == "global" then Store.lockHolder(mode, c.id) or "-" else "-",
		servers = if #servers > 0 then table.concat(servers, ", ") else "-",
		server = ServerMode.get(),
		test = c.test,
	}
end

-- A local test tournament on this server: signups open for `seconds`, then the invitations and the bracket here.
function TourneyService.AdminOpen(seconds: number): (boolean, string?)
	if not ServerMode.isWorld() then
		return false, "tourney.error.notWorld"
	end
	if test ~= nil or next(runners) ~= nil then
		return false, "admin.tourney.busy"
	end
	local now = Clock.now()
	-- H: the test never touches the real tournament (its signups, messages, rechecks and announcements)
	if (Tourney.phaseAt(now)) ~= "idle" or currentNow(now).phase ~= "idle" then
		return false, "admin.tourney.real"
	end
	local id = `test_{os.time()}`
	test = { id = id, phase = "signup", closesAt = now + seconds, startAt = now + seconds + RULES.window.invite }
	modes[id] = "local"
	step()
	return true, id
end

-- S131: a real tournament on every server, `minutes` from now (signups open at once, the usual close, organizer and
-- start offsets). Refused next to a scheduled or another forced tournament and during a test one. Returns its id.
function TourneyService.AdminForce(minutes: number): (boolean, string?)
	if not ServerMode.isWorld() then
		return false, "tourney.error.notWorld"
	end
	if not Tourney.forceMinutesOk(minutes) then
		return false, "admin.tourney.forceMinutes"
	end
	if test ~= nil or next(runners) ~= nil then
		return false, "admin.tourney.busy"
	end
	local now = Clock.now()
	local startAt = Tourney.forceStart(now, minutes)
	local ends = Tourney.times(startAt).ends
	-- the next scheduled tournament must open after the forced one ends; nothing may run now
	local nextStart = Tourney.startAt(now)
	if currentNow(now).phase ~= "idle" or (nextStart > 0 and Tourney.times(nextStart).open < ends) then
		return false, "admin.tourney.real"
	end
	local id = Tourney.forcedId(startAt)
	Bus.publish({ op = "force", id = id, b = "", t = startAt }, true)
	return true, id
end

-- S131 (/sched): the forced tournament known here until its end.
function TourneyService.Forced(): { id: string, startAt: number }?
	local f = forced
	return if f and Clock.now() < Tourney.times(f.startAt).ends then f else nil
end

local function needTest(): Test?
	return test
end

function TourneyService.AdminClose(): (boolean, number)
	local t = needTest()
	if not t or t.phase ~= "signup" then
		return false, 0
	end
	t.closesAt = Clock.now()
	t.phase = "inviting"
	t.startAt = Clock.now() + RULES.window.invite
	local c = currentNow(Clock.now())
	current = c
	local n = inviteLocal(c)
	return true, n
end

function TourneyService.AdminStart(): (boolean, number)
	local t = needTest()
	if not t or t.phase == "running" then
		return false, 0
	end
	if t.phase == "signup" then
		TourneyService.AdminClose()
	end
	t.phase = "running"
	t.startAt = Clock.now()
	local c = currentNow(Clock.now())
	current = c
	-- the invited who did not answer yet count as accepted (a test with the admin's own accounts)
	local list = accepted[c.id] or {}
	for player, inv in table.clone(invites) do
		local key = keyOf(player)
		if inv.id == c.id and key then
			list[key] = true
			invites[player] = nil
		end
	end
	accepted[c.id] = list
	local n = startLocal(c)
	publishAll()
	return true, n
end

function TourneyService.AdminCancel(): boolean
	local t = needTest()
	if not t then
		return false
	end
	for _, r in table.clone(runners) do
		r.Stop()
	end
	runners = {}
	for _, player in Players:GetPlayers() do
		local char = character(player)
		local signed = if char then stateOf(char).signed else nil
		if signed and signed.id == t.id then
			setSigned(player, nil)
		end
		invites[player] = nil
	end
	accepted[t.id] = nil
	test = nil
	releaseSand()
	step()
	publishAll()
	return true
end

-- Ends `target`'s match of a test tournament with its win.
function TourneyService.AdminWin(target: Player): (boolean, string?)
	if test == nil then
		return false, "admin.tourney.noTest"
	end
	for _, r in runners do
		if r.AdminWin(target) then
			return true, nil
		end
	end
	return false, "admin.tourney.noMatch"
end

function TourneyService.HasTest(): boolean
	return test ~= nil
end

-- Lifecycle ---------------------------------------------------------------------------------------------------------

function TourneyService.Init(registry)
	Registry = registry
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	DataService = registry.Get("DataService")
	AnnounceService = registry.Get("AnnounceService")
	ArenaService = registry.Get("ArenaService")
	MailService = registry.Get("MailService")
	TravelService = registry.Get("TravelService")
	WorldService = registry.Get("WorldService")
	PvpService = registry.Get("PvpService")
	Hall.init(DataService.HasDataStoreAccess)
end

function TourneyService.Start()
	-- S122 Logic/UseBlocks: no Elixir of Wholeness in a bracket or on a tournament server
	UseGuards.register("tourney", function(player)
		return TourneyService.InTourney(player)
	end, "TourneyService")
	-- a player of a local bracket stays out of the ranked queue (its match would wait for the sand the tournament holds)
	ArenaService.AddQueueGuard(function(player: Player): string?
		for _, r in runners do
			if r.InTourney(player) then
				return "tourney.error.inBracket"
			end
		end
		return nil
	end)

	Net.Handle("TourneySignup", function(player: Player, sign: boolean): (boolean, string?)
		if busy[player] then
			return false, "error.busy"
		end
		local t = os.clock()
		if t - (lastCall[player] or -math.huge) < CFG.signupCooldown then
			return false, "error.busy"
		end
		lastCall[player] = t
		busy[player] = true
		local ok, result, err = pcall(signup, player, sign)
		busy[player] = nil
		if not ok then
			log:error("tournament signup failed for %s: %s", player.Name, tostring(result))
			return false, "tourney.error.service"
		end
		return result, err
	end)
	Net.Handle("TourneyRespond", function(player: Player, accept: boolean): (boolean, string?)
		if busy[player] then
			return false, "error.busy"
		end
		busy[player] = true
		local ok, result, err = pcall(respond, player, accept)
		busy[player] = nil
		if not ok then
			log:error("tournament answer failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, err
	end)
	Net.Handle("TourneyLeave", function(player: Player): (boolean, string?)
		local key = keyOf(player)
		local r = if key then runnerOf(key) else nil
		if r then
			r.Withdraw(player)
		end
		if ServerMode.get() == "tournament" then
			homeOf(player, "tourney.left")
			return true, nil
		end
		return r ~= nil, if r then nil else "tourney.error.notSigned"
	end)
	Net.Handle("TourneyInfo", function(player: Player): (boolean, any)
		local ok, result, data = pcall(info, player)
		if not ok then
			log:warn("tournament info failed for %s: %s", player.Name, tostring(result))
			return false, "error.internal"
		end
		return result, data
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player, char: Types.CharacterData)
		lastSent[player] = nil
		local state = stateOf(char)
		if ServerMode.isWorld() and state.signed and Tourney.isStale(state.signed, Clock.now(), forced) then
			local signed = state.signed :: { id: string, bracket: string }
			local t = test
			if not (t and signed.id == t.id) then
				setSigned(player, nil)
			end
		end
		local key = keyOf(player)
		if key then
			charIds[key] = char.id
		end
		-- D7: signed on another server; the record of its bracket may be known here already
		local c = cur()
		local signed = stateOf(char).signed
		if signed and signed.id == c.id and c.phase == "inviting" then
			local record = records[`{c.id}_{signed.bracket}`]
			if record then
				task.spawn(applyRecord, c.id, signed.bracket, record)
			end
		end
		publish(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		invites[player] = nil
		lastSent[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "tourney" }, nil)
		end
	end)
	PlayerStateService.Ready:Connect(function(player: Player)
		lastSent[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		invites[player] = nil
		busy[player] = nil
		lastCall[player] = nil
		lastSent[player] = nil
		joinData[player] = nil
	end)

	if ServerMode.get() == "tournament" then
		startHost()
		return
	end
	if not ServerMode.isWorld() then
		return -- an arena server: nothing of the tournament here (the window says "world servers only")
	end

	task.spawn(function()
		-- the bus only when the stores answer (Studio and a failed probe: messages stay here)
		local online = Store.probe()
		Bus.start(onMessage, online)
	end)
	-- the Hall of Fame board and statues in the city
	task.spawn(function()
		while true do
			local ok, champions = pcall(Hall.read, Clock.now(), true)
			if ok then
				refreshBoards(champions)
			end
			task.wait(CFG.hallRefresh)
		end
	end)
	CollectionService:GetInstanceAddedSignal("TourneyFameBoard"):Connect(function(part)
		if hallJson then
			part:SetAttribute("Hall", hallJson)
		end
	end)

	lastStep = 0
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

return TourneyService
