--!strict
-- The arena server (S127, DESIGN-17 §6): a reserved server in mode "arena" (Arena/ServerMode) that hosts one global
-- match. ArenaService.Start runs it there. What it does:
--   1. reads the match record ArenaMatch_<ServerMode.ref()> (no record, or not "accepted" / "live": everybody home);
--   2. lets in only the players of the record with their slot (TeleportData is only a hint: Logic/ArenaQueue.allowed)
--      and puts each character straight on its start point of the pit (CharacterService.Play with a spawn; never in
--      the capital, the saved location stays as it was);
--   3. both here: the record goes "live" and ArenaService.RunMatch(spec, "pit") plays it by the S126 rules (Arena/Match,
--      ApplyResult, history and ranking unchanged); nobody else comes in;
--   4. one missing after arriveTimeout s: the match is cancelled without a rating, the one present goes home, the
--      missing one gets the decline penalty unless its server reported a teleport failure;
--   5. after the result (ArenaService.MatchFinished): the record "done", the return in returnDelay s (or "Return now",
--      ArenaReturnNow), Arena/Transfer.home: the server the player came from, any public one, a kick at last;
--   6. the server closing (an update): the match stops without a rating, the record "cancelled" / "void", all home.
-- Travel (portals, stones, the free return) is refused here through TravelService.AddGuard; Arena/Match still moves
-- the fighters with TravelService.TeleportToMap. Nothing here reads purchases (tests/paywall.spec).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Data.Arena)
local ArenaQueue = require(ReplicatedStorage.Shared.Logic.ArenaQueue)
local ArenaRules = require(ReplicatedStorage.Shared.Logic.ArenaRules)
local Clock = require(ReplicatedStorage.Shared.Util.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local ServerMode = require(script.Parent.ServerMode)
local Time = require(ReplicatedStorage.Shared.Logic.Time)
local Transfer = require(script.Parent.Transfer)
local Venues = require(script.Parent.Venues)

local log = Log.new("ArenaHost")

local NET = Config.ArenaNet
local VENUE = "pit"
local CLOSE_WAIT = 25 -- s BindToClose waits for the players to leave

export type Deps = {
	ArenaService: any, -- RunMatch, State, MatchFinished, AdminStop
	PlayerState: any, -- Ready, GetPhase
	Character: any, -- Play, SetSpawnOverride
	TravelService: any, -- AddGuard
	backend: ArenaQueue.Backend,
	playerOfKey: (key: string) -> Player?,
	setLive: (player: Player, field: string, value: any) -> (),
	toast: (player: Player, key: string, args: { [string]: any }?, kind: string?) -> (),
}

local ArenaHost = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function joinDataOf(player: Player): any?
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return if ok then data else nil
end

function ArenaHost.start(d: Deps)
	ServerMode.claim("arena", "ArenaService")
	local id = ServerMode.ref() or ""
	local recordKey = ArenaQueue.matchKey(id)
	local ArenaService = d.ArenaService
	local TravelService = d.TravelService
	local record: ArenaQueue.MatchRecord? = nil
	local phase: string = "boot" -- "boot" | "waiting" | "live" | "done"
	local finished = false -- the match has a result (the world server shows it on the return)
	local bootTs = now()
	local joinData: { [Player]: any } = {}

	-- no portals, stones or free returns out of the arena server
	TravelService.AddGuard(function(_player: Player): string?
		return "arena.net.error.notHere"
	end)

	local function sideOf(key: string): number
		local r = record
		if r then
			for side, list in r.spec.sides do
				for _, entrant in list do
					if entrant.key == key then
						return side
					end
				end
			end
		end
		return 1
	end

	local function keyOfUser(player: Player, slot: number): string
		return ArenaQueue.entryKey(player.UserId, slot)
	end

	local function startOf(key: string): CFrame
		return Venues.get(VENUE):spawnCFrame(sideOf(key), 1)
	end

	-- A death respawn or a fresh model on this server goes to the own start point (or the pit's way out).
	d.Character.SetSpawnOverride(function(player: Player): (CFrame?, string?)
		local data = joinData[player]
		local slot = if type(data) == "table" and type(data.TeleportData) == "table"
			then tonumber(data.TeleportData.slot)
			else nil
		if slot and record then
			return startOf(keyOfUser(player, slot)), "arena_pit"
		end
		return Venues.get(VENUE):exitCFrame(), "arena_pit"
	end)

	local function home(player: Player, reasonKey: string)
		task.spawn(Transfer.home, player, joinData[player] or joinDataOf(player), reasonKey, finished)
	end

	local function homeAll(reasonKey: string)
		for _, player in Players:GetPlayers() do
			home(player, reasonKey)
		end
	end

	local function write(fn: (current: any?) -> any?): any?
		local ok, after = d.backend.hupdate(NET.matchMap, recordKey, fn, NET.matchTtl)
		if ok and type(after) == "table" then
			record = after
		end
		return if ok then after else nil
	end

	-- A player arrived (the profile is loaded): in the match with the slot of the record, or home.
	local function admit(player: Player)
		if player.Parent ~= Players then
			return
		end
		local data = joinDataOf(player)
		joinData[player] = data
		local r = record
		local booting = phase == "boot"
		if not r or phase == "done" then
			if not booting then
				home(player, "arena.net.notInMatch")
			end
			return
		end
		local tp = if type(data) == "table" and type(data.TeleportData) == "table" then data.TeleportData else {}
		local slot = tonumber(tp.slot)
		if not slot or phase ~= "waiting" or not ArenaQueue.allowed(r, player.UserId, slot) then
			home(player, "arena.net.notInMatch")
			return
		end
		local key = keyOfUser(player, slot)
		local ok, err = d.Character.Play(player, slot, { map = "arena_pit", at = startOf(key) })
		if not ok then
			log:warn("%s could not enter the arena: %s", player.Name, tostring(err))
			home(player, "arena.net.notInMatch")
			return
		end
		task.spawn(write, ArenaQueue.arrived(key))
	end

	local function present(): { [string]: boolean }
		local out: { [string]: boolean } = {}
		local r = record
		if r then
			for _, p in r.players do
				local player = d.playerOfKey(p.key)
				if player and player.Character then
					out[p.key] = true
				end
			end
		end
		return out
	end

	local function startMatch()
		local r = record :: ArenaQueue.MatchRecord
		phase = "live"
		write(ArenaQueue.goLive())
		local spec = table.clone(r.spec)
		local day = Time.dayNumber(Clock.now())
		local unrated: { [string]: boolean } = {}
		for side, list in spec.sides do
			for _, entrant in list do
				local player = d.playerOfKey(entrant.key)
				local state = if player then ArenaService.State(player) else nil
				if state then
					for other, olist in spec.sides do
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
		spec.unrated = unrated
		local ok, err = ArenaService.RunMatch(spec, VENUE)
		if not ok then
			log:warn("match %s did not start: %s", id, tostring(err))
			phase = "done"
			write(ArenaQueue.void())
			homeAll("arena.net.cancelled.server")
		end
	end

	local function noShow(missing: { string })
		phase = "done"
		local r = record
		-- a player whose own server reported a failed teleport is not to blame
		local excused = r ~= nil and r.state == "cancelled" and r.reason == "teleport"
		write(ArenaQueue.cancel("noShow", missing[1]))
		if not excused then
			for _, key in missing do
				local untilAt = now() + Arena.QUEUE.declinePenalty
				d.backend.hupdate(NET.penaltyMap, key, function(cur: any?): any?
					return math.max(tonumber(cur) or 0, untilAt)
				end, math.max(1, math.floor(untilAt - now())))
			end
		end
		homeAll("arena.net.cancelled.noShow")
	end

	ArenaService.MatchFinished:Connect(function(spec: ArenaRules.MatchSpec, result: ArenaRules.MatchResult)
		if spec.id ~= id then
			return
		end
		phase = "done"
		finished = true
		local winner = if result.winner
				and spec.sides[result.winner]
				and spec.sides[result.winner][1]
			then spec.sides[result.winner][1].key
			else nil
		task.spawn(
			write,
			ArenaQueue.finish({ winner = winner, noRating = not spec.rated or result.reason == "aborted" })
		)
		local returnAt = now() + NET.returnDelay
		for _, player in Players:GetPlayers() do
			d.setLive(player, "returnAt", returnAt)
		end
		task.delay(NET.returnDelay, function()
			homeAll("arena.net.returned")
		end)
	end)

	d.PlayerState.Ready:Connect(function(player: Player)
		task.spawn(admit, player)
	end)

	game:BindToClose(function()
		if phase == "waiting" or phase == "boot" then
			write(ArenaQueue.cancel("server", nil))
		elseif phase == "live" then
			for _, player in Players:GetPlayers() do
				pcall(ArenaService.AdminStop, player) -- the match ends without a rating, not as a forfeit
			end
			write(ArenaQueue.void())
		end
		phase = "done"
		homeAll("arena.net.cancelled.server")
		local deadline = os.clock() + CLOSE_WAIT
		while #Players:GetPlayers() > 0 and os.clock() < deadline do
			task.wait(0.5)
		end
	end)

	-- Return now (after the result).
	ArenaHost.returnNow = function(player: Player): (boolean, string?)
		if phase ~= "done" then
			return false, "arena.net.error.notHere"
		end
		home(player, "arena.net.returned")
		return true, nil
	end

	task.spawn(function()
		local deadline = os.clock() + NET.modeWait
		while os.clock() < deadline do
			local ok, value = d.backend.hget(NET.matchMap, recordKey)
			if ok and type(value) == "table" then
				record = value
				break
			end
			task.wait(1)
		end
		local r = record
		if not r or (r.state ~= "accepted" and r.state ~= "live") then
			log:warn("no match %s here: everybody goes home", id)
			phase = "done"
			homeAll("arena.net.cancelled.server")
			return
		end
		phase = "waiting"
		bootTs = now()
		for _, player in Players:GetPlayers() do
			if d.PlayerState.GetPhase(player) == "select" then
				task.spawn(admit, player)
			end
		end
		local lastRead = os.clock()
		while phase == "waiting" do
			task.wait(1)
			if os.clock() - lastRead >= 5 then
				lastRead = os.clock()
				local ok, value = d.backend.hget(NET.matchMap, recordKey)
				if ok and type(value) == "table" then
					record = value
					if value.state ~= "accepted" and value.state ~= "live" then
						phase = "done"
						homeAll("arena.net.cancelled.noShow") -- the opponent's teleport failed or the offer ended
						break
					end
				end
			end
			if phase ~= "waiting" then
				break
			end
			local status, missing = ArenaQueue.arrival(record :: ArenaQueue.MatchRecord, present(), bootTs, now(), NET)
			if status == "start" then
				local ok, err = pcall(function()
					startMatch()
				end)
				if not ok then
					log:error("arena start failed: %s", tostring(err))
					phase = "done"
					homeAll("arena.net.cancelled.server")
				end
			elseif status == "noShow" then
				noShow(missing)
			end
		end
	end)
end

-- Set by `start` (ArenaReturnNow on an arena server).
ArenaHost.returnNow = function(_player: Player): (boolean, string?)
	return false, "arena.net.error.notHere"
end

return ArenaHost
