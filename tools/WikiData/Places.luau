--!strict
-- Where things are in the world (S37, docs/WIKI.md §5): the map search index of the game (mapsearch.json, built by
-- Logic/MapSearch in each language with test vectors), the place of a quest objective (`where`, through the game's
-- AreaAdvice), the route from the city to every map (MapRoute.path), the monster groups of every map (Data/Spawns),
-- the gathering placements (MeadowsGen.nodes for the Meadows, the other regions from the text of their server
-- layouts) and the colours of the map sketch (src/client/UI/MapSketch.luau read as text). Pure: file texts come in
-- through ctx.readText.

local AreaAdvice = require("../../src/shared/Logic/AreaAdvice")
local Areas = require("../../src/shared/Data/Areas")
local Bosses = require("../../src/shared/Data/Bosses")
local Clean = require("./Clean")
local Locale = require("../../src/shared/Util/Locale")
local MapRoute = require("../../src/shared/Logic/MapRoute")
local MapSearch = require("../../src/shared/Logic/MapSearch")
local MeadowsGen = require("../../src/shared/Logic/MeadowsGen")
local Npcs = require("../../src/shared/Data/Npcs")
local Schema = require("./Schema")
local Spawns = require("../../src/shared/Data/Spawns")

local S = Schema
local arr, map, rec = S.arr, S.map, S.rec

local Places = {}

Places.REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }

-- Map search queries checked by the wiki's TypeScript copy of MapSearch (same results, same order).
Places.QUERIES = {
	{ lang = "pl", q = "laki" },
	{ lang = "pl", q = "kowal" },
	{ lang = "pl", q = "wilk" },
	{ lang = "pl", q = "grimrok" },
	{ lang = "pl", q = "jaskinia" },
	{ lang = "pl", q = "poczta" },
	{ lang = "pl", q = "gob" },
	{ lang = "pl", q = "szary wilk" },
	{ lang = "pl", q = "bór" },
	{ lang = "pl", q = "krypta" },
	{ lang = "en", q = "meadow" },
	{ lang = "en", q = "smith" },
}

local Entry = rec("MapSearchEntry", {
	kind = "string",
	id = "string",
	map = "ref:maps",
	x = "number",
	z = "number",
	texts = arr("string"),
})

S.file(
	"mapsearch",
	rec("MapSearchFile", {
		limit = "int",
		pl = arr(Entry),
		en = arr(Entry),
		vectors = arr(rec("MapSearchVector", { lang = "string", query = "string", results = arr("string") })),
	})
)

Places.Where = rec("PlaceRef", {
	map = "ref:maps",
	["area?"] = "ref:areas",
	["cave?"] = "ref:caves",
	["npc?"] = "ref:npcs",
})

Places.Group = rec("SpawnGroup", {
	id = "string",
	x = "number",
	z = "number",
	variant = "string",
	kinds = arr("ref:monsters"),
	count = "int",
	levelMin = "int",
	levelMax = "int",
	respawnMin = "number",
	respawnMax = "number",
	["area?"] = "string",
})

Places.Placement = rec("GatherPlacement", {
	kind = "string",
	n = "int",
	["rect?"] = arr("number"),
	["x?"] = "number",
	["z?"] = "number",
})

local function round1(v: number): number
	return math.floor(v * 10 + 0.5) / 10
end

-- Map search ------------------------------------------------------------------------------------------------------

local function translator(lang: string): MapSearch.Translate
	return function(key: string): string
		return Locale.T(key, nil, lang)
	end
end

function Places.mapsearch(_ctx: any): any
	local out: any = { limit = MapSearch.LIMIT, vectors = {} }
	local indexes = {}
	for _, lang in { "pl", "en" } do
		local index = MapSearch.build(translator(lang))
		indexes[lang] = index
		local list = {}
		for _, item in index.entries do
			local e = item.entry
			table.insert(list, {
				kind = e.kind,
				id = e.id,
				map = e.map,
				x = round1(e.x),
				z = round1(e.z),
				texts = table.clone(e.texts),
			})
		end
		out[lang] = list
	end
	for _, v in Places.QUERIES do
		local results = {}
		for _, r in MapSearch.search(indexes[v.lang], v.q) do
			table.insert(results, `{r.kind}:{r.id}`)
		end
		table.insert(out.vectors, { lang = v.lang, query = v.q, results = results })
	end
	return out
end

-- Quest objectives ------------------------------------------------------------------------------------------------

local function caveRef(kind: string): any?
	local cave = AreaAdvice.caveFor(kind)
	return if cave then { map = cave.id, cave = cave.id } else nil
end

-- Where an objective is done ({ map, area?, cave?, npc? }), or nil when it is not tied to a place (equip, learn...).
function Places.objectiveWhere(o: any, level: number, turnIn: string?): any?
	local t = o.type
	if t == "kill" or t == "collect" then
		if o.area then
			local area, mapId = Areas.areaById(o.area)
			if area and mapId then
				return { map = mapId, area = area.id }
			end
		end
		if o.monster then
			if o.variant == "elite" or o.variant == "elite2" then
				local ref = caveRef(o.monster)
				if ref then
					return ref
				end
			end
			local area, mapId = AreaAdvice.forKind(o.monster, level)
			if area and mapId then
				return { map = mapId, area = area.id }
			end
			return caveRef(o.monster)
		end
		if o.region and Places.REGION_MAPS[o.region] then
			return { map = Places.REGION_MAPS[o.region] }
		end
	elseif t == "reach" and o.map then
		return { map = o.map }
	elseif t == "boss" then
		local boss = Bosses.get(o.boss or "")
		if boss then
			return { map = `dungeon_{boss.region}` }
		end
	elseif t == "talk" or t == "deliver" then
		local npc = Npcs.get(o.npc or turnIn or "")
		if npc then
			return { map = npc.map, npc = npc.id }
		end
	elseif t == "use" then
		local id = o.anchor or (o.anchors and o.anchors[1])
		local _, mapId = Areas.anchorById(id or "")
		if mapId then
			return { map = mapId }
		end
	end
	return nil
end

-- Maps -------------------------------------------------------------------------------------------------------------

function Places.route(mapId: string): { string }?
	return MapRoute.path("city", mapId)
end

-- Monster groups of every map (regions and caves), as Data/Spawns builds them.
function Places.groups(): { [string]: { any } }
	local out = {}
	for _, mapId in Clean.keys(Spawns.byMap) do
		local list = {}
		for _, s in Spawns.byMap[mapId] do
			local kinds, seen = {}, {}
			for _, k in (s.choices or s.members or { s.monster }) :: { string } do
				if not seen[k] then
					seen[k] = true
					table.insert(kinds, k)
				end
			end
			table.insert(list, {
				id = s.id,
				x = round1(s.position.x),
				z = round1(s.position.z),
				variant = s.variant,
				kinds = kinds,
				count = s.count,
				levelMin = s.level.min,
				levelMax = s.level.max,
				respawnMin = s.respawn.min,
				respawnMax = s.respawn.max,
				area = s.areaId,
			})
		end
		out[mapId] = list
	end
	return out
end

-- Gathering --------------------------------------------------------------------------------------------------------

Places.LAYOUT_DIR = "src/server/World/Layouts"

-- Placements from the text of a region layout: Build.scatterNodes(ctx, "<kind>", n, { x1, z1, x2, z2 } ...) is a
-- rectangle where n nodes grow, Build.node(ctx, "<kind>", x, z) one point (a fishing spot).
function Places.parseLayout(text: string): { any }
	local out = {}
	local num = "(%-?[%d%.]+)"
	local scatter = 'Build%.scatterNodes%(ctx,%s*"([%w_]+)",%s*(%d+),%s*{%s*'
		.. num
		.. ",%s*"
		.. num
		.. ",%s*"
		.. num
		.. ",%s*"
		.. num
		.. "%s*}"
	for kind, n, x1, z1, x2, z2 in string.gmatch(text, scatter) do
		table.insert(out, {
			kind = kind,
			n = tonumber(n),
			rect = { tonumber(x1), tonumber(z1), tonumber(x2), tonumber(z2) },
		})
	end
	for kind, x, z in string.gmatch(text, 'Build%.node%(ctx,%s*"([%w_]+)",%s*' .. num .. ",%s*" .. num .. "%s*%)") do
		table.insert(out, { kind = kind, n = 1, x = tonumber(x), z = tonumber(z) })
	end
	return out
end

-- Placements per region map; `readText(path)` gives a layout's text (nil = unknown, the map gets no placements).
function Places.gather(readText: ((path: string) -> string?)?, warnings: { string }): { [string]: { any } }
	local out = {}
	for _, mapId in Places.REGION_MAPS do
		local list = {}
		if mapId == "meadows" then
			for _, node in MeadowsGen.nodes() do
				table.insert(list, { kind = node.kind, n = 1, x = round1(node.x), z = round1(node.z) })
			end
		else
			local text = readText and readText(`{Places.LAYOUT_DIR}/{mapId}.luau`)
			if text then
				list = Places.parseLayout(text)
			end
		end
		if #list == 0 then
			table.insert(warnings, `gather: no placements found for {mapId}`)
		end
		out[mapId] = list
	end
	return out
end

-- Map sketch colours ----------------------------------------------------------------------------------------------

-- `--vw-map-bg-<biome>` from BACKGROUND and `--vw-map-<kind>` from COLORS of UI/MapSketch.luau ("ground:Sand" ->
-- ground-sand), sorted. Empty without the text (map.css has fallbacks).
function Places.sketchColors(text: string?, warnings: { string }): { { name: string, hex: string } }
	local out = {}
	if not text then
		table.insert(warnings, "MapSketch.luau not read: map colours fall back to map.css")
		return out
	end
	local bg = string.match(text, "local BACKGROUND[^=]*=%s*(%b{})")
	local colors = string.match(text, "local COLORS[^=]*=%s*(%b{})")
	if not bg or not colors then
		table.insert(warnings, "MapSketch.luau: BACKGROUND / COLORS not found, map colours fall back to map.css")
		return out
	end
	for name, hex in string.gmatch(bg, '([%w_]+)%s*=%s*"(#%x%x%x%x%x%x)"') do
		table.insert(out, { name = `bg-{string.lower(name)}`, hex = string.upper(hex) })
	end
	for line in string.gmatch(colors, "[^\n]+") do
		local name, hex = string.match(line, '^%s*%[?"?([%w_:]+)"?%]?%s*=%s*{%s*color%s*=%s*"(#%x%x%x%x%x%x)"')
		if name and hex then
			local token = string.gsub(string.gsub(name, "[:_]", "-"), "(%l)(%u)", "%1-%2")
			table.insert(out, { name = string.lower(token), hex = string.upper(hex) })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

return Places
