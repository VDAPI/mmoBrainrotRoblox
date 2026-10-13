--!strict
-- Dungeon bosses (DESIGN §16). Grimrok (20) and Morvane (45) are complete; Azgor (70) and Vaelgrath (100)
-- have their data ready for S11, which builds their arenas.
--
-- Attacks are telegraphed areas resolved after `windup`:
--   shape  circle (radius) | cone (radius, angle) | line (length, width) | ring (radius, inner = safe centre)
--   target self (around the boss) | threat (current target) | random (random player) | nearest | all
--   count  how many targets get their own area (random targets without repeats)
--   phases in which phases (1..3) the attack is used; `cooldown` seconds between uses
--   leap   the boss jumps to the area when it lands
-- Phase thresholds are HP fractions. `summons` happen when a phase starts (and every `every` seconds). Since
-- 2026-10-10 every wave is a shield wave: ~10 helpers (+ SUMMON_PER_PLAYER per extra player) attack at once and the
-- boss is invulnerable and holds still at the arena centre until all of them are dead; helpers drop nothing.

local Families = require("./Families")

export type Attack = {
	id: string,
	shape: "circle" | "cone" | "line" | "ring",
	target: "self" | "threat" | "random" | "nearest" | "all",
	radius: number?,
	inner: number?,
	angle: number?,
	length: number?,
	width: number?,
	windup: number,
	damage: number, -- multiplier of the boss attack
	cooldown: number,
	count: number?,
	phases: { number },
	element: ("fire" | "ice" | "lightning" | "poison")?,
	damageKind: ("phys" | "magic")?,
	leap: boolean?,
	-- S64 (STATY 6): nil = neither (telegraphed areas); melee / ranged protection only when set
	delivery: ("melee" | "ranged")?,
}

export type Summon = {
	phase: number,
	monster: string,
	level: number,
	count: number,
	every: number?, -- repeat interval while the phase lasts
	shield: boolean?, -- the boss is invulnerable while these summons live
}

export type BossDef = {
	id: string,
	nameKey: string,
	region: string, -- dungeon region, map "dungeon_<region>"
	level: number,
	hpMul: number?, -- S32: on top of BossScaling.hpMultiplier (fight length), default 1
	atkMul: number,
	defMul: number,
	mresMul: number?, -- S66: magic resistance multiplier, default 1; armour keeps defMul
	family: Families.FamilyId, -- S66: monster family (Data/Families); bosses have no defence trait or dodge
	speed: number, -- attack speed multiplier
	moveSpeed: number,
	attack: "melee" | "ranged",
	damageKind: "phys" | "magic",
	range: number?,
	phases: { number }, -- HP thresholds, e.g. { 0.7, 0.35 }
	attacks: { Attack },
	summons: { Summon },
	-- Phase 3 haste (multiplier of movement and attack speed).
	haste: { [number]: number }?,
	enrageAfter: number, -- seconds
	enrageDamage: number, -- damage multiplier when enraged
	timeLimit: number, -- seconds
	-- S24: only the scale and the aura colour; the look itself is Data/MonsterLooks[boss id].
	look: { size: number, aura: string },
}

local list: { BossDef } = {}
local byId: { [string]: BossDef } = {}

local function boss(def: BossDef)
	byId[def.id] = def
	table.insert(list, def)
end

boss({
	id = "grimrok",
	family = "humanoid",
	nameKey = "boss.grimrok.name",
	region = "meadows",
	level = 20,
	-- S32 (tests/balance.spec): 3-5 players of level 18-20 need 4-6 min; no hit takes more than 70 % of a level 20
	-- Mage's HP (the whirlwind took ~150 %). Basic attacks are softer (atkMul 1.2 → 0.32), the telegraphed attacks
	-- carry the danger. S91: 3-5 players of level 19 need 4-6 min in the S83 / S87 model (hpMul 1.4 -> 1.2); the
	-- sweep at the tank is heavier (4.5 -> 6) so a dungeon Healer heals 1.0-2.0 of the tank's damage (T-SK6).
	hpMul = 1.2,
	atkMul = 0.32,
	defMul = 1.3,
	speed = 0.9,
	moveSpeed = 14,
	attack = "melee",
	damageKind = "phys",
	phases = { 0.7, 0.35 },
	attacks = {
		{
			id = "sweep",
			shape = "cone",
			target = "threat",
			radius = 15,
			angle = 120,
			windup = 1.2,
			damage = 6,
			cooldown = 8,
			phases = { 1, 2, 3 },
		},
		{
			id = "leap",
			shape = "circle",
			target = "random",
			radius = 8,
			windup = 1.5,
			damage = 6,
			cooldown = 13,
			phases = { 1, 2, 3 },
			leap = true,
		},
		{
			id = "whirlwind",
			shape = "circle",
			target = "self",
			radius = 10,
			windup = 1.6,
			damage = 7,
			cooldown = 10,
			phases = { 3 },
		},
	},
	summons = {
		{ phase = 2, monster = "goblinScout", level = 19, count = 10, shield = true },
		{ phase = 3, monster = "goblinScout", level = 20, count = 10, shield = true },
	},
	haste = { [3] = 1.25 },
	enrageAfter = 600,
	enrageDamage = 1.6,
	timeLimit = 900,
	look = { size = 2.6, aura = "#D64A3E" },
})

boss({
	id = "morvane",
	family = "undead",
	nameKey = "boss.morvane.name",
	region = "duskwood",
	level = 45,
	-- S92 (balance plan D4, tests/balance.spec R.duskwood.morvane.*): 3-5 players of level 44 need 4-6 min in the S83 /
	-- S87 model (hpMul 1.2); the basic hit is ~11 % of a level 45 Mage's HP (atkMul 1.1 -> 0.42), the ring stays below
	-- 70 % of it; the curse field on the nearest member carries the tank damage (T-SK6 of the dungeon Healer 2.66,
	-- asserted <= 2.7, DECYZJE S92; the tank's real intake ~740 % HP/min, the S32 row counts only basic and threat
	-- attacks) while a party without support still lives on potions (Morvane bez wsparcia).
	hpMul = 1.2,
	atkMul = 0.42,
	defMul = 1.1,
	speed = 1.15,
	moveSpeed = 12,
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	phases = { 0.7, 0.35 },
	attacks = {
		{
			id = "shadowBolt",
			shape = "circle",
			target = "random",
			count = 3,
			radius = 4.5,
			windup = 1.1,
			damage = 4.5,
			cooldown = 6,
			phases = { 1, 2 },
			damageKind = "magic",
		},
		{
			id = "shadowBoltFast",
			shape = "circle",
			target = "random",
			count = 3,
			radius = 4.5,
			windup = 0.8,
			damage = 4.5,
			cooldown = 4,
			phases = { 3 },
			damageKind = "magic",
		},
		{
			id = "curseField",
			shape = "circle",
			target = "nearest",
			radius = 9,
			windup = 1.6,
			damage = 11.5,
			cooldown = 6.5,
			phases = { 1, 2, 3 },
			element = "poison",
			damageKind = "magic",
		},
		{
			id = "deathRing",
			shape = "ring",
			target = "self",
			radius = 32,
			inner = 7,
			windup = 2.2,
			damage = 5.8,
			cooldown = 15,
			phases = { 3 },
			damageKind = "magic",
		},
	},
	summons = {
		-- S92: the waves at 36 / 37 (were 44 / 45): a party of 3 loses <= 110 % HP per member per wave (S32 limit;
		-- summoned helpers hit without the group damage reduction, Balance.summonHelpers)
		{ phase = 2, monster = "skeletonGuard", level = 36, count = 10, shield = true },
		{ phase = 3, monster = "skeletonGuard", level = 37, count = 10, shield = true },
	},
	enrageAfter = 600,
	enrageDamage = 1.6,
	timeLimit = 900,
	look = { size = 2.4, aura = "#7A3FA0" },
})

-- Arenas for these two are built in S11.
boss({
	id = "azgor",
	family = "elemental",
	nameKey = "boss.azgor.name",
	region = "ashen",
	level = 70,
	-- S93 (balance plan D4, tests/balance.spec R.ashen.azgor.*): 3-5 players of level 69 need 4-6 min in the S83 /
	-- S87 model (hpMul 1.25); the basic hit is ~10 % of a level 70 Mage's HP (atkMul 1.25 -> 0.36), the inferno on a
	-- ranged Mage ~66 % (<= 70 %), the meteor softened to ~54 % of a Mage's HP per minute (variant (a) of plan 8.5),
	-- the S32 tank ~346 %/min from a faster basic swing (speed 1.35: more hits to counter, S88 swordplay) and a
	-- lighter flame cleave; a party without support lives on potions (Azgor bez wsparcia).
	hpMul = 1.25,
	atkMul = 0.36,
	defMul = 1.3,
	speed = 1.35,
	moveSpeed = 13,
	attack = "melee",
	damageKind = "phys",
	phases = { 0.7, 0.35 },
	attacks = {
		{
			id = "fireWave",
			shape = "line",
			target = "random",
			length = 40,
			width = 9,
			windup = 1.3,
			damage = 5.2,
			cooldown = 7,
			phases = { 1, 2, 3 },
			element = "fire",
			damageKind = "magic",
		},
		{
			id = "flameCleave",
			shape = "cone",
			target = "threat",
			radius = 16,
			angle = 110,
			windup = 1.2,
			damage = 3,
			cooldown = 9,
			phases = { 1, 2, 3 },
			element = "fire",
		},
		{
			id = "meteor",
			shape = "circle",
			target = "all",
			radius = 7,
			windup = 1.6,
			damage = 4,
			cooldown = 18,
			phases = { 1, 2, 3 },
			element = "fire",
			damageKind = "magic",
		},
		{
			id = "inferno",
			shape = "ring",
			target = "self",
			radius = 30,
			inner = 8,
			windup = 2,
			damage = 6.6,
			cooldown = 14,
			phases = { 3 },
			element = "fire",
			damageKind = "magic",
		},
	},
	summons = {
		-- S93: the waves at 58 / 59 (were 69 / 70): a party of 3 loses <= 110 % HP per member per wave (S32 limit;
		-- summoned helpers hit without the group damage reduction, Balance.summonHelpers)
		{ phase = 2, monster = "fireGolem", level = 58, count = 10, shield = true },
		{ phase = 3, monster = "fireGolem", level = 59, count = 10, shield = true },
	},
	haste = { [3] = 1.2 },
	enrageAfter = 600,
	enrageDamage = 1.6,
	timeLimit = 900,
	look = { size = 2.8, aura = "#FF5A1A" },
})

boss({
	id = "vaelgrath",
	family = "dragon",
	mresMul = 1.4, -- S66: dragons get armour and magic resistance x1.4
	nameKey = "boss.vaelgrath.name",
	region = "frostpeak",
	level = 100,
	atkMul = 1.3,
	defMul = 1.4,
	speed = 0.85,
	moveSpeed = 14,
	attack = "melee",
	damageKind = "magic",
	phases = { 0.7, 0.35 },
	attacks = {
		{
			id = "frostBreath",
			shape = "cone",
			target = "threat",
			radius = 22,
			angle = 70,
			windup = 1.4,
			damage = 2.6,
			cooldown = 8,
			phases = { 1, 2, 3 },
			element = "ice",
			damageKind = "magic",
		},
		{
			id = "wingBuffet",
			shape = "circle",
			target = "self",
			radius = 14,
			windup = 1.2,
			damage = 2.2,
			cooldown = 11,
			phases = { 1, 2, 3 },
		},
		{
			id = "tailSwipe",
			shape = "line",
			target = "random",
			length = 26,
			width = 8,
			windup = 1.2,
			damage = 2.4,
			cooldown = 9,
			phases = { 1, 2, 3 },
		},
		{
			id = "blizzard",
			shape = "circle",
			target = "all",
			radius = 6,
			windup = 1.8,
			damage = 2.6,
			cooldown = 16,
			phases = { 2, 3 },
			element = "ice",
			damageKind = "magic",
		},
		{
			id = "glacialRing",
			shape = "ring",
			target = "self",
			radius = 34,
			inner = 8,
			windup = 2.2,
			damage = 3.6,
			cooldown = 15,
			phases = { 3 },
			element = "ice",
			damageKind = "magic",
		},
	},
	summons = {
		{ phase = 2, monster = "dragonspawn", level = 99, count = 10, shield = true },
		{ phase = 3, monster = "dragonspawn", level = 100, count = 10, shield = true },
	},
	haste = { [3] = 1.2 },
	enrageAfter = 600,
	enrageDamage = 1.6,
	timeLimit = 900,
	look = { size = 2.8, aura = "#9FE0FF" },
})

local byRegion: { [string]: BossDef } = {}
for _, def in list do
	byRegion[def.region] = def
end

return table.freeze({
	list = list,
	byId = byId,
	get = function(id: string): BossDef?
		return byId[id]
	end,
	forRegion = function(region: string): BossDef?
		return byRegion[region]
	end,
	-- Chance of a random legendary blessing in the boss loot (DESIGN §16).
	LEGENDARY_BLESSING_CHANCE = 0.2,
	-- Dungeon rules (DESIGN §16).
	ENTRY_RANGE = 20, -- members this close to the leader enter with them
	RELEASE_AFTER = 60, -- seconds after the kill
	COUNTDOWN = 5, -- seconds before the boss appears
	TIME_WARNINGS = { 5, 1 }, -- minutes left when the fighters get a warning
	SUMMON_PER_PLAYER = 2, -- extra helpers per wave for every player above the first
})
