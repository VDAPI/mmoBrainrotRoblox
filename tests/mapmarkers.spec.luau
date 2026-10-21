--!strict
-- Owner 2026-10-20 "Mapa": world map symbol categories, the saved filter and the declutter layout (Logic/MapMarkers).

local MapMarkers = require("../src/shared/Logic/MapMarkers")
local Npcs = require("../src/shared/Data/Npcs")
local UiPalette = require("../src/shared/Data/UiPalette")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local SIZE = 40

local function dist(a: MapMarkers.Placed, b: MapMarkers.Placed): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

describe("Map marker categories", function()
	it("every category has a palette colour, a glyph and a name in both languages", function()
		local bad = {}
		for _, category in MapMarkers.CATEGORIES do
			local key = `worldmap.cat.{category.id}`
			if
				(UiPalette.map :: any)[category.color] == nil
				or category.glyph == ""
				or pl[key] == nil
				or en[key] == nil
			then
				table.insert(bad, category.id)
			end
		end
		expect(bad).toEqual({})
	end)

	it("NPC categories: quest mark first, then services, else plain", function()
		expect(MapMarkers.npcCategory({ "talk", "shop" })).toBe("shop")
		expect(MapMarkers.npcCategory({ "talk", "shop" }, true)).toBe("quest")
		expect(MapMarkers.npcCategory({ "blacksmith" })).toBe("smith")
		expect(MapMarkers.npcCategory({ "mail" })).toBe("bank")
		expect(MapMarkers.npcCategory({ "story" })).toBe("quest")
		expect(MapMarkers.npcCategory({ "talk" })).toBe("npc")
		expect(MapMarkers.npcCategory({})).toBe("npc")
	end)

	it("every NPC service maps to a known category", function()
		for _, npc in Npcs.list do
			expect(MapMarkers.byId[MapMarkers.npcCategory(npc.services)] ~= nil).toBe(true)
		end
		for _, category in MapMarkers.SERVICE_CATEGORY do
			expect(MapMarkers.byId[category] ~= nil).toBe(true)
		end
	end)

	it("search kinds and icon kinds map to categories", function()
		for _, kind in { "portal", "map", "cave", "dungeon", "boss", "lair", "worldboss", "node", "area", "monster" } do
			expect(MapMarkers.byId[MapMarkers.kindCategory(kind)] ~= nil).toBe(true)
		end
		expect(MapMarkers.kindCategory("boss")).toBe("dungeon")
	end)
end)

describe("Map filter setting", function()
	it("round-trips the hidden set and drops unknown ids", function()
		local set = MapMarkers.hiddenSet({ "node", "npc", "nope", 5 })
		expect(set).toEqual({ node = true, npc = true })
		expect(MapMarkers.hiddenList(set)).toEqual({ "npc", "node" })
		expect(MapMarkers.hiddenSet(nil)).toEqual({})
	end)

	it("validates the saved list", function()
		expect(MapMarkers.validHidden({})).toBe(true)
		expect(MapMarkers.validHidden({ "node", "shop" })).toBe(true)
		expect(MapMarkers.validHidden({ "node", "node" })).toBe(false)
		expect(MapMarkers.validHidden({ "bogus" })).toBe(false)
		expect(MapMarkers.validHidden({ a = "node" })).toBe(false)
		expect(MapMarkers.validHidden("node")).toBe(false)
		expect(MapMarkers.validHidden(MapMarkers.hiddenList(MapMarkers.setAll(false)))).toBe(true)
	end)

	it("toggle, all and none", function()
		local set = MapMarkers.toggle({}, "cave")
		expect(set).toEqual({ cave = true })
		expect(MapMarkers.toggle(set, "cave")).toEqual({})
		expect(MapMarkers.setAll(true)).toEqual({})
		local none = MapMarkers.setAll(false)
		expect(#MapMarkers.hiddenList(none)).toBe(#MapMarkers.CATEGORIES)
	end)
end)

describe("Map marker layout", function()
	it("far apart icons stay where they are", function()
		local layout = MapMarkers.layout({
			{ key = "a", x = 0, y = 0, priority = 1 },
			{ key = "b", x = 100, y = 0, priority = 1 },
		}, 1, { size = SIZE })
		expect(layout.placed.a).toEqual({ x = 0, y = 0 })
		expect(layout.placed.b).toEqual({ x = 100, y = 0 })
		expect(#layout.clusters).toBe(0)
	end)

	it("two overlapping icons are nudged one icon apart, keeping their side", function()
		local layout = MapMarkers.layout({
			{ key = "a", x = 0, y = 0, priority = 1 },
			{ key = "b", x = 10, y = 0, priority = 1 },
		}, 1, { size = SIZE })
		expect(dist(layout.placed.a, layout.placed.b)).toBeNear(SIZE, 1e-6)
		expect(layout.placed.a.x < layout.placed.b.x).toBe(true)
		expect(#layout.clusters).toBe(0)
	end)

	it("nudging works in screen pixels: zoomed in, the same icons no longer overlap", function()
		local points = {
			{ key = "a", x = 0, y = 0, priority = 1 },
			{ key = "b", x = 10, y = 0, priority = 1 },
		}
		local layout = MapMarkers.layout(points, 4, { size = SIZE })
		expect(layout.placed.a).toEqual({ x = 0, y = 0 })
		expect(layout.placed.b).toEqual({ x = 10, y = 0 })
	end)

	it("three coincident icons spread on a ring with every pair at least one icon apart", function()
		local layout = MapMarkers.layout({
			{ key = "a", x = 50, y = 50, priority = 3 },
			{ key = "b", x = 50, y = 50, priority = 2 },
			{ key = "c", x = 50, y = 50, priority = 1 },
		}, 1, { size = SIZE })
		expect(#layout.clusters).toBe(0)
		for _, pair in { { "a", "b" }, { "b", "c" }, { "a", "c" } } do
			expect(dist(layout.placed[pair[1]], layout.placed[pair[2]]) >= SIZE - 1e-6).toBe(true)
		end
	end)

	it("a crowd becomes one cluster at its centre, and spreads at the closest zoom", function()
		local points = {}
		for i = 1, 6 do
			table.insert(points, { key = `n{i}`, x = 100 + i, y = 100, priority = i })
		end
		local layout = MapMarkers.layout(points, 1, { size = SIZE })
		expect(#layout.clusters).toBe(1)
		expect(#layout.clusters[1].members).toBe(6)
		expect(layout.clusters[1].x).toBeNear(103.5, 1e-6)
		expect(layout.clusters[1].members[1]).toBe("n6") -- most important first
		expect(layout.placed.n1).toBeNil()
		local spread = MapMarkers.layout(points, 1, { size = SIZE, spread = true })
		expect(#spread.clusters).toBe(0)
		for i = 1, 6 do
			expect(spread.placed[`n{i}`] ~= nil).toBe(true)
		end
	end)

	it("a click on a cluster zooms to where it splits (or the closest zoom)", function()
		local zooms = { 1, 1.6, 2.5, 4 }
		local loose = {}
		for i = 1, 4 do
			table.insert(loose, { key = `a{i}`, x = i * 12, y = 0, priority = 1 })
		end
		expect(#MapMarkers.layout(loose, 1, { size = SIZE }).clusters).toBe(1)
		expect(MapMarkers.splitZoom(loose, zooms, 1, SIZE)).toBe(2)
		local tight = {}
		for i = 1, 5 do
			table.insert(tight, { key = `t{i}`, x = 0, y = 0, priority = 1 })
		end
		expect(MapMarkers.splitZoom(tight, zooms, 1, SIZE)).toBe(4)
	end)
end)

describe("Map area plates", function()
	local rect = { x0 = 0, y0 = 0, x1 = 200, y1 = 100 }

	it("a plate goes to the centre of a free area", function()
		local spot, x, y = MapMarkers.placeLabel(rect, 80, 30, 1, {}, SIZE)
		expect(spot).toBe("centre")
		expect(x).toBe(100)
		expect(y).toBe(50)
	end)

	it("an icon in the middle pushes the plate to the top, then the bottom", function()
		expect((MapMarkers.placeLabel(rect, 80, 20, 1, { { x = 100, y = 50 } }, SIZE))).toBe("top")
		expect((MapMarkers.placeLabel(rect, 80, 20, 1, { { x = 100, y = 50 }, { x = 100, y = 10 } }, SIZE))).toBe(
			"bottom"
		)
	end)

	it("no room: the plate hides (until the zoom makes room)", function()
		expect((MapMarkers.placeLabel(rect, 300, 20, 1, {}, SIZE))).toBeNil()
		expect((MapMarkers.placeLabel(rect, 300, 20, 2, {}, SIZE))).toBe("centre")
	end)

	it("text width grows with the characters, not the bytes", function()
		expect(MapMarkers.textWidth("Łąki", 10)).toBeNear(4 * 10 * 0.56, 1e-6)
	end)
end)
