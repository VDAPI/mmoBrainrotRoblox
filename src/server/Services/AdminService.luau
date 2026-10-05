--!strict
-- Chat commands for admins (Config.AdminUserIds) and everyone in Studio. Each command is a
-- TextChatCommand so the text never shows up in public chat. Replies go to the caller's system channel.
-- Add commands to COMMANDS; every session extends this list with tools for testing its features.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared

local AccountSchema = require(Shared.Logic.AccountSchema)
local Classes = require(Shared.Data.Classes)
local Config = require(Shared.Config)
local Damage = require(Shared.Logic.Damage)
local Elements = require(Shared.Data.Elements)
local MonsterStats = require(Shared.Logic.MonsterStats)
local Log = require(Shared.Util.Log)
local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Blessings = require(Shared.Data.Blessings)
local Bosses = require(Shared.Data.Bosses)
local Clock = require(Shared.Util.Clock)
local Items = require(Shared.Data.Items)
local Maps = require(Shared.Data.Maps)
local Monsters = require(Shared.Data.Monsters)
local Npcs = require(Shared.Data.Npcs)
local Net = require(Shared.Net)
local Rng = require(Shared.Logic.Rng)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Loot = require(Shared.Logic.Loot)
local GuildLogic = require(Shared.Logic.Guild)
local GuildSkills = require(Shared.Data.GuildSkills)
local Products = require(Shared.Data.Products)

local log = Log.new("AdminService")

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
	},
}

local DataService: any
local PlayerStateService: any
local CharacterService: any
local NameService: any
local LevelService: any
local ResourceService: any
local DeathService: any
local PvpService: any
local MonetizationService: any
local MonsterService: any
local CombatService: any
local EntityService: any
local InventoryService: any
local LootService: any
local StatService: any
local SkillService: any
local NpcService: any
local AlchemyService: any
local BlessingService: any
local GatherService: any
local FishingService: any
local WorldService: any
local TravelService: any
local DungeonService: any
local TradeService: any
local QuestService: any
local GuildService: any
local MailService: any
local AuctionService: any
local CosmeticService: any

type Command = {
	usageKey: string,
	run: (player: Player, args: { string }) -> (),
}

local WIPE_CONFIRM_SECONDS = 30
local MAX_AMOUNT = 1e12
local wipeRequests: { [Player]: number } = {}

local function reply(player: Player, key: string, args: { [string]: any }?)
	Net.Fire(player, "SystemMessage", key, args)
end

function AdminService.IsAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	return table.find(Config.AdminUserIds, player.UserId) ~= nil
end

local function parseAmount(text: string?): number?
	local n = tonumber(text)
	if n == nil or n ~= n or math.abs(n) > MAX_AMOUNT then
		return nil
	end
	return math.floor(n)
end

local COMMANDS: { [string]: Command } = {}

COMMANDS.help = {
	usageKey = "admin.usage.help",
	run = function(player)
		local names = {}
		for name in COMMANDS do
			table.insert(names, name)
		end
		table.sort(names)
		reply(player, "admin.help.header")
		for _, name in names do
			reply(player, COMMANDS[name].usageKey)
		end
	end,
}

COMMANDS.gold = {
	usageKey = "admin.usage.gold",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil then
			reply(player, "admin.usage.gold")
			return
		end
		if PlayerStateService.GetCharacter(player) == nil then
			reply(player, "admin.needCharacter")
			return
		end
		local total = PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
			return math.max(0, gold + amount)
		end)
		reply(player, "admin.gold.ok", { amount = amount, total = total })
	end,
}

COMMANDS.shards = {
	usageKey = "admin.usage.shards",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil then
			reply(player, "admin.usage.shards")
			return
		end
		local total = PlayerStateService.Update(player, { "account", "dragonShards" }, function(shards: number)
			return math.max(0, shards + amount)
		end)
		reply(player, "admin.shards.ok", { amount = amount, total = total })
	end,
}

COMMANDS.wipe = {
	usageKey = "admin.usage.wipe",
	run = function(player, args)
		local requestedAt = wipeRequests[player]
		local confirmed = args[1] == "confirm"
			and requestedAt ~= nil
			and os.clock() - requestedAt <= WIPE_CONFIRM_SECONDS
		if not confirmed then
			wipeRequests[player] = os.clock()
			reply(player, "admin.wipe.confirm", { seconds = WIPE_CONFIRM_SECONDS })
			return
		end
		wipeRequests[player] = nil

		local data = DataService.GetData(player)
		if not data then
			return
		end
		CharacterService.ReturnToSelect(player)
		for _, character in data.characters do
			NameService.Release(character.name, NameService.OwnerKey(player.UserId, character.id))
		end
		-- Replace contents in place: the profile keeps referencing the same table.
		local fresh = AccountSchema.accountTemplate()
		local keepLang = data.settings.lang
		for key in data :: any do
			(data :: any)[key] = nil
		end
		for key, value in fresh :: any do
			(data :: any)[key] = value
		end
		data.settings.lang = keepLang
		data.stats.createdAt = os.time()
		PlayerStateService.Reset(player)
		log:info("%s wiped their account", player.Name)
		reply(player, "admin.wipe.ok")
	end,
}

-- Runs `fn` only when the caller is in the world with a character.
local function withCharacter(player: Player, fn: () -> ())
	if PlayerStateService.GetCharacter(player) == nil then
		reply(player, "admin.needCharacter")
		return
	end
	fn()
end

COMMANDS.lvl = {
	usageKey = "admin.usage.lvl",
	run = function(player, args)
		local level = parseAmount(args[1])
		if level == nil or level < 1 then
			reply(player, "admin.usage.lvl")
			return
		end
		withCharacter(player, function()
			LevelService.SetLevel(player, level)
			reply(player, "admin.lvl.ok", { level = PlayerStateService.Get(player, { "character", "level" }) })
		end)
	end,
}

-- S17: lets the same account redeem the reward codes again (testing).
COMMANDS.resetcodes = {
	usageKey = "admin.usage.resetcodes",
	run = function(player)
		PlayerStateService.Set(player, { "account", "redeemed" }, {})
		reply(player, "admin.resetcodes.ok")
	end,
}

-- S18 ------------------------------------------------------------------------------------------------

-- Changes the equipped weapon with `edit` and recomputes stats.
local function editWeapon(player: Player, edit: (item: any) -> ()): boolean
	local character = PlayerStateService.GetCharacter(player)
	local item = character and character.equipment.weapon
	if not item then
		reply(player, "admin.weapon.none")
		return false
	end
	local copy = table.clone(item)
	edit(copy)
	PlayerStateService.Set(player, { "character", "equipment", "weapon" }, copy)
	StatService.Invalidate(player)
	return true
end

COMMANDS.ilvl = {
	usageKey = "admin.usage.ilvl",
	run = function(player, args)
		local ilvl = parseAmount(args[1])
		if ilvl == nil or ilvl < 1 or ilvl > Config.MaxLevel then
			reply(player, "admin.usage.ilvl")
			return
		end
		withCharacter(player, function()
			if editWeapon(player, function(item)
				item.ilvl = ilvl
			end) then
				reply(player, "admin.ilvl.ok", { ilvl = ilvl })
			end
		end)
	end,
}

COMMANDS.element = {
	usageKey = "admin.usage.element",
	run = function(player, args)
		local element = args[1]
		if not Elements.isWeaponElement(element) then
			reply(player, "admin.usage.element")
			return
		end
		withCharacter(player, function()
			local character = PlayerStateService.GetCharacter(player)
			local item = character and character.equipment.weapon
			local def = item and Items.get(item.id)
			if def and not def.elemental then
				reply(player, "admin.element.notMage")
				return
			end
			if editWeapon(player, function(weapon)
				weapon.el = element
			end) then
				reply(player, "admin.element.ok", { element = element })
			end
		end)
	end,
}

COMMANDS.mstats = {
	usageKey = "admin.usage.mstats",
	run = function(player, args)
		withCharacter(player, function()
			local character = PlayerStateService.GetCharacter(player) :: any
			local level = parseAmount(args[1]) or character.level
			level = math.clamp(level, 1, Config.MaxLevel)
			local monster =
				MonsterStats.compute({ hpMul = 1, atkMul = 1, defMul = 1, speed = 1, attack = "melee" }, level)
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
	end,
}

COMMANDS.sprint = {
	usageKey = "admin.usage.sprint",
	run = function(player)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		reply(player, "admin.sprint.info", {
			on = if StatService.IsSprinting(player) then "ON" else "OFF",
			speed = if humanoid then string.format("%.1f", humanoid.WalkSpeed) else "-",
		})
	end,
}

COMMANDS.exp = {
	usageKey = "admin.usage.exp",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil or amount <= 0 then
			reply(player, "admin.usage.exp")
			return
		end
		withCharacter(player, function()
			local levels = LevelService.GiveExp(player, amount, "admin")
			reply(player, "admin.exp.ok", { amount = amount, levels = levels })
		end)
	end,
}

COMMANDS.stats = {
	usageKey = "admin.usage.stats",
	run = function(player, args)
		if args[1] ~= "reset" then
			reply(player, "admin.usage.stats")
			return
		end
		withCharacter(player, function()
			LevelService.ResetStats(player)
			reply(player, "admin.stats.ok")
		end)
	end,
}

COMMANDS.heal = {
	usageKey = "admin.usage.heal",
	run = function(player)
		withCharacter(player, function()
			if ResourceService.IsDead(player) then
				reply(player, "admin.heal.dead")
				return
			end
			ResourceService.Restore(player)
			reply(player, "admin.heal.ok")
		end)
	end,
}

COMMANDS.god = {
	usageKey = "admin.usage.god",
	run = function(player)
		withCharacter(player, function()
			local enabled = not ResourceService.IsGod(player)
			ResourceService.SetGod(player, enabled)
			reply(player, if enabled then "admin.god.on" else "admin.god.off")
		end)
	end,
}

COMMANDS.hurt = {
	usageKey = "admin.usage.hurt",
	run = function(player, args)
		local amount = parseAmount(args[1])
		if amount == nil or amount <= 0 then
			reply(player, "admin.usage.hurt")
			return
		end
		withCharacter(player, function()
			local dealt = ResourceService.Damage(player, amount, "admin")
			reply(player, "admin.hurt.ok", { amount = math.floor(dealt) })
		end)
	end,
}

COMMANDS.kill = {
	usageKey = "admin.usage.kill",
	run = function(player, args: { string })
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
	end,
}

COMMANDS.pvp = {
	usageKey = "admin.usage.pvp",
	run = function(player, args)
		local mode = if args[1] == "force" then args[2] else args[1]
		if mode ~= "on" and mode ~= "off" then
			reply(player, "admin.usage.pvp")
			return
		end
		withCharacter(player, function()
			PvpService.Force(player, mode == "on")
			reply(player, if mode == "on" then "admin.pvp.on" else "admin.pvp.off")
		end)
	end,
}

COMMANDS.tp = {
	usageKey = "admin.usage.tp",
	run = function(player, args)
		local mapId = args[1]
		if mapId == "boss" and args[2] then
			-- /tp boss <id>: in front of that boss's dungeon gate.
			local def = Bosses.get(args[2])
			local cave = nil
			for _, map in Maps.byId do
				if def and map.dungeonRegion == def.region and map.dungeonEntrance then
					cave = map
				end
			end
			if not cave or not cave.dungeonEntrance or not WorldService.IsBuilt(cave.id) then
				reply(player, "admin.usage.tp")
				return
			end
			local e = cave.dungeonEntrance
			withCharacter(player, function()
				task.spawn(
					TravelService.TeleportToMap,
					player,
					cave.id,
					WorldService.GroundCFrame(cave.id, e.x - 22, e.z)
				)
				reply(player, "admin.tp.map", { map = cave.id })
			end)
			return
		end
		if mapId and Maps.get(mapId) then
			if not WorldService.IsBuilt(mapId) then
				reply(player, "admin.maps.notBuilt", { map = mapId })
				return
			end
			withCharacter(player, function()
				local px, pz = tonumber(args[2]), tonumber(args[3])
				local at = if px and pz then WorldService.GroundCFrame(mapId, px, pz) else nil
				task.spawn(TravelService.TeleportToMap, player, mapId, at)
				reply(player, "admin.tp.map", { map = mapId })
			end)
			return
		end
		local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
		if x == nil or y == nil or z == nil then
			reply(player, "admin.usage.tp")
			return
		end
		withCharacter(player, function()
			local model = player.Character
			if model then
				model:PivotTo(CFrame.new(x :: number, y :: number, z :: number))
				reply(player, "admin.tp.ok", { x = x, y = y, z = z })
			end
		end)
	end,
}

COMMANDS.pass = {
	usageKey = "admin.usage.pass",
	run = function(player, args)
		local passId = args[1]
		if passId == nil or (args[2] ~= "on" and args[2] ~= "off") then
			reply(player, "admin.usage.pass")
			return
		end
		MonetizationService.SetTestPass(player, passId, args[2] == "on")
		reply(player, "admin.pass.ok", { pass = passId, state = args[2] })
	end,
}

local VARIANTS = { [0] = "normal", [1] = "elite", [2] = "elite2" }

COMMANDS.spawn = {
	usageKey = "admin.usage.spawn",
	run = function(player, args)
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
	end,
}

COMMANDS.killall = {
	usageKey = "admin.usage.killall",
	run = function(player, args)
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
	end,
}

COMMANDS.target = {
	usageKey = "admin.usage.target",
	run = function(player, args)
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
	end,
}

COMMANDS.dmg = {
	usageKey = "admin.usage.dmg",
	run = function(player, args)
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
	end,
}

COMMANDS.monsters = {
	usageKey = "admin.usage.monsters",
	run = function(player)
		local active, sleeping, spawners, awake = MonsterService.Stats()
		reply(
			player,
			"admin.monsters.info",
			{ active = active, sleeping = sleeping, spawners = spawners, awake = awake }
		)
	end,
}

COMMANDS.give = {
	usageKey = "admin.usage.give",
	run = function(player, args)
		local itemId = args[1]
		if not itemId then
			reply(player, "admin.usage.give")
			return
		end
		local def = Items.get(itemId)
		if not def then
			reply(player, "admin.give.unknown", { id = itemId })
			return
		end
		withCharacter(player, function()
			local character = PlayerStateService.GetCharacter(player)
			local rarityArg = args[2]
			local rarity = if rarityArg == "u" then 6 else math.clamp(tonumber(rarityArg) or 1, 1, 5)
			local ilvl = math.clamp(parseAmount(args[3]) or math.max(def.level, character.level), 1, Config.MaxLevel)
			local n = math.clamp(parseAmount(args[4]) or 1, 1, 999)
			local given = 0
			if def.stackable then
				given = n - InventoryService.GiveNew(player, itemId, n)
			else
				for _ = 1, math.min(n, 50) do
					local leftover =
						InventoryService.GiveNew(player, itemId, 1, if rarity == 6 then 1 else rarity, ilvl)
					if leftover > 0 then
						break
					end
					given += 1
				end
			end
			if given == 0 then
				reply(player, "inventory.full")
			else
				reply(player, "admin.give.ok", { name = `#item:{itemId}:0`, n = given })
			end
		end)
	end,
}

COMMANDS.legend = {
	usageKey = "admin.usage.legend",
	run = function(player)
		withCharacter(player, function()
			if LootService.DropLegendary(player) then
				reply(player, "admin.legend.ok")
			end
		end)
	end,
}

COMMANDS.lootsim = {
	usageKey = "admin.usage.lootsim",
	run = function(player, args)
		local monsterId = args[1]
		local def = monsterId and Monsters.get(monsterId)
		if not def then
			reply(player, "admin.usage.lootsim")
			return
		end
		local variant = VARIANTS[tonumber(args[2]) or 0] or "normal"
		local n = math.clamp(parseAmount(args[3]) or 1000, 1, 100000)
		local character = PlayerStateService.GetCharacter(player)
		local counts, items, mats, gold =
			LootService.Simulate(monsterId, variant, def.levels.max, n, if character then character.class else nil)
		reply(player, "admin.lootsim.result", {
			n = n,
			items = items,
			c1 = counts[1],
			c2 = counts[2],
			c3 = counts[3],
			c4 = counts[4],
			c5 = counts[5],
			c6 = counts[6],
			mats = mats,
			gold = gold,
		})
	end,
}

COMMANDS.clearinv = {
	usageKey = "admin.usage.clearinv",
	run = function(player)
		withCharacter(player, function()
			InventoryService.Clear(player)
			reply(player, "admin.clearinv.ok")
		end)
	end,
}

COMMANDS.bag = {
	usageKey = "admin.usage.bag",
	run = function(player, args)
		local capacity = parseAmount(args[1])
		local id = if capacity then `backpack_{capacity}` else ""
		if not Items.get(id) then
			reply(player, "admin.bag.unknown", { capacity = args[1] or "?" })
			return
		end
		withCharacter(player, function()
			local character = PlayerStateService.GetCharacter(player)
			if not Inventory.compact(character.inventory, capacity :: number) then
				reply(player, "equip.error.backpackFit")
				return
			end
			local backpack = ItemRoll.makeStack(id, 1, InventoryService.NewUid())
			backpack.bound = true
			PlayerStateService.Set(player, { "character", "equipment", "backpack" }, backpack)
			InventoryService.SyncAll(player)
			StatService.Invalidate(player)
			reply(player, "admin.bag.ok", { capacity = capacity })
		end)
	end,
}

COMMANDS.skillpoints = {
	usageKey = "admin.usage.skillpoints",
	run = function(player, args)
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
	end,
}

COMMANDS.skills = {
	usageKey = "admin.usage.skills",
	run = function(player, args)
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
	end,
}

COMMANDS.cd = {
	usageKey = "admin.usage.cd",
	run = function(player, args)
		if args[1] ~= "off" and args[1] ~= "on" then
			reply(player, "admin.usage.cd")
			return
		end
		SkillService.SetNoCooldowns(player, args[1] == "off")
		reply(player, if args[1] == "off" then "admin.cd.off" else "admin.cd.on")
	end,
}

COMMANDS.res = {
	usageKey = "admin.usage.res",
	run = function(player, args)
		if args[1] ~= "inf" and args[1] ~= "off" then
			reply(player, "admin.usage.res")
			return
		end
		SkillService.SetInfiniteResources(player, args[1] == "inf")
		reply(player, if args[1] == "inf" then "admin.res.on" else "admin.res.off")
	end,
}

COMMANDS.up = {
	usageKey = "admin.usage.up",
	run = function(player, args)
		local where, level = args[1], parseAmount(args[2])
		if not where or level == nil then
			reply(player, "admin.usage.up")
			return
		end
		withCharacter(player, function()
			local character = PlayerStateService.GetCharacter(player)
			local up = math.clamp(level, 0, 9)
			local index = tonumber(where)
			if index then
				local item = InventoryService.Get(player, index)
				if not item then
					reply(player, "admin.up.none")
					return
				end
				item.up = up
				InventoryService.SetSlot(player, index, item)
			else
				local item = character.equipment[where]
				if not item then
					reply(player, "admin.up.none")
					return
				end
				item.up = up
				PlayerStateService.Set(player, { "character", "equipment", where }, item)
				StatService.Invalidate(player)
			end
			reply(player, "admin.up.ok", { up = up })
		end)
	end,
}

COMMANDS.mats = {
	usageKey = "admin.usage.mats",
	run = function(player, args)
		local n = math.clamp(parseAmount(args[1]) or 50, 1, 999)
		withCharacter(player, function()
			for id, def in Items.byId do
				if def.category == "material" then
					InventoryService.GiveNew(player, id, n)
				end
			end
			reply(player, "admin.mats.ok")
		end)
	end,
}

COMMANDS.scrolls = {
	usageKey = "admin.usage.scrolls",
	run = function(player, args)
		local n = math.clamp(parseAmount(args[1]) or 5, 1, 999)
		withCharacter(player, function()
			for id, def in Items.byId do
				if def.category == "scroll" or def.category == "stone" then
					InventoryService.GiveNew(player, id, n)
				end
			end
			reply(player, "admin.scrolls.ok")
		end)
	end,
}

COMMANDS.npc = {
	usageKey = "admin.usage.npc",
	run = function(player, args)
		local id = args[1]
		if not id then
			local names = {}
			for _, def in Npcs.list do
				if not def.decoration then
					table.insert(names, def.id)
				end
			end
			reply(player, "admin.npc.list", { list = table.concat(names, ", ") })
			return
		end
		local position = NpcService.Position(id)
		local def = Npcs.get(id)
		withCharacter(player, function()
			local model = player.Character
			if model and position and def then
				model:PivotTo(CFrame.new(position + Vector3.new(0, 4, 6)))
				reply(player, "admin.npc.tp", { npc = "@" .. def.nameKey })
			else
				reply(player, "admin.usage.npc")
			end
		end)
	end,
}

COMMANDS.time = {
	usageKey = "admin.usage.time",
	run = function(player, args)
		local text = args[1]
		local seconds = text and tonumber((string.gsub(text, "^%+", "")))
		if not seconds then
			reply(player, "admin.usage.time")
			return
		end
		Clock.shift(seconds)
		AlchemyService.CheckAll()
		BlessingService.CheckAll()
		reply(player, "admin.time.ok", { seconds = seconds, offset = Clock.offset() })
	end,
}

COMMANDS.bless = {
	usageKey = "admin.usage.bless",
	run = function(player, args)
		local id = args[1]
		if not id then
			local ids = {}
			for _, blessing in Blessings.list do
				table.insert(ids, blessing.id)
			end
			reply(player, "admin.bless.list", { list = table.concat(ids, ", ") })
			return
		end
		withCharacter(player, function()
			if BlessingService.Grant(player, id) then
				reply(player, "admin.bless.ok", { id = id })
			else
				reply(player, "admin.usage.bless")
			end
		end)
	end,
}

COMMANDS.nodes = {
	usageKey = "admin.usage.nodes",
	run = function(player, args)
		if args[1] ~= "respawn" then
			reply(player, "admin.usage.nodes")
			return
		end
		reply(player, "admin.nodes.ok", { n = GatherService.RespawnAll() })
	end,
}

COMMANDS.fish = {
	usageKey = "admin.usage.fish",
	run = function(player, args)
		if args[1] ~= "auto" then
			reply(player, "admin.usage.fish")
			return
		end
		local enabled = not FishingService.IsAuto(player)
		FishingService.SetAuto(player, enabled)
		reply(player, if enabled then "admin.fish.on" else "admin.fish.off")
	end,
}

COMMANDS.maps = {
	usageKey = "admin.usage.maps",
	run = function(player)
		local ids = {}
		for id in Maps.byId do
			table.insert(ids, id)
		end
		table.sort(ids)
		local parts = {}
		for _, id in ids do
			table.insert(parts, if WorldService.IsBuilt(id) then `{id} ✔` else id)
		end
		reply(player, "admin.maps.list", { list = table.concat(parts, ", ") })
	end,
}

COMMANDS.rebuild = {
	usageKey = "admin.usage.rebuild",
	run = function(player, args)
		local mapId = args[1]
		if not mapId or not Maps.get(mapId) then
			reply(player, "admin.usage.rebuild")
			return
		end
		local started = os.clock()
		if WorldService.Rebuild(mapId) then
			reply(player, "admin.rebuild.ok", { map = mapId, seconds = math.floor((os.clock() - started) * 10) / 10 })
		else
			reply(player, "admin.maps.notBuilt", { map = mapId })
		end
	end,
}

COMMANDS.nearby = {
	usageKey = "admin.usage.nearby",
	run = function(player, args)
		local radius = math.clamp(tonumber(args[1]) or 150, 10, 2000)
		local model = player.Character
		local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end
		local lines = {}
		for i, s in MonsterService.SpawnersNear(root.Position, radius) do
			if i > 12 then
				break
			end
			table.insert(lines, `{s.id} ({s.monster} {s.variant}) {s.alive}/{s.count} · {s.distance}`)
		end
		if #lines == 0 then
			reply(player, "admin.nearby.none")
		else
			reply(player, "admin.nearby.list", { list = table.concat(lines, "; ") })
		end
	end,
}

COMMANDS.boss = {
	usageKey = "admin.usage.boss",
	run = function(player, args)
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
	end,
}

COMMANDS.phase = {
	usageKey = "admin.usage.phase",
	run = function(player, args)
		local phase = tonumber(args[1])
		if not phase or not DungeonService.ForcePhase(player, math.floor(phase)) then
			reply(player, "admin.usage.phase")
			return
		end
		reply(player, "admin.phase.ok", { phase = phase })
	end,
}

-- Simulates party loot distribution among fake members of every class (solo testing of DESIGN §17).
COMMANDS.partyloot = {
	usageKey = "admin.usage.partyloot",
	run = function(player, args)
		local n = math.clamp(tonumber(args[1]) or 4, 1, 5)
		local classes = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }
		local candidates = {}
		for i = 1, n do
			table.insert(candidates, { id = i, classId = classes[i] })
		end
		local rng = Rng.new()
		local loot = Loot.rollBossLoot("grimrok", n, rng, {})
		local items = {}
		for i, drop in loot.items do
			local def = Items.get(drop.defId)
			table.insert(items, { uid = tostring(i), classes = if def then def.classes else nil, id = drop.defId })
		end
		local assigned = PartyLoot.distribute(items :: any, candidates, rng)
		local lines = {}
		for _, item in items do
			local owner = assigned[item.uid]
			table.insert(lines, `{item.id} -> #{owner or 0} {classes[owner or 1]}`)
		end
		reply(player, "admin.partyloot.result", { list = table.concat(lines, "; ") })
	end,
}

COMMANDS.tradetest = {
	usageKey = "admin.usage.tradetest",
	run = function(player)
		if not game:GetService("RunService"):IsStudio() then
			reply(player, "admin.studioOnly")
			return
		end
		withCharacter(player, function()
			if TradeService.Preview(player) then
				reply(player, "admin.tradetest.ok")
			end
		end)
	end,
}

COMMANDS.quest = {
	usageKey = "admin.usage.quest",
	run = function(player, args)
		withCharacter(player, function()
			if args[1] == "set" and args[2] and QuestService.SetMain(player, args[2]) then
				reply(player, "admin.quest.set", { id = args[2] })
			elseif args[1] == "complete" and QuestService.CompleteMain(player) then
				reply(player, "admin.quest.complete")
			else
				reply(player, "admin.usage.quest")
			end
		end)
	end,
}

COMMANDS.daily = {
	usageKey = "admin.usage.daily",
	run = function(player, args)
		if args[1] ~= "reroll" then
			reply(player, "admin.usage.daily")
			return
		end
		withCharacter(player, function()
			QuestService.RerollDaily(player)
			reply(player, "admin.daily.reroll")
		end)
	end,
}

COMMANDS.guild = {
	usageKey = "admin.usage.guild",
	run = function(player, args)
		withCharacter(player, function()
			local data = GuildService.Data(player)
			if not data then
				reply(player, "admin.guild.none")
				return
			end
			local sub = args[1]
			if sub == "info" then
				local skills = {}
				for id, level in data.skills do
					table.insert(skills, `{id} {level}`)
				end
				local count = 0
				for _ in data.members do
					count += 1
				end
				reply(player, "admin.guild.info", {
					name = data.name,
					tag = data.tag,
					members = count,
					treasury = data.treasury,
					skills = if #skills > 0 then table.concat(skills, ", ") else "-",
					version = data.version,
					id = data.id,
				})
			elseif sub == "treasury" and parseAmount(args[2]) then
				local amount = math.max(0, parseAmount(args[2]) :: number)
				if GuildService.AdminMutate(player, function(guild)
					guild.treasury = amount
				end) then
					reply(player, "admin.guild.done")
				end
			elseif sub == "skills" and args[2] == "max" then
				if
					GuildService.AdminMutate(player, function(guild)
						for _, def in GuildSkills.list do
							guild.skills[def.id] = GuildSkills.MAX_LEVEL
						end
					end)
				then
					reply(player, "admin.guild.done")
				end
			elseif sub == "bots" and parseAmount(args[2]) then
				-- Offline dummy members to test the member list, ranks and kicking alone.
				local n = math.clamp(parseAmount(args[2]) :: number, 1, 40)
				local classes = { "Warrior", "Hunter", "Mage", "Cleric" }
				if
					GuildService.AdminMutate(player, function(guild)
						local limit = GuildLogic.memberLimit(guild.skills)
						for i = 1, n do
							if GuildLogic.memberCount(guild) >= limit then
								break
							end
							local charId = `bot{guild.version}_{i}`
							guild.members[GuildLogic.memberKey(-i, charId)] = {
								userId = -i,
								charId = charId,
								name = `Bot{i}`,
								class = classes[(i - 1) % 4 + 1],
								level = 10 + i * 2,
								rank = "member",
								joinedAt = os.time(),
								contributed = 0,
							}
						end
					end)
				then
					reply(player, "admin.guild.done")
				end
			elseif sub == "disband" then
				if GuildService.AdminDisband(player) then
					reply(player, "admin.guild.done")
				end
			else
				reply(player, "admin.usage.guild")
			end
		end)
	end,
}

COMMANDS.mail = {
	usageKey = "admin.usage.mail",
	run = function(player, args)
		withCharacter(player, function()
			local char = PlayerStateService.GetCharacter(player)
			local outgoing: any = { from = "admin", subjectKey = "mail.subject.admin", charId = nil }
			if args[1] == "gold" and parseAmount(args[2]) then
				outgoing.gold = math.max(1, parseAmount(args[2]) :: number)
			elseif args[1] == "item" and args[2] and Items.get(args[2]) then
				local def = Items.get(args[2]) :: any
				local n = math.clamp(parseAmount(args[3]) or 1, 1, def.maxStack)
				local item = if def.category == "equipment"
					then ItemRoll.rollItem(
						args[2],
						def.level,
						math.clamp(parseAmount(args[4]) or 1, 1, 5),
						Rng.new(),
						InventoryService.NewUid()
					)
					else ItemRoll.makeStack(args[2], n, InventoryService.NewUid())
				outgoing.items = { item }
			else
				reply(player, "admin.usage.mail")
				return
			end
			outgoing.charId = if char then char.id else nil
			local ok, err = MailService.Send(player.UserId, outgoing)
			reply(player, if ok then "admin.mail.sent" else (err or "error.internal"))
		end)
	end,
}

COMMANDS.auction = {
	usageKey = "admin.usage.auction",
	run = function(player, args)
		if args[1] == "list" then
			local parts = {}
			for category, n in AuctionService.AdminStats() do
				table.insert(parts, `{category} {n}`)
			end
			table.sort(parts)
			reply(player, "admin.auction.list", {
				list = table.concat(parts, ", "),
				mode = if AuctionService.IndexIsLocal() then "local" else "global",
			})
		elseif args[1] == "expireall" then
			if not RunService:IsStudio() then
				reply(player, "admin.studioOnly")
				return
			end
			reply(player, "admin.auction.expired", { n = AuctionService.AdminExpireAll() })
		else
			reply(player, "admin.usage.auction")
		end
	end,
}

COMMANDS.premium = {
	usageKey = "admin.usage.premium",
	run = function(player, args)
		local pass = args[2] and Products.getPass(args[2])
		if args[1] ~= "grant" or not pass then
			reply(player, "admin.usage.premium")
			return
		end
		MonetizationService.SetTestPass(player, pass.key, true)
		reply(player, "admin.pass.ok", { pass = pass.key, state = "on" })
	end,
}

COMMANDS.cosmetic = {
	usageKey = "admin.usage.cosmetic",
	run = function(player, args)
		if args[1] ~= "all" then
			reply(player, "admin.usage.cosmetic")
			return
		end
		CosmeticService.GrantAll(player)
		reply(player, "admin.cosmetic.all")
	end,
}

COMMANDS.perf = {
	usageKey = "admin.usage.perf",
	run = function(player)
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
	end,
}

local function onCommand(name: string, textSource: TextSource, message: string)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if not player then
		return
	end
	if not AdminService.IsAdmin(player) then
		reply(player, "admin.denied")
		return
	end
	local parts = string.split(message, " ")
	local args = {}
	for i = 2, #parts do
		if parts[i] ~= "" then
			table.insert(args, parts[i])
		end
	end
	local command = COMMANDS[name]
	local ok, err = pcall(command.run :: any, player, args)
	if not ok then
		log:error("/%s failed: %s", name, tostring(err))
		reply(player, "admin.failed", { command = name })
	end
end

function AdminService.Init(registry)
	DataService = registry.Get("DataService")
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	NameService = registry.Get("NameService")
	LevelService = registry.Get("LevelService")
	ResourceService = registry.Get("ResourceService")
	DeathService = registry.Get("DeathService")
	PvpService = registry.Get("PvpService")
	MonetizationService = registry.Get("MonetizationService")
	MonsterService = registry.Get("MonsterService")
	CombatService = registry.Get("CombatService")
	EntityService = registry.Get("EntityService")
	InventoryService = registry.Get("InventoryService")
	LootService = registry.Get("LootService")
	StatService = registry.Get("StatService")
	SkillService = registry.Get("SkillService")
	NpcService = registry.Get("NpcService")
	AlchemyService = registry.Get("AlchemyService")
	BlessingService = registry.Get("BlessingService")
	GatherService = registry.Get("GatherService")
	FishingService = registry.Get("FishingService")
	WorldService = registry.Get("WorldService")
	TravelService = registry.Get("TravelService")
	DungeonService = registry.Get("DungeonService")
	TradeService = registry.Get("TradeService")
	QuestService = registry.Get("QuestService")
	GuildService = registry.Get("GuildService")
	MailService = registry.Get("MailService")
	AuctionService = registry.Get("AuctionService")
	CosmeticService = registry.Get("CosmeticService")
end

function AdminService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "AdminCommands"
	for name in COMMANDS do
		local command = Instance.new("TextChatCommand")
		command.Name = `Admin_{name}`
		command.PrimaryAlias = `/{name}`
		command.Triggered:Connect(function(textSource: TextSource, message: string)
			onCommand(name, textSource, message)
		end)
		command.Parent = folder
	end
	folder.Parent = TextChatService

	Players.PlayerRemoving:Connect(function(player)
		wipeRequests[player] = nil
	end)
end

return AdminService
