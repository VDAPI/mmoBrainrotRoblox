--!strict
-- Skill rules (DESIGN §14.1). Pure.
-- S56 (ROZWOJ 2.5): ranks come from the character level (rankAt / rankFor); no skill points, no learning.
-- S57: which skills a character has, the hotbar and the passive totals live in Logic/Paths (base + paths).
-- S54 (ROZWOJ 8): the one cost (Skills.cost), heal curve (Skills.healMul) and weapon speed normalisation
-- (Skills.speedFactor) used by the server, the skill bar, the descriptions and the wiki.

local BuffCategories = require("../Data/BuffCategories")
local Combat = require("../Data/Combat")
local Config = require("../Config")
local LevelCurves = require("./LevelCurves")
local Locale = require("../Util/Locale")
local PathsData = require("../Data/Paths")
local SkillData = require("../Data/Skills")
local Stats = require("../Data/Stats")

type SkillDef = SkillData.SkillDef

local Skills = {}

-- Linear interpolation of a { rank 1, max rank } pair; constants pass through.
function Skills.scaled(skill: SkillDef, value: SkillData.Scaled?, level: number): number
	if value == nil then
		return 0
	end
	if type(value) == "number" then
		return value
	end
	local first, last = value[1], value[2] or value[1]
	if skill.maxLevel <= 1 then
		return first
	end
	local t = math.clamp((level - 1) / (skill.maxLevel - 1), 0, 1)
	return first + (last - first) * t
end

function Skills.valueAt(skill: SkillDef, field: string, level: number): number
	return Skills.scaled(skill, skill.values[field], level)
end

-- A ValueRef at a rank: numbers pass, strings read def.values (0 when missing), nil is 0 (S73).
function Skills.resolve(def: SkillDef, ref: SkillData.ValueRef?, rank: number): number
	if ref == nil then
		return 0
	elseif type(ref) == "number" then
		return ref
	end
	return Skills.valueAt(def, ref, rank)
end

-- Reach of a buff's party copies: allyRadius or BuffCategories.rules.allyRadius, never above rules.maxRadius
-- (ROZWOJ 7.3).
function Skills.allyRadius(def: SkillDef): number
	return math.min(def.allyRadius or BuffCategories.rules.allyRadius, BuffCategories.rules.maxRadius)
end

-- Hit multiplier of a skill with furyConsume: +perStack % per consumed stack (Rend: 8 % x 10 stacks = x1.8).
function Skills.furyMultiplier(perStack: number, stacks: number): number
	return 1 + perStack * math.max(0, stacks) / 100
end

-- Breakpoints (S28, S55: ROZWOJ 2.7) -------------------------------------------------------------------------------

Skills.BREAKPOINT_LEVELS = { 5, 10 }

-- S55 (ROZWOJ 2.7, 3.2): breakpoint choices in the shape of the saved path.bp: ["<skillId>:<rank>"] = "a" | "b".
-- A missing entry, or "b" on a rank without option B, means A.
export type Choices = { [string]: SkillData.BreakpointOption }
-- One modify node as a resolved breakpoint table (Paths.skillMods, S57, settles the node rank, the weapon and
-- modify.option). Applied after the breakpoints, in row order.
export type SkillMod = SkillData.Breakpoint

function Skills.choiceKey(skillId: string, at: number): string
	return `{skillId}:{at}`
end

-- The option that works at breakpoint rank `at`.
function Skills.chosen(skill: SkillDef, at: number, choices: Choices?): SkillData.BreakpointOption
	local pair = skill.breakpoints and skill.breakpoints[at]
	if choices and pair and pair.b and choices[Skills.choiceKey(skill.id, at)] == "b" then
		return "b"
	end
	return "a"
end

-- Breakpoints that work at `rank`, rank 5 first, each in the chosen option (none when Config.Skills.breakpoints is
-- off; `enabled` overrides the switch, for tests and measurements).
function Skills.breakpointsAt(
	skill: SkillDef,
	rank: number,
	choices: Choices?,
	enabled: boolean?
): { SkillData.Breakpoint }
	local out = {}
	local list = skill.breakpoints
	local on = if enabled == nil then Config.Skills.breakpoints else enabled
	if not list or not on then
		return out
	end
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = list[at]
		if pair and rank >= at then
			local bp = if Skills.chosen(skill, at, choices) == "b" then pair.b else pair.a
			if bp then
				table.insert(out, bp)
			end
		end
	end
	return out
end

-- Behaviours of every source merged into one table (later sources win on the same key). Extra effects are not here:
-- they are on def.effects / def.selfEffects / def.allyEffects.
export type Behaviour = SkillData.Breakpoint

local NUMERIC_FIELDS = { "range", "radius", "hitRadius", "angle", "length", "width", "hits", "delay" }

-- The skill as it works at `rank` (ROZWOJ 2.7). Sources in order: breakpoint 5, breakpoint 10 (chosen option, A
-- without a choice), then `mods` (modify nodes, row order). Rules: `values` add to the current value (the base scales
-- once), `add` sums, `mul` multiplies, `effect` / `selfEffect` / `allyEffect` go to the effects / selfEffects /
-- allyEffects lists, every other key: the later source wins. `add.effectDuration` lengthens `effects` only.
-- `enabled = false` (or Config.Skills.breakpoints off) drops the breakpoints, not the mods. `rank` comes from the
-- character level (S56); consumers call it through Logic/Paths.effectiveFor (choices = path.bp, mods =
-- Paths.skillMods). Never mutates the data; with no source returns the def itself.
function Skills.effective(
	skill: SkillDef,
	rank: number,
	choices: Choices?,
	mods: { SkillMod }?,
	enabled: boolean?
): (SkillDef, Behaviour)
	local sources = Skills.breakpointsAt(skill, rank, choices, enabled)
	if mods then
		for _, mod in mods do
			table.insert(sources, mod)
		end
	end
	local behaviour: any = {}
	if #sources == 0 then
		return skill, behaviour
	end
	local def: any = table.clone(skill)
	def.values = table.clone(skill.values)
	local effects: { SkillData.SkillEffect } = table.clone(skill.effects or {})
	local selfEffects: { SkillData.SkillEffect } = {}
	local allyEffects: { SkillData.SkillEffect } = {}
	local addDuration = 0
	local jumps = 0
	local none: { [string]: number } = {}
	for _, bp in sources do
		for key, amount in bp.add or none do
			if key == "effectDuration" then
				addDuration += amount
			elseif key == "jumps" then
				jumps += amount
			elseif key == "duration" then
				def.duration = Skills.scaled(skill, def.duration, rank) + amount
			elseif key == "allyRadius" then
				-- S73: from the default reach (30), so a node's +5 gives 35
				def.allyRadius = (def.allyRadius or BuffCategories.rules.allyRadius) + amount
			elseif table.find(NUMERIC_FIELDS, key) then
				def[key] = (def[key] or 0) + amount
			end
		end
		for key, factor in bp.mul or none do
			if key == "cooldown" then
				def.cooldown = Skills.scaled(skill, def.cooldown, rank) * factor
			elseif key == "cost" then
				def.cost = Skills.scaled(skill, def.cost, rank) * factor
			elseif key == "delay" then
				def.delay = (def.delay or 0) * factor
			end
		end
		for field, amount in bp.values or none do
			-- ROZWOJ 2.7: every change adds to the current value (the base scales once)
			def.values[field] = Skills.scaled(skill, def.values[field], rank) + amount
		end
		for key, v in bp :: any do
			if key == "effect" then
				table.insert(effects, v)
			elseif key == "selfEffect" then
				table.insert(selfEffects, v)
			elseif key == "allyEffect" then
				table.insert(allyEffects, v)
			elseif key ~= "add" and key ~= "mul" and key ~= "values" then
				behaviour[key] = v -- later wins: breakpoint 5, breakpoint 10, nodes by row
			end
		end
	end
	if jumps ~= 0 then
		def.values.jumps = Skills.scaled(skill, def.values.jumps, rank) + jumps
	end
	-- add.effectDuration lengthens `effects` only, as before S55 (not selfEffects / allyEffects)
	if addDuration ~= 0 then
		for i, effect in effects do
			local copy = table.clone(effect)
			copy.duration = math.max(0.5, Skills.scaled(skill, effect.duration, rank) + addDuration)
			effects[i] = copy
		end
	end
	def.effects = effects
	def.selfEffects = if #selfEffects > 0 then selfEffects else nil
	def.allyEffects = if #allyEffects > 0 then allyEffects else nil
	if behaviour.steadfast then
		-- S70: channel rules read the definition (Logic/Channel.stops, S76 stores def = ctx.skill)
		def.steadfast = true
	end
	return def :: SkillDef, behaviour
end

-- Who an effect of the skill lands on (S53): its own target, or self for buffs and enemies for the rest.
function Skills.effectSide(skill: SkillDef, effect: SkillData.SkillEffect): "enemy" | "self" | "allies"
	return effect.target or (if skill.type == "buff" or skill.type == "groupBuff" then "self" else "enemy")
end

-- Whether a buff gives anything to allies around (Support.buff, SkillInfo): allyEffects, allyHeal, allyShield or an
-- effect whose side is "allies" (Skills.effectSide, S53). behindEffect is separate (its own geometry). Other types
-- have their own loops (groupBuff, groupHeal, from S74 shout and guard).
function Skills.hasAllyPass(def: SkillDef, behaviour: Behaviour): boolean
	if def.type ~= "buff" then
		return false
	end
	if (def.allyEffects and #def.allyEffects > 0) or behaviour.allyHeal ~= nil or behaviour.allyShield ~= nil then
		return true
	end
	local effects: { SkillData.SkillEffect } = def.effects or {}
	for _, effect in effects do
		if Skills.effectSide(def, effect) == "allies" then
			return true
		end
	end
	return false
end

-- Locale key of a breakpoint option's text: skill.<id>.bp5 / .bp10 (A), .bp5b / .bp10b (B).
function Skills.breakpointKey(skillId: string, at: number, option: SkillData.BreakpointOption): string
	return if option == "b" then `skill.{skillId}.bp{at}b` else `skill.{skillId}.bp{at}`
end

-- Locale keys of a skill's breakpoints, rank by rank, A before B (B only where it exists).
export type BreakpointKey = { rank: number, option: SkillData.BreakpointOption, key: string }

function Skills.breakpointKeys(skill: SkillDef): { BreakpointKey }
	local out: { BreakpointKey } = {}
	for _, at in Skills.BREAKPOINT_LEVELS do
		local pair = skill.breakpoints and skill.breakpoints[at]
		if pair then
			table.insert(out, { rank = at, option = "a", key = Skills.breakpointKey(skill.id, at, "a") })
			if pair.b then
				table.insert(out, { rank = at, option = "b", key = Skills.breakpointKey(skill.id, at, "b") })
			end
		end
	end
	return out
end

-- S55 (ROZWOJ 2.5): character level at which `skill` reaches rank r (actives 1..10, passives 1..5; a passive's last
-- rank comes where an active's rank 10 does). Every skill is maxed by Data/Skills RANKS.capLevel.
function Skills.rankLevel(skill: SkillDef, r: number): number
	if skill.maxLevel <= 1 or r <= 1 then
		return skill.unlock
	end
	local ranks = SkillData.RANKS
	-- nine steps: an active skill's ranks 1..10
	local span = math.max(0, math.min(9 * ranks.step, ranks.capLevel - skill.unlock))
	local n = math.min(r, skill.maxLevel)
	return skill.unlock + math.floor((n - 1) * span / (skill.maxLevel - 1) + 0.5)
end

-- Rank of `skill` at character level `level` (0 before the unlock).
function Skills.rankAt(skill: SkillDef, level: number): number
	for r = skill.maxLevel, 1, -1 do
		if level >= Skills.rankLevel(skill, r) then
			return r
		end
	end
	return 0
end

-- S56 (ROZWOJ 2.5, 2.6): ranks come from the character level; no skill points ------------------------------------

-- Rank of a class base skill for a character of `classId` at `level` (0: other class or not unlocked yet).
-- base only; path skills: Logic/Paths (Paths.skillRank is the rank every consumer asks for)
function Skills.rankFor(classId: string?, level: number, skill: SkillDef): number
	if skill.class ~= classId or skill.path ~= nil then
		return 0
	end
	return Skills.rankAt(skill, level)
end

local function byUnlock(a: SkillDef, b: SkillDef): boolean
	if a.unlock ~= b.unlock then
		return a.unlock < b.unlock
	end
	return a.order < b.order
end

-- Base skills of the class unlocked at `level`, by unlock level (tie: order). A class without paths keeps all its
-- skills here (transitional ladder, ROZWOJ 2.6).
-- base only; path skills: Logic/Paths
function Skills.unlocked(classId: string, level: number): { SkillDef }
	local out: { SkillDef } = {}
	local list: { SkillDef } = SkillData.byClass[classId] or {}
	for _, skill in list do
		if skill.path == nil and skill.unlock <= level then
			table.insert(out, skill)
		end
	end
	table.sort(out, byUnlock)
	return out
end

-- The class's base active skill with the lowest unlock (on slot 1 of a new character).
function Skills.startingSkill(classId: string): string?
	local best: SkillDef? = nil
	local list: { SkillDef } = SkillData.byClass[classId] or {}
	for _, skill in list do
		if skill.path == nil and skill.type ~= "passive" and (best == nil or byUnlock(skill, best)) then
			best = skill
		end
	end
	return if best then best.id else nil
end

-- A hotbar with the base actives unlocked at `level` on "1", "2", ... in unlock order (at most HOTBAR_SLOTS; ROZWOJ 5).
function Skills.startHotbar(classId: string, level: number): { [string]: string }
	local bar: { [string]: string } = {}
	local slot = 0
	for _, skill in Skills.unlocked(classId, level) do
		if skill.type ~= "passive" and slot < SkillData.HOTBAR_SLOTS then
			slot += 1
			bar[tostring(slot)] = skill.id
		end
	end
	return bar
end

-- Base skills of the class with fromLevel < unlock <= toLevel, in unlock order (path skills reach the bar when their
-- node is bought, never on a level-up).
function Skills.newlyUnlocked(classId: string, fromLevel: number, toLevel: number): { SkillDef }
	local out: { SkillDef } = {}
	for _, skill in Skills.unlocked(classId, toLevel) do
		if skill.unlock > fromLevel then
			table.insert(out, skill)
		end
	end
	return out
end

-- The lowest free slot 1..HOTBAR_SLOTS (nil: the bar is full).
function Skills.firstFreeSlot(hotbar: { [string]: string }): number?
	for slot = 1, SkillData.HOTBAR_SLOTS do
		if hotbar[tostring(slot)] == nil then
			return slot
		end
	end
	return nil
end

export type Placement = { slot: number, id: string }

-- Where `ids` would land on `hotbar` (not mutated): ids already on the bar are skipped, the rest go to the next free
-- slots. Returns the placements and the ids that did not fit.
function Skills.placeOnBar(hotbar: { [string]: string }, ids: { string }): ({ Placement }, { string })
	local bar = table.clone(hotbar)
	local onBar: { [string]: boolean } = {}
	for _, id in bar do
		onBar[id] = true
	end
	local placed: { Placement } = {}
	local left: { string } = {}
	for _, id in ids do
		if not onBar[id] then
			local slot = Skills.firstFreeSlot(bar)
			if slot then
				bar[tostring(slot)] = id
				onBar[id] = true
				table.insert(placed, { slot = slot, id = id })
			else
				table.insert(left, id)
			end
		end
	end
	return placed, left
end

-- A hotbar slot number 1..HOTBAR_SLOTS. Which skill may sit there: Logic/Paths.canPutOnBar / validHotbar.
function Skills.validSlot(slot: number): boolean
	return slot == math.floor(slot) and slot >= 1 and slot <= SkillData.HOTBAR_SLOTS
end

export type PassiveTotals = {
	flat: { [string]: number },
	pct: { [string]: number },
	hooks: { [string]: number },
}

-- Adds `skill.passive` at `rank` to `totals` (rank <= 0: nothing). Which skills count: Logic/Paths.passiveTotals.
function Skills.addPassive(totals: PassiveTotals, skill: SkillDef, rank: number)
	local passive = skill.passive
	if not passive or rank <= 0 then
		return
	end
	local flat: { [string]: string } = passive.flat or {}
	local pct: { [string]: string } = passive.pct or {}
	local hooks: { [string]: string } = passive.hooks or {}
	for stat, field in flat do
		totals.flat[stat] = (totals.flat[stat] or 0) + Skills.valueAt(skill, field, rank)
	end
	for stat, field in pct do
		totals.pct[stat] = (totals.pct[stat] or 0) + Skills.valueAt(skill, field, rank)
	end
	for hook, field in hooks do
		totals.hooks[hook] = (totals.hooks[hook] or 0) + Skills.valueAt(skill, field, rank)
	end
end

-- Level formulas (S54, ROZWOJ 8) ---------------------------------------------------------------------------------

-- Changes to a skill's cost: costPct = sum of percentage changes (-20 = 20 % cheaper). Later sessions extend it
-- (S76 / S79-S80 hooks).
export type CostMods = {
	costPct: number?,
	costReduce: number?, -- % item saving (costReduce stat: Tome trait + lines), capped by Data/Stats
}

local COST_REDUCE_CAP = (Stats.get("costReduce") :: any).cap :: number

-- Resource cost of `skill` (the def after Skills.effective, so breakpoint cost changes apply) at rank `rank` for a
-- character of level `level` and class `classId`. Mana skills of a class with a "manaCost.<classId>" level curve cost
-- more with the level (Mage, owner answer 25). Not rounded: the server and the skill bar compare the same number.
-- One function for the server, the skill bar, the description and the wiki; `rank` comes from the character level.
-- (paid, base): Arcanist power reads the base cost (STATY 3), saving does not weaken it (S80/S81). `paid` is the base
-- after the item saving (mods.costReduce); a call that keeps one value gets what the player pays.
function Skills.cost(skill: SkillDef, rank: number, level: number, classId: string, mods: CostMods?): (number, number)
	local base = Skills.scaled(skill, skill.cost, rank)
	if base <= 0 then
		return 0, 0
	end
	local curve = "manaCost." .. classId
	if skill.resource == "mana" and LevelCurves.has(curve) then
		base *= LevelCurves.at(curve, level)
	end
	local pct = if mods and mods.costPct then mods.costPct else 0
	base *= math.max(0, 1 + pct / 100)
	local saving = math.clamp(if mods and mods.costReduce then mods.costReduce else 0, 0, COST_REDUCE_CAP)
	return base * (1 - saving / 100), base
end

-- S64 (STATY 2C, owner answer 26): item cooldown reduction, capped by Combat.cdrCap.
function Skills.cooldownReduction(total: number): number
	return math.clamp(total, 0, Combat.cdrCap)
end

-- `radius` (S73): the effect's own reach (behindEffect: AURA.behindRadius); nil = the skill's reach.
export type PartyEffect = { kind: string, category: string?, duration: number, radius: number? }

-- Party effects of a skill (ROZWOJ 7.3): effects on allies, allyEffects and a shield skill's shield on an ally.
-- `def` is the skill after Skills.effective. The rule tests/PartyBuffRules checks and the cooldown floor use.
-- S73: with `behaviour` also behindEffect (behind the caster) and allyShield (a shield on the allies).
-- S74: a banner refreshes its circle effects while it stands, so they last the banner's duration (not one pulse).
function Skills.partyEffects(def: SkillDef, rank: number, behaviour: Behaviour?): { PartyEffect }
	local out: { PartyEffect } = {}
	local banner = if def.type == "banner" then Skills.scaled(def, def.duration, rank) else nil
	local function add(effect: SkillData.SkillEffect, radius: number?, pulsed: boolean?)
		local entry: PartyEffect = {
			kind = effect.kind :: string,
			category = effect.category,
			duration = if pulsed and banner then banner else Skills.scaled(def, effect.duration or def.duration, rank),
			radius = radius,
		}
		table.insert(out, entry)
	end
	local effects: { SkillData.SkillEffect } = def.effects or {}
	for _, effect in effects do
		if Skills.effectSide(def, effect) == "allies" then
			add(effect, nil, true)
		end
	end
	local allyEffects: { SkillData.SkillEffect } = def.allyEffects or {}
	for _, effect in allyEffects do
		add(effect, nil, true)
	end
	if def.type == "shield" then
		table.insert(out, { kind = "shield", duration = Skills.scaled(def, def.duration, rank) })
	end
	if behaviour and behaviour.behindEffect then
		add(behaviour.behindEffect, PathsData.AURA.behindRadius)
	end
	if behaviour and behaviour.allyShield then
		table.insert(out, { kind = "shield", duration = behaviour.allyShield.duration })
	end
	return out
end

-- Longest party effect of the skill in s, 0 without one.
function Skills.partyDuration(def: SkillDef, rank: number, behaviour: Behaviour?): number
	local longest = 0
	for _, effect in Skills.partyEffects(def, rank, behaviour) do
		longest = math.max(longest, effect.duration)
	end
	return longest
end

-- S64: cooldown of `def` (after Skills.effective) at `rank` with `reduction` % item cooldown reduction. A party buff
-- never comes back sooner than it lasts (ROZWOJ 7.3), and the floor never lifts the cooldown above its base. One
-- function for the server, the skill bar, the description and the wiki. S73: with `behaviour` its party effects
-- (behindEffect, allyShield) count for the floor too.
function Skills.cooldown(def: SkillDef, rank: number, reduction: number?, behaviour: Behaviour?): number
	local base = Skills.scaled(def, def.cooldown, rank)
	local pct = Skills.cooldownReduction(reduction or 0)
	if pct <= 0 then
		return base
	end
	return math.max(base * (1 - pct / 100), math.min(base, Skills.partyDuration(def, rank, behaviour)))
end

-- S70 Guardian Angel (ROZWOJ 7.6, 9.3): a lethal hit from a monster leaves 1 HP. Only "monster" and
-- "intercept" (a monster's blow taken for an ally) are saved; players ("pvp"), damage over time (no attacker,
-- may come from a player), "admin" and "world" never are. Returns the amount to let through and whether the
-- angel was used.
function Skills.angelSave(hp: number, amount: number, source: string, hasAngel: boolean): (number, boolean)
	if not hasAngel or amount < hp or (source ~= "monster" and source ~= "intercept") then
		return amount, false
	end
	return math.max(0, hp - 1), true
end

-- Multiplier of the magic-attack part of heals and shields at character level `level` (ROZWOJ 9.2).
function Skills.healMul(level: number): number
	return LevelCurves.at("heal", level)
end

local HEAL_TYPES: { [string]: boolean } = { heal = true, hot = true, groupHeal = true }

-- Value fields of `skill` computed from magic attack (or, for a damage skill that heals allies, from its own hit)
-- that the heal curve multiplies. S69: with the target-HP pair only the magic part (healMag / shieldMag) is on the
-- curve, never healHp / shieldHp. Percent-of-HP heals (Divine Intervention), heal bonuses (Devotion) and shares of
-- dealt damage from passive hooks (Holy Strike) are not on the curve.
function Skills.healFields(skill: SkillDef): { string }
	if skill.values.healMag ~= nil then
		return { "healMag" }
	elseif skill.values.shieldMag ~= nil then
		return { "shieldMag" }
	elseif HEAL_TYPES[skill.type] then
		return { "heal" }
	elseif skill.type == "shield" then
		return { "shield" }
	elseif skill.type ~= "passive" and skill.values.heal ~= nil and skill.values.dmg ~= nil then
		return { "heal" }
	end
	return {}
end

-- S69 (ROZWOJ 7.5, 9.2): base heal or shield of `def` (already Skills.effective) at `rank` on a target with
-- `targetMaxHp`, before heal bonuses, item power and PvP scaling. prefix "heal" reads values.healHp / healMag,
-- "shield" reads values.shieldHp / shieldMag. Only the magic-attack part follows the heal curve (S54); `level` is
-- the caster's character level. Data without the Hp / Mag pair keeps the formula from before S69: magic attack x
-- curve x values[prefix] %.
function Skills.healAmount(
	def: SkillDef,
	rank: number,
	prefix: "heal" | "shield",
	targetMaxHp: number,
	magAtk: number,
	level: number
): number
	local hpField, magField = def.values[prefix .. "Hp"], def.values[prefix .. "Mag"]
	local curve = Skills.healMul(level)
	if hpField == nil and magField == nil then
		return magAtk * curve * Skills.valueAt(def, prefix, rank) / 100
	end
	return targetMaxHp * Skills.scaled(def, hpField, rank) / 100
		+ magAtk * curve * Skills.scaled(def, magField, rank) / 100
end

-- S71 (ROZWOJ 9.3, 9.4): heal bonus in % of a heal on a target with `fraction` of its health before the heal.
-- healBonus always, allyHealBonus only on another player, lowHpHealBonus below SkillData.LOW_HP_HEAL %; they add up.
export type HealHooks = { healBonus: number, allyHealBonus: number, lowHpHealBonus: number }

function Skills.healBonusPct(hooks: HealHooks, isOther: boolean, fraction: number): number
	local pct = hooks.healBonus
	if isOther then
		pct += hooks.allyHealBonus
	end
	if fraction < SkillData.LOW_HP_HEAL / 100 then
		pct += hooks.lowHpHealBonus
	end
	return pct
end

-- S71 (Lucky Mending): chance in [0, 1] that a heal or shield is critical, from the caster's critChance (points) and
-- the healCrit hook (% of that chance).
function Skills.healCritChance(critChance: number, healCrit: number): number
	return math.clamp(critChance * healCrit / 10000, 0, 1)
end

-- S69 (ROZWOJ 9.2, Heal 10B chainHeal): order of the next chain targets. `fractions[i]` is the HP share of
-- candidate i (already without the targets healed in this cast). Only wounded candidates (< 1), the most
-- wounded first, ties by lower index, at most `jumps`. Returns candidate indices.
function Skills.chainOrder(fractions: { number }, jumps: number): { number }
	local order: { number } = {}
	for i, fraction in fractions do
		if fraction < 1 then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a: number, b: number): boolean
		if fractions[a] ~= fractions[b] then
			return fractions[a] < fractions[b]
		end
		return a < b
	end)
	local limit = math.max(0, math.floor(jumps))
	while #order > limit do
		table.remove(order)
	end
	return order
end

-- Share of the k-th chain jump (k = 1, 2, ...): (pct / 100) ^ k, e.g. 60 -> 0.6, 0.36.
function Skills.chainShare(pct: number, k: number): number
	return (pct / 100) ^ k
end

-- Skill damage multiplier from the base speed of the equipped weapon (nil = unarmed): weapons with the same damage
-- per second give skills the same damage. Combat.skillSpeedRef (two-handed axe) = x1.
function Skills.speedFactor(weaponSpeed: number?): number
	return (weaponSpeed or Stats.Formula.unarmed.speed) / Combat.skillSpeedRef
end

-- A description argument: a whole number stays, anything else gets one decimal (S59: also path node texts).
function Skills.roundArg(value: number): number
	if math.abs(value - math.floor(value + 0.5)) < 1e-6 then
		return math.floor(value + 0.5)
	end
	return math.floor(value * 10 + 0.5) / 10
end
local round = Skills.roundArg

-- Options of a description: `level` = character level (default: the level the rank unlocks at, as on the wiki);
-- `choices` / `mods` as in Skills.effective (S55; nil = option A, no nodes).
-- S64: `cdr` = % item cooldown reduction (Skills.cooldown; nil = none, as on the wiki).
export type DescOpts = { level: number?, choices: Choices?, mods: { SkillMod }?, cdr: number? }

-- Placeholder values for the description of `base` at rank `rank` ({dmg}, {slow}, {duration}, {cost}, ...).
-- S28: the numbers as the skill works at that rank (breakpoints applied). S54: cost and heal values at the
-- character level from `opts` (Skills.cost, Skills.healMul).
function Skills.descriptionArgs(base: SkillDef, rank: number, opts: DescOpts?): { [string]: number }
	local skill, behaviour = Skills.effective(base, rank, opts and opts.choices, opts and opts.mods)
	local L = if opts and opts.level then opts.level else Skills.rankLevel(base, rank)
	local args: { [string]: number } = {}
	for field in skill.values do
		args[field] = round(Skills.valueAt(skill, field, rank))
	end
	local healMul = Skills.healMul(L)
	for _, field in Skills.healFields(base) do
		if skill.values[field] ~= nil then
			args[field] = round(Skills.valueAt(skill, field, rank) * healMul)
		end
	end
	local cost = Skills.cost(skill, rank, L, base.class, nil)
	args.cost = round(cost)
	args.cooldown = round(Skills.cooldown(skill, rank, opts and opts.cdr, behaviour))
	if skill.duration then
		args.duration = round(Skills.scaled(skill, skill.duration, rank))
	end
	local effects: { SkillData.SkillEffect } = skill.effects or {}
	for _, effect in effects do
		args[`{effect.kind}Duration`] = round(Skills.scaled(skill, effect.duration, rank))
	end
	args.radius = skill.radius or 0
	args.range = skill.range or 0
	args.length = skill.length or 0
	args.hits = skill.hits or 1
	-- S73: only for skills that have them (today's descriptions and the wiki keep their arguments)
	if skill.hitRadius then
		args.hitRadius = skill.hitRadius
	end
	if skill.allyRadius then
		args.allyRadius = Skills.allyRadius(skill)
	end
	return args
end

function Skills.formatDescription(skill: SkillDef, rank: number, lang: string?, opts: DescOpts?): string
	return Locale.T(skill.descKey, Skills.descriptionArgs(skill, math.max(1, rank), opts), lang)
end

-- Weapon element a skill needs (DESIGN §5.8, S18): Mage element skills need a weapon of their element;
-- adaptive skills and everything else work with any weapon.
-- Shape of a skill's area for the tooltip icon (S28): "circle" | "self" | "cone" | "line" | "target" | "none".
function Skills.shape(skill: SkillDef): string
	local kind: string = skill.type
	if kind == "cone" then
		return "cone"
	elseif kind == "line" then
		return "line"
	elseif kind == "circleSelf" or kind == "groupHeal" or kind == "groupBuff" then
		return "self"
	elseif kind == "circleTarget" or kind == "trap" or kind == "healZone" or kind == "banner" then
		return "circle"
	elseif kind == "shout" then
		return "self" -- S74
	elseif kind == "guard" then
		return "target" -- S74: an ally, or the guard itself (ROZWOJ 14.2)
	elseif skill.target == "enemy" or skill.target == "ally" or skill.target == "deadAlly" then
		return "target"
	end
	return "none"
end

-- Types that attack whatever their target mode (SkillService before S74).
local OFFENSIVE_TYPES: { [string]: boolean } = { cone = true, circleSelf = true, circleTarget = true, line = true }

-- Skills that attack (ROZWOJ 14.2): refused in green zones, and casting one ends the respawn protection.
-- A shout attacks only with damage (Order to Advance); Shield Wall, guard and banner never do.
function Skills.offensive(def: SkillDef): boolean
	if def.target == "enemy" or OFFENSIVE_TYPES[def.type] then
		return true
	end
	return def.type == "shout" and def.values.dmg ~= nil
end

function Skills.requiredElement(skill: SkillDef): string?
	if skill.class ~= "Mage" or skill.adaptive or not skill.element then
		return nil
	end
	return skill.element
end

function Skills.elementAllowed(skill: SkillDef, weaponElement: string?): boolean
	local required = Skills.requiredElement(skill)
	return required == nil or required == weaponElement
end

return Skills
