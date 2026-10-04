--!strict
-- Guilds on the client (DESIGN §19): the guild window (G), the founding window at the Guild Master, and the
-- guild chat. Guild chat is a TextChannel per guild on each server (shown as a chat tab); lines typed in it
-- are also sent to the server (GuildChatSend), which relays them to members on other servers, where they
-- arrive as GuildChatLine and are displayed in the same channel. System lines (joined, promoted, upgraded)
-- arrive the same way. Invitations use SocialController's popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GuildFound = require(script.Parent.Parent.UI.Screens.GuildFound)
local GuildWindow = require(script.Parent.Parent.UI.Screens.GuildWindow)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local GuildController = {
	Name = "GuildController",
	Deps = { "WindowManager", "NotificationController" },
}

local scope = Fusion.scoped(Fusion)
local WindowManager: any
local NotificationController: any
local tab = scope:Value("overview")

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function guildChannel(): TextChannel?
	local id = State.Get({ "character", "guildId" })
	if type(id) ~= "string" then
		return nil
	end
	for _, channel in TextChatService:GetDescendants() do
		if channel:IsA("TextChannel") and channel:GetAttribute("GuildId") == id then
			return channel
		end
	end
	return nil
end

local function tagPrefix(): string
	local tag = State.Get({ "guild", "tag" })
	return if type(tag) == "string" then `[{tag}] ` else ""
end

-- Shows a line in the guild channel (falls back to the system channel while it does not exist yet).
local function display(text: string)
	local channel = guildChannel()
	if channel then
		channel:DisplaySystemMessage(text)
	else
		NotificationController.System(text)
	end
end

local function onLine(name: string?, textOrKey: string, args: any)
	if type(textOrKey) ~= "string" then
		return
	end
	if name then
		-- A player's line from another server (already filtered by the sender's server).
		local color = Theme.Colors.Success:ToHex()
		display(`<font color="#{color}">{escape(tagPrefix())}{escape(tostring(name))}:</font> {escape(textOrKey)}`)
	else
		local color = Theme.Colors.GoldBright:ToHex()
		local text = Text.now(textOrKey, NotificationController.ResolveArgs(args))
		display(`<font color="#{color}">{escape(tagPrefix())}{text}</font>`)
	end
end

function GuildController.OpenFromNpc()
	WindowManager.Close("npc")
	if State.Get({ "character", "guildId" }) then
		WindowManager.Open("guild")
	else
		WindowManager.Open("guildfound")
	end
end

function GuildController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	NotificationController = registry.Get("NotificationController")
	WindowManager.Register({
		id = "guild",
		titleKey = "window.guild.title",
		size = Vector2.new(880, 660),
		hotkey = Enum.KeyCode.G,
		build = function(s)
			return GuildWindow(s, { ShowModal = WindowManager.ShowModal, Tab = tab })
		end,
	})
	WindowManager.Register({
		id = "guildfound",
		titleKey = "window.guildfound.title",
		size = Vector2.new(600, 560),
		build = function(s, close)
			return GuildFound(s, function()
				close()
				tab:set("overview")
				WindowManager.Open("guild")
			end)
		end,
	})
end

function GuildController.Start()
	Net.On("GuildChatLine", onLine)

	-- Chat tabs: one per channel the player is in (general, party, guild).
	pcall(function()
		local tabs = TextChatService:FindFirstChildOfClass("ChannelTabsConfiguration")
		if tabs then
			tabs.Enabled = true
		end
	end)

	-- Relay own guild lines to members on other servers.
	TextChatService.SendingMessage:Connect(function(message: TextChatMessage)
		local channel = message.TextChannel
		if channel and channel:GetAttribute("GuildId") ~= nil and message.Text ~= "" then
			Net.Send("GuildChatSend", message.Text)
		end
	end)

	-- Losing the guild closes the guild channel as the chat target.
	scope:Observer(State.Value({ "character", "guildId" })):onChange(function()
		if State.Get({ "character", "guildId" }) == nil then
			tab:set("overview")
			local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
			local target = config and config.TargetTextChannel
			if config and target and target:GetAttribute("GuildId") ~= nil then
				local channels = TextChatService:FindFirstChild("TextChannels")
				local general = channels and channels:FindFirstChild("RBXGeneral")
				config.TargetTextChannel = if general and general:IsA("TextChannel") then general else nil
			end
		end
	end)
end

return GuildController
