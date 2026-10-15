--!strict
-- Moving players between servers (S127, DESIGN-17 §6; S130 tournaments use it too). A plain module (not a service):
-- ArenaService.Init hands in what it needs (`Transfer.init`).
--   * toReserved(player, code, data, onFail): onto a reserved server (the arena of a global match). Before the teleport
--     the profile is saved and `arenaLive.transfer = "toArena"` shows the client's overlay; a party is left on its
--     own (parties live on one server; the toast says so), trades and mounts end with the leave like on any logout.
--   * home(player, joinData, reasonKey): from an arena server back to the server the player came from
--     (TeleportData.returnJob), then to any public server, at last a kick with a text (Logic/ArenaQueue.returnPlan).
--   * homeAll(reasonKey): everybody home (no match here, the server closes, /arenanet home).
-- Roblox API (create.roblox.com, TeleportService): TeleportAsync(placeId, { Player }, TeleportOptions) yields and
-- errors on a bad request; a teleport that starts and then fails fires TeleportService.TeleportInitFailed(player,
-- result, message, placeId, options). TeleportOptions.ReservedServerAccessCode = the code of ReserveServer;
-- TeleportOptions.ServerInstanceId = a JobId of a running public server (the modern TeleportToPlaceInstance, with
-- TeleportData); TeleportOptions:SetTeleportData(table) is read on arrival by Player:GetJoinData().TeleportData. Every
-- call runs in pcall: a wrong signature ends in a retry and the fallback, never in an error in a loop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local ArenaQueue = require(ReplicatedStorage.Shared.Logic.ArenaQueue)
local Config = require(ReplicatedStorage.Shared.Config)
local Locale = require(ReplicatedStorage.Shared.Util.Locale)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("ArenaTransfer")

local NET = Config.ArenaNet
-- A teleport that neither failed nor took the player away within this many seconds counts as failed.
local WATCHDOG = 30

export type Deps = {
	save: (player: Player) -> (), -- the runtime values into the profile and a save now
	restoreHome: (player: Player) -> (), -- the arena server: the saved location back before leaving (CharacterService)
	inParty: (player: Player) -> boolean,
	toast: (player: Player, key: string, args: { [string]: any }?, kind: string?) -> (),
	setLive: (player: Player, field: string, value: any) -> (),
}

type Pending = {
	token: number,
	retry: () -> (),
	failed: boolean,
}

local Transfer = {}

local deps: Deps? = nil
local pending: { [Player]: Pending } = {}
local tokens = 0
local connected = false

local function need(): Deps
	local d = deps
	if not d then
		error("Arena/Transfer: init first")
	end
	return d
end

-- One TeleportAsync; false when the call itself failed (the event may still report a later failure).
local function teleport(player: Player, options: TeleportOptions): boolean
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not ok then
		log:warn("teleport of %s failed: %s", player.Name, tostring(err))
	end
	return ok
end

-- Runs `attempt(n)` until the player leaves the server; a failure (call error, TeleportInitFailed or the watchdog)
-- moves to attempt n + 1 after the retry gap. `attempt` returns false when there is nothing left to try.
local function drive(player: Player, attempt: (n: number) -> boolean)
	tokens += 1
	local token = tokens
	local n = 0
	local entry: Pending = { token = token, retry = function() end, failed = false }
	local function step()
		if pending[player] ~= entry or player.Parent ~= Players then
			return
		end
		n += 1
		entry.failed = false
		if not attempt(n) then
			pending[player] = nil
			return
		end
		local mine = n
		task.delay(WATCHDOG, function()
			if pending[player] == entry and n == mine and player.Parent == Players then
				log:warn("teleport of %s did not start in %d s", player.Name, WATCHDOG)
				entry.retry()
			end
		end)
	end
	entry.retry = function()
		if pending[player] ~= entry or entry.failed then
			return
		end
		entry.failed = true
		task.delay(NET.teleportRetryGap, step)
	end
	pending[player] = entry
	step()
end

local function options(data: { [string]: any }, code: string?, instance: string?): TeleportOptions
	local o = Instance.new("TeleportOptions")
	if code then
		o.ReservedServerAccessCode = code
	end
	if instance then
		o.ServerInstanceId = instance
	end
	o:SetTeleportData(data)
	return o
end

function Transfer.init(d: Deps)
	deps = d
	if connected then
		return
	end
	connected = true
	TeleportService.TeleportInitFailed:Connect(function(player: Player, result: Enum.TeleportResult, message: string)
		local entry = pending[player]
		if entry then
			log:warn("teleport of %s failed (%s): %s", player.Name, tostring(result), tostring(message))
			entry.retry()
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
	end)
end

-- Whether a teleport of `player` is under way.
function Transfer.busy(player: Player): boolean
	return pending[player] ~= nil
end

-- Onto the reserved server `code` with `data` as TeleportData; `onFail("teleport")` after every attempt failed.
function Transfer.toReserved(player: Player, code: string, data: { [string]: any }, onFail: (reason: string) -> ())
	local d = need()
	if d.inParty(player) then
		d.toast(player, "arena.net.partyLeft", nil, "info")
	end
	d.setLive(player, "transfer", "toArena")
	pcall(d.save, player)
	drive(player, function(n: number): boolean
		if n > NET.teleportRetries then
			d.setLive(player, "transfer", nil)
			task.spawn(onFail, "teleport")
			return false
		end
		if not teleport(player, options(data, code, nil)) then
			task.defer(function()
				local entry = pending[player]
				if entry then
					entry.retry()
				end
			end)
		end
		return true
	end)
end

-- Back to the world from an arena server. `joinData` = Player:GetJoinData() of the arrival (TeleportData.returnJob,
-- arenaMatch, slot); `reasonKey` is shown first; `finished` = the match has a result (TeleportData.arenaDone: the
-- world server shows it, a cancelled match only says "back").
function Transfer.home(player: Player, joinData: any?, reasonKey: string, finished: boolean?)
	local d = need()
	if pending[player] or player.Parent ~= Players then
		return
	end
	local data = if type(joinData) == "table" and type(joinData.TeleportData) == "table"
		then joinData.TeleportData
		else {}
	local returnJob = if type(data.returnJob) == "string" then data.returnJob else nil
	local back = {
		serverMode = "world",
		arenaReturn = if type(data.arenaMatch) == "string" then data.arenaMatch else "arena",
		slot = if type(data.slot) == "number" then data.slot else nil,
		arenaDone = if finished then true else nil,
		team = if data.team == true then true else nil, -- S128: the world server tells a party member it is gone
	}
	d.toast(player, reasonKey, nil, "info")
	d.setLive(player, "transfer", "home")
	pcall(d.restoreHome, player)
	pcall(d.save, player)
	drive(player, function(n: number): boolean
		local plan = ArenaQueue.returnPlan(n, returnJob, NET)
		if plan.kind == "kick" then
			local key = "arena.net.kickReturn"
			player:Kick(Locale.T(key, nil, "en") .. " / " .. Locale.T(key, nil, "pl"))
			return false
		end
		local instance = if plan.kind == "instance" then plan.job else nil
		if not teleport(player, options(back, nil, instance)) then
			task.defer(function()
				local entry = pending[player]
				if entry then
					entry.retry()
				end
			end)
		end
		return true
	end)
end

-- Everybody home (the arena server has no match, closes or an admin asked).
function Transfer.homeAll(reasonKey: string)
	for _, player in Players:GetPlayers() do
		local ok, data = pcall(function()
			return player:GetJoinData()
		end)
		task.spawn(Transfer.home, player, if ok then data else nil, reasonKey)
	end
end

return Transfer
