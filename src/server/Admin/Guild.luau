--!strict
-- Admin commands: guild (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local GuildLogic = require(Shared.Logic.Guild)
local GuildSkills = require(Shared.Data.GuildSkills)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount

local GuildService = Context.services.GuildService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.guild = function(player, args)
	withCharacter(player, function()
		local data = GuildService.Data(player)
		if not data then
			reply(player, "admin.guild.none")
			return
		end
		local sub = args[1]
		if sub == "info" then
			local skills = {}
			for id, level in data.skills do
				table.insert(skills, `{id} {level}`)
			end
			local count = 0
			for _ in data.members do
				count += 1
			end
			reply(player, "admin.guild.info", {
				name = data.name,
				tag = data.tag,
				members = count,
				treasury = data.treasury,
				skills = if #skills > 0 then table.concat(skills, ", ") else "-",
				version = data.version,
				id = data.id,
			})
		elseif sub == "treasury" and parseAmount(args[2]) then
			local amount = math.max(0, parseAmount(args[2]) :: number)
			if GuildService.AdminMutate(player, function(guild)
				guild.treasury = amount
			end) then
				reply(player, "admin.guild.done")
			end
		elseif sub == "skills" and args[2] == "max" then
			if
				GuildService.AdminMutate(player, function(guild)
					for _, def in GuildSkills.list do
						guild.skills[def.id] = GuildSkills.MAX_LEVEL
					end
				end)
			then
				reply(player, "admin.guild.done")
			end
		elseif sub == "bots" and parseAmount(args[2]) then
			-- Offline dummy members to test the member list, ranks and kicking alone.
			local n = math.clamp(parseAmount(args[2]) :: number, 1, 40)
			local classes = { "Warrior", "Hunter", "Mage", "Cleric" }
			if
				GuildService.AdminMutate(player, function(guild)
					local limit = GuildLogic.memberLimit(guild.skills)
					for i = 1, n do
						if GuildLogic.memberCount(guild) >= limit then
							break
						end
						local charId = `bot{guild.version}_{i}`
						guild.members[GuildLogic.memberKey(-i, charId)] = {
							userId = -i,
							charId = charId,
							name = `Bot{i}`,
							class = classes[(i - 1) % 4 + 1],
							level = 10 + i * 2,
							rank = "member",
							joinedAt = os.time(),
							contributed = 0,
						}
					end
				end)
			then
				reply(player, "admin.guild.done")
			end
		elseif sub == "disband" then
			if GuildService.AdminDisband(player) then
				reply(player, "admin.guild.done")
			end
		else
			reply(player, "admin.usage.guild")
		end
	end)
end

return commands
