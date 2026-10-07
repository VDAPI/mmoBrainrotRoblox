--!strict
-- S27: side quests of the Whispering Meadows: data consistency (NPCs, anchors, monsters, areas, caves, texts),
-- level continuity, the EXP budget, the rules of Logic/SideQuests and the save migration.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Areas = require("../src/shared/Data/Areas")
local Config = require("../src/shared/Config")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
local Monsters = require("../src/shared/Data/Monsters")
local NpcMarks = require("../src/shared/Logic/NpcMarks")
local Npcs = require("../src/shared/Data/Npcs")
local Quests = require("../src/shared/Data/Quests")
local Rng = require("../src/shared/Logic/Rng")
local SideQuests = require("../src/shared/Logic/SideQuests")
local Test = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = Test.describe, Test.it, Test.expect

type SideQuest = Quests.SideQuest

local KNOWN_TYPES = {
	talk = true,
	kill = true,
	collect = true,
	gather = true,
	fish = true,
	reach = true,
	use = true,
	deliver = true,
}

local function hasKey(key: string): boolean
	return (pl :: any)[key] ~= nil and (en :: any)[key] ~= nil
end

local function quests(side: any?, mainDone: number?): any
	return {
		main = nil,
		mainDone = mainDone or 0,
		daily = { day = 0, list = {}, rerolls = 0 },
		side = side or { active = {}, done = {} },
	}
end

local function doneUpTo(id: string): { [string]: boolean }
	local done = {}
	local quest = assert(Quests.Side.get(id), id)
	for _, other in Quests.Side.byArc[quest.arc] do
		if other.id == id then
			break
		end
		done[other.id] = true
	end
	for _, req in quest.requires or {} do
		done[req] = true
	end
	return done
end

describe("Side quest data", function()
	it("has 28 quests in 9 arcs, every arc with exactly one final quest at its end", function()
		expect(#Quests.Side.list).toBe(28)
		expect(#Quests.Side.ARCS).toBe(9)
		for _, arc in Quests.Side.ARCS do
			local list = assert(Quests.Side.byArc[arc], arc)
			local finals = 0
			for i, quest in list do
				if quest.reward.choice then
					finals += 1
					expect(i).toBe(#list)
				end
			end
			expect(finals).toBe(1)
			expect(hasKey(`quest.arc.{arc}`)).toBe(true)
		end
	end)

	it("givers and turn-in NPCs exist and talk", function()
		for _, quest in Quests.Side.list do
			for _, npcId in { quest.giver, quest.turnIn } do
				local npc = Npcs.get(npcId)
				if not npc or npc.decoration then
					error(`{quest.id}: unknown NPC {npcId}`)
				end
			end
		end
	end)

	it("requirements exist, come earlier in level and have no cycles", function()
		local function visit(id: string, seen: { [string]: boolean })
			if seen[id] then
				error(`cycle at {id}`)
			end
			seen[id] = true
			local quest = Quests.Side.get(id)
			if quest then
				for _, req in quest.requires or {} do
					visit(req, table.clone(seen))
				end
			end
		end
		for _, quest in Quests.Side.list do
			for _, req in quest.requires or {} do
				local other = Quests.Side.get(req)
				local main = Quests.Main.get(req)
				if not other and not main then
					error(`{quest.id}: unknown requirement {req}`)
				end
				if other then
					expect(other.level <= quest.level).toBe(true)
				end
			end
			visit(quest.id, {})
		end
	end)

	it("objectives point at existing anchors, monsters, areas, nodes and NPCs", function()
		local anchors: { [string]: boolean } = {}
		for _, anchor in Areas.byMap.meadows.questAnchors or {} do
			anchors[anchor.id] = true
		end
		local nodes: { [string]: boolean } = {}
		for _, node in MeadowsGen.nodes() do
			nodes[node.kind] = true
		end
		for _, quest in Quests.Side.list do
			-- the cave of a "reach" objective (elite kills must live there)
			local cave: any = nil
			for _, objective in quest.objectives do
				if objective.type == "reach" and objective.map then
					cave = Areas.caves.get(objective.map)
				end
			end
			for _, objective in quest.objectives do
				local what = `{quest.id} {objective.type}`
				expect(KNOWN_TYPES[objective.type] == true).toBe(true)
				expect(objective.n >= 1).toBe(true)
				if objective.type == "use" then
					local list: { string } = objective.anchors or { objective.anchor :: string }
					expect(#list).toBe(objective.n)
					for _, id in list do
						if not anchors[id] then
							error(`{what}: unknown anchor {id}`)
						end
					end
					expect(objective.action ~= nil and hasKey(objective.action :: string)).toBe(true)
					expect(objective.fx ~= nil and Quests.Side.FX[objective.fx :: string] == true).toBe(true)
					expect((objective.hold or 0) >= 1.5 and (objective.hold or 0) <= 3).toBe(true)
				end
				if objective.type == "deliver" or objective.type == "collect" then
					expect(objective.item ~= nil and hasKey(`quest.item.{objective.item}`)).toBe(true)
				end
				if objective.type == "deliver" or objective.type == "talk" then
					expect(Npcs.get(objective.npc or quest.turnIn) ~= nil).toBe(true)
				end
				if objective.type == "gather" and objective.node then
					if not nodes[objective.node] then
						error(`{what}: no {objective.node} node on the Meadows`)
					end
				end
				if objective.monster then
					expect(Monsters.get(objective.monster) ~= nil).toBe(true)
				end
				if objective.area then
					local area = Areas.areaById(objective.area)
					if not area or not table.find(area.kinds, objective.monster :: string) then
						error(`{what}: {objective.monster} does not live in {objective.area}`)
					end
				end
				if objective.variant == "elite" then
					if not cave or not table.find(cave.elites, objective.monster :: string) then
						error(`{what}: elite {objective.monster} not in the quest's cave`)
					end
				end
				if objective.type == "reach" and objective.x then
					expect(objective.place ~= nil and hasKey(objective.place :: string)).toBe(true)
				end
			end
		end
	end)

	it("every quest has its title, pages, progress and thanks in both languages", function()
		for _, quest in Quests.Side.list do
			expect(quest.pages >= 2 and quest.pages <= 4).toBe(true)
			local keys = { `quest.{quest.id}.title`, `quest.{quest.id}.progress`, `quest.{quest.id}.done` }
			for i = 1, quest.pages do
				table.insert(keys, `quest.{quest.id}.p{i}`)
			end
			for _, key in keys do
				if not hasKey(key) then
					error(`missing {key}`)
				end
			end
			expect(hasKey(`quest.{quest.id}.p{quest.pages + 1}`)).toBe(false)
		end
	end)

	it("new NPCs have role, lines and a place for the innkeeper's gossip", function()
		for _, npc in Npcs.list do
			for i = 1, npc.lines or 0 do
				expect(hasKey(`npc.{npc.id}.line{i}`)).toBe(true)
			end
		end
		for _, quest in Quests.Side.list do
			if not hasKey(`npc.{quest.giver}.where`) then
				error(`missing npc.{quest.giver}.where`)
			end
		end
		for i = 1, 3 do
			expect(hasKey(`npc.innkeeper.gossip{i}`)).toBe(true)
		end
	end)

	it("Meadows NPCs stand on the places S26 prepared", function()
		local spots = Areas.byMap.meadows.npcSpots or {}
		local count = 0
		for _, npc in Npcs.list do
			if npc.map == "meadows" and npc.id ~= "scout_meadows" then
				count += 1
				local found = false
				for _, spot in spots do
					found = found or (spot.x == npc.position.x and spot.z == npc.position.z)
				end
				if not found then
					error(`{npc.id} is not on an npc spot`)
				end
			end
		end
		expect(count).toBe(6)
	end)
end)

describe("Side quest levels and balance", function()
	it("every two levels from 1 to 20 have a side quest", function()
		for from = 1, 19, 2 do
			local found = false
			for _, quest in Quests.Side.list do
				found = found or (quest.level >= from and quest.level <= from + 1)
			end
			if not found then
				error(`no side quest for levels {from}-{from + 1}`)
			end
		end
	end)

	it("can be taken once the earlier ones are done, at their minimum level", function()
		for _, quest in Quests.Side.list do
			local ok, reason = SideQuests.canAccept(
				quests({ active = {}, done = doneUpTo(quest.id) }),
				SideQuests.minLevel(quest),
				quest
			)
			if not ok then
				error(`{quest.id}: {reason}`)
			end
		end
	end)

	it("give at most 40% of the EXP from level 1 to 20, at most 70% of a level each", function()
		local need = 0
		for level = 1, 19 do
			need += Exp.expToNext(level)
		end
		local total = 0
		for _, quest in Quests.Side.list do
			total += quest.reward.exp
			expect(quest.reward.exp <= Exp.expToNext(quest.level) * 0.7).toBe(true)
			expect(quest.reward.gold > 0).toBe(true)
		end
		expect(total <= need * 0.4).toBe(true)
	end)

	it("offer three class items (weapon first) for every class at every final quest", function()
		local rng = Rng.new(5)
		for _, class in { "Warrior", "Hunter", "Mage", "Cleric" } do
			for _, quest in Quests.Side.list do
				if quest.reward.choice then
					local ids = SideQuests.choiceIds(class, quest.level, Config.SideQuest.choiceCount, rng)
					expect(#ids).toBe(Config.SideQuest.choiceCount)
					local weapon = assert(Items.get(ids[1]), ids[1])
					expect(weapon.weapon ~= nil).toBe(true)
					for _, id in ids do
						local def = assert(Items.get(id), id)
						expect(def.classes == nil or table.find(def.classes, class) ~= nil).toBe(true)
					end
					local n = 0
					local items = SideQuests.rollChoice(quest, class, rng, function()
						n += 1
						return `uid{n}`
					end)
					expect(#items).toBe(3)
					for _, item in items do
						expect(item.rarity).toBe(Config.SideQuest.choiceRarity.final)
						expect(item.ilvl).toBe(quest.level)
					end
				end
			end
		end
	end)
end)

describe("SideQuests rules", function()
	local granary = assert(Quests.Side.get("side_granary"))
	local rabbits = assert(Quests.Side.get("side_rabbits"))
	local fence = assert(Quests.Side.get("side_fence"))

	it("canAccept: level, requirements, limit, active and done", function()
		expect((SideQuests.canAccept(quests(), 1, granary))).toBe(true)
		local _, reason = SideQuests.canAccept(quests(), 1, rabbits)
		expect(reason).toBe("requires")
		local tooLow = assert(Quests.Side.get("side_wanted"))
		_, reason = SideQuests.canAccept(quests({ active = {}, done = doneUpTo("side_wanted") }), 5, tooLow)
		expect(reason).toBe("level")
		_, reason = SideQuests.canAccept(quests({ active = {}, done = { side_granary = true } }), 1, granary)
		expect(reason).toBe("done")
		_, reason = SideQuests.canAccept(
			quests({ active = { side_granary = SideQuests.newEntry(granary) }, done = {} }),
			1,
			granary
		)
		expect(reason).toBe("active")
		local full = {}
		for i, quest in Quests.Side.list do
			if i <= Config.SideQuest.maxActive + 1 and quest.id ~= "side_granary" then
				full[quest.id] = SideQuests.newEntry(quest)
			end
		end
		_, reason = SideQuests.canAccept(quests({ active = full, done = {} }), 20, granary)
		expect(reason).toBe("limit")
	end)

	it("available / later / turnInReady per NPC and the innkeeper's gossip", function()
		local q = quests()
		local offered = SideQuests.available(q, 1, "granary_keeper")
		expect(#offered).toBe(1)
		expect(offered[1].id).toBe("side_granary")
		expect(#SideQuests.available(q, 1, "farmer_bartosz")).toBe(0)
		-- side_totem (15) is later; side_wanted needs side_goods first and is not listed at all
		local later = SideQuests.later(q, 1, "sergeant")
		expect(#later).toBe(1)
		expect(later[1].id).toBe("side_totem")
		local givers = SideQuests.giversWithWork(q, 1, "innkeeper")
		expect(table.find(givers, "granary_keeper") ~= nil).toBe(true)
		expect(table.find(givers, "innkeeper")).toBeNil()
		-- deliver: talking to the turn-in NPC completes it
		local entry = SideQuests.newEntry(granary)
		local rng = Rng.new(1)
		expect(#SideQuests.advance(entry, granary, "talk", { npc = "granary_keeper" }, rng)).toBe(0)
		expect(#SideQuests.advance(entry, granary, "talk", { npc = "farmer_bartosz" }, rng)).toBe(1)
		local ready = SideQuests.turnInReady(quests({ active = { side_granary = entry }, done = {} }), "farmer_bartosz")
		expect(#ready).toBe(1)
		expect(#SideQuests.turnInReady(quests({ active = { side_granary = entry }, done = {} }), "granary_keeper")).toBe(
			0
		)
	end)

	it("use: every anchor counts once", function()
		local entry = SideQuests.newEntry(fence)
		local rng = Rng.new(1)
		expect(#SideQuests.advance(entry, fence, "use", { anchor = "fence_1" }, rng)).toBe(1)
		expect(#SideQuests.advance(entry, fence, "use", { anchor = "fence_1" }, rng)).toBe(0)
		expect(#SideQuests.advance(entry, fence, "use", { anchor = "net_shore" }, rng)).toBe(0)
		expect(entry.progress[1]).toBe(1)
		expect(SideQuests.pendingUse(entry, fence, "fence_1")).toBeNil()
		expect(SideQuests.pendingUse(entry, fence, "fence_2")).toBe(1)
		for _, id in { "fence_2", "fence_3", "fence_4" } do
			SideQuests.advance(entry, fence, "use", { anchor = id }, rng)
		end
		expect(SideQuests.isComplete(entry, fence)).toBe(true)
		local q = quests({ active = { side_fence = entry }, done = {} })
		expect(SideQuests.usableAnchors(q).fence_1).toBeNil()
		expect(SideQuests.doneAnchors(q).fence_3).toBe("plank")
	end)

	it("kill with an area counts only monsters of that area", function()
		local entry = SideQuests.newEntry(rabbits)
		local rng = Rng.new(1)
		expect(#SideQuests.advance(entry, rabbits, "kill", { monsterId = "rabbit", areaId = "meadows_wolfhills" }, rng)).toBe(
			0
		)
		expect(#SideQuests.advance(entry, rabbits, "kill", { monsterId = "rabbit" }, rng)).toBe(0)
		expect(
			#SideQuests.advance(entry, rabbits, "kill", { monsterId = "rabbit", areaId = "meadows_rabbitfields" }, rng)
		).toBe(1)
		expect(
			#SideQuests.advance(entry, rabbits, "kill", { monsterId = "wolf", areaId = "meadows_rabbitfields" }, rng)
		).toBe(0)
	end)

	it("reach with a place needs the position", function()
		local circle = assert(Quests.Side.get("side_stoneCircle"))
		local entry = SideQuests.newEntry(circle)
		local rng = Rng.new(1)
		expect(#SideQuests.advance(entry, circle, "reach", { map = "meadows" }, rng)).toBe(0)
		expect(#SideQuests.advance(entry, circle, "reach", { map = "meadows", x = -100, z = -150 }, rng)).toBe(0)
		expect(#SideQuests.advance(entry, circle, "reach", { map = "meadows", x = -335, z = -140 }, rng)).toBe(1)
	end)

	it("marks: ! at a giver, ? at the turn-in NPC when done, grey ? while open", function()
		local marks = NpcMarks.all(quests(nil, 0), 1)
		expect(marks.granary_keeper).toBe("available")
		expect(marks.farmer_bartosz).toBeNil()
		local entry = SideQuests.newEntry(granary)
		marks = NpcMarks.all(quests({ active = { side_granary = entry }, done = {} }), 1)
		expect(marks.farmer_bartosz).toBe("active")
		entry.progress[1] = 1
		marks = NpcMarks.all(quests({ active = { side_granary = entry }, done = {} }), 1)
		expect(marks.farmer_bartosz).toBe("turnIn")
		expect(marks.granary_keeper).toBeNil()
	end)

	it("arc progress", function()
		local done, total = SideQuests.arcProgress(quests({ active = {}, done = doneUpTo("side_sheep") }), "farm")
		expect(done).toBe(3)
		expect(total).toBe(5)
	end)
end)

describe("AccountSchema S27", function()
	it("the migration adds quests.side and keeps old saves intact", function()
		local data: any = {
			schema = 3,
			characters = {
				["1"] = {
					id = "a",
					name = "Old",
					level = 12,
					quests = { main = { id = "boars", progress = { 4 } }, mainDone = 8 },
				},
				["2"] = { id = "b", name = "Broken", level = 3, quests = { mainDone = 1, side = "oops" } },
			},
		}
		local applied = AccountSchema.migrate(data)
		expect(applied).toEqual({ 4, 5 })
		expect(data.characters["1"].quests.side).toEqual({ active = {}, done = {} })
		expect(data.characters["2"].quests.side).toEqual({ active = {}, done = {} })
		expect(data.characters["1"].quests.main.id).toBe("boars")
		expect(data.characters["1"].quests.mainDone).toBe(8)
		expect(data.characters["1"].level).toBe(12)
	end)
end)

return nil
