--!strict
-- Admin commands: monsters (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Classes = require(Shared.Data.Classes)
local Config = require(Shared.Config)
local Damage = require(Shared.Logic.Damage)
local Monsters = require(Shared.Data.Monsters)
local MonsterStats = require(Shared.Logic.MonsterStats)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount
local VARIANTS = Context.VARIANTS

local PlayerStateService = Context.services.PlayerStateService
local MonsterService = Context.services.MonsterService
local CombatService = Context.services.CombatService
local EntityService = Context.services.EntityService
local StatService = Context.services.StatService
local DungeonService = Context.services.DungeonService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.spawn = function(player, args)
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
end

commands.killall = function(player, args)
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
end

commands.monsters = function(player)
	local active, sleeping, spawners, awake = MonsterService.Stats()
	reply(player, "admin.monsters.info", { active = active, sleeping = sleeping, spawners = spawners, awake = awake })
end

commands.mstats = function(player, args)
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player) :: any
		local level = parseAmount(args[1]) or character.level
		level = math.clamp(level, 1, Config.MaxLevel)
		local monster = MonsterStats.compute({ hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }, level)
		local values = (StatService.Get(player) or { values = {} }).values
		local class = Classes.get(character.class)
		local magic = class ~= nil and class.basicAttack.kind == "magic"
		local attack = if magic then values.magAtk or 0 else values.physAtk or 0
		local defense = if magic then monster.mres else monster.armor
		local perHit = attack * (1 - Damage.reduction(defense, character.level))
		local dps = perHit * math.max(0.2, values.atkSpeed or 1)
		local hit = monster.attack * (1 - Damage.reduction(values.armor or 0, level))
		reply(player, "admin.mstats.info", {
			level = level,
			hp = monster.maxHp,
			atk = math.floor(monster.attack + 0.5),
			hit = math.floor(hit + 0.5),
			interval = monster.attackInterval,
			seconds = if dps > 0 then string.format("%.1f", monster.maxHp / dps) else "∞",
		})
	end)
end

commands.groups = function(player)
	local character = PlayerStateService.GetCharacter(player)
	local mapId = character and character.location.map or nil
	local total, sizes, active = MonsterService.GroupStats(mapId)
	reply(player, "admin.groups.info", {
		map = mapId or "?",
		total = total,
		s1 = sizes[1],
		s2 = sizes[2],
		s3 = sizes[3],
		s4 = sizes[4],
		active = active,
	})
end

commands.e2 = function(player, args)
	if args[1] ~= "spawn" then
		reply(player, "admin.usage.e2")
		return
	end
	local character = PlayerStateService.GetCharacter(player)
	local mapId = character and character.location.map or ""
	if MonsterService.RespawnElite2(mapId) then
		reply(player, "admin.e2.ok")
	else
		reply(player, "admin.e2.none")
	end
end

commands.e2timer = function(player)
	local character = PlayerStateService.GetCharacter(player)
	local timers = character and character.e2timers or {}
	if #timers == 0 then
		reply(player, "admin.e2timer.none")
		return
	end
	local now = workspace:GetServerTimeNow()
	for _, timer in timers do
		reply(player, "admin.e2timer.entry", {
			kind = timer.kind,
			map = timer.map,
			from = math.max(0, math.floor(timer.from - now)),
			to = math.max(0, math.floor(timer.to - now)),
			job = if timer.job == game.JobId then "this" else "other",
		})
	end
end

commands.boss = function(player, args)
	if args[1] == "reset" then
		withCharacter(player, function()
			DungeonService.ResetAll(player)
			reply(player, "admin.boss.reset")
		end)
	elseif args[1] == "spawn" and args[2] then
		withCharacter(player, function()
			if DungeonService.ForceStart(player, args[2]) then
				reply(player, "admin.boss.spawn", { boss = args[2] })
			else
				reply(player, "admin.usage.boss")
			end
		end)
	else
		reply(player, "admin.usage.boss")
	end
end

commands.phase = function(player, args)
	local phase = tonumber(args[1])
	if not phase or not DungeonService.ForcePhase(player, math.floor(phase)) then
		reply(player, "admin.usage.phase")
		return
	end
	reply(player, "admin.phase.ok", { phase = phase })
end

commands.leash = function(player)
	local target = CombatService.GetTarget(player)
	local monster = target and target.kind == "monster" and target.monster
	if not monster then
		reply(player, "admin.kill.noTarget")
		return
	end
	local home = monster.home or monster.spawnCFrame.Position
	local offset = monster.root.Position - home
	local since = os.clock() - monster.lastHit
	reply(player, "admin.leash.info", {
		state = monster.state,
		distance = math.floor(Vector3.new(offset.X, 0, offset.Z).Magnitude),
		since = if monster.lastHit > 0 then string.format("%.1f", since) else "-",
		hp = math.ceil(monster.hp),
		max = monster.stats.maxHp,
		boss = tostring(monster.isBoss == true),
	})
end

return commands
