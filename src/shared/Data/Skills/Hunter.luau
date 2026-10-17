--!strict
-- Hunter (docs/ROZWOJ.md 11): the class's skills. Energy. Values are { rank 1, rank 10 } (passives: rank 5).
-- S144 (docs/DESIGN-18.md §6.3): two weapon pools on the shared ladder, Bow (`bow`: quick shots, crits, movement, the
-- falcon) and Crossbow (`crossbow`: heavy bolts, traps, poison, piercing), and the Hunter's common skills (Disengage C1
-- 4, Hunter's Mark C2 12, Draw a Bead C3 30, Predator's Instinct C4 45); the old path skills moved into the pools, the
-- directions keep one skill: the Drive (the Scout's capstone, row 8). The new skills follow the old ones (the `order`
-- of the old ones stays). Crossbow school rules: Logic/Crossbow (Toxic Tips, Executioner's Bolt, Quick Reload); a root
-- that turns into a slow on bosses: Logic/Snare (SkillEffect.bossSlow).

local Build = require("./Build")
local Types = require("./Types")

-- S77: typed apart (luau-lsp rejects a literal list of effects of different shapes)
local SNAREFIELD_EFFECTS: { Types.SkillEffect } = {
	{ kind = "vulnerability", duration = 6, value = "vuln", category = "enemyWeak" },
	{ kind = "root", duration = { 1.5, 2.5 }, notBoss = true },
}
-- S144: Wind Step's two own effects (dodge, movement); one statBuff key, so they merge (EffectStack.merge)
local WINDSTEP_EFFECTS: { Types.SkillEffect } = {
	{ kind = "statBuff", duration = 4, stats = { dodge = "dodge" }, target = "self", category = "own" },
	{ kind = "statBuff", duration = 4, stats = { moveSpeed = "move" }, target = "self", category = "own" },
}
-- S144 (Logic/Snare): a root, on bosses and Elite IIs a slow of values.slow % for the same time
local PIN_EFFECTS: { Types.SkillEffect } = { { kind = "root", duration = 2, bossSlow = "slow" } }
local NET_EFFECTS: { Types.SkillEffect } = { { kind = "root", duration = 2.5, bossSlow = "slow" } }

return Build.class("Hunter", "energy", "phys", {
	-- The old base (ROZWOJ 11.2) ----------------------------------------------------------------------------------
	{
		id = "aimedShot",
		pool = "bow", -- S144: S1 of the Bow (DESIGN-18 §6.3)
		role = "S1",
		unlock = 1,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 15,
		cooldown = 4,
		range = 38,
		values = { dmg = { 144, 233 } }, -- S91: rank 1 170 -> 144 (ranks <= 20, Data/SkillCurves)
		breakpoints = Build.bp2(
			{ a = { pierce = 50 }, b = { values = { dmg = 30 } } },
			{ a = { execute = 21 }, b = { lifesteal = 12 } }
		),
		glyph = "➶",
		vfx = "arrow",
	},
	{
		id = "doubleShot",
		pool = "bow", -- S144: S2 of the Bow (was 3)
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 20,
		cooldown = 6,
		range = 38,
		hits = 2,
		interval = 0.15,
		-- S144: rank 1 at 15 = the old rank 4 at 15, rank 2 (19) the old rank 5, rank 3 (23) the old rank 6 (knots)
		values = { dmg = { 77.75, 114 } },
		breakpoints = Build.bp2(
			{ a = { add = { hits = 1 } }, b = { mul = { cooldown = 0.87 } } },
			{ -- S91: 5B 0.7 -> 0.87 (R4)
				a = { effect = { kind = "slow", duration = 2, value = 25, category = "enemySlow" } },
				b = { values = { dmg = 28 } },
			}
		),
		glyph = "⇉",
		vfx = "arrow",
	},
	{
		id = "disengage",
		pool = "common",
		role = "C1",
		unlock = 4, -- S144: 6 -> 4 (C1)
		maxLevel = 10,
		type = "blink",
		delivery = "ranged",
		target = "none",
		cost = 15,
		cooldown = 10,
		length = 15,
		values = { bonus = { 20, 35 } },
		effects = { { kind = "nextShot", duration = 8, value = "bonus", target = "self", category = "own" } },
		breakpoints = Build.bp2(
			{ a = { trap = { radius = 6, duration = 8, slow = 40 } }, b = { mul = { cooldown = 0.7 } } },
			{
				a = { values = { bonus = 50 }, add = { effectDuration = -5 } },
				-- dodge is percentage points: flat, not pct
				b = {
					selfEffect = {
						kind = "statBuff",
						duration = 4,
						stats = { dodge = "dodgeBp" },
						target = "self",
						category = "own",
					},
					values = { dodgeBp = 20 },
				},
			}
		),
		glyph = "⤺",
	},
	{
		id = "arrowRain",
		pool = "bow", -- S144: A1 of the Bow (was 10)
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 35,
		cooldown = 10,
		range = 38,
		radius = 9,
		hits = 4,
		interval = 0.5,
		-- S144: rank 5 (level 19) keeps the old rank 3 (level 18, Data/SkillCurves), rank 3 (11) about the old rank 1 at 10
		values = { dmg = { 36, 85 } },
		breakpoints = Build.bp2({ a = { add = { radius = 3 } }, b = { values = { dmg = 8 } } }, {
			a = { effect = { kind = "slow", duration = 2, value = 30, category = "enemySlow" } },
			b = { add = { hits = 1 } },
		}),
		glyph = "☔",
	},
	{
		id = "hawkEye",
		pool = "bow", -- S144: P1 of the Bow (was 14; rank 1 at 20 = the old rank 1)
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		values = { crit = { 2, 4 }, critDmg = { 10, 16 } },
		passive = { flat = { critChance = "crit", critDmg = "critDmg" } },
		glyph = "👁",
	},
	{
		id = "venomArrow",
		pool = "crossbow", -- S144: S2 of the Crossbow (was 18)
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 25,
		cooldown = 8,
		range = 38,
		element = "poison",
		values = { dmg = { 120, 152 }, poison = { 50, 50 } },
		effects = { { kind = "poison", duration = 6, value = "poison" } },
		-- S144: 5A 21 -> 15 and 10B 60 -> 28 (R4 on the Crossbow's Trapper, whose nodes stack and strengthen the poison)
		breakpoints = Build.bp2(
			{ a = { values = { poison = 15 } }, b = { values = { dmg = 28 } } },
			{ a = { splash = { radius = 5, pct = 19 } }, b = { values = { poison = 28 } } }
		),
		glyph = "☠",
		vfx = "arrow",
	},
	{
		id = "volley",
		pool = "bow", -- S144: A2 of the Bow (was 30)
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "cone",
		delivery = "ranged",
		cost = 50,
		cooldown = 13,
		radius = 25,
		angle = 60,
		hits = 7,
		values = { dmg = { 24, 34 } }, -- S144: rank 2 (level 30) keeps the old rank 1 (Data/SkillCurves)
		breakpoints = Build.bp2(
			{ a = { add = { hits = 1 } }, b = { values = { dmg = 4 } } }, -- S144: 5B 5 -> 4 (R4 from 26)
			{ a = { add = { angle = 30 } }, b = { values = { dmg = 9 } } }
		),
		glyph = "⇶",
	},
	{
		id = "predatorInstinct",
		pool = "common",
		role = "C4",
		unlock = 45,
		maxLevel = 5,
		type = "passive",
		values = { speed = { 17, 34 } },
		passive = { flat = { atkSpeed = "speed" } },
		glyph = "🐾",
	},
	-- The old Marksman skills (ROZWOJ 11.3). Draw a Bead: only the caster's hits on the target crit more (effect
	-- `sighted`). Heartseeker: aimed for castTime (S76), double damage below 20% HP (finisher, x1.5 on players).
	{
		id = "piercingArrow",
		pool = "crossbow", -- S144: A1 of the Crossbow (was the Marksman's row 1): "Piercing Bolt" in the texts
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "line",
		delivery = "ranged",
		cost = 40,
		cooldown = 12,
		length = 35,
		width = 4,
		-- S144: rank 5 (level 19) keeps the old rank 3 (level 18, Data/SkillCurves), rank 3 (11) the old rank 1 at 10
		values = { dmg = { 164.4, 410 } },
		breakpoints = Build.bp2({
			a = { add = { width = 2 } },
			-- no category, like every DoT (ROZWOJ 7.1, 7.2); S144: 50 -> 40 (R4 at 20: rank 5 at 19)
			b = { effect = { kind = "bleed", duration = 6, value = 40 } },
		}, { a = { knockback = 6 }, b = { mul = { cooldown = 0.8 } } }),
		glyph = "➸",
	},
	{
		id = "drawBead",
		pool = "common", -- S144: C3 of the Hunter (was the Marksman's row 4)
		role = "C3",
		unlock = 30,
		maxLevel = 10,
		type = "debuff",
		delivery = "ranged",
		cost = 15,
		cooldown = 25,
		range = 40,
		values = { crit = { 20.33, 23 }, critDmg = { 26.67, 28 } }, -- S144: rank 1 at 30 = the old rank 2 at 30
		effects = { { kind = "sighted", duration = 10, stats = { critChance = "crit", critDmg = "critDmg" } } },
		breakpoints = Build.bp2({ a = { add = { effectDuration = 2 } }, b = { values = { critDmg = 15 } } }, {
			a = { mul = { cooldown = 0.8 } },
			b = { selfEffect = { kind = "guaranteedCrit", duration = 5, target = "self", category = "own" } },
		}),
		glyph = "◎",
	},
	{
		id = "stormArrow",
		pool = "bow", -- S144: U of the Bow (was the Marksman's row 7, 48)
		role = "U",
		unlock = 60,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 80,
		cooldown = 29,
		range = 38,
		radius = 8,
		element = "lightning",
		values = { dmg = { 266.7, 400 }, splash = 75 }, -- S144: rank 1 at 60 = the old rank 4 at 60
		breakpoints = Build.bp2(
			{ a = { add = { radius = 4 } }, b = { values = { dmg = 37 } } },
			{ a = { effect = { kind = "stun", duration = 1 } }, b = { mul = { cooldown = 0.8 } } }
		),
		glyph = "⚡",
		vfx = "stormArrow",
	},
	{
		id = "heartseeker",
		pool = "bow", -- S144: S3 of the Bow (was the Marksman's capstone, 60)
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 50,
		cooldown = 31,
		range = 40,
		castTime = 1.5,
		finisher = { hp = 20, mul = 2 },
		values = { dmg = { 170, 290 } }, -- S144: rank 6 (level 60) keeps the old rank 1 (Data/SkillCurves)
		breakpoints = Build.bp2(
			{ a = { values = { dmg = 37 } }, b = { pierce = 11 } },
			{ a = { mul = { cooldown = 0.8 } }, b = { splash = { radius = 6, pct = 18 } } }
		),
		glyph = "➹",
	},
	-- The old Trapper skills (ROZWOJ 11.4). Venom Snare: a trap thrown to a point, damage + poison + slow. Snarefield:
	-- five snares in a ring around the point (S76 ringRadius).
	{
		id = "frostTrap",
		pool = "crossbow", -- S144: K1 of the Crossbow (was the Trapper's row 1)
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "trap",
		delivery = "ranged",
		cost = 25,
		cooldown = 18,
		radius = 6,
		duration = 20,
		hits = 1, -- 10B adds one (add.hits sums onto the base: without it the second trap never appears)
		element = "ice",
		values = { root = { 2, 3.5 } },
		effects = { { kind = "root", duration = { 2, 3.5 } } },
		breakpoints = Build.bp2({
			a = { add = { radius = 2 } },
			-- the same values.poison and effect as Blast Trap (ROZWOJ 11.4): one effect, summed value (S78 D4)
			b = { values = { poison = 9 }, effect = { kind = "poison", duration = 6, value = "poison" } },
		}, { a = { effect = { kind = "freeze", duration = 1 } }, b = { add = { hits = 1 } } }),
		glyph = "❄",
	},
	{
		id = "venomSnare",
		pool = "crossbow", -- S144: A2 of the Crossbow (was the Trapper's row 4)
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "trap",
		target = "point",
		delivery = "ranged",
		cost = 16,
		cooldown = 14,
		range = 30,
		radius = 6,
		duration = 20,
		element = "poison",
		values = { dmg = { 232, 236 }, poison = { 285, 290 }, slow = 30 },
		effects = {
			{ kind = "poison", duration = 6, value = "poison" },
			{ kind = "slow", duration = 3, value = "slow", category = "enemySlow" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { pull = 8 } },
			{ a = { echo = { delay = 1, pct = 44 } }, b = { values = { poison = 98 } } } -- S144: 10A 38 -> 44 (R4)
		),
		glyph = "☣",
	},
	{
		id = "camouflage",
		pool = "crossbow", -- S144: O1 of the Crossbow (was the Trapper's row 7)
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "buff",
		delivery = "ranged",
		cost = 30,
		cooldown = 67,
		duration = 4,
		values = {},
		effects = {
			{ kind = "camouflage", duration = 4, target = "self", category = "own" },
			{ kind = "guaranteedCrit", duration = 10, target = "self", category = "own" },
		},
		breakpoints = Build.bp2({ a = { add = { effectDuration = 2 } }, b = { mul = { cooldown = 0.75 } } }, {
			a = {
				selfEffect = {
					kind = "statBuff",
					duration = 4,
					-- moveSpeed already is a % of walk speed (base 0): flat points, not pct (S53).
					stats = { moveSpeed = "speedBp" },
					target = "self",
					category = "own",
				},
				values = { speedBp = 30 },
			},
			b = { selfHeal = 15 },
		}),
		glyph = "🌫",
	},
	{
		id = "snarefield",
		pool = "crossbow", -- S144: U of the Crossbow (was the Trapper's capstone)
		role = "U",
		unlock = 60,
		maxLevel = 10,
		type = "trap",
		target = "point",
		delivery = "ranged",
		cost = 45,
		cooldown = 35,
		range = 30,
		radius = 3.5,
		ringRadius = 8,
		hits = 5,
		duration = 15,
		values = { dmg = { 30, 38 }, vuln = { 5, 8 }, root = { 1.5, 2.5 } },
		effects = SNAREFIELD_EFFECTS,
		breakpoints = Build.bp2(
			{ a = { add = { radius = 1 } }, b = { values = { vuln = 1 } } }, -- 5B: at most the Mark with 10B (ROZWOJ 11.4)
			{ a = { values = { dmg = 14 } }, b = { pull = 6 } }
		),
		glyph = "⁂",
	},
	-- The old Scout skills (ROZWOJ 11.5). Falcon: a companion (Skills/Companion), first strike after `delay`, then every
	-- `interval`; `range` = reach of the hunter's target, `radius` = reach of the fallback target. The Drive (the
	-- Scout's capstone, row 8): pulls to the point (S76 pull), then one wave with slow and vulnerability.
	{
		id = "agility",
		pool = "bow", -- S144: P2 of the Bow (was the Scout's row 1)
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { dodge = { 10, 12 }, move = { 15, 18 } }, -- S144: rank 1 at 50 = the old rank 5 at 46
		passive = { flat = { dodge = "dodge", moveSpeed = "move" } },
		glyph = "🍃",
	},
	{
		id = "falcon",
		pool = "bow", -- S144: K2 of the Bow (was the Scout's row 4, 26)
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "companion",
		delivery = "ranged",
		cost = 30,
		cooldown = 36,
		duration = 20,
		interval = 2,
		delay = 1,
		range = 40,
		radius = 30,
		values = { dmg = { 28.9, 44 } }, -- S144: rank 1 at 33 = the old rank 2 at 30
		breakpoints = Build.bp2({
			a = { add = { duration = 4 } },
			b = { effect = { kind = "slow", duration = 2, value = 15, category = "enemySlow" } },
		}, { a = { values = { dmg = 14 } }, b = { splash = { radius = 5, pct = 10 } } }),
		glyph = "🦅",
	},
	{
		id = "huntersMark",
		pool = "common", -- S144: C2 of the Hunter (was the Scout's row 7)
		role = "C2",
		unlock = 12,
		maxLevel = 10,
		type = "debuff",
		delivery = "ranged",
		cost = 20,
		cooldown = 25,
		range = 40,
		values = { vuln = { 6, 8 } }, -- ROZWOJ 11.5, 15.4.1
		effects = { { kind = "vulnerability", duration = 10, value = "vuln", category = "enemyWeak" } },
		breakpoints = Build.bp2({ a = { add = { effectDuration = 1 } }, b = { add = { radius = 6 } } }, {
			a = { effect = { kind = "slow", duration = 10, value = 20, category = "enemySlow" } },
			b = { values = { vuln = 1 } },
		}),
		glyph = "🎯",
	},
	{
		id = "drive",
		path = "scout",
		unlock = 60, -- the Scout's capstone, row 8 (S144: was row 10, 80)
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 40,
		cooldown = 33,
		range = 30,
		radius = 12,
		pull = 10,
		-- S144: rank 6 (level 79) keeps the old rank 1 at 80 (Data/SkillCurves)
		values = { dmg = { 90, 108 }, slow = 30, vuln = 6 },
		effects = {
			{ kind = "slow", duration = 3, value = "slow", category = "enemySlow" },
			{ kind = "vulnerability", duration = 8, value = "vuln", category = "enemyWeak" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { radius = 3 } }, b = { mul = { cooldown = 0.9 } } },
			{ a = { values = { dmg = 20 } }, b = { effect = { kind = "root", duration = 1, notBoss = true } } }
		),
		glyph = "⇲",
	},
	-- S144 (DESIGN-18 §6.3): the new skills of the Bow -------------------------------------------------------------
	{
		id = "pinningShot",
		pool = "bow", -- K1 of the Bow
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 20,
		cooldown = 12,
		range = 38,
		values = { dmg = { 70, 130 }, slow = 40 },
		effects = PIN_EFFECTS,
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 0.5 } }, b = { values = { dmg = 14 } } },
			{ a = { mul = { cooldown = 0.8 } }, b = { values = { dmg = 32 } } }
		),
		glyph = "⇥",
	},
	{
		id = "windstep",
		pool = "bow", -- O1 of the Bow
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "buff",
		delivery = "ranged",
		cost = 20,
		cooldown = 20,
		duration = 4,
		-- dodge and moveSpeed are percentage points: flat, not pct
		values = { dodge = { 10, 20 }, move = { 20, 35 } },
		effects = WINDSTEP_EFFECTS,
		breakpoints = Build.bp2({ a = { add = { effectDuration = 2 } }, b = { values = { dodge = 5 } } }, {
			a = {
				selfEffect = {
					kind = "nextShot",
					duration = 6,
					value = "windShot",
					target = "self",
					category = "own",
				},
				values = { windShot = 25 },
			},
			b = { mul = { cooldown = 0.75 } },
		}),
		glyph = "🌬",
	},
	-- S144 (DESIGN-18 §6.3): the new skills of the Crossbow --------------------------------------------------------
	{
		id = "heavyBolt",
		pool = "crossbow", -- S1 of the Crossbow: Aimed Shot x1.3, slower (cooldown x1.3)
		role = "S1",
		unlock = 1,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 20,
		cooldown = 5.2,
		range = 38,
		values = { dmg = { 187.2, 302.9 } }, -- Aimed Shot's numbers and S91 knots x1.3 (Data/SkillCurves)
		breakpoints = Build.bp2({
			-- no category, like every DoT (ROZWOJ 7.1); % of the attack over 6 s
			a = { effect = { kind = "poison", duration = 6, value = 30 } },
			b = { values = { dmg = 39 } },
		}, { a = { pierce = 60 }, b = { values = { dmg = 60 } } }),
		glyph = "➼",
	},
	{
		id = "toxicTips",
		pool = "crossbow", -- P1 of the Crossbow (Logic/Crossbow, Data/Skills.CROSSBOW)
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		values = { tip = { 10, 20 } }, -- % of the attack over CROSSBOW.tipDuration per stack
		passive = { hooks = { toxicTips = "tip" } },
		glyph = "⚗",
	},
	{
		id = "netShot",
		pool = "crossbow", -- K2 of the Crossbow
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 30,
		cooldown = 18,
		range = 30,
		radius = 5,
		values = { dmg = { 60, 110 }, slow = 40 },
		effects = NET_EFFECTS,
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { values = { dmg = 12 } } },
			{ a = { add = { effectDuration = 0.5 } }, b = { values = { dmg = 26 } } }
		),
		glyph = "⌗",
	},
	{
		id = "deadlyBolt",
		pool = "crossbow", -- S3 of the Crossbow: the finisher on the poisoned (Logic/Crossbow.venomMul)
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 25,
		cooldown = 10,
		range = 38,
		-- venomMul % more on a target with at least venomStacks stacks of the caster's poisons
		values = { dmg = { 180, 260 }, venomMul = 50, venomStacks = 3 },
		breakpoints = Build.bp2(
			{ a = { values = { venomMul = 20 } }, b = { values = { dmg = 26 } } },
			{ a = { values = { venomMul = 35 } }, b = { values = { dmg = 52 } } }
		),
		glyph = "✠",
	},
	{
		id = "quickReload",
		pool = "crossbow", -- P2 of the Crossbow: cooldowns of the Crossbow's skills only (Logic/Crossbow.cdrFor)
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { reload = { 4, 12 } },
		passive = { hooks = { quickReload = "reload" } },
		glyph = "⟲",
	},
})
