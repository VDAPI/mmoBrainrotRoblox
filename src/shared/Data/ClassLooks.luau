--!strict
-- Class looks (DESIGN-17 §9a, S132): the default outfit of every class, the creator choices (faces, skin tones,
-- hairstyles) and the hooks for real items. Every element may name a Roblox catalog asset id (put on through
-- HumanoidDescription, never bought) or an owner's model in assets/ClassLooks; with id 0 and no model the game draws
-- the procedural look from parts (Util/AvatarBuild). Looks only: nothing here changes a number of the game.
-- Procedural garment names live in Logic/CharacterLook.GARMENTS (tests/classlooks.spec checks every name used here).
-- Owner's list of empty catalog ids: docs/WYGLAD-KLAS.md (tools/classlooks_slots.luau prints it).

export type Garment = {
	g: string, -- procedural garment name (Logic/CharacterLook.GARMENTS)
	catalog: number?, -- Roblox catalog accessory id; 0 / nil = procedural
	asset: string?, -- key of ClassLooks.assets (owner's model); replaces the procedural garment when the model exists
	role: string?, -- colour role of the garment (default: the garment's own default role in GARMENTS)
}
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
export type Face = { id: string, catalog: number?, eyes: string, brows: string, mouth: string, mark: string? }
export type Skin = { id: string, color: string }
export type Hair = { id: string, catalog: number?, asset: string?, style: string, color: string }
-- An owner's model: ReplicatedStorage.Assets.ClassLooks.<model>. An Accessory is put on with Humanoid:AddAccessory
-- (server), a Model / MeshPart is welded to the part `attach` (default UpperTorso), moved by `offset` studs and scaled.
export type Asset = { model: string, attach: string?, offset: { number }?, scale: number? }
export type Look = { face: string, skin: string, hair: string }

local function garment(g: string, role: string?): Garment
	return { g = g, catalog = 0, role = role }
end

local function look(class: string, colors: Colors, garments: { Garment }, body: { [string]: string }?): ClassLook
	return {
		class = class,
		nameKey = `classlook.{class}.name`,
		outfit = { colors = colors, body = body, garments = garments, shirt = 0, pants = 0 },
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
		main = "#5B616B",
		second = "#3A3F47",
		trim = "#A33A2A",
		leather = "#6B4A2B",
		metal = "#9AA3AD",
	}, {
		garment("breastplate", "metal"),
		garment("plate_pauldrons", "metal"),
		garment("gauntlets", "metal"),
		garment("greaves", "metal"),
		garment("belt", "leather"),
		garment("cape", "trim"),
	}),
	-- A long white robe with a hood, the holy symbol and a stole.
	Cleric = look("Cleric", {
		main = "#E8E2D0",
		second = "#C9A45C",
		trim = "#E8C25A",
		leather = "#7A5A3A",
		metal = "#C9A45C",
	}, {
		garment("robe_skirt", "main"),
		garment("hood", "main"),
		garment("holy_symbol", "second"),
		garment("sash", "trim"),
		garment("stole", "second"),
	}, ROBE_BODY),
	-- Leathers, a hood and the quiver on the back.
	Hunter = look("Hunter", {
		main = "#4A5A34",
		second = "#6B4E2E",
		trim = "#4FA35A",
		leather = "#5A3E24",
		metal = "#8A8070",
	}, {
		garment("leather_vest", "leather"),
		garment("hood", "main"),
		garment("quiver_back", "leather"),
		garment("bracers", "leather"),
		garment("belt", "leather"),
		garment("boots", "leather"),
	}),
	-- A robe to the ground, a high collar and a book at the belt.
	Mage = look("Mage", {
		main = "#2E3A6B",
		second = "#C9B98A",
		trim = "#4A8FE7",
		leather = "#4A3A2A",
		metal = "#B8A060",
	}, {
		garment("robe_skirt", "main"),
		garment("high_collar", "main"),
		garment("belt_book", "leather"),
		garment("sash", "trim"),
		garment("shoulder_mantle", "second"),
	}, ROBE_BODY),
}

local function face(id: string, eyes: string, brows: string, mouth: string, mark: string?): Face
	return { id = id, catalog = 0, eyes = eyes, brows = brows, mouth = mouth, mark = mark }
end

local FACES: { Face } = {
	face("face_calm", "calm", "flat", "line"),
	face("face_stern", "narrow", "stern", "line"),
	face("face_young", "wide", "raised", "smile"),
	face("face_weary", "tired", "flat", "frown"),
	face("face_scarred", "narrow", "stern", "line", "scar"),
	face("face_bearded", "calm", "flat", "beard"),
	face("face_freckled", "wide", "flat", "smile", "freckles"),
	face("face_sharp", "narrow", "raised", "frown"),
}

-- Light to dark.
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
}

local function hair(id: string, style: string, color: string): Hair
	return { id = id, catalog = 0, style = style, color = color }
end

-- `style` names the procedural garment hair_<style> (Logic/CharacterLook.GARMENTS); "shaved" is a thin shadow over the
-- scalp in the hair colour.
local HAIRS: { Hair } = {
	hair("hair_short_dark", "short", "#2E2620"),
	hair("hair_short_light", "short", "#C9A86A"),
	hair("hair_long_dark", "long", "#1E1A18"),
	hair("hair_long_red", "long", "#8A3A1E"),
	hair("hair_ponytail_brown", "ponytail", "#5A3A24"),
	hair("hair_ponytail_blond", "ponytail", "#D8BC7A"),
	hair("hair_braid_dark", "braid", "#2A2420"),
	hair("hair_braid_grey", "braid", "#9A9690"),
	hair("hair_topknot_black", "topknot", "#141210"),
	hair("hair_curly_brown", "curly", "#4A3020"),
	hair("hair_swept_white", "swept", "#E8E4DA"),
	hair("hair_shaved", "shaved", "#3A302A"),
}

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

local DEFAULT_LOOK: Look = table.freeze({ face = "face_calm", skin = "skin_4", hair = "hair_short_dark" })

return table.freeze({
	classes = classes,
	FACES = FACES,
	SKINS = SKINS,
	HAIRS = HAIRS,
	faceById = faceById,
	skinById = skinById,
	hairById = hairById,
	DEFAULT_LOOK = DEFAULT_LOOK,
	BODY_ROLES = BODY_ROLES,
	assets = assets,
	get = function(classId: string): ClassLook?
		return classes[classId]
	end,
})
