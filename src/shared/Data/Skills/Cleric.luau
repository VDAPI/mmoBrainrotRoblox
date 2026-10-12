--!strict
-- Cleric (docs/ROZWOJ.md 9): base 8 and the skills of the healer, fortune and inquisitor paths. Heals and shields from
-- target max HP (S69).
-- Heals and buffs only work on the caster and party members. Path skills unlock at their row level through the
-- path's skill node (Data/Paths/Cleric, S71).

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

return Build.class("Cleric", "mana", "magic", {
	{
		id = "holyStrike",
		unlock = 1,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 12,
		cooldown = 3,
		range = 12,
		holy = true,
		values = { dmg = { 190, 340 } },
		breakpoints = Build.bp2(
			{ a = { splash = { radius = 5, pct = 40 } }, b = { execute = 30 } },
			{ a = { effect = { kind = "stun", duration = 0.8 } }, b = { healWounded = 30 } }
		),
		glyph = "✚",
	},
	{
		id = "heal",
		unlock = 3,
		maxLevel = 10,
		type = "heal",
		delivery = "ranged",
		cost = 20,
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
		unlock = 6,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 35,
		cooldown = 10,
		radius = 10,
		holy = true,
		values = { dmg = { 130, 240 }, heal = 50 },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 3 } }, b = { pull = 16 } },
			{ a = { values = { heal = 50 } }, b = { echo = { delay = 1, pct = 40 } } }
		),
		glyph = "☀",
	},
	{
		id = "devotion",
		unlock = 10,
		maxLevel = 5,
		type = "passive",
		values = { heal = { 5, 25 } },
		passive = { hooks = { healBonus = "heal" } },
		glyph = "🙏",
	},
	{
		id = "circleOfLight",
		unlock = 14,
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
			b = { healZone = { duration = 4, pct = 25 } },
		}),
		glyph = "◌",
	},
	{
		id = "shieldOfFaith",
		unlock = 18,
		maxLevel = 10,
		type = "shield",
		delivery = "ranged",
		cost = 40,
		cooldown = 20,
		range = 30,
		duration = 8,
		values = { shieldHp = { 12, 18 }, shieldMag = { 10, 15 } },
		breakpoints = Build.bp2(
			{ a = { values = { shieldHp = 3 } }, b = { cleanse = true } },
			{ a = { secondTarget = 50 }, b = { add = { duration = 6 }, values = { shieldHp = 3 } } }
		),
		glyph = "🛡",
	},
	{
		id = "divineWrath",
		unlock = 30,
		maxLevel = 5,
		type = "passive",
		values = { bonus = { 4, 20 } },
		passive = { hooks = { holyDamage = "bonus", holyStrikeHeal = "bonus" } },
		glyph = "⚜",
	},
	{
		id = "judgement",
		unlock = 45,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 55,
		cooldown = 15,
		range = 14,
		holy = true,
		values = { dmg = { 320, 580 } },
		effects = { { kind = "stun", duration = 1 } },
		breakpoints = Build.bp2({ a = { lifesteal = 30 }, b = { stunNear = { radius = 6, duration = 0.8 } } }, {
			a = { effect = { kind = "vulnerability", duration = 6, value = 10, category = "enemyWeak" } },
			b = { values = { dmg = 100 } },
		}),
		glyph = "⚖",
	},
	-- healer path (ROZWOJ 9.3)
	{
		id = "renew",
		path = "healer",
		unlock = 10,
		maxLevel = 10,
		type = "hot",
		delivery = "ranged",
		cost = 25,
		cooldown = 8,
		range = 30,
		duration = 10,
		values = { healHp = { 16, 24 }, healMag = { 10, 15 } },
		breakpoints = Build.bp2(
			{ a = { add = { duration = 4 } }, b = { secondTarget = 50 } },
			{ a = { cleanse = true }, b = { values = { healHp = 6 } } }
		),
		glyph = "❦",
	},
	{
		id = "sanctuary",
		path = "healer",
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
		unlock = 48,
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 100,
		cooldown = 120,
		radius = 30,
		values = { invuln = { 2, 4 }, heal = 30 },
		effects = { { kind = "invuln", duration = { 2, 4 }, target = "allies" } },
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
		path = "healer",
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
	-- fortune path (ROZWOJ 9.4)
	{
		id = "resurrection",
		path = "fortune",
		unlock = 10,
		maxLevel = 10,
		type = "resurrect",
		delivery = "ranged",
		cost = 80,
		cooldown = { 120, 60 },
		range = 30,
		values = { hp = { 20, 60 } },
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
		path = "fortune",
		unlock = 48,
		maxLevel = 10,
		type = "channel",
		delivery = "melee",
		cost = 0,
		cooldown = 90,
		duration = 3,
		values = { mana = { 25, 45 }, group = 5 },
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
	-- inquisitor path (ROZWOJ 9.5)
	{
		id = "purify",
		path = "inquisitor",
		unlock = 10,
		maxLevel = 10,
		type = "heal",
		delivery = "ranged",
		cost = 25,
		cooldown = 12,
		range = 30,
		values = { healHp = { 8, 12 }, healMag = { 6, 10 } },
		breakpoints = Build.bp2(
			{ a = { overhealShield = true }, b = { burst = { radius = 6, pct = 60 } } },
			{ a = { secondTarget = 50 }, b = { mul = { cooldown = 0.6 } } }
		),
		glyph = "✧",
	},
	{
		id = "brandOfLight",
		path = "inquisitor",
		unlock = 26,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 30,
		cooldown = 10,
		range = 12,
		holy = true,
		values = { dmg = { 100, 170 }, dot = { 140, 240 } },
		effects = { { kind = "burn", duration = 6, value = "dot" } },
		breakpoints = Build.bp2({ a = { values = { dot = 30 } }, b = { splash = { radius = 5, pct = 40 } } }, {
			a = { lifesteal = 20 },
			b = { effect = { kind = "vulnerability", duration = 8, value = 8, category = "enemyWeak" } },
		}),
		glyph = "✹",
	},
	{
		id = "auraOfEndurance",
		path = "inquisitor",
		unlock = 48,
		maxLevel = 10,
		type = "groupBuff",
		delivery = "melee",
		cost = 40,
		cooldown = 60,
		radius = 30,
		duration = 60,
		values = { hp = { 5, 15 } },
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
		path = "inquisitor",
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
		values = { dmg = { 200, 340 } },
		effects = { { kind = "stun", duration = 1.2, notBoss = true } },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { lingering = { pct = 10, duration = 4, kind = "holy" } } },
			{ a = { add = { effectDuration = 0.8 } }, b = { echo = { delay = 1.2, pct = 50 } } }
		),
		glyph = "⚒",
	},
})
