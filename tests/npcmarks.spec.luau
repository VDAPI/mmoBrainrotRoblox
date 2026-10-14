--!strict
-- S25: quest marks over NPCs (Logic/NpcMarks).

local Config = require("../src/shared/Config")
local NpcMarks = require("../src/shared/Logic/NpcMarks")
local Npcs = require("../src/shared/Data/Npcs")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- S99: every hunting contract handed in, so the cases before S99 see no contract marks
local function state(main: any, mainDone: number, daily: { any }?): any
	return {
		main = main,
		mainDone = mainDone,
		daily = { day = 1, list = daily or {}, rerolls = 0 },
		contract = { done = Quests.Contracts.MAX_LEVEL },
	}
end

describe("NpcMarks", function()
	it("an available story quest marks its giver", function()
		local first = Quests.Main.list[1]
		local marks = NpcMarks.all(state(nil, 0), 1)
		expect(marks[first.giver]).toBe("available")
	end)

	it("a finished quest marks the turn-in NPC, an open one shows it in progress", function()
		local quest = Quests.Main.list[2]
		local done = {}
		for i, objective in quest.objectives do
			done[i] = objective.n
		end
		expect(NpcMarks.of(quest.turnIn, state({ id = quest.id, progress = done }, 1), 1)).toBe("turnIn")
		local open = QuestLogic.emptyProgress(quest.objectives)
		expect(NpcMarks.of(quest.turnIn, state({ id = quest.id, progress = open }, 1), 1)).toBe("active")
		-- The giver of the next quest has nothing while a quest is active (S27: side quest givers aside).
		local count = 0
		for npcId in NpcMarks.all(state({ id = quest.id, progress = open }, 1), 1) do
			local sideGiver = false
			for _, side in Quests.Side.list do
				sideGiver = sideGiver or side.giver == npcId
			end
			if not sideGiver then
				count += 1
			end
		end
		expect(count).toBe(1)
	end)

	it("no mark when the level is too low", function()
		local index, quest = 0, nil :: Quests.MainQuest?
		for i, candidate in Quests.Main.list do
			if candidate.level - Quests.Main.LEVEL_SLACK > 1 then
				index, quest = i, candidate
				break
			end
		end
		assert(quest, "a quest above level 1")
		expect(NpcMarks.of(quest.giver, state(nil, index - 1), 1)).toBeNil()
		expect(NpcMarks.of(quest.giver, state(nil, index - 1), quest.level)).toBe("available")
	end)

	it("the contract board follows the daily list from dailyFor", function()
		local list: { any } = QuestLogic.dailyFor(123, "char-1", 20000, 10)
		expect(#list > 0).toBe(true)
		expect(NpcMarks.of(NpcMarks.BOARD, state(nil, 999, list), 10)).toBe("active")
		local first = list[1]
		first.progress = first.objective.n
		expect(NpcMarks.of(NpcMarks.BOARD, state(nil, 999, list), 10)).toBe("turnIn")
		for _, entry in list do
			entry.claimed = true
		end
		expect(NpcMarks.of(NpcMarks.BOARD, state(nil, 999, list), 10)).toBeNil()
	end)

	it("marks only NPCs that exist", function()
		for _, quest in Quests.Main.list do
			expect(Npcs.get(quest.giver) ~= nil and Npcs.get(quest.turnIn) ~= nil).toBe(true)
		end
		expect(NpcMarks.all(nil, 1)).toEqual({})
	end)

	it("story chapter II (S103): the marks over Borin, Radomir, the captain and Jorund", function()
		local indexOf = Quests.Main.indexOf
		expect(NpcMarks.of("scout_duskwood", state(nil, indexOf.werewolves), 22)).toBe("available")
		local moonstone = assert(Quests.Main.get("moonstone"))
		local full = {}
		for i, objective in moonstone.objectives do
			full[i] = objective.n
		end
		local ready = state({ id = "moonstone", progress = full }, indexOf.moonstone - 1)
		expect(NpcMarks.of("forester_radomir", ready, 22)).toBe("turnIn")
		expect(NpcMarks.of("forester_radomir", state(nil, indexOf.moonstone), 23)).toBe("available")
		local turncoat = assert(Quests.Main.get("turncoat"))
		local running =
			state({ id = "turncoat", progress = QuestLogic.emptyProgress(turncoat.objectives) }, indexOf.cult)
		expect(NpcMarks.of("captain", running, 31)).toBe("active")
		local jorund = NpcMarks.of("defector_jorund", running, 31)
		expect(jorund ~= "available" and jorund ~= "availableLow").toBe(true)
	end)

	it("priority orders turn-in over available over active", function()
		expect(NpcMarks.priority("turnIn") > NpcMarks.priority("available")).toBe(true)
		expect(NpcMarks.priority("available") > NpcMarks.priority("availableLow")).toBe(true)
		expect(NpcMarks.priority("availableLow") > NpcMarks.priority("active")).toBe(true)
		expect(NpcMarks.priority("active") > NpcMarks.priority(nil)).toBe(true)
		expect(NpcMarks.priority(nil)).toBe(0)
	end)

	-- S98 (docs/DESIGN-15.md §3.1): the grey "!", the weekly contracts and the boss quests of the scouts
	local function sideState(done: { [string]: boolean }?, weekly: any?): any
		local s = state(nil, 999)
		s.side = { active = {}, done = done or {} }
		s.weekly = weekly
		return s
	end

	it("an offer more than greyGap levels below is grey, at greyGap it is gold", function()
		local gap = Config.Quest.greyGap
		expect(NpcMarks.isLow(10, 10 + gap)).toBe(false)
		expect(NpcMarks.isLow(10, 10 + gap + 1)).toBe(true)
		local q = Quests.Boss.get("boss_grimrok")
		assert(q, "boss_grimrok")
		expect(NpcMarks.of(q.giver, sideState(), q.level + gap)).toBe("available")
		expect(NpcMarks.of(q.giver, sideState(), q.level + gap + 1)).toBe("availableLow")
	end)

	it("a gold offer wins over a grey one at the same NPC", function()
		-- the stablemaster: side_wagon (10) is grey at 21, the stable arc's first quest (21) is gold
		local wagon = Quests.Side.get("side_wagon")
		local harness = Quests.Side.get("side_stable_harness")
		assert(wagon and harness, "stablemaster quests")
		expect(wagon.giver).toBe("stablemaster")
		expect(harness.giver).toBe("stablemaster")
		expect(NpcMarks.isLow(wagon.level, 21)).toBe(true)
		expect(NpcMarks.of("stablemaster", sideState(), 21)).toBe("available")
		local arcDone = { side_stable_harness = true, side_stable_stallion = true }
		expect(NpcMarks.of("stablemaster", sideState(arcDone), 21)).toBe("availableLow")
	end)

	it("the board shows weekly contracts and the boss contract", function()
		local list: { any } = QuestLogic.weeklyFor(7, "c", 2963, 30)
		local weekly = { week = 2963, list = list, rerolls = 0 }
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("active")
		list[1].progress = list[1].objective.n
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("turnIn")
		for _, entry in list do
			entry.claimed = true
		end
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBeNil()
		weekly.boss = { boss = "morvane", progress = 0, claimed = false }
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("active")
		weekly.boss.progress = Quests.Weekly.bossContract.n
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBe("turnIn")
		weekly.boss.claimed = true
		expect(NpcMarks.of(NpcMarks.BOARD, sideState(nil, weekly), 30)).toBeNil()
	end)

	it("the Meadows scout offers Grimrok's Slayer at 15", function()
		local q = Quests.Boss.get("boss_grimrok")
		assert(q, "boss_grimrok")
		expect(q.giver).toBe("scout_meadows")
		expect(NpcMarks.of("scout_meadows", sideState(), 14)).toBeNil()
		expect(NpcMarks.of("scout_meadows", sideState(), 15)).toBe("available")
	end)

	-- S99 (docs/DESIGN-15.md §3.3): the hunting contract at the board and the scout of its region
	local function contractState(done: number, active: any?): any
		local s = state(nil, 999)
		-- the boss quests of the scouts handed in: only the contract marks the scouts
		local bossDone = {}
		for _, q in Quests.Boss.list do
			bossDone[q.id] = true
		end
		s.side = { active = {}, done = bossDone }
		s.contract = { done = done, active = active }
		return s
	end

	local function scoutOf(level: number): string
		return `scout_{(Quests.Contracts.forLevel(level) :: any).map}`
	end

	local function otherScout(level: number): string
		local own = scoutOf(level)
		for _, map in { "meadows", "duskwood", "ashen", "frostpeak" } do
			if `scout_{map}` ~= own then
				return `scout_{map}`
			end
		end
		error("no other scout")
	end

	it("the next contract is a gold ! at the board and its scout, grey far below the level", function()
		-- contract 31 (Dark Forest): no boss quest of the Dark Forest scout is open at 31 (Morvane's is from 40)
		local s = contractState(30)
		expect(NpcMarks.of(NpcMarks.BOARD, s, 31)).toBe("available")
		expect(NpcMarks.of(scoutOf(31), s, 31)).toBe("available")
		expect(NpcMarks.of(otherScout(31), s, 31)).toBeNil()
		expect(NpcMarks.of(NpcMarks.BOARD, s, 30)).toBeNil() -- below its level: nothing to take
		local gap = Config.Quest.greyGap
		expect(NpcMarks.of(NpcMarks.BOARD, s, 31 + gap)).toBe("available")
		expect(NpcMarks.of(NpcMarks.BOARD, s, 32 + gap)).toBe("availableLow")
		expect(NpcMarks.of(scoutOf(31), s, 32 + gap)).toBe("availableLow")
	end)

	it("an active contract is a grey ? until done, then ? at both givers", function()
		local contract = Quests.Contracts.forLevel(31) :: any
		local open = contractState(30, { level = 31, progress = { 0 } })
		expect(NpcMarks.of(NpcMarks.BOARD, open, 31)).toBe("active")
		expect(NpcMarks.of(scoutOf(31), open, 31)).toBe("active")
		local done = contractState(30, { level = 31, progress = { contract.objectives[1].n } })
		expect(NpcMarks.of(NpcMarks.BOARD, done, 31)).toBe("turnIn")
		expect(NpcMarks.of(scoutOf(31), done, 31)).toBe("turnIn")
		expect(NpcMarks.of(otherScout(31), done, 31)).toBeNil()
	end)

	it("a scout with a story quest to hand in and a contract to take shows ?", function()
		-- the Meadows scout gives Grimrok's Slayer (15) and the contracts of the Meadows
		local slayer = Quests.Boss.get("boss_grimrok") :: any
		local contract = Quests.Contracts.forLevel(15) :: any
		expect(contract.map).toBe("meadows")
		local s = contractState(14)
		s.side.active[slayer.id] = { progress = { slayer.objectives[1].n } }
		expect(NpcMarks.of("scout_meadows", s, 15)).toBe("turnIn")
		s.side.active = {}
		expect(NpcMarks.of("scout_meadows", s, 15)).toBe("available")
	end)

	it("after the 99th contract the board has no contract mark", function()
		expect(NpcMarks.of(NpcMarks.BOARD, contractState(99), 100)).toBeNil()
		expect(NpcMarks.of(scoutOf(99), contractState(99), 100)).toBeNil()
	end)
end)

return nil
