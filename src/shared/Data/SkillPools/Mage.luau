--!strict
-- Mage weapon pools (S137, DESIGN-18 §4.2, §6.1). S140 filled the fire pool on the shared ladder and the common skills
-- (C1 Blink 4, C2 Mana Shield 12, C3 Evocation 30, C4 Focus 45); S141 filled the ice pool (Ice Shard S1 at 1, Frost
-- Nova K1 at 6 and nine new skills); S142 filled the lightning pool (Lightning Bolt S1, Chain Lightning A1 at 3,
-- Thunderstorm A2 at 26 and eight new skills) and made Fire Bolt the fire pool's S1: the Mage is no longer transitional.

local Types = require("./Types")

local WEAPONS = { "wand", "staff", "runestaff" }

local function pool(id: string, glyph: string, plan: { string }): Types.PoolDef
	return {
		id = id,
		nameKey = `skills.pool.{id}`,
		glyph = glyph,
		weapon = { main = WEAPONS, element = id },
		plan = plan,
	}
end

local pools: Types.ClassPools = {
	-- S138: 2 (directions without the main path). S140: 3 (the fire pool, the common skills, the directions' new
	-- nodes: a free reset, DESIGN-18 §10). S141: 4 (the ice pool). S142: 5 (the lightning pool, Fire Bolt in the fire
	-- pool only)
	version = 5,
	defaultPool = "fire", -- Data/Elements.DEFAULT, the starting wand
	pools = {
		-- S140: the ladder order (DESIGN-18 §5), actives before passives
		pool("fire", "♨", {
			"firebolt",
			"fireball",
			"blink",
			"flameWave",
			"emberShield",
			"manaShield",
			"pyroblast",
			"meteor",
			"evocation",
			"combustion",
			"immolate",
			"meteorStorm",
			"kindling",
			"focus",
			"phoenixHeart",
		}),
		-- S141: the ice pool in the ladder order
		pool("ice", "❄", {
			"iceShard",
			"hailstorm",
			"blink",
			"frostNova",
			"iceBarrier",
			"manaShield",
			"glacialSpike",
			"frozenOrb",
			"evocation",
			"deepFreeze",
			"shatter",
			"blizzard",
			"wintersGrip",
			"focus",
			"iceBlood",
		}),
		-- S142: the lightning pool in the ladder order
		pool("lightning", "ϟ", {
			"lightningBolt",
			"chainLightning",
			"blink",
			"staticShock",
			"stormArmor",
			"manaShield",
			"thunderStrike",
			"firewall",
			"evocation",
			"ballLightning",
			"lightningLance",
			"tempest",
			"overcharge",
			"focus",
			"conductor",
		}),
	},
	commonPlan = { "blink", "manaShield", "evocation", "focus" },
}

return pools
