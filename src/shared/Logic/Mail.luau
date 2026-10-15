--!strict
-- Mail rules (DESIGN §18), pure so they run inside DataStore UpdateAsync callbacks. A mailbox belongs to
-- an account ("Mail_<userId>"); a parcel addressed to a character (`charId`) is only visible to it, one
-- without `charId` to every character of the account. Parcels expire after Market.Mail.lifetimeDays.

local Cosmetics = require("../Data/Cosmetics")
local Items = require("../Data/Items")
local Market = require("../Data/Market")
local Rarities = require("../Data/Rarities")
local TitleData = require("../Data/Titles")
local Types = require("../Types")

type ItemInstance = Types.ItemInstance

local Rules = Market.Mail

export type Parcel = {
	id: string,
	from: string, -- "system" | "auction" | "admin" | "player"
	fromName: string?,
	subjectKey: string,
	args: { [string]: any }?,
	gold: number,
	items: { ItemInstance },
	createdAt: number,
	expiresAt: number,
	charId: string?,
	shards: number?, -- S125: Dragon Shards for the account, system/admin parcels only
	timedTitle: { id: string, untilTs: number }?, -- S125: timed title (Data/Titles req.kind "timed") for `charId`
	once: string?, -- S128: an idempotency key: a second parcel with the same key is never added (Mail.add)
	tokens: number?, -- S129: Arena Tokens for `charId` (outside the weekly cap), system/admin parcels only
	cosmetics: { string }?, -- S129: Data/Cosmetics ids earned in the game (obtain ~= nil), system/admin parcels only
}

-- S128: `sent` = the once keys of parcels added (key -> os.time it is forgotten), kept after the parcel is claimed
export type Box = { parcels: { [string]: Parcel }, sent: { [string]: number }? }

local Mail = {}

Mail.LIFETIME = Rules.lifetimeDays * 86400
-- S128: how long a once key is remembered (a season reward retried after a long absence still finds it)
Mail.ONCE_KEEP = 400 * 86400

function Mail.newBox(): Box
	return { parcels = {} }
end

-- Accepts nil/garbage from the store and returns a usable box.
-- Normalises a stored mailbox. S30: items of parcels sent before the new rarity ladder are upgraded
-- (Rarities.upgradeItem, idempotent; parcels live up to 30 days).
function Mail.box(value: any): Box
	if type(value) == "table" and type(value.parcels) == "table" then
		if value.sent ~= nil and type(value.sent) ~= "table" then
			value.sent = nil
		end
		for _, parcel in value.parcels do
			if type(parcel) == "table" and type(parcel.items) == "table" then
				for _, item in parcel.items do
					if type(item) == "table" and type(item.id) == "string" then
						Rarities.upgradeItem(item, Items.get(item.id))
					end
				end
			end
		end
		return value
	end
	return Mail.newBox()
end

function Mail.count(box: Box): number
	local n = 0
	for _ in box.parcels do
		n += 1
	end
	return n
end

-- Removes expired parcels. Returns their ids.
function Mail.prune(box: Box, now: number): { string }
	local removed = {}
	for id, parcel in box.parcels do
		if parcel.expiresAt <= now then
			box.parcels[id] = nil
			table.insert(removed, id)
		end
	end
	if box.sent then
		for once, untilTs in box.sent do
			if type(untilTs) ~= "number" or untilTs <= now then
				box.sent[once] = nil
			end
		end
	end
	return removed
end

-- S128: a parcel with a `once` key already sent returns (true, nil) and adds nothing (the sender may retry safely).
function Mail.add(box: Box, parcel: Parcel, now: number): (boolean, string?)
	Mail.prune(box, now)
	if parcel.once ~= nil and box.sent and box.sent[parcel.once] then
		return true, nil
	end
	if #parcel.items > Rules.maxItemsPerParcel then
		return false, "mail.error.tooManyItems"
	end
	if parcel.gold < 0 or parcel.gold ~= math.floor(parcel.gold) then
		return false, "error.badRequest"
	end
	-- S125: shards and a timed title come only from the game (rankings, events) or an admin, never from a player
	if parcel.shards ~= nil then
		local n = parcel.shards
		if
			type(n) ~= "number"
			or n < 0
			or n ~= math.floor(n)
			or (parcel.from ~= "system" and parcel.from ~= "admin")
		then
			return false, "error.badRequest"
		end
	end
	if parcel.timedTitle ~= nil then
		local t = parcel.timedTitle
		local def = if type(t) == "table" and type(t.id) == "string" then TitleData.get(t.id) else nil
		if
			not def
			or def.req.kind ~= "timed"
			or type(t.untilTs) ~= "number"
			or parcel.charId == nil
			or (parcel.from ~= "system" and parcel.from ~= "admin")
		then
			return false, "error.badRequest"
		end
	end
	-- S129: Arena Tokens and cosmetics earned in events (Blood Moon, S130 tournament); a cosmetic must be one that is
	-- never sold (obtain), so mail can never hand out a shop item
	if parcel.tokens ~= nil then
		local n = parcel.tokens
		if
			type(n) ~= "number"
			or n < 0
			or n ~= math.floor(n)
			or parcel.charId == nil
			or (parcel.from ~= "system" and parcel.from ~= "admin")
		then
			return false, "error.badRequest"
		end
	end
	if parcel.cosmetics ~= nil then
		local list = parcel.cosmetics
		if type(list) ~= "table" or (parcel.from ~= "system" and parcel.from ~= "admin") then
			return false, "error.badRequest"
		end
		for _, id in list do
			local def = if type(id) == "string" then Cosmetics.get(id) else nil
			if not def or def.obtain == nil then
				return false, "error.badRequest"
			end
		end
	end
	if Mail.count(box) >= Rules.maxParcels then
		return false, "mail.error.full"
	end
	box.parcels[parcel.id] = parcel
	if parcel.once ~= nil then
		local sent = box.sent or {}
		sent[parcel.once] = now + Mail.ONCE_KEEP
		box.sent = sent
	end
	return true, nil
end

-- S125: nothing to take: no gold, items, shards or title (S129: tokens, cosmetics).
function Mail.isEmpty(parcel: Parcel): boolean
	return parcel.gold <= 0
		and #parcel.items == 0
		and (parcel.shards or 0) <= 0
		and parcel.timedTitle == nil
		and (parcel.tokens or 0) <= 0
		and (parcel.cosmetics == nil or #parcel.cosmetics == 0)
end

local function visibleTo(parcel: Parcel, charId: string?, now: number): boolean
	return parcel.expiresAt > now and (parcel.charId == nil or parcel.charId == charId)
end

-- Parcels a character can see, newest first.
function Mail.visible(box: Box, charId: string?, now: number): { Parcel }
	local list = {}
	for _, parcel in box.parcels do
		if visibleTo(parcel, charId, now) then
			table.insert(list, parcel)
		end
	end
	table.sort(list, function(a, b)
		if a.createdAt ~= b.createdAt then
			return a.createdAt > b.createdAt
		end
		return a.id < b.id
	end)
	return list
end

-- Removes and returns the parcel if the character may take it.
function Mail.take(box: Box, id: string, charId: string?, now: number): Parcel?
	local parcel = box.parcels[id]
	if not parcel or not visibleTo(parcel, charId, now) then
		return nil
	end
	box.parcels[id] = nil
	return parcel
end

return Mail
