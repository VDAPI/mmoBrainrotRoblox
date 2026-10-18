--!strict
-- Hunting contracts (S99, S134k; docs/DESIGN-15.md §3.3, Data/Quests/Contracts): one contract per level 1-99, "kill n
-- of <kind> on <hunting ground>" (character.quests.contract, rules in Logic/Contracts). S134k: every contract up to the
-- character's level may be active at once, without a limit; a kill counts for every matching active contract (its
-- kind on its ground: QuestLogic.amount through Contracts.credit). Taken and handed in at the contract board in the
-- city, at the Huntmaster beside it or at the scout of the contract's region: "Accept all" (ContractAccept) takes every
-- contract that NPC gives, ContractAcceptOne one of them, "Hand in all" (ContractTurnIn) hands in every finished one
-- that NPC takes, ContractAbandon drops an active one (its progress is lost). After the first contract taken at an NPC
-- (`auto`), a level up takes the contract of the new level wherever the player stands. Hand-in rewards: the EXP and
-- gold of the contract's own level, its Hunter's Marks and milestone items (whatever does not fit goes by mail: never
-- a refused hand-in). Kills come through QuestService.handle (CombatService credit, the area of the monster's group),
-- so a party's kills count for every credited member. Kills before taking a contract do not count.
--   ContractAccept(npcId) · ContractAcceptOne(npcId, level) · ContractTurnIn(npcId) · ContractAbandon(level)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)

local Areas = require(Shared.Data.Areas)
local Contracts = require(Shared.Logic.Contracts)
local ItemRoll = require(Shared.Logic.ItemRoll)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Log = require(Shared.Util.Log)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local QuestLogic = require(Shared.Logic.QuestLogic)
local Quests = require(Shared.Data.Quests)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)

local log = Log.new("ContractService")

local ContractService = {
	Name = "ContractService",
	Deps = {
		"PlayerStateService",
		"InventoryService",
		"LevelService",
		"NpcService",
		"CharacterService",
		"MailService", -- S134k: milestone items that do not fit
		"CosmeticService", -- S134k: the title of the last contract
	},
}

local PlayerStateService: any
local InventoryService: any
local LevelService: any
local NpcService: any
local MailService: any
local CosmeticService: any
local CharacterService: any

local rng = Rng.new()

local PATH = { "character", "quests", "contract" }

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function stateOf(char: Types.CharacterData): Contracts.State
	return Contracts.stateOf(char.quests)
end

local function write(player: Player, state: Contracts.State)
	PlayerStateService.Set(player, PATH, state)
end

local function areaArg(areaId: string): string
	local area = Areas.areaById(areaId)
	return if area then `@{area.nameKey}` else areaId
end

local function npcArg(npcId: string): string
	local def = Npcs.get(npcId)
	return if def then `@{def.nameKey}` else npcId
end

local function monsterArg(kind: string?): string
	local def = if kind then Monsters.get(kind) else nil
	return if def then `@{def.nameKeys.normal}` else (kind or "?")
end

-- Arguments of `contract.title` ("Hunting contract {n}: {monster} ({area})") for toasts and QuestCompleted.
local function titleArgs(contract: Quests.ContractQuest): { [string]: any }
	return { n = contract.level, monster = monsterArg(contract.objectives[1].monster), area = areaArg(contract.area) }
end

-- Arguments of `contract.objective` ("Kill {n}x {monster} ({area})").
local function objectiveArgs(contract: Quests.ContractQuest): { [string]: any }
	local objective = contract.objectives[1]
	return { n = objective.n, monster = monsterArg(objective.monster), area = areaArg(contract.area) }
end

-- Takes `list` (no yields) and says so ("contract.next" for one, "contract.acceptedMany" for more).
local function take(player: Player, state: Contracts.State, list: { Quests.ContractQuest })
	if #list == 0 then
		return
	end
	write(player, Contracts.withAccepted(state, list))
	if #list == 1 then
		Net.Fire(
			player,
			"Toast",
			"contract.next",
			{ title = { key = "contract.title", args = titleArgs(list[1]) } },
			"info"
		)
	else
		Net.Fire(player, "Toast", "contract.acceptedMany", { n = #list }, "info")
	end
	log:info("%s took %d contract(s) from %d", player.Name, #list, list[1].level)
end

-- A kill advances every matching active contract (one write of the branch); a level up takes the contracts of the
-- new levels once `auto` is on (QuestService.handle calls this for every event).
function ContractService.Handle(player: Player, kind: string, data: { [string]: any })
	if kind ~= "kill" and kind ~= "level" then
		return
	end
	local char = character(player)
	if not char then
		return
	end
	local state = stateOf(char)
	if kind == "level" then
		-- only a real level up (LevelService.LeveledUp sends `gained`); QuestService.catchUp's "level" on entering the
		-- world or accepting a quest must not take back an abandoned contract of the current level
		if not state.auto or data.gained == nil then
			return
		end
		local level = math.floor(tonumber(data.level) or char.level)
		local gained = math.max(1, math.floor(tonumber(data.gained) or 1))
		local list: { Quests.ContractQuest } = {}
		for _, contract in Contracts.eligible(state, level) do
			if contract.level > level - gained then
				table.insert(list, contract)
			end
		end
		take(player, state, list)
		return
	end
	local levels = Contracts.credit(state, kind, data)
	if #levels == 0 then
		return
	end
	local after = Contracts.copy(state)
	local finished: { Quests.ContractQuest } = {}
	for _, level in levels do
		local entry = Contracts.activeEntry(after, level)
		local contract = Quests.Contracts.forLevel(level)
		if entry and contract then
			QuestLogic.advance(entry.progress, contract.objectives, kind, data, rng)
			if QuestLogic.isComplete(entry.progress, contract.objectives) then
				table.insert(finished, contract)
			end
		end
	end
	-- a new branch: the state layer diffs by assignment
	PlayerStateService.Set(player, { "character", "quests", "contract", "active" }, after.active)
	if #finished == 1 then
		local contract = finished[1]
		local args = objectiveArgs(contract)
		args.scout = npcArg(`scout_{contract.map}`)
		Net.Fire(player, "Toast", "contract.ready", args, "success")
	elseif #finished > 1 then
		Net.Fire(player, "Toast", "contract.readyMany", { n = #finished }, "success")
	end
end

local function errorKey(reason: string?): string
	return if reason == "level" then "quest.error.level" else `contract.error.{reason or "none"}`
end

-- "Accept all": every contract this NPC gives the character now. Returns the number taken.
local function accept(player: Player, npcId: string): (boolean, string?, number?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not Npcs.get(npcId) or not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local state = stateOf(char)
	local ok, reason = Contracts.canAccept(state, char.level, npcId)
	if not ok then
		return false, errorKey(reason)
	end
	local list = Contracts.acceptable(state, char.level, npcId)
	take(player, state, list)
	return true, nil, #list
end

-- One contract of `level` from this NPC (the journal's and the board's rows).
local function acceptOne(player: Player, npcId: string, level: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not Npcs.get(npcId) or not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local state = stateOf(char)
	local ok, reason = Contracts.canAccept(state, char.level, npcId, level)
	if not ok then
		return false, errorKey(reason)
	end
	local contract = Quests.Contracts.forLevel(level) :: Quests.ContractQuest
	take(player, state, { contract })
	return true, nil
end

-- Items that did not fit: one system parcel to the character (yields; the hand-in itself is done already).
local function mailItems(player: Player, charId: string, items: { Types.ItemInstance })
	local sent, err = MailService.Send(player.UserId, {
		from = "system",
		subjectKey = "mail.subject.contract",
		items = items,
		charId = charId,
	})
	if sent then
		if player.Parent ~= nil then
			MailService.Refresh(player)
			Net.Fire(player, "Toast", "contract.mailed", nil, "info")
		end
		return
	end
	log:warn("contract items of %s not mailed: %s", player.Name, tostring(err))
end

export type TurnInResult = { n: number, exp: number, gold: number, marks: number }

-- "Hand in all": every finished contract this NPC takes, in order of level. The branch is written first, then the
-- gold, one LevelService.GiveExp per contract (a level up in between counts), the cosmetic and the items; no yield.
local function turnIn(player: Player, npcId: string): (boolean, string?, TurnInResult?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not Npcs.get(npcId) or not NpcService.Near(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local state = stateOf(char)
	local ready = Contracts.ready(state, npcId)
	if #ready == 0 then
		return false, if #Contracts.complete(state) > 0 then "contract.error.giver" else "quest.error.notDone"
	end
	local levels: { number } = {}
	local gold, marks = 0, 0
	local stacks: { Types.ItemInstance } = {}
	local handed: { Quests.ContractQuest } = {}
	for _, taken in ready do
		local reward = taken.contract.reward
		table.insert(levels, taken.contract.level)
		gold += reward.gold
		marks += reward.marks or 0
		for _, item in (reward.items or {}) :: { { id: string, n: number } } do
			local stack = ItemRoll.makeStack(item.id, item.n, InventoryService.NewUid())
			table.insert(stacks, stack)
		end
		table.insert(handed, taken.contract)
	end
	local after = Contracts.withHandedIn(state, levels, marks)
	write(player, after)
	QuestEvents.fire(player, "quest", { kind = "contract", n = #ready }) -- S151: contracts handed in (achievements)
	if gold > 0 then
		local balance = PlayerStateService.Update(player, { "character", "gold" }, function(current: number)
			return current + gold
		end)
		Analytics.gold(player, gold, balance, "contract")
	end
	local exp = 0
	for _, taken in ready do
		exp += taken.contract.reward.exp
		LevelService.GiveExp(player, taken.contract.reward.exp, "contract")
	end
	-- the title of contract 99 only once all 99 are handed in (Contracts.earnedCosmetics)
	for _, id in Contracts.earnedCosmetics(after, handed) do
		CosmeticService.Grant(player, id)
	end
	local leftovers: { Types.ItemInstance } = {}
	for _, stack in stacks do
		local left = if InventoryService.IsTradeLocked(player) then stack.n else InventoryService.AddItem(player, stack)
		if left > 0 then
			local rest = ItemRoll.makeStack(stack.id, left, InventoryService.NewUid())
			table.insert(leftovers, rest)
		end
	end
	if #leftovers > 0 then
		task.spawn(mailItems, player, char.id, leftovers)
	end
	Net.Fire(player, "CombatFx", { { k = "reward", exp = exp, gold = gold, marks = marks } })
	if #ready == 1 then
		Net.Fire(player, "QuestCompleted", "contract.title", titleArgs(ready[1].contract))
	else
		Net.Fire(player, "QuestCompleted", "contract.titleMany", { n = #ready })
	end
	Analytics.custom(player, "ContractTurnIn", #ready)
	log:info("%s handed in %d contract(s) at %s (+%d marks)", player.Name, #ready, npcId, marks)
	return true, nil, { n = #ready, exp = exp, gold = gold, marks = marks }
end

-- Drops an active contract (its progress is lost; it can be taken again).
local function abandon(player: Player, level: number): (boolean, string?)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	local state = stateOf(char)
	if not Contracts.activeEntry(state, level) then
		return false, "error.badRequest"
	end
	write(player, Contracts.withAbandoned(state, level))
	return true, nil
end

-- Admin ------------------------------------------------------------------------------------------------------------

-- /contract set <level>: contracts before `level` handed in, `level` active with no progress (the marks stay).
function ContractService.SetLevel(player: Player, level: number): boolean
	local contract = Quests.Contracts.forLevel(level)
	local char = character(player)
	if not contract or not char then
		return false
	end
	local state = stateOf(char)
	state.done, state.extra, state.active = level - 1, {}, {}
	write(player, Contracts.withAccepted(state, { contract }))
	return true
end

-- /contract all: takes every contract up to the character's level without an NPC; the number taken.
function ContractService.AcceptAll(player: Player): number
	local char = character(player)
	if not char then
		return 0
	end
	local state = stateOf(char)
	local list = Contracts.eligible(state, char.level)
	take(player, state, list)
	return #list
end

-- /contract finish [level|all]: fills the active contract of `level` (nil = every active one); the number filled.
function ContractService.Finish(player: Player, level: number?): number
	local char = character(player)
	if not char then
		return 0
	end
	local state = Contracts.copy(stateOf(char))
	local n = 0
	for _, taken in Contracts.activeList(state) do
		if level == nil or taken.entry.level == level then
			for i, objective in taken.contract.objectives do
				taken.entry.progress[i] = objective.n
			end
			n += 1
		end
	end
	if n > 0 then
		PlayerStateService.Set(player, { "character", "quests", "contract", "active" }, state.active)
	end
	return n
end

-- /contract reset: back to contract 1 (nothing active, the marks stay).
function ContractService.Reset(player: Player): boolean
	local char = character(player)
	if not char then
		return false
	end
	local state = stateOf(char)
	local fresh = Contracts.empty()
	fresh.marks, fresh.shopWeek = state.marks, state.shopWeek
	write(player, fresh)
	return true
end

-- /marks <n>: adds (or takes, never below 0) Hunter's Marks; the new balance.
function ContractService.AddMarks(player: Player, amount: number): number?
	local char = character(player)
	if not char then
		return nil
	end
	local state = stateOf(char)
	local marks = math.max(0, state.marks + math.floor(amount))
	PlayerStateService.Set(player, { "character", "quests", "contract", "marks" }, marks)
	return marks
end

export type Info = { done: number, extra: number, active: number, ready: number, eligible: number, marks: number }

-- /contract info
function ContractService.Info(player: Player): Info?
	local char = character(player)
	if not char then
		return nil
	end
	local state = stateOf(char)
	return {
		done = state.done,
		extra = #state.extra,
		active = #state.active,
		ready = #Contracts.complete(state),
		eligible = #Contracts.eligible(state, char.level),
		marks = state.marks,
	}
end

function ContractService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	LevelService = registry.Get("LevelService")
	NpcService = registry.Get("NpcService")
	MailService = registry.Get("MailService")
	CosmeticService = registry.Get("CosmeticService")
	CharacterService = registry.Get("CharacterService")
end

-- The title of the last contract for a character that handed in all 99 before S134k (or out of order before the
-- rule): given on entering the world, nothing when owned.
local function grantEarned(player: Player, char: Types.CharacterData)
	if character(player) ~= char then
		return
	end
	for _, id in Contracts.earnedCosmetics(stateOf(char), {}) do
		CosmeticService.Grant(player, id)
	end
end

function ContractService.Start()
	CharacterService.CharacterEntered:Connect(function(player: Player, char: Types.CharacterData)
		task.defer(grantEarned, player, char)
	end)
	Net.Handle("ContractAccept", accept)
	Net.Handle("ContractAcceptOne", acceptOne)
	Net.Handle("ContractTurnIn", turnIn)
	Net.Handle("ContractAbandon", abandon)
end

return ContractService
