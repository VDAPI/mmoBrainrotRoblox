--!strict
-- S11: quest data and progress rules.

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
}

describe("Main quests data", function()
	it("has about 30 quests from level 1 to the Frost Dragon", function()
		local list = Quests.Main.list
		expect(#list >= 28).toBe(true)
		expect(list[1].level).toBe(1)
		expect(list[#list].objectives[1].boss).toBe("vaelgrath")
	end)

	it("never goes down in level", function()
		local last = 0
		for _, quest in Quests.Main.list do
			expect(quest.level >= last).toBe(true)
			last = quest.level
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
				if objective.npc then
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
