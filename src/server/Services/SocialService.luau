--!strict
-- Friends, ignored players, presence and whispers (S133).
--   * Lists in account.social (Logic/Social, limits in Config.Social). A friendship is mutual: a request needs both
--     players on this server (popup with a countdown) and the acceptance writes both accounts. Ending it (or ignoring)
--     writes the own account at once and the other one directly when that player is here; otherwise a "drop" goes to
--     the other player's record in the DataStore Config.Social.storeName ("Social_<userId>") and a Notify "socialSync"
--     makes their server apply it now (or their next login does). A drop only removes a friendship older than itself.
--   * The same record mirrors the player's ignored list, so mail (MailService) can refuse a letter from an ignored
--     player to an account that is offline or on another server.
--   * Presence across servers and the friends window: FriendService (S150, Friends/Presence). Entering the game tells
--     every server on one MessagingService topic, which toasts "<name> is in the game" to that player's friends
--     (friendAlerts); a player who appears offline (S150 account.settings.appearOffline) is not announced.
--   * Whispers: a private TextChannel per pair ("Whisper_<min>_<max>", both users added by the server, destroyed when
--     both left or one ignores the other). TextChatService filters the text. "/w <character name> text" is our
--     TextChatCommand (Roblox's default whisper command is switched off and its names still work: a Roblox name or
--     display name on this server is the fallback). Ignored players are never added; account.settings.whispers =
--     "friends" lets only friends and guild mates in.
--   * Ignored players' lines in every other channel are not delivered to the ignoring player (ShouldDeliverCallback).
--   * Social/Ignores answers "ignores?" for trade, duel, party and guild invitations without a dependency on this.

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Ignores = require(script.Parent.Parent.Social.Ignores)
local KeyStore = require(script.Parent.Parent.Market.KeyStore)
local Log = require(Shared.Util.Log)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local NameRules = require(Shared.Logic.NameRules)
local Net = require(Shared.Net)
local Notify = require(script.Parent.Parent.Market.Notify)
local Social = require(Shared.Logic.Social)
local Types = require(Shared.Types)

local log = Log.new("SocialService")

type SocialData = Types.SocialData
type SocialEntry = Types.SocialEntry

local SocialService = {
	Name = "SocialService",
	Deps = { "DataService", "PlayerStateService", "CharacterService", "NameService" },
}

local ONLINE_TOPIC = "Vaelthorn_FriendOnline"
local ServerId = HttpService:GenerateGUID(false) -- the echo of our own announcement is ignored
local ANNOUNCE_GAP = 60 -- s: one "is in the game" per player and minute (character switches)

local DataService: any
local PlayerStateService: any
local CharacterService: any
local NameService: any

local store: KeyStore.KeyStore
type Invite = { from: Player, expiresAt: number }
local invites: { [Player]: Invite } = {}
local synced: { [Player]: boolean } = {}
local announcedAt: { [number]: number } = {}
local channels: { [string]: TextChannel } = {}

-- Record ---------------------------------------------------------------------------------------------------------

type Record = { ignored: { [string]: boolean }, drop: { [string]: number } }

local function recordKey(userId: number): string
	return `Social_{userId}`
end

local function normalizeRecord(value: any): Record
	local record: Record = { ignored = {}, drop = {} }
	if type(value) == "table" then
		if type(value.ignored) == "table" then
			for key, flag in value.ignored do
				if type(key) == "string" and flag == true then
					record.ignored[key] = true
				end
			end
		end
		if type(value.drop) == "table" then
			for key, at in value.drop do
				if type(key) == "string" and type(at) == "number" then
					record.drop[key] = at
				end
			end
		end
	end
	return record
end

-- Account lists ----------------------------------------------------------------------------------------------------

local function socialOf(player: Player): SocialData?
	if not PlayerStateService.HasState(player) then
		return nil
	end
	local value = PlayerStateService.Get(player, { "account", "social" })
	return if type(value) == "table" then value :: SocialData else nil
end

local function writeSocial(player: Player, data: SocialData)
	if PlayerStateService.HasState(player) then
		PlayerStateService.Set(player, { "account", "social" }, data)
		-- S151: the number of friends (achievements count the highest)
		local friends = 0
		local list: { [string]: any } = data.friends or {}
		for _ in list do
			friends += 1
		end
		QuestEvents.fire(player, "social", { friends = friends })
	end
end

-- A working copy of the lists (written back with writeSocial).
local function copyOf(player: Player): SocialData?
	local data = socialOf(player)
	return if data then Social.normalize(data) else nil
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function entryOf(player: Player): SocialEntry?
	local char = character(player)
	return if char then { name = char.name, class = char.class :: string, since = os.time() } else nil
end

local function nameOf(player: Player): string
	local char = character(player)
	return if char then char.name else player.DisplayName
end

local function playing(player: Player?): boolean
	return player ~= nil and player.Parent == Players and PlayerStateService.GetPhase(player) == "playing"
end

-- The record (ignore mirror) of the player's own account follows the account's ignored list. Yields.
local function mirrorIgnores(player: Player)
	local data = socialOf(player)
	if not data then
		return
	end
	local wanted: { [string]: boolean } = {}
	for key in data.ignored do
		wanted[key] = true
	end
	store:update(recordKey(player.UserId), function(current: any?)
		local record = normalizeRecord(current)
		record.ignored = wanted
		return record, nil
	end)
end

-- Ends the friendship on the other account: directly when that player is here, else through their record. Yields.
local function dropOther(userId: number, fromUserId: number)
	local other = Players:GetPlayerByUserId(userId)
	local data = if other then copyOf(other) else nil
	if other and data then
		if Social.removeFriend(data, fromUserId) then
			writeSocial(other, data)
		end
		return
	end
	local at = os.time()
	local ok = store:update(recordKey(userId), function(current: any?)
		local record = normalizeRecord(current)
		record.drop[Social.key(fromUserId)] = at
		return record, nil
	end)
	if ok then
		Notify.send(userId, "socialSync", nil)
	else
		log:warn("could not queue the end of friendship %d -> %d", fromUserId, userId)
	end
end

-- Applies the drops waiting in the player's record and repairs the ignore mirror. Yields.
local function syncRecord(player: Player)
	local ok, value = store:get(recordKey(player.UserId))
	if not ok or player.Parent ~= Players then
		return
	end
	local record = normalizeRecord(value)
	local data = copyOf(player)
	if not data then
		return
	end
	local applied: { [string]: number } = {}
	local changed = false
	for key, at in record.drop do
		applied[key] = at
		local friend = data.friends[key]
		if friend and friend.since <= at then
			data.friends[key] = nil
			changed = true
		end
	end
	if changed then
		writeSocial(player, data)
	end
	local mirrorDiffers = false
	for key in data.ignored do
		if not record.ignored[key] then
			mirrorDiffers = true
		end
	end
	for key in record.ignored do
		if not data.ignored[key] then
			mirrorDiffers = true
		end
	end
	if next(applied) == nil and not mirrorDiffers then
		return
	end
	local wanted: { [string]: boolean } = {}
	for key in data.ignored do
		wanted[key] = true
	end
	store:update(recordKey(player.UserId), function(current: any?)
		local r = normalizeRecord(current)
		for key, at in applied do
			if r.drop[key] == at then
				r.drop[key] = nil
			end
		end
		r.ignored = wanted
		return r, nil
	end)
end

-- Whether the account `userId` ignores `fromUserId` (this server: the live list, else the record). Yields.
-- Returns (ok, ignores); ok = false when the store failed.
function SocialService.Ignores(userId: number, fromUserId: number): (boolean, boolean)
	local other = Players:GetPlayerByUserId(userId)
	local data = if other then socialOf(other) else nil
	if data then
		return true, Social.isIgnored(data, fromUserId)
	end
	local ok, value = store:get(recordKey(userId))
	if not ok then
		return false, false
	end
	return true, normalizeRecord(value).ignored[Social.key(fromUserId)] == true
end

-- Whether `player` ignores the account `userId` (own live list).
function SocialService.IgnoresUser(player: Player, userId: number): boolean
	return Social.isIgnored(socialOf(player), userId)
end

-- Whispers ---------------------------------------------------------------------------------------------------------

local function destroyChannel(name: string)
	local channel = channels[name]
	channels[name] = nil
	if channel then
		channel:Destroy()
	end
end

local function sameGuild(a: Player, b: Player): boolean
	local ca, cb = character(a), character(b)
	return ca ~= nil and cb ~= nil and ca.guildId ~= nil and ca.guildId == cb.guildId
end

local function addUser(channel: TextChannel, userId: number): boolean
	for _, child in channel:GetChildren() do
		if child:IsA("TextSource") and child.UserId == userId then
			return true
		end
	end
	local ok, err = pcall(function()
		channel:AddUserAsync(userId)
	end)
	if not ok then
		log:warn("whisper channel %s: could not add %d (%s)", channel.Name, userId, tostring(err))
	end
	return ok
end

-- Opens (or reuses) the private channel of two players on this server. Yields. Returns (ok, errorKey?, channel?).
local function openWhisper(player: Player, target: Player?): (boolean, string?, TextChannel?)
	if not character(player) then
		return false, "error.wrongPhase", nil
	end
	if target == nil or target.Parent ~= Players then
		return false, "social.whisper.otherServer", nil
	end
	if target == player then
		return false, "social.error.self", nil
	end
	if not playing(target) or not character(target) then
		return false, "social.error.unavailable", nil
	end
	local ignored = Ignores.check(player, target)
	if ignored then
		return false, ignored, nil
	end
	local setting = PlayerStateService.Get(target, { "account", "settings", "whispers" })
	local friends = Social.isFriend(socialOf(target), player.UserId)
	if not Social.whisperAllowed(setting, friends, sameGuild(player, target)) then
		return false, "social.error.whispersFriends", nil
	end
	local name = Social.channelName(player.UserId, target.UserId)
	local channel = channels[name]
	if not channel or channel.Parent == nil then
		local c = Instance.new("TextChannel")
		c.Name = name
		c:SetAttribute("VaelthornChannel", "whisper")
		c:SetAttribute("WhisperA", math.min(player.UserId, target.UserId))
		c:SetAttribute("WhisperB", math.max(player.UserId, target.UserId))
		c.Parent = TextChatService
		channels[name] = c
		channel = c
	end
	local c = channel :: TextChannel
	if not addUser(c, player.UserId) or not addUser(c, target.UserId) then
		return false, "error.internal", nil
	end
	return true, nil, c
end

-- A character name, or a Roblox name / display name, of a player on this server.
local function findHere(name: string): Player?
	if utf8.len(name) == nil then
		return nil
	end
	local wanted = NameRules.normalize(name)
	local byRoblox: Player? = nil
	for _, player in Players:GetPlayers() do
		local char = character(player)
		if char and NameRules.normalize(char.name) == wanted then
			return player
		end
		if
			string.lower(player.Name) == string.lower(name)
			or string.lower(player.DisplayName) == string.lower(name)
		then
			byRoblox = byRoblox or player
		end
	end
	return byRoblox
end

-- "/w <name> text": opens the channel and hands the text back to the sender's client, which sends it through
-- TextChatService (filtered there). Yields.
local function onWhisperCommand(source: TextSource, message: string)
	local player = Players:GetPlayerByUserId(source.UserId)
	if not player or not character(player) then
		return
	end
	local name, text = string.match(message, "^%S+%s+(%S+)%s*(.*)$")
	if not name then
		Net.Fire(player, "Toast", "social.whisper.usage", nil, "info")
		return
	end
	local target = findHere(name)
	if not target then
		local ok, userId = NameService.Lookup(name)
		if ok and userId then
			Net.Fire(player, "WhisperFailed", "social.whisper.otherServer", name)
		else
			Net.Fire(player, "WhisperFailed", "social.error.noSuchName", name)
		end
		return
	end
	local ok, err, channel = openWhisper(player, target)
	if not ok or not channel then
		Net.Fire(player, "WhisperFailed", err or "error.internal", name)
		return
	end
	Net.Fire(player, "WhisperReady", channel.Name, nameOf(target), text or "")
end

-- Lines of an ignored player are not delivered to the ignoring player (every channel but whispers and system lines).
local function guardChannel(channel: Instance)
	if not channel:IsA("TextChannel") or channel.Name == "RBXSystem" then
		return
	end
	if channel:GetAttribute("VaelthornChannel") == "whisper" then
		return
	end
	-- typed loosely: callback properties are not assignable in every analyzer definition
	local host: any = channel
	host.ShouldDeliverCallback = function(message: TextChatMessage, recipient: TextSource): boolean
		local from = message.TextSource
		if not from then
			return true
		end
		local listener = Players:GetPlayerByUserId(recipient.UserId)
		return not (listener ~= nil and Social.isIgnored(socialOf(listener), from.UserId))
	end
end

-- Friends ----------------------------------------------------------------------------------------------------------

local function invite(player: Player, userId: number): (boolean, string?)
	local target = Players:GetPlayerByUserId(userId)
	if target == player then
		return false, "social.error.self"
	end
	if not playing(target) or not character(player) then
		return false, "party.error.notFound"
	end
	local t = target :: Player
	local ignored = Ignores.check(player, t)
	if ignored then
		return false, ignored
	end
	local mine, theirs = socialOf(player), socialOf(t)
	if not mine or not theirs then
		return false, "error.wrongPhase"
	end
	if Social.isFriend(mine, userId) then
		return false, "social.error.alreadyFriend"
	end
	if Social.count(mine.friends) >= Config.Social.maxFriends then
		return false, "social.error.friendsFull"
	end
	if Social.count(theirs.friends) >= Config.Social.maxFriends then
		return false, "social.error.targetFull"
	end
	local pending = invites[t]
	if pending and pending.expiresAt > os.clock() then
		return false, "party.error.pending"
	end
	invites[t] = { from = player, expiresAt = os.clock() + Config.Social.inviteSeconds }
	Net.Fire(t, "FriendInvited", nameOf(player), Config.Social.inviteSeconds)
	return true, nil
end

local function respond(player: Player, accept: boolean): (boolean, string?)
	local pending = invites[player]
	invites[player] = nil
	if not pending or pending.expiresAt < os.clock() or not playing(pending.from) then
		return false, "party.error.expired"
	end
	local from = pending.from
	if not accept then
		Net.Fire(from, "Toast", "social.friendDeclined", { name = nameOf(player) }, "info")
		return true, nil
	end
	local ignored = Ignores.check(player, from)
	if ignored then
		return false, ignored
	end
	local mine, theirs = copyOf(player), copyOf(from)
	local myEntry, theirEntry = entryOf(player), entryOf(from)
	if not mine or not theirs or not myEntry or not theirEntry then
		return false, "party.error.expired"
	end
	local ok, err = Social.addFriend(mine, from.UserId, theirEntry)
	if not ok and err ~= "social.error.alreadyFriend" then
		return false, err
	end
	local ok2, err2 = Social.addFriend(theirs, player.UserId, myEntry)
	if not ok2 and err2 ~= "social.error.alreadyFriend" then
		return false, if err2 == "social.error.friendsFull" then "social.error.targetFull" else err2
	end
	writeSocial(player, mine)
	writeSocial(from, theirs)
	Net.Fire(player, "Toast", "social.friendAdded", { name = theirEntry.name }, "success")
	Net.Fire(from, "Toast", "social.friendAdded", { name = myEntry.name }, "success")
	return true, nil
end

local function removeFriend(player: Player, userId: number): (boolean, string?)
	local data = copyOf(player)
	if not data then
		return false, "error.wrongPhase"
	end
	if not Social.removeFriend(data, userId) then
		return false, "social.error.notFriend"
	end
	writeSocial(player, data)
	task.spawn(dropOther, userId, player.UserId)
	return true, nil
end

-- The entry for ignoring `userId`: the player here, else the friend entry, else `knownName` (a checked name).
local function ignoreEntry(player: Player, userId: number, knownName: string?): SocialEntry?
	local other = Players:GetPlayerByUserId(userId)
	if other then
		local e = entryOf(other)
		if e then
			return e
		end
	end
	local data = socialOf(player)
	local friend = data and data.friends[Social.key(userId)]
	if friend then
		return { name = friend.name, class = friend.class, since = os.time() }
	end
	return if knownName then { name = knownName, since = os.time() } else nil
end

local function ignore(player: Player, userId: number, knownName: string?): (boolean, string?)
	if userId == player.UserId then
		return false, "social.error.self"
	end
	local data = copyOf(player)
	if not data then
		return false, "error.wrongPhase"
	end
	local e = ignoreEntry(player, userId, knownName)
	if not e then
		return false, "party.error.notFound"
	end
	local wasFriend = Social.isFriend(data, userId)
	local ok, err = Social.ignore(data, userId, e)
	if not ok then
		return false, err
	end
	writeSocial(player, data)
	destroyChannel(Social.channelName(player.UserId, userId))
	local other = Players:GetPlayerByUserId(userId)
	if other and invites[other] and invites[other].from == player then
		invites[other] = nil
	end
	if invites[player] and invites[player].from.UserId == userId then
		invites[player] = nil
	end
	task.spawn(function()
		if wasFriend then
			dropOther(userId, player.UserId)
		end
		mirrorIgnores(player)
	end)
	return true, nil
end

local function ignoreByName(player: Player, name: string): (boolean, string?)
	local here = findHere(name)
	if here then
		return ignore(player, here.UserId, nil)
	end
	local ok, userId = NameService.Lookup(name)
	if not ok then
		return false, "error.internal"
	end
	if not userId then
		return false, "social.error.noSuchName"
	end
	return ignore(player, userId, name)
end

local function unignore(player: Player, userId: number): (boolean, string?)
	local data = copyOf(player)
	if not data then
		return false, "error.wrongPhase"
	end
	if not Social.unignore(data, userId) then
		return false, "social.error.notIgnored"
	end
	writeSocial(player, data)
	task.spawn(mirrorIgnores, player)
	return true, nil
end

-- "is in the game" ---------------------------------------------------------------------------------

-- Toasts "<name> is in the game" to the friends of `userId` on this server.
local function friendOnline(userId: number, name: string)
	local key = Social.key(userId)
	for _, player in Players:GetPlayers() do
		if player.UserId == userId then
			continue
		end
		local data = socialOf(player)
		local friend = data and data.friends[key]
		if friend then
			if PlayerStateService.Get(player, { "account", "settings", "friendAlerts" }) ~= false then
				Net.Fire(player, "Toast", "social.friendOnline", { name = name }, "info")
			end
			if friend.name ~= name then
				local fresh = copyOf(player)
				if fresh and fresh.friends[key] then
					fresh.friends[key].name = name
					writeSocial(player, fresh)
				end
			end
		end
	end
end

local function announce(player: Player)
	local char = character(player)
	if not char or PlayerStateService.Get(player, { "account", "settings", "appearOffline" }) == true then
		return
	end
	local last = announcedAt[player.UserId]
	if last and os.clock() - last < ANNOUNCE_GAP then
		return
	end
	announcedAt[player.UserId] = os.clock()
	local userId, name = player.UserId, char.name
	friendOnline(userId, name)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(ONLINE_TOPIC, { u = userId, n = name, j = ServerId })
		end)
	end)
end

local function subscribeOnline()
	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(ONLINE_TOPIC, function(packet)
			local data = packet.Data
			if
				type(data) == "table"
				and type(data.u) == "number"
				and type(data.n) == "string"
				and data.j ~= ServerId
			then
				friendOnline(data.u, data.n)
			end
		end)
	end)
	if not ok then
		log:warn("MessagingService unavailable (%s): friend alerts stay on this server", tostring(err))
	end
end

-- Lifecycle -----------------------------------------------------------------------------------------------------

function SocialService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	NameService = registry.Get("NameService")
	store = KeyStore.new(Config.Social.storeName, DataService.HasDataStoreAccess)
	Ignores.setReader(function(userId: number)
		local player = Players:GetPlayerByUserId(userId)
		local data = if player then socialOf(player) else nil
		return if data then data.ignored else nil
	end)
end

function SocialService.Start()
	task.spawn(subscribeOnline)

	-- The default /w (Roblox names) gives way to ours (character names first, Roblox names as a fallback).
	task.spawn(function()
		local commands = TextChatService:WaitForChild("TextChatCommands", 15)
		local default = commands and commands:WaitForChild("RBXWhisperCommand", 15)
		if default and default:IsA("TextChatCommand") then
			default.Enabled = false
		end
	end)
	local command = Instance.new("TextChatCommand")
	command.Name = "VaelthornWhisper"
	command.PrimaryAlias = "/w"
	command.SecondaryAlias = "/whisper"
	command.Triggered:Connect(function(source: TextSource, message: string)
		task.spawn(onWhisperCommand, source, message)
	end)
	command.Parent = TextChatService

	for _, descendant in TextChatService:GetDescendants() do
		guardChannel(descendant)
	end
	TextChatService.DescendantAdded:Connect(guardChannel)

	Net.Handle("FriendInvite", invite)
	Net.Handle("FriendRespond", respond)
	Net.Handle("FriendRemove", removeFriend)
	Net.Handle("IgnoreAdd", function(player: Player, userId: number)
		return ignore(player, userId, nil)
	end)
	Net.Handle("IgnoreName", ignoreByName)
	Net.Handle("IgnoreRemove", unignore)
	Net.Handle("WhisperOpen", function(player: Player, userId: number)
		local ok, err, channel = openWhisper(player, Players:GetPlayerByUserId(userId))
		if not ok or not channel then
			return false, err
		end
		local target = Players:GetPlayerByUserId(userId)
		return true, nil, channel.Name, if target then nameOf(target) else ""
	end)
	Net.On("SocialHintSeen", function(player: Player)
		if character(player) then
			PlayerStateService.Set(player, { "character", "playerMenuHint" }, true)
		end
	end)

	Notify.on("socialSync", function(player: Player)
		syncRecord(player)
	end)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		task.spawn(function()
			if not synced[player] then
				synced[player] = true
				syncRecord(player)
			end
		end)
		announce(player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		invites[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		invites[player] = nil
		synced[player] = nil
		for target, pending in invites do
			if pending.from == player then
				invites[target] = nil
			end
		end
		local userId = player.UserId
		-- A whisper channel goes once both of its players left.
		for name, channel in channels do
			local a, b = channel:GetAttribute("WhisperA"), channel:GetAttribute("WhisperB")
			if a == userId or b == userId then
				local other = if a == userId then b else a
				if type(other) ~= "number" or Players:GetPlayerByUserId(other) == nil then
					destroyChannel(name)
				end
			end
		end
	end)
end

-- Admin (/social): the lists of a player on this server, as text.
function SocialService.Describe(player: Player): (string, string)
	local data = socialOf(player)
	if not data then
		return "-", "-"
	end
	local function join(list: { [string]: SocialEntry }): string
		local parts = {}
		for key, e in list do
			table.insert(parts, `{e.name} ({key})`)
		end
		table.sort(parts)
		return if #parts > 0 then table.concat(parts, ", ") else "-"
	end
	return join(data.friends), join(data.ignored)
end

return SocialService
