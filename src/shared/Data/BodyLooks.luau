--!strict
-- W09: the body every character wears (docs/WYGLAD.md §3, docs/WYGLAD-KLAS.md "Ciało"): one free Roblox base body with
-- human proportions and a dynamic head (Roblox bundle "Base Body - Dawson"), the same for everybody (equal silhouettes
-- in PvP; build choices come with the creator, W10), scaled to the height of the old standard R15 figure, and the free
-- Roblox hairstyles drawn instead of the procedural hair. Util/AvatarBuild puts it in the description of the character
-- (server) and the hair on the model (server and previews); a part that fails to load falls back to the standard R15
-- part (Roblox does that itself), a missing hairstyle to the procedural one. Looks only.

export type Hair = {
	id: number, -- Roblox catalog accessory (layered hair, Roblox, free)
	-- true: the texture is light (blond), the hair colour tints it; false: a black texture, kept for dark colours and
	-- replaced by the plain hair colour for light ones (Logic/HairTint)
	light: boolean,
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

-- The dynamic head's brows and lashes (layered face accessories of the bundle).
BodyLooks.eyebrows = 11709883139
BodyLooks.eyelashes = 11709884954

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

-- Hairstyle (Data/ClassLooks.HAIRS style) -> the Roblox hair drawn for it; a style without an entry is drawn from
-- parts (none: "shaved" is the bare head). The creator's choice of real hairstyles comes with W10.
BodyLooks.hairs = table.freeze({
	short = { id = 9243987340, light = true }, -- Short and Sleek - Blonde
	long = { id = 9244111257, light = false }, -- Wavy Middle Part - Black
	ponytail = { id = 9244095135, light = true }, -- Pony Tail - Blonde
	braid = { id = 7193454569, light = false }, -- Braided Hair - Black
	topknot = { id = 9174353649, light = false }, -- Surfer - Black (swept back, the nearest to a knot)
	curly = { id = 7193452166, light = false }, -- Short Curls - Black
	swept = { id = 9244021842, light = false }, -- Side Part - Black
} :: { [string]: Hair })

-- ReplicatedStorage folder the server fills with the hair accessories (one per style, named after it) for the
-- characters and the client previews.
BodyLooks.HAIR_FOLDER = "VaelthornHairs"

return table.freeze(BodyLooks)
