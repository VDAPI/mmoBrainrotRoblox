--!strict
-- Cross-server plumbing for guilds (DESIGN §19):
--   * MessagingService topic "Guild_<id>": change notices, chat lines, system lines, presence. A message is
--     handled on the sending server right away (no round trip) and its echo is ignored there.
--   * MemoryStore HashMap Config.GuildPresenceMap: one entry per guild { [memberKey] = { j = jobId, t } };
--     entries older than Config.GuildPresenceTtl count as offline.
-- Everything is best effort (pcall): without these services guilds still work on a single server.

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("GuildBus")

export type Message = { op: string, [string]: any }

local Bus = {}

-- Identifies this server in messages (JobId is empty in Studio).
Bus.ServerId = HttpService:GenerateGUID(false)
Bus.JobId = if game.JobId ~= "" then game.JobId else "studio"

local handler: (guildId: string, message: Message) -> () = function(_guildId: string, _message: Message) end
local subscriptions: { [string]: RBXScriptConnection | boolean } = {}
local presenceMap: MemoryStoreHashMap? = nil
local warned: { [string]: boolean } = {}

local function warnOnce(what: string, err: any)
	if not warned[what] then
		warned[what] = true
		log:warn("%s unavailable (%s), guild data stays server-local for this feature", what, tostring(err))
	end
end

local function topic(guildId: string): string
	return `Guild_{guildId}`
end

function Bus.init(onMessage: (guildId: string, message: Message) -> ())
	handler = onMessage
	local ok, map = pcall(function()
		return MemoryStoreService:GetHashMap(Config.GuildPresenceMap)
	end)
	presenceMap = if ok then map else nil
end

-- Yields. Safe to call repeatedly.
function Bus.subscribe(guildId: string)
	if subscriptions[guildId] then
		return
	end
	subscriptions[guildId] = true -- placeholder while SubscribeAsync yields
	local ok, connection = pcall(function()
		return MessagingService:SubscribeAsync(topic(guildId), function(packet)
			local message = packet.Data
			if type(message) == "table" and message.s ~= Bus.ServerId and type(message.op) == "string" then
				handler(guildId, message)
			end
		end)
	end)
	if not ok then
		warnOnce("MessagingService", connection)
		return
	end
	if subscriptions[guildId] == true then
		subscriptions[guildId] = connection
	else
		(connection :: RBXScriptConnection):Disconnect() -- unsubscribed while connecting
	end
end

function Bus.unsubscribe(guildId: string)
	local connection = subscriptions[guildId]
	subscriptions[guildId] = nil
	if typeof(connection) == "RBXScriptConnection" then
		connection:Disconnect()
	end
end

-- Handles the message here at once and sends it to the other servers.
function Bus.publish(guildId: string, message: Message)
	message.s = Bus.ServerId
	task.spawn(handler, guildId, message)
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(topic(guildId), message)
		end)
		if not ok then
			warnOnce("MessagingService", err)
		end
	end)
end

-- Presence ----------------------------------------------------------------------------------------

-- Marks members online (jobId) or offline (nil). Yields.
function Bus.setPresence(guildId: string, changes: { [string]: boolean })
	local map = presenceMap
	if not map then
		return
	end
	local now = os.time()
	local ok, err = pcall(function()
		map:UpdateAsync(guildId, function(current: any)
			local value = if type(current) == "table" then current else {}
			for key, entry in value do
				if type(entry) ~= "table" or now - (entry.t or 0) > Config.GuildPresenceTtl then
					value[key] = nil
				end
			end
			for key, online in changes do
				value[key] = if online then { j = Bus.JobId, t = now } else nil
			end
			return value
		end, Config.GuildPresenceTtl * 3)
	end)
	if not ok then
		warnOnce("MemoryStore", err)
	end
end

-- Online members of a guild on any server: { [memberKey] = jobId }. Yields. nil when unavailable.
function Bus.readPresence(guildId: string): { [string]: string }?
	local map = presenceMap
	if not map then
		return nil
	end
	local ok, value = pcall(function()
		return map:GetAsync(guildId)
	end)
	if not ok then
		warnOnce("MemoryStore", value)
		return nil
	end
	local result = {}
	local now = os.time()
	if type(value) == "table" then
		for key, entry in value do
			if type(entry) == "table" and now - (entry.t or 0) <= Config.GuildPresenceTtl then
				result[key] = tostring(entry.j)
			end
		end
	end
	return result
end

return Bus
