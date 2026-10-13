--!strict
-- S11: quest data and progress rules.

local Areas = require("../src/shared/Data/Areas")
local Bosses = require("../src/shared/Data/Bosses")
local Items = require("../src/shared/Data/Items")
local Maps = require("../src/shared/Data/Maps")
local Monsters = require("../src/shared/Data/Monsters")
local Npcs = require("../src/shared/Data/Npcs")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Locale = require("../src/shared/Util/Locale")

local function hasText(key: string): boolean
	return Locale.has(key, "pl") and Locale.has(key, "en")
end

local KNOWN_TYPES = {
	talk = true,
	kill = true,
	collect = true,
	gather = true,
	fish = true,
	reach = true,
	boss = true,
	upgrade = true,
	equip = true,
	level = true,
	loot = true,
	stats = true,
	learn = true,
	potion = true,
	duel = true,
	escort = true, -- S101b: walk with the leading companion (CompanionService)
	use = true, -- S102: quest anchors in the story too (Logic/SideQuests)
	deliver = true, -- S102: deliveries in the story too
}

describe("Main quests data", function()
	it("has about 30 quests from level 1 to the Frost Dragon", function()
		local list = Quests.Main.list
		expect(#list >= 28).toBe(true)
		expect(list[1].level).toBe(1)
		expect(list[#list].objectives[1].boss).toBe("vaelgrath")
	end)

	it("never goes down in level", function()
		-- S102: a quest right after a boss quest may sit at the level of the last quest without a boss (warCouncil
		-- after grimrok: the pace window model of tests/Balance counts windows from the quests without a boss)
		local last = 0
		for _, quest in Quests.Main.list do
			expect(`{quest.id} {quest.level >= last}`).toBe(`{quest.id} true`)
			local boss = false
			for _, objective in quest.objectives do
				boss = boss or objective.type == "boss"
			end
			if not boss then
				last = quest.level
			end
		end
	end)

	it("references existing NPCs, monsters, maps, bosses, nodes and items", function()
		for _, quest in Quests.Main.list do
			for _, npc in { quest.giver, quest.turnIn } do
				if not Npcs.get(npc) then
					error(`{quest.id}: unknown NPC {npc}`)
				end
			end
			expect(quest.reward.exp > 0 and quest.reward.gold > 0).toBe(true)
			for _, item in quest.reward.items or {} do
				if not Items.get(item.id) then
					error(`{quest.id}: unknown reward {item.id}`)
				end
			end
			for _, objective in quest.objectives do
				expect(KNOWN_TYPES[objective.type]).toBe(true)
				expect(objective.n >= 1).toBe(true)
				if objective.monster then
					expect(Monsters.get(objective.monster) ~= nil).toBe(true)
				end
				if objective.npc == QuestLogic.CLASS_VENDOR then
					-- S95: "your class vendor" only in talk / deliver objectives (never giver / turn-in)
					expect(objective.type == "talk" or objective.type == "deliver").toBe(true)
				elseif objective.npc then
					expect(Npcs.get(objective.npc) ~= nil).toBe(true)
				end
				if objective.map then
					expect(Maps.get(objective.map) ~= nil).toBe(true)
				end
				if objective.boss then
					expect(Bosses.get(objective.boss) ~= nil).toBe(true)
				end
				if objective.type == "collect" then
					expect(objective.item ~= nil and objective.chance ~= nil).toBe(true)
				end
				-- S102: anchors exist, a talk / deliver line has its text
				local anchors: { string } = objective.anchors or (if objective.anchor then { objective.anchor } else {})
				for _, anchor in anchors do
					expect(`{quest.id} {anchor} {Areas.anchorById(anchor) ~= nil}`).toBe(`{quest.id} {anchor} true`)
				end
				if objective.line then
					expect(objective.type == "talk" or objective.type == "deliver").toBe(true)
					expect(`{objective.line} {hasText(objective.line)}`).toBe(`{objective.line} true`)
				end
			end
		end
	end)

	it("starts with the tutorial", function()
		local types = {}
		for i = 1, 10 do
			for _, objective in Quests.Main.list[i].objectives do
				types[objective.type] = true
			end
		end
		for _, needed in { "talk", "potion", "upgrade", "reach", "kill", "loot", "equip", "stats", "learn" } do
			expect(types[needed]).toBe(true)
		end
	end)

	it("gives the Scroll of Unbinding only once", function()
		local count = 0
		for _, quest in Quests.Main.list do
			for _, item in quest.reward.items or {} do
				if item.id == "scroll_unbind" then
					count += item.n
				end
			end
		end
		expect(count).toBe(1)
	end)
end)

describe("Quest texts", function()
	it("every quest, quest item and daily contract has texts in both languages", function()
		local fs = require("@lune/fs")
		local en = fs.readFile("src/shared/Data/Localization/en.luau")
		local pl = fs.readFile("src/shared/Data/Localization/pl.luau")
		local function has(key: string): boolean
			local pattern = `%["{string.gsub(key, "%.", "%%.")}"%]`
			return string.find(en, pattern) ~= nil and string.find(pl, pattern) ~= nil
		end
		for _, quest in Quests.Main.list do
			for _, suffix in { "title", "text", "done" } do
				if not has(`quest.{quest.id}.{suffix}`) then
					error(`missing quest.{quest.id}.{suffix}`)
				end
			end
			-- S102: offer pages
			for i = 1, quest.pages or 0 do
				if not has(`quest.{quest.id}.p{i}`) then
					error(`missing quest.{quest.id}.p{i}`)
				end
			end
			for _, objective in quest.objectives do
				if objective.item then
					expect(has(`quest.item.{objective.item}`)).toBe(true)
				end
			end
		end
		for _, template in Quests.Daily.templates do
			expect(has(`daily.{template.id}.title`)).toBe(true)
		end
	end)
end)

describe("QuestLogic.amount", function()
	it("matches kills by monster, variant and region", function()
		expect(QuestLogic.amount({ type = "kill", n = 5, monster = "wolf" }, "kill", { monsterId = "wolf" }, 0)).toBe(1)
		expect(QuestLogic.amount({ type = "kill", n = 5, monster = "wolf" }, "kill", { monsterId = "boar" }, 0)).toBe(0)
		local elite = { type = "kill", n = 3, monster = "goblinScout", variant = "elite" }
		expect(QuestLogic.amount(elite, "kill", { monsterId = "goblinScout", variant = "normal" }, 0)).toBe(0)
		expect(QuestLogic.amount(elite, "kill", { monsterId = "goblinScout", variant = "elite2" }, 0)).toBe(1)
		local region = { type = "kill", n = 30, region = 2 }
		expect(QuestLogic.amount(region, "kill", { monsterId = "werewolf" }, 0)).toBe(1)
		expect(QuestLogic.amount(region, "kill", { monsterId = "wolf" }, 0)).toBe(0)
	end)

	it("drops quest items by chance", function()
		local collect = { type = "collect", n = 6, monster = "wolf", item = "wolfFang", chance = 0.5 }
		expect(QuestLogic.amount(collect, "kill", { monsterId = "wolf" }, 0.2)).toBe(1)
		expect(QuestLogic.amount(collect, "kill", { monsterId = "wolf" }, 0.7)).toBe(0)
	end)

	it("matches gathering, bosses, upgrades, equipment, talks and places", function()
		expect(QuestLogic.amount({ type = "gather", n = 5, node = "bush_meadowsweet" }, "gather", {
			kind = "bush_meadowsweet",
			category = "herb",
		}, 0)).toBe(1)
		expect(
			QuestLogic.amount(
				{ type = "gather", n = 5, category = "ore" },
				"gather",
				{ kind = "bush_x", category = "herb" },
				0
			)
		).toBe(0)
		expect(QuestLogic.amount({ type = "boss", n = 1, boss = "grimrok" }, "boss", { bossId = "morvane" }, 0)).toBe(0)
		expect(QuestLogic.amount({ type = "boss", n = 1 }, "boss", { bossId = "morvane" }, 0)).toBe(1)
		expect(QuestLogic.amount({ type = "upgrade", n = 1, up = 5 }, "upgrade", { to = 4 }, 0)).toBe(0)
		expect(QuestLogic.amount({ type = "upgrade", n = 1, up = 5 }, "upgrade", { to = 5 }, 0)).toBe(1)
		expect(QuestLogic.amount({ type = "equip", n = 1, rarity = 3 }, "equip", { rarity = 2 }, 0)).toBe(0)
		expect(QuestLogic.amount({ type = "talk", n = 1, npc = "healer" }, "talk", { npc = "healer" }, 0)).toBe(1)
	end)

	it("counts the world event objective by its kind (S98, from S101)", function()
		local objective = { type = "event", n = 2 }
		expect(QuestLogic.amount(objective, "event", {}, 0)).toBe(1)
		-- S101: WorldEventService's data (every rewarded participant, also on a defeat)
		local data = { eventId = "x", kind = "invasion", success = false, map = "meadows" }
		expect(QuestLogic.amount(objective, "event", data, 0)).toBe(1)
		expect(QuestLogic.amount(objective, "kill", data, 0)).toBe(0)
		local weekly = Quests.Weekly.get("event")
		assert(weekly, "event")
		expect(weekly.hidden == true).toBe(false)
		expect(weekly.objective(1).type).toBe("event")
		expect(QuestLogic.amount(objective, "kill", { monsterId = "wolf" }, 0)).toBe(0)
	end)

	it("resolves the class vendor objective (S95)", function()
		local expected: { [string]: string } = {
			Warrior = "vendor_warrior",
			Cleric = "vendor_cleric",
			Hunter = "vendor_hunter",
			Mage = "vendor_mage",
		}
		for classId, vendor in expected do
			expect(QuestLogic.npcFor(QuestLogic.CLASS_VENDOR, classId)).toBe(vendor)
			expect(Npcs.get(vendor) ~= nil).toBe(true)
		end
		expect(QuestLogic.CLASS_VENDOR).toBe("classVendor")
		expect(QuestLogic.npcFor("healer", "Mage")).toBe("healer")
		expect(QuestLogic.npcFor("classVendor", nil)).toBeNil()
		expect(QuestLogic.npcFor(nil, "Mage")).toBeNil()
		local talk = { type = "talk", n = 1, npc = "classVendor" }
		expect(QuestLogic.amount(talk :: any, "talk", { npc = "vendor_mage", classId = "Mage" }, 0)).toBe(1)
		expect(QuestLogic.amount(talk :: any, "talk", { npc = "vendor_warrior", classId = "Mage" }, 0)).toBe(0)
		expect(QuestLogic.amount(talk :: any, "talk", { npc = "vendor_mage" }, 0)).toBe(0)
		local deliver = { type = "deliver", n = 1, npc = "classVendor", item = "x" }
		expect(
			QuestLogic.amount(
				deliver :: any,
				"talk",
				{ npc = "vendor_hunter", classId = "Hunter", turnIn = "healer" },
				0
			)
		).toBe(1)
		expect(QuestLogic.amount(deliver :: any, "talk", { npc = "healer", classId = "Hunter", turnIn = "healer" }, 0)).toBe(
			0
		)
		expect(QuestLogic.amount({ type = "reach", n = 1, map = "meadows" }, "reach", { map = "meadows" }, 0)).toBe(1)
		expect(QuestLogic.amount({ type = "reach", n = 1, map = "meadows", x = 0, z = 0, radius = 10 }, "reach", {
			map = "meadows",
			x = 50,
			z = 0,
		}, 0)).toBe(0)
		expect(QuestLogic.amount({ type = "fish", n = 3 }, "fish", {}, 0)).toBe(1)
		expect(QuestLogic.amount({ type = "fish", n = 3 }, "loot", {}, 0)).toBe(0)
	end)
end)

describe("QuestLogic progress", function()
	it("advances, caps and completes", function()
		local objectives = { { type = "kill", n = 2, monster = "wolf" }, { type = "loot", n = 1 } }
		local progress = QuestLogic.emptyProgress(objectives)
		local rng = Rng.new(1)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "wolf" }, rng)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "wolf" }, rng)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "wolf" }, rng)
		expect(progress[1]).toBe(2)
		expect(QuestLogic.isComplete(progress, objectives)).toBe(false)
		local changed = QuestLogic.advance(progress, objectives, "loot", {}, rng)
		expect(changed[1]).toBe(2)
		expect(QuestLogic.isComplete(progress, objectives)).toBe(true)
	end)

	it("offers the next main quest by level", function()
		local first, ready = QuestLogic.nextMain(0, 1)
		assert(first, "first")
		expect(first.id).toBe("arrival")
		expect(ready).toBe(true)
		local later, laterReady = QuestLogic.nextMain(10, 1)
		assert(later, "later")
		expect(laterReady).toBe(false)
		expect((QuestLogic.nextMain(#Quests.Main.list, 100))).toBeNil()
	end)
end)

describe("Daily contracts", function()
	it("picks 3 different contracts, the same for the same day", function()
		local a = QuestLogic.dailyFor(123, "char-1", 20000, 30)
		local b = QuestLogic.dailyFor(123, "char-1", 20000, 30)
		expect(#a).toBe(3)
		local seen = {}
		for i, entry in a do
			expect(entry.template).toBe(b[i].template)
			expect(seen[entry.template]).toBeNil()
			seen[entry.template] = true
			expect(entry.progress).toBe(0)
		end
	end)

	it("changes with the day", function()
		local different = false
		local base = QuestLogic.dailyFor(123, "char-1", 20000, 30)
		for day = 20001, 20010 do
			local other = QuestLogic.dailyFor(123, "char-1", day, 30)
			for i, entry in other do
				if entry.template ~= base[i].template then
					different = true
				end
			end
		end
		expect(different).toBe(true)
	end)

	it("respects minimum levels and scales with level", function()
		for day = 1, 30 do
			for _, entry in QuestLogic.dailyFor(5, "c", day, 1) do
				local template = Quests.Daily.get(entry.template)
				assert(template, entry.template)
				expect(template.minLevel <= 1).toBe(true)
			end
		end
		local hunt = Quests.Daily.get("hunt")
		assert(hunt, "hunt")
		expect(hunt.objective(10).region).toBe(1)
		expect(hunt.objective(90).region).toBe(4)
		local reward = Quests.Daily.reward(50)
		for _, item in reward.items or {} do
			expect(Items.get(item.id) ~= nil).toBe(true)
		end
	end)
end)

describe("S56 learn objective", function()
	it("learnedOnBar: the first skill on the bar other than the starting one", function()
		expect(QuestLogic.learnedOnBar({ ["1"] = "mightyStrike" }, "mightyStrike")).toBeNil()
		expect(QuestLogic.learnedOnBar({ ["1"] = "mightyStrike", ["2"] = "battleCry" }, "mightyStrike")).toBe(
			"battleCry"
		)
		expect(QuestLogic.learnedOnBar({ ["3"] = "charge" }, nil)).toBe("charge")
		expect(QuestLogic.learnedOnBar({}, "x")).toBeNil()
		expect(QuestLogic.learnedOnBar("oops", "x")).toBeNil()
	end)

	it("wolves asks for a skill on the bar at level 3", function()
		local wolves = Quests.Main.byId.wolves :: any
		expect(wolves.level).toBe(3)
		local found = false
		for _, objective in wolves.objectives do
			if objective.type == "learn" then
				found = objective.n == 1
			end
		end
		expect(found).toBe(true)
		expect(QuestLogic.amount({ type = "learn", n = 1 } :: any, "learn", { skillId = "battleCry" }, 0)).toBe(1)
	end)
end)

-- S99: the hunting contracts' objective (kill with only an area)
describe("QuestLogic: kill in an area", function()
	it("counts every kind and variant of the area, nothing from another area or without one", function()
		local objective: any = { type = "kill", n = 3, area = "meadows_crowfield" }
		expect(QuestLogic.amount(objective, "kill", { monsterId = "crow", areaId = "meadows_crowfield" }, 0)).toBe(1)
		expect(QuestLogic.amount(objective, "kill", { monsterId = "scarecrow", areaId = "meadows_crowfield" }, 0)).toBe(
			1
		)
		local elite = { monsterId = "crow", variant = "elite", areaId = "meadows_crowfield" }
		expect(QuestLogic.amount(objective, "kill", elite, 0)).toBe(1)
		expect(QuestLogic.amount(objective, "kill", { monsterId = "crow", areaId = "meadows_banditroad" }, 0)).toBe(0)
		expect(QuestLogic.amount(objective, "kill", { monsterId = "crow" }, 0)).toBe(0)
		local progress = { 0 }
		local rng = Rng.new(3)
		for _ = 1, 5 do
			QuestLogic.advance(
				progress,
				{ objective },
				"kill",
				{ monsterId = "crow", areaId = "meadows_crowfield" },
				rng
			)
		end
		expect(progress[1]).toBe(3)
	end)
end)
