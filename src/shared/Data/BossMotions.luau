--!strict
-- How bosses fight (S117, DESIGN-16 §8, docs/ANIMACJE.md "Potwory i bossowie w walce"): the pose of every attack of
-- Data/Bosses (a Data/MonsterMotions style, each attack of a boss a different one), the effect and the camera shake at
-- the blow, the phase roar and the death. Looks only: the windup, the areas and the damage stay the server's. A real
-- model plays its clip anims[<attack id>] instead of the style (S116; until then the generator). Data only (Lune).
-- S159a: `patterns` gives every dodgeable pattern of the boss (Data/BossTuning.patterns: replace, ambient, the shield
-- and kiting casts) its own gesture: the style poses the anticipation over the pattern's warning and the blow at its
-- release (Logic/HazardGesture), a channel holds it, the style's `follow` is the follow-through; an imported model
-- (bone clips) poses it procedurally too (client/Anim/BoneOverlay). A pattern added to an attack names it in `rides`:
-- the attack's own motion is its gesture. Roars: `roar.byPhase` picks another style for a phase, `roar.sound` is the
-- audible roar while the boss's own roar key has no sound (Data/Sfx), `roar.intro` roars at the first aggro.

export type Impact =
	"slash"
	| "shockwave"
	| "cracks"
	| "ringWave"
	| "pillar"
	| "meteor"
	| "breath"
	| "bolt"
	| "rune"
	| "none"

export type BossAttackMotion = {
	style: string, -- MonsterMotions.STYLES key (bosses may add their own styles in STYLES)
	impact: Impact?, -- effect at the blow, on every area of the attack (CombatFxController), default "none"
	cracks: boolean?, -- dark cracks under the impact as well (a heavy landing)
	shake: number?, -- camera shake at the blow for players within Config.Telegraph.shakeRange (0..1)
	sound: string?, -- Data/Sfx key, default "boss.<bossId>.attack"
	arc: number?, -- `leap` attacks: studs of the visual jump arc (Gait.leapArc) before the server's teleport
}
-- S159a: the gesture of a dodgeable pattern (Data/HazardPatterns) cast by the boss.
export type Gesture = {
	style: string?, -- MonsterMotions.STYLES key (nil with `rides`)
	rides: string?, -- an attack id of the boss whose own motion carries the pattern (BossTuning.patterns.add)
	windSound: string?, -- Data/Sfx key at the start of the windup (default telegraph.warn)
	sound: string?, -- Data/Sfx key at the release
	shake: number?, -- camera shake at the release for players within Config.Telegraph.shakeRange (0..1)
}
export type Roar = {
	style: string,
	shake: number,
	seconds: number,
	byPhase: { [number]: string }?, -- S159a: another style for the roar into this phase
	sound: string?, -- S159a: Data/Sfx key played with the roar while boss.<id>.roar has no sound
	intro: boolean?, -- S159a: the boss also roars when it first turns on a fighter
}
export type BossMotion = {
	attacks: { [string]: BossAttackMotion }, -- every attack id of Data/Bosses
	patterns: { [string]: Gesture }, -- S159a: every pattern id the boss casts (Data/BossTuning.patterns, extra)
	roar: Roar,
	-- light: hex colour of the death flash; seconds: the clone's break-up (default Config.MonsterLook.bossDeathSeconds)
	death: { style: string, light: string, seconds: number? },
}

-- Effects an attack may name (tests).
local IMPACTS: { Impact } =
	{ "slash", "shockwave", "cracks", "ringWave", "pillar", "meteor", "breath", "bolt", "rune", "none" }

local function boss(def: BossMotion): BossMotion
	return def
end

local BY_BOSS: { [string]: BossMotion } = {
	grimrok = boss({
		attacks = {
			sweep = { style = "gr_sweep", impact = "slash", shake = 0.3 },
			leap = { style = "gr_leap", impact = "shockwave", cracks = true, shake = 0.6, arc = 6 },
			whirlwind = { style = "gr_whirl", impact = "ringWave", shake = 0.4 },
			-- S134: generic styles of Data/MonsterMotions until the boss gets its own
			groundSplitter = { style = "gr_fissure", impact = "cracks", cracks = true, shake = 0.5 }, -- S159a
			boulder = { style = "jumpSlam", impact = "meteor", cracks = true, shake = 0.6 },
		},
		patterns = {
			gr_fissure = { style = "gr_fissure", windSound = "skill.taunt", sound = "skill.earthquake", shake = 0.5 },
			gr_axeThrow = { style = "gr_axeThrow", sound = "swing.heavy" },
			gr_axeFan = { style = "gr_axeFan", sound = "skill.bladeWhirl", shake = 0.2 },
			gr_bombs = { style = "gr_bombLob", sound = "swing.light" },
			gr_quakeRing = { rides = "leap" },
			gr_whirlAxes = { rides = "whirlwind" },
		},
		roar = {
			style = "gr_roar",
			shake = 0.5,
			seconds = 1.2,
			byPhase = { [3] = "gr_rage" },
			sound = "skill.battleCry",
			intro = true,
		},
		death = { style = "knees", light = "#FFB060" },
	}),
	morvane = boss({
		attacks = {
			shadowBolt = { style = "mv_bolt", impact = "bolt", shake = 0 },
			shadowBoltFast = { style = "mv_boltFast", impact = "bolt", shake = 0 },
			curseField = { style = "mv_curse", impact = "rune", shake = 0 },
			deathRing = { style = "mv_deathRing", impact = "ringWave", shake = 0.5 },
			soulReap = { style = "wide", impact = "slash", shake = 0.3 },
			cryptBrand = { style = "cast", impact = "rune", shake = 0.2 },
			requiem = { style = "castBurst", impact = "ringWave", shake = 0.5 },
		},
		patterns = {
			mv_soulOrbs = { style = "mv_soulOrbs", windSound = "skill.evocation", sound = "wand.cast" },
			mv_soulVolley = { style = "mv_soulVolley", sound = "skill.arcaneDischarge" },
			mv_spiral = {
				style = "mv_spiral",
				windSound = "skill.evocation",
				sound = "skill.arcaneTorrent",
				shake = 0.2,
			},
		},
		roar = {
			style = "mv_wail",
			shake = 0.45,
			seconds = 1.3,
			byPhase = { [3] = "mv_rage" },
			sound = "skill.blizzard",
			intro = true,
		},
		death = { style = "dissolve", light = "#B48CFF" },
	}),
	azgor = boss({
		attacks = {
			fireWave = { style = "az_flameWall", impact = "pillar", shake = 0.3 }, -- S159a: the flame wall's gesture
			flameCleave = { style = "az_cleave", impact = "slash", shake = 0.3 },
			meteor = { style = "az_meteor", impact = "meteor", shake = 0.4 },
			inferno = { style = "az_inferno", impact = "ringWave", shake = 0.6 },
			eruption = { style = "erupt", impact = "pillar", shake = 0.4 },
			volcanoHeart = { style = "slam", impact = "meteor", cracks = true, shake = 0.6 },
			cinderBrand = { style = "cast", impact = "rune", shake = 0.2 },
		},
		patterns = {
			az_flameWall = { style = "az_flameWall", sound = "skill.flameWave", shake = 0.3 },
			az_meteor = { style = "az_meteor", windSound = "skill.meteor.cast", sound = "skill.meteor", shake = 0.4 },
			az_fireballs = { style = "az_fireballs", windSound = "skill.fireball.cast", sound = "skill.pyroblast" },
			az_magma = {
				style = "az_magmaSlam",
				windSound = "skill.cataclysm.cast",
				sound = "skill.combustion",
				shake = 0.5,
			},
		},
		roar = {
			style = "az_roar",
			shake = 0.6,
			seconds = 1.4,
			byPhase = { [3] = "az_rage" },
			sound = "skill.carnage",
			intro = true,
		},
		death = { style = "crumble", light = "#FF7A1A" },
	}),
	vaelgrath = boss({
		attacks = {
			frostBreath = { style = "vg_breath", impact = "breath", shake = 0.2 },
			wingBuffet = { style = "vg_wings", impact = "ringWave", shake = 0.4 },
			tailSwipe = { style = "vg_tail", impact = "slash", shake = 0.3 },
			blizzard = { style = "vg_comets", impact = "meteor", shake = 0.2 }, -- S159a: the ice comets' gesture
			glacialRing = { style = "vg_glacial", impact = "ringWave", cracks = true, shake = 0.7 },
			avalanche = { style = "vg_avalanche", impact = "cracks", shake = 0.5 }, -- S159a
			iceComet = { style = "rear", impact = "meteor", cracks = true, shake = 0.6 },
			frostTomb = { style = "screech", impact = "rune", shake = 0.2 },
			absoluteZero = { style = "nova", impact = "ringWave", shake = 0.8 },
		},
		patterns = {
			vg_iceComets = {
				style = "vg_comets",
				windSound = "skill.glacialSpike.cast",
				sound = "skill.iceShard",
				shake = 0.3,
			},
			vg_avalanche = { style = "vg_avalanche", sound = "skill.warStomp", shake = 0.5 },
			vg_frostOrbs = { style = "vg_orbSpit", sound = "skill.frozenOrb" },
			vg_skyShards = {
				style = "vg_wingStorm",
				windSound = "skill.blizzard",
				sound = "skill.hailstorm",
				shake = 0.2,
			},
		},
		roar = {
			style = "vg_roar",
			shake = 0.7,
			seconds = 1.6,
			byPhase = { [3] = "vg_rage" },
			sound = "skill.bloodlust",
			intro = true,
		},
		death = { style = "dragon", light = "#9FDCFF" },
	}),
	-- S149: the world boss (generic humanoid styles of Data/MonsterMotions, one per attack, until a real model)
	hrimvald = boss({
		attacks = {
			fistSlam = { style = "punch", impact = "shockwave", shake = 0.4 },
			-- S159a: the attacks a pattern replaces pose as its gesture; the stomp as its own (the ring rides on it)
			boulderToss = { style = "hv_boulderThrow", impact = "meteor", cracks = true, shake = 0.4 },
			glacierStomp = { style = "hv_stomp", impact = "ringWave", cracks = true, shake = 0.7 },
			iceSpikes = { style = "hv_spikeSlam", impact = "pillar", shake = 0.5 },
			avalanche = { style = "hv_iceCall", impact = "meteor", shake = 0.5 },
			shatterStone = { style = "jumpSlam", impact = "meteor", cracks = true, shake = 0.8 },
			frostBrand = { style = "cast", impact = "rune", shake = 0.2 },
			endlessWinter = { style = "nova", impact = "ringWave", shake = 0.8 },
		},
		patterns = {
			hv_boulder = { style = "hv_boulderThrow", windSound = "skill.earthquake.cast", sound = "swing.heavy" },
			hv_spikeWave = { style = "hv_spikeSlam", sound = "skill.glacialSpike", shake = 0.5 },
			hv_iceBlocks = {
				style = "hv_iceCall",
				windSound = "skill.meteorStorm.cast",
				sound = "skill.deepFreeze",
				shake = 0.5,
			},
			hv_shardRain = {
				style = "hv_shardCall",
				windSound = "skill.blizzard",
				sound = "skill.hailstorm",
				shake = 0.2,
			},
			hv_frostBreath = { style = "hv_breath", windSound = "skill.glacialSpike.cast", sound = "skill.blizzard" },
			hv_iceVolley = { style = "hv_javelins", windSound = "skill.glacialSpike.cast", sound = "skill.volley" },
			hv_glacierWalls = {
				style = "hv_wallRise",
				windSound = "skill.iceBarrier",
				sound = "skill.warStomp",
				shake = 0.6,
			},
			hv_stompRing = { rides = "glacierStomp" },
		},
		roar = {
			style = "hv_roar",
			shake = 0.8,
			seconds = 1.6,
			byPhase = { [3] = "hv_rage" },
			sound = "skill.taunt",
			intro = true,
		},
		death = { style = "knees", light = "#BFE6FF" },
	}),
}

return table.freeze({
	IMPACTS = IMPACTS,
	byBoss = BY_BOSS,
	get = function(bossId: string): BossMotion?
		return BY_BOSS[bossId]
	end,
	-- The motion of one attack (nil for an unknown boss or attack).
	attack = function(bossId: string, attackId: string): BossAttackMotion?
		local def = BY_BOSS[bossId]
		return if def then def.attacks[attackId] else nil
	end,
	-- S159a: the gesture of a pattern the boss casts (nil for an unknown boss or pattern).
	gesture = function(bossId: string, patternId: string): Gesture?
		local def = BY_BOSS[bossId]
		return if def then def.patterns[patternId] else nil
	end,
	-- S159a: the roar style into `phase` (byPhase, else the boss's roar).
	roarStyle = function(bossId: string, phase: number?): string?
		local def = BY_BOSS[bossId]
		if not def then
			return nil
		end
		local byPhase = def.roar.byPhase
		return (if byPhase and phase then byPhase[phase] else nil) or def.roar.style
	end,
})
