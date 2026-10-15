--!strict
-- Chat look (DESIGN §23, S13): every line gets its channel colour and label (General, Trade, Party, Guild,
-- Whisper), the speaker's character name instead of the Roblox name, the guild tag and the VIP star
-- (S14, player attribute "Vip"). System lines without their own colour are drawn in gold.
-- Channels: RBXGeneral (server), Trade (ChatService), party (PartyService), guild (GuildService),
-- whispers through Roblox's /w name.
-- S17: the tab labels of the trade and party channels are renamed locally to the player's language (the
-- server names are "⚖ Trade" and "VaelthornParty_<id>"); the tab follows TextChannel.Name.
-- S123 (DESIGN-17 §4): the chat frame cosmetic of the speaker (player attribute CosmeticChatFrame): its glyphs around
-- the character name in the line (the name keeps its channel colour, the VIP star stays next to it; the frame the
-- player chose wins over any default VIP look) and the speech bubble's colours (OnBubbleAdded; nothing when bubbles
-- are off). The message text and its filtering never change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local CosmeticRules = require(ReplicatedStorage.Shared.Logic.CosmeticRules)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
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

-- S123: the chat frame cosmetic of a player, nil without one.
local function chatFrameOf(player: Player?): Cosmetics.Def?
	local id = player and player:GetAttribute("CosmeticChatFrame")
	local def = if type(id) == "string" then Cosmetics.get(id) else nil
	return if def and def.kind == "chatframe" then def else nil
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
		local decor = CosmeticRules.chatDecor(chatFrameOf(player))
		if decor then
			local around = Color3.fromHex(decor.color):ToHex()
			local own = color:ToHex()
			local left = `<font color="#{around}">{escape(decor.left)}</font>`
			local right = `<font color="#{around}">{escape(decor.right)}</font>`
			table.insert(
				parts,
				`{left}<font color="#{own}"><b>{escape(name)}</b></font>{right}<font color="#{own}"><b>:</b></font>`
			)
		else
			table.insert(parts, `<font color="#{color:ToHex()}"><b>{escape(name)}:</b></font>`)
		end
		properties.PrefixText = table.concat(parts, " ")
	elseif kind == "system" or kind == nil then
		if not string.find(message.Text, "<font", 1, true) then
			properties.Text = `<font color="#{COLORS.system:ToHex()}">{message.Text}</font>`
		end
	end
	return properties
end

local TAB_ICONS: { [string]: string } = { trade = "⚖", party = "☍" }

local function relabel(channel: Instance)
	if not channel:IsA("TextChannel") then
		return
	end
	local kind = channel:GetAttribute("VaelthornChannel")
	local icon = if type(kind) == "string" then TAB_ICONS[kind] else nil
	if icon then
		pcall(function()
			channel.Name = `{icon} {Text.now(`chat.channel.{kind}`)}`
		end)
	end
end

-- S123: the speech bubble in the colours of the speaker's chat frame (nil = the default bubble).
local function onBubble(message: TextChatMessage, _adornee: Instance): any
	local source = message.TextSource
	local player = source and Players:GetPlayerByUserId(source.UserId)
	local bubble = CosmeticRules.bubble(chatFrameOf(player))
	if not bubble then
		return nil
	end
	local ok, properties = pcall(function(): Instance
		local p = Instance.new("BubbleChatMessageProperties")
		p.BackgroundColor3 = Color3.fromHex(bubble.bg)
		p.TextColor3 = Color3.fromHex(bubble.text)
		return p
	end)
	return if ok then properties else nil
end

function ChatController.Start()
	TextChatService.OnIncomingMessage = onIncoming
	-- S123: typed loosely: the callback may be missing from older analyzer definitions (create.roblox.com:
	-- TextChatService.OnBubbleAdded(message, adornee) -> BubbleChatMessageProperties?)
	pcall(function()
		(TextChatService :: any).OnBubbleAdded = onBubble
	end)
	for _, child in TextChatService:GetChildren() do
		relabel(child)
	end
	TextChatService.ChildAdded:Connect(function(child)
		-- Attributes arrive with the instance; wait a frame so the tab is created first.
		task.defer(relabel, child)
	end)
	local scope = Fusion.scoped(Fusion)
	scope:Observer(Text.Lang):onChange(function()
		for _, child in TextChatService:GetChildren() do
			relabel(child)
		end
	end)
end

return ChatController
