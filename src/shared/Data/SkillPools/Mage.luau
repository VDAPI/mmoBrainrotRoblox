--!strict
-- Mage weapon pools (S137, DESIGN-18 §4.2, §6.1). Transitional: the S81 base split by element (Magic Bolt stays
-- adaptive and common until S140, Blink common); S140-S142 fill the ladder.

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
	version = 2, -- S138: directions without the main path (DESIGN-18 §7, §10): a free reset to rethink the talents
	transitional = true,
	defaultPool = "fire", -- Data/Elements.DEFAULT, the starting wand
	pools = {
		pool("fire", "♨", { "firebolt", "fireball", "blink", "meteor" }),
		pool("ice", "❄", { "firebolt", "iceShard", "blink", "frostNova" }),
		pool("lightning", "ϟ", { "firebolt", "chainLightning", "blink", "firewall" }),
	},
	commonPlan = { "firebolt", "blink" },
}

return pools
