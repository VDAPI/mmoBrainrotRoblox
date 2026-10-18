--!strict
-- S150: the one cross-server module of friends (replaces S133 Social/Presence; pattern of Guild/Bus and
-- Leaderboard/Stores). Two things, both best effort:
--   * presence: MemoryStore HashMap Config.Friends.presenceMap through Logic/Presence.reader (cache shared by the
--     server, token bucket Config.Friends.readsPerMinute). Writes use SetAsync (1 request unit; an entry is never
--     merged) and RemoveAsync with Market/Retry; a read is a single GetAsync in pcall (a failure = "unknown").
--   * party invitations: one MessagingService topic Config.Friends.inviteTopic for every server (PublishAsync with
--     Market/Retry, SubscribeAsync once in pcall).
-- In Studio, and when MemoryStore / MessagingService cannot be reached, both run on one Logic/MemoryFake in memory
-- ("this server only"): presence of this server's players works, other servers read as offline.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local MemoryFake = require(ReplicatedStorage.Shared.Logic.MemoryFake)
local PresenceLogic = require(ReplicatedStorage.Shared.Logic.Presence)
local Retry = require(script.Parent.Parent.Market.Retry)

local log = Log.new("FriendsPresence")

local F = Config.Friends

local Presence = {}

-- This server in presence entries (JobId is empty in Studio: a random id keeps two Studio servers apart).
Presence.JobId = if game.JobId ~= "" then game.JobId else `studio-{HttpService:GenerateGUID(false)}`

local fake = MemoryFake.new(os.time)
local reader: PresenceLogic.Reader? = nil
local live = false -- MemoryStore / MessagingService in use (false: the fake)
local messaging = false
local warned: { [string]: boolean } = {}
local inviteHandler: (message: any) -> () = function(_message: any) end

local function warnOnce(what: string, err: any)
	if not warned[what] then
		warned[what] = true
		log:warn("%s unavailable (%s): friends stay on this server", what, tostring(err))
	end
end

-- The Logic/Presence backend on a MemoryStore hash map.
local function storeBackend(map: MemoryStoreHashMap): PresenceLogic.Backend
	return {
		hget = function(_name: string, key: string): (boolean, any?)
			local ok, value = pcall(function()
				return map:GetAsync(key)
			end)
			if not ok then
				warnOnce("MemoryStore read", value)
			end
			return ok, if ok then value else nil
		end,
		hupdate = function(_name: string, key: string, fn: (current: any?) -> any?, ttl: number): (boolean, any?, any?)
			local value = fn(nil) -- presence is never merged: SetAsync, one request unit
			if value == nil then
				return true, nil, nil
			end
			local ok, err = Retry.call("Presence.Set", function()
				map:SetAsync(key, value, ttl)
			end)
			if not ok then
				warnOnce("MemoryStore write", err)
			end
			return ok, value, nil
		end,
		hremove = function(_name: string, key: string): boolean
			local ok, err = Retry.call("Presence.Remove", function()
				map:RemoveAsync(key)
			end)
			if not ok then
				warnOnce("MemoryStore remove", err)
			end
			return ok
		end,
	}
end

local function fakeBackend(): PresenceLogic.Backend
	return {
		hget = fake.hget,
		hupdate = fake.hupdate,
		hremove = fake.hremove,
	}
end

-- Opens the map and subscribes the invitation topic (once, from FriendService.Start). Yields.
function Presence.init(onInvite: (message: any) -> ())
	inviteHandler = onInvite
	local backend: PresenceLogic.Backend = fakeBackend()
	if not RunService:IsStudio() then
		local ok, result = pcall(function()
			return MemoryStoreService:GetHashMap(F.presenceMap)
		end)
		if ok then
			backend = storeBackend(result)
			live = true
		else
			warnOnce("MemoryStore", result)
		end
	end
	-- before the yielding subscribe: an early write already reaches the real map
	reader = PresenceLogic.reader(backend, os.time)
	if not RunService:IsStudio() then
		local subscribed, err = pcall(function()
			MessagingService:SubscribeAsync(F.inviteTopic, function(packet)
				inviteHandler(packet.Data)
			end)
		end)
		if subscribed then
			messaging = true
		else
			warnOnce("MessagingService", err)
		end
	end
	if not messaging then
		fake:subscribe(function(message: { [string]: any })
			inviteHandler(message)
		end)
	end
end

local function need(): PresenceLogic.Reader
	local r = reader
	if r then
		return r
	end
	-- before init (tests; in the game init sets the reader before it yields): the fake keeps everything in memory
	local made = PresenceLogic.reader(fakeBackend(), os.time)
	reader = made
	return made
end

-- Writes (or refreshes) a player's entry. Yields.
function Presence.write(userId: number, rec: PresenceLogic.Record): boolean
	return need().write(userId, rec)
end

-- Drops a player's entry (left, or appears offline now). Yields.
function Presence.remove(userId: number): boolean
	return need().remove(userId)
end

-- The entry of a player on any server: ("ok" | "fail" | "wait", record?). Yields (MemoryStore), cached.
function Presence.read(
	userId: number,
	priority: PresenceLogic.Priority
): (PresenceLogic.ReadState, PresenceLogic.Record?)
	return need().read(userId, priority)
end

function Presence.forget(userId: number)
	need().forget(userId)
end

function Presence.stats(): PresenceLogic.BudgetStats
	return need().budget.stats()
end

-- Whether the real services are in use (admin).
function Presence.mode(): string
	return if live then "memorystore" else "fake"
end

-- Publishes a party invitation to every server. Yields. Returns ok.
function Presence.publish(message: { [string]: any }): boolean
	if not messaging then
		return fake.publish(message)
	end
	local ok, err = Retry.call("FriendInvite.Publish", function()
		MessagingService:PublishAsync(F.inviteTopic, message)
	end)
	if not ok then
		warnOnce("MessagingService publish", err)
	end
	return ok
end

return Presence
