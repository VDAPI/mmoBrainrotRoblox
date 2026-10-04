--!strict
-- Scrolls (DESIGN §13): Oblivion (refund stat points), Rebirth (reset the skill tree), Unbinding (pick a
-- bound item — UnbindItem — and unbind it, uniques too). Scrolls of Protection are consumed by the
-- blacksmith; using one from the backpack only explains that.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local Items = require(Shared.Data.Items)
local Net = require(Shared.Net)
local Types = require(Shared.Types)

local ScrollService = {
	Name = "ScrollService",
	Deps = { "PlayerStateService", "InventoryService", "LevelService", "SkillService" },
}

local PlayerStateService: any
local InventoryService: any
local LevelService: any
local SkillService: any

local function useScroll(player: Player, index: number, item: Types.ItemInstance): (boolean, string?)
	local def = Items.get(item.id)
	local target = def and def.use and def.use.target
	if target == "oblivion" then
		InventoryService.ConsumeAt(player, index)
		LevelService.ResetStats(player)
		Net.Fire(player, "Toast", "scroll.oblivion.done", nil, "success")
		return true, nil
	elseif target == "skillreset" then
		-- SkillService consumes one scroll from the backpack itself.
		local ok, err = SkillService.Reset(player, false)
		if ok then
			Net.Fire(player, "Toast", "skills.reset.done", nil, "success")
		end
		return ok, err
	elseif target == "protection" then
		return false, "scroll.protection.hint"
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
	SkillService = registry.Get("SkillService")
	InventoryService.UseHandlers.scroll = useScroll
end

function ScrollService.Start()
	Net.Handle("UnbindItem", unbind)
end

return ScrollService
