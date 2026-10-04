--!strict
-- Unique items (DESIGN §5.2): hand-made, fixed stats, own name and lore, drop only from bosses (rarely
-- Elite II). Three per boss. Base stats come from the matching base type at the boss level x 1.3; the
-- bonuses below are fixed (no rolling). Bind on pickup.

local Bases = require("./Bases")
local Types = require("./Types")

local LIST: { Types.ItemDef } = {}

local UNIQUE_MUL = 1.3

local function unique(
	id: string,
	baseType: string,
	bossId: string,
	level: number,
	glyph: string,
	bonuses: { { stat: string, v: number } }
)
	local base = Bases.byType[baseType]
	assert(base, `Uniques: unknown base {baseType}`)
	local stats: { [string]: number }? = nil
	if base.stats then
		local raw = base.stats(level)
		local scaled: { [string]: number } = {}
		for stat, value in raw do
			scaled[stat] = math.floor(value * UNIQUE_MUL * 10 + 0.5) / 10
		end
		stats = scaled
	end
	local weapon: Types.WeaponStats? = nil
	if base.weapon then
		local raw = base.weapon(level)
		weapon = {
			dmg = math.floor(raw.dmg * UNIQUE_MUL + 0.5),
			mdmg = math.floor(raw.mdmg * UNIQUE_MUL + 0.5),
			speed = raw.speed,
			ranged = raw.ranged,
			twoHanded = raw.twoHanded,
		}
	end
	table.insert(LIST, {
		id = id,
		category = "equipment",
		type = baseType,
		slot = base.slot,
		classes = base.classes,
		level = level,
		tier = level,
		stackable = false,
		maxStack = 1,
		base = stats,
		weapon = weapon,
		nameKey = `item.{id}.name`,
		descKey = `item.{id}.desc`,
		icon = { glyph = glyph, color = "#E8C25A" },
		price = Bases.priceAt(level) * 3,
		fixedBonuses = bonuses,
		bossId = bossId,
		bindOnPickup = true,
	})
end

-- Grimrok, Goblin Warlord (20)
unique("unique_grimrok_cleaver", "axe1h", "grimrok", 20, "⚒", {
	{ stat = "physAtk", v = 12 },
	{ stat = "str", v = 8 },
	{ stat = "critDmg", v = 15 },
	{ stat = "leg_executioner", v = 15 },
})
unique("unique_grimrok_fang", "ring", "grimrok", 20, "○", {
	{ stat = "critChance", v = 4 },
	{ stat = "lifesteal", v = 2 },
	{ stat = "dex", v = 6 },
	{ stat = "goldBonus", v = 10 },
})
unique("unique_grimrok_totem", "talisman", "grimrok", 20, "✧", {
	{ stat = "vit", v = 8 },
	{ stat = "hpPct", v = 6 },
	{ stat = "resPoison", v = 15 },
	{ stat = "leg_killHeal", v = 3 },
})
-- Morvane, Queen of the Crypts (45)
unique("unique_morvane_shroud", "armor_light", "morvane", 45, "♜", {
	{ stat = "int", v = 14 },
	{ stat = "mana", v = 120 },
	{ stat = "resIce", v = 18 },
	{ stat = "leg_lastStand", v = 15 },
})
unique("unique_morvane_scepter", "scepter", "morvane", 45, "⚜", {
	{ stat = "magAtk", v = 30 },
	{ stat = "int", v = 12 },
	{ stat = "hpRegen", v = 6 },
	{ stat = "leg_manaOnHit", v = 2 },
})
unique("unique_morvane_bow", "bow", "morvane", 45, "➶", {
	{ stat = "physAtk", v = 28 },
	{ stat = "dex", v = 14 },
	{ stat = "critChance", v = 6 },
	{ stat = "leg_doubleAttack", v = 5 },
})
-- Azgor, Lord of Flames (70)
unique("unique_azgor_heart", "necklace", "azgor", 70, "◎", {
	{ stat = "hp", v = 260 },
	{ stat = "resFire", v = 25 },
	{ stat = "critDmg", v = 25 },
	{ stat = "leg_eliteDamage", v = 12 },
})
unique("unique_azgor_staff", "staff", "azgor", 70, "⚕", {
	{ stat = "magAtk", v = 60 },
	{ stat = "int", v = 22 },
	{ stat = "critChance", v = 8 },
	{ stat = "leg_bossDamage", v = 10 },
})
unique("unique_azgor_helm", "helmet_heavy", "azgor", 70, "⛑", {
	{ stat = "vit", v = 20 },
	{ stat = "armor", v = 90 },
	{ stat = "resFire", v = 25 },
	{ stat = "leg_thorns", v = 10 },
})
-- Vaelgrath, Frost Dragon (100)
unique("unique_vaelgrath_fang", "sword2h", "vaelgrath", 100, "⚔", {
	{ stat = "physAtk", v = 110 },
	{ stat = "str", v = 35 },
	{ stat = "critDmg", v = 40 },
	{ stat = "leg_bossDamage", v = 12 },
})
unique("unique_vaelgrath_scale", "shield", "vaelgrath", 100, "⛨", {
	{ stat = "armor", v = 160 },
	{ stat = "hpPct", v = 10 },
	{ stat = "resIce", v = 30 },
	{ stat = "leg_lastStand", v = 18 },
})
unique("unique_vaelgrath_eye", "orb", "vaelgrath", 100, "◉", {
	{ stat = "magAtk", v = 90 },
	{ stat = "int", v = 35 },
	{ stat = "manaRegen", v = 12 },
	{ stat = "leg_executioner", v = 18 },
})

return LIST
