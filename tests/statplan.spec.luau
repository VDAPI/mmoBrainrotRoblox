--!strict
-- Stat plans and stat points of a build set (S58, ROZWOJ 2.9, 2.11): Logic/StatPlan and the plans in Data.

local Classes = require("../src/shared/Data/Classes")
local Fixture = require("./fixtures/paths")
local PathData = require("../src/shared/Data/Paths")
local StatPlan = require("../src/shared/Logic/StatPlan")
local Stats = require("../src/shared/Data/Stats")
local T = require("./Test")

local function plus(base: any, add: { [string]: number }): { [string]: number }
	local out: { [string]: number } = table.clone(base)
	for id, n in add do
		out[id] = (out[id] or 0) + n
	end
	return out
end

local function checkPlan(plan: any, what: string)
	assert(type(plan) == "table", `{what}: statPlan missing`)
	local entries = 0
	for id, w in plan do
		assert(table.find(Stats.primary, id), `{what}: statPlan key {id} is not a primary stat`)
		assert(type(w) == "number" and w >= 1 and w == math.floor(w), `{what}: statPlan {id} must be an integer >= 1`)
		entries += 1
	end
	assert(entries > 0, `{what}: statPlan is empty`)
end

T.describe("StatPlan.suggest", function()
	local warrior = StatPlan.startOf("Warrior") :: any

	T.it("1. the Warrior plan from the start", function()
		T.expect(StatPlan.suggest({ str = 4, vit = 1 }, warrior, warrior, 5)).toEqual({ str = 4, vit = 1 })
		T.expect(StatPlan.suggest({ str = 4, vit = 1 }, warrior, warrior, 10)).toEqual({ str = 8, vit = 2 })
	end)

	T.it("2. ties follow Stats.primary", function()
		local cleric = StatPlan.startOf("Cleric") :: any
		T.expect(StatPlan.suggest({ int = 1, vit = 1 }, cleric, cleric, 5)).toEqual({ int = 3, vit = 2 })
	end)

	T.it("3. off-plan points count toward the total", function()
		T.expect(StatPlan.suggest({ str = 4, vit = 1 }, warrior, plus(warrior, { dex = 5 }), 5)).toEqual({ str = 5 })
		T.expect(StatPlan.suggest({ str = 4, vit = 1 }, warrior, plus(warrior, { str = 10 }), 4)).toEqual({
			vit = 3,
			str = 1,
		})
	end)

	T.it("4. edges", function()
		T.expect(StatPlan.suggest({ str = 4, vit = 1 }, warrior, warrior, 0)).toEqual({})
		T.expect(StatPlan.suggest({}, warrior, warrior, 5)).toEqual({})
		T.expect(StatPlan.suggest({ str = 0 }, warrior, warrior, 5)).toEqual({})
		T.expect(StatPlan.suggest({ luck = 5, str = 1 }, warrior, warrior, 5)).toEqual({ str = 5 })
		T.expect(StatPlan.suggest({ str = 4, vit = 1 }, warrior, warrior, 2.7)).toEqual({ str = 2 })
	end)

	T.it("5. proportions from the start", function()
		local plans: { { [string]: number } } = {
			{ int = 3, vit = 2 },
			{ str = 2, vit = 3 },
			{ str = 1, dex = 1, int = 1, vit = 1 },
		}
		for _, id in Classes.order do
			table.insert(plans, (Classes.get(id) :: any).statPlan)
		end
		for _, plan in plans do
			local weight = 0
			for _, w in plan do
				weight += w
			end
			for free = 0, 495 do
				local out = StatPlan.suggest(plan, warrior, warrior, free)
				local sum = 0
				for id, n in out do
					assert(plan[id] ~= nil, `key {id} outside the plan`)
					assert(n >= 1, `zero entry {id}`)
					sum += n
				end
				assert(sum == free, `sum {sum} ~= {free}`)
				for id, w in plan do
					local diff = math.abs((out[id] or 0) - w / weight * free)
					assert(diff < 1, `{id} off by {diff} at {free}`)
				end
			end
		end
	end)
end)

T.describe("StatPlan: points", function()
	T.it("6. spent and refit", function()
		local start = StatPlan.startOf("Warrior") :: any
		local stats = plus(start, { str = 100, vit = 45 })
		T.expect(StatPlan.spent("Warrior", stats)).toBe(145)
		local reset, free = StatPlan.refit("Warrior", 20, stats)
		T.expect(reset).toEqual(start)
		T.expect(free).toBe(95)
		local kept = plus(start, { str = 50 })
		local same, left = StatPlan.refit("Warrior", 30, kept)
		T.expect(same).toEqual(kept)
		T.expect(same ~= (kept :: any)).toBe(true)
		T.expect(left).toBe(95)
		local unknown, all = StatPlan.refit("Nobody", 30, kept)
		T.expect(unknown).toEqual(kept)
		T.expect(all).toBe(StatPlan.total(30))
		T.expect(StatPlan.total(1)).toBe(0)
		T.expect(StatPlan.total(100)).toBe(495)
		T.expect(StatPlan.startOf("Nobody")).toEqual({ str = 0, dex = 0, int = 0, vit = 0 })
	end)
end)

T.describe("Data: stat plans", function()
	T.it("7. class and path plans", function()
		local expected: { [string]: { [string]: number } } = {
			Warrior = { str = 4, vit = 1 },
			Hunter = { dex = 4, vit = 1 },
			Mage = { int = 4, vit = 1 },
			Cleric = { int = 1, vit = 1 },
		}
		for _, id in Classes.order do
			local plan = (Classes.get(id) :: any).statPlan
			checkPlan(plan, id)
			T.expect(plan).toEqual(expected[id])
		end
		for _, path in PathData.list do
			if path.statPlan ~= nil then
				checkPlan(path.statPlan, path.id)
			end
		end
		local storm = Fixture.source.path("fxStorm") :: any
		checkPlan(storm.statPlan, "fxStorm")
	end)
end)
