--!strict
-- "Join" a friend's server and party invitations between servers, pure (S150). The server (FriendService) and the
-- client (FriendsWindow, the "Join" button with its reason) ask the same `canJoin`.
--   * canJoin(view, now): a friend (account list or Roblox friend), nobody ignores anybody (an ignored pair hears
--     "offline": the ignore stays secret), a fresh entry on another public world server whose owner lets friends
--     join, the joiner on a world server, no Logic/UseBlocks reason (friendJoin), no cooldown.
--   * Party invitations from another server: one MessagingService topic (Config.Friends.inviteTopic), the message
--     `inviteMessage`, the receiving server keeps it only through `acceptInvite`, senders are limited by `limiter`.
--     Accepting = canJoin + teleport with TeleportData `teleportData("friendParty", ...)`; the inviter's server lets the
--     arrival into the party through `arrival` (it remembers its own invitations: TeleportData alone proves nothing).

local Config = require("../Config")
local Presence = require("./Presence")
local UseBlocks = require("./UseBlocks")

export type View = {
	friend: boolean, -- an account friend (S133) or a Roblox friend
	ignored: boolean, -- either side ignores the other
	status: Presence.Status,
	pj: string?, -- the friend's join rule ("friends" | "none")
	hereMode: string, -- the joiner's server mode
	block: string?, -- the first active Logic/UseBlocks reason of friendJoin
	cooldownUntil: number?, -- os.time
	-- the joiner's (inviter's) own side: an invitation from another server ends in canJoin against the inviter
	selfHidden: boolean?, -- appears offline (no presence entry)
	selfPj: string?, -- the own join rule ("friends" when nil)
	selfPrivate: boolean?, -- on a player's private server
}

export type Invite = {
	to: number,
	from: number,
	name: string,
	lvl: number,
	cls: string,
	j: string,
	exp: number,
}

export type Receiver = {
	here: boolean, -- the addressee plays on this server
	ignoresSender: boolean,
	pj: string?, -- the addressee's join rule
}

export type Arrival = {
	inviteKnown: boolean, -- this server sent that invitation and it is not older than exp + inviteGrace
	leaderHere: boolean,
	canLead: boolean, -- the inviter leads a party or has none
	size: number, -- members now (1 without a party)
	max: number,
}

export type Limiter = { allow: (userId: number, now: number) -> boolean }

local F = Config.Friends

local FriendJoin = {}

local STATUS_REASON: { [string]: string } = {
	offline = "friends.join.offline",
	unknown = "friends.join.unknown",
	arena = "friends.join.arena",
	tournament = "friends.join.tournament",
	private = "friends.join.private",
	here = "friends.join.sameServer",
}

-- The Locale key of a friendJoin block reason.
function FriendJoin.blockKey(reason: string): string
	return UseBlocks.key("friendJoin", reason)
end

-- Whether the joiner may go to the friend's server now. Returns (ok, reasonKey?).
function FriendJoin.canJoin(view: View, now: number): (boolean, string?)
	if not view.friend then
		return false, "friends.join.notFriend"
	end
	if view.ignored then
		return false, "friends.join.offline"
	end
	local statusReason = STATUS_REASON[view.status]
	if statusReason then
		return false, statusReason
	end
	if view.pj ~= "friends" then
		return false, "friends.join.closed"
	end
	if view.hereMode ~= "world" then
		return false, "friends.join.notHere"
	end
	if view.block then
		return false, FriendJoin.blockKey(view.block)
	end
	if view.cooldownUntil and now < view.cooldownUntil then
		return false, "friends.join.cooldown"
	end
	return true, nil
end

-- Whether a party invitation can go to a friend on another server (the inviter's view). Returns (ok, reasonKey?).
-- A friend on this server is invited by the S133 path (PartyInviteUser). Accepting is canJoin against the inviter, so
-- an inviter who appears offline, lets nobody join or plays on a private server cannot invite from another server.
function FriendJoin.canInvite(view: View): (boolean, string?)
	if not view.friend then
		return false, "friends.join.notFriend"
	end
	if view.ignored then
		return false, "friends.join.offline"
	end
	if view.status == "here" then
		return true, nil
	end
	if view.status ~= "world" and view.status ~= "private" then
		return false, STATUS_REASON[view.status] or "friends.join.offline"
	end
	if view.pj ~= "friends" then
		return false, "friends.join.closed"
	end
	if view.hereMode ~= "world" then
		return false, "friends.party.notHere"
	end
	if view.selfPrivate then
		return false, "friends.party.private"
	end
	if view.selfHidden then
		return false, "friends.party.invisible"
	end
	if view.selfPj == "none" then
		return false, "friends.party.closedSelf"
	end
	return true, nil
end

-- The message of a party invitation (well under the 1 KiB limit of MessagingService).
function FriendJoin.inviteMessage(fields: {
	to: number,
	from: number,
	name: string,
	lvl: number,
	cls: string,
	j: string,
	now: number,
	seconds: number?,
}): Invite
	return {
		to = fields.to,
		from = fields.from,
		name = string.sub(fields.name, 1, 40),
		lvl = fields.lvl,
		cls = fields.cls,
		j = fields.j,
		exp = fields.now + (fields.seconds or F.inviteSeconds),
	}
end

-- A received message as an invitation, nil when it is not one.
function FriendJoin.parseInvite(value: any): Invite?
	if
		type(value) ~= "table"
		or type(value.to) ~= "number"
		or type(value.from) ~= "number"
		or type(value.name) ~= "string"
		or type(value.j) ~= "string"
		or type(value.exp) ~= "number"
	then
		return nil
	end
	return {
		to = value.to,
		from = value.from,
		name = value.name,
		lvl = if type(value.lvl) == "number" then value.lvl else 0,
		cls = if type(value.cls) == "string" then value.cls else "",
		j = value.j,
		exp = value.exp,
	}
end

-- Whether the receiving server shows the invitation. Returns (ok, why?) with why "absent" | "self" | "ignored" |
-- "closed" | "expired".
function FriendJoin.acceptInvite(invite: Invite, receiver: Receiver, now: number): (boolean, string?)
	if not receiver.here then
		return false, "absent"
	end
	if invite.to == invite.from then
		return false, "self"
	end
	if receiver.ignoresSender then
		return false, "ignored"
	end
	if receiver.pj ~= "friends" then
		return false, "closed"
	end
	if now >= invite.exp then
		return false, "expired"
	end
	return true, nil
end

-- At most `perMinute` invitations per sender in any 60 s.
function FriendJoin.limiter(perMinute: number?): Limiter
	local max = perMinute or F.invitesPerMinute
	local sent: { [number]: { number } } = {}
	return {
		allow = function(userId: number, now: number): boolean
			local list: { number } = sent[userId] or {}
			local kept: { number } = {}
			for _, at in list do
				if now - at < 60 then
					table.insert(kept, at)
				end
			end
			if #kept >= max then
				sent[userId] = kept
				return false
			end
			table.insert(kept, now)
			sent[userId] = kept
			return true
		end,
	}
end

-- TeleportData of a join ("friend") or of an accepted party invitation ("friendParty", until = the invitation's exp).
function FriendJoin.teleportData(via: string, friend: number, untilAt: number?): { [string]: any }
	return { via = via, friend = friend, ["until"] = untilAt }
end

-- What the inviter's server does with an arrival: "join" (PartyService.AddMember), "expired" (a toast) or "none"
-- (not a party arrival).
function FriendJoin.arrival(data: any, ctx: Arrival): string
	if type(data) ~= "table" or data.via ~= "friendParty" or type(data.friend) ~= "number" then
		return "none"
	end
	if not ctx.inviteKnown or not ctx.leaderHere or not ctx.canLead or ctx.size >= ctx.max then
		return "expired"
	end
	return "join"
end

-- The toast of a failed teleport by Enum.TeleportResult name.
function FriendJoin.failKey(resultName: string?): string
	if resultName == "GameFull" then
		return "friends.join.full"
	elseif resultName == "GameNotFound" or resultName == "GameEnded" then
		return "friends.join.gone"
	end
	return "friends.join.failed"
end

return FriendJoin
