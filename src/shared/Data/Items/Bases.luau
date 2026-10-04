--!strict
-- Equipment base types (DESIGN §5.3). Each base turns a tier level into stats; Generate.luau creates one
-- definition per tier. Armour weights (S04 decision): heavy = Warrior, Cleric; medium = Hunter;
-- light = Mage, Cleric.

local Types = require("./Types")

export type Base = {
	type: string,
	slot: Types.SlotGroup,
	classes: { string }?,
	bonusGroup: string,
	glyph: string,
	gender: "m" | "f" | "n" | "p",
	-- Non-weapon base stats at level L.
	stats: ((level: number) -> { [string]: number })?,
	-- Weapon damage at level L (before rarity and upgrades).
	weapon: ((level: number) -> Types.WeaponStats)?,
}

local WARRIOR, HUNTER, MAGE, CLERIC = "Warrior", "Hunter", "Mage", "Cleric"

local function round(x: number): number
	return math.floor(x + 0.5)
end

-- Weapon damage curve: (6 + 2.2 L) x multiplier.
local function weapon(dmgMul: number, mdmgMul: number, speed: number, ranged: boolean, twoHanded: boolean)
	return function(level: number): Types.WeaponStats
		local curve = 6 + 2.2 * level
		return {
			dmg = round(curve * dmgMul),
			mdmg = round(curve * mdmgMul),
			speed = speed,
			ranged = ranged,
			twoHanded = twoHanded,
		}
	end
end

-- Armour: a piece factor (helmet 0.6, chest 1.0, gloves 0.45, boots 0.5) scales the weight curve.
local PIECES: { { slot: Types.SlotGroup, factor: number, glyph: string } } = {
	{ slot = "helmet", factor = 0.6, glyph = "⛑" },
	{ slot = "armor", factor = 1.0, glyph = "♜" },
	{ slot = "gloves", factor = 0.45, glyph = "✋" },
	{ slot = "boots", factor = 0.5, glyph = "⛸" },
}

local WEIGHTS: { { id: string, classes: { string }, stats: (level: number, factor: number) -> { [string]: number } } } =
	{
		{
			id = "heavy",
			classes = { WARRIOR, CLERIC },
			stats = function(level, f)
				return { armor = round((4 + 2.4 * level) * f), hp = round((6 + 3 * level) * f) }
			end,
		},
		{
			id = "medium",
			classes = { HUNTER },
			stats = function(level, f)
				return {
					armor = round((3 + 1.7 * level) * f),
					hp = round((5 + 2.5 * level) * f),
					dodge = math.floor((0.5 + 0.02 * level) * f * 10 + 0.5) / 10,
				}
			end,
		},
		{
			id = "light",
			classes = { MAGE, CLERIC },
			stats = function(level, f)
				return {
					armor = round((2 + 1.0 * level) * f),
					mres = round((2 + 1.4 * level) * f),
					mana = round((5 + 2.5 * level) * f),
				}
			end,
		},
	}

-- Polish genders of the armour nouns: helmet, chest, gloves, boots per weight.
local ARMOR_GENDERS: { [string]: { [string]: "m" | "f" | "n" | "p" } } = {
	heavy = { helmet = "m", armor = "f", gloves = "p", boots = "p" },
	medium = { helmet = "m", armor = "f", gloves = "p", boots = "p" },
	light = { helmet = "m", armor = "f", gloves = "p", boots = "p" },
}

local LIST: { Base } = {
	-- Weapons
	{
		type = "sword1h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "🗡",
		gender = "m",
		weapon = weapon(1.0, 0, 1.2, false, false),
	},
	{
		type = "axe1h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "⚒",
		gender = "m",
		weapon = weapon(1.1, 0, 1.05, false, false),
	},
	{
		type = "mace1h",
		slot = "weapon",
		classes = { WARRIOR, CLERIC },
		bonusGroup = "weapon",
		glyph = "⚚",
		gender = "f",
		weapon = weapon(1.0, 0.7, 1.1, false, false),
	},
	{
		type = "sword2h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "⚔",
		gender = "m",
		weapon = weapon(1.6, 0, 0.85, false, true),
	},
	{
		type = "axe2h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "⚒",
		gender = "m",
		weapon = weapon(1.75, 0, 0.8, false, true),
	},
	{
		type = "hammer2h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "⚒",
		gender = "m",
		weapon = weapon(1.85, 0, 0.75, false, true),
	},
	{
		type = "bow",
		slot = "weapon",
		classes = { HUNTER },
		bonusGroup = "weapon",
		glyph = "➶",
		gender = "m",
		weapon = weapon(1.15, 0, 1.0, true, false),
	},
	{
		type = "crossbow",
		slot = "weapon",
		classes = { HUNTER },
		bonusGroup = "weapon",
		glyph = "➹",
		gender = "f",
		weapon = weapon(1.45, 0, 0.75, true, false),
	},
	{
		type = "wand",
		slot = "weapon",
		classes = { MAGE },
		bonusGroup = "weapon",
		glyph = "✦",
		gender = "f",
		weapon = weapon(0, 1.0, 1.15, true, false),
	},
	{
		type = "staff",
		slot = "weapon",
		classes = { MAGE },
		bonusGroup = "weapon",
		glyph = "⚕",
		gender = "m",
		weapon = weapon(0, 1.6, 0.85, true, true),
	},
	{
		type = "scepter",
		slot = "weapon",
		classes = { CLERIC },
		bonusGroup = "weapon",
		glyph = "⚜",
		gender = "n",
		weapon = weapon(0.4, 1.1, 1.0, false, false),
	},
	-- Off-hand
	{
		type = "shield",
		slot = "offhand",
		classes = { WARRIOR, CLERIC },
		bonusGroup = "shield",
		glyph = "⛨",
		gender = "f",
		stats = function(level)
			return { armor = round(3 + 1.6 * level), hp = round(10 + 4 * level) }
		end,
	},
	{
		type = "quiver",
		slot = "offhand",
		classes = { HUNTER },
		bonusGroup = "quiver",
		glyph = "➵",
		gender = "m",
		stats = function(level)
			return { physAtk = round(2 + 0.6 * level) }
		end,
	},
	{
		type = "tome",
		slot = "offhand",
		classes = { MAGE },
		bonusGroup = "magicOffhand",
		glyph = "📖",
		gender = "f",
		stats = function(level)
			return { magAtk = round(2 + 0.6 * level), mana = round(8 + 3 * level) }
		end,
	},
	{
		type = "orb",
		slot = "offhand",
		classes = { MAGE },
		bonusGroup = "magicOffhand",
		glyph = "◉",
		gender = "f",
		stats = function(level)
			return { magAtk = round(3 + 0.8 * level) }
		end,
	},
	{
		type = "relic",
		slot = "offhand",
		classes = { CLERIC },
		bonusGroup = "magicOffhand",
		glyph = "✚",
		gender = "f",
		stats = function(level)
			return { magAtk = round(2 + 0.5 * level), hpRegen = math.floor((0.5 + 0.05 * level) * 10 + 0.5) / 10 }
		end,
	},
	-- Jewellery (every class)
	{
		type = "necklace",
		slot = "necklace",
		bonusGroup = "necklace",
		glyph = "◎",
		gender = "m",
		stats = function(level)
			return { hp = round(10 + 4 * level) }
		end,
	},
	{
		type = "ring",
		slot = "ring",
		bonusGroup = "ring",
		glyph = "○",
		gender = "m",
		stats = function(level)
			return { physAtk = round(1 + 0.4 * level), magAtk = round(1 + 0.4 * level) }
		end,
	},
	{
		type = "talisman",
		slot = "talisman",
		bonusGroup = "talisman",
		glyph = "✧",
		gender = "m",
		stats = function(level)
			return { mres = round(2 + 1.2 * level), mana = round(5 + 2 * level) }
		end,
	},
}

-- Armour bases: <slot>_<weight>, e.g. helmet_heavy, armor_light.
for _, weight in WEIGHTS do
	for _, piece in PIECES do
		local stats = weight.stats
		local factor = piece.factor
		local base: Base = {
			type = `{piece.slot}_{weight.id}`,
			slot = piece.slot,
			classes = weight.classes,
			bonusGroup = piece.slot,
			glyph = piece.glyph,
			gender = ARMOR_GENDERS[weight.id][piece.slot],
			stats = function(level)
				return stats(level, factor)
			end,
		}
		table.insert(LIST, base)
	end
end

local byType: { [string]: Base } = {}
for _, base in LIST do
	byType[base.type] = base
end

return table.freeze({
	list = LIST,
	byType = byType,
	-- Tier levels for generated items (DESIGN §5.3: every 5 levels).
	tiers = { 1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 },
	-- Sell price of a common +0 item of level L.
	priceAt = function(level: number): number
		return math.floor(5 + 4 * level + 0.6 * level * level)
	end,
})
