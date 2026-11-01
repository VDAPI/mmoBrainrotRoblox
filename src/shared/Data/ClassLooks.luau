--!strict
-- Class looks (DESIGN-17 §9a, S132): the default outfit of every class, the creator choices (faces, skin tones,
-- hairstyles) and the hooks for real items. Every element may name a Roblox catalog asset id (put on through
-- HumanoidDescription, never bought) or an owner's model in assets/ClassLooks; with id 0 and no model the game draws
-- the procedural look from parts (Util/AvatarBuild). Looks only: nothing here changes a number of the game.
-- Procedural garment names live in Logic/CharacterLook.GARMENTS (tests/classlooks.spec checks every name used here).
-- Owner's list of empty catalog ids: docs/WYGLAD-KLAS.md (tools/classlooks_slots.luau prints it).

-- Catalog clothing 2026-11-01 (docs/WYGLAD-KLAS.md §3): a catalog item says its accessory type, a layered one its
-- layering order, and may cover more procedural garments than its own.
-- One more catalog item worn with a garment's own (the other half of a pair: the right pauldron, the right shoe).
export type CatalogRef = { catalog: number, type: string?, order: number? }
export type Garment = {
	g: string, -- procedural garment name (Logic/CharacterLook.GARMENTS)
	catalog: number?, -- Roblox catalog item worn instead of the procedural garment; 0 / nil = procedural
	-- the item's Enum.AccessoryType name (CATALOG_TYPES); nil = "Hat", a rigid accessory on its own attachment
	type: string?,
	order: number?, -- layered types only: the layering order (higher = over); nil = Roblox's default of the type
	-- procedural garments of the same outfit (`g` names) the item covers too: none of them is worn while it is
	hides: { string }?,
	also: { CatalogRef }?, -- more catalog items worn with this one, only while `catalog` is set
	asset: string?, -- key of ClassLooks.assets (owner's model); replaces the procedural garment when the model exists
	role: string?, -- colour role of the garment (default: the garment's own default role in GARMENTS)
}
-- The accessory types a catalog item may say (Enum.AccessoryType names). Layered clothing (a WrapLayer) is fitted over
-- the body and over what is under it; `order` = Roblox's default layering order of the type (the LayeredClothingOrder
-- of its avatar editor and in-experience try-on): shoes 3, pants 4, shorts 5, dress / skirt 6, T-shirt 7, shirt 8,
-- sweater 9, jacket 10. A rigid accessory sits on the attachment of its handle; `field` = its HumanoidDescription
-- property. Layered "Shirt" / "Pants" are 3D items, not the classic Shirt / Pants of an outfit (`shirt`, `pants`).
export type CatalogType = { layered: boolean, order: number?, field: string? }
export type Colors = { main: string, second: string, trim: string?, leather: string?, metal: string? }
export type OutfitSpec = {
	colors: Colors,
	body: { [string]: string }?, -- R15 part name -> colour role ("main", "second", "trim", "leather", "metal", "skin"); default BODY_ROLES
	garments: { Garment },
	shirt: number?, -- Roblox classic Shirt id (0 = the procedural body colours show)
	pants: number?, -- Roblox classic Pants id
}
export type Layers = {
	chest: OutfitSpec?,
	head: OutfitSpec?,
	legs: OutfitSpec?,
	hands: OutfitSpec?,
	feet: OutfitSpec?,
	back: OutfitSpec?,
}
export type ClassLook = {
	class: string,
	nameKey: string, -- "classlook.<Class>.name" (the default outfit's name in the wardrobe)
	outfit: OutfitSpec,
	-- Later (not in DESIGN-17): armour from the equipment changes the look by slot, as in Margonem. Nothing reads it
	-- yet (DECYZJE S132); the slots match Logic/CharacterLook.SLOTS.
	layers: Layers,
}
-- W10: a face is a dynamic head of Data/BodyLooks (its own eyes, nose and mouth, its lashes); `beard` / `paint` = what the
-- face of the same id meant before W10 (a save without those fields gets them)
export type Face = { id: string, catalog: number?, legacyBeard: string?, legacyPaint: string? }
export type Skin = { id: string, color: string }
-- W10: a hairstyle (the colour is its own choice, HAIR_COLORS); `style` = the procedural hairstyle drawn when the Roblox
-- one (Data/BodyLooks.hairs) is missing
export type Hair = { id: string, catalog: number?, asset: string?, style: string }
export type Choice = { id: string, color: string? }
-- An owner's model: ReplicatedStorage.Assets.ClassLooks.<model>. An Accessory is put on with Humanoid:AddAccessory
-- (server), a Model / MeshPart is welded to the part `attach` (default UpperTorso), moved by `offset` studs and scaled.
export type Asset = { model: string, attach: string?, offset: { number }?, scale: number? }
-- W10: hairColor, brows, beard, build, paint, paintColor are missing in a save from before W10 (CharacterLook.normalize
-- fills them, from the old face and hair ids where those meant them)
export type Look = {
	face: string,
	skin: string,
	hair: string,
	hairColor: string?,
	brows: string?,
	beard: string?,
	build: string?,
	paint: string?,
	paintColor: string?,
}

local CATALOG_TYPES: { [string]: CatalogType } = {
	LeftShoe = { layered = true, order = 3 },
	RightShoe = { layered = true, order = 3 },
	Pants = { layered = true, order = 4 },
	Shorts = { layered = true, order = 5 },
	DressSkirt = { layered = true, order = 6 },
	TShirt = { layered = true, order = 7 },
	Shirt = { layered = true, order = 8 },
	Sweater = { layered = true, order = 9 },
	Jacket = { layered = true, order = 10 },
	Hat = { layered = false, field = "HatAccessory" },
	Hair = { layered = false, field = "HairAccessory" },
	Face = { layered = false, field = "FaceAccessory" },
	Neck = { layered = false, field = "NeckAccessory" },
	Shoulder = { layered = false, field = "ShouldersAccessory" },
	Front = { layered = false, field = "FrontAccessory" },
	Back = { layered = false, field = "BackAccessory" },
	Waist = { layered = false, field = "WaistAccessory" },
}
for _, def in CATALOG_TYPES do
	table.freeze(def)
end

-- `item`: the catalog fields of the garment (catalog, type, order, hides, also), e.g.
--   garment("breastplate", "metal", { catalog = 123, type = "Jacket", hides = { "belt", "plate_pauldrons" } })
local function garment(g: string, role: string?, item: { [string]: any }?): Garment
	local out: any = { g = g, catalog = 0, role = role }
	for k, v in (item or {}) :: { [string]: any } do
		out[k] = v
	end
	return out :: Garment
end

-- `outfit.shirt` / `outfit.pants` = the class's classic Shirt / Pants ids (0 = none).
local function look(class: string, outfit: OutfitSpec): ClassLook
	return {
		class = class,
		nameKey = `classlook.{class}.name`,
		outfit = outfit,
		layers = {},
	}
end

-- Default colour role of every R15 part (an outfit's `body` overrides single parts).
local BODY_ROLES: { [string]: string } = {
	Head = "skin",
	UpperTorso = "main",
	LowerTorso = "second",
	LeftUpperArm = "main",
	RightUpperArm = "main",
	LeftLowerArm = "second",
	RightLowerArm = "second",
	LeftHand = "skin",
	RightHand = "skin",
	LeftUpperLeg = "second",
	RightUpperLeg = "second",
	LeftLowerLeg = "leather",
	RightLowerLeg = "leather",
	LeftFoot = "leather",
	RightFoot = "leather",
}

-- A long robe: the legs in the robe's colour down to the boots.
local ROBE_BODY: { [string]: string } = {
	LowerTorso = "main",
	LeftUpperLeg = "main",
	RightUpperLeg = "main",
	LeftLowerLeg = "main",
	RightLowerLeg = "main",
}

local classes: { [string]: ClassLook } = {
	-- Plate and a cape: broad in the shoulders, the class red as the cape.
	Warrior = look("Warrior", {
		colors = {
			main = "#5B616B",
			second = "#3A3F47",
			trim = "#A33A2A",
			leather = "#6B4A2B",
			metal = "#9AA3AD",
		},
		garments = {
			garment("breastplate", "metal"),
			garment("plate_pauldrons", "metal", {
				catalog = 5830109763,
				type = "Shoulder",
				also = { { catalog = 5830106859, type = "Shoulder" } },
			}),
			garment("gauntlets", "metal"),
			garment("greaves", "metal"),
			garment("belt", "leather"),
			garment("cape", "trim", {
				catalog = 9764302228,
				type = "Back",
				hides = { "breastplate", "gauntlets", "greaves", "belt" },
			}),
		},
		-- owner 2026-11-01: fancy catalog sets on the block body, the procedural pieces stay for the previews
		shirt = 6962895458,
		pants = 6962898847,
	}),
	-- A long white robe with a hood, the holy symbol and a stole.
	Cleric = look("Cleric", {
		colors = {
			main = "#E8E2D0",
			second = "#C9A45C",
			trim = "#E8C25A",
			leather = "#7A5A3A",
			metal = "#C9A45C",
		},
		body = ROBE_BODY,
		garments = {
			garment("robe_skirt", "main"),
			garment("hood", "main"),
			garment("holy_symbol", "second"),
			garment("sash", "trim"),
			garment("stole", "second", {
				catalog = 5830109763,
				type = "Shoulder",
				also = { { catalog = 5830106859, type = "Shoulder" } },
				hides = { "robe_skirt", "hood", "holy_symbol", "sash" },
			}),
		},
		shirt = 88459025813113,
		pants = 16104137810,
	}),
	-- Leathers, a hood and the quiver on the back. Owner 2026-10-21: green trousers under the brown vest (all brown read
	-- as bare skin).
	Hunter = look("Hunter", {
		colors = {
			main = "#4A5A34",
			second = "#3E4A2C",
			trim = "#4FA35A",
			leather = "#7A5232",
			metal = "#8A8070",
		},
		garments = {
			garment("leather_vest", "leather"),
			garment("hood", "main", {
				catalog = 16292136577,
				type = "Hat",
				hides = { "leather_vest", "bracers", "belt", "boots" },
			}),
			garment("quiver_back", "leather"),
			garment("bracers", "leather"),
			garment("belt", "leather"),
			garment("boots", "leather"),
		},
		shirt = 6856612123,
		pants = 6856612978,
	}),
	-- A robe to the ground, a high collar and a book at the belt.
	-- owner 2026-10-21: violet sleeves and mantle (the pale second colour read as bare arms)
	Mage = look("Mage", {
		colors = {
			main = "#5A1E1E", -- (owner 2026-11-01: with the red robes, it shows on the sleeve)
			second = "#5B4E8C",
			trim = "#4A8FE7",
			leather = "#4A3A2A",
			metal = "#B8A060",
		},
		body = ROBE_BODY,
		garments = {
			garment("robe_skirt", "main"),
			garment("high_collar", "main"),
			garment("belt_book", "leather"),
			garment("sash", "trim"),
			garment("shoulder_mantle", "second", {
				catalog = 9764302228,
				type = "Back",
				hides = { "robe_skirt", "high_collar", "belt_book", "sash" },
			}),
		},
		shirt = 92407930233991,
		pants = 84545186380755,
	}),
}

local function face(id: string, legacyBeard: string?, legacyPaint: string?): Face
	return { id = id, catalog = 0, legacyBeard = legacyBeard, legacyPaint = legacyPaint }
end

-- W10: eight faces = eight dynamic heads (Data/BodyLooks.heads); the ids are those of the S132 faces, so a saved face
-- stays a face (the beard and the freckles of two old faces became their own choices).
local FACES: { Face } = {
	face("face_calm"),
	face("face_stern"),
	face("face_young"),
	face("face_weary"),
	face("face_scarred"),
	face("face_bearded", "beard_full"),
	face("face_freckled", nil, "paint_freckles"),
	face("face_sharp"),
}

-- Light to dark, then two fantasy tones (W10: ashen, olive grey).
local SKINS: { Skin } = {
	{ id = "skin_1", color = "#F6DCC6" },
	{ id = "skin_2", color = "#EFCDAF" },
	{ id = "skin_3", color = "#E3B992" },
	{ id = "skin_4", color = "#D6A57C" },
	{ id = "skin_5", color = "#C68C63" },
	{ id = "skin_6", color = "#A9714B" },
	{ id = "skin_7", color = "#8C5A3B" },
	{ id = "skin_8", color = "#6E442C" },
	{ id = "skin_9", color = "#553323" },
	{ id = "skin_10", color = "#3E2519" },
	{ id = "skin_ash", color = "#A9A7A2" },
	{ id = "skin_olive", color = "#8E9478" },
}

local function hair(id: string, style: string): Hair
	return { id = id, catalog = 0, style = style }
end

-- W10: the hairstyles; the Roblox hair of each in Data/BodyLooks.hairs. Hair fixes 2026-10-31: twelve, short cuts
-- first, then long and tied ones, the bare head last (the creator's order).
local HAIRS: { Hair } = {
	hair("hair_short", "swept"),
	hair("hair_fringe", "short"),
	hair("hair_charmer", "short"),
	hair("hair_slicked", "short"),
	hair("hair_bob", "long"),
	hair("hair_long", "long"),
	hair("hair_straight", "long"),
	hair("hair_ponytail", "ponytail"),
	hair("hair_sidetail", "ponytail"),
	hair("hair_braid", "braid"),
	hair("hair_bun", "topknot"),
	hair("hair_shaved", "shaved"),
}

-- W10: the hair colour (hair, brows, beard).
local HAIR_COLORS: { Choice } = {
	{ id = "hc_black", color = "#141210" },
	{ id = "hc_dark", color = "#2E2620" },
	{ id = "hc_brown", color = "#4A3020" },
	{ id = "hc_chestnut", color = "#5A3A24" },
	{ id = "hc_auburn", color = "#6E2E18" },
	{ id = "hc_red", color = "#8A3A1E" },
	{ id = "hc_copper", color = "#A55A2A" },
	{ id = "hc_darkblond", color = "#8C6A3A" },
	{ id = "hc_blond", color = "#C9A86A" },
	{ id = "hc_paleblond", color = "#D8BC7A" },
	{ id = "hc_grey", color = "#9A9690" },
	{ id = "hc_white", color = "#E8E4DA" },
}

-- W10: brows (the brows of six dynamic heads, Data/BodyLooks.brows), in the hair colour.
local BROWS: { Choice } = {
	{ id = "brows_1" },
	{ id = "brows_2" },
	{ id = "brows_3" },
	{ id = "brows_4" },
	{ id = "brows_5" },
	{ id = "brows_6" },
}

-- W10: facial hair, drawn from parts in the hair colour (Util/AvatarBuild BEARDS).
local BEARDS: { Choice } = {
	{ id = "beard_none" },
	{ id = "beard_moustache" },
	{ id = "beard_goatee" },
	{ id = "beard_short" },
	{ id = "beard_full" },
	{ id = "beard_long" },
}

-- W10: build: width and depth of the body (the height and the hitbox stay; Data/BodyLooks.builds, at most 5%).
local BUILDS: { Choice } = {
	{ id = "build_slim" },
	{ id = "build_medium" },
	{ id = "build_strong" },
}

-- W10: face paint (Data/BodyLooks.paints: a decal on the face), no blood or wounds.
local PAINTS: { Choice } = {
	{ id = "paint_none" },
	{ id = "paint_freckles" },
	{ id = "paint_stripes" },
	{ id = "paint_rune" },
	{ id = "paint_tribal" },
	{ id = "paint_ash" },
}

local PAINT_COLORS: { Choice } = {
	{ id = "pc_ochre", color = "#C08A3A" },
	{ id = "pc_white", color = "#E6E0D2" },
	{ id = "pc_woad", color = "#3A5E9A" },
	{ id = "pc_soot", color = "#1E1C1A" },
	{ id = "pc_rust", color = "#8A4A2A" },
	{ id = "pc_moss", color = "#4E6A34" },
}

-- Old hair ids -> hairstyle and hair colour. S132 ids (style and colour in one) give both; hair fixes 2026-10-31: a
-- removed or renamed W10 id gives the nearest hairstyle and keeps the save's own colour (no second entry), and an S132
-- id whose colour the new hairstyle no longer offers (Logic/CharacterLook.hairColors) points at a near one that has it.
local LEGACY_HAIRS: { [string]: { string } } = {
	hair_short_dark = { "hair_short", "hc_dark" },
	hair_short_light = { "hair_short", "hc_blond" },
	hair_long_dark = { "hair_long", "hc_black" },
	hair_long_red = { "hair_long", "hc_red" },
	hair_ponytail_brown = { "hair_ponytail", "hc_chestnut" },
	hair_ponytail_blond = { "hair_ponytail", "hc_paleblond" },
	hair_braid_dark = { "hair_braid", "hc_dark" },
	hair_braid_grey = { "hair_ponytail", "hc_grey" },
	hair_topknot_black = { "hair_bun", "hc_black" },
	hair_curly_brown = { "hair_fringe", "hc_brown" },
	hair_swept_white = { "hair_short", "hc_white" },
	hair_curly = { "hair_fringe" }, -- Short Curls (a curly cap) -> the short fringe
	hair_bangs = { "hair_bob" }, -- Straight Bangs (an anime bob) -> the shoulder-length cut, renamed
	hair_swept = { "hair_short" }, -- Side Part - Black: the same mesh as hair_short, whose light texture goes black too
}

local function index(list: { any }): { [string]: any }
	local out = {}
	for _, entry in list do
		out[entry.id] = entry
	end
	return out
end

local faceById: { [string]: Face } = {}
for _, f in FACES do
	faceById[f.id] = f
end
local skinById: { [string]: Skin } = {}
for _, s in SKINS do
	skinById[s.id] = s
end
local hairById: { [string]: Hair } = {}
for _, h in HAIRS do
	hairById[h.id] = h
end

-- Owner's models (docs/WYGLAD-KLAS.md): none yet. Example:
--   warrior_cape = { model = "warrior_cape", attach = "UpperTorso" },
local assets: { [string]: Asset } = {}

local DEFAULT_LOOK: Look = table.freeze({
	face = "face_calm",
	skin = "skin_4",
	hair = "hair_short",
	hairColor = "hc_dark",
	brows = "brows_1",
	beard = "beard_none",
	build = "build_medium",
	paint = "paint_none",
	paintColor = "pc_ochre",
})

return table.freeze({
	classes = classes,
	FACES = FACES,
	SKINS = SKINS,
	HAIRS = HAIRS,
	faceById = faceById,
	skinById = skinById,
	hairById = hairById,
	HAIR_COLORS = HAIR_COLORS,
	BROWS = BROWS,
	BEARDS = BEARDS,
	BUILDS = BUILDS,
	PAINTS = PAINTS,
	PAINT_COLORS = PAINT_COLORS,
	hairColorById = index(HAIR_COLORS),
	browsById = index(BROWS),
	beardById = index(BEARDS),
	buildById = index(BUILDS),
	paintById = index(PAINTS),
	paintColorById = index(PAINT_COLORS),
	LEGACY_HAIRS = LEGACY_HAIRS,
	DEFAULT_LOOK = DEFAULT_LOOK,
	BODY_ROLES = BODY_ROLES,
	CATALOG_TYPES = table.freeze(CATALOG_TYPES),
	DEFAULT_CATALOG_TYPE = "Hat", -- a bare `catalog = id`: a rigid accessory (before 2026-11-01 every item was one)
	assets = assets,
	get = function(classId: string): ClassLook?
		return classes[classId]
	end,
})
