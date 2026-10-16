--!strict
-- S134f: the party finder board (Logic/PartyFinder).
local BossScaling = require("../src/shared/Logic/BossScaling")
local Config = require("../src/shared/Config")
local PartyFinder = require("../src/shared/Logic/PartyFinder")
local T = require("./Test")

type Listing = PartyFinder.Listing

local CFG = Config.PartyFinder

local function listing(over: { [string]: any }?): Listing
	local base: Listing = {
		id = 1,
		leaderId = 100,
		leaderName = "Ala",
		leaderClass = "Warrior",
		leaderLevel = 30,
		kind = "boss",
		target = "duskwood",
		nameKey = "boss.x",
		level = 40,
		minLevel = 30,
		maxLevel = 50,
		want = {},
		size = 2,
		createdAt = 0,
		expiresAt = 600,
	}
	for key, value in over or {} do
		(base :: any)[key] = value
	end
	return base
end

T.describe("PartyFinder.bandFor", function()
	T.it("boss: from the entry level up to level + bossAbove", function()
		local lo, hi = PartyFinder.bandFor("boss", 40)
		T.expect(lo).toBe(BossScaling.requiredLevel(40))
		T.expect(hi).toBe(40 + CFG.bossAbove)
	end)

	T.it("elite2, ground and invasion follow their offsets", function()
		local lo, hi = PartyFinder.bandFor("elite2", 50)
		T.expect({ lo, hi }).toEqual({ 50 - CFG.eliteBelow, 50 + CFG.eliteAbove })
		lo, hi = PartyFinder.bandFor("ground", 20, 25)
		T.expect({ lo, hi }).toEqual({ 20 - CFG.groundBelow, 25 + CFG.groundAbove })
		lo, hi = PartyFinder.bandFor("invasion", 60)
		T.expect({ lo, hi }).toEqual({ 60 - CFG.invasionBand, 60 + CFG.invasionBand })
	end)

	T.it("stays within 1..MaxLevel", function()
		local lo, _ = PartyFinder.bandFor("ground", 1, 3)
		T.expect(lo).toBe(1)
		local _, hi = PartyFinder.bandFor("boss", Config.MaxLevel)
		T.expect(hi).toBe(Config.MaxLevel)
	end)

	T.it("clampBand only narrows", function()
		local lo, hi = PartyFinder.clampBand(30, 50, 20, 60)
		T.expect({ lo, hi }).toEqual({ 30, 50 })
		lo, hi = PartyFinder.clampBand(30, 50, 35, 45)
		T.expect({ lo, hi }).toEqual({ 35, 45 })
		lo, hi = PartyFinder.clampBand(30, 50, 48, 40)
		T.expect({ lo, hi }).toEqual({ 48, 48 })
	end)
end)

T.describe("PartyFinder.canPost", function()
	local function poster(over: { [string]: any }?): PartyFinder.Poster
		local base: PartyFinder.Poster = {
			id = 100,
			level = 40,
			inParty = true,
			isLeader = true,
			partySize = 2,
			minLevel = 30,
			maxLevel = 50,
		}
		for key, value in over or {} do
			(base :: any)[key] = value
		end
		return base
	end

	T.it("checks leader, size, the server limit and the leader's level", function()
		local state = { listings = {}, maxListings = 2 }
		T.expect((PartyFinder.canPost(state, poster()))).toBe(true)
		T.expect((PartyFinder.canPost(state, poster({ inParty = false, isLeader = true, partySize = 1 })))).toBe(true)
		T.expect(select(2, PartyFinder.canPost(state, poster({ isLeader = false })))).toBe("finder.error.notLeader")
		T.expect(select(2, PartyFinder.canPost(state, poster({ partySize = CFG.maxMembers }))))
			.toBe("finder.error.full")
		T.expect(select(2, PartyFinder.canPost(state, poster({ level = 29 })))).toBe("finder.error.level")
		local full = { listings = { listing({ leaderId = 1 }), listing({ leaderId = 2 }) }, maxListings = 2 }
		T.expect(select(2, PartyFinder.canPost(full, poster()))).toBe("finder.error.limit")
		-- the leader's own listing does not count (a new one replaces it)
		local own = { listings = { listing({ leaderId = 1 }), listing({ leaderId = 100 }) }, maxListings = 2 }
		T.expect((PartyFinder.canPost(own, poster()))).toBe(true)
	end)

	T.it("a second listing replaces the first", function()
		local list = PartyFinder.post({ listing({ id = 1 }), listing({ id = 2, leaderId = 7 }) }, listing({ id = 3 }))
		T.expect(#list).toBe(2)
		T.expect(list[2].id).toBe(3)
		T.expect(list[1].leaderId).toBe(7)
	end)
end)

T.describe("PartyFinder.canJoin", function()
	local joiner = { id = 5, level = 40, class = "Cleric", inParty = false }

	T.it("joins a fitting listing", function()
		T.expect((PartyFinder.canJoin(listing(), joiner, 10))).toBe(true)
	end)

	T.it("names the reason", function()
		local function why(l: Listing, j: any): string?
			return select(2, PartyFinder.canJoin(l, j, 10))
		end
		T.expect(why(listing({ expiresAt = 10 }), joiner)).toBe("finder.error.expired")
		T.expect(why(listing({ leaderId = 5 }), joiner)).toBe("finder.error.own")
		T.expect(why(listing(), { id = 5, level = 40, class = "Cleric", inParty = true })).toBe("finder.error.inParty")
		T.expect(why(listing(), { id = 5, level = 29, class = "Cleric", inParty = false })).toBe("finder.error.level")
		T.expect(why(listing({ size = CFG.maxMembers }), joiner)).toBe("finder.error.full")
		T.expect(why(listing({ want = { "Warrior", "Mage" } }), joiner)).toBe("finder.error.class")
		T.expect((PartyFinder.canJoin(listing({ want = { "Cleric" } }), joiner, 10))).toBe(true)
	end)
end)

T.describe("PartyFinder.visible and prune", function()
	T.it("puts fitting listings first, then the newest; hides expired ones", function()
		local list = {
			listing({ id = 1, createdAt = 1, minLevel = 60, maxLevel = 70 }),
			listing({ id = 2, createdAt = 2 }),
			listing({ id = 3, createdAt = 3 }),
			listing({ id = 4, createdAt = 4, expiresAt = 5 }),
		}
		local shown = PartyFinder.visible(list, 40, 10)
		T.expect(#shown).toBe(3)
		T.expect(shown[1].id).toBe(3)
		T.expect(shown[2].id).toBe(2)
		T.expect(shown[3].id).toBe(1)
	end)

	T.it("prune drops expired, full and dead listings", function()
		local list = {
			listing({ id = 1 }),
			listing({ id = 2, expiresAt = 5 }),
			listing({ id = 3, size = CFG.maxMembers }),
			listing({ id = 4, leaderId = 9 }),
		}
		local kept = PartyFinder.prune(list, 10, function(l)
			return l.leaderId ~= 9
		end)
		T.expect(#kept).toBe(1)
		T.expect(kept[1].id).toBe(1)
	end)

	T.it("validWant takes at most maxWant known classes, once each", function()
		T.expect(PartyFinder.validWant({ "Cleric", "Mage" })).toEqual({ "Cleric", "Mage" })
		T.expect(PartyFinder.validWant({ "Cleric", "Cleric" })).toBeNil()
		T.expect(PartyFinder.validWant({ "Bard" })).toBeNil()
		T.expect(PartyFinder.validWant({})).toEqual({})
		T.expect(PartyFinder.validWant("x")).toBeNil()
	end)

	T.it("offers targets from the data", function()
		T.expect(#PartyFinder.targets("boss") > 0).toBe(true)
		T.expect(#PartyFinder.targets("ground") > 0).toBe(true)
		T.expect(#PartyFinder.targets("elite2") > 0).toBe(true)
		T.expect(#PartyFinder.targets("invasion")).toBe(0)
		for _, target in PartyFinder.targets("boss") do
			T.expect(target.at ~= nil).toBe(true)
		end
		local near = PartyFinder.nearest("ground", 1)
		T.expect(near ~= nil).toBe(true)
	end)
end)
