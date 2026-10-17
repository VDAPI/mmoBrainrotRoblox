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
-- S123 (DESIGN-17 §4):
--   dye      : recolours the worn outfit (main and second colour); one slot, does nothing without an outfit
--   frame    : a frame around the portrait (HUD, character window, profile); account-wide, one slot
--   chatframe: brackets and colour around the name in chat and the speech bubble style; one slot
--   title    : a bought title; the title itself lives in Data/Titles with req { kind = "cosmetic", id }
--   emote    : a gesture played from the emote wheel or "/e <alias>"; every owned emote is available, no slot
--   levelup  : the effect shown to everyone when the character levels up; one slot
-- obtain.vipMonth (S121, DESIGN-17 §2): given for good to an account with VIP during that month (VipService); never
-- sold. obtain.pack (S123): only in a starter pack (Data/Products.starterPacks), never sold on its own.
-- weekly (S123): the cosmetic is in the pool of the offer of the week (Logic/WeeklyOffer); free (S123): every account
-- owns it without buying (Logic/CosmeticRules.owns, price 0).
-- S132 (DESIGN-17 §9a): class looks. An outfit replaces the clothing of the class (Data/ClassLooks); `class` = the class
-- that may wear it (nil = every class; only outfits), `outfit` = the full look (colour roles, body parts, procedural
-- garments of Logic/CharacterLook.GARMENTS, catalog ids; without it Logic/CharacterLook.outfitSpec builds one from
-- color / color2 / parts). obtain.bossWin = every character of the outfit's class among the winners of that boss gets
-- it; obtain.quest on a class outfit = the character of that class handing the quest in gets it.

local ClassLooks = require("./ClassLooks")

export type Kind =
	"outfit"
	| "aura"
	| "trail"
	| "weapon"
	| "pet"
	| "mountskin"
	| "dye"
	| "frame"
	| "chatframe"
	| "title"
	| "emote"
	| "levelup"

-- S97: a mount skin over the mount's look (Logic/Mounts.lookWith): colour roles (base, accent, detail, eye, cloth,
-- trim) and material roles (base, accent, detail) win over the mount's, parts are added, glow replaces its glow.
export type Skin = {
	colors: { [string]: string }?,
	materials: { [string]: string }?,
	parts: { string }?,
	glow: string?,
}

-- S97: earned in the game, never sold (price 0, Logic/Premium.canBuyCosmetic): exactly one of the fields.
-- S121: vipMonth = "YYYYMM" (UTC) of the VIP cosmetic of the month (Logic/Vip.monthCosmetic).
-- S123: pack = the key of the starter pack (Data/Products.starterPacks) that gives it.
-- S128: arena = "shop" (Arena Tokens shop, Data/Arena.SHOP) or "season" (a season reward, Data/Arena.SEASON_REWARDS).
-- S129: event = a reward of a wall-clock event (Data/ScheduledEvents key, "bloodmoon"; S130 "tourney"), never sold
-- S132: bossWin = a class outfit for every winner of that class over the boss (deterministic, no roll; CosmeticService)
-- S134k: hunt = "shop" (the Huntmaster's shop for Hunter's Marks, Data/HuntShop)
export type Obtain = {
	boss: string?,
	quest: string?,
	vipMonth: string?,
	pack: string?,
	arena: ("shop" | "season")?,
	event: string?,
	bossWin: string?,
	hunt: "shop"?, -- S134k: the Huntmaster's shop (Hunter's Marks, Data/HuntShop)
}

-- S123 looks of the new kinds (all colours hex).
-- frame: the stroke (a gradient from stroke to stroke2) `thickness` px at an 84 px portrait, an ornament glyph in the
-- four corners and a soft second stroke (glow).
export type Frame = { stroke: string, stroke2: string?, thickness: number, ornament: string?, glow: boolean? }
-- chatframe: the glyphs around the name in the chat window, their colour, the speech bubble's background and text.
export type ChatFrame = { left: string, right: string, color: string, bubble: string, bubbleText: string }
export type LevelUpStyle = "pillar" | "rings" | "runes" | "embers" | "frost"
export type LevelUp = { style: LevelUpStyle, color: string, color2: string? }
-- dye: the outfit's main colour and second colour (nil keeps the outfit's second colour).
export type Dye = { main: string, second: string? }

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
	wiki: boolean?, -- S105: false = left out of the wiki until published (tools/WikiData/Visibility)
	-- S123 (DESIGN-17 §4): one field per new kind
	frame: Frame?,
	chat: ChatFrame?,
	title: string?, -- id in Data/Titles
	emote: string?, -- id in Data/Emotes
	levelup: LevelUp?,
	dye: Dye?,
	weekly: boolean?, -- in the pool of the offer of the week (price > 0, no obtain, not free)
	free: boolean?, -- owned by every account (price 0)
	-- S132 (DESIGN-17 §9a): outfits only
	class: string?, -- the class that may wear it (nil = every class)
	outfit: ClassLooks.OutfitSpec?, -- the full look (nil: built from color / color2 / parts)
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
add("outfit_ranger", "outfit", 300, "♣", "#3E5B33", { weekly = true, color2 = "#6B4E2E", parts = { "hood", "cape" } })
add(
	"outfit_paladin",
	"outfit",
	450,
	"✚",
	"#D8D2C0",
	{ weekly = true, color2 = "#C9A45C", parts = { "pauldrons", "cape" } }
)
add("outfit_shadow", "outfit", 450, "☾", "#1E1E26", { weekly = true, color2 = "#5A2A7A", parts = { "hood", "mask" } })
add("outfit_royal", "outfit", 800, "♛", "#6B1F2A", { weekly = true, color2 = "#E8C25A", parts = { "crown", "cape" } })
add(
	"outfit_frost",
	"outfit",
	600,
	"❄",
	"#BFE3F2",
	{ weekly = true, color2 = "#4A8FE7", parts = { "pauldrons", "crown" } }
)
add("outfit_ember", "outfit", 600, "♨", "#7A2A12", { weekly = true, color2 = "#FF8A2A", parts = { "horns", "cape" } })
add("outfit_druid", "outfit", 350, "❦", "#5E7A3A", { weekly = true, color2 = "#A88A5A", parts = { "horns", "hood" } })
add("outfit_saint", "outfit", 900, "✧", "#F4EFE0", { weekly = true, color2 = "#FFD86A", parts = { "halo", "cape" } })
-- Auras
add("aura_gold", "aura", 500, "✺", "#FFD86A", { weekly = true })
add("aura_frost", "aura", 500, "❄", "#9ED8FF", { weekly = true })
add("aura_shadow", "aura", 650, "☾", "#7A3AB0", { weekly = true })
add("aura_ember", "aura", 650, "♨", "#FF6A2A", { weekly = true })
-- Trails
add("trail_spark", "trail", 250, "≈", "#FFE08A", { weekly = true, color2 = "#FF9F1C" })
add("trail_mist", "trail", 250, "≋", "#BFD8FF", { weekly = true, color2 = "#4A8FE7" })
-- Weapon effects
add("weapon_flame", "weapon", 400, "♨", "#FF7A2A", { weekly = true })
add("weapon_frost", "weapon", 400, "❄", "#8FD8FF", { weekly = true })
add("weapon_holy", "weapon", 500, "✧", "#FFF2B0", { weekly = true })
-- Pets
add("pet_fox", "pet", 600, "🦊", "#D9752E", {
	weekly = true,
	color2 = "#F4EFE0",
	flies = false,
	look = {
		plan = "canine",
		build = { chibi = 1, snout = 0.9, ears = 1.3, tail = 2, mane = 0 },
		colors = { base = "#D9752E", accent = "#F4EFE0", detail = "#3A2A24" },
	},
})
add("pet_owl", "pet", 600, "🦉", "#8A6A4A", {
	weekly = true,
	color2 = "#E8D8B0",
	flies = true,
	look = {
		plan = "bird",
		build = { chibi = 1 },
		colors = { base = "#8A6A4A", accent = "#E8D8B0", detail = "#C9A45C", eye = "#FFD23A" },
	},
})
add("pet_dragon", "pet", 1200, "🐉", "#3E8A4A", {
	weekly = true,
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
	weekly = true,
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
	weekly = true,
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
	weekly = true,
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
	weekly = true,
	color2 = "#5A3E24",
	skin = { colors = { base = "#B8B4AC", accent = "#E4E0D6", detail = "#5A3E24" } },
})
add("mountskin_raven", "mountskin", 500, "🐎", "#24222A", {
	weekly = true,
	color2 = "#C8CCD2",
	skin = {
		colors = { base = "#24222A", accent = "#1E1E24", detail = "#2E2A30", trim = "#C8CCD2" },
		materials = { accent = "SmoothPlastic" },
	},
})
add("mountskin_ivory", "mountskin", 700, "🐎", "#E8E0CC", {
	weekly = true,
	color2 = "#6E1F2E",
	skin = {
		colors = { base = "#E8E0CC", accent = "#D8CCB0", cloth = "#6E1F2E", trim = "#D4AF37" },
		parts = { "caparison" },
	},
})
add("mountskin_herald", "mountskin", 900, "🐎", "#E8E4DA", {
	weekly = true,
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
-- S105: the reward of the story's finale (firstSpring): pale green cloth with white flowers, a wreath of field flowers
-- by the bridle
add("mountskin_spring", "mountskin", 0, "❀", "#B8E07A", {
	color2 = "#F4F0E8",
	obtain = { quest = "firstSpring" },
	skin = {
		colors = { cloth = "#9CCB6A", trim = "#F4F0E8", accent = "#E8D8B0" },
		parts = { "caparison", "wreath" },
	},
})

-- S106: the reward of the Dusk Lanterns arc (side_lampLighter): ash-grey coat, a navy caparison with a silver lantern
-- trim, black tack and a cold bluish mane
add("mountskin_lantern", "mountskin", 0, "🏮", "#8A8884", {
	color2 = "#7FB8FF",
	obtain = { quest = "side_lampLighter" },
	skin = {
		colors = { base = "#8A8884", accent = "#9FB8D8", detail = "#1A1A1E", cloth = "#1E2A4A", trim = "#C8CCD4" },
		parts = { "caparison" },
	},
})

-- S121: VIP cosmetics of the month (DESIGN-17 §2): given for good to an account with VIP in that UTC month.
add("aura_vip_hearth", "aura", 0, "✺", "#FFB04A", { color2 = "#FFE3A0", obtain = { vipMonth = "202611" } })
add("trail_vip_snowfall", "trail", 0, "❄", "#EAF6FF", { color2 = "#9ED8FF", obtain = { vipMonth = "202612" } })
add("weapon_vip_starlight", "weapon", 0, "✧", "#CFE3FF", { obtain = { vipMonth = "202701" } })
add("aura_vip_bloodrose", "aura", 0, "❀", "#B3263A", { obtain = { vipMonth = "202702" } })
add("trail_vip_thaw", "trail", 0, "≋", "#8FD18B", { color2 = "#E8F6E0", obtain = { vipMonth = "202703" } })
add("outfit_vip_herald", "outfit", 0, "♛", "#1F2E5A", {
	color2 = "#E8C25A",
	parts = { "cape", "crown" },
	obtain = { vipMonth = "202704" },
})

-- S123 (DESIGN-17 §4): marks, gestures, effects and dyes. Prices in the ranges of KATALOG.md (frames 100-300, chat
-- frames 100-250, titles 100-250, emotes 50-150, level-up effects 250-600, dyes 30-60); S131 reviews them.
-- Portrait frames
add("frame_bronze", "frame", 100, "▢", "#9A6A3A", {
	weekly = true,
	color2 = "#C8955A",
	frame = { stroke = "#9A6A3A", stroke2 = "#C8955A", thickness = 3 },
})
add("frame_silver", "frame", 150, "✦", "#A8AEB6", {
	weekly = true,
	color2 = "#E8ECF0",
	frame = { stroke = "#A8AEB6", stroke2 = "#E8ECF0", thickness = 3, ornament = "✦" },
})
add("frame_runic", "frame", 200, "ᚱ", "#1E2A4A", {
	weekly = true,
	color2 = "#7FB8FF",
	frame = { stroke = "#1E2A4A", stroke2 = "#7FB8FF", thickness = 4, ornament = "ᚱ", glow = true },
})
add("frame_thorns", "frame", 250, "❦", "#1A1A1E", {
	weekly = true,
	color2 = "#2F4A2A",
	frame = { stroke = "#1A1A1E", stroke2 = "#3E6A34", thickness = 4, ornament = "❦" },
})
add("frame_royal", "frame", 300, "♛", "#E8C25A", {
	weekly = true,
	color2 = "#6B1F2A",
	frame = { stroke = "#E8C25A", stroke2 = "#6B1F2A", thickness = 5, ornament = "♛", glow = true },
})
-- Chat frames
add("chatframe_parchment", "chatframe", 100, "❲", "#E8DCC0", {
	weekly = true,
	color2 = "#3A2A1A",
	chat = { left = "❲", right = "❳", color = "#B08A5A", bubble = "#E8DCC0", bubbleText = "#3A2A1A" },
})
add("chatframe_ember", "chatframe", 150, "‹", "#2A140C", {
	weekly = true,
	color2 = "#FFB070",
	chat = { left = "‹", right = "›", color = "#FF8A3A", bubble = "#2A140C", bubbleText = "#FFB070" },
})
add("chatframe_frost", "chatframe", 150, "❅", "#13263A", {
	weekly = true,
	color2 = "#CFEAFF",
	chat = { left = "❅", right = "❅", color = "#8FD0FF", bubble = "#13263A", bubbleText = "#CFEAFF" },
})
add("chatframe_royal", "chatframe", 250, "⟨", "#2A1430", {
	weekly = true,
	color2 = "#F4D98A",
	chat = { left = "⟨", right = "⟩", color = "#E8C25A", bubble = "#2A1430", bubbleText = "#F4D98A" },
})
-- Bought titles (Data/Titles req { kind = "cosmetic", id })
add("title_pilgrim", "title", 100, "✎", "#CDBB94", { weekly = true, title = "pilgrim" })
add("title_lorekeeper", "title", 150, "✎", "#9FC3E8", { weekly = true, title = "lorekeeper" })
add("title_oathbound", "title", 200, "✎", "#D8C27A", { weekly = true, title = "oathbound" })
add("title_nightwatch", "title", 200, "✎", "#7F8FB8", { weekly = true, title = "nightwatch" })
add("title_highborn", "title", 250, "✎", "#E0B0D8", { weekly = true, title = "highborn" })
-- Emotes (Data/Emotes); the first two belong to every account
add("emote_wave", "emote", 0, "✋", "#CFC6B0", { free = true, emote = "wave" })
add("emote_point", "emote", 0, "☞", "#CFC6B0", { free = true, emote = "point" })
add("emote_bow", "emote", 50, "♙", "#C9A45C", { weekly = true, emote = "bow" })
add("emote_salute", "emote", 50, "⚔", "#A8AEB6", { weekly = true, emote = "salute" })
add("emote_kneel", "emote", 80, "♗", "#9FC3E8", { weekly = true, emote = "kneel" })
add("emote_cheer", "emote", 80, "✊", "#E8C25A", { weekly = true, emote = "cheer" })
add("emote_ponder", "emote", 100, "❔", "#B8A8D8", { weekly = true, emote = "ponder" })
add("emote_sit", "emote", 120, "⌂", "#8A7A6A", { weekly = true, emote = "sit" })
-- Level-up effects (EffectsController; nothing equipped = the gold pillar of S22)
add("levelup_radiance", "levelup", 250, "✺", "#FFF6DC", {
	weekly = true,
	color2 = "#F4D98A",
	levelup = { style = "pillar", color = "#FFF6DC", color2 = "#F4D98A" },
})
add("levelup_runes", "levelup", 350, "ᚱ", "#7FB8FF", {
	weekly = true,
	color2 = "#D8E0EA",
	levelup = { style = "runes", color = "#7FB8FF", color2 = "#D8E0EA" },
})
add("levelup_embers", "levelup", 400, "♨", "#FF7A2A", {
	weekly = true,
	color2 = "#FFD08A",
	levelup = { style = "embers", color = "#FF7A2A", color2 = "#FFD08A" },
})
add("levelup_frost", "levelup", 400, "❄", "#9ED8FF", {
	weekly = true,
	color2 = "#E4F6FF",
	levelup = { style = "frost", color = "#9ED8FF", color2 = "#E4F6FF" },
})
-- Dyes (the worn outfit's colours; kept for good, DECYZJE S123)
add("dye_crimson", "dye", 30, "◐", "#7A1E22", { color2 = "#C9A45C", dye = { main = "#7A1E22", second = "#C9A45C" } })
add("dye_azure", "dye", 30, "◐", "#1F4E8C", { color2 = "#D8D2C0", dye = { main = "#1F4E8C", second = "#D8D2C0" } })
add("dye_forest", "dye", 30, "◐", "#2F4A2A", { color2 = "#8A6A3A", dye = { main = "#2F4A2A", second = "#8A6A3A" } })
add("dye_onyx", "dye", 40, "◐", "#1A1A1E", { color2 = "#7A7A86", dye = { main = "#1A1A1E", second = "#7A7A86" } })
add("dye_ivory", "dye", 40, "◐", "#E8E0CC", { color2 = "#8A6A3A", dye = { main = "#E8E0CC", second = "#8A6A3A" } })
add("dye_gold", "dye", 60, "◐", "#B8902E", { color2 = "#3A2A1A", dye = { main = "#B8902E", second = "#3A2A1A" } })

-- S123: only in the starter packs (Data/Products.starterPacks), never sold alone. The wayfarer's cloak is an outfit
-- with a cape (there is no cape kind) and, like every outfit of this session, for every class (S132 adds `class`).
add("outfit_wayfarer", "outfit", 0, "✣", "#4A3E2E", {
	color2 = "#7A2E22",
	parts = { "hood", "cape" },
	obtain = { pack = "starter_wanderer" },
})
add("pet_hound", "pet", 0, "🐕", "#8A7A6A", {
	color2 = "#E8E0CC",
	flies = false,
	obtain = { pack = "starter_wanderer" },
	look = {
		plan = "canine",
		build = { chibi = 1, snout = 1.1, ears = 0.8, tail = 1.6, mane = 0 },
		colors = { base = "#8A7A6A", accent = "#E8E0CC", detail = "#3A2E24" },
	},
})
add("aura_valor", "aura", 0, "✠", "#E8C25A", { obtain = { pack = "starter_hero" } })

-- S128 (DESIGN-17 §6): the arena cosmetics, never sold for shards (price 0, obtain.arena): bought with Arena Tokens at
-- the Arena Master (Data/Arena.SHOP) or given as a season reward (Data/Arena.SEASON_REWARDS). On the wiki with the
-- arena article (S131).
add("frame_gladiator", "frame", 0, "⚔", "#8A5A2A", {
	color2 = "#D9B26A",
	obtain = { arena = "shop" },
	frame = { stroke = "#8A5A2A", stroke2 = "#D9B26A", thickness = 4, ornament = "⚔" },
})
add("chatframe_gladiator", "chatframe", 0, "⚔", "#3A2A18", {
	color2 = "#E8D2A0",
	obtain = { arena = "shop" },
	chat = { left = "⟦", right = "⟧", color = "#B07A3A", bubble = "#3A2A18", bubbleText = "#E8D2A0" },
})
add("title_ironwill", "title", 0, "✎", "#B8B2A6", { obtain = { arena = "shop" }, title = "ironwill" })
add("title_sandveteran", "title", 0, "✎", "#D9B26A", { obtain = { arena = "shop" }, title = "sandveteran" })
add("aura_gladiator", "aura", 0, "⚔", "#D9A441", { color2 = "#8A5A2A", obtain = { arena = "shop" } })
add("frame_arena_season", "frame", 0, "❦", "#C9D1D9", {
	color2 = "#8A9098",
	obtain = { arena = "season" },
	frame = { stroke = "#C9D1D9", stroke2 = "#8A9098", thickness = 5, ornament = "❦", glow = true },
})
add("aura_arena_season", "aura", 0, "❦", "#E8C25A", { color2 = "#FFF0B0", obtain = { arena = "season" } })

-- S129 (DESIGN-17 §7): the frame of the top 10 of a Blood Moon region, never sold (obtain.event); on the wiki with the
-- Blood Moon article (S131).
add("frame_bloodmoon", "frame", 0, "☾", "#8E1A22", {
	color2 = "#2A0A0E",
	obtain = { event = "bloodmoon" },
	frame = { stroke = "#8E1A22", stroke2 = "#D04A3A", thickness = 5, ornament = "☾", glow = true },
})

-- S130 (DESIGN-17 §8): the Champion's Tournament rewards, never sold (obtain.event = "tourney"): the champion's aura
-- (a bright golden crown of light, CosmeticLook.applyAura from the colours) and the finalist's frame (dark silver with
-- crossed swords). On the wiki with the tournament article (S131).
add("aura_champion", "aura", 0, "♛", "#F2C14E", { color2 = "#FFFFFF", obtain = { event = "tourney" } })
add("frame_tourney", "frame", 0, "⚔", "#6E7480", {
	color2 = "#C9CED6",
	obtain = { event = "tourney" },
	frame = { stroke = "#6E7480", stroke2 = "#C9CED6", thickness = 5, ornament = "⚔", glow = true },
})

-- S134k (DESIGN-15 §3.3): the hunting contracts' cosmetics, never sold for shards (price 0): the title and the frame of
-- the Huntmaster's shop (Hunter's Marks, Data/HuntShop; obtain.hunt) and the title of the 99th contract (its reward).
-- Procedural like the arena's (no pictures yet).
add("title_bountyhunter", "title", 0, "✎", "#A8743A", { obtain = { hunt = "shop" }, title = "bountyhunter" })
add("frame_trophy", "frame", 0, "➶", "#6B5A2E", {
	color2 = "#C9A45C",
	obtain = { hunt = "shop" },
	frame = { stroke = "#6B5A2E", stroke2 = "#C9A45C", thickness = 4, ornament = "➶" },
})
add("title_huntlord", "title", 0, "✎", "#7FA04A", { obtain = { quest = "contract_99" }, title = "huntlord" })

-- S132 (DESIGN-17 §9a): class outfits. Each replaces the default outfit of its class (Data/ClassLooks): per class
-- three for Dragon Shards, one for the end of the story's chapter II and one for defeating Azgor with that class. All
-- catalog ids 0 (procedural garments, docs/WYGLAD-KLAS.md). `color` / `color2` are the wardrobe and wiki swatch.
local QUEST_CHAPTER2_END = "queensLegacy" -- the last story quest of chapter II "Zapomniany Ród" (S103)
local ASHEN_BOSS = "azgor"

type Garment = ClassLooks.Garment

local function wear(g: string, role: string?): Garment
	return { g = g, catalog = 0, role = role }
end

-- A long robe: the legs in the robe's colour (as the default looks of the Cleric and the Mage).
local ROBE_BODY: { [string]: string } = {
	LowerTorso = "main",
	LeftUpperLeg = "main",
	RightUpperLeg = "main",
	LeftLowerLeg = "main",
	RightLowerLeg = "main",
}

local function classOutfit(
	id: string,
	class: string,
	price: number,
	icon: string,
	colors: ClassLooks.Colors,
	garments: { Garment },
	extra: { [string]: any }?
)
	local e: { [string]: any } = {
		class = class,
		color2 = colors.second,
		outfit = {
			colors = colors,
			body = if class == "Cleric" or class == "Mage" then ROBE_BODY else nil,
			garments = garments,
			shirt = 0,
			pants = 0,
		} :: ClassLooks.OutfitSpec,
	}
	if price > 0 then
		e.weekly = true
	end
	for k, v in (extra or {}) :: { [string]: any } do
		e[k] = v
	end
	add(id, "outfit", price, icon, colors.main, e)
end

-- Warrior
classOutfit("outfit_warrior_vanguard", "Warrior", 450, "⛨", {
	main = "#6A707A",
	second = "#2A3550",
	trim = "#C9A45C",
	leather = "#5A3E26",
	metal = "#B4BCC6",
}, {
	wear("breastplate", "metal"),
	wear("plate_pauldrons", "metal"),
	wear("gauntlets", "metal"),
	wear("greaves", "metal"),
	wear("belt", "leather"),
	wear("amulet", "trim"),
	wear("cape", "second"),
})
classOutfit("outfit_warrior_blackiron", "Warrior", 700, "⛨", {
	main = "#2A2A2E",
	second = "#4A4A50",
	trim = "#7A7A80",
	leather = "#3A2A1E",
	metal = "#3C3C42",
}, {
	wear("breastplate", "metal"),
	wear("plate_pauldrons", "metal"),
	wear("gauntlets", "metal"),
	wear("greaves", "metal"),
	wear("belt", "leather"),
	wear("cape", "trim"),
})
classOutfit("outfit_warrior_crimson", "Warrior", 900, "⛨", {
	main = "#7A1E22",
	second = "#5A1418",
	trim = "#B03028",
	leather = "#4A2E1E",
	metal = "#B8903E",
}, {
	wear("breastplate", "metal"),
	wear("plate_pauldrons", "metal"),
	wear("gauntlets", "metal"),
	wear("greaves", "metal"),
	wear("tabard", "trim"),
	wear("cape", "trim"),
	wear("helm_crest", "metal"),
})
classOutfit("outfit_warrior_duskwood", "Warrior", 0, "❦", {
	main = "#4A5A3A",
	second = "#5A4A30",
	trim = "#3E6A34",
	leather = "#5A3E24",
	metal = "#7A7E84",
}, {
	wear("chain_mail", "metal"),
	wear("tabard", "trim"),
	wear("fur_collar", "leather"),
	wear("belt", "leather"),
	wear("bracers", "leather"),
	wear("boots", "leather"),
}, { obtain = { quest = QUEST_CHAPTER2_END } })
classOutfit("outfit_warrior_ashen", "Warrior", 0, "♨", {
	main = "#3A3432",
	second = "#2A2422",
	trim = "#FF7A2A",
	leather = "#3A2A20",
	metal = "#4A4442",
}, {
	wear("breastplate", "metal"),
	wear("plate_pauldrons", "metal"),
	wear("gauntlets", "metal"),
	wear("greaves", "metal"),
	wear("glow_seams", "trim"),
	wear("cape", "second"),
}, { obtain = { bossWin = ASHEN_BOSS } })
-- Cleric
classOutfit("outfit_cleric_pilgrim", "Cleric", 400, "✝", {
	main = "#8A8680",
	second = "#6B4A2B",
	trim = "#A8916A",
	leather = "#5A4030",
	metal = "#6B4A2B",
}, {
	wear("robe_skirt", "main"),
	wear("hood", "main"),
	wear("sash", "trim"),
	wear("holy_symbol", "second"),
})
classOutfit("outfit_cleric_dawn", "Cleric", 700, "☀", {
	main = "#F4EFE0",
	second = "#D8B24A",
	trim = "#E8C25A",
	leather = "#8A6A3A",
	metal = "#D8B24A",
}, {
	wear("robe_skirt", "main"),
	wear("holy_symbol", "second"),
	wear("stole", "second"),
	wear("sash", "trim"),
	wear("shoulder_mantle", "trim"),
})
classOutfit("outfit_cleric_inquisitor", "Cleric", 900, "✝", {
	main = "#1E1C20",
	second = "#A8AEB6",
	trim = "#8E1A22",
	leather = "#2A2226",
	metal = "#A8AEB6",
}, {
	wear("robe_skirt", "main"),
	wear("hood", "main"),
	wear("holy_symbol", "second"),
	wear("stole", "trim"),
	wear("sash", "trim"),
})
classOutfit("outfit_cleric_duskwood", "Cleric", 0, "❦", {
	main = "#3E5A34",
	second = "#7A5A3A",
	trim = "#6B8A3A",
	leather = "#5A4030",
	metal = "#7A5A3A",
}, {
	wear("robe_skirt", "main"),
	wear("wreath", "trim"),
	wear("holy_symbol", "second"),
	wear("sash", "leather"),
}, { obtain = { quest = QUEST_CHAPTER2_END } })
classOutfit("outfit_cleric_ashen", "Cleric", 0, "♨", {
	main = "#5A5654",
	second = "#8A6A2E",
	trim = "#FF8A3A",
	leather = "#3A302A",
	metal = "#8A6A2E",
}, {
	wear("robe_skirt", "main"),
	wear("hood", "main"),
	wear("holy_symbol", "second"),
	wear("glow_seams", "trim"),
}, { obtain = { bossWin = ASHEN_BOSS } })
-- Hunter
classOutfit("outfit_hunter_tracker", "Hunter", 400, "➶", {
	main = "#3E5A2E",
	second = "#6B4A2B",
	trim = "#8A6A3A",
	leather = "#6B4A2B",
	metal = "#7A7468",
}, {
	wear("leather_vest", "leather"),
	wear("hood", "main"),
	wear("cape", "main"),
	wear("quiver_back", "leather"),
	wear("belt", "leather"),
	wear("boots", "leather"),
})
classOutfit("outfit_hunter_wolfpelt", "Hunter", 650, "➶", {
	main = "#6A6660",
	second = "#4A3A2A",
	trim = "#8A8278",
	leather = "#4A3424",
	metal = "#7A7468",
}, {
	wear("leather_vest", "leather"),
	wear("hood", "main"),
	wear("fur_mantle", "main"),
	wear("quiver_back", "leather"),
	wear("bracers", "leather"),
	wear("boots", "leather"),
})
classOutfit("outfit_hunter_nightstalker", "Hunter", 900, "➶", {
	main = "#1E1E22",
	second = "#2E2A2A",
	trim = "#5A5A66",
	leather = "#26222A",
	metal = "#4A4A52",
}, {
	wear("leather_vest", "leather"),
	wear("hood", "main"),
	wear("mask", "second"),
	wear("quiver_back", "leather"),
	wear("bracers", "leather"),
	wear("boots", "leather"),
})
classOutfit("outfit_hunter_duskwood", "Hunter", 0, "❦", {
	main = "#4A5A2E",
	second = "#6A5A3A",
	trim = "#7A9A3A",
	leather = "#4A3A24",
	metal = "#6A6458",
}, {
	wear("leather_vest", "leather"),
	wear("hood", "main"),
	wear("wreath", "trim"),
	wear("quiver_back", "leather"),
	wear("bracers", "leather"),
	wear("boots", "leather"),
}, { obtain = { quest = QUEST_CHAPTER2_END } })
classOutfit("outfit_hunter_ashen", "Hunter", 0, "♨", {
	main = "#8A3E22",
	second = "#4A2A1A",
	trim = "#FF8A2A",
	leather = "#5A2E1A",
	metal = "#6A5A50",
}, {
	wear("leather_vest", "main"),
	wear("hood", "second"),
	wear("quiver_back", "leather"),
	wear("ember_arrows", "trim"),
	wear("bracers", "leather"),
	wear("boots", "leather"),
}, { obtain = { bossWin = ASHEN_BOSS } })
-- Mage
classOutfit("outfit_mage_scholar", "Mage", 400, "✦", {
	main = "#6B4E2E",
	second = "#C9B98A",
	trim = "#8A6A3A",
	leather = "#4A3424",
	metal = "#B8A060",
}, {
	wear("robe_skirt", "main"),
	wear("belt_book", "leather"),
	wear("spectacles", "metal"),
	wear("sash", "trim"),
	wear("shoulder_mantle", "second"),
})
classOutfit("outfit_mage_ember", "Mage", 700, "♨", {
	main = "#5A1414",
	second = "#2A1010",
	trim = "#FF8A2A",
	leather = "#3A2018",
	metal = "#B8603A",
}, {
	wear("robe_skirt", "main"),
	wear("high_collar", "trim"),
	wear("glow_seams", "trim"),
	wear("sash", "trim"),
	wear("belt_book", "leather"),
})
classOutfit("outfit_mage_frostweave", "Mage", 900, "❄", {
	main = "#E4F0F6",
	second = "#7FB8E8",
	trim = "#BFE8FF",
	leather = "#5A6A7A",
	metal = "#A8C8E0",
}, {
	wear("robe_skirt", "main"),
	wear("high_collar", "main"),
	wear("frost_crystals", "trim"),
	wear("sash", "second"),
	wear("belt_book", "leather"),
})
classOutfit("outfit_mage_duskwood", "Mage", 0, "❦", {
	main = "#24361E",
	second = "#4A3A2A",
	trim = "#D8D0B8",
	leather = "#3A2A1E",
	metal = "#8A7A5A",
}, {
	wear("robe_skirt", "main"),
	wear("hood", "main"),
	wear("amulet", "trim"),
	wear("sash", "second"),
	wear("belt_book", "leather"),
}, { obtain = { quest = QUEST_CHAPTER2_END } })
classOutfit("outfit_mage_ashen", "Mage", 0, "♨", {
	main = "#141214",
	second = "#2A2628",
	trim = "#FF6A2A",
	leather = "#2A2020",
	metal = "#1A1A22",
}, {
	wear("robe_skirt", "main"),
	wear("high_collar", "metal"),
	wear("glow_seams", "trim"),
	wear("belt_book", "leather"),
	wear("shoulder_mantle", "second"),
}, { obtain = { bossWin = ASHEN_BOSS } })

local byId: { [string]: Def } = {}
for _, def in LIST do
	byId[def.id] = def
end

local KINDS: { Kind } = {
	"outfit",
	"aura",
	"trail",
	"weapon",
	"pet",
	"mountskin",
	"dye",
	"frame",
	"chatframe",
	"title",
	"emote",
	"levelup",
}

-- Wardrobe groups (S123): two-level tabs, every kind in exactly one group (tests/cosmetics2.spec).
export type Group = { id: string, kinds: { Kind } }
local GROUPS: { Group } = {
	{ id = "look", kinds = { "outfit", "dye", "aura", "trail", "weapon" } },
	{ id = "companions", kinds = { "pet", "mountskin" } },
	{ id = "marks", kinds = { "title", "frame", "chatframe" } },
	{ id = "gestures", kinds = { "emote", "levelup" } },
}

-- S123, DESIGN-17 §4: four cosmetics a week (Monday 00:00 UTC, Logic/Time.weekNumber), one at -30 %; the same on every
-- server (seeded Logic/Rng, no messaging). The discounted price is rounded to `round` shards (never below it); `salt`
-- moves the seed away from other weekly rolls.
local WEEKLY = table.freeze({ size = 4, discount = 0.3, round = 5, salt = 1723 })

return table.freeze({
	list = LIST,
	byId = byId,
	kinds = KINDS,
	groups = GROUPS,
	weekly = WEEKLY,
	PET_SCALE = 0.42, -- pet looks are built at this scale (S24)
	get = function(id: string): Def?
		return byId[id]
	end,
})
