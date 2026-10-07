--!strict
-- Admin commands: monsters (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Bosses = require(Shared.Data.Bosses)
local Anatomy = require(Shared.Logic.Anatomy)
local Classes = require(Shared.Data.Classes)
local Cosmetics = require(Shared.Data.Cosmetics)
local LookAnim = require(Shared.Logic.LookAnim)
local MonsterLooks = require(Shared.Data.MonsterLooks)
local Net = require(Shared.Net)
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

-- S28: /dummy [level]: a training dummy in front of you (no AI, no attacks, huge HP, removed after 10 minutes).
local DUMMY_KIND = "bandit"
local DUMMY_SECONDS = 600
commands.dummy = function(player, args)
	withCharacter(player, function()
		local model = player.Character
		local char = Context.services.PlayerStateService.GetCharacter(player)
		if not model or not char then
			return
		end
		local level = math.clamp(parseAmount(args[1]) or char.level, 1, Config.MaxLevel)
		local at = model:GetPivot() * CFrame.new(0, 0, -10)
		local monster =
			MonsterService.SpawnAt(DUMMY_KIND, "normal", level, CFrame.lookAt(at.Position, model:GetPivot().Position))
		if not monster then
			return
		end
		local m: any = monster
		m.dummy = true
		m.stats.maxHp = 1e9
		m.hp = 1e9
		m.model:SetAttribute("Hp", 1e9)
		m.model:SetAttribute("MaxHp", 1e9)
		m.model:SetAttribute("Dummy", true)
		m.humanoid.WalkSpeed = 0
		task.delay(DUMMY_SECONDS, function()
			if m.model.Parent and m:IsAlive() then
				MonsterService.Despawn(m)
			end
		end)
		reply(player, "admin.dummy.ok", { level = level })
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

-- Looks (S24) -------------------------------------------------------------------------------------------

local VIZ_GROUPS = { all = true, bosses = true, pets = true, ["1"] = true, ["2"] = true, ["3"] = true, ["4"] = true }
local VIZ_VARIANTS = { normal = true, elite = true, elite2 = true }

local function isPet(id: string): boolean
	local def = Cosmetics.get(id)
	return def ~= nil and def.kind == "pet"
end

commands.mobviz = function(player, args)
	local target = args[1] and string.lower(args[1]) or nil
	if not target then
		reply(player, "admin.usage.mobviz")
		return
	end
	if target == "clear" then
		Net.Fire(player, "MobViz", "clear")
		reply(player, "admin.mobviz.cleared")
		return
	end
	local id = args[1] :: string
	if string.sub(target, 1, 6) == "region" then
		target = string.sub(target, 7)
	end
	if not VIZ_GROUPS[target] and not MonsterLooks.has(id) and not isPet(id) then
		reply(player, "admin.mobviz.unknown", { id = id })
		return
	end
	local variant = "normal"
	local anim = false
	for i = 2, 3 do
		local option = args[i] and string.lower(args[i])
		if option == "anim" then
			anim = true
		elseif option and VIZ_VARIANTS[option] then
			variant = option
		elseif option then
			reply(player, "admin.usage.mobviz")
			return
		end
	end
	Net.Fire(player, "MobViz", "show", {
		target = if VIZ_GROUPS[target] then target else id,
		variant = variant,
		anim = anim,
	})
	reply(player, "admin.mobviz.ok", { target = if VIZ_GROUPS[target] then target else id, variant = variant })
end

commands.look = function(player, args)
	local id = args[1]
	local look: any = id and MonsterLooks.get(id)
	local variant = "normal"
	local scale = 1
	if id and not look and isPet(id) then
		look = (Cosmetics.get(id) :: any).look
		variant = "pet"
		scale = Cosmetics.PET_SCALE
	elseif look then
		local def = Monsters.get(id :: string)
		local boss = Bosses.get(id :: string)
		scale = if def then def.size elseif boss then boss.look.size else 1
		variant = if boss then "boss" else "normal"
	end
	if not id or not look then
		reply(player, "admin.mobviz.unknown", { id = tostring(id) })
		return
	end
	local rig = Anatomy.build(look, { id = id :: string, variant = variant, scale = scale })
	local asset = look.asset
	local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(if variant == "pet" then "Pets" else "Monsters")
	local modelName = if asset then asset.model else id
	local present = folder ~= nil and folder:FindFirstChild(modelName :: string) ~= nil
	local missing = {}
	if asset and asset.rig == "animator" then
		for _, slot in LookAnim.SLOTS do
			if not (asset.anims and asset.anims[slot]) then
				table.insert(missing, slot)
			end
		end
	end
	local size = rig.root.size
	reply(player, "admin.look.info", {
		id = id,
		plan = look.plan,
		parts = #rig.pieces,
		root = string.format("%.1f × %.1f × %.1f", size[1], size[2], size[3]),
		hip = string.format("%.2f", rig.hipHeight),
		height = string.format("%.1f", rig.height),
		model = if present then "✔" else "✘",
		missing = if #missing > 0 then table.concat(missing, ", ") else "-",
	})
end

commands.lookstats = function(player)
	Net.Fire(player, "MobViz", "stats")
end

return commands
