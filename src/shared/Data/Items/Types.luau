--!strict
-- Item definition shape (DESIGN §5.3). Instances (what players own) are Types.ItemInstance.

export type Category = "equipment" | "material" | "consumable" | "backpack" | "scroll" | "stone" | "tool"

-- Equipment slot groups. "ring" fits ring1 and ring2.
export type SlotGroup =
	"weapon"
	| "offhand"
	| "helmet"
	| "armor"
	| "gloves"
	| "boots"
	| "necklace"
	| "ring"
	| "talisman"
	| "backpack"

export type WeaponStats = {
	dmg: number,
	mdmg: number,
	speed: number, -- attacks per second at +0
	ranged: boolean,
	twoHanded: boolean,
	element: string?, -- mage weapons (from the item instance, S18)
}

export type UseEffect = {
	kind: "potion" | "teleport" | "scroll" | "blessing" | "elixir" | "none",
	resource: ("hp" | "mana" | "energy")?,
	amount: number?,
	target: string?, -- teleport / scroll specifics (S06–S07)
}

export type ItemDef = {
	id: string,
	category: Category,
	type: string, -- base type: "sword1h", "armor_heavy", "potion_hp", "ore", ...
	slot: SlotGroup?, -- equippable when set
	classes: { string }?, -- nil = every class
	level: number, -- required character level
	tier: number?, -- generated equipment tier (1, 5, 10, ..., 100)
	stackable: boolean,
	maxStack: number,
	base: { [string]: number }?, -- base stats of a common +0 item (non-weapon stats)
	weapon: WeaponStats?,
	elemental: boolean?, -- mage weapon: instances carry an element (S18)
	bonusGroup: string?, -- Data/Bonuses pool
	-- Name: a fixed key, or a generated prefix + base noun with Polish gender agreement.
	nameKey: string?,
	namePrefix: string?, -- "itemTier.<tier>" (resolved as "<prefix>.<gender>")
	nameBase: string?, -- "itemBase.<type>"
	gender: ("m" | "f" | "n" | "p")?,
	descKey: string?,
	icon: { glyph: string, color: string },
	price: number, -- sell price of one common unit
	buyPrice: number?, -- shop price (S06)
	use: UseEffect?,
	capacity: number?, -- backpacks
	-- Named (hand-made Mythic) boss items: fixed bonuses and the boss that drops them.
	fixedBonuses: { { stat: string, v: number } }?,
	bossId: string?,
	bindOnPickup: boolean?,
	noSell: boolean?, -- S31: merchants refuse it (the tooltip says "Cannot be sold"; its value still shows)
	-- Fixed rarity of stackable items (blessings) and of named boss items; other equipment rolls its rarity.
	rarity: number?,
}

return nil
