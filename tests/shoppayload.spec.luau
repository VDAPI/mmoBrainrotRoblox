--!strict
-- W28: every Dragon Shop purchase the client builds (Logic/ShopPayload) passes the server's argument check
-- (Net/Definitions + Logic/ArgCheck, the same call Net.Handle makes) and names a catalog entry the server serves.
-- Regression: PremiumConfirm sent PremiumBuy(key, nil) = two arguments for a one-argument remote, refused as
-- "error.badRequest" for every item bought with Dragon Shards.
local ArgCheck = require("../src/shared/Logic/ArgCheck")
local CosmeticData = require("../src/shared/Data/Cosmetics")
local Definitions = require("../src/shared/Net/Definitions")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local ShopPayload = require("../src/shared/Logic/ShopPayload")
local T = require("./Test")

local function passes(call: ShopPayload.Payload): (boolean, string?)
	local def = Definitions[call.remote]
	if not def then
		return false, `unknown remote {call.remote}`
	end
	if def.kind ~= "function" or def.dir ~= "c2s" then
		return false, `{call.remote} is not a c2s function`
	end
	return ArgCheck.check(call.args, def.args or {}, call.n)
end

local function expectPasses(call: ShopPayload.Payload, what: string)
	local ok, reason = passes(call)
	if not ok then
		error(`{what}: {call.remote} refused ({reason})`, 0)
	end
end

T.describe("ShopPayload", function()
	T.it("drops trailing nils only", function()
		T.expect(ShopPayload.pack("X", "a", nil, nil).n).toBe(1)
		T.expect(ShopPayload.pack("X", "a", nil, 5).n).toBe(3)
		T.expect(ShopPayload.pack("X").n).toBe(0)
		T.expect(ShopPayload.confirm("PremiumBuy", "scroll_protection", nil).n).toBe(1)
		T.expect(ShopPayload.confirm("PremiumBuyCosmetic", "x", 100).n).toBe(2)
	end)

	T.it("every Dragon Shard shop entry passes the server check and is served", function()
		T.expect(#Products.shop > 0).toBe(true)
		for _, entry in Products.shop do
			if entry.kind == "rename" then
				-- its own dialog: PremiumRename(new name)
				expectPasses(ShopPayload.pack("PremiumRename", "Aria"), entry.key)
				continue
			end
			local call = ShopPayload.shopEntry(entry)
			T.expect(call ~= nil).toBe(true)
			expectPasses(call :: ShopPayload.Payload, entry.key)
			T.expect(Products.getShop((call :: ShopPayload.Payload).args[1]) == entry).toBe(true)
			if ShopPayload.PREMIUM_BUY_KINDS[entry.kind] ~= true then
				error(`{entry.key}: kind {entry.kind} has no PremiumBuy branch`, 0)
			end
			if entry.kind == "item" and entry.itemId == nil then
				error(`{entry.key}: item entry without itemId`, 0)
			end
		end
	end)

	T.it("every cosmetic on sale passes the server check (with and without the price of the week)", function()
		local n = 0
		for _, def in CosmeticData.list do
			if def.price > 0 and def.obtain == nil then
				n += 1
				expectPasses(ShopPayload.confirm("PremiumBuyCosmetic", def.id, def.price), def.id)
				expectPasses(ShopPayload.confirm("PremiumBuyCosmetic", def.id, nil), def.id)
				T.expect(CosmeticData.get(def.id) ~= nil).toBe(true)
			end
		end
		T.expect(n > 0).toBe(true)
	end)

	T.it("every Robux product, pass and subscription passes the server check and resolves", function()
		local keys: { string } = {}
		for _, pack in Products.shardPacks do
			table.insert(keys, pack.key)
		end
		for _, mount in Products.mounts do
			table.insert(keys, mount.key)
		end
		for _, pack in Products.starterPacks do
			table.insert(keys, pack.key)
		end
		for _, key in keys do
			expectPasses(ShopPayload.pack("BuyProduct", key), key)
			if ShopPayload.productIdOf(key) == nil then
				error(`{key}: no product id on the server`, 0)
			end
		end
		T.expect(ShopPayload.productIdOf("no_such_product")).toBeNil()
		for _, pass in Products.passes do
			expectPasses(ShopPayload.pack("BuyPass", pass.key), pass.key)
			T.expect(Products.getPass(pass.key) == pass).toBe(true)
		end
		for _, sub in Products.subscriptions do
			expectPasses(ShopPayload.pack("BuySubscription", sub.key), sub.key)
		end
	end)

	T.it("the Studio shard button's admin call passes the server check", function()
		expectPasses(ShopPayload.pack("AdminRun", "shards", { "1000" }), "studio shards")
	end)

	T.it("in Studio every enabled Robux offer is buyable (simulated), on live id 0 is Soon", function()
		local ids: { number } = {}
		for _, pack in Products.shardPacks do
			table.insert(ids, pack.productId)
		end
		for _, pack in Products.starterPacks do
			table.insert(ids, pack.productId)
		end
		for _, pass in Products.passes do
			if pass.enabled ~= false then
				table.insert(ids, pass.passId)
			end
		end
		for _, id in ids do
			T.expect(Premium.robuxState(id, true)).toBe("buy")
			T.expect(Premium.robuxState(id, false)).toBe(if id == 0 then "soon" else "buy")
		end
		for _, sub in Products.subscriptions do
			T.expect(Premium.subscriptionState(sub, true)).toBe("buy")
		end
	end)
end)
