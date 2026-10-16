--!strict
-- Premium consumables (S122, DESIGN-17 §3): the one place of blocks (Logic/UseBlocks + src/server/UseGuards), the
-- Elixir of Wholeness (Logic/FullElixir) and the Cloak of Luring (Logic/Lure), their data and save fields.
local fs = require("@lune/fs")

local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Auction = require("../src/shared/Logic/Auction")
local Config = require("../src/shared/Config")
local FullElixir = require("../src/shared/Logic/FullElixir")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Items = require("../src/shared/Data/Items")
local Lure = require("../src/shared/Logic/Lure")
local Potions = require("../src/shared/Logic/Potions")
local Products = require("../src/shared/Data/Products")
local Shops = require("../src/shared/Data/Shops")
local T = require("./Test")
local Trade = require("../src/shared/Logic/Trade")
local UseBlocks = require("../src/shared/Logic/UseBlocks")
local UseGuards = require("../src/server/UseGuards")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local DAY = 86400

-- Every .luau file under a directory.
local function sources(dir: string, out: { string }): { string }
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			sources(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
	return out
end

local function candidate(fields: { [string]: any }?): Lure.Candidate
	local c: { [string]: any } = {
		ref = "m",
		group = nil,
		variant = "normal",
		boss = false,
		summoned = false,
		fromSpawner = true,
		passive = false,
		idle = true,
		targetable = true,
		level = 30,
		distance = 10,
		cost = 1,
	}
	for k, v in fields or {} do
		c[k] = v
	end
	return c :: any
end

T.describe("S122 UseBlocks", function()
	T.it("the lists follow DESIGN-17 §3 in order", function()
		T.expect(UseBlocks.LISTS.fullElixir)
			.toEqual({ "dead", "duel", "arena", "dungeon", "pvpLock", "bloodMoon", "tourney" })
		T.expect(UseBlocks.LISTS.lure)
			.toEqual({ "dead", "city", "underground", "redZone", "arena", "tourney", "bloodMoon", "mounted" })
	end)

	T.it("keys, the first active reason and ignored reasons", function()
		T.expect(UseBlocks.key("fullElixir", "duel")).toBe("fullElixir.block.duel")
		T.expect(UseBlocks.key("lure", "city")).toBe("lure.block.city")
		T.expect(UseBlocks.first("fullElixir", { mounted = true, city = true })).toBeNil()
		T.expect(UseBlocks.first("fullElixir", { pvpLock = true, dead = true })).toBe("dead")
		T.expect(UseBlocks.first("lure", { redZone = true, arena = true })).toBe("redZone")
	end)

	T.it("pending and later reasons are on a list; reasons are unique", function()
		local all: { [string]: boolean } = {}
		local reasons = UseBlocks.reasons()
		for _, reason in reasons do
			T.expect({ reason, all[reason] }).toEqual({ reason, nil })
			all[reason] = true
		end
		for reason in UseBlocks.PENDING do
			T.expect({ reason, all[reason] }).toEqual({ reason, true })
		end
		for reason in UseBlocks.LATER do
			T.expect({ reason, all[reason] }).toEqual({ reason, true })
		end
	end)

	T.it("every block has a text in pl and en", function()
		for feature, list in UseBlocks.LISTS do
			for _, reason in list do
				local key = UseBlocks.key(feature :: any, reason)
				T.expect({ key, pl[key] ~= nil, en[key] ~= nil }).toEqual({ key, true, true })
			end
		end
	end)

	T.it("every reason outside PENDING is registered on the server, every pending one is not", function()
		local files = sources("src/server", {})
		local texts: { [string]: string } = {}
		for _, path in files do
			texts[path] = fs.readFile(path)
		end
		for _, reason in UseBlocks.reasons() do
			local needle = `UseGuards.register("{reason}"`
			local found = 0
			for _, text in texts do
				if string.find(text, needle, 1, true) then
					found += 1
				end
			end
			local pending = UseBlocks.PENDING[reason] ~= nil
			if pending and found > 0 then
				error(`{reason}: register the check and remove the reason from UseBlocks.PENDING in the same session`)
			elseif not pending and found == 0 then
				error(`{reason}: no UseGuards.register("{reason}", ...) in src/server`)
			end
		end
	end)

	T.it("only the features ask their own lists, and no server file spells a block text", function()
		local potion = fs.readFile("src/server/Services/PotionService.luau")
		local lure = fs.readFile("src/server/Services/LureService.luau")
		T.expect(string.find(potion, "UseBlocks.LISTS.fullElixir", 1, true) ~= nil).toBe(true)
		T.expect(string.find(lure, "UseBlocks.LISTS.lure", 1, true) ~= nil).toBe(true)
		-- S134d: Auto Potions and Auto Hunt ask their own lists
		local autoPotion = fs.readFile("src/server/Services/AutoPotionService.luau")
		local autoGrind = fs.readFile("src/server/Services/AutoGrindService.luau")
		T.expect(string.find(autoPotion, "UseBlocks.LISTS.autoPotion", 1, true) ~= nil).toBe(true)
		T.expect(string.find(autoGrind, "UseBlocks.LISTS.autoGrind", 1, true) ~= nil).toBe(true)
		for _, path in sources("src/server", {}) do
			local text = fs.readFile(path)
			for _, literal in { '"fullElixir.block.', '"lure.block.', '"autoPotion.block.', '"autoGrind.block.' } do
				if string.find(text, literal, 1, true) then
					error(`{path}: block texts only through UseBlocks.key`)
				end
			end
		end
	end)
end)

T.describe("S122 UseGuards", function()
	local list = UseBlocks.LISTS.fullElixir

	T.it("no check = not blocked; a true check blocks", function()
		UseGuards._reset()
		T.expect(UseGuards.first("p", list)).toBeNil()
		UseGuards.register("duel", function()
			return true
		end, "DuelService")
		T.expect(UseGuards.first("p", list)).toBe("duel")
		UseGuards._reset()
	end)

	T.it("several checks of a reason are OR-ed; the same owner replaces its check", function()
		UseGuards._reset()
		UseGuards.register("arena", function()
			return false
		end, "PvpService")
		UseGuards.register("arena", function()
			return true
		end, "ArenaService")
		T.expect(UseGuards.first("p", list)).toBe("arena")
		UseGuards.register("arena", function()
			return false
		end, "ArenaService")
		T.expect(UseGuards.first("p", list)).toBeNil()
		T.expect(UseGuards.owners("arena")).toEqual({ "PvpService", "ArenaService" })
		UseGuards._reset()
	end)

	T.it("a check that errors blocks (fail closed) and keeps the error", function()
		UseGuards._reset()
		UseGuards.register("pvpLock", function(): boolean
			error("broken")
		end, "PvpService")
		T.expect(UseGuards.first("p", list)).toBe("pvpLock")
		T.expect(type(UseGuards.lastError("pvpLock")) == "string").toBe(true)
		UseGuards._reset()
	end)

	T.it("unregister removes the check; active lists every reason in list order", function()
		UseGuards._reset()
		local off = UseGuards.register("dungeon", function()
			return true
		end, "DungeonService")
		UseGuards.register("dead", function()
			return true
		end, "ResourceService")
		T.expect(UseGuards.active("p", list)).toEqual({ "dead", "dungeon" })
		off()
		T.expect(UseGuards.active("p", list)).toEqual({ "dead" })
		T.expect(UseGuards.owners("dungeon")).toEqual({})
		UseGuards._reset()
	end)

	T.it("the player reaches the check", function()
		UseGuards._reset()
		UseGuards.register("mounted", function(player)
			return player == "rider"
		end, "MountService")
		T.expect(UseGuards.first("rider", UseBlocks.LISTS.lure)).toBe("mounted")
		T.expect(UseGuards.first("walker", UseBlocks.LISTS.lure)).toBeNil()
		UseGuards._reset()
	end)
end)

T.describe("S122 FullElixir", function()
	local missing = { hp = 100, mana = 0, energy = 0 }
	local start = 20000 * DAY + 3600

	T.it("fresh state drinks; the cooldown holds 180 s", function()
		T.expect({ FullElixir.check(FullElixir.EMPTY, start, missing) }).toEqual({ true, nil })
		local after = FullElixir.count(FullElixir.EMPTY, start)
		T.expect({ FullElixir.check(after, start + 179, missing) }).toEqual({ false, "fullElixir.error.cooldown" })
		T.expect({ FullElixir.check(after, start + 180, missing) }).toEqual({ true, nil })
	end)

	T.it("ten a day, a new UTC day starts again", function()
		local state: FullElixir.State = FullElixir.EMPTY
		local t = start
		for _ = 1, Config.FullElixir.dailyLimit do
			T.expect((FullElixir.check(state, t, missing))).toBe(true)
			state = FullElixir.count(state, t)
			t += Config.FullElixir.cooldown
		end
		T.expect(FullElixir.leftToday(state, t)).toBe(0)
		T.expect({ FullElixir.check(state, t, missing) }).toEqual({ false, "fullElixir.error.daily" })
		local tomorrow = (math.floor(start / DAY) + 1) * DAY
		T.expect(FullElixir.usedToday(state, tomorrow)).toBe(0)
		T.expect({ FullElixir.check(state, tomorrow, missing) }).toEqual({ true, nil })
	end)

	T.it("full strength is not needed; cooldown before limit before full", function()
		local none = { hp = 0, mana = 0, energy = 0 }
		T.expect({ FullElixir.check(FullElixir.EMPTY, start, none) }).toEqual({ false, "fullElixir.error.notNeeded" })
		local spent = { day = math.floor(start / DAY), used = Config.FullElixir.dailyLimit, readyAt = start + 10 }
		T.expect({ FullElixir.check(spent, start, none) }).toEqual({ false, "fullElixir.error.cooldown" })
		T.expect({ FullElixir.check(spent, start + 10, none) }).toEqual({ false, "fullElixir.error.daily" })
	end)

	T.it("count never changes its input", function()
		local frozen = table.freeze({ day = 0, used = 0, readyAt = 0 })
		local next = FullElixir.count(frozen, start)
		T.expect(frozen.used).toBe(0)
		T.expect(next.used).toBe(1)
		T.expect(next.readyAt).toBe(start + Config.FullElixir.cooldown)
	end)
end)

T.describe("S122 Lure", function()
	T.it("time: extend, active, parts", function()
		local now = 1000000
		local fresh = Lure.extend({ untilTs = 0, on = false }, 3600, now)
		T.expect(fresh).toEqual({ untilTs = now + 3600, on = true })
		local more = Lure.extend(fresh, 600, now + 100)
		T.expect(more.untilTs).toBe(now + 4200)
		T.expect(Lure.active(more, now + 100)).toBe(true)
		T.expect(Lure.active({ untilTs = more.untilTs, on = false }, now + 100)).toBe(false)
		T.expect(Lure.active(more, now + 4200)).toBe(false)
		T.expect(Lure.left(more, now + 5000)).toBe(0)
		T.expect(Lure.parts(7 * DAY - 60)).toEqual({ d = 6, h = 23, m = 59 })
		T.expect((Lure.timeKey(7 * DAY - 60))).toBe("lure.left.d")
		T.expect((Lure.timeKey(3600))).toBe("lure.left.h")
		T.expect((Lure.timeKey(59 * 60))).toBe("lure.left.m")
		T.expect((Lure.timeKey(30))).toBe("lure.left.s")
	end)

	T.it("eligible: ordinary idle monsters in radius and level gap only", function()
		local refused: { { [string]: any } } = {
			{ variant = "elite" },
			{ variant = "elite2" },
			{ variant = "boss" },
			{ boss = true },
			{ summoned = true },
			{ fromSpawner = false },
			{ passive = true },
			{ idle = false },
			{ targetable = false },
			{ level = 41 },
			{ distance = 25.1 },
		}
		for _, fields in refused do
			T.expect(Lure.eligible(candidate(fields), 30)).toBe(false)
		end
		T.expect(Lure.eligible(candidate({ level = 40, distance = 25 }), 30)).toBe(true)
		T.expect(Lure.eligible(candidate({ level = 20 }), 30)).toBe(true)
	end)

	T.it("pick: the limit counts whole groups, nearest first, deterministic", function()
		T.expect(#Lure.pick({ candidate() }, 30, Config.Lure.maxPulled)).toBe(0)
		local groups = {
			candidate({ ref = "a", group = "g1", cost = 2, distance = 4 }),
			candidate({ ref = "b", group = "g2", cost = 2, distance = 8 }),
			candidate({ ref = "c", group = "g3", cost = 2, distance = 12 }),
			candidate({ ref = "d", group = "g4", cost = 2, distance = 16 }),
		}
		local picked = Lure.pick(groups, 30, 0)
		local refs, total = {}, 0
		for _, c in picked do
			table.insert(refs, c.ref)
			total += c.cost
		end
		T.expect(refs).toEqual({ "a", "b", "c" })
		T.expect(total).toBe(6)
		T.expect(#Lure.pick({ candidate({ group = "big", cost = 7 }) }, 30, 0)).toBe(0)
		local same = Lure.pick({
			candidate({ ref = "x", group = "g", cost = 2, distance = 3 }),
			candidate({ ref = "y", group = "g", cost = 2, distance = 5 }),
		}, 30, 0)
		T.expect(#same).toBe(1)
		T.expect(same[1].ref).toBe("x")
		local again = Lure.pick(groups, 30, 0)
		T.expect(#again).toBe(#picked)
		for i, c in again do
			T.expect(c.ref).toBe(picked[i].ref)
		end
	end)
end)

T.describe("S122 data and save", function()
	T.it("the Elixir of Wholeness item", function()
		local def = Items.get("potion_full")
		assert(def, "potion_full")
		T.expect(def.category).toBe("consumable")
		T.expect(def.use and def.use.kind).toBe("fullElixir")
		T.expect(def.bindOnPickup).toBe(true)
		T.expect(def.noSell).toBe(true)
		T.expect(def.buyPrice).toBeNil()
		for id, shop in Shops.byId do
			for _, entry in shop.entries do
				T.expect({ id, entry.item ~= "potion_full" }).toEqual({ id, true })
			end
		end
		T.expect(Potions.requiredLevel(def)).toBe(1)
	end)

	T.it("bound from creation, refused by trade, auction and merchants", function()
		local stack = ItemRoll.makeStack("potion_full", 5, "x")
		T.expect(stack.bound).toBe(true)
		T.expect(ItemRoll.makeStack("potion_hp_1", 1, "y").bound).toBe(false)
		T.expect({ Trade.canOffer(stack) }).toEqual({ false, "trade.error.bound" })
		local def = Items.get("potion_full") :: any
		T.expect({ Auction.validateListing(stack, def, 100, 24, 0, 100000) }).toEqual({ false, "auction.error.bound" })
		T.expect(ItemValue.canSell(stack, def)).toBe(false)
	end)

	T.it("fits every potion slot; potions fit only their own", function()
		local full = Items.get("potion_full")
		for _, kind in { "hp", "mana", "energy" } do
			T.expect({ kind, Potions.fitsSlot(full, kind) }).toEqual({ kind, true })
		end
		T.expect(Potions.fitsSlot(Items.get("potion_hp_1"), "hp")).toBe(true)
		T.expect(Potions.fitsSlot(Items.get("potion_hp_1"), "mana")).toBe(false)
		T.expect(Potions.fitsSlot(Items.get("scroll_unbind"), "hp")).toBe(false)
	end)

	T.it("shop entries: packs and cloak time", function()
		local five = Products.getShop("potion_full_5")
		local twenty = Products.getShop("potion_full_20")
		local hour = Products.getShop("lure_1h")
		local week = Products.getShop("lure_7d")
		assert(five and twenty and hour and week, "S122 shop entries")
		T.expect({ five.n, five.price, five.itemId }).toEqual({ 5, 120, "potion_full" })
		T.expect({ twenty.n, twenty.price, twenty.itemId }).toEqual({ 20, 400, "potion_full" })
		T.expect({ hour.kind, hour.seconds, hour.price }).toEqual({ "lure", 3600, 150 })
		T.expect({ week.kind, week.seconds, week.price }).toEqual({ "lure", 604800, 990 })
	end)

	T.it("save fields from the templates, no migration", function()
		-- S122 adds no migration: the schema stays at S121's version (S132: 9 = class outfits)
		T.expect(AccountSchema.CURRENT).toBe(9)
		T.expect(AccountSchema.accountTemplate().lure).toEqual({ untilTs = 0, on = false })
		T.expect(AccountSchema.characterTemplate().fullElixir).toEqual({ day = 0, used = 0, readyAt = 0 })
		local old: any = { schema = 9, characters = { ["1"] = { name = "Old", class = "Warrior" } } }
		local applied = AccountSchema.migrate(old)
		T.expect(#applied).toBe(0)
		T.expect(old.lure).toEqual({ untilTs = 0, on = false })
		T.expect(old.characters["1"].fullElixir).toEqual({ day = 0, used = 0, readyAt = 0 })
	end)
end)
