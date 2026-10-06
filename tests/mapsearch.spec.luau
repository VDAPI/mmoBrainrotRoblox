--!strict
-- S25: world map search (Logic/MapSearch) with the real Polish and English texts.

local MapSearch = require("../src/shared/Logic/MapSearch")
local Maps = require("../src/shared/Data/Maps")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function translate(lang: { [string]: string }): MapSearch.Translate
	return function(key: string): string
		return lang[key] or ""
	end
end

local plIndex = MapSearch.build(translate(pl))
local enIndex = MapSearch.build(translate(en))

local function ids(index: MapSearch.Index, query: string): { [string]: boolean }
	local out = {}
	for _, result in MapSearch.search(index, query) do
		out[result.id] = true
	end
	return out
end

describe("MapSearch", function()
	it("normalize folds case and Polish letters", function()
		expect(MapSearch.normalize("Szepczące ŁĄKI")).toBe("szepczace laki")
		expect(MapSearch.normalize("  Żółć,  Źdźbło!  ")).toBe("zolc zdzblo")
		expect(MapSearch.normalize("")).toBe("")
	end)

	it("kowal finds the blacksmith first", function()
		local results = MapSearch.search(plIndex, "kowal")
		expect(results[1].kind).toBe("npc")
		expect(results[1].id).toBe("blacksmith")
		expect(ids(enIndex, "smith").blacksmith).toBe(true)
	end)

	it("laki without Polish letters finds the Whispering Meadows", function()
		local results = MapSearch.search(plIndex, "laki")
		expect(results[1].kind).toBe("map")
		expect(results[1].id).toBe("meadows")
	end)

	it("service words find their NPCs", function()
		expect(ids(plIndex, "poczta").auctioneer).toBe(true)
		expect(ids(plIndex, "sklep").merchant).toBe(true)
		expect(ids(plIndex, "alchemia").alchemist).toBe(true)
		expect(ids(enIndex, "bank").banker).toBe(true)
	end)

	it("a word starting with the query ranks above a match inside a word", function()
		local index = MapSearch.build(function(key: string): string
			return key
		end, {
			{ kind = "node", id = "middle", map = "city", x = 0, z = 0, labelKey = "middle", texts = { "Nakowalnia" } },
			{
				kind = "node",
				id = "inside",
				map = "city",
				x = 0,
				z = 0,
				labelKey = "inside",
				texts = { "Stary kowal" },
			},
		})
		local order = {}
		for _, result in MapSearch.search(index, "kowal") do
			if result.id == "inside" or result.id == "middle" then
				table.insert(order, result.id)
			end
		end
		expect(order).toEqual({ "inside", "middle" })
	end)

	it("returns at most 12 results and nothing for an empty query", function()
		expect(#MapSearch.search(plIndex, "a")).toBe(MapSearch.LIMIT)
		expect(MapSearch.LIMIT).toBe(12)
		expect(#MapSearch.search(plIndex, "a", 3)).toBe(3)
		expect(MapSearch.search(plIndex, "")).toEqual({})
		expect(MapSearch.search(plIndex, "   ")).toEqual({})
	end)

	it("monsters are found by variant names and bosses by name", function()
		expect(#MapSearch.search(plIndex, "wilk") > 0).toBe(true)
		local boss = MapSearch.search(enIndex, "grimrok")
		expect(boss[1].kind).toBe("boss")
		expect(boss[1].map).toBe("meadows_cave")
	end)

	it("every entry points inside its map", function()
		local outside = {}
		for _, item in plIndex.entries do
			local entry = item.entry
			local map = Maps.get(entry.map)
			if not map or math.abs(entry.x) > map.size.x / 2 or math.abs(entry.z) > map.size.z / 2 then
				table.insert(outside, entry.id)
			end
		end
		expect(outside).toEqual({})
	end)
end)

return nil
