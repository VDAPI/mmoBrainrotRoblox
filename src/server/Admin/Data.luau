--!strict
-- Admin commands: data (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared

local AccountSchema = require(Shared.Logic.AccountSchema)
local AdminCommands = require(Shared.Data.AdminCommands)

local Context = require(script.Parent.Context)

local reply = Context.reply
local log = Context.log

local DataService = Context.services.DataService
local PlayerStateService = Context.services.PlayerStateService
local CharacterService = Context.services.CharacterService
local NameService = Context.services.NameService

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

return commands
