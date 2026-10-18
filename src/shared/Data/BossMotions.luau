--!strict
-- How bosses fight (S117, DESIGN-16 §8, docs/ANIMACJE.md "Potwory i bossowie w walce"): the pose of every attack of
-- Data/Bosses (a Data/MonsterMotions style, each attack of a boss a different one), the effect and the camera shake at
-- the blow, the phase roar and the death. Looks only: the windup, the areas and the damage stay the server's. A real
-- model plays its clip anims[<attack id>] instead of the style (S116; until then the generator). Data only (Lune).

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
export type BossMotion = {
	attacks: { [string]: BossAttackMotion }, -- every attack id of Data/Bosses
	roar: { style: string, shake: number, seconds: number },
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
			groundSplitter = { style = "overhead", impact = "cracks", cracks = true, shake = 0.5 },
			boulder = { style = "jumpSlam", impact = "meteor", cracks = true, shake = 0.6 },
		},
		roar = { style = "roar", shake = 0.5, seconds = 1.2 },
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
		roar = { style = "roar", shake = 0.45, seconds = 1.3 },
		death = { style = "dissolve", light = "#B48CFF" },
	}),
	azgor = boss({
		attacks = {
			fireWave = { style = "az_fireWave", impact = "pillar", shake = 0.3 },
			flameCleave = { style = "az_cleave", impact = "slash", shake = 0.3 },
			meteor = { style = "az_meteor", impact = "meteor", shake = 0.4 },
			inferno = { style = "az_inferno", impact = "ringWave", shake = 0.6 },
			eruption = { style = "erupt", impact = "pillar", shake = 0.4 },
			volcanoHeart = { style = "slam", impact = "meteor", cracks = true, shake = 0.6 },
			cinderBrand = { style = "cast", impact = "rune", shake = 0.2 },
		},
		roar = { style = "roar", shake = 0.6, seconds = 1.4 },
		death = { style = "crumble", light = "#FF7A1A" },
	}),
	vaelgrath = boss({
		attacks = {
			frostBreath = { style = "vg_breath", impact = "breath", shake = 0.2 },
			wingBuffet = { style = "vg_wings", impact = "ringWave", shake = 0.4 },
			tailSwipe = { style = "vg_tail", impact = "slash", shake = 0.3 },
			blizzard = { style = "vg_blizzard", impact = "meteor", shake = 0.2 },
			glacialRing = { style = "vg_glacial", impact = "ringWave", cracks = true, shake = 0.7 },
			avalanche = { style = "stomp", impact = "cracks", shake = 0.5 },
			iceComet = { style = "rear", impact = "meteor", cracks = true, shake = 0.6 },
			frostTomb = { style = "screech", impact = "rune", shake = 0.2 },
			absoluteZero = { style = "nova", impact = "ringWave", shake = 0.8 },
		},
		roar = { style = "roar", shake = 0.7, seconds = 1.6 },
		death = { style = "dragon", light = "#9FDCFF" },
	}),
	-- S149: the world boss (generic humanoid styles of Data/MonsterMotions, one per attack, until a real model)
	hrimvald = boss({
		attacks = {
			fistSlam = { style = "punch", impact = "shockwave", shake = 0.4 },
			boulderToss = { style = "overhead", impact = "meteor", cracks = true, shake = 0.4 },
			glacierStomp = { style = "stomp", impact = "ringWave", cracks = true, shake = 0.7 },
			iceSpikes = { style = "erupt", impact = "pillar", shake = 0.5 },
			avalanche = { style = "wide", impact = "meteor", shake = 0.5 },
			shatterStone = { style = "jumpSlam", impact = "meteor", cracks = true, shake = 0.8 },
			frostBrand = { style = "cast", impact = "rune", shake = 0.2 },
			endlessWinter = { style = "nova", impact = "ringWave", shake = 0.8 },
		},
		roar = { style = "roar", shake = 0.8, seconds = 1.6 },
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
})
