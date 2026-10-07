--!strict
-- S29: blessing duration (30 min), brewing time vs duration and the ✶ mark next to the name.

local AdminCommands = require("../src/shared/Data/AdminCommands")
local BlessingMark = require("../src/shared/Logic/BlessingMark")
local Blessings = require("../src/shared/Data/Blessings")
local Recipes = require("../src/shared/Data/Recipes")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Blessing duration", function()
	it("lasts 30 minutes", function()
		expect(Blessings.DURATION).toBe(1800)
	end)

	it("never takes longer to brew than it lasts", function()
		local count = 0
		for _, recipe in Recipes.list do
			if recipe.group == "blessing" then
				count += 1
				expect(recipe.time > 0 and recipe.time <= Blessings.DURATION).toBe(true)
			end
		end
		expect(count > 0).toBe(true)
	end)

	it("keeps elixirs at one hour", function()
		expect(Blessings.ELIXIR_DURATION).toBe(3600)
	end)

	it("finds a blessing by line and tier", function()
		local def = Blessings.of("warrior", 3)
		expect(def and def.id).toBe("warrior_3")
		expect(Blessings.of("warrior", 6)).toBe(nil)
		expect(Blessings.of("nope", 1)).toBe(nil)
	end)
end)

describe("BlessingMark", function()
	it("mirrors only an active blessing to attributes", function()
		local id, untilTime = BlessingMark.attributes({ id = "sage_2", expiresAt = 1000 }, 400)
		expect(id).toBe("sage_2")
		expect(untilTime).toBe(1000)
		local none, noneUntil = BlessingMark.attributes({ id = "sage_2", expiresAt = 1000 }, 1000)
		expect(none).toBe(nil)
		expect(noneUntil).toBe(nil)
		expect((BlessingMark.attributes(nil, 0))).toBe(nil)
		expect((BlessingMark.attributes({ id = "bogus_9", expiresAt = 1000 }, 0))).toBe(nil)
	end)

	it("reads attribute values safely", function()
		expect(BlessingMark.read(nil, nil, 0)).toBe(nil)
		expect(BlessingMark.read("warrior_1", "x", 0)).toBe(nil)
		expect(BlessingMark.read("warrior_1", 100, 100)).toBe(nil)
		local mark = BlessingMark.read("guardian_5", 2000, 200)
		expect(mark and mark.def.rarity).toBe(5)
		expect(mark and mark.lastMinute).toBe(false)
		local ending = BlessingMark.read("guardian_5", 2000, 2000 - Blessings.LAST_MINUTE)
		expect(ending and ending.lastMinute).toBe(true)
	end)

	it("counts down as mm:ss", function()
		expect(BlessingMark.countdown(Blessings.DURATION)).toBe("30:00")
		expect(BlessingMark.countdown(59.2)).toBe("01:00")
		expect(BlessingMark.countdown(0)).toBe("00:00")
	end)
end)

describe("Admin /blessing", function()
	it("takes line, tier and optional seconds", function()
		local command = AdminCommands.get("blessing")
		expect(command ~= nil).toBe(true)
		if command then
			expect(#command.args).toBe(3)
			expect(command.args[1].kind).toBe("enum")
			expect(command.args[3].optional).toBe(true)
		end
	end)
end)
