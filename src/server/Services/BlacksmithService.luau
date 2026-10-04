--!strict
-- Blacksmith (DESIGN §6–§8): crafting fixed-stat Common items for gold + ore, upgrading +0..+9 (backpack or
-- equipped items, optional Scroll of Protection), dismantling into essences. Each operation checks the NPC
-- distance, the costs and changes data in one step. +7 and higher is announced on the server; +9 on a
-- legendary also across servers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Crafting = require(Shared.Data.Crafting)
local Dismantle = require(Shared.Logic.Dismantle)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)
local Upgrade = require(Shared.Logic.Upgrade)

local log = Log.new("BlacksmithService")

type ItemInstance = Types.ItemInstance

local BlacksmithService = {
	Name = "BlacksmithService",
	Deps = {
		"PlayerStateService",
		"InventoryService",
		"NpcService",
		"StatService",
		"AnnounceService",
		"EquipmentService",
	},
}

local PlayerStateService: any
local InventoryService: any
local NpcService: any
local StatService: any
local AnnounceService: any

local rng = Rng.new()

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function nearSmith(player: Player): boolean
	return NpcService.NearService(player, "blacksmith") ~= nil
end

local function hasMaterials(player: Player, materials: { { id: string, n: number } }): boolean
	for _, material in materials do
		if InventoryService.Count(player, material.id) < material.n then
			return false
		end
	end
	return true
end

local function takeMaterials(player: Player, materials: { { id: string, n: number } })
	for _, material in materials do
		InventoryService.Remove(player, material.id, material.n)
	end
end

local function addGold(player: Player, delta: number)
	PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return math.max(0, gold + delta)
	end)
end

-- Crafting ----------------------------------------------------------------------------------------------------

local function craft(player: Player, recipeId: string): (boolean, string?)
	local char = character(player)
	local recipe = Crafting.get(recipeId)
	if not char or not recipe then
		return false, "error.badRequest"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	if char.gold < recipe.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, recipe.materials) then
		return false, "smith.missing"
	end
	local item = ItemRoll.rollItem(recipe.item, recipe.level, Rarities.COMMON, rng, InventoryService.NewUid())
	if not InventoryService.CanFit(player, { item }) then
		return false, "inventory.full"
	end
	addGold(player, -recipe.gold)
	takeMaterials(player, recipe.materials)
	InventoryService.AddItem(player, item)
	return true, nil
end

-- Upgrading --------------------------------------------------------------------------------------------------

local function locate(player: Player, location: string, key: string): (ItemInstance?, () -> ())
	local char = character(player)
	if not char then
		return nil, function() end
	end
	if location == "eq" then
		local item = char.equipment[key]
		if key == "backpack" then
			return nil, function() end
		end
		return item,
			function()
				PlayerStateService.Set(player, { "character", "equipment", key }, item)
				StatService.Invalidate(player)
			end
	elseif location == "inv" then
		local index = tonumber(key)
		local item = if index then InventoryService.Get(player, index) else nil
		return item, function()
			InventoryService.SetSlot(player, index :: number, item)
		end
	end
	return nil, function() end
end

local function upgrade(player: Player, location: string, key: string, protect: boolean): (boolean, string?, any)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local item, commit = locate(player, location, key)
	local def = item and Items.get(item.id)
	if not item or not def or def.category ~= "equipment" then
		return false, "error.badRequest"
	end
	if not Upgrade.canUpgrade(item) then
		return false, "smith.upgrade.max"
	end
	local cost = Upgrade.cost(item, item.up + 1)
	if char.gold < cost.gold then
		return false, "shop.error.gold"
	end
	if not hasMaterials(player, cost.materials) then
		return false, "smith.missing"
	end
	local useProtection = protect and InventoryService.Count(player, "scroll_protection") > 0
	-- Pay, roll, write — no yields in between.
	addGold(player, -cost.gold)
	takeMaterials(player, cost.materials)
	if useProtection then
		InventoryService.Remove(player, "scroll_protection", 1)
	end
	local result = Upgrade.attempt(item, useProtection, rng)
	item.up = result.to
	commit()
	if result.success and result.to >= 7 then
		local args = { player = char.name, item = `#item:{item.id}:0`, up = result.to }
		if result.to >= 9 and item.rarity == Rarities.LEGENDARY then
			AnnounceService.Global("announce.upgrade", "announce.upgradeGlobal", args)
		else
			AnnounceService.Server("announce.upgrade", args)
		end
	end
	log:info("%s upgrade %s +%d -> +%d", player.Name, item.id, result.from, result.to)
	return true, nil, { success = result.success, from = result.from, to = result.to, protected = result.protected }
end

-- Dismantling -------------------------------------------------------------------------------------------------

local function dismantleIndices(player: Player, indices: { number }): (boolean, string?, any)
	local gained: { [string]: number } = {}
	local count = 0
	for _, index in indices do
		local item = InventoryService.Get(player, index)
		if item and Dismantle.canDismantle(item) then
			for _, material in Dismantle.roll(item, rng) do
				gained[material.id] = (gained[material.id] or 0) + material.n
			end
			InventoryService.SetSlot(player, index, nil)
			count += 1
		end
	end
	if count == 0 then
		return false, "shop.error.nothing"
	end
	local list = {}
	for id, n in gained do
		InventoryService.GiveNew(player, id, n)
		table.insert(list, { id = id, n = n })
	end
	return true, nil, list
end

local function dismantle(player: Player, raw: { any }): (boolean, string?, any)
	if not character(player) then
		return false, "error.wrongPhase"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local indices = {}
	local seen: { [number]: boolean } = {}
	for i, value in raw do
		local index = tonumber(value)
		if i > 200 then
			break
		end
		if index and index == math.floor(index) and not seen[index] then
			seen[index] = true
			table.insert(indices, index)
		end
	end
	return dismantleIndices(player, indices)
end

local function dismantleAll(player: Player, maxRarity: number): (boolean, string?, any)
	local char = character(player)
	if not char then
		return false, "error.wrongPhase"
	end
	if not nearSmith(player) then
		return false, "npc.error.tooFar"
	end
	local limit = math.clamp(maxRarity, Rarities.COMMON, Rarities.UNCOMMON)
	local indices = {}
	for key, item in char.inventory do
		if item.rarity <= limit and Dismantle.canDismantle(item) then
			table.insert(indices, tonumber(key) :: number)
		end
	end
	return dismantleIndices(player, indices)
end

function BlacksmithService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	StatService = registry.Get("StatService")
	AnnounceService = registry.Get("AnnounceService")
end

function BlacksmithService.Start()
	Net.Handle("Craft", craft)
	Net.Handle("UpgradeItem", upgrade)
	Net.Handle("Dismantle", dismantle)
	Net.Handle("DismantleAll", dismantleAll)
end

return BlacksmithService
