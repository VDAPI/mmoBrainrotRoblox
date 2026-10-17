--!strict
-- Named boss items (DESIGN §5.2; S30: rarity Mythic, ids `unique_*` kept for saves): hand-made, fixed stats,
-- own name and lore, only from a boss's personal Mythic roll. Three per boss. Base stats come from the matching
-- base type at the boss level x UNIQUE_MUL (S134g: 1.26, was 1.3; ItemRoll.itemStats keeps them, no rarity multiplier
-- on top); 3 fixed lines and (S134g) two fixed skill effects per class that wears it; the bonuses
-- below are fixed (no rolling; S32: an instance always shows the definition's current bonuses, attack bonuses
-- are percentages since S32). Bind on pickup.

local Bases = require("./Bases")
local Rarities = require("../Rarities")
local Types = require("./Types")

local LIST: { Types.ItemDef } = {}

local UNIQUE_MUL = 1.26

local function unique(
	id: string,
	baseType: string,
	bossId: string,
	level: number,
	glyph: string,
	bonuses: { { stat: string, v: number } },
	fx: ({ string } | { [string]: { string } })?
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
		trait = base.trait, -- S62: named weapons carry their type's trait (STATY 9)
		nameKey = `item.{id}.name`,
		descKey = `item.{id}.desc`,
		icon = { glyph = glyph, color = Rarities.get(Rarities.MYTHIC).hex },
		price = Bases.priceAt(level) * 3,
		fixedBonuses = bonuses,
		fx = fx,
		bossId = bossId,
		bindOnPickup = true,
		rarity = Rarities.MYTHIC,
	})
end

-- S134g (G): a named item's legendary line became two fixed skill effects (Data/ItemEffects: one legendary, one
-- mythic), read from the definition (Logic/ItemEffects.idsOf); class-free items (jewellery) carry a pair per class.
local function perClass(
	warrior: { string },
	hunter: { string },
	mage: { string },
	cleric: { string }
): { [string]: { string } }
	return { Warrior = warrior, Hunter = hunter, Mage = mage, Cleric = cleric }
end

-- Grimrok, Goblin Warlord (20)
unique("unique_grimrok_cleaver", "axe1h", "grimrok", 20, "⚒", {
	{ stat = "physAtk", v = 6 },
	{ stat = "str", v = 6 },
	{ stat = "vs_humanoid", v = 12 },
}, { "crushingBlow_finisher", "earthquake_rupture" })
unique(
	"unique_grimrok_fang",
	"ring",
	"grimrok",
	20,
	"○",
	{
		{ stat = "critChance", v = 4 },
		{ stat = "lifesteal", v = 2 },
		{ stat = "dex", v = 6 },
	},
	perClass(
		{ "mightyStrike_bloodthirst", "bladeWhirl_secondwind" },
		{ "aimedShot_burst", "doubleShot_instinct" },
		{ "firebolt_executioner", "meteor_shards" },
		{ "holyStrike_zeal", "judgement_reckoning" }
	)
)
unique(
	"unique_grimrok_totem",
	"talisman",
	"grimrok",
	20,
	"✧",
	{
		{ stat = "vit", v = 6 },
		{ stat = "hpPct", v = 5 },
		{ stat = "res_humanoid", v = 8 },
	},
	perClass(
		{ "taunt_muster", "bladeWhirl_secondwind" },
		{ "disengage_tailwind", "frostTrap_snare" },
		{ "frostNova_deepcold", "frostNova_maelstrom" },
		{ "renew_lasting", "circleOfLight_aegis" }
	)
)
-- Morvane, Queen of the Crypts (45)
unique("unique_morvane_shroud", "armor_light", "morvane", 45, "♜", {
	{ stat = "int", v = 14 },
	{ stat = "mana", v = 120 },
	{ stat = "res_undead", v = 10 },
}, { Mage = { "blink_arcaneSurge", "frostNova_maelstrom" }, Cleric = { "shieldOfFaith_steadfast", "sanctuary_haven" } })
unique("unique_morvane_scepter", "scepter", "morvane", 45, "⚜", {
	{ stat = "magAtk", v = 8 },
	{ stat = "int", v = 12 },
	{ stat = "healPower", v = 8 },
}, { "heal_smite", "circleOfLight_aegis" })
unique("unique_morvane_bow", "bow", "morvane", 45, "➶", {
	{ stat = "physAtk", v = 6 },
	{ stat = "dex", v = 10 },
	{ stat = "poisonChance", v = 5 },
	-- S144: Hunter's Mark (common) instead of Venom Arrow, now the Crossbow's skill (DESIGN-18 §0.9)
}, { "huntersMark_spread", "volley_followup" })
-- Azgor, Lord of Flames (70)
unique(
	"unique_azgor_heart",
	"necklace",
	"azgor",
	70,
	"◎",
	{
		{ stat = "hp", v = 260 },
		{ stat = "resFire", v = 25 },
		{ stat = "vs_elemental", v = 12 },
	},
	perClass(
		{ "rend_hamstring", "earthquake_rupture" },
		{ "arrowRain_second", "volley_followup" },
		{ "fireball_afterblast", "meteor_shards" },
		{ "radiance_dazzle", "judgement_reckoning" }
	)
)
unique("unique_azgor_staff", "staff", "azgor", 70, "⚕", {
	{ stat = "magAtk", v = 9 },
	{ stat = "int", v = 22 },
	{ stat = "dotPower", v = 15 },
}, { "fireball_afterblast", "meteor_shards" })
unique("unique_azgor_helm", "helmet_heavy", "azgor", 70, "⛑", {
	{ stat = "vit", v = 20 },
	{ stat = "armor", v = 90 },
	{ stat = "res_elemental", v = 10 },
}, { Warrior = { "taunt_muster", "shieldWall_rally" }, Cleric = { "shieldOfFaith_steadfast", "sanctuary_haven" } })
-- Vaelgrath, Frost Dragon (100)
unique("unique_vaelgrath_fang", "sword2h", "vaelgrath", 100, "⚔", {
	{ stat = "physAtk", v = 11 },
	{ stat = "str", v = 35 },
	{ stat = "critDmg", v = 40 },
}, { "rend_hamstring", "bladeWhirl_secondwind" })
unique("unique_vaelgrath_scale", "shield", "vaelgrath", 100, "⛨", {
	{ stat = "armor", v = 160 },
	{ stat = "hpPct", v = 7 },
	{ stat = "res_dragon", v = 10 },
}, {
	Warrior = { "charge_stagger", "shieldWall_rally" },
	Cleric = { "shieldOfFaith_steadfast", "circleOfLight_aegis" },
})
unique("unique_vaelgrath_eye", "orb", "vaelgrath", 100, "◉", {
	{ stat = "magAtk", v = 8 },
	{ stat = "int", v = 29 },
	{ stat = "magicPierce", v = 10 },
}, { "iceShard_shatter", "frostNova_maelstrom" })

return LIST
