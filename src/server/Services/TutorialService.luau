--!strict
-- The hands-on tutorial of a new character (S155, docs/DESIGN.md §20 "Samouczek"; rules in Logic/Tutorial). The server
-- owns character.tutorial: it counts the steps it sees itself (taking a story quest: QuestService.MainAccepted, a
-- potion: PotionService.Drank, a basic attack hitting a monster: CombatService.BasicHit, a skill cast from the bar:
-- SkillService.Casted) through TutorialService.Event, and only the client steps of Tutorial.clientAllowed (move,
-- backpack) from the TutorialEvent remote. TutorialSkip skips the rest. Every step counted is an onboarding funnel step
-- (Tutorial.funnelStep), a skip a custom event "TutorialSkip" with the step it happened at.
-- The level reward (Data/Tutorial.REWARD, Tutorial.rewardDue): at level 5 every character made from S155 on (skipped or
-- not) gets the title cosmetic and the bound stacks; a full backpack sends the stacks by mail (once key
-- tutorial_<character id>). The mark is written first and undone when the mail fails (like LoginRewardService), on
-- that character even after a switch during the mail; the check runs on every level up and on entering the world.
-- Characters made before S155 have reward = true.
-- The potion step: while it is the current step an ordinary potion can be drunk at full (PotionService.AddFullDrink),
-- since a new character stands in the city at full HP.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Tutorial = require(Shared.Logic.Tutorial)
local TutorialData = require(Shared.Data.Tutorial)
local Types = require(Shared.Types)

type ItemInstance = Types.ItemInstance
type State = Tutorial.State

local log = Log.new("TutorialService")

local TutorialService = {
	Name = "TutorialService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"QuestService",
		"PotionService",
		"CombatService",
		"SkillService",
		"LevelService",
		"InventoryService",
		"CosmeticService",
		"MailService",
	},
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local QuestService: any
local PotionService: any
local CombatService: any
local SkillService: any
local LevelService: any
local InventoryService: any
local CosmeticService: any
local MailService: any

local busy: { [Player]: boolean } = {} -- a reward being mailed

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function stateOf(player: Player): State?
	local char = character(player)
	return if char then Tutorial.sanitize(char.tutorial) else nil
end

local function write(player: Player, state: State)
	PlayerStateService.Set(player, { "character", "tutorial" }, state)
end

-- Counts one step event (a step id) for the player's character; true when it counted. The only way into the steps on
-- the server: the signals below, the TutorialEvent remote (client steps) and the admin command.
function TutorialService.Event(player: Player, name: string): boolean
	local before = stateOf(player)
	if not before then
		return false
	end
	local after, changed = Tutorial.advance(before, name)
	if not changed then
		return false
	end
	write(player, after)
	local step = Tutorial.funnelStep("tutorial", name)
	if step then
		Analytics.onboarding(player, step, name)
	end
	if after.done and not before.done then
		log:info("%s finished the tutorial", player.Name)
	end
	return true
end

-- Skips the rest of the tutorial; false when it is already finished.
function TutorialService.Skip(player: Player): boolean
	local before = stateOf(player)
	if not before or before.done then
		return false
	end
	write(player, Tutorial.skip(before))
	Analytics.custom(player, "TutorialSkip", before.step)
	return true
end

-- The reward stacks, bound to the character (Data/Tutorial.REWARD.items).
local function rewardItems(): { ItemInstance }
	local items: { ItemInstance } = {}
	for _, entry in TutorialData.REWARD.items do
		local item = ItemRoll.makeStack(entry.id, entry.n, InventoryService.NewUid())
		item.bound = true
		table.insert(items, item)
	end
	return items
end

-- Gives the level reward when it is due (Tutorial.rewardDue); true when it was given (now or by mail). Yields when
-- the backpack is full (the mail).
function TutorialService.TryReward(player: Player): boolean
	local char = character(player)
	if not char or busy[player] or PlayerStateService.GetPhase(player) ~= "playing" then
		return false
	end
	local before = Tutorial.sanitize(char.tutorial)
	if not Tutorial.rewardDue(before, char.level) then
		return false
	end
	local after = Tutorial.sanitize(before) -- a copy
	after.reward = true
	write(player, after)
	CosmeticService.Grant(player, TutorialData.REWARD.title, nil, true) -- the client's reward toast names it
	local items = rewardItems()
	if InventoryService.CanFit(player, items) and not InventoryService.IsTradeLocked(player) then
		for _, item in items do
			local leftover = InventoryService.AddItem(player, item)
			if leftover > 0 then
				log:warn("%s: %d x %s did not fit after CanFit", player.Name, leftover, item.id)
			end
		end
	else
		busy[player] = true
		local sent, err = MailService.Send(player.UserId, {
			from = "system",
			subjectKey = "mail.subject.tutorial",
			items = items,
			charId = char.id,
			once = `tutorial_{char.id}`,
		})
		busy[player] = nil
		if not sent then
			log:warn("tutorial reward for %s not mailed: %s", player.Name, tostring(err))
			-- undo on the character that got the mark: the player may have switched characters during the mail
			local active = if player.Parent ~= nil and PlayerStateService.HasState(player)
				then character(player)
				else nil
			local undone = Tutorial.sanitize(char.tutorial)
			undone.reward = false
			if active and active.id == char.id then
				write(player, undone)
			else
				char.tutorial = undone -- the saved table of the character left (not replicated, not active)
			end
			return false
		end
		if player.Parent ~= nil then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "tutorial.rewardMailed", nil, "info")
		end
	end
	if player.Parent ~= nil then
		DataService.Save(player)
		local step = Tutorial.funnelStep("level", Tutorial.LEVEL_KEY)
		if step then
			Analytics.onboarding(player, step, Tutorial.LEVEL_KEY)
		end
	end
	log:info("%s got the tutorial reward at level %d", player.Name, char.level)
	return true
end

-- Admin (/tutorial) --------------------------------------------------------------------------------------------------

function TutorialService.Info(player: Player): State?
	return stateOf(player)
end

-- Back to step 1 with the reward waiting again.
function TutorialService.Reset(player: Player): boolean
	if not character(player) then
		return false
	end
	write(player, Tutorial.newState())
	return true
end

-- Jumps to the step `id` (the earlier ones done, nothing pending); false for an unknown id.
function TutorialService.SetStep(player: Player, id: string): boolean
	local index = Tutorial.indexOf[id]
	local before = stateOf(player)
	if not index or not before then
		return false
	end
	local after: State = {
		step = index,
		done = index == #Tutorial.STEPS,
		skipped = false,
		reward = before.reward,
	}
	write(player, after)
	return true
end

-- Finishes the tutorial as if every step was done (no funnel events).
function TutorialService.Finish(player: Player): boolean
	return TutorialService.SetStep(player, Tutorial.STEPS[#Tutorial.STEPS].id)
end

function TutorialService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	QuestService = registry.Get("QuestService")
	PotionService = registry.Get("PotionService")
	CombatService = registry.Get("CombatService")
	SkillService = registry.Get("SkillService")
	LevelService = registry.Get("LevelService")
	InventoryService = registry.Get("InventoryService")
	CosmeticService = registry.Get("CosmeticService")
	MailService = registry.Get("MailService")
	PotionService.AddFullDrink(function(player: Player): boolean
		local state = stateOf(player)
		return state ~= nil and Tutorial.wantsPotion(state)
	end)
end

function TutorialService.Start()
	Net.On("TutorialEvent", function(player: Player, name: string)
		if Tutorial.clientAllowed(name) and PlayerStateService.GetPhase(player) == "playing" then
			TutorialService.Event(player, name)
		end
	end)
	Net.On("TutorialSkip", function(player: Player)
		TutorialService.Skip(player)
	end)

	QuestService.MainAccepted:Connect(function(player: Player)
		TutorialService.Event(player, "quest")
	end)
	PotionService.Drank:Connect(function(player: Player)
		TutorialService.Event(player, "potion")
	end)
	CombatService.BasicHit:Connect(function(player: Player)
		TutorialService.Event(player, "attack")
	end)
	SkillService.Casted:Connect(function(player: Player)
		TutorialService.Event(player, "skill")
	end)

	LevelService.LeveledUp:Connect(function(player: Player)
		task.spawn(TutorialService.TryReward, player)
	end)
	CharacterService.CharacterEntered:Connect(function(player: Player)
		local char = character(player)
		-- a story quest taken or handed in before (a crash, /tutorial reset) still counts
		if char and (char.quests.main ~= nil or (tonumber(char.quests.mainDone) or 0) > 0) then
			TutorialService.Event(player, "quest")
		end
		task.spawn(TutorialService.TryReward, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return TutorialService
