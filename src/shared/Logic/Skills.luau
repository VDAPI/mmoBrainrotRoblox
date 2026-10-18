--!strict
-- Skill rules (DESIGN §14.1). Pure.
-- S56 (ROZWOJ 2.5): ranks came from the character level (rankAt / rankFor). S137 (DESIGN-18): ranks are bought with
-- skill points per weapon pool (Logic/SkillPoints); rankAt is the limit.
-- S57: which skills a character has, the hotbar and the passive totals live in Logic/Paths (base + paths).
-- S54 (ROZWOJ 8): the one cost (Skills.cost), heal curve (Skills.healMul) and weapon speed normalisation
-- (Skills.speedFactor) used by the server, the skill bar, the descriptions and the wiki.
-- S79 (ROZWOJ 12.3, 14.4): spell tags (Skills.tag), area / single target rules, cast zones, Mage hooks and the spell
-- cost hooks (areaCost, spellCost) in Skills.cost.
-- S80 (ROZWOJ 12.5): Arcane Charges (cost, damage, decay), Arcane Torrent's drain and ticks (Skills.drain,
-- beamTicks, beamTickPct); Skills.cost and Skills.drain share one modifier rule (applyCostMods).

local BuffCategories = require("../Data/BuffCategories")
local Chill = require("./Chill")
local Combat = require("../Data/Combat")
local Config = require("../Config")
local Crossbow = require("./Crossbow")
local LevelCurves = require("./LevelCurves")
local Locale = require("../Util/Locale")
local PathsData = require("../Data/Paths")
local SkillCurves = require("../Data/SkillCurves")
local SkillData = require("../Data/Skills")
local Stats = require("../Data/Stats")
local TableUtil = require("../Util/TableUtil")

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

-- Linear interpolation over points { rank, value } sorted by rank; clamped to the end points (S83).
function Skills.interpolate(points: { { number } }, rank: number): number
	local first, last = points[1], points[#points]
	if rank <= first[1] then
		return first[2]
	elseif rank >= last[1] then
		return last[2]
	end
	for i = 2, #points do
		local a, b = points[i - 1], points[i]
		if rank <= b[1] then
			if b[1] == a[1] then
				return b[2]
			end
			return a[2] + (b[2] - a[2]) * (rank - a[1]) / (b[1] - a[1])
		end
	end
	return last[2]
end

-- A `values` field at `level` (rank). S83 (balance plan 2.2): a { rank 1, max rank } pair with knots in
-- Data/SkillCurves goes through them (Skills.interpolate); without knots it is exactly Skills.scaled. Every scaling
-- of a `values` field goes through here (cost, cooldown and durations stay on Skills.scaled).
function Skills.valueAt(skill: SkillDef, field: string, level: number): number
	local value = skill.values[field]
	local byField = SkillCurves.knots[skill.id]
	local knots = byField and byField[field]
	if knots == nil or type(value) ~= "table" then
		return Skills.scaled(skill, value, level)
	end
	local points: { { number } } = { { 1, value[1] } }
	local ranks: { number } = {}
	for rank in knots do
		table.insert(ranks, rank)
	end
	table.sort(ranks)
	for _, rank in ranks do
		table.insert(points, { rank, knots[rank] })
	end
	table.insert(points, { math.max(1, skill.maxLevel), value[2] or value[1] })
	return Skills.interpolate(points, level)
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

-- S76: castTime, interval and ringRadius (Hunter breakpoints and nodes, ROZWOJ 11)
local NUMERIC_FIELDS = {
	"range",
	"radius",
	"hitRadius",
	"angle",
	"length",
	"width",
	"hits",
	"delay",
	"castTime",
	"interval",
	"ringRadius",
	"burnStacks", -- S140 (Logic/Burn)
}

-- The skill as it works at `rank` (ROZWOJ 2.7). Sources in order: breakpoint 5, breakpoint 10 (chosen option, A
-- without a choice), then `mods` (modify nodes, row order). Rules: `values` add to the current value (the base scales
-- once), `add` sums, `mul` multiplies, `effect` / `selfEffect` / `allyEffect` go to the effects / selfEffects /
-- allyEffects lists, every other key: the later source wins. `add.effectDuration` lengthens every effect of the
-- skill (effects, selfEffects, allyEffects; S75), `add.<kind>Duration` only the `effects` of that kind (S75).
-- S78: an effect deeply equal to one already on its list is not added again (values were summed).
-- S76: `finisher` merges into def.finisher (each source overrides the fields it gives); castTime stays >= 0.
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
	local addKind: { [string]: number } = {}
	local jumps = 0
	local none: { [string]: number } = {}
	-- S78: identical effects from several sources merge: their values were already summed (ROZWOJ 2.7)
	local function addEffect(list: { SkillData.SkillEffect }, effect: SkillData.SkillEffect)
		for _, present in list do
			if TableUtil.deepEqual(present, effect) then
				return
			end
		end
		table.insert(list, effect)
	end
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
			elseif string.sub(key, -8) == "Duration" then
				-- S75: one effect kind, e.g. armorBreakDuration (the {<kind>Duration} placeholder name)
				local kind = string.sub(key, 1, -9)
				addKind[kind] = (addKind[kind] or 0) + amount
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
			def.values[field] = Skills.valueAt(def, field, rank) + amount
		end
		for key, v in bp :: any do
			if key == "effect" then
				addEffect(effects, v)
			elseif key == "selfEffect" then
				addEffect(selfEffects, v)
			elseif key == "allyEffect" then
				addEffect(allyEffects, v)
			elseif key == "finisher" then
				local merged = if def.finisher then table.clone(def.finisher) else {}
				for field, x in v do
					merged[field] = x
				end
				def.finisher = merged
			elseif key ~= "add" and key ~= "mul" and key ~= "values" then
				behaviour[key] = v -- later wins: breakpoint 5, breakpoint 10, nodes by row
			end
		end
	end
	if jumps ~= 0 then
		def.values.jumps = Skills.valueAt(def, "jumps", rank) + jumps
	end
	-- S75: add.effectDuration lengthens every list (the self and party copies last as long as the skill);
	-- add.<kind>Duration only `effects` of that kind
	local function lengthen(list: { SkillData.SkillEffect }, byKind: boolean)
		for i, effect in list do
			local extra = addDuration + (if byKind then addKind[effect.kind] or 0 else 0)
			if extra ~= 0 then
				local copy = table.clone(effect)
				copy.duration = math.max(0.5, Skills.scaled(skill, effect.duration, rank) + extra)
				list[i] = copy
			end
		end
	end
	lengthen(effects, true)
	lengthen(selfEffects, false)
	lengthen(allyEffects, false)
	def.effects = effects
	def.selfEffects = if #selfEffects > 0 then selfEffects else nil
	def.allyEffects = if #allyEffects > 0 then allyEffects else nil
	if def.castTime ~= nil then
		def.castTime = math.max(0, def.castTime)
	end
	if behaviour.steadfast then
		-- S70: channel rules read the definition (Logic/Channel.stops, S76 stores def = ctx.skill)
		def.steadfast = true
	end
	if behaviour.channelMove then
		-- S79: channel rules read the definition (Logic/Channel.stops: a channel with channelMove survives moving)
		def.channelMove = behaviour.channelMove
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

-- S56 (ROZWOJ 2.5, 2.6): ranks came from the character level. S137 (DESIGN-18 §3.1): ranks are bought with skill
-- points (Logic/SkillPoints); rankAt / rankFor are the LIMIT of a rank at a level (and the legacy rank of migration 12).

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

-- S137: a base skill of the weapon pool (SkillDef.pool "common" or the pool id; Logic/SkillPools.memberDef for the
-- full rule); nil = any pool.
local function ofPool(skill: SkillDef, poolId: string?): boolean
	return poolId == nil or skill.pool == "common" or skill.pool == poolId
end

-- Base skills of the class unlocked at `level`, by unlock level (tie: order); S137: only those of `poolId` when given.
-- base only; path skills: Logic/Paths
function Skills.unlocked(classId: string, level: number, poolId: string?): { SkillDef }
	local out: { SkillDef } = {}
	local list: { SkillDef } = SkillData.byClass[classId] or {}
	for _, skill in list do
		if skill.path == nil and skill.unlock <= level and ofPool(skill, poolId) then
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
-- S137: of `poolId` when given (the ranks are bought now: Logic/SkillPoints.startBar fills a bar from them).
function Skills.startHotbar(classId: string, level: number, poolId: string?): { [string]: string }
	local bar: { [string]: string } = {}
	local slot = 0
	for _, skill in Skills.unlocked(classId, level, poolId) do
		if skill.type ~= "passive" and slot < SkillData.HOTBAR_SLOTS then
			slot += 1
			bar[tostring(slot)] = skill.id
		end
	end
	return bar
end

-- Base skills of the class with fromLevel < unlock <= toLevel, in unlock order (path skills reach the bar when their
-- node is bought, never on a level-up).
function Skills.newlyUnlocked(classId: string, fromLevel: number, toLevel: number, poolId: string?): { SkillDef }
	local out: { SkillDef } = {}
	for _, skill in Skills.unlocked(classId, toLevel, poolId) do
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
	-- S76: the caster's hooks (Paths.passiveTotals(...).hooks)
	-- cost hooks in %: areaCost / spellCost (S79) plus = dearer; trapCost (S76) plus = cheaper (a discount);
	-- chargeCost (S80): percentage points per charge, plus = dearer
	hooks: { [string]: number }?,
	-- S80: Arcane Charges the caster holds (they raise the cost of spells only, Skills.isSpell)
	charges: number?,
}

-- A hook from an optional table (0 when missing). Callers name the hook as a literal (paths.spec hook receivers).
local function hookValue(hooks: { [string]: number }?, id: string): number
	return if hooks then hooks[id] or 0 else 0
end

local COST_REDUCE_CAP = (Stats.get("costReduce") :: any).cap :: number

-- S80 (ROZWOJ 12.5) Arcane Charges --------------------------------------------------------------------------------

local CHARGES = SkillData.ARCANE_CHARGES

-- Cost factor of `charges` Arcane Charges; chargeCost = the hook in percentage points per charge (minus = cheaper).
function Skills.chargeCostFactor(charges: number, chargeCost: number?): number
	return 1 + charges * math.max(0, CHARGES.cost + (chargeCost or 0)) / 100
end

-- Damage factor of `charges` Arcane Charges on a spell other than the consumer (chargeDamage hook in points).
function Skills.chargeDamageFactor(charges: number, chargeDamage: number?): number
	return 1 + charges * (CHARGES.damage + (chargeDamage or 0)) / 100
end

-- Arcane Discharge: +perCharge % for each charge it consumes.
function Skills.dischargeFactor(perCharge: number, charges: number): number
	return 1 + perCharge * charges / 100
end

-- Charges after gaining `gain` (0..max).
function Skills.chargesAfterGain(current: number, gain: number): number
	return math.clamp(current + gain, 0, CHARGES.max)
end

-- Charges that still count: none out of combat or after the entry's end (15 s).
function Skills.chargesNow(stacks: number, expiresAt: number, now: number, inCombat: boolean): number
	if not inCombat or expiresAt <= now then
		return 0
	end
	return stacks
end

-- The skill consumes Arcane Charges (Arcane Discharge: values.perCharge; no fixed id in code).
function Skills.consumesCharges(def: SkillDef): boolean
	return def.values ~= nil and def.values.perCharge ~= nil
end

-- (paid, base) from a base cost: the S79 hooks (areaCost / spellCost), then Arcane Charges (damaging spells),
-- then the saving (costReduce, S62). Charges raise the base cost; the saving applies to them too (STATY 3, S80).
local function applyCostMods(skill: SkillDef, base: number, mods: CostMods?): (number, number)
	local hooks = if mods then mods.hooks else nil
	local pct = if mods and mods.costPct then mods.costPct else 0
	local spell = Skills.isSpell(skill)
	-- S79 (ROZWOJ 14.4): spell cost hooks in the base (before the item saving), plus = dearer
	if spell then
		pct += hookValue(hooks, "spellCost")
		if Skills.tag(skill) == "area" then
			pct += hookValue(hooks, "areaCost")
		end
	end
	base *= math.max(0, 1 + pct / 100)
	-- S76 (ROZWOJ 11.4, Poacher's Thrift): a node discount, so it sits in the base next to costPct
	local trapCost = if skill.type == "trap" then hookValue(hooks, "trapCost") else 0
	if trapCost ~= 0 then
		base *= math.max(0, 1 - trapCost / 100)
	end
	-- S80: Arcane Charges, a factor of its own after the S79 hooks
	local charges = if mods and mods.charges then mods.charges else 0
	if spell and charges > 0 then
		base *= Skills.chargeCostFactor(charges, hookValue(hooks, "chargeCost"))
	end
	local saving = math.clamp(if mods and mods.costReduce then mods.costReduce else 0, 0, COST_REDUCE_CAP)
	return base * (1 - saving / 100), base
end

-- Resource cost of `skill` (the def after Skills.effective, so breakpoint cost changes apply) at rank `rank` for a
-- character of level `level` and class `classId`. Mana skills of a class with a "manaCost.<classId>" level curve cost
-- more with the level (Mage, owner answer 25). Not rounded: the server and the skill bar compare the same number.
-- One function for the server, the skill bar, the description and the wiki; `rank` comes from the character level.
-- (paid, base): base holds the curve, the S79 cost hooks and Arcane Charges; the saving (costReduce) comes last
-- (STATY 3, S80). A call that keeps one value gets what the player pays.
function Skills.cost(skill: SkillDef, rank: number, level: number, classId: string, mods: CostMods?): (number, number)
	local base = Skills.scaled(skill, skill.cost, rank)
	if base <= 0 then
		return 0, 0
	end
	local curve = "manaCost." .. classId
	if skill.resource == "mana" and LevelCurves.has(curve) then
		base *= LevelCurves.at(curve, level)
	end
	return applyCostMods(skill, base, mods)
end

-- S87 (/balance, approximation of T-SK4 without mana refunds or Invocation): mana per second of casting every listed
-- skill on its cooldown, sum of Skills.cost / cooldown over the mana skills with a cooldown above 0.
export type DemandEntry = { skill: SkillDef, rank: number, cooldown: number }
function Skills.manaDemand(list: { DemandEntry }, level: number, classId: string, mods: CostMods?): number
	local total = 0
	for _, entry in list do
		if entry.skill.resource == "mana" and entry.cooldown > 0 then
			total += Skills.cost(entry.skill, entry.rank, level, classId, mods) / entry.cooldown
		end
	end
	return total
end

-- S80: Arcane Torrent's mana per tick. Percent of max mana, so no mana curve (ROZWOJ 12.5); the same modifiers as
-- Skills.cost (one rule for the server, the bar and the tooltip).
function Skills.drain(skill: SkillDef, rank: number, maxMana: number, mods: CostMods?): (number, number)
	local pct = if skill.values.drain ~= nil then Skills.valueAt(skill, "drain", rank) else 0
	local base = maxMana * pct / 100
	if base <= 0 then
		return 0, 0
	end
	return applyCostMods(skill, base, mods)
end

-- S80: ticks of a beam (after Skills.effective: Inexhaustible Torrent's +1 s gives 10).
function Skills.beamTicks(def: SkillDef): number
	local duration = if type(def.duration) == "number" then def.duration else 0
	return math.max(1, math.floor(duration / (def.interval or 0.5) + 1e-6))
end

-- S80: tick n of a beam deals dmg x (1 + growth % x (n - 1)).
function Skills.beamTickPct(dmg: number, growth: number, n: number): number
	return dmg * (1 + growth / 100 * (n - 1))
end

-- S64 (STATY 6): types whose damage is a ranged / melee blow. S74: a shout strikes around the caster like circleSelf;
-- S77: the Falcon (companion) strikes from the air like a trap; S80: a beam is ranged.
local RANGED_TYPES: { [string]: boolean } = table.freeze({
	projectile = true,
	chain = true,
	circleTarget = true,
	line = true,
	trap = true,
	companion = true,
	beam = true,
} :: { [string]: boolean })
local MELEE_TYPES: { [string]: boolean } =
	table.freeze({ charge = true, circleSelf = true, shout = true } :: { [string]: boolean })

-- S64 (STATY 6): the kind of blow the rule gives a skill that deals damage; nil for the rest (buffs, heals, blinks,
-- a shout without values.dmg...: any value, data.spec still requires one). The skill window shows the label only
-- where this is not nil.
function Skills.deliveryRule(def: SkillDef): ("melee" | "ranged")?
	local kind = def.type
	if kind == "shout" and (def.values == nil or def.values.dmg == nil) then
		return nil
	elseif RANGED_TYPES[kind] then
		return "ranged"
	elseif MELEE_TYPES[kind] then
		return "melee"
	end
	local reach = Combat.meleeRange + Combat.rangeTolerance
	if kind == "target" then
		return if (def.range or 0) <= reach then "melee" else "ranged"
	elseif kind == "cone" then
		return if (def.radius or 0) <= reach then "melee" else "ranged"
	end
	return nil
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
	local hpField, magField = prefix .. "Hp", prefix .. "Mag"
	local curve = Skills.healMul(level)
	if def.values[hpField] == nil and def.values[magField] == nil then
		return magAtk * curve * Skills.valueAt(def, prefix, rank) / 100
	end
	-- S83: through valueAt (knots of Data/SkillCurves); a missing field is 0 as before
	return targetMaxHp * Skills.valueAt(def, hpField, rank) / 100
		+ magAtk * curve * Skills.valueAt(def, magField, rank) / 100
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

-- S76: numeric breakpoint behaviours a description may name.
local BEHAVIOUR_ARGS = { "poisonStacks", "critCdr", "poisonSpread", "markJump", "firstWave" }

-- S76 (ROZWOJ 16.5): pull radius of a skill after Skills.effective: the breakpoint's `pull` overrides the skill's; a
-- number is the radius, true the skill's radius; 0 = no pull. Skills/Context.pull and descriptions read it.
function Skills.pullRadius(def: SkillDef, behaviour: Behaviour?): number
	local spec: any = if behaviour and behaviour.pull ~= nil then behaviour.pull else def.pull
	if spec == true then
		return def.radius or 0
	elseif type(spec) == "number" then
		return spec
	end
	return 0
end

-- Options of a description: `level` = character level (default: the level the rank unlocks at, as on the wiki);
-- `choices` / `mods` as in Skills.effective (S55; nil = option A, no nodes).
-- S64: `cdr` = % item cooldown reduction (Skills.cooldown; nil = none, as on the wiki).
-- S76: `hooks` = the character's hooks (trapCost; nil = none, as on the wiki).
export type DescOpts = {
	level: number?,
	choices: Choices?,
	mods: { SkillMod }?,
	cdr: number?,
	hooks: { [string]: number }?,
}

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
	local cost = Skills.cost(skill, rank, L, base.class, if opts and opts.hooks then { hooks = opts.hooks } else nil)
	args.cost = round(cost)
	-- S144 (Logic/Crossbow): Quick Reload shortens the Crossbow's skills only
	local cdr = Crossbow.cdrFor(base.pool, opts and opts.cdr, hookValue(opts and opts.hooks, "quickReload"))
	args.cooldown = round(Skills.cooldown(skill, rank, cdr, behaviour))
	if skill.duration then
		args.duration = round(Skills.scaled(skill, skill.duration, rank))
	end
	local effects: { SkillData.SkillEffect } = skill.effects or {}
	for _, effect in effects do
		args[`{effect.kind}Duration`] = round(Skills.scaled(skill, effect.duration, rank))
	end
	-- S79 Broad Rings: the circle as it grows with the areaRadius hook
	args.radius = if opts and opts.hooks
		then round(Skills.areaRadius(skill, hookValue(opts.hooks, "areaRadius")) or 0)
		else skill.radius or 0
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
	-- S76 (Hunter, S77-S78 texts): only when the field exists, so a placeholder without data fails the locale test
	if skill.castTime then
		args.castTime = round(skill.castTime)
	end
	-- S77: the Falcon's strike interval; only for companions (other skills with `interval` keep their wiki args)
	if skill.type == "companion" and skill.interval then
		args.interval = round(skill.interval)
	end
	-- S80: only for beams (other skills keep their wiki args)
	if skill.type == "beam" then
		args.ticks = Skills.beamTicks(skill)
	end
	if skill.ringRadius then
		args.ringRadius = round(skill.ringRadius)
	end
	-- S70 Wheel of Fortune: the misfortune circle (Skills/Context reads the same field)
	if skill.roll and skill.roll.enemyRadius then
		args.enemyRadius = round(skill.roll.enemyRadius)
	end
	local finisher: any = skill.finisher
	if finisher and finisher.hp and finisher.mul then
		args.finisherHp = round(finisher.hp)
		args.finisherMul = round(finisher.mul)
	end
	for _, key in BEHAVIOUR_ARGS do
		local v = (behaviour :: any)[key]
		if type(v) == "number" then
			args[key] = round(v)
		end
	end
	local pull = Skills.pullRadius(skill, behaviour)
	if pull > 0 then
		args.pullRadius = round(pull)
	end
	-- S140 (Logic/Burn): only for skills that have them
	if skill.values.detonate ~= nil then
		args.stunAt = SkillData.BURN.stunAt
	end
	if skill.burnStacks then
		args.burnStacks = round(skill.burnStacks)
	end
	if skill.knockback and args.knockback == nil then
		args.knockback = round(skill.knockback)
	end
	-- S141 (Logic/Chill): only for skills that have them
	if skill.travel then
		args.travel = round(skill.travel)
	end
	if skill.freezeWave then
		args.freezeWave = skill.freezeWave
	end
	for _, effect in effects do
		if effect.maxStacks then
			args[`{effect.kind}Stacks`] = effect.maxStacks
		end
	end
	local hooks = skill.passive and skill.passive.hooks
	local chill = SkillData.CHILL
	if hooks and hooks.chillFreeze then
		args.threshold = chill.threshold
	end
	if skill.element == "ice" or (hooks and hooks.chillFreeze) then
		-- Winter's Grip raises it (the server's Chill.deepPct); the wiki passes no hooks
		args.deepPct = Chill.deepPct(hookValue(opts and opts.hooks, "deepChill"))
		args.deepDuration = chill.deepDuration
	end
	if skill.values.barrier ~= nil then
		args.barrierSlow = chill.barrierSlow
	end
	-- S142 (Logic/Shock): only for skills that have them
	if skill.type == "target" and skill.delay then
		args.delay = round(skill.delay)
	end
	if skill.type == "line" and skill.width then
		args.width = round(skill.width)
	end
	local finale = skill.finale
	if finale then
		args.finaleKnockback = round(finale.knockback)
		args.finaleStun = round(finale.stun)
	end
	if hooks and hooks.conduct then
		args.conductRadius = SkillData.SHOCK.conductRadius
	end
	-- S143 (Logic/Fury, Logic/Block): only for skills that have them
	if skill.furyGain then
		args.furyGain = round(skill.furyGain)
	end
	if skill.values.perBlock ~= nil then
		args.blockWindow = SkillData.BLOCK.window
		args.blockMax = SkillData.BLOCK.max
	end
	-- S144 (Logic/Crossbow): only for skills that have them
	if hooks and hooks.toxicTips then
		args.tipStacks = SkillData.CROSSBOW.tipStacks
		args.tipDuration = SkillData.CROSSBOW.tipDuration
		args.tipGap = SkillData.CROSSBOW.tipGap
	end
	return args
end

function Skills.formatDescription(skill: SkillDef, rank: number, lang: string?, opts: DescOpts?): string
	return Locale.T(skill.descKey, Skills.descriptionArgs(skill, math.max(1, rank), opts), lang)
end

-- S79 (ROZWOJ 12.3, 14.4): spell tags, area / single target bonuses, zones and Mage hooks ---------------------------

-- S79 (ROZWOJ 12.3): circle, cone, line and chain spells are "area", everything else "single".
-- Not Traits.isAreaSkill (S63): that one also counts traps, for the 1/3 on-hit trait share.
local AREA_TAG_TYPES: { [string]: boolean } =
	table.freeze({ circleSelf = true, circleTarget = true, cone = true, line = true, chain = true })

export type SpellTag = "area" | "single"

function Skills.tag(def: SkillDef): SpellTag
	if AREA_TAG_TYPES[def.type] then
		return "area"
	end
	return "single"
end

-- A spell has values.dmg (spells get spellCost / areaCost and the spell bonuses).
function Skills.isSpell(def: SkillDef): boolean
	return def.values ~= nil and def.values.dmg ~= nil
end

-- "Area" bonuses: a secondary hit (splash, pierce, arc, split) always, an area spell when it hits at least
-- SkillData.AREA_MIN_HITS enemies.
function Skills.areaApplies(tag: string, count: number, secondary: boolean): boolean
	return secondary or (tag == "area" and count >= SkillData.AREA_MIN_HITS)
end

-- "Single target" bonuses: every main hit of a single-target spell (both bolts of Bolt 10B), never a secondary one.
function Skills.singleApplies(tag: string, secondary: boolean): boolean
	return tag == "single" and not secondary
end

-- Enemies an area wave counts: Thunderstorm (randomTarget) counts the enemies in its circle, though its bolt strikes
-- one; every other spell the enemies it struck.
function Skills.areaCount(def: SkillDef, inCircle: number, struck: number): number
	if def.randomTarget then
		return inCircle
	end
	return struck
end

-- % bonus of one hit: areaDamage when the area rule holds, singleDamage on a single-target main hit, spellDamage
-- always. One sum, so the tag bonuses and the spell bonus are one factor (1 + sum / 100).
function Skills.spellBonus(tag: string, count: number, secondary: boolean, hooks: { [string]: number }?): number
	local sum = hookValue(hooks, "spellDamage")
	if Skills.areaApplies(tag, count, secondary) then
		sum += hookValue(hooks, "areaDamage")
	end
	if Skills.singleApplies(tag, secondary) then
		sum += hookValue(hooks, "singleDamage")
	end
	return sum
end

-- Resonance: x (1 + pct / 100) while the mana before the cast (fraction of the pool) is at least
-- SkillData.RESONANCE_MANA %.
function Skills.resonanceMul(manaFraction: number, pct: number): number
	if pct > 0 and manaFraction * 100 >= SkillData.RESONANCE_MANA then
		return 1 + pct / 100
	end
	return 1
end

-- A lasting area of a cast: `pct` % of attack per tick (one tick a second), `element` = the weapon element's ground.
export type Zone = {
	pct: number,
	duration: number,
	radius: number,
	kind: string,
	slow: number?,
	element: boolean?,
}

-- Zones of wave `wave` of a cast dealing `percent` (ROZWOJ 14.4): only the first wave makes them. The breakpoint's
-- lingering zone, and next to it (not instead) the areaLingering zone of circle spells: hookPct % of the spell's
-- value per target (dmg x waves; randomTarget: divided by the enemies `inCircle`, none without enemies) for
-- SkillData.AREA_LINGER_SECONDS s.
function Skills.castZones(
	def: SkillDef,
	behaviour: Behaviour,
	wave: number,
	percent: number,
	hookPct: number,
	inCircle: number
): { Zone }
	local zones: { Zone } = {}
	if wave ~= 1 then
		return zones
	end
	local spec = behaviour.lingering
	if spec then
		table.insert(zones, {
			pct = percent * spec.pct / 100,
			duration = spec.duration,
			radius = spec.radius or def.radius or 8,
			kind = spec.kind,
			slow = spec.slow,
			element = if spec.kind == "element" then true else nil,
		})
	end
	local circle = def.type == "circleSelf" or def.type == "circleTarget"
	if hookPct > 0 and circle and Skills.tag(def) == "area" and Skills.isSpell(def) then
		local share = if def.randomTarget then inCircle else 1
		if share >= 1 then
			table.insert(zones, {
				pct = percent * (def.hits or 1) / share * hookPct / 100,
				duration = SkillData.AREA_LINGER_SECONDS,
				radius = def.radius or 8,
				kind = "element",
				element = true,
			})
		end
	end
	return zones
end

-- Ground kind of a weapon element's zone (the client draws an unknown kind in the element's colour).
function Skills.zoneKind(element: string?): string
	if element == "fire" then
		return "burn"
	elseif element == "ice" then
		return "frost"
	elseif element == "lightning" then
		return "spark"
	end
	return "arcane"
end

-- Cascade (areaKillMana): mana an area spell's killing hit gives, pct % of max mana.
function Skills.areaKillMana(tag: string, killed: boolean, dealt: number, pct: number, maxMana: number): number
	if tag == "area" and killed and dealt > 0 and pct > 0 then
		return maxMana * pct / 100
	end
	return 0
end

-- An own damage reduction of a Mage hook, as StatusEffectService.Apply options plus its kind.
export type GuardSpec = {
	kind: string,
	value: number,
	duration: number,
	category: string,
	skillId: string,
	target: string,
}

-- Master Mind (channelGuard): damage reduction for the whole channel; it ends with the channel (SkillService).
-- S80 (ROZWOJ 14.4): on a "channel" or a "beam" (Arcane Torrent); never on aiming.
function Skills.channelGuard(kind: string, value: number, duration: number): GuardSpec?
	if (kind ~= "channel" and kind ~= "beam") or value <= 0 or duration <= 0 then
		return nil
	end
	return {
		kind = "damageReduction",
		value = value,
		duration = duration,
		category = "own",
		skillId = "arcanist_masterMind",
		target = "self",
	}
end

-- Mantle of Elements (vortexGuard): damage reduction until the last wave of Elemental Vortex.
function Skills.castGuard(def: SkillDef, value: number): GuardSpec?
	if def.id ~= SkillData.VORTEX_SKILL or value <= 0 then
		return nil
	end
	local duration = ((def.hits or 1) - 1) * (def.interval or 0.4)
	if duration <= 0 then
		return nil
	end
	return {
		kind = "damageReduction",
		value = value,
		duration = duration,
		category = "own",
		skillId = "destroyer_mantle",
		target = "self",
	}
end

-- Broad Rings (areaRadius): the radius of a circle spell grown by pct %; other skills keep theirs (a chain's jump
-- radius is not a circle).
function Skills.areaRadius(def: SkillDef, pct: number): number?
	local circle = def.type == "circleSelf" or def.type == "circleTarget"
	if circle and Skills.tag(def) == "area" and def.radius ~= nil then
		return def.radius * (1 + pct / 100)
	end
	return def.radius
end

-- Mana Shield with manaShieldCost (plus = more mana): (damage absorbed, mana spent) of `amount` when the shield takes
-- `share` % and the player has `mana`. With costPct 0 both are today's min(mana, amount x share / 100).
function Skills.manaShieldSplit(amount: number, share: number, mana: number, costPct: number): (number, number)
	local want = amount * share / 100
	local rate = math.max(0, 1 + costPct / 100)
	if rate == 0 then
		return want, 0
	end
	local absorbed = math.min(want, mana / rate)
	-- clamp: absorbed x rate can land a few ULPs above mana, and SpendMana refuses more than the pool
	return absorbed, math.min(mana, absorbed * rate)
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
	elseif kind == "shout" or kind == "companion" then
		return "self" -- S74; S77: the Falcon's fallback reach around the caster
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
	if def.type == "companion" then
		return true -- S77: the Falcon attacks
	end
	return def.type == "shout" and def.values.dmg ~= nil
end

-- The weapon element a Mage skill belongs to (S18; shown in the skill's details and on the wiki). S142 (DESIGN-18 §4.1):
-- no cast check reads it any more: the weapon's element picks the pool and every element skill sits in its own pool
-- (cast.error.wrongPool), so the old Skills.elementAllowed is gone.
function Skills.requiredElement(skill: SkillDef): string?
	if skill.class ~= "Mage" or skill.adaptive or not skill.element then
		return nil
	end
	return skill.element
end

return Skills
