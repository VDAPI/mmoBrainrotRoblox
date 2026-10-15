--!strict
-- Player interactions (S133), pure: the player menu (which actions, in which order, which are greyed out and why),
-- friends and ignored players (account.social, limits in Config.Social), whisper rules, presence status and the
-- rules of letters between players (Config.PlayerMail: lengths, items, fee, daily limit reset at 00:00 UTC).
-- The server (SocialService, MailService) and the client (PartyController, FriendsWindow, MailCompose) both use it.

local Config = require("../Config")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

export type SocialEntry = Types.SocialEntry
export type SocialData = Types.SocialData

-- What the client knows about the player it opens the menu for.
export type MenuContext = {
	sameMap: boolean, -- "Follow player" needs the same map
	isFriend: boolean,
	isIgnored: boolean, -- the local player ignores the target
	friendsFull: boolean?,
	ignoredFull: boolean?,
	guildRank: string?, -- the local player's guild rank ("leader" | "officer" | ...)
	targetInGuild: boolean?,
	inMyParty: boolean?, -- the target is already in the local player's party
	notPartyLeader: boolean?, -- the local player is in a party and does not lead it
	duelAllowed: boolean, -- false on arena / tournament servers
	arenaChallenge: boolean?, -- an arena invitation by name exists (S126-S127 have none: always false in the game)
	canReport: boolean?, -- a client API that opens the Roblox report dialog works
	following: boolean?, -- "Follow player" is running for this target
}

export type MenuEntry = {
	id: string, -- "whisper" | "mail" | "trade" | "duel" | "arena" | "party" | "guild" | "profile" | "friend" | "ignore" | "follow" | "report"
	labelKey: string,
	enabled: boolean,
	reasonKey: string?, -- why it is greyed out (Locale key)
}

export type LetterDraft = {
	subject: string,
	body: string,
	gold: number,
	itemCount: number,
}

export type MailCounter = { day: number, n: number }

export type Presence = { j: string, m: string?, l: number?, c: string?, n: string?, t: number }

export type Status = "here" | "online" | "offline" | "unknown"

local Social = {}

Social.MENU_ORDER =
	{ "whisper", "mail", "trade", "duel", "arena", "party", "guild", "profile", "friend", "ignore", "follow", "report" }

local function entry(id: string, labelKey: string, reasonKey: string?): MenuEntry
	return { id = id, labelKey = labelKey, enabled = reasonKey == nil, reasonKey = reasonKey }
end

-- The player menu. Entries that do not exist by a fixed rule (the guild invite without a leader / officer rank, the
-- arena challenge, the report) are left out; anything else unavailable right now stays in, greyed out with a reason.
function Social.menuEntries(ctx: MenuContext): { MenuEntry }
	local ignored = if ctx.isIgnored then "social.reason.youIgnore" else nil
	local list: { MenuEntry } = {}
	table.insert(list, entry("whisper", "social.menu.whisper", ignored))
	table.insert(list, entry("mail", "social.menu.mail", ignored))
	table.insert(list, entry("trade", "social.menu.trade", ignored))
	table.insert(
		list,
		entry("duel", "social.menu.duel", ignored or (if ctx.duelAllowed then nil else "social.reason.noDuelHere"))
	)
	if ctx.arenaChallenge then
		table.insert(list, entry("arena", "social.menu.arena", ignored))
	end
	local partyReason = ignored
		or (if ctx.inMyParty then "social.reason.inMyParty" else nil)
		or (if ctx.notPartyLeader then "social.reason.notLeader" else nil)
	table.insert(list, entry("party", "social.menu.party", partyReason))
	if ctx.guildRank == "leader" or ctx.guildRank == "officer" then
		table.insert(
			list,
			entry(
				"guild",
				"social.menu.guild",
				ignored or (if ctx.targetInGuild then "social.reason.hasGuild" else nil)
			)
		)
	end
	table.insert(list, entry("profile", "social.menu.profile"))
	if ctx.isFriend then
		table.insert(list, entry("friend", "social.menu.unfriend"))
	else
		table.insert(
			list,
			entry(
				"friend",
				"social.menu.friend",
				ignored or (if ctx.friendsFull then "social.reason.friendsFull" else nil)
			)
		)
	end
	if ctx.isIgnored then
		table.insert(list, entry("ignore", "social.menu.unignore"))
	else
		table.insert(
			list,
			entry("ignore", "social.menu.ignore", if ctx.ignoredFull then "social.reason.ignoredFull" else nil)
		)
	end
	if ctx.following then
		table.insert(list, entry("follow", "social.menu.followStop"))
	else
		table.insert(list, entry("follow", "social.menu.follow", if ctx.sameMap then nil else "social.reason.otherMap"))
	end
	if ctx.canReport then
		table.insert(list, entry("report", "social.menu.report"))
	end
	return list
end

-- Friends and ignored ------------------------------------------------------------------------------------------------

function Social.empty(): SocialData
	return { friends = {}, ignored = {} }
end

local function cleanList(value: any): { [string]: SocialEntry }
	local out: { [string]: SocialEntry } = {}
	if type(value) ~= "table" then
		return out
	end
	for key, e in value do
		if type(key) == "string" and tonumber(key) ~= nil and type(e) == "table" and type(e.name) == "string" then
			out[key] = {
				name = e.name,
				class = if type(e.class) == "string" then e.class else nil,
				since = if type(e.since) == "number" then e.since else 0,
			}
		end
	end
	return out
end

-- Accepts anything stored and returns usable lists (keys are tostring(userId)).
function Social.normalize(value: any): SocialData
	if type(value) ~= "table" then
		return Social.empty()
	end
	return { friends = cleanList(value.friends), ignored = cleanList(value.ignored) }
end

function Social.count(list: { [string]: any }): number
	local n = 0
	for _ in list do
		n += 1
	end
	return n
end

function Social.key(userId: number): string
	return tostring(math.floor(userId))
end

function Social.isFriend(data: SocialData?, userId: number): boolean
	return data ~= nil and data.friends[Social.key(userId)] ~= nil
end

function Social.isIgnored(data: SocialData?, userId: number): boolean
	return data ~= nil and data.ignored[Social.key(userId)] ~= nil
end

-- Adds a friend (one side; the server writes both accounts). Returns (ok, errorKey?).
function Social.addFriend(data: SocialData, userId: number, e: SocialEntry, max: number?): (boolean, string?)
	local key = Social.key(userId)
	if data.friends[key] then
		return false, "social.error.alreadyFriend"
	end
	if data.ignored[key] then
		return false, "social.error.unavailable"
	end
	if Social.count(data.friends) >= (max or Config.Social.maxFriends) then
		return false, "social.error.friendsFull"
	end
	data.friends[key] = { name = e.name, class = e.class, since = e.since }
	return true, nil
end

function Social.removeFriend(data: SocialData, userId: number): boolean
	local key = Social.key(userId)
	local had = data.friends[key] ~= nil
	data.friends[key] = nil
	return had
end

-- Ignores a player: also ends the friendship (this side). Returns (ok, errorKey?).
function Social.ignore(data: SocialData, userId: number, e: SocialEntry, max: number?): (boolean, string?)
	local key = Social.key(userId)
	if data.ignored[key] then
		return false, "social.error.alreadyIgnored"
	end
	if Social.count(data.ignored) >= (max or Config.Social.maxIgnored) then
		return false, "social.error.ignoredFull"
	end
	data.friends[key] = nil
	data.ignored[key] = { name = e.name, class = e.class, since = e.since }
	return true, nil
end

function Social.unignore(data: SocialData, userId: number): boolean
	local key = Social.key(userId)
	local had = data.ignored[key] ~= nil
	data.ignored[key] = nil
	return had
end

-- Whispers: "all" lets anyone write, "friends" only friends and guild mates.
function Social.whisperAllowed(setting: string?, isFriend: boolean, sameGuild: boolean): boolean
	if setting == "friends" then
		return isFriend or sameGuild
	end
	return true
end

-- The private chat channel of two players (the same name whoever opens it).
function Social.channelName(a: number, b: number): string
	return `Whisper_{math.min(a, b)}_{math.max(a, b)}`
end

-- Presence of a player seen from server `myJob`: "here" (this server), "online" (another one), "offline".
function Social.presenceStatus(p: Presence?, now: number, myJob: string, ttl: number?): Status
	if type(p) ~= "table" or type(p.t) ~= "number" or now - p.t > (ttl or Config.Social.presenceTtl) then
		return "offline"
	end
	return if p.j == myJob then "here" else "online"
end

-- Letters --------------------------------------------------------------------------------------------------------

-- Characters of a UTF-8 string, nil when it is not valid UTF-8.
function Social.textLength(text: string): number?
	return utf8.len(text)
end

-- Drops control characters (keeps line breaks in a body), trims and squeezes blank lines. A subject is one line.
function Social.cleanText(text: string, multiline: boolean): string
	local out = string.gsub(text, "\r\n?", "\n")
	if multiline then
		out = string.gsub(out, "[%z\1-\9\11-\31\127]", "")
		out = string.gsub(out, "\n\n\n+", "\n\n")
	else
		out = string.gsub(out, "[%z\1-\31\127]", " ")
	end
	out = string.gsub(out, "^%s+", "")
	out = string.gsub(out, "%s+$", "")
	return out
end

-- Shape of a letter before the items are looked at. Returns (ok, errorKey?).
function Social.validateLetter(draft: LetterDraft, rules: typeof(Config.PlayerMail)?): (boolean, string?)
	local r = rules or Config.PlayerMail
	local subjectLength = Social.textLength(draft.subject)
	local bodyLength = Social.textLength(draft.body)
	if subjectLength == nil or bodyLength == nil then
		return false, "error.badRequest"
	end
	if subjectLength == 0 and bodyLength == 0 then
		return false, "mail.error.emptyLetter"
	end
	if subjectLength > r.subjectMax then
		return false, "mail.error.subjectLong"
	end
	if bodyLength > r.bodyMax then
		return false, "mail.error.bodyLong"
	end
	if draft.gold < 0 or draft.gold ~= math.floor(draft.gold) or draft.gold ~= draft.gold then
		return false, "error.badRequest"
	end
	if draft.itemCount < 0 or draft.itemCount > r.maxItems then
		return false, "mail.error.tooManyItems"
	end
	return true, nil
end

-- Postage in gold: a fixed part and a part per attached item.
function Social.letterFee(itemCount: number, rules: typeof(Config.PlayerMail)?): number
	local r = rules or Config.PlayerMail
	return r.feeBase + r.feePerItem * math.max(0, itemCount)
end

-- Gold or items leave only at a mailbox (the same rule as collecting); a plain letter goes from anywhere.
function Social.needsMailbox(gold: number, itemCount: number): boolean
	return gold > 0 or itemCount > 0
end

-- Whether a backpack item may go into a letter (whole stack). Returns (ok, errorKey?).
function Social.mailableItem(item: ItemInstance?): (boolean, string?)
	if not item then
		return false, "error.badRequest"
	end
	if item.locked then
		return false, "item.error.locked"
	end
	if item.bound then
		return false, "mail.error.bound"
	end
	return true, nil
end

local function dayOf(now: number): number
	return math.floor(now / 86400)
end

-- Letters sent today (UTC) by the counter's owner.
function Social.sentToday(counter: MailCounter?, now: number): number
	if type(counter) ~= "table" or counter.day ~= dayOf(now) then
		return 0
	end
	return counter.n
end

function Social.canSendToday(counter: MailCounter?, now: number, perDay: number?): (boolean, string?)
	if Social.sentToday(counter, now) >= (perDay or Config.PlayerMail.perDay) then
		return false, "mail.error.dailyLimit"
	end
	return true, nil
end

-- The counter after one more letter.
function Social.countSent(counter: MailCounter?, now: number): MailCounter
	return { day = dayOf(now), n = Social.sentToday(counter, now) + 1 }
end

return Social
