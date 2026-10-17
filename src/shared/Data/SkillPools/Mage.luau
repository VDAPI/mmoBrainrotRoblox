--!strict
-- Mage weapon pools (S137, DESIGN-18 §4.2, §6.1). Transitional until S142: S140 filled the fire pool on the shared ladder
-- and the common skills (C1 Blink 4, C2 Mana Shield 12, C3 Evocation 30, C4 Focus 45); Magic Bolt stays common and
-- adaptive (the S1 of every element until S142); the ice and lightning pools keep the old base split by element
-- (S141, S142).

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
	-- nodes: a free reset, DESIGN-18 §10)
	version = 3,
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
		pool("ice", "❄", { "firebolt", "blink", "iceShard", "manaShield", "frostNova", "evocation", "focus" }),
		pool(
			"lightning",
			"ϟ",
			{ "firebolt", "blink", "chainLightning", "manaShield", "evocation", "firewall", "focus" }
		),
	},
	commonPlan = { "firebolt", "blink", "manaShield", "evocation", "focus" },
}

return pools
