--!strict
-- Mage (docs/ROZWOJ.md 12): base 8 and the skills of the destroyer and arcanist paths. Ids are kept (firebolt = Magic Bolt, firewall = Thunderstorm, meteorStorm = Wrath of Elements).
-- S18: element skills need a weapon of the same element; Magic Bolt and Wrath of Elements are adaptive, Thunderstorm
-- is lightning. S81: unlocks and paths of ROZWOJ 12.2 / 12.4 / 12.5, B options of the 11 older actives.

local Build = require("./Build")

return Build.class("Mage", "mana", "magic", {
	{
		id = "firebolt",
		unlock = 1,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 12,
		cooldown = 2.5,
		range = 38,
		hits = 1, -- S79 (ROZWOJ 14.4): Bolt 10B adds one (add.hits)
		adaptive = true,
		values = { dmg = { 170, 310 } },
		breakpoints = Build.bp2(
			{ a = { pierce = 40 }, b = { mul = { cooldown = 0.88 } } },
			-- 10B: two bolts at 186 % each (20 % more in total)
			{ a = { splash = { radius = 4, pct = 50 } }, b = { add = { hits = 1 }, values = { dmg = -124 } } }
		),
		glyph = "✦",
		vfx = "arcaneBolt",
	},
	{
		id = "fireball",
		unlock = 3,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 35,
		cooldown = 8,
		range = 38,
		radius = 8,
		element = "fire",
		values = { dmg = { 150, 270 } },
		breakpoints = Build.bp2(
			{ a = { lingering = { pct = 15, duration = 3, kind = "burn" } }, b = { execute = 35 } },
			{ a = { split = { count = 3, pct = 40, radius = 7 } }, b = { values = { dmg = 55 } } }
		),
		glyph = "☄",
	},
	{
		id = "iceShard",
		unlock = 6,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 15,
		cooldown = 5,
		range = 38,
		element = "ice",
		values = { dmg = { 140, 250 }, slow = 30 },
		effects = { { kind = "slow", duration = 3, value = "slow", category = "enemySlow" } },
		breakpoints = Build.bp2(
			{ a = { effect = { kind = "freeze", duration = 0.8 } }, b = { values = { dmg = 20 } } },
			{ a = { pierce = 60 }, b = { mul = { cooldown = 0.85 } } }
		),
		glyph = "❄",
		vfx = "iceShard",
	},
	{
		id = "chainLightning",
		unlock = 10,
		maxLevel = 10,
		type = "chain",
		delivery = "ranged",
		cost = 35,
		cooldown = 9,
		range = 35,
		radius = 12,
		element = "lightning",
		values = { dmg = { 130, 230 }, jumps = { 3, 6 } },
		breakpoints = Build.bp2(
			{ a = { add = { jumps = 2 } }, b = { values = { dmg = 25 } } },
			{ a = { stunLast = 1 }, b = { mul = { cooldown = 0.8 } } }
		),
		glyph = "⚡",
	},
	{
		id = "blink",
		unlock = 14,
		maxLevel = 10,
		type = "blink",
		delivery = "ranged",
		cost = 20,
		cooldown = 12,
		length = 15,
		values = {},
		breakpoints = Build.bp2({
			a = {
				selfEffect = {
					kind = "damageReduction",
					duration = 2,
					value = 30,
					target = "self",
					category = "own",
				},
			},
			b = { add = { length = 5 } },
		}, {
			a = { mul = { cooldown = 0.6 } },
			b = { trap = { radius = 6, duration = 3, slow = 40 } },
		}),
		glyph = "✧",
	},
	{
		id = "frostNova",
		unlock = 18,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 45,
		cooldown = 18,
		radius = 10,
		element = "ice",
		values = { dmg = { 120, 220 }, freeze = { 1.5, 2.5 } },
		effects = { { kind = "freeze", duration = { 1.5, 2.5 } } },
		breakpoints = Build.bp2({
			a = { add = { radius = 3 } },
			b = {
				selfEffect = { kind = "damageReduction", duration = 4, value = 20, target = "self", category = "own" },
			},
		}, {
			a = { lingering = { pct = 10, duration = 4, kind = "frost", slow = 40 } },
			b = { echo = { delay = 1.5, pct = 40 } },
		}),
		glyph = "✳",
	},
	{
		id = "meteor",
		unlock = 30,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 60,
		cooldown = 20,
		range = 38,
		radius = 10,
		delay = 1,
		element = "fire",
		values = { dmg = { 280, 480 } },
		breakpoints = Build.bp2(
			{ a = { mul = { delay = 0.5 } }, b = { values = { dmg = 45 } } },
			{ a = { lingering = { pct = 20, duration = 4, kind = "burn" } }, b = { values = { dmg = 100 } } }
		),
		glyph = "☄",
	},
	{
		id = "firewall",
		unlock = 45,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 55,
		cooldown = 22,
		range = 38,
		radius = 12,
		hits = 10,
		interval = 0.5,
		randomTarget = true,
		element = "lightning",
		values = { dmg = { 50, 90 } },
		breakpoints = Build.bp2(
			{ a = { add = { hits = 4 } }, b = { mul = { cooldown = 0.75 } } },
			{ a = { effect = { kind = "stun", duration = 0.5 } }, b = { values = { dmg = 18 } } }
		),
		glyph = "⛈",
		vfx = "thunderstorm",
	},
	{
		id = "elementalist",
		path = "destroyer",
		unlock = 10,
		maxLevel = 5,
		type = "passive",
		values = { bonus = { 3, 15 } },
		passive = { hooks = { elementDamage = "bonus" } },
		glyph = "✺",
	},
	-- S80 (ROZWOJ 12.4): Destroyer. Elemental Vortex follows the mage (circleSelf re-centres every wave) and does not
	-- block other spells; the weapon's element adds its effect.
	{
		id = "elementalVortex",
		path = "destroyer",
		unlock = 26,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 40,
		cooldown = 12,
		radius = 7,
		hits = 10,
		interval = 0.4,
		adaptive = true,
		values = { dmg = { 12, 13 } },
		breakpoints = Build.bp2({ a = { add = { radius = 2 } }, b = { values = { dmg = 2 } } }, {
			a = { add = { hits = 3 } },
			b = {
				selfEffect = { kind = "damageReduction", duration = 6, value = 20, target = "self", category = "own" },
			},
		}),
		glyph = "❋",
	},
	{
		id = "meteorStorm",
		path = "destroyer",
		unlock = 48,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 120,
		cooldown = 50,
		range = 38,
		radius = 16,
		hits = 6,
		interval = 0.4,
		delay = 0.8,
		adaptive = true,
		values = { dmg = { 60, 80 } }, -- S81 (ROZWOJ 12.4, 15.5.4): row 7 of the Destroyer
		breakpoints = Build.bp2(
			{ a = { add = { hits = 2 } }, b = { mul = { cooldown = 0.75 } } },
			{ a = { add = { radius = 4 } }, b = { values = { dmg = 22 } } }
		),
		glyph = "✺",
	},
	-- Cataclysm (capstone): pulls the whole circle to the point first (bosses immune), then 5 waves.
	{
		id = "cataclysm",
		path = "destroyer",
		unlock = 60,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 90,
		cooldown = 30,
		range = 38,
		radius = 12,
		hits = 5,
		interval = 0.6,
		pull = true,
		adaptive = true,
		values = { dmg = { 60, 70 } },
		breakpoints = Build.bp2({ a = { add = { radius = 3 } }, b = { values = { dmg = 7 } } }, {
			a = { lingering = { pct = 25, duration = 4, kind = "element" } },
			b = { echo = { delay = 0.8, pct = 100 } },
		}),
		glyph = "✵",
	},
	{
		id = "focus",
		path = "destroyer",
		unlock = 80,
		maxLevel = 5,
		type = "passive",
		-- S81 (ROZWOJ 12.4): the S79 mana reserve (percentage points of the pool), not regeneration
		values = { reserve = { 4, 20 } },
		passive = { pct = { manaReserve = "reserve" } },
		glyph = "◉",
	},
	{
		id = "manaShield",
		path = "arcanist",
		unlock = 10,
		maxLevel = 10,
		type = "buff",
		delivery = "ranged",
		cost = 30,
		cooldown = 40,
		duration = { 8, 15 },
		values = {},
		effects = { { kind = "manaShield", duration = { 8, 15 }, value = 50, target = "self", category = "own" } },
		breakpoints = Build.bp2({
			a = {
				selfEffect = {
					kind = "statBuff",
					duration = 15,
					stats = { manaRegen = "regenBp" },
					pct = true,
					target = "self",
					category = "own",
				},
				values = { regenBp = 50 },
			},
			b = { mul = { cooldown = 0.75 } },
		}, { a = { add = { effectDuration = 5 } }, b = { selfHeal = 10 } }),
		glyph = "🔵",
	},
	-- S80 (ROZWOJ 12.5): Arcanist. Arcane Discharge: pure magic, consumes every Arcane Charge for +perCharge % each.
	{
		id = "arcaneDischarge",
		path = "arcanist",
		unlock = 26,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 20,
		cooldown = 6,
		range = 38,
		values = { dmg = { 140, 230 }, perCharge = 12 },
		breakpoints = Build.bp2(
			{ a = { values = { perCharge = 5 } }, b = { mul = { cooldown = 0.8 } } },
			{ a = { execute = 35 }, b = { splash = { radius = 5, pct = 40 } } }
		),
		glyph = "✴",
	},
	{
		id = "evocation",
		path = "arcanist",
		unlock = 48,
		maxLevel = 10,
		type = "channel",
		delivery = "ranged",
		cost = 0,
		cooldown = 120, -- S81 (ROZWOJ 15.5.4): 90 -> 120; 5A gives 90
		duration = 3,
		values = { mana = { 30, 50 } },
		breakpoints = Build.bp2(
			{ a = { mul = { cooldown = 0.75 } }, b = { channelMove = 50 } },
			{ a = { values = { mana = 15 } }, b = { grantCharges = 4 } }
		),
		glyph = "∞",
	},
	-- Arcane Torrent (capstone): a beam (Logic/Channel "beam"): damage does not break it; mana per tick, no cost.
	{
		id = "arcaneTorrent",
		path = "arcanist",
		unlock = 60,
		maxLevel = 10,
		type = "beam",
		delivery = "ranged",
		cost = 0,
		cooldown = 25,
		range = 30,
		duration = 4,
		interval = 0.5,
		values = { dmg = { 160, 170 }, growth = 2, drain = 1.5 },
		breakpoints = Build.bp2(
			{ a = { values = { growth = 1 } }, b = { channelMove = 50 } },
			{ a = { values = { dmg = 30 } }, b = { splash = { radius = 4, pct = 35 } } }
		),
		glyph = "≋",
	},
	{
		id = "arcaneMind",
		path = "arcanist",
		unlock = 80,
		maxLevel = 5,
		type = "passive",
		values = { crit = { 1, 3 }, critDmg = { 3, 8 } }, -- S81 (ROZWOJ 12.5, 15.5.4)
		passive = { flat = { critChance = "crit", critDmg = "critDmg" } },
		glyph = "✦",
	},
})
