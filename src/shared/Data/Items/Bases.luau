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
	-- Mage weapons carry an element (S18, DESIGN §5.8).
	elemental: boolean?,
}

local WARRIOR, HUNTER, MAGE, CLERIC = "Warrior", "Hunter", "Mage", "Cleric"

-- % attack of off-hands and rings at level 0 (S32, tests/balance.spec: 2H vs 1H + off-hand).
local QUIVER_PCT, TOME_PCT, ORB_PCT, RELIC_PCT, RING_PCT = 8, 5, 8, 5, 3.5

local function round(x: number): number
	return math.floor(x + 0.5)
end

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
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
				-- S32: a small HP line (Mages had ~25 % less HP than Warriors and died in groups).
				return {
					armor = round((2 + 1.0 * level) * f),
					mres = round((2 + 1.4 * level) * f),
					hp = round((3 + 1.5 * level) * f),
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
		weapon = weapon(1.14, 0, 1.05, false, false),
	},
	{
		type = "mace1h",
		slot = "weapon",
		classes = { WARRIOR, CLERIC },
		bonusGroup = "weapon",
		glyph = "⚚",
		gender = "f",
		weapon = weapon(1.0, 1.0, 1.1, false, false),
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
		weapon = weapon(1.69, 0, 0.8, false, true),
	},
	{
		type = "hammer2h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "⚒",
		gender = "m",
		weapon = weapon(1.82, 0, 0.75, false, true),
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
		elemental = true,
	},
	{
		type = "staff",
		slot = "weapon",
		classes = { MAGE },
		bonusGroup = "weapon",
		glyph = "⚕",
		gender = "m",
		weapon = weapon(0, 1.47, 0.85, true, true),
		elemental = true,
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
	-- More weapon types per class (S18, DESIGN §5.8): speed vs damage trade-offs at about the same DPS.
	-- S32: two-handed multipliers lowered (staff 1.6 → 1.47, runestaff 2.0 → 1.75, holy staff 1.75 → 1.5, ...) so a
	-- two-handed weapon gives the same DPS x survivability as 1H + off-hand (±3 %, tests/balance.spec).
	{
		type = "saber1h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "⚔",
		gender = "f",
		weapon = weapon(0.85, 0, 1.4, false, false),
	},
	{
		type = "spear2h",
		slot = "weapon",
		classes = { WARRIOR },
		bonusGroup = "weapon",
		glyph = "↟",
		gender = "f",
		weapon = weapon(1.53, 0, 0.88, false, true),
	},
	{
		type = "shortbow",
		slot = "weapon",
		classes = { HUNTER },
		bonusGroup = "weapon",
		glyph = "➶",
		gender = "m",
		weapon = weapon(0.9, 0, 1.3, true, false),
	},
	{
		type = "longbow",
		slot = "weapon",
		classes = { HUNTER },
		bonusGroup = "weapon",
		glyph = "➶",
		gender = "m",
		weapon = weapon(1.47, 0, 0.78, true, false),
	},
	{
		type = "heavycrossbow",
		slot = "weapon",
		classes = { HUNTER },
		bonusGroup = "weapon",
		glyph = "➹",
		gender = "f",
		weapon = weapon(1.85, 0, 0.62, true, false),
	},
	{
		type = "runestaff",
		slot = "weapon",
		classes = { MAGE },
		bonusGroup = "weapon",
		glyph = "⚕",
		gender = "m",
		weapon = weapon(0, 1.75, 0.72, true, true),
		elemental = true,
	},
	{
		type = "flail1h",
		slot = "weapon",
		classes = { CLERIC },
		bonusGroup = "weapon",
		glyph = "⚚",
		gender = "m",
		weapon = weapon(1.15, 1.2, 0.95, false, false),
	},
	{
		type = "holystaff",
		slot = "weapon",
		classes = { CLERIC },
		bonusGroup = "weapon",
		glyph = "✟",
		gender = "m",
		weapon = weapon(0.5, 1.5, 0.8, false, true),
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
		-- S32: attack off-hands and rings give a % of the attack ("<stat>Pct"), so 1H + off-hand keeps up with
		-- two-handed weapons at every level (a flat bonus fell behind the stat-scaled weapon damage).
		stats = function(level)
			return { physAtkPct = round1(QUIVER_PCT + 0.03 * level) }
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
			return { magAtkPct = round1(TOME_PCT + 0.03 * level), mana = round(8 + 3 * level) }
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
			return { magAtkPct = round1(ORB_PCT + 0.04 * level) }
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
			return { magAtkPct = round1(RELIC_PCT + 0.03 * level), hpRegen = round1(0.5 + 0.05 * level) }
		end,
	},
	-- Jewellery (every class)
	{
		type = "necklace",
		slot = "necklace",
		bonusGroup = "necklace",
		glyph = "◎",
		gender = "m",
		-- S32: more HP (it was +90 at level 20, ~10 % of a Warrior's HP).
		stats = function(level)
			return { hp = round(12 + 6 * level) }
		end,
	},
	{
		type = "ring",
		slot = "ring",
		bonusGroup = "ring",
		glyph = "○",
		gender = "m",
		-- Both attacks: every class uses only its own one, so the ring is class-neutral (S32 decision).
		stats = function(level)
			return { physAtkPct = round1(RING_PCT + 0.03 * level), magAtkPct = round1(RING_PCT + 0.03 * level) }
		end,
	},
	{
		type = "talisman",
		slot = "talisman",
		bonusGroup = "talisman",
		glyph = "✧",
		gender = "m",
		-- S32: HP + armour + magic resistance for every class (was magic resistance + mana).
		stats = function(level)
			return { hp = round(6 + 3 * level), armor = round(2 + 1 * level), mres = round(2 + 1 * level) }
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
