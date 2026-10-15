--!strict
-- S133: who is in the game across servers. One MemoryStore HashMap (Config.Social.presenceMap), one entry per online
-- player: { j = jobId, m = map, l = level, c = class, n = character name, t = os.time }, written with a TTL of
-- Config.Social.presenceTtl and refreshed every Config.Social.presenceRefresh by the player's server (SocialService).
-- Reads are cached for Config.Social.statusRefresh per user on this server, so a friends window open on many clients
-- costs at most one read per friend and period. Everything is best effort (pcall): when MemoryStore fails (Studio
-- without API access, an outage) the entries of this server still work from memory and other players read as
-- "unknown" (`read` returns ok = false).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Social = require(ReplicatedStorage.Shared.Logic.Social)

local log = Log.new("Presence")

local Presence = {}

-- This server in presence entries (JobId is empty in Studio: a random id keeps two Studio servers apart).
Presence.JobId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`

local map: MemoryStoreHashMap? = nil
local warned = false
local localEntries: { [string]: Social.Presence } = {}
type Cached = { at: number, ok: boolean, entry: Social.Presence? }
local cache: { [string]: Cached } = {}

local function warnOnce(err: any)
	if not warned then
		warned = true
		log:warn("MemoryStore unavailable (%s): presence stays on this server", tostring(err))
	end
end

function Presence.init()
	local ok, result = pcall(function()
		return MemoryStoreService:GetHashMap(Config.Social.presenceMap)
	end)
	if ok then
		map = result
	else
		warnOnce(result)
	end
end

-- Writes (or refreshes) a player's entry. Yields.
function Presence.write(userId: number, entry: Social.Presence)
	local key = Social.key(userId)
	localEntries[key] = entry
	cache[key] = nil
	local m = map
	if not m then
		return
	end
	local ok, err = pcall(function()
		m:SetAsync(key, entry, Config.Social.presenceTtl)
	end)
	if not ok then
		warnOnce(err)
	end
end

-- Drops a player's entry (left the game). Yields.
function Presence.remove(userId: number)
	local key = Social.key(userId)
	localEntries[key] = nil
	cache[key] = nil
	local m = map
	if not m then
		return
	end
	local ok, err = pcall(function()
		m:RemoveAsync(key)
	end)
	if not ok then
		warnOnce(err)
	end
end

-- The entry of a player on any server. Yields (MemoryStore), cached. Returns (ok, entry?); ok = false: unknown.
function Presence.read(userId: number): (boolean, Social.Presence?)
	local key = Social.key(userId)
	local own = localEntries[key]
	if own then
		return true, own
	end
	local now = os.clock()
	local hit = cache[key]
	if hit and now - hit.at < Config.Social.statusRefresh then
		return hit.ok, hit.entry
	end
	local m = map
	if not m then
		return false, nil
	end
	local ok, result = pcall(function()
		return m:GetAsync(key)
	end)
	local entry: Social.Presence? = nil
	if ok and type(result) == "table" and type(result.j) == "string" and type(result.t) == "number" then
		entry = result :: any
	elseif not ok then
		warnOnce(result)
	end
	cache[key] = { at = now, ok = ok, entry = entry }
	return ok, entry
end

return Presence
