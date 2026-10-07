--!strict
-- Loot bags (DESIGN §5.5). On MonsterKilled each credited player gets a bag visible only to them (LootSpawn).
-- The server keeps the contents; PickupLoot validates owner, distance and backpack room (partial pickups
-- leave the rest in the bag). Bags expire after Config.LootLifetime. Named boss items and every Mythic bind on pickup.
-- Equipment whose rarity announces (S30: Legendary, Mythic) is announced to the whole server and to other servers
-- (AnnounceService); Mythic has its own, stronger message (`loot.announceMythic`).
-- S20: the owner's loot filter hides weak equipment and limits Auto-loot (Logic/LootFilter); picked-up
-- equipment goes to the character's loot log (last 50, with source monster and map).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Analytics = require(script.Parent.Parent.Analytics)
local Products = require(Shared.Data.Products)

local Config = require(Shared.Config)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Items = require(Shared.Data.Items)
local Loot = require(Shared.Logic.Loot)
local LootFilter = require(Shared.Logic.LootFilter)
local Net = require(Shared.Net)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local PartyLoot = require(Shared.Logic.PartyLoot)
local Rarities = require(Shared.Data.Rarities)
local Rng = require(Shared.Logic.Rng)
local Types = require(Shared.Types)

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
		"AnnounceService",
		"PartyService",
	},
}

type Bag = {
	id: string,
	owner: Player,
	position: Vector3,
	items: { ItemInstance },
	expiresAt: number,
	legendary: boolean, -- holds equipment with a reveal (Legendary or Mythic)
	mythic: boolean, -- holds Mythic equipment
	best: number, -- best equipment rarity (bag colour)
	personal: boolean?, -- a boss's personal roll (S30)
	source: string?, -- monster kind (loot log)
}

local LOOT_LOG_SIZE = 50

local PlayerStateService: any
local CharacterService: any
local CombatService: any
local InventoryService: any
local StatService: any
local MonetizationService: any
local AnnounceService: any
local PartyService: any

local PICKUP_TOLERANCE = 4

local bags: { [string]: Bag } = {}
local rng = Rng.new()

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
		mythic = bag.mythic,
		best = bag.best,
		personal = bag.personal == true,
		expiresIn = bag.expiresAt - os.clock(),
	}
end

-- Announcements -------------------------------------------------------------------------------------------

local function isEquipment(item: ItemInstance): boolean
	local def = Items.get(item.id)
	return def ~= nil and def.category == "equipment"
end

-- Server-wide announcement of an equipment drop whose rarity announces (only `category == "equipment"`, so a
-- Mythic blessing never does). Returns whether it announced.
local function announceDrop(player: Player, item: ItemInstance): boolean
	local kind = Rarities.get(item.rarity).announce
	if kind == nil or not isEquipment(item) then
		return false
	end
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	local name = if character then character.name else player.Name
	local args = { player = name, item = `#item:{item.id}:{item.up}`, rarity = item.rarity }
	if kind == "mythic" then
		Analytics.custom(player, "MythicDrop", item.ilvl)
		AnnounceService.Global("loot.announceMythic", "loot.announceMythicGlobal", args)
	else
		Analytics.custom(player, "LegendaryDrop", item.ilvl)
		AnnounceService.Global("loot.announce", "loot.announceGlobal", args)
	end
	return true
end

-- Bags ----------------------------------------------------------------------------------------------------

local function settingsOf(player: Player): { [string]: any }
	local settings = PlayerStateService.Get(player, { "account", "settings" })
	return if type(settings) == "table" then settings else {}
end

local function decision(player: Player, item: ItemInstance): LootFilter.Decision
	local def = Items.get(item.id)
	local settings = settingsOf(player)
	return LootFilter.decide(
		if def then def.category else "material",
		item.rarity,
		tonumber(settings.lootHideBelow),
		tonumber(settings.lootAutoFrom),
		MonetizationService.HasPass(player, "autoLoot")
	)
end

-- Creates a bag for `owner` at `position` (also used by /legend). Returns the bag id. Items the owner's
-- loot filter hides are not dropped at all.
function LootService.SpawnBag(
	owner: Player,
	position: Vector3,
	items: { ItemInstance },
	source: string?,
	personal: boolean?
): string?
	local kept = {}
	for _, item in items do
		if decision(owner, item) ~= "hide" then
			table.insert(kept, item)
		end
	end
	items = kept
	if #items == 0 then
		return nil
	end
	local legendary, mythic, best = false, false, Rarities.COMMON
	for _, item in items do
		if isEquipment(item) then
			local rarity = Rarities.get(item.rarity)
			legendary = legendary or rarity.reveal
			mythic = mythic or rarity.id == Rarities.MYTHIC
			best = math.max(best, rarity.id)
		end
	end
	local bag: Bag = {
		id = HttpService:GenerateGUID(false),
		owner = owner,
		position = position,
		items = items,
		expiresAt = os.clock() + Config.LootLifetime,
		legendary = legendary,
		mythic = mythic,
		best = best,
		personal = personal,
		source = source,
	}
	bags[bag.id] = bag
	Net.Fire(owner, "LootSpawn", summary(bag))
	for _, item in items do
		announceDrop(owner, item)
	end
	return bag.id
end

local function instancesFrom(loot: Loot.LootResult): { ItemInstance }
	local items: { ItemInstance } = {}
	for _, drop in loot.items do
		table.insert(
			items,
			ItemRoll.rollItem(drop.defId, drop.ilvl, drop.rarity, rng, HttpService:GenerateGUID(false), drop.forClass)
		)
	end
	for _, material in loot.materials do
		table.insert(items, ItemRoll.makeStack(material.id, material.n, HttpService:GenerateGUID(false)))
	end
	return items
end

-- Adds picked-up equipment to the character's loot log (newest first).
local function logLoot(player: Player, bag: Bag, picked: { ItemInstance })
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return
	end
	local log = table.clone(character.lootLog or {})
	for _, item in picked do
		local def = Items.get(item.id)
		if def and def.category == "equipment" then
			table.insert(log, 1, {
				id = item.id,
				rarity = item.rarity,
				ilvl = item.ilvl,
				el = item.el,
				at = os.time(),
				src = bag.source,
				map = character.location.map,
			})
		end
	end
	while #log > LOOT_LOG_SIZE do
		table.remove(log)
	end
	PlayerStateService.Set(player, { "character", "lootLog" }, log)
end

-- Picks up as much of the bag as fits (only the items `only` accepts, when given). Returns (ok, errorKey?).
function LootService.Pickup(
	player: Player,
	bagId: string,
	ignoreDistance: boolean?,
	only: ((item: ItemInstance) -> boolean)?
): (boolean, string?)
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
		if only and not only(item) then
			table.insert(remaining, item)
			continue
		end
		local def = Items.get(item.id)
		if def and (def.bindOnPickup or (def.category == "equipment" and Rarities.get(item.rarity).bindOnPickup)) then
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
		QuestEvents.fire(player, "loot", nil)
		logLoot(player, bag, picked)
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

-- Splits `items` between party members (DESIGN §17) and drops one bag per member. Equipment is announced
-- in the party chat.
function LootService.DistributeToParty(members: { Player }, position: Vector3, items: { ItemInstance }, source: string?)
	if #members == 0 or #items == 0 then
		return
	end
	if #members == 1 then
		LootService.SpawnBag(members[1], position, items, source)
		return
	end
	local candidates: { PartyLoot.Candidate } = {}
	local byId: { [number]: Player } = {}
	for _, member in members do
		local character: Types.CharacterData? = PlayerStateService.GetCharacter(member)
		if character then
			table.insert(candidates, { id = member.UserId, classId = character.class :: string })
			byId[member.UserId] = member
		end
	end
	local lootItems: { PartyLoot.LootItem } = {}
	for _, item in items do
		local def = Items.get(item.id)
		table.insert(lootItems, { uid = item.uid, classes = if def then def.classes else nil })
	end
	local assigned = PartyLoot.distribute(lootItems, candidates, rng)
	local perMember: { [Player]: { ItemInstance } } = {}
	for _, item in items do
		local owner = byId[assigned[item.uid] or 0]
		if owner then
			local list = perMember[owner] or {}
			table.insert(list, item)
			perMember[owner] = list
			local def = Items.get(item.id)
			local party = PartyService.Get(owner)
			if party and def and def.category == "equipment" then
				local character: Types.CharacterData? = PlayerStateService.GetCharacter(owner)
				PartyService.Notify(party, "party.lootItem", {
					name = if character then character.name else owner.DisplayName,
					item = `#item:{item.id}:{item.up}`,
				})
			end
		end
	end
	for member, list in perMember do
		LootService.SpawnBag(member, position, list, source)
	end
end

local function onMonsterKilled(info: any, credit: { Player })
	if info.boss or #credit == 0 then
		return
	end
	-- One roll per monster with the top damage dealer's bonuses and class preference (also in a party,
	-- before the loot is split; S18); parties share it.
	local killer = credit[1]
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(killer)
	if not character then
		return
	end
	local loot = Loot.rollMonsterLoot(info.monsterId, info.variant, info.level, rng, {
		dropBonus = StatService.GetValue(killer, "dropBonus"),
		classId = character.class :: string,
		dropLevel = info.dropLevel,
	})
	LootService.DistributeToParty(credit, info.position, instancesFrom(loot), info.monsterId)
end

-- Rolls items for a loot result (used by DungeonService for boss loot).
function LootService.InstancesFrom(loot: Loot.LootResult): { ItemInstance }
	return instancesFrom(loot)
end

-- Admin: rolls a Legendary (or `rarity`) item for the player's class and drops it in front of them.
function LootService.DropLegendary(player: Player, rarity: number?): boolean
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
	local item = ItemRoll.rollItem(defId, level, rarity or Rarities.LEGENDARY, rng, HttpService:GenerateGUID(false))
	local position = (model:GetPivot() * CFrame.new(0, -2.5, -8)).Position
	LootService.SpawnBag(player, position, { item })
	return true
end

-- Admin: n simulated kills. Returns counts per rarity, materials and gold.
function LootService.Simulate(monsterId: string, variant: string, level: number, n: number, classId: string?)
	local counts = table.create(Rarities.MAX, 0)
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

-- Number of loot bags on the server (/perf).
function LootService.BagCount(): number
	local n = 0
	for _ in bags do
		n += 1
	end
	return n
end

function LootService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	CombatService = registry.Get("CombatService")
	InventoryService = registry.Get("InventoryService")
	StatService = registry.Get("StatService")
	MonetizationService = registry.Get("MonetizationService")
	AnnounceService = registry.Get("AnnounceService")
	PartyService = registry.Get("PartyService")
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

	-- "Auto-loot" gamepass: bags within Products.AUTO_LOOT_RANGE studs are picked up on their own
	-- (as much as fits; a full backpack leaves the rest in the bag).
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, bag in table.clone(bags) do
				local owner = bag.owner
				if owner.Parent and MonetizationService.HasPass(owner, "autoLoot") then
					local root = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					local retryAt = (bag :: any).autoRetryAt or 0
					if
						root
						and os.clock() >= retryAt
						and (root.Position - bag.position).Magnitude <= Products.AUTO_LOOT_RANGE
					then
						-- Only what the loot filter lets Auto-loot take; the rest waits in the bag.
						local _, err = LootService.Pickup(owner, bag.id, true, function(item)
							return decision(owner, item) == "pickup"
						end)
						if err == "loot.partial" then
							(bag :: any).autoRetryAt = os.clock() + 5 -- full backpack: do not spam
						end
					end
				end
			end
		end
	end)

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
end

return LootService
