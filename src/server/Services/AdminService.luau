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
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)

local log = Log.new("AdminService")

local AdminService = {
	Name = "AdminService",
	Deps = {
		"DataService",
		"PlayerStateService",
		"CharacterService",
		"NameService",
		"LevelService",
		"ResourceService",
		"DeathService",
		"PvpService",
		"MonetizationService",
		"MonsterService",
		"CombatService",
		"EntityService",
	},
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local NameService: any
local LevelService: any
local ResourceService: any
local DeathService: any
local PvpService: any
local MonetizationService: any
local MonsterService: any
local CombatService: any
local EntityService: any

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

-- Runs `fn` only when the caller is in the world with a character.
local function withCharacter(player: Player, fn: () -> ())
	if PlayerStateService.GetCharacter(player) == nil then
		reply(player, "admin.needCharacter")
		return
	end
	fn()
end

COMMANDS.lvl = {
	usageKey = "admin.usage.lvl",
	run = function(player, args)
		local level = parseAmount(args[1])
		if level == nil or level < 1 then
			reply(player, "admin.usage.lvl")
			return
		end
		withCharacter(player, function()
			LevelService.SetLevel(player, level)
			reply(player, "admin.lvl.ok", { level = PlayerStateService.Get(player, { "character", "level" }) })
		end)
	end,
}

COMMANDS.exp = {
	usageKey = "admin.usage.exp",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil or amount <= 0 then
			reply(player, "admin.usage.exp")
			return
		end
		withCharacter(player, function()
			local levels = LevelService.GiveExp(player, amount, "admin")
			reply(player, "admin.exp.ok", { amount = amount, levels = levels })
		end)
	end,
}

COMMANDS.stats = {
	usageKey = "admin.usage.stats",
	run = function(player, args)
		if args[1] ~= "reset" then
			reply(player, "admin.usage.stats")
			return
		end
		withCharacter(player, function()
			LevelService.ResetStats(player)
			reply(player, "admin.stats.ok")
		end)
	end,
}

COMMANDS.heal = {
	usageKey = "admin.usage.heal",
	run = function(player)
		withCharacter(player, function()
			if ResourceService.IsDead(player) then
				reply(player, "admin.heal.dead")
				return
			end
			ResourceService.Restore(player)
			reply(player, "admin.heal.ok")
		end)
	end,
}

COMMANDS.god = {
	usageKey = "admin.usage.god",
	run = function(player)
		withCharacter(player, function()
			local enabled = not ResourceService.IsGod(player)
			ResourceService.SetGod(player, enabled)
			reply(player, if enabled then "admin.god.on" else "admin.god.off")
		end)
	end,
}

COMMANDS.hurt = {
	usageKey = "admin.usage.hurt",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil or amount <= 0 then
			reply(player, "admin.usage.hurt")
			return
		end
		withCharacter(player, function()
			local dealt = ResourceService.Damage(player, amount, "admin")
			reply(player, "admin.hurt.ok", { amount = math.floor(dealt) })
		end)
	end,
}

COMMANDS.kill = {
	usageKey = "admin.usage.kill",
	run = function(player, args: { string })
		withCharacter(player, function()
			if args[1] == "me" then
				DeathService.Kill(player)
				return
			end
			local target = CombatService.GetTarget(player)
			if not target then
				reply(player, "admin.kill.noTarget")
			elseif target.kind == "monster" then
				target.monster:TakeDamage(target.monster.hp + 1, player)
			elseif target.player then
				DeathService.Kill(target.player)
			end
		end)
	end,
}

COMMANDS.pvp = {
	usageKey = "admin.usage.pvp",
	run = function(player, args)
		local mode = args[1]
		if mode ~= "on" and mode ~= "off" then
			reply(player, "admin.usage.pvp")
			return
		end
		withCharacter(player, function()
			PvpService.Force(player, mode == "on")
			reply(player, if mode == "on" then "admin.pvp.on" else "admin.pvp.off")
		end)
	end,
}

COMMANDS.tp = {
	usageKey = "admin.usage.tp",
	run = function(player, args)
		local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		if x == nil or y == nil or z == nil then
			reply(player, "admin.usage.tp")
			return
		end
		withCharacter(player, function()
			local model = player.Character
			if model then
				model:PivotTo(CFrame.new(x :: number, y :: number, z :: number))
				reply(player, "admin.tp.ok", { x = x, y = y, z = z })
			end
		end)
	end,
}

COMMANDS.pass = {
	usageKey = "admin.usage.pass",
	run = function(player, args)
		local passId = args[1]
		if passId == nil or (args[2] ~= "on" and args[2] ~= "off") then
			reply(player, "admin.usage.pass")
			return
		end
		MonetizationService.SetTestPass(player, passId, args[2] == "on")
		reply(player, "admin.pass.ok", { pass = passId, state = args[2] })
	end,
}

local VARIANTS = { [0] = "normal", [1] = "elite", [2] = "elite2" }

COMMANDS.spawn = {
	usageKey = "admin.usage.spawn",
	run = function(player, args)
		local monsterId = args[1]
		if not monsterId then
			reply(player, "admin.usage.spawn")
			return
		end
		local def = Monsters.get(monsterId)
		if not def then
			reply(player, "admin.spawn.unknown", { id = monsterId })
			return
		end
		local variant = VARIANTS[tonumber(args[2]) or 0] or "normal"
		local level = math.clamp(parseAmount(args[3]) or def.levels.min, 1, Config.MaxLevel)
		withCharacter(player, function()
			local model = player.Character
			if not model then
				return
			end
			local at = model:GetPivot() * CFrame.new(0, 0, -12)
			local monster = MonsterService.SpawnAt(monsterId, variant, level, CFrame.new(at.Position))
			if monster then
				reply(player, "admin.spawn.ok", { name = "@" .. monster:Name(), level = monster.stats.level })
			end
		end)
	end,
}

COMMANDS.killall = {
	usageKey = "admin.usage.killall",
	run = function(player, args)
		local radius = math.clamp(parseAmount(args[1]) or 100, 1, 2000)
		withCharacter(player, function()
			local model = player.Character
			if not model then
				return
			end
			local count = 0
			for _, entity in EntityService.QueryMonsters(model:GetPivot().Position, radius) do
				local monster = entity.monster
				if monster and monster:IsAlive() then
					monster.invulnerable = false
					monster:TakeDamage(monster.hp + 1, player)
					count += 1
				end
			end
			reply(player, "admin.killall.ok", { count = count })
		end)
	end,
}

COMMANDS.target = {
	usageKey = "admin.usage.target",
	run = function(player, args)
		if args[1] ~= "info" then
			reply(player, "admin.usage.target")
			return
		end
		local target = CombatService.GetTarget(player)
		if not target then
			reply(player, "admin.target.none")
			return
		end
		if target.kind == "monster" then
			local m = target.monster
			reply(player, "admin.target.info", {
				name = "@" .. m:Name(),
				level = m.stats.level,
				hp = math.ceil(m.hp),
				maxHp = m.stats.maxHp,
				atk = math.floor(m.stats.attack),
				armor = math.floor(m.stats.armor),
				mres = math.floor(m.stats.mres),
			})
		else
			local other = target.player
			local character = other and PlayerStateService.GetCharacter(other)
			local derived = other and PlayerStateService.Get(other, { "derived", "values" })
			if character and derived then
				reply(player, "admin.target.info", {
					name = character.name,
					level = character.level,
					hp = character.hp,
					maxHp = math.floor(derived.maxHp),
					atk = math.floor(derived.physAtk),
					armor = math.floor(derived.armor),
					mres = math.floor(derived.mres),
				})
			end
		end
	end,
}

COMMANDS.dmg = {
	usageKey = "admin.usage.dmg",
	run = function(player, args)
		if args[1] == "off" then
			CombatService.SetDamageOverride(player, nil)
			reply(player, "admin.dmg.off")
			return
		end
		local amount = parseAmount(args[1])
		if amount == nil or amount <= 0 then
			reply(player, "admin.usage.dmg")
			return
		end
		CombatService.SetDamageOverride(player, amount)
		reply(player, "admin.dmg.on", { amount = amount })
	end,
}

COMMANDS.monsters = {
	usageKey = "admin.usage.monsters",
	run = function(player)
		local active, sleeping, spawners, awake = MonsterService.Stats()
		reply(
			player,
			"admin.monsters.info",
			{ active = active, sleeping = sleeping, spawners = spawners, awake = awake }
		)
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
	LevelService = registry.Get("LevelService")
	ResourceService = registry.Get("ResourceService")
	DeathService = registry.Get("DeathService")
	PvpService = registry.Get("PvpService")
	MonetizationService = registry.Get("MonetizationService")
	MonsterService = registry.Get("MonsterService")
	CombatService = registry.Get("CombatService")
	EntityService = registry.Get("EntityService")
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
