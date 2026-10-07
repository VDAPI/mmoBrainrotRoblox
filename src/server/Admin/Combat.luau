--!strict
-- Admin commands: combat (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Classes = require(Shared.Data.Classes)
local Config = require(Shared.Config)
local FightSim = require(Shared.Logic.FightSim)
local Monsters = require(Shared.Data.Monsters)
local Net = require(Shared.Net)

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
local StatService = Context.services.StatService
local EquipmentService = Context.services.EquipmentService

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

-- S32: the player as Logic/FightSim sees them (current stats, legendary effects, class attack kind).
local function simPlayer(player: Player, character: any): FightSim.Player
	local values = (StatService.Get(player) or { values = {} }).values
	local class = Classes.get(character.class)
	return {
		level = character.level,
		values = values,
		hooks = EquipmentService.GetHooks(player),
		magic = class ~= nil and class.basicAttack.kind == "magic",
	}
end

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

return commands
