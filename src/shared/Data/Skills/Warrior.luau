--!strict
-- Warrior (docs/ROZWOJ.md 10): base 8 and the skills of the guardian, berserker and standard paths.
-- Energy. Values are { rank 1, rank 10 } (passives: rank 5). Breakpoint options A/B: ROZWOJ 10.2-10.5 (S73).

local Build = require("./Build")

return Build.class("Warrior", "energy", "phys", {
	-- Base (ROZWOJ 10.2) ------------------------------------------------------------------------------------------
	{
		id = "mightyStrike",
		pool = "common", -- S137 (DESIGN-18 §4.2)
		unlock = 1,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 15,
		cooldown = 4,
		range = 8,
		values = { dmg = { 136, 222 } }, -- S91: rank 1 160 -> 136 (ranks <= 20, Data/SkillCurves)
		breakpoints = Build.bp2({ a = { knockback = 6 }, b = { execute = 30 } }, {
			a = { splash = { radius = 6, pct = 50 } },
			-- no category (ROZWOJ 7.1); every strike renews it (no bleedStacks)
			b = { effect = { kind = "bleed", duration = 6, value = 45 } },
		}),
		glyph = "⚔",
	},
	{
		id = "charge",
		pool = "common",
		unlock = 3,
		maxLevel = 10,
		type = "charge",
		delivery = "melee",
		cost = 20,
		cooldown = 12,
		range = 25,
		values = { dmg = { 102, 165 } }, -- S91: rank 1 120 -> 102 (ranks <= 20, Data/SkillCurves)
		effects = { { kind = "stun", duration = 0.8 } },
		breakpoints = Build.bp2(
			{ a = { add = { range = 7 } }, b = { mul = { cooldown = 0.88 } } }, -- S91: 5B 0.8 -> 0.88 (R4)
			{ a = { stunNear = { radius = 5, duration = 1 } }, b = { splash = { radius = 6, pct = 60 } } }
		),
		glyph = "➹",
	},
	{
		id = "bladeWhirl",
		pool = "common",
		unlock = 6,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 30,
		cooldown = 8,
		radius = 8,
		-- S28: two turns with three blows (the DESIGN total 110-200% split over the hits)
		hits = 3,
		interval = 0.2,
		values = { dmg = { 33, 52 } }, -- S91: rank 1 37 -> 33 (ranks <= 20, Data/SkillCurves)
		breakpoints = Build.bp2(
			{ a = { castMove = 60 }, b = { lifesteal = 8 } },
			{ a = { pull = 12 }, b = { add = { hits = 1 }, values = { dmg = -4 } } } -- 4 x 48 % at rank 10
		),
		glyph = "🌀",
	},
	{
		id = "taunt",
		pool = "common",
		unlock = 10,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 20,
		cooldown = 20,
		radius = 15,
		values = { armor = { 20, 40 } },
		effects = {
			{ kind = "taunt", duration = 6 },
			{
				kind = "statBuff",
				duration = 6,
				stats = { armor = "armor" },
				pct = true,
				target = "self",
				category = "own",
			},
		},
		breakpoints = Build.bp2({ a = { add = { radius = 5 } }, b = { selfHeal = 8 } }, {
			a = { effect = { kind = "slow", duration = 4, value = 30, category = "enemySlow" } },
			b = { add = { effectDuration = 3 } }, -- taunt and armor 9 s
		}),
		glyph = "❗",
	},
	{
		id = "steelSkin",
		pool = "common",
		unlock = 14,
		maxLevel = 5,
		type = "passive",
		values = { armor = { 5, 25 } },
		passive = { pct = { armor = "armor" } },
		glyph = "⛨",
	},
	{
		id = "bloodlust",
		pool = "common",
		unlock = 18,
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 40,
		cooldown = 60,
		duration = 12,
		values = { speed = { 15, 20 }, lifesteal = 5 },
		effects = {
			{
				kind = "statBuff",
				duration = 12,
				stats = { atkSpeed = "speed", lifesteal = "lifesteal" },
				target = "self",
				category = "own",
			},
		},
		breakpoints = Build.bp2({ a = { values = { lifesteal = 3 } }, b = { add = { effectDuration = 2 } } }, {
			a = {
				selfEffect = {
					kind = "damageReduction",
					duration = 12,
					value = 15,
					target = "self",
					category = "own",
				},
			},
			b = { values = { speed = 4 } },
		}),
		glyph = "🩸",
	},
	{
		id = "earthquake",
		pool = "common",
		unlock = 30,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 45,
		cooldown = 14,
		radius = 12,
		values = { dmg = { 150, 175 }, slow = 40 },
		effects = { { kind = "slow", duration = 3, value = "slow", category = "enemySlow" } },
		breakpoints = Build.bp2(
			-- S73: was pct = 20 (R4, ROZWOJ 10.2)
			{ a = { lingering = { pct = 5, duration = 3, kind = "cracks" } }, b = { pull = 10 } },
			-- S73: was pct = 60 (R4, ROZWOJ 10.2)
			{ a = { echo = { delay = 1, pct = 25 } }, b = { values = { dmg = 38 } } }
		),
		glyph = "⛰",
	},
	{
		id = "riposte",
		pool = "common",
		unlock = 45,
		maxLevel = 5,
		type = "passive",
		values = { chance = { 4, 12 } },
		passive = { hooks = { riposte = "chance" } },
		glyph = "↺",
	},
	-- Guardian (ROZWOJ 10.3) --------------------------------------------------------------------------------------
	{
		id = "fortitude",
		path = "guardian",
		unlock = 10, -- row 1
		maxLevel = 5,
		type = "passive",
		values = { hp = { 4, 20 } },
		passive = { pct = { maxHp = "hp" } },
		glyph = "❤",
	},
	{
		id = "intercept",
		path = "guardian",
		unlock = 26, -- row 4
		maxLevel = 10,
		type = "guard",
		delivery = "melee",
		cost = 20,
		cooldown = { 16, 12 },
		range = 25,
		duration = 4,
		values = { share = { 20, 30 }, guard = { 10, 15 } },
		effects = {
			{ kind = "intercept", duration = 4, value = "share", target = "allies" }, -- no category (ROZWOJ 7.1)
			-- the self variant (nobody to protect)
			{ kind = "damageReduction", duration = 4, value = "guard", target = "self", category = "own" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { stunNear = { radius = 6, duration = 1 } } },
			{ a = { secondTarget = 100 }, b = { tauntNear = { radius = 8, duration = 3 } } }
		),
		glyph = "⇄",
	},
	{
		id = "lastBastion",
		path = "guardian",
		unlock = 48, -- row 7
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 40,
		cooldown = 90,
		duration = 6,
		values = { reduction = { 40, 60 } },
		effects = {
			{ kind = "damageReduction", duration = 6, value = "reduction", target = "self", category = "own" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { values = { reduction = 8 } } },
			{ a = { selfHeal = 15 }, b = { mul = { cooldown = 0.75 } } }
		),
		glyph = "🛡",
	},
	{
		id = "shieldWall",
		path = "guardian",
		unlock = 60, -- capstone, row 8
		maxLevel = 10,
		type = "shout",
		delivery = "melee",
		cost = 40,
		cooldown = 60,
		radius = 15, -- allies
		hitRadius = 15, -- enemies (bosses too) taunted
		duration = 6,
		values = { share = { 15, 25 }, reduction = { 20, 30 } },
		effects = {
			{ kind = "taunt", duration = 3 }, -- enemies within hitRadius
			{ kind = "intercept", duration = 6, value = "share", target = "allies" },
			{ kind = "damageReduction", duration = 6, value = "reduction", target = "self", category = "own" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { cleanse = true } },
			{ a = { add = { radius = 5 } }, b = { selfHeal = 15 } }
		),
		glyph = "🧱",
	},
	-- Berserker (ROZWOJ 10.4) -------------------------------------------------------------------------------------
	{
		id = "cleave",
		path = "berserker",
		unlock = 10, -- row 1
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 30,
		cooldown = 7,
		radius = 10,
		angle = 90,
		values = { dmg = { 140, 168 }, bleed = 30 },
		effects = { { kind = "bleed", duration = 5, value = "bleed" } },
		breakpoints = Build.bp2(
			{ a = { add = { angle = 30 } }, b = { values = { bleed = 20 } } },
			{ a = { bleedStacks = 3 }, b = { lifesteal = 12 } }
		),
		glyph = "🪓",
	},
	{
		id = "rend",
		path = "berserker",
		unlock = 26, -- row 4
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 25,
		cooldown = 10,
		range = 8,
		furyConsume = "furyDmg", -- consumes all Fury: +furyDmg % hit damage per stack (x1.6 at 10, S89)
		values = { dmg = { 280, 280 }, bleed = 10, furyDmg = 6 },
		effects = { { kind = "bleed", duration = 6, value = "bleed" } },
		breakpoints = Build.bp2(
			{ a = { execute = 30 }, b = { lifesteal = 15 } },
			{ a = { values = { bleed = 70 } }, b = { splash = { radius = 6, pct = 50 } } }
		),
		glyph = "🗡",
	},
	{
		id = "titansWrath",
		path = "berserker",
		unlock = 48, -- row 7
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 80,
		cooldown = 45,
		radius = 14,
		hits = 3,
		interval = 0.45,
		values = { dmg = { 105, 150 } },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 3 } }, b = { values = { dmg = 18 } } },
			{ a = { stunLast = 1.2 }, b = { add = { hits = 1 }, values = { dmg = -15 } } } -- 4 x 135 % at rank 10
		),
		glyph = "⚡",
	},
	{
		id = "carnage",
		path = "berserker",
		unlock = 60, -- capstone, row 8
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 30,
		cooldown = 45,
		duration = 8,
		furyConsume = "perFury", -- consumes all Fury: +perFury % physical attack per stack (own)
		-- Fury restored when Carnage ends: berserker_carnage2, S75
		values = { perFury = { 0.6, 0.9 }, furyRestore = 0 },
		-- S72: no Fury decay, +2 per hit, a kill resets Charge and Blade Whirl
		effects = {
			{ kind = "carnage", duration = 8, value = "furyRestore", target = "self", category = "own" } :: any,
			-- S73: the furyConsume field counts once per Fury stack the cast consumed (Skills/Context.applyEffect)
			{
				kind = "statBuff",
				duration = 8,
				stats = { physAtk = "perFury" },
				pct = true,
				target = "self",
				category = "own",
			},
		},
		breakpoints = Build.bp2({ a = { add = { effectDuration = 2 } }, b = { selfHeal = 10 } }, {
			a = { values = { perFury = 0.5 } },
			b = {
				selfEffect = { kind = "damageReduction", duration = 8, value = 15, target = "self", category = "own" },
			},
		}),
		glyph = "💀",
	},
	-- Standard-Bearer (ROZWOJ 10.5) -------------------------------------------------------------------------------
	{
		id = "battleCry",
		path = "standard",
		unlock = 10, -- row 1
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 25,
		cooldown = 40,
		duration = 20,
		values = { atk = { 10, 16 } },
		effects = {
			{
				kind = "statBuff",
				duration = 20,
				stats = { physAtk = "atk" },
				pct = true,
				target = "self",
				category = "own",
			},
		},
		breakpoints = Build.bp2({
			a = {
				selfEffect = {
					kind = "statBuff",
					duration = 20,
					stats = { armor = "armorBp" },
					pct = true,
					target = "self",
					category = "own",
				},
				values = { armorBp = 12 },
			},
			b = { values = { atk = 3 } },
		}, {
			a = { mul = { cooldown = 0.75 } }, -- S73: was 0.6 (R4, ROZWOJ 10.5)
			b = {
				add = { effectDuration = 4 }, -- the own attack bonus 20 -> 24 s
				-- Same key as the cry's own statBuff (S53 merges stats, longer time wins), so it lasts as long as the cry.
				selfEffect = {
					kind = "statBuff",
					duration = 20,
					stats = { atkSpeed = "speedBp" },
					pct = true,
					target = "self",
					category = "own",
				},
				values = { speedBp = 10 },
			},
		}),
		glyph = "📣",
	},
	{
		id = "warBanner",
		path = "standard",
		unlock = 26, -- row 4
		maxLevel = 10,
		type = "banner",
		delivery = "melee",
		cost = 15,
		cooldown = 30,
		range = 12, -- planted up to 12 studs away (no aim: at the feet)
		radius = 15,
		duration = 12, -- the banner's life; circle effects are pulses refreshed every second (their 1.5 s is nominal)
		values = { haste = { 5, 10 } },
		effects = {
			{
				kind = "statBuff",
				duration = 1.5,
				stats = { atkSpeed = "haste" },
				pct = true,
				target = "allies",
				category = "allyHaste",
			},
		},
		breakpoints = Build.bp2({
			a = { add = { radius = 5 } },
			b = { allyEffect = { kind = "hot", hpPct = 1.5, duration = 1.5, target = "allies" } },
		}, {
			a = { add = { duration = 3 } },
			b = { effect = { kind = "slow", duration = 1.5, value = 20, category = "enemySlow" } },
		}),
		glyph = "🚩",
	},
	{
		id = "crushingBlow",
		path = "standard",
		unlock = 48, -- row 7
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 35,
		cooldown = 16,
		range = 8,
		values = { dmg = { 300, 520 }, armorBreak = 40 },
		effects = { { kind = "armorBreak", duration = 6, value = "armorBreak", category = "enemyArmor" } },
		breakpoints = Build.bp2(
			{ a = { effect = { kind = "stun", duration = 0.7 } }, b = { values = { dmg = 48 } } },
			{ a = { splash = { radius = 7, pct = 60 } }, b = { mul = { cooldown = 0.8 } } }
		),
		glyph = "🔨",
	},
	{
		id = "advanceOrder",
		path = "standard",
		unlock = 60, -- capstone, row 8
		maxLevel = 10,
		type = "shout",
		delivery = "melee",
		cost = 20,
		cooldown = 60,
		radius = 30, -- allies, the Standard-Bearer included (node Hetman's Order: +10 -> 40, S75)
		hitRadius = 10,
		duration = 10,
		values = { dmg = { 120, 220 }, crit = { 12, 24 } },
		effects = {
			-- critChance in points (allyCrit)
			{
				kind = "statBuff",
				duration = 10,
				stats = { critChance = "crit" },
				target = "allies",
				category = "allyCrit",
			},
		},
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { pull = 10 } },
			{ a = { values = { crit = 5 } }, b = { cleanse = true } }
		),
		glyph = "📯",
	},
})
