--!strict
-- quests.json (S34): the main story (order, level, giver / turn-in NPCs, texts, objectives with labels built from
-- the game's quest.obj.<type> texts like UI/QuestText.objective, rewards), the side quests (S27: arcs, pages,
-- requirements) and the daily contracts (objective and reward on levels 1, 5, 10, ..., 100).

local Bosses = require("../../src/shared/Data/Bosses")
local Clean = require("./Clean")
local Config = require("../../src/shared/Config")
local GatherNodes = require("../../src/shared/Data/GatherNodes")
local Maps = require("../../src/shared/Data/Maps")
local Monsters = require("../../src/shared/Data/Monsters")
local Names = require("./Names")
local Npcs = require("../../src/shared/Data/Npcs")
local QuestData = require("../../src/shared/Data/Quests")
local Areas = require("../../src/shared/Data/Areas")
local Schema = require("./Schema")

local S = Schema
local arr, rec = S.arr, S.rec

local Quests = {}

Quests.REGION_MAPS = { "meadows", "duskwood", "ashen", "frostpeak" }
Quests.DAILY_LEVELS = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }

local Objective = rec("QuestObjective", {
	type = "string",
	n = "int",
	label = "name",
	["npc?"] = "ref:npcs",
	["monster?"] = "ref:monsters",
	["variant?"] = "string",
	["region?"] = "int",
	["item?"] = "string",
	["chance?"] = "number",
	["node?"] = "string",
	["category?"] = "string",
	["map?"] = "ref:maps",
	["x?"] = "number",
	["z?"] = "number",
	["radius?"] = "number",
	["boss?"] = "ref:bosses",
	["up?"] = "int",
	["rarity?"] = "int",
	["level?"] = "int",
	["area?"] = "ref:areas",
	["anchor?"] = "string",
	["anchors?"] = arr("string"),
	["hold?"] = "number",
	["place?"] = "name",
})

local Reward = rec("QuestReward", {
	exp = "int",
	gold = "int",
	items = arr(rec("QuestRewardItem", { id = "ref:items", n = "int" })),
	["choice?"] = "string",
})

S.file(
	"quests",
	rec("QuestsFile", {
		main = arr(rec("MainQuest", {
			id = "string",
			order = "int",
			level = "int",
			giver = "ref:npcs",
			turnIn = "ref:npcs",
			title = "name",
			["text?"] = "name",
			["done?"] = "name",
			objectives = arr(Objective),
			reward = Reward,
		})),
		side = arr(rec("SideQuest", {
			id = "string",
			level = "int",
			giver = "ref:npcs",
			turnIn = "ref:npcs",
			arc = "string",
			arcName = "name",
			title = "name",
			pages = arr("name"),
			["progress?"] = "name",
			["done?"] = "name",
			requires = arr("string"),
			objectives = arr(Objective),
			reward = Reward,
			["where?"] = rec(
				"QuestWhere",
				{ map = "ref:maps", ["area?"] = "ref:areas", ["x?"] = "number", ["z?"] = "number" }
			),
		})),
		daily = rec("DailyQuests", {
			perDay = "int",
			templates = arr(rec("DailyTemplate", {
				id = "string",
				minLevel = "int",
				title = "name",
				byLevel = arr(rec("DailyLevel", { level = "int", objective = Objective, reward = Reward })),
			})),
		}),
		levelSlack = "int",
		sideLevelSlack = "int",
		sideMaxActive = "int",
	})
)

local function textOf(key: string?, lang: string): string
	return if key then Names.T(key, nil, lang) else "?"
end

-- Label of an objective (as UI/QuestText.objective, with the amount instead of the progress).
function Quests.label(o: any, turnIn: string?, lang: string): string
	local t = o.type
	local count = tostring(o.n)
	local area = o.area and Areas.areaById(o.area)
	local where = if area then Names.T("quest.obj.inArea", { area = textOf(area.nameKey, lang) }, lang) else ""
	local function npcName(id: string?): string
		local npc = Npcs.get(id or "")
		return if npc then textOf(npc.nameKey, lang) else "?"
	end
	if t == "talk" then
		return Names.T("quest.obj.talk", { npc = npcName(o.npc) }, lang)
	elseif t == "deliver" then
		return Names.T(
			"quest.obj.deliver",
			{ item = textOf(`quest.item.{o.item}`, lang), npc = npcName(o.npc or turnIn) },
			lang
		)
	elseif t == "use" then
		local label = textOf(o.action or "quest.use.default", lang)
		return if o.n > 1 then `{label} {count}` else label
	elseif t == "kill" then
		if o.monster then
			local def = Monsters.get(o.monster)
			local key = if def then (if o.variant == "elite" then def.nameKeys.elite else def.nameKeys.normal) else nil
			return Names.T("quest.obj.kill", { monster = textOf(key, lang), count = count }, lang) .. where
		end
		local map = Maps.get(Quests.REGION_MAPS[o.region or 1] or "")
		local key = if o.variant == "elite" then "quest.obj.killElite" else "quest.obj.killRegion"
		return Names.T(key, { region = textOf(map and map.nameKey, lang), count = count }, lang)
	elseif t == "collect" then
		return Names.T("quest.obj.collect", { item = textOf(`quest.item.{o.item}`, lang), count = count }, lang)
			.. where
	elseif t == "gather" then
		if o.node then
			local kind = GatherNodes.get(o.node)
			return Names.T("quest.obj.gather", { node = textOf(kind and kind.nameKey, lang), count = count }, lang)
		end
		local key = if o.category == "ore" then "quest.obj.gatherOre" else "quest.obj.gatherHerb"
		return Names.T(key, { count = count }, lang)
	elseif t == "reach" then
		if o.place then
			return Names.T("quest.obj.reach", { map = textOf(o.place, lang) }, lang)
		end
		local map = Maps.get(o.map or "")
		return Names.T("quest.obj.reach", { map = textOf(map and map.nameKey, lang) }, lang)
	elseif t == "boss" then
		local boss = Bosses.get(o.boss or "")
		if boss then
			return Names.T("quest.obj.boss", { boss = textOf(boss.nameKey, lang) }, lang)
		end
		return Names.T("quest.obj.bossAny", nil, lang)
	elseif t == "upgrade" then
		return Names.T("quest.obj.upgrade", { up = o.up or 1 }, lang)
	elseif t == "level" then
		return Names.T("quest.obj.level", { level = o.level or 1 }, lang)
	end
	return Names.T(`quest.obj.{t}`, { count = count }, lang)
end

local function objectives(list: { any }, turnIn: string?): { any }
	local out = {}
	for _, o in list do
		local entry = Clean.pick(o, {
			"type",
			"n",
			"npc",
			"monster",
			"variant",
			"region",
			"item",
			"chance",
			"node",
			"category",
			"map",
			"x",
			"z",
			"radius",
			"boss",
			"up",
			"rarity",
			"level",
			"area",
			"anchor",
			"anchors",
			"hold",
		})
		entry.label = Names.combine(function(lang: string): string
			return Quests.label(o, turnIn, lang)
		end)
		if o.place then
			entry.place = Names.of(o.place)
		end
		table.insert(out, entry)
	end
	return out
end

local function reward(r: any, hidden: { [string]: boolean }): any
	return {
		exp = r.exp,
		gold = r.gold,
		items = Clean.dropRefs(Clean.clean(r.items or {}), hidden, "id"),
		choice = r.choice,
	}
end

function Quests.build(ctx: any): any
	ctx.questItems = {}
	local function noteItems(questId: string, r: any)
		for _, item in r.items or {} do
			ctx.questItems[item.id] = ctx.questItems[item.id] or {}
			table.insert(ctx.questItems[item.id], { quest = questId, n = item.n })
		end
	end
	local main = {}
	for _, q in QuestData.Main.list do
		if not ctx.hidden[q.id] then
			noteItems(q.id, q.reward)
			table.insert(main, {
				id = q.id,
				order = QuestData.Main.indexOf[q.id],
				level = q.level,
				giver = q.giver,
				turnIn = q.turnIn,
				title = Names.of(`quest.{q.id}.title`),
				text = Names.opt(`quest.{q.id}.text`),
				done = Names.opt(`quest.{q.id}.done`),
				objectives = objectives(q.objectives, q.turnIn),
				reward = reward(q.reward, ctx.hidden),
			})
		end
	end
	local side = {}
	for _, q in QuestData.Side.list do
		if not ctx.hidden[q.id] then
			noteItems(q.id, q.reward)
			local pages = {}
			for i = 1, q.pages do
				table.insert(pages, Names.of(`quest.{q.id}.p{i}`))
			end
			table.insert(side, {
				id = q.id,
				level = q.level,
				giver = q.giver,
				turnIn = q.turnIn,
				arc = q.arc,
				arcName = Names.of(`quest.arc.{q.arc}`),
				title = Names.of(`quest.{q.id}.title`),
				pages = pages,
				progress = Names.opt(`quest.{q.id}.progress`),
				done = Names.opt(`quest.{q.id}.done`),
				requires = Clean.dropRefs(Clean.clean(q.requires or {}), ctx.hidden),
				objectives = objectives(q.objectives, q.turnIn),
				reward = reward(q.reward, ctx.hidden),
				where = if q.where then Clean.clean(q.where) else nil,
			})
		end
	end
	local templates = {}
	for _, t in QuestData.Daily.templates do
		local byLevel = {}
		for _, level in Quests.DAILY_LEVELS do
			if level >= t.minLevel then
				local r = QuestData.Daily.reward(level)
				table.insert(byLevel, {
					level = level,
					objective = objectives({ t.objective(level) }, nil)[1],
					reward = reward(r, ctx.hidden),
				})
			end
		end
		table.insert(templates, {
			id = t.id,
			minLevel = t.minLevel,
			title = Names.of(`daily.{t.id}.title`),
			byLevel = byLevel,
		})
	end
	return {
		main = main,
		side = side,
		daily = { perDay = QuestData.Daily.PER_DAY, templates = templates },
		levelSlack = QuestData.Main.LEVEL_SLACK,
		sideLevelSlack = Config.SideQuest.levelSlack,
		sideMaxActive = Config.SideQuest.maxActive,
	}
end

return Quests
