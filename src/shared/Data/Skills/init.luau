--!strict
-- Every skill (Data/Skills/<Class>), by id and by class.

local Cleric = require("@self/Cleric")
local Hunter = require("@self/Hunter")
local Mage = require("@self/Mage")
local Types = require("@self/Types")
local Warrior = require("@self/Warrior")

export type SkillDef = Types.SkillDef
export type Scaled = Types.Scaled
export type ValueRef = Types.ValueRef
export type SkillEffect = Types.SkillEffect
export type Breakpoint = Types.Breakpoint
export type Breakpoints = Types.Breakpoints
export type BreakpointPair = Types.BreakpointPair
export type BreakpointOption = Types.BreakpointOption

local byClass: { [string]: { SkillDef } } = {
	Warrior = Warrior,
	Hunter = Hunter,
	Mage = Mage,
	Cleric = Cleric,
}

local byId: { [string]: SkillDef } = {}
for _, list in byClass do
	for _, def in list do
		assert(byId[def.id] == nil, `Skills: duplicate id {def.id}`)
		byId[def.id] = def
	end
end

return table.freeze({
	byId = byId,
	byClass = byClass,
	get = function(id: string): SkillDef?
		return byId[id]
	end,
	HOTBAR_SLOTS = 10, -- S137: 8 slots per weapon pool (was 10); S156 (owner 2026-10-20): 10 again, keys 1-9 and 0
	-- S156: the balance model (tests/SkillModel) still casts the first 8 actives of a build's bar priority, as tuned in
	-- S146-S147; the two extra slots are room for situational skills, not a longer rotation
	MODEL_BAR = 8,
	-- S55 (ROZWOJ 2.5): the rank curve. S137 (DESIGN-18 §3.1): it is the LIMIT of a bought rank, no longer the rank:
	-- rank r of a skill unlocked at U may be bought from U + round((r - 1) * span / (maxLevel - 1)),
	-- span = min(9 * step, capLevel - U): every skill may be maxed by capLevel.
	RANKS = table.freeze({ step = 4, capLevel = 95 }),
	GCD = 0.5, -- global cooldown (DESIGN §14.1)
	-- S80 (ROZWOJ 12.5): Arcane Charges. Every damaging spell but the consumer adds one (up to `max`, for `duration`
	-- seconds, lost out of combat and on death); each charge gives +`damage` % to spells other than the consumer and
	-- +`cost` % to the cost of every damaging spell. Charges exist only for a caster who may use `consumer`
	-- (Logic/Paths.skillUsable: the node bought and the arcanist's weapon). Not exported to the wiki.
	ARCANE_CHARGES = table.freeze({ max = 4, duration = 15, damage = 1, cost = 4.3, consumer = "arcaneDischarge" }), -- S90: damage 2 -> 1, cost 15 -> 4.3
	-- S80: Empowering Invocation lasts this long; its value and uses come from the channel's `empower`.
	EMPOWERED = table.freeze({ duration = 15 }),
	AREA_MIN_HITS = 2, -- S79 (ROZWOJ 12.3): area bonuses need this many enemies hit; secondary hits always count
	AREA_LINGER_SECONDS = 3, -- S79: the areaLingering zone (Elemental Trail) lasts this long
	RESONANCE_MANA = 75, -- S79: resonance works while mana before the cast is at least this % of the pool
	VORTEX_SKILL = "elementalVortex", -- S79: casts of this skill apply vortexGuard (the skill comes in S80)
	WOUNDED_RADIUS = 30, -- S69: healWounded looks for the most wounded ally within this radius of the caster
	GUARD_SECOND_RADIUS = 15, -- S74 (ROZWOJ 10.3): guard 10A covers the second most wounded ally this near the landing
	-- S71 (ROZWOJ 9.3, 9.4): lowHpHealBonus works on a target below LOW_HP_HEAL % health; a critical heal or shield
	-- (healCrit) is x HEAL_CRIT_MUL.
	LOW_HP_HEAL = 35,
	HEAL_CRIT_MUL = 1.5,
	-- S65 (DESIGN §14.4): weapon-element effect of adaptive skills (server/Skills/Elements): fire burns burnPct % of
	-- the hit over burnDuration s, ice slows slowPct % for slowDuration s, lightning arcs within arcRadius for arcPct %.
	ADAPTIVE = table.freeze({
		burnPct = 15,
		burnDuration = 4,
		slowPct = 25,
		slowDuration = 2,
		arcPct = 40,
		arcRadius = 10,
		-- S79: skill burns pay the full burnPct over the real ticks (Traits.dotTick), like the Mage model
		exactTicks = true,
	}),
	-- S140 (DESIGN-18 §6.1): the fire school's burn (Logic/Burn). Every fire burn of a player on a target is ONE entry
	-- (StatusEffectService key skillId KEY): a fire skill's hit adds `burnStacks` stacks worth pct % of the hit over
	-- duration s each (Traits.dotTick, accumulate: every hit is paid in full), the adaptive weapon burn adds one with
	-- ADAPTIVE's numbers; at most maxStacks stacks (+ the burnStacks hook of Kindling). Stacks feed Kindling's
	-- burnBonus, Combustion (detonate) and Immolate (vsBurning); stunAt stacks make Combustion stun (no bosses).
	BURN = table.freeze({ key = "burn", pct = 30, duration = 4, maxStacks = 1, stunAt = 3 }),
	-- S140: Ember Shield's retaliation: a melee blow on the bearer burns the attacker at most once per `gap` s.
	EMBER = table.freeze({ gap = 1 }),
	-- S140: Phoenix Heart's fire blast reaches this far (its rest, invulnerability and blast are the passive's values).
	PHOENIX = table.freeze({ radius = 8 }),
	-- S141 (DESIGN-18 §6.1): the ice school's chill (Logic/Chill). With Winter's Grip (hook chillFreeze = the freeze's
	-- seconds) every main ice hit of the player on a slowed, not frozen enemy adds a stack to the player's chill counter
	-- on it (one entry per target, StatusEffectService skillId `key`, refreshed for `counter` s); at `threshold` stacks
	-- the counter is spent on a freeze. Bosses and Elite II (StatusEffectService.IsBossLike) never freeze: every freeze
	-- of a player's ice gives them Deep Chill instead (skillId `deepKey`): +deepPct % damage from that player (the
	-- deepChill hook of Winter's Grip when higher) for deepDuration s. Ice Barrier: a melee blow of a monster on the
	-- bearer slows it by the effect's value % for barrierSlow s, at most once per barrierGap s per attacker.
	CHILL = table.freeze({
		key = "chill",
		deepKey = "deepChill",
		threshold = 4,
		counter = 5,
		deepPct = 10,
		deepDuration = 4,
		barrierSlow = 2,
		barrierGap = 1,
	}),
	-- S142 (DESIGN-18 §6.1): the lightning school (Logic/Shock). Conductor's jump looks for the nearest other enemy within
	-- conductRadius studs of the struck target; Storm Armor strikes a melee attacker back at most once per armorGap s.
	SHOCK = table.freeze({ conductRadius = 10, armorGap = 1 }),
	-- S143 (DESIGN-18 §6.2): the shield school (Logic/Block). Vindicate counts the Warrior's blocks of the last `window`
	-- seconds, at most `max` of them (values.perBlock % each).
	BLOCK = table.freeze({ window = 6, max = 3 }),
	-- S144 (DESIGN-18 §6.3): the crossbow school (Logic/Crossbow). With Toxic Tips every main hit of a skill of the
	-- `pool` pool adds one stack of the caster's tip poison (one entry per target, skillId tipKey) worth the toxicTips
	-- hook % of the attack over tipDuration s, at most tipStacks stacks, at most once per tipGap s per target.
	CROSSBOW = table.freeze({ pool = "crossbow", tipKey = "toxicTips", tipGap = 1, tipDuration = 6, tipStacks = 5 }),
	-- S145 (DESIGN-18 §6.4): the Cleric's schools (Logic/Faith). Zeal (hook `zeal`, s) shortens the running cooldowns of
	-- the `hammer` pool's skills after an offensive cast of one of them; Guiding Light (hook `guidingLight`, %) leaves a
	-- ward (shield, skillId wardKey) of that share of the HP a heal skill restored, for wardDuration s, at most wardCap
	-- % of the target's max HP; the Inquisitor's wandering brand (hook `brandJump`, %) lands that share of a brand
	-- skill's burn on the nearest other enemy within brandRadius studs.
	FAITH = table.freeze({
		hammer = "hammer",
		light = "light",
		wardKey = "guidingLight",
		wardDuration = 6,
		wardCap = 20,
		brandRadius = 8,
		brandSkills = table.freeze({ brandOfLight = true } :: { [string]: boolean }),
	}),
	-- S65 (STATY 3): Frostbite, +% damage from you on targets your ice slowed or froze, with any ice weapon;
	-- the fixed hook "frostbite" of a wand (6) or staff (10) replaces it when higher.
	FROSTBITE = 6,
	-- S76 (ROZWOJ 11.4, Trapper): a second trap without ringRadius stands TRAP_SIDE_OFFSET studs to the side (Frost
	-- Trap 10B), trapEnergy pays for at most TRAP_ENERGY_MAX enemies per trap, poisonSpread (Contagion) reaches the
	-- nearest within POISON_SPREAD_RADIUS studs.
	TRAP_SIDE_OFFSET = 4,
	TRAP_ENERGY_MAX = 3,
	POISON_SPREAD_RADIUS = 8,
})
