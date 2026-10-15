--!strict
-- Champion's Tournament messages between servers (S130, DESIGN-17 §8): one MessagingService topic
-- (Config.Tourney.topic) with { op = "open" | "cancel", id, b, s }: a bracket of tournament `id` got its server (the
-- record in Tourney/Store has the code and the players) or was cancelled. Never player lists or codes (1 KB limit;
-- they live in the record). A message is handled here at once and sent to the others; the echo is ignored by `s`
-- (this server's id), the wzór of Guild/Bus. Best effort: without MessagingService (Studio, an error) only this server
-- hears it, and world servers read the records themselves twice (TourneyService, Config.Tourney.recheck). Every
-- Roblox call in pcall; the in-memory path (no subscription, a local call) is the fake.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("TourneyBus")

export type Message = { op: "open" | "cancel", id: string, b: string, s: string? }

local Bus = {}

Bus.ServerId = HttpService:GenerateGUID(false)

local handler: (message: Message) -> () = function(_message: Message) end
local subscribed = false
local warned: { [string]: boolean } = {}

local function warnOnce(what: string, err: any)
	if not warned[what] then
		warned[what] = true
		log:warn("%s unavailable (%s): tournament messages stay on this server", what, tostring(err))
	end
end

local function parse(data: any): Message?
	if type(data) ~= "table" or (data.op ~= "open" and data.op ~= "cancel") then
		return nil
	end
	if type(data.id) ~= "string" or #data.id > 32 or type(data.b) ~= "string" or #data.b > 16 then
		return nil
	end
	return { op = data.op, id = data.id, b = data.b, s = if type(data.s) == "string" then data.s else nil }
end

-- Sets the handler and subscribes (yields; once). `online` = false (the local mode, Studio): only local calls.
function Bus.start(onMessage: (message: Message) -> (), online: boolean)
	handler = onMessage
	if subscribed or not online or RunService:IsStudio() then
		return
	end
	subscribed = true
	local ok, err = pcall(function()
		return MessagingService:SubscribeAsync(Config.Tourney.topic, function(packet)
			local message = parse(packet.Data)
			if message and message.s ~= Bus.ServerId then
				handler(message)
			end
		end)
	end)
	if not ok then
		subscribed = false
		warnOnce("MessagingService", err)
	end
end

-- Handles the message here at once and sends it to the other servers (when `online`).
function Bus.publish(message: Message, online: boolean)
	message.s = Bus.ServerId
	task.spawn(handler, message)
	if not online or RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(Config.Tourney.topic, message)
		end)
		if not ok then
			warnOnce("MessagingService", err)
		end
	end)
end

return Bus
