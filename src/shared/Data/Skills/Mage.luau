--!strict
-- Mage (docs/ROZWOJ.md 12): base 8 and the skills of the destroyer and arcanist paths. Ids are kept (firebolt = Magic Bolt, firewall = Thunderstorm, meteorStorm = Rain of Meteors).
-- S18: element skills need a weapon of the same element; Magic Bolt is adaptive, Thunderstorm is lightning. S81:
-- unlocks and paths of ROZWOJ 12.2 / 12.4 / 12.5, B options of the 11 older actives.
-- S140 (DESIGN-18 §6.1): the fire pool on the shared ladder (A1 Fireball 3, K1 Flame Wave 6, O1 Ember Shield 10, S2
-- Pyroblast 15, P1 Kindling 20, A2 Meteor 26, K2 Combustion 33, S3 Immolate 40, P2 Phoenix Heart 50, U Rain of Meteors
-- 60; S1 Magic Bolt stays common and adaptive until S142) and the Mage's common skills (C1 Blink 4, C2 Mana Shield 12,
-- C3 Evocation 30, C4 Focus 45). Elementalist and Arcane Mind are passive nodes of the directions (Data/Paths/Mage).
-- Fire mechanics: Logic/Burn (burnStacks, Kindling's hooks, vsBurning, detonate, Phoenix Heart).
-- S141 (DESIGN-18 §6.1): the ice pool on the ladder (S1 Ice Shard 1, A1 Hailstorm 3, K1 Frost Nova 6, O1 Ice Barrier 10,
-- S2 Glacial Spike 15, P1 Winter's Grip 20, A2 Frozen Orb 26, K2 Deep Freeze 33, S3 Shatter 40, P2 Ice Blood 50, U
-- Blizzard 60; the new ones at the end of the list). Ice mechanics: Logic/Chill (the chill counter, Deep Chill on
-- bosses, vsFrozen, Shatter, the barrier's slow, Ice Blood).

local Build = require("./Build")

return Build.class("Mage", "mana", "magic", {
	{
		id = "firebolt",
		pool = "common", -- S137 (DESIGN-18 §4.2)
		unlock = 1,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 12,
		cooldown = 2.5,
		range = 38,
		hits = 1, -- S79 (ROZWOJ 14.4): Bolt 10B adds one (add.hits)
		adaptive = true,
		-- S91: rank 1 170 -> 128 (ranks <= 20, Data/SkillCurves). S140: 128 -> 118 (the fire pool's R1 at 20, S91 band)
		values = { dmg = { 118, 255.7 } },
		breakpoints = Build.bp2(
			{ a = { pierce = 17 }, b = { mul = { cooldown = 0.88 } } }, -- S91: 5A pierce 40 -> 17 (R4)
			-- 10B: two bolts at 151.7 % each (19 % more in total)
			{ a = { splash = { radius = 4, pct = 12 } }, b = { add = { hits = 1 }, values = { dmg = -104 } } }
		),
		glyph = "✦",
		vfx = "arcaneBolt",
	},
	{
		id = "fireball",
		pool = "fire",
		role = "A1", -- S140
		unlock = 3,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 35,
		cooldown = 8,
		range = 38,
		radius = 8,
		element = "fire",
		-- S91: rank 1 150 -> 128 (ranks <= 20, Data/SkillCurves). S140: 128 -> 120 (the fire pool's R1 at 20, S91 band)
		values = { dmg = { 120, 221.8 } },
		breakpoints = Build.bp2(
			-- S91: 5A burn 15 -> 5.5 % (R4)
			{ a = { lingering = { pct = 5.5, duration = 3, kind = "burn" } }, b = { execute = 35 } },
			{ a = { split = { count = 3, pct = 40, radius = 7 } }, b = { values = { dmg = 55 } } }
		),
		glyph = "☄",
	},
	-- S141 (DESIGN-18 §6.1): the ice pool's S1 (unlock 6 -> 1): rank 1 near Magic Bolt's (S91)
	{
		id = "iceShard",
		pool = "ice",
		role = "S1",
		unlock = 1,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 15,
		cooldown = 5,
		range = 38,
		element = "ice",
		-- S91: rank 1 140 -> 119 (Data/SkillCurves). S141: 119 -> 70 at level 1 (rank-5 knot 80; DECYZJE S141)
		values = { dmg = { 70, 213 }, slow = 30 },
		effects = { { kind = "slow", duration = 3, value = "slow", category = "enemySlow" } },
		breakpoints = Build.bp2(
			{ a = { effect = { kind = "freeze", duration = 0.8 } }, b = { values = { dmg = 23 } } },
			{ a = { pierce = 27 }, b = { mul = { cooldown = 0.84 } } }
		),
		glyph = "❄",
		vfx = "iceShard",
	},
	{
		id = "chainLightning",
		pool = "lightning",
		unlock = 10,
		maxLevel = 10,
		type = "chain",
		delivery = "ranged",
		cost = 35,
		cooldown = 9,
		range = 35,
		radius = 12,
		element = "lightning",
		values = { dmg = { 110, 163.5 }, jumps = { 3, 6 } }, -- S91: rank 1 130 -> 110
		breakpoints = Build.bp2(
			{ a = { add = { jumps = 2 } }, b = { values = { dmg = 22 } } },
			{ a = { stunLast = 1 }, b = { mul = { cooldown = 0.83 } } }
		),
		glyph = "⚡",
	},
	{
		id = "blink",
		pool = "common",
		role = "C1", -- S140
		unlock = 4, -- S140: 14 -> 4 (COMMON_LADDER C1)
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
	-- S141: the ice pool's K1 (unlock 18 -> 6, freeze 1-2 s); bosses get Deep Chill instead (Logic/Chill)
	{
		id = "frostNova",
		pool = "ice",
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "circleSelf",
		delivery = "melee",
		cost = 40,
		cooldown = 16,
		radius = 10,
		element = "ice",
		-- S141: rank 1 at 6 below the old rank 1 at 18 (the knot keeps rank 4, level 18, at 120)
		values = { dmg = { 90, 141.3 }, freeze = { 1, 2 } },
		effects = { { kind = "freeze", duration = { 1, 2 } } },
		breakpoints = Build.bp2({
			a = { add = { radius = 3 } },
			b = {
				selfEffect = { kind = "damageReduction", duration = 4, value = 20, target = "self", category = "own" },
			},
		}, {
			a = { lingering = { pct = 5, duration = 4, kind = "frost", slow = 40 } },
			b = { echo = { delay = 1.5, pct = 19 } },
		}),
		glyph = "✳",
	},
	{
		id = "meteor",
		pool = "fire",
		role = "A2", -- S140
		unlock = 26, -- S140: 30 -> 26 (LADDER A2); Data/SkillCurves keeps the value at a level (rank 2 at 30 = old rank 1)
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 72,
		cooldown = 20,
		range = 38,
		radius = 10,
		delay = 1,
		element = "fire",
		values = { dmg = { 89.6, 174 } }, -- S140: rank 1 98 -> 89.6 (the knot keeps rank 2 = 98 at level 30)
		breakpoints = Build.bp2(
			-- S140: 5B 23 -> 20 (rank 5 now at 42, R4 at 45 0.182 -> 0.16)
			{ a = { mul = { delay = 0.5 } }, b = { values = { dmg = 20 } } },
			{ a = { lingering = { pct = 6, duration = 4, kind = "burn" } }, b = { values = { dmg = 45 } } }
		),
		glyph = "☄",
	},
	{
		id = "firewall",
		pool = "lightning",
		unlock = 45,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 43,
		cooldown = 22,
		range = 38,
		radius = 12,
		hits = 10,
		interval = 0.5,
		randomTarget = true,
		element = "lightning",
		values = { dmg = { 24.9, 49.8 } },
		breakpoints = Build.bp2(
			{ a = { add = { hits = 1 } }, b = { mul = { cooldown = 0.93 } } },
			{ a = { effect = { kind = "stun", duration = 0.5 } }, b = { values = { dmg = 13.9 } } }
		),
		glyph = "⛈",
		vfx = "thunderstorm",
	},
	-- S140 (DESIGN-18 §6.1): the rest of the fire pool. Starting numbers (model D of S140, docs/SESJE.md S140).
	-- Flame Wave: a cone that throws back (knockback, bosses immune) and sets one burn stack.
	{
		id = "flameWave",
		pool = "fire",
		role = "K1",
		unlock = 6,
		maxLevel = 10,
		type = "cone",
		delivery = "melee",
		cost = 40,
		cooldown = 14,
		radius = 8,
		angle = 70,
		element = "fire",
		burnStacks = 1,
		knockback = 6,
		values = { dmg = { 45, 150 } },
		breakpoints = Build.bp2(
			{ a = { add = { angle = 40 } }, b = { values = { dmg = 16 } } },
			{ a = { add = { burnStacks = 1 } }, b = { values = { dmg = 36 } } }
		),
		glyph = "♒",
	},
	-- Ember Shield: an absorb shield on the caster; while it lasts a melee blow burns the attacker (CombatService).
	{
		id = "emberShield",
		pool = "fire",
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "shield",
		target = "self",
		delivery = "ranged",
		cost = 35,
		cooldown = 24,
		duration = 8,
		element = "fire",
		values = { shieldHp = { 8, 12 }, shieldMag = { 10, 15 }, ember = { 20, 40 } },
		effects = { { kind = "emberShield", duration = 8, value = "ember", target = "self", category = "own" } },
		breakpoints = Build.bp2(
			{ a = { values = { ember = 15 } }, b = { values = { shieldHp = 3 } } },
			{ a = { add = { effectDuration = 4, duration = 4 } }, b = { mul = { cooldown = 0.75 } } }
		),
		glyph = "🜂",
	},
	-- Pyroblast: a long cast, a heavy bolt and two burn stacks.
	{
		id = "pyroblast",
		pool = "fire",
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 40,
		cooldown = 10,
		range = 38,
		castTime = 1,
		element = "fire",
		burnStacks = 2,
		values = { dmg = { 90, 380 } },
		breakpoints = Build.bp2(
			{ a = { splash = { radius = 5, pct = 12 } }, b = { values = { dmg = 45 } } },
			{ a = { add = { burnStacks = 1 } }, b = { values = { dmg = 80 } } }
		),
		glyph = "✹",
	},
	-- Kindling: the caster's burns stack up to 1 + extraStacks; every own stack on a target: +perStack % fire damage
	-- there.
	{
		id = "kindling",
		pool = "fire",
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		values = { extraStacks = 2, perStack = { 1, 5 } },
		passive = { hooks = { burnStacks = "extraStacks", burnBonus = "perStack" } },
		glyph = "♨",
	},
	-- Combustion: a hit that consumes the target's burn stacks in a blast of detonate % per stack (Logic/Burn.detonate);
	-- at BURN.stunAt stacks it stuns (never bosses).
	{
		id = "combustion",
		pool = "fire",
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 45,
		cooldown = 16,
		range = 38,
		radius = 6,
		element = "fire",
		values = { dmg = { 80, 140 }, detonate = { 60, 105 }, stun = 1 },
		breakpoints = Build.bp2(
			{ a = { add = { radius = 2 } }, b = { values = { detonate = 14 } } },
			{ a = { values = { stun = 0.5 } }, b = { mul = { cooldown = 0.8 } } }
		),
		glyph = "✺",
	},
	-- Immolate: the finisher; +vsBurning % per own burn stack on the target (Logic/Burn.vsBurning).
	{
		id = "immolate",
		pool = "fire",
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 35,
		cooldown = 9,
		range = 38,
		element = "fire",
		finisher = { hp = 30, mul = 1.5 },
		values = { dmg = { 180, 300 }, vsBurning = { 10, 16 } },
		breakpoints = Build.bp2(
			{ a = { splash = { radius = 5, pct = 8 } }, b = { values = { vsBurning = 5 } } },
			{ a = { execute = 50 }, b = { values = { dmg = 60 } } }
		),
		glyph = "🔥",
	},
	-- Phoenix Heart: a lethal blow leaves 1 HP once per `rest` s, `invuln` s of invulnerability and a fire blast of
	-- `blast` % magic attack around (SkillService, Logic/Burn.phoenixSave).
	{
		id = "phoenixHeart",
		pool = "fire",
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { blast = { 150, 300 }, rest = 180, invuln = 2 },
		passive = { hooks = { phoenixHeart = "blast", phoenixRest = "rest", phoenixInvuln = "invuln" } },
		glyph = "🜃",
	},
	-- Rain of Meteors (id meteorStorm, was Wrath of Elements): S140 the fire pool's capstone (U), fire, one burn stack
	-- per impact.
	{
		id = "meteorStorm",
		pool = "fire",
		role = "U",
		unlock = 60, -- S140: 48 -> 60 (LADDER U)
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 174,
		cooldown = 50,
		range = 38,
		radius = 16,
		hits = 6,
		interval = 0.4,
		delay = 0.8,
		element = "fire",
		burnStacks = 1,
		values = { dmg = { 24, 24 } }, -- S81 (ROZWOJ 12.4, 15.5.4): row 7 of the Destroyer
		breakpoints = Build.bp2(
			{ a = { add = { hits = 1 } }, b = { mul = { cooldown = 0.88 } } },
			-- S94 (H4): 10A -5 studs (was +4: a wider storm spread the impacts, R4 -0.04; -5 gives 0.21 at 84-100)
			{ a = { add = { radius = -5 } }, b = { values = { dmg = 4.4 } } }
		),
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
		cost = 12,
		cooldown = 12,
		radius = 7,
		hits = 10,
		interval = 0.4,
		adaptive = true,
		values = { dmg = { 6.2, 8.3 } },
		breakpoints = Build.bp2({ a = { add = { radius = 2 } }, b = { values = { dmg = 1.2 } } }, {
			a = { add = { hits = 3 } },
			b = {
				selfEffect = { kind = "damageReduction", duration = 6, value = 20, target = "self", category = "own" },
			},
		}),
		glyph = "❋",
	},
	-- Cataclysm (capstone): pulls the whole circle to the point first (bosses immune), then 5 waves.
	{
		id = "cataclysm",
		path = "destroyer",
		unlock = 60,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 119,
		cooldown = 30,
		range = 38,
		radius = 12,
		hits = 5,
		interval = 0.6,
		pull = true,
		adaptive = true,
		values = { dmg = { 36.6, 36.6 } },
		breakpoints = Build.bp2({ a = { add = { radius = 3 } }, b = { values = { dmg = 6 } } }, {
			a = { lingering = { pct = 34, duration = 4, kind = "element" } },
			b = { echo = { delay = 0.8, pct = 136 } },
		}),
		glyph = "✵",
	},
	-- S140: the Mage's common skills (C1 Blink above): Mana Shield, Evocation and Focus were path skills.
	{
		id = "manaShield",
		pool = "common",
		role = "C2",
		unlock = 12, -- S140: 10 (row 1 of the Arcanist) -> 12 (COMMON_LADDER C2)
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
	{
		id = "evocation",
		pool = "common",
		role = "C3",
		unlock = 30, -- S140: 48 (row 7 of the Arcanist) -> 30 (COMMON_LADDER C3)
		maxLevel = 10,
		type = "channel",
		delivery = "ranged",
		cost = 0,
		cooldown = 120, -- S81 (ROZWOJ 15.5.4): 90 -> 120; 5A gives 90
		duration = 3,
		values = { mana = { 25, 49 } },
		breakpoints = Build.bp2(
			{ a = { mul = { cooldown = 0.75 } }, b = { channelMove = 50 } },
			{ a = { values = { mana = 15 } }, b = { grantCharges = 4 } }
		),
		glyph = "∞",
	},
	{
		id = "focus",
		pool = "common",
		role = "C4",
		unlock = 45, -- S140: 80 (row 10 of the Destroyer) -> 45 (COMMON_LADDER C4)
		maxLevel = 5,
		type = "passive",
		-- S81 (ROZWOJ 12.4): the S79 mana reserve (percentage points of the pool), not regeneration
		values = { reserve = { 3.1, 15.4 } },
		passive = { pct = { manaReserve = "reserve" } },
		glyph = "◉",
	},
	-- S80 (ROZWOJ 12.5): Arcanist. Arcane Discharge: pure magic, consumes every Arcane Charge for +perCharge % each.
	{
		id = "arcaneDischarge",
		path = "arcanist",
		unlock = 26,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 5,
		cooldown = 6,
		range = 38,
		values = { dmg = { 57, 69 }, perCharge = 4.1 },
		breakpoints = Build.bp2(
			{ a = { values = { perCharge = 5 } }, b = { mul = { cooldown = 0.8 } } },
			{ a = { execute = 40 }, b = { splash = { radius = 5, pct = 11 } } }
		),
		glyph = "✴",
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
		values = { dmg = { 122, 140 }, growth = 1.62, drain = 0.73 },
		breakpoints = Build.bp2(
			{ a = { values = { growth = 4.37 } }, b = { channelMove = 50 } },
			{ a = { values = { dmg = 32 } }, b = { splash = { radius = 4, pct = 10 } } }
		),
		glyph = "≋",
	},
	-- S141 (DESIGN-18 §6.1): the rest of the ice pool (Logic/Chill). Starting numbers: model C of S141 (docs/SESJE.md).
	-- Hailstorm: three waves of hail on a circle, each wave slows (waveEffects).
	{
		id = "hailstorm",
		pool = "ice",
		role = "A1",
		unlock = 3,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 35,
		cooldown = 8,
		range = 38,
		radius = 7,
		hits = 3,
		interval = 0.5,
		element = "ice",
		waveEffects = true,
		values = { dmg = { 18, 60 }, slow = 30 },
		effects = { { kind = "slow", duration = 2, value = "slow", category = "enemySlow" } },
		breakpoints = Build.bp2(
			{ a = { values = { slow = 15 } }, b = { values = { dmg = 7 } } },
			{ a = { lingering = { pct = 5, duration = 3, kind = "frost", slow = 40 } }, b = { values = { dmg = 16 } } }
		),
		glyph = "⁂",
	},
	-- Ice Barrier: an absorb shield on the caster; while it lasts a monster's melee blow slows the attacker (CombatService).
	{
		id = "iceBarrier",
		pool = "ice",
		role = "O1",
		unlock = 10,
		maxLevel = 10,
		type = "shield",
		target = "self",
		delivery = "ranged",
		cost = 35,
		cooldown = 24,
		duration = 8,
		element = "ice",
		values = { shieldHp = { 8, 12 }, shieldMag = { 10, 15 }, barrier = { 40, 55 } },
		effects = { { kind = "iceBarrier", duration = 8, value = "barrier", target = "self", category = "own" } },
		breakpoints = Build.bp2(
			{ a = { values = { barrier = 15 } }, b = { values = { shieldHp = 3 } } },
			{ a = { add = { effectDuration = 4, duration = 4 } }, b = { mul = { cooldown = 0.75 } } }
		),
		glyph = "⛉",
	},
	-- Glacial Spike: a long cast, a heavy spike, x (1 + vsFrozen %) on a frozen target, x (1 + vsDeepChill %) on a boss
	-- with the caster's Deep Chill (Logic/Chill.vsFrozen).
	{
		id = "glacialSpike",
		pool = "ice",
		role = "S2",
		unlock = 15,
		maxLevel = 10,
		type = "projectile",
		delivery = "ranged",
		cost = 40,
		cooldown = 10,
		range = 38,
		castTime = 0.8,
		element = "ice",
		values = { dmg = { 70, 330 }, vsFrozen = 50, vsDeepChill = 25 },
		breakpoints = Build.bp2(
			{ a = { splash = { radius = 5, pct = 9 } }, b = { values = { dmg = 45 } } },
			{ a = { effect = { kind = "freeze", duration = 1.5 } }, b = { values = { dmg = 75 } } }
		),
		glyph = "⟁",
	},
	-- Winter's Grip: the chill counter (Logic/Chill.chillToFreeze): CHILL.threshold main ice hits on a slowed enemy freeze
	-- it for `freeze` s; bosses get Deep Chill (+deepChill %, at least CHILL.deepPct).
	{
		id = "wintersGrip",
		pool = "ice",
		role = "P1",
		unlock = 20,
		maxLevel = 5,
		type = "passive",
		values = { freeze = { 1.5, 2.5 }, deepChill = { 10, 18 } },
		passive = { hooks = { chillFreeze = "freeze", deepChill = "deepChill" } },
		glyph = "❆",
	},
	-- Frozen Orb: a slow orb flies `travel` studs from the caster; every wave hurts and slows a bit more (a slow of up
	-- to five stacks).
	{
		id = "frozenOrb",
		pool = "ice",
		role = "A2",
		unlock = 26,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 60,
		cooldown = 16,
		range = 38,
		radius = 5,
		hits = 10,
		interval = 0.4,
		travel = 20,
		element = "ice",
		waveEffects = true,
		values = { dmg = { 12, 24 }, slow = 8 },
		effects = { { kind = "slow", duration = 2, value = "slow", category = "enemySlow", maxStacks = 5 } },
		breakpoints = Build.bp2(
			{ a = { values = { slow = 2 } }, b = { values = { dmg = 2.5 } } },
			{ a = { add = { radius = 2 } }, b = { values = { dmg = 5 } } }
		),
		glyph = "◎",
	},
	-- Deep Freeze: a long freeze of one target; bosses get Deep Chill and slower attacks (attackSlow lands on everyone).
	{
		id = "deepFreeze",
		pool = "ice",
		role = "K2",
		unlock = 33,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 45,
		cooldown = 20,
		range = 38,
		element = "ice",
		values = { dmg = { 70, 120 }, attackSlow = 30 },
		effects = {
			{ kind = "freeze", duration = 3 },
			{ kind = "attackSlow", duration = 4, value = "attackSlow", category = "enemyAttackSlow" },
		},
		breakpoints = Build.bp2(
			{ a = { add = { effectDuration = 1 } }, b = { values = { dmg = 13 } } },
			{ a = { mul = { cooldown = 0.85 } }, b = { values = { dmg = 30 } } }
		),
		glyph = "✻",
	},
	-- Shatter: the finisher; ends the target's freeze for x (1 + shatter %), on a boss spends the caster's Deep Chill for
	-- x (1 + shatterDeep %) (Logic/Chill.shatterMul).
	{
		id = "shatter",
		pool = "ice",
		role = "S3",
		unlock = 40,
		maxLevel = 10,
		type = "target",
		delivery = "ranged",
		cost = 35,
		cooldown = 9,
		range = 38,
		element = "ice",
		values = { dmg = { 160, 230 }, shatter = 100, shatterDeep = 60 },
		breakpoints = Build.bp2(
			{ a = { splash = { radius = 5, pct = 12 } }, b = { values = { shatter = 30 } } },
			{ a = { effect = { kind = "freeze", duration = 1 } }, b = { values = { dmg = 55 } } }
		),
		glyph = "✶",
	},
	-- Ice Blood: less damage from slowed or frozen attackers (own damage reduction, CombatService).
	{
		id = "iceBlood",
		pool = "ice",
		role = "P2",
		unlock = 50,
		maxLevel = 5,
		type = "passive",
		values = { blood = { 4, 12 } },
		passive = { hooks = { iceBlood = "blood" } },
		glyph = "♆",
	},
	-- Blizzard: the ice pool's capstone; a big circle of waves, the slow grows every wave, from wave freezeWave every
	-- enemy inside freezes once (bosses: Deep Chill).
	{
		id = "blizzard",
		pool = "ice",
		role = "U",
		unlock = 60,
		maxLevel = 10,
		type = "circleTarget",
		delivery = "ranged",
		cost = 170,
		cooldown = 50,
		range = 38,
		radius = 12,
		hits = 8,
		interval = 0.75,
		element = "ice",
		waveEffects = true,
		freezeWave = 5,
		values = { dmg = { 17, 21 }, slow = 6, freeze = 1 },
		effects = { { kind = "slow", duration = 2, value = "slow", category = "enemySlow", maxStacks = 8 } },
		breakpoints = Build.bp2(
			{ a = { add = { hits = 1 } }, b = { mul = { cooldown = 0.88 } } },
			{ a = { add = { radius = 3 } }, b = { values = { dmg = 3.5 } } }
		),
		glyph = "🌬",
	},
})
