--!strict
-- Chat commands for admins (Config.AdminUserIds) and everyone in Studio. Each command is a
-- TextChatCommand so the text never shows up in public chat. Replies go to the caller's system channel.
-- Add commands to COMMANDS; every session extends this list with tools for testing its features.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local AccountSchema = require(Shared.Logic.AccountSchema)
local Config = require(Shared.Config)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)

local log = Log.new("AdminService")

local AdminService = {
	Name = "AdminService",
	Deps = { "DataService", "PlayerStateService", "CharacterService", "NameService" },
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local NameService: any

type Command = {
	usageKey: string,
	run: (player: Player, args: { string }) -> (),
}

local WIPE_CONFIRM_SECONDS = 30
local MAX_AMOUNT = 1e12
local wipeRequests: { [Player]: number } = {}

local function reply(player: Player, key: string, args: { [string]: any }?)
	Net.Fire(player, "SystemMessage", key, args)
end

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
end

local function parseAmount(text: string?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or math.abs(n) > MAX_AMOUNT then
		return nil
	end
	return math.floor(n)
end

local COMMANDS: { [string]: Command } = {}

COMMANDS.help = {
	usageKey = "admin.usage.help",
	run = function(player)
		local names = {}
		for name in COMMANDS do
			table.insert(names, name)
		end
		table.sort(names)
		reply(player, "admin.help.header")
		for _, name in names do
			reply(player, COMMANDS[name].usageKey)
		end
	end,
}

COMMANDS.gold = {
	usageKey = "admin.usage.gold",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil then
			reply(player, "admin.usage.gold")
			return
		end
		if PlayerStateService.GetCharacter(player) == nil then
			reply(player, "admin.needCharacter")
			return
		end
		local total = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return math.max(0, gold + amount)
		end)
		reply(player, "admin.gold.ok", { amount = amount, total = total })
	end,
}

COMMANDS.shards = {
	usageKey = "admin.usage.shards",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil then
			reply(player, "admin.usage.shards")
			return
		end
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
			return math.max(0, shards + amount)
		end)
		reply(player, "admin.shards.ok", { amount = amount, total = total })
	end,
}

COMMANDS.wipe = {
	usageKey = "admin.usage.wipe",
	run = function(player, args)
		local requestedAt = wipeRequests[player]
		local confirmed = args[1] == "confirm"
			and requestedAt ~= nil
			and os.clock() - requestedAt <= WIPE_CONFIRM_SECONDS
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
	end,
}

local function onCommand(name: string, textSource: TextSource, message: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player then
		return
	end
	if not AdminService.IsAdmin(player) then
		reply(player, "admin.denied")
		return
	end
	local parts = string.split(message, " ")
	local args = {}
	for i = 2, #parts do
		if parts[i] ~= "" then
			table.insert(args, parts[i])
		end
	end
	local command = COMMANDS[name]
	local ok, err = pcall(command.run :: any, player, args)
	if not ok then
		log:error("/%s failed: %s", name, tostring(err))
		reply(player, "admin.failed", { command = name })
	end
end

function AdminService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	NameService = registry.Get("NameService")
end

function AdminService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "AdminCommands"
	for name in COMMANDS do
		local command = Instance.new("TextChatCommand")
		command.Name = `Admin_{name}`
		command.PrimaryAlias = `/{name}`
		command.Triggered:Connect(function(textSource: TextSource, message: string)
			onCommand(name, textSource, message)
		end)
		command.Parent = folder
	end
	folder.Parent = TextChatService

	Players.PlayerRemoving:Connect(function(player)
		wipeRequests[player] = nil
	end)
end

return AdminService
