--!strict
-- Owner 2026-11-01 (docs/DESIGN.md §13a, Logic/TeleportStone): every everlasting teleport stone rests 30 minutes after a
-- teleport, each its own (`cd`, an absolute time, so it runs over a logout); a resting stone is refused with the minutes
-- left; the Everlasting Map and Dungeon Stone are set for good to a place on their first use (`at`; the Map Stone only to
-- visited maps, caves and crypts included, never boss dungeons or server-mode maps); a character holds several set Map
-- Stones that never stack; the Everlasting Map Stone is bought again and again; stones bought before are set at their
-- next use. Single-use stones keep the old rules.

local serde = require("@lune/serde")

local Inventory = require("../src/shared/Logic/Inventory")
local ItemRoll = require("../src/shared/Logic/ItemRoll")
local Items = require("../src/shared/Data/Items")
local Locale = require("../src/shared/Util/Locale")
local Main = require("../src/shared/Data/Quests/Main")
local Maps = require("../src/shared/Data/Maps")
local PortalData = require("../src/shared/Data/PortalShop")
local PortalShop = require("../src/shared/Logic/PortalShop")
local TeleportStone = require("../src/shared/Logic/TeleportStone")
local TooltipModel = require("../src/shared/Logic/TooltipModel")
local T = require("./Test")

local NOW = 1_800_000_000 -- any os.time

local function stone(id: string, uid: string?): any
	return ItemRoll.makeStack(id, 1, uid or id)
end

local function visited(list: { string }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, id in list do
		out[id] = true
	end
	return out
end

-- Set for good the way TravelService does it: the refusal first, then `at` on a copy.
local function set(item: any, target: string, seen: { [string]: boolean }?): (any, string?)
	local refused = TeleportStone.setRefusal(item, Items.get(item.id), target, seen)
	if refused then
		return nil, refused
	end
	local copy = table.clone(item)
	copy.at = target
	return copy, nil
end

-- What the save keeps between sessions: the plain fields, encoded and decoded.
local function saved(item: any): any
	return serde.decode("json", serde.encode("json", item))
end

T.describe("Everlasting teleport stones (owner 2026-11-01)", function()
	T.it("every everlasting stone rests 30 minutes; single-use stones never", function()
		T.expect(TeleportStone.COOLDOWN).toBe(30 * 60)
		for _, entry in PortalData.list do
			T.expect({ entry.permId, TeleportStone.everlasting(Items.get(entry.permId)) })
				.toEqual({ entry.permId, true })
			T.expect({ entry.itemId, TeleportStone.everlasting(Items.get(entry.itemId)) })
				.toEqual({ entry.itemId, false })
			local rested = TeleportStone.rested(stone(entry.permId), NOW)
			T.expect({ entry.permId, TeleportStone.restLeft(rested, NOW) }).toEqual({ entry.permId, 30 * 60 })
			T.expect(TeleportStone.restLeft(stone(entry.itemId), NOW)).toBe(0)
		end
	end)

	T.it("each stone rests on its own (not by kind or by place)", function()
		local a = TeleportStone.rested(stone("stone_return_perm", "a"), NOW)
		local b = stone("stone_return_perm", "b")
		local c = stone("stone_dungeon_meadows_perm", "c")
		T.expect(TeleportStone.restLeft(a, NOW + 60)).toBe(30 * 60 - 60)
		T.expect(TeleportStone.restLeft(b, NOW + 60)).toBe(0)
		T.expect(TeleportStone.restLeft(c, NOW + 60)).toBe(0)
		local fresh = stone("stone_map_perm", "d")
		local used = TeleportStone.rested(fresh, NOW)
		T.expect(fresh.cd).toBeNil() -- the stone it was made from is untouched
		T.expect(used.uid).toBe("d")
	end)

	T.it("the rest is an absolute time, so it runs while the player is offline", function()
		local used = saved(TeleportStone.rested(stone("stone_map_perm"), NOW))
		T.expect(used.cd).toBe(NOW + 30 * 60)
		T.expect(TeleportStone.restLeft(used, NOW + 20 * 60)).toBe(10 * 60) -- back after 20 minutes on another server
		T.expect(TeleportStone.restLeft(used, NOW + 3600)).toBe(0) -- back after an hour: ready
	end)

	T.it("a resting stone is refused with the minutes left, rounded up", function()
		local used = TeleportStone.rested(stone("stone_return_perm"), NOW)
		T.expect(TeleportStone.minutesLeft(used, NOW)).toBe(30)
		T.expect(TeleportStone.minutesLeft(used, NOW + 30 * 60 - 61)).toBe(2)
		T.expect(TeleportStone.minutesLeft(used, NOW + 30 * 60 - 1)).toBe(1)
		T.expect(TeleportStone.minutesLeft(used, NOW + 30 * 60)).toBe(0)
		for _, lang in { "pl", "en" } do
			local text = Locale.T("teleport.cooldown", { minutes = 12 }, lang)
			T.expect({ lang, string.find(text, "12", 1, true) ~= nil }).toEqual({ lang, true })
			T.expect(Locale.has("teleport.cooldownShort", lang)).toBe(true)
		end
		-- the server refuses before the channel, the client before asking it (one rule)
		local travel = require("@lune/fs").readFile("src/server/Services/TravelService.luau")
		T.expect(string.find(travel, "TeleportStone.restLeft(item, os.time())", 1, true) ~= nil).toBe(true)
		local items = require("@lune/fs").readFile("src/client/Controllers/ItemController.luau")
		T.expect(string.find(items, "TeleportStone.minutesLeft(item, Workspace:GetServerTimeNow())", 1, true) ~= nil)
			.toBe(true)
	end)

	T.it("the Everlasting Map and Dungeon Stone are set once; the other stones never", function()
		for _, entry in PortalData.list do
			local def = Items.get(entry.permId) :: any
			local wanted = def.use.target == "map" or def.use.target == "dungeon"
			T.expect({ entry.permId, TeleportStone.sets(def) }).toEqual({ entry.permId, wanted })
			T.expect({ entry.itemId, TeleportStone.sets(Items.get(entry.itemId)) }).toEqual({ entry.itemId, false })
		end
		local seen = visited({ "city", "meadows", "duskwood" })
		local done = set(stone("stone_map_perm"), "meadows", seen)
		T.expect(done.at).toBe("meadows")
		T.expect({ set(done, "duskwood", seen) }).toEqual({ nil, "teleport.bound" })
		T.expect({ set(done, "meadows", seen) }).toEqual({ nil, "teleport.bound" })
		T.expect({ set(stone("stone_map"), "meadows", seen) }).toEqual({ nil, "error.badRequest" })
		T.expect({ set(stone("stone_return_perm"), "city", seen) }).toEqual({ nil, "error.badRequest" })
	end)

	T.it("the Map Stone is set only to a place the character visited", function()
		local seen = visited({ "city", "meadows" })
		T.expect({ set(stone("stone_map_perm"), "duskwood", seen) }).toEqual({ nil, "teleport.notVisited" })
		T.expect({ set(stone("stone_map_perm"), "duskwood", nil) }).toEqual({ nil, "teleport.notVisited" })
		T.expect({ set(stone("stone_map_perm"), "nowhere", visited({ "nowhere" })) }).toEqual({
			nil,
			"teleport.notVisited",
		})
		T.expect(TeleportStone.mapPlaces(seen)).toEqual({ "city", "meadows" })
	end)

	T.it("caves and crypts are Map Stone places; boss dungeons and server-mode maps are not", function()
		local all: { string } = {}
		for id in Maps.byId do
			table.insert(all, id)
		end
		local seen = visited(all)
		local places = TeleportStone.mapPlaces(seen)
		local caves, crypts = 0, 0
		for id, map in Maps.byId do
			local place = table.find(places, id) ~= nil
			T.expect({ id, place }).toEqual({ id, map.biome ~= "dungeon" and map.serverModes == nil })
			if place and map.biome == "cave" then
				caves += 1
			elseif place and map.biome == "crypt" then
				crypts += 1
			end
		end
		T.expect(caves >= 4 and crypts >= 2).toBe(true)
		for _, id in { "meadows_hideout", "duskwood_barrow", "meadows_cave" } do
			T.expect({ id, (set(stone("stone_map_perm"), id, seen)) ~= nil }).toEqual({ id, true })
		end
		for _, id in { "dungeon_meadows", "arena_pit" } do
			T.expect({ set(stone("stone_map_perm"), id, seen) }).toEqual({ nil, "teleport.notVisited" })
		end
		-- the server's trip and the picker use the same rule
		local fs = require("@lune/fs")
		local travel = fs.readFile("src/server/Services/TravelService.luau")
		T.expect(string.find(travel, "TeleportStone.isMapPlace(mapId, char.visitedMaps)", 1, true) ~= nil).toBe(true)
		local picker = fs.readFile("src/client/UI/Screens/StonePicker.luau")
		T.expect(string.find(picker, "TeleportStone.mapPlaces(use(visited))", 1, true) ~= nil).toBe(true)
	end)

	T.it("the Dungeon Stone is set to a boss dungeon entrance, its name in the tooltip", function()
		for _, region in { "meadows", "duskwood", "ashen", "frostpeak" } do
			local done = set(stone("stone_dungeon_perm"), region, nil)
			T.expect({ region, done and done.at }).toEqual({ region, region })
			T.expect(TeleportStone.placeKey(Items.get("stone_dungeon_perm"), region)).toBe(`dungeon.{region}`)
		end
		T.expect({ set(stone("stone_dungeon_perm"), "moon", nil) }).toEqual({ nil, "teleport.soon" })
		T.expect(TeleportStone.placeKey(Items.get("stone_map_perm"), "meadows"))
			.toBe((Maps.get("meadows") :: any).nameKey)
	end)

	T.it("a character holds several set Map Stones, each its own slot and rest", function()
		local seen = visited({ "meadows", "duskwood", "duskwood_den" })
		local inv: Inventory.Inventory = {}
		local n = 0
		local function uid(): string
			n += 1
			return `u{n}`
		end
		Inventory.add(inv, 10, set(stone("stone_map_perm", "a"), "meadows", seen), uid)
		Inventory.add(inv, 10, TeleportStone.rested(set(stone("stone_map_perm", "b"), "duskwood_den", seen), NOW), uid)
		Inventory.add(inv, 10, set(stone("stone_map_perm", "c"), "meadows", seen), uid)
		Inventory.add(inv, 10, stone("stone_map_perm", "d"), uid)
		Inventory.add(inv, 10, stone("stone_map_perm", "e"), uid)
		T.expect(Inventory.used(inv)).toBe(5)
		local places: { string } = {}
		for _, item in inv do
			T.expect(item.n).toBe(1)
			table.insert(places, item.at or "-")
			local wanted = if item.uid == "b" then 30 * 60 else 0
			T.expect({ item.uid, TeleportStone.restLeft(item, NOW) }).toEqual({ item.uid, wanted })
		end
		table.sort(places)
		T.expect(places).toEqual({ "-", "-", "duskwood_den", "meadows", "meadows" })
	end)

	T.it("everlasting stones never stack (moves and sorting keep them apart)", function()
		for _, entry in PortalData.list do
			T.expect({ entry.permId, Inventory.canMerge(stone(entry.permId, "x"), stone(entry.permId, "y")) }).toEqual({
				entry.permId,
				false,
			})
			T.expect({ entry.itemId, Inventory.canMerge(stone(entry.itemId, "x"), stone(entry.itemId, "y")) }).toEqual({
				entry.itemId,
				true,
			})
		end
		local seen = visited({ "meadows", "duskwood" })
		local inv: Inventory.Inventory = {
			["1"] = set(stone("stone_map_perm", "a"), "meadows", seen),
			["2"] = set(stone("stone_map_perm", "b"), "duskwood", seen),
		}
		T.expect(Inventory.move(inv, 10, 1, 2)).toEqual({ 1, 2 })
		T.expect({ inv["1"].at, inv["2"].at }).toEqual({ "duskwood", "meadows" })
		Inventory.sort(inv, 10, function(): string
			return "s"
		end)
		T.expect(Inventory.used(inv)).toBe(2)
	end)

	T.it("the Everlasting Map Stone is bought again and again; the other stones once per account", function()
		for _, entry in PortalData.list do
			local owner = { dragonShards = 100000, portalStones = { [entry.itemId] = true } }
			local wanted = entry.itemId == "stone_map"
			T.expect({ entry.itemId, entry.many == true }).toEqual({ entry.itemId, wanted })
			local ok, err = PortalShop.canBuy(entry, "perm", 1, owner, 3)
			T.expect({ entry.itemId, ok, err }).toEqual({
				entry.itemId,
				wanted,
				if wanted then nil else "portalshop.error.owned",
			})
			-- the free copy stays one at a time
			T.expect({ PortalShop.canBuy(entry, "claim", 1, owner, 1) }).toEqual({ false, "portalshop.error.have" })
			T.expect({ PortalShop.canBuy(entry, "claim", 1, owner, 0) }).toEqual({ true, nil })
		end
		local map = PortalData.get("stone_map") :: PortalData.Entry
		local poor = { dragonShards = map.perm - 1, portalStones = { stone_map = true } }
		T.expect({ PortalShop.canBuy(map, "perm", 1, poor) }).toEqual({ false, "premium.error.shards" })
	end)

	T.it("stones bought before the rule are ready at once and set at their next use", function()
		for _, id in { "stone_map_perm", "stone_dungeon_perm" } do
			local old = stone(id) -- an old save: no `at`, no `cd`
			T.expect({ id, old.at, TeleportStone.restLeft(old, NOW) }).toEqual({ id, nil, 0 })
			local target = if id == "stone_map_perm" then "city" else "ashen"
			T.expect({ id, (set(old, target, visited({ "city" }))).at }).toEqual({ id, target })
		end
	end)

	T.it("the tooltip shows the place and the rest, also in its short view", function()
		local seen = visited({ "meadows_hideout" })
		local function texts(item: any, now: number?): string
			local out = {}
			for _, line in TooltipModel.build(item, nil, { lang = "pl", now = now, view = "compact" }).lines do
				table.insert(out, `{line.role}={line.text}`)
			end
			return table.concat(out, "\n")
		end
		local done = TeleportStone.rested(set(stone("stone_map_perm"), "meadows_hideout", seen), NOW)
		local text = texts(done, NOW + 60)
		local place = Locale.T((Maps.get("meadows_hideout") :: any).nameKey, nil, "pl")
		T.expect(string.find(text, Locale.T("tooltip.stoneAt", { map = place }, "pl"), 1, true) ~= nil).toBe(true)
		T.expect(string.find(text, Locale.T("tooltip.stoneRest", { minutes = 29 }, "pl"), 1, true) ~= nil).toBe(true)
		T.expect(string.find(texts(done, NOW + 3600), "stoneRest=", 1, true)).toBeNil()
		local dungeon = set(stone("stone_dungeon_perm"), "ashen", nil)
		local name = Locale.T("dungeon.ashen", nil, "pl")
		T.expect(string.find(texts(dungeon, NOW), Locale.T("tooltip.stoneAt", { map = name }, "pl"), 1, true) ~= nil)
			.toBe(true)
	end)

	T.it("the rest starts only when the teleport arrives", function()
		local travel = require("@lune/fs").readFile("src/server/Services/TravelService.luau")
		local lines = string.split(travel, "\n")
		local starts = 0
		for i, line in lines do
			if string.find(line, "startRest(player, keptUid)", 1, true) then
				starts += 1
				-- inside the channel's `arrive`, right before the teleport (a refused or broken channel never rests)
				local nextLine = lines[i + 1] or ""
				T.expect({ i, string.find(nextLine, "TravelService.TeleportToMap(", 1, true) ~= nil })
					.toEqual({ i, true })
			end
		end
		T.expect(starts).toBe(3) -- the capital, a map, a dungeon
	end)

	T.it("an unset Map or Dungeon Stone asks first; the server sets it on the character's copy", function()
		local fs = require("@lune/fs")
		local items = fs.readFile("src/client/Controllers/ItemController.luau")
		T.expect(string.find(items, "GatherController.OpenStonePicker(index, use.target, keep)", 1, true) ~= nil)
			.toBe(true)
		local picker = fs.readFile("src/client/UI/Screens/StonePicker.luau")
		T.expect(string.find(picker, 'Text.now("teleport.setConfirm", { map = choice.label })', 1, true) ~= nil)
			.toBe(true)
		local travel = fs.readFile("src/server/Services/TravelService.luau")
		T.expect(string.find(travel, "TeleportStone.setRefusal(item, def, target, char.visitedMaps)", 1, true) ~= nil)
			.toBe(true)
		for _, lang in { "pl", "en" } do
			for _, key in { "teleport.setTitle", "teleport.setConfirm", "teleport.setYes", "teleport.attuned" } do
				T.expect({ lang, key, Locale.has(key, lang) }).toEqual({ lang, key, true })
			end
		end
	end)

	T.it("an everlasting stone stays out of the vault (no free copies past the rest)", function()
		local deposit = require("@lune/fs").readFile("src/server/Services/DepositService.luau")
		T.expect(string.find(deposit, "TeleportStone.everlasting(Items.get(item.id))", 1, true) ~= nil).toBe(true)
		for _, lang in { "pl", "en" } do
			T.expect(Locale.has("deposit.error.stone", lang)).toBe(true)
		end
	end)

	T.it("one main quest gives one unset Everlasting Map Stone", function()
		local found = 0
		for _, quest in Main.list do
			for _, item in ((quest :: any).reward.items or {}) :: { any } do
				if item.id == "stone_map_perm" then
					found += 1
					T.expect(item.n).toBe(1)
				end
			end
		end
		T.expect(found).toBe(1)
	end)
end)
