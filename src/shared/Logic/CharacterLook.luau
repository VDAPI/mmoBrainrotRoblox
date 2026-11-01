--!strict
-- Class looks (DESIGN-17 §9a, S132), pure: the procedural garments, the creator choices and their validation, the
-- one place that turns a character (class, face / skin / hair, the class outfit of the account, the dye, the avatar
-- switch) into what Util/AvatarBuild draws (`resolve`), the class outfits of the account, the cost of a look change
-- and the scales of the Roblox avatar. Used by the server (CosmeticService, CharacterService through its description
-- provider), the windows (creator, wardrobe, look window) and AccountSchema (migration 9). Looks only: nothing here
-- changes a number of the game.

local BodyLooks = require("../Data/BodyLooks")
local ClassLooks = require("../Data/ClassLooks")
local Config = require("../Config")
local CosmeticRules = require("./CosmeticRules")
local Cosmetics = require("../Data/Cosmetics")
local HairTint = require("./HairTint")

type Def = Cosmetics.Def
type OutfitSpec = ClassLooks.OutfitSpec

local CharacterLook = {}

-- Slots of the body a garment sits on (the same names the armour layers will use later, Data/ClassLooks.layers).
CharacterLook.SLOTS =
	table.freeze({ "head", "face", "back", "chest", "shoulders", "arms", "hands", "waist", "legs", "feet" })

export type GarmentDef = { slot: string, pieces: number, role: string, hidesHair: boolean? }

local function g(slot: string, pieces: number, role: string, hidesHair: boolean?): GarmentDef
	return table.freeze({ slot = slot, pieces = pieces, role = role, hidesHair = hidesHair })
end

-- Every procedural garment: slot, parts drawn, default colour role, whether it covers the hair.
-- Util/AvatarBuild draws every name here; tests/classlooks.spec checks every look uses only these.
CharacterLook.GARMENTS = table.freeze({
	-- the outfits before S132 (Data/Cosmetics `parts`)
	hood = g("head", 2, "main", true), -- owner 2026-10-21: a round hood and its tail
	crown = g("head", 1, "second"),
	halo = g("head", 1, "second"),
	horns = g("head", 2, "second"),
	mask = g("face", 1, "second"),
	cape = g("back", 1, "second"),
	pauldrons = g("shoulders", 2, "second"),
	-- class looks and class outfits (S132)
	breastplate = g("chest", 2, "metal"),
	plate_pauldrons = g("shoulders", 2, "metal"),
	gauntlets = g("hands", 2, "metal"),
	greaves = g("legs", 2, "metal"),
	belt = g("waist", 1, "leather"),
	robe_skirt = g("legs", 8, "main"), -- owner 2026-10-21: a flared skirt of 8 panels
	holy_symbol = g("chest", 2, "second"),
	sash = g("waist", 1, "trim"),
	stole = g("chest", 2, "second"),
	leather_vest = g("chest", 1, "leather"),
	quiver_back = g("back", 2, "leather"),
	bracers = g("arms", 2, "leather"),
	boots = g("feet", 4, "leather"), -- owner 2026-10-21: shoes and shin cuffs
	high_collar = g("shoulders", 1, "main"),
	belt_book = g("waist", 2, "leather"),
	shoulder_mantle = g("shoulders", 1, "second"),
	helm_crest = g("head", 2, "metal", true),
	fur_mantle = g("shoulders", 1, "second"),
	fur_collar = g("shoulders", 1, "second"),
	spectacles = g("face", 2, "metal"),
	wreath = g("head", 1, "second"),
	frost_crystals = g("shoulders", 2, "trim"),
	glow_seams = g("chest", 2, "trim"),
	ember_arrows = g("back", 1, "trim"),
	amulet = g("chest", 1, "trim"),
	tabard = g("chest", 1, "trim"),
	chain_mail = g("chest", 1, "metal"),
	-- hairstyles (Data/ClassLooks.HAIRS style -> hair_<style>)
	hair_short = g("head", 1, "hair"),
	hair_long = g("head", 2, "hair"),
	hair_ponytail = g("head", 2, "hair"),
	hair_braid = g("head", 2, "hair"),
	hair_topknot = g("head", 2, "hair"),
	hair_curly = g("head", 2, "hair"),
	hair_swept = g("head", 2, "hair"),
	hair_shaved = g("head", 1, "hair"),
} :: { [string]: GarmentDef })

-- Parts of the S122 Cloak of Luring (CosmeticLook.applyLure: the cape and its hem), for the piece budget.
CharacterLook.LURE_PIECES = 2

-- Hands keep the avatar's colour in avatar mode only through an outfit (as before S132: the outfit's second colour).
local HANDS = { LeftHand = true, RightHand = true }

export type Look = ClassLooks.Look

-- W10: the fields of a look, each with the list of its choices (Data/ClassLooks).
CharacterLook.FIELDS = table.freeze({
	{ key = "face", list = ClassLooks.FACES },
	{ key = "skin", list = ClassLooks.SKINS },
	{ key = "hair", list = ClassLooks.HAIRS },
	{ key = "hairColor", list = ClassLooks.HAIR_COLORS },
	{ key = "brows", list = ClassLooks.BROWS },
	{ key = "beard", list = ClassLooks.BEARDS },
	{ key = "build", list = ClassLooks.BUILDS },
	{ key = "paint", list = ClassLooks.PAINTS },
	{ key = "paintColor", list = ClassLooks.PAINT_COLORS },
} :: { { key: string, list: { any } } })

local function known(field: { key: string, list: { any } }, value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	for _, entry in field.list do
		if entry.id == value then
			return true
		end
	end
	return false
end

-- Hair fixes 2026-10-31: the hair colours (Data/ClassLooks.HAIR_COLORS ids, in their order) each hairstyle offers. A
-- Roblox hair whose texture has its own colour (Data/BodyLooks.hairs `tone`: dark, red, pink) is only nudged toward
-- the colour, and a tint only darkens: it offers the colours its texture reaches (Logic/HairTint.REACH). Every other
-- hairstyle offers them all.
local hairColorIds: { [string]: { string } } = {}
for _, hair in ClassLooks.HAIRS do
	local def = BodyLooks.hairs[hair.id]
	local ids: { string } = {}
	for _, c in ClassLooks.HAIR_COLORS do
		if not (def and def.tone) or HairTint.reach(c.color :: string, def.tone) <= HairTint.REACH then
			table.insert(ids, c.id)
		end
	end
	hairColorIds[hair.id] = table.freeze(ids)
end

function CharacterLook.hairColors(hairId: string): { string }
	return hairColorIds[hairId] or hairColorIds[ClassLooks.DEFAULT_LOOK.hair]
end

-- The hair colour `colorId` when the hairstyle offers it, else the offered one that looks nearest (HairTint.distance).
function CharacterLook.fitHairColor(hairId: string, colorId: string): string
	local offered = CharacterLook.hairColors(hairId)
	if table.find(offered, colorId) then
		return colorId
	end
	local want = ClassLooks.hairColorById[colorId]
	if not want then
		return offered[1]
	end
	local best, bestDistance = offered[1], math.huge
	for _, id in offered do
		local distance = HairTint.distance(want.color, ClassLooks.hairColorById[id].color)
		if distance < bestDistance then
			best, bestDistance = id, distance
		end
	end
	return best
end

-- A valid look: every field an existing id of Data/ClassLooks, else the default one. Always a new table, every field
-- set. W10: a save from before W10 has an S132 hair id (style and colour, Data/ClassLooks.LEGACY_HAIRS) and no
-- beard / paint: the beard and the freckles of its face become those choices; nothing else changes. Hair fixes
-- 2026-10-31: a removed or renamed hairstyle becomes its nearest one (LEGACY_HAIRS), and a hair colour the
-- hairstyle does not offer the nearest offered one (brows and beard follow it).
function CharacterLook.normalize(look: any): Look
	local d = ClassLooks.DEFAULT_LOOK :: any
	local src: any = if type(look) == "table" then look else {}
	local out: any = {}
	for _, field in CharacterLook.FIELDS do
		out[field.key] = if known(field, src[field.key]) then src[field.key] else d[field.key]
	end
	local legacy = if type(src.hair) == "string" then ClassLooks.LEGACY_HAIRS[src.hair] else nil
	if legacy then
		out.hair = legacy[1]
		if src.hairColor == nil and legacy[2] then
			out.hairColor = legacy[2]
		end
	end
	out.hairColor = CharacterLook.fitHairColor(out.hair, out.hairColor)
	local face = ClassLooks.faceById[out.face]
	if face and src.beard == nil and face.legacyBeard then
		out.beard = face.legacyBeard
	end
	if face and src.paint == nil and face.legacyPaint then
		out.paint = face.legacyPaint
	end
	return out :: Look
end

-- Whether a look sent by a client is valid: a table whose every field (CharacterLook.FIELDS) names an existing entry,
-- the hair colour one its hairstyle offers.
function CharacterLook.isValid(look: any): (boolean, string?)
	if type(look) ~= "table" then
		return false, "look.error.bad"
	end
	for _, field in CharacterLook.FIELDS do
		if not known(field, look[field.key]) then
			return false, "look.error.bad"
		end
	end
	if not table.find(CharacterLook.hairColors(look.hair), look.hairColor) then
		return false, "look.error.bad"
	end
	return true, nil
end

-- Whether two looks are the same (every field, after normalize).
function CharacterLook.same(a: any, b: any): boolean
	local x, y = CharacterLook.normalize(a) :: any, CharacterLook.normalize(b) :: any
	for _, field in CharacterLook.FIELDS do
		if x[field.key] ~= y[field.key] then
			return false
		end
	end
	return true
end

-- W10: a random valid look (`roll()` in [0, 1), Logic/Rng in the game): a natural skin tone, a painted face one time
-- in three.
function CharacterLook.random(roll: () -> number): Look
	local out: any = {}
	for _, field in CharacterLook.FIELDS do
		local list = field.list
		local count = if field.key == "skin" then CharacterLook.NATURAL_SKINS else #list
		out[field.key] = list[math.clamp(math.floor(roll() * count) + 1, 1, count)].id
	end
	if roll() >= 1 / 3 then
		out.paint = "paint_none"
	end
	out.hairColor = CharacterLook.fitHairColor(out.hair, out.hairColor)
	return out :: Look
end

-- The first skins of Data/ClassLooks.SKINS are natural tones (the fantasy ones follow).
CharacterLook.NATURAL_SKINS = 10

-- Whether `def` is an outfit the class `classId` may wear (a shared one, or one of that class).
function CharacterLook.allowed(def: Def?, classId: string?): boolean
	return def ~= nil and def.kind == "outfit" and (def.class == nil or def.class == classId)
end

-- The parts each outfit before S132 coloured (Util/CosmeticLook BODY_MAIN / BODY_SECOND); hands are "skin" (in avatar
-- mode they still take the second colour, as before).
local LEGACY_BODY: { [string]: string } = {
	UpperTorso = "main",
	LowerTorso = "main",
	LeftUpperArm = "main",
	RightUpperArm = "main",
	LeftLowerArm = "second",
	RightLowerArm = "second",
	LeftHand = "skin",
	RightHand = "skin",
	LeftUpperLeg = "second",
	RightUpperLeg = "second",
	LeftLowerLeg = "second",
	RightLowerLeg = "second",
	LeftFoot = "second",
	RightFoot = "second",
}

-- The full outfit of a cosmetic: its `outfit`, or one built from the fields of the outfits before S132 (colour,
-- second colour, accessory parts).
function CharacterLook.outfitSpec(def: Def): OutfitSpec
	if def.outfit then
		return def.outfit
	end
	local garments: { ClassLooks.Garment } = {}
	for _, name in (def.parts or {}) :: { string } do
		table.insert(garments, { g = name })
	end
	return {
		colors = { main = def.color, second = def.color2 or def.color },
		body = LEGACY_BODY,
		garments = garments,
		shirt = 0,
		pants = 0,
	}
end

-- The class outfit the account wears on class `classId`: the saved one when it exists, is owned and allowed, else nil
-- (= the default outfit of the class).
function CharacterLook.outfitOf(account: any, classId: string?): string?
	if type(account) ~= "table" or type(classId) ~= "string" then
		return nil
	end
	local cosmetics = account.cosmetics
	local saved = if type(cosmetics) == "table" and type(cosmetics.classOutfits) == "table"
		then cosmetics.classOutfits[classId]
		else nil
	local def = if type(saved) == "string" then Cosmetics.get(saved) else nil
	if not def or not CharacterLook.allowed(def, classId) then
		return nil
	end
	if not CosmeticRules.ownsIn(def, if type(cosmetics.owned) == "table" then cosmetics.owned else nil) then
		return nil
	end
	return def.id
end

-- Catalog clothing 2026-11-01: a catalog item as a description wears it (Enum.AccessoryType name; `order` = the
-- layering order of a layered type, nil for a rigid one).
export type CatalogPiece = { id: number, type: string, layered: boolean, order: number? }
-- Dev try-on (/trylook, CosmeticService): catalog items over the look, procedural garments taken off, another body.
export type Trial = {
	pieces: { CatalogPiece }?, -- worn after the look's own items
	hide: { string }?, -- garments (`g` names) of the outfit not worn
	bare: boolean?, -- no garment of the outfit is worn (nor the plain shoes)
	hideHair: boolean?, -- no hairstyle
	body: { [string]: number }?, -- HumanoidDescription body part fields -> ids (a Head goes over the face's head)
}

export type LookInput = {
	classId: string,
	look: any,
	outfitId: string?,
	dye: any?,
	robloxAvatar: boolean,
	lure: boolean?,
	-- an outfit given directly (tests, tools) instead of `outfitId` / the class's default; used as it is
	spec: OutfitSpec?,
	trial: Trial?,
}
-- W10: the face of the look: the dynamic head and lashes (Data/BodyLooks.heads), the brows, the facial hair and the
-- face paint; `hair` = the hair colour (brows and beard take it)
export type FaceSpec = {
	id: string,
	head: number,
	lashes: number,
	brows: string,
	browsId: number,
	beard: string,
	paint: string,
	paintColor: string,
	hair: string,
}
export type HairSpec = { id: string, catalog: number, asset: string?, style: string, color: string }
-- `hidden`: not worn (covered by a catalog item of the outfit, `Garment.hides`, or taken off by a trial); previews still
-- draw it, as they draw the procedural garment of every catalog item.
export type GarmentSpec = { g: string, color: string, catalog: number, asset: string?, hidden: boolean? }
export type LookSpec = {
	mode: "class" | "avatar",
	skin: string?, -- hex; nil in avatar mode (the avatar keeps its own)
	-- `hair` = the hair colour (a beard takes it)
	face: FaceSpec?,
	hair: HairSpec?, -- nil = avatar mode or covered by a hood / helmet
	body: { [string]: string }, -- R15 part -> hex (empty in avatar mode without an outfit)
	garments: { GarmentSpec }, -- procedural or catalog / asset pieces, hats hide hair
	shirt: number,
	pants: number, -- catalog clothing (0 = none)
	-- catalog items of the description: the garments' (with their `also`), the hair's, a trial's, in that order
	accessories: { CatalogPiece },
	catalogKey: string, -- stable text of every catalog id: the server re-applies the description only when it changes
	pieces: number, -- procedural parts drawn (Config.CharacterLook.maxPieces)
	build: { width: number, depth: number }, -- W10: width and depth of the body (Data/BodyLooks.builds)
	shoes: boolean, -- plain shoes drawn (owner 2026-10-21: a class look without boots or catalog shoes)
	bodyParts: { [string]: number }?, -- a trial's body (nil = the game's body, Data/BodyLooks.parts)
}

local function int(n: any): number
	return if type(n) == "number" and n == n then math.max(0, math.floor(n)) else 0
end

-- Catalog clothing 2026-11-01 ----------------------------------------------------------------------------------

local typeByLower: { [string]: string } = {}
for name in ClassLooks.CATALOG_TYPES do
	typeByLower[string.lower(name)] = name
end
-- names the catalog uses for some types
local TYPE_ALIASES: { [string]: string } = {
	shoulders = "Shoulder",
	dress = "DressSkirt",
	skirt = "DressSkirt",
	["t-shirt"] = "TShirt",
}

-- The Enum.AccessoryType name of `name` (Data/ClassLooks.CATALOG_TYPES) in any case, also as the catalog writes it
-- ("JacketAcc", "PantsAccessory", "Shoulders"); nil when unknown.
function CharacterLook.catalogType(name: any): string?
	if type(name) ~= "string" then
		return nil
	end
	local key = string.lower(name)
	key = (string.gsub(key, "accessory$", ""))
	key = (string.gsub(key, "acc$", ""))
	return typeByLower[key] or TYPE_ALIASES[key]
end

-- A catalog item as a description wears it, nil for id 0: its type (catalogType; nil or unknown = the rigid
-- ClassLooks.DEFAULT_CATALOG_TYPE), for a layered type the layering order (`order`, else the type's default).
function CharacterLook.catalogPiece(id: any, typeName: any?, order: any?): CatalogPiece?
	local n = int(id)
	if n == 0 then
		return nil
	end
	local name = CharacterLook.catalogType(typeName) or ClassLooks.DEFAULT_CATALOG_TYPE
	local def = ClassLooks.CATALOG_TYPES[name]
	local o: number? = nil
	if def.layered then
		o = if type(order) == "number" and order == order then int(order) else def.order
	end
	return { id = n, type = name, layered = def.layered, order = o }
end

-- The catalog items a garment wears: its own and its `also` items, none while its `catalog` is 0.
function CharacterLook.garmentPieces(item: ClassLooks.Garment): { CatalogPiece }
	local out: { CatalogPiece } = {}
	local own = CharacterLook.catalogPiece(item.catalog, item.type, item.order)
	if own then
		table.insert(out, own)
		for _, ref in (item.also or {}) :: { ClassLooks.CatalogRef } do
			local piece = CharacterLook.catalogPiece(ref.catalog, ref.type, ref.order)
			if piece then
				table.insert(out, piece)
			end
		end
	end
	return out
end

-- The stable text of everything a look takes from its description: the face (head, lashes, brows), the build, the
-- classic clothing, every catalog item with its type and order, a trial's body. The server re-applies the description
-- only when it changes.
function CharacterLook.catalogKey(spec: LookSpec): string
	local face = spec.face
	local faceKey = if face then `{face.head}.{face.lashes}.{face.browsId}` else "0"
	local items = {}
	for _, piece in spec.accessories do
		table.insert(
			items,
			if piece.layered then `{piece.id}:{piece.type}@{piece.order}` else `{piece.id}:{piece.type}`
		)
	end
	local key =
		`f{faceKey}|w{spec.build.width},{spec.build.depth}|s{spec.shirt}|p{spec.pants}|a{table.concat(items, ",")}`
	local body = spec.bodyParts
	if body then
		local ids = {}
		for _, field in BodyLooks.PART_FIELDS do
			table.insert(ids, tostring(body[field] or 0))
		end
		key ..= `|b{table.concat(ids, ".")}`
	end
	return key
end

-- What a model marks with the description it wears (mode and catalog key; the server sets it, the wardrobe compares).
function CharacterLook.lookKey(spec: LookSpec): string
	return `{spec.mode}|{spec.catalogKey}`
end

-- An entry of HumanoidDescription:SetAccessories with the AccessoryType by name (Util/AvatarBuild turns it into the
-- enum). A rigid entry has no Order: SetAccessories reads an entry without one as a rigid accessory.
export type AccessoryEntry = {
	AssetId: number,
	AccessoryType: string,
	IsLayered: boolean,
	Order: number?,
	Puffiness: number?,
}

-- Layered clothing categories: a new item of one takes the place of every item of it (Roblox's own try-on).
local CATEGORY: { [string]: string } = {
	Shirt = "top",
	TShirt = "top",
	Sweater = "top",
	Pants = "bottom",
	Shorts = "bottom",
	DressSkirt = "bottom",
}

-- The accessory list of a description: `existing` (what it has, GetAccessories(true)) and then every catalog item of
-- the look. `replace` (avatar mode): a layered item takes the place of the description's layered clothing of the same
-- type or category, so an outfit's jacket is not layered over the avatar's own.
function CharacterLook.accessoryList(
	existing: { AccessoryEntry },
	pieces: { CatalogPiece },
	replace: boolean?
): { AccessoryEntry }
	local types: { [string]: boolean } = {}
	local categories: { [string]: boolean } = {}
	if replace == true then
		for _, piece in pieces do
			if piece.layered then
				types[piece.type] = true
				local category = CATEGORY[piece.type]
				if category then
					categories[category] = true
				end
			end
		end
	end
	local out: { AccessoryEntry } = {}
	for _, entry in existing do
		local category = CATEGORY[entry.AccessoryType]
		local taken = entry.IsLayered and (types[entry.AccessoryType] or (category ~= nil and categories[category]))
		if not taken then
			table.insert(out, entry)
		end
	end
	for _, piece in pieces do
		local entry: AccessoryEntry = { AssetId = piece.id, AccessoryType = piece.type, IsLayered = piece.layered }
		if piece.layered then
			entry.Order = piece.order
		end
		table.insert(out, entry)
	end
	return out
end

local function colorOf(colors: ClassLooks.Colors, role: string, skin: string?, hairColor: string?): string?
	if role == "skin" then
		return skin
	elseif role == "hair" then
		return hairColor or colors.second
	end
	local c = (colors :: any)[role]
	if type(c) == "string" then
		return c
	end
	-- trim, leather and metal fall back to the second colour (outfits before S132 have only two)
	return if role == "main" then colors.main else colors.second
end

-- What a character looks like (the only source of the outfit's colours: the dye is already in it). The input is
-- never changed.
function CharacterLook.resolve(input: LookInput): LookSpec
	local avatar = input.robloxAvatar == true
	local outfitDef = if input.outfitId then Cosmetics.get(input.outfitId) else nil
	if outfitDef and not CharacterLook.allowed(outfitDef, input.classId) then
		outfitDef = nil
	end
	local spec: OutfitSpec? = nil
	if input.spec then
		spec = input.spec
	elseif outfitDef then
		spec = CharacterLook.outfitSpec(outfitDef)
	elseif not avatar then
		local classLook = ClassLooks.get(input.classId)
		spec = if classLook then classLook.outfit else nil
	end

	local look = CharacterLook.normalize(input.look) :: any
	local skinHex: string? = nil
	local face: FaceSpec? = nil
	local hairDef: ClassLooks.Hair? = nil
	local hairHex = ClassLooks.hairColorById[look.hairColor].color :: string
	local build = BodyLooks.builds[look.build] or BodyLooks.builds.build_medium
	if not avatar then
		local skin = ClassLooks.skinById[look.skin]
		skinHex = skin and skin.color
		hairDef = ClassLooks.hairById[look.hair]
		local head = BodyLooks.heads[look.face]
		if head then
			face = {
				id = look.face,
				head = head.head,
				lashes = head.lashes,
				brows = look.brows,
				browsId = BodyLooks.brows[look.brows] or 0,
				beard = look.beard,
				paint = look.paint,
				paintColor = ClassLooks.paintColorById[look.paintColor].color :: string,
				hair = hairHex,
			}
		end
	else
		build = BodyLooks.builds.build_medium
	end

	-- colours of the roles, the dye over main and second (S123 rule, CosmeticRules.dyed)
	local colors: ClassLooks.Colors = { main = "#808080", second = "#808080" }
	if spec then
		colors = table.clone(spec.colors)
		local dyeDef = if type(input.dye) == "string" then Cosmetics.get(input.dye) else nil
		local main, second =
			CosmeticRules.dyed({ kind = "outfit", color = colors.main, color2 = colors.second } :: any, dyeDef)
		if main then
			colors.main = main
			colors.second = second or colors.second
		end
	end

	local trial = input.trial
	local bare = trial ~= nil and trial.bare == true
	local body: { [string]: string } = {}
	local garments: { GarmentSpec } = {}
	local accessories: { CatalogPiece } = {}
	local pieces = 0
	local hidesHair = false
	local shod = false
	local shirt, pants = 0, 0
	if spec then
		local roles = spec.body
		for part, defaultRole in ClassLooks.BODY_ROLES do
			local role = if roles and roles[part] then roles[part] else defaultRole
			if avatar and role == "skin" then
				-- the avatar keeps its own head and skin; hands take the second colour as before S132
				if HANDS[part] then
					body[part] = colors.second
				end
			else
				local c = colorOf(colors, role, skinHex, nil)
				if c then
					body[part] = c
				end
			end
		end
		-- a garment is not worn when a worn catalog item covers it (`hides`) or a trial takes it off
		local hidden: { [string]: boolean } = {}
		for _, name in ((if trial then trial.hide else nil) or {}) :: { string } do
			hidden[name] = true
		end
		for _, item in spec.garments do
			if int(item.catalog) ~= 0 then
				for _, name in (item.hides or {}) :: { string } do
					hidden[name] = true
				end
			end
		end
		for _, item in spec.garments do
			local def = CharacterLook.GARMENTS[item.g]
			if def then
				local off = bare or hidden[item.g] == true
				local catalog = int(item.catalog)
				local color = colorOf(colors, item.role or def.role, skinHex, nil) or colors.main
				table.insert(garments, {
					g = item.g,
					color = color,
					catalog = catalog,
					asset = item.asset,
					hidden = if off then true else nil,
				})
				if not off then
					local worn = CharacterLook.garmentPieces(item)
					for _, piece in worn do
						table.insert(accessories, piece)
					end
					if #worn == 0 then
						pieces += def.pieces
					end
					-- a hood or helmet worn (drawn or as its catalog item) covers the hair
					if def.hidesHair then
						hidesHair = true
					end
				end
				if item.g == "boots" and not bare then
					shod = true
				end
			end
		end
		shirt, pants = int(spec.shirt), int(spec.pants)
	end

	local hair: HairSpec? = nil
	if hairDef and not hidesHair and not (trial ~= nil and trial.hideHair == true) then
		local h: HairSpec = {
			id = hairDef.id,
			catalog = int(hairDef.catalog),
			asset = hairDef.asset,
			style = hairDef.style,
			color = hairHex,
		}
		hair = h
		local piece = CharacterLook.catalogPiece(h.catalog, "Hair")
		if piece then
			table.insert(accessories, piece)
		else
			local def = CharacterLook.GARMENTS[`hair_{hairDef.style}`]
			pieces += if def then def.pieces else 0
		end
	end
	if input.lure == true then
		pieces += CharacterLook.LURE_PIECES
	end
	local bodyParts: { [string]: number }? = nil
	if trial then
		for _, piece in (trial.pieces or {}) :: { CatalogPiece } do
			table.insert(accessories, table.clone(piece))
		end
		bodyParts = if trial.body then table.clone(trial.body) else nil
	end
	for _, piece in accessories do
		if piece.type == "LeftShoe" or piece.type == "RightShoe" then
			shod = true
		end
	end
	local out: LookSpec = {
		mode = if avatar then "avatar" else "class",
		skin = skinHex,
		face = face,
		hair = hair,
		body = body,
		garments = garments,
		shirt = shirt,
		pants = pants,
		accessories = accessories,
		catalogKey = "",
		pieces = pieces,
		build = { width = build.width, depth = build.depth },
		shoes = not avatar and not shod and not bare,
		bodyParts = bodyParts,
	}
	-- the head, lashes and brows come from the description too: a change re-applies it
	out.catalogKey = CharacterLook.catalogKey(out)
	return out
end

local function sortedIds(match: (def: Def) -> boolean): { string }
	local out: { string } = {}
	for _, def in Cosmetics.list do
		if match(def) then
			table.insert(out, def.id)
		end
	end
	table.sort(out)
	return out
end

-- Outfits given to a character of `classId` that hands in the quest `questId` (obtain.quest; shared or of the class).
function CharacterLook.questOutfits(questId: string, classId: string): { string }
	return sortedIds(function(def: Def): boolean
		return def.kind == "outfit"
			and def.obtain ~= nil
			and def.obtain.quest == questId
			and (def.class == nil or def.class == classId)
	end)
end

-- Outfits given to a character of `classId` among the winners of the boss `bossId` (obtain.bossWin).
function CharacterLook.bossWinOutfits(bossId: string, classId: string): { string }
	return sortedIds(function(def: Def): boolean
		return def.kind == "outfit"
			and def.obtain ~= nil
			and def.obtain.bossWin == bossId
			and (def.class == nil or def.class == classId)
	end)
end

-- Outfits a character of `classId` has earned already (given back when it enters the world): `questDone(id)` and
-- `bossWon(id)` answer from the save, only with a lasting proof.
function CharacterLook.earnedOutfits(
	classId: string,
	questDone: (questId: string) -> boolean,
	bossWon: (bossId: string) -> boolean
): { string }
	return sortedIds(function(def: Def): boolean
		local obtain = def.obtain
		if def.kind ~= "outfit" or obtain == nil or (def.class ~= nil and def.class ~= classId) then
			return false
		end
		return (obtain.quest ~= nil and questDone(obtain.quest)) or (obtain.bossWin ~= nil and bossWon(obtain.bossWin))
	end)
end

-- The gold of a look change: 0 (free, true) while the character has its free change, else
-- max(goldMin, goldPerLevel x level).
function CharacterLook.changeCost(character: any): (number, boolean)
	if type(character) == "table" and character.lookFree == true then
		return 0, true
	end
	local level = if type(character) == "table" then math.max(1, math.floor(tonumber(character.level) or 1)) else 1
	local cfg = Config.LookChange
	return math.max(cfg.goldMin, cfg.goldPerLevel * level), false
end

-- Whether `character` may change its look to `newLook` now (`nearBarber`: next to an NPC with the "look" service).
-- Errors in order: bad id, the same look, a paid change away from the barber, not enough gold.
function CharacterLook.canChange(character: any, newLook: any, nearBarber: boolean): (boolean, string?, number)
	local cost, free = CharacterLook.changeCost(character)
	if not CharacterLook.isValid(newLook) then
		return false, "look.error.bad", cost
	end
	if CharacterLook.same(if type(character) == "table" then character.look else nil, newLook) then
		return false, "look.error.same", cost
	end
	if not free and not nearBarber then
		return false, "look.error.barber", cost
	end
	local gold = if type(character) == "table" then tonumber(character.gold) or 0 else 0
	if gold < cost then
		return false, "look.error.gold", cost
	end
	return true, nil, cost
end

-- Scales of the class look (standard R15) and the avatar's scales clamped to Config.CharacterLook.avatarScale.
CharacterLook.STANDARD =
	table.freeze({ height = 1, width = 1, depth = 1, head = 1, bodyType = 0, proportion = 0 } :: { [string]: number })

function CharacterLook.clampScales(scales: any): { [string]: number }
	local out: { [string]: number } = {}
	local limits = Config.CharacterLook.avatarScale :: { [string]: { number } }
	for key, standard in CharacterLook.STANDARD do
		local value = if type(scales) == "table" then scales[key] else nil
		local range = limits[key]
		if type(value) ~= "number" or value ~= value or not range then
			out[key] = standard
		else
			out[key] = math.clamp(value, range[1], range[2])
		end
	end
	return out
end

return CharacterLook
