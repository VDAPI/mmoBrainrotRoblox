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
-- mob.<family>.<attack|hurt|death|aggro>, boss.<bossId>.<roar|attack|death|phase>, telegraph.warn,
-- ui.<loot|loot.rare|loot.legendary|levelup|quest|coin|click|error>. S112-S117 call sounds by these keys.

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
