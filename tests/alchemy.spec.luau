--!strict
-- S07: time helpers, alchemist recipes, blessings, gathering and fishing data.

local Blessings = require("../src/shared/Data/Blessings")
local Fish = require("../src/shared/Data/Fish")
local GatherNodes = require("../src/shared/Data/GatherNodes")
local Items = require("../src/shared/Data/Items")
local Recipes = require("../src/shared/Data/Recipes")
local Test = require("./Test")
local Time = require("../src/shared/Logic/Time")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Time", function()
	it("computes UTC day numbers", function()
		expect(Time.dayNumber(0)).toBe(0)
		expect(Time.dayNumber(86399)).toBe(0)
		expect(Time.dayNumber(86400)).toBe(1)
	end)

	it("counts down without going negative", function()
		expect(Time.remaining(100, 40)).toBe(60)
		expect(Time.remaining(100, 140)).toBe(0)
	end)

	it("formats durations", function()
		expect(Time.format(5)).toBe("0:05")
		expect(Time.format(247)).toBe("4:07")
		expect(Time.format(3909)).toBe("1:05:09")
		expect(Time.format(-3)).toBe("0:00")
	end)

	it("limits the alchemy queue", function()
		local queue = { { recipeId = "a", readyAt = 10 }, { recipeId = "b", readyAt = 20 } }
		expect(Time.canQueue(queue, 3)).toBe(true)
		table.insert(queue, { recipeId = "c", readyAt = 5 })
		expect(Time.canQueue(queue, 3)).toBe(false)
		expect(Time.canQueue(queue, 4)).toBe(true)
	end)

	it("finds finished orders", function()
		local queue = {
			{ recipeId = "a", readyAt = 10 },
			{ recipeId = "b", readyAt = 20 },
			{ recipeId = "c", readyAt = 5 },
		}
		local ready = Time.readyItems(queue, 10)
		expect(#ready).toBe(2)
		expect(ready[1]).toBe(1)
		expect(ready[2]).toBe(3)
		expect(#Time.readyItems(queue, 0)).toBe(0)
	end)

	it("reports order progress", function()
		local order = { recipeId = "a", readyAt = 100 }
		expect(Time.progress(order, 100, 0)).toBe(0)
		expect(Time.progress(order, 100, 50)).toBe(0.5)
		expect(Time.progress(order, 100, 200)).toBe(1)
	end)
end)

describe("Recipes", function()
	it("has at least 25 recipes", function()
		expect(#Recipes.list >= 25).toBe(true)
	end)

	it("references existing items with positive amounts, gold and time", function()
		for _, recipe in Recipes.list do
			expect(Items.get(recipe.result.id) ~= nil).toBe(true)
			expect(recipe.result.n > 0).toBe(true)
			expect(recipe.time > 0).toBe(true)
			expect(recipe.gold > 0).toBe(true)
			expect(recipe.level >= 1 and recipe.level <= 100).toBe(true)
			expect(#recipe.ingredients > 0).toBe(true)
			for _, ingredient in recipe.ingredients do
				if not Items.get(ingredient.id) then
					error(`{recipe.id}: unknown ingredient {ingredient.id}`)
				end
				expect(ingredient.n > 0).toBe(true)
			end
		end
	end)

	it("brews blessings of every line up to Epic, but not Legendary", function()
		for _, line in Blessings.lines do
			for rarity = 1, 4 do
				expect(Recipes.get(`blessing_{line}_{rarity}`) ~= nil).toBe(true)
			end
			expect(Recipes.get(`blessing_{line}_5`)).toBeNil()
		end
	end)

	it("transmutes essences 10 -> 1 and 8 -> 1", function()
		local shard = Recipes.get("transmute_shard")
		local crystal = Recipes.get("transmute_crystal")
		assert(shard and crystal, "missing data")
		expect(shard.ingredients[1].n).toBe(10)
		expect(crystal.ingredients[1].n).toBe(8)
		expect(shard.time).toBe(300)
	end)

	it("takes 2 to 60 minutes", function()
		for _, recipe in Recipes.list do
			expect(recipe.time >= 120 and recipe.time <= 3600).toBe(true)
		end
	end)
end)

describe("Blessings", function()
	it("has 5 lines x 5 rarities, each with an item", function()
		expect(#Blessings.list).toBe(25)
		for _, blessing in Blessings.list do
			local def = Items.get(blessing.itemId)
			assert(def and def.use, "missing data")
			expect(def.use.kind).toBe("blessing")
			expect(def.use.target).toBe(blessing.id)
			expect(def.rarity).toBe(blessing.rarity)
		end
	end)

	it("matches the Warrior line from DESIGN §11", function()
		local common = Blessings.get("warrior_1")
		local epic = Blessings.get("warrior_4")
		local legendary = Blessings.get("warrior_5")
		assert(common and epic and legendary, "missing data")
		expect(common.stats.maxHp).toBe(100)
		expect(common.stats.str).toBe(5)
		expect(epic.stats.critChance).toBe(3)
		expect(legendary.stats.maxHp).toBe(800)
		expect(legendary.stats.expBonus).toBe(10)
		expect(legendary.stats.dropBonus).toBe(10)
	end)

	it("grows stronger with rarity", function()
		for _, line in Blessings.lines do
			for rarity = 2, 5 do
				local lower = Blessings.get(`{line}_{rarity - 1}`)
				local higher = Blessings.get(`{line}_{rarity}`)
				assert(lower and higher, "missing data")
				for stat, value in lower.stats do
					expect((higher.stats[stat] or 0) >= value).toBe(true)
				end
			end
		end
	end)
end)

describe("Gathering", function()
	it("defines 5 ores, 5 herbs and 4 fishing spots", function()
		local counts = { ore = 0, herb = 0, fishing = 0 }
		for _, kind in GatherNodes.list do
			counts[kind.category] += 1
		end
		expect(counts.ore).toBe(5)
		expect(counts.herb).toBe(5)
		expect(counts.fishing).toBe(4)
	end)

	it("uses the DESIGN §12 timings", function()
		local vein = GatherNodes.get("vein_copper")
		local bush = GatherNodes.get("bush_meadowsweet")
		assert(vein and bush, "missing data")
		expect(vein.tool).toBe("pickaxe")
		expect(vein.time).toBe(2.5)
		expect(vein.respawn).toBe(90)
		expect(bush.tool).toBeNil()
		expect(bush.time).toBe(1.5)
		expect(bush.respawn).toBe(60)
	end)

	it("drops existing items", function()
		for _, kind in GatherNodes.list do
			if kind.tool then
				expect(Items.get(kind.tool) ~= nil).toBe(true)
			end
			for _, entry in kind.loot do
				expect(Items.get(entry.id) ~= nil).toBe(true)
			end
			if kind.category == "fishing" then
				expect(Fish.get(kind.spot or "") ~= nil).toBe(true)
			end
		end
	end)

	it("has fish that exist and a sane minigame", function()
		for _, spot in Fish.spots do
			for _, fish in spot.fish do
				expect(Items.get(fish.id) ~= nil).toBe(true)
				expect(fish.zone > 0.05 and fish.zone < 0.5).toBe(true)
				expect(fish.speed > 0).toBe(true)
			end
			expect(spot.chestChance < 0.1).toBe(true)
		end
		for _, entry in Fish.CHEST_LOOT do
			expect(Items.get(entry.id) ~= nil).toBe(true)
		end
	end)

	it("picks fish by weight", function()
		local spot = Fish.get("meadows")
		assert(spot, "missing data")
		expect(Fish.pick(spot, 0).id).toBe("fish_carp")
		expect(Fish.pick(spot, 0.999).id).toBe("fish_goldfin")
	end)
end)
