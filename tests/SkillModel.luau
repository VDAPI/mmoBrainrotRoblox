--!strict
-- Skill model (S85, balance plan D1, ROZWOJ 0 / 7.5 / 8): a time-stepped, expected-value fight that casts the real
-- skills of a build (ranks from the level, A/B breakpoints, path nodes, resources, potions) on the game's own pure
-- functions (Paths.effectiveFor, Paths.passiveTotals, StatCalc, Damage, EffectStack, Skills.cost / cooldown / healAmount,
-- Traits). The guard next to the S32 convention (FightSim.SKILL_DPS = x1.2 stays the main model of the G targets).
-- Never game code: test data and measurement assumptions only, nothing in BALANCE_MODULES or on the wiki.
--
--   builds(classId)                 the class base (BASE, rows 1 of every path; Mage rows 1-2) and every
--                                   PathDef.reference (key "<pathId>.<id>"), rotation from the data only
--   character(build, L)             the build trimmed to L: level-up simulation through Paths.canChooseMain / canBuy
--   player(build, L, opts?)         Balance.gear + StatPlan.suggest + Paths.passiveTotals + circle auras
--   fight(sp, opts)                 the engine (port of Skills/Context, Types/Offense, Types/Support, Types/Movement,
--                                   SkillService.cast, CombatService.DealDamage / tryBasicAttack, StatusEffectService)
--   metrics(build, L, opts?)        T-SK1..4 numbers of one row; oneHeal (T-SK5); healerVsBoss (T-SK6)
--   targetsG10() / targetsMeadows() TargetRow lists for balance.spec (report mode) and docs/BALANS.md
--   HANDLERS / BEHAVIOURS           registries: S86 adds the class mechanics here
--
-- Inventory (A3; the full table with counts is in docs/SESJE.md, S85):
--   S85 here: types target, projectile, cone, circleSelf, circleTarget, line, chain, charge, buff, debuff, heal, hot,
--     shield, channel, groupBuff, groupHeal, trap (05b859d shape: effects on the first entry), blink, resurrect;
--     behaviours splash, pierce, lingering (Skills.castZones), echo, split, execute, finisher, firstWave, bleedStacks,
--     poisonStacks, lifesteal, secondTarget, overhealShield, selfHeal, healWounded, burst, stunSplash, cdrPerTarget,
--     critCdr, cleanse, effect / selfEffect / allyEffect; effects statBuff, bleed, poison, armorBreak, vulnerability,
--     nextShot, guaranteedCrit, sighted, hot, shield; hooks elementDamage, holyDamage, areaSkillDamage, eliteDamage,
--     bossDamage, executioner, vs_<family>, damagePerEnemy, weakSpot, dotPower, bleedDamage, poisonDamage,
--     elementRider, riderSameTarget, doubleAttack, manaOnHit, cooldownReduction, zealCdr, the cost hooks (through
--     Skills.cost), heal hooks (healBonus, allyHealBonus, lowHpHealBonus, healCrit, holyStrikeHeal, holyHealAll).
--   S86 (unmodelled, listed per build): types guard, shout, banner, companion, beam, healZone; castTime; Fury
--     (furyConsume, carnage, fury hooks); Arcane Charges and empowered; burn effects; accumulate; spell tag bonuses
--     (areaDamage, singleDamage, spellDamage, resonance); trap damage / rings / pulls / energy; dice; healZone,
--     chainHeal, shieldPerHit, allyHeal, allyShield, behindEffect, shieldBurst; item trait hooks and effects; returns.
--   No effect on a dummy: movement, knockback, pulls, stuns, slows, freezes, roots, taunt, camouflage, damage
--     reduction, invulnerability, mana shield, intercept, kills (poisonSpread, markJump, extendOnKill), defensive hooks.

local B = require("./Balance")
local Bonuses = require("../src/shared/Data/Bonuses")
local BuffCategories = require("../src/shared/Data/BuffCategories")
local Bosses = require("../src/shared/Data/Bosses")
local Chain = require("../src/shared/Logic/Chain")
local Classes = require("../src/shared/Data/Classes")
local Combat = require("../src/shared/Data/Combat")
local Damage = require("../src/shared/Logic/Damage")
local EffectStack = require("../src/shared/Logic/EffectStack")
local Items = require("../src/shared/Data/Items")
local MonsterStats = require("../src/shared/Logic/MonsterStats")
local PathData = require("../src/shared/Data/Paths")
local Paths = require("../src/shared/Logic/Paths")
local Potions = require("../src/shared/Logic/Potions")
local SkillData = require("../src/shared/Data/Skills")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local Skills = require("../src/shared/Logic/Skills")
local StatPlan = require("../src/shared/Logic/StatPlan")
local Traits = require("../src/shared/Logic/Traits")

local SkillModel = {}

-- Test data (assumptions of the measurement, never game numbers) --------------------------------------------------

SkillModel.ASSUMPTIONS = {
	dt = 0.05, -- s per step (diag SkillEngine E.DT)
	burstSeconds = 8, -- T-SK2 / T-SK3 window (balance plan D1)
	sustainedSeconds = 60, -- T-SK1 window (balance plan D1, diag_skills)
	areaTargets = 3, -- T-SK3 dummies (balance plan D1)
	dummyHp = 1e12, -- dummies never die (diag_skills)
	-- execute / finisher / executioner on a dummy: "linear" = share of hits below the threshold is threshold / 100, the
	-- dummy's HP falls linearly through the fight (diag SkillEngine belowFraction); "hp" = by the dummy's real HP (it
	-- never falls: no share)
	executeShare = "linear",
	-- every dummy stands at the aim point in reach of every area (ROZWOJ 11.6, 12.7); a pierce hits the second dummy
	-- when there are at least 2; projectile and orb flight is left out (dummies in reach)
	dummySpread = 0,
	elements = { "fire", "ice", "lightning" }, -- the Mage's number is their mean (ROZWOJ 12.7; the diagnosis: fire)
	teamLevelGap = 1, -- T-SK6 party at the boss level - 1 (diag_heal, S92)
	team = { "Warrior", "Mage", "Hunter", "Cleric", "Warrior" }, -- T-SK6 default party, tank first (diag_heal)
	-- S92-S94 party 4 (balance plan D1): the measured healer replaces "healer.dungeon"
	teamS92 = { "guardian.defender", "healer.dungeon", "berserker.fury", "marksman.kingslayer" },
	healTargetFraction = 1, -- HP share of a heal target before the heal: no HP axis until S86 (no low-HP bonus)
}
local A = SkillModel.ASSUMPTIONS

-- The class base (B2, ROZWOJ 2.1): no main path, rows 1 of every path (Mage rows 1-2, 12.7), A everywhere, the class
-- stat plan, the weapon of the class measurement. `loadout` (P2) is Balance.LOADOUT, the diagnosis' weapon.
SkillModel.BASE = {
	Warrior = { rows = 1, weapon = { main = "axe2h" } }, -- ROZWOJ 10.6 (two-handed axe, the reference)
	Hunter = { rows = 1, weapon = { main = "bow", offhand = "quiver" } }, -- ROZWOJ 11.6
	Mage = { rows = 2, weapon = { main = "staff" } }, -- ROZWOJ 12.7
	Cleric = { rows = 1, weapon = { main = "mace1h", offhand = "shield" } }, -- ROZWOJ 9.6 (Balance.LOADOUT)
} :: { [string]: { rows: number, weapon: { main: string, offhand: string? } } }

SkillModel.LEVELS = { 20, 45, 70, 100 } -- the T-SK grid (balance plan D1)
SkillModel.BOSS_AT = { [20] = "grimrok", [45] = "morvane", [70] = "azgor", [100] = "vaelgrath" } :: { [number]: string }
SkillModel.G10_LEVELS = { 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }

local EPS = 1e-6
-- mirrors StatusEffectService TICK_INTERVAL (one DoT / HoT tick per second; Traits.ticks assumes the same)
local TICK = 1
-- mirrors SkillService INSTANT: types without the motion's hit delay
local INSTANT: { [string]: boolean } = { resurrect = true, channel = true, beam = true }
-- mirrors Skills/Context HOLY_HEAL_SKILLS (Holy Wrath, holyHealAll; a server list, "Dla S87")
local HOLY_HEAL_SKILLS: { [string]: boolean } =
	{ radiance = true, judgement = true, brandOfLight = true, hammerOfHeaven = true }
-- mirrors SkillService ZEAL_SKILLS (Ardor, zealCdr)
local ZEAL_SKILLS = { "heal", "purify" }
-- mirrors Types/Offense: a split impact's radius and enemiesInCircle's tolerance
local SPLIT_RADIUS, CIRCLE_TOLERANCE = 3.5, 1.5

-- Types -------------------------------------------------------------------------------------------------------------

export type Build = {
	key: string, -- "<pathId>.<id>", "base", "base.loadout"
	classId: string,
	pathId: string?,
	ref: any?,
	base: boolean,
	weapon: { main: string, offhand: string? },
	areaCap: number,
	rotation: { { [string]: any } },
	nodes: { { any } },
	bp: { [string]: string },
	stats: { [string]: number },
	damageReference: boolean?,
	r7Exempt: boolean?,
}

export type CharacterResult = {
	character: any, -- { class, level, path = { main, nodes, bp, freeUsed }, equipment }
	spent: number,
	free: number,
	unbought: { { node: string, reason: string } },
	rankChecks: number, -- ranks bought, each through Paths.canBuy
}

-- Builds ------------------------------------------------------------------------------------------------------------

local buildCache: { [string]: { Build } } = {}

local function skillNodeOf(classId: string, skillId: string): string?
	for _, path in Paths.pathsOf(classId) do
		for _, row in path.rows do
			for _, node in row.nodes do
				if node.kind == "skill" and node.skill == skillId then
					return node.id
				end
			end
		end
	end
	return nil
end

-- B2 c: the class rotations in path / build order, the first occurrence of a skill wins (with its conditions),
-- kept when `keep(skillId)`.
local function classRotation(classId: string, keep: (string) -> boolean): { { [string]: any } }
	local out: { { [string]: any } } = {}
	local seen: { [string]: boolean } = {}
	for _, path in Paths.pathsOf(classId) do
		for _, ref in path.reference do
			for _, entry in ref.rotation do
				local id = entry.skill
				if not seen[id] then
					seen[id] = true
					if keep(id) then
						table.insert(out, entry)
					end
				end
			end
		end
	end
	return out
end

-- S85 (B1, B2): the class base first (BASE; base.loadout when Balance.LOADOUT differs), then every reference build of
-- every path in Paths order. Builds and rotations are data only; nothing here sorts or filters a priority.
function SkillModel.builds(classId: string): { Build }
	local cached = buildCache[classId]
	if cached then
		return cached
	end
	local out: { Build } = {}
	local spec = SkillModel.BASE[classId]
	local nodes: { { any } } = {}
	local inBase: { [string]: boolean } = {}
	for _, path in Paths.pathsOf(classId) do
		for r = 1, spec.rows do
			for _, node in path.rows[r].nodes do
				table.insert(nodes, { node.id, node.maxRank })
				inBase[node.id] = true
			end
		end
	end
	local rotation = classRotation(classId, function(id: string): boolean
		local skill = SkillData.get(id)
		if not skill then
			return false
		end
		if skill.path == nil then
			return true
		end
		local nodeId = skillNodeOf(classId, id)
		return nodeId ~= nil and inBase[nodeId] == true
	end)
	local class = Classes.get(classId :: any) :: any
	local function base(key: string, weapon: { main: string, offhand: string? }): Build
		return {
			key = key,
			classId = classId,
			pathId = nil,
			ref = nil,
			base = true,
			weapon = weapon,
			areaCap = 2.0, -- ROZWOJ 8 (R3 / T-SK3)
			rotation = rotation,
			nodes = nodes,
			bp = {},
			stats = class.statPlan,
		}
	end
	table.insert(out, base("base", spec.weapon))
	local loadout = B.LOADOUT[classId]
	if loadout.weapon ~= spec.weapon.main or loadout.offhand ~= spec.weapon.offhand then
		local twoHanded = Paths.isTwoHanded(loadout.weapon)
		table.insert(
			out,
			base("base.loadout", { main = loadout.weapon, offhand = if twoHanded then nil else loadout.offhand })
		)
	end
	for _, path in Paths.pathsOf(classId) do
		for _, ref in path.reference do
			table.insert(out, {
				key = `{path.id}.{ref.id}`,
				classId = classId,
				pathId = path.id,
				ref = ref,
				base = false,
				weapon = ref.weapon,
				areaCap = ref.areaCap or 2.0, -- ROZWOJ 8
				rotation = ref.rotation,
				nodes = ref.nodes,
				bp = ref.bp,
				stats = ref.stats,
				damageReference = ref.damageReference,
				r7Exempt = ref.r7Exempt,
			})
		end
	end
	buildCache[classId] = out
	return out
end

-- One build by key ("<pathId>.<id>", "base", "base.loadout") of a class, or of any class for a path key.
function SkillModel.build(key: string, classId: string?): Build?
	for _, c in (if classId then { classId } else B.CLASSES) do
		for _, build in SkillModel.builds(c) do
			if build.key == key then
				return build
			end
		end
	end
	return nil
end

-- Character -------------------------------------------------------------------------------------------------------

local charCache: { [string]: CharacterResult } = {}

-- S85 (B3): level-up from 1 to L on the ROZWOJ 3.2 save shape. The main path (the build's) at Paths.MAIN_LEVEL
-- through Paths.canChooseMain; on every new point the first rank of `nodes` that Paths.canBuy accepts (an entry that
-- cannot be bought yet waits, later ones may pass). Breakpoint choices from the build (Skills.effective applies them
-- from rank 5 / 10).
function SkillModel.character(build: Build, L: number): CharacterResult
	local key = `{build.classId}|{build.key}|{L}`
	local cached = charCache[key]
	if cached then
		return cached
	end
	local path =
		{ main = nil :: string?, nodes = {} :: { [string]: number }, bp = table.clone(build.bp), freeUsed = false }
	local character: any = { class = build.classId, level = 1, path = path, equipment = {} }
	local units: { string } = {}
	for _, entry in build.nodes do
		for _ = 1, entry[2] do
			table.insert(units, entry[1])
		end
	end
	local done: { boolean } = {}
	local checks = 0
	for level = 1, L do
		character.level = level
		if build.pathId and path.main == nil and Paths.canChooseMain(character, build.pathId) then
			path.main = build.pathId
			path.freeUsed = true
		end
		while Paths.free(character) >= 1 do
			local bought = false
			for i, nodeId in units do
				if not done[i] and Paths.canBuy(character, nodeId) then
					path.nodes[nodeId] = (path.nodes[nodeId] or 0) + 1
					done[i] = true
					bought = true
					checks += 1
					break
				end
			end
			if not bought then
				break
			end
		end
	end
	local unbought: { { node: string, reason: string } } = {}
	for i, nodeId in units do
		if not done[i] then
			local _, reason = Paths.canBuy(character, nodeId)
			table.insert(unbought, { node = nodeId, reason = reason or "?" })
		end
	end
	local result: CharacterResult = {
		character = character,
		spent = Paths.spent(character),
		free = Paths.free(character),
		unbought = unbought,
		rankChecks = checks,
	}
	charCache[key] = result
	return result
end

-- Player ----------------------------------------------------------------------------------------------------------

export type PlayerOpts = {
	gear: B.GearOpts?, -- passed on to Balance.gear (rarity, upgrade, traitScale, ilvl ...)
	element: string?, -- the Mage weapon's element (E5)
}

local playerCache: { [string]: any } = {}

local function serialize(t: { [string]: number }): string
	local keys: { string } = {}
	for k in t do
		table.insert(keys, k)
	end
	table.sort(keys)
	local parts: { string } = {}
	for _, k in keys do
		table.insert(parts, `{k}={t[k]}`)
	end
	return table.concat(parts, ",")
end

-- The Balance player of a model player with `flat` / `pct` effect stats (EffectStack.stats of the working statBuffs
-- and auras), cached by the effect set (diag currentPlayer).
local function playerWith(sp: any, flat: { [string]: number }, pct: { [string]: number }): any
	local key = serialize(flat) .. "|" .. serialize(pct)
	local hit = sp.byEffects[key]
	if hit then
		return hit
	end
	local sources: { any } = { { key = "source.passives", flat = sp.passives.flat, pct = sp.passives.pct } }
	if next(flat) ~= nil or next(pct) ~= nil then
		table.insert(sources, { key = "source.effects", flat = flat, pct = pct })
	end
	local p: any = B.playerFromItems(
		sp.classId,
		sp.level,
		sp.items,
		sp.traitScale,
		{ stats = sp.stats, sources = sources, hooks = sp.passives.hooks }
	)
	sp.byEffects[key] = p
	return p
end

-- S85 (B4): the player of `build` at L. Gear of the convention (Balance.gear with the build's weapon), stats from
-- StatPlan.suggest (the "spend as the path suggests" button), path passives / nodes / hooks from Paths.passiveTotals,
-- circle auras of the build on its owner (PartyAuraService covers the owner, solo too). `sp.p` is a Balance.Player
-- (FightSim.dps reads it); `sp.pathHooks` is SkillService.PassiveHook (path and class passives only).
function SkillModel.player(build: Build, L: number, opts: PlayerOpts?): any
	local o: PlayerOpts = opts or {}
	-- cached without gear options (S86 / S88 pass their own GearOpts and keep the player)
	local key = `{build.classId}|{build.key}|{L}|{o.element or "-"}`
	local cached = if o.gear then nil else playerCache[key]
	if cached then
		return cached
	end
	local ch = SkillModel.character(build, L)
	local character = ch.character
	local weapons = { main = build.weapon.main, offhand = build.weapon.offhand }
	local gearOpts: any = if o.gear then table.clone(o.gear :: any) else {}
	gearOpts.weapon = build.weapon.main
	gearOpts.offhand = if build.weapon.offhand then build.weapon.offhand else false
	gearOpts.element = o.element or gearOpts.element
	local items = B.gear(build.classId, L, gearOpts)
	local start = StatPlan.startOf(build.classId) :: any
	local stats = table.clone(start)
	for id, n in StatPlan.suggest(build.stats, start, start, StatPlan.total(L)) do
		stats[id] = (stats[id] or 0) + n
	end
	local passives = Paths.passiveTotals(character, weapons)
	local auraEntries: { any } = {}
	for _, aura in Paths.auras(character, weapons) do
		local category: any = BuffCategories.get(aura.category)
		if aura.shape == "circle" and category and category.kind == "statBuff" then
			table.insert(auraEntries, {
				category = aura.category,
				stats = aura.stats,
				pct = category.mode == "pct",
				at = -1,
			})
		end
	end
	local class = Classes.get(build.classId :: any) :: any
	local sp: any = {
		build = build,
		classId = build.classId,
		level = L,
		character = character,
		weapons = weapons,
		items = items,
		traitScale = gearOpts.traitScale,
		stats = stats,
		passives = passives,
		pathHooks = passives.hooks,
		auraEntries = auraEntries,
		byEffects = {},
		resource = class.resource,
	}
	local flat, pct = EffectStack.stats(auraEntries)
	sp.p = playerWith(sp, flat, pct)
	sp.element = sp.p.element
	-- S54: skill damage x the equipped weapon's base speed / Combat.skillSpeedRef, once per player
	sp.speedMul = Skills.speedFactor(sp.p.weaponSpeed)
	if not o.gear then
		playerCache[key] = sp
	end
	return sp
end

-- A Balance.Player (the S32 convention) as a model player without skills or path (H1 control on Balance.player).
function SkillModel.wrap(p: any): any
	local class = Classes.get(p.classId :: any) :: any
	local sp: any = {
		build = { key = "convention", classId = p.classId, rotation = {} },
		classId = p.classId,
		level = p.level,
		character = { class = p.classId, level = p.level, path = { nodes = {}, bp = {}, freeUsed = false } },
		weapons = {},
		passives = { flat = {}, pct = {}, hooks = {} },
		pathHooks = {},
		auraEntries = {},
		byEffects = { ["|"] = p },
		resource = class.resource,
		p = p,
		element = p.element,
		speedMul = Skills.speedFactor(p.weaponSpeed),
	}
	return sp
end

-- Static unmodelled list of a player (I1 c): hooks and item traits the model does not count yet.
local HOOKS_S85: { [string]: boolean } = {
	elementDamage = true,
	holyDamage = true,
	areaSkillDamage = true,
	eliteDamage = true,
	bossDamage = true,
	executioner = true,
	damagePerEnemy = true,
	weakSpot = true,
	dotPower = true,
	bleedDamage = true,
	poisonDamage = true,
	elementRider = true,
	riderSameTarget = true,
	doubleAttack = true,
	manaOnHit = true,
	cooldownReduction = true,
	zealCdr = true,
	healBonus = true,
	allyHealBonus = true,
	lowHpHealBonus = true,
	healCrit = true,
	holyStrikeHeal = true,
	holyHealAll = true,
	trapCost = true,
	areaCost = true,
	spellCost = true,
	areaLingering = true,
}
-- Hooks that change nothing on a dummy (defence, movement, kills, minimap, radius of areas all dummies stand in).
local HOOKS_NONE: { [string]: boolean } = {
	block = true,
	riposte = true,
	guardPerEnemy = true,
	lastStand = true,
	threat = true,
	interceptMitigation = true,
	interceptThorns = true,
	killHeal = true,
	channelGuard = true,
	vortexGuard = true,
	manaShieldCost = true,
	areaRadius = true,
	minimapEliteBonus = true,
	vigilanceGuard = true,
	vigilanceMove = true,
	poisonedGuard = true,
	poisonSpread = true,
	poisonSlow = true,
	trapRootDuration = true,
	counterDamage = true,
}

local function staticUnmodelled(sp: any): { string }
	local out: { string } = {}
	local seen: { [string]: boolean } = {}
	local function add(text: string)
		if not seen[text] then
			seen[text] = true
			table.insert(out, text)
		end
	end
	for id, v in sp.p.hooks do
		if v ~= 0 and not HOOKS_S85[id] and not HOOKS_NONE[id] and string.sub(id, 1, 3) ~= "vs_" then
			if string.sub(id, 1, 4) ~= "res_" then
				add(`hak {id}`)
			end
		end
	end
	for id, trait in sp.p.traits or {} do
		if trait.def.kind ~= "stat" then
			add(`cecha {id}`)
		end
	end
	table.sort(out)
	return out
end

-- Fight -----------------------------------------------------------------------------------------------------------

export type FightOpts = {
	targets: { any }?, -- MonsterStats (default: Balance.monster(GENERIC, L))
	dummy: boolean?, -- default true: HP without end
	seconds: number?, -- default ASSUMPTIONS.sustainedSeconds
	skills: boolean?, -- false = basic attacks only
	startPool: number?, -- share of the pool at the start (default 1)
	unlimited: boolean?, -- costs count in `spent` but never leave the pool (on cooldown, T-SK4)
	potions: boolean?, -- E4
	control: boolean?, -- H1: leaves out the terms FightSim.dps does not count
	heal: any?, -- F: { tank = Player, team = n }: heal rotation of a Cleric on a boss
}

export type FightResult = {
	seconds: number,
	dealt: number,
	dps: number,
	by: { [string]: number },
	casts: { [string]: number },
	spent: number,
	poolMax: number,
	poolEnd: number,
	regen: number,
	potions: number,
	healTo: { [string]: number },
	skipped: { [string]: { reason: string, count: number } },
	unmodelled: { string },
	firstCasts: { string },
}

local function mark(state: any, text: string)
	state.unmodelled[text] = true
end

local function schedule(state: any, at: number, fn: () -> ())
	state.seq += 1
	local ev = { t = at, seq = state.seq, fn = fn }
	local list = state.events
	local i = #list
	-- insertion keeps (t, seq) order; most events are appended near the end
	while i >= 1 and (list[i].t > at or (list[i].t == at and list[i].seq > ev.seq)) do
		i -= 1
	end
	table.insert(list, i + 1, ev)
end

local function alive(state: any): { any }
	if state.dummy then
		return state.targets -- dummies never die
	end
	local out = {}
	for _, tg in state.targets do
		if tg.hp > 0 then
			table.insert(out, tg)
		end
	end
	return out
end

-- The working Balance player: statBuff effects on the player and the build's circle auras through
-- Logic/EffectStack (StatusEffectService modifierSource), recomputed only when the set changes.
local function current(state: any): any
	if not state.selfDirty then
		return state.p
	end
	state.selfDirty = false
	local entries = table.clone(state.sp.auraEntries)
	for _, e in state.self.effects do
		if e.kind == "statBuff" then
			table.insert(entries, { category = e.category, stats = e.stats, pct = e.pct, at = e.appliedAt })
		end
	end
	local flat, pct = EffectStack.stats(entries)
	state.p = playerWith(state.sp, flat, pct)
	return state.p
end

-- CombatService.Hook (items + path passives) and SkillService.PassiveHook (path passives only).
local function hook(state: any, id: string): number
	return current(state).hooks[id] or 0
end
local function pathHook(state: any, id: string): number
	return state.sp.pathHooks[id] or 0
end

-- mirrors CombatService.DotBonus
local function dotBonus(state: any, kind: string): number
	if kind == "bleed" then
		return hook(state, "dotPower") + hook(state, "bleedDamage")
	elseif kind == "poison" then
		return hook(state, "dotPower") + hook(state, "poisonDamage")
	elseif kind == "burn" then
		return hook(state, "dotPower")
	end
	return 0
end

-- mirrors StatusEffectService.IsBossLike (bosses and Elite II ignore notBoss effects)
local function bossLike(entity: any): boolean
	return entity.m ~= nil and (entity.m.variant == "boss" or entity.m.variant == "elite2")
end

-- mirrors StatusEffectService.Apply (S85 C4). One effect per key (kind, source, skillId, category; the source is
-- always this player), EffectStack.restack (a running effect gains a stack up to maxStacks, keeps nextTick, ends at
-- now + duration; tickAmount x stacks), statBuff merge (EffectStack.merge).
local function apply(state: any, entity: any, kind: string, o: any): boolean
	if (o.duration or 0) <= 0 then
		return false
	end
	if o.notBoss and bossLike(entity) then
		return false
	end
	local t = state.t
	local key = `{kind}|{o.skillId or ""}|{o.category or ""}`
	local e = entity.effects[key]
	local running = e ~= nil and e.expiresAt > t + EPS
	local old = if running
		then {
			stacks = e.stacks,
			value = e.value,
			tickAmount = e.tickAmount,
			expiresAt = e.expiresAt,
			nextTick = e.nextTick,
		}
		else nil
	local st = EffectStack.restack(old, {
		unit = o.value or 0,
		tickUnit = o.tickAmount,
		maxStacks = o.maxStacks,
		duration = o.duration,
		now = t,
		tickInterval = TICK,
	})
	local stats, expiresAt = o.stats, st.expiresAt
	if kind == "statBuff" then
		local timed = if running then { stats = e.stats, pct = e.pct, expiresAt = e.expiresAt } else nil
		stats, expiresAt = EffectStack.merge(timed, { stats = o.stats, pct = o.pct, expiresAt = st.expiresAt }, t)
	end
	entity.effects[key] = {
		kind = kind,
		skillId = o.skillId,
		category = o.category,
		stacks = st.stacks,
		value = st.value,
		tickAmount = st.tickAmount,
		nextTick = st.nextTick,
		expiresAt = expiresAt,
		appliedAt = t,
		stats = stats,
		pct = o.pct,
	}
	if entity == state.self and kind == "statBuff" then
		state.selfDirty = true
	end
	return true
end

local function effectsOf(entity: any, kind: string): { any }
	local out = {}
	for _, e in entity.effects do
		if e.kind == kind then
			table.insert(out, e)
		end
	end
	return out
end

-- mirrors StatusEffectService.Consume / Remove: every self effect of `kind` goes, the first one's value counts
local function takeOne(state: any, kind: string): any?
	local first = nil
	for key, e in state.self.effects do
		if e.kind == kind then
			state.self.effects[key] = nil
			first = first or e
		end
	end
	return first
end

-- Healing done (F): `who` is "self", "tank" or "ally".
local function recordHeal(state: any, who: string, amount: number)
	if amount > 0 then
		state.healTo[who] = (state.healTo[who] or 0) + amount
	end
end

-- mirrors StatusEffectService.tickEntity (S85 C4): the end first, then the tick (a d s effect deals Traits.ticks
-- ticks for d > 1; none for d <= 1); ticks on monsters bypass armour, crit and multipliers (Monster:TakeDamage).
local function tickEntity(state: any, entity: any)
	local t = state.t
	for key, e in entity.effects do
		if e.expiresAt <= t + EPS then
			entity.effects[key] = nil
			if entity == state.self and e.kind == "statBuff" then
				state.selfDirty = true
			end
			continue
		end
		if e.nextTick and e.tickAmount and t + EPS >= e.nextTick then
			e.nextTick += TICK
			if e.kind == "hot" then
				recordHeal(state, entity.who or "self", e.tickAmount)
			elseif entity.m and entity.hp > 0 then
				entity.hp -= e.tickAmount
				state.dealt += e.tickAmount
				local bucket = e.skillId or "dot"
				state.by[bucket] = (state.by[bucket] or 0) + e.tickAmount
			end
		end
	end
end

-- mirrors CombatService.offensiveMultiplier (S85 C3): eliteDamage / bossDamage by variant, vs_<family>,
-- executioner below Combat.lowHpFraction as a share of hits on a dummy, damagePerEnemy (Menace) per living target up
-- to HOOK_RULES.perEnemy.max. control = H1 (FightSim.dps counts only vs_<family>).
local function offensiveMultiplier(state: any, tg: any): number
	local mult = 1
	local m = tg.m
	if not state.control then
		if m.variant == "elite" or m.variant == "elite2" then
			mult += hook(state, "eliteDamage") / 100
		elseif m.variant == "boss" then
			mult += hook(state, "bossDamage") / 100
		end
	end
	if m.family then
		mult += hook(state, Bonuses.familyLine("vs_", m.family)) / 100
	end
	if not state.control then
		local executioner = hook(state, "executioner")
		if executioner > 0 then
			local share = if tg.dummy and A.executeShare == "linear"
				then Combat.lowHpFraction
				else (if tg.hp / tg.maxHp < Combat.lowHpFraction then 1 else 0)
			-- traitExecute (Beheading) is an item trait: S86
			mult += share * Traits.executeBonus(executioner, 0, nil) / 100
		end
		local perEnemy = hook(state, "damagePerEnemy")
		if perEnemy > 0 then
			mult += perEnemy * math.min(#alive(state), PathData.HOOK_RULES.perEnemy.max) / 100
		end
		if hook(state, "furyDamage") > 0 then
			mark(state, "Furia (furyDamage)")
		end
	end
	return mult
end

-- Share of hits on `tg` below `pct` % HP (execute, finisher): a dummy's HP falls linearly (ASSUMPTIONS).
local function belowShare(tg: any, pct: number): number
	if tg.dummy and A.executeShare == "linear" then
		return math.clamp(pct / 100, 0, 1)
	end
	return if tg.hp / tg.maxHp * 100 < pct then 1 else 0
end

export type HitOpts = {
	magic: boolean,
	percent: number, -- % of attack (params.multiplier x 100)
	extra: number?, -- DealOptions.multiplier
	basic: boolean?,
	consumeShot: boolean?,
	forceShare: number?, -- share of hits with forceCrit (execute)
	noProc: boolean?,
	bucket: string?,
	focus: boolean?, -- the selected target (Weak Spot)
	scale: number?, -- expected share of the hit (doubleAttack's second hit)
}

-- mirrors CombatService.DealDamage + Logic/Damage.computeDamage (S85 C3), one expected hit: guaranteedCrit and
-- nextShot taken by every hit with consumeShot ~= false (basic attacks too), Draw a Bead (sighted) crit, the target's
-- strongest vulnerability, Weak Spot stacks, armour break of the enemyArmor category (EffectStack.value), pierce /
-- magicPierce, Damage.reduction, levelGap, crit as expected value (forceCrit: the full multiplier; monsters have no
-- element resistance), skillDmg / basicDmg, offensiveMultiplier; dodge only on basic attacks (Damage.paramsVsMonster);
-- rounding, minDamage and the 0.92-1.08 spread (mean 1) left out. Returns the expected damage.
local function dealDamage(state: any, tg: any, o: HitOpts): number
	if tg.hp <= 0 then
		return 0
	end
	local p = current(state)
	local v = p.values
	local attacker, _ = Damage.fromStats(p.level, v)
	local extra = o.extra or 1
	local force = o.forceShare or 0
	if o.consumeShot ~= false then
		if takeOne(state, "guaranteedCrit") then
			force = 1
		end
		local shot = takeOne(state, "nextShot")
		if shot then
			extra *= 1 + shot.value / 100
		end
	end
	local params: any = { kind = if o.magic then "magic" else "phys", isSkill = not o.basic, basic = o.basic }
	for _, e in effectsOf(tg, "sighted") do
		if e.stats then
			params.critAdd = e.stats.critChance
			params.critDmgAdd = e.stats.critDmg
		end
	end
	local vuln = 0
	for _, e in effectsOf(tg, "vulnerability") do
		vuln = math.max(vuln, e.value)
	end
	extra *= 1 + vuln / 100
	local weak = hook(state, "weakSpot")
	if weak > 0 and not o.noProc and o.focus and not state.control then
		extra *= 1 + state.weakStacks * PathData.HOOK_RULES.weakSpotPerStack / 100
		state.weakStacks = math.min(weak, state.weakStacks + 1)
	end
	local entries = {}
	for _, e in effectsOf(tg, "armorBreak") do
		if e.category == "enemyArmor" then
			table.insert(entries, { category = e.category, value = e.value, at = e.appliedAt, item = false })
		end
	end
	local armorBreak = EffectStack.value(entries, "enemyArmor")
	local defender = MonsterStats.asDefender(tg.m)
	local defense = Damage.defenseOf(params.kind, attacker, defender, armorBreak)
	local gapMul, gapCrit = Damage.levelGap(attacker.level, defender.level)
	local chance = Damage.critChance(attacker, params, gapCrit) / 100
	local critMul = Damage.critMultiplier(attacker.critDmg + (params.critDmgAdd or 0), defender.critResist)
	local critFactor = (1 - force) * (1 + chance * (critMul - 1)) + force * critMul
	local hitShare = if o.basic then 1 - Damage.dodgeChance(defender.dodge or 0, attacker.accuracy or 0) else 1
	local raw = (if o.magic then attacker.magAtk else attacker.physAtk) * o.percent / 100
	raw *= Damage.bonusMul(attacker, params)
	local amount = raw * (1 - Damage.reduction(defense, attacker.level)) * gapMul * critFactor
	-- element resistance: MonsterStats.asDefender gives monsters none (Damage.resMul would be 1)
	amount *= offensiveMultiplier(state, tg) * extra * hitShare * (o.scale or 1)
	tg.hp -= amount
	state.dealt += amount
	local bucket = o.bucket or "basic"
	state.by[bucket] = (state.by[bucket] or 0) + amount
	state.lastCrit = (1 - force) * chance + force
	if amount > 0 then
		local manaOnHit = hook(state, "manaOnHit")
		if manaOnHit > 0 and state.resource == "mana" then
			state.gain(v.maxMana * manaOnHit / 100)
		end
		local lifesteal = math.clamp(v.lifesteal or 0, 0, 15) -- mirrors Damage.computeDamage (cap 15)
		if lifesteal > 0 then
			recordHeal(state, "self", amount * lifesteal / 100)
		end
	end
	return amount
end

-- mirrors CombatService.tryBasicAttack (S85 C2): a swing every 1 / max(0.2, atkSpeed) from t = 0 (the speed of the
-- moment), doubleAttack as the expected second hit (no on-hit effects, nothing left to consume), the weapon element.
-- Swings keep their nominal times (nextBasic += interval, diag SkillEngine), so the step does not round the interval
-- up; AttackPose.hitDelay is left out: with the end-of-window correction it does not change the sum (DECYZJE).
local function basicSwing(state: any)
	local p = current(state)
	local focus = alive(state)[1]
	if not focus then
		return
	end
	local o: HitOpts = {
		magic = p.magic,
		percent = 100,
		basic = true,
		focus = true,
	}
	local amount = dealDamage(state, focus, o)
	local double = hook(state, "doubleAttack")
	if double > 0 then
		local second = table.clone(o)
		second.consumeShot = false
		second.noProc = true
		second.scale = math.clamp(double, 0, 100) / 100
		amount += dealDamage(state, focus, second)
	end
	local interval = 1 / math.max(0.2, p.values.atkSpeed or 1)
	state.lastSwing = { at = state.nextBasic, interval = interval, amount = amount }
	state.nextBasic += interval
end

-- Handlers ----------------------------------------------------------------------------------------------------------

type Ctx = any

-- mirrors Skills/Context ctx.damage (S85 C3): execute (forceCrit share) and finisher on main hits, elemental /
-- holy hooks (PassiveHook), the weapon normalisation (speedMul), areaSkillDamage on area skills (not pulses or plain
-- hits), cdrPerTarget, the weapon element of adaptive skills (Traits.elementPlan), then the on-hit behaviours.
local damage: (ctx: Ctx, tg: any, percent: number, o: { [string]: any }?) -> number

local function elementalMultiplier(ctx: Ctx, holy: boolean?): number
	local mult = 1
	if ctx.element then
		mult += pathHook(ctx.state, "elementDamage") / 100
	end
	if ctx.def.holy or holy then
		mult += pathHook(ctx.state, "holyDamage") / 100
	end
	return mult
end

local function attackOf(ctx: Ctx): number
	local v = current(ctx.state).values
	return (if ctx.magic then v.magAtk or 0 else v.physAtk or 0) * ctx.state.sp.speedMul
end

local function heal(ctx: Ctx, who: string, amount: number, shield: boolean?)
	-- mirrors Skills/Context Context.healFactor: healPower, the heal hooks (healBonus + allyHealBonus on another
	-- player + lowHpHealBonus below SkillData.LOW_HP_HEAL), healCrit as expected value (x HEAL_CRIT_MUL)
	local state = ctx.state
	local v = current(state).values
	local mul = 1 + (v.healPower or 0) / 100
	if not shield then
		local bonus = Skills.healBonusPct({
			healBonus = pathHook(state, "healBonus"),
			allyHealBonus = pathHook(state, "allyHealBonus"),
			lowHpHealBonus = pathHook(state, "lowHpHealBonus"),
		}, who ~= "self", A.healTargetFraction)
		mul *= 1 + bonus / 100
	end
	local chance = Skills.healCritChance(v.critChance or 0, pathHook(state, "healCrit"))
	mul *= 1 + chance * (SkillData.HEAL_CRIT_MUL - 1)
	recordHeal(state, who, amount * mul)
end

local function maxHpOf(state: any, who: string): number
	if who == "tank" and state.heal then
		return state.heal.tank.values.maxHp
	end
	return current(state).values.maxHp
end

local function healAmount(ctx: Ctx, who: string, prefix: "heal" | "shield"): number
	local state = ctx.state
	return Skills.healAmount(
		ctx.def,
		ctx.rank,
		prefix,
		maxHpOf(state, who),
		current(state).values.magAtk or 0,
		state.sp.level
	)
end

-- Allies in reach: solo the caster; heal mode the caster and the tank (other members are not counted, F2).
local function allies(state: any): { string }
	return if state.heal then { "self", "tank" } else { "self" }
end

-- mirrors Skills/Context applyEffect (S85 kinds; S86 kinds go to unmodelled)
local function applyEffect(ctx: Ctx, entity: any, effect: any, scale: number?)
	local state = ctx.state
	local kind = effect.kind
	if kind == "burn" or kind == "carnage" or kind == "arcaneCharge" or kind == "empowered" then
		mark(state, `efekt {kind}`)
		return
	end
	local s = scale or 1
	local duration = Skills.scaled(ctx.def, effect.duration, ctx.rank)
	local raw = if type(effect.value) == "string"
		then Skills.valueAt(ctx.def, effect.value, ctx.rank)
		elseif type(effect.value) == "number" then effect.value
		else 0
	local value = raw * s
	local tickAmount: number? = nil
	if kind == "bleed" or kind == "poison" then
		tickAmount = math.max(1, attackOf(ctx) * value / 100 / math.max(1, duration))
			* (1 + dotBonus(state, kind) / 100)
	elseif kind == "hot" then
		if entity.who == nil then
			return
		end
		if effect.hpPct ~= nil then
			-- S73: hpPct % of the bearer's max HP per second x healFactor (the factor counts in recordHeal at the tick)
			local mul = 1
			local v = current(state).values
			mul *= 1 + (v.healPower or 0) / 100
			local bonus = Skills.healBonusPct({
				healBonus = pathHook(state, "healBonus"),
				allyHealBonus = pathHook(state, "allyHealBonus"),
				lowHpHealBonus = pathHook(state, "lowHpHealBonus"),
			}, entity.who ~= "self", A.healTargetFraction)
			mul *= (1 + bonus / 100) * (1 + Skills.healCritChance(v.critChance or 0, pathHook(state, "healCrit")) * (SkillData.HEAL_CRIT_MUL - 1))
			tickAmount = maxHpOf(state, entity.who) * Skills.resolve(ctx.def, effect.hpPct, ctx.rank) / 100 * mul * s
		else
			tickAmount = maxHpOf(state, entity.who) * value / 100
		end
	end
	local stats: { [string]: number }? = nil
	if effect.stats then
		local resolved: { [string]: number } = {}
		for stat, field in effect.stats do
			if field == ctx.def.furyConsume then
				mark(state, "Furia (furyConsume)")
				resolved[stat] = 0
			else
				resolved[stat] = Skills.valueAt(ctx.def, field, ctx.rank) * s
			end
		end
		stats = resolved
	end
	if
		ctx.element == "ice"
		and state.sp.element == "ice"
		and (kind == "slow" or kind == "freeze")
		and entity.m ~= nil
	then
		mark(state, "Przemarznięcie (frostbite)")
	end
	apply(state, entity, kind, {
		duration = duration,
		value = value,
		tickAmount = tickAmount,
		stats = stats,
		pct = effect.pct,
		maxStacks = if kind == "bleed" then ctx.bp.bleedStacks elseif kind == "poison" then ctx.bp.poisonStacks else nil,
		skillId = ctx.id,
		category = effect.category,
		notBoss = effect.notBoss,
	})
end

-- mirrors Skills/Context applyEffects (dice faces only through the roll: S86)
local function applyEffects(ctx: Ctx, entity: any, side: string)
	for _, effect in ctx.def.effects or {} do
		if Skills.effectSide(ctx.def, effect) == side and not effect.face then
			applyEffect(ctx, entity, effect)
		end
	end
end

-- The self entity (statBuff, nextShot, ...) and the tank entity (heal over time) of heal mode.
local function entityOf(state: any, who: string): any
	return if who == "tank" then state.tank else state.self
end

-- mirrors Skills/Context onHit (S28 / S69 / S71): Divine Wrath heal, lifesteal, healWounded, splash around the
-- main target; knockback and stunNear change nothing on a dummy.
local function onHit(ctx: Ctx, tg: any, percent: number, amount: number, o: { [string]: any })
	local state = ctx.state
	local share = 0
	if ctx.id == "holyStrike" then
		if o.primary then
			share = pathHook(state, "holyStrikeHeal")
		end
	elseif HOLY_HEAL_SKILLS[ctx.id] then
		local strength = pathHook(state, "holyHealAll")
		if strength > 0 then
			share = pathHook(state, "holyStrikeHeal") * strength / 100
		end
	end
	if share > 0 then
		heal(ctx, "self", amount * share / 100)
	end
	if ctx.bp.lifesteal then
		heal(ctx, "self", amount * ctx.bp.lifesteal / 100)
	end
	if ctx.bp.healWounded and o.primary then
		-- the most wounded ally: the tank in heal mode (no wound model, F2), the caster solo
		heal(ctx, if state.heal then "tank" else "self", amount * ctx.bp.healWounded / 100)
	end
	local splash = ctx.bp.splash
	if splash and o.primary then
		for _, other in alive(state) do
			if other ~= tg then
				damage(ctx, other, percent * splash.pct / 100, { plain = true, consumeShot = false, secondary = true })
			end
		end
	end
end

damage = function(ctx: Ctx, tg: any, percent: number, options: { [string]: any }?): number
	if tg.hp <= 0 then
		return 0
	end
	local state = ctx.state
	local o: { [string]: any } = options or {}
	local def, bp = ctx.def, ctx.bp
	local pct = percent
	local force = 0
	if bp.execute and not o.plain then
		force = belowShare(tg, bp.execute)
	end
	local finisher: any = def.finisher
	if finisher and finisher.hp and finisher.mul and not o.plain then
		pct *= 1 + belowShare(tg, finisher.hp) * (finisher.mul - 1)
	end
	local multiplier = elementalMultiplier(ctx, o.holy) * state.sp.speedMul
	if Traits.isAreaSkill(def.type) and not (o.plain or o.lingering) then
		multiplier *= 1 + hook(state, "areaSkillDamage") / 100
	end
	local amount = dealDamage(state, tg, {
		magic = ctx.magic,
		percent = pct,
		extra = multiplier,
		consumeShot = o.consumeShot ~= false,
		forceShare = force,
		noProc = o.plain == true or o.noAdaptive == true or o.noProc == true or o.secondary == true,
		bucket = ctx.id,
		focus = tg == alive(state)[1],
	})
	local cdr = bp.cdrPerTarget
	if cdr and not o.lingering and not ctx.struck[tg] and ctx.struckCount < cdr.max then
		ctx.struck[tg] = true
		ctx.struckCount += 1
		state.cd[ctx.id] = (state.cd[ctx.id] or 0) - cdr.sec
	end
	if def.adaptive and amount > 0 and not o.noAdaptive then
		-- mirrors Skills/Elements.apply with Data/Skills.ADAPTIVE (Context ADAPTIVE_SPEC)
		local spec: any = {
			burnPct = SkillData.ADAPTIVE.burnPct,
			burnDuration = SkillData.ADAPTIVE.burnDuration,
			slowPct = SkillData.ADAPTIVE.slowPct,
			slowDuration = SkillData.ADAPTIVE.slowDuration,
			arcPct = SkillData.ADAPTIVE.arcPct,
			arcRadius = SkillData.ADAPTIVE.arcRadius,
			exactTicks = SkillData.ADAPTIVE.exactTicks,
		}
		local rider = hook(state, "elementRider")
		local plan = Traits.elementPlan(
			ctx.element,
			spec,
			amount,
			rider,
			dotBonus(state, "burn"),
			hook(state, "riderSameTarget") > 0
		)
		if plan and plan.kind == "burn" then
			-- the server refreshes with accumulate (S79): counted as a plain refresh, the rest is S86
			mark(state, "accumulate (podpalenie)")
			apply(
				state,
				tg,
				"burn",
				{ duration = plan.duration, value = plan.pct, tickAmount = plan.tick, skillId = ctx.id }
			)
		elseif plan and plan.kind == "slow" then
			mark(state, "Przemarznięcie (frostbite)")
		elseif plan and plan.kind == "arc" then
			local other: any = nil
			for _, x in alive(state) do
				if x ~= tg then
					other = x
					break
				end
			end
			if other then
				damage(
					ctx,
					other,
					percent * plan.pct / 100,
					{ noAdaptive = true, consumeShot = false, secondary = true }
				)
			elseif plan.sameTarget > 0 then
				damage(
					ctx,
					tg,
					percent * plan.sameTarget / 100,
					{ noAdaptive = true, consumeShot = false, secondary = true }
				)
			end
		end
	end
	if amount > 0 and not o.plain then
		onHit(ctx, tg, percent, amount, o)
	end
	local critCdr = bp.critCdr
	if critCdr and not o.plain and not ctx.critCdrUsed and ctx.cooldown > 0 then
		-- the first crit of the cast: expected share of the cooldown (the chance of this hit)
		ctx.critCdrUsed = true
		state.cd[ctx.id] = (state.cd[ctx.id] or 0) - ctx.cooldown * critCdr / 100 * (state.lastCrit or 0)
	end
	return amount
end

-- mirrors Types/Offense hitAll: the enemy effects only with `withEffects`.
local function hitAll(ctx: Ctx, list: { any }, percent: number, withEffects: boolean, o: { [string]: any }?)
	for _, tg in list do
		local amount = damage(ctx, tg, percent, o)
		if withEffects and amount > 0 then
			applyEffects(ctx, tg, "enemy")
		end
	end
end

-- mirrors Skills/Context lingering + startZone: zones of the first wave (Skills.castZones with areaLingering),
-- floor(duration) pulses a second on every dummy as plain zone ticks; an element zone x Elements.power, a poison zone
-- x the Hunter's poison bonus.
local function lingering(ctx: Ctx, percent: number, wave: number, inCircle: number)
	local state = ctx.state
	for _, zone in Skills.castZones(ctx.def, ctx.bp, wave, percent, hook(state, "areaLingering"), inCircle) do
		local pulse = zone.pct
		if zone.element then
			pulse *= 1 + math.max(0, hook(state, "elementRider")) / 100
		elseif zone.kind == "poison" then
			pulse *= 1 + dotBonus(state, "poison") / 100
		end
		for second = 1, math.floor(zone.duration) do
			schedule(state, state.t + second, function()
				for _, tg in alive(state) do
					damage(ctx, tg, pulse, {
						plain = true,
						consumeShot = false,
						lingering = true,
						noAdaptive = if zone.element then true else nil,
					})
				end
			end)
		end
	end
end

local function at(ctx: Ctx, delay: number, fn: () -> ())
	if delay <= EPS then
		fn()
	else
		schedule(ctx.state, ctx.state.t + delay, fn)
	end
end

-- Handlers by type (SkillService HANDLERS). Each returns false when it refuses (nothing spent).
SkillModel.HANDLERS = {} :: { [string]: (ctx: Ctx) -> boolean }
local H = SkillModel.HANDLERS

-- mirrors Types/Offense.target (furyConsume: Fury is S86; stunSplash on a stunned target, S71)
H.target = function(ctx)
	local tg = alive(ctx.state)[1]
	if not tg then
		return false
	end
	if ctx.def.furyConsume then
		mark(ctx.state, "Furia (furyConsume)")
	end
	local percent = Skills.valueAt(ctx.def, "dmg", ctx.rank)
	local amount = damage(ctx, tg, percent, { primary = true })
	if amount > 0 then
		applyEffects(ctx, tg, "enemy")
		if ctx.bp.stunSplash and #effectsOf(tg, "stun") > 0 then
			local splash = percent * Skills.valueAt(ctx.def, "stunSplash", ctx.rank) / 100
			for _, other in alive(ctx.state) do
				if other ~= tg then
					damage(ctx, other, splash, { plain = true, consumeShot = false })
				end
			end
		end
	end
	return true
end

-- mirrors Types/Offense.projectile: `hits` shots every `interval` (0.15), only the first consumes and pierces,
-- every shot that lands applies the effects, Storm Arrow's splash (values.splash) around the target.
H.projectile = function(ctx)
	local state = ctx.state
	local tg = alive(state)[1]
	if not tg then
		return false
	end
	local hits = ctx.def.hits or 1
	local interval = ctx.def.interval or 0.15
	for shot = 1, hits do
		at(ctx, (shot - 1) * interval, function()
			if tg.hp <= 0 then
				return
			end
			local percent = Skills.valueAt(ctx.def, "dmg", ctx.rank)
			local amount = damage(ctx, tg, percent, { consumeShot = shot == 1, primary = shot == 1 })
			if amount > 0 then
				applyEffects(ctx, tg, "enemy")
			end
			local share = ctx.bp.pierce
			if shot == 1 and share then
				local list = alive(state)
				local nextOne = list[2]
				if nextOne and nextOne ~= tg then
					damage(
						ctx,
						nextOne,
						percent * share / 100,
						{ consumeShot = false, noProc = true, secondary = true }
					)
				end
			end
			if ctx.def.values.splash and ctx.def.radius then
				local others = {}
				for _, x in alive(state) do
					if x ~= tg then
						table.insert(others, x)
					end
				end
				hitAll(ctx, others, Skills.valueAt(ctx.def, "splash", ctx.rank), false, { secondary = true })
			end
		end)
	end
	return true
end

-- mirrors Types/Offense.cone (a volley: N arrows over the enemies every 0.06 s; effects from the first arrow on each)
H.cone = function(ctx)
	local state = ctx.state
	local enemies = alive(state)
	local hits = ctx.def.hits
	if hits and #enemies > 0 then
		for i = 1, hits do
			local tg = enemies[(i - 1) % #enemies + 1]
			schedule(state, state.t + i * 0.06, function()
				local amount = damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank), { consumeShot = i == 1 })
				if amount > 0 and i <= #enemies then
					applyEffects(ctx, tg, "enemy")
				end
			end)
		end
	else
		hitAll(ctx, enemies, Skills.valueAt(ctx.def, "dmg", ctx.rank), true)
	end
	return true
end

-- mirrors Types/Offense.circleSelf: waves every `interval` (0.4), effects from the first, Radiance heals allies,
-- the zones, the echo wave; the caster's own effects (Taunt's armour). shieldPerHit is S86.
H.circleSelf = function(ctx)
	local state = ctx.state
	local def = ctx.def
	local hasDamage = def.values.dmg ~= nil
	local hits = def.hits or 1
	local interval = def.interval or 0.4
	if ctx.bp.shieldPerHit then
		mark(state, "zachowanie shieldPerHit")
	end
	local function wave(n: number, percent: number)
		local enemies = alive(state)
		if hasDamage then
			hitAll(ctx, enemies, percent, n == 1)
		elseif n == 1 then
			for _, tg in enemies do
				applyEffects(ctx, tg, "enemy")
			end
		end
		if n == 1 and def.values.heal and hasDamage then
			local amount = attackOf(ctx)
				* Skills.valueAt(def, "dmg", ctx.rank)
				/ 100
				* Skills.valueAt(def, "heal", ctx.rank)
				/ 100
				* Skills.healMul(state.sp.level)
			for _, who in allies(state) do
				heal(ctx, who, amount)
			end
		end
		if hasDamage then
			lingering(ctx, percent, n, 0)
		end
	end
	local dmg = if hasDamage then Skills.valueAt(def, "dmg", ctx.rank) else 0
	for n = 1, hits do
		at(ctx, (n - 1) * interval, function()
			wave(n, dmg)
		end)
	end
	local echo = ctx.bp.echo
	if echo and hasDamage then
		at(ctx, (hits - 1) * interval + echo.delay, function()
			wave(hits + 1, dmg * echo.pct / 100)
		end)
	end
	applyEffects(ctx, state.self, "self")
	return true
end

-- mirrors Types/Offense.circleTarget (S85 C5): share of a meteor storm's impacts that hit a dummy at the aim point;
-- a storm (hits > 1 and delay > 0) strikes circles of max(4, r / 3) at a distance uniform in [0, r - r_i] from the
-- point; enemiesInCircle's tolerance 1.5. 1 for every other circle.
function SkillModel.stormShare(def: any): number
	local radius = def.radius or 8
	local hits = def.hits or 1
	if not (hits > 1 and (def.delay or 0) > 0) then
		return 1
	end
	local impactRadius = math.max(4, radius / 3)
	return math.min(1, (impactRadius + CIRCLE_TOLERANCE) / math.max(0.01, radius - impactRadius))
end

-- mirrors Types/Offense.circleTarget: `delay`, waves every `interval` (0.5), firstWave, a meteor storm's impacts
-- (radius max(4, r / 3), share of hits min(1, (r_i + 1.5) / (r - r_i)) on dummies at the aim point), Thunderstorm's
-- bolt (one random enemy: 1 / n each), effects from the first wave, the zones, the split blasts (3.5 studs, at
-- split.radius from the point) and the echo. Orb flight and the pull wait are left out (dummies in reach).
H.circleTarget = function(ctx)
	local state = ctx.state
	local def = ctx.def
	if def.values.dmg == nil then
		return true
	end
	local hits = def.hits or 1
	local interval = def.interval or 0.5
	local delay = def.delay or 0
	local stormShare = SkillModel.stormShare(def)
	local dmg = Skills.valueAt(def, "dmg", ctx.rank)
	local firstPercent = dmg * (1 + (ctx.bp.firstWave or 0) / 100)
	for w = 1, hits do
		at(ctx, delay + (w - 1) * interval, function()
			local enemies = alive(state)
			local percent = if w == 1 then firstPercent else dmg
			if def.randomTarget then
				local n = #enemies
				if n > 0 then
					hitAll(ctx, enemies, percent / n, true)
				end
				lingering(ctx, dmg, w, n)
				return
			end
			hitAll(ctx, enemies, percent * stormShare, w == 1)
			lingering(ctx, dmg, w, 0)
			local split = ctx.bp.split
			if w == 1 and split then
				local reach = SPLIT_RADIUS + CIRCLE_TOLERANCE
				local hitsDummies = split.radius - A.dummySpread <= reach
				for i = 1, split.count do
					at(ctx, 0.15 + i * 0.08, function()
						if hitsDummies then
							hitAll(ctx, alive(state), dmg * split.pct / 100, false, { secondary = true })
						end
					end)
				end
			end
		end)
	end
	local echo = ctx.bp.echo
	if echo then
		at(ctx, delay + (hits - 1) * interval + echo.delay, function()
			hitAll(ctx, alive(state), dmg * echo.pct / 100, false)
		end)
	end
	return true
end

-- mirrors Types/Offense.line (with a duration: floor(duration / interval) hits without effects)
H.line = function(ctx)
	local state = ctx.state
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	local dmg = Skills.valueAt(ctx.def, "dmg", ctx.rank)
	if duration > 0 then
		local interval = ctx.def.interval or 0.5
		for i = 1, math.floor(duration / interval) do
			schedule(state, state.t + i * interval, function()
				hitAll(ctx, alive(state), dmg, false)
			end)
		end
	else
		hitAll(ctx, alive(state), dmg, true)
	end
	return true
end

-- mirrors Types/Offense.chain: the path first (Logic/Chain.path; dummies at one point: index order), -10 % a jump
H.chain = function(ctx)
	local state = ctx.state
	local list = alive(state)
	if #list == 0 then
		return false
	end
	local jumps = math.floor(Skills.valueAt(ctx.def, "jumps", ctx.rank) + 0.5)
	local points = {}
	for _ = 1, #list do
		table.insert(points, { x = 0, z = A.dummySpread })
	end
	local order = Chain.path(points, 1, (ctx.def.radius or 12) + CIRCLE_TOLERANCE, jumps)
	local percent = Skills.valueAt(ctx.def, "dmg", ctx.rank)
	for i, index in order do
		local tg = list[index]
		local amount = damage(ctx, tg, percent * (1 - 0.1 * (i - 1)), { consumeShot = i == 1, primary = i == 1 })
		if amount > 0 then
			applyEffects(ctx, tg, "enemy")
		end
	end
	return true
end

-- mirrors Types/Movement.charge (the blow 0.15 s after the leap)
H.charge = function(ctx)
	local state = ctx.state
	local tg = alive(state)[1]
	if not tg then
		return false
	end
	schedule(state, state.t + 0.15, function()
		local amount = damage(ctx, tg, Skills.valueAt(ctx.def, "dmg", ctx.rank), { primary = true })
		if amount > 0 then
			applyEffects(ctx, tg, "enemy")
		end
	end)
	return true
end

-- mirrors Types/Movement.blink: the caster's effects (Disengage's next shot); the breakpoint trap only slows
H.blink = function(ctx)
	applyEffects(ctx, ctx.state.self, "self")
	return true
end

-- Types/Movement.trap in its 05b859d shape (C5): the skill's enemy effects on every dummy after one TRAP_CHECK
-- (0.25 s). Its damage, rings, pull, echo and trapEnergy (S76-S78) are S86.
H.trap = function(ctx)
	local state = ctx.state
	if ctx.def.values.dmg ~= nil or (ctx.def.hits or 1) > 1 or ctx.bp.echo then
		mark(state, "pułapki S76–S78 (obrażenia, pierścień, echo, energia)")
	end
	schedule(state, state.t + 0.25, function()
		for _, tg in alive(state) do
			for _, effect in ctx.def.effects or {} do
				if Skills.effectSide(ctx.def, effect) == "enemy" and not effect.face then
					applyEffect(ctx, tg, effect)
				end
			end
		end
	end)
	return true
end

-- mirrors Types/Support.buff: Fury first (S86), the caster's own effects, the party copies on the caster (solo
-- allyPass: effects on "allies" and allyEffects); allyHeal / allyShield / behindEffect are S86.
H.buff = function(ctx)
	local state = ctx.state
	if ctx.def.furyConsume then
		mark(state, "Furia (furyConsume)")
	end
	applyEffects(ctx, state.self, "self")
	if Skills.hasAllyPass(ctx.def, ctx.bp) then
		applyEffects(ctx, state.self, "allies")
		for _, effect in ctx.def.allyEffects or {} do
			applyEffect(ctx, state.self, effect)
		end
	end
	if ctx.bp.behindEffect then
		mark(state, "zachowanie behindEffect")
	end
	return true
end

-- mirrors Types/Support.debuff: enemy effects on the target and, with a radius, on every other dummy
H.debuff = function(ctx)
	local state = ctx.state
	local list = alive(state)
	local tg = list[1]
	if not tg then
		return false
	end
	applyEffects(ctx, tg, "enemy")
	if (ctx.def.radius or 0) > 0 then
		for _, other in list do
			if other ~= tg then
				applyEffects(ctx, other, "enemy")
			end
		end
	end
	if ctx.id == "huntersMark" and pathHook(state, "royalFalcon") > 0 then
		mark(state, "Sokół (nurkowanie)")
	end
	return true
end

-- The ally a heal helps (Support allyTarget): heal mode: entries with target "tank" / "mostWounded" or without a
-- target heal the tank (F2); solo the caster.
local function healTarget(ctx: Ctx): string
	local state = ctx.state
	if not state.heal then
		return "self"
	end
	local target = ctx.entry.target
	if target == "self" then
		return "self"
	end
	return "tank"
end

-- mirrors Types/Support.heal (healOne; overheal and second targets need the HP axis and other members: F2), the
-- Purify 5B burst on every dummy (in reach); chainHeal is S86.
H.heal = function(ctx)
	local state = ctx.state
	local who = healTarget(ctx)
	heal(ctx, who, healAmount(ctx, who, "heal"))
	local burst = ctx.bp.burst
	if burst then
		for _, tg in alive(state) do
			damage(ctx, tg, burst.pct, { plain = true, consumeShot = false, holy = true })
		end
	end
	if ctx.bp.chainHeal then
		mark(state, "zachowanie chainHeal")
	end
	return true
end

-- mirrors Types/Support.hot: the sum at the cast x healFactor over the ticks of a "hot" effect
H.hot = function(ctx)
	local state = ctx.state
	local who = healTarget(ctx)
	local duration = Skills.scaled(ctx.def, ctx.def.duration, ctx.rank)
	local entity = entityOf(state, who)
	-- the factor is taken at the tick by recordHeal's caller: fold it into the sum here (one roll per cast)
	local v = current(state).values
	local bonus = Skills.healBonusPct({
		healBonus = pathHook(state, "healBonus"),
		allyHealBonus = pathHook(state, "allyHealBonus"),
		lowHpHealBonus = pathHook(state, "lowHpHealBonus"),
	}, who ~= "self", A.healTargetFraction)
	local mul = (1 + (v.healPower or 0) / 100)
		* (1 + bonus / 100)
		* (1 + Skills.healCritChance(v.critChance or 0, pathHook(state, "healCrit")) * (SkillData.HEAL_CRIT_MUL - 1))
	local total = healAmount(ctx, who, "heal") * mul
	apply(state, entity, "hot", {
		duration = duration,
		tickAmount = total / math.max(1, duration),
		skillId = ctx.id,
	})
	return true
end

-- mirrors Types/Support.shield: a shield counted by its amount (absorption is S86) x healFactor (shield)
H.shield = function(ctx)
	local who = healTarget(ctx)
	heal(ctx, who, healAmount(ctx, who, "shield"), true)
	if ctx.bp.shieldBurst then
		mark(ctx.state, "zachowanie shieldBurst")
	end
	return true
end

-- mirrors Types/Support.groupHeal: every ally in reach heals their own amount (F2: the tank's part counts);
-- healZone (Circle of Light 10B) is S86.
H.groupHeal = function(ctx)
	for _, who in allies(ctx.state) do
		heal(ctx, who, healAmount(ctx, who, "heal"))
	end
	if ctx.bp.healZone then
		mark(ctx.state, "zachowanie healZone")
	end
	return true
end

-- mirrors Types/Support.groupBuff: the party copies on the caster (solo), the own effects, Divine Intervention's
-- % max HP heal; the dice (roll) are S86.
H.groupBuff = function(ctx)
	local state = ctx.state
	applyEffects(ctx, state.self, "allies")
	for _, effect in ctx.def.allyEffects or {} do
		applyEffect(ctx, state.self, effect)
	end
	applyEffects(ctx, state.self, "self")
	if ctx.def.roll then
		mark(state, "kości (roll)")
	end
	if ctx.id == "divineIntervention" then
		for _, who in allies(state) do
			heal(ctx, who, maxHpOf(state, who) * Skills.valueAt(ctx.def, "heal", ctx.rank) / 100)
		end
	end
	return true
end

-- Without a dead ally the server refuses Resurrection (nothing spent): never cast on a dummy.
H.resurrect = function(_ctx)
	return false
end

-- S86 adds guard, shout, banner, companion, beam and healZone here (C7).
local S86_TYPES: { [string]: boolean } =
	{ guard = true, shout = true, banner = true, companion = true, beam = true, healZone = true }

-- Behaviour keys the model knows (C6): counted here or without effect on a dummy. Any other key goes to unmodelled.
SkillModel.BEHAVIOURS = {
	splash = true,
	pierce = true,
	lingering = true,
	echo = true,
	split = true,
	execute = true,
	bleedStacks = true,
	poisonStacks = true,
	lifesteal = true,
	secondTarget = true,
	overhealShield = true,
	selfHeal = true,
	healWounded = true,
	burst = true,
	stunSplash = true,
	cdrPerTarget = true,
	critCdr = true,
	firstWave = true,
	cleanse = true,
	-- no effect on a dummy
	pull = true,
	knockback = true,
	castMove = true,
	stunNear = true,
	stunLast = true,
	trap = true,
	poisonSpread = true,
	markJump = true,
	extendOnKill = true,
	steadfast = true,
	channelMove = true,
	tauntNear = true,
} :: { [string]: boolean }

-- Rotation ----------------------------------------------------------------------------------------------------------

-- S85 (D2): conditions of a rotation entry on the dummies and the player. Returns true, false, or a string: the
-- reason of an entry the model has no state for (S86: Fury, charges, the party, red zones).
local function condition(state: any, entry: { [string]: any }): boolean | string
	for key, value in entry do
		if key == "skill" then
			continue
		elseif key == "target" then
			if value == "tank" or value == "mostWounded" then
				if not state.heal then
					return false
				end
			elseif value == "meleeAllies" or value == "allyInZone" then
				return `warunek target = {value}: S86`
			end
		elseif key == "minEnemies" then
			if #alive(state) < value then
				return false
			end
		elseif key == "minWounded" then
			-- heal mode: every member is wounded (no HP axis, S86); solo: nobody
			if not state.heal or state.heal.team < value then
				return false
			end
		elseif key == "elite" then
			local focus = alive(state)[1]
			local variant = if focus then focus.m.variant else "normal"
			if value and not (variant == "elite" or variant == "elite2" or variant == "boss") then
				return false
			end
		elseif key == "debuff" then
			local who = if entry.target == "self" then state.self else alive(state)[1]
			if not who or #effectsOf(who, value) == 0 then
				return false
			end
		elseif key == "opener" then
			if value and state.casts[entry.skill] then
				return false
			end
		elseif key == "belowHp" then
			-- the player is at full HP on a dummy, and heal mode has no HP axis (S86)
			return false
		elseif key == "minManaPct" or key == "maxManaPct" then
			local share = if state.poolMax > 0 then state.pool / state.poolMax * 100 else 0
			if key == "minManaPct" and share < value then
				return false
			elseif key == "maxManaPct" and share > value then
				return false
			end
		elseif key == "notInZone" then
			continue -- no red zones on a dummy
		elseif key == "beforeRedZone" then
			return false -- no boss schedule in the model
		elseif key == "minFury" or key == "minCharges" then
			return `warunek {key}: S86`
		else
			return `warunek {key}: S86`
		end
	end
	return true
end

-- A prepared rotation entry: the effective skill, its rank, cost (Skills.cost) and cooldown (Skills.cooldown), or why
-- it is never cast.
local function prepare(state: any, entry: { [string]: any }): any
	local sp = state.sp
	local id = entry.skill
	local base = SkillData.get(id)
	local out: any = { entry = entry, id = id }
	if not base or base.class ~= sp.classId then
		out.never = "spoza klasy"
		return out
	end
	local rank = Paths.skillRank(sp.character, id)
	if rank <= 0 or base.type == "passive" then
		out.off = true -- no rank yet (not listed)
		return out
	end
	if not Paths.skillUsable(sp.character, id, sp.weapons) then
		out.off = true
		return out
	end
	local def, bp = Paths.effectiveFor(sp.character, id, sp.weapons, rank)
	if not Skills.elementAllowed(def, sp.element) then
		out.off = true
		return out
	end
	out.rank, out.def, out.bp = rank, def, bp
	local p = state.p
	-- mirrors SkillService.cast: CostMods = { costReduce, hooks = PassiveHook table, charges } (charges S86 = 0)
	out.cost = Skills.cost(def, rank, sp.level, sp.classId, {
		costReduce = p.values.costReduce or 0,
		hooks = sp.pathHooks,
		charges = 0,
	})
	out.cooldown = Skills.cooldown(def, rank, Skills.cooldownReduction(p.hooks.cooldownReduction or 0), bp)
	if S86_TYPES[def.type] then
		out.never = `typ {def.type}: S86`
	elseif (def.castTime or 0) > 0 then
		out.never = "castTime: S86"
	elseif def.type == "resurrect" then
		out.never = "bez martwego sojusznika"
	elseif def.type ~= "channel" and not SkillModel.HANDLERS[def.type] then
		-- a channel has no handler: SkillService.cast runs it (cast below)
		out.never = `typ {def.type}: nieznany`
	end
	for key in bp do
		if not SkillModel.BEHAVIOURS[key] then
			mark(state, `zachowanie {key}`)
		end
	end
	return out
end

local function skip(state: any, item: any, reason: string)
	if state.t + EPS < (item.virtualReady or 0) then
		return
	end
	item.virtualReady = state.t + (item.cooldown or 1)
	local s = state.skipped[item.id]
	if not s then
		s = { reason = reason, count = 0 }
		state.skipped[item.id] = s
	end
	s.count += 1
end

-- mirrors SkillService.finished: selfEffects, selfHeal, zealCdr (Ardor); extendOnKill needs kills; charges and Full
-- Draw are S86.
local function finished(ctx: Ctx)
	local state = ctx.state
	for _, effect in ctx.def.selfEffects or {} do
		applyEffect(ctx, state.self, effect)
	end
	if ctx.bp.selfHeal then
		heal(ctx, "self", current(state).values.maxHp * ctx.bp.selfHeal / 100)
	end
	local zeal = if Skills.offensive(ctx.def) then pathHook(state, "zealCdr") else 0
	if zeal > 0 then
		for _, id in ZEAL_SKILLS do
			local ready = state.cd[id]
			if ready and ready > state.t then
				state.cd[id] = math.max(state.t, ready - zeal)
			end
		end
	end
end

-- mirrors SkillService.cast (S85 C1, D1, E1): the cost (Skills.cost) at the cast, GCD and cooldown at the cast,
-- a channel stands its duration (the model casts nothing meanwhile; basic attacks go on) and gives the mana back at
-- its end, other types land after SkillMotions.hitDelay (none for INSTANT types).
local function cast(state: any, item: any): boolean
	local def = item.def
	local ctx: Ctx = {
		state = state,
		entry = item.entry,
		id = item.id,
		def = def,
		bp = item.bp,
		rank = item.rank,
		magic = def.damageKind == "magic",
		element = if def.adaptive then state.sp.element else def.element,
		cooldown = item.cooldown,
		struck = {},
		struckCount = 0,
		critCdrUsed = false,
	}
	state.spent += item.cost
	if not state.unlimited then
		state.pool -= item.cost
	end
	state.gcd = state.t + SkillData.GCD
	state.cd[item.id] = state.t + item.cooldown
	state.casts[item.id] = (state.casts[item.id] or 0) + 1
	if #state.firstCasts < 12 then
		table.insert(state.firstCasts, item.id)
	end
	if def.type == "channel" then
		local duration = Skills.scaled(def, def.duration, item.rank)
		state.channelUntil = state.t + duration
		finished(ctx)
		if item.bp.roll or item.bp.grantCharges or item.bp.empower then
			mark(state, "kanał: kości / Ładunki / Wzmocnienie")
		end
		schedule(state, state.t + duration, function()
			-- mirrors SkillService.completeChannel (mana back; Prayer's party share needs the party)
			state.gain(current(state).values.maxMana * Skills.valueAt(def, "mana", item.rank) / 100)
		end)
		return true
	end
	local handler = SkillModel.HANDLERS[def.type]
	local delay = if INSTANT[def.type] then 0 else SkillMotions.hitDelay(item.id)
	local function run()
		if handler(ctx) then
			finished(ctx)
		end
	end
	if delay <= EPS then
		run()
	else
		schedule(state, state.t + delay, run)
	end
	return true
end

-- mirrors PotionService: the biggest allowed quality (Balance.potionHps rule) every Potions.interval(L), drunk when
-- the pool has room for it or a ready cast lacks the resource (DECYZJE).
local function potionAmount(resource: string, level: number): number
	local best = 0
	for q = 1, 5 do
		local def: any = Items.get(`potion_{resource}_{q}`)
		if def and (def.level or 1) <= level then
			best = math.max(best, def.use.amount)
		end
	end
	return best
end

-- S85 (C1): the fight. Steps of ASSUMPTIONS.dt over [0, seconds): events due, effect ticks, the basic swing, potions,
-- the rotation, regeneration. Without real HP the window ends at `seconds` and the last swing counts only its part
-- inside the window (C2: 60 s at speed 1.2 = 72 swings).
function SkillModel.fight(sp: any, opts: FightOpts?): FightResult
	local o: FightOpts = opts or {}
	local T = o.seconds or A.sustainedSeconds
	local dummy = o.dummy ~= false
	local monsters = o.targets or { B.monster(B.GENERIC, sp.level) }
	local state: any = {
		sp = sp,
		p = sp.p,
		selfDirty = true,
		t = 0,
		seq = 0,
		events = {},
		targets = {},
		self = { effects = {}, who = "self" },
		tank = { effects = {}, who = "tank" },
		dealt = 0,
		by = {},
		casts = {},
		firstCasts = {},
		cd = {},
		gcd = 0,
		spent = 0,
		healTo = {},
		skipped = {},
		unmodelled = {},
		weakStacks = 0,
		nextBasic = 0,
		dummy = dummy,
		control = o.control == true,
		unlimited = o.unlimited == true,
		heal = o.heal,
		resource = sp.resource,
		potions = 0,
	}
	for i, m in monsters do
		table.insert(state.targets, {
			id = `t{i}`,
			m = m,
			hp = if dummy then A.dummyHp else m.maxHp,
			maxHp = if dummy then A.dummyHp else m.maxHp,
			dummy = dummy,
			effects = {},
		})
	end
	local p0 = current(state)
	state.poolMax = if sp.resource == "mana" then p0.values.maxMana else p0.values.maxEnergy
	state.pool = state.poolMax * (o.startPool or 1)
	state.gain = function(amount: number)
		state.pool = math.min(state.poolMax, state.pool + amount)
	end
	local regen = if sp.resource == "mana" then p0.values.manaRegen or 0 else p0.values.energyRegen or 0
	state.regen = regen
	local items: { any } = {}
	if o.skills ~= false then
		for _, entry in sp.build.rotation do
			local item = prepare(state, entry)
			if not item.off then
				table.insert(items, item)
			end
		end
	end
	local potionAmountNow = if o.potions then potionAmount(sp.resource, sp.level) else 0
	local potionEvery = Potions.interval(sp.level)
	local nextPotion = 0
	local steps = math.floor(T / A.dt + 0.5)
	local ended = T
	for step = 0, steps - 1 do
		local t = step * A.dt
		state.t = t
		local events = state.events
		while #events > 0 and events[1].t <= t + EPS do
			local ev = table.remove(events, 1)
			ev.fn()
		end
		for _, tg in state.targets do
			tickEntity(state, tg)
		end
		tickEntity(state, state.self)
		tickEntity(state, state.tank)
		if not dummy and #alive(state) == 0 then
			ended = t
			break
		end
		if t + EPS >= state.nextBasic then
			basicSwing(state)
		end
		local blocked = false
		local channeling = state.channelUntil ~= nil and t + EPS < state.channelUntil
		if #items > 0 and not channeling and t + EPS >= state.gcd then
			for _, item in items do
				if t + EPS < (state.cd[item.id] or 0) then
					continue
				end
				if item.never then
					skip(state, item, item.never)
					continue
				end
				local ok = condition(state, item.entry)
				if type(ok) == "string" then
					skip(state, item, ok)
					continue
				elseif not ok then
					continue
				end
				if not state.unlimited and state.pool + EPS < item.cost then
					blocked = true -- a ready cast lacks the resource (the potion rule)
					continue
				end
				cast(state, item)
				break
			end
		end
		if o.potions and t + EPS >= nextPotion and potionAmountNow > 0 then
			if state.pool <= state.poolMax - potionAmountNow or blocked then
				state.gain(potionAmountNow)
				state.potions += 1
				nextPotion = t + potionEvery
			end
		end
		local p = current(state)
		local r = if sp.resource == "mana" then p.values.manaRegen or 0 else p.values.energyRegen or 0
		state.gain(r * A.dt)
	end
	-- C2: only the part of the swings inside the window counts: the last swing loses the part past T, a swing due
	-- before T that the last step did not reach counts its part inside (as the last swing's amount)
	local last = state.lastSwing
	if dummy and last then
		local inside = math.min(1, (T - last.at) / last.interval)
		local fix = (inside - 1) * last.amount
		if state.nextBasic < T - EPS then
			fix += (T - state.nextBasic) / last.interval * last.amount
		end
		state.dealt += fix
		state.by.basic = (state.by.basic or 0) + fix
	end
	local unmodelled: { string } = {}
	for text in state.unmodelled do
		table.insert(unmodelled, text)
	end
	for _, text in staticUnmodelled(sp) do
		if not state.unmodelled[text] then
			table.insert(unmodelled, text)
		end
	end
	for _, item in items do
		if item.never and not table.find(unmodelled, item.never) and string.find(item.never, "S86") then
			table.insert(unmodelled, item.never)
		end
	end
	table.sort(unmodelled)
	return {
		seconds = ended,
		dealt = state.dealt,
		dps = state.dealt / math.max(A.dt, ended),
		by = state.by,
		casts = state.casts,
		spent = state.spent,
		poolMax = state.poolMax,
		poolEnd = state.pool,
		regen = regen,
		potions = state.potions,
		healTo = state.healTo,
		skipped = state.skipped,
		unmodelled = unmodelled,
		firstCasts = state.firstCasts,
	}
end

-- Metrics -----------------------------------------------------------------------------------------------------------

export type Metrics = {
	basic: number,
	onCooldown: number,
	demand: number, -- resource per second on cooldown
	burst8: number,
	sustained60: number,
	sustained60p: number,
	potionsPerMinute: number,
	aoe3burst: number,
	aoe3sus: number,
	tsk1: number,
	tsk2: number,
	tsk3: number,
	tsk1rel: number,
	tsk2rel: number,
	tsk4: number, -- demand on cooldown / regeneration (Mage T-SK4, Cleric report)
	pool: number,
	regen: number,
	spent: number,
	free: number,
	unmodelled: { string },
	skipped: { [string]: { reason: string, count: number } },
	offRotation: { string },
	shares: { [string]: number }, -- damage share of sustained60
	byElement: { [string]: Metrics }?,
}

local metricsCache: { [string]: Metrics } = {}

local function rawMetrics(build: Build, L: number, element: string?): Metrics
	local sp = SkillModel.player(build, L, { element = element })
	local one = { B.monster(B.GENERIC, L) }
	local three = {}
	for _ = 1, A.areaTargets do
		table.insert(three, B.monster(B.GENERIC, L))
	end
	local basic = SkillModel.fight(sp, { skills = false, targets = one })
	local cooldown = SkillModel.fight(sp, { unlimited = true, targets = one })
	local burst = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = one })
	local sustained = SkillModel.fight(sp, { targets = one })
	local withPotions = SkillModel.fight(sp, { targets = one, potions = true })
	local aoeBurst = SkillModel.fight(sp, { seconds = A.burstSeconds, targets = three })
	local aoeSus = SkillModel.fight(sp, { targets = three })
	local unmodelled: { [string]: boolean } = {}
	for _, r in { cooldown, burst, sustained, aoeBurst, aoeSus } do
		for _, text in r.unmodelled do
			unmodelled[text] = true
		end
	end
	local skipped: { [string]: { reason: string, count: number } } = table.clone(sustained.skipped)
	for id, s in aoeSus.skipped do
		if not skipped[id] then
			skipped[id] = s
		end
	end
	local list: { string } = {}
	for text in unmodelled do
		table.insert(list, text)
	end
	table.sort(list)
	local inRotation: { [string]: boolean } = {}
	for _, entry in build.rotation do
		inRotation[entry.skill] = true
	end
	local off: { string } = {}
	for _, id in Paths.availableSkills(sp.character) do
		local def = SkillData.get(id)
		if def and def.type ~= "passive" and not inRotation[id] and Paths.skillUsable(sp.character, id, sp.weapons) then
			if Skills.elementAllowed(def, sp.element) then
				table.insert(off, id)
			end
		end
	end
	local shares: { [string]: number } = {}
	for id, v in sustained.by do
		shares[id] = v / math.max(1e-9, sustained.dealt)
	end
	local ch = SkillModel.character(build, L)
	return {
		basic = basic.dps,
		onCooldown = cooldown.dps,
		demand = cooldown.spent / A.sustainedSeconds,
		burst8 = burst.dps,
		sustained60 = sustained.dps,
		sustained60p = withPotions.dps,
		potionsPerMinute = withPotions.potions * 60 / A.sustainedSeconds,
		aoe3burst = aoeBurst.dps,
		aoe3sus = aoeSus.dps,
		tsk1 = sustained.dps / basic.dps,
		tsk2 = burst.dps / basic.dps,
		tsk3 = aoeBurst.dps / burst.dps,
		tsk1rel = 0,
		tsk2rel = 0,
		tsk4 = (cooldown.spent / A.sustainedSeconds) / math.max(1e-9, cooldown.regen),
		pool = cooldown.poolMax,
		regen = cooldown.regen,
		spent = ch.spent,
		free = ch.free,
		unmodelled = list,
		skipped = skipped,
		offRotation = off,
		shares = shares,
	}
end

local NUMERIC = {
	"basic",
	"onCooldown",
	"demand",
	"burst8",
	"sustained60",
	"sustained60p",
	"potionsPerMinute",
	"aoe3burst",
	"aoe3sus",
	"pool",
	"regen",
}

-- S85 (G1): the numbers of one row. Mage: the mean of the three weapon elements (E5), ratios from the means, the
-- per-element numbers in byElement. tsk1rel / tsk2rel against the same build at L20.
function SkillModel.metrics(build: Build, L: number): Metrics
	local key = `{build.classId}|{build.key}|{L}`
	local cached = metricsCache[key]
	if cached then
		return cached
	end
	local m: Metrics
	if build.classId == "Mage" then
		local byElement: { [string]: Metrics } = {}
		local runs: { Metrics } = {}
		for _, element in A.elements do
			local r = rawMetrics(build, L, element)
			byElement[element] = r
			table.insert(runs, r)
		end
		m = table.clone(runs[1])
		for _, field in NUMERIC do
			local sum = 0
			for _, r in runs do
				sum += (r :: any)[field]
			end
			(m :: any)[field] = sum / #runs
		end
		m.tsk1 = m.sustained60 / m.basic
		m.tsk2 = m.burst8 / m.basic
		m.tsk3 = m.aoe3burst / m.burst8
		m.tsk4 = m.demand / math.max(1e-9, m.regen)
		local seen: { [string]: boolean } = {}
		local list: { string } = {}
		local off: { [string]: boolean } = {}
		local skipped: { [string]: { reason: string, count: number } } = {}
		local shares: { [string]: number } = {}
		for _, r in runs do
			for _, text in r.unmodelled do
				if not seen[text] then
					seen[text] = true
					table.insert(list, text)
				end
			end
			for _, id in r.offRotation do
				off[id] = true
			end
			for id, s in r.skipped do
				skipped[id] = skipped[id] or s
			end
			for id, v in r.shares do
				shares[id] = (shares[id] or 0) + v / #runs
			end
		end
		table.sort(list)
		local offList: { string } = {}
		for id in off do
			table.insert(offList, id)
		end
		table.sort(offList)
		m.unmodelled = list
		m.offRotation = offList
		m.skipped = skipped
		m.shares = shares
		m.byElement = byElement
	else
		m = rawMetrics(build, L, nil)
	end
	if L == 20 then
		m.tsk1rel, m.tsk2rel = 1, 1
	else
		local at20 = SkillModel.metrics(build, 20)
		m.tsk1rel = m.tsk1 / at20.tsk1
		m.tsk2rel = m.tsk2 / at20.tsk2
	end
	metricsCache[key] = m
	return m
end

-- Test helper (J1 b): effects of `applies` ({ t, kind, duration, tick, maxStacks }) on one dummy over `seconds`
-- through the model's Apply / tickEntity; returns every tick { t, amount } and the effects left at the end.
function SkillModel.timeline(applies: { { [string]: any } }, seconds: number): ({ { number } }, { [string]: any })
	local state: any = {
		t = 0,
		dealt = 0,
		by = {},
		healTo = {},
		selfDirty = false,
		self = { effects = {} },
		unmodelled = {},
	}
	local target = { m = B.monster(B.GENERIC, 20), hp = A.dummyHp, maxHp = A.dummyHp, dummy = true, effects = {} }
	local ticks: { { number } } = {}
	local steps = math.floor(seconds / A.dt + 0.5)
	local nextApply = 1
	for step = 0, steps do
		state.t = step * A.dt
		local before = state.dealt
		tickEntity(state, target)
		if state.dealt > before then
			table.insert(ticks, { state.t, state.dealt - before })
		end
		local a = applies[nextApply]
		while a and a.t <= state.t + EPS do
			apply(state, target, a.kind or "bleed", {
				duration = a.duration,
				value = a.value or 1,
				tickAmount = a.tick,
				maxStacks = a.maxStacks,
				skillId = a.skillId or "test",
			})
			nextApply += 1
			a = applies[nextApply]
		end
	end
	return ticks, target.effects
end

-- Healing (F) -----------------------------------------------------------------------------------------------------

-- S85 (F1, T-SK5): one Heal of the build's Cleric at L on `tank` (a Balance.Player) as a share of the tank's max HP:
-- Skills.healAmount("heal") x the heal factor of another player (healPower, healBonus + allyHealBonus, healCrit as
-- expected value). Default tank: the convention Warrior (ROZWOJ 9.6, diag_skilltable).
function SkillModel.oneHeal(build: Build, L: number, tank: any?): number
	local sp = SkillModel.player(build, L)
	local tankPlayer = tank or B.player("Warrior", L)
	local rank = Paths.skillRank(sp.character, "heal")
	if rank <= 0 then
		return 0
	end
	local def = Paths.effectiveFor(sp.character, "heal", sp.weapons, rank)
	local v = sp.p.values
	local amount = Skills.healAmount(def, rank, "heal", tankPlayer.values.maxHp, v.magAtk or 0, L)
	local bonus = Skills.healBonusPct({
		healBonus = sp.pathHooks.healBonus or 0,
		allyHealBonus = sp.pathHooks.allyHealBonus or 0,
		lowHpHealBonus = sp.pathHooks.lowHpHealBonus or 0,
	}, true, A.healTargetFraction)
	local mul = (1 + (v.healPower or 0) / 100)
		* (1 + bonus / 100)
		* (1 + Skills.healCritChance(v.critChance or 0, sp.pathHooks.healCrit or 0) * (SkillData.HEAL_CRIT_MUL - 1))
	return amount * mul / tankPlayer.values.maxHp
end

-- The tank "Defender" (guardian.defender) at L as a Balance.Player (T-SK5's second tank, S86, S87 G10, S89).
function SkillModel.defenderTank(L: number): any
	local build = SkillModel.build("guardian.defender", "Warrior") :: Build
	return SkillModel.player(build, L).p
end

export type HealerVsBoss = {
	bossId: string,
	level: number,
	seconds: number,
	hps: number, -- heal per second on the tank
	tankDps: number,
	tsk6: number,
	mana: number, -- heal rotation's mana on cooldown / regeneration (report)
	casts: { [string]: number },
	unmodelled: { string },
}

local healCache: { [string]: HealerVsBoss } = {}

-- S85 (F2, T-SK6): the build's Cleric in the party of the band's boss (party at boss level - 1; ASSUMPTIONS.team or
-- opts.team = "s92"), heal per second on the tank over Balance.bossFight(...).seconds from the build's rotation with
-- its mana (no potions) / the fight's tankDps. "Without overheal": no second target, no other members, no overflow
-- shield; amounts are not cut to missing HP (no HP axis, S86).
function SkillModel.healerVsBoss(build: Build, bossId: string, opts: { team: string? }?): HealerVsBoss
	local teamName = if opts and opts.team then opts.team else "default"
	local key = `{build.key}|{bossId}|{teamName}`
	local cached = healCache[key]
	if cached then
		return cached
	end
	local def = Bosses.byId[bossId] :: any
	local L = def.level - A.teamLevelGap
	local sp = SkillModel.player(build, L)
	local team: { any } = {}
	if teamName == "s92" then
		for _, k in A.teamS92 do
			if string.sub(k, 1, 7) == "healer." then
				table.insert(team, sp.p)
			else
				local b = SkillModel.build(k) :: Build
				table.insert(team, SkillModel.player(b, L).p)
			end
		end
	else
		for _, classId in A.team do
			table.insert(team, if classId == "Cleric" then sp.p else B.player(classId, L))
		end
	end
	local fightOf = B.bossFight(bossId, team)
	local m = B.monster(B.bossKind(def, #team), def.level, "boss")
	local heal = { tank = team[1], team = #team }
	local r = SkillModel.fight(sp, { targets = { m }, seconds = fightOf.seconds, heal = heal })
	local cd = SkillModel.fight(sp, { targets = { m }, seconds = A.sustainedSeconds, heal = heal, unlimited = true })
	local hps = (r.healTo.tank or 0) / math.max(1e-9, fightOf.seconds)
	local out: HealerVsBoss = {
		bossId = bossId,
		level = L,
		seconds = fightOf.seconds,
		hps = hps,
		tankDps = fightOf.tankDps,
		tsk6 = hps / math.max(1e-9, fightOf.tankDps),
		mana = (cd.spent / A.sustainedSeconds) / math.max(1e-9, cd.regen),
		casts = r.casts,
		unmodelled = r.unmodelled,
	}
	healCache[key] = out
	return out
end

-- Target rows (J2) ----------------------------------------------------------------------------------------------------

-- T-SK4 bands (ROZWOJ 8, 12.7): the main builds 2.0-3.0, their variants from 1.6, the base 1.1-1.4.
SkillModel.TSK4_BANDS = {
	["destroyer.destroyerExp"] = { 2.0, 3.0 },
	["arcanist.arcanistBoss"] = { 2.0, 3.0 },
	["destroyer.destroyerBoss"] = { 1.6 },
	["arcanist.arcanistOverload"] = { 1.6 },
	base = { 1.1, 1.4 },
	["base.loadout"] = { 1.1, 1.4 },
} :: { [string]: { number } }
SkillModel.TSK5_BAND = { 0.25, 0.35 } -- ROZWOJ 0, 7.5

-- S85 (J2): G10 rows for the global block (report until S87): T-SK4 of the Mage base and every Mage build from 45
-- (the target holds after 45, ROZWOJ 8; mean of the elements) and T-SK5 of the Cleric base and every Cleric build on
-- both tanks, L = 20, 25, ..., 100. Labels name the build key (and the tank).
function SkillModel.targetsG10(): { B.TargetRow }
	local rows: { B.TargetRow } = {}
	for _, L in SkillModel.G10_LEVELS do
		if L >= 45 then
			for _, build in SkillModel.builds("Mage") do
				local band = SkillModel.TSK4_BANDS[build.key] or { 2.0, 3.0 }
				local m = SkillModel.metrics(build, L)
				table.insert(rows, {
					id = "G10",
					group = "G10",
					label = `T-SK4 Mage {build.key} {L}`,
					value = m.tsk4,
					low = band[1],
					high = band[2],
					classId = "Mage",
					level = L,
				})
			end
		end
		local tanks = { { "Warrior", B.player("Warrior", L) }, { "guardian.defender", SkillModel.defenderTank(L) } }
		for _, build in SkillModel.builds("Cleric") do
			for _, tank in tanks do
				table.insert(rows, {
					id = "G10",
					group = "G10",
					label = `T-SK5 Cleric {build.key} na {tank[1]} {L}`,
					value = SkillModel.oneHeal(build, L, tank[2]),
					low = SkillModel.TSK5_BAND[1],
					high = SkillModel.TSK5_BAND[2],
					classId = "Cleric",
					level = L,
				})
			end
		end
	end
	return rows
end

-- S85 (J2): the Meadows' rows at L20, printed only (S86 or S91 assert them): T-SK3 of every base and build against
-- its areaCap, T-SK6 of every Cleric build on Grimrok (default party).
function SkillModel.targetsMeadows(): { B.TargetRow }
	local rows: { B.TargetRow } = {}
	for _, classId in B.CLASSES do
		for _, build in SkillModel.builds(classId) do
			table.insert(rows, {
				id = `R.meadows.tsk3.{classId}.{build.key}`,
				group = "T-SK3",
				label = `T-SK3 {classId} {build.key} 20`,
				value = SkillModel.metrics(build, 20).tsk3,
				high = build.areaCap,
				classId = classId,
				level = 20,
				report = "S86",
			})
		end
	end
	for _, build in SkillModel.builds("Cleric") do
		table.insert(rows, {
			id = `R.meadows.tsk6.{build.key}`,
			group = "T-SK6",
			label = `T-SK6 Cleric {build.key} grimrok`,
			value = SkillModel.healerVsBoss(build, "grimrok").tsk6,
			low = 1.0,
			high = 2.0,
			classId = "Cleric",
			level = 20,
			report = "S86",
		})
	end
	return rows
end

return SkillModel
