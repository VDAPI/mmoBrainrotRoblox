--!strict
-- Admin commands: combat (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local BuffCategories = require(Shared.Data.BuffCategories)
local Combat = require(Shared.Data.Combat)
local Config = require(Shared.Config)
local FightSim = require(Shared.Logic.FightSim)
local LevelCurves = require(Shared.Logic.LevelCurves)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)
local PathData = require(Shared.Data.Paths)
local Paths = require(Shared.Logic.Paths)
local Potions = require(Shared.Logic.Potions)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount

local PlayerStateService = Context.services.PlayerStateService
local ResourceService = Context.services.ResourceService
local DeathService = Context.services.DeathService
local PvpService = Context.services.PvpService
local CombatService = Context.services.CombatService
local StatusEffectService = Context.services.StatusEffectService
local EntityService = Context.services.EntityService
local PartyService = Context.services.PartyService
local PartyAuraService = Context.services.PartyAuraService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.target = function(player, args)
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
		-- S66: family, defence trait and dodge of the monster.
		reply(player, "admin.target.family", {
			family = "@family." .. (m.def.family or "none"),
			defence = "@monsterDefence." .. (m.def.defence or "none") .. ".name",
			dodge = m.stats.dodge or 0,
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
end

commands.dmg = function(player, args)
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
end

commands.hurt = function(player, args)
	local amount = parseAmount(args[1])
	if amount == nil or amount <= 0 then
		reply(player, "admin.usage.hurt")
		return
	end
	withCharacter(player, function()
		local dealt = ResourceService.Damage(player, amount, "admin")
		reply(player, "admin.hurt.ok", { amount = math.floor(dealt) })
	end)
end

commands.kill = function(player, args: { string })
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
end

commands.pvp = function(player, args)
	local mode = if args[1] == "force" then args[2] else args[1]
	if mode ~= "on" and mode ~= "off" then
		reply(player, "admin.usage.pvp")
		return
	end
	withCharacter(player, function()
		PvpService.Force(player, mode == "on")
		reply(player, if mode == "on" then "admin.pvp.on" else "admin.pvp.off")
	end)
end

commands.die = function(player)
	withCharacter(player, function()
		-- DeathService.Kill removes the respawn protection first.
		DeathService.Kill(player)
	end)
end

commands.shield = function(player, args)
	local seconds = math.clamp(tonumber(args[1]) or Config.RespawnShieldSeconds, 1, 600)
	withCharacter(player, function()
		StatusEffectService.ApplyRespawnShield(player, seconds)
		reply(player, "admin.shield.ok", { seconds = seconds })
	end)
end

-- S61: the caller guards the targeted player, or without a player target every other party member within
-- Combat.interceptRadius. A share above the cap is allowed, so the cap shows when it is read.
commands.intercept = function(player, args)
	local share = math.clamp(tonumber(args[1]) or 30, 1, 100)
	local seconds = math.clamp(tonumber(args[2]) or 10, 1, 600)
	withCharacter(player, function()
		local allies: { Player } = {}
		local target = CombatService.GetTarget(player)
		if target and target.kind == "player" and target.player and target.player ~= player then
			table.insert(allies, target.player)
		else
			local entity = EntityService.GetPlayerEntity(player)
			local position = entity and EntityService.Position(entity)
			if position then
				for _, member in PartyService.MembersInRange(player, position, Combat.interceptRadius) do
					if member ~= player then
						table.insert(allies, member)
					end
				end
			end
		end
		local n = 0
		for _, ally in allies do
			local entity = EntityService.GetPlayerEntity(ally)
			if entity then
				StatusEffectService.Apply(entity, "intercept", {
					duration = seconds,
					value = share,
					source = player,
					radius = Combat.interceptRadius,
					skillId = "admin",
				})
				n += 1
			end
		end
		if n == 0 then
			reply(player, "admin.intercept.none", { radius = Combat.interceptRadius })
		else
			reply(player, "admin.intercept.ok", { n = n, share = share, seconds = seconds })
		end
	end)
end

-- S61: misfortune on the current target (monster or player).
commands.misfortune = function(player, args)
	local value = math.clamp(tonumber(args[1]) or 15, 1, 100)
	local seconds = math.clamp(tonumber(args[2]) or 10, 1, 600)
	withCharacter(player, function()
		local target = CombatService.GetTarget(player)
		if not target then
			reply(player, "admin.misfortune.noTarget")
			return
		end
		StatusEffectService.Apply(target, "misfortune", {
			duration = seconds,
			value = value,
			source = player,
			category = "enemyMiss",
			skillId = "admin",
		})
		reply(player, "admin.misfortune.ok", { value = value, seconds = seconds, cap = BuffCategories.caps.enemyMiss })
	end)
end

-- S61: an aura like a path node's (PartyAuraService.SetExtra, key "admin"); every stat of the category gets `value`.
commands.aura = function(player, args)
	withCharacter(player, function()
		local id = args[1]
		if id == "off" then
			PartyAuraService.SetExtra(player, "admin", nil)
			reply(player, "admin.aura.off")
			return
		end
		local category = BuffCategories.get(id)
		if not category or category.side ~= "ally" then
			reply(player, "admin.usage.aura")
			return
		end
		local value = math.clamp(tonumber(args[2]) or 10, 1, 100)
		local shape: "circle" | "behind" = if args[3] == "behind" then "behind" else "circle"
		local default = if shape == "behind" then PathData.AURA.behindRadius else PathData.AURA.radius
		local radius = math.clamp(tonumber(args[4]) or default, 1, PathData.AURA.maxRadius)
		local stats: { [string]: number } = {}
		if category.stats then
			for _, stat in category.stats do
				stats[stat] = value
			end
		else
			stats.value = value
		end
		local aura: Paths.Aura =
			{ nodeId = "admin_aura", category = category.id, stats = stats, shape = shape, radius = radius }
		PartyAuraService.SetExtra(player, "admin", aura)
		reply(player, "admin.aura.on", { category = category.id, value = value, shape = shape, radius = radius })
	end)
end

commands.anim = function(player, args)
	local kind = args[1]
	if not kind then
		reply(player, "admin.usage.anim")
		return
	end
	Net.Fire(player, "AdminClient", "anim", kind)
	reply(player, "admin.anim.ok", { kind = kind })
end

-- S28: /skillpreview <id>: the skill's animation and effect on your character (nothing is cast).
commands.skillpreview = function(player, args)
	local id = args[1] or ""
	Net.Fire(player, "AdminClient", "skillpreview", id)
	reply(player, "admin.skillpreview.ok", { id = id })
end

-- S29: /dmgtest: every kind of damage number in turn above the target (or above you), through the real
-- CombatFx batching, to judge the look. Nothing is dealt.
local DMGTEST_STEP = 0.45

commands.dmgtest = function(player)
	withCharacter(player, function()
		local me = EntityService.GetPlayerEntity(player)
		if not me then
			return
		end
		local target = CombatService.GetTarget(player) or me
		local other = "m-dmgtest" -- an attacker that is not us: "others' hits"
		local hit: { [string]: any } = { k = "dmg", e = target.id, s = me.id }
		local function with(extra: { [string]: any }): { [string]: any }
			local event = table.clone(hit)
			for key, value in extra do
				event[key] = value
			end
			return event
		end
		local steps: { { [string]: any } } = {
			with({ a = 128 }),
			with({ a = 1234, c = true }),
			with({ a = 312, sk = "mightyStrike" }),
			with({ a = 96, s = other }),
			with({ a = 240, s = other, c = true }),
			{ k = "dmg", e = me.id, s = other, a = 57 },
			{ k = "dmg", e = me.id, s = other, a = 204, c = true },
			with({ a = 0, ab = true }),
			with({ a = 0, im = true }),
			with({ a = 0, d = true }),
			{ k = "heal", e = me.id, s = me.id, a = 123 },
			{ k = "heal", e = me.id, s = me.id, a = 25, hot = true },
			with({ a = 18, dot = true, el = "fire" }),
			with({ a = 14, dot = true, el = "poison" }),
			with({ a = 11, dot = true, el = "bleed" }),
		}
		reply(player, "admin.dmgtest.ok")
		task.spawn(function()
			for _, event in steps do
				CombatService.QueueFx(EntityService.Position(event.e == me.id and me or target), event)
				task.wait(DMGTEST_STEP)
			end
			-- A burst faster than the merge rate: the numbers add up instead of piling.
			for _ = 1, 14 do
				CombatService.QueueFx(EntityService.Position(target), with({ a = 21 }))
				task.wait(0.05)
			end
		end)
	end)
end

local simPlayer: (player: Player, character: any) -> FightSim.Player = Context.simPlayer

local function percent(x: number): number
	return math.floor(x * 100 + 0.5)
end

local function seconds(x: number): string
	return string.format("%.1f", x)
end

-- /simfight <monster> <level> [n] [variant]: expected fight against a group of `n` with your current stats.
commands.simfight = function(player, args)
	local def = Monsters.get(args[1] or "")
	local level = parseAmount(args[2])
	local variant = args[4] or "normal"
	if not def or not level or (variant ~= "normal" and variant ~= "elite" and variant ~= "elite2") then
		reply(player, "admin.usage.simfight")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local p = simPlayer(player, character)
		local n = math.clamp(parseAmount(args[3]) or 1, 1, 4)
		local actual = if def.elites then variant else "normal"
		local members = FightSim.group(def, math.clamp(level, 1, Config.MaxLevel), n, actual :: any)
		local basic = FightSim.groupFight(p, members, 1)
		local skills = FightSim.groupFight(p, members, FightSim.SKILL_DPS)
		local m = members[1]
		reply(player, "admin.simfight.info", {
			name = `@{(def.nameKeys :: any)[actual] or def.nameKeys.normal}`,
			level = m.level,
			n = n,
			hp = m.maxHp,
			hit = math.floor(FightSim.hit(m, p) + 0.5),
			s1 = seconds(basic.seconds),
			l1 = percent(basic.hpLost),
			s2 = seconds(skills.seconds),
			l2 = percent(skills.hpLost),
		})
	end)
end

-- /balance: your character against the S32 targets at your level (DESIGN §15.1).
commands.balance = function(player)
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local p = simPlayer(player, character)
		local level = character.level
		local generic = { hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }
		local duel = FightSim.groupFight(p, FightSim.group(generic, level, 1), FightSim.SKILL_DPS)
		local groups = FightSim.expectedGroup(p, generic, level, FightSim.SKILL_DPS)
		local elite = FightSim.groupFight(p, FightSim.group(generic, level, 1, "elite"), FightSim.SKILL_DPS)
		reply(player, "admin.balance.info", {
			level = level,
			ds = seconds(duel.seconds),
			dl = percent(duel.hpLost),
			gl = percent(groups.hpLost),
			g4 = percent(groups.bySize[4].hpLost),
			es = seconds(elite.seconds),
			el = percent(elite.hpLost),
		})
		reply(player, "admin.balance.targets")
	end)
end

-- /curves [level]: every level curve (Data/LevelCurves), the DEX factor and the potion interval at a level
-- (yours by default), S54.
commands.curves = function(player, args)
	local function show(level: number)
		local L = math.clamp(level, 1, Config.MaxLevel)
		reply(player, "admin.curves.head", { level = L })
		for _, id in LevelCurves.ids() do
			reply(player, "admin.curves.line", { id = id, value = string.format("%.3f", LevelCurves.at(id, L)) })
		end
		reply(player, "admin.curves.derived", {
			dex = string.format("%.2f", LevelCurves.dexFactor(L)),
			dexLevel = LevelCurves.dexRatingLevel(),
			potion = string.format("%.1f", Potions.interval(L)),
		})
	end
	if args[1] ~= nil then
		local level = parseAmount(args[1])
		if not level then
			reply(player, "admin.usage.curves")
			return
		end
		show(level)
		return
	end
	withCharacter(player, function()
		show(PlayerStateService.GetCharacter(player).level)
	end)
end

return commands
