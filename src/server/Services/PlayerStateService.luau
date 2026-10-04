--!strict
-- Owns each player's replicated state tree (ARCHITECTURE §6) and streams changes to the owner.
--
-- Tree: { account = profile.Data (sent without .characters), slots = summaries,
--         character = profile.Data.characters[slot] (same table!), session = {...},
--         derived/zone/death/pvp = runtime-only branches owned by their services }
-- Writes through Set/Update/ArrayInsert/ArrayRemove mutate profile data directly and queue a diff;
-- diffs are batched and flushed once per Heartbeat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local CharacterFactory = require(Shared.Logic.CharacterFactory)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local PathOps = require(Shared.Logic.PathOps)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Types = require(Shared.Types)

local log = Log.new("PlayerState")

type Path = Types.Path
type Diff = Types.Diff

type Entry = {
	root: any,
	pending: { Diff },
}

local PlayerStateService = {
	Name = "PlayerStateService",
	Deps = { "DataService" },
	-- (player) after a full snapshot was built (initial load or Reset).
	Ready = Signal.new(),
}

local DataService: any
local entries: { [Player]: Entry } = {}

local function assertReplicable(path: Path)
	assert(#path > 0, "PlayerState: empty path")
	assert(
		not (path[1] == "account" and path[2] == "characters"),
		"PlayerState: account.characters is not replicated; write through {'character', ...} or {'slots', ...}"
	)
end

local function buildSnapshot(root: any): any
	local snapshot = table.clone(root)
	local account = table.clone(root.account)
	account.characters = nil
	snapshot.account = account
	return snapshot
end

local function queue(player: Player, entry: Entry, diff: Diff)
	table.insert(entry.pending, diff)
	if Config.Debug.LogStateDiffs then
		log:debug("%s %s %s", player.Name, diff.op, PathOps.key(diff.path))
	end
end

local function getEntry(player: Player): Entry
	local entry = entries[player]
	assert(entry, `PlayerState: no state for {player.Name}`)
	return entry
end

function PlayerStateService.HasState(player: Player): boolean
	return entries[player] ~= nil
end

function PlayerStateService.Get(player: Player, path: Path): any
	local entry = entries[player]
	return if entry then PathOps.get(entry.root, path) else nil
end

function PlayerStateService.Set(player: Player, path: Path, value: any)
	assertReplicable(path)
	local entry = getEntry(player)
	PathOps.set(entry.root, path, value)
	queue(player, entry, { op = "set", path = path, value = value })
end

function PlayerStateService.Update(player: Player, path: Path, fn: (any) -> any): any
	local value = fn(PlayerStateService.Get(player, path))
	PlayerStateService.Set(player, path, value)
	return value
end

function PlayerStateService.ArrayInsert(player: Player, path: Path, value: any, index: number?): number
	assertReplicable(path)
	local entry = getEntry(player)
	local at = PathOps.insert(entry.root, path, value, index)
	queue(player, entry, { op = "insert", path = path, value = value, index = at })
	return at
end

function PlayerStateService.ArrayRemove(player: Player, path: Path, index: number): any
	assertReplicable(path)
	local entry = getEntry(player)
	local removed = PathOps.remove(entry.root, path, index)
	queue(player, entry, { op = "remove", path = path, index = index })
	return removed
end

-- Active character data (the live profile table) or nil on the selection screen.
function PlayerStateService.GetCharacter(player: Player): Types.CharacterData?
	local entry = entries[player]
	return if entry then entry.root.character else nil
end

function PlayerStateService.GetPhase(player: Player): Types.SessionPhase
	local entry = entries[player]
	return if entry then entry.root.session.phase else "loading"
end

-- Rebuilds the tree from profile data (e.g. after /wipe) and resends a full snapshot.
function PlayerStateService.Reset(player: Player)
	local data = DataService.GetData(player)
	if not data then
		return
	end
	local root = {
		account = data,
		slots = CharacterFactory.summaries(data.characters),
		character = nil,
		session = { phase = "select", slot = nil, dataMock = DataService.IsMock() },
		-- Filled while playing: derived stats (StatService), zone (ZoneService), death (DeathService),
		-- pvp toggle state (PvpService).
		derived = nil,
		zone = nil,
		death = nil,
		pvp = nil,
	}
	entries[player] = { root = root, pending = {} }
	Net.Fire(player, "StateSnapshot", buildSnapshot(root))
	PlayerStateService.Ready:Fire(player)
end

-- Sends any queued diffs right away (use before yielding work the client must see first).
function PlayerStateService.Flush(player: Player)
	local entry = entries[player]
	if entry and #entry.pending > 0 then
		local batch = entry.pending
		entry.pending = {}
		Net.Fire(player, "StateDiff", batch)
	end
end

function PlayerStateService.Init(registry)
	DataService = registry.Get("DataService")
end

function PlayerStateService.Start()
	DataService.ProfileLoaded:Connect(function(player: Player)
		PlayerStateService.Reset(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Deferred so ProfileReleasing handlers can still read state.
		task.defer(function()
			entries[player] = nil
		end)
	end)

	Net.On("RequestSnapshot", function(player: Player)
		local entry = entries[player]
		if entry then
			Net.Fire(player, "StateSnapshot", buildSnapshot(entry.root))
			entry.pending = {}
		end
	end)

	local sinceFlush = 0
	RunService.Heartbeat:Connect(function(dt)
		sinceFlush += dt
		if sinceFlush < Config.StateFlushInterval then
			return
		end
		sinceFlush = 0
		for player in entries do
			PlayerStateService.Flush(player)
		end
	end)
end

return PlayerStateService
