--!strict
-- S160k (owner 2026-10-21): the Portal Master's purchase rule (Data/PortalShop), pure. The server (PortalShopService),
-- the window and tests/portalshop.spec use the same functions.
--   piece  `n` ordinary stones (1..MAX_PIECES) for n x piece shards
--   perm   the everlasting stone once per account for `perm` shards (account.portalStones[itemId] = true)
--   claim  a character of an account that owns it takes its everlasting copy for free (one held at a time)

local Data = require("../Data/PortalShop")

local PortalShop = {}

export type Mode = "piece" | "perm" | "claim"
-- What the rule reads from the account (the server passes AccountData, the window its replicated branches).
export type Account = { dragonShards: number?, portalStones: any }

-- Whether the account owns the everlasting stone of `itemId` (junk reads as not owned).
function PortalShop.owned(account: Account, itemId: string): boolean
	local stones = account.portalStones
	return type(stones) == "table" and stones[itemId] == true
end

-- The shards a purchase costs (0 for a claim, nil for a bad mode).
function PortalShop.price(entry: Data.Entry, mode: string, n: number): number?
	if mode == "piece" then
		return entry.piece * n
	elseif mode == "perm" then
		return entry.perm
	elseif mode == "claim" then
		return 0
	end
	return nil
end

-- The one purchase rule: "error.badRequest" (no entry, a bad mode or amount) | "portalshop.error.owned" (perm again) |
-- "portalshop.error.notOwned" (a claim without the purchase) | "portalshop.error.have" (a claim while the character
-- holds a copy; `held` = everlasting copies in its backpack) | "premium.error.shards".
function PortalShop.canBuy(
	entry: Data.Entry?,
	mode: string,
	n: number,
	account: Account,
	held: number?
): (boolean, string?)
	if entry == nil then
		return false, "error.badRequest"
	end
	if mode == "piece" then
		if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > Data.MAX_PIECES then
			return false, "error.badRequest"
		end
	elseif mode == "perm" then
		if PortalShop.owned(account, entry.itemId) then
			return false, "portalshop.error.owned"
		end
	elseif mode == "claim" then
		if not PortalShop.owned(account, entry.itemId) then
			return false, "portalshop.error.notOwned"
		end
		if (held or 0) > 0 then
			return false, "portalshop.error.have"
		end
		return true, nil
	else
		return false, "error.badRequest"
	end
	local price = PortalShop.price(entry, mode, n) :: number
	if (account.dragonShards or 0) < price then
		return false, "premium.error.shards"
	end
	return true, nil
end

return PortalShop
