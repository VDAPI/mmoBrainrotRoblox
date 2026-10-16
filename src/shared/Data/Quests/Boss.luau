--!strict
-- Boss quests (S98, docs/DESIGN-15.md §3.1): one "first defeat" quest per boss and its dungeon (the boss cave of the
-- region), given and handed in by the region's scout. Available from boss level - 5 (BossScaling.questLevel; S134c:
-- the dungeon itself opens 10 levels below the boss, the quest stays on the old entry level and its budget band). Progress only from a won dungeon run (QuestEvents "boss"), so the daily limit
-- (Config.Boss.dailyRuns) always applies. EXP: Logic/QuestBudget.bossQuestExp (the boss share of the band's EXP).
-- Texts: quest.<id>.title, .p1..p2, .progress, .done.

local Bosses = require("../Bosses")
local BossScaling = require("../../Logic/BossScaling")
local Caves = require("../Areas/Caves")
local QuestBudget = require("../../Logic/QuestBudget")
local Side = require("./Side")
local Types = require("./Types")

type SideQuest = Types.SideQuest

-- Region order of the quests (journal order).
local REGIONS = { "meadows", "duskwood", "ashen", "frostpeak" }
-- Gold: the base main-quest gold of the level (Main.luau: 60 + 45 x level) x GOLD_MUL.
local GOLD_MUL = 1.5
-- Dungeon stones of the boss's region on hand-in.
local STONES = 2

local function bossCave(region: string): string
	for _, cave in Caves.list do
		if cave.region == region and cave.boss == true then
			return cave.id
		end
	end
	error(`Quests/Boss: no cave with boss = true in region {region} (Data/Areas/Caves)`)
end

-- Boss quests per budget band (QuestBudget.bandOf of the entry level): the band's boss share is split between them.
local perBand: { [number]: number } = {}
for _, region in REGIONS do
	local def = Bosses.forRegion(region)
	if def then
		local lo = QuestBudget.bandOf(BossScaling.questLevel(def.level))
		perBand[lo] = (perBand[lo] or 0) + 1
	end
end

local list: { SideQuest } = {}
local byId: { [string]: SideQuest } = {}
local byBoss: { [string]: SideQuest } = {}

for _, region in REGIONS do
	local def = Bosses.forRegion(region)
	assert(def, `Quests/Boss: no boss in region {region}`)
	local level = BossScaling.questLevel(def.level)
	local quest: SideQuest = {
		id = "boss_" .. def.id,
		category = "boss",
		level = level,
		minLevel = level,
		giver = "scout_" .. region,
		turnIn = "scout_" .. region,
		arc = "bosses",
		pages = 2,
		objectives = { { type = "boss", n = 1, boss = def.id } },
		where = { map = bossCave(region) },
		reward = {
			exp = QuestBudget.bossQuestExp(level, perBand[(QuestBudget.bandOf(level))] or 1),
			gold = math.floor((60 + 45 * level) * GOLD_MUL),
			items = { { id = "stone_dungeon_" .. region, n = STONES } },
		},
	}
	assert(not byId[quest.id], `Quests/Boss: duplicate id {quest.id}`)
	assert(not Side.byId[quest.id], `Quests/Boss: {quest.id} is a side quest id too`)
	table.insert(list, quest)
	byId[quest.id] = quest
	byBoss[def.id] = quest
end

return table.freeze({
	list = list,
	byId = byId,
	get = function(id: string): SideQuest?
		return byId[id]
	end,
	ofBoss = function(bossId: string): SideQuest?
		return byBoss[bossId]
	end,
})
