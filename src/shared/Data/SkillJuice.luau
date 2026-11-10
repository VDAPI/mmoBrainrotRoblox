--!strict
-- Skill juice (owner 2026-11-10: "umiejętności każdej profesji mają mieć większą dynamikę: dźwięk, wybuch, partikle"):
-- one shared layer every active skill gets on top of its own pieces (Data/SkillVfx), played by VfxController through
-- Vfx/Juice: a flare at the hand or the weapon when the cast starts (or when a gathered spell is let go), a punch where
-- the blow lands (a spray of particles in the look of the class, a puff, a ground ring, a short fading light; heavy
-- blows throw chips too) and a camera kick for our own big blows (Vfx/CameraShake, option "Hit feel"). Which style,
-- weight, anchor and timing a skill gets is Logic/SkillJuice; its cast voice is the Data/Sfx key skill.<id>.voice
-- (VOICES below). Looks only. Texture keys are Data/VfxTextures keys (all uploaded).
--   styles   Warrior steel (sparks, dust, chips, dust ring), Cleric holy light (stars, motes rising, rays) and its
--            healing green, Hunter the wood (leaves, splinter sparks, dust) or the arrow's element (venom bubbles, ice,
--            lightning), Mage the element of the spell or the weapon (fire embers and flames, ice shards and mist,
--            lightning sparks and arcs) and arcane stars without one
--   motions  how particles of a layer move (speed, drag, gravity, life, size, facing)
--   weights  light (support), medium (a normal blow), heavy (finishers and big blows): sizes, particle counts on the
--            high graphics level (Logic/SkillJuice.count scales them down), light, chips and the own camera kick

export type Motion = {
	speed: { number }, -- studs/s { min, max } at weight 1
	drag: number,
	accel: { number }, -- { x, y, z } studs/s²
	life: { number }, -- seconds { min, max }
	size: { number }, -- studs { start, end }
	spread: number, -- degrees around the emit direction (180 = every way)
	parallel: boolean?, -- particles face their flight (streaks)
	spin: number?, -- degrees/s of a random turn (shards, leaves)
	up: boolean?, -- emitted upwards (the default: every way from the point)
}

export type Style = {
	core: string, -- texture of the bright core of the flare and the punch
	motes: string, -- texture of the flare's particles
	moteMotion: string, -- MOTIONS key
	burst: string, -- texture of the punch's spray
	burstMotion: string,
	puff: string?, -- texture of the punch's second layer (dust, smoke, mist, bubbles); nil = none
	puffColor: string?, -- "#hex" of the puff; nil = the skill's colour, darkened
	ring: string?, -- ground ring texture of the punch; nil = none
	chips: boolean?, -- heavy blows throw chips (texture debris)
	arcs: boolean?, -- medium and heavy blows crackle with short lightning arcs
	rays: boolean?, -- the punch's core flares with rays of light (texture rays)
	white: number, -- share of white mixed into the core (white-hot steel and lightning, soft holy light)
	glow: string, -- "#hex" colour of the style (steel glints, holy gold, embers...)
	share: number, -- how much of the skill's own colour the particles, ring and light take over the style's (0..1)
}

export type Weight = {
	flare: number, -- size of the flare (1 = a 2.4-stud core)
	punch: number, -- size of the punch (1 = a 3-stud core, speeds x1)
	motes: number, -- flare particles on high
	burst: number, -- punch spray particles on high
	puff: number, -- punch puff particles on high
	chips: number, -- chips on high (only styles with chips)
	ring: number, -- ground ring radius in studs (also capped by the skill's own radius)
	light: number, -- PointLight range in studs (0 = none); brightness and time below
	shake: number, -- our own camera kick (0..1, the strength Vfx/CameraShake takes)
}

local MOTIONS: { [string]: Motion } = {
	-- steel glints and sparks: fast streaks thrown out, falling
	streak = {
		speed = { 14, 30 },
		drag = 3,
		accel = { 0, -45, 0 },
		life = { 0.25, 0.55 },
		size = { 0.32, 0.08 },
		spread = 180,
		parallel = true,
	},
	-- holy and healing motes: drifting up and out, slow
	rise = {
		speed = { 3, 9 },
		drag = 2.5,
		accel = { 0, 7, 0 },
		life = { 0.6, 1.1 },
		size = { 0.55, 0.05 },
		spread = 180,
	},
	-- leaves and feathers: thrown up, tumbling down slowly
	float = {
		speed = { 6, 14 },
		drag = 3,
		accel = { 0, -6, 0 },
		life = { 0.7, 1.2 },
		size = { 0.6, 0.35 },
		spread = 70,
		spin = 220,
		up = true,
	},
	-- ice shards: thrown out, spinning, falling fast
	shards = {
		speed = { 10, 22 },
		drag = 2,
		accel = { 0, -38, 0 },
		life = { 0.4, 0.75 },
		size = { 0.75, 0.35 },
		spread = 180,
		spin = 300,
	},
	-- fire embers: thrown out, then rising in the heat
	embers = {
		speed = { 12, 26 },
		drag = 4,
		accel = { 0, 10, 0 },
		life = { 0.45, 0.9 },
		size = { 0.26, 0.05 },
		spread = 180,
		parallel = true,
	},
	-- small flames licking up (the fire flare)
	flames = {
		speed = { 2, 6 },
		drag = 3,
		accel = { 0, 9, 0 },
		life = { 0.3, 0.55 },
		size = { 0.9, 0.2 },
		spread = 180,
		spin = 120,
	},
	-- lightning sparks: very fast, very short
	crackle = {
		speed = { 20, 40 },
		drag = 5,
		accel = { 0, -20, 0 },
		life = { 0.12, 0.3 },
		size = { 0.26, 0.04 },
		spread = 180,
		parallel = true,
	},
	-- arcane stars and venom bubbles: pushed out, slowing to a hover
	drift = {
		speed = { 6, 14 },
		drag = 5,
		accel = { 0, 2, 0 },
		life = { 0.5, 0.95 },
		size = { 0.5, 0.05 },
		spread = 180,
		spin = 90,
	},
	-- dust, smoke and mist: a low cloud rolling out and up
	cloud = {
		speed = { 3, 8 },
		drag = 2.5,
		accel = { 0, 1.5, 0 },
		life = { 0.9, 1.4 },
		size = { 1.4, 4 },
		spread = 80,
		spin = 40,
		up = true,
	},
	-- chips of rock and splinters: thrown up on arcs, falling hard
	chips = {
		speed = { 12, 24 },
		drag = 0.5,
		accel = { 0, -60, 0 },
		life = { 0.6, 1 },
		size = { 0.45, 0.35 },
		spread = 55,
		spin = 360,
		up = true,
	},
}

local STYLES: { [string]: Style } = {
	steel = {
		core = "hitStar",
		motes = "spark",
		moteMotion = "streak",
		burst = "spark",
		burstMotion = "streak",
		puff = "dust",
		puffColor = "#B8AA90",
		ring = "dustRing",
		chips = true,
		white = 0.55,
		glow = "#FFE2B0",
		share = 0.3,
	},
	holy = {
		core = "star",
		motes = "glow",
		moteMotion = "rise",
		burst = "glow",
		burstMotion = "rise",
		rays = true,
		ring = "ring",
		white = 0.4,
		glow = "#FFE7A0",
		share = 0.55,
	},
	heal = {
		core = "star",
		motes = "glow",
		moteMotion = "rise",
		burst = "star",
		burstMotion = "rise",
		ring = "ring",
		white = 0.35,
		glow = "#C8FFD0",
		share = 0.7,
	},
	hunt = {
		core = "star",
		motes = "leaf",
		moteMotion = "float",
		burst = "spark",
		burstMotion = "streak",
		puff = "dust",
		puffColor = "#A89A7C",
		ring = "dustRing",
		chips = true,
		white = 0.3,
		glow = "#E8F2C0",
		share = 0.45,
	},
	venom = {
		core = "glow",
		motes = "poisonBubble",
		moteMotion = "drift",
		burst = "poisonBubble",
		burstMotion = "drift",
		puff = "smoke",
		puffColor = "#4E7A2A",
		ring = "ring",
		white = 0.15,
		glow = "#B6F27A",
		share = 0.6,
	},
	fire = {
		core = "star",
		motes = "fire",
		moteMotion = "flames",
		burst = "spark",
		burstMotion = "embers",
		puff = "smoke",
		puffColor = "#3A2E2A",
		ring = "ring",
		chips = true,
		white = 0.35,
		glow = "#FFB25A",
		share = 0.7,
	},
	ice = {
		core = "star",
		motes = "iceShard",
		moteMotion = "shards",
		burst = "iceShard",
		burstMotion = "shards",
		puff = "smoke",
		puffColor = "#DDF4FF",
		ring = "ring",
		white = 0.45,
		glow = "#BFEFFF",
		share = 0.6,
	},
	lightning = {
		core = "hitStar",
		motes = "spark",
		moteMotion = "crackle",
		burst = "spark",
		burstMotion = "crackle",
		ring = "ring",
		arcs = true,
		white = 0.6,
		glow = "#F6F0A0",
		share = 0.5,
	},
	arcane = {
		core = "star",
		motes = "star",
		moteMotion = "drift",
		burst = "star",
		burstMotion = "drift",
		ring = "ring",
		white = 0.35,
		glow = "#D2B8FF",
		share = 0.8,
	},
}

local WEIGHTS: { [string]: Weight } = {
	light = { flare = 0.85, punch = 0.75, motes = 7, burst = 10, puff = 3, chips = 0, ring = 4, light = 9, shake = 0 },
	medium = { flare = 1, punch = 1, motes = 10, burst = 16, puff = 5, chips = 0, ring = 6, light = 12, shake = 0 },
	heavy = {
		flare = 1.25,
		punch = 1.4,
		motes = 14,
		burst = 24,
		puff = 7,
		chips = 9,
		ring = 9,
		light = 18,
		shake = 0.45,
	},
}

-- Skill kinds whose blow is help, not harm: the punch lifts (motes rise, no chips), the Cleric's turn green.
local SUPPORT: { [string]: boolean } = {
	heal = true,
	groupHeal = true,
	hot = true,
	healZone = true,
	resurrect = true,
	buff = true,
	shield = true,
	groupBuff = true,
	guard = true,
	channel = true,
}
local HEALS: { [string]: boolean } = { heal = true, groupHeal = true, hot = true, healZone = true, resurrect = true }

-- Big blows and finishers beyond the rule of Logic/SkillJuice.weightOf (a strong shake or a finisher is heavy anyway).
local HEAVY: { [string]: boolean } = {
	rend = true, -- spends Fury
	pyroblast = true,
	glacialSpike = true,
	stormArrow = true,
	deadlyBolt = true,
	lightningLance = true,
	shatter = true,
}
-- Skills played lighter than their kind says (a mark, a stance).
local LIGHT: { [string]: boolean } = {
	drawBead = true,
	huntersMark = true,
	brandOfLight = true,
	holyChains = true,
}

-- The style of a skill of `class` of `kind` with `element` (the skill's, or the weapon's for adaptive looks).
local function styleOf(class: string?, kind: string, element: string?): string
	if class == "Warrior" then
		return "steel"
	elseif class == "Cleric" then
		return if HEALS[kind] then "heal" else "holy"
	elseif class == "Hunter" then
		if element == "poison" then
			return "venom"
		elseif element == "lightning" or element == "ice" or element == "fire" then
			return element
		end
		return "hunt"
	end
	if element == "fire" or element == "ice" or element == "lightning" then
		return element
	elseif element == "poison" then
		return "venom"
	end
	return "arcane"
end

-- Cast voices (Data/Sfx skill.<id>.voice): sound ids of the S111 list by name (Data/Sfx resolves them; docs/ASSETS.md),
-- the middle pitch (0.97..1.03, so every step of Data/Sfx VOICE_STEPS stays in the allowed 0.85..1.15; styles sharing a
-- file differ by other than a step, 0.025) and the volume of the style. The skills of a style take its ids in turn and move one pitch step after each round, so no two skills
-- of a class sound the same.
export type Voice = { ids: { string }, pitch: number, volume: number, hint: string }
local VOICES: { [string]: Voice } = {
	steel = {
		ids = { "UNSHEATH", "SWOOSH", "WHOOSH_01" },
		pitch = 1.02,
		volume = 0.42,
		hint = "steel ring blade gleam short",
	},
	holy = {
		ids = { "SELECT_02", "SELECT_01", "SWEEP" },
		pitch = 1.03,
		volume = 0.4,
		hint = "holy chime bright short",
	},
	heal = { ids = { "SELECT_01", "CUTE_GOODBYE" }, pitch = 1, volume = 0.4, hint = "soft healing chime" },
	hunt = {
		ids = { "SWITCH", "WHOOSH_02", "PAPER_SWIPE" },
		pitch = 1,
		volume = 0.4,
		hint = "arrow nock click quick",
	},
	venom = { ids = { "SWITCH", "SPLAT" }, pitch = 0.97, volume = 0.38, hint = "poison hiss click" },
	fire = { ids = { "WHOOSH_04", "SWEEP" }, pitch = 0.97, volume = 0.42, hint = "fire ignite whoosh" },
	ice = { ids = { "WHOOSH_04", "SNAP" }, pitch = 1.03, volume = 0.4, hint = "frost crackle cold whoosh" },
	lightning = { ids = { "SNAP", "PING" }, pitch = 1, volume = 0.38, hint = "electric crackle snap" },
	arcane = { ids = { "SWEEP", "WHOOSH_04" }, pitch = 0.985, volume = 0.4, hint = "arcane hum swell short" },
}

-- The blow of a projectile arriving (Data/Sfx skill.impact.<style>): spells sound where they land; arrows and steel
-- keep the hit material of their damage only.
local IMPACT_VOICES: { [string]: Voice } = {
	fire = { ids = { "BASS" }, pitch = 1.1, volume = 0.45, hint = "small fire explosion pop" },
	ice = { ids = { "SNAP" }, pitch = 1.12, volume = 0.42, hint = "ice shatter crack" },
	lightning = { ids = { "PING" }, pitch = 1.04, volume = 0.4, hint = "electric zap impact" },
	arcane = { ids = { "SELECT_02" }, pitch = 0.9, volume = 0.4, hint = "arcane pop impact" },
	holy = { ids = { "SELECT_02" }, pitch = 1.12, volume = 0.4, hint = "holy light impact chime" },
	venom = { ids = { "SPLAT" }, pitch = 0.95, volume = 0.42, hint = "poison splat burst" },
}

return table.freeze({
	MOTIONS = table.freeze(MOTIONS),
	STYLES = table.freeze(STYLES),
	WEIGHTS = table.freeze(WEIGHTS),
	SUPPORT = table.freeze(SUPPORT),
	HEALS = table.freeze(HEALS),
	HEAVY = table.freeze(HEAVY),
	LIGHT = table.freeze(LIGHT),
	VOICES = table.freeze(VOICES),
	IMPACT_VOICES = table.freeze(IMPACT_VOICES),
	styleOf = styleOf,
})
