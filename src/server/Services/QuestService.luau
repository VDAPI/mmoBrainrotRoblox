--!strict
-- Quests (DESIGN §20). The story: one accepted main quest at a time (character.quests.main), taken from its
-- giver NPC once the level allows it and handed in at its turn-in NPC. Daily contracts: 3 per UTC day
-- (Logic/QuestLogic.dailyFor), active automatically, rewards collected at the board on the plaza.
-- Progress comes from QuestEvents (combat, gathering, fishing, upgrades, …), kills (CombatService credit),
-- levels, map changes and talking to NPCs. Rewards check the backpack space first.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Clock = require(Shared.Util.Clock)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Quests = require(Shared.Data.Quests)
local Rng = require(Shared.Logic.Rng)
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
	},
}

local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local LevelService: any
local CombatService: any
local NpcService: any
local ZoneService: any

local rng = Rng.new()

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
	Net.Fire(player, "CombatFx", { { k = "reward", exp = reward.exp, gold = reward.gold } })
end

-- Applies an event to the story quest and the daily contracts.
local function handle(player: Player, kind: string, data: { [string]: any })
	local char = character(player)
	if not char then
		return
	end
	local main = char.quests.main
	local quest = main and Quests.Main.get(main.id)
	if main and quest and not QuestLogic.isComplete(main.progress, quest.objectives) then
		local progress = table.clone(main.progress)
		local changed = QuestLogic.advance(progress, quest.objectives, kind, data, rng)
		if #changed > 0 then
			PlayerStateService.Set(player, { "character", "quests", "main", "progress" }, progress)
			for _, index in changed do
				local objective = quest.objectives[index]
				if objective.type == "collect" and objective.item then
					Net.Fire(player, "Toast", "quest.collected", {
						item = itemArg(objective.item),
						have = progress[index],
						n = objective.n,
					}, "success")
				end
			end
			if QuestLogic.isComplete(progress, quest.objectives) then
				Net.Fire(player, "Toast", "quest.ready", {
					title = `@quest.{quest.id}.title`,
					npc = `@{(Npcs.get(quest.turnIn) :: any).nameKey}`,
				}, "success")
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
end

function QuestService.Handle(player: Player, kind: string, data: { [string]: any }?)
	handle(player, kind, data or {})
end

local function near(player: Player, npcId: string): boolean
	return Npcs.get(npcId) ~= nil and NpcService.Near(player, npcId)
end

-- Counts what the character already has when a quest starts (current map, level).
local function catchUp(player: Player)
	local char = character(player)
	if not char then
		return
	end
	handle(player, "reach", { map = char.location.map })
	handle(player, "level", { level = char.level })
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
	})
	handle(player, "talk", { npc = npcId })
	catchUp(player)
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
	PlayerStateService.Set(player, { "character", "quests", "mainDone" }, char.quests.mainDone + 1)
	-- The first story quests are the tutorial: report them as the onboarding funnel.
	if char.quests.mainDone <= TUTORIAL_STEPS then
		Analytics.onboarding(player, char.quests.mainDone, quest.id)
	end
	give(player, quest.reward)
	Net.Fire(player, "QuestCompleted", `quest.{quest.id}.title`)
	log:info("%s completed %s", player.Name, quest.id)
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

-- Admin ------------------------------------------------------------------------------------------

-- /quest set <id>: makes `id` the active story quest (everything before counts as done).
function QuestService.SetMain(player: Player, questId: string): boolean
	local quest = Quests.Main.get(questId)
	local index = Quests.Main.indexOf[questId]
	if not quest or not index or not character(player) then
		return false
	end
	PlayerStateService.Set(player, { "character", "quests", "mainDone" }, index - 1)
	PlayerStateService.Set(player, { "character", "quests", "main" }, {
		id = quest.id,
		progress = QuestLogic.emptyProgress(quest.objectives),
	})
	catchUp(player)
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
	local progress = {}
	for i, objective in quest.objectives do
		progress[i] = objective.n
	end
	PlayerStateService.Set(player, { "character", "quests", "main", "progress" }, progress)
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

function QuestService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	LevelService = registry.Get("LevelService")
	CombatService = registry.Get("CombatService")
	NpcService = registry.Get("NpcService")
	ZoneService = registry.Get("ZoneService")
end

function QuestService.Start()
	Net.Handle("QuestTalk", talk)
	Net.Handle("QuestAccept", accept)
	Net.Handle("QuestTurnIn", turnIn)
	Net.Handle("DailyClaim", claim)

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
			})
		end
	end)
	LevelService.LeveledUp:Connect(function(player: Player, level: number)
		handle(player, "level", { level = level })
	end)
	ZoneService.ZoneChanged:Connect(function(player: Player, zone: any)
		handle(player, "reach", { map = zone.map })
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		ensureDaily(player)
		catchUp(player)
	end)

	-- New UTC day while playing.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				if PlayerStateService.HasState(player) and character(player) then
					ensureDaily(player)
				end
			end
		end
	end)
end

return QuestService
