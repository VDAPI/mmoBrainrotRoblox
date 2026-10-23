--!strict
-- Dev panel best grants (Logic/ItemBest): every line at the top of its range, class-fitting lines and effects, the
-- rarity's line and effect counts, no effect twice in a set, deterministic.

local Bonuses = require("../src/shared/Data/Bonuses")
local DevPreset = require("../src/shared/Logic/DevPreset")
local ItemBest = require("../src/shared/Logic/ItemBest")
local ItemEffects = require("../src/shared/Logic/ItemEffects")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemScore = require("../src/shared/Logic/ItemScore")
local Items = require("../src/shared/Data/Items")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local CLASSES = { "Warrior", "Hunter", "Mage", "Cleric" }

local function uids(): () -> string
	local n = 0
	return function(): string
		n += 1
		return `best{n}`
	end
end

describe("ItemBest", function()
	it("rolls every line at its top value, fitting the class, with the rarity's counts", function()
		for _, class in CLASSES do
			for _, rarity in { Rarities.UNIQUE, Rarities.LEGENDARY, Rarities.MYTHIC } do
				local rdef = Rarities.get(rarity)
				for _, piece in DevPreset.pick(class, 50) do
					local item = ItemBest.roll(piece.id, 52, rarity, "u", class, { up = 7 })
					expect(item.ilvl).toBe(52)
					expect(item.up).toBe(7)
					expect(#item.bonuses).toBe(math.min(rdef.bonusMax, #ItemRoll.bonusPool(piece.id, class)))
					local seen: { [string]: boolean } = {}
					for _, line in item.bonuses do
						expect(seen[line.stat]).toBeNil()
						seen[line.stat] = true
						-- the top of the range, rounded to the line's decimals like every roll
						expect(line.v).toBe(ItemRoll.rollBonusValue(line.stat, item.ilvl, rarity, 1))
						expect(ItemRoll.bonusQuality(line.stat, line.v, item.ilvl, rarity) > 0.8).toBe(true)
						local only = Bonuses.classStats[line.stat]
						expect(only == nil or table.find(only, class) ~= nil).toBe(true)
					end
					local fx = item.fx or {}
					expect(#fx).toBe(rdef.legendaryEffects + rdef.mythicEffects)
					for _, id in fx do
						local effect = assert(ItemEffects.resolve(id), id)
						expect(effect.class).toBe(class)
					end
				end
			end
		end
	end)

	it("scores at least as high as any random roll without situational lines", function()
		local rng = Rng.new(7)
		for _, class in CLASSES do
			for _, piece in DevPreset.pick(class, 40) do
				local best = ItemBest.roll(piece.id, 40, Rarities.MYTHIC, "b", class)
				local top = ItemScore.score(best, class)
				for _ = 1, 20 do
					local random = ItemRoll.rollItem(piece.id, 40, Rarities.MYTHIC, rng, "r", class)
					random.el = best.el
					-- situational lines (families, classes, bosses, elites) are left out of best rolls on purpose
					local plain = true
					for _, line in random.bonuses do
						local l = string.lower(line.stat)
						if
							string.match(l, "^vs_")
							or string.match(l, "^res_")
							or string.find(l, "boss", 1, true)
							or string.find(l, "elite", 1, true)
						then
							plain = false
						end
					end
					if plain then
						expect(ItemScore.score(random, class) <= top + 1e-6).toBe(true)
					end
				end
			end
		end
	end)

	it("is deterministic and keeps effects distinct across a set", function()
		for _, class in CLASSES do
			local pieces = DevPreset.pick(class, 60)
			local a = ItemBest.set(pieces, 60, Rarities.MYTHIC, class, uids(), { up = 9 })
			local b = ItemBest.set(pieces, 60, Rarities.MYTHIC, class, uids(), { up = 9 })
			expect(a).toEqual(b)
			local count: { [string]: number } = {}
			local total = 0
			for _, item in a do
				for _, id in item.fx or {} do
					count[id] = (count[id] or 0) + 1
					total += 1
				end
			end
			local distinct = 0
			for _ in count do
				distinct += 1
			end
			-- repeats only once the class's pools run out
			local poolSize = #ItemEffects.pool(class, "legendary") + #ItemEffects.pool(class, "mythic")
			expect(distinct).toBe(math.min(total, poolSize))
		end
	end)

	it("rolls a weapon's effects from its own pool and keeps named items fixed", function()
		local bow = ItemBest.roll("longbow_50", 50, Rarities.MYTHIC, "w", "Hunter")
		for _, id in bow.fx or {} do
			local effect = assert(ItemEffects.resolve(id), id)
			expect(effect.pool == "bow" or effect.pool == "common").toBe(true)
		end
		for id, def in Items.byId do
			if def.fixedBonuses then
				local item = ItemBest.roll(id, def.level, Rarities.MYTHIC, "n", "Warrior")
				expect(item.bonuses).toEqual(def.fixedBonuses)
				break
			end
		end
	end)

	it("keeps the weapon and off-hand types the character uses", function()
		local set = DevPreset.pick("Warrior", 50, { weapon = "axe1h", offhand = "shield" })
		expect(set[1].id).toBe("axe1h_50")
		local hunter = DevPreset.pick("Hunter", 50, { weapon = "sword1h" })
		expect(hunter[1].id).toBe("bow_50")
	end)
end)
