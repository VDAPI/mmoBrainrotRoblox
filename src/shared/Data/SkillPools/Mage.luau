--!strict
-- Mage weapon pools (S137, DESIGN-18 §4.2, §6.1). Transitional until S142: S140 filled the fire pool on the shared ladder
-- and the common skills (C1 Blink 4, C2 Mana Shield 12, C3 Evocation 30, C4 Focus 45); Magic Bolt stays common and
-- adaptive (the S1 of every element until S142); S141 filled the ice pool (Ice Shard S1 at 1, Frost Nova K1 at 6 and
-- nine new skills); the lightning pool keeps the old base split by element (S142).

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
	-- nodes: a free reset, DESIGN-18 §10). S141: 4 (the ice pool)
	version = 4,
	transitional = true,
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
		-- S141: the ice pool in the ladder order (Ice Shard is S1; Magic Bolt stays common and adaptive until S142)
		pool("ice", "❄", {
			"iceShard",
			"firebolt",
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
		pool(
			"lightning",
			"ϟ",
			{ "firebolt", "blink", "chainLightning", "manaShield", "evocation", "firewall", "focus" }
		),
	},
	commonPlan = { "firebolt", "blink", "manaShield", "evocation", "focus" },
}

return pools
