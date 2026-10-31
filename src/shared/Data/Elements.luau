--!strict
-- Elements (DESIGN §5.8, §14.4). Mage weapons carry one of WEAPON (fire, ice, lightning); element skills
-- need a matching weapon. Colours are shared by the UI (tooltips, icons) and the skill / combat effects.

export type Element = "fire" | "ice" | "lightning" | "poison"

local WEAPON: { Element } = { "fire", "ice", "lightning" }
local DEFAULT: Element = "fire"

local COLORS: { [string]: string } = {
	fire = "#FF7A1A",
	ice = "#9FE0FF",
	lightning = "#F2E85A",
	poison = "#7ACB3A",
}

return table.freeze({
	WEAPON = table.freeze(WEAPON),
	COLORS = table.freeze(COLORS),
	-- Default element of mage weapons created before S18 (and of the Mage's starting wand).
	DEFAULT = DEFAULT,
	isWeaponElement = function(id: any): boolean
		return type(id) == "string" and table.find(WEAPON, id :: any) ~= nil
	end,
	-- The element of a Mage weapon instance (nil for any other item): a named weapon's own element (ItemDef.element,
	-- 2026-10-31: the Staff of Endless Winter is always ice, whatever the instance says), else the instance's `el`,
	-- else DEFAULT (weapons from before S18). The one rule for ItemRoll.elementOf, ItemEffects and ItemIcons.
	weaponElement = function(def: { elemental: boolean?, element: string? }?, el: any): string?
		if not def or not def.elemental then
			return nil
		end
		if type(def.element) == "string" and table.find(WEAPON, def.element :: any) then
			return def.element
		end
		return if type(el) == "string" and table.find(WEAPON, el :: any) then el else DEFAULT
	end,
	nameKey = function(id: string): string
		return `element.{id}`
	end,
	suffixKey = function(id: string): string
		return `element.suffix.{id}`
	end,
})
