--!strict
-- Admin commands: items (S23). Metadata (arguments, usage) in Shared.Data.AdminCommands; AdminService runs
-- them for the chat and the dev panel. Required from AdminService.Init, after Context has the services.

local Shared = game:GetService("ReplicatedStorage").Shared

local Config = require(Shared.Config)
local Elements = require(Shared.Data.Elements)
local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Loot = require(Shared.Logic.Loot)
local Monsters = require(Shared.Data.Monsters)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Rng = require(Shared.Logic.Rng)

local Context = require(script.Parent.Context)

local reply = Context.reply
local withCharacter = Context.withCharacter
local parseAmount = Context.parseAmount
local VARIANTS = Context.VARIANTS

local PlayerStateService = Context.services.PlayerStateService
local InventoryService = Context.services.InventoryService
local EquipmentService = Context.services.EquipmentService
local LootService = Context.services.LootService
local StatService = Context.services.StatService

local commands: { [string]: (player: Player, args: { string }) -> ...any } = {}

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

commands.give = function(player, args)
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
				local leftover = InventoryService.GiveNew(player, itemId, 1, if rarity == 6 then 1 else rarity, ilvl)
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
end

commands.legend = function(player)
	withCharacter(player, function()
		if LootService.DropLegendary(player) then
			reply(player, "admin.legend.ok")
		end
	end)
end

commands.lootsim = function(player, args)
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
end

commands.clearinv = function(player)
	withCharacter(player, function()
		InventoryService.Clear(player)
		reply(player, "admin.clearinv.ok")
	end)
end

commands.bag = function(player, args)
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
end

commands.up = function(player, args)
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
end

commands.mats = function(player, args)
	local n = math.clamp(parseAmount(args[1]) or 50, 1, 999)
	withCharacter(player, function()
		for id, def in Items.byId do
			if def.category == "material" then
				InventoryService.GiveNew(player, id, n)
			end
		end
		reply(player, "admin.mats.ok")
	end)
end

commands.scrolls = function(player, args)
	local n = math.clamp(parseAmount(args[1]) or 5, 1, 999)
	withCharacter(player, function()
		for id, def in Items.byId do
			if def.category == "scroll" or def.category == "stone" then
				InventoryService.GiveNew(player, id, n)
			end
		end
		reply(player, "admin.scrolls.ok")
	end)
end

commands.ilvl = function(player, args)
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
end

commands.element = function(player, args)
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
end

commands.partyloot = function(player, args)
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
end

-- S23: /givex id rarity ilvl up el n equip
commands.givex = function(player, args)
	local itemId = args[1]
	local def = itemId and Items.get(itemId)
	if not def then
		reply(player, "admin.usage.givex")
		return
	end
	withCharacter(player, function()
		local character = PlayerStateService.GetCharacter(player)
		local rarity = math.clamp(parseAmount(args[2]) or def.rarity or 1, 1, 6)
		local ilvl = math.clamp(parseAmount(args[3]) or math.max(def.level, character.level), 1, Config.MaxLevel)
		local up = math.clamp(parseAmount(args[4]) or 0, 0, 9)
		local element = args[5]
		local n = math.clamp(parseAmount(args[6]) or 1, 1, 999)
		local equip = args[7] == "yes"
		if def.stackable then
			local given = n - InventoryService.GiveNew(player, itemId, n)
			reply(
				player,
				if given > 0 then "admin.give.ok" else "inventory.full",
				{ name = `#item:{itemId}:0`, n = given }
			)
			return
		end
		local given = 0
		local lastIndex: number? = nil
		for _ = 1, math.min(n, 50) do
			local leftover, item = InventoryService.GiveNew(player, itemId, 1, if def.bossId then 6 else rarity, ilvl)
			if leftover > 0 or not item then
				break
			end
			item.up = up
			if def.elemental and element and Elements.isWeaponElement(element) then
				item.el = element
			end
			local index = InventoryService.IndexOf(player, item.uid)
			if index then
				InventoryService.SetSlot(player, index, item)
				lastIndex = index
			end
			given += 1
		end
		if given == 0 then
			reply(player, "inventory.full")
			return
		end
		reply(player, "admin.give.ok", { name = `#item:{itemId}:0`, n = given })
		if equip and lastIndex and def.slot then
			local ok, err = EquipmentService.Equip(player, lastIndex)
			if not ok then
				reply(player, err or "equip.error.slot")
			end
		end
	end)
end

return commands
