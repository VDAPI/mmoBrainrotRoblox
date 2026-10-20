--!strict
-- W26: monster kinds that reuse the imported model of another kind instead of their own Tripo model
-- (docs/wyglad/TRIPO-POTWORY-GOTOWE.md: "Gra zmienia im barwę i skalę"). Data/MonsterAssets turns each one whose base
-- has an entry into an entry of its own (`from` = the base, the base's hitbox numbers and clips); until the base has a
-- model (brownBear), the variant keeps its generated look. `tint`: the colour the base's textures are multiplied by
-- (SurfaceAppearance.Color), so a light colour keeps the texture and a dark one darkens it. The scale is the variant's
-- own (Data/Monsters size, elite variants on top), the bone roles come from the shared skeleton.
-- No chains: a base is never a variant itself (tests/monsterassets.spec).

export type Variant = {
	from: string, -- the base kind, a key of Data/MonsterAssets once its model exists
	tint: string, -- "#RRGGBB" multiply colour of the base's textures
}

local MonsterAssetVariants: { [string]: Variant } = {
	iceWolf = { from = "wolf", tint = "#C4DCF6" }, -- pale icy blue over the grey wolf
	snowLeopard = { from = "lynx", tint = "#D2D6DE" }, -- cool white-grey over the tawny lynx, the dark spots stay
	blackBear = { from = "brownBear", tint = "#463C36" }, -- near-black brown (brownBear has no model yet)
}

return MonsterAssetVariants
