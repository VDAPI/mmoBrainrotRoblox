--!strict
-- Chat channels (DESIGN §23, S13). Roblox already provides General (RBXGeneral), system lines (RBXSystem)
-- and whispers (/w name, RBXWhisper). This adds the server-wide Trade channel; party (S09) and guild (S12)
-- channels are made by their services. Channel tabs are switched on so every channel is one click away;
-- colours and name prefixes are applied on the client (ChatController). Filtering and flood protection are
-- TextChatService's own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Log = require(ReplicatedStorage.Shared.Util.Log)

local log = Log.new("ChatService")

local ChatService = {
	Name = "ChatService",
}

local trade: TextChannel? = nil

local function join(player: Player)
	local channel = trade
	if channel then
		task.spawn(function()
			local ok, err = pcall(function()
				channel:AddUserAsync(player.UserId)
			end)
			if not ok then
				log:warn("could not add %s to the trade channel: %s", player.Name, tostring(err))
			end
		end)
	end
end

function ChatService.Start()
	pcall(function()
		local tabs = TextChatService:FindFirstChildOfClass("ChannelTabsConfiguration")
		if tabs then
			tabs.Enabled = true
		end
	end)
	local channel = Instance.new("TextChannel")
	channel.Name = "⚖ Trade"
	channel:SetAttribute("VaelthornChannel", "trade")
	channel.Parent = TextChatService
	trade = channel
	for _, player in Players:GetPlayers() do
		join(player)
	end
	Players.PlayerAdded:Connect(join)
end

return ChatService
