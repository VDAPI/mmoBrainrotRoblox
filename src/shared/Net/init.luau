--!strict
-- Networking layer over RemoteEvents/RemoteFunctions defined in Net/Definitions.
--
-- Server: Net.initServer(); Net.On(name, fn(player, ...)); Net.Handle(name, fn(player, ...) -> ...);
--         Net.Fire(player, name, ...); Net.FireAll(name, ...); Net.FireList(players, name, ...)
-- Client: Net.initClient(); Net.On(name, fn(...)); Net.Send(name, ...); Net.Invoke(name, ...)
--
-- Every client -> server call is rate limited and type checked (Definitions.args) before the handler
-- runs. Rejected calls are dropped (events) or answer (false, "error.rateLimited"/"error.badRequest").
-- There is never a server -> client RemoteFunction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Definitions = require("@self/Definitions")
local ArgCheck = require("./Logic/ArgCheck")
local RateLimit = require("./Logic/RateLimit")
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

-- Returns true when the call may proceed.
-- Whether a call passes; the second value is the error key for a refused function call (owner 2026-10-20: a rate limit
-- said "bad request" too, so fast clicks looked like a broken button).
local function admit(
	player: Player,
	name: string,
	def: Definitions.Definition,
	args: { any },
	n: number
): (boolean, string?)
	local limiter = limiters[name]
	if limiter and not limiter:take(`{player.UserId}`, os.clock()) then
		flag(player, name, "rate limit")
		return false, "error.rateLimited"
	end
	local ok, reason = Net.Check(args, def.args or {}, n)
	if not ok then
		flag(player, name, reason or "bad args")
		return false, "error.badRequest"
	end
	return true, nil
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
			if admit(player, name, def, args, n) then
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
		local admitted, refusal = admit(player, name, def, args, n)
		if not admitted then
			return false, refusal or "error.badRequest"
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			log:error("%s handler failed for %s: %s", name, player.Name, tostring(results[2]))
			return false, "error.internal"
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
function Net.Invoke(name: string, ...: any): ...any
	assert(not IS_SERVER, "Net.Invoke is client-only")
	local def = getDefinition(name)
	assert(def.kind == "function", `Net.Invoke: '{name}' is not a function`)
	local remote = getRemote(name) :: RemoteFunction
	-- owner 2026-10-20: a click faster than the remote's rate waits a moment and asks again (twice at most) instead of
	-- showing an error
	for attempt = 1, RATE_RETRIES + 1 do
		local results = table.pack(pcall(remote.InvokeServer, remote, ...))
		if not results[1] then
			log:warn("%s invoke failed: %s", name, tostring(results[2]))
			return false, "error.network"
		end
		if results[2] == false and results[3] == "error.rateLimited" and attempt <= RATE_RETRIES then
			task.wait(RATE_RETRY_WAIT * attempt)
		else
			return table.unpack(results, 2, results.n)
		end
	end
	return false, "error.rateLimited"
end

return Net
