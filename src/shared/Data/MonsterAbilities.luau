--!strict
-- Special abilities of Elite II monsters (DESIGN §15.1): telegraphed area attacks. Data only.
--
-- shape:  "circle" (radius) | "cone" (radius + angle in degrees) | "line" (length x width)
-- origin: "self" (around the monster) | "target" (centred on the current target's position)
-- windup: seconds the red telegraph fills before the hit lands
-- damage: multiplier of the monster's attack; element optional

export type Ability = {
	id: string,
	shape: "circle" | "cone" | "line",
	origin: "self" | "target",
	radius: number?,
	angle: number?,
	length: number?,
	width: number?,
	windup: number,
	damage: number,
	cooldown: number,
	element: ("fire" | "ice" | "lightning" | "poison")?,
	damageKind: ("phys" | "magic")?,
}

local ABILITIES: { [string]: Ability } = {
	leap = { id = "leap", shape = "circle", origin = "target", radius = 7, windup = 1.2, damage = 2.6, cooldown = 11 },
	charge = {
		id = "charge",
		shape = "line",
		origin = "self",
		length = 20,
		width = 6,
		windup = 1.0,
		damage = 2.8,
		cooldown = 12,
	},
	cleave = {
		id = "cleave",
		shape = "cone",
		origin = "self",
		radius = 11,
		angle = 100,
		windup = 1.0,
		damage = 2.4,
		cooldown = 9,
	},
	slam = { id = "slam", shape = "circle", origin = "self", radius = 11, windup = 1.4, damage = 3.0, cooldown = 13 },
	poisonPool = {
		id = "poisonPool",
		shape = "circle",
		origin = "target",
		radius = 8,
		windup = 1.3,
		damage = 2.5,
		cooldown = 12,
		element = "poison",
		damageKind = "magic",
	},
	boneNova = {
		id = "boneNova",
		shape = "circle",
		origin = "self",
		radius = 13,
		windup = 1.5,
		damage = 2.6,
		cooldown = 14,
		damageKind = "magic",
	},
	voidPool = {
		id = "voidPool",
		shape = "circle",
		origin = "target",
		radius = 9,
		windup = 1.4,
		damage = 2.7,
		cooldown = 13,
		damageKind = "magic",
	},
	frostNova = {
		id = "frostNova",
		shape = "circle",
		origin = "self",
		radius = 13,
		windup = 1.4,
		damage = 2.6,
		cooldown = 13,
		element = "ice",
		damageKind = "magic",
	},
	wail = {
		id = "wail",
		shape = "cone",
		origin = "self",
		radius = 15,
		angle = 90,
		windup = 1.2,
		damage = 2.4,
		cooldown = 11,
		damageKind = "magic",
	},
	fireBreath = {
		id = "fireBreath",
		shape = "cone",
		origin = "self",
		radius = 17,
		angle = 60,
		windup = 1.3,
		damage = 2.9,
		cooldown = 12,
		element = "fire",
		damageKind = "magic",
	},
	frostBreath = {
		id = "frostBreath",
		shape = "cone",
		origin = "self",
		radius = 17,
		angle = 60,
		windup = 1.3,
		damage = 2.9,
		cooldown = 12,
		element = "ice",
		damageKind = "magic",
	},
	emberNova = {
		id = "emberNova",
		shape = "circle",
		origin = "self",
		radius = 12,
		windup = 1.4,
		damage = 2.8,
		cooldown = 13,
		element = "fire",
	},
}

return table.freeze({
	byId = ABILITIES,
	get = function(id: string): Ability?
		return ABILITIES[id]
	end,
})
