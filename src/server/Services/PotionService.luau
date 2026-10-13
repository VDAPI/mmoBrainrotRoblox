--!strict
-- Potions (DESIGN §9): three bar slots (hp / mana / energy) holding a chosen potion id, a shared cooldown
-- per kind (Logic/Potions.interval of the character level, S54) and drinking from the backpack. Cooldowns replicate
-- as state branch `potions` = { [kind] = server time when ready }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local Potions = require(Shared.Logic.Potions)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Types = require(Shared.Types)

local PotionService = {
	Name = "PotionService",
	Deps = { "PlayerStateService", "CharacterService", "InventoryService", "ResourceService" },
}

local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local ResourceService: any

local KINDS: { [string]: boolean } = { hp = true, mana = true, energy = true }
local readyAt: { [Player]: { [string]: number } } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function potionResource(itemId: string): string?
	local def = Items.get(itemId)
	local use = def and def.use
	return if use and use.kind == "potion" then use.resource else nil
end

-- Drinks the potion stack at `index`. Returns (ok, errorKey?).
local function drink(player: Player, index: number): (boolean, string?)
	local item = InventoryService.Get(player, index)
	local def = item and Items.get(item.id)
	local use = def and def.use
	if not item or not use or use.kind ~= "potion" or not use.resource then
		return false, "inventory.cannotUse"
	end
	local resource = use.resource :: "hp" | "mana" | "energy"
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	if ResourceService.IsDead(player) then
		return false, "error.wrongPhase"
	end
	-- S87 (balance plan D3): Great potions from 45, Mighty from 70 (old stacks too: the definition decides)
	if not Potions.canDrink(def, character.level) then
		return false, "potion.error.level"
	end
	local timers = readyAt[player] or {}
	readyAt[player] = timers
	local t = now()
	if (timers[resource] or 0) > t then
		return false, "potion.cooldown"
	end
	if ResourceService.Missing(player, resource) <= 0 then
		return false, "potion.notNeeded"
	end
	InventoryService.ConsumeAt(player, index)
	ResourceService.Add(player, resource, use.amount or 0)
	timers[resource] = t + Potions.interval(character.level)
	PlayerStateService.Set(player, { "potions", resource }, timers[resource])
	QuestEvents.fire(player, "potion", nil)
	return true, nil
end

-- Hotkey / bar button: drinks the potion assigned to `kind`.
local function usePotion(player: Player, kind: string): (boolean, string?)
	if not KINDS[kind] then
		return false, "error.badRequest"
	end
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	local itemId = (character.potionBar :: any)[kind]
	local index = itemId and InventoryService.Find(player, itemId)
	if not index then
		return false, "potion.none"
	end
	return drink(player, index)
end

local function setPotionSlot(player: Player, kind: string, itemId: string?): (boolean, string?)
	if not KINDS[kind] then
		return false, "error.badRequest"
	end
	if itemId ~= nil and potionResource(itemId) ~= kind then
		return false, "error.badRequest"
	end
	if not PlayerStateService.GetCharacter(player) then
		return false, "error.wrongPhase"
	end
	PlayerStateService.Set(player, { "character", "potionBar", kind }, itemId)
	return true, nil
end

function PotionService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	CharacterService = registry.Get("CharacterService")
	InventoryService = registry.Get("InventoryService")
	ResourceService = registry.Get("ResourceService")
	InventoryService.UseHandlers.potion = function(player: Player, index: number)
		return drink(player, index)
	end
end

function PotionService.Start()
	Net.Handle("UsePotion", usePotion)
	Net.Handle("SetPotionSlot", setPotionSlot)
	CharacterService.CharacterLeaving:Connect(function(player: Player)
		readyAt[player] = nil
		if PlayerStateService.HasState(player) then
			PlayerStateService.Set(player, { "potions" }, nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		readyAt[player] = nil
	end)
end

return PotionService
