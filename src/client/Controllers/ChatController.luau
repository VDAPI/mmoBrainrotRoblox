--!strict
-- Chat look (DESIGN §23, S13): every line gets its channel colour and label (General, Trade, Party, Guild,
-- Whisper), the speaker's character name instead of the Roblox name, the guild tag and the VIP star
-- (S14, player attribute "Vip"). System lines without their own colour are drawn in gold.
-- Channels: RBXGeneral (server), Trade (ChatService), party (PartyService), guild (GuildService),
-- whispers through Roblox's /w name.

local Players = game:GetService("Players")
local TextChatService = game:GetService("TextChatService")

local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local ChatController = {
	Name = "ChatController",
}

local COLORS: { [string]: Color3 } = {
	general = Theme.Colors.Text,
	trade = Color3.fromHex("#E0A23B"),
	party = Color3.fromHex("#6FB3FF"),
	guild = Color3.fromHex("#6FD38A"),
	whisper = Color3.fromHex("#D58CFF"),
	system = Theme.Colors.GoldBright,
}

local function escape(text: string): string
	return (string.gsub(text, "[<>&]", { ["<"] = "&lt;", [">"] = "&gt;", ["&"] = "&amp;" }))
end

local function kindOf(channel: TextChannel?): string?
	if not channel then
		return nil
	end
	local tagged = channel:GetAttribute("VaelthornChannel")
	if type(tagged) == "string" then
		return tagged
	end
	if channel.Name == "RBXGeneral" then
		return "general"
	elseif channel.Name == "RBXSystem" then
		return "system"
	elseif string.sub(channel.Name, 1, 10) == "RBXWhisper" then
		return "whisper"
	end
	return nil
end

local function onIncoming(message: TextChatMessage): TextChatMessageProperties?
	local properties = Instance.new("TextChatMessageProperties")
	local kind = kindOf(message.TextChannel)
	local source = message.TextSource
	if source then
		local player = Players:GetPlayerByUserId(source.UserId)
		local model = player and player.Character
		local charName = model and model:GetAttribute("CharName")
		local tag = model and model:GetAttribute("GuildTag")
		local color = COLORS[kind or "general"] or Theme.Colors.Text
		local parts = {}
		if kind and kind ~= "general" then
			table.insert(parts, `<font color="#{color:ToHex()}">[{Text.now(`chat.channel.{kind}`)}]</font>`)
		end
		if type(tag) == "string" and tag ~= "" then
			table.insert(parts, `<font color="#{Theme.Colors.Gold:ToHex()}">[{escape(tag)}]</font>`)
		end
		if player and player:GetAttribute("Vip") == true then
			table.insert(parts, `<font color="#{Theme.Colors.GoldBright:ToHex()}">★</font>`)
		end
		local name = if type(charName) == "string" then charName else (if player then player.DisplayName else "?")
		table.insert(parts, `<font color="#{color:ToHex()}"><b>{escape(name)}:</b></font>`)
		properties.PrefixText = table.concat(parts, " ")
	elseif kind == "system" or kind == nil then
		if not string.find(message.Text, "<font", 1, true) then
			properties.Text = `<font color="#{COLORS.system:ToHex()}">{message.Text}</font>`
		end
	end
	return properties
end

function ChatController.Start()
	TextChatService.OnIncomingMessage = onIncoming
end

return ChatController
