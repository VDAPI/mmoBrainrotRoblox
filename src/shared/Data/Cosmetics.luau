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
	-- Pets (S24): a "chibi" look for Logic/Anatomy (same format as Data/MonsterLooks; `color` stays for the
	-- wardrobe swatch) and whether the pet flies (hovers at shoulder height and flaps).
	look: any?,
	flies: boolean?,
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
add("pet_fox", "pet", 600, "🦊", "#D9752E", {
	color2 = "#F4EFE0",
	flies = false,
	look = {
		plan = "canine",
		build = { chibi = 1, snout = 0.9, ears = 1.3, tail = 2, mane = 0 },
		colors = { base = "#D9752E", accent = "#F4EFE0", detail = "#3A2A24" },
	},
})
add("pet_owl", "pet", 600, "🦉", "#8A6A4A", {
	color2 = "#E8D8B0",
	flies = true,
	look = {
		plan = "bird",
		build = { chibi = 1 },
		colors = { base = "#8A6A4A", accent = "#E8D8B0", detail = "#C9A45C", eye = "#FFD23A" },
	},
})
add("pet_dragon", "pet", 1200, "🐉", "#3E8A4A", {
	color2 = "#E8C25A",
	flies = true,
	look = {
		plan = "dragon",
		build = { chibi = 1 },
		colors = { base = "#3E8A4A", accent = "#E8C25A", detail = "#E8DCC8" },
		materials = { base = "SmoothPlastic", accent = "Fabric", detail = "SmoothPlastic" },
	},
})
add("pet_wisp", "pet", 900, "✦", "#9ED8FF", {
	color2 = "#FFFFFF",
	flies = true,
	look = {
		plan = "elemental",
		build = { chibi = 1 },
		colors = { base = "#9ED8FF", accent = "#E4F6FF", detail = "#5A9AC9" },
		materials = { base = "Glass", accent = "Glass", detail = "Glass" },
		glow = "#E4F6FF",
	},
})
add("pet_cat", "pet", 500, "🐈", "#4A4A52", {
	color2 = "#E8E4DA",
	flies = false,
	look = {
		plan = "canine",
		build = { chibi = 1, snout = 0.45, ears = 1.0, tail = 1, thinTail = 1, mane = 0 },
		colors = { base = "#4A4A52", accent = "#E8E4DA", detail = "#2A2A30" },
		parts = { "whiskers" },
	},
})
add("pet_frog", "pet", 400, "🐸", "#5EA83A", {
	color2 = "#E8D85A",
	flies = false,
	look = {
		plan = "toad",
		build = { chibi = 1 },
		colors = { base = "#5EA83A", accent = "#E8D85A", detail = "#3A6A24" },
		materials = { base = "SmoothPlastic" },
	},
})

local byId: { [string]: Def } = {}
for _, def in LIST do
	byId[def.id] = def
end

local KINDS: { Kind } = { "outfit", "aura", "trail", "weapon", "pet" }

return table.freeze({
	list = LIST,
	byId = byId,
	kinds = KINDS,
	PET_SCALE = 0.42, -- pet looks are built at this scale (S24)
	get = function(id: string): Def?
		return byId[id]
	end,
})
