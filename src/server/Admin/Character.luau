--!strict
-- Admin commands: character (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Config = require(Shared.Config)
local DevPreset = require(Shared.Logic.DevPreset)
local Elements = require(Shared.Data.Elements)
local Items = require(Shared.Data.Items)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount

local PlayerStateService = Context.services.PlayerStateService
local LevelService = Context.services.LevelService
local ResourceService = Context.services.ResourceService
local InventoryService = Context.services.InventoryService
local EquipmentService = Context.services.EquipmentService
local StatService = Context.services.StatService
local SkillService = Context.services.SkillService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

commands.lvl = function(player, args)
	local level = parseAmount(args[1])
	if level == nil or level < 1 then
		reply(player, "admin.usage.lvl")
		return
	end
	withCharacter(player, function()
		LevelService.SetLevel(player, level)
		reply(player, "admin.lvl.ok", { level = PlayerStateService.Get(player, { "character", "level" }) })
	end)
end

commands.exp = function(player, args)
	local amount = parseAmount(args[1])
	if amount == nil or amount <= 0 then
		reply(player, "admin.usage.exp")
		return
	end
	withCharacter(player, function()
		local levels = LevelService.GiveExp(player, amount, "admin")
		reply(player, "admin.exp.ok", { amount = amount, levels = levels })
	end)
end

commands.stats = function(player, args)
	if args[1] ~= "reset" then
		reply(player, "admin.usage.stats")
		return
	end
	withCharacter(player, function()
		LevelService.ResetStats(player)
		reply(player, "admin.stats.ok")
	end)
end

commands.heal = function(player)
	withCharacter(player, function()
		if ResourceService.IsDead(player) then
			reply(player, "admin.heal.dead")
			return
		end
		ResourceService.Restore(player)
		reply(player, "admin.heal.ok")
	end)
end

commands.god = function(player)
	withCharacter(player, function()
		local enabled = not ResourceService.IsGod(player)
		ResourceService.SetGod(player, enabled)
		reply(player, if enabled then "admin.god.on" else "admin.god.off")
	end)
end

commands.sprint = function(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	reply(player, "admin.sprint.info", {
		on = if StatService.IsSprinting(player) then "ON" else "OFF",
		speed = if humanoid then string.format("%.1f", humanoid.WalkSpeed) else "-",
	})
end

commands.skillpoints = function(player, args)
	local n = parseAmount(args[1])
	if n == nil then
		reply(player, "admin.usage.skillpoints")
		return
	end
	withCharacter(player, function()
		PlayerStateService.Update(player, { "character", "skillPoints" }, function(current: number)
			return math.max(0, current + n)
		end)
		reply(player, "admin.skillpoints.ok", { n = n })
	end)
end

commands.skills = function(player, args)
	if args[1] == "reset" then
		withCharacter(player, function()
			SkillService.Reset(player, true)
			reply(player, "skills.reset.done")
		end)
		return
	end
	if args[1] ~= "max" then
		reply(player, "admin.usage.skills")
		return
	end
	withCharacter(player, function()
		reply(player, "admin.skills.ok", { points = SkillService.LearnAll(player) })
	end)
end

commands.cd = function(player, args)
	if args[1] ~= "off" and args[1] ~= "on" then
		reply(player, "admin.usage.cd")
		return
	end
	SkillService.SetNoCooldowns(player, args[1] == "off")
	reply(player, if args[1] == "off" then "admin.cd.off" else "admin.cd.on")
end

commands.res = function(player, args)
	if args[1] ~= "inf" and args[1] ~= "off" then
		reply(player, "admin.usage.res")
		return
	end
	SkillService.SetInfiniteResources(player, args[1] == "inf")
	reply(player, if args[1] == "inf" then "admin.res.on" else "admin.res.off")
end

-- S23 -------------------------------------------------------------------------------------------------

commands.statpoints = function(player, args)
	local n = parseAmount(args[1])
	if n == nil or n < 0 then
		reply(player, "admin.usage.statpoints")
		return
	end
	withCharacter(player, function()
		PlayerStateService.Set(player, { "character", "statPoints" }, n)
		reply(player, "admin.statpoints.ok", { n = n })
	end)
end

commands.speed = function(player, args)
	local value = args[1]
	if value == "off" then
		StatService.SetSpeedOverride(player, nil)
		reply(player, "admin.speed.off")
		return
	end
	local speed = tonumber(value)
	if not speed or speed ~= speed or speed < 1 or speed > 300 then
		reply(player, "admin.usage.speed")
		return
	end
	StatService.SetSpeedOverride(player, speed)
	reply(player, "admin.speed.ok", { speed = speed })
end

-- Level + the full gear set of the character's class at that level (Logic/DevPreset), rolled at `rarity` with
-- upgrade `up`, equipped through the normal Equip path (old pieces go to the backpack).
commands.preset = function(player, args)
	local level = parseAmount(args[1])
	local rarity = parseAmount(args[2])
	local up = math.clamp(parseAmount(args[3]) or 0, 0, 9)
	if not level or not rarity then
		reply(player, "admin.usage.preset")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		LevelService.SetLevel(player, math.clamp(level, 1, Config.MaxLevel))
		local tier = Items.generate.tierFor(level)
		local equipped = 0
		for _, piece in DevPreset.pick(character.class, level) do
			local leftover, item = InventoryService.GiveNew(player, piece.id, 1, math.clamp(rarity, 1, 5), tier)
			if leftover > 0 or not item then
				reply(player, "inventory.full")
				break
			end
			local def = Items.get(piece.id)
			item.up = up
			if def and def.elemental and item.el == nil then
				item.el = Elements.DEFAULT
			end
			local index = InventoryService.IndexOf(player, item.uid)
			if index then
				InventoryService.SetSlot(player, index, item)
				local ok = EquipmentService.Equip(player, index, piece.slot)
				if ok then
					equipped += 1
				end
			end
		end
		reply(player, "admin.preset.ok", { level = level, rarity = rarity, up = up, n = equipped })
	end)
end

return commands
