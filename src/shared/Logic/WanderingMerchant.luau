--!strict
-- The wandering merchant (owner 2026-10-20, docs/DESIGN.md §8b, Data/WanderingMerchant). Pure (Lune): every server and
-- every client computes the same visits from the clock (Util/Clock.now) and the same stock from the visit number,
-- seeded through Logic/Rng, so nothing travels between servers and the window and the map need no remote to know where
-- he is and what he sells. The purchase rules (WanderingMerchantService and the window) are here too.

local Data = require("../Data/WanderingMerchant")
local Items = require("../Data/Items")
local LoginReward = require("./LoginReward")
local Loot = require("./Loot")
local LootTables = require("../Data/LootTables")
local Rng = require("./Rng")
local Classes = require("../Data/Classes")

export type Spot = Data.Spot
export type Offer = Data.Offer
export type Visit = {
	index: number, -- the visit number since the epoch (Logic.indexAt)
	id: string, -- tostring(index)
	startsAt: number,
	endsAt: number,
	spot: Spot,
	band: { number }, -- { min, max } character levels of the spot's map
}
-- character.wanderer: the purchases of one visit (a counter of another visit starts over)
export type Bought = { visit: number, counts: { [string]: number } }
export type Crossing = { kind: "warn" | "arrive" | "leaving" | "left", visit: Visit, before: number? }
export type Grant = { id: string, n: number }
-- What canBuy reads of the buyer.
export type Buyer = {
	level: number,
	gold: number,
	marks: number,
	bought: Bought?,
	owned: { [string]: boolean }?, -- account.cosmetics.owned
}

local S = Data.schedule

local WanderingMerchant = {}
WanderingMerchant.Data = Data

-- The number of the visit whose start is at or before `t` (it may already be over).
function WanderingMerchant.indexAt(t: number): number
	return math.floor((t - S.offset) / S.interval)
end

function WanderingMerchant.startOf(index: number): number
	return S.offset + index * S.interval
end

local spotsByMap: { [string]: { Spot } } = {}
for _, spot in Data.spots do
	local list = spotsByMap[spot.map] or {}
	table.insert(list, spot)
	spotsByMap[spot.map] = list
end

-- The spots of `map` in data order (empty for a map without any).
function WanderingMerchant.spotsOf(map: string): { Spot }
	return spotsByMap[map] or {}
end

local function rawSpot(index: number): Spot
	local rng = Rng.new(Rng.seedOf(`wanderer:{index}:{S.salt}`))
	local map = rng:weighted(Data.mapWeights)
	return rng:pick(spotsByMap[map])
end

-- The spot of visit `index`: a weighted map, a spot of it; the next spot of the same map when that is where he stood
-- on the visit before (a short chain of such fixes is followed at most `depth` visits back).
local cache: { [number]: Spot } = {}
local function spotAt(index: number, depth: number): Spot
	local hit = cache[index]
	if hit then
		return hit
	end
	local spot = rawSpot(index)
	if depth < 8 then
		local prev = spotAt(index - 1, depth + 1)
		if prev.id == spot.id then
			local list = spotsByMap[spot.map]
			spot = list[(table.find(list, spot) :: number) % #list + 1]
		end
		if depth == 0 then
			cache[index] = spot
		end
	end
	return spot
end

function WanderingMerchant.spotOf(index: number): Spot
	return spotAt(index, 0)
end

function WanderingMerchant.bandOf(map: string): { number }
	return Data.bands[map] or { 1, 100 }
end

function WanderingMerchant.visit(index: number): Visit
	local startsAt = WanderingMerchant.startOf(index)
	local spot = WanderingMerchant.spotOf(index)
	return {
		index = index,
		id = tostring(index),
		startsAt = startsAt,
		endsAt = startsAt + S.duration,
		spot = spot,
		band = WanderingMerchant.bandOf(spot.map),
	}
end

-- The visit running at `now` (startsAt <= now < endsAt), nil between visits.
function WanderingMerchant.current(now: number): Visit?
	local index = WanderingMerchant.indexAt(now)
	if now < WanderingMerchant.startOf(index) + S.duration then
		return WanderingMerchant.visit(index)
	end
	return nil
end

-- The next visit starting after `now`.
function WanderingMerchant.nextVisit(now: number): Visit
	return WanderingMerchant.visit(WanderingMerchant.indexAt(now) + 1)
end

-- The visit running now, else the next one (the map's caption, the window's footer).
function WanderingMerchant.shown(now: number): Visit
	return WanderingMerchant.current(now) or WanderingMerchant.nextVisit(now)
end

-- The announcements due in (from, to], in time order: the warnings before the arrival (`before` = seconds), the
-- arrival, "he packs up" and the departure. A server loop calls it with the previous and the current time, so every
-- announcement falls once (also after a frozen server or /time), and a server starting at `now` (from = now) never
-- repeats missed ones.
function WanderingMerchant.crossed(from: number, to: number): { Crossing }
	local out: { Crossing } = {}
	if to <= from then
		return out
	end
	local first = WanderingMerchant.indexAt(from) - 1
	local last = WanderingMerchant.indexAt(to) + 1
	for index = first, last do
		local startsAt = WanderingMerchant.startOf(index)
		local endsAt = startsAt + S.duration
		local function due(at: number): boolean
			return from < at and at <= to
		end
		local marks: { { at: number, kind: string, before: number? } } = {}
		for _, before in S.warn do
			table.insert(marks, { at = startsAt - before, kind = "warn", before = before })
		end
		table.insert(marks, { at = startsAt, kind = "arrive" })
		table.insert(marks, { at = endsAt - S.leaving, kind = "leaving" })
		table.insert(marks, { at = endsAt, kind = "left" })
		for _, m in marks do
			if due(m.at) then
				table.insert(out, { kind = m.kind :: any, visit = WanderingMerchant.visit(index), before = m.before })
			end
		end
	end
	return out
end

-- Draws `count` different pool entries the band reaches (weighted, without repeats).
local function draw(pool: { Data.PoolEntry }, count: number, band: { number }, rng: Rng.Rng): { Data.PoolEntry }
	local weights: { [string]: number } = {}
	local byKey: { [string]: Data.PoolEntry } = {}
	for _, entry in pool do
		if entry.minLevel <= band[2] then
			weights[entry.key] = entry.weight
			byKey[entry.key] = entry
		end
	end
	local out: { Data.PoolEntry } = {}
	for _ = 1, count do
		if next(weights) == nil then
			break
		end
		local key = rng:weighted(weights)
		weights[key] = nil
		table.insert(out, byKey[key])
	end
	return out
end

local function fromPool(entry: Data.PoolEntry, group: Data.Group, id: string?): Offer
	return {
		key = entry.key,
		kind = entry.kind,
		group = group,
		id = id or entry.id,
		rarity = entry.rarity,
		n = entry.n,
		currency = entry.currency,
		price = entry.price,
		perLevel = entry.perLevel,
		minLevel = entry.minLevel,
		limit = entry.limit,
	}
end

-- The stock of visit `index` in window order (gear, materials, the dye, consumables); the same on every server.
local stockCache: { [number]: { Offer } } = {}
function WanderingMerchant.stock(index: number): { Offer }
	local hit = stockCache[index]
	if hit then
		return hit
	end
	local band = WanderingMerchant.bandOf(WanderingMerchant.spotOf(index).map)
	local rng = Rng.new(Rng.seedOf(`wanderer-stock:{index}:{S.salt}`))
	local out: { Offer } = {}
	local slots: { [string]: number } = table.clone(LootTables.bossSlots)
	for i = 1, Data.gear.count do
		local slot = rng:weighted(slots)
		slots[slot] = nil
		local rarity = rng:weighted(Data.gear.rarity)
		local price = Data.gear.price[rarity]
		table.insert(out, {
			key = `gear{i}`,
			kind = "gear",
			group = "gear",
			slot = slot,
			rarity = rarity,
			n = 1,
			currency = price.currency,
			price = price.price,
			perLevel = price.perLevel,
			minLevel = band[1],
			limit = Data.gear.limit,
		})
	end
	for _, entry in draw(Data.materials, Data.materialCount, band, rng) do
		table.insert(out, fromPool(entry, "material"))
	end
	table.insert(out, {
		key = "dye",
		kind = "dye",
		group = "dye",
		id = rng:pick(Data.dyes),
		n = 1,
		currency = "gold",
		price = Data.dyePrice,
		minLevel = 1,
		limit = 1,
	})
	for _, entry in draw(Data.consumables, Data.consumableCount, band, rng) do
		local id = if entry.kind == "blessing" then rng:pick(Data.blessingLines) else nil
		table.insert(out, fromPool(entry, "consumable", id))
	end
	-- keep the cache small: only visits near each other are asked for
	local cached = 0
	for _ in stockCache do
		cached += 1
	end
	if cached > 8 then
		table.clear(stockCache)
	end
	stockCache[index] = out
	return out
end

function WanderingMerchant.offerOf(index: number, key: string): Offer?
	for _, offer in WanderingMerchant.stock(index) do
		if offer.key == key then
			return offer
		end
	end
	return nil
end

-- The item level of gear bought by a character of `level` in `band` (never above the buyer's level when he may buy).
function WanderingMerchant.ilvlOf(band: { number }, level: number): number
	return math.clamp(math.floor(level), band[1], band[2])
end

-- What an item / potion / blessing offer gives per purchase at `level` (nil for gear and the dye).
function WanderingMerchant.grant(offer: Offer, level: number, classId: string): Grant?
	if offer.kind == "item" and offer.id then
		return { id = offer.id, n = offer.n }
	elseif offer.kind == "potion" then
		local quality = LoginReward.potionQuality(level)
		if offer.id == "hp" then
			return { id = `potion_hp_{quality}`, n = offer.n }
		end
		local class = Classes.get(classId)
		local resource = if class then class.resource else "mana"
		return { id = `potion_{resource}_{quality}`, n = offer.n }
	elseif offer.kind == "blessing" then
		return { id = `blessing_{offer.id}_{offer.rarity or 3}`, n = offer.n }
	end
	return nil
end

-- The price of one purchase of `offer` for a character of `level` and `classId` at a visit of `band` (in the offer's
-- currency, whole and at least 1).
function WanderingMerchant.priceOf(offer: Offer, level: number, band: { number }, classId: string?): number
	local price: number
	if offer.kind == "potion" then
		local grant = WanderingMerchant.grant(offer, level, classId or "Warrior") :: Grant
		local def = Items.get(grant.id)
		local unit = if def then def.buyPrice or def.price else 1
		price = unit * grant.n * (offer.price or 1)
	elseif offer.perLevel then
		price = offer.perLevel * WanderingMerchant.ilvlOf(band, level)
	else
		price = offer.price or 1
	end
	return math.max(1, math.floor(price + 0.5))
end

-- Purchases of `key` at visit `index` (0 when the counter is of another visit).
function WanderingMerchant.boughtAt(bought: Bought?, index: number, key: string): number
	if not bought or bought.visit ~= index then
		return 0
	end
	return bought.counts[key] or 0
end

-- The counter after buying `amount` of `key` at visit `index` (a new table).
function WanderingMerchant.counted(bought: Bought?, index: number, key: string, amount: number): Bought
	local counts: { [string]: number } = if bought and bought.visit == index then table.clone(bought.counts) else {}
	counts[key] = (counts[key] or 0) + amount
	return { visit = index, counts = counts }
end

-- Whether `buyer` may buy `amount` (default 1) of `offer` at visit `index` of `band`; the reason otherwise:
-- "error.badRequest" | "wanderer.error.level" | "wanderer.error.owned" | "wanderer.error.limit" |
-- "wanderer.error.gold" | "wanderer.error.marks".
function WanderingMerchant.canBuy(
	offer: Offer?,
	index: number,
	band: { number },
	buyer: Buyer,
	classId: string?,
	amount: number?
): (boolean, string?)
	if offer == nil then
		return false, "error.badRequest"
	end
	local o = offer :: Offer
	local count = amount or 1
	local stackable = o.kind == "item" or o.kind == "potion" or o.kind == "blessing"
	if count ~= math.floor(count) or count < 1 or (not stackable and count > 1) then
		return false, "error.badRequest"
	end
	if buyer.level < o.minLevel then
		return false, "wanderer.error.level"
	end
	if o.kind == "dye" and o.id and buyer.owned and buyer.owned[o.id] == true then
		return false, "wanderer.error.owned"
	end
	if WanderingMerchant.boughtAt(buyer.bought, index, o.key) + count > o.limit then
		return false, "wanderer.error.limit"
	end
	local total = WanderingMerchant.priceOf(o, buyer.level, band, classId) * count
	if o.currency == "marks" then
		if buyer.marks < total then
			return false, "wanderer.error.marks"
		end
	elseif buyer.gold < total then
		return false, "wanderer.error.gold"
	end
	return true, nil
end

-- The equipment base of a gear offer for `classId` at `ilvl` (an item of the offer's slot the class can use).
function WanderingMerchant.pickGear(offer: Offer, ilvl: number, classId: string, rng: Rng.Rng): string?
	if offer.kind ~= "gear" or not offer.slot then
		return nil
	end
	local defId = Loot.pickUsable({ [offer.slot] = 1 }, ilvl, classId, rng)
	local def = if defId then Items.get(defId) else nil
	if def and (def.classes == nil or table.find(def.classes, classId) ~= nil) then
		return defId
	end
	-- no base of that slot for the class at this tier: any boss slot the class can use
	return Loot.pickUsable(LootTables.bossSlots, ilvl, classId, rng)
end

return WanderingMerchant
