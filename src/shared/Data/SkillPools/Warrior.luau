--!strict
-- Warrior weapon pools (S137, DESIGN-18 §4.2, §6.2). Transitional: both pools share the whole S75 base (common) until
-- S143 fills the ladder.

local Types = require("./Types")

local PLAN = { "mightyStrike", "charge", "bladeWhirl", "taunt", "bloodlust", "earthquake", "steelSkin", "riposte" }

local pools: Types.ClassPools = {
	version = 1,
	transitional = true,
	defaultPool = "onehand", -- the starting sword1h_1
	pools = {
		{
			id = "onehand",
			nameKey = "skills.pool.onehand",
			glyph = "⛨",
			weapon = { main = { "sword1h", "axe1h", "mace1h", "saber1h" } },
			plan = PLAN,
		},
		{
			id = "twohand",
			nameKey = "skills.pool.twohand",
			glyph = "⚔",
			weapon = { main = { "sword2h", "axe2h", "hammer2h", "spear2h" } },
			plan = PLAN,
		},
	},
	commonPlan = PLAN,
}

return pools
