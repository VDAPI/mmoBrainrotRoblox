--!strict
-- Admin commands: quests (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Areas = require(Shared.Data.Areas)
local Maps = require(Shared.Data.Maps)
local NpcMarks = require(Shared.Logic.NpcMarks)
local Quests = require(Shared.Data.Quests)
local SideQuests = require(Shared.Logic.SideQuests)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter

local QuestService = Context.services.QuestService
local PlayerStateService = Context.services.PlayerStateService
local SideQuestService = Context.services.SideQuestService
local TravelService = Context.services.TravelService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.quest = function(player, args)
	withCharacter(player, function()
		if args[1] == "set" and args[2] and QuestService.SetMain(player, args[2]) then
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

-- S27: /side list | give <id> | complete <id> | reset [id] | arc <id>
commands.side = function(player, args)
	local action, id = args[1], args[2]
	withCharacter(player, function()
		local char = PlayerStateService.GetCharacter(player)
		if action == "list" then
			for _, arc in Quests.Side.ARCS do
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
		if not id or not Quests.Side.get(id) then
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
