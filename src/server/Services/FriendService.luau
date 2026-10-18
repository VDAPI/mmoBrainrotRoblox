--!strict
-- Friends 2.0 (S150): presence across servers, "Join" a friend's server, party invitations between servers, Roblox
-- friends who play Vaelthorn and "appear offline". S133 SocialService keeps the lists, whispers and requests.
--   * Presence: one entry per account (Logic/Presence, Friends/Presence), written by this server for its players
--     every Config.Friends.presenceEvery and at once when the map, the character or a privacy setting changes; a
--     player who appears offline has no entry (removed at once). Entries are written on world, arena and tournament
--     servers alike, each with its mode.
--   * The friends window: FriendsWatch(true) makes this server publish the runtime branch `friends` = { list, roblox,
--     online, at, block, cd, mode } to that player, fully every Config.Friends.refreshEvery (reads in the budget,
--     window refreshes first; a row without a token keeps its last state with r = true) and lightly (block reason and
--     cooldown only) every Config.Friends.lightEvery, always only when it changed.
--   * FriendJoin(userId): the server checks everything itself (Logic/FriendJoin.canJoin: friend or Roblox friend,
--     ignores, a fresh entry on another public world server, the owner's join rule, Logic/UseBlocks friendJoin,
--     cooldown) and teleports with Arena/Transfer.toServer (save first; a party stays behind). Studio: a toast.
--   * FriendPartyInvite(userId): a friend on another server gets an invitation through the topic (this server
--     remembers it); accepting is a join with TeleportData via = "friendParty", and on arrival this server lets the
--     player into the inviter's party (PartyService.AddMember) when the inviter still leads one with room.
--   * Roblox friends: Players:GetFriendsAsync once per session (pages up to Config.Friends.robloxMax, Market/Retry);
--     the client names the Roblox friends it sees in this game (FriendsRobloxHint, Player:GetFriendsOnlineAsync);
--     only those that are Roblox friends by the server's own list are read (Config.Friends.robloxReads per refresh).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local FriendJoin = require(Shared.Logic.FriendJoin)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local PresenceLogic = require(Shared.Logic.Presence)
local Presence = require(script.Parent.Parent.Friends.Presence)
local Retry = require(script.Parent.Parent.Market.Retry)
local ServerMode = require(script.Parent.Parent.Arena.ServerMode)
local Social = require(Shared.Logic.Social)
local Transfer = require(script.Parent.Parent.Arena.Transfer)
local Types = require(Shared.Types)
local UseBlocks = require(Shared.Logic.UseBlocks)
local UseGuards = require(script.Parent.Parent.UseGuards)

local log = Log.new("FriendService")

local F = Config.Friends
local PARTY_MAX = Config.PartyFinder.maxMembers

local FriendService = {
	Name = "FriendService",
	Deps = { "PlayerStateService", "CharacterService", "SocialService", "PartyService", "ArenaService" },
}

type Row = {
	s: string,
	map: string?,
	lvl: number?,
	cls: string?,
	name: string?,
	tag: string?,
	pj: string?,
	r: boolean?,
}

type Payload = {
	list: { [string]: Row },
	roblox: { [string]: Row },
	online: number,
	at: number,
	block: string?,
	cd: number?,
	mode: string,
	priv: boolean?,
}

type Watch = { due: number, busy: boolean, sent: string?, payload: Payload? }

type PendingInvite = { from: number, name: string, j: string, exp: number }

local PlayerStateService: any
local CharacterService: any
local SocialService: any
local PartyService: any

local watchers: { [Player]: Watch } = {}
local written: { [Player]: { sig: string, at: number }? } = {}
local cooldowns: { [Player]: number } = {}
local robloxSets: { [Player]: { [number]: boolean } } = {}
local robloxLoadedAt: { [Player]: number } = {}
local robloxChecked: { [Player]: { [number]: boolean } } = {}
local hints: { [Player]: { number } } = {}
local hintTurn: { [Player]: number } = {}
local robloxIgnores: { [Player]: { [number]: { ignored: boolean, at: number } } } = {} -- other servers, cached
local pendingInvites: { [Player]: PendingInvite } = {}
local sentInvites: { [number]: { [number]: number } } = {} -- inviter userId -> invitee userId -> exp
local arrived: { [Player]: boolean } = {}
local limiter = FriendJoin.limiter(F.invitesPerMinute)

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function playing(player: Player?): boolean
	return player ~= nil and player.Parent == Players and PlayerStateService.GetPhase(player) == "playing"
end

local function setting(player: Player, name: string): any
	if not PlayerStateService.HasState(player) then
		return nil
	end
	return PlayerStateService.Get(player, { "account", "settings", name })
end

local function invisible(player: Player): boolean
	return setting(player, "appearOffline") == true
end

local function joinRule(player: Player): string
	return if setting(player, "friendJoin") == "none" then "none" else "friends"
end

local function socialOf(player: Player): Social.SocialData?
	if not PlayerStateService.HasState(player) then
		return nil
	end
	local value = PlayerStateService.Get(player, { "account", "social" })
	return if type(value) == "table" then value :: Social.SocialData else nil
end

local function toast(player: Player, key: string, args: { [string]: any }?, kind: string?)
	if player.Parent == Players then
		Net.Fire(player, "Toast", key, args, kind or "info")
	end
end

-- Any private or reserved server: not joinable by ServerInstanceId (a reserved server whose mode fell back to
-- "world" included).
local function isPrivateServer(): boolean
	return game.PrivateServerId ~= ""
end

-- Presence of this server's players ---------------------------------------------------------------------------

local function recordOf(player: Player): PresenceLogic.Record?
	local char = character(player)
	if not char or not playing(player) or invisible(player) then
		return nil
	end
	return PresenceLogic.record({
		j = Presence.JobId,
		m = ServerMode.get(),
		p = isPrivateServer(),
		map = char.location.map,
		lvl = char.level,
		cls = char.class :: string,
		name = char.name,
		t = os.time(),
		pj = joinRule(player),
	})
end

-- What makes a write due at once (not the level: that waits for the periodic refresh).
local function signature(player: Player): string
	local char = character(player)
	if not char or not playing(player) or invisible(player) then
		return "off"
	end
	return `{char.name}|{char.class}|{char.location.map}|{joinRule(player)}`
end

-- Writes, refreshes or removes the player's entry when it is due. Yields.
local function syncPresence(player: Player, force: boolean?)
	local sig = signature(player)
	local last = written[player]
	local now = os.time()
	if not force and last and last.sig == sig and (sig == "off" or now - last.at < F.presenceEvery) then
		return
	end
	written[player] = { sig = sig, at = now }
	local rec = recordOf(player)
	if rec then
		Presence.write(player.UserId, rec)
	elseif last and last.sig ~= "off" then
		Presence.remove(player.UserId)
	end
end

-- Friendship and ignores ------------------------------------------------------------------------------------------

-- Loads the player's Roblox friends (FriendPages up to Config.Friends.robloxMax). Yields.
local function loadRobloxFriends(player: Player)
	local now = os.time()
	local at = robloxLoadedAt[player]
	if at and now - at < F.robloxRefresh then
		return
	end
	robloxLoadedAt[player] = now
	local ok, set = Retry.call("GetFriendsAsync", function()
		local found: { [number]: boolean } = {}
		local count = 0
		local pages = Players:GetFriendsAsync(player.UserId)
		while count < F.robloxMax do
			for _, friend in pages:GetCurrentPage() do
				if type(friend) == "table" and type(friend.Id) == "number" then
					found[friend.Id] = true
					count += 1
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
		return found
	end)
	if ok and type(set) == "table" and player.Parent == Players then
		robloxSets[player] = set
	end
end

-- Whether `userId` is a Roblox friend of `player` (the session list; without it Player:IsFriendsWith, cached). Yields.
local function robloxFriend(player: Player, userId: number): boolean
	local set = robloxSets[player]
	if set then
		return set[userId] == true
	end
	local checked = robloxChecked[player]
	if not checked then
		checked = {}
		robloxChecked[player] = checked
	end
	local known = checked[userId]
	if known ~= nil then
		return known
	end
	local ok, result = pcall(function()
		return player:IsFriendsWithAsync(userId)
	end)
	local value = ok and result == true
	if ok then
		checked[userId] = value
	end
	return value
end

local function accountFriend(player: Player, userId: number): boolean
	return Social.isFriend(socialOf(player), userId)
end

-- Either side ignores the other (the other side's record when that player is elsewhere). Yields. A failed read of
-- the record counts as ignored (fail closed: the join waits for the store).
local function ignoredPair(player: Player, userId: number): boolean
	if SocialService.IgnoresUser(player, userId) then
		return true
	end
	local ok, ignores = SocialService.Ignores(userId, player.UserId)
	return not ok or ignores
end

-- The status and entry of a friend seen from this server. Yields.
local function statusOf(
	userId: number,
	priority: PresenceLogic.Priority
): (PresenceLogic.Status, PresenceLogic.Record?, boolean)
	local other = Players:GetPlayerByUserId(userId)
	if other and playing(other) then
		if invisible(other) then
			return "offline", nil, false
		end
		return "here", recordOf(other), false
	end
	local state, rec = Presence.read(userId, priority)
	if state == "wait" then
		return "unknown", rec, true
	end
	if state == "fail" then
		return "unknown", nil, false
	end
	local status: PresenceLogic.Status = PresenceLogic.statusOf(rec, Presence.JobId, os.time())
	if status == "here" then
		status = "offline" :: PresenceLogic.Status -- an entry of this server without the player here is a stale one
	end
	return status, rec, false
end

local function blockOf(player: Player): string?
	return UseGuards.first(player, UseBlocks.LISTS.friendJoin)
end

-- Whether a Roblox friend on another server ignores `player` (cached for Config.Friends.robloxRefresh; a failed
-- read counts as ignored and is not cached). Yields.
local function robloxIgnored(player: Player, userId: number): boolean
	if SocialService.IgnoresUser(player, userId) then
		return true
	end
	if Players:GetPlayerByUserId(userId) then
		return ignoredPair(player, userId) -- live list, no read
	end
	local cache = robloxIgnores[player]
	if not cache then
		cache = {}
		robloxIgnores[player] = cache
	end
	local now = os.time()
	local known = cache[userId]
	if known and now - known.at < F.robloxRefresh then
		return known.ignored
	end
	local ok, ignores = SocialService.Ignores(userId, player.UserId)
	if not ok then
		return true
	end
	cache[userId] = { ignored = ignores, at = now }
	return ignores
end

-- The Logic/FriendJoin view of `userId` for `player`. Yields.
local function viewFor(player: Player, userId: number): (FriendJoin.View, PresenceLogic.Record?)
	local friend = accountFriend(player, userId) or robloxFriend(player, userId)
	local ignored = friend and ignoredPair(player, userId)
	local status: PresenceLogic.Status, rec: PresenceLogic.Record? = "offline", nil
	if friend and not ignored then
		status, rec = statusOf(userId, "join")
	end
	return {
		friend = friend,
		ignored = ignored,
		status = status,
		pj = if rec then rec.pj else nil,
		hereMode = ServerMode.get(),
		block = blockOf(player),
		cooldownUntil = cooldowns[player],
		selfHidden = invisible(player),
		selfPj = joinRule(player),
		selfPrivate = isPrivateServer(),
	},
		rec
end

-- The friends window -------------------------------------------------------------------------------------------

local function rowOf(status: string, rec: PresenceLogic.Record?, waiting: boolean): Row
	local row: Row = { s = status }
	if rec and status ~= "offline" then
		row.map = rec.map
		row.lvl = rec.lvl
		row.cls = rec.cls
		row.name = rec.name
		row.pj = rec.pj
		if status == "here" or status == "world" then
			row.tag = PresenceLogic.serverTag(rec.j)
		end
	end
	if waiting then
		row.r = true
	end
	return row
end

-- Runs `jobs` in parallel and waits for them (at most 8 s). Yields.
local function together(jobs: { () -> () })
	local left = #jobs
	for _, job in jobs do
		task.spawn(function()
			local ok, err = pcall(job :: any)
			if not ok then
				log:warn("friends refresh: %s", tostring(err))
			end
			left -= 1
		end)
	end
	local deadline = os.clock() + 8
	while left > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end

-- The full payload of the window. Yields (reads within the budget).
local function buildPayload(player: Player, previous: Payload?): Payload?
	local data = socialOf(player)
	if not data then
		return nil
	end
	local list: { [string]: Row } = {}
	local jobs: { () -> () } = {}
	for key in data.friends do
		local userId = tonumber(key)
		if not userId then
			continue
		end
		table.insert(jobs, function()
			local status, rec, waiting = statusOf(userId, "window")
			if waiting then
				local old = previous and previous.list[key]
				if old then
					local kept = table.clone(old)
					kept.r = true
					list[key] = kept
					return
				end
			end
			list[key] = rowOf(status, rec, waiting)
		end)
	end
	-- Roblox friends: on this server (no read) and those the client named (Config.Friends.robloxReads per refresh)
	local roblox: { [string]: Row } = {}
	local candidates: { number } = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and robloxSets[player] and robloxSets[player][other.UserId] then
			table.insert(candidates, other.UserId)
		end
	end
	local hinted = hints[player] or {}
	local turn = hintTurn[player] or 0
	for i = 1, math.min(#hinted, F.robloxReads) do
		local id = hinted[((turn + i - 1) % #hinted) + 1]
		if not table.find(candidates, id) then
			table.insert(candidates, id)
		end
	end
	if #hinted > 0 then
		hintTurn[player] = (turn + F.robloxReads) % #hinted
	end
	for _, userId in candidates do
		local key = Social.key(userId)
		if data.friends[key] or data.ignored[key] or userId == player.UserId then
			continue
		end
		table.insert(jobs, function()
			-- S133 rule: a player who ignores the viewer is never shown (nor where they play)
			if not robloxFriend(player, userId) or robloxIgnored(player, userId) then
				return
			end
			local status, rec, waiting = statusOf(userId, "other")
			if waiting then
				local old = previous and previous.roblox[key]
				if old then
					local kept = table.clone(old)
					kept.r = true
					roblox[key] = kept
				end
				return
			end
			if PresenceLogic.online(status :: PresenceLogic.Status) and rec and rec.name then
				roblox[key] = rowOf(status, rec, false)
			end
		end)
	end
	together(jobs)
	local online = 0
	for _, row in list do
		if PresenceLogic.online(row.s :: PresenceLogic.Status) then
			online += 1
		end
	end
	-- S133: names and classes in the list follow what the friend plays now
	local fresh = socialOf(player)
	if fresh then
		local copy = Social.normalize(fresh)
		local changed = false
		for key, row in list do
			local friend = copy.friends[key]
			if friend and row.name and (friend.name ~= row.name or (row.cls and friend.class ~= row.cls)) then
				friend.name = row.name
				friend.class = row.cls or friend.class
				changed = true
			end
		end
		if changed and PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "account", "social" }, copy)
		end
	end
	return {
		list = list,
		roblox = roblox,
		online = online,
		at = os.time(),
		block = blockOf(player),
		cd = cooldowns[player],
		mode = ServerMode.get() :: string,
		priv = if isPrivateServer() then true else nil,
	}
end

local function send(player: Player, watch: Watch, payload: Payload)
	if watchers[player] ~= watch or not PlayerStateService.HasState(player) then
		return
	end
	watch.payload = payload
	local ok, key = pcall(function()
		return game:GetService("HttpService"):JSONEncode(payload)
	end)
	if ok and watch.sent == key then
		return
	end
	watch.sent = if ok then key else nil
	PlayerStateService.Set(player, { "friends" }, payload)
end

-- A full refresh of one watcher (yields; one at a time per player).
local function refresh(player: Player)
	local watch = watchers[player]
	if not watch or watch.busy then
		return
	end
	watch.busy = true
	watch.due = os.clock() + F.refreshEvery
	task.spawn(loadRobloxFriends, player)
	local ok, result = pcall(buildPayload, player, watch.payload)
	watch.busy = false
	if not ok then
		log:warn("friends refresh of %s failed: %s", player.Name, tostring(result))
		return
	end
	if result then
		send(player, watch, result)
	end
end

-- Block reason and cooldown of an open window (no store call).
local function lightRefresh(player: Player)
	local watch = watchers[player]
	local payload = watch and watch.payload
	if not watch or not payload or watch.busy then
		return
	end
	local endsAt = cooldowns[player]
	if endsAt and os.time() >= endsAt then
		cooldowns[player] = nil -- an expired cooldown re-enables "Join" in the open window
	end
	local block, cd = blockOf(player), cooldowns[player]
	if payload.block == block and payload.cd == cd then
		return
	end
	local copy = table.clone(payload)
	copy.block = block
	copy.cd = cd
	send(player, watch, copy)
end

-- Join -------------------------------------------------------------------------------------------------------

local function teleportTo(player: Player, rec: PresenceLogic.Record, data: { [string]: any }): (boolean, string?)
	if RunService:IsStudio() then
		return false, "friends.join.studio"
	end
	if Transfer.busy(player) then
		return false, "friends.join.cooldown"
	end
	cooldowns[player] = os.time() + F.joinCooldown
	local ok, err = pcall(function()
		Transfer.toServer(player, rec.j, data, function(result: string)
			toast(player, FriendJoin.failKey(result), nil, "error")
		end)
	end)
	if not ok then
		log:warn("teleport of %s to a friend failed: %s", player.Name, tostring(err))
		return false, "friends.join.failed"
	end
	return true, nil
end

local function join(player: Player, userId: number): (boolean, string?)
	if not playing(player) or not character(player) then
		return false, "error.wrongPhase"
	end
	if userId == player.UserId then
		return false, "social.error.self"
	end
	local view, rec = viewFor(player, userId)
	local ok, reason = FriendJoin.canJoin(view, os.time())
	if not ok or not rec then
		return false, reason or "friends.join.offline"
	end
	return teleportTo(player, rec, FriendJoin.teleportData("friend", userId))
end

-- Party invitations between servers --------------------------------------------------------------------------

local function partyInvite(player: Player, userId: number): (boolean, string?)
	local char = character(player)
	if not playing(player) or not char then
		return false, "error.wrongPhase"
	end
	if userId == player.UserId then
		return false, "social.error.self"
	end
	local party = PartyService.Get(player)
	if party and party.leader ~= player then
		return false, "party.error.notLeader"
	end
	if party and #party.members >= PARTY_MAX then
		return false, "party.error.full"
	end
	local view, rec = viewFor(player, userId)
	local ok, reason = FriendJoin.canInvite(view)
	if not ok then
		return false, reason
	end
	if view.status == "here" or not rec then
		return false, "friends.party.here" -- the client uses the S133 invitation (PartyInviteUser)
	end
	local now = os.time()
	if not limiter.allow(player.UserId, now) then
		return false, "friends.party.limit"
	end
	local message = FriendJoin.inviteMessage({
		to = userId,
		from = player.UserId,
		name = char.name,
		lvl = char.level,
		cls = char.class :: string,
		j = Presence.JobId,
		now = now,
	})
	if not Presence.publish(message) then
		return false, "friends.party.failed"
	end
	local mine = sentInvites[player.UserId] or {}
	mine[userId] = message.exp
	sentInvites[player.UserId] = mine
	return true, nil
end

-- An invitation from the topic (any server, also this one). Never yields long.
local function onInvite(raw: any)
	local invite = FriendJoin.parseInvite(raw)
	if not invite then
		return
	end
	local target = Players:GetPlayerByUserId(invite.to)
	local here = target ~= nil and playing(target)
	local t = target :: Player
	local receiver: FriendJoin.Receiver = {
		here = here,
		ignoresSender = here and Social.isIgnored(socialOf(t), invite.from),
		pj = if here then joinRule(t) else nil,
	}
	local now = os.time()
	if not FriendJoin.acceptInvite(invite, receiver, now) then
		return
	end
	pendingInvites[t] = { from = invite.from, name = invite.name, j = invite.j, exp = invite.exp }
	Net.Fire(t, "FriendPartyInvited", invite.name, invite.lvl, invite.cls, math.max(1, invite.exp - now))
end

local function partyRespond(player: Player, accept: boolean): (boolean, string?)
	local pending = pendingInvites[player]
	pendingInvites[player] = nil
	if not pending or os.time() >= pending.exp then
		return false, "friends.party.expired"
	end
	if not accept then
		return true, nil
	end
	local view, rec = viewFor(player, pending.from)
	local ok, reason = FriendJoin.canJoin(view, os.time())
	if not ok or not rec then
		return false, reason or "friends.party.expired"
	end
	if rec.j ~= pending.j then
		return false, "friends.party.expired" -- the inviter moved: the invitation stayed on the old server
	end
	return teleportTo(player, rec, FriendJoin.teleportData("friendParty", pending.from, pending.exp))
end

-- Arrival through "Join" (TeleportData via = "friend" | "friendParty"), once per session.
local function onArrival(player: Player)
	if arrived[player] then
		return
	end
	arrived[player] = true
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local data: any = if ok and type(joinData) == "table" then (joinData :: any).TeleportData else nil
	if type(data) ~= "table" or type(data.friend) ~= "number" then
		return
	end
	if data.via ~= "friend" and data.via ~= "friendParty" then
		return
	end
	local friend = Players:GetPlayerByUserId(data.friend)
	local char = character(player)
	if friend and playing(friend) and char and not invisible(player) then
		toast(friend, "friends.join.arrived", { name = char.name }, "info")
	end
	if data.via ~= "friendParty" then
		return
	end
	local sent = sentInvites[data.friend]
	local exp = sent and sent[player.UserId]
	if sent then
		sent[player.UserId] = nil
	end
	local party = if friend then PartyService.Get(friend) else nil
	local result = FriendJoin.arrival(data, {
		inviteKnown = exp ~= nil and os.time() <= exp + F.inviteGrace,
		leaderHere = friend ~= nil and playing(friend),
		canLead = party == nil or party.leader == friend,
		size = if party then #party.members else 1,
		max = PARTY_MAX,
	})
	if result == "join" and friend then
		local joined = PartyService.AddMember(friend, player)
		if joined then
			local fc = character(friend)
			toast(player, "friends.party.joined", { name = if fc then fc.name else friend.DisplayName }, "success")
			return
		end
	end
	if result ~= "none" then
		toast(player, "friends.party.expired", nil, "info")
	end
end

-- Roblox friends hint ------------------------------------------------------------------------------------------

local function onHint(player: Player, ids: any)
	if type(ids) ~= "table" then
		return
	end
	local out: { number } = {}
	for i, id in ids do
		if type(i) ~= "number" or i > F.robloxHint then
			return
		end
		if type(id) == "number" and id == math.floor(id) and id > 0 and id ~= player.UserId then
			if not table.find(out, id) then
				table.insert(out, id)
			end
		end
	end
	local set = robloxSets[player]
	if set then
		local kept: { number } = {}
		for _, id in out do
			if set[id] then
				table.insert(kept, id)
			end
		end
		out = kept
	end
	local old = hints[player]
	hints[player] = out
	local watch = watchers[player]
	if watch and (old == nil or table.concat(old, ",") ~= table.concat(out, ",")) then
		watch.due = 0 -- a new hint shows up in an open window at once, not after Config.Friends.refreshEvery
	end
end

-- Lifecycle ----------------------------------------------------------------------------------------------------

local function forget(player: Player)
	watchers[player] = nil
	written[player] = nil
	cooldowns[player] = nil
	robloxSets[player] = nil
	robloxLoadedAt[player] = nil
	robloxChecked[player] = nil
	hints[player] = nil
	hintTurn[player] = nil
	robloxIgnores[player] = nil
	pendingInvites[player] = nil
	arrived[player] = nil
end

function FriendService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	SocialService = registry.Get("SocialService")
	PartyService = registry.Get("PartyService")
end

function FriendService.Start()
	task.spawn(Presence.init, onInvite)

	Net.Handle("FriendJoin", join)
	Net.Handle("FriendPartyInvite", partyInvite)
	Net.Handle("FriendPartyRespond", partyRespond)
	Net.On("FriendsWatch", function(player: Player, on: boolean)
		if on then
			if not watchers[player] then
				watchers[player] = { due = 0, busy = false, sent = nil, payload = nil }
			end
			task.spawn(refresh, player)
		else
			watchers[player] = nil
			if PlayerStateService.HasState(player) then
				PlayerStateService.Set(player, { "friends" }, nil)
			end
		end
	end)
	Net.On("FriendsRobloxHint", onHint)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		task.spawn(function()
			syncPresence(player, true)
			onArrival(player)
		end)
		task.spawn(loadRobloxFriends, player)
	end)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		watchers[player] = nil
		pendingInvites[player] = nil
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local had = written[player]
		forget(player)
		if had and had.sig ~= "off" then
			task.spawn(Presence.remove, player.UserId)
		end
	end)

	-- Presence writes on a change (and the periodic refresh); window refreshes, full and light.
	task.spawn(function()
		local lastLight = 0
		while true do
			task.wait(F.changeCheck)
			for _, player in Players:GetPlayers() do
				if written[player] then
					task.spawn(syncPresence, player)
				end
			end
			local now = os.clock()
			for player, watch in watchers do
				if not watch.busy and now >= watch.due then
					task.spawn(refresh, player)
				end
			end
			if now - lastLight >= F.lightEvery then
				lastLight = now
				for player in watchers do
					lightRefresh(player)
				end
			end
			-- old invitations of this server
			local t = os.time()
			for from, list in sentInvites do
				for to, exp in list do
					if t > exp + F.inviteGrace then
						list[to] = nil
					end
				end
				if next(list) == nil then
					sentInvites[from] = nil
				end
			end
		end
	end)
end

-- Admin --------------------------------------------------------------------------------------------------------

-- /presence: the raw entry of a user (yields), its status from here and its age.
function FriendService.Describe(userId: number): (string, string?)
	local other = Players:GetPlayerByUserId(userId)
	local rec: PresenceLogic.Record?
	local state: string
	if other then
		rec = recordOf(other)
		state = if rec then "here" else "offline (appears offline or no character)"
	else
		Presence.forget(userId)
		local s, r = Presence.read(userId, "join")
		rec = r
		state = s
	end
	if not rec then
		return state, nil
	end
	local status = PresenceLogic.statusOf(rec, Presence.JobId, os.time())
	return status,
		`j={rec.j} tag={PresenceLogic.serverTag(rec.j)} m={rec.m} p={tostring(rec.p)} map={rec.map or "-"} lvl={rec.lvl or 0} cls={rec.cls or "-"} name={rec.name or "-"} pj={rec.pj} age={os.time() - rec.t}s`
end

-- /friends budget
function FriendService.Budget(): (PresenceLogic.BudgetStats, string, number)
	local n = 0
	for _ in watchers do
		n += 1
	end
	return Presence.stats(), Presence.mode(), n
end

-- /friendinvite: an invitation from `from` to `target` through the topic (in Studio through the fake), with the
-- target's server deciding as for any message.
function FriendService.TestInvite(from: Player, target: Player): boolean
	local char = character(from)
	if not char then
		return false
	end
	local message = FriendJoin.inviteMessage({
		to = target.UserId,
		from = from.UserId,
		name = char.name,
		lvl = char.level,
		cls = char.class :: string,
		j = Presence.JobId,
		now = os.time(),
	})
	local mine = sentInvites[from.UserId] or {}
	mine[target.UserId] = message.exp
	sentInvites[from.UserId] = mine
	return Presence.publish(message)
end

return FriendService
