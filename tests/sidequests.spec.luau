--!strict
-- S27: side quests of the Whispering Meadows: data consistency (NPCs, anchors, monsters, areas, caves, texts),
-- level continuity, the EXP budget, the rules of Logic/SideQuests and the save migration.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Areas = require("../src/shared/Data/Areas")
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local DuskwoodGen = require("../src/shared/Logic/DuskwoodGen")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
local Monsters = require("../src/shared/Data/Monsters")
local Mounts = require("../src/shared/Data/Mounts")
local NpcMarks = require("../src/shared/Logic/NpcMarks")
local Npcs = require("../src/shared/Data/Npcs")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local QuestBudget = require("../src/shared/Logic/QuestBudget")
local QuestBudgetData = require("../src/shared/Data/QuestBudget")
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
	escort = true, -- S106: side_boneTree (Wanda leads)
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
	-- S96: the stable arc (3 quests) ends with a mount instead of an item choice; S106: + 27 quests in 8 Duskwood arcs
	it("has 58 quests in 18 arcs, every arc with exactly one final quest (choice or mount) at its end", function()
		expect(#Quests.Side.list).toBe(58)
		expect(#Quests.Side.ARCS).toBe(18)
		for _, arc in Quests.Side.ARCS do
			local list = assert(Quests.Side.byArc[arc], arc)
			local finals = 0
			for i, quest in list do
				expect(quest.reward.choice == nil or quest.reward.mount == nil).toBe(true)
				if quest.reward.choice or quest.reward.mount then
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

	-- S106: anchors of every map, gathering nodes of the quest's map (the map of its areas, anchors or `where`)
	it("objectives point at existing anchors, monsters, areas, nodes and NPCs", function()
		local nodesOf: { [string]: { [string]: boolean } } = { meadows = {}, duskwood = {} }
		for _, node in MeadowsGen.nodes() do
			nodesOf.meadows[node.kind] = true
		end
		for _, node in DuskwoodGen.nodes() do
			nodesOf.duskwood[node.kind] = true
		end
		local function mapOf(quest: SideQuest): string
			if quest.where then
				return quest.where.map
			end
			for _, objective in quest.objectives do
				if objective.area then
					local _, mapId = Areas.areaById(objective.area)
					return mapId or "meadows"
				end
				local list: { string } = objective.anchors or { objective.anchor :: string }
				if objective.type == "use" and list[1] then
					local _, mapId = Areas.anchorById(list[1])
					return mapId or "meadows"
				end
			end
			return "meadows"
		end
		for _, quest in Quests.Side.list do
			local nodes = nodesOf[mapOf(quest)] or {}
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
						if not Areas.anchorById(id) then
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
				if
					(objective.type == "deliver" or objective.type == "talk")
					and objective.npc ~= QuestLogic.CLASS_VENDOR
				then
					expect(Npcs.get(objective.npc or quest.turnIn) ~= nil).toBe(true)
				elseif objective.npc == QuestLogic.CLASS_VENDOR then
					-- S95: "your class vendor" only in talk / deliver objectives
					expect(objective.type == "deliver" or objective.type == "talk").toBe(true)
				end
				if objective.type == "gather" and objective.node then
					if not nodes[objective.node] then
						error(`{what}: no {objective.node} node on the quest's map`)
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

	it("S101b: side() keeps the dialogue fields (side_den)", function()
		local den = assert(Quests.Side.get("side_den"))
		expect(den.choices ~= nil and #(den.choices :: any).options == 3).toBe(true)
		expect(den.recall).toEqual({ p1 = "side_bears" })
		expect((den.barks :: any).near).toBe(1)
		expect((den.companion :: any).npc).toBe("hunter_borys")
		-- a quest without them has none
		local granary = assert(Quests.Side.get("side_granary"))
		expect(granary.choices).toBeNil()
		expect(granary.companion).toBeNil()
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

	-- S96: the budget 1 -> 20 counts the quests up to level 19 (the stable arc is above it); 70% holds for all
	it("give at most 40% of the EXP from level 1 to 20, at most 70% of a level each", function()
		local need = 0
		for level = 1, 19 do
			need += Exp.expToNext(level)
		end
		local total = 0
		for _, quest in Quests.Side.list do
			if quest.level <= 19 then
				total += quest.reward.exp
			end
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

describe("S96 stable arc", function()
	local harness = assert(Quests.Side.get("side_stable_harness"))
	local ride = assert(Quests.Side.get("side_stable_ride"))

	it("is taken from level 20 and ends with the bay horse", function()
		local _, reason = SideQuests.canAccept(quests(), 19, harness)
		expect(reason).toBe("level")
		expect((SideQuests.canAccept(quests(), 20, harness))).toBe(true)
		for _, quest in Quests.Side.byArc.stable do
			expect(SideQuests.minLevel(quest)).toBe(20)
			expect(quest.minLevel).toBe(Quests.Side.STABLE_MIN)
			expect(quest.wiki).toBe(nil) -- S97: published on the wiki
		end
		expect(#Quests.Side.byArc.stable).toBe(3)
		for _, quest in Quests.Side.byArc.stable do
			expect(quest.category).toBe("side") -- S98
		end
		expect(ride.reward.mount).toBe("mount_horse")
		expect(ride.reward.choice).toBe(nil)
		expect(Mounts.get(ride.reward.mount :: string) ~= nil).toBe(true)
	end)
end)

describe("S98 boss quests on the side machinery", function()
	it("the Meadows scout offers Grimrok's Slayer from 15", function()
		local function ids(list: { Quests.SideQuest }): { string }
			local out = {}
			for _, quest in list do
				table.insert(out, quest.id)
			end
			return out
		end
		expect(table.find(ids(SideQuests.available(quests(), 15, "scout_meadows")), "boss_grimrok") ~= nil).toBe(true)
		expect(table.find(ids(SideQuests.available(quests(), 14, "scout_meadows")), "boss_grimrok")).toBeNil()
		expect(table.find(ids(SideQuests.later(quests(), 14, "scout_meadows")), "boss_grimrok") ~= nil).toBe(true)
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
		expect(#later).toBe(2) -- S106: side_moonOil (20) too
		expect(later[1].id).toBe("side_totem")
		expect(later[2].id).toBe("side_moonOil")
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

	-- S102: the story on the same machinery (QuestLike, mainEntry, quests.main.used)
	it("the active story quest uses anchors, delivers and keeps its done look", function()
		local main = Quests.Main
		local q: any = quests(nil, main.indexOf.frostRuins - 1)
		q.main = { id = "frostRuins", progress = { 1, 0, 0 } }
		local usable = SideQuests.usableAnchors(q)
		local crest = assert(usable.tower_crest, "tower_crest")
		expect(crest.quest).toBe("frostRuins")
		expect(crest.index).toBe(2)
		expect(crest.main).toBe(true)
		-- the story entry: anchors join `used`, then the anchor is no longer usable
		local quest, entry = SideQuests.mainEntry(q)
		local frost = assert(quest, "frostRuins")
		local e = assert(entry, "entry")
		expect(e.used).toEqual({})
		local rng = Rng.new(1)
		expect(SideQuests.advance(e, frost, "use", { anchor = "tower_crest" }, rng)).toEqual({ 2 })
		expect(e.used).toEqual({ "tower_crest" })
		q.main = { id = "frostRuins", progress = e.progress, used = e.used }
		expect(SideQuests.usableAnchors(q).tower_crest).toBeNil()
		expect(SideQuests.doneAnchors(q).tower_crest).toBe("frost")
		-- handed in (and relogged without the active entry): the frost stays
		local handed: any = quests(nil, main.indexOf.frostRuins)
		expect(SideQuests.doneAnchors(handed).tower_crest).toBe("frost")
		expect(SideQuests.doneAnchors(quests(nil, main.indexOf.frostRuins - 1)).tower_crest).toBeNil()
		-- deliver in the story: talking to the alchemist hands the charm over
		local council = assert(main.get("warCouncil"))
		local c = { progress = { 0, 0 }, used = {} }
		expect(SideQuests.advance(c, council, "talk", { npc = "captain" }, rng)).toEqual({})
		expect(SideQuests.advance(c, council, "talk", { npc = "alchemist" }, rng)).toEqual({ 2 })
		expect(SideQuests.currentObjective(c, council)).toBe(1)
		-- no active story quest
		expect(SideQuests.mainEntry(quests())).toBeNil()
		local broken: any = quests()
		broken.main = { id = "nope", progress = {} }
		expect(SideQuests.mainEntry(broken)).toBeNil()
	end)

	it("requirements on story quests follow StoryProgress.isDone", function()
		local main = Quests.Main
		local q = quests(nil, main.indexOf.herbs)
		expect(SideQuests.requirementsMet(q, { requires = { "herbs" } } :: any)).toBe(true)
		expect(SideQuests.requirementsMet(q, { requires = { "frostRuins" } } :: any)).toBe(false)
		expect(SideQuests.requirementsMet(quests(nil, main.indexOf.frostRuins), { requires = { "frostRuins" } } :: any)).toBe(
			true
		)
	end)

	it("arc progress", function()
		local done, total = SideQuests.arcProgress(quests({ active = {}, done = doneUpTo("side_sheep") }), "farm")
		expect(done).toBe(3)
		expect(total).toBe(5)
	end)
end)

-- S106: the Duskwood side arcs (levels 20-44) ---------------------------------------------------------------------

local DUSK_ARCS = { "lanterns", "apiary", "cemetery", "rot", "waymarks", "ferry", "charms", "masons" }
-- NPCs of Duskwood that are not side arc NPCs (the scout and the story NPCs of S103)
local DUSK_OTHERS = { scout_duskwood = true, forester_radomir = true, ghost_oswin = true, defector_jorund = true }
DUSK_OTHERS.witch_ragna = true
local CITY_GIVERS = { sergeant = true, innkeeper = true, brother_anzelm = true, alchemist = true }
local BANNED_PL = { "Ilvar", "Morvane", "Vael", "Vaelgrath", "Cierń", "Ciernia", "pieczęci" }
local BANNED_EN = { "Ilvar", "Morvane", "Vael", "Thorn" }

local function duskQuests(): { SideQuest }
	local out = {}
	for _, arc in DUSK_ARCS do
		for _, quest in Quests.Side.byArc[arc] or {} do
			table.insert(out, quest)
		end
	end
	return out
end

local function ids(list: { SideQuest }): { string }
	local out = {}
	for _, quest in list do
		table.insert(out, quest.id)
	end
	return out
end

describe("Duskwood side arcs (S106)", function()
	local dusk = duskQuests()

	it("27 quests in eight arcs at the end of ARCS, levels 20-44, from 20, hidden from the wiki", function()
		expect(#dusk).toBe(27)
		for i, arc in DUSK_ARCS do
			expect(Quests.Side.ARCS[10 + i]).toBe(arc)
		end
		for _, quest in dusk do
			expect(quest.level >= 20 and quest.level <= 44).toBe(true)
			expect(SideQuests.minLevel(quest) >= 20).toBe(true)
			expect(quest.wiki).toBe(false)
			expect(quest.category).toBe("side")
			for _, npcId in { quest.giver, quest.turnIn } do
				local npc = assert(Npcs.get(npcId), npcId)
				expect(`{npcId} {npc.map == "duskwood" or CITY_GIVERS[npcId] == true}`).toBe(`{npcId} true`)
			end
			for _, objective in quest.objectives do
				if objective.area then
					local _, mapId = Areas.areaById(objective.area)
					expect(`{quest.id} {mapId}`).toBe(`{quest.id} duskwood`)
				end
				if objective.type == "reach" and objective.map and objective.map ~= "duskwood" then
					local cave = assert(Areas.caves.get(objective.map), objective.map)
					expect(cave.region).toBe("duskwood")
				end
			end
		end
	end)

	it("the new people of the Duskwood stand on its npc spots, hidden from the wiki", function()
		local spots = Areas.byMap.duskwood.npcSpots or {}
		local count = 0
		for _, npc in Npcs.list do
			if npc.map == "duskwood" and not DUSK_OTHERS[npc.id] then
				count += 1
				expect(npc.wiki).toBe(false)
				local found = false
				for _, spot in spots do
					found = found or (spot.x == npc.position.x and spot.z == npc.position.z)
				end
				if not found then
					error(`{npc.id} is not on an npc spot`)
				end
				for _, key in { "name", "role", "greeting", "line1", "line2", "line3", "where" } do
					expect(`{npc.id}.{key} {hasKey(`npc.{npc.id}.{key}`)}`).toBe(`{npc.id}.{key} true`)
				end
			end
		end
		expect(count).toBe(8)
	end)

	it("a side quest every two levels from 20 to 43 (with the stable arc)", function()
		for from = 20, 43, 2 do
			local found = false
			for _, quest in Quests.Side.list do
				found = found or (quest.level >= from and quest.level <= from + 1)
			end
			if not found then
				error(`no side quest for levels {from}-{from + 1}`)
			end
		end
	end)

	it("the band 20-44 holds TARGET.side of its EXP, by expToNext x weight", function()
		local scale = assert(Quests.Side.BAND_SCALE[20], "BAND_SCALE[20]")
		local total = 0
		for _, quest in Quests.Side.list do
			if quest.level >= 20 and quest.level <= 44 then
				total += quest.reward.exp
			end
		end
		local share = total / QuestBudget.bandExp(20)
		local target = QuestBudgetData.TARGET.side
		expect(share >= target - 0.003 and share <= target).toBe(true)
		for _, quest in dusk do
			local w = if quest.reward.choice then Quests.Side.WEIGHT.final else Quests.Side.WEIGHT.normal
			expect(quest.reward.exp).toBe(math.floor(Exp.expToNext(quest.level) * w * scale))
			expect(quest.reward.exp > 0).toBe(true)
			expect(
				math.floor(Exp.expToNext(quest.level) * Quests.Side.WEIGHT.final * scale) > quest.reward.exp or w > 1
			).toBe(true)
			expect(quest.reward.exp <= Exp.expToNext(quest.level) * 0.7).toBe(true)
			expect(quest.reward.gold > 0).toBe(true)
		end
	end)

	it("each quest after the first of its arc requires the one before; none requires a story quest", function()
		for _, arc in DUSK_ARCS do
			for i, quest in Quests.Side.byArc[arc] do
				if i == 1 then
					expect(quest.requires).toBeNil()
				else
					expect(quest.requires).toEqual({ Quests.Side.byArc[arc][i - 1].id })
				end
				for _, req in quest.requires or {} do
					expect(Quests.Main.get(req)).toBeNil()
				end
			end
		end
	end)

	it("the Meadows and the stable arc keep their rewards", function()
		for _, quest in Quests.Side.list do
			if quest.level < 20 then
				local share = if quest.reward.choice == "final" then 0.45 else 0.25
				expect(`{quest.id} {quest.reward.exp}`).toBe(
					`{quest.id} {math.floor(Exp.expToNext(quest.level) * share)}`
				)
			elseif quest.arc == "stable" then
				expect(quest.reward.exp).toBe(math.floor(Exp.expToNext(quest.level) * 0.1))
			end
		end
	end)

	it("no page names a secret of the story", function()
		for _, quest in dusk do
			for _, lang in { { pl, BANNED_PL }, { en, BANNED_EN } } do
				local tbl: any, banned = lang[1], lang[2]
				for key, text in tbl do
					if string.sub(key, 1, #quest.id + 7) == `quest.{quest.id}.` then
						for _, word in banned do
							if string.find(text, word, 1, true) then
								error(`{key}: {word}`)
							end
						end
					end
				end
			end
		end
	end)

	it("the lantern arc ends with the Lantern Warden's caparison", function()
		local lamp = assert(Quests.Side.get("side_lampLighter"))
		expect(lamp.reward.cosmetic).toBe("mountskin_lantern")
		expect(lamp.reward.choice).toBe("final")
		local skin = assert(Cosmetics.get("mountskin_lantern"))
		expect((skin.obtain :: any).quest).toBe("side_lampLighter")
		expect(skin.price).toBe(0)
		expect(skin.wiki).toBe(false)
	end)

	it("the innkeeper hears of the Duskwood people; the sergeant offers the oil from 20", function()
		local q = quests()
		local givers = SideQuests.giversWithWork(q, 30)
		expect(table.find(givers, "herbalist_dobrawa") ~= nil).toBe(true)
		expect(table.find(givers, "warden_zbyszko") ~= nil).toBe(true)
		expect(#SideQuests.available(q, 20, "huntress_wanda")).toBe(0)
		expect(table.find(ids(SideQuests.available(q, 20, "sergeant")), "side_moonOil") ~= nil).toBe(true)
		expect(table.find(ids(SideQuests.available(q, 19, "sergeant")), "side_moonOil")).toBeNil()
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
		expect(applied).toEqual({ 4, 5, 6, 7, 8 })
		expect(data.characters["1"].quests.side).toEqual({ active = {}, done = {} })
		expect(data.characters["2"].quests.side).toEqual({ active = {}, done = {} })
		expect(data.characters["1"].quests.main.id).toBe("boars")
		expect(data.characters["1"].quests.mainDone).toBe(8)
		expect(data.characters["1"].level).toBe(12)
	end)
end)

return nil
