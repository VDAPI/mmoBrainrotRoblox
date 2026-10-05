--!strict
-- Playable classes (DESIGN §4.2–4.3). Data only.

local Types = require("../Types")

export type ClassDef = {
	id: Types.ClassId,
	nameKey: string,
	roleKey: string,
	descKey: string,
	mainStats: { Types.StatId },
	resource: Types.ResourceId,
	startStats: Types.Stats,
	weaponTypes: { string },
	offhandTypes: { string },
	-- Basic attack before a weapon defines it (S03): damage type, range class and visual style.
	basicAttack: { kind: "phys" | "magic", ranged: boolean, style: "melee" | "arrow" | "bolt" },
	color: string, -- hex, used for UI accents and placeholder icons
	icon: string, -- placeholder glyph until real icons exist
}

local Classes: { [Types.ClassId]: ClassDef } = {
	Warrior = {
		id = "Warrior",
		nameKey = "class.Warrior.name",
		roleKey = "class.Warrior.role",
		descKey = "class.Warrior.desc",
		mainStats = { "str" },
		resource = "energy",
		startStats = { str = 10, dex = 5, int = 3, vit = 8 },
		weaponTypes = { "sword1h", "axe1h", "mace1h", "saber1h", "sword2h", "axe2h", "hammer2h", "spear2h" },
		offhandTypes = { "shield" },
		basicAttack = { kind = "phys", ranged = false, style = "melee" },
		color = "#C0503C",
		icon = "⚔",
	},
	Hunter = {
		id = "Hunter",
		nameKey = "class.Hunter.name",
		roleKey = "class.Hunter.role",
		descKey = "class.Hunter.desc",
		mainStats = { "dex" },
		resource = "energy",
		startStats = { str = 5, dex = 10, int = 3, vit = 8 },
		weaponTypes = { "shortbow", "bow", "longbow", "crossbow", "heavycrossbow" },
		offhandTypes = { "quiver" },
		basicAttack = { kind = "phys", ranged = true, style = "arrow" },
		color = "#4FA35A",
		icon = "➶",
	},
	Mage = {
		id = "Mage",
		nameKey = "class.Mage.name",
		roleKey = "class.Mage.role",
		descKey = "class.Mage.desc",
		mainStats = { "int" },
		resource = "mana",
		startStats = { str = 3, dex = 5, int = 10, vit = 8 },
		weaponTypes = { "wand", "staff", "runestaff" },
		offhandTypes = { "tome", "orb" },
		basicAttack = { kind = "magic", ranged = true, style = "bolt" },
		color = "#4A8FE7",
		icon = "✦",
	},
	Cleric = {
		id = "Cleric",
		nameKey = "class.Cleric.name",
		roleKey = "class.Cleric.role",
		descKey = "class.Cleric.desc",
		mainStats = { "int", "vit" },
		resource = "mana",
		startStats = { str = 4, dex = 4, int = 9, vit = 9 },
		weaponTypes = { "mace1h", "scepter", "flail1h", "holystaff" },
		offhandTypes = { "shield", "relic" },
		basicAttack = { kind = "magic", ranged = false, style = "melee" },
		color = "#E8C25A",
		icon = "✚",
	},
}

-- Display order on the class picker.
local ORDER: { Types.ClassId } = { "Warrior", "Hunter", "Mage", "Cleric" }

return table.freeze({
	byId = Classes,
	order = ORDER,
	get = function(id: string): ClassDef?
		return (Classes :: any)[id]
	end,
})
