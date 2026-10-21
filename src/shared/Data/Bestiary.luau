--!strict
-- Bestiary (S151c, docs/DESIGN.md §20c): the tab of the achievements window. Every monster kind (Data/Monsters) and
-- every boss (Data/Bosses.all, the world boss too) is one entry with three kill tiers; a tier reveals more of the entry
-- (REVEAL), gives bestiary points (counted with the achievement points) and the last tier ("mastered") adds a little
-- damage against the entry's family (FAMILY_PCT each, at most FAMILY_CAP per family; a hook vs_<family> like the item
-- lines, never in the pace model: the cap stays below the smallest Common vs_<family> line, tests/balance.spec).
-- A region is complete when every entry of it is mastered: the achievement bestiary_<region> with its title
-- (Data/Achievements, counter bestiaryRegions). Rules in Logic/Bestiary, the server in AchievementService.
-- Not a balance module (tools/balance_reasons NOT_BALANCE "postęp"): milestones, the bonus is checked by its own test.

local Bosses = require("./Bosses")
local LootTables = require("./LootTables")
local Monsters = require("./Monsters")
local WorldBoss = require("./WorldBoss")

export type Entry = {
	id: string, -- the monster kind or boss id (the save key)
	boss: boolean,
	region: string, -- REGIONS id
	family: string,
	nameKey: string,
	levels: { min: number, max: number },
	cave: boolean, -- lives in the region's cave (monsters only)
	tiers: { number }, -- kills per tier (ascending)
	points: { number }, -- bestiary points per tier
	drops: { string }, -- item ids it can drop (materials; bosses also their named items), in data order
}

-- The world order of the regions (Data/Monsters region 1-4 = this index).
local REGIONS: { string } = { "meadows", "duskwood", "ashen", "frostpeak" }

local TIERS = table.freeze({
	monster = table.freeze({ 10, 100, 1000 }),
	boss = table.freeze({ 1, 10, 50 }),
})

local POINTS = table.freeze({
	monster = table.freeze({ 2, 5, 10 }),
	boss = table.freeze({ 5, 10, 25 }),
})

-- What each tier shows in the window (0 kills: "???"; the first kill shows the name, the family and the kill count).
local REVEAL = table.freeze({
	portrait = 1, -- the model preview, the levels, where it lives, how it attacks
	drops = 2, -- the drops seen (the rest "???"), the defence trait
	weak = 3, -- the weaknesses and the element of its attacks
})

-- % damage against the family per mastered entry and the cap per family (a Common vs_<family> line rolls 5-12).
local FAMILY_PCT = 1
local FAMILY_CAP = 3

local list: { Entry } = {}
local byId: { [string]: Entry } = {}
local byRegion: { [string]: { Entry } } = {}

local function addUnique(out: { string }, id: string)
	if not table.find(out, id) then
		table.insert(out, id)
	end
end

local function monsterDrops(def: Monsters.MonsterDef): { string }
	local out: { string } = {}
	local loot = LootTables.get(def.lootTable)
	if loot then
		for _, m in loot.materials do
			addUnique(out, m.id)
		end
		if def.elites then
			for _, variant in { "elite", "elite2" } do
				local extra: { LootTables.MaterialDrop } = loot.variantMaterials[variant] or {}
				for _, m in extra do
					addUnique(out, m.id)
				end
			end
		end
	end
	return out
end

local function bossDrops(def: Bosses.BossDef): { string }
	local out: { string } = {}
	if def.world then
		local reward = WorldBoss.reward
		local byClass: { [string]: { string } } = reward.named.byClass :: any
		local classes: { string } = {}
		for class in byClass do
			table.insert(classes, class)
		end
		table.sort(classes)
		for _, class in classes do
			for _, id in byClass[class] do
				addUnique(out, id)
			end
		end
		for _, m in reward.materials do
			addUnique(out, m.id)
		end
		return out
	end
	local loot = LootTables.bosses[def.id]
	if loot then
		for _, id in loot.named do
			addUnique(out, id)
		end
		for _, m in loot.materials do
			addUnique(out, m.id)
		end
	end
	return out
end

local function add(entry: Entry)
	assert(byId[entry.id] == nil, `Bestiary: duplicate id {entry.id}`)
	byId[entry.id] = entry
	table.insert(list, entry)
	local forRegion = byRegion[entry.region]
	if not forRegion then
		forRegion = {}
		byRegion[entry.region] = forRegion
	end
	table.insert(forRegion, entry)
end

for index, region in REGIONS do
	-- the monsters of the region by their lowest level (the order a player meets them), then its bosses
	local kinds: { Monsters.MonsterDef } = {}
	for _, def in Monsters.list do
		if def.region == index then
			table.insert(kinds, def)
		end
	end
	table.sort(kinds, function(a: Monsters.MonsterDef, b: Monsters.MonsterDef): boolean
		if a.levels.min ~= b.levels.min then
			return a.levels.min < b.levels.min
		end
		return a.id < b.id
	end)
	for _, def in kinds do
		add({
			id = def.id,
			boss = false,
			region = region,
			family = def.family,
			nameKey = def.nameKeys.normal,
			levels = { min = def.levels.min, max = def.levels.max },
			cave = def.cave,
			tiers = TIERS.monster,
			points = POINTS.monster,
			drops = monsterDrops(def),
		})
	end
	for _, def in Bosses.all do
		if def.region == region then
			add({
				id = def.id,
				boss = true,
				region = region,
				family = def.family,
				nameKey = def.nameKey,
				levels = { min = def.level, max = def.level },
				cave = false,
				tiers = TIERS.boss,
				points = POINTS.boss,
				drops = bossDrops(def),
			})
		end
	end
end

return table.freeze({
	REGIONS = table.freeze(REGIONS),
	TIERS = TIERS,
	POINTS = POINTS,
	REVEAL = REVEAL,
	FAMILY_PCT = FAMILY_PCT,
	FAMILY_CAP = FAMILY_CAP,
	list = list,
	byId = byId,
	get = function(id: string): Entry?
		return byId[id]
	end,
	forRegion = function(region: string): { Entry }
		return byRegion[region] or {}
	end,
})
