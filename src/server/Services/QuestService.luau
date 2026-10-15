--!strict
-- Quests (DESIGN §20). The story: one accepted main quest at a time (character.quests.main), taken from its
-- giver NPC once the level allows it and handed in at its turn-in NPC. Daily contracts: 3 per UTC day
-- (Logic/QuestLogic.dailyFor), active automatically, rewards collected at the board on the plaza.
-- Progress comes from QuestEvents (combat, gathering, fishing, upgrades, …), kills (CombatService credit),
-- levels, map changes and talking to NPCs. Rewards check the backpack space first. S27: every event also goes to
-- the side quests (SideQuestService.Handle) and, S99, to the hunting contract (ContractService.Handle).
-- S98 (docs/DESIGN-15.md §3.1): weekly contracts (3 per week from Monday 00:00 UTC, Logic/QuestLogic.weeklyFor) and
-- the week's boss contract (the highest boss open to the character, `Weekly.bossContract.n` won dungeon runs: only
-- the "boss" event DungeonService fires after a won run counts, so Config.Boss.dailyRuns always applies), both
-- collected at the board.
-- S101b (DESIGN-15 §3.5): answers on quest pages (QuestSay(questId, choiceId), Logic/Dialogue.canSay, saved for good in
-- character.quests.said; an `item` answer needs the backpack space first) for the story and the side quests, and
-- CompanionService.Refresh after every change of the active quests (the companion of Logic/Companion).
-- S102 (docs/FABULA.md §2.1): the story runs on the side-quest machinery (Logic/SideQuests.mainEntry / advance: `use`
-- anchors in quests.main.used, `deliver`, places to reach), hand-in keeps the place in the story (mainDone = index of
-- the quest, mainLast = its id; Logic/StoryProgress recounts both on load) and story events queue the cutscenes of
-- Data/Cutscenes in quests.scenes (false = queued); the client plays them and reports CutsceneDone(sceneId).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Clock = require(Shared.Util.Clock)
local Cutscenes = require(Shared.Logic.Cutscenes)
local Dialogue = require(Shared.Logic.Dialogue)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local NpcVisibility = require(Shared.Logic.NpcVisibility)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Quests = require(Shared.Data.Quests)
local Rng = require(Shared.Logic.Rng)
local SideQuests = require(Shared.Logic.SideQuests)
local Skills = require(Shared.Logic.Skills)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)

local log = Log.new("QuestService")

-- The first story quests form the tutorial (Data/Quests/Main); reported as the onboarding funnel.
local TUTORIAL_STEPS = 10

local QuestService = {
	Name = "QuestService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"InventoryService",
		"LevelService",
		"CombatService",
		"NpcService",
		"ZoneService",
		"SideQuestService",
		"ContractService", -- S99: hunting contracts (ContractService.Handle)
		"CosmeticService", -- S97: Reward.cosmetic (the Dragonslayer's mount skin of the quest vaelgrath)
	},
}

local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local LevelService: any
local CombatService: any
local NpcService: any
local ZoneService: any
local SideQuestService: any
local ContractService: any
local CosmeticService: any
local Registry: any -- S101b: CompanionService during play (it is not in Deps: no cycle with the quest services)

local rng = Rng.new()

-- S101b: the companion follows the active quests (Logic/Companion.want).
local function refreshCompanion(player: Player)
	local companions = Registry and Registry.Get("CompanionService")
	if companions then
		companions.Refresh(player)
	end
end

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function itemArg(item: string): string
	return `@quest.item.{item}`
end

-- Daily contracts of today (regenerated on a new UTC day).
local function ensureDaily(player: Player)
	local char = character(player)
	if not char then
		return
	end
	local today = Time.dayNumber(Clock.now())
	local daily = char.quests.daily
	if daily.day == today and #daily.list > 0 then
		return
	end
	local list = QuestLogic.dailyFor(player.UserId, char.id, today, char.level)
	PlayerStateService.Set(player, { "character", "quests", "daily" }, { day = today, list = list, rerolls = 0 })
end

-- S98: the week's boss contract for the character's level (nil below the first boss's entry level).
local function bossContract(level: number): { boss: string, progress: number, claimed: boolean }?
	local bossId = QuestLogic.bossContractFor(level)
	return if bossId then { boss = bossId, progress = 0, claimed = false } else nil
end

-- S98: weekly contracts of this week (regenerated on a new week). A character that reaches the first boss's entry
-- level during the week gets the boss contract at once; once given, its boss stays until the week ends.
local function ensureWeekly(player: Player)
	local char = character(player)
	if not char then
		return
	end
	local week = Time.weekNumber(Clock.now())
	local weekly: any = char.quests.weekly
	if type(weekly) ~= "table" or weekly.week ~= week then
		PlayerStateService.Set(player, { "character", "quests", "weekly" }, {
			week = week,
			list = QuestLogic.weeklyFor(player.UserId, char.id, week, char.level),
			rerolls = 0,
			boss = bossContract(char.level),
		})
		return
	end
	if type(weekly.list) ~= "table" or #weekly.list == 0 then
		local list = QuestLogic.weeklyFor(player.UserId, char.id, week, char.level)
		if #list > 0 then
			PlayerStateService.Set(player, { "character", "quests", "weekly", "list" }, list)
		end
	end
	if weekly.boss == nil then
		local contract = bossContract(char.level)
		if contract then
			PlayerStateService.Set(player, { "character", "quests", "weekly", "boss" }, contract)
		end
	end
end

local function canFit(player: Player, items: { { id: string, n: number } }?): boolean
	if not items or #items == 0 then
		return true
	end
	local stacks = {}
	for _, item in items do
		table.insert(stacks, ItemRoll.makeStack(item.id, item.n, "check"))
	end
	return InventoryService.CanFit(player, stacks)
end

local function give(player: Player, reward: Quests.Reward)
	LevelService.GiveExp(player, reward.exp, "quest")
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold + reward.gold
	end)
	Analytics.gold(player, reward.gold, balance, "quest")
	local items: { { id: string, n: number } } = reward.items or {}
	for _, item in items do
		InventoryService.GiveNew(player, item.id, item.n)
	end
	-- S97: an account cosmetic (already owned: nothing, the quest is handed in all the same)
	if reward.cosmetic then
		CosmeticService.Grant(player, reward.cosmetic)
	end
	Net.Fire(player, "CombatFx", { { k = "reward", exp = reward.exp, gold = reward.gold } })
end

-- S102: queues the cutscenes a story event triggers (Logic/Cutscenes.triggered) that this character never had: once
-- per character, a scene once queued never comes back.
local function queueScenes(player: Player, questId: string, on: string, index: number?)
	local char = character(player)
	if not char then
		return
	end
	local scenes: { [string]: boolean } = char.quests.scenes or {}
	for _, id in Cutscenes.triggered(questId, on, index) do
		if scenes[id] == nil then
			PlayerStateService.Set(player, { "character", "quests", "scenes", id }, false)
		end
	end
end

-- Applies an event to the story quest and the daily contracts.
local function handle(player: Player, kind: string, data: { [string]: any })
	local char = character(player)
	if not char then
		return
	end
	if kind == "talk" and data.classId == nil then
		-- S95: "talk to your class vendor" objectives (QuestLogic.npcFor) need the talker's class
		data = table.clone(data)
		data.classId = char.class
	end
	-- S102: the story on the side-quest machinery (use anchors, deliver, places)
	local quest, storyEntry = SideQuests.mainEntry(char.quests)
	if quest and storyEntry and not QuestLogic.isComplete(storyEntry.progress, quest.objectives) then
		local before = table.clone(storyEntry.progress)
		local changed = SideQuests.advance(storyEntry, quest, kind, data, rng)
		if #changed > 0 then
			PlayerStateService.Set(
				player,
				{ "character", "quests", "main" },
				{ id = quest.id, progress = storyEntry.progress, used = storyEntry.used }
			)
			for _, index in changed do
				local objective = quest.objectives[index]
				if objective.type == "collect" and objective.item then
					Net.Fire(player, "Toast", "quest.collected", {
						item = itemArg(objective.item),
						have = storyEntry.progress[index],
						n = objective.n,
					}, "success")
				end
				if (before[index] or 0) < objective.n and (storyEntry.progress[index] or 0) >= objective.n then
					queueScenes(player, quest.id, "objective", index)
				end
			end
			if QuestLogic.isComplete(storyEntry.progress, quest.objectives) then
				Net.Fire(player, "Toast", "quest.ready", {
					title = `@quest.{quest.id}.title`,
					npc = `@{(Npcs.get(quest.turnIn) :: any).nameKey}`,
				}, "success")
				queueScenes(player, quest.id, "complete")
			end
		end
	end
	local daily = char.quests.daily
	for index, entry in daily.list do
		if not entry.claimed and entry.progress < entry.objective.n then
			local add = QuestLogic.amount(entry.objective, kind, data, rng:next())
			if add > 0 then
				local value = math.min(entry.objective.n, entry.progress + add)
				PlayerStateService.Set(
					player,
					{ "character", "quests", "daily", "list", index, "progress" } :: { any },
					value
				)
				if value >= entry.objective.n then
					Net.Fire(player, "Toast", "quest.dailyDone", { title = `@daily.{entry.template}.title` }, "success")
				end
			end
		end
	end
	-- S98: weekly contracts and the boss contract
	local weekly: any = char.quests.weekly
	if type(weekly) == "table" then
		for index, entry in weekly.list or {} do
			if not entry.claimed and entry.progress < entry.objective.n then
				local add = QuestLogic.amount(entry.objective, kind, data, rng:next())
				if add > 0 then
					local value = math.min(entry.objective.n, entry.progress + add)
					PlayerStateService.Set(
						player,
						{ "character", "quests", "weekly", "list", index, "progress" } :: { any },
						value
					)
					if value >= entry.objective.n then
						Net.Fire(
							player,
							"Toast",
							"quest.weeklyDone",
							{ title = `@weekly.{entry.template}.title` },
							"success"
						)
					end
				end
			end
		end
		local boss = weekly.boss
		local need = Quests.Weekly.bossContract.n
		if kind == "boss" and boss and not boss.claimed and data.bossId == boss.boss and boss.progress < need then
			local value = boss.progress + 1
			PlayerStateService.Set(player, { "character", "quests", "weekly", "boss", "progress" }, value)
			if value >= need then
				Net.Fire(player, "Toast", "quest.bossContractDone", {}, "success")
			end
		end
	end
	-- S27: the same event for every active side quest.
	SideQuestService.Handle(player, kind, data)
	-- S99: the hunting contract (kills of its area)
	ContractService.Handle(player, kind, data)
	-- S101b: progress may open or close the companion's objectives
	refreshCompanion(player)
end

function QuestService.Handle(player: Player, kind: string, data: { [string]: any }?)
	handle(player, kind, data or {})
end

-- S104: an NPC hidden from the character (NpcDef.showFrom, Logic/NpcVisibility) cannot be talked to either.
local function seen(player: Player, npcId: string): boolean
	local char = character(player)
	return NpcVisibility.visibleId(npcId, if char then char.quests else nil)
end

local function near(player: Player, npcId: string): boolean
	return Npcs.get(npcId) ~= nil and NpcService.Near(player, npcId) and seen(player, npcId)
end

-- Counts what the character already has when a quest starts (current map, level).
local function catchUp(player: Player)
	local char = character(player)
	if not char then
		return
	end
	-- S102: with the position, so a story place to reach counts on accepting it there
	local map, x, z = SideQuestService.WhereIs(player)
	if map then
		handle(player, "reach", { map = map, x = x, z = z })
	else
		handle(player, "reach", { map = char.location.map })
	end
	handle(player, "level", { level = char.level })
	-- S56: "learn" counts a skill on the bar; the level-3 auto-put happens before "wolves" is accepted
	-- (no daily or side quest has a "learn" objective)
	local onBar = QuestLogic.learnedOnBar(char.hotbar, Skills.startingSkill(char.class))
	if onBar then
		handle(player, "learn", { skillId = onBar })
	end
end

local function talk(player: Player, npcId: string): (boolean, string?)
	if not near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	handle(player, "talk", { npc = npcId })
	return true, nil
end

local function accept(player: Player, npcId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	if char.quests.main then
		return false, "quest.error.active"
	end
	local quest, ready = QuestLogic.nextMain(char.quests.mainDone, char.level)
	if not quest or quest.giver ~= npcId then
		return false, "error.badRequest"
	end
	if not ready then
		return false, "quest.error.level"
	end
	PlayerStateService.Set(player, { "character", "quests", "main" }, {
		id = quest.id,
		progress = QuestLogic.emptyProgress(quest.objectives),
		used = {},
	})
	-- S102: the virtual items of deliver objectives come with the quest (shown in the journal)
	for _, objective in quest.objectives do
		if objective.type == "deliver" and objective.item then
			Net.Fire(player, "Toast", "quest.deliverGot", { item = itemArg(objective.item) }, "info")
		end
	end
	queueScenes(player, quest.id, "accept")
	handle(player, "talk", { npc = npcId })
	catchUp(player)
	refreshCompanion(player)
	return true, nil
end

local function turnIn(player: Player, npcId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local main = char.quests.main
	local quest = main and Quests.Main.get(main.id)
	if not main or not quest or quest.turnIn ~= npcId then
		return false, "error.badRequest"
	end
	-- Talking to the turn-in NPC counts first (quests ending with "talk to X").
	handle(player, "talk", { npc = npcId })
	if not QuestLogic.isComplete(main.progress, quest.objectives) then
		return false, "quest.error.notDone"
	end
	if not canFit(player, quest.reward.items) then
		return false, "inventory.full"
	end
	PlayerStateService.Set(player, { "character", "quests", "main" }, nil)
	-- S102: the place in the story is the quest itself (Logic/StoryProgress recounts it on load)
	local index = Quests.Main.indexOf[quest.id]
	PlayerStateService.Set(player, { "character", "quests", "mainDone" }, index)
	PlayerStateService.Set(player, { "character", "quests", "mainLast" }, quest.id)
	-- The first story quests are the tutorial: report them as the onboarding funnel.
	if index <= TUTORIAL_STEPS then
		Analytics.onboarding(player, index, quest.id)
	end
	give(player, quest.reward)
	-- S132: class outfits of this quest for the character's class (obtain.quest; owned = nothing)
	CosmeticService.GrantQuestOutfits(player, quest.id, char.class)
	queueScenes(player, quest.id, "turnIn")
	Net.Fire(player, "QuestCompleted", `quest.{quest.id}.title`)
	log:info("%s completed %s", player.Name, quest.id)
	refreshCompanion(player)
	return true, nil
end

-- S101b: the player's answer on a quest page (story or side). The page's NPC (giver for an offer page, turn-in NPC for
-- the hand-in page) must be near and the page shown now (Logic/Dialogue.canSay); once per character and quest. An
-- `item` answer gives a small consumable of Config.Dialogue.gifts; without the backpack space nothing is saved (the
-- player can answer later, another answer works at once). `hint` and `focus` the client reads from `said`.
local function say(player: Player, questId: string, choiceId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local main = Quests.Main.get(questId)
	local quest: any = main or Quests.npcQuest(questId)
	if not quest then
		return false, "error.badRequest"
	end
	local kind: Dialogue.Kind = if main then "main" else "side"
	local option = Dialogue.option(quest, choiceId)
	if not option then
		return false, "quest.say.unknown"
	end
	local err: string? = "npc.error.tooFar"
	local ok = false
	for _, npcId in { quest.giver, quest.turnIn } do
		if near(player, npcId) then
			local allowed, reason = Dialogue.canSay(char.quests, char.level, kind, quest, choiceId, npcId)
			if allowed then
				ok = true
				break
			end
			err = reason
		end
	end
	if not ok then
		return false, err
	end
	local effect: any = option.effect
	if effect and effect.kind == "item" then
		local items = { { id = effect.id :: string, n = effect.n :: number } }
		if not canFit(player, items) then
			return false, "inventory.full"
		end
		InventoryService.GiveNew(player, effect.id, effect.n)
		Net.Fire(player, "Toast", "quest.say.gift", { item = `@item.{effect.id}.name`, n = effect.n }, "success")
	end
	PlayerStateService.Set(player, { "character", "quests", "said", questId }, choiceId)
	return true, nil
end

-- S102: the client finished or skipped a queued story cutscene; only a queued one turns into watched.
local function cutsceneDone(player: Player, sceneId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local scenes: { [string]: boolean } = char.quests.scenes or {}
	if scenes[sceneId] ~= false then
		return false, "error.badRequest"
	end
	PlayerStateService.Set(player, { "character", "quests", "scenes", sceneId }, true)
	return true, nil
end

local function claim(player: Player, index: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "quests") then
		return false, "npc.error.tooFar"
	end
	ensureDaily(player)
	local entry = char.quests.daily.list[index]
	if not entry or entry.claimed then
		return false, "error.badRequest"
	end
	if entry.progress < entry.objective.n then
		return false, "quest.error.notDone"
	end
	local reward = Quests.Daily.reward(char.level)
	if not canFit(player, reward.items) then
		return false, "inventory.full"
	end
	PlayerStateService.Set(player, { "character", "quests", "daily", "list", index, "claimed" } :: { any }, true)
	give(player, reward)
	Net.Fire(player, "QuestCompleted", `daily.{entry.template}.title`)
	return true, nil
end

-- S98: collects weekly contract `index` at the board.
local function claimWeekly(player: Player, index: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "quests") then
		return false, "npc.error.tooFar"
	end
	ensureWeekly(player)
	local weekly: any = char.quests.weekly
	local entry = if type(weekly) == "table" and type(weekly.list) == "table" then weekly.list[index] else nil
	if not entry or entry.claimed then
		return false, "error.badRequest"
	end
	if entry.progress < entry.objective.n then
		return false, "quest.error.notDone"
	end
	local reward = Quests.Weekly.reward(char.level)
	if not canFit(player, reward.items) then
		return false, "inventory.full"
	end
	PlayerStateService.Set(player, { "character", "quests", "weekly", "list", index, "claimed" } :: { any }, true)
	give(player, reward)
	Net.Fire(player, "QuestCompleted", `weekly.{entry.template}.title`)
	return true, nil
end

-- S98: collects the week's boss contract at the board.
local function claimBossContract(player: Player): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not NpcService.NearService(player, "quests") then
		return false, "npc.error.tooFar"
	end
	ensureWeekly(player)
	local weekly: any = char.quests.weekly
	local boss = if type(weekly) == "table" then weekly.boss else nil
	if not boss or boss.claimed then
		return false, "error.badRequest"
	end
	if boss.progress < Quests.Weekly.bossContract.n then
		return false, "quest.error.notDone"
	end
	local reward = Quests.Weekly.bossReward(char.level)
	if not canFit(player, reward.items) then
		return false, "inventory.full"
	end
	PlayerStateService.Set(player, { "character", "quests", "weekly", "boss", "claimed" }, true)
	give(player, reward)
	Net.Fire(player, "QuestCompleted", "quest.bossContract.title")
	return true, nil
end

-- Admin ------------------------------------------------------------------------------------------

-- /quest set <id>: makes `id` the active story quest (everything before counts as done).
function QuestService.SetMain(player: Player, questId: string): boolean
	local quest = Quests.Main.get(questId)
	local index = Quests.Main.indexOf[questId]
	if not quest or not index or not character(player) then
		return false
	end
	local before = Quests.Main.list[index - 1]
	PlayerStateService.Set(player, { "character", "quests", "mainDone" }, index - 1)
	PlayerStateService.Set(player, { "character", "quests", "mainLast" }, if before then before.id else nil)
	PlayerStateService.Set(player, { "character", "quests", "main" }, {
		id = quest.id,
		progress = QuestLogic.emptyProgress(quest.objectives),
		used = {},
	})
	catchUp(player)
	refreshCompanion(player)
	return true
end

-- /quest complete: fills every objective of the active story quest.
function QuestService.CompleteMain(player: Player): boolean
	local char = character(player)
	local main = char and char.quests.main
	local quest = main and Quests.Main.get(main.id)
	if not quest then
		return false
	end
	-- S102: the anchors of use objectives count as used, and the scenes queue as if the objectives just filled (so
	-- /quest complete shows them)
	local before: { number } = table.clone((main :: any).progress or {})
	local progress = {}
	local used: { string } = table.clone((main :: any).used or {})
	for i, objective in quest.objectives do
		progress[i] = objective.n
		if objective.type == "use" then
			local anchors: { string } = objective.anchors or { objective.anchor :: string }
			for _, anchor in anchors do
				if not table.find(used, anchor) then
					table.insert(used, anchor)
				end
			end
		end
	end
	PlayerStateService.Set(
		player,
		{ "character", "quests", "main" },
		{ id = quest.id, progress = progress, used = used }
	)
	for i, objective in quest.objectives do
		if (before[i] or 0) < objective.n then
			queueScenes(player, quest.id, "objective", i)
		end
	end
	queueScenes(player, quest.id, "complete")
	refreshCompanion(player)
	return true
end

-- S102 /scene play: queues a scene again (also one already watched); false for an unknown id.
function QuestService.QueueScene(player: Player, sceneId: string): boolean
	if not Cutscenes.isKnown(sceneId) or not character(player) then
		return false
	end
	PlayerStateService.Set(player, { "character", "quests", "scenes", sceneId }, false)
	return true
end

-- S102 /scene reset: forgets every scene of the character (they play again on their next trigger).
function QuestService.ResetScenes(player: Player): boolean
	if not character(player) then
		return false
	end
	PlayerStateService.Set(player, { "character", "quests", "scenes" }, {})
	return true
end

-- /daily reroll: new contracts for today.
function QuestService.RerollDaily(player: Player): boolean
	local char = character(player)
	if not char then
		return false
	end
	local today = Time.dayNumber(Clock.now())
	local rerolls = (char.quests.daily.rerolls or 0) + 1
	local list = QuestLogic.dailyFor(player.UserId, `{char.id}#{rerolls}`, today, char.level)
	PlayerStateService.Set(player, { "character", "quests", "daily" }, { day = today, list = list, rerolls = rerolls })
	return true
end

-- S98 /weekly reroll: new weekly contracts for this week (the boss contract stays).
function QuestService.RerollWeekly(player: Player): boolean
	local char = character(player)
	if not char then
		return false
	end
	ensureWeekly(player)
	local weekly: any = char.quests.weekly
	local week = Time.weekNumber(Clock.now())
	local rerolls = (weekly.rerolls or 0) + 1
	PlayerStateService.Set(player, { "character", "quests", "weekly" }, {
		week = week,
		list = QuestLogic.weeklyFor(player.UserId, `{char.id}#{rerolls}`, week, char.level),
		rerolls = rerolls,
		boss = weekly.boss,
	})
	return true
end

-- S98 /weekly complete: fills every weekly contract and the boss contract (to test collecting them).
function QuestService.CompleteWeekly(player: Player): boolean
	local char = character(player)
	if not char then
		return false
	end
	ensureWeekly(player)
	local weekly: any = char.quests.weekly
	for index, entry in weekly.list do
		PlayerStateService.Set(
			player,
			{ "character", "quests", "weekly", "list", index, "progress" } :: { any },
			entry.objective.n
		)
	end
	if weekly.boss then
		PlayerStateService.Set(
			player,
			{ "character", "quests", "weekly", "boss", "progress" },
			Quests.Weekly.bossContract.n
		)
	end
	return true
end

function QuestService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	LevelService = registry.Get("LevelService")
	CombatService = registry.Get("CombatService")
	NpcService = registry.Get("NpcService")
	ZoneService = registry.Get("ZoneService")
	SideQuestService = registry.Get("SideQuestService")
	ContractService = registry.Get("ContractService")
	CosmeticService = registry.Get("CosmeticService")
	Registry = registry
end

function QuestService.Start()
	Net.Handle("QuestTalk", talk)
	Net.Handle("QuestAccept", accept)
	Net.Handle("QuestTurnIn", turnIn)
	Net.Handle("DailyClaim", claim)
	Net.Handle("WeeklyClaim", claimWeekly)
	Net.Handle("BossContractClaim", claimBossContract)
	Net.Handle("QuestSay", say)
	Net.Handle("CutsceneDone", cutsceneDone)

	QuestEvents.Fired:Connect(function(player: Player, kind: string, data: { [string]: any })
		handle(player, kind, data)
	end)
	CombatService.MonsterKilled:Connect(function(info: any, credit: { Player })
		for _, player in credit do
			handle(player, "kill", {
				monsterId = info.monsterId,
				variant = info.variant,
				level = info.level,
				mapId = info.mapId,
				areaId = info.areaId,
			})
		end
	end)
	LevelService.LeveledUp:Connect(function(player: Player, level: number)
		handle(player, "level", { level = level })
		ensureWeekly(player) -- S98: the boss contract from the first boss's entry level
	end)
	ZoneService.ZoneChanged:Connect(function(player: Player, zone: any)
		handle(player, "reach", { map = zone.map })
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		ensureDaily(player)
		ensureWeekly(player)
		catchUp(player)
	end)

	-- New UTC day while playing.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if PlayerStateService.HasState(player) and character(player) then
					ensureDaily(player)
					ensureWeekly(player)
				end
			end
		end
	end)
end

return QuestService
