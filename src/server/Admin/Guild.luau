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
local LeaderboardService = Context.services.LeaderboardService
local SocialService = Context.services.SocialService -- S133
local FriendService = Context.services.FriendService -- S150
local AdminService = Context.services.AdminService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

-- S133: /social <player>: the friends and ignored players of a player on this server.
commands.social = function(player, args)
	local target = AdminService.FindPlayer(args[1] or "")
	if not target then
		reply(player, "admin.player.none")
		return false, "admin.player.none"
	end
	local friends, ignored = SocialService.Describe(target)
	reply(player, "admin.social.list", { name = target.Name, friends = friends, ignored = ignored })
	return true
end

-- S150: /presence <player | userId>: the raw presence entry, its status from this server and its age.
commands.presence = function(player, args)
	local who = args[1] or ""
	local target = AdminService.FindPlayer(who)
	local userId = if target then target.UserId else tonumber(who)
	if not userId then
		reply(player, "admin.player.none")
		return false, "admin.player.none"
	end
	local status, line = FriendService.Describe(userId)
	reply(player, "admin.presence.line", { id = userId, status = status, entry = line or "-" })
	return true
end

-- S150: /friends budget: read tokens, reads in the last minute, cache hits, refused reads, mode and watchers.
commands.friends = function(player, _args)
	local stats, mode, watching = FriendService.Budget()
	reply(player, "admin.friends.budget", {
		tokens = stats.tokens,
		reads = stats.reads,
		hits = stats.hits,
		denied = stats.denied,
		mode = mode,
		watching = watching,
	})
	return true
end

-- S150: /friendinvite <player>: a party invitation from the caller to the player through the topic.
commands.friendinvite = function(player, args)
	local target = AdminService.FindPlayer(args[1] or "")
	if not target then
		reply(player, "admin.player.none")
		return false, "admin.player.none"
	end
	local ok = FriendService.TestInvite(player, target)
	reply(player, if ok then "admin.friendinvite.sent" else "admin.friendinvite.failed", { name = target.Name })
	return ok
end

-- S125: the guild board entry of the player's guild.
commands.rankguild = function(player, args)
	withCharacter(player, function()
		if args[1] == "push" and not LeaderboardService.GuildPush(player) then
			reply(player, "admin.rank.noGuild")
			return
		end
		local score, rank = LeaderboardService.GuildInfo(player)
		if score == nil then
			reply(player, "admin.rank.noGuild")
			return
		end
		reply(player, "admin.rank.guild", { score = score, rank = if rank then rank else "-" })
	end)
end

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
