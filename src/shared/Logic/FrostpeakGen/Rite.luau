--!strict
-- The Rite Circle at the foot of the Wyrm Spire's horn (S105, story chapter IV and the finale): the ring of six ice
-- monoliths with the cult's runes, the slate altar and the Heart of Winter on it. One source of the geometry for the
-- generator (Logic/FrostpeakGen/Wyrm builds the circle for everyone) and for the client effects that change it for
-- one player after the rite is broken and the Thorn driven in (QuestAnchorController `rite`, `thorn`). Local frame of
-- the site `summitRite` (Data/Areas/frostpeak): the front is local -Z (towards the Bone Trail), the anchors
-- summit_rite and summit_thorn stand on the local -Z axis. Pure.

local Rite = {}

Rite.RADIUS = 9 -- the monoliths' ring
Rite.STONE = { w = 2.4, h = 9, d = 1.6 } -- one monolith (w across the ring's tangent)
Rite.ALTAR = { w = 4, h = 2, d = 4 } -- the slate altar in the middle
Rite.HEART = 3.4 -- the Heart of Winter: a crystal ball on the altar
Rite.HEART_COLOR = "#9FE0FF"
Rite.CLEAR = 14 -- no tree or rock inside this circle

export type Stone = { x: number, z: number, yaw: number }

-- The six monoliths: every 60 degrees from 30 (the front, local -Z, stays open for the way in); `yaw` turns the
-- stone's broad face towards the middle.
function Rite.stones(): { Stone }
	local out: { Stone } = {}
	for k = 0, 5 do
		local a = math.rad(30 + k * 60)
		table.insert(out, { x = math.sin(a) * Rite.RADIUS, z = -math.cos(a) * Rite.RADIUS, yaw = -(30 + k * 60) })
	end
	return out
end

-- The Heart's centre over the ground in the middle.
function Rite.heartY(): number
	return Rite.ALTAR.h + Rite.HEART / 2
end

return table.freeze(Rite)
