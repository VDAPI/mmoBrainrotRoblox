--!strict
-- Per-player notices across servers (mail arrived, item sold) on one MessagingService topic. A notice for
-- a player on this server is handled locally at once; other servers handle it when it arrives.

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("Notify")

local TOPIC = "Vaelthorn_PlayerNotice"

local Notify = {}

type Handler = (player: Player, args: { [string]: any }) -> ()

local handlers: { [string]: Handler } = {}
local started = false

function Notify.on(kind: string, handler: Handler)
	handlers[kind] = handler
end

local function deliver(userId: number, kind: string, args: { [string]: any }): boolean
	local player = Players:GetPlayerByUserId(userId)
	local handler = handlers[kind]
	if player and handler then
		task.spawn(handler, player, args)
		return true
	end
	return false
end

-- Subscribes once per server. Yields.
function Notify.start()
	if started then
		return
	end
	started = true
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(packet)
			local data = packet.Data
			if type(data) == "table" and type(data.u) == "number" and type(data.k) == "string" then
				deliver(data.u, data.k, if type(data.a) == "table" then data.a else {})
			end
		end)
	end)
	if not ok then
		log:warn("MessagingService unavailable (%s): notices stay on this server", tostring(err))
	end
end

function Notify.send(userId: number, kind: string, args: { [string]: any }?)
	local payload = args or {}
	if deliver(userId, kind, payload) then
		return
	end
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { u = userId, k = kind, a = payload })
		end)
	end)
end

return Notify
