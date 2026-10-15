--!strict
-- One ranked match (S126, DESIGN-17 §6), whatever source paired it and wherever it is played: rounds, the fight rule,
-- the knockout, potions of the match, spectators off the sand, the result. Services come in `deps` (ArenaService
-- hands them in), so the module requires no service. The code walks sides and fighters (`for side, list in
-- spec.sides`), never "a" and "b": S128 3v3 is a new Data/Arena mode with three fighters a side.
--   1. before the first round: the way back of every fighter, blessings suspended, the match potions;
--   2. a round: revive and restore, effects cleared (the respawn shield too), cooldowns reset, a teleport to the
--      fighter's spot, "Round n of m", the countdown, then the fight until the round time;
--   3. every WATCH s: a fighter who stepped off the sand loses the round ("left"), a knockout (`lethal`) downs a
--      fighter (1v1: the round ends), the end of time compares %HP (Logic/ArenaRules.roundOutcome); a real death (a
--      reset, the void) downs the fighter too and DeathService.Recall brings it back on its spot at once;
--   4. after a round: the winner announced, the score, Logic/ArenaRules.matchOutcome; else a break and the next round;
--   5. the end: hooks.finished (ArenaService writes ratings), blessings back, everyone restored, after BACK_DELAY s a
--      teleport to the spot before the match, then hooks.closed (the host frees the venue).
-- Leaving the game (or switching characters) during a match: `leave` - the side whose fighters all left loses.
-- S128 (3v3, teamSize > 1): a knocked out fighter stays down for the round with 1 HP, leaves the sand for the bench of
-- its side (VENUES.bench, a stand seat), cannot fight or cast (ArenaService.IsSidelined) and watches; the HUD panel of
-- the teams (`teams`, `myTeam` in the snapshot) refreshes every TEAM_PUBLISH s while the round runs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Venues = require(script.Parent.Venues)

local log = Log.new("ArenaMatch")

local WATCH = 0.25
local SETTLE = 1.5 -- s after the teleport before "Round n of m"
local TELEPORT_WAIT = 8 -- s at most for the round teleports
local BACK_DELAY = 2 -- s after the end before the way back
local SPECTATOR_GAP = 3 -- s between two moves of the same spectator
local TEAM_PUBLISH = 0.5 -- s between two team panel updates (S128: at most 4 a second by the contract)

export type Deps = {
	Resource: any,
	StatusEffect: any,
	Entity: any,
	Skill: any,
	Stat: any,
	Blessing: any,
	Travel: any,
	PlayerState: any,
	Death: any,
	mapOf: (player: Player) -> string?,
	announce: (player: Player, key: string, args: { [string]: any }?) -> (),
	toast: (player: Player, key: string, args: { [string]: any }?, kind: string?) -> (),
}

export type Hooks = {
	finished: (match: Match, result: ArenaRules.MatchResult) -> (),
	closed: (match: Match) -> (),
}

type FighterState = {
	key: string,
	side: number,
	index: number,
	player: Player,
	name: string,
	class: string, -- S128: the team panel
	down: boolean,
	out: boolean, -- stepped off the sand this round
	gone: boolean, -- left the game / switched characters
	seen: boolean, -- stood on the sand during this fight phase (the teleport arrived)
	potions: number,
	back: { map: string, at: CFrame }?,
}

export type Phase = "waiting" | "countdown" | "fight" | "between" | "done"

export type Match = {
	spec: ArenaRules.MatchSpec,
	mode: Arena.Mode,
	venue: Venues.Venue,
	phase: Phase,
	round: number,
	score: { number },
	endsAt: number?,
	result: ArenaRules.MatchResult?,
	run: (self: Match) -> (),
	abort: (self: Match, reason: string) -> (),
	sideOf: (self: Match, player: Player) -> number?,
	isFighter: (self: Match, player: Player) -> boolean,
	keyOf: (self: Match, player: Player) -> string?,
	rule: (self: Match, attacker: Player, target: Player) -> string?,
	allies: (self: Match, player: Player) -> { Player }?,
	lethal: (self: Match, player: Player, amount: number, hp: number) -> number,
	died: (self: Match, player: Player) -> (),
	leave: (self: Match, player: Player) -> (),
	potionsLeft: (self: Match, player: Player) -> number,
	drank: (self: Match, player: Player) -> (),
	snapshot: (self: Match, player: Player) -> { [string]: any },
	sidelined: (self: Match, player: Player) -> boolean, -- S128: knocked out in a team match, the round still runs
	players: (self: Match) -> { Player },
	names: (self: Match) -> { { string } },
}

local Match = {}

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- `players`: entrant key -> the player (all fighters of the spec are online when the match starts).
function Match.new(
	spec: ArenaRules.MatchSpec,
	venue: Venues.Venue,
	deps: Deps,
	hooks: Hooks,
	players: { [string]: Player }
): Match
	local mode = Arena.mode(spec.mode)
	if not mode then
		error(`Arena/Match: unknown mode {spec.mode}`)
	end
	local fighters: { FighterState } = {}
	local byPlayer: { [Player]: FighterState } = {}
	local score: { number } = {}
	for side, list in spec.sides do
		score[side] = 0
		for index, entrant in list do
			local player = players[entrant.key]
			if player then
				local f: FighterState = {
					key = entrant.key,
					side = side,
					index = index,
					player = player,
					name = entrant.name,
					class = entrant.class,
					down = false,
					out = false,
					gone = false,
					seen = false,
					potions = mode.potions,
					back = nil,
				}
				table.insert(fighters, f)
				byPlayer[player] = f
			end
		end
	end

	local self = {} :: any
	self.spec = spec
	self.mode = mode
	self.venue = venue
	self.phase = "countdown" :: Phase
	self.round = 0
	self.score = score
	self.endsAt = nil :: number?
	self.result = nil :: ArenaRules.MatchResult?

	local team = mode.teamSize > 1 -- S128
	local forfeits: { [string]: boolean } = {}
	local spectatorMoved: { [Player]: number } = {}
	local seat = 0
	local finishing = false

	local function online(f: FighterState): boolean
		return not f.gone
			and f.player.Parent ~= nil
			and deps.PlayerState.HasState(f.player)
			and deps.PlayerState.GetCharacter(f.player) ~= nil
	end

	local function publish()
		for _, f in fighters do
			if online(f) then
				deps.PlayerState.Set(f.player, { "arenaLive", "match" }, self:snapshot(f.player))
			end
		end
	end

	local function announce(key: string, args: { [string]: any }?)
		for _, f in fighters do
			if online(f) then
				deps.announce(f.player, key, args)
			end
		end
	end

	local function sideFighters(side: number): { FighterState }
		local out = {}
		for _, f in fighters do
			if f.side == side then
				table.insert(out, f)
			end
		end
		return out
	end

	local function sideName(side: number): string
		local names = {}
		for _, f in sideFighters(side) do
			table.insert(names, f.name)
		end
		return table.concat(names, ", ")
	end

	-- S128: a fighter knocked out in a team match goes to the bench of its side and everybody hears of it.
	local function bench(f: FighterState)
		deps.toast(f.player, "arena.team.youOut", nil, "warning")
		for _, other in fighters do
			if other ~= f and online(other) then
				deps.toast(other.player, "arena.team.out", { name = f.name }, "info")
			end
		end
		local at = venue:standCFrame(ArenaRules.benchIndex(venue.def, f.side))
		task.spawn(function()
			pcall(deps.Travel.TeleportToMap, f.player, venue.map, at)
		end)
	end

	local function restore(player: Player)
		if player.Parent and deps.PlayerState.HasState(player) and deps.PlayerState.GetCharacter(player) then
			if deps.Resource.IsDead(player) then
				deps.Resource.Revive(player)
			end
			deps.Resource.Restore(player)
		end
	end

	-- Where a fighter goes after the match: the spot before it, or the venue's way out (dungeon, no model).
	local function backOf(player: Player): { map: string, at: CFrame }?
		local mapId = deps.mapOf(player)
		local map = if mapId then Maps.get(mapId) else nil
		local model = player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not mapId or not map or map.biome == "dungeon" or not root then
			return nil
		end
		return { map = mapId, at = root.CFrame }
	end

	local function teleportAll(round: number)
		local left = 0
		for _, f in fighters do
			if online(f) then
				left += 1
				local at = venue:spawnCFrame(f.side, f.index)
				task.spawn(function()
					local ok, err = pcall(deps.Travel.TeleportToMap, f.player, venue.map, at)
					if not ok then
						log:warn("round %d teleport of %s failed: %s", round, f.player.Name, tostring(err))
					end
					left -= 1
				end)
			end
		end
		local waited = 0
		while left > 0 and waited < TELEPORT_WAIT do
			task.wait(WATCH)
			waited += WATCH
		end
	end

	local function prepareRound()
		for _, f in fighters do
			f.down = false
			f.out = false
			f.seen = false
			if online(f) then
				restore(f.player)
				local entity = deps.Entity.GetPlayerEntity(f.player)
				if entity then
					-- every effect goes, the respawn shield and the Fury too (a clean start of every round)
					deps.StatusEffect.Clear(entity)
				end
				deps.Skill.ResetAllCooldowns(f.player)
			end
		end
	end

	local function fighterView(f: FighterState): ArenaRules.Fighter
		local hpPct = 0
		if online(f) and not f.down then
			local hp = deps.Resource.Get(f.player)
			local maxHp = math.max(1, deps.Stat.GetValue(f.player, "maxHp"))
			hpPct = math.clamp(hp / maxHp, 0, 1)
		end
		return { key = f.key, hpPct = hpPct, down = f.down, left = f.out or f.gone }
	end

	local function outcomeNow(timedOut: boolean): ArenaRules.RoundOutcome?
		local sides: { { ArenaRules.Fighter } } = {}
		for side in spec.sides do
			local list = {}
			for _, f in sideFighters(side) do
				table.insert(list, fighterView(f))
			end
			sides[side] = list
		end
		return ArenaRules.roundOutcome(sides, timedOut, mode.tieBreak)
	end

	local function moveSpectators()
		local clock = os.clock()
		for _, player in Players:GetPlayers() do
			if byPlayer[player] and not byPlayer[player].gone then
				continue
			end
			local last = spectatorMoved[player]
			if last and clock - last < SPECTATOR_GAP then
				continue
			end
			if deps.PlayerState.GetCharacter(player) and venue:contains(player) then
				spectatorMoved[player] = clock
				seat += 1
				task.spawn(deps.Travel.TeleportToMap, player, venue.map, venue:standCFrame(seat))
				deps.toast(player, "arena.spectate.moved", nil, "warning")
			end
		end
	end

	local function finish(result: ArenaRules.MatchResult)
		if finishing then
			return
		end
		finishing = true
		result.forfeits = table.clone(forfeits)
		self.result = result
		self.phase = "done"
		self.endsAt = nil
		publish()
		local ok, err = pcall(function()
			hooks.finished(self :: Match, result)
		end)
		if not ok then
			log:error("match %s: finished hook failed: %s", spec.id, tostring(err))
		end
		for _, f in fighters do
			deps.Blessing.SetSuspended(f.player, false)
			if online(f) then
				restore(f.player)
			end
		end
		task.delay(BACK_DELAY, function()
			for _, f in fighters do
				if online(f) then
					local back = f.back
					local mapId = if back then back.map else venue.map
					local at = if back then back.at else venue:exitCFrame()
					task.spawn(function()
						pcall(deps.Travel.TeleportToMap, f.player, mapId, at)
					end)
					deps.PlayerState.Set(f.player, { "arenaLive", "match" }, nil)
				end
			end
			local okClosed, errClosed = pcall(function()
				hooks.closed(self :: Match)
			end)
			if not okClosed then
				log:error("match %s: closed hook failed: %s", spec.id, tostring(errClosed))
			end
		end)
	end

	-- A side all of whose fighters left loses at once (forfeit).
	local function checkForfeit(): boolean
		for side in spec.sides do
			local all = true
			for _, f in sideFighters(side) do
				if not f.gone then
					all = false
				end
			end
			if all then
				local result = ArenaRules.matchOutcome(self.score, self.round, mode, side)
				if result then
					finish(result)
					return true
				end
			end
		end
		return false
	end

	local function pause(seconds: number): boolean
		local t = 0
		while t < seconds do
			if finishing then
				return false
			end
			task.wait(WATCH)
			t += WATCH
			if not finishing then
				moveSpectators() -- the stands stay the stands between rounds and in the countdown too
			end
		end
		return not finishing
	end

	-- One round; returns false when the match ended meanwhile.
	local function playRound(n: number): boolean
		self.round = n
		self.phase = "countdown" :: Phase
		self.endsAt = nil
		prepareRound()
		publish()
		teleportAll(n)
		if not pause(SETTLE) then
			return false
		end
		announce("arena.round", { n = n, of = mode.maxRounds })
		if not pause(1) then
			return false
		end
		for c = mode.countdown, 1, -1 do
			announce("arena.count", { n = c })
			if not pause(1) then
				return false
			end
		end
		self.phase = "fight" :: Phase
		local fightStart = os.clock()
		local lastTeamPublish = fightStart
		self.endsAt = serverNow() + mode.roundTime
		publish()
		announce("arena.fight", nil)
		local outcome: ArenaRules.RoundOutcome? = nil
		while not finishing do
			task.wait(WATCH)
			if finishing then
				return false
			end
			for _, f in fighters do
				if not f.gone and not online(f) then
					self:leave(f.player)
				end
			end
			if finishing then
				return false
			end
			for _, f in fighters do
				if online(f) and not f.down and not f.out then
					if venue:contains(f.player) then
						f.seen = true
					elseif f.seen then
						-- stepped off the sand: the round is lost (DECYZJE S126)
						f.out = true
						if team then
							-- S128 (C6): knocked out and counted as having left (no tokens), sidelined on the bench
							f.down = true
							forfeits[f.key] = true
							bench(f)
						end
					end
				end
			end
			moveSpectators()
			if team and os.clock() - lastTeamPublish >= TEAM_PUBLISH then
				lastTeamPublish = os.clock()
				publish()
			end
			local timedOut = os.clock() - fightStart >= mode.roundTime
			outcome = outcomeNow(timedOut)
			if outcome then
				break
			end
		end
		if finishing or not outcome then
			return false
		end
		local o = outcome :: ArenaRules.RoundOutcome
		self.phase = "between" :: Phase
		self.endsAt = nil
		if o.winner then
			self.score[o.winner] += 1
			announce("arena.roundWon", { name = sideName(o.winner) })
		else
			announce("arena.roundDraw", nil)
		end
		publish()
		local result = ArenaRules.matchOutcome(self.score, n, mode, nil)
		if result then
			finish(result)
			return false
		end
		return pause(mode.between)
	end

	function self.run(_self: Match)
		task.spawn(function()
			for _, f in fighters do
				f.back = backOf(f.player)
				deps.Blessing.SetSuspended(f.player, true)
			end
			for n = 1, mode.maxRounds do
				local ok, goOn = pcall(playRound, n)
				if not ok then
					log:error("match %s round %d failed: %s", spec.id, n, tostring(goOn))
					self:abort("error")
					return
				end
				if not goOn then
					break
				end
			end
			if not finishing then
				-- every round played without a decision (matchOutcome decides at maxRounds; a safety net)
				finish(ArenaRules.matchOutcome(self.score, mode.maxRounds, mode, nil) or {
					winner = nil,
					score = table.clone(self.score),
					rounds = self.round,
					reason = "draw",
					forfeits = {},
				})
			end
		end)
	end

	function self.abort(_self: Match, _reason: string)
		finish({ winner = nil, score = table.clone(self.score), rounds = self.round, reason = "aborted", forfeits = {} })
	end

	function self.sideOf(_self: Match, player: Player): number?
		local f = byPlayer[player]
		return if f then f.side else nil
	end

	function self.isFighter(_self: Match, player: Player): boolean
		return byPlayer[player] ~= nil
	end

	function self.keyOf(_self: Match, player: Player): string?
		local f = byPlayer[player]
		return if f then f.key else nil
	end

	-- Fighters of this match hit each other only during the fight, across sides and while standing; nobody else hits
	-- them and they hit nobody else. The same side never (S128 teams have no shared party).
	function self.rule(_self: Match, attacker: Player, target: Player): string?
		local a, t = byPlayer[attacker], byPlayer[target]
		if a and t then
			if a.side == t.side then
				return "deny"
			end
			local fair = self.phase == "fight" and not a.down and not t.down and not a.out and not t.out
			return if fair then "allow" else "deny"
		end
		if a or t then
			return "deny"
		end
		return nil
	end

	-- The help group of a fighter: the standing fighters of its side (itself always).
	function self.allies(_self: Match, player: Player): { Player }?
		local f = byPlayer[player]
		if not f or finishing then
			return nil
		end
		local out = { player }
		for _, other in sideFighters(f.side) do
			if other ~= f and online(other) and not other.down then
				table.insert(out, other.player)
			end
		end
		return out
	end

	-- A blow that would kill a fighter leaves 1 HP; in the fight it downs the fighter (1v1: the round ends).
	function self.lethal(_self: Match, player: Player, amount: number, hp: number): number
		local f = byPlayer[player]
		if not f or finishing or amount < hp then
			return amount
		end
		if self.phase == "fight" and not f.down then
			f.down = true
			if team then
				-- S128: off the sand to the bench (deferred: this runs inside the damage filter)
				task.defer(bench, f)
			end
		end
		return math.max(0, hp - 1)
	end

	-- A fighter died anyway (a reset, the void: past the damage filters): down for this round (in the countdown too),
	-- and back at once on the own spot through DeathService (no death timer, no choice, no respawn shield). Deferred:
	-- DeathService opens the death on the same signal.
	function self.died(_self: Match, player: Player)
		local f = byPlayer[player]
		if not f or f.gone then
			return
		end
		local wasDown = f.down
		if not finishing and (self.phase == "fight" or self.phase == "countdown") then
			f.down = true
		end
		task.defer(function()
			if not f.gone and online(f) then
				-- S128: a team fighter down in the fight comes back on the bench of its side
				local onBench = team and f.down and self.phase == "fight"
				local at = if onBench
					then venue:standCFrame(ArenaRules.benchIndex(venue.def, f.side))
					else venue:spawnCFrame(f.side, f.index)
				deps.Death.Recall(player, venue.map, at)
				if onBench and not wasDown then
					bench(f)
				end
			end
		end)
	end

	function self.leave(_self: Match, player: Player)
		local f = byPlayer[player]
		if not f or f.gone or finishing then
			return
		end
		f.gone = true
		forfeits[f.key] = true
		deps.Blessing.SetSuspended(player, false)
		checkForfeit()
	end

	function self.potionsLeft(_self: Match, player: Player): number
		local f = byPlayer[player]
		return if f then f.potions else 0
	end

	function self.drank(_self: Match, player: Player)
		local f = byPlayer[player]
		if f and not finishing then
			f.potions = math.max(0, f.potions - 1)
			if online(f) then
				deps.PlayerState.Set(f.player, { "arenaLive", "match" }, self:snapshot(f.player))
			end
		end
	end

	function self.sidelined(_self: Match, player: Player): boolean
		local f = byPlayer[player]
		return team and f ~= nil and f.down and not finishing and self.phase == "fight"
	end

	function self.players(_self: Match): { Player }
		local out = {}
		for _, f in fighters do
			table.insert(out, f.player)
		end
		return out
	end

	function self.names(_self: Match): { { string } }
		local out: { { string } } = {}
		for side, list in spec.sides do
			local names = {}
			for _, entrant in list do
				table.insert(names, entrant.name)
			end
			out[side] = names
		end
		return out
	end

	-- The HUD panel of `player` (state branch arenaLive.match).
	-- S128: the fighters of each side for the team panel (hp of a downed or gone fighter = 0).
	local function teamsView(): { { { [string]: any } } }
		local out = {}
		for side in spec.sides do
			local list = {}
			for _, other in sideFighters(side) do
				local hp, maxHp = 0, 1
				if online(other) then
					maxHp = math.max(1, deps.Stat.GetValue(other.player, "maxHp"))
					hp = if other.down then 0 else math.clamp(deps.Resource.Get(other.player), 0, maxHp)
				end
				table.insert(list, {
					name = other.name,
					class = other.class,
					out = other.down or other.gone or other.out,
					hp = math.floor(hp),
					maxHp = math.floor(maxHp),
				})
			end
			out[side] = list
		end
		return out
	end

	function self.snapshot(_self: Match, player: Player): { [string]: any }
		local f = byPlayer[player]
		return {
			teams = if team then teamsView() else nil,
			myTeam = if team and f then f.side else nil,
			id = spec.id,
			mode = spec.mode,
			phase = self.phase,
			round = self.round,
			maxRounds = mode.maxRounds,
			score = table.clone(self.score),
			side = if f then f.side else 0,
			endsAt = self.endsAt,
			potionsLeft = if f then f.potions else 0,
			names = self:names(),
			-- S128: the decided match (0 = no winner), so a forfeit win at 0:0 does not read as a draw
			winner = if self.result then self.result.winner or 0 else nil,
		}
	end

	return self :: Match
end

return Match
