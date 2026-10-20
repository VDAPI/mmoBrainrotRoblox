--!strict
-- Dungeon bosses (DESIGN §16) and (S149) the world boss (DESIGN §15.6, `world = true`). Grimrok (20) and Morvane (45)
-- are complete; Azgor (70) and Vaelgrath (100) have their data ready for S11, which builds their arenas.
--
-- Attacks are telegraphed areas resolved after `windup`:
--   shape  circle (radius) | cone (radius, angle) | line (length, width) | ring (radius, inner = safe centre)
--   target self (around the boss) | threat (current target) | random (random player) | nearest | all
--   count  how many targets get their own area (random targets without repeats)
--   phases in which phases (1..3) the attack is used; `cooldown` seconds between uses
--   leap   the boss jumps to the area when it lands
-- Phase thresholds are HP fractions. `summons` happen when a phase starts (and every `every` seconds). Since
-- 2026-10-10 every wave is a shield wave: the helpers attack at once and the boss is invulnerable and holds still at
-- the arena centre until all of them are dead; helpers drop nothing.
-- S134 (bosses 2.0): a boss never scales with the party (HP = HP_BASE x hpMul, fixed helper count); it is built for
-- 3-5 players, solo only with overpowered gear. `avoid` = a big blow to dodge (60-90 % of a Mage's HP, windup >= 1.8 s);
-- `mechanic` = a party mechanic (Logic/BossMechanics): `split` (stand together in the golden circle, the blow is
-- shared), `mark` (the marked player walks away from the party), `channel` (break the spell with damage).

local Families = require("./Families")

-- S134: the numbers of a party mechanic (rules in Logic/BossMechanics).
export type SplitSpec = { missAll: number }
-- S149: `count` = how many fighters are marked at once (without repeats, default 1)
export type MarkSpec = { seconds: number, self: number, count: number? }
export type ChannelSpec = { seconds: number, breakPct: number, stagger: number }

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
	-- S134: a big blow to dodge (the model counts it as dodged); never on a mechanic
	avoid: boolean?,
	-- S134: a party mechanic (Logic/BossMechanics) and its numbers
	mechanic: ("split" | "mark" | "channel")?,
	split: SplitSpec?, -- missAll: share of the damage every fighter takes when nobody stands inside
	mark: MarkSpec?, -- seconds to the blast; self: the marked one's damage multiplier
	-- seconds of the spell (= windup), breakPct: share of the max HP that breaks it, stagger: seconds stunned after
	channel: ChannelSpec?,
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
	hpMul: number?, -- S32: on top of BossScaling.hpMultiplier() = HP_BASE (S134: no party scaling), default 1
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
	-- S149: a world boss (Data/WorldBoss, WorldBossService): no dungeon, `region` names its map; never in `list`,
	-- `forRegion` or the dungeon rules (`world` / `all` list it)
	world: boolean?,
	-- S149: the lowest character level that gets the world boss reward (lower ones may help for nothing)
	minLevel: number?,
}

local list: { BossDef } = {}
local world: { BossDef } = {}
local all: { BossDef } = {}
local byId: { [string]: BossDef } = {}

-- S149: dungeon bosses go to `list` (the dungeons, their quests, the party finder, the wiki), world bosses to `world`;
-- `all` and `byId` hold both.
local function boss(def: BossDef)
	byId[def.id] = def
	table.insert(all, def)
	table.insert(if def.world then world else list, def)
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
			damage = 7.2,
			cooldown = 8,
			phases = { 1, 2, 3 },
		},
		{
			id = "leap",
			shape = "circle",
			target = "random",
			radius = 8,
			windup = 1.8,
			damage = 7.6,
			cooldown = 15,
			phases = { 1, 2, 3 },
			leap = true,
			avoid = true,
		},
		{
			id = "whirlwind",
			shape = "circle",
			target = "self",
			radius = 10,
			windup = 2.0,
			damage = 9.2,
			cooldown = 14,
			phases = { 3 },
			avoid = true,
		},
		-- S134: the axe splits the ground towards a random fighter (a big blow to dodge)
		{
			id = "groundSplitter",
			shape = "line",
			target = "random",
			length = 40,
			width = 6,
			windup = 1.8,
			damage = 8.2,
			cooldown = 16,
			phases = { 1, 2, 3 },
			avoid = true,
		},
		-- S134: the chieftain's boulder (split): stand together in the golden circle
		{
			id = "boulder",
			shape = "circle",
			target = "random",
			radius = 6,
			windup = 3.0,
			damage = 21,
			cooldown = 24,
			phases = { 2, 3 },
			mechanic = "split",
			split = { missAll = 0.25 },
		},
	},
	summons = {
		{ phase = 2, monster = "goblinScout", level = 19, count = 8, shield = true },
		{ phase = 3, monster = "goblinScout", level = 20, count = 8, shield = true },
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
			damage = 4.2,
			cooldown = 7,
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
			damage = 4.2,
			cooldown = 6,
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
			windup = 2.5,
			damage = 6.8,
			cooldown = 16,
			phases = { 3 },
			damageKind = "magic",
			avoid = true,
		},
		-- S134: a scythe of souls in a cone towards a random fighter (a big blow to dodge)
		{
			id = "soulReap",
			shape = "cone",
			target = "random",
			radius = 26,
			angle = 70,
			windup = 1.8,
			damage = 6.2,
			cooldown = 16,
			phases = { 1, 2 },
			damageKind = "magic",
			avoid = true,
		},
		-- S134: the crypt brand (mark): the marked fighter carries the blast away from the party
		{
			id = "cryptBrand",
			shape = "circle",
			target = "random",
			radius = 9,
			windup = 1.2,
			damage = 6,
			cooldown = 22,
			phases = { 1, 2 },
			damageKind = "magic",
			mechanic = "mark",
			mark = { seconds = 5, self = 0.43 },
		},
		-- S134: the requiem (channel): break it with damage or it hits everyone
		{
			id = "requiem",
			shape = "circle",
			target = "self",
			radius = 6,
			windup = 5,
			damage = 7.7,
			cooldown = 36,
			phases = { 2, 3 },
			damageKind = "magic",
			mechanic = "channel",
			channel = { seconds = 5, breakPct = 0.012, stagger = 3 },
		},
	},
	summons = {
		-- S92: the waves at 36 / 37 (were 44 / 45): a party of 3 loses <= 110 % HP per member per wave (S32 limit;
		-- summoned helpers hit without the group damage reduction, Balance.summonHelpers)
		{ phase = 2, monster = "skeletonGuard", level = 36, count = 8, shield = true },
		{ phase = 3, monster = "skeletonGuard", level = 37, count = 8, shield = true },
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
	hpMul = 1.3,
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
			windup = 1.8,
			damage = 7,
			cooldown = 10,
			phases = { 1, 3 },
			element = "fire",
			damageKind = "magic",
			avoid = true,
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
			windup = 2.4,
			damage = 8,
			cooldown = 16,
			phases = { 3 },
			element = "fire",
			damageKind = "magic",
			avoid = true,
		},
		-- S134: three fire columns under random fighters (a big blow to dodge)
		{
			id = "eruption",
			shape = "circle",
			target = "random",
			count = 3,
			radius = 7,
			windup = 2.0,
			damage = 7.3,
			cooldown = 16,
			phases = { 1, 2 },
			element = "fire",
			damageKind = "magic",
			avoid = true,
		},
		-- S134: the heart of the volcano (split): stand together in the golden circle
		{
			id = "volcanoHeart",
			shape = "circle",
			target = "random",
			radius = 7,
			windup = 3.0,
			damage = 17.5,
			cooldown = 26,
			phases = { 1, 2 },
			element = "fire",
			damageKind = "magic",
			mechanic = "split",
			split = { missAll = 0.25 },
		},
		-- S134: the cinder brand (mark): the marked fighter carries the blast away from the party
		{
			id = "cinderBrand",
			shape = "circle",
			target = "random",
			radius = 10,
			windup = 1.2,
			damage = 7,
			cooldown = 24,
			phases = { 2, 3 },
			element = "fire",
			damageKind = "magic",
			mechanic = "mark",
			mark = { seconds = 5, self = 0.43 },
		},
	},
	summons = {
		-- S93: the waves at 58 / 59 (were 69 / 70): a party of 3 loses <= 110 % HP per member per wave (S32 limit;
		-- summoned helpers hit without the group damage reduction, Balance.summonHelpers)
		{ phase = 2, monster = "fireGolem", level = 58, count = 8, shield = true },
		{ phase = 3, monster = "fireGolem", level = 59, count = 8, shield = true },
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
	hpMul = 1.35,
	atkMul = 0.38,
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
			damage = 3.6,
			cooldown = 10,
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
			damage = 3.7,
			cooldown = 14,
			phases = { 1 },
		},
		{
			id = "tailSwipe",
			shape = "line",
			target = "random",
			length = 26,
			width = 8,
			windup = 1.8,
			damage = 6.2,
			cooldown = 14,
			phases = { 1, 2 },
			avoid = true,
		},
		{
			id = "blizzard",
			shape = "circle",
			target = "all",
			radius = 6,
			windup = 1.8,
			damage = 4.4,
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
			windup = 2.5,
			damage = 8.1,
			cooldown = 18,
			phases = { 3 },
			element = "ice",
			damageKind = "magic",
			avoid = true,
		},
		-- S134: an avalanche in a wide cone towards a random fighter (a big blow to dodge)
		{
			id = "avalanche",
			shape = "cone",
			target = "random",
			radius = 30,
			angle = 90,
			windup = 2.0,
			damage = 7,
			cooldown = 14,
			phases = { 2, 3 },
			element = "ice",
			damageKind = "magic",
			avoid = true,
		},
		-- S134: the ice comet (split): stand together in the golden circle
		{
			id = "iceComet",
			shape = "circle",
			target = "random",
			radius = 7,
			windup = 3.2,
			damage = 17.7,
			cooldown = 26,
			phases = { 1, 3 },
			element = "ice",
			damageKind = "magic",
			mechanic = "split",
			split = { missAll = 0.25 },
		},
		-- S134: the frost tomb (mark): the marked fighter carries the blast away from the party
		{
			id = "frostTomb",
			shape = "circle",
			target = "random",
			radius = 10,
			windup = 1.2,
			damage = 7.1,
			cooldown = 24,
			phases = { 1, 2 },
			element = "ice",
			damageKind = "magic",
			mechanic = "mark",
			mark = { seconds = 5, self = 0.4 },
		},
		-- S134: absolute zero (channel, phase 3): break it with damage or it hits everyone
		{
			id = "absoluteZero",
			shape = "circle",
			target = "self",
			radius = 6,
			windup = 5,
			damage = 8.6,
			cooldown = 36,
			phases = { 3 },
			element = "ice",
			damageKind = "magic",
			mechanic = "channel",
			channel = { seconds = 5, breakPct = 0.012, stagger = 3 },
		},
	},
	summons = {
		{ phase = 2, monster = "dragonspawn", level = 86, count = 8, shield = true },
		{ phase = 3, monster = "dragonspawn", level = 87, count = 8, shield = true },
	},
	haste = { [3] = 1.2 },
	enrageAfter = 600,
	enrageDamage = 1.6,
	timeLimit = 900,
	look = { size = 2.8, aura = "#9FE0FF" },
})

-- S149: the world boss of the late game (Data/WorldBoss, WorldBossService): Hrimvald, the Forefather of Giants, wakes
-- on the Frost Peaks every 3 h for 10-20 players. No dungeon, no party scaling, no shield (an open-world boss is never
-- invulnerable); the helpers of phases 2-3 only add pressure. The numbers come from the S149 model
-- (Balance.targetsS149: 10 players of level 99 in 9-12 min, 20 in 5-7, 5 never win).
boss({
	id = "hrimvald",
	family = "humanoid",
	nameKey = "boss.hrimvald.name",
	region = "frostpeak", -- the map (read only: no dungeon)
	world = true,
	minLevel = 70, -- owner 2026-10-18: reward from 70 (was 80)
	level = 100,
	hpMul = 7.8,
	atkMul = 0.38,
	defMul = 1.4,
	mresMul = 1.4,
	speed = 0.8,
	moveSpeed = 13,
	attack = "melee",
	damageKind = "phys",
	phases = { 0.7, 0.35 },
	attacks = {
		-- regular blows (no `avoid`): the fist at the tank, a boulder under a random fighter
		{
			id = "fistSlam",
			shape = "cone",
			target = "threat",
			radius = 16,
			angle = 80,
			windup = 1.4,
			damage = 3.5,
			cooldown = 14,
			phases = { 1, 2, 3 },
		},
		{
			id = "boulderToss",
			shape = "circle",
			target = "random",
			radius = 6,
			windup = 1.6,
			damage = 3.8,
			cooldown = 16,
			phases = { 1, 2, 3 },
			delivery = "ranged",
		},
		-- big blows to dodge
		{
			id = "glacierStomp",
			shape = "circle",
			target = "self",
			radius = 16,
			windup = 2.2,
			damage = 7.3,
			cooldown = 22,
			phases = { 1, 2, 3 },
			element = "ice",
			avoid = true,
		},
		{
			id = "iceSpikes",
			shape = "line",
			target = "random",
			count = 3,
			length = 50,
			width = 7,
			windup = 2.0,
			damage = 6.9,
			cooldown = 20,
			phases = { 1, 2, 3 },
			element = "ice",
			damageKind = "magic",
			avoid = true,
		},
		{
			id = "avalanche",
			shape = "circle",
			target = "random",
			count = 5,
			radius = 9,
			windup = 2.2,
			damage = 6.7,
			cooldown = 24,
			phases = { 2, 3 },
			element = "ice",
			damageKind = "magic",
			avoid = true,
		},
		-- the shared blow for 10+ players: ~700 % of a Mage's HP split by everyone in the circle
		{
			id = "shatterStone",
			shape = "circle",
			target = "random",
			radius = 10,
			windup = 3.5,
			damage = 64,
			cooldown = 30,
			phases = { 1, 2, 3 },
			mechanic = "split",
			split = { missAll = 0.086 },
		},
		-- three brands at once (S149 `count`); the circles may overlap
		{
			id = "frostBrand",
			shape = "circle",
			target = "random",
			radius = 10,
			windup = 1.2,
			damage = 6.8,
			cooldown = 26,
			phases = { 2, 3 },
			element = "ice",
			damageKind = "magic",
			mechanic = "mark",
			mark = { seconds = 5, self = 0.43, count = 3 },
		},
		-- the endless winter (channel): break it with damage or it hits every fighter
		{
			id = "endlessWinter",
			shape = "circle",
			target = "self",
			radius = 6,
			windup = 6,
			damage = 8.6,
			cooldown = 40,
			phases = { 2, 3 },
			element = "ice",
			damageKind = "magic",
			mechanic = "channel",
			channel = { seconds = 6, breakPct = 0.007, stagger = 4 },
		},
	},
	summons = {
		-- S149: helpers without a shield (an open-world boss is never invulnerable), no loot and no EXP
		{ phase = 2, monster = "frozenKnight", level = 95, count = 3 },
		{ phase = 2, monster = "iceWolf", level = 95, count = 3 },
		{ phase = 3, monster = "frozenKnight", level = 95, count = 3 },
		{ phase = 3, monster = "iceWolf", level = 95, count = 3 },
	},
	haste = { [3] = 1.2 },
	enrageAfter = 780,
	enrageDamage = 1.6,
	timeLimit = 7200, -- S149: then it leaves (WorldBossService); owner 2026-10-20: 15 min -> 2 h
	look = { size = 6, aura = "#9FD8FF" },
})

local byRegion: { [string]: BossDef } = {}
for _, def in list do
	byRegion[def.region] = def
end

return table.freeze({
	list = list, -- dungeon bosses (S149: never a world boss)
	world = world, -- S149: world bosses (Data/WorldBoss)
	all = all, -- S149: every boss
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
	-- S134: HP multiplier on top of a normal monster of the boss's level, whatever the party (BossScaling.hpMultiplier;
	-- the old 30 x (1 + 0.6 x (players - 1)) for 4 players)
	HP_BASE = 84,
	-- S134c: a character may enter a boss dungeon from boss level - ENTRY_GAP; a party carries the lower ones
	-- (BossScaling.requiredLevel)
	ENTRY_GAP = 10,
	-- S134c: the boss quest, the weekly boss contract and the lower winner's EXP rule stay at boss level - QUEST_GAP
	-- (the old entry level; BossScaling.questLevel, Exp.bossExpFor)
	QUEST_GAP = 5,
})
