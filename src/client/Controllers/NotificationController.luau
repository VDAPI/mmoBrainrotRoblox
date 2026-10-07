--!strict
-- Server notifications: "Toast" (key, args?, kind?) -> toast stack; "SystemMessage" (key, args?) -> the
-- chat's system channel (admin replies); "Announce" (key, args?) -> golden banner + system chat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ItemText = require(script.Parent.Parent.UI.ItemText)
local Net = require(ReplicatedStorage.Shared.Net)
local Text = require(script.Parent.Parent.UI.Text)
local Announcement = require(script.Parent.Parent.UI.Components.Announcement)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local NotificationController = {
	Name = "NotificationController",
	Deps = { "UIController" },
}

local KINDS = { info = true, success = true, warning = true, error = true }

-- Player-provided values (names) must not inject rich text tags. Values starting with "@" are localization keys,
-- "#item:<id>:<up>" are item names.
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
			elseif string.sub(value, 1, 6) == "#item:" then
				-- "#item:<id>:<up>" = an item name (generated names need the item definition).
				value = ItemText.resolveArg(value) or value
			else
				value = string.gsub(value, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" })
			end
		end
		out[key] = value
	end
	return out
end

function NotificationController.ResolveArgs(args: any): { [string]: any }?
	return escapeArgs(args)
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
	-- Server-wide announcements (legendary drops, +7..+9 upgrades): golden banner + system chat; a mythic drop
	-- (loot.announceMythic*, S30) gets the stronger red banner.
	Net.On("Announce", function(key: string, args: any)
		local text = Text.now(key, escapeArgs(args))
		local mythic = type(key) == "string" and string.find(key, "announceMythic", 1, true) ~= nil
		Announcement.push(text, if mythic then "mythic" else nil)
		NotificationController.System(text)
	end)
end

return NotificationController
