--!strict
-- No pay-to-win (DESIGN-17 §0.2, §1; S120). Every later session that sells something extends these lists with a
-- reason; nothing bought with Robux or Dragon Currency may give stats, EXP, gold, drops, upgrade materials or
-- blessings (DESIGN-17 §0.2). The lists are allowlists: anything not named here fails.

local Blessings = require("../src/shared/Data/Blessings")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Items = require("../src/shared/Data/Items")
local Mounts = require("../src/shared/Data/Mounts")
local Products = require("../src/shared/Data/Products")
local T = require("./Test")

-- Passes (Products.passes): key -> why it is not pay-to-win.
local ALLOWED_PASSES: { [string]: string } = {
	autoLoot = "comfort: picks up bags in range",
	vault = "space: deposit slots",
	fastRespawn = "time: shorter respawn",
	vip = "looks and comfort only (chat star, colour, alchemist queue)",
}
local ALLOWED_SUBSCRIPTIONS: { [string]: string } = {} -- S121: vip
local ALLOWED_SHOP_KINDS: { [string]: string } = { item = "an item, checked below", rename = "a service" }
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
local EXCEPTIONS: { [string]: string } = {} -- item id -> reason (S122: potion_full; DESIGN-17 §3)
local ALLOWED_COSMETIC_KINDS: { [string]: string } = {
	outfit = "looks",
	aura = "looks",
	trail = "looks",
	weapon = "looks",
	pet = "looks",
	mountskin = "looks (S97)",
}
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
		local fields = { key = true, passId = true, robux = true, icon = true, enabled = true }
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

return nil
