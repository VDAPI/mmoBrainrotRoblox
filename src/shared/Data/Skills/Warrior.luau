--!strict
-- Warrior (docs/ROZWOJ.md 10): the class's skills. Energy. Values are { rank 1, rank 10 } (passives: rank 5).
-- Breakpoint options A/B: ROZWOJ 10.2-10.5 (S73). S143 (docs/DESIGN-18.md §6.2): two weapon pools on the shared ladder,
-- Sword and Shield (`onehand`: block, stuns, guarding the party) and Two-Handed (`twohand`: Fury, bleeds, big swings),
-- and the Warrior's common skills (Charge C1 4, Taunt C2 12, Battle Cry C3 30, Steel Skin C4 45); the old path skills
-- moved into the pools, the directions keep their capstones (row 8): Last Bastion (Guardian), Carnage (Berserker) and
-- Order to Advance (Standard-Bearer). The new skills follow the old ones (the `order` of the old ones stays).

local Build = require("./Build")
local Types = require("./Types")

local SHIELD = { offhand = { "shield" } }
-- S143: typed apart (luau-lsp rejects a literal list of effects of different shapes, like Hunter's S77)
local WAR_STOMP_EFFECTS: { Types.SkillEffect } = {
	{ kind = "stun", duration = 1, notBoss = true },
	{ kind = "attackSlow", duration = 4, value = "attackSlow", category = "enemyAttackSlow" },
}

return Build.class("Warrior", "energy", "phys", {
	-- The old base (ROZWOJ 10.2) ----------------------------------------------------------------------------------
	{
		id = "mightyStrike",
		pool = "onehand", -- S143: S1 of Sword and Shield (DESIGN-18 §6.2)
		role = "S1",
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
		role = "C1",
		unlock = 4, -- S143: 3 -> 4 (C1)
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
		pool = "twohand", -- S143: A2 of Two-Handed (was 6)
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 30,
		cooldown = 8,
		radius = 8,
		-- S28: two turns with three blows (the DESIGN total 110-200% split over the hits)
		hits = 3,
		interval = 0.2,
		-- S143: rank 1 at 26 keeps the old rank 6 at 26 (48.7); the S91 knots of ranks <= 20 are gone
		values = { dmg = { 48, 52 } },
		breakpoints = Build.bp2(
			{ a = { castMove = 60 }, b = { lifesteal = 8 } },
			{ a = { pull = 12 }, b = { add = { hits = 1 }, values = { dmg = -4 } } } -- 4 x 48 % at rank 10
		),
		glyph = "🌀",
	},
	{
		id = "taunt",
		pool = "common",
		role = "C2",
		unlock = 12, -- S143: 10 -> 12 (C2)
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
		role = "C4",
		unlock = 45, -- S143: 14 -> 45 (C4)
		maxLevel = 5,
		type = "passive",
		values = { armor = { 20, 25 } }, -- S143: rank 1 at 45 keeps the old rank 4 at 41 (20 %)
		passive = { pct = { armor = "armor" } },
		glyph = "⛨",
	},
	{
		id = "bloodlust",
		pool = "twohand", -- S143: O1 of Two-Handed (was 18)
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 40,
		cooldown = 60,
		duration = 12,
		-- S143: rank 3 (level 18) keeps the old rank 1, rank 4 (22) the old rank 2 (Data/SkillCurves)
		values = { speed = { 13, 20 }, lifesteal = 5 },
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
		pool = "onehand", -- S143: A2 of Sword and Shield (was 30)
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 45,
		cooldown = 14,
		radius = 12,
		values = { dmg = { 147, 175 }, slow = 40 }, -- S143: rank 2 (level 30) keeps the old rank 1 (Data/SkillCurves)
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
		pool = "onehand", -- S143: P2 of Sword and Shield (was 45)
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { chance = { 4, 12 } },
		passive = { hooks = { riposte = "chance" } },
		glyph = "↺",
	},
	-- The old Guardian skills (ROZWOJ 10.3) -----------------------------------------------------------------------
	{
		id = "fortitude",
		pool = "onehand", -- S143: P1 of Sword and Shield (was the Guardian's row 1): life and block
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		-- S143: rank 1 at 20 is 6 %, below the old rank 2 at 19 (8 %): with the new block points 8 % puts the Warrior's
		-- Elite fight at 20 below the S32 band; the block feeds Vindicate (Logic/Block)
		values = { hp = { 6, 20 }, block = { 1, 3 } },
		passive = { pct = { maxHp = "hp" }, hooks = { block = "block" } },
		glyph = "❤",
	},
	{
		id = "intercept",
		pool = "onehand", -- S143: O1 of Sword and Shield (was the Guardian's row 4)
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "guard",
		delivery = "melee",
		cost = 20,
		cooldown = { 16, 12 },
		range = 25,
		duration = 4,
		-- S143: rank 5 (level 26) keeps the old rank 1, rank 6 (30) the old rank 2 (Data/SkillCurves)
		values = { share = { 12, 30 }, guard = { 6, 15 } },
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
		unlock = 60, -- capstone, row 8 (S143: was row 7)
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 40,
		cooldown = 90,
		duration = 6,
		values = { reduction = { 46.7, 60 } }, -- S143: rank 1 at 60 keeps the old rank 4 at 60
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
		pool = "onehand", -- S143: U of Sword and Shield (was the Guardian's capstone)
		role = "U",
		unlock = 60,
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
	-- The old Berserker skills (ROZWOJ 10.4) ----------------------------------------------------------------------
	{
		id = "cleave",
		pool = "twohand", -- S143: A1 of Two-Handed (was the Berserker's row 1)
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 30,
		cooldown = 7,
		radius = 10,
		angle = 90,
		-- S143: rank 5 (level 19) keeps the old rank 3 (level 18, 164.4), rank 3 (11) about the old rank 1 at 10
		values = { dmg = { 115, 168 }, bleed = 30 },
		effects = { { kind = "bleed", duration = 5, value = "bleed" } },
		breakpoints = Build.bp2(
			{ a = { add = { angle = 30 } }, b = { values = { bleed = 20 } } },
			{ a = { bleedStacks = 3 }, b = { lifesteal = 12 } }
		),
		glyph = "🪓",
	},
	{
		id = "rend",
		pool = "twohand", -- S143: S2 of Two-Handed (was the Berserker's row 4)
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 25,
		cooldown = 10,
		range = 8,
		furyConsume = "furyDmg", -- consumes all Fury: +furyDmg % hit damage per stack (x1.6 at 10, S89)
		-- S143: rank 1 at 15 (was 26) 200 for the S91 band at 20, rank 10 280 (rank 4 at 27 = 226.7)
		values = { dmg = { 200, 280 }, bleed = 10, furyDmg = 6 },
		effects = { { kind = "bleed", duration = 6, value = "bleed" } },
		breakpoints = Build.bp2(
			{ a = { execute = 30 }, b = { lifesteal = 15 } },
			{ a = { values = { bleed = 70 } }, b = { splash = { radius = 6, pct = 50 } } }
		),
		glyph = "🗡",
	},
	{
		id = "titansWrath",
		pool = "twohand", -- S143: U of Two-Handed (was the Berserker's row 7)
		role = "U",
		unlock = 60,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 80,
		cooldown = 45,
		radius = 14,
		hits = 3,
		interval = 0.45,
		values = { dmg = { 120, 150 } }, -- S143: rank 1 at 60 keeps the old rank 4 at 60 (120)
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
	-- The old Standard-Bearer skills (ROZWOJ 10.5) ----------------------------------------------------------------
	{
		id = "battleCry",
		pool = "common", -- S143: C3 of the Warrior (was the Standard-Bearer's row 1)
		role = "C3",
		unlock = 30,
		maxLevel = 10,
		type = "buff",
		delivery = "melee",
		cost = 25,
		cooldown = 40,
		duration = 20,
		values = { atk = { 14.9, 16 } }, -- S143: rank 1 at 30 keeps the old rank 6 at 30 (14.9)
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
		pool = "onehand", -- S143: K2 of Sword and Shield (was the Standard-Bearer's row 4)
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "banner",
		delivery = "melee",
		cost = 15,
		cooldown = 30,
		range = 12, -- planted up to 12 studs away (no aim: at the feet)
		radius = 15,
		duration = 12, -- the banner's life; circle effects are pulses refreshed every second (their 1.5 s is nominal)
		values = { haste = { 5.5, 10 } }, -- S143: rank 1 at 33 keeps the old rank 2 at 30 (5.5)
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
		pool = "onehand", -- S143: S2 of Sword and Shield (was the Standard-Bearer's row 7)
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 35,
		cooldown = 16,
		range = 8,
		-- S143: rank 9 (level 47) keeps the old rank 1 at 48 (300), rank 10 (51) the old rank 2 (Data/SkillCurves);
		-- ranks <= 20 for the S91 band
		values = { dmg = { 220, 324.4 }, armorBreak = 40 },
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
	-- S143 (DESIGN-18 §6.2): the new skills of Sword and Shield -----------------------------------------------------
	-- Shield Sweep: a wide sweep of the shield's edge, pushes the struck back; harder with a shield on the arm.
	{
		id = "shieldSweep",
		pool = "onehand",
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 25,
		cooldown = 7,
		radius = 6,
		angle = 100,
		knockback = 4,
		values = { dmg = { 100, 160 }, shieldDmg = 20 }, -- shieldDmg: % more with a shield (Logic/Block.shieldMul)
		breakpoints = Build.bp2(
			{ a = { add = { angle = 40 } }, b = { values = { dmg = 18 } } },
			{ a = { effect = { kind = "stun", duration = 0.8, notBoss = true } }, b = { values = { dmg = 36 } } }
		),
		glyph = "◗",
	},
	-- Shield Bash: the shield's face in one enemy's head, a 1.5 s stun; needs a shield.
	{
		id = "shieldBash",
		pool = "onehand",
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 20,
		cooldown = 12,
		range = 8,
		weapon = SHIELD,
		values = { dmg = { 70, 130 } },
		effects = { { kind = "stun", duration = 1.5, notBoss = true } },
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 0.5 } }, b = { values = { dmg = 14 } } },
			{ a = { mul = { cooldown = 0.8 } }, b = { values = { dmg = 32 } } }
		),
		glyph = "⬣",
	},
	-- Vindicate: the finisher of the shield: +perBlock % for each block of the last 6 s (at most 3, Logic/Block).
	{
		id = "vindicate",
		pool = "onehand",
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 30,
		cooldown = 10,
		range = 8,
		values = { dmg = { 200, 300 }, perBlock = 15 },
		breakpoints = Build.bp2(
			{ a = { values = { perBlock = 5 } }, b = { values = { dmg = 30 } } },
			{ a = { splash = { radius = 6, pct = 50 } }, b = { values = { dmg = 66 } } }
		),
		glyph = "⚖",
	},
	-- S143 (DESIGN-18 §6.2): the new skills of Two-Handed ----------------------------------------------------------
	-- Brutal Strike: the heavy two-handed blow that feeds Rage's Fury twice as fast (furyGain).
	{
		id = "brutalStrike",
		pool = "twohand",
		role = "S1",
		unlock = 1,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 15,
		cooldown = 4,
		range = 8,
		furyGain = 2,
		values = { dmg = { 136, 222 } }, -- like Mighty Strike (knots in Data/SkillCurves)
		breakpoints = Build.bp2(
			{ a = { execute = 30 }, b = { values = { dmg = 28 } } },
			{ a = { splash = { radius = 6, pct = 50 } }, b = { values = { dmg = 50 } } }
		),
		glyph = "✊",
	},
	-- Sunder: breaks the target's armour (enemyArmor) and slows it.
	{
		id = "sunder",
		pool = "twohand",
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 20,
		cooldown = 12,
		range = 8,
		values = { dmg = { 60, 110 }, armorBreak = { 10, 20 }, slow = 30 },
		effects = {
			{ kind = "armorBreak", duration = 6, value = "armorBreak", category = "enemyArmor" },
			{ kind = "slow", duration = 3, value = "slow", category = "enemySlow" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { values = { dmg = 15 } } },
			{ a = { values = { armorBreak = 10 } }, b = { values = { dmg = 34 } } }
		),
		glyph = "✖",
	},
	-- Rage: the two-handed school's passive. Fury exists only with it (Logic/Fury.cap): Rage alone holds `fury` stacks,
	-- the Berserker's Fury nodes raise the cap (at most HOOK_RULES.fury.maxStacks), every stack +perStack % damage.
	{
		id = "rage",
		pool = "twohand",
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		values = { fury = 6, perStack = { 0.2, 0.5 } },
		passive = { hooks = { rage = "fury", furyMax = "fury", furyDamage = "perStack" } },
		glyph = "♨",
	},
	-- War Stomp: a stamp that stuns the enemies around for 1 s (bosses and Elite II: slower attacks instead).
	{
		id = "warStomp",
		pool = "twohand",
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 35,
		cooldown = 18,
		radius = 6,
		values = { dmg = { 60, 110 }, attackSlow = 20 }, -- S143: at the enemyAttackSlow cap (Data/BuffCategories)
		effects = WAR_STOMP_EFFECTS,
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { values = { dmg = 12 } } },
			{ a = { add = { effectDuration = 0.5 } }, b = { values = { dmg = 26 } } }
		),
		glyph = "⇊",
	},
	-- Execute: the two-handed finisher: x2 below 30 % HP, spends all Fury (+furyDmg % per stack).
	{
		id = "execute",
		pool = "twohand",
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "target",
		delivery = "melee",
		cost = 25,
		cooldown = 10,
		range = 8,
		finisher = { hp = 30, mul = 2 },
		furyConsume = "furyDmg",
		values = { dmg = { 180, 260 }, furyDmg = 4 },
		breakpoints = Build.bp2(
			{ a = { execute = 30 }, b = { values = { dmg = 26 } } },
			{ a = { lifesteal = 15 }, b = { values = { furyDmg = 3 } } }
		),
		glyph = "⚚",
	},
	-- Unstoppable: at full Fury the Warrior shrugs off stuns and knockbacks and takes guard % less damage (own).
	{
		id = "unstoppable",
		pool = "twohand",
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { immune = 1, guard = { 3, 9 } },
		passive = { hooks = { unstoppable = "immune", furyGuard = "guard" } },
		glyph = "▲",
	},
})
