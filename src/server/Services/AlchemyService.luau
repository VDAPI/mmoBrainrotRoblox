--!strict
-- Alchemist (DESIGN §10): orders brew in real time (Util/Clock, so they finish offline too), 3 parallel
-- orders (+1 with VIP). Starting an order takes the ingredients and gold at once; collecting moves finished
-- results into the backpack (orders that do not fit stay in the queue). Players get a toast when an order
-- finishes and on entering the world when something is waiting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Clock = require(Shared.Util.Clock)
local ItemRoll = require(Shared.Logic.ItemRoll)
local Log = require(Shared.Util.Log)
local Net = require(Shared.Net)
local Npcs = require(Shared.Data.Npcs)
local Recipes = require(Shared.Data.Recipes)
local Time = require(Shared.Logic.Time)
local Types = require(Shared.Types)

local log = Log.new("AlchemyService")

local AlchemyService = {
	Name = "AlchemyService",
	Deps = { "PlayerStateService", "InventoryService", "NpcService", "MonetizationService", "CharacterService" },
}

local CHECK_INTERVAL = 5

local PlayerStateService: any
local InventoryService: any
local NpcService: any
local MonetizationService: any
local CharacterService: any

-- Orders already announced as ready (by readyAt + recipe), per player.
local notified: { [Player]: { [string]: boolean } } = {}

local function character(player: Player): Types.CharacterData?
	return PlayerStateService.GetCharacter(player)
end

local function orderKey(order: Time.Order): string
	return `{order.recipeId}@{order.readyAt}`
end

function AlchemyService.Slots(player: Player): number
	return if MonetizationService.HasPass(player, "vip") then Recipes.QUEUE_SLOTS_VIP else Recipes.QUEUE_SLOTS
end

local function nearAlchemist(player: Player, npcId: string): boolean
	local def = Npcs.get(npcId)
	return def ~= nil and table.find(def.services, "alchemy" :: any) ~= nil and NpcService.Near(player, npcId)
end

local function startRecipe(player: Player, npcId: string, recipeId: string): (boolean, string?)
	local char = character(player)
	local recipe = Recipes.get(recipeId)
	if not char or not recipe then
		return false, "error.badRequest"
	end
	if not nearAlchemist(player, npcId) then
		return false, "npc.error.tooFar"
	end
	if char.level < recipe.level then
		return false, "alchemy.error.level"
	end
	if not Time.canQueue(char.alchemy, AlchemyService.Slots(player)) then
		return false, "alchemy.error.queueFull"
	end
	if char.gold < recipe.gold then
		return false, "shop.error.gold"
	end
	for _, ingredient in recipe.ingredients do
		if InventoryService.Count(player, ingredient.id) < ingredient.n then
			return false, "smith.missing"
		end
	end
	for _, ingredient in recipe.ingredients do
		InventoryService.Remove(player, ingredient.id, ingredient.n)
	end
	PlayerStateService.Update(player, { "character", "gold" }, function(gold: number)
		return gold - recipe.gold
	end)
	PlayerStateService.ArrayInsert(player, { "character", "alchemy" }, {
		recipeId = recipe.id,
		readyAt = Clock.now() + recipe.time,
	})
	log:info("%s started %s", player.Name, recipe.id)
	return true, nil
end

local function collect(player: Player, npcId: string): (boolean, string?, number?)
	local char = character(player)
	if not char then
		return false, "error.badRequest"
	end
	if not nearAlchemist(player, npcId) then
		return false, "npc.error.tooFar"
	end
	local ready = Time.readyItems(char.alchemy, Clock.now())
	if #ready == 0 then
		return false, "alchemy.error.nothingReady"
	end
	local collected = 0
	-- Highest index first so removals do not shift the remaining ones.
	for i = #ready, 1, -1 do
		local index = ready[i]
		local order = char.alchemy[index]
		local recipe = order and Recipes.get(order.recipeId)
		if recipe then
			local stack = ItemRoll.makeStack(recipe.result.id, recipe.result.n, "check")
			if InventoryService.CanFit(player, { stack }) then
				InventoryService.GiveNew(player, recipe.result.id, recipe.result.n)
				PlayerStateService.ArrayRemove(player, { "character", "alchemy" }, index)
				collected += 1
			end
		else
			-- Recipe removed from data: drop the order.
			PlayerStateService.ArrayRemove(player, { "character", "alchemy" }, index)
		end
	end
	if collected == 0 then
		return false, "inventory.full"
	end
	return true, nil, collected
end

local function checkReady(player: Player, onEnter: boolean)
	local char = character(player)
	if not char then
		return
	end
	local seen = notified[player] or {}
	notified[player] = seen
	local now = Clock.now()
	local fresh = 0
	for _, order in char.alchemy do
		local key = orderKey(order)
		if order.readyAt <= now and not seen[key] then
			seen[key] = true
			fresh += 1
			if not onEnter then
				local recipe = Recipes.get(order.recipeId)
				if recipe then
					Net.Fire(player, "Toast", "alchemy.ready", { name = `#item:{recipe.result.id}:0` }, "success")
				end
			end
		end
	end
	if onEnter and fresh > 0 then
		Net.Fire(player, "Toast", "alchemy.readyLogin", { n = fresh }, "success")
	end
end

function AlchemyService.CheckAll()
	for _, player in Players:GetPlayers() do
		if PlayerStateService.HasState(player) then
			checkReady(player, false)
		end
	end
end

function AlchemyService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	NpcService = registry.Get("NpcService")
	MonetizationService = registry.Get("MonetizationService")
	CharacterService = registry.Get("CharacterService")
end

function AlchemyService.Start()
	Net.Handle("StartRecipe", startRecipe)
	Net.Handle("CollectAlchemy", collect)

	CharacterService.CharacterEntered:Connect(function(player: Player)
		notified[player] = {}
		task.delay(3, function()
			if PlayerStateService.HasState(player) then
				checkReady(player, true)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		notified[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			AlchemyService.CheckAll()
		end
	end)
end

return AlchemyService
