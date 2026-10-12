--!strict
-- Admin commands: character (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Config = require(Shared.Config)
local DevPreset = require(Shared.Logic.DevPreset)
local Elements = require(Shared.Data.Elements)
local Items = require(Shared.Data.Items)
local PathData = require(Shared.Data.Paths)

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
local PathService = Context.services.PathService

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

-- S28: /nocd [on|off]: no cooldowns and no costs together.
commands.nocd = function(player, args)
	local on = args[1] ~= "off"
	SkillService.SetNoCooldowns(player, on)
	SkillService.SetInfiniteResources(player, on)
	reply(player, if on then "admin.nocd.on" else "admin.nocd.off")
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

-- S57: class paths -----------------------------------------------------------------------------------------------

commands.path = function(player, args)
	local id = args[1]
	if not id then
		reply(player, "admin.usage.path")
		return
	end
	withCharacter(player, function()
		local pathId = if string.lower(id) == "none" then nil else id
		local ok = PathService.AdminSetMain(player, pathId)
		if not ok then
			reply(player, "admin.path.unknown", { id = id })
			return
		end
		local path = if pathId then PathData.get(pathId) else nil
		if path then
			reply(player, "admin.path.ok", { path = "@" .. path.nameKey })
		else
			reply(player, "paths.mainNone")
		end
	end)
end

commands.node = function(player, args)
	local id = args[1]
	local rank = if args[2] then tonumber(args[2]) else nil
	if not id or (args[2] and rank == nil) then
		reply(player, "admin.usage.node")
		return
	end
	withCharacter(player, function()
		if not PathService.AdminSetNode(player, id, rank) then
			reply(player, "admin.node.unknown", { id = id })
			return
		end
		local now = PlayerStateService.Get(player, { "character", "path", "nodes", id }) or 0
		reply(player, "admin.node.ok", { id = id, rank = now })
	end)
end

commands.pathmax = function(player, args)
	withCharacter(player, function()
		local bought, err = PathService.AdminMax(player, args[1])
		if err == "admin.path.unknown" then
			reply(player, err, { id = args[1] })
			return
		end
		local main = PlayerStateService.Get(player, { "character", "path", "main" })
		if bought == 0 and main == nil then
			reply(player, "admin.pathmax.noPath")
			return
		end
		reply(player, "admin.pathmax.ok", { bought = bought })
	end)
end

commands.bp = function(player, args)
	local skillId, rank, option = args[1], tonumber(args[2]), args[3]
	if not skillId or (rank ~= 5 and rank ~= 10) or (option ~= "a" and option ~= "b") then
		reply(player, "admin.usage.bp")
		return
	end
	withCharacter(player, function()
		local ok, err = PathService.AdminChooseBp(player, skillId, rank :: number, option)
		if not ok then
			reply(player, err or "admin.usage.bp")
			return
		end
		reply(player, "admin.bp.ok", { key = `{skillId}:{rank}`, option = string.upper(option) })
	end)
end

commands.resetskills = function(player)
	withCharacter(player, function()
		PathService.AdminReset(player)
		reply(player, "admin.resetskills.ok")
	end)
end

-- S58: /buildset <1|2|copy> (ROZWOJ 3.3): everywhere, no place, combat, death or cooldown checks.
commands.buildset = function(player, args)
	local action = args[1]
	if action ~= "1" and action ~= "2" and action ~= "copy" then
		reply(player, "admin.usage.buildset")
		return
	end
	withCharacter(player, function()
		local slot = if PlayerStateService.Get(player, { "character", "buildSlot" }) == 2 then 2 else 1
		if action == "copy" then
			PathService.AdminCopy(player)
			reply(player, "admin.buildset.copied", { from = slot, to = 3 - slot })
		elseif tonumber(action) == slot then
			reply(player, "admin.buildset.same", { n = slot })
		else
			PathService.AdminSwitch(player)
			reply(player, "admin.buildset.ok", { n = 3 - slot })
		end
	end)
end

return commands
