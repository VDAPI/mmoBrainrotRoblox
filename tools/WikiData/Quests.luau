--!strict
-- quests.json (S34): the main story (order, level, giver / turn-in NPCs, texts, objectives with labels built from
-- the game's quest.obj.<type> texts like UI/QuestText.objective, rewards), the side quests (S27: arcs, pages,
-- requirements) and the daily contracts (objective and reward on levels 1, 5, 10, ..., 100).
-- S109 (DESIGN-15 §0.5, G2): only keys added. `chapters` (Main.CHAPTERS, the one source of the story's chapters),
-- `main[].chapter` (Main.chapterOf; a quest with offer pages exports them as `text`, the pages joined by a blank
-- line), `bossQuests` (Data/Quests/Boss), `weekly` (the templates on the daily levels, the boss contract on the levels
-- with a boss) and `contracts` (Data/Quests/Contracts without the generator's rules). The cutscenes stay off the wiki.
-- S134k: a contract's monster kind (`monster`), its Hunter's Marks (`reward.marks`), the Huntmaster and his shop for
-- the marks (`contracts.shop`, Data/HuntShop; prices in marks are not premium) and the marks of contracts 1-99.

local Bosses = require("../../src/shared/Data/Bosses")
local Clean = require("./Clean")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local HuntShopData = require("../../src/shared/Data/HuntShop")
local Config = require("../../src/shared/Config")
local GatherNodes = require("../../src/shared/Data/GatherNodes")
local Maps = require("../../src/shared/Data/Maps")
local Monsters = require("../../src/shared/Data/Monsters")
local Names = require("./Names")
local Npcs = require("../../src/shared/Data/Npcs")
local QuestData = require("../../src/shared/Data/Quests")
local QuestLogic = require("../../src/shared/Logic/QuestLogic")
local Areas = require("../../src/shared/Data/Areas")
local Basics = require("./Basics")
local Places = require("./Places")
local Schema = require("./Schema")
local StoryProgress = require("../../src/shared/Logic/StoryProgress")

local S = Schema
local arr, map, rec = S.arr, S.map, S.rec

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
	["itemName?"] = "name",
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
	["where?"] = Places.Where, -- S37: map (and area, cave or NPC) of the objective
})

local Reward = rec("QuestReward", {
	exp = "int",
	gold = "int",
	items = arr(rec("QuestRewardItem", { id = "ref:items", n = "int" })),
	["choice?"] = "string",
	["mount?"] = "ref:mounts", -- S97: the stable arc's horse
	["cosmetic?"] = "ref:cosmetics", -- S97: a mount skin
	["marks?"] = "int", -- S134k: Hunter's Marks of a hunting contract
})

local DailyLevel = rec("DailyLevel", { level = "int", objective = Objective, reward = Reward })

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
			chapter = "int", -- S109: Main.chapterOf
		})),
		-- S109: the story's chapters (Main.CHAPTERS): levels of their quests, region, the finale
		chapters = arr(rec("QuestChapter", {
			n = "int",
			title = "name",
			from = "int",
			to = "int",
			map = "ref:maps",
			["final?"] = "bool",
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
				byLevel = arr(DailyLevel),
			})),
			-- WIKI-3 (S159): the set: groups drawn first, free rerolls, the streak and the set bonus on the daily
			-- levels (EXP at a streak of 1 and at the cap, the blessings); the Dragon Shards only as a flag (S131)
			["set?"] = rec("DailySet", {
				slots = arr("string"),
				rerolls = "int",
				streakCap = "int",
				streakShardsFrom = "int",
				shardMinLevel = "int",
				bonus = arr(rec("DailyBonusLevel", {
					level = "int",
					expFirst = "int",
					expCap = "int",
					items = arr(rec("DailyBonusItem", { id = "ref:items", n = "int" })),
					currency = "bool",
				})),
			}),
		}),
		-- S109: the first defeat of every boss (Data/Quests/Boss), given and handed in by the land's scout
		bossQuests = arr(rec("BossQuest", {
			id = "string",
			level = "int",
			giver = "ref:npcs",
			boss = "ref:bosses",
			title = "name",
			reward = Reward,
			["where?"] = Places.Where,
		})),
		-- S109: the weekly contracts (Data/Quests/Weekly) and the weekly boss contract
		weekly = rec("WeeklyQuests", {
			perWeek = "int",
			templates = arr(rec("WeeklyTemplate", {
				id = "string",
				minLevel = "int",
				title = "name",
				byLevel = arr(DailyLevel),
			})),
			-- WIKI-3 (S159): the weekly set bonus on the daily levels (Dragon Shards only as a flag)
			["bonus?"] = arr(rec("WeeklyBonusLevel", {
				level = "int",
				exp = "int",
				items = arr(rec("WeeklyBonusItem", { id = "ref:items", n = "int" })),
				currency = "bool",
			})),
			bossContract = rec("BossContract", {
				n = "int",
				byLevel = arr(rec("BossContractLevel", { level = "int", boss = "ref:bosses", reward = Reward })),
			}),
		}),
		-- S109: the hunting contracts 1-99 (Data/Quests/Contracts; RULES stay the generator's)
		contracts = rec("Contracts", {
			max = "int",
			board = "ref:npcs",
			scouts = arr("ref:npcs"),
			milestoneEvery = "int",
			list = arr(rec("Contract", {
				level = "int",
				map = "ref:maps",
				area = "ref:areas",
				monster = "ref:monsters", -- S134k: the kind to kill
				n = "int",
				label = "name",
				reward = Reward,
			})),
			-- S134k: the Huntmaster (takes and hands in like the board) and his shop for Hunter's Marks
			huntmaster = "ref:npcs",
			marksTotal = "int",
			shop = arr(rec("HuntShopEntry", {
				id = "string",
				kind = "string",
				group = "string",
				["item?"] = "ref:items",
				["n?"] = "int",
				["cosmetic?"] = "string",
				name = "name",
				marks = "int",
				["marksByQuality?"] = arr("int"),
				["minLevel?"] = "int",
				["maxLevel?"] = "int",
				["weeklyLimit?"] = "int",
			})),
		}),
		levelSlack = "int",
		sideLevelSlack = "int",
		sideMaxActive = "int",
		-- S42: class items offered by side quests with a reward choice (Config.SideQuest)
		sideChoice = rec("SideChoice", { count = "int", rarity = map(S.enum("RarityKey")) }),
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
	if t == "talk" and o.npc == QuestLogic.CLASS_VENDOR then
		-- S95: the vendor depends on the reader's class
		return Names.T("quest.obj.talkClassVendor", nil, lang)
	elseif t == "talk" then
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
		-- S109 (as UI/QuestText): only an area (the hunting contracts), Elite II (the weekly contracts)
		if area and not o.region and not o.variant then
			return Names.T("quest.obj.killArea", { area = textOf(area.nameKey, lang), count = count }, lang)
		end
		-- S159 (as UI/QuestText): the daily and weekly hunts in the level range
		if o.lvMin and not o.region then
			local key = if o.variant == "elite" then "quest.obj.killEliteLevel" else "quest.obj.killLevel"
			return Names.T(key, { level = o.lvMin, count = count }, lang)
		end
		local map = Maps.get(Quests.REGION_MAPS[o.region or 1] or "")
		local key = if o.variant == "elite2"
			then "quest.obj.killElite2"
			elseif o.variant == "elite" then "quest.obj.killElite"
			else "quest.obj.killRegion"
		return Names.T(key, { region = textOf(map and map.nameKey, lang), count = count }, lang)
	elseif t == "collect" then
		-- S109 (as UI/QuestText, S104): the loot of Elites only
		local def = if o.variant == "elite" and o.monster then Monsters.get(o.monster) else nil
		if def then
			return Names.T("quest.obj.collectFrom", {
				item = textOf(`quest.item.{o.item}`, lang),
				monster = textOf(def.nameKeys.elite, lang),
				count = count,
			}, lang) .. where
		end
		return Names.T("quest.obj.collect", { item = textOf(`quest.item.{o.item}`, lang), count = count }, lang)
			.. where
	elseif t == "gather" then
		if o.node then
			local kind = GatherNodes.get(o.node)
			return Names.T("quest.obj.gather", { node = textOf(kind and kind.nameKey, lang), count = count }, lang)
		end
		-- S109 (as UI/QuestText, S98): no node and no category = herbs or ore (the weekly "gather" contract)
		local key = if o.category == "ore"
			then "quest.obj.gatherOre"
			elseif o.category == "herb" then "quest.obj.gatherHerb"
			else "quest.obj.gatherAny"
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
	elseif t == "escort" then
		-- S101b: walk with the leading companion
		return Names.T("quest.obj.escort", { npc = npcName(o.npc), place = textOf(o.place, lang) }, lang)
	end
	return Names.T(`quest.obj.{t}`, { count = count }, lang)
end

local function objectives(list: { any }, turnIn: string?, level: number): { any }
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
		if entry.npc == QuestLogic.CLASS_VENDOR then
			entry.npc = nil -- S95: "your class vendor" is no NPC id (ref:npcs)
		end
		entry.label = Names.combine(function(lang: string): string
			return Quests.label(o, turnIn, lang)
		end)
		if o.place then
			entry.place = Names.of(o.place)
		end
		if o.item then
			entry.itemName = Names.opt(`quest.item.{o.item}`)
		end
		entry["where"] = Places.objectiveWhere(o, level, turnIn)
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
		-- S97: never an unpublished mount or cosmetic
		mount = if r.mount and not hidden[r.mount] then r.mount else nil,
		cosmetic = if r.cosmetic and not hidden[r.cosmetic] then r.cosmetic else nil,
		marks = r.marks, -- S134k
	}
end

local LEGACY: { [string]: boolean } = {}
for _, id in StoryProgress.LEGACY_ORDER do
	LEGACY[id] = true
end

-- S109 (G2): the story text of a main quest: the 32 quests of StoryProgress.LEGACY_ORDER keep `quest.<id>.text`;
-- a later one with offer pages exports p1..pN joined by a blank line (its `.text` is only the journal summary);
-- nil when neither exists.
function Quests.storyText(q: any): any?
	if LEGACY[q.id] or not q.pages then
		return Names.opt(`quest.{q.id}.text`)
	end
	return Names.combine(function(lang: string): string
		local parts = {}
		for i = 1, q.pages do
			table.insert(parts, Names.T(`quest.{q.id}.p{i}`, nil, lang))
		end
		return table.concat(parts, "\n\n")
	end)
end

function Quests.sideChoice(): any
	local rarity = {}
	for kind, id in Config.SideQuest.choiceRarity do
		rarity[kind] = Basics.rarityKey(id)
	end
	return { count = Config.SideQuest.choiceCount, rarity = rarity }
end

-- WIKI-3 (S159): the daily set rules and its bonus on the daily levels (Data/Quests/Daily). Shards: a flag only.
function Quests.dailySet(hidden: { [string]: boolean }): any
	local D = QuestData.Daily
	local rows = {}
	for _, level in Quests.DAILY_LEVELS do
		local first = D.bonus(level, 1)
		local cap = D.bonus(level, D.STREAK_CAP)
		table.insert(rows, {
			level = level,
			expFirst = first.exp,
			expCap = cap.exp,
			items = Clean.dropRefs(Clean.clean(first.items or {}), hidden, "id"),
			currency = (first.shards or 0) > 0 and level >= D.SHARD_MIN_LEVEL,
		})
	end
	return {
		slots = table.clone(D.SLOTS),
		rerolls = D.REROLLS,
		streakCap = D.STREAK_CAP,
		streakShardsFrom = D.BONUS.streakShardsFrom,
		shardMinLevel = D.SHARD_MIN_LEVEL,
		bonus = rows,
	}
end

-- WIKI-3 (S159): the weekly set bonus on the daily levels (Data/Quests/Weekly). Shards: a flag only.
function Quests.weeklyBonus(hidden: { [string]: boolean }): any
	local rows = {}
	for _, level in Quests.DAILY_LEVELS do
		local b = QuestData.Weekly.bonus(level)
		table.insert(rows, {
			level = level,
			exp = b.exp,
			items = Clean.dropRefs(Clean.clean(b.items or {}), hidden, "id"),
			currency = (b.shards or 0) > 0 and level >= QuestData.Daily.SHARD_MIN_LEVEL,
		})
	end
	return rows
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
	-- S102: `order` counts the exported story quests only (a hidden one stays out)
	local order = 0
	local chapterLevels: { [number]: { number } } = {}
	for _, q in QuestData.Main.list do
		if not ctx.hidden[q.id] then
			noteItems(q.id, q.reward)
			order += 1
			local chapter = QuestData.Main.chapterOf(q.id)
			local levels = chapterLevels[chapter] or {}
			chapterLevels[chapter] = levels
			table.insert(levels, q.level)
			table.insert(main, {
				id = q.id,
				order = order,
				level = q.level,
				giver = q.giver,
				turnIn = q.turnIn,
				title = Names.of(`quest.{q.id}.title`),
				text = Quests.storyText(q),
				done = Names.opt(`quest.{q.id}.done`),
				objectives = objectives(q.objectives, q.turnIn, q.level),
				reward = reward(q.reward, ctx.hidden),
				chapter = chapter,
			})
		end
	end
	local chapters = {}
	for _, c in QuestData.Main.CHAPTERS do
		local levels = chapterLevels[c.n]
		if levels and #levels > 0 then
			table.insert(chapters, {
				n = c.n,
				title = Names.of(`story.chapter.{c.n}`),
				from = math.min(table.unpack(levels)),
				to = math.max(table.unpack(levels)),
				map = c.region or "city",
				final = if c.final then true else nil,
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
				objectives = objectives(q.objectives, q.turnIn, q.level),
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
					objective = objectives({ t.objective(level) }, nil, level)[1],
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
	-- S109: boss quests (the boss objective's dungeon as the place)
	local bossQuests = {}
	for _, q in QuestData.Boss.list do
		local o = q.objectives[1]
		if not ctx.hidden[q.id] and o and o.boss and not ctx.hidden[o.boss] then
			table.insert(bossQuests, {
				id = q.id,
				level = q.level,
				giver = q.giver,
				boss = o.boss,
				title = Names.of(`quest.{q.id}.title`),
				reward = reward(q.reward, ctx.hidden),
				where = Places.objectiveWhere(o, q.level, q.turnIn),
			})
		end
	end
	-- S109: weekly templates on the daily levels from their minLevel; the boss contract where a boss can be entered
	local weeklyTemplates = {}
	for _, t in QuestData.Weekly.templates do
		if (t :: any).hidden ~= true then
			local byLevel = {}
			for _, level in Quests.DAILY_LEVELS do
				if level >= t.minLevel then
					table.insert(byLevel, {
						level = level,
						objective = objectives({ t.objective(level) }, nil, level)[1],
						reward = reward(QuestData.Weekly.reward(level), ctx.hidden),
					})
				end
			end
			table.insert(weeklyTemplates, {
				id = t.id,
				minLevel = t.minLevel,
				title = Names.of(`weekly.{t.id}.title`),
				byLevel = byLevel,
			})
		end
	end
	local bossLevels = {}
	for _, level in Quests.DAILY_LEVELS do
		local boss = QuestLogic.bossContractFor(level)
		if boss and not ctx.hidden[boss] then
			table.insert(
				bossLevels,
				{ level = level, boss = boss, reward = reward(QuestData.Weekly.bossReward(level), ctx.hidden) }
			)
		end
	end
	-- S109: the hunting contracts (the board in the city and the scout of every land take them)
	local Contracts = QuestData.Contracts
	local scouts = {}
	for _, mapId in Quests.REGION_MAPS do
		if Npcs.get(`scout_{mapId}`) and not ctx.hidden[`scout_{mapId}`] then
			table.insert(scouts, `scout_{mapId}`)
		end
	end
	local contractList = {}
	for _, c in Contracts.list do
		if not ctx.hidden[c.id] then
			local o = c.objectives[1]
			table.insert(contractList, {
				level = c.level,
				map = c.map,
				area = c.area,
				monster = o.monster,
				n = o.n,
				label = Names.combine(function(lang: string): string
					return Quests.label(o, nil, lang)
				end),
				reward = reward(c.reward, ctx.hidden),
			})
		end
	end
	local every = math.huge
	for level in Contracts.RULES.milestones do
		every = math.min(every, level)
	end
	-- S134k: the Huntmaster's shop (potions by the level's quality: their name and the price of every quality)
	local shop = {}
	for _, e in HuntShopData.ENTRIES do
		if not ctx.hidden[e.id] then
			local item = if e.kind == "item" then e.id else nil
			table.insert(shop, {
				id = e.key,
				kind = e.kind,
				group = e.group,
				item = item,
				n = if (e.n or 1) > 1 then e.n else nil,
				cosmetic = if e.kind == "cosmetic" then e.id else nil,
				name = if item
					then Names.item(item)
					elseif e.kind == "cosmetic" then Names.of((Cosmetics.get(e.id) :: any).nameKey)
					elseif e.kind == "chest" then Names.of(`item.{e.key}.name`)
					else Names.of(`huntshop.potion.{e.id}`),
				marks = e.price,
				marksByQuality = e.qualityPrices,
				minLevel = e.minLevel,
				maxLevel = e.maxLevel,
				weeklyLimit = e.weeklyLimit,
			})
		end
	end
	local marksTotal = 0
	for _, c in Contracts.list do
		marksTotal += c.reward.marks or 0
	end
	return {
		main = main,
		chapters = chapters,
		side = side,
		daily = { perDay = QuestData.Daily.PER_DAY, templates = templates, set = Quests.dailySet(ctx.hidden) },
		bossQuests = bossQuests,
		weekly = {
			perWeek = QuestData.Weekly.PER_WEEK,
			templates = weeklyTemplates,
			bonus = Quests.weeklyBonus(ctx.hidden),
			bossContract = { n = QuestData.Weekly.bossContract.n, byLevel = bossLevels },
		},
		contracts = {
			max = Contracts.MAX_LEVEL,
			board = "questboard",
			scouts = scouts,
			milestoneEvery = if every == math.huge then 10 else every,
			list = contractList,
			huntmaster = "huntmaster",
			marksTotal = marksTotal,
			shop = shop,
		},
		levelSlack = QuestData.Main.LEVEL_SLACK,
		sideLevelSlack = Config.SideQuest.levelSlack,
		sideMaxActive = Config.SideQuest.maxActive,
		sideChoice = Quests.sideChoice(),
	}
end

return Quests
