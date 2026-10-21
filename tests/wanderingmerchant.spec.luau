--!strict
-- S159w (owner 2026-10-20, docs/DESIGN.md §8b): the wandering merchant (Data/WanderingMerchant, Logic/WanderingMerchant):
-- the clock schedule and its announcements, the spot of a visit (deterministic, never twice in a row, on open city
-- ground or by a respawn camp off the monsters), the stock (rerolled per visit, never Mythic, gear of the band's
-- levels), prices, the per-visit limit, the caravan dyes (gold, never shards) and nothing sold for Robux or shards.

local Areas = require("../src/shared/Data/Areas")
local Cosmetics = require("../src/shared/Data/Cosmetics")
local Data = require("../src/shared/Data/WanderingMerchant")
local Items = require("../src/shared/Data/Items")
local Maps = require("../src/shared/Data/Maps")
local Npcs = require("../src/shared/Data/Npcs")
local Premium = require("../src/shared/Logic/Premium")
local Products = require("../src/shared/Data/Products")
local Rarities = require("../src/shared/Data/Rarities")
local Rng = require("../src/shared/Logic/Rng")
local Test = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local WM = require("../src/shared/Logic/WanderingMerchant")

local describe, it, expect = Test.describe, Test.it, Test.expect

local S = Data.schedule
-- a fixed moment: Tuesday 2026-10-20 12:00 UTC
local NOON = 1792497600

local function buyer(level: number, gold: number, marks: number?, bought: WM.Bought?): WM.Buyer
	return { level = level, gold = gold, marks = marks or 0, bought = bought, owned = {} }
end

describe("Wandering merchant: schedule (S159w)", function()
	it("comes every 3 h for 45 min at 01:30, 04:30, ... UTC", function()
		expect(S.interval).toBe(3 * 3600)
		expect(S.duration).toBe(45 * 60)
		local index = WM.indexAt(NOON)
		local start = WM.startOf(index)
		expect(start % 86400).toBe(10 * 3600 + 1800) -- 10:30 UTC
		expect(WM.current(start - 1)).toBeNil()
		expect((WM.current(start) :: WM.Visit).index).toBe(index)
		expect((WM.current(start + S.duration - 1) :: WM.Visit).index).toBe(index)
		expect(WM.current(start + S.duration)).toBeNil()
		expect(WM.nextVisit(start + S.duration).startsAt).toBe(start + S.interval)
		expect(WM.shown(start - 100).startsAt).toBe(start)
	end)

	it("announces each warning, the arrival, the packing and the departure exactly once", function()
		local start = WM.startOf(WM.indexAt(NOON))
		local kinds: { string } = {}
		local t = start - 900
		while t < start + S.duration + 60 do
			for _, c in WM.crossed(t, t + 7) do
				table.insert(kinds, `{c.kind}{c.before or ""}`)
				expect(c.visit.startsAt).toBe(start)
			end
			t += 7
		end
		expect(kinds).toEqual({ "warn600", "warn60", "arrive", "leaving", "left" })
		-- a server starting mid-visit announces nothing it missed
		expect(#WM.crossed(start + 100, start + 100)).toBe(0)
	end)
end)

describe("Wandering merchant: spots (S159w)", function()
	it("every spot is on a known map with a band equal to the map's levels; ids are unique", function()
		local seen: { [string]: boolean } = {}
		for _, spot in Data.spots do
			expect({ spot.id, seen[spot.id] }).toEqual({ spot.id, nil })
			seen[spot.id] = true
			local map = Maps.get(spot.map)
			expect({ spot.id, map ~= nil }).toEqual({ spot.id, true })
			local band = Data.bands[spot.map]
			expect({ spot.id, band[1], band[2] }).toEqual({ spot.id, (map :: any).minLevel, (map :: any).maxLevel })
			expect({ spot.id, Data.mapWeights[spot.map] ~= nil }).toEqual({ spot.id, true })
		end
		for map in Data.mapWeights do
			expect({ map, #WM.spotsOf(map) >= 2 }).toEqual({ map, true })
		end
	end)

	it("city spots stand on open ground off the streets, the NPCs and the fountain, inside the walls", function()
		local city = Town.city
		for _, spot in Data.spots do
			if spot.map ~= "city" then
				continue
			end
			local yaw = math.rad(spot.facing)
			local wx = spot.x + math.sin(yaw) * Data.look.behind
			local wz = spot.z + math.cos(yaw) * Data.look.behind
			for _, p in { { spot.x, spot.z, 3 }, { wx, wz, 7 } } do
				local where = `{spot.id} ({p[1]}, {p[2]})`
				expect({ where, TownTerrain.isOpen(p[1], p[2], p[3]) }).toEqual({ where, true })
				expect({ where, TownGeom.inPoly(city.wall, p[1], p[2]) }).toEqual({ where, true })
			end
			for id, npc in Town.allNpcSpots() do
				local d = math.sqrt((npc.x - spot.x) ^ 2 + (npc.z - spot.z) ^ 2)
				expect({ spot.id, id, d >= 14 }).toEqual({ spot.id, id, true })
			end
			for _, street in city.streets do
				local gap = TownGeom.lineDist(street.pts, spot.x, spot.z) - street.w / 2
				expect({ spot.id, street.id, gap >= 3 }).toEqual({ spot.id, street.id, true })
			end
			local f = math.sqrt((spot.x - city.fountain[1]) ^ 2 + (spot.z - city.fountain[2]) ^ 2)
			expect({ spot.id, f >= 20 }).toEqual({ spot.id, true })
		end
	end)

	it("region spots stand in a no-monster circle, off the NPCs and the Elite II hideouts", function()
		for _, spot in Data.spots do
			if spot.map == "city" then
				continue
			end
			local data = Areas.byMap[spot.map]
			local inside = false
			for _, c in data.avoid do
				if math.sqrt((c.x - spot.x) ^ 2 + (c.z - spot.z) ^ 2) <= c.r - 4 then
					inside = true
				end
			end
			expect({ spot.id, inside }).toEqual({ spot.id, true })
			for id, npc in data.npcSpots or {} do
				local d = math.sqrt((npc.x - spot.x) ^ 2 + (npc.z - spot.z) ^ 2)
				expect({ spot.id, id, d >= 20 }).toEqual({ spot.id, id, true })
			end
			for _, lair in data.lairs or {} do
				local d = math.sqrt((lair.x - spot.x) ^ 2 + (lair.z - spot.z) ^ 2)
				expect({ spot.id, lair.id, d >= lair.r + 30 }).toEqual({ spot.id, lair.id, true })
			end
			for _, lake in data.lakes do
				local d = math.sqrt((lake.x - spot.x) ^ 2 + (lake.z - spot.z) ^ 2)
				expect({ spot.id, d >= lake.r + 10 }).toEqual({ spot.id, true })
			end
		end
	end)

	it("the spot is the same for every caller, never the same twice in a row, and every map gets visits", function()
		local start = WM.indexAt(NOON)
		local perMap: { [string]: number } = {}
		local prev = WM.spotOf(start - 1).id
		for index = start, start + 799 do
			local spot = WM.spotOf(index)
			expect(WM.visit(index).spot.id).toBe(spot.id)
			if spot.id == prev then
				error(`visit {index} repeats {spot.id}`)
			end
			prev = spot.id
			perMap[spot.map] = (perMap[spot.map] or 0) + 1
		end
		for map, weight in Data.mapWeights do
			local share = (perMap[map] or 0) / 800
			local want = weight / 6
			expect({ map, math.abs(share - want) < 0.08 }).toEqual({ map, true })
		end
	end)
end)

describe("Wandering merchant: stock (S159w)", function()
	it("rerolls every visit, the same everywhere, with 3 gear, 2 materials, a dye and 3 supplies", function()
		local start = WM.indexAt(NOON)
		local signatures: { [string]: boolean } = {}
		for index = start, start + 199 do
			local stock = WM.stock(index)
			local groups: { [string]: number } = {}
			local keys: { [string]: boolean } = {}
			local sig = {}
			for _, offer in stock do
				groups[offer.group] = (groups[offer.group] or 0) + 1
				expect({ index, offer.key, keys[offer.key] }).toEqual({ index, offer.key, nil })
				keys[offer.key] = true
				table.insert(sig, `{offer.key}:{offer.slot or offer.id}:{offer.rarity or 0}`)
			end
			expect(groups.gear).toBe(Data.gear.count)
			expect(groups.dye).toBe(1)
			expect(groups.consumable).toBe(Data.consumableCount)
			expect(groups.material).toBe(Data.materialCount)
			signatures[table.concat(sig, ",")] = true
		end
		local distinct = 0
		for _ in signatures do
			distinct += 1
		end
		expect(distinct > 190).toBe(true)
	end)

	it("gear is Unique, Heroic or rarely Legendary, never Mythic; one slot once a visit", function()
		local start = WM.indexAt(NOON)
		local counts: { [number]: number } = {}
		local total = 0
		for index = start, start + 999 do
			local slots: { [string]: boolean } = {}
			for _, offer in WM.stock(index) do
				if offer.kind == "gear" then
					local rarity = offer.rarity :: number
					expect(rarity >= Rarities.UNIQUE and rarity <= Rarities.LEGENDARY).toBe(true)
					expect(slots[offer.slot :: string]).toBeNil()
					slots[offer.slot :: string] = true
					counts[rarity] = (counts[rarity] or 0) + 1
					total += 1
					-- the Legendary only for Hunter's Marks, the others for gold
					expect(offer.currency).toBe(if rarity == Rarities.LEGENDARY then "marks" else "gold")
				end
			end
		end
		expect((counts[Rarities.LEGENDARY] or 0) / total < 0.06).toBe(true)
		expect((counts[Rarities.LEGENDARY] or 0) > 0).toBe(true)
		expect(counts[Rarities.MYTHIC]).toBeNil()
		for rarity in Data.gear.rarity do
			expect(rarity < Rarities.MYTHIC).toBe(true)
		end
	end)

	it("pool entries exist, are reached by the bands, and a region visit only draws what its band reaches", function()
		for _, pool in { Data.materials, Data.consumables } do
			for _, entry in pool do
				if entry.kind == "item" then
					expect({ entry.key, Items.get(entry.id) ~= nil }).toEqual({ entry.key, true })
				end
				expect({ entry.key, entry.limit >= 1, entry.n >= 1 }).toEqual({ entry.key, true, true })
			end
		end
		for _, line in Data.blessingLines do
			expect({ line, Items.get(`blessing_{line}_3`) ~= nil }).toEqual({ line, true })
		end
		local start = WM.indexAt(NOON)
		for index = start, start + 299 do
			local band = WM.visit(index).band
			for _, offer in WM.stock(index) do
				expect({ index, offer.key, offer.minLevel <= band[2] }).toEqual({ index, offer.key, true })
			end
		end
	end)

	it("gear of the buyer's class in the offer's slot (or another one he can wear) at the band's level", function()
		local start = WM.indexAt(NOON)
		local rng = Rng.new(7)
		for index = start, start + 59 do
			local visit = WM.visit(index)
			for _, offer in WM.stock(index) do
				if offer.kind == "gear" then
					for _, classId in { "Warrior", "Hunter", "Mage", "Cleric" } do
						local level = visit.band[2]
						local ilvl = WM.ilvlOf(visit.band, level)
						local defId = WM.pickGear(offer, ilvl, classId, rng)
						local def = Items.get(defId :: string)
						expect({ classId, def ~= nil }).toEqual({ classId, true })
						local d = def :: any
						expect({ classId, d.classes == nil or table.find(d.classes, classId) ~= nil }).toEqual({
							classId,
							true,
						})
					end
				end
			end
		end
		expect(WM.ilvlOf({ 45, 70 }, 90)).toBe(70)
		expect(WM.ilvlOf({ 45, 70 }, 50)).toBe(50)
		expect(WM.ilvlOf({ 1, 100 }, 33)).toBe(33)
	end)
end)

describe("Wandering merchant: buying (S159w)", function()
	local gearOffer: WM.Offer = {
		key = "gear1",
		kind = "gear",
		group = "gear",
		slot = "helmet",
		rarity = Rarities.HEROIC,
		n = 1,
		currency = "gold",
		perLevel = 1080,
		minLevel = 45,
		limit = 1,
	}
	local band = { 45, 70 }

	it("prices: gear by the item level, potions at 80 % of the alchemist, fixed ones as given", function()
		expect(WM.priceOf(gearOffer, 50, band)).toBe(1080 * 50)
		expect(WM.priceOf(gearOffer, 99, band)).toBe(1080 * 70)
		local potion: WM.Offer = {
			key = "con_potion_hp",
			kind = "potion",
			group = "consumable",
			id = "hp",
			n = 10,
			currency = "gold",
			price = 0.8,
			minLevel = 1,
			limit = 3,
		}
		local grant = WM.grant(potion, 50, "Warrior") :: WM.Grant
		local def = Items.get(grant.id) :: any
		expect(WM.priceOf(potion, 50, band, "Warrior")).toBe(math.floor(def.buyPrice * 10 * 0.8 + 0.5))
		local mage = WM.grant({ kind = "potion", id = "resource", n = 10 } :: any, 50, "Mage") :: WM.Grant
		expect(string.sub(mage.id, 1, 11)).toBe("potion_mana")
	end)

	it("needs the level, the money and room in the visit's limit; the limit resets on the next visit", function()
		local price = WM.priceOf(gearOffer, 50, band)
		expect({ WM.canBuy(gearOffer, 10, band, buyer(44, 10 ^ 9), "Warrior") }).toEqual({
			false,
			"wanderer.error.level",
		})
		expect({ WM.canBuy(gearOffer, 10, band, buyer(50, price - 1), "Warrior") }).toEqual({
			false,
			"wanderer.error.gold",
		})
		expect({ WM.canBuy(gearOffer, 10, band, buyer(50, price), "Warrior") }).toEqual({ true, nil })
		local bought = WM.counted(nil, 10, "gear1", 1)
		expect({ WM.canBuy(gearOffer, 10, band, buyer(50, price, 0, bought), "Warrior") }).toEqual({
			false,
			"wanderer.error.limit",
		})
		expect({ WM.canBuy(gearOffer, 11, band, buyer(50, price, 0, bought), "Warrior") }).toEqual({ true, nil })
		expect(WM.boughtAt(bought, 11, "gear1")).toBe(0)
		expect({ WM.canBuy(gearOffer, 10, band, buyer(50, price), "Warrior", 2) }).toEqual({
			false,
			"error.badRequest",
		})
		expect({ WM.canBuy(nil, 10, band, buyer(50, price), "Warrior") }).toEqual({ false, "error.badRequest" })
	end)

	it("the Legendary costs Hunter's Marks, not gold", function()
		local legendary = table.clone(gearOffer)
		legendary.rarity = Rarities.LEGENDARY
		legendary.currency = "marks"
		legendary.perLevel = nil
		legendary.price = 400
		expect({ WM.canBuy(legendary, 1, band, buyer(50, 10 ^ 9, 399), "Mage") }).toEqual({
			false,
			"wanderer.error.marks",
		})
		expect({ WM.canBuy(legendary, 1, band, buyer(50, 0, 400), "Mage") }).toEqual({ true, nil })
	end)

	it("a caravan dye: gold only, once per account, never for Dragon Shards nor in the weekly offer", function()
		for _, id in Data.dyes do
			local def = Cosmetics.get(id) :: any
			expect({ id, def ~= nil and def.kind == "dye" }).toEqual({ id, true })
			expect({ id, def.price, def.obtain and def.obtain.merchant, def.weekly }).toEqual({ id, 0, true, nil })
			expect({ id, (Premium.canBuyCosmetic(id, {}, 999999)) }).toEqual({ id, false })
		end
		local dye: WM.Offer = {
			key = "dye",
			kind = "dye",
			group = "dye",
			id = Data.dyes[1],
			n = 1,
			currency = "gold",
			price = Data.dyePrice,
			minLevel = 1,
			limit = 1,
		}
		local b = buyer(1, Data.dyePrice)
		b.owned = { [Data.dyes[1]] = true }
		expect({ WM.canBuy(dye, 1, band, b, "Warrior") }).toEqual({ false, "wanderer.error.owned" })
	end)

	it("no Robux product or shard purchase gives anything of the merchant; his NPC is not a fixed one", function()
		for _, entry in Products.shop or {} do
			local key = (entry :: any).key or ""
			expect({ key, string.find(key, "wanderer", 1, true) }).toEqual({ key, nil })
		end
		expect(Npcs.get("wanderer")).toBe(Npcs.WANDERER)
		for _, npc in Npcs.list do
			expect(npc.id ~= "wanderer").toBe(true)
		end
	end)
end)
