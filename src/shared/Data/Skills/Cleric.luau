--!strict
-- Cleric (docs/ROZWOJ.md 9): the class's skills. Mana. Values are { rank 1, rank 10 } (passives: rank 5). Heals and
-- shields from target max HP (S69). Heals and buffs only work on the caster and party members.
-- S145 (docs/DESIGN-18.md §6.4): two weapon pools on the shared ladder, Scepter and Staff (`light`: heals, shields,
-- fields) and Mace and Flail (`hammer`: melee light, brands, weakening), and the Cleric's common skills (Heal C1 4,
-- Circle of Light C2 12, Resurrection C3 30, Devotion C4 45); the old path skills moved into the pools, the directions
-- keep four skills: Prayer (the Healer's row 4) and Divine Intervention (the Healer's capstone, row 8), Roll of the
-- Dice (Fortune's row 4) and Wheel of Fortune (Fortune's capstone, row 8). The new skills follow the old ones (the
-- `order` of the old ones stays). Cleric school rules: Logic/Faith (Light Ray's heal, Guiding Light's ward, Zeal, the
-- wandering brand, Rebuke's interrupt); a root that turns into a slow on bosses: Logic/Snare (SkillEffect.bossSlow).

local Build = require("./Build")
local Types = require("./Types")

-- S70 (ROZWOJ 9.4): the three faces of Fortune's dice (value fields crit, haste, regen), `duration` s each; a typed
-- list, the face entries have different shapes.
local function diceFaces(duration: number, extra: Types.SkillEffect?): { Types.SkillEffect }
	local list: { Types.SkillEffect } = {
		{
			kind = "statBuff",
			face = "blade",
			duration = duration,
			stats = { critChance = "crit" },
			target = "allies",
			category = "allyCrit",
		},
		{
			kind = "statBuff",
			face = "wind",
			duration = duration,
			stats = { atkSpeed = "haste" },
			pct = true,
			target = "allies",
			category = "allyHaste",
		},
		{ kind = "hot", face = "spring", duration = duration, value = "regen", target = "allies" },
	}
	if extra then
		table.insert(list, extra)
	end
	return list
end

-- S145: Blinding Light's misses (category enemyMiss, capped at 15 % by Data/BuffCategories, S61)
local BLIND_EFFECTS: { Types.SkillEffect } =
	{ { kind = "misfortune", duration = 3, value = "miss", category = "enemyMiss" } }
-- S145 (Logic/Snare): Holy Chains root; on bosses and Elite IIs a slow of values.slow % for the same time
local CHAINS_EFFECTS: { Types.SkillEffect } = { { kind = "root", duration = 2, bossSlow = "slow" } }

return Build.class("Cleric", "mana", "magic", {
	-- The old base (ROZWOJ 9.2) ----------------------------------------------------------------------------------
	{
		id = "holyStrike",
		pool = "hammer", -- S145: S1 of Mace and Flail (DESIGN-18 §6.4)
		role = "S1",
		unlock = 1,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 12,
		cooldown = 3,
		range = 12,
		holy = true,
		values = { dmg = { 167, 340 } }, -- S91: rank 1 190 -> 167 (ranks <= 20, Data/SkillCurves)
		breakpoints = Build.bp2(
			{ a = { splash = { radius = 5, pct = 40 } }, b = { execute = 30 } },
			{ a = { effect = { kind = "stun", duration = 0.8 } }, b = { healWounded = 30 } }
		),
		glyph = "✚",
	},
	{
		id = "heal",
		pool = "common",
		role = "C1",
		unlock = 4, -- S145: 3 -> 4 (C1)
		maxLevel = 10,
		type = "heal",
		delivery = "ranged",
		cost = 12, -- S91: 20 -> 12 (T-SK6 Grimrok: at 20 the Holy Strikes at 12 took every mana point of the heals)
		cooldown = 3,
		range = 30,
		values = { healHp = { 16, 18 }, healMag = { 8, 12 } },
		breakpoints = Build.bp2(
			{ a = { secondTarget = 50 }, b = { selfHeal = 6 } },
			{ a = { overhealShield = true }, b = { chainHeal = { jumps = 2, pct = 60 } } }
		),
		glyph = "✙",
	},
	{
		id = "radiance",
		pool = "light", -- S145: A1 of Scepter and Staff (was 6)
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 35,
		cooldown = 10,
		radius = 10,
		holy = true,
		-- S145: rank 5 (level 19) keeps the old rank 4 (level 18), rank 6 (23) the old rank 5 (22; Data/SkillCurves)
		values = { dmg = { 120, 240 }, heal = 50 },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 3 } }, b = { pull = 16 } },
			{ a = { values = { heal = 50 } }, b = { echo = { delay = 1, pct = 25 } } }
		),
		glyph = "☀",
	},
	{
		id = "devotion",
		pool = "common",
		role = "C4",
		unlock = 45, -- S145: 10 -> 45 (C4)
		maxLevel = 5,
		type = "passive",
		-- S145: rank 1 at 45 = the old rank 4 at 37; S146: 20-25 -> 6-9 (T-SK5 of the light pool at 95-100 <= 0.35)
		values = { heal = { 6, 9 } },
		passive = { hooks = { healBonus = "heal" } },
		glyph = "🙏",
	},
	{
		id = "circleOfLight",
		pool = "common",
		role = "C2",
		unlock = 12, -- S145: 14 -> 12 (C2); rank 3 (level 20) keeps the old rank 2 (18, Data/SkillCurves)
		maxLevel = 10,
		type = "groupHeal",
		delivery = "melee",
		cost = 50,
		cooldown = 15,
		radius = 14,
		values = { healHp = { 8, 12 }, healMag = { 6, 10 } },
		breakpoints = Build.bp2({ a = { cleanse = true }, b = { add = { radius = 4 } } }, {
			a = {
				allyEffect = {
					kind = "damageReduction",
					duration = 4,
					value = 15,
					target = "allies",
					category = "allyGuard",
				},
			},
			b = { healZone = { duration = 4, pct = 6 } },
		}),
		glyph = "◌",
	},
	{
		id = "shieldOfFaith",
		pool = "light", -- S145: O1 of Scepter and Staff (was 18); rank 3 (level 18) keeps the old rank 1
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "shield",
		delivery = "ranged",
		cost = 40,
		cooldown = 20,
		range = 30,
		duration = 8,
		values = { shieldHp = { 10, 18 }, shieldMag = { 8, 15 } },
		breakpoints = Build.bp2(
			{ a = { values = { shieldHp = 3 } }, b = { cleanse = true } },
			{ a = { secondTarget = 50 }, b = { add = { duration = 6 }, values = { shieldHp = 7 } } }
		),
		glyph = "🛡",
	},
	{
		id = "divineWrath",
		pool = "hammer", -- S145: P1 of Mace and Flail (was 30); rank 2 (level 29) keeps the old rank 1 (30)
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		values = { bonus = { 2, 22 } }, -- S146: rank 5 20 -> 22 (rank 4 pinned, Data/SkillCurves)
		passive = { hooks = { holyDamage = "bonus", holyStrikeHeal = "bonus" } },
		glyph = "⚜",
	},
	{
		id = "judgement",
		pool = "hammer", -- S145: S3 of Mace and Flail (was 45); rank 2 (level 44) keeps the old rank 1 (45)
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 55,
		cooldown = 15,
		range = 14,
		holy = true,
		values = { dmg = { 270, 580 } }, -- S146: rank 1 300 -> 270, rank 2 320 -> 290 (Data/SkillCurves)
		effects = { { kind = "stun", duration = 1 } },
		breakpoints = Build.bp2({ a = { lifesteal = 30 }, b = { stunNear = { radius = 6, duration = 0.8 } } }, {
			a = { effect = { kind = "vulnerability", duration = 6, value = 10, category = "enemyWeak" } },
			b = { values = { dmg = 100 } },
		}),
		glyph = "⚖",
	},
	-- The old Healer skills (ROZWOJ 9.3) ---------------------------------------------------------------------------
	{
		id = "renew",
		pool = "light", -- S145: S2 of Scepter and Staff (was the Healer's row 1)
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "hot",
		delivery = "ranged",
		cost = 25,
		cooldown = 8,
		range = 30,
		duration = 10,
		-- S145: rank 1 at 15 = the old rank 2 at 14
		values = { healHp = { 16.89, 24 }, healMag = { 10.56, 15 } },
		breakpoints = Build.bp2(
			{ a = { add = { duration = 4 } }, b = { secondTarget = 50 } },
			{ a = { cleanse = true }, b = { values = { healHp = 6 } } }
		),
		glyph = "❦",
	},
	{
		id = "sanctuary",
		pool = "light", -- S145: A2 of Scepter and Staff (was the Healer's row 4, 26)
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "healZone",
		delivery = "ranged",
		cost = 45,
		cooldown = 18,
		range = 30,
		radius = 10,
		duration = 6,
		values = { healHp = { 2, 3.2 }, healMag = { 2, 3 } },
		breakpoints = Build.bp2({ a = { add = { radius = 3 } }, b = { cleanse = true } }, {
			a = { add = { duration = 2 } },
			b = {
				allyEffect = {
					kind = "damageReduction",
					duration = 1.5,
					value = 10,
					target = "allies",
					category = "allyGuard",
				},
			},
		}),
		glyph = "❂",
	},
	{
		id = "divineIntervention",
		path = "healer",
		unlock = 60, -- the Healer's capstone, row 8 (S145: was row 7, 48)
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 100,
		cooldown = 120,
		radius = 30,
		-- S145: rank 1 at 60 near the old rank 4 at 60
		values = { invuln = { 2.5, 4 }, heal = 30 },
		effects = { { kind = "invuln", duration = { 2.5, 4 }, target = "allies" } },
		breakpoints = Build.bp2({ a = { values = { heal = 15 } }, b = { cleanse = true } }, {
			a = { add = { radius = 10 } },
			b = {
				allyEffect = {
					kind = "damageReduction",
					duration = 7,
					value = 25,
					target = "allies",
					category = "allyGuard",
				},
			},
		}),
		glyph = "☩",
	},
	{
		id = "guardianAngel",
		pool = "light", -- S145: U of Scepter and Staff (was the Healer's capstone)
		role = "U",
		unlock = 60,
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 80,
		cooldown = { 120, 90 },
		radius = 30,
		values = { saveHeal = { 15, 25 } },
		effects = { { kind = "guardianAngel", duration = { 6, 8 }, value = "saveHeal", target = "allies" } },
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { add = { radius = 10 } } },
			{ a = { values = { saveHeal = 15 } }, b = { mul = { cooldown = 0.75 } } }
		),
		glyph = "✟",
	},
	-- The old Priest of Fortune skills (ROZWOJ 9.4) ----------------------------------------------------------------
	{
		id = "resurrection",
		pool = "common", -- S145: C3 of the Cleric (was Fortune's row 1)
		role = "C3",
		unlock = 30,
		maxLevel = 10,
		type = "resurrect",
		delivery = "ranged",
		cost = 80,
		cooldown = { 86.67, 60 }, -- S145: rank 1 at 30 = the old rank 6 at 30
		range = 30,
		values = { hp = { 42.22, 60 } },
		breakpoints = Build.bp2(
			{ a = { values = { hp = 20 } }, b = { mul = { cooldown = 0.7 } } },
			{ a = { allyEffect = { kind = "invuln", duration = 3, target = "allies" } }, b = { values = { hp = 25 } } }
		),
		glyph = "✝",
	},
	{
		id = "fortuneDice",
		path = "fortune",
		unlock = 26,
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 40,
		cooldown = 24,
		radius = 30,
		roll = {},
		values = { crit = { 4, 8 }, haste = { 6, 12 }, regen = { 1, 2 }, boost = 0 },
		effects = diceFaces(15),
		breakpoints = Build.bp2(
			{ a = { values = { crit = 1, haste = 2, regen = 0.2 } }, b = { add = { radius = 10 } } },
			{ a = { values = { crit = 2, haste = 3, regen = 0.4 } }, b = { rollDouble = 30 } }
		),
		glyph = "⚄",
	},
	{
		id = "prayer",
		path = "healer", -- S145: the Healer's row 4 (was Fortune's row 7, 48); its 5B dice work without Roll of the Dice
		unlock = 26,
		maxLevel = 10,
		type = "channel",
		delivery = "melee",
		cost = 0,
		cooldown = 90,
		duration = 3,
		values = { mana = { 20, 45 }, group = 5 }, -- S145: rank 1 25 -> 20 (from 26, was 48)
		breakpoints = Build.bp2(
			{ a = { mul = { cooldown = 0.75 } }, b = { roll = { half = true } } },
			{ a = { values = { group = 5 } }, b = { steadfast = true } }
		),
		glyph = "🕯",
	},
	{
		id = "wheelOfFortune",
		path = "fortune",
		unlock = 60,
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 80,
		cooldown = 90,
		radius = 30,
		roll = { all = true, enemyRadius = 15 },
		values = { crit = { 6, 10 }, haste = { 8, 15 }, regen = { 1.5, 2.5 }, boost = 50, miss = { 10, 15 } },
		effects = diceFaces(
			10,
			{ kind = "misfortune", duration = 10, value = "miss", target = "enemy", category = "enemyMiss" }
		),
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 2 } }, b = { add = { radius = 10 } } },
			{ a = { mul = { cooldown = 0.85 } }, b = { values = { boost = 50 } } }
		),
		glyph = "✺",
	},
	-- The old Inquisitor skills (ROZWOJ 9.5) -----------------------------------------------------------------------
	{
		id = "purify",
		pool = "light", -- S145: K2 of Scepter and Staff (was the Inquisitor's row 1)
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "heal",
		delivery = "ranged",
		cost = 25,
		cooldown = 12,
		range = 30,
		values = { healHp = { 10.22, 12 }, healMag = { 8.22, 10 } }, -- S145: rank 1 at 33 = the old rank 6 at 30
		breakpoints = Build.bp2(
			{ a = { overhealShield = true }, b = { burst = { radius = 6, pct = 60 } } },
			{ a = { secondTarget = 50 }, b = { mul = { cooldown = 0.85 } } }
		),
		glyph = "✧",
	},
	{
		id = "brandOfLight",
		pool = "hammer", -- S145: S2 of Mace and Flail (was the Inquisitor's row 4, 26)
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 30,
		cooldown = 10,
		range = 12,
		holy = true,
		-- S145: rank 4 (level 27) keeps the old rank 1 (26, Data/SkillCurves); ranks 1-3 lower (R1 at 20)
		values = { dmg = { 30, 260 }, dot = { 35, 320 } },
		effects = { { kind = "burn", duration = 6, value = "dot" } },
		breakpoints = Build.bp2({ a = { values = { dot = 80 } }, b = { splash = { radius = 5, pct = 40 } } }, {
			a = { lifesteal = 20 },
			b = { effect = { kind = "vulnerability", duration = 8, value = 8, category = "enemyWeak" } },
		}),
		glyph = "✹",
	},
	{
		id = "auraOfEndurance",
		pool = "hammer", -- S145: O1 of Mace and Flail (was the Inquisitor's row 7, 48)
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 40,
		cooldown = 60,
		radius = 30,
		duration = 60,
		values = { hp = { 4, 12 } }, -- S145: { 5, 15 } -> { 4, 12 } (from 10, was 48: rank 10 at 46)
		effects = {
			{
				kind = "statBuff",
				duration = 60,
				stats = { maxHp = "hp" },
				pct = true,
				target = "allies",
				category = "allyVigor",
			},
		},
		breakpoints = Build.bp2({
			a = { add = { radius = 10 } },
			b = {
				allyEffect = {
					kind = "statBuff",
					duration = 60,
					stats = { mres = "mresBp" },
					pct = true,
					target = "allies",
					category = "allyVigor",
				},
				values = { mresBp = 10 },
			},
		}, {
			a = {
				allyEffect = {
					kind = "statBuff",
					duration = 60,
					stats = { armor = "armorBp" },
					pct = true,
					target = "allies",
					category = "allyVigor",
				},
				values = { armorBp = 10 },
			},
			b = {
				allyEffect = {
					kind = "statBuff",
					duration = 60,
					stats = { physAtk = "atkBp", magAtk = "atkBp" },
					pct = true,
					target = "allies",
					category = "allyAttack",
				},
				values = { atkBp = 6 },
			},
		}),
		glyph = "♥",
	},
	{
		id = "hammerOfHeaven",
		pool = "hammer", -- S145: U of Mace and Flail (was the Inquisitor's capstone)
		role = "U",
		unlock = 60,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 70,
		cooldown = 30,
		range = 20,
		radius = 8,
		delay = 0.5,
		holy = true,
		values = { dmg = { 160, 260 } },
		effects = { { kind = "stun", duration = 1.2, notBoss = true } },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { lingering = { pct = 5, duration = 4, kind = "holy" } } },
			{ a = { add = { effectDuration = 0.8 } }, b = { echo = { delay = 1.2, pct = 25 } } }
		),
		glyph = "⚒",
	},
	-- S145 (DESIGN-18 §6.4): the new skills of Scepter and Staff -------------------------------------------------
	{
		-- S1: a ray of light; its main hit heals the most wounded ally within WOUNDED_RADIUS (the caster solo) for
		-- rayHeal % of the damage (Logic/Faith.rayHeal, ctx.wounded, ctx.heal)
		id = "lightRay",
		pool = "light",
		role = "S1",
		unlock = 1,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 12,
		cooldown = 3,
		range = 30,
		holy = true,
		-- Holy Strike x0.85 (its S91 knots too, Data/SkillCurves): a quarter of the hit heals
		values = { dmg = { 142, 289 }, rayHeal = 25 },
		breakpoints = Build.bp2(
			{ a = { values = { rayHeal = 10 } }, b = { values = { dmg = 30 } } },
			{ a = { values = { dmg = 60 } }, b = { splash = { radius = 5, pct = 40 } } }
		),
		glyph = "✦",
	},
	{
		-- K1: a cone of blinding light; the enemies miss their regular attacks for 3 s (misfortune, enemyMiss)
		id = "blindingLight",
		pool = "light",
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 25,
		cooldown = 12,
		radius = 10,
		angle = 90,
		holy = true,
		values = { dmg = { 60, 110 }, miss = 15 },
		effects = BLIND_EFFECTS,
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 1 } }, b = { values = { dmg = 14 } } },
			{ a = { mul = { cooldown = 0.8 } }, b = { add = { angle = 60 } } }
		),
		glyph = "☼",
	},
	{
		-- P1: more healing, critical heals (healCrit, % of the crit chance) and more on a target below LOW_HP_HEAL %
		id = "grace",
		pool = "light",
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		-- `heal`: what Devotion gave the dungeon Healer before 45 (T-SK5 at 20-44, S145)
		-- S146: rank 5 heal 12 -> 10 (T-SK5 at 95-100 <= 0.35; rank 1 at 20 kept)
		values = { heal = { 7, 10 }, healCrit = { 20, 60 }, lowHeal = { 10, 30 } },
		passive = { hooks = { healBonus = "heal", healCrit = "healCrit", lowHpHealBonus = "lowHeal" } },
		glyph = "❀",
	},
	{
		-- S3: a long prayer (castTime) and the biggest single heal of the class
		id = "miracle",
		pool = "light",
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "heal",
		delivery = "ranged",
		cost = 40,
		cooldown = 15,
		range = 30,
		castTime = 1.2,
		values = { healHp = { 26, 32 }, healMag = { 13, 18 } },
		breakpoints = Build.bp2(
			{ a = { values = { healHp = 4 } }, b = { add = { castTime = -0.4 } } },
			{ a = { secondTarget = 50 }, b = { values = { healHp = 8 } } }
		),
		glyph = "✵",
	},
	{
		-- P2: every heal of a heal skill leaves a ward of `ward` % of the HP it restored (Logic/Faith.ward)
		id = "guidingLight",
		pool = "light",
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { ward = { 10, 20 } },
		passive = { hooks = { guidingLight = "ward" } },
		glyph = "✴",
	},
	-- S145 (DESIGN-18 §6.4): the new skills of Mace and Flail ----------------------------------------------------
	{
		-- A1: consecrated ground under the caster, four waves of light
		id = "consecrate",
		pool = "hammer",
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 25,
		cooldown = 10,
		radius = 6,
		hits = 4,
		interval = 0.5,
		holy = true,
		values = { dmg = { 34, 70 } },
		breakpoints = Build.bp2({ a = { add = { radius = 2 } }, b = { values = { dmg = 6 } } }, {
			a = { effect = { kind = "slow", duration = 2, value = 30, category = "enemySlow" } },
			b = { add = { hits = 1 } },
		}),
		glyph = "⊕",
	},
	{
		-- K1: chains of light root the target (Logic/Snare: bosses and Elite IIs are slowed instead)
		id = "holyChains",
		pool = "hammer",
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 25,
		cooldown = 12,
		range = 15,
		holy = true,
		values = { dmg = { 70, 130 }, slow = 40 },
		effects = CHAINS_EFFECTS,
		breakpoints = Build.bp2({ a = { add = { effectDuration = 0.5 } }, b = { values = { dmg = 14 } } }, {
			a = { mul = { cooldown = 0.8 } },
			b = { effect = { kind = "vulnerability", duration = 6, value = 8, category = "enemyWeak" } },
		}),
		glyph = "⛓",
	},
	{
		-- A2: a burst of light around the caster: damage to the enemies and a small heal of the allies in the circle in
		-- one cast (Types/Offense.circleSelf with healHp / healMag, ctx.healAmount)
		id = "holyNova",
		pool = "hammer",
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 45,
		cooldown = 14,
		radius = 8,
		holy = true,
		values = { dmg = { 120, 200 }, healHp = { 3, 5 }, healMag = { 3, 5 } },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { values = { healHp = 1 } } },
			{ a = { echo = { delay = 1, pct = 22 } }, b = { values = { dmg = 44 } } }
		),
		glyph = "✳",
	},
	{
		-- K2: a rebuke of light in a cone: knocks back and breaks an enemy player's channel (Logic/Faith.interrupts; a
		-- boss's channel breaks only by damage, BossMechanics)
		id = "rebuke",
		pool = "hammer",
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 30,
		cooldown = 16,
		radius = 8,
		angle = 100,
		holy = true,
		knockback = 8,
		interrupt = true,
		values = { dmg = { 90, 160 } },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { values = { dmg = 18 } } },
			{ a = { effect = { kind = "stun", duration = 0.8, notBoss = true } }, b = { mul = { cooldown = 0.8 } } }
		),
		glyph = "✋",
	},
	{
		-- P2: every offensive cast of a Mace and Flail skill shortens the running cooldowns of the pool's other skills
		-- (Logic/Faith.zealCut)
		id = "zeal",
		pool = "hammer",
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		-- S146: 0.3-0.8 -> 0.1-0.2 (R9 of the hammer pool at 100 <= 0.93 x "Furia" once the Inquisitor buys Zeal)
		values = { zeal = { 0.1, 0.2 } },
		passive = { hooks = { zeal = "zeal" } },
		glyph = "⇈",
	},
})
