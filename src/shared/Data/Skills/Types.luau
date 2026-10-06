--!strict
-- Skill definition shape (DESIGN §14). Values that grow with the skill level are { level 1, max level } pairs,
-- interpolated linearly by Logic/Skills.valueAt (DESIGN: "mnożnik = baza + przyrost·(poziom−1)").

-- { valueAtLevel1, valueAtMaxLevel } or a constant.
export type Scaled = { number } | number

export type SkillType =
	"target" -- single enemy hit
	| "projectile" -- single enemy hit after travel time
	| "cone" -- enemies in a cone in front
	| "circleSelf" -- enemies around the caster
	| "circleTarget" -- enemies around a point / the target
	| "line" -- enemies in a line in front
	| "chain" -- jumps between enemies
	| "charge" -- dash to the target, then hit
	| "blink" -- teleport
	| "buff" -- effect on the caster
	| "debuff" -- effect on an enemy
	| "heal" -- heal an ally / self
	| "hot" -- heal over time
	| "shield" -- absorb shield on an ally / self
	| "channel" -- stand still for a while, then restore
	| "trap" -- object on the ground that triggers
	| "resurrect" -- revive a dead ally
	| "groupBuff" -- effect on allies around
	| "groupHeal" -- heal allies around
	| "passive" -- permanent stat bonus / proc

export type TargetMode = "enemy" | "ally" | "self" | "point" | "deadAlly" | "none"

export type EffectKind =
	"stun"
	| "root"
	| "slow"
	| "freeze"
	| "bleed"
	| "poison"
	| "armorBreak"
	| "taunt"
	| "invuln"
	| "damageReduction"
	| "shield"
	| "statBuff"
	| "vulnerability"
	| "hot"
	| "camouflage"
	| "nextShot"
	| "guaranteedCrit"
	| "manaShield"
	| "respawnShield" -- S22: after a respawn; no damage, ignored by monsters, no PvP; ends on any attack
	| "burn"

export type SkillEffect = {
	kind: EffectKind,
	duration: Scaled,
	-- Value field name in `values` (or a constant): slow %, DoT % of attack, armor break %, ...
	value: (string | number)?,
	-- Stat modifiers for "statBuff": stat id -> value field name; `pct` = % multiplier instead of flat.
	stats: { [string]: string }?,
	pct: boolean?,
	target: ("enemy" | "self" | "allies")?, -- default: enemy for damage skills, self for buffs
}

export type SkillDef = {
	id: string,
	class: string,
	order: number, -- 1..14 in the class tree (DESIGN table row)
	unlock: number, -- character level for skill level 1
	maxLevel: number, -- 10 active, 5 passive
	type: SkillType,
	target: TargetMode,
	resource: ("mana" | "energy")?,
	cost: Scaled,
	cooldown: Scaled,
	range: number?,
	radius: number?,
	angle: number?,
	length: number?,
	width: number?,
	delay: number?, -- seconds before the hit lands (meteor)
	hits: number?, -- waves / strikes / projectiles
	interval: number?, -- seconds between hits
	duration: Scaled?, -- buff / channel / area length
	element: ("fire" | "ice" | "lightning" | "poison")?,
	-- Takes the element of the caster's weapon (Mage, S18): fire burns, ice slows, lightning arcs.
	adaptive: boolean?,
	-- Each wave strikes one random enemy in the area instead of all of them (Thunderstorm, S18).
	randomTarget: boolean?,
	damageKind: ("phys" | "magic")?,
	holy: boolean?, -- light damage (Cleric, Divine Wrath)
	values: { [string]: Scaled },
	effects: { SkillEffect }?,
	-- Passive stat modifiers: stat id -> value field; `pct` stats multiply.
	passive: { flat: { [string]: string }?, pct: { [string]: string }?, hooks: { [string]: string }? }?,
	requires: { { skill: string, level: number } }?,
	col: number,
	row: number,
	glyph: string,
	vfx: string,
	nameKey: string,
	descKey: string,
}

return nil
