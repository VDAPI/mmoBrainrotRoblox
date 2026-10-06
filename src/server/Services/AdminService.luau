--!strict
-- Admin commands (S23): admins (Config.AdminUserIds) and everyone in Studio. One path for the chat and the dev
-- panel: AdminService.Run checks the rights, validates the arguments against Data/AdminCommands
-- (Logic/AdminArgs, catalogue ids resolved here), logs the call (audit, /adminlog) and runs the command from
-- its category module in src/server/Admin. From the chat (TextChatCommand "/name", never shown in public chat)
-- replies go to the caller's system channel; from the panel (remote AdminRun) they come back as result lines.
-- Players get the attribute "Admin" so the client shows the panel (visibility only; the server always checks).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local AdminArgs = require(Shared.Logic.AdminArgs)
local AdminCommands = require(Shared.Data.AdminCommands)
local Areas = require(Shared.Data.Areas)
local Blessings = require(Shared.Data.Blessings)
local Bosses = require(Shared.Data.Bosses)
local Config = require(Shared.Config)
local Items = require(Shared.Data.Items)
local Maps = require(Shared.Data.Maps)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local Products = require(Shared.Data.Products)
local Quests = require(Shared.Data.Quests)

local Context = require(script.Parent.Parent.Admin.Context)

local log = Context.log

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
		"InventoryService",
		"EquipmentService",
		"LootService",
		"StatService",
		"SkillService",
		"NpcService",
		"AlchemyService",
		"BlessingService",
		"GatherService",
		"FishingService",
		"WorldService",
		"TravelService",
		"DungeonService",
		"TradeService",
		"QuestService",
		"GuildService",
		"MailService",
		"AuctionService",
		"CosmeticService",
		"StatusEffectService",
	},
}

type Run = (player: Player, args: { string }) -> ...any

-- Command name -> implementation, collected from the category modules in Init.
local RUN: { [string]: Run } = {}
local MODULES = { "Character", "Items", "World", "Monsters", "Combat", "Quests", "Economy", "Guild", "Perf", "Data" }

-- Audit log (S23): the last AUDIT_SIZE calls, newest last.
export type AuditEntry = { t: number, user: string, command: string, args: string, ok: boolean }
local AUDIT_SIZE = 200
local audit: { AuditEntry } = {}

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
end

-- The last `n` audit entries, newest first (/adminlog).
function AdminService.Audit(n: number): { AuditEntry }
	local out = {}
	for i = #audit, math.max(1, #audit - n + 1), -1 do
		table.insert(out, audit[i])
	end
	return out
end

local function record(player: Player, name: string, args: { string }, ok: boolean)
	local text = table.concat(args, " ")
	log:info("%s /%s %s -> %s", player.Name, name, text, if ok then "ok" else "rejected")
	table.insert(audit, { t = os.time(), user = player.Name, command = name, args = text, ok = ok })
	if #audit > AUDIT_SIZE then
		table.remove(audit, 1)
	end
end

-- Player by exact name, display name or a unique name prefix (case-insensitive).
function AdminService.FindPlayer(text: string): Player?
	local wanted = string.lower(text)
	local prefix: Player? = nil
	local count = 0
	for _, other in Players:GetPlayers() do
		local name, display = string.lower(other.Name), string.lower(other.DisplayName)
		if name == wanted or display == wanted then
			return other
		end
		if string.sub(name, 1, #wanted) == wanted or string.sub(display, 1, #wanted) == wanted then
			prefix = other
			count += 1
		end
	end
	return if count == 1 then prefix else nil
end

local function areaExists(id: string): boolean
	for _, data in Areas.byMap do
		for _, area in data.areas do
			if area.id == id then
				return true
			end
		end
	end
	return false
end

local function passExists(key: string): boolean
	for _, pass in Products.passes do
		if pass.key == key then
			return true
		end
	end
	return false
end

-- Catalogue lookups for argument validation.
local RESOLVE: { [string]: (string) -> boolean } = {
	item = function(id)
		return Items.get(id) ~= nil
	end,
	monster = function(id)
		return Monsters.get(id) ~= nil
	end,
	map = function(id)
		return Maps.get(id) ~= nil
	end,
	area = areaExists,
	npc = function(id)
		return Npcs.get(id) ~= nil
	end,
	boss = function(id)
		return Bosses.get(id) ~= nil
	end,
	quest = function(id)
		return Quests.Main.get(id) ~= nil
	end,
	blessing = function(id)
		return Blessings.get(id) ~= nil
	end,
	pass = passExists,
	player = function(name)
		return AdminService.FindPlayer(name) ~= nil
	end,
}

local function resolve(kind: string, value: string): boolean
	local check = RESOLVE[kind]
	return check == nil or check(value)
end

-- Runs a command for `player` (chat or panel). Returns (ok, errorKey?, lines) where `lines` are the replies
-- collected when `collect` is set (panel); from the chat the replies go to the system channel as they come.
function AdminService.Run(
	player: Player,
	name: string,
	rawArgs: { string },
	collect: boolean?
): (boolean, string?, { Context.Line })
	local lines: { Context.Line } = {}
	if not AdminService.IsAdmin(player) then
		record(player, name, rawArgs, false)
		return false, "admin.denied", lines
	end
	local def = AdminCommands.get(name)
	local run = RUN[name]
	if not def or not run then
		record(player, name, rawArgs, false)
		return false, "admin.unknown", lines
	end
	if def.studioOnly and not RunService:IsStudio() then
		record(player, name, rawArgs, false)
		return false, "admin.studioOnly", lines
	end
	local valid, values, errKey, errArgs = AdminArgs.validate(def.args :: any, rawArgs, resolve)
	if not valid or not values then
		record(player, name, rawArgs, false)
		if collect then
			table.insert(lines, { key = errKey or "error.badRequest", args = errArgs })
			table.insert(lines, { key = def.usageKey })
		else
			Context.reply(player, errKey or "error.badRequest", errArgs)
			Context.reply(player, def.usageKey)
		end
		return false, errKey or "error.badRequest", lines
	end
	record(player, name, values, true)
	if collect then
		Context.capture(player, lines)
	end
	local okCall, result, resultErr = pcall(run, player, values)
	if collect then
		Context.capture(player, nil)
	end
	if not okCall then
		log:error("/%s failed: %s", name, tostring(result))
		if not collect then
			Context.reply(player, "admin.failed", { command = name })
		end
		return false, "admin.failed", lines
	end
	-- A command may report a failure by returning (false, errorKey).
	if result == false then
		return false, if type(resultErr) == "string" then resultErr else "admin.failed", lines
	end
	return true, nil, lines
end

local function onCommand(name: string, textSource: TextSource, message: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player then
		return
	end
	if not AdminService.IsAdmin(player) then
		Context.reply(player, "admin.denied")
		return
	end
	local parts = string.split(message, " ")
	local args = {}
	for i = 2, #parts do
		if parts[i] ~= "" then
			table.insert(args, parts[i])
		end
	end
	AdminService.Run(player, name, args, false)
end

-- AdminRun(name, args) from the dev panel: (ok, errorKey?, lines). Admin rights are checked every time.
local function onPanel(player: Player, name: string, raw: any): (boolean, string?, { Context.Line }?)
	local args = AdminArgs.sanitize(raw)
	if not args then
		return false, "error.badRequest", nil
	end
	if not AdminService.IsAdmin(player) then
		record(player, name, args, false)
		return false, "admin.denied", nil
	end
	local ok, err, lines = AdminService.Run(player, string.lower(name), args, true)
	return ok, err, lines
end

function AdminService.Init(registry)
	for _, serviceName in AdminService.Deps do
		Context.services[serviceName] = registry.Get(serviceName)
	end
	Context.services.AdminService = AdminService
	Context.isAdmin = AdminService.IsAdmin
	-- The modules read Context.services when required, so they are loaded only now.
	local folder = script.Parent.Parent:FindFirstChild("Admin")
	assert(folder, "AdminService: src/server/Admin missing")
	for _, moduleName in MODULES do
		local module = folder:FindFirstChild(moduleName)
		assert(module and module:IsA("ModuleScript"), `AdminService: Admin/{moduleName} missing`)
		local commands = (require :: any)(module) :: { [string]: Run }
		for name, run in commands do
			if RUN[name] then
				log:error("admin command /%s is defined twice", name)
			end
			RUN[name] = run
		end
	end
	-- Metadata and implementations must match (S23).
	for _, def in AdminCommands.list do
		if not RUN[def.name] then
			log:error("admin command /%s has metadata but no implementation", def.name)
		end
	end
	for name in RUN do
		if not AdminCommands.get(name) then
			log:error("admin command /%s has no metadata (Data/AdminCommands)", name)
		end
	end
end

function AdminService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "AdminCommands"
	for _, def in AdminCommands.list do
		if RUN[def.name] then
			local command = Instance.new("TextChatCommand")
			command.Name = `Admin_{def.name}`
			command.PrimaryAlias = `/{def.name}`
			command.Triggered:Connect(function(textSource: TextSource, message: string)
				onCommand(def.name, textSource, message)
			end)
			command.Parent = folder
		end
	end
	folder.Parent = TextChatService
	Net.Handle("AdminRun", onPanel)

	local function flag(player: Player)
		if AdminService.IsAdmin(player) then
			player:SetAttribute("Admin", true)
		end
	end
	for _, player in Players:GetPlayers() do
		flag(player)
	end
	Players.PlayerAdded:Connect(flag)
end

return AdminService
