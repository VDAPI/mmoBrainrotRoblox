--!strict
-- Server notifications: "Toast" (key, args?, kind?) -> toast stack; "SystemMessage" (key, args?) -> the
-- chat's system channel (admin replies, announcements).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Net = require(ReplicatedStorage.Shared.Net)
local Text = require(script.Parent.Parent.UI.Text)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local NotificationController = {
	Name = "NotificationController",
	Deps = { "UIController" },
}

local KINDS = { info = true, success = true, warning = true, error = true }

-- Player-provided values (names) must not inject rich text tags. Values starting with "@" are localization keys.
local function escapeArgs(args: any): { [string]: any }?
	if type(args) ~= "table" then
		return nil
	end
	local out = {}
	for key, value in args do
		if type(value) == "string" then
			if string.sub(value, 1, 1) == "@" then
				-- "@monster.wolf.normal" = a localization key, translated in the viewer's language.
				value = Text.now(string.sub(value, 2))
			else
				value = string.gsub(value, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" })
			end
		end
		out[key] = value
	end
	return out
end

local systemChannel: TextChannel? = nil

local function getSystemChannel(): TextChannel?
	if systemChannel and systemChannel.Parent then
		return systemChannel
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels and channels:FindFirstChild("RBXSystem")
	systemChannel = if channel and channel:IsA("TextChannel") then channel else nil
	return systemChannel
end

function NotificationController.Show(key: string, args: { [string]: any }?, kind: Toast.Kind?)
	Toast.push(Text.now(key, args), kind)
end

function NotificationController.System(text: string)
	local channel = getSystemChannel()
	if channel then
		channel:DisplaySystemMessage(text)
	else
		Toast.push(text, "info")
	end
end

function NotificationController.Start()
	Net.On("Toast", function(key: string, args: any, kind: any)
		local safeKind: Toast.Kind = if type(kind) == "string" and KINDS[kind] then kind :: Toast.Kind else "info"
		Toast.push(Text.now(key, escapeArgs(args)), safeKind)
	end)
	Net.On("SystemMessage", function(key: string, args: any)
		NotificationController.System(Text.now(key, escapeArgs(args)))
	end)
end

return NotificationController
