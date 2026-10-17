--!strict
-- The Huntmaster's shop rules (S134k, Data/HuntShop): whether a character may buy an entry (marks, level, the weekly
-- limit), what an entry gives at a level (potions of the level's quality) and the weekly counter. Pure (Lune): the
-- server (ContractService), the window and tests/huntshop.spec use the same functions.

local Classes = require("../Data/Classes")
local Data = require("../Data/HuntShop")
local LoginReward = require("./LoginReward")

export type Entry = Data.Entry
export type Week = { week: number, counts: { [string]: number } }
-- The state the rules read: the marks and the weekly counter of character.quests.contract (Logic/Contracts.State).
export type Wallet = { marks: number, shopWeek: Week }
export type Grant = { id: string, n: number }

local HuntShop = {}

-- Purchases of `entry` in `week` (0 when the counter is of another week).
function HuntShop.boughtThisWeek(entry: Entry, wallet: Wallet, week: number): number
	if wallet.shopWeek.week ~= week then
		return 0
	end
	return wallet.shopWeek.counts[entry.key] or 0
end

-- The price of one purchase of `entry` for a character of `charLevel` (potions: by the quality the level gets).
function HuntShop.priceAt(entry: Entry, charLevel: number): number
	local prices = entry.qualityPrices
	if prices and entry.kind == "potion" then
		return prices[LoginReward.potionQuality(charLevel)] or entry.price
	end
	return entry.price
end

-- Whether a character of `charLevel` sees `entry` (its level range).
function HuntShop.offered(entry: Entry, charLevel: number): boolean
	return charLevel <= (entry.maxLevel or math.huge)
end

-- How many more of `entry` the weekly limit allows in `week` (math.huge without a limit).
function HuntShop.left(entry: Entry, wallet: Wallet, week: number): number
	local limit = entry.weeklyLimit
	if not limit then
		return math.huge
	end
	return math.max(0, limit - HuntShop.boughtThisWeek(entry, wallet, week))
end

-- Whether a character of `charLevel` may buy `amount` (default 1) of `entry` now; the reason otherwise:
-- "error.badRequest" (no entry, a bad amount) | "huntshop.error.level" | "huntshop.error.weekly" |
-- "huntshop.error.marks" | "huntshop.error.owned" (a cosmetic the account owns; `owned` = account.cosmetics.owned).
function HuntShop.canBuy(
	entry: Entry?,
	wallet: Wallet,
	charLevel: number,
	week: number,
	amount: number?,
	owned: { [string]: boolean }?
): (boolean, string?)
	if entry == nil then
		return false, "error.badRequest"
	end
	local e = entry :: Entry
	local count = amount or 1
	if count ~= math.floor(count) or count < 1 or (e.kind ~= "item" and e.kind ~= "potion" and count > 1) then
		return false, "error.badRequest"
	end
	if charLevel < (e.minLevel or 1) or not HuntShop.offered(e, charLevel) then
		return false, "huntshop.error.level"
	end
	if e.kind == "cosmetic" and owned ~= nil and owned[e.id] == true then
		return false, "huntshop.error.owned"
	end
	if count > HuntShop.left(e, wallet, week) then
		return false, "huntshop.error.weekly"
	end
	if wallet.marks < HuntShop.priceAt(e, charLevel) * count then
		return false, "huntshop.error.marks"
	end
	return true, nil
end

-- The weekly counter after buying `amount` of `entry` in `week` (a new table; a counter of another week starts over).
function HuntShop.counted(entry: Entry, wallet: Wallet, week: number, amount: number): Week
	local counts: { [string]: number } = if wallet.shopWeek.week == week
		then table.clone(wallet.shopWeek.counts)
		else {}
	if entry.weeklyLimit then
		counts[entry.key] = (counts[entry.key] or 0) + amount
	end
	return { week = week, counts = counts }
end

-- The item an "item" or "potion" entry gives a character of `charLevel` and `classId` per purchase (nil for chests
-- and cosmetics): potions of the quality of Logic/LoginReward.potionQuality (HP, or the class resource).
function HuntShop.grant(entry: Entry, charLevel: number, classId: string): Grant?
	local n = entry.n or 1
	if entry.kind == "item" then
		return { id = entry.id, n = n }
	elseif entry.kind == "potion" then
		local quality = LoginReward.potionQuality(charLevel)
		if entry.id == "hp" then
			return { id = `potion_hp_{quality}`, n = n }
		end
		local class = Classes.get(classId)
		local resource = if class then class.resource else "mana"
		return { id = `potion_{resource}_{quality}`, n = n }
	end
	return nil
end

-- The rarity of a chest entry (nil for anything else).
function HuntShop.chestRarity(entry: Entry): number?
	if entry.kind ~= "chest" then
		return nil
	end
	return (Data.CHEST_RARITY :: { [string]: number })[entry.id]
end

return HuntShop
