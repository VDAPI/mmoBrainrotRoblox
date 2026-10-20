--!strict
-- Networking layer over RemoteEvents/RemoteFunctions defined in Net/Definitions.
--
-- Server: Net.initServer(); Net.On(name, fn(player, ...)); Net.Handle(name, fn(player, ...) -> ...);
--         Net.Fire(player, name, ...); Net.FireAll(name, ...); Net.FireList(players, name, ...)
-- Client: Net.initClient(); Net.On(name, fn(...)); Net.Send(name, ...); Net.Invoke(name, ...)
--
-- Every client -> server call is rate limited and type checked (Definitions.args) before the handler
-- runs. Rejected calls are dropped (events) or answer (false, "error.rateLimited"/"error.badRequest"); W28: a full
-- rate limit bucket is "error.rateLimited" (silent on the client), "error.badRequest" only for arguments that fail
-- Definitions.args, and every "error.badRequest" (Net's own or a handler's) is logged with the remote's name.
-- A rate-limited Net.Invoke waits and asks again (RATE_RETRIES). W28: Net.Invoke merges a repeated identical call and throttles toggles (Logic/RequestGuard), so a fast double click
-- never reaches the server twice. There is never a server -> client RemoteFunction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Definitions = require("@self/Definitions")
local ArgCheck = require("./Logic/ArgCheck")
local RateLimit = require("./Logic/RateLimit")
local RequestGuard = require("./Logic/RequestGuard")
local Log = require("./Util/Log")

local log = Log.new("Net")
local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Remotes"

local Net = {}

local folder: Folder? = nil
local limiters: { [string]: RateLimit.RateLimit } = {}
local RATE_RETRIES = 2
local RATE_RETRY_WAIT = 0.35 -- seconds before the first retry (the second waits twice as long)
local suspicion: { [number]: number } = {}
local badAnswers: { [number]: number } = {}
local guard = RequestGuard.new()

Net.Check = ArgCheck.check

local function getDefinition(name: string): Definitions.Definition
	local def = Definitions[name]
	assert(def, `Net: unknown remote '{name}'`)
	return def
end

local function getRemote(name: string): Instance
	assert(folder, "Net: not initialised (call Net.initServer/initClient first)")
	local remote = folder:FindFirstChild(name)
	if remote == nil then
		remote = folder:WaitForChild(name, 10)
	end
	assert(remote, `Net: remote '{name}' not found`)
	return remote
end

local function flag(player: Player, name: string, reason: string)
	local count = (suspicion[player.UserId] or 0) + 1
	suspicion[player.UserId] = count
	if count <= 20 or count % 50 == 0 then
		log:warn("rejected %s from %s (%d): %s", name, player.Name, count, reason)
	end
end

-- A short, safe description of a call's arguments for the logs.
local function describe(args: { any }, n: number): string
	local parts = {}
	for i = 1, math.min(n, 6) do
		local value = args[i]
		local text = if type(value) == "string" then `"{string.sub(value, 1, 24)}"` else typeof(value)
		if type(value) == "number" or type(value) == "boolean" then
			text = tostring(value)
		end
		table.insert(parts, text)
	end
	return table.concat(parts, ", ")
end

-- Returns nil when the call may proceed, otherwise the error key to answer (RequestGuard.rejectCode).
local function admit(player: Player, name: string, def: Definitions.Definition, args: { any }, n: number): string?
	local limiter = limiters[name]
	local rateOk = true
	if limiter then
		rateOk = limiter:take(`{player.UserId}`, os.clock())
	end
	local argsOk, reason = true, nil
	if rateOk then
		argsOk, reason = Net.Check(args, def.args or {}, n)
	end
	local code = RequestGuard.rejectCode(rateOk, argsOk)
	if code == RequestGuard.RATE_LIMITED then
		flag(player, name, "rate limit")
	elseif code then
		flag(player, name, `bad args ({reason or "?"}): {describe(args, n)}`)
	end
	return code
end

-- W28: a handler answered "error.badRequest" (a payload its own checks refused): logged with the remote's name.
local function noteBadAnswer(player: Player, name: string, args: { any }, n: number)
	local count = (badAnswers[player.UserId] or 0) + 1
	badAnswers[player.UserId] = count
	if count <= 20 or count % 50 == 0 then
		log:warn("%s answered badRequest to %s (%d): %s", name, player.Name, count, describe(args, n))
	end
end

-- Server ------------------------------------------------------------------------------------------

function Net.initServer()
	assert(IS_SERVER, "Net.initServer called on client")
	if folder then
		return
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = FOLDER_NAME
	for name, def in Definitions do
		local remote = Instance.new(if def.kind == "event" then "RemoteEvent" else "RemoteFunction")
		remote.Name = name
		remote.Parent = newFolder
		if def.dir ~= "s2c" then
			limiters[name] = RateLimit.new(def.rate or 10)
		end
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
	Players.PlayerRemoving:Connect(function(player)
		suspicion[player.UserId] = nil
		badAnswers[player.UserId] = nil
		for _, limiter in limiters do
			limiter.buckets[`{player.UserId}`] = nil
		end
	end)
end

-- Server: handler for a c2s event. Client: handler for an s2c event.
function Net.On(name: string, handler: (...any) -> ())
	local def = getDefinition(name)
	assert(def.kind == "event", `Net.On: '{name}' is not an event`)
	local remote = getRemote(name) :: RemoteEvent
	if IS_SERVER then
		assert(def.dir ~= "s2c", `Net.On: '{name}' is server -> client`)
		remote.OnServerEvent:Connect(function(player: Player, ...: any)
			local n = select("#", ...)
			local args = { ... }
			if admit(player, name, def, args, n) == nil then
				handler(player, ...)
			end
		end)
	else
		assert(def.dir ~= "c2s", `Net.On: '{name}' is client -> server`)
		remote.OnClientEvent:Connect(handler)
	end
end

-- Server: answers a c2s function. Handler errors are caught and returned as (false, "error.internal").
function Net.Handle(name: string, handler: (player: Player, ...any) -> ...any)
	assert(IS_SERVER, "Net.Handle is server-only")
	local def = getDefinition(name)
	assert(def.kind == "function", `Net.Handle: '{name}' is not a function`)
	local remote = getRemote(name) :: RemoteFunction
	remote.OnServerInvoke = function(player: Player, ...: any): ...any
		local n = select("#", ...)
		local args = { ... }
		local rejected = admit(player, name, def, args, n)
		if rejected then
			return false, rejected
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			log:error("%s handler failed for %s: %s", name, player.Name, tostring(results[2]))
			return false, "error.internal"
		end
		if results[2] == false and results[3] == RequestGuard.BAD_REQUEST then
			noteBadAnswer(player, name, args, n)
		end
		return table.unpack(results, 2, results.n)
	end
end

function Net.Fire(player: Player, name: string, ...: any)
	assert(IS_SERVER, "Net.Fire is server-only (client uses Net.Send)")
	local remote = getRemote(name) :: RemoteEvent
	remote:FireClient(player, ...)
end

function Net.FireAll(name: string, ...: any)
	assert(IS_SERVER, "Net.FireAll is server-only")
	local remote = getRemote(name) :: RemoteEvent
	remote:FireAllClients(...)
end

function Net.FireList(players: { Player }, name: string, ...: any)
	assert(IS_SERVER, "Net.FireList is server-only")
	local remote = getRemote(name) :: RemoteEvent
	for _, player in players do
		remote:FireClient(player, ...)
	end
end

-- Client ------------------------------------------------------------------------------------------

function Net.initClient()
	assert(not IS_SERVER, "Net.initClient called on server")
	if folder then
		return
	end
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Net.Send(name: string, ...: any)
	assert(not IS_SERVER, "Net.Send is client-only")
	local def = getDefinition(name)
	assert(def.kind == "event" and def.dir ~= "s2c", `Net.Send: '{name}' is not a c2s event`)
	local remote = getRemote(name) :: RemoteEvent
	remote:FireServer(...)
end

-- Yields. Returns whatever the server handler returned; (false, "error.network") if the call failed.
-- W28: the same call (remote + arguments) while one is in flight waits for it and returns its results; repeated
-- within RequestGuard.SAME_WINDOW it returns the last results again (not for Definitions.repeatable); a toggle
-- (Definitions.toggle) sent again within RequestGuard.TOGGLE_WINDOW answers (false, "error.tooFast"). Toasts skip
-- RequestGuard.SILENT keys, so none of these shows an error.
function Net.Invoke(name: string, ...: any): ...any
	assert(not IS_SERVER, "Net.Invoke is client-only")
	local def = getDefinition(name)
	assert(def.kind == "function", `Net.Invoke: '{name}' is not a function`)
	local remote = getRemote(name) :: RemoteFunction
	local n = select("#", ...)
	local key = RequestGuard.key(name, { ... }, n)
	local verdict = guard:begin(name, key, def, os.clock())
	if verdict == "drop" then
		return false, RequestGuard.TOO_FAST
	elseif verdict ~= "send" and key then
		while guard:pending(key, os.clock()) do
			task.wait()
		end
		local last = guard:results(key)
		if last then
			return table.unpack(last, 1, last.n)
		end
		return false, RequestGuard.TOO_FAST
	end
	-- owner 2026-10-20: a click faster than the remote's rate waits a moment and asks again (twice at most) instead of
	-- showing an error
	local results = table.pack(false, RequestGuard.RATE_LIMITED)
	for attempt = 1, RATE_RETRIES + 1 do
		local called = table.pack(pcall(remote.InvokeServer, remote, ...))
		if not called[1] then
			log:warn("%s invoke failed: %s", name, tostring(called[2]))
			results = table.pack(false, "error.network")
			break
		end
		results = table.pack(table.unpack(called, 2, called.n))
		if results[1] == false and results[2] == RequestGuard.RATE_LIMITED and attempt <= RATE_RETRIES then
			task.wait(RATE_RETRY_WAIT * attempt)
		else
			break
		end
	end
	guard:finish(key, results, os.clock())
	return table.unpack(results, 1, results.n)
end

return Net
