--!strict
-- Cleric weapon pools (S137, DESIGN-18 §4.2, §6.4). S145 filled both pools on the shared ladder: Scepter and Staff
-- (`light`: heals, shields, fields) and Mace and Flail (`hammer`: melee light, brands, weakening), with the common skills
-- (C1 Heal 4, C2 Circle of Light 12, C3 Resurrection 30, C4 Devotion 45). The pool comes from the main weapon only; a
-- shield or a relic in the off hand means nothing for it.

local Types = require("./Types")

local pools: Types.ClassPools = {
	-- S138: 2 (directions without the main path). S145: 3 (both pools on the ladder, the directions' new nodes: a free
	-- reset, DESIGN-18 §10)
	version = 3,
	defaultPool = "hammer", -- the starting mace1h_1
	pools = {
		-- S145: the ladder order (DESIGN-18 §5), actives before passives
		{
			id = "light",
			nameKey = "skills.pool.light",
			glyph = "✧",
			weapon = { main = { "scepter", "holystaff" } },
			plan = {
				"lightRay",
				"radiance",
				"heal",
				"blindingLight",
				"shieldOfFaith",
				"circleOfLight",
				"renew",
				"sanctuary",
				"resurrection",
				"purify",
				"miracle",
				"guardianAngel",
				"grace",
				"devotion",
				"guidingLight",
			},
		},
		{
			id = "hammer",
			nameKey = "skills.pool.hammer",
			glyph = "✚",
			weapon = { main = { "mace1h", "flail1h" } },
			plan = {
				"holyStrike",
				"consecrate",
				"heal",
				"holyChains",
				"auraOfEndurance",
				"circleOfLight",
				"brandOfLight",
				"holyNova",
				"resurrection",
				"rebuke",
				"judgement",
				"hammerOfHeaven",
				"divineWrath",
				"devotion",
				"zeal",
			},
		},
	},
	commonPlan = { "heal", "circleOfLight", "resurrection", "devotion" },
}

return pools
