--!strict
-- One bracket of the Champion's Tournament being fought (S130, DESIGN-17 §8), on whatever server: a tournament server
-- (one Runner, its bracket, four fields pit_1 .. pit_4) or a world server in the local mode (one Runner per bracket,
-- one shared field: the Ristalle, held by the tournament for its whole length). A plain module: TourneyService hands
-- in everything (the players present at the start, the field pool, ArenaService's entries, the callbacks).
--   * seeding: Logic/Tourney.seedOrder of the present players -> Logic/Bracket.new; fewer than Data/Arena.TOURNEY
--     .minPlayers -> cancelled (tourney.cancelledFew), no rewards;
--   * every TICK s: players gone (and not in a running match) withdraw (Bracket.withdraw: walkovers); every ready
--     match whose two players rested TOURNEY.restBetween s and are free to fight gets a free field and is played by
--     ArenaService.RunMatch (S126 rules, origin "tournament", rated = false); a busy player of the local mode
--     (dungeon, fight) is waited for Config.Tourney.callWait s, then withdrawn;
--   * a result (ArenaService.MatchFinished of our spec): Bracket.report; a draw (or an aborted match) goes to the
--     higher seed (always a winner); the loser's place goes to `onPlace`, the final to `onDone`;
--   * `showed` of a place = seeded and present at the start, except a walkover for being away before any fought match.
-- Handle: InTourney(player), View(), Me(key), Withdraw(player), AdminWin(player), Stop(), Done().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Bracket = require(ReplicatedStorage.Shared.Logic.Bracket)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Tourney = require(ReplicatedStorage.Shared.Logic.Tourney)

local log = Log.new("TourneyRunner")

local TICK = 0.5
local RULES = Arena.TOURNEY

export type PlayerEntry = { player: Player, key: string, rating: number, t: number, name: string, class: string }

-- The fields a runner may take (shared by the runners of a local tournament): venue ids of Data/Arena.VENUES.
export type FieldPool = {
	take: (self: FieldPool) -> string?,
	give: (self: FieldPool, venue: string) -> (),
	number: (self: FieldPool, venue: string) -> number,
}

-- What the runner needs of ArenaService (and of the world).
export type ArenaApi = {
	RunMatch: (
		spec: ArenaRules.MatchSpec,
		venue: string,
		absent: { [string]: boolean }?,
		opts: { direct: boolean?, onClosed: (() -> ())? }?
	) -> (boolean, string?),
	MatchFinished: any, -- Signal (spec, result)
	ForceWin: (player: Player) -> boolean,
	AdminStop: (player: Player) -> boolean,
	CanFight: (player: Player) -> string?,
	InMatch: (player: Player) -> boolean,
}

export type Spec = {
	id: string,
	bracket: string,
	range: string,
	players: { PlayerEntry },
	fields: FieldPool,
	arena: ArenaApi,
	direct: boolean, -- RunMatch on the venue now (the local mode holds the Ristalle)
	waitBusy: boolean, -- the local mode: a busy player is waited for (callWait); a tournament server has none
	online: (key: string) -> Player?, -- the player of the key on this server now (same character)
	entrant: (player: Player, key: string) -> ArenaRules.Entrant?,
	toast: (player: Player, key: string, args: { [string]: any }?, kind: string?) -> (),
	onPlace: (key: string, place: number, showed: boolean, player: Player?) -> (),
	onDone: (championKey: string?, cancelled: boolean) -> (),
	onChange: () -> (),
}

export type Me = { place: number?, field: number?, state: string }

export type Handle = {
	id: string,
	bracket: string,
	range: string,
	InTourney: (player: Player) -> boolean,
	Has: (key: string) -> boolean,
	View: () -> any,
	Me: (key: string) -> Me?,
	Withdraw: (player: Player) -> (),
	AdminWin: (player: Player) -> boolean,
	Stop: () -> (),
	Done: () -> boolean,
	Count: () -> number,
}

type Running = { matchId: number, venue: string, specId: string, a: string, b: string }

local Runner = {}

function Runner.start(spec: Spec): Handle
	local entries: { Tourney.Entry } = {}
	local byKey: { [string]: PlayerEntry } = {}
	for _, p in spec.players do
		if byKey[p.key] == nil then
			byKey[p.key] = p
			table.insert(entries, { key = p.key, rating = p.rating, t = p.t, name = p.name, class = p.class })
		end
	end

	local handle = {} :: any
	handle.id = spec.id
	handle.bracket = spec.bracket
	handle.range = spec.range

	local stopped = false
	local finished = false
	local bracket: Bracket.Bracket? = nil
	local running: { [string]: Running } = {} -- spec id -> the match on a field
	local fought: { [string]: boolean } = {}
	local placed: { [string]: boolean } = {}
	local lastEnd: { [string]: number } = {}
	local busySince: { [string]: number } = {}
	local names: { [string]: string } = {}
	local classes: { [string]: string } = {}
	local connection: any = nil
	for key, p in byKey do
		names[key] = p.name
		classes[key] = p.class
	end

	local function now(): number
		return Workspace:GetServerTimeNow()
	end

	local function runningOf(key: string): Running?
		for _, r in running do
			if r.a == key or r.b == key then
				return r
			end
		end
		return nil
	end

	local function finish(champion: string?, cancelled: boolean)
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		local ok, err = pcall(function()
			spec.onDone(champion, cancelled)
		end)
		if not ok then
			log:error("tournament %s %s: onDone failed: %s", spec.id, spec.bracket, tostring(err))
		end
	end

	-- Places of the newly out (and of the final's winner once it is decided).
	local function placeNew()
		local b = bracket
		if not b then
			return
		end
		for key in byKey do
			if not placed[key] then
				local place = Bracket.placeOf(b, key)
				if place then
					placed[key] = true
					local showed = not (b.absent[key] and not fought[key])
					local player = spec.online(key)
					local ok, err = pcall(function()
						spec.onPlace(key, place, showed, player)
					end)
					if not ok then
						log:error("tournament %s: onPlace %s failed: %s", spec.id, key, tostring(err))
					end
				end
			end
		end
		if Bracket.done(b) then
			finish(Bracket.champion(b), false)
		end
	end

	local function changed()
		placeNew()
		local ok, err = pcall(function()
			spec.onChange()
		end)
		if not ok then
			log:warn("tournament %s: onChange failed: %s", spec.id, tostring(err))
		end
	end

	-- The opponent of a walkover hears of it.
	local function withdraw(key: string)
		local b = bracket
		if not b or b.absent[key] then
			return
		end
		local m = Bracket.matchOf(b, key)
		Bracket.withdraw(b, key)
		if m and m.winner ~= nil then
			local other = if m.a == key then m.b else m.a
			local player = if other then spec.online(other) else nil
			if player then
				spec.toast(player, "tourney.walkover", { name = names[key] or "?" }, "info")
			end
		end
	end

	local function seedOf(key: string): number
		local b = bracket
		return if b then table.find(b.seeds, key) or math.huge else math.huge
	end

	local function onResult(matchSpec: ArenaRules.MatchSpec, result: ArenaRules.MatchResult)
		local r = running[matchSpec.id]
		local b = bracket
		if not r or not b then
			return
		end
		running[matchSpec.id] = nil
		Bracket.setField(b, r.matchId, nil)
		local t = now()
		lastEnd[r.a] = t
		lastEnd[r.b] = t
		if stopped then
			return
		end
		local m = Bracket.get(b, r.matchId)
		if not m or m.winner ~= nil then
			changed()
			return
		end
		local winnerKey: string? = nil
		local side = result.winner
		if side and matchSpec.sides[side] and matchSpec.sides[side][1] then
			winnerKey = matchSpec.sides[side][1].key
		end
		if winnerKey ~= r.a and winnerKey ~= r.b then
			-- a draw or an aborted match: the higher seed goes on (DECYZJE S130: always a winner)
			winnerKey = if seedOf(r.a) <= seedOf(r.b) then r.a else r.b
		end
		local reason: "win" | "walkover" = if result.reason == "forfeit" then "walkover" else "win"
		local winner = winnerKey :: string
		local ok, err = pcall(function()
			Bracket.report(b, r.matchId, winner, reason)
		end)
		if not ok then
			log:error("tournament %s: report of match %d failed: %s", spec.id, r.matchId, tostring(err))
		end
		changed()
	end

	-- Starts the ready matches that have two rested, free players and a free field.
	local function callMatches(): boolean
		local b = bracket
		if not b then
			return false
		end
		local any = false
		local t = now()
		for _, m in Bracket.ready(b) do
			local a, c = m.a :: string, m.b :: string
			local busy = false
			for _, r in running do
				if r.matchId == m.id then
					busy = true
				end
			end
			if busy then
				continue
			end
			if
				t - (lastEnd[a] or -math.huge) < RULES.restBetween
				or t - (lastEnd[c] or -math.huge) < RULES.restBetween
			then
				continue
			end
			local pa, pc = spec.online(a), spec.online(c)
			if not pa or not pc then
				continue -- the gone one withdraws in the next tick
			end
			local blocked = false
			local function check(key: string, player: Player)
				local reason = spec.arena.CanFight(player)
				if reason then
					blocked = true
					if spec.waitBusy then
						local since = busySince[key]
						if since == nil then
							busySince[key] = t
							spec.toast(player, "tourney.error.busy", nil, "warning")
						elseif t - since >= Config.Tourney.callWait then
							busySince[key] = nil
							withdraw(key)
							any = true
						end
					end
				else
					busySince[key] = nil
				end
			end
			check(a, pa)
			check(c, pc)
			if blocked then
				continue
			end
			local venue = spec.fields:take()
			if not venue then
				break -- every field is in use: the rest waits, in the order of rounds
			end
			local ea, ec = spec.entrant(pa, a), spec.entrant(pc, c)
			if not ea or not ec then
				spec.fields:give(venue)
				continue
			end
			local specId = `{spec.id}_{spec.bracket}_{m.id}`
			local matchSpec: ArenaRules.MatchSpec = {
				id = specId,
				mode = "1v1",
				bracket = spec.bracket,
				season = ArenaRules.seasonOf(Clock.now()),
				rated = false,
				unrated = {},
				sides = { { ea }, { ec } },
				venue = venue,
				origin = "tournament",
				createdAt = Clock.now(),
			}
			local field = spec.fields:number(venue)
			running[specId] = { matchId = m.id, venue = venue, specId = specId, a = a, b = c }
			Bracket.setField(b, m.id, field)
			local released = false
			local ok, err = spec.arena.RunMatch(matchSpec, venue, nil, {
				direct = spec.direct,
				onClosed = function()
					if not released then
						released = true
						spec.fields:give(venue)
					end
				end,
			})
			if not ok then
				log:warn("tournament %s: match %d did not start: %s", spec.id, m.id, tostring(err))
				running[specId] = nil
				Bracket.setField(b, m.id, nil)
				if not released then
					released = true
					spec.fields:give(venue)
				end
			else
				fought[a] = true
				fought[c] = true
				spec.toast(pa, "tourney.called", { field = field }, "info")
				spec.toast(pc, "tourney.called", { field = field }, "info")
			end
			any = true
		end
		return any
	end

	local function tick()
		local b = bracket
		if not b or finished then
			return
		end
		local any = false
		for key in byKey do
			if not b.absent[key] and b.eliminated[key] == nil and runningOf(key) == nil and spec.online(key) == nil then
				withdraw(key)
				any = true
			end
		end
		if any then
			changed()
		end
		if not finished and callMatches() then
			changed()
		end
	end

	function handle.InTourney(player: Player): boolean
		local b = bracket
		if not b or finished then
			return false
		end
		for key, p in byKey do
			if p.player == player then
				return b.eliminated[key] == nil and not b.absent[key]
			end
		end
		return false
	end

	function handle.Has(key: string): boolean
		return byKey[key] ~= nil
	end

	function handle.View(): any
		local b = bracket
		if not b then
			return nil
		end
		local view = Bracket.view(b)
		view.names = names
		view.classes = classes
		return view
	end

	function handle.Me(key: string): Me?
		local b = bracket
		if not b or byKey[key] == nil then
			return nil
		end
		local place = Bracket.placeOf(b, key)
		local status = Bracket.status(b, key)
		if status == "champion" then
			return { place = 1, field = nil, state = "champion" }
		elseif status == "out" then
			return { place = place, field = nil, state = "out" }
		end
		local r = runningOf(key)
		if r then
			return { place = nil, field = spec.fields:number(r.venue), state = "fighting" }
		end
		return { place = nil, field = nil, state = "waiting" }
	end

	function handle.Withdraw(player: Player)
		for key, p in byKey do
			if p.player == player then
				local r = runningOf(key)
				if r then
					-- in a match: leaving gives it to the opponent (a walkover)
					local other = if r.a == key then r.b else r.a
					local opponent = spec.online(other)
					if opponent then
						spec.arena.ForceWin(opponent)
					end
				end
				withdraw(key)
				changed()
				return
			end
		end
	end

	function handle.AdminWin(player: Player): boolean
		if not spec.arena.InMatch(player) then
			return false
		end
		for key, p in byKey do
			if p.player == player and runningOf(key) then
				return spec.arena.ForceWin(player)
			end
		end
		return false
	end

	function handle.Stop()
		if stopped then
			return
		end
		stopped = true
		for _, r in table.clone(running) do
			for _, key in { r.a, r.b } do
				local player = spec.online(key)
				if player then
					pcall(spec.arena.AdminStop, player)
				end
			end
		end
		finish(nil, true)
	end

	function handle.Done(): boolean
		return finished
	end

	function handle.Count(): number
		return #entries
	end

	if #entries < RULES.minPlayers then
		for _, p in byKey do
			spec.toast(p.player, "tourney.cancelledFew", nil, "warning")
		end
		task.defer(finish, nil, true)
		return handle :: Handle
	end

	bracket = Bracket.new(Tourney.seedOrder(entries))
	connection = spec.arena.MatchFinished:Connect(function(matchSpec: ArenaRules.MatchSpec, result: any)
		local ok, err = pcall(function()
			onResult(matchSpec, result)
		end)
		if not ok then
			log:error("tournament %s: result failed: %s", spec.id, tostring(err))
		end
	end)
	for _, m in (bracket :: Bracket.Bracket).matches do
		local p = if m.round == 1 and m.reason == "bye" and m.winner then byKey[m.winner] else nil
		if p then
			spec.toast(p.player, "tourney.bye", nil, "info")
		end
	end
	task.spawn(function()
		changed()
		while not finished and not stopped do
			local ok, err = pcall(function()
				tick()
			end)
			if not ok then
				log:error("tournament %s %s: tick failed: %s", spec.id, spec.bracket, tostring(err))
			end
			task.wait(TICK)
		end
	end)
	log:info("tournament %s bracket %s: %d players", spec.id, spec.bracket, #entries)
	return handle :: Handle
end

return Runner
