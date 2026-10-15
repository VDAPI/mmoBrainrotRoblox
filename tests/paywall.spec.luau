--!strict
-- No pay-to-win (DESIGN-17 §0.2, §1; S120). Every later session that sells something extends these lists with a
-- reason; nothing bought with Robux or Dragon Currency may give stats, EXP, gold, drops, upgrade materials or
-- blessings (DESIGN-17 §0.2). The lists are allowlists: anything not named here fails.

local Blessings = require("../src/shared/Data/Blessings")
local Config = require("../src/shared/Config")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Items = require("../src/shared/Data/Items")
local Mounts = require("../src/shared/Data/Mounts")
local Auction = require("../src/shared/Logic/Auction")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local ItemValue = require("../src/shared/Logic/ItemValue")
local Lure = require("../src/shared/Logic/Lure")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local Shops = require("../src/shared/Data/Shops")
local T = require("./Test")
local Trade = require("../src/shared/Logic/Trade")
local UseBlocks = require("../src/shared/Logic/UseBlocks")

-- Passes (Products.passes): key -> why it is not pay-to-win.
local ALLOWED_PASSES: { [string]: string } = {
	autoLoot = "comfort: picks up bags in range",
	vault = "space: deposit slots",
	fastRespawn = "time: shorter respawn",
	vip = "VIP forever (switched off): the VIP benefits below, looks and comfort only",
	pockets = "space: +10 backpack slots (S121)",
	slot4 = "account: a fourth character slot (S121)",
	slot5 = "account: a fifth character slot (S121)",
	wardrobePlus = "looks: five saved looks (S121)",
}
local ALLOWED_SUBSCRIPTIONS: { [string]: string } = { vip = "comfort and looks, DESIGN-17 §2" }
-- S121: Config.Vip keys -> why (statusRefresh is a technical re-check interval, not a benefit).
local ALLOWED_VIP_KEYS: { [string]: string } = {
	dailyShards = "premium currency: buys only what passes this test",
	auctionExtraListings = "comfort: more listings at once",
	auctionFeeMul = "comfort: a lower sale fee, fixed on the listing",
	freeRecallCooldown = "travel: the Stone of Return's channel without a stone",
	freeRespawnsPerDay = "time: an instant respawn once a day",
	statusRefresh = "technical: subscription re-check interval",
}
local VIP_POWER_WORDS = { "exp", "gold", "drop", "luck", "stat", "dmg", "hp" }
local ALLOWED_SHOP_KINDS: { [string]: string } = {
	item = "an item, checked below",
	rename = "a service",
	lure = "DESIGN-17 §0.2/§3: faster farming without strength (Cloak of Luring)",
}
local ALLOWED_ITEM_CATEGORIES: { [string]: string } = {
	scroll = "resets and unbinding (protection only with a daily limit of 1)",
	backpack = "space: capacity only, no stats",
	stone = "travel: teleport",
}
local ALLOWED_USE_KINDS: { [string]: string } =
	{ scroll = "see ALLOWED_SCROLLS", teleport = "travel", none = "no effect" }
local ALLOWED_SCROLLS: { [string]: string } = {
	oblivion = "redistributes own stat points",
	skillreset = "redistributes own skill points",
	unbind = "trade comfort",
	protection = "EXCEPTION: keeps the upgrade level on a failure; dailyLimit must be 1 (DESIGN-17 §1)",
}
-- item id -> reason (DESIGN-17 §3). Never add "fullElixir" to ALLOWED_USE_KINDS: every future item of that kind
-- would pass without an exception.
local EXCEPTIONS: { [string]: string } = {
	potion_full = "DESIGN-17 §0.2/§3: healing outside fights with players and bosses",
}
local ALLOWED_COSMETIC_KINDS: { [string]: string } = {
	outfit = "looks",
	aura = "looks",
	trail = "looks",
	weapon = "looks",
	pet = "looks",
	mountskin = "looks (S97)",
	-- S123: looks only, DESIGN-17 §4
	dye = "looks only, DESIGN-17 §4: the worn outfit's colours",
	frame = "looks only, DESIGN-17 §4: a frame around the portrait",
	chatframe = "looks only, DESIGN-17 §4: the name's frame in chat and the bubble",
	title = "looks only, DESIGN-17 §4: a name over the head, nothing else",
	emote = "looks only, DESIGN-17 §4: a gesture, never in combat",
	levelup = "looks only, DESIGN-17 §4: the level-up picture",
}
-- S123: passes a starter pack may grant in the profile (comfort, DESIGN-17 §0.2).
local PACK_PASSES_ALLOWED: { [string]: string } = { pockets = "space: +10 backpack slots" }
-- Top-level fields a cosmetic may have (Data/Cosmetics.Def); `wiki` is the S105 publication flag.
local COSMETIC_FIELDS = {
	id = true,
	kind = true,
	nameKey = true,
	price = true,
	icon = true,
	color = true,
	color2 = true,
	parts = true,
	look = true,
	flies = true,
	skin = true,
	obtain = true,
	wiki = true,
	-- S123
	frame = true,
	chat = true,
	title = true,
	emote = true,
	levelup = true,
	dye = true,
	weekly = true,
	free = true,
}
local FORBIDDEN_KEYS = {
	"exp",
	"xp",
	"gold",
	"stats",
	"bonuses",
	"fixedBonuses",
	"base",
	"weapon",
	"bonusGroup",
	"drop",
	"dropMul",
	"expMul",
	"goldMul",
	"luck",
	"blessing",
	"dmg",
	"hp",
	"mana",
}

-- Whether the item `id` may be sold for Robux or Dragon Currency; the reason names the id when not.
local function allowedItem(id: string): (boolean, string?)
	local def = Items.get(id)
	if not def then
		return false, `{id}: not an item`
	end
	if EXCEPTIONS[id] then
		return true, nil
	end
	if not ALLOWED_ITEM_CATEGORIES[def.category] then
		return false, `{id}: category {def.category} is not allowed`
	end
	local raw = def :: any
	for _, field in { "base", "weapon", "bonusGroup", "fixedBonuses", "trait" } do
		if raw[field] ~= nil then
			return false, `{id}: has {field}`
		end
	end
	if def.slot ~= nil and def.slot ~= "backpack" then
		return false, `{id}: equips in {def.slot}`
	end
	local use = def.use
	if use then
		if not ALLOWED_USE_KINDS[use.kind] then
			return false, `{id}: use {use.kind} is not allowed`
		end
		if use.kind == "scroll" and not (use.target and ALLOWED_SCROLLS[use.target]) then
			return false, `{id}: scroll {tostring(use.target)} is not allowed`
		end
	end
	return true, nil
end

local function expectAllowed(id: string, where: string)
	local ok, why = allowedItem(id)
	if not ok then
		error(`{where}: {why}`)
	end
end

local function isInt(n: any): boolean
	return type(n) == "number" and n == math.floor(n)
end

local function fieldsWithin(record: { [string]: any }, allowed: { [string]: boolean }, where: string)
	for k in record do
		if not allowed[k] then
			error(`{where}: field {k} is not allowed`)
		end
	end
end

local forbidden: { [string]: boolean } = {}
for _, key in FORBIDDEN_KEYS do
	forbidden[key] = true
end

-- Every table key under `value` (skipping the look subtrees `skip`), with its full path.
local function scan(value: any, path: string, skip: { [string]: boolean }?, seen: { [any]: boolean }?)
	if type(value) ~= "table" then
		return
	end
	local visited = seen or {}
	if visited[value] then
		return
	end
	visited[value] = true
	for k, v in value do
		local p = `{path}.{tostring(k)}`
		if type(k) == "string" and forbidden[k] then
			error(`{p}: forbidden key {k} (DESIGN-17 §0.2)`)
		end
		if not (type(k) == "string" and skip and skip[k]) then
			scan(v, p, skip, visited)
		end
	end
end

local raw = Products :: any
-- S121 / S123 fill these lists (DESIGN-17 §2, §4).
local subscriptions: { any } = raw.subscriptions or {}
local starterPacks: { any } = raw.starterPacks or {}

T.describe("Paywall (S120, DESIGN-17 §0.2)", function()
	T.it("1. every shop entry is an allowed kind, item and limit", function()
		local cats: { [string]: boolean } = {}
		for _, cat in Products.shopCats do
			cats[cat] = true
		end
		for _, entry in Products.shop do
			local where = `shop.{entry.key}`
			if not ALLOWED_SHOP_KINDS[entry.kind] then
				error(`{where}: kind {entry.kind} is not allowed`)
			end
			if not cats[entry.cat] then
				error(`{where}: cat {tostring(entry.cat)} is not in Products.shopCats`)
			end
			T.expect({ where, entry.price > 0 }).toEqual({ where, true })
			if entry.itemId then
				expectAllowed(entry.itemId, where)
			end
			for _, limit in { entry.dailyLimit, entry.weeklyLimit } do
				if limit ~= nil and not (isInt(limit) and limit >= 1) then
					error(`{where}: limits are whole numbers >= 1`)
				end
			end
		end
	end)

	T.it("2. the Scroll of Protection is 1 a day", function()
		local found = 0
		for _, entry in Products.shop do
			local def = entry.itemId and Items.get(entry.itemId)
			if def and def.use and def.use.target == "protection" then
				found += 1
				if entry.dailyLimit ~= 1 then
					error(`shop.{entry.key}: DESIGN-17 §1: Scroll of Protection is 1 a day`)
				end
			end
		end
		T.expect(found).toBe(1)
	end)

	T.it("3. the item checker refuses power and accepts comfort", function()
		local refused = {
			Items.startingGear.Warrior[1],
			Blessings.list[1].itemId,
			"elixir_resFire",
			"potion_hp_1",
		}
		for _, id in { "wolf_pelt", "essence_shard", "legend_core" } do
			if Items.get(id) then
				table.insert(refused, id)
			end
		end
		T.expect(#refused >= 6).toBe(true)
		for _, id in refused do
			local ok, why = allowedItem(id)
			T.expect({ id, ok }).toEqual({ id, false })
			T.expect(type(why) == "string" and string.find(why :: string, id, 1, true) ~= nil).toBe(true)
		end
		for _, id in { "scroll_unbind", "backpack_premium_100", "stone_return" } do
			T.expect({ id, (allowedItem(id)) }).toEqual({ id, true })
		end
	end)

	T.it("4. every pass is allowed and carries only its fields", function()
		local fields = { key = true, passId = true, robux = true, icon = true, enabled = true, requires = true }
		for _, pass in Products.passes do
			local where = `passes.{pass.key}`
			if not ALLOWED_PASSES[pass.key] then
				error(`{where}: not in ALLOWED_PASSES`)
			end
			fieldsWithin(pass :: any, fields, where)
		end
	end)

	T.it("5. currency packs and the respawn give only what they say", function()
		for _, pack in Products.shardPacks do
			fieldsWithin(
				pack :: any,
				{ key = true, productId = true, shards = true, robux = true },
				`shardPacks.{pack.key}`
			)
		end
		fieldsWithin(Products.respawn :: any, { key = true, productId = true, robux = true }, "respawn")
	end)

	T.it("6. future subscriptions and starter packs", function()
		for _, sub in subscriptions do
			if not ALLOWED_SUBSCRIPTIONS[sub.key] then
				error(`subscriptions.{tostring(sub.key)}: not in ALLOWED_SUBSCRIPTIONS`)
			end
		end
		for i, pack in starterPacks do
			local where = `starterPacks.{tostring(pack.key or i)}`
			scan(pack, where)
			local function items(value: any)
				if type(value) == "string" and Items.get(value) then
					expectAllowed(value, where)
				elseif type(value) == "table" then
					for _, v in value do
						items(v)
					end
				end
			end
			items(pack)
		end
	end)

	T.it("7. premium mounts start no higher than the boss mounts (S97, mounts.spec)", function()
		local bossTop = 0
		for _, def in Mounts.list do
			if def.source == "boss" then
				bossTop = math.max(bossTop, def.startLevel)
			end
		end
		T.expect(bossTop > 0).toBe(true)
		for _, entry in Products.mounts do
			local def = Mounts.get(entry.mount)
			if not def then
				error(`mounts.{entry.key}: unknown mount {entry.mount}`)
			end
			T.expect({ entry.key, def.source }).toEqual({ entry.key, "premium" })
			T.expect({ entry.key, def.startLevel <= bossTop }).toEqual({ entry.key, true })
		end
	end)

	T.it("8. no forbidden key anywhere in what is sold", function()
		scan(Products.shop, "shop")
		scan(Products.passes, "passes")
		scan(Products.shardPacks, "shardPacks")
		scan(Products.respawn, "respawn")
		scan(Products.mounts, "mounts")
		scan(subscriptions, "subscriptions")
		scan(starterPacks, "starterPacks")
		-- look and skin describe the appearance (colours, parts, bones)
		for _, def in Cosmetics.list do
			scan(def, `cosmetics.{def.id}`, { look = true, skin = true })
		end
	end)

	T.it("9. cosmetics are looks only", function()
		for _, def in Cosmetics.list do
			local where = `cosmetics.{def.id}`
			if not ALLOWED_COSMETIC_KINDS[def.kind] then
				error(`{where}: kind {def.kind} is not in ALLOWED_COSMETIC_KINDS`)
			end
			fieldsWithin(def :: any, COSMETIC_FIELDS, where)
			T.expect({ where, def.price >= 0 }).toEqual({ where, true })
		end
	end)

	T.it("10. every allowance has a reason", function()
		local lists: { [string]: { [string]: string } } = {
			ALLOWED_PASSES = ALLOWED_PASSES,
			ALLOWED_SUBSCRIPTIONS = ALLOWED_SUBSCRIPTIONS,
			ALLOWED_SHOP_KINDS = ALLOWED_SHOP_KINDS,
			ALLOWED_ITEM_CATEGORIES = ALLOWED_ITEM_CATEGORIES,
			ALLOWED_USE_KINDS = ALLOWED_USE_KINDS,
			ALLOWED_SCROLLS = ALLOWED_SCROLLS,
			EXCEPTIONS = EXCEPTIONS,
			ALLOWED_COSMETIC_KINDS = ALLOWED_COSMETIC_KINDS,
			ALLOWED_VIP_KEYS = ALLOWED_VIP_KEYS,
			PACK_PASSES_ALLOWED = PACK_PASSES_ALLOWED,
		}
		for name, list in lists do
			for key, why in list do
				if type(why) ~= "string" or why == "" then
					error(`{name}.{key}: no reason`)
				end
			end
		end
	end)
end)

T.describe("S122 premium consumables", function()
	local function has(list: { string }, reason: string): boolean
		return table.find(list, reason) ~= nil
	end

	T.it("the Elixir of Wholeness is bound, never sold, traded or listed and has no power", function()
		local def = Items.get("potion_full")
		assert(def, "potion_full")
		local raw = def :: any
		T.expect(def.use and def.use.kind).toBe("fullElixir")
		T.expect(def.bindOnPickup).toBe(true)
		T.expect(def.noSell).toBe(true)
		for _, field in { "fixedBonuses", "bonusGroup", "base", "weapon", "trait" } do
			T.expect({ field, raw[field] }).toEqual({ field, nil })
		end
		for id, shop in Shops.byId do
			for _, entry in shop.entries do
				T.expect({ id, entry.item ~= "potion_full" }).toEqual({ id, true })
			end
		end
		local stack = ItemRoll.makeStack("potion_full", 1, "paywall")
		T.expect(stack.bound).toBe(true)
		T.expect({ Trade.canOffer(stack) }).toEqual({ false, "trade.error.bound" })
		T.expect({ Auction.validateListing(stack, def :: any, 100, 24, 0, 100000) }).toEqual({
			false,
			"auction.error.bound",
		})
		T.expect(ItemValue.canSell(stack, def)).toBe(false)
		T.expect(ALLOWED_USE_KINDS.fullElixir).toBeNil()
	end)

	T.it("the elixir never works against players or bosses", function()
		T.expect(Config.FullElixir.cooldown >= 180).toBe(true)
		T.expect(Config.FullElixir.dailyLimit <= 10).toBe(true)
		for _, reason in { "duel", "arena", "dungeon", "pvpLock", "bloodMoon", "tourney" } do
			if not has(UseBlocks.LISTS.fullElixir, reason) then
				error(`{reason}: DESIGN-17 §3: the elixir must never work against players or bosses`)
			end
		end
	end)

	T.it("the Cloak of Luring: limits, places and ordinary monsters only", function()
		T.expect(Config.Lure.maxPulled <= 6).toBe(true)
		T.expect(Config.Lure.radius <= 25).toBe(true)
		T.expect(Config.Lure.levelGap <= 10).toBe(true)
		T.expect(Config.Lure.interval >= 8).toBe(true)
		for _, reason in { "city", "underground", "redZone", "arena", "bloodMoon", "mounted", "dead" } do
			if not has(UseBlocks.LISTS.lure, reason) then
				error(`{reason}: DESIGN-17 §3: the cloak must not work there`)
			end
		end
		local base: { [string]: any } = {
			ref = 1,
			variant = "normal",
			boss = false,
			summoned = false,
			fromSpawner = true,
			passive = false,
			idle = true,
			targetable = true,
			level = 30,
			distance = 5,
			cost = 1,
		}
		T.expect(Lure.eligible(base :: any, 30)).toBe(true)
		for _, change in
			{
				{ variant = "elite" },
				{ variant = "elite2" },
				{ variant = "boss" },
				{ boss = true },
				{ summoned = true },
				{ fromSpawner = false },
			} :: { { [string]: any } }
		do
			local c = table.clone(base)
			for k, v in change do
				c[k] = v
			end
			T.expect(Lure.eligible(c :: any, 30)).toBe(false)
		end
	end)

	T.it("one item of kind fullElixir and two lure entries, without items", function()
		local elixirs = {}
		for id, def in Items.byId do
			if def.use and def.use.kind == "fullElixir" then
				table.insert(elixirs, id)
			end
		end
		T.expect(elixirs).toEqual({ "potion_full" })
		local lures = {}
		for _, entry in Products.shop do
			if entry.kind == "lure" then
				table.insert(lures, entry.key)
				T.expect({ entry.key, (entry.seconds or 0) > 0, entry.itemId }).toEqual({ entry.key, true, nil })
			end
		end
		table.sort(lures)
		T.expect(lures).toEqual({ "lure_1h", "lure_7d" })
	end)
end)

T.describe("S123 cosmetics 2 and starter packs", function()
	local Emotes = require("../src/shared/Data/Emotes")
	local TitleData = require("../src/shared/Data/Titles")

	T.it("bought titles and title cosmetics point at each other and carry only a name", function()
		local byTitle: { [string]: string } = {}
		for _, def in Cosmetics.list do
			if def.kind == "title" then
				T.expect({ def.id, def.title ~= nil }).toEqual({ def.id, true })
				byTitle[def.title :: string] = def.id
			end
		end
		local n = 0
		for _, def in TitleData.list do
			local req: any = def.req
			if req.kind == "cosmetic" then
				n += 1
				local where = `titles.{def.id}`
				T.expect({ where, byTitle[def.id] }).toEqual({ where, req.id })
				fieldsWithin(def :: any, { id = true, nameKey = true, req = true, color = true }, where)
				fieldsWithin(req, { kind = true, id = true }, `{where}.req`)
			end
		end
		local m = 0
		for _ in byTitle do
			m += 1
		end
		T.expect(n).toBe(m)
	end)

	T.it("starter packs give shards, existing cosmetics and comfort passes only", function()
		T.expect(#starterPacks >= 2).toBe(true)
		local fields = {
			key = true,
			productId = true,
			robux = true,
			shards = true,
			cosmetics = true,
			passes = true,
			icon = true,
		}
		local fromPack: { [string]: string } = {}
		for _, pack in starterPacks do
			local where = `starterPacks.{pack.key}`
			fieldsWithin(pack, fields, where)
			T.expect({ where, isInt(pack.shards) and pack.shards > 0 }).toEqual({ where, true })
			for _, id in pack.cosmetics do
				local def = Cosmetics.get(id)
				if not def then
					error(`{where}: unknown cosmetic {id}`)
				end
				T.expect({ id, ALLOWED_COSMETIC_KINDS[def.kind] ~= nil }).toEqual({ id, true })
				T.expect({ id, fromPack[id] }).toEqual({ id, nil })
				fromPack[id] = pack.key
			end
			for _, key in pack.passes do
				if not PACK_PASSES_ALLOWED[key] then
					error(`{where}: pass {key} is not in PACK_PASSES_ALLOWED`)
				end
				T.expect({ key, Products.getPass(key) ~= nil }).toEqual({ key, true })
			end
		end
		-- obtain.pack <-> the pack that gives it
		for _, def in Cosmetics.list do
			local pack = def.obtain and def.obtain.pack
			if pack then
				T.expect({ def.id, fromPack[def.id] }).toEqual({ def.id, pack })
				fieldsWithin(def.obtain :: any, { pack = true }, `cosmetics.{def.id}.obtain`)
			end
		end
		for id, key in fromPack do
			local def = Cosmetics.get(id) :: Cosmetics.Def
			T.expect({ id, def.obtain and def.obtain.pack }).toEqual({ id, key })
		end
	end)

	T.it("emotes have no combat events", function()
		for _, emote in Emotes.list do
			local raw = emote.motion :: any
			for _, event in { "hit", "release", "land", "lock" } do
				T.expect({ emote.id, event, raw[event] }).toEqual({ emote.id, event, nil })
			end
		end
	end)

	T.it("shard prices live in Data/Cosmetics only, one discount of at most half", function()
		local fs = require("@lune/fs")
		for _, path in { "src/shared/Logic/WeeklyOffer.luau", "src/shared/Logic/CosmeticRules.luau" } do
			local source = fs.readFile(path)
			T.expect({ path, string.find(source, "price%s*=%s*%d") }).toEqual({ path })
		end
		local weekly = Cosmetics.weekly
		T.expect(type(weekly.discount)).toBe("number")
		T.expect(weekly.discount >= 0 and weekly.discount <= 0.5).toBe(true)
		local free = 0
		for _, def in Cosmetics.list do
			if def.free == true then
				free += 1
				T.expect({ def.id, def.kind, def.price, def.weekly }).toEqual({ def.id, "emote", 0, nil })
			end
		end
		T.expect(free).toBe(2)
	end)
end)

T.describe("S121 VIP and passes", function()
	T.it("subscriptions are allowed and carry only their fields", function()
		T.expect(#subscriptions >= 1).toBe(true)
		for _, sub in subscriptions do
			local where = `subscriptions.{tostring(sub.key)}`
			if not ALLOWED_SUBSCRIPTIONS[sub.key] then
				error(`{where}: not in ALLOWED_SUBSCRIPTIONS`)
			end
			T.expect({ where, type(sub.subscriptionId) }).toEqual({ where, "string" })
			fieldsWithin(sub, { key = true, subscriptionId = true, enabled = true }, where)
		end
	end)

	T.it("Config.Vip has exactly the allowed keys and no power", function()
		for key in Config.Vip :: any do
			if not ALLOWED_VIP_KEYS[key] then
				error(`Config.Vip.{key}: not in ALLOWED_VIP_KEYS`)
			end
			if key ~= "statusRefresh" then
				local lower = string.lower(key)
				for _, word in VIP_POWER_WORDS do
					if string.find(lower, word, 1, true) then
						error(`Config.Vip.{key}: contains "{word}" (DESIGN-17 §0.2)`)
					end
				end
			end
		end
		for key in ALLOWED_VIP_KEYS do
			T.expect({ key, (Config.Vip :: any)[key] ~= nil }).toEqual({ key, true })
		end
		T.expect(Config.Vip.auctionFeeMul > 0 and Config.Vip.auctionFeeMul <= 1).toBe(true)
	end)

	T.it("passes: requires and slot passes point at real passes", function()
		for _, pass in Products.passes do
			if pass.requires ~= nil then
				T.expect({ pass.key, Products.getPass(pass.requires) ~= nil }).toEqual({ pass.key, true })
			end
		end
		for slot, keys in Products.SLOT_PASSES do
			for _, key in keys do
				T.expect({ slot, key, ALLOWED_PASSES[key] ~= nil }).toEqual({ slot, key, true })
			end
		end
	end)

	T.it("the cosmetics of the month are looks, never sold", function()
		local n = 0
		for _, def in Cosmetics.list do
			local obtain = def.obtain
			if obtain and obtain.vipMonth then
				n += 1
				local where = `cosmetics.{def.id}`
				T.expect({ where, ALLOWED_COSMETIC_KINDS[def.kind] ~= nil }).toEqual({ where, true })
				T.expect({ where, def.price }).toEqual({ where, 0 })
				fieldsWithin(def :: any, COSMETIC_FIELDS, where)
				fieldsWithin(obtain :: any, { boss = true, quest = true, vipMonth = true }, `{where}.obtain`)
				scan(def, where, { look = true, skin = true })
				T.expect({ where, Premium.canBuyCosmetic(def.id, {}, 1e9) }).toEqual({
					where,
					false,
					"premium.error.notForSale",
				})
			end
		end
		T.expect(n).toBe(6)
	end)

	T.it("Logic/Vip requires no power module", function()
		local fs = require("@lune/fs")
		local source = fs.readFile("src/shared/Logic/Vip.luau")
		local allowed = {
			["../Config"] = true,
			["../Data/Cosmetics"] = true,
			["../Data/Market"] = true, -- the auction fee for the benefit row
			["../Data/Recipes"] = true, -- the alchemist queue sizes for the benefit row
			["./Time"] = true,
			["../Types"] = true,
		}
		for path in string.gmatch(source, 'require%("([^"]+)"%)') do
			if not allowed[path] then
				error(`Logic/Vip requires {path}: not in the allowed list`)
			end
		end
	end)
end)

-- S124 (DESIGN-17 §0.2, §5): a leaderboard score depends on the character only. Every scorer is listed here (S125+
-- add theirs with a comment); none may read the account, purchases, VIP, passes or shards.
local ALLOWED_SCORERS: { [string]: string } = { level = "level, EXP and the moment of the top level (S124)" }

T.describe("Rankings (S124)", function()
	local Leaderboard = require("../src/shared/Logic/Leaderboard")
	local Leaderboards = require("../src/shared/Data/Leaderboards")

	T.it("every scorer is on the allowed list and every board's scorer exists", function()
		for name in Leaderboard.SCORERS do
			if not ALLOWED_SCORERS[name] then
				error(`Leaderboard.SCORERS.{name}: not in ALLOWED_SCORERS`)
			end
		end
		for _, def in Leaderboards.list do
			if def.score then
				T.expect({ def.id, Leaderboard.SCORERS[def.score] ~= nil }).toEqual({ def.id, true })
			end
		end
	end)

	T.it("a score depends only on the character, never on what the account bought", function()
		local now = 1791763200
		local character = { id = "c1", name = "Aria", class = "Mage", level = 63, exp = 4321, gold = 10 }
		local bought = table.clone(character) :: any
		bought.title = "title_highborn"
		bought.guildId = "g1"
		bought.gold = 1e12
		bought.fullElixir = { day = 1, used = 10, readyAt = 0 }
		bought.equipment = { weapon = { id = "sword", rarity = 5, up = 9 } }
		local trap = setmetatable({}, {
			__index = function()
				error("scorer read the account")
			end,
		})
		for name, scorer in Leaderboard.SCORERS do
			local plain = (scorer :: any)(character, now, trap)
			T.expect({ name, plain }).toEqual({ name, (scorer :: any)(bought, now, trap) })
			T.expect({ name, type(plain) }).toEqual({ name, "number" })
		end
	end)
end)

-- S125 (DESIGN-17 §0.2, §5): the weekly ranking counts EXP from an allowlist of game sources, the guild board the
-- member levels only; boards without a scorer are fed by LeaderboardService and listed here (S126+ add theirs).
local SERVICE_BOARDS: { [string]: string } = {
	exp_week = "weekly EXP from Data/Leaderboards.WEEK_SOURCES (S125)",
	guild = "the sum of the highest member levels, Logic/Leaderboard.guildScore (S125)",
	arena = "the 1v1 arena rating from match results only, Logic/ArenaRules.applyResult (S126)",
	arena3 = "the 3v3 arena rating from match results only, Logic/ArenaRules.applyResult (S128)",
}
local SOURCE_WORDS = { "premium", "shop", "purchase", "product", "admin", "robux", "shard" }

T.describe("S125 rankings", function()
	local Leaderboard = require("../src/shared/Logic/Leaderboard")
	local Leaderboards = require("../src/shared/Data/Leaderboards")
	local Mail = require("../src/shared/Logic/Mail")

	T.it("weekly EXP sources are game sources, never a product, a pass or an admin command", function()
		local productKeys: { [string]: boolean } = {}
		for _, list in
			{ Products.shop, Products.passes, subscriptions, starterPacks, raw.shardPacks or {}, raw.mounts or {} }
		do
			for _, entry in list :: { any } do
				productKeys[entry.key] = true
			end
		end
		for source, on in Leaderboards.WEEK_SOURCES do
			T.expect({ source, on }).toEqual({ source, true })
			T.expect({ source, productKeys[source] == nil }).toEqual({ source, true })
			local lower = string.lower(source)
			for _, word in SOURCE_WORDS do
				T.expect({ source, word, string.find(lower, word, 1, true) == nil }).toEqual({ source, word, true })
			end
		end
		T.expect(Leaderboard.countsForWeek("admin")).toBe(false)
	end)

	T.it("every board is scored by an allowed scorer or listed as fed by a service", function()
		for _, def in Leaderboards.list do
			if def.kind == "list" then
				continue
			end
			if def.score then
				T.expect({ def.id, ALLOWED_SCORERS[def.score] ~= nil }).toEqual({ def.id, true })
			else
				T.expect({ def.id, SERVICE_BOARDS[def.id] ~= nil }).toEqual({ def.id, true })
			end
		end
		for id in SERVICE_BOARDS do
			T.expect({ id, Leaderboards.get(id) ~= nil }).toEqual({ id, true })
		end
	end)

	T.it("the guild score depends only on the member levels", function()
		local function guild(treasury: number, skills: { [string]: number }): any
			return {
				members = { a = { level = 40, contributed = 9 }, b = { level = 55 }, c = { level = 12 } },
				treasury = treasury,
				skills = skills,
			}
		end
		local poor = guild(0, {})
		local rich = guild(1e9, { wealth = 5, might = 5 })
		T.expect(Leaderboard.guildScore(poor.members)).toBe(Leaderboard.guildScore(rich.members))
		T.expect(Leaderboard.guildScore(rich.members)).toBe(107)
	end)

	T.it("rewards are shards and a timed title only, and players cannot mail shards", function()
		local rewards = Leaderboards.WEEK_REWARDS :: any
		local fields = {}
		for key in rewards do
			table.insert(fields, key)
		end
		table.sort(fields)
		T.expect(fields).toEqual({ "shards", "title", "titleDays" })
		local box = Mail.newBox()
		local parcel: Mail.Parcel = {
			id = "p",
			from = "player",
			subjectKey = "mail.subject.admin",
			gold = 0,
			items = {},
			createdAt = 0,
			expiresAt = 1000,
			shards = 10,
		}
		T.expect({ Mail.add(box, parcel, 0) }).toEqual({ false, "error.badRequest" })
	end)
end)

-- S126 (DESIGN-17 §0.2, §6): the ranked arena depends on match results, the character level and its gear only.
T.describe("Arena (S126)", function()
	local fs = require("@lune/fs")
	local Arena = require("../src/shared/Data/Arena")
	local ArenaRules = require("../src/shared/Logic/ArenaRules")

	local FORBIDDEN_REQUIRES = { "Data/Products", "Data/Cosmetics", "Logic/Premium", "MonetizationService" }

	T.it("the arena data and rules require nothing from the shop", function()
		for _, path in
			{
				"src/shared/Data/Arena.luau",
				"src/shared/Logic/Elo.luau",
				"src/shared/Logic/ArenaRules.luau",
			}
		do
			for line in string.gmatch(fs.readFile(path), "[^\n]+") do
				if string.find(line, "require(", 1, true) then
					for _, name in FORBIDDEN_REQUIRES do
						if string.find(line, name, 1, true) then
							error(`{path}: requires {name}`, 0)
						end
					end
				end
			end
		end
	end)

	T.it("a result is the same for a state carrying purchases", function()
		local plain: any = ArenaRules.emptyState()
		plain.season = "202611"
		local bought: any = table.clone(plain)
		bought.vip = true
		bought.dragonShards = 99999
		bought.passes = { vip = true }
		local input: ArenaRules.ResultInput = {
			mode = Arena.MODES["1v1"],
			season = "202611",
			day = 20758,
			now = 20758 * 86400,
			myKey = "1_1",
			oppKeys = { "2_1" },
			oppRating = 1100,
			oppName = "Rival",
			oppClass = "Mage",
			score = 1,
			rounds = "2:1",
			rated = true,
		}
		local a, ra = ArenaRules.applyResult(plain, input)
		local b, rb = ArenaRules.applyResult(bought, input)
		T.expect(b).toEqual(a)
		T.expect(rb).toEqual(ra)
		T.expect((b :: any).vip).toBeNil()
		T.expect((b :: any).dragonShards).toBeNil()
	end)

	T.it("the arena data has no prices in Robux or Dragon Shards", function()
		-- S128 adds a SHOP priced in Arena Tokens (allowed); a `shards` / `robux` key never is
		-- S128: `price` only in SHOP / shopByKey (Arena Tokens, earned in matches), `shards` only in SEASON_REWARDS (a
		-- reward by mail for the season's tier, never bought)
		local banned = { robux = true, productId = true, shards = true, price = true }
		local allowedUnder: { [string]: { [string]: boolean } } = {
			price = { SHOP = true, shopByKey = true },
			-- S130: TOURNEY.rewards (the Champion's Tournament places, by mail, never bought)
			shards = { SEASON_REWARDS = true, TOURNEY = true },
		}
		local function walk(value: any, path: string, top: string?)
			if type(value) ~= "table" then
				return
			end
			for k, v in value do
				local allow = type(k) == "string" and allowedUnder[k] and top and allowedUnder[k][top]
				if type(k) == "string" and banned[k] and not allow then
					error(`Data/Arena{path}.{k}: a purchase key`, 0)
				end
				walk(v, `{path}.{tostring(k)}`, top or (if type(k) == "string" then k else nil))
			end
		end
		walk(Arena, "", nil)
	end)
end)

T.describe("Global arena (S127)", function()
	local fs = require("@lune/fs")

	T.it("the global queue, the arena server and the remote host read nothing of purchases", function()
		for _, path in
			{
				"src/shared/Logic/ArenaQueue.luau",
				"src/server/Arena/Matchmaker.luau",
				"src/server/Arena/ArenaHost.luau",
				"src/server/Arena/RemoteHost.luau",
			}
		do
			local text = fs.readFile(path)
			for _, word in { "Products", "HasVip", "HasPass", "MonetizationService", "shards", "Vip" } do
				if string.find(text, word, 1, true) then
					error(`{path}: mentions {word}`, 0)
				end
			end
		end
	end)
end)

-- S128 (DESIGN-17 §0.2, §6): Arena Tokens are never sold, the arena cosmetics are never for sale, the arena shop sells
-- no power and the arena never depends on purchases. The kinds the arena shop may sell (explicit):
local ARENA_SHOP_KINDS: { [string]: string } = {
	cosmetic = "looks: an arena cosmetic (obtain.arena = shop), never for Dragon Shards",
	item = "a blessing up to Heroic (rarity <= 3) or the Return Stone; bound to the character",
}

T.describe("S128 arena tokens, shop and season rewards", function()
	local Arena = require("../src/shared/Data/Arena")
	local ArenaRules = require("../src/shared/Logic/ArenaRules")

	local function arenaCosmetic(id: string): boolean
		local def = Cosmetics.get(id)
		return def ~= nil and def.obtain ~= nil and def.obtain.arena ~= nil
	end

	-- every key and string value under a product: no tokens, no arena keys, no arena cosmetic
	local function noArena(value: any, where: string, seen: { [any]: boolean }?)
		if type(value) ~= "table" then
			if type(value) == "string" and arenaCosmetic(value) then
				error(`{where}: gives the arena cosmetic {value}`, 0)
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
				if lower == "tokens" or lower == "arenatokens" or string.sub(lower, 1, 5) == "arena" then
					error(`{where}.{k}: Arena Tokens are never sold`, 0)
				end
			end
			noArena(v, `{where}.{tostring(k)}`, visited)
		end
	end

	T.it("no product, pass, subscription, starter pack or mount gives Arena Tokens or an arena cosmetic", function()
		local raw: any = Products
		for _, field in { "shop", "passes", "subscriptions", "starterPacks", "mounts" } do
			noArena(raw[field] or {}, `Products.{field}`)
		end
	end)

	T.it("every arena cosmetic is free of a shard price, out of the weekly offer and not for sale", function()
		local n = 0
		for _, def in Cosmetics.list do
			if def.obtain and def.obtain.arena then
				n += 1
				local where = `cosmetics.{def.id}`
				T.expect({ where, def.price }).toEqual({ where, 0 })
				T.expect({ where, def.weekly == true }).toEqual({ where, false })
				T.expect({ where, def.obtain.arena == "shop" or def.obtain.arena == "season" }).toEqual({ where, true })
				T.expect({ where, ALLOWED_COSMETIC_KINDS[def.kind] ~= nil }).toEqual({ where, true })
				fieldsWithin(def.obtain :: any, { arena = true }, `{where}.obtain`)
				T.expect({ where, Premium.canBuyCosmetic(def.id, {}, 1e9) }).toEqual({
					where,
					false,
					"premium.error.notForSale",
				})
			end
		end
		T.expect(n).toBe(7)
	end)

	T.it("the arena shop sells only the allowed kinds, nothing with power", function()
		for _, entry in Arena.SHOP do
			local where = `Arena.SHOP.{entry.key}`
			T.expect({ where, ARENA_SHOP_KINDS[entry.kind] ~= nil }).toEqual({ where, true })
			if entry.kind == "cosmetic" then
				local def = Cosmetics.get(entry.id)
				T.expect({ where, def and def.obtain and def.obtain.arena }).toEqual({ where, "shop" })
			else
				local def = Items.get(entry.id) :: any
				T.expect({ where, def ~= nil }).toEqual({ where, true })
				local blessing = def.use and def.use.kind == "blessing"
				if blessing then
					local b = Blessings.get(def.use.target)
					T.expect({ where, b ~= nil and b.rarity <= 3 }).toEqual({ where, true })
				else
					T.expect({ where, entry.id }).toEqual({ where, "stone_return" })
				end
				for _, field in { "base", "weapon", "bonusGroup", "fixedBonuses", "trait" } do
					T.expect({ where, field, def[field] }).toEqual({ where, field, nil })
				end
				T.expect({ where, def.category ~= "material" and def.category ~= "currency" }).toEqual({ where, true })
				T.expect({ where, def.use == nil or def.use.kind ~= "scroll" }).toEqual({ where, true })
				T.expect({ where, def.use == nil or def.use.kind ~= "exp" }).toEqual({ where, true })
			end
		end
	end)

	T.it("tokens, teams, the 3v3 result and the season tier take nothing of the account", function()
		-- (S131: these functions have no account parameter; two accounts that differ in VIP, passes, shards and
		-- cosmetics cannot change their results)
		local plainAccount: any = { vip = false, passes = {}, dragonShards = 0, cosmetics = { owned = {} } }
		local richAccount: any =
			{ vip = true, passes = { vip = true, pockets = true }, dragonShards = 99999, cosmetics = { owned = {} } }
		local results = {}
		for _, _account in { plainAccount, richAccount } do
			local tickets = {}
			for i = 1, 6 do
				table.insert(tickets, {
					entrant = {
						key = `{i}_1`,
						userId = i,
						slot = 1,
						name = `P{i}`,
						class = "Mage",
						level = 45,
						rating = 1000 + i,
						played = 0,
					},
					mode = "3v3",
					bracket = "40_59",
					joinedAt = i,
				})
			end
			local state: any = ArenaRules.emptyState()
			state.season = "202611"
			local after, info = ArenaRules.applyResult(state, {
				mode = Arena.MODES["3v3"],
				season = "202611",
				day = 20758,
				now = 20758 * 86400,
				myKey = "1_1",
				oppKeys = { "4_1", "5_1", "6_1" },
				oppRating = 1005,
				oppName = "P4",
				oppClass = "Mage",
				score = 1,
				rounds = "1:0",
				rated = true,
			})
			table.insert(results, {
				pairing = ArenaRules.formTeams3(tickets, 10),
				after = after,
				info = info,
				tokens = { ArenaRules.tokensFor("3v3", "win", 0, 0, true, false) },
				tier = ArenaRules.seasonTier(1250, 1310),
			})
		end
		T.expect(results[2]).toEqual(results[1])
	end)
end)

T.describe("S129 Blood Moon", function()
	local BloodMoon = require("../src/shared/Logic/BloodMoon")
	local ScheduledEvents = require("../src/shared/Data/ScheduledEvents")
	local REWARD = ScheduledEvents.bloodMoon.reward

	-- every string value under a product: never the Blood Moon frame or title
	local function noEvent(value: any, where: string, seen: { [any]: boolean }?)
		if type(value) ~= "table" then
			if value == REWARD.frameId or value == REWARD.titleId then
				error(`{where}: gives the Blood Moon reward {value}`, 0)
			end
			return
		end
		local visited = seen or {}
		if visited[value] then
			return
		end
		visited[value] = true
		for k, v in value do
			noEvent(v, `{where}.{tostring(k)}`, visited)
		end
	end

	T.it("the frame and the title are earned only: not for sale, in no product", function()
		local frame = Cosmetics.get(REWARD.frameId)
		T.expect(frame ~= nil).toBe(true)
		local def = frame :: Cosmetics.Def
		T.expect(def.obtain ~= nil).toBe(true)
		fieldsWithin(def.obtain :: any, { event = true }, `cosmetics.{def.id}.obtain`)
		T.expect(def.price).toBe(0)
		T.expect(def.weekly == true).toBe(false)
		T.expect({ Premium.canBuyCosmetic(def.id, {}, 1e9) }).toEqual({ false, "premium.error.notForSale" })
		local raw: any = Products
		for _, field in { "shop", "passes", "subscriptions", "starterPacks", "mounts" } do
			noEvent(raw[field] or {}, `Products.{field}`)
		end
		-- no bought title (Data/Cosmetics kind "title") points at the Blood Moon title
		for _, cosmetic in Cosmetics.list do
			T.expect({ cosmetic.id, cosmetic.title == REWARD.titleId }).toEqual({ cosmetic.id, false })
		end
	end)

	T.it("paid and VIP respawns are off on the event maps during the event", function()
		T.expect(BloodMoon.paidRespawnBlocked(true, "meadows")).toBe(true)
		T.expect(BloodMoon.paidRespawnBlocked(true, "meadows_cave")).toBe(true)
		T.expect(BloodMoon.paidRespawnBlocked(true, "city")).toBe(false)
		T.expect(BloodMoon.paidRespawnBlocked(false, "meadows")).toBe(false)
	end)

	T.it("the Elixir of Wholeness and the Cloak of Luring are blocked during the event", function()
		T.expect(BloodMoon.consumableBlocked(true)).toBe(true)
		T.expect(BloodMoon.consumableBlocked(false)).toBe(false)
		T.expect(table.find(UseBlocks.LISTS.fullElixir, "bloodMoon") ~= nil).toBe(true)
		T.expect(table.find(UseBlocks.LISTS.lure, "bloodMoon") ~= nil).toBe(true)
		T.expect(UseBlocks.PENDING.bloodMoon).toBeNil()
		T.expect(UseBlocks.first("fullElixir", { bloodMoon = true })).toBe("bloodMoon")
	end)

	T.it("points come from kills only, never from purchases or VIP", function()
		local plain = { killerLevel = 40, victimLevel = 38, prior = 0 }
		local rich: any = table.clone(plain)
		rich.vip = true
		rich.passes = { fastRespawn = true, vip = true }
		rich.purchases = { r1 = true }
		rich.dragonShards = 99999
		T.expect(BloodMoon.playerPoints(rich)).toBe(BloodMoon.playerPoints(plain))
		T.expect(BloodMoon.monsterPoints("elite")).toBe(ScheduledEvents.bloodMoon.points.elite)
		-- the reward comes from the points and the rank alone
		T.expect(BloodMoon.rewardsOf(BloodMoon.tierOf(5, nil)).shards).toBe(0)
		-- the module never reads the account
		local fs = require("@lune/fs")
		local source = fs.readFile("src/shared/Logic/BloodMoon.luau")
		for _, word in { "purchases", "dragonShards", "vip", "passes", "HasPass", "HasVip" } do
			T.expect({ word, string.find(source, word, 1, true) ~= nil }).toEqual({ word, false })
		end
	end)
end)

T.describe("S130 tourney", function()
	local Arena = require("../src/shared/Data/Arena")
	local Tourney = require("../src/shared/Logic/Tourney")
	local TOURNEY = Arena.TOURNEY
	-- the kinds of a tournament reward -> why it is not pay-to-win
	local ALLOWED_REWARD_FIELDS: { [string]: string } = {
		place = "the place it is for",
		shards = "Dragon Shards: buy only what passes this test",
		title = "a timed title: looks",
		titleDays = "how long the title shows",
		cosmetics = "looks never sold (obtain), no stats",
	}
	local LOOK_KINDS: { [string]: boolean } =
		{ aura = true, frame = true, title = true, chatframe = true, trail = true }

	-- every string value under a product: never a tournament reward
	local function noReward(value: any, ids: { [string]: boolean }, where: string, seen: { [any]: boolean }?)
		if type(value) ~= "table" then
			if type(value) == "string" and ids[value] then
				error(`{where}: gives the tournament reward {value}`, 0)
			end
			return
		end
		local visited = seen or {}
		if visited[value] then
			return
		end
		visited[value] = true
		for k, v in value do
			noReward(v, ids, `{where}.{tostring(k)}`, visited)
		end
	end

	T.it("rewards are shards, tokens, a timed title and looks only", function()
		local allowed: { [string]: boolean } = {}
		for k in ALLOWED_REWARD_FIELDS do
			allowed[k] = true
		end
		for i, r in TOURNEY.rewards do
			fieldsWithin(r :: any, allowed, `TOURNEY.rewards[{i}]`)
			for _, id in r.cosmetics or {} do
				local def = Cosmetics.get(id) :: Cosmetics.Def
				T.expect({ id, def ~= nil }).toEqual({ id, true })
				T.expect({ id, LOOK_KINDS[def.kind] == true }).toEqual({ id, true })
				-- no stat-like field on a reward cosmetic
				for _, key in FORBIDDEN_KEYS do
					T.expect({ id, key, (def :: any)[key] }).toEqual({ id, key, nil })
				end
			end
		end
		T.expect(TOURNEY.participantTokens > 0 and TOURNEY.participantTokens % 1 == 0).toBe(true)
	end)

	T.it("the aura and the frame are never for sale and in no product", function()
		local ids: { [string]: boolean } = { tourney_champion = true }
		for _, id in { "aura_champion", "frame_tourney" } do
			ids[id] = true
			local def = Cosmetics.get(id) :: Cosmetics.Def
			T.expect(def ~= nil).toBe(true)
			fieldsWithin(def.obtain :: any, { event = true }, `cosmetics.{id}.obtain`)
			T.expect((def.obtain :: any).event).toBe("tourney")
			T.expect(def.price).toBe(0)
			T.expect(def.weekly == true).toBe(false)
			T.expect({ Premium.canBuyCosmetic(id, {}, 999999) }).toEqual({ false, "premium.error.notForSale" })
		end
		local raw: any = Products
		for _, field in { "shop", "passes", "subscriptions", "starterPacks", "mounts" } do
			noReward(raw[field] or {}, ids, `Products.{field}`)
		end
		for _, cosmetic in Cosmetics.list do
			T.expect({ cosmetic.id, cosmetic.title == "tourney_champion" }).toEqual({ cosmetic.id, false })
		end
		-- the arena shop does not sell them either
		for _, entry in Arena.SHOP do
			T.expect({ entry.id, ids[entry.id] == true }).toEqual({ entry.id, false })
		end
	end)

	T.it("the list and the seeding read only the rating and the signup time", function()
		local plain: { Tourney.Entry } = {}
		local rich: { any } = {}
		for i = 1, 40 do
			local e = { key = `{i}_1`, rating = 1000 + (i * 37) % 300, t = 1000 + i, name = `n{i}`, class = "warrior" }
			table.insert(plain, e)
			local r: any = table.clone(e)
			r.vip = i % 2 == 0
			r.passes = { fastRespawn = true, vip = true }
			r.dragonShards = i * 1000
			r.name = `other{i}`
			r.class = "mage"
			table.insert(rich, r)
		end
		T.expect(Tourney.seedOrder(rich)).toEqual(Tourney.seedOrder(plain))
		local a, _, ta = Tourney.pick(plain, TOURNEY.cap)
		local b, _, tb = Tourney.pick(rich, TOURNEY.cap)
		local keysA, keysB = {}, {}
		for _, e in a do
			table.insert(keysA, e.key)
		end
		for _, e in b do
			table.insert(keysB, e.key)
		end
		T.expect(keysB).toEqual(keysA)
		T.expect(tb).toBe(ta)
	end)

	T.it("the Elixir of Wholeness is blocked in a tournament (registered, not pending)", function()
		T.expect(table.find(UseBlocks.LISTS.fullElixir, "tourney") ~= nil).toBe(true)
		T.expect(UseBlocks.PENDING.tourney).toBeNil()
		T.expect(UseBlocks.first("fullElixir", { tourney = true })).toBe("tourney")
	end)
end)

return nil
