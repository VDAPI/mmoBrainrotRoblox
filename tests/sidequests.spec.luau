--!strict
-- S27: side quests of the Whispering Meadows: data consistency (NPCs, anchors, monsters, areas, caves, texts),
-- level continuity, the EXP budget, the rules of Logic/SideQuests and the save migration.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Areas = require("../src/shared/Data/Areas")
local AshenGen = require("../src/shared/Logic/AshenGen")
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local DuskwoodGen = require("../src/shared/Logic/DuskwoodGen")
local Exp = require("../src/shared/Logic/Exp")
local FrostpeakGen = require("../src/shared/Logic/FrostpeakGen")
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
local fs = require("@lune/fs")
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
	escort = true, -- S106: side_boneTree (Wanda leads); S107: side_ash_wells, side_ash_king; S108: side_fp_ledge, side_fp_boat
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
	-- S96: the stable arc (3 quests) ends with a mount instead of an item choice; S106: + 27 quests in 8 Duskwood arcs;
	-- S107: + 26 quests in 8 Ashen arcs; S108: + 25 quests in 8 Frost Peaks arcs
	it("has 109 quests in 34 arcs, every arc with exactly one final quest (choice or mount) at its end", function()
		expect(#Quests.Side.list).toBe(109)
		expect(#Quests.Side.ARCS).toBe(34)
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
		local nodesOf: { [string]: { [string]: boolean } } = { meadows = {}, duskwood = {}, ashen = {}, frostpeak = {} }
		for _, node in MeadowsGen.nodes() do
			nodesOf.meadows[node.kind] = true
		end
		for _, node in DuskwoodGen.nodes() do
			nodesOf.duskwood[node.kind] = true
		end
		for _, node in AshenGen.nodes() do -- S107
			nodesOf.ashen[node.kind] = true
		end
		for _, node in FrostpeakGen.nodes() do -- S108
			nodesOf.frostpeak[node.kind] = true
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
				if (objective.type == "reach" or objective.type == "escort") and objective.x then
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

	-- S108: every NPC of the Frost Peaks but the scout stands on a place of Areas/frostpeak npcSpots (position, facing)
	it("Frost Peaks NPCs stand on frostpeak npcSpots", function()
		local spots = Areas.byMap.frostpeak.npcSpots or {}
		local seen: { [string]: boolean } = {}
		for _, npc in Npcs.list do
			if npc.map == "frostpeak" and npc.id ~= "scout_frostpeak" then
				local found = false
				for _, spot in spots do
					found = found
						or (spot.x == npc.position.x and spot.z == npc.position.z and spot.facing == npc.facing)
				end
				if not found then
					error(`{npc.id} is not on an npc spot`)
				end
				seen[npc.id] = true
			end
		end
		for _, id in
			{
				"cairn_ingrid",
				"hornblower_eskil",
				"skald_ragnvald",
				"icefisher_torvi",
				"bonecarver_gunnar",
				"squire_asmund",
				"scholar_vigdis",
			}
		do
			expect(`{id} {seen[id] == true}`).toBe(`{id} true`)
		end
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

	-- S107: a quest that requires a story quest (Ghasha's and Kaspar's arcs) is taken with that story quest done
	it("can be taken once the earlier ones are done, at their minimum level", function()
		for _, quest in Quests.Side.list do
			local mainDone = 0
			for _, req in quest.requires or {} do
				mainDone = math.max(mainDone, Quests.Main.indexOf[req] or 0)
			end
			local ok, reason = SideQuests.canAccept(
				quests({ active = {}, done = doneUpTo(quest.id) }, mainDone),
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

	it("27 quests in eight arcs at the end of ARCS, levels 20-44, from 20, on the wiki (S109)", function()
		expect(#dusk).toBe(27)
		for i, arc in DUSK_ARCS do
			expect(Quests.Side.ARCS[10 + i]).toBe(arc)
		end
		for _, quest in dusk do
			expect(quest.level >= 20 and quest.level <= 44).toBe(true)
			expect(SideQuests.minLevel(quest) >= 20).toBe(true)
			expect(quest.wiki).toBeNil() -- S109: published on the wiki
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

	it("the new people of the Duskwood stand on its npc spots, on the wiki (S109)", function()
		local spots = Areas.byMap.duskwood.npcSpots or {}
		local count = 0
		for _, npc in Npcs.list do
			if npc.map == "duskwood" and not DUSK_OTHERS[npc.id] then
				count += 1
				expect(npc.wiki).toBeNil() -- S109: published on the wiki
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
		expect(skin.wiki).toBeNil() -- S109: published on the wiki
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

-- S107: the Ashen side arcs (levels 45-68) ------------------------------------------------------------------------

local ASH_ARCS = {
	"ashSalamanders",
	"ashOasis",
	"ashSpring",
	"ashProspector",
	"ashRuins",
	"ashCrags",
	"ashTombs",
	"ashCaravans",
}
-- NPCs of the Wastes that are not side arc NPCs of S107 (the scout and the story NPCs of S104)
local ASH_OTHERS = { scout_ashen = true, runesmith_brokk = true, shaman_ghasha = true, hermit_kaspar = true }
local ASH_NEW =
	{ "waterkeeper_orren", "prospector_dragan", "wyvernhunter_wieslawa", "tombwarden_ezra", "wagoner_bogna" }
local ASH_CITY = { alchemist = true, innkeeper = true, blacksmith = true, brother_anzelm = true }
local ASH_BANNED_PL = { "Ilvar", "Morvane", "Vael", "Cierń", "Ciernia" }
local ASH_BANNED_EN = { "Ilvar", "Morvane", "Vael", "Thorn" }

local function ashQuests(): { SideQuest }
	local out = {}
	for _, arc in ASH_ARCS do
		for _, quest in Quests.Side.byArc[arc] or {} do
			table.insert(out, quest)
		end
	end
	return out
end

-- The map an objective of an Ashen quest points at (anchor, area or the cave of a `reach`), nil when none.
local function objectiveMap(objective: any): string?
	if objective.type == "use" then
		local list: { string } = objective.anchors or { objective.anchor }
		local _, mapId = Areas.anchorById(list[1])
		return mapId
	end
	if objective.area then
		local _, mapId = Areas.areaById(objective.area)
		return mapId
	end
	if (objective.type == "reach" or objective.type == "escort") and objective.map then
		return objective.map
	end
	return nil
end

describe("Ashen side arcs (S107)", function()
	local ash = ashQuests()

	it("26 quests side_ash_* in eight arcs at the end of ARCS, levels 45-68, on the wiki (S109)", function()
		expect(#ash).toBe(26)
		-- S108: the Frost Peaks arcs follow them at the end of ARCS
		local arcs = Quests.Side.ARCS
		local first = assert(table.find(arcs, ASH_ARCS[1]), "ashen arcs")
		expect(first).toBe(#arcs - #ASH_ARCS - 8 + 1)
		for i, arc in ASH_ARCS do
			expect(arcs[first + i - 1]).toBe(arc)
		end
		for _, quest in ash do
			expect(string.sub(quest.id, 1, 9)).toBe("side_ash_")
			expect(quest.level >= 45 and quest.level <= 68).toBe(true)
			expect(quest.wiki).toBeNil() -- S109: published on the wiki
			expect(quest.category).toBe("side")
			expect(quest.reward.items).toBeNil()
			expect(quest.reward.mount).toBeNil()
			for _, npcId in { quest.giver, quest.turnIn } do
				local npc = assert(Npcs.get(npcId), npcId)
				expect(`{npcId} {npc.map == "ashen" or ASH_CITY[npcId] == true}`).toBe(`{npcId} true`)
			end
			local reachMap: string? = nil
			for _, objective in quest.objectives do
				local mapId = objectiveMap(objective)
				if mapId and mapId ~= "ashen" then
					local cave = assert(Areas.caves.get(mapId), mapId)
					expect(cave.region).toBe("ashen")
					reachMap = mapId
				end
			end
			if quest.id == "side_ash_salve" or quest.id == "side_ash_cask" then
				expect(quest.where).toBeNil()
			else
				local where = assert(quest.where, quest.id)
				expect(`{quest.id} {where.map == "ashen" or where.map == reachMap}`).toBe(`{quest.id} true`)
			end
		end
		for _, other in Quests.Side.list do
			if string.sub(other.id, 1, 9) == "side_ash_" then
				expect(table.find(ASH_ARCS, other.arc) ~= nil).toBe(true)
			end
		end
	end)

	it(
		"every objective points at the Wastes: anchors, areas, nodes, the mine's elites, the places of the sites",
		function()
			local sites = assert(Areas.byMap.ashen.sites, "ashen sites")
			for _, quest in ash do
				for _, objective in quest.objectives do
					local mapId = objectiveMap(objective)
					if objective.type == "use" or objective.area then
						expect(`{quest.id} {mapId}`).toBe(`{quest.id} ashen`)
					end
				end
			end
			-- the reach of the Avenue and the escort to the Buried King are the sites themselves (Areas/ashen SITES)
			local avenue = assert(Quests.Side.get("side_ash_avenue")).objectives[1]
			expect(avenue.type).toBe("reach")
			expect(avenue.x).toBe(sites.kingsAvenue.x)
			expect(avenue.z).toBe(sites.kingsAvenue.z)
			expect(avenue.place).toBe("place.kingsAvenue")
			local king = assert(Quests.Side.get("side_ash_king")).objectives[1]
			expect(king.type).toBe("escort")
			expect(king.x).toBe(sites.buriedKing.x)
			expect(king.z).toBe(sites.buriedKing.z)
			expect(king.place).toBe("place.buriedKing")
			local wells = assert(Quests.Side.get("side_ash_wells")).objectives[1]
			expect(wells.type).toBe("escort")
			expect(wells.place).toBe("place.strandedBoat")
		end
	)

	it(
		"areas of the kill and collect objectives fit the quest's level; a quest every two levels from 45 to 68",
		function()
			local slack = Config.SideQuest.levelSlack
			for _, quest in ash do
				for _, objective in quest.objectives do
					if objective.area then
						local area = assert(Areas.areaById(objective.area), objective.area)
						local fits = area.lv[1] <= quest.level + 3 and area.lv[2] >= quest.level - slack
						expect(`{quest.id} {objective.area} {fits}`).toBe(`{quest.id} {objective.area} true`)
					end
				end
			end
			for from = 45, 67, 2 do
				local found = false
				for _, quest in ash do
					found = found or (quest.level >= from and quest.level <= from + 1)
				end
				if not found then
					error(`no Ashen side quest for levels {from}-{from + 1}`)
				end
			end
		end
	)

	it("each quest after the first of its arc requires the one before; Ghasha's and Kaspar's arcs the story", function()
		local STORY = { ashSpring = "warcampCages", ashRuins = "burntTemple" }
		for _, arc in ASH_ARCS do
			for i, quest in Quests.Side.byArc[arc] do
				if i == 1 then
					if STORY[arc] then
						expect(quest.requires).toEqual({ STORY[arc] })
						expect(Quests.Main.get(STORY[arc]) ~= nil).toBe(true)
					else
						expect(quest.requires).toBeNil()
					end
				else
					expect(quest.requires).toEqual({ Quests.Side.byArc[arc][i - 1].id })
					expect(quest.level >= Quests.Side.byArc[arc][i - 1].level).toBe(true)
				end
			end
		end
		local rite = assert(Quests.Side.get("side_ash_rite"))
		local cages = Quests.Main.indexOf.warcampCages
		expect((SideQuests.canAccept(quests(nil, cages), SideQuests.minLevel(rite), rite))).toBe(true)
		local _, reason = SideQuests.canAccept(quests(nil, cages - 1), SideQuests.minLevel(rite), rite)
		expect(reason).toBe("requires")
		local chimneys = assert(Quests.Side.get("side_ash_chimneys"))
		local temple = Quests.Main.indexOf.burntTemple
		expect((SideQuests.canAccept(quests(nil, temple), SideQuests.minLevel(chimneys), chimneys))).toBe(true)
		_, reason = SideQuests.canAccept(quests(nil, temple - 1), SideQuests.minLevel(chimneys), chimneys)
		expect(reason).toBe("requires")
	end)

	it("the band 45-69 holds TARGET.side of its EXP, by expToNext x weight; gold of the banded quests", function()
		local scale = assert(Quests.Side.BAND_SCALE[45], "BAND_SCALE[45]")
		local total, need = 0, 0
		for _, quest in Quests.Side.list do
			if quest.level >= 45 and quest.level <= 69 and quest.category == "side" then
				total += quest.reward.exp
			end
		end
		for level = 45, 69 do
			need += Exp.expToNext(level)
		end
		local share = total / need
		local target = QuestBudgetData.TARGET.side
		expect(share >= target - 0.003 and share <= target).toBe(true)
		expect(share >= 0.05 and share <= 0.07).toBe(true)
		expect(math.abs(QuestBudget.bandExp(45) - need) < 1).toBe(true)
		for _, quest in ash do
			local w = if quest.reward.choice then Quests.Side.WEIGHT.final else Quests.Side.WEIGHT.normal
			expect(quest.reward.exp).toBe(math.floor(Exp.expToNext(quest.level) * w * scale))
			expect(quest.reward.exp > 0 and quest.reward.exp <= Exp.expToNext(quest.level) * 0.7).toBe(true)
			expect(quest.reward.gold > 0).toBe(true)
			expect(quest.reward.gold).toBe(
				math.floor(math.floor((60 + quest.level * 45) * 0.5) * Quests.Side.GOLD_FROM_20)
			)
		end
	end)

	it("the five new people of the Wastes stand on its npc spots, talk and are on the wiki (S109)", function()
		local spots = Areas.byMap.ashen.npcSpots or {}
		local count, onSpots = 0, 0
		for _, npc in Npcs.list do
			if npc.map == "ashen" and npc.id ~= "scout_ashen" then
				onSpots += 1
				local found = false
				for _, spot in spots do
					found = found or (spot.x == npc.position.x and spot.z == npc.position.z)
				end
				if not found then
					error(`{npc.id} is not on an npc spot`)
				end
				if not ASH_OTHERS[npc.id] then
					count += 1
					expect(table.find(ASH_NEW, npc.id) ~= nil).toBe(true)
				end
			end
		end
		expect(onSpots).toBe(3 + 5)
		expect(count).toBe(5)
		for _, id in ASH_NEW do
			local npc = assert(Npcs.get(id), id)
			expect(npc.services).toEqual({ "talk" })
			expect(npc.lines).toBe(3)
			expect(npc.wiki).toBeNil() -- S109: published on the wiki
			expect(npc.showFrom).toBeNil()
			for _, key in { "name", "role", "greeting", "line1", "line2", "line3", "where" } do
				expect(`{id}.{key} {hasKey(`npc.{id}.{key}`)}`).toBe(`{id}.{key} true`)
			end
		end
		for _, quest in ash do
			expect(`{quest.giver} {hasKey(`npc.{quest.giver}.where`)}`).toBe(`{quest.giver} true`)
		end
	end)

	it(
		"rules on the Ashen quests: three anchors, two use objectives and an escort, a place, an area, a deliver",
		function()
			local rng = Rng.new(3)
			-- side_ash_glands: every cairn counts once, the skull of the next quest does not
			local glands = assert(Quests.Side.get("side_ash_glands"))
			local g = SideQuests.newEntry(glands)
			expect(SideQuests.advance(g, glands, "use", { anchor = "ash_cairn_1" }, rng)).toEqual({ 2 })
			expect(#SideQuests.advance(g, glands, "use", { anchor = "ash_cairn_1" }, rng)).toBe(0)
			expect(#SideQuests.advance(g, glands, "use", { anchor = "ash_hyena_skull" }, rng)).toBe(0)
			SideQuests.advance(g, glands, "use", { anchor = "ash_cairn_2" }, rng)
			SideQuests.advance(g, glands, "use", { anchor = "ash_cairn_3" }, rng)
			g.progress[1] = 6
			expect(SideQuests.isComplete(g, glands)).toBe(true)
			local gq = quests({ active = { side_ash_glands = g }, done = {} })
			expect(SideQuests.doneAnchors(gq).ash_cairn_2).toBe("cairn")
			-- side_ash_wells: Orren's escort is objective 1, the boat objective 2, the wells objective 3
			local wells = assert(Quests.Side.get("side_ash_wells"))
			local w = SideQuests.newEntry(wells)
			expect(SideQuests.advance(w, wells, "escort", { npc = "waterkeeper_orren" }, rng)).toEqual({ 1 })
			expect(SideQuests.advance(w, wells, "use", { anchor = "ash_stranded_boat" }, rng)).toEqual({ 2 })
			expect(SideQuests.advance(w, wells, "use", { anchor = "ash_well_1" }, rng)).toEqual({ 3 })
			-- side_ash_avenue: the Avenue of Kings needs the position
			local avenue = assert(Quests.Side.get("side_ash_avenue"))
			local a = SideQuests.newEntry(avenue)
			expect(#SideQuests.advance(a, avenue, "reach", { map = "ashen", x = 220, z = 0 }, rng)).toBe(0)
			expect(#SideQuests.advance(a, avenue, "reach", { map = "ashen", x = 220, z = -153 }, rng)).toBe(1)
			-- side_ash_mirror: basilisks of the Crags do not count, those of the Ash Road do
			local mirror = assert(Quests.Side.get("side_ash_mirror"))
			local m = SideQuests.newEntry(mirror)
			expect(#SideQuests.advance(m, mirror, "kill", { monsterId = "basilisk", areaId = "ashen_crags" }, rng)).toBe(
				0
			)
			expect(#SideQuests.advance(m, mirror, "kill", { monsterId = "basilisk", areaId = "ashen_ashroad" }, rng)).toBe(
				1
			)
			-- side_ash_names: the list goes to Brother Anzelm, not back to Kaspar
			local names = assert(Quests.Side.get("side_ash_names"))
			local n = SideQuests.newEntry(names)
			expect(#SideQuests.advance(n, names, "talk", { npc = "hermit_kaspar" }, rng)).toBe(0)
			expect(SideQuests.advance(n, names, "talk", { npc = "brother_anzelm" }, rng)).toEqual({ 2 })
			-- marks: "!" at Orren at 47 once the cask is handed in, "?" once the wells are done
			local done = { side_ash_cask = true }
			expect(NpcMarks.all(quests({ active = {}, done = done }), 47).waterkeeper_orren).toBe("available")
			local entry = SideQuests.newEntry(wells)
			for i, objective in wells.objectives do
				entry.progress[i] = objective.n
			end
			local q = quests({ active = { side_ash_wells = entry }, done = done })
			expect(NpcMarks.all(q, 47).waterkeeper_orren).toBe("turnIn")
		end
	)

	it("the innkeeper hears of the Ashen people; the alchemist offers the salve from 43", function()
		local q = quests()
		local givers = SideQuests.giversWithWork(q, 62)
		expect(table.find(givers, "wyvernhunter_wieslawa") ~= nil).toBe(true)
		expect(table.find(givers, "wagoner_bogna") ~= nil).toBe(true)
		expect(table.find(ids(SideQuests.available(q, 43, "alchemist")), "side_ash_salve") ~= nil).toBe(true)
		expect(table.find(ids(SideQuests.available(q, 42, "alchemist")), "side_ash_salve")).toBeNil()
		expect(#SideQuests.available(q, 66, "shaman_ghasha")).toBe(0) -- warcampCages not done
	end)

	it("no page names a secret of the story", function()
		for _, quest in ash do
			for _, lang in { { pl, ASH_BANNED_PL }, { en, ASH_BANNED_EN } } do
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

	-- F3: an anchor effect without a client builder would silently draw nothing
	it("every anchor effect of the data has a builder in QuestAnchorController", function()
		local source = fs.readFile("src/client/Controllers/QuestAnchorController.luau")
		for key in Quests.Side.FX do
			if not string.find(source, `\n\t{key} = function(model`, 1, true) then
				error(`no builder for the anchor effect {key}`)
			end
		end
		for _, quest in Quests.Side.list do
			for _, objective in quest.objectives do
				if objective.type == "use" then
					expect(Quests.Side.FX[objective.fx :: string]).toBe(true)
				end
			end
		end
		for _, key in { "cairn", "water", "incense", "drum", "mirror" } do
			expect(Quests.Side.FX[key]).toBe(true)
		end
	end)
end)

-- S108: the Frost Peaks side arcs (levels 70-99) ------------------------------------------------------------------

local FP_ARCS = { "fp_cairn", "fp_trappers", "fp_horn", "fp_saga", "fp_icefish", "fp_bones", "fp_squire", "fp_wyrms" }
local FP_NEW = {
	"cairn_ingrid",
	"hornblower_eskil",
	"skald_ragnvald",
	"icefisher_torvi",
	"bonecarver_gunnar",
	"squire_asmund",
	"scholar_vigdis",
}
-- NPCs of the arcs that are not new (S105's Sigrun, the scout, Brother Anzelm in the city)
local FP_OLD = { trapper_sigrun = true, scout_frostpeak = true, brother_anzelm = true }
local FP_STORY = { fp_trappers = "trappersCamp", fp_squire = "iceWatch", fp_wyrms = "dragonTemple" }
local FP_BANNED_PL = { "Ilvar", "Morvane", "Vael", "Cierń", "Ciernia", "serce", "Serce" }
local FP_BANNED_EN = { "Ilvar", "Morvane", "Vael", "Thorn", "heart", "Heart" }

local function fpQuests(): { SideQuest }
	local out = {}
	for _, quest in Quests.Side.list do
		if string.sub(quest.id, 1, 8) == "side_fp_" then
			table.insert(out, quest)
		end
	end
	return out
end

describe("Frost Peaks side arcs (S108)", function()
	local fp = fpQuests()

	it("1: eight fp_ arcs at the end of ARCS, 25 quests side_fp_*, 3-4 an arc, levels rising within 70-99", function()
		expect(#fp).toBe(25)
		local arcs = Quests.Side.ARCS
		for i, arc in FP_ARCS do
			expect(arcs[#arcs - #FP_ARCS + i]).toBe(arc)
			expect(hasKey(`quest.arc.{arc}`)).toBe(true)
			local list = assert(Quests.Side.byArc[arc], arc)
			expect(#list >= 3 and #list <= 4).toBe(true)
			for k, quest in list do
				expect(string.sub(quest.id, 1, 8)).toBe("side_fp_")
				if k > 1 then
					expect(quest.level >= list[k - 1].level).toBe(true)
				end
				expect(quest.reward.choice == "final").toBe(k == #list)
			end
		end
		for _, quest in fp do
			expect(table.find(FP_ARCS, quest.arc) ~= nil).toBe(true)
			expect(quest.level >= 70 and quest.level <= 99).toBe(true)
		end
		local count = 0
		for _, arc in arcs do
			if string.sub(arc, 1, 3) == "fp_" then
				count += 1
			end
		end
		expect(count).toBe(8)
	end)

	it("2-3: a quest every two levels from 70 to 99, none taken before 70", function()
		for from = 70, 98, 2 do
			local found = false
			for _, quest in fp do
				found = found or (quest.level >= from and quest.level <= from + 1)
			end
			if not found then
				error(`no Frost Peaks side quest for levels {from}-{from + 1}`)
			end
		end
		for _, quest in fp do
			expect(`{quest.id} {SideQuests.minLevel(quest) >= 70}`).toBe(`{quest.id} true`)
		end
		expect(assert(Quests.Side.get("side_fp_flask")).minLevel).toBe(70)
		expect(assert(Quests.Side.get("side_fp_ribbons")).minLevel).toBe(70)
	end)

	it("4: on the wiki (S109), side, with gold and EXP of at most 0.7 of the level", function()
		for _, quest in fp do
			expect(quest.wiki).toBeNil() -- S109: published on the wiki
			expect(quest.category).toBe("side")
			expect(quest.reward.gold > 0).toBe(true)
			expect(quest.reward.exp > 0 and quest.reward.exp <= Exp.expToNext(quest.level) * 0.7).toBe(true)
			expect(quest.reward.items).toBeNil()
			expect(quest.reward.mount).toBeNil()
			expect(quest.reward.gold).toBe(
				math.floor(math.floor((60 + quest.level * 45) * 0.5) * Quests.Side.GOLD_FROM_20)
			)
		end
	end)

	it("5: the band 70-99 holds TARGET.side of its EXP, by expToNext x weight (the arc's end 1.8)", function()
		local scale = assert(Quests.Side.BAND_SCALE[70], "BAND_SCALE[70]")
		local total = 0
		for _, quest in Quests.Side.list do
			if quest.level >= 70 and quest.level <= 99 and quest.category == "side" then
				total += quest.reward.exp
			end
		end
		local share = total / QuestBudget.bandExp(70)
		local target = QuestBudgetData.TARGET.side
		expect(share >= target - 0.003 and share <= target).toBe(true)
		for _, quest in fp do
			local w = if quest.reward.choice then Quests.Side.WEIGHT.final else Quests.Side.WEIGHT.normal
			expect(quest.reward.exp).toBe(math.floor(Exp.expToNext(quest.level) * w * scale))
		end
		local tusks = assert(Quests.Side.get("side_fp_tusks"))
		local boat = assert(Quests.Side.get("side_fp_boat"))
		expect(tusks.level).toBe(boat.level)
		expect(tusks.reward.exp).toBe(boat.reward.exp)
		local hoard = assert(Quests.Side.get("side_fp_hoard"))
		local stampede = assert(Quests.Side.get("side_fp_stampede"))
		expect(hoard.level).toBe(stampede.level)
		expect(math.abs(hoard.reward.exp / stampede.reward.exp - 1.8) <= 0.01).toBe(true)
	end)

	it("6: kills and drops in areas of the Peaks whose monsters fit the quest's level (+-6)", function()
		for _, quest in fp do
			for _, objective in quest.objectives do
				if (objective.type == "kill" or objective.type == "collect") and objective.area then
					local area, mapId = Areas.areaById(objective.area)
					expect(`{quest.id} {mapId}`).toBe(`{quest.id} frostpeak`)
					local monster = objective.monster :: string
					expect(table.find(assert(area).kinds, monster) ~= nil).toBe(true)
					local levels = assert(Monsters.get(monster)).levels
					local fits = levels.min <= quest.level + 6 and levels.max >= quest.level - 6
					expect(`{quest.id} {monster} {fits}`).toBe(`{quest.id} {monster} true`)
				end
				if objective.type == "reach" and objective.map and objective.map ~= "frostpeak" then
					expect(assert(Areas.caves.get(objective.map)).region).toBe("frostpeak")
				end
			end
		end
	end)

	it("7: every anchor of a use objective lies on the Peaks and serves one quest only", function()
		local used: { [string]: string } = {}
		for _, quest in fp do
			for _, objective in quest.objectives do
				if objective.type == "use" then
					for _, id in objective.anchors or { objective.anchor :: string } do
						local anchor, mapId = Areas.anchorById(id)
						expect(`{id} {anchor ~= nil and mapId == "frostpeak"}`).toBe(`{id} true`)
						expect(`{id} {used[id]}`).toBe(`{id} nil`)
						used[id] = quest.id
					end
				end
			end
		end
		local n = 0
		for _ in used do
			n += 1
		end
		expect(n).toBe(25)
	end)

	it("8: givers and turn-in NPCs: the seven new people, Sigrun, the scout and Brother Anzelm", function()
		for _, quest in fp do
			for _, npcId in { quest.giver, quest.turnIn } do
				local npc = assert(Npcs.get(npcId), npcId)
				local known = table.find(FP_NEW, npcId) ~= nil or FP_OLD[npcId] == true
				expect(`{npcId} {known}`).toBe(`{npcId} true`)
				expect(npc.map == "frostpeak" or npcId == "brother_anzelm").toBe(true)
			end
			expect(`{quest.giver} {hasKey(`npc.{quest.giver}.where`)}`).toBe(`{quest.giver} true`)
		end
		for _, id in FP_NEW do
			local npc = assert(Npcs.get(id), id)
			expect(npc.services).toEqual({ "talk" })
			expect(npc.lines).toBe(3)
			expect(npc.wiki).toBeNil() -- S109: published on the wiki
			for _, key in { "name", "role", "greeting", "line1", "line2", "line3", "where" } do
				expect(`{id}.{key} {hasKey(`npc.{id}.{key}`)}`).toBe(`{id}.{key} true`)
			end
		end
		expect(assert(Quests.Side.get("side_fp_letter")).giver).toBe("brother_anzelm")
		expect(assert(Quests.Side.get("side_fp_treatise")).turnIn).toBe("brother_anzelm")
		expect(assert(Quests.Side.get("side_fp_flask")).giver).toBe("scout_frostpeak")
	end)

	it(
		"9: the arcs of Sigrun, Asmund and Vigdis wait for their story quest of S105; the rest chain in the arc",
		function()
			for _, arc in FP_ARCS do
				for i, quest in Quests.Side.byArc[arc] do
					if i == 1 then
						if FP_STORY[arc] then
							expect(quest.requires).toEqual({ FP_STORY[arc] })
						else
							expect(quest.requires).toBeNil()
						end
					elseif quest.id == "side_fp_ledge" then
						expect(quest.requires).toEqual({ "side_fp_snares", "iceGrotto" })
					else
						expect(quest.requires).toEqual({ Quests.Side.byArc[arc][i - 1].id })
					end
				end
			end
			for _, id in { "trappersCamp", "iceGrotto", "iceWatch", "dragonTemple" } do
				expect(`{id} {Quests.Main.indexOf[id] ~= nil}`).toBe(`{id} true`)
			end
			local snares = assert(Quests.Side.get("side_fp_snares"))
			local camp = Quests.Main.indexOf.trappersCamp
			expect((SideQuests.canAccept(quests(nil, camp), SideQuests.minLevel(snares), snares))).toBe(true)
			local _, reason = SideQuests.canAccept(quests(nil, camp - 1), SideQuests.minLevel(snares), snares)
			expect(reason).toBe("requires")
			-- the knife waits for the Grotto too
			local ledge = assert(Quests.Side.get("side_fp_ledge"))
			local grotto = Quests.Main.indexOf.iceGrotto
			local done = { side_fp_snares = true }
			expect((SideQuests.canAccept(quests({ active = {}, done = done }, grotto), 76, ledge))).toBe(true)
			_, reason = SideQuests.canAccept(quests({ active = {}, done = done }, grotto - 1), 76, ledge)
			expect(reason).toBe("requires")
		end
	)

	it("10: the twelve new anchor effects are in the data (each has a builder: the S107 case above)", function()
		for _, key in
			{
				"cairnOffering",
				"ribbons",
				"snare",
				"sledgeRunner",
				"dugHorn",
				"toppled",
				"runeRubbing",
				"runeCarving",
				"iceChipped",
				"tuskPost",
				"juniper",
				"eggShards",
			}
		do
			expect(Quests.Side.FX[key]).toBe(true)
		end
		local gate = assert(Quests.Side.get("side_fp_spurs")).objectives[1]
		expect(gate.anchor).toBe("fp_watch_gate")
		expect(gate.fx).toBe("candles")
	end)

	it(
		"reach, escort and hint points: the Hall of Thrones, the wyrm's bones, the boat and named places on dry ground",
		function()
			local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
			local T = assert(RegionTerrain.get("frostpeak"))
			local sites = assert(Areas.byMap.frostpeak.sites, "frostpeak sites")
			local thrones = assert(Quests.Side.get("side_fp_thrones")).objectives[1]
			expect(thrones.type).toBe("reach")
			expect(thrones.x).toBe(sites.thrones.x)
			expect(thrones.z).toBe(sites.thrones.z)
			expect(thrones.place).toBe("place.thrones")
			local bones = assert(Quests.Side.get("side_fp_bonetrail")).objectives[1]
			expect(bones.x).toBe(sites.wyrmBones.x)
			expect(bones.z).toBe(sites.wyrmBones.z)
			expect(bones.place).toBe("place.wyrmBones")
			expect(assert(Quests.Side.get("side_fp_ledge")).objectives[1].place).toBe("place.leopardLedge")
			expect(assert(Quests.Side.get("side_fp_boat")).objectives[1].place).toBe("place.frozenBoat")
			local hints = 0
			for _, quest in fp do
				for _, option in (if quest.choices then quest.choices.options else {}) :: { any } do
					local effect = option.effect
					if effect and effect.kind == "hint" then
						hints += 1
						expect(effect.map).toBe("frostpeak")
						expect(hasKey(effect.place)).toBe(true)
						local tag = `{quest.id} {option.id}`
						expect(`{tag} {T.isWater(effect.x, effect.z) or T.mountainAt(effect.x, effect.z)}`).toBe(
							`{tag} false`
						)
					end
				end
			end
			expect(hints).toBe(7)
		end
	)

	it("rules on the Frost Peaks quests: an escort, three snares, a reach, a deliver at the city", function()
		local rng = Rng.new(8)
		-- side_fp_ledge: Sigrun's escort is objective 1, the knife objective 2
		local ledge = assert(Quests.Side.get("side_fp_ledge"))
		local l = SideQuests.newEntry(ledge)
		expect(#SideQuests.advance(l, ledge, "escort", { npc = "icefisher_torvi" }, rng)).toBe(0)
		expect(SideQuests.advance(l, ledge, "escort", { npc = "trapper_sigrun" }, rng)).toEqual({ 1 })
		-- side_fp_snares: each snare once
		local snares = assert(Quests.Side.get("side_fp_snares"))
		local s = SideQuests.newEntry(snares)
		expect(SideQuests.advance(s, snares, "use", { anchor = "fp_snare_1" }, rng)).toEqual({ 1 })
		expect(#SideQuests.advance(s, snares, "use", { anchor = "fp_snare_1" }, rng)).toBe(0)
		expect(#SideQuests.advance(s, snares, "use", { anchor = "fp_trapper_sledge" }, rng)).toBe(0)
		-- side_fp_thrones: the Hall of Thrones needs the position
		local thrones = assert(Quests.Side.get("side_fp_thrones"))
		local t = SideQuests.newEntry(thrones)
		expect(#SideQuests.advance(t, thrones, "reach", { map = "frostpeak", x = 100, z = -32 }, rng)).toBe(0)
		expect(#SideQuests.advance(t, thrones, "reach", { map = "frostpeak", x = 196, z = 110 }, rng)).toBe(1)
		-- side_fp_stampede: mammoths of the lake do not count, those of the tundra do
		local stampede = assert(Quests.Side.get("side_fp_stampede"))
		local m = SideQuests.newEntry(stampede)
		expect(#SideQuests.advance(m, stampede, "kill", { monsterId = "iceMammoth", areaId = "frostpeak_lake" }, rng)).toBe(
			0
		)
		expect(#SideQuests.advance(m, stampede, "kill", { monsterId = "iceMammoth", areaId = "frostpeak_tundra" }, rng)).toBe(
			1
		)
		-- the marks: "!" at Ingrid at 71 once the flask is handed in, "?" at Brother Anzelm with the treatise done
		local done = { side_fp_flask = true }
		expect(NpcMarks.all(quests({ active = {}, done = done }), 71).cairn_ingrid).toBe("available")
		local treatise = assert(Quests.Side.get("side_fp_treatise"))
		local entry = SideQuests.newEntry(treatise)
		for i, objective in treatise.objectives do
			entry.progress[i] = objective.n
		end
		local q = quests({ active = { side_fp_treatise = entry }, done = {} })
		expect(NpcMarks.all(q, 99).brother_anzelm).toBe("turnIn")
	end)

	it("the innkeeper hears of the Peaks people; the scout offers the flask from 70, not before", function()
		local q = quests()
		local givers = SideQuests.giversWithWork(q, 85)
		expect(table.find(givers, "skald_ragnvald") ~= nil).toBe(true)
		expect(table.find(givers, "icefisher_torvi") ~= nil).toBe(true)
		expect(table.find(ids(SideQuests.available(q, 70, "scout_frostpeak")), "side_fp_flask") ~= nil).toBe(true)
		expect(table.find(ids(SideQuests.available(q, 69, "scout_frostpeak")), "side_fp_flask")).toBeNil()
		expect(#SideQuests.available(q, 90, "squire_asmund")).toBe(0) -- iceWatch not done
	end)

	it("no page names a secret of the story (Ilvar, the Thorn, the dragon's heart)", function()
		for _, quest in fp do
			for _, lang in { { pl, FP_BANNED_PL }, { en, FP_BANNED_EN } } do
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
		expect(applied).toEqual({ 4, 5, 6, 7, 8, 9, 10, 11 }) -- S134g: 10 = item effects; S134k: 11 = contracts
		expect(data.characters["1"].quests.side).toEqual({ active = {}, done = {} })
		expect(data.characters["2"].quests.side).toEqual({ active = {}, done = {} })
		expect(data.characters["1"].quests.main.id).toBe("boars")
		expect(data.characters["1"].quests.mainDone).toBe(8)
		expect(data.characters["1"].level).toBe(12)
	end)
end)

return nil
