--!strict
-- How every active skill looks (S28): VfxController plays these pieces (client/Vfx/Library) on the skill's events —
-- `cast` when the animation starts (weapon trail over the motion's trail window, glowing hands while charging), the
-- impact pieces when the server reports the blow (SkillFx without `v`), `land` when a jump lands. Sizes come from the
-- server event (radius, angle, length, width), so breakpoints that grow an area grow the effect too.
--   color: "class" | "element" (weapon element for adaptive skills, else the skill's) | "holy" | "heal" | "#hex"
--   impact pieces: slash, whirl, shockwave, cracks, burst, pillar, sparkle, aura, shield, beam, dash, dust, rune,
--     arrowRain, fan, lineBeam, skyBolt, meteor, smoke, cloud, tether (S74: a line from the caster to the target),
--     falcon (S77: the Scout's bird over the caster, Vfx/Library.falcon)
--   trigger (S77, traps only): pieces when a trap springs instead of the default shockwave + burst
--   allies (S74): pieces played on every ally of the event's `al` list, in allyColor (default: color)
--   object (S74): "banner" = the skill leaves a server object the client draws (Vfx/Library.banner)
--   shake: camera shake strength (0..1) for players near the impact (setting "Camera shake"), hitstop: melee freeze
--   sound (S111): Data/Sfx key ("skill.<id>" or a "skill.default.*" key) or "" (= "skill.<id>" when playable, else
--     the default of the skill's kind, Logic/SfxRules.skillKey)
--   S80: everyWave = impact pieces every wave plays (default: shockwave, whirl, cracks, pillar; the first wave plays
--     all); waves = circleTarget sends one impact event per wave (`n` = the wave) instead of one at the start;
--     chargeSize = the projectile grows by this much per Arcane Charge spent (`ch` of the event)
--   S112 (Data/VfxTextures): impact pieces impactFlash, sparks, groundDecal, smokePuff, magicCircle, ringWave (the new
--     Vfx/Library pieces); decal = texture key of groundDecal (default cracks), circle = texture key of magicCircle and
--     rune (default the rune of the skill's class for every color, VfxTextures.runeOf(skill.class), magicCircle when
--     the class has none), sparks = texture key of sparks (default spark)
--   S114 (Warrior and Cleric, DESIGN-16 §2.6): every skill shows three layers (core: impactFlash / burst; body: the
--     shape; trail: sparks, dust, smoke, cracks, sparkle; tests/SkillLooks); tex = { [piece] = Data/VfxTextures key }
--     (slash, whirl, impactFlash, sparks, groundDecal, smokePuff, magicCircle, rune, ringWave, aura, beam, dash, tether,
--     skyBolt: a straight textured ray instead of lightning); flash = impactFlash size; pillar = { radius, height };
--     coreDelay = seconds the core, the hitstop and the sound wait after the event (Charge: the server deals the
--     damage 0.15 s after it); landsAfter = circleTarget whose blow lands the event's `d` later (Hammer of Heaven: only
--     magicCircle / rune show at once); markRadius = the size of groundDecal / cracks instead of the event's radius (a
--     mark at the pole or the shield, not over the whole area); new pieces shieldArc (a half ring of shields on the radius) and wings (wings of
--     light behind the target); projectile "die" (two dice). The sound stays "" = skill.<id> (Data/Sfx, S114 keys).

export type Entry = {
	color: string,
	sound: string,
	trail: boolean?,
	glow: { hand: "r" | "l" | "both" | "weapon", dur: number }?,
	projectile: ("orb" | "arrow" | "shard" | "bolt" | "rock" | "die")?,
	impact: { string },
	land: { string }?,
	slash: { from: number, to: number, tilt: number?, radius: number? }?,
	telegraph: ("circle" | "cone" | "line")?,
	shake: number?,
	hitstop: number?,
	size: number?,
	allies: { string }?,
	allyColor: string?,
	object: "banner"?,
	trigger: { string }?, -- S77: pieces of a trap's trapTrigger event (default: shockwave + burst)
	everyWave: { string }?, -- S80: pieces of every wave (subset of impact)
	waves: boolean?, -- S80: circleTarget, one impact event per wave
	chargeSize: number?, -- S80: projectile size per Arcane Charge spent
	decal: string?, -- S112: Data/VfxTextures key of groundDecal (kind decal)
	circle: string?, -- S112: Data/VfxTextures key of magicCircle / rune (kind beam)
	sparks: string?, -- S112: Data/VfxTextures key of sparks (kind particle)
	tex: { [string]: string }?, -- S114: piece -> Data/VfxTextures key
	flash: number?, -- S114: impactFlash size (default 3 x size)
	pillar: { radius: number, height: number }?, -- S114: the light pillar's size (default 1.5 / 14 x size)
	coreDelay: number?, -- S114: core pieces, hitstop and sound wait this long after the event
	landsAfter: boolean?, -- S114: circleTarget, the blow (all but magicCircle / rune, the shake and the sound) waits `d`
	markRadius: number?, -- S114: groundDecal / cracks size (a local mark) instead of the event's radius
}

local function e(def: Entry): Entry
	return def
end

local SkillVfx: { [string]: Entry } = {
	-- Warrior (S114): steel and dust near the weapon and the ground, the class colour; arcs slashNarrow / slashWide
	mightyStrike = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "impactFlash", "slash", "sparks", "dust" },
		slash = { from = 70, to = -70, tilt = 55, radius = 7 },
		tex = { slash = "slashNarrow" },
		shake = 0.25,
		hitstop = 0.07,
	}),
	battleCry = e({
		color = "#FF6A3A",
		sound = "",
		impact = { "impactFlash", "ringWave", "aura", "sparks" },
		flash = 4,
		shake = 0.2,
	}),
	charge = e({
		color = "class",
		sound = "",
		impact = { "dash", "impactFlash", "dust", "smokePuff" },
		tex = { dash = "trailStreak" },
		coreDelay = 0.15,
		shake = 0.35,
		hitstop = 0.06,
	}),
	bladeWhirl = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "impactFlash", "whirl", "sparks", "dust" },
		everyWave = { "whirl", "sparks" },
		tex = { whirl = "slashWide" },
		hitstop = 0.04,
	}),
	cleave = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "impactFlash", "slash", "sparks", "dust" },
		slash = { from = 60, to = -60, tilt = 0 },
		tex = { slash = "slashWide" },
		sparks = "darkSpark",
		telegraph = "cone",
		hitstop = 0.06,
	}),
	taunt = e({
		color = "#E2483A",
		sound = "",
		impact = { "impactFlash", "ringWave", "sparks", "dust" },
		telegraph = "circle",
	}),
	earthquake = e({
		color = "#C08A4A",
		sound = "",
		trail = true,
		impact = { "impactFlash", "ringWave", "groundDecal", "dust", "smokePuff", "sparks" },
		land = { "dust" },
		telegraph = "circle",
		shake = 0.6,
		hitstop = 0.08,
	}),
	bloodlust = e({ color = "#C21F2A", sound = "", impact = { "burst", "aura", "smokePuff" }, size = 0.8 }),
	crushingBlow = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "impactFlash", "groundDecal", "ringWave", "dust", "sparks" },
		flash = 5,
		shake = 0.5,
		hitstop = 0.08,
		size = 0.6,
	}),
	lastBastion = e({
		color = "#E8C25A",
		sound = "",
		impact = { "impactFlash", "shield", "dust", "groundDecal" },
		allies = { "shield" }, -- S73 bastionCover: allies behind the back (al of the buff event)
		size = 0.5,
	}),
	titansWrath = e({
		color = "#E8C25A",
		sound = "",
		trail = true,
		impact = { "impactFlash", "ringWave", "pillar", "groundDecal", "dust" },
		everyWave = { "impactFlash", "ringWave", "pillar", "groundDecal", "dust" },
		pillar = { radius = 3, height = 8 },
		land = { "dust" },
		telegraph = "circle",
		shake = 0.7,
		hitstop = 0.06,
	}),
	-- S74 path skills (ROZWOJ 10.3-10.5)
	intercept = e({
		color = "#E8C25A",
		sound = "",
		-- shield on `t`: the protected ally (the Warrior himself in the self variant); 10A: the second ally's own line
		impact = { "dash", "tether", "shield", "impactFlash", "dust" },
		tex = { dash = "trailStreak", tether = "beamHoly" },
		allies = { "shield", "tether" },
	}),
	shieldWall = e({
		color = "#E8C25A",
		sound = "",
		impact = { "impactFlash", "shieldArc", "dust", "cracks" },
		allies = { "shield" },
		markRadius = 3,
		telegraph = "circle",
		shake = 0.35,
	}),
	rend = e({
		color = "#C21F2A",
		sound = "",
		trail = true,
		impact = { "impactFlash", "slash", "sparks" },
		slash = { from = 70, to = -70, tilt = 80, radius = 7 },
		tex = { slash = "slashNarrow" },
		sparks = "darkSpark",
		shake = 0.3,
		hitstop = 0.08,
	}),
	carnage = e({
		color = "#8E1B1B",
		sound = "",
		impact = { "burst", "aura", "smokePuff", "sparks" },
		tex = { aura = "smoke" },
		sparks = "darkSpark",
	}),
	warBanner = e({
		color = "class",
		sound = "",
		impact = { "impactFlash", "ringWave", "dust", "groundDecal" },
		markRadius = 2.5,
		object = "banner",
		shake = 0.25,
	}),
	advanceOrder = e({
		color = "class",
		sound = "",
		impact = { "impactFlash", "ringWave", "dust", "sparks" },
		allies = { "aura" },
		allyColor = "#E8C25A",
		telegraph = "circle",
		shake = 0.4,
	}),
	-- Hunter
	aimedShot = e({
		color = "class",
		sound = "",
		glow = { hand = "l", dur = 0.55 },
		projectile = "arrow",
		impact = { "burst" },
		size = 0.6,
	}),
	doubleShot = e({ color = "class", sound = "", projectile = "arrow", impact = { "burst" }, size = 0.4 }),
	disengage = e({ color = "class", sound = "", impact = { "dash", "dust" }, land = { "dust" } }),
	arrowRain = e({ color = "class", sound = "", impact = { "arrowRain" }, telegraph = "circle" }),
	venomArrow = e({ color = "element", sound = "", projectile = "arrow", impact = { "cloud", "burst" }, size = 0.6 }),
	frostTrap = e({ color = "element", sound = "", impact = { "rune" } }),
	piercingArrow = e({
		color = "class",
		sound = "",
		glow = { hand = "l", dur = 0.4 },
		impact = { "lineBeam" },
		telegraph = "line",
		shake = 0.2,
	}),
	huntersMark = e({ color = "#E2483A", sound = "", impact = { "pillar", "burst" }, size = 0.5 }),
	volley = e({ color = "class", sound = "", impact = { "fan" }, telegraph = "cone" }),
	camouflage = e({ color = "#5F7A4A", sound = "", impact = { "smoke", "aura" } }),
	stormArrow = e({
		color = "element",
		sound = "",
		glow = { hand = "l", dur = 0.6 },
		projectile = "bolt",
		impact = { "skyBolt", "burst" },
		shake = 0.35,
	}),
	-- S77 (ROZWOJ 11.3-11.5): path skills of the Hunter
	drawBead = e({ color = "#E2483A", sound = "", impact = { "rune", "sparkle" }, size = 0.5 }),
	heartseeker = e({
		color = "#E2483A",
		sound = "",
		glow = { hand = "l", dur = 1.5 },
		projectile = "arrow",
		impact = { "beam", "burst" },
		shake = 0.3,
		size = 0.8,
	}),
	venomSnare = e({ color = "element", sound = "", impact = { "rune" }, trigger = { "cloud", "burst" } }),
	snarefield = e({ color = "class", sound = "", impact = { "rune" }, trigger = { "cracks", "burst" } }),
	falcon = e({ color = "#C8A060", sound = "", impact = { "dust", "sparkle", "falcon" }, size = 0.6 }),
	drive = e({
		color = "class",
		sound = "",
		impact = { "arrowRain", "shockwave", "dust" },
		telegraph = "circle",
		shake = 0.25,
	}),
	-- Mage
	firebolt = e({
		color = "element",
		sound = "",
		glow = { hand = "weapon", dur = 0.18 },
		projectile = "orb",
		impact = { "burst" },
		size = 0.7,
	}),
	iceShard = e({
		color = "element",
		sound = "",
		glow = { hand = "both", dur = 0.28 },
		projectile = "shard",
		impact = { "burst" },
		size = 0.7,
	}),
	blink = e({ color = "#B07CFF", sound = "", impact = { "dash", "burst" } }),
	fireball = e({
		color = "element",
		sound = "",
		glow = { hand = "both", dur = 0.4 },
		projectile = "orb",
		impact = { "burst", "shockwave", "cracks" },
		telegraph = "circle",
		shake = 0.35,
		size = 1.4,
	}),
	chainLightning = e({ color = "element", sound = "", glow = { hand = "r", dur = 0.27 }, impact = {} }),
	manaShield = e({ color = "#6FA8FF", sound = "", impact = { "shield" } }),
	frostNova = e({
		color = "element",
		sound = "",
		impact = { "shockwave", "cracks", "burst" },
		telegraph = "circle",
		shake = 0.3,
	}),
	meteor = e({
		color = "element",
		sound = "",
		glow = { hand = "both", dur = 0.9 },
		impact = { "meteor", "rune" },
		telegraph = "circle",
		shake = 0.8,
	}),
	firewall = e({
		color = "element",
		sound = "",
		glow = { hand = "weapon", dur = 0.4 },
		impact = { "rune" },
		telegraph = "circle",
	}),
	evocation = e({ color = "#6FA8FF", sound = "", impact = { "aura", "rune" } }),
	meteorStorm = e({
		color = "element",
		sound = "",
		glow = { hand = "both", dur = 0.55 },
		impact = { "rune" },
		telegraph = "circle",
		shake = 0.5,
	}),
	-- S80 (ROZWOJ 12.4, 12.5)
	elementalVortex = e({
		color = "element",
		sound = "",
		impact = { "rune", "whirl", "aura" },
		everyWave = { "whirl", "aura" },
	}),
	cataclysm = e({
		color = "element",
		sound = "",
		glow = { hand = "both", dur = 0.8 },
		impact = { "meteor", "shockwave", "cracks", "rune" },
		telegraph = "circle",
		waves = true,
		shake = 0.7,
	}),
	arcaneDischarge = e({
		color = "#B07CFF",
		sound = "",
		glow = { hand = "both", dur = 0.35 },
		projectile = "orb",
		size = 0.8,
		chargeSize = 0.15,
		impact = { "burst", "sparkle", "shockwave" },
	}),
	arcaneTorrent = e({ color = "#B07CFF", sound = "", impact = { "beam", "sparkle", "aura" } }),
	-- Cleric (S114): light from above and from the hands, little dust; holy gold, heal green, the Cleric's rune
	holyStrike = e({
		color = "holy",
		sound = "",
		trail = true,
		impact = { "impactFlash", "pillar", "sparks" },
		pillar = { radius = 0.8, height = 16 },
		hitstop = 0.06,
		size = 0.5,
	}),
	heal = e({
		color = "heal",
		sound = "",
		glow = { hand = "l", dur = 0.3 },
		impact = { "impactFlash", "beam", "sparkle" },
		size = 0.6,
	}),
	renew = e({
		color = "heal",
		sound = "",
		glow = { hand = "both", dur = 0.35 },
		impact = { "impactFlash", "aura", "sparkle" },
		size = 0.5,
	}),
	radiance = e({
		color = "holy",
		sound = "",
		glow = { hand = "weapon", dur = 0.3 },
		impact = { "impactFlash", "ringWave", "pillar", "sparks" },
		pillar = { radius = 2.4, height = 9 },
		telegraph = "circle",
	}),
	circleOfLight = e({
		color = "heal",
		sound = "",
		impact = { "impactFlash", "magicCircle", "ringWave", "sparkle" },
	}),
	purify = e({
		color = "#F4F1E0",
		sound = "",
		impact = { "impactFlash", "ringWave", "sparks", "smokePuff" },
		size = 0.5,
	}),
	auraOfEndurance = e({ color = "holy", sound = "", impact = { "impactFlash", "ringWave", "aura", "sparkle" } }),
	resurrection = e({
		color = "holy",
		sound = "",
		impact = { "impactFlash", "pillar", "sparkle" },
		tex = { impactFlash = "glow" },
		pillar = { radius = 2, height = 20 },
		size = 1.4,
	}),
	shieldOfFaith = e({ color = "holy", sound = "", impact = { "impactFlash", "shield", "sparkle" }, size = 0.6 }),
	judgement = e({
		color = "holy",
		sound = "",
		trail = true,
		impact = { "impactFlash", "skyBolt", "groundDecal" },
		tex = { skyBolt = "beamHoly" },
		land = { "dust" },
		shake = 0.5,
		hitstop = 0.08,
		size = 0.6,
	}),
	prayer = e({ color = "holy", sound = "", impact = { "impactFlash", "magicCircle", "aura", "sparkle" }, size = 0.6 }),
	divineIntervention = e({
		color = "holy",
		sound = "",
		impact = { "impactFlash", "pillar", "ringWave", "sparkle" },
		pillar = { radius = 3, height = 24 },
		flash = 6,
		shake = 0.3,
		size = 2,
	}),
	-- S70 (ROZWOJ 9.3–9.5)
	sanctuary = e({
		color = "heal",
		sound = "",
		impact = { "impactFlash", "magicCircle", "sparkle" },
		telegraph = "circle",
	}),
	guardianAngel = e({
		color = "holy",
		sound = "",
		impact = { "impactFlash", "wings", "sparkle" },
		allies = { "wings" }, -- behind every ally of the groupBuff event's `al`
		size = 1.6,
	}),
	fortuneDice = e({
		color = "#E8C25A",
		sound = "",
		projectile = "die",
		impact = { "burst", "rune", "sparkle" },
		size = 0.6,
	}),
	wheelOfFortune = e({
		color = "#E8C25A",
		sound = "",
		impact = { "impactFlash", "magicCircle", "pillar", "sparks" },
		circle = "magicCircle",
		pillar = { radius = 2, height = 18 },
		flash = 5,
		shake = 0.3,
		size = 2.2,
	}),
	brandOfLight = e({ color = "holy", sound = "", impact = { "impactFlash", "rune", "sparks" }, size = 0.5 }),
	hammerOfHeaven = e({
		color = "holy",
		sound = "",
		trail = true,
		impact = { "magicCircle", "impactFlash", "skyBolt", "ringWave", "groundDecal", "dust" },
		tex = { skyBolt = "beamHoly" },
		landsAfter = true,
		land = { "dust" },
		telegraph = "circle",
		flash = 6,
		shake = 0.6,
		hitstop = 0.08,
		size = 0.9,
	}),
}

return table.freeze(SkillVfx)
