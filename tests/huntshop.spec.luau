--!strict
-- S134k (docs/DESIGN-15.md §3.3): the Huntmaster's shop for Hunter's Marks (Data/HuntShop, Logic/HuntShop): prices and
-- groups, nothing above the loot (no Legendary or Mythic, no equipment, blessings up to Heroic), bound chests, the
-- purchase rule (marks, level, weekly limit and its reset) and no product of the premium shop giving marks.

local Blessings = require("../src/shared/Data/Blessings")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Data = require("../src/shared/Data/HuntShop")
local HuntShop = require("../src/shared/Logic/HuntShop")
local Items = require("../src/shared/Data/Items")
local LoginReward = require("../src/shared/Logic/LoginReward")
local Products = require("../src/shared/Data/Products")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function wallet(marks: number, week: number?, counts: { [string]: number }?): HuntShop.Wallet
	return { marks = marks, shopWeek = { week = week or 0, counts = counts or {} } }
end

describe("Hunt shop: data (S134k)", function()
	it("every entry has a price > 0, a known group and kind, unique keys", function()
		local groups: { [string]: boolean } = {}
		for _, g in Data.GROUPS do
			groups[g] = true
		end
		local seen: { [string]: boolean } = {}
		for _, entry in Data.ENTRIES do
			local where = `HuntShop.{entry.key}`
			expect({ where, entry.price > 0 and entry.price % 1 == 0 }).toEqual({ where, true })
			expect({ where, groups[entry.group] == true }).toEqual({ where, true })
			expect({ where, seen[entry.key] }).toEqual({ where, nil })
			seen[entry.key] = true
			expect(Data.byKey[entry.key]).toBe(entry)
			for _, p in entry.qualityPrices or {} do
				expect({ where, p > 0 }).toEqual({ where, true })
			end
			if entry.weeklyLimit then
				expect({ where, entry.weeklyLimit >= 1 }).toEqual({ where, true })
			end
		end
		-- the owner's list: potions, stones, Fortune blessings, essence with limits, two chests, cosmetics
		for _, key in { "potion_hp", "stone_return", "essence_dust", "essence_shard", "essence_crystal" } do
			expect({ key, Data.byKey[key] ~= nil }).toEqual({ key, true })
		end
		expect(Data.byKey.hunt_chest.price).toBe(60)
		expect(Data.byKey.hunt_chest_heroic.price).toBe(200)
		expect(Data.byKey.hunt_chest_heroic.weeklyLimit).toBe(1)
		for _, key in { "essence_dust", "essence_shard", "essence_crystal" } do
			expect({ key, Data.byKey[key].weeklyLimit ~= nil }).toEqual({ key, true })
		end
	end)

	it("nothing above the loot: no equipment, blessings up to Heroic, chests Unique / Heroic only and bound", function()
		for _, entry in Data.ENTRIES do
			local where = `HuntShop.{entry.key}`
			if entry.kind == "item" then
				local def = Items.get(entry.id) :: any
				expect({ where, def ~= nil }).toEqual({ where, true })
				expect({ where, def.slot }).toEqual({ where, nil })
				expect({ where, (def.rarity or 1) < Rarities.LEGENDARY }).toEqual({ where, true })
				if def.use and def.use.kind == "blessing" then
					local b = Blessings.get(def.use.target)
					expect({ where, b ~= nil and b.rarity <= Rarities.HEROIC }).toEqual({ where, true })
				end
			elseif entry.kind == "chest" then
				local rarity = HuntShop.chestRarity(entry)
				expect({ where, rarity == Rarities.UNIQUE or rarity == Rarities.HEROIC }).toEqual({ where, true })
			elseif entry.kind == "cosmetic" then
				local def = Cosmetics.get(entry.id)
				expect({ where, def and def.obtain and def.obtain.hunt }).toEqual({ where, "shop" })
				expect({ where, def and def.price }).toEqual({ where, 0 })
			else
				expect({ where, entry.kind }).toEqual({ where, "potion" })
			end
		end
		expect(Data.CHEST_BOUND).toBe(true)
		-- every hunt cosmetic is sold here (and only here)
		for _, def in Cosmetics.list do
			if def.obtain and def.obtain.hunt then
				expect({ def.id, Data.byKey[def.id] ~= nil }).toEqual({ def.id, true })
			end
		end
	end)

	it("a chest rolls one item of its rarity for the class and level (the day 7 chest's roll)", function()
		local rng = Rng.new(7)
		for _, rarity in { Rarities.UNIQUE, Rarities.HEROIC } do
			for _, L in { 10, 45, 99 } do
				local drop = LoginReward.rollItem(L, "Mage", rarity, rng)
				assert(drop, `no chest item at {L}`)
				expect(drop.rarity).toBe(rarity)
				expect(drop.forClass).toBe("Mage")
				expect(drop.rarity < Rarities.LEGENDARY).toBe(true)
			end
		end
		-- the login reward's own roll keeps its weights (Unique / Heroic)
		local drop = LoginReward.rollChest(30, "Warrior", Rng.new(3))
		assert(drop, "login chest")
		expect(drop.rarity == Rarities.UNIQUE or drop.rarity == Rarities.HEROIC).toBe(true)
	end)
end)

describe("Hunt shop: rules (Logic/HuntShop)", function()
	it("canBuy: marks, level range, owned cosmetics, amounts", function()
		local dust = Data.byKey.essence_dust
		local shard = Data.byKey.essence_shard
		local chest = Data.byKey.hunt_chest
		local title = Data.byKey.title_bountyhunter
		expect({ HuntShop.canBuy(dust, wallet(100), 10, 5) }).toEqual({ true, nil })
		expect({ HuntShop.canBuy(dust, wallet(dust.price - 1), 10, 5) }).toEqual({ false, "huntshop.error.marks" })
		expect({ HuntShop.canBuy(shard, wallet(100), 44, 5) }).toEqual({ false, "huntshop.error.level" })
		expect({ HuntShop.canBuy(shard, wallet(100), 45, 5) }).toEqual({ true, nil })
		-- the shards stop where the crystal starts
		expect({ HuntShop.canBuy(shard, wallet(100), 70, 5) }).toEqual({ false, "huntshop.error.level" })
		expect(HuntShop.offered(shard, 70)).toBe(false)
		expect({ HuntShop.canBuy(nil, wallet(100), 10, 5) }).toEqual({ false, "error.badRequest" })
		expect({ HuntShop.canBuy(chest, wallet(1000), 50, 5, 2) }).toEqual({ false, "error.badRequest" })
		expect({ HuntShop.canBuy(dust, wallet(1000), 50, 5, 0) }).toEqual({ false, "error.badRequest" })
		expect({ HuntShop.canBuy(dust, wallet(1000), 50, 5, 1.5) }).toEqual({ false, "error.badRequest" })
		expect({ HuntShop.canBuy(title, wallet(1000), 50, 5, 1, { title_bountyhunter = true }) }).toEqual({
			false,
			"huntshop.error.owned",
		})
		expect({ HuntShop.canBuy(title, wallet(1000), 50, 5, 1, {}) }).toEqual({ true, nil })
	end)

	it("the weekly limit counts in its week and starts over in a new one", function()
		local heroic = Data.byKey.hunt_chest_heroic
		local w = wallet(1000, 5)
		expect({ HuntShop.canBuy(heroic, w, 50, 5) }).toEqual({ true, nil })
		local counted = HuntShop.counted(heroic, w, 5, 1)
		expect(counted).toEqual({ week = 5, counts = { hunt_chest_heroic = 1 } })
		local after = { marks = 800, shopWeek = counted }
		expect({ HuntShop.canBuy(heroic, after, 50, 5) }).toEqual({ false, "huntshop.error.weekly" })
		expect(HuntShop.left(heroic, after, 5)).toBe(0)
		-- a new week: the old counter does not count
		expect({ HuntShop.canBuy(heroic, after, 50, 6) }).toEqual({ true, nil })
		expect(HuntShop.boughtThisWeek(heroic, after, 6)).toBe(0)
		expect(HuntShop.counted(heroic, after, 6, 1)).toEqual({ week = 6, counts = { hunt_chest_heroic = 1 } })
		-- an entry without a limit is never counted
		local stone = Data.byKey.stone_return
		expect(HuntShop.counted(stone, after, 5, 3)).toEqual(counted)
		expect(HuntShop.left(stone, after, 5)).toBe(math.huge)
		-- several at once against the limit
		local dust = Data.byKey.essence_dust
		local limit = dust.weeklyLimit :: number
		expect({ HuntShop.canBuy(dust, wallet(1000, 5), 50, 5, limit + 1) }).toEqual({ false, "huntshop.error.weekly" })
	end)

	it("potions of the level's quality at the quality's price, the class resource", function()
		local hp = Data.byKey.potion_hp
		local res = Data.byKey.potion_resource
		for _, L in { 1, 12, 35, 45, 70, 100 } do
			local q = LoginReward.potionQuality(L)
			expect(HuntShop.grant(hp, L, "Warrior")).toEqual({ id = `potion_hp_{q}`, n = hp.n or 1 })
			expect(HuntShop.priceAt(hp, L)).toBe((hp.qualityPrices :: { number })[q])
		end
		expect((HuntShop.grant(res, 50, "Mage") :: any).id).toBe(`potion_mana_{LoginReward.potionQuality(50)}`)
		expect((HuntShop.grant(res, 50, "Warrior") :: any).id).toBe(`potion_energy_{LoginReward.potionQuality(50)}`)
		expect(HuntShop.grant(Data.byKey.hunt_chest, 50, "Mage")).toBeNil()
		expect(HuntShop.priceAt(Data.byKey.hunt_chest, 50)).toBe(60)
		-- the marks a purchase needs follow the price of the level
		local price = HuntShop.priceAt(hp, 70)
		expect({ HuntShop.canBuy(hp, wallet(price - 1), 70, 1) }).toEqual({ false, "huntshop.error.marks" })
		expect({ HuntShop.canBuy(hp, wallet(price), 70, 1) }).toEqual({ true, nil })
	end)
end)

describe("Hunt shop: goods (S134k)", function()
	it("a merchant pays nothing for what marks bought, and those stacks stay apart", function()
		local Inventory = require("../src/shared/Logic/Inventory")
		local ItemRoll = require("../src/shared/Logic/ItemRoll")
		local ItemValue = require("../src/shared/Logic/ItemValue")
		local bought = ItemRoll.makeStack("potion_hp_3", 5, "a")
		bought.bound = true
		bought.ns = true
		local looted = ItemRoll.makeStack("potion_hp_3", 5, "b")
		looted.bound = true
		expect(ItemValue.canSell(bought)).toBe(false)
		expect(ItemValue.sellPrice(bought)).toBe(0)
		expect(ItemValue.canSell(looted)).toBe(true)
		expect(Inventory.canMerge(bought, looted)).toBe(false)
		local twin = ItemRoll.makeStack("potion_hp_3", 2, "c")
		twin.bound = true
		twin.ns = true
		expect(Inventory.canMerge(bought, twin)).toBe(true)
	end)
end)

describe("Hunt shop: never sold (S134k, DESIGN-17 §0.2)", function()
	-- every key and string value under a product: no marks, no hunt cosmetic
	local function noMarks(value: any, where: string, seen: { [any]: boolean }?)
		if type(value) ~= "table" then
			if type(value) == "string" then
				local def = Cosmetics.get(value)
				if def and def.obtain and def.obtain.hunt then
					error(`{where}: gives the hunt cosmetic {value}`, 0)
				end
			end
			return
		end
		local visited = seen or {}
		if visited[value] then
			return
		end
		visited[value] = true
		for k, v in value do
			if type(k) == "string" then
				local lower = string.lower(k)
				if lower == "marks" or lower == "huntmarks" then
					error(`{where}.{k}: Hunter's Marks are never sold`, 0)
				end
			end
			noMarks(v, `{where}.{tostring(k)}`, visited)
		end
	end

	it("no product, pass, subscription, starter pack or mount gives Hunter's Marks or a hunt cosmetic", function()
		local raw: any = Products
		for _, field in { "shop", "passes", "subscriptions", "starterPacks", "mounts" } do
			noMarks(raw[field] or {}, `Products.{field}`)
		end
	end)
end)

return nil
