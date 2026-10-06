--!strict
-- Admin commands: perf (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared

local Net = require(Shared.Net)

local Context = require(script.Parent.Context)

local reply = Context.reply

local MonsterService = Context.services.MonsterService
local EntityService = Context.services.EntityService
local LootService = Context.services.LootService
local WorldService = Context.services.WorldService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.perf = function(player)
	local stats = game:GetService("Stats")
	local heartbeat = 0
	pcall(function()
		heartbeat = (stats :: any).HeartbeatTimeMs
	end)
	local active, sleeping = MonsterService.Stats()
	reply(player, "admin.perf", {
		players = #Players:GetPlayers(),
		monsters = EntityService.CountMonsters(),
		active = active,
		sleeping = sleeping,
		bags = LootService.BagCount(),
		memory = math.floor(stats:GetTotalMemoryUsageMb()),
		heartbeat = string.format("%.1f", heartbeat),
		fps = math.floor(workspace:GetRealPhysicsFPS()),
	})
	-- Parts per map (S20) and the client's decoration chunks / frame time.
	local counts = {}
	for mapId, n in WorldService.PartCounts() do
		table.insert(counts, `{mapId} {n}`)
	end
	table.sort(counts)
	reply(player, "admin.perf.parts", { list = table.concat(counts, ", ") })
	Net.Fire(player, "AdminClient", "perf")
end

-- S23: the last admin calls (newest first).
commands.adminlog = function(player, args)
	local n = math.clamp(tonumber(args[1]) or 20, 1, 200)
	local entries = Context.services.AdminService.Audit(n)
	if #entries == 0 then
		reply(player, "admin.adminlog.empty")
		return
	end
	for _, entry in entries do
		reply(player, "admin.adminlog.line", {
			time = os.date("!%H:%M:%S", entry.t),
			user = entry.user,
			command = entry.command,
			args = entry.args,
			ok = if entry.ok then "✔" else "✖",
		})
	end
end

return commands
