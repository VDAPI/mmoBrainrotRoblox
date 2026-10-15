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
				look = "sweep",
				shape = "line",
				length = 40,
				width = 5,
				windup = 1.4,
				damage = 3,
				every = 5,
			}),
			far = table.freeze({
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
				look = "shadowBolt",
				shape = "circle",
				radius = 4.5,
				windup = 1.2,
				damage = 3,
				every = 4,
			}),
		}),
		azgor = table.freeze({
			shield = table.freeze({
				look = "fireWave",
				shape = "line",
				length = 40,
				width = 7,
				windup = 1.4,
				damage = 3.2,
				every = 5,
			}),
			far = table.freeze({
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
				look = "blizzard",
				shape = "circle",
				radius = 6,
				windup = 1.5,
				damage = 3,
				every = 5,
			}),
			far = table.freeze({
				look = "blizzard",
				shape = "circle",
				radius = 6,
				windup = 1.4,
				damage = 3.8,
				cooldown = 7,
			}),
		}),
	}),
})
