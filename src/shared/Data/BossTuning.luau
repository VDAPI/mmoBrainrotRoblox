--!strict
-- Boss tuning constants outside Data/Bosses (S87, balance plan D3). Data only; read by Entities/Boss,
-- BossScripts and the balance model. Not exported to the wiki: the scripts' "local NAME = number" lines stay
-- the wiki's source (tools/WikiData/Bosses.scriptConsts).

return table.freeze({
	-- Seconds between two attacks of any kind (Entities/Boss.Step).
	globalGap = 2.2,
	-- Scripted hazards by boss and hazard id: damage as a multiple of the boss attack, like any attack.
	hazards = table.freeze({
		-- S93: 0.7 -> 2.2 (one tick ~20 % of a level 70 Mage's HP after atkMul 0.36)
		azgor = table.freeze({ lava = 2.2 }),
		vaelgrath = table.freeze({ freezingStorm = 3.9 }),
	}),
	-- FIX 2026-10-15 (owner): bosses outside the S87 schedule (the balance model counts only Data/Bosses.attacks).
	-- `shield`: while the summoned helpers shield it, the boss stays at the centre but keeps casting this at a random
	-- fighter every `every` seconds. `far`: no fighter within farRange for farAfter seconds (kiting) = this ranged
	-- attack on its own cooldown, before the usual pick. `look` = an attack id of the boss in Data/BossMotions (pose,
	-- effect, sound); the numbers are like Data/Bosses attacks (damage x the boss attack).
	farRange = 14,
	farAfter = 2.5,
	extra = table.freeze({
		grimrok = table.freeze({
			shield = table.freeze({
				pattern = "gr_axeFan", -- S159: dodgeable axes (Data/HazardPatterns) instead of the line
				look = "sweep",
				shape = "line",
				length = 40,
				width = 5,
				windup = 1.4,
				damage = 3,
				every = 5,
			}),
			far = table.freeze({
				pattern = "gr_axeThrow",
				look = "sweep",
				shape = "line",
				length = 48,
				width = 5,
				windup = 1.2,
				damage = 4.5,
				cooldown = 6,
			}),
		}),
		morvane = table.freeze({
			shield = table.freeze({
				pattern = "mv_spiral",
				look = "shadowBolt",
				shape = "circle",
				radius = 4.5,
				windup = 1.2,
				damage = 3,
				every = 6, -- S159: 4 -> 6, a spiral lasts ~4 s
			}),
		}),
		azgor = table.freeze({
			shield = table.freeze({
				pattern = "az_flameWall",
				look = "fireWave",
				shape = "line",
				length = 40,
				width = 7,
				windup = 1.4,
				damage = 3.2,
				every = 5,
			}),
			far = table.freeze({
				pattern = "az_fireballs",
				look = "meteor",
				shape = "circle",
				radius = 6,
				windup = 1.4,
				damage = 3.6,
				cooldown = 7,
			}),
		}),
		vaelgrath = table.freeze({
			shield = table.freeze({
				pattern = "vg_iceComets",
				look = "blizzard",
				shape = "circle",
				radius = 6,
				windup = 1.5,
				damage = 3,
				every = 5,
			}),
			far = table.freeze({
				pattern = "vg_frostOrbs",
				look = "blizzard",
				shape = "circle",
				radius = 6,
				windup = 1.4,
				damage = 3.8,
				cooldown = 7,
			}),
		}),
	}),
	-- S159 (owner 2026-10-21, "projectiles you have to dodge"; Logic/Hazards, Data/HazardPatterns, HazardService):
	--   replace  attack id of Data/Bosses -> pattern: the attack keeps its numbers, schedule and windup (the balance
	--            model counts it as before), but its damage comes by the pattern's dodgeable hazards (one hit per player)
	--            instead of the area; a dodged hazard deals nothing
	--   add      attack id -> a pattern that follows the attack (`at` "area": from its area, "self": from the boss),
	--            starting at the blow, `damage` x the boss attack per hit
	--   ambient  patterns of the later phases on their own timer (`every` s, at `count` random fighters, or the arena
	--            centre with `centre`), cast like an attack (the boss stands for the pattern's warning; they share the
	--            global gap), `damage` x the boss attack per hit; not while shielded
	-- A dodgeable hit of an add / ambient pattern counts like a big blow to dodge (Balance model: dodged);
	-- tests/hazards.spec keeps one hit at most HAZARD_HIT_MAX of a Mage's HP at the boss's level.
	-- The bounce circle of the dungeon arenas (the flat floor is 74 studs, nothing collidable within 50) and of the
	-- world boss's barrow.
	arenaRadius = table.freeze({ dungeon = 46, world = 64 }),
	patterns = table.freeze({
		grimrok = table.freeze({
			replace = table.freeze({ groundSplitter = "gr_fissure" }),
			add = table.freeze({
				leap = table.freeze({ pattern = "gr_quakeRing", damage = 2, at = "area" }),
				whirlwind = table.freeze({ pattern = "gr_whirlAxes", damage = 2.4, at = "self" }),
			}),
			ambient = table.freeze({
				table.freeze({
					pattern = "gr_bombs",
					phases = { 2, 3 },
					every = 11,
					count = 2,
					centre = false,
					damage = 2.4,
				}),
			}),
		}),
		morvane = table.freeze({
			replace = table.freeze({ shadowBolt = "mv_soulOrbs", shadowBoltFast = "mv_soulVolley" }),
			ambient = table.freeze({
				table.freeze({
					pattern = "mv_spiral",
					phases = { 3 },
					every = 15,
					count = 1,
					centre = true,
					damage = 2.6,
				}),
			}),
		}),
		azgor = table.freeze({
			replace = table.freeze({ fireWave = "az_flameWall", meteor = "az_meteor" }),
			ambient = table.freeze({
				table.freeze({
					pattern = "az_magma",
					phases = { 2, 3 },
					every = 14,
					count = 1,
					centre = true,
					damage = 2.8,
				}),
			}),
		}),
		vaelgrath = table.freeze({
			replace = table.freeze({ blizzard = "vg_iceComets", avalanche = "vg_avalanche" }),
			ambient = table.freeze({
				table.freeze({
					pattern = "vg_skyShards",
					phases = { 2, 3 },
					every = 8,
					count = 2,
					centre = false,
					damage = 2.6,
				}),
				table.freeze({
					pattern = "vg_frostOrbs",
					phases = { 3 },
					every = 16,
					count = 1,
					centre = false,
					damage = 3,
				}),
			}),
		}),
		hrimvald = table.freeze({
			replace = table.freeze({
				boulderToss = "hv_boulder",
				iceSpikes = "hv_spikeWave",
				avalanche = "hv_iceBlocks",
			}),
			add = table.freeze({
				glacierStomp = table.freeze({ pattern = "hv_stompRing", damage = 2.2, at = "self" }),
			}),
			ambient = table.freeze({
				table.freeze({
					pattern = "hv_shardRain",
					phases = { 1, 2, 3 },
					every = 22,
					count = 4,
					centre = false,
					damage = 2,
				}),
				table.freeze({
					pattern = "hv_frostBreath",
					phases = { 1, 2, 3 },
					every = 26,
					count = 1,
					centre = false,
					damage = 4.2,
				}),
				table.freeze({
					pattern = "hv_iceVolley",
					phases = { 1, 2, 3 },
					every = 30,
					count = 2,
					centre = false,
					damage = 3,
				}),
				table.freeze({
					pattern = "hv_glacierWalls",
					phases = { 2, 3 },
					every = 34,
					count = 1,
					centre = true,
					damage = 4,
				}),
			}),
		}),
	}),
})
