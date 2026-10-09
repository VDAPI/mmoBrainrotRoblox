--!strict
-- S09: party loot, gold/EXP sharing, boss scaling and boss data.

local BossScaling = require("../src/shared/Logic/BossScaling")
local Config = require("../src/shared/Config")
local Bosses = require("../src/shared/Data/Bosses")
local LootTables = require("../src/shared/Data/LootTables")
local Maps = require("../src/shared/Data/Maps")
local Monsters = require("../src/shared/Data/Monsters")
local PartyLoot = require("../src/shared/Logic/PartyLoot")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local WARRIOR = { id = 1, classId = "Warrior" }
local WARRIOR2 = { id = 2, classId = "Warrior" }
local MAGE = { id = 3, classId = "Mage" }
local HUNTER = { id = 4, classId = "Hunter" }

describe("PartyLoot.distribute", function()
	it("gives everything to a single member", function()
		local result = PartyLoot.distribute({
			{ uid = "a", classes = { "Mage" } },
			{ uid = "b", classes = nil },
		}, { WARRIOR }, Rng.new(1))
		expect(result.a).toBe(1)
		expect(result.b).toBe(1)
	end)

	it("gives a class item to the only member of that class", function()
		for seed = 1, 30 do
			local result = PartyLoot.distribute(
				{ { uid = "staff", classes = { "Mage" } } },
				{ WARRIOR, MAGE, HUNTER },
				Rng.new(seed)
			)
			expect(result.staff).toBe(3)
		end
	end)

	it("rolls between several members of the class", function()
		local seen = {}
		local rng = Rng.new(12345)
		for _ = 1, 60 do
			local result = PartyLoot.distribute(
				{ { uid = "axe", classes = { "Warrior" } } },
				{ WARRIOR, WARRIOR2, MAGE },
				rng
			)
			expect(result.axe == 1 or result.axe == 2).toBe(true)
			seen[result.axe] = true
		end
		expect(seen[1] and seen[2]).toBe(true)
	end)

	it("rolls between everybody when nobody has the class", function()
		local seen = {}
		local rng = Rng.new(12345)
		for _ = 1, 80 do
			local result = PartyLoot.distribute({ { uid = "bow", classes = { "Hunter" } } }, { WARRIOR, MAGE }, rng)
			seen[result.bow] = true
		end
		expect(seen[1] and seen[3]).toBe(true)
	end)

	it("rolls jewellery and materials between everybody", function()
		local seen = {}
		local rng = Rng.new(12345)
		for _ = 1, 120 do
			local result = PartyLoot.distribute({ { uid = "ring" } }, { WARRIOR, MAGE, HUNTER }, rng)
			seen[result.ring] = true
		end
		expect(seen[1] and seen[3] and seen[4]).toBe(true)
	end)

	it("assigns every item and nothing without candidates", function()
		local items = { { uid = "1" }, { uid = "2", classes = { "Mage" } }, { uid = "3", classes = { "Warrior" } } }
		local result = PartyLoot.distribute(items, { WARRIOR, MAGE }, Rng.new(5))
		expect(result["1"] ~= nil and result["2"] == 3 and result["3"] == 1).toBe(true)
		expect(next(PartyLoot.distribute(items, {}, Rng.new(5)))).toBeNil()
	end)
end)

describe("PartyLoot sharing", function()
	it("splits gold evenly with the remainder to one member", function()
		local shares = PartyLoot.splitGold(101, 4, Rng.new(3))
		local total, max, min = 0, 0, math.huge
		for _, share in shares do
			total += share
			max = math.max(max, share)
			min = math.min(min, share)
		end
		expect(#shares).toBe(4)
		expect(total).toBe(101)
		expect(min).toBe(25)
		expect(max).toBe(26)
	end)

	it("keeps solo gold intact", function()
		expect(PartyLoot.splitGold(77, 1, Rng.new(1))[1]).toBe(77)
	end)

	it("splits EXP evenly", function()
		expect(PartyLoot.splitExp(100, 3)).toBe(33)
		expect(PartyLoot.splitExp(100, 1)).toBe(100)
		expect(PartyLoot.splitExp(100, 0)).toBe(100)
	end)
end)

describe("BossScaling", function()
	it("scales HP by players", function()
		expect(BossScaling.hpMultiplier(1)).toBe(30)
		expect(math.abs(BossScaling.hpMultiplier(5) - 102) < 1e-9).toBe(true)
	end)

	it("picks phases by HP", function()
		local t = { 0.7, 0.35 }
		expect(BossScaling.phaseFor(1, t)).toBe(1)
		expect(BossScaling.phaseFor(0.7, t)).toBe(2)
		expect(BossScaling.phaseFor(0.5, t)).toBe(2)
		expect(BossScaling.phaseFor(0.35, t)).toBe(3)
		expect(BossScaling.phaseFor(0.01, t)).toBe(3)
	end)

	it("locks after the daily runs for the rest of the UTC day (S30 bossRuns)", function()
		local day = 20000
		local now = day * 86400 + 3600
		expect(BossScaling.isLocked({ grimrok = { day = day, n = 3 } }, "grimrok", now, 3)).toBe(true)
		expect(BossScaling.isLocked({ grimrok = { day = day, n = 2 } }, "grimrok", now, 3)).toBe(false)
		expect(BossScaling.isLocked({ grimrok = { day = day, n = 1 } }, "grimrok", now, 1)).toBe(true)
		expect(BossScaling.isLocked({ grimrok = { day = day - 1, n = 3 } }, "grimrok", now, 3)).toBe(false)
		expect(BossScaling.isLocked({}, "grimrok", now)).toBe(false)
		expect(BossScaling.isLocked(nil, "grimrok", now)).toBe(false)
		expect(BossScaling.runsToday({ grimrok = { day = day, n = 2 } }, "grimrok", now)).toBe(2)
		expect(BossScaling.runsToday({ grimrok = { day = day - 1, n = 2 } }, "grimrok", now)).toBe(0)
		expect(BossScaling.addRun({ grimrok = { day = day, n = 2 } }, "grimrok", now)).toEqual({
			day = day,
			n = 3,
			k = 3,
		})
		expect(BossScaling.addRun({ grimrok = { day = day - 1, n = 3 } }, "grimrok", now)).toEqual({
			day = day,
			n = 1,
			k = 1,
		})
		-- A failed attempt uses the limit but adds no kill.
		local failed = BossScaling.addRun({ grimrok = { day = day, n = 1, k = 1 } }, "grimrok", now, false)
		expect(failed).toEqual({ day = day, n = 2, k = 1 })
		expect(BossScaling.killsToday({ grimrok = failed }, "grimrok", now)).toBe(1)
		expect(BossScaling.runsToday({ grimrok = failed }, "grimrok", now)).toBe(2)
		expect(BossScaling.isLocked({ grimrok = { day = day, n = 2 } }, "grimrok", now)).toBe(
			Config.Boss.dailyRuns <= 2
		)
		expect(BossScaling.untilReset(now)).toBe(86400 - 3600)
	end)

	it("requires boss level - 5", function()
		expect(BossScaling.requiredLevel(20)).toBe(15)
	end)
end)

describe("Boss data", function()
	it("has the four bosses with loot tables and dungeon maps", function()
		for _, id in { "grimrok", "morvane", "azgor", "vaelgrath" } do
			local def = Bosses.get(id)
			assert(def, id)
			expect(LootTables.bosses[id] ~= nil).toBe(true)
			expect(Maps.get(`dungeon_{def.region}`) ~= nil).toBe(true)
			expect(Bosses.forRegion(def.region)).toBe(def)
		end
	end)

	it("matches the DESIGN §16 rules", function()
		for _, def in Bosses.list do
			expect(def.timeLimit).toBe(900)
			expect(def.enrageAfter).toBe(600)
			expect(#def.phases).toBe(2)
			expect(def.phases[1]).toBe(0.7)
			expect(def.phases[2]).toBe(0.35)
		end
	end)

	it("has valid attacks and summons", function()
		for _, def in Bosses.list do
			local usedPhases = {}
			for _, attack in def.attacks do
				expect(attack.windup >= 0.8 and attack.windup <= 2.5).toBe(true)
				expect(attack.cooldown > attack.windup).toBe(true)
				expect(attack.damage > 0).toBe(true)
				if attack.shape == "ring" then
					expect((attack.inner or 0) > 0 and (attack.inner or 0) < (attack.radius or 0)).toBe(true)
				end
				for _, phase in attack.phases do
					usedPhases[phase] = true
				end
			end
			expect(usedPhases[1] and usedPhases[2] and usedPhases[3]).toBe(true)
			for _, summon in def.summons do
				expect(Monsters.get(summon.monster) ~= nil).toBe(true)
				expect(summon.phase >= 2 and summon.phase <= 3).toBe(true)
			end
		end
	end)

	it("Grimrok and Morvane follow their scripts", function()
		local grimrok = Bosses.get("grimrok")
		local morvane = Bosses.get("morvane")
		assert(grimrok and morvane, "bosses")
		expect((grimrok.haste or {})[3]).toBe(1.25)
		-- 2026-10-10: every boss calls two shield waves of 10 helpers (phases 2 and 3).
		for _, def in Bosses.list do
			expect(#def.summons).toBe(2)
			for _, summon in def.summons do
				expect(summon.count).toBe(10)
				expect(summon.shield).toBe(true)
				expect(summon.every).toBe(nil)
			end
		end
		local ring = nil
		for _, attack in morvane.attacks do
			if attack.shape == "ring" then
				ring = attack
			end
		end
		assert(ring, "ring")
		expect(ring.cooldown).toBe(15)
	end)
end)
