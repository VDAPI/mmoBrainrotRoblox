--!strict
-- Admin commands: quests (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter

local QuestService = Context.services.QuestService

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

return commands
