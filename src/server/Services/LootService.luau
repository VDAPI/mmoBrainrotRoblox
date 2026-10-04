--!strict
-- Loot bags (DESIGN §5.5). On MonsterKilled each credited player gets a bag visible only to them (LootSpawn).
-- The server keeps the contents; PickupLoot validates owner, distance and backpack room (partial pickups
-- leave the rest in the bag). Bags expire after Config.LootLifetime. Uniques bind on pickup.
-- Legendary drops are announced to the whole server and, rate limited, to other servers (MessagingService).

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared

local Config = require(Shared.Config)
local Inventory = require(Shared.Logic.Inventory)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Log = require(Shared.Util.Log)
local Loot = require(Shared.Logic.Loot)
local Net = require(Shared.Net)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)

local log = Log.new("LootService")

type ItemInstance = Types.ItemInstance

local LootService = {
	Name = "LootService",
	Deps = {
		"PlayerStateService",
		"CharacterService",
		"CombatService",
		"InventoryService",
		"StatService",
		"MonetizationService",
	},
}

type Bag = {
	id: string,
	owner: Player,
	position: Vector3,
	items: { ItemInstance },
	expiresAt: number,
	legendary: boolean,
}

local PlayerStateService: any
local CharacterService: any
local CombatService: any
local InventoryService: any
local StatService: any
local MonetizationService: any

local GLOBAL_TOPIC = "GlobalAnnounce"
local GLOBAL_MIN_INTERVAL = 10 -- seconds between cross-server announcements from this server
local PICKUP_TOLERANCE = 4

local bags: { [string]: Bag } = {}
local rng = Rng.new()
local serverId = HttpService:GenerateGUID(false)
local lastGlobal = 0

local function summary(bag: Bag): { [string]: any }
	local items = {}
	for _, item in bag.items do
		table.insert(items, item)
	end
	return {
		id = bag.id,
		position = bag.position,
		items = items,
		legendary = bag.legendary,
		best = Inventory.bestRarity(bag.items),
		expiresIn = bag.expiresAt - os.clock(),
	}
end

-- Announcements -------------------------------------------------------------------------------------------

function LootService.Announce(key: string, args: { [string]: any })
	Net.FireAll("Announce", key, args)
end

local function announceLegendary(player: Player, item: ItemInstance)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local name = if character then character.name else player.Name
	local args = { player = name, item = `#item:{item.id}:{item.up}` }
	LootService.Announce("loot.announce", args)
	if RunService:IsStudio() or os.clock() - lastGlobal < GLOBAL_MIN_INTERVAL then
		return
	end
	lastGlobal = os.clock()
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:PublishAsync(GLOBAL_TOPIC, { from = serverId, key = "loot.announceGlobal", args = args })
		end)
		if not ok then
			log:warn("global announce failed: %s", tostring(err))
		end
	end)
end

-- Bags ----------------------------------------------------------------------------------------------------

-- Creates a bag for `owner` at `position` (also used by /legend). Returns the bag id.
function LootService.SpawnBag(owner: Player, position: Vector3, items: { ItemInstance }): string?
	if #items == 0 then
		return nil
	end
	local legendary = false
	for _, item in items do
		if item.rarity == Rarities.LEGENDARY then
			legendary = true
		end
	end
	local bag: Bag = {
		id = HttpService:GenerateGUID(false),
		owner = owner,
		position = position,
		items = items,
		expiresAt = os.clock() + Config.LootLifetime,
		legendary = legendary,
	}
	bags[bag.id] = bag
	Net.Fire(owner, "LootSpawn", summary(bag))
	if legendary then
		for _, item in items do
			if item.rarity == Rarities.LEGENDARY then
				announceLegendary(owner, item)
			end
		end
	end
	-- "Auto-loot" gamepass picks everything up at once (S14 makes the pass purchasable).
	if MonetizationService.HasPass(owner, "autoLoot") then
		task.defer(function()
			LootService.Pickup(owner, bag.id, true)
		end)
	end
	return bag.id
end

local function instancesFrom(loot: Loot.LootResult): { ItemInstance }
	local items: { ItemInstance } = {}
	for _, drop in loot.items do
		table.insert(items, ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, rng, HttpService:GenerateGUID(false)))
	end
	for _, material in loot.materials do
		table.insert(items, ItemRoll.makeStack(material.id, material.n, HttpService:GenerateGUID(false)))
	end
	return items
end

-- Picks up as much of the bag as fits. Returns (ok, errorKey?).
function LootService.Pickup(player: Player, bagId: string, ignoreDistance: boolean?): (boolean, string?)
	local bag = bags[bagId]
	if not bag or bag.owner ~= player then
		return false, "loot.gone"
	end
	if not ignoreDistance then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - bag.position).Magnitude > Config.LootPickupRange + PICKUP_TOLERANCE then
			return false, "loot.tooFar"
		end
	end
	local picked: { ItemInstance } = {}
	local remaining: { ItemInstance } = {}
	for _, item in bag.items do
		local def = Items.get(item.id)
		if def and def.bindOnPickup then
			item.bound = true
		end
		local leftover = InventoryService.AddItem(player, item)
		if leftover <= 0 then
			table.insert(picked, item)
		else
			local rest = table.clone(item)
			rest.n = leftover
			table.insert(remaining, rest)
			if leftover < item.n then
				local part = table.clone(item)
				part.n = item.n - leftover
				table.insert(picked, part)
			end
		end
	end
	if #picked > 0 then
		Net.Fire(player, "LootPicked", picked)
	end
	if #remaining > 0 then
		bag.items = remaining
		Net.Fire(player, "LootUpdate", bag.id, remaining)
		return false, "loot.partial"
	end
	bags[bagId] = nil
	Net.Fire(player, "LootRemove", bagId)
	return true, nil
end

local function onMonsterKilled(info: any, credit: { Player })
	for _, player in credit do
		local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
		if character then
			local loot = Loot.rollMonsterLoot(info.monsterId, info.variant, info.level, rng, {
				dropBonus = StatService.GetValue(player, "dropBonus"),
				classId = character.class :: string,
			})
			local items = instancesFrom(loot)
			if #items > 0 then
				LootService.SpawnBag(player, info.position, items)
			end
		end
	end
end

-- Admin: rolls a legendary for the player's class and drops it in front of them.
function LootService.DropLegendary(player: Player): boolean
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local model = player.Character
	if not character or not model then
		return false
	end
	local level = character.level
	local defId: string? = nil
	for _ = 1, 20 do
		defId = Loot.pickItem(
			{ weapon = 4, offhand = 1, armor = 2, helmet = 1, necklace = 1, ring = 1 },
			level,
			1,
			character.class,
			rng
		)
		local def = defId and Items.get(defId)
		if def and (def.classes == nil or table.find(def.classes, character.class)) then
			break
		end
	end
	if not defId then
		return false
	end
	local item = ItemRoll.rollItem(defId, level, Rarities.LEGENDARY, rng, HttpService:GenerateGUID(false))
	local position = (model:GetPivot() * CFrame.new(0, -2.5, -8)).Position
	LootService.SpawnBag(player, position, { item })
	return true
end

-- Admin: n simulated kills. Returns counts per rarity, materials and gold.
function LootService.Simulate(monsterId: string, variant: string, level: number, n: number, classId: string?)
	local counts = { 0, 0, 0, 0, 0, 0 }
	local items, mats, gold = 0, 0, 0
	for _ = 1, n do
		local loot = Loot.rollMonsterLoot(monsterId, variant, level, rng, { classId = classId })
		for _, drop in loot.items do
			counts[drop.rarity] += 1
			items += 1
		end
		for _, material in loot.materials do
			mats += material.n
		end
		gold += loot.gold
	end
	return counts, items, mats, gold
end

function LootService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	CombatService = registry.Get("CombatService")
	InventoryService = registry.Get("InventoryService")
	StatService = registry.Get("StatService")
	MonetizationService = registry.Get("MonetizationService")
end

function LootService.Start()
	CombatService.MonsterKilled:Connect(onMonsterKilled)
	Net.Handle("PickupLoot", function(player: Player, bagId: string)
		return LootService.Pickup(player, bagId, false)
	end)

	-- Bags belong to the character that earned them: switching characters or leaving drops them.
	local function dropBagsOf(player: Player)
		for id, bag in bags do
			if bag.owner == player then
				bags[id] = nil
			end
		end
	end
	CharacterService.CharacterLeaving:Connect(dropBagsOf)
	Players.PlayerRemoving:Connect(dropBagsOf)

	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()
			for id, bag in bags do
				if now >= bag.expiresAt then
					bags[id] = nil
					if bag.owner.Parent then
						Net.Fire(bag.owner, "LootRemove", id)
					end
				end
			end
		end
	end)

	if not RunService:IsStudio() then
		task.spawn(function()
			local ok, err = pcall(function()
				MessagingService:SubscribeAsync(GLOBAL_TOPIC, function(message)
					local data = message.Data
					if type(data) == "table" and data.from ~= serverId and type(data.key) == "string" then
						LootService.Announce(data.key, if type(data.args) == "table" then data.args else {})
					end
				end)
			end)
			if not ok then
				log:warn("cannot subscribe to %s: %s", GLOBAL_TOPIC, tostring(err))
			end
		end)
	end
end

return LootService
