--!strict
-- Player-to-player on the client (S10): duel, trade and guild (S12) invitations (popup with Accept / Decline and a
-- countdown), the trade window (opens with state `trade`, closing it cancels the trade) and the kill feed
-- (right side, map-local, 5 s per line).
-- S133: friend requests (the same popup), whispers by character name (the private channel of the pair, opened by the
-- server, becomes the chat target), letters ("write to"), friends and ignored players (confirmations, the friends
-- window).
-- S150: the friends window sends FriendsWatch while it is open (the server publishes the runtime branch `friends`) and
-- every Config.Friends.hintEvery the user ids of Roblox friends this client sees in this game
-- (Player:GetFriendsOnlineAsync, client only); "Join" (FriendJoin), party invitations to another server
-- (FriendPartyInvite) and their popup ("Join and enter the party", FriendPartyRespond).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ActionMenu = require(script.Parent.Parent.UI.Components.ActionMenu)
local Button = require(script.Parent.Parent.UI.Components.Button)
local Config = require(ReplicatedStorage.Shared.Config)
local FriendsWindow = require(script.Parent.Parent.UI.Screens.FriendsWindow)
local MailDraft = require(script.Parent.Parent.UI.MailDraft)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local TradeWindow = require(script.Parent.Parent.UI.Screens.TradeWindow)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SocialController = {
	Name = "SocialController",
	Deps = { "WindowManager", "UIController" },
}

local FEED_SECONDS = 5
local FEED_MAX = 5

local scope = Fusion.scoped(Fusion)
local WindowManager: any

type InviteKind = "duel" | "trade" | "guild" | "friend" | "friendParty"
type Invite = { kind: InviteKind, from: string, left: number, guild: string? }
local invite = scope:Value(nil :: Invite?)
local feed = scope:Value({} :: { { text: string, at: number } })
local sheetScope: Fusion.Scope<typeof(Fusion)>? = nil -- S150: the "..." action sheet of a friend row
local UIController: any

local function invoke(name: string, ...: any): boolean
	local ok, err = Net.Invoke(name, ...)
	if not ok then
		Sounds.play("error")
		Toast.push(Text.now(err or "error.internal"), "error")
	end
	return ok
end

function SocialController.Challenge(userId: number)
	task.spawn(function()
		if invoke("DuelChallenge", userId) then
			Toast.push(Text.now("duel.sent"), "success")
		end
	end)
end

function SocialController.RequestTrade(userId: number)
	task.spawn(function()
		if invoke("TradeRequest", userId) then
			Toast.push(Text.now("trade.sent"), "success")
		end
	end)
end

-- S133 ------------------------------------------------------------------------------------------------------------

-- Opens the letter window addressed to `name` ("" = choose the recipient there).
function SocialController.ComposeTo(name: string)
	MailDraft.To:set(name)
	MailDraft.Fresh:set(Fusion.peek(MailDraft.Fresh) + 1)
	WindowManager.Open("mailCompose")
end

-- "<name> is on another server: write a letter?"
local function offerLetter(name: string)
	WindowManager.ShowModal({
		Title = Text.now("social.whisper.otherServerTitle"),
		Message = Text.now("social.whisper.otherServer", { name = name }),
		ConfirmText = Text.now("mail.write"),
		CancelText = Text.now("common.cancel"),
		OnConfirm = function()
			SocialController.ComposeTo(name)
			return true
		end,
	})
end

-- The whisper channel of the pair with `userId` (found by its attributes: the client renames its tab).
local function whisperChannel(userId: number): TextChannel?
	local me = Players.LocalPlayer.UserId
	local a, b = math.min(me, userId), math.max(me, userId)
	for _, child in TextChatService:GetChildren() do
		if child:IsA("TextChannel") and child:GetAttribute("WhisperA") == a and child:GetAttribute("WhisperB") == b then
			return child
		end
	end
	return nil
end

-- Makes the private channel the chat target and sends `text` when there is any (TextChatService filters it).
local function focusWhisper(userId: number, name: string, text: string)
	local channel = whisperChannel(userId)
	local deadline = os.clock() + 5
	while not channel and os.clock() < deadline do
		task.wait(0.1)
		channel = whisperChannel(userId)
	end
	if not channel then
		Toast.push(Text.now("error.internal"), "error")
		return
	end
	local config = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if config then
		config.TargetTextChannel = channel
	end
	if text ~= "" then
		local c = channel :: TextChannel
		pcall(function()
			c:SendAsync(text)
		end)
	else
		Toast.push(Text.now("social.whisper.ready", { name = name }), "info", 5)
	end
end

local function failed(err: string?, name: string)
	if err == "social.whisper.otherServer" then
		offerLetter(name)
		return
	end
	Sounds.play("error")
	Toast.push(Text.now(err or "error.internal", { name = name }), "error")
end

-- Whisper to a player on this server.
function SocialController.Whisper(userId: number, name: string)
	task.spawn(function()
		local ok, err = Net.Invoke("WhisperOpen", userId)
		if not ok then
			failed(err, name)
			return
		end
		focusWhisper(userId, name, "")
	end)
end

function SocialController.AddFriend(userId: number)
	task.spawn(function()
		if invoke("FriendInvite", userId) then
			Toast.push(Text.now("social.friendSent"), "success")
		end
	end)
end

function SocialController.RemoveFriend(userId: number, name: string)
	WindowManager.ShowModal({
		Title = Text.now("social.confirm.unfriendTitle"),
		Message = Text.now("social.confirm.unfriend", { name = name }),
		ConfirmText = Text.now("social.menu.unfriend"),
		CancelText = Text.now("common.cancel"),
		Variant = "danger",
		OnConfirm = function()
			task.spawn(function()
				if invoke("FriendRemove", userId) then
					Toast.push(Text.now("social.unfriended", { name = name }), "info")
				end
			end)
			return true
		end,
	})
end

local function confirmIgnore(name: string, run: () -> boolean)
	WindowManager.ShowModal({
		Title = Text.now("social.confirm.ignoreTitle"),
		Message = Text.now("social.confirm.ignore", { name = name }),
		ConfirmText = Text.now("social.menu.ignore"),
		CancelText = Text.now("common.cancel"),
		Variant = "danger",
		OnConfirm = function()
			task.spawn(function()
				if run() then
					Toast.push(Text.now("social.ignoredNow", { name = name }), "info")
				end
			end)
			return true
		end,
	})
end

function SocialController.Ignore(userId: number, name: string)
	confirmIgnore(name, function()
		return invoke("IgnoreAdd", userId)
	end)
end

-- A character by name, on any server or offline (a letter's sender, the friends window).
function SocialController.IgnoreByName(name: string)
	if name == "" then
		return
	end
	confirmIgnore(name, function()
		return invoke("IgnoreName", name)
	end)
end

function SocialController.Unignore(userId: number, name: string)
	task.spawn(function()
		if invoke("IgnoreRemove", userId) then
			Toast.push(Text.now("social.unignored", { name = name }), "info")
		end
	end)
end

function SocialController.InviteParty(userId: number, name: string)
	task.spawn(function()
		if invoke("PartyInviteUser", userId) then
			Toast.push(Text.now("party.inviteSent", { name = name }), "success")
		end
	end)
end

-- S150 ------------------------------------------------------------------------------------------------------------

-- Moves to the friend's server (the server checks everything; a teleport ends this client).
function SocialController.Join(userId: number)
	task.spawn(invoke, "FriendJoin", userId)
end

-- Invite to party: the S133 invitation on this server, an invitation through the topic on another one.
function SocialController.InviteFriendParty(userId: number, name: string, here: boolean)
	if here then
		SocialController.InviteParty(userId, name)
		return
	end
	task.spawn(function()
		if invoke("FriendPartyInvite", userId) then
			Toast.push(Text.now("friends.party.sent", { name = name }), "success")
		end
	end)
end

local function closeSheet()
	local s = sheetScope
	sheetScope = nil
	if s then
		s:doCleanup()
	end
end

-- The "..." action sheet of a friend row: the enabled entries as buttons.
function SocialController.Sheet(title: string, entries: { any }, run: (id: string) -> ())
	closeSheet()
	local options: { ActionMenu.Option } = {}
	for _, entry in entries do
		table.insert(options, {
			label = Text.now(entry.labelKey),
			variant = if entry.id == "remove" or entry.id == "ignore" then "danger" else "secondary",
			run = function()
				run(entry.id)
			end,
		})
	end
	if #options == 0 then
		return
	end
	local s = scope:innerScope()
	sheetScope = s
	ActionMenu(s, {
		Title = title,
		Options = options,
		CancelText = Text.now("common.cancel"),
		Close = closeSheet,
	}).Parent =
		UIController.GetLayer("Modals")
end

-- The user ids of Roblox friends in this game (client API with a 30 s cache), at most Config.Friends.robloxHint.
local function robloxFriendsHere(): { number }
	local player: any = Players.LocalPlayer
	local ok, list = pcall(function()
		return player:GetFriendsOnlineAsync(Config.Friends.robloxMax)
	end)
	if not ok then
		ok, list = pcall(function()
			return player:GetFriendsOnline(Config.Friends.robloxMax)
		end)
	end
	local out: { number } = {}
	if not ok or type(list) ~= "table" then
		return out
	end
	for _, friend in list do
		if
			type(friend) == "table"
			and friend.PlaceId == game.PlaceId
			and type(friend.VisitorId) == "number"
			and #out < Config.Friends.robloxHint
		then
			table.insert(out, friend.VisitorId)
		end
	end
	return out
end

local function respond(accept: boolean)
	local current = Fusion.peek(invite)
	invite:set(nil)
	if current then
		local remote = if current.kind == "duel"
			then "DuelRespond"
			elseif current.kind == "guild" then "GuildRespond"
			elseif current.kind == "friend" then "FriendRespond"
			elseif current.kind == "friendParty" then "FriendPartyRespond"
			else "TradeRespond"
		task.spawn(invoke, remote, accept)
	end
end

local function showInvite(kind: InviteKind, from: string, seconds: number, guild: string?)
	Sounds.play("levelUp")
	local entry: Invite = { kind = kind, from = from, left = seconds, guild = guild }
	invite:set(entry)
	task.spawn(function()
		while Fusion.peek(invite) == entry and entry.left > 0 do
			task.wait(1)
			if Fusion.peek(invite) ~= entry then
				return
			end
			local updated = table.clone(entry)
			updated.left -= 1
			entry = updated
			invite:set(updated)
		end
		if Fusion.peek(invite) == entry then
			invite:set(nil)
		end
	end)
end

local function invitePopup(): Instance
	return scope:New("Frame")({
		Name = "SocialInvite",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 260),
		Size = UDim2.fromOffset(460, 130),
		BackgroundColor3 = Theme.Iron.Surface,
		Visible = scope:Computed(function(use): boolean
			return use(invite) ~= nil
		end),
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Medium }),
			scope:New("UIStroke")({ Color = Theme.Brass.Line, Thickness = 1.5 }),
			scope:New("TextLabel")({
				Position = UDim2.fromOffset(16, 10),
				Size = UDim2.new(1, -32, 0, 50),
				BackgroundTransparency = 1,
				TextWrapped = true,
				Text = scope:Computed(function(use): string
					local i = use(invite)
					if not i then
						return ""
					end
					local key = if i.kind == "duel"
						then "duel.invited"
						elseif i.kind == "guild" then "guild.invited"
						elseif i.kind == "friend" then "social.friendInvited"
						elseif i.kind == "friendParty" then "friends.party.invited"
						else "trade.invited"
					return Text.get(use, key, { name = i.from, seconds = i.left, guild = i.guild or "" })
				end),
				FontFace = Theme.Fonts.BodyBold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Iron.Text,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				Position = UDim2.new(0, 16, 1, -62),
				Size = UDim2.new(0.5, -24, 0, 50),
				Variant = "primary",
				Text = scope:Computed(function(use): string
					local i = use(invite)
					return Text.get(
						use,
						if i and i.kind == "friendParty" then "friends.party.accept" else "party.accept"
					)
				end),
				OnClick = function()
					respond(true)
				end,
			}),
			Button(scope, {
				Surface = "iron", -- S135: on a dark HUD / overlay surface
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 1, -62),
				Size = UDim2.new(0.5, -24, 0, 50),
				Text = scope:Computed(function(use): string
					local i = use(invite)
					return Text.get(
						use,
						if i and i.kind == "friendParty" then "friends.party.decline" else "party.decline"
					)
				end),
				OnClick = function()
					respond(false)
				end,
			}),
		},
	})
end

local function killFeed(): Instance
	local rows = scope:Computed(function(use, s: Scope): { Instance }
		local list = {}
		for i, entry in use(feed) do
			table.insert(
				list,
				s:New("TextLabel")({
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, 26),
					BackgroundColor3 = Theme.Iron.Surface,
					BackgroundTransparency = 0.35,
					Text = entry.text,
					FontFace = Theme.Fonts.BodyBold,
					TextSize = Theme.TextSize.Small,
					TextColor3 = Theme.Iron.Text,
					TextXAlignment = Enum.TextXAlignment.Right,
					[Children] = {
						s:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
						s:New("UIPadding")({ PaddingRight = UDim.new(0, 8) }),
					},
				})
			)
		end
		return list
	end)
	return scope:New("Frame")({
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -Theme.Padding.Large - 320, 0, 300),
		Size = UDim2.fromOffset(340, FEED_MAX * 30),
		BackgroundTransparency = 1,
		[Children] = {
			scope:New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
			}),
			rows :: any,
		},
	})
end

function SocialController.Init(registry)
	WindowManager = registry.Get("WindowManager")
	UIController = registry.Get("UIController")
	WindowManager.Register({
		id = "trade",
		titleKey = "window.trade.title",
		size = Vector2.new(640, 520),
		build = TradeWindow,
	})
	-- S133: friends and ignored players (key win_friends)
	WindowManager.Register({
		id = "friends",
		titleKey = "window.friends.title",
		size = Vector2.new(700, 640),
		hotkey = Enum.KeyCode.Y, -- a fallback: WindowManager follows the win_friends action
		build = function(s)
			return FriendsWindow(s, {
				Actions = {
					Join = SocialController.Join,
					Party = SocialController.InviteFriendParty,
					Whisper = SocialController.Whisper,
					Mail = SocialController.ComposeTo,
					Remove = SocialController.RemoveFriend,
					Ignore = SocialController.Ignore,
					AddFriend = SocialController.AddFriend,
					Unignore = SocialController.Unignore,
					IgnoreName = SocialController.IgnoreByName,
					Sheet = SocialController.Sheet,
					Setting = function(name: string, value: any)
						Net.Send("SetSetting", name, value)
					end,
				},
			})
		end,
	})
	invitePopup().Parent = UIController.GetLayer("Modals")
	killFeed().Parent = UIController.GetLayer("Screens")
end

function SocialController.Start()
	Net.On("DuelInvited", function(from: string, seconds: number)
		showInvite("duel", from, seconds)
	end)
	Net.On("TradeInvited", function(from: string, seconds: number)
		showInvite("trade", from, seconds)
	end)
	Net.On("GuildInvited", function(guildName: string, tag: string, from: string, seconds: number)
		showInvite("guild", from, seconds, `[{tag}] {guildName}`)
	end)
	-- S133: friend requests, "/w" results
	Net.On("FriendInvited", function(from: string, seconds: number)
		showInvite("friend", from, seconds)
	end)
	Net.On("WhisperReady", function(channelName: string, name: string, text: string)
		local a, b = string.match(channelName, "^Whisper_(%d+)_(%d+)$")
		local me = Players.LocalPlayer.UserId
		local other = if tonumber(a) == me then tonumber(b) else tonumber(a)
		if other then
			task.spawn(focusWhisper, other, name, text)
		end
	end)
	Net.On("WhisperFailed", function(err: string, name: string)
		failed(err, name)
	end)
	-- S150: party invitations from another server
	Net.On("FriendPartyInvited", function(from: string, _level: number, _class: string, seconds: number)
		showInvite("friendParty", from, seconds)
	end)
	-- S150: the server publishes `friends` while the window is open; the client adds the Roblox friends it sees here.
	local friendsOpen = WindowManager.IsOpen("friends")
	scope:Observer(friendsOpen):onChange(function()
		local open = Fusion.peek(friendsOpen)
		Net.Send("FriendsWatch", open)
		if not open then
			closeSheet()
		end
	end)
	task.spawn(function()
		local last = -math.huge
		while true do
			task.wait(1)
			if Fusion.peek(friendsOpen) and os.clock() - last >= Config.Friends.hintEvery then
				last = os.clock()
				Net.Send("FriendsRobloxHint", robloxFriendsHere())
			end
		end
	end)
	Net.On("KillFeed", function(killer: string, victim: string)
		local list = table.clone(Fusion.peek(feed))
		table.insert(list, { text = `{killer}  ⚔  {victim}`, at = os.clock() })
		while #list > FEED_MAX do
			table.remove(list, 1)
		end
		feed:set(list)
		task.delay(FEED_SECONDS, function()
			local current = Fusion.peek(feed)
			local kept = {}
			for _, entry in current do
				if os.clock() - entry.at < FEED_SECONDS then
					table.insert(kept, entry)
				end
			end
			feed:set(kept)
		end)
	end)

	-- The trade window follows the trade state; closing it cancels the trade.
	local tradeOpen = WindowManager.IsOpen("trade")
	scope:Observer(State.Value({ "trade" })):onChange(function()
		if State.Get({ "trade" }) ~= nil then
			if not Fusion.peek(tradeOpen) then
				WindowManager.Open("trade") -- brings the companion backpack (WindowRules)
			end
		elseif Fusion.peek(tradeOpen) then
			WindowManager.Close("trade") -- cancelled or done: the companion backpack closes with it
		end
	end)
	scope:Observer(tradeOpen):onChange(function()
		if not Fusion.peek(tradeOpen) and State.Get({ "trade" }) ~= nil then
			Net.Send("TradeCancel")
		end
	end)
end

return SocialController
