--!strict
-- Cleric weapon pools (S137, DESIGN-18 §4.2, §6.4). Transitional: both pools share the whole S71 base (common) until
-- S145 fills the ladder.

local Types = require("./Types")

local PLAN =
	{ "holyStrike", "heal", "radiance", "circleOfLight", "shieldOfFaith", "judgement", "devotion", "divineWrath" }

local pools: Types.ClassPools = {
	version = 1,
	transitional = true,
	defaultPool = "hammer", -- the starting mace1h_1
	pools = {
		{
			id = "light",
			nameKey = "skills.pool.light",
			glyph = "✧",
			weapon = { main = { "scepter", "holystaff" } },
			plan = PLAN,
		},
		{
			id = "hammer",
			nameKey = "skills.pool.hammer",
			glyph = "✚",
			weapon = { main = { "mace1h", "flail1h" } },
			plan = PLAN,
		},
	},
	commonPlan = PLAN,
}

return pools
