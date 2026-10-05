--!strict
-- Elements (DESIGN §5.8, §14.4). Mage weapons carry one of WEAPON (fire, ice, lightning); element skills
-- need a matching weapon. Colours are shared by the UI (tooltips, icons) and the skill / combat effects.

export type Element = "fire" | "ice" | "lightning" | "poison"

local WEAPON: { Element } = { "fire", "ice", "lightning" }

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
	DEFAULT = "fire" :: Element,
	isWeaponElement = function(id: any): boolean
		return type(id) == "string" and table.find(WEAPON, id :: any) ~= nil
	end,
	nameKey = function(id: string): string
		return `element.{id}`
	end,
	suffixKey = function(id: string): string
		return `element.suffix.{id}`
	end,
})
