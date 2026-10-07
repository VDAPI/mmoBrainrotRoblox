--!strict
-- search.json (S34): a light index for the Ctrl+K palette built from the other files (type, id, parent map of an
-- area, class of a skill, name, both names normalized with MapSearch.normalize, level, rarity or zone) and test
-- vectors of normalize (input -> output) so the wiki's TypeScript version can be checked against the game's.

local MapSearch = require("../../src/shared/Logic/MapSearch")
local Schema = require("./Schema")

local S = Schema
local arr, rec = S.arr, S.rec

local Search = {}

Search.VECTORS = {
	"Szary Wilk",
	"Żabie Oczko",
	"  Gobliński   Obóz ",
	"Niedźwiedzi Jar",
	"ŁĄKI",
	"Zażółć gęślą jaźń",
	"Miecz jednoręczny (5)",
	"Grimrok, Pan Kamieni!",
	"Kupiecki-Trakt",
	"Wolf Hills",
	"Bear Ravine",
	"Ruiny Smoczej Świątyni",
	"Śnieżny Lampart",
	"Ognisty Chochlik",
	"Wyrm Szronu",
	"Café Noël",
	"Über Straße",
	"tab\tand\nnew line",
	"Ostrze: +7",
	"",
}

local Entry = rec("SearchEntry", {
	type = "string",
	id = "string",
	["map?"] = "ref:maps",
	["class?"] = "string",
	name = "name",
	key = "string",
	["level?"] = "int",
	["rarity?"] = "string",
	["zone?"] = "string",
})

S.file(
	"search",
	rec("SearchFile", {
		entries = arr(Entry),
		vectors = arr(rec("NormalizeVector", { input = "string", output = "string" })),
	})
)

local function key(name: { pl: string, en: string }): string
	local pl, en = MapSearch.normalize(name.pl), MapSearch.normalize(name.en)
	return if pl == en then pl else `{pl} {en}`
end

function Search.build(ctx: any): any
	local d = ctx.data
	local entries = {}
	local function add(entry: any)
		entry.key = key(entry.name)
		table.insert(entries, entry)
	end
	for _, item in (d.items and d.items.items or {}) do
		local top = item.rarities[#item.rarities]
		add({ type = "item", id = item.id, name = item.name, level = item.requiredLevel, rarity = top })
	end
	for _, m in (d.monsters and d.monsters.monsters or {}) do
		local level = nil
		for _, v in { "normal", "elite", "elite2" } do
			local variant = m.variants[v]
			if variant and not level then
				level = variant.levelMin
			end
		end
		add({ type = "monster", id = m.id, name = m.name, level = level })
	end
	for _, b in (d.bosses and d.bosses.bosses or {}) do
		add({ type = "boss", id = b.id, name = b.name, level = b.level })
	end
	for _, m in (d.maps and d.maps.maps or {}) do
		add({ type = "map", id = m.id, name = m.name, level = m.minLevel, zone = m.zone })
	end
	for _, a in (d.areas and d.areas.areas or {}) do
		add({ type = "area", id = a.id, map = a.map, name = a.name, level = a.levelMin })
	end
	for _, c in (d.caves and d.caves.caves or {}) do
		add({ type = "cave", id = c.id, map = c.region, name = c.name, level = c.levelMin, zone = "red" })
	end
	for _, n in (d.npcs and d.npcs.npcs or {}) do
		if not n.decoration then
			add({ type = "npc", id = n.id, map = n.map, name = n.name })
		end
	end
	for _, q in (d.quests and d.quests.main or {}) do
		add({ type = "quest", id = q.id, name = q.title, level = q.level })
	end
	for _, q in (d.quests and d.quests.side or {}) do
		add({ type = "quest", id = q.id, name = q.title, level = q.level })
	end
	for _, s in (d.skills and d.skills.skills or {}) do
		add({ type = "skill", id = s.id, class = s.class, name = s.name, level = s.unlock })
	end
	for _, c in (d.classes and d.classes.classes or {}) do
		add({ type = "class", id = c.id, name = c.name })
	end
	local vectors = {}
	for _, input in Search.VECTORS do
		table.insert(vectors, { input = input, output = MapSearch.normalize(input) })
	end
	return { entries = entries, vectors = vectors }
end

return Search
