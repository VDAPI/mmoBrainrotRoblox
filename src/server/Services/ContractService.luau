--!strict
-- Hunting contracts (S99, docs/DESIGN-15.md §3.3, Data/Quests/Contracts): one kill contract per level 1-99 on a
-- hunting ground of that level, in order (character.quests.contract = { done, active? }, rules in Logic/Contracts).
-- One active at a time; taken and handed in at the contract board in the city or at the scout of the contract's
-- region (no other NPC); the contract of level L needs the character at L. Handing one in takes the next one at once
-- when the level allows it, wherever the player stands (an NPC is only needed for the first one and after waiting
-- for a level). Kills come through QuestService.handle (CombatService credit, the area of the monster's group), so a
-- party's kills count for every credited member. Kills before taking a contract do not count.
--   ContractAccept(npcId) · ContractTurnIn(npcId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Areas = require(Shared.Data.Areas)
local Contracts = require(Shared.Logic.Contracts)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Quests = require(Shared.Data.Quests)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)

local log = Log.new("ContractService")

local ContractService = {
	Name = "ContractService",
	Deps = { "PlayerStateService", "InventoryService", "LevelService", "NpcService", "CharacterService" },
}

local PlayerStateService: any
local InventoryService: any
local LevelService: any
local NpcService: any

local rng = Rng.new()

local PATH = { "character", "quests", "contract" }

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function stateOf(char: Types.CharacterData): Contracts.State
	return Contracts.stateOf(char.quests)
end

local function areaArg(areaId: string): string
	local area = Areas.areaById(areaId)
	return if area then `@{area.nameKey}` else areaId
end

local function npcArg(npcId: string): string
	local def = Npcs.get(npcId)
	return if def then `@{def.nameKey}` else npcId
end

-- Arguments of `contract.title` ("Hunting contract {n}: {area}") for toasts and QuestCompleted.
local function titleArgs(contract: Quests.ContractQuest): { [string]: any }
	return { n = contract.level, area = areaArg(contract.area) }
end

local function setActive(player: Player, done: number, contract: Quests.ContractQuest?)
	local value: { [string]: any } = { done = done }
	if contract then
		value.active = { level = contract.level, progress = QuestLogic.emptyProgress(contract.objectives) }
	end
	PlayerStateService.Set(player, PATH, value)
end

-- Applies a gameplay event to the active contract (QuestService.handle calls this for every event).
function ContractService.Handle(player: Player, kind: string, data: { [string]: any })
	if kind ~= "kill" then
		return
	end
	local char = character(player)
	if not char then
		return
	end
	local state = stateOf(char)
	local contract, entry = Contracts.active(state)
	if not contract or not entry or Contracts.isComplete(state) then
		return
	end
	local progress = table.clone(entry.progress)
	local changed = QuestLogic.advance(progress, contract.objectives, kind, data, rng)
	if #changed == 0 then
		return
	end
	-- a new list: the state layer diffs by assignment
	PlayerStateService.Set(player, { "character", "quests", "contract", "active", "progress" }, progress)
	if QuestLogic.isComplete(progress, contract.objectives) then
		Net.Fire(player, "Toast", "contract.ready", {
			area = areaArg(contract.area),
			scout = npcArg(`scout_{contract.map}`),
		}, "success")
	end
end

local function accept(player: Player, npcId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not Npcs.get(npcId) or not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local state = stateOf(char)
	local ok, reason = Contracts.canAccept(state, char.level)
	if not ok then
		return false, if reason == "level" then "quest.error.level" else `contract.error.{reason}`
	end
	local nextContract = Contracts.next(state)
	if not nextContract then
		return false, "contract.error.none"
	end
	if not Contracts.isGiver(npcId, nextContract) then
		return false, "contract.error.giver"
	end
	setActive(player, state.done, nextContract)
	log:info("%s accepted %s", player.Name, nextContract.id)
	return true, nil
end

local function turnIn(player: Player, npcId: string): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local state = stateOf(char)
	local contract = Contracts.active(state)
	if not contract then
		return false, "error.badRequest"
	end
	if not Contracts.isComplete(state) then
		return false, "quest.error.notDone"
	end
	if not Contracts.isGiver(npcId, contract) then
		return false, "contract.error.giver"
	end
	if not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local reward = contract.reward
	local items: { { id: string, n: number } } = reward.items or {}
	if #items > 0 then
		local stacks = {}
		for _, item in items do
			table.insert(stacks, ItemRoll.makeStack(item.id, item.n, "check"))
		end
		if not InventoryService.CanFit(player, stacks) then
			return false, "inventory.full"
		end
	end
	local done = contract.level
	setActive(player, done, nil)
	LevelService.GiveExp(player, reward.exp, "contract")
	local balance = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold + reward.gold
	end)
	Analytics.gold(player, reward.gold, balance, "contract")
	for _, item in items do
		InventoryService.GiveNew(player, item.id, item.n)
	end
	Net.Fire(player, "CombatFx", { { k = "reward", exp = reward.exp, gold = reward.gold } })
	Net.Fire(player, "QuestCompleted", "contract.title", titleArgs(contract))
	log:info("%s completed %s", player.Name, contract.id)
	-- the next one is taken at once when the level allows it (the level after the EXP above)
	local now = character(player)
	if not now then
		return true, nil
	end
	local after = stateOf(now)
	local nextContract = Contracts.next(after)
	if nextContract and Contracts.canAccept(after, now.level) then
		setActive(player, after.done, nextContract)
		local args = titleArgs(nextContract)
		Net.Fire(player, "Toast", "contract.next", {
			title = { key = "contract.title", args = args },
		}, "info")
	elseif nextContract then
		Net.Fire(player, "Toast", "contract.waiting", { level = nextContract.level }, "info")
	end
	return true, nil
end

-- Admin ------------------------------------------------------------------------------------------------------------

-- /contract set <level>: contract `level` active with no progress (every one before counts as done).
function ContractService.SetLevel(player: Player, level: number): boolean
	local contract = Quests.Contracts.forLevel(level)
	if not contract or not character(player) then
		return false
	end
	setActive(player, level - 1, contract)
	return true
end

-- /contract complete: fills the active contract.
function ContractService.Complete(player: Player): boolean
	local char = character(player)
	if not char then
		return false
	end
	local contract = Contracts.active(stateOf(char))
	if not contract then
		return false
	end
	local progress = {}
	for i, objective in contract.objectives do
		progress[i] = objective.n
	end
	PlayerStateService.Set(player, { "character", "quests", "contract", "active", "progress" }, progress)
	return true
end

-- /contract reset: back to contract 1 (nothing active).
function ContractService.Reset(player: Player): boolean
	if not character(player) then
		return false
	end
	setActive(player, 0, nil)
	return true
end

export type Info = { done: number, active: string?, have: number?, need: number?, next: string? }

-- /contract info
function ContractService.Info(player: Player): Info?
	local char = character(player)
	if not char then
		return nil
	end
	local state = stateOf(char)
	local contract, entry = Contracts.active(state)
	local nextContract = Quests.Contracts.forLevel(state.done + (if contract then 2 else 1))
	return {
		done = state.done,
		active = if contract then contract.id else nil,
		have = if entry then entry.progress[1] or 0 else nil,
		need = if contract then contract.objectives[1].n else nil,
		next = if nextContract then nextContract.id else nil,
	}
end

function ContractService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	LevelService = registry.Get("LevelService")
	NpcService = registry.Get("NpcService")
end

function ContractService.Start()
	Net.Handle("ContractAccept", accept)
	Net.Handle("ContractTurnIn", turnIn)
end

return ContractService
