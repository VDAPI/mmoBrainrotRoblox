--!strict
local Classes = require("../src/shared/Data/Classes")
local StatCalc = require("../src/shared/Logic/StatCalc")
local Stats = require("../src/shared/Data/Stats")
local T = require("./Test")

local F = Stats.Formula

local function statsFor(classId: string, level: number): any
	local class = Classes.get(classId) :: Classes.ClassDef
	local stats = table.clone(class.startStats) :: any
	-- Spread level-up points evenly over the class main stats.
	local points = (level - 1) * 5
	local mains = class.mainStats
	for i = 1, points do
		local id = mains[(i - 1) % #mains + 1]
		stats[id] += 1
	end
	return stats
end

local function expected(stats: any, level: number)
	return {
		maxHp = math.floor(80 + 20 * level + 12 * stats.vit),
		maxMana = math.floor(40 + 6 * level + 8 * stats.int),
		maxEnergy = 100 + level,
		armor = stats.vit + 0.5 * stats.str,
		mres = 0.5 * stats.int + 0.5 * stats.vit,
		critChance = math.min(60, 5 + 0.05 * stats.dex),
		dodge = math.min(30, 0.03 * stats.dex),
		physAtk = F.unarmed.dmg * (1 + 0.02 * stats.str),
		magAtk = F.unarmed.mdmg * (1 + 0.025 * stats.int),
		atkSpeed = math.min(2.5, F.unarmed.speed * (1 + 0.002 * stats.dex)),
	}
end

T.describe("StatCalc", function()
	for _, classId in Classes.order do
		for _, level in { 1, 50, 100 } do
			T.it(`{classId} level {level} matches the formulas`, function()
				local stats = statsFor(classId, level)
				local result = StatCalc.compute({ level = level, stats = stats })
				for id, value in expected(stats, level) do
					local actual = result.values[id]
					if math.abs(actual - value) > 1e-6 then
						error(`{id}: expected {value}, got {actual}`)
					end
				end
				T.expect(result.primary).toEqual(stats)
				T.expect(result.walkSpeed).toBe(16)
			end)
		end
	end

	T.it("Warrior level 1 concrete numbers", function()
		local result = StatCalc.compute({ level = 1, stats = { str = 10, dex = 5, int = 3, vit = 8 } })
		T.expect(result.values.maxHp).toBe(196)
		T.expect(result.values.maxMana).toBe(70)
		T.expect(result.values.maxEnergy).toBe(101)
		T.expect(result.values.critChance).toBeNear(5.25)
		T.expect(result.values.hpRegen).toBeNear(0.98)
		T.expect(result.values.hpRegenCombat).toBeNear(0.196)
		T.expect(result.values.energyRegen).toBe(8)
	end)

	T.it("sources add flat, then pct multiplies", function()
		local result = StatCalc.compute({
			level = 1,
			stats = { str = 10, dex = 5, int = 3, vit = 8 },
			sources = {
				{ key = "source.gear", flat = { hp = 100, vit = 2 }, pct = { maxHp = 10 } },
				{ key = "source.blessing", flat = { maxHp = 50 } },
			},
		})
		-- (80 + 20 + 12*10 + 150) * 1.1
		T.expect(result.values.maxHp).toBe(math.floor((80 + 20 + 120 + 150) * 1.1))
		T.expect(result.primary.vit).toBe(10)
		local keys = {}
		for _, part in result.breakdown.maxHp do
			table.insert(keys, part.key .. (if part.pct then "%" else ""))
		end
		T.expect(keys).toEqual({
			"breakdown.base",
			"breakdown.level",
			"breakdown.vit",
			"source.gear",
			"source.gear%",
			"source.blessing",
		})
	end)

	T.it("caps apply", function()
		local result = StatCalc.compute({
			level = 1,
			stats = { str = 1, dex = 5000, int = 1, vit = 1 },
			sources = {
				{
					key = "source.gear",
					flat = { lifesteal = 40, resFire = 120, moveSpeed = 80, atkSpeed = 500 },
				},
			},
		})
		T.expect(result.values.critChance).toBe(60)
		T.expect(result.values.dodge).toBe(30)
		T.expect(result.values.lifesteal).toBe(15)
		T.expect(result.values.resFire).toBe(75)
		T.expect(result.values.moveSpeed).toBe(30)
		T.expect(result.values.atkSpeed).toBe(2.5)
		T.expect(result.walkSpeed).toBeNear(20.8)
	end)

	T.it("ranged weapons scale with DEX, melee with STR", function()
		local stats = { str = 20, dex = 40, int = 1, vit = 1 }
		local bow =
			StatCalc.compute({ level = 10, stats = stats, weapon = { dmg = 10, mdmg = 0, speed = 1, ranged = true } })
		local sword =
			StatCalc.compute({ level = 10, stats = stats, weapon = { dmg = 10, mdmg = 0, speed = 1, ranged = false } })
		T.expect(bow.values.physAtk).toBeNear(10 * (1 + 0.02 * 40))
		T.expect(sword.values.physAtk).toBeNear(10 * (1 + 0.02 * 20))
	end)

	T.it("every stat definition gets a value and a breakdown", function()
		local result = StatCalc.compute({ level = 5, stats = { str = 5, dex = 5, int = 5, vit = 5 } })
		for _, def in Stats.list do
			T.expect({ id = def.id, ok = result.values[def.id] ~= nil and result.breakdown[def.id] ~= nil }).toEqual({
				id = def.id,
				ok = true,
			})
		end
	end)

	T.it("merge sums sources", function()
		local merged = StatCalc.merge({
			{ key = "a", flat = { hp = 1 }, pct = { hp = 5 } },
			{ key = "b", flat = { hp = 2, str = 3 } },
		}, "total")
		T.expect(merged).toEqual({ key = "total", flat = { hp = 3, str = 3 }, pct = { hp = 5 } })
	end)
end)

return nil
