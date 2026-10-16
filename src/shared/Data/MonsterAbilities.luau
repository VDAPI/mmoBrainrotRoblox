--!strict
-- Special abilities of Elite II monsters (DESIGN §15.1): telegraphed area attacks. Data only.
--
-- shape:  "circle" (radius) | "cone" (radius + angle in degrees) | "line" (length x width)
-- origin: "self" (around the monster) | "target" (centred on the current target's position) | "random" (S134c: under
--         a random fighter the spawning service lists, Monster.SetExtraAbilities)
-- windup: seconds the red telegraph fills before the hit lands
-- damage: multiplier of the monster's attack; element optional
-- S134c (world event commander, Data/WorldEvents.kinds.invasion.commanderAbilities): the bosses 2.0 fields of
-- Data/Bosses read by Logic/BossMechanics: `avoid` (a big blow to dodge, windup >= 1.8 s), `mechanic = "split"` with
-- `split.missAll` (stand together in the golden circle, windup >= 3 s), plus `fromHp` (used only at or below this
-- share of the max HP) and `leap` (the monster lands in the area). Ordinary Elite II abilities have none of them.

export type SplitSpec = { missAll: number }

export type Ability = {
	id: string,
	shape: "circle" | "cone" | "line" | "ring",
	origin: "self" | "target" | "random",
	radius: number?,
	inner: number?, -- ring: radius of the safe centre
	angle: number?,
	length: number?,
	width: number?,
	windup: number,
	damage: number,
	cooldown: number,
	element: ("fire" | "ice" | "lightning" | "poison")?,
	damageKind: ("phys" | "magic")?,
	-- S64 (STATY 6): nil = neither (telegraphed areas); melee / ranged protection only when set
	delivery: ("melee" | "ranged")?,
	-- S134c: the bosses 2.0 fields (Logic/BossMechanics; only the split mechanic for monsters)
	avoid: boolean?,
	mechanic: ("split" | "mark" | "channel")?,
	split: SplitSpec?,
	fromHp: number?,
	leap: boolean?,
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
	-- S134c: the Invasion commander's blows (Data/WorldEvents.kinds.invasion.commanderAbilities), on top of its own
	-- Elite II ability: two big blows to dodge and a shared blow (bosses 2.0, S134). Damage = x the commander's attack.
	warlordCleave = {
		id = "warlordCleave",
		shape = "cone",
		origin = "self", -- a cone from the commander towards its target
		radius = 16,
		angle = 100,
		windup = 1.8,
		damage = 7.5,
		cooldown = 12,
		avoid = true,
	},
	warlordLeap = {
		id = "warlordLeap",
		shape = "circle",
		origin = "random",
		radius = 8,
		windup = 2.0,
		damage = 8.7,
		cooldown = 16,
		avoid = true,
		leap = true,
	},
	warlordRally = {
		id = "warlordRally",
		shape = "circle",
		origin = "random",
		radius = 6,
		windup = 3.0,
		damage = 17.5,
		cooldown = 24,
		mechanic = "split",
		split = { missAll = 0.33 },
		fromHp = 0.6,
	},
}

return table.freeze({
	byId = ABILITIES,
	get = function(id: string): Ability?
		return ABILITIES[id]
	end,
})
