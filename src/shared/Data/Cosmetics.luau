--!strict
-- Cosmetics and pets (DESIGN §22): looks only, never stats. Bought with Dragon Shards in the wardrobe and
-- owned by the account. Visuals are placeholders built from parts/particles (Util/CosmeticLook); real
-- models can replace them later without touching this table's shape.
--   outfit  : body colours + accessory parts ("hood", "crown", "cape", "pauldrons", "horns", "halo", "mask")
--   aura    : particles around the character
--   trail   : a trail behind the character while moving
--   weapon  : particles on the weapon in hand
--   pet     : a small creature that follows its owner
--   mountskin: the look of every owned mount (account-wide, one slot; S97, DESIGN-15 §2)

export type Kind = "outfit" | "aura" | "trail" | "weapon" | "pet" | "mountskin"

-- S97: a mount skin over the mount's look (Logic/Mounts.lookWith): colour roles (base, accent, detail, eye, cloth,
-- trim) and material roles (base, accent, detail) win over the mount's, parts are added, glow replaces its glow.
export type Skin = {
	colors: { [string]: string }?,
	materials: { [string]: string }?,
	parts: { string }?,
	glow: string?,
}

-- S97: earned in the game, never sold (price 0, Logic/Premium.canBuyCosmetic): exactly one of the fields.
export type Obtain = { boss: string?, quest: string? }

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
	skin: Skin?, -- S97: mountskin
	obtain: Obtain?, -- S97: a boss drop (Data/Mounts.BOSS_DROPS) or a quest reward (Reward.cosmetic), not for sale
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

-- Mount skins (S97): the look of every mount the character owns (Logic/Mounts.lookWith). Sold ones like mid-range
-- cosmetics; Morvane's and Azgor's from their bosses (Data/Mounts.BOSS_DROPS), two from quests (Reward.cosmetic).
add("mountskin_dapple", "mountskin", 350, "🐎", "#B8B4AC", {
	color2 = "#5A3E24",
	skin = { colors = { base = "#B8B4AC", accent = "#E4E0D6", detail = "#5A3E24" } },
})
add("mountskin_raven", "mountskin", 500, "🐎", "#24222A", {
	color2 = "#C8CCD2",
	skin = {
		colors = { base = "#24222A", accent = "#1E1E24", detail = "#2E2A30", trim = "#C8CCD2" },
		materials = { accent = "SmoothPlastic" },
	},
})
add("mountskin_ivory", "mountskin", 700, "🐎", "#E8E0CC", {
	color2 = "#6E1F2E",
	skin = {
		colors = { base = "#E8E0CC", accent = "#D8CCB0", cloth = "#6E1F2E", trim = "#D4AF37" },
		parts = { "caparison" },
	},
})
add("mountskin_herald", "mountskin", 900, "🐎", "#E8E4DA", {
	color2 = "#B0202A",
	skin = {
		colors = { base = "#E8E4DA", accent = "#D8D0C0", cloth = "#B0202A", trim = "#D4AF37" },
		parts = { "caparison", "plume" },
	},
})
add("mountskin_shade", "mountskin", 0, "☾", "#4A4850", {
	color2 = "#9FE0B8",
	obtain = { boss = "morvane" },
	skin = {
		colors = { base = "#4A4850", accent = "#9FE0B8", cloth = "#24222A", eye = "#B8F5D0" },
		materials = { accent = "Neon" },
		parts = { "caparisonTorn" },
	},
})
add("mountskin_cinder", "mountskin", 0, "♨", "#6A6460", {
	color2 = "#FF7A2A",
	obtain = { boss = "azgor" },
	skin = {
		colors = { base = "#6A6460", accent = "#2E2826", detail = "#2A2422", trim = "#3E3634" },
		parts = { "emberCracks" },
		glow = "#FF7A2A",
	},
})
add("mountskin_meadow", "mountskin", 0, "❦", "#8A4A26", {
	color2 = "#4E7A34",
	obtain = { quest = "side_stable_ride" },
	skin = {
		colors = { base = "#8A4A26", accent = "#5A2E18", cloth = "#4E7A34" },
		parts = { "caparison", "wreath" },
	},
})
add("mountskin_dragonslayer", "mountskin", 0, "🐉", "#8E949C", {
	color2 = "#9FD8F5",
	obtain = { quest = "vaelgrath" },
	skin = {
		colors = { base = "#5A5E66", accent = "#2E3138", trim = "#A8AEB6", cloth = "#9FD8F5" },
		parts = { "peytral", "chamfron" },
	},
})

local byId: { [string]: Def } = {}
for _, def in LIST do
	byId[def.id] = def
end

local KINDS: { Kind } = { "outfit", "aura", "trail", "weapon", "pet", "mountskin" }

return table.freeze({
	list = LIST,
	byId = byId,
	kinds = KINDS,
	PET_SCALE = 0.42, -- pet looks are built at this scale (S24)
	get = function(id: string): Def?
		return byId[id]
	end,
})
