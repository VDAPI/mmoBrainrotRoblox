--!strict
-- S99 (docs/DESIGN-15.md §3.3): hunting contracts 1-99 (Data/Quests/Contracts, Logic/ContractGen, Logic/Contracts)
-- and the save migration 7.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Areas = require("../src/shared/Data/Areas")
local BudgetData = require("../src/shared/Data/QuestBudget")
local Config = require("../src/shared/Config")
local ContractGen = require("../src/shared/Logic/ContractGen")
local Contracts = require("../src/shared/Logic/Contracts")
local Exp = require("../src/shared/Logic/Exp")
local Items = require("../src/shared/Data/Items")
local Npcs = require("../src/shared/Data/Npcs")
local QuestLogic = require("../src/shared/Logic/QuestLogic")
local Quests = require("../src/shared/Data/Quests")
local Rng = require("../src/shared/Logic/Rng")
local Spawns = require("../src/shared/Data/Spawns")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local Data = Quests.Contracts
local RULES = Data.RULES
local SHARE = BudgetData.TARGET.contract
local REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }

local function deepEqual(a: any, b: any): boolean
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function fits(level: number): number
	return #ContractGen.candidates(RULES, level)
end

describe("Contracts: data (S99)", function()
	it("99 contracts, one per level, on a hunting ground of a region map that covers the level", function()
		expect(#Data.list).toBe(Data.MAX_LEVEL)
		expect(Data.MAX_LEVEL).toBe(99)
		for L = 1, Data.MAX_LEVEL do
			local c: any = Data.list[L]
			expect(Data.byLevel[L]).toBe(c)
			expect(Data.forLevel(L)).toBe(c)
			expect(Data.byId[c.id]).toBe(c)
			expect(Data.get(c.id)).toBe(c)
			expect(c.id).toBe(`contract_{L}`)
			expect(c.level).toBe(L)
			expect(c.category).toBe("contract")
			expect(Quests.categoryOf(c.id)).toBe("contract")
			expect(c.givers).toBeNil()
			expect(c.giver).toBeNil()
			expect(#c.objectives).toBe(1)
			local o = c.objectives[1]
			expect(o.type).toBe("kill")
			expect(o.area).toBe(c.area)
			expect(o.monster).toBeNil()
			expect(o.region).toBeNil()
			expect(o.variant).toBeNil()
			local area, mapId = Areas.areaById(c.area)
			assert(area, `contract_{L}: unknown area {c.area}`)
			expect(mapId).toBe(c.map)
			expect(table.find(REGION_MAPS, c.map) ~= nil).toBe(true)
			expect(Areas.caves.get(c.area)).toBeNil()
			expect(area.lv[1] <= L and L <= area.lv[2]).toBe(true)
			expect(area.groups >= RULES.minGroups).toBe(true)
			expect(Npcs.get(`scout_{c.map}`) ~= nil).toBe(true)
		end
	end)

	it("every used hunting ground has at least minGroups groups and 6 monsters in Data/Spawns", function()
		local seen: { [string]: boolean } = {}
		for _, c in Data.list do
			if not seen[c.area] then
				seen[c.area] = true
				local groups, monsters = 0, 0
				for _, spawner in Spawns.byMap[c.map] or {} do
					if spawner.areaId == c.area then
						groups += 1
						monsters += spawner.count
					end
				end
				if groups < RULES.minGroups or monsters < 6 then
					error(`{c.area}: {groups} groups, {monsters} monsters`, 0)
				end
			end
		end
	end)

	it(
		"numbers: n grows 10 -> 30 -> 60, EXP is the budget share (none below expFrom), gold 20 + 4 L, items every 10th",
		function()
			local last = 0
			for L = 1, Data.MAX_LEVEL do
				local c = Data.list[L]
				local n = c.objectives[1].n
				expect(n >= last).toBe(true)
				expect(n >= 10 and n <= 60).toBe(true)
				last = n
				-- S109 (audit D3): no EXP below RULES.expFrom (the tutorial pays levels 1-2 in full)
				local exp = if L >= RULES.expFrom then math.floor(Exp.expToNext(L) * SHARE) else 0
				expect(c.reward.exp).toBe(exp)
				expect(c.reward.gold).toBe(math.floor(RULES.gold.base + RULES.gold.perLevel * L))
				expect((L < RULES.expFrom or c.reward.exp > 0) and c.reward.gold > 0).toBe(true)
				local items = c.reward.items
				if L % 10 == 0 then
					assert(items and #items > 0, `contract_{L}: milestone items`)
					for _, item in items do
						local def = Items.get(item.id)
						assert(def, `contract_{L}: unknown item {item.id}`)
						expect(def.slot).toBeNil()
						expect(item.n > 0).toBe(true)
					end
				else
					expect(items).toBeNil()
				end
			end
			expect(Data.list[1].objectives[1].n).toBe(10)
			expect(Data.list[10].objectives[1].n).toBe(20)
			expect(Data.list[20].objectives[1].n).toBe(30)
			expect(Data.list[99].objectives[1].n).toBe(60)
			expect(RULES.gold.base).toBe(20)
			expect(RULES.gold.perLevel).toBe(4)
		end
	)

	it("rotation: never the previous area when two fit, at most 2 in 5, every hunting ground used", function()
		for L = 2, Data.MAX_LEVEL do
			if fits(L) >= 2 and fits(L - 1) >= 2 then
				if Data.list[L].area == Data.list[L - 1].area then
					error(`contract_{L} repeats {Data.list[L].area}`, 0)
				end
			end
		end
		for first = 1, Data.MAX_LEVEL - 4 do
			local wide = true
			for L = first, first + 4 do
				wide = wide and fits(L) >= 3
			end
			if wide then
				local count: { [string]: number } = {}
				for L = first, first + 4 do
					local id = Data.list[L].area
					count[id] = (count[id] or 0) + 1
					if count[id] > 2 then
						error(`{id} more than twice in {first}-{first + 4}`, 0)
					end
				end
			end
		end
		local used: { [string]: boolean } = {}
		for _, c in Data.list do
			used[c.area] = true
		end
		for _, map in REGION_MAPS do
			for _, area in Areas.byMap[map].areas do
				if area.groups >= RULES.minGroups and area.lv[1] <= 99 then
					if not used[area.id] then
						error(`{area.id} is never used`, 0)
					end
				end
			end
		end
	end)

	it("the list is up to date and the generator is deterministic", function()
		local built = ContractGen.build(RULES, SHARE)
		if not deepEqual(built, Data.list) then
			error(
				"Data/Quests/Contracts is stale: run `lune run tools/contracts_gen.luau`, then tools/quest_budget.luau",
				0
			)
		end
		expect(deepEqual(ContractGen.build(RULES, SHARE), built)).toBe(true)
		for _, line in ContractGen.report(built) do
			if string.sub(line, 1, 10) == "fallbacks:" then
				expect(line).toBe("fallbacks: none")
			end
		end
	end)

	it("candidates at the region borders and killsAt interpolation", function()
		for _, L in { 20, 45, 70 } do
			local maps: { [string]: boolean } = {}
			for _, pick in ContractGen.candidates(RULES, L) do
				maps[pick.map] = true
				expect(pick.area.lv[1] <= L and L <= pick.area.lv[2]).toBe(true)
				expect(pick.fallback).toBe(false)
			end
			local count = 0
			for _ in maps do
				count += 1
			end
			expect(count).toBe(2) -- both regions cover the border level
		end
		local rules: any = table.clone(RULES)
		rules.kills = { { 1, 10 }, { 10, 20 } }
		expect(ContractGen.killsAt(rules, 5)).toBe(14)
		expect(ContractGen.killsAt(rules, 0)).toBe(10)
		expect(ContractGen.killsAt(rules, 50)).toBe(20)
		expect(ContractGen.killsAt(RULES, 99)).toBe(60)
	end)
end)

describe("Contracts: queue (Logic/Contracts)", function()
	it("stateOf survives broken saves", function()
		expect(Contracts.stateOf(nil)).toEqual({ done = 0 })
		expect(Contracts.stateOf({})).toEqual({ done = 0 })
		expect(Contracts.stateOf({ contract = "x" })).toEqual({ done = 0 })
		expect(Contracts.stateOf({ contract = { done = 3, active = { level = 7, progress = { 0 } } } })).toEqual({
			done = 3,
		})
		expect(Contracts.stateOf({ contract = { done = 3, active = { level = 4 } } })).toEqual({ done = 3 })
		local state = Contracts.stateOf({ contract = { done = 3, active = { level = 4, progress = { 2 } } } })
		expect(state).toEqual({ done = 3, active = { level = 4, progress = { 2 } } })
	end)

	it("next, canAccept, active and completion", function()
		expect((Contracts.next({ done = 0 }) :: any).id).toBe("contract_1")
		expect(Contracts.next({ done = 99 })).toBeNil()
		expect(Contracts.next({ done = 3, active = { level = 4, progress = { 0 } } })).toBeNil()
		local ok, reason = Contracts.canAccept({ done = 9 }, 9)
		expect(ok).toBe(false)
		expect(reason).toBe("level")
		ok, reason = Contracts.canAccept({ done = 9 }, 10)
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		ok, reason = Contracts.canAccept({ done = 9, active = { level = 10, progress = { 0 } } }, 50)
		expect(reason).toBe("active")
		ok, reason = Contracts.canAccept({ done = 99 }, 100)
		expect(ok).toBe(false)
		expect(reason).toBe("none")
		local n = Data.list[10].objectives[1].n
		local open = { done = 9, active = { level = 10, progress = { n - 1 } } }
		local c = Contracts.active(open)
		expect((c :: any).id).toBe("contract_10")
		expect(Contracts.isComplete(open)).toBe(false)
		expect(Contracts.isComplete({ done = 9, active = { level = 10, progress = { n } } })).toBe(true)
		expect(Contracts.isComplete({ done = 9 })).toBe(false)
	end)

	it("backlog, upcoming and the givers", function()
		expect(Contracts.backlog({ done = 3 }, 10)).toBe(7)
		expect(Contracts.backlog({ done = 3, active = { level = 4, progress = { 0 } } }, 10)).toBe(7)
		expect(Contracts.backlog({ done = 12 }, 10)).toBe(0)
		expect(Contracts.backlog({ done = 98 }, 100)).toBe(1)
		local upcoming = Contracts.upcoming({ done = 3, active = { level = 4, progress = { 0 } } }, 3)
		expect(#upcoming).toBe(3)
		expect(upcoming[1].level).toBe(5)
		expect(upcoming[3].level).toBe(7)
		expect(#Contracts.upcoming({ done = 97 }, 3)).toBe(1) -- contract 99 after the next (98)
		local meadows = Data.list[5]
		expect(meadows.map).toBe("meadows")
		expect(Contracts.giversOf(meadows)).toEqual({ "questboard", "scout_meadows" })
		expect(Contracts.isGiver("questboard", meadows)).toBe(true)
		expect(Contracts.isGiver("scout_meadows", meadows)).toBe(true)
		expect(Contracts.isGiver("scout_ashen", meadows)).toBe(false)
		expect(Contracts.allDone({ done = 99 })).toBe(true)
		expect(Contracts.allDone({ done = 98 })).toBe(false)
	end)
end)

describe("Contracts: progress", function()
	it("counts any monster of the contract's area, never another area or none", function()
		local c = Data.list[12]
		local objectives = c.objectives
		local n = objectives[1].n
		local rng = Rng.new(1)
		local progress = QuestLogic.emptyProgress(objectives)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "wolf", areaId = c.area }, rng)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "bandit", areaId = c.area }, rng)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "wolf", areaId = "meadows_rabbitfields" }, rng)
		QuestLogic.advance(progress, objectives, "kill", { monsterId = "wolf" }, rng)
		QuestLogic.advance(progress, objectives, "gather", { areaId = c.area }, rng)
		expect(progress[1]).toBe(2)
		for _ = 1, n + 5 do
			QuestLogic.advance(progress, objectives, "kill", { monsterId = "x", areaId = c.area }, rng)
		end
		expect(progress[1]).toBe(n)
		expect(QuestLogic.isComplete(progress, objectives)).toBe(true)
	end)
end)

describe("Contracts: save and migration 7", function()
	local function oldAccount(): any
		local function char(id: string, level: number, contract: any): any
			return {
				id = id,
				name = id,
				class = "Warrior",
				level = level,
				exp = 17,
				gold = 500,
				inventory = {},
				quests = {
					main = nil,
					mainDone = 3,
					daily = { day = 0, list = {}, rerolls = 0 },
					contract = contract,
					side = { active = {}, done = {} },
				},
			}
		end
		return {
			schema = 6, -- before migration 7 (S102 added 8)
			characters = {
				a = char("a", 80, { done = 0 }),
				b = char("b", 2, { done = 0 }),
				c = char("c", 50, { done = 0, active = { level = 1, progress = { 3 } } }),
				d = char("d", 40, { done = 45 }),
				e = { id = "e", name = "e", class = "Mage", level = 30 },
				f = char("f", 20, "broken"),
			},
		}
	end

	it("the template starts at contract 1", function()
		local template: any = AccountSchema.characterTemplate()
		expect(template.quests.contract).toEqual({ done = 0 })
		expect(Config.Quest.contractBacklog).toBe(3)
		expect(AccountSchema.CURRENT).toBe(10) -- S102: 8 = story progress, S132: 9 = class outfits; S134g: 10 = item effects
	end)

	it("existing characters keep 3 levels of backlog, never lose progress, get no rewards", function()
		local data = oldAccount()
		local applied = AccountSchema.migrate(data)
		expect(applied).toEqual({ 7, 8, 9, 10 }) -- S134g: 10 = item effects
		local chars = data.characters
		expect(chars.a.quests.contract).toEqual({ done = 77 })
		expect(chars.b.quests.contract).toEqual({ done = 0 })
		expect(chars.c.quests.contract).toEqual({ done = 47 }) -- the stray active entry is gone
		expect(chars.d.quests.contract).toEqual({ done = 45 })
		expect(chars.e.quests.contract).toEqual({ done = 0 })
		expect(chars.f.quests.contract).toEqual({ done = 17 })
		for _, id in { "a", "b", "c", "d", "f" } do
			expect(chars[id].exp).toBe(17)
			expect(chars[id].gold).toBe(500)
			expect(chars[id].inventory).toEqual({})
			expect(chars[id].level ~= nil).toBe(true)
		end
		-- a second migrate changes nothing
		local before = data.characters.a.quests.contract.done
		expect(AccountSchema.migrate(data)).toEqual({})
		expect(data.characters.a.quests.contract.done).toBe(before)
		-- the migration itself is idempotent
		AccountSchema._migrations[7](data, function()
			return "x"
		end)
		expect(chars.a.quests.contract).toEqual({ done = 77 })
		expect(chars.d.quests.contract).toEqual({ done = 45 })
	end)

	it("keeps an active entry that is the next contract", function()
		local data: any = {
			schema = 6,
			characters = {
				["1"] = {
					id = "1",
					level = 10,
					quests = { contract = { done = 7, active = { level = 8, progress = { 4 } } } },
				},
			},
		}
		AccountSchema.migrate(data)
		expect(data.characters["1"].quests.contract).toEqual({ done = 7, active = { level = 8, progress = { 4 } } })
		local odd: any = { schema = 6, characters = { ["1"] = "oops" } }
		AccountSchema._migrations[7](odd, function()
			return "x"
		end)
		expect(odd.characters["1"]).toBe("oops")
	end)
end)

return nil
