--!strict
-- Admin commands: quests (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Areas = require(Shared.Data.Areas)
local BudgetData = require(Shared.Data.QuestBudget)
local CavePlan = require(Shared.Logic.CavePlan)
local CutsceneData = require(Shared.Data.Cutscenes)
local Maps = require(Shared.Data.Maps)
local NpcMarks = require(Shared.Logic.NpcMarks)
local QuestBudget = require(Shared.Logic.QuestBudget)
local Quests = require(Shared.Data.Quests)
local SideQuests = require(Shared.Logic.SideQuests)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter

local QuestService = Context.services.QuestService
local PlayerStateService = Context.services.PlayerStateService
local SideQuestService = Context.services.SideQuestService
local ContractService = Context.services.ContractService
local CompanionService = Context.services.CompanionService
local AdminService = Context.services.AdminService
local TravelService = Context.services.TravelService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.quest = function(player, args)
	withCharacter(player, function()
		if args[1] == "info" then
			-- S102: the place in the story (Logic/StoryProgress) and the chapter of the active or next quest
			local quests = PlayerStateService.GetCharacter(player).quests
			local active = if type(quests.main) == "table" then quests.main.id else nil
			local nextQuest = Quests.Main.list[(quests.mainDone or 0) + 1]
			local current = active or (if nextQuest then nextQuest.id else nil)
			reply(player, "admin.quest.info", {
				done = quests.mainDone or 0,
				last = quests.mainLast or "—",
				active = active or "—",
				chapter = if current then Quests.Main.chapterOf(current) else "—",
			})
		elseif args[1] == "set" and args[2] and QuestService.SetMain(player, args[2]) then
			reply(player, "admin.quest.set", { id = args[2] })
		elseif args[1] == "complete" and QuestService.CompleteMain(player) then
			reply(player, "admin.quest.complete")
		else
			reply(player, "admin.usage.quest")
		end
	end)
end

commands.daily = function(player, args)
	if args[1] ~= "reroll" then
		reply(player, "admin.usage.daily")
		return
	end
	withCharacter(player, function()
		QuestService.RerollDaily(player)
		reply(player, "admin.daily.reroll")
	end)
end

-- S98: /weekly reroll | complete
commands.weekly = function(player, args)
	local action = args[1]
	if action ~= "reroll" and action ~= "complete" then
		reply(player, "admin.usage.weekly")
		return
	end
	withCharacter(player, function()
		if action == "reroll" then
			QuestService.RerollWeekly(player)
		else
			QuestService.CompleteWeekly(player)
		end
		reply(player, "admin.weekly.done")
	end)
end

-- S99: /contract info | set <level> | complete | reset
commands.contract = function(player, args)
	local action = args[1]
	withCharacter(player, function()
		if action == "info" then
			local info = ContractService.Info(player)
			if not info then
				return
			end
			reply(player, "admin.contract.info", {
				done = info.done,
				max = Quests.Contracts.MAX_LEVEL,
				active = info.active or "-",
				have = info.have or 0,
				need = info.need or 0,
				next = info.next or "-",
			})
		elseif action == "set" then
			local level = tonumber(args[2])
			local contract = if level then Quests.Contracts.forLevel(math.floor(level)) else nil
			if contract and ContractService.SetLevel(player, contract.level) then
				reply(player, "admin.contract.set", { id = contract.id })
			else
				reply(player, "admin.usage.contract")
			end
		elseif action == "complete" and ContractService.Complete(player) then
			reply(player, "admin.contract.complete")
		elseif action == "reset" and ContractService.Reset(player) then
			reply(player, "admin.contract.reset")
		else
			reply(player, "admin.usage.contract")
		end
	end)
end

-- S98: /questbudget [level]: the monster EXP multiplier of the quest budget (Logic/QuestBudget).
commands.questbudget = function(player, args)
	withCharacter(player, function()
		local char = PlayerStateService.GetCharacter(player)
		local level = math.clamp(math.floor(tonumber(args[1]) or char.level), 1, 100)
		local lo, hi = QuestBudget.bandOf(level)
		local t = BudgetData.TARGET
		local target = t.contract + t.main + t.side + t.boss
		reply(player, "admin.questbudget.line", {
			level = level,
			mul = string.format("%.3f", QuestBudget.monsterExpMul(level)),
			lo = lo,
			hi = hi,
			target = math.floor(target * 100 + 0.5),
		})
	end)
end

-- S25: quest marks over NPCs (Logic/NpcMarks) for the caller's character, as the maps show them.
commands.questmarks = function(player)
	withCharacter(player, function()
		local char = PlayerStateService.GetCharacter(player)
		local marks = NpcMarks.all(char.quests, char.level)
		local ids = {}
		for npcId in marks do
			table.insert(ids, npcId)
		end
		table.sort(ids)
		if #ids == 0 then
			reply(player, "admin.questmarks.none")
			return
		end
		for _, npcId in ids do
			reply(player, "admin.questmarks.line", { npc = npcId, mark = marks[npcId] })
		end
	end)
end

-- S27: /side list [prefix] | give <id> | complete <id> | reset [id] | arc <id> (S108: the arc prefix filter)
commands.side = function(player, args)
	local action, id = args[1], args[2]
	withCharacter(player, function()
		local char = PlayerStateService.GetCharacter(player)
		if action == "list" then
			-- S108: `/side list <prefix>` shows only the arcs whose id starts with it (`fp_`: the Frost Peaks)
			for _, arc in Quests.Side.ARCS do
				if id and id ~= "" and string.sub(arc, 1, #id) ~= id then
					continue
				end
				local lines = {}
				local list: { Quests.SideQuest } = Quests.Side.byArc[arc] or {}
				for _, quest in list do
					local state = if SideQuests.isDone(char.quests, quest.id)
						then "✔"
						elseif SideQuests.isActive(char.quests, quest.id) then "…"
						elseif SideQuests.canAccept(char.quests, char.level, quest) then "!"
						else "·"
					table.insert(lines, `{state} {quest.id} ({quest.level})`)
				end
				reply(player, "admin.side.arc", { arc = `@quest.arc.{arc}`, list = table.concat(lines, ", ") })
			end
			return
		end
		if action == "reset" and SideQuestService.Reset(player, id) then
			reply(player, "admin.side.done", { action = action, id = id or "*" })
			return
		end
		if not id or not Quests.npcQuest(id) then
			reply(player, "admin.usage.side")
			return
		end
		local ok = if action == "give"
			then SideQuestService.Give(player, id)
			elseif action == "complete" then SideQuestService.Complete(player, id)
			elseif action == "arc" then SideQuestService.SkipTo(player, id)
			else false
		reply(player, if ok then "admin.side.done" else "admin.usage.side", { action = action, id = id })
	end)
end

-- S101b: /companion info | reset [player]: the quest companion of the caller or of a named player.
commands.companion = function(player, args)
	local action = args[1]
	local target = player
	if args[2] and args[2] ~= "" then
		local found = AdminService.FindPlayer(args[2])
		if not found then
			reply(player, "admin.player.none")
			return
		end
		target = found
	end
	if action == "info" then
		local info = CompanionService.Info(target)
		if info then
			reply(player, "admin.companion.info", {
				name = target.Name,
				npc = `@npc.{info.npc}.name`,
				quest = info.quest,
				mode = info.mode,
				phase = info.phase,
			})
		else
			reply(player, "admin.companion.none", { name = target.Name })
		end
	elseif action == "reset" then
		if CompanionService.Reset(target) then
			reply(player, "admin.companion.reset", { name = target.Name })
		else
			reply(player, "admin.companion.none", { name = target.Name })
		end
	else
		reply(player, "admin.usage.companion")
	end
end

-- S102: /scene play <id> | list | reset: story cutscenes of the caller's character (play = queue again, also a watched
-- one; reset = forget them all).
commands.scene = function(player, args)
	local action, id = args[1], args[2]
	withCharacter(player, function()
		local quests = PlayerStateService.GetCharacter(player).quests
		if action == "play" then
			if id and QuestService.QueueScene(player, id) then
				reply(player, "admin.scene.done", { action = action, id = id })
			else
				reply(player, "admin.scene.unknown", { id = id or "" })
			end
		elseif action == "list" then
			local scenes = quests.scenes or {}
			for _, scene in CutsceneData.list do
				local value = scenes[scene.id]
				reply(player, "admin.scene.line", {
					id = scene.id,
					state = if value == true then "✔" elseif value == false then "…" else "·",
				})
			end
		elseif action == "reset" and QuestService.ResetScenes(player) then
			reply(player, "admin.scene.done", { action = action, id = "*" })
		else
			reply(player, "admin.usage.scene")
		end
	end)
end

-- S27: /anchor <id>: teleport next to a quest anchor (no id: the list).
commands.anchor = function(player, args)
	local id = args[1]
	local found: Areas.QuestAnchor?, mapId: string? = nil, nil
	local names = {}
	for map, data in Areas.byMap do
		for _, anchor in (data.questAnchors or {}) :: { Areas.QuestAnchor } do
			table.insert(names, anchor.id)
			if anchor.id == id then
				found, mapId = anchor, map
			end
		end
	end
	-- S102: anchors inside caves (Areas.anchorById knows them too)
	for _, cave in Areas.caves.list do
		for _, anchor in CavePlan.anchors(cave) do -- S134h: as drawn (scaled cave)
			table.insert(names, anchor.id)
			if anchor.id == id then
				found, mapId = anchor, cave.id
			end
		end
	end
	if not found or not mapId then
		table.sort(names)
		reply(player, "admin.anchor.list", { list = table.concat(names, ", ") })
		return
	end
	local anchor = found
	local map = Maps.get(mapId)
	local position = SideQuestService.AnchorPosition(anchor.id)
	if not map or not position then
		reply(player, "admin.maps.notBuilt", { map = mapId })
		return
	end
	withCharacter(player, function()
		local at = position + Vector3.new(4, 2, 4)
		task.spawn(TravelService.TeleportToMap, player, mapId, CFrame.lookAt(at, position))
		reply(player, "admin.anchor.tp", { id = anchor.id })
	end)
end

return commands
