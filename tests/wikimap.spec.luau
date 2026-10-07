--!strict
-- Wiki map SVGs (S37, tools/WikiMaps): valid XML, the ids the wiki links to (areas, portals, cave mouths, NPCs,
-- world nodes and links), unique ids, coordinates inside the viewBox, label pairs, determinism, size budgets and
-- no remote references. Also the S37 exporter additions (tools/WikiData/Places): objective places, routes,
-- map search vectors, gathering placements.

local fs = require("@lune/fs")

local Areas = require("../src/shared/Data/Areas")
local MapSearch = require("../src/shared/Logic/MapSearch")
local Maps = require("../src/shared/Data/Maps")
local Npcs = require("../src/shared/Data/Npcs")
local Places = require("../tools/WikiData/Places")
local Portals = require("../src/shared/Data/Portals")
local QuestData = require("../src/shared/Data/Quests")
local T = require("./Test")
local WikiMap = require("../tools/WikiMaps")

local function readText(path: string): string?
	return if fs.isFile(path) then fs.readFile(path) else nil
end

local result = WikiMap.build({ readText = readText })
local files = result.files

-- Minimal XML check: balanced tags, quoted attributes, no raw & or < in text. Returns an error or nil, and the
-- attributes of every element.
local function parse(text: string): (string?, { { tag: string, attrs: { [string]: string } } })
	local stack = {}
	local elements = {}
	local i = 1
	local n = #text
	while i <= n do
		local lt = string.find(text, "<", i, true)
		local chunk = string.sub(text, i, (lt or n + 1) - 1)
		if string.find(chunk, "&", 1, true) then
			for amp in string.gmatch(chunk, "&[^;]*;?") do
				if not (amp == "&amp;" or amp == "&lt;" or amp == "&gt;" or amp == "&quot;") then
					return `bad entity {amp}`, elements
				end
			end
		end
		if string.find(chunk, ">", 1, true) then
			return "raw > in text", elements
		end
		if not lt then
			break
		end
		local gt = string.find(text, ">", lt, true)
		if not gt then
			return "unclosed tag", elements
		end
		local tag = string.sub(text, lt + 1, gt - 1)
		if string.sub(tag, 1, 1) == "/" then
			local name = string.sub(tag, 2)
			local top = table.remove(stack)
			if top ~= name then
				return `closing {name} but open {top}`, elements
			end
		else
			local selfClosing = string.sub(tag, -1) == "/"
			local body = if selfClosing then string.sub(tag, 1, -2) else tag
			local name = string.match(body, "^([%w:%-]+)")
			if not name then
				return `bad tag {tag}`, elements
			end
			local rest = string.sub(body, #name + 1)
			local attrs = {}
			local stripped = string.gsub(rest, '%s+([%w:%-]+)="([^"<]*)"', function(k: string, v: string): string
				attrs[k] = v
				return ""
			end)
			if string.match(stripped, "%S") then
				return `bad attributes in <{name}>: {stripped}`, elements
			end
			table.insert(elements, { tag = name, attrs = attrs })
			if not selfClosing then
				table.insert(stack, name)
			end
		end
		i = gt + 1
	end
	if #stack > 0 then
		return `unclosed {stack[#stack]}`, elements
	end
	return nil, elements
end

local parsed: { [string]: { { tag: string, attrs: { [string]: string } } } } = {}
local ids: { [string]: { [string]: boolean } } = {}

local function idsOf(name: string): { [string]: boolean }
	return ids[name] or {}
end

T.describe("wikimap: files", function()
	T.it("builds the world, the city, four regions and twelve caves", function()
		local names = {}
		for name in files do
			table.insert(names, name)
		end
		T.expect(#names).toBe(2 + 4 + #Areas.caves.list)
		for _, name in { "world", "city", "meadows", "duskwood", "ashen", "frostpeak" } do
			T.expect(files[name] ~= nil).toBe(true)
		end
	end)

	T.it("every file is valid XML with a viewBox root and unique ids", function()
		for name, text in files do
			local err, elements = parse(text)
			if err then
				error(`{name}: {err}`)
			end
			parsed[name] = elements
			T.expect(elements[1].tag).toBe("svg")
			T.expect(elements[1].attrs.viewBox ~= nil).toBe(true)
			local seen = {}
			for _, e in elements do
				local id = e.attrs.id
				if id then
					if seen[id] then
						error(`{name}: duplicate id {id}`)
					end
					seen[id] = true
				end
			end
			ids[name] = seen
		end
	end)

	T.it("coordinates are finite and inside the viewBox", function()
		for name, elements in parsed do
			local vb = elements[1].attrs.viewBox
			local x0, z0, w, h = string.match(vb, "^(%-?%d+) (%-?%d+) (%d+) (%d+)$")
			local bx, bz, bw, bh =
				tonumber(x0) :: number, tonumber(z0) :: number, tonumber(w) :: number, tonumber(h) :: number
			for _, e in elements do
				local t = e.attrs.transform
				if t then
					local x, z = string.match(t, "^translate%((%-?[%d%.]+) (%-?[%d%.]+)%)$")
					if not x then
						error(`{name}: bad transform {t}`)
					end
					local px, pz = tonumber(x) :: number, tonumber(z) :: number
					if px < bx or px > bx + bw or pz < bz or pz > bz + bh then
						error(`{name}: {e.attrs.id or e.tag} at {px} {pz} outside {vb}`)
					end
				end
				for _, key in { "x", "y", "cx", "cy", "width", "height", "r" } do
					local v = e.attrs[key]
					if v and not tonumber(v) then
						error(`{name}: {key}="{v}"`)
					end
				end
			end
		end
	end)

	T.it("every label comes as a pl / en pair", function()
		for name, text in files do
			local _, pl = string.gsub(text, '<text lang="pl"', "")
			local _, en = string.gsub(text, '<text lang="en"', "")
			if pl ~= en then
				error(`{name}: {pl} Polish and {en} English labels`)
			end
		end
	end)

	T.it("is deterministic", function()
		local again = WikiMap.build({ readText = readText }).files
		for name, text in files do
			T.expect(again[name] == text).toBe(true)
		end
	end)

	T.it("stays within the size budgets and has no remote references", function()
		for name, text in files do
			local budget = WikiMap.BUDGET[WikiMap.kindOf(name)]
			if #text > budget then
				error(`{name}: {#text} bytes > {budget}`)
			end
			T.expect(string.find(text, "rbxassetid", 1, true)).toBeNil()
			local withoutNs = string.gsub(text, 'xmlns="http://www.w3.org/2000/svg"', "")
			T.expect(string.find(withoutNs, "http", 1, true)).toBeNil()
		end
	end)
end)

T.describe("wikimap: ids the wiki links to", function()
	T.it("every area, portal, cave mouth and NPC of a map has its element", function()
		for mapId, data in Areas.byMap do
			local set = idsOf(mapId)
			for _, a in data.areas do
				T.expect(set[`area-{a.id}`]).toBe(true)
			end
			for _, c in data.caves do
				T.expect(set[`cave-{c.cave}`]).toBe(true)
			end
		end
		for _, p in Portals.list do
			if p.kind ~= "cave" and files[p.map] then
				if not idsOf(p.map)[`portal-{p.id}`] then
					error(`{p.map}: no portal-{p.id}`)
				end
			end
		end
		for _, n in Npcs.list do
			if not n.decoration and files[n.map] then
				T.expect(idsOf(n.map)[`npc-{n.id}`]).toBe(true)
			end
		end
	end)

	T.it("every placed map is a world node and every link a line", function()
		local set = idsOf("world")
		for id, m in Maps.byId do
			if m.worldMap.x ~= 0 or m.worldMap.y ~= 0 then
				T.expect(set[`node-{id}`]).toBe(true)
				for _, other in m.links do
					local o = Maps.byId[other]
					if o and (o.worldMap.x ~= 0 or o.worldMap.y ~= 0) then
						local a, b = if id < other then id else other, if id < other then other else id
						if not set[`link-{a}--{b}`] then
							error(`world: no link-{a}--{b}`)
						end
					end
				end
			end
		end
	end)

	T.it("the boss cave of every region shows the dungeon gate and the boss", function()
		for _, cave in Areas.caves.list do
			if cave.boss then
				T.expect(idsOf(cave.id)[`portal-dungeon_{cave.region}`]).toBe(true)
			end
		end
	end)
end)

T.describe("wikidump: places (S37)", function()
	T.it("objective places point at existing maps, areas, caves and NPCs", function()
		local n = 0
		for _, list in { QuestData.Main.list, QuestData.Side.list } do
			for _, q in list do
				for _, o in q.objectives do
					local w = Places.objectiveWhere(o, q.level, q.turnIn)
					if w then
						n += 1
						T.expect(Maps.byId[w.map] ~= nil).toBe(true)
						if w.area then
							local area, mapId = Areas.areaById(w.area)
							T.expect(area ~= nil and mapId == w.map).toBe(true)
						end
						if w.cave then
							T.expect(Areas.caves.get(w.cave) ~= nil).toBe(true)
						end
						if w.npc then
							T.expect(Npcs.get(w.npc) ~= nil).toBe(true)
						end
					end
				end
			end
		end
		T.expect(n > 50).toBe(true)
	end)

	T.it("every route starts in the city and ends on its map", function()
		for id in Maps.byId do
			local route = Places.route(id)
			if route then
				T.expect(route[1]).toBe("city")
				T.expect(route[#route]).toBe(id)
			end
		end
	end)

	T.it("the map search has one entry per MapSearch entry in each language", function()
		local data = Places.mapsearch({})
		local index = MapSearch.build(function(key: string): string
			return key
		end)
		T.expect(#data.pl).toBe(#index.entries)
		T.expect(#data.en).toBe(#index.entries)
		local laki = data.vectors[1]
		T.expect(laki.query).toBe("laki")
		T.expect(laki.results[1]).toBe("map:meadows")
	end)

	T.it("gathering placements lie inside their maps", function()
		local warnings = {}
		local placements = Places.gather(readText, warnings)
		for mapId, list in placements do
			local half = Maps.byId[mapId].size.x / 2
			T.expect(#list > 0).toBe(true)
			for _, p in list do
				local coords = p.rect or { p.x, p.z }
				for _, v in coords do
					T.expect(math.abs(v) <= half).toBe(true)
				end
			end
		end
	end)
end)

return nil
