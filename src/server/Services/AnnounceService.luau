--!strict
-- Server-wide and cross-server announcements (legendary drops, +7..+9 upgrades). Server(key, args) shows a
-- banner + chat line to everyone on this server; Global(key, globalKey, args) also publishes to other servers
-- through MessagingService (rate limited, disabled in Studio). Item names travel as "#item:<id>:<up>" args.
-- S131: a cross-server message inside the rate gap (Config.Announce.globalGap) is no longer dropped: it waits in a
-- short queue (at most Config.Announce.queueMax, the oldest dropped beyond it) sent one per gap, so the Blood Moon
-- winners and the tournament champions reach every server even when they come together.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net)

local log = Log.new("AnnounceService")

local AnnounceService = {
	Name = "AnnounceService",
}

local TOPIC = "GlobalAnnounce"

type Outgoing = { from: string, key: string, args: { [string]: any } }

local serverId = HttpService:GenerateGUID(false)
local lastGlobal = -math.huge
local queue: { Outgoing } = {}
local draining = false

function AnnounceService.Server(key: string, args: { [string]: any })
	Net.FireAll("Announce", key, args)
end

local function publish(message: Outgoing)
	lastGlobal = os.clock()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, message)
	end)
	if not ok then
		log:warn("publish failed: %s", tostring(err))
	end
end

-- Sends the queued messages one per gap (one drain thread at a time).
local function drain()
	if draining then
		return
	end
	draining = true
	task.spawn(function()
		while #queue > 0 do
			local wait = Config.Announce.globalGap - (os.clock() - lastGlobal)
			if wait > 0 then
				task.wait(wait)
			end
			local message = table.remove(queue, 1)
			if message then
				publish(message)
			end
		end
		draining = false
	end)
end

-- `globalKey` is the variant shown on other servers ("... (another server)").
function AnnounceService.Global(key: string, globalKey: string, args: { [string]: any })
	AnnounceService.Server(key, args)
	if RunService:IsStudio() then
		return
	end
	table.insert(queue, { from = serverId, key = globalKey, args = args })
	while #queue > Config.Announce.queueMax do
		table.remove(queue, 1)
	end
	drain()
end

function AnnounceService.Start()
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if type(data) == "table" and data.from ~= serverId and type(data.key) == "string" then
					AnnounceService.Server(data.key, if type(data.args) == "table" then data.args else {})
				end
			end)
		end)
		if not ok then
			log:warn("cannot subscribe to %s: %s", TOPIC, tostring(err))
		end
	end)
end

return AnnounceService
