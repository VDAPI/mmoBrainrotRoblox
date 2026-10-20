--!strict
-- Scrolls (DESIGN §13): Oblivion (refund stat points; the active build set only, ROZWOJ 2.9), Skill Renewal (S138,
-- DESIGN-18 §3.2: PathService.FullReset, every pool's ranks and the active set's nodes; used up only on success and
-- never with respecFree or below Progression.freeRespecLevel; the client asks first), Unbinding (pick a bound item — UnbindItem — and unbind it, uniques too). Scrolls of Protection are consumed by the
-- blacksmith; using one from the backpack only explains that (S134j: the Stone of Transmutation too).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local ScrollService = {
	Name = "ScrollService",
	Deps = { "PlayerStateService", "InventoryService", "LevelService", "PathService" },
}

local PlayerStateService: any
local InventoryService: any
local LevelService: any
local PathService: any

local function useScroll(player: Player, index: number, item: Types.ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	local target = def and def.use and def.use.target
	if target == "oblivion" then
		InventoryService.ConsumeAt(player, index)
		LevelService.ResetStats(player)
		Net.Fire(player, "Toast", "scroll.oblivion.done", nil, "success")
		return true, nil
	elseif target == "skillreset" then
		-- S138: Scroll of Skill Renewal = the full reset (PathService takes the scroll when it pays)
		return PathService.FullReset(player)
	elseif target == "protection" then
		return false, "scroll.protection.hint"
	elseif target == "transmute" then
		-- S134j: the Stone of Transmutation is taken by the blacksmith (Reroll tab), never used up here
		return false, "item.reroll_stone.useHint"
	elseif target == "transmuteAll" then
		-- S156: the Scroll of Transformation too
		return false, "item.transmute_scroll.useHint"
	elseif target == "unbind" then
		-- The client opens the item picker and calls UnbindItem.
		return false, "scroll.unbind.pick"
	end
	return false, "inventory.cannotUse"
end

local function unbind(player: Player, location: string, key: string): (boolean, string?)
	local character: Types.CharacterData? = PlayerStateService.GetCharacter(player)
	if not character then
		return false, "error.wrongPhase"
	end
	if InventoryService.Count(player, "scroll_unbind") < 1 then
		return false, "inventory.cannotUse"
	end
	local item: Types.ItemInstance?
	if location == "eq" and key ~= "backpack" then
		item = character.equipment[key]
	elseif location == "inv" then
		local index = tonumber(key)
		item = if index then InventoryService.Get(player, index) else nil
	end
	local def = item and Items.get(item.id)
	if not item or not def or def.category ~= "equipment" or not item.bound then
		return false, "error.badRequest"
	end
	InventoryService.Remove(player, "scroll_unbind", 1)
	item.bound = false
	if location == "eq" then
		PlayerStateService.Set(player, { "character", "equipment", key }, item)
	else
		InventoryService.SetSlot(player, tonumber(key) :: number, item)
	end
	return true, nil
end

function ScrollService.Init(registry)
	PlayerStateService = registry.Get("PlayerStateService")
	InventoryService = registry.Get("InventoryService")
	LevelService = registry.Get("LevelService")
	PathService = registry.Get("PathService")
	InventoryService.UseHandlers.scroll = useScroll
end

function ScrollService.Start()
	Net.Handle("UnbindItem", unbind)
end

return ScrollService
