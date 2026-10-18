--!strict
-- Hunter weapon pools (S137, DESIGN-18 §4.2, §6.3). S144 filled both pools on the shared ladder: Bow (`bow`: quick
-- shots, crits, movement, the falcon) and Crossbow (`crossbow`: heavy bolts, traps, poison, piercing), with the common
-- skills (C1 Disengage 4, C2 Hunter's Mark 12, C3 Draw a Bead 30, C4 Predator's Instinct 45): the Hunter is no longer
-- transitional. The pool comes from the main weapon only; the quiver means nothing for it.

local Types = require("./Types")

local pools: Types.ClassPools = {
	-- S138: 2 (directions without the main path). S144: 3 (both pools on the ladder, the directions' new nodes: a free
	-- reset, DESIGN-18 §10)
	version = 3,
	transitional = false,
	defaultPool = "bow", -- the starting bow_1
	pools = {
		-- S144: the ladder order (DESIGN-18 §5), actives before passives
		{
			id = "bow",
			nameKey = "skills.pool.bow",
			glyph = "➶",
			weapon = { main = { "shortbow", "bow", "longbow" } },
			plan = {
				"aimedShot",
				"arrowRain",
				"disengage",
				"pinningShot",
				"windstep",
				"huntersMark",
				"doubleShot",
				"volley",
				"drawBead",
				"falcon",
				"heartseeker",
				"stormArrow",
				"hawkEye",
				"predatorInstinct",
				"agility",
			},
		},
		{
			id = "crossbow",
			nameKey = "skills.pool.crossbow",
			glyph = "⇶",
			weapon = { main = { "crossbow", "heavycrossbow" } },
			plan = {
				"heavyBolt",
				"piercingArrow",
				"disengage",
				"frostTrap",
				"camouflage",
				"huntersMark",
				"venomArrow",
				"venomSnare",
				"drawBead",
				"netShot",
				"deadlyBolt",
				"snarefield",
				"toxicTips",
				"predatorInstinct",
				"quickReload",
			},
		},
	},
	commonPlan = { "disengage", "huntersMark", "drawBead", "predatorInstinct" },
}

return pools
