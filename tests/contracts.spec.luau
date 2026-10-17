--!strict
-- S99 (docs/DESIGN-15.md §3.3): hunting contracts 1-99 (Data/Quests/Contracts, Logic/ContractGen, Logic/Contracts)
-- and the save migration 7. S134k: the target is one monster kind of the hunting ground, several contracts active at
-- once (Logic/Contracts state, credit, hand-in out of order), Hunter's Marks and the save migration 11.

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
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

-- S134k: a state from a short description (the rest empty)
local function state(spec: any): Contracts.State
	return Contracts.stateOf({ contract = spec })
end

local function levelsOf(list: { any }): { number }
	local out = {}
	for _, item in list do
		table.insert(out, if item.contract then item.contract.level else item.level)
	end
	return out
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
			-- S134k: the target names a monster kind (checked below); no region or variant
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
		"numbers: EXP is the budget share (none below expFrom), gold 20 + 4 L, items every 10th; S134k: the same EXP and gold as S99 for every level",
		function()
			for L = 1, Data.MAX_LEVEL do
				local c = Data.list[L]
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
			-- S134k: the kill anchors of S99 stay (the kills of the kind come from them and the kind's share)
			expect(ContractGen.killsAt(RULES, 1)).toBe(10)
			expect(ContractGen.killsAt(RULES, 10)).toBe(20)
			expect(ContractGen.killsAt(RULES, 20)).toBe(30)
			expect(ContractGen.killsAt(RULES, 99)).toBe(60)
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

describe("Contracts: monster kinds and marks (S134k)", function()
	it(
		"every target is a normal kind of its hunting ground that spawns there, never an Elite or an Elite II",
		function()
			for _, c in Data.list do
				local o = c.objectives[1]
				local area = Areas.areaById(c.area) :: Areas.Area
				assert(o.monster, `{c.id}: no monster kind`)
				if not table.find(area.kinds, o.monster) then
					error(`{c.id}: {o.monster} is not a kind of {c.area}`, 0)
				end
				local shares = AreaSpawns.kindShares(Spawns.byMap[c.map], c.area)
				expect((shares[o.monster] or 0) > 0).toBe(true)
				-- Elites / Elite IIs of the caves and hideouts are other kinds
				for _, cave in Areas.caves.list do
					for _, id in cave.elites do
						expect(o.monster ~= id or table.find(area.kinds, id) ~= nil).toBe(true)
					end
				end
			end
		end
	)

	it("never the same kind twice in a row when the hunting ground has another", function()
		for L = 2, Data.MAX_LEVEL do
			local c, prev = Data.list[L], Data.list[L - 1]
			local area = Areas.areaById(c.area) :: Areas.Area
			local others = ContractGen.kindsOf(c.map, area, RULES.minKindShare)
			if #others > 1 and c.objectives[1].monster == prev.objectives[1].monster then
				error(`contract_{L} repeats {c.objectives[1].monster}`, 0)
			end
		end
	end)

	it("kills of the kind: max(minKindKills, round(killsAt x share)) and never under minKindKills", function()
		for L, pick in ContractGen.picks(RULES) do
			local c = Data.list[L]
			local n = c.objectives[1].n
			expect(n).toBe(ContractGen.kindKills(RULES, c.level, pick.share :: number))
			expect(n >= RULES.minKindKills).toBe(true)
		end
		-- S134k: the time of a contract stays within 1.2 x the S99 one from level 4 (kills of the area for n of the kind)
		for L, pick in ContractGen.picks(RULES) do
			if L >= 4 then
				local n = Data.list[L].objectives[1].n
				local ratio = n / (pick.share :: number) / ContractGen.killsAt(RULES, L)
				if ratio > 1.2 then
					error(`contract_{L}: {string.format("%.2f", ratio)} x the S99 kills`, 0)
				end
			end
		end
	end)

	it("Hunter's Marks: the reward is marksFor(L) = base + floor(L / 10) + the milestone on every 10th", function()
		local m = RULES.marks
		expect(m.base).toBe(2)
		local sum = 0
		for _, c in Data.list do
			expect(c.reward.marks).toBe(Contracts.marksFor(c.level))
			local want = m.base + m.per10 * math.floor(c.level / 10) + (if c.level % 10 == 0 then m.milestone else 0)
			expect(Contracts.marksFor(c.level)).toBe(want)
			sum += c.reward.marks or 0
		end
		expect(Contracts.marksFor(1)).toBe(2)
		expect(Contracts.marksFor(45)).toBe(6)
		expect(Contracts.marksFor(99)).toBe(11)
		expect(sum).toBe(Contracts.retroMarks(99))
		expect(sum >= 700 and sum <= 780).toBe(true)
		expect(Contracts.marksFor(0)).toBe(0)
		-- the last contract gives the title
		expect(Data.list[99].reward.cosmetic).toBe(RULES.finalCosmetic)
		expect(Data.list[98].reward.cosmetic).toBeNil()
	end)

	it("kindShares counts the members of the area's normal groups only", function()
		local spawners: any = {
			{ areaId = "a", variant = "normal", monster = "x", members = { "x", "y" }, count = 2 },
			{ areaId = "a", variant = "normal", monster = "x", count = 2 },
			{ areaId = "a", variant = "elite", monster = "z", count = 1 },
			{ areaId = "b", variant = "normal", monster = "y", count = 3 },
		}
		local shares = AreaSpawns.kindShares(spawners, "a")
		expect(shares.x).toBe(0.75)
		expect(shares.y).toBe(0.25)
		expect(shares.z).toBeNil()
		expect(next(AreaSpawns.kindShares(spawners, "c"))).toBeNil()
	end)
end)

describe("Contracts: state (Logic/Contracts, S134k)", function()
	it("stateOf survives broken saves", function()
		local empty = Contracts.empty()
		expect(Contracts.stateOf(nil)).toEqual(empty)
		expect(Contracts.stateOf({})).toEqual(empty)
		expect(Contracts.stateOf({ contract = "x" })).toEqual(empty)
		local s = state({
			done = 3.7,
			extra = { 5, 4, 4, 2, "x", 120, 7 },
			active = {
				{ level = 6, progress = { 2 } },
				{ level = 6, progress = { 9 } }, -- a duplicate
				{ level = 5, progress = { 1 } }, -- handed in
				{ level = 9, progress = "bad" },
				{ level = 200, progress = { 1 } }, -- unknown
				"junk",
			},
			marks = -4,
			auto = "yes",
			shopWeek = { week = 12, counts = { essence_dust = 2, bad = -1, [3] = 4 } },
		})
		-- 4 and 5 follow done 3: compacted; 2 is in the prefix; 7 stays out of order
		expect(s.done).toBe(5)
		expect(s.extra).toEqual({ 7 })
		expect(levelsOf(s.active)).toEqual({ 6, 9 })
		expect(s.active[1].progress).toEqual({ 2 })
		expect(s.active[2].progress).toEqual({ 0 })
		expect(s.marks).toBe(0)
		expect(s.auto).toBe(false)
		expect(s.shopWeek).toEqual({ week = 12, counts = { essence_dust = 2 } })
		-- the pre-S134k single entry reads as a list of one
		local old = state({ done = 3, active = { level = 4, progress = { 2 } } })
		expect(old.active).toEqual({ { level = 4, progress = { 2 } } })
		expect(state({ done = 3, active = { level = 2, progress = { 2 } } }).active).toEqual({})
	end)

	it("eligible, canAccept and the givers (the board, the Huntmaster, the scout of the region only)", function()
		local s = state({ done = 3, extra = { 6 }, active = { { level = 5, progress = { 0 } } } })
		expect(levelsOf(Contracts.eligible(s, 8))).toEqual({ 4, 7, 8 })
		expect(#Contracts.eligible(s, 3)).toBe(0)
		local meadows = Data.list[5]
		expect(meadows.map).toBe("meadows")
		expect(Contracts.giversOf(meadows)).toEqual({ "questboard", "huntmaster", "scout_meadows" })
		expect(Contracts.isGiver("huntmaster", meadows)).toBe(true)
		expect(Contracts.isGiver("scout_ashen", meadows)).toBe(false)
		expect(Contracts.isAnyGiver("scout_ashen")).toBe(true)
		expect(Contracts.isAnyGiver("innkeeper")).toBe(false)
		local ok, reason = Contracts.canAccept(s, 8, "questboard")
		expect(ok).toBe(true)
		expect(reason).toBeNil()
		ok, reason = Contracts.canAccept(s, 8, "scout_ashen")
		expect(ok).toBe(false)
		expect(reason).toBe("giver")
		ok, reason = Contracts.canAccept(s, 3, "questboard")
		expect(reason).toBe("level")
		ok, reason = Contracts.canAccept(s, 8, "questboard", 5) -- active already
		expect(reason).toBe("none")
		ok, reason = Contracts.canAccept(s, 8, "questboard", 6) -- handed in
		expect(reason).toBe("none")
		ok, reason = Contracts.canAccept(s, 8, "questboard", 9)
		expect(reason).toBe("level")
		ok = Contracts.canAccept(s, 8, "scout_meadows", 7)
		expect(ok).toBe(true)
		ok, reason = Contracts.canAccept(state({ done = 99 }), 100, "questboard")
		expect(reason).toBe("none")
		-- a scout gives only the contracts of its own region
		local wide = state({ done = 0 })
		for _, c in Contracts.acceptable(wide, 40, "scout_meadows") do
			expect(c.map).toBe("meadows")
		end
		expect(#Contracts.acceptable(wide, 40, "questboard")).toBe(40)
		expect(#Contracts.acceptable(wide, 40, "huntmaster")).toBe(40)
	end)

	it("credit: a kill of the kind on the ground counts for every matching active contract, nothing else", function()
		-- two active contracts on the same kind and ground (one already finished) and one elsewhere
		local c = Data.list[12]
		local o = c.objectives[1]
		local other: any = nil
		for _, d in Data.list do
			if d.area ~= c.area then
				other = d
				break
			end
		end
		local s = state({
			done = 0,
			active = { { level = 12, progress = { 0 } }, { level = other.level, progress = { 0 } } },
		})
		local kill = { monsterId = o.monster, areaId = c.area, variant = "normal" }
		expect(Contracts.credit(s, "kill", kill)).toEqual({ 12 })
		expect(Contracts.credit(s, "kill", { monsterId = o.monster, areaId = c.area, variant = "elite" })).toEqual({
			12,
		})
		expect(Contracts.credit(s, "kill", { monsterId = "nobody", areaId = c.area })).toEqual({})
		expect(Contracts.credit(s, "kill", { monsterId = o.monster, areaId = "elsewhere" })).toEqual({})
		expect(Contracts.credit(s, "gather", { areaId = c.area })).toEqual({})
		local finished = state({ done = 0, active = { { level = 12, progress = { o.n } } } })
		expect(Contracts.credit(finished, "kill", kill)).toEqual({})
		-- a second contract on the same kind and ground gets the same kill
		local twin: any = nil
		for _, d in Data.list do
			if d.level ~= 12 and d.area == c.area and d.objectives[1].monster == o.monster then
				twin = d
				break
			end
		end
		if twin then
			local both = state({
				done = 0,
				active = { { level = 12, progress = { 0 } }, { level = twin.level, progress = { 0 } } },
			})
			local levels = Contracts.credit(both, "kill", kill)
			table.sort(levels)
			local want = { 12, twin.level }
			table.sort(want)
			expect(levels).toEqual(want)
		end
		-- the progress itself goes through QuestLogic (the same rule)
		local rng = Rng.new(1)
		local progress = QuestLogic.emptyProgress(c.objectives)
		QuestLogic.advance(progress, c.objectives, "kill", kill, rng)
		QuestLogic.advance(progress, c.objectives, "kill", { monsterId = "nobody", areaId = c.area }, rng)
		expect(progress[1]).toBe(1)
	end)

	it("accepting, handing in out of order (compacting done), abandoning", function()
		local s = state({ done = 2 })
		local taken = Contracts.withAccepted(s, { Data.list[3], Data.list[5], Data.list[4] })
		expect(levelsOf(taken.active)).toEqual({ 3, 4, 5 })
		expect(taken.auto).toBe(true)
		expect(s.active).toEqual({}) -- a copy
		local again = Contracts.withAccepted(taken, { Data.list[3] })
		expect(#again.active).toBe(3)
		local handed = Contracts.withHandedIn(taken, { 5 }, 7)
		expect(handed.done).toBe(2)
		expect(handed.extra).toEqual({ 5 })
		expect(handed.marks).toBe(7)
		expect(Contracts.isDone(handed, 5)).toBe(true)
		expect(Contracts.isDone(handed, 4)).toBe(false)
		handed = Contracts.withHandedIn(handed, { 3, 4 }, 0)
		expect(handed.done).toBe(5)
		expect(handed.extra).toEqual({})
		expect(handed.active).toEqual({})
		expect(Contracts.doneCount(handed)).toBe(5)
		local dropped = Contracts.withAbandoned(taken, 4)
		expect(levelsOf(dropped.active)).toEqual({ 3, 5 })
		expect(levelsOf(Contracts.eligible(dropped, 5))).toEqual({ 4 })
	end)

	it("complete, ready at a giver, backlog, upcoming and allDone", function()
		local n10 = Data.list[10].objectives[1].n
		local s = state({
			done = 8,
			active = { { level = 9, progress = { 0 } }, { level = 10, progress = { n10 } } },
		})
		expect(levelsOf(Contracts.complete(s))).toEqual({ 10 })
		expect(levelsOf(Contracts.ready(s, "huntmaster"))).toEqual({ 10 })
		expect(levelsOf(Contracts.ready(s, "scout_ashen"))).toEqual({})
		expect(Contracts.backlog(s, 12)).toBe(3) -- 11, 12 to take and 9 open
		expect(levelsOf(Contracts.upcoming(s, 12, 3))).toEqual({ 13, 14, 15 })
		expect(#Contracts.upcoming(state({ done = 97 }), 97, 3)).toBe(2)
		expect(Contracts.allDone(state({ done = 99 }))).toBe(true)
		expect(Contracts.allDone(state({ done = 98 }))).toBe(false)
	end)

	it("the title of contract 99 only once all 99 are handed in", function()
		local final = Data.RULES.finalCosmetic
		local c99 = Data.forLevel(99) :: any
		expect(c99.reward.cosmetic).toBe(final)
		-- 99 handed in out of order: no title while 21..98 are open
		local early = Contracts.withHandedIn(state({ done = 20 }), { 99 }, 0)
		expect(Contracts.earnedCosmetics(early, { c99 })).toEqual({})
		-- the last open contract handed in after 99: the title comes with it
		local last = Contracts.withHandedIn(state({ done = 97, extra = { 99 } }), { 98 }, 0)
		expect(Contracts.earnedCosmetics(last, { Data.forLevel(98) :: any })).toEqual({ final })
		-- in order, and a character done before S134k (no hand-in)
		expect(Contracts.earnedCosmetics(Contracts.withHandedIn(state({ done = 98 }), { 99 }, 0), { c99 })).toEqual({
			final,
		})
		expect(Contracts.earnedCosmetics(state({ done = 99 }), {})).toEqual({ final })
		expect(Contracts.earnedCosmetics(state({ done = 50 }), {})).toEqual({})
	end)
end)

describe("Contracts: save, migration 7 and migration 11", function()
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

	it("the template starts at contract 1 without marks", function()
		local template: any = AccountSchema.characterTemplate()
		-- S134k: the new shape (several active, marks, the weekly shop counter)
		expect(template.quests.contract).toEqual({
			done = 0,
			extra = {},
			active = {},
			marks = 0,
			auto = false,
			shopWeek = { week = 0, counts = {} },
		})
		expect(Config.Quest.contractBacklog).toBe(3)
		-- S102: 8 = story progress, S132: 9 = class outfits; S134g: 10 = item effects; S134k: 11 = contracts
		expect(AccountSchema.CURRENT).toBe(11)
	end)

	it(
		"existing characters keep 3 levels of backlog, never lose progress, get no rewards but the retro marks",
		function()
			local data = oldAccount()
			local applied = AccountSchema.migrate(data)
			expect(applied).toEqual({ 7, 8, 9, 10, 11 }) -- S134g: 10 = item effects; S134k: 11 = contracts
			local chars = data.characters
			-- S134k: the S99 numbers stay `done`, now in the shape of migration 11
			local function shape(done: number): any
				return {
					done = done,
					extra = {},
					active = {},
					marks = Contracts.retroMarks(done),
					auto = done > 0,
					shopWeek = { week = 0, counts = {} },
				}
			end
			expect(chars.a.quests.contract).toEqual(shape(77))
			expect(chars.b.quests.contract).toEqual(shape(0))
			expect(chars.c.quests.contract).toEqual(shape(47)) -- the stray active entry is gone
			expect(chars.d.quests.contract).toEqual(shape(45))
			expect(chars.e.quests.contract).toEqual(shape(0))
			expect(chars.f.quests.contract).toEqual(shape(17))
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
			expect(chars.a.quests.contract.done).toBe(77)
			expect(chars.d.quests.contract.done).toBe(45)
		end
	)

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
		-- S134k: migration 11 keeps it as the one active contract (progress min(4, the new n))
		local n = Data.list[8].objectives[1].n
		local contract = data.characters["1"].quests.contract
		expect(contract.done).toBe(7)
		expect(contract.active).toEqual({ { level = 8, progress = { math.min(4, n) } } })
		local odd: any = { schema = 6, characters = { ["1"] = "oops" } }
		AccountSchema._migrations[7](odd, function()
			return "x"
		end)
		expect(odd.characters["1"]).toBe("oops")
	end)

	it("migration 11: done 1-30 kept, the active 31 with min(old progress, n), retro marks; idempotent", function()
		local function account(contract: any): any
			return {
				schema = 10,
				characters = {
					x = { id = "x", level = 40, quests = { contract = contract } },
					y = { id = "y", level = 5 }, -- no quests: the reconcile adds the template
					z = "junk",
				},
			}
		end
		local data = account({ done = 30, active = { level = 31, progress = { 12 } } })
		expect(AccountSchema.migrate(data)).toEqual({ 11 })
		local n = Data.list[31].objectives[1].n
		local c = data.characters.x.quests.contract
		expect(c.done).toBe(30)
		expect(c.extra).toEqual({})
		expect(c.active).toEqual({ { level = 31, progress = { math.min(12, n) } } })
		local sum = 0
		for L = 1, 30 do
			sum += Contracts.marksFor(L)
		end
		expect(c.marks).toBe(sum)
		expect(c.auto).toBe(true)
		expect(c.shopWeek).toEqual({ week = 0, counts = {} })
		expect(data.characters.y.quests.contract).toEqual(AccountSchema.characterTemplate().quests.contract)
		expect(data.characters.z).toBe("junk")
		-- the state reads it, the 30 contracts count as handed in
		local s = Contracts.stateOf(data.characters.x.quests)
		expect(Contracts.isDone(s, 30)).toBe(true)
		expect(levelsOf(Contracts.eligible(s, 33))).toEqual({ 32, 33 })
		-- idempotent: a second run leaves the new shape (and spent marks) alone
		c.marks = 3
		AccountSchema._migrations[11](data, function()
			return "x"
		end)
		expect(data.characters.x.quests.contract.marks).toBe(3)
		expect(data.characters.x.quests.contract.active).toEqual({ { level = 31, progress = { math.min(12, n) } } })
		-- an old entry far over the new n keeps n; a broken one goes; a fresh character starts at 1 without marks
		local big = account({ done = 0, active = { level = 1, progress = { 999 } } })
		AccountSchema.migrate(big)
		expect(big.characters.x.quests.contract.active).toEqual({
			{ level = 1, progress = { Data.list[1].objectives[1].n } },
		})
		local broken = account({ done = "x", active = { level = 0.5 } })
		AccountSchema.migrate(broken)
		expect(broken.characters.x.quests.contract.done).toBe(0)
		expect(broken.characters.x.quests.contract.active).toEqual({})
		expect(broken.characters.x.quests.contract.auto).toBe(false)
		expect(broken.characters.x.quests.contract.marks).toBe(0)
	end)
end)

return nil
