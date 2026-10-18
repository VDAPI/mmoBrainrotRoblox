--!strict
-- Warrior weapon pools (S137, DESIGN-18 §4.2, §6.2). S143 filled both pools on the shared ladder: Sword and Shield
-- (`onehand`: block, stuns, guarding the party) and Two-Handed (`twohand`: Fury, bleeds, big swings), with the common
-- skills (C1 Charge 4, C2 Taunt 12, C3 Battle Cry 30, C4 Steel Skin 45): the Warrior is no longer transitional.

local Types = require("./Types")

local pools: Types.ClassPools = {
	-- S138: 2 (directions without the main path). S143: 3 (both pools on the ladder, the directions' new nodes: a free
	-- reset, DESIGN-18 §10)
	version = 3,
	transitional = false,
	defaultPool = "onehand", -- the starting sword1h_1
	pools = {
		-- S143: the ladder order (DESIGN-18 §5), actives before passives
		{
			id = "onehand",
			nameKey = "skills.pool.onehand",
			glyph = "⛨",
			weapon = { main = { "sword1h", "axe1h", "mace1h", "saber1h" } },
			plan = {
				"mightyStrike",
				"shieldSweep",
				"charge",
				"shieldBash",
				"intercept",
				"taunt",
				"crushingBlow",
				"earthquake",
				"battleCry",
				"warBanner",
				"vindicate",
				"shieldWall",
				"fortitude",
				"steelSkin",
				"riposte",
			},
		},
		{
			id = "twohand",
			nameKey = "skills.pool.twohand",
			glyph = "⚔",
			weapon = { main = { "sword2h", "axe2h", "hammer2h", "spear2h" } },
			plan = {
				"brutalStrike",
				"cleave",
				"charge",
				"sunder",
				"bloodlust",
				"taunt",
				"rend",
				"bladeWhirl",
				"battleCry",
				"warStomp",
				"execute",
				"titansWrath",
				"rage",
				"steelSkin",
				"unstoppable",
			},
		},
	},
	commonPlan = { "charge", "taunt", "battleCry", "steelSkin" },
}

return pools
