--!strict
-- Server-wide and cross-server announcements (legendary drops, +7..+9 upgrades). Server(key, args) shows a
-- banner + chat line to everyone on this server; Global(key, globalKey, args) also publishes to other servers
-- through MessagingService (rate limited, disabled in Studio). Item names travel as "#item:<id>:<up>" args.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Log = require(ReplicatedStorage.Shared.Util.Log)
local Net = require(ReplicatedStorage.Shared.Net)

local log = Log.new("AnnounceService")

local AnnounceService = {
	Name = "AnnounceService",
}

local TOPIC = "GlobalAnnounce"
local MIN_INTERVAL = 10 -- seconds between cross-server messages from this server

local serverId = HttpService:GenerateGUID(false)
local lastGlobal = 0

function AnnounceService.Server(key: string, args: { [string]: any })
	Net.FireAll("Announce", key, args)
end

-- `globalKey` is the variant shown on other servers ("... (another server)").
function AnnounceService.Global(key: string, globalKey: string, args: { [string]: any })
	AnnounceService.Server(key, args)
	if RunService:IsStudio() or os.clock() - lastGlobal < MIN_INTERVAL then
		return
	end
	lastGlobal = os.clock()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(TOPIC, { from = serverId, key = globalKey, args = args })
		end)
		if not ok then
			log:warn("publish failed: %s", tostring(err))
		end
	end)
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
