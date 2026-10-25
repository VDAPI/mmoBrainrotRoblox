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
-- S134e (KITS): every Elite II of a spawner (and of the last Invasion wave) also has the kit `elite2` (Crushing Blow,
-- Pounce, the throw at a fleeing target), every Elite the kit `elite` (Heavy Blow). The kit's fields, read by
-- Logic/MonsterCast (the server's pick, the lethal multiplier, the landing check):
--   lethal     a killing blow: dodge it or die from a few levels of the monster's advantage (windup >= 2.0 s)
--   canCrit    false = never crits (Damage.Params.canCrit; a lethal blow must be predictable)
--   castRange  the target may stand this far (flat studs) when the blow is announced (default max(reach, size))
--   minRange   ... and at least this far
--   kiteOnly   only at a target that keeps out of reach for the kit's `kiteSeconds` (the fleeing rule)
--   firstAfter seconds after the fight starts it is ready first ({ min, max }; default 3-6 s)
--   gapRamp    lethal only: +perLevel of the damage per level of the monster's advantage from `from`, up to maxSteps
--              levels (Logic/MonsterCast.lethalMul; a player above the monster gets nothing)
-- S162m (owner 2026-10-25, docs/ANIM-WZORCE §9 Q6): `dash` = the monster really travels at the end of the windup
-- (Logic/MonsterMove, Entities/Monster). Without `leap` it runs there (the wolf's leap, the boar's charge): it starts
-- `seconds` before the blow lands and stops in front of where its target stood when the blow was announced (the
-- melee approach distance, Data/Combat.meleeApproach; a line no farther than its length). With `leap` it is still
-- moved at the blow (Pounce, the commander's leap); `seconds` is then the visual flight before it. `arc` = studs of
-- the jump's height per stud of travel, held within `arcMin`..`arcMax` studs x the monster's look scale (0 = a run on
-- the ground). The clients read the flight from the model's Dash* attributes (docs/ANIM-WZORCE "Server data").

export type SplitSpec = { missAll: number }
export type GapRamp = { from: number, perLevel: number, maxSteps: number }
-- S134e: the regular ranged attack of a kit at a fleeing target (x the monster's attack, every interval x intervalMul;
-- gapRamp as a lethal blow's: the farther below the monster the fleeing player is, the harder it hits)
export type ThrowSpec = { range: number, intervalMul: number, damage: number, gapRamp: GapRamp? }
export type DashSpec = { seconds: number, arc: number, arcMin: number?, arcMax: number? }
export type Kit = {
	abilities: { string }, -- priority order; the monster's own ability comes after them
	globalGap: number, -- seconds after every blow before the next ability (the throw is a regular attack)
	kiteSeconds: number?, -- a target out of reach this long is fleeing (kiteOnly abilities, the throw)
	throw: ThrowSpec?,
}

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
	-- S134e: the kit fields (see the header)
	lethal: boolean?,
	canCrit: boolean?,
	castRange: number?,
	minRange: number?,
	kiteOnly: boolean?,
	firstAfter: { number }?,
	gapRamp: GapRamp?,
	dash: DashSpec?, -- S162m (see the header)
}

local ABILITIES: { [string]: Ability } = {
	-- S162m: the wolf really leaps the last 0.35 s onto its circle, the boar runs its line the last 0.4 s
	leap = {
		id = "leap",
		shape = "circle",
		origin = "target",
		radius = 7,
		windup = 1.2,
		damage = 2.6,
		cooldown = 11,
		dash = { seconds = 0.35, arc = 0.35, arcMin = 1.2, arcMax = 4 },
	},
	charge = {
		id = "charge",
		shape = "line",
		origin = "self",
		length = 20,
		width = 6,
		windup = 1.0,
		damage = 2.8,
		cooldown = 12,
		dash = { seconds = 0.4, arc = 0 },
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
		dash = { seconds = 0.5, arc = 0.25, arcMin = 3, arcMax = 8 }, -- S162m: the flight the clients draw
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
	-- S134e: the Elite II kit (owner 2026-10-15: a blow that nearly one-shots at the monster's level advantage, and no
	-- free kiting). Crushing Blow: a circle frozen under the target when announced, up to 45 studs away (past the
	-- Mage's 35), never a crit; x10.8 = 0.61-0.79 of a Mage's HP at the Elite II's level, kills from 10 levels below.
	crush = {
		id = "crush",
		shape = "circle",
		origin = "target",
		radius = 9,
		windup = 2.2,
		damage = 10.8,
		cooldown = 16,
		avoid = true,
		lethal = true,
		canCrit = false,
		castRange = 45,
		firstAfter = { 6, 9 },
		gapRamp = { from = 1, perLevel = 0.02, maxSteps = 5 },
	},
	-- Pounce: at a fleeing target 12-45 studs away, a circle under it; the Elite II lands there (not in a safe zone,
	-- not past its hard leash).
	pounce = {
		id = "pounce",
		shape = "circle",
		origin = "target",
		radius = 6,
		windup = 1.4,
		damage = 3.2,
		cooldown = 10,
		castRange = 45,
		minRange = 12,
		kiteOnly = true,
		leap = true,
		dash = { seconds = 0.4, arc = 0.25, arcMin = 2, arcMax = 6 }, -- S162m: the flight the clients draw
	},
	-- The Elite kit: Heavy Blow, a cone in front of it to dodge (no leap, no throw: an Elite is solo content).
	heavyBlow = {
		id = "heavyBlow",
		shape = "cone",
		origin = "self",
		radius = 10,
		angle = 90,
		windup = 1.8,
		damage = 7,
		cooldown = 14,
		avoid = true,
		canCrit = false,
	},
}

-- S134e: the kits by variant (Entities/Monster; the world event commander and champion spawn without one).
local KITS: { [string]: Kit } = {
	elite2 = {
		abilities = { "crush", "pounce" },
		globalGap = 2.5,
		kiteSeconds = 2.5,
		throw = {
			range = 42,
			intervalMul = 1.3,
			damage = 1.25,
			gapRamp = { from = 1, perLevel = 0.3, maxSteps = 15 },
		},
	},
	elite = { abilities = { "heavyBlow" }, globalGap = 2.5 },
}

return table.freeze({
	byId = ABILITIES,
	KITS = KITS,
	kit = function(variant: string): Kit?
		return KITS[variant]
	end,
	get = function(id: string): Ability?
		return ABILITIES[id]
	end,
})
