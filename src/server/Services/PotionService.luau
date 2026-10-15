--!strict
-- Potions (DESIGN §9): three bar slots (hp / mana / energy) holding a chosen potion id, a shared cooldown
-- per kind (Logic/Potions.interval of the character level, S54) and drinking from the backpack. Cooldowns replicate
-- as state branch `potions` = { [kind] = server time when ready }.
-- S122: the Elixir of Wholeness (use.kind "fullElixir", DESIGN-17 §3) fits every bar slot and restores everything;
-- its own cooldown and daily limit are saved on the character (Logic/FullElixir), where it does not work is the one
-- list Logic/UseBlocks.LISTS.fullElixir asked through src/server/UseGuards. It never goes through `drink`.
-- S126: guards of the ordinary potions (AddGuard: ArenaService counts the potions of a ranked match) and the Drank
-- signal after every ordinary potion.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared

local Signal = require(ReplicatedStorage.Packages.Signal)

local Analytics = require(script.Parent.Parent.Analytics)
local Config = require(Shared.Config)
local FullElixir = require(Shared.Logic.FullElixir)
local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local Potions = require(Shared.Logic.Potions)
local QuestEvents = require(script.Parent.Parent.QuestEvents)
local Types = require(Shared.Types)
local UseBlocks = require(Shared.Logic.UseBlocks)
local UseGuards = require(script.Parent.Parent.UseGuards)

local PotionService = {
	Name = "PotionService",
	Deps = { "PlayerStateService", "CharacterService", "InventoryService", "ResourceService" },
	-- S126: (player, itemId) after an ordinary potion was drunk (never the Elixir of Wholeness)
	Drank = Signal.new(),
}

-- S126: a guard returns an error key to refuse an ordinary potion (checked after the level, before the cooldown).
export type Guard = (player: Player, def: Items.ItemDef) -> string?
local guards: { Guard } = {}

local PlayerStateService: any
local CharacterService: any
local InventoryService: any
local ResourceService: any

local KINDS: { [string]: boolean } = { hp = true, mana = true, energy = true }
local readyAt: { [Player]: { [string]: number } } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
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
	for _, guard in guards do
		local refused = guard(player, def :: Items.ItemDef)
		if refused then
			return false, refused
		end
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
	PotionService.Drank:Fire(player, item.id)
	return true, nil
end

-- S126: adds a guard of the ordinary potions (the first refusal wins).
function PotionService.AddGuard(guard: Guard)
	table.insert(guards, guard)
end

-- S122: drinks the Elixir of Wholeness at `index` (backpack or any bar slot). Place blocks first (UseGuards), then
-- the saved cooldown, the daily limit and "already full"; consuming, restoring and counting happen without a yield.
local function drinkFull(player: Player, index: number): (boolean, string?)
	local item = InventoryService.Get(player, index)
	local def = item and Items.get(item.id)
	if not item or not def or not def.use or def.use.kind ~= "fullElixir" then
		return false, "inventory.cannotUse"
	end
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	local reason = UseGuards.first(player, UseBlocks.LISTS.fullElixir)
	if reason then
		return false, UseBlocks.key("fullElixir", reason)
	end
	local t = os.time()
	local state = character.fullElixir
	local ok, err = FullElixir.check(state, t, {
		hp = ResourceService.Missing(player, "hp"),
		mana = ResourceService.Missing(player, "mana"),
		energy = ResourceService.Missing(player, "energy"),
	})
	if not ok then
		return false, err
	end
	local counted = FullElixir.count(state, t)
	InventoryService.ConsumeAt(player, index)
	ResourceService.Restore(player)
	PlayerStateService.Set(player, { "character", "fullElixir" }, counted)
	-- no QuestEvents "potion": the elixir does not count for "drink a potion" objectives (DECYZJE S122)
	Net.Fire(
		player,
		"Toast",
		"fullElixir.used",
		{ left = FullElixir.leftToday(counted, t), max = Config.FullElixir.dailyLimit },
		"success"
	)
	Analytics.custom(player, "FullElixir", 1)
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
	local def = Items.get(itemId)
	if def and def.use and def.use.kind == "fullElixir" then
		return drinkFull(player, index)
	end
	return drink(player, index)
end

local function setPotionSlot(player: Player, kind: string, itemId: string?): (boolean, string?)
	if not KINDS[kind] then
		return false, "error.badRequest"
	end
	-- S122: one rule for every slot (Potions.fitsSlot): the Elixir of Wholeness fits all three
	if itemId ~= nil and not Potions.fitsSlot(Items.get(itemId), kind) then
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
	InventoryService.UseHandlers.fullElixir = function(player: Player, index: number)
		return drinkFull(player, index)
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
