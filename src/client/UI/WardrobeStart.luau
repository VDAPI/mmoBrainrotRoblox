--!strict
-- The tab the wardrobe opens on next time (S97: the mounts window's "Wardrobe" opens it on the mount skins) and, S120,
-- the cosmetic tried on when it opens (the Dragon Shop's "Try on"). Read and cleared by UI/Screens/Wardrobe when it is
-- built.

local WardrobeStart = {
	kind = nil :: string?,
	try = nil :: string?, -- S120
}

return WardrobeStart
