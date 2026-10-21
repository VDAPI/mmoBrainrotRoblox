--!strict
-- Dodgeable hazard patterns (owner 2026-10-21, S159; rules and kinds in Logic/Hazards): what flies, rolls, runs over
-- the ground or turns, how fast and how wide. The damage of a hit is the cast's (a boss attack's `damage`, a
-- BossTuning.patterns entry, a monster's regular blow) x the emitter's `share`; a player takes at most `hits` hits of
-- one cast. Every instance warns >= Logic/Hazards.MIN_WARN s before it can hit (tests/hazards.spec). `look` names the
-- client's look (Vfx/HazardFx), `color` its tint, `sound` / `impactSound` Data/Sfx keys; the caster's gesture is the
-- boss's Data/BossMotions.patterns entry (S159g, timed by Logic/HazardGesture). Data only (Lune).

local Hazards = require("../Logic/Hazards")

type Pattern = Hazards.Pattern

local function pattern(def: Pattern): Pattern
	return table.freeze(def)
end

local PATTERNS: { [string]: Pattern } = {
	-- Monsters' regular ranged blows (CombatService: archers and casters, the Elite II throw) ---------------------------
	-- an arrow at the target's place a moment ahead (MonsterShot.lead); hits only its target
	mobArrow = pattern({
		regular = true,
		lead = 0.5,
		look = "arrow",
		color = "#C9B48A",
		emitters = { { kind = "bolt", aim = "target", speed = 62, radius = 0.9, range = 70, life = 1.3, delay = 0 } },
	}),
	mobBolt = pattern({
		regular = true,
		lead = 0.4,
		look = "magicBolt",
		color = "#8F7BFF",
		emitters = { { kind = "bolt", aim = "target", speed = 40, radius = 1.1, range = 70, life = 2, delay = 0 } },
	}),
	-- S134e Elite II's throw at a fleeing target: a heavy rock or a dark bolt
	eliteThrow = pattern({
		regular = true,
		lead = 0.8,
		look = "rock",
		color = "#8A7A66",
		emitters = { { kind = "bolt", aim = "target", speed = 55, radius = 1.4, range = 80, life = 1.6, delay = 0 } },
	}),
	eliteThrowMagic = pattern({
		regular = true,
		lead = 0.8,
		look = "magicBolt",
		color = "#B060FF",
		emitters = { { kind = "bolt", aim = "target", speed = 46, radius = 1.4, range = 80, life = 1.9, delay = 0 } },
	}),

	-- Grimrok, Goblin Warchief ----------------------------------------------------------------------------------------
	-- the axe splits the ground: a crack runs from the boss along the lane (replaces groundSplitter's line)
	gr_fissure = pattern({
		look = "fissure",
		color = "#D6A04A",
		big = true,
		impactSound = "boss.grimrok.attack",
		emitters = { { kind = "wave", aim = "target", width = 6, thick = 3, length = 40, speed = 32, offset = 2 } },
	}),
	-- three hand axes in a fan at a kiting fighter; they come back to the throw (BossTuning.extra far)
	gr_axeThrow = pattern({
		look = "axe",
		color = "#B8B0A0",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 3,
				spread = 34,
				speed = 30,
				radius = 1.3,
				range = 32,
				life = 3,
				returns = true,
				delay = 0.8,
				offset = 2,
			},
		},
	}),
	-- behind the goblins' shield: five axes fan out from the throne and come back
	gr_axeFan = pattern({
		look = "axe",
		color = "#B8B0A0",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 5,
				spread = 70,
				speed = 26,
				radius = 1.3,
				range = 36,
				life = 3.4,
				returns = true,
				delay = 0.9,
				offset = 2,
			},
		},
	}),
	-- the leap's landing throws a low shock ring: jump over it or stand far
	gr_quakeRing = pattern({
		look = "quakeRing",
		color = "#C8A070",
		emitters = { { kind = "ring", aim = "forward", speed = 20, maxRadius = 22, thick = 2, low = true } },
	}),
	-- the whirlwind flings four axes round (phase 3)
	gr_whirlAxes = pattern({
		look = "axe",
		color = "#E05A3E",
		emitters = {
			{
				kind = "bolt",
				aim = "around",
				arms = 4,
				speed = 24,
				radius = 1.3,
				range = 26,
				life = 3,
				returns = true,
				offset = 3,
			},
		},
	}),
	-- phase 2-3: goblin bombs lobbed at random fighters, landing round them with a fizzing circle
	gr_bombs = pattern({
		look = "bomb",
		color = "#E8862A",
		hits = 2,
		hitGap = 0.4,
		impactSound = "skill.combustion", -- S159g: the bombs burst audibly (boss.grimrok.attack has no sound yet)
		emitters = { { kind = "lob", aim = "target", count = 2, every = 0.25, radius = 5, scatter = 7, delay = 1.4 } },
	}),

	-- Morvane, Queen of the Crypts ------------------------------------------------------------------------------------
	-- slow homing soul orbs, one at each chosen fighter (replaces shadowBolt's circles): outrun or sidestep them
	mv_soulOrbs = pattern({
		look = "soulOrb",
		color = "#B07CFF",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				speed = 13,
				radius = 1.5,
				homing = 70,
				range = 70,
				life = 5.5,
				offset = 2,
			},
		},
	}),
	-- phase 3: a quick fan of three straight orbs at each chosen fighter (replaces shadowBoltFast)
	mv_soulVolley = pattern({
		look = "soulOrb",
		color = "#C99BFF",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 3,
				spread = 22,
				speed = 28,
				radius = 1.3,
				range = 60,
				life = 3,
				offset = 2,
			},
		},
	}),
	-- behind the guards' shield (and phase 3): a turning spiral of slow orbs from the queen
	mv_spiral = pattern({
		look = "soulOrb",
		color = "#9E6BFF",
		hits = 2,
		emitters = {
			{
				kind = "bolt",
				aim = "around",
				arms = 3,
				shots = 10,
				every = 0.22,
				turn = 14,
				speed = 15,
				radius = 1.2,
				range = 46,
				life = 4,
				offset = 2,
			},
		},
	}),

	-- Azgor, Lord of Flames -------------------------------------------------------------------------------------------
	-- a wall of fire runs along the lane (replaces fireWave's line)
	az_flameWall = pattern({
		look = "flameWall",
		color = "#FF6A1A",
		big = true,
		emitters = { { kind = "wave", aim = "target", width = 9, thick = 3, length = 40, speed = 26, offset = 2 } },
	}),
	-- a meteor falls on every fighter (replaces meteor's circles; the landing circle warns for the whole fall)
	az_meteor = pattern({
		look = "meteor",
		color = "#FF7A1A",
		big = true,
		emitters = { { kind = "lob", aim = "target", radius = 7 } },
	}),
	-- five fireballs in a fan at a kiting fighter (BossTuning.extra far)
	az_fireballs = pattern({
		look = "fireball",
		color = "#FF8A2A",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 5,
				spread = 40,
				speed = 34,
				radius = 1.4,
				range = 60,
				life = 2.2,
				delay = 0.8,
				offset = 2,
			},
		},
	}),
	-- phase 2-3: two balls of magma bouncing round the arena
	az_magma = pattern({
		look = "magma",
		color = "#FF5A10",
		hits = 2,
		hitGap = 1.2,
		emitters = {
			{
				kind = "bolt",
				aim = "around",
				arms = 2,
				speed = 16,
				radius = 2.4,
				range = 400,
				life = 8,
				bounce = 4,
				delay = 1.2,
				offset = 3,
			},
		},
	}),

	-- Vaelgrath, the Frost Dragon -------------------------------------------------------------------------------------
	-- ice comets fall on every fighter (replaces blizzard's circles)
	vg_iceComets = pattern({
		look = "iceShard",
		color = "#9FDCFF",
		emitters = { { kind = "lob", aim = "target", radius = 6 } },
	}),
	-- the avalanche: five snowballs rolling out in a fan (replaces avalanche's cone): step between them or aside
	vg_avalanche = pattern({
		look = "snowball",
		color = "#E8F4FF",
		big = true,
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 5,
				spread = 80,
				speed = 20,
				radius = 2.6,
				range = 34,
				life = 2.4,
				offset = 3,
			},
		},
	}),
	-- three homing frost orbs at a kiting fighter (BossTuning.extra far)
	vg_frostOrbs = pattern({
		look = "frostOrb",
		color = "#7FD4FF",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 3,
				spread = 50,
				speed = 15,
				radius = 1.4,
				homing = 55,
				range = 70,
				life = 5,
				delay = 0.8,
				offset = 3,
			},
		},
	}),
	-- in the air (phase 2) and in phase 3: ice shards fall round random fighters
	vg_skyShards = pattern({
		look = "iceShard",
		color = "#BDE9FF",
		hits = 2,
		hitGap = 0.4,
		emitters = { { kind = "lob", aim = "target", count = 3, every = 0.3, radius = 4, scatter = 8, delay = 1.2 } },
	}),

	-- Hrimvald, the Forefather of Giants (world boss) ----------------------------------------------------------------
	-- a boulder thrown in an arc at a fighter (replaces boulderToss's circle)
	hv_boulder = pattern({
		look = "boulder",
		color = "#9AA6B4",
		big = true,
		emitters = { { kind = "lob", aim = "target", radius = 6 } },
	}),
	-- a run of ice spikes along each of three lanes (replaces iceSpikes' lines)
	hv_spikeWave = pattern({
		look = "spikeWave",
		color = "#9FD8FF",
		big = true,
		emitters = { { kind = "wave", aim = "target", width = 7, thick = 3, length = 50, speed = 30, offset = 3 } },
	}),
	-- a huge ice block on each of five fighters (replaces avalanche's circles)
	hv_iceBlocks = pattern({
		look = "iceShard",
		color = "#BFE6FF",
		big = true,
		emitters = { { kind = "lob", aim = "target", radius = 9 } },
	}),
	-- the ice shard rain: small shards over the whole field, staggered, each with its own circle
	hv_shardRain = pattern({
		look = "iceShard",
		color = "#D6F0FF",
		hits = 2,
		hitGap = 0.5,
		emitters = {
			{ kind = "lob", aim = "target", count = 3, every = 0.12, radius = 3.5, scatter = 9, delay = 1.1 },
			{ kind = "lob", aim = "scatter", count = 10, every = 0.12, radius = 3.5, scatter = 50, delay = 1.1 },
		},
	}),
	-- the frost breath: a cone that turns across the front of the giant
	hv_frostBreath = pattern({
		look = "frostBreath",
		color = "#9FE4FF",
		big = true,
		emitters = {
			{
				kind = "sweep",
				aim = "target",
				radius = 34,
				cone = 34,
				from = -60,
				to = 60,
				seconds = 2.4,
				delay = 1.5,
			},
		},
	}),
	-- phase 2-3: two glacier walls rise at the arena's edge and slide across it, each with one gap to slip through
	hv_glacierWalls = pattern({
		look = "iceWall",
		color = "#A8DCFF",
		big = true,
		emitters = {
			{
				kind = "wave",
				aim = "around",
				arms = 2,
				width = 140,
				thick = 3,
				length = 124,
				back = 62,
				speed = 11,
				gap = 14,
				delay = 2.2,
			},
		},
	}),
	-- a fan of ice javelins hurled at a fighter (and a second at another)
	hv_iceVolley = pattern({
		look = "icicle",
		color = "#CFEFFF",
		emitters = {
			{
				kind = "bolt",
				aim = "target",
				count = 7,
				spread = 50,
				speed = 32,
				radius = 1.3,
				range = 70,
				life = 2.6,
				delay = 1.1,
				offset = 4,
			},
		},
	}),
	-- the stomp's shock ring: jump it or keep away
	hv_stompRing = pattern({
		look = "quakeRing",
		color = "#BFE6FF",
		emitters = { { kind = "ring", aim = "forward", speed = 22, maxRadius = 34, thick = 2.4, low = true } },
	}),
}

return table.freeze({
	byId = PATTERNS,
	get = function(id: string): Pattern?
		return PATTERNS[id]
	end,
})
