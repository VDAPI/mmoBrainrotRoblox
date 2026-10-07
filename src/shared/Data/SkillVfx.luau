--!strict
-- How every active skill looks (S28): VfxController plays these pieces (client/Vfx/Library) on the skill's events —
-- `cast` when the animation starts (weapon trail over the motion's trail window, glowing hands while charging), the
-- impact pieces when the server reports the blow (SkillFx without `v`), `land` when a jump lands. Sizes come from the
-- server event (radius, angle, length, width), so breakpoints that grow an area grow the effect too.
--   color: "class" | "element" (weapon element for adaptive skills, else the skill's) | "holy" | "heal" | "#hex"
--   impact pieces: slash, whirl, shockwave, cracks, burst, pillar, sparkle, aura, shield, beam, dash, dust, rune,
--     arrowRain, fan, lineBeam, skyBolt, meteor, smoke, cloud
--   shake: camera shake strength (0..1) for players near the impact (setting "Camera shake"), hitstop: melee freeze
--   sound: rbxassetid or "" (none yet: PROGRESS "Niedokończone" lists what to attach)

export type Entry = {
	color: string,
	sound: string,
	trail: boolean?,
	glow: { hand: "r" | "l" | "both" | "weapon", dur: number }?,
	projectile: ("orb" | "arrow" | "shard" | "bolt" | "rock")?,
	impact: { string },
	land: { string }?,
	slash: { from: number, to: number, tilt: number?, radius: number? }?,
	telegraph: ("circle" | "cone" | "line")?,
	shake: number?,
	hitstop: number?,
	size: number?,
}

local function e(def: Entry): Entry
	return def
end

local SkillVfx: { [string]: Entry } = {
	-- Warrior
	mightyStrike = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "slash", "burst", "dust" },
		slash = { from = 70, to = -70, tilt = 55, radius = 7 },
		shake = 0.25,
		hitstop = 0.07,
	}),
	battleCry = e({ color = "#FF6A3A", sound = "", impact = { "shockwave", "aura", "burst" }, shake = 0.2 }),
	charge = e({ color = "class", sound = "", impact = { "dash", "burst", "dust" }, shake = 0.35, hitstop = 0.06 }),
	bladeWhirl = e({ color = "class", sound = "", trail = true, impact = { "whirl", "shockwave" }, hitstop = 0.04 }),
	cleave = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "slash" },
		slash = { from = 60, to = -60, tilt = 0 },
		telegraph = "cone",
		hitstop = 0.06,
	}),
	taunt = e({ color = "#E2483A", sound = "", impact = { "shockwave", "burst", "aura" }, telegraph = "circle" }),
	earthquake = e({
		color = "#C08A4A",
		sound = "",
		trail = true,
		impact = { "shockwave", "cracks", "dust" },
		land = { "dust" },
		telegraph = "circle",
		shake = 0.6,
		hitstop = 0.08,
	}),
	bloodlust = e({ color = "#C21F2A", sound = "", impact = { "aura", "burst" } }),
	crushingBlow = e({
		color = "class",
		sound = "",
		trail = true,
		impact = { "burst", "cracks", "dust" },
		shake = 0.5,
		hitstop = 0.08,
		size = 0.6,
	}),
	lastBastion = e({ color = "#E8C25A", sound = "", impact = { "shield", "burst" } }),
	titansWrath = e({
		color = "#E8C25A",
		sound = "",
		trail = true,
		impact = { "shockwave", "cracks", "pillar", "dust" },
		land = { "dust" },
		telegraph = "circle",
		shake = 0.7,
		hitstop = 0.06,
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
	-- Cleric
	holyStrike = e({
		color = "holy",
		sound = "",
		trail = true,
		impact = { "pillar", "burst" },
		hitstop = 0.06,
		size = 0.5,
	}),
	heal = e({ color = "heal", sound = "", glow = { hand = "l", dur = 0.3 }, impact = { "beam", "sparkle" } }),
	renew = e({ color = "heal", sound = "", impact = { "sparkle", "aura" } }),
	radiance = e({
		color = "holy",
		sound = "",
		glow = { hand = "weapon", dur = 0.3 },
		impact = { "shockwave", "pillar" },
		telegraph = "circle",
	}),
	circleOfLight = e({ color = "heal", sound = "", impact = { "rune", "shockwave", "sparkle" } }),
	purify = e({ color = "#F4F1E0", sound = "", impact = { "burst", "sparkle" } }),
	auraOfEndurance = e({ color = "holy", sound = "", impact = { "shockwave", "aura" } }),
	resurrection = e({ color = "holy", sound = "", impact = { "pillar", "sparkle" }, size = 1.4 }),
	shieldOfFaith = e({ color = "holy", sound = "", impact = { "shield", "sparkle" } }),
	judgement = e({
		color = "holy",
		sound = "",
		trail = true,
		impact = { "skyBolt", "pillar", "cracks" },
		land = { "dust" },
		shake = 0.5,
		hitstop = 0.08,
		size = 0.6,
	}),
	prayer = e({ color = "holy", sound = "", impact = { "rune", "aura" } }),
	divineIntervention = e({
		color = "holy",
		sound = "",
		impact = { "pillar", "shockwave", "aura" },
		shake = 0.3,
		size = 2,
	}),
}

return table.freeze(SkillVfx)
