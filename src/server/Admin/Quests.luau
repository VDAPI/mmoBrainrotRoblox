--!strict
-- Admin commands: quests (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local NpcMarks = require(Shared.Logic.NpcMarks)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter

local QuestService = Context.services.QuestService
local PlayerStateService = Context.services.PlayerStateService

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

return commands
