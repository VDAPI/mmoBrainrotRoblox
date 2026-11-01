--!strict
-- W09: the body every character wears (docs/WYGLAD.md §3, docs/WYGLAD-KLAS.md "Ciało"): one free Roblox base body with
-- human proportions and a dynamic head (Roblox bundle "Base Body - Dawson"), the same for everybody (equal silhouettes
-- in PvP; build choices come with the creator, W10), scaled to the height of the old standard R15 figure, and the free
-- Roblox hairstyles drawn instead of the procedural hair. Util/AvatarBuild puts it in the description of the character
-- (server) and the hair on the model (server and previews); a part that fails to load falls back to the standard R15
-- part (Roblox does that itself), a missing hairstyle to the procedural one. Looks only.

export type Hair = {
	id: number, -- Roblox catalog accessory (layered or classic hair, Roblox, free)
	-- true: the texture is light (blond), the hair colour tints it (Logic/HairTint.plan); false: see `tone`
	light: boolean,
	-- hair fixes 2026-10-31, every hair that is not light: the average colour of its texture (dark, red, pink, golden),
	-- read off Studio screenshots. The hair colour only nudges its hue (Logic/HairTint.nudge), so the creator offers such a
	-- hair in the colours its texture reaches (Logic/CharacterLook.hairColors).
	tone: string?,
}

local BodyLooks = {}

-- The Roblox bundle the parts come from (docs/ASSETS.md "Ciało").
BodyLooks.bundle = 991

-- HumanoidDescription body part fields -> catalog ids (Base Body - Dawson).
BodyLooks.parts = table.freeze({
	Head = 11709871094,
	Torso = 11709869073,
	LeftArm = 11709862883,
	RightArm = 11709865568,
	LeftLeg = 11709864101,
	RightLeg = 11709867346,
} :: { [string]: number })

-- The body part fields of a HumanoidDescription, in this order wherever they are listed.
BodyLooks.PART_FIELDS = table.freeze({ "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" })

-- Catalog clothing 2026-11-01: the other free base bodies to compare on the live character (dev /trylook body <name>,
-- docs/WYGLAD-KLAS.md §3): the parts below the head (the head stays the character's face) or only the bundle, whose
-- parts the server looks up (AssetService:GetBundleDetailsAsync). From the owner's catalog search (1.11), not tried on.
BodyLooks.trialBodies = table.freeze({
	dawson = { bundle = 991 }, -- the game's body (`parts` above)
	addison = {
		bundle = 988,
		parts = {
			Torso = 11702287641,
			LeftArm = 11702279057,
			RightArm = 11702284438,
			LeftLeg = 11702282072,
			RightLeg = 11702286099,
		},
	},
	jordan = {
		bundle = 994,
		parts = {
			Torso = 11740060397,
			LeftArm = 11740050465,
			RightArm = 11740055375,
			LeftLeg = 11740052832,
			RightLeg = 11740057815,
		},
	},
	robin = {
		bundle = 990,
		parts = {
			Torso = 11709146274,
			LeftArm = 11709138329,
			RightArm = 11709143116,
			LeftLeg = 11709141448,
			RightLeg = 11709144753,
		},
	},
	rene = {
		bundle = 992,
		parts = {
			Torso = 11714041015,
			LeftArm = 11714033534,
			RightArm = 11714037276,
			LeftLeg = 11714035598,
			RightLeg = 11714039415,
		},
	},
	billie = { bundle = 995 },
	harper = { bundle = 989 },
	glenn = { bundle = 984 },
	andi = { bundle = 993 },
} :: { [string]: { bundle: number, parts: { [string]: number }? } })

-- Heights of the whole figure at scale 1 (Studio, W09): the old standard R15 figure and this body. The class look
-- scales the body to the standard height (hitboxes, camera and the nameplate stay where they were, within 10%).
BodyLooks.STANDARD_HEIGHT = 5.46
BodyLooks.bodyHeight = 6.16

-- The scales of the class look on this body (the avatar mode multiplies its clamped height by `height`).
BodyLooks.scales = table.freeze({
	height = 0.9,
	width = 1,
	depth = 1,
	head = 1,
	bodyType = 0,
	proportion = 0,
} :: { [string]: number })

-- W10: the face choices (Data/ClassLooks.FACES id) -> the dynamic head and its lashes, from the free Roblox base body
-- bundles (Dawson, Jordan, Billie, Rene, Andi, Robin, Harper, Addison). Every head fits the neck of the body above.
BodyLooks.heads = table.freeze({
	face_calm = { head = 11709871094, lashes = 11709884954 },
	face_stern = { head = 11740063830, lashes = 11740069153 },
	face_young = { head = 11748988354, lashes = 11748991080 },
	face_weary = { head = 11714044513, lashes = 11714050380 },
	face_scarred = { head = 11715265417, lashes = 11715268504 },
	face_bearded = { head = 11709148634, lashes = 11709152004 },
	face_freckled = { head = 11702751287, lashes = 11702757409 },
	face_sharp = { head = 11702291006, lashes = 11702297008 },
} :: { [string]: { head: number, lashes: number } })

-- W10: the brow choices (Data/ClassLooks.BROWS id) -> the brows of a base body bundle, tinted with the hair colour.
BodyLooks.brows = table.freeze({
	brows_1 = 11709883139, -- Dawson
	brows_2 = 11740066767, -- Jordan
	brows_3 = 11702755085, -- Harper
	brows_4 = 11715267394, -- Andi
	brows_5 = 11714047676, -- Rene
	brows_6 = 11709149939, -- Robin
} :: { [string]: number })

-- Hairstyle (Data/ClassLooks.HAIRS id) -> the free Roblox hair drawn for it; a hairstyle without an entry is drawn from
-- parts ("hair_shaved" is the bare head). Hair fixes 2026-10-31 (tester: "most hairstyles are poorly made"): the
-- modern / anime ones gave way to the plainer cuts of the same free pool, light textures wherever Roblox has one (they
-- keep their strands in every colour). Tones read off Studio screenshots (review 2026-10-31); a colour cast = adjust
-- the tone. Side Part - Black was the same mesh as hair_short and left (hair_swept -> hair_short).
-- Owner 2026-11-01, the block body: a layered hair wraps round the square head into a box, every hair here is a rigid
-- classic one (read off Studio screenshots on the block body).
BodyLooks.hairs = table.freeze({
	hair_short = { id = 62743701, light = false, tone = "#6B4426" }, -- Stylish Brown Hair (classic)
	hair_fringe = { id = 62234425, light = false, tone = "#5C3A21" }, -- Brown Hair (classic)
	hair_charmer = { id = 376548738, light = false, tone = "#7A3A22" }, -- Brown Charmer Hair (classic, red-brown)
	hair_slicked = { id = 376524487, light = false, tone = "#D8BE45" }, -- Blonde Spiked Hair (classic)
	hair_bob = { id = 323476364, light = false, tone = "#4E3324" }, -- Brown Scene Hair (classic)
	hair_long = { id = 13745548, light = false, tone = "#8A4A26" }, -- Cinnamon Hair (classic)
	hair_straight = { id = 376526888, light = false, tone = "#D8BE45" }, -- Straight Blonde Hair (classic, golden)
	hair_ponytail = { id = 26658141, light = false, tone = "#4A3224" }, -- Messy Hair (classic)
	hair_sidetail = { id = 376527350, light = false, tone = "#1E1F2A" }, -- Black Side Ponytail (classic, blue-black)
	hair_braid = { id = 2956239660, light = false, tone = "#C23A1C" }, -- Belle Of Belfast (red, braided crown)
	hair_bun = { id = 451220849, light = false, tone = "#E2A6DC" }, -- Lavender Updo (classic messy bun, pink)
} :: { [string]: Hair })

-- W10: build (Data/ClassLooks.BUILDS id) -> width and depth scale of the body (height and hitbox unchanged, within 5%).
BodyLooks.builds = table.freeze({
	build_slim = { width = 0.95, depth = 0.96 },
	build_medium = { width = 1, depth = 1 },
	build_strong = { width = 1.05, depth = 1.04 },
} :: { [string]: { width: number, depth: number } })

-- W10: face paint (Data/ClassLooks.PAINTS id) -> image of a decal on the front of the head (white on transparent,
-- tinted with the paint colour; art/paint, tools/paint/make_paints.py, uploaded through Studio MCP); 0 = no image
-- (nothing drawn).
BodyLooks.paints = table.freeze({
	paint_freckles = 95942517711921,
	paint_stripes = 135974831560455,
	paint_rune = 99912586932383,
	paint_tribal = 102850523232408,
	paint_ash = 81514322022003,
} :: { [string]: number })

-- ReplicatedStorage folder the server fills (W10) with the look parts the client previews need and the server puts on:
-- `hair_<id>` / `brows_<id>` / `lashes_<face>` accessories and `head_<face>` heads.
BodyLooks.PARTS_FOLDER = "VaelthornLookParts"

export type Style = {
	id: string,
	scales: { [string]: number },
	blocky: boolean, -- the classic block R15 (no body parts, no dynamic head): a decal face, classic shirts and pants show
	face: number, -- the decal face of a blocky body (the one tried in Studio 2026-11-01)
}

-- Owner 2026-11-01, after trying the styles in Studio: every character and the creator's mannequin wear the classic
-- block R15 (BodyLooks.parts, the dynamic heads and `scales` above are what a character wore before, kept for the
-- previews of old saves until the creator is rebuilt on it).
local BLOCKY: Style = table.freeze({
	id = "blocky",
	scales = table.freeze({ height = 1, width = 1, depth = 1, head = 1, bodyType = 0, proportion = 0 }),
	blocky = true,
	face = 86487700,
})

function BodyLooks.current(): Style
	return BLOCKY
end

return table.freeze(BodyLooks)
