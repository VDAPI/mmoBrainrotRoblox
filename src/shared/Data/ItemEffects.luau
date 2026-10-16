--!strict
-- S134g: skill effects of Legendary and Mythic items (docs/STATY.md 2C, 9; docs/DESIGN-18.md §0.9). Data only; rules
-- (rolling, reading the equipment, the save migration, text arguments) in Logic/ItemEffects.
--
-- An effect changes one skill of its class: `bp` has the shape of a breakpoint (Data/Skills/Types Breakpoint) and joins
-- Logic/Skills.effective after the path nodes (Logic/Paths.effectiveFor), so the server, the skill bar, aiming and
-- the skill description see it the same way. Its numbers are fixed: they never grow with the item level or upgrade
-- (the skill itself grows with its rank). `id` is saved on the item (ItemInstance.fx) and never changes; `skill`,
-- `role` and `pool` follow docs/DESIGN-18.md §5-§6, so the skills 2.0 sessions (S137-S148) repoint `skill` / `bp` here
-- without touching saves; a removed effect keeps its entry with `replacedBy` (Logic/ItemEffects.resolve).
-- `hook` (rare): an S62 hook added by itemStats like a trait's, for what a breakpoint cannot say. `score` is the
-- ItemScore estimate (% of one axis, like the trait estimates of STATY 14).
-- Texts: itemfx.<id>.name and itemfx.<id>.line (PL, EN); the line gets {skill} (skill.<skill>.name) and every number of
-- `bp` under its field name (Logic/ItemEffects.lineArgs). Rule of the receiver (tests/itemeffects.spec, B2): a
-- behaviour key of `bp` is not in the skill's own breakpoints and has a receiver for the skill's type.

local SkillTypes = require("./Skills/Types")

export type Tier = "legendary" | "mythic"
export type Axis = "dmg" | "surv" | "support"
export type Score = { axis: Axis, pct: number }

export type ItemEffectDef = {
	id: string,
	tier: Tier,
	class: string, -- Classes.order form ("Mage")
	skill: string, -- Data/Skills id today
	role: string, -- DESIGN-18 §5 code ("S1", "A2", "C1", ...)
	pool: string, -- DESIGN-18 §4.2 pool id, "common" for the class's shared skills
	bp: SkillTypes.Breakpoint,
	hook: { id: string, value: number }?,
	score: Score,
	wiki: boolean,
	replacedBy: string?, -- a retired effect is read as this one (never deleted without a successor)
	nameKey: string,
	lineKey: string,
}

local LIST: { ItemEffectDef } = {}
local BY_ID: { [string]: ItemEffectDef } = {}

local function fx(
	id: string,
	spec: {
		tier: Tier,
		class: string,
		skill: string,
		role: string,
		pool: string,
		bp: SkillTypes.Breakpoint,
		hook: { id: string, value: number }?,
		score: Score,
		wiki: boolean?,
		replacedBy: string?,
	}
)
	assert(BY_ID[id] == nil, `ItemEffects: duplicate id {id}`)
	local def: ItemEffectDef = table.freeze({
		id = id,
		tier = spec.tier,
		class = spec.class,
		skill = spec.skill,
		role = spec.role,
		pool = spec.pool,
		bp = spec.bp,
		hook = spec.hook,
		score = table.freeze(spec.score),
		wiki = spec.wiki ~= false,
		replacedBy = spec.replacedBy,
		nameKey = `itemfx.{id}.name`,
		lineKey = `itemfx.{id}.line`,
	}) :: any
	table.insert(LIST, def)
	BY_ID[id] = def
end

local function dmg(pct: number): Score
	return { axis = "dmg", pct = pct }
end
local function surv(pct: number): Score
	return { axis = "surv", pct = pct }
end
local function support(pct: number): Score
	return { axis = "support", pct = pct }
end

-- Mage ---------------------------------------------------------------------------------------------------------------
fx("fireball_afterblast", {
	tier = "legendary",
	class = "Mage",
	skill = "fireball",
	role = "A1",
	pool = "fire",
	bp = { echo = { delay = 1, pct = 30 } },
	score = dmg(4),
})
fx("firebolt_executioner", {
	tier = "legendary",
	class = "Mage",
	skill = "firebolt",
	role = "S1",
	pool = "fire",
	bp = { execute = 25 },
	score = dmg(4),
})
fx("iceShard_shatter", {
	tier = "legendary",
	class = "Mage",
	skill = "iceShard",
	role = "S1",
	pool = "ice",
	bp = { splash = { radius = 4, pct = 25 } },
	score = dmg(4),
})
fx("chainLightning_arc", {
	tier = "legendary",
	class = "Mage",
	skill = "chainLightning",
	role = "A1",
	pool = "lightning",
	bp = { add = { jumps = 1 } },
	score = dmg(4),
})
fx("frostNova_deepcold", {
	tier = "legendary",
	class = "Mage",
	skill = "frostNova",
	role = "K1",
	pool = "ice",
	bp = { add = { radius = 2, freezeDuration = 0.5 } },
	score = surv(4),
})
-- S134g: replaces blink_frostprint (a trap: Blink's own 10B is a trap, so it would be dead or replace the choice, B2)
fx("blink_arcaneSurge", {
	tier = "legendary",
	class = "Mage",
	skill = "blink",
	role = "C1",
	pool = "common",
	bp = {
		selfEffect = {
			kind = "statBuff",
			duration = 4,
			stats = { magAtk = "surgePower" },
			pct = true,
			target = "self",
			category = "own",
		},
		values = { surgePower = 10 },
	},
	score = dmg(3),
})
fx("meteor_shards", {
	tier = "mythic",
	class = "Mage",
	skill = "meteor",
	role = "A2",
	pool = "fire",
	bp = { split = { count = 3, pct = 35, radius = 7 } },
	score = dmg(7),
})
fx("firewall_aftershock", {
	tier = "mythic",
	class = "Mage",
	skill = "firewall",
	role = "A2",
	pool = "lightning",
	bp = { echo = { delay = 1.5, pct = 40 } },
	score = dmg(7),
})
-- S134g: replaces iceShard_volley (a flat values.dmg cut for 3 shards depends on the rank: below rank 7 the three
-- shards would deal less than one); the same pool (ice), a mythic on its control skill
fx("frostNova_maelstrom", {
	tier = "mythic",
	class = "Mage",
	skill = "frostNova",
	role = "K1",
	pool = "ice",
	bp = { pull = 14 },
	score = dmg(6),
})

-- Warrior ------------------------------------------------------------------------------------------------------------
-- S134g: Charge already stuns (its own effect), so the effect lengthens that stun (add.stunDuration, S75) instead of
-- a second stun the effect stack would drop
fx("charge_stagger", {
	tier = "legendary",
	class = "Warrior",
	skill = "charge",
	role = "C1",
	pool = "common",
	bp = { add = { stunDuration = 0.7 } },
	score = surv(3),
})
fx("mightyStrike_bloodthirst", {
	tier = "legendary",
	class = "Warrior",
	skill = "mightyStrike",
	role = "S1",
	pool = "onehand",
	bp = { lifesteal = 15 },
	score = surv(4),
})
fx("cleave_wide", {
	tier = "legendary",
	class = "Warrior",
	skill = "cleave",
	role = "A1",
	pool = "twohand",
	bp = { knockback = 5 },
	score = surv(3),
})
fx("crushingBlow_finisher", {
	tier = "legendary",
	class = "Warrior",
	skill = "crushingBlow",
	role = "S2",
	pool = "onehand",
	bp = { execute = 25 },
	score = dmg(4),
})
fx("rend_hamstring", {
	tier = "legendary",
	class = "Warrior",
	skill = "rend",
	role = "S2",
	pool = "twohand",
	bp = { effect = { kind = "slow", value = 30, duration = 3, category = "enemySlow" } },
	score = surv(3),
})
-- S134g: replaces taunt_bulwark (shieldPerHit: the Guardian's Defender's Oath node already sets it on Taunt, so the
-- item's would replace the node's, B2)
fx("taunt_muster", {
	tier = "legendary",
	class = "Warrior",
	skill = "taunt",
	role = "C2",
	pool = "common",
	bp = { pull = 12 },
	score = surv(4),
})
fx("earthquake_rupture", {
	tier = "mythic",
	class = "Warrior",
	skill = "earthquake",
	role = "A2",
	pool = "onehand",
	bp = { stunLast = 1 },
	score = surv(7),
})
fx("bladeWhirl_secondwind", {
	tier = "mythic",
	class = "Warrior",
	skill = "bladeWhirl",
	role = "A2",
	pool = "twohand",
	bp = { selfHeal = 5 },
	score = surv(7),
})
fx("shieldWall_rally", {
	tier = "mythic",
	class = "Warrior",
	skill = "shieldWall",
	role = "U",
	pool = "onehand",
	bp = { pull = 10 },
	score = surv(6),
})

-- Hunter -------------------------------------------------------------------------------------------------------------
fx("aimedShot_burst", {
	tier = "legendary",
	class = "Hunter",
	skill = "aimedShot",
	role = "S1",
	pool = "bow",
	bp = { splash = { radius = 4, pct = 30 } },
	score = dmg(4),
})
fx("arrowRain_second", {
	tier = "legendary",
	class = "Hunter",
	skill = "arrowRain",
	role = "A1",
	pool = "bow",
	bp = { echo = { delay = 1, pct = 30 } },
	score = dmg(4),
})
fx("venomArrow_contagion", {
	tier = "legendary",
	class = "Hunter",
	skill = "venomArrow",
	role = "S2",
	pool = "crossbow",
	bp = { poisonSpread = 2 },
	score = dmg(3),
})
fx("disengage_tailwind", {
	tier = "legendary",
	class = "Hunter",
	skill = "disengage",
	role = "C1",
	pool = "common",
	bp = {
		-- flat points of moveSpeed (a % stat); the same key as Disengage 10B's dodge buff merges with it (S53)
		selfEffect = {
			kind = "statBuff",
			duration = 4,
			stats = { moveSpeed = "tailwind" },
			target = "self",
			category = "own",
		},
		values = { tailwind = 25 },
	},
	score = surv(3),
})
-- S134g: replaces huntersMark_relay (markJump: the Scout's node already sets it on the mark, B2); add.radius sums with
-- 5B (its enemy effects also land around the target, Types/Support debuff)
fx("huntersMark_spread", {
	tier = "legendary",
	class = "Hunter",
	skill = "huntersMark",
	role = "C2",
	pool = "common",
	bp = { add = { radius = 6 } },
	score = dmg(3),
})
fx("piercingArrow_venom", {
	tier = "legendary",
	class = "Hunter",
	skill = "piercingArrow",
	role = "A1",
	pool = "crossbow",
	-- no category, like every DoT (ROZWOJ 7.1); value = % of the attack over the duration, as Venom Arrow's poison
	bp = { effect = { kind = "poison", duration = 4, value = 30 } },
	score = dmg(4),
})
fx("volley_followup", {
	tier = "mythic",
	class = "Hunter",
	skill = "volley",
	role = "A2",
	pool = "bow",
	bp = { echo = { delay = 1, pct = 35 } },
	score = dmg(7),
})
fx("doubleShot_instinct", {
	tier = "mythic",
	class = "Hunter",
	skill = "doubleShot",
	role = "S2",
	pool = "bow",
	bp = { critCdr = 30 },
	score = dmg(6),
})
fx("frostTrap_snare", {
	tier = "mythic",
	class = "Hunter",
	skill = "frostTrap",
	role = "K1",
	pool = "crossbow",
	bp = { pull = 8 },
	score = surv(6),
})

-- Cleric -------------------------------------------------------------------------------------------------------------
fx("holyStrike_zeal", {
	tier = "legendary",
	class = "Cleric",
	skill = "holyStrike",
	role = "S1",
	pool = "hammer",
	bp = { lifesteal = 20 },
	score = surv(4),
})
fx("heal_smite", {
	tier = "legendary",
	class = "Cleric",
	skill = "heal",
	role = "C1",
	pool = "common",
	bp = { burst = { radius = 6, pct = 40 } },
	score = dmg(3),
})
fx("radiance_dazzle", {
	tier = "legendary",
	class = "Cleric",
	skill = "radiance",
	role = "A1",
	pool = "light",
	bp = { effect = { kind = "slow", value = 25, duration = 2, category = "enemySlow" } },
	score = surv(3),
})
-- S134g: replaces shieldOfFaith_shards (shieldBurst: the Healer's Shattering Shield node already sets it, B2)
fx("shieldOfFaith_steadfast", {
	tier = "legendary",
	class = "Cleric",
	skill = "shieldOfFaith",
	role = "O1",
	pool = "light",
	bp = { add = { duration = 4 }, values = { shieldHp = 4 } },
	score = support(4),
})
fx("renew_lasting", {
	tier = "legendary",
	class = "Cleric",
	skill = "renew",
	role = "S2",
	pool = "light",
	bp = { add = { duration = 3 } },
	score = support(4),
})
fx("brandOfLight_mercy", {
	tier = "legendary",
	class = "Cleric",
	skill = "brandOfLight",
	role = "S2",
	pool = "hammer",
	bp = { healWounded = 20 },
	score = support(4),
})
-- S134g: replaces judgement_verdict (stunSplash: the Inquisitor's Final Verdict node already sets it, B2)
fx("judgement_reckoning", {
	tier = "mythic",
	class = "Cleric",
	skill = "judgement",
	role = "S3",
	pool = "hammer",
	bp = { splash = { radius = 6, pct = 50 } },
	score = dmg(7),
})
-- S134g: Sanctuary 5B already cleanses, so the mythic is time and reach only (no cleanse, B2)
fx("sanctuary_haven", {
	tier = "mythic",
	class = "Cleric",
	skill = "sanctuary",
	role = "A2",
	pool = "light",
	bp = { add = { duration = 3, radius = 2 } },
	score = support(7),
})
fx("circleOfLight_aegis", {
	tier = "mythic",
	class = "Cleric",
	skill = "circleOfLight",
	role = "C2",
	pool = "common",
	bp = { overhealShield = true },
	score = support(7),
})

return table.freeze({
	list = LIST,
	byId = BY_ID,
	get = function(id: string): ItemEffectDef?
		return BY_ID[id]
	end,
	TIERS = table.freeze({ "legendary", "mythic" } :: { Tier }),
})
