--!strict
-- Ranked arena (S126, DESIGN-17 §6): the queue of this server, match offers with a ready check, ranked 1v1 matches on
-- the Ristalle sand, Elo ratings with monthly seasons and the arena board of LeaderboardService. Friendly duels stay in
-- DuelService (they share the sand through Arena/Sand). The pieces (src/server/Arena):
--   * pair sources (Arena/Types.PairSource): S126 Arena/LocalQueue; S127 puts a global Matchmaker in front (AddSource);
--   * hosts (Arena/Types.Host): S126 "local" = Arena/LocalHost (the sand); S127 "remote" (SetHost) and RunMatch on an
--     arena server;
--   * Arena/Match: one match, from the spec only; the result goes through ApplyResult (the one writer of
--     character.arena after a match), computed from the ratings snapshotted in the MatchSpec.
-- Other services ask the arena through hooks registered here (PvpService.AddFightRule, ResourceService damage filter,
-- PotionService.AddGuard / Drank, BlessingService.SetSuspended, PartyService.SetAllyOverride, TravelService.AddGuard,
-- UseGuards "arena"); DuelService takes this service lazily. Nothing depends on this service (Util/Loader order).
-- Live state: the runtime branch `arenaLive` ({ queue, penaltyUntil, offer, match }, Types.ArenaLive).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Arena = require(Shared.Data.Arena)
local ArenaRules = require(Shared.Logic.ArenaRules)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local Elo = require(Shared.Logic.Elo)
local Leaderboard = require(Shared.Logic.Leaderboard)
local LocalHost = require(script.Parent.Parent.Arena.LocalHost)
local LocalQueue = require(script.Parent.Parent.Arena.LocalQueue)
local Log = require(Shared.Util.Log)
local Maps = require(Shared.Data.Maps)
local Match = require(script.Parent.Parent.Arena.Match)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Sand = require(script.Parent.Parent.Arena.Sand)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)
local ArenaTypes = require(script.Parent.Parent.Arena.Types)
local UseGuards = require(script.Parent.Parent.UseGuards)
local Venues = require(script.Parent.Parent.Arena.Venues)

local log = Log.new("ArenaService")

local ArenaService = {
	Name = "ArenaService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"ResourceService",
		"StatService",
		"StatusEffectService",
		"EntityService",
		"SkillService",
		"PotionService",
		"BlessingService",
		"PartyService",
		"PvpService",
		"ZoneService",
		"WorldService",
		"TravelService",
		"AnnounceService",
		"DuelService",
		"LeaderboardService",
		"DeathService",
	},
	-- (spec, result) after every match with a result (S128 tokens, S130 the bracket)
	MatchFinished = Signal.new(),
	-- (player, summary) when a soft reset closed a season of the character (S128 season rewards)
	SeasonClosed = Signal.new(),
}

local PlayerStateService: any
local CharacterService: any
local ResourceService: any
local StatService: any
local StatusEffectService: any
local EntityService: any
local SkillService: any
local PotionService: any
local BlessingService: any
local PartyService: any
local PvpService: any
local ZoneService: any
local WorldService: any
local TravelService: any
local AnnounceService: any
local DuelService: any
local LeaderboardService: any
local DeathService: any

type Queued = { ticket: ArenaRules.Ticket, source: ArenaTypes.PairSource }
type Offer = {
	id: string,
	spec: ArenaRules.MatchSpec,
	players: { [string]: Player },
	tickets: { [string]: ArenaRules.Ticket },
	accepted: { [string]: boolean },
	expiresAt: number,
	source: ArenaTypes.PairSource,
}

local sources: { ArenaTypes.PairSource } = {}
local hosts: { [string]: ArenaTypes.Host } = {}
local queued: { [Player]: Queued } = {}
local offers: { [string]: Offer } = {}
local offerOf: { [Player]: Offer } = {}
local reserved: { [Player]: string } = {} -- accepted, the match waits for the sand (spec id)
local ticketsOf: { [string]: { [string]: ArenaRules.Ticket } } = {} -- spec id -> tickets to put back on a cancel
local sourceOf: { [string]: ArenaTypes.PairSource } = {}
local matches: { [string]: Match.Match } = {}
local byPlayer: { [Player]: Match.Match } = {}
local penalties: { [string]: number } = {} -- entry key -> server time the queue opens again (memory; S127 MemoryStore)
local saved: { [string]: { [string]: boolean } } = {} -- spec id -> entry keys whose result is written
local lastBoard: { [string]: string } = {} -- entry key -> the arena board written last on this server
local lastWaiting: { [Player]: number } = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

-- The entry key of the active character ("<userId>_<slot>"), nil outside the world.
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

-- The online player of an entry key (the same character still active), nil otherwise.
local function playerOfKey(key: string): Player?
	local userId = Leaderboard.parseKey(key)
	local player = if userId then Players:GetPlayerByUserId(userId) else nil
	if player and keyOf(player) == key then
		return player
	end
	return nil
end

local function mapOf(player: Player): string?
	local zone = ZoneService.GetZone(player)
	if zone then
		return zone.map
	end
	local char = character(player)
	return if char then char.location.map else nil
end

local function inDungeon(player: Player): boolean
	local mapId = mapOf(player)
	local map = if mapId then Maps.get(mapId) else nil
	return map ~= nil and map.biome == "dungeon"
end

local function toast(player: Player, key: string, args: { [string]: any }?, kind: string?)
	if player.Parent then
		Net.Fire(player, "Toast", key, args, kind or "info")
	end
end

local function setLive(player: Player, field: string, value: any)
	if player.Parent and PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "arenaLive", field }, value)
	end
end

-- Seasons ------------------------------------------------------------------------------------------------------------

-- Moves the character's arena state to the season now (saved only when it changed); fires SeasonClosed.
local function ensureSeason(player: Player)
	local char = character(player)
	if not char or type(char.arena) ~= "table" then
		return
	end
	local season = ArenaRules.seasonOf(Clock.now())
	if char.arena.season == season then
		return
	end
	local new, closed = ArenaRules.rollSeason(char.arena, season)
	PlayerStateService.Set(player, { "character", "arena" }, new)
	if closed then
		ArenaService.SeasonClosed:Fire(player, closed)
	end
end

-- Queue ----------------------------------------------------------------------------------------------------------------

local function inQueue(player: Player): boolean
	if queued[player] then
		return true
	end
	local key = keyOf(player)
	if not key then
		return false
	end
	for _, source in sources do
		if source:has(key) then
			return true
		end
	end
	return false
end

local function publishQueue(player: Player)
	local q = queued[player]
	if not q then
		setLive(player, "queue", nil)
		lastWaiting[player] = nil
		return
	end
	local waiting = q.source:waiting(q.ticket.mode, q.ticket.bracket)
	lastWaiting[player] = waiting or -1
	setLive(player, "queue", {
		mode = q.ticket.mode,
		bracket = q.ticket.bracket,
		since = q.ticket.joinedAt,
		scope = q.source.kind,
		waiting = waiting,
	})
end

local function dropQueue(player: Player)
	local key = keyOf(player)
	local q = queued[player]
	queued[player] = nil
	for _, source in sources do
		if key then
			source:leave(key)
		end
		if q then
			source:leave(q.ticket.entrant.key)
		end
	end
	publishQueue(player)
end

local function requeue(player: Player, ticket: ArenaRules.Ticket, source: ArenaTypes.PairSource)
	source:requeue(ticket)
	queued[player] = { ticket = ticket, source = source }
	publishQueue(player)
end

-- What keeps `player` from fighting now: no character, dead, in a dungeon, in a duel or in a running match.
local function fightBlock(player: Player): string?
	local char = character(player)
	if not char then
		return "error.wrongPhase"
	end
	if ResourceService.IsDead(player) then
		return "arena.error.dead"
	elseif inDungeon(player) then
		return "arena.error.dungeon"
	elseif DuelService.InDuel(player) then
		return "arena.error.duel"
	elseif byPlayer[player] then
		return "arena.error.inMatch"
	end
	return nil
end

-- What blocks `player` from a new match (the queue rules without "already queued"): also an accepted match waiting.
local function matchBlock(player: Player): string?
	local reason = fightBlock(player)
	if reason then
		return reason
	end
	return if reserved[player] then "arena.error.inMatch" else nil
end

-- Public API -----------------------------------------------------------------------------------------------------------

function ArenaService.InMatch(player: Player): boolean
	return byPlayer[player] ~= nil
end

function ArenaService.InQueue(player: Player): boolean
	return inQueue(player)
end

-- S126: a match offer waits for the player's answer, or the accepted match waits for the sand.
function ArenaService.HasOffer(player: Player): boolean
	return offerOf[player] ~= nil or reserved[player] ~= nil
end

-- Logic/ArenaRules.canQueue on the player's state (S129 / S130 use it for their blocks).
function ArenaService.BlockedReason(player: Player, mode: string?): string?
	local char = character(player)
	if not char then
		return "error.wrongPhase"
	end
	local key = keyOf(player)
	return ArenaRules.canQueue({
		level = char.level,
		dead = ResourceService.IsDead(player),
		inDungeon = inDungeon(player),
		inDuel = DuelService.InDuel(player),
		inMatch = byPlayer[player] ~= nil or reserved[player] ~= nil,
		queued = inQueue(player),
		offered = offerOf[player] ~= nil,
		penaltyUntil = if key then penalties[key] else nil,
		now = serverNow(),
		mode = mode or Arena.MODE_ORDER[1],
	})
end

-- The character's arena state of the season now (a copy; nil outside the world).
function ArenaService.State(player: Player): Types.ArenaState?
	local char = character(player)
	if not char or type(char.arena) ~= "table" then
		return nil
	end
	return (ArenaRules.rollSeason(char.arena, ArenaRules.seasonOf(Clock.now())))
end

function ArenaService.Join(player: Player, modeId: string): (boolean, string?)
	if type(modeId) ~= "string" then
		return false, "error.badRequest"
	end
	ensureSeason(player)
	local reason = ArenaService.BlockedReason(player, modeId)
	if reason then
		return false, reason
	end
	local char = character(player) :: Types.CharacterData
	local key = keyOf(player) :: string
	local mode = Arena.MODES[modeId]
	local bracket = ArenaRules.bracketOf(char.level) :: string
	local ticket: ArenaRules.Ticket = {
		entrant = {
			key = key,
			userId = player.UserId,
			slot = tonumber(PlayerStateService.Get(player, { "session", "slot" })) or 0,
			name = char.name,
			class = char.class :: string,
			level = char.level,
			rating = ArenaRules.ratingOf(char.arena, mode),
			played = char.arena.played,
		},
		mode = modeId,
		bracket = bracket,
		joinedAt = serverNow(),
	}
	local source = sources[1]
	local ok, err = source:join(ticket)
	if not ok then
		return false, err
	end
	queued[player] = { ticket = ticket, source = source }
	publishQueue(player)
	toast(player, "arena.joined", { mode = modeId }, "success")
	return true, nil
end

function ArenaService.Leave(player: Player)
	dropQueue(player)
end

-- S127: a Matchmaker goes in front of the local queue (Join uses the first source; pairs come from all of them).
function ArenaService.AddSource(source: ArenaTypes.PairSource)
	table.insert(sources, 1, source)
end

-- S127: "remote" (a reserved arena server).
function ArenaService.SetHost(kind: string, host: ArenaTypes.Host)
	hosts[kind] = host
end

-- Results -----------------------------------------------------------------------------------------------------------

local function sideOfKey(spec: ArenaRules.MatchSpec, key: string): number?
	for side, list in spec.sides do
		for _, entrant in list do
			if entrant.key == key then
				return side
			end
		end
	end
	return nil
end

local function bracketText(bracket: string): string
	local b = Arena.bracket(bracket)
	return if b then `{b.min}–{b.max}` else bracket
end

-- The arena board entry of a rated result (DESIGN-17 §6): this season's board of the character's bracket; the entry
-- of another bracket of the season goes (a level-up from 39 to 40), at most once per bracket change on this server.
local function submitBoard(player: Player, char: Types.CharacterData, key: string, mode: Arena.Mode, rating: number)
	if Leaderboard.excluded(player.UserId, char, Config.AdminUserIds, Config.Leaderboard) then
		return
	end
	local bracket = ArenaRules.bracketOf(char.level)
	if not bracket then
		return
	end
	local season = ArenaRules.seasonOf(Clock.now())
	local id = ArenaRules.boardId(mode, season, bracket)
	if lastBoard[key] ~= id then
		for _, b in Arena.BRACKETS do
			if b.id ~= bracket then
				LeaderboardService.Remove(ArenaRules.boardId(mode, season, b.id), key)
			end
		end
		lastBoard[key] = id
	end
	LeaderboardService.Submit(id, key, rating)
end

-- Writes one result for `player` (online, the character of the entry). `forcedScore` = a loss written at a leave.
local function applyFor(
	player: Player,
	spec: ArenaRules.MatchSpec,
	result: ArenaRules.MatchResult,
	forcedScore: number?
): { delta: number, rated: boolean }?
	local char = character(player)
	local key = keyOf(player)
	local mode = Arena.mode(spec.mode)
	if not char or not key or not mode or type(char.arena) ~= "table" then
		return nil
	end
	local side = sideOfKey(spec, key)
	if not side then
		return nil
	end
	local done = saved[spec.id] or {}
	saved[spec.id] = done
	if done[key] then
		return nil
	end
	done[key] = true
	ensureSeason(player)
	char = character(player) :: Types.CharacterData
	local oppKeys, oppRatings = {}, {}
	local oppName, oppClass = "", ""
	for s, list in spec.sides do
		if s ~= side then
			for _, entrant in list do
				table.insert(oppKeys, entrant.key)
				table.insert(oppRatings, entrant.rating)
				if oppName == "" then
					oppName, oppClass = entrant.name, entrant.class
				end
			end
		end
	end
	local score = forcedScore or ArenaRules.scoreOf(result, side)
	local now = Clock.now()
	local new, info = ArenaRules.applyResult(char.arena, {
		mode = mode,
		season = ArenaRules.seasonOf(now),
		day = Time.dayNumber(now),
		now = now,
		myKey = key,
		oppKeys = oppKeys,
		oppRating = Elo.sideRating(oppRatings),
		oppName = oppName,
		oppClass = oppClass,
		score = score,
		rounds = ArenaRules.roundsText(result.score, side),
		rated = spec.rated and not spec.unrated[key] and result.reason ~= "aborted",
	})
	PlayerStateService.Set(player, { "character", "arena" }, new)
	if info.rated then
		submitBoard(player, char, key, mode, ArenaRules.ratingOf(new, mode))
	end
	-- the daily and weekly duel objectives count ranked matches too (DECYZJE S126)
	QuestEvents.fire(player, "duel", { won = score >= 1 })
	local delta = if info.delta > 0 then `+{info.delta}` else tostring(info.delta)
	if not info.rated then
		toast(player, "arena.result.unrated", nil, "info")
	elseif score >= 1 then
		toast(player, "arena.result.win", { delta = delta }, "success")
	elseif score <= 0 then
		toast(player, "arena.result.loss", { delta = delta }, "warning")
	else
		toast(player, "arena.result.draw", { delta = delta }, "info")
	end
	return info
end

-- The one entry that writes a match into character.arena, the ranking and the history (S127: on the arena server).
function ArenaService.ApplyResult(
	player: Player,
	spec: ArenaRules.MatchSpec,
	result: ArenaRules.MatchResult
): { delta: number, rated: boolean }?
	return applyFor(player, spec, result, nil)
end

local function onFinished(match: Match.Match, result: ArenaRules.MatchResult)
	local spec = match.spec
	if result.reason ~= "aborted" then
		for _, list in spec.sides do
			for _, entrant in list do
				local player = playerOfKey(entrant.key)
				if player then
					applyFor(player, spec, result, nil)
				end
			end
		end
		local names = match:names()
		local winner = result.winner
		if winner and #spec.sides == 2 then
			local loser = 3 - winner
			AnnounceService.Server("arena.announce", {
				winner = table.concat(names[winner], ", "),
				loser = table.concat(names[loser], ", "),
				score = `{result.score[winner]}:{result.score[loser]}`,
				bracket = bracketText(spec.bracket),
			})
		elseif #spec.sides == 2 then
			AnnounceService.Server(
				"arena.announceDraw",
				{ a = table.concat(names[1], ", "), b = table.concat(names[2], ", ") }
			)
		end
	end
	ArenaService.MatchFinished:Fire(spec, result)
end

-- Matches ----------------------------------------------------------------------------------------------------------------

local function matchDeps(): Match.Deps
	return {
		Resource = ResourceService,
		StatusEffect = StatusEffectService,
		Entity = EntityService,
		Skill = SkillService,
		Stat = StatService,
		Blessing = BlessingService,
		Travel = TravelService,
		PlayerState = PlayerStateService,
		Death = DeathService,
		mapOf = mapOf,
		announce = function(player: Player, key: string, args: { [string]: any }?)
			if player.Parent then
				Net.Fire(player, "BossAnnounce", key, args)
			end
		end,
		toast = toast,
	}
end

-- Runs a match on a venue now (the sand of this venue is ours). `onClosed` runs once the fighters were sent back.
local function runOn(spec: ArenaRules.MatchSpec, venueId: string, players: { [string]: Player }, onClosed: (() -> ())?)
	for _, player in players do
		reserved[player] = nil
		setLive(player, "offer", nil)
	end
	local match = Match.new(spec, Venues.get(venueId), matchDeps(), {
		finished = onFinished,
		closed = function(m: Match.Match)
			matches[spec.id] = nil
			saved[spec.id] = nil
			for _, player in m:players() do
				if byPlayer[player] == m then
					byPlayer[player] = nil
				end
			end
			if onClosed then
				onClosed()
			end
		end,
	}, players)
	matches[spec.id] = match
	for _, player in players do
		byPlayer[player] = match
	end
	match:run()
end

local function waitingPanel(spec: ArenaRules.MatchSpec, player: Player, place: number)
	local mode = Arena.mode(spec.mode)
	local key = keyOf(player)
	local names: { { string } } = {}
	for side, list in spec.sides do
		local n = {}
		for _, entrant in list do
			table.insert(n, entrant.name)
		end
		names[side] = n
	end
	setLive(player, "match", {
		id = spec.id,
		mode = spec.mode,
		phase = "waiting",
		round = 0,
		maxRounds = if mode then mode.maxRounds else 0,
		score = table.create(#spec.sides, 0),
		side = if key then sideOfKey(spec, key) or 0 else 0,
		endsAt = nil,
		potionsLeft = if mode then mode.potions else 0,
		names = names,
		queued = place,
	})
end

local function localHost(): ArenaTypes.Host
	return LocalHost.new({
		ready = function(player: Player, key: string): boolean
			if player.Parent == nil or keyOf(player) ~= key or fightBlock(player) ~= nil then
				return false
			end
			-- the start heals and teleports, so it must not rescue anyone from a fight (the duel rule, S14)
			if ResourceService.InCombat(player) then
				toast(player, "arena.error.combat", nil, "warning")
				return false
			end
			return true
		end,
		queued = function(spec: ArenaRules.MatchSpec, players: { [string]: Player }, place: number)
			for _, player in players do
				toast(player, "arena.venueQueued", { n = place }, "info")
				waitingPanel(spec, player, place)
			end
		end,
		run = function(spec: ArenaRules.MatchSpec, players: { [string]: Player }, release: () -> ())
			ticketsOf[spec.id] = nil
			sourceOf[spec.id] = nil
			runOn(spec, spec.venue, players, release)
		end,
		cancelled = function(spec: ArenaRules.MatchSpec, players: { [string]: Player }, missing: { string })
			local tickets = ticketsOf[spec.id] or {}
			local source = sourceOf[spec.id]
			ticketsOf[spec.id] = nil
			sourceOf[spec.id] = nil
			for key, player in players do
				reserved[player] = nil
				setLive(player, "match", nil)
				local ticket = tickets[key]
				if not table.find(missing, key) and ticket and source and keyOf(player) == key then
					requeue(player, ticket, source)
					toast(player, "arena.cancelled", nil, "warning")
				end
			end
		end,
	})
end

-- S127: a match for the players on this server (an arena server); S130 tournaments with rated = false. On the
-- Ristalle venue the match waits for the sand (the local host).
function ArenaService.RunMatch(spec: ArenaRules.MatchSpec, venueId: string): (boolean, string?)
	if not Arena.venue(venueId) or not Arena.mode(spec.mode) then
		return false, "error.badRequest"
	end
	local players: { [string]: Player } = {}
	for _, list in spec.sides do
		for _, entrant in list do
			local player = playerOfKey(entrant.key)
			if not player then
				return false, "arena.cancelled"
			end
			if byPlayer[player] then
				return false, "arena.error.inMatch"
			end
			players[entrant.key] = player
		end
	end
	for _, player in players do
		dropQueue(player)
		reserved[player] = spec.id
	end
	if venueId == "ristalle" then
		return hosts["local"]:start(spec, players)
	end
	runOn(spec, venueId, players, nil)
	return true, nil
end

-- Offers -----------------------------------------------------------------------------------------------------------------

local function entrantOf(player: Player, ticket: ArenaRules.Ticket): ArenaRules.Entrant
	-- the rating snapshot of the match: the state now (a match may have ended since the ticket was made)
	local char = character(player)
	local mode = Arena.mode(ticket.mode)
	local e = table.clone(ticket.entrant)
	if char and mode and type(char.arena) == "table" then
		e.rating = ArenaRules.ratingOf(char.arena, mode)
		e.played = char.arena.played
		e.level = char.level
	end
	return e
end

-- A spec from the sides (ratings snapshotted now); `unrated` = the entrants over the same-opponent limit today.
local function buildSpec(
	sides: { { ArenaRules.Entrant } },
	mode: string,
	bracket: string,
	origin: string,
	rated: boolean
): ArenaRules.MatchSpec
	local now = Clock.now()
	local day = Time.dayNumber(now)
	local unrated: { [string]: boolean } = {}
	for side, list in sides do
		for _, entrant in list do
			local player = playerOfKey(entrant.key)
			local state = if player then ArenaService.State(player) else nil
			if state then
				for other, olist in sides do
					if other ~= side then
						for _, opp in olist do
							if not ArenaRules.isRated(state, opp.key, day) then
								unrated[entrant.key] = true
							end
						end
					end
				end
			end
		end
	end
	return {
		id = HttpService:GenerateGUID(false),
		mode = mode,
		bracket = bracket,
		season = ArenaRules.seasonOf(now),
		rated = rated,
		unrated = unrated,
		sides = sides,
		venue = "ristalle",
		origin = origin,
		createdAt = now,
	}
end

local function offerView(offer: Offer, player: Player): { [string]: any }?
	local key = keyOf(player)
	if not key then
		return nil
	end
	local side = sideOfKey(offer.spec, key)
	local opp: ArenaRules.Entrant? = nil
	for s, list in offer.spec.sides do
		if s ~= side and list[1] then
			opp = list[1]
			break
		end
	end
	if not opp then
		return nil
	end
	local o = opp :: ArenaRules.Entrant
	local state = ArenaService.State(player)
	return {
		id = offer.id,
		expiresAt = offer.expiresAt,
		accepted = offer.accepted[key] == true,
		mode = offer.spec.mode,
		unrated = offer.spec.unrated[key] == true,
		vs = if state then ArenaRules.vsCount(state, o.key, Time.dayNumber(Clock.now())) else 0,
		opp = { name = o.name, class = o.class, level = o.level, rating = o.rating },
	}
end

local function closeOffer(offer: Offer)
	offers[offer.id] = nil
	for _, player in offer.players do
		if offerOf[player] == offer then
			offerOf[player] = nil
		end
		setLive(player, "offer", nil)
	end
end

-- Ends an offer: `declined` keys get the queue penalty, the others go back to their place (unless gone).
local function failOffer(offer: Offer, declined: { [string]: boolean }, gone: { [string]: boolean })
	closeOffer(offer)
	local now = serverNow()
	for key, player in offer.players do
		if declined[key] then
			local untilAt = now + Arena.QUEUE.declinePenalty
			penalties[key] = untilAt
			setLive(player, "penaltyUntil", untilAt)
			toast(player, "arena.penalty", { time = Time.format(Arena.QUEUE.declinePenalty) }, "warning")
		elseif not gone[key] and keyOf(player) == key then
			requeue(player, offer.tickets[key], offer.source)
			toast(player, "arena.oppDeclined", nil, "info")
		end
	end
end

local function startOffer(offer: Offer)
	closeOffer(offer)
	for _, player in offer.players do
		reserved[player] = offer.spec.id
	end
	ticketsOf[offer.spec.id] = offer.tickets
	sourceOf[offer.spec.id] = offer.source
	local host = hosts["local"]
	local ok, err = host:start(offer.spec, offer.players)
	if not ok then
		log:warn("match %s did not start: %s", offer.spec.id, tostring(err))
		for _, player in offer.players do
			reserved[player] = nil
			setLive(player, "match", nil)
		end
	end
end

local function makeOffer(pairing: ArenaRules.Pairing, source: ArenaTypes.PairSource)
	local players: { [string]: Player } = {}
	local tickets: { [string]: ArenaRules.Ticket } = {}
	local blocked: { [string]: string } = {}
	local any = false
	for _, list in pairing.sides do
		for _, ticket in list do
			local key = ticket.entrant.key
			tickets[key] = ticket
			local player = playerOfKey(key)
			if not player then
				blocked[key] = "gone"
				any = true
			else
				players[key] = player
				local reason = matchBlock(player)
				if reason then
					blocked[key] = reason
					any = true
				end
			end
		end
	end
	if any then
		-- the blocked ones drop out of the queue; the others keep their place
		for key, ticket in tickets do
			local player = players[key]
			if blocked[key] then
				if player then
					queued[player] = nil
					publishQueue(player)
					if blocked[key] ~= "gone" then
						toast(player, blocked[key], nil, "warning")
					end
				end
			elseif player then
				requeue(player, ticket, source)
			end
		end
		return
	end
	local sides: { { ArenaRules.Entrant } } = {}
	for side, list in pairing.sides do
		local entrants = {}
		for _, ticket in list do
			table.insert(entrants, entrantOf(players[ticket.entrant.key], ticket))
		end
		sides[side] = entrants
	end
	local spec = buildSpec(sides, pairing.mode, pairing.bracket, "local", true)
	local offer: Offer = {
		id = spec.id,
		spec = spec,
		players = players,
		tickets = tickets,
		accepted = {},
		expiresAt = serverNow() + Arena.QUEUE.acceptSeconds,
		source = source,
	}
	offers[offer.id] = offer
	for _, player in players do
		queued[player] = nil
		publishQueue(player)
		offerOf[player] = offer
		setLive(player, "offer", offerView(offer, player))
	end
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local offer = offerOf[player]
	local key = keyOf(player)
	if not offer or not key or serverNow() > offer.expiresAt then
		return false, "arena.error.offer"
	end
	if not accept then
		failOffer(offer, { [key] = true }, {})
		return true, nil
	end
	if ResourceService.InCombat(player) then
		return false, "arena.error.combat"
	end
	local reason = matchBlock(player)
	if reason then
		return false, reason
	end
	offer.accepted[key] = true
	setLive(player, "offer", offerView(offer, player))
	for k in offer.players do
		if not offer.accepted[k] then
			return true, nil
		end
	end
	startOffer(offer)
	return true, nil
end

-- The queue tick ---------------------------------------------------------------------------------------------------------

local function queueTick()
	local now = serverNow()
	for _, offer in table.clone(offers) do
		if now > offer.expiresAt then
			local silent: { [string]: boolean } = {}
			for key in offer.players do
				if not offer.accepted[key] then
					silent[key] = true
				end
			end
			failOffer(offer, silent, {})
		end
	end
	for _, source in table.clone(sources) do
		for _, pairing in source:take(now) do
			makeOffer(pairing, source)
		end
	end
	for player, q in queued do
		local waiting = q.source:waiting(q.ticket.mode, q.ticket.bracket)
		if (waiting or -1) ~= lastWaiting[player] then
			publishQueue(player)
		end
	end
	for key, untilAt in penalties do
		if untilAt <= now then
			penalties[key] = nil
			local player = playerOfKey(key)
			if player then
				setLive(player, "penaltyUntil", nil)
			end
		end
	end
end

-- Spectating and status ---------------------------------------------------------------------------------------------

local seat = 0

local function sandFight(): (string?, { string }?)
	for _, match in matches do
		if match.venue.id == "ristalle" and match.phase ~= "done" then
			local names = match:names()
			local flat = {}
			for _, list in names do
				table.insert(flat, table.concat(list, ", "))
			end
			return "arena", flat
		end
	end
	local duel = DuelService.Fighters()
	if duel then
		return "duel", duel
	end
	return nil, nil
end

local function spectate(player: Player): (boolean, string?)
	if not character(player) then
		return false, "error.wrongPhase"
	end
	if byPlayer[player] or reserved[player] or DuelService.InDuel(player) then
		return false, "arena.error.inMatch"
	end
	if inDungeon(player) then
		return false, "arena.error.dungeon"
	end
	if ResourceService.IsDead(player) then
		return false, "arena.error.dead"
	end
	if ResourceService.InCombat(player) then
		return false, "arena.error.combat"
	end
	if sandFight() == nil then
		return false, "arena.error.nothing"
	end
	seat += 1
	local venue = Venues.get("ristalle")
	task.spawn(TravelService.TeleportToMap, player, venue.map, venue:standCFrame(seat))
	return true, nil
end

local function status(_player: Player): (boolean, any)
	local waiting: { [string]: number } = {}
	local home = sources[#sources] -- the local queue stays last (S127 sources go in front)
	for _, b in Arena.BRACKETS do
		waiting[b.id] = home:waiting(Arena.MODE_ORDER[1], b.id) or 0
	end
	local kind, names = sandFight()
	return true,
		{
			scope = sources[1].kind,
			waiting = waiting,
			busy = if kind then { kind = kind, names = names } else nil,
			pending = Sand.waiting(),
		}
end

-- Admin (/arena) ----------------------------------------------------------------------------------------------------------

function ArenaService.AdminSetRating(player: Player, rating: number): boolean
	ensureSeason(player)
	local char = character(player)
	local key = keyOf(player)
	if not char or not key then
		return false
	end
	local new = ArenaRules.copy(char.arena)
	new.rating = math.clamp(math.floor(rating), 0, 5000)
	new.peak = math.max(new.peak, new.rating)
	PlayerStateService.Set(player, { "character", "arena" }, new)
	submitBoard(player, char, key, Arena.MODES[Arena.MODE_ORDER[1]], new.rating)
	return true
end

function ArenaService.AdminReset(player: Player): boolean
	if not character(player) then
		return false
	end
	local fresh = ArenaRules.emptyState()
	fresh.season = ArenaRules.seasonOf(Clock.now())
	PlayerStateService.Set(player, { "character", "arena" }, fresh)
	return true
end

-- Starts the season again as if a month had passed: the state goes to the season before, then the usual roll.
function ArenaService.AdminSeason(player: Player): (Types.ArenaState?, Types.ArenaSeasonSummary?)
	local char = character(player)
	if not char then
		return nil, nil
	end
	local season = ArenaRules.seasonOf(Clock.now())
	local back = ArenaRules.copy(char.arena)
	back.season = ArenaRules.prevSeason(season)
	local new, closed = ArenaRules.rollSeason(back, season)
	PlayerStateService.Set(player, { "character", "arena" }, new)
	if closed then
		ArenaService.SeasonClosed:Fire(player, closed)
	end
	return new, closed
end

export type QueueLine = { name: string, bracket: string, rating: number, wait: number, window: number }

function ArenaService.AdminQueue(): ({ QueueLine }, string, number)
	local now = serverNow()
	local lines: { QueueLine } = {}
	for _, source in sources do
		for _, t in source:tickets() do
			local wait = math.floor(now - t.joinedAt)
			table.insert(lines, {
				name = t.entrant.name,
				bracket = t.bracket,
				rating = t.entrant.rating,
				wait = wait,
				window = ArenaRules.window(wait),
			})
		end
	end
	local owner = Sand.owner()
	return lines, owner or "", Sand.waiting()
end

-- A rated test match between two players of this server, without the queue and the ready check.
function ArenaService.AdminMatch(admin: Player, target: Player): (boolean, string?)
	if admin == target then
		return false, "error.badRequest"
	end
	local entrants: { ArenaRules.Entrant } = {}
	local players: { [string]: Player } = {}
	local mode = Arena.MODES[Arena.MODE_ORDER[1]]
	for _, player in { admin, target } do
		ensureSeason(player)
		local char = character(player)
		local key = keyOf(player)
		if not char or not key then
			return false, "error.wrongPhase"
		end
		local reason = matchBlock(player)
		if reason then
			return false, reason
		end
		table.insert(entrants, {
			key = key,
			userId = player.UserId,
			slot = tonumber(PlayerStateService.Get(player, { "session", "slot" })) or 0,
			name = char.name,
			class = char.class :: string,
			level = char.level,
			rating = ArenaRules.ratingOf(char.arena, mode),
			played = char.arena.played,
		})
		players[key] = player
	end
	for _, player in players do
		dropQueue(player)
		local offer = offerOf[player]
		if offer then
			-- only the other entrant of that offer goes back to the queue
			failOffer(offer, {}, { [entrants[1].key] = true, [entrants[2].key] = true })
		end
	end
	local bracket = ArenaRules.bracketOf((character(admin) :: Types.CharacterData).level) or Arena.BRACKETS[1].id
	local spec = buildSpec({ { entrants[1] }, { entrants[2] } }, mode.id, bracket, "admin", true)
	for _, player in players do
		reserved[player] = spec.id
	end
	return hosts["local"]:start(spec, players)
end

-- Stops the match of `player` without a rating.
function ArenaService.AdminStop(player: Player): boolean
	local match = byPlayer[player]
	if not match then
		return false
	end
	match:abort("admin")
	return true
end

function ArenaService.Info(player: Player): { [string]: any }?
	local state = ArenaService.State(player)
	if not state then
		return nil
	end
	return {
		rating = state.rating,
		tier = `@arena.tier.{ArenaRules.tierOf(state.rating)}`,
		season = state.season,
		wins = state.wins,
		losses = state.losses,
		played = state.played,
		queued = inQueue(player),
		match = byPlayer[player] ~= nil,
	}
end

-- Lifecycle -------------------------------------------------------------------------------------------------------------

function ArenaService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	ResourceService = registry.Get("ResourceService")
	StatService = registry.Get("StatService")
	StatusEffectService = registry.Get("StatusEffectService")
	EntityService = registry.Get("EntityService")
	SkillService = registry.Get("SkillService")
	PotionService = registry.Get("PotionService")
	BlessingService = registry.Get("BlessingService")
	PartyService = registry.Get("PartyService")
	PvpService = registry.Get("PvpService")
	ZoneService = registry.Get("ZoneService")
	WorldService = registry.Get("WorldService")
	TravelService = registry.Get("TravelService")
	AnnounceService = registry.Get("AnnounceService")
	DuelService = registry.Get("DuelService")
	LeaderboardService = registry.Get("LeaderboardService")
	DeathService = registry.Get("DeathService")

	sources = { LocalQueue.new() }
	hosts = { ["local"] = localHost() }
	Venues.init({ ground = WorldService.GroundCFrame, mapOf = mapOf })

	-- Fighters of a match hit each other only in the fight; nobody else hits them, they hit nobody else.
	PvpService.AddFightRule(function(attacker: Player, target: Player): string?
		local match = byPlayer[attacker] or byPlayer[target]
		return if match then match:rule(attacker, target) else nil
	end)
	-- A blow that would kill a fighter leaves 1 HP and downs it (after shields and reductions, like the duel).
	ResourceService.SetDamageFilter(function(player: Player, amount: number, _source: string, _attacker: any?): number
		local match = byPlayer[player]
		if not match then
			return amount
		end
		local hp = ResourceService.Get(player)
		return match:lethal(player, amount, hp)
	end, ResourceService.FilterPriority.arena)
	-- Ordinary potions: Data/Arena MODES.potions per match (the Elixir of Wholeness: UseGuards "arena" in Start).
	PotionService.AddGuard(function(player: Player, _def: any): string?
		local match = byPlayer[player]
		if match and match:potionsLeft(player) <= 0 then
			return "arena.error.potions"
		end
		return nil
	end)
	-- Help only within the own side of the match.
	PartyService.SetAllyOverride(function(player: Player): { Player }?
		local match = byPlayer[player]
		return if match then match:allies(player) else nil
	end)
	-- No stones, free returns or portals out of a match.
	TravelService.AddGuard(function(player: Player): string?
		return if byPlayer[player] then "arena.error.travel" else nil
	end)
end

function ArenaService.Start()
	UseGuards.register("arena", function(player)
		return ArenaService.InMatch(player)
	end, "ArenaService") -- S122 Logic/UseBlocks (the Elixir of Wholeness and the Cloak of Luring in a match)

	Net.Handle("ArenaJoin", function(player: Player, mode: string)
		return ArenaService.Join(player, mode)
	end)
	Net.Handle("ArenaLeave", function(player: Player)
		if not inQueue(player) then
			return false, "arena.error.notQueued"
		end
		ArenaService.Leave(player)
		toast(player, "arena.left", nil, "info")
		return true, nil
	end)
	Net.Handle("ArenaRespond", respond)
	Net.Handle("ArenaSpectate", spectate)
	Net.Handle("ArenaStatus", status)

	PotionService.Drank:Connect(function(player: Player)
		local match = byPlayer[player]
		if match then
			match:drank(player)
		end
	end)
	ResourceService.Died:Connect(function(player: Player)
		local match = byPlayer[player]
		if match then
			match:died(player)
		end
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		ensureSeason(player)
		local key = keyOf(player)
		local untilAt = if key then penalties[key] else nil
		if untilAt and untilAt > serverNow() then
			setLive(player, "penaltyUntil", untilAt)
		end
	end)

	-- The character data goes away after this event: the loss of a running match is written now, without a yield.
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		local key = keyOf(player)
		dropQueue(player)
		local offer = offerOf[player]
		if offer and key then
			-- leaving the game is not a refusal: no penalty, the others go back to the queue
			failOffer(offer, {}, { [key] = true })
		end
		reserved[player] = nil
		local match = byPlayer[player]
		if match and key and match.phase ~= "done" then
			local spec = match.spec
			local side = sideOfKey(spec, key)
			if side then
				local forfeit: ArenaRules.MatchResult = {
					winner = if #spec.sides == 2 then 3 - side else nil,
					score = table.clone(match.score),
					rounds = match.round,
					reason = "forfeit",
					forfeits = { [key] = true },
				}
				local ok, err = pcall(function()
					applyFor(player, spec, forfeit, 0)
				end)
				if not ok then
					log:error("arena loss on leave failed for %s: %s", player.Name, tostring(err))
				end
			end
			match:leave(player)
		end
		byPlayer[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "arenaLive" }, nil)
		end
	end)

	-- Deferred: CharacterLeaving (DataService release, also on PlayerRemoving) still needs the offer and the match.
	Players.PlayerRemoving:Connect(function(player: Player)
		task.defer(function()
			queued[player] = nil
			local offer = offerOf[player]
			if offer then
				for key, p in offer.players do
					if p == player then
						-- leaving the game is not a refusal (DECYZJE S126)
						failOffer(offer, {}, { [key] = true })
						break
					end
				end
			end
			offerOf[player] = nil
			reserved[player] = nil
			lastWaiting[player] = nil
			local match = byPlayer[player]
			if match then
				match:leave(player)
				byPlayer[player] = nil
			end
		end)
	end)

	-- Entering a dungeon takes a player off the queue.
	ZoneService.ZoneChanged:Connect(function(player: Player, zone: Types.ZoneState)
		local map = Maps.get(zone.map)
		if map and map.biome == "dungeon" and inQueue(player) then
			dropQueue(player)
			toast(player, "arena.queueLeft.dungeon", nil, "warning")
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Arena.QUEUE.tick)
			local ok, err = pcall(function()
				queueTick()
			end)
			if not ok then
				log:error("arena tick failed: %s", tostring(err))
			end
		end
	end)
end

return ArenaService
