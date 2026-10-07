--!strict
-- Loot filter (S20, DESIGN §5.9): what happens to an item that drops for the player.
--   "show"   : a normal loot bag
--   "hide"   : equipment below the "hide below" rarity is not shown (materials, gold, consumables and
--              rarities with a reveal (Legendary, Mythic) are always shown)
--   "pickup" : picked up automatically (Auto-loot pass) from the "auto from" rarity up
-- Settings: lootHideBelow (rarity, 0 = off), lootAutoFrom (rarity, 0 = everything the pass picks up).

local Rarities = require("../Data/Rarities")

local LootFilter = {}

export type Decision = "show" | "hide" | "pickup"

function LootFilter.decide(
	category: string,
	rarity: number,
	hideBelow: number?,
	autoFrom: number?,
	autoLoot: boolean
): Decision
	local equipment = category == "equipment"
	if autoLoot and (not equipment or rarity >= (autoFrom or 0)) then
		return "pickup"
	end
	if equipment and not Rarities.get(rarity).reveal and rarity < (hideBelow or 0) then
		return "hide"
	end
	return "show"
end

return LootFilter
