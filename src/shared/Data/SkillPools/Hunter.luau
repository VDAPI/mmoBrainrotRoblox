--!strict
-- Hunter weapon pools (S137, DESIGN-18 §4.2, §6.3). Transitional: both pools share the whole S78 base (common) until
-- S144 fills the ladder.

local Types = require("./Types")

local PLAN =
	{ "aimedShot", "doubleShot", "disengage", "arrowRain", "venomArrow", "volley", "hawkEye", "predatorInstinct" }

local pools: Types.ClassPools = {
	version = 2, -- S138: directions without the main path (DESIGN-18 §7, §10): a free reset to rethink the talents
	transitional = true,
	defaultPool = "bow", -- the starting bow_1
	pools = {
		{
			id = "bow",
			nameKey = "skills.pool.bow",
			glyph = "➶",
			weapon = { main = { "shortbow", "bow", "longbow" } },
			plan = PLAN,
		},
		{
			id = "crossbow",
			nameKey = "skills.pool.crossbow",
			glyph = "⇶",
			weapon = { main = { "crossbow", "heavycrossbow" } },
			plan = PLAN,
		},
	},
	commonPlan = PLAN,
}

return pools
