--!strict
-- Admin commands: data (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared

local AccountSchema = require(Shared.Logic.AccountSchema)
local AdminCommands = require(Shared.Data.AdminCommands)
local Classes = require(Shared.Data.Classes)

local Context = require(script.Parent.Context)

local reply = Context.reply
local log = Context.log

local DataService = Context.services.DataService
local PlayerStateService = Context.services.PlayerStateService
local CharacterService = Context.services.CharacterService
local NameService = Context.services.NameService
local LeaderboardService = Context.services.LeaderboardService
local AdminService = Context.services.AdminService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

local WIPE_CONFIRM_SECONDS = 30
local wipeRequests: { [Player]: number } = {}
Players.PlayerRemoving:Connect(function(player)
	wipeRequests[player] = nil
end)

commands.help = function(player)
	reply(player, "admin.help.header")
	for _, def in AdminCommands.sorted() do
		reply(player, def.usageKey)
	end
end

commands.wipe = function(player, args)
	local requestedAt = wipeRequests[player]
	local confirmed = args[1] == "confirm" and requestedAt ~= nil and os.clock() - requestedAt <= WIPE_CONFIRM_SECONDS
	if not confirmed then
		wipeRequests[player] = os.clock()
		reply(player, "admin.wipe.confirm", { seconds = WIPE_CONFIRM_SECONDS })
		return
	end
	wipeRequests[player] = nil

	local data = DataService.GetData(player)
	if not data then
		return
	end
	CharacterService.ReturnToSelect(player)
	for _, character in data.characters do
		NameService.Release(character.name, NameService.OwnerKey(player.UserId, character.id))
	end
	-- Replace contents in place: the profile keeps referencing the same table.
	local fresh = AccountSchema.accountTemplate()
	local keepLang = data.settings.lang
	for key in data :: any do
		(data :: any)[key] = nil
	end
	for key, value in fresh :: any do
		(data :: any)[key] = value
	end
	data.settings.lang = keepLang
	data.stats.createdAt = os.time()
	PlayerStateService.Reset(player)
	log:info("%s wiped their account", player.Name)
	reply(player, "admin.wipe.ok")
end

commands.resetcodes = function(player)
	PlayerStateService.Set(player, { "account", "redeemed" }, {})
	reply(player, "admin.resetcodes.ok")
end

-- S124: /lb info | refresh | submit | hide <player> | show <player> | remove <board:key> | fake <n> | hofclear <class>
commands.lb = function(player, args)
	local action, arg = args[1], args[2]
	if action == "info" then
		local info = LeaderboardService.Info(player)
		reply(player, "admin.lb.info", info :: any)
	elseif action == "refresh" then
		local ok, n = LeaderboardService.ForceRefresh()
		reply(player, if ok then "admin.lb.refreshed" else "admin.lb.cooldown", { n = n })
	elseif action == "submit" then
		Context.withCharacter(player, function()
			reply(player, if LeaderboardService.AdminSubmit(player) then "admin.lb.submitted" else "admin.lb.excluded")
		end)
	elseif action == "hide" or action == "show" then
		local target = AdminService.FindPlayer(arg or "")
		if not target or not LeaderboardService.SetHidden(target, action == "hide") then
			reply(player, "admin.player.none")
			return
		end
		reply(player, if action == "hide" then "admin.lb.hidden" else "admin.lb.shown", { name = target.Name })
	elseif action == "remove" then
		local board, key = string.match(arg or "", "^([^:]+):(.+)$")
		if not board or not key or not LeaderboardService.RemoveEntry(board, key) then
			reply(player, "admin.usage.lb")
			return
		end
		reply(player, "admin.lb.removed")
	elseif action == "fake" then
		local n = tonumber(arg)
		if not n or n < 1 or n > 200 then
			reply(player, "admin.usage.lb")
			return
		end
		if not LeaderboardService.Fake(math.floor(n)) then
			reply(player, "admin.lb.notMock")
			return
		end
		reply(player, "admin.lb.faked", { n = math.floor(n) })
	elseif action == "hofclear" then
		local class: string? = nil
		for _, id in Classes.order do
			if string.lower(id) == string.lower(arg or "") then
				class = id
			end
		end
		if not class then
			reply(player, "admin.usage.lb")
			return
		end
		if not LeaderboardService.HofClear(class) then
			reply(player, "admin.lb.notMock")
			return
		end
		reply(player, "admin.lb.hofCleared", { class = `@class.{class}.name` })
	end
end

return commands
