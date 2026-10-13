--!strict
-- S101b (DESIGN-15 §3.5): quest dialogue. Answers (Logic/Dialogue: canSay, pages, recall, focus, hint, validation),
-- comments (Logic/Barks: events, limiter, speaker, picks, validation), the texts of both languages and the content
-- minimums every quest session fills in: S102-S105 add their story quests to NEW_QUESTS.S10x and their chapter to
-- COMPANION_GROUPS.S10x (S103-S105 also BARKS_ONLY.S10x: the chapter's existing quests), S106-S108 their side quests
-- and region. S109 audits the whole.

local Barks = require("../src/shared/Logic/Barks")
local Config = require("../src/shared/Config")
local Dialogue = require("../src/shared/Logic/Dialogue")
local Quests = require("../src/shared/Data/Quests")
local Talk = require("../src/shared/Data/Quests/Talk")
local Test = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- Content minimums (DESIGN-15 §3.5) -------------------------------------------------------------------------------

-- New quests of a session (S102-S105: story ids, S106-S108: side ids of the region), e.g.
-- NEW_QUESTS.S102 = { "frostSign", ... }: each has a page with 2-3 answers and every event of Barks.required.
local NEW_QUESTS: { [string]: { string } } = {
	S102 = { "frostRuins", "frostSign", "warrenCharms", "warCouncil" },
}

-- Groups of a session that need at least two quests with a companion among its NEW_QUESTS: S102-S105
-- { chapter = n } (story quests of the chapter's level band), S106-S108 { map = "duskwood" | "ashen" | "frostpeak" }
-- (side quests whose companion walks on that map).
local COMPANION_GROUPS: { [string]: { { chapter: number?, map: string? } } } = {
	S102 = { { chapter = 1 } },
}

-- Existing quests that got comments only (no answers): every event of Barks.required.
local BARKS_ONLY: { [string]: { string } } = {
	S101b = {
		-- the story 1-20
		"arrival",
		"healer",
		"smith",
		"portal",
		"firstHunt",
		"gearUp",
		"wolves",
		"wolfFangs",
		"boars",
		"herbs",
		"banditRoad",
		"banditOrders",
		"goblinCamp",
		"mosshollow",
		"grimrok",
		-- the 28 side quests of the Meadows
		"side_granary",
		"side_rabbits",
		"side_fence",
		"side_sheep",
		"side_grainCart",
		"side_shrine",
		"side_stoneCircle",
		"side_father",
		"side_toads",
		"side_venom",
		"side_net",
		"side_roast",
		"side_woodcutter",
		"side_logs",
		"side_shiny",
		"side_mill",
		"side_smugglers",
		"side_wagon",
		"side_goods",
		"side_wanted",
		"side_ore",
		"side_tools",
		"side_tunnels",
		"side_totem",
		"side_foreman",
		"side_hunter",
		"side_bears",
		"side_den",
		-- the stable arc (S96)
		"side_stable_harness",
		"side_stable_stallion",
		"side_stable_ride",
	},
}

-- Existing quests that got answers, page variants and a companion in S101b (every effect kind is in the data).
local RETROFIT = {
	S101b = {
		choices = { "side_venom", "side_bears", "side_den" },
		recall = { "side_den" },
		companion = { "side_den" },
	},
}

local CHAPTER_LEVELS = { { 1, 20 }, { 20, 45 }, { 45, 70 }, { 70, 100 } }

local function questOf(id: string): any
	return Quests.Main.get(id) or Quests.npcQuest(id)
end

local function hasKey(key: string): boolean
	return (pl :: any)[key] ~= nil and (en :: any)[key] ~= nil
end

local function has(key: string): boolean
	return hasKey(key)
end

-- character.quests for the tests
local function quests(fields: { [string]: any }?): any
	local out: any = {
		main = nil,
		mainDone = 0,
		daily = { day = 0, list = {}, rerolls = 0 },
		side = { active = {}, done = {} },
		said = {},
	}
	for key, value in fields or {} do
		out[key] = value
	end
	return out
end

-- A side quest of the tests (Wit gives, Ysolde takes, two objectives).
local function fakeSide(choices: any?): any
	return {
		id = "test_side",
		level = 5,
		giver = "fisher_wit",
		turnIn = "alchemist",
		arc = "pond",
		pages = 3,
		requires = { "side_toads" },
		objectives = {
			{ type = "kill", n = 2, monster = "swampToad" },
			{ type = "collect", n = 2, item = "toadVenom", monster = "swampToad", chance = 1 },
		},
		reward = { exp = 1, gold = 1 },
		choices = choices or Talk.onPage(2, { Talk.answer("a"), Talk.answer("b", Talk.focus(2)) }),
		barks = { accept = 1, half = 2, done = 1 },
	}
end

-- The story's healer quest with answers on its single page (or on the hand-in page).
local function fakeMain(choices: any?): any
	local quest: any = table.clone(assert(Quests.Main.get("healer")))
	quest.pages = nil -- S102: healer has offer pages now; the fake is a story quest without them
	quest.choices = choices or Talk.onText({ Talk.answer("yes"), Talk.answer("no") })
	return quest
end

describe("Dialogue: answers (S101b T1)", function()
	it("the data is valid", function()
		expect(Dialogue.validate()).toEqual({})
	end)

	it("canSay on a side quest: offered, active, answered, not offered, wrong NPC, unknown", function()
		local quest = fakeSide()
		local ready = quests({ side = { active = {}, done = { side_toads = true } } })
		expect(Dialogue.canSay(ready, 5, "side", quest, "a", "fisher_wit")).toBe(true)
		local active = quests({
			side = { active = { test_side = { progress = { 1, 0 }, used = {} } }, done = { side_toads = true } },
		})
		expect(Dialogue.canSay(active, 5, "side", quest, "b", "fisher_wit")).toBe(true)
		local said = quests({ side = { active = {}, done = { side_toads = true } }, said = { test_side = "a" } })
		expect(select(2, Dialogue.canSay(said, 5, "side", quest, "b", "fisher_wit"))).toBe("quest.say.already")
		-- level too low, requirement missing, done, wrong NPC
		expect(select(2, Dialogue.canSay(ready, 1, "side", quest, "a", "fisher_wit"))).toBe("quest.say.notOffered")
		expect(select(2, Dialogue.canSay(quests(), 5, "side", quest, "a", "fisher_wit"))).toBe("quest.say.notOffered")
		local done = quests({ side = { active = {}, done = { side_toads = true, test_side = true } } })
		expect(select(2, Dialogue.canSay(done, 5, "side", quest, "a", "fisher_wit"))).toBe("quest.say.notOffered")
		expect(select(2, Dialogue.canSay(ready, 5, "side", quest, "a", "alchemist"))).toBe("quest.say.notOffered")
		expect(select(2, Dialogue.canSay(ready, 5, "side", quest, "zzz", "fisher_wit"))).toBe("quest.say.unknown")
		local bare = fakeSide()
		bare.choices = nil
		expect(select(2, Dialogue.canSay(ready, 5, "side", bare, "a", "fisher_wit"))).toBe("quest.say.unknown")
		-- complete: the offer page is not shown any more
		local complete = quests({
			side = { active = { test_side = { progress = { 2, 2 }, used = {} } }, done = { side_toads = true } },
		})
		expect(select(2, Dialogue.canSay(complete, 5, "side", quest, "a", "fisher_wit"))).toBe("quest.say.notOffered")
	end)

	it("canSay on a hand-in page: only with every objective done, at the turn-in NPC", function()
		local quest = fakeSide(Talk.onDone({ Talk.answer("a"), Talk.answer("b", Talk.gift("potion_hp_1", 1)) }))
		local open = quests({
			side = { active = { test_side = { progress = { 2, 1 }, used = {} } }, done = { side_toads = true } },
		})
		local complete = quests({
			side = { active = { test_side = { progress = { 2, 2 }, used = {} } }, done = { side_toads = true } },
		})
		expect(select(2, Dialogue.canSay(open, 5, "side", quest, "a", "alchemist"))).toBe("quest.say.notOffered")
		expect(select(2, Dialogue.canSay(complete, 5, "side", quest, "a", "fisher_wit"))).toBe("quest.say.notOffered")
		expect(Dialogue.canSay(complete, 5, "side", quest, "a", "alchemist")).toBe(true)
		-- the story: hand-in at the turn-in NPC with the quest complete
		local main = fakeMain(Talk.onDone({ Talk.answer("yes"), Talk.answer("no") }))
		local mainOpen = quests({ main = { id = "healer", progress = { 1, 0 } }, mainDone = 1 })
		local mainDone = quests({ main = { id = "healer", progress = { 1, 1 } }, mainDone = 1 })
		expect(select(2, Dialogue.canSay(mainOpen, 5, "main", main, "yes", "healer"))).toBe("quest.say.notOffered")
		expect(Dialogue.canSay(mainDone, 5, "main", main, "yes", "healer")).toBe(true)
		expect(select(2, Dialogue.canSay(mainDone, 5, "main", main, "yes", "captain"))).toBe("quest.say.notOffered")
	end)

	it("canSay on the story's text page: the next quest at its giver, or in progress at the turn-in NPC", function()
		local quest = fakeMain()
		expect(Dialogue.canSay(quests({ mainDone = 1 }), 1, "main", quest, "yes", "captain")).toBe(true)
		expect(select(2, Dialogue.canSay(quests({ mainDone = 1 }), 1, "main", quest, "yes", "healer"))).toBe(
			"quest.say.notOffered"
		)
		-- not the next story quest (chain)
		expect(select(2, Dialogue.canSay(quests({ mainDone = 0 }), 1, "main", quest, "yes", "captain"))).toBe(
			"quest.say.notOffered"
		)
		local running = quests({ main = { id = "healer", progress = { 1, 0 } }, mainDone = 1 })
		expect(Dialogue.canSay(running, 1, "main", quest, "no", "healer")).toBe(true)
		-- another story quest is active
		local other = quests({ main = { id = "arrival", progress = { 0 } }, mainDone = 1 })
		expect(select(2, Dialogue.canSay(other, 1, "main", quest, "no", "captain"))).toBe("quest.say.notOffered")
		-- the level does not allow the next quest yet
		local later = fakeMain()
		later.id = "wolfFangs"
		later.level = 4
		later.giver = "scout_meadows"
		expect(select(2, Dialogue.canSay(quests({ mainDone = 7 }), 1, "main", later, "yes", "scout_meadows"))).toBe(
			"quest.say.notOffered"
		)
		expect(Dialogue.canSay(quests({ mainDone = 7 }), 4, "main", later, "yes", "scout_meadows")).toBe(true)
	end)

	it("pageOf for every mode of both kinds", function()
		local side = fakeSide()
		local main = fakeMain()
		expect(Dialogue.pageOf(side, "side", "offer", 2)).toBe("p2")
		expect(Dialogue.pageOf(side, "side", "active", 1)).toBe("progress")
		expect(Dialogue.pageOf(side, "side", "turnIn", 1)).toBe("done")
		expect(Dialogue.pageOf(main, "main", "offer", 1)).toBe("text")
		expect(Dialogue.pageOf(main, "main", "active", 1)).toBe("text")
		expect(Dialogue.pageOf(main, "main", "turnIn", 1)).toBe("done")
		-- S102: a story quest with pages
		local paged = fakeMain()
		paged.pages = 3
		expect(Dialogue.pageOf(paged, "main", "offer", 3)).toBe("p3")
		expect(Dialogue.pageName(2)).toBe("p2")
		expect(Dialogue.pageName("done")).toBe("done")
	end)

	it("pageKey picks the variant of an earlier answer when the text exists", function()
		local quest = fakeSide()
		quest.recall = { p1 = "side_bears", done = "test_side" }
		local q = quests({ said = { side_bears = "quiet", test_side = "b" } })
		local known = { ["quest.test_side.p1.quiet"] = true }
		local function lookup(key: string): boolean
			return known[key] == true
		end
		expect(Dialogue.pageKey(quest, "p1", q, lookup)).toBe("quest.test_side.p1.quiet")
		expect(Dialogue.pageKey(quest, "done", q, lookup)).toBe("quest.test_side.done")
		expect(Dialogue.pageKey(quest, "p2", q, lookup)).toBe("quest.test_side.p2")
		expect(Dialogue.pageKey(quest, "p1", quests(), lookup)).toBe("quest.test_side.p1")
		-- a broken `said` is ignored
		expect(Dialogue.pageKey(quest, "p1", quests({ said = 5 }), lookup)).toBe("quest.test_side.p1")
		expect(Dialogue.saidOf({ said = { x = 3 } }, "x")).toBeNil()
		expect(Dialogue.saidOf(nil, "x")).toBeNil()
	end)

	it("focusOf and hintOf read the saved answer", function()
		local quest = fakeSide(Talk.onPage(1, {
			Talk.answer("a", Talk.focus(2)),
			Talk.answer("b", Talk.hint("meadows", 1, 2, "area.meadows_toadmire")),
		}))
		expect(Dialogue.focusOf(quest, quests({ said = { test_side = "a" } }))).toBe(2)
		expect(Dialogue.hintOf(quest, quests({ said = { test_side = "a" } }))).toBeNil()
		local hint: any = Dialogue.hintOf(quest, quests({ said = { test_side = "b" } }))
		expect(hint.x).toBe(1)
		expect(hint.map).toBe("meadows")
		expect(Dialogue.focusOf(quest, quests())).toBeNil()
	end)

	it("the validator catches broken pages", function()
		local function problems(quest: any, kind: any): number
			return #Dialogue.validate({ { kind = kind, quest = quest } })
		end
		expect(problems(fakeSide(), "side")).toBe(0)
		expect(problems(fakeMain(), "main")).toBe(0)
		expect(problems(fakeSide(Talk.onPage(1, { Talk.answer("a") })), "side")).toBe(1)
		local four = { Talk.answer("a"), Talk.answer("b"), Talk.answer("c"), Talk.answer("d") }
		expect(problems(fakeSide(Talk.onPage(1, four)), "side")).toBe(1)
		expect(problems(fakeSide(Talk.onPage(1, { Talk.answer("a"), Talk.answer("a") })), "side")).toBe(1)
		expect(problems(fakeSide(Talk.onPage(1, { Talk.answer("a b"), Talk.answer("c") })), "side")).toBe(1)
		expect(problems(fakeSide(Talk.onPage(4, { Talk.answer("a"), Talk.answer("b") })), "side")).toBe(1)
		expect(problems(fakeSide(Talk.onText({ Talk.answer("a"), Talk.answer("b") })), "side")).toBe(1)
		local paged = fakeMain()
		paged.pages = 2
		expect(problems(paged, "main")).toBe(1)
		local hintDone =
			Talk.onDone({ Talk.answer("a", Talk.hint("meadows", 0, 0, "area.meadows_toadmire")), Talk.answer("b") })
		expect(problems(fakeSide(hintDone), "side")).toBe(1)
		local twoItems = Talk.onPage(1, {
			Talk.answer("a", Talk.gift("potion_hp_1", 1)),
			Talk.answer("b", Talk.gift("potion_mana_1", 1)),
		})
		expect(problems(fakeSide(twoItems), "side")).toBe(1)
		local notGift = Talk.onPage(1, { Talk.answer("a", Talk.gift("backpack_30", 1)), Talk.answer("b") })
		expect(problems(fakeSide(notGift), "side")).toBe(1)
		local tooMany = Talk.onPage(1, { Talk.answer("a", Talk.gift("potion_hp_1", 99)), Talk.answer("b") })
		expect(problems(fakeSide(tooMany), "side")).toBe(1)
		local badHint =
			Talk.onPage(1, { Talk.answer("a", Talk.hint("nowhere", 0, 0, "no.such.key")), Talk.answer("b") })
		expect(problems(fakeSide(badHint), "side")).toBe(2)
		expect(problems(fakeSide(Talk.onPage(1, { Talk.answer("a", Talk.focus(3)), Talk.answer("b") })), "side")).toBe(
			1
		)
		-- recall from a later quest, from a quest without answers, on a page that does not exist
		local laterRecall = fakeSide()
		laterRecall.recall = { p1 = "side_den" }
		expect(problems(laterRecall, "side")).toBe(1)
		local noChoices = fakeSide()
		noChoices.recall = { p1 = "side_toads" }
		expect(problems(noChoices, "side")).toBe(1)
		local badPage = fakeSide()
		badPage.requires = { "side_bears" }
		badPage.recall = { p9 = "side_bears", text = "side_bears" }
		expect(problems(badPage, "side")).toBe(2)
		local earlierRecall = fakeSide()
		earlierRecall.requires = { "side_bears" }
		earlierRecall.recall = { p1 = "side_bears", progress = "side_bears" }
		expect(problems(earlierRecall, "side")).toBe(0)
		local unknown = fakeSide()
		unknown.recall = { p1 = "no_such_quest" }
		expect(problems(unknown, "side")).toBe(1)
	end)

	it("every gift is a small consumable that exists", function()
		for id, n in Config.Dialogue.gifts do
			expect(string.match(id, "^potion_") ~= nil).toBe(true)
			expect(n >= 1 and n <= 5).toBe(true)
		end
	end)
end)

-- Comments ---------------------------------------------------------------------------------------------------------

local function sideState(active: { [string]: any }): any
	return quests({ side = { active = active, done = {} } })
end

describe("Barks: comments (S101b T2)", function()
	it("the data is valid", function()
		expect(Barks.validate()).toEqual({})
	end)

	it("events: accept, half, done, half and done at once, gone, without barks", function()
		local before = sideState({})
		local accepted = sideState({ side_bears = { progress = { 0, 0 }, used = {} } })
		expect(Barks.events(before, accepted)).toEqual({ { quest = "side_bears", kind = "side", event = "accept" } })
		local almost = sideState({ side_bears = { progress = { 6, 0 }, used = {} } })
		local half = sideState({ side_bears = { progress = { 7, 0 }, used = {} } })
		expect(Barks.events(accepted, almost)).toEqual({})
		expect(Barks.events(almost, half)).toEqual({ { quest = "side_bears", kind = "side", event = "half" } })
		expect(Barks.events(half, half)).toEqual({})
		local full = sideState({ side_bears = { progress = { 10, 4 }, used = {} } })
		expect(Barks.events(half, full)).toEqual({ { quest = "side_bears", kind = "side", event = "done" } })
		expect(Barks.events(accepted, full)).toEqual({ { quest = "side_bears", kind = "side", event = "done" } })
		expect(Barks.events(full, sideState({}))).toEqual({})
		-- the S98 boss quests have no comments
		expect(Barks.events(before, sideState({ boss_grimrok = { progress = { 0 }, used = {} } }))).toEqual({})
		-- the story first; a story quest that appears complete says done
		local main = quests({ main = { id = "arrival", progress = { 1 } }, side = accepted.side })
		expect(Barks.events(before, main)).toEqual({
			{ quest = "arrival", kind = "main", event = "done" },
			{ quest = "side_bears", kind = "side", event = "accept" },
		})
		-- missing tables are tolerated
		expect(Barks.events(nil, nil)).toEqual({})
	end)

	it("the limiter keeps the pace", function()
		local c = Config.Barks
		local l = Barks.newLimiter()
		expect(Barks.allow(l, "a", "accept", 0)).toBe(true)
		expect(Barks.allow(l, "b", "accept", c.gap - 1)).toBe(false)
		expect(Barks.allow(l, "b", "accept", c.gap)).toBe(true)
		expect(Barks.allow(l, "a", "accept", c.gap * 2)).toBe(c.gap * 2 >= c.sameEvent)
		local m = Barks.newLimiter()
		local t = 0
		local said = 0
		for i = 1, 10 do
			if Barks.allow(m, `q{i}`, "half", t) then
				said += 1
			end
			t += 1
		end
		expect(said).toBe(1)
		local stuck = Barks.newLimiter()
		expect(Barks.allow(stuck, "q", "stuck", 0)).toBe(true)
		expect(Barks.allow(stuck, "q", "stuck", c.stuckRepeat - 1)).toBe(false)
		expect(Barks.allow(stuck, "q", "stuck", c.stuckRepeat)).toBe(true)
		local death = Barks.newLimiter()
		expect(Barks.allow(death, "q", "death", 0)).toBe(true)
		expect(Barks.allow(death, "q", "death", c.deathRepeat - 1)).toBe(false)
		expect(Barks.allow(death, "q", "death", c.deathRepeat)).toBe(true)
		local same = Barks.newLimiter()
		expect(Barks.allow(same, "q", "half", 0)).toBe(true)
		expect(Barks.allow(same, "q", "half", c.sameEvent - 1)).toBe(false)
		expect(Barks.allow(same, "q", "half", c.sameEvent)).toBe(true)
	end)

	it("perMinute caps a window of 60 seconds", function()
		local c = Config.Barks
		local l = Barks.newLimiter()
		l.recent = {}
		for i = 1, c.perMinute do
			table.insert(l.recent, 100 + i)
		end
		l.last = 100
		expect(Barks.allow(l, "x", "half", 100 + c.gap)).toBe(false)
		expect(Barks.allow(l, "x", "half", 100 + c.perMinute + 60)).toBe(true)
	end)

	it("isStuck counts only outside town", function()
		local after = Config.Barks.stuckAfter
		expect(Barks.isStuck(0, after, false)).toBe(true)
		expect(Barks.isStuck(0, after - 1, false)).toBe(false)
		expect(Barks.isStuck(0, after * 3, true)).toBe(false)
	end)

	it("nearHit on the same map only", function()
		local target = { map = "meadows", x = 100, z = 100 }
		expect(Barks.nearHit(target, { x = 110, z = 100 }, "meadows", 35)).toBe(true)
		expect(Barks.nearHit(target, { x = 110, z = 100 }, "city", 35)).toBe(false)
		expect(Barks.nearHit(target, { x = 200, z = 100 }, "meadows", 35)).toBe(false)
		expect(Barks.nearHit({ map = "meadows" }, { x = 0, z = 0 }, "meadows", 35)).toBe(false)
	end)

	it("pick is deterministic and in range", function()
		local quest = fakeSide()
		expect(Barks.pick(quest, "half", 0)).toBe("quest.test_side.bark.half1")
		expect(Barks.pick(quest, "half", 1)).toBe("quest.test_side.bark.half2")
		expect(Barks.pick(quest, "half", 2)).toBe("quest.test_side.bark.half1")
		expect(Barks.pick(quest, "half", -3)).toBe("quest.test_side.bark.half2")
		expect(Barks.pick(quest, "accept", 7)).toBe("quest.test_side.bark.accept1")
		expect(Barks.pick(quest, "near", 7)).toBeNil()
		local den = assert(Quests.Side.get("side_den"))
		expect(Barks.pickComp(den, "join", 3)).toBe("quest.side_den.comp.join2")
		expect(Barks.pickComp(den, "arrive", 3)).toBeNil()
	end)

	it("speaker: by, companion, turn-in NPC for done, giver", function()
		local quest = fakeSide()
		expect(Barks.speaker(quest, "accept", nil)).toBe("fisher_wit")
		expect(Barks.speaker(quest, "done", nil)).toBe("alchemist")
		expect(Barks.speaker(quest, "half", "hunter_borys")).toBe("hunter_borys")
		quest.barks = { by = "fishwife", accept = 1 }
		expect(Barks.speaker(quest, "done", "hunter_borys")).toBe("fishwife")
	end)

	it("required: half only with two objective units or more", function()
		expect(Barks.required(assert(Quests.Main.get("arrival")))).toEqual({ "accept", "done" })
		expect(Barks.required(assert(Quests.Main.get("healer")))).toEqual({ "accept", "half", "done" })
		expect(Barks.required(assert(Quests.Side.get("side_den")))).toEqual({ "accept", "half", "done" })
	end)

	it("the validator catches dead and unknown comments", function()
		local function problems(quest: any): number
			return #Barks.validate({ quest })
		end
		local arrival: any = table.clone(assert(Quests.Main.get("arrival")))
		arrival.barks = { accept = 1, half = 1, done = 1 }
		expect(problems(arrival)).toBe(1)
		arrival.barks = { accept = 1, near = 1 }
		expect(problems(arrival)).toBe(0) -- talk points at the captain
		local toads: any = table.clone(assert(Quests.Side.get("side_rabbits")))
		toads.barks = { accept = 5, grumble = 1, by = "nobody" }
		expect(problems(toads)).toBe(3)
		local venom: any = table.clone(assert(Quests.Side.get("side_venom")))
		venom.barks = { near = 1 }
		expect(problems(venom)).toBe(1) -- collect without an area and no `where`
	end)
end)

-- Texts --------------------------------------------------------------------------------------------------------------

local MAX = { bark = 90, comp = 90, say = 60, reply = 140, page = 220 }
local BANNED_TEXT = { "—", "!!", ":)", ":(", "xD", "XD" }
local BANNED_WORDS =
	{ "%f[%a]quests?%f[%A]", "%f[%a]level", "%f[%a]poziom", "%f[%a]exp%f[%A]", "%f[%a]klik", "%f[%a]lol%f[%A]" }

local function textProblems(key: string, kind: string, problems: { string })
	for lang, tbl in { pl = pl :: any, en = en :: any } do
		local text = tbl[key]
		if type(text) ~= "string" then
			table.insert(problems, `{lang} {key}: missing`)
			continue
		end
		local length = utf8.len(text) or #text
		if length > MAX[kind] then
			table.insert(problems, `{lang} {key}: {length} > {MAX[kind]}`)
		end
		if kind ~= "page" then
			for _, banned in BANNED_TEXT do
				if string.find(text, banned, 1, true) then
					table.insert(problems, `{lang} {key}: "{banned}"`)
				end
			end
			local lower = string.lower(text)
			for _, pattern in BANNED_WORDS do
				if string.find(lower, pattern) then
					table.insert(problems, `{lang} {key}: {pattern}`)
				end
			end
		end
	end
end

describe("Dialogue texts (S101b T3)", function()
	it("answers, replies, page variants, comments and companion lines exist in both languages", function()
		local problems: { string } = {}
		for _, item in Dialogue.allQuests() do
			local quest = item.quest
			local page = quest.choices
			if page then
				for _, option in page.options do
					textProblems(`quest.{quest.id}.say.{option.id}`, "say", problems)
					textProblems(`quest.{quest.id}.say.{option.id}.reply`, "reply", problems)
				end
			end
			if quest.recall then
				for pageKey, sourceId in quest.recall do
					local source = questOf(sourceId)
					for _, option in (if source and source.choices then source.choices.options else {}) :: { any } do
						local key = `quest.{quest.id}.{pageKey}.{option.id}`
						if (pl :: any)[key] ~= nil or (en :: any)[key] ~= nil then
							textProblems(key, "page", problems)
						end
					end
				end
			end
			for _, event in Barks.EVENTS do
				for n = 1, Barks.count(quest, event) do
					textProblems(`quest.{quest.id}.bark.{event}{n}`, "bark", problems)
				end
			end
			for _, event in Barks.COMPANION_EVENTS do
				for n = 1, Barks.compCount(quest, event) do
					textProblems(`quest.{quest.id}.comp.{event}{n}`, "comp", problems)
				end
			end
		end
		expect(problems).toEqual({})
	end)

	it("the general texts exist", function()
		for _, key in
			{
				"quest.say.unknown",
				"quest.say.already",
				"quest.say.notOffered",
				"quest.say.pick",
				"quest.say.later",
				"menu.barks",
				"companion.tag",
				"companion.waiting",
				"companion.back",
				"quest.obj.escort",
				"admin.companion.info",
				"admin.companion.none",
				"admin.companion.reset",
				"admin.usage.companion",
			}
		do
			expect(hasKey(key)).toBe(true)
		end
	end)
end)

-- Content minimums -----------------------------------------------------------------------------------------------------

local function missingEvents(quest: any): { string }
	local out = {}
	for _, event in Barks.required(quest) do
		if Barks.count(quest, event) < 1 then
			table.insert(out, event)
		end
	end
	return out
end

describe("Dialogue content minimums (S101b T4, DESIGN-15 §3.5)", function()
	it("every new quest has a page with answers and the required comments", function()
		for session, ids in NEW_QUESTS do
			for _, id in ids do
				local quest = questOf(id)
				expect(`{session} {id} {quest ~= nil}`).toBe(`{session} {id} true`)
				if quest then
					local page = Dialogue.choicePage(quest)
					local options = if page then #page.options else 0
					expect(`{id} {options >= 2 and options <= 3}`).toBe(`{id} true`)
					expect(`{id}: {table.concat(missingEvents(quest), ",")}`).toBe(`{id}: `)
				end
			end
		end
	end)

	it("every chapter and region of a session has two quests with a companion", function()
		for session, groups in COMPANION_GROUPS do
			for _, group in groups do
				local count = 0
				for _, id in NEW_QUESTS[session] or {} do
					local quest = questOf(id)
					local def = quest and quest.companion
					if def then
						local inGroup = false
						if group.chapter then
							local band = CHAPTER_LEVELS[group.chapter]
							inGroup = Quests.Main.get(id) ~= nil
								and band ~= nil
								and quest.level >= band[1]
								and quest.level <= band[2]
						elseif group.map then
							inGroup = def.map == group.map
						end
						if inGroup then
							count += 1
						end
					end
				end
				local name = group.map or `chapter {group.chapter}`
				expect(`{session} {name}: {count >= 2}`).toBe(`{session} {name}: true`)
			end
		end
	end)

	it("every quest with comments only has the required events", function()
		local seen = 0
		for _, ids in BARKS_ONLY do
			for _, id in ids do
				local quest = questOf(id)
				expect(`{id} {quest ~= nil}`).toBe(`{id} true`)
				if quest then
					seen += 1
					expect(`{id}: {table.concat(missingEvents(quest), ",")}`).toBe(`{id}: `)
				end
			end
		end
		expect(#BARKS_ONLY.S101b).toBe(15 + 28 + 3)
		expect(seen >= 46).toBe(true)
	end)

	it("S101b retrofit: answers, a page variant and a companion; every effect kind is in the data", function()
		for _, id in RETROFIT.S101b.choices do
			expect(Dialogue.choicePage(questOf(id)) ~= nil).toBe(true)
		end
		for _, id in RETROFIT.S101b.recall do
			expect(questOf(id).recall ~= nil).toBe(true)
		end
		for _, id in RETROFIT.S101b.companion do
			expect(questOf(id).companion ~= nil).toBe(true)
		end
		local function kinds(id: string): { [string]: boolean }
			local out = {}
			for _, option in (Dialogue.choicePage(questOf(id)) :: any).options do
				if option.effect then
					out[option.effect.kind] = true
				end
			end
			return out
		end
		expect(kinds("side_venom").hint).toBe(true)
		expect(kinds("side_bears").item).toBe(true)
		expect(kinds("side_den").focus).toBe(true)
	end)
end)

-- The Meadows content ---------------------------------------------------------------------------------------------

describe("Dialogue on the Meadows (S101b T5)", function()
	it("side_den's first page answers what was said in side_bears", function()
		local den = assert(Quests.Side.get("side_den"))
		local function page(answer: string?): string
			return Dialogue.pageKey(den, "p1", quests({ said = { side_bears = answer } }), has)
		end
		expect(page("quiet")).toBe("quest.side_den.p1.quiet")
		expect(page("fire")).toBe("quest.side_den.p1.fire")
		expect(page("supplies")).toBe("quest.side_den.p1")
		expect(page(nil)).toBe("quest.side_den.p1")
	end)

	it("Wit's hint points into Toad Pond's marsh", function()
		local venom = assert(Quests.Side.get("side_venom"))
		local hint: any = Dialogue.hintOf(venom, quests({ said = { side_venom = "where" } }))
		expect(hint ~= nil).toBe(true)
		expect(hint.map).toBe("meadows")
		local Areas = require("../src/shared/Data/Areas")
		local area = assert(Areas.areaById("meadows_toadmire"))
		local r = area.rect :: { number }
		expect(hint.x >= r[1] and hint.x <= r[3] and hint.z >= r[2] and hint.z <= r[4]).toBe(true)
	end)

	it("Borys takes an answer about the bears while the quest runs, not after", function()
		local bears = assert(Quests.Side.get("side_bears"))
		local running = quests({
			side = { active = { side_bears = { progress = { 0, 0 }, used = {} } }, done = { side_hunter = true } },
		})
		expect(Dialogue.canSay(running, 17, "side", bears, "quiet", "hunter_borys")).toBe(true)
		local handedIn = quests({ side = { active = {}, done = { side_hunter = true, side_bears = true } } })
		expect(select(2, Dialogue.canSay(handedIn, 17, "side", bears, "quiet", "hunter_borys"))).toBe(
			"quest.say.notOffered"
		)
		-- the gift is the only item answer and fits Config.Dialogue.gifts
		local option: any = Dialogue.option(bears, "supplies")
		expect(option.effect.id).toBe("potion_hp_1")
		expect(option.effect.n <= Config.Dialogue.gifts.potion_hp_1).toBe(true)
	end)
end)

describe("Dialogue in story chapter I (S102 T11)", function()
	local Locale = require("../src/shared/Util/Locale")
	local function has(key: string): boolean
		return Locale.has(key, "pl") and Locale.has(key, "en")
	end

	it("recall picks the variants of frostSign.done and warCouncil.p1", function()
		local frostSign = assert(Quests.Main.get("frostSign"))
		local warCouncil = assert(Quests.Main.get("warCouncil"))
		expect(Dialogue.pageKey(frostSign, "done", quests({ said = { frostSign = "chance" } }), has)).toBe(
			"quest.frostSign.done.chance"
		)
		expect(Dialogue.pageKey(frostSign, "done", quests({ said = { frostSign = "same" } }), has)).toBe(
			"quest.frostSign.done"
		)
		for _, choice in { "jewelry", "ready" } do
			expect(Dialogue.pageKey(warCouncil, "p1", quests({ said = { warrenCharms = choice } }), has)).toBe(
				`quest.warCouncil.p1.{choice}`
			)
		end
		expect(Dialogue.pageKey(warCouncil, "p1", quests({ said = { warrenCharms = "count" } }), has)).toBe(
			"quest.warCouncil.p1"
		)
	end)

	it("answers stand on a page number of story quests with pages", function()
		for _, id in { "frostRuins", "frostSign", "warrenCharms", "warCouncil" } do
			local quest = assert(Quests.Main.get(id))
			local page = assert(Dialogue.choicePage(quest), id)
			expect(type(page.page)).toBe("number")
			expect((page.page :: number) <= (quest.pages or 0)).toBe(true)
		end
		-- Mirela offers frostRuins (page 3) right after herbs
		local frostRuins = assert(Quests.Main.get("frostRuins"))
		local ready = quests({ mainDone = Quests.Main.indexOf.herbs })
		expect(Dialogue.canSay(ready, frostRuins.level, "main", frostRuins, "go", "healer")).toBe(true)
		expect(Dialogue.canSay(ready, frostRuins.level, "main", frostRuins, "go", "captain")).toBe(false)
	end)
end)
