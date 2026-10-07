--!strict
-- Mail rules (DESIGN §18), pure so they run inside DataStore UpdateAsync callbacks. A mailbox belongs to
-- an account ("Mail_<userId>"); a parcel addressed to a character (`charId`) is only visible to it, one
-- without `charId` to every character of the account. Parcels expire after Market.Mail.lifetimeDays.

local Items = require("../Data/Items")
local Market = require("../Data/Market")
local Rarities = require("../Data/Rarities")
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
}

export type Box = { parcels: { [string]: Parcel } }

local Mail = {}

Mail.LIFETIME = Rules.lifetimeDays * 86400

function Mail.newBox(): Box
	return { parcels = {} }
end

-- Accepts nil/garbage from the store and returns a usable box.
-- Normalises a stored mailbox. S30: items of parcels sent before the new rarity ladder are upgraded
-- (Rarities.upgradeItem, idempotent; parcels live up to 30 days).
function Mail.box(value: any): Box
	if type(value) == "table" and type(value.parcels) == "table" then
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
	return removed
end

function Mail.add(box: Box, parcel: Parcel, now: number): (boolean, string?)
	Mail.prune(box, now)
	if #parcel.items > Rules.maxItemsPerParcel then
		return false, "mail.error.tooManyItems"
	end
	if parcel.gold < 0 or parcel.gold ~= math.floor(parcel.gold) then
		return false, "error.badRequest"
	end
	if Mail.count(box) >= Rules.maxParcels then
		return false, "mail.error.full"
	end
	box.parcels[parcel.id] = parcel
	return true, nil
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
