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
	HOTBAR_SLOTS = 10,
	-- S55 (ROZWOJ 2.5): ranks grow with the character level. Rank r of a skill unlocked at U comes at
	-- U + round((r - 1) * span / (maxLevel - 1)), span = min(9 * step, capLevel - U): every skill is maxed by capLevel.
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
		burnPct = 30,
		burnDuration = 4,
		slowPct = 25,
		slowDuration = 2,
		arcPct = 40,
		arcRadius = 10,
		-- S79: skill burns pay the full burnPct over the real ticks (Traits.dotTick), like the Mage model
		exactTicks = true,
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
