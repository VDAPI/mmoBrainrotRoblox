--!strict
-- Skill definition shape (DESIGN §14). Values that grow with the rank are { rank 1, max rank } pairs,
-- interpolated linearly by Logic/Skills.valueAt (DESIGN: "mnożnik = baza + przyrost·(poziom−1)").

-- { valueAtLevel1, valueAtMaxLevel } or a constant.
export type Scaled = { number } | number

-- A number, or the name of a `values` field read at the skill's rank (like SkillEffect.value). Path nodes reach a
-- behaviour's number through it: the node adds to `values.<field>` and the behaviour names the field (S71, S73).
export type ValueRef = number | string

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
	| "healZone" -- S70 (ROZWOJ 9.3): a healing field at a point (Sanctuary), on the S69 ctx.healZone loop
	| "guard" -- leap to an ally and intercept the monster blows aimed at them; no ally: a self variant (ROZWOJ 10.3)
	| "shout" -- around the caster: effects on allies within `radius`, on enemies within `hitRadius`, optional damage
	| "banner" -- an object planted on the ground; every second its circle gives the skill's effects (ROZWOJ 10.5)
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
	| "intercept" -- S61: value = share % of monster blows the source (guard) takes; no category
	| "misfortune" -- S61: value = % the bearer misses regular attacks; category enemyMiss
	| "attackSlow" -- S63: value = % slower attacks (slow stays movement); category enemyAttackSlow
	| "weaken" -- S63: value = % less damage the bearer deals; category enemyDamageDown
	| "guardianAngel" -- S70: a lethal hit from a monster leaves 1 HP and heals value % max HP, once
	-- S72 (ROZWOJ 10.4): own; Fury does not decay and grows by HOOK_RULES.carnage.furyGain, killing blows reset
	-- HOOK_RULES.carnage.resets (Data/Paths)
	| "carnage"

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
	-- S70: a die face of a roll skill ("blade" | "wind" | "spring"); applied only by the roll (ctx.rollDice)
	face: string?,
	-- S70: bosses and Elite II ignore it (StatusEffectService ApplyOptions.notBoss, S63)
	notBoss: boolean?,
	-- "hot": heals hpPct % of the target's max HP per second (ROZWOJ 7.5, 14.2)
	hpPct: ValueRef?,
}

-- Breakpoint (S28, ROZWOJ 2.7): what changes when the skill reaches rank 5 / 10 — numbers (`add` to radius, angle,
-- range, length, width, hits, jumps, duration, effectDuration (every effect list), <kind>Duration (only `effects` of
-- that kind, S75); `mul` cooldown, cost, delay; `values` added to the
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
--   cleanse = true           also removes harmful effects (heal, hot, groupHeal, shield, groupBuff (S69))
--   lifesteal = pct          the caster heals for pct of the damage dealt
--   selfHeal = pct           the caster heals pct of max HP on cast
--   healWounded = pct        S69: the most wounded ally within SkillData.WOUNDED_RADIUS heals pct of the main hit
--   chainHeal = { jumps, pct }  S69: the heal jumps to `jumps` more wounded allies in range, (pct/100)^k of their heal
--   healZone = { duration, pct }  S69: a field at the cast point heals allies inside pct of their heal every second
--   roll = { half = true }       S70: at the end of the channel the caster rolls Roll of the Dice for the party
--                                (one face, half its duration)
--   rollDouble = pct              S70: pct % chance that a die roll gives two different faces
--   steadfast = true              S70: damage does not interrupt the channel
--   burst = { radius, pct }       S70: enemies within radius of the healed target take pct % magic attack as light
--   stunSplash = { radius }       S71: a hit on a stunned target (also by the same cast) bursts: enemies within radius
--                                take values.stunSplash % of the skill's damage (Final Verdict)
--   shieldBurst = { radius }      S71: when the shield breaks or expires, allies within radius of its bearer heal
--                                values.shieldBurst % of its starting value, once per shield (Shattering Shield)
--   tauntNear = { radius, duration }       guard (S74): enemies near the protected ally are taunted onto the caster
--   shieldPerHit = { hpPct, max, duration } circleSelf: an absorb shield on the caster, hpPct % of its max HP per taunted
--                                           monster (at most `max` monsters), through ctx.shield
--   extendOnKill = { seconds, max }        buff: every kill while it lasts lengthens the skill's effects by `seconds`,
--                                           at most `max` seconds in total (SkillService, StatusEffectService.Extend)
--   behindEffect = SkillEffect             buff: the effect on allies behind the caster at the cast (Paths.inAura "behind")
--   allyHeal = { hpPct }                   buff: allies within allyRadius (caster included) heal hpPct % of their max HP
--   allyShield = { hpPct, duration }       buff: the same allies get a shield of hpPct % of their max HP (guard, S74: the
--                                           protected ally)
-- Skill fields: furyConsume (target, buff), hitRadius (shout, S74), allyRadius (buff); `add.hitRadius` works like
-- `add.radius`, `add.allyRadius` adds to the default reach (30). Numbers typed ValueRef may name a `values` field.
-- S74 types: guard reads stunNear and tauntNear (around the protected ally), secondTarget (a second wounded ally within
-- 15 studs of the landing point), allyShield and allyEffect (on the protected allies); shout reads cleanse (allies),
-- pull (enemies, before the strike), allyEffect and selfHeal; banner reads allyEffect and effect (enemies in the
-- circle). Effects of a banner's circle last one pulse (Data/Paths AURA.duration) whatever their data says; the
-- banner refreshes them every AURA.tick while it stands.
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
	healWounded: number?,
	chainHeal: { jumps: number, pct: number }?,
	healZone: { duration: number, pct: number }?,
	roll: { half: boolean? }?,
	rollDouble: number?,
	steadfast: boolean?,
	burst: { radius: number, pct: number }?,
	stunSplash: { radius: number }?,
	shieldBurst: { radius: number }?,
	tauntNear: { radius: number, duration: number }?,
	shieldPerHit: { hpPct: ValueRef, max: number, duration: number }?,
	extendOnKill: { seconds: number, max: ValueRef }?,
	behindEffect: SkillEffect?,
	allyHeal: { hpPct: ValueRef }?,
	allyShield: { hpPct: ValueRef, duration: number }?,
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
	-- S64 (STATY 6): kind of blow for melee / ranged protection; required on every non-passive skill (data.spec)
	delivery: ("melee" | "ranged")?,
	resource: ("mana" | "energy")?,
	cost: Scaled,
	cooldown: Scaled,
	range: number?,
	radius: number?,
	hitRadius: number?, -- enemies' radius of a shout (S74); `radius` is the allies' one (ROZWOJ 14.2)
	-- reach of a buff's party copies (allyEffect, allyHeal, allyShield); default BuffCategories.rules.allyRadius
	allyRadius: number?,
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
	furyConsume: string?, -- values field: bonus % per Fury stack; the cast consumes every stack (ROZWOJ 10.4)
	values: { [string]: Scaled },
	effects: { SkillEffect }?,
	-- S70 (ROZWOJ 9.4): effects with face are dice faces; all = every face with one pointed face stronger, and
	-- enemies within enemyRadius get the enemy effects
	roll: { all: boolean?, enemyRadius: number? }?,
	-- S70: damage does not end this channel (Logic/Channel); set by the steadfast breakpoint
	steadfast: boolean?,
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
