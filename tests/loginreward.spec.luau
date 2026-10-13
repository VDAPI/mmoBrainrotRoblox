--!strict
-- Login reward (S100, docs/DESIGN-15.md §5): the streak, the contents of the days, the chest and the data.
local Blessings = require("../src/shared/Data/Blessings")
local Classes = require("../src/shared/Data/Classes")
local Data = require("../src/shared/Data/LoginReward")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local LoginReward = require("../src/shared/Logic/LoginReward")
local Potions = require("../src/shared/Logic/Potions")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")

local TODAY = 20000
local LEVELS = { 1, 10, 20, 44, 45, 69, 70, 100 }

T.describe("LoginReward: streak", function()
	T.it("sanitizes broken saves", function()
		T.expect(LoginReward.sanitize(nil)).toEqual({ day = 0, last = 0 })
		T.expect(LoginReward.sanitize("x")).toEqual({ day = 0, last = 0 })
		T.expect(LoginReward.sanitize({ day = 3 })).toEqual({ day = 0, last = 0 })
		T.expect(LoginReward.sanitize({ day = 9, last = -3 })).toEqual({ day = 7, last = 0 })
		T.expect(LoginReward.sanitize({ day = 2.7, last = 123.9 })).toEqual({ day = 2, last = 123 })
		T.expect(LoginReward.sanitize({ day = -1, last = 5 })).toEqual({ day = 0, last = 5 })
		T.expect(LoginReward.sanitize({ day = 0 / 0, last = 5 })).toEqual({ day = 0, last = 0 })
	end)

	T.it("a new account claims day 1 once a day", function()
		local state = LoginReward.sanitize(nil)
		local status = LoginReward.status(state, TODAY)
		T.expect(status.claimable).toBe(true)
		T.expect(status.day).toBe(1)
		T.expect(status.resets).toBe(false)
		T.expect(status.claimedToday).toBe(false)
		local after, day = LoginReward.claim(state, TODAY)
		T.expect(after).toEqual({ day = 1, last = TODAY })
		T.expect(day).toBe(1)
		local again, againDay = LoginReward.claim(after :: any, TODAY)
		T.expect(again).toBeNil()
		T.expect(againDay).toBeNil()
	end)

	T.it("seven days in a row give days 1..7, then the streak starts over without a reset", function()
		local state = LoginReward.sanitize(nil)
		for i = 1, 7 do
			local status = LoginReward.status(state, TODAY + i)
			T.expect(status.day).toBe(i)
			T.expect(status.resets).toBe(false)
			local after, day = LoginReward.claim(state, TODAY + i)
			T.expect(day).toBe(i)
			state = after :: any
		end
		local claimed = LoginReward.status(state, TODAY + 7)
		T.expect(claimed.claimedToday).toBe(true)
		T.expect(claimed.nextDay).toBe(1)
		local eighth = LoginReward.status(state, TODAY + 8)
		T.expect(eighth.claimable).toBe(true)
		T.expect(eighth.day).toBe(1)
		T.expect(eighth.resets).toBe(false)
	end)

	T.it("a missed full day resets a running streak", function()
		local broken = LoginReward.status({ day = 3, last = TODAY - 2 }, TODAY)
		T.expect(broken.claimable).toBe(true)
		T.expect(broken.day).toBe(1)
		T.expect(broken.resets).toBe(true)
		local week = LoginReward.status({ day = 7, last = TODAY - 5 }, TODAY)
		T.expect(week.day).toBe(1)
		T.expect(week.resets).toBe(false)
		local zero = LoginReward.status({ day = 0, last = TODAY - 1 }, TODAY)
		T.expect(zero.day).toBe(1)
		T.expect(zero.resets).toBe(false)
		local kept = LoginReward.status({ day = 3, last = TODAY - 1 }, TODAY)
		T.expect(kept.day).toBe(4)
		T.expect(kept.nextDay).toBe(5)
	end)

	T.it("claimed today and a clock moved back give nothing", function()
		local today = LoginReward.status({ day = 4, last = TODAY }, TODAY)
		T.expect(today.claimedToday).toBe(true)
		T.expect(today.claimable).toBe(false)
		T.expect(today.day).toBe(4)
		T.expect(today.nextDay).toBe(5)
		local back = LoginReward.status({ day = 4, last = TODAY + 3 }, TODAY)
		T.expect(back.claimable).toBe(false)
		T.expect((LoginReward.claim({ day = 4, last = TODAY + 3 }, TODAY))).toBeNil()
	end)

	T.it("counts UTC days with Time.dayNumber and Time.nextDayAt", function()
		T.expect(Time.dayNumber(86400 * TODAY - 1)).toBe(TODAY - 1)
		T.expect(Time.dayNumber(86400 * TODAY)).toBe(TODAY)
		T.expect(Time.nextDayAt(86400 * TODAY + 5)).toBe(86400 * (TODAY + 1))
		T.expect(Time.nextDayAt(86400 * TODAY - 1)).toBe(86400 * TODAY)
	end)
end)

T.describe("LoginReward: contents", function()
	T.it("seven valid days for every class and level, no EXP, the chest on day 7", function()
		for _, classId in Classes.order do
			for _, L in LEVELS do
				local week = LoginReward.week(L, classId)
				T.expect(#week).toBe(7)
				for d, day in week do
					T.expect(day.exp).toBe(0)
					T.expect(day.chest).toBe(d == 7)
					for _, entry in day.items do
						if Items.get(entry.id) == nil then
							error(`{classId} L{L} day {d}: unknown item {entry.id}`, 0)
						end
						T.expect(entry.n >= 1).toBe(true)
					end
					T.expect(day).toEqual(LoginReward.contents(d, L, classId))
				end
				local line = LoginReward.lineOf(classId)
				local hasBlessing = false
				for _, entry in week[7].items do
					if entry.id == `blessing_{line}_2` then
						hasBlessing = true
					end
				end
				T.expect(hasBlessing).toBe(true)
			end
		end
	end)

	T.it("days 1-6 give gold, potions, a blessing, essence and Return Stones (DESIGN-15 §5)", function()
		local seen = { gold = false, potion = false, blessing = false, essence = false, stone = false }
		for d = 1, 6 do
			local day = LoginReward.contents(d, 30, "Warrior")
			seen.gold = seen.gold or day.gold > 0
			for _, entry in day.items do
				local def = Items.get(entry.id) :: Items.ItemDef
				if def.use and def.use.kind == "potion" then
					seen.potion = true
				elseif def.use and def.use.kind == "blessing" then
					seen.blessing = true
				elseif entry.id == "stone_return" then
					seen.stone = true
				elseif string.sub(entry.id, 1, 8) == "essence_" then
					seen.essence = true
				end
			end
		end
		T.expect(seen).toEqual({ gold = true, potion = true, blessing = true, essence = true, stone = true })
	end)

	T.it("gold grows with the level in steps of the round unit", function()
		for d = 1, 7 do
			local last = 0
			for L = 1, 100 do
				local gold = LoginReward.goldAt(d, L)
				T.expect(gold >= last).toBe(true)
				T.expect(gold % Data.gold.round).toBe(0)
				if Data.days[d].gold == nil then
					T.expect(gold).toBe(0)
				end
				last = gold
			end
		end
		T.expect(LoginReward.goldAt(2, 50)).toBe(0)
		T.expect(LoginReward.goldAt(1, 50) > 0).toBe(true)
	end)

	T.it("potions the level may drink, of the class resource", function()
		local last = 0
		for L = 1, 100 do
			local q = LoginReward.potionQuality(L)
			T.expect(q >= last).toBe(true)
			last = q
			for _, classId in Classes.order do
				for _, entry in LoginReward.contents(2, L, classId).items do
					T.expect(Potions.canDrink(Items.get(entry.id), L)).toBe(true)
				end
			end
		end
		T.expect(LoginReward.potionQuality(44) < 4).toBe(true)
		T.expect(LoginReward.potionQuality(69) < 5).toBe(true)
		-- final bands (S100 G3): Large from 35, Great from 70, never Mighty
		T.expect(LoginReward.potionQuality(11)).toBe(1)
		T.expect(LoginReward.potionQuality(12)).toBe(2)
		T.expect(LoginReward.potionQuality(59)).toBe(3)
		T.expect(LoginReward.potionQuality(69)).toBe(3)
		T.expect(LoginReward.potionQuality(70)).toBe(4)
		T.expect(LoginReward.potionQuality(100)).toBe(4)
		local expected = { Warrior = "energy", Hunter = "energy", Mage = "mana", Cleric = "mana" }
		for classId, resource in expected do
			local items = LoginReward.contents(2, 40, classId).items
			T.expect(#items).toBe(2)
			T.expect(items[1].id).toBe("potion_hp_3")
			T.expect(items[2].id).toBe(`potion_{resource}_3`)
		end
		T.expect(#LoginReward.contents(2, 40, "Nobody").items).toBe(1)
	end)

	T.it("essence of the level band: dust up to 19, shards from 20", function()
		T.expect(LoginReward.essenceAt(19).item).toBe("essence_dust")
		T.expect(LoginReward.essenceAt(20).item).toBe("essence_shard")
		T.expect(LoginReward.essenceAt(44).item).toBe("essence_shard")
		T.expect(LoginReward.essenceAt(45).item).toBe("essence_shard")
		T.expect(LoginReward.essenceAt(100).item).toBe("essence_shard")
		T.expect(LoginReward.contents(3, 19, "Mage").items[1]).toEqual({ id = "essence_dust", n = 3 })
		T.expect(LoginReward.contents(3, 45, "Mage").items[1]).toEqual({ id = "essence_shard", n = 2 })
	end)

	T.it("the blessing line follows the class and is never fortune", function()
		T.expect(LoginReward.lineOf("Warrior")).toBe("warrior")
		T.expect(LoginReward.lineOf("Hunter")).toBe("hunter")
		T.expect(LoginReward.lineOf("Mage")).toBe("sage")
		T.expect(LoginReward.lineOf("Cleric")).toBe("guardian")
		T.expect(LoginReward.lineOf("Nobody")).toBe("guardian")
	end)
end)

T.describe("LoginReward: chest", function()
	T.it("a Unique or Heroic item the class can wear, of a drop level for the character", function()
		for _, classId in Classes.order do
			for _, L in { 1, 5, 20, 45, 70, 100 } do
				local low, high = ItemRoll.dropLevelRange(L)
				for seed = 1, 50 do
					local drop = LoginReward.rollChest(L, classId, Rng.new(seed))
					if not drop then
						error(`{classId} L{L} seed {seed}: no chest item`, 0)
					end
					T.expect(drop.rarity == Rarities.UNIQUE or drop.rarity == Rarities.HEROIC).toBe(true)
					T.expect(drop.ilvl).toBeBetween(low, high)
					T.expect(drop.forClass).toBe(classId)
					local def = Items.get(drop.defId) :: Items.ItemDef
					T.expect(def.category).toBe("equipment")
					T.expect(def.classes == nil or table.find(def.classes, classId) ~= nil).toBe(true)
					local item =
						ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, Rng.new(seed), "t", drop.forClass)
					T.expect(item.rarity).toBe(drop.rarity)
				end
			end
		end
	end)

	T.it("is deterministic and Heroic with its weight", function()
		T.expect(LoginReward.rollChest(40, "Mage", Rng.new(7))).toEqual(LoginReward.rollChest(40, "Mage", Rng.new(7)))
		local rng = Rng.new(12345)
		local heroic = 0
		local N = 2000
		for _ = 1, N do
			local drop = LoginReward.rollChest(50, "Hunter", rng)
			if drop and drop.rarity == Rarities.HEROIC then
				heroic += 1
			end
		end
		local total = 0
		for _, w in Data.chest.rarity :: { [number]: number } do
			total += w
		end
		local expected = (Data.chest.rarity :: { [number]: number })[Rarities.HEROIC] / total
		T.expect(heroic / N).toBeNear(expected, 0.04)
	end)

	T.it("the fallback is the band's essence twice", function()
		T.expect(LoginReward.chestFallback(10)).toEqual({ id = "essence_dust", n = 6 })
	end)
end)

T.describe("LoginReward: data", function()
	T.it("seven days, one chest, rarities up to Heroic", function()
		T.expect(Data.DAYS).toBe(7)
		T.expect(#Data.days).toBe(7)
		local chests = 0
		for _, day in Data.days do
			chests += if day.chest then 1 else 0
			if day.blessing then
				T.expect(day.blessing).toBeBetween(1, 2)
			end
		end
		T.expect(chests).toBe(1)
		T.expect(2).toBe(Rarities.UNIQUE)
		T.expect(3).toBe(Rarities.HEROIC)
		for rarity, w in Data.chest.rarity :: { [number]: number } do
			T.expect(rarity == Rarities.UNIQUE or rarity == Rarities.HEROIC).toBe(true)
			T.expect(w > 0).toBe(true)
		end
		T.expect(table.isfrozen(Data)).toBe(true)
	end)

	T.it("a blessing line for every class, never fortune", function()
		for _, classId in Classes.order do
			local line = (Data.classLine :: { [string]: string })[classId]
			T.expect(line ~= nil).toBe(true)
			T.expect(line ~= "fortune").toBe(true)
			T.expect(table.find(Blessings.lines, line) ~= nil).toBe(true)
		end
	end)

	T.it("potion and essence bands grow from level 1", function()
		for _, bands in { Data.potionBands :: { any }, Data.essenceBands :: { any } } do
			T.expect(bands[1].from).toBe(1)
			for i = 2, #bands do
				T.expect(bands[i].from > bands[i - 1].from).toBe(true)
			end
			for _, band in bands do
				T.expect(band.n >= 1).toBe(true)
			end
		end
		for _, band in Data.potionBands do
			T.expect(band.quality).toBeBetween(1, 5)
		end
		for _, band in Data.essenceBands do
			T.expect(Items.get(band.item) ~= nil).toBe(true)
		end
	end)
end)
