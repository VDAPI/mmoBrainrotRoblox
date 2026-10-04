--!strict
-- Cosmetics and pets (DESIGN §22): looks only, never stats. Bought with Dragon Shards in the wardrobe and
-- owned by the account. Visuals are placeholders built from parts/particles (Util/CosmeticLook); real
-- models can replace them later without touching this table's shape.
--   outfit  : body colours + accessory parts ("hood", "crown", "cape", "pauldrons", "horns", "halo", "mask")
--   aura    : particles around the character
--   trail   : a trail behind the character while moving
--   weapon  : particles on the weapon in hand
--   pet     : a small creature that follows its owner

export type Kind = "outfit" | "aura" | "trail" | "weapon" | "pet"

export type Def = {
	id: string,
	kind: Kind,
	nameKey: string,
	price: number, -- Dragon Shards
	icon: string,
	color: string, -- main colour (hex)
	color2: string?, -- secondary colour
	parts: { string }?, -- outfit accessories
	shape: string?, -- pet body plan: "fox" | "owl" | "dragon" | "wisp" | "cat" | "frog"
}

local LIST: { Def } = {}

local function add(id: string, kind: Kind, price: number, icon: string, color: string, extra: { [string]: any }?)
	local def: any = { id = id, kind = kind, nameKey = `cosmetic.{id}`, price = price, icon = icon, color = color }
	for k, v in (extra or {}) :: { [string]: any } do
		def[k] = v
	end
	table.insert(LIST, def)
end

-- Outfits
add("outfit_ranger", "outfit", 300, "♣", "#3E5B33", { color2 = "#6B4E2E", parts = { "hood", "cape" } })
add("outfit_paladin", "outfit", 450, "✚", "#D8D2C0", { color2 = "#C9A45C", parts = { "pauldrons", "cape" } })
add("outfit_shadow", "outfit", 450, "☾", "#1E1E26", { color2 = "#5A2A7A", parts = { "hood", "mask" } })
add("outfit_royal", "outfit", 800, "♛", "#6B1F2A", { color2 = "#E8C25A", parts = { "crown", "cape" } })
add("outfit_frost", "outfit", 600, "❄", "#BFE3F2", { color2 = "#4A8FE7", parts = { "pauldrons", "crown" } })
add("outfit_ember", "outfit", 600, "♨", "#7A2A12", { color2 = "#FF8A2A", parts = { "horns", "cape" } })
add("outfit_druid", "outfit", 350, "❦", "#5E7A3A", { color2 = "#A88A5A", parts = { "horns", "hood" } })
add("outfit_saint", "outfit", 900, "✧", "#F4EFE0", { color2 = "#FFD86A", parts = { "halo", "cape" } })
-- Auras
add("aura_gold", "aura", 500, "✺", "#FFD86A")
add("aura_frost", "aura", 500, "❄", "#9ED8FF")
add("aura_shadow", "aura", 650, "☾", "#7A3AB0")
add("aura_ember", "aura", 650, "♨", "#FF6A2A")
-- Trails
add("trail_spark", "trail", 250, "≈", "#FFE08A", { color2 = "#FF9F1C" })
add("trail_mist", "trail", 250, "≋", "#BFD8FF", { color2 = "#4A8FE7" })
-- Weapon effects
add("weapon_flame", "weapon", 400, "♨", "#FF7A2A")
add("weapon_frost", "weapon", 400, "❄", "#8FD8FF")
add("weapon_holy", "weapon", 500, "✧", "#FFF2B0")
-- Pets
add("pet_fox", "pet", 600, "🦊", "#D9752E", { color2 = "#F4EFE0", shape = "fox" })
add("pet_owl", "pet", 600, "🦉", "#8A6A4A", { color2 = "#E8D8B0", shape = "owl" })
add("pet_dragon", "pet", 1200, "🐉", "#3E8A4A", { color2 = "#E8C25A", shape = "dragon" })
add("pet_wisp", "pet", 900, "✦", "#9ED8FF", { color2 = "#FFFFFF", shape = "wisp" })
add("pet_cat", "pet", 500, "🐈", "#4A4A52", { color2 = "#E8E4DA", shape = "cat" })
add("pet_frog", "pet", 400, "🐸", "#5EA83A", { color2 = "#E8D85A", shape = "frog" })

local byId: { [string]: Def } = {}
for _, def in LIST do
	byId[def.id] = def
end

local KINDS: { Kind } = { "outfit", "aura", "trail", "weapon", "pet" }

return table.freeze({
	list = LIST,
	byId = byId,
	kinds = KINDS,
	get = function(id: string): Def?
		return byId[id]
	end,
})
