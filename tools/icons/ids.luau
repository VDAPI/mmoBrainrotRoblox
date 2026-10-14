--!strict
-- Item ids of the game for the icon importers (S118): the single source of truth for which picture names are valid.
--   lune run tools/icons/ids.luau [out.json]
-- Prints (or writes) JSON:
--   items        { [id] = { category, type, tier?, group } } from Items.byId; group is the report group
--   questItems   { [item] = true }: `item` of every quest objective (any quest list) and every quest.item.* text key
--   unusedQuestItems  { item }: text keys without an objective (allowed, listed in the report)
--   blessingLines     { line }
--   ui           S119: game ids of every interface picture category (Logic/UiArtKeys.ids: skills, effects, elements,
--                profiles, guildSkills, classes, titles, slots, menus, maps, marks, services, cosmetics, shop, bosses,
--                fixed) for tools/icons/import_ui.py
-- The Python tools never parse Luau themselves (tools/icons/import_graphics.py --ids).

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Blessings = require("../../src/shared/Data/Blessings")
local Items = require("../../src/shared/Data/Items")
local Pl = require("../../src/shared/Data/Localization/pl")
local Quests = require("../../src/shared/Data/Quests")
local UiArtKeys = require("../../src/shared/Logic/UiArtKeys")

local function groupOf(def: Items.ItemDef): string
	if string.sub(def.id, 1, 7) == "unique_" then
		return "unique"
	end
	local cat = def.category
	if cat == "equipment" then
		if def.slot == "weapon" then
			return "weapon"
		elseif def.slot == "offhand" then
			return "offhand"
		elseif def.slot == "necklace" or def.slot == "ring" or def.slot == "talisman" then
			return "jewelry"
		end
		return "armor"
	elseif cat == "material" then
		return "material"
	elseif cat == "consumable" then
		if string.sub(def.type, 1, 7) == "potion_" then
			return "potion"
		elseif def.type == "elixir" then
			return "elixir"
		elseif def.type == "blessing" then
			return "blessing"
		end
		return "other"
	elseif cat == "scroll" or cat == "stone" or cat == "backpack" or cat == "tool" then
		return cat
	end
	return "other"
end

local items: { [string]: any } = {}
for id, def in Items.byId do
	items[id] = { category = def.category, type = def.type, tier = def.tier, group = groupOf(def) }
end

-- Every table reachable from the quest data that looks like an objective with an `item`.
local questItems: { [string]: boolean } = {}
local fromObjectives: { [string]: boolean } = {}
local seen: { [any]: boolean } = {}
local function walk(t: any)
	if type(t) ~= "table" or seen[t] then
		return
	end
	seen[t] = true
	if type(t.type) == "string" and type(t.item) == "string" then
		questItems[t.item] = true
		fromObjectives[t.item] = true
	end
	for _, v in t do
		walk(v)
	end
end
walk(Quests)

local unused: { string } = {}
for key in Pl :: any do
	local item = string.match(key, "^quest%.item%.([%w_]+)$")
	if item then
		questItems[item] = true
		if not fromObjectives[item] then
			table.insert(unused, item)
		end
	end
end
table.sort(unused)

local lines: { string } = {}
for _, line in Blessings.lines do
	table.insert(lines, line)
end

local out = serde.encode("json", {
	items = items,
	questItems = questItems,
	unusedQuestItems = unused,
	blessingLines = lines,
	ui = UiArtKeys.ids(),
}, false)

local path = process.args[1]
if path then
	fs.writeFile(path, out)
	local n = 0
	for _ in items do
		n += 1
	end
	print(`ids: {n} items -> {path}`)
else
	print(out)
end
