--!strict
-- Potion interval (S54, ROZWOJ 8, owner answer 28): Config.PotionCooldown x the "potionCooldown" level curve, so
-- 1.5 s up to level 20, 6 s at 45 and ~10 s from 70. The only source of the interval for PotionService, the potion
-- bar and the wiki. S87: the level a potion needs (requiredLevel, canDrink). Pure.

local Config = require("../Config")
local Items = require("../Data/Items")
local LevelCurves = require("./LevelCurves")

local Potions = {}

-- S87 (balance plan D3): the character level a potion needs (its definition's level: Great 45, Mighty 70); 1 for
-- anything that is not a potion. Old stacks carry ilvl 1, so the rule reads the definition, never the stack.
function Potions.requiredLevel(def: Items.ItemDef?): number
	if def and def.use and def.use.kind == "potion" then
		return def.level or 1
	end
	return 1
end

-- Whether a character of `level` may drink the potion `def` (PotionService.drink; the shop, the backpack and the
-- tooltip show the same threshold).
function Potions.canDrink(def: Items.ItemDef?, level: number): boolean
	return level >= Potions.requiredLevel(def)
end

-- Whether `def` may sit in the potion bar slot `kind` ("hp" | "mana" | "energy"): a potion of that resource.
-- S122: the Elixir of Wholeness fits every potion slot. PotionService.setPotionSlot, the drop on a slot
-- (ItemController) and the slot's choice list (PotionBar) use this one rule.
function Potions.fitsSlot(def: Items.ItemDef?, kind: string): boolean
	local use = def and def.use
	if not use then
		return false
	end
	return (use.kind == "potion" and use.resource == kind) or use.kind == "fullElixir"
end

-- Seconds between two potions of the same kind at character level `level`.
function Potions.interval(level: number): number
	return Config.PotionCooldown * LevelCurves.at("potionCooldown", level)
end

return Potions
