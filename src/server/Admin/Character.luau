--!strict
-- Admin commands: character (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local CharacterLook = require(Shared.Logic.CharacterLook)
local ClassLooks = require(Shared.Data.ClassLooks)
local Clock = require(Shared.Util.Clock)
local Config = require(Shared.Config)
local DevPreset = require(Shared.Logic.DevPreset)
local Elements = require(Shared.Data.Elements)
local FullElixir = require(Shared.Logic.FullElixir)
local Items = require(Shared.Data.Items)
local Luck = require(Shared.Logic.Luck)
local MountData = require(Shared.Data.Mounts)
local Mounts = require(Shared.Logic.Mounts)
local LuckData = require(Shared.Data.Luck)
local PartyBonus = require(Shared.Logic.PartyBonus)
local Time = require(Shared.Logic.Time)
local TitleData = require(Shared.Data.Titles)
local UseBlocks = require(Shared.Logic.UseBlocks)

local UseGuards = require(script.Parent.Parent.UseGuards)

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
local PartyService = Context.services.PartyService
local MountService = Context.services.MountService
local TitleService = Context.services.TitleService
local CosmeticService = Context.services.CosmeticService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

-- S125: a timed title for tests (0 days takes it away).
commands.timedtitle = function(player, args)
	local id = args[1] or ""
	local days = math.floor(tonumber(args[2]) or 7)
	local def = TitleData.get(id)
	if not def or def.req.kind ~= "timed" then
		reply(player, "admin.title.notTimed")
		return
	end
	withCharacter(player, function()
		if days <= 0 then
			TitleService.RemoveTimed(player, id)
			reply(player, "admin.title.removed", { id = id })
			return
		end
		local untilTs = math.floor(Clock.now()) + days * 86400
		TitleService.GrantTimed(player, id, untilTs)
		local year, month, day = Time.civil(untilTs)
		reply(player, "admin.title.timed", { id = id, ["until"] = string.format("%d-%02d-%02d", year, month, day) })
	end)
end

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

-- S122: the character's Elixir of Wholeness counter (Logic/FullElixir).
commands.elixir = function(player, args)
	withCharacter(player, function()
		local now = os.time()
		if args[1] == "reset" then
			PlayerStateService.Set(player, { "character", "fullElixir" }, table.clone(FullElixir.EMPTY))
			reply(player, "admin.elixir.reset")
		elseif args[1] == "info" then
			local state = PlayerStateService.Get(player, { "character", "fullElixir" })
			reply(player, "admin.elixir.info", {
				used = FullElixir.usedToday(state, now),
				max = Config.FullElixir.dailyLimit,
				ready = FullElixir.readyIn(state, now),
			})
		else
			reply(player, "admin.usage.elixir")
		end
	end)
end

-- S122: what blocks the elixir and the cloak for the caller right now (src/server/UseGuards) and what waits; S134d: Auto
-- Potions and Auto Hunt too (every UseBlocks feature).
commands.useblocks = function(player)
	local pending: { string } = {}
	for reason, session in UseBlocks.PENDING do
		table.insert(pending, `{reason} ({session})`)
	end
	table.sort(pending)
	for _, feature in UseBlocks.FEATURES do
		local list = UseBlocks.LISTS[feature]
		local active = UseGuards.active(player, list)
		reply(player, "admin.useblocks.line", {
			feature = feature,
			active = if #active > 0 then table.concat(active, ", ") else "-",
			pending = if #pending > 0 then table.concat(pending, ", ") else "-",
		})
	end
	for _, reason in UseBlocks.reasons() do
		local err = UseGuards.lastError(reason)
		if err then
			reply(player, "admin.useblocks.error", { reason = reason, err = err })
		end
	end
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

-- S96: /mount info | give [id] | take [id] | lvl <1-10> | ride | off
commands.mount = function(player, args)
	local action = args[1]
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local state = (character and character.mounts) or { owned = {}, riding = false }
		local active, lvl = Mounts.activeOf(state)
		if action == "info" then
			local owned: { string } = {}
			for id, entry in state.owned do
				table.insert(owned, `{id} {entry.lvl}`)
			end
			table.sort(owned)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			reply(player, "admin.mount.info", {
				owned = if #owned > 0 then table.concat(owned, ", ") else "-",
				active = active or "-",
				riding = if MountService.IsRiding(player) then "ON" else "OFF",
				speed = if humanoid then string.format("%.1f", humanoid.WalkSpeed) else "-",
				mul = string.format("%.2f", Mounts.speedMul(lvl)),
				time = tostring(Mounts.mountTime(lvl)),
			})
		elseif action == "give" then
			local id = args[2] or "mount_horse"
			if not MountData.get(id) then
				reply(player, "admin.mount.unknown", { id = id })
			elseif MountService.Grant(player, id, "admin") then
				reply(player, "admin.mount.given", { id = id })
			else
				reply(player, "admin.mount.already", { id = id })
			end
		elseif action == "take" then
			local id = args[2] or active
			if id and MountService.Take(player, id) then
				reply(player, "admin.mount.taken", { id = id })
			else
				reply(player, "admin.mount.unknown", { id = id or "-" })
			end
		elseif action == "lvl" then
			local n = parseAmount(args[2])
			if not n or not active then
				reply(player, "admin.usage.mount")
				return
			end
			MountService.SetLevel(player, active, n)
			local entry = (PlayerStateService.Get(player, { "character", "mounts", "owned", active }) or {}) :: any
			reply(player, "admin.mount.lvl", { id = active, lvl = entry.lvl or n })
		elseif action == "ride" then
			local ok, err = MountService.Ride(player, true)
			if not ok then
				reply(player, err or "admin.usage.mount", { level = Config.Mount.minLevel })
			end
		elseif action == "off" then
			MountService.Interrupt(player)
			MountService.Dismount(player, "admin")
		else
			reply(player, "admin.usage.mount")
		end
	end)
end

-- S97: every mount at its start level (premium too: admins test everything).
commands.mountall = function(player)
	withCharacter(player, function()
		local n = 0
		for _, def in MountData.list do
			if MountService.Grant(player, def.id, "admin") then
				n += 1
			end
		end
		reply(player, "admin.mount.all", { n = n })
	end)
end

-- S132: the look of the character without a cost and without touching the free change; "reset" = the default look.
commands.charlook = function(player, args)
	withCharacter(player, function()
		local look: ClassLooks.Look
		if args[1] == "reset" then
			look = CharacterLook.normalize(nil)
		else
			look = { face = args[1] or "", skin = args[2] or "", hair = args[3] or "" }
			for _, id in { look.face, look.skin, look.hair } do
				if not (ClassLooks.faceById[id] or ClassLooks.skinById[id] or ClassLooks.hairById[id]) then
					reply(player, "admin.charlook.bad", { id = id })
					return
				end
			end
		end
		if not CosmeticService.AdminSetLook(player, look) then
			reply(player, "admin.usage.charlook")
			return
		end
		reply(player, "admin.charlook.set", {
			face = `@look.face.{look.face}`,
			skin = look.skin,
			hair = `@look.hair.{look.hair}`,
		})
	end)
end

-- S132: the free look change again (the creator's one).
commands.lookfree = function(player)
	withCharacter(player, function()
		PlayerStateService.Set(player, { "character", "lookFree" }, true)
		reply(player, "admin.lookfree.ok")
	end)
end

-- S132: "Show my Roblox avatar" like the options window (CosmeticService.SetRobloxAvatar).
commands.avatarmode = function(player, args)
	if args[1] ~= "on" and args[1] ~= "off" then
		reply(player, "admin.usage.avatarmode")
		return
	end
	CosmeticService.SetRobloxAvatar(player, args[1] == "on")
	reply(player, "admin.avatarmode.ok", { mode = args[1] })
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
		if bought == 0 then
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

-- S137 (DESIGN-18 §11): /skillrank <skillId> <rank> [pool] (no points, no limit), /skillmax [pool] (buys like a
-- player), /skillreset (free), /pool (the active pool and the free points), /respecfree [on|off].
commands.skillrank = function(player, args)
	local skillId, rank, pool = args[1], tonumber(args[2]), args[3]
	if not skillId or rank == nil then
		reply(player, "admin.usage.skillrank")
		return
	end
	withCharacter(player, function()
		local ok, err = PathService.AdminSkillRank(player, skillId, rank :: number, pool)
		if not ok then
			reply(player, err or "admin.usage.skillrank")
			return
		end
		reply(player, "admin.skillrank.ok", { skill = skillId, rank = math.floor(rank :: number) })
	end)
end

commands.skillmax = function(player, args)
	withCharacter(player, function()
		local bought, err = PathService.AdminSkillMax(player, args[1])
		if err then
			reply(player, err)
			return
		end
		reply(player, "admin.skillmax.ok", { n = bought })
	end)
end

commands.skillreset = function(player)
	withCharacter(player, function()
		PathService.AdminSkillReset(player)
		reply(player, "admin.skillreset.ok")
	end)
end

commands.pool = function(player)
	withCharacter(player, function()
		local info = PathService.AdminPoolInfo(player)
		if not info then
			return
		end
		local parts: { string } = {}
		for id, n in info.free do
			table.insert(parts, `{id} {n}`)
		end
		table.sort(parts)
		reply(player, "admin.pool.info", {
			active = info.active,
			bar = if info.barPool ~= "" then info.barPool else "-",
			free = table.concat(parts, ", "),
			respec = if info.respecFree then "1" else "0",
		})
	end)
end

commands.respecfree = function(player, args)
	withCharacter(player, function()
		local on = args[1] ~= "off"
		PathService.AdminRespecFree(player, on)
		reply(player, "admin.respecfree.ok", { mode = if on then "on" else "off" })
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

-- S60: /luck: own luck, the party's (no range) and the class variety bonus (read only).
local function pct(value: number): number
	return math.floor(value + 0.5)
end

local function mul(value: number): string
	return string.format("%.2f", value)
end

commands.luck = function(player)
	withCharacter(player, function()
		local own = PathService.GetLuck(player)
		reply(player, "admin.luck.self", {
			drop = pct(StatService.GetValue(player, "dropBonus")),
			item = pct(Luck.capped("monsterItem", own.monsterItem)),
			elite2 = pct(Luck.capped("elite2", own.elite2)),
			gold = pct(Luck.capped("gold", own.gold)),
			mul = mul(1 + Luck.capped("bossLegendary", own.bossLegendary) / 100),
			upgrade = pct(Luck.capped("bossUpgrade", own.bossUpgrade)),
			extra = pct(Luck.capped("bossExtra", own.bossExtra)),
		})
		local members: { Luck.Member } = {}
		local classes: { string } = {}
		for _, member in PartyService.Members(player) do
			local data = PlayerStateService.GetCharacter(member)
			table.insert(members, {
				name = if data then data.name else member.Name,
				dropBonus = StatService.GetValue(member, "dropBonus"),
				luck = PathService.GetLuck(member),
			})
			table.insert(classes, if data then data.class else "")
		end
		local monster = Luck.monster(members)
		local boss = Luck.boss(members)
		reply(player, "admin.luck.group", {
			n = #members,
			itemBonus = pct(monster.itemBonus),
			personal = pct(monster.personal),
			fortune = pct(monster.fortune),
			cap = LuckData.monsterItemCap,
			gold = pct(monster.gold),
			elite2 = mul(monster.elite2Mul),
			mul = mul(boss.legendaryMul),
			upgrade = pct(boss.upgrade * 100),
			extra = pct(boss.extra * 100),
			from = boss.from or "-",
		})
		local distinct: { [string]: boolean } = {}
		local count = 0
		for _, id in classes do
			if id ~= "" and not distinct[id] then
				distinct[id] = true
				count += 1
			end
		end
		reply(player, "admin.luck.variety", { pct = PartyBonus.variety(classes), classes = count })
	end)
end

return commands
