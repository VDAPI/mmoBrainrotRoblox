--!strict
-- Sound effects (S111, DESIGN-16 §3, docs/ANIMACJE.md §7): key -> a few variants, volume, pitch range, roll-off
-- distance. SfxController (client) plays them through the "Effects" sound group (settings.volume); the choice of a key
-- (attack motion, skill, hit material, mix rules) is in Logic/SfxRules. Data only.
--
-- Sound ids come only from the Creator Store with the creator "Roblox", found through the Studio MCP `search_asset`
-- and checked in Play (IsLoaded, TimeLength); every id has a row in docs/ASSETS.md ("Dźwięki (S111)"). Ids are never
-- guessed: a key without ids is silent and the fallback chain picks another key (skill.<id> -> skill.default.<kind>,
-- Logic/SfxRules.skillKey), or the old placeholder plays (interface keys, UI/Sounds router). `hint` is what to look
-- for in the Creator Store and stays after the ids are filled.
--
-- Keys: swing.<light|heavy|blunt|thrust>, bow.draw, bow.release, crossbow.release, wand.cast,
-- hit.<material> and hit.crit (played together with the material), block, miss (also a dodge),
-- skill.default.<strike|cast|blast|heal|buff|dash|trap|call>, skill.<skillId> (SkillVfx.sound names a key),
-- skill.<skillId>.cast (S114: at the cast event, a long wind-up), skill.guardianAngel.save (S114: the angel's save),
-- skill.<skillId>.trigger / .wave and skill.falcon.strike (S115: a trap springing, a later wave or a storm's strike,
-- the falcon's strike),
-- mob.<family>.<attack|hurt|death|aggro>, boss.<bossId>.<roar|attack|death|phase>, telegraph.warn,
-- boss.mechanic.<mark|split|channel> (S134),
-- ui.<loot|loot.rare|loot.legendary|levelup|quest|coin|click|error|lowHp>. S112-S117 call sounds by these keys.

local Bosses = require("./Bosses")
local Families = require("./Families")

export type Def = {
	ids: { string }, -- "rbxassetid://<digits>" variants; empty = silent (the fallback chain picks another key)
	volume: number, -- 0..1 before the group and priority scaling
	pitch: { number }, -- { min, max } PlaybackSpeed, e.g. { 0.94, 1.06 }
	roll: number, -- RollOffMaxDistance in studs (ignored by 2D keys)
	cooldown: number?, -- seconds before the same key may play again from the same source (hurt, aggro, roar)
	hint: string, -- what to look for in the Creator Store (search words), kept after the ids are filled
	ui: boolean?, -- 2D (no position): interface sounds
}

-- ids: the variants found and checked in S111 (docs/ASSETS.md); pitch / cooldown / ui as in Def.
type Extra = { ids: { string }?, pitch: { number }?, cooldown: number?, ui: boolean? }

local Sfx = {}

local function d(hint: string, volume: number, roll: number, extra: Extra?): Def
	local e: Extra = extra or {}
	return {
		ids = e.ids or {},
		volume = volume,
		pitch = e.pitch or { 0.94, 1.06 },
		roll = roll,
		cooldown = e.cooldown,
		hint = hint,
		ui = e.ui,
	}
end

-- Pitch ranges (looks only): swings vary more, bosses less, clicks not at all.
local SWING_PITCH = { 0.92, 1.08 }
local HEAVY_PITCH = { 0.86, 0.94 } -- a lower, heavier take of a shared sound (two-handed, hammers, crossbows)
local BOSS_PITCH = { 0.96, 1.04 }
local FLAT = { 1, 1 }

Sfx.MATERIALS = { "flesh", "armor", "wood", "stone", "bone", "slime" }
-- Hit material of a monster family; MonsterLooks.hitSound overrides it per look (Logic/SfxRules.material).
Sfx.FAMILY_MATERIAL = {
	animal = "flesh",
	humanoid = "armor",
	undead = "bone",
	beast = "flesh",
	elemental = "stone",
	dragon = "armor",
} :: { [string]: string }
-- Skills that have their own key (the S110 review sample); the rest use skill.default.<kind> until S114 / S115.
Sfx.SKILL_SAMPLE = {
	"mightyStrike",
	"bladeWhirl",
	"earthquake",
	"cleave",
	"aimedShot",
	"arrowRain",
	"volley",
	"frostTrap",
	"firebolt",
	"fireball",
	"chainLightning",
	"frostNova",
	"holyStrike",
	"radiance",
	"circleOfLight",
	"hammerOfHeaven",
}

local defs: { [string]: Def } = {
	-- Basic attacks: the swing at the start of the blow, the release of a shot or a spell.
	["swing.light"] = d(
		"sword swing whoosh light",
		0.45,
		60,
		{ pitch = SWING_PITCH, ids = { "rbxassetid://12222216", "rbxassetid://15675024286" } }
	),
	["swing.heavy"] = d(
		"heavy weapon swing whoosh",
		0.45,
		60,
		{ pitch = HEAVY_PITCH, ids = { "rbxassetid://12222216" } }
	),
	["swing.blunt"] = d(
		"hammer swing heavy whoosh",
		0.45,
		60,
		{ pitch = HEAVY_PITCH, ids = { "rbxassetid://12222200" } }
	),
	["swing.thrust"] = d(
		"spear thrust quick whoosh",
		0.45,
		60,
		{ pitch = SWING_PITCH, ids = { "rbxassetid://12222208" } }
	),
	["bow.draw"] = d("bow string draw creak", 0.5, 70),
	["bow.release"] = d("arrow bow release twang", 0.5, 70, { ids = { "rbxassetid://12222140" } }),
	["crossbow.release"] = d(
		"crossbow bolt shot release",
		0.5,
		70,
		{ pitch = HEAVY_PITCH, ids = { "rbxassetid://12222140" } }
	),
	["wand.cast"] = d("magic spell cast short", 0.5, 70, { ids = { "rbxassetid://15675046931" } }),
	-- Hits: the material of the target; a critical hit adds hit.crit on top.
	["hit.flesh"] = d("punch hit flesh impact", 0.6, 70, { ids = { "rbxassetid://12221984" } }),
	["hit.armor"] = d("sword hit metal armor clang", 0.6, 70),
	["hit.wood"] = d("wood hit impact knock", 0.6, 70),
	["hit.stone"] = d("rock stone hit impact", 0.6, 70),
	["hit.bone"] = d("bones hit crack rattle", 0.6, 70, { ids = { "rbxassetid://12222140" } }),
	["hit.slime"] = d("slime squish splat impact", 0.6, 70, { ids = { "rbxassetid://12222152" } }),
	["hit.crit"] = d("critical hit heavy impact boom", 0.7, 70, { ids = { "rbxassetid://12221944" } }),
	-- Defence: a blocked blow, a miss or a dodge (also an absorbed / immune hit, quieter).
	["block"] = d("shield block metal clang", 0.55, 60, { ids = { "rbxassetid://12222225" } }),
	["miss"] = d("whoosh miss air short", 0.4, 60, { ids = { "rbxassetid://15674975792" } }),
	-- Skills: the default of each kind (Logic/SfxRules.KIND_DEFAULT) and the own keys of the sample.
	["skill.default.strike"] = d(
		"heavy sword slash impact",
		0.6,
		90,
		{ ids = { "rbxassetid://12222216", "rbxassetid://12222208" } }
	),
	["skill.default.cast"] = d("magic spell cast whoosh", 0.6, 90, { ids = { "rbxassetid://15675012262" } }),
	["skill.default.blast"] = d("magic explosion blast impact", 0.6, 90, { ids = { "rbxassetid://12221944" } }),
	["skill.default.heal"] = d("healing magic chime shimmer", 0.6, 90, { ids = { "rbxassetid://15675081158" } }),
	["skill.default.buff"] = d("power up magic buff", 0.6, 90, { ids = { "rbxassetid://10066931761" } }),
	["skill.default.dash"] = d("dash whoosh fast movement", 0.6, 90, { ids = { "rbxassetid://15675028888" } }),
	["skill.default.trap"] = d("trap set metal click", 0.6, 90, { ids = { "rbxassetid://12222170" } }),
	["skill.default.call"] = d("hawk screech bird call", 0.6, 90, { ids = { "rbxassetid://15675062723" } }),
	["telegraph.warn"] = d("warning alarm magic hum short", 0.55, 120, { ids = { "rbxassetid://12221990" } }),
	-- S134: the party mechanics of bosses 2.0 (no ids yet: the owner picks them, docs/ASSETS.md)
	["boss.mechanic.mark"] = d("dark curse brand ominous whisper", 0.7, 150),
	["boss.mechanic.split"] = d("heavy rumble incoming impact gather", 0.7, 150),
	["boss.mechanic.channel"] = d("magic channel spell chant rising", 0.7, 200),
	-- Interface (2D).
	["ui.loot"] = d(
		"item pickup bag rustle",
		0.5,
		0,
		{ ui = true, ids = { "rbxassetid://15675037413", "rbxassetid://10128766965" } }
	),
	["ui.loot.rare"] = d("rare item reward chime", 0.6, 0, { ui = true, ids = { "rbxassetid://10066968815" } }),
	["ui.loot.legendary"] = d(
		"legendary item reveal fanfare",
		0.7,
		0,
		{ ui = true, ids = { "rbxassetid://15675043410" } }
	),
	["ui.levelup"] = d("level up fanfare short", 0.7, 0, { ui = true, ids = { "rbxassetid://12222253" } }),
	["ui.quest"] = d("quest complete success jingle", 0.65, 0, { ui = true, ids = { "rbxassetid://10128760939" } }),
	["ui.coin"] = d("coins pickup jingle", 0.45, 0, { ui = true, ids = { "rbxassetid://10066947742" } }),
	["ui.click"] = d("ui button click soft", 0.4, 0, { ui = true, pitch = FLAT, ids = { "rbxassetid://15675032796" } }),
	["ui.error"] = d("ui error buzz short", 0.5, 0, { ui = true, pitch = FLAT, ids = { "rbxassetid://15675075163" } }),
	-- S134f: the low health heartbeat (Hud/LowHpVignette); no checked Roblox heartbeat yet, silent until the owner
	-- picks one (docs/ASSETS.md). Cooldown shorter than Config.LowHp.beatFast.
	["ui.lowHp"] = d("heartbeat low health thump", 0.6, 0, { ui = true, pitch = FLAT, cooldown = 0.5 }),
}

-- Own skill keys of the sample (hints by what the skill does).
local SKILL_HINTS: { [string]: string } = {
	mightyStrike = "heavy sword strike impact",
	bladeWhirl = "sword spin whirlwind whoosh",
	earthquake = "earthquake ground slam rumble",
	cleave = "wide sword slash cleave",
	aimedShot = "powerful arrow shot release",
	arrowRain = "arrows volley rain impact",
	volley = "multiple arrows shot release",
	frostTrap = "ice freeze crack trap",
	firebolt = "fire bolt whoosh small",
	fireball = "fireball explosion impact",
	chainLightning = "electric lightning zap chain",
	frostNova = "ice nova freeze burst",
	holyStrike = "holy light strike chime",
	radiance = "holy light burst shimmer",
	circleOfLight = "holy healing circle chime",
	hammerOfHeaven = "divine hammer thunder impact",
}
for _, id in Sfx.SKILL_SAMPLE do
	defs["skill." .. id] = d(SKILL_HINTS[id] or "magic skill impact", 0.65, 90)
end

-- S114: every active skill of the Warrior and the Cleric has its own key (DESIGN-16 §6). Ids only from the S111 list
-- (Creator Store, creator Roblox, checked in Play, docs/ASSETS.md "Dźwięki (S111)"), taken again for another skill at
-- its own pitch; keys without a fitting Roblox sound stay empty (the kind's default plays) and wait for the owner's
-- choice (docs/PROGRESS.md). roll: melee 70, areas 110.
local SWORDSLASH = "rbxassetid://12222216"
local SWORDLUNGE = "rbxassetid://12222208"
local SWOOSH = "rbxassetid://12222200"
local WHOOSH_01 = "rbxassetid://15675024286"
local WHOOSH_02 = "rbxassetid://15675028888"
local WHOOSH_04 = "rbxassetid://15675012262"
local COLLIDE = "rbxassetid://12221984"
local BASS = "rbxassetid://12221944"
local UNSHEATH = "rbxassetid://12222225"
local SNAP = "rbxassetid://12222140"
local CUTE_GOODBYE = "rbxassetid://15675081158"
local TONAL_STINGER = "rbxassetid://15675043410"
local SELECT_01 = "rbxassetid://10128760939"
local SELECT_02 = "rbxassetid://10066968815"
-- S115: more files of the S111 list (docs/ASSETS.md "Dźwięki (S111)")
local WHOOSH_03 = "rbxassetid://15674975792"
local SPLAT = "rbxassetid://12222152"
local SWITCH = "rbxassetid://12222170"
local SWEEP = "rbxassetid://15675046931"
local WHISTLE_LOW = "rbxassetid://15675062723"
local PING = "rbxassetid://12221990"
local PAPER_SWIPE = "rbxassetid://15675037413"
local LOW = { 0.85, 0.9 }
local HEAVY = { 0.86, 0.94 }
local MID = { 0.92, 1.0 }

type Own = { hint: string, roll: number, ids: { string }?, pitch: { number }?, volume: number? }
local OWN: { [string]: Own } = {
	-- Warrior
	mightyStrike = {
		hint = "heavy sword strike impact low",
		roll = 70,
		ids = { SWORDSLASH, SWORDLUNGE },
		pitch = HEAVY,
	},
	charge = { hint = "running footsteps shoulder bash armor thud", roll = 70, ids = { COLLIDE }, pitch = LOW },
	bladeWhirl = { hint = "sword spin whirlwind three whooshes", roll = 80, ids = { SWOOSH, WHOOSH_01 } },
	taunt = { hint = "short roar shield bang", roll = 110, ids = { UNSHEATH }, pitch = MID },
	bloodlust = { hint = "low roar heartbeat rage", roll = 70 },
	earthquake = { hint = "earthquake ground slam rumble rocks", roll = 110, ids = { BASS }, pitch = LOW },
	intercept = { hint = "quick steps shield clang", roll = 80, ids = { WHOOSH_02, UNSHEATH }, pitch = MID },
	lastBastion = { hint = "heavy stomp low metal bell", roll = 70, ids = { UNSHEATH }, pitch = LOW },
	shieldWall = { hint = "shield slam stone short shout chorus", roll = 110, ids = { UNSHEATH, BASS }, pitch = LOW },
	cleave = { hint = "wide sword slash cleave tear", roll = 80, ids = { SWORDSLASH, SWOOSH }, pitch = HEAVY },
	rend = { hint = "heavy cut wet tear", roll = 70, ids = { SWORDSLASH }, pitch = LOW },
	titansWrath = { hint = "three ground thunder slams", roll = 120, ids = { BASS }, pitch = LOW },
	carnage = { hint = "roar metallic reverb rage", roll = 80 },
	battleCry = { hint = "war cry shout voice no words", roll = 110 },
	warBanner = { hint = "pole planted ground cloth flap", roll = 110, ids = { COLLIDE }, pitch = HEAVY },
	crushingBlow = { hint = "heavy armor crush impact", roll = 70, ids = { BASS, COLLIDE }, pitch = LOW },
	advanceOrder = { hint = "war horn blow ground hit", roll = 120 },
	-- Cleric
	holyStrike = { hint = "holy bell strike chime", roll = 80, ids = { SELECT_02 }, pitch = MID },
	heal = { hint = "warm healing chord chime", roll = 80, ids = { CUTE_GOODBYE } },
	radiance = { hint = "bright holy chord shimmer", roll = 110, ids = { TONAL_STINGER } },
	circleOfLight = { hint = "short choir healing circle", roll = 110, ids = { SELECT_01 } },
	shieldOfFaith = { hint = "glass bell shield", roll = 80, ids = { SELECT_02 }, pitch = { 1.02, 1.1 } },
	judgement = { hint = "thunder with choir holy", roll = 110, ids = { BASS }, pitch = HEAVY },
	renew = { hint = "soft water flow healing", roll = 80 },
	sanctuary = { hint = "choir warm drone holy ground", roll = 110 },
	divineIntervention = { hint = "full choir with bell", roll = 120, ids = { TONAL_STINGER }, pitch = HEAVY },
	guardianAngel = { hint = "harp and choir angel", roll = 120 },
	resurrection = { hint = "rising choir revive", roll = 110, ids = { TONAL_STINGER }, pitch = MID },
	fortuneDice = { hint = "dice rattle roll", roll = 80, ids = { SNAP }, pitch = { 1.04, 1.12 } },
	prayer = { hint = "quiet choir whisper prayer", roll = 80 },
	wheelOfFortune = { hint = "spinning wheel rattle gong", roll = 120 },
	purify = { hint = "hiss clean pure tone", roll = 80 },
	brandOfLight = { hint = "searing hiss small bell", roll = 80 },
	auraOfEndurance = { hint = "low organ chord", roll = 110 },
	hammerOfHeaven = { hint = "rising whoosh thunder impact divine", roll = 120, ids = { BASS }, pitch = LOW },
	-- Hunter (S115): a shot plays at the release (the hit's material comes with its damage), an area at its blow.
	-- roll: shots 80-100, areas 100-120 (S115 B5)
	aimedShot = { hint = "powerful bow release deep twang", roll = 90, ids = { SNAP }, pitch = { 0.85, 0.87 } },
	doubleShot = { hint = "bow release quick twang", roll = 90, ids = { SNAP }, pitch = { 1, 1.08 } },
	disengage = { hint = "jump flip whoosh soft landing", roll = 80, ids = { WHOOSH_02 }, pitch = MID },
	arrowRain = { hint = "many arrows whistle rain impact", roll = 110, ids = { WHOOSH_03, SWOOSH }, pitch = MID },
	venomArrow = { hint = "bow release with hiss poison", roll = 90, ids = { SNAP }, pitch = { 1.04, 1.12 } },
	volley = { hint = "rapid series of bow releases", roll = 100, ids = { SNAP, SWOOSH }, pitch = { 1.06, 1.14 } },
	piercingArrow = { hint = "heavy bow release whoosh through", roll = 100, ids = { SNAP }, pitch = { 0.85, 0.87 } },
	drawBead = { hint = "quiet click bow string tension", roll = 70, ids = { SWITCH }, pitch = { 0.9, 0.98 } },
	stormArrow = { hint = "thunder crack lightning arrow", roll = 110, ids = { BASS }, pitch = { 0.95, 1.05 } },
	heartseeker = { hint = "mighty bow release deep twang", roll = 100, ids = { SNAP }, pitch = { 0.85, 0.87 } },
	frostTrap = { hint = "trap click ice crackle", roll = 80, ids = { SWITCH }, pitch = { 0.86, 0.94 } },
	venomSnare = { hint = "thrown net splat on ground", roll = 80, ids = { SPLAT }, pitch = MID },
	camouflage = { hint = "leaves rustle cloak", roll = 60, ids = { PAPER_SWIPE }, pitch = { 0.85, 0.88 } },
	snarefield = { hint = "metal snares rattle clicks", roll = 90, ids = { SWITCH }, pitch = { 1.05, 1.15 } },
	falcon = { hint = "falcon screech bird call", roll = 110, ids = { WHISTLE_LOW }, pitch = { 1, 1.08 } },
	huntersMark = { hint = "short hunter whistle", roll = 90, ids = { WHISTLE_LOW }, pitch = { 1.13, 1.15 } },
	drive = { hint = "hunting horn and arrows whistle", roll = 120, ids = { WHOOSH_01, SWOOSH }, pitch = HEAVY },
	-- Mage (S115): the element is heard in the hit (hit.<material>); spells by their shape
	firebolt = { hint = "magic bolt fsst short", roll = 90, ids = { SWEEP }, pitch = { 1.02, 1.1 } },
	fireball = { hint = "fireball explosion impact", roll = 120, ids = { BASS }, pitch = HEAVY },
	iceShard = { hint = "glass whoosh ice crack", roll = 90, ids = { SNAP }, pitch = { 1.13, 1.15 } },
	chainLightning = { hint = "electric zap chain crackle", roll = 100, ids = { PING, SNAP }, pitch = { 0.85, 0.9 } },
	blink = { hint = "teleport fump magic", roll = 80, ids = { WHOOSH_04 }, pitch = { 1.1, 1.15 } },
	frostNova = { hint = "ice freeze crackle burst", roll = 110, ids = { SNAP }, pitch = { 0.85, 0.88 } },
	meteor = { hint = "meteor impact huge explosion", roll = 120, ids = { BASS }, pitch = { 0.85, 0.87 } },
	firewall = { hint = "rising thunder rumble storm", roll = 120, ids = { BASS }, pitch = { 0.85, 0.87 } },
	evocation = { hint = "arcane hum rising energy", roll = 80, ids = { SELECT_01 }, pitch = { 0.85, 0.87 } },
	meteorStorm = { hint = "meteor shower impacts", roll = 120, ids = { BASS }, pitch = { 0.85, 0.9 } },
	elementalVortex = {
		hint = "magic wind vortex whoosh",
		roll = 100,
		ids = { SWOOSH, WHOOSH_01 },
		pitch = { 0.9, 0.98 },
	},
	cataclysm = { hint = "massive magic explosion rumble", roll = 120, ids = { BASS }, pitch = { 0.85, 0.87 } },
	manaShield = { hint = "glass hum magic shield", roll = 80, ids = { SELECT_02 }, pitch = { 0.85, 0.9 } },
	arcaneDischarge = { hint = "arcane discharge blast", roll = 110, ids = { BASS }, pitch = { 0.94, 1.02 } },
	arcaneTorrent = { hint = "arcane beam start hum", roll = 100, ids = { SWEEP }, pitch = { 0.85, 0.87 } },
}
-- S114: the wind-up at the cast event (skills with a long wind-up), the Guardian Angel's save.
local CAST: { [string]: Own } = {
	earthquake = { hint = "jump whoosh heavy", roll = 90, ids = { SWOOSH }, pitch = LOW },
	titansWrath = { hint = "jump whoosh heavy", roll = 90, ids = { SWOOSH }, pitch = LOW },
	judgement = { hint = "jump whoosh holy rising", roll = 90, ids = { WHOOSH_04 }, pitch = MID },
	hammerOfHeaven = { hint = "rising whoosh from the sky", roll = 110, ids = { WHOOSH_04 }, pitch = LOW },
	guardianAngel = { hint = "angel rising choir short", roll = 110 },
	-- S115: the draw of a long shot (no Roblox bow creak: bow.draw is empty too) and the call of a big spell
	aimedShot = { hint = "bow string draw creak long", roll = 70 },
	stormArrow = { hint = "distant thunder rumble", roll = 100, ids = { BASS }, pitch = { 0.85, 0.87 } },
	heartseeker = { hint = "bow string draw creak long tense", roll = 70 },
	fireball = { hint = "rising fire hiss", roll = 90, ids = { WHOOSH_04 }, pitch = { 0.85, 0.87 } },
	meteor = { hint = "deep summoning rumble rising", roll = 110, ids = { WHOOSH_04 }, pitch = { 0.85, 0.87 } },
	meteorStorm = { hint = "deep summoning rumble rising", roll = 110, ids = { WHOOSH_04 }, pitch = { 0.85, 0.87 } },
	cataclysm = { hint = "deep earth rumble summoning", roll = 120, ids = { WHOOSH_04 }, pitch = { 0.85, 0.87 } },
}
-- S115: phase sounds: a trap springing (.trigger), a later wave or a storm's strike (.wave), the falcon's strike.
local PHASE: { [string]: Own } = {
	["frostTrap.trigger"] = { hint = "trap snap ice shatter", roll = 90, ids = { SNAP }, pitch = { 1.1, 1.15 } },
	["venomSnare.trigger"] = { hint = "trap snap poison hiss", roll = 90, ids = { SWITCH }, pitch = { 0.85, 0.88 } },
	["snarefield.trigger"] = { hint = "trap snap metal jaws", roll = 90, ids = { SWITCH }, pitch = { 0.86, 0.94 } },
	["falcon.strike"] = { hint = "bird dive whoosh talons", roll = 90, ids = { SWOOSH }, pitch = { 1.1, 1.15 } },
	["firewall.wave"] = {
		hint = "lightning bolt crack",
		roll = 110,
		ids = { SNAP },
		pitch = { 0.85, 0.87 },
		volume = 0.5,
	},
	["meteorStorm.wave"] = {
		hint = "small meteor impact",
		roll = 110,
		ids = { BASS },
		pitch = { 1, 1.1 },
		volume = 0.45,
	},
	["cataclysm.wave"] = {
		hint = "explosion rumble wave",
		roll = 120,
		ids = { BASS },
		pitch = { 0.85, 0.88 },
		volume = 0.5,
	},
}
for id, own in OWN do
	defs["skill." .. id] = d(own.hint, own.volume or 0.65, own.roll, { ids = own.ids, pitch = own.pitch })
end
for id, own in CAST do
	defs[`skill.{id}.cast`] = d(own.hint, own.volume or 0.55, own.roll, { ids = own.ids, pitch = own.pitch })
end
defs["skill.guardianAngel.save"] = d("angel save harp choir burst", 0.7, 120)
for key, own in PHASE do
	defs[`skill.{key}`] = d(own.hint, own.volume or 0.55, own.roll, { ids = own.ids, pitch = own.pitch })
end

-- Monsters: one set per family (DESIGN-16 §3); the attack plays at the attacker, the rest at the monster.
local MOB_HINTS: { [string]: { attack: string, hurt: string, death: string, aggro: string } } = {
	animal = {
		attack = "wolf growl bite attack",
		hurt = "animal yelp hurt short",
		death = "animal death whimper",
		aggro = "wolf growl snarl",
	},
	humanoid = {
		attack = "male grunt attack effort",
		hurt = "male grunt pain short",
		death = "male death groan short",
		aggro = "battle cry shout short",
	},
	undead = {
		attack = "zombie growl attack",
		hurt = "skeleton bones rattle hurt",
		death = "skeleton bones break collapse",
		aggro = "ghost moan undead",
	},
	beast = {
		attack = "monster roar attack short",
		hurt = "creature hurt screech",
		death = "monster death roar",
		aggro = "creature snarl growl",
	},
	elemental = {
		attack = "rock golem stomp attack",
		hurt = "stone crack impact rumble",
		death = "rock crumble collapse",
		aggro = "magic rumble hum low",
	},
	dragon = {
		attack = "dragon roar attack bite",
		hurt = "dragon hurt growl",
		death = "dragon death roar",
		aggro = "dragon growl low",
	},
}
for _, family in Families.ids do
	local hints = MOB_HINTS[family]
	defs[`mob.{family}.attack`] = d(hints.attack, 0.5, 80)
	defs[`mob.{family}.hurt`] = d(hints.hurt, 0.45, 80, { cooldown = 0.35 })
	defs[`mob.{family}.death`] = d(hints.death, 0.6, 80)
	defs[`mob.{family}.aggro`] = d(hints.aggro, 0.5, 80, { cooldown = 4 })
end

-- Bosses: a roar at the first aggro and at every new phase, a gong for the phase, the attack after a telegraph.
local BOSS_HINTS: { [string]: { roar: string, attack: string, death: string, phase: string } } = {
	grimrok = {
		roar = "goblin warchief roar angry",
		attack = "heavy club smash impact",
		death = "goblin death scream",
		phase = "war drum boom impact",
	},
	morvane = {
		roar = "ghost queen scream eerie",
		attack = "dark magic spell cast",
		death = "ghost death wail fading",
		phase = "deep bell toll dark",
	},
	azgor = {
		roar = "fire demon roar huge",
		attack = "fire explosion impact heavy",
		death = "fire monster death roar",
		phase = "fire burst whoosh boom",
	},
	vaelgrath = {
		roar = "dragon roar huge",
		attack = "dragon breath ice blast",
		death = "dragon death roar long",
		phase = "deep gong boom impact",
	},
}
for _, boss in Bosses.list do
	local hints = BOSS_HINTS[boss.id] or BOSS_HINTS.vaelgrath
	defs[`boss.{boss.id}.roar`] = d(hints.roar, 0.8, 200, { cooldown = 3, pitch = BOSS_PITCH })
	defs[`boss.{boss.id}.attack`] = d(hints.attack, 0.8, 200, { pitch = BOSS_PITCH })
	defs[`boss.{boss.id}.death`] = d(hints.death, 0.8, 200, { pitch = BOSS_PITCH })
	defs[`boss.{boss.id}.phase`] = d(hints.phase, 0.8, 200, { pitch = BOSS_PITCH })
end

Sfx.defs = defs

function Sfx.get(key: string): Def?
	return defs[key]
end

-- Defined (even with empty ids).
function Sfx.has(key: string): boolean
	return defs[key] ~= nil
end

-- Defined and at least one id.
function Sfx.playable(key: string): boolean
	local def = defs[key]
	return def ~= nil and #def.ids > 0
end

-- Every key, sorted (AnimLab `sfx list`, docs).
function Sfx.keys(prefix: string?): { string }
	local out = {}
	for key in defs do
		if prefix == nil or string.sub(key, 1, #prefix) == prefix then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

return Sfx
