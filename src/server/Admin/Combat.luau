--!strict
-- Admin commands: combat (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Config = require(Shared.Config)
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

return commands
