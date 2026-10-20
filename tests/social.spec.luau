--!strict
-- S133: player menu, friends and ignored players, whisper rules, presence and letters between players (Logic/Social).

local Config = require("../src/shared/Config")
local FriendJoin = require("../src/shared/Logic/FriendJoin")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Mail = require("../src/shared/Logic/Mail")
local Presence = require("../src/shared/Logic/Presence")
local Rng = require("../src/shared/Logic/Rng")
local Social = require("../src/shared/Logic/Social")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function ctx(extra: { [string]: any }?): Social.MenuContext
	local base: any = { sameMap = true, isFriend = false, isIgnored = false, duelAllowed = true }
	for k, v in extra or {} do
		base[k] = v
	end
	return base
end

local function ids(list: { Social.MenuEntry }): { string }
	local out = {}
	for _, e in list do
		table.insert(out, e.id)
	end
	return out
end

local function find(list: { Social.MenuEntry }, id: string): Social.MenuEntry
	for _, e in list do
		if e.id == id then
			return e
		end
	end
	error(`no entry {id}`)
end

local function entry(name: string): Social.SocialEntry
	return { name = name, class = "Warrior", since = 1 }
end

local DAY = 86400

T.describe("Social.menuEntries", function()
	T.it("lists the actions in the fixed order, guild, arena and report only when they exist", function()
		T.expect(ids(Social.menuEntries(ctx()))).toEqual({
			"whisper",
			"mail",
			"trade",
			"duel",
			"party",
			"profile",
			"friend",
			"ignore",
			"follow",
		})
		local full = Social.menuEntries(ctx({ guildRank = "officer", arenaChallenge = true, canReport = true }))
		T.expect(ids(full)).toEqual(Social.MENU_ORDER)
		T.expect(ids(Social.menuEntries(ctx({ guildRank = "member" })))).toEqual(ids(Social.menuEntries(ctx())))
		T.expect(table.find(ids(Social.menuEntries(ctx({ guildRank = "leader" }))), "guild") ~= nil).toBe(true)
	end)

	T.it("keeps unavailable actions greyed out with a reason", function()
		local list = Social.menuEntries(ctx({
			sameMap = false,
			duelAllowed = false,
			inMyParty = true,
			guildRank = "leader",
			targetInGuild = true,
			friendsFull = true,
		}))
		T.expect(find(list, "follow")).toEqual({
			id = "follow",
			labelKey = "social.menu.follow",
			enabled = false,
			reasonKey = "social.reason.otherMap",
		})
		T.expect(find(list, "duel").reasonKey).toBe("social.reason.noDuelHere")
		T.expect(find(list, "party").reasonKey).toBe("social.reason.inMyParty")
		T.expect(find(list, "guild").reasonKey).toBe("social.reason.hasGuild")
		T.expect(find(list, "friend").reasonKey).toBe("social.reason.friendsFull")
		T.expect(find(list, "profile").enabled).toBe(true)
		T.expect(find(list, "whisper").enabled).toBe(true)
		T.expect(find(Social.menuEntries(ctx({ notPartyLeader = true })), "party").reasonKey)
			.toBe("social.reason.notLeader")
	end)

	T.it("an ignored player: contacts greyed out, the ignore entry turns into unignore", function()
		local list = Social.menuEntries(ctx({ isIgnored = true }))
		for _, id in { "whisper", "mail", "trade", "duel", "party", "friend" } do
			T.expect(find(list, id).reasonKey).toBe("social.reason.youIgnore")
		end
		T.expect(find(list, "ignore")).toEqual({ id = "ignore", labelKey = "social.menu.unignore", enabled = true })
		T.expect(find(list, "profile").enabled).toBe(true)
	end)

	T.it("friend, follow labels switch with the state", function()
		local list = Social.menuEntries(ctx({ isFriend = true, following = true }))
		T.expect(find(list, "friend").labelKey).toBe("social.menu.unfriend")
		T.expect(find(list, "follow").labelKey).toBe("social.menu.followStop")
		T.expect(find(Social.menuEntries(ctx()), "friend").labelKey).toBe("social.menu.friend")
	end)

	T.it("every label and reason exists in both languages", function()
		local list = Social.menuEntries(ctx({ guildRank = "leader", arenaChallenge = true, canReport = true }))
		local keys: { string } = {}
		for _, e in list do
			table.insert(keys, e.labelKey)
		end
		for _, key in
			{
				"social.menu.unfriend",
				"social.menu.unignore",
				"social.menu.followStop",
				"social.reason.youIgnore",
				"social.reason.noDuelHere",
				"social.reason.inMyParty",
				"social.reason.notLeader",
				"social.reason.hasGuild",
				"social.reason.friendsFull",
				"social.reason.ignoredFull",
				"social.reason.otherMap",
			}
		do
			table.insert(keys, key)
		end
		for _, key in keys do
			T.expect({ key = key, pl = pl[key] ~= nil, en = en[key] ~= nil })
				.toEqual({ key = key, pl = true, en = true })
		end
	end)
end)

T.describe("Social: friends and ignored", function()
	T.it("adds friends up to the limit, once each", function()
		local data = Social.empty()
		T.expect({ Social.addFriend(data, 1, entry("A"), 2) }).toEqual({ true })
		T.expect({ Social.addFriend(data, 1, entry("A"), 2) }).toEqual({ false, "social.error.alreadyFriend" })
		T.expect({ Social.addFriend(data, 2, entry("B"), 2) }).toEqual({ true })
		T.expect({ Social.addFriend(data, 3, entry("C"), 2) }).toEqual({ false, "social.error.friendsFull" })
		T.expect(Social.isFriend(data, 2)).toBe(true)
		T.expect(Social.count(data.friends)).toBe(2)
		T.expect(Social.removeFriend(data, 2)).toBe(true)
		T.expect(Social.removeFriend(data, 2)).toBe(false)
		T.expect(Config.Social.maxFriends).toBe(50)
		T.expect(Config.Social.maxIgnored).toBe(100)
	end)

	T.it("ignoring ends the friendship and blocks a new one", function()
		local data = Social.empty()
		Social.addFriend(data, 7, entry("Borys"))
		T.expect({ Social.ignore(data, 7, entry("Borys")) }).toEqual({ true })
		T.expect(Social.isFriend(data, 7)).toBe(false)
		T.expect(Social.isIgnored(data, 7)).toBe(true)
		T.expect({ Social.addFriend(data, 7, entry("Borys")) }).toEqual({ false, "social.error.unavailable" })
		T.expect({ Social.ignore(data, 7, entry("Borys")) }).toEqual({ false, "social.error.alreadyIgnored" })
		T.expect(Social.unignore(data, 7)).toBe(true)
		T.expect(Social.isIgnored(data, 7)).toBe(false)
	end)

	T.it("ignored list has its own limit", function()
		local data = Social.empty()
		T.expect({ Social.ignore(data, 1, entry("A"), 1) }).toEqual({ true })
		T.expect({ Social.ignore(data, 2, entry("B"), 1) }).toEqual({ false, "social.error.ignoredFull" })
	end)

	T.it("normalize drops garbage and keeps valid entries", function()
		local data = Social.normalize({
			friends = { ["5"] = { name = "Ola", class = "Mage", since = 3 }, bad = { name = "x" }, ["6"] = 4 },
			ignored = "nope",
		})
		T.expect(data).toEqual({ friends = { ["5"] = { name = "Ola", class = "Mage", since = 3 } }, ignored = {} })
		T.expect(Social.normalize(nil)).toEqual(Social.empty())
	end)

	T.it("whispers only from friends and guild mates when set so", function()
		T.expect(Social.whisperAllowed("all", false, false)).toBe(true)
		T.expect(Social.whisperAllowed("friends", false, false)).toBe(false)
		T.expect(Social.whisperAllowed("friends", true, false)).toBe(true)
		T.expect(Social.whisperAllowed("friends", false, true)).toBe(true)
		T.expect(Social.channelName(20, 10)).toBe("Whisper_10_20")
		T.expect(Social.channelName(10, 20)).toBe(Social.channelName(20, 10))
	end)

	-- S150: presence statuses moved to Logic/Presence (tests/friends.spec); "online" became world / private / arena /
	-- tournament
	T.it("presence: here, another world server, offline by the entry's age", function()
		local p = Presence.record({ j = "job-a", m = "world", t = 1000, pj = "friends" })
		T.expect(Presence.statusOf(p, "job-a", 1050, 120)).toBe("here")
		T.expect(Presence.statusOf(p, "job-b", 1050, 120)).toBe("world")
		T.expect(Presence.statusOf(p, "job-b", 1121, 120)).toBe("offline")
		T.expect(Presence.statusOf(nil, "job-b", 1050, 120)).toBe("offline")
	end)
end)

-- S150: the row of a friend in the friends window (Join, Invite to party, Whisper, Write a letter; "..." Remove,
-- Ignore) for a friend here and on another server.
T.describe("Social.friendRowEntries", function()
	local function view(extra: { [string]: any }?): FriendJoin.View
		local base: any = {
			friend = true,
			ignored = false,
			status = "world",
			pj = "friends",
			hereMode = "world",
		}
		for k, v in extra or {} do
			base[k] = v
		end
		return base
	end
	local function rowFind(row: Social.FriendRow, id: string): Social.MenuEntry
		for _, e in row.primary do
			if e.id == id then
				return e
			end
		end
		for _, e in row.more do
			if e.id == id then
				return e
			end
		end
		error(`no entry {id}`)
	end

	T.it("a friend on another world server: Join and the party invitation work, whisper does not", function()
		local row = Social.friendRowEntries({ view = view(), now = 100 })
		T.expect(ids(row.primary)).toEqual({ "join", "party", "whisper", "mail" })
		T.expect(ids(row.more)).toEqual({ "remove", "ignore" })
		T.expect(rowFind(row, "join").enabled).toBe(true)
		T.expect(rowFind(row, "party")).toEqual({ id = "party", labelKey = "friends.party.invite", enabled = true })
		T.expect(rowFind(row, "whisper").reasonKey).toBe("friends.reason.notHere")
		T.expect(rowFind(row, "mail").enabled).toBe(true)
	end)

	T.it("a friend here: whisper and the local invitation, Join greyed (same server)", function()
		local row = Social.friendRowEntries({ view = view({ status = "here" }), now = 100 })
		T.expect(rowFind(row, "join").reasonKey).toBe("friends.join.sameServer")
		T.expect(rowFind(row, "party").enabled).toBe(true)
		T.expect(rowFind(row, "whisper").enabled).toBe(true)
		local inParty = Social.friendRowEntries({ view = view({ status = "here" }), now = 100, inMyParty = true })
		T.expect(rowFind(inParty, "party").reasonKey).toBe("social.reason.inMyParty")
	end)

	T.it("greyed out with a reason: arena, private server, closed server, a block, not the leader", function()
		local arena = Social.friendRowEntries({ view = view({ status = "arena" }), now = 100 })
		T.expect(rowFind(arena, "join").reasonKey).toBe("friends.join.arena")
		T.expect(rowFind(arena, "party").reasonKey).toBe("friends.join.arena")
		local private = Social.friendRowEntries({ view = view({ status = "private" }), now = 100 })
		T.expect(rowFind(private, "join").reasonKey).toBe("friends.join.private")
		T.expect(rowFind(private, "party").enabled).toBe(true)
		local closed = Social.friendRowEntries({ view = view({ pj = "none" }), now = 100 })
		T.expect(rowFind(closed, "join").reasonKey).toBe("friends.join.closed")
		T.expect(rowFind(closed, "party").reasonKey).toBe("friends.join.closed")
		local blocked = Social.friendRowEntries({ view = view({ block = "combat" }), now = 100 })
		T.expect(rowFind(blocked, "join").reasonKey).toBe("friends.block.combat")
		T.expect(rowFind(blocked, "party").enabled).toBe(true)
		local follower = Social.friendRowEntries({ view = view(), now = 100, notPartyLeader = true })
		T.expect(rowFind(follower, "party").reasonKey).toBe("social.reason.notLeader")
		local hidden = Social.friendRowEntries({ view = view({ selfHidden = true }), now = 100 })
		T.expect(rowFind(hidden, "party").reasonKey).toBe("friends.party.invisible")
		T.expect(rowFind(hidden, "join").enabled).toBe(true)
		local offline = Social.friendRowEntries({ view = view({ status = "offline" }), now = 100 })
		T.expect(rowFind(offline, "join").reasonKey).toBe("friends.join.offline")
		T.expect(rowFind(offline, "mail").enabled).toBe(true)
	end)

	T.it("every label and reason of the row exists in both languages", function()
		local keys = {}
		local views = {}
		for _, status in { "here", "world", "private", "arena", "tournament", "offline", "unknown" } do
			table.insert(views, view({ status = status }))
		end
		for _, own in { { selfPrivate = true }, { selfHidden = true }, { selfPj = "none" } } do
			table.insert(views, view(own))
		end
		for _, v in views do
			local row = Social.friendRowEntries({ view = v, now = 100 })
			for _, list in { row.primary, row.more } do
				for _, e in list do
					table.insert(keys, e.labelKey)
					if e.reasonKey then
						table.insert(keys, e.reasonKey)
					end
				end
			end
		end
		for _, key in keys do
			T.expect({ key = key, pl = pl[key] ~= nil, en = en[key] ~= nil })
				.toEqual({ key = key, pl = true, en = true })
		end
	end)
end)

T.describe("Social: letters", function()
	local rules = Config.PlayerMail

	T.it("checks subject and body lengths in characters", function()
		local ok = { subject = "Hej", body = "Treść", gold = 0, itemCount = 0 }
		T.expect({ Social.validateLetter(ok) }).toEqual({ true })
		T.expect({ Social.validateLetter({ subject = "", body = "", gold = 0, itemCount = 0 }) }).toEqual({
			false,
			"mail.error.emptyLetter",
		})
		T.expect({
			Social.validateLetter({ subject = string.rep("ą", rules.subjectMax), body = "", gold = 0, itemCount = 0 }),
		}).toEqual({
			true,
		})
		T.expect({
			Social.validateLetter({
				subject = string.rep("a", rules.subjectMax + 1),
				body = "",
				gold = 0,
				itemCount = 0,
			}),
		}).toEqual({ false, "mail.error.subjectLong" })
		T.expect({
			Social.validateLetter({
				subject = "x",
				body = string.rep("ż", rules.bodyMax + 1),
				gold = 0,
				itemCount = 0,
			}),
		}).toEqual({ false, "mail.error.bodyLong" })
		T.expect({ Social.validateLetter({ subject = "x", body = "\255", gold = 0, itemCount = 0 }) }).toEqual({
			false,
			"error.badRequest",
		})
	end)

	T.it("limits items and gold", function()
		T.expect({ Social.validateLetter({ subject = "x", body = "", gold = 0, itemCount = rules.maxItems }) })
			.toEqual({
				true,
			})
		T.expect({ Social.validateLetter({ subject = "x", body = "", gold = 0, itemCount = rules.maxItems + 1 }) })
			.toEqual({
				false,
				"mail.error.tooManyItems",
			})
		T.expect({ Social.validateLetter({ subject = "x", body = "", gold = -1, itemCount = 0 }) }).toEqual({
			false,
			"error.badRequest",
		})
		T.expect({ Social.validateLetter({ subject = "x", body = "", gold = 1.5, itemCount = 0 }) }).toEqual({
			false,
			"error.badRequest",
		})
	end)

	T.it("bound and locked items stay home", function()
		local sword = ItemRoll.rollItem("sword1h_10", 10, 2, Rng.new(1), "u1")
		sword.bound = false
		T.expect({ Social.mailableItem(sword) }).toEqual({ true })
		local bound = table.clone(sword)
		bound.bound = true
		T.expect({ Social.mailableItem(bound) }).toEqual({ false, "mail.error.bound" })
		local locked = table.clone(sword)
		locked.locked = true
		T.expect({ Social.mailableItem(locked) }).toEqual({ false, "item.error.locked" })
		T.expect({ Social.mailableItem(nil) }).toEqual({ false, "error.badRequest" })
	end)

	T.it("postage: a fixed part and a part per item; the mailbox only for gold or items", function()
		T.expect(Social.letterFee(0)).toBe(rules.feeBase)
		T.expect(Social.letterFee(3)).toBe(rules.feeBase + 3 * rules.feePerItem)
		T.expect(Social.needsMailbox(0, 0)).toBe(false)
		T.expect(Social.needsMailbox(5, 0)).toBe(true)
		T.expect(Social.needsMailbox(0, 1)).toBe(true)
	end)

	T.it("daily limit resets at midnight UTC", function()
		local now = 20000 * DAY + 3600
		local counter: Social.MailCounter? = nil
		for _ = 1, 3 do
			T.expect({ Social.canSendToday(counter, now, 3) }).toEqual({ true })
			counter = Social.countSent(counter, now)
		end
		T.expect({ Social.canSendToday(counter, now, 3) }).toEqual({ false, "mail.error.dailyLimit" })
		T.expect({ Social.canSendToday(counter, 20001 * DAY - 1, 3) }).toEqual({ false, "mail.error.dailyLimit" })
		T.expect({ Social.canSendToday(counter, 20001 * DAY, 3) }).toEqual({ true })
		T.expect(Social.countSent(counter, 20001 * DAY)).toEqual({ day = 20001, n = 1 })
		T.expect(Social.sentToday({ day = 0, n = 9 }, now)).toBe(0)
	end)

	T.it("cleans text: one line subjects, no control characters", function()
		T.expect(Social.cleanText("  Witaj\tprzyjacielu\n ", false)).toBe("Witaj przyjacielu")
		T.expect(Social.cleanText("a\r\nb\n\n\n\nc\1", true)).toBe("a\nb\n\nc")
	end)

	T.it("a parcel from a player carries text within the limits and is returnable with contents", function()
		local box = Mail.newBox()
		local parcel: Mail.Parcel = {
			id = "p1",
			from = "player",
			fromName = "Aria",
			fromId = 77,
			fromChar = "c1",
			subjectKey = "mail.player.subject",
			subject = "Hej",
			body = "Treść listu",
			gold = 10,
			items = {},
			createdAt = 0,
			expiresAt = Mail.LIFETIME,
		}
		T.expect({ Mail.add(box, parcel, 0) }).toEqual({ true })
		T.expect(Mail.returnable(parcel)).toBe(true)
		local plain = table.clone(parcel)
		plain.id, plain.gold = "p2", 0
		T.expect(Mail.returnable(plain)).toBe(false)
		local long = table.clone(parcel)
		long.id, long.body = "p3", string.rep("a", Config.PlayerMail.bodyMax + 1)
		T.expect({ Mail.add(box, long, 0) }).toEqual({ false, "error.badRequest" })
		local spoofed = table.clone(parcel)
		spoofed.id, spoofed.from = "p4", "system"
		T.expect({ Mail.add(box, spoofed, 0) }).toEqual({ false, "error.badRequest" })
		local anonymous = table.clone(parcel)
		anonymous.id, anonymous.fromId = "p5", nil
		T.expect({ Mail.add(box, anonymous, 0) }).toEqual({ false, "error.badRequest" })
	end)
end)
