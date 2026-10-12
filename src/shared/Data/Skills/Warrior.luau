--!strict
-- Warrior skills (DESIGN §14.2), Energy. Values are { rank 1, rank 10 } (passives: rank 5).
-- S73: breakpoint options A/B from ROZWOJ 10.2-10.5; unlock levels are still today's (paths: S75).
-- S74: six path skills (ROZWOJ 10.3-10.5) with `path`; their paths get a PathDef in S75, until then they are
-- unreachable (Logic/Paths) and hidden on the wiki.

local Build = require("./Build")

return Build.class("Warrior", "energy", "phys", {
	{
		id = "mightyStrike",
		unlock = 1,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 15,
		cooldown = 4,
		range = 8,
		values = { dmg = { 160, 295 } },
		breakpoints = Build.bp2({ a = { knockback = 6 }, b = { execute = 30 } }, {
			a = { splash = { radius = 6, pct = 50 } },
			-- no category (ROZWOJ 7.1); every strike renews it (no bleedStacks)
			b = { effect = { kind = "bleed", duration = 6, value = 90 } },
		}),
		glyph = "⚔",
	},
	{
		id = "battleCry",
		unlock = 3,
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 25,
		cooldown = 40,
		duration = 20,
		values = { atk = { 10, 28 } },
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
		id = "charge",
		unlock = 6,
		maxLevel = 10,
		type = "charge",
		delivery = "melee",
		cost = 20,
		cooldown = 12,
		range = 25,
		values = { dmg = { 120, 210 } },
		effects = { { kind = "stun", duration = 0.8 } },
		breakpoints = Build.bp2(
			{ a = { add = { range = 7 } }, b = { mul = { cooldown = 0.8 } } },
			{ a = { stunNear = { radius = 5, duration = 1 } }, b = { splash = { radius = 6, pct = 60 } } }
		),
		glyph = "➹",
	},
	{
		id = "bladeWhirl",
		unlock = 10,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 30,
		cooldown = 8,
		radius = 8,
		-- S28: two turns with three blows (the DESIGN total 110-200% split over the hits)
		hits = 3,
		interval = 0.2,
		values = { dmg = { 37, 67 } },
		breakpoints = Build.bp2(
			{ a = { castMove = 60 }, b = { lifesteal = 8 } },
			{ a = { pull = 12 }, b = { add = { hits = 1 }, values = { dmg = -7 } } } -- 4 x 60 % at rank 10
		),
		glyph = "🌀",
	},
	{
		id = "steelSkin",
		unlock = 14,
		maxLevel = 5,
		type = "passive",
		values = { armor = { 5, 25 } },
		passive = { pct = { armor = "armor" } },
		glyph = "⛨",
	},
	{
		id = "cleave",
		unlock = 18,
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 30,
		cooldown = 7,
		radius = 10,
		angle = 90,
		values = { dmg = { 140, 250 }, bleed = 30 },
		effects = { { kind = "bleed", duration = 5, value = "bleed" } },
		breakpoints = Build.bp2(
			{ a = { add = { angle = 30 } }, b = { values = { bleed = 20 } } },
			{ a = { bleedStacks = 3 }, b = { lifesteal = 12 } }
		),
		glyph = "🪓",
	},
	{
		id = "taunt",
		unlock = 23,
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
		id = "fortitude",
		unlock = 28,
		maxLevel = 5,
		type = "passive",
		values = { hp = { 4, 20 } },
		passive = { pct = { maxHp = "hp" } },
		glyph = "❤",
	},
	{
		id = "earthquake",
		unlock = 34,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 45,
		cooldown = 14,
		radius = 12,
		values = { dmg = { 150, 280 }, slow = 40 },
		effects = { { kind = "slow", duration = 3, value = "slow", category = "enemySlow" } },
		breakpoints = Build.bp2(
			-- S73: was pct = 20 (R4, ROZWOJ 10.2)
			{ a = { lingering = { pct = 5, duration = 3, kind = "cracks" } }, b = { pull = 10 } },
			-- S73: was pct = 60 (R4, ROZWOJ 10.2)
			{ a = { echo = { delay = 1, pct = 25 } }, b = { values = { dmg = 60 } } }
		),
		glyph = "⛰",
	},
	{
		id = "bloodlust",
		unlock = 40,
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 40,
		cooldown = 60,
		duration = 12,
		values = { speed = { 15, 35 }, lifesteal = 5 },
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
			b = { values = { speed = 8 } },
		}),
		glyph = "🩸",
	},
	{
		id = "riposte",
		unlock = 48,
		maxLevel = 5,
		type = "passive",
		values = { chance = { 4, 12 } },
		passive = { hooks = { riposte = "chance" } },
		glyph = "↺",
	},
	{
		id = "crushingBlow",
		unlock = 56,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 50,
		cooldown = 16,
		range = 8,
		values = { dmg = { 300, 520 }, armorBreak = 30 },
		effects = { { kind = "armorBreak", duration = 6, value = "armorBreak", category = "enemyArmor" } },
		breakpoints = Build.bp2(
			{ a = { effect = { kind = "stun", duration = 0.7 } }, b = { values = { dmg = 40 } } },
			{ a = { splash = { radius = 7, pct = 60 } }, b = { mul = { cooldown = 0.8 } } }
		),
		glyph = "🔨",
	},
	{
		id = "lastBastion",
		unlock = 65,
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
		id = "titansWrath",
		unlock = 75,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 80,
		cooldown = 45,
		radius = 14,
		hits = 3,
		interval = 0.45,
		values = { dmg = { 180, 320 } },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 3 } }, b = { values = { dmg = 25 } } },
			{ a = { stunLast = 1.2 }, b = { add = { hits = 1 }, values = { dmg = -25 } } } -- 4 x 295 % at rank 10
		),
		glyph = "⚡",
	},
	-- Guardian (unreachable until the guardian path has a PathDef, S75) ------------------------------------------
	{
		id = "intercept",
		path = "guardian",
		unlock = 26, -- row 4 (ROZWOJ 10.3)
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
	-- Berserker ---------------------------------------------------------------------------------------------------
	{
		id = "rend",
		path = "berserker",
		unlock = 26,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 25,
		cooldown = 10,
		range = 8,
		furyConsume = "furyDmg", -- consumes all Fury: +furyDmg % hit damage per stack (x1.8 at 10)
		values = { dmg = { 140, 250 }, bleed = 40, furyDmg = 8 },
		effects = { { kind = "bleed", duration = 6, value = "bleed" } },
		breakpoints = Build.bp2(
			{ a = { execute = 30 }, b = { lifesteal = 15 } },
			{ a = { values = { bleed = 30 } }, b = { splash = { radius = 6, pct = 50 } } }
		),
		glyph = "🗡",
	},
	{
		id = "carnage",
		path = "berserker",
		unlock = 60,
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 30,
		cooldown = 45,
		duration = 8,
		furyConsume = "perFury", -- consumes all Fury: +perFury % physical attack per stack (own)
		values = { perFury = { 1.5, 2.5 } },
		effects = {
			-- S72: no Fury decay, +2 per hit, a kill resets Charge and Blade Whirl
			{ kind = "carnage", duration = 8, target = "self", category = "own" },
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
	-- Standard-Bearer ---------------------------------------------------------------------------------------------
	{
		id = "warBanner",
		path = "standard",
		unlock = 26,
		maxLevel = 10,
		type = "banner",
		delivery = "melee",
		cost = 30,
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
		id = "advanceOrder",
		path = "standard",
		unlock = 60,
		maxLevel = 10,
		type = "shout",
		delivery = "melee",
		cost = 35,
		cooldown = 60,
		radius = 30, -- allies, the Standard-Bearer included (node Hetman's Order: +10 -> 40, S75)
		hitRadius = 10,
		duration = 10,
		values = { dmg = { 120, 220 }, crit = { 10, 20 } },
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
