--!strict
-- The mode of this server (S127, DESIGN-17 §6): "world" (every public server and players' private servers),
-- "arena" (a reserved server of one global arena match) or "tournament" (a reserved server of a tournament, S130).
-- A plain module, not a service: init.server.luau calls `resolve()` once before Util/Loader loads any service, so
-- every service may require this module without a Deps entry, and WorldService.Init (which must not yield) builds
-- only the maps of the mode (Data/Maps.serverModes, here arena_pit).
-- A reserved server learns its mode from the MemoryStore HashMap ReservedServers[PrivateServerId] (written by the
-- organizer right after TeleportService:ReserveServer, Logic/ArenaQueue.tryPair), else from the first player's
-- TeleportData (`serverMode`); without either it runs as a world (it breaks nothing). Studio is always "world".
-- The result is published as Workspace attributes ServerMode / ServerModeRef for the client (UI/ServerModeView).

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArenaQueue = require(ReplicatedStorage.Shared.Logic.ArenaQueue)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Retry = require(script.Parent.Parent.Market.Retry)

local log = Log.new("ServerMode")

local NET = Config.ArenaNet

export type Mode = ArenaQueue.ServerMode

local ServerMode = {}

local mode: Mode = "world"
local ref: string? = nil
local resolved = false
local owners: { [string]: string } = {}

local function publish()
	Workspace:SetAttribute("ServerMode", mode)
	Workspace:SetAttribute("ServerModeRef", ref)
	log:info("server mode: %s (%s)", mode, tostring(ref))
end

-- Reads the registry entry of this reserved server (MemoryStoreHashMap:GetAsync(key) returns the stored value or nil;
-- every failure ends in nil, never in an error).
local function readRegistry(psid: string): any?
	local ok, value = Retry.call("ReservedServers.Get", function()
		return MemoryStoreService:GetHashMap(NET.registryMap):GetAsync(psid)
	end)
	return if ok then value else nil
end

-- The join data of the first player (Player:GetJoinData() -> { TeleportData = ..., ... }), waiting until `deadline`.
local function firstJoinData(deadline: number): any?
	local player = Players:GetPlayers()[1]
	while not player and os.clock() < deadline do
		task.wait(0.25)
		player = Players:GetPlayers()[1]
	end
	if not player then
		return nil
	end
	local ok, data = pcall(function()
		return player:GetJoinData()
	end)
	return if ok then data else nil
end

-- Decides the mode (yields on a reserved server only; called once from init.server.luau before the loader).
function ServerMode.resolve()
	if resolved then
		return
	end
	resolved = true
	-- game.PrivateServerId is "" on public servers; PrivateServerOwnerId is 0 on reserved servers and the owner's user
	-- id on a player's private server (create.roblox.com DataModel)
	local psid = game.PrivateServerId
	local owner = game.PrivateServerOwnerId
	if RunService:IsStudio() or psid == "" or owner ~= 0 then
		mode, ref = "world", nil
		publish()
		return
	end
	local deadline = os.clock() + NET.modeWait
	local registry = readRegistry(psid)
	local joinData = if registry == nil then firstJoinData(deadline) else nil
	local ok, decided, decidedRef = pcall(ArenaQueue.decideMode, {
		privateServerId = psid,
		ownerId = owner,
		registry = registry,
		joinData = joinData,
	})
	if ok then
		mode, ref = decided :: Mode, decidedRef
	else
		log:warn("mode decision failed (%s): running as a world", tostring(decided))
		mode, ref = "world", nil
	end
	publish()
end

function ServerMode.get(): Mode
	return mode
end

-- The match id (arena) or the tournament id (tournament); nil on a world server.
function ServerMode.ref(): string?
	return ref
end

function ServerMode.isWorld(): boolean
	return mode == "world"
end

-- The map characters stand on by default: the capital on a world server, the arena pit elsewhere.
function ServerMode.homeMap(): string
	return if mode == "world" then Config.StartingMap else "arena_pit"
end

-- Writes the registry entry of a reserved server (after ReserveServer): the one writer next to Logic/ArenaQueue
-- (which owns the shape). `backend` is a Logic/ArenaQueue Backend (the Matchmaker's). S130: "tournament".
function ServerMode.register(backend: ArenaQueue.Backend, psid: string, m: Mode, r: string): boolean
	local ok = backend.hupdate(NET.registryMap, psid, function(_current: any?): any?
		return ArenaQueue.registryEntry(m, r)
	end, NET.registryTtl)
	return ok
end

-- The service that runs a non-world mode says so in its Start (S127 ArenaService for "arena"; S130 the tournament
-- service for "tournament"). A mode nobody claims sends its players home (ArenaService, after a grace period).
function ServerMode.claim(m: Mode, ownerName: string)
	owners[m] = ownerName
end

function ServerMode.claimedBy(): string?
	return owners[mode]
end

return ServerMode
