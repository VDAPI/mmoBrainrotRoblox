--!strict
-- S102 (docs/FABULA.md §2): story progress that survives inserted quests (Logic/StoryProgress, migration 8), the
-- chain of story NPCs, chapters, offer pages, cutscene data and rules (Logic/Cutscenes), cave quest anchors,
-- regionfolk and the one EXP rule of the story (Data/Quests/Main settleStory). Written to survive S103-S105: every
-- expectation goes through Main.indexOf, and the story sessions only add their ids to EXPECTED_INSERTS.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Areas = require("../src/shared/Data/Areas")
local Config = require("../src/shared/Config")
local CutsceneData = require("../src/shared/Data/Cutscenes")
local Cutscenes = require("../src/shared/Logic/Cutscenes")
local Exp = require("../src/shared/Logic/Exp")
local Locale = require("../src/shared/Util/Locale")
local Npcs = require("../src/shared/Data/Npcs")
local QuestBudget = require("../src/shared/Logic/QuestBudget")
local QuestBudgetData = require("../src/shared/Data/QuestBudget")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Rng = require("../src/shared/Logic/Rng")
local Side = require("../src/shared/Data/Quests/Side")
local SideQuests = require("../src/shared/Logic/SideQuests")
local StoryProgress = require("../src/shared/Logic/StoryProgress")
local Test = require("./Test")
local Titles = require("../src/shared/Logic/Titles")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Main = Quests.Main
local indexOf = Main.indexOf

-- Story quests inserted after S101b, per session in Main.list order (S103-S105 add theirs).
local EXPECTED_INSERTS: { [string]: { string } } = {
	S102 = { "frostRuins", "frostSign", "warrenCharms", "warCouncil" },
	S103 = {
		"moonstone",
		"lostHunters",
		"houseOfVael",
		"elderHeart",
		"turncoat",
		"barrow",
		"witchCounsel",
		"cryptGate",
		"queensLegacy",
	},
}

-- Rewards of the quests that keep fixed EXP (the old 1-19, toDuskwood and the boss quests), as before S102.
local FIXED_EXP: { [string]: number } = {
	arrival = 30,
	healer = 40,
	smith = 50,
	portal = 40,
	firstHunt = 125,
	gearUp = 83,
	wolves = 76,
	wolfFangs = 617,
	boars = 505,
	herbs = 2593,
	banditRoad = 2848,
	banditOrders = 3961,
	goblinCamp = 5229,
	mosshollow = 14858,
	grimrok = 9534,
	toDuskwood = 7150,
	morvane = 66499,
	azgor = 153861,
	vaelgrath = 371503,
}

-- Quests whose gold is not gold(level) (S103-S105 add their x2 / x3 rewards here).
local GOLD_EXCEPTIONS: { [string]: boolean } = {
	queensLegacy = true, -- S103: gold(44) x 2 (the end of chapter II)
}

local function has(key: string): boolean
	return Locale.has(key, "pl") and Locale.has(key, "en")
end

local function hasBoss(quest: Quests.MainQuest): boolean
	for _, objective in quest.objectives do
		if objective.type == "boss" then
			return true
		end
	end
	return false
end

local function quests(fields: { [string]: any }?): any
	local out: any = {
		main = nil,
		mainDone = 0,
		daily = { day = 0, list = {}, rerolls = 0 },
		side = { active = {}, done = {} },
		said = {},
		scenes = {},
	}
	for key, value in fields or {} do
		out[key] = value
	end
	return out
end

-- A fresh copy of `quests` after StoryProgress.apply.
local function applied(fields: { [string]: any }): any
	local q = quests(fields)
	StoryProgress.apply(q)
	return q
end

describe("Story progress: LEGACY_ORDER (S102 T1)", function()
	it("has the 32 old quests, every one still in Main.list, and the old order never changes", function()
		local legacy = StoryProgress.LEGACY_ORDER
		expect(#legacy).toBe(32)
		local seen: { [string]: boolean } = {}
		for _, id in legacy do
			expect(seen[id]).toBeNil()
			seen[id] = true
			expect(`{id} {indexOf[id] ~= nil}`).toBe(`{id} true`)
		end
		local old: { string } = {}
		local inserted = StoryProgress.inserted()
		for _, quest in Main.list do
			if not table.find(inserted, quest.id) then
				table.insert(old, quest.id)
			end
		end
		expect(old).toEqual(table.clone(legacy) :: any)
	end)

	it("the inserted quests are exactly EXPECTED_INSERTS, in list order", function()
		local expected: { string } = {}
		for _, ids in EXPECTED_INSERTS do
			for _, id in ids do
				table.insert(expected, id)
			end
		end
		table.sort(expected, function(a, b)
			return (indexOf[a] or 0) < (indexOf[b] or 0)
		end)
		expect(StoryProgress.inserted()).toEqual(expected)
	end)

	it("maps an old mainDone to the last quest handed in", function()
		expect(StoryProgress.legacyId(0)).toBeNil()
		expect(StoryProgress.legacyId(1)).toBe("arrival")
		expect(StoryProgress.legacyId(11)).toBe("banditRoad")
		expect(StoryProgress.legacyId(32)).toBe("vaelgrath")
		expect(StoryProgress.legacyId(99)).toBe("vaelgrath")
		expect(StoryProgress.legacyId("x")).toBeNil()
		expect(StoryProgress.legacyId(-3)).toBeNil()
	end)
end)

describe("Story progress: sync and apply (S102 T2)", function()
	it("(a) a new character: 0, nil", function()
		local done, last = StoryProgress.sync(quests())
		expect(done).toBe(0)
		expect(last).toBeNil()
	end)

	it("(b) mainLast herbs: the next quest is frostRuins", function()
		local q = applied({ mainLast = "herbs", mainDone = 10 })
		expect(q.mainDone).toBe(indexOf.herbs)
		expect(q.mainLast).toBe("herbs")
		expect((QuestLogic.nextMain(q.mainDone, 20))).toBe(Main.get("frostRuins"))
	end)

	it("(c) the old mainDone 11 (banditRoad): frostRuins counts as handed in", function()
		local q = applied({ mainLast = StoryProgress.legacyId(11), mainDone = 11 })
		expect(q.mainDone).toBe(indexOf.banditRoad)
		expect(q.mainDone >= indexOf.frostRuins).toBe(true)
		expect(StoryProgress.isDone(q, "frostRuins")).toBe(true)
	end)

	it("(d) an active goblinCamp keeps its place, the quests inserted before it count as done", function()
		local q = applied({ mainDone = 12, main = { id = "goblinCamp", progress = { 3 } } })
		expect(q.mainDone).toBe(indexOf.goblinCamp - 1)
		expect(q.mainLast).toBe(Main.list[indexOf.goblinCamp - 1].id)
		expect(q.main.id).toBe("goblinCamp")
		expect(q.main.progress).toEqual({ 3 })
		expect(StoryProgress.isDone(q, "frostSign")).toBe(true)
	end)

	it("(e) the old 15 (grimrok): the next quest is warCouncil", function()
		local q = applied({ mainLast = StoryProgress.legacyId(15), mainDone = 15 })
		expect(q.mainDone).toBe(indexOf.grimrok)
		expect((QuestLogic.nextMain(q.mainDone, 20))).toBe(Main.get("warCouncil"))
	end)

	it("(f) the old 16 (toDuskwood): warCouncil counts as handed in", function()
		local q = applied({ mainLast = StoryProgress.legacyId(16), mainDone = 16 })
		expect(q.mainDone).toBe(indexOf.toDuskwood)
		expect(StoryProgress.isDone(q, "warCouncil")).toBe(true)
	end)

	it("(g) the old 32: the whole story, vaelgrath last", function()
		local q = applied({ mainLast = StoryProgress.legacyId(32), mainDone = 32 })
		expect(q.mainDone).toBe(indexOf.vaelgrath)
		expect(q.mainLast).toBe("vaelgrath")
		expect((QuestLogic.nextMain(q.mainDone, 100))).toBe(Main.list[indexOf.vaelgrath + 1])
	end)

	it("(h) garbage without an anchor: clamped", function()
		expect(applied({ mainDone = "x" }).mainDone).toBe(0)
		expect(applied({ mainDone = -3 }).mainDone).toBe(0)
		expect(applied({ mainDone = 99 }).mainDone).toBe(#Main.list)
		expect(applied({ mainDone = 2.7 }).mainDone).toBe(2)
	end)

	it("(i) an active quest with an unknown id is dropped and the anchor counts", function()
		local q = applied({ mainLast = "herbs", main = { id = "gone", progress = {} } })
		expect(q.main).toBeNil()
		expect(q.mainDone).toBe(indexOf.herbs)
		local broken = applied({ mainLast = "herbs", main = "oops" })
		expect(broken.main).toBeNil()
		expect(broken.mainDone).toBe(indexOf.herbs)
	end)

	it("(j) apply is idempotent", function()
		for _, fields in
			{
				{ mainLast = "herbs" },
				{ mainDone = 12, main = { id = "goblinCamp", progress = { 0 } } },
				{ mainDone = 99 },
				{ mainLast = "nope", mainDone = 3 },
			}
		do
			local q = applied(fields)
			local done, last, main = q.mainDone, q.mainLast, q.main
			StoryProgress.apply(q)
			expect(q.mainDone).toBe(done)
			expect(q.mainLast).toBe(last)
			expect(q.main).toBe(main)
		end
	end)

	it("a future insertion before the player's place needs no migration", function()
		-- S103-S105 insert quests: simulated on a list with a quest before werewolves and one before ruins
		local list: { { id: string } } = {}
		for _, quest in Main.list do
			if quest.id == "werewolves" then
				table.insert(list, { id = "testMoonstone" })
			elseif quest.id == "ruins" then
				table.insert(list, { id = "testLostHunters" })
			end
			table.insert(list, { id = quest.id })
		end
		local index: { [string]: number } = {}
		for i, entry in list do
			index[entry.id] = i
		end
		local after = quests({ mainLast = "toDuskwood", mainDone = indexOf.toDuskwood })
		StoryProgress.apply(after, list)
		expect(list[after.mainDone + 1].id).toBe("testMoonstone")
		local active = quests({ mainDone = 3, main = { id = "ruins", progress = {} } })
		StoryProgress.apply(active, list)
		expect(active.mainDone).toBe(index.ruins - 1)
		expect(active.mainDone >= index.testMoonstone and active.mainDone >= index.testLostHunters).toBe(true)
		-- the real insertions in list order, the two test quests where they stand
		local expected: { string } = {}
		for _, entry in list do
			if
				entry.id == "testMoonstone"
				or entry.id == "testLostHunters"
				or table.find(StoryProgress.inserted(), entry.id)
			then
				table.insert(expected, entry.id)
			end
		end
		expect(StoryProgress.inserted(list)).toEqual(expected)
		expect(table.find(expected, "testMoonstone") ~= nil and table.find(expected, "frostRuins") == 1).toBe(true)
	end)
end)

describe("Story progress: migration 8 (S102 T3)", function()
	local function character(id: string, fields: { [string]: any }): any
		local c: any = AccountSchema.characterTemplate()
		c.id = id
		c.name = id
		c.level = 30
		c.quests.scenes = nil
		c.quests.said = nil
		for key, value in fields do
			c.quests[key] = value
		end
		return c
	end

	local function account(): any
		local data: any = AccountSchema.accountTemplate()
		data.schema = 7
		data.characters = {
			c = character("c", { mainDone = 11 }),
			d = character("d", { mainDone = 12, main = { id = "goblinCamp", progress = { 2 }, used = 5 } }),
			e = character("e", { mainDone = 15, scenes = "oops" }),
			g = character("g", { mainDone = 32 }),
			s = "not a character",
			q = { id = "q", name = "q", class = "Mage", level = 3, quests = "broken" },
		}
		return data
	end

	it("recounts every character in the new list, fixes broken branches and is idempotent", function()
		local data = account()
		local applied8 = AccountSchema.migrate(data)
		expect(applied8).toEqual({ 8 })
		expect(data.schema).toBe(8)
		local chars = data.characters
		expect(chars.c.quests.mainLast).toBe("banditRoad")
		expect(chars.c.quests.mainDone).toBe(indexOf.banditRoad)
		expect(chars.d.quests.mainDone).toBe(indexOf.goblinCamp - 1)
		expect(chars.d.quests.main.id).toBe("goblinCamp")
		expect(chars.d.quests.main.used).toBeNil()
		expect(chars.e.quests.mainDone).toBe(indexOf.grimrok)
		expect(chars.e.quests.scenes).toEqual({})
		expect(chars.g.quests.mainDone).toBe(indexOf.vaelgrath)
		expect(chars.c.quests.said).toEqual({})
		expect(chars.s).toBe("not a character")
		expect(chars.q.quests).toBe("broken")
		-- the dragon slayers keep their title
		expect(Titles.isUnlocked(chars.g, "dragonbane")).toBe(true)
		expect(Titles.isUnlocked(chars.e, "dragonbane")).toBe(false)
		-- a second load changes nothing
		local before = {
			c = table.clone(chars.c.quests),
			d = table.clone(chars.d.quests),
			g = table.clone(chars.g.quests),
		}
		expect(AccountSchema.migrate(data)).toEqual({})
		for id, q in before do
			expect(chars[id].quests.mainDone).toBe(q.mainDone)
			expect(chars[id].quests.mainLast).toBe(q.mainLast)
		end
	end)

	it("a schema 1 account runs every migration", function()
		local data: any = {
			schema = 1,
			characters = {
				["1"] = { id = "a", name = "Old", class = "Warrior", level = 12, quests = { mainDone = 13 } },
			},
		}
		local list = AccountSchema.migrate(data)
		expect(list[#list]).toBe(8)
		expect(data.schema).toBe(AccountSchema.CURRENT)
		local q = data.characters["1"].quests
		expect(q.mainLast).toBe("goblinCamp")
		expect(q.mainDone).toBe(indexOf.goblinCamp)
		expect(q.scenes).toEqual({})
	end)
end)

describe("Story chain and data (S102 T4)", function()
	it(
		"every inserted quest is taken where the last one was handed in and handed in where the next is taken",
		function()
			local list = Main.list
			for _, id in StoryProgress.inserted() do
				local i = indexOf[id]
				local quest = list[i]
				if i > 1 then
					expect(`{id} giver {quest.giver}`).toBe(`{id} giver {list[i - 1].turnIn}`)
				end
				if list[i + 1] then
					expect(`{id} turnIn {quest.turnIn}`).toBe(`{id} turnIn {list[i + 1].giver}`)
				end
				expect(quest.wiki).toBe(false)
				expect(quest.category).toBe("main")
			end
		end
	)

	it("levels never go down, except back to the window after a boss quest", function()
		local last = 0
		for _, quest in Main.list do
			expect(`{quest.id} {quest.level >= last}`).toBe(`{quest.id} true`)
			if not hasBoss(quest) then
				last = quest.level
			end
		end
	end)

	it("inserted quests get their EXP from the story rule and gold(level)", function()
		for _, id in StoryProgress.inserted() do
			local quest = assert(Main.get(id))
			local weight = Main.STORY_WEIGHT[id]
			expect(`{id} {weight ~= nil}`).toBe(`{id} true`)
			local lo = QuestBudget.bandOf(quest.level)
			local scale = assert(Main.STORY_SCALE[lo], `scale {lo}`)
			expect(quest.reward.exp).toBe(math.floor(scale * Exp.expToNext(quest.level) * weight))
			expect(quest.reward.exp > 0).toBe(true)
			if not GOLD_EXCEPTIONS[id] then
				expect(quest.reward.gold).toBe(60 + 45 * quest.level)
			end
		end
	end)

	it("lines, items, places, anchors and effects of the story objectives exist", function()
		for _, quest in Main.list do
			for _, objective in quest.objectives do
				if objective.line then
					expect(`{objective.line} {has(objective.line)}`).toBe(`{objective.line} true`)
				end
				if objective.type == "deliver" and objective.item then
					expect(has(`quest.item.{objective.item}`)).toBe(true)
				end
				if objective.type == "reach" and objective.x then
					expect(objective.place ~= nil and has(objective.place :: string)).toBe(true)
				end
				if objective.type == "use" then
					local anchors: { string } = objective.anchors or { objective.anchor :: string }
					for _, anchor in anchors do
						expect(`{anchor} {Areas.anchorById(anchor) ~= nil}`).toBe(`{anchor} true`)
					end
					expect(objective.fx == nil or Side.FX[objective.fx] == true).toBe(true)
				end
			end
		end
	end)
end)

describe("Story pages and chapters (S102 T5)", function()
	it("every quest with pages has p1..pN in both languages; the whole chapter I has pages", function()
		for _, quest in Main.list do
			if quest.pages then
				expect(quest.pages >= 2 and quest.pages <= 4).toBe(true)
				for i = 1, quest.pages do
					expect(`{quest.id}.p{i} {has(`quest.{quest.id}.p{i}`)}`).toBe(`{quest.id}.p{i} true`)
				end
			end
		end
		-- S103: and the whole chapter II
		for i = indexOf.arrival, indexOf.queensLegacy do
			local quest = Main.list[i]
			expect(`{quest.id} {quest.pages ~= nil}`).toBe(`{quest.id} true`)
		end
	end)

	it("chapters start in list order and name their quests", function()
		local last = 0
		for _, chapter in Main.CHAPTERS do
			local first = assert(indexOf[chapter.first], chapter.first)
			expect(first > last).toBe(true)
			last = first
			expect(has(`story.chapter.{chapter.n}`)).toBe(true)
		end
		expect(Main.chapterOf("arrival")).toBe(1)
		expect(Main.chapterOf("warCouncil")).toBe(1)
		expect(Main.chapterOf("toDuskwood")).toBe(2)
		expect(Main.chapterOf("queensLegacy")).toBe(2)
		expect(Main.chapterOf("ashen")).toBe(3)
		expect(Main.chapterOf("vaelgrath")).toBe(4)
		expect(Main.chapterOf("nope")).toBe(1)
		expect(has("story.chapter.1.end")).toBe(true)
	end)
end)

describe("Story cutscenes (S102 T6)", function()
	local C = Config.Cutscene

	it("the data is valid", function()
		expect(Cutscenes.validate()).toEqual({})
	end)

	it("has the seven scenes of chapter I and the ten of chapter II with their triggers, in playing order", function()
		local want = {
			{ "ch1_open", "arrival", "accept" },
			{ "portal_gate", "portal", "objective", 1 },
			{ "frost_ruins", "frostRuins", "objective", 2 },
			{ "bandit_orders", "banditOrders", "turnIn" },
			{ "frost_sign", "frostSign", "objective", 3 },
			{ "grimrok_end", "grimrok", "objective", 1 },
			{ "ch1_close", "warCouncil", "turnIn" },
			-- S103: chapter II
			{ "ch2_title", "toDuskwood", "objective", 1 },
			{ "moonstone", "moonstone", "objective", 2 },
			{ "houseOfVael", "houseOfVael", "objective", 2 },
			{ "elderHeart", "elderHeart", "objective", 1 },
			{ "cult", "cult", "turnIn" },
			{ "turncoat", "turncoat", "objective", 2 },
			{ "barrow", "barrow", "objective", 3 },
			{ "cryptGate", "cryptGate", "objective", 2 },
			{ "morvane", "morvane", "objective", 1 },
			{ "queensLegacy", "queensLegacy", "turnIn" },
		}
		expect(#CutsceneData.list).toBe(#want)
		for i, row in want do
			local scene = CutsceneData.list[i]
			expect(scene.id).toBe(row[1])
			expect(scene.quest).toBe(row[2])
			expect(scene.on).toBe(row[3])
			expect(scene.index).toBe(row[4])
		end
		expect(CutsceneData.get("ch1_open").kind).toBe("chapter")
		expect(CutsceneData.get("ch1_close").title).toBe("story.chapter.1.end")
	end)

	it("every line fits its time in both languages", function()
		local Pl = require("../src/shared/Data/Localization/pl") :: any
		local En = require("../src/shared/Data/Localization/en") :: any
		local most = C.lineMax * C.lineCharsPerSecond
		for _, scene in CutsceneData.list do
			for _, line in scene.lines do
				for _, text in { Pl[line.key], En[line.key] } do
					expect(`{line.key} {type(text) == "string"}`).toBe(`{line.key} true`)
					expect(`{line.key} {(utf8.len(text) or 0) <= most}`).toBe(`{line.key} true`)
					expect(Cutscenes.lineSeconds(text) <= C.lineMax).toBe(true)
				end
			end
		end
	end)

	it("triggers, queue and replay lists", function()
		expect(Cutscenes.triggered("portal", "objective", 1)).toEqual({ "portal_gate" })
		expect(Cutscenes.triggered("portal", "objective", 2)).toEqual({})
		expect(Cutscenes.triggered("warCouncil", "turnIn")).toEqual({ "ch1_close" })
		expect(Cutscenes.triggered("arrival", "accept")).toEqual({ "ch1_open" })
		expect(Cutscenes.pending({ ch1_close = false, portal_gate = false, ch1_open = true, gone = false })).toEqual({
			"portal_gate",
			"ch1_close",
		})
		expect(Cutscenes.pending("oops")).toEqual({})
		expect(Cutscenes.ofQuest("frostSign")).toEqual({ "frost_sign" })
		expect(Cutscenes.ofQuest("healer")).toEqual({})
		expect(Cutscenes.isKnown("frost_ruins")).toBe(true)
		expect(Cutscenes.isKnown("nope")).toBe(false)
	end)

	it("frame: distance, push, height and orbit", function()
		local shot: CutsceneData.Shot =
			{ kind = "point", map = "meadows", x = 0, z = 0, yaw = 30, dist = 20, height = 6, orbit = 40, push = 5 }
		local focus = { x = 10, y = 3, z = -4 }
		local function flat(eye: { x: number, z: number }): (number, number)
			return eye.x - focus.x, eye.z - focus.z
		end
		local e0, l0 = Cutscenes.frame(shot, focus, nil, 0)
		local e1 = Cutscenes.frame(shot, focus, nil, 1)
		expect(l0).toEqual(focus)
		local x0, z0 = flat(e0)
		local x1, z1 = flat(e1)
		expect(math.abs(math.sqrt(x0 * x0 + z0 * z0) - 20) < 1e-6).toBe(true)
		expect(math.abs(math.sqrt(x1 * x1 + z1 * z1) - 15) < 1e-6).toBe(true)
		expect(math.abs(e0.y - 9) < 1e-6).toBe(true)
		expect(math.abs(e1.y - 9) < 1e-6).toBe(true)
		-- yaw 30 at the start: direction (-sin, -cos); 70 at the end
		expect(math.abs(x0 / 20 + math.sin(math.rad(30))) < 1e-6).toBe(true)
		expect(math.abs(z0 / 20 + math.cos(math.rad(30))) < 1e-6).toBe(true)
		expect(math.abs(x1 / 15 + math.sin(math.rad(70))) < 1e-6).toBe(true)
		-- npc / self shots turn from the facing when they have no yaw
		local npcShot: CutsceneData.Shot = { kind = "npc", npc = "captain", dist = 10, orbit = 0, push = 0 }
		local e = Cutscenes.frame(npcShot, focus, 90, 0)
		expect(math.abs((e.x - focus.x) + 10) < 1e-6).toBe(true)
	end)

	it("lineSeconds counts UTF-8 characters and speakers have names", function()
		local C2 = Config.Cutscene
		expect(Cutscenes.lineSeconds("żółć")).toBe(C2.lineMin)
		local long = string.rep("ż", math.floor(C2.lineCharsPerSecond * (C2.lineMin + 1)))
		expect(math.abs(Cutscenes.lineSeconds(long) - (C2.lineMin + 1)) < 1e-6).toBe(true)
		expect(Cutscenes.lineSeconds(string.rep("a", 1000))).toBe(C2.lineMax)
		expect(Cutscenes.speakerKey({ key = "x" })).toBeNil()
		expect(Cutscenes.speakerKey({ who = "captain", key = "x" })).toBe("npc.captain.name")
		expect(Cutscenes.speakerKey({ who = "ilvar", key = "x" })).toBe("cutscene.who.ilvar")
		expect(Cutscenes.speakerKey({ who = "boss:grimrok", key = "x" }) ~= nil).toBe(true)
		expect(Cutscenes.speakerKey({ who = "nobody", key = "x" })).toBeNil()
	end)
end)

describe("Cave quest anchors (S102 T7)", function()
	it("Areas.anchorById finds every anchor of the caves", function()
		for _, cave in Areas.caves.list do
			for _, anchor in cave.questAnchors or {} do
				local found, mapId = Areas.anchorById(anchor.id)
				expect(found).toBe(anchor)
				expect(mapId).toBe(cave.id)
			end
		end
	end)

	-- review S102: the tracker points a kill / collect `area` that is a cave id at the cave (UI/QuestText.areaTarget)
	it("every objective area is a named area or a cave with a mouth on its region map", function()
		local function check(id: string, objectives: { any })
			for i, objective in objectives do
				if objective.area then
					local area = Areas.areaById(objective.area)
					local cave = Areas.caves.get(objective.area)
					local ok = area ~= nil or (cave ~= nil and Areas.arrivalOf(cave.id) ~= nil)
					expect(`{id}#{i} {objective.area} {ok}`).toBe(`{id}#{i} {objective.area} true`)
				end
			end
		end
		for _, quest in Quests.Main.list do
			check(quest.id, quest.objectives)
		end
		for _, quest in Side.list do
			check(quest.id, quest.objectives)
		end
		local charms = assert(Quests.Main.get("warrenCharms")).objectives[3]
		expect(charms.type).toBe("collect")
		expect(charms.area).toBe("meadows_burrow")
		expect(Areas.areaById("meadows_burrow")).toBeNil()
		expect((assert(Areas.caves.get("meadows_burrow"))).region).toBe("meadows")
	end)
end)

describe("Story escort on the side quests' machinery (S102 T11)", function()
	it("the escort of frostSign counts through SideQuests.mainEntry and advance", function()
		local quest, entry = SideQuests.mainEntry({ main = { id = "frostSign", progress = { 1, 0, 0 } } })
		local frostSign = assert(quest, "frostSign")
		local e = assert(entry, "entry")
		local rng = Rng.new(1)
		expect(SideQuests.advance(e, frostSign, "escort", { npc = "brother_anzelm", quest = "frostSign" }, rng)).toEqual({})
		expect(e.progress[2]).toBe(0)
		expect(SideQuests.advance(e, frostSign, "escort", { npc = "sergeant", quest = "frostSign" }, rng)).toEqual({ 2 })
		expect(e.progress[2]).toBe(1)
	end)
end)

describe("regionfolk (S102 T8)", function()
	it("the Meadows NPCs of S27 stand on their spots", function()
		local spots = assert(Areas.byMap.meadows.npcSpots, "spots")
		local pairs = {
			farmer_bartosz = "farmer",
			fisher_wit = "fisher",
			woodcutter_gerwazy = "woodcutter",
			merchant_lucjan = "merchant",
			miner_dobromir = "miner",
			hunter_borys = "hunter",
		}
		for id, spotId in pairs do
			local npc = assert(Npcs.get(id), id)
			local spot = assert(spots[spotId], spotId)
			expect(npc.map).toBe("meadows")
			expect(npc.position.x).toBe(spot.x)
			expect(npc.position.z).toBe(spot.z)
			expect(npc.facing).toBe(spot.facing)
		end
	end)

	it("a spot that does not exist is an error naming the map and the spot", function()
		local ok, err = pcall(function()
			Npcs.regionfolk("duskwood", "test_nobody", "no_such_spot", { body = "#000000", accent = "#000000" }, "?")
		end)
		expect(ok).toBe(false)
		expect(string.find(tostring(err), "no_such_spot", 1, true) ~= nil).toBe(true)
		expect(string.find(tostring(err), "duskwood", 1, true) ~= nil).toBe(true)
	end)
end)

describe("Story EXP rule (S102 T10)", function()
	it("STORY_STEP in the band 1-19, the STORY_BANDS hit TARGET.main", function()
		expect(Main.STORY_SCALE[1]).toBe(Main.STORY_STEP)
		for _, lo in Main.STORY_BANDS do
			local sum = 0
			for _, quest in Main.list do
				if QuestBudget.bandOf(quest.level) == lo and not hasBoss(quest) then
					sum += quest.reward.exp
				end
			end
			local share = sum / QuestBudget.bandExp(lo)
			local target = QuestBudgetData.TARGET.main
			expect(`{lo} {share >= target - 0.003 and share <= target}`).toBe(`{lo} true`)
		end
	end)

	it("weights sit in STORY_BANDS from 20; fixed rewards only on boss quests, the old 1-19 and toDuskwood", function()
		for _, quest in Main.list do
			local lo = QuestBudget.bandOf(quest.level)
			local weighted = Main.STORY_WEIGHT[quest.id] ~= nil
			if weighted and lo >= 20 then
				expect(`{quest.id} {table.find(Main.STORY_BANDS, lo) ~= nil}`).toBe(`{quest.id} true`)
			end
			if not weighted and table.find(Main.STORY_BANDS, lo) then
				expect(`{quest.id} {hasBoss(quest) or quest.id == "toDuskwood"}`).toBe(`{quest.id} true`)
			end
		end
		for id, value in FIXED_EXP do
			expect(`{id} {(assert(Main.get(id), id)).reward.exp}`).toBe(`{id} {value}`)
		end
	end)

	it("the chapter's end weighs more than a plain quest", function()
		local council = assert(Main.get("warCouncil"))
		local plain = math.floor(Main.STORY_SCALE[QuestBudget.bandOf(council.level)] * Exp.expToNext(council.level))
		expect(council.reward.exp > plain).toBe(true)
	end)
end)

-- S103 (docs/FABULA.md §2.3): chapter II "The Forgotten House" ----------------------------------------------------

local CHAPTER_II = {
	"toDuskwood",
	"werewolves",
	"moonstone",
	"lostHunters",
	"ruins",
	"houseOfVael",
	"ents",
	"elderHeart",
	"cult",
	"turncoat",
	"swamp",
	"barrow",
	"crypt",
	"witchCounsel",
	"cryptGate",
	"morvane",
	"queensLegacy",
}
local OLD_II = { "toDuskwood", "werewolves", "ruins", "ents", "cult", "swamp", "crypt", "morvane" }

describe("Chapter II: quests (S103)", function()
	it("has the 17 quests in the order of the plan, levels 20-44, ashen right after", function()
		local first = indexOf.toDuskwood
		for k, id in CHAPTER_II do
			local quest = Main.list[first + k - 1]
			expect(quest.id).toBe(id)
			expect(quest.level >= 20 and quest.level <= 44).toBe(true)
		end
		expect(Main.list[indexOf.queensLegacy + 1].id).toBe("ashen")
		expect(Main.list[indexOf.queensLegacy + 1].level).toBe(45)
	end)

	it("every story quest is taken where the last one was handed in", function()
		for i = 2, #Main.list do
			local quest, before = Main.list[i], Main.list[i - 1]
			expect(`{quest.id} {quest.giver}`).toBe(`{quest.id} {before.turnIn}`)
		end
	end)

	it("new quests: main, hidden from the wiki, 2-4 pages with texts; the old eight 2-3 pages", function()
		for _, id in EXPECTED_INSERTS.S103 do
			local quest = assert(Main.get(id), id)
			expect(quest.category).toBe("main")
			expect(quest.wiki).toBe(false)
			local pages = assert(quest.pages, id)
			expect(pages >= 2 and pages <= 4).toBe(true)
			for _, key in { "title", "text", "done" } do
				expect(`{id}.{key} {has(`quest.{id}.{key}`)}`).toBe(`{id}.{key} true`)
			end
		end
		for _, id in OLD_II do
			local quest = assert(Main.get(id), id)
			local pages = assert(quest.pages, id)
			expect(pages >= 2 and pages <= 3).toBe(true)
			for i = 1, pages do
				expect(has(`quest.{id}.p{i}`)).toBe(true)
			end
			expect(quest.wiki).toBeNil()
		end
	end)

	it(
		"objectives: anchors on Duskwood with texts and effects, places on walkable ground, areas with their kinds",
		function()
			local MapTerrain = require("../src/shared/Logic/MapTerrain")
			for _, id in CHAPTER_II do
				local quest = assert(Main.get(id))
				for i, objective in quest.objectives do
					local tag = `{id}#{i}`
					if objective.type == "use" then
						local anchor, mapId = Areas.anchorById(objective.anchor :: string)
						expect(`{tag} {anchor ~= nil and mapId == "duskwood"}`).toBe(`{tag} true`)
						expect(has(objective.action :: string)).toBe(true)
						expect(Side.FX[objective.fx :: string]).toBe(true)
					elseif objective.type == "reach" and objective.x then
						expect(has(objective.place :: string)).toBe(true)
						local walkable = MapTerrain.walkable(
							objective.map :: string,
							objective.x :: number,
							objective.z :: number,
							6
						)
						expect(`{tag} {walkable}`).toBe(`{tag} true`)
					elseif (objective.type == "kill" or objective.type == "collect") and objective.area then
						local area, mapId = Areas.areaById(objective.area)
						local cave = Areas.caves.get(objective.area)
						if area then
							expect(mapId).toBe("duskwood")
							expect(`{tag} {table.find(area.kinds, objective.monster) ~= nil}`).toBe(`{tag} true`)
						else
							local c = assert(cave, `{tag} {objective.area}`)
							expect(c.region).toBe("duskwood")
						end
						if objective.variant == "elite" then
							local c = assert(cave, `{tag}: an elite objective in a cave`)
							expect(`{tag} {table.find(c.elites, objective.monster) ~= nil}`).toBe(`{tag} true`)
						end
					elseif objective.type == "deliver" then
						expect(has(`quest.item.{objective.item}`)).toBe(true)
						expect(Npcs.get(objective.npc :: string) ~= nil).toBe(true)
					end
					if objective.type == "collect" then
						expect(has(`quest.item.{objective.item}`)).toBe(true)
					end
				end
			end
			-- the elites of the plan: the cultists of the Barrow, the specters of the Crypt
			local barrow = assert(Main.get("barrow")).objectives
			expect(barrow[2].area).toBe("duskwood_barrow")
			expect(barrow[3].variant).toBe("elite")
			expect(assert(Main.get("cryptGate")).objectives[3].area).toBe("duskwood_cave")
		end
	)

	it("queensLegacy: one talk with Anzelm hands in both deliveries, Ysolde apart", function()
		local quest = assert(Main.get("queensLegacy"))
		local progress = QuestLogic.emptyProgress(quest.objectives)
		local rng = Rng.new(3)
		expect(QuestLogic.advance(progress, quest.objectives, "talk", { npc = "brother_anzelm" }, rng)).toEqual({ 1, 2 })
		expect(progress).toEqual({ 1, 1, 0 })
		expect(QuestLogic.advance(progress, quest.objectives, "talk", { npc = "alchemist" }, rng)).toEqual({ 3 })
		expect(QuestLogic.isComplete(progress, quest.objectives)).toBe(true)
	end)

	it("moonstone: talking to Radomir alone does not finish it", function()
		local quest = assert(Main.get("moonstone"))
		local progress = QuestLogic.emptyProgress(quest.objectives)
		local rng = Rng.new(4)
		expect(QuestLogic.advance(progress, quest.objectives, "talk", { npc = "forester_radomir" }, rng)).toEqual({ 1 })
		expect(QuestLogic.isComplete(progress, quest.objectives)).toBe(false)
		-- a werewolf from another area does not count
		expect(
			QuestLogic.advance(
				progress,
				quest.objectives,
				"kill",
				{ monsterId = "werewolf", areaId = "duskwood_bearhollow" },
				rng
			)
		).toEqual({})
	end)

	it("barrow: the Book of Rites drops only from elites", function()
		local quest = assert(Main.get("barrow"))
		local book = quest.objectives[3]
		expect(QuestLogic.amount(book, "kill", { monsterId = "darkCultist", areaId = "duskwood_barrow" }, 0)).toBe(0)
		expect(
			QuestLogic.amount(
				book,
				"kill",
				{ monsterId = "darkCultist", areaId = "duskwood_barrow", variant = "elite" },
				0
			)
		).toBe(1)
	end)

	it("EXP of the new quests: 5-70% of their level, the chapter's end above a plain quest of its level", function()
		for _, id in EXPECTED_INSERTS.S103 do
			local quest = assert(Main.get(id))
			local e = Exp.expToNext(quest.level)
			local share = quest.reward.exp / e
			expect(`{id} {share >= 0.05 and share <= 0.7}`).toBe(`{id} true`)
		end
		local legacy = assert(Main.get("queensLegacy"))
		local plain = math.floor(Main.STORY_SCALE[20] * Exp.expToNext(legacy.level) * 1)
		expect(legacy.reward.exp > plain).toBe(true)
		expect(table.find(Main.STORY_BANDS, 20) ~= nil).toBe(true)
		-- every reward item exists
		local Items = require("../src/shared/Data/Items")
		for _, id in EXPECTED_INSERTS.S103 do
			for _, item in assert(Main.get(id)).reward.items or {} do
				expect(`{item.id} {Items.get(item.id) ~= nil}`).toBe(`{item.id} true`)
			end
		end
	end)
end)

describe("Chapter II: players in the middle of the story (S103, A6)", function()
	local function migrated(fields: { [string]: any }): any
		local c: any = AccountSchema.characterTemplate()
		c.id, c.name, c.level = "x", "x", 30
		for key, value in fields do
			c.quests[key] = value
		end
		local data: any = AccountSchema.accountTemplate()
		data.schema = 7
		data.characters = { x = c }
		AccountSchema.migrate(data)
		return data.characters.x.quests
	end

	it("(a) werewolves handed in (old save): moonstone is offered", function()
		local q = applied({ mainLast = StoryProgress.legacyId(17), mainDone = 17 })
		expect(q.mainLast).toBe("werewolves")
		expect(q.mainDone).toBe(indexOf.werewolves)
		expect((QuestLogic.nextMain(q.mainDone, 22))).toBe(Main.get("moonstone"))
	end)

	it("(b) an active ruins keeps its progress; moonstone and lostHunters count as handed in", function()
		local q = applied({ mainDone = 17, main = { id = "ruins", progress = { 7, 2 } } })
		expect(q.mainDone).toBe(indexOf.ruins - 1)
		expect(q.main.progress).toEqual({ 7, 2 })
		expect(StoryProgress.isDone(q, "moonstone")).toBe(true)
		expect(StoryProgress.isDone(q, "lostHunters")).toBe(true)
		expect(StoryProgress.isDone(q, "houseOfVael")).toBe(false)
	end)

	it("(c) morvane handed in, ashen not taken: queensLegacy, open from level 42", function()
		local q = applied({ mainLast = "morvane", mainDone = 23 })
		local quest, ready = QuestLogic.nextMain(q.mainDone, 42)
		expect(quest).toBe(Main.get("queensLegacy"))
		expect(ready).toBe(true)
		expect((select(2, QuestLogic.nextMain(q.mainDone, 41)))).toBe(false)
	end)

	it("(d) past chapter II: every insertion handed in, the next quest unchanged", function()
		local active = applied({ mainDone = 24, main = { id = "ashen", progress = { 1, 3 } } })
		local last = applied({ mainLast = "orcs", mainDone = 25 })
		for _, id in EXPECTED_INSERTS.S103 do
			expect(StoryProgress.isDone(active, id)).toBe(true)
			expect(StoryProgress.isDone(last, id)).toBe(true)
		end
		expect(active.main.id).toBe("ashen")
		expect(active.main.progress).toEqual({ 1, 3 })
		expect((QuestLogic.nextMain(last.mainDone, 60))).toBe(Main.get("golems"))
	end)

	it("(e) in chapter I nothing of chapter II counts", function()
		local q = applied({ mainDone = 12, main = { id = "goblinCamp", progress = { 4 } } })
		expect(q.mainDone).toBe(indexOf.goblinCamp - 1)
		for _, id in EXPECTED_INSERTS.S103 do
			expect(StoryProgress.isDone(q, id)).toBe(false)
		end
	end)

	it("(f) saved after S102, before S103: cult handed in, crypt or morvane active", function()
		local cult = applied({ mainLast = "cult", mainDone = 24 })
		expect(cult.mainDone).toBe(indexOf.cult)
		expect((QuestLogic.nextMain(cult.mainDone, 31))).toBe(Main.get("turncoat"))
		local crypt = applied({ mainLast = "swamp", mainDone = 25, main = { id = "crypt", progress = { 1, 2 } } })
		expect(crypt.mainDone).toBe(indexOf.crypt - 1)
		expect(crypt.mainLast).toBe("barrow")
		expect(crypt.main.progress).toEqual({ 1, 2 })
		local morvane = applied({ mainLast = "crypt", mainDone = 26, main = { id = "morvane", progress = { 0 } } })
		expect(morvane.mainDone).toBe(indexOf.morvane - 1)
		expect(morvane.mainLast).toBe("cryptGate")
		expect(StoryProgress.isDone(morvane, "witchCounsel")).toBe(true)
		expect(StoryProgress.isDone(morvane, "queensLegacy")).toBe(false)
	end)

	it("(g) a schema 7 save through the migration: same places, CURRENT stays 8", function()
		expect(AccountSchema.CURRENT).toBe(8)
		local wolves = migrated({ mainDone = 17 })
		expect(wolves.mainLast).toBe("werewolves")
		expect(wolves.mainDone).toBe(indexOf.werewolves)
		local queen = migrated({ mainDone = 23 })
		expect((QuestLogic.nextMain(queen.mainDone, 44))).toBe(Main.get("queensLegacy"))
		local ruins = migrated({ mainDone = 17, main = { id = "ruins", progress = { 2, 0 } } })
		expect(ruins.mainDone).toBe(indexOf.ruins - 1)
		expect(ruins.main.progress).toEqual({ 2, 0 })
	end)

	it("(h) idempotent, and mainDone never past the list", function()
		for _, fields in
			{
				{ mainLast = "werewolves" },
				{ mainDone = 17, main = { id = "ruins", progress = { 1, 0 } } },
				{ mainLast = "morvane" },
				{ mainDone = 999 },
			}
		do
			local q = applied(fields)
			local d, l = q.mainDone, q.mainLast
			StoryProgress.apply(q)
			expect(q.mainDone).toBe(d)
			expect(q.mainLast).toBe(l)
			expect(q.mainDone <= #Main.list).toBe(true)
		end
	end)

	it("titles mean what they meant before the insertions", function()
		local TitleData = require("../src/shared/Data/Titles")
		for _, title in TitleData.list do
			local req: any = title.req
			if title.id == "sentinel" then
				expect(req.value).toBe(indexOf.herbs)
			elseif title.id == "dragonbane" then
				expect(req.value).toBe(indexOf.vaelgrath)
			end
		end
	end)
end)

describe("Chapter II: NPCs, places and scenes (S103)", function()
	it("the four story NPCs of Duskwood: hidden from the wiki, texts in both languages, Oswin a ghost", function()
		for _, id in { "forester_radomir", "ghost_oswin", "defector_jorund", "witch_ragna" } do
			local npc = assert(Npcs.get(id), id)
			expect(npc.map).toBe("duskwood")
			expect(npc.wiki).toBe(false)
			expect(npc.lines).toBe(3)
			for _, key in { "name", "role", "greeting", "line1", "line2", "line3", "where" } do
				expect(`{id}.{key} {has(`npc.{id}.{key}`)}`).toBe(`{id}.{key} true`)
			end
			expect(npc.ghost == true).toBe(id == "ghost_oswin")
		end
	end)

	it("Ilvar appears only as a figure; the scenes of chapter II sit on their maps", function()
		local Maps = require("../src/shared/Data/Maps")
		local chapter2 = {
			ch2_title = true,
			moonstone = true,
			houseOfVael = true,
			elderHeart = true,
			cult = true,
			turncoat = true,
			barrow = true,
			cryptGate = true,
			morvane = true,
			queensLegacy = true,
		}
		local withIlvar: { string } = {}
		for _, scene in CutsceneData.list do
			if chapter2[scene.id] then
				local seen = false
				for _, line in scene.lines do
					seen = seen or line.who == "ilvar"
				end
				for _, fig in scene.figures or {} do
					seen = seen or fig.look == "ilvar"
				end
				if seen then
					table.insert(withIlvar, scene.id)
				end
			end
			local shot = scene.shot
			if shot.kind == "point" then
				local map = assert(Maps.get(shot.map :: string))
				expect(math.abs(shot.x :: number) <= map.size.x / 2 and math.abs(shot.z :: number) <= map.size.z / 2).toBe(
					true
				)
			end
		end
		expect(table.concat(withIlvar, ",")).toBe("cryptGate")
		expect(Npcs.get("ilvar")).toBeNil()
		local gate = assert(CutsceneData.get("cryptGate"))
		expect((gate.figures :: any)[1].look).toBe("ilvar")
		expect((gate.figures :: any)[1].ghost).toBe(true)
		expect(assert(CutsceneData.get("ch2_title")).kind).toBe("chapter")
		expect(assert(CutsceneData.get("ch2_title")).subtitle).toBe("story.chapter.2")
		expect(assert(CutsceneData.get("queensLegacy")).title).toBe("story.chapter.2.end")
		expect(has("story.morvane.name")).toBe(true)
	end)
end)
