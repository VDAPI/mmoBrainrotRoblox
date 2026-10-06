--!strict
-- Search of the world map (S25): NPCs (name, role and the names of their services, e.g. "smith", "shop",
-- "mail"), maps, monster areas, monster kinds (every variant name), bosses and, from the client, gathering nodes.
-- Case and Polish letters do not matter ("laki" finds "Łąki"); a word that starts with the query ranks above a
-- match inside a word. The index is built once per language with an injected translate function, so the
-- tests run without Locale. Pure (Lune).

local AreaAdvice = require("./AreaAdvice")
local Areas = require("../Data/Areas")
local Bosses = require("../Data/Bosses")
local Maps = require("../Data/Maps")
local Monsters = require("../Data/Monsters")
local Npcs = require("../Data/Npcs")
local Portals = require("../Data/Portals")

local MapSearch = {}

MapSearch.LIMIT = 12

export type Kind = "npc" | "map" | "area" | "monster" | "boss" | "node" | "cave"

export type Result = {
	kind: Kind,
	id: string,
	map: string,
	x: number,
	z: number,
	labelKey: string,
}

-- One searchable thing: the result plus its texts (`texts[1]` is the label).
export type Entry = {
	kind: Kind,
	id: string,
	map: string,
	x: number,
	z: number,
	labelKey: string,
	texts: { string },
	rank: number?,
}

type Prepared = { entry: Entry, texts: { string }, words: { string } }

export type Index = { entries: { Prepared } }

export type Translate = (key: string) -> string

-- Kind order when two results score the same.
local KIND_RANK: { [string]: number } = { npc = 1, map = 2, cave = 3, area = 4, boss = 5, monster = 6, node = 7 }

-- Lowercase letters without Polish (and a few other) diacritics.
local FOLD: { [number]: string } = {
	[0x104] = "a",
	[0x105] = "a",
	[0x106] = "c",
	[0x107] = "c",
	[0x118] = "e",
	[0x119] = "e",
	[0x141] = "l",
	[0x142] = "l",
	[0x143] = "n",
	[0x144] = "n",
	[0xD3] = "o",
	[0xF3] = "o",
	[0x15A] = "s",
	[0x15B] = "s",
	[0x179] = "z",
	[0x17A] = "z",
	[0x17B] = "z",
	[0x17C] = "z",
	[0xC4] = "a",
	[0xE4] = "a",
	[0xD6] = "o",
	[0xF6] = "o",
	[0xDC] = "u",
	[0xFC] = "u",
	[0xC9] = "e",
	[0xE9] = "e",
}

-- Lowercase, no diacritics, punctuation as single spaces, trimmed.
function MapSearch.normalize(text: string): string
	local out = table.create(#text)
	local ok = pcall(function()
		for _, code in utf8.codes(text) do
			local folded = FOLD[code]
			if folded then
				table.insert(out, folded)
			elseif code < 128 then
				table.insert(out, string.lower(string.char(code)))
			else
				table.insert(out, utf8.char(code))
			end
		end
	end)
	local joined = if ok then table.concat(out) else string.lower(text)
	joined = string.gsub(joined, "[%p%c]", " ")
	joined = string.gsub(joined, "%s+", " ")
	return (string.match(joined, "^%s*(.-)%s*$") or "") :: string
end

local function prepare(entry: Entry): Prepared
	local texts, words = {}, {}
	for _, text in entry.texts do
		local normalized = MapSearch.normalize(text)
		if normalized ~= "" then
			table.insert(texts, normalized)
			for word in string.gmatch(normalized, "%S+") do
				table.insert(words, word)
			end
		end
	end
	return { entry = entry, texts = texts, words = words }
end

local function npcEntries(translate: Translate, out: { Entry })
	for _, npc in Npcs.list do
		if not npc.decoration then
			local texts = { translate(npc.nameKey), translate(`npc.{npc.id}.role`) }
			for _, service in npc.services do
				table.insert(texts, translate(`npc.service.{service}`))
				table.insert(texts, translate(`worldmap.search.{service}`))
			end
			table.insert(out, {
				kind = "npc",
				id = npc.id,
				map = npc.map,
				x = npc.position.x,
				z = npc.position.z,
				labelKey = npc.nameKey,
				texts = texts,
			})
		end
	end
end

local function mapEntries(translate: Translate, out: { Entry })
	local ids = {}
	for id in Maps.byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		local map = Maps.byId[id]
		if map.biome ~= "dungeon" then
			table.insert(out, {
				kind = if Areas.caves.get(id) then "cave" else "map",
				id = id,
				map = id,
				x = map.spawn.x,
				z = map.spawn.z,
				labelKey = map.nameKey,
				texts = { translate(map.nameKey) },
			})
		end
	end
end

local function areaEntries(translate: Translate, out: { Entry })
	for _, mapId in { "meadows", "duskwood", "ashen", "frostpeak" } do
		for _, area in AreaAdvice.sorted(mapId) do
			local x, z = AreaAdvice.centre(area)
			table.insert(out, {
				kind = "area",
				id = area.id,
				map = mapId,
				x = x,
				z = z,
				labelKey = area.nameKey,
				texts = { translate(area.nameKey) },
			})
		end
	end
end

-- Where a monster kind lives: its lowest area, else the lowest cave with it (in front of the cave's spawn).
local function home(kind: string): (string?, number, number)
	local area, mapId = AreaAdvice.forKind(kind, 1)
	if area and mapId then
		local x, z = AreaAdvice.centre(area)
		return mapId, x, z
	end
	local cave = AreaAdvice.caveFor(kind)
	local map = cave and Maps.get(cave.id)
	if cave and map then
		return cave.id, map.spawn.x, map.spawn.z
	end
	return nil, 0, 0
end

local function monsterEntries(translate: Translate, out: { Entry })
	for _, def in Monsters.list do
		local mapId, x, z = home(def.id)
		if mapId then
			local texts = { translate(def.nameKeys.normal) }
			if def.elites then
				table.insert(texts, translate(def.nameKeys.elite))
				table.insert(texts, translate(def.nameKeys.elite2))
			end
			table.insert(out, {
				kind = "monster",
				id = def.id,
				map = mapId,
				x = x,
				z = z,
				labelKey = def.nameKeys.normal,
				texts = texts,
			})
		end
	end
end

local function bossEntries(translate: Translate, out: { Entry })
	for _, boss in Bosses.list do
		local gate = Portals.get(`dungeon_{boss.region}`)
		if gate then
			table.insert(out, {
				kind = "boss",
				id = boss.id,
				map = gate.map,
				x = gate.x,
				z = gate.z,
				labelKey = boss.nameKey,
				texts = { translate(boss.nameKey), translate(`map.dungeon_{boss.region}.name`) },
			})
		end
	end
end

-- Builds the index for one language. `extra` adds entries known only at run time (gathering nodes).
function MapSearch.build(translate: Translate, extra: { Entry }?): Index
	local entries: { Entry } = {}
	npcEntries(translate, entries)
	mapEntries(translate, entries)
	areaEntries(translate, entries)
	monsterEntries(translate, entries)
	bossEntries(translate, entries)
	if extra then
		for _, entry in extra do
			table.insert(entries, entry)
		end
	end
	local prepared = {}
	for _, entry in entries do
		table.insert(prepared, prepare(entry))
	end
	return { entries = prepared }
end

-- 2 when a word starts with the token, 1 when a text contains it, 0 otherwise.
local function tokenScore(item: Prepared, token: string): number
	for _, word in item.words do
		if string.sub(word, 1, #token) == token then
			return 2
		end
	end
	for _, text in item.texts do
		if string.find(text, token, 1, true) then
			return 1
		end
	end
	return 0
end

-- Best results for `query` (empty query = none), at most `limit` (default 12).
function MapSearch.search(index: Index, query: string, limit: number?): { Result }
	local normalized = MapSearch.normalize(query)
	if normalized == "" then
		return {}
	end
	local tokens = {}
	for token in string.gmatch(normalized, "%S+") do
		table.insert(tokens, token)
	end
	local scored: { { item: Prepared, score: number } } = {}
	for _, item in index.entries do
		local score = 0
		for _, token in tokens do
			local s = tokenScore(item, token)
			if s == 0 then
				score = -1
				break
			end
			score += s
		end
		if score > 0 then
			-- The label itself starting with the whole query ranks first.
			local label = item.texts[1]
			if label and string.sub(label, 1, #normalized) == normalized then
				score += 1
			end
			table.insert(scored, { item = item, score = score })
		end
	end
	table.sort(scored, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		local ra = a.item.entry.rank or KIND_RANK[a.item.entry.kind] or 9
		local rb = b.item.entry.rank or KIND_RANK[b.item.entry.kind] or 9
		if ra ~= rb then
			return ra < rb
		end
		local la, lb = a.item.texts[1] or "", b.item.texts[1] or ""
		if la ~= lb then
			return la < lb
		end
		return a.item.entry.id < b.item.entry.id
	end)
	local out: { Result } = {}
	for i = 1, math.min(#scored, limit or MapSearch.LIMIT) do
		local entry = scored[i].item.entry
		table.insert(out, {
			kind = entry.kind,
			id = entry.id,
			map = entry.map,
			x = entry.x,
			z = entry.z,
			labelKey = entry.labelKey,
		})
	end
	return out
end

return MapSearch
