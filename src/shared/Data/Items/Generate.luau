--!strict
-- Generates equipment definitions: every base type x every tier (DESIGN §5.3). Ids are "<type>_<tier>",
-- e.g. "sword1h_30", "armor_heavy_1". Names are a tier prefix ("itemTier.<tier>.<gender>") + a base noun
-- ("itemBase.<type>"), so Polish adjectives agree with the noun.

local Bases = require("./Bases")
local Types = require("./Types")

local Generate = {}

-- Icon colour per slot group (placeholder icons until real art exists).
local SLOT_COLORS: { [string]: string } = {
	weapon = "#B0B4BC",
	offhand = "#9C8A72",
	helmet = "#8E96A3",
	armor = "#7D8794",
	gloves = "#8A7E6A",
	boots = "#6F6152",
	necklace = "#E8C25A",
	ring = "#E8C25A",
	talisman = "#C9A45C",
}

function Generate.definition(base: Bases.Base, tier: number): Types.ItemDef
	return {
		id = `{base.type}_{tier}`,
		category = "equipment",
		type = base.type,
		slot = base.slot,
		classes = base.classes,
		level = tier,
		tier = tier,
		stackable = false,
		maxStack = 1,
		base = if base.stats then base.stats(tier) else nil,
		weapon = if base.weapon then base.weapon(tier) else nil,
		elemental = base.elemental,
		bonusGroup = base.bonusGroup,
		namePrefix = `itemTier.{tier}`,
		nameBase = `itemBase.{base.type}`,
		gender = base.gender,
		icon = { glyph = base.glyph, color = SLOT_COLORS[base.slot] or "#9A9DA8" },
		price = Bases.priceAt(tier),
	}
end

function Generate.all(): { [string]: Types.ItemDef }
	local result = {}
	for _, base in Bases.list do
		for _, tier in Bases.tiers do
			local def = Generate.definition(base, tier)
			result[def.id] = def
		end
	end
	return result
end

-- Highest tier <= level (items of level 37 use the tier-35 definition).
function Generate.tierFor(level: number): number
	local best = Bases.tiers[1]
	for _, tier in Bases.tiers do
		if tier <= level then
			best = tier
		end
	end
	return best
end

return Generate
