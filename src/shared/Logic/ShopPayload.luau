--!strict
-- The remote calls of the Dragon Shop (W28 fix), pure: what the client sends for a purchase and which product id the
-- server resolves for a Robux product key. Every shop window path builds its call here, so tests/shoppayload.spec
-- can check each catalog entry against Net/Definitions with the server's own ArgCheck.
--   ShopPayload.pack(remote, ...)   { remote, args, n } without trailing nils (PremiumBuy(key, nil) was refused as
--                                   "error.badRequest" until ArgCheck ignored trailing nils, 7fed5891)
--   ShopPayload.confirm(remote, arg, arg2?)  a shard purchase from UI/PremiumConfirm (arg2 only when given)
--   ShopPayload.shopEntry(entry)    the PremiumBuy call of a shop entry (nil for rename: its own dialog, PremiumRename)
--   ShopPayload.productIdOf(key)    the Developer Product id behind a BuyProduct key (nil = unknown key)

local Products = require("../Data/Products")

local ShopPayload = {}

export type Payload = { remote: string, args: { any }, n: number }

-- The kinds PremiumShopService.buy serves through PremiumBuy.
ShopPayload.PREMIUM_BUY_KINDS = table.freeze({ item = true, lure = true, autoPotion = true, autoGrind = true })

function ShopPayload.pack(remote: string, ...: any): Payload
	local args = table.pack(...)
	local n = args.n
	while n > 0 and args[n] == nil do
		n -= 1
	end
	return { remote = remote, args = args, n = n }
end

function ShopPayload.confirm(remote: string, arg: any, arg2: any?): Payload
	return ShopPayload.pack(remote, arg, arg2)
end

function ShopPayload.shopEntry(entry: Products.ShopEntry): Payload?
	if entry.kind == "rename" then
		return nil
	end
	return ShopPayload.confirm("PremiumBuy", entry.key, nil)
end

-- The same lookup as MonetizationService.buyProduct: shard packs, premium mounts, starter packs.
function ShopPayload.productIdOf(key: string): number?
	local pack = Products.getPack(key)
	if pack then
		return pack.productId
	end
	local mount = Products.getMount(key)
	if mount then
		return mount.productId
	end
	local starter = Products.getStarterPack(key)
	if starter then
		return starter.productId
	end
	return nil
end

return ShopPayload
