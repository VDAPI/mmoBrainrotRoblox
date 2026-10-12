--!strict
-- Skill definition shape (DESIGN §14). Values that grow with the rank are { rank 1, max rank } pairs,
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
	-- S53: Data/BuffCategories id (Logic/EffectStack: strongest per category, own entries add up); "own" for every
	-- effect on the caster. No category: crowd control, taunt, invulnerability, shields, heal and damage over time.
	category: string?,
}

-- Breakpoint (S28, ROZWOJ 2.7): what changes when the skill reaches rank 5 / 10 — numbers (`add` to radius, angle,
-- range, length, width, hits, jumps, duration, effectDuration; `mul` cooldown, cost, delay; `values` added to the
-- skill's values) and behaviours the server applies (Skills/Context, Types/*):
--   pull = radius            enemies within the radius are pulled to the caster at the start
--   knockback = studs        hit enemies are pushed away (bosses immune, players half)
--   castMove = %             the caster may move at this % speed while the motion plays (client)
--   stunNear = { radius, duration }  enemies near the target are stunned too
--   bleedStacks = n          the skill's bleed stacks up to n times
--   lingering = { pct, duration, radius?, kind, slow? }  the area keeps hurting (pct of the hit per second)
--   echo = { delay, pct }    the area hits again after `delay` seconds for pct
--   pierce = pct             a projectile also hits the next enemy behind the target
--   execute = hp%            guaranteed crit on a target below hp%
--   trap = { radius, duration, slow }  leaves a slowing trap where the caster stood
--   split = { count, pct, radius }     the impact splits into small blasts around
--   stunLast = seconds       the last wave / jump stuns
--   splash = { radius, pct } a single-target hit also hurts enemies around the target
--   secondTarget = pct       heal / shield / heal-over-time also on the second most wounded ally
--   overhealShield = true    healing above full HP becomes an absorb shield
--   cleanse = true           also removes harmful effects
--   lifesteal = pct          the caster heals for pct of the damage dealt
--   selfHeal = pct           the caster heals pct of max HP on cast
--   effect / selfEffect / allyEffect = SkillEffect   an extra effect on hit enemies / the caster / allies; these
--                            carry their own category (S53) like the skill's effects. Logic/Skills.effective
--                            collects them from every source into def.effects / def.selfEffects / def.allyEffects
export type Breakpoint = {
	add: { [string]: number }?,
	mul: { [string]: number }?,
	values: { [string]: number }?,
	pull: number?,
	knockback: number?,
	castMove: number?,
	stunNear: { radius: number, duration: number }?,
	bleedStacks: number?,
	lingering: { pct: number, duration: number, radius: number?, kind: string, slow: number? }?,
	echo: { delay: number, pct: number }?,
	pierce: number?,
	execute: number?,
	trap: { radius: number, duration: number, slow: number }?,
	split: { count: number, pct: number, radius: number }?,
	stunLast: number?,
	splash: { radius: number, pct: number }?,
	secondTarget: number?,
	overhealShield: boolean?,
	cleanse: boolean?,
	lifesteal: number?,
	selfHeal: number?,
	effect: SkillEffect?,
	selfEffect: SkillEffect?,
	allyEffect: SkillEffect?,
}

export type BreakpointOption = "a" | "b"
-- S55 (ROZWOJ 2.7): a breakpoint rank offers option A (today's breakpoint, texts skill.<id>.bp5 / .bp10) and
-- optionally B (class sessions, texts .bp5b / .bp10b). No choice = A.
export type BreakpointPair = { a: Breakpoint, b: Breakpoint? }
export type Breakpoints = { [number]: BreakpointPair } -- ranks 5 and 10

export type SkillDef = {
	id: string,
	class: string,
	order: number, -- position in the class list
	path: string?, -- S57 (ROZWOJ 2.2): the path that gives the skill (a node of kind "skill"); nil = class base
	unlock: number, -- character level for rank 1
	maxLevel: number, -- explicit in the data: 10 active, 5 passive (ROZWOJ 2.5)
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
	-- filled only by Logic/Skills.effective from breakpoints and node mods (ROZWOJ 2.7)
	selfEffects: { SkillEffect }?,
	allyEffects: { SkillEffect }?,
	-- Passive stat modifiers: stat id -> value field; `pct` stats multiply.
	passive: { flat: { [string]: string }?, pct: { [string]: string }?, hooks: { [string]: string }? }?,
	breakpoints: Breakpoints?, -- S55: { [5] = { a, b? }, [10] = { a, b? } }
	glyph: string,
	vfx: string,
	nameKey: string,
	descKey: string,
}

return nil
